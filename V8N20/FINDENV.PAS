(*** FINDENV.PAS -  A Program to Find the Real DOS Environment ***)

USES DOS;

VAR
  envseg : Word;                  {address of environment}
  envsize : Word;                 {absolute size of environment}
  envinuse : Word;                {bytes in env up to first double 00}

  FUNCTION SpecialDOS : Boolean;  {true if DOS 3.2x}
  VAR
    regs : registers;
  BEGIN
    WITH regs DO BEGIN
      AH := $30;                  {Get MS-DOS version number}
      MsDos(regs);
      IF ((AL = 3) AND (AH > 19) AND (AH < 30)) THEN SpecialDOS := True
      ELSE SpecialDOS := False;
    END;
  END;

  FUNCTION getDOSPSP : Word;
  VAR
    tent, tent1 : Word;
  BEGIN
    tent := MemW[PrefixSeg:$16];
    WHILE True DO BEGIN
      tent1 := MemW[tent:$16];
      IF ((tent1 = 0) OR (tent1 = tent)) THEN BEGIN {this means we have DOS!}
        getDOSPSP := tent;
        Exit;
      END ELSE tent := tent1;
    END;
  END;

  PROCEDURE ComputeEnvInUse;
  VAR
    j : Word;
  BEGIN
    FOR j := 0 TO (envsize-3) DO
      IF MemW[envseg:j] = $0 THEN BEGIN {word 0 means two bytes}
        envinuse := j+2;
        Exit;
      END;
    envinuse := envsize;
  END;

  PROCEDURE getenv;
  VAR
    DOSPSP, temp : Word;
  BEGIN
    DOSPSP := getDOSPSP;
    temp := MemW[DOSPSP:$2C];
    IF ((temp <> 0) AND (NOT SpecialDOS)) THEN envseg := temp
    ELSE envseg := DOSPSP+MemW[DOSPSP-1:3]+1;
    envsize := 16*MemW[envseg-1:3];
    ComputeEnvInUse;
  END;

  FUNCTION HexDigit(b : Byte) : Char;
  BEGIN
    IF b < 10 THEN HexDigit := Char(Ord('0')+b)
    ELSE HexDigit := Char(Ord('A')-10+b);
  END;

  FUNCTION HexWord(w : Word) : STRING;
  BEGIN
    HexWord := HexDigit(w DIV $1000)+HexDigit((w MOD $1000) DIV $100)
    +HexDigit((w MOD $100) DIV $10)+HexDigit(w MOD $10);
  END;

BEGIN
  getenv;
  WriteLn('ENVREP. Copyright Ziff-Davis Corp., 1989');
  WriteLn('  Your active environment environment is at '+HexWord(envseg)+'H.');
  WriteLn('  The size of the environment is ', envsize, ' bytes');
  WriteLn('    of which ', envinuse, ' bytes are used');
  WriteLn('    leaving ', envsize-envinuse, ' bytes free.');
  WriteLn('  Have a good day.');
END.


