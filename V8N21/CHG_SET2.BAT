@ECHO OFF
REM CHG_SET2.BAT
SET V$=
:LOOP
IF !%P%==!-DB SET V$=%1;%V$%
IF !%P%==!-DE SET V$=%V$%%1;
SHIFT
IF NOT !%1==! IF NOT !%1==!%M% GOTO LOOP
%V@%=%V$%
SET M=
SET P=
SET V$=
%V@%
SET V@=
