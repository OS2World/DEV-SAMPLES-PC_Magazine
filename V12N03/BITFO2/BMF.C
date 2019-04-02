/*-------------------------------------------
   BMF.C -- Easy access to OS/2 bitmap fonts
            (c) Charles Petzold, 1993
  -------------------------------------------*/

#define INCL_GPI
#include <os2.h>
#include <stdlib.h>
#include <string.h>
#include "bmf.h"

static PFONTLIST pfl ;

PFONTLIST GetAllBitmapFonts (HPS hps)
     {
     HDC          hdc ;
     int          iFace, iSize ;
     LONG         l, lFonts, xRes, yRes ;
     PFONTMETRICS pfm ;

               // Check for changed fonts

     if (!(QFA_PUBLIC & GpiQueryFontAction (hps, QFA_PUBLIC)) && pfl != NULL)
          return pfl ;

               // Clean up old structure if necessary

     if (pfl != NULL)
          {
          for (iFace = 0 ; iFace < pfl->iNumFaces ; iFace++)
               free (pfl->faces[iFace].psizes) ;

          free (pfl) ;
          }

               // Determine the number of fonts

     lFonts = 0 ;
     lFonts = GpiQueryFonts (hps, QF_PUBLIC, NULL, &lFonts, 0, NULL) ;

     if (lFonts == 0)
          return NULL ;

               // Allocate memory for FONTMETRICS structures

     pfm = (PFONTMETRICS) calloc (lFonts, sizeof (FONTMETRICS)) ;

     if (pfm == NULL)
          return NULL ;

               // Get all fonts

     GpiQueryFonts (hps, QF_PUBLIC, NULL, &lFonts,
                         sizeof (FONTMETRICS), pfm) ;

               // Determine font resolution

     hdc = GpiQueryDevice (hps) ;

     DevQueryCaps (hdc, CAPS_HORIZONTAL_FONT_RES, 1, &xRes) ;
     DevQueryCaps (hdc, CAPS_VERTICAL_FONT_RES,   1, &yRes) ;

               // Allocate memory for FONTLIST structure

     pfl = malloc (sizeof (FONTLIST)) ;
     pfl->iNumFaces = 0 ;

               // Loop through all fonts

     for (l = 0 ; l < lFonts ; l++)
          {
                    // Check if bitmap font at screen resolution

          if (!(pfm[l].fsDefn & FM_DEFN_OUTLINE) &&
                pfm[l].sXDeviceRes == xRes       &&
                pfm[l].sYDeviceRes == yRes)
               {
                         // Loop through existing facenames

               for (iFace = 0 ; iFace < pfl->iNumFaces ; iFace++)
                    if (0 == strcmp (pfl->faces[iFace].szFacename,
                                     pfm[l].szFacename))
                         break ;

                         // If new face, reallocate FONTLIST structure

               if (iFace == pfl->iNumFaces)
                    {
                    pfl = realloc (pfl, sizeof (FONTLIST) +
                                        pfl->iNumFaces * sizeof (FACES)) ;

                    pfl->iNumFaces ++ ;

                    strcpy (pfl->faces[iFace].szFacename, pfm[l].szFacename) ;

                    pfl->faces[iFace].iNumSizes = 0 ;
                    pfl->faces[iFace].psizes = NULL ;
                    }

               iSize = pfl->faces[iFace].iNumSizes ;

               pfl->faces[iFace].iNumSizes ++ ;

               pfl->faces[iFace].psizes =  realloc (pfl->faces[iFace].psizes,
                              pfl->faces[iFace].iNumSizes * sizeof (SIZES)) ;

                         // Store point size and lMatch value

               pfl->faces[iFace].psizes[iSize].iPointSize =
                                   pfm[l].sNominalPointSize / 10 ;

               pfl->faces[iFace].psizes[iSize].lMatch = pfm[l].lMatch ;
               }
          }

               // Clean up

     free (pfm) ;

     return pfl ;
     }

LONG CreateBitmapFont (HPS hps, LONG lcid, char * szFacename,
                       int iPointSize, SHORT fsAttributes, SHORT usCodePage)
     {
     FATTRS fat ;
     int    iFace, iSize ;

     fat.usRecordLength  = sizeof (FATTRS) ;
     fat.fsSelection     = fsAttributes ;
     fat.lMatch          = 0 ;
     fat.szFacename[0]   = '\0' ;
     fat.idRegistry      = 0 ;
     fat.usCodePage      = usCodePage ;
     fat.lMaxBaselineExt = 0 ;
     fat.lAveCharWidth   = 0 ;
     fat.fsType          = 0 ;
     fat.fsFontUse       = 0 ;

               // If fonts have changed, re-enumerate them

     GetAllBitmapFonts (hps) ;

               // If bitmap fonts are available, loop through faces

     if (pfl != NULL)
          for (iFace = 0 ; iFace < pfl->iNumFaces ; iFace++)

                         // If a face matches, loop through sizes

               if (0 == strcmp (szFacename, pfl->faces[iFace].szFacename))
                    for (iSize = 0 ; iSize < pfl->faces[iFace].iNumSizes ;
                                     iSize++)

                                   // If size matches, setup FATTR structure

                         if (iPointSize ==
                                   pfl->faces[iFace].psizes[iSize].iPointSize)
                              {
                              strcpy (fat.szFacename,
                                      pfl->faces[iFace].szFacename) ;

                              fat.lMatch =
                                   pfl->faces[iFace].psizes[iSize].lMatch ;
                              }

               // Create the font

     return GpiCreateLogFont (hps, NULL, lcid, &fat) ;
     }
