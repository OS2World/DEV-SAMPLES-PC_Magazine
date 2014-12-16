
JUMP.PAS




{ Non - local Goto for Turbo Pascal 4.0 }
UNIT Jump;
INTERFACE
TYPE
  JmpBuf = RECORD
             SP : Word;
             SS : Word;
             CS : Word;
             IP : Word;
             BP : Word;
             DS : Word;
           END;

  { Save current context and return a code of 0 }
FUNCTION SetJmp(VAR X : JmpBuf) : Integer;

  { Restore context and return the given code }
PROCEDURE LongJmp(VAR X : JmpBuf; RetValue : Integer);

IMPLEMENTATION
  FUNCTION SetJmp; EXTERNAL;
  PROCEDURE LongJmp; EXTERNAL;
  {$L SETJMP.OBJ }
END.



