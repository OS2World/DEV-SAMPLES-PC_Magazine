D$ = MID$(DATE$, 4, 2)
M$ = LEFT$(DATE$, 2)
Y$ = RIGHT$(DATE$, 2)
today$ = Y$ + M$ + D$
OPEN "today.bat" FOR OUTPUT AS #1
PRINT #1, "set today="; today$
CLOSE #1
SYSTEM
