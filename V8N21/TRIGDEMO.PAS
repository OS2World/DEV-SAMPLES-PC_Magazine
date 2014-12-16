TRIGDEMO.PAS





PROGRAM TrigDemo;
{ This is an example to demonstrate use of the inverse
  trigonometric function ArcSin (inverse sine).
  The program calculates the angle of a right triangle with a
  hypoteneuse "c" and a side "a" opposite the angle.
  The user is prompted for the lengths of the opposide
  side and of the hypoteneuse.  If the input is valid,
  the program then displays the value of the angle in
  degrees.}
USES Trig, Crt;

VAR
  a : Real;              {length of the side opposide the angle in question}
  c : Real;              {length of the hypoteneuse}
  ArcSinError : Boolean; {error return from ArcSin function}
  angle : Real;          {the calculated angle}
  Answer : Char;         { answer to done prompt}
BEGIN
  ClrScr;
  REPEAT
    Write('Input the length of the side opposite ');
    Write('the angle in question> ');
    ReadLn(a);
    Write('Input the length of the hypoteneuse> ');
    ReadLn(c);
    {calculate the angle and convert it to degrees.}
    angle := 360.0*ArcSin(a/c, ArcSinError)/(2.0*Pi);
    IF ArcSinError THEN
      WriteLn('***** ERROR in inverse sine calculation *****')
    ELSE WriteLn('The angle is ', angle:1:11);
    WriteLn;
    Write('Are you done? ');
    Answer := Upcase(ReadKey); WriteLn(Answer);
  UNTIL Answer = 'Y';
END.



