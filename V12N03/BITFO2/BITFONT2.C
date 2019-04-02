/*------------------------------------------
   BITFONTS.C -- Displays OS/2 Bitmap Fonts
                 (c) Charles Petzold, 1993
  ------------------------------------------*/

#define INCL_WIN
#define INCL_GPI
#include <os2.h>
#include <stdio.h>
#include <string.h>
#include "bitfont2.h"
#include "bmf.h"

#define LCID_FONT   1

MRESULT EXPENTRY ClientWndProc (HWND, ULONG, MPARAM, MPARAM) ;

int main (void)
     {
     static CHAR  szClientClass [] = "BitFont2" ;
     static ULONG flFrameFlags = FCF_TITLEBAR      | FCF_SYSMENU  |
                                 FCF_SIZEBORDER    | FCF_MINMAX   |
                                 FCF_SHELLPOSITION | FCF_TASKLIST |
                                 FCF_MENU ;
     HAB          hab ;
     HMQ          hmq ;
     HWND         hwndFrame, hwndClient ;
     QMSG         qmsg ;

     hab = WinInitialize (0) ;
     hmq = WinCreateMsgQueue (hab, 0) ;

     WinRegisterClass (hab, szClientClass, ClientWndProc, CS_SIZEREDRAW, 0) ;

     hwndFrame = WinCreateStdWindow (HWND_DESKTOP, WS_VISIBLE,
                                     &flFrameFlags, szClientClass,
                                     "Bitmap Fonts", 0L,
                                     NULLHANDLE, ID_RESOURCE, &hwndClient) ;

     while (WinGetMsg (hab, &qmsg, NULLHANDLE, 0, 0))
          WinDispatchMsg (hab, &qmsg) ;

     WinDestroyWindow (hwndFrame) ;
     WinDestroyMsgQueue (hmq) ;
     WinTerminate (hab) ;
     return 0 ;
     }

MRESULT EXPENTRY ClientWndProc (HWND hwnd, ULONG msg, MPARAM mp1, MPARAM mp2)
     {
     static BOOL  fItalic, fUnder, fStrike, fBold ;
     static HWND  hwndMenu ;
     static SHORT cyClient ;
     CHAR         szBuffer [FACESIZE + 32] ;
     FONTMETRICS  fm ;
     HPS          hps ;
     int          iFace, iSize ;
     PFONTLIST    pfl ;
     POINTL       ptl ;

     switch (msg)
	  {
          case WM_CREATE:
               hwndMenu = WinWindowFromID (WinQueryWindow (hwnd, QW_PARENT),
                                           FID_MENU) ;
               return 0 ;

          case WM_SIZE:
               cyClient = HIUSHORT (mp2) ;
               return 0 ;

          case WM_COMMAND:
               switch (COMMANDMSG(&msg)->cmd)
                    {
                    case IDM_ITALIC:      fItalic   = ! fItalic   ;  break ;
                    case IDM_UNDERSCORE:  fUnder    = ! fUnder    ;  break ;
                    case IDM_STRIKEOUT:   fStrike   = ! fStrike   ;  break ;
                    case IDM_BOLD:        fBold     = ! fBold     ;  break ;

                    default:  return 0 ;
                    }

               WinCheckMenuItem (hwndMenu, COMMANDMSG(&msg)->cmd,
                    ! WinIsMenuItemChecked (hwndMenu, COMMANDMSG(&msg)->cmd)) ;

               WinInvalidateRect (hwnd, NULL, TRUE) ;
               return 0 ;

          case WM_PAINT:
               hps = WinBeginPaint (hwnd, NULLHANDLE, NULL) ;

               GpiErase (hps) ;

                    // Get the font list

               pfl = GetAllBitmapFonts (hps) ;

                    // Set POINTL structure to upper left corner of client

               ptl.x = 0 ;
               ptl.y = cyClient ;

                    // Loop through all the bitmap fonts

               for (iFace = 0 ; iFace < pfl->iNumFaces              ; iFace ++)
               for (iSize = 0 ; iSize < pfl->faces[iFace].iNumSizes ; iSize ++)
                    {
                         // Create the logical font and select it

                    CreateBitmapFont (hps, LCID_FONT,
                                   pfl->faces[iFace].szFacename,
                                   pfl->faces[iFace].psizes[iSize].iPointSize,
                                   (fItalic  ? FATTR_SEL_ITALIC     : 0) |
                                   (fUnder   ? FATTR_SEL_UNDERSCORE : 0) |
                                   (fStrike  ? FATTR_SEL_STRIKEOUT  : 0) |
                                   (fBold    ? FATTR_SEL_BOLD       : 0),
                                   0) ;

                    GpiSetCharSet (hps, LCID_FONT) ;

                         // Query the font metrics of the current font

                    GpiQueryFontMetrics (hps, sizeof (FONTMETRICS), &fm) ;

                         // Set up a text string to display

                    sprintf (szBuffer, "%s - %d points",
                             pfl->faces[iFace].szFacename,
                             pfl->faces[iFace].psizes[iSize].iPointSize) ;

                         // Drop POINTL structure to baseline of font

                    ptl.y -= fm.lMaxAscender ;

                         // Display the character string

                    GpiCharStringAt (hps, &ptl, strlen (szBuffer), szBuffer) ;

                         // Drop POINTL structure down to bottom of text

                    ptl.y -= fm.lMaxDescender ;

                         // Select the default font; delete the logical font

                    GpiSetCharSet (hps, LCID_DEFAULT) ;
                    GpiDeleteSetId (hps, LCID_FONT) ;
                    }

               WinEndPaint (hps) ;
               return 0 ;

          case WM_DESTROY:
               return 0 ;
          }
     return WinDefWindowProc (hwnd, msg, mp1, mp2) ;
     }
