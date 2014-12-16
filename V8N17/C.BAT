
ECHO OFF
C:
IF "%1"=="" GOTO End
IF  %1==* GOTO Dir
CD  %1
IF "%2"=="" GOTO End
IF NOT %2==* GOTO End
:Dir
DIR
:End


