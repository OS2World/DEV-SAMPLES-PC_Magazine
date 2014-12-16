








;********** FLAGS.ASM

;Syntax: CALL ClearAll                'clear all flags
;        CALL ClearFlag(FlagNum%)     'clear flag number FlagNum%
;        CALL SetFlag(FlagNum%)       'set flag number FlagNum%
;        Flag = GetFlag%(FlagNum%)    'retrieve flag number FlagNum%

.Model Medium, Basic
.Code

    Public ClearAll, ClearFlag, SetFlag, GetFlag

ClearAll Proc Far
     Push CS                           ;copy the code segment into ES
     Pop  ES
     Mov  DI,Offset CS:Flags           ;point DI to the flag words
     Mov  CX,4                         ;clear 4 words
     Xor  AX,AX                        ;set AX = 0
     Rep  Stosw                        ;store 4 zero words
     Ret                               ;return to BASIC
ClearAll Endp

ClearFlag Proc Far
     Push BP                           ;set BP to incoming variable
     Mov  BP,SP
     Mov  SI,[BP+06]                   ;get the address for FlagNum%
     Call DoFlag                       ;let DoFlag handle the common code
     Jc   ExitClear                    ;if carry is set, FlagNum% was illegal
     Not  AL                           ;reverse to clear the flag
     And  CS:Flags [BX],AL             ;set the appropriate Flag bit

ExitClear:
     Pop  BP                           ;restore BP
     Ret  2                            ;return to BASIC
ClearFlag Endp

SetFlag Proc Far
     Push BP                           ;set BP to incoming variable
     Mov  BP,SP
     Mov  SI,[BP+06]                   ;get the address for FlagNum%
     Call DoFlag                       ;let DoFlag do the work
     Jc   ExitSet                      ;if carry is set, FlagNum% was illegal
     Or   CS:Flags [BX],AL             ;set the appropriate Flag bit

ExitSet:
     Pop  BP                           ;restore BP
     Ret  2                            ;return to BASIC
SetFlag Endp

GetFlag Proc Far
     Push BP                           ;set BP to incoming variable
     Mov  BP,SP
     Mov  SI,[BP+06]                   ;get the address for FlagNum%
     Call DoFlag                       ;let DoFlag worry about it
     Test CS:Flags [BX],AL             ;see if the bit is set
     Mov  AX,0                         ;assume it isn't
     Jz   ExitGet                      ;we were right
     Dec  AX                           ;no, assign -1 for the function output

ExitGet:
     Pop  BP                           ;restore BP
     Ret  2                            ;return to BASIC
GetFlag Endp

DoFlag Proc Near                       ;common code for the other routines
     Mov  AX,[SI]                      ;put FlagNum% into AX
     Dec  AX                           ;adjust 1-64 to 0-63
     Cmp  AX,63                        ;see if it's too high
     Ja   DoError                      ;it is, get out

     Push AX                           ;save AX for later
     Mov  CX,8                         ;divide by eight
     Xor  DX,DX                        ;clear DX for the divide
     Div  CX                           ;now AX points to the correct flag word
     Mov  BX,AX                        ;transfer to BX for an index

     Mov  AL,1                         ;make a bit
     Pop  CX                           ;retrieve the flag number
     Rol  AL,CL                        ;now the bit is in position
     Clc                               ;clear the carry to show no error
     Ret                               ;return to caller

DoError:
     Stc                               ;set the carry to show an error
     Ret                               ;return to caller
DoFlag Endp

     Flags   DB 8 Dup (0)              ;this holds the flags

End



