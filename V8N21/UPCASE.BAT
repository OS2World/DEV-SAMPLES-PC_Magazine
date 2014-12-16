@ECHO OFF
REM Syntax: UPCASE {VarName} {string}
IF %1!==! GOTO END
SET T$=%PATH%
PATH=%2
SET %1=%PATH%
PATH=%T$%
SET T$=
:END
