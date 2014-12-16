/*---------------------------------------------------------
   POPMENU.C -- Popup Menus for OS/2 Presentation Manager
                (c) 1989, Ziff Communications Co.
                PC Magazine * Charles Petzold, August 1989
  ---------------------------------------------------------*/

#define INCL_WIN
#include <os2.h>
#include "popmenu.h"

MRESULT EXPENTRY ClientWndProc (HWND, USHORT, MPARAM, MPARAM) ;
MRESULT EXPENTRY AboutDlgProc  (HWND, USHORT, MPARAM, MPARAM) ;

int main (void)
     {
     static CHAR  szClientClass[] = "PopMenu" ;
     static ULONG flFrameFlags = FCF_TITLEBAR      | FCF_SYSMENU  |
                                 FCF_SIZEBORDER    | FCF_MINMAX   |
                                 FCF_SHELLPOSITION | FCF_TASKLIST |
                                 FCF_MENU ;
     HAB          hab ;
     HMQ          hmq ;
     HWND         hwndFrame, hwndClient ;
     QMSG         qmsg ;

     hab = WinInitialize (0) ;
     hmq = WinCreateMsgQueue (hab, DEFAULT_QUEUE_SIZE) ;

     WinRegisterClass (hab, szClientClass, ClientWndProc, 0L, 0) ;

     hwndFrame = WinCreateStdWindow (HWND_DESKTOP, WS_VISIBLE,
                                     &flFrameFlags, szClientClass, NULL,
                                     0L, NULL, ID_NORMAL, &hwndClient) ;

     while (WinGetMsg (hab, &qmsg, NULL, 0, 0))
          WinDispatchMsg (hab, &qmsg) ;

     WinDestroyWindow (hwndFrame) ;
     WinDestroyMsgQueue (hmq) ;
     WinTerminate (hab) ;
     return 0 ;
     }

MRESULT EXPENTRY ClientWndProc (HWND hwnd, USHORT msg, 
                                MPARAM mp1, MPARAM mp2)
     {
     static HWND hwndMenuPopup ;
     HPS         hps ;
     POINTL      ptlMouse ;

     switch (msg)
          {
          case WM_CREATE:
               hwndMenuPopup = WinLoadMenu (hwnd, NULL, ID_POPUP) ;
               WinSetWindowPos (hwndMenuPopup, NULL, 
                                0, 0, 0, 0, SWP_SIZE) ;
               WinSetParent (hwndMenuPopup, HWND_DESKTOP, FALSE) ;
               return 0 ;

          case WM_BUTTON2UP:
               WinQueryPointerPos (HWND_DESKTOP, &ptlMouse) ;
               ptlMouse.y += WinQuerySysValue (HWND_DESKTOP, 
                                               SV_CYMENU) ;

               WinSetWindowPos (hwndMenuPopup, NULL,
                                (SHORT) ptlMouse.x, (SHORT) ptlMouse.y,
                                0, 0, SWP_MOVE) ;

               WinSendMsg (hwndMenuPopup, MM_SELECTITEM,
                           MPFROM2SHORT (IDM_POPUP, FALSE),
                           MPFROMSHORT (FALSE)) ;

               WinSetCapture (HWND_DESKTOP, hwndMenuPopup) ;
               return 0 ;

          case WM_COMMAND:
               switch (COMMANDMSG(&msg)->cmd)
                    {
                    case IDM_ABOUT:
                         WinDlgBox (HWND_DESKTOP, hwnd, AboutDlgProc,
                                    NULL, IDD_ABOUT, NULL) ;
                         return 0 ;
                    }
               break ;

          case WM_PAINT:
               hps = WinBeginPaint (hwnd, NULL, NULL) ;
               GpiErase (hps) ;
               WinEndPaint (hps) ;
               return 0 ;
          }
     return WinDefWindowProc (hwnd, msg, mp1, mp2) ;
     }

MRESULT EXPENTRY AboutDlgProc (HWND hwnd, USHORT msg, 
                               MPARAM mp1, MPARAM mp2)
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


