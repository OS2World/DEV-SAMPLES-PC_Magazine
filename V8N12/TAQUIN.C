/*---------------------------------------------------------
   TAQUIN.C -- Jeu de Taquin for OS/2 Presentation Manager
               (c) 1989, Ziff Communications Co.
               PC Magazine * Charles Petzold, January 1989
  ---------------------------------------------------------*/

#define INCL_WIN              // include 'Win' functions in OS/2 headers
#define INCL_GPI              // include 'Gpi' functions in OS/2 headers
#include <os2.h>
#include <stdlib.h>
#include "taquin.h"

#define NUMROWS        4      // greater than or equal to 2
#define NUMCOLS        4      // greater than or equal to 3
#define SCRAMBLEREP  100      // make larger if using more than 16 square
#define SQUARESIZE    67      // in 1/100th inch

MRESULT EXPENTRY ClientWndProc (HWND, USHORT, MPARAM, MPARAM) ;
MRESULT EXPENTRY AboutDlgProc  (HWND, USHORT, MPARAM, MPARAM) ;

int main (void)
     {
     static CHAR  szClientClass[] = "Taquin" ;
     static ULONG flFrameFlags = FCF_SYSMENU  | FCF_TITLEBAR  |
                                 FCF_BORDER   | FCF_MINBUTTON |
                                 FCF_MENU     | FCF_ICON      |
                                 FCF_TASKLIST ;
     HAB          hab ;
     HMQ          hmq ;
     HWND         hwndFrame, hwndClient ;
     QMSG         qmsg ;
                              // Initialize and create standard window

     hab = WinInitialize (0) ;
     hmq = WinCreateMsgQueue (hab, 0) ;
     WinRegisterClass (hab, szClientClass, ClientWndProc, 0L, 0) ;
     hwndFrame = WinCreateStdWindow (HWND_DESKTOP, WS_VISIBLE,
                                     &flFrameFlags, szClientClass, NULL,
                                     0L, NULL, ID_RESOURCE, &hwndClient) ;

                              // Get messages from queue and dispatch them

     while (WinGetMsg (hab, &qmsg, NULL, 0, 0))
          WinDispatchMsg (hab, &qmsg) ;

                              // Clean up and terminate

     WinDestroyWindow (hwndFrame) ;
     WinDestroyMsgQueue (hmq) ;
     WinTerminate (hab) ;
     return 0 ;
     }

MRESULT EXPENTRY ClientWndProc (HWND hwnd, USHORT msg, MPARAM mp1, MPARAM mp2)
     {
     static SHORT asPuzzle[NUMROWS][NUMCOLS],
                  sBlankRow, sBlankCol, cxSquare, cySquare ;
     CHAR         szNum[5] ;
     HPS          hps ;
     HWND         hwndFrame ;
     POINTL       ptl ;
     RECTL        rcl, rclInvalid, rclIntersect ;
     SHORT        sRow, sCol, sMouseRow, sMouseCol, i ;
     SIZEL        sizl ;

     switch (msg)
          {
          case WM_CREATE:
                              // Calculate square size in pixels

               hps = WinGetPS (hwnd) ;
               sizl.cx = sizl.cy = 0 ;
               GpiSetPS (hps, &sizl, PU_LOENGLISH) ;
               ptl.x = SQUARESIZE ;
               ptl.y = SQUARESIZE ;
               GpiConvert (hps, CVTC_PAGE, CVTC_DEVICE, 1L, &ptl) ;
               WinReleasePS (hps) ;

               cxSquare = (SHORT) ptl.x ;
               cySquare = (SHORT) ptl.y ;

                              // Calculate client window size and position

               rcl.xLeft   = (WinQuerySysValue (HWND_DESKTOP, SV_CXSCREEN) -
                                           NUMCOLS * cxSquare) / 2 ;
               rcl.yBottom = (WinQuerySysValue (HWND_DESKTOP, SV_CYSCREEN) -
                                           NUMROWS * cySquare) / 2 ;
               rcl.xRight  = rcl.xLeft   + NUMCOLS * cxSquare ;
               rcl.yTop    = rcl.yBottom + NUMROWS * cySquare ;

                              // Set frame window position and size

               hwndFrame = WinQueryWindow (hwnd, QW_PARENT, FALSE) ;
               WinCalcFrameRect (hwndFrame, &rcl, FALSE) ;
               WinSetWindowPos  (hwndFrame, NULL,
                                 (SHORT) rcl.xLeft, (SHORT) rcl.yBottom,
                                 (SHORT) (rcl.xRight - rcl.xLeft),
                                 (SHORT) (rcl.yTop - rcl.yBottom),
                                 SWP_MOVE | SWP_SIZE | SWP_ACTIVATE) ;

                              // Initialize the asPuzzle array

               WinSendMsg (hwnd, WM_COMMAND, MPFROMSHORT (IDM_NORMAL), NULL) ;
               return 0 ;

          case WM_PAINT:
               hps = WinBeginPaint (hwnd, NULL, &rclInvalid) ;

                              // Draw the squares

               for (sRow = NUMROWS - 1 ; sRow >= 0 ; sRow--)
                    for (sCol = 0 ; sCol < NUMCOLS ; sCol++)
                         {
                         rcl.xLeft   = cxSquare * sCol ;
                         rcl.yBottom = cySquare * sRow ;
                         rcl.xRight  = rcl.xLeft   + cxSquare ;
                         rcl.yTop    = rcl.yBottom + cySquare ;

                         if (!WinIntersectRect (NULL, &rclIntersect,
                                                &rcl, &rclInvalid))
                              continue ;

                         if (sRow == sBlankRow && sCol == sBlankCol)
                              WinFillRect (hps, &rcl, CLR_BLACK) ;
                         else
                              {
                              WinDrawBorder (hps, &rcl, 5, 5,
                                             CLR_PALEGRAY, CLR_DARKGRAY,
                                             DB_STANDARD | DB_INTERIOR) ;
                              WinDrawBorder (hps, &rcl, 2, 2,
                                             CLR_BLACK, 0L, DB_STANDARD) ;
                              WinDrawText (hps, -1,
                                      itoa (asPuzzle[sRow][sCol], szNum, 10),
                                           &rcl, CLR_WHITE, CLR_DARKGRAY,
                                           DT_CENTER | DT_VCENTER) ;
                              }
                         }
               WinEndPaint (hps) ;
               return 0 ;

          case WM_BUTTON1DOWN:
               sMouseCol = MOUSEMSG(&msg)->x / cxSquare ;
               sMouseRow = MOUSEMSG(&msg)->y / cySquare ;

                              // Check if mouse was in valid area

               if ( sMouseRow < 0          || sMouseCol < 0           ||
                    sMouseRow >= NUMROWS   || sMouseCol >= NUMCOLS    ||
                   (sMouseRow != sBlankRow && sMouseCol != sBlankCol) ||
                   (sMouseRow == sBlankRow && sMouseCol == sBlankCol))
                         break ;

                              // Move a row right or left

               if (sMouseRow == sBlankRow)
                    {
                    if (sMouseCol < sBlankCol)
                         for (sCol = sBlankCol ; sCol > sMouseCol ; sCol--)
                              asPuzzle[sBlankRow][sCol] =
                                   asPuzzle[sBlankRow][sCol - 1] ;
                    else
                         for (sCol = sBlankCol ; sCol < sMouseCol ; sCol++)
                              asPuzzle[sBlankRow][sCol] =
                                   asPuzzle[sBlankRow][sCol + 1] ;
                    }
                              // Move a column up or down
               else
                    {
                    if (sMouseRow < sBlankRow)
                         for (sRow = sBlankRow ; sRow > sMouseRow ; sRow--)
                              asPuzzle[sRow][sBlankCol] =
                                   asPuzzle[sRow - 1][sBlankCol] ;
                    else
                         for (sRow = sBlankRow ; sRow < sMouseRow ; sRow++)
                              asPuzzle[sRow][sBlankCol] =
                                   asPuzzle[sRow + 1][sBlankCol] ;
                    }
                              // Calculate invalid rectangle

               rcl.xLeft   = cxSquare *  min (sMouseCol, sBlankCol) ;
               rcl.yBottom = cySquare *  min (sMouseRow, sBlankRow) ;
               rcl.xRight  = cxSquare * (max (sMouseCol, sBlankCol) + 1) ;
               rcl.yTop    = cySquare * (max (sMouseRow, sBlankRow) + 1) ;

                              // Set new array and blank values

               sBlankRow = sMouseRow ;
               sBlankCol = sMouseCol ;
               asPuzzle[sBlankRow][sBlankCol] = 0 ;

                              // Invalidate rectangle

               WinInvalidateRect (hwnd, &rcl, FALSE) ;
               break ;

          case WM_CHAR:
               if (!(CHARMSG(&msg)->fs & KC_VIRTUALKEY) ||
                     CHARMSG(&msg)->fs & KC_KEYUP)
                         return 0 ;

                              // Mimic a WM_BUTTON1DOWN message

               sMouseCol = sBlankCol ;
               sMouseRow = sBlankRow ;

               switch (CHARMSG(&msg)->vkey)
                    {
                    case VK_LEFT:   sMouseCol++ ;  break ;
                    case VK_RIGHT:  sMouseCol-- ;  break ;
                    case VK_UP:     sMouseRow-- ;  break ;
                    case VK_DOWN:   sMouseRow++ ;  break ;
                    default:        return 0 ;
                    }
               WinSendMsg (hwnd, WM_BUTTON1DOWN,
                           MPFROM2SHORT (sMouseCol * cxSquare,
                                         sMouseRow * cySquare), NULL) ;
               return 0 ;

          case WM_COMMAND:
               switch (COMMANDMSG(&msg)->cmd)
                    {
                              // Initialize asPuzzle array

                    case IDM_NORMAL:
                    case IDM_INVERT:
                         for (sRow = 0 ; sRow < NUMROWS ; sRow++)
                              for (sCol = 0 ; sCol < NUMCOLS ; sCol++)
                                   asPuzzle[sRow][sCol] = sCol + 1 +
                                        NUMCOLS * (NUMROWS - sRow - 1) ;

                         if (COMMANDMSG(&msg)->cmd == IDM_INVERT)
                              {
                              asPuzzle[0][NUMCOLS-2] = NUMCOLS * NUMROWS - 2 ;
                              asPuzzle[0][NUMCOLS-3] = NUMCOLS * NUMROWS - 1 ;
                              }
                         asPuzzle[sBlankRow = 0][sBlankCol = NUMCOLS - 1] = 0 ;
                         WinInvalidateRect (hwnd, NULL, FALSE) ;
                         return 0 ;

                              // Randomly scramble the squares

                    case IDM_SCRAMBLE:
                         WinSetPointer (HWND_DESKTOP, WinQuerySysPointer (
                                        HWND_DESKTOP, SPTR_WAIT, FALSE)) ;

                         srand ((int) WinGetCurrentTime (NULL)) ;

                         for (i = 0 ; i < SCRAMBLEREP ; i++)
                              {
                              WinSendMsg (hwnd, WM_BUTTON1DOWN,
                                   MPFROM2SHORT (rand() % NUMCOLS * cxSquare,
                                        sBlankRow * cySquare), NULL) ;
                              WinUpdateWindow (hwnd) ;

                              WinSendMsg (hwnd, WM_BUTTON1DOWN,
                                   MPFROM2SHORT (sBlankCol * cxSquare,
                                        rand() % NUMROWS * cySquare), NULL) ;
                              WinUpdateWindow (hwnd) ;
                              }
                         WinSetPointer (HWND_DESKTOP, WinQuerySysPointer (
                                        HWND_DESKTOP, SPTR_ARROW, FALSE));
                         return 0 ;

                              // Display dialog box

                    case IDM_ABOUT:
                         WinDlgBox (HWND_DESKTOP, hwnd, AboutDlgProc,
                                    NULL, IDD_ABOUT, NULL) ;
                         return 0 ;
                    }
               break ;
          }
     return WinDefWindowProc (hwnd, msg, mp1, mp2) ;
     }

MRESULT EXPENTRY AboutDlgProc (HWND hwnd, USHORT msg, MPARAM mp1, MPARAM mp2)
     {
     switch (msg)
          {
          case WM_COMMAND:
               switch (COMMANDMSG(&msg)->cmd)
                    {
                    case DID_OK:
                    case DID_CANCEL:
                         WinDismissDlg (hwnd, TRUE) ;
                         return 0 ;
                    }
               break ;
          }
     return WinDefDlgProc (hwnd, msg, mp1, mp2) ;
     }
