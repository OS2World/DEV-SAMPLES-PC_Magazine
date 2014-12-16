Title	Program to display network node number (NETNUM.com)

comment @
	This will send a message to the standard output device
		indicating the physical and logical node
		numbers of a computer on a Novell-compatible
		network

	 Novell ELS networks return a physical address of 2,
		regardless of the card settings @

doscall macro	the_fcn
	mov	ah, the_fcn
	int	21h
	endm

std_exit	equ	0
print_str	equ	9
exit_with_code	equ	4ch

cr	equ	13
lf	equ	10
dos_prt_term	equ	'$'

;	Network Functions
net_log_num	equ	0dch
net_phys_num	equ	0eeh


cseg	segment 'code'
	org	100h
	assume	cs:cseg, ds:cseg

netnum	proc	near
begin:	jmp	skip_dat

;..........................................
;	Error message stuff
err_code	dw	no_err
no_err	equ	0
not_on_net	equ	no_err + 1

no_err_msg	db	'This message should NOT ever be displayed.'
	db	cr, lf, dos_prt_term

no_net_msg	db	'This computer is not on a '
	db	'Novell-compatible network.'
	db	cr, lf, dos_prt_term

err_msg_addr	dw	offset no_err_msg
	dw	offset no_net_msg
;..........................................

exit_code	db	0	;ERRORLEVEL on exit, 0 if error, lower
			; byte of physical address if no error

out_msg db	'The logical network address is: '
log_num db	2 dup (?)
	db	cr, lf
	db	'The physical network address is: '
phys_num	db	12 dup (?)
	db	'h', cr, lf, dos_prt_term

skip_dat:
	call	get_log_num
	cmp	err_code, no_err
	je	no_err1
	call	disp_err_msg
	jmp	exit

no_err1:
	call	get_phys_num
	call	print_msg

exit:
	mov	al, exit_code
	doscall exit_with_code
netnum	endp

comment @
	Procedure to get logical network node number
	On Entry:
		Nothing
	On Exit:
		DS:ERR_CODE will be changed if it appears that
			the computer is not on a network
			(node number = 255)
		Number will be placed in DS:LOG_NUM
@
get_log_num	proc	near
	push	cx
	push	ax

	mov	cx, 'ff'		;Will allow error check
	doscall net_log_num
	cmp	cx, 'ff'
	jne	gln_ok

;	Looks like this is not on a network.  Signal that and return
	mov	err_code, not_on_net
	jmp	gln_exit

gln_ok:
	mov	log_num, cl
	mov	log_num + 1, ch

gln_exit:
	pop	ax
	pop	cx
	ret
get_log_num	endp


;-------------------------------------------------
comment @
	Procedure to get physical network node number
	On Entry:
		Nothing
	On Exit:
		Number (12 hex digits) will be placed in DS:PHYS_NUM
			and lower 8 bits will be placed in
			EXIT_CODE
@
get_phys_num	proc	near
	push	ax
	push	bx
	push	cx

;	Zero registers first
	mov	ax, 0
	mov	bx, ax
	mov	cx, ax

	doscall net_phys_num
	mov	exit_code, al	;Save for ERRORLEVEL
	push	ax

	mov	ax, cx
	mov	si, offset phys_num
	call	word_to_chars

	mov	ax, bx
	add	si, 4
	call	word_to_chars

	pop	ax
	add	si, 4
	call	word_to_chars

	pop	cx
	pop	bx
	pop	ax
	ret
get_phys_num	endp


;----------------------------------------------
comment @
	Procedure to print the output message
	On Entry:
		Nothing
	On Exit:
		The message at DS:OUT_MSG will be sent to
			the standard output device
@
print_msg	proc	near
	mov	dx, offset out_msg
	doscall print_str
	ret
print_msg	endp

;--------------------------------------------------
comment @
	Procedure to print error message
	On Entry:
		DS:ERR_CODE holds the # of the error message
		DS:ERR_MSG_ADDR[ERR_CODE * 2] holds the address
			 of the message

	On Exit:
		The message will be sent to standard output
@
disp_err_msg	proc	near
	push	bx
	push	dx

	mov	bx, err_code
	shl	bx, 1		;Point to word offset in table
	mov	dx, err_msg_addr[bx]	;Get offset of message
	doscall print_str		;Display it

	pop	dx
	pop	bx

	ret
disp_err_msg	endp
;...................................................
comment @
	Procedure to convert AX to a string of 4 hex characters
		in [SI]
@

word_to_chars	proc	near

	push	bx		;Save used registers
	push	si

;	Do higher byte first
	mov	bx, ax		;Save the word
	mov	al, ah
	call	byte_to_chars

;	Do lower byte
	mov	al, bl	;Retrieve lower byte
	inc	si	;Point at correct chars
	inc	si
	call	byte_to_chars

	pop	si	;Restore used registers
	pop	bx
	ret
word_to_chars	endp

comment @
	Procedure to convert AL to a string of 2 hex characters
		in [SI]
@

byte_to_chars	proc	near

	push	bx		;Save used registers
	push	cx

;	Do higher nibble first
	mov	bl, al		;Save the word
	mov	cl, 4
	shr	al, cl		;Move high nibble to low nibble
	call	nbl_2_char		;Do the conversion
	mov	[si], al		;Save the result to be printed

;	Lower nibble
	mov	al, bl
	call	nbl_2_char
	mov	[si + 1], al

	pop	cx	;Restore used registers
	pop	bx
	ret
byte_to_chars	endp

;	Procedure to convert nibble to character
;	On Entry:
;		AL (lower 4 bits) is nibble to convert
;	On Exit:
;		AL contains character ("0" to "F")

xlat_str	db	'0123456789ABCDEF'

nbl_2_char	proc	near
	push	bx
	and	al, 0fh ;Zero out upper nibble
	mov	bx, offset xlat_str
	xlat
	pop	bx
	ret
nbl_2_char	endp

cseg	ends
	end	begin
