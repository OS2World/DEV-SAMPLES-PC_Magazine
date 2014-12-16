/*-------------------------------------------------------------------
   PMASC.C -- ASCII (and EBCDIC) Table for OS/2 Presentation Manager
              (c) 1989, Ziff Communications Co.
              PC Magazine * Charles Petzold, March 1989
  -------------------------------------------------------------------*/

#define INCL_WIN
#define INCL_GPI
#include <os2.h>
#include <stdlib.h>
#include <string.h>
#include "pmasc.h"

MRESULT EXPENTRY ClientWndProc (HWND, USHORT, MPARAM, MPARAM) ;
MRESULT EXPENTRY AboutDlgProc  (HWND, USHORT, MPARAM, MPARAM) ;

int main (void)
     {
     static CHAR  szClientClass[] = "PMASC" ;
     static ULONG flFrameFlags = FCF_SYSMENU | FCF_TITLEBAR   |
                                 FCF_BORDER  | FCF_MINBUTTON  |
                                 FCF_MENU    | FCF_VERTSCROLL |
                                 FCF_ICON    | FCF_TASKLIST ;
     HAB          hab ;
     HMQ          hmq ;
     HWND         hwndFrame, hwndClient ;
     QMSG         qmsg ;

     hab = WinInitialize (0) ;
     hmq = WinCreateMsgQueue (hab, 0) ;

     WinRegisterClass (hab, szClientClass, ClientWndProc, 0L, 0) ;

     hwndFrame = WinCreateStdWindow (HWND_DESKTOP, WS_VISIBLE,
                                     &flFrameFlags, szClientClass, NULL,
                                     0L, NULL, ID_RESOURCE, &hwndClient) ;

     while (WinGetMsg (hab, &qmsg, NULL, 0, 0))
          WinDispatchMsg (hab, &qmsg) ;

     WinDestroyWindow (hwndFrame) ;
     WinDestroyMsgQueue (hmq) ;
     WinTerminate (hab) ;
     return 0 ;
     }

MRESULT EXPENTRY ClientWndProc (HWND hwnd, USHORT msg, MPARAM mp1, MPARAM mp2)
     {
     static CHAR   *szHeading[] = { "Dec", "Hex", "Char" },
                   achHex[] = "0123456789ABCDEF" ;
     static HWND   hwndFrame, hwndMenu, hwndScroll ;
     static RECTL  rcl ;
     static SHORT  sScroll, cxChar, cyChar, cyDesc ;
     static USHORT usDefCodePage, usSelCodePage ;
     CHAR          szBuffer[40] ;
     FONTMETRICS   fm ;
     POINTL        ptl, aptlText[TXTBOX_COUNT] ;
     HPS           hps ;
     RECTL         rclInvalid ;
     SHORT         sLineBeg, sLineEnd, sLine, sCol, sNum, i, j ;

     switch (msg)
          {
          case WM_CREATE:
               hps = WinGetPS (hwnd) ;
               usDefCodePage = GpiQueryCp (hps) ;
               usSelCodePage = usDefCodePage ;

                         // Get text dimensions

               GpiQueryFontMetrics (hps, (LONG) sizeof fm, &fm) ;
               cxChar = (SHORT) fm.lAveCharWidth ;
               cyChar = (SHORT) fm.lMaxBaselineExt ;
               cyDesc = (SHORT) fm.lMaxDescender ;
               WinReleasePS (hps) ;

                         // Get handles of scroll bar and menu windows

               hwndFrame  = WinQueryWindow (hwnd, QW_PARENT, FALSE) ;
               hwndScroll = WinWindowFromID (hwndFrame, FID_VERTSCROLL) ;
               hwndMenu   = WinWindowFromID (hwndFrame, FID_MENU) ;

                         // Set scroll bar range

               WinSendMsg (hwndScroll, SBM_SETSCROLLBAR,
                           MPFROMSHORT (0), MPFROM2SHORT (0, 224)) ;

                         // Put check mark in menu for current code page

               WinSendMsg (hwndMenu, MM_SETITEMATTR,
                           MPFROM2SHORT (usSelCodePage, TRUE),
                           MPFROM2SHORT (MIA_CHECKED, MIA_CHECKED)) ;

                         // Calculate client window size and position

               rcl.xLeft   = (WinQuerySysValue (HWND_DESKTOP, SV_CXSCREEN) -
                                           36 * cxChar) / 2 ;
               rcl.yBottom = (WinQuerySysValue (HWND_DESKTOP, SV_CYSCREEN) -
                                           18 * cyChar) / 2 ;
               rcl.xRight  = rcl.xLeft   + 36 * cxChar ;
               rcl.yTop    = rcl.yBottom + 18 * cyChar ;

                         // Set frame window position and size

               WinCalcFrameRect (hwndFrame, &rcl, FALSE) ;
               WinSetWindowPos  (hwndFrame, NULL,
                                 (SHORT) rcl.xLeft, (SHORT) rcl.yBottom,
                                 (SHORT) (rcl.xRight - rcl.xLeft),
                                 (SHORT) (rcl.yTop - rcl.yBottom),
                                 SWP_MOVE | SWP_SIZE | SWP_ACTIVATE) ;

                         // Rectangle of table (without heading)

               rcl.xLeft   = 0 ;
               rcl.yBottom = 0 ;
               rcl.xRight  = 36 * cxChar ;
               rcl.yTop    = 16 * cyChar ;
               return 0 ;

          case WM_VSCROLL:
               switch (SHORT2FROMMP (mp2))
                    {
                              // Scroll bar line up or down: Scroll window

                    case SB_LINEUP:
                         if (sScroll > 0)
                              {
                              sScroll-- ;
                              WinScrollWindow (hwnd, 0, -cyChar, &rcl, &rcl,
                                               NULL, NULL, SW_INVALIDATERGN) ;
                              }
                         break ;

                    case SB_LINEDOWN:
                         if (sScroll < 224)
                              {
                              sScroll++ ;
                              WinScrollWindow (hwnd, 0, cyChar, &rcl, &rcl,
                                               NULL, NULL, SW_INVALIDATERGN) ;
                              }
                         break ;

                              // Scroll bar page up or down: Invalidate window

                    case SB_PAGEUP:
                         if (sScroll > 0)
                              {
                              sScroll = max (0, sScroll - 32) ;
                              WinInvalidateRect (hwnd, &rcl, FALSE) ;
                              }
                         break ;

                    case SB_PAGEDOWN:
                         if (sScroll < 224)
                              {
                              sScroll = min (224, sScroll + 32) ;
                              WinInvalidateRect (hwnd, &rcl, FALSE) ;
                              }
                         break ;

                    case SB_SLIDERPOSITION:
                         if (sScroll != SHORT1FROMMP (mp2))
                              {
                              sScroll = SHORT1FROMMP (mp2) ;
                              WinInvalidateRect (hwnd, &rcl, FALSE) ;
                              }
                         break ;

                    default:
                         return 0 ;
                    }

               WinSendMsg (hwndScroll, SBM_SETPOS,
                                       MPFROMSHORT (sScroll), NULL) ;
               return 0 ;

                    // Keyboard messages: Mimic scroll bar

          case WM_CHAR:
               switch (CHARMSG(&msg)->vkey)
                    {
                    case VK_HOME:
                         return WinSendMsg (hwnd, WM_VSCROLL, NULL,
                                   MPFROM2SHORT (0, SB_SLIDERPOSITION)) ;
                    case VK_END:
                         return WinSendMsg (hwnd, WM_VSCROLL, NULL,
                                   MPFROM2SHORT (224, SB_SLIDERPOSITION)) ;
                    default:
                         return WinSendMsg (hwndScroll, msg, mp1, mp2) ;
                    }

                    // Menu messages: Invoke "About" box or set new code page

          case WM_COMMAND:
               if (COMMANDMSG(&msg)->cmd == IDM_ABOUT)
                    WinDlgBox (HWND_DESKTOP, hwnd, AboutDlgProc,
                               NULL, IDD_ABOUT, NULL) ;
               else
                    {
                    WinSendMsg (hwndMenu, MM_SETITEMATTR,
                                MPFROM2SHORT (usSelCodePage, TRUE),
                                MPFROM2SHORT (MIA_CHECKED, 0)) ;

                    hps = WinGetPS (hwnd) ;
                    GpiSetCp (hps, COMMANDMSG(&msg)->cmd) ;
                    usSelCodePage = GpiQueryCp (hps) ;
                    GpiSetCp (hps, usDefCodePage) ;
                    WinReleasePS (hps) ;

                    WinSendMsg (hwndMenu, MM_SETITEMATTR,
                                MPFROM2SHORT (usSelCodePage, TRUE),
                                MPFROM2SHORT (MIA_CHECKED, MIA_CHECKED)) ;

                    WinInvalidateRect (hwnd, NULL, FALSE) ;
                    }
               return 0 ;

          case WM_PAINT:
               hps = WinBeginPaint (hwnd, NULL, &rclInvalid) ;
               WinFillRect (hps, &rclInvalid, CLR_WHITE) ;

                         // Draw lines in window

               GpiSetColor (hps, CLR_BLACK) ;

               ptl.x = rcl.xRight / 2 ;  ptl.y = 0 ;  GpiMove (hps, &ptl) ;
               ptl.y = rcl.yTop + cyChar ;            GpiLine (hps, &ptl) ;
               ptl.x = 0 ;  ptl.y = rcl.yTop ;        GpiMove (hps, &ptl) ;
               ptl.x = rcl.xRight ;                   GpiLine (hps, &ptl) ;

                         // Determine text line range within invalid rectangle

               sLineBeg = (SHORT) (16 - (rclInvalid.yTop+cyChar-1) / cyChar) ;
               sLineEnd = (SHORT) (16 -  rclInvalid.yBottom        / cyChar) ;

               for (sLine = sLineBeg ; sLine < sLineEnd ; sLine++)
                    {
                    ptl.y = (15 - sLine) * cyChar + cyDesc ;

                              // Display codepage name

                    if (sLine == -2)
                         {
                         GpiSetColor (hps, CLR_RED) ;

                         WinSendMsg (hwndMenu, MM_QUERYITEMTEXT,
                                     MPFROM2SHORT (usSelCodePage,
                                                   (SHORT) sizeof (szBuffer)),
                                     szBuffer) ;

                                        // Strip out '~' character

                         for (i = 0, j = 0 ; szBuffer[j] != '\0' ; )
                              if (szBuffer[i++] != '~')
                                   szBuffer[j++] = szBuffer[i-1] ;

                                        // Display centered text

                         GpiQueryTextBox (hps, (LONG) strlen (szBuffer),
                                          szBuffer, TXTBOX_COUNT, aptlText) ;

                         ptl.x = (rcl.xRight - aptlText[TXTBOX_CONCAT].x) / 2 ;
                         GpiCharStringAt (hps, &ptl, (LONG) strlen (szBuffer),
                                          szBuffer) ;
                         }

                              // Display heading

                    else if (sLine == -1)
                         {
                         GpiSetColor (hps, CLR_BLUE) ;

                         for (sCol = 0 ; sCol < 6 ; sCol++)
                              {
                              ptl.x = cxChar * (5 * sCol + (sCol > 2 ? 4 : 2));

                              GpiCharStringAt (hps, &ptl,
                                   (LONG) strlen (szHeading[sCol % 3]),
                                   szHeading[sCol % 3]) ;
                              }
                         }
                    else
                         {
                         GpiSetColor (hps, CLR_BLACK) ;

                         for (sCol = 0 ; sCol < 6 ; sCol++)
                              {
                              ptl.x = cxChar * (5 * sCol + (sCol > 2 ? 4 : 2));
                              sNum = sScroll + sLine + (sCol > 2 ? 16 : 0) ;

                                        // Decimal ASCII/EBCDIC code

                              if (sCol % 3 == 0)
                                   {
                                   szBuffer[0] = (CHAR) ('0' + sNum/100) ;
                                   szBuffer[1] = (CHAR) ('0' + sNum%100/10) ;
                                   szBuffer[2] = (CHAR) ('0' + sNum%10) ;
                                   szBuffer[3] = '\0' ;
                                   }
                                        // Hexadecimal ASCII/EBCDIC code

                              else if (sCol % 3 == 1)
                                   {
                                   szBuffer[0] = ' ' ;
                                   szBuffer[1] = achHex[sNum >> 4] ;
                                   szBuffer[2] = achHex[sNum & 15] ;
                                   szBuffer[3] = '\0' ;
                                   }
                                        // ASCII/EBCDIC character
                              else
                                   {
                                   szBuffer[0] = ' ' ;
                                   szBuffer[1] = (CHAR) sNum ;
                                   szBuffer[2] = '\0' ;

                                   GpiSetCp (hps, usSelCodePage) ;
                                   }

                              GpiCharStringAt (hps, &ptl,
                                        (LONG) strlen (szBuffer), szBuffer) ;

                              GpiSetCp (hps, usDefCodePage) ;
                              }
                         }
                    }
               WinEndPaint (hps) ;
               return 0 ;
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
