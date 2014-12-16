        title   MPNEG.ASM Multiple-Precision 2's Complement
        page    55,132

; MPNEG.ASM     Multiple-Precision 2's Complement Routine
;               for Intel 8086, 8088, 80286, and
;               80386 in real mode/16-bit protected mode
;
; Copyright (C) 1989 Ziff Davis Communications
; PC Magazine * Ray Duncan
;
; Call with:    DS:SI   = address of argument
;               CX      = argument length in bytes
;               Assumes direction flag is clear at entry
;
; Returns:      ES:DI   = address of result
;
; Destroys:     Nothing

_TEXT   segment word public 'CODE'

        assume  cs:_TEXT

        public  mpneg
mpneg   proc    near

        mov     di,si                   ; save address of result
        push    cx                      ; save two copies of 
        push    cx                      ; argument length

mpneg1: not     byte ptr [si]           ; 1's complement this digit
        inc     si                      ; advance through argument
        loop    mpneg1                  ; until all digits inverted

        pop     cx                      ; retrieve length of argument
        mov     si,di                   ; retrieve first-byte-address
        stc                             ; set carry to add 1

mpneg2: adc     byte ptr [si],0         ; add 1 to 1's complement
        inc     si                      ; to get 2's complement
        loop    mpneg2                  ; until all digits finished

        pop     cx                      ; restore operand length
        mov     si,di                   ; restore argument address
        ret                             ; back to caller

mpneg   endp

_TEXT   ends

        end

