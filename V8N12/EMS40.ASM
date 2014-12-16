;============================================================================
;EMS40.SYS an Expanded Memory Simulator for the IBM AT
;============================================================================
		PAGE	,132
CODE		SEGMENT PUBLIC'code'
		ASSUME	CS:CODE
;-----------------------------------------------------------------------------
;Structure of the device driver request header
;-----------------------------------------------------------------------------
REQ_STRUC	STRUC
LEN		DB	?
UNIT		DB	?			;unit number
COMMAND		DB	?			;command code
STATUS		DW	?			;return status
RESERVE		DB	8 DUP (?)
MEDIA		DB	?
ADDRESS		DD	?			;Transfer address
CONFIG_PTR	DD	?			;Pointer to line in config
REQ_STRUC	ENDS
;-----------------------------------------------------------------------------
;Segment descriptor structure
;-----------------------------------------------------------------------------
DAT_SEG_DES	STRUC				;data segment descriptor
SEG_LIM		DW	0			;length of segment
BASE_ADRL	DW	0			;base address of segment
BASE_ADRH	DB	0
		DB	0			;access rights byte
		DW	0			;reserved
DAT_SEG_DES	ENDS
;=============================================================================
;Device header begin
;=============================================================================
		ORG	0			;drivers start at offset 0
HEADER		DD	-1                      ;Pointer to next driver
		DW	8000H			;device attribute word
		DW	OFFSET STRATEGY		;pointer to strategy routine
		DW	OFFSET INTERRUPT        ;pointer to interrupt routine
		DB	'EMMXXXX0'		;name of driver
;Device header end
SWAP_POINTER	DW	OFFSET EMS_EXCH_PAG
PROGRAM		DB	"EMS 4.0 Simulator"
COPYRIGHT	DB	" (C) 1989 Ziff Communications",13,10
PROGRAMMER	DB	"PC Magazine ",254," Douglas Boling",13,10,"$",26
REQ_HEADADR	DD	?			;Far pointer to request header
;-----------------------------------------------------------------------------
;Global Descriptor table needed for moves to and from extended memory.
;-----------------------------------------------------------------------------
GDT		LABEL	BYTE
		DAT_SEG_DES <>			;Dummy
		DAT_SEG_DES <>			;GDT descriptor
SOURCE		DAT_SEG_DES <4000H,,,93H,>	;source descriptor
DEST		DAT_SEG_DES <4000H,,,93H,>	;destination descriptor
		DAT_SEG_DES <>			;bios code descriptor
		DAT_SEG_DES <>			;stack segment descriptor
;=============================================================================
;Strategy routine. This routine stores the address of the request header
;=============================================================================
STRATEGY	PROC	FAR
		ASSUME CS:CODE,DS:NOTHING,ES:NOTHING
		MOV	WORD PTR CS:[REQ_HEADADR],BX	;save offset
		MOV	WORD PTR CS:[REQ_HEADADR+2],ES	;save segment
		RET
STRATEGY	ENDP
;=============================================================================
;Interrupt routine. This routine executes the command code in the req header.
;=============================================================================
INTERRUPT	PROC	FAR
		ASSUME CS:CODE,DS:NOTHING,ES:NOTHING
		PUSHF
		PUSH	AX			;save every register used
		PUSH	BX
		PUSH	CX
		PUSH	DX
		PUSH	DI
		PUSH	SI
		PUSH	DS
		PUSH	ES
		PUSH	CS			;Set DS
		POP	DS
		ASSUME DS:CODE
		CLD				;any string operations move up.
;Get command from request header
		LES	DI,[REQ_HEADADR]	;load address of req header
		ASSUME	ES:NOTHING
		MOV	BL,ES:[DI.COMMAND]
		CMP	BL,0
		JNE	PROCESS1
		CALL	INITIALIZE
		JMP	SHORT DONE
PROCESS1:	CMP	BL,16			;see if command out of range
		JBE	DONE
		MOV	AX,8003H		;unknown command error code
DONE:		OR	AX,0100H		;set the 'done' bit
		MOV	ES:[DI.STATUS],AX
		POP	ES			;restore registers before exit
		POP	DS
		POP	SI
		POP	DI
		POP	DX
		POP	CX
		POP	BX
		POP	AX
		POPF
		RET
INTERRUPT	ENDP
DRIVER_END	=	$			;Last part of driver code
;======================================================================
;EMS Driver code starts here.
;======================================================================
OLD_INT15H	LABEL DWORD
OLD_INT15HO	DW	?			;offset of old interrupt vector
OLD_INT15HS	DW	?			;segment
EXT_MEM_LIMIT	DW	0			;adjusted top of avail memory
OS_ENABLED	DB	1			;Enable os functions 1=enabled
OS_PASS_LOW	DW	0			;Operating system password.
OS_PASS_HIGH 	DW	0
ALT_MAP_PTRS 	DW	0			;Mapping pointer for funct 28
ALT_MAP_PTRO 	DW	0
WINDOW_SEG	DW	?			;starting segment of ems win
WINDOW_ADDR_BASE	DD	4 DUP(0)	;address of each page
EXTEND_ADRL	DW	?			;base of extended memory used
EXTEND_ADRH	DB	?
TOTAL_PAGES	DW	24			;default to 384k of exp mem.
TOTAL_HANDLES	DW	255			;Default number of handles
PAG_OWNER_TBL	DW	?			;Pointer to page table
HANDLE_ARRAY 	DW	?                       ;Pointer to handle table
MAP_ARRAY_PTR 	DW	?                       ;Pointer to map array

ACTIVE		DB	0			;Active flag


;======================================================================
;Interrupt 15h routine. Intercept extended memory size determine.
;======================================================================
INT_15H		PROC	FAR
		ASSUME CS:CODE,DS:NOTHING,ES:NOTHING
		CMP	AH,88H
		JE	INT15_F88
		JMP	CS:[OLD_INT15H]
INT15_F88:	MOV	AX,CS:EXT_MEM_LIMIT             ;provide new limit
		CLC                                     ;clear error flag
		RET	2
INT_15H		ENDP
;-----------------------------------------------------------------------------
;Jump table for EMS driver commands
;-----------------------------------------------------------------------------
EMS_CMDS	DW	OFFSET EMS_01		;Get status
		DW	OFFSET EMS_02		;Get page frame seg address
		DW	OFFSET EMS_03		;Get unallocated page count
		DW	OFFSET EMS_04		;Allocate pages
		DW	OFFSET EMS_05		;Map/unmap handle pages
		DW	OFFSET EMS_06		;Deallocate pages
		DW	OFFSET EMS_07		;Get version
		DW	OFFSET EMS_08		;Save page map
		DW	OFFSET EMS_09		;Restore page map
		DW	OFFSET EMS_UNSP		;reserved
		DW	OFFSET EMS_UNSP		;reserved
		DW	OFFSET EMS_12		;Get handle count
		DW	OFFSET EMS_13		;Get handle pages
		DW	OFFSET EMS_14		;Get all handle pages
		DW	OFFSET EMS_15		;Page map functions
		DW	OFFSET EMS_16		;Partial page map functions
		DW	OFFSET EMS_17		;Map/unmap multiple hndl pages
		DW	OFFSET EMS_18		;Reallocate pages
		DW	OFFSET EMS_19		;Handle attribute
		DW	OFFSET EMS_20		;Handle name
		DW	OFFSET EMS_21		;Handle directory
		DW	OFFSET EMS_22		;Alter page map and jump
		DW	OFFSET EMS_23		;Alter page map and call
		DW	OFFSET EMS_24		;move/exchange memory region
		DW	OFFSET EMS_25		;Get mappable phys addr array
		DW	OFFSET EMS_26		;Hardware configuration
		DW	OFFSET EMS_27		;Allocate standard pages
		DW	OFFSET EMS_28		;Alternate map register set
		DW	OFFSET EMS_UNSP		;Warmboot preparation
		DW	OFFSET EMS_30		;OS/E functions
;======================================================================
;Interrupt 67h routine. EMS driver function dispatcher.
;======================================================================
INT_67H		PROC	FAR
		ASSUME 	CS:CODE,DS:NOTHING,ES:NOTHING
		PUSH	BP
		MOV	BP,SP			;set up stack addressing
		STI				;allow interrupts
		CLD				;any string operations move up.
		PUSH	CX			;Save registers
		PUSH	DI			;NOTE: Don't change the
		PUSH	SI                      ;  order of the register save.
		PUSH	DS                      ;  Many of the routines depend
		PUSH	ES                      ;  on the correct order.
		PUSH	CS			;point ds to code segment
		POP	DS
		ASSUME DS:CODE
		CMP	AH,5DH			;Check for a cmd out of range
		JA	EMS_CMD_ERR
		CMP	AH,40H
		JL	EMS_CMD_ERR
		MOV	DI,OFFSET RETURN_ADDR	;Push return address onto
		PUSH	DI			;  stack.
		PUSH	AX			;save ax
		SUB	AH,40H			;Convert command code in AX
		MOV	AL,AH			;  into a jump address.
		XOR	AH,AH                   ;Clear upper byte
		SAL	AX,1			;Convert to word offset
		ADD	AX,OFFSET EMS_CMDS	;add offset of jump table
		MOV	DI,AX			;Copy to DI
		POP	AX			;restore AX
		PUSH	[DI]			;Put offset of routine on stk
		MOV	DI,[BP-4]		;Restore DI
		CALL	EMS_CHECK_HDL           ;check for valid handle in DX
		RETN    			;Use ret to call function.
RETURN_ADDR:	POP	ES			;Restore registers
		POP	DS
		POP	SI
		POP	DI
		POP	CX
		POP	BP
EMS_I67_EXIT:
		IRET
EMS_CMD_ERR:	MOV	AH,84H                  ;EMS command out of range
		JMP	SHORT RETURN_ADDR
INT_67H		ENDP
;======================================================================
;Function 1.  Get status.
;======================================================================
EMS_01		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		XOR	AX,AX
		RET
EMS_01		ENDP
;======================================================================
;Function 2.  Get segment address of EMS window
;======================================================================
EMS_02		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		MOV	BX,WINDOW_SEG		;store starting seg of window
		XOR	AX,AX
		RET
EMS_02		ENDP
;======================================================================
;Function 3.  Get count of unallocated pages
;======================================================================
EMS_03		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		XOR	DX,DX			;search for hndl =-1 (unaloc)
		DEC	DX
		CLC				;fake 'handle ok' flag
		CALL	EMS_13
		MOV	DX,TOTAL_PAGES		;Load total pages
		XOR	AX,AX	 		;Clear return code
		RET
EMS_03		ENDP
;======================================================================
;Function 4.  Get handle and allocate pages
;======================================================================
EMS_04		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		OR	BX,BX			;Check for 0 page request
		JE	EMS_04_ERR		;If so, error
		CALL	EMS_27			;Let function 27 do the work
EMS_04_EXIT:	RET
EMS_04_ERR:	MOV	AH,89H			;attempt to allocate 0 pages
		JMP	SHORT EMS_04_EXIT
EMS_04		ENDP
;======================================================================
;Function 5,  Map / Unmap pages.
;======================================================================
EMS_05		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	BX
		PUSH	DX
		JC	EMS_05_EXIT		;carry set, invalid handle
		CMP	AL,3			;Check for physical page out
		JG	EMS_05_ERR0		;  of range
		CMP	BX,0FFFFH		;See if unmap page. If so,
		JNE	EMS_05_S1		;  save current mapped page
		MOV	BL,AL                   ;  but don't map new page.
		XOR	AX,AX
		XOR	DX,DX                   ;DL:AX=0 indicates no map
		JMP	SHORT EMS_05_S2
EMS_05_S1:	PUSH	AX			;Save physical page to map
		CALL	EMS_LOG2PHY		;Convert page into an address
		POP	BX                      ;Put phy page into BX for call
		JC	EMS_05_EXIT		;If error, exit
EMS_05_S2:	CALL	EMS_EXCH_PAG		;Map the page
             	XOR	AX,AX			;Clear return code
EMS_05_EXIT:	POP	DX                      ;Restore registers.
		POP	BX
		RET
EMS_05_ERR0:	MOV	AH,8BH			;Physical page out of range
		JMP	SHORT EMS_05_EXIT
EMS_05		ENDP
;======================================================================
;Function 6,  Deallocate pages.
;======================================================================
EMS_06		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	BX
		PUSH	DX
		JC	EMS_06_EXIT		;carry set, invalid handle
		MOV	BL,0FFH			;clear all pages
		CALL	EMS_DEALLOC		;Deallocate memory
		OR	DL,DL			;handle zero cannot be
		JE	EMS_06_GOOD		;  deallocated
		PUSH	CS                      ;Deallocate handle
		POP	ES
		ASSUME	ES:CODE
		MOV	DI,HANDLE_ARRAY
		MOV	AX,DX			;copy handle
		MOV	CX,9			;convert handle to an index into
		MUL	CX			;  the handle array.
		ADD	DI,AX
		XOR	AL,AL			;Erase handle flag and name.
		REP	STOSB
EMS_06_GOOD:	XOR	AX,AX			;clear return code
EMS_06_EXIT:	POP	DX
		POP	BX
		RET
EMS_06		ENDP
;======================================================================
;Function 7.  Get version number
;======================================================================
EMS_07		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		MOV	AX,0040H		;store ver num and ret code
		RET
EMS_07		ENDP
;======================================================================
;Function 8. Save page map.
;======================================================================
EMS_08		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	BX
		PUSH	DX
		JC	EMS_08_EXIT		;carry set, invalid handle
;Search the mapping arrays to find an array that is empty.  At the same
;   time, make sure that the handle doesn't have an array currently saved.
		MOV	SI,MAP_ARRAY_PTR	;start search of map arr lbls
		MOV	CX,3			;search all 3 save map arrays
		XOR	BX,BX			;initialize free pointer
EMS_08_L1:	ADD	SI,18			;look at next map array
		CMP	WORD PTR [SI],0	;see if free
		JNE	EMS_08_S1
		MOV	DI,SI			;if so, copy address
		JMP	SHORT EMS_08_S3
EMS_08_S1:	CMP	[SI],DX			;see if curr hndl used before
		JNE	EMS_08_S2
		MOV	AH,8DH			;handle already used for save
		JMP	SHORT EMS_08_EXIT
EMS_08_S2:	LOOP	EMS_08_L1		;loop back if less than 4 times
		MOV	AH,8CH			;no room to store page map
		JMP	SHORT EMS_08_EXIT
EMS_08_S3:	PUSH	CS			;point ds:si to page array
		POP	ES
		ASSUME ES:CODE			;point es:di to save array
		MOV	SI,MAP_ARRAY_PTR
		MOV	[SI],DX			;label arrays with handle
		MOV	CX,9
		REP	MOVSW
		XOR	AX,AX			;clear return code
EMS_08_EXIT:	POP	DX
            	POP	BX
		RET
EMS_08		ENDP
;======================================================================
;Function 9. Restore page map
;======================================================================
EMS_09		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	BX
		PUSH	DX
		JC	EMS_09_EXIT		;carry set, invalid handle
;find the saved page map in the save array.
		MOV	SI,MAP_ARRAY_PTR
		MOV	CX,3
EMS_09_L1:	ADD	SI,18			;look at next map array
		CMP	[SI],DX			;See if array label matches the
		JE	EMS_09_S1		;  handle.
		LOOP	EMS_09_L1
		MOV	AH,8EH			;no saved page map found
		JMP	SHORT EMS_09_EXIT
;Now that the saved array has been found, call restore map routine.
EMS_09_S1:	MOV	WORD PTR [SI],0		;mark saved array as free
		CALL	EMS_15_1		;restore map
		XOR	AX,AX			;clear return code
EMS_09_EXIT:	POP	DX
		POP	BX
		RET
EMS_09		ENDP
;======================================================================
;Function 12, Get Handle Count
;======================================================================
EMS_12		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		MOV	DI,HANDLE_ARRAY		;point to handle array
		XOR	BX,BX			;clear count and compare regs
		MOV	CX,TOTAL_HANDLES	;look at all handles 0 - feh
EMS_12_L1:	CMP	BH,[DI]			;if handle id = 0 then that
		JE	EMS_12_S1		;  handle has not been allocated.
		INC	BL			;Add one to open handle count
EMS_12_S1:	ADD	DI,9			;Move di to point to next id.
		LOOP	SHORT EMS_12_L1
		XOR	AX,AX			;clear return code
EMS_12_EXIT:	RET
EMS_12		ENDP
;======================================================================
;Function 13 Get Handle pages
;Entry: dx = handle to search for
;Exit:  ax = return code.      bx = number of matches found.
;======================================================================
EMS_13		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	DI
		JC	EMS_13_EXIT		;carry set, invalid handle
		MOV	DI,PAG_OWNER_TBL	;point to owner table
		MOV	CX,TOTAL_PAGES
		XOR	BX,BX			;Clear page count
EMS_13_LOOP:	CMP	DL,[DI]			;Compare handle to table
		JNE	EMS_13_SKIP
		INC	BX                      ;Inc count of pages
EMS_13_SKIP:	ADD	DI,3			;Point to next entry
		LOOP	EMS_13_LOOP
		XOR	AX,AX                   ;Clear return code.
EMS_13_EXIT:	POP	DI
		RET
EMS_13		ENDP
;======================================================================
;Function 14. Get All Handle Pages
;======================================================================
EMS_14		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	DX
		XOR	DX,DX			;handle currently being checked
		XOR	SI,SI			;si total open handles counter
EMS_14_L1:	CALL	EMS_CHECK_HDL		;see if handle active
		CALL	EMS_13			;cnt number of pages for hdl
		JC	EMS_14_S1               ;if bad handle, skip
		INC	SI			;add to handle count
		MOV	ES:[DI],DX		;write results to the array
		MOV	ES:2[DI],BX
EMS_14_S1:	INC	DX			;point to next handle
		ADD	DI,4			;incriment array pointer
		CMP	DX,TOTAL_HANDLES	;have we check all handles?
		JL	EMS_14_L1		;no, loop back.
		MOV	BX,SI			;Get number of active handles
		XOR	AX,AX			;clear return code
EMS_14_EXIT:	POP	DX
		RET
EMS_14		ENDP
;======================================================================
;Function 15.  Get/Set Page Map
;======================================================================
EMS_15_TBL	DW	OFFSET EMS_15_0	;Jump table for subfunctions
		DW	OFFSET EMS_15_1
		DW	OFFSET EMS_15_2
		DW	OFFSET EMS_15_3
EMS_15		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	BX
		PUSH	DX
		PUSH	DS
		MOV	DS,SS:[BP-8]		;Get original DS
		ASSUME DS:NOTHING
		CMP	AL,3			;check al for a number not 0-3
		JA	EMS_15_ERROR
		XOR	AH,AH			;clear top byte of subfunction
		MOV	BX,AX			;convert into jump address
		SAL	BX,1
		ADD	BX,OFFSET EMS_15_TBL
		CALL	CS:[BX]
EMS_15_EXIT:	POP	DS
		POP	DX
		POP	BX
		RET
EMS_15_ERROR:	MOV	AH,8FH			;invalid subfunction
		JMP	SHORT EMS_15_EXIT
EMS_15		ENDP
;----------------------------------------------------------------------
;Function 15.0  Get mapping array
;----------------------------------------------------------------------
EMS_15_0	PROC	NEAR
		ASSUME DS:NOTHING,ES:NOTHING
		PUSH	SI
		PUSH	DS
		PUSH	CS
		POP	DS
		ASSUME DS:CODE
		MOV	SI,MAP_ARRAY_PTR	;ds:si points to page array
		MOV	CX,9			;es:di points to destination
		REP	MOVSW			;copy mapping array
		XOR	AH,AH
		POP	DS
		POP	SI
		RET
EMS_15_0	ENDP
;----------------------------------------------------------------------
;Function 15.1  Set mapping array
;----------------------------------------------------------------------
EMS_15_1	PROC	NEAR
		ASSUME DS:NOTHING,ES:NOTHING
		PUSH	SI
		XOR	BX,BX			;start with logical page 0
		ADD	SI,2			;move si past the handle pointer
EMS_15_1_L1:	MOV	AX,DS:[SI]		;get current page address
		MOV	DX,DS:2[SI]
		PUSH	BX
		CALL	EMS_EXCH_PAG		;Exchange current window page
		POP	BX                      ;Point si to next address
		ADD	SI,4
		INC	BX
		CMP	BL,3			;Have we done all 4 pages?
		JLE	EMS_15_1_L1		;No, loop back
		XOR	AH,AH
EMS_15_1_EXIT:	POP	SI
		RET
EMS_15_1	ENDP
;----------------------------------------------------------------------
;Function 15.2  Get & Set mapping array
;----------------------------------------------------------------------
EMS_15_2	PROC	NEAR
		ASSUME DS:NOTHING,ES:NOTHING
		PUSH	DI
		CALL	EMS_15_0		;Save current mapping array
		POP	DI
		CALL	EMS_15_1		;Set new mapping context
		XOR	AH,AH
		RET
EMS_15_2	ENDP
;----------------------------------------------------------------------
;Function 15.3  Get mapping array size
;----------------------------------------------------------------------
EMS_15_3	PROC	NEAR
		ASSUME DS:NOTHING,ES:NOTHING
		MOV	AX,0012H		;18 bytes in the page array
		RET
EMS_15_3	ENDP
;======================================================================
;Function 16.  Get/Set Partial Page Map
;======================================================================
EMS_16_TBL	DW	OFFSET EMS_16_0		;Jump table for subfunctions
		DW	OFFSET EMS_16_1
		DW	OFFSET EMS_16_2
EMS_16		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	BX
		PUSH	DX
		PUSH	DS
		MOV	DS,SS:[BP-8]		;Get original DS from stack
		ASSUME DS:NOTHING
EMS_16_S1:	XOR	AH,AH			;clear top byte of subfunction
		CMP	AL,2			;check al for a number not 0-3
		JA	EMS_16_ERROR
		MOV	DI,AX			;convert into jump address
		SAL	DI,1
		ADD	DI,OFFSET EMS_16_TBL
		CALL	CS:[DI]
EMS_16_EXIT:	POP	DS
		POP	DX
		POP	BX
		RET
EMS_16_ERROR:	MOV	AH,8FH			;invalid subfunction
		JMP	SHORT EMS_16_EXIT
EMS_16		ENDP
;----------------------------------------------------------------------
;Function 16.0  Get mapping array
;----------------------------------------------------------------------
EMS_16_0	PROC	NEAR
		ASSUME DS:NOTHING,ES:NOTHING
		MOV	DI,SS:[BP-4]		;Get back original DI.
		MOV	CX,DS:[SI]		;get count of mappable segs.
		MOV	ES:[DI],CX		;save count
EMS_16_0_L1:	MOV	AX,DS:2[SI]		;Get segment to convert
		CALL	EMS_SEG2LOG		;convert segment onto page #
		JC	EMS_16_0_EXIT
		MOV	ES:2[DI],BX		;save physical page number
		SAL	BX,1			;Convert page number
		SAL	BX,1			;  into offset
		ADD	BX,CS:MAP_ARRAY_PTR
		MOV	AX,CS:2[BX]
		MOV	ES:4[DI],AX		;save address low
		MOV	AX,CS:4[BX]
		MOV	ES:6[DI],AX		;save address high
		ADD	DI,6
		INC	SI			;point to next seg to save
		INC	SI
		LOOP	EMS_16_0_L1
		XOR	AX,AX
EMS_16_0_EXIT:	RET
EMS_16_0	ENDP
;----------------------------------------------------------------------
;Function 16.1  Set mapping array
;----------------------------------------------------------------------
EMS_16_1	PROC	NEAR
		ASSUME DS:NOTHING,ES:NOTHING
		MOV	CX,DS:[SI]		;get count of pages
EMS_16_1_L1:	MOV	BX,2[SI]		;get logical page
		MOV	AX,4[SI]		;get address of page to
		MOV	DX,6[SI]		;  restore
		CALL	EMS_EXCH_PAG		;Exchange current window page
		ADD	SI,6			;Point si to next page
		LOOP	EMS_16_1_L1		;No, loop back
		XOR	AX,AX			;Clear error code
EMS_16_1_EXIT:	RET
EMS_16_1	ENDP
;----------------------------------------------------------------------
;Function 16.2  Get partial mapping array size
;----------------------------------------------------------------------
EMS_16_2	PROC	NEAR
		ASSUME DS:NOTHING,ES:NOTHING
		MOV	AX,BX			;get nubmer of pages
		MOV	AH,6			;6 bytes per page
		MUL	AH
		ADD	AX,2			;add room for count
		XOR	AH,AH			;zero return code
		RET
EMS_16_2	ENDP
;======================================================================
;Function 17.  Map Multiple Handle Pages
;======================================================================
EMS_17		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		MOV	ES,SS:[BP-8]		;get pointer to map structure
		CALL	EMS_17_INTERNAL
		RET
EMS_17		ENDP
;----------------------------------------------------------------------
;Function 17 (internal).  Used by jump and call routines to map pages.
;----------------------------------------------------------------------
EMS_17_INTERNAL	PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	BX
		PUSH	DX
		JC	EMS_17_EXIT		;carry set, invalid handle
		CMP	AL,1			;no subfunction > 1.
		JA	EMS_17_ERR1
		CMP	CX,4			;Make sure count < number of
		JA	EMS_17_ERR2		;  mappable pages.
		MOV	CH,AL			;save subfunction
EMS_17_L1:	MOV	AX,ES:2[SI]		;get physical page number/seg
		OR	CH,CH
		JE	EMS_17_S3		;if seg address mapping,
		CALL	EMS_SEG2LOG		;  convert seg addr to number
		JC	EMS_17_EXIT		;check for error on conversion
		MOV	AL,BL
EMS_17_S3:	MOV	BX,ES:[SI]		;get logical page number
		CLC				;handle valid
		PUSH	CX			;save count
		CALL	EMS_05			;map page
		POP	CX			;restore count
		OR	AH,AH			;check for error
		JNE	EMS_17_EXIT
		ADD	SI,4			;Move pointers to next
		DEC	CL			;  mapping structure.
		JNZ	EMS_17_L1
		XOR	AX,AX			;clear return code
EMS_17_EXIT:	POP	DX
		POP	BX
		RET
EMS_17_ERR1:	MOV	AH,8FH			;invalid subfunction
		JMP	SHORT EMS_17_EXIT
EMS_17_ERR2:	MOV	AH,8BH			;Number exceeds mappable pages
		JMP	SHORT EMS_17_EXIT	;  in the system
EMS_17_INTERNAL	ENDP
;======================================================================
;Function 18.  Reallocate Pages
;======================================================================
EMS_18		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	BX
		PUSH	DX
		JC	EMS_18_EXIT		;carry set, invalid handle
		MOV	DI,BX			;save reallocation count
		PUSH	BX
		CALL	EMS_13			;get current count
		MOV	CX,BX
		POP	BX			;get back new count
		SUB	BX,CX
		JG	EMS_18_INCREASE
		JL	EMS_18_REDUCE
		XOR	AH,AH			;clear return code
EMS_18_EXIT:	POP	DX
		POP	BX
		RET
EMS_18_INCREASE:
		CALL	EMS_ASSIGN
		JMP	SHORT EMS_18_EXIT
EMS_18_REDUCE:	NEG	BX			;turn into positive number
		CALL	EMS_DEALLOC
		JMP	SHORT EMS_18_EXIT
EMS_18		ENDP
;======================================================================
;Function 19. Get/Set Handle Attribute (Not Supported)
;======================================================================
EMS_19		PROC	NEAR
		ASSUME CS:CODE,DS:CODE
		CMP	AL,1
		JE	EMS_19_1   		;Set handle attribute.
		CMP	AL,2			;For subfunctions 0 and 2,
		JG	EMS_19_ERR1		;  return volatile handle,
EMS_19_GOOD_EXIT:
		XOR	AX,AX                   ;  non-volatile not supp
EMS_19_EXIT:	RET
EMS_19_1:	CALL	EMS_CHECK_HDL		;See if good handle
		JC	EMS_19_ERR2
		CMP	BL,1 			;See if legal attribute type
		JG 	EMS_19_ERR3      	;  or if non-volatile.
		JL	EMS_19_GOOD_EXIT
		MOV	AH,91H			;function not supported
		JMP	SHORT EMS_19_EXIT
EMS_19_ERR1:	MOV	AH,8FH			;subfunction invalid
		JMP	SHORT EMS_19_EXIT
EMS_19_ERR2:	MOV	AH,83H			;invalid handle
		JMP	SHORT EMS_19_EXIT
EMS_19_ERR3:	MOV	AH,90H			;attribute type not defined.
		JMP	SHORT EMS_19_EXIT
EMS_19		ENDP
;======================================================================
;Function 20. Get/Set Handle Name
;======================================================================
EMS_20		PROC	NEAR
		ASSUME  CS:CODE,DS:CODE,ES:NOTHING
		PUSH	BX
		PUSH	DX
		PUSH	DS
		JC	EMS_20_EXIT		;carry set, invalid handle
		PUSH	AX			;find spot for handle
		MOV	BX,CS			;get code segment
		MOV	AX,DX			;Compute offset by multipling
		MOV	AH,9			;  the handle number by the
		MUL	AH			;  size of each entry (9).
		MOV	DX,AX
		ADD	DX,HANDLE_ARRAY
		INC	DX			;point dx past the handle used
		POP	AX			;  flag.
		OR	AL,AL			;Check for get or set subfun.
		JNE	EMS_20_S1
;Get Handle Name
		MOV	SI,DX			;load pointer to handle name
		JMP	SHORT EMS_20_MOV
;Set Handle Name
EMS_20_S1:	CMP	AL,1			;Make sure that subfunction
		JNE	EMS_20_ERR1             ;  = 1.
		MOV	DS,SS:[BP-8]            ;Get original DS
		ASSUME  DS:NOTHING
		PUSH	SI
		PUSH	DX
		CALL	EMS_21_1		;First, search for handle
		POP	DX			;  with this name. The
		POP	SI			;  return code must be a0h.
		AND	AH,0FEH			;  or a1h.
		CMP	AH,0A0H
		JNE	EMS_20_ERR2
		MOV	DI,DX			;Get back name pointer
		PUSH	CS
		POP	ES
		ASSUME  ES:CODE
EMS_20_MOV:	MOV	CX,8			;copy name. move 8 bytes
		REP	MOVSB
		XOR	AX,AX			;clear return code
EMS_20_EXIT:	POP	DS
		POP	DX
		POP	BX
		RET
EMS_20_ERR1:	MOV	AH,8FH			;Invalid subfunction
		JMP	SHORT EMS_20_EXIT
EMS_20_ERR2:	MOV	AH,0A1H			;Handle already used
		JMP	SHORT EMS_20_EXIT
EMS_20		ENDP
;======================================================================
;Function 21. Get Handle directory
;======================================================================
EMS_21_TBL	DW	OFFSET EMS_21_0	;Jump table for subfunctions
		DW	OFFSET EMS_21_1
		DW	OFFSET EMS_21_2
EMS_21		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	DS
		MOV	DS,SS:[BP-8]		;Get original DS
		ASSUME  DS:NOTHING
		CMP	AL,2			;check subfunction < 3
		JA	EMS_21_ERROR
		XOR	AH,AH			;clear top byte of subfunction
		MOV	DI,AX			;convert into jump address
		SAL	DI,1
		ADD	DI,OFFSET EMS_21_TBL
		CALL	CS:[DI]
EMS_21_EXIT:	POP	DS
		RET
EMS_21_ERROR:	MOV	AH,8FH			;invalid subfunction
		JMP	SHORT EMS_21_EXIT
EMS_21		ENDP
;----------------------------------------------------------------------
;Function 21.0  Get Handle Directory
;----------------------------------------------------------------------
EMS_21_0	PROC	NEAR
		ASSUME  DS:NOTHING,ES:NOTHING
		PUSH	DX
		PUSH	CS
		POP	DS
		ASSUME  DS:CODE
		MOV	SI,HANDLE_ARRAY
		MOV	DI,SS:[BP-4]		;Get original DI
		XOR	AX,AX			;Clear RC and hndl counter
		MOV	DX,AX			;Start with handle 0
EMS_21_0_L1:	CMP	BYTE PTR [SI],0		;Check flag to see if handle
		JE	EMS_21_0_S1		;  is used.
		MOV	ES:[DI],DX		;Store handle value
		INC	SI			;move SI past handle flag
		ADD	DI,2			;move DI past handle
		MOV	CX,8			;8 char per handle name
		REP	MOVSB
		INC	AL			;add to handle count
		JMP	SHORT EMS_21_0_S2
EMS_21_0_S1:	ADD	SI,9			;move to the next handle
EMS_21_0_S2:	INC	DX			;check next handle
		CMP	DX,TOTAL_HANDLES	;last handle?
		JB	EMS_21_0_L1		;no, loop back
		POP	DX
		RET
EMS_21_0	ENDP
;----------------------------------------------------------------------
;Function 21.1  Search for Named Handle
;----------------------------------------------------------------------
EMS_21_1	PROC	NEAR
		ASSUME DS:NOTHING
		PUSH	BX
		PUSH	DS			;copy segment of name
		POP	ES
		ASSUME ES:NOTHING
		MOV	DI,SI
		MOV	CX,8			;Check for null string. If
		XOR	AL,AL			;  null, skip scan for dup
		REPE	SCASB			;  strings.
		JE	EMS_21_1_ERR1
		MOV	CX,CS:TOTAL_HANDLES	;look at all handles
		PUSH	CS			;ES:DI -> handle array
		POP	ES			;DS:SI -> handle name
		ASSUME  ES:CODE
		MOV	BX,SI			;bx holds handle name ptr
		MOV	AX,CS:HANDLE_ARRAY	;ax holds handle array ptr
		INC	AX			;move ax past handle flag
		XOR	DX,DX			;start handle count at 0
EMS_21_1_L1:	MOV	DI,AX			;Compare each of the handle
		MOV	SI,BX			;  names with the new handle
		PUSH	CX
		MOV	CX,8
		REPE	CMPSB
		POP	CX
		JE	EMS_21_1_EXIT		;If match found print err msg.
		ADD	AX,9			;move AX to next handle
		INC	DX
		LOOP	EMS_21_1_L1
		MOV	AH,0A0H			;handle not found
		JMP	SHORT EMS_21_1_EXIT1
EMS_21_1_EXIT:	XOR	AH,AH
EMS_21_1_EXIT1:	POP	BX
		RET
EMS_21_1_ERR1:	MOV	AH,0A1H			;null handle found
		JMP	SHORT EMS_21_1_EXIT1
EMS_21_1	ENDP
;----------------------------------------------------------------------
;Function 21.2  Get Total Handles
;----------------------------------------------------------------------
EMS_21_2	PROC	NEAR
		ASSUME	DS:NOTHING
		MOV	BX,CS:TOTAL_HANDLES	;Get number of allowed hdls
		XOR	AX,AX   		;Clear return code.
		RET
EMS_21_2	ENDP
;======================================================================
;Function 22. Alter Page Map and Jump
;======================================================================
EMS_22		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		JC	EMS_22_EXIT		;carry set, invalid handle
;Map new pages into window
		MOV	DI,SI			; ES:DI = pointer to map and
		MOV	ES,SS:[BP-8]		;  jump data
		MOV 	SI,ES:[DI]		;Modify return address on
		MOV	SS:[BP+2],SI		;  the stack to the address
		MOV 	SI,ES:2[DI]		;  in the jump structure.
		MOV	SS:[BP+4],SI
		MOV	SI,ES:5[DI]		;Get pointer to mapping
		MOV	ES,ES:7[DI]		;   structure.
		MOV	CL,ES:4[DI]		;get mapping count
		XOR	CH,CH
		CALL	EMS_17_INTERNAL		;alter page map
EMS_22_EXIT:	RET
EMS_22		ENDP
;======================================================================
;Function 23. Alter Page Map and Call
;======================================================================
EMS_23		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		JC	EMS_23_JMP_END          ;carry set, invalid handle
		CMP	AL,2			;Check for stack size function
		JNE	EMS_23_S1
		MOV	BX,28			;Say we need 28 bytes
		XOR	AH,AH
EMS_23_JMP_END:	JMP	EMS_23_EXIT
EMS_23_S1:	PUSH	AX			;Save subfunction
;Map new pages into window
		MOV	DI,SI			;get pointer to map and
		MOV	ES,SS:[BP-8]		;  jump data
		PUSH	ES			;Save pointer to structure
		PUSH	DI
		XOR	CH,CH
		MOV	CL,ES:[DI+4]		;get mapping count
		MOV	SI,ES:[DI+5]		;get pointer to mapping
		MOV	ES,ES:[DI+7]		;   structure
		PUSH	AX
		CLC				;indicate good handle
		CALL	EMS_17_INTERNAL		;alter page map
		OR	AH,AH
		POP	AX			;Restore AX
		JNE	EMS_23_EXIT
;Restore values in the registers and call.
		MOV	AX,SS:[BP+6]		;get flags
		PUSH	AX
		POPF				;load flags
		MOV	ES,SS:[BP-10]		;restore ES
		MOV	DS,SS:[BP-8]            ;Restore DS
		MOV	SI,SS:[BP-6]		;Restore SI
		MOV	DI,SS:[BP-4]		;Restore DI
		MOV	DI,SS:[BP-2]		;Restore CX
		ASSUME	DS:NOTHING
		PUSH	BP                      ;Save my base pointer
		MOV	BP,SS:[BP]		;Restore BP
		MOV	AX,0000			;Clear return code
		CALL	DWORD PTR DS:[SI]	;Call.
		POP	AX			;Get back pointer to stack
		PUSH	BP			;Save returned BP
		MOV 	BP,AX			;Restore my base pointer
		POP	AX			;Get back returned BP
		PUSHF				;Save returned flags
		MOV	[BP-10],ES
		MOV	[BP-8],DS		;Put reg values on stack
		MOV	[BP-6],SI               ;  to be restored on return
		MOV	[BP-4],DI
		MOV	[BP-2],CX
		POP	CX     			;Get back returned flags
		MOV	SS:[BP+6],CX
		MOV	SS:[BP],AX		;Save returned BP
		PUSH	CS
		POP	DS
		ASSUME DS:CODE
;Map old pages into window
		POP	DI			;Get back pointer to structure
		POP	ES
		XOR	CH,CH
		MOV	CL,ES:[DI+9]		;get mapping count
		MOV	SI,ES:[DI+10]		;get pointer to mapping
		MOV	ES,ES:[DI+12]		;   structure
		CLC				;indicate good handle
		POP	AX			;Restore subfunction
		CALL	EMS_17_INTERNAL		;alter page map
EMS_23_EXIT:	RET
EMS_23		ENDP
;======================================================================
;Function 24.  Move/Exchange Memory Region
;======================================================================
EMS_24_SUBFUN	EQU	[BP-1]			;Saved subfunction
EMS_24_DIR	EQU	[BP-2]			;Direction flag for move
EMS_24_COUNT	EQU	[BP-6]			;Amount of memory to move
EMS_24_SRC_PTR	EQU	[BP-10]			;Source move pointer
EMS_24_DEST_PTR	EQU	[BP-14]			;Destination move pointer
EMS_24_RET_CODE	EQU	[BP-15]			;RC for non-fatal error codes
EMS_24		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	BX			;Save registers
		PUSH	DX
		MOV	ES,SS:[BP-8]		;Get DS off original stack
		PUSH	ES			;Push for local addressability
		PUSH	SI
		PUSH	BP
		MOV	BP,SP			;Set up pointer to local data
		SUB	SP,18			;Make room on stack for data
		MOV 	EMS_24_SUBFUN,AL        ;Save subfunction
		MOV	BYTE PTR EMS_24_RET_CODE,0
		MOV	AX,ES:[SI]		;Get count from move struc
		MOV	DX,ES:[SI+2]
		CMP	DX,10H			;see if region size > 1M
		JB 	EMS_24_S0
		MOV	AH,96H			;region > 1M byte
		JMP	EMS_24_EXIT
EMS_24_S0:	MOV	WORD PTR [EMS_24_COUNT],AX	;Save count. Compute
		MOV	WORD PTR [EMS_24_COUNT+2],DX    ;  the number of
		MOV	CX,16384		        ;  16K pages needed.
		DIV	CX
		MOV	CH,AL			;Save number of pages
		MOV	CL,DL			;save remainder
;Verify handles have the pages assigned. (If Expanded memory.)
		ADD	SI,4			;move pointer to source descr
		MOV	DI,-10			;Pointer to src local store
		CALL	EMS_CHECK_MOV
		JC	EMS_24_JMP_EXIT
		PUSH	AX			;Save source end address
		PUSH	DX
		ADD	SI,7                    ;Point to destination block
		MOV	DI,-14			;Pointer to dest local store
		CALL	EMS_CHECK_MOV
		POP	DI                      ;Recover source end address
		POP	BX
		JNC	EMS_24_S01              ;If error flag set, exit
EMS_24_JMP_EXIT:
		JMP	EMS_24_EXIT
EMS_24_S01:	MOV	BYTE PTR EMS_24_DIR,0	;Set direction flag bottom up
;Check and adjust for overlap if necessary. If exchange, don't allow overlap.
		MOV	CL,BYTE PTR ES:[SI]  	;Get destination memory type
		ADD	CL,BYTE PTR ES:[SI-7]  	;Compare to source memory type
		CMP	CL,1			;0 = both conv, 1 = diff types,
		JE	EMS_24_MOVEDATA		;  2 = both expanded.
		JB	EMS_24_S2		;0, check conv overlap.
		MOV	CX,ES:[SI+1]		;Get dest handle
		CMP	CX,ES:[SI-6]		;Compare to source handle
		JNE	EMS_24_MOVEDATA		;Not the same, no overlap
		MOV	CX,ES:[SI-2]		;Get source starting page
		CMP	CX,ES:[SI+5]		;Compare dest starting page
		JB	EMS_24_S1  		;If source starts first,
		JA	EMS_24_S02              ;  bottom up move.
		MOV	CX,ES:[SI-4]            ;Get source starting offset
		CMP	CX,ES:[SI+3]            ;Get source starting offset
		JB	EMS_24_S1		;Source lower, bottom up move
EMS_24_S02:	MOV 	BX,AX                   ;Copy from top down.
		MOV 	DI,DX			;Put end addr of Dest in DI,BX
		SUB	SI,7			;Point to source descriptor
		MOV	BYTE PTR EMS_24_DIR,1	;Set direction top down
EMS_24_S1:	CMP	DI,ES:[SI+5]		;Compare end with start addr
		JB	EMS_24_MOVEDATA		;No overlap
		JA	EMS_24_OVERLAP		;Overlap
		CMP	BX,ES:[SI+3]		;Same pages, check offsets
		JB	EMS_24_MOVEDATA		;If less, no overlap
		JMP	SHORT EMS_24_OVERLAP
;Check for overlap of conventional memory regions.
EMS_24_S2:	CMP	DX,DI			;Compare high word
		JB	EMS_24_S3		;dest higher, top down
		JA	EMS_24_S21              ;Less, bottom up.
		CMP	AX,BX			;Compare low word of address
		JB 	EMS_24_S3		;Jmp if dest addr higher
EMS_24_S21:	MOV	SI,-14			;Point to dest descriptor
		CALL	EMS_24_ADR_CNV
		XCHG	DI,DX			;Exchange starting addresses
		XCHG	BX,AX
		MOV	SI,-10			;Point to source descriptor
		CALL	EMS_24_ADR_CNV
		MOV	BYTE PTR EMS_24_DIR,1	;Set direction flag top down
EMS_24_S3:	SUB	BX,WORD PTR [EMS_24_COUNT]	;Generate start addr
		SBB	DI,WORD PTR [EMS_24_COUNT+2]
		CMP	DX,DI                   ;Compare starting addr with
		JB	EMS_24_MOVEDATA		;  end of other block
		CMP	AX,BX
		JBE	EMS_24_MOVEDATA
EMS_24_OVERLAP:	MOV	BYTE PTR EMS_24_RET_CODE,92H	;Indicate overlap
		CMP	BYTE PTR EMS_24_SUBFUN,0	;If exch. don't allow
		JE	EMS_24_MOVEDATA                 ;  overlap.
		MOV	AH,97H				;Error, no overlap
		JMP	EMS_24_EXIT			;  on exchange.
;Move/Exchange the data
EMS_24_MOVEDATA:
		MOV	BX,MAP_ARRAY_PTR	;Save context of pages 0 & 1
		PUSH	[BX+8]                  ;Save address for page 1
		PUSH	[BX+6]
		PUSH	[BX+4]			;Save address for page 0
		PUSH	[BX+2]
		STD
		CMP	BYTE PTR EMS_24_DIR,0   ;If moving from top to bottom
		JNE	EMS_24_MOVE0            ;  set direction flag for move
		CLD
		MOV	AX,ES:[SI-4]		;If move from bottom to top,
		MOV	DX,ES:[SI-2]                    ;  initialize the
		MOV	WORD PTR [EMS_24_SRC_PTR],AX    ;  pointers back to
		MOV	WORD PTR [EMS_24_SRC_PTR+2],DX  ;  the starting
		MOV	AX,ES:[SI+3]                    ;  addresses.
		MOV	DX,ES:[SI+5]
		MOV	WORD PTR [EMS_24_DEST_PTR],AX
		MOV	WORD PTR [EMS_24_DEST_PTR+2],DX
EMS_24_MOVE0:	XOR	CX,CX			;Clear last move count
EMS_24_MOVELOOP:
		MOV	ES,[BP+4]		;Restore move structure
		MOV	BX,[BP+2]		;  pointer to ES:BX
		MOV	DX,ES			;Save ES
		MOV 	AX,CX			;Save last count
		ADD	BX,4                    ;Point to source descriptor
		XOR	SI,SI			;Indicate source
		CALL	EMS_24_MOV_SET
		PUSH	ES      		;Save source pointer
		PUSH	DI
		XCHG	CX,AX			;save count, restore last cnt
		MOV	ES,DX			;Restore ES
		ADD	BX,7			;Point to dest mem descriptor
		MOV	SI,1
		CALL	EMS_24_MOV_SET 		;Map extended mem if needed
                POP     SI			;Get back source pointer
		POP	BX			;Save segment in BX
		CMP	AX,CX                 	;Get lower count
		JA	EMS_24_MOVE1
		MOV	CX,AX
EMS_24_MOVE1:	MOV	AX,WORD PTR [EMS_24_COUNT]  	;Get move count
		MOV	DX,WORD PTR [EMS_24_COUNT+2]
		OR	DX,DX                           ;See if at end of
		JNE	EMS_24_MOVE2                    ;  count. If so,
		CMP	AX,CX                           ;  copy only to end
		JA	EMS_24_MOVE2                    ;  of count.
		MOV	CX,AX
EMS_24_MOVE2:	SUB	AX,CX			;Subtract from count
		SBB	DX,0
		PUSH	CX
		PUSH	AX                      ;Save count
		PUSH	DX
		CMP	BYTE PTR EMS_24_SUBFUN,1	;See if move or exch
		MOV	DS,BX			;Time to set DS
		ASSUME	DS:NOTHING
		JE	EMS_24_EXCH
		REP	MOVSB			;Move that data
                JMP	SHORT EMS_24_MOVE3
EMS_24_EXCH:	MOV	BL,ES:[DI]		;Get dest byte
		MOVSB
		CMP	BYTE PTR EMS_24_DIR,0	;Check direction flag to
		JNE	EMS_24_EXCH1            ;  make sure of pointers
		MOV     DS:[SI-1],BL		;Move dest byte to source
		JMP	SHORT EMS_24_EXCH2
EMS_24_EXCH1:	MOV     DS:[SI+1],BL		;Move dest byte to source
EMS_24_EXCH2:	LOOP	EMS_24_EXCH             ;Loop until block exchanged.
EMS_24_MOVE3:	PUSH	CS                      ;Restore DS altered by move
		POP	DS
		ASSUME	DS:CODE
		POP	DX			;Get back count
		POP	AX
		POP	CX
		MOV	WORD PTR [EMS_24_COUNT],AX	;Restore count
		MOV	WORD PTR [EMS_24_COUNT+2],DX
		OR	DX,DX
		JNE	EMS_24_MOVE4            ;See if count has expired.
		OR	AX,AX
		JLE	EMS_24_LOOP_DONE
EMS_24_MOVE4:	JMP	EMS_24_MOVELOOP
EMS_24_LOOP_DONE:				;Restore pages 0 and 1.
		XOR	BX,BX    		;set physical page = 0
		POP	AX      		;get address of page to
		POP	DX      		;  restore
		CALL	EMS_EXCH_PAG		;Exchange current window page
		MOV	BX,1     		;set physical page = 1
		POP	AX      		;get address of page to
		POP	DX      		;  restore
		CALL	EMS_EXCH_PAG		;Exchange current window page
		MOV	AH,BYTE PTR EMS_24_RET_CODE	;Get return code
EMS_24_EXIT:	ADD	SP,18			;Deallocate local storage
		POP	BP
		POP	SI
		POP	ES
		POP	DX
		POP	BX
		RET
EMS_24		ENDP
;----------------------------------------------------------------------
;Convert address to segment offset form
;Entry: dx ax - address
;          si - pointer to local memory descriptor
;----------------------------------------------------------------------
EMS_24_ADR_CNV	PROC	NEAR
		PUSH	AX
		PUSH	DX
		MOV	CX,16384		;Convert address to seg:offset
		DIV	CX
		MOV	WORD PTR [BP+SI],DX	;Save offset
		MOV	CL,10
		SAL	AX,CL
		MOV	WORD PTR [BP+SI+2],AX   ;Save segment
		POP	DX
		POP	AX
		RET
EMS_24_ADR_CNV	ENDP
;----------------------------------------------------------------------
;Setup ems page for move.
;Entry:    al - 0 = source page, 1 = destination page.
;       es:bx - pointer to external memory descriptor
;          cx - Count used on last move
;Exit:  ES:DI - pointer to data to move
;          cx - max count before crossing boundry.
;----------------------------------------------------------------------
EMS_24_MOV_SET	PROC	NEAR
		ASSUME	DS:CODE
		PUSH	AX
		PUSH	BX
		PUSH	DX
		MOV	DX,SI
		MOV	SI,-10                  ;Use SI as offset to src_ptr
		OR	DX,DX
		JE	EMS_24_MOV_SET_S0
		SUB	SI,4			;Point SI to dest_ptr
EMS_24_MOV_SET_S0:
		MOV	DH,BYTE PTR ES:[BX]	;Get memory type
		MOV	AX,16383		;Load constants for EMS mem
		MOV	DI,1
		OR 	DH,DH             	;Check type of number
		JNE	EMS_24_MOV_SET_S1	;1 = EMS memory
		MOV	DI,1024                 ;Load constants for
		        			;  conventional memory.
EMS_24_MOV_SET_S1:
		CMP	BYTE PTR EMS_24_DIR,0	;If bottom up move, skip
		JE	EMS_24_MOV_SET_S3
;Top down.
		SUB	WORD PTR [BP+SI],CX	;Sub last move from offset
		JAE	EMS_24_MOV_SET_S2	;See if end of page
		MOV	WORD PTR [BP+SI],AX   	;Start at top of next page
		SUB	WORD PTR [BP+SI+2],DI	;Point to next page
EMS_24_MOV_SET_S2:
		MOV	CX,WORD PTR [BP+SI]	;Get offset for count
		INC	CX
		JMP	EMS_24_MOV_SET_S5
;Bottom up
EMS_24_MOV_SET_S3:
		ADD	WORD PTR [BP+SI],CX	;Add last move to offset
		CMP	WORD PTR [BP+SI],AX   	;See if end of page
		JBE	EMS_24_MOV_SET_S4
EMS_24_MOV_SET_S31:
		MOV	WORD PTR [BP+SI],0 	;Start at bottom of page
		ADD	WORD PTR [BP+SI+2],DI 	;Point to next page
EMS_24_MOV_SET_S4:
		MOV	CX,AX                   ;Compute count to end of page
		SUB	CX,WORD PTR [BP+SI]
 		INC	CX
EMS_24_MOV_SET_S5:
		OR 	DH,DH              	;Check type of number
		JE	EMS_24_MOV_SET_CONV1	;If conventional, don't map
		PUSH	CX			;Save new count
		PUSH	DX
		MOV	AL,DL			;Pass proper phyical page
		MOV	DX,WORD PTR ES:[BX+1]	;Get handle
		MOV	BX,WORD PTR [BP+SI+2]	;Put page in proper register
		PUSHF
		CLD				;Set assumed direction flag
		CLC				;Set handle good flag
		CALL	EMS_05			;Map page
		POPF
		POP	DX
		POP	CX			;Get count back
		MOV	AX,WINDOW_SEG		;Get window segment
		OR	DL,DL			;See if source or dest
		JE	EMS_24_MOV_SET_S6       ;If destination, point to
		ADD	AX,1024                 ;  2nd page. 1024 paragraphs
EMS_24_MOV_SET_S6:
		MOV	ES,AX			;Set pointer to data
EMS_24_MOV_SET_EXIT:
		MOV	DI,WORD PTR [BP+SI]	;Load offset
		POP	DX
		POP	BX
		POP	AX
		RET
EMS_24_MOV_SET_CONV1:
		MOV	DI,WORD PTR [BP+SI+2]
		MOV	ES,DI
		JMP	SHORT EMS_24_MOV_SET_EXIT
EMS_24_MOV_SET	ENDP
;----------------------------------------------------------------------
;Check parameters for move or exchange
;Entry: es:si - pointer to memory descriptor
;       bp+di - pointer to local store descriptor
;          ch - number of extended pages needed
;          cl - number of bytes into last extended page
;Exit:  dx,ax - ending address if conventional
;          ax - ending page if expanded
;          dx - ending offset if expanded
;----------------------------------------------------------------------
EMS_CHECK_MOV 	PROC	NEAR
		ASSUME  DS:CODE,ES:NOTHING
		PUSH	BX
		PUSH	CX
		PUSH	DI
		XOR	AX,AX
		MOV	AL,CH			;Get number of pages needed
		MOV	DI,AX			;Save number of pages in DI
		XOR	CH,CH
		MOV	AX,ES:[SI+5]		;Get segment/page
		MOV	BX,ES:[SI+3]		;get offset
		MOV	DL,ES:[SI]		;Get memory type
		OR	DL,DL			;See if EMS or low memory
		JE 	EMS_CHECK_MOV_CONV	;jump if low memory
  		CMP	DL,1			;If not low mem make sure
		JE 	EMS_CHECK_MOV_S1        ;  EMS memory.
		MOV	AH,98H			;Invalid memory type
		JMP	EMS_CHECK_MOV_SET_ERR
EMS_CHECK_MOV_S1:
		CMP	BX,3FFFH		;Check for offset < 16K
		JA	EMS_CHECK_MOV_ERR1
;See if the handle owns enough pages to hold the region.
		MOV	DX,ES:[SI+1]		;Get handle
		PUSH	CX
		CALL	EMS_CHECK_HDL   	;Verify handle.
		CALL	EMS_13			;Get number of pages owned
		POP	CX                      ;  by handle
		OR	AH,AH			;If error, set carry and
		JNE	EMS_CHECK_MOV_SET_ERR	;  return.
		MOV	DX,BX			;save number of pages
		MOV	BX,ES:[SI+5]		;Get logical page number
		MOV	AX,DI			;Copy number of pages needed
		ADD	AX,BX			;Add starting page.
		ADD	CX,ES:[SI+3]		;Add start offset to remainder
		DEC	CX                      ;  of the num of pages needed.
		CMP	CX,16384
		JL	EMS_CHECK_MOV_S4	;If rem+offset > 16K add a
		INC	AX			;  page to the num needed.
		SUB	CX,16384
EMS_CHECK_MOV_S4:
		CMP	AX,DX			;Compare to total number of
		JG	EMS_CHECK_MOV_ERR3	;  pages.
		MOV	DX,CX			;Copy ending offset
		XCHG	AX,DX			;Exchange offset and segment
EMS_CHECK_MOV_EXIT:
		CLC				;Clear error flag
EMS_CHECK_MOV_EXIT1:
		POP	DI                      ;Restore registers
		MOV	[BP+DI],AX		;Save offset
		MOV	[BP+DI+2],DX		;Save segnent/page
		POP	CX
		POP	BX
		RET
EMS_CHECK_MOV_CONV:
		MOV	CX,16			;convert segment into address
		MUL	CX
		ADD	AX,BX			;Add offset
		ADC	DX,0
		ADD	AX,WORD PTR [EMS_24_COUNT]	;Add len to start addr
		ADC	DX,WORD PTR [EMS_24_COUNT+2]
		SUB	AX,1			;Decriment count
		SBB	DX,0
		JMP	SHORT EMS_CHECK_MOV_EXIT
EMS_CHECK_MOV_ERR1:
		MOV	AH,95H			;offset too large
EMS_CHECK_MOV_SET_ERR:
		STC                     	;Indicate error
		JMP	SHORT EMS_CHECK_MOV_EXIT1
EMS_CHECK_MOV_ERR3:
		MOV	AH,93H			;Not enough pages
		JMP	SHORT EMS_CHECK_MOV_SET_ERR
EMS_CHECK_MOV ENDP
;======================================================================
;Function 25. Get Mappable Physical Address Array
;======================================================================
EMS_25		PROC	NEAR
		ASSUME  CS:CODE,DS:CODE,ES:NOTHING
		OR	AL,AL			;check subfunction
		JE	EMS_25_S1
		CMP	AL,1			;assure subfunction 0 or 1.
		JNE	EMS_25_ERR1
		MOV	WORD PTR SS:[BP-2],4	;replace saved cx with 4
		JMP	SHORT EMS_25_EXIT
EMS_25_S1:	MOV	AX,WINDOW_SEG
		XOR	CX,CX
EMS_25_L1:	MOV	ES:[DI],AX		;write segment
		MOV	ES:2[DI],CX		;write segment number
		ADD	AX,1024 		;Point to next segment
		ADD	DI,4
		INC	CX                      ;Indicate next page
		CMP	CX,3
		JLE	EMS_25_L1
		INC	CX			;number is 1 based not 0 based
EMS_25_EXIT:	XOR	AX,AX			;clear return code
EMS_25_EXIT1:	RET
EMS_25_ERR1:	MOV	AH,8FH			;Unknown subfunction
		JMP	SHORT EMS_25_EXIT1
EMS_25		ENDP
;======================================================================
;Function 26.  Get Expanded Memory Hardware Information
;======================================================================
EMS_26		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		CMP	OS_ENABLED,1		;Are OS funcctions enabled?
		JNE	EMS_26_ERR1             ;No, exit
		CMP	AL,1                    ;Subfunction 1, get page cnt
		JB	EMS_26_0 		;Jmp to subfunction 0
		JA	EMS_26_ERR2		;If > 1, invalid subfunction.
EMS_26_1:	CALL	EMS_03			;Since raw page = normal page,
		JMP	SHORT EMS_26_EXIT       ;  get normal page count.
EMS_26_0:	XOR	CX,CX
		MOV	WORD PTR ES:[DI],1024   ;16K pages (1024 paragraphs)
		MOV	ES:2[DI],CX		;No alternate register sets
		CALL	EMS_15_3		;Get context area size
		MOV	ES:4[DI],AX
		MOV	ES:6[DI],CX		;No DMA channels
		MOV	ES:8[DI],CX		;DMA channel operation
		XOR	AX,AX			;clear return code
EMS_26_EXIT:	RET
EMS_26_ERR1:	MOV	AH,0A4H			;operating system denied
		JMP	SHORT EMS_26_EXIT	;  access.
EMS_26_ERR2:	MOV	AH,8FH			;Invalid subfunction
		JMP	SHORT EMS_26_EXIT
EMS_26		ENDP
;======================================================================
;Function 27.  Get handle and allocate pages
;======================================================================
EMS_27		PROC	NEAR
		ASSUME DS:CODE,ES:NOTHING
		PUSH	BX			;Save register
		CMP	BX,TOTAL_PAGES		;Make sure request is not out
		JLE	EMS_27_S1		;  of range.
		MOV	AH,87H			;Not enough pages in system
		JMP	SHORT EMS_27_EXIT
EMS_27_S1:	PUSH	BX			;save num. of pages to alloc
		XOR	DX,DX			;search for handle =-1 (unaloc)
		DEC	DX
		CLC
		CALL	EMS_13			;get unallocated page count.
		POP	CX
		CMP	BX,CX			;check for enough free pages
		JL	EMS_27_ERR1
		MOV	DI,HANDLE_ARRAY		;Assign handle
		XOR	AX,AX			;search for free handles
		MOV	DX,AX			;dx=0 at start of hndl search
EMS_27_L1:	CMP	AL,[DI]			;if handle id = 0 then that
		JE	EMS_27_S2		;  hndl has not been allocated.
		ADD	DI,9			;Move di to point to next id.
		INC	DX
		CMP	DX,TOTAL_HANDLES	;have we searched all handles?
		JB	EMS_27_L1
		MOV	AH,85H			;no free handles
		JMP	SHORT EMS_27_EXIT
EMS_27_S2:	DEC	BYTE PTR [DI]		;indicate that handle is used
		MOV	BX,CX
		CALL	EMS_ASSIGN		;alloc pages, dx = new handle
EMS_27_EXIT:	POP	BX   			;Restore register
		RET
EMS_27_ERR1:	MOV	AH,88H
		JMP	SHORT EMS_27_EXIT
EMS_27		ENDP
;======================================================================
;Function 28. Alternate Map Register Set
;======================================================================
EMS_28_TBL	DW	OFFSET EMS_28_0	;Jump table for subfunctions
		DW	OFFSET EMS_28_1
		DW	OFFSET EMS_28_2
		DW	OFFSET EMS_28_3
		DW	OFFSET EMS_28_4
		DW	OFFSET EMS_28_3
		DW	OFFSET EMS_28_6
EMS_28		PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		CMP	OS_ENABLED,1		;See if function enabled
		JNE	EMS_28_ERR1
		CMP	AL,8			;check al for a number not 0-8
		JA	EMS_28_ERR2
		CMP	AL,6			;check al for function 4-8.
		JLE	EMS_28_S1		;If >5 point to unsupported
		MOV	AL,6			;  routine.
EMS_28_S1:	XOR	AH,AH			;clear top byte of subfunction
		MOV	DI,AX			;convert into jump address
		SAL	DI,1
		ADD	DI,OFFSET EMS_28_TBL
		XOR	AX,AX			;clear return code before call
		CALL	CS:[DI]
EMS_28_EXIT:	RET
EMS_28_ERR1:	MOV	AH,0A4H			;operating system denied
		JMP	SHORT EMS_28_EXIT	;  access.
EMS_28_ERR2:	MOV	AH,8FH			;invalid subfunction
		JMP	SHORT EMS_28_EXIT
EMS_28		ENDP
;----------------------------------------------------------------------
;Function 28.0  Get Alternate Map Register Set
;----------------------------------------------------------------------
EMS_28_0	PROC	NEAR
		PUSH	DX
		MOV	ES,ALT_MAP_PTRS		;Get pointer
		MOV	DI,ALT_MAP_PTRO
		MOV	SS:[BP-4],DI		;save values for exit
		MOV	SS:[BP-10],ES
		OR	DI,DI			;See if it is zero
		JNE	EMS_28_0_S1
		MOV	CX,ES			;If so, exit without saving
		OR	CX,CX			;  page map array.
		XOR	AX,AX			;Clear return code
		JE	EMS_28_0_EXIT
EMS_28_0_S1:	PUSH	DI			;save original pointer
		CALL	EMS_15_0		;copy page map
		POP	DI			;The return code will be
EMS_28_0_EXIT:	XOR	BL,BL                   ;  set by Function 15.0
		POP	DX                      ;Indicate non-support for
		RET                             ;  alternate mapping regs.
EMS_28_0	ENDP
;----------------------------------------------------------------------
;Function 28.1  Set Alternate Map Register Set
;----------------------------------------------------------------------
EMS_28_1	PROC	NEAR
		PUSH	BX
		PUSH	DX
		OR	BL,BL			;check bl = 0
		JNE	EMS_28_1_ERR
		MOV	DI,[BP-4]		;Restore DI
		MOV	ALT_MAP_PTRS,ES		;Save mapping pointer
		MOV	ALT_MAP_PTRO,DI
		OR	DI,DI			;See if it is zero
		JNE	EMS_28_1_S1
		MOV	CX,ES			;If so, exit without restoring
		OR	CX,CX			;  page map array.
		JE	EMS_28_1_EXIT
EMS_28_1_S1:	PUSH	DS
		MOV	SI,ES			;Put pointer into ds:si for
		MOV	DS,SI			;  function 15.1 call.
		ASSUME DS:NOTHING
		MOV	SI,DI   		;DS:SI = ES:DI
		CALL	EMS_15_1		;Restore page map
		POP	DS
		ASSUME DS:CODE
EMS_28_1_EXIT:	POP	DX
		POP	BX
		RET
EMS_28_1_ERR:	MOV	AH,9CH			;Alternate map register
		JMP	SHORT EMS_28_EXIT	;  sets not supported.
EMS_28_1	ENDP
;----------------------------------------------------------------------
;Function 28.2  Get Alternate Map Save Array Size
;----------------------------------------------------------------------
EMS_28_2	PROC	NEAR
		CALL	EMS_15_3		;Get save array size.
		MOV	DX,AX
		RET
EMS_28_2	ENDP
;----------------------------------------------------------------------
;Function 28.3 and 28.5  Deallocate Map Register Set
;----------------------------------------------------------------------
EMS_28_3	PROC	NEAR
		XOR	BL,BL			;set bl = 0
		XOR	AX,AX
		RET
EMS_28_3	ENDP
;----------------------------------------------------------------------
;Function 28.4  Deallocate Alternate Map Register Set
;----------------------------------------------------------------------
EMS_28_4	PROC	NEAR
		OR	BL,BL			;See if zero page indicated
		JNE	EMS_28_4_ERR1		;  if not, error
		XOR	AX,AX			;Clear return code.
		MOV	ALT_MAP_PTRS,AX		;Clear mapping pointer
		MOV	ALT_MAP_PTRO,AX
EMS_28_4_EXIT:	RET
EMS_28_4_ERR1:	MOV	AH,9CH			;Alt register sets not
		JMP	SHORT EMS_28_4_EXIT	;  supported
EMS_28_4	ENDP
;----------------------------------------------------------------------
;Function 28.6-28.8  Unsupported Subfunctions
;----------------------------------------------------------------------
EMS_28_6	PROC	NEAR
		OR	BL,BL			;see if zero page indicated
		JNE	EMS_28_6_ERR1		;if not, error
		XOR	AX,AX			;clear return code.
EMS_28_6_EXIT:	RET
EMS_28_6_ERR1:	MOV	AH,9CH			;Alt register sets not
		JMP	SHORT EMS_28_6_EXIT	;  supported
EMS_28_6	ENDP
;======================================================================
;Function 30.  OS/E Functions
;======================================================================
EMS_30		PROC	NEAR
		PUSH	DX
		CMP	OS_PASS_LOW,0
		JNE	EMS_30_S1
		CMP	OS_PASS_HIGH,0
		JE	EMS_30_S2		;first call, create password.
EMS_30_S1:	CMP	OS_PASS_LOW,BX		;Check password
		JNE	EMS_30_ERR1
		CMP	OS_PASS_HIGH,CX
		JNE	EMS_30_ERR1
		JMP	SHORT EMS_30_S3
EMS_30_S2:	PUSH	AX			;Read the system time using
		XOR	AH,AH			;  bios int 1A function 00.
		INT	1AH
		MOV	AX,DX			;copy low word of time
		INC	CX			;multiply by high word. Inc
		MUL	CX			;to assure count <> 0.
		MOV	OS_PASS_LOW,AX
		MOV	OS_PASS_HIGH,DX
		MOV	BX,AX                   ;Return password in BX,CX
		MOV	SS:[BP-2],DX		;Update CX on stack
		POP	AX			;get back subfunction
EMS_30_S3:	CMP	AL,2			;return key function
		JNE	EMS_30_S4
		XOR	AX,AX			;Clear return code
		MOV	OS_PASS_LOW,AX          ;Clear password
		MOV	OS_PASS_HIGH,AX
		MOV	OS_ENABLED,1		;set op system flag
		JMP	SHORT EMS_30_EXIT
EMS_30_S4:	CMP	AL,1			;Disable op system functions
		JNE	EMS_30_S5
		MOV	OS_ENABLED,0		;Clear flag
		JMP	SHORT EMS_30_EXIT
EMS_30_S5:	OR	AL,AL			;Enable op system functions
		JNE	EMS_30_ERR2
		MOV	OS_ENABLED,1		;Set flag
EMS_30_EXIT:	XOR	AX,AX
EMS_30_EXIT1:	POP	DX
		RET
EMS_30_ERR1:	MOV	AH,0A4H			;Access denied
		JMP	SHORT EMS_30_EXIT1
EMS_30_ERR2:	MOV	AH,8FH			;Subfunction not defined
		JMP	SHORT EMS_30_EXIT1
EMS_30		ENDP
;======================================================================
;Unsupported Function
;======================================================================
EMS_UNSP	PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		MOV	AH,91H			;Feature not supported.
		RET
EMS_UNSP	ENDP
;-----------------------------------------------------------------------------
;Convert segment address into logical page number
;Entry: ax - segment address to convert  EXIT: bl - logical page number
;-----------------------------------------------------------------------------
EMS_SEG2LOG	PROC	NEAR
		ASSUME CS:CODE,DS:NOTHING,ES:NOTHING
		PUSH	CX
		PUSH	DX
		XOR	BX,BX			;clear logical sector number
		MOV	DX,CS:WINDOW_SEG
		MOV	CX,4
EMS_SEG2_L1:	CMP	AX,DX
		JE	EMS_SEG2_FND
		ADD	DX,400H
		INC	BX
		LOOP	EMS_SEG2_L1
		MOV	AH,8BH			;segment not valid
		STC
		JMP	SHORT EMS_SEG2_EXIT
EMS_SEG2_FND:	CLC
EMS_SEG2_EXIT:	POP	DX
		POP	CX
		RET
EMS_SEG2LOG	ENDP
;------------------------------------------------------------------------
;EMS convert logical page to address
;Entry: bx = logical page  dx = handle of page owner
;Exit: dx,ax - absolute address of page. carry set - page not found
;------------------------------------------------------------------------
EMS_LOG2PHY	PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	DI
		MOV	DI,PAG_OWNER_TBL	;Point to page owner table
		MOV	CX,TOTAL_PAGES		;Check entry for each page
EMS_LOG2P_L1:	CMP	BYTE PTR [DI],DL	;See if owned by handle
		JNE	EMS_LOG2P_S1
		CMP	WORD PTR [DI+1],BX	;See if this is the page
		JE	EMS_LOG2P_S2		;  we have been looking for.
EMS_LOG2P_S1:	ADD	DI,3
		LOOP	SHORT EMS_LOG2P_L1
		MOV	AH,8AH			;page out of range for handle
		STC
		JMP	SHORT EMS_LOG2PHY_EXIT
EMS_LOG2P_S2:	SUB	DI,PAG_OWNER_TBL	;compute the phy page address
		MOV	AX,DI
		XOR	DX,DX			;Clear high word
		MOV	CX,3			;Divide by size of each entry
		DIV	CX
		MOV	CX,16384		;Mul page number by size of
		MUL	CX                      ;  page.
		ADD	AX,EXTEND_ADRL          ;Add starting address
		ADC	DL,EXTEND_ADRH
		XOR	DH,DH
		CLC				;clear error flag
EMS_LOG2PHY_EXIT:
		POP	DI
		RET
EMS_LOG2PHY	ENDP
;------------------------------------------------------------------------
;EMS Assign pages  bx = number of pages needed  dx = handle to assign pages.
;------------------------------------------------------------------------
EMS_ASSIGN	PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		CMP	AX,TOTAL_PAGES		;see if enough total pages
		JG	EMS_ASSIGN_ERR2
		PUSH	DX			;save handle
		PUSH	BX			;save pages to add
		MOV	DX,0FFFFH		;load unassigned handle
		CLC                             ;Get number of unassigned
		CALL	EMS_13                  ;  pages.
		POP	AX			;Get back number of pages
		POP	DX			;Get back handle
		CMP	BX,AX			;are there enough pages?
		JL 	EMS_ASSIGN_ERR1		;No, return error code.
		PUSH	AX			;Save number of pages to alloc
		CLC				;Set handle found flag
		CALL	EMS_13			;Get number of pages assigned
		POP	AX                      ;Get back num pages requested
		MOV	DI,PAG_OWNER_TBL	;point to page owner table
		MOV	CX,TOTAL_PAGES		;Get size of the array
		INC	CX			;Make sure loop complete
EMS_ASSIGN_L1:	OR	AX,AX			;See if we have assigned
		JE	EMS_ASSIGN_S2		;  enough pages.
		CMP	BYTE PTR [DI],0FFH	;see if page is unowned
		JNE	EMS_ASSIGN_S1		;Page owned, try another.
		MOV	[DI],DL			;if so, assign it to the hndl
		MOV	[DI+1],BX		;Assign page number
		INC	BX			;inc page number to assign
		DEC	AX			;one less page needed.
EMS_ASSIGN_S1:	ADD	DI,3			;point to the next page entry
		LOOP	EMS_ASSIGN_L1
EMS_ASSIGN_ERR1:
		MOV	AH,88H			;not enough unallocated pages
		STC				;set error flag
		JMP	SHORT EMS_ASSIGN_EXIT
EMS_ASSIGN_ERR2:
		MOV	AH,87H			;not enough pages in system
		STC				;set error flag
		JMP	SHORT EMS_ASSIGN_EXIT
EMS_ASSIGN_S2:	CLC
		XOR	AX,AX			;Clear return code.
EMS_ASSIGN_EXIT:
		RET
EMS_ASSIGN	ENDP
;------------------------------------------------------------------------
;EMS Deallocate pages
;Entry: dx = handle
;       bl = number of pages to deallocate
;------------------------------------------------------------------------
EMS_DEALLOC	PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		CMP	BL,0FFH			;See if clear all
		JNE	EMS_DEALLOC_S0
		XOR	BX,BX
		JMP	SHORT EMS_DEALLOC_S1
EMS_DEALLOC_S0:	XOR	BH,BH
		PUSH	BX			;Save num of pages to dealloc
		CLC
		CALL	EMS_13			;Get num of pages owned
		POP	AX			;Get back num pages to dealloc
		SUB	BX,AX			;Sub dealloc from total
EMS_DEALLOC_S1:	MOV	DI,PAG_OWNER_TBL	;Point to the page owner table
		MOV	CX,TOTAL_PAGES
EMS_DEALLOC_L1:	CMP	[DI],DL			;compare handle
		JNE	EMS_DEALLOC_S2		;if not, keep looking
		CMP	[DI+1],BX		;compare page number if above
		JB 	EMS_DEALLOC_S2		;  new limit, erase.  Else,
		MOV	BYTE PTR [DI],0FFH	;  keep looking
		MOV	WORD PTR [DI+1],0FFFFH
EMS_DEALLOC_S2:	ADD	DI,3			;Point to next entry
		LOOP	EMS_DEALLOC_L1
EMS_DEALLOC_EXIT:
		XOR	AH,AH                   ;Clear return code.
		RET
EMS_DEALLOC	ENDP
;-----------------------------------------------------------------------------
;EMS Check Handle
;Entry: dx = handle to check  Exit: zero flag set - handle not found, ah = 83h
;-----------------------------------------------------------------------------
EMS_CHECK_HDL	PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	DX
		PUSH	BX
		OR	DH,DH			;dh must be 0 for valid handle
		JNE	EMS_CHECK_ERROR
		XCHG	AX,DX			;Save ax
		MOV	AH,9			;Convert handle into an index
		MUL	AH			;  into the array
		MOV	BX,AX			;copy to base register
		ADD	BX,HANDLE_ARRAY		;add base address of array
		MOV	AX,DX			;restore ax
		CMP	BYTE PTR [BX],0		;If byte<>0, then good handle
		JE	EMS_CHECK_ERROR
		CLC				;clear error flag
EMS_CHECK_EXIT:	POP	BX
		POP	DX
		RET
EMS_CHECK_ERROR:
		MOV	AH,83H			;load error return code in ah
		STC				;set error flag
		JMP	SHORT EMS_CHECK_EXIT
EMS_CHECK_HDL	ENDP
;------------------------------------------------------------------------
;EMS exchange page
;Entry: bl = window page to map    dl,ax = absolute address of page to map.
;------------------------------------------------------------------------
EMS_EXCH_PAG 	PROC	NEAR
		ASSUME CS:CODE,DS:NOTHING,ES:NOTHING
		PUSH	CX
		PUSH	SI
		PUSH	DS
		PUSH	ES
		PUSH	CS			;point DS, ES to code segment
		POP	DS
		PUSH	CS
		POP	ES
		ASSUME DS:CODE,ES:CODE
 		PUSH	DEST.BASE_ADRL   	;Save GTD data in case a
 		PUSH	SOURCE.BASE_ADRL        ;  reentrant call is made.
 		MOV	BH,DEST.BASE_ADRH
  		PUSH	BX
 		MOV	BH,SOURCE.BASE_ADRH
 		PUSH	BX
		PUSH	AX			;Save page address
		PUSH	DX
		XOR	BH,BH			;Convert physical page number
		SAL	BX,1			;  into an index,
		SAL	BX,1
 		MOV	DI,OFFSET WINDOW_ADDR_BASE	;Point to window addr
		MOV	SI,MAP_ARRAY_PTR	;Point to mapping array.
		INC	SI
		INC	SI
;Check to see if the address requested has already been mapped.
		PUSH	BX			;Save offset into table
		MOV	DH,0FFH			;Init local page flag.
		XOR	BX,BX                   ;Search the mapping table
		MOV	CX,4                    ;  for the address to be
EMS_EXCH_L1:	CMP	AX,[SI+BX]              ;  mapped. If found, use
		JNE	EMS_EXCH_S1             ;  the data from the mapped
		CMP	DL,[SI+BX+2]            ;  page since it may be more
		JE 	EMS_EXCH_LOCAL          ;  accurate than the page
EMS_EXCH_S1:	ADD	BX,4			;  in extended memory.
		LOOP	EMS_EXCH_L1
		JMP	SHORT EMS_EXCH_S2	;Local page not found
EMS_EXCH_LOCAL:	MOV	AX,[SI+BX]		;Replace new page address with
		MOV	DL,[SI+BX+2]            ;  local page address.
              	MOV	DH,BL			;Save local page index.
EMS_EXCH_S2:	POP	BX			;Get original page index
		CMP	BL,DH			;See if we are remapping page
		JNE	EMS_EXCH_S3  		;If different, continue
 		ADD	SP,4			;Clean up stack
		JMP	SHORT EMS_EXCH_EXIT	;If same page, skip everything
;Save page currently mapped.
EMS_EXCH_S3:	PUSH	AX                      ;Save new page address
		PUSH	DX
		MOV 	AX,[SI+BX]              ;Load address of current page
		MOV 	DL,[SI+BX+2]            ;  into destination registers.
		OR	AX,AX			;If the current page is
		JNE	STORE_PAGE		;  unowned, don't save it.
		OR	DL,DL
		JE	LOAD_PAGE
STORE_PAGE: 	MOV 	CX,[DI+BX]              ;Load physical page address
		MOV 	DH,[DI+BX+2]            ;  into source registers.
           	CALL	EMS_MOVE_DATA
;Load in page from extended memory.
LOAD_PAGE: 	POP	DX			;Pop new page address into
		POP	CX                      ;  source registers.
		MOV	DH,DL
		CLI				;Critical code, no interrupts
		POP	AX			;Get back original destination
		MOV 	[SI+BX+2],AL            ;  address.
		POP     AX			;Load address of new page into
		MOV 	[SI+BX],AX		;  page map array.
		OR	CX,CX			;If the current page is
		JNE	EMS_EXCH_S4		;  unowned, don't save it.
		OR	DH,DH
		JE	EMS_EXCH_EXIT
EMS_EXCH_S4: 	MOV	AX,[DI+BX]         	;Get window address again.
		MOV	DL,[DI+BX+2]
            	CALL	EMS_MOVE_DATA		;Move memory
EMS_EXCH_EXIT:	STI				;All clear, allow interrupts
              	POP 	BX                      ;Restore GDT data
  		MOV	SOURCE.BASE_ADRH,BH
 		POP 	BX
  		MOV	DEST.BASE_ADRH,BH
 		POP 	SOURCE.BASE_ADRL
              	POP 	DEST.BASE_ADRL
		POP	ES			;Restore registers
		POP	DS
		POP	SI
		POP	CX
		RET
EMS_EXCH_PAG 	ENDP
;-----------------------------------------------------------------------------
;EMS MOVE DATA moves blocks of data using BIOS move block function.
;  Entry:  DL,AX - destination address  CX,DH - source address.
;-----------------------------------------------------------------------------
EMS_MOVE_DATA	PROC	NEAR
		PUSH	SI
		MOV	SI,OFFSET GDT		;ES:SI point to GDT
		MOV	DEST.BASE_ADRL,AX	;store source address
		MOV	DEST.BASE_ADRH,DL
		MOV	SOURCE.BASE_ADRL,CX	;store destination address
		MOV	SOURCE.BASE_ADRH,DH
		MOV	AH,87H			;BIOS move extended block
		MOV	CX,2000H		;move 8192 words
		INT	15H			;call BIOS
		POP	SI
		RET
EMS_MOVE_DATA	ENDP
;-----------------------------------------------------------------------------
;Init1. code initializes memory below this address then returns.
;-----------------------------------------------------------------------------
INITIALIZE1	PROC	NEAR
INIT1:		ASSUME	CS:CODE,DS:CODE,ES:CODE
		MOV	DI,PAG_OWNER_TBL
		MOV	AX,TOTAL_PAGES  	;Compute size of page owner
		MOV	DX,3                    ;  table.
		MUL	DX
		MOV	CX,AX
		XOR	AX,AX                   ;load ff's into page owner tbl
		DEC	AX                      ;  because ff is invalid hndl.
		REP	STOSB
		MOV	AX,TOTAL_HANDLES	;Compute size of handle array
		MOV	AH,9			;9 bytes / handle
		MUL	AH
		MOV	CX,AX
		ADD	CX,36			;Add room for context save
		XOR	AX,AX                   ;  area.
		REP	STOSW
		MOV	DI,HANDLE_ARRAY		;activate system handle
		DEC	BYTE PTR [DI]
		RET
INITIALIZE1	ENDP
;======================  End of resident Code  =============================
DATA_START	=	$
VDISK_HEADER 	DB	'VDISK  V'
ERRMSG		DB	'Not enough memory',13,10,'$'
;===========================================================================
;Initialize. This routine sets up the EMS driver.
;===========================================================================
INITIALIZE	PROC	NEAR
		ASSUME CS:CODE,DS:CODE,ES:NOTHING
		PUSH	CS			;Parse command line
		POP	ES
		LDS	SI,[REQ_HEADADR]	;get back addr of hdr
		ASSUME	DS:NOTHING,ES:CODE
		LDS	SI,DS:[SI.CONFIG_PTR]   ;Get pointer to config line
		MOV	BH,1    		;Look for first non-character
		MOV	CX,80			;80 characters in line
		CALL	SCAN_FOR                ;Scan for non-character.
 		OR	AH,AH			;see if found
		JNE	CHK_FOR_VDISK		;not found, skip remainder
		XOR	BH,BH    		;Look for next character
		CALL	SCAN_FOR		;Scan for character
 		OR	AH,AH			;see if found
		JNE	CHK_FOR_VDISK		;not found, skip remainder
;-----------------------------------------------------------------------------
;Non-blank line after driver name. Attempt to convert to memory size in Kbytes
;-----------------------------------------------------------------------------
		DEC	SI			;backup to 1st number
		MOV	CX,5			;Max 5 numbers.
		XOR	AX,AX			;Clear running total
		MOV	DI,10			;Decimal conversion constant
INIT_LOOP1:     MOV 	BL,DS:[SI]		;Get number
		INC	SI			;Point to next number.
		SUB	BL,'0'                  ;Convert to number and see
		JB      INIT_SKIP1              ;  if in range for a number.
		CMP	BL,9
		JA      INIT_SKIP1
		XOR	BH,BH
		MUL	DI  			;Mul by 16 to convert to hex
		ADD	AX,BX			;add to current total
		LOOP	INIT_LOOP1
;-----------------------------------------------------------------------------
;Compute number of pages available for allocated memory.
;-----------------------------------------------------------------------------
INIT_SKIP1:	XOR	DX,DX			;Clear high word for divide
		MOV	DI,16                   ;Divide number of Kbytes
		DIV	DI                      ;  by 16 Kbytes / page.
		OR	AX,AX			;if number less than 1 page
		JE 	CHK_FOR_VDISK		;  use default 24 pages.
		MOV	CS:TOTAL_PAGES,AX	;Save number of pages.
;-----------------------------------------------------------------------------
;Check for vdisk driver by reading int 19 vector.
;-----------------------------------------------------------------------------
CHK_FOR_VDISK:	PUSH	CS			;Set DS = CS
		POP	DS
		ASSUME 	DS:CODE
		MOV	AX,3519H		;Get interrupt vector 19
		INT	21H			;ES points to VDISK segment
		MOV	DI,12H			;VDISK header at offset 12h
		MOV	SI,OFFSET VDISK_HEADER
		MOV	CX,8			;8 characters in header
		XOR	BX,BX			;assume no memory used by vdisk
		REPE	CMPSB			;Compare header
		JNE 	CHK_EXT_MEM
;-----------------------------------------------------------------------------
;If VDISK present, read top of available memory from inside VDISK driver.
;-----------------------------------------------------------------------------
		MOV	SI,2CH			;load offset of memory used
		MOV	AX,ES:[SI]		;Get amount of memory used by
		MOV	DL,ES:[SI+2]		;  vdisk
		SUB	DL,10H			;Subtract 1 Mbyte starting adr
		XOR	DH,DH
		MOV	BX,16384		;Convert to 16k pages
		DIV	BX
		MOV	BX,AX			;save result in BX
;-----------------------------------------------------------------------------
;Find upper limit of extended memory.
;-----------------------------------------------------------------------------
CHK_EXT_MEM:	PUSH	CS			;ES = CS
		POP	ES
		ASSUME	ES:CODE
		MOV	AH,88H			;Get extended memory function
		CLC				;clr err flag. (fix IBMCACHE)
		INT	15H			;Returns extended memory in
		JC 	EXTEND_ERROR 		;  1k pages.
		MOV	CL,4			;Convert number of 1k pages
		SAR	AX,CL			;  into number of 16k pages.
		SUB	AX,TOTAL_PAGES		;See if there is enough room.
		JL	EXTEND_ERROR
		CMP	AX,BX			;Subtract memory used by vdisk
		JGE	EXTEND_MEM_OK1
EXTEND_ERROR:	JMP	DISP_ERR		;Error, abort instalation.
;-----------------------------------------------------------------------------
;Compute the starting address of the extended memory area for int 15.
;-----------------------------------------------------------------------------
EXTEND_MEM_OK1:	PUSH	CS                      ;  ES = CS
		POP	ES                      ;Convert memory req. to 1k
		ASSUME	ES:CODE                 ;  pages then store this
		MOV	CL,4                    ;  value for use as the new
		SAL	AX,CL                   ;  extended memory limit.
		MOV	EXT_MEM_LIMIT,AX
		MOV	CX,1024			;Convert number of 1024
                MUL	CX                      ;  byte pages to absolute adr
		ADD	DL,10H                  ;Add starting address of
		MOV	EXTEND_ADRL,AX          ;  extended memory and
		MOV	EXTEND_ADRH,DL          ;  save.
;-----------------------------------------------------------------------------
;Initialize the variables and pointers needed to emulate the EMS spec.
;-----------------------------------------------------------------------------
		MOV	BX,OFFSET DATA_START    ;Get end of installed code.
		MOV	PAG_OWNER_TBL,BX	;Save pointer to page table
		MOV	AX,TOTAL_PAGES          ;Get number of pages
		MOV	DX,3
		MUL	DX
		ADD	AX,BX           	;Add to current pointer
		MOV	HANDLE_ARRAY,AX         ;Save pointer to handle array
		MOV	CX,AX			;save current position
		MOV	AX,TOTAL_HANDLES	;compute size of handle
		MOV	AH,9                    ;  array using 9 bytes / hdl.
		MUL	AH
		ADD	AX,CX
		MOV	MAP_ARRAY_PTR,AX	;map array 18 bytes. 4 arrays.
		ADD	AX,72+15                ;Arrays + 15 to next segment.
;-----------------------------------------------------------------------------
;Compute the memory requirments for driver.
;-----------------------------------------------------------------------------
		MOV	CL,4			;Convert offset into a
		SHR	AX,CL			;  segment value
		MOV	BX,CS			;Get code segment
		ADD	AX,BX			;Add code segment to code length
		MOV	WINDOW_SEG,AX		;Store starting segment of ems
		PUSH	AX
;-----------------------------------------------------------------------------
;Generate and store abolute addresses of window pages.
;-----------------------------------------------------------------------------
		MOV	DX,16			;Convert segment into
		MUL	DX                      ;  absolute address.
		MOV	DI,OFFSET WINDOW_ADDR_BASE
		MOV	CX,4
EMS_INIT_L2:	MOV	[DI],AX			;Save absolute address
		MOV	[DI+2],DX
		ADD	AX,16384                ;Point to next page address
		ADC	DX,0
		ADD	DI,4             	;Point to next save address
		LOOP	EMS_INIT_L2
;-----------------------------------------------------------------------------
;Write the memory requirments to the device driver header
;-----------------------------------------------------------------------------
		POP	BX            		;Get back seg start of window
		ADD	BX,1000H                ;Add 64 Kbytes.
		XOR	AX,AX			;Start at offset 0
		PUSH	ES
		CALL	LOAD_HEADER  		;Load memory requirments into
		POP	ES                      ;  request header.
		MOV	DX,OFFSET PROGRAM	;Print copyright
		MOV	AH,9
		INT	21H
;-----------------------------------------------------------------------------
;Vector interrupt 15h to reserve the extended memory.
;-----------------------------------------------------------------------------
		PUSH	ES
		MOV	AX,3515H		;Get interrupt vector 15
		INT	21H
		MOV	OLD_INT15HO,BX		;save vector
		MOV	OLD_INT15HS,ES
		POP	ES
		MOV	AX,2515H		;Set interrupt vector 15
		MOV	DX,OFFSET INT_15H
		INT	21H			;Call DOS
;-----------------------------------------------------------------------------
;Vector the 67h interrupt to the driver. Jump to final installation code.
;-----------------------------------------------------------------------------
		MOV	AX,2567H		;Set interrupt vector 67
		MOV	DX,OFFSET INT_67H
		INT	21H			;Call DOS
		JMP	INIT1			;jump to final init. code.
;-----------------------------------------------------------------------------
;error routine to abort instalation.
;-----------------------------------------------------------------------------
DISP_ERR:	MOV	DX,OFFSET ERRMSG	;Tell user that the driver is
		MOV	AH,9			;  not loaded.
		INT	21H
		MOV	AX,3000H		;Get DOS version
		INT	21H
		XCHG	AL,AH			;Put number in proper order
		CMP	AX,31EH			;See if DOS 3.3
		MOV	AX,OFFSET DRIVER_END	;Offset of device driver code
		MOV	BX,CS           	;If >3.3, abort install with
		JB 	ERROR_ABORT_SKIP	; 0 memory. Otherwise leave
		XOR	AX,AX			;  driver stub installed.
ERROR_ABORT_SKIP:
		CALL	LOAD_HEADER		;Load into request header
		MOV	AX,8002	 		;Indicate error in the
		RET				;  driver return code.
;-----------------------------------------------------------------------------
;LOADHEADER loads the amount of memory needed into the request header.
;-----------------------------------------------------------------------------
LOAD_HEADER	PROC	NEAR
		LES	DI,[REQ_HEADADR]		;get addr of req hdr
		MOV	WORD PTR ES:[DI.ADDRESS],AX	;Store offset and
		MOV	WORD PTR ES:[DI.ADDRESS+2],BX   ;  code segment.
		RET
LOAD_HEADER	ENDP
;-----------------------------------------------------------------------------
;ScanFor - scans for first (non)occurance of character in line.
; Entry -  BH - 0 = scan for non character, 1 = scan for character.
;          DS:SI - string to scan.   CX - length of string
; Exit  -  AH - 1 = end of line found.
;-----------------------------------------------------------------------------
SCAN_FOR	PROC	NEAR
		XOR	AH,AH           	;Clear found flag
SCAN_LOOP1:	LODSB				;Get character
		OR	BH,BH			;see if first match or
		JE	SCAN_SKIP1		;  mismatch. 0 = match
		CMP	AL,20H                  ;Check for noncharacter.
		JLE	SCAN_SKIP4
		JMP	SHORT SCAN_SKIP2
SCAN_SKIP1:	CMP	AL,20H			;Check for character
		JG 	SCAN_SKIP4
SCAN_SKIP2:	CMP	AL,13			;Check for CR
		JE	SCAN_SKIP3
		CMP	AL,10			;Check for LF
		JE	SCAN_SKIP3
		LOOP	SCAN_LOOP1
SCAN_SKIP3:	INC	AH			;character not found
SCAN_SKIP4:	RET
SCAN_FOR	ENDP
END_OF_CODE	=	$
INITIALIZE	ENDP
CODE		ENDS
		END
