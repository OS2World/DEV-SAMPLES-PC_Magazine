		page	66,132
;============================================================================
; ALIAS.COM adds a command line stack, a command line editor, and
; an alias function to COMMAND.COM.  Syntax is:
;
;	ALIAS [alias [command]] [/F filename] [/S nn] [/U]
;             [/B] [/E] [/D] [/L] [/U] [/*] [//]
;
; where /B = Set size of buffer for future alias commands
;       /D = Disable alias translation
;       /E = Enable alias translation
;       /F = Filename of file with list of commands
;       /L = List aliases currently in list
;       /M = Set minimum command length to save
;       /S = Size of command line stack where "nn" is the number of commands
;            to save
;       /U = Uninstall the program
;       /* or // = Comment. Ignore remainder of the line.
;
;
; Revision History:
;
; 	Version 1.0	Initial Release		PC Magazine Vol 8 Num 22
;
;============================================================================

		code	segment
		assume	cs:code

		org	2ch
env_segment	dw	?			;Word containing the segment
						;  of the program's env. block.
		org	80h
command_tail	db	?			;Offset of the command tail.

		org	100h

main:		jmp	initialize
program		db	13,10,"ALIAS 1.0 "
copyright	db	"(c) 1989 Ziff Communications Co.",10,13
authors		db	"PC Magazine ",254," Doug Boling and Jeff Prosise"
		db	10,13,"$",1Ah

cmdcom_psp	dw	0			;Segment of COMMAND.COM PSP
master_env	dw	0			;Segment of master environment

cef_pointer	dd	?			;Pointer to critical err flag
dos_version	dw	0			;DOS Version number

chk_alias	db	1			;Alias enable flag.
aliaslist_ptr	dd	?                 	;Pointer to alias list.
aliaslist_size	dw	0f600h			;Pointer to end of list seg
work_buff_ptr	dw	?			;Pointer to alias working buff

cmdstack_base	dw	?
cmdstack_size	dw	16			;Size of command stack.
minlength	db	1			;Minimum len of cmd to stack

mystack_ptr	dw	offset end_of_resident + 512 ;Ptr to internal stack
saved_ss	dw	?
saved_sp	dw	?
int21h		dd	-1			;Int 21 vector (DOS)
int2fh		dd	-1			;Int 2f vector (DOS MULTIPLEX)

multiplex_id	db	0dbh			;Program ID for multiplex int

points		dw	?			;Scan lines per character
columns		db	?			;Number of screen columns
cursor_mode	dw	?			;Cursor mode
bufferptr	db	?			;Input buffer pointer
next_ptr	dw	0			;Address where next command
						;  will be stored
cmd_ptr		dw	0			;Address of current command
						;  in command stack
insert_flag	db	0			;0 = insert off, 1 = on
exkeys		db	71,72,75,77,79,80	;Extended keycode list
		db	82,83,115,116,117
exkeys_end	=	$

ex_entry	dw	offset ctrl_end		;Jump table for extended
		dw	offset ctrl_right	;  keycodes
		dw	offset ctrl_left
		dw	offset delete
		dw	offset toggle_ins
		dw	offset next_cmd
		dw	offset eol
		dw	offset move_right
		dw	offset move_left
		dw	offset prev_cmd
		dw	offset home

;============================================================================
; DOSINT processes calls to interrupt 21h
;============================================================================
dosint		proc	far
		assume	cs:code,ds:nothing,es:nothing
 		cmp	ah,0ah			;Check for char input
 		je	dosint_1    		;If so, continue
goto_dos:
		jmp	cs:[int21h]             ;else pass the call to DOS
;
;Compare the active PSP with COMMAND.COM PSP.
;
dosint_1:
		push	ax			;Save registers
		push	bx
		mov	ah,51h			;Get active PSP segment
		cmp	word ptr cs:[dos_version],310h
		jb	early_dos
		pushf
		call	cs:[int21h]
		jmp	short chkpsp1
early_dos:
		push	es			;If before DOS 3.1, set
		les	bx,cs:[cef_pointer]	;  critical error flag to
		inc	byte ptr es:[bx]	;  force DOS to use the aux
		pushf                           ;  stack.
		call	cs:[int21h]		;Get active PSP segment
		mov	ax,bx
		les	bx,cs:[cef_pointer]	;Reset critical error flag
		dec	byte ptr es:[bx]
		mov	bx,ax
		pop	es
chkpsp1:
		cmp	bx,cs:[cmdcom_psp]
		je	dosint_2
		pop	bx			;Else, cleanup and goto DOS
		pop	ax
		jmp	short goto_dos
dosint_2:
		cld				;Set direction flag
		mov	cs:[saved_ss],ss	;Save SS:SP
		mov	cs:[saved_sp],sp
		cli
		push	cs                      ;Move to internal stack
		pop	ss
		mov	sp,cs:[mystack_ptr]
		sti
		push	bp                      ;Save remaining registers.
		mov	bp,sp			;Set up stack access
		push	cx
		push	dx
		push	di
		push	si
		push	ds
		push	es
;
;The call is from COMMAND.COM. Invoke line editor.
;
		push	dx
		call	cmd_input
		pop	dx
		cmp	cs:[cmdstack_size],0
		je	dosint_3
		call	cmd_record
;
;Check for alias before returning to COMMAND.COM
;
dosint_3:
		cmp	cs:[chk_alias],0     	;See if alias translation
		je	dosint_exit  		;  is enabled.
		mov	si,[bp-4]		;Get pointer to input buffer
		inc     si
		xor	cx,cx
		or 	cl,ds:[si]		;Get length of buffer
		je	dosint_exit		;If buffer empty, exit.
		inc	si			;Point to 1st char in buffer
		mov	ax,cs
		mov	es,ax			;Set ES to installed code.
		call	searchalias		;See if an alias is found.
		jc	dosint_exit		;No, exit.
;
;If alias found, copy it from alias list to internal buffer.
;
		mov 	si,di			;Load SI with alias pointer
		mov	ax,es
		mov	ds,ax			;Point DS to alias list seg
		xor	cx,cx
		mov	cl,ds:[si+3]		;Get size of alias
		call	getalias		;Get alias from list
;
;Append remainder of command line to alias if no cmd line parameters were used.
;
		or	dx,dx			;See if any command line
		jne	dosint_6		;  parameters were used.
		push	si			;Save pointer to buffer.
		push	ds
		mov	di,si
		add	di,cx			;Point DI to end of alias
		mov	dx,cx			;Save length of alias
		mov	si,[bp-4]		;Point DS:SI to command.com
		mov	ds,[bp-10]		;  data buffer.
		xor	cx,cx
		inc	si
		mov	cl,[si]			;Get length of command line.
		cmp	ah,cl			;See if enough space in
		ja	dosint_4		;  internal buffer. If not
		mov	cl,ah			;  copy only until buff full.
dosint_4:
		inc	si
		mov	bl,1 			;Skip past alias.
		call	scan4char
		jc	dosint_5
		dec	si			;Back up 1 char
		inc	cx
		add	dx,cx			;Add length of command line.
		rep	movsb			;Copy command line
dosint_5:
		mov	cx,dx			;Restore length of command
		pop	ds			;Restore pointer
		pop	si
;
;Copy alias from internal buffer to COMMAND.COM data buffer.
;
dosint_6:
		mov	di,[bp-4]		;Point ES:DI to command.com
		mov	es,[bp-10]		;  data buffer.
		mov	al,es:[di]		;Get size of data buffer
		dec	al			;If alias longer than buffer,
		cmp	al,cl			;  copy only the enough
		ja 	dosint_7		;  characters to fill the
		xor	cx,cx			;  buffer.
		mov     cl,al
dosint_7:
		inc	di			;Move DI past length bytes
		mov	es:[di],cl		;Save length of command
		inc	di
		rep	movsb			;Copy alias.
		mov	byte ptr es:[di],13     ;Append carriage return
dosint_exit:
		mov	cx,cs:[cursor_mode]	;Set default cursor
		mov	ah,1
		int	10h
		pop	es
		pop	ds
		pop	si
		pop	di
		pop	dx
		pop	cx
		pop	bp
        	cli
		mov	ss,cs:[saved_ss]	;Restore stack pointer
		mov	sp,cs:[saved_sp]
		pop	bx
		pop	ax
		iret				;Return to COMMAND.COM
dosint		endp

;-----------------------------------------------------------------------------
; GETALIAS Copies an alias from the alias list while substituting any
;          environment variables and command line parameters.
; Entry:  DS:SI - pointer to alias
; Exit:   DS:SI - pointer to buffer containing translated alias.
;            AH - free space in buffer
;            CX - length of the alias
;-----------------------------------------------------------------------------
getalias	proc	near
		mov	di,work_buff_ptr	;Point DI to internal buffer
		xor	ax,ax       		;Point to command by adding
		mov	al,ds:[si+2]		;  the size of the alias to
		add	si,ax       		;  pointer to the entry.
		add	si,4			;Move past list data.
		mov	ah,126			;AH contains max size of buff
		xor	dx,dx			;Clear flag for line params
alias_1:
		lodsb				;Get byte from alias
		cmp	al,"%"			;See if special character
		je 	alias_3			;Yes, process special char.
alias_2:
		stosb				;Store byte from alias
		dec	ah			;Dec buffer size counter
		jz	alias_6			;If internal buffer full, done
		loop	alias_1
		jmp	short alias_6		;If at end of alias, done
;
;A percent sign has been found indicating a 'soft' parameter.
;
alias_3:
		mov	al,ds:[si]		;Get character after %
		cmp	al,"%"			;If double %, include in one
		je	alias_4			;  % in alias.
                mov	bh,al      		;Copy and check to see if
		sub	bh,"0"			;  the next char is a number.
		jb	alias_5 		;  If so, assume a line
		cmp	bh,9                    ;  parameter.
		ja	alias_5
 		call	sublineparam		;Substitute a line paramter
		inc	dx
alias_4:
		inc 	si			;Move SI past number or
		dec	cx			;  trailing % sign.
		loop	alias_1
		jmp	short alias_6		;If at end of alias, done
alias_5:
 		call	subenvvar		;Substitute an environment var
		loop	alias_1
alias_6:
		mov	si,work_buff_ptr	;Point SI to internal buffer
		mov	cx,di			;Compute size of completed
		sub	cx,si                 	;  alias.
		ret
getalias	endp

;-----------------------------------------------------------------------------
; SUBLINEPARAM substitutes a parameter from the command line into the alias.
; Entry:  DS:SI - pointer to alias
;         ES:DI - pointer to buffer to copy the line parameter
;            AH - remaining space in the internal buffer
;            BH - binary number of the line parameter
;            CX - length of the alias
; Exit:   ES:DI - pointer to byte after the parameter in the buffer
;         DS:SI - pointer to the character after the line parameter number
;            CX - remaining length of the alias
;-----------------------------------------------------------------------------
sublineparam	proc	near
		push	cx
		push	si
		push	ds
		mov	si,[bp-4]		;Get pointer to command.com
		mov	ds,[bp-10]		;  data buffer.
		xor	cx,cx
		mov	cl,ds:[si+1]		;Get number of chars in buffer.
		inc	si			;Point to the first byte of
		inc	si			;  data.
sublineparam_1:
		or	bh,bh			;Check count of param to find.
		jz	sublineparam_2
		mov	bl,1
		call    scan4char		;Find next space
		jc	sublineparam_exit
		dec	bl
		call	scan4char		;Find next word
		jc	sublineparam_exit
		dec	bh			;Dec parameter count
		jne	sublineparam_1		;If not done, loop back.
		dec	si			;Backup to 1st char in word.
sublineparam_2:
		lodsb				;Get character from parameter
		cmp	al," "			;If space, parameter done
		jbe	sublineparam_exit
		stosb
		dec	ah			;Dec buffer size counter
		jnz	sublineparam_2
sublineparam_exit:
		pop	ds
		pop	si
		pop	cx
		ret
sublineparam	endp

;-----------------------------------------------------------------------------
; SUBENVVAR substitutes an environment variable into alias.
; Entry:  DS:SI - pointer to variable to substitute
;         ES:DI - pointer to buffer to copy the contents of the variable
;            AH - remaining space in internal buffer
;            CX - length of alias string
; Exit:   DS:SI - pointer to the byte after the variable name
;         ES:DI - pointer to the byte after the variable contents
;            CF - set if variable not found
;-----------------------------------------------------------------------------
subenvvar  	proc	near
		push	dx
		push	ds
		push	es
;
;Compute the length of the variable name.
;
		mov	bx,di	                ;Save pointer to internal buff
		mov	di,si                   ;Compute the length of the
		mov  	dx,cx                   ;  environment variable by
		mov	al,"%"                  ;  searching for the trailing
		repne	scasb                   ;  % sign.
		sub	dx,cx			;Compute length of variable.
		dec	dx			;Subtract % byte fron length.
		push	di			;Save ptr to end of env var.
;
;Search the Master Environment block for the variable pointed to by DS:SI
;
		mov	es,cs:[master_env]	;Get segment of master env blk
		xor	di,di			;Point ES:DI to environment.
		push	cx			;Save alias size.
		push	bx			;Save ptr to internal buffer
		mov 	bx,si			;Save pointer to var name
subenvvar_1:
		mov	si,bx			;Get back ptr to var name.
		mov	cx,dx			;Compare env var to var in
		repe	cmpsb                   ;  alias.
		je	subenvvar_2		;Variable found, exit loop
		xor	al,al			;Find next environment var.
		mov	cx,-1  			;Scan the entire segment.
		repne	scasb
		cmp	byte ptr es:[di],0	;If double zero, end of env
		jne	subenvvar_1		;  block. else, loop back.
		pop	di                      ;Restore DI and exit
		jmp	short subenvvar_exit
;
;Environment variable found. Substitute into alias.
;
subenvvar_2:
		mov	si,es			;DS:SI points to env string
		mov	ds,si			;ES:DI points to internal buff
		mov 	si,cs
		mov	es,si
		mov	si,di			;Copy pointer to var contents.
		pop	di   			;Restore ptr to internal buff
subenvvar_3:
		lodsb				;Move environment pointer past
		cmp	al,"="			;  the equals sign.
		jne	subenvvar_3
subenvvar_4:
		lodsb				;Move pointer to first
		cmp	al," "			;  non-space character.
		jb	subenvvar_4
subenvvar_5:
		or	al,al			;See if at the end of variable
		je	subenvvar_exit
		stosb				;Save character in command
		lodsb				;Get next character
		dec	ah			;Dec buffer size count.
		jne	subenvvar_5		;If buffer not full, continue
subenvvar_exit:
		pop	cx			;Restore alias length
		pop	si			;Restore alias pointer
		pop	es			;Restore segment registers
		pop	ds
		pop	dx
		ret
subenvvar	endp

;-----------------------------------------------------------------------------
; SUBKEY searches the alias list for a key substitution
; Entry:  AL - extended key code
; Exit:   CF - clear if key found, set if not found
;         DX - offset address of matching entry in alias list (if CF = 0)
;         CX - length of matching entry (if CF = 0)
;-----------------------------------------------------------------------------
subkey		proc	near
		push	bx
		push	di
		push	si
		push	ds
		push	es
                xor	ah,ah			;Indicate extended code.
		les	di,cs:[aliaslist_ptr]	;Get pointer to alias list.
subkey_1:
		mov	dx,es:[di]		;Get next entry offset
		cmp	dx,-1			;See if at the end of the list
		je	subkey_notfound
		cmp	es:[di+4],ax		;Check for key code.
		je	subkey_found		;If found, exit loop
subkey_2:
		add	di,dx     		;Else, point to next entry.
		jmp	short subkey_1
;
;Copy alias into internal buffer.
;
subkey_found:
		mov 	si,di			;Load SI with alias pointer
		mov	ax,es
		mov	ds,ax			;Point DS to alias list seg
		xor	cx,cx
		mov	cl,ds:[si+3]		;Get size of alias
		call	getalias		;Get alias from list
		mov	dx,si			;Copy pointer to buffer
		clc				;Set key found flag
subkey_exit:
		pop	es
		pop	ds
		pop	si
		pop	di
		pop	bx
		ret
subkey_notfound:
		stc				;Set key not found flag
		jmp	subkey_exit
subkey		endp

;-----------------------------------------------------------------------------
; SEARCHALIAS searches the alias list for a matching alias.
; Entry:  DS:SI - pointer to alias
;            ES - segment of installed code
;            CX - length input buffer
; Exit:      CF - clear if alias found
;         ES:DI - pointer to matching entry in alias list, if CF is clear
;-----------------------------------------------------------------------------
searchalias	proc	near
		push	bx			;Save registers
		push	cx
		push	si
		xor	bx,bx
searchalias_1:
		lodsb                           ;Compute the length of the
		or 	al,al                   ;  length of the alias by
		je	searchalias_2 	        ;  finding the next space.
		cmp	al," "                  ;Allow zero byte in alias
		jbe	searchalias_3           ;  for function key labels.
searchalias_2:
		inc	bx
 		loop	searchalias_1
searchalias_3:
		pop	si
		les	di,es:[aliaslist_ptr]	;Get pointer to alias list.
		mov	cx,bx			;Get length of alias
searchalias_4:
		mov	bx,es:[di]
		cmp	bx,-1			;See if at the end of the list
		je	searchalias_notfound
		cmp	es:[di+2],cl		;Compare lengths
		jne	searchalias_5
		push	cx			;Save size and starting
		push	di                      ;  pointers.
		push	si
		add	di,4			;Point to start of alias field.
		repe	cmpsb			;Compare alias to input string
		pop	si
		pop	di
		pop	cx
		je	searchalias_6		;If found, exit loop
searchalias_5:
		add	di,bx			;Else, point to next entry.
		jmp	short searchalias_4
searchalias_6:
		clc				;Set alias found flag
searchalias_exit:
		pop	cx
		pop	bx
		ret
searchalias_notfound:
		stc
		jmp	short searchalias_exit
searchalias	endp

;-----------------------------------------------------------------------------
; SCAN4CHAR scans a string to find the first character.
; Entry:  SI - pointer to ASCII string
;         BL - 0 = find next char, 1 = find next space
;         CX - file length
; Exit:   AL - first nonspace character
;         CF - set if carriage return found
;-----------------------------------------------------------------------------
scan4char  	proc near
		assume	ds:nothing,es:nothing
scan4loop:
		jcxz	scan4_eol		;See if at the end of the file.
		lodsb
		dec	cx     			;Decrement file length counter.
		cmp	al,13			;Check for carriage return.
		jne	scan4_1
scan4_eol:
		stc
		jmp	short scan4_exit1
scan4_1:
		or	bl,bl			;Check if searching for space
		jne	scan4_2			;  or character.
		cmp	al," "			;Check for space or other
		jbe	scan4loop		;  'white' characters.
		jmp	short scan4_exit
scan4_2:
		cmp	al," "			;Check for characters.
		ja	scan4loop
scan4_exit:
		clc
scan4_exit1:
 		ret
scan4char	endp

;----------------------------------------------------------------------------
; CMD_INPUT replaces DOS' 0Ah text input function.
;----------------------------------------------------------------------------
cmd_input	proc	near
		push	ds			;Save DS
		xor	ax,ax			;Then zero it
		mov	ds,ax
		mov	ax,ds:[0485h]		;Get number of scan lines
		cmp	ax,cs:[points]		;  per character and branch
		je	cmd1			;  if it hasn't changed

		mov	cs:[points],ax		;Record new number of scan
		mov	ax,ds:[0460h]		;  lines per character and
		mov	cs:[cursor_mode],ax	;  cursor mode
cmd1:
		pop	ds			;Restore DS
		call	set_cursor		;Set cursor mode

		mov	ah,15			;Get video page and columns
		int	10h
		dec	ah			;Calculate max column number
		mov	cs:[columns],ah		;Save it
		mov	ax,ds			;Point ES:DI to buffer
		mov	es,ax
		mov	di,dx
		add	di,2
		mov	si,dx			;Point DS:SI to character count
		inc	si
		mov	byte ptr [si],0		;Zero initial count
		mov	cs:[bufferptr],1	;Set initial index value
		cld				;Clear DF
;
;Wait for a keycode to appear in the keyboard buffer.
;
getkey:		mov	ah,0Bh			;Check buffer for keycode
		int	21h
		or	al,al			;Anything there?
		jne	getchar			;Yes, then go get it
		int	28h			;No, then execute interrupt 28h
		jmp	getkey			;Loop back for another try
;
;Read the keycode and process it if it's not an extended code.
;
getchar:
		mov	ah,8			;Read character from buffer
		int	21h
		or	al,al			;Is it an extended code?
		je	excode			;Yes, then branch

		cmp	al,8			;Backspace key?
		jne	getc1			;No, then branch
		call	backspace		;Rub out a character
		jmp	getkey			;Return to loop
getc1:
		cmp	al,9			;Tab key?
		jne	getc2			;No, then branch
		call	tab			;Tab to next tab boundary
		jmp	getkey			;Return to loop
getc2:
		cmp	al,27			;ESC key?
		jne	getc3			;No, then branch
		call	clear_line		;Yes, then clear input line
		mov	cs:[cmd_ptr],0		;Zero current command pointer
		jmp	getkey
getc3:
		cmp	al,7Fh			;Ctrl-Backspace?
		jne	getc4			;No, then branch
		call	ctrl_bs			;Yes, then delete word
		jmp	getkey
getc4:
		cmp	al,13			;ENTER key?
		je	enter			;Yes, then branch
		call	printchar		;No, then print the character
getc5:
		jmp	getkey
enter:
		call	eol			;Place cursor at end-of-line
		mov	byte ptr es:[di],13	;Insert carriage return code
		mov	ah,2			;Advance to next line
		mov	dl,13
		int	21h
get_exit:
		ret
;
;Process extended keycodes.
;
excode:
		mov	ah,8			;Read extended code
		int	21h

                cmp	al,3Bh			;See if below F1
		jb	excode3
		cmp	al,71h			;See if above Alt-F10
		ja	excode3
                cmp	al,54h			;See if above Shift-F1
		jae	excode1
		cmp	al,44h			;See if above F10
		ja	excode3
excode1:
		call	subkey			;Scan alias list for match
		jc	getkey			;Exit if no match found
		push	cx
		push	dx
		call	clear_line		;Clear command line
		pop	dx
		pop	cx
excode2:
		push	si
		mov	si,dx			;Copy offset address into SI
		mov	al,byte ptr cs:[si]	;Get next character
		pop	si
		cmp	al,13			;Exit and execute command
		je	enter			;  on carriage return
		inc	dx
		push	cx
		push	dx
		call	printchar		;Print it
		pop	dx
		pop	cx
		jc	getc5
		loop	excode2			;Loop until done
		jmp	getkey			;Return to input loop
excode3:
		push	es			;Save buffer address
		push	di
		mov	cx,cs			;Point ES:DI to list of
		mov	es,cx			;  supported keycodes
		mov	di,offset exkeys
		mov	cx,offset exkeys_end - offset exkeys
		repne	scasb			;Scan list
		pop	di			;Clear the stack
		pop	es
		jne	excode4			;Ignore if key not found
		shl	cx,1			;Convert CX to address
		add	cx,offset ex_entry
		push	bx			;Save page number in BH
		mov	bx,cx			;Get entry address from table
		mov	ax,cs:[bx]
		pop	bx			;Restore BH
		call	ax			;Call handling routine
excode4:
		jmp	getkey			;Return to input loop
cmd_input	endp

;------------------------------------------------------------------------------
; PREV_CMD outputs the previous command in the command stack.
;------------------------------------------------------------------------------
prev_cmd	proc	near
		mov	dx,cs:[cmd_ptr]		;Get current stack index
		cmp	dx,cs:[cmdstack_size]	;Exit if at top of command
		je	prev_exit		;  stack
		or	dx,dx			;Branch if not at bottom of
		jnz	prev1			;  command stack
;
;Copy the current contents of the command line to the search buffer.
;
		mov	cl,[si]			;Get count of characters on
		xor	ch,ch			;  command line in CX
		inc	cx
		push	es			;Save registers
		push	di
		push	si
		mov	ax,cs			;Point ES:DI to search text
		mov	es,ax			;  buffer
		mov	di,offset command_tail
		rep	movsb			;Copy command line text
		pop	si			;Restore registers
		pop	di
		pop	es
;
;Search for the previous command and output it.
;
prev1:
		inc	dx			;Increment stack index
		mov	ax,cs:[next_ptr]	;Get stack base index
		sub	ax,dx			;Calculate address of previous
		cmp	ax,0			;  command
		jge	prev2
		add	ax,cs:[cmdstack_size]
prev2:
		mov	cl,7			;Calculate offset address of
		shl	ax,cl			;  the command
		add	ax,cs:[cmdstack_base]
		cmp	byte ptr cs:[command_tail],0	;Output command if there is
		je	prev3			;  no search criterion
		call	check_string		;Compare strings
		jz	prev3			;Output command if the strings
		cmp	dx,cs:[cmdstack_size]	;  match
		jne	prev1
		ret				;Exit if at top of stack
prev3:
		push	si			;Save SI
		mov	si,ax			;Transfer address to SI
		cmp	byte ptr cs:[si],0	;Valid command?
		pop	si			;Restore SI
		je	prev_exit		;No, then ignore keypress
		mov	cs:[cmd_ptr],dx		;Save new command pointer
		call	write_command		;Output the command string
prev_exit:
		ret
prev_cmd	endp

;------------------------------------------------------------------------------
; NEXT_CMD outputs the next command in the command stack.
;------------------------------------------------------------------------------
next_cmd	proc	near
		mov	dx,cs:[cmd_ptr]		;Get current stack index
		or	dx,dx			;Exit if it's zero
		jz	next_exit
next1:
		dec	dx			;Decrement stack index
		mov	cs:[cmd_ptr],dx		;Save command pointer
		or	dx,dx			;Clear line and exit if
		jz	next3			;  the result is zero
		mov	ax,cs:[next_ptr]	;Get stack base index
		sub	ax,dx			;Calculate address of next
		cmp	ax,0			;  command
		jge	next2
		add	ax,cs:[cmdstack_size]
next2:
		mov	cl,7			;Calculate offset address of
		shl	ax,cl			;  command
		add	ax,cs:[cmdstack_base]
		cmp	byte ptr cs:[command_tail],0	;Output command if there is
		je	next4			;  no search criterion
		call	check_string		;Compare strings
		jz	next4			;Output command if the strings
		jmp	next1			;  match
next3:
		call	clear_line
		cmp	byte ptr cs:[command_tail],0
		je	next_exit
		mov	ax,offset command_tail
next4:
		call	write_command		;Output the command string
next_exit:
		ret
next_cmd	endp

;------------------------------------------------------------------------------
; CHECK_STRING compares the string in the search buffer with another string.
; Entry:  AX - string address
; Exit:   ZF - set if strings are equivalent, clear if they are not
;------------------------------------------------------------------------------
check_string	proc	near
		push	ds			;Save registers
		push	si
		push	es
		push	di
		mov	cx,cs			;Point DS and ES to
		mov	ds,cx			;  code segment
		mov	es,cx
		mov	si,offset command_tail	;Point DS:SI to text in
		mov	cl,[si]			;  search buffer
		xor	ch,ch
		inc	si
		mov	di,ax			;Point DI to other string
		inc	di			;
		repe	cmpsb			;Compare strings
		pop	di			;Restore registers
		pop	es
		pop	si
		pop	ds
		ret
check_string	endp

;------------------------------------------------------------------------------
; PRINT_STRING writes an ASCII string to the command line.
; Entry:  DS:SI - string address
;            CX - number of characters
;------------------------------------------------------------------------------
print_string	proc	near
		jcxz	ps_exit			;Exit if no characters
		push	dx
		cld
		mov	ah,2			;Print the character
ps1:
		lodsb				;Get a byte
		mov	dl,al			;Transfer it to DL
		int	21h			;Output character
		loop	ps1			;Loop until done
		pop	dx
ps_exit:
		ret
print_string	endp

;------------------------------------------------------------------------------
; WRITE_COMMAND outputs a command string.
; Entry:  AX - string offset address
; Exit:   AL - character after string
;------------------------------------------------------------------------------
write_command	proc	near
		push	ax			;Save address
		call	clear_line		;Clear input line
		pop	ax			;Retrieve string address
		push	ds			;Save DS and SI
		push	si
		push	cs			;Point DS to string segment
		pop	ds
		mov	si,ax			;Point SI to the string
		mov	cl,[si]			;Get string length
		xor	ch,ch
		mov	byte ptr es:[di-1],cl	;Store string length
		inc	si			;Advance SI to string text
write1:
		mov	ah,2			;Print one character
		mov	dl,[si]
		int	21h
		movsb				;Transfer character to buffer
		inc	cs:[bufferptr]		;Advance pointer
		loop	write1			;Loop until done
		lodsb				;Get first character after string
		pop	si			;Restore registers
		pop	ds
		ret
write_command	endp

;------------------------------------------------------------------------------
; TOGGLE_INS toggles the insert flag.
;------------------------------------------------------------------------------
toggle_ins	proc	near
		xor	cs:[insert_flag],1	;Toggle insert flag
		call	set_cursor		;Set cursor mode
		ret
toggle_ins	endp

;------------------------------------------------------------------------------
; TAB tabs to the next tab boundary.
;------------------------------------------------------------------------------
tab		proc	near
		mov	al,cs:[bufferptr]	;Calculate number of
		dec	al			;  spaces to insert for
		xor	ah,ah			;  soft tab
		mov	bl,8
		div	bl
		mov	cx,8
		sub	cl,ah
tab1:
		push	cx			;Print spaces
		mov	al,32
		call	printchar
		pop	cx
		jc	tab_exit
		loop	tab1
tab_exit:
		ret
tab		endp

;------------------------------------------------------------------------------
; BACKSPACE deletes the character left of the cursor.
;------------------------------------------------------------------------------
backspace	proc	near
		cmp	cs:[bufferptr],1	;At beginning of command line?
		je	bs_exit			;Yes, then ignore it
		mov	cl,[si]			;Get count
		sub	cl,cs:[bufferptr]	;Calculate distance to end-of-line
		inc	cl
		xor	ch,ch
		push	cx			;Save it
		jcxz	bs1			;Branch if at end-of-line
;
;Shift all characters right of the cursor in the buffer one slot left.
;
		push	si			;Save SI and DI
		push	di
		mov	si,di			;Position them for shifts
		dec	di
		rep	movsb			;Shift characters right of cursor
		pop	di			;Restore registers
		pop	si
;
;Display the new string and update input parameters.
;
bs1:
		call	move_left		;Move cursor left
bs2:
		pop	cx			;Retrieve shift count
		push	dx			;Save cursor position
		push	si			;Save SI
		mov	si,di			;Point SI to new part of string
		call	print_string		;Print the new part
		mov	ah,2			;Blank the last character
		mov	dl,32
		int	21h
		pop	si			;Restore registers
		pop	dx			;Restore cursor address
		mov	ah,2			;Reset the cursor
		int	10h
		dec	byte ptr [si]		;Decrement character count
bs_exit:
		ret
backspace	endp

;------------------------------------------------------------------------------
; PRINTCHAR writes a new character to the input buffer and echoes it.
; Entry:  AL - character to print
; Exit:   CF clear if character printed
;         CF set if buffer full
;------------------------------------------------------------------------------
printchar	proc	near
		cmp	cs:[insert_flag],0	;Insert state on?
		jne	print3			;Yes, then branch
;
;Print a character in overstrike mode.
;
		mov	cl,[si]			;Get count
		cmp	cl,cs:[bufferptr]	;End-of-line?
		jae	print2			;No, then branch
		mov	cl,[si-1]		;Get maximum length
		sub	cl,[si]			;Subtract current length
		cmp	cl,1			;Buffer full?
		je	beep			;Yes, then branch
print1:
		inc	byte ptr [si]		;Increment count
print2:
		stosb				;Deposit new character
		mov	ah,2			;Then print it
		mov	dl,al
		int	21h
		inc	cs:[bufferptr]		;Advance buffer pointer
print_exit:
		clc				;Clear CF and exit
		ret
beep:
		mov	ax,0E07h		;Print ASCII 7 thru BIOS
		int	10h
		stc
		ret
;
;Print a character in insert mode.
;
print3:
		mov	cl,[si-1]		;Get maximum length
		sub	cl,[si]			;Subtract current count
		cmp	cl,1			;Buffer full?
		je	beep			;Yes, then branch
		mov	cl,[si]			;Get count
		cmp	cl,cs:[bufferptr]	;End-of-line?
		jb	print1			;Yes, then branch
		sub	cl,cs:[bufferptr]	;Calculate number of shifts
		inc	cl
		xor	ch,ch
		push	cx			;Save shift count
		push	si			;Save SI
		add	di,cx			;Position DI to end-of-line
		mov	si,di			;Position SI just before it
		dec	si
		std				;Set DF for now
		rep	movsb			;Make room for new character
		cld				;Clear DF
		pop	si			;Restore SI
		mov	es:[di],al		;Deposit new character
		mov	ah,3			;Get cursor position
		int	10h
		pop	cx			;Retrieve shift count
		inc	cx			;Increment it
		push	dx			;Save cursor position
		push	si			;Save SI
		mov	si,di			;Point SI to current location
		call	print_string		;Print new part of string
		pop	si			;Restore SI and DX
		pop	dx
		mov	ah,2			;Reset cursor position
		int	10h
		inc	byte ptr [si]		;Add to character count
		call	move_right		;Move cursor right
		jmp	print_exit
printchar	endp

;------------------------------------------------------------------------------
; DELETE deletes the character at the cursor.
;------------------------------------------------------------------------------
delete		proc	near
		mov	cl,[si]			;Get count
		cmp	cl,cs:[bufferptr]	;End-of-line?
		jb	del2			;Yes, then ignore keypress
		sub	cl,cs:[bufferptr]	;Calculate number of shifts
		xor	ch,ch			;Byte to word in CX
		push	cx			;Save shift count
		jcxz	del1			;Branch if no shifts
		push	si			;Save SI and DI
		push	di
		mov	si,di			;Position registers for shift
		inc	si
		rep	movsb			;Shift chars right of cursor
		pop	di			;Restore registers
		pop	si
del1:
		mov	ah,3			;Get cursor position
		int	10h
		jmp	bs2			;Exit thru BACKSPACE routine
del2:
		ret
delete		endp

;------------------------------------------------------------------------------
; CTRL_BS deletes the word at the cursor.
;------------------------------------------------------------------------------
lesschars	dw	?			;Count of chars deleted
shiftcount	dw	?			;Count of chars shifted

ctrl_bs		proc	near
		mov	cl,[si]			;Exit now if there is nothing
		xor	ch,ch			;  on the command line
		or	cx,cx
		jnz	cbs1
cbs_exit:
		ret
cbs1:
		cmp	cs:[bufferptr],1	;Exit if the cursor is at the
		je	cbs3			;  at the end of the command
		cmp	cl,cs:[bufferptr]	;  line or if it is under a
		jb	cbs_exit		;  space; otherwise, move to
		cmp	byte ptr [di],32	;  the beginning of the
		je	cbs_exit		;  current word
		cmp	byte ptr [di-1],32
		je	cbs3
cbs2:
		push	cx			;Save CX
		call	ctrl_left		;Move to start of word
		pop	cx			;Restore CX
cbs3:
		inc	cx			;Calculate max number of
		push	cx			;  characters to search
		mov	dl,cs:[bufferptr]	;  looking for the next
		xor	dh,dh			;  word or end-of-line
		sub	cx,dx
		push	di			;Save DI
cbs4:
		inc	di			;Search until DI addresses
		cmp	byte ptr [di],32	;  either the first character
		je	cbs5			;  in the next word or the
		cmp	byte ptr [di-1],32	;  end of the command line
		je	cbs6
cbs5:
		loop	cbs4
cbs6:
		mov	dx,di			;Save final value of DI
		pop	di			;Restore DI
		pop	cx			;Retrieve count
		mov	cs:[lesschars],dx	;Calculate number of chars to
		sub	cs:[lesschars],di	;  be deleted
		sub	cx,dx			;Then calculate how many chars
		add	cx,si			;  must be shifted
		mov	cs:[shiftcount],cx
		jcxz	cbs7			;Branch if no shift
		push	si			;Save registers
		push	di
		mov	si,dx			;Point DS:SI to next word
		rep	movsb			;Delete current word
		pop	di			;Restore registers
		pop	si
cbs7:
		mov	cx,cs:[lesschars]	;Update character counter
		sub	[si],cl			;  in input buffer
		mov	ah,3			;Save the current cursor
		int	10h			;  position on the stack
		push	dx
		push	si			;Update the text on the
		mov	si,di			;  command line
		mov	cx,cs:[shiftcount]
		call	print_string
		pop	si
		mov	cx,cs:[lesschars]
cbs8:
		mov	ah,2			;Print as many spaces as
		mov	dl,32			;  there were characters
		int	21h			;  deleted
		loop	cbs8
		pop	dx			;Restore cursor position
		mov	ah,2			;  and exit
		int	10h
		ret
ctrl_bs		endp

;------------------------------------------------------------------------------
; CTRL_END deletes command line text from the cursor to the end of the line.
;------------------------------------------------------------------------------
ctrl_end	proc	near
		mov	cl,[si]			;Exit if already at end
		cmp	cl,cs:[bufferptr]	;  of line
		jb	ce_exit
		sub	cl,cs:[bufferptr]	;Calculate number of chars
		xor	ch,ch			;  to be deleted
		inc	cx
		sub	[si],cl			;Update count in input buffer
		push	cx
		mov	ah,3			;Get and save cursor position
		int	10h
		pop	cx
		push	dx
ce1:
		mov	ah,2			;Print as many spaces as
		mov	dl,32			;  there are characters
		int	21h			;  to delete
		loop	ce1
		mov	ah,2			;Reset cursor position and
		pop	dx			;  exit
		int	10h
ce_exit:
		ret
ctrl_end	endp

;------------------------------------------------------------------------------
; MOVE_LEFT moves the cursor one character left.
;------------------------------------------------------------------------------
move_left	proc	near
		cmp	cs:[bufferptr],1	;At beginning of line?
		je	left2			;Yes, then ignore keypress
		mov	ah,3			;Get cursor position
		int	10h
		dec	dl			;Decrement it by 1
		cmp	dl,0FFh
		jne	left1
		mov	dl,cs:[columns]		;Decrement row number by 1
		dec	dh			;  if cursor wraps around
left1:
		mov	ah,2			;Set new position
		int	10h
		dec	di			;Decrement pointers
		dec	cs:[bufferptr]
left2:
		ret
move_left	endp

;------------------------------------------------------------------------------
; MOVE_RIGHT moves the cursor one character right.
;------------------------------------------------------------------------------
move_right	proc	near
		mov	cl,[si]			;Get count
		cmp	cl,cs:[bufferptr]	;End-of-line?
		jb	rt2			;Yes, then ignore keypress
		mov	ah,3			;Get cursor position
		int	10h
		inc	dl			;Increment column number
		cmp	dl,cs:[columns]		;Increment row number if
		jna	rt1			;  cursor wraps around
		xor	dl,dl
		inc	dh
rt1:
		mov	ah,2			;Position cursor
		int	10h
		inc	di			;Advance pointers
		inc	cs:[bufferptr]
rt2:
		ret
move_right	endp

;------------------------------------------------------------------------------
; CTRL_LEFT moves the cursor one word left.
;------------------------------------------------------------------------------
ctrl_left	proc	near
		call	move_left		;Move one character left
		cmp	cs:[bufferptr],1	;Beginning of line?
		je	cl_exit			;Yes, then exit
		cmp	byte ptr es:[di],32	;Loop back if current char
		je	ctrl_left		;  is a space
		cmp	byte ptr es:[di-1],32	;Loop back if char to the
		jne	ctrl_left		;  left is not a space
cl_exit:
		ret
ctrl_left	endp

;------------------------------------------------------------------------------
; CTRL_RIGHT moves the cursor one word right.
;------------------------------------------------------------------------------
ctrl_right	proc	near
		call	move_right		;Move one character right
		mov	cl,[si]			;End-of-line?
		cmp	cl,cs:[bufferptr]	;Yes, then exit
		jb	cr_exit
		cmp	byte ptr es:[di],32	;Loop back if current char
		je	ctrl_right		;  is a space
		cmp	byte ptr es:[di-1],32	;Loop back if char to the
		jne	ctrl_right		;  left is not a space
cr_exit:
		ret
ctrl_right	endp

;------------------------------------------------------------------------------
; HOME relocates the cursor to the beginning of the command line.
;------------------------------------------------------------------------------
home		proc	near
		mov	cl,cs:[bufferptr]	;Get position pointer
		dec	cl			;Calculate distance from start
		xor	ch,ch
		jcxz	home_exit		;Exit if already there
home1:
		push	cx			;Save count
		call	move_left		;Move left one space
		pop	cx			;Retrieve count
		loop	home1			;Loop until done
home_exit:
		ret
home		endp

;------------------------------------------------------------------------------
; EOL advances the cursor to the end of the command line.
;------------------------------------------------------------------------------
eol		proc	near
		mov	cl,[si]			;Get count
		cmp	cl,cs:[bufferptr]	;Already at end?
		jb	eol_exit		;Yes, then exit
		sub	cl,cs:[bufferptr]	;Calculate distance from end
		inc	cl
		xor	ch,ch			;Byte to word in CX
eol1:
		push	cx			;Advance right CX times
		call	move_right
		pop	cx
		loop	eol1
eol_exit:
		ret
eol		endp

;------------------------------------------------------------------------------
; CLEAR_LINE clears the command line.
; Entry:  BH - current video page
;------------------------------------------------------------------------------
clear_line	proc	near
		mov	cl,[si]			;Get count
		xor	ch,ch
		jcxz	cline2			;Exit if no characters
		push	cx			;Save count
		call	home			;Home the cursor
		mov	ah,3			;Get cursor position
		int	10h
		pop	cx			;Restore CX
		push	dx			;Save cursor address
		mov	ah,2			;Print ASCII spaces
		mov	dl,32
cline1:
		int	21h
		loop	cline1
		mov	ah,2			;Home cursor again
		pop	dx
		int	10h
		mov	byte ptr [si],0		;Reset count
cline2:
		ret
clear_line	endp

;------------------------------------------------------------------------------
; CMD_RECORD records the latest command in the command stack.
; Entry:  DS:DX - input buffer address
;------------------------------------------------------------------------------
cmd_record	proc	near
		mov	si,dx			;Point SI to input buffer
		mov	al,[si+1]		;Get length of input string
		cmp	al,cs:[minlength]	;Is the length zero?
		jb	cmd_exit		;Yes, then exit now
		inc	si			;Advance SI to count byte
		push	cs			;Point ES to command stack 
		pop	es			;  segment
		mov	di,cs:[next_ptr]	;Get command stack pointer
		mov	cl,7			;Convert it to offset address
		shl	di,cl
		add	di,cs:[cmdstack_base]
		mov	cl,al			;Transfer string length to CL
		inc	cl			;Increment for count byte
		xor	ch,ch			;Byte to word in CX
		cld				;Clear DF
		rep	movsb			;Copy string to command stack
		inc	cs:[next_ptr]		;Update pointer
		mov	ax,cs:[cmdstack_size]
		cmp	cs:[next_ptr],ax	;Wrap around if necessary
		jne	cmdrec1
		mov	cs:[next_ptr],0
cmdrec1:
		mov	cs:[cmd_ptr],0		;Zero current command pointer
cmd_exit:
		ret
cmd_record	endp

;------------------------------------------------------------------------------
; SET_CURSOR sets the cursor mode based on the state of the insert flag.
;------------------------------------------------------------------------------
set_cursor	proc	near
		cmp	cs:[insert_flag],0	;Test state of insert flag
		je	setc1			;Branch if not set
		mov	cx,cs:[cursor_mode]	;Raise top by 2 scan lines
		sub	ch,2
		jns	setc2			;Exit if it wraps around
		ret
setc1:
		mov	cx,cs:[cursor_mode]	;Set default cursor
setc2:
		mov	ah,1			;Set cursor mode
		int	10h
		ret
set_cursor	endp

;============================================================================
; MUXINT processes calls to interrupt 2Fh
; Entry:  AH - Device ID
; Exit:   AL - 0FFh if AH = Alias device ID. Unchanged otherwise.
;         ES - Code segment if AH = Alias device ID. Unchanged otherwise.
;============================================================================
muxint		proc	far
		assume	cs:code,ds:nothing,es:nothing
 		cmp	ah,cs:[multiplex_id]	;Check for program ID
		je	muxint_1		;Its us, indicate installed.
		jmp	cs:[int2fh]             ;else pass the call on
muxint_1:
		mov	al,-1			;Indicate Alias installed
		push	cs			;ES = installed code segment
		pop	es
		iret
muxint		endp

		even				;Align stack on word boundry
end_of_resident	=	$
;----------------------------------------------------------------------------
; Start of non-resident code.
;----------------------------------------------------------------------------
final_install:
		rep	movsb			;Copy alias list
		mov	di,cmdstack_base	;Initialize command stack
		mov	cx,cmdstack_size	;  area with leading zeroes
		jcxz	tsr			;Branch if size is zero
		xor	al,al
		cld
final_loop:
		stosb
		add	di,127
		loop	final_loop
tsr:
		mov	ax,3100h		;Terminate and stay resident
		int	21h

;----------------------------------------------------------------------------
; Non-resident data.
;----------------------------------------------------------------------------
alrdy_installed	db	0			;Installed flag
other_seg	dw	0			;Segment of installed code
databuff_seg	dw	0			;Segment of data buffer.

alias_buffer	dw	512			;Extra buffer for alias list.
aliaslist_end	dw	0			;Offset of end of the list.
alias_inlist	db	0			;Flag used in alias list append

infomsg1	db	"ALIAS uninstalled$"
infomsg2	db	13,10,9,"Command stack size: $"
infomsg3	db	13,10,9,"Minimum stacked command length: $"
infomsg4	db	13,10,9,"Bytes free in alias buffer: $"
infomsg5	db	13,10,9,"Alias translation is $"
infomsg5d	db	"disabled",13,10,"$"
infomsg5e	db	"enabled",13,10,"$"
infomsg6	db	13,10,9,"FUNCTION KEY DEFINITIONS$"
infomsg7	db	13,10,9,"ALIAS DEFINITIONS$"
infomsg8	db	13,10,"For help type ALIAS ?$"

filemsg1	db	13,10,"Error in line $"	;File identification message.
filemsg2	db	" of file: "
filenam_field	db	78 dup (0)		;Name of current entry file.

errmsg0		db	"Need DOS 2.0 or greater$"
errmsg1		db	"ALIAS not installed$"

errmsg2		db	13,10,"Syntax: ALIAS [alias [command]] "
		db	"[/F filename] [/S nn] [/U]",13,10
		db	14 dup (" ")
		db	"[/B nn] [/E] [/D] [/L] [/M]",13,10,10
		db     	9,"ALIAS alias command",13,10
		db     	9,"ALIAS [fn] command",13,10,10
		db     	9,"/B = Buffer size",13,10
		db     	9,"/D = Disable alias translation",13,10
		db     	9,"/E = Enable alias translation",13,10
		db     	9,"/F = Filename of command file",13,10
		db     	9,"/L = List aliases",13,10
		db     	9,"/M = Minimum command length to stack",13,10
		db     	9,"/S = Size of command stack",13,10
		db     	9,"/U = Uninstall",13,10,"$"

errmsg3		db	"Can",39,"t uninstall$"
errmsg4		db	"Can",39,"t change parameter after installation$"
errmsg5		db	"Illegal number$"
errmsg6		db	"Can",39,"t find alias file$"
errmsg7		db	"Can",39,"t find COMMAND.COM$"
errmsg8		db	"Not enough memory$"
errmsg9		db	"Alias list full$"
errmsg10	db	"List and stack too large$"
errmsg11	db	"Invalid key assignment$"
errmsg12	db	"Number too big$"
errmsg13	db	"Alias not in list$"
errmsg14	db	"Error using Int 2Fh$"
endmsg		db	13,10,"$"

shiftmsg	db	"S-$"
altmsg		db	"A-$"
ctlmsg		db	"C-$"

file_linecount	dw	0			;Line number being processed.
caps_flag	db	0
param_found	db	0			;Cmd line parameter found flag
append_cr	db	0			;Append cr to alias flag
cmdcom_name	db	"COMMAND"		;Name of command.com

cmd_switches	db	"sfeldbum*/"		;Letters of valid commands.
cmd_switch_end	=	$
cmd_jmp_tbl	dw	offset setstacksize	;This jump table is used to
		dw	offset loadaliasfile	;  call the routines that
		dw	offset enablealias      ;  process the command line
		dw	offset listalias	;  arguments
		dw	offset disablealias
		dw	offset setlistbuffer
		dw	offset remove
		dw	offset minstacklen
		dw	offset comment_line	;Comments can be indicated by
		dw	offset comment_line	;  a /* or a //.

;----------------------------------------------------------------------------
; Initialization routine.
;----------------------------------------------------------------------------
initialize	proc	near
		assume	cs:code,ds:code,es:code
		cld
		mov	ah,30h			;Get DOS version
		int	21h
		xchg	al,ah			;Swap major, minor numbers
		mov	dx,offset errmsg0	;Bad DOS version
		cmp	ah,2			;Run if DOS 2.0 or greater.
		jae	init1
jmp_disp_error:
		jmp	disp_error
init1:
		mov	dos_version,ax		;Save version number

		mov	ah,4ah			;Reduce memory allocation to
		mov	bx,1000h     		;  just this segment.
		int	21h

		mov	ax,offset end_of_code        	;Initialize alias list
		mov	word ptr [aliaslist_ptr],ax	;  pointers.
		mov	ax,cs
		mov	word ptr [aliaslist_ptr+2],ax
		lds	di,aliaslist_ptr		;Initialize alias list
		mov	ax,-1				;  by writing a -1 as
		stosw       				;  an end flag.
		mov	aliaslist_end,di
;
;See if a copy is already resident in memory. If > DOS 3.0, use int 2Fh.
;
		mov	byte ptr [main+2],0	;Initialize fingerprint
		cmp	dos_version,300h	;See if DOS 3.0 or later
		jb	find_copy1		;No, search the old way.
		mov	cx,16			;Try 16 different IDs.
find_copy:
		xor	ax,ax
		mov	es,ax
		mov	ah,multiplex_id		;Load ID.  Use Int 2Fh to
		int	2fh			;  reach installed code so
		or	al,al			;  that we are compatible
		jne	find_copy0		;  with 386 memory managers.
		push	cs
		pop	es                      ;If AL not changed, ALIAS not
		jmp	short find_copy4	;  installed.
find_copy0:
		push	cx
		call	cmpheader		;See if really Alias by
		pop	cx                      ;  comparing file headers.
		je	find_copy3
		inc	multiplex_id		;ID used by another program.
		loop	find_copy		;  Change and try again.
		mov	dx,offset errmsg14	;All IDs taken, print error
		jmp	disp_error        	;  msg and exit.
;
;For DOS 2.x find the installed code the old fashioned way by scanning
;the memory control blocks.
;
find_copy1:
		xor	bx,bx			;zero BX for start
		mov	ax,cs			;keep CS value in AX
find_copy2:
		inc	bx			;increment search segment value
		mov	es,bx
		assume	es:nothing
		cmp	ax,bx			;not installed if current
		je	find_copy4    		;  segment is found.
		call	cmpheader
		jne	find_copy2		;loop back if not found
find_copy3:
		inc	alrdy_installed		;Set installed flag
find_copy4:
		mov	other_seg,es		;Save seg of installed code
;
;Parse the command line for switches.
;
 		mov	ah,48h			;Allocate memory block for
  		mov	bx,0800h		;  alias file buffer.
 		int	21h
 		mov	dx,offset errmsg8	;Not enough memory msg
 		jc	jmp_disp_error
		mov	databuff_seg,ax		;Save segment to file buffer.
		mov	es,ax			;Treat the command line as
		xor	di,di			;  a 1 line file.
		mov	si,offset command_tail
		xor	cx,cx
		or	cl,[si]			;Get command line length
		je	parse_line_end		;If zero, skip parse routine
		inc	si                      ;Copy command line into file
		inc	cx			;  buffer.
		push	cx
		rep	movsb
		pop	cx			;CX = file size.
		xor	si,si			;Point SI to start of buffer
		push	es
		pop	ds			;Set DS to file buffer seg
		assume	ds:nothing
		mov	es,cs:[other_seg] 	;Set ES to installed code
;
;Parse command line and command files.
;
parse_line_loop:
		xor	bl,bl
		call	scanline     		;Get 1st character
		jc	parse_2                 ;If carriage return, skip line
		cmp	al,"/"			;Compare character to switch.
		je	parse_switch_found
		cmp	al,"?"			;See if help character
		je	parse_line_error
		call	setkey          	;Must be alias definition
		jc	parse_error
		mov	param_found,1		;Set parameter found flag
		jmp	short parse_2		;Return to parse loop
parse_line_error:
		mov	dx,offset errmsg2	;Command not found msg
parse_error:	jmp	short disp_error
parse_switch_found:
		mov	param_found,1		;Set parameter found flag
		lodsb				;Get command line switch
		dec	cx
		cmp	al,'A' 			;Convert to lower case if
		jb	parse_1			;  necessary.
		cmp	al,'Z'
		ja	parse_1
		or	al,20h
parse_1:
		push	cx			;Scan the list of allowable
		push	es			;  command switches. If switch
		push	cs			;  found, use its position for
		pop	es			;  an index into the list of
		mov	di,offset cmd_switches	;  routines.
		mov	cx,offset cmd_switch_end - offset cmd_switches
		mov	bx,offset cmd_switch_end - offset cmd_switches - 1
		repne	scasb
		mov	ax,cx			;Copy index into list
		pop	es
		pop	cx
		jne	parse_line_error
		sub	bx,ax			;Compute offset into list
		shl	bx,1			;Convert to word offset
		add	bx,offset cmd_jmp_tbl	;Add the start addr of table.
		call	cs:[bx]			;Call command routine.
		jc	disp_error		;If error terminate parse.
parse_2:
		jcxz	parse_line_end		;If at file end, exit parse.
                jmp	short parse_line_loop
;
;See if installed. If not, install.
;
parse_line_end:
		cmp	cs:[param_found],1	;See if any parameters found
		je 	init2			;If already installed and
		cmp	cs:[alrdy_installed],0	;  no parameters on the
		je	init2			;  command line, default to
		mov	es,cs:[other_seg] 	;  showing program information
		call	listalias
init2:
		mov	ah,49h			;Release memory block used
		mov	es,cs:[databuff_seg]	;  for file buffer.
		int	21h
		push	cs
		pop	ds
		assume	ds:code
		mov	word ptr databuff_seg,0
		cmp	alrdy_installed,0	;If not already installed,
		je	install			;  jump to install routine.
exit:
		mov	ax,4C00h		;Terminate with RC = 0
		int	21h
;
;Display error message.
;
disp_error:
		xor	ax,ax			;If file buffer still
		or 	ax,databuff_seg		;  allocated, deallocate it.
		jz	disp_error0
		mov	ah,49h			;Release memory block used
		mov 	es,ax    		;  for file buffer.
		int	21h
disp_error0:
		push	cs
		pop	ds
		assume	ds:code
		cmp	byte ptr filenam_field,0
		je	disp_error1             ;If processing a file, print
		push	dx                      ;  a message informing the
		mov	dx,offset filemsg1      ;  user the filename being
		call	printmsg                ;  processed and the line
		mov	ax,file_linecount       ;  that the error occured.
		call	hex2asc
		mov	dx,offset filemsg2
		call	printmsgcr
		pop	dx
disp_error1:
		call	printmsgcr		;print string
		mov	ax,4c01h		;Terminate with RC = 1
		int	21h
;
;Install routine. Find segment of COMMAND.COM, hook into int 21h, 2Fh and TSR.
;
		assume	ds:code
install:
		mov	dx,offset program       ;Display copyright message
		call	printmsg

		push	ds			;Save DS
		xor	ax,ax			;Then zero it
		mov	ds,ax
		mov	cs:[points],ax		;Record number of scan lines
		mov	ax,ds:[0460h]		;  per character and cursor
		mov	cs:[cursor_mode],ax	;  mode
		pop	ds			;Restore DS

		mov	byte ptr filenam_field,0  ;Don't callout file on error
		mov	ah,52h			;get address of first MCB
		int	21h
		mov	ax,es:[bx-2]		;point ES to MCB
		mov	cx,20			;Allow only 20 loops.
mcb_loop:
		mov	es,ax
		cmp	byte ptr es:[0],"M"	;check for mcb signature
		jne	mcb_error
		inc	ax			;point AX to memory block
		cmp	ax,es:[1]		;See if this is a PSP block
		je 	psp_found
mcb_continue:
		add	ax,es:[3]		;Get size of memory block
		loop	mcb_loop
mcb_error:
		mov	dx,offset errmsg7	;Can't locate command.com PSP
		jmp	disp_error
psp_found:
		cmp     dos_version,0400h	;If DOS 4.00 or greater,
		jb	psp_found_1		;  COMMAND.COM may not be the
		push	ds			;  first program loaded.  Look
		mov	si,offset cmdcom_name	;  at the name of the program
		mov	di,8			;  stored in the last 8 bytes
		mov	cx,7			;  of the memory control
		repe	cmpsb			;  block.  If the string
		pop	ds			;  "COMMAND" isn't found, keep
		jne	mcb_continue		;  looking.
psp_found_1:
		mov	cmdcom_psp,ax		;Save segment of cmd.com PSP
		mov	es,ax
		mov	ax,es:[2ch]		;Get seg of master environment
		mov	master_env,ax
;
;Set up pointers to the cmd stack and to move the alias list to the end of the
;command stack so it takes up less space when ALIAS resident.
;
		mov	di,mystack_ptr		;Get base of internal stack
		mov	work_buff_ptr,di	;Copy ptr to alias buffer
		add	di,128			;Add size of buffer
		mov	cmdstack_base,di	;Copy for start of cmd stack
		mov	ax,cmdstack_size	;Get size of command stack
		mov	ah,128          	;128 bytes for each entry
		mul	ah
		add	di,ax			 	;Add to cmd stack for
		mov	si,word ptr aliaslist_ptr	;  start of the
		mov	cx,aliaslist_end		;  alias list.
		mov     word ptr aliaslist_ptr,di	;Save new pointer.
		sub	cx,si           	;Compute size of list.
		mov	dx,di			;See if we have enough room
		add	dx,cx			;  for everything in one seg.
		jnc	install_1
		mov	dx,offset errmsg10	;Not enough memory, exit.
		jmp	disp_error
install_1:
		add	dx,alias_buffer		;Add additional space for list
		mov	aliaslist_size,dx	;Save pointer to end of seg
		add	dx,15			;Convert memory needed to
		shr	dx,1			;  paragraphs.
		shr	dx,1
		shr	dx,1
		shr	dx,1
		cmp	di,si			;Check for overlap in the move
		jb	install_2		;If overlap, copy list from
		std				;  the top down to avoid
		add	di,cx			;  overwriting the list.
		add	si,cx
		dec	si
		dec	di
;
;Revector interrupts 21h and 2Fh (if necessary).
;
install_2:
		mov	ax,3521h		;Get interrupt 21 (DOS)
		int	21h                     ;  vector.
		mov	word ptr [int21h],bx
		mov	word ptr [int21h+2],es
		push	dx			;Save memory size parameter
		mov	ax,2521h                ;Point int 21 to internal
		mov	dx,offset dosint        ;  routine.
		int	21h

		cmp	dos_version,300h	;See if we are using Int 2Fh
		jb	install_3
		mov	ax,352fh		;Get interrupt 2F (MUX)
		int	21h                     ;  vector.
		mov	word ptr [int2fh],bx
		mov	word ptr [int2fh+2],es
		mov	ax,252fh                ;Point int 2F to internal
		mov	dx,offset muxint        ;  routine.
		int	21h
install_3:
		pop	dx
		push	ds			;ES = DS
		pop	es
                jmp	final_install		;Jump to safe place for move.
initialize	endp

;-----------------------------------------------------------------------------
; CMPHEADER compares the first 16 bytes of this file with the segment
;           pointed to by ES.
; Entry:  DS - code segment
;         ES - pointer to segment to compare
; Exit:   ZF - 0 = segments match.
;-----------------------------------------------------------------------------
cmpheader	proc	near
		mov	si,offset main+2	;Search this segment for ASCII
		mov	di,si			;  fingerprint.
		mov	cx,16
		repe	cmpsb
		ret
cmpheader	endp

;-----------------------------------------------------------------------------
; PRINTMSG prints the message pointed to by DX to the screen.
; Entry:  DX - pointer to ASCII message terminated by $
;-----------------------------------------------------------------------------
printmsg	proc	near
		assume	ds:nothing,es:nothing
		push	ds
		push	cs
		pop	ds
		assume	ds:code
		mov	ah,9			;Print message
		int	21h
		pop	ds
		ret
printmsg	endp

;-----------------------------------------------------------------------------
; PRINTMSGCR calls PRINTMSG, then appends a carriage return to the message.
; Entry:  DX - pointer to ASCII message terminated by $
;-----------------------------------------------------------------------------
printmsgcr	proc	near
		assume	ds:nothing,es:nothing
		push	dx
		call	printmsg
		mov	dx,offset endmsg
		call	printmsg
		pop	dx
		ret
printmsgcr	endp

;-----------------------------------------------------------------------------
; SETSTACKSIZE - Sets the size of the command line stack.
; Entry:  DS:SI - points to stack size in ascii
; Exit:      CF - Clear if sucessful, Set if error, DX points to error msg.
;-----------------------------------------------------------------------------
setstacksize	proc	near
		assume	ds:nothing,es:nothing
		xor	bl,bl			;Check for installed code
		call	setparameter		;Get num and convert to binary
		jc	setstack_exit		;Check for error
		mov	cs:[cmdstack_size],ax	;Save parameter
setstack_exit:
		ret
setstacksize	endp

;-----------------------------------------------------------------------------
; SETLISTBUFFER - Sets the size of the additional buffer reserved for alias
;                 list expansion.
; Entry:  DS:SI - points to buffer size in ascii
; Exit:      CF - Clear if sucessful, Set if error, DX points to error msg.
;-----------------------------------------------------------------------------
setlistbuffer	proc	near
		assume	ds:nothing,es:nothing
		xor	bl,bl			;Check for installed code
		call	setparameter		;Get num and convert to binary
		jc	setlistbuffer_exit      ;Check for error
		mov	cs:[alias_buffer],ax	;Save buffer size parameter
setlistbuffer_exit:
		ret
setlistbuffer	endp

;-----------------------------------------------------------------------------
; MINSTACKLEN - sets the minimum legth of a command to stack.
; Entry:     ES - segment of the installed code
;         DS:SI - points to buffer size in ascii
; Exit:      CF - Clear if sucessful, Set if error, DX points to error msg.
;-----------------------------------------------------------------------------
minstacklen	proc	near
		assume	ds:nothing,es:nothing
		mov	bl,1 			;Don't check for installed code
		call	asc2bin			;Get num and convert to binary
		jc	minstacklen_exit	;Check for error
		cmp	al,126
		jb	minstacklen_1
		mov	dx,offset errmsg12	;Stack length too big
		stc
		jmp	short minstacklen_exit
minstacklen_1:
		or 	al,al			;Make sure min length is not
		jne	minstacklen_2		; specified at 0. If so,
		inc	al			; change to 1.
minstacklen_2:
		mov	es:[minlength],al	;Save minimum length parameter
minstacklen_exit:
		ret
minstacklen	endp

;-----------------------------------------------------------------------------
; SETPARAMETER - Common code used by the set stack and set buffer and set
;                minimum command length routines.
; Entry:  DS:SI - points to ascii number
;            BL - Flag to indicate check for installed code, BL=0, check.
; Exit:      CF - Clear if sucessful, Set if error.
;-----------------------------------------------------------------------------
setparameter	proc	near
		assume	ds:nothing,es:nothing
		mov	dx,offset errmsg4 	;Can't change parameter msg
		cmp	cs:[alrdy_installed],1	;If already installed don't
		je 	setparam_error          ;  change parameter.
		call	asc2bin
setparam_exit:
		ret
setparam_error:
		stc				;Set error flag.
		jmp	short setparam_exit
setparameter	endp

;-----------------------------------------------------------------------------
; SETKEY modifies the alias list to add function key definitions.
; Entry:  DS:SI - pointer to string identifing the function key
;            ES - pointer to segment of installed code
; Exit:      CF - clear if successful
;-----------------------------------------------------------------------------
setkey		proc	near
		assume	ds:nothing,es:nothing
		push	es
		cmp	al,"["			;Determine alias or key
		je	setkey_1
 		dec	si                      ;Backup before last key
 		inc	cx
		jmp	short setkey_5
setkey_1:
		lodsb				;Get next character
		dec	cx
		jcxz 	setkey_badkey
		mov	bx,58			;Load default F1 keycode
		or	al,20h			;Convert to lower case
		cmp	al,"f"
		je	setkey_3
		add	bx,25			;Assume shift F1 keycode
		cmp	al,"s"
		je	setkey_2
		add	bx,10			;Assume ctl F1 keycode
		cmp	al,"c"
		je	setkey_2
		add	bx,10			;Assume alt F1 keycode
		cmp	al,"a"
		jne	setkey_badkey
setkey_2:
		lodsb				;Get next character
		dec	cx
		or	al,20h			;Convert to lower case
		cmp	al,"f"			;Make sure next key is "f"
		jne	setkey_badkey
setkey_3:
		call	asc2bin
		jc  	setkey_badkey		;If bad number, exit
		or 	ax,ax
		je	setkey_badkey		;Make sure not zero
		cmp	ax,10
		ja	setkey_badkey		;Make sure less than 10
		cmp	byte ptr [si-1],"]"	;Check for closing bracket
		jne 	setkey_badkey		;  if not found, error
		add	bx,ax			;Add in function key number
		cmp	byte ptr [si]," "       ;Check to see if a character
		jbe	setkey_4                ;  trails the closing bracket.
		cmp	byte ptr [si],"*"       ;Check to see if an * is
		jne	setkey_badkey		;  appended to the function
		lodsb                           ;  key assignment. If so,
		dec	cx                      ;  remove key and set flag
		mov	cs:[append_cr],1        ;  to append cr to command.
setkey_4:
		sub	si,2			;Back up to keycode.
		xor	bh,bh
		mov	ds:[si],bx		;Save keycode on command line
		add	cx,2
setkey_5:
		call	setalias                ;Use SETALIAS to load
setkey_exit:
		pop	es			;Restore ptr to installed seg
		ret
setkey_badkey:
		mov	dx,offset errmsg11	;Bad key assignment msg
		stc
		jmp	setkey_exit
setkey		endp


;-----------------------------------------------------------------------------
; SETALIAS modifies the alias list according to command line agruments.
; Entry:  DS:SI - pointer to string to be inserted into alias list.
;            ES - pointer to segment of installed code.
; Exit:      CF - clear if successful
;-----------------------------------------------------------------------------
setalias	proc	near
		assume	ds:nothing,es:nothing
		push	es
		xor	bl,bl			;Find 1st character on
		call	scanline		;  command line.
		jnc	setalias_1		;If at end of line, exit
		jmp	setalias_exit		;  routine.
setalias_1:
;
;Get length of alias, then search list for matching alias
;
 		dec	si			;Backup to before 1st char.
		inc	cx
		mov	byte ptr cs:[alias_inlist],0 ;Assume not in list
		call	searchalias		;Is there already an alias?
		jc 	setalias_2		;No, continue.
		inc	byte ptr cs:[alias_inlist]
;
;If in list, erase old alias from list.
;
		call	delete_aliasent		;Delete entry from list
setalias_2:
;
;Append new alias to the end of the list.
;
		mov 	bp,di			;Save ptr to end of list.
		add	di,4                    ;Move past length fields.
		push	es			;Get max size of alias list.
		mov	es,cs:[other_seg]
		mov	dx,es:[aliaslist_size]
		pop	es
;
;Append alias to list.
;
		xor	ax,ax			;Clear character counter
setalias_3:
		lodsb				;Get byte
		dec	cx			;Decriment buffer counter.
		jcxz	setalias_4	     	;If at end of file, exit.
		cmp	al,13 			;See if at end of line.
		jne	setalias_6	     	;No, continue.
setalias_4:
		cmp	byte ptr cs:[alias_inlist],0
		jne	setalias_5	        ;Was alias in list?
		jmp	setalias_notnfil	;No, incomplete alias specifed
setalias_5:
		jmp	setalias_exit		;Yes, alias simply erased.
setalias_6:
		cmp	al,' '			;See if at end of tag.
		je	setalias_8		;Yes, exit copy loop
		cmp	al,9			;Check for tab
		je	setalias_8
		cmp	di,dx 			;See if alias list is full
		jbe	setalias_7  		;No, continue
		jmp	setalias_full		;Yes, exit routine
setalias_7:
		stosb				;No, add character to list
		inc	ah   			;Inc size of tag
		jmp	short setalias_3
setalias_8:
		mov	es:[bp+2],ah		;Save size of alias
;
;Append command to alias list.
;
		mov	cs:[caps_flag],0	;Clear environment var flag.
		xor	bx,bx			;Find 1st character in
		call	scanline		;  command.
		jc	setalias_exit		;If no command, exit
		xor	ah,ah			;Clear character counter
setalias_9:
		cmp	al,"%"			;Check for environment var
		jne	setalias_11		;  by checking for % signs.
		cmp	cs:[caps_flag],0	;If caps flag set capitialize
		jne	setalias_10		;  string before saving.
		mov	bl,ds:[si]		;Get next character
		cmp	bl,"0"			;If numberic, assume this is
		jb	setalias_10		;  a line parameter, not an
		cmp	bl,"9"			;  environment variable so
		jbe	setalias_11		;  don't set caps flag.
		cmp	bl,"%"			;Don't let double % signs
		je	setalias_11		;  indicate environment var.
setalias_10:
		not	byte ptr cs:[caps_flag]	;Toggle caps flag
setalias_11:
		cmp	cs:[caps_flag],0	;Capitialize environment
		je	setalias_12		;  variables so they will
		cmp	al,"a"			;  match when searched for in
		jb 	setalias_12		;  the environment block.
		cmp	al,"z"
		ja 	setalias_12
		and	al,0dfh			;Make character uppercase.
setalias_12:
		cmp	di,dx 			;See if alias list is full
		ja 	setalias_full		;Yes, exit routine
		stosb				;Append character on list
		inc	ah   			;Inc character counter.
		jcxz	setalias_13		;Check for end of file.
		lodsb				;Get next character
		dec	cx			;Dec file counter.
		cmp	al,13			;See if carriage return.
		jne	setalias_9              ;If not continue
setalias_13:
		cmp	cs:[append_cr],1	;If flag set, append carrage
		jne	setalias_14		;  return to command.
		mov	al,13
		inc	ah
		stosb
		mov	cs:[append_cr],0	;Clear flag
setalias_14:
		mov	es:[bp+3],ah		;Save command size
		mov	word ptr es:[di],-1	;Set new end of list flag
		mov	ax,di              	;Save end pointer to list
		add	ax,2			;Make room for the end flag.
		mov	cs:[aliaslist_end],ax
		sub	di,bp			;Compute size of entry
		mov	es:[bp],di		;Put size over old end flag.
		inc	cs:[file_linecount]	;Point counter to next line.
setalias_exit:
		clc
setalias_exit1:
		pop	es			;Restore ptr to installed seg
		ret
setalias_full:
		mov	dx,offset errmsg9	;Alias list too large msg.
		stc
		jmp	short setalias_exit1
setalias_notnfil:
		mov	dx,offset errmsg13	;Alias not in list.
		stc
		jmp	short setalias_exit1
setalias	endp

;-----------------------------------------------------------------------------
; DELALIASENTRY - Deletes an alias entry
; Entry:  DS:SI - pointer to the entry in the alias list to delete
; Exit:      CF - clear if successful
;-----------------------------------------------------------------------------
delete_aliasent	proc	near
		push	cx			;Save registers
		push	si
		push	ds                      ;Yes, remove entry from list
		push	es                      ;  by moving the remainder of
		pop 	ds                      ;  the list over this entry.
		mov	si,es:[di]		;Point SI to the next list
		add	si,di			;  entry.
delent_1:
		cmp 	word ptr es:[si],-1   	;Check for the end of the list
		je	delent_2
		mov	cx,es:[si]		;Get size of entry
		rep	movsb			;Copy next entry over current
		jmp	short delent_1		;  entry.
delent_2:
		mov	word ptr es:[di],-1	;Set end of list indicator
		pop	ds			;Get back file buffer pointer
		pop	si
		pop	cx
		ret
delete_aliasent	endp

;-----------------------------------------------------------------------------
; LOADALIASFILE loads a file containing a list of alias commands.
; Entry:  DS:SI - pointer to the name of the file to open
; exit:      CX - size of the file in bytes
;            CF - clear if successful
;-----------------------------------------------------------------------------
loadaliasfile	proc	near
		assume	ds:nothing,es:nothing
		xor	bl,bl
		call	scanline		;Find 1st char of filename.
		mov 	dx,si			;Copy filename pointer
		inc	bl			;Find end of filename
		call	scanline
		mov	byte ptr [si-1],0	;Make filename ASCIIZ.
		dec	dx
		mov	ax,3d00h		;Open file (Read only)
		int	21h
		jc	loadfile_error
		mov	bx,ax			;Copy file handle
;
;Save the name of the file for error messages.
;
		push    si
		push	es
		mov	di,offset filenam_field
		push	cs
		pop	es
		mov	si,dx
loadfile_1:
		lodsb
		stosb
		or	al,al
		jne	loadfile_1
		mov	byte ptr es:[di-1],"$"	;Terminate string with $.
		pop	es
		pop	si
;
;Open file and read contents into file buffer.
;
		mov	ah,3fh			;Read alias file
		xor	dx,dx			;Pont to base of file buffer.
		mov	cx,07f00h		;Read up to 32512 bytes.
 		int	21h
		mov	si,ax
		mov	byte ptr ds:[si],13	;Append a CR to end of file.
		mov 	cx,ax			;Save new file size
		xor	si,si			;Reset file pointer.
		mov	ah,3eh			;Close file.
		int	21h
		mov	cs:[file_linecount],1	;Reset line counter.
loadfile_exit:
		clc
loadfile_exit1:
		ret
loadfile_error:
		stc
		mov	dx,offset errmsg6	;Bad filename specified.
		jmp	short loadfile_exit1
loadaliasfile	endp

;-----------------------------------------------------------------------------
; LISTALIAS prints the alias list to screen.
; Entry:  ES - segment of the installed code
;-----------------------------------------------------------------------------
listalias	proc	near
		assume	ds:nothing,es:nothing
		push	ds
;
;Print Command stack size and amount of alias buffer space remaining
;
		mov	dx,offset infomsg2	;Print size of command stack
		call	printmsg
		mov	ax,es:[cmdstack_size]	;Get size of command stack
		call	hex2asc			;Print size
		mov	dx,offset infomsg3	;Print min cmd length
		call	printmsg
		xor	ax,ax
		mov	al,es:[minlength]	;Get min cmd length to stack
		call	hex2asc			;Print length
		mov	dx,offset infomsg4	;Print label to buffer size
		call	printmsg
		lds	si,es:[aliaslist_ptr]	;Get pointer to alias list
listalias_1:
		cmp	word ptr [si],-1	;Scan through alias list to
		je	listalias_2		;  find the end of the list.
                add	si,[si]			;Point to next entry
		jmp	short listalias_1
listalias_2:
		mov	ax,es:[aliaslist_size]	;Get offset to end of buffer
		sub	ax,si			;Subtract end of alias list
		sub	ax,2			;Correct for end pointer
		call	hex2asc			;Print size
		mov	dx,offset infomsg5	;Indicate if alias translation
		call	printmsg		;  is enabled or disabled
		mov	dx,offset infomsg5d	;Disabled message
		cmp	byte ptr es:[chk_alias],0	;See if alias enabled
		je	listalias_3
		mov	dx,offset infomsg5e     ;Enabled message
listalias_3:
		call	printmsg
;
;Scan through alias list to print function key assignments
;
		xor	dx,dx			;Clear alias found flag
		lds	si,es:[aliaslist_ptr]	;Get pointer to alias list
listalias_4:
		cmp	word ptr [si],-1	;Check for end of list
		jne	listalias_5
		jmp	listalias_11
listalias_5:
		mov	bx,si			;Save pointer to entry.
 		cmp	byte ptr [si+5],0	;See if key assignment
 		je	listalias_6		;If so, skip entry
		or  	dh,1			;Set alias found flag
		add	si,[bx]			;Point to next entry
		jmp	short listalias_4
listalias_6:
;
;Convert scan code into function key label
;
		test	dh,80h			;See if first time though
		jne	listalias_7
		push	dx
		mov	dx,offset infomsg6      ;If first time print header
		call	printmsgcr
		pop	dx
		or	dh,80h			;Set header printed flag
listalias_7:
		call	printtab
		push	dx
                add	si,4     		;Point SI to command string
		mov	al,[si]			;Get key code
		mov	dh,al
		cmp	al,84                   ;Check for base code
		jb 	listalias_9
		sub	dh,25
		mov     di,offset shiftmsg	;Assume shift prefix
		cmp	al,94			;Check for shift
		jb	listalias_8
		sub	dh,10
		mov     di,offset ctlmsg	;Assume control prefix
		cmp	al,104			;Check for ctl
		jb	listalias_8
		mov     di,offset altmsg	;Assume alt prefix
		sub	dh,10
listalias_8:
		push	dx			;Print prefix identifier
		mov	dx,di
		call    printmsg
		pop	dx
listalias_9:
		mov	dl,"F"			;Set function key
		mov	ah,2			;Character output
		int	21h
		mov	al,dh  			;Get modified key code
		sub	al,58			;Convert from scan code to hex
		xor	ah,ah
		call	hex2asc			;Print function key number
		mov	cl,[bx+3]		;Get length of command
		inc	si			;Point SI to command string
		inc	si
		mov	di,bx
		add	di,[bx]
		cmp	byte ptr [di-1],13	;Check for carrage return
		jne	listalias_10		;  after command. If found,
		mov	dl,'*'			;  indicate immediate command
		mov	ah,2			;  by appending an * to the
		int	21h			;  end of the function key.
listalias_10:
		call	printtab
		call	printtab
		call	print_string		;Print command to screen
		mov	dx,offset endmsg	;Append carriage return to
		call	printmsg		;  advance to next line. SI
		pop	dx                      ;  points to the next entry.
		jmp	listalias_4
;
;Scan through alias list to print aliases.
;
listalias_11:
 		test	dh,1              	;See if any aliases found
 		je	listalias_exit		;If no aliases, skip remainder
		mov	dx,offset infomsg7	;Print header
		call	printmsgcr
		xor	cx,cx			;Clear CX
		lds	si,es:[aliaslist_ptr]	;Get pointer to alias list
listalias_12:
		mov	bx,si			;Save pointer to entry.
 		cmp	byte ptr [si+5],0	;See if key definition
 		jne	listalias_13		;If so, skip entry
		add	si,[bx]
		jmp	short listalias_14
listalias_13:
		call	printtab
                add	si,4     		;Point SI to alias string
		mov	cl,[bx+2]		;Get length of alias
		call	print_string		;Print alias to screen
		call	printtab
		call	printtab
		mov	cl,[bx+3]		;Get length of command
		call	print_string		;Print command to screen
		mov	dx,offset endmsg	;Append carriage return to
		call	printmsg		;  advance to next line.
listalias_14:
		cmp	word ptr [si],-1	;Check for end of list. SI
		jne	listalias_12		;  points to the next entry.
listalias_exit:
		mov	dx,offset infomsg8	;Print pointer to help msg
		call	printmsgcr
		pop	ds
		clc
		ret
listalias	endp

;-----------------------------------------------------------------------------
; PRINTTAB prints a TAB character to the screen.
; Entry:  ES - segment of the installed code
;-----------------------------------------------------------------------------
printtab	proc	near
		assume	ds:nothing,es:nothing
		mov	ah,2			;Character output
		mov	dl,9			;Print TAB character
		int	21h
		ret
printtab	endp

;-----------------------------------------------------------------------------
; ENABLEALIAS enables alias translation.
; Entry:  ES - segment of the installed code
;-----------------------------------------------------------------------------
enablealias	proc	near
		assume	ds:nothing,es:nothing
		mov	byte ptr es:[chk_alias],1	;Enable alias
		clc
		ret
enablealias	endp

;-----------------------------------------------------------------------------
; DISABLEALIAS disables alias translation.
; Entry:  ES - segment of the installed code
;-----------------------------------------------------------------------------
disablealias 	proc	near
		assume	ds:nothing,es:nothing
		mov	byte ptr es:[chk_alias],0	;Disable alias
		clc
		ret
disablealias 	endp

;-----------------------------------------------------------------------------
; REMOVE uninstalls the installed program from memory.
;-----------------------------------------------------------------------------
remove		proc	near
		assume	ds:nothing,es:nothing
		push	ds
		mov	dx,offset errmsg1	;Not installed msg
		cmp	cs:[alrdy_installed],0	;See if installed
		je 	remove_exit   		;Not installed, error

		mov	cx,cs:[other_seg]	;Get segment of installed code
		mov	ax,3521h                ;Get DOS vector
		int	21h
		mov	ax,es			;Check to make sure DOS
		cmp	ax,cs:[other_seg]	;  vector not modified.
		jne	remove_error

		lds	dx,es:[int2fh]		;Get old interrupt 2F vector
		cmp	dx,-1			;See if Int used
		je	remove_1		;No, skip check of Int 2F
		mov	ax,352fh                ;Get MUX vector
		int	21h
		mov	ax,es			;Check to make sure MUX
		cmp	ax,cs:[other_seg]	;  vector not modified.
		jne	remove_error
		mov	ax,252fh		;Set interrupt
		int	21h
remove_1:
		lds	dx,es:[int21h]		;Get old interrupt 21 vector
		mov	ax,2521h		;Set interrupt
		int	21h
		mov	cx,es:[env_segment]
		mov	ah,49h			;Free memory block
		int	21h
		mov	es,cx			;Free environment block
		mov	ah,49h
		int	21h
		mov	dx,offset infomsg1	;Indicate uninstalled.
		mov	byte ptr filenam_field,0 ;Clear filename field
remove_exit:
		stc
		pop	ds
remove_exit1:	ret
remove_error:
             	mov	dx,offset errmsg3	;Can't remove error msg
		jmp	short remove_exit

remove		endp

;-----------------------------------------------------------------------------
; COMMENT_LINE allows comments in the alias file by skipping to the next
; carriage return.
; Entry:  SI - pointer to ASCII string
;         CX - file length
;-----------------------------------------------------------------------------
comment_line	proc near
		assume	ds:nothing,es:nothing
comment_loop:
		push	es
		push	ds
		pop	es
		mov	di,si			;Copy file pointer
		mov	al,13			;Scan for carriage return.
		repne	scasb
		inc	cs:[file_linecount]	;Inc file line counter.
		mov	si,di			;Restore file pointer.
		pop	es
		clc
 		ret
comment_line	endp

;-----------------------------------------------------------------------------
; HEX2ASC converts a binary number to ASCII and prints it to the screen.
; Entry:  AX - binary number
;-----------------------------------------------------------------------------
hex2asc    	proc near
		assume	ds:nothing,es:nothing
		push	bx
		mov	cx,5			;Allow max of five digits
hex_loop1:
		xor	dx,dx                   ;Clear high word
		mov	bx,10			;Load number base
		div	bx			;Divide by base (10)
		add	dl,30h          	;Convert to ascii
		push	dx                      ;Save digit on stack
		loop	hex_loop1
		mov	cx,5			;Allow max of five digits
		mov	bl,"0"			;Set leading zero indicator
hex_loop2:
		pop	dx			;Get digit off stack
		or 	bl,dl 			;Don't print leading zeros.
		cmp	bl,"0"			;The first non zero will
		je	hex_1			;  change bl to non-zero.
		mov	ah,2			;DOS character output
		int	21h
hex_1:
		loop	hex_loop2
hex_exit:
		pop	bx
 		ret
hex2asc     	endp

;-----------------------------------------------------------------------------
; ASC2BIN - converts an ASCII number of the command line to hex.
; Entry:  DS:SI - pointer to ASCII number
;-----------------------------------------------------------------------------
asc2bin		proc	near
		push	bx
		xor	bl,bl
		call	scanline		;Find next character.
		mov	di,offset errmsg5	;Bad number message
		jc	asc_error		;If no number found, error
		mov	bl,al			;Copy first digit.
            	xor	ax,ax			;Clear out sum
		xor	bh,bh			;Clear high byte for word adds
asc_loop:
		cmp	bl," "  		;If space, assume end of
		jbe	asc_exit		;  number.
		cmp	bl,"]"			;Exit if closing bracket
		je	asc_exit		;  encountered
		sub	bl,"0"			;Check for valid number then
		jb	asc_error		;  convert to binary.
		cmp	bl,9
		ja	asc_error
		mov	dx,10			;DX holds base multiplier
		mul	dx 			;Shift over current number
		jc	asc_overflow		;If overflow, indicate error
		add	ax,bx			;Add new digit to sum.
		jcxz	asc_exit		;If end of file, exit.
		mov	bl,ds:[si]		;Get next ASCII character
		inc	si			;Point to next character
		dec	cx			;Dec file size counter
		jmp	short asc_loop		;Go back for more
asc_exit:
		clc				;Clear error flag.
asc_exit1:
		pop	bx
		ret
asc_overflow:
		mov	di,offset errmsg12	;Number too large message.
asc_error:
		mov	dx,di			;Copy message pointer.
		stc				;Set error flag.
		jmp	short asc_exit1
asc2bin		endp
;-----------------------------------------------------------------------------
; SCANLINE performs the same function as SCAN4CHAR but keeps track of the
; carriage returns.
; Entry:  SI - pointer to ASCII string
;         BL - 0 = find next char, 1 = find next space
;         CX - file length
; Exit:   AL - first nonspace character
;         CF - set if carriage return found
;-----------------------------------------------------------------------------
scanline	proc	near
		call	scan4char		;Find the next char.
		jnc	scanline_exit
		inc	cs:[file_linecount]	;Point to next line.
		stc
scanline_exit:
		ret
scanline	endp

end_of_code	=	$
code		ends

end		main
