
®MDNM¯LOG.BAT


ECHO OFF
SET TYPE=
IF "%1"=="" GOTO Syntax
FOR %%v IN (WP SS wp ss) DO IF %1==%%v SET TYPE=BIZ
FOR %%v IN (DD FS dd fs) DO IF %1==%%v SET TYPE=FUN
IF "%TYPE%"=="" GOTO Syntax
REM > START_%1.%TYPE%
DIR START_%1.%TYPE% | FIND "START_" >> C:\RECORDS.LOG
DEL START_%1.%TYPE%
GOTO %1
:WP
ECHO Your WordProcessor here
PAUSE
GOTO endlog
:SS
ECHO Your Spreadsheet here
PAUSE
GOTO endlog
:DD
ECHO Your Dungeons 'n Dragons here
PAUSE
GOTO endlog
:FS
ECHO Your Flight Simulator here
PAUSE
:Endlog
REM > END___%1.%TYPE%
DIR END___%1.%TYPE% | FIND "END___" >> C:\RECORDS.LOG
DEL END___%1.%TYPE%
ECHO ____________ >> C:\RECORDS.LOG
GOTO End
:Syntax
ECHO Syntax: "LOG NN", where NN is one of WP, SS, DD, FS
ECHO   WP=Word Processing
ECHO   SS=Spreadsheet
ECHO   DD=Dungeons 'n Dragons
ECHO   FS=Flight Simulator
:End


