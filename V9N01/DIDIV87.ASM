        title   DIDIV87.ASM 80x87-based Signed Divide
        page    55,132

; DIDIV87.ASM   Double Precision Signed Integer Divide
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
; Call with:    DX:CX:BX:AX     = quad-precision dividend
;               SI:DI           = double-precision divisor
;
; Returns:      DX:AX           = double-precision quotient     
;               CX:BX           = double-precision remainder
;
; Destroys:     nothing

_TEXT   segment word public 'CODE'

        assume  cs:_TEXT

        public  didiv
didiv   proc    near

        push    dx                      ; put dividend on stack
        push    cx
        push    bx
        push    ax

        push    si                      ; put divisor on stack
        push    di

        mov     bx,sp                   ; make arguments addressable

        fild    dword ptr ss:[bx]       ; put divisor on coprocessor
        fild    qword ptr ss:[bx+4]     ; put dividend on coprocessor

        fld     st(1)                   ; make copies of both
        fld     st(1)

        fdivrp  st(1),st(0)             ; perform signed divide

        fistp   dword ptr ss:[bx]       ; unload quotient

        fprem                           ; calculate remainder

        fistp   dword ptr ss:[bx+4]     ; unload remainder
        fstp    st(0)                   ; discard stack top

        pop     ax                      ; quotient into DX:AX
        pop     dx

        pop     bx                      ; remainder into CX:BX
        pop     cx

        add     sp,4                    ; clean up stack
        ret                             ; and exit
        
didiv   endp

_TEXT   ends

        end

