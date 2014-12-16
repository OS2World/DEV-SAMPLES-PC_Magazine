

        title   ARGC -- count command line arguments
        page    55,132
        .386

; ARGC.ASM:     Return count of command line arguments.
;               Treats blanks and tabs as whitespace.
;
; 80386 version for Phar Lap DOS|Extender
; Copyright (C) 1989 Ziff Communications Co.
; PC Magazine * Ray Duncan
; 
; Call with:    N/A
;
; Returns:      EAX    = argument count (always >=1)
;
; Uses:         nothing (other registers preserved)
;
; Warning: uses "magic" Phar Lap hard-wired selectors
; to address environment and PSP.  Code will need adjustment
; for other 80386 protected-mode environments.

cr      equ     0dh             ; ASCII carriage return
tab     equ     09h             ; ASCII tab code
blank   equ     20h             ; ASCII space code

pspsel  equ     24h             ; selector for prog seg prefix
cmdtail equ     80h             ; buffer for command tail

_TEXT   segment dword use32 public 'CODE'

        assume  cs:_TEXT

        public  argc
argc    proc    near

        push    ebx             ; save registers
        push    ecx
        push    es

        mov     ebx,pspsel      ; set ES:EBX = command tail
        mov     es,bx
        mov     ebx,cmdtail

        mov     eax,1           ; force count >= 1

argc1:  mov     ecx,-1          ; set flag = outside argument

argc2:  inc     ebx             ; point to next character 
        cmp     byte ptr es:[ebx],cr
        je      argc3           ; exit if carriage return
        cmp     byte ptr es:[ebx],blank
        je      argc1           ; outside argument if ASCII blank
        cmp     byte ptr es:[ebx],tab   
        je      argc1           ; outside argument if ASCII tab

                                ; not blank or tab...
        jecxz   argc2           ; jump if already inside argument

        inc     eax             ; else found argument, count it
        not     ecx             ; set flag = inside argument
        jmp     argc2           ; and look at next character

argc3:  pop     es              ; restore registers
        pop     ecx
        pop     ebx
        ret                     ; return EAX = argument count

argc    endp

_TEXT   ends

        end
