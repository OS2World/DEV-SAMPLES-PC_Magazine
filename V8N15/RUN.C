

/* RUN.C */
/* Compile with these options if QuickC: /W3 /Zp /Ox /I$(INCLUDE) /DMSC */
/* Compile with these options if Turbo C: -DTC -O -w -I$(INCLUDE) -L$(LIB) */

#include <stdio.h>
#include <process.h>
#include <string.h>

#if defined(MSC)
#include <malloc.h>
#endif

#if defined(TC)
#include <alloc.h>
#endif

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>

/*
#include <sys\types.h>
#include <sys\stat.h>
*/

#include <io.h>

void    make_command(char *token);
int     IsCommandCommand(char *command);
void    RunProgram(char *command);
void    NoMemoryExit(void);
void    main(int argc, char **argv);

#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif

    /* Table of Internal DOS commands */
char *Commandcoms[] =
{
	"CD","CHDIR","CLS","COPY","CTTY","DATE","DEL","DIR","ECHO","ERASE","MD",
	"MKDIR","PATH","PAUSE", "PROMPT","RD","REN","RENAME","RMDIR","SET",
	"TIME","TYPE","VER","VOL",NULL
};

#define    DELIMETER ";"	/* semicolon delimiter */
char *wsdelim = " \\/\t\n"; /* whitespace delimiters */

char *usage = "Usage: run command;command;...\n"
              "or     run - Then enter each command followed by <RETURN>\n";
char *command_prompt = "\nCommand: ";


#define MAXCOMMANDLINE	128		/* command line size */
#define MAXCOMMANDSTACK	100		/* max commands to 'stack' */
#define MAXCOMMANDS		40		/* max command-line commands */

char *runstr[MAXCOMMANDSTACK];	/* pointers to commands     */
int runcnt = 0;

void main(int argc, char **argv)
    {
    char cmdline[MAXCOMMANDLINE+1];	/* buffer for command line */
    char *token;					/* the associated pointer */
    int n;
    cmdline[0] = '\0';
    if(argc > 1)		/* if arguments */
        {
        argv++;
        while (argc--)
            {
            strcat(cmdline, *argv++);
            strcat(cmdline, " ");
            }

            /* parse out and malloc string for each command (';' separator) */
        for(token = NULL;
				token = strtok((token ? NULL : cmdline), DELIMETER); )
            {
            make_command(token);
            if(runcnt >= MAXCOMMANDS)	/* and quit if too many */
                break;
            }
        }
    else				/* no command-line arguments*/
        {
        printf(command_prompt);

        while(strlen(gets(cmdline)) > 0)
            {
            make_command(cmdline);
            if(runcnt >= MAXCOMMANDS)	/* and quit if too many */
                break;
            printf(command_prompt);
            }
        }

        /* runcnt now has the # of commands given either way,
           and the commands are pointed to by pointers in runstr
         */
    if(!runcnt)		/* no commands given: quit */
        {
        printf(usage);
        exit(1);
        }

    for(n = 0; n < runcnt; n++)		/* process each command */
        {
        printf("\n%s\n", runstr[n]);	/* echo out the command */

        if(IsCommandCommand(runstr[n]))	/* if DOS command */
            {
            if(system(runstr[n]))		/* load COMMAND.COM to run */
                perror("run (DOS cmd)");
            }
        else
            RunProgram(runstr[n]);		/* else run as a program */

        free(runstr[n]);
        }
    exit(0);
    }

void make_command(char *token)
    {
    if(!(runstr[runcnt] = malloc(strlen(token)+1)))
        NoMemoryExit();
    
    strcpy(runstr[runcnt], token);
    runcnt++;
    }


int IsCommandCommand(char *command)
    {
    register char **p, *token;
    char temp[MAXCOMMANDLINE+1];	/* buffer for command line */
    strcpy(temp,command);
    token = strtok(temp, wsdelim);
    strupr(token);
    for(p = Commandcoms; *p; p++)
        if(!strcmp(*p, token))
            return TRUE;

    return FALSE;
    }


void RunProgram(char *command)
    {
    char *cmd_args[MAXCOMMANDS];	/* array of pointers for spawn */
    char *token;
    int arg = 2, i;
    char *batch_command = "/c";
    memset(cmd_args,0,sizeof(cmd_args));     /* clear the pointer array */
    
    cmd_args[0] = getenv("COMSPEC");
    cmd_args[1] = batch_command;
    								/* set up the arguments */
    if((token = strtok(command, wsdelim)) != NULL)
        {
        if(!(cmd_args[arg] = malloc(strlen(token)+1)))
            NoMemoryExit();
        strcpy(cmd_args[arg++], token);
        for( ; token = strtok(NULL, wsdelim); arg++)
            {
            if(!(cmd_args[arg] = malloc(strlen(token)+1)))
                NoMemoryExit();
            strcpy(cmd_args[arg], token);
            }
        }
    if(spawnvp(P_WAIT, cmd_args[2], &cmd_args[2])) /* run the program...... */
        if(cmd_args[0])
            {
            if(spawnvp(P_WAIT, cmd_args[0], cmd_args))
                perror("run (program)");
            }
        else
            printf("COMSPEC= not set in environment, cannot execute\n");

    for( i = 2; i < arg; i++)	/* free each non-NULL pointer */
        free(cmd_args[i]);
    }

void NoMemoryExit(void)
    {
    printf("\nrun: Not enough memory to proceed");
    exit(1);
    }

