'****** CURPATH.BAS

'Copyright (c) 1988, Ziff Comunications Co.
'PC Magazine * Don Malin
'Queries the current directory in OS/2

DEFINT A-Z                              'Default to integers

DECLARE FUNCTION DosQCurDir%(BYVAL Drive, BYVAL StrSeg, BYVAL StrOff, _
	SEG Length)

DECLARE FUNCTION CurPath$(Drive$)    'BASIC wrapper for OS/2 call

INPUT "Which drive (ENTER for current drive)"; Drive$   'ask for drive to check
PRINT "The current directory is "; CurPath$(Drive$)   'print the directory

FUNCTION CurPath$(Drive$) STATIC

	IF LEN(Drive$) THEN         'Was a drive letter given?
	DriveNumber = ASC(UCASE$(Drive$)) - 64   'Yes, convert to drive number
	ELSE
	DriveNumber = 0             'No, use the current drive
	END IF

	BufLen = 128               'OS/2 needs buffer's length
	Path$ = Space$(BufLen)     'Buffer to receive the name
                                        'invoke the function
DOSError = DosQCurDir%(DriveNumber, VARSEG(Path$), SADD(Path$), BufLen)

	IF DOSError THEN              'Show there was an error
	CurPath$ = "Error" + STR$(DOSError)  'Append the OS/2 error number
	ELSE                     'Return what precedes CHR$(0)
	CurPath$ = "\" + LEFT$(Path$, INSTR(Path$, CHR$(0)) - 1)
	END IF

END FUNCTION
