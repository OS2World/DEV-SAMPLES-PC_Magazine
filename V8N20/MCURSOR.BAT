ECHO OFF
IF "%2"=="" GOTO BadParams
FOR %%v IN (0 1 2 3 4 5 6 7 8 9 A B C D a b c d) DO IF %%v==%1 GOTO OK1
GOTO BadParams
:OK1
FOR %%v IN (0 1 2 3 4 5 6 7 8 9 A B C D a b c d) DO IF %%v==%2 GOTO OK2
GOTO BadParams
:OK2
ECHO Creating DEBUG script to set cursor lines to %1 and %2
ECHO A 100 > CURSOR.$$$
ECHO MOV AH,01 >> CURSOR.$$$
ECHO MOV CH,0%1 >> CURSOR.$$$
ECHO MOV CL,0%2 >> CURSOR.$$$
ECHO INT 10 >> CURSOR.$$$
ECHO INT 20 >> CURSOR.$$$
REM Using MORE in the next line gets an extra
REM blank line before G, which is necessary to
REM end the Assemble mode.
ECHO G | MORE >> CURSOR.$$$
ECHO Q >> CURSOR.$$$
ECHO Now RUNNING the DEBUG script
DEBUG < CURSOR.$$$ > NUL
DEL CURSOR.$$$
GOTO End
:BadParams
ECHO SYNTAX: "MCURSOR top bot", where top and bot are hex numbers
ECHO 0-9 or A-D.
:End
