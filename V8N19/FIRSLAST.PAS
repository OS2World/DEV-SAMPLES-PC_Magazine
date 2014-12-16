FIRSTLAST.PAS



{$R+}
PROGRAM FirstLast;
TYPE
  value = (excellent, good, fair, poor, terrible);
  years = 1953..1989;
  biggy = 100000..200000;
VAR
  valuevar : value;
  yearsvar : years;
  biggyvar : biggy;
  firsone, Lastone : LongInt;

  FUNCTION last:LongInt;
  INLINE(
    $26/$8B/$55/$06/    {MOV	DX,ES:[DI+06]}
    $26/$8B/$45/$04);   {MOV	AX,ES:[DI+04]}

  FUNCTION First:LongInt;
  INLINE(
    $26/$8B/$55/$02/    {MOV	DX,ES:[DI+02]}
    $26/$8B/$45/$00);   {MOV	AX,ES:[DI+00]}

BEGIN
  valuevar := excellent;
  yearsvar := 1980;
  biggyvar := 150000;
  valuevar := valuevar; lastone := last;
  valuevar := valuevar; firsone := first;
  WriteLn('Limits of VALUE type are ',firsone,' to ',lastone);
  yearsvar := yearsvar; lastone := last;
  yearsvar := yearsvar; firsone := first;
  WriteLn('Limits of YEARS type are ',firsone,' to ',lastone);
  biggyvar := biggyvar; lastone := last;
  biggyvar := biggyvar; firsone := first;
  WriteLn('Limits of BIGGY type are ',firsone,' to ',lastone);
END.




