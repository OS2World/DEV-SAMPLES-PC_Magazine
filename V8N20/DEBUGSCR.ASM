; DebugScr converts any disk file into a hexadecimal ASCII script text file.
; Unlike binary files like .EXEs, .COMs or 123 data files, the script file can
; then be sent via a data service like MCI or CIS as an ordinary text file.
; The recipient recreates the original binary file by redirecting the script
; file as Debug's input thus:
;
;              DEBUG < filename.SCR
;
; where filename.SCR is the name of script file created by DEBUGSCR.COM.

_TEXT          SEGMENT PUBLIC 'CODE'
               ASSUME  CS:_TEXT,DS:_TEXT,ES:_TEXT,SS:_TEXT
               ORG     100H
START:         JMP     MAIN

;              DATA AREA
;              ---------
SIGNATURE      DB      CR,SPACE,SPACE,SPACE,CR,LF
COPYRIGHT      DB      "DEBUGSCR 1.0 (C) 1989 Ziff Communications Co. ",CR,LF
PROGRAMMER     DB      "PC Magazine ",BOX," Michael J. Mefford",CR,LF,LF

DB             "Syntax:  DEBUGSCR filespec [/N]",CR,LF,LF
DB             "/N = No instruction messages in script",CR,LF,LF
DB             "filename.SCR will be created",CR,LF
DB             "To recreate file, Enter",CR,LF,LF

DB             TAB,     "DEBUG < filename.SCR",CR,LF,LF,"$",CTRL_Z

TAB            EQU     9
CR             EQU     13
LF             EQU     10
CTRL_Z         EQU     26
SPACE          EQU     32
BOX            EQU     254

FILESPEC_START DW     ?
FILESPEC_END   DW     ?
FILENAME_START DW     ?
FILENAME_LEN   DW     ?
DOT_ADDRESS    DW     ?

EXE_FLAG       DB     0                        ;Set if and EXE 
                                               ; extension found.
MSG_FLAG       DB     0                        ;Set if no suppress script msg.
FILE_LENGTH    DW     ?
HANDLE         DW     ?
LINE_NO        DW     100H
CHAR_CT        DW     ?

FILE           DB     "File"
NOT_FOUND      DB     " not found",CR,LF,LF,"$"
DISK_ERROR     DB     "Disk error",CR,LF,LF,"$"
DOT_SCR        DB     ".SCR",0,"$"
EXE            DB     ".EXE",CR,LF
TOO_BIG        DB     "Input file too big; can't be more than 60K",CR,LF,LF,"$"
NOT_ENOUGH     DB     "Not enough memory; requires 64K",CR,LF,LF,"$"
CREATED        DB     "created",CR,LF,LF,"$"

RCX            DB     " RCX",CR,LF
WQ             DB     " W",CR,LF
               DB     " Q",CR,LF,CR,LF

SCRIPT_END DB  TAB, "If you have downloaded this script file, remove",CR,LF
           DB  TAB, "any captured communications header and then enter",CR,LF
           DB  CR,LF,TAB,TAB,"DEBUG < filename",CR,LF,CR,LF
           DB  TAB,"where filename is the name of this script file.",CR,LF
SCRIPT_END_LEN EQU $ - SCRIPT_END

EXE_MSG   DB  CR,LF
          DB  TAB,"Note this is an EXE script.  Debug will not create",CR,LF
          DB  TAB,"a file with an EXE name extension.  You have to add",CR,LF
          DB  TAB,"the EXE extension yourself AFTER the file is created",CR,LF
          DB  TAB,"by Debug by entering the following at the DOS prompt",CR,LF
          DB  CR,LF

          DB  TAB,"RENAME "
EXE_MSG_LENGTH EQU    $ - EXE_MSG

;              CODE AREA
;              ---------
MAIN           PROC   NEAR
               CLD
               MOV    DX,OFFSET SIGNATURE      ;Display copyright and syntax.
               CALL   PRINT_STRING

               MOV    BX,64 / 16 * 1024        ;Minimum 64K memory required.
               MOV    AH,4AH
               INT    21H
               MOV    DX,OFFSET NOT_ENOUGH
               JNC    CAPITALIZE
               JMP    ERROR_EXIT

CAPITALIZE:    MOV    SI,81H                   ;Capitalize the command line.
NEXT_CAP:      LODSB
               CMP    AL,CR
               JZ     PARSE
               CMP    AL,"/"
               JNZ    CK_CAP
               MOV    BYTE PTR [SI - 1],CR
               LODSB
               AND    AL,5FH
               CMP    AL,"N"
               JNZ    PARSE
               MOV    MSG_FLAG,1
               JMP    SHORT PARSE
CK_CAP:        CMP    AL,"a"
               JB     NEXT_CAP
               CMP    AL,"z"
               JA     NEXT_CAP
               AND    BYTE PTR [SI - 1],5FH
               JMP    NEXT_CAP

PARSE:         MOV    SI,81H                   ;Parse the command line.
FIND_START:    LODSB                           ;Find first non-white space.
               CMP    AL,CR
               JNZ    CK_SPACE
               MOV    DX,OFFSET FILE           ;If no parameter, display
               JMP    ERROR_EXIT               ; error message.
CK_SPACE:      CMP    AL,SPACE
               JBE    FIND_START

               DEC    SI                       ;Adjust.
               MOV    BP,SI                    ;BP = Filespec start.
               MOV    FILESPEC_START,BP        ;Save it.
               MOV    DX,SI                    ;DX = Filename start.
               XOR    CX,CX                    ;CX = dot flag.
FIND_END:      LODSB
               CMP    AL,":"                   ;If colon or backslash found,
               JZ     FOUND_PATH               ; it's a path specifier
               CMP    AL,"\"
               JNZ    CK_DOT
FOUND_PATH:    MOV    DX,SI                    ;Filename start.
CK_DOT:        CMP    AL,"."                   ;If dot, extension follows.
               JNZ    CK_END
               MOV    CX,SI
               DEC    CX                       ;Adjust.
CK_END:        CMP    AL,SPACE                 ;Carriage return marks end of
               JA     FIND_END                 ; command line.
               DEC    SI                       ;Adjust.
               MOV    BYTE PTR [SI],0          ;ASCIIZ the filespec.
               MOV    FILESPEC_END,SI          ;Save filespec end.
               MOV    FILENAME_START,DX        ;Save filename start.
               MOV    DOT_ADDRESS,CX           ;Save address of extension.

               MOV    DX,BP                    ;Retrieve filespec start.
               MOV    AX,3D00H                 ;Open file for reading.
               INT    21H
               JNC    OPENED
               MOV    BYTE PTR [SI],"$"        ;If failed, display message.
               CALL   PRINT_STRING
               MOV    DX,OFFSET NOT_FOUND
               JMP    ERROR_EXIT

OPENED:        MOV    BX,AX                    ;Else, BX = filehandle.
               MOV    DX,OFFSET BUFFER         ;Point to input buffer.
               MOV    CX,(60 * 1024) + 1       ;Read 60K + 1.
               MOV    AH,3FH
               INT    21H
               JNC    CK_SIZE
               MOV    DX,OFFSET DISK_ERROR     ;If failed, disk error.
               JMP    ERROR_EXIT

CK_SIZE:       CMP    AX,CX                    ;Did we read 60K + 1.
               JNZ    SAVE_SIZE
               MOV    DX,OFFSET TOO_BIG        ;If yes, too big.
               JMP    ERROR_EXIT

SAVE_SIZE:     MOV    FILE_LENGTH,AX           ;Else, save file size.
               MOV    AH,3EH                   ;Close input file.
               INT    21H

               MOV    BX,FILESPEC_END          ;Retrieve filespec end.
               MOV    BP,DOT_ADDRESS           ;Retrieve extension address.
               OR     BP,BP                    ;Is there an extension?
               JNZ    CK_EXE                   ;If yes, see if it's an EXE.
               MOV    BP,BX                    ;Else, filename end=
                                               ; filespec end.
               JMP    SHORT STORE_NAME

CK_EXE:        MOV    SI,BP                    ;Point to extension address.
               MOV    DI,OFFSET EXE            ;And ".EXE"
               MOV    CX,4
               REP    CMPSB
               JNZ    STORE_NAME               ;If the extension is EXE then
               MOV    EXE_FLAG,1               ; special case.
               MOV    BX,BP                    ;filespec end=
                                               ; extension address.

STORE_NAME:    MOV    SI,FILENAME_START        ;Filename.
               MOV    CX,BX                    ;Calculate filename length.
               SUB    CX,SI
               MOV    FILENAME_LEN,CX          ;Save length
               MOV    DI,OFFSET DTA + 3        ;Place name in DTA.
               REP    MOVSB

MAKE_SCRIPT:   MOV    SI,OFFSET DOT_SCR        ;Convert filespec to script
               MOV    DI,BP                    ; name by adding .SCR 
                                               ; extension.
               MOV    CX,6
               REP    MOVSB

               MOV    DX,FILESPEC_START        ;Create a normal file with the
               XOR    CX,CX                    ; .SCR extension on it's name.
               MOV    AH,3CH
               INT    21H
               JNC    SAVE_HANDLE
               MOV    DX,OFFSET DISK_ERROR     ;If failed, disk error.
               JMP    ERROR_EXIT
SAVE_HANDLE:   MOV    HANDLE,AX                ;Else, save file handle.

               MOV    CX,FILENAME_LEN          ;Retrieve length of filename.
               ADD    CX,3                     ;Add 3 for space,"N",space.
               CALL   WRITE                    ;Write to disk.

;----------------------------------------------;
; This is the hexadecimal E loop.              ;
;----------------------------------------------;
               MOV    BP,FILE_LENGTH           ;Retrieve file length.
               MOV    SI,OFFSET BUFFER         ;Point to input file buffer.
NEXT_LINE:     MOV    DI,OFFSET DTA + 1        ;Point to write storage.
               MOV    CHAR_CT,3                ;Chars to write; start with 3.
               CALL   E                        ;Get the (E)nter address.
               MOV    CX,16                    ;16 numbers per line

NEXT_BYTE:     MOV    AL,SPACE                 ;Space delimiter.
               STOSB
               INC    CHAR_CT                  ;Count it.
               LODSB                           ;Get a byte from input file.
               CALL   CONVERT                  ;Convert to ASCII hexadecimal.
               DEC    BP                       ;One less input character.
               JZ     END_FILE                 ;If that last one, done.
               LOOP   NEXT_BYTE                ;Else, do 16 numbers/line.
               MOV    CX,CHAR_CT               ;Retrieve length of line.
               CALL   WRITE                    ;Write it to disk.
               JMP    SHORT NEXT_LINE          ;Next line.

END_FILE:      MOV    CX,CHAR_CT               ;Write the last line to disk.
               CALL   WRITE

               MOV    DX,OFFSET RCX            ;Add "RCX" line.
               MOV    CX,6
               CALL   DOS_WRITE
               MOV    AX,FILE_LENGTH           ;Retrieve length of file.
               PUSH   AX                       ;Save low half.
               MOV    AL,AH                    ;Convert high half to 
                                               ; ASCII hex.
               MOV    DI,OFFSET DTA + 1
               CALL   CONVERT
               POP    AX                       ;Retrieve low half and convert 
               CALL   CONVERT                  ; it also to ASCII hex.
               MOV    CX,5
               CALL   WRITE                    ;Write that line to disk.
               MOV    DX,OFFSET WQ             ;Write "W" and "Q".
               MOV    CX,10
               CALL   DOS_WRITE
               CMP    MSG_FLAG,1
               JZ     CLOSE_FILE
               MOV    DX,OFFSET SCRIPT_END     ;Finish up with instuctions.
               MOV    CX,SCRIPT_END_LEN
               CALL   DOS_WRITE

               CMP    EXE_FLAG,1               ;Was there the special case of
               JNZ    CLOSE_FILE               ; and EXE extension.
               MOV    DX,OFFSET EXE_MSG        ;If no, done here.
               MOV    CX,EXE_MSG_LENGTH        ;Else, add EXE message 
                                               ; to script.
               CALL   DOS_WRITE
               MOV    DX,FILENAME_START        ;Add REN filename.
               PUSH   DX
               MOV    CX,FILENAME_LEN
               PUSH   CX
               CALL   DOS_WRITE
               MOV    DX,OFFSET DTA            ;Add delimiting space.
               MOV    CX,1
               CALL   DOS_WRITE
               POP    CX
               POP    DX                       ;Add new name
               CALL   DOS_WRITE
               MOV    DX,OFFSET EXE            ; with the .EXE extension.
               MOV    CX,6
               CALL   DOS_WRITE

CLOSE_FILE:    MOV    BX,HANDLE                ;Close output file.
               MOV    AH,3EH
               INT    21H
               JC     WRITE_FAIL
               MOV    DX,FILESPEC_START        ;Retrieve output filespec.
               CALL   PRINT_STRING             ;Display it followed by
               MOV    DX,OFFSET CREATED        ; "created".
               CALL   PRINT_STRING
               XOR    AL,AL                    ;ErrorLevel = 0.
               JMP    SHORT EXIT               ;Done.

;----------------------------------------------;
WRITE_FAIL:    MOV    DX,OFFSET DISK_ERROR     ;Generic disk error message.
ERROR_EXIT:    CALL   PRINT_STRING
               MOV    AL,1                     ;ErrorLevel = 1.

EXIT:          MOV    AH,4CH                   ;Terminate.
               INT    21H
MAIN           ENDP

;********* SUBROUTINES *********;

DOS_WRITE:     MOV    AH,40H                   ;Write to file.
               INT    21H
               JC     WRITE_FAIL               ;Exit with message if failed.
               RET

;----------------------------------------------;
; INPUT: CX = count of chars to write.         ;
;----------------------------------------------;
WRITE:         MOV    DX,OFFSET DTA            ;Point to Disk 
                                               ; Transfer Area.
               MOV    BX,HANDLE                ;Output filehandle.
               CALL   DOS_WRITE                ;Write DTA.
NEW_LINE:      MOV    BYTE PTR DTA + 1,CR      ;Add Carriage return 
                                               ; and linefeed
               MOV    BYTE PTR DTA + 2,LF
               MOV    DX,OFFSET DTA + 1
               MOV    CX,2
               CALL   DOS_WRITE
               RET

;----------------------------------------------;
E:             MOV    AL,"E"                   ;Store the "E"
               STOSB
               MOV    AL,SPACE                 ; and space delimiter.
               STOSB
               MOV    AX,LINE_NO               ;Retrieve the line number.
               PUSH   AX
               XCHG   AL,AH
               CALL   CONVERT                  ;Convert high half to 
                                               ; ASCII hex.
               POP    AX
               MOV    AX,LINE_NO
               CALL   CONVERT                  ;Convert the low half.
               ADD    LINE_NO,16               ;Next line number.
               RET

;----------------------------------------------------------;
; INPUT: AL = binary number; DI -> appropriate DTA address ;
;----------------------------------------------------------;
CONVERT:       PUSH    CX                      ;Preserve loop counter.
               MOV     DX,2                    ;Two ASCII 
                                               ; hex bytes/binary byte.
               MOV     BL,AL                   ;Preserve binary number.
ROTATE:        MOV     CL,4
               ROL     BL,CL                   ;Rotate by four bits.
               MOV     AL,BL
               AND     AL,0FH                  ;Mask off high four bits.
               ADD     AL,"0"                  ;Convert to ASCII.
               CMP     AL,"9"                  ;If A-F, add 7.
               JBE     STORE_HEX
               ADD     AL,7
STORE_HEX:     STOSB                           ;Store in DTA.
               INC     CHAR_CT                 ;Increment count to write.
               DEC     DX                      ;Next half.
               JNZ     ROTATE
               POP     CX                      ;Restore loop counter.
               RET

;----------------------------------------------;
PRINT_STRING:  MOV    AH,9                     ;DOS print string.
               INT    21H
               RET

DTA            DB      SPACE,"N",SPACE
BUFFER         =       DTA + 100

_TEXT ENDS
END   START
