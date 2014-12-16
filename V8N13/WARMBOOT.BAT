GOTO batch
N WARMBOOT.COM
A 100
MOV BX,1234
MOV AX,0040
MOV DS,AX
MOV [0072],BX
JMP FFFF:0000

RCX
11
W
Q
:Batch
ECHO OFF
DEBUG < %0.BAT | FIND /C "Error"
ECHO IF the line above contains a 1, %0.COM was created
ECHO successfully.  Otherwise, check the DEBUG script lines,
ECHO because they contain an error.
