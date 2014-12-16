



CODE    SEGMENT BYTE PUBLIC
        ASSUME CS:CODE
        PUBLIC SetJmp, LongJmp

SetJmp  PROC FAR
        PUSH    BP
        MOV     BP, SP
        LES     DI, 6[BP]       ; Get address of JumpBuffer
        CLD
        LEA     AX, 6[BP]       ; Save SP
        ADD     AX, 4
        STOSW
        MOV     AX, SS
        STOSW                   ; Save SS
        MOV     AX, 4[BP]
        STOSW                   ; Save CS
        MOV     AX, 2[BP]
        STOSW                   ; Save IP
        MOV     AX, [BP]
        STOSW                   ; Save BP
        MOV     AX, DS
        STOSW                   ; Save DS
        XOR     AX, AX          ; Return a value of 0 from SetJmp
        POP     BP              ; Restore previous frame pointer
        RET     4               ; Clean up stack and return
SetJmp  ENDP

LongJmp PROC    FAR
        PUSH    BP
        MOV     BP, SP
        MOV     BX, 6[BP]       ; Get the return code
        CMP     BX, 1   ; If it is zero then return a value of 1
        ADC     BX, 0   ;       so that LongJmp never returns 0
        LDS     SI, 8[BP]       ; DS:SI points to JumpBuffer
        CLD
        LODSW           ;Restore SS
        MOV     SS, [SI]
        MOV     SP, AX  ;Restore SP
        LODSW
        LODSW
        PUSH    AX      ;Push CS and IP onto the stack
        LODSW
        PUSH    AX
        LODSW
        MOV     BP, AX  ;Restore BP
        LODSW
        MOV     DS, AX  ;Restore DS
        MOV     AX, BX  ;RetValue in AX
        RET             ;Return with CS:IP from JumpBuffer
LongJmp ENDP
CODE    ENDS
        END




