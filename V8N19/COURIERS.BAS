100 REM - BASIC PROGRAM TO CREATE COURIERS.COM
110 CLS:PRINT "Creating COURIERS.COM": OPEN "COURIERS.COM" AS #1 LEN = 1
120 FIELD #1, 1 AS A$: CHECKSUM#=0
130 FOR I = 1 TO    80
140  LINESUM#=0: LOCATE 2,3: PRINT "Countdown: "    80 - I ;
150  FOR J = 1 TO  16: READ BYTE$: BYTE = VAL("&H" + BYTE$)
160   CHECKSUM# = CHECKSUM# + BYTE: LINESUM# = LINESUM# + BYTE
170   IF (BYTE < 256) THEN LSET A$=CHR$(BYTE): PUT #1
180  NEXT J
190  READ LINETOT$: LINECHECK# = VAL("&H"+LINETOT$)
200  IF LINECHECK# = LINESUM# THEN GOTO 220
210  LOCATE 4,2: PRINT "Error in line #"  ;  260 +  10 * I: GOTO 260
220 NEXT I
230 CLOSE: READ FILETOT$ : FILECHECK# = VAL(FILETOT$)
240 IF CHECKSUM# <> FILECHECK# THEN GOTO 260
250 PRINT: PRINT "COURIERS.COM created successfully": SYSTEM
260 PRINT: PRINT "COURIERS.COM is not valid!": END
270 DATA E9, 99,  4, 43, 6F, 75, 72, 69, 65, 72, 73, 20, 31, 2E, 30, 20,   5A1
280 DATA 43, 6F, 70, 79, 52, 69, 67, 68, 74, 20, 28, 43, 29, 20, 31, 39,   4D7
290 DATA 38, 39, 20, 5A, 69, 66, 66, 20, 44, 61, 76, 69, 73, 20, 43, 6F,   509
300 DATA 6D, 6D, 75, 6E, 69, 63, 61, 74, 69, 6F, 6E, 73, 20, 43, 6F, 2E,   617
310 DATA  D,  A, 50, 43, 20, 4D, 61, 67, 61, 7A, 69, 6E, 65, 20, 2A, 20,   460
320 DATA 50, 65, 74, 65, 20, 4D, 61, 63, 6C, 65, 61, 6E, 2C, 20, 41, 75,   561
330 DATA 67, 75, 73, 74, 20, 31, 39, 38, 39, 24, 10,  2, F8,  3, 30,  0,   41F
340 DATA 10,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    10
350 DATA  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 16,  2, F8,  2, 2C,   13E
360 DATA  0,  8,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,     8
370 DATA  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 1C,  2, E8,  3,   109
380 DATA 30,  0, 10,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    40
390 DATA  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 22,  2, E8,   10C
400 DATA  2, 2C,  0,  8,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,    36
410 DATA  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 7F,  3,    82
420 DATA 95,  3, E0,  3, 10,  4, 44,  4, 5B,  4, 86,  4, A0,  4, A6,  4,   40E
430 DATA BE,  4, D7,  4, D8,  4, DE,  4, 1A,  3, E9,  2, 5F,  2, 1F,  3,   4E6
440 DATA 53, BB, 6A,  1, EB, 10, 53, BB, 8B,  1, EB,  A, 53, BB, AC,  1,   6BE
450 DATA EB,  4, 53, BB, CD,  1, 50, 52, 56, 1E,  6,  E, 1F, 8B, 57,  2,   4F8
460 DATA 80, C2,  2, EC, 52, 25,  6,  0, 8B, F0, FF, 94,  8,  2, FB, 5A,   71A
470 DATA 80, C2,  2, B0,  3, EE, B0,  B, EB,  0, EE, FA, 80, C2, FE, EC,   99F
480 DATA A8,  1, 74, E0, B0, 20, E6, 20,  7, 1F, 5E, 5A, 58, 5B, CF, 80,   6B3
490 DATA C2,  3, EC, 8A, E0, 80, C2, FB, EC, F7, 47,  7,  2,  0, 74, 22,   821
500 DATA 3C, 13, 75,  5, 80, 4F,  9,  2, C3, 3C, 11, 75, 15, F6, 47,  9,   483
510 DATA  2, 74, 58, 80, 67,  9, FD, 80, C2,  5, EC, A8, 20, 74, 4C, E9,   75F
520 DATA E9,  2, C4, 77, 11, 26, 89,  4, 46, 46, FF, 47,  B, 3B, 77, 19,   592
530 DATA 74, 3A, 89, 77, 11, 3B, 77, 15, 74, 37, F7, 47,  7,  1,  0, 74,   4EB
540 DATA 2A, F7, C6,  E,  0, 75, 24, F6, 47,  9,  1, 75, 1E, 8B, 47,  B,   545
550 DATA 3B, 47,  F, 72, 16, 80, 4F,  9,  1, 80, C2,  5, EC, A8, 20, B0,   59D
560 DATA 13, 74,  5, 80, C2, FB, EE, C3, 88, 47,  A, C3, 8B, 77, 17, EB,   81A
570 DATA C1, 33, C0, 89, 47,  B, 48, EB, A9, 80, C2, FE, 33, C0, 86, 47,   86B
580 DATA  A, 84, C0, 75, 1B, F6, 47,  9,  2, 75, 19,  6, C4, 77, 1B, 85,   595
590 DATA F6, 74, 10, 26, 8A,  4, 46, 3B, 77, 1F, 74,  A, 89, 77, 1B,  7,   4E5
600 DATA EE, F8, C3,  7, F9, C3, 33, F6, EB, F2, 80, C2,  4, EC, C3, 80,   AE7
610 DATA C2,  3, EC, C3, 9C,  A, E4, 79,  5, 80, FC, 8E, 76,  6, 9D, EA,   889
620 DATA  0,  0,  0,  0, 9D, FB, 53, 51, 52, 55, 56, 57, 1E,  6, 1E,  7,   3D9
630 DATA  E, 1F, FC, E8,  B,  0,  7, 1F, 5F, 5E, 5D, 5A, 59, 5B, CA,  2,   536
640 DATA  0, 80, EC, 81, 7D,  3, B4, E8, C3, FE, C8, 3C,  4, 72,  3, B4,   7FB
650 DATA FF, C3, 50, 8B, FB, BB, 6A,  1, B4, 21, F6, E4,  3, D8, 8B, 57,   92A
660 DATA  2, 58, 32, C0, 86, E0, BE, EE,  1,  3, F0,  3, F0, FF, 24, 42,   7AA
670 DATA EC, B4,  2, 3C, ED, 74,  D, FE, CC, 8A, 67,  6, E4, 21, 22, C4,   7F8
680 DATA 74,  2, FE, CC, C3, 89, 4F,  7, 80, C2,  3, 33, C0, EE, 88, 47,   7D7
690 DATA  9, 88, 47,  A, 80, C2, FE, EE, 80, C2,  3, B0,  B, EE, 80, C2,   840
700 DATA FC, 8B, C7, E8, A1,  1, 33, C0, 8E, C0, 8C, C8, 8B, 7F,  4, FA,   975
710 DATA 26, 89, 45,  2, 8B,  7, 26, 89,  5, FB, 8A, 67,  6, F6, D4, FA,   6F2
720 DATA E4, 21, 22, C4, E6, 21, FB, 8B, C1, 80, C2,  3, B0,  3, EE, C3,   8E2
730 DATA 8C, C0, 89, 47, 13, 89, 7F, 17, 89, 7F, 15, 83, E1, FE,  3, F9,   7C9
740 DATA 89, 7F, 19, E8, 4E,  0, D1, E9, 8B, C1, D1, E8, 89, 47,  D, D1,   8C4
750 DATA E8, 2B, C8, 89, 4F,  F, EC, EC, 42, EC,  C,  1, EB,  0, EE, C3,   871
760 DATA 8B, 77, 15, 3B, 77, 11, 74, 2B, FA, FF, 4F,  B, F6, 47,  9,  1,   613
770 DATA 74,  B, 8B, 47,  B, 3B, 47,  D, 77,  3, E8, 12,  1, FB, 8B, 47,   52D
780 DATA 13, 1E, 8E, D8, AD, 1F, 3B, 77, 19, 75,  3, 8B, 77, 17, 89, 77,   5BF
790 DATA 15,  B, DB, C3, FA, 8B, 77, 15, 89, 77, 11, 33, C0, 89, 47,  B,   6AE
800 DATA F6, 47,  9,  1, 74,  3, E8, E6,  0, FB, C3, FE, C2, FA, EC, 24,   914
810 DATA FD, EB,  0, EE, FB, 80, C2,  4, EC, A8, 40, 74, FB, FA, 89, 7F,   A5C
820 DATA 1B,  3, F9, 89, 7F, 1F, 8C, C0, 89, 47, 1D, F6, 47,  9,  2, 75,   634
830 DATA  3, E8, F7,  0, FB, C3, 8B, 47, 1B, 85, C0, 74,  6, 2B, 47, 1F,   6DD
840 DATA F7, D8, C3, 83, C2,  5, EC, 24, 20, 75,  2, 40, C3, 33, C0, C3,   83C
850 DATA 33, C0, 89, 47, 1B, C3, 80, C2,  5, EC, A8, 20, 74, FB, 80, C2,   84D
860 DATA FB, 8A, C1, EE, 33, C9, 86, 4F,  A, 84, C9, 75, E9, C3, 80, C2,   9BF
870 DATA  3, FA, EC,  C, 40, EB,  0, EE, FB, B1,  7, E8, 2E,  0, FA, EC,   8BD
880 DATA 34, 40, EB,  0, EE, FB, C3, C3, 8B, C7, E8, 7A,  0, C3, 8A, 67,   936
890 DATA  6, FA, E4, 21,  A, C4, E6, 21, FB, 80, C2,  3, 33, C0, EE, 80,   87B
900 DATA C2, FE, EB,  0, EE, 80, C2,  3, EB,  0, EE, C3, 1E, 33, C0, 8E,   919
910 DATA D8, 32, ED, 3B,  6, 6C,  4, 74, FA, A1, 6C,  4, E2, F5, 1F, C3,   7E0
920 DATA  B, C0, 75,  2, 40, C3, 53, 3D, 58,  2, 72, 12, 52, 33, D2, BB,   5C5
930 DATA 64,  0, F7, F3, 8B, D8, B8, 80,  4, F7, F3, 5A, 5B, C3, B3,  A,   90C
940 DATA F6, F3, 8A, D8, B8, 78,  0, F6, F3, B3, 60, F6, E3, 5B, C3, 80,   AEE
950 DATA 67,  9, FE, 80, C2,  5, EC, A8, 20, B0, 11, 74,  6, 80, C2, FB,   7E1
960 DATA EE, 33, C0, 88, 47,  A, C3, 52, E8, B5, FF, 50, 80, C2,  3, EC,   8EC
970 DATA  C, 80, EB,  0, EE, 58, 80, C2, FD, EE, 42, 8A, C4, EE, 80, C2,   9AA
980 DATA  2, EB,  0, EC, 24, 7F, EB,  0, EE, 5A, C3, 80, C2, FC, EC, 24,   8C0
990 DATA FD, EB,  0, EE, 42, E8, 61, FD, 72, 11, 80, C2,  1, EC,  C,  2,   81E
1000 DATA EB,  0, EE, 80, C2,  4, EC, 24, 20, 75, E0, C3, B4, 80, CD, 14,   87C
1010 DATA 80, FC, E8, 75,  C, 8D, 16, E4,  5, B4,  9, CD, 21, 33, C0, CD,   7DC
1020 DATA 21, A1, 2C,  0, 8E, C0, B4, 49, CD, 21, 8D, 16,  3,  1, B4,  9,   58B
1030 DATA CD, 21, B8, 14, 35, CD, 21, 89, 1E, 30,  3, 8C,  6, 32,  3, B8,   536
1040 DATA 14, 25, 8D, 16, 24,  3, CD, 21, BA, AB,  5, B1,  4, D3, EA, B8,   685
1050 DATA  0, 31, CD, 21, 43, 6F, 75, 72, 69, 65, 72, 73, 20, 69, 73, 20,   587
1060 DATA 61, 6C, 72, 65, 61, 64, 79, 20, 6C, 6F, 61, 64, 65, 64, 24,  0,   58F
1070 DATA 133019
