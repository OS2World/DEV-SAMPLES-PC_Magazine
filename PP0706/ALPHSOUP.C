/*---------------------------------------------------------------------------
   ALPHSOUP.C -- OS/2 Program that Runs 26 Threads Using One Thread Function
                 (C) 1988, Ziff-Davis Communications Company
                 PC Magazine * Programmed by Charles Petzold, 11/87
  ---------------------------------------------------------------------------*/

#include <doscalls.h>
#include <subcalls.h>

void far ThreadFunction (void) ;

main ()
     {
     static unsigned char ThreadStack [26][1024] ;
     unsigned int         i, ThreadID [26] ;
     struct KeyData       kd ;

     for (i = 0 ; i < 26 ; i++)
          if (DOSCREATETHREAD (ThreadFunction, &ThreadID [i],
                               ThreadStack [i] + 1024))               {
               puts ("RANDQUAD: Could not create thread") ;
               return 1 ;
               }

     KBDCHARIN (&kd, 0, 0) ;

     return 0 ;
     }

#pragma check_stack-

void far ThreadFunction ()
     {
     static struct ModeData md ;
     static char            ClearCell [2] = " \x07" ;
     static int             ThreadNumber = 0 ;
     unsigned int           MinRow, MaxRow, MinCol, MaxCol ;
     int                    MyThreadNum, Row, Col ;

     DOSENTERCRITSEC () ;

     if (ThreadNumber == 0)
          {
          VIOSCROLLUP (0, 0, 0xFFFF, 0xFFFF, 0xFFFF, ClearCell, 0L) ;

          md.length = sizeof (md) ;
          VIOGETMODE (&md, 0) ;
          }

     MyThreadNum = ThreadNumber ;

     ThreadNumber += 1 ;

     DOSEXITCRITSEC () ;

     Row = SafeRand () % md.row ;
     Col = SafeRand () % md.col ;

     while (1)
          {
          Row = (Row + SafeRand () % 3 - 1 + md.row) % md.row ;
          Col = (Col + SafeRand () % 3 - 1 + md.col) % md.col ;

          Display (0, Row, Col, MyThreadNum) ;

          DOSSLEEP (0L) ;

          Display (1, Row, Col, MyThreadNum) ;
          }
     }

SafeRand ()
     {     static long Semaphore = 0 ;
     int         ReturnValue ;

     DOSSEMREQUEST ((unsigned long) (long far *) &Semaphore, -1L) ;

     ReturnValue = rand () ;

     DOSSEMCLEAR ((unsigned long) (long far *) &Semaphore) ;

     return ReturnValue ;
     }

Display (Cycle, Row, Col, Num)
     int Cycle, Row, Col, Num ;
     {
     char String [2] ;

     String [0] = (char) (Cycle == 0 ? Num + 'A' : ' ') ;
     String [1] = '\x07' ;

     if (Num == 0)
          String [1] = '\x1B' ;

     VIOWRTCELLSTR (String, 2, Row, Col, 0) ;
     }
