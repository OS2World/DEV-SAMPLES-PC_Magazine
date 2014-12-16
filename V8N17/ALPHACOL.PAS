


PROGRAM AlphaCol;
(*Translate integers to and from alphabetic
  column headings.  Integers from 0 to 701,
  headings from " A" to "ZZ"*)

TYPE AString = STRING[2];

VAR i : Integer;

  FUNCTION Alpha(i : Integer) : AString;
  CONST digits : ARRAY[0..26] OF Char = ' ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  BEGIN
    Alpha := digits[i DIV 26] + digits[Succ(i MOD 26)];
  END;

  FUNCTION Numeric(AlStg : AString) : Integer;
  BEGIN
    IF AlStg[1] = ' ' THEN
      Numeric := (Ord(AlStg[2])-65)
    ELSE
      Numeric := ((Ord(AlStg[1])-64)*26) + (Ord(AlStg[2])-65);
  END;

BEGIN                             {Demo}
  FOR i := 0 TO 701 DO
    BEGIN
      Write('Column is *', Alpha(i), '*');
      WriteLn('  Column value is ', Numeric(Alpha(i)), '.');
    END;
END.



