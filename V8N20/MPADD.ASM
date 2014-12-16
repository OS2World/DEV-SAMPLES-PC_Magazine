        title   MPADD.ASM Multiple-Precision Integer Addition
        page    55,132

; MPADD.ASM     Multiple-Precision Integer Addition
;               for Intel 8086, 8088, 80286, and
;               80386 in real mode/16-bit protected mode
;
; Copyright (C) 1989 Ziff Davis Communications
; PC Magazine * Ray Duncan
;
; Call with:    DS:SI   = address of source operand
;               ES:DI   = address of destination operand
;               CX      = operand length in bytes
;               Assumes direction flag is clear at entry
;
; Returns:      ES:DI   = address of result
;
; Destroys:     AL, CX, SI (other registers preserved)

_TEXT   segment word public 'CODE'

        assume  cs:_TEXT

        public  mpadd
mpadd   proc    near

        push    di                      ; save address of result
        clc                             ; carry initially clear

mpadd1: lodsb                           ; next byte from source
        adc     byte ptr es:[di],al     ; accumulate sum
        inc     di
        loop    mpadd1                  ; until all bytes processed

        pop     di                      ; restore address of result
        ret                             ; back to caller

mpadd   endp

_TEXT   ends

        end

