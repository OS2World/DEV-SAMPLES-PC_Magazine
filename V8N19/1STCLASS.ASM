	PAGE	60,132
	TITLE	'1stClass:  MCI Mail Agent'

CINT	=	14H		; interrupt for Couriers
FIFOSIZE=	512		; size for COM-port input FIFO
FNSIZE	=	65		; maximum filename size
ATTESC	=	'!'		; attachment escape character
CLOCK	=	46CH		; low-memory timer word
SBS	=	128		; small-buffer size
LBS	=	512		; large buffer size:  must be at least (SBS+1)*3
BELL	=	07H		; ASCII bell
BS	=	08H		; ASCII backspace
CR	=	0DH		; ASCII carriage return
ESCAPE	=	1BH		; ASCII escape
LF	=	0AH		; ASCII linefeed
TAB	=	09H		; ASCII tab

; Mail Link message types (internal enumeration only)

MT_COMMENT	=	0
MT_CREATE	=	1
MT_END		=	2
MT_ENV		=	3
MT_INIT		=	4
MT_REPLY	=	5
MT_RESET	=	6
MT_SEND		=	7
MT_TERM		=	8
MT_TEXT		=	9
MT_TURN		=	10

PSEG	SEGMENT
	ASSUME	CS:PSEG, DS:PSEG, ES:PSEG

; Entry point

	ORG	100H
ENTRY	PROC	NEAR
	XOR	AX,AX			; jump to CS:0000 to exit
	PUSH	AX
	CLD
	CALL	TTY$			; announce 1stClass
	DW	OFFSET INITMSG
	MOV	AH,80H			; check if Couriers is loaded
	INT	CINT
	CMP	AH,232
	JNE	.EN5			; if Couriers is not there
	MOV	AH,3CH			; create log file for session transcript
	MOV	DX,OFFSET LOGFN		; DX -> "1STCLASS.LOG"
	XOR	CX,CX
	INT	21H
	MOV	LOGFH,AX		; save handle
	JC	.EN3			; if create failed
	MOV	AX,3D01H		; open file for incoming mail
	MOV	DX,OFFSET INFN		; DX -> "MAIL.IN"
	INT	21H
	JNC	.EN2			; if opened successfully
	MOV	AH,3CH			; else try a create
	XOR	CX,CX
	INT	21H
	JC	.EN3			; if we cannot get the file at all

.EN2:	MOV	MAILIN,AX
	MOV	BX,AX			; BX = handle
	MOV	AX,4202H		; move file pointer to end
	XOR	CX,CX
	XOR	DX,DX
	INT	21H	
	MOV	DX,OFFSET CSFN		; DX -> "1STCLASS.CSF"
	CALL	SCRIPT			; process the script
	JMP	CLEAN			; go clean up and exit

.EN3:	JMP	OPEN_ERROR

.EN5:	CALL	TTY$			; complain that Couriers is not loaded
	DW	OFFSET LOADMSG
	RET
ENTRY	ENDP

; Append a carriage return and linefeed to a string

APPEND_CRLF	PROC NEAR	; DI -> string
	MOV	AX,(LF SHL 8) OR CR
	STOSW
	RET
APPEND_CRLF ENDP	; returns DI = updated string pointer

; Process an !ATTACH instruction

ATTACH_FILE	PROC	NEAR	; SI -> Attach command
	INC	SI			; push SI past escape character
	CALL	FOLDUP			; fold line to uppercase
	MOV	BX,OFFSET INST_KEYS	; match an instruction key
	CALL	MATCH
	JNZ	.AF4			; if not "ATTACH"
	CALL	SKIP_WHITESPACE
	MOV	DI,OFFSET FILENAME
	MOV	DX,DI			; DX, DI -> filename area

.AF1:	LODSB				; peel off filename
	CMP	AL,' '			; note that length is not checked!
	JLE	.AF2
	STOSB
	JMP	SHORT .AF1

.AF2:	XOR	AX,AX
	STOSB

	CALL	TTY$			; tell user about attachment
	DW	OFFSET ATMSG
	MOV	BX,DX			; BX -> filename
	CALL	TTYZ
	MOV	AX,3D00H		; open for read, DX -> filename
	INT	21H
	MOV	BX,AX			; BX = handle
	JC	.AF3			; if error
	PUSH	BX
	MOV	SI,DX			; SI -> filename

.AF24:	LODSB				; scan past path
	TEST	AL,AL
	JZ	.AF28
	CMP	AL,':'
	JE	.AF26
	CMP	AL,'\'
	JNE	.AF24

.AF26:	MOV	DX,SI
	JMP	SHORT .AF24

.AF28:	MOV	SI,DX			; send FILENAME.EXT with attachment
	CALL	SEND_FILE		; send the file
	MOV	AH,3EH			; and close the file
	POP	BX			; BX = handle
	INT	21H
	RET

.AF3:	JMP	OPEN_ERROR		; complain that file cannot be opened

.AF4:	CALL	TTY$			; complain about invalid !command
	DW	OFFSET INSTMSG

.AF5:	MOV	BX,OFFSET LINE_BUFFER	; and echo the command
	CALL	TTYZ
	RET
ATTACH_FILE	ENDP

; Calculate a checksum

CALCULATE_CHECKSUM	PROC	NEAR		; SI -> message to be summed
	PUSH	SI
	MOV	BX,CHECKSUM		; accumulate sum in BX
	XOR	AX,AX

.CC1:	LODSB				; load each byte
	ADD	BX,AX			; and add to the checksum
	TEST	AL,AL			; until a null is encountered
	JNZ	.CC1

	MOV	AX,BX
	MOV	CHECKSUM,AX		; store checksum
	POP	SI
	RET		; returns AX = checksum, kills BX
CALCULATE_CHECKSUM	ENDP

; Clean up and exit

CLEAN	PROC	NEAR
	MOV	AX,8D00H		; deconfigure COM port
	OR	AL,COM_PORT
	JZ	.CL1			; unless we never configured one
	INT	CINT

.CL1:	XOR	BX,BX
	JMP	BX
CLEAN	ENDP

; Process a received COMMENT or RESET command

COMMENTARY	PROC	NEAR
	INC	ECHO_LINE		; display this reply
	CALL	RECEIVE_MESSAGE		; wait for rest of commentary
	DEC	ECHO_LINE
	XOR	BX,BX			; no text in reply
	RET
COMMENTARY	ENDP

; Copy ASCII characters to a Mail Link message, mapping as required

COPY_ASCII	PROC	NEAR	; SI -> source (null terminated), DI -> destination
	PUSH	DI

.CA1:	LODSB				; AL = next character
	TEST	AL,AL
	JZ	.CA3			; if at end of message
	CMP	AL,1AH			; check for end-of-file
	JE	.CA4
	CMP	AL,'*'			; translate asterisk, slash and percent
	JE	.CA2
	CMP	AL,'/'
	JE	.CA2
	CMP	AL,'%'
	JE	.CA2
	STOSB
	JMP	SHORT .CA1

.CA2:	MOV	AH,AL			; AH = ASCII code for PUTHEX
	MOV	AL,'%'			; preface hex by a percent sign
	STOSB
	MOV	CH,2			; encode a 2-character hex
	CALL	PUTHEX
	JMP	SHORT .CA1

.CA3:	POP	SI
	CLC
	RET

.CA4:	POP	SI
	STC
	RET		; returns SI -> destination, updated pointer in DI
COPY_ASCII ENDP		; CF = 1 if Ctrl-Z end-of-file detected

; Copy a string of bytes, mapping codes to ASCII as required
;
; Basic algorithm:
;	Fill buffer up to CR/LF then flush but if buffer reaches 197
;	characters then append a %CR/LF and flush.  If data does not end
;	with a CR/LF then append a %CRLF.

COPY_BINARY	PROC	NEAR	; BX = handle to read from
	MOV	DI,OFFSET XM_BUFFER	; SI, DI -> transmit buffer
	MOV	SI,DI

.CB1:	CALL	READ_BYTE
	JC	.CB8			; on EOF

.CB2:	CMP	AL,CR			; special considerations for CRs
	JE	.CB5
	CMP	AL,TAB			; tabs go through as is
	JE	.CB3
	CMP	AL,' '			; all other control chars get mapped
	JB	.CB4
	CMP	AL,'*'			; so do asterisk, slash and percent
	JE	.CB4
	CMP	AL,'/'
	JE	.CB4
	CMP	AL,'%'
	JE	.CB4
	CMP	AL,7EH			; DEL and all extended chars
	JAE	.CB4

.CB3:	STOSB				; stuff the byte into the buffer
	CALL	FLUSH_CHECK		; flush buffer if it's full
	JMP	SHORT .CB1

.CB4:	CALL	MAP_BYTE		; map the byte and check the buffer
	JMP	SHORT .CB1

.CB5:	CALL	READ_BYTE		; got a CR, see what's next
	JNC	.CB6			; if anything but EOF
	MOV	AL,CR			; and send the CR mapped
	CALL	MAP_BYTE
	JMP	SHORT .CB8		; then tie things up

.CB6:	CMP	AL,LF			; do we have a nice CR/LF?
	JNE	.CB7			; oh dear
	CALL	APPEND_CRLF		; buffer CR/LF
	CALL	TRANSMIT		; flush buffer and reset pointers
	CALL	DOTTY			; drive user dotty
	JMP	.CB1

.CB7:	PUSH	AX			; save second character
	MOV	AL,CR			; and send the CR mapped
	CALL	MAP_BYTE
	POP	AX			; retrieve next character
	JMP	.CB2			; and handle normally

.CB8:	CMP	SI,DI			; anything in the buffer?
	JE	.CB9			; if not we are done
	MOV	AL,'%'			; else append a delimited CR/LF
	STOSB
	CALL	APPEND_CRLF
	CALL	TRANSMIT		; and flush the buffer

.CB9:	RET
COPY_BINARY ENDP

; Copy a null-terminated string

COPY_STRING	PROC	NEAR	; SI -> string, DI -> destination

.CS1:	LODSB
	STOSB
	TEST	AL,AL
	JNZ	.CS1
	DEC	DI
	RET		; returns SI -> end of string, DI -> next position
COPY_STRING	ENDP

; Handle a received CREATE command -- which means doing nothing

CREATE	PROC	NEAR
	XOR	BX,BX			; no text in reply
	RET
CREATE	ENDP

; Delay for a certain number of 18.2-to-a-second clock ticks.  The method used
; is guaranteed never to be shorter than the specified period but it may be
; longer.

DELAY	PROC	NEAR	; TIMEOUT set for number of ticks to delay
	MOV	CX,TIMEOUT		; CX = ticks to delay
	INC	CX			; adjust for method
	PUSH	DS
	XOR	AX,AX
	MOV	DS,AX			; DS = 0

OS1:	CMP	AX,DS:[CLOCK]		; read the system clock
	JE	OS1			; until it gets updated
	MOV	AX,DS:[CLOCK]
	LOOP	OS1			; then count down one tick

	POP	DS
	RET
DELAY	ENDP

; Display a dot on the screen to let the user know that things are progressing

DOTTY	PROC	NEAR
	MOV	AH,02H			; use DOS service 2
	MOV	DL,'.'
	INT	21H
	RET
DOTTY	ENDP

; End a Mail Link command being prepared for transmission

END_COMMAND	PROC NEAR	; AH = command type
	MOV	DI,OFFSET XM_BUFFER	; prepare message in transmit buffer
	PUSH	DI
	MOV	SI,OFFSET ENDER		; SI -> '/END '
	MOV	CX,L_ENDER
	REP	MOVSB
	CALL	KEY			; get SI -> key name
	CALL	COPY_STRING		; copy key up to null
	POP	SI			; SI -> XM_BUFFER
	JMP	SENDER			; append checksum and transmit
END_COMMAND ENDP

; Handle a received ENV command

ENVELOPE	PROC	NEAR
	MOV	AX,MAILIN		; set up incoming mail file
	MOV	WRITE_HANDLE,AX
	INC	ECHO_LINE		; echo envelope to screen
	CALL	RECEIVE_MESSAGE
	DEC	ECHO_LINE
	MOV	SI,OFFSET EOE		; append a blank line
	CALL	WRITELINE
	XOR	BX,BX			; no text in reply
	RET
ENVELOPE	ENDP

ERROR	PROC	NEAR	; DX -> diagnostic message
	POP	AX			; AX = return address
	MOV	ERROR_AT,AX
	MOV	AH,9			; display the message
	INT	21H
	JMP	CLEAN			; disconnect
ERROR	ENDP

; Check if buffer needs to be flushed during "binary" transmission

FLUSH_CHECK	PROC	NEAR	; SI -> start of buffer, DI -> next byte
	CMP	DI,OFFSET XM_BUFFER+195
	JB	.FC1			; if < 195 chars in buffer
	MOV	AL,'%'			; else append a delimited CR/LF
	STOSB
	CALL	APPEND_CRLF
	CALL	TRANSMIT		; flush the buffer and reset SI and DI
	CALL	DOTTY

.FC1:	RET
FLUSH_CHECK	ENDP

; Fold a line of text to uppercase

FOLDUP	PROC	NEAR	; SI -> null-terminated text
	PUSH	SI
	MOV	DI,SI

.FU1:	LODSB				; AL = next character
	CMP	AL,'a'			; skip if not lowercase alphabetic
	JL	.FU2
	CMP	AL,'z'
	JG	.FU2
	SUB	AL,'a' - 'A'

.FU2:	STOSB				; re-store letter even if not changed
	TEST	AL,AL			; test for end of line
	JNZ	.FU1
	POP	SI
	RET
FOLDUP	ENDP		; returns SI -> text

; Decode a decimal integer

GETDEC	PROC	NEAR	; SI -> string to be decoded,  AX = default value
	PUSH	AX			; save default
	CALL	SKIP_WHITESPACE		; skip any white space before the no.
	XOR	AX,AX
	MOV	BX,AX			; BX used to accumulate the result
	MOV	CX,AX			; CX used as character counter

GD1:	LODSB				; AL = next character
	CMP	AL,'0'			; stop when any non-digit is seen
	JB	GD2
	CMP	AL,'9'
	JA	GD2
	SUB	AL,'0'			; convert digit to binary
	CBW
	XCHG	AX,BX
	ADD	AX,AX			; multiply partial result by 10
	MOV	DX,AX
	ADD	AX,AX
	ADD	AX,AX
	ADD	AX,DX
	ADD	BX,AX			; then add in the new digit
	INC	CX			; count characters
	JMP	SHORT GD1

GD2:	XCHG	AX,BX
	TEST	CX,CX
	POP	CX			; CX = default value
	JNZ	GD3			; if length was non-zero
	MOV	AX,CX			; else return default value

GD3:	DEC	SI			; point SI to next character
	RET		; returns AX = decoded value, BL = terminator
GETDEC	ENDP

; Decode a hexadecimal number of a fixed number of characters

GETHEX	PROC	NEAR	; SI -> hex string to be decoded, CH = number of hexits
	XOR	AX,AX
	MOV	BX,AX		; BX will be used to accumulate the result
	MOV	CL,04H		; CH = char counter, CL = shift count

.GH1:	LODSB				; we assume, do not check, that each
	SUB	AL,'0'			;   character is a valid hexit
	CMP	AL,9
	JBE	.GH2			; if 0-9
	SUB	AL,7			; if A-F

.GH2:	SHL	BX,CL			; shift partial result by 4 bits
	ADD	BX,AX
	DEC	CH
	JNZ	.GH1
	MOV	AX,BX
	RET		; returns AX = decoded value, SI -> next character
GETHEX	ENDP

; Get a keypress without echo

GETKEY	PROC
	MOV	AH,7			; use DOS service 7
	INT	21H
	TEST	AL,AL			; ASCII code?
	JNZ	GET1
	MOV	AH,7			; no, get the rest of it
	INT	21H
	XOR	AH,AH			; set Z bit
GET1:	RET		; returns ZR = 0 if ASCII, ZR = 1 otherwise
GETKEY	ENDP

; Wait for, and process, the Mail Link reply to a command just sent

GET_REPLY	PROC	NEAR	; AL = reply type expected (ignored at present)
	CALL	RECEIVE_MESSAGE
	CMP	AL,MT_REPLY		; should be a reply
	JNE	.GR_PF			; if not...
	MOV	BX,OFFSET MESSAGE_KEYS	; determine reply type
	CALL	MATCH
	JNZ	.GR1			; if not recognizable type
	MOV	AX,100			; assume good reply
	CALL	GETDEC			; get reply code
	PUSH	AX
	CMP	AX,100			; echo reply if not type 100
	JE	.GR2

.GR1:	INC	ECHO_LINE

.GR2:	CALL	RECEIVE_MESSAGE		; wait for END
	CMP	AL,MT_END
	JNE	.GR_PF
	XOR	AX,AX
	MOV	ECHO_LINE,AL
	POP	AX
	CMP	AX,100
	RET		; returns AX = numeric code in reply, ZR = AX==100

.GR_PF:	MOV	DX,OFFSET PFMSG		; protocol failure:  invalid message received
	CALL	ERROR
GET_REPLY	ENDP

; Interpret a received Mail Link message

INTERPRET_PROTOCOL_LINE	PROC	NEAR	; SI -> line, DI -> end of line
	SUB	DI,2			; assume line ends with CR/LF
	XOR	AX,AX
	STOSB				; overwrite CR with null
	INC	SI			; point SI to first char past the /
	MOV	BX,OFFSET MESSAGE_KEYS
	CALL	MATCH			; try to match message key
	JNZ	.IPL3			; if not recognized
	PUSH	AX
	CMP	AL,MT_END		; an END?
	JNE	.IPL1
	CALL	SKIP_WHITESPACE		; yes, skip past command type
	MOV	BX,OFFSET MESSAGE_KEYS
	CALL	MATCH			; by matching message key

.IPL1:	CALL	SKIP_WHITESPACE		; skip to checksum marker
	CMP	AL,'*'
	JNE	.IPL2
	INC	SI
	MOV	CH,4			; decode a four-character hex number
	CALL	GETHEX
	SUB	STARSUM,AX
.IPL2:	POP	AX
	RET

.IPL3:	MOV	DX,OFFSET PFMSG		; tell user we got a bad message
	CALL	ERROR
INTERPRET_PROTOCOL_LINE	ENDP

; Look up a message name from the table given an id

KEY	PROC	NEAR	; AH = key id
	PUSH	DI
	MOV	DI,OFFSET MESSAGE_KEYS	; DI -> message name table
	XOR	AL,AL
	
.KEY1:	TEST	AH,AH			; look up message type
	JZ	.KEY2
	DEC	AH
	MOV	CX,0FFFFH
	REPNZ	SCASB			; scan to next message
	JMP	SHORT .KEY1

.KEY2:	MOV	SI,DI			; SI -> key
	POP	DI
	RET		; returns SI -> key name
KEY	ENDP

; Submit the piece of mail from the active file

MAILER	PROC	NEAR	; DX -> filename
	CALL	TTY$			; tell user what's up[loading]
	DW	OFFSET UPMSG
	MOV	BX,DX			; BX -> filename
	CALL	TTYZ
	MOV	AH,MT_CREATE		; start by sending a CREATE command
	CALL	MAKE_COMMAND
	CALL	SENDER
	CALL	GET_REPLY
	JNE	.MR25			; if bad reply came ack (.MR7 is far)
	MOV	AH,MT_ENV		; then comes the envelope
	CALL	MAKE_COMMAND
	CALL	APPEND_CRLF
	CALL	TRANSMIT

.MR1:	MOV	BX,READ_HANDLE
	CALL	READLINE		; read next line from the file
	JC	.MR2			; if read error
	CALL	SKIP_WHITESPACE
	TEST	AL,AL
	JZ	.MR2			; zero-length line => end of envelope
	MOV	DI,OFFSET XM_BUFFER	; DI-> transmit buffer
	CALL	COPY_ASCII		; map to approved ASCII
	CALL	APPEND_CRLF
	CALL	TRANSMIT
	CALL	DOTTY			; drive user dotty
	JMP	SHORT .MR1

.MR2:	MOV	AH,MT_ENV		; send the END ENV
	CALL	END_COMMAND
	CALL	GET_REPLY

.MR25:	JNE	.MR7			; if bad reply came back
	MOV	AH,MT_TEXT		; send a TEXT ASCII command
	CALL	MAKE_COMMAND
	MOV	AL,' '
	STOSB
	MOV	SI,OFFSET K_ASCII
	CALL	COPY_STRING
	CALL	APPEND_CRLF
	MOV	SI,OFFSET XM_BUFFER
	CALL	TRANSMIT

.MR3:	MOV	BX,READ_HANDLE		; read each line of the message text
	CALL	READLINE
	JC	.MR4			; if EOF
	CMP	BYTE PTR [SI],ATTESC	; attachment escape?
	JE	.MR4
	MOV	DI,OFFSET XM_BUFFER
	CALL	COPY_ASCII		; map characters
	CALL	APPEND_CRLF		; end the line
	CALL	TRANSMIT		; and send it off
	CALL	DOTTY			; display one dot per line
	JMP	SHORT .MR3

.MR4:	PUSH	SI
	MOV	AH,MT_TEXT		; send an END TEXT
	CALL	END_COMMAND
	CALL	GET_REPLY
	JNE	.MR7			; if bad reply came back
	CALL	TTY$			; end the dot stream neatly
	DW	OFFSET CRLF
	POP	SI

.MR45:	CMP	BYTE PTR [SI],ATTESC	; attachment escape?
	JNE	.MR6

.MR5:	CALL	ATTACH_FILE		; attach a file to the message
	MOV	BX,READ_HANDLE
	CALL	READLINE		; then read next line
	JNC	.MR45			; if not EOF

.MR6:	MOV	AH,MT_SEND		; send a SEND command
	CALL	MAKE_COMMAND
	CALL	SENDER
	CALL	GET_REPLY

.MR7:	RET	; returns ZR = 1 if mail was successfully sent
MAILER	ENDP

; Prepare a Mail Link command header for transmission

MAKE_COMMAND	PROC	NEAR	; AH = command type
	CALL	KEY			; get SI -> key name
	MOV	DI,OFFSET XM_BUFFER	; prepare message in transmit buffer
	PUSH	DI
	MOV	BYTE PTR ES:[DI],'/'	; start with a '/'
	INC	DI
	CALL	COPY_STRING		; copy key up to null
	XOR	AX,AX			; reset checksum
	MOV	CHECKSUM,AX
	POP	SI			; SI -> xm_buffer
	RET		; returns SI -> xm_buffer, DI -> next character slot
MAKE_COMMAND ENDP

; Map a byte for binary transmission.  (Called by COPY_BINARY)

MAP_BYTE	PROC	NEAR	; AL = byte, DI -> buffer
	MOV	AH,AL			; AH = ASCII code for puthex
	MOV	AL,'%'
	STOSB
	MOV	CH,2
	CALL	PUTHEX
	JMP	FLUSH_CHECK
MAP_BYTE	ENDP

; Play master role in Mail Link exchange

MASTER	PROC	NEAR
	INC	MASTERED		; record that we have played this role

	MOV	AL,SLAVED		; are we doing this first or second?
	TEST	AL,AL
	JNZ	.MA1			; if we slaved already

	MOV	ECHO_LINE,AL		; turn off echoing to start
	CALL	RECEIVE_MESSAGE		; assume we get a REPLY INIT
	CALL	RECEIVE_LINE		; Should be "Request performed..."
	INC	ECHO_LINE		; echo rest of reply
	CALL	RECEIVE_MESSAGE
	DEC	ECHO_LINE

	CALL	OUTGOING		; send any outgoing mail

	MOV	AH,MT_TURN		; then send a TURN command
	CALL	MAKE_COMMAND		;   to switch roles
	CALL	SENDER
	CALL	GET_REPLY
	JMP	SLAVE			; time to do our slaving

.MA1:	CALL	OUTGOING		; send any outgoing messages

	MOV	AH,MT_TERM		; then terminate
	CALL	MAKE_COMMAND
	CALL	SENDER
	CALL	GET_REPLY
	RET
MASTER	ENDP

; Match a string to a set of keys

MATCH	PROC	NEAR	; BX -> list of keys, SI -> string to be matched
	CALL	SKIP_WHITESPACE		; skip any leading blanks
	MOV	DI,SI			; SI, DI -> first non-white char
	XOR	CX,CX			; count keys in CX

.MAT1:	MOV	SI,DI			; SI -> target of match

.MAT2:	CMP	BYTE PTR [BX],0		; check for end of table
	JE	.MAT5
	LODSB				; AL = next character of string
	CMP	AL,' '			; match up to blank or control
	JBE	.MAT4
	CMP	AL,[BX]
	PUSHF
	INC	BX
	POPF
	JE	.MAT2

.MAT3:	CMP	BYTE PTR [BX],0
	PUSHF
	INC	BX
	POPF
	JNZ	.MAT3
	INC	CX
	CMP	BYTE PTR [BX],0
	JNZ	.MAT1
	INC	CX
	RET				; return with ZR = 0

.MAT4:	DEC	SI
	CMP	BYTE PTR [BX],0

.MAT5:	MOV	AX,CX
	RET		; returns ZR = 1 if match, AX = key number
			;		and SI -> character past key
MATCH	ENDP

; Normalize translates a null-terminated string containing control characters
; in the form '^X'

NORMALIZE	PROC	NEAR	; SI -> null-terminated string
	PUSH	SI
	MOV	DI,SI

.NOR1:	LODSB				; AL = next character
	MOV	ES:[DI],AL		; re-store in string
	OR	AL,AL
	JZ	.NOR3			; if end of string
	CMP	AL,' '
	JB	.NOR1			; ignore "real" control characters
	CMP	AL,'^'
	JNE	.NOR2
	LODSB
	CMP	AL,'^'			; ^^ means ^
	JE	.NOR2
	AND	AL,1FH			; make a control

.NOR2:	STOSB				; and store into string
	JMP	SHORT .NOR1

.NOR3:	POP	SI
	MOV	BX,SI
	MOV	CX,DI			; calculate new length
	SUB	CX,BX
	RET		; returns BX = SI -> normalized string, CX = length
			;	DI -> end of string
NORMALIZE ENDP

; Display a message about a file-open error and quit

OPEN_ERROR	PROC	NEAR	; DX -> filename
	CALL	TTY$			; say "Cannot open file: "
	DW	OFFSET OPENMSG
	MOV	BX,DX			; and announce the filename
	CALL	TTYZ
	JMP	CLEAN			; then quit
OPEN_ERROR	ENDP

; Send any outgoing mail

OUTGOING	PROC	NEAR
	MOV	AH,4EH			; DOS find first matching file function
	MOV	DX,OFFSET OUTFN		; look for "*.OUT"

.OG1:	INT	21H			; find first/next matching dir entry
	JC	.OG3			; if error or no more files
	MOV	AH,2FH			; DOS get disk transfer address
	INT	21H			; returns BX -> DTA
	MOV	DX,BX
	ADD	DX,30			; DX -> filename
	MOV	AX,3D00H		; open read-only
	INT	21H
	MOV	READ_HANDLE,AX
	JC	.OG2			; if open failed

	PUSH	DX			; save pointer to name
	CALL	MAILER			; mail the file
	PUSHF				; save result flags
	MOV	AH,3EH			; DOS close function
	MOV	BX,READ_HANDLE
	INT	21H
	POPF				; did mailer succeed?
	POP	SI			; SI -> filename
	JNZ	.OG2			; no...
	PUSH	SI
	MOV	DI,OFFSET FILENAME
	PUSH	DI

.OG15:	LODSB				; rename the file with extension "MLD"
	STOSB
	CMP	AL,'.'
	JNE	.OG15

	MOV	SI,OFFSET RENAME
	MOV	CX,4
	REP	MOVSB

	MOV	AH,41H			; delete any already renamed file
	POP	DX
	INT	21H			; ignore errors

	MOV	AH,56H			; DOS rename file service
	MOV	DI,DX			; DI -> new name
	POP	DX			; DX -> old name
	INT	21H

.OG2:	MOV	AH,4FH			; DOS find next matching file
	JMP	SHORT .OG1

.OG3:	RET
OUTGOING	ENDP

; Encode a number into a 3-digit decimal ASCII string

PUTDEC	PROC	NEAR	; AX = number to be encoded, DI -> destination
	IDIV	BYTE PTR HUNDRED	; divide by 100
	ADD	AL,'0'
	STOSB
	MOV	AL,AH
	XOR	AH,AH
	IDIV	BYTE PTR TEN
	ADD	AX,'00'
	STOSW
	RET
PUTDEC	ENDP

; Encode a number into a hex string of a given number of characters

PUTHEX	PROC	NEAR	; AX = number, DI -> destination for encoded hex number
			; CH = number of hexits required (1 - 4)
	MOV	BX,AX			; keep target in BX
	MOV	CL,04H			; CH = char counter, CL = shift count

.PH1:	ROL	BX,CL
	MOV	AX,BX
	AND	AL,0FH			; mask off a nybble
	ADD	AL,'0'
	CMP	AL,'9'
	JBE	.PH2			; if 0 - 9
	ADD	AL,7			; if A - F

.PH2:	STOSB				; store into the string
	DEC	CH			; decrement the character counter
	JNZ	.PH1			; if more to go
	RET		; returns DI = updated pointer
PUTHEX	ENDP

; Read a byte from the send file

READ_BYTE	PROC	NEAR
	MOV	AH,3FH			; DOS read file function
	MOV	BX,SEND_HANDLE
	MOV	CX,1			; read one byte
	MOV	DX,OFFSET READ_POT	; into read_pot
	INT	21H
	JC	.RB1			; if error
	TEST	AX,AX
	JZ	.RB1			; zero count means end-of-file
	MOV	AL,READ_POT
	RET				; TEST sets CF = 0

.RB1:	STC
	RET	; returns CF set if error or EOF else AL = character
READ_BYTE	ENDP

; Read line from file to line_buffer

READLINE	PROC	NEAR	; BX = file handle
	MOV	SI,OFFSET LINE_BUFFER	; SI -> line_buffer
	MOV	DI,SI			; DI too
	MOV	CX,1			; read one byte at a time

.RE1:	MOV	AH,3FH			; DOS read function
	MOV	DX,SI			; DS:DX -> buffer
	INT	21H
	JC	.RE5			; if read error
	TEST	AX,AX
	JZ	.RE4			; if EOF
	AND	BYTE PTR [SI],07FH	; mask the character just read
	MOV	AL,[SI]			; AL = byte just read
	CMP	AL,' '			; control character?
	JB	.RE2			; if so
	INC	SI			; else bump buffer pointer
	CMP	SI,OFFSET LINE_BUFFER+79; and check for overflow
	JB	.RE1			; handle over-long lines ungracefully!

.RE3:	XOR	AX,AX			; null terminate the line
	MOV	[SI],AL
	MOV	CX,SI			; calculate its length
	MOV	SI,DI
	SUB	CX,SI			; CX = line length
	CLC
	RET		; return with CF zero and SI -> input, CX = length

.RE2:	CMP	AL,CR			; check for CR
	JNE	.RE1			; and discard other control characters
	JMP	SHORT .RE3		; end the line on CR

.RE4:	CMP	SI,DI			; accept a last line with no CR
	JNE	.RE3

.RE5:	STC
	RET		; EOF or read error, return with CF set
READLINE	ENDP

; Receive a char, mask to ASCII, echo to screen

RECEIVE_ASCII	PROC	NEAR
	CALL	RECEIVE_CHARACTER
	AND	AL,07FH
	PUSH	AX
	MOV	AH,0EH			; echo to screen
	INT	10H			; using BIOS tty write
	POP	AX
	RET
RECEIVE_ASCII	ENDP

; Receive a character from the line

RECEIVE_CHARACTER	PROC	NEAR

.RC1:	MOV	AH,84H			; read next input
	MOV	AL,COM_PORT
	INT	CINT
	JNZ	.RC2			; if input returned...

	CALL	TIMER
	JMP	SHORT .RC1		; if not expired

.RC2:	TEST	AL,AL			; ignore NULs (TYMNET sends a few)
	JZ	.RC1
	PUSH	AX
	MOV	READ_POT,AL		; save in memory
	MOV	DX,OFFSET READ_POT	; write to log file
	MOV	BX,LOGFH
	MOV	AH,40H
	MOV	CX,1
	INT	21H
	POP	AX
	XOR	AH,AH			; add into checksum
	ADD	CHECKSUM,AX
	RET		; returns AL = character
RECEIVE_CHARACTER	ENDP

; Receive a message from Mail Link partner

RECEIVE_LINE	PROC	NEAR
	MOV	DI,OFFSET RM_BUFFER	; read through this buffer
	PUSH	DI
	MOV	AX,364			; wait 20 seconds per line
	MOV	TIMEOUT,AX		; set timeout
	MOV	AX,LBS-2		; AX = buffer size - 2
	MOV	BUFFER_COUNTER,AX
	CALL	RECEIVE_CHARACTER
	PUSH	AX			; save initial character
	JMP	SHORT .RL2

.RL1:	CALL	RECEIVE_CHARACTER

.RL2:	STOSB				; store into buffer
	CMP	AL,'*'			; checksum delimiter?
	JNE	.RL3
	MOV	BX,CHECKSUM
	MOV	STARSUM,BX

.RL3:	CMP	AL,'%'			; expanded code?
	JNE	.RL4
	MOV	SI,DI			; SI -> hex code
	CALL	RECEIVE_CHARACTER
	STOSB
	CALL	RECEIVE_CHARACTER
	STOSB
	MOV	DI,SI
	DEC	DI
	CMP	AL,LF			; check for %/CR/LF
	JE	.RL5
	MOV	CH,2			; decode 2-character hex number
	CALL	GETHEX
	STOSB

.RL4:	CMP	AL,LF
	JE	.RL5
	MOV	AX,1
	SUB	BUFFER_COUNTER,AX
	JG	.RL1

.RL5:	XOR	AX,AX			; terminate with a NUL
	STOSB
	DEC	DI			; DI -> null terminator
	POP	AX
	POP	SI
	RET	; returns SI -> receive buffer, DI -> end of message
		;         AL = initial character
RECEIVE_LINE	ENDP

; Receive a Mail Link message

RECEIVE_MESSAGE	PROC	NEAR

.RM1:	CALL	RECEIVE_LINE
	CMP	AL,'/'			; is it a protocol line?
	JE	.RM2			; if so...
	CALL	WRITER
	TEST	BYTE PTR ECHO_LINE,0FFH
	JZ	.RM3
	MOV	BX,SI			; BX -> line
	CALL	TTYZ
	JMP	SHORT .RM1

.RM3:	TEST	BYTE PTR DOTTER,0FFH
	JZ	.RM1
	CALL	DOTTY
	JMP	SHORT .RM1

.RM2:	JMP	INTERPRET_PROTOCOL_LINE
RECEIVE_MESSAGE	ENDP	; returns AL = type number

; Read and interpret a script

SCRIPT	PROC	NEAR	; DX -> script file name
	MOV	AX,3D00H		; open script file for read
	INT	21H
	MOV	SCRIPT_HANDLE,AX
	JNC	.SC1
	JMP	OPEN_ERROR		; if open error reported

.SC1:	MOV	BX,SCRIPT_HANDLE	; read first/next line of the script
	CALL	READLINE
	JNC	.SC2
	RET				; return on end-of-file

.SC2:	LODSB				; AL = first character
	PUSH	AX			; save while decoding numeric argument
	XOR	AX,AX			; default is always 0
	CALL	GETDEC
	MOV	CX,AX			; CX = result
	MOV	BL,18			; convert ticks to seconds
	MUL	BL
	MOV	TIMEOUT,AX		; save for anyone that wants to use it
	CALL	SKIP_WHITESPACE
	CMP	AL,'"'			; quoted argument?
	JNE	.SC3			; if not assume okay
	INC	SI			; else push pointer past it
	PUSH	SI			; and look for closing quote

.SC25:	LODSB
	TEST	AL,AL			; no worry if there is none
	JZ	.SC28
	CMP	AL,'"'
	JNE	.SC25
	MOV	BYTE PTR [SI-1],0	; replace a closing quote with a NUL

.SC28:	POP	SI

.SC3:	POP	AX			; retrieve command key
	MOV	BX,OFFSET .SC1		; stack return address
	PUSH	BX			; make like a CALL
	CALL	SWITCHER		; with CX = numeric arg, SI -> next arg

SCRIPT_SWITCH	LABEL	BYTE
	DB	'B'			; bps rate
	DB	SCRIPT_BPS - SCRIPT_SWITCH
	DB	'C'			; comment
	DB	SCRIPT_COMMENT - SCRIPT_SWITCH
	DB	'D'			; delay
	DB	SCRIPT_DELAY - SCRIPT_SWITCH
	DB	'E'			; echo mode
	DB	SCRIPT_ECHO - SCRIPT_SWITCH
	DB	'M'			; master mode
	DB	SCRIPT_MASTER - SCRIPT_SWITCH
	DB	'P'			; set port
	DB	SCRIPT_PORT - SCRIPT_SWITCH
	DB	'S'			; slave mode
	DB	SCRIPT_SLAVE - SCRIPT_SWITCH
	DB	'T'			; transmit string
	DB	SCRIPT_TX - SCRIPT_SWITCH
	DB	'R'			; receive
	DB	SCRIPT_RX - SCRIPT_SWITCH
	DB	0
	DB	SCRIPT_ERROR - SCRIPT_SWITCH

SCRIPT_ERROR:
	CALL	TTY$
	DW	OFFSET CSERM		; "Error in connect script"
	POP	AX			; clean local return address
	RET

SCRIPT_BPS:				; reset line speed
	MOV	DI,OFFSET RM_BUFFER	; receive characters into rm_buffer
	MOV	SI,DI

.SB1:	CALL	RECEIVE_ASCII
	STOSB
	CMP	AL,CR			; until a CR is seen
	JNE	.SB1			; note there is no length check!

	MOV	AX,COM_SPEED		; AX = default speed
	CALL	GETDEC			; decode the new speed
	CMP	AX,COM_SPEED		; was it changed
	JE	.SB2			; skip if not
	MOV	COM_SPEED,AX		; record the new speed
	MOV	BX,AX			; BX = speed

	MOV	AH,8CH			; change speed on COM port
	MOV	AL,COM_PORT
	INT	CINT

.SB2:	RET

SCRIPT_COMMENT:				; display a comment on the screen
	CALL	NORMALIZE		; normalize the string
	JMP	TTYZ			; and display it

SCRIPT_PORT:				; set up COM-port parameters
	MOV	COM_PORT,CL		; port number already decoded into CX
	CALL	GETDEC			; decode the port speed
	MOV	COM_SPEED,AX		; record it
	MOV	BX,AX			; BX = speed for Couriers
	MOV	AH,82H			; configure COM port
	MOV	AL,COM_PORT
	MOV	CX,COM_OPTIONS
	INT	CINT

	MOV	AH,83H			; start input on port
	MOV	AL,COM_PORT
	MOV	BX,OFFSET FIFO
	MOV	CX,FIFOSIZE
	INT	CINT

; for unclear reasons a delay is required here so wait a sec or 4
	; fall through
SCRIPT_DELAY:				; delay N seconds
	CALL	DELAY
	RET

SCRIPT_ECHO:				; change mode for echoing received chars
	MOV	MODEM_ECHO,CL
.SEC1:	RET

SCRIPT_TX:				; transmit a string
	CALL	NORMALIZE		; normalize it
	TEST	BYTE PTR MODEM_ECHO,0FFH; echo mode on?
	JZ	.STX1			; skip if not
	MOV	DX,BX			; DX -> message
	MOV	BX,LOGFH		; write to log file
	MOV	AH,40H
	INT	21H

.STX1:	JMP	TRANSMIT		; shove it out the port

SCRIPT_RX:				; wait to receive a string
	CALL	NORMALIZE		; normalize the string expected
	JMP	WAITST			; and wait for it

SCRIPT_MASTER:				; start Mail Link processing as master
	JMP	MASTER

SCRIPT_SLAVE:				; start Mail Link processing as slave
	JMP	SLAVE
SCRIPT	ENDP

; Process a received SEND command

SEND	PROC	NEAR
	MOV	SI,OFFSET EOL		; end letter with some blank lines
	CALL	WRITELINE
	XOR	BX,BX			; no text in reply
	MOV	WRITE_HANDLE,BX		; write no more to file
	RET
SEND	ENDP

; Terminate and transmit a Mail Link message

SENDER	PROC	NEAR	; SI -> buffer, DI -> tail

; Append '*', calculate and append checksum, and terminate with CR/LF

	MOV	AL,'*'
	STOSB
	CALL	TRANSMIT		; transmit up to '*'
	MOV	SI,OFFSET XM_BUFFER	; encode checksum as a 4-char hex
	MOV	DI,SI
	MOV	AX,CHECKSUM
	MOV	CH,4
	CALL	PUTHEX
	CALL	APPEND_CRLF		; append CR/LF
	JMP	TRANSMIT		; and transmit that
SENDER	ENDP

; Send a file as a binary attachment to a mail message

SEND_FILE	PROC	NEAR	; BX = file handle, SI -> attachment note
	MOV	SEND_HANDLE,BX
	PUSH	SI
	MOV	AH,MT_TEXT		; make a TEXT command
	CALL	MAKE_COMMAND
	MOV	AL,' '			; append a blank
	STOSB
	MOV	SI,OFFSET K_BINARY	; say it's BINARY
	CALL	COPY_STRING
	MOV	AL,':'
	STOSB
	POP	SI
	CALL	COPY_STRING		; and copy the note
	CALL	APPEND_CRLF
	MOV	SI,OFFSET XM_BUFFER
	CALL	TRANSMIT		; send the first line
	CALL	COPY_BINARY		; copy the file
	MOV	AH,MT_TEXT		; send END TEXT
	CALL	END_COMMAND
	CALL	TTY$			; terminate dot stream on screen
	DW	OFFSET CRLF
	JMP	GET_REPLY		; get TEXT reply
SEND_FILE ENDP

; Send a Mail Link reply

SEND_REPLY	PROC	NEAR	; AX = code (normally 100), BX -> text
	PUSH	AX
	MOV	AH,COMMAND_TYPE		; AH = command id
	CALL	KEY			; get SI -> key name
	PUSH	SI			; save -> message key
	MOV	DI,OFFSET REPLY_BUFFER	; prepare message in reply buffer
	MOV	SI,OFFSET REPLY_HEAD	; copy in "/REPLY "
	MOV	CX,L_REPLY_HEAD
	REP	MOVSB

	POP	SI
	CALL	COPY_STRING		; copy key up to null
	MOV	AL,' '			; need a space after this
	STOSB
	POP	AX			; retrieve code
	CALL	PUTDEC			; encode it
	CALL	APPEND_CRLF		; that does the first line
	TEST	BX,BX			; any text?
	JZ	.SR6			; if not
	MOV	SI,BX
	CALL	COPY_ASCII

.SR6:	CALL	APPEND_CRLF		; that makes the second line
	MOV	SI,OFFSET REPLY_TAIL	; third line is "/END REPLY..."
	MOV	CX,L_REPLY_TAIL
	REP	MOVSB
	XOR	AX,AX			; append temporary null end marker
	MOV	BYTE PTR ES:[DI],AL
	MOV	CHECKSUM,AX		; and reset checksum
	MOV	SI,OFFSET REPLY_BUFFER
	JMP	SENDER			; join common message-send code
SEND_REPLY ENDP

; Skip over blanks and tabs in a string

SKIP_WHITESPACE	PROC	NEAR	; SI -> string

.SW1:	LODSB				; AL = next character
	CMP	AL,' '
	JE	.SW1			; if it's a space
	CMP	AL,09H
	JE	.SW1			; if it's a tab
	DEC	SI			; else SI -> first non-white
	RET		; returns SI -> first non-white char, AL = said char
SKIP_WHITESPACE	ENDP

; Play slave role in Mail Link exchange

SLAVE	PROC	NEAR
	INC	SLAVED			; record that we have slaved

.SL1:	XOR	AX,AX			; reset checksum
	MOV	CHECKSUM,AX
	CALL	RECEIVE_MESSAGE		; receive a Mail Link command

	MOV	COMMAND_TYPE,AL		; save the command id
	MOV	BX,OFFSET SLAVE_SWITCH	; switch to command handler
	ADD	BX,AX
	ADD	BX,AX
	MOV	BX,[BX]
	TEST	BX,BX
	JZ	.SL1			; entry can be noop
	CALL	BX			; returns BX -> reply text
	MOV	AX,STARSUM		; was checksum correct?
	TEST	AX,AX
	PUSHF
	MOV	AX,100			; assume normal reply
	JZ	.SL2			; if checksum okay
	MOV	AX,403			; else send a REPLY 403 "Checksum error"
	MOV	BX,OFFSET CKERROR

.SL2:	CALL	SEND_REPLY		; reply to command
	POPF
	JZ	.SL1			; if checksum was okay
	MOV	DX,OFFSET BADMSG	; protocol message with bad checksum received
	CALL	ERROR
SLAVE	ENDP

; Perform a computer switch through a jump table

SWITCHER	PROC	NEAR	; AL = code, [SP] -> switch table
	CLD
	POP	BX			; BX -> switch table
	PUSH	SI
	MOV	SI,BX			; SI -> switch table
	MOV	AH,AL			; AH = switch code
	DEC	SI

SW1:	INC	SI
	LODSB				; AL = code to match
	TEST	AL,AL
	JZ	SW2			; if end of list
	CMP	AL,AH
	JNE	SW1

SW2:	XOR	AX,AX			; prepare AX for byte offset
	LODSB
	ADD	BX,AX			; from base of switch
	POP	SI
	JMP	BX
SWITCHER	ENDP

; Process a TEXT command

TEXT	PROC	NEAR
	MOV	AX,MAILIN		; set up incoming mail file
	MOV	WRITE_HANDLE,AX
	INC	DOTTER			; show user we're busy
	CALL	SKIP_WHITESPACE		; skip to text-type field
	TEST	AL,AL			; but there may not be one
	JZ	.TE4			; in which case it is treated as ASCII
	MOV	BX,OFFSET TEXT_KEYS	; is it ASCII or BINARY?
	CALL	MATCH
	JNZ	.TE4			; if unknown, treat as ASCII
	TEST	AX,AX
	JZ	.TE4			; if ASCII
					; process a BINARY attachment
	INC	SI			; normally a colon follows
	PUSH	SI			; save -> attachment name
	CALL	TTY$			; say we're downloading an attachment
	DW	OFFSET DOWNAT
	MOV	SI,OFFSET ATTACHMENT	; note attachment in the mail file
	CALL	WRITELINE
	POP	SI
	CALL	WRITELINE
	MOV	DX,SI			; DX -> filename from message
	MOV	AX,4300H		; see if it exists
	INT	21H
	JC	.TE3			; if it does not exist use this name

.TE2:	MOV	AH,2CH			; else get time of day from DOS
	INT	21H			;  to use in generating a filename
	MOV	AX,CX
	ADD	AX,DX
	MOV	CH,3
	MOV	DI,OFFSET ATTACH_EXT
	CALL	PUTHEX

	MOV	DX,OFFSET ATTACH_FN	; DX -> filename

.TE3:	MOV	AH,3CH			; DOS create file function
	XOR	CX,CX			; zero attributes
	INT	21H
	JC	.TE2			; if open failed
	MOV	WRITE_HANDLE,AX
	MOV	SI,DX			; SI -> filename
	MOV	DI,OFFSET FILENAME	; copy for later use
	PUSH	DI
	CALL	COPY_STRING
	CALL	RECEIVE_MESSAGE
	MOV	AH,3EH			; DOS close function
	MOV	BX,WRITE_HANDLE
	INT	21H
	MOV	AX,MAILIN		; note attachment within the mail
	MOV	WRITE_HANDLE,AX
	MOV	SI,OFFSET TOFILE
	CALL	WRITELINE
	POP	SI			; SI -> filename
	CALL	WRITELINE
	JMP	SHORT .TE5

.TE4:	CALL	TTY$			; say we're downloading a message
	DW	OFFSET DOWNER
	CALL	RECEIVE_MESSAGE

.TE5:	DEC	DOTTER
	CALL	TTY$
	DW	OFFSET CRLF
	XOR	BX,BX			; no text in reply
	RET

.TE6:	MOV	DX,OFFSET PFMSG		; note an unrecognized command
	CALL	ERROR
TEXT	ENDP

; Count down ticks in TIMEOUT

TIMER	PROC	NEAR
	XOR	AX,AX
	CMP	AX,TIMEOUT		; zero period
	JZ	.TIM1			; means wait forever

	PUSH	DS
	MOV	DS,AX
	MOV	AX,DS:[CLOCK]
	POP	DS
	CMP	AX,TIME
	JE	.TIM1
	MOV	TIME,AX
	DEC	TIMEOUT
	JZ	.TIM3			; if timer expired

.TIM1:	MOV	AH,1			; check for keyboard input
	INT	16H			; using the BIOS
	JZ	.TIM2			; if no keyboard action
	CALL	GETKEY			; else read the character
	CMP	AL,ESCAPE		; is it an an Escape?
	JNE	.TIM2			; ignore anything else
	MOV	DX,OFFSET INMSG		; interrupted message
	CALL	ERROR

.TIM2:	RET

.TIM3:	MOV	DX,OFFSET TOMSG		; tell user we timed out
	CALL	ERROR
TIMER	ENDP		; returns only if timer not expired

; Transmit some data

TRANSMIT	PROC	NEAR	; SI -> start of buffer, DI -> end of buffer
	MOV	AX,1092			; wait a minute for transmit to complete
	MOV	TIMEOUT,AX
	MOV	BYTE PTR [DI],0		; ensure data is zero terminated
	MOV	BX,SI			; BX -> buffer
	MOV	CX,DI			; calculate length of buffer
	SUB	CX,SI
	MOV	AH,86H			; start output
	MOV	AL,COM_PORT
	INT	CINT

	MOV	DX,BX			; DX -> message
	MOV	BX,LOGFH		; write to log file
	MOV	AH,40H
	INT	21H

	CALL	CALCULATE_CHECKSUM	; gather checksum while transmitting

.TX1:	MOV	AH,87H			; wait until output is done
	MOV	AL,COM_PORT
	INT	CINT
	JZ	.TX2
	CALL	TIMER
	JMP	SHORT .TX1

.TX2:	MOV	DI,SI
	RET		; returns SI = DI -> start of buffer
TRANSMIT ENDP

; Display a null-terminated string

TTYZ	PROC	NEAR	; BX -> string
	PUSH	BX

.TZ1:	MOV	AL,[BX]			; do it one character at a time
	INC	BX
	TEST	AL,AL
	JZ	.TZ2
	MOV	AH,0EH			; suing the BIOS
	INT	10H
	JMP	SHORT .TZ1

.TZ2:	POP	BX
	RET
TTYZ	ENDP

; Display a '$'-terminated message

TTY$	PROC	NEAR	; (SP) -> address of '$'-terminated message
	POP	SI
	PUSH	AX
	PUSH	DX
	LODSW				; AX -> message
	MOV	DX,AX
	MOV	AH,09H			; use DOS service 9
	INT	21H
	POP	DX
	POP	AX
	JMP	SI
TTY$	ENDP

; Process a received TURN command

TURN	PROC	NEAR
	XOR	BX,BX			; reply
	MOV	AX,100
	CALL	SEND_REPLY
	POP	AX			; discard return address
	JMP	MASTER
TURN	ENDP

; Wait for a given string to be received or for a timeout

WAITST	PROC	NEAR	; BX -> string to wait for (null terminated), timeout set
	MOV	BP,BX			; BP -> target string

.WST1:	MOV	SI,BP			; SI -> string

.WST2:	CALL	RECEIVE_ASCII

	MOV	CL,AL			; CL = character
	TEST	BYTE PTR MODEM_ECHO,0FFH; don't echo if echo is OFF
	JZ	.WST3

	MOV	AH,89H			; output a single character (in CL)
	MOV	AL,COM_PORT
	INT	CINT

.WST3:	LODSB
	CMP	CL,AL			; is it character we want?
	JNE	.WST1			; no
	TEST	BYTE PTR [SI],0FFH
	JNZ	.WST2			; more to go...
	RET
WAITST	ENDP

; Write a line to the current file

WRITELINE	PROC	NEAR	; SI -> null-terminated string
	MOV	DI,SI
	XOR	AX,AX
	MOV	CX,0FFFFH
	REPNE	SCASB
	DEC	DI
;	fall through to WRITER
WRITELINE	ENDP
; Write received-message contents to current file
WRITER	PROC	NEAR	; SI -> line buffer, DI -> last character stored + 1
	MOV	AH,40H			; DOS write function
	MOV	DX,SI			; DX -> line
	MOV	CX,DI			; calculate CX = length
	SUB	CX,DX
	JZ	.WR1
	MOV	BX,WRITE_HANDLE
	TEST	BX,BX
	JZ	.WR1			; zero handle => no file open
	INT	21H

.WR1:	RET
WRITER	ENDP

; User parameters for COM port settings

COM_PORT	DB	0	; COM-port number (1, 2, 3, or 4)
COM_SPEED	DW	0	; speed in bps
COM_OPTIONS	DW	3H	; use both input and output flow control

; Filenames and messages

CSFN		DB	'1STCLASS.CSF',0
INFN		DB	'MAIL.IN',0
OUTFN		DB	'*.OUT',0
RENAME		DB	'MLD',0
LOGFN		DB	'1STCLASS.LOG',0
ATTACH_FN	DB	'ATTACHED.'
ATTACH_EXT	DB	'XYZ',0

; Messages

INITMSG	DB	'1stClass 1.0 (c) 1989 Ziff Communications Co.',CR,LF
	DB	'PC Magazine * Pete Maclean',CR,LF,'$'

NOTE	DB	'NOTICE: This software was developed, in part, using, with' 
	DB	'permission, proprietary, trade secret information of MCI'
	DB	'Telecommunications Corporation.  The user agrees to use this'
	DB	'program only for the purpose of communicating with MCI Mail.$'

LOADMSG	DB	'Please load Couriers.$'
TOMSG	DB	BELL,CR,LF,'***TIMED OUT***$'
INMSG	DB	BELL,CR,LF,'***Interrupted by user***$'
PFMSG	DB	BELL,CR,LF,'***Protocol failure: unrecognized message received***$'
BADMSG	DB	BELL,CR,LF,'***Message received with bad checksum***$'
INSTMSG	DB	BELL,'Ignoring unrecognized !COMMAND:',CR,LF,'$'
OPENMSG	DB	BELL,CR,LF,'Cannot open file: $'
CSERM	DB	BELL,CR,LF,'Unknown script command$'
CRLF	DB	CR,LF,'$'
UPMSG	DB	'Uploading $'
ATMSG	DB	'Attaching $'
DOWNAT	DB	'Downloading attachment$'
DOWNER	DB	'Downloading message$'

; Odd strings

ATTACHMENT	DB	CR,LF,'ATTACHMENT:  ',0
EOL		DB	CR,LF,CR,LF			; end of letter...
EOE		DB	CR,LF,0				; end of envelope
TOFILE		DB	CR,LF,'STORED ON FILE:  ',0

; Message keys

MESSAGE_KEYS	LABEL	BYTE
	DB	'COMMENT',0,'CREATE',0,'END',0,'ENV',0,'INIT',0,'REPLY',0
	DB	'RESET',0,'SEND',0,'TERM',0,'TEXT',0,'TURN',0,0

; Text types

TEXT_KEYS	LABEL	BYTE
K_ASCII		DB	'ASCII',0
K_BINARY	DB	'BINARY',0,0

; Escape instructions

INST_KEYS	LABEL	BYTE
I_ATTACH	DB	'ATTACH',0,0

; Code switch for slave processing

SLAVE_SWITCH	LABEL	WORD
	DW	OFFSET COMMENTARY	; COMMENT
	DW	OFFSET CREATE		; CREATE
	DW	0			; END
	DW	OFFSET ENVELOPE		; ENV
	DW	0			; INIT
	DW	0			; REPLY
	DW	OFFSET COMMENTARY	; RESET
	DW	OFFSET SEND		; SEND
	DW	0			; TERM
	DW	OFFSET TEXT		; TEXT
	DW	OFFSET TURN		; TURN

; Mail Link reply text

CKERROR		DB	'Checksum error',0

ENDER		DB	'/END '
L_ENDER		=	$ - ENDER

REPLY_HEAD	DB	'/REPLY '
L_REPLY_HEAD	=	$ - REPLY_HEAD

REPLY_TAIL	DB	'/END REPLY'
L_REPLY_TAIL	=	$ - REPLY_TAIL

; Numeric constants

HUNDRED		DB	100
TEN		DB	10

; Miscellaneous variables

BUFFER_COUNTER	DW	0	; for counting characters in READLINE
CHECKSUM	DW	0	; for checksums
COMMAND_TYPE	DB	0	; Mail Link command type, MT_XXXX
DOTTER		DB	0	; ? show download progress with dots
MODEM_ECHO	DB	0	; ? echo received characters (like a modem does)
				; (applies only in script handler)
ECHO_LINE	DB	0	; ? echo received lines to screen
ERROR_AT	DW	0	; error address (for debugging)
FILENAME	DB	65 DUP (?)
LOGFH		DW	0	; file handle for log
MAILIN		DW	0	; handle for incoming mail file
MASTERED	DB	0	; ? played Mail Link master role
MESSAGE_LENGTH	DW	0	; length of a received message
SCRIPT_HANDLE	DW	0	; handle for script file
SEND_HANDLE	DW	0	; handle for a send file
READ_HANDLE	DW	0	; handle for reading mail and attachment files
READ_POT	DB	0	; copy of last character received
SLAVED		DB	0	; ? played Mail Link slave role
STARSUM		DW	0	; received checksum saved at '*'
TIMEOUT		DW	0	; timeout counter
TIME		DW	0	; last time read from system clock
WRITE_HANDLE	DW	0	; handle for file being written

; Buffers

FIFO		LABEL	BYTE
LINE_BUFFER	=	FIFO + FIFOSIZE		; text-line buffer
RM_BUFFER	=	LINE_BUFFER + SBS	; receive message buffer
XM_BUFFER	=	RM_BUFFER + LBS		; transmit message buffer
REPLY_BUFFER	=	XM_BUFFER + LBS		; Mail Link reply buffer (LBS bytes)

PSEG	ENDS
	END	ENTRY
