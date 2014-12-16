        title   MPMUL1.ASM Multiple-Precision Unsigned Multiply
        page    55,132

; MPMUL1.ASM    Multiple-Precision Unsigned Multiply
;               for Intel 8086, 8088, 80286, and
;               80386 in real mode/16-bit protected mode
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
;
; Usage:        DS:SI = u[0] base address source operand
;               SS:BP = v[0] base address destination operand
;               ES:DI = w[0] base address of product
;               BX    = i    index for outer loop
;               CX    = j    index for inner loop
;               DH    = m    operand length in bytes
;               DL    = k    remainder of partial products

_TEXT    segment word public 'CODE'

         assume  cs:_TEXT

         public  mpmul1
mpmul1   proc    near

         push    bx                      ; save registers
         push    dx
         push    bp
         sub     sp,cx                   ; make buffer on stack
         mov     bp,sp                   ; for destination operand
         mov     dh,cl                   ; save operand length (m)

         push    cx
         push    si                      ; copy destination operand
         push    di                      ; to temporary storage in
         push    es                      ; stack frame, because result
         push    ss                      ; will be built in destination
         pop     es                      ; operand's buffer
         mov     si,di
         mov     di,bp
         rep     movsb
         pop     es
         pop     di
         pop     si
         pop     cx

         push    di                      ; initialize destination buffer
         xor     ax,ax                   ; to receive result (it better be 
         rep     stosw                   ; twice the size of the operands)
         pop     di

         xor     bx,bx                   ; i = 0
 
mpmul11: xor     dl,dl                   ; k = 0
         xor     cx,cx                   ; j = 0

mpmul12: xchg    bx,cx
         mov     al,[si+bx]              ; get u[j]
         xchg    bx,cx
 
         xchg    bp,di
         mov     ah,ss:[di+bx]           ; get v[i]
         xchg    bp,di
        
         mul     ah                      ; t = u[j] * v[i]
         add     al,dl                   ;     + k
         adc     ah,0
         add     bx,cx
         add     al,[bx+di]              ;     + w[i+j]
         adc     ah,0
         mov     [bx+di],al              ; w[i+j] = t mod b
         mov     dl,ah                   ; k      = t / b
         sub     bx,cx                   ; restore i

         inc     cx                      ; j++
         cmp     cl,dh                   ; j = m?
         jne     mpmul12                 ; no, repeat inner loop

         push    bx
         add     bl,dh                   ; w[i+m] = k
         adc     bh,0
         mov     [di+bx],ah
         pop     bx

         inc     bx                      ; i++
         cmp     bl,dh                   ; i = m?
         jne     mpmul11                 ; no, repeat outer loop

         add     sp,bx                   ; discard operand buffer
         pop     bp                      ; restore registers
         pop     dx
         pop     bx
         ret                             ; back to caller

mpmul1   endp

_TEXT    ends

         end

