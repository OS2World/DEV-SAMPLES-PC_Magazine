

'******** HARDWARE.BAS - determines installed hardware using Turbo Basic

CLS
CALL INTERRUPT &H11                             'call BIOS routine
Equip$ = BIN$(REG(1))                           'set binary of AX in Equip$
Length = LEN(Equip$)                            'find number of bits returned
Equip$ = STRING$(16 - Length, 48) + Equip$      'adjust for 16 bits

PCRam = VAL("&B" + MID$(Equip$, 13, 2)) + 1 * 16  'Bit 3 & 2
VMode = VAL("&B" + MID$(Equip$, 11, 2))           'Bit 5 & 4
DiskDrives = VAL("&B" + MID$(Equip$, 9, 2)) + 1   'Bit 7 & 6
RS232 = VAL("&B" + MID$(Equip$, 5, 3))            'Bit 11,10 & 9
Game = VAL("&B" + MID$(Equip$, 4, 1))             'Bit 12
Parallel = VAL("&B" + MID$(Equip$, 1, 2))         'Bit 15 & 14

CALL INTERRUPT &H12                             'call BIOS routine to
SysMem = REG(1)                                 '  determine memory size

IF VMode = 1 THEN Monitor$ = " 40 X 25 Color Graphics Adapter"
IF VMode = 2 THEN Monitor$ = " 80 X 25 Color Graphics Adapter"
IF VMode = 3 THEN Monitor$ = " Monochrome Display Adapter"

PRINT "Disk Drives      "; DiskDrives
PRINT "Serial Port      "; RS232
PRINT "Game Ports       "; Game
PRINT "Parallel Ports   "; Parallel
PRINT "System Memory    "; SysMem; "K"
PRINT "Video Adapter    "; Monitor$



