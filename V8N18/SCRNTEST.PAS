scrntest.pas


PROGRAM ScrnDumpTest;
{ Author: Thomas L. Bregante, 1988 }

USES
  Crt,
  Graph,
  ScrnDump; {ScrnDump uses the Graph Unit}

VAR
  GraphDriver, GraphMode : Integer;
  X, Y, MaxX, MaxY : Integer;
  I, ErrorCode : Integer;
  Ch : Char;
  PrinterType : Byte;

BEGIN
  Clrscr;
  WriteLn('1  Epson FX Printer');
  WriteLn('2  IBM Graphics Printer');
  WriteLn('3  IBM Proprinter');
  WriteLn;
  Write('What Type of printer do you have (1, 2 or 3) ? ');
  X := WhereX;
  Y := WhereY;
  REPEAT
    GotoXY(X, Y);
    Ch := ReadKey;
    Write(Ch);
  UNTIL (Ch > '0') AND (Ch < '4');
  CASE Ch OF
    '1' : PrinterType := EpsonFx;
    '2' : PrinterType := IBMGR;
    '3' : PrinterType := IBMPRO;
  END;                            {Case}
  GraphDriver := Detect;
  InitGraph(GraphDriver, GraphMode, '');
  ErrorCode := GraphResult;
  IF ErrorCode <> GrOK THEN
    BEGIN
      WriteLn;
      WriteLn('ERROR: ',GraphErrorMsg(ErrorCode));
      Halt;
    END;
  MaxX := GetMaxX;
  MaxY := GetMaxY;
  FOR I := 0 TO 9 DO              {draw boxes}
    Rectangle(10*I, 10*I, MaxX-10*I, MaxY-10*I);
  SetTextStyle(DefaultFont, HorizDir, 1);
  OutTextXY(250, MaxY DIV 2, 'Add Some Text and Dump');

  ScrDmp(PrinterType);            { Dump It }
  CloseGraph;
END.
