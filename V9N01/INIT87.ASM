        title   INIT87.ASM Initialize Numeric Coprocessor
        page    55,132

; INIT87.ASM    Initialize 80x87 Numeric Coprocessor
;
; Copyright (C) 1989 Ziff Davis Communications
; PC Magazine * Ray Duncan
;
; Call with:    AX      = control word for desired rounding
;                         mode, precision, exception mask
;
; Returns:      (if coprocessor present)
;               Z flag  = True (1)
;
;               (if coprocessor not found)
;               Z flag  = False (0)
;
; Destroys:     nothing

_TEXT   segment word public 'CODE'

        assume  cs:_TEXT

        public  init87
init87  proc    near

        push    bx                      ; save registers
        push    ax

        mov     ax,-1                   ; put FFFFH on stack
        push    ax
        mov     bx,sp                   ; make it addressable

        fninit                          ; try to initialize coprocessor
        fnstsw  ss:[bx]                 ; try to get status word
        
        pop     ax                      ; if low 8 bits are zero,
        or      al,al                   ; coprocessor is present

        jnz     initx                   ; jump if no coprocessor

        fldcw   ss:[bx+2]               ; load coprocessor control word

initx:  pop     ax                      ; restore registers
        pop     bx
        ret                             ; and return result in Z flag

init87  endp

_TEXT   ends

        end

