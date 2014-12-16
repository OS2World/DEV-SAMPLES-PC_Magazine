

/* WRITEVAR.C - Writes new variable contents back to the executable file */
/* Compile with -DTC -O -w -I$(INCLUDE -L$(LIB) -Z -lt -mt */

#include<stdio.h>
#include<string.h>
#include<errno.h>

#define STORAGE_SIZE 80
char storage[STORAGE_SIZE] = "Hello, out there!";
char storage2[STORAGE_SIZE];

int writevar(char *filename, void *var, unsigned varlen);
void main(int argc, char **argv);

void main(int argc, char **argv)
	{
	printf("Storage=%s\n",storage);
	printf("Enter new value and press <RETURN>\n");
	if(gets(storage2) && strlen(storage2))		/* get new values	*/
		{
		storage2[sizeof(storage)-1] = '\0';		/* force NULL terminate	*/
		strcpy(storage,storage2);		     /* update the executable */
		if(writevar(argv[0], storage, sizeof(storage)))
			printf("Storage successfully updated\n");
		else
			printf("Unable to update Storage\n");
		}
	}

int writevar(char *filename, void *var, unsigned varlen)
	{
	FILE *fp;
	long off = 0L;
	unsigned x;
	int retval = 0;

	x = (unsigned)var;		/* get address of variable	*/
	x -= 0x100;				/* adjust for PSP	*/
	off += x;				/* off now has disk offset	*/

	if(fp = fopen(filename,"r+b"))		/* open the executable	*/
		{
		if(!fseek(fp,off,SEEK_SET))		/* seek to disk offset	*/
			if(fwrite(var,1,varlen,fp) == varlen)		/* write the variable */
				retval = 1;
				fclose(fp);		/* close the file	*/
		}
	return retval;
	}

