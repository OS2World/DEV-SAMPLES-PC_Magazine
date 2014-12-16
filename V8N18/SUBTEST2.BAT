
SUBTEST2.BAT


ECHO OFF

GOTO %1

:main1 SUBROUTINE
ECHO Entered MAIN1 routine
SET arg=Arg #1
CALL subtest2 sub1
ECHO Returned from SUB1 to MAIN1RTN
GOTO RETURN

:main2 SUBROUTINE
ECHO Entered MAIN2 routine
SET arg=Arg #2
CALL subtest2 sub1
ECHO Returned from SUB1 to MAIN2RTN
GOTO RETURN

:sub1 SUBROUTINE
ECHO Entered SUB1 routine with arg = %arg%
CALL subtest2 sub2
ECHO Returned from SUB2 to SUB1RTN
GOTO RETURN

:sub2 SUBROUTINE
ECHO Entered SUB2 subroutine
GOTO RETURN
:RETURN



