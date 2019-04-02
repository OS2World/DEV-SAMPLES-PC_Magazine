//
// ExeLook.H -- Header File for Windows/NT version of ExeLook.C
//

#define WIN16     FALSE
#define THUMBPOS  HIWORD(wParam)

struct decodeMsg {                          // structure associates
    UINT Code;                              // messages or menu IDs
    LONG (*Fxn)(HWND, UINT, UINT, LONG); }; // with a function

struct decodeMenuID {                       // structure associates
    UINT Code;                              // menu ID with a function
    VOID (*Fxn)(VOID);                      // and a window caption
    TCHAR * Name; }; 

struct decodeUINT {                         // structure associates
    UINT Code;                              // UINTs with a string
    TCHAR * Name; };                         

typedef struct _IMAGE_IMPORT_MODULE_DIRECTORY {
    UINT ImportList;
    UINT Reserved1;
    UINT Reserved2;
    UINT ModuleName;
    UINT Reserved3;
    } IMAGE_IMPORT_MODULE_DIRECTORY, *PIMAGE_IMPORT_MODULE_DIRECTORY;

// typedefs for convenience in referring to image structures
typedef IMAGE_DOS_HEADER *                PMZHEADER;
typedef IMAGE_NT_HEADERS *                PPEHEADER;
typedef IMAGE_FILE_HEADER *               PCOFFHEADER;
typedef IMAGE_OPTIONAL_HEADER *           POPTHEADER;
typedef IMAGE_SECTION_HEADER *            PSCNHEADER;
typedef IMAGE_DATA_DIRECTORY *            PDATADIR;
typedef IMAGE_IMPORT_MODULE_DIRECTORY *   PMODULEDIR;
typedef IMAGE_IMPORT_BY_NAME *            PIMPORTNAME;
typedef IMAGE_RESOURCE_DIRECTORY *        PRSRCDIR;
typedef IMAGE_RESOURCE_DIRECTORY_ENTRY *  PRSRCDIRENTRY;
typedef IMAGE_RESOURCE_DIRECTORY_STRING * PRSRCDIRSTR;
typedef IMAGE_RESOURCE_DATA_ENTRY *       PRSRCDATAENTRY;
typedef IMAGE_EXPORT_DIRECTORY *          PEXPORTDIR;

// predefined resource types (from RESFMT.DOC on CompuServe)
// (Some RT_ values are defined in WINUSER.H but they cause 
// problems because of the MAKEINTRESOURCE macro)
#define RSRC_NEWRESOURCE    0x2000
#define RSRC_ERROR          0x7fff
#define RSRC_CURSOR         1
#define RSRC_BITMAP         2
#define RSRC_ICON           3
#define RSRC_MENU           4
#define RSRC_DIALOG         5
#define RSRC_STRING         6
#define RSRC_FONTDIR        7
#define RSRC_FONT           8
#define RSRC_ACCELERATOR    9
#define RSRC_RCDATA         10
#define RSRC_MESSAGETABLE   11
#define RSRC_GROUP_CURSOR   12 
#define RSRC_GROUP_ICON     14
#define RSRC_VERSION        16
#define RSRC_DLGINCLUDE     17
#define RSRC_NEWBITMAP      (RSRC_BITMAP|RSRC_NEWRESOURCE)
#define RSRC_NEWMENU        (RSRC_MENU|RSRC_NEWRESOURCE)
#define RSRC_NEWDIALOG      (RSRC_DIALOG|RSRC_NEWRESOURCE)

// arbitrary menu identifiers
#define  IDM_OPEN     100
#define  IDM_EXIT     101
#define  IDM_ABOUT    102
#define  IDM_DOSHDR   103
#define  IDM_COFFHDR  104
#define  IDM_OPTHDR   105
#define  IDM_SECT     106
#define  IDM_DATADIR  107
#define  IDM_IMPORT   108
#define  IDM_EXPORT   109
#define  IDM_RESOURCE 110
#define  IDM_RSRCTREE 111


// Function prototypes
INT APIENTRY WinMain(HANDLE, HANDLE, PSTR, INT);
BOOL InitInstance(HANDLE, INT);
BOOL TermInstance(HANDLE);
LONG CALLBACK FrameWndProc(HWND, UINT, UINT, LONG);
BOOL CALLBACK AboutDlgProc (HWND, UINT, UINT, LONG);
LONG DoDestroy(HWND, UINT, UINT, LONG);
LONG DoClose(HWND, UINT, UINT, LONG);
LONG DoPaint(HWND, UINT, UINT, LONG);
LONG DoSize(HWND, UINT, UINT, LONG);
LONG DoInitMenu(HWND, UINT, UINT, LONG);
LONG DoCommand(HWND, UINT, UINT, LONG);
LONG DoVScroll(HWND, UINT, UINT, LONG);
LONG DoMenuOpen(HWND, UINT, UINT, LONG);
LONG DoMenuExit(HWND, UINT, UINT, LONG);
LONG DoMenuAbout(HWND, UINT, UINT, LONG);
LONG DoDisplayType(HWND, UINT, UINT, LONG);
VOID Repaint(VOID);
VOID ConfigWindow(VOID);
VOID PaintLine(HDC hdc, INT line);
VOID AddLine(TCHAR *);
VOID SetCurLine(INT);
VOID SetWindowCaption(TCHAR *);
VOID UpdateProfile(VOID);
VOID EmptyLines(VOID);
VOID OpenDataFile(VOID);
VOID CloseDataFile(VOID);
VOID ShowMZHeader(VOID);
VOID ShowCoffHeader(VOID);
VOID ShowOptHeader(VOID);
VOID ShowDataDirectory(VOID);
VOID ShowSections(VOID);
VOID ShowImports(VOID);
VOID ShowExports(VOID);
VOID ShowResources(VOID);
VOID ShowRsrcDir(PRSRCDIR);
VOID ShowRsrcDirEntry(PRSRCDIRENTRY);
VOID ShowRsrcDataEntry(PRSRCDATAENTRY);
VOID ShowResourceTree(VOID);
VOID ShowRsrcTreeDir(PRSRCDIR);
VOID ShowRsrcTreeDirEntry(PRSRCDIRENTRY);
VOID ShowRsrcTreeDataEntry(PRSRCDATAENTRY);
VOID SetHeaderPtrs(VOID);
VOID SetSpaces(INT);


