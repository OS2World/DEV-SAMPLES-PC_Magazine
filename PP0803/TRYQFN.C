/* TRYQFN.C    Demonstration of use of QFN.C module to qualify filenames.
   PC Magazine * Ray Duncan * Feb 14, 1989 */

#include <stdio.h>

extern char *qfn(char *);

main(int argc, char *argv[])
{
    char buffer[80];                /* buffer for user input */
    char *p;                        /* receives ptr from qfn */

    while(1)                        /* do until empty line */
    {
                                    /* prompt user for filename */
        printf("\nEnter filename:        ");

        gets(buffer);               /* read in filename */

        if(buffer[0] == 0) break;   /* exit if no entry */

        p = qfn(buffer);            /* else qualify filename */

        if(p != NULL)               /* display filename or error message */

            printf("\nThe full pathname is:  %s\n",p);

        else printf("\nBad filename!\n");
  } 
}
