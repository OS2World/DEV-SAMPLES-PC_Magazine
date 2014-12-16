scrndump.pas



UNIT ScrnDump;
{   Written by: Thomas L. Bregante, 1988 }

INTERFACE

USES
  Graph,
  Printer;

CONST
  EpsonFx = 1;
  IBMGR = 2;
  IBMPRO = 2;

  PROCEDURE Scrdmp(PrinterType : Byte);

IMPLEMENTATION

  PROCEDURE Scrdmp(PrinterType : Byte);
  CONST
    Esc = $1B;
  VAR
    K, I, X, Y : Integer;
    Pins, Pin, Bcolor : Byte;
    Vlimit, Hlimit, Vextra, Klimit : Integer;

    PROCEDURE InitLine(Columns : Integer);
      { Setup for double density graphics}
    VAR
      ColMod, ColDiv : Byte;
    BEGIN
      ColDiv := Columns DIV 256;
      ColMod := Columns MOD 256;
      Write(lst, Char(Esc), 'L', Char(ColMod), Char(ColDiv));
    END;

    PROCEDURE SetPrinter(Ptype : Byte);
      { Set to 8/72 inches per line}
    BEGIN
      CASE Ptype OF
        1 : WriteLn(lst, Char(Esc), 'A', Char(8));
        2 : WriteLn(lst, Char(Esc), 'A', Char(8), Char(Esc), '2');
      END;                        (* Case *)
    END;

    PROCEDURE ResetPrinter(Ptype : Byte);
      { Set to 6 lines per inch and sent a form feed. }
    BEGIN
      CASE Ptype OF
        1, 2 : WriteLn(lst, Char(Esc), '2', Char(12));
      END;                        (* Case *)
    END;

  BEGIN
    SetPrinter(PrinterType);
    Bcolor := GetBkColor;
    Hlimit := GetMaxX;
    Vlimit := GetMaxY DIV 8;
    Vextra := GetMaxY MOD 8;
    Klimit := 7;
    FOR I := 0 TO Vlimit DO
      BEGIN
        InitLine(Hlimit+1);
        FOR X := 0 TO Hlimit DO
          BEGIN
            Pins := 0;
            IF I = Vlimit THEN Klimit := Vextra;
            FOR K := 0 TO Klimit DO
              BEGIN
                Y := (I*8)+K;
                Pin := GetPixel(X, Y);
                IF Pin <> Bcolor THEN {Compare to background}
                  Pins := Pins+1 SHL (7-K); {Calc power of 2}
              END;
            Write(lst, Char(Pins));
          END;
        WriteLn(lst);
      END;
    ResetPrinter(PrinterType);
  END;                            {SCRDMP}

END.
