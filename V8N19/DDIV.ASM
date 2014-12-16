
        title   DDIV.ASM Double Precision Unsigned Divide
        page    55,132

; DDIV.ASM      Double Precision Unsigned Divide
;               for 8086, 8088, 80286, and 
;               80386 in real mode/16-bit protected mode
;
; Copyright (C) 1989 Ziff Communications Co.
; PC Magazine * Ray Duncan
;
; Call with:    DX:CX:BX:AX     = quad-precision dividend
;               SI:DI           = double-precision divisor
;
; Returns:      DX:AX           = double-precision quotient     
;               CX:BX           = double-precision remainder
;
; Destroys:     SI, DI

_TEXT   segment word public 'CODE'

        assume  cs:_TEXT

        public  ddiv
ddiv    proc    near

        push    bp              ; save register
        mov     bp,cx           ; BP = 3sw of dividend
        mov     cx,32           ; initialize loop counter
        clc                     ; carry flag initially clear

ddiv1:  rcl     ax,1            ; test this bit of dividend
        rcl     bx,1
        rcl     bp,1
        rcl     dx,1
        jnc     ddiv3           ; jump if bit was clear

ddiv2:  sub     bp,di           ; subtract divisor from dividend
        sbb     dx,si
        stc                     ; force carry flag set and
        loop    ddiv1           ; shift it into forming quotient
        jmp     ddiv5

ddiv3:  cmp     dx,si           ; dividend > divisor?
        jc      ddiv4           ; no, jump
        jne     ddiv2           ; yes, subtract divisor
        cmp     bp,di
        jnc     ddiv2           ; yes, subtract divisor

ddiv4:  clc                     ; force carry flag clear and
        loop    ddiv1           ; shift it into forming quotient

ddiv5:  rcl     ax,1            ; bring last bit into quotient
        rcl     bx,1

        mov     cx,bp
        xchg    dx,bx           ; put quotient in DX:AX
        xchg    cx,bx           ; put remainder in CX:BX

        pop     bp              ; restore register
        ret                     ; and exit
        
ddiv    endp

_TEXT   ends

        end

