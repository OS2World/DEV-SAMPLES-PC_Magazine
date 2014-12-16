;; DOSTERM.ASM - A DOS terminal emulation program
;;
;; This code illustrates how a program written for the DOS
;; environment can program the UART and interrupt controller
;; for interrupt-driven serial I/O.  An ISR is set up to
;; service received data ready interrupts coming from IRQ4 (COM1)
;; and buffer the data in a 1,024-byte circular queue similar to
;; the BIOS keyboard buffer.
;;
;; Characters are read from the queue by calling the subroutine
;; READ_CHAR.  Characters transmitted are output directly to the
;; UART by SEND_CHAR.  Execution ends when the Esc key is pressed.
;;
;; Copyright (c) 1989 Ziff Communications Company

INTA00		equ	20h			;8259A IRQ control register
INTA01		equ	21h			;8259A IRQ mask register

data		segment	word public 'DATA'
error_msg	db	"COM1 not installed",13,10,"$"
data_buffer	db	1024 dup (?)		;input buffer
buffer_start	dw	offset data_buffer	;starting buffer address
buffer_end	dw	offset buffer_start	;ending buffer address
buffer_head	dw	offset data_buffer	;location for next write
buffer_tail	dw	offset data_buffer	;location for next read
uart_addr	dw	?			;UART base address
int0Ch		dd	?			;old interrupt 0Ch vector
data		ends

stack		segment	stack
		dw	256 dup (?)		;stack area
stack		ends

code		segment	word public 'CODE'
		assume	cs:code,ds:data,ss:stack

;;
;; MAIN initializes the system for interrupt-driven input and
;; calls TERM to perform terminal emulation functions.
;;

main		proc	far
		mov	ax,data			;point DS to the data
		mov	ds,ax			;  segment
;
;Obtain the base address of COM1 from the BIOS data area.
;
		mov	ax,40h			;point ES to data area
		mov	es,ax
		mov	ax,word ptr es:[0]	;get the word at 0040:0000h
		mov	uart_addr,ax		;save it

		or	ax,ax			;exit on error if COM1
		jnz	vector			;  is not installed
		mov	ah,9
		mov	dx,offset error_msg
		int	21h
		mov	ax,4C01h
		int	21h
;
;Save the old interrupt 0Ch vector and point it to READ_COM.
;
vector:		mov	ax,350Ch		;obtain and save the current
		int	21h			;  value of the int 0Ch
		mov	word ptr int0Ch,bx	;  vector
		mov	word ptr int0Ch[2],es

		assume	ds:nothing		;save DS
		push	ds
		mov	ax,cs
		mov	ds,ax
		mov	ax,250Ch		;revector to our own
		mov	dx,offset read_com	;  interrupt handler
		int	21h
		pop	ds			;restore DS
		assume	ds:data
;
;Initialize the UART to 9600 N81.
;
		mov	ax,00E3h		;9600 bps, no parity,
		xor	dx,dx			;  8 data bits, and 1
		int	14h			;  stop bit
;
;Unmask IRQ4 interrupts in the 8259's IRQ mask register.
;
		in	al,INTA01		;clear bit 4 to unmask
		and	al,0EFh			;  IRQ4 (COM1) interrupts
		out	INTA01,al
;
;Initialize the Interrupt Enable Register and assert GPO2.
;
		mov	dx,uart_addr		;first clear DLAB
		add	dx,3
		in	al,dx
		and	al,07Fh
		out	dx,al

		sub	dx,2			;set bit 0 for received data
		mov	al,1			;  ready interrupts
		out	dx,al

		add	dx,3			;assert GPO2, DTR, and RTS
		mov	al,0Bh
		out	dx,al
;
;Send and receive characters until ESC is pressed.
;
		call	term
;
;Reset the system and exit.
;
		mov	dx,uart_addr		;clear bits 0, 1, and 3 of
		add	dx,4			;  the Modem Control Register
		in	al,dx
		and	al,0F4h
		out	dx,al

		sub	dx,3			;disable UART interrupts
		xor	al,al
		out	dx,al

		in	al,INTA01		;mask off IRQ4 interrupts
		or	al,10h			;  that reach the 8259A
		out	dx,al

		mov	ax,250Ch		;reset the int 0Ch vector
		lds	dx,[int0Ch]
		int	21h

		mov	ax,4C00h		;terminate
		int	21h
main		endp

;;
;; TERM transmits characters typed at the keyboard and displays those
;; received at the serial port.
;;

term		proc	near
;
;Check the keyboard buffer and process any waiting keycodes.
;
term_loop:	mov	ah,1			;don't read the keyboard if
		int	16h			;  nothing is waiting
		jz	keys_clear

		xor	ah,ah			;read keycode
		int	16h
		or	al,al			;ignore extended keycodes
		jz	keys_clear
		cmp	al,01Bh			;exit if ESC was pressed
		jne	output
		ret

output:		push	ax			;display the character
		call	display_char
		pop	ax

		call	send_char		;output the character
;
;Check the serial input buffer and read it if a character is waiting.
;
keys_clear:	mov	ax,buffer_tail		;loop back if the buffer is
		cmp	ax,buffer_head		;  empty
		je	term_loop

		call	read_char			;extract character from buffer

		call	display_char		;display it
		jmp	term_loop		;return to loop
term		endp

;;
;; READ_CHAR waits for a character to appear in the serial input
;; queue, then reads it and returns it in AL.
;;

read_char	proc	near
no_char:	mov	bx,buffer_tail		;loop until a character
		cmp	bx,buffer_head		;  appears in the serial
		je	no_char			;  input buffer

		cli				;interrupts off
		mov	al,[bx]			;read a byte from the buffer
		inc	bx			;  and advance the tail
		cmp	bx,buffer_end		;wrap around to start of buffer
		jne	read_exit		;  if necessary
		mov	bx,buffer_start
read_exit:	mov	buffer_tail,bx

		sti				;interrupts on
		ret				;  and exit
read_char	endp

;;
;; DISPLAY_CHAR writes the character in AL to the screen buffer.
;;

display_char	proc	near
		mov	ah,0Eh			;BIOS TTy function
		xor	bh,bh
		int	10h
		ret
display_char	endp

;;
;; SEND_CHAR writes the character in AL to COM1.
;;

send_char	proc	near
		push	ax			;save character code
		mov	dx,uart_addr		;point DX to Line Status
		add	dx,5

send_loop:	in	al,dx			;loop until Transmit
		test	al,20h			;  Holding register
		jz	send_loop		;  is empty

		sub	dx,5			;then output the character
		pop	ax
		out	dx,al
		ret
send_char	endp

;;
;; READ_COM handles interrupts generated by COM1 when a byte of data
;; is received.  Data is read from the UART's Receive Buffer register
;; and stored in a FIFO queue.
;;

read_com	proc	far
		push	ax			;save registers
		push	bx
		push	dx
		push	ds

		mov	ax,data			;establish DS addressability
		mov	ds,ax

		mov	dx,uart_addr		;make sure DLAB is clear
		add	dx,3
		in	al,dx
		and	al,07Fh
		out	dx,al
		
		mov	dx,uart_addr		;read the character
		in	al,dx

		mov	bx,buffer_head		;calculate next head position
		mov	dx,bx			;  to make sure the buffer
		inc	dx			;  isn't full
		cmp	dx,buffer_end
		jne	no_wrap
		mov	dx,buffer_start
no_wrap:	cmp	dx,buffer_tail
		je	exit_int		;exit if buffer is full

		mov	[bx],al			;insert character in buffer
		mov	buffer_head,dx		;advance head pointer

exit_int:	mov	al,20h			;signal EOI to the 8259
		out	INTA00,al
		sti				;interrupts on

		pop	ds			;restore registers
		pop	dx
		pop	bx
		pop	ax
		iret				;return from interrupt
read_com	endp

code		ends
		end	main
