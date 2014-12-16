

REM      -------------------
REM      :    FROMA.BAT    :
REM      -------------------

REM      Copy several files from drive A:

ECHO OFF
IF NOT "%1" == "" GOTO NextFile
COPY a:*.*
SHIFT
:NextFile
IF "%1" == "" quit
COPY A:%1
SHIFT
GOTO NextFile
REM   End of FROMA.BAT


