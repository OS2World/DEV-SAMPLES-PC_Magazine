/*
    TD.C:  Time & Date Formatting Functions

    Ray Duncan, December 1987

*/

#include <stdio.h>
#include <stdlib.h>
#include <dos.h>

union REGS regs;

char * systcvt(int);                /* function prototypes */
char * sysdcvt(int);
char * dirtcvt(int, unsigned);
char * dirdcvt(int, unsigned);
char * tcvt(int, int, int, int, int);
char * dcvt(int, int, int, int);
void   getctry();

static char cbuff[34];              /* receives country info */

static int cflag = 0;               /* true if country info */
                                    /* present in cbuff */


                                        
/*
        Convert current system time to ASCII string.
*/

char * systcvt(int length)
{   
    char *p;
    int hour, min, sec, csec;

    regs.x.ax = 0x2c00;             /* get current time */
    int86(0x21, &regs, &regs);

    hour = regs.h.ch;               /* extract hours, minutes, */
    min = regs.h.cl;                /* seconds, and hundredths */
    sec = regs.h.dh;                /* of seconds from registers */
    csec = regs.h.dl;

                                    /* convert it to ASCII */
    p=tcvt(length, hour, min, sec, csec);

    return(p);                      /* return pointer */
}


/*
        Convert current system date to ASCII string.
*/

char * sysdcvt(int length)
{   
    char *p;
    int month, day, year;

    regs.x.ax = 0x2a00;             /* get current date */
    int86(0x21, &regs, &regs);

    month = regs.h.dh;              /* extract month, day, */
    day = regs.h.dl;                /* year from registers */
    year = regs.x.cx - 1900;

                                    /* convert it to ASCII */
    p=dcvt(length, month, day, year);
    return(p);                      /* return pointer */
}


/*
        Convert time in directory format to ASCII string.
*/

char * dirtcvt(int length, unsigned dirtime)
{   
    char *p;
    int hour, min, sec, csec;

    hour = (dirtime >> 11) & 0x1f;  /* isolate time fields */ 
    min = (dirtime >> 5) & 0x3f;
    sec = (dirtime & 0x1f) * 2;
    csec = 0;

                                    /* convert it to ASCII */
    p=tcvt(length, hour, min, sec, csec);

    return(p);                      /* return pointer */
}


/*
        Convert date in directory format to ASCII string.
*/

char * dirdcvt(int length, unsigned dirdate)
{
    char *p;
    int month, day, year;

    day = dirdate & 0x1f;           /* isolate date fields */
    month = (dirdate >> 5) & 0x0f;
    year = 80 + ((dirdate >> 9) & 0x3f);

                                    /* convert it to ASCII */
    p=dcvt(length, month, day, year);
    return(p);                      /* return pointer */
}



/*
        Convert hours, minutes, seconds, and hundredths
        of seconds to ASCII string, truncating string to 
        lesser of specified length or 11 characters.
*/

char * tcvt(int length, int hour, int min, int sec, int csec)
{   
    static char time[12];           /* receives formatted time */

    getctry();                      /* get country info */

    sprintf(time,"%02d%c%02d%c%02d%c%02d", 
              hour, cbuff[13], min, cbuff[13], sec, cbuff[9], csec);

                                    /* truncate if necessary */
    time[(int) min(length, 11)] = 0;

    return(time);                   /* return pointer */
}


/*
        Convert month, day, and year to ASCII string, truncating
        string to lesser of specified length or 8 characters.
*/

char * dcvt(int length, int month, int day, int year)
{   
    static char date[9];            /* receives formatted date */

    getctry();                      /* get country info */

    switch(cbuff[0])                /* format by date code */
    {
        case 0:                     /* USA: m d y */
        sprintf(date,"%02d%c%02d%c%02d", 
                  month, cbuff[11], day, cbuff[11], year);
            break;

        case 1:                     /* Europe: d m y */
        sprintf(date,"%02d%c%02d%c%02d", 
                  day, cbuff[11], month, cbuff[11], year);
            break;

        case 2:                     /* Japan: y m d */
        sprintf(date,"%02d%c%02d%c%02d", 
                  year, cbuff[11], month, cbuff[11], day);
            break;
    }

    date[(int) min(length, 8)] = 0; /* truncate string */

   return(date);                    /* return pointer */
}


/*
        Get MS-DOS internationalization information into
        'cbuff', or provide default information.
*/

void getctry()
{   
    int dosver;

    if(cflag) return;               /* exit if information */
                                    /* already in buffer */

    memset(cbuff,0,34);             /* initialize buffer */

    regs.x.ax = 0x3000;             /* get MS-DOS version */
    int86(0x21, &regs, &regs);
    dosver = regs.h.al;

    if(dosver >= 2)                 /* if MS-DOS 2.x or 3.x */
    {                               /* get country info */
        (char *) regs.x.dx = cbuff;
        regs.x.ax = 0x3800;
        int86(0x21, &regs, &regs);
    }

    if(dosver <= 2)                 /* if MS-DOS 1.x or 2.x */
    {                               /* force delimiter info */
        cbuff[9]  = '.';            /* decimal separator */
        cbuff[11] = '/';            /* date separator */
        cbuff[13] = ':';            /* time separator */
    }

    cflag = -1;                     /* we've been here before */
}

