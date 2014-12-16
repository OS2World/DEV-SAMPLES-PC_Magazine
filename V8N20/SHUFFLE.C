

/* SHUFFLE.C - rearranges a given set of specific objects - in this
               case a deck of playing cards - into random order. This 
               illustrates the proper use of the subroutine shuffle().
*/

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define N 52        // number of objects in the set - 52 for a deck of cards
#define NMAX 100    /* maximum number that shuffle() can rearrange: must be
                       greater than or equal to N */

typedef struct {
                int word1;
                int word2;
                } dword;     // structure needed by shuffle()

char *suit[4] = {"spades", "hearts", "clubs", "diamonds"};
char *value[13] = {"ace", "two", "three", "four", "five", "six", "seven",
                   "eight", "nine", "ten", "jack", "queen", "king"};

void shuffle(int, int *, unsigned int);      // function prototypes
int compare(dword *, dword *);

main()
{
     int i;
     int a[N];           // one-dimensional array to be shuffled
     unsigned int see;   // arbitrary integer to seed rand()
     long tval;

     seed = (unsigned int) (time(&tval) % 65536); // random seed based on time
     shuffle(N, a, seed);
     for(i=0; i<N; i++)
          printf("\n%s of %s", value[a[i] % 13], suit[a[i]/13]);
}


/* shuffle() - This is the heart of the program. It assigns a one-dimensional
               aray of integers, whose beginning address is base, all the
               values from 0 to N-1 in random order. The seed is arbitrary 
               and is used only to have repeated calls to shufle() return
               different sequences.
*/

void shuffle(int n, int *base, unsigned int seed)
{
     int i;
     dword RandomIndex[NMAX];     /* "dword" structure randomizing vehicle.
                                     NMAX is the maximum possible number of
                                     objects in the set, and must be
                                     initialized by the user. */

     srand(seed);                 // initialize rand()
     for(i=0; i<n; i+)            // initialize RandomIndex
          {
            RandomIndex[i].word1 = rand();  // first part is a random number
            RandomIndex[i].word2 = i;       // second starts as a
           }

     qsort(RandomIndex, n, length, compare); /* sort first part only, but
                                                "drag" second parts along */

     for(i=0; i<n; i++)
          *base+i) = Randomndex[i].word2;    /* assign array to newly
                                                randomized second parts */
}


/* compare() - routine needed by qsort() to compare the values of
               dwords according to their first parts only */

compare(dword *elem1, dword *elem2)
{
     return(elem1->word1 - elem2->word1);
}

