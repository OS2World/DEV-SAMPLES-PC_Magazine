/*
    SHOWXMEM.C  Demonstrates use of GETXM and PUTXM routines
                in EXTMEM.ASM.  Prompts for a physical (linear)
                memory address, then displays 64 bytes of memory
                beginning at that address in hex and ASCII.

    Compile:    MASM /Mx /Zi EXTMEM;
                CL /Zi SHOWXMEM.C EXTMEM

    Usage:      SHOWXMEM (press <Enter>, ^Break or ^C to exit)

    Copyright (C) 1989 Ziff Davis Communications
    PC Magazine * Ray Duncan
*/

#include <stdio.h>
#include <stdlib.h>

#define BUFSIZE 64

                                    /* prototypes for EXTMEM.ASM */
extern getxm(unsigned long, char far *, unsigned);
extern putxm(char far *, unsigned long, unsigned);

main()
{   
    char buffer[BUFSIZE];           /* receives extended memory data */
    char input[80];                 /* keyboard input buffer */
    char *stopstr;                  /* receives pointer from strtoul */
    unsigned long xmemaddr;         /* linear extended memory address */
    int i;                          /* scratch variable */

    while(1)
    {                               /* get & convert starting address */
        printf("\n\nEnter extended memory address (hex): ");
        gets(input);            
        if(input[0] == 0) break;
        xmemaddr = strtoul(input, &stopstr, 16);

        if(xmemaddr > 0xffffff) /* check if address too large */
        {
            printf("\nInvalid extended memory address!");
            continue;
        }

        xmemaddr &= 0xfffff0;       /* round down to paragraph boundary */

                                    /* fetch from extended memory */
        if(getxm(xmemaddr, buffer, BUFSIZE))
        {
            printf("\nExtended memory read error!");
            continue;
        }
                                    /* display heading and data */
        printf("\n\t  0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F");
        for(i = 0; i < BUFSIZE; i += 16) dump16(buffer+i, xmemaddr+i);
    }
}

/*
    Display 16 bytes from local buffer at specified starting address
*/
dump16(char *buffer, unsigned long xmemaddr)
{   
    int i;                          /* index to local buffer */

    printf("\n%06lX\t", xmemaddr);  /* extended memory address */

    for(i = 0; i < 16; i++)         /* display hex for each byte */
        printf(" %02X", (unsigned char) buffer[i]);

    printf("  ");                   
    for(i = 0; i < 16; i++)         /* display ASCII for each byte */
    {   
        if(buffer[i] < 32 || buffer[i] > 126) putchar('.');
        else putchar(buffer[i]);
    }
} 
