ECHO OFF
IF "%1"=="" GOTO NoParam
FOR %%v IN (E: F: e: f:) DO IF %1==%%v GOTO InUse
SUBST %1 /D > NUL
SUBST %1 .
%1
CLS
ECHO IF you're not in SUBSTed drive "%1" now, either you gave 
ECHO an erroneous parameter OR your LASTDRIVE line in CONFIG.SYS
ECHO fails to specify a value of at least "%1".
GOTO End
:NoParam
ECHO SYNTAX: "SUBSTDOT d:", where d: is the drive letter to use.
GOTO End
:InUse
ECHO The drive letter "%1" is in use.
:End
