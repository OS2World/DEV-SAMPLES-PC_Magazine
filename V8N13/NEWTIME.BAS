 DEF FnNewTime$ (t1$, Op$, t2$)

     hour1 = VAL(t1$)            'parse hour values
     hour2 = VAL(t2$)
    
     min1 = VAL(MID$(t1$, 4))    'parse minute values
     min2 = VAL(MID$(t2$, 4))
    
     sec1 = VAL(RIGHT$(t1$, 2))  'parse second values
     sec2 = VAL(RIGHT$(t2$, 2))
    
     IF Op$ = "+" THEN           'add times
    
        hourval = hour1 + hour2  'add hours
        minval = min1 + min2     'add minutes
        secval = sec1 + sec2     'add seconds
    
        IF secval > 59 THEN      'check to carry a minute
           secval = secval - 60
           minval = minval + 1
        END IF
    
        IF minval > 59 THEN      'check to carry an hour
           minval = minval - 60
           hourval = hourval + 1
        END IF
    
        DO WHILE hourval > 23    'check to see if next day
           hourval = hourval - 24
        LOOP
    
     ELSEIF Op$ = "-" THEN       'subtract times
    
        IF sec2 > sec1 THEN      'look to borrow a minute
           sec1 = sec1 + 60
           min1 = min1 - 1
        END IF
        secval = sec1 - sec2     'subtract seconds
    
        IF min2 > min1 THEN      'look to borrow an hour
           min1 = min1 + 60
           hour1 = hour1 - 1
        END IF
        minval = min1 - min2
    
        IF hour2 > hour1 THEN    'look to borrow a day
           DO UNTIL hour1 > hour2
              hour1 = hour1 + 24
           LOOP
        END IF
        hourval = hour1 - hour2
    
     'wasn't "+" or "-"
     ELSE
        FnNewTime$ = "Illegal Operation"
        EXIT DEF
     END IF
    
     'set the final result
     hour$ = MID$(STR$(hourval), 2)
     minute$ = MID$(STR$(minval), 2)
     sec$ = MID$(STR$(secval), 2)
    
     'pad any empty slots
     WHILE LEN(hour$) < 2
        hour$ = "0" + hour$
     WEND
    
     WHILE LEN(minute$) < 2
        minute$ = "0" + minute$
     WEND
    
     WHILE LEN(sec$) < 2
        sec$ = "0" + sec$
     WEND
    
     FnNewTime$ = hour$ + ":" + minute$ + ":" + sec$
    
 END DEF
    
 INPUT "First time : ", t1$
 INPUT "Second time: ", t2$
 INPUT "Operator (+/-): ", Op$
    
 IF LEN(t1$) <> 8 OR LEN(t2$) <> 8 OR (Op$ <> "+" AND Op$ <> "-") THEN
    PRINT "Invalid format!"
    END
 END IF
    
 PRINT FnNewTime$(t1$, Op$, t2$)

