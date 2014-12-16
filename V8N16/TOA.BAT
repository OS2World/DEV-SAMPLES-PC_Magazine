

REM      -----------------
REM      :    TOA.BAT    :
REM      -----------------

REM      Copy several files to drive A:

ECHO OFF
IF NOT "%1" == "" GOTO NextFile
COPY *.* A:
SHIFT
:NextFile
IF "%1" == "" quit
COPY %1 A:
SHIFT
GOTO NextFile
REM   End of TOA.BAT


