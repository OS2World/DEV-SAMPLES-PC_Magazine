;------------------------------------------------------;
;  Convert.com - Converts either a number or character ;
;  to complementary radices.                           ;
;  Decimal, Hexadecimal, Octal and Binary supported.   ;
;  PC Magazine * Michael J. Mefford                    ;
;------------------------------------------------------;
_TEXT          SEGMENT PUBLIC 'CODE'
               ASSUME  CS:_TEXT,DS:_TEXT,ES:_TEXT,SS:_TEXT
               ORG     100H
START:         JMP     MAIN

;              DATA AREA
;              ---------
SYNTAX         DB      CR,SPACE,SPACE,SPACE,CR,LF
COPYRIGHT      DB      "CONVERT 1.0 (C) 1989 Ziff Communications Co.",CR,LF
PROGRAMMER     DB      "PC Magazine ",BOX," Michael J. Mefford",CR,LF,LF

               DB      "Syntax:  CONVERT number[-number][radix] | "
               DB      QUOTES,"character(s)",QUOTES,CR,LF
               DB      "radix:  b = binary, h = hexadecimal, o = octal",CR,LF
               DB      "default is decimal",LF,"$",CTRL_Z

CR             EQU     13
LF             EQU     10
CTRL_Z         EQU     26
SPACE          EQU     32
QUOTES         EQU     34
BOX            EQU     254
SPACE_CNT      EQU     5

INVALID_MSG    DB      "Invalid parameter",CR,LF
               DB      "number range: 0 - 65535",CR,LF,"$"

RADIX_TYPE     DB      "HOB"                   ;Hex, octal, binary.
RADIX_CNT      EQU     $ - RADIX_TYPE

INPUT_CALLS    DW      DECIMAL_INPUT, HEX_INPUT, OCTAL_INPUT, BINARY_INPUT
CALLS_END      EQU     $ - 2

;              CODE AREA
;              ---------

;------------------------------------------------------------------------;
; Capitalize the parameters so a single compare for radices can be done. ;
;------------------------------------------------------------------------;
MAIN           PROC    NEAR
               CLD                             ;All string moves forward.
               CMP     BYTE PTR DS:[80H],0     ;Are there parameters?
               JNZ     PARSE                   ;If yes, continue.
               JMP     ERROR_EXIT              ;Else, exit with syntax message.

;------------------------------------------------------------------------------;
; Parse the parameters by looking for either carriage return, quotes, or dash. ;
;------------------------------------------------------------------------------;
PARSE:         MOV     DL,LF                   ;Print a linefeed just to first
               CALL    PRINT_CHAR              ; to make our output look pretty.
               MOV     SI,82H                  ;Point to parameters again.
NEXT_INPUT:    MOV     BP,SI                   ;Start parameter start.
NEXT_PARSE:    LODSB                           ;Get a byte.
               CMP     AL,CR                   ;Is it carriage return?
               JZ      EVALUATE                ;If yes, done here.
               CMP     AL,QUOTES               ;Is it quotes?
               JZ      CHARACTER               ;If yes, character entry.
               CMP     AL,"-"                  ;Is it delimiting dash?
               JNZ     NEXT_PARSE              ;If no, find parameter end.
               CMP     BP,82H                  ;Else, is this first dash?
               JNZ     EVALUATE                ;If no, evaluate just the two.
               PUSH    SI                      ;Save our position.
               CALL    GET_NUMBER              ;Get the parameter.
               POP     SI                      ;Restore our position.
               PUSH    BX                      ;Save the number.
               JMP     SHORT NEXT_INPUT        ;Get second parameter.

;----------------------------------------------------------------------;
; If quotes were detected, store up to two characters to be evaluated. ;
;----------------------------------------------------------------------;
CHARACTER:     XOR     BX,BX                   ;Assume no characters.
               LODSB                           ;Get a byte.
               CMP     AL,CR                   ;End of parameter?
               JZ      ERROR_EXIT              ;If yes, no character; exit.
               MOV     BL,AL                   ;Else, store character.
               LODSB                           ;Get next character.
               CMP     AL,CR                   ;End of parameter?
               JZ      GOT_CHAR                ;If yes, only one character.
               CMP     AL,QUOTES               ;Is it quotes?
               JNZ     GET_CHAR                ;If no, valid second character.
               CMP     BYTE PTR [SI],QUOTES    ;Is it followed by quotes?
               JNZ     GOT_CHAR                ;If no, not quotes in quotes.
GET_CHAR:      MOV     BH,AL                   ;Else, store second character.
               XCHG    BH,BL                   ;Swap so in right order.
GOT_CHAR:      XOR     CX,CX                   ;Zero out parameter count.
               JMP     SHORT CONVERT           ;Convert the character.

;-------------------------------------------------------------;
; Find range of numbers and display the complementry radices. ;
;-------------------------------------------------------------;
EVALUATE:      CALL    GET_NUMBER              ;Get the parameter.
               XOR     CX,CX                   ;Assume only one parameter.
               CMP     BP,82H                  ;Where there more than one?
               JZ      CONVERT                 ;If no, convert just the one.
               POP     CX                      ;Else, retrieve the first one.
               CMP     CX,BX                   ;Is it the larger of the two?
               JA      FIND_RANGE              ;If yes, find range.
               XCHG    BX,CX                   ;Else, swap numbers.
FIND_RANGE:    SUB     CX,BX                   ;Find difference.

CONVERT:       INC     CX                      ;Increment by one for "thru".
               MOV     DI,BX                   ;Save number to be converted.
OUTPUT:        PUSH    CX                      ;Save count to be converted.
               CALL    DECIMAL_OUTPUT          ;Display decimal, hexadecimal,
               CALL    SPACE_IT                ; octal and binary equivalents
               CALL    HEX_OUTPUT              ; with spaces in between.
               CALL    SPACING
               CALL    OCTAL_OUTPUT
               CALL    SPACING
               CALL    BINARY_OUTPUT
               CALL    SPACING
               CALL    ASCII_OUTPUT
               MOV     DL,CR
               CALL    PRINT_CHAR
               MOV     DL,LF
               CALL    PRINT_CHAR
               INC     DI                      ;Get ready for next number.
               POP     CX                      ;Retrieve conversion count.
               LOOP    OUTPUT                  ;Do them all.
               XOR     AL,AL                   ;Exit with ErrorLevel of zero.
               JMP     SHORT EXIT

;---------------------------------------------------------------------------;
; Exit with syntax message and ErrorLevel of 1 if error, else ErrorLevel 0. ;
;---------------------------------------------------------------------------;
ERROR_EXIT:    MOV     DX,OFFSET SYNTAX        ;Display syntax.
               CALL    PRINT_STRING
               MOV     AL,1                    ;ErrorLevel one.
EXIT:          MOV     AH,4CH
               INT     21H                     ;Terminate.
MAIN           ENDP

;              *************
;              *SUBROUTINES*
;              *************

;------------------------------------------------------------------------------;
; INPUT:  SI points to byte after parameter end; BP points to parameter start. ;
; OUTPUT: BX = number.                                                         ;
; CALLS:  DECIMAL_INPUT, HEX_INPUT, OCTAL_INPUT, BINARY_INPUT.                 ;
;------------------------------------------------------------------------------;
GET_NUMBER     PROC    NEAR
               DEC     SI                      ;Adjust pointer to parameter end.
               MOV     CX,SI                   ;Save SI.
               MOV     SI,BP                   ;Point to parameter start.
NEXT_CAP:      CMP     SI,CX                   ;Are we end of parameter?
               JZ      STRING_LENGTH           ;If yes, done here.
               LODSB                           ;Get a byte.
               CMP     AL,"a"
               JB      NEXT_CAP
               CMP     AL,"z"
               JA      NEXT_CAP
               AND     BYTE PTR [SI-1],5FH     ;Capitalize.
               JMP     SHORT NEXT_CAP

STRING_LENGTH: MOV     SI,BP                   ;Point to parameter start.
               SUB     CX,BP                   ;Find parameter length.
               PUSH    CX                      ;Save it.

NEXT_RADIX:    XCHG    CX,BX                   ;Save count in BX.
               LODSB                           ;Get a byte.
               MOV     CX,RADIX_CNT            ;Count of radix appendixes in CX.
               MOV     DI,OFFSET RADIX_TYPE    ;Point to appendixes.
               REPNZ   SCASB                   ;Is it an appendix?
               JZ      INPUT                   ;If yes, evaluate.
               XCHG    CX,BX                   ;Else, retrieve parameter count.
LOOP_RADIX:    LOOP    NEXT_RADIX              ;Check next byte.
               MOV     CX,RADIX_CNT            ;If no appendix, assume decimal.

INPUT:         SHL     CX,1                    ;Convert count to word pointer.
               MOV     DI,OFFSET CALLS_END     ;Point to input calls end.
               SUB     DI,CX                   ;Point to appropriate call.
               POP     CX                      ;Retrieve parameter length.
               MOV     SI,BP                   ;Point to parameter start.
               XOR     BX,BX                   ;Start with a zero number.
               CALL    [DI]                    ;Get the number.
               MOV     DX,OFFSET INVALID_MSG   ;Print error message if
               JNC     END_NUMBER              ; number invalid.
               CALL    PRINT_STRING
               JMP     SHORT ERROR_EXIT
END_NUMBER:    RET                             ;Else, return with number in BX.
GET_NUMBER     ENDP

;----------------------------------------------------------------------;
; INPUT:  SI points to parameter start; CX = parameter length; BX = 0. ;
; OUTPUT: BX = number; CY = 0 if valid entry; CY = 1 if invalid entry. ;
;----------------------------------------------------------------------;
DECIMAL_INPUT  PROC    NEAR
NEXT_DECIMAL:  LODSB                           ;Get a character.
               SUB     AL,"0"                  ;ASCII to binary.
               JC      LOOP_DECIMAL            ;If not between 0 and 9, skip.
               CMP     AL,9
               JA      LOOP_DECIMAL
               CBW                             ;Convert to word.
               XCHG    AX,BX                   ;Swap old and new number.
               PUSH    CX                      ;Preserve counter.
               MOV     CX,10                   ;Shift to left by multiplying
               MUL     CX                      ; last entry by ten.
               POP     CX                      ;Retrieve counter.
               JC      END_DECIMAL             ;If carry, too big.
               ADD     BX,AX                   ;Add new number and store in BX.
               JC      END_DECIMAL             ;If carry, too big.
LOOP_DECIMAL:  LOOP    NEXT_DECIMAL
               CLC
END_DECIMAL:   RET
DECIMAL_INPUT  ENDP

;-----------------------------------------------------------------------;
; INPUT  : SI points to parameter start; CX = parameter length; BX = 0. ;
; OUTPUT : BX = number; CY = 0 if valid entry; CY = 1 if invalid entry. ;
;-----------------------------------------------------------------------;
BINARY_INPUT   PROC    NEAR
NEXT_BIN:      LODSB                           ;Get a byte.
               SUB     AL,"0"                  ;ASCII to binary.
               JC      LOOP_BIN                ;If not 0 or 1, skip.
               CMP     AL,1
               JA      LOOP_BIN
               SHL     BX,1                    ;Shift old number left one bit.
               JC      END_BIN                 ;If carry, too big.
               OR      BL,AL                   ;Else, add it to the number.
LOOP_BIN:      LOOP    NEXT_BIN
               CLC
END_BIN:       RET
BINARY_INPUT   ENDP

;-----------------------------------------------------------------------;
; INPUT  : SI points to parameter start; CX = parameter length; BX = 0. ;
; OUTPUT : BX = number; CY = 0 if valid entry; CY = 1 if invalid entry. ;
;-----------------------------------------------------------------------;
HEX_INPUT      PROC    NEAR
NEXT_HEX:      LODSB                           ;Get a byte.
               SUB     AL,"0"                  ;ASCII to binary.
               JC      LOOP_HEX                ;If not 0 to 9, skip.
               CMP     AL,9                    ;Is it A - F ?
               JLE     NOT_ALPHA               ;If no, OK.
               SUB     AL,7                    ;Else, adjust for alpha.
               CMP     AL,10                   ;Is it punctuation?
               JB      LOOP_HEX                ;If yes, skip.
               CMP     AL,15                   ;Is it valid?
               JA      LOOP_HEX                ;If no, skip.
NOT_ALPHA:     TEST    BX,1111b SHL 12         ;Is the number going to overflow?
               STC                             ;Assume yes.
               JNZ     END_HEX                 ;If yes, too big.
               PUSH    CX                      ;Else, preserve counter.
               MOV     CL,4                    ;Shift old number four bits left.
               SHL     BX,CL
               POP     CX                      ;Retrieve counter.
               OR      BL,AL                   ;Add to number.
LOOP_HEX:      LOOP    NEXT_HEX
               CLC
END_HEX:       RET
HEX_INPUT      ENDP

;-----------------------------------------------------------------------;
; INPUT  : SI points to parameter start; CX = parameter length; BX = 0. ;
; OUTPUT : BX = number; CY = 0 if valid entry; CY = 1 if invalid entry. ;
;-----------------------------------------------------------------------;
OCTAL_INPUT    PROC    NEAR
NEXT_OCTAL:    LODSB                           ;Get a byte.
               SUB     AL,"0"                  ;ASCII to binary.
               JC      LOOP_OCTAL              ;If not 0 through 7, skip.
               CMP     AL,7
               JA      LOOP_OCTAL
               TEST    BX,111b SHL 13          ;Is the number going to overflow?
               STC                             ;Assume yes.
               JNZ     END_OCTAL               ;If yes, too big.
               PUSH    CX                      ;Else, save counter.
               MOV     CL,3                    ;Shift old number left three bits
               SHL     BX,CL
               POP     CX                      ;Retrieve counter.
               OR      BL,AL                   ;Add to number.
LOOP_OCTAL:    LOOP    NEXT_OCTAL
               CLC
END_OCTAL:     RET
OCTAL_INPUT    ENDP

;-----------------------------------------------------------------------;
; INPUT  : SI points to parameter start; CX = parameter length; BX = 0. ;
; OUTPUT : BX = number; CY = 0 if valid entry; CY = 1 if invalid entry. ;
;-----------------------------------------------------------------------;
DECIMAL_OUTPUT PROC    NEAR
               MOV     AX,DI                   ;Retrieve number.
               MOV     BX,10                   ;Divisor of ten.
               XOR     CX,CX                   ;Zero in counter.
NEXT_COUNT:    XOR     DX,DX                   ;Zero in high half.
               DIV     BX                      ;Divide by ten.
               ADD     DL,"0"                  ;Convert to ASCII.
               PUSH    DX                      ;Save results.
               INC     CX                      ;Also increment count.
               CMP     AX,0                    ;Are we done?
               JNZ     NEXT_COUNT              ;Continue until zero.
               MOV     BX,CX                   ;Save the number of characters.

NEXT_NUMBER:   POP     DX                      ;Retrieve numbers.
               CALL    PRINT_CHAR              ;And write them.
               LOOP    NEXT_NUMBER
               MOV     CX,SPACE_CNT + 5        ;Return with tab count.
               SUB     CX,BX
               RET
DECIMAL_OUTPUT ENDP

;----------------------------------------;
; INPUT: DI = number.                    ;
;----------------------------------------;
HEX_OUTPUT     PROC    NEAR
               MOV     BX,DI                   ;Retrieve number.
               MOV     CX,404H                 ;4 positions/word; 4bits/char.
ROTATE_HEX:    ROL     BX,CL                   ;Move highest bits to lowest.
               MOV     DL,BL
               AND     DL,1111B                ;Mask off all but four lowest.
               ADD     DL,"0"                  ;Convert to ASCII.
               CMP     DL,"9"                  ;Is it alpha.
               JLE     PRINT_HEX               ;If no, print it.
               ADD     DL,7                    ;Else, adjust.
PRINT_HEX:     CALL    PRINT_CHAR              ;And write them.
               DEC     CH                      ;Done all four positions?
               JNZ     ROTATE_HEX              ;If no, get next.

               MOV     DL,"h"                  ;Tack on hex character.
               CALL    PRINT_CHAR
               RET
HEX_OUTPUT     ENDP

;----------------------------------------;
; INPUT: DI = number.                    ;
;----------------------------------------;
OCTAL_OUTPUT   PROC    NEAR
               MOV     BX,DI                   ;Retrieve number.
               MOV     CX,603H                 ;6 positions/word; 3bits/char.
               ROL     BX,1                    ;Special case first; get top bit.
               MOV     DL,BL
               AND     DL,1                    ;Mask off all but that bit.
               JMP     SHORT OCTAL_ASCII       ;Write it.

OCTAL_ROTATE:  ROL     BX,CL                   ;Rotate highest 3 bits to lowest.
               MOV     DL,BL
               AND     DL,111B                 ;Mask off all but lowest 3 bits.
OCTAL_ASCII:   ADD     DL,"0"                  ;Convert to ASCII.
               CALL    PRINT_CHAR              ;Write it.
               DEC     CH                      ;Do all 6 positions.
               JNZ     OCTAL_ROTATE

               MOV     DL,"o"                  ;Tack on octal character.
               CALL    PRINT_CHAR
               RET
OCTAL_OUTPUT   ENDP

;----------------------------------------;
; INPUT: DI = number.                    ;
;----------------------------------------;
BINARY_OUTPUT  PROC    NEAR
               MOV     BX,DI                   ;Retrieve number.
               MOV     CH,16                   ;Display all 16 positions.
ROTATE_BIN:    ROL     BX,1                    ;Move highest bit to lowest.
               MOV     DL,BL
               AND     DL,1                    ;Mask off all but lowest.
               ADD     DL,"0"                  ;Convert to ASCII.
               CALL    PRINT_CHAR
               CMP     CH,9                    ;Format with space between bytes.
               JNZ     SKIP_SPACE
               MOV     DL,SPACE
               CALL    PRINT_CHAR
SKIP_SPACE:    DEC     CH                      ;Do all 16 bits.
               JNZ     ROTATE_BIN

               MOV     DL,"b"                  ;Tack on binary character.
               CALL    PRINT_CHAR
               RET
BINARY_OUTPUT  ENDP

;----------------------------------------;
; INPUT: DI = number.                    ;
;----------------------------------------;
ASCII_OUTPUT   PROC    NEAR
               XOR     BH,BH                   ;Page zero.
               MOV     AX,0E22H                ;Write TTY a quote mark.
               INT     10H                     ; via BIOS.

               MOV     CX,3                    ;Display 3 quotation marks and
               MOV     AX,0A22H                ; do not update cursor position.
               INT     10H
               MOV     CX,2                    ;Display the low byte twice
               MOV     AX,DI
               MOV     AH,0AH                  ; at current cursor position.
               INT     10H
               MOV     CX,1                    ;Display the high byte once
               MOV     AX,DI                   ; at current cursor position
               XCHG    AL,AH
               MOV     AH,0AH                  ; over the first low byte.
               INT     10H
               RET
ASCII_OUTPUT   ENDP

;---------------------------------------------------------------;
; These subroutines print and separate the display with spaces. ;
;---------------------------------------------------------------;
PRINT_CHAR     PROC    NEAR
               MOV     AH,2                    ;DOS display output.
               INT     21H                     ;Character is in DL.
               RET
PRINT_CHAR     ENDP

;-------------------------;
PRINT_STRING   PROC    NEAR
               MOV     AH,9                    ;DOS string output.
               INT     21H                     ;DX points to string
               RET                             ; terminated by "$".
PRINT_STRING   ENDP

;-------------------------;
SPACING        PROC    NEAR
               MOV     CX,SPACE_CNT            ;Retrieve space count between
SPACE_IT:      MOV     DL,SPACE                ; outputs and print via DOS.
               CALL    PRINT_CHAR
               LOOP    SPACE_IT
               RET
SPACING        ENDP

_TEXT          ENDS
               END     START
