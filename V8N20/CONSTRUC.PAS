CONSTRUC.PAS



PROGRAM construc;

TYPE
  Parent = OBJECT
    CONSTRUCTOR Init;
    PROCEDURE InitializeParent;
    PROCEDURE Message; Virtual;
  END;

  Child = OBJECT(Parent)
    CONSTRUCTOR Init;
    PROCEDURE Message; Virtual;
  END;

CONSTRUCTOR Parent.Init; 
BEGIN END;

PROCEDURE Parent.InitializeParent;
BEGIN
  Init; {- Calls Parent.Init -}
END;

PROCEDURE Parent.Message; 
BEGIN WriteLn('Parent Message'); END;

CONSTRUCTOR Child.Init; 
BEGIN InitializeParent; END;

PROCEDURE Child.Message; 
BEGIN Writeln('Child Message'); END;

VAR
  ChildInst: Child;

BEGIN
  ChildInst.Init;
  ChildInst.Message;
END.
