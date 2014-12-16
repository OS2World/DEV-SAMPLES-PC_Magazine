ENUMLAST.PAS




PROGRAM Enumerated;
(* Insert more items in the enumerated type "Fruit". The
   program will still correctly display the ordinal values
   of all the items.*)
TYPE
  Fruit = (Apple, Orange, Grape, Pineapple);
  FruitRay = array[Fruit] of byte;

CONST
  FirstFruit = Fruit(0);
  LastFruit = Fruit(sizeof(FruitRay)-1);

PROCEDURE ShowAllFruits;
VAR
  F : Fruit;
BEGIN
  WriteLn('Here are the ordinal values of all the fruits:');
    For F := FirstFruit To LastFruit DO
      Write( Ord(F):3 );
  WriteLn;
END;

BEGIN
  ShowAllFruits;
END.



