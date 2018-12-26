/*
    TRYTD.C:    Demo of TD.C Time & Date Formatting Functions
			    OS/2 version

    by Ray Duncan, Copyright (C) 1988 Ziff Davis

    Compile:    C>CL TRYTD.C TD.C  <Enter>
*/

#include <stdio.h>
#include <stdlib.h>

extern char * systcvt(int);         /* local function prototypes */
extern char * sysdcvt(int);
extern char * dirtcvt(int, unsigned);
extern char * dirdcvt(int, unsigned);
extern char * tcvt(int, int, int, int, int);
extern char * dcvt(int, int, int, int);

#define API unsigned extern far pascal

API DosClose(unsigned);				/* API function prototypes */

API DosQFileInfo(unsigned, int, void far *, int);

API DosOpen(char far *, unsigned far *, unsigned far *, unsigned long,
            unsigned, unsigned, unsigned, unsigned long);           

struct _finfo {                    	/* used by DosGetFileInfo */
	unsigned cdate;
    unsigned ctime;
    unsigned adate;
    unsigned atime;
    unsigned wdate;
    unsigned wtime; 
	long fsize;
	long falloc;
	unsigned fattr; } finfo;


main()
{   
    char *tstr;                     /* pointer to formatted time */
    char *dstr;                     /* pointer to formatted date */
	unsigned fhandle, faction;		/* file handle, DosOpen action */
	unsigned status;				/* scratch variable */

    tstr = systcvt(11);             /* format current time */
    dstr = sysdcvt(8);              /* format current date */

                                    /* display time & date */
    printf("\nThe current time and date are: %s %s\n", tstr, dstr);

                                   	/* open the TRYTD.EXE file */
    if(DosOpen("TRYTD.EXE", &fhandle, &faction, 0L, 0, 1, 0x40, 0L))
    {   
    	puts("Can't open TRYTD.EXE");
        exit(1);
    }

									/* get file date & time */
	if(DosQFileInfo(fhandle, 1, &finfo, sizeof(finfo)))
    {   
    	puts("Can't get TRYTD.EXE file info");
        exit(1);
    }
	
	if(DosClose(fhandle))			/* close the file */
    {   
    	puts("Can't close TRYTD.EXE");
        exit(1);
    }
	
    dstr = dirdcvt(8, finfo.wdate); /* format date & time */
    tstr = dirtcvt(11, finfo.wtime);

                                    /* display time & date */
    printf("\nThe TRYTD.EXE file time and date are: %s %s\n",
            tstr, dstr);
}


