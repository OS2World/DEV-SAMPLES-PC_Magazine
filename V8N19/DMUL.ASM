

        title   DMUL.ASM Double Precision Unsigned Multiply
        page    55,132

; DMUL.ASM      Double Precision Unsigned Multiply
;               for 8086, 8088, 80286, and 
;               80386 in real mode/16-bit protected mode
;
; Copyright (C) 1989 Ziff Communications Co.
; PC Magazine * Ray Duncan
;
; Call with:    DX:AX           = double-precision argument 1
;               CX:BX           = double-precision argument 2           
;
; Returns:      DX:CX:BX:AX     = quad-precision product
;
; Destroys:     nothing

_TEXT   segment word public 'CODE'

w0      equ     word ptr [bp-2]         ; local variables
w1      equ     word ptr [bp-4]
w2      equ     word ptr [bp-6]
w3      equ     word ptr [bp-8]

        assume  cs:_TEXT

        public  dmul
dmul    proc    near

        push    si                      ; save registers
        push    di
        push    bp                      ; set up stack frame
        mov     bp,sp                   ; for forming result
        sub     sp,8

        mov     di,dx                   ; save copy of argument 1
        mov     si,ax

        mul     bx                      ; arg1 low * arg2 low
        mov     w0,ax
        mov     w1,dx

        mov     ax,di                   ; arg1 high * arg2 high
        mul     cx
        mov     w2,ax
        mov     w3,dx

        mov     ax,di                   ; arg1 high * arg2 low
        mul     bx
        add     w1,ax                   ; accumulate result
        adc     w2,dx
        adc     w3,0

        mov     ax,si                   ; arg1 low * arg2 high
        mul     cx
        add     w1,ax                   ; accumulate result
        adc     w2,dx
        adc     w3,0

        pop     dx                      ; load quad-precision result
        pop     cx
        pop     bx
        pop     ax

        pop     bp                      ; restore registers
        pop     di
        pop     si
        ret                             ; and exit

dmul    endp

_TEXT   ends

        end


