
        title   ARGV --- get address of command line argument
        page    55,132
        .386

; ARGV.ASM:     Return address and length of specified 
;               command line argument or fully qualified 
;               program name.  Treats blanks and tabs 
;               as whitespace.
;
; 80386 version for Phar Lap DOS|Extender
; Copyright (C) 1989 Ziff Communications Co.
; PC Magazine * Ray Duncan
; 
; Call with:    EAX    = argument number (0 based)
;
; Returns:      ES:EBX = argument address
;               EAX    = argument length (0=no argument)
;
; Uses:         nothing (other registers preserved)
;
; Note: if called with AX=0 (argv[0]), returns ES:EBX 
; pointing to fully qualified program name in environment 
; block and EAX=length.
;
; Warning: uses "magic" Phar Lap hard-wired selectors
; to address environment and PSP.  Code will need adjustment
; for other 80386 protected-mode environments.

cr      equ     0dh             ; ASCII carriage return
tab     equ     09h             ; ASCII tab code
blank   equ     20h             ; ASCII space code

pspsel  equ     24h             ; selector for prog seg prefix
envsel  equ     2ch             ; selector for environment block
cmdtail equ     80h             ; buffer for command tail

_TEXT   segment dword use32 public 'CODE'

        assume  cs:_TEXT

        public  argv
argv    proc    near

        push    ecx             ; save registers
        push    edi

        or      eax,eax         ; is it command tail argument 0?
        jz      argv7           ; yes, jump to get program name

        mov     ebx,pspsel      ; set ES:EBX = command tail
        mov     es,bx
        mov     ebx,cmdtail

        xor     ah,ah           ; initialize argument counter

argv1:  mov     ecx,-1          ; set flag = outside argument

argv2:  inc     ebx             ; point to next character 
        cmp     byte ptr es:[ebx],cr
        je      argv6           ; exit if carriage return
        cmp     byte ptr es:[ebx],blank
        je      argv1           ; outside argument if ASCII blank
        cmp     byte ptr es:[ebx],tab   
        je      argv1           ; outside argument if ASCII tab

                                ; not blank or tab...
        jecxz   argv2           ; jump if already inside argument

        inc     ah              ; else count arguments found
        cmp     ah,al           ; is this the one we're looking for?
        je      argv3           ; yes, go find its length
        not     ecx             ; no, set flag = inside argument
        jmp     argv2           ; and look at next character

argv3:                          ; found desired argument, now
                                ; determine its length...
        mov     eax,ebx         ; save param. starting address 

argv4:  inc     ebx             ; point to next character
        cmp     byte ptr es:[ebx],cr
        je      argv5           ; found end if carriage return
        cmp     byte ptr es:[ebx],blank
        je      argv5           ; found end if ASCII blank
        cmp     byte ptr es:[ebx],tab   
        jne     argv4           ; found end if ASCII tab

argv5:  xchg    ebx,eax         ; set ES:EBX = argument address
        sub     eax,ebx         ; and EAX = argument length
        jmp     argv9           ; return to caller

argv6:  xor     eax,eax         ; set EAX = 0, argument not found
        jmp     argv9           ; return to caller

argv7:                          ; special handling for argv=0
        mov     eax,envsel      ; get environment selector
        mov     es,ax
        xor     edi,edi         ; find the program name by
        xor     al,al           ; first skipping over all the
        mov     ecx,-1          ; environment variables...
        cld

argv8:  repne scasb             ; scan for double null (can't use
        scasb                   ; (SCASW since might be odd addr.)
        jne     argv8           ; loop if it was a single null
        add     edi,2           ; skip count word in environment
        mov     ebx,edi         ; save program name address
        mov     ecx,-1          ; now find its length... 
        repne scasb             ; scan for another null byte
        not     ecx             ; convert ECX to length 
        dec     ecx
        mov     eax,ecx         ; return length in EAX

argv9:                          ; common exit point
        pop     edi             ; restore registers
        pop     ecx
        ret                     ; return to caller

argv    endp

_TEXT   ends

        end


