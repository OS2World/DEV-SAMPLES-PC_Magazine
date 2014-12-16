

DEFINT A-Z
CLS
INPUT "Enter screen mode (1/2/9) ", Mode
   SELECT CASE Mode
   CASE 1
      MaxColor = 3
   CASE 2
      MaxColor = 1
   CASE 9
      MaxColor = 15
   CASE ELSE
      END
   END SELECT
 
SCREEN Mode
DEF SEG = &HFFA6               'ROM segment for character shape tables
 
DO
   CLS
   INPUT "Enter something to print "; A$
   IF A$ = "" THEN SCREEN 0: END
 
   X = 13                      'X/Y location to start printing
   Y = 20
   CO = 1                      'initial color
 
   FOR I = 1 TO LEN(A$)        'step through the string
       Addr = 8 * ASC(MID$(A$, I)) + 14 'address character shape table
       FOR J = 0 TO 7                   'print the character
           LINE (X + 7, Y + J)-(X, Y + J), CO, , PEEK(Addr + J) * 128
       NEXT
       X = X + 10                       'advance right ten pixels
       Y = Y + 3                        'go down three pixels
       CO = CO + 1                      'increment the color by one
       IF CO > MaxColor THEN CO = 1     'wrap if at the maximum for
   NEXT                                 'this mode
   WHILE INKEY$ = "": WEND              'give 'em time to see it
LOOP                                    'prompt for another message

