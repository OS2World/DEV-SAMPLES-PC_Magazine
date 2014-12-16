/*
 *	OS2TERM.C - An interrupt-driven OS/2 terminal emulator
 *
 *	This program uses OS/2's COM0x.SYS serial device
 *	driver to turn a PC into a simple terminal.  Incoming 
 *	data is buffered in OS/2's 1,024-byte serial receive
 *	queue and transferred to the program's data space
 *	using wait-for-something reads.  DTR and RTS are asserted
 *	but no handshaking is performed with the RS-232 control
 *	pins.  Execution is terminated when ESC	is pressed.
 *
 *	Compile and link with:  cl -Lp -G2 -Zp os2term.c
 *
 *	Copyright (c) 1989 Ziff-Davis Publishing Co.
 *	Written May 1989 for PC Magazine by Jeff Prosise
 */

#define INCL_DOS
#define INCL_SUB
#define INCL_DOSDEVICES

#define SERIAL 0x01
#define SETBAUDRATE 0x41
#define SETLINECTRL 0x42
#define SETDCBINFO 0x53
#define GETDCBINFO 0x73

#define STACK_SIZE 2048
#define BPS 9600
#define KBD_HANDLE 0
#define VIO_HANDLE 0

#include <os2.h>
#include <stdio.h>

struct {
	unsigned char DataBits;
	unsigned char Parity;
	unsigned char StopBits;
} LineCtrl = { 	8,		// 8 data bits
		0,		// No parity
		0  };		// 1 stop bit

struct {
	unsigned short usWriteTimeout;
	unsigned short usReadTimeout;
	unsigned char bFlags1;
	unsigned char bFlags2;
	unsigned char bFlags3;
	unsigned char bErrorReplacementChar;
	unsigned char bBreakReplacementChar;
	unsigned char bXONChar;
	unsigned char bXOFFChar;
} DCBInfo;

unsigned short hCom;		// COM handle
unsigned char InBuffer[256];	// Input buffer

/*
 *	The primary thread opens and initializes the COM
 *	driver, starts a thread to monitor the serial port,
 *	displays and outputs characters typed at the keyboard,
 *	and terminates when ESC is pressed.
 */

main()
{
	unsigned short usAction;
	unsigned short usBaudRate = BPS;
	unsigned ThreadID;
	static char ComThdStk[STACK_SIZE];
	struct _KBDKEYINFO KbdData;
	unsigned short usBytesWritten;

	void far ComThread();

	/* Open and initialize COM1 */

	if (DosOpen("COM1", &hCom, &usAction, 0L, 0, 1, 0x12, 0L)) {
		printf("COM1 not available or COM0x.SYS not loaded\n");
		exit(1);
	}

	/* Set data rate to 9600 bps and line format to N81 */

	DosDevIOCtl(0L, &usBaudRate, SETBAUDRATE, SERIAL, hCom);
	DosDevIOCtl(0L, &LineCtrl, SETLINECTRL, SERIAL, hCom);

	/* Set Device Control Block parameters */

	DosDevIOCtl(&DCBInfo, 0L, GETDCBINFO, SERIAL, hCom);

	DCBInfo.usWriteTimeout = 6000;	// 60 second write timeout
	DCBInfo.usReadTimeout = 6000;	// 60 second read timeout
	DCBInfo.bFlags1 = 0x01;		// Enable DTR
	DCBInfo.bFlags2 = 0x40;		// Enable RTS
	DCBInfo.bFlags3 = 0x04;		// Wait-for-something reads

	DosDevIOCtl(0L, &DCBInfo, SETDCBINFO, SERIAL, hCom);

	/* Create a thread to monitor the serial port */

	DosCreateThread(ComThread, &ThreadID, ComThdStk+STACK_SIZE);

	/* Monitor the keyboard and output typed characters */

	do {
		KbdCharIn(&KbdData, IO_WAIT, KBD_HANDLE);

		if ((KbdData.chChar != 0) && (KbdData.chChar != 0x1B)) {
			VioWrtTTy(&KbdData.chChar, 1, VIO_HANDLE);
			DosWrite(hCom, &KbdData.chChar, 1, &usBytesWritten);
		}

	} while (KbdData.chChar != 0x1B);

	DosExit(EXIT_PROCESS, 0);
}

#pragma check_stack (off)	// Disable stack checking

/*
 *	This thread monitors COM1 for incoming bytes and writes
 *	any it receives to the display screen.  If an error is
 *	returned by DosRead(), the thread terminates itself.
 */

void far ComThread()
{
	unsigned short usBytesRead;

	while (!DosRead(hCom, InBuffer, 256, &usBytesRead))
		if (usBytesRead)
			VioWrtTTy(InBuffer, usBytesRead, VIO_HANDLE);

	DosExit(EXIT_THREAD, 1);
}
