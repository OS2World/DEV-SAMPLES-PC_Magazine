ECHO off
CD \LANGS\SRC
FOR %%e IN (ASM BAS PAS SCR) DO IF EXIST %1.%%e GOTO %%e
ECHO Source module "%1" not found
GOTO end
:asm
MASM %2 %1 C:\LANGS\OBJ\%1 %1;
GOTO end
:bas
BC %1,C:\LANGS\OBJ\%1 /ZI/O/E/X%2;
GOTO end
:pas
TPC %1 %2
GOTO end
:scr
CD \LANGS\PGM
DEBUG < C:\LANGS\SRC\%1.SCR
:end
CD \
