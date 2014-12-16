ECHO off
REM rspath.bat
IF "%1"=="" GOTO error
IF EXIST %1spath.bat GOTO reset
IF "%2"=="" GOTO error
IF EXIST rsp%1th.bat GOTO append
IF EXIST r%1path.bat GOTO start
GOTO error
:append
SET op=%path%
PATH=%path%;%2
GOTO end
:start
SET op=%path%
PATH=%2;%path%
GOTO end
:reset
PATH=%op%
GOTO end
:error
ECHO USAGE: RSPATH A/S/R [PATH]
ECHO A to add a path at end
ECHO S to add a path at beginning
ECHO R to restore old path
:end
PATH
