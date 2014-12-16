








'********** FLAGS.BAS

DEFINT A-Z
DECLARE SUB ClearAll ()                 'clears all flags
DECLARE SUB ClearFlag (FlagNum)         'clears a single flag
DECLARE SUB SetFlag (FlagNum)           'sets a single flag
DECLARE FUNCTION GetFlag% (FlagNum)     'retrieves a single flag

CLS
ClearAll                        'clear all the flags

FOR X = 1 TO 64                 'display each flag to prove they're zero
    PRINT GetFlag%(X);
NEXT
PRINT : PRINT

FOR X = 1 TO 64                 'set all of the flags
    SetFlag X
NEXT

FOR X = 1 TO 64                 'display each flag again
    PRINT GetFlag%(X);
NEXT
PRINT : PRINT

FOR X = 1 TO 64 STEP 2          'clear every other flag
    ClearFlag X
NEXT

FOR X = 1 TO 64                 'prove that it worked
    PRINT GetFlag%(X);
NEXT




