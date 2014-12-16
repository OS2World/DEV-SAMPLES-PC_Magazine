        title   MPDIV.ASM Multiple-Precision Unsigned Divide
        page    55,132

; MPDIV.ASM     Multiple-Precision Unsigned Divide
;               using "shift-and-subtract" method
;               for Intel 8086, 8088, 80286, and
;               80386 in real mode/16-bit protected mode.
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
; Destroys:     AX (other registers preserved)

_TEXT   segment word public 'CODE'

        assume  cs:_TEXT

        public  mpdiv
mpdiv   proc    near

        push    bx                      ; save registers        
        push    cx
        push    dx
        push    si
        push    di
        push    bp

        mov     dx,cx                   ; save divisor length in DX

        mov     bp,cx                   ; BP will be outer loop 
        shl     bp,1                    ; counter, set it to number
        shl     bp,1                    ; of bits in divisor
        shl     bp,1

        clc                             ; initially clear carry

mpdiv1: push    di                      ; save pointer to dividend
        mov     cx,dx                   ; CX = bytes in dividend

mpdiv2: rcl     word ptr [di],1         ; shift carry flag into
        inc     di                      ; low bit of quotient
        inc     di                      ; shift high bit of dividend
        loop    mpdiv2                  ; into carry flag

        pop     di                      ; restore pointer to dividend

        jnc     mpdiv5                  ; jump if high bit was clear

mpdiv3: push    si                      ; save pointer to divisor
        push    di                      ; save pointer to dividend

        add     di,dx                   ; DI = addr high half of dividend
        mov     cx,dx                   ; CX = bytes in divisor
        clc                             ; initially clear carry

mpdiv4: mov     al,[si]                 ; subtract divisor from high
        sbb     [di],al                 ; half of dividend
        inc     si
        inc     di
        loop    mpdiv4

        pop     di                      ; restore pointer to dividend
        pop     si                      ; restore pointer to divisor

        stc                             ; shift bit=1 into quotient
        dec     bp                      ; all bits of answer generated?
        jnz     mpdiv1                  ; no, loop
        jmp     mpdiv7                  ; yes, go clean up and exit

mpdiv5: push    si                      ; save pointer to divisor
        push    di                      ; save pointer to dividend

        add     di,dx                   ; point to high half of dividend
        mov     cx,dx                   ; CX = bytes in divisor
        clc                             ; initially clear carry

mpdiv6: mov     al,[di]                 ; high half of dividend > divisor?
        sbb     al,[si]
        inc     si
        inc     di
        loop    mpdiv6

        pop     di                      ; restore pointer to dividend
        pop     si                      ; restore pointer to divisor

        jnc     mpdiv3                  ; jump, high dividend > divisor

        clc                             ; shift bit=0 into quotient
        dec     bp                      ; all bits of answer generated?
        jnz     mpdiv1                  ; no, loop again

mpdiv7: mov     cx,dx                   ; CX = bytes in quotient

mpdiv8: rcl     byte ptr [di],1         ; bring final bit into quotient
        inc     di             
        loop    mpdiv8         

        xchg    si,di                   ; copy remainder to final address
        mov     cx,dx
        rep movsb

        pop     bp                      ; restore registers
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        ret                             ; back to caller

mpdiv   endp

_TEXT   ends

        end

