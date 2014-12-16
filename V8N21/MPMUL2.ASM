        title   MPMUL2.ASM Multiple-Precision Unsigned Multiply
        page    55,132

; MPMUL2.ASM    Multiple-Precision Unsigned Multiply
;               for Intel 8086, 8088, 80286, and
;               80386 in real mode/16-bit protected mode.
;               This version uses "shift and add" method.
;
; Copyright (c) 1989 Ziff Davis Communications
; PC Magazine * Ray Duncan
;
; Call with:    DS:SI   = address of source operand
;               ES:DI   = address of destination operand
;               CX      = operand length in bytes
;
;               Assumes direction flag is clear at entry
;               Assumes DS = ES <> SS
;               Assumes 0 < CX <= 255
;
; Returns:      ES:DI   = address of product
;
;               NOTE: Buffer for destination operand must be
;               twice as long as the actual operand, because
;               it will receive a double-precision result.
;
; Destroys:     AX (other registers preserved)
;
_TEXT    segment word public 'CODE'

         assume  cs:_TEXT

         public  mpmul2
mpmul2   proc    near

         push    bx                      ; save registers        
         push    cx
         push    dx
         push    bp

         push    di                      ; save addr of dest argument
         mov     dx,cx                   ; save bytes/operand

         add     di,cx                   ; find address of high half
         mov     bp,di                   ; of product, save it in BP

         xor     al,al                   ; initialize high half of
         rep     stosb                   ; forming product to zero

         pop     di                      ; retrieve addr of dest arg

         mov     cx,dx                   ; CX = bits per argument + 1
         shl     cx,1
         shl     cx,1
         shl     cx,1
         inc     cx

         clc                             ; initialize carry

mpmul21: pushf                           ; save carry flag
         mov     bx,dx                   ; BX = bytes in product - 1
         shl     bx,1
         dec     bx
         popf                            ; restore carry flag

mpmul22: rcr     byte ptr es:[di+bx],1   ; shift forming product and 
         dec     bx                      ; dest operand right 1 bit
         jns     mpmul22                 ; loop while BX >= 0
 
         jnc     mpmul24                 ; jump if bit shifted out = 0

                                         ; bit shifted out = 1
         xchg    bp,di                   ; DI = high half of product
         push    cx                      ; save bit counter
         mov     cx,dx                   ; CX = bytes per argument
         xor     bx,bx                   ; init index (also clears carry)
                                        
mpmul23: mov     al,[si+bx]              ; add source argument to high
         adc     es:[di+bx],al           ; half of forming product
         inc     bx                      
         loop    mpmul23

         pop     cx                      ; restore bit counter
         xchg    bp,di                   ; restore dest operand pointer
 
mpmul24: loop    mpmul21                 ; loop until all bits processed

         pop     bp                      ; restore registers
         pop     dx
         pop     cx
         pop     bx
         ret                             ; back to caller

mpmul2   endp

_TEXT    ends

         end

