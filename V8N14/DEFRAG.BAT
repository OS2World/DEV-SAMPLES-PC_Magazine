

ECHO off
CLS	
ECHO Checking condition of drive %1 ...

chkdsk %1/F >lpt1:

chkfrag %1 /% /L >lpt1:
IF ERRORLEVEL 255 GOTO error
IF ERRORLEVEL 24  GOTO nodefrag

ECHO Drive %1 fragmented 25% or more .. starting defrag
defragit %1>lpt1        *** Replace with your utility ***
GOTO end

:nodefrag
ECHO Drive %1 does not require defragging
GOTO end

:error
ECHO Error occured during CHKFRAG.

:end
ECHO DEFRAG done.


