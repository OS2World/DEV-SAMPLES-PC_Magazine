/*--------------------------------------------------------------------------
   QUADRANT.C -- OS/2 Program that Runs 4 Threads Using One Thread Function
                 (C) 1988, Ziff-Davis Communications Company
                 PC Magazine * Programmed by Charles Petzold, 11/87
  --------------------------------------------------------------------------*/

#include <doscalls.h>
#include <subcalls.h>

#define min(a,b) ((a) < (b) ? (a) : (b)) 

void far ThreadFunction (void) ;

main ()
     {
     static unsigned char ThreadStack [4][1024] ;
     unsigned int         i, ThreadID [4] ;     struct KeyData       kd ;

     for (i = 0 ; i < 4 ; i++)
          if (DOSCREATETHREAD (ThreadFunction, &ThreadID [i],
                               ThreadStack [i] + 1024))
               {
               puts ("QUADRANT: Could not create thread") ;
               return 1 ;
               }

     KBDCHARIN (&kd, 0, 0) ;

     return 0 ;
     }

#pragma check_stack-

void far ThreadFunction ()
     {
     static struct ModeData md ;
     static int             ThreadNumber = 0, NumRep ;
     unsigned int           MinRow, MaxRow, MinCol, MaxCol ;
     unsigned int           MyThreadNum, Cycle, Rep, Row, Col ;

     DOSENTERCRITSEC () ;

     if (ThreadNumber == 0)
          {
          md.length = sizeof (md) ;
          VIOGETMODE (&md, 0) ;

          NumRep = (min (md.col, md.row) / 2 + 1) / 2 ;
          }

     MyThreadNum = ThreadNumber ;

     ThreadNumber += 1 ;

     DOSEXITCRITSEC () ;

     MinRow = MyThreadNum > 1 ? md.row / 2 : 0 ;
     MaxRow = MinRow + md.row / 2 ;
     MinCol = MyThreadNum % 2 ? md.col / 2 : 0 ;
     MaxCol = MinCol + md.col / 2 ; 

     while (1)
          for (Cycle = 0 ; Cycle < 2 ; Cycle++)
               for (Rep = 0 ; Rep < NumRep ; Rep++)
                    {
                    Row = MinRow + Rep ;

                    for (Col = MinCol+Rep ; Col < MaxCol-Rep-1 ; Col++)
                         Display (Cycle, Row, Col, MyThreadNum) ;
                    for (Row = MinRow+Rep ; Row < MaxRow-Rep-1 ; Row++)
                         Display (Cycle, Row, Col, MyThreadNum) ;

                    for (Col = MaxCol-Rep-1 ; Col > MinCol+Rep ; Col--)
                         Display (Cycle, Row, Col, MyThreadNum)  ;

                    for (Row = MaxRow-Rep-1 ; Row > MinRow+Rep ; Row--)
                         Display (Cycle, Row, Col, MyThreadNum) ;
                    }
     }

Display (Cycle, Row, Col, Num)
     int Cycle, Row, Col, Num ;
     {
     char String [2] ;

     String [0] = (char) (Cycle == 0 ? Num + '0' : ' ') ;
     String [1] = '\x07' ;

     VIOWRTCELLSTR (String, 2, Row, Col, 0) ;

     DOSSLEEP (0L) ;
     }
