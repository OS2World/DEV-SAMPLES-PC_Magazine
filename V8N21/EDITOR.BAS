'********** EDITOR.BAS

DEFINT A-Z
DECLARE SUB Editor (Text$, LeftCol, RightCol, KeyCode)

COLOR 7, 1                              'Clear the screen to white on blue
CLS

COLOR 0, 7                              'Set inverse video for editing
Text$ = "This is a test"                'Make some sample text
LeftCol = 20                            'Set left column for editing
RightCol = 40                           'Ditto for right column
LOCATE 10                               'Set the line number for editing

DO
                                        'Edit the field
   Editor Text$, LeftCol, RightCol, KeyCode

LOOP UNTIL KeyCode = 13 OR KeyCode = 27 'Do until Enter or Escape is pressed

COLOR 7, 0

SUB Editor (Text$, LeftCol, RightCol, KeyCode)

    '----- Find the cursor's size in Scan Lines
    DEF SEG = 0                                 'Peek at low memory to see
    IF PEEK(&H463) = &HB4 THEN                  'what type of monitor we have
       CsrSize = 12                             'Monochrome uses 13 scan lines
    ELSE                                        '  (numbered 0 to 12)
       CsrSize = 7                              'Color uses 8 (0 to 7)
    END IF

    Edit$ = SPACE$(RightCol - LeftCol + 1)      'Make a temporary string for
    LSET Edit$ = Text$                          '  editing

    TxtPos = POS(0) - LeftCol + 1               'Get the cursor's location to
    IF TxtPos < 1 THEN TxtPos = 1               '  see where to begin editing
    IF TxtPos > LEN(Edit$) THEN TxtPos = LEN(Edit$)

    LOCATE , LeftCol                            'Print the editing string
    PRINT Edit$;

    '----- Main loop for handling key presses
    DO
       LOCATE , LeftCol + TxtPos - 1, 1         'Locate the cursor, turn it on

       DO                                       'Wait for a key press
          Ky$ = INKEY$
       LOOP UNTIL LEN(Ky$)

       IF LEN(Ky$) = 1 THEN                     'Make a key code from Ky$
          KeyCode = ASC(Ky$)                    'Single character key
       ELSE
          KeyCode = -ASC(RIGHT$(Ky$, 1))        'Extended keys are negative
       END IF

       '----- Branch according to the key pressed
       SELECT CASE KeyCode

          '----- Backspace
          CASE 8
             TxtPos = TxtPos - 1                'Back up the text pointer
             LOCATE , LeftCol + TxtPos - 1, 0   'Locate 1 to the left
             IF TxtPos > 0 THEN                 'Still within the field?
                IF Insert THEN                  'Truncate the string
                   MID$(Edit$, TxtPos) = MID$(Edit$, TxtPos + 1) + " "
                ELSE                            'Blank the letter
                   MID$(Edit$, TxtPos) = " "
                END IF
                PRINT MID$(Edit$, TxtPos);      'Print the new part of text
             END IF

          '----- Enter or Escape
          CASE 13, 27
             EXIT DO                            'Bail out

          '----- Letter keys
          CASE 32 TO 254
             LOCATE , , 0                       'Turn the cursor off
             IF Insert THEN                     'Expand the text string
                MID$(Edit$, TxtPos) = Ky$ + MID$(Edit$, TxtPos)
                PRINT MID$(Edit$, TxtPos);      'Print the expanded part
             ELSE
                MID$(Edit$, TxtPos) = Ky$       'Put the new letter in string
                PRINT Ky$;                      'Print the letter
             END IF
             TxtPos = TxtPos + 1                'Increment the text pointer

          '----- Left arrow
          CASE -75
             TxtPos = TxtPos - 1                'Decrement the text pointer

          '----- Right arrow
          CASE -77
             TxtPos = TxtPos + 1                'Increment the text pointer

          '----- Home
          CASE -71
             TxtPos = 1                         'Move text pointer to 1

          '----- End
          CASE -79
             FOR N = LEN(Edit$) TO 1 STEP -1    'Look backwards for non-blank
                IF MID$(Edit$, N, 1) <> " " THEN EXIT FOR
             NEXT
             TxtPos = N + 1                     'Set pointer to last char +1
             IF TxtPos > LEN(Edit$) THEN TxtPos = LEN(Edit$)

          '----- Insert key
          CASE -82
             Insert = NOT Insert                'Toggle the Insert state
             IF Insert THEN                     'Adjust the cursor size
                LOCATE , , , CsrSize \ 2, CsrSize
             ELSE
                LOCATE , , , CsrSize - 1, CsrSize
             END IF

          '----- Delete
          CASE -83                              'Truncate the text
             MID$(Edit$, TxtPos) = MID$(Edit$, TxtPos + 1) + " "
             LOCATE , , 0                       'Print the truncated part
             PRINT MID$(Edit$, TxtPos);

          CASE ELSE                             'All other keys,
             EXIT DO                            '  bail out
       END SELECT

    LOOP UNTIL TxtPos < 1 OR TxtPos > LEN(Edit$) 'If cursor is out of field,
                                                 '  quit editing

    Text$ = RTRIM$(Edit$)                       'Trim the right side of text

END SUB


