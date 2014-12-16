


{$A-} {Delete this line for TP4}
PROGRAM SlowFast;
(* This program is used to demonstrate how
   a program can be slowed with data
   misalignment on a 16-bit computer.*)
USES Dos;
CONST
  oddeven : ARRAY[Boolean] of String[4] =
          ('EVEN','ODD ');
VAR
  Start, Elapsed : LongInt;
  i, EmptyLoop : LongInt;
  b : byte;
  j : LongInt;

  FUNCTION time100ths : LongInt;
  VAR H,M,S,F : Word;
  BEGIN
    GetTime(H,M,S,F);
    Time100ths := (((((LongInt(H)*60) + M) * 60) + S) * 100) + F;
  END;

  {$IFDEF VER40}
  PROCEDURE Neutral;
  BEGIN END;

  PROCEDURE Slow;
  VAR b : Byte;
  BEGIN  Neutral; END;

  PROCEDURE Fast;
  BEGIN  Neutral;  END;
  {$ENDIF}

BEGIN
  WriteLn('Offset of i, ',ofs(i),' is ',oddeven[odd(ofs(i))]);
  WriteLn('Offset of j, ',ofs(j),' is ',oddeven[odd(ofs(j))]);
  Start := Time100ths;
  FOR i := 1 TO 1000000 DO {nothing} ;
  Elapsed := Time100ths-Start;
  EmptyLoop := Elapsed;
  WriteLn('Time using i: ', Elapsed DIV 100,'.', Elapsed MOD 100);
  Start := Time100ths;
  FOR j := 1 TO 1000000 DO {nothing} ;
  Elapsed := Time100ths-Start;
  WriteLn('Time using j: ', Elapsed DIV 100,'.', Elapsed MOD 100);
  {$IFDEF VER40}
  Start := time100ths;
  FOR i := 1 to 1000000 DO fast;
  Elapsed := time100ths - Start - EmptyLoop;
  WriteLn('Time using fast: ', Elapsed DIV 100,'.', Elapsed MOD 100);
  Start := time100ths;
  FOR i := 1 to 1000000 DO slow;
  Elapsed := time100ths - Start - EmptyLoop;
  WriteLn('Time using slow: ', Elapsed DIV 100,'.', Elapsed MOD 100);
  {$ELSE}
  WriteLn('No stack test -- TP5 aligns the stack even with {$A-}');
  {$ENDIF}
END.


