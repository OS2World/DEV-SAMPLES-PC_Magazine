SUB SUBST (old$, new$, text$, start)
    gap = LEN(old$)
    n = LEN(text$)
    IF start <= n THEN
       x = INSTR(start, text$, old$)
       DO WHILE x > 0
          text$ = LEFT$(text$, x - 1) + new$ +_
            RIGHT$(text$, n + 1 -(x + gap))
          n = LEN(text$)
          x = INSTR(x, text$, old$)
       LOOP
    END IF
END SUB
