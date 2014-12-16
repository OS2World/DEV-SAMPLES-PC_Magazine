
        title   HEXASC -- convert binary to hex ASCII
        page    55,132
        .386

; HEXASC.ASM:   Convert binary data to hex ASCII.
; Copyright (C) 1989 Ziff Communications Co.
; PC Magazine * Ray Duncan
;
; This module contains 3 public routines:
; D2ASC:        Convert binary dword (32-bits) to ASCII string
; W2ASC:        Convert binary word  (16-bits) to ASCII string
; B2ASC:        Convert binary byte  (8-bits)  to ASCII string

_TEXT   segment dword use32 public 'CODE'

        assume  cs:_TEXT

; D2ASC:        Convert doubleword (32-bits) to hex ASCII
;
; Call with:    EAX    = data to convert
;               ES:EDI = storage address for ASCII string
;
; Returns:      nothing
;
; Uses:         EAX, ECX, EDI
;
        public  d2asc
d2asc   proc    near

        push    eax                     ; save copy of dword
        shr     eax,16                  ; convert upper word
        call    w2asc
        pop     eax                     ; get back copy of dword
        call    w2asc                   ; convert lower word
        ret

d2asc   endp

; W2ASC:        Convert word (16-bits) to hex ASCII
;
; Call with:    EAX    = data to convert in lower 16-bits
;               ES:EDI = storage address for ASCII string
;
; Returns:      nothing
;
; Uses:         EAX, ECX, EDI
;
        public  w2asc
w2asc   proc    near

        push    eax                     ; save copy of value
        mov     al,ah
        call    b2asc                   ; convert upper byte

        pop     eax                     ; get back copy
        call    b2asc                   ; convert lower byte
        ret

w2asc   endp

; B2ASC:        Convert byte (8-bits) to hex ASCII
;
; Call with:    EAX    = data to convert in lower 8-bits
;               ES:EDI = storage address for ASCII string
;
; Returns:      nothing
;
; Uses:         EAX, ECX, EDI
;
        public  b2asc
b2asc   proc    near

        ror     eax,4
        call    ascii                   ; convert high 4 bits
        stosb                           ; and store ASCII character
        rol     eax,4
        call    ascii                   ; convert low 4 bits
        stosb                           ; and store ASCII character
        ret

b2asc   endp

; ASCII:        Convert nibble (4-bits) to hex ASCII
;
; Call with:    AL    = data to convert in lower 4-bits
; Returns:      AL    = ASCII character
; Uses:         nothing
;
ascii   proc    near
                
        and     al,0fh                  ; mask to range 00H-0FH
        add     al,'0'                  ; offset to chars '0'-'9'
        cmp     al,'9'                  ; is result > '9'?
        jle     ascii2                  ; no, jump
        add     al,'A'-'9'-1            ; adjust for chars 'A'-'F',

ascii2: ret                             ; return AL = ASCII char.

ascii   endp

_TEXT   ends

        end

