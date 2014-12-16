        title   DIMUL87.ASM 80x87-based Signed Divide
        page    55,132

; DIMUL87.ASM   Double Precision Signed Integer Multiply
;               for 80x87 coprocessor and 8086, 8088, 80286, or
;               80386 in real mode/16-bit protected mode
;
;               Be sure to call INIT87 routine first to test for 
;               coprocessor existence and to set rounding mode, 
;               precision, and exception masks!
;
; Copyright (C) 1989 Ziff Davis Communications
; PC Magazine * Ray Duncan
;
; Call with:    DX:AX           = double-precision argument 1
;               CX:BX           = double-precision argument 2           
;
; Returns:      DX:CX:BX:AX     = quad-precision product
;
; Destroys:     nothing

_TEXT   segment word public 'CODE'

        assume  cs:_TEXT

        public  dimul
dimul   proc    near

        push    dx                      ; put argument 1 on stack
        push    ax      

        push    cx                      ; put argument 2 on stack
        push    bx

        mov     bx,sp                   ; make arguments addressable

        fild    dword ptr ss:[bx]       ; load one argument
        fimul   dword ptr ss:[bx+4]     ; multiply it by the other

        fistp   qword ptr ss:[bx]       ; unload the result
        fwait                           ; wait for it to arrive

        pop     ax                      ; retrieve result
        pop     bx
        pop     cx
        pop     dx
        ret                             ; and exit

dimul   endp

_TEXT   ends

        end

