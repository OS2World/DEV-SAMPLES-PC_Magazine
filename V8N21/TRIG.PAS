TRIG.PAS



UNIT Trig;
  (**********************)
  (**)  INTERFACE     (**)
  (**********************)

FUNCTION ArcCos(X : Real; VAR Error : Boolean) : Real;
FUNCTION ArcSin(X : Real; VAR Error : Boolean) : Real;

  (**********************)
  (**) IMPLEMENTATION (**)
  (**********************)

  FUNCTION ArcCos(X : Real; VAR Error : Boolean) : Real;
  { This function calculates the inverse cosine
    (or "arc cosine") of the argument X.  The
    arc cosine is the angle whose cosine is the
    argument.}
  VAR temp : Real;
  BEGIN
    IF Abs(X) > 1.0 THEN
      BEGIN
        Error := True;
        ArcCos := 0.0;
      END
    ELSE
      BEGIN
        Error := False;
        IF X = 0.0 THEN ArcCos := Pi/2.0
        ELSE
          IF X = -1.0 THEN ArcCos := Pi
          ELSE
            BEGIN
              temp := ArcTan(Sqrt(1.0-Sqr(X))/X);
              IF temp < 0 THEN ArcCos := temp+Pi
              ELSE ArcCos := temp;
            END;
      END;
  END;                            {function ArcCos}


  FUNCTION ArcSin(X : Real; VAR Error : Boolean) : Real;
  { This function calculates the inverse sine
    (or "arc sine") of the argument X.  The
    arc sine is the angle whose sine is the
    argument.}
  BEGIN
    IF Abs(X) > 1.0 THEN
      BEGIN
        Error := True;
        ArcSin := 0.0;
      END
    ELSE
      BEGIN
        Error := False;
        IF X = -1.0 THEN ArcSin := -Pi/2.0
        ELSE
          IF Abs(X) = 1.0 THEN ArcSin := Pi/2.0
          ELSE ArcSin := ArcTan(X/Sqrt(1.0-Sqr(X)));
      END;
  END;                            {function ArcSin}

END.                              {unit Trig}


