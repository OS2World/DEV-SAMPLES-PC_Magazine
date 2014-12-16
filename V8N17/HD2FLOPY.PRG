

*** HD2FLOPY.PRG
CLEAR
odbf=SPACE(30)
fdrive="A"
ndbf=SPACE(8)
@ 1,0 SAY "Backup which database?" GET odbf
@ 3,0 SAY "To which floppy drive?" GET fdrive
@ 5,0 SAY "Enter Backup filename:" GET ndbf
READ
odbf=TRIM(odbf)
ndbf=TRIM(ndbf)
fmess="Insert a blank, formatted disk in ";
     +"Drive &fdrive, and press a key..."
IF READKEY()=12
  RETURN
ENDIF
IF ndbf<=" "
  ? [No TARGET file]+CHR(7)
  RETURN
ENDIF
IF FILE(odbf) .OR. FILE(odbf+".DBF")
  USE &odbf
ELSE
  ? [No SOURCE file: "&odbf"]+CHR(7)
  RETURN
ENDI

fdriven=ASC(UPPE(fdrive))-64
DO WHILE DISKSPACE(fdriven)<1
  WAIT fmess
ENDDO

* Calc header size
STOR 0 TO fldno,header
DO WHILE ""<FIELD(fldno+1)
  fldno=fldno+1
ENDDO
header=32*fldno+35

* Calc # of floppies needed
floprecs=INT((DISKSPACE(fdriven)-header)/RECSIZE())
flopneed=INT((RECCOUNT())/floprecs)+1
makeflop="F"
DO WHILE makeflop$"Ff"
  ? STR(flopneed)+" Disks required.  "
  ?? "Press <ENTER> to proceed."
  WAIT "To format additional disks, insert ";
      +"floppy and press <F>" TO makeflop
  IF makeflop$"Ff"
    RUN FORMAT &fdrive:
  ENDIF
ENDDO

sofar="0"
DO WHILE .NOT. EOF()
  sofar=LTRIM(STR(VAL(sofar)+1))
  COPY NEXT floprecs TO &fdrive:&ndbf..&sofar
  IF .NOT. EOF()
    SKIP
    DO WHILE DISKSPACE(fdriven)<RECSIZE()+header
      WAIT fmess
    ENDDO
  ENDIF
ENDDO

