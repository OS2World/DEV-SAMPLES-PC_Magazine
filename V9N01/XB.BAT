XB.BAT




@ECHO OFF
IF %1!==! GOTO OOPS
IF NOT %2!==! GOTO TOOMANY
FIND /V "%1" C:C:\PHONE\BB.LST | FIND /V "BB" > C:\PHONE\UP.DAT
REM TYPE C:\PHONE\BB.LST | FIND /V "%1" > C:\PHONE\UP.DAT
DEL C:\PHONE\BB.LST
REN C:\PHONE\UP.DAT BB.LST
GOTO END
:TOOMANY
ECHO .
ECHO Sorry, you cannot have spaces in your XB character string.
:OOPS
ECHO .
ECHO To DELETE names from the BLACK BOOK, type: XB (Any character string).
ECHO .
:END




