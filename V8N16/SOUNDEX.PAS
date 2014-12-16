SOUNDEX.PAS



PROGRAM TestSoundex;

USES Crt; (*comment out for TP3*)
TYPE
  SString = STRING[255];
VAR
  IPString : SString;
  Row : Byte;

  FUNCTION Soundex(TextString : SString) : SString;
  CONST SoundexTable : ARRAY[1..26] OF Char =
     '.123.12..22455.12623.1.2.2';
  (*  ABCDEFGHIJKLMNOPQRSTUVWXYZ  *)
  VAR
    SoundString : SString;
    FirstChar : Char;
    I1, I2 : Integer;
  BEGIN
    (* Provide for trailing zero fill  *)
    FillChar(SoundString[1], 255, '0');
    SoundString[0] := #255;
    (* First character is always alpha *)
    FirstChar := Upcase(TextString[1]);
    (*  First step - ASCII to soundex *)
    FOR I1 := 1 TO Length(TextString)-1 DO
      BEGIN
        I2 := Ord(Upcase(TextString[I1+1]))-64;
        (* Range check for good letters *)
        IF (I2 < 1) OR (I2 > 26) THEN I2 := 1;
        SoundString[I1] := SoundexTable[I2];
      END;
    I1 := 1; (* Initialize for second pass      *)
    (* Eliminate non-soundex characters and side by side duplicates  *)
    REPEAT
      WHILE SoundString[I1] = '.' DO Delete(SoundString, I1, 1);
      IF SoundString[I1] = SoundString[I1+1] THEN
        Delete(SoundString, I1, 1);
      I1 := I1 + 1;
    UNTIL SoundString[I1] = '0';
    Soundex := FirstChar+Copy(SoundString, 1, 3);
  END;                            (* End of Soundex FUNCTION         *)

BEGIN
  Row := 24;
  REPEAT
    IF Row = 24 THEN
      BEGIN
        Row := 1;
        ClrScr;
      END;
    GoToXY(10, 24);
    Write('Enter a name to be encoded:  ');
    ReadLn(IPString);
    IF IPString <> '' THEN
      BEGIN
        GoToXY(10, 24);
        ClrEol;
        GoToXY(10, Row);
        Write(IPString);
        GoToXY(32, Row);
        WriteLn('->  ', Soundex(IPString));
        Row := Row+1;
      END;
  UNTIL IPString = '';
END.


