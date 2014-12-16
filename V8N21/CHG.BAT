@ECHO OFF
REM CHG.BAT a new version of PC MAGAZINE's CHPATH Utility (in Vol.7 Num.4)
IF !%3==! GOTO ERROR
CALL UPCASE V@ %1
IF !%V@%==!PATH SET V$=%PATH%
IF !%V@%==!APPEND SET V$=%APPEND%
IF !%V$%==! GOTO ERROR
%V@% > L_%V@%.BAT
CALL UPCASE M %2
CALL UPCASE P %3
IF !%P%==!-DB CHG_SET1 %V$%
IF !%P%==!-DE CHG_SET2 %V$%
IF !%P%==!-I  CHG_SET3 %V$%
IF !%P%==!-B  %V@%=%M%;%V$%
IF !%P%==!-E  %V@%=%V$%%M%;
REM IF you don't end your path with a semicolon, change
REM the line above to "IF !%P%==!-E  %V@@%=%V$%;%M%"
%V@%
SET M=
SET P=
SET V$=
GOTO END
:ERROR
ECHO Proper syntax is:
ECHO %0 {PATH ³ APPEND} DIRECTORY {-B ³ -E ³ -I ³ -DB ³ -DE }
:END
SET V@=
