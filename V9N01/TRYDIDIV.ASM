        title   TRYDIDIV --- Demo of DIDIV87
        page    55,132

; TRYDIDIV.ASM --- interactive demo of DIDIV87
;
; To exit from the program, push <Enter>
; alone at any prompt.
;
; (C) 1989 Ray Duncan, December 1987
;
; Build with:   MASM HTOL;
;               MASM ITOH;
;               MASM HTOQ;
;               MASM DIDIV87;
;               MASM INIT87;
;               MASM TRYDIDIV;
;               LINK TRYDIDIV+ITOH+HTOL+DIDIV87+INIT87;

cr      equ     0dh                     ; ASCII carriage return 
lf      equ     0ah                     ; ASCII line feed
                                        
stdin   equ     0                       ; standard input handle
stdout  equ     1                       ; standard output handle

DGROUP  group   _DATA,STACK

_TEXT   segment word public 'CODE'

        assume  cs:_TEXT,ds:DGROUP

        extrn   HTOQ:near               ; hex ASCII to quad int.
        extrn   HTOL:near               ; hex ASCII to long int.
        extrn   ITOH:near               ; integer to hex ASCII
        extrn   DIDIV:near              ; double-precision signed divide
        extrn   INIT87:near             ; initialize coprocessor

main    proc    near

        mov     ax,DGROUP               ; make our data segment
        mov     ds,ax                   ; addressable...
        mov     es,ax
        
        mov     ax,0fbfh                ; initialize coprocessor
        call    init87                  ; set rounding = truncate
                                        ; set precision = 64
                                        ; mask all exceptions

        jz      main1                   ; jump, coprocessor present

        mov     dx,offset errmsg        ; coprocessor absent,
        mov     cx,err_len              ; display error message
        call    pmsg                    ; and terminate program
        jmp     main3

main1:  mov     dx,offset signon        ; display sign-on message
        mov     cx,so_len
        call    pmsg

main2:  mov     dx,offset prompt1       ; get dividend from user
        mov     cx,p1_len
        call    getnum
        cmp     byte ptr inbuff,cr      ; was anything entered?
        jne     main4                   ; yes, proceed

main3:  mov     ax,4c00h                ; no, exit to MS-DOS
        int     21h

main4:  mov     si,offset inbuff        ; convert dividend to 
        call    htoq                    ; 64-bit value in DX:CX:BX:AX

        push    dx                      ; save dividend on stack
        push    cx              
        push    bx
        push    ax

        mov     dx,offset prompt2       ; get divisor from user
        mov     cx,p2_len
        call    getnum
        cmp     byte ptr inbuff,cr      ; was anything entered?
        je      main3                   ; no, exit to MS-DOS

        mov     si,offset inbuff        ; convert divisor to
        call    htol                    ; 32-bit value in DX:AX

        mov     si,dx                   ; SI:DI = divisor
        mov     di,ax

        pop     ax                      ; get back divisor
        pop     bx                      ; in DX:CX:BX:AX
        pop     cx
        pop     dx

        call    DIDIV                   ; perform signed divide

        push    cx
        push    bx
        push    dx

        mov     bx,offset disp2         ; format lsw of quotient
        call    itoh

        pop     ax                      ; format msw of quotient
        mov     bx,offset disp1
        call    itoh

        pop     ax                      ; format lsw of remainder
        mov     bx,offset disp4
        call    itoh

        pop     ax                      ; format msw of remainder
        mov     bx,offset disp3
        call    itoh

        mov     dx,offset display       ; display everything
        mov     cx,d_len
        call    pmsg

        jmp     main2                   ; do it again...

main    endp


pmsg    proc    near                    ; display message on stdout.
                                        ; call with:
                                        ; DS:DX = message address
                                        ; CX    = message length

        mov     bx,stdout               ; standard output handle
        mov     ah,40h                  ; function 40h = write
        int     21h                     ; transfer to MS-DOS
        ret                             ; return to caller

pmsg    endp


getnum  proc    near                    ; display prompt, get input.
                                        ; call with:
                                        ; DS:DX = prompt address
                                        ; CX    = prompt length

        call    pmsg                    ; display the prompt

        mov     dx,offset inbuff        ; read keyboard entry
        mov     cx,80                   ; from the user...
        mov     bx,stdin                ; standard input handle
        mov     ah,3fh                  ; funct. 3FH = read
        int     21h                     ; transfer to MS-DOS

        ret                             ; return to caller

getnum  endp


_TEXT   ends


_DATA   segment word public 'DATA'

signon  db      cr,lf
        db      'Demo Program for 64-bit by 32-bit Signed Divide'
        db      cr,lf,lf
        db      'Specify the dividend as 1-16 hex digits (64-bit value)'
        db      cr,lf
        db      'followed by the <Enter> key; specify the divisor as 1-8'
        db      cr,lf
        db      'hex digits (32-bit value) followed by the <Enter> key.'
        db      cr,lf
        db      'The 32-bit quotient and 32-bit remainder are displayed.'
        db      cr,lf,lf
        db      'Press <Enter> alone at any prompt to exit.'
        db      cr,lf
so_len  equ     $-signon

prompt1 db      cr,lf
        db      'Enter dividend:    '
p1_len  equ     $-prompt1

prompt2 db      'Enter divisor:     '
p2_len  equ     $-prompt2
                                                   
display db      'The quotient is:   '
disp1   db      'xxxx'
disp2   db      'xxxx'
        db      cr,lf
        db      'The remainder is:  '
disp3   db      'xxxx'
disp4   db      'xxxx'
        db      cr,lf
d_len   equ     $-display

errmsg  db      cr,lf
        db      'No 80x87 coprocessor found!'
        db      cr,lf
err_len equ     $-errmsg

inbuff  db      80 dup (?)              ; keyboard input buffer

_DATA   ends


STACK   segment para stack 'STACK'
        
        db      128 dup (?)

STACK   ends

        end     main

