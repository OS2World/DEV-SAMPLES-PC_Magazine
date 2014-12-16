        title   MPIMUL.ASM Multiple-Precision Signed Multiply
        page    55,132

; MPIMUL.ASM    Multiple-Precision Signed Multiply
;               for Intel 8086, 8088, 80286, and
;               80386 in real mode/16-bit protected mode.
;               Requires MPNEG.ASM (multiple-precision
;               2's complement) and MPMUL1.ASM (multiple-
;               precision unsigned integer multiply).
;
; Copyright (C) 1989 Ziff Davis Communications
; PC Magazine * Ray Duncan
;
; Call with:    DS:SI   = address of source operand
;               ES:DI   = address of destination operand
;               CX      = operand length in bytes
;
;               Assumes direction flag is clear at entry
;               Assumes DS = ES <> SS
;               Assumes CX <= 255
;
; Returns:      ES:DI   = address of product
;
;               NOTE: Buffer for destination operand must be
;               twice as long as the actual operand, because
;               it will receive a double-precision result.
;
; Destroys:     AX (other registers preserved)

_TEXT   segment word public 'CODE'

        extrn   mpmul1:near 
        extrn   mpneg:near

        assume  cs:_TEXT

        public  mpimul
mpimul  proc    near

        push    bx                      ; save registers

        mov     bx,cx                   ; take Exclusive-OR of
        mov     al,[si+bx-1]            ; signs of operands
        xor     al,[di+bx-1]
        pushf                           ; save sign of result           

        test    byte ptr [si+bx-1],80h  ; source operand negative?
        jz      mpim1                   ; no, jump

        push    di                      ; yes, flip sign of 
        call    mpneg                   ; source operand
        pop     di

mpim1:  test    byte ptr [di+bx-1],80h  ; destination operand negative?
        jz      mpim2                   ; no, jump
        push    si                      ; yes, flip sign of
        mov     si,di                   ; destination operand
        call    mpneg
        pop     si

mpim2:  call    mpmul1                  ; perform unsigned multiply

        popf                            ; retrieve sign of result
        jns     mpim3                   ; jump, result is positive

        push    si                      ; operand signs were not
        push    cx                      ; same, make result negative
        mov     si,di
        shl     cx,1
        call    mpneg
        pop     cx
        pop     si

mpim3:  pop     bx                      ; restore register
        ret                             ; back to caller

mpimul  endp

_TEXT   ends

        end

