  

        title   DDIV386.ASM Double Precision Unsigned Divide
        page    55,132
        .386

; DDIV386.ASM   Double Precision Unsigned Divide
;               for 80386 32-bit protected mode
;
; Copyright (C) 1989 Ziff Communications Co.
; PC Magazine * Ray Duncan
;
; Call with:    EDX:ECX:EBX:EAX = quad-precision dividend
;               ESI:EDI         = double-precision divisor
;
; Returns:      EDX:EAX         = double-precision quotient     
;               ECX:EBX         = double-precision remainder
;
; Destroys:     ESI, EDI

_TEXT   segment dword public use32 'CODE'

        assume  cs:_TEXT

        public  ddiv
ddiv    proc    near

        push    ebp             ; save register
        mov     ebp,ecx         ; EBP = 3sw of dividend
        mov     ecx,64          ; initialize loop counter
        clc                     ; carry flag initially clear

ddiv1:  rcl     eax,1           ; test this bit of dividend
        rcl     ebx,1
        rcl     ebp,1
        rcl     edx,1
        jnc     ddiv3           ; jump if bit was clear

ddiv2:  sub     ebp,edi         ; subtract divisor from dividend
        sbb     edx,esi
        stc                     ; force carry flag set and
        loop    ddiv1           ; shift it into forming quotient
        jmp     ddiv5

ddiv3:  cmp     edx,esi         ; dividend > divisor?
        jc      ddiv4           ; no, jump
        jne     ddiv2           ; yes, subtract divisor
        cmp     ebp,edi
        jnc     ddiv2           ; yes, subtract divisor

ddiv4:  clc                     ; force carry flag clear and
        loop    ddiv1           ; shift it into forming quotient

ddiv5:  rcl     eax,1           ; bring last bit into quotient
        rcl     ebx,1

        mov     ecx,ebp
        xchg    edx,ebx         ; put quotient in EDX:EAX
        xchg    ecx,ebx         ; put remainder in ECX:EBX

        pop     ebp             ; restore register
        ret                     ; and exit
        
ddiv    endp

_TEXT   ends

        end

