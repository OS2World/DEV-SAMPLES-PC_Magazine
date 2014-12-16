
#include <stdio.h>
#include <malloc.h>

#define TRUE 1
#define FALSE 0
#define BLOCKS 20

struct avirus {
	char code[8];
	int bytes;
	unsigned long lowcrc;
	int crcs[BLOCKS];
} antivir = { "CAPRIO\xDF\0" };

main(int argc, char *argv[])
{
	printf("This shows how a program may perform a self-check at startup\n");
	printf("to protect itself from being infected by a virus.\n\n");

	switch (check(argv)) {
		case 0 :
			printf("Executable is unaltered\n");
			break;
		case 1 :
			printf("Could not find executable\n");
			break;
		case 2 :
			printf("Executable has not been PATCHed\n");
			break;
		case 3 :
			printf("Executable has been altered, possibly by a virus\n");
			exit(1);
		}		

	/*--------------------------*/
	/* Insert body of code here */
	/*--------------------------*/
}

check(char *argv[])	/* Function called to perform the CRC check */
{
	int crc;
	char *buff, *buffp;		/* Pointers to data buffer */
	int j1, j2 = 0;
	int change = FALSE;		/* TRUE if file altered */
	int rsize;			/* Amount of data read into buffer */
	long fl;			/* File length */
	FILE *fn;
	unsigned long bytecount = 0;	/* Position in file */
	unsigned long lowcrc, highcrc;	/* Position of areas patched */

	/* Open executable file for reading */
	if ((fn = fopen(argv[0], "rb")) == NULL)
		return(1);

	/* Return error code if PATCH utility hasn't been run */
	if (antivir.crcs[1] == 0 && antivir.crcs[2] == 0)
		return(2);

	/* Calculate and compare the CRC values */
	buff = calloc(antivir.bytes, sizeof(char));
	lowcrc = antivir.lowcrc + sizeof(antivir.code) + 1;
	highcrc = antivir.lowcrc + sizeof(struct avirus);

	do {
		rsize = fread (buff, sizeof(char), antivir.bytes, fn);
		buffp = buff;
		crc = 0;

		for (j1 = 0; j1 < rsize; j1++) {
			bytecount++;
			if ((bytecount >= lowcrc)  && (bytecount <= highcrc)) {
				buffp++;
				crc = crc_update (crc,'\0');
			}
			else
				crc = crc_update (crc,*(buffp++));
		}

		crc = crc_finish(crc);
		if (antivir.crcs[j2++] != crc) {
			change = TRUE;
			break;
		}

	} while (rsize == antivir.bytes);

	free(buff);
	fclose(fn);

	/* Return 0 if file is OK, 3 if it has been altered */
	if (change)
		return(3);
	else
		return(0);
}

crc_update(int crcval, char crc_char)
{
	long tmp;
	int  j1;

	tmp = ((long)crcval << 8) + crc_char;
	for (j1 = 0; j1 < 8; j1++) {
		tmp = tmp << 1;
		if(tmp & 0x01000000)
			tmp = tmp ^ 0x01800500;
	}
	return((tmp & 0x00ffff00) >> 8);
}

crc_finish(int crc)
{
	return(crc_update(crc_update(crc,'\0'), '\0'));
}



