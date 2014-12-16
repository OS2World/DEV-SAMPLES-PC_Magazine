ECHO OFF
:---------- WIPE.BAT ----------

CLS
IF "%1"=="" GOTO USAGE

:- Create temp file for DEBUG input. This creates a
:- temporary file that is 64K - 256 bytes of 0. This
:- file is used to destroy the files specified by the user.

ECHO RBX	>  WIPE.$$$
ECHO 0	>> WIPE.$$$
ECHO RCX	>> WIPE.$$$
ECHO FF00	>> WIPE.$$$
ECHO F CS:100 L FF00 0 >> WIPE.$$$
ECHO W	>> WIPE.$$$
ECHO Q	>> WIPE.$$$

DEBUG WIPE.$$1 < WIPE.$$$ > NUL
DEL WIPE.$$$

:- Top of loop for each input parameter to the batch file.
:- Use shift to do multiple input parameters. 
:- Only limit is 128 char cmd line.

:NEXTPARAM
IF .%1==. GOTO :DONE
IF NOT EXIST %1 GOTO NOFILE

:- One or more files, use file WIPE.$$1 created above to
:- destroy the first 64K - 256 bytes of each file and 
:- then delete the file.

ECHO.
ECHO Files matching the specification:   %1
ECHO.
ECHO are about to be permanently destroyed!!
ECHO To abort without deleting any files, press [CTRL-BREAK] or
PAUSE
FOR %%F IN (%1) DO COPY WIPE.$$1 %%F > NUL
IF EXIST %1 DEL %1
ECHO.
ECHO %1 file(s) destroyed and deleted
SHIFT
GOTO NEXTPARAM

:- No files matching spec, tell user and continue

:NOFILE
ECHO.
ECHO No files of type:    %1
ECHO.
SHIFT
GOTO NEXTPARAM

:- Define syntax to the user

:USAGE
ECHO WIPE - Permanently destroy and delete a file or group of files.
ECHO.
ECHO Usage:
ECHO.
ECHO        WIPE filespec1 [filespec2] ... [filespecN]
ECHO.
ECHO where: filespec1, filespec2, ... filespecN may be any legal DOS file
ECHO        specification. Each filespec may contain wildcard characters.
ECHO.

:- All done, exit the batch file

:DONE
if exist WIPE.$$1 del WIPE.$$1
