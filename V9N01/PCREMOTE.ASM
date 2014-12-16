	TITLE	PCREMOTE - Unattended Computer Access - 1989 by Terry Lahman
	PAGE	60,132
;======================================================================
;
;  PCREMOTE - An unattended computer access utility.  Allows access to an
;  unattended computer from a manned computer.	The unattended computer
;  executes the TSR portion of the program and waits for the manned
;  computer to call.  For use with text only programs.	Like using the
;  phone lines and modems as a long extension cord for your keyboard
;  and monitor.
;
;	Usage:	PCREMOTE [ /M ] [ /2 ] [ /F ] [ /D ]
;
;======================================================================
CSEG	SEGMENT PARA PUBLIC 'CODE'
	ASSUME	CS:CSEG,DS:NOTHING,ES:NOTHING,SS:NOTHING

BS		EQU	8
CR		EQU	13
LF		EQU	10
SPACE		EQU	32

;----------------------------------------------------------------------
;  Start of code
;----------------------------------------------------------------------
		ORG	100H			;Starting offset for .com
START:		JMP	INITIALIZE		;Jump over resident code

;----------------------------------------------------------------------
;  Data storage
;----------------------------------------------------------------------

COPYRIGHT	DB	"PCREMOTE Version 1.0 (c) 1989 Ziff Communications Co."
		DB	CR,LF,"PC Magazine ",254," by Terry Lahman",CR,LF,"$",26
CONNECT_FLAG	DB	0			;0=not connected
						;1=connected to manned system
ACT_FLAG	DB	0			;0=unattended prog not active
						;1=unattended program is active
						; do not run again
OLDINT_8	DW	0,0			;Old timer vector
MANNED_FLAG	DB	0			;0=Operate in unattended mode
						;1=Operate in manned mode
COMM_FLAG	DB	0			;0=Use comm1
						;1=Use comm2
COMM_PORT	DW	0			;Comm port address
COMM_INT_STA	DB	0			;Comm port interrupt status
						;0=not transmitting data
						;1=transmitting data
SPEED_FLAG	DB	0			;0=Use 1200 baud
						;1=Use 2400 baud
DESNOW_FLAG	DB	0			;0=Do not use desnow code
						;1=Use desnow code
VIDEO_COPY	DW	0			;Address of video ram copy
VIDEO_SEGMENT	DW	0			;Segment register for vid ram
SHIFT_STATUS	DB	0			;Current status of shift byte
STACK_TOP	DW	INITIALIZE+256D 	;Top of stack for unattended
OLD_SS		DW	0			;Old stack segment
OLD_SP		DW	0			;Old stack pointer
TEMP_REG	DW	0			;Temp storage for register
CURSOR_POSITION DW	0			;Old cursor position
VID_RAM_OFFSET	DW	0			;Current compare offset
ASCII_FLAG	DB	0			;0=no data is pending
						;1=received a FE
						;2=received ASCII char
						;4=received scan code
SHIFT_FLAG	DB	0			;0=no data is pending
						;1=received a FD
KEY_ONE 	DB	0			;ASCII char received
KEY_TWO 	DB	0			;Scan code received
BAUD_RATE	DB	0,60H			;1200 BAUD divisor MSB LSB
		DB	0,30H			;2400 BAUD divisor MSB LSB
IN_BUFF_SIZE	EQU	512D			;Size for input buffer
OUT_BUFF_SIZE	EQU	512D			;Size for output buffer
IN_BUFF_HEAD	DW	?			;Pointer to input buffer head
IN_BUFF_TAIL	DW	?			;Pointer to input buffer tail
IN_BUFF_BEGIN	DW	?			;Pointer to input buffer begin
IN_BUFF_END	DW	?			;Pointer to input buffer end
OUT_BUFF_HEAD	DW	?			;Pointer to output buffer head
OUT_BUFF_TAIL	DW	?			;Pointer to output buffer tail
OUT_BUFF_BEGIN	DW	?			;Pointer to output buffer begin
OUT_BUFF_END	DW	?			;Pointer to output buffer end
BLOCK_SIZE	EQU	16D			;Block transfer size in words
BLOCK_SIZEX2	EQU	BLOCK_SIZE*2		;Block transfer size in bytes
BLOCK_COUNT	DB	?			;Block number being processed
BLOCK_POINTER	DW	0			;Points to current video block
TEMP_VIDEO_PTR	DW	?			;Pointer to temp video storage
CR_COUNT	DB	?			;Number of CRs for speed sync
MODEM_ATTENTION DB	CR,"AT",CR,0
MODEM_SETUP1	DB	"ATE0 S12=40 Q0 V0 X1 S0=0",CR,0 ;Manned
MODEM_SETUP2	DB	"ATE0 S12=40 Q1S0=2",CR,0 ;Unattended
MODEM_SETUP3	DB	"AT&C1",CR,0		;Enable DCD on 2400 baud modem
MODEM_HANGUP	DB	"ATH0",CR,0
MODEM_ESCAPE	DB	"+++",0
TONE_DIAL	DB	"ATDT",0		;Tone dial command
PASS_MESSAGE	DB	"Enter password:",0	;Enter password message
PASSWORD_SIZE	DW	EXTRA_PW_SPACE-PASSWORD
PASSWORD	DB	"PC MAGAZINE"
EXTRA_PW_SPACE	DB	20-(EXTRA_PW_SPACE-PASSWORD) DUP(?)
PASSWORD_BUFFER DB	20 DUP(?)
EXIT_CODE	DB	0,45D			;alt-x, code to exit program

;======================================================================
;  Interrupt handlers.  Interrupt 8 is used in unattended mode only.
;  The communications interrupt is used in both modes.
;======================================================================
;----------------------------------------------------------------------
;  Interrupt 8 handling routine.  If program is already active do not run.
;  Run connect unattended if not connected, otherwise run unattended.
;----------------------------------------------------------------------
INT8		PROC	NEAR
		ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		PUSH	DS			;Save data segment
		PUSH	CS			;Set data segment to code seg
		POP	DS
		PUSHF				;Call old int 8
		CALL	DWORD PTR OLDINT_8
I8_10:
		CLI				;Disable interrupts
		CMP	BYTE PTR ACT_FLAG,0	;Check for program active
		JNZ	I8_EXIT			;Exit if progam is active
		INC	BYTE PTR ACT_FLAG	;Set program active flag
		STI				;Enable interrupts
		CALL	SET_STACK		;Create stack & save registers
		CMP	BYTE PTR CONNECT_FLAG,0 ;Connected to manned?
		JNZ	I8_20			;Yes, then run unattended
		CALL	CONNECT_UNATTENDED	;No, check for connection
		JMP	I8_30
I8_20:
		CALL	UNATTENDED		;Run unattended
I8_30:
		CALL	RESET_STACK		;Restore registers & stack
		DEC	BYTE PTR ACT_FLAG	;Clear program active flag
I8_EXIT:
		STI				;Enable interrupts
		POP	DS			;Restore data segment
		IRET
INT8		ENDP

;----------------------------------------------------------------------
;  Interrupt handling routine for communications interrupt.  Provides
;  interrupt driven I/O.  Transmit or receive a character.
;----------------------------------------------------------------------
INT_COMM	PROC	NEAR
		ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		PUSH	DS			;Save data segment
		PUSH	DX			;Save registers
		PUSH	BX
		PUSH	AX
		PUSH	CS			;Set data segment to code seg.
		POP	DS
		MOV	DX,COMM_PORT		;Get port base address
		INC	DX			;Point to int. id reg.
		INC	DX
		IN	AL,DX			;Get the interrupt id byte
IC_10:
		CMP	AL,2			;Transmit empty int?
		JZ	IC_40			;Yes transmit a byte
;
;	received data, get it and store in buffer
;
		DEC	DX			;Port base address
		DEC	DX
		IN	AL,DX			;Get data from receive register
		MOV	BX,IN_BUFF_TAIL		;Get the buffer tail pointer
		MOV	[BX],AL 		;Store the data in buffer
		INC	BX			;Point to next data storage
		CMP	IN_BUFF_END,BX		;Beyond end of buffer area?
		JNE	IC_20			;No, then don't reset
		MOV	BX,IN_BUFF_BEGIN	;Yes, reset to buffer begin
IC_20:
		CMP	BX,IN_BUFF_HEAD		;Test for buffer full
		JE	IC_30	 		;If so,don't change ptr ,sorry
		MOV	IN_BUFF_TAIL,BX		;Save new tail pointer
IC_30:
		JMP	IC_70
;
;	transmit buffer empty, send a byte
;
IC_40:
		DEC	DX			;Port base address
		DEC	DX
		MOV	BX,OUT_BUFF_HEAD	;Get the buffer head pointer
		CMP	BX,OUT_BUFF_TAIL	;Test for data in buffer
		JE	IC_60	 		;If the same, no data so exit
		MOV	AL,[BX] 		;Get the data
		INC	BX			;Point to next data in buffer
		CMP	OUT_BUFF_END,BX		;Beyond end of buffer area?
		JNE	IC_50			;No, then don't reset
		MOV	BX,OUT_BUFF_BEGIN	;Yes, reset to buffer begin
IC_50:
		MOV	OUT_BUFF_HEAD,BX 	;Save new head pointer
		OUT	DX,AL			;Send the data out the port
		JMP	IC_70			;Check for request pending
IC_60:
		MOV	BYTE PTR COMM_INT_STA,0	;Reset transmitting data flag
IC_70:
		INC	DX			;Point to int. id reg.
		INC	DX
		IN	AL,DX			;Get the interrupt id byte
		TEST	AL,1			;Request pending?
		JZ	IC_10			;Yes, then process
IC_EXIT:
		MOV	AL,20H			;Reset 8259
		OUT	20H,AL
		STI				;Enable interrupts
		POP	AX			;Restore registers
		POP	BX
		POP	DX
		POP	DS			;Restore data segment
		IRET
INT_COMM	ENDP

;----------------------------------------------------------------------
;  Create stack area and save all registers.
;----------------------------------------------------------------------
SET_STACK	PROC	NEAR
		ASSUME	CS:CSEG,DS:NOTHING,ES:NOTHING,SS:NOTHING
		MOV	TEMP_REG,BX		;Save BX
		POP	BX			;Save the return address
		PUSH	AX			;Save AX
;
;	make my own stack
;
		CLI				;Disable interrupts
		MOV	AX,SS			;Put old stack segment in AX
		MOV	OLD_SS,AX		;And save it
		MOV	AX,SP			;Put old stack pointer in AX
		MOV	OLD_SP,AX		;And save it
		MOV	AX,CS			;Get current segment
		MOV	SS,AX			;And put into stack segment
		MOV	AX,STACK_TOP 		;Get top of stack address
		MOV	SP,AX			;And put into stack pointer
		STI				;Enable interrupts
;
;	save all the registers on the stack
;
		PUSH	CX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	DS
		PUSH	ES
		PUSH	BP
		MOV	AX,CS			;Get code segment
		MOV	DS,AX			;Set data segment to code seg
		MOV	ES,AX			;Set extra seg to code seg
		PUSH	BX			;Restore return address
		RET
SET_STACK	ENDP

;----------------------------------------------------------------------
;  Restore all registers and reset stack
;----------------------------------------------------------------------
RESET_STACK	PROC	NEAR
		ASSUME	CS:CSEG,DS:NOTHING,ES:NOTHING,SS:NOTHING
		POP	BX			;Save return address
;
;	restore the registers
;
		POP	BP			;Restore the registers
		POP	ES
		POP	DS
		POP	DI
		POP	SI
		POP	DX
		POP	CX
;
;	restore the original stack
;
		CLI				;Disable interrupts
		MOV	AX,OLD_SP		;Get old stack pointer
		MOV	SP,AX			;And restore it
		MOV	AX,OLD_SS		;Get old stack segment
		MOV	SS,AX			;And restore it
		STI				;Enable interrupts
		POP	AX			;Restore AX
		PUSH	BX			;Put return add back on stack
		MOV	BX,TEMP_REG		;Restore BX

		RET
RESET_STACK	ENDP

;======================================================================
;  The unattended routine will execute the connect routine to establish
;  a connection with the manned system.  Once connected it will execute 
;  the unattended routine to process incoming data and send any changed
;  video data to the manned system.
;======================================================================

;----------------------------------------------------------------------
;  CONNECT_UNATTENDED - Check for ring codes, answer the phone and check
;  the password.  If correct, set connected flag.
;----------------------------------------------------------------------
CONNECT_UNATTENDED PROC    NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:CSEG,SS:NOTHING
		MOV	BP,SP			;Save stack pointer for exit
		CALL	CHECK_CARRIER		;Test for carrier present
		JNZ	CU_10			;Yes then check baud rate
		JMP	CU_EXIT 		;No, then exit routine
CU_10:
		CALL	CLEAR_INBUFF		;Clear the input buffer
		XOR	AH,AH			;Use input buffer
		MOV	CX,10D			;Number of char to check for CR
		MOV	BYTE PTR CR_COUNT,5	;Number of matches required
CU_20:
		CALL	CHECK_CARRIER		;Check for carrier loss
		JNZ	CU_30
		JMP	IP_50			;Carrier loss, reset and exit
CU_30:
		CALL	GET_BUFF_DATA		;Try to get data from buffer
		JNC	CU_20			;Wait till their is data
		CMP	AL,CR			;Check for CR code
		JNZ	CU_40			;No so skip over
		DEC	BYTE PTR CR_COUNT	;Found a match dec count
		JZ	CU_50			;5 out of ten then 2400 baud
CU_40:
		LOOP	CU_20			;Keep trying
		XOR	AL,AL			;No 5 out of 10, try 1200 baud
		CALL	SET_BAUD_RATE
		JMP	CU_10			;Now wait for CR at 1200 baud
CU_50:
		MOV	BYTE PTR CONNECT_FLAG,1 ;Set connect flag
		MOV	CX,3			;3 tries to enter password
CU_60:
		MOV	SI,OFFSET PASS_MESSAGE	;Point to enter password mess.
		CALL	LOAD_ZSTRING		;Load it into output buffer
		CALL	GET_PASSWORD		;Get the password
		CALL	CHECK_PASSWORD		;Check the password sent
		JZ	CU_70	 		;Jump if correct
		LOOP	CU_60			;Keep trying
		MOV	AL,1			;Use setup string 2
		CALL	RESET_MODEM		;Hangup and reset modem
		JMP	CU_EXIT			;Done, so exit
CU_70:
		MOV	AH,1			;Use output buffer
		XOR	AL,AL			;Sync byte to send
		MOV	CX,5			;Send 5 of them
CU_80:
		CALL	PUT_BUFF_DATA		;Send them
		LOOP	CU_80
CU_EXIT:
		RET
CONNECT_UNATTENDED ENDP

;----------------------------------------------------------------------
;  Get the password from the manned system
;  Input - Nothing
;  Output - Password buffer contains password from manned system
;  Changes - DI, AX
;----------------------------------------------------------------------
GET_PASSWORD	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:CSEG,SS:NOTHING
		PUSH	CX			  ;Save register
		MOV	DI,OFFSET PASSWORD_BUFFER ;Point to password buffer
		MOV	CX,20D			  ;Zero buffer to clear previous
		XOR	AL,AL			  ; password
		CLD
		REP	STOSB
		MOV	DI,OFFSET PASSWORD_BUFFER ;Pointer to buffer
		MOV	CX,20D			  ;Maximum password size
GP_10:
		CALL	CHECK_CARRIER		;Check for carrier loss
		JNZ	GP_20
		JMP	IP_50			;Carrier loss, reset and exit
GP_20:
		CALL	INPUT_PROCESSING	;Get data & put in keybd buffer
		CALL	GET_KEYSTROKE		;Check for keystroke
		JZ	GP_10			;None, so wait
		CMP	AL,60H			;Check for lower case
		JL	GP_30			;No then leave it alone
		AND	AL,5FH			;Convert to upper case
GP_30:
		CMP	AL,CR			;If it is a CR then exit
		JZ	GP_EXIT
		CMP	AL,BS			;Is it a back space?
		JNZ	GP_40			;No, so save it
		INC	CX			  ;Resetcounter for BS
		CMP	DI,OFFSET PASSWORD_BUFFER ;Already at start of buffer?
		JZ	GP_60			  ;Yes, then don't backspace
		DEC	DI			;Backspace buffer pointer
		MOV	BYTE PTR [DI],0		; and null the data
		JMP	GP_50
GP_40:
		CLD				;Forward
		STOSB				;Save the character
		MOV	AL,'*'			;Echo character
GP_50:
		MOV	AH,1			;Use output buffer
		CALL	PUT_BUFF_DATA		; and store the character
GP_60:
		LOOP	GP_10			;Receive up to CX characters
GP_EXIT:
		POP	CX			;Restore register
		RET
GET_PASSWORD	ENDP

;----------------------------------------------------------------------
;  Check the password in the buffer with correct password
;  Input - Nothing
;  Output - Zero set - correct password
;	    Zero reset - Wrong password
;  Changes - SI, DI
;----------------------------------------------------------------------
CHECK_PASSWORD	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:CSEG,SS:NOTHING
		PUSH	CX			  ;Save register
		MOV	SI,OFFSET PASSWORD_BUFFER ;Pointer to buffer
		MOV	DI,OFFSET PASSWORD	  ;Pointer to password
		MOV	CX,PASSWORD_SIZE	;Number of compares to make
		CLD				;Compare forward
		REPZ	CMPSB			;Repeat while passwords match
		POP	CX			;Restore register
		RET
CHECK_PASSWORD	ENDP

;----------------------------------------------------------------------
;  UNATTENDED - Process incoming data and check for changes in video 
;  data, format and send to manned system.  Maintains 18 or less characters
;  in output buffer, ensures maximum throughput.
;----------------------------------------------------------------------
UNATTENDED	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:CSEG,SS:NOTHING
		MOV	BP,SP			;Save stack pointer for exit
		CALL	INPUT_PROCESSING	;Process any buffered data
		MOV	AX,OUT_BUFF_HEAD	;Get the head pointer
		MOV	BX,OUT_BUFF_TAIL	;Get the tail pointer
		MOV	CX,18D			;Check for bytes in buffer
UA_10:
		CMP	AX,BX			;Less than 18 bytes in buffer
		JZ	UA_30			;Yes, then compare video
		INC	AX			;Increment head pointer
		CMP	OUT_BUFF_END,AX		;Beyond end of buffer area?
		JNE	UA_20			;No, then don't reset
		MOV	AX,OUT_BUFF_BEGIN	;Yes, reset to buffer begin
UA_20:
		LOOP	UA_10			;Check all 18 bytes
		JMP	UA_EXIT			;More than 18, exit
UA_30:
		MOV	VID_RAM_OFFSET,0	;Start at address 0
		MOV	BYTE PTR BLOCK_COUNT,0	;Reset block counter
;
;	compare the video copy with the video ram
;
UA_40:
		PUSH	DS			;Save data segment
		MOV	SI,VID_RAM_OFFSET	;Get the current offset
		MOV	DI,TEMP_VIDEO_PTR	;Dest. ES:DI temp video buffer
		MOV	AX,VIDEO_SEGMENT	;Get video Segment register
		MOV	DS,AX			;Source DS:SI video RAM
;
;	transfer block_size words of data from video RAM to the temp buffer
;
		MOV	CX,BLOCK_SIZE		;Get count of words to transfer
		CLD
		CMP	BYTE PTR CS:DESNOW_FLAG,0 ;Check desnow flag
		JZ	UA_70
		SAL	CX,1			;Convert words to bytes
		MOV	DX,3DAH			;CGA status port
UA_50:
		IN	AL,DX			;Get status byte
		TEST	AL,1			;Test display enable
		JNZ	UA_50			;If in Hor. sync then wait
		CLI				;Disable interrupts
UA_60:
		IN	AL,DX			;Get status byte
		TEST	AL,1			;Test display enable
		JZ	UA_60			;Wait for Hor. sync
		MOVSB				;Transfer one byte
		STI				;Enable interrupts
		LOOP	UA_50			;Transfer block size words
		JMP	UA_80
UA_70:
		REP	MOVSW
UA_80:
		POP	DS			;Restore data segment
;
;	compare the block from video RAM with the video copy
;
		MOV	CX,BLOCK_SIZEX2 	;Number of words to compare
		MOV	SI,TEMP_VIDEO_PTR	;Point to block of video data
		MOV	DI,VIDEO_COPY		;Point to video copy
		ADD	DI,VID_RAM_OFFSET	;Adjust for current block
		REPE	CMPSB			;Compare while equal
		JNE	UA_90			;No match, format & send block
		MOV	AX,VID_RAM_OFFSET	;Get current block pointer
		ADD	AX,BLOCK_SIZEX2 	;Point to next block
		MOV	VID_RAM_OFFSET,AX	;And save the pointer
		INC	BYTE PTR BLOCK_COUNT	;Increment current block count
		CMP	AX,4000D		;Check for end of video RAM
		JNZ	UA_40			;No, keep checking the RAM
		MOV	VID_RAM_OFFSET,0	;Yes, reset to begin of video
		JMP	UA_100			;Check for change in cursor
;
;	data doesn't match, format and send to manned system
;
UA_90:
		INC	CX			;Adjust count
		AND	CX,1			;LSB indicates char or attr.
		CALL	TRANSFER_BLOCK		;Prepare to send block of data
;
;	Check for a change in the cursor position
;
UA_100:
		MOV	AX,40H			;Set ES to BIOS data segment
		MOV	ES,AX
		MOV	BX,ES:[50H]		;Get current cursor position
		CMP	BX,CURSOR_POSITION	;Compare with copy
		JZ	UA_EXIT			;No change, skip
		MOV	CURSOR_POSITION,BX	;Save new cursor position
		MOV	AL,0D2H 		;Sync bits, set position
		MOV	AH,1			;Use output buffer
		CALL	PUT_BUFF_DATA		;Send sync byte
		MOV	AL,BL			;Low byte
		CALL	PUT_BUFF_DATA
		MOV	AL,BH			;High byte
		CALL	PUT_BUFF_DATA
UA_EXIT:
		RET
UNATTENDED	ENDP

;----------------------------------------------------------------------
;  Get data from the unattended input buffer and process
;  Input - Nothing
;  Output - Keyboard buffer or shift status is updated
;  Changes - Nothing
;----------------------------------------------------------------------
INPUT_PROCESSING PROC	 NEAR
		PUSH	AX			;Save register
		PUSH	DX
		PUSH	ES
		MOV	AX,40H			;Set ES to BIOS data area
		MOV	ES,AX
IP_10:
		CMP	BYTE PTR CONNECT_FLAG,0 ;Are we connected
		JZ	IP_20			;No, don't check carrier
		CALL	CHECK_CARRIER		;Yes check for carrier loss
		JZ	IP_50			;Carrier loss, reset and exit
IP_20:
		MOV	AH,0			;Use input buffer
		CALL	GET_BUFF_DATA		;Get a byte of data
		JC	IP_30			;If data then process
		JMP	IP_EXIT			;Otherwise exit
;
;	Check to see if expecting ASCII data
;
IP_30:
		CMP	ASCII_FLAG,0		;Check ASCII flag
		JZ	IP_70			;0=not expecting data here
		CMP	ASCII_FLAG,1		;Check for received 1st byte
		JNZ	IP_40			;Jump if second byte
		MOV	KEY_ONE,AL		;Save scan code, byte one
		INC	BYTE PTR ASCII_FLAG	;Indicate receiving one byte
		JMP	IP_10			;Process next byte
IP_40:
		MOV	KEY_TWO,AL		;Save ASCII code, byte two
		MOV	AL,KEY_ONE		;Get ASCII code
		MOV	AH,KEY_TWO		;Get scan code
		CMP	AX,WORD PTR EXIT_CODE	;Check for exit code
		JNZ	IP_60			;No,then continue processing
IP_50:						;Otherwise reset connect & exit
		CALL	CLEAR_INBUFF		;Clear input buffer
		CALL	CLEAR_OUTBUFF		;Clear output buffer
		MOV	BYTE PTR COMM_INT_STA,0	;Reset transmitting data flag
		CALL	IU_10			;reinit and reset modem
		CLI				;Disable interrupts
		MOV	BYTE PTR CONNECT_FLAG,0 ;Reset the connect flag
		MOV	BYTE PTR ASCII_FLAG,0	;Reset ASCII flag
		MOV	BYTE PTR SHIFT_FLAG,0	;Reset shift flag
		MOV	BYTE PTR ES:[17H],0	;Reset any shift status
		MOV	SP,BP			;Clean the stack
		RET		 		;And exit unattended routine
IP_60:
		CALL	PUT_KEY_DATA		;And stuff in keyboard buffer
		MOV	BYTE PTR ASCII_FLAG,0	;Reset ASCII flag for next data
		JMP	IP_10			;Process next byte
;
;	Check to see if expecting shift data
;
IP_70:
		CMP	BYTE PTR SHIFT_FLAG,0	;Check shift flag
		JZ	IP_80			;0=not expecting data here
		MOV	ES:[17H],AL		;And save in shift status
		MOV	BYTE PTR SHIFT_FLAG,0	;Reset shift flag for next data
		JMP	IP_10			;Process next byte
;
;	Check to see if it's a sync byte
;
IP_80:
		CMP	AL,0FEH 		;Check for ASCII sync byte
		JNZ	IP_90			;If not then check for shift
		INC	BYTE PTR ASCII_FLAG	;Indicate received FEh
		JMP	IP_10			;Process next byte
IP_90:
		CMP	AL,0FDH 		;Check for shift sync byte
		JNZ	IP_100			;If not then throw away
		INC	BYTE PTR SHIFT_FLAG	;Indicate received FDh
IP_100:
		JMP	IP_10			;Process till buffer empty
IP_EXIT:
		POP	ES			;Restore registers
		POP	DX
		POP	AX
		RET
INPUT_PROCESSING ENDP

;----------------------------------------------------------------------
;  Formats the data in temporary video buffer and puts it into the
;  output buffer
;  Input - CX=0 Transfer character data to output buffer
;	   CX=1 Transfer attribute data to output buffer
;  Output - Nothing
;  Changes - AX, BX, CX, SI, DI
;----------------------------------------------------------------------
TRANSFER_BLOCK	PROC	NEAR
		OR	CX,CX			;Set flags
		JZ	TB_10			;Jump if character data
		MOV	AL,0FFH 		;Sync byte for attr. data
		JMP	TB_20
TB_10:
		MOV	AL,0FEH 		;Sync byte for char. data
TB_20:
		MOV	AH,1			;Use output buffer
		CALL	PUT_BUFF_DATA		;Put sync byte in output buff.
		MOV	AL,BLOCK_COUNT
		MOV	AH,1			;Use output buffer
		CALL	PUT_BUFF_DATA		;Send the block number
		MOV	SI,TEMP_VIDEO_PTR	;Point to block of video data
		ADD	SI,CX			;Adjust for char. or attr.
		MOV	DI,VIDEO_COPY		;Point to video copy
		ADD	DI,VID_RAM_OFFSET	;Adjust for block offset
		ADD	DI,CX			; and character or attribute
		MOV	CX,BLOCK_SIZE		;Number of bytes to send
		CLD				;Forward direction
TB_30:
		LODSW				;Get the unmatched data
		MOV	AH,1			;Use the output buffer
		CALL	PUT_BUFF_DATA		;Put the video data in out buff
		STOSB				;Save video data in copy
		INC	DI			;Adjust for word offset
		LOOP	TB_30			;Send block size bytes of data
		RET
TRANSFER_BLOCK	ENDP

;----------------------------------------------------------------------
;  Put a byte of data into the unattended keyboard buffer.
;  Input - AL contains ASCII to be put into buffer.
;	   AH contains scan code to be put into buffer.
;  Output - Carry Set - Byte placed in buffer successfully
;	    Carry Reset - Buffer full, byte not stored in buffer
;  Changes - Nothing
;----------------------------------------------------------------------
PUT_KEY_DATA	PROC	NEAR
		PUSH	BX			;Save registers
		PUSH	SI
		PUSH	DI
		MOV	SI,1AH			;Point to keyboard head pointer
		CLI				;Don't allow interrupts
		MOV	BX,ES:[1CH]		;Get the buffer tail pointer
		MOV	DI,BX			;Save the tail pointer
		INC	BX			;Point to next data storage
		INC	BX
		CMP	BX,3EH			;Beyond end of buffer area?
		JNE	PK_10			;No, then don't reset
		MOV	BX,1EH			;Yes, reset to buffer begin
PK_10:
		CMP	BX,ES:[1AH]		;Test for buffer full
		JE	PK_EXIT 		;If the same, don't save it
						; exit, carry is already reset
		MOV	ES:[DI],AX		;Store the data in buffer
		MOV	ES:[1CH],BX		;Save new tail pointer
		STC				;Indicate data stored OK
PK_EXIT:
		POP	DI
		POP	SI
		POP	BX
		STI				;Enable interrupts
		RET
PUT_KEY_DATA   ENDP

;======================================================================
;  COMMON ROUTINES - These routines are common to both the unattended
;  processing portion of the program and the manned processing portion.
;======================================================================

;----------------------------------------------------------------------
;  Get a byte of data from a buffer.  Byte pointed to by head pointer is
;  is next data byte.  If head=tail, no data in buffer.
;  Input - AH - Buffer to use 0=Input buffer, 1=Output buffer.
;  Output - Carry Set - Byte from buffer is in AL
;	    Carry Reset - No data in buffer
;  Changes - AL
;----------------------------------------------------------------------
GET_BUFF_DATA	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		PUSH	BX			;Save registers
		PUSH	SI
		CMP	AH,0			;Check which buffer to use
		JNZ	GD_10			;Jump for output buffer
		MOV	SI,OFFSET IN_BUFF_HEAD	;Point to input buffer
		JMP	GD_20			;Skip over out buffer
GD_10:
		MOV	SI,OFFSET OUT_BUFF_HEAD ;Point to output buffer
GD_20:
		CLI				;Don't allow interrupts
		MOV	BX,[SI] 		;Get the buffer head pointer
		CMP	BX,2[SI]		;Test for data in buffer
		JE	GD_EXIT 		;If the same, no data so
						; exit, carry is already reset
		MOV	AL,[BX] 		;Get the data
		INC	BX			;Point to data in buffer
		CMP	6[SI],BX		;Beyond end of buffer area?
		JNE	GD_30			;No, then don't reset
		MOV	BX,4[SI]		;Yes, reset to buffer begin
GD_30:
		MOV	[SI],BX 		;Save new head pointer
		STC				;Indicate data is in AL
GD_EXIT:
		POP	SI			;Restore registers
		POP	BX
		STI				;Enable interrupts
		RET
GET_BUFF_DATA	ENDP

;----------------------------------------------------------------------
;  Put a byte of data into a buffer.  Byte is stored at location
;  pointed to by tail pointer.
;  Input - AL contains data to be put into buffer.
;	   AH - Buffer to use 0=Input buffer, 1=Output buffer
;  Output - Carry Set - byte placed in buffer successfully
;	    Carry Reset - Buffer full, byte not stored in buffer
;  Changes - Nothing
;----------------------------------------------------------------------
PUT_BUFF_DATA	PROC	NEAR
		ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		PUSH	AX			;Save registers
		PUSH	BX
		PUSH	DX
		PUSH	SI
		PUSH	DI
		PUSH	DS
		PUSH	CS			;Set data segment to CS
		POP	DS
		CMP	AH,0			;Check which buffer to use
		JNZ	PD_10			;Jump for output buffer
		MOV	SI,OFFSET IN_BUFF_HEAD	;Point to input buffer
		JMP	PD_20			;Skip over out buffer
PD_10:
		MOV	SI,OFFSET OUT_BUFF_HEAD ;Point to output buffer
PD_20:
		CLI				;Don't allow interrupts
		MOV	BX,2[SI]		;Get the buffer tail pointer
		MOV	DI,BX			;Save the tail pointer
		INC	BX			;Point to next data storage
		CMP	6[SI],BX		;Beyond end of buffer area?
		JNE	PD_30			;No, then don't reset
		MOV	BX,4[SI]		;Yes, reset to buffer begin
PD_30:
		CMP	BX,[SI] 		;Test for buffer full
		JE	PD_40	 		;If so, exit carry is reset

		MOV	[DI],AL 		;Store the data in buffer
		MOV	2[SI],BX		;Save new tail pointer
		STC				;Indicate data stored ok
PD_40:
		PUSHF				;Save the flags
		CMP	BYTE PTR COMM_INT_STA,0	;Transmit int. running?
		JNZ	PD_50			;Yes, so exit
		MOV	AX,OUT_BUFF_HEAD	;Is data in output buffer
		CMP	AX,OUT_BUFF_TAIL
		JZ	PD_50			;No, so exit
		MOV	BYTE PTR COMM_INT_STA,1	;Set transmitting data flag
		MOV	AH,1			;Use the output buffer
		CALL	GET_BUFF_DATA		;Get data from output buffer
		MOV	DX,COMM_PORT		;Get port base address
		OUT	DX,AL			;Send the data out the port
PD_50:
		STI				;Enable interrupts
		POPF				;Restore flags
		POP	DS			;Restore registers
		POP	DI
		POP	SI
		POP	DX
		POP	BX
		POP	AX
		RET
PUT_BUFF_DATA	ENDP

;----------------------------------------------------------------------
;  Clear the input buffer
;  Input - Nothing
;  Output - Nothing
;  Changes - Nothing
;----------------------------------------------------------------------
CLEAR_INBUFF	PROC	NEAR
		ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		PUSH	AX			;Save register
		CLI				;Disable interrupts
		MOV	AX,IN_BUFF_TAIL		;Get buffer tail pointer
		MOV	IN_BUFF_HEAD,AX		;Make head equal tail
		STI				;Enable interrupts
		POP	AX
		RET
CLEAR_INBUFF	ENDP

;----------------------------------------------------------------------
;  Clear the output buffer
;  Input - Nothing
;  Output - Nothing
;  Changes - Nothing
;----------------------------------------------------------------------
CLEAR_OUTBUFF	PROC	NEAR
		ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		PUSH	AX			;Save register
		CLI				;Disable interrupts
		MOV	AX,OUT_BUFF_TAIL	;Get buffer tail pointer
		MOV	OUT_BUFF_HEAD,AX	;Make head equal tail
		STI				;Enable interrupts
		POP	AX
		RET
CLEAR_OUTBUFF	ENDP

;----------------------------------------------------------------------
;  Reset the modem and send the setup string to initialize
;  Input - AL - 0 use setup string 1, 1 use setup string 2
;  Output - Nothing
;  Changes - Nothing
;----------------------------------------------------------------------
RESET_MODEM	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		PUSH	SI			;Save registers
		PUSH	DX
		PUSH	AX
		CMP	BYTE PTR CONNECT_FLAG,0 ;Is modem connected?
		JZ	RM_20			;No then send setup only
		CALL	CLEAR_OUTBUFF		;Empty the output buffer
		MOV	BYTE PTR CONNECT_FLAG,0 ;Reset connect flag
		MOV	AL,1			;Wait a second for guard time
		CALL	DELAY
		MOV	SI,OFFSET MODEM_ESCAPE	;Send modem escape code
		CALL	LOAD_ZSTRING
		MOV	AL,2			;Wait
		CALL	DELAY
		MOV	SI,OFFSET MODEM_HANGUP	;Send modem hangup code
		CALL	LOAD_ZSTRING
		MOV	AL,1			;Wait for a second
		CALL	DELAY
RM_20:
		MOV	AL,SPEED_FLAG		;Get speed flag
		CALL	SET_BAUD_RATE
		MOV	SI,OFFSET MODEM_ATTENTION ;Point to modem attention
		CALL	LOAD_ZSTRING		  ;Put it into output buffer
		MOV	AL,1			;Wait for a second
		CALL	DELAY
		POP	AX			;Get setup string to use
		CMP	AL,0			;Test for string 1
		JNZ	RM_30			;No, then use string 2
		MOV	SI,OFFSET MODEM_SETUP1	;Point to modem setup string 1
		JMP	RM_40
RM_30:
		MOV	SI,OFFSET MODEM_SETUP2	;Point to modem setup string 2
RM_40:
		CALL	LOAD_ZSTRING		;Load setup string to modem
		MOV	AL,1			;Wait a second
		CALL	DELAY
		MOV	SI,OFFSET MODEM_SETUP3	;Point to modem setup string 3
		CALL	LOAD_ZSTRING		;Load setup string to modem
		CALL	CLEAR_INBUFF		;Clear the input buffer
		POP	DX			;Restore registers
		POP	SI
		RET
RESET_MODEM	ENDP

;----------------------------------------------------------------------
;  Check carrier reads the carrier status signal and sets Z flag to 
;  indicate status
;  Input - Nothing
;  Output - Zero flag 0 - Carrier
;	    Zero flag 1 - No Carrier detected
;  Changes - Nothing
;----------------------------------------------------------------------
CHECK_CARRIER	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		PUSH	AX			;Save registers
		PUSH	DX
		MOV	DX,COMM_PORT		;Get the comm base address
		ADD	DX,6			;Modem status register
		IN	AL,DX			;Get the current status
		TEST	AL,10000000B		;Data carrier detect
		POP	DX			;Restore registers
		POP	AX
		RET
CHECK_CARRIER	ENDP

;----------------------------------------------------------------------
;  DELAY - delay approximate number of seconds in AL
;  Input - AL
;  Output - Nothing (just waits till AL is zero)
;  Changes - Nothing
;----------------------------------------------------------------------
DELAY		PROC	NEAR
		PUSH	CX			;Save registers
		PUSH	DX
		PUSH	DI
		PUSH	AX
		XOR	AH,AH			;Read system time
		INT	1AH
		MOV	DI,DX			;Save low tick count
		MOV	SI,CX			;Save high tick count
		POP	AX			;Get number of seconds to delay
		PUSH	AX
		XOR	CX,CX			;Zero CX
		MOV	CL,AL			;Put seconds into loop counter
D_10:
		ADD	DI,19D			;Approximate counts in a second
		ADC	SI,0			;Add carry to SI
		LOOP	D_10
D_20:
		XOR	AH,AH			;Read system time
		INT	1AH
		CMP	SI,CX
		JNE	D_20
		CMP	DI,DX			;End of delay time
		JGE	D_20			;No, keep checking
		POP	AX			;Restore registers
		POP	DI
		POP	DX
		POP	CX
		RET
DELAY		ENDP

;----------------------------------------------------------------------
;  String at SI is placed in output buffer to be sent out serial port
;  Input - SI points to zero terminated string
;  Output - Nothing
;  Changes - SI
;----------------------------------------------------------------------
LOAD_ZSTRING	PROC	NEAR
		PUSH	AX			;Save register
		MOV	AH,1			;Use output buffer
		CLD				;Forward
LZ_10:
		LODSB				;Get a byte of data
		CMP	AL,0			;Check for zero
		JZ	LZ_EXIT 		;Yes, then exit
		CALL	PUT_BUFF_DATA		;No, put in output buffer
		JMP	LZ_10			;Process next data
LZ_EXIT:
		POP	AX			;Restore register
		RET
LOAD_ZSTRING	ENDP

;----------------------------------------------------------------------
;  Check for a key in the keyboard buffer, if one is there, get it
;  Input - Nothing
;  Output - Zero flag = 1 no key in buffer
;	    Zero flag = 0 key is in AX
;  Changes - AX
;----------------------------------------------------------------------
GET_KEYSTROKE	PROC	NEAR
	ASSUME	CS:CSEG,DS:NOTHING,ES:NOTHING,SS:NOTHING
		MOV	AH,1			;Check for keystroke
		INT	16H			;Keyboard BIOS
		JZ	GK_EXIT 		;No key so exit
		PUSHF				;Save the zero flag
		XOR	AH,AH			;Get the keystroke
		INT	16H
		POPF				;Restore the zero flag
GK_EXIT:
		RET
GET_KEYSTROKE	ENDP

;----------------------------------------------------------------------
;  Change the interrupt 8 vector to the interrupt service routine of
;  PCREMOTE
;  Input - CX points to starting buffer location
;  Output - Input and output buffer points are initialized
;  Changes - BX, CX
;----------------------------------------------------------------------
INIT_BUFFERS	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		MOV	BX,OFFSET IN_BUFF_HEAD	;In buffer will be here
		MOV	WORD PTR [BX],CX	; Set head pointer to buffer
		MOV	WORD PTR 2[BX],CX	;Set tail pointer to buffer
		MOV	WORD PTR 4[BX],CX	;Set begin of buffer
		ADD	CX,IN_BUFF_SIZE 	;CX Points to end of in buffer
		MOV	WORD PTR 6[BX],CX	;Set end of buffer
		MOV	BX,OFFSET OUT_BUFF_HEAD ;Out buffer after in buffer
		MOV	WORD PTR [BX],CX	; Set head pointer to buffer
		MOV	WORD PTR 2[BX],CX	;Set tail pointer to buffer
		MOV	WORD PTR 4[BX],CX	;Set begin of buffer
		ADD	CX,OUT_BUFF_SIZE	;CX Points to end of out buffer
		MOV	WORD PTR 6[BX],CX	;Set end of buffer
		RET
INIT_BUFFERS	ENDP

;----------------------------------------------------------------------
;  Change the interrupt 8 vector to the interrupt service routine of
;  PCREMOTE
;  Input - Nothing
;  Output - Interrupt vector 8 points to INT8
;  Changes - AX, DX, BX, ES
;----------------------------------------------------------------------
MODIFY_INT8	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
;
;	Change interrupt 8 vector
;
		MOV	AX,3508H		;Get interrupt 8h vector
		INT	21H
		MOV	OLDINT_8,BX		;And save it
		MOV	OLDINT_8[2],ES
		MOV	AX,2508H		;Set interrupt 8h vector
		MOV	DX,OFFSET INT8		; to point to new routine
		INT	21H
		RET
MODIFY_INT8	ENDP

;----------------------------------------------------------------------
;  Set baud rate to 1200 or 2400
;  Input - AL -0 1200 baud, 1 2400 baud
;  Output - Nothing
;  Changes - Nothing
;----------------------------------------------------------------------
SET_BAUD_RATE	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		PUSH	DX			;Save registers
		PUSH	BX
		PUSH	SI
		PUSH	AX
		MOV	DX,COMM_PORT		;Get port address
		ADD	DX,3			;Line control register
		MOV	AL,83H			;Toggle port address to
		OUT	DX,AL			; prepare to set baud rate
		SUB	DX,2			;Baud rate divisor MSB port
		POP	AX			;Restore baud rate
		PUSH	AX
		XOR	AH,AH			;Zero AH
		MOV	SI,AX			;Save in index register
		SHL	SI,1			;Multiply by 2, word address
		MOV	BX,OFFSET BAUD_RATE	;Point to baud rates
		MOV	AL,[BX+SI]		;Get baud rate MSB
		OUT	DX,AL			; and set it
		DEC	DX			;Baud rate divisor LSB port
		MOV	AL,1[BX+SI]		;Get baud rate LSB
		OUT	DX,AL			; and set it
		ADD	DX,3			;Line control register
		MOV	AL,3			;8 data bits,1 stop,no parity
		OUT	DX,AL			;Set data bit pattern
						; and toggle port address
		POP	AX			;Restore registers
		POP	SI
		POP	BX
		POP	DX
		RET
SET_BAUD_RATE	ENDP

;======================================================================
;  Initialize routines.  The initialize routine for unattended is first
;  because it must remain resident.
;======================================================================

;-----------------------------------------------------------------------------
;  Initialize the unattended program.
;-----------------------------------------------------------------------------
INIT_UNATTENDED PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:CSEG,SS:NOTHING
		CALL	IU_10			;Init pointers,clear video copy
		CALL	MODIFY_INT8		;Change INT 8 vector
;
;	Terminate-Stay-Resident
;
		MOV	DX,VIDEO_COPY		;Start of video copy
		ADD	DX,4000D		;Allow room for video copy
		INT	27H			;Terminate-Stay-Resident
;
;	Initialize buffer pointers and video copy pointer
;
IU_10:
		PUSH	ES			;Save extra segment
		MOV	CX,OFFSET INITIALIZE	;CX points to begin of buffer
		ADD	CX,256D 		;Leave room for TSR stack
		CALL	INIT_BUFFERS		;Initalize the buffer pointers
		INC	CX			;Point to copy of video ram
		MOV	TEMP_VIDEO_PTR,CX	;Save address of temp video buf
		ADD	CX,BLOCK_SIZEX2 	;Save room for temp video data
		MOV	VIDEO_COPY,CX		;Save address of video copy
;
;	fill video RAM image with with space code since screen
;	of manned system is blanked when connected
;
		PUSH	CS			;Video copy is destination
		POP	ES			;ES:DI points to video copy
		MOV	DI,WORD PTR VIDEO_COPY
		MOV	AX,0720H		;Data to fill buffer
		CLD				;Move upward
		MOV	CX,2000D		;Move 2000 words
		REP	STOSW			;Fill to force screen dump
		MOV	CURSOR_POSITION,0FFFFH	;Force cursor position update
		MOV	AL,1			;Use setup string 2
		CALL	RESET_MODEM		;Reset the modem
		POP	ES			;Restore extra segment
		RET
INIT_UNATTENDED ENDP

;-----------------------------------------------------------------------------
;  INITIALIZE - Initialize the program.  Determine whether it is manned
;  or unattended by processing the command line.  Initialize the serial
;  port.
;-----------------------------------------------------------------------------
INITIALIZE	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
;
;	Display copyright notice.
;
		MOV	DX,OFFSET COPYRIGHT	;Display copyright notice
		MOV	AH,9			;Display string
		INT	21H
;
;	check to see if the program is already in memory
;
		MOV	BYTE PTR START,0	;Zero word to avoid false match
		XOR	BX,BX			;Initialize search segment
		MOV	AX,CS			;Save current segment in AX
		CLD				;Clear direction flag
I_10:
		INC	BX			;Increment search segment
		CMP	AX,BX			;Reached current segment?
		JE	I_20			;Yes, PCREMOTE not resident
		MOV	ES,BX			;Point ES to search segment
		MOV	SI,OFFSET START 	;Start of compare area
		MOV	DI,SI			;Make offsets equal
		MOV	CX,16D			;Check 16 characters
		REPE	CMPSB			;Compare the strings
		JNE	I_10			;Compare failed
		MOV	AH,09H			;Print string
		MOV	DX,OFFSET PROG_RES	;Display program resident mess.
		INT	21H
		INT	20H			;Terminate
;
;	Process command line for switches.
;
I_20:
		PUSH	CS			;Restore ES
		POP	ES
		MOV	BX,80H			;Point to command line length
		MOV	AH,[BX] 		;Get command line length
I_30:
		OR	AH,AH			;Check for commands
		JZ	I_70			;None, so don't look
		INC	BX			;Point to next data
		MOV	AL,[BX] 		;Get data
		DEC	AH			;Decrement counter
		CMP	AL,"/"			;Check for slash
		JNE	I_30			;No, jump to check next data
		OR	AH,AH			;Check for data after slash
		JZ	I_70			;No, so don't process
		INC	BX			;Point to next data
		MOV	AL,[BX] 		;Get data
		DEC	AH			;Decrement counter
		CMP	AL,"2"			;Check for comm2
		JNE	I_40			;No, check for another switch
		INC	BYTE PTR COMM_FLAG	;Set comm2 flag
		JMP	I_30			;Process next switch
I_40:
		OR	AL,20H			;Force data to lower case
		CMP	AL,"m"			;Check for manned switch
		JNE	I_50			;No, check for another switch
		INC	BYTE PTR MANNED_FLAG	;Set manned flag
		JMP	I_30			;Process next switch
I_50:
		CMP	AL,"f"			;Check for fast speed
		JNE	I_60			;No, check for another switch
		INC	BYTE PTR SPEED_FLAG	;Set high speed flag
		JMP	I_30			;Process next switch
I_60:
		CMP	AL,"d"			;Check for desnow
		JNE	I_30			;No, process next switch
		INC	BYTE PTR DESNOW_FLAG	;Set desnow flag
		JMP	I_30			;Process next switch

;----------------------------------------------------------------------
;  Initialize the serial port
;----------------------------------------------------------------------

I_70:
;
;	get the comm port base address using 2* comm port flag as offset
;
		PUSH	DS			;Save data segment
		XOR	BX,BX			;Zero BX
		MOV	BL,COMM_FLAG		;Get comm port flag
		MOV	SI,BX			;Save in index register
		SHL	SI,1			;Multiply by 2, word address
		MOV	AX,40H			;Point DS to BIOS data area
		MOV	DS,AX
		XOR	BX,BX			;Point to comm port address
		MOV	AX,[BX+SI]		;Get comm port address
		POP	DS			;Restore data segment
		MOV	COMM_PORT,AX		;Save comm port address
;
;	disable the interrupts on the 8250 and initialize DTR and RTS
;
		CLI				;Disable interrupts
		MOV	DX,COMM_PORT		;Get UART base address
		ADD	DX,4			;Modem control register
		MOV	AL,00001011B		;Set DTR, RTS, and OUT2
		OUT	DX,AL
;
;	set the baud rate of the UART and initialize line control register
;
		MOV	AL,SPEED_FLAG		;Get speed flag
		CALL	SET_BAUD_RATE
;
;	modify the interrupt vector for the comm port and set 8259 mask
;
		CMP	BYTE PTR COMM_FLAG,0	;Determine INT vector to change
		JZ	I_80
		MOV	AL,11D			;Vector for comm2
		MOV	BL,0F7H			;Mask for 8259 comm2
		JMP	I_90
I_80:
		MOV	AL,12D			;Vector for comm1
		MOV	BL,0EFH			;Mask for 8259 comm1
I_90:
		MOV	AH,25H			;Set interrupt for comm vector
		MOV	DX,OFFSET INT_COMM	; to point to routine
		INT	21H
		IN	AL,21H			;Get current 8259 int mask
		AND	AL,BL			;Mask appropriate int bit
		OUT	21H,AL			;And set new 8259 mask
;
;	enable the data received interrupt and reset the 8250
;
		MOV	DX,COMM_PORT		;Point to comm port
		INC	DX			;Point to int enable reg
		MOV	AL,3			;Enable data received int
		OUT	DX,AL
		DEC	DX			;Point to base address
		MOV	CX,7			;Reset the serial port
I_100:
		IN	AL,DX			;Read registers to reset
		INC	DX
		LOOP	I_100
;
;	determine color or monochrome and save appropriate video segment
;
		MOV	AH,0FH			;Determine video mode
		INT	10H			;By using BIOS int 10
		CMP	AL,7			;Check for monochrome
		JZ	MONOCHROME		      ;Jump if it is
		MOV	WORD PTR VIDEO_SEGMENT,0B800H ;Nope, it's CGA or EGA
		JMP	I_110			      ;Skip over
MONOCHROME:
		MOV	WORD PTR VIDEO_SEGMENT,0B000H ;It's a monochrome
I_110:
;
;	If manned then execute manned initialization, otherwise execute
;	unattended initialization.
;
		CMP	BYTE PTR MANNED_FLAG,0	;Manned or unattended
		JNZ	INIT_MANNED		;Init the manned routines
		JMP	INIT_UNATTENDED 	;Init the unattended routines
INITIALIZE	ENDP

;----------------------------------------------------------------------
;  Initialize the manned program.  Initialize buffers, and change INT 8
;  vector.
;----------------------------------------------------------------------
INIT_MANNED	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		MOV	CX,OFFSET LAST_BYTE	;CX points to begin of buffer
		CALL	INIT_BUFFERS		;Initalize the buffer pointers
		MOV	AX,VIDEO_SEGMENT	;Set ES to point to video RAM
		MOV	ES,AX
		JMP	CONNECT_MANNED		;Run manned portion of program
INIT_MANNED	ENDP

;======================================================================
;  Data used by manned portion of program only.  Not required to be
;  resident for unattended mode.
;======================================================================
BLOCK_DATA_COUNT DB	0			;Number of bytes left to rec.
TYPE_TRANSFER	DB	0FFH			;FF - No data transfer in prog.
						;00 - Received FE, char. data
						;01 - Received FF, attr. data
CUR_STATUS	DB	0			;0=No cursor data being rec.
						; otherwise, byte count
CUR_LOW 	DB	0			;Low byte of cursor data
CUR_HIGH	DB	0			;High byte of cursor data
ENTER_NUMBER	DB	CR,LF,CR,LF,"Enter phone number:$"
NO_CARRIER	DB	CR,LF,"No carrier.$"
MODEM_ERROR	DB	CR,LF,"Error.$"
TERMINATE_MESS	DB	CR,LF,"Returning to DOS.$"
PROG_RES	DB	CR,LF,"PCREMOTE is already resident.$"
EXIT_MESSAGE	DB	"ษออออออออออออออออออป"
		DB	"บ OK to EXIT? (Y/N)บ"
		DB	"ศออออออออออออออออออผ"

;======================================================================
;  The manned routine will execute the connect manned routine to call the
;  unattended system.  These routines are only used in the manned mode.
;======================================================================

;----------------------------------------------------------------------
;  Connect manned asks for the phone number to call, dials the number
;  and waits for connect.  Once connected it sends bursts of 20 CRs at
;  one second intervals.  When it receives alpha data it processes video
;  data and waits for sync byte (00), then transfers control to the
;  manned routine.
;----------------------------------------------------------------------
CONNECT_MANNED	PROC	NEAR
		ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		XOR	AL,AL			;Use setup string 1
		CALL	RESET_MODEM		;Reset the modem first
		MOV	DX,OFFSET ENTER_NUMBER	;Point to enter number mess.
		MOV	AH,9			;Display message
		INT	21H
		MOV	DX,OFFSET UNATTENDED	;Unused area as keyboard buffer
		MOV	BX,DX			;Enter max characters for input
		MOV	BYTE PTR [BX],40D
		MOV	AH,0AH			;Buffered keyboard input
		INT	21H			;Get the phone number
		MOV	AL,1			;Wait a second
		CALL	DELAY
		MOV	SI,OFFSET UNATTENDED	;Point to phone number
		INC	SI			;Amount of data in key buffer
		XOR	AX,AX			;Zero AX
		CLD				;Forward
		LODSB				;Get count
		OR	AL,AL			;Check for no input
		JNZ	CM_10			;If there is then continue
		JMP	EXIT_MANNED		;No, then exit program
CM_10:
		PUSH	SI			;Save pointer
		MOV	SI,OFFSET TONE_DIAL	;Send the tone dial command
		CALL	LOAD_ZSTRING
		POP	SI			;Restore pointer
		ADD	SI,AX			;Point to end of buffer
		INC	SI			;Include CR code
		MOV	BYTE PTR [SI],0 	;And put a zero on end
		DEC	SI			;Adjust for previous INC
		SUB	SI,AX			;Back to begin of buffer
		CALL	LOAD_ZSTRING		;Dial the phone number
		MOV	AL,1			;Wait a second
		CALL	DELAY
		CALL	CLEAR_INBUFF		;Clear input buffer
CM_20:
		CALL	CHECK_CARRIER		;Check for a connect signal
		JZ	CM_30			;No, then check for err codes
		CALL	CLEAR_SCREEN		;Yes, blank the screen
		MOV	BYTE PTR CONNECT_FLAG,1 ;Set the connect flag
		JMP	CM_60			;Execute manned
CM_30:
		MOV	AH,0			;Use input buffer
		CALL	GET_BUFF_DATA		;Get data from buffer
		JNC	CM_20			;No data, try again
		CMP	AL,"3"			;No carrier code?
		JNZ	CM_50			;No, check for other code
CM_40:		
		MOV	DX,OFFSET NO_CARRIER	;Send no carrier message
		MOV	AH,09H
		INT	21H
		JMP	CONNECT_MANNED		;Yes, reset modem and try again
CM_50:
		CMP	AL,"8"			;2400 no answer code
		JZ	CM_40			;Yes, display no carrier mess
		CMP	AL,"4"			;Error code?
		JNZ	CM_20			;No, check for other code
		MOV	DX,OFFSET MODEM_ERROR	;Send modem command error mess
		MOV	AH,09H
		INT	21H
		JMP	CONNECT_MANNED		;Yes, reset modem and try again
CM_60:
		MOV	AL,1			;Wait for a second
		CALL	DELAY
		MOV	BYTE PTR CR_COUNT,20D	;Send 20 CRs at a time
CM_70:
		CALL	CHECK_CARRIER		;Check for carrier loss
		JNZ	CM_80			;No, then continue
		JMP	EXIT_MANNED		;Yes, then exit
CM_80:
		MOV	AX,OUT_BUFF_TAIL	;Is output buffer empty?
		CMP	AX,OUT_BUFF_HEAD
		JNZ	CM_90			;No, skip CR
		MOV	AL,CR			;Send a CR for speed sync
		MOV	AH,1			;Use output buffer
		CALL	PUT_BUFF_DATA
		DEC	BYTE PTR CR_COUNT	;Decrement CR counter
		JZ	CM_60
CM_90:
		MOV	AH,0			;Use input buffer
		CALL	GET_BUFF_DATA		; and check for data
		JNC	CM_70			;No data so keep checking
		CMP	AL,'@'			;Alpha message?
		JL	CM_70			;No, then wait for it
CM_100:
		CMP	AL,0			;Is data a sync byte
		JNE	CM_110			;No, then put data on screen
		CALL	CLEAR_SCREEN		;Blank the screen
		JMP	MANNED			;We're in, let's run program
CM_110:
		MOV	DL,AL			;Prepare to display character
		MOV	AH,2			; using DOS
		INT	21H			;Display it
CM_120:
		CALL	CHECK_CARRIER		;Check for carrier loss
		JNZ	CM_130			;No, then continue
		JMP	EXIT_MANNED		;Yes, then exit
CM_130:
		CALL	GET_KEYSTROKE		;Check for a keystroke
		JZ	CM_150			;If none, skip next routine
;
;	Check for exit code, if it is then exit
;
		CMP	AX,WORD PTR EXIT_CODE	;Check for exit code
		JNZ	CM_140			;No, so continue
		CALL	CONFIRM_EXIT		;Yes, confirm exit
		JNZ	CM_150			;No, so continue, don't send
		JMP	EXIT_MANNED		;Otherwise reset and exit
CM_140:
		CALL	SEND_KEYSTROKE		;Send to unattended system
CM_150:
		MOV	AH,0			;Use input buffer
		CALL	GET_BUFF_DATA		; and check for data
		JNC	CM_120			;No data, check for keys
		JMP	CM_100			;Check for sync byte
CONNECT_MANNED	ENDP

;----------------------------------------------------------------------
;  Manned portion of the program.  Not RAM resident.  Sends keystrokes
;  to the unattended computer.	Data from unattended computer is
;  decoded and processed.
;----------------------------------------------------------------------
MANNED		PROC	NEAR
		ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
;
;	Check for loss of carrier
;
		CALL	CHECK_CARRIER		;No, check for carrier loss
		JNZ	M_10			;No loss so continue
		JMP	EXIT_MANNED		;Otherwise reset and exit
;
;	Check to see if shift status has changed, if so, put new status
;	in the output buffer
;
M_10:
		MOV	AH,2			;Prepare to get shift status
		INT	16H			;Get shift status
		CMP	SHIFT_STATUS,AL 	;See if the same
		JE	M_20			;If so then next routine
		MOV	SHIFT_STATUS,AL 	;Save new status
		MOV	AL,0FDH 		;Sync byte, to expect shift
		MOV	AH,1			;Put into output buffer
		CALL	PUT_BUFF_DATA
		MOV	AL,SHIFT_STATUS 	;Get the shift status
		CALL	PUT_BUFF_DATA		;Send to unattended computer
;
;	Check for keystoke, if so, put the ASCII code and scan code
;	into the output buffer, check it for exit code
;
M_20:
		CALL	GET_KEYSTROKE		;Check for keystroke
		JZ	M_50			;If none skip this routine
;
;	Check for exit code, if it is then exit
;
		CMP	AX,WORD PTR EXIT_CODE	;Check for exit code
		JNZ	M_40			;No, so continue
		CALL	CONFIRM_EXIT		;Yes, confirm exit
		JNZ	M_50			;No, so continue, don't send
		JMP	EXIT_MANNED		;Otherwise reset and exit
M_40:
		CALL	SEND_KEYSTROKE		;Send keystroke
;
;	Check for receive data, if available, get data and decode
;
M_50:
		MOV	AH,0			;Get data from input buffer
		CALL	GET_BUFF_DATA
		JC	M_60			;Data is there, so process
		JMP	M_EXIT			;No data,so loop again
M_60:
		CMP	BYTE PTR TYPE_TRANSFER,0FFH ;Check transfer type
		JZ	M_100			;If ff, check for sync byte
M_70:
		CMP	VID_RAM_OFFSET,0FFFFH	;Received block no. yet?
		JNZ	M_80			;Yes, then process as data
		MOV	BYTE PTR BLOCK_DATA_COUNT,BLOCK_SIZE ;Data counter
		MOV	BX,BLOCK_SIZEX2 	;Get block size in bytes
		MUL	BX			;Block number X block size
		ADD	AL,TYPE_TRANSFER	;Adjust for char. or attr.
		MOV	VID_RAM_OFFSET,AX	;Save pointer to video RAM
		JMP	M_EXIT
M_80:
		MOV	DI,VID_RAM_OFFSET	;Point to video RAM
		CALL	PUT_VIDEO_DATA		;Store the data in video RAM
		INC	DI			;Point to next video RAM loc.
		MOV	VID_RAM_OFFSET,DI	  ;And save pointer
		DEC	BYTE PTR BLOCK_DATA_COUNT ;Dec. data counter
		JZ	M_90			  ;End of data, reset variables
		JMP	M_EXIT			;Otherwise continue
M_90:
		MOV	BYTE PTR TYPE_TRANSFER,0FFH ;Reset type transfer flag
		JMP	M_EXIT
M_100:
		CMP	BYTE PTR CUR_STATUS,0	;Check cursor status
		JZ	M_110			;If 0, check for sync byte
		XOR	BX,BX			;Zero BX for index
		MOV	BL,BYTE PTR CUR_STATUS	;Use as index for cursor data
		MOV	DI,OFFSET CUR_STATUS	;Base address for cursor data
		MOV	[DI+BX],AL		;Save the register data
		INC	BL			;Increment count
		MOV	BYTE PTR CUR_STATUS,BL	;And save it

		CMP	BL,3			;Check to see if we have 3 byte
		JNZ	M_EXIT			;No, so wait till enough data
		MOV	BH,0			;Always use page one
		MOV	DX,WORD PTR CUR_LOW	;Get cursor position
		MOV	AH,2			;Set cursor function
		INT	10H
		MOV	BYTE PTR CUR_STATUS,0	;Reset cursor status
		JMP	M_EXIT
M_110:
		PUSH	AX			;Save the data
		AND	AL,0FEH 		;Mask out LSB
		CMP	AL,0FEH 		;Video data sync?
		JNZ	M_120			;No, check for cursor sync
		POP	AX			;Yes, restore data
		AND	AL,1			;Save LSB
		MOV	TYPE_TRANSFER,AL	;Set transfer type flag
		MOV	VID_RAM_OFFSET,0FFFFH	;Prepare to receive block no.
		JMP	M_EXIT
M_120:
		CMP	AL,0D2H 		;Check for cursor data sync
		JNZ	M_130			;If not, then throw away
		POP	AX			;Restore data
		MOV	BYTE PTR CUR_STATUS,1	;Set cursor status byte
		JMP	M_EXIT
M_130:
		POP	AX			;Clean up stack
M_EXIT:
		JMP	MANNED			;Do it again
MANNED		ENDP

;----------------------------------------------------------------------
;  Exit manned.  The exit code is sent, interrupt vector reset, and
;  the modem is hung up and reset
;  Input - Nothing
;  Output - DOS
;  Changes - everything
;----------------------------------------------------------------------
EXIT_MANNED	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		MOV	AX,WORD PTR EXIT_CODE	;Get the exit code
		CALL	SEND_KEYSTROKE		;Send the exit code
		CALL	CLEAR_SCREEN		 ;Blank the screen
		MOV	DX,OFFSET TERMINATE_MESS ;Display terminate call mess.
		MOV	AH,09H
		INT	21H
		XOR	AL,AL			;Reset modem and exit
		CALL	RESET_MODEM
		MOV	AL,1			;Wait a second
		CALL	DELAY
;
;  Disable the serial port interrupts and reset the 8259 mask
;
		MOV	DX,COMM_PORT		;Get port address
		INC	DX			;Interrupt enable reg.
		XOR	AL,AL
		OUT	DX,AL			;Disable all interrupts
		CMP	BYTE PTR COMM_FLAG,0	;Determine mask bit to change
		JZ	EM_10
		MOV	BL,00001000B		;Mask for 8259 comm2
		JMP	EM_20
EM_10:
		MOV	BL,00010000B		;Mask for 8259 comm1
EM_20:
		IN	AL,21H			;Get current 8259 int mask
		OR	AL,BL			;Set appropriate int bit
		OUT	21H,AL			;And set new 8259 mask
		INT	20H			;Terminate program
EXIT_MANNED	ENDP

;----------------------------------------------------------------------
;  Clear screen.  This routine will blank the video display
;  Input - Nothing
;  Output - Screen is cleared
;  Changes - AX, BX, CX, DX
;----------------------------------------------------------------------
CLEAR_SCREEN	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		MOV	BX,0			;Use video page one
		MOV	DX,0			;Position cursor at row 0 col 0
		MOV	AH,2			;Set cursor function
		INT	10H
		MOV	AX,0700H		;Scroll down, clear screen
		MOV	BH,07H			;White on black
		MOV	CX,0			;Upper left corner
		MOV	DH,24D			;Lower right corner
		MOV	DL,79D
		INT	10H			;Video BIOS call
		RET
CLEAR_SCREEN	ENDP

;----------------------------------------------------------------------
;  Store the video data in AL in the memory location pointed to by DI
;  Input - AL video data, ES:DI video RAM destination
;  Output - Nothing
;  Changes - DI is incremented
;----------------------------------------------------------------------
PUT_VIDEO_DATA	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
;
;	Check desnow flag, if set wait for horizontal sync to put in video RAM
;
		PUSH	BX			;Save registers
		PUSH	DX
		CMP	BYTE PTR DESNOW_FLAG,0	;Check desnow flag
		JZ	PV_30			;No, skip over
		CLD				;Forward
		MOV	BL,AL			;Save video data
		MOV	DX,3DAH			;CGA status port
		CLI				;Disable interrupts
PV_10:
		IN	AL,DX			;Get status byte
		TEST	AL,1			;Test display enable
		JNZ	PV_10			;If in Hor. sync then wait
PV_20:
		IN	AL,DX			;Get status byte
		TEST	AL,1			;Test display enable
		JZ	PV_20			;Wait for Hor. sync
		XCHG	AX,BX			;Get video data
PV_30:
		STOSB				;And put into video RAM
		STI				;Enable interrupts
		POP	DX			;Restore registers
		POP	BX
		RET
PUT_VIDEO_DATA	ENDP

;----------------------------------------------------------------------
;  Display OK to exit message and wait for response
;  Input - Nothing
;  Output - Zero flag set - exit, zero flag reset - do not exit
;  Changes - CX, SI, DI
;----------------------------------------------------------------------
CONFIRM_EXIT	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		PUSH	AX			;Save the exit code
CE_10:
		MOV	AX,OUT_BUFF_HEAD	;Wait until the out buffer
		CMP	AX,OUT_BUFF_TAIL	; is empty
		JNZ	CE_10
;
;  Save the existing video data in the output buffer
;
		CALL	SWITCH_DS_ES
		MOV	DI,ES:OUT_BUFF_BEGIN	;Use output buffer as temp stor.
		MOV	SI,0			;Upper left corner of video
		MOV	CX,3			;Transfer 3 lines
CE_20:
		PUSH	CX			;Save line counter
		MOV	CX,20D			;Transfer 20 char. per line
		REPNZ	MOVSW
		ADD	SI,120D 		;Next line
		POP	CX			;Restore line counter
		LOOP	CE_20
;
;  Display the ok to exit message
;
		CALL	SWITCH_DS_ES
		MOV	DI,0			;Upper left corner of video
		MOV	SI,OFFSET EXIT_MESSAGE	;Exit message
		MOV	CX,3			;Display three lines
CE_30:
		PUSH	CX			;Save line counter
		MOV	CX,20D			;Display 20 characters per line
CE_40:
		LODSB
		CALL	PUT_VIDEO_DATA		;Display the character
		MOV	AL,7			;White on black attribute
		CALL	PUT_VIDEO_DATA		;Store attribute
		LOOP	CE_40
		ADD	DI,120D 		;Next line
		POP	CX			;Restore line counter
		LOOP	CE_30
;
;  Wait for keystroke and convert to lower case
;
CE_50:
		CALL	GET_KEYSTROKE		;Check for keystroke
		JZ	CE_50			;None there, try again
		OR	AL,20H			;Convert to lower case
;
;  Restore the saved video data
;
		MOV	SI,OUT_BUFF_BEGIN	;Old video is in output buffer
		MOV	DI,0			;Upper left corner of video
		MOV	CX,3			;Transfer 3 lines
CE_60:
		PUSH	CX			;Save line counter
		MOV	CX,20D			;Transfer 20 char. per line
		REPNZ	MOVSW
		ADD	DI,120D 		;Next line
		POP	CX			;Restore line counter
		LOOP	CE_60
		CMP	AL,'y'			;Check for yes, all others no
		POP	AX			;Restore exit code
		RET
CONFIRM_EXIT	ENDP

;----------------------------------------------------------------------
;  Switch ES and DS
;  Input - Nothing
;  Output - ES is in DS and DS is in ES
;  Changes - ES, DS
;----------------------------------------------------------------------
SWITCH_DS_ES	PROC	NEAR
		PUSH	ES
		PUSH	DS
		POP	ES
		POP	DS
		RET
SWITCH_DS_ES	ENDP

;----------------------------------------------------------------------
;  Put the keystroke data into the output buffer to be sent to unattended
;  system
;  Input - AX - keystroke data
;  Output - Nothing
;  Changes - Nothing
;----------------------------------------------------------------------
SEND_KEYSTROKE	PROC	NEAR
	ASSUME	CS:CSEG,DS:CSEG,ES:NOTHING,SS:NOTHING
		PUSH	AX			;Save it
		MOV	AH,1			;Use the output buffer
		MOV	AL,0FEH 		;Sync byte, to expect key data
		CALL	PUT_BUFF_DATA		;Put AL into the output buffer
		POP	AX			;Get AL back
		PUSH	AX			;Save AH
		MOV	AH,1			;Use the output buffer
		CALL	PUT_BUFF_DATA		;Put ASCII code in out buffer
		POP	AX			;Get AH back
		PUSH	AX			;Save keystroke
		MOV	AL,AH			;Move it to AL
		MOV	AH,1			;Use the output buffer
		CALL	PUT_BUFF_DATA		;Put scan code in out buffer
		POP	AX			;Restore keystroke
		RET
SEND_KEYSTROKE	ENDP

;======================================================================
LAST_BYTE	EQU	$
CSEG		ENDS
		END	START
