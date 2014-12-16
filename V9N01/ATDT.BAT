ATDT.BAT


@ECHO OFF
IF "%1"=="?" GOTO FIRSTIME
IF %1!==! GOTO LIST
IF %2!==! GOTO SEARCH
IF EXIST NUMBER.BAT GOTO DIAL
ECHO %0 %1 %2 %3 %4 %5 %6 %7 %8 %9 >UP.DAT
COPY C:\PHONE\BB.LST+UP.DAT C:\PHONE\BB.LST >NUL
DEL UP.DAT
ECHO .
ECHO (%1 %2 %3 %4 %5 %6 %7 %8 %9 --ADDED)
ECHO .
GOTO DONE
:FIRSTIME
CLS
ECHO --------------------[ B L A C K   B O O K   H E L P ]--------------------
ECHO .
ECHO ENTER NEW NUMBERS  : BB 9-999-999-9999 Last, First Street City St Zip
ECHO FIND\DIAL NUMBERS  : BB (Any character string)
ECHO  DELETE   NUMBERS  : XB (Any character string)
ECHO   LIST    NUMBERS  : BB
ECHO .
ECHO -------------------------------------------------------------------------
GOTO DONE
:LIST
IF NOT EXIST C:\PHONE\BB.LST GOTO FIRSTIME
CLS
ECHO -------------------------[ B L A C K   B O O K ]-------------------------
TYPE C:\PHONE\BB.LST | MORE
ECHO .
ECHO -------------------------------------------------------------------------
GOTO DONE
:SEARCH
CLS
IF NOT EXIST C:\PHONE\BB.LST GOTO FIRSTIME
FIND "%1" C:\PHONE\BB.LST | FIND /V "BB">NUMBER.BAT
ECHO -------------------------[ B L A C K   B O O K ]-------------------------
TYPE NUMBER.BAT
ECHO .
ECHO -------------------- TYPE CONTROL-C TO ABORT DIALING --------------------
ECHO .
ECHO To Dial %1, Pick up the phone and
PAUSE
NUMBER
:DIAL
CLS
ECHO %0%1,,,,Z>COM1
CLS
ECHO .
ECHO ------- DIALING %1 -------
ECHO .
ECHO Once the modem makes the connection, press
ECHO any key to hang it up and connect the phone.
PAUSE >NUL
ECHO ATZ>COM1
:DONE
ECHO .
IF EXIST NUMBER.BAT DEL NUMBER.BAT




