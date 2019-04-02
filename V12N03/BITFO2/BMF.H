/*-------------------------------------------
   BMF.H -- Easy access to OS/2 bitmap fonts
            (c) Charles Petzold, 1993
  -------------------------------------------*/

typedef struct
     {
     int  iPointSize ;
     LONG lMatch ;
     }
     SIZES ;

typedef SIZES * PSIZES ;

typedef struct
     {
     char   szFacename [FACESIZE] ;
     int    iNumSizes ;
     PSIZES psizes ;
     }
     FACES ;

typedef struct
     {
     int   iNumFaces ;
     FACES faces [1] ;
     }
     FONTLIST ;

typedef FONTLIST * PFONTLIST ;

PFONTLIST GetAllBitmapFonts (HPS hps) ;

LONG CreateBitmapFont (HPS hps, LONG lcid, char * szFacename,
                       int iPointSize, SHORT fsAttributes, SHORT usCodePage) ;
