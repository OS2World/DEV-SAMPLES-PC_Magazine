CHECKCOM.BAT


ECHO OFF
DIR C:\COMMAND.COM | FIND "25307" > TEMP$$$1
COPY TEMP$$$1 TEMP$$$2 > NUL
IF EXIST TEMP$$$2 GOTO OK1
ECHO COMMAND.COM is the wrong size. Time to worry.
GOTO finish1
:OK1
DEL TEMP$$$2
ECHO COMMAND.COM is the right size.  You can relax.
:finish1
DEL TEMP$$$1
DIR C:\COMMAND.COM | FIND "3-17-87" > TEMP$$$1
COPY TEMP$$$1 TEMP$$$2 > NUL
IF EXIST TEMP$$$2 GOTO OK2
ECHO COMMAND.COM's date has been changed.  Time to worry.
GOTO finish2
:OK2
DEL TEMP$$$2
ECHO COMMAND.COM has the right date.  You can relax.
:finish2
DEL TEMP$$$1



