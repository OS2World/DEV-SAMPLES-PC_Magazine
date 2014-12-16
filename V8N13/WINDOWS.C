
#define MAX_WINDOWS 10
#define BUFFER_SIZE 10000

typedef unsigned char BYTE;

struct WindowData{
	BYTE Row;
	BYTE Col;
	BYTE Height;
	BYTE Width;
} WinData[MAX_WINDOWS];

int WinNum = -1;					/* Index into WinData array */
unsigned ScreenCols;				/* Number of columns displayed */
unsigned far *VideoSeg;				/* Pointer to video segment */
unsigned BufferPtr = 0;				/* Buffer index */
unsigned WinBuffer[BUFFER_SIZE];	/* Buffer for saved screen data */

main()	/* Illustrates the use of window functions */
{
	InitWindow();

	if (PushWindow(0, 0, 8, 40)) {
		printf("Overflow error\n");
		exit(1);
	}

	/*---------------------------------------*/
	/* Insert code to fill first window here */
	/*---------------------------------------*/

	if (PushWindow(10, 15, 10, 50)) {
		printf("Overflow error\n");
		exit(1);
	}

	/*----------------------------------------*/
	/* Insert code to fill second window here */
	/*----------------------------------------*/

	if (PopWindow()) {
		printf("Underflow error\n");
		exit(1);
	}

	if (PopWindow()) {
		printf("Underflow error\n");
		exit(1);
	}
}

InitWindow(void)
{
	if (*(unsigned far *) 0x00400063 == 0x3B4)
		VideoSeg = (unsigned far *) 0xB0000000;
	else
		VideoSeg = (unsigned far *) 0xB8000000;
	ScreenCols = *(unsigned far *) 0x0040004A;
}

PushWindow(BYTE Row, BYTE Col, BYTE Height, BYTE Width)
{
	unsigned Offset;
	BYTE i, j;

	if (WinNum == 9)		/* Check for overflow */
		return(1);
	if ((BufferPtr + Height * Width) > BUFFER_SIZE)
		return(2);

	WinData[++WinNum].Row = Row;	/* Save window parameters */
	WinData[WinNum].Col = Col;
	WinData[WinNum].Height = Height;
	WinData[WinNum].Width = Width;

	Offset = (Row * ScreenCols) + Col;
	for (i=0; i<Height; i++)
		for (j=0; j<Width; j++)
			WinBuffer[BufferPtr++] = *(VideoSeg + Offset + 
										(i*ScreenCols) + j);

	return(0);
}

PopWindow(void)
{
	unsigned Offset;
	int i, j;

	if (WinNum == -1)		/* Check for undeflow */
		return(1);

	Offset = (WinData[WinNum].Row * ScreenCols) + WinData[WinNum].Col;
	for (i=WinData[WinNum].Height-1; i>-1; i--)
		for (j=WinData[WinNum].Width-1; j>-1; j--)
			*(VideoSeg + Offset + (i*ScreenCols) + j) = 
				WinBuffer[--BufferPtr];

	WinNum--;
	return(0);
}

