        title   MPIDIV.ASM Multiple-Precision Signed Divide
        page    55,132

; MPIDIV.ASM    Multiple-Precision Signed Division
;               for Intel 8086, 8088, 80286, and
;               80386 in real mode/16-bit protected mode.
;               Requires MPNEG.ASM (multiple-precision
;               2's complement) and MPDIV.ASM (multiple-
;               precision unsigned integer divide).
;
; Copyright (c) 1989 Ziff Davis Communications
; PC Magazine * Ray Duncan
;
; Call with:    DS:SI   = address of divisor
;               ES:DI   = address of dividend
;               CX      = divisor length in bytes
;                         (dividend length = 2 * divisor length)
;
;               Assumes direction flag is clear at entry
;               Assumes DS = ES <> SS
;               Assumes 0 < CX <= 255
;
; Returns:      ES:DI   = address of quotient
;               DS:SI   = address of remainder
;
;               NOTE: Dividend is assumed to be twice as long
;               as the divisor.  Returned remainder and quotient 
;               are same size as divisor.
;
;               The sign of the quotient is positive if the signs
;               signs of the dividend and divisor are the same;
;               negative if they are different.  The sign of the
;               remainder is the same as the sign of the dividend.
;
; Destroys:     AX (other registers preserved)

_TEXT   segment word public 'CODE'

        extrn   mpdiv:near 
        extrn   mpneg:near

        assume  cs:_TEXT

        public  mpidiv
mpidiv  proc    near

        push    bx                      ; save registers

        mov     bx,cx                   ; get Exclusive-OR of
        mov     al,[si+bx-1]            ; signs of operands
        add     bx,bx
        xor     al,[di+bx-1]
        pushf                           ; save sign of result           

        mov     al,[di+bx-1]            ; test sign of dividend
        or      al,al
        pushf                           ; save sign of remainder

        jns     mpid1                   ; jump if dividend positive

        push    si                      ; save pointer to divisor
        push    cx                      ; save length of divisor

        mov     si,di                   ; point to dividend
        add     cx,cx                   ; calc length of dividend
        call    mpneg                   ; flip sign of dividend

        pop     cx                      ; restore length of divisor
        pop     si                      ; restore address of divisor

mpid1:  mov     bx,cx                   ; check if divisor negative
        test    byte ptr [si+bx-1],80h
        jz      mpid2                   ; jump, divisor is positive

        push    di                      ; save pointer to dividend
        call    mpneg                   ; flip sign of divisor
        pop     di                      ; restore pointer to dividend

mpid2:  call    mpdiv                   ; perform unsigned divide

        popf                            ; retrieve sign of remainder
        jns     mpid3                   ; jump, remainder is positive

        push    di                      ; save pointer to quotient
        call    mpneg                   ; flip sign of remainder
        pop     di                      ; restore pointer to quotient

mpid3:  popf                            ; retrieve sign of result
        jns     mpid4                   ; jump, result is positive

        push    si                      ; save pointer to remainder
        mov     si,di                   ; point to quotient
        call    mpneg                   ; flip sign of quotient
        pop     si                      ; restore pointer to remainder

mpid4:  pop     bx                      ; restore register
        ret                             ; back to caller

mpidiv  endp

_TEXT   ends

        end

