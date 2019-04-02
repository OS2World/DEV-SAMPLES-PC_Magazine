@ECHO OFF
REM GETODAY.BAT - gets today's date into the e-var Today
REM   in the format YYMMDD.
ECHO. | DATE > DATETMP$.BAT
ECHO SET Today=%%4>CURRENT.BAT
CALL DATETMP$
DEL DATETMP$.BAT
DEL CURRENT.BAT
SET count=

REM Loop1 changes Today to -YYYYMMDD
:Loop1
SET old=%Today%
FOR %%v IN (/%Today%) DO SET Today=%%v
FOR %%v IN (/%old%) DO IF '%%v'=='-' GOTO skip
FOR %%v IN (/%old%) DO IF '%%v%Today%'=='%old%' SET Today=%Today%%%v
:skip
REM ECHO The value of Today is "%Today%"
SET count=%count%x
IF NOT '%count%'=='xxxxx' GOTO Loop1

REM Loop2 reduces Today to YYMMDD
:Loop2
FOR %%v IN (/%Today%) DO SET Today=%%v
REM ECHO The value of Today is "%Today%"
SET count=%count%x
IF NOT '%count%'=='xxxxxxxx' GOTO Loop2

FOR %%v IN (old count) DO SET %%v=
