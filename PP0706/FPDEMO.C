/*  
        fpdemo.c --- demonstrates use of printf to format
                     pretty tables of floating point numbers
        PC Magazine - Ray Duncan
*/

#include <stdio.h>
#include <stdlib.h>

main(int argc, char *argv[])
{  
   int i,j;                             /* some integer variables */
   double f;                            /* floating point variable */

   printf("\n\nPrintf floating point demo\n\n\t");

   for(i=1; i<11; i++)                  /* print column numbers */
      printf("%7d", i);

   for(i=1; i<21; i++)
   {  printf("\n%2d\t", i);             /* print row numbers */
      for(j=1; j<11; j++)
      {  f=(double) j / (double) i;     /* type cast and divide */
         printf("%7.3f", f);            /* display results */
      }
   }
}
