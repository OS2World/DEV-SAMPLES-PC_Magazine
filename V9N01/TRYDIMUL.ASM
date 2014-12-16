        title   TRYDIMUL --- Demo of DIMUL87
        page    55,132

; TRYDIMUL.ASM --- an interactive demo of DIMUL87
;
; To exit from the program, push <Enter>
; alone at the "Enter a number" prompt.
;
; (C) 1989 Ray Duncan, December 1987
;
; Build with:   MASM HTOL;
;               MASM ITOH;
;               MASM DIMUL87;
;               MASM INIT87;
;               MASM TRYDIMUL;
;               LINK TRYDIMUL+ITOH+HTOL+DIMUL87+INIT87;

cr      equ     0dh                     ; ASCII carriage return
lf      equ     0ah                     ; ASCII line feed

stdin   equ     0                       ; standard input handle
stdout  equ     1                       ; standard output handle

DGROUP  group   _DATA,STACK

_TEXT   segment word public 'CODE'

        assume  cs:_TEXT,ds:DGROUP

        extrn   HTOL:near               ; hex ASCII to long (32-bit) int
        extrn   ITOH:near               ; 16-bit integer to hex ASCII
        extrn   DIMUL:near              ; double-precision signed multiply
        extrn   INIT87:near             ; initialize numeric coprocessor

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

main2:  mov     dx,offset prompt1       ; get argument 1 from user
        mov     cx,p1_len
        call    getnum
        cmp     byte ptr inbuff,cr      ; was anything entered?
        jne     main4                   ; yes, proceed

main3:  mov     ax,4c00h                ; no, exit to MS-DOS
        int     21h

main4:  push    ax                      ; save argument 1
        push    dx

        mov     dx,offset prompt2       ; get argument 2 from user
        mov     cx,p2_len
        call    getnum
        cmp     byte ptr inbuff,cr      ; was anything entered?
        je      main3                   ; no, exit to MS-DOS

        pop     cx                      ; retrieve argument 1
        pop     bx

        call    DIMUL                   ; perform signed multiply

        push    dx                      ; save most of product
        push    cx
        push    bx

        mov     bx,offset disp4         ; format lsw of result
        call    itoh

        pop     ax                      ; format 2sw of result
        mov     bx,offset disp3
        call    itoh

        pop     ax                      ; format 3sw of result
        mov     bx,offset disp2
        call    itoh

        pop     ax                      ; format msw of result
        mov     bx,offset disp1
        call    itoh

        mov     dx,offset display       ; display the result
        mov     cx,d_len
        call    pmsg

        jmp     main2                   ; do it again...

main    endp


pmsg    proc    near                    ; display message on stdout
                                        ; call with 
                                        ; DS:DX = message address
                                        ; CX    = message length

        mov     bx,stdout               ; standard output handle
        mov     ah,40h                  ; function 40h = write
        int     21h                     ; transfer to MS-DOS
        ret                             ; return to caller

pmsg    endp


getnum  proc    near                    ; display prompt, get input,
                                        ; and convert to binary.
                                        ; call with:
                                        ; DS:DX = prompt address
                                        ; CX    = prompt length
                                        ; returns:
                                        ; DX:AX = value entered

        call    pmsg                    ; display the prompt

        mov     dx,offset inbuff        ; read keyboard entry
        mov     cx,80                   ; from the user...
        mov     bx,stdin                ; standard input handle
        mov     ah,3fh                  ; funct. 3FH = read
        int     21h                     ; transfer to MS-DOS

        mov     si,offset inbuff        ; convert convert user's 
        call    htol                    ; input to binary in DX:AX

        ret                             ; return to caller

getnum  endp


_TEXT   ends


_DATA   segment word public 'DATA'

signon  db      cr,lf
        db      'Demo Program for 32-bit by 32-bit Signed Multiply'
        db      cr,lf,lf
        db      'Specify arguments as hex values of 1-8 digits'
        db      cr,lf
        db      'followed by the <Enter> key.  The 64-bit product'
        db      cr,lf
        db      'is displayed.'
        db      cr,lf,lf
        db      'Press <Enter> alone at any prompt to exit.'
        db      cr,lf

so_len  equ     $-signon

prompt1 db      cr,lf
        db      'Enter argument 1:  '
p1_len  equ     $-prompt1

prompt2 db      'Enter argument 2:  '
p2_len  equ     $-prompt2
                                                   
display db      'The result is:     '
disp1   db      'xxxx'
disp2   db      'xxxx'
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

