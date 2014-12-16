
SETJUMP.PAS






{*        Copyright (c) TurboPower Software 1987.        *}
TYPE
  JumpRecord =
    RECORD
      SpReg, BpReg : Word;
      JmpPt : Pointer;
    END;

  PROCEDURE SetJump(VAR JumpDest : JumpRecord);
    {-Save current SP, BP, and a jump destination}
  INLINE(
     $5F/               {pop di           ;di = Ofs(JmpDest)}
     $07/               {pop es           ;es = Seg(JmpDest)}
     $26/$89/$25/       {mov es:[di],sp   ;save sp}
     $26/$89/$6D/$02/   {mov es:[di+2],bp ;save bp}
     $E8/$00/$00/       {call null        ;push IP onto stack}
     {null:}
     $58/               {pop ax           ;pop into ax}
     $05/$0C/$00/       {add ax,12        ;point to "next:"}
     $26/$89/$45/$04/   {mov es:[di+4],ax ;save jump offset}
     $26/$8C/$4D/$06);  {mov es:[di+6],cs ;save jump segment}
  {next:}

  PROCEDURE LongJump(VAR JumpDest : JumpRecord);
    {-Restore SP, BP, and jump to JumpDest.JmpPt}
  INLINE(
     $5F/               {pop di            ;di = Ofs(JumpDest)}
     $07/               {pop es            ;es = Seg(JumpDest)}
     $26/$8B/$25/       {mov sp,es:[di]    ;restore sp}
     $26/$8B/$6D/$02/   {mov bp,es:[di+2]  ;restore bp}
     $26/$FF/$6D/$04);  {jmp far es:[di+4] ;jump far to JumpDest.JmpPt}



