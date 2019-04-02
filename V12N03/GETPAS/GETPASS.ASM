;==========================================================================
; GETPASS.ASM - A routine to as for a password
;==========================================================================
code	segment
		assume	cs:code
		org	100h
main:		jmp	main_1
current_pass	db	"PC Magazine",0
promptmsg	db	"Enter Password:",13,10,"$"
rightmsg	db	"Correct password!",13,10,"$"
wrongmsg	db	"Incorrect password!",13,10,"$"
main_1:
		cld					;Set string dir up
		mov	ah,9
		mov	dx,offset promptmsg
		int	21h
		add	sp,4				;Clean up stack.
		push	cs
		mov	ax,offset current_pass
		push	ax
		call	GetPassword
		mov	dx,offset rightmsg
		or	ax,ax
		je	main_2
		mov	dx,offset wrongmsg
main_2:
		push	ax				;Save return code
		mov	ah,9				;DOS print string
		int	21h
		pop	ax
		mov	ah,4ch				;DOS Terminate
		int	21h
;-------------------------------------------------------------------------
; GetPassword - Read a password from the user and compare to current PW.
; Entry: Long pointer to current ASCIIZ password on stack.
; Exit:  AX = 0 if correct password entered.
; Parameters must be removed from the stack by the calling procedure
;-------------------------------------------------------------------------
GetPassword	proc	near
		assume	cs:code
		push	bp
		mov	bp,sp				;Create stack frame
		push	bx				;Save registers.
		push	dx
		push	di
		push	es
		mov	di,ss:[bp+6]			;Get ptr to password
		mov	es,di
		mov	di,ss:[bp+4]
		xor	bx,bx				;Clear PW good flag
GetPW_1:
		mov	ah,7				;DOS Console I/O
		mov	dl,-1
		int	21h
		or	al,al				;See if extended key
		jne	GetPW_2
		
		mov	ah,7				;Get extended key, ignore,
		int	21h				;  and replace with 
		mov	al,1				;  1 value.
GetPW_2:
		cmp	al,13				;See if return
		je	GetPW_3
		sub	al,es:[di]			;Compare characters
		or	bl,al				;OR into pass flag
		cmp	byte ptr es:[di],0		;See if at end of PW
		je	GetPW_1
		inc	di				;No, inc pointer
		jmp	short GetPW_1
GetPW_3:		
		or	bl,es:[di]			;OR Terminating zero.
		mov	ax,bx				;Copy pass flag
		pop	es
		pop	di
		pop	dx
		pop	bx
		mov	sp,bp
		pop	bp
		ret
GetPassword	endp
code		ends
end		main
