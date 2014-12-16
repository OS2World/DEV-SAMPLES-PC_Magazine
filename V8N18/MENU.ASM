                PAGE    66,132          ;
                NAME    MENU            ;
                TITLE   Menu utility    ;
;
; MENU provides a screen oriented interface for use in constructing batch files
; using menu selection and fill-in-the-blanks approaches.
;
; Use:
;
; MENU [/N/D/E] [screen] [template] [out out out ...]
;
; "screen" is the display file that the user sees.  "screen" contains the text
; to be displayed, the display attributes, and display management commands.
; The logical screen may be longer than a physical screen.
;
; "template" is a file that defines the format of the output file "out".
; "template" consists of the exact text to be sent to "out" except for the
; inclusion of bracketed references.  Text of the form [nnn] is replaced by
;
; "out" is the name of the file to receive the final output.  Multiple out
; files may be specified.
;
; Copyright (c) 1989 Ziff Communications Co.
; Written  May 1989 for PC Magazine by Ronald Q. Smith
;
; Constant definitions.
;
; DOS Interface
;
DOS$            EQU     21H             ; DOS function call INT
; Function values for DOS$
DATE$           EQU     2AH             ; Get date
TIME$           EQU     2CH             ; Get time of day
CREATE$         EQU     3CH             ; Create file
OPEN$           EQU     3DH             ; Open file
CLOSE$          EQU     3EH             ; Close file
RDFILE$         EQU     3FH             ; Read file
WRFILE$         EQU     40H             ; Write file
EXIT$           EQU     4CH             ; Return to DOS
STDIN           EQU     0               ; Standard input handle
STDOUT          EQU     1               ; Standard output handle
ERROUT          EQU     2               ; Handle for error messages
;
; BIOS Interface
;
VIDEO$          EQU     10H             ; CRT handler INT
; Function values for VIDEO$
SMODE$          EQU     0               ; Set video mode
CRS$            EQU     2               ; Set cursor position function
RDCRS$          EQU     3               ; Read cursor position function
PAGE$           EQU     5               ; Set video page
RACH$           EQU     8               ; Read attribute and character
WACH$           EQU     9               ; Write attribute and character
WCHR$           EQU     10              ; Write character
VIDSTAT$        EQU     15              ; Get current video state
EGASTAT$        EQU     17              ; Get EGA status
ALTSEL$         EQU     18              ; Alternate select to EGA
;
KYBD$           EQU     16H             ; Keyboard handler INT
;
; Non-printing ASCII characters
;
BS_CHR          EQU     8               ; Back space
TAB_CHR         EQU     9               ; Tab
LF_CHR          EQU     10              ; Line feed
CR_CHR          EQU     13              ; Carriage return
EOF_CHR         EQU     26              ; End-of-file sentinel character
ESC_CHR         EQU     27              ; Esc
;
; Screen constants.
;
SCR_ATTR        EQU     7               ; White on black default
MONO_SEG        EQU     0B000H          ; Monochrome adapter refresh segment
COLOR_SEG       EQU     0B800H          ; Color/EGA adapter refresh segment
;
; I/O constants.
;
L_INB           EQU     512             ; Input buffer size
L_OUTB          EQU     512             ; Output buffer size
EDIT_FLD        EQU     100             ; Maximum number of input fields
;
; BIOS Data segment
;
BIOS_DATA       SEGMENT AT 40H          ;
                ORG     63H             ;
ADDR_6845       DW      ?               ; I/O address of current display
                ORG     87H             ;
EGA_INFO        DB      ?               ; EGA status byte
EGA_MASK        EQU     00001000B       ; EGA active bit (0=active)
BIOS_DATA       ENDS                    ;
;
; Macros.
;
; DBA creates character,attribute pairs from an attribute value (ATTR) and
; a string (STR).  This macro may be used to create values to be copied
; directly to the screen buffer.
;
DBA             MACRO   ATTR,STR        ; DB with attribute
                  IRPC    C,<&STR>      ;
                    DB      '&C',ATTR   ;
                  ENDM                  ;
                ENDM                    ;
;
; Start of program area.
;
CODE            SEGMENT PARA PUBLIC     ;
                ASSUME  CS:CODE,DS:CODE,ES:CODE,SS:CODE ;
;
; Program Segment Prefix area.
;
MENU_PSP        LABEL   BYTE            ; Start of segment
                ORG     80H             ;
P_CNT           DB      ?               ; Number of bytes of parameter supplied
P_CMD           DB      ?               ; Parameter area
;
; MENU Body
;
                ORG     100H            ;
MENU            PROC                    ;
                JMP     INIT            ; Go to initialization code
;
; Data area.
;
;
; Screen handling.
;
SAVEPAGE        DB      ?               ; Save video page
SAVECRS         DW      ?               ; Save original cursor position
FAST            DB      0               ; If non-zero, fast screen update
VIDEO_SEG       DW      MONO_SEG        ; Default video display segment
STATUS_REG      DW      ?               ; Video status register
SCR_COL         DB      80,0            ; Default screen width
SCR_LIN         DB      25,0            ; Default number of lines
DISP_SIZE       DW      24*80*2         ; Default display area size
DISP_LOC        DW      0FFFFH          ; Save area start for screen
EDIT_LAST       DW      ?               ; Last address in edit buffer
ATTRIBUTE       DB      SCR_ATTR        ; Current screen attribute
DOPT            DW      L_SCHR          ; Length of screen character table
EOPT            DW      L_KEYT          ; Length of editing character table
SHOW            DB      0               ; Show fields if set
SCRN_END        DW      ?               ; Location of end of screen
;
; Input field handling.
;
EDIT_NUM        DW      0               ; Index to next input area def
EDIT_AREA       DW      EDIT_FLD DUP(0,0) ; Start and end of input areas
                DW      0,0             ; Last DEF_AREA entry
;
; Constant fields.
;
CONST_NUM       DW      0               ; Index to next constant definition
CONST_AREA      DW      EDIT_FLD DUP(0,0) ; Start and end of constant areas
;
; Defining new input fields.
;
DEF_NUM         DW      0               ; Index to next definition
DEF_AREA        EQU     EDIT_AREA+4     ; Start and end of input areas
                                        ; Only use one real input area
                                        ; when defining new ones
;
; Handles and other I/O related.
;
SCREENFILE      DW      ?               ; Screen file handle
TEMPLFILE       DW      ?               ; Template file handle
IN_CNT          DW      0               ; Characters remaining in input buffer
IN_INDX         DW      ?               ; Next character in input buffer
NUM_OUT         DW      0               ; Number of output files
OUT_HNDL        LABEL   WORD            ;
                DW      64 DUP(0)       ; Output file handles
OUTFILE         DW      ?               ; Current output file handle
OUT_INDX        DW      0               ; Output buffer index
;
; Messages
;
CRLF            DB      CR_CHR,LF_CHR   ;
BIG_MSG         DB      "Screen file is too long." ;
L_BIG           EQU     $-BIG_MSG       ;
SCRN_ERR        DB      'Error reading screen file.' ;
L_SERR          EQU     $-SCRN_ERR      ;
INP_MSG         DB      "Screen file contains unbalanced []'s or too " ;
                DB      'many fields.'  ;
L_INP           EQU     $-INP_MSG       ;
CONST_MSG       DB      "Screen file contains unbalanced {}'s or too " ;
                DB      'many constants.' ;
L_CONST         EQU     $-CONST_MSG     ;
ANSI_MSG        DB      'Illegal ANSI (ESC) sequence.  Only ESC [#;...#m ' ;
                DB      'is allowed.  #=0-47.' ;
L_ANSI          EQU     $-ANSI_MSG      ;
TMPL_ERR        DB      'Error reading template file.' ;
L_TMPL          EQU     $-TMPL_ERR      ;
TMPL_MSG        DB      "Template file contains unbalanced []'s, {}'s, " ;
                DB      "<>'s or a bad field number." ;
L_TBAD          EQU     $-TMPL_MSG      ;
OUT_MSG         DB      'Error writing output file.' ;
L_OUT           EQU     $-OUT_MSG       ;
Q_MSG           DB      'Do you want to quit? YN' ;
L_Q             EQU     $-Q_MSG         ;
ROOM_MSG        DB      'Too many fields' ;
L_ROOM          EQU     $-ROOM_MSG      ;
BAL_MSG         DB      'No field start' ;
L_BAL           EQU     $-BAL_MSG       ;
NEST_MSG        DB      'Fields may not be nested' ;
L_NEST          EQU     $-NEST_MSG      ;
COLOR_MSG       DB      'Text='         ;
TCLR            DB      '   Bkgr='      ;
BCLR            DB      '  Blink='      ;
BLNK            DB      ' '             ;
L_COLOR         EQU     $-COLOR_MSG     ;
;
; Date and time values
;
DOW             DW      0               ; Day of week index (0-6)*3
MON             DW      0               ; Month index (0-12)*3
MONTH           DW      'MM'            ; Month
DAY             DW      'DD'            ; Day
CENTURY         DW      'CC'            ; Century
YEAR            DW      'YY'            ; Year
HOUR            DW      'hh'            ; Hours
MINUTE          DW      'mm'            ; Minutes
SECOND          DW      'ss'            ; Seconds
DOW_TAB         LABEL   BYTE            ; Day of week abbreviations
                DB      'Sun'           ;
                DB      'Mon'           ;
                DB      'Tue'           ;
                DB      'Wed'           ;
                DB      'Thu'           ;
                DB      'Fri'           ;
                DB      'Sat'           ;
MON_TAB         LABEL   BYTE            ; Month abbreviations
                DB      'Jan'           ;
                DB      'Feb'           ;
                DB      'Mar'           ;
                DB      'Apr'           ;
                DB      'May'           ;
                DB      'Jun'           ;
                DB      'Jul'           ;
                DB      'Aug'           ;
                DB      'Sep'           ;
                DB      'Oct'           ;
                DB      'Nov'           ;
                DB      'Dec'           ;
TD_TAB          LABEL   WORD            ; Pattern table for time/date
                DW      'DW'            ;
                DW      'MN'            ;
                DW      'MM'            ;
                DW      'DD'            ;
                DW      'CC'            ;
                DW      'YY'            ;
                DW      'hh'            ;
                DW      'mm'            ;
                DW      'ss'            ;
L_TD            EQU     ($-TD_TAB)/2    ; Number entries
TD_LOC          DW      DOW             ;
                DW      MON             ;
                DW      MONTH           ;
                DW      DAY             ;
                DW      CENTURY         ;
                DW      YEAR            ;
                DW      HOUR            ;
                DW      MINUTE          ;
                DW      SECOND          ;
;
; Key handling tables.
;
KEY_TAB         LABEL   WORD            ; Keys requiring special handling
                DW      CR_CHR          ; Carriage return
                DW      LF_CHR          ; Ctrl Enter
                DW      TAB_CHR         ; Tab
                DW      ESC_CHR         ; Esc
                DW      BS_CHR          ; Backspace
                DW      15*256          ; Back tab
                DW      71*256          ; Home
                DW      72*256          ; Up arrow
                DW      73*256          ; PgUp
                DW      75*256          ; Left arrow
                DW      77*256          ; Right arrow
                DW      79*256          ; End
                DW      80*256          ; Down arrow
                DW      81*256          ; PgDn
                DW      82*256          ; Ins
                DW      83*256          ; Del
                DW      117*256         ; Ctrl End
                DW      119*256         ; Ctrl Home
                DW      59*256          ; F1
L_KEYT          EQU     ($-KEY_TAB)/2   ; Number entries if not editing screen
                DW      60*256          ; F2
                DW      61*256          ; F3
                DW      62*256          ; F4
                DW      63*256          ; F5
                DW      64*256          ; F6
                DW      65*256          ; F7
                DW      66*256          ; F8
                DW      67*256          ; F9
                DW      68*256          ; F10
                DW      131*256         ; Alt =
L_EDIT          EQU     ($-KEY_TAB)/2   ; Number of entries if editing screen
KEY_VECT        LABEL   WORD            ; Vector for key processing routines
                DW      EDIT_PUT        ;
                DW      CR_SUB          ;
                DW      CENTER_SUB      ;
                DW      TAB_SUB         ;
                DW      ESC_SUB         ;
                DW      BS_SUB          ;
                DW      BTAB_SUB        ;
                DW      HOME_SUB        ;
                DW      UP_SUB          ;
                DW      PGUP_SUB        ;
                DW      LEFT_SUB        ;
                DW      RIGHT_SUB       ;
                DW      END_SUB         ;
                DW      DOWN_SUB        ;
                DW      PGDN_SUB        ;
                DW      INS_SUB         ;
                DW      DEL_SUB         ;
                DW      CEND_SUB        ;
                DW      CHOME_SUB       ;
                DW      HELP_SUB        ;
                DW      SETND_SUB       ;
                DW      FSHOW_SUB       ;
                DW      FDEL_SUB        ;
                DW      CNSTRT_SUB      ;
                DW      CNEND_SUB       ;
                DW      FSTRT_SUB       ;
                DW      FEND_SUB        ;
                DW      ATTR_SUB        ;
                DW      COLOR_SUB       ;
                DW      FORCE_SUB       ;
;
; Search and vector table for screen file conversion.
;
SCR_CHR         LABEL   BYTE            ;
                DB      CR_CHR,LF_CHR,ESC_CHR ;
L_DOPT          EQU     $-SCR_CHR       ; Length if display only
                DB      '\[]{}'         ;
L_SCHR          EQU     $-SCR_CHR       ;
SCR_VECT        LABEL   WORD            ;
                DW      SCR_PUT         ; If no match, just put character
                DW      SCR_CR          ;
                DW      SCR_LF          ;
                DW      SCR_ANSI        ;
                DW      SCR_FORCE       ;
                DW      SCR_LBRK        ;
                DW      SCR_RBRK        ;
                DW      SCR_LBRACE      ;
                DW      SCR_RBRACE      ;
;
; Search and vector table for pattern replacement.
;
REPL_CHR        LABEL   BYTE            ;
                DB      '\?=|]'        ;
L_RCHR          EQU     $-REPL_CHR      ;
REPL_VECT       LABEL   WORD            ;
                DW      REPL_PUT        ; If no match, just put character
                DW      COPY_FORCE      ;
                DW      COPY_ONE        ;
                DW      COPY_LINE       ;
                DW      COPY_STOP       ;
                DW      COPY_REST       ;
;
; Search and vector table for template file processing.
;
TMPL_CHR        LABEL   BYTE            ;
                DB      '\[]{}<>'       ;
L_TCHR          EQU     $-TMPL_CHR      ;
TMPL_VECT       LABEL   WORD            ;
                DW      TMPL_PUT        ; If no match, just put character
                DW      TMPL_FORCE      ;
                DW      TMPL_SENT       ;
                DW      TMPL_ERROR      ;
                DW      TMPL_CONST      ;
                DW      TMPL_ERROR      ;
                DW      TMPL_FILE       ;
                DW      TMPL_ERROR      ;
;
; Attribute tables for ANSI sequence.
;
ATTR_MASK       LABEL   BYTE            ;
                DB      0               ; White on black
                DB      0FFH            ; Bold
                DB      0FFH            ;
                DB      0FFH            ;
                DB      0F8H            ; Underline
                DB      0FFH            ; Blink
                DB      0FFH            ;
                DB      077H            ; Reverse video
                DB      070H            ; Invisible
                DB      29-8 DUP(0FFH)  ; Unused
                DB      070H            ; Black foreground
                DB      070H            ; Red foreground
                DB      070H            ; Green foreground
                DB      070H            ; Yellow foreground
                DB      070H            ; Blue foreground
                DB      070H            ; Magenta foreground
                DB      070H            ; Cyan foreground
                DB      070H            ; White foreground
                DB      39-37 DUP(0FFH) ; Unused
                DB      0FH             ; Black background
                DB      0FH             ; Red background
                DB      0FH             ; Green background
                DB      0FH             ; Yellow background
                DB      0FH             ; Blue background
                DB      0FH             ; Magenta background
                DB      0FH             ; Cyan background
                DB      0FH             ; White background
L_ATTR          EQU     $-ATTR_MASK     ; Number of attribute values
ATTR_VAL        LABEL   BYTE            ;
                DB      7               ; White on black
                DB      8               ; Bold on
                DB      0               ;
                DB      0               ;
                DB      1               ; Underline
                DB      80H             ; Blink
                DB      0               ;
                DB      0               ; Reverse
                DB      0               ; Hidden
                DB      29-8 DUP(0)     ; Unused
                DB      0               ; Black foreground
                DB      4               ; Red foreground
                DB      2               ; Green foreground
                DB      6               ; Yellow foreground
                DB      1               ; Blue foreground
                DB      5               ; Magenta foreground
                DB      3               ; Cyan foreground
                DB      7               ; White foreground
                DB      39-37 DUP(0)    ; Unused
                DB      0               ; Black background
                DB      40H             ; Red background
                DB      20H             ; Green background
                DB      60H             ; Yellow background
                DB      10H             ; Blue background
                DB      50H             ; Magenta background
                DB      30H             ; Cyan background
                DB      70H             ; White background
;
; Status line.
;
C10             DB      10,0            ; Constant 10
C100            DB      100             ; Constant 100
STAT_ATTR       EQU     1FH             ; White on blue
STATUS_MSG      DB      'COL='          ;
STAT_COL        DB      'xxx, ROW='     ;
STAT_ROW        DB      'xxx, LN='      ;
STAT_LIN        DB      'xxx'           ;
                DB      ' '             ;
STAT_INS        DB      ' '             ;
                DB      ' '             ;
STAT_Q          DB      ' '             ;
                DB      71-($-STATUS_MSG) DUP(' ') ;
Q_LNG           EQU     $-STAT_Q        ; Max length of messages
                DB      'F1 = Help'     ;
                DB      80 DUP(' ')     ; Status lines up to 160 characters
;
; Menu for selecting colors and attributes.
;
COLOR_MNU       LABEL   WORD            ;
                DBA %(SCR_ATTR OR 8),<                 COLORS                 >
                DBA     SCR_ATTR,<                                        > ;
                DBA     SCR_ATTR,<Select text color(0-15) background(0-7) > ;
                DBA     SCR_ATTR,<       and blink(Y,N)                   > ;
                DBA     SCR_ATTR,<Press Enter when done                   > ;
                DBA     SCR_ATTR,<                                        > ;
                DBA          70H,< 0 = Black          > ;
                DBA            8,< 8 = Dark grey      > ;
                DBA            1,< 1 = Blue           > ;
                DBA            9,< 9 = Bright blue    > ;
                DBA            2,< 2 = Green          > ;
                DBA           10,<10 = Bright green   > ;
                DBA            3,< 3 = Cyan           > ;
                DBA           11,<11 = Bright cyan    > ;
                DBA            4,< 4 = Red            > ;
                DBA           12,<12 = Bright Red     > ;
                DBA            5,< 5 = Magenta        > ;
                DBA           13,<13 = Bright Magenta > ;
                DBA            6,< 6 = Brown          > ;
                DBA           14,<14 = Yellow         > ;
                DBA            7,< 7 = White          > ;
                DBA           15,<15 = Bright white   > ;
L_CTAB          EQU     ($-COLOR_MNU)/80        ; Number of lines in menu
;
; HELP display
;
HELP_MNU        LABEL   WORD                    ;
                DBA %(SCR_ATTR OR 8),<            KEY DEFINITIONS             >
                DBA     SCR_ATTR,<                                        > ;
                DBA     SCR_ATTR,<Press Enter when done                   > ;
                DBA     SCR_ATTR,<                                        > ;
                DBA     SCR_ATTR,<Esc = Quit          > ;
                DBA     SCR_ATTR,<Ctrl Enter = Done   > ;
                DBA     SCR_ATTR,<F1 = Key definition > ;
                DBA     SCR_ATTR,<Enter = Field done  > ;
                DBA     SCR_ATTR,<Tab = Next field    > ;
                DBA     SCR_ATTR,<ShiftTab = Tab back > ;
                DBA     SCR_ATTR,<Home = Field start  > ;
                DBA     SCR_ATTR,<End = Field end     > ;
                DBA     SCR_ATTR,<Ctrl Home = Top     > ;
                DBA     SCR_ATTR,<Ctrl End = Bottom   > ;
                DBA     SCR_ATTR,<Ins = Insert mode   > ;
                DBA     SCR_ATTR,<Del = Delete char   > ;
L_HELP          EQU     ($-HELP_MNU)/80 ; Number of lines if not editing
                DBA     SCR_ATTR,<Alt= = Insert key   > ;
                DBA     SCR_ATTR,<F2 = Set end screen > ;
                DBA     SCR_ATTR,<F3 = Display Fields > ;
                DBA     SCR_ATTR,<F4 = Delete Field   > ;
                DBA     SCR_ATTR,<F5 = Start Constant > ;
                DBA     SCR_ATTR,<F6 = End Constant   > ;
                DBA     SCR_ATTR,<F7 = Start Field    > ;
                DBA     SCR_ATTR,<F8 = End Field      > ;
                DBA     SCR_ATTR,<F9 = Select color   > ;
                DBA     SCR_ATTR,<F10 = Color char    > ;
L_HMNU          EQU     ($-HELP_MNU)/80 ; Number of lines in menu
;
; Code area.
;
BEGIN:                                  ;
;
; Copy screen file to editing buffer.
; Editing buffer is layed out in screen format.
;
                MOV     DI,OFFSET EDIT_LOC ;
                MOV     AH,SCR_ATTR     ; Default attribute
                MOV     BX,SCREENFILE   ;
                CMP     DOPT,L_DOPT     ; If /D option, allow STDIN
                JE      SCR_LINE        ;
                OR      BX,BX           ; Any screen file?
                JZ      SCR_DONE        ; No, Just use an empty file
;
; Get next character and check for special cases.
; For CR, treat as end of line and skip an immediately following LF.
; For LF, treat as end of line.
; For ESC, process ANSI SGR sequence.
; For \, use next character even if it is a special character.
; For [], build input field
; For {}, build constant field
; For anything else, just use the character.
;
SCR_LINE:                               ;
                MOV     DX,WORD PTR SCR_COL ; Number of columns on screen
SCR_GET:                                ;
                CALL    GET_CHR         ;
                JZ      SCR_END         ; If no more characters
SCR_GOT:                                ;
                MOV     CX,DOPT         ; Length for display type
                MOV     SI,OFFSET SCR_CHR ;
                CALL    TBL_SRCH        ; Find character type
                JMP     SCR_VECT[SI]    ; Branch on character type
;
; Just put the character and the current attribute in the display.
;
SCR_PUT:                                ;
                CMP     DI,EDIT_LAST    ; Buffer full?
                JA      SCR_ERROR       ; File too big
                STOSW                   ; Store character
                DEC     DX              ; Starting a new line on screen?
                JNS     SCR_GET         ; No
                ADD     DX,WORD PTR SCR_COL ; Chars remaining in new line
                JMP     SCR_GET         ;
;
; Got a line feed (LF) which always means end of record.
;
SCR_LF:                                 ;
                CALL    SCR_PAD         ; Close out line
                JMP     SCR_LINE        ; and start another
;
; Got a CR which means end of record.  Must check for a line feed following
; and skip it if found.
;
SCR_CR:                                 ;
                CALL    SCR_PAD         ; Close out line
                MOV     DL,SCR_COL      ; Start new line
                CALL    GET_CHR         ; Get next character
                JZ      SCR_DONE        ; No more characters
                CMP     AL,LF_CHR       ; Is it a LF?
                JNE     SCR_GOT         ; No, go process it
                JMP     SCR_GET         ; Yes, go get next character
;
; End of file
;
SCR_END:                                ;
                CMP     DL,SCR_COL      ; Started a line?
                JAE     SCR_DONE        ; No
                CALL    SCR_PAD         ; Fill out line to end
SCR_DONE:                               ;
                JMP     EDIT_RDY        ;
;
; Insert spaces into screen line for remainder of line.
; DX = space count
;
SCR_PAD:                                ;
                MOV     CX,DX           ; Remaining character count
                MOV     AL,' '          ; Space character.
        REP     STOSW                   ;
                MOV     DX,CX           ; No characters remaining
                CMP     DI,EDIT_LAST    ; Overflow?
                JA      SCR_ERROR       ; Yes
                RET                     ;
;
; Expanded file is too big.
;
SCR_ERROR:                              ;
                MOV     DX,OFFSET BIG_MSG ;
                MOV     CX,L_BIG        ;
                JMP     ERROR_DSP       ;
;
; Found a \.  Put the next character no matter what it is.
;
SCR_FORCE:                              ;
                CALL    GET_CHR         ;
                JZ      SCR_END         ;
                JMP     SCR_PUT         ;
;
; Found a [.  Start input field.
;
SCR_LBRK:                               ;
                MOV     SI,EDIT_NUM     ; Loc of next input area control
                CMP     SI,EDIT_FLD*4   ; Already too many?
                JAE     INP_ERROR       ; No
                CMP     EDIT_AREA[SI],0 ; Already started an input area?
                JNZ     INP_ERROR       ;
                MOV     EDIT_AREA[SI],DI ; Save start of input area
                JMP     SCR_GET         ; Go get next character
;
; Found a ].  End input field.
;
SCR_RBRK:                               ;
                MOV     SI,EDIT_NUM     ;
                CMP     SI,EDIT_FLD*4   ; Already too many?
                JAE     INP_ERROR       ; No
                CMP     EDIT_AREA[SI],0 ; Start of area found?
                JZ      INP_ERROR       ; No, error
                MOV     EDIT_AREA[SI+2],DI ; Save end of area
                ADD     EDIT_NUM,4      ; Move to next area
                JMP     SCR_GET         ;
INP_ERROR:                              ; Unbalanced or too many []'s
                MOV     DX,OFFSET INP_MSG ;
                MOV     CX,L_INP        ;
                JMP     ERROR_DSP       ; Go display error message
;
; Found an ANSI sequence.  Form new attribute value.
;
SCR_ANSI:                               ;
                CALL    GET_CHR         ; We have the Esc, look for [
                JZ      ANSI_ERROR      ;
                CMP     AL,'['          ; ESC [ ?
                JNE     ANSI_ERROR      ; No
                PUSH    DX              ;
                MOV     CL,4            ;
SCR_ALP:                                ;
                CALL    DTB             ; Get binary value
                CMP     DX,L_ATTR       ; Legal attribute value?
                JAE     ANSI_ERROR      ; No, error
                MOV     SI,DX           ;
                AND     AH,ATTR_MASK[SI] ; Mask attribute to be changed out
                OR      AH,ATTR_VAL[SI] ; Put in new value
                CMP     DL,7            ; Reverse video?
                JNE     SCR_INV         ; No
                ROL     AH,CL           ;
SCR_INV:                                ;
                CMP     DL,8            ; Canceled(invisible)?
                JNE     SCR_SEP         ; No
                MOV     DH,AH           ; Make foreground=background
                SHR     DH,CL           ;
                OR      AH,DH           ;
SCR_SEP:                                ;
                CMP     AL,';'          ; Sub-field separator?
                JE      SCR_ALP         ; Yes, continue
                CMP     AL,'m'          ; End of SGR sequence?
                JNE     ANSI_ERROR      ; No
                POP     DX              ;
                JMP     SCR_GET         ; Yes
ANSI_ERROR:                             ; Not a supported Esc sequence
                MOV     DX,OFFSET ANSI_MSG ;
                MOV     CX,L_ANSI       ;
                JMP     ERROR_DSP       ;
;
; { indicating beginning of constant area.
;
SCR_LBRACE:                             ;
                MOV     SI,CONST_NUM    ; Loc of next constant area control
                CMP     SI,EDIT_FLD*4   ; Already too many?
                JAE     CONST_ERROR     ; No
                CMP     CONST_AREA[SI],0 ; Already started a constant area?
                JNZ     CONST_ERROR     ;
                MOV     CONST_AREA[SI],DI ; Save start of constant area
                JMP     SCR_GET         ; Go get next character
;
; Found a }.  End constant area.
;
SCR_RBRACE:                             ;
                MOV     SI,CONST_NUM    ;
                CMP     SI,EDIT_FLD*4   ; Already too many?
                JAE     CONST_ERROR     ; No
                CMP     CONST_AREA[SI],0 ; Start of area found?
                JZ      CONST_ERROR     ; No, error
                MOV     CONST_AREA[SI+2],DI ; Save end of area
                ADD     CONST_NUM,4     ; Move to next area
                JMP     SCR_GET         ;
CONST_ERROR:                            ;
                MOV     CX,L_CONST      ;
                MOV     DX,OFFSET CONST_MSG ;
                JMP     ERROR_DSP       ;
;
; Check for unbalanced []'s and {}'s.
;
EDIT_RDY:                               ;
                MOV     SI,EDIT_NUM     ;
                CMP     SI,EDIT_FLD*4   ; Area full?
                JAE     EDIT_BRACE      ; Yes, everything is OK
                CMP     EDIT_AREA[SI],0 ; Started next field?
                JZ      EDIT_BRACE      ; No
                JMP     INP_ERROR       ; Yes, error
EDIT_BRACE:                             ;
                MOV     SI,CONST_NUM    ;
                CMP     SI,EDIT_FLD*4   ; Full?
                JAE     EDIT_OK         ;
                CMP     CONST_AREA[SI],0 ; Started next constant.
                JNZ     CONST_ERROR     ;
EDIT_OK:                                ;
                DEC     DI              ; Update end of file
                DEC     DI              ;
;
; If the /E option is set, copy all existing input field definitions to the
; New field area and set the entire display to a single input field.
;
                CMP     EOPT,L_EDIT     ; Editing a screen file?
                JNE     EDIT_NORM       ; No normal file editing
                MOV     CX,EDIT_NUM     ; Length to copy
                MOV     SI,OFFSET EDIT_AREA-1 ; Copy input definition to
                ADD     SI,CX           ;
                MOV     DI,OFFSET DEF_AREA-1 ; new input definitions
                ADD     DI,CX           ;
                MOV     DEF_NUM,CX      ;
                STD                     ; Overlapping fields
        REP     MOVSB                   ;
                CLD                     ;
                MOV     EDIT_NUM,4      ; Define a single input field
                MOV     EDIT_AREA,OFFSET EDIT_LOC ; covering the entire file
                MOV     DI,EDIT_LAST    ;
                MOV     EDIT_AREA+2,DI  ;
                MOV     SCRN_END,DI     ; Default end of screen definition
EDIT_NORM:                              ;
                MOV     EDIT_LAST,DI    ;
                CMP     DI,OFFSET EDIT_LOC-2 ; Empty file?
                JA      EDIT_NMT        ; No
                JMP     CENTER_SUB      ; Yes, just exit
EDIT_NMT:                               ;
;
; Display first screen of file.
;
                CALL    CHOME_SUB       ; Display first page
;
; Now get a key and process editing commands.
;
EDIT_FILE:                              ;
                XOR     AH,AH           ;
                INT     KYBD$           ; Read next character
                OR      AL,AL           ; Extended key?
                JZ      EDIT_XTND       ; Yes
                XOR     AH,AH           ; Clear scan code
EDIT_XTND:                              ;
;
; Determine type of key and switch to proper routine to handle that key type.
;
                PUSH    SI              ;
                MOV     CX,EOPT         ;
                MOV     SI,OFFSET KEY_TAB ;
                CALL    WTBL_SRCH       ; Find matching entry
                MOV     BX,SI           ;
                POP     SI              ;
                CALL    KEY_VECT[BX]    ; Go to key routine
                JMP     EDIT_FILE       ;
;
; Put character in file and display.  All normal keys.
;
EDIT_PUT:                               ;
                CMP     AL,0            ; Don't put NULs
                JZ      EDIT_STATUS     ;
EDIT_FORCE:                             ;
                CALL    FIND_AREA       ; Are we in an input field?
                JC      EDIT_STATUS     ; No, do nothing
                CMP     STAT_INS,' '    ; Are we inserting?
                JE      EDIT_NINS       ; No, just store the character
;
; Insert a character in this input area.
;
                PUSH    DI              ;
                PUSH    SI              ;
                MOV     DI,EDIT_AREA[BX+2] ; Amount to move
                DEC     DI              ;
                DEC     DI              ;
                CMP     SI,DI           ; At end of area?
                JAE     EDIT_NMV        ; Yes, don't move anything
                MOV     CX,DI           ;
                SUB     CX,SI           ;
                LEA     SI,[DI-2]       ;
                SHR     CX,1            ;
                STD                     ;
        REP     MOVSW                   ; Copy characters
                CLD                     ;
EDIT_NMV:                               ;
                POP     SI              ;
                POP     DI              ;
                MOV     [SI],AL         ;
                CALL    DISP_SCREEN     ; Display the modified field
                JMP     SHORT RIGHT_SUB ;
;
; Put character in file buffer and display.
;
EDIT_NINS:                              ;
                MOV     [SI],AL         ; Put key in file
                MOV     AH,[SI+1]       ;
                CALL    WRITE_SCREEN    ;
                DEC     DI              ; Don't move cursor here
                DEC     DI              ;
;
; Increment cursor position.
;
RIGHT_SUB:                              ; Right arrow
                MOV     AX,1            ;
;
; General logic to move the cursor.
; If it would move outside the file, it is moved the maximum amount.
; If it moves outside the current screen, the screen is moved.
; This logic is only good for moves of <8000H bytes.
; Entered with AX = Amount to move cursor, positive or negative.
;
MOVE_CRS:                               ;
                CWD                     ; Extend sign
                SHL     AX,1            ; Make into word offset
                ADD     AX,SI           ; Adjust file pointer
                ADC     DX,0            ;
                JS      CHOME_SUB       ; Negative is before start
                JNZ     CEND_SUB        ; Too large, so after end
                CMP     AX,OFFSET EDIT_LOC ; Before start of file?
                JB      CHOME_SUB       ; Yes
                CMP     AX,EDIT_LAST    ; Beyond end?
                JA      CEND_SUB        ; Yes
;
; Move to a specific display position.
; Because we could be moving 16384 (8000H) bytes or more, we must handle the
; calculations with double precision arithmetic.
; Enter with AX = New display position.
;
MOVE_TO:                                ;
                XCHG    SI,AX           ; New file position
                SUB     AX,SI           ; Distance from old to new
                SBB     DX,DX           ; Sign extend distance to high order
                SUB     DI,AX           ; New cursor index
                ADC     DX,0            ; Slight cheat knowing sign of DI
                JS      MOVE_FWD        ; DI>64K, move screen forward
                JNZ     MOVE_BACK       ; DI<0, move screen backward
                CMP     DI,DISP_SIZE    ; Off end of screen?
                JAE     MOVE_FWD        ; Must move screen forward
                CALL    FIND_AREA       ; Get next input field
                JNC     EDIT_STATUS     ; Already in one
                MOV     AX,EDIT_AREA[BX] ; Start of next area
                SUB     AX,SI           ; Offset to start of next area
                JB      EDIT_STATUS     ; Don't move back to area
                MOV     CX,AX           ;
                ADD     CX,DI           ; Cursor index of next area
                SHR     AX,1            ;
                CMP     CX,DISP_SIZE    ; Still on screen?
                JB      MOVE_CRS        ; Yes, move cursor to input area
;
; Update status line with cursor position and move video cursor.
;
EDIT_STATUS:                            ;
                CALL    STAT_CLR        ; Clear any message in status line
                CALL    STATUS          ; Display status line
                XOR     BH,BH           ; Video page 0
                MOV     AX,DI           ;
                SHR     AX,1            ;
                DIV     SCR_COL         ; Compute new cursor position
                XCHG    AL,AH           ;
                MOV     DX,AX           ;
                MOV     AH,CRS$         ; Update cursor position
                INT     VIDEO$          ;
                RET                     ;
;
; Ctrl Home = Go to top of display.
;
CHOME_SUB:                              ; Ctrl Home
                MOV     SI,OFFSET EDIT_LOC ; Move back to start
;
; Move display back until new position is in first line on screen.
;
MOVE_BACK:                              ;
                XOR     DI,DI           ; Cursor line is top of screen
                JMP     SHORT MOVE_SCRN ;
;
; Move display forward until new position is in last line on screen.
;
MOVE_FWD:                               ;
                MOV     DI,DISP_SIZE    ;
                SUB     DI,WORD PTR SCR_COL ; Cursor is in last line
                SUB     DI,WORD PTR SCR_COL ;
MOVE_SCRN:                              ;
                LEA     AX,[SI-(OFFSET EDIT_LOC - OFFSET MENU_PSP)] ;
                SHR     AX,1            ;
                CWD                     ; May be more than 256 lines
                DIV     WORD PTR SCR_COL ; Compute new column position
                SHL     DX,1            ; Remainder is column
                ADD     DI,DX           ; New cursor position
                CALL    DISP_SCREEN     ; Redisplay screen
                XOR     AX,AX           ; Find field position
                JMP     MOVE_CRS        ;
;
; Ctrl End = Go to end of display.
;
CEND_SUB:                               ; Ctrl End
                MOV     AX,EDIT_LAST    ; Move to end of display area
                JMP     MOVE_TO         ;
;
; CR = Go to next line in a multi-line field, or to next field, or exit
; if in last line of last field.
;
CR_SUB:                                 ; CR
                CALL    FIND_AREA       ; Find which area we are in
                JC      CR_TAB          ; Not in an area
                MOV     AX,DI           ;
                SHR     AX,1            ;
                DIV     SCR_COL         ; Offset to start of next line
                MOV     AL,SCR_COL      ;
                SUB     AL,AH           ;
                XOR     AH,AH           ;
                SHL     AX,1            ;
                ADD     AX,SI           ;
                CMP     AX,EDIT_AREA[BX+2] ; Beyond end of area?
                JB      GO_MTO          ; No, just move to next line
                ADD     BX,4            ;
CR_TAB:                                 ; Go to next area or quit
                CMP     BX,EDIT_NUM     ; In last field?
                JAE     GO_CENTER       ; Yes
                CMP     SI,EDIT_AREA[BX] ; After last field?
                JB      TAB_SUB         ; No, move to next field
GO_CENTER:                              ;
                JMP     CENTER_SUB      ; Yes, end of entry
;
; Down arrow = Move down one line.
;
DOWN_SUB:                               ; Down arrow
                MOV     AX,WORD PTR SCR_COL ; Move one line
                JMP     MOVE_CRS        ;
;
; Up arrow = Move up one line.
;
UP_SUB:                                 ; Up arrow
                MOV     AX,WORD PTR SCR_COL ; Move up one line
                NEG     AX              ;
                JMP     MOVE_CRS        ;
;
; PgUp = Move up one page.
;
PGUP_SUB:                               ; PgUp
                MOV     AX,DISP_SIZE    ;
                SHR     AX,1            ;
                NEG     AX              ; Move back one page
                JMP     MOVE_CRS        ; Move to next input area if any
;
; PgDn = Move down one page.
;
PGDN_SUB:                               ; PgDn
                MOV     AX,DISP_SIZE    ; Move ahead one screen
                SHR     AX,1            ;
                JMP     MOVE_CRS        ;
;
; Tab = Move to start of next field.
;
TAB_SUB:                                ; TAB
                CMP     EDIT_NUM,0      ; Any input areas?
                JZ      GO_EST          ; No, nothing to do
                CALL    FIND_AREA       ; Find current area
                JC      TAB_OK          ; Point to next area
                ADD     BX,4            ; Move to next area
                CMP     BX,EDIT_NUM     ; Wrap around?
                JB      TAB_OK          ;
                XOR     BX,BX           ;
TAB_OK:                                 ;
                MOV     AX,EDIT_AREA[BX] ; Move to start of next area
GO_MTO:                                 ;
                JMP     MOVE_TO         ;
;
; Home and Back tab = Move to start of this field.  If at start, move to
; start of previous field.
;
HOME_SUB:                               ; Home
BTAB_SUB:                               ; Back tab
                CALL    FIND_AREA       ; Find current area
                JC      BTAB_AREA       ; Not in an area, just use previous
                MOV     AX,EDIT_AREA[BX] ;
                CMP     AX,SI           ; Already at start of area?
                JNE     GO_MTO          ; No, move to start of area
BTAB_AREA:                              ;
                CMP     EDIT_NUM,0      ; Any input areas?
                JZ      GO_EST          ; No
                OR      BX,BX           ; First area?
                JNZ     BACK_AREA       ; No
                MOV     BX,EDIT_NUM     ; Yes, move to last area
BACK_AREA:                              ;
                MOV     AX,EDIT_AREA[BX-4] ; Start of previous area
                JMP     MOVE_TO         ;
GO_EST:                                 ;
                JMP     EDIT_STATUS     ;
;
; Left arrow = Move cursor left one space.
;
LEFT_SUB:                               ; Left arrow
                MOV     AX,-1           ; Back one space
                JMP     MOVE_CRS        ;
;
; End = Move to end of this field.  Moves to first space after last non-space.
;
END_SUB:                                ; End
                CALL    FIND_AREA       ; Find area
                CMP     BX,EDIT_NUM     ; Any areas?
                JAE     GO_EST          ; No, nothing to do
                CALL    END_FIND        ; Find end of next area
                CMP     AX,SI           ; Would we move?
                JNE     GO_MTO          ; Yes, so move
                CALL    TAB_SUB         ; Move to end of next area
                CALL    FIND_AREA       ;
                CALL    END_FIND        ;
                JMP     MOVE_TO         ;
;
; Find end of area.
;
END_FIND:                               ;
                PUSH    DI              ;
                MOV     DX,EDIT_AREA[BX] ; Start of area
                MOV     DI,EDIT_AREA[BX+2] ; End of area
                MOV     AH,[DI-1]       ; Attribute for first position
                CALL    TRIM            ; Find last non-blank + 2
                CMP     DI,EDIT_AREA[BX+2] ; Non-blank in last position
                JB      EF_LAST         ; No
                DEC     DI              ; Go to last position then
                DEC     DI              ;
EF_LAST:                                ;
                MOV     AX,DI           ; Position to move to
                POP     DI              ;
                RET                     ;
;
; Ins = Toggle insert mode.
;
INS_SUB:                                ;
                XOR     STAT_INS,' ' XOR '^' ; Toggle insert mode
                JMP     EDIT_STATUS     ; Go display updated status
;
; Backspace = Move back one space and delete the character there.
; If at first character of the field, do nothing.
;
BS_SUB:                                 ; Backspace
                CALL    FIND_AREA       ; Find current input area
                JC      LEFT_SUB        ; Not in area, just move left
                CMP     SI,EDIT_AREA[BX] ; Are we at start?
                JNE     BS_LFT          ; No, move left
                JMP     EDIT_STATUS     ; Nothing to do
BS_LFT:                                 ;
                CALL    LEFT_SUB        ;
;
; Del = Delete the character under the cursor.
;
DEL_SUB:                                ;
                CALL    FIND_AREA       ; Find the area we are in
                JC      GO_EST          ; Not in an area
                MOV     CX,EDIT_AREA[BX+2] ;
                DEC     CX              ; Last character of field
                DEC     CX              ;
                PUSH    CX              ; Save last position
                SUB     CX,SI           ;
                PUSH    DI              ;
                PUSH    SI              ;
                MOV     DI,SI           ;
                INC     SI              ;
                INC     SI              ;
        REP     MOVSB                   ; Copy characters
                POP     SI              ;
                POP     DI              ;
                POP     BX              ;
                MOV     BYTE PTR [BX],' ' ; Put a blank in the last spot
                CALL    DISP_SCREEN     ; Display the field
                RET                     ;
;
; F1 = Help.  Display key definitions.
;
HELP_SUB:                               ;
                MOV     AX,OFFSET HELP_MNU ;
                MOV     CX,L_HELP       ; Length if not editing
                CMP     EOPT,L_EDIT     ; Editing a screen file?
                JNE     HELP_NRM        ; No
                MOV     CX,L_HMNU       ;
HELP_NRM:                               ;
                CALL    DISP_MNU        ; Display the menu
HELP_WT:                                ;
                XOR     AH,AH           ;
                INT     KYBD$           ;
                CMP     AL,ESC_CHR      ;
                JE      HELP_QUIT       ;
                CMP     AL,CR_CHR       ;
                JNE     HELP_WT         ; Wait for a CR
HELP_QUIT:                              ;
                CALL    DISP_SCREEN     ; Refresh the screen
                JMP     EDIT_STATUS     ;
;
; F2 = Send end of screen definition location.
;
SETND_SUB:                              ;
                MOV     SCRN_END,SI     ; Set new end of definition loc
                JMP     EDIT_STATUS     ;
;
; F3 = Toggle field and constant display.
;
FSHOW_SUB:                              ;
                XOR     SHOW,1          ; Toggle show flag
                CALL    DISP_SCREEN     ; Redisplay this screen
                RET                     ;
;
; F4 = Erase field or constant definition at this location.
;
FDEL_SUB:                               ; Erase definition
                XOR     BX,BX           ; Loop through all definitions
FDEL_LP:                                ;
                CMP     BX,DEF_NUM      ;
                JAE     NO_FDEF         ;
                CMP     SI,DEF_AREA[BX] ; Start of this field?
                JNE     NO_FDEF         ; No
                MOV     AX,OFFSET DEF_AREA ;
                CALL    FD_RMV          ; Remove entry
                SUB     DEF_NUM,4       ; Reduce count of entries
                JMP     FDEL_LP         ; Check next entry
NO_FDEF:                                ;
                CMP     BX,CONST_NUM    ;
                JAE     NO_FCON         ;
                CMP     SI,CONST_AREA[BX] ; Start of this constant?
                JNE     NO_FCON         ; No
                MOV     AX,OFFSET CONST_AREA ;
                CALL    FD_RMV          ; Remove entry
                SUB     CONST_NUM,4     ; Reduce count
                JMP     NO_FDEF         ; Check next entry
NO_FCON:                                ;
                ADD     BX,4            ;
                CMP     BX,EDIT_FLD*4   ; More fields to check?
                JB      FDEL_LP         ; Yes
                CALL    DISP_SCREEN     ; Update display
                RET                     ;
FD_RMV:                                 ;
                PUSH    DI              ; Remove this entry
                PUSH    SI              ;
                MOV     CX,EDIT_FLD*4-4 ;
                SUB     CX,BX           ; Length to move
                MOV     DI,BX           ;
                ADD     DI,AX           ;
                LEA     SI,[DI+4]       ;
        REP     MOVSB                   ; Copy entries
                XOR     AX,AX           ;
                STOSW                   ;
                STOSW                   ; Clear last entry
                POP     SI              ;
                POP     DI              ;
                RET                     ;
;
; F5 = Start constant area.
;
CNSTRT_SUB:                             ; Define new constant area
                MOV     BX,CONST_NUM    ; Pointer to next field definition
                CMP     BX,EDIT_FLD*4   ; Area full?
                JAE     DEF_ERROR       ; Yes
                CMP     CONST_AREA[BX],0 ; Already started the area?
                JNZ     DEF_NEST        ; Yes, cannot nest
                MOV     CONST_AREA[BX],SI ; Save start of area
                CALL    DISP_SCREEN     ;
                RET                     ;
;
; F6 = End of constant area.
;
CNEND_SUB:                              ; End constant area
                MOV     BX,CONST_NUM     ;
                CMP     BX,EDIT_FLD*4   ; Full?
                JAE     DEF_ERROR       ;
                CMP     CONST_AREA[BX],0 ; Started area?
                JZ      DEF_UNBAL       ; No
                LEA     AX,[SI+2]       ;
                MOV     CONST_AREA[BX+2],AX ; Save end of area
                ADD     CONST_NUM,4     ;
                CALL    DISP_SCREEN     ;
                RET                     ;
;
; F7 = Start new field.
;
FSTRT_SUB:                              ; F7
                MOV     BX,DEF_NUM      ; Pointer to next field definition
                CMP     BX,EDIT_FLD*4   ; Area full?
                JAE     DEF_ERROR       ; Yes
                CMP     DEF_AREA[BX],0  ; Already started the area?
                JNZ     DEF_NEST        ; Yes, cannot nest
                MOV     DEF_AREA[BX],SI ; Save start of area
                CALL    DISP_SCREEN     ;
                RET                     ;
DEF_ERROR:                              ;
                MOV     AX,OFFSET ROOM_MSG ;
                MOV     CX,L_ROOM       ;
                CALL    STAT_MSG        ; Display error in status line
                JMP     EDIT_FILE       ;
DEF_NEST:                               ;
                MOV     AX,OFFSET NEST_MSG ;
                MOV     CX,L_NEST       ;
                CALL    STAT_MSG        ;
                JMP     EDIT_FILE       ;
;
; F8 = End of new field.
;
FEND_SUB:                               ;
                MOV     BX,DEF_NUM      ;
                CMP     BX,EDIT_FLD*4   ; Full?
                JAE     DEF_ERROR       ;
                CMP     DEF_AREA[BX],0  ; Started area?
                JZ      DEF_UNBAL       ; No
                LEA     AX,[SI+2]       ;
                MOV     DEF_AREA[BX+2],AX ; Save end of area
                ADD     DEF_NUM,4       ;
                CALL    DISP_SCREEN     ;
                RET                     ;
DEF_UNBAL:                              ;
                MOV     AX,OFFSET BAL_MSG ;
                MOV     CX,L_BAL        ;
                CALL    STAT_MSG        ;
                JMP     EDIT_FILE       ;
;
; F9 = Select new colors.
;
ATTR_SUB:                               ;
;
; Display color menu.
;
                MOV     CX,L_CTAB       ; Number of lines
                MOV     AX,OFFSET COLOR_MNU ;
                CALL    DISP_MNU        ; Display attribute menu
;
; Display status line showing current colors as defaults.
;
                MOV     AL,[SI+1]       ; Get text color
                AND     AL,0FH          ;
                CALL    BTD             ;
                MOV     WORD PTR TCLR,AX ;
                MOV     AL,[SI+1]       ;
                MOV     AH,'N'          ; Blink Value
                TEST    AL,80H          ; Is it blinking?
                JZ      NOT_BLINK       ; No
                MOV     AH,'Y'          ;
NOT_BLINK:                              ;
                MOV     BLNK,AH         ;
                MOV     CL,4            ;
                SHR     AL,CL           ;
                AND     AL,7            ; Background color
                CALL    BTD             ;
                MOV     BCLR,AH         ;
;
; Get new color values.
;
                PUSH    SI              ;
                MOV     DH,SCR_LIN      ;
                DEC     DH              ;
COLOR_ST:                               ;
                MOV     DL,OFFSET STAT_Q - OFFSET STATUS_MSG ;
                ADD     DL,OFFSET TCLR - OFFSET COLOR_MSG ;
                MOV     SI,OFFSET TCLR  ;
                XOR     BH,BH           ;
COLOR_LP:                               ;
                MOV     AX,OFFSET COLOR_MSG ; Put in status line
                MOV     CX,L_COLOR      ;
                CALL    STAT_MSG        ;
                MOV     AH,CRS$         ;
                INT     VIDEO$          ; Set cursor position
                XOR     AH,AH           ;
                INT     KYBD$           ; Get next input
                CMP     AL,'0'          ; Digit?
                JB      NOT_CDIG        ; No
                CMP     AL,'9'          ;
                JA      NOT_CDIG        ;
                CMP     SI,OFFSET BCLR  ; Blink field?
                JA      COLOR_LP        ; Yes, no digits
                MOV     [SI],AL         ; Put digit
                CMP     SI,OFFSET TCLR  ; Moving to another field?
                JA      PUT_CLR2        ;
                INC     SI              ;
                INC     DL              ;
                JMP     COLOR_LP        ;
PUT_CLR2:                               ;
                CMP     SI,OFFSET BCLR  ; Moving to blink field?
                JAE     PUT_BKGR        ; Yes
                ADD     SI,OFFSET BCLR - OFFSET TCLR - 1 ;
                ADD     DL,OFFSET BCLR - OFFSET TCLR - 1 ;
                JMP     COLOR_LP        ;
PUT_BKGR:                               ;
                ADD     SI,OFFSET BLNK - OFFSET BCLR ;
                ADD     DL,OFFSET BLNK - OFFSET BCLR ;
                JMP     COLOR_LP        ;
NOT_CDIG:                               ;
                CMP     AL,ESC_CHR      ; Quit?
                JE      CLR_QUIT        ;
                CMP     AL,CR_CHR       ; Done?
                JE      CLR_DONE        ; Yes
                CMP     AL,BS_CHR       ; Backspace?
                JE      CLR_BS          ; Yes
                CMP     SI,OFFSET BLNK  ; Blink field?
                JNE     COLOR_LP        ; No
                AND     AL,NOT 20H      ;
                CMP     AL,'N'          ;
                JE      PUT_BLNK        ;
                CMP     AL,'Y'          ;
                JNE     COLOR_LP        ;
PUT_BLNK:                               ;
                MOV     [SI],AL         ;
                JMP     COLOR_LP        ;
;
; We have the color request.  Convert the values and check if legal.
;
CLR_DONE:                               ;
                MOV     AL,TCLR         ; Convert foreground color to binary
                SUB     AL,'0'          ;
                MUL     C10             ;
                ADD     AL,TCLR+1       ;
                SUB     AL,'0'          ;
                MOV     AH,BCLR         ; Convert background color
                SUB     AH,'0'          ;
                CMP     AL,15           ; Legal colors?
                JA      GO_CST          ; No
                CMP     AH,7            ;
                JA      GO_CST          ;
                MOV     CL,4            ; Put in attribute format
                SHL     AH,CL           ;
                OR      AL,AH           ;
                CMP     BLNK,'Y'        ; Blink?
                JNE     NOT_BLNK        ; No
                OR      AL,80H          ;
NOT_BLNK:                               ;
                MOV     ATTRIBUTE,AL    ; Save new attribute
CLR_QUIT:                               ;
                POP     SI              ;
                CALL    DISP_SCREEN     ; Redisplay screen
                JMP     EDIT_STATUS     ; Redisplay cursor
;
; Handle backspacing in color information.
;
CLR_BS:                                 ;
                CMP     SI,OFFSET TCLR+1 ; In first field?
                JA      BS_BKGR         ; No
                JB      GO_CLRLP        ;
                DEC     SI              ;
                DEC     DL              ;
GO_CLRLP:                               ;
                JMP     COLOR_LP        ;
BS_BKGR:                                ;
                CMP     SI,OFFSET BCLR  ; In background?
                JA      BS_BLNK         ; No
                SUB     SI,OFFSET BCLR - OFFSET TCLR - 1 ;
                SUB     DL,OFFSET BCLR - OFFSET TCLR - 1 ;
                JMP     COLOR_LP        ;
BS_BLNK:                                ;
                SUB     SI,OFFSET BLNK - OFFSET BCLR ;
                SUB     DL,OFFSET BLNK - OFFSET BCLR ;
                JMP     COLOR_LP        ;
GO_CST:                                 ;
                JMP     COLOR_ST        ;
;
; F10 = Put new attribute in character and advance cursor.
;
COLOR_SUB:                              ;
                MOV     AH,ATTRIBUTE    ;
                MOV     [SI+1],AH       ; Put new attribute
                MOV     AL,[SI]         ;
                JMP     EDIT_NINS       ; Redisplay the character position
;
; Alt= = Put next key value whatever it is.
;
FORCE_SUB:                              ;
                XOR     AH,AH           ;
                INT     KYBD$           ; Get next key stroke
                JMP     EDIT_FORCE      ; and force into file
;
; Ctrl Enter = Done
;
CENTER_SUB:                             ; Ctrl Enter = Done
                POP     AX              ; Throw away return
                CALL    REST_VID        ; Restore screen
                CALL    GET_TIME        ; Initialize date & time variables
;
; Read template file.
;
                MOV     BX,TEMPLFILE    ; Read template file
                MOV     IN_CNT,0        ; Start new buffer
                MOV     AH,SCR_ATTR     ; Starting attribute for ANSI conversion
                MOV     DX,1            ; First field for screen file editing
                CMP     EOPT,L_EDIT     ; Editing a screen file?
                JE      DO_INP          ; Yes, go copy the screen
                CMP     BX,0            ; Any template file?
                JZ      GO_DONE         ; No
;
; Scan template file looking for.  Check character type and handle as needed.
;
TMPL_LP:                                ;
                CALL    GET_CHR         ; Get next character
                JNZ     TMPL_OK         ; Got a character
GO_DONE:                                ;
                JMP     WF_DONE         ;
TMPL_OK:                                ;
                MOV     CX,L_TCHR       ;
                MOV     SI,OFFSET TMPL_CHR ;
                CALL    TBL_SRCH        ; Find character type
                JMP     TMPL_VECT[SI]   ; Switch on character type
TMPL_PUT:                               ;
                CALL    OUT_CHR         ; No, send character to output
                JMP     TMPL_LP         ; Continue processing characters
;
; \ Force out next character.
;
TMPL_FORCE:                             ;
                CALL    GET_CHR         ; Get character
                JNZ     TMPL_PUT        ; If none, error.  Otherwise put it
;
; Bad template file format.
;
TMPL_ERROR:                             ;
                MOV     CX,L_TBAD       ;
                MOV     DX,OFFSET TMPL_MSG ;
                JMP     ERROR_DSP       ;
;
; < Switch output files.
;
TMPL_FILE:                              ;
                CALL    DTB             ; Get file number
                CMP     AL,'>'          ;
                JNE     TMPL_ERROR      ; Not correct closing symbol
                DEC     DX              ;
                MOV     SI,DX           ;
                SHL     SI,1            ;
                CMP     DX,NUM_OUT      ; Legal value?
                JAE     TMPL_ERROR      ;
                CALL    WR_OUT          ; Spill rest of buffer for current file
                MOV     OUT_INDX,0      ;
                MOV     AX,OUT_HNDL[SI] ; Get handle
                MOV     OUTFILE,AX      ;
                JMP     TMPL_LP         ;
;
; [ Look for pattern type.
;
TMPL_SENT:                              ;
;
; Check for an input area reference.
;
                CALL    DTB             ; Convert value to binary
                OR      DX,DX           ; Input number?
                JNZ     DO_INP          ;
                JMP     CHK_PAT         ; No, check if time/date pattern
;
; We have an input area to copy.  Check to see if the number is good.
;
DO_INP:                                 ;
                DEC     DX              ;
                SHL     DX,1            ; Convert to area index
                SHL     DX,1            ;
                CMP     DX,EDIT_NUM     ; Legal area?
                JAE     TMPL_ERROR      ; No, error
;
; Get area to copy.
; We will not copy trailing blanks from the input area.
; Input will be treated as a single character string with no CR,LFs inserted.
; The template may indicate formatting by following the number with any of
; the following pattern characters:
; ]     =       All remaining input characters
; ?     =       Next input character
; =     =       All input characters up to end of screen line
; |     =       Ignore rest of template if no more input
; \     =       Include next template character in output
; All other characters in the template are copied to the output.
;
                MOV     DI,DX           ; Input area index
                MOV     DX,EDIT_AREA[DI] ; Start of input area
                MOV     DI,EDIT_AREA[DI+2] ; End of input area
;
; Find last non-blank.
;
                CALL    TRIM            ; Find start of trailing spaces
                XCHG    DX,DI           ; DX=End, DI=Start
;
; Scan template doing the replacement.
;
                CMP     EOPT,L_EDIT     ; Editing a screen file?
                JNE     REPL_FIRST      ; Already have first character
                JMP     COPY_SCRN       ; Yes
REPL_INP:                               ;
                CALL    GET_CHR         ; Get next template character
                JZ      TMPL_ERROR      ;
REPL_FIRST:                             ;
                MOV     CX,L_RCHR       ;
                MOV     SI,OFFSET REPL_CHR ;
                CALL    TBL_SRCH        ; Get character type
                CALL    REPL_VECT[SI]   ; Switch on character type
                JMP     REPL_INP        ;
;
; All non-pattern characters.
;
REPL_PUT:                               ;
                CALL    OUT_CHR         ; Just send the character to output
REPL_OK:                                ;
                RET                     ; Continue replacing
GO_STOP:                                ;
                JMP     COPY_STOP       ;
;
; \ Copy the next template character.
;
COPY_FORCE:                             ;
                CALL    GET_CHR         ; Get the character
                JZ      TMPL_ERROR      ;
                JMP     REPL_PUT        ;
;
; ? Copy the next input character.
;
COPY_ONE:                               ;
                CMP     DI,DX           ; Any left?
                JAE     REPL_OK         ; No, nothing to copy
                MOV     AL,[DI]         ;
                INC     DI              ;
                INC     DI              ;
                JMP     REPL_PUT        ;
;
; Copy to file in screen file format.  Generate ANSI sequences as needed.
; For start and end of defined input fields insert [ and ].
; For start and end of constant fields insert { and }.
; Put a \ in front of screen file control characters that appear as data.
;
COPY_SCRN:                              ;
                CMP     DX,SCRN_END     ; Past user defined end?
                JBE     COPY_SOK        ; No
                MOV     DX,SCRN_END     ;
                INC     DX              ;
                INC     DX              ;
COPY_SOK:                               ;
                CALL    COPY_LINE       ; Copy one line
                MOV     AL,CR_CHR       ;
                CALL    OUT_CHR         ;
                MOV     AL,LF_CHR       ; Put end of line
                CALL    OUT_CHR         ;
                CMP     DI,DX           ; Any input left?
                JB      COPY_SOK        ; Yes
                JMP     WF_DONE         ; No
;
; = Copy all input characters up to the end of the screen line.
; Do not copy trailing blanks on the screen line but do skip over them.
;
COPY_LINE:                              ;
                PUSH    CX              ;
                PUSH    AX              ;
                MOV     AX,DI           ; Starting location
                SUB     AX,OFFSET EDIT_LOC ; Index
                SHR     AX,1            ; Convert to character index
                MOV     CX,WORD PTR SCR_COL ; Columns per line
                DIV     CL              ;
                SUB     CL,AH           ; Remaining characters to end of line
                MOV     AX,DX           ;
                SUB     AX,DI           ;
                SHR     AX,1            ; Remaining characters in input field
                CMP     AX,CX           ; Use lesser
                JAE     LINE_COPY       ;
                MOV     CX,AX           ;
LINE_COPY:                              ;
                POP     AX              ;
                JCXZ    LINE_DONE       ;
                PUSH    DX              ;
                MOV     DX,DI           ; Start of area
                ADD     DI,CX           ; End of input area to be copied
                ADD     DI,CX           ;
                PUSH    DI              ; Save end
                CALL    TRIM            ; Ignore trailing blanks
                MOV     CX,DI           ; Compute new length
                SUB     CX,DX           ;
                SHR     CX,1            ;
                MOV     DI,DX           ; Start of copy
                JCXZ    LINE_MT         ; All blank line
;
; Now copy the characters checking for start and end of input areas and
; change of attributes.
;
LINE_CP:                                ;
                CMP     EOPT,L_EDIT     ; Generating screen file?
                JNE     LINE_PUT        ; No
                MOV     AL,'['          ; Do start of fields
                CALL    FIELD_GEN       ; Check for field start
                CMP     AH,[DI+1]       ; Attributes match?
                JNE     GEN_ANSI        ; No, generate ANSI sequence
LINE_CHR:                               ;
                MOV     DX,CX           ;
                MOV     AL,[DI]         ; Get next input character
                MOV     CX,L_SCHR       ; See if this is a screen control char
                MOV     SI,OFFSET SCR_CHR ;
                CALL    TBL_SRCH        ;
                MOV     CX,DX           ;
                CMP     SI,0            ; Normal character?
                JZ      LINE_PUT        ; Yes
                MOV     DL,AL           ;
                MOV     AL,'\'          ; Send force character
                CALL    OUT_CHR         ;
                MOV     AL,DL           ;
LINE_PUT:                               ;
                MOV     AL,[DI]         ; Get next input character
                CALL    OUT_CHR         ; Send to output
                INC     DI              ;
                INC     DI              ;
                CMP     EOPT,L_EDIT     ; Screen file editing?
                JNE     LINE_ELP        ; No
                MOV     AL,']'          ; Do end of fields
                CALL    FIELD_GEN       ;
LINE_ELP:                               ;
                LOOP    LINE_CP         ;
LINE_MT:                                ;
                POP     DI              ; Move to end of line
                POP     DX              ;
LINE_DONE:                              ;
                POP     CX              ;
                RET                     ;
;
; Generate ANSI sequence from change in attribute.
;
GEN_ANSI:                               ;
                PUSH    CX              ;
                PUSH    DX              ;
                XOR     CX,CX           ; No values output yet
;
; Put Esc [ start of ANSI sequence.
;
                MOV     AL,ESC_CHR      ; Start ANSI sequence
                CALL    OUT_CHR         ;
                MOV     AL,'['          ;
                CALL    OUT_CHR         ;
;
; Check to see if foreground colors are changed.
;
                MOV     DL,[DI+1]       ; Isolate foregrounds
                MOV     DH,AH           ;
                AND     DX,0F0FH        ;
                CMP     DL,DH           ; Did foreground change?
                JE      NOT_FORE        ; No
                AND     DL,7            ; Check to see if only intensity
                CMP     DL,DH           ;
                JE      SET_INT         ; Only intensity being set
                TEST    DL,5            ; Switch attributes if appropriate
                JPE     NSW_1           ;
                XOR     DL,5            ; Invert attributes
NSW_1:                                  ;
                MOV     AL,'3'          ; Put foreground color
                CALL    OUT_CHR         ;
                MOV     AL,DL           ;
                ADD     AL,'0'          ;
                CALL    OUT_CHR         ;
                INC     CX              ;
;
; Foreground changed, so check to see if we need to set high intensity.
;
                MOV     DL,[DI+1]       ;
                TEST    DL,8            ; High intensity set?
                JZ      NOT_FORE        ; No
                MOV     AL,';'          ;
                CALL    OUT_CHR         ;
SET_INT:                                ;
                MOV     AL,'1'          ;
                CALL    OUT_CHR         ;
                INC     CX              ;
NOT_FORE:                               ;
                MOV     DH,AH           ;
                MOV     DL,[DI+1]       ; Compare backgrounds
                AND     DX,7070H        ;
                CMP     DL,DH           ; Did background change?
                JE      NOT_BKGR        ; No
                TEST    DL,50H          ; Switch attributes if appropriate
                JPE     NSW_2           ;
                XOR     DL,50H          ;
NSW_2:                                  ;
                JCXZ    NO_SEP2         ; No value output yet
                MOV     AL,';'          ; Put separator
                CALL    OUT_CHR         ;
NO_SEP2:                                ;
                MOV     AL,'4'          ;
                CALL    OUT_CHR         ; Put background color
                MOV     AL,DL           ;
                MOV     CL,4            ;
                SHR     AL,CL           ;
                ADD     AL,'0'          ;
                CALL    OUT_CHR         ;
NOT_BKGR:                               ;
                TEST    BYTE PTR [DI+1],80H ; Blink set?
                JZ      NOT_BLI         ; No
                JCXZ    NO_SEP3         ;
                MOV     AL,';'          ; Separator
                CALL    OUT_CHR         ;
NO_SEP3:                                ;
                MOV     AL,'5'          ;
                CALL    OUT_CHR         ;
NOT_BLI:                                ;
                MOV     AL,'m'          ; Put terminator
                CALL    OUT_CHR         ;
                MOV     AH,[DI+1]       ; New attribute
                POP     DX              ;
                POP     CX              ;
                JMP     LINE_CHR        ;
;
; | Stop copying from this template if there is no more input.
;
COPY_STOP:                              ;
                CMP     DI,DX           ; Any more input?
                JAE     COPY_SKIP       ; No
                RET                     ; Yes
COPY_SKIP:                              ;
                CALL    GET_CHR         ; Skip to end of template
                JZ      BAD_TP          ;
                CMP     AL,']'          ; End of template?
                JE      COPY_DONE       ; Yes
                CMP     AL,'\'          ; Force?
                JNE     COPY_SKIP       ; No, keep looking
                CALL    GET_CHR         ; Ignore next character
                JZ      BAD_TP          ;
                JMP     COPY_SKIP       ; Keep looking
;
; ] Copy remaining input characters to output and then start over at top.
;
COPY_REST:                              ;
                CMP     DI,DX           ; Any remaining input characters?
                JAE     COPY_DONE       ; No
                MOV     AL,[DI]         ;
                CALL    OUT_CHR         ; Copy to output
                INC     DI              ;
                INC     DI              ;
                JMP     COPY_REST       ;
BAD_TP:                                 ;
                POP     AX              ;
                JMP     TMPL_ERROR      ;
COPY_DONE:                              ;
                POP     AX              ;
                JMP     TMPL_LP         ; Continue working on template file
;
; Check for time and date patterns.
; \ Force next character
; MM DD CC YY DW MN hh mm ss are all replaced with appropriate values.
;
CHK_PAT:                                ;
                PUSH    AX              ;
CHK_MORE:                               ;
                CMP     AL,']'          ; End sentinel?
                JE      COPY_DONE       ; Yes, look for next template
                MOV     AH,AL           ; Save first pattern character
                CALL    GET_CHR         ; Get second pattern character
                JZ      BAD_TP          ;
PAT_CHK:                                ;
                CMP     AH,'\'          ; Force next character?
                JE      PAT_NEXT        ; Yes
                MOV     SI,OFFSET TD_TAB ; Pattern table
                MOV     CX,L_TD         ;
                CALL    WTBL_SRCH       ; Find matching entry
                CMP     SI,0            ; Do we have a pattern?
                JNZ     REPL_PAT        ; Yes
                XCHG    AL,AH           ; No, output first char and continue
                CALL    OUT_CHR         ; Send character to output
                XCHG    AL,AH           ;
                JMP     CHK_MORE        ; Keep checking for patterns
;
; \ Found a force character.
;
PAT_NEXT:                               ;
                CALL    OUT_CHR         ; Send forced character to output
PAT_GET:                                ;
                CALL    GET_CHR         ;
                JZ      BAD_TP          ;
                JMP     CHK_MORE        ;
;
; Found a pattern to be replaced.
; Check for DW and MN case and handle specially.
;
REPL_PAT:                               ;
                MOV     DI,TD_LOC[SI-2] ; Data loc
                CMP     SI,4            ; DW or MN?
                JE      CK_MON          ; MN
                JB      CK_DOW          ; DW
DO_2:                                   ;
                MOV     AX,[DI]         ; Get data
                CALL    OUT_CHR         ; Put in output
                MOV     AL,AH           ;
                CALL    OUT_CHR         ;
                JMP     PAT_GET         ;
CK_MON:                                 ;
                MOV     AX,OFFSET MON_TAB ; Month abbreviation table
DO_3:                                   ;
                ADD     AX,[DI]         ;
                MOV     DI,AX           ;
                MOV     AL,[DI]         ; Get abbreviation
                CALL    OUT_CHR         ; Put first character
                INC     DI              ;
                JMP     DO_2            ;
CK_DOW:                                 ;
                MOV     AX,OFFSET DOW_TAB ; Day of week abbreviation table
                JMP     DO_3            ;
;
; { Constant area reference.
;
TMPL_CONST:                             ;
                CALL    DTB             ; Convert value to binary
                OR      DX,DX           ; Constant number?
                JNZ     DO_CONST        ;
                CMP     AL,'['          ; Indirect reference?
                JE      DO_INDIR        ; Indirect constant reference
                JMP     TMPL_ERROR      ; Incorrect constant reference
;
; We have {[nnn]}.
;
DO_INDIR:                               ;
                CALL    DTB             ; Get input field reference
                OR      DX,DX           ; Got a number?
                JZ      GO_TERR         ; Yes
                CMP     AL,']'          ; Closed properly?
                JE      INDIR_OK        ;
GO_TERR:                                ;
                JMP     TMPL_ERROR      ;
INDIR_OK:                               ;
                DEC     DX              ;
                SHL     DX,1            ;
                SHL     DX,1            ;
                CMP     DX,EDIT_NUM     ; Legal field reference?
                JAE     GO_TERR         ; No
                MOV     SI,DX           ;
                MOV     CX,EDIT_AREA[SI+2] ; End of area
                MOV     SI,EDIT_AREA[SI] ; Start of input
                XOR     DX,DX           ;
INDIR_VAL:                              ;
                LODSB                   ; Get next character
                CMP     AL,'0'          ; If not a digit, skip
                JB      INDIR_SKIP      ;
                CMP     AL,'9'          ;
                JA      INDIR_SKIP      ;
                SUB     AL,'0'          ; Convert to binary
                XCHG    AL,DL           ;
                MUL     C10             ;
                ADD     DX,AX           ;
INDIR_SKIP:                             ;
                INC     SI              ;
                CMP     SI,CX           ;
                JB      INDIR_VAL       ;
                CALL    GET_CHR         ; Must have closing brace
                JZ      GO_TERR         ;
;
; We have a constant reference.
;
DO_CONST:                               ;
                CMP     AL,'}'          ; Closing brace?
                JNE     GO_TERR         ;
                DEC     DX              ;
                SHL     DX,1            ;
                SHL     DX,1            ;
                CMP     DX,CONST_NUM    ; Legal constant reference?
                JAE     GO_TMPL         ; No, ignore
                MOV     SI,DX           ;
                MOV     DX,CONST_AREA[SI+2] ; End of constant area
                MOV     SI,CONST_AREA[SI] ; Start of constant
CONST_LP:                               ;
                LODSB                   ;
                CALL    OUT_CHR         ; Send next constant character
                INC     SI              ;
                CMP     SI,DX           ; Reached the end?
                JB      CONST_LP        ; No
GO_TMPL:                                ;
                JMP     TMPL_LP         ; Yes, continue processing template
;
; Processing complete.
;
WF_DONE:                                ;
                CALL    WR_OUT          ; Write remaining buffered output
                MOV     CX,NUM_OUT      ; Number of output files
                XOR     SI,SI           ;
CLOSE_LP:                               ;
                MOV     BX,OUT_HNDL[SI] ; Close output file
                MOV     AH,CLOSE$       ;
                INT     DOS$            ;
                INC     SI              ;
                INC     SI              ;
                LOOP    CLOSE_LP        ;
                JMP     SHORT EXIT_DOS  ;
;
; Esc = Quit
;
ESC_SUB:                                ; Esc
                MOV     AX,OFFSET Q_MSG ;
                MOV     CX,L_Q          ;
                CALL    STAT_MSG        ; Display query "Really want to quit?"
Q_SOL:                                  ;
                XOR     AH,AH           ;
                INT     KYBD$           ; Read next character
                AND     AL,NOT 20H      ; Make upper case
                CMP     AL,'Y'          ; Really want to exit?
                JE      DO_QUIT         ; Yes
                CMP     AL,'N'          ; Want to keep going?
                JNE     Q_SOL           ; No, resolicit
                JMP     EDIT_STATUS     ; Keep on going
DO_QUIT:                                ;
                CALL    REST_VID        ; Restore original screen
EXIT_DOS:                               ;
                MOV     AH,EXIT$        ; Return to DOS
                XOR     AL,AL           ; Normal exit
                INT     DOS$            ;
;
; Commnon code for error message display and error exit to DOS.
;
ERROR_DSP:                              ;
                MOV     AH,WRFILE$      ; Display error message
                MOV     BX,ERROUT       ;
                INT     DOS$            ;
                MOV     CX,2            ;
                MOV     DX,OFFSET CRLF  ; Skip a line
                MOV     AH,WRFILE$      ;
                INT     DOS$            ;
                MOV     AH,EXIT$        ;
                MOV     AL,1            ; Error exit
                INT     DOS$            ;
;
;
; PROCEDURE FIND_AREA
;
; FIND_AREA finds the input area containing the current cursor position.
; If the position is not in an area, the next logical area start is
; returned.
;
; INPUT:
;       SI      =       Current cursor location
;
; OUTPUT:
;       BX      =       Pointer to area table entry
;       CF      =       1, Not in the area
;                       0, In the area
;
FIND_AREA       PROC                    ;
                XOR     BX,BX           ; Search input table
FA_LP:                                  ;
                CMP     BX,EDIT_NUM     ; Still in table?
                JA      FA_FIRST        ; No, go to home position
                CMP     SI,EDIT_AREA[BX] ; Within this area?
                JB      FA_NOT          ; No
                CMP     SI,EDIT_AREA[BX+2] ;
                JB      FA_IN           ; Yes
                ADD     BX,4            ; Try next area
                JMP     FA_LP           ;
FA_FIRST:                               ;
                XOR     BX,BX           ;
FA_NOT:                                 ;
                CLC                     ;
FA_IN:                                  ;
                CMC                     ; Set carry appropriately
                RET                     ;
FIND_AREA       ENDP                    ;
;
;
; PROCEDURE: DISP_MNU
;
; DISP_MNU displays a Nx40 menu on the screen.
;
; INPUT:
;       AX      =       Menu location
;       CX      =       Number of lines in menu
;
; OUTPUT:
;       AX, CX contents destroyed.
;
DISP_MNU        PROC                    ;
                PUSH    DX              ;
                PUSH    DI              ;
                PUSH    SI              ;
                XOR     DI,DI           ;
                MOV     DX,CX           ; Number of lines
                MOV     SI,AX           ; Start of menu
DM_LINE:                                ;
                MOV     CX,40           ;
DM_LP:                                  ;
                LODSW                   ;
                CALL    WRITE_SCREEN    ; Display next character
                LOOP    DM_LP           ;
                ADD     DI,WORD PTR SCR_COL ; New line
                ADD     DI,WORD PTR SCR_COL ;
                SUB     DI,80           ;
                DEC     DX              ;
                JNZ     DM_LINE         ;
                POP     SI              ;
                POP     DI              ;
                POP     DX              ;
                RET                     ;
DISP_MNU        ENDP                    ;
;
;
; PROCEDURE STATUS
;
; Display status line.
;
; INPUT:
;       DI      =       Current cursor position
;       SI      =       Current file position
;
; OUTPUT:
;       AX contents are destroyed.
;
STATUS          PROC                    ;
                PUSH    CX              ;
                PUSH    DX              ;
                PUSH    DI              ;
                PUSH    SI              ;
;
; Convert row and column to ASCII and store in status line.
;
                MOV     AX,DI           ;
                SHR     AX,1            ;
                DIV     SCR_COL         ; Get column and row
                MOV     CL,AH           ; Save column
                XOR     AH,AH           ;
                INC     AL              ;
                MOV     DI,OFFSET STAT_ROW ;
                CALL    BTD3            ; Convert and store row
                MOV     AL,CL           ;
                INC     AL              ;
                XOR     AH,AH           ;
                MOV     DI,OFFSET STAT_COL ;
                CALL    BTD3            ;
;
; Convert file line number and put in status.
;
                LEA     AX,[SI-(OFFSET EDIT_LOC - OFFSET MENU_PSP)] ;
                SHR     AX,1            ;
                CWD                     ;
                DIV     WORD PTR SCR_COL ; Get line number
                INC     AX              ; Start at 1
                MOV     DI,OFFSET STAT_LIN ;
                CALL    BTD3            ; Convert high order
;
; Display status line.
;
                MOV     AH,STAT_ATTR    ; Status display attribute
                MOV     SI,OFFSET STATUS_MSG ;
                MOV     DI,DISP_SIZE    ;
                MOV     CX,WORD PTR SCR_COL ;
STAT_LP:                                ;
                LODSB                   ;
                CALL    WRITE_SCREEN    ;
                LOOP    STAT_LP         ;
                POP     SI              ;
                POP     DI              ;
                POP     DX              ;
                POP     CX              ;
                RET                     ;
STATUS          ENDP                    ;
;
;
; PROCEDURE: STAT_MSG
;
; STAT_MSG displays a message in the status field.
;
; INPUT:
;       AX      =       Start of message to display
;       CX      =       Length of message to display
;
; OUTPUT:
;       AX, CX contents destroyed.
;
STAT_MSG        PROC                    ;
                PUSH    DI              ;
                PUSH    SI              ;
                MOV     SI,AX           ; Location of message
                MOV     AX,CX           ; Save count
                MOV     DI,OFFSET STAT_Q ;
        REP     MOVSB                   ; Copy query to status
                MOV     CX,Q_LNG        ; Clear rest of message area
                SUB     CX,AX           ;
                MOV     AL,' '          ;
        REP     STOSB                   ;
                POP     SI              ;
                POP     DI              ;
                CALL    STATUS          ; Display message
                RET                     ;
STAT_MSG        ENDP                    ;
;
;
; PROCEDURE: STAT_CLR
;
; STAT_CLR clears the message area of the status line.
;
; INPUT:
;       None
;
; OUTPUT:
;       None
;
STAT_CLR        PROC                    ;
                PUSH    AX              ;
                PUSH    CX              ;
                PUSH    DI              ;
                MOV     CX,Q_LNG        ;
                MOV     DI,OFFSET STAT_Q ;
                MOV     AL,' '          ;
        REP     STOSB                   ;
                POP     DI              ;
                POP     CX              ;
                POP     AX              ;
                RET                     ;
STAT_CLR        ENDP                    ;
;
;
; PROCEDURE: GET_TIME
;
; GET_TIME gets the current date and time and edits the value to ASCII
; characters and places the values in the date and time variables.
;
; INPUT:
;       None
;
; OUTPUT:
;       MONTH, MON, DOW, DAY, CENTURY, YEAR, HOUR, MINUTE, SECOND updated.
;
GET_TIME        PROC                    ;
;
; Save registers used.
;
                PUSH    AX              ;
                PUSH    CX              ;
                PUSH    DX              ;
;
; Get date and convert to ASCII.
;
                MOV     AH,DATE$        ;
                INT     DOS$            ; Get current date
                MOV     AH,3            ; Convert DOW to an index
                MUL     AH              ;
                MOV     DOW,AX          ;
;
; Convert date to MM DD CC YY format.
; Compute month table index.
;
                MOV     AL,DH           ; Month index
                DEC     AL              ; Start index at 0
                MOV     AH,3            ;
                MUL     AH              ;
                MOV     MON,AX          ;
                MOV     AL,DH           ; Do month
                CALL    BTD             ; Convert to ASCII
                MOV     MONTH,AX        ;
                MOV     AL,DL           ; Day
                CALL    BTD             ;
                MOV     DAY,AX          ;
                MOV     AX,CX           ; Year
                MOV     CL,100          ; Separate century
                DIV     CL              ;
                MOV     CL,AH           ; Save year
                CALL    BTD             ;
                MOV     CENTURY,AX      ; Century
                MOV     AL,CL           ; Year
                CALL    BTD             ;
                MOV     YEAR,AX         ;
;
; Get time and convert to hh mm ss.
;
                MOV     AH,TIME$        ;
                INT     DOS$            ; Get current time
                MOV     AL,CH           ; Hour
                CALL    BTD             ;
                MOV     HOUR,AX         ;
                MOV     AL,CL           ; Minutes
                CALL    BTD             ;
                MOV     MINUTE,AX       ;
                ADD     DX,256-50       ; Round up seconds
                MOV     AL,DH           ; Seconds
                CALL    BTD             ;
                MOV     SECOND,AX       ;
                POP     DX              ;
                POP     CX              ;
                POP     AX              ;
                RET                     ;
GET_TIME        ENDP                    ;
;
;
; PROCEDURE BTD
;
; BTD converts a binary value from 00-99 to its decimal ASCII equivalent.
;
; INPUT:
;       AL      =       Binary value
;
; OUTPUT:
;       AX      =       ASCII value (low order in AH)
;
BTD             PROC                    ;
                XOR     AH,AH           ; Make a whole word
                DIV     C10             ; Separate digits
                ADD     AX,'00'         ; Convert to ASCII
                RET                     ;
BTD             ENDP                    ;
;
;
; PROCEDURE BTD3
;
; BTD3 converts a binary value from 000-999 to its decimal ASCII equivalent
; and stores the result in a specified location.
;
; INPUT:
;       AX      =       Value
;       ES:DI   =       Location to save value
;
; OUTPUT:
;       AX,DI contents destroyed.
;
BTD3            PROC                    ;
                DIV     C100            ; Isolate 100's digit
                ADD     AL,"0"          ; Convert high order digit
                STOSB                   ;
                MOV     AL,AH           ;
                CALL    BTD             ; Convert low order digits
                STOSW                   ;
                RET                     ;
BTD3            ENDP                    ;
;
;
; PROCEDURE DTB
;
; DTB converts a sequence of decimal characters to their binary equivalent.
; The resulting value must be <65536.
;
; INPUT:
;       BX, CX, SI set up for GET_CHR
;
; OUTPUT:
;       AL      =       Terminator character
;       DX      =       Result value
;
DTB             PROC                    ;
                XOR     DX,DX           ; Zero accumulator
DTB_LP:                                 ;
                CALL    GET_CHR         ; Get next character
                JZ      DTB_END         ; No more characters
                CMP     AL,'0'          ; Decimal character?
                JB      DTB_END         ; No, end of conversion
                CMP     AL,'9'          ;
                JA      DTB_END         ;
                SUB     AL,'0'          ; Convert to binary
                PUSH    AX              ;
                MOV     AX,DX           ;
                MUL     WORD PTR C10    ; Multiply previous value
                MOV     DX,AX           ;
                POP     AX              ;
                ADD     DL,AL           ;
                ADC     DH,0            ;
                JMP     DTB_LP          ; Keep accumulating value
DTB_END:                                ;
                RET                     ;
DTB             ENDP                    ;
;
;
; PROCEDURE GET_CHR
;
; GET_CHR returns the next character of the current file.  This may be either
; the SCREEN file or the TEMPLATE file.  Once one file is read, it must be
; read through to the end without referencing any other file.  The end of the
; file will be signalled and the file closed when no more characters remain
; in the file or the end-of-file sentinel character(26=1AH) is reached.
;
; INPUT:
;       BX      =       File handle(SCREENFILE or TEMPLFILE)
;       IN_CNT  =       Remaining characters in buffer
;       IN_INDX =       Pointer to next character
;
; OUTPUT:
;       AL      =       Character
;       IN_CNT, IN_INDX updated
;       ZF      =       1, end of file
;
GET_CHR         PROC                    ;
;
; Check to see if any more characters remain
;
                CMP     IN_CNT,0        ; Any more in buffer
                JZ      READ_MORE       ; No
;
; Get next character and return it.
;
                XCHG    SI,IN_INDX      ;
                LODSB                   ;
                XCHG    SI,IN_INDX      ;
                DEC     IN_CNT          ; Decrement character count
                CMP     AL,EOF_CHR      ; Is it end of file?
                JE      FILE_DONE       ; Yes
                RET                     ;
;
; Read next buffer full of file.
;
READ_MORE:                              ;
                PUSH    AX              ;
                PUSH    CX              ;
                PUSH    DX              ;
                MOV     AH,RDFILE$      ;
                MOV     CX,L_INB        ; Read all that buffer will hold
                MOV     DX,OFFSET CHR_LOC ;
                MOV     IN_INDX,DX      ;
                INT     DOS$            ; Read file
                MOV     IN_CNT,AX       ; Save amount read
                POP     DX              ;
                POP     CX              ;
                POP     AX              ;
                JC      SCRN_ERROR      ; Error reading file
                CMP     IN_CNT,0        ; Any data read?
                JNZ     GET_CHR         ; Read is OK, so return the character
FILE_DONE:                              ;
                PUSHF                   ; Preserve carry flag
                PUSH    AX              ;
                MOV     AH,CLOSE$       ; Close the file
                INT     DOS$            ;
                POP     AX              ;
                POPF                    ;
                MOV     IN_CNT,1        ; Continue to signal EOF
                MOV     IN_INDX,OFFSET CHR_LOC ;
                MOV     CHR_LOC,EOF_CHR ;
                XOR     AL,AL           ; Indicate end of file
                RET                     ;
;
; Error reading screen file.
;
SCRN_ERROR:                             ;
                CMP     BX,SCREENFILE   ; Screen file?
                JNE     TMPL_FAIL       ; No, template file
                MOV     DX,OFFSET SCRN_ERR ;
                MOV     CX,L_SERR       ;
                JMP     ERROR_DSP       ;
;
; Error reading template file.
;
TMPL_FAIL:                              ;
                MOV     CX,L_TMPL       ;
                MOV     DX,OFFSET TMPL_ERR ;
                JMP     ERROR_DSP       ;
GET_CHR         ENDP                    ;
;
;
; PROCEDURE OUT_CHR
;
; OUT_CHR sends one character to the output file.
;
; INPUT:
;       AL      =       Character to send
;
; OUTPUT:
;       None
;
; PROCEDURE WR_OUT
;
; WR_OUT writes any remaining buffered output to the output file.
;
; INPUT:
;       None
;
; OUTPUT:
;       None
;
OUT_CHR         PROC                    ;
;
; Save registers used.
;
                PUSH    BX              ;
;
; Add character to buffer.  If buffer full, write to file.
;
                MOV     BX,OUT_INDX     ;
                MOV     OUT_BUF[BX],AL  ;
                INC     BX              ;
                MOV     OUT_INDX,BX     ;
                POP     BX              ;
                CMP     BX,L_OUTB       ; Buffer full?
                JAE     WR_OUT          ; Yes
                RET                     ;
;
; Write data to out file.
;
WR_OUT:                                 ;
                PUSH    AX              ;
                PUSH    BX              ;
                PUSH    CX              ;
                PUSH    DX              ;
                MOV     CX,OUT_INDX     ; Amount to write
                JCXZ    NO_OUT          ;
                MOV     AH,WRFILE$      ;
                MOV     BX,OUTFILE      ;
                MOV     DX,OFFSET OUT_BUF ;
                INT     DOS$            ; Write file
                JC      OUT_ERR         ;
NO_OUT:                                 ;
                POP     DX              ;
                POP     CX              ;
                POP     BX              ;
                POP     AX              ;
                RET                     ;
OUT_ERR:                                ;
                MOV     CX,L_OUT        ;
                MOV     DX,OFFSET OUT_MSG ;
                JMP     ERROR_DSP       ;
OUT_CHR         ENDP                    ;
;
;
; PROCEDURE DISP_SCREEN
;
; DISP_SCREEN redisplays the screen.
; SCR_LIN*SCR_COL characters are displayed.
;
; If the show fields flag is set, new field definitions are indicated by
; blinking []'s (º if a single position) and constant area definitions
; are indicated by blinking {}'s (Î if a single position).
;
; INPUT:
;       DI      =       Screen cursor position
;       SI      =       Edit buffer cursor position
;
; OUTPUT:
;       None
;
DISP_SCREEN     PROC                    ;
;
; Save registers used.
; Save current cursor position.
;
                PUSH    AX              ;
                PUSH    DI              ;
                PUSH    SI              ;
;
; Display characters until end of screen or buffer.
;
                SUB     SI,DI           ; Start of screen in edit buffer
                XOR     DI,DI           ;
DISP_LP:                                ;
                MOV     AL," "          ; Default space
                MOV     AH,SCR_ATTR     ; Empty attribute
                CMP     SI,EDIT_LAST    ; End of characters?
                JA      NO_CHR          ; Yes
                LODSW                   ; Get next char
NO_CHR:                                 ;
                CALL    WRITE_SCREEN    ;
                CMP     DI,DISP_SIZE    ; End of screen
                JB      DISP_LP         ; No
;
; If the show fields flag is set, insert field indicator characters.
;
                CMP     SHOW,0          ; Showing definitions?
                JZ      NO_SHOW         ; No
                PUSH    BX              ;
                XOR     BX,BX           ;
                SUB     SI,DI           ; Back to start of screen
SHDF_LP:                                ; Do all input and constant definitions
                MOV     AL,'['          ; Input definitions
                MOV     DI,DEF_AREA[BX] ;
                CALL    SHOW_IT         ; Start
                MOV     AL,']'          ;
                MOV     DI,DEF_AREA[BX+2] ;
                DEC     DI              ;
                DEC     DI              ;
                CMP     DI,DEF_AREA[BX] ; Start and end the same?
                JNE     NOT_DBL1        ;
                MOV     AL,'º'          ;
NOT_DBL1:                               ;
                CALL    SHOW_IT         ; End
                MOV     AL,'{'          ; Constant definitions
                MOV     DI,CONST_AREA[BX] ;
                CALL    SHOW_IT         ; Start
                MOV     AL,'}'          ;
                MOV     DI,CONST_AREA[BX+2] ;
                DEC     DI              ;
                DEC     DI              ;
                CMP     DI,CONST_AREA[BX] ; Start and end the same?
                JNE     NOT_DBL2        ;
                MOV     AL,'Î'          ;
NOT_DBL2:                               ;
                CALL    SHOW_IT         ; End
                ADD     BX,4            ;
                CMP     BX,EDIT_FLD*4   ;
                JB      SHDF_LP         ;
NO_CNDF:                                ;
                POP     BX              ;
NO_SHOW:                                ;
                POP     SI              ;
                POP     DI              ;
                POP     AX              ;
                RET                     ;
;
; Check if on this screen and display if so.
;
SHOW_IT:                                ;
                CMP     DI,0            ; Definition present?
                JZ      NOT_SH          ;
                MOV     AH,[DI+1]       ; Get attribute
                CMP     DI,SI           ; On this screen?
                JB      NOT_SH          ; No
                SUB     DI,SI           ; Offset to this one
                CMP     DI,DISP_SIZE    ; On screen?
                JAE     NOT_SH          ; No
                OR      AH,80H          ; Set blink
                CALL    WRITE_SCREEN    ; Display it
NOT_SH:                                 ;
                RET                     ;
DISP_SCREEN     ENDP                    ;
;
;
; PROCEDURE REST_VID
;
; REST_VID restores the screen as it was prior to doing the menu editing.
;
; INPUT:
;       None
;
; OUTPUT:
;       None
;
REST_VID        PROC                    ;
;
; Save registers used.
;
                PUSH    AX              ;
                PUSH    BX              ;
                PUSH    DX              ;
                PUSH    DI              ;
                PUSH    SI              ;
;
; Restore video modes and screen.
;
                MOV     SI,DISP_LOC     ;
                CMP     SI,0            ; Did we save the screen?
                JZ      NO_REST         ; No
                MOV     AX,WORD PTR SCR_COL ;
                SHL     AX,1            ;
                ADD     DISP_SIZE,AX    ; Include the last line
                MOV     EDIT_LAST,-1    ; Make sure area considered in display
                XOR     DI,DI           ; At top of screen
                CALL    DISP_SCREEN     ; Redisplay the screen
NO_REST:                                ;
                MOV     BH,SAVEPAGE     ;
                MOV     AL,BH           ;
                MOV     AH,PAGE$        ;
                INT     VIDEO$          ;
                MOV     DX,SAVECRS      ;
                MOV     AH,CRS$         ;
                INT     VIDEO$          ; Restore cursor position
                POP     SI              ;
                POP     DI              ;
                POP     DX              ;
                POP     BX              ;
                POP     AX              ;
                RET                     ;
REST_VID        ENDP                    ;
;
;
; PROCEDURE: WRITE_SCREEN
;
; WRITE_SCREEN writes a character directly to the video refresh memory.
;
; INPUT:
;       AX      =       Character and attribute to write
;       DI      =       Location at which to write character
;
; OUTPUT:
;       DI      =       DI + 2
;
WRITE_SCREEN    PROC                    ;
;
; Compute video memory offset.
;
                PUSH    BX              ;
                PUSH    DX              ;
                PUSH    ES              ;
                MOV     ES,VIDEO_SEG    ; Screen segment
                ASSUME  ES:NOTHING      ;
                CMP     FAST,0          ; Fast screen update?
                JNZ     FAST_WRITE      ;
                MOV     BX,AX           ;
                MOV     DX,STATUS_REG   ; Retrieve status register.
HORZ_RET:                               ;
                IN      AL,DX           ; Get status from adaptor
                TEST    AL,1            ; Is it low?
                JNZ     HORZ_RET        ; If not, wait until it is.
                CLI                     ; No more interrupts.
WAIT_RET:                               ;
                IN      AL,DX           ; Get status.
                TEST    AL,1            ; Is it high?
                JZ      WAIT_RET        ; If no, wait until it is.
                MOV     AX,BX           ; Retrieve character; now it's OK
FAST_WRITE:                             ; Move the following code up
                STOSW                   ; to write to screen buffer.
                STI                     ; Interrupts back on.
                POP     ES              ;
                ASSUME  ES:CODE         ;
                POP     DX              ;
                POP     BX              ;
                RET                     ;
WRITE_SCREEN    ENDP                    ;
;
;
; PROCEDURE: TRIM
;
; TRIM determines the last non-blank character in an area on the screen.
; Any location that contains the start or end of a defined input field is
; also considered to be non-blank.
; TRIM also considers a change in attribute value the equivalent of a non-blank.
;
; INPUT:
;       DX      =       Start of area
;       DI      =       End of area+2(i.e., location after end)
;       AH      =       Attribute of preceding location
;
; OUTPUT:
;       DI      =       Last non-blank(or attribute change)+2
;       DI      =       DX, entire area blank
;
TRIM            PROC                    ;
                PUSH    AX              ;
                PUSH    BX              ;
                PUSH    CX              ;
                MOV     AL,[DI-1]       ; Last attribute
TRIM_IT:                                ;
                CMP     DX,DI           ; At start of area?
                JE      TRIM_DONE       ; Yes, nothing to do
                CMP     BYTE PTR [DI-2],' ' ; Blank?
                JNE     TRIM_DONE       ; No, found end
                LEA     CX,[DI-2]       ;
                XOR     BX,BX           ;
TRIM_LP:                                ;
                CMP     BX,DEF_NUM      ; Any more input fields?
                JAE     TRIM_DF         ; No
                CMP     CX,DEF_AREA[BX] ; Start of defined field?
                JE      TRIM_DONE       ; Yes, in next position
                CMP     DI,DEF_AREA[BX+2] ; End of defined field?
                JE      TRIM_DONE       ; Yes
                ADD     BX,4            ; Next definition
                JMP     TRIM_LP         ;
TRIM_DF:                                ;
                CMP     CX,DX           ; At first position?
                JA      TRIM_CK         ; No
                CMP     AH,[DI-1]       ; Is attribute different than entry?
                JNE     TRIM_DONE       ; Yes
                JMP     SHORT TRIM_NA   ;
TRIM_CK:                                ;
                CMP     AL,[DI-3]       ; Does attribute change?
                JNE     TRIM_DONE       ; Yes
TRIM_NA:                                ;
                DEC     DI              ; Back up one
                DEC     DI              ;
                JMP     TRIM_IT         ;
TRIM_DONE:                              ;
                POP     CX              ;
                POP     BX              ;
                POP     AX              ;
                RET                     ;
TRIM            ENDP                    ;
;
;
; PROCEDURE: TBL_SRCH
;
; TBL_SRCH searches a list of characters and returns the index*2 of any match
; or 0 for no match.  The result value may be used to index a corresponding
; table of word size values with the 0th entry being the no-match entry.
;
; INPUT:
;       AL      =       Character to be matched
;       CX      =       Length of table to search
;       SI      =       Location of table to search
;
; OUTPUT:
;       SI      =       0 if no match or index*2 of match
;       CX contents are destroyed
;
TBL_SRCH        PROC                    ;
                PUSH    DI              ;
                MOV     DI,SI           ; Table base
        REPNE   SCASB                   ; Search the table
                JE      TBL_FND         ; If we found a match
                MOV     DI,SI           ; So we generate a 0 result
TBL_FND:                                ;
                SUB     SI,DI           ; Form index
                NEG     SI              ;
                SHL     SI,1            ; Double for word index
                POP     DI              ;
                RET                     ;
TBL_SRCH        ENDP                    ;
;
;
; PROCEDURE: WTBL_SRCH
;
; WTBL_SRCH searches a list of words and returns the index of any match
; or 0 for no match.  The result value may be used to index a corresponding
; table of word size values with the 0th entry being the no-match entry.
;
; INPUT:
;       AX      =       Word to be matched
;       CX      =       Length of table to search
;       SI      =       Location of table to search
;
; OUTPUT:
;       SI      =       0 if no match or index of match
;       CX contents are destroyed
;
WTBL_SRCH       PROC                    ;
                PUSH    DI              ;
                MOV     DI,SI           ; Table base
        REPNE   SCASW                   ; Search the table
                JE      WTBL_FND        ; If we found a match
                MOV     DI,SI           ; So we generate a 0 result
WTBL_FND:                               ;
                SUB     SI,DI           ; Form index
                NEG     SI              ;
                POP     DI              ;
                RET                     ;
WTBL_SRCH       ENDP                    ;
;
;
; PROCEDURE: FIELD_GEN
;
; FIELD_GEN is called when a screen file has been edited and is being output
; to check for input and constant fields and insert the bracketing characters
; as appropriate.
;
; INPUT:
;       AL      =       '[' or ']' for start or end check
;       DI      =       File index to check
;
; OUTPUT:
;       None
;
FIELD_GEN       PROC                    ;
                PUSH    BX              ;
;
; Loop through field definitions.
;
                XOR     BX,BX           ; Check for start of input
                CMP     AL,'['          ; Field start?
                JE      FG_LP           ; Yes
                INC     BX              ; Use end of field
                INC     BX              ;
FG_LP:                                  ;
                CMP     BX,DEF_NUM      ; Any more input fields?
                JAE     NO_DEF          ; No
                CMP     DI,DEF_AREA[BX] ; Start of field?
                JNE     NO_DEF          ; Yes
                CALL    OUT_CHR         ; Put start of input
NO_DEF:                                 ;
                CMP     BX,CONST_NUM    ; Any more constant fields?
                JAE     NO_CONST        ; No
                CMP     DI,CONST_AREA[BX] ; Start of constant?
                JNE     NO_CONST        ;
                OR      AL,20H          ; Put start of constant
                CALL    OUT_CHR         ;
                AND     AL,NOT 20H      ;
NO_CONST:                               ;
                ADD     BX,4            ;
                CMP     BX,EDIT_FLD*4   ; Processed all possible fields?
                JB      FG_LP           ;
                POP     BX              ;
                RET                     ;
FIELD_GEN       ENDP                    ;
;
; Location of reusable space.
;
CHR_LOC         LABEL   BYTE            ; Input buffer
OUT_BUF         EQU     CHR_LOC+L_INB   ; Output I/O buffer
;
; Initialization data.
;
ERROR_MSG       LABEL   BYTE            ;
                DB      "MENU [/D/E/N] screen template out" ;
L_ERROR         EQU     $-ERROR_MSG     ;
OPT_CHR         LABEL   BYTE            ;
                DB      'NDE'           ; Option letters
L_OPT           EQU     $-OPT_CHR       ;
OPT_VECT        LABEL   WORD            ;
                DW      BAD_OPT         ;
                DW      N_OPT           ;
                DW      D_OPT           ;
                DW      E_OPT           ;
;
;
; INIT performs video and file initialization for MENU.  It is placed at the
; end of the program area so that its space may be reused.
;
INIT:                                   ;
;
; Find input file name and open it.
;
                MOV     SI,OFFSET P_CNT ;
                LODSB                   ; Get count
                XOR     AH,AH           ;
                MOV     CX,AX           ;
                XOR     AL,AL           ; Open for input only
                XOR     BX,BX           ; Default to standard input or none
                CALL    OPEN_FILE       ; Parse file name and open file
                JC      ERROR_FILE      ; Error getting file
                MOV     SCREENFILE,AX   ; Save handle
                JMP     GET_TMPL        ;
;
; File does not exist.
;
ERROR_FILE:                             ;
                MOV     CX,L_ERROR      ;
                MOV     DX,OFFSET ERROR_MSG ;
                JMP     ERROR_DSP       ;
;
; Find template file name.
;
GET_TMPL:                               ;
                XOR     BX,BX           ;
                XOR     AL,AL           ;
                CALL    OPEN_FILE       ; Get template file
                JC      ERROR_FILE      ;
                MOV     TEMPLFILE,AX    ; Template handle
;
; Get output file name.
;
                MOV     BX,STDOUT       ; Default to standard output
                MOV     AL,1            ; Open file for writing
                CALL    OPEN_FILE       ;
                JC      ERROR_FILE      ;
                MOV     OUTFILE,AX      ; Output file handle
;
; See if multiple output files specified.
;
                MOV     DI,OFFSET OUT_HNDL ;
OUT_LP:                                 ;
                STOSW                   ; Save handle in output table
                INC     NUM_OUT         ; Increment count of output files
OUT_SKP:                                ;
                JCXZ    CHECK_VOID      ; No more files, check void
                MOV     AL,1            ; Create the file
                CALL    OPEN_FILE       ;
                JC      ERROR_FILE      ;
                CMP     AX,STDOUT       ; Any file name there?
                JNE     OUT_LP          ; Yes
                JMP     OUT_SKP         ; No, skip saving handle
CHECK_VOID:                             ;
                CMP     DOPT,L_DOPT     ; Only /D is legal
                JE      CHECK_VID       ;
                CMP     SCREENFILE,0    ; Any parameters?
                JE      ERROR_FILE      ; No, error
;
; Determine current video modes and save them.
;
CHECK_VID:                              ;
                MOV     AX,BIOS_DATA    ; Point to the ROM BIOS data area
                MOV     DS,AX           ; and get base address of active
                ASSUME  DS:BIOS_DATA    ;
                MOV     AX,ADDR_6845    ; display card.
                PUSH    CS              ; Restore DS
                POP     DS              ;
                ASSUME  DS:CODE         ;
                ADD     AX,6            ; Add six to get status register
                MOV     STATUS_REG,AX   ; Store status register.
                CMP     AX,3BAH         ; Status port of MONO card is 3BAH.
                JE      MONO            ; If that's what we got, it's MONO
                MOV     VIDEO_SEG,COLOR_SEG ; else COLOR so use that seg
                MOV     AH,ALTSEL$      ; Try to select the EGA/VGA
                MOV     BL,10H          ; Ask EGA/VGA for status
                INT     VIDEO$          ;
                CMP     BL,10H          ; EGA/VGA present?
                JE      CGA             ; No, assume old CGA
                MOV     AX,BIOS_DATA    ; There is an EGA/VGA.  Check if it is
                MOV     DS,AX           ; the one we are using.
                ASSUME  DS:BIOS_DATA    ;
                MOV     AL,EGA_INFO     ; Get EGA/VGA status byte
                PUSH    CS              ;
                POP     DS              ;
                ASSUME  DS:CODE         ;
                TEST    AL,EGA_MASK     ; Is EGA/VGA active?
                JNZ     CGA             ; No, do CGA initialization only
;
; Since it is an EGA/VGA, there may be other than 25 lines per screen.  Get the
; actual number and change MENU to use it.
;
                XOR     BH,BH           ;
                MOV     AX,EGASTAT$*256+48 ;
                INT     VIDEO$          ; EGA/VGA get status
                PUSH    CS              ;
                POP     ES              ; Reset ES changed by VIDEO$
                INC     DL              ; Number of lines
                MOV     SCR_LIN,DL      ;
;
; For monochrome and EGA/VGA controllers, we do not need to wait for horizontal
; retrace before putting a character on the display.
;
MONO:                                   ; MDA or EGA/VGA
                MOV     FAST,1          ; Set fast video flag
CGA:                                    ;
                MOV     AH,VIDSTAT$     ; Get video state
                INT     VIDEO$          ;
                MOV     SCR_COL,AH      ; Save number of columns
                MOV     SAVEPAGE,BH     ; Save current video page
                CMP     AL,3            ; Check for legal video modes
                JBE     VID_OK          ; OK
                CMP     AL,7            ;
                JE      VID_OK          ;
                MOV     AH,SMODE$       ;
                MOV     AL,3            ; Switch to standard text mode
                INT     VIDEO$          ;
                MOV     DISP_LOC,0      ; Don't try to save cleared screen
                JMP     CHECK_VID       ; Get state again
VID_OK:                                 ;
                MOV     AH,RDCRS$       ;
                INT     VIDEO$          ; Save cursor position
                MOV     SAVECRS,DX      ;
                MOV     AL,SCR_LIN      ; Compute display area size
                DEC     AL              ;
                MUL     SCR_COL         ;
                MOV     DISP_SIZE,AX    ;
                SHL     DISP_SIZE,1     ; Room for attributes
                ADD     AX,WORD PTR SCR_COL ;
                INC     AX              ; Don't run right up to end
                SHL     AX,1            ; Words
                NEG     AX              ;
                CMP     DISP_LOC,0      ; Are we saving the screen?
                JNZ     SV_SCRN         ; Yes
                XOR     AX,AX           ; No size required
SV_SCRN:                                ;
                ADD     AX,SP           ; Subtract from size of program
                SUB     AX,100H         ; Leave room for stack
                CMP     DISP_LOC,0      ; Save screen?
                JZ      NO_SVSCR        ; No
                MOV     DISP_LOC,AX     ; Location of screen save area
NO_SVSCR:                               ;
;
; Initialize edit area to contain blanks.
;
                MOV     DI,OFFSET EDIT_LOC ;
                SUB     AX,DI           ; Length of file area
                SUB     AX,WORD PTR SCR_COL ; Leave pad for last line spaces
                SHR     AX,1            ;
                CWD                     ;
                DIV     WORD PTR SCR_COL ; Make multiple of line length
                MUL     WORD PTR SCR_COL ;
                SHL     AX,1            ;
                MOV     CX,AX           ;
                ADD     AX,OFFSET EDIT_LOC-2 ;
                MOV     EDIT_LAST,AX    ;
                SHR     CX,1            ; Number of words
                MOV     AL," "          ;
                MOV     AH,SCR_ATTR     ;
        REP     STOSW                   ;
;
; Save current screen.
;
                CMP     DISP_LOC,0      ; Are we saving the screen?
                JZ      NO_SCRN         ; No
                XOR     AL,AL           ;
                MOV     AH,PAGE$        ; Force page 0
                INT     VIDEO$          ;
                MOV     DI,DISP_LOC     ;
                MOV     CX,DISP_SIZE    ;
                SHR     CX,1            ;
                ADD     CX,WORD PTR SCR_COL ; Full screen size
                XOR     SI,SI           ; Start at top of screen
SAV_LP:                                 ;
                CALL    READ_SCREEN     ;
                STOSW                   ; Save
                LOOP    SAV_LP          ;
NO_SCRN:                                ;
                JMP     BEGIN           ; Start processing edit file
;
;
; PROCEDURE: READ_SCREEN
;
; READ_SCREEN writes a character directly from the video refresh memory.
;
; INPUT:
;       SI      =       Location in video refresh memory to read
;
; OUTPUT:
;       AX      =       Character and attribute
;       SI      =       SI + 2
;       DX contents are destroyed.
;
READ_SCREEN     PROC                    ;
                PUSH    ES              ;
                MOV     ES,VIDEO_SEG    ; Screen segment
                ASSUME  ES:NOTHING      ;
                CMP     FAST,0          ; Fast screen?
                JNZ     FAST_READ       ; Yes
;
; Wait for horizontal retrace before reading.
;
                MOV     DX,STATUS_REG   ; Retrieve status register.
HORZ_RET2:                              ;
                IN      AL,DX           ; Get status from adaptor
                TEST    AL,1            ; Is it low?
                JNZ     HORZ_RET2       ; If not, wait until it is.
                CLI                     ; No more interrupts.
WAIT_RET2:                              ;
                IN      AL,DX           ; Get status.
                TEST    AL,1            ; Is it high?
                JZ      WAIT_RET2       ; If no, wait until it is.
FAST_READ:                              ;
                LODS    WORD PTR ES:[SI] ; to read to screen buffer.
                STI                     ; Interrupts back on.
                POP     ES              ;
                ASSUME  ES:CODE         ;
                RET                     ;
READ_SCREEN     ENDP                    ;
;
;
; PROCEDURE OPEN_FILE
;
; OPEN_FILE parses the next file name in the parameter area and opens
; the file.  If the file is opened for output only, the file is created.
;
; INPUT:
;       AL      =       Open mode to use (0=read, 1=create, 2=update)
;       BX      =       File handle to use if field missing
;       CX      =       Remaining input character count
;       SI      =       Next input character
;
; OUTPUT:
;       AX      =       Return from OPEN (handle or error status)
;       CF      =       1, error
;       CX,SI   Updated
;
OPEN_FILE       PROC                    ;
;
; Save registers used.
;
                PUSH    DX              ;
                PUSH    AX              ;
;
; Find start of file name by skipping any white space characters.
;
FIND_AGAIN:                             ;
                JCXZ    MIS_FIL         ;
FIND_STRT:                              ;
                LODSB                   ; Get next character
                CMP     AL," "          ; Skip leading blanks/tabs
                JE      SKIP_SEP        ;
                CMP     AL,TAB_CHR      ;
                JNE     STRT_FND        ; Found start of filename
SKIP_SEP:                               ;
                LOOP    FIND_STRT       ;
MIS_FIL:                                ; Use default file handle
                POP     AX              ;
                POP     DX              ;
                MOV     AX,BX           ;
                CLC                     ;
                RET                     ;
;
; Found start of file name.  Now find end.
;
STRT_FND:                               ;
                CMP     AL,'/'          ; Option?
                JE      DO_OPT          ; Yes
                LEA     DX,[SI-1]       ; Start of file name
                JMP     SHORT CHK_FIL   ;
FIL_LP:                                 ;
                LODSB                   ;
CHK_FIL:                                ;
                CMP     AL," "          ;
                JE      END_FIL         ; Found end of it
                CMP     AL,","          ;
                JE      END_FIL         ;
                CMP     AL,TAB_CHR      ;
                JE      END_FIL         ;
                CMP     AL,CR_CHR       ;
                JE      END_FIL         ;
                LOOP    FIL_LP          ; Continue scanning
                INC     SI              ;
                INC     CX              ;
;
; Found end of file name.  Open file.
;
END_FIL:                                ;
                DEC     CX              ;
                LEA     AX,[SI-1]       ; Ending location
                CMP     AX,DX           ; No file?
                JE      MIS_FIL         ; Yes, use default
                MOV     BYTE PTR [SI-1],0 ; Make ASCIIZ
                POP     AX              ; Open type
                CMP     AL,1            ; Open for output only?
                JE      CRE_FILE        ; Yes
                MOV     AH,OPEN$        ;
                INT     DOS$            ;
                POP     DX              ;
                RET                     ;
;
; Create a new file.
;
CRE_FILE:                               ;
                PUSH    CX              ;
                XOR     CX,CX           ; Normal file type
                MOV     AH,CREATE$      ; Create the file
                INT     DOS$            ;
                POP     CX              ;
                POP     DX              ;
                RET                     ;
;
; Check for /N = No_save_screen.
;        or /D = Display only (Only ANSI sequences processed.)
;        or /E = Edit screen file
;
DO_OPT:                                 ;
                DEC     CX              ;
                JCXZ    MIS_FIL         ;
                LODSB                   ; Get option letter
                DEC     CX              ;
                AND     AL,NOT 20H      ; Force to upper case
                PUSH    CX              ;
                PUSH    SI              ;
                MOV     CX,L_OPT        ;
                MOV     SI,OFFSET OPT_CHR ;
                CALL    TBL_SRCH        ;
                JMP     OPT_VECT[SI]    ; Switch on option
N_OPT:                                  ;
                MOV     DISP_LOC,0      ; No screen save required
OK_OPT:                                 ;
                POP     SI              ;
                POP     CX              ;
                JMP     FIND_AGAIN      ; Continue scanning
D_OPT:                                  ;
                MOV     DOPT,L_DOPT     ; Display only, do not process
                JMP     OK_OPT          ; control characters
E_OPT:                                  ;
                MOV     EOPT,L_EDIT     ; Set edit flag
                JMP     OK_OPT          ; Force display mode
BAD_OPT:                                ;
                POP     SI              ;
                POP     CX              ;
                POP     AX              ;
                POP     DX              ;
                STC                     ; Error signal
                RET                     ;
OPEN_FILE       ENDP                    ;
MENU            ENDP                    ;
EDIT_LOC        EQU     OUT_BUF+L_OUTB  ; Buffer for editing
CODE            ENDS                    ;
                END     MENU            ;
