ONEDRIVE.PAS



PROGRAM FloppyDemo;

USES Crt;                         {Required for Turbo 4.0}

VAR fileptr : Text;


  FUNCTION NumberOfDisketteDrives : Byte;
    { Returns the number of DISKETTE drives available }
  VAR
    equip : Integer ABSOLUTE $0000 : $0410;
  BEGIN
    IF (equip AND $0001) = 1 THEN
      NumberOfDisketteDrives := ((equip SHR 6) AND $0003)+1
    ELSE
      NumberOfDisketteDrives := 0;
  END;


  FUNCTION FirstDiskDrive : Char;
    { Returns the letter of first diskette drive (A or B) }
  BEGIN
    IF NumberOfDisketteDrives > 1 THEN FirstDiskDrive := 'A'
    ELSE
      CASE Mem[$0000 : $0504] OF
        00 : FirstDiskDrive := 'A';
        01 : FirstDiskDrive := 'B';
      END;
  END;


  PROCEDURE MakeFirstDrive(drive : Char);
    { Makes the first diskette drive A or B }
  BEGIN
    IF NumberOfDisketteDrives = 1 THEN
      CASE Upcase(drive) OF
        'A' : Mem[$0000 : $0504] := 00;
        'B' : Mem[$0000 : $0504] := 01;
      END;
  END;


BEGIN
  ClrScr;
  IF NumberOfDisketteDrives > 1 THEN
    WriteLn('You have more than one floppy drive...terminating')
  ELSE
    BEGIN
      WriteLn('Put a scratch disk into drive A.');
      WriteLn('Reassigning drive A to B.');

      IF FirstDiskDrive = 'A' THEN MakeFirstDrive('B');

      Write('Press a key to write "B:JUNK.DAT"...');
      IF ReadKey = #0 THEN; {Dummy ReadKey call}
      WriteLn;

      Assign(fileptr, 'B:JUNK.DAT');
      Rewrite(fileptr);
      WriteLn(fileptr, 'Test File');
      Close(fileptr);

      WriteLn('Done...returning drive to A.');
      MakeFirstDrive('A');
    END;                          {else}
END.



