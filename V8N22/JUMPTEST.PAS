JUMPTEST.PAS





PROGRAM JumpTest;
USES Jump;
VAR
  JumpBuffer : JmpBuf;
  RetValue : Integer;
  X : Integer;

  PROCEDURE A;
  BEGIN
    WriteLn('In Procedure A');
    IF X = 1 THEN
      LongJmp(JumpBuffer, 1)
      { Return to outer level with RetValue = 1 }
    ELSE
      BEGIN
        X := X+1;                     
        WriteLn('Returning from A');
      END;
  END;

  PROCEDURE B;
  BEGIN
    WriteLn('In Procedure B');
    A;
    WriteLn('Returning from B');
  END;

BEGIN
  X := 0;
  REPEAT
    RetValue := SetJmp(JumpBuffer);
    IF RetValue = 0 THEN
      B
    ELSE
      WriteLn('Exit with RetValue = ', RetValue);             
  UNTIL RetValue <> 0;
END.



