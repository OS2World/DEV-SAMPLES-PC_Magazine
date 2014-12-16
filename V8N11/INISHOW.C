/*------------------------------------------------------
   INISHOW.C - Displays OS2.INI Information in OS/2 1.1
               (C) 1989, Ziff Communications Co.
               PC Magazine * Charles Petzold, 1/89
  ------------------------------------------------------*/

#define  INCL_WINSHELLDATA
#include <os2.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define  BYTES 8    // Bytes of binary data per display line

int main (void)
     {
     BOOL   fIsString ;
     CHAR   szBuffer[4 * BYTES + 10] ;
     HAB    hab ;
     INT    iQueryApp, iQueryKey, iOff, iByte, iLen ;
     UCHAR  *pchQueryApp, *pchQueryKey, *pchQueryStr ;
     USHORT cbData ;

     hab = WinInitialize (0) ;
                                   // Allocate memory for application names

     if (WinQueryProfileSize (hab, NULL, NULL, &cbData))
          {
          fputs ("INISHOW: Cannot obtain any profile data.\n", stderr) ;
          return 1 ;
          }

     if (NULL == (pchQueryApp = malloc (cbData)))
          {
          fputs ("INISHOW: Cannot allocate memory for application names.\n",
                 stderr) ;
          return 1 ;
          }
                                   // Get list of application names and scan

     WinQueryProfileString (hab, NULL, NULL, "", pchQueryApp, cbData) ;
     iQueryApp = 0 ;

     while (pchQueryApp[iQueryApp] != '\0')
          {
          printf ("[%s]\n", pchQueryApp + iQueryApp) ;

                                        // Allocate memory for key names

          WinQueryProfileSize (hab, pchQueryApp + iQueryApp, NULL, &cbData) ;

          if (NULL == (pchQueryKey = malloc (cbData)))
               {
               fputs ("INISHOW: Cannot allocate memory for key names.\n",
                      stderr) ;
               return 1 ;
               }
                                        // Get list of key names and scan

          WinQueryProfileString (hab, pchQueryApp + iQueryApp, NULL, "",
                                      pchQueryKey, cbData) ;
          iQueryKey = 0 ;

          while (pchQueryKey[iQueryKey] != '\0')
               {
                                             // Get size of data

               WinQueryProfileSize (hab, pchQueryApp + iQueryApp,
                                         pchQueryKey + iQueryKey, &cbData) ;

               if (NULL == (pchQueryStr = malloc (cbData)))
                    {
                    fputs ("INISHOW: Cannot allocate memory for data.\n",
                           stderr) ;
                    return 1 ;
                    }

               printf ("\t[%s]%s\n", pchQueryKey + iQueryKey,
                                     cbData == 0 ? " -- NO DATA -- " : "") ;
               if (cbData == 0)
                    continue ;
                                             // Determine if data is string
                                             // or stored in a binary format

               fIsString = (cbData > 1) ? TRUE : FALSE ;

               if (fIsString)
                    {
                    WinQueryProfileString (hab, pchQueryApp + iQueryApp,
                                                pchQueryKey + iQueryKey, "",
                                                pchQueryStr, cbData) ;

                                             // Check if string length matches

                    if (cbData != strlen (pchQueryStr) + 1)
                         fIsString = FALSE ;
                    }
                                             // Check for printable characters
               if (fIsString)
                    for (iByte = 0 ; iByte < cbData - 1 ; iByte++)
                         if (!isprint (pchQueryStr[iByte]))
                              fIsString = FALSE ;

                                             // If a string, display it
               if (fIsString)
                    printf ("\t\t%s\n", pchQueryStr) ;

                                             // If not, dump it
               else
                    {
                    WinQueryProfileData (hab, pchQueryApp + iQueryApp,
                                              pchQueryKey + iQueryKey,
                                              pchQueryStr, &cbData) ;

                    for (iOff = 0 ; iOff < cbData ; iOff += BYTES)
                         {
                         iLen = sprintf (szBuffer, "\t\t%04X  ", iOff) ;

                         for (iByte = iOff ; iByte < iOff + BYTES ; iByte++)
                              {
                              if (iByte < cbData)
                                   iLen += sprintf (szBuffer + iLen, "%02X ",
                                                    pchQueryStr[iByte]) ;
                              else
                                   iLen = strlen (strcat (szBuffer, "   ")) ;
                              }
                         szBuffer[iLen++] = ' ' ;

                         for (iByte = iOff ; iByte < iOff + BYTES ; iByte++)
                              {
                              if (iByte < cbData)
                                   if (isprint (pchQueryStr[iByte]))
                                        szBuffer[iLen++] = pchQueryStr[iByte] ;
                                   else
                                        szBuffer[iLen++] = '.' ;
                              else
                                   szBuffer[iLen++] = ' ' ;
                              }
                         szBuffer[iLen] = '\0' ;
                         puts (szBuffer) ;
                         }
                    }
                                             // Next key name
               free (pchQueryStr) ;
               iQueryKey += strlen (pchQueryKey + iQueryKey) + 1 ;
               }
                                        // Next application name
          free (pchQueryKey) ;
          iQueryApp += strlen (pchQueryApp + iQueryApp) + 1 ;
          }
                                   // Clean up and terminate
     free (pchQueryApp) ;
     WinTerminate (hab) ;
     return 0 ;
     }
