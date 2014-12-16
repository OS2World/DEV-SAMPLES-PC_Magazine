/****************************************************************************
*   PCMANAGE - Compresses files not accessed within a certain time frame
*
*	Copyright (c) 1989 by Ziff Communications Co.
*       Program by Ross M. Greenberg
****************************************************************************/

/*********
**			Standard Include Files
**********/

#include	<stdio.h>
#include	<dir.h>
#include	<dos.h>
#include	<fcntl.h>
#include	<stat.h>
#include	<string.h>
#include	<conio.h>
#include	<io.h>

#define	FALSE	0
#define	TRUE	!FALSE
#define	ESCAPE	0x1b
#define min(a,b) ((a) < (b) ? (a) : (b))
#define max(a,b) ((a) > (b) ? (a) : (b))

/*********
**			Define the Box character set
**********/

#define	UPPER_LEFT	0xd5
#define	UPPER_RIGHT	0xb8
#define	LOWER_LEFT	0xd4
#define	LOWER_RIGHT	0xbe
#define	HORIZONTAL	0xcd
#define	VERTICAL	0xb3
#define	LEFT_CROSS	0xc6
#define	RIGHT_CROSS	0xb5

/*********
**		Turn DCOMPRES On or OFF
**********/

#define	ON	0
#define	OFF	1


#define	RESET	-2
#define	CLOSE	-3

/*********
**		Status Byte in the Index File
**********/

#define	NORMAL		0
#define	COMPRESSED	1
#define	DELETED		2
#define	SKIP		3
#define	TESTING		4
#define	ERROR		5
#define	LOW		6

#define	MAX_FLEN	14
#define	MAX_PLEN	64
#define	MAX_DISK	3

#define	MAX_FILES	100
#define	TBUF_SIZE	128

/*********
**		Structure of the the Index file
**********/
struct	INDEX
	{
		int		fname_len;
		char		filename[MAX_FLEN];
		unsigned	left_ptr;
		unsigned	right_ptr;
		struct		date	da;
		struct		time	ti;
		char		status;
		char		access_cnt;
	};

/*********
**		Don't separate these next two fields
**********/
int		num_files;
char		path_name[MAX_PLEN + MAX_FLEN];
struct		INDEX	*index;


char		only_dir[MAX_PLEN];
char		*screen;
int		days;
int		min_percent;
int		min_bytes;
int		install_flag;
int		install_window;

#define	EMPTY	-1
#define	IN_TABLE	-1


/*********
**		The actual code table
**********/
struct	TABLE
	{
		int	code;
		char	suffix;
	};

#define	MAX_CODE	4096
#define	RESET_CODE	(MAX_CODE - 1)

struct	TABLE	*table;
int		reset;
int		codesused;
unsigned	oldcode;

int		*hashtable;
long		total = 0;
long		in_cnt = 0;
long		out_cnt = 0;
long		total_in_cnt = 0;
long		total_out_cnt = 0;
int		percent;
int		dirty_bit;
int		scan_cnt;
int		tot_examine;
int		tot_skipped;
int		tot_compressed;
int		tot_bypassed;
int		tot_files;
int		tot_directories;



char		*copyright = "PCMANAGE, Copyright (c) 1989 by Ziff Communications Co. \
All Rights Reserved.";
char		*program = "Program by Ross M. Greenberg";
char		start_path[MAX_PLEN + MAX_DISK];

int		exclude_cnt = 3;
char		*exclude_list[MAX_FILES] =
			{"*INDEX.CMP",
			 "*DCOMPRES.COM",
			 "*PCMANAGE.EXE"
			};


/*********
**		Code Starts Here
**********/


void center(int row, char *ptr)
{
	gotoxy(40 - strlen(ptr)/2, row);
	cprintf(ptr);
}

void draw_screen()
{
char	tmp_buf[TBUF_SIZE];
int	i;
char	*ptr;

	textcolor(WHITE);
	textbackground(BLUE);
	clrscr();
	center(1, copyright);		/* the Ziff copyright notice */
	center(2, program);		/* Program ID and author */
	ptr = tmp_buf;
	for (i=1; i < 80 ; i++)
		*ptr++ = HORIZONTAL;	/* make a horizontal line */
	tmp_buf[0] = UPPER_LEFT;	/* fill in the corners */
	tmp_buf[79] = UPPER_RIGHT;
	tmp_buf[80] = 0;
	gotoxy(1,3);
	cprintf(tmp_buf);		/* top line */
	tmp_buf[0] = LOWER_LEFT;	/* make it a bottom line */
	tmp_buf[79] = LOWER_RIGHT;
	gotoxy(1, 24);
	cprintf(tmp_buf);		/* and draw it */

	for (i = 4 ; i < 24 ; i++)	/* draw down each side */
	{
		gotoxy(1, i);
		putch(VERTICAL);
		gotoxy(80, i);
		putch(VERTICAL);
	}

	tmp_buf[0] = LEFT_CROSS;	/* cross boxes */
	tmp_buf[79] = RIGHT_CROSS;
	gotoxy(1, 7);
	cprintf(tmp_buf);		/* horizontal line */
	gotoxy(1, 9);
	cprintf(tmp_buf);		/* horizontal line */
	if	(!install_flag)
	{
		gotoxy(2,10);
		cprintf("  Filename     Last Access    Status     Filename     Last Access    Status");
		gotoxy(1, 16);
		cprintf(tmp_buf);		/* horizontal line */

		gotoxy(2, 4);
		cprintf("Only files without access in the past %d days and with a compression ratio", days);
		gotoxy(2,5);
		cprintf("of at least %d%% and %d bytes will be compressed.", min_percent, min_bytes);
	}
	else
	{
		gotoxy(2,4);
		cprintf("Accessing all files.");
	}
	gotoxy(2,6);
	cprintf("Starting path is:  %s", start_path);

}

/*********
**		Draw 'N' graphics characters across
**********/
void bar_chart(int num_bars, char bar_char)
{
char	tmp_buf[TBUF_SIZE];
char	*ptr = tmp_buf;

	if	(!num_bars)
		return;
	num_bars = min(num_bars, 50);
	while(num_bars--)
		*ptr++ = bar_char;
	*ptr = 0;
	cprintf(tmp_buf);
}

/*********
**	Open the exclude file and load the contents into an array.
**	Maximum of 20 members in the arrray, three already populated.
**********/
void do_exclude()
{
FILE	*fp;
char	tmp_buf[TBUF_SIZE];
char	*ptr;

	if	((fp = fopen("C:\\DCOMPRES.EXL", "r")) == (FILE *)NULL)
		return;
	while	(fgets(tmp_buf, TBUF_SIZE, fp) && exclude_cnt < 20)
	{
        	ptr = (char *)malloc(strlen(tmp_buf) + 1);
                tmp_buf[strlen(tmp_buf) - 1] = 0;
		strcpy(ptr, tmp_buf);
	 	strupr(ptr);
                exclude_list[exclude_cnt++] = ptr;
	}
	fclose(fp);
}

/*********
**	Tell DCOMPRES to turn on or off.
**********/

void sq_toggle(int flag)
{
union	REGS	regset;

	regset.h.ah = 0xdc;
	regset.x.dx = flag;
	intdos(&regset, &regset);
}


/*********
**	If a control C or Break is hit, turn DCOMPRES back on
**********/
void c_break(void)
{
	printf("Control-C Hit....Aborting\n");
	sq_toggle(ON);
	exit(1);
}


char	*do_stat(int s)
{
	switch	(s)
	{
		case	NORMAL:
			return("Normal    ");

		case	DELETED:
			return("Deleted   ");

		case	COMPRESSED:
			return("Compressed");

		case	ERROR:
			return("Error     ");

		case	TESTING:
			return("Testing   ");

		case	SKIP:
			return("Skipping  ");

		case	LOW:
			return("No Compres");

		default:
			return("Unknown   ");
	}
}

/*********
**	Process each entry in the index file
**
**  1.  Slide down the tree as left as you can via recursion.
**  2.  When the left end of a branch is hit, output the file stuff
**      formatted pretty.
**  3.  If not a NORMAL file, skip it.
**  4.  Otherwise, check if "outdated". Skip if not.
**  5.  Otherwise, do the compression on the file.
**  6.  Output the status when starting, update it when done.
**  7.  Process the rest of the tree - the righthand side.
**  9.  Return
**********/

void
scan_files(int cnt)
{
int	xx;
int	yy;
int	stat;


	if	(kbhit())
	{
		if	(getch() == ESCAPE)
			return;
	}
	cnt--;
	if	(index[cnt].left_ptr)
	{
		 scan_files(index[cnt].left_ptr);
	}
	cprintf("%-12s %02d:%02d %02d/%02d/%02d ",
		index[cnt].filename,
		index[cnt].ti.ti_hour,
		index[cnt].ti.ti_min,
		index[cnt].da.da_mon,
		index[cnt].da.da_day,
		index[cnt].da.da_year - 1900);
	xx = wherex();
	yy = wherey();
	cprintf("%s", do_stat(index[cnt].status));


	if	(index[cnt].status == COMPRESSED)
		tot_compressed++;
	else
	if	(index[cnt].status == LOW)
		tot_bypassed++;
	else
	if	(index[cnt].status == NORMAL &&
			check_date(&index[cnt]) >= days)
	{
		gotoxy(xx, yy);
		cprintf(do_stat(TESTING));
		stat = 	compress(&index[cnt]);
		window(2, 11, 79, 15);
		gotoxy(xx, yy);
		cprintf("%s", do_stat(stat));
        }

	if	(!(++scan_cnt % 2))
		putch('\n');
	else
		putch(VERTICAL);

	if	(index[cnt].right_ptr)
	{
		scan_files(index[cnt].right_ptr);
	}
	return;
}



/*********
**	Process the index file
**
**  1.  Read the number of files in the index
**  2.  Read the directory path of the index in.
**  3.  If no match, then something weird happened. Return.
**  4.  Read the whole index file into memory
**  5.  Call scan_files the index file entries.
**  6.  If there was a change made, then write the index back out.
**  7.	Close the index file and return.
**
**********/


void do_index(char *dir)
{
int	fd;
char	filename[MAX_PLEN+MAX_FLEN];
int	stat;
char	tmp;
char	tmp_buf[TBUF_SIZE];
int	attrb;

	window(1, 1, 80, 25);
	sprintf(filename, "%s\\INDEX.CMP", dir);
	attrb = _chmod(filename, NULL);
	_chmod(filename, 1, attrb & ~FA_RDONLY);
	if	((fd = open(filename, O_RDWR | O_BINARY)) == -1)
		return;

	_read(fd, &num_files, 2);
	_read(fd, &path_name, MAX_PLEN + MAX_FLEN);
	strcpy(only_dir, dir);
	strcat(only_dir, "\\");
	if	(strncmp(dir, path_name, strlen(dir)))
		return;

	_read(fd, index, sizeof(struct INDEX) * 100);
	gotoxy(2, 8);
	sprintf(tmp_buf, "%d Files in %s", num_files, dir);
	cprintf("%-78.78s", tmp_buf);
	dirty_bit = FALSE;
	window(2, 11, 79, 15);
	clrscr();
	gotoxy(1,1);
	scan_cnt = 0;
	scan_files(1);
	if	(dirty_bit)
        {
		lseek(fd, (long)(2 + MAX_PLEN + MAX_FLEN), 0);
		_write(fd, (char *)index, sizeof(struct INDEX) * 100);
	}
	close(fd);
	_chmod(filename, attrb);
}


/*********
**	Process a directory
**
**  1.  Do the index file, if any, in the argument directory
**  2.  Create a template for FindFirst and FindNext calls
**  3.  Find the first file.  If none match, then return
**  4.  Make sure we're not processing `.' or `..' as a file.
**  5.  If a directory, then process it
**  6.  Go on to next file.  When no more files, return
**
**********/
do_dir(char *root)
{
struct	ffblk	ffblk;
int	done;
char	template[MAX_PLEN];
char	dir_template[MAX_PLEN];
char	tmp_dir[MAX_PLEN + MAX_FLEN];
int	install_fd;

	if	(exclude(root))
		return(TRUE);
	if	(!install_flag)
		do_index(root);
        else
	{
		tot_directories++;
		if	(!install_window)
		{
			install_window = TRUE;
			window(2, 10, 79, 23);
		}
        }

	strcpy(dir_template, root);
	strcat(dir_template, "\\");
	sprintf(template, "%s*.*", dir_template);
	done = findfirst(template, &ffblk, FA_DIREC );
	while	(!done)
	{
		if	(kbhit())
		{
			if	(getch() == ESCAPE)
				return(FALSE);
		}
		if	(strncmp(ffblk.ff_name, ".", 1) && strncmp(ffblk.ff_name, "..", 2))
		{
			sprintf(tmp_dir, "%s%s", dir_template, ffblk.ff_name);
			if	(ffblk.ff_attrib & FA_DIREC)
			{
				if	(!do_dir(tmp_dir))
					return(FALSE);
			}
			else
			if	(install_flag)
			{
				if	(!exclude(tmp_dir))
				{
					if	((install_fd = open(tmp_dir, O_RDONLY)) != -1)
					{
						tot_files++;
						cprintf("Accessing: %s\n", tmp_dir);
						close(install_fd);
					}
				 }
			}
		}
		done = findnext(&ffblk);
	}
	return(TRUE);
}

/*********
**	Stuff a code into the buffer
**
**  1.  If a reset, initialize everything, return
**  2.  If this is a `normal' code entry (we're not closing the file),
**      create the code as a nibble and a byte or byte and a nibble.
**  3.  If we're closing the file, or the buffer is full, then close the
**      buffer if required, output the buffer and start to reset.
**
**********/

void stuff(int fd, unsigned code, int flag)
{
static	char		buffer[750];		/*enough for 500 entries*/
static	char		*buffer_end = buffer + 750;
static	char		*p = buffer;
static	unsigned 	hold;

	if	(flag == RESET)
	{
		buffer_end = buffer + 750;
		p = buffer;
		hold = 0;
		return;
	}

	if	(flag == NORMAL)
	{
		if	(!(hold & 0x100))
		{
			*p++ = (code & 0xff0) >> 4;
			hold = (code & 0xf) | 0x100;
			out_cnt++;
		}
		else
		{
			hold &= 0xf;
			*p++ = (hold << 4) | ((code & 0xf00) >> 8);
			*p++ = code & 0xff;
			hold = 0;
			out_cnt += 2;
		}
	}

	if	(flag == CLOSE || p >= buffer_end)
	{
		if	(hold & 0x100)
		{
			*p++ = (hold << 4);
			*p = 0;
		}
		_write(fd, &buffer, p - buffer);
		p = buffer;
	}
}

/*********
**	Return the next character from the input file
**
**  1.  If a reset, initialize everything, return
**  2.  Allocate bufer memory for the read if we haven't already
**  3.  Read the input file in big chunks as required, returning with
**      FALSE on EOF, else TRUE.  Charaacter de-referenced via argument
**      pointer.
**
**********/

get_char(int fd, char *ptr)
{
static	unsigned	cnt = 0;
static	char	*p;
static	char	*ptr2 = NULL;
static  int	size_mem;

	if	(fd == RESET)
	{
		cnt = 0;
		return(FALSE);
	}
	if	(!ptr2)
	{
        	size_mem = min(coreleft() - 5 * 1024, 32760);
		ptr2 = (char *)malloc(size_mem);
		p = ptr2;
	}

	if	(!cnt)
	{
		cnt = _read(fd, ptr2, size_mem);
		if	(!cnt)
			return(FALSE);
		p = ptr2;
	}
	*ptr = *p++;
	cnt--;
	return(TRUE);
}

/*********
**	Initialize the table, the "used" counter, etc.
**********/

void init_table(void)
{
int	i;

	for(i = 0; i < 256 ; i++)
	{
		table[i].code = 0;
		table[i].suffix = (char)i;
	}
	codesused = 256;
	for (i = 0 ; i < MAX_CODE ; i++)
		hashtable[i] = EMPTY;
}

void do_usage()
{
	printf(copyright);
	printf("\n\nUsage:\nPCMANAGE -i -d<days> -c<percent> -b<byte_cnt> -p<path>\n\n");
	printf("      -i:         access all files in the specified directory path.\n");
	printf("                  use only the first time you run PCMANAGE.\n\n");
	printf("      <days>:     Compress files that have not been accessed\n");
	printf("                  in <days> or longer.  Default is 7 days.\n\n");
	printf("      <percent>:  Only compress files where the compression\n");
	printf("                  ratio is greater than <percent>. The\n");
	printf("		  default is set for 5%%\n");
	printf("      <byte_cnt>: Only compress files saving more than <byte_cnt>\n");
	printf("                  bytes.  Default is one cluster.\n");
	printf("      <path>:     the fully qualified base directory name\n");
	printf("                  to recurse through.\n");
}


/*********
**	Main program
**
**  1.  Set up default values
**  2.  Process options and arguments
**  3.  Process the exclude file
**  4.  Paint screen and allocate memory
**  5.  Set Control-C handler and turn off DCOMPRES
**  6.  -->Process the directory heirarchy
**  7.  Turn DCOMPRES back on
**  8.  Print stats and exit
**********/

void main(int argc, char *argv[])
{
int	cnt;
struct	fatinfo fi;
int	orig_x,
	orig_y;

	strcpy(start_path, "C:");
	days = 7;
	min_percent = 10;
	cnt = 1;

	while	(argc && argv[cnt][0])
	{
		if	(argv[cnt][0] != '-' && argv[cnt][0] != '/')
                {
			do_usage();
			exit();
		}
                switch	(toupper(argv[cnt][1]))
		{
			case	'D':
				days = atoi(&argv[cnt][2]);
				if	(days < 1)
				{
					printf("Days must be more than one!\n");
					exit(1);
				}
				break;

			case	'C':
				min_percent = atoi(&argv[cnt][2]);
				if	(min_percent < 5)
				{
					printf("Minimum percentage must be greater than 5%%\n");
					exit(1);
				}
				break;

			case	'P':
				strncpy(start_path, &argv[cnt][2], 67);
				if	(strlen(start_path) == 1)
					strcpy(start_path, "");
                                break;

			case	'B':
				min_bytes = atoi(&argv[cnt][2]);
				if	(min_bytes < 1024)
				{
					printf("Minimum compression count must be greater than 1024 bytes\n");
					exit(1);
				}
				break;

			case	'I':
				install_flag = TRUE;
				break;

			default:
				do_usage();
				exit(1);
                }
                cnt++;
	}

	if	(!min_bytes)
	{
		getfat(toupper(*start_path) - '@', &fi);
		min_bytes = fi.fi_sclus * fi.fi_bysec;
	}

	index = (struct INDEX *)calloc(100, sizeof(struct INDEX));
	table = (struct TABLE *)calloc(MAX_CODE, sizeof(struct TABLE));
	hashtable = (int *)calloc(MAX_CODE, sizeof(int));
	screen = (char *)calloc(80 * 2 * 25, sizeof(char));

	gettext(1, 1, 80, 25, screen);
	orig_x = wherex();
	orig_y = wherey();
	do_exclude();
	draw_screen();

	ctrlbrk(c_break);
	if	(!install_flag)
		sq_toggle(OFF);
	do_dir(start_path);
	sq_toggle(ON);
	if	(!install_flag)
	{
		window(2, 17, 79, 23);
		clrscr();
		if	(total_in_cnt)
			percent = (int)((100 * (total_in_cnt - total_out_cnt))/total_in_cnt);
		cprintf("Total compression of %ld bytes, representing a %d%% compression ratio.\n",
			total_in_cnt - total_out_cnt, percent);
		cprintf("Total of %d files examined, %d skipped, %d compressed, %d bypassed.\n",
			tot_examine, tot_skipped, tot_compressed, tot_bypassed);
	}
	else
	{
		window(2, 10, 79, 23);
		clrscr();
		cprintf("A total of %d files accessed in %d directories examined\n", tot_files, tot_directories);
	}
	while	(kbhit())
		getch();
	cprintf("\n\nPress a key to continue.");
	getch();
	window(1,1, 80, 25);
	puttext(1, 1, 80, 25, screen);
	gotoxy(orig_x, orig_y);
	exit(0);
}



/*********
**	Make a hash out of code and suffix
**********/


unsigned make_hash(unsigned c1, unsigned c2)
{
	return((c1 ^ (c2 << 3)) & 0xfff);
}


/*********
**	The guts of LZW
**
**  1.  Make a hash out of the last code and current character
**  2.  Find an empty spot in the hashtable or find a matching entry
**  3.  If there's room in the table, add this code-suffix combination
**  4.  Save the code and return the new code.
**********/

unsigned get_code(unsigned char c)
{
int	i;
unsigned	output;
int	idx;
unsigned int	hash = make_hash(oldcode, (unsigned)c);

	idx = hashtable[hash];
	while (idx != EMPTY)
	{
		if	(table[idx].code == oldcode && table[idx].suffix == c)
		{
			oldcode = idx;
			return(IN_TABLE);
		}
		hash += 101;
		hash %= (MAX_CODE);
		idx = hashtable[hash];
	}

	output = oldcode;

	if	(codesused < MAX_CODE - 1)
	{
		table[codesused].code = oldcode;
		table[codesused].suffix = c;
		hashtable[hash] = codesused;
		codesused++;
	}
	oldcode = (unsigned)c;
	return(output & 0x0fff);
}

/*********
**	LZW main routine
**
**  1.  If the file is on the exclude list, return without processing
**  2.  Open the file and get the file length
**  3.  Open the scratch file and write our tag.  The tag starts with an
**      INT 20, an exit instruction in case a DCOMPRES file is run without
**      DCOMPRES running, no system hang.
**  4.  Initialize everything and read the first character from the file
**  5.  For each character in the file: if the character and last code
**      are already in the table, get the next character and try again.
**      If there isn't room in the table to stuff the new combination,
**      output a reset code, reset the table and continue.
**  6.  Print out pretty stuff when enough data has been processed
**  7.  When finished with the input character, output the last code
**  8.  Check the compression ratios.  If enough, remove the original
**      input file, reset the status byte on this file's index entry.
**      Otherwise, simply remove the temp file.
**  9.  Return
**********/

compress(struct INDEX *ip)
{
char	fname[MAX_PLEN + MAX_FLEN];
char	tmp_name[MAX_PLEN + MAX_FLEN];
int	fd1;
int	fd2;
char	c;
unsigned	tmp_code;
long	file_len;
int	each_char;
struct	ftime	ft;

	if	(exclude(ip->filename))
	{
		tot_skipped++;
		return(SKIP);
        }
	tot_examine++;

	window(2, 17, 79, 23);
	clrscr();
	gotoxy(2,1);
	cprintf("%d out of %d files processed. Total %d%% compression, %ld bytes saved\n",
		tot_examine + tot_skipped,
		num_files,
                total_in_cnt ?
		 (int)((100 * (total_in_cnt - total_out_cnt))/total_in_cnt) : 0,
		total_in_cnt - total_out_cnt);

	in_cnt = out_cnt = 0L;
	sprintf(fname, "%s%s", only_dir, ip->filename);
	sprintf(tmp_name, "%s%s", only_dir, "COMPRESS.$$$");
	if	((fd1 = open(fname, O_RDONLY | O_BINARY)) == -1)
	{
		cprintf("??Can't open: %s\n", fname);
		return(ERROR);
	}
	getftime(fd1, &ft);
	file_len = filelength(fd1);
	each_char = max((int)(file_len / 50L), 1);
	unlink(tmp_name);
	if	((fd2 = open(tmp_name, O_CREAT | O_RDWR | O_BINARY, S_IREAD | S_IWRITE)) == -1)
	{
		cprintf("??Can't open: %s\n", tmp_name);
		close(fd1);
		return(ERROR);
	}
	_write(fd2, "\xcd\x20PCOMPRES", 10);
	init_table();
        stuff(NULL, NULL, RESET);
        get_char(RESET, NULL);
	reset = 0;


	get_char(fd1, &c);
	oldcode = c;
	in_cnt = 1;
	while (get_char(fd1, &c))
	{
		in_cnt++;
		if	((tmp_code = get_code(c)) != IN_TABLE)
		{
			stuff(fd2, tmp_code, NORMAL);
			if	(codesused == RESET_CODE)
			{
				stuff(fd2, RESET_CODE, NORMAL);
				init_table();
				reset++;
			}
		}
		if	(!(in_cnt % each_char))
		{
			gotoxy(2, 3);
			percent = (int)((100 * in_cnt)/file_len);
			cprintf("Compressing: %s. %2.2d%% Complete, %u Codes Used", fname, percent, codesused + (reset * MAX_CODE));
			percent = (int)(100 - (100 * out_cnt)/in_cnt);
			gotoxy(2, 4);
			cprintf("Compression of %2.2d%%, %u Bytes Saved.\n", percent, in_cnt - out_cnt );
			gotoxy(2, 6);
			cprintf(" Input Bytes: (%7.7ld)", in_cnt);
			bar_chart((int)(in_cnt / (long)each_char), 0xb1);
			gotoxy(2, 7);
			cprintf("Output Bytes: (%7.7ld)", out_cnt);
			bar_chart((int)(out_cnt / (long)each_char), 0xb2);
		 }
	}
/***/
	stuff(fd2, oldcode, FALSE);
	stuff(fd2, NULL, CLOSE);
	in_cnt++;
	percent = (int)(100 - (100 * out_cnt)/in_cnt);
	gotoxy(2, 10);
	close(fd1);

	total_in_cnt += in_cnt;
	if	(percent >= min_percent && ((in_cnt - out_cnt) > (long)min_bytes))
	{
		ip->status = COMPRESSED;
		dirty_bit = TRUE;
		setftime(fd2, &ft);
		close(fd2);
		unlink(fname);
		rename(tmp_name, fname);
		total += (in_cnt - out_cnt);
		tot_compressed++;
		total_out_cnt += out_cnt;
		return(COMPRESSED);
	}
	else
	{
		ip->status = LOW;
		dirty_bit = TRUE;
		close(fd2);
		unlink(tmp_name);
		tot_bypassed++;
		total_out_cnt += in_cnt;
		return(LOW);
	}
}

check_date(struct INDEX *ip)
{
long	time1 = dostounix(&ip->da, &ip->ti);
long	time2;
long	dtime;

	time(&time2);
	dtime = (time2 - time1)/(long)(60L * 60L * 24L);
	return((int)dtime);
}

/*********
**	Check a file against a pattern in the exclude file.
**********/
exclude(char *fname)
{
int	exclude_idx;
char	*ptr;
char	*ptr2;

 	strupr(fname);
	for(exclude_idx = 0 ; exclude_idx < exclude_cnt ; exclude_idx++)
	{
		ptr2 = exclude_list[exclude_idx];
		ptr = fname;
		while (*ptr)
		{
			if	(*ptr == *ptr2 || *ptr2 == '?')
                	{
				ptr2++;
				ptr++;
				continue;
			}
			else
			if	(*ptr2 == '*')
			{
                         	ptr2++;
				if	(!*ptr2)
                                	return(TRUE);
				else
				{
					while (*ptr && *ptr != *ptr2)
						ptr++;
					if (!*ptr)
						break;
				}
			}
			else
				break;
                }
		if	(!*ptr2)
			return(TRUE);
	}
	return(FALSE);
}

