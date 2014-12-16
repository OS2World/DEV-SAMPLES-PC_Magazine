



        title   DMUL386.ASM Double Precision Unsigned Multiply
        page    55,132
        .386

; DMUL386.ASM   Double Precision Unsigned Multiply
;               for 80386 32-bit protected mode
;
; Copyright (C) 1989 Ziff Communications Co.
; PC Magazine * Ray Duncan
;
; Call with:    EDX:EAX         = double-precision argument 1
;               ECX:EBX         = double-precision argument 2           
;
; Returns:      EDX:ECX:EBX:EAX = quad-precision product
;
; Destroys:     nothing

_TEXT   segment dword public use32 'CODE'

w0      equ     dword ptr [ebp-4]       ; local variables
w1      equ     dword ptr [ebp-8]
w2      equ     dword ptr [ebp-12]
w3      equ     dword ptr [ebp-16]

        assume  cs:_TEXT

        public  dmul
dmul    proc    near

        push    esi                     ; save registers
        push    edi
        push    ebp                     ; set up stack frame
        mov     ebp,esp                 ; for forming result
        sub     esp,16

        mov     edi,edx                 ; save copy of argument 1
        mov     esi,eax

        mul     ebx                     ; arg1 low * arg2 low
        mov     w0,eax
        mov     w1,edx

        mov     eax,edi                 ; arg1 high * arg2 high
        mul     ecx
        mov     w2,eax
        mov     w3,edx

        mov     eax,edi                 ; arg1 high * arg2 low
        mul     ebx
        add     w1,eax                  ; accumulate result
        adc     w2,edx
        adc     w3,0

        mov     eax,esi                 ; arg1 low * arg2 high
        mul     ecx
        add     w1,eax                  ; accumulate result
        adc     w2,edx
        adc     w3,0

        pop     edx                     ; load quad-precision result
        pop     ecx
        pop     ebx
        pop     eax

        pop     ebp                     ; restore registers
        pop     edi
        pop     esi
        ret                             ; and exit

dmul    endp

_TEXT   ends

        end


