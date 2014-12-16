        title   EXTMEM --- get/put extended memory
        page    55,132

; EXTMEM.ASM --- Routines to transfer data between
;                conventional and extended memory.
;                For use with small model C programs.
; Copyright (C) 1989 Ziff Davis Communications
; PC Magazine * Ray Duncan
;
; Assemble with: MASM /Zi /Mx EXTMEM;

DGROUP  group   _DATA

_DATA   segment word public 'DATA'

gdt     db      30h dup (0)     ; global descriptor table

_DATA   ends


_TEXT   segment word public 'CODE'

        assume  cs:_TEXT,ds:DGROUP

args    equ     [bp+4]          ; offset of arguments, small model
source  equ     word ptr args
dest    equ     word ptr source+4
len     equ     word ptr dest+4

;
; GETXM copies data from extended memory to conventional memory.
; 
; status = getxm(unsigned long source, void far *dest, unsigned len)
;
; Status is zero if move successful, nonzero if move failed:
; 1 = parity error, 2 = exception interrupt error, 3 = gate A20 failed
;
        public  _getxm
_getxm  proc    near

        push    bp              ; set up stack frame
        mov     bp,sp
        push    si              ; protect register variables
        push    di

        push    ds              ; let ES:SI point to
        pop     es              ; global descriptor table
        mov     si,offset DGROUP:gdt

                                ; store access rights bytes
        mov     byte ptr es:[si+15h],93h
        mov     byte ptr es:[si+1dh],93h

        mov     ax,source       ; store source address
        mov     es:[si+12h],ax  ; into descriptor
        mov     ax,source+2
        mov     es:[si+14h],al

        mov     ax,dest+2       ; destination segment * 16
        mov     dx,16
        mul     dx
        add     ax,dest         ; + offset -> linear address
        adc     dx,0
        mov     es:[si+1ah],ax  ; store destination address
        mov     es:[si+1ch],dl  ; into descriptor

        mov     cx,len  ; store length into source
        mov     es:[si+10h],cx  ; and destination descriptors
        mov     es:[si+18h],cx 

        shr     cx,1            ; convert length to words
        mov     ah,87h          ; Int 15H Fxn 87h = block move
        int     15h             ; transfer to ROM BIOS 

        mov     al,ah           ; form status in AX     
        cbw

        pop     di              ; restore registers
        pop     si
        pop     bp
        ret                     ; back to caller

_getxm  endp

;
; PUTXM copies data from conventional memory to extended memory.
; 
; status = putxm(void far *source, unsigned long dest, unsigned len)
;
; Status is zero if move successful, nonzero if move failed:
; 1 = parity error, 2 = exception interrupt error, 3 = gate A20 failed
;
        public  _putxm
_putxm  proc    near

        push    bp              ; set up stack frame
        mov     bp,sp
        push    si              ; protect register variables
        push    di

        push    ds              ; let ES:SI point to
        pop     es              ; global descriptor table
        mov     si,offset DGROUP:gdt

                                ; store access rights bytes
        mov     byte ptr es:[si+15h],93h
        mov     byte ptr es:[si+1dh],93h

        mov     ax,dest         ; store destination address
        mov     es:[si+1ah],ax  ; into descriptor
        mov     ax,dest+2
        mov     es:[si+1ch],al

        mov     ax,source+2     ; source segment * 16
        mov     dx,16
        mul     dx
        add     ax,source       ; + offset -> linear address
        adc     dx,0
        mov     es:[si+12h],ax  ; store source address
        mov     es:[si+14h],dl  ; into descriptor

        mov     cx,len          ; store length into source
        mov     es:[si+10h],cx  ; and destination descriptors
        mov     es:[si+18h],cx 

        shr     cx,1            ; convert length to words
        mov     ah,87h          ; Int 15H Fxn 87h = block move
        int     15h             ; transfer to ROM BIOS 

        mov     al,ah           ; form status in AX
        cbw

        pop     di              ; restore registers
        pop     si
        pop     bp
        ret                     ; back to caller

_putxm  endp

_TEXT   ends

        end

