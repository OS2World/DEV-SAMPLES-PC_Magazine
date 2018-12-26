        title   TRYTD --- time & date demo
        page    55,132
	.286

; TRYTD.ASM -- Demonstrate use of time and date routines
;              OS/2 version
;
; by Ray Duncan, Copyright (C) 1988 Ziff Davis

cr      equ     0dh             ; ASCII carriage return
lf      equ     0ah             ; ASCII line feed

stdin   equ     0               ; standard input handle
stdout  equ     1               ; standard output handle

        extrn	DosClose:far	; OS/2 API functions
        extrn	DosExit:far 
	extrn	DosOpen:far
	extrn	DosQFileInfo:far
	extrn	DosWrite:far

DGROUP  group   _DATA

_DATA   segment word public 'DATA'

finfo	label	byte		; receives file info
cdate	dw	?		; date of creation
ctime	dw	?	        ; time of creation
adate	dw	?	        ; date of last access
atime	dw	?	        ; time of last access
wdate	dw	?       	; date of last write
wtime	dw	?	        ; time of last write
fsize	dd	?	        ; file size
falloc	dd	?	        ; file allocation
fattr	dw	?	        ; file attribute
fi_len	equ	$-finfo		; length of info buffer

msg1    db      cr,lf                           
        db      'The current time and date are: '
msg1a   db      12 dup (' ')    ; time formatted here
msg1b   db      8 dup  (' ')    ; date formatted here
        db      cr,lf,lf
        db      'The TRYTD.EXE file time and date are: '
msg1c   db      12 dup (' ')    ; time formatted here
msg1d   db      8 dup  (' ')    ; date formatted here
        db      cr,lf
msg1_len equ $-msg1

msg2    db      cr,lf
        db      'Can''t open TRYTD.EXE'
        db      cr,lf
msg2_len equ $-msg2

fname   db      'TRYTD.EXE',0   ; name of this file
fhandle dw      0               ; handle for this file
faction	dw	0		; receives DosOpen action

wlen	dw	?		; receives actual number
				; of bytes written

_DATA   ends


_TEXT   segment word public 'CODE'

        assume  cs:_TEXT,ds:DGROUP

        extrn   systcvt:near    ; format system time
        extrn   sysdcvt:near    ; format system date
        extrn   dirtcvt:near    ; format directory time
        extrn   dirdcvt:near    ; format directory date

main    proc    near
                                
                                ; format system time...
        mov     si,offset msg1a ; buffer address
        mov     bx,11           ; buffer length (max 11)
        call    systcvt

                                ; format system date
        mov     si,offset msg1b ; buffer address
        mov     bx,8            ; buffer length (max 8)
        call    sysdcvt

				; open TRYTD.EXE file...
        push	ds		; address of filename
        push	offset DGROUP:fname
        push	ds		; receives file handle
        push	offset DGROUP:fhandle
        push	ds		; receives DosOpen action
        push	offset DGROUP:faction
        push	0		; initial allocation (N/A)
        push	0
        push	0		; file attribute (N/A)
        push	1		; open if exists, do
        			; not create file
        push	40h		; deny none, read-only
        push	0		; DWORD reserved
        push	0
        call	DosOpen		; transfer to OS/2
	or	ax,ax		; did open succeed?
        jnz	main1		; jump if open failed

				; get file date/time...
	push	fhandle		; file handle
        push	1		; info level (always 1)
        push	ds	        ; receives file info
        push	offset DGROUP:finfo
	push	fi_len		; length of buffer
        call	DosQFileInfo	; transfer to OS/2

        mov	ax,wtime	; format file time
        mov     bx,11           ; buffer length
        mov     si,offset msg1c ; buffer address
        call    dirtcvt

	mov	ax,wdate	; format file date
        mov     bx,8            ; buffer length
        mov     si,offset msg1d ; buffer address
        call    dirdcvt

				; now close file...
	push	fhandle		; file handle
	call	DosClose	; transfer to OS/2

                                ; display formatted
                                ; date and time...
	push	stdout		; standard output handle
        push	ds		; address of message
        push	offset DGROUP:msg1
        push	msg1_len	; length of message
        push	ds	        ; receives write count
        push	offset DGROUP:wlen
	call	DosWrite	; transfer to OS/2

				; final exit to OS/2
        push	1		; terminate all threads
        push	0		; return code = 0 (success)
        call	DosExit		; transfer to OS/2

main1:  			; open failed, display
				; "Can't open TRYTD.EXE"
	push	stdout		; standard output handle
        push	ds		; address of message
        push	offset DGROUP:msg2
        push	msg2_len	; length of message
        push	ds	        ; receives write count
        push	offset DGROUP:wlen
	call	DosWrite	; transfer to OS/2

				; final exit to OS/2
        push	1		; terminate all threads
        push	1		; return code = 1 (error)
        call	DosExit	        ; transfer to OS/2
			        
main    endp

_TEXT   ends

        end     main		; defines entry point

