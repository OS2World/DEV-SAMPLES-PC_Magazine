;-----------------------------------------------------------------------------;
;  DIRMATCH * PC Magazine * Michael J. Mefford                                 ;
;  Points out the similarity and differences of two directories and then       ;
;  lets you update the target directory with specific source directory files.  ;
;-----------------------------------------------------------------------------;
_TEXT          SEGMENT PUBLIC 'CODE'
               ASSUME  CS:_TEXT,DS:_TEXT,ES:_TEXT,SS:_TEXT
               ORG     100H
START:         JMP     MAIN

;              DATA AREA
;              ---------
SIGNATURE      DB      CR,SPACE,SPACE,SPACE,CR,LF
COPYRIGHT      DB      "DIRMATCH 1.0 (C) 1989 Ziff Communications Co. ",CR,LF
PROGRAMMER     DB      "PC Magazine ",BOX," Michael J. Mefford",CR,LF,LF

DB             "Syntax:  DIRMATCH source target [/D][/A]",CR,LF,LF
DB             "/D = Different files",CR,LF
DB             "/A = Alike files$",CTRL_Z

TAB            EQU     9
CR             EQU     13
LF             EQU     10
CTRL_Z         EQU     26
SPACE          EQU     32
BOX            EQU     254
VERT_LINE      EQU     179
FF             EQU     12
SHIFT_KEYS     EQU     3
LITTLE_ARROW   EQU     26
ESC_SCAN       EQU     1
Y_SCAN         EQU     15H
N_SCAN         EQU     31H
NOTE           EQU     1046                    ; C
SPEC_LENGTH    EQU     66 + 12

MENU           LABEL BYTE
DB "F1 ",0, "All files  ",0, "Different files  ",0, "Alike files  ",0
DB "F2 Mark all  F3 Clear marks  F4 CopyF5 Move   F6 Print   "
DB "Use: ",24,32,25," PgUp PgDn Home End   +/- Mark/Unmark   Esc to Exit",0

ALL            EQU     0
UNIQUE         EQU     2
ALIKE          EQU     4

FILES_MODE     DB      ALL
MODES          DW      DO_ALL, DO_UNIQUE, DO_ALIKE

CRT_MODE       EQU     49H
CRT_ROWS       EQU     84H
STATUS_REG     DW      3BAH
VIDEO_SEG      DW      0B000H
ROWS           DB      24
SYNTAX_FLAG    DB      0

HEADING_ATTR   DB      70H
ACTIVE_ATTR    DB      0FH
BODY_ATTR      DB      07H
HIGHLIGHT_ATTR DB      0FH
MENU_ATTR      DB      07H
BAR_ATTR       DB      70H
INTENSE        EQU     7FH
INTENSE_BLUE   EQU     1FH
BLUE           EQU     17H
INVERSE_BLUE   EQU     71H
CYAN           EQU     31H

TOP_MEMORY     DW      ?
DEFAULT_DRIVE  DB      ?
SOURCE_SEG     DW      ?
TARGET_SEG     DW      ?
BUFFER_SEG     DW      ?
BUFFER_SIZE    DW      0FFFFH
SOURCE_END     DW      ?
TARGET_END     DW      ?
LISTING_LINE   DW      0
BAR_LINE       DW      0
LAST_BAR       DW      ?
PAGE_LENGTH    DW      ?
SOURCE_COUNT   DW      ?
TARGET_COUNT   DW      ?
MARKED_COUNT   DW      ?
RESPONSE       DW      ?

OUT_OF_MEMORY  DB      "Not enough memory ",0,"$"
TOO_MANY       DB      "Too many files ",0,"$"
SOURCE_PROMPT  DB      CR,LF,LF,"Source$"
TARGET_PROMPT  DB      CR,LF,LF,"Target$"
NOT_FOUND      DB      " filespec not found",CR,LF
               DB      "Enter filespec: $"

PRESS_MSG      DB      "Error; Press any key",0
SOURCE_MSG     DB      " Source",0
DIRECTORY_MSG  DB      " Directory",0
FILES_MSG      DB      " files",0
GAP            EQU     4
DIRECTORY_LEN  EQU     $ - SOURCE_MSG + GAP - 3
TO_MSG         DB      " to"
TARGET_MSG     DB      " Target",0
COPY_MSG       DB      "Copy ",0
MOVE_MSG       DB      "Move ",0
MARKED_MSG     DB      " marked files",0
QUERY_MSG      DB      "?  Y/N ",0
STAR_DOT_STAR  DB      "*.*",0

RECENT         DB      ">",   6 DUP (?)
NOT_RECENT     DB      SPACE, 6 DUP (?)

DISPATCH_KEY   DB      48H,   50H,   49H,   51H,   47H,   4FH
               DB      3BH,   54H,   3CH,   3DH,   3EH,   3FH
               DB      40H,   01H,   0DH,   4EH,   0CH,   4AH
DISPATCH_CNT   EQU     $ - DISPATCH_KEY

DISPATCH_TABLE DW      UP,    DOWN,  PGUP,  PGDN,  HOME,  END_KEY
               DW      F1,    S_F1,  F2,    F3,    F4,    F5
               DW      F6,    EXIT,  PLUS,  PLUS,  MINUS, MINUS
DISPATCH_END   EQU     $ - 2

MATCHING       STRUC
RESERVED       DB      21 DUP (?)
ATTRIBUTE      DB              ?
FILE_TIME      DW              ?
FILE_DATE      DW              ?
SIZE_LOW       DW              ?
SIZE_HIGH      DW              ?
FILE_NAME      DB      13 DUP (?)
MATCHING       ENDS

FILE_RECORD    STRUC
LIST_NAME      DB      12 DUP (?)
LIST_BYTES     DB       9 DUP (?)
LIST_DATE      DB      10 DUP (?)
LIST_TIME      DB       8 DUP (?)
MARK           DB              ?
DOS_DATE       DW              ?
DOS_TIME       DW              ?
DISP_ORDER     DW              ?
FILE_RECORD    ENDS

;              CODE AREA
;              ---------
MAIN           PROC    NEAR
               CLD                             ;String instructions forward.
               MOV     BX,0FFFFH               ;Memory allocation request will
               MOV     AH,4AH                  ; fail and BX will return with
               INT     21H                     ; available memory in 
                                               ; paragraphs.
               CMP     BX,64 * (1024 / 16)     ;At least 64K paragraphs?
               JAE     ALLOCATE
               MOV     DX,OFFSET OUT_OF_MEMORY
               JMP     ERROR_EXIT              ;If no, exit.
ALLOCATE:      MOV     AH,4AH                  ;Else, allocate all available.
               INT     21H
               MOV     AX,DS                   ;Get our segment;
               ADD     AX,BX                   ; add to available and save
               MOV     TOP_MEMORY,AX           ; as segment of memory top.

               MOV     SP,OFFSET STACK_POINTER ;Set up stack.

               MOV     DX,OFFSET DTA           ;Set up Disk Transfer Address.
               MOV     AH,1AH
               INT     21H

               MOV     AH,19H                  ;Get default drive so can
               INT     21H                     ; restore after we change it.
               MOV     DEFAULT_DRIVE,AL

;----------------------------------------------;
CK_SWITCH:     MOV     SI,81H                  ;Point to command line.
NEXT_SWITCH:   LODSB                           ;Get a byte.
               CMP     AL,CR                   ;Is it carriage return?
               JZ      PARSE_SOURCE            ;If yes, done here.
               CMP     AL,"/"                  ;Is it switch delimiter?
               JNZ     NEXT_SWITCH             ;If no, next byte.
               LODSB                           ;Get the switch character.
               CMP     AL,CR                   ;Make sure it's not CR
               JZ      PARSE_SOURCE            ; so we don't go past end.
               AND     AL,5FH                  ;Capitalize.
CK_UNIQUE:     CMP     AL,"D"                  ;If "D", then Different files.
               JNZ     CK_ALIKE
               MOV     FILES_MODE,UNIQUE
CK_ALIKE:      CMP     AL,"A"                  ;If "A", then Alike files.
               JNZ     NEXT_SWITCH             ;If none of these, next byte.
               MOV     FILES_MODE,ALIKE
               JMP     NEXT_SWITCH

;---------------------------------------------------------------;
; Parse the command line for filespecs.  If one or both missing ;
; or file can't be opened, prompt the user for filespec.        ;
;---------------------------------------------------------------;
PARSE_SOURCE:  MOV     SI,81H                  ;Point to command line again.
               CALL    PARSE_SPEC              ;Parse a filespec.
               PUSH    [SI]                    ;Save ending byte
               PUSH    SI                      ; and the pointer.
               JNZ     SOURCE_PATH             ;If filespec found, check path.
PROMPT1:       XOR     DI,DI                   ;Else, ask user for first
               CALL    PROMPT_USER             ; filespec.
               CALL    PARSE_SPEC              ;Parse it.
               JZ      PROMPT1                 ;If null string, prompt again.
SOURCE_PATH:   MOV     DI,OFFSET SOURCE_SPEC   ;Storage for complete filespec.
               CALL    FIND_PATH               ;Parse the path from filespec.
               JC      PROMPT1                 ;If not found, prompt user.
               MOV     SOURCE_END,SI           ;Else, store source path end.
               MOV     BP,ES                   ;Calculate the segment to save
               MOV     DI,OFFSET SOURCE_OFFSET ; first batch of filenames.
               CALL    CALC_SEG
               MOV     SOURCE_SEG,BP           ;Save it.
               CALL    SOURCE_DIR
               JC      ERROR_EXIT              ;If ran out of memory, exit.
               POP     SI                      ;Recover command line pointer
               POP     [SI]                    ; and restore string
                                               ; terminator.

PARSE_TARGET:  CALL    PARSE_SPEC              ;Parse for second filespec.
               JNZ     TARGET_PATH             ;If not null string, check
                                               ; path.
PROMPT2:       MOV     DI,1                    ;Else, prompt user for second
               CALL    PROMPT_USER             ; filespec and then parse it.
               JMP     PARSE_TARGET
TARGET_PATH:   MOV     DI,OFFSET TARGET_SPEC   ;Storage for complete filespec.
               CALL    FIND_PATH               ;Parse path from filespec.
               JC      PROMPT2                 ;If not found, prompt user.
               MOV     TARGET_END,SI           ;Else, save target path end.
               CALL    TARGET_DIR              ;Get target files.
               JC      ERROR_EXIT

DO_SETUP:      CALL    VIDEO_SETUP             ;Prepare for video environment.
               CALL    MATCH                   ;Match the filenames.

;----------------------------------------------------------;
; Loop here processing user commands and updating display. ;
;----------------------------------------------------------;
INPUT:         CALL    DISP_LISTINGS           ;Update the display.
               CALL    GET_KEY
               MOV     DI,OFFSET DISPATCH_KEY  ;Check dispatch table.
               MOV     CX,DISPATCH_CNT
               REPNZ   SCASB
               JNZ     INPUT                   ;If no match, ignore.
               SHL     CX,1                    ;Else, look up subroutine
               MOV     DI,OFFSET DISPATCH_END
               SUB     DI,CX
               MOV     BP,BAR_LINE             ;Paging commands need line
               MOV     BX,LISTING_LINE         ; page data.
               MOV     CX,LAST_BAR
               MOV     DX,PAGE_LENGTH
               CALL    [DI]                    ;Process the command.
               JMP     INPUT                   ;Next input.

;----------------------------------------------;
ERROR_EXIT:    CALL    PRINT_STRING            ;Print error message.
ERROR:         MOV     AL,1                    ;Exit with ERRORLEVEL one.
               JMP     SHORT TERMINATE

EXIT:          MOV     DH,ROWS                 ;Clear last two lines.
               MOV     CH,DH
               DEC     CH
               XOR     CL,CL
               MOV     DL,80 - 1
               MOV     BH,MENU_ATTR
               MOV     AX,600H                 ; by scrolling active page.
               INT     10H

               XOR     BX,BX                   ;Border back to black.
               MOV     AH,0BH
               INT     10H

               MOV     DH,CH                   ;Place cursor on next
               DEC     DH                      ; to last line.
               XOR     DL,DL
               CALL    SET_CURSOR
               XOR     AL,AL                   ;ERRORLEVEL zero.
TERMINATE:     MOV     AH,4CH                  ;Terminate.
               INT     21H
MAIN           ENDP

;              ***************
;              * SUBROUTINES *
;              ***************
;-------------------------------------------------;
SOURCE_DIR:    MOV     BP,SOURCE_SEG
               MOV     DX,OFFSET SOURCE_SPEC
               CALL    FIND_FILES              ;Find the filenames.
               JC      GET_END1
               CALL    CALC_SEG                ;If successful, calculate
                                               ; segment of target DIR
               MOV     TARGET_SEG,BP           ; filename storage.
               CLC
GET_END1:      RET

;-------------------------------------------------;
; OUTPUT: CY = 1 if failed;  DX -> Error message. ;
;-------------------------------------------------;
TARGET_DIR:    MOV     BP,TARGET_SEG           ;Retrieve segment for
                                               ; filenames.
               MOV     DX,OFFSET TARGET_SPEC
               CALL    FIND_FILES              ;Find the filenames.
               JC      GET_END2                ;If ran out of memory, exit.
               CALL    CALC_SEG                ;If successful, calculate
               MOV     BUFFER_SEG,BP           ; segment of copy buffer.
               MOV     AX,TOP_MEMORY           ;Retrieve top of memory 
                                               ; segment.
               SUB     AX,BP                   ;Paragraphs available for
                                               ; buffer.
               MOV     DX,OFFSET OUT_OF_MEMORY
               JBE     GET_END2                ;If none, exit.
               CMP     AX,80H                  ;If less than practical minimum
               JB      GET_END2                ; of 2K bytes (128 para), exit.
               CMP     AX,1000H                ;If more than 4K paragraphs
               JAE     GET_END2                ; (64K bytes), then use
                                               ; default.
               MOV     CL,4                    ;Else, convert paragraphs to
               SHL     AX,CL                   ; bytes and save as buffer
               MOV     BUFFER_SIZE,AX          ; size.
               CLC
GET_END2:      RET

;----------------------------------------------;
MATCH:         MOV     BAR_LINE,0
               MOV     LISTING_LINE,0          ;Move listing to top.
DO_MATCH:      PUSH    DS                      ;Preserve segments.
               PUSH    ES
               MOV     SOURCE_COUNT,0
               MOV     TARGET_COUNT,0          ;Initialize file counts to
                                               ; zero.

               MOV     DL,FILES_MODE           ;Get offset of current
               XOR     DH,DH                   ; file display mode.
               ADD     DX,OFFSET MODES
               MOV     ES,TARGET_SEG           ;Target listing segment.
               MOV     DS,SOURCE_SEG           ;Source listing segment.
               XOR     BX,BX                   ;DS:BX -> source.
               XOR     BP,BP                   ;ES:BP -> target.
               XOR     AX,AX                   ;Counter.
NEXT_MATCH:    CMP     BYTE PTR ES:LIST_NAME[BP],-1   ;End of listing 2?
               JNZ     COMPARE                        ;If no, compare
                                                      ; filenames.
               CMP     BYTE PTR LIST_NAME[BX],-1      ;Else, end of listing 1?
               JZ      MATCH_END                      ;If yes, done here.

COMPARE:       MOV     SI,BX                   ;Get pointers to filenames.
               MOV     DI,BP
               MOV     CX,SIZE LIST_NAME
               REP     CMPSB                   ;Compare the names.
               MOV     DI,DX
               CALL    CS:[DI]                 ;Process.
               JMP     NEXT_MATCH              ;Do next match.

MATCH_END:     POP     ES                      ;Restore segments.
               POP     DS
               DEC     AX                      ;Adjust counter.
               JGE     STORE_BAR               ;If non-zero, OK.
               XOR     AX,AX                   ;Else, use zero.
STORE_BAR:     MOV     LAST_BAR,AX             ;Last bar location = count.
               CALL    DISPLAY_DIRS            ;Update the directory file
                                               ; count.
               RET

;----------------------------------------------;
DO_ALL:        MOV     SI,AX                   ;Current counter.
               MOV     DI,AX
               JZ      ALL_MATCH               ;If name same, check date.
               JB      ALL_LEFT2               ;Else, update the one
               CALL    UPDATE_LIST2            ; earlier in the alphabet
               JMP     SHORT ALL_END           ; with current display order.

ALL_MATCH:     CALL    DO_DATE
               JB      ALL_LEFT1
               JA      ALL_RIGHT1
               OR      DI,8000H                ;Highlight flag.
ALL_RIGHT1:    OR      SI,8000H
               JMP     SHORT ALL_UPDATE
ALL_LEFT1:     OR      DI,8000H
ALL_UPDATE:    CALL    UPDATE_LIST2

ALL_LEFT2:     CALL    UPDATE_LIST1
ALL_END:       INC     AX                      ;Increment counter.
               RET

;----------------------------------------------;
DO_UNIQUE:     MOV     SI,AX
               MOV     DI,AX
               JZ      UNIQUE_MATCH            ;If match, check date.
               JA      UNIQUE_RIGHT            ;Else, update the one
               INC     AX                      ; earlier in the alphabetic
               JMP     SHORT UNIQUE_LEFT       ; with current display order.
UNIQUE_RIGHT:  INC     AX
               CALL    UPDATE_LIST2
               JMP     SHORT UNIQUE_END

UNIQUE_MATCH:  CALL    DO_DATE
               JB      UNIQUE_LEFT1
               JA      UNIQUE_RIGHT1
               MOV     SI,-1                   ;Non-display flag.
               MOV     DI,-1
               JMP     SHORT UNIQUE_UPDATE
UNIQUE_RIGHT1: OR      SI,8000H                ;Highlight flag.
               JMP     SHORT UNIQUE_DATE
UNIQUE_LEFT1:  OR      DI,8000H
UNIQUE_DATE:   INC     AX

UNIQUE_UPDATE: CALL    UPDATE_LIST2
UNIQUE_LEFT:   CALL    UPDATE_LIST1
UNIQUE_END:    RET

;----------------------------------------------;
DO_ALIKE:      MOV     SI,AX
               MOV     DI,AX
               JZ      ALIKE_MATCH             ;If match, then check date.
               MOV     SI,-1
               JB      ALIKE_LEFT
               MOV     DI,-1                   ;Else, update the one earlier
               CALL    UPDATE_LIST2            ; in the alphabet with a -1
               JMP     SHORT ALIKE_END         ; non-display flag.

ALIKE_MATCH:   INC     AX
               CALL    DO_DATE
               JB      ALIKE_LEFT1
               JA      ALIKE_RIGHT1
               OR      DI,8000H
ALIKE_RIGHT1:  OR      SI,8000H
               JMP     SHORT ALIKE_UPDATE
ALIKE_LEFT1:   OR      DI,8000H

ALIKE_UPDATE:  CALL    UPDATE_LIST2
ALIKE_LEFT:    CALL    UPDATE_LIST1
ALIKE_END:     RET

;-----------------------------------------------------------------------------;
; INPUT: BX -> Source name; BP -> target name; OUTPUT: ZF = 1 if date matched. ;
;-----------------------------------------------------------------------------;
DO_DATE:       PUSH    SI
               PUSH    DI
               MOV     SI,BX                   ;Get filename pointers again.
               MOV     DI,BP
               ADD     SI,DOS_DATE             ;Point to date/time in DOS
               ADD     DI,DOS_DATE             ; format and compare.
               MOV     CX,(SIZE DOS_DATE + SIZE DOS_TIME) / 2
               REP     CMPSW
               POP     DI
               POP     SI
               RET

;----------------------------------------------;
UPDATE_LIST1:  MOV     DISP_ORDER[BX],SI       ;Store the display order value.
               ADD     BX,SIZE FILE_RECORD     ;Point to next filename.
               INC     SI                      ;Is it -1, non-display marker?
               JZ      LIST1_END               ;If yes, done here.
               INC     CS:SOURCE_COUNT         ;Else, increment file count.
LIST1_END:     RET

UPDATE_LIST2:  MOV     ES:DISP_ORDER[BP],DI    ;Same for the second batch of
               ADD     BP,SIZE FILE_RECORD     ; of filenames.
               INC     DI                      ;Is it -1, non-display marker?
               JZ      LIST2_END               ;If yes, done here.
               INC     CS:TARGET_COUNT         ;Else, increment file count.
LIST2_END:     RET

;----------------------------------------------;
DISP_LISTINGS: PUSH    DS                      ;Preserve data segment.
               PUSH    SI
               MOV     BP,LISTING_LINE         ;1st line of listing to
                                               ; display.
               MOV     CX,PAGE_LENGTH          ;No. of lines to display.
               XOR     SI,SI                   ;SI -> start of source.
               XOR     DX,DX                   ;DX -> start of target.
               MOV     DI,(3 * 160)            ;Start display row 2; column 1.
NEXT_LIST:     PUSH    CX                      ;Preserve lines to display.
               MOV     DS,CS:SOURCE_SEG        ;1st in left half of screen.
               MOV     CX,40                   ;39 chars in filename plus
                                               ; mark.
               PUSH    DX                      ;Preserve DX.
               CALL    DO_LIST                 ;Display the left half of line.
               POP     DX                      ;Restore DX.
               XCHG    SI,DX                   ;Now point to target filename.
               MOV     DS,CS:TARGET_SEG        ;Also need the segment.
               INC     DI                      ;Bump pointer to next line.
               INC     DI
               MOV     CX,39                   ;It is 39 chars too.
               PUSH    DX                      ;Preserve DX.
               CALL    DO_LIST                 ;Display the right half of
                                               ; line.
               POP     DX                      ;Restore DX.
               XCHG    SI,DX                   ;Restore pointers.
               INC     BP                      ;Next order counter.
               POP     CX                      ;Retrieve line counter.
               LOOP    NEXT_LIST               ;Do all lines.
               POP     SI
               POP     DS                      ;Restore data segment.
               RET                             ;Done here.

;---------------------------------------------------------------;
; INPUT: DS:SI -> filename to display; Entry point at DO_LIST.  ;
;---------------------------------------------------------------;
NEXT_REC1:     ADD     SI,SIZE FILE_RECORD     ;Next filename.
DO_LIST:       MOV     BH,CS:BODY_ATTR         ;Assume body attribute.
               CMP     LIST_NAME[SI],-1        ;Is this end of listing?
               JZ      PAD_LINE                ;If yes, pad line with spaces.
               MOV     AX,DISP_ORDER[SI]       ;Retrieve display order.
               CMP     AX,-1                   ;Should it be displayed?
               JZ      NEXT_REC1               ;If no, next record.
               TEST    AX,8000H                ;Highlight bit?
               JZ      COMPARE_ORDER           ;If no, use body attribute.
               MOV     BH,CS:HIGHLIGHT_ATTR    ;Else, highlight.
               AND     AX,NOT 8000H            ;Strip highlight bit.
COMPARE_ORDER: CMP     AX,BP                   ;Else, entry less than order?
               JB      NEXT_REC1               ;If yes, next record.
               JA      PAD_LINE                ;If above, pad with spaces.

               CMP     CX,40                   ;Is this the source directory?
               JNZ     DO_CHAR2                ;If no, skip mark field.
               MOV     AL,MARK[SI]             ;Else, retrieve mark.
               CALL    WRITE_SCREEN            ;Write it to display.
               DEC     CX                      ;Adjust count acting as flag.
               CMP     CS:BAR_LINE,BP          ;Is this the bar line?
               JNZ     DO_CHAR2                ;If no, write the line.
               PUSH    BX                      ;Else, preserve attribute.
               MOV     BH,CS:BAR_ATTR          ;Retrieve bar attribute.
               MOV     CX,SIZE LIST_NAME       ;Write name with bar attribute.
DO_CHAR1:      LODSB
               CALL    WRITE_SCREEN
               LOOP    DO_CHAR1
               POP     BX                      ;Retrieve display attribute.
               MOV     CX,39 - SIZE LIST_NAME  ;Rest of name.
DO_CHAR2:      LODSB                           ;Display the filename.
               CALL    WRITE_SCREEN
               LOOP    DO_CHAR2
               ADD     SI,7                    ;Past date/time/order/mark
               JMP     SHORT DO_LIST_END       ; fields.

PAD_LINE:      CMP     CX,40                   ;Is this source directory?
               JNZ     DO_PAD2                 ;If no, just write spaces.
               MOV     AL,SPACE                ;Else, write one space as mark.
               CALL    WRITE_SCREEN
               DEC     CX                      ;Adjust counter flag.
               CMP     CS:BAR_LINE,BP          ;Is this the bar line?
               JNZ     DO_PAD2                 ;If no, write line.
               PUSH    BX                      ;Else, display bar and
               MOV     BH,CS:BAR_ATTR          ; then rest of blank line.
               MOV     CX,SIZE LIST_NAME
DO_PAD1:       MOV     AL,SPACE
               CALL    WRITE_SCREEN
               LOOP    DO_PAD1
               POP     BX
               MOV     CX,39 - SIZE LIST_NAME
DO_PAD2:       MOV     AL,SPACE
               CALL    WRITE_SCREEN
               LOOP    DO_PAD2
DO_LIST_END:   RET

;-------------------------------------------------------------------------;
; INPUT:  SI -> string to parse.                                          ;
; OUTPUT: BP -> filespec start; SI -> filespec end; BX -> filename start. ;
;         ZF = 1 if null string.                                          ;
;-------------------------------------------------------------------------;
PARSE_SPEC:    LODSB                           ;Get a byte.
               CMP     AL,SPACE                ;Is it a space char or below?
               JA      LEADING_END             ;If no, found start.
               CMP     AL,CR                   ;Is it carriage return?
               JNZ     PARSE_SPEC              ;If no, get next byte.
LEADING_END:   DEC     SI                      ;Adjust pointer to string
                                               ; start.
               MOV     BP,SI                   ;Save start of filespec.
               MOV     BX,SI                   ;Use BX as filename start
                                               ; pointer

FIND_END:      LODSB                           ;Get a byte.
               CMP     AL,":"                  ;Is it a drive delimiter?
               JNZ     CK_SLASH                ;If no, check path delimiter.
               MOV     DL,[SI-2]               ;Else, retrieve drive
                                               ; specifier.
               AND     DL,5FH                  ;Capitalize.
               SUB     DL,"A"                  ;Convert to DOS format.
               MOV     AH,0EH                  ;Change drive.
               INT     21H
               MOV     BX,SI                   ;Save as filename start.
               MOV     AH,19H                  ;Get current disk.
               INT     21H
               CMP     AL,DL                   ;Was it a valid disk request?
               JZ      FIND_END                ;If yes, continue parsing.
FIND_DELIMIT:  LODSB                           ;Else, find delimiter
               CMP     AL,SPACE
               JA      FIND_DELIMIT
               DEC     SI
               MOV     BP,SI                   ; and emulate null string.
               JMP     SHORT PARSE_END

CK_SLASH:      CMP     AL,"\"                  ;Is it a path delimiter?
               JNZ     CK_DELIMITER            ;If no, check switch character.
               MOV     BX,SI                   ;Else, save as filename start.
CK_DELIMITER:  CMP     AL,"/"                  ;Is it a switch delimiter?
               JZ      FOUND_END               ;If yes, end of filespec.
               CMP     AL,SPACE                ;Is it above space character?
               JA      FIND_END                ;If yes, continue until find
                                               ; end.

FOUND_END:     DEC     SI                      ;Adjust.
               PUSH    SI
               MOV     SI,OFFSET CURRENT_DIR   ;Get default directory.
               CALL    GET_DIR
               POP     SI
PARSE_END:     CMP     BP,SI                   ;Any filespec?
               RET                             ;Return result to caller.

;-----------------------------------------------------------;
; INPUT:  DI = 0 for first prompt, DI = 1 for second prompt ;
; OUTPUT: SI -> string start.                               ;
;-----------------------------------------------------------;
PROMPT_USER:   CMP     SYNTAX_FLAG,1           ;If first time through, display
               JZ      PROMPT                  ; syntax message.
               MOV     SYNTAX_FLAG,1
               CALL    CLS
               XOR     DX,DX
               CALL    SET_CURSOR
               MOV     DX,OFFSET SIGNATURE
               CALL    PRINT_STRING

PROMPT:        MOV     DX,OFFSET SOURCE_PROMPT ;Point to appropriate prompt
               OR      DI,DI
               JZ      DISP_PROMPT
               MOV     DX,OFFSET TARGET_PROMPT
DISP_PROMPT:   CALL    PRINT_STRING            ; and display it.
               MOV     DX,OFFSET NOT_FOUND
               CALL    PRINT_STRING
               MOV     SI,OFFSET USER_INPUT    ;User input storage.
               MOV     BYTE PTR [SI],65        ;Maximum of 65 characters.
               MOV     DX,SI
               MOV     AH,0AH
               INT     21H                     ;Buffered Keyboard Input.
               INC     SI
               MOV     BYTE PTR [SI],SPACE     ;Emulate command line entry.
               INC     SI                      ;SI -> string.
               RET

;-------------------------------------------------------------------------;
; INPUT:  BP -> filespec start; SI -> filespec end; BX -> filename start. ;
;         DI -> filespec storage;                                         ;
; OUTPUT: SI -> path end; CY = 0 if filespec exist; CY = 1 if not exist.  ;
;-------------------------------------------------------------------------;
FIND_PATH:     MOV     BYTE PTR [SI],0         ;ASCIIZ the string.
               CMP     BYTE PTR [SI - 1],":"   ;Drive-only?
               JZ      DO_GLOBAL               ;If yes, use global.
CK_ROOT:       MOV     CX,1                    ;CX=1:"\"not=root
                                               ;CX=0:"\"=root.
               CMP     BYTE PTR [BX - 1],"\"   ;Filespec start path delimiter?
               JNZ     CK_PATH                 ;If no, not root.
               CMP     BYTE PTR [BX - 2],":"   ;Else, prefaced with colon
               JZ      ROOT                    ;If yes, then root.
               CMP     BYTE PTR [BX - 2],SPACE ;Prefaced with white space?
               JA      CK_TRAILING             ;If no, then trailing slash?
ROOT:          DEC     CX                      ;Else, root; CX=0 for root
                                               ; flag.
               JMP     SHORT CK_PATH           ;Change default path.

CK_TRAILING:   CMP     BX,SI                   ;Filename start = filespec end?
               JNZ     CK_PATH                 ;If no, not trailing slash.
               MOV     BYTE PTR [BX - 1],0     ;Else, zero out trailing slash
               MOV     BX,OFFSET STAR_DOT_STAR ; and use global filespec.

CK_PATH:       MOV     DX,BP                   ;See if filespec is a path
               CALL    CHANGE_DIR              ; by changing directory.
               JC      CK_FILESPEC             ;If failed, remove filename.
DO_GLOBAL:     MOV     BX,OFFSET STAR_DOT_STAR ;Else, use global for filename.
               JMP     SHORT GOT_FILESPEC      ;Done here.

CK_FILESPEC:   JCXZ    SAVE_DELIMIT            ;Is path root?
                                               ; If yes leave "\".
               DEC     BX                      ;Else, point to slash.
SAVE_DELIMIT:  PUSH    [BX]                    ;Preserve filename start.
               MOV     BYTE PTR [BX],0         ;Temp ASCIIZ twixt path and
                                               ; name.
               CALL    CHANGE_DIR              ;Change directory.
               POP     [BX]                    ;Restore first byte of
                                               ; filename.
               PUSHF                           ;Save CHDIR status.
               JCXZ    CK_FILENAME             ;If root, done here.
               INC     BX                      ;Else, re-adjust filename
                                               ; pointer.
CK_FILENAME:   POPF                            ;Retrieve CHDIR status.
               JNC     GOT_FILESPEC            ;If successful, got filespec.
               CALL    FIND_FIRST              ;Else, check if filename.
               JC      RESTORE_DRIVE           ;If not, invalid filespec.

GOT_FILESPEC:  MOV     AH,19H                  ;Get current drive.
               INT     21H
               ADD     AL,"A"                  ;Convert to ASCII.
               MOV     [DI + SPEC_LENGTH],AL   ;Make a copy.
               STOSB                           ;Store it.
               MOV     AL,":"                  ;Add colon delimiter.
               MOV     [DI + SPEC_LENGTH],AL   ;Make a copy.
               STOSB
               MOV     SI,DI
               ADD     DI,SPEC_LENGTH
               CALL    GET_DIR                 ;Add complete path via DOS.
               DEC     SI                      ;Point to "\".
PATH_END:      LODSB                           ;Make a copy and at the same
               STOSB                           ; time find end of path.
               OR      AL,AL
               JNZ     PATH_END
               DEC     DI                      ;Point to end of path.
               PUSH    DI                      ;Add save it.
               DEC     SI                      ;Adjust spec path pointer also.
               MOV     DI,SI
               MOV     SI,BX
               CALL    ADD_NAME                ;Add spec to end of path.

               MOV     DX,OFFSET CURRENT_DIR   ;Restore default directory.
               CALL    CHANGE_DIR
               POP     SI                      ;Return path end pointer.
               CLC                             ;Successful.

RESTORE_DRIVE: PUSHF
               MOV     DL,DEFAULT_DRIVE        ;Restore default drive.
               MOV     AH,0EH
               INT     21H
               POPF
               RET

;-----------------------------------------------------------------------------;
; INPUT:  DX -> Complete filespec;  BP -> Seg name storage.                    ;
; OUTPUT: BP:DI -> Storage end;  CY = 0 if successful                          ;
;         CY = 1 if segment full or ran out of memory and DX -> Error message. ;
;-----------------------------------------------------------------------------;
FIND_FILES:    PUSH    ES                      ;Preserve extra segment.
               MOV     ES,BP                   ;ES:DI -> filename storage.
               XOR     DI,DI
               MOV     WORD PTR ES:[DI],-1     ;Assume empty directory.
               CALL    FIND_FIRST              ;Any files?
               JC      FILES_DONE              ;If no, assumed right.

FIND_NEXT:     CALL    STORE_NAME              ;Store a filename.
               CALL    CK_AVAIL                ;Make sure we not out of
                                               ; memory.
               JC      FILES_END               ;If not enough, exit.
               MOV     AH,4FH                  ;Find Next Matching.
               INT     21H
               JNC     FIND_NEXT               ;If successful store filename.
               MOV     AX,-1                   ;Else, mark the end with -1.
               STOSW
               CALL    SORT                    ;Sort 'em.
FILES_DONE:    CLC                             ;No error so CY = 0.
FILES_END:     POP     ES                      ;Restore extra segment.
               RET

;---------------------------------------------------------------------;
; INPUT: ES segment of filenames to sort;  Selection sort algorithm.  ;
;---------------------------------------------------------------------;
SORT:          PUSH    DS                      ;Preserve couple registers.
               PUSH    DI
               PUSH    ES
               POP     DS                      ;DS = ES.
               XOR     SI,SI                   ;SI = first record.

NEXT_SORT:     MOV     AX,SI                   ;Carry source pointer in AX.
               MOV     BX,SI                   ;Carry destination pointer in DX.
               ADD     BX,SIZE FILE_RECORD
               CMP     WORD PTR [BX],-1        ;Sort is done when last record.
               JZ      SORT_END

               PUSH    SI                      ;Save record pointer.
NEXT_RECORD:   MOV     SI,AX                   ;Restore inside loop pointers.
               MOV     DI,BX
               MOV     CX,SIZE LIST_NAME       ;Filename length.
               REPZ    CMPSB                   ;Compare the name fields.
               JB      NO_SWITCH               ;If below, no switch.
SWAP:          MOV     AX,BX                   ;Else, AX = selected record.

NO_SWITCH:     ADD     BX,SIZE FILE_RECORD     ;Move to next record in list.
               CMP     WORD PTR [BX],-1        ;End of list?
               JNZ     NEXT_RECORD             ;If no, continue.

               POP     SI                      ;Else, restore outside loop
                                               ; ptr.
               CMP     SI,BX                   ;Did we make a selection?
               JZ      SELECT_LOOP             ;If no, go to next list.

               PUSH    SI                      ;Else, save pointer.
               MOV     CX,(SIZE FILE_RECORD - 2) / 2
               MOV     DI,AX
NEXT_SWAP:     MOV     AX,[DI]                 ;Swap the selection into place.
               MOVSW
               MOV     [SI - 2],AX
               LOOP    NEXT_SWAP
               POP     SI

SELECT_LOOP:   ADD     SI,SIZE FILE_RECORD     ;Next record.
               JMP     NEXT_SORT

SORT_END:      POP     DI                      ;Restore registers.
               POP     DS
               RET

;----------------------------------------------------------------------------;
; INPUT: ES:DI pointer; OUTPUT: CY = 1 if segment full or ran out of memory  ;
;----------------------------------------------------------------------------;
CK_AVAIL:      CMP     DI,65535 - (2 * SIZE FILE_RECORD)   ;End of segment?
               MOV     DX,OFFSET TOO_MANY
               JA      AVAIL_END               ;If yes, too many files.
               MOV     AX,DI                   ;Else, calculate the pointer
               ADD     AX,16 + 15              ; in paragraphs.
               MOV     CL,4
               SHR     AX,CL
               MOV     BX,ES
               ADD     AX,BX
               CMP     AX,TOP_MEMORY           ;Top of memory?
               MOV     DX,OFFSET OUT_OF_MEMORY ;If yes, not enough memory.
               JA      AVAIL_END
               STC
AVAIL_END:     CMC                             ;Complement the carry status.
               RET

;----------------------------------------------------------------------;
; INPUT: BP:DI = current seg:off;  OUTPUT: BP = start of new segment.  ;
;----------------------------------------------------------------------;
CALC_SEG:      ADD     DI,SIZE FILE_RECORD + 15
               MOV     CL,4
               SHR     DI,CL
               ADD     BP,DI
               RET

;--------------------------------------------------------------------------;
; Keyboard subroutines.                                                    ;
; INPUT: BP = BAR_LINE; BX = LISTING_LINE; CX = LAST_BAR; DX = PAGE_LENGTH ;
;--------------------------------------------------------------------------;
PLUS:          MOV     AL,LITTLE_ARROW         ;Use little right arrow for
                                               ; mark.
               JMP     SHORT PLUSMINUS

MINUS:         MOV     AL,SPACE                ;Remove mark with space char.

PLUSMINUS:     PUSH    DS                      ;Preserve some registers.
               PUSH    BX
               CALL    FIND_BAR                ;Find bar record.
               JC      PLUSMINUS_END           ;If on blank line, skip.
               MOV     MARK[SI],AL             ;Else, store the mark.
PLUSMINUS_END: POP     BX                      ;Restore registers.
               POP     DS
               MOV     AH,2
               INT     16H                     ;Shift key pressed?
               TEST    AL,SHIFT_KEYS           ;If no, move down line.
               JZ      DOWN                    ;Else, move up a line.

UP:            DEC     BP                      ;Move bar up a line.
               JL      PAGEKEY_END             ;If < 0, ignore.
               CMP     BP,BX                   ;If bar below top, OK.
               JAE     PAGE_UPDATE
               DEC     BX                      ;Else, move listing up a line.
               JMP     SHORT PAGE_UPDATE

DOWN:          INC     BP                      ;Move bar down a line.
               CMP     BP,CX                   ;If > last line, then ignore.
               JA      PAGEKEY_END
               ADD     DX,BX                   ;Listing top + page length =
               CMP     BP,DX                   ; listing bottom; If bar below
               JB      PAGE_UPDATE             ; listing bottom, OK.
               INC     BX                      ;Else move listing down a line.
               JMP     SHORT PAGE_UPDATE

PGUP:          SUB     BP,DX                   ;Move bar up a page.
               SUB     BX,DX                   ;Move listing up a page.
               JC      HOME                    ;If listing < top, then home.
               JMP     SHORT PAGE_UPDATE       ;Else, OK.

PGDN:          ADD     BX,DX                   ;Move listing down a page.
               CMP     BX,CX                   ;If <= last line, do bar.
               JBE     DO_BAR
               SUB     BX,DX                   ;Else, back to where we were
               MOV     BP,CX                   ; and move bar to last line
               JMP     SHORT PAGE_UPDATE       ; and update.
DO_BAR:        ADD     BP,DX                   ;Move bar down a page.
               CMP     BP,CX                   ;If bar <= last line, OK.
               JBE     PAGE_UPDATE
               MOV     BP,CX                   ;Else, move bar to last line.
               JMP     SHORT PAGE_UPDATE

HOME:          XOR     BP,BP                   ;Move bar to top.
               XOR     BX,BX                   ;Move listing to top.
               JMP     SHORT PAGE_UPDATE

END_KEY:       MOV     BP,CX                   ;Move bar to last line.
               INC     CX                      ;Last line + 1 - page length =
               SUB     CX,DX                   ; top of last page.
               CMP     BX,CX                   ;If less than a full page,
               JG      PAGE_UPDATE             ; then already at last page.
               MOV     BX,CX                   ;Else, move listing to last
                                               ; page.
               JMP     SHORT PAGE_UPDATE

PAGE_UPDATE:   MOV     BAR_LINE,BP             ;Store the new bar
               MOV     LISTING_LINE,BX         ; and listing line start.
PAGEKEY_END:   RET

;----------------------------------------------;
F1:            MOV     AH,FILES_MODE           ;Retrieve current file mode.
               INC     AH                      ;Go to next mode.
               INC     AH
               CMP     AH,ALIKE                ;Is it above last mode, Alike?
               JBE     F1_STORE                ;If no, OK.
               XOR     AH,AH                   ;Else, wrap to All file mode.
               JMP     SHORT F1_STORE          ;Store and update.

S_F1:          MOV     AH,FILES_MODE           ;Retrieve current file mode.
               DEC     AH                      ;Reverse direction.
               DEC     AH
               CMP     AH,ALL                  ;Is it below All file mode?
               JGE     F1_STORE                ;If no, OK.
               MOV     AH,ALIKE                ;Else, wrap to last mode,
                                               ; Alike?

F1_STORE:      MOV     FILES_MODE,AH           ;Store new mode.
               CALL    DISPLAY_MENU            ;Update the menu.
               CALL    MATCH                   ;Update the matches.
               RET

;----------------------------------------------;
F2:            MOV     AL,LITTLE_ARROW         ;Mark all records with little
               JMP     SHORT DO_MARKS          ; right arrow.

;----------------------------------------------;
F3:            MOV     AL,SPACE                ;Mark all records with space
                                               ; char
DO_MARKS:      PUSH    DS
               MOV     DS,SOURCE_SEG
               XOR     SI,SI                   ;DS:SI -> source records.
               JMP     SHORT DO_MARK
NEXT_ALL:      ADD     SI,SIZE FILE_RECORD     ;Next record.
DO_MARK:       CMP     LIST_NAME[SI],-1        ;Is this last record?
               JZ      MARKS_END               ;If yes, done.
               MOV     MARK[SI],AL             ;Else, store mark.
               JMP     SHORT NEXT_ALL
MARKS_END:     POP     DS
               RET

;----------------------------------------------;
F4:            MOV     RESPONSE,OFFSET COPY_MSG
               JMP     SHORT CK_COPY

F5:            MOV     RESPONSE,OFFSET MOVE_MSG
               CMP     FILES_MODE,ALIKE        ;Can't move files in alike
                                               ; mode.
               JNZ     CK_COPY
               CALL    BEEP
               RET

CK_COPY:       PUSH    DS                      ;Preserve data segment.
               MOV     DS,SOURCE_SEG           ;DS:SI -> source records.
               XOR     SI,SI
               XOR     CX,CX                   ;Initialize counter to zero.
               JMP     SHORT COUNT_MARKS       ;Count the marks.
FOUND_MARK:    INC     CX                      ;Increment count.
NEXT_COUNT:    ADD     SI,SIZE FILE_RECORD     ;Next record.
COUNT_MARKS:   CMP     LIST_NAME[SI],-1        ;Last record?
               JZ      GOT_COUNT               ;If yes, got count of marks.
               CMP     DISP_ORDER[SI],-1       ;Else, is record displayed?
               JZ      NEXT_COUNT              ;If no, skip.
               CMP     MARK[SI],LITTLE_ARROW   ;Else, is it marked?
               JNZ     NEXT_COUNT              ;If no, skip.
               JMP     FOUND_MARK              ;Else, count it.
GOT_COUNT:     POP     DS                      ;Restore data segment.

               MOV     MARKED_COUNT,CX         ;Save count of marks.
               JCXZ    COPY_BAR                ;If none marked, copy bar.
               CALL    GET_COUNT               ;Else, convert count to ASCII.
               MOV     BX,OFFSET MARKED_MSG    ;Will display marked message.
               CALL    GET_RESPONSE            ;Ask user if should continue.
               JNZ     COPY_MARKED             ;If confirmed, continue.
               JMP     F4_END                  ;Else, exit.

COPY_MARKED:   PUSH    LISTING_LINE            ;Preserve current page
               PUSH    BAR_LINE                ; and bar line.
               CALL    HOME                    ;Start searching for marked
               XOR     SI,SI                   ; files from home position.
               JMP     SHORT CK_ABORT          ;Go check keypress for abort.

NEXT_REC3:     ADD     SI,SIZE FILE_RECORD     ;Next record.
NEXT_MARKED:   MOV     BP,BAR_LINE             ;Paging commands need line
               MOV     BX,LISTING_LINE         ; page data.
               MOV     CX,LAST_BAR
               MOV     DX,PAGE_LENGTH
               CALL    DOWN                    ;Move bar down a line.

CK_ABORT:      CALL    CK_KEY                  ;Any keypress?
               JNZ     MARKED_END              ;If yes, quite copying.
               CALL    DISP_LISTINGS           ;Else, display current bar.
               PUSH    DS
               MOV     DS,SOURCE_SEG
               MOV     AX,DISP_ORDER[SI]       ;Retrieve display order and
               MOV     BL,MARK[SI]             ; mark of current record.
               POP     DS
               CMP     AX,-1                   ;Is it displayed?
               JNZ     CK_BAR                  ;If yes, see if bar record.
               ADD     SI,SIZE FILE_RECORD     ;Else, next record.
               JMP     CK_ABORT

CK_BAR:        AND     AX,NOT 8000H            ;Else, strip highlight bit.
               CMP     AX,BAR_LINE             ;Is it current line?
               JA      NEXT_MARKED             ;If above, skip for now.
               CMP     BL,LITTLE_ARROW         ;Is it marked?
               JNZ     NEXT_REC3               ;If no, next record.

               MOV     BP,SI                   ;Else, copy; First convert name
               CALL    GET_SOURCE              ; back to dot delimited ASCIIZ.
               CALL    COPY                    ;Copy the file.
               JC      MARKED_END              ;If failed, exit.
               MOV     SI,BP                   ;Else, retrieve record pointer.
               DEC     MARKED_COUNT            ;Decrement marked count.
               JNZ     NEXT_REC3               ;Continue until zero.
               CALL    DISP_LISTINGS           ;Display last asterisk.

MARKED_END:    POP     BAR_LINE                ;Restore bar and page.
               POP     LISTING_LINE
               JMP     SHORT F4_REREAD         ;Done.

;----------------------------------------------;
COPY_BAR:      PUSH    DS
               CALL    FIND_BAR                ;Find bar record.
               POP     DS
               JNC     VALID_BAR               ;Is bar on blank line?
               CALL    BEEP                    ;If yes, beep and exit.
               JMP     SHORT F4_END
VALID_BAR:     MOV     BP,SI                   ;Else, convert name to dot
               CALL    GET_SOURCE              ; delimited ASCIIZ.
               XOR     BX,BX                   ;No "marked files" message.
               CALL    GET_RESPONSE            ;Ask user for confirmation.
               JZ      F4_END                  ;If aborted, exit.
               CALL    COPY                    ;Else, copy the highlighted
                                               ; file.

F4_REREAD:     CMP     RESPONSE,OFFSET MOVE_MSG  ;Did we move files?
               JNZ     READ_TARGET             ;If no, just read target.
               CALL    SOURCE_DIR              ;Else, get new source dir also.
READ_TARGET:   CALL    TARGET_DIR
               JNC     F4_UPDATE
               CALL    MENU_OFFSET             ;Calculate menu offset.
               ADD     DI,80 * 2               ;Place error message on second
               MOV     BH,MENU_ATTR            ; menu line with menu
                                               ; attribute.
               MOV     SI,DX                   ;Error message.
               CALL    WRITE_STRING            ;Write the message.
               MOV     SI,OFFSET PRESS_MSG
               CALL    WRITE_STRING
               CALL    HIDE_CURSOR             ;Rehide the cursor.
               CALL    BEEP                    ;Draw attention with beep.
               CALL    GET_KEY                 ;Pause for keystroke.
               CALL    CLS
               XOR     DX,DX
               CALL    SET_CURSOR
               JMP     ERROR                   ;Abort to DOS.

F4_UPDATE:     CMP     RESPONSE,OFFSET MOVE_MSG  ;Did we do a move?
               JZ      KEEP_BAR                  ;If yes, preserve bar/page.
               CMP     FILES_MODE,UNIQUE         ;Are different files
                                                 ; displayed?
               JNZ     KEEP_BAR                  ;If no, then preserve
                                                 ; bar/page.
               CALL    MATCH                     ;Else, home bar and page.
               JMP     SHORT F4_END
KEEP_BAR:      CALL    DO_MATCH

F4_END:        CALL    HIDE_CURSOR             ;Rehide the cursor.
               CALL    DISPLAY_MENU            ;Redisplay the menu.
               CALL    CLEAR_KEY               ;Clear the keyboard.
               RET                             ;Done.

;--------------------------------------------------;
; OUTPUT:  CY = 1 if failed; CY = 0 if successful. ;
;--------------------------------------------------;
COPY:          MOV     SI,OFFSET SOURCE_NAME   ;Add filename to both source
               MOV     DI,SOURCE_END           ; and target path spec.
               CALL    ADD_NAME
               MOV     SI,OFFSET SOURCE_NAME
               MOV     DI,TARGET_END
               CALL    ADD_NAME

               MOV     DX,OFFSET SOURCE_FILE   ;Get attribute, size and date
               CALL    FIND_FIRST              ; of source file via 
                                               ; Find First.
               MOV     SI,OFFSET DTA
               MOV     DI,OFFSET SOURCE_STATS  ;Store the info.
               MOV     CX,SIZE MATCHING
               REP     MOVSB

               MOV     AX,3D00H                ;Open source file for reading.
               INT     21H
               JNC     SAVE_HANDLE
               JMP     COPY_END                ;If failed, exit.
SAVE_HANDLE:   MOV     DI,AX                   ;Else, save source handle.

               MOV     DX,OFFSET TARGET_FILE   ;Point to target name.
               CALL    FIND_FIRST              ;Does it exist?
               JNC     CK_IF_MOVE              ;If yes, see if move request.
               CALL    DISK_FREE               ;Else, get disk free space.
               JMP     SHORT CK_FREE           ;Go see if enough room.

CK_IF_MOVE:    CMP     RESPONSE,OFFSET MOVE_MSG ;Is it a move request?
               JNZ     CK_IF_SAME               ;If no, see if same as source.
               STC
               JMP     CLOSE_READ              ;Else, exit with error flag.

CK_IF_SAME:    MOV     CL,DTA.ATTRIBUTE        ;Get attribute of target
               XOR     CH,CH
               MOV     SI,CX                   ; and save.
               XOR     CX,1                    ;Flip read-only attribute.
               MOV     AX,4301H                ;Change file mode.
               INT     21H
               MOV     DX,OFFSET SOURCE_FILE   ;Now get source attribute.
               MOV     AX,4300H
               INT     21H
               JNC     CK_CHANGED
               JMP     COPY_END                   ;Exit if error.
CK_CHANGED:    CMP     CL,SOURCE_STATS.ATTRIBUTE  ;Else, see if it has
                                                  ; changed.
               PUSHF                              ;Save compare results.
               MOV     DX,OFFSET TARGET_FILE      ;Restore target attribute.
               MOV     CX,SI
               MOV     AX,4301H                 ;Change file mode.
               INT     21H
               POPF                             ;Retrieve compare results.
               STC                              ;Assume files are the same.
               JNZ     CLOSE_READ               ;If attr changed, they are
                                                ; so exit
               CALL    DISK_FREE                ;Else, get disk free space.
               ADD     AX,DTA.SIZE_LOW
               ADC     DX,DTA.SIZE_HIGH           ;Target size + disk free.
CK_FREE:       SUB     AX,SOURCE_STATS.SIZE_LOW   ;Total - source size.
               SBB     DX,SOURCE_STATS.SIZE_HIGH
               JB      CLOSE_READ                 ;If negative, not enough
                                                  ; room.

CREATE:        MOV     DX,OFFSET TARGET_FILE   ;Create and truncate target
               XOR     CX,CX                   ; file to zero
               MOV     AH,3CH
               INT     21H
               JC      CLOSE_READ
               MOV     SI,AX                   ;Save handle.
               MOV     DS,BUFFER_SEG           ;Read/write buffer.
               XOR     DX,DX                   ;Offset zero.

COPY_READ:     MOV     BX,DI                   ;Retrieve read handle.
               MOV     CX,CS:BUFFER_SIZE       ;Buffer size.
               MOV     AH,3FH
               INT     21H                     ;Read source file.
               JC      COPY_DONE               ;If carry, failed; exit.
               OR      AX,AX                   ;If zero bytes read, done.
               JZ      CHANGE_DATE             ;Change target date to source.

               MOV     CX,AX                   ;Else, bytes read into counter.
               MOV     BX,SI                   ;Retrieve write handle.
               MOV     AH,40H
               INT     21H                     ;Write the buffer to disk.
               JC      COPY_DONE               ;If failed, exit.
               CMP     CX,AX                   ;Write same number as read?
               STC                             ;Assume no.
               JNZ     COPY_DONE               ;If no, failed; exit.
               CMP     CX,CS:BUFFER_SIZE       ;Was it a full read?
               JZ      COPY_READ               ;If yes, there must be more.

CHANGE_DATE:   MOV     BX,SI                         ;Write handle.
               MOV     CX,CS:SOURCE_STATS.FILE_TIME  ;Else, make time/date
               MOV     DX,CS:SOURCE_STATS.FILE_DATE  ; same as source.
               MOV     AX,5701H
               INT     21H
               MOV     DS,CS:SOURCE_SEG        ;Mark success with asterisk.
               MOV     DS:MARK[BP],"*"

COPY_DONE:     PUSH    CS                      ;Restore data segment.
               POP     DS

CLOSE_WRITE:   PUSHF                           ;Save error if any.
               MOV     BX,SI                   ;Close write file.
               MOV     AH,3EH
               INT     21H
               POP     AX                      ;Retrieve flags.
               JC      CLOSE_READ              ;Close successful?
               XCHG    AH,AL                   ;If no, exit with error, else
               SAHF                            ; retrieve write state.

CLOSE_READ:    PUSHF                           ;Save flags.
               MOV     BX,DI                   ;Close read file.
               MOV     AH,3EH
               INT     21H
               POPF                            ;Write file status.

COPY_END:      PUSHF                           ;Save status.
               JNC     CK_DELETE               ;If no carry, successful.
               CALL    HIDE_CURSOR
               CALL    MENU_OFFSET             ;Else, calculate menu offset.
               ADD     DI,80 * 2               ;Place error message on second
               MOV     BH,MENU_ATTR            ; menu line with menu
               MOV     SI,RESPONSE             ; attribute.
               CALL    WRITE_STRING            ;Write the message.
               MOV     SI,OFFSET PRESS_MSG
               CALL    WRITE_STRING
               CALL    BEEP                    ;Draw attention with beep.
               CALL    GET_KEY                 ;Pause for keystroke.
               JMP     SHORT COPY_RETURN

CK_DELETE:     CMP     RESPONSE,OFFSET MOVE_MSG  ;Move request?
               JNZ     COPY_RETURN               ;If no, done here.
               POPF
               MOV     DX,OFFSET SOURCE_FILE     ;Else, delete the source
               MOV     AH,41H                    ; file.
               INT     21H
               PUSHF

COPY_RETURN:   POPF                            ;Retrieve status.
               RET

;----------------------------------------------;
; INPUT: SI -> Filename;  DI -> End of path.   ;
;----------------------------------------------;
ADD_NAME:      MOV     AL,"\"                  ;Backslash delimiter.
               CMP     [DI - 1],AL             ;Is there a delimiter?
               JZ      ADD_IT                  ;If yes, continue.
               STOSB                           ;Else, add delimiter.
ADD_IT:        LODSB                           ;Add the filename.
               CMP     AL,"a"
               JB      GOT_NAME
               CMP     AL,"z"
               JA      GOT_NAME
               AND     AL,5FH                  ;Capitalize.
GOT_NAME:      STOSB
               OR      AL,AL                   ;ASCIIZ.
               JNZ     ADD_IT
               RET
 
;----------------------------------------------;
F6:            PUSH    DS                      ;Preserve segment registers.
               PUSH    ES                      ;Place cursor back on screen at
               MOV     DX,300H                 ; third row in case there is
               CALL    SET_CURSOR              ; a DOS print error message.
               MOV     BX,SOURCE_SEG           ;BX -> source segment.
               XOR     SI,SI                   ;Start of source.
               XOR     DI,DI                   ;Start of target.
               XOR     BP,BP                   ;Start of order.
               JMP     SHORT PRINT_HEADER      ;Print directory header on
                                               ; page.

NEXT_PRINT:    MOV     DS,BX                   ;Source on left side of page.
               CMP     LIST_NAME[SI],-1        ;End of listing?
               JNZ     PRINT1                  ;If no, continue.
               MOV     DS,CS:TARGET_SEG        ;Target listing segment
               CMP     LIST_NAME[DI],-1        ;End of Target listing also?
               JZ      F6_END                  ;If yes, done.

PRINT1:        MOV     DS,BX                   ;Source segment.
               MOV     CX,40                   ;40 characters per half line.
               CALL    DO_LINE                 ;Print a spec.
               XCHG    SI,DI                   ;Target pointer.
               MOV     DS,CS:TARGET_SEG        ;Target segment.
               MOV     CX,40
               CALL    DO_LINE                 ;Print left half of line.
               XCHG    SI,DI                   ;Restore pointers.
               CALL    NEW_LINE                ;CR LF to new line.
               INC     BP                      ;Increment order counter.
               MOV     AX,BP
               XOR     DX,DX
               MOV     CX,54
               DIV     CX
               OR      DX,DX                   ;If MOD 54 = 0 then formfeed.
               JNZ     NEXT_PRINT
               CALL    FORMFEED
PRINT_HEADER:  PUSH    CS                      ;Back to code segment.
               POP     DS
               PUSH    SI                      ;Save some pointers.
               PUSH    BP
               MOV     BP,OFFSET PRINT_CHAR    ;Print directory heading at
               CALL    WRITE_PATH              ; top of each page.
               POP     BP                      ;Restore the pointers.
               POP     SI
               CALL    NEW_LINE                ;Double space before filenames.
               CALL    NEW_LINE
               JMP     NEXT_PRINT              ;Next line.

F6_END:        CALL    FORMFEED                ;Spit out last printed page.
               CALL    HIDE_CURSOR
               POP     ES                      ;Restore segments.
               POP     DS
               RET

;----------------------------------------------------;
; INPUT: DS:SI -> filename.  Entry point at DO_LINE  ;
;----------------------------------------------------;
NEXT_REC2:     ADD     SI,SIZE FILE_RECORD     ;Next filename.
DO_LINE:       CMP     LIST_NAME[SI],-1        ;Last record?
               JZ      BLANK_LINE              ;If yes, blank line.
               MOV     DX,DISP_ORDER[SI]       ;Retrieve display order.
               CMP     DX,-1                   ;Is it displayed?
               JZ      NEXT_REC2               ;If no, next record.
               MOV     AX,OFFSET NOT_RECENT    ;Assume not a recent file.
               TEST    DX,8000H                ;Is it highlighted?
               JZ      COMPARE_PRINT           ;If no, see if current order.
               MOV     AX,OFFSET RECENT        ;Else, use recent codes.
               AND     DX,NOT 8000H            ;Strip highlight bit.
COMPARE_PRINT: CMP     DX,BP                   ;Entry less than order?
               JB      NEXT_REC2               ;If yes, next record.
               JA      BLANK_LINE              ;If above, blank line.
               PUSH    BX
               PUSH    CX
               MOV     BX,AX                   ;Get offset.
               MOV     AL,CS:[BX]              ;Get char or code count.
               CMP     AL,6                    ;Is it above 6?
               JA      PRINT_MARK              ;If yes, assumed right.
               MOV     CL,AL                   ;Else, it's a printer code
                                               ; count.
               XOR     CH,CH                   ;Zero in high half.
NEXT_CODE:     INC     BX                      ;Point to a code.
               MOV     AL,CS:[BX]              ;Retrieve it.
               CALL    PRINT_CHAR              ;Print it.
               LOOP    NEXT_CODE
               MOV     AL,SPACE                ;Indent with a space.
PRINT_MARK:    CALL    PRINT_CHAR
               POP     CX
               POP     BX
               DEC     CX
PRINT_LINE:    LODSB                           ;Else, print the line.
               CALL    PRINT_CHAR
               LOOP    PRINT_LINE
               ADD     SI,7                    ;Pointer date/time/order
               JMP     SHORT DO_LINE_END       ; fields.
BLANK_LINE:    MOV     AL,SPACE                ;Blank line with spaces.
               CALL    PRINT_CHAR
               LOOP    BLANK_LINE
DO_LINE_END:   RET

;----------------------------------------------;
NEW_LINE:      MOV     AL,CR                   ;Carriage return linefeed.
               CALL    PRINT_CHAR
               MOV     AL,LF
               CALL    PRINT_CHAR
               RET

FORMFEED:      MOV     AL,FF                   ;Formfeed.

PRINT_CHAR:    MOV     DL,AL                   ;Print via DOS.
               MOV     AH,5
               INT     21H
               RET

;-----------------------------------------------------------------------;
; OUTPUT: DS:SI -> Highlighted bar record; CY = 1 if bar on blank line. ;
;-----------------------------------------------------------------------;
FIND_BAR:      MOV     DI,BAR_LINE             ;Retrieve bar line.
               XOR     SI,SI                   ;DS:SI -> source records.
               MOV     DS,SOURCE_SEG
               JMP     SHORT GET_BAR
NEXT_BAR:      ADD     SI,SIZE FILE_RECORD     ;Next record.
GET_BAR:       CMP     LIST_NAME[SI],-1        ;End of listing?
               JZ      NO_NAME                 ;If yes, no name.
               MOV     BX,DISP_ORDER[SI]       ;Retrieve display order.
               CMP     BX,-1                   ;Is it displayed?
               JZ      NEXT_BAR                ;If no, next record.
               AND     BX,NOT 8000H            ;Else, strip highlight bit.
               CMP     BX,DI                   ;Is display order same as bar?
               JB      NEXT_BAR                ;If > then next record.
               JA      NO_NAME                 ;If above, then no name.
               CLC                             ;If same, then valid name.
               RET

NO_NAME:       STC
               RET

;-----------------------------------------------------------------;
; INPUT: CX = binary count; OUTPUT: SOURCE_NAME = ASCII of count. ;
;-----------------------------------------------------------------;
GET_COUNT:     PUSH    BX
               PUSH    DI
               MOV     AX,CX                   ;Retrieve number.
               MOV     BX,10                   ;Divisor of ten.
               XOR     CX,CX                   ;Zero in counter.
NEXT_DIV:      XOR     DX,DX                   ;Zero in high half.
               DIV     BX                      ;Divide by ten.
               ADD     DL,"0"                  ;Convert to ASCII.
               PUSH    DX                      ;Save results.
               INC     CX                      ;Also increment count.
               OR      AX,AX                   ;Are we done?
               JNZ     NEXT_DIV                ;Continue until zero.

               MOV     DI,OFFSET SOURCE_NAME
NEXT_NUMBER:   POP     AX                      ;Retrieve numbers.
               STOSB                           ;And store.
               LOOP    NEXT_NUMBER
               XOR     AL,AL                   ;ASCIIZ string.
               STOSB
               POP     DI
               POP     BX
               RET

;--------------------------------------------------------------;
; INPUT: BP -> Source filename; OUTPUT: SOURCE_NAME = filename ;
;--------------------------------------------------------------;
GET_SOURCE:    PUSH    DS
               MOV     DS,SOURCE_SEG           ;DS:SI -> Source name.
               MOV     SI,BP
               MOV     DI,OFFSET SOURCE_NAME   ;Name storage.
               MOV     CX,8                    ;8 characters of name.
NEXT_NAME:     LODSB
               CMP     AL,SPACE                ;End of name?
               JZ      EXTENSION               ;If yes, do extension.
               STOSB
               LOOP    NEXT_NAME
EXTENSION:     MOV     SI,BP                   ;Retrieve name start.
               ADD     SI,9                    ;Move to extension field.
               CMP     BYTE PTR [SI],SPACE     ;Is there any extension?
               JZ      NAME_DONE               ;If no, done.
               MOV     AL,"."                  ;Else, add delimiting dot.
               STOSB
               MOV     CX,3                    ;3 characters for extension.
NEXT_EXT:      LODSB
               CMP     AL,SPACE
               JZ      NAME_DONE
               STOSB
               LOOP    NEXT_EXT
NAME_DONE:     XOR     AL,AL                   ;ASCIIZ.
               STOSB
               POP     DS
               RET

;-----------------------------------------------------------------------------;
; INPUT: BX -> MARKED_MSG if marked; OUTPUT: ZF=1 if cancel; ZF=0 if confirm. ;
;-----------------------------------------------------------------------------;
GET_RESPONSE:  PUSH    BX                      ;Save message pointer.
               CALL    MENU_OFFSET             ;Calculate menu screen offset.
               MOV     BH,MENU_ATTR            ;Menu attribute.
               MOV     CX,80 * 2               ;Blank out the two lines of
                                               ; menu.
NEXT_MENU:     MOV     AL,SPACE
               CALL    WRITE_SCREEN
               LOOP    NEXT_MENU
               MOV     DH,ROWS                 ;Retrieve the rows.
               DEC     DH                      ;Next to last line.
               XOR     DL,DL
               CALL    SET_CURSOR              ;Set the cursor.
               MOV     SI,RESPONSE             ;Write TTY, copy or move
               CALL    TTY_STRING              ; message.
               MOV     SI,OFFSET SOURCE_NAME   ;Write filename or mark count.
               CALL    TTY_STRING
               POP     BX                      ;Retrieve message pointer.
               CMP     BX,OFFSET MARKED_MSG    ;Is it "marked files" message?
               JNZ     DO_TO                   ;If no, skip.
               MOV     SI,BX                   ;Else, display it.
               CALL    TTY_STRING
DO_TO:         MOV     SI,OFFSET TO_MSG        ;Display rest of
               CALL    TTY_STRING              ; "to Target Directory?  Y/N"
               MOV     SI,OFFSET DIRECTORY_MSG ; message.
               CALL    TTY_STRING
               MOV     SI,OFFSET QUERY_MSG
               CALL    TTY_STRING
NEXT_RESPONSE: CALL    GET_KEY                 ;Get a key.
               CMP     AL,ESC_SCAN             ;If ESC, abort.
               JZ      RESPONSE_END
               CMP     AL,N_SCAN               ;If "N", abort.
               JZ      RESPONSE_END
               CMP     AL,Y_SCAN               ;If not "Y", ignore.
               JNZ     NEXT_RESPONSE           ;Else, cursor to
               MOV     DX,300H                 ; third row in case there is
               CALL    SET_CURSOR              ; a DOS critical error message.
               OR      AL,1                    ;Return ZF = 0 to confirm.
RESPONSE_END:  RET
  
;----------------------------------------------;
VIDEO_SETUP:   MOV     AX,500H                 ;Make sure active page is zero.
               INT     10H
               MOV     AX,40H                  ;Point to the ROM BIOS data
               MOV     ES,AX                   ; area

               MOV     AL,ES:CRT_MODE          ;Retrieve current video mode.
               CMP     AL,7                    ;Is it mono mode?
               JZ      GET_ROWS                ;If yes, continue.
               ADD     STATUS_REG,20H          ;Else, adjust status register
               ADD     VIDEO_SEG,800H          ; and video segment.
               CMP     AL,2                    ;Is it BW80?
               JZ      GET_ROWS                ;If yes, continue.
               MOV     HEADING_ATTR,INVERSE_BLUE
               MOV     ACTIVE_ATTR,INTENSE
               MOV     BODY_ATTR,BLUE          ;Else, use color attributes.
               MOV     HIGHLIGHT_ATTR,INTENSE_BLUE
               MOV     MENU_ATTR,INVERSE_BLUE
               MOV     BAR_ATTR,CYAN
               CMP     AL,3                    ;Is it mode CO80?
               JZ      GET_ROWS                ;If yes, continue.
               MOV     AX,300H                 ;Else, change video mode to CO80.
               INT     10H

GET_ROWS:      MOV     AL,ES:CRT_ROWS          ;Retrieve rows - 1.
               OR      AL,AL                   ;BIOS supported?
               JNZ     STORE_ROWS              ;If yes, store
               MOV     AL,24                   ;Else, use 25 lines.
STORE_ROWS:    MOV     ROWS,AL                 ;Store rows.
               XOR     AH,AH
               SUB     AX,4
               MOV     PAGE_LENGTH,AX          ;Page length = display rows-4.

;----------------------------------------------;
DISPLAY_SETUP: PUSH    CS
               POP     ES
               CALL    CLS                     ;Clear screen.
               CALL    HIDE_CURSOR             ;Hide the cursor off screen.

               MOV     BL,MENU_ATTR            ;Turn on border.
               MOV     CL,4
               SHR     BL,CL
               MOV     AH,0BH
               INT     10H

               MOV     SI,OFFSET COPYRIGHT     ;Point to copyright message.
               XOR     DI,DI                   ;Point to top left of display.
               MOV     BH,HEADING_ATTR         ;Use header attribute.
               CALL    WRITE_STRING            ;And display it.
               MOV     AL,BOX
               CALL    WRITE_SCREEN
               MOV     AL,SPACE
               CALL    WRITE_SCREEN
               INC     SI                      ;Bump pointer past LF
               CALL    WRITE_STRING            ; and display rest of header.
               CALL    DISPLAY_DIRS            ;Display directory heading.

               MOV     BP,OFFSET WRITE_SCREEN  ;Display directories.
               CALL    WRITE_PATH

               MOV     BH,BODY_ATTR            ;Body attribute.
               MOV     CX,PAGE_LENGTH          ;Page length.
               MOV     DI,(3 * 160) + (2 * 40) ;Middle of third row.
NEXT_LINE:     MOV     AL,VERT_LINE            ;Display delimiting
               CALL    WRITE_SCREEN            ; vertical lines.
               ADD     DI,(2 * 79)
               LOOP    NEXT_LINE

;----------------------------------------------;
DISPLAY_MENU:  MOV     SI,OFFSET MENU          ;Display menu on bottom two
               CALL    MENU_OFFSET             ; lines.
               MOV     CL,MENU_ATTR            ;Menu attribute.
               MOV     CH,ACTIVE_ATTR          ;Active mode attribute.

               MOV     BH,CL
               CALL    WRITE_STRING            ;"F1"

               CMP     FILES_MODE,ALL
               JNZ     DISPLAY3
               MOV     BH,CH
DISPLAY3:      CALL    WRITE_STRING            ;"All files"

               MOV     BH,CL
               CMP     FILES_MODE,UNIQUE
               JNZ     DISPLAY4
               MOV     BH,CH
DISPLAY4:      CALL    WRITE_STRING            ;"Different files"

               MOV     BH,CL
               CMP     FILES_MODE,ALIKE
               JNZ     DISPLAY5
               MOV     BH,CH
DISPLAY5:      CALL    WRITE_STRING            ;"Alike files"

               MOV     BH,CL
               CALL    WRITE_STRING            ;Print rest of menu
               RET

;----------------------------------------------;
DISPLAY_DIRS:  MOV     BH,ACTIVE_ATTR          ;Directory attribute.
               MOV     DI,80 * 2
               MOV     SI,OFFSET SOURCE_MSG    ;Display "Source Directory"
               CALL    WRITE_STRING
               CALL    WRITE_STRING
               MOV     CX,SOURCE_COUNT
               CALL    WRITE_COUNT             ;Write the source file count.
               MOV     SI,OFFSET TARGET_MSG    ;Display "Target Directory".
               CALL    WRITE_STRING
               MOV     SI,OFFSET DIRECTORY_MSG
               CALL    WRITE_STRING
               MOV     CX,TARGET_COUNT         ;And finally target files
                                               ; count.

WRITE_COUNT:   CALL    GET_COUNT
               MOV     CX,GAP
NEXT_GAP:      MOV     AL,SPACE                ;Space over some.
               CALL    WRITE_SCREEN
               LOOP    NEXT_GAP
               MOV     SI,OFFSET SOURCE_NAME   ;Storage for count in ASCIIZ.
               MOV     CX,40 - DIRECTORY_LEN
NEXT_NUM:      LODSB                           ;Get a number.
               OR      AL,AL                   ;End of string?
               JZ      WRITE_FILES             ;If yes, add "files" message.
               CALL    WRITE_SCREEN
               LOOP    NEXT_NUM
WRITE_FILES:   MOV     SI,OFFSET FILES_MSG
               CALL    WRITE_STRING
NEXT_SPACE:    MOV     AL,SPACE                ;Pad balance with spaces.
               CALL    WRITE_SCREEN
               LOOP    NEXT_SPACE
               RET

;----------------------------------------;
; OUTPUT: DI -> Screen offset for menu.  ;
;----------------------------------------;
MENU_OFFSET:   MOV     AL,2 * 80               ;(Rows * chars) - chars
               MUL     ROWS                    ; = menu offset.
               SUB     AX,2 * 80
               MOV     DI,AX
               RET

;-----------------------------------------------------------------------------;
; INPUT: SI->Filespec; DI->Video buffer; BP=OFFSET WRITE_SCREEN OR PRINT_CHAR;
;-----------------------------------------------------------------------------;
WRITE_PATH:    MOV     SI,OFFSET SOURCE_SPEC   ;Write first string.
               CALL    DISP_FILESPEC
               MOV     SI,OFFSET TARGET_SPEC   ;Write second string.

DISP_FILESPEC: MOV     AL,SPACE                ;Indent one space.
               CALL    BP
               MOV     CX,39
NEXT_FILESPEC: LODSB
               OR      AL,AL                   ;Null terminates string.
               JZ      PAD_SPACES              ;Pad balance with spaces.
               CALL    BP
               LOOP    NEXT_FILESPEC
               JMP     SHORT FILESPEC_END
PAD_SPACES:    MOV     AL,SPACE
               CALL    BP
               LOOP    PAD_SPACES
FILESPEC_END:  RET

;----------------------------------------------------;
; INPUT:  AL = character to write;  BH = attribute.  ;
;----------------------------------------------------;
WRITE_SCREEN:  PUSH    ES
               MOV     ES,CS:VIDEO_SEG         ;Point to screen segment.
               MOV     DX,CS:STATUS_REG        ;Retrieve status register.
               MOV     BL,AL                   ;Store character in BL.

HORZ_RET:      IN      AL,DX                   ;Get status.
               RCR     AL,1                    ;Is it low?
               JC      HORZ_RET                ;If not, wait until it is.
               CLI                             ;No more interrupts.

HWAIT:         IN      AL,DX                   ;Get status.
               RCR     AL,1                    ;Is it high?
               JNC     HWAIT                   ;If no, wait until it is.

               MOV     AX,BX                   ;Retrieve character; now it's
               STOSW                           ; OK to write to screen buffer.
               STI                             ;Interrupts back on.
               POP     ES
               RET                             ;Return

;------------------------------------------------------------------;
; INPUT:  SI -> to string to display;  DI -> where to display it.  ;
;   Entry point is WRITE_STRING.                                   ;
;------------------------------------------------------------------;
WRITE_IT:      CALL    WRITE_SCREEN            ;Write a character.
WRITE_STRING:  LODSB                           ;Retrieve a character.
               CMP     AL,CR                   ;Keep writing until a carriage
               JA      WRITE_IT                ; return or zero encountered.
               RET

;----------------------------------------------;
STORE_NAME:    MOV     SI,OFFSET DTA.FILE_NAME ;Point to filename.
               PUSH    DI
               MOV     AX,SPACE SHL 8 + SPACE  ;Initiate storage with spaces.
               MOV     CX,(SIZE FILE_RECORD - 6) / 2   ;Fill out with spaces.
               REP     STOSW
               POP     DI                      ;Point to start of storage
                                               ; again.
               MOV     CX,SIZE LIST_NAME       ;Store 12 bytes of filename.
NEXT_STORE:    LODSB                           ;Get a byte.
               OR      AL,AL                   ;End of filename?
               JZ      END_STORE               ;If yes, finish with blanks.
               CMP     AL,"."                  ;Is it the period?
               JNZ     STORE_BYTE              ;If no, store.
               SUB     CX,3                    ;Else, store 3 spaces.
               MOV     AL,SPACE
               REP     STOSB
               ADD     CX,3
               JMP     SHORT NEXT_STORE        ;Get next byte.

STORE_BYTE:    STOSB                           ;Store byte.
               LOOP    NEXT_STORE              ;Get next byte.
END_STORE:     MOV     AL,SPACE                ;Pad balance with spaces.
               REP     STOSB

               PUSH    DI                      ;Save pointer.
               ADD     DI,8                    ;Move to end of bytes field.
               MOV     DX,DTA.SIZE_LOW         ;Retrieve high and low words
               MOV     AX,DTA.SIZE_HIGH        ; of size in bytes.
               MOV     BX,10                   ;Convert to decimal.
               STD                             ;Reverse direction.

NEXT_SIZE:     MOV     CX,DX                   ;Low word in CX.
               XOR     DX,DX                   ;Zero in high half.
               DIV     BX                      ;Convert to decimal.
               XCHG    AX,CX                   ;Retrieve low word.
               DIV     BX
               XCHG    AX,DX                   ;Retrieve remainder.
               ADD     AL,"0"                  ;Convert to ASCII.
               STOSB                           ;Store it.
               MOV     AX,CX                   ;Are we done?
               OR      CX,DX
               JNZ     NEXT_SIZE               ;If no, divide again.

               CLD                             ;Back to forward direction.
               POP     DI                      ;Retrieve pointer.
               ADD     DI,11                   ;Move to date field.
DATE:          MOV     DX,DTA.FILE_DATE        ;Retrieve date.
               MOV     AX,DX
               MOV     CL,5                    ;Shift to lowest bits.
               SHR     AX,CL
               AND     AX,1111B                ;Mask off all but month.
               MOV     CL,0FFH                 ;Flag as no leading zeros.
               MOV     CH,"-"                  ;Delimiting character.
               CALL    STORE_WORD              ;Store it.

               MOV     AX,DX                   ;Retrieve date.
               AND     AX,11111B               ;Mask off all but day.
               XOR     CL,CL                   ;Flag include leading zeros.
               MOV     CH,"-"
               CALL    STORE_WORD              ;Store it.

               MOV     AX,DX                   ;Retrieve date for last time.
               MOV     CL,9
               SHR     AX,CL                   ;Mask off all but year.
               ADD     AX,80                   ;Adjust to ASCII.
               CMP     AX,100                  ;Past year 2000?
               JB      DISPLAY_DATE            ;If no, display. Else, adjust
               SUB     AX,100                  ; for next century. (Planning
                                               ; ahead!)
DISPLAY_DATE:  XOR     CL,CL                   ;Display leading zeros.
               MOV     CH,SPACE
               CALL    STORE_WORD              ;Store it.

TIME:          INC     DI                      ;Move to time field.
               MOV     DX,DTA.FILE_TIME        ;Retrieve time.
               MOV     AX,DX
               MOV     CL,11                   ;Shift to hours bits.
               SHR     AX,CL
               PUSH    AX
               CMP     AX,12                   ;Past noon?
               JBE     MERIDIAN
               SUB     AX,12                   ;If yes, adjust.
MERIDIAN:      CMP     AX,0                    ;Midnight?
               JNZ     NOT_MIDNIGHT
               MOV     AX,12                   ;If yes, adjust.
NOT_MIDNIGHT:  MOV     CL,0FFH                 ;Suppress leading zeros.
               MOV     CH,":"
               CALL    STORE_WORD              ;Store it.

               MOV     AX,DX                   ;Retrieve time.
               MOV     CL,5                    ;Shift to minutes bits.
               SHR     AX,CL
               AND     AX,111111B              ;Mask off all but minutes.
               XOR     CL,CL
               POP     DX                      ;Retrieve hours.
               MOV     CH,"p"                  ;Assume PM.
               CMP     DX,12                   ;Is it PM?
               JAE     PM
               MOV     CH,"a"                  ;If no, AM.

PM:            CALL    STORE_WORD              ;Store it.
               INC     DI                      ;Pointer past mark.
               MOV     AX,DTA.FILE_DATE
               STOSW                           ;Store date in DOS format.
               MOV     AX,DTA.FILE_TIME
               STOSW                           ;Store time in DOS format.
               INC     DI                      ;Bump pointer past DISP_ORDER.
               INC     DI
               RET                             ;Done here.

;-----------------------------------------------------------------------;
; Converts a two byte hex number to decimal followed by delimiter.      ;
; INPUT: AX = hex number; BL = 10; CH = delimiter character to store.   ;
;   CL = 0 if zeros are to be stored; CL = -1 if leading zeros ignored. ;
;   ES:DI points to storage.                                            ;
;-----------------------------------------------------------------------;
STORE_WORD:    DIV     BL                      ;Divide by ten.
               ADD     AX,"00"                 ;Convert to ASCII.
               CMP     CL,0                    ;Display leading zero?
               JZ      STORE_IT                ;If yes, store as is.
               CMP     AL,"0"                  ;Is it a leading zero?
               JNZ     STORE_IT                ;If no, store it.
               MOV     AL,SPACE                ;Else, store a space.
STORE_IT:      STOSW
               MOV     AL,CH                   ;Also store delimiter character
               STOSB
               RET

;----------------------------------------------;
CLS:           XOR     CX,CX                   ;Top left corner.
               MOV     DH,ROWS
               MOV     DL,80 - 1
               MOV     BH,BODY_ATTR            ;Normal attribute.
               MOV     AX,600H                 ;Scroll active page.
               INT     10H
               RET

;----------------------------------------------;
GET_DIR:       MOV     BYTE PTR [SI],"\"       ;DOS doesn't preface directory
               INC     SI                      ; with slash so we must.
               XOR     DL,DL
               MOV     AH,47H                  ;Get current directory.
               INT     21H
               RET

CHANGE_DIR:    MOV     AH,3BH                  ;Change current directory.
               INT     21H
               RET

;----------------------------------------------;
FIND_FIRST:    XOR     CX,CX                   ;Normal files.
               MOV     AH,4EH                  ;Find first.
               INT     21H
               RET

;----------------------------------------------;
PRINT_STRING:  MOV     AH,9                    ;Print string via DOS.
               INT     21H
               RET

;----------------------------------------------;
DISK_FREE:     MOV     DL,BYTE PTR TARGET_SPEC ;Target drive.
               SUB     DL,"A" - 1
               MOV     AH,36H                  ;Disk free space.
               INT     21H
               XOR     DX,DX
               MUL     BX                      ;Sectors per cluster * clusters
               MUL     CX                      ;Result times bytes per cluster
               RET                             ; = available bytes.

;----------------------------------------------;
BEEP:          MOV     BX,NOTE                 ;Tone frequency divisor.
               MOV     DX,12H
               XOR     AX,AX
               DIV     BX
               MOV     BX,AX                   ;8253 countdown.

               CALL    DELAY                   ;Wait till clock rolls over.

               MOV     AL,0B6H                 ;Channel 2 speaker functions.
               OUT     43H,AL                  ;8253 Mode Control.
               JMP     $+2                     ;IO delay.
               MOV     AX,BX                   ;Retrieve countdown.
               OUT     42H,AL                  ;Channel 2 LSB.
               JMP     $+2
               MOV     AL,AH                   ;Channel 2 MSB.
               OUT     42H,AL
               IN      AL,61H                  ;Port B.
               OR      AL,3                    ;Turn on speaker.
               JMP     $+2
               OUT     61H,AL

               CALL    DELAY                   ;Delay one second.
               IN      AL,61H                  ;Get Port B again.
               AND     AL,NOT 3                ;Turn speaker off.
               JMP     $+2
               OUT     61H,AL
               RET                             ;Done.

;-----------------------------;
DELAY:         PUSH    DS                      ;Preserve data segment.
               MOV     AX,40H                  ;Point to BIOS data segment.
               MOV     DS,AX
               MOV     AX,DS:[6CH]             ;Retrieve timer low.
NEXT_BEEP:     MOV     DX,DS:[6CH]             ;Retrieve timer low.
               CMP     DX,AX                   ;Have we timed out?
               JZ      NEXT_BEEP               ;If not, wait until second up.
               POP     DS                      ;Restore data segment.
               RET

;----------------------------------------------;
HIDE_CURSOR:   MOV     DH,ROWS                 ;Retrieve CRT rows.
               INC     DH                      ;Move one line below off
                                               ; screen.
               XOR     DL,DL                   ;Column zero.

SET_CURSOR:    XOR     BH,BH                   ;Page zero.
               MOV     AH,2                    ;Set cursor position.
               INT     10H
               RET

;----------------------------------------------;
GET_KEY:       MOV     AH,0                    ;Wait for next keyboard input.
               INT     16H
               XCHG    AH,AL
               RET

CK_KEY:        MOV     AH,1                    ;Is a keystroke available.
               INT     16H
               RET

CLEAR_IT:      CALL    GET_KEY                 ;Read keystrokes until buffer
CLEAR_KEY:     CALL    CK_KEY                  ; empty.
               JNZ     CLEAR_IT
               RET

;----------------------------------------------;
WRITE_TTY:     MOV     AH,0EH
               INT     10H
               RET

TTY:           CALL    WRITE_TTY
TTY_STRING:    LODSB                           ;ASCIIZ marks end of string.
               OR      AL,AL
               JNZ     TTY
               RET

;----------------------------------------------;
EVEN
DTA            =  $
SOURCE_STATS   =  DTA          + SIZE MATCHING
CURRENT_DIR    =  SOURCE_STATS + SIZE MATCHING
SOURCE_SPEC    =  CURRENT_DIR  + SPEC_LENGTH
SOURCE_FILE    =  SOURCE_SPEC  + SPEC_LENGTH
TARGET_SPEC    =  SOURCE_FILE  + SPEC_LENGTH
TARGET_FILE    =  TARGET_SPEC  + SPEC_LENGTH
USER_INPUT     =  TARGET_FILE  + SPEC_LENGTH
SOURCE_NAME    =  USER_INPUT   + 14
STACK_POINTER  =  SOURCE_NAME  + 68 + 256
SOURCE_OFFSET  =  STACK_POINTER

_TEXT          ENDS
               END     START
