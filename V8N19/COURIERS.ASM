	PAGE	60,132
	TITLE	'Couriers:  Serial-port Services for 1stClass'

TIMER	=	46CH		; low-memory timer word
CTRL_Q	=	11H		; ASCII Control-Q/XON/DC1
CTRL_S	=	13H		; ASCII Control-S/XOFF/DC3

; Service options

INPUT_FLOW	=	01H	; handle input flow control (send ^S/^Q)
OUTPUT_FLOW	=	02H	; handle output flow control (receive ^S/^Q)

; COM port register offsets

COM_TXB=	0	; Transmit Buffer
COM_RXB=	0	; Receive Buffer
COM_DLL=	0	; Divisor Latch LSB
COM_DLM=	1	; Divisor Latch MSB
COM_IER=	1	; Interrupt Enable Register
COM_IIR=	2	; Interrupt Identification Register
COM_LCR=	3	; Line-Control Register
COM_MCR=	4	; Modem Control Register
COM_LSR=	5	; Line Status Register
COM_MSR=	6	; Modem Status Register

PSEG	SEGMENT
	ASSUME	CS:PSEG
	ORG	100H
ENTRY:	JMP	MAIN

PROGRAM_NAME	LABEL	BYTE
INITMSG	DB	'Couriers 1.0 - (c) 1989 Ziff Communications Co.',13,10
	DB	'PC Magazine * Pete Maclean$'

; Structure for holding the fixed and operating parameters for a COM port

COM_PORT	STRUC
COM_IH		DW	?	; (offset) address of interrupt handler
COM_ADDRESS	DW	?	; i/o address
COM_IVA		DW	?	; interrupt vector address
COM_BIT		DB	?	; IRQ mask bit

COM_OPTIONS	DW	?	; options set for port at configuration

COM_FLAGS	DB	?	; various bit flags
COM_OUTFLOW	DB	?	; flow-control character awaiting transmission

COM_IN_CTR	DW	?	; counter for bytes in input buffer
COM_IN_LO	DW	?	; low threshold for input flow control
COM_IN_HI	DW	?	; high threshold for input flow control

COM_IN_PTR	DW	?	; input pointer (offset)
COM_IN_SEG	DW	?	; input segment
COM_RD_PTR	DW	?	; read pointer (offset)
COM_IN_FIRST	DW	?	; base offset of input buffer
COM_IN_LIMIT	DW	?	; limit offset of input buffer

COM_OUT_PTR	DW	?	; output pointer (offset)
COM_OUT_SEG	DW	?	; output segment
COM_OUT_LIMIT	DW	?	; output limit (offset)

COM_PORT	ENDS

COM_SIZE	=	SIZE COM_PORT

; Definitions of bit flags for the COM_FLAGS field

CF_ISF		=	01H	; input suspended by flow control
CF_OSF		=	02H	; output suspended by flow control

; Tables

PORT1		COM_PORT	<IH1, 3F8H, 30H, 10H>	; COM1
PORT2		COM_PORT	<IH2, 2F8H, 2CH, 08H>	; COM2
PORT3		COM_PORT	<IH3, 3E8H, 30H, 10H>	; COM3
PORT4		COM_PORT	<IH4, 2E8H, 2CH, 08H>	; COM4

F_SWITCH	LABEL	WORD
					; 80h - check if Couriers is loaded
		DW	F_BUSY		; 81h - check if port busy
		DW	F_CONFIGURE	; 82h - set port parameters
		DW	F_INPUT		; 83h - start input on port
		DW	F_READ		; 84h - get next input
		DW	F_CLEAR_INPUT	; 85h - flush pending input
		DW	F_OUTPUT	; 86h - initiate tranmission
		DW	F_CHECK_OUTPUT	; 87h - report output status
		DW	F_ABORT_OUTPUT	; 88h - abort current output
		DW	F_OUTCH		; 89h - output a single character
		DW	F_BREAK		; 8Ah - send BREAK
		DW	F_STATUS	; 8Bh - get port status
		DW	F_SPEED		; 8Ch - change bps rate
		DW	F_DECONFIG	; 8Dh - deconfigure port

INTSWITCH	DW	MODEM_STATUS_INT
		DW	TX_INT
		DW	RX_INT
		DW	LINE_STATUS_INT

;******************************************************************************
;
; COM Interrupt Handlers

IH1	PROC	NEAR			; COM1
	PUSH	BX
	MOV	BX,OFFSET PORT1
	JMP	SHORT INTERRUPT_HANDLER
IH1	ENDP

IH2	PROC	NEAR			; COM2
	PUSH	BX
	MOV	BX,OFFSET PORT2
	JMP	SHORT INTERRUPT_HANDLER
IH2	ENDP

IH3	PROC	NEAR			; COM3
	PUSH	BX
	MOV	BX,OFFSET PORT3
	JMP	SHORT INTERRUPT_HANDLER
IH3	ENDP

IH4	PROC	NEAR			; COM4
	PUSH	BX
	MOV	BX,OFFSET PORT4
IH4	ENDP

INTERRUPT_HANDLER	PROC	NEAR	; BX -> port table
	PUSH	AX
	PUSH	DX
	PUSH	SI
	PUSH	DS
	PUSH	ES			; CX, DI and BP are not used here
	PUSH	CS			; set DS to local segment
	POP	DS
	ASSUME	DS:PSEG

	MOV	DX,[BX+COM_ADDRESS]	; DX = COM port i/o address
	ADD	DL,COM_IIR		; DX -> Interrupt ID Register
	IN	AL,DX			; identify the cause of the interrupt

INT1:	PUSH	DX			; save IIR address
	AND	AX,0006H		; mask off interrupts type
	MOV	SI,AX			; and branch accordingly
	CALL	INTSWITCH[SI]

	STI				; allow higher priority interrupts
	POP	DX			; DX = IIR address
	ADD	DL,COM_MCR-COM_IIR	; DX -> Modem Control Register
	MOV	AL,03H			; waggle OUT2
	OUT	DX,AL
	MOV	AL,0BH
	JMP	SHORT $+2		; take enough time between outs
	OUT	DX,AL
	CLI				; interrupts off again

	ADD	DL,COM_IIR-COM_MCR	; DX -> Interrupt ID Register
	IN	AL,DX			; check if another interrupt is pending
	TEST	AL,01H
	JZ	INT1			; loop if another one is ready

	MOV	AL,20H			; take care of interrupt controller
	OUT	20H,AL
	POP	ES
	POP	DS
	POP	SI
	POP	DX
	POP	AX
	POP	BX
	IRET
INTERRUPT_HANDLER	ENDP
		
; Received Character Interrupt

RX_INT	PROC	NEAR	; BX -> port table, DX -> COM port Interrupt Id Reg
	ADD	DL,COM_LSR-COM_IIR	; DX -> Line Status Register
	IN	AL,DX			; read COM port status
	MOV	AH,AL			; status to AH
	ADD	DL,COM_RXB-COM_LSR	; DX -> Receive Buffer
	IN	AL,DX			; read character from COM port
	TEST	[BX+COM_OPTIONS],OUTPUT_FLOW	; output flow control on?
	JZ	RX2			; if not...
	CMP	AL,CTRL_S		; is character a Control-S?
	JNE	RX1			; no, check for Control-Q
	OR	[BX+COM_FLAGS],CF_OSF	; set flag to suspend output
	RET

RX1:	CMP	AL,CTRL_Q		; is character a Control-Q?
	JNE	RX2			; if not then it is data
	TEST	[BX+COM_FLAGS],CF_OSF	; is output stopped?
	JZ	RX4			; if it is not then we need do nothing
	AND	[BX+COM_FLAGS],NOT CF_OSF	; clear suspend-output flag
	ADD	DL,COM_LSR-COM_RXB	; DX -> Line Status Register
	IN	AL,DX			; read the port status
	TEST	AL,20H			; is the transmitter buffer empty?
	JZ	RX4			; if not then output will continue
	JMP	START_OUTPUT		; else it must be restarted

RX2:	LES	SI,DWORD PTR [BX+COM_IN_PTR]	; ES:SI = input pointer
	MOV	ES:[SI],AX		; deposit input in buffer
	INC	SI			; bump pointer to next word
	INC	SI
	INC	[BX+COM_IN_CTR]		; increment counter
	CMP	SI,[BX+COM_IN_LIMIT]	; time to wrap?
	JE	RX5			; yes...

RX3:	MOV	[BX+COM_IN_PTR],SI	; update in pointer
	CMP	SI,[BX+COM_RD_PTR]	; check for overflow
	JE	RX6			; reset the buffer with error flag

	TEST	[BX+COM_OPTIONS],INPUT_FLOW	; input flow control on?
	JZ	RX4			; if not we are done
	TEST	SI,000EH		; else check buffer every 8th char
	JNZ	RX4
	TEST	[BX+COM_FLAGS],CF_ISF	; is input staunched?
	JNZ	RX4			; if so all is well
	MOV	AX,[BX+COM_IN_CTR]	; AX = input counter
	CMP	AX,[BX+COM_IN_HI]
	JB	RX4
	OR	[BX+COM_FLAGS],CF_ISF	; flag input staunched
	ADD	DL,COM_LSR-COM_RXB	; DX -> Line Status Register
	IN	AL,DX
	TEST	AL,20H			; transmit buffer empty?
	MOV	AL,CTRL_S
	JZ	RX35			; no
	ADD	DL,COM_TXB-COM_LSR	; DX -> Transmit Buffer
	OUT	DX,AL			; transmit the ^S or ^Q
	RET

RX35:	MOV	[BX+COM_OUTFLOW],AL

RX4:	RET

RX5:	MOV	SI,[BX+COM_IN_FIRST]
	JMP	SHORT	RX3

RX6:	XOR	AX,AX
	MOV	[BX+COM_IN_CTR],AX	; zero the input counter
	DEC	AX			; store -1 as overflow marker
	JMP	SHORT RX2
RX_INT	ENDP
		
; Transmit Character Interrupt

TX_INT	PROC	NEAR	; BX -> port table, DX -> COM port Interrupt Id Reg
	ADD	DL,COM_TXB-COM_IIR	; DX -> COM port transmit buffer
	XOR	AX,AX
	XCHG	AL,[BX+COM_OUTFLOW]	; is there a flow-control char waiting?
	TEST	AL,AL
	JNZ	TX2			; if so go send it

	TEST	[BX+COM_FLAGS],CF_OSF	; is output suspended by flow control?
	JNZ	TX4			; if so then we do nothing
	PUSH	ES
	LES	SI,DWORD PTR [BX+COM_OUT_PTR]	; get ES:SI = output pointer
	TEST	SI,SI			; is output active?
	JZ	TX3			; no, return

	MOV	AL,ES:[SI]		; AL = next character
	INC	SI			; bump the pointer
	CMP	SI,[BX+COM_OUT_LIMIT]	; time to stop?
	JE	TX5			; yes...

TX1:	MOV	[BX+COM_OUT_PTR],SI	; update pointer
	POP	ES

TX2:	OUT	DX,AL			; transmit the character
	CLC				; signal character sent
	RET

TX3:	POP	ES

TX4:	STC				; signal no character sent
	RET

TX5:	XOR	SI,SI
	JMP	SHORT	TX1
TX_INT	ENDP

; Status Interrupts

MODEM_STATUS_INT	PROC	NEAR
	ADD	DL,COM_MSR-COM_IIR
	IN	AL,DX
	RET
MODEM_STATUS_INT	ENDP

LINE_STATUS_INT	PROC	NEAR
	ADD	DL,COM_LSR-COM_IIR
	IN	AL,DX
	RET
LINE_STATUS_INT	ENDP

; Intercept for BIOS interrupt 14

INTERCEPT14	PROC	NEAR
	PUSHF
	OR	AH,AH			; BIOS function or ours?
	JNS	OUT14			; if not ours
	CMP	AH,8EH
	JBE	HIT			; it's ours

OUT14:	POPF
	DB	0EAH			; JMP FAR immediate opcode
EXINT14		DD	0		; ex-setting of interrupt 14

HIT:	POPF				; discard flags
	STI				; allow interrupts
	PUSH	BX			; save registers
	PUSH	CX
	PUSH	DX
	PUSH	BP
	PUSH	SI
	PUSH	DI
	PUSH	DS
	PUSH	ES
	PUSH	DS			; set ES to caller's segment
	POP	ES
	PUSH	CS			; set DS to this segment
	POP	DS
	CLD
	CALL	PROCESS			; do a function
	POP	ES
	POP	DS
	POP	DI
	POP	SI
	POP	BP
	POP	DX
	POP	CX
	POP	BX
	RETF	2
INTERCEPT14	ENDP

; Process a Couriers function

PROCESS	PROC	NEAR
	SUB	AH,129			; normalize the function code
	JGE	PRO1			; if function 81H or greater
	MOV	AH,232			; function 80H:  check that Couriers is loaded
	RET				; signal that Couriers is alive

PRO1:	DEC	AL			; convert port number from 1-4 to 0-3
	CMP	AL,4			; validate port number
	JB	PRO2			; if it's acceptable
	MOV	AH,-1			; else error return
	RET

PRO2:	PUSH	AX			; save function code
	MOV	DI,BX			; move any BX arg to DI
	MOV	BX,OFFSET PORT1		; point BX to COM_PORT table
	MOV	AH,COM_SIZE		; calcalute offset to one we need
	MUL	AH
	ADD	BX,AX			; BX -> appropriate COM table
	MOV	DX,[BX+COM_ADDRESS]	; DX = i/o address for port
	POP	AX			; AH = function code
	XOR	AL,AL
	XCHG	AH,AL			; AX = function code
	MOV	SI,OFFSET F_SWITCH	; switch to appropriate procedure
	ADD	SI,AX
	ADD	SI,AX
	JMP	[SI]	; with BX -> COM_PORT, DX = i/o address
PROCESS	ENDP

; Check if a port is in use

F_BUSY	PROC	NEAR	; BX -> port table, DX = port i/o address
	INC	DX			; DX -> Interrupt Enable Register
	IN	AL,DX
	MOV	AH,2
	CMP	AL,0EDH			; normal input for non-existent port
	JE	BUSY1
	DEC	AH			; AH = 1
	MOV	AH,[BX+COM_BIT]		; AH = IRQ bit
	IN	AL,21H			; get interrupt mask
	AND	AL,AH
	JZ	BUSY1			; if bit not set interrupt is enabled
	DEC	AH

BUSY1:	RET	; report in AH: 0 if port available, 1 if busy, 2 if dead
F_BUSY	ENDP

; Configure a port

F_CONFIGURE PROC NEAR	; BX -> port table, DX=i/o address, DI=speed, CX=options
	MOV	[BX+COM_OPTIONS],CX	; save options

	ADD	DL,COM_LCR		; DX -> Line-Control Register
	XOR	AX,AX
	OUT	DX,AL			; allow access to IER
	MOV	[BX+COM_FLAGS],AL	; clear all flags for the port
	MOV	[BX+COM_OUTFLOW],AL	; and outbound flow control field

	ADD	DL,COM_IER-COM_LCR	; DX -> Interrupt Enable Register
	OUT	DX,AL			; turn off all interrupts

	ADD	DL,COM_MCR-COM_IER	; DX -> Modem-Control Register
	MOV	AL,0BH			; set DTR, RTS and out2 to get ints
	OUT	DX,AL

	ADD	DL,COM_TXB-COM_MCR	; DX -> base i/o address
	MOV	AX,DI			; AX = speed
	CALL	SET_SPEED

	XOR	AX,AX			; set interrupt vector
	MOV	ES,AX
	MOV	AX,CS
	MOV	DI,[BX+COM_IVA]		; ES:DI -> interrupt vector
	CLI				; turn interrupts off
	MOV	ES:[DI+2],AX		; set new value in vector
	MOV	AX,[BX+COM_IH]
	MOV	ES:[DI],AX
	STI

	MOV	AH,[BX+COM_BIT]		; mask on interrupt at controller
	NOT	AH
	CLI
	IN	AL,21H
	AND	AL,AH
	OUT	21H,AL
	STI

	MOV	AX,CX			; AX = line settings
	ADD	DL,COM_LCR-COM_TXB	; DX -> Line-Control Register
	MOV	AL,03H			; select 8-bit characters
	OUT	DX,AL
	RET
F_CONFIGURE ENDP

; Start input

F_INPUT	PROC NEAR	; BX -> port table, DX = i/o address, ES:DI -> buffer,
			; CX = buffer size in bytes
	MOV	AX,ES			; set up input pointers
	MOV	[BX+COM_IN_SEG],AX
	MOV	[BX+COM_IN_FIRST],DI
	MOV	[BX+COM_RD_PTR],DI
	AND	CX,0FFFEH		; need even length
	ADD	DI,CX
	MOV	[BX+COM_IN_LIMIT],DI
	CALL	F_CLEAR_INPUT		; initialize the buffer to receive data
	SHR	CX,1			; convert byte count to word count
	MOV	AX,CX			; calculate thresholds for flow control
	SHR	AX,1
	MOV	[BX+COM_IN_LO],AX	; send Ctrl-Q when half empty
	SHR	AX,1
	SUB	CX,AX
	MOV	[BX+COM_IN_HI],CX	; send Ctrl-S when three-quarters full

	IN	AL,DX			; flush input from port
	IN	AL,DX
	INC	DX			; DX -> COM_IER
	IN	AL,DX			; read Interrupt Enable Register
	OR	AL,01H			; enable input-available interrupt
	JMP	$+2			; (this may be more than is needed)
	OUT	DX,AL
	RET
F_INPUT	ENDP

; Read a received character

F_READ	PROC	NEAR	; BX -> port table, DX = i/o address
	MOV	SI,[BX+COM_RD_PTR]
	CMP	SI,[BX+COM_IN_PTR]	; any input?
	JE	RD4			; no...

	CLI				; interrupts off
	DEC	[BX+COM_IN_CTR]		; decrement input counter
	TEST	[BX+COM_FLAGS],CF_ISF	; input flow-controlled off?
	JZ	RD2			; if not...
	MOV	AX,[BX+COM_IN_CTR]	; else see it it's time to resume
	CMP	AX,[BX+COM_IN_LO]
	JA	RD2			; not yet
	CALL	RESTART_INPUT

RD2:	STI				; interrupts back on
	MOV	AX,[BX+COM_IN_SEG]	; get buffer segment
	PUSH	DS
	MOV	DS,AX
	LODSW				; load character and status
	POP	DS
	CMP	SI,[BX+COM_IN_LIMIT]
	JNE	RD3
	MOV	SI,[BX+COM_IN_FIRST]

RD3:	MOV	[BX+COM_RD_PTR],SI
	OR	BX,BX			; reset ZF

RD4:	RET
F_READ	ENDP	; returns ZF = 1 if no input available
		;    else ZF = 0 and AX = input

; Flush pending input

F_CLEAR_INPUT PROC NEAR		; BX -> port table, DX = i/o address
	CLI				; interrupts off while messing with pointers
	MOV	SI,[BX+COM_RD_PTR]	; make IN equal OUT
	MOV	[BX+COM_IN_PTR],SI
	XOR	AX,AX
	MOV	[BX+COM_IN_CTR],AX	; zero the counter
	TEST	[BX+COM_FLAGS],CF_ISF	; input flow-controlled off?
	JZ	CI1			; if not...
	CALL	RESTART_INPUT		; send a Control-Q

CI1:	STI
	RET
F_CLEAR_INPUT ENDP

; Start output

F_OUTPUT PROC NEAR ; BX -> port table, DX = i/o address, ES:DI -> buffer,
		   ; CX = buffer size in bytes
	INC	DL			; DX -> Interrupt Enable Register
	CLI				; interrupts off
	IN	AL,DX
	AND	AL,0FDH			; reset transmit-interrupt enable
	JMP	SHORT $+2
	OUT	DX,AL
	STI				; interrupts on
	ADD	DL,COM_LSR-COM_IER	; DX -> Line Status Register

OUT1:	IN	AL,DX			; wait until transmitter is empty
	TEST	AL,40H
	JZ	OUT1

	CLI				; disallow interrupts
	MOV	[BX+COM_OUT_PTR],DI	; set output pointer
	ADD	DI,CX			; and limit pointer
	MOV	[BX+COM_OUT_LIMIT],DI
	MOV	AX,ES			; buffer assumed to be in one segment
	MOV	[BX+COM_OUT_SEG],AX

	TEST	[BX+COM_FLAGS],CF_OSF	; output flow control on?
	JNZ	OUT2			; if so then a ^Q will start it
	CALL	START_OUTPUT		; else start the transmitter

OUT2:	STI				; leave with interrupts on
	RET
F_OUTPUT ENDP

; Check status of output in progress

F_CHECK_OUTPUT PROC NEAR	; BX -> port table, DX = i/o address
	MOV	AX,[BX+COM_OUT_PTR]	; get output pointer
	TEST	AX,AX
	JZ	CHECK1			; if zero, output is done
	SUB	AX,[BX+COM_OUT_LIMIT]	; else calculate number of characters
	NEG	AX			;    still to go
	RET

CHECK1:	ADD	DX,COM_LSR - COM_TXB	; DX -> Line Status Register
	IN	AL,DX
	AND	AL,20H			; Tx Holding Register Empty?
	JNZ	CHECK2
	INC	AX			; still 1 en route thru COM
	RET

CHECK2:	XOR	AX,AX			; only return 0 if ready for more
	RET
F_CHECK_OUTPUT ENDP

; Abort output in progress

F_ABORT_OUTPUT PROC NEAR	; BX -> port table
	XOR	AX,AX
	MOV	[BX+COM_OUT_PTR],AX
	RET
F_ABORT_OUTPUT ENDP

; Single-character output

F_OUTCH	PROC	NEAR	; BX -> port table, CL = character to be sent
			; DX = i/o address
OC1:	ADD	DL,COM_LSR-COM_TXB	; DX -> Line Status Register

OC2:	IN	AL,DX			; wait until
	TEST	AL,20H			;    Transmitter Holding Register empty
	JZ	OC2

	ADD	DL,COM_TXB-COM_LSR	; DX -> Transmit Buffer
	MOV	AL,CL
	OUT	DX,AL			; transmit it

	XOR	CX,CX
	XCHG	[BX+COM_OUTFLOW],CL	; flow-control character waiting?
	TEST	CL,CL
	JNZ	OC1			; if so loop to send it
	RET
F_OUTCH	ENDP

; Transmit a BREAK

F_BREAK	PROC	NEAR		; BX -> port table, DX = i/o address
	ADD	DL,COM_LCR		; DX -> Line Control Register
	CLI				; interrupts off while changing LCR
	IN	AL,DX
	OR	AL,40H			; set BREAK
	JMP	SHORT $+2
	OUT	DX,AL
	STI
	MOV	CL,7			; send BREAK for approx 385 ms
	CALL	DELAY
	CLI
	IN	AL,DX
	XOR	AL,40H			; reset BREAK
	JMP	SHORT $+2
	OUT	DX,AL
	STI
	RET
F_BREAK	ENDP

; (Unused)

F_STATUS PROC	NEAR	; BX -> port table, DX = i/o address
	RET			; not sure we need this...
F_STATUS ENDP

; Set line speed

F_SPEED	PROC	NEAR	; BX -> port table, DX = i/o address, DI = speed
	MOV	AX,DI			; AX = speed
	CALL	SET_SPEED
	RET
F_SPEED	ENDP

; Deconfigure a port

F_DECONFIG PROC	NEAR	; BX -> port table, DX = i/o address
	MOV	AH,[BX+COM_BIT]
	CLI				; mask off interrupt at controller
	IN	AL,21H
	OR	AL,AH
	OUT	21H,AL
	STI

	ADD	DL,COM_LCR		; DX -> Line-Control Register
	XOR	AX,AX			; allow access to IER
	OUT	DX,AL

	ADD	DL,COM_IER-COM_LCR	; DX -> Interrupt Enable Register
	JMP	$+2
	OUT	DX,AL			; turn off all interrupts

	ADD	DL,COM_MCR-COM_IER	; DX -> Modem-Control Register
	JMP	$+2
	OUT	DX,AL			; turn off OUT2 and all modem controls
	RET
F_DECONFIG ENDP

; Wait for a given number of clock ticks

DELAY	PROC	NEAR	; CL = number of 18.2-to-a-second ticks to delay
	PUSH	DS
	XOR	AX,AX
	MOV	DS,AX			; DS = segment 0
	XOR	CH,CH

OS1:	CMP	AX,DS:[TIMER]		; check AX against system clock
	JE	OS1			; if the same then wait
	MOV	AX,DS:[TIMER]		; else AX = value of system clock
	LOOP	OS1			; decrement tick counter

	POP	DS
	RET
DELAY	ENDP

; Convert line speed from bits per second to divisor for COM port

GET_DIVISOR	PROC	NEAR	; AX = speed in bits per second
	OR	AX,AX			; special case of zero speed
	JNE	DIV1
	INC	AX			; really means 115,200 bps
	RET				; for which divisor is 1

DIV1:	PUSH	BX
	CMP	AX,600			; calculation break at 600 bps
	JB	DIV2			; if below 600
	PUSH	DX
	XOR	DX,DX
	MOV	BX,100
	DIV	BX			; divide speed by 100
	MOV	BX,AX
	MOV	AX,1152
	DIV	BX			; then divide (speed/100) into 1152
	POP	DX			; that gives the desired result
	POP	BX
	RET

DIV2:	MOV	BL,10			; divide the speed by 10
	DIV	BL
	MOV	BL,AL			; BL = speed/10
	MOV	AX,120
	DIV	BL			; divide that into 120
	MOV	BL,96			; BL = divisor for 1,200 bps
	MUL	BL			; this gives the desired result
	POP	BX
	RET
GET_DIVISOR	ENDP		; returns divisor in AX

; Send a Control-Q to restart input

RESTART_INPUT	PROC	NEAR	; BX -> port table, DX -> i/o address, Ints off
	AND	[BX+COM_FLAGS],NOT CF_ISF	; reset input-off flag
	ADD	DL,COM_LSR		; DX -> Line Status Register
	IN	AL,DX
	TEST	AL,20H			; transmit buffer empty?
	MOV	AL,CTRL_Q
	JZ	RI1			; no
	ADD	DL,COM_TXB-COM_LSR	; DX -> Transmit Buffer
	OUT	DX,AL
	XOR	AX,AX

RI1:	MOV	[BX+COM_OUTFLOW],AL
	RET
RESTART_INPUT	ENDP

; Set the line speed for a port

SET_SPEED	PROC	NEAR	; AX = speed in bps, DX = i/o address
	PUSH	DX
	CALL	GET_DIVISOR		; convert speed to divisor
	PUSH	AX
	ADD	DL,COM_LCR		; DX -> Line-Control Register
	IN	AL,DX			; AL = LCR setting
	OR	AL,80H			; set Divisor Latch Access bit
	JMP	$+2
	OUT	DX,AL
	POP	AX			; AX = divisor
	ADD	DL,COM_DLL-COM_LCR
	OUT	DX,AL
	INC	DX			; DX -> COM_DLM
	MOV	AL,AH
	OUT	DX,AL
	ADD	DL,COM_LCR-COM_DLM	; DX -> Line-Control Register
	JMP	$+2
	IN	AL,DX			; read LCR again
	AND	AL,07FH			; clear DLA bit
	JMP	$+2
	OUT	DX,AL
	POP	DX
	RET
SET_SPEED ENDP

; Start the COM Port transmitting and prime for transmit interrupts

START_OUTPUT	PROC	NEAR	; DX -> LSR, interrupts off
PRIME:	ADD	DL,COM_IER-COM_LSR	; DX -> Interrupt Enable Register
	IN	AL,DX
	AND	AL,0FDh			; disable transmit interrupts
	JMP	$+2
	OUT	DX,AL
	INC	DX			; DX -> Interrupt Identification Reg
	CALL	TX_INT			; dispatch the next character
	JC	EMPTY			; if there was nothing to transmit
	ADD	DL,COM_IER-COM_TXB	; DX -> Interrupt Enable Register
	IN	AL,DX
	OR	AL,2			; enable transmit interrupts
	JMP	$+2
	OUT	DX,AL
	ADD	DL,COM_LSR-COM_IER
	IN	AL,DX
	AND	AL,20H			; transmitter buffer still empty?
	JNZ	PRIME			; if so prime it again

EMPTY:	RET
START_OUTPUT	ENDP

THE_END	=	$			; end of resident code

; Startup

MAIN	PROC	NEAR
	MOV	AH,80H			; check if Couriers is already loaded
	INT	14H
	CMP	AH,232			; if it is it will return AH = 232
	JNE	LOAD
	LEA	DX,BADMSG		; complain
	MOV	AH,9H
	INT	21H
	XOR	AX,AX			; Couriers already loaded so exit
	INT	21H

LOAD:	MOV	AX,DS:[44]		; release copy of environment
	MOV	ES,AX
	MOV	AH,49H
	INT	21H
	LEA	DX,INITMSG		; announce program
	MOV	AH,9H
	INT	21H
	MOV	AX,3514H		; get BIOS serial-port services
	INT	21H			;	interrupt vector
	MOV	WORD PTR [EXINT14],BX	; save offset
	MOV	WORD PTR [EXINT14+2],ES	; and segment
	MOV	AX,2514H		; change vector for intercept
	LEA	DX,INTERCEPT14
	INT	21H
	MOV	DX,OFFSET THE_END + 15	; calculate paragraphs used
	MOV	CL,4
	SHR	DX,CL
	MOV	AX,3100H		; terminate but stay resident
	INT	21H

MAIN	ENDP

BADMSG	DB	'Couriers is already loaded$'

PSEG	ENDS
	END	ENTRY
