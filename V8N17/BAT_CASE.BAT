

ECHO OFF
CLS
:MENU
ECHO WHAT would you like to do now?
ECHO    (S) Run Spreadsheet
ECHO    (D) Run Database
ECHO    (W) Run Word Processor
ECHO    (Q) Quit
GETKEY
SET opt=0
REM 68=D, 81=Q, 83=S, 87=W, 100=d, 113=q, 115=s, 119=w
FOR %%e IN (68 69 81 82 83 84 87 88 100) DO IF ERRORLEVEL %%e SET opt=%%e
FOR %%e IN (101 113 114 115 116 119 120) DO IF ERRORLEVEL %%e SET opt=%%e
GOTO CASE%opt%
:CASE0
:CASE69
:CASE82
:CASE84
:CASE88
:CASE101
:CASE114
:CASE116
:CASE120
ECHO That was not a valid option
PAUSE
GOTO MENU

:CASE115
:CASE83
ECHO Pretending to run Spreadsheet
PAUSE
GOTO MENU

:CASE68
:CASE100
ECHO Pretending to run Database
PAUSE
GOTO MENU

:CASE119
:CASE87
ECHO Pretending to run Word Processor
Pause
GOTO MENU

:CASE113
:CASE81
ECHO ENDING it all


