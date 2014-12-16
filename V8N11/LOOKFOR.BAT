
@ECHO OFF
IF /%1 ==/ GOTO EXIT
ATTRIB %1 /S
GOTO End
:EXIT
ECHO Must have Parameters
:End
