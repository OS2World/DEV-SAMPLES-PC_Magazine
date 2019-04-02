// ExeLook - Display Information about NT "Portable EXE" (PE) File
// Copyright (C) 1993 Ray Duncan
// PC Magazine * Ziff Davis Publishing
//
// Known limitations:
// Not completely UNICODE-ready yet.
// Not checked out with DLLs which export by ordinal only yet.
// Needs code added to print and to allow viewing of hex contents
// of sections and resources.
//
// Note: 
// Displayed value for "Calculated size of real-mode image" under 
// "MZ Header" is not correct. This is because the NT linker sets 
// the MZ fields incorrectly.
//

#define dim(x) (sizeof(x) / sizeof(x[0]))   // returns no. of elements
#define EXENAMESIZE 256                     // max length of path+filename
#define MAXLINES 4096                       // max lines to display

// macro to convert mapped memory address to file offset
#define FileOffset(x) ((ULONG) x - (ULONG) pMap)

#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <commdlg.h>
#include "ExeLook.h"

HANDLE hInst;                               // module instance handle
HWND hFrame;                                // handle for frame window
HFONT hFont;                                // handle for nonprop. font

INT CharX, CharY;                           // character dimensions
INT LinesPerPage;                           // lines per page
INT CurLine = 0;                            // first line, current page
INT TotLines = 0;                           // total lines to display
INT TopLine = 0;                            // first line of last page
INT DisplayType = IDM_DOSHDR;               // default display type
TCHAR Spaces[256];                          // holds string of blanks
TCHAR *LinePtr[MAXLINES];                   // holds pointers to lines

PMZHEADER   pMZHeader;                      // pointers to header 
PPEHEADER   pPEHeader;                      // structures within mapped 
PCOFFHEADER pCoffHeader;                    // executable file
POPTHEADER  pOptHeader;
PSCNHEADER  pFirstScnHeader;            
PSCNHEADER  pIdataHeader;
PMODULEDIR  pIdata;
PSCNHEADER  pRsrcHeader;
PRSRCDIR    pRsrcDirectory;
PDATADIR    pDataDirectory;
PSCNHEADER  pEdataHeader;
PEXPORTDIR  pExportDirectory;

INT iTreeLevel = 0;                         // nesting level of tree
TCHAR RsrcName[256];                        // name of current resource
PSTR pRsrcType;                             // name of current type

INT hFile = -1;                             // handle for current file
TCHAR szFileName[EXENAMESIZE+1];            // name of current file
LONG FileSize;                              // length of current file
HANDLE hMap = 0;                            // handle, file mapping object
PSTR pMap = NULL;                           // base address, mapping object

TCHAR szFrameClass[] = "ExeLook";           // classname for frame window
TCHAR szAppName[] = "EXE Viewer Utility";   // long application name
TCHAR szMenuName[] = "ExeLookMenu";         // name of menu resource
TCHAR szIcon[] = "ExeLookIcon";             // name of icon resource
TCHAR szIni[] = "ExeLook.ini";              // name of private INI file

TCHAR szFilter[] = {                        // filters for Open dialog
     "Executable Files\0"        "*.EXE\0"
     "Dynamic Link Libraries\0"  "*.DLL\0"
     "All Files\0"               "*.*\0"
     "\0" } ;

TCHAR *DataDirNames[] = {                   // strings for ShowDataDirectory
    "Export Directory",                     // 0
    "Import Directory",                     // 1
    "Resource Directory",                   // 2
    "Exception Directory",                  // 3
    "Security Directory",                   // 4
    "Base Relocation Table",                // 5
    "Debug Directory",                      // 6
    "Description String",                   // 7
    "Machine Value (MIPS GP)",              // 8
    "Thread Local Storage",                 // 9
    "Callback Directory",                   // 10
    "<Unknown>",                            // 11
    "<Unknown>",                            // 12
    "<Unknown>",                            // 13
    "<Unknown>",                            // 14
    "<Unknown>", } ;                        // 15

struct decodeUINT SubSystemTable[] = {            
    IMAGE_SUBSYSTEM_UNKNOWN, "Unknown subsystem",
    IMAGE_SUBSYSTEM_NATIVE, "No subsystem required",
    IMAGE_SUBSYSTEM_WINDOWS_GUI, "Windows graphical I/O subsystem",
    IMAGE_SUBSYSTEM_WINDOWS_CUI, "Windows character I/O subsystem",
    IMAGE_SUBSYSTEM_OS2_CUI, "OS/2 character I/O subsystem",
    IMAGE_SUBSYSTEM_POSIX_CUI, "POSIX character I/O subsystem", } ;

struct decodeUINT SectionChars[] = {
    IMAGE_SCN_TYPE_REGULAR, "Regular",
    IMAGE_SCN_TYPE_DUMMY, "Dummy",          // reserved 
    IMAGE_SCN_TYPE_NO_LOAD, "Not loaded",
    IMAGE_SCN_TYPE_GROUPED, "16-bit offset code",
    IMAGE_SCN_TYPE_NO_PAD, "Unpadded",
    IMAGE_SCN_TYPE_COPY, "Copy",            // reserved
    IMAGE_SCN_CNT_CODE, "Machine code",
    IMAGE_SCN_CNT_INITIALIZED_DATA, "Initialized data",
    IMAGE_SCN_CNT_UNINITIALIZED_DATA, "Uninitialized data",
    IMAGE_SCN_LNK_OTHER, "Other",           // reserved
    IMAGE_SCN_LNK_INFO, "Information",
    IMAGE_SCN_LNK_OVERLAY, "Overlay",
    IMAGE_SCN_LNK_REMOVE, "Not part of image",
    IMAGE_SCN_LNK_COMDAT, "COMDAT",
    IMAGE_SCN_MEM_DISCARDABLE, "Discardable",
    IMAGE_SCN_MEM_NOT_CACHED, "Not cacheable",
    IMAGE_SCN_MEM_NOT_PAGED, "Not pageable",
    IMAGE_SCN_MEM_SHARED, "Shareable",
    IMAGE_SCN_MEM_EXECUTE, "Executable",
    IMAGE_SCN_MEM_READ, "Readable",
    IMAGE_SCN_MEM_WRITE, "Writeable", } ;

struct decodeUINT ImageChars[] = {
    IMAGE_FILE_RELOCS_STRIPPED, "Reloc info stripped",    
    IMAGE_FILE_EXECUTABLE_IMAGE, "Executable",       
    IMAGE_FILE_LINE_NUMS_STRIPPED, "Line numbers stripped",
    IMAGE_FILE_LOCAL_SYMS_STRIPPED, "Local symbols stripped",
    IMAGE_FILE_MINIMAL_OBJECT, "Minimal object",
    IMAGE_FILE_UPDATE_OBJECT, "Update object",
    IMAGE_FILE_16BIT_MACHINE, "16-bit machine",
    IMAGE_FILE_BYTES_REVERSED_LO, "Bytes reversed low",
    IMAGE_FILE_32BIT_MACHINE, "32-bit machine",
    IMAGE_FILE_PATCH, "Patch",
    IMAGE_FILE_SYSTEM, "System file",
    IMAGE_FILE_DLL, "DLL file",
    IMAGE_FILE_BYTES_REVERSED_HI, "Bytes reversed high", } ;

struct decodeUINT DllChars[] = {
    IMAGE_LIBRARY_PROCESS_INIT, "Per-process initialization", 
    IMAGE_LIBRARY_PROCESS_TERM, "Per-process termination",
    IMAGE_LIBRARY_THREAD_INIT, "Per-thread initialization",
    IMAGE_LIBRARY_THREAD_TERM, "Per-thread termination", } ;

struct decodeUINT MachineType[] = {
    IMAGE_FILE_MACHINE_UNKNOWN, "Unknown machine",
    IMAGE_FILE_MACHINE_I860, "Intel i860",
    IMAGE_FILE_MACHINE_I386, "Intel i386/i486",
    IMAGE_FILE_MACHINE_R3000, "MIPS R3000 little-endian",
    IMAGE_FILE_MACHINE_R4000, "MIPS R4000 little-endian", };

struct decodeUINT RsrcType[] = {
    RSRC_CURSOR, "Cursor",
    RSRC_BITMAP, "Bitmap",
    RSRC_ICON, "Icon",          
    RSRC_MENU, "Menu",
    RSRC_DIALOG, "Dialog",
    RSRC_STRING, "String",
    RSRC_FONTDIR, "Font Dir",
    RSRC_FONT, "Font",
    RSRC_ACCELERATOR, "Accelerators", 
    RSRC_RCDATA, "User Defined",
    RSRC_MESSAGETABLE, "Message Table",
    RSRC_GROUP_CURSOR, "Cursor Group",
    RSRC_GROUP_ICON, "Icon Group",
    RSRC_VERSION, "Version",
    RSRC_DLGINCLUDE, "Dlg Include",
    RSRC_NEWBITMAP, "New Bitmap",
    RSRC_NEWMENU, "New Menu",
    RSRC_NEWDIALOG, "New Dialog", } ;

//
// Table of window messages supported by FrameWndProc()
// and the functions which correspond to each message.
//
struct decodeMsg frameMsgs[] = {
    WM_PAINT, DoPaint,
    WM_SIZE, DoSize,
    WM_COMMAND, DoCommand,
    WM_CLOSE, DoClose,
    WM_INITMENU, DoInitMenu,
    WM_DESTROY, DoDestroy,
    WM_VSCROLL, DoVScroll, } ;

//
// Table of WM_COMMAND menu IDs and their corresponding functions.
//
struct decodeMsg menuMsgs[] = {
    IDM_OPEN, DoMenuOpen,
    IDM_EXIT, DoMenuExit,
    IDM_ABOUT, DoMenuAbout,
    IDM_DOSHDR, DoDisplayType,
    IDM_COFFHDR, DoDisplayType,
    IDM_OPTHDR, DoDisplayType,
    IDM_DATADIR, DoDisplayType,
    IDM_SECT, DoDisplayType, 
    IDM_IMPORT, DoDisplayType, 
    IDM_EXPORT, DoDisplayType,  
    IDM_RESOURCE, DoDisplayType, 
    IDM_RSRCTREE, DoDisplayType, } ;

//
// Table of menu IDs for Display popup and their corresponding
// functions and window captions.
//
struct decodeMenuID displayTable[] = {
    IDM_DOSHDR, ShowMZHeader, "DOS (MZ) File Header",
    IDM_COFFHDR, ShowCoffHeader, "COFF File Header", 
    IDM_OPTHDR, ShowOptHeader, "COFF Optional Header", 
    IDM_DATADIR, ShowDataDirectory, "Data Directory", 
    IDM_SECT, ShowSections, "COFF File Sections", 
    IDM_IMPORT, ShowImports, "Module Imports", 
    IDM_EXPORT, ShowExports, "Module Exports", 
    IDM_RESOURCE, ShowResources, "Resources", 
    IDM_RSRCTREE, ShowResourceTree, "Resource Tree", } ;

//
// WinMain -- entry point for this application from Windows.
//
INT APIENTRY WinMain(HANDLE hInstance,
    HANDLE hPrevInstance, PSTR pCmdLine, INT nCmdShow)
{
    MSG msg;                                // scratch message storage
    hInst = hInstance;                      // save this instance handle

    if(!InitInstance(hInstance, nCmdShow))  // initialize everything
    {
        MessageBox(hFrame, "Initialization failed!", szAppName,
            MB_ICONSTOP | MB_OK);
        return(FALSE);
    }

    while(GetMessage(&msg, NULL, 0, 0))     // while message != WM_QUIT
    {
        TranslateMessage(&msg);             // translate virtual key codes
        DispatchMessage(&msg);              // dispatch message to window
    }

    TermInstance(hInstance);                // clean up everything
    return(msg.wParam);                     // return code = WM_QUIT value
}

//
// InitInstance --- initialization code for this process
//
BOOL InitInstance(HANDLE hInstance, INT nCmdShow)
{
    WNDCLASS  wc;                           // window class info
    HDC hdc;                                // handle for device context
    TEXTMETRIC tm;                          // info about font
    RECT rect;                              // window position & size
    INT i;                                  // scratch variable

    // set parameters for frame window class
    wc.style = CS_HREDRAW|CS_VREDRAW;       // class style
    wc.lpfnWndProc = FrameWndProc;          // class callback function
    wc.cbClsExtra = 0;                      // extra per-class data
    wc.cbWndExtra = 0;                      // extra per-window data
    wc.hInstance = hInstance;               // handle of class owner
    wc.hIcon = LoadIcon(hInst, szIcon);     // application icon
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);       // default cursor
    wc.hbrBackground = GetStockObject(WHITE_BRUSH); // background color 
    wc.lpszMenuName =  szMenuName;          // name of menu resource
    wc.lpszClassName = szFrameClass;        // name of window class

    if(!RegisterClass(&wc))                 // register window class,       
        return(FALSE);                      // exit if registration fails
    
    for(i = 0; i < MAXLINES; i++)           // initialize all line
        LinePtr[i] = NULL;                  // pointers

    hFrame = CreateWindow(                  // create frame window
        szFrameClass,                       // window class name
        szAppName,                          // text for title bar
        WS_OVERLAPPEDWINDOW | WS_VSCROLL,   // window style
        CW_USEDEFAULT, CW_USEDEFAULT,       // default position
        CW_USEDEFAULT, CW_USEDEFAULT,       // default size
        NULL,                               // no parent window
        NULL,                               // use class default menu
        hInstance,                          // window owner
        NULL);                              // unused pointer

    if(!hFrame) return(FALSE);              // error, can't create window

    hdc = GetDC(hFrame);                    // get device context
    hFont = GetStockObject(SYSTEM_FIXED_FONT);  // handle for nonprop. font
    SelectObject(hdc, hFont);               // realize the font and get
    GetTextMetrics(hdc, &tm);               // the character dimensions
    CharX = tm.tmAveCharWidth;
    CharY = tm.tmHeight + tm.tmExternalLeading;
    ReleaseDC(hFrame, hdc);                 // release device context

    GetWindowRect(hFrame, &rect);           // current window pos & size

    // read profile for frame window from previous invocation, if any
    rect.left   = GetPrivateProfileInt("Frame", "xul", rect.left, szIni);
    rect.top    = GetPrivateProfileInt("Frame", "yul", rect.top, szIni);
    rect.right  = GetPrivateProfileInt("Frame", "xlr", rect.right, szIni);
    rect.bottom = GetPrivateProfileInt("Frame", "ylr", rect.bottom, szIni);

    MoveWindow(hFrame, rect.left, rect.top, // force window size & position
        rect.right-rect.left, rect.bottom-rect.top, TRUE);

    // get saved filename from previous invocation and open the file
    GetPrivateProfileString("File", "filename", "", szFileName, 
        EXENAMESIZE, szIni);
    if(szFileName[0])                       
        OpenDataFile();                     

    // get display type from previous invocation, default to DOS file header
    DisplayType = GetPrivateProfileInt("Frame", "type", IDM_DOSHDR, szIni);

    ShowWindow(hFrame, nCmdShow);           // make frame window visible

    // simulate a Display menu command to turn on the menu checkmark
    // for the current display type, and force update of the window
    PostMessage(hFrame, WM_COMMAND, DisplayType, 0);

    return(TRUE);                           // return success flag
}

//
// TermInstance -- cleanup code for this process
//
BOOL TermInstance(HANDLE hinstance)
{
    return(TRUE);                           // return success flag
}

//
// FrameWndProc --- callback function for application frame window.
// Searches frameMsgs[] for message match, runs corresponding function.
//
LONG CALLBACK FrameWndProc(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    INT i;                                  // scratch variable

    for(i = 0; i < dim(frameMsgs); i++)     // decode window message and
    {                                       // run corresponding function
        if(wMsg == frameMsgs[i].Code)
            return((*frameMsgs[i].Fxn)(hWnd, wMsg, wParam, lParam));
    }

    return(DefWindowProc(hWnd, wMsg, wParam, lParam));
}

//
// DoCommand -- process WM_COMMAND message for frame window by
// decoding the menubar item with the menuMsgs[] array, then
// running the corresponding function to process the command.
// 
LONG DoCommand(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    INT i;                                  // scratch variable

    for(i = 0; i < dim(menuMsgs); i++)      // decode menu command and
    {                                       // run corresponding function
        if(wParam == menuMsgs[i].Code)
            return((*menuMsgs[i].Fxn)(hWnd, wMsg, wParam, lParam));
    }

    return(DefWindowProc(hWnd, wMsg, wParam, lParam));
}

//
// DoDestroy -- process WM_DESTROY message for frame window.
// 
LONG DoDestroy(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    PostQuitMessage(0);                     // force WM_QUIT message to
    return(0);                              // terminate the event loop
}

//
// DoClose -- process WM_CLOSE message for frame window.
// 
LONG DoClose(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    UpdateProfile();                        // save window size & position
    DestroyWindow(hWnd);                    // then close down app
    return(FALSE);                              
}

// 
// DoInitMenu - process WM_INITMENU message, enable/disable menu
// items and set appropriate checkmarks.
//
LONG DoInitMenu(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    HMENU hMenu = (HMENU) wParam;

    // if imports section was found, enable import menu item
    EnableMenuItem(hMenu, IDM_IMPORT, pIdataHeader ? MF_ENABLED : MF_GRAYED);

    // if exports section was found, enable import menu item
    EnableMenuItem(hMenu, IDM_EXPORT, pEdataHeader ? MF_ENABLED : MF_GRAYED);

    // if resource section was found, enable resource menu items
    EnableMenuItem(hMenu, IDM_RESOURCE, pRsrcHeader ? MF_ENABLED : MF_GRAYED);
    EnableMenuItem(hMenu, IDM_RSRCTREE, pRsrcHeader ? MF_ENABLED : MF_GRAYED);

    return(FALSE);
}

//
// DoVScroll -- process WM_VSCROLL message for frame window.
// 
LONG DoVScroll(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    RECT rect;

    switch(LOWORD(wParam))                  // LOWORD vital for Win32
    {                                   
        case SB_TOP:                        // go to top of output if
            if(CurLine)                     // we aren't there already
            {
                SetCurLine(0);
                Repaint();
            }
            break;

        case SB_BOTTOM:                     // go to bottom of output if
            if(CurLine < TopLine)           // we aren't there already
            {
                SetCurLine(TopLine);
                Repaint();
            }
            break;

        case SB_LINEUP:                     // scroll up by one line if
            if(CurLine)                     // we aren't already at top
            {   
                SetCurLine(CurLine - 1);
                ScrollWindow(hWnd, 0, CharY, NULL, NULL);
                UpdateWindow(hWnd);
            }
            break;

        case SB_LINEDOWN:                   // scroll down by one line if
            if(CurLine < TopLine)           // we aren't already at bottom
            {
                SetCurLine(CurLine + 1);
                ScrollWindow(hWnd, 0, -CharY, NULL, NULL);
                GetClientRect(hWnd, &rect);
                rect.top = max(0, (LinesPerPage-1) * CharY);
                InvalidateRect(hWnd, &rect, TRUE);
                UpdateWindow(hWnd);
            }
            break;

        case SB_PAGEUP:                     // scroll up by one page
            SetCurLine(CurLine - LinesPerPage);
            Repaint();
            break;

        case SB_PAGEDOWN:                   // scroll down by one page
            SetCurLine(CurLine + LinesPerPage);
            Repaint();
            break;

        case SB_THUMBPOSITION:              // scroll display according
            SetCurLine(THUMBPOS);           // to new thumb position
            Repaint();
            break;
    }
    return(FALSE);                              
}

//
// DoPaint -- process WM_PAINT message for frame window.
// 
LONG DoPaint(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    HDC hdc;
    PAINTSTRUCT ps;
    INT i;

    hdc = BeginPaint(hWnd, &ps);            // get device context
    SelectObject(hdc, hFont);               // select non-prop. font

    for(i = 0; i < LinesPerPage; i++)       // paint lines of text
        PaintLine(hdc, i);                  // in the window

    EndPaint(hWnd, &ps);                    // release device context
    return(FALSE);
}

//
// DoSize -- process WM_SIZE message for frame window.  Recalculate
// lines per page, if window has grown and at end of file may need to 
// change first line in window and refresh it.
//
LONG DoSize(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    LinesPerPage = HIWORD(lParam) / CharY;  // window height / char height
    ConfigWindow();                         // calc display parameters
    if(CurLine > TopLine)                   // make sure window refilled
        SetCurLine(TopLine);                // if window got bigger
    return(FALSE);
}

//
// DoMenuOpen -- process File-Open command from menu bar. All
// the hard work is done by the OpenFile common dialog.
//
LONG DoMenuOpen(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    OPENFILENAME ofn;                       // used by common dialogs

    szFileName[0]  = '\0';                  // init filename buffer

    ofn.lStructSize = sizeof(OPENFILENAME); // length of structure
    ofn.hwndOwner = hWnd;                   // handle for owner window
    ofn.lpstrFilter = szFilter;             // address of filter list
    ofn.lpstrCustomFilter = NULL;           // custom filter buffer address
    ofn.nFilterIndex = 1;                   // pick default filter
    ofn.lpstrFile = szFileName;             // buffer for path+filename
    ofn.nMaxFile = EXENAMESIZE;             // length of buffer
    ofn.lpstrFileTitle = NULL;              // buffer for filename only
    ofn.lpstrInitialDir = NULL;             // initial directory for dialog
    ofn.lpstrTitle = NULL;                  // title for dialog box
    ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;
    ofn.lpstrDefExt = NULL;                 // default extension 

    if(GetOpenFileName(&ofn))               // display open dialog
    {
        OpenDataFile();                     // open file for viewing
        PostMessage(hFrame, WM_COMMAND, DisplayType, 0); // update display
    }

    return(FALSE);
}

//
// DoMenuExit -- process File-Exit command from menu bar.
// 
LONG DoMenuExit(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    SendMessage (hWnd, WM_CLOSE, 0, 0L);    // send window close message    
    return(FALSE);                          // to shut down the app
}

//
// DoDisplayType -- update the display type popup menu, rebuild the 
// formattted information according to the newly selected display 
// type, then refresh the window.
// 
LONG DoDisplayType(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    HMENU hMenu;                            // scratch variables
    INT i;

    hMenu = GetMenu(hWnd);                  // update popup checkmark
    CheckMenuItem(hMenu, DisplayType, MF_UNCHECKED);
    DisplayType = wParam;                   
    CheckMenuItem(hMenu, DisplayType, MF_CHECKED);

    EmptyLines();                           // discard old output

    if(hFile != -1)                         // make sure valid file
    {
        // look up the display function and window caption
        // for the currently selected display type
        for(i = 0; i < dim(displayTable); i++)      
        {                                       
            if(wParam == displayTable[i].Code)
            {
                SetWindowCaption(displayTable[i].Name);
                (*displayTable[i].Fxn)();
            }
        }
    }

    ConfigWindow();                         // configure scroll bar etc.
    Repaint();                              // refresh the window

    return(FALSE);
}

//
// DoMenuAbout -- process File-About command from menu bar.
// 
LONG DoMenuAbout(HWND hWnd, UINT wMsg, UINT wParam, LONG lParam)
{
    // allocate a thunk for the dialog callback, then display dialog
    DialogBox(hInst, "AboutBox", hWnd, (WNDPROC) AboutDlgProc);         
    return(FALSE);                              
}

//
// AboutDlgProc -- callback routine for About... dialog.  Basically
// ignores all messages except for the OK button, which dismisses dialog.
//
BOOL CALLBACK AboutDlgProc (HWND hwnd, UINT msg, UINT wParam, LONG lParam)
{
    if((msg == WM_COMMAND) && (wParam == IDOK)) 
        EndDialog(hwnd, 0);                 // if OK button, destroy dialog
    else return(FALSE);                     // otherwise ignore message
}

//
// ShowMZHeader -- formats contents of Real-mode DOS "Old Exe" (MZ) 
// file header.
//
VOID ShowMZHeader(VOID)
{
    TCHAR temp[256];
    LONG l;

    wsprintf(temp, "Header size:\t\t\t%d paragraphs (%d bytes)", 
        pMZHeader->e_cparhdr, pMZHeader->e_cparhdr * 16);
    AddLine(temp);

    wsprintf(temp, "Header + program size:\t\t%d (512-byte) pages", 
        pMZHeader->e_cp);
    AddLine(temp);

    wsprintf(temp, "Header + program MOD 512:\t%d bytes", 
        pMZHeader->e_cblp);
    AddLine(temp);

    l = (pMZHeader->e_cp * 512) - (pMZHeader->e_cparhdr * 16);
    if(pMZHeader->e_cblp) l = l - 512 + pMZHeader->e_cblp;
    wsprintf(temp, "Calculated image size:\t\t%ld bytes", l);
    AddLine(temp);

    wsprintf(temp, "Number of relocations:\t\t%d", pMZHeader->e_crlc);
    AddLine(temp);

    wsprintf(temp, "Relocation table offset:\t%04Xh bytes", 
        pMZHeader->e_lfarlc);
    AddLine(temp);

    wsprintf(temp, "Initial CS:IP:\t\t\t%04X:%04Xh (load address relative)", 
        pMZHeader->e_cs, pMZHeader->e_ip);
    AddLine(temp);

    wsprintf(temp, "Initial SS:SP:\t\t\t%04X:%04Xh (load address relative)", 
        pMZHeader->e_ss, pMZHeader->e_sp);
    AddLine(temp);

    wsprintf(temp, "Minimum extra allocation:\t%u paragraphs (%d bytes)", 
        pMZHeader->e_minalloc, pMZHeader->e_minalloc * 16);
    AddLine(temp);

    wsprintf(temp, "Maximum extra allocation:\t%u paragraphs (%d bytes)", 
        pMZHeader->e_maxalloc, pMZHeader->e_maxalloc * 16);
    AddLine(temp);

    wsprintf(temp, "Checksum:\t\t\t%04Xh", pMZHeader->e_csum);
    AddLine(temp);

    if(pMZHeader->e_lfarlc >= 0x40)             // check if NE, LE, or PE
    {
        wsprintf(temp, "Protected mode header offset:\t%ld (%08lXh) bytes",
            pMZHeader->e_lfanew, pMZHeader->e_lfanew);
        AddLine(temp);
    }
}

//
// ShowCoffHeader -- formats contents of COFF "FileHeader" structure
// embedded within NT "PE" header.
//
VOID ShowCoffHeader(VOID)
{
    TCHAR temp[256];
    TCHAR *p;
    INT i;

    p = "Unknown machine type";

    for(i = 0; i < dim(MachineType); i++)
    {
        if(MachineType[i].Code == pCoffHeader->Machine)
            p = MachineType[i].Name;
    }

    wsprintf(temp, "Machine:\t\t\t%04Xh (%s)", pCoffHeader->Machine, p);
    AddLine(temp);
    
    wsprintf(temp, "Number of sections:\t\t%d", 
        pCoffHeader->NumberOfSections);
    AddLine(temp);

    wsprintf(temp, "Time/Date Stamp:\t\t%08Xh", 
        pCoffHeader->TimeDateStamp);
    AddLine(temp);

    wsprintf(temp, "Symbol Table Pointer:\t\t%08Xh",
        pCoffHeader->PointerToSymbolTable);
    AddLine(temp);

    wsprintf(temp, "Number of Symbols:\t\t%d",
        pCoffHeader->NumberOfSymbols);
    AddLine(temp);

    wsprintf(temp, "Optional Header Size:\t\t%d (%0Xh) bytes",
        pCoffHeader->SizeOfOptionalHeader,
        pCoffHeader->SizeOfOptionalHeader);
    AddLine(temp);

    wsprintf(temp, "Characteristics:\t\t%04Xh",
        pCoffHeader->Characteristics);
    AddLine(temp);

    for(i = 0; i < dim(ImageChars); i++)
    {
        if(ImageChars[i].Code & pCoffHeader->Characteristics)
        {
            wsprintf(temp, "\t\t\t\t%s", ImageChars[i].Name);
            AddLine(temp);
        }
    }
}

//
// ShowOptHeader -- formats contents of COFF "OptionalHeader" 
// structure embedded within NT "PE" header.
//
VOID ShowOptHeader(VOID)
{
    TCHAR temp[256];
    TCHAR *p;
    INT i;

    wsprintf(temp, "Magic Number:\t\t\t%04Xh",
        pOptHeader->Magic);
    AddLine(temp);

    wsprintf(temp, "Linker Major Version Number:\t%d",
        pOptHeader->MajorLinkerVersion);
    AddLine(temp);

    wsprintf(temp, "Linker Minor Version Number:\t%d",
        pOptHeader->MinorLinkerVersion);
    AddLine(temp);

    wsprintf(temp, "Size of Code:\t\t\t%d (%0Xh) bytes",
        pOptHeader->SizeOfCode,
        pOptHeader->SizeOfCode);
    AddLine(temp);

    wsprintf(temp, "Size of Initialized Data:\t%d (%0Xh) bytes",
        pOptHeader->SizeOfInitializedData,
        pOptHeader->SizeOfInitializedData);
    AddLine(temp);

    wsprintf(temp, "Size of Uninitialized Data:\t%d (%0Xh) bytes",
        pOptHeader->SizeOfUninitializedData,
        pOptHeader->SizeOfUninitializedData);
    AddLine(temp);

    wsprintf(temp, "Address of Entry Point:\t%08Xh",
        pOptHeader->AddressOfEntryPoint);
    AddLine(temp);

    wsprintf(temp, "Base of Code:\t\t\t%08Xh",
        pOptHeader->BaseOfCode);
    AddLine(temp);

    wsprintf(temp, "Base of Data:\t\t\t%08Xh",
        pOptHeader->BaseOfData);
    AddLine(temp);

    wsprintf(temp, "Base of Image:\t\t\t%08Xh",
        pOptHeader->ImageBase);
    AddLine(temp);

    wsprintf(temp, "Section Alignment:\t\t%d bytes",
        pOptHeader->SectionAlignment);
    AddLine(temp);

    wsprintf(temp, "File Alignment:\t\t%d bytes",
        pOptHeader->FileAlignment);
    AddLine(temp);

    wsprintf(temp, "Op Sys Major Version Number:\t%d",
        pOptHeader->MajorOperatingSystemVersion);
    AddLine(temp);

    wsprintf(temp, "Op Sys Minor Version Number:\t%d",
        pOptHeader->MinorOperatingSystemVersion);
    AddLine(temp);

    wsprintf(temp, "Image Major Version Number:\t%d",
        pOptHeader->MajorImageVersion);
    AddLine(temp);

    wsprintf(temp, "Image Minor Version Number:\t%d",
        pOptHeader->MinorImageVersion);
    AddLine(temp);

    wsprintf(temp, "Subsyst Major Version Number:\t%d",
        pOptHeader->MajorSubsystemVersion);
    AddLine(temp);

    wsprintf(temp, "Subsyst Minor Version Number:\t%d",
        pOptHeader->MinorSubsystemVersion);
    AddLine(temp);

    wsprintf(temp, "Size of Image:\t\t\t%d (%0Xh) bytes",
        pOptHeader->SizeOfImage, pOptHeader->SizeOfImage);
    AddLine(temp);

    wsprintf(temp, "Size of Headers:\t\t%d (%0Xh) bytes",
        pOptHeader->SizeOfHeaders, pOptHeader->SizeOfHeaders);
    AddLine(temp);

    wsprintf(temp, "Checksum:\t\t\t%08Xh",
        pOptHeader->CheckSum);
    AddLine(temp);

    p = "Unknown subsystem";

    for(i = 0; i < dim(SubSystemTable); i++)
    {
        if(SubSystemTable[i].Code == pOptHeader->Subsystem)
            p = SubSystemTable[i].Name;
    }

    wsprintf(temp, "Subsystem:\t\t\t%04Xh (%s)",
        pOptHeader->Subsystem, p);
    AddLine(temp);

    wsprintf(temp, "DLL Characteristics:\t\t%04Xh",
        pOptHeader->DllCharacteristics);
    AddLine(temp);

    for(i = 0; i < dim(DllChars); i++)
    {
        if(DllChars[i].Code & pOptHeader->DllCharacteristics)
        {
            wsprintf(temp, "\t\t\t\t%s", DllChars[i].Name);
            AddLine(temp);
        }
    }

    wsprintf(temp, "Stack Reserve Size:\t\t%d (%0Xh) bytes",
        pOptHeader->SizeOfStackReserve,
        pOptHeader->SizeOfStackReserve);
    AddLine(temp);

    wsprintf(temp, "Stack Commit Size:\t\t%d (%0Xh) bytes",
        pOptHeader->SizeOfStackCommit,
        pOptHeader->SizeOfStackCommit);
    AddLine(temp);

    wsprintf(temp, "Heap Reserve Size:\t\t%d (%0Xh) bytes",
        pOptHeader->SizeOfHeapReserve,
        pOptHeader->SizeOfHeapReserve);
    AddLine(temp);

    wsprintf(temp, "Heap Commit Size:\t\t%d (%0Xh) bytes",
        pOptHeader->SizeOfHeapCommit,
        pOptHeader->SizeOfHeapCommit);
    AddLine(temp);

    wsprintf(temp, "Tls Index Address:\t\t%08Xh",
        pOptHeader->AddressOfTlsIndex);
    AddLine(temp);

    wsprintf(temp, "Number of Rva And Sizes:\t%d",
        pOptHeader->NumberOfRvaAndSizes);
    AddLine(temp);
}

//
// ShowDataDirectory -- formats nonzero slots in the Data Directory
// that is embedded in the COFF "Optional Header."
//
VOID ShowDataDirectory(VOID)
{
    INT i;
    TCHAR temp[256];

    AddLine("\t\t\t  Virtual Addr     Size");

    for(i = 0; i < IMAGE_NUMBEROF_DIRECTORY_ENTRIES; i++)
    {
        if(pDataDirectory[i].VirtualAddress)
        {
            wsprintf(temp, "%-24s  %08Xh    %08XH", 
                     DataDirNames[i],
                     pDataDirectory[i].VirtualAddress,
                     pDataDirectory[i].Size);
            AddLine(temp);
        }   
    }
}

//
// ShowSections -- formats information about the COFF sections
// in the executable file.
//
VOID ShowSections(VOID)
{
    TCHAR temp[256], temp2[256];
    UINT i, j;
    PSCNHEADER pCurScnHeader = pFirstScnHeader;

    AddLine("\t   Virtual  Raw Data   Relocs   LineNums");
    AddLine("\t  Addr/Size Addr/Size Addr/Cnt  Addr/Cnt  Attributes");

    for(i = 0; i < pCoffHeader->NumberOfSections; i++)
    {
        wsprintf(temp, "%-8s %08Xh %08Xh %08Xh %08Xh %08Xh", 
            pCurScnHeader->Name,
            pCurScnHeader->VirtualAddress,
            pCurScnHeader->PointerToRawData,
            pCurScnHeader->PointerToRelocations,
            pCurScnHeader->PointerToLinenumbers,
            pCurScnHeader->Characteristics);
        AddLine(temp);

        wsprintf(temp, "         %08Xh %08Xh %08Xh %08Xh ", 
            pCurScnHeader->Misc.VirtualSize,
            pCurScnHeader->SizeOfRawData,
            pCurScnHeader->NumberOfRelocations,
            pCurScnHeader->NumberOfLinenumbers);
        AddLine(temp);

        strcpy(temp2, "");

        for(j = 0; j < dim(SectionChars); j++)
        {
            if(SectionChars[j].Code & pCurScnHeader->Characteristics)
            {
                if(strlen(temp2))
                    strcat(temp2, ", ");
                      
                strcat(temp2, SectionChars[j].Name);
            }
        }

        if(strlen(temp2))
        {
            wsprintf(temp, "         %s", temp2);
            AddLine(temp);
        }

        pCurScnHeader = (PSCNHEADER) ((PBYTE) pCurScnHeader + 
                        sizeof(IMAGE_SECTION_HEADER));
    }
}

//
// ShowImports -- formats names of imported modules and their
// function entry points.
//
VOID ShowImports(VOID)
{
    TCHAR temp[256];                        // formatting buffer
    PMODULEDIR pCurModule = pIdata;         // module directory pointer
    PBYTE pModuleName;                      // module name pointer
    UINT * pImportList;                     // function list pointer
    PIMPORTNAME pImportEntry;               // imported function pointer

    if(pIdataHeader == NULL)                // bail if no import section
    {
        PostMessage(hFrame, WM_COMMAND, IDM_SECT, 0);
        return;
    }

    // walk through the imported module directory which is found 
    // at the beginning of the file section ".idata"
    while(pCurModule->ModuleName)
    {
        // extract pointer to the imported module's name from
        // the current module directory slot
        pModuleName = (PBYTE) pIdata + pCurModule->ModuleName - 
                      pIdataHeader->VirtualAddress;

        // copy the module name to local storage (since ".idata" is
        // in read-only memory), then fold it to upper case for display
        strcpy(temp, pModuleName);
        _strupr(temp);
        AddLine(temp);

        // extract a pointer to the list of imported functions for
        // this module from the module directory entry
        pImportList = (UINT *) ((PBYTE) pIdata + pCurModule->ImportList - 
                      pIdataHeader->VirtualAddress);

        // walk through the list of pointers to structures for the
        // imported functions until a NULL pointer is encountered
        while(*pImportList)
        {
            // calculate the address of the structure describing this
            // imported function
            pImportEntry = (PIMPORTNAME) ((PBYTE) pIdata + *pImportList - 
                           pIdataHeader->VirtualAddress);

            // format the name of the imported function for display
            wsprintf(temp, "\t%s", pImportEntry->Name);
            AddLine(temp);

            // go to the next imported function for this module
            pImportList++;
        }

        // calculate the address of the next module directory entry
        pCurModule++;
    }
}

//
// ShowExports -- formats names, ordinals, hint values, and virtual
// addresses of exported functions for this module.
//
VOID ShowExports(VOID)
{
    ULONG i;                                // scratch variable
    UINT Hint = 0;                          // exported fxn position
    UINT * pFunctionList;                   // pointer to pointer list
    PSTR pFunctionName;                     // pointer to name 
    UINT * pFunctionAddr;                   // pointer to virtual addr
    USHORT * pFunctionOrdinal;              // pointer to ordinal
    TCHAR temp[256];                        // formatting buffer 

    if(pEdataHeader == NULL)                // bail if no export section
    {
        PostMessage(hFrame, WM_COMMAND, IDM_SECT, 0);
        return;
    }

    // extract virtual address of list of pointers to exported function
    // names from export directory, convert virtual to mapped address
    pFunctionList = (UINT *) ((PBYTE) pExportDirectory + 
                    (ULONG) pExportDirectory->AddressOfNames - 
                    pEdataHeader->VirtualAddress);

    // calculate mapped base address of table of function addresses
    pFunctionAddr = (UINT *) ((PBYTE) pExportDirectory + 
                    (ULONG) pExportDirectory->AddressOfFunctions - 
                    pEdataHeader->VirtualAddress);

    // calculate mapped base address of table of ordinals which have a
    // 1:1 correspondence to function names
    pFunctionOrdinal= (USHORT *) ((PBYTE) pExportDirectory + 
                      (ULONG) pExportDirectory->AddressOfNameOrdinals - 
                      pEdataHeader->VirtualAddress);

    // display title line
    wsprintf(temp, "%-32s Ordinal  Hint  Virt Addr", "Function Name");
    AddLine(temp);

    // now walk through the array of name pointers and display each name
    // along with function's ordinal, hint number, and virtual address
    for(i = 0; i < pExportDirectory->NumberOfNames; i++)
    {
        // convert virtual address of function name to mapped address
        pFunctionName = (PSTR) pExportDirectory + (ULONG) *pFunctionList - 
                        pEdataHeader->VirtualAddress;

        // format and display information for this function
        wsprintf(temp, "%-32s  %04Xh  %04Xh  %08Xh", pFunctionName, 
                 pExportDirectory->Base + *pFunctionOrdinal, Hint,
                 pFunctionAddr[*pFunctionOrdinal]);
        AddLine(temp);

        // advance to next name and corresponding ordinal
        // count exported functions for "hint" value
        pFunctionList++;
        pFunctionOrdinal++;
        Hint++;
    }
}

//
// ShowResources -- formats names or IDs, types, addresses, and sizes 
// of binary resources (icons, dialogs, menus, bitmaps, and so on).
//
VOID ShowResources(VOID)
{
    TCHAR temp[256];

    if(pRsrcDirectory == NULL)              // bail if no resource section
    {
        PostMessage(hFrame, WM_COMMAND, IDM_SECT, 0);
        return;
    }

    // format title line with spacing to match detail lines
    wsprintf(temp, "%-24s %-14s %-9s  %-9s  %-9s  %-9s",
             "Resource Name or ID", "Type", "Virt Addr", 
             "File Addr", "  Size", "Code Page");
    AddLine(temp);

    iTreeLevel = 0;                         // reset nesting level
    ShowRsrcDir(pRsrcDirectory);            // start with root directory
}

//
// ShowRsrcDir -- traverse directory entries for the specified
// resource directory. Gets called by its own subroutines to 
// walk recursively through the entire resource directory tree.
//
VOID ShowRsrcDir(PRSRCDIR pCurRsrcDir)
{
    PRSRCDIRENTRY  pCurDirEntry;
    UINT i, j;

    // calculate address of first entry for this directory
    pCurDirEntry = (PRSRCDIRENTRY) ((PBYTE) pCurRsrcDir + 
                   sizeof(IMAGE_RESOURCE_DIRECTORY));

    // find number of entries (by ID or by name)
    j = max(pCurRsrcDir->NumberOfNamedEntries, pCurRsrcDir->NumberOfIdEntries);

    // now go and process each entry 
    for(i = 0; i < j; i++)
    {
        ShowRsrcDirEntry(pCurDirEntry);
        pCurDirEntry++;
    }
}

//
// ShowRsrcDirEntry -- process one directory entry.  If at directory
// level zero, the name field indicates the type of resource.  If at
// directory level one, the name field indicates the ID or name of
// a single discrete resource. If at directory level two, the name
// indicates the language (not handled by this code as we have no 
// working examples of multilanguage files yet).
//
VOID ShowRsrcDirEntry(PRSRCDIRENTRY pCurDirEntry)
{
    PRSRCDIRSTR pCurDirString;
    PRSRCDATAENTRY pCurDataEntry;
    INT i;

    // If this is first level of directory, the name field of the
    // directory entry indicates the resource type.  Find the string 
    // corresponding to the resource type, save its address for later.
    if(iTreeLevel == 0)
    {
        pRsrcType = "Unknown";

        for(i = 0; i < dim(RsrcType); i++)
        {
            if(RsrcType[i].Code == pCurDirEntry->Name)
                pRsrcType = RsrcType[i].Name;
        }
    }

    // Now format the resource name or ID.  If we happen to be at
    // directory level zero no harm is done, the resulting string will 
    // just get overwritten during processing of next level.
    if(pCurDirEntry->Name & IMAGE_RESOURCE_NAME_IS_STRING)
    {
        // calculate file address of UNICODE resource name
        pCurDirString = (PRSRCDIRSTR) ((PBYTE) pRsrcDirectory + 
                        (pCurDirEntry->Name &
                        ~IMAGE_RESOURCE_NAME_IS_STRING));

        // convert UNICODE resource name to ASCIIZ for later display
        memset(RsrcName, 0, sizeof(RsrcName));
        wcstombs(RsrcName, (LPWSTR) pCurDirString->NameString, 
                 pCurDirString->Length);
    }
    else if(pCurDirEntry->Name)             // format ID if nonzero
    {
        wsprintf(RsrcName, "%08Xh", pCurDirEntry->Name);
    }

    // calculate address of resource data entry for this directory entry
    pCurDataEntry = (PRSRCDATAENTRY) ((PBYTE) pRsrcDirectory + 
                    (pCurDirEntry->OffsetToData & 
                    ~IMAGE_RESOURCE_DATA_IS_DIRECTORY));

    // if data field of entry points to a resource subdirectory, 
    // call ShowRsrcDir to process the subdirectory, otherwise, call
    // ShowRsrcDataEntry to format the resource information.
    if(pCurDirEntry->OffsetToData & IMAGE_RESOURCE_DATA_IS_DIRECTORY)
    {
        iTreeLevel++;                           // update nesting level
        ShowRsrcDir((PRSRCDIR) pCurDataEntry);  // audit subdirectory
        iTreeLevel--;                           // update nesting level
    }
    else ShowRsrcDataEntry(pCurDataEntry);  // audit resource data entry 
}

//
// ShowRsrcDataEntry -- formats and displays the name, type, address,
// size, and code page of a discrete binary resource, using information
// in the data entry structure and the resource ID or name and resource 
// type saved during traversal of the directory tree.
//
VOID ShowRsrcDataEntry(PRSRCDATAENTRY pCurDataEntry)
{
    TCHAR temp[256];

    wsprintf(temp, "%-24s %-14s %08Xh  %08Xh  %08Xh  %08Xh",
             RsrcName,                      // resource name or ID      
             pRsrcType,                     // resource type
             pCurDataEntry->OffsetToData,   // virtual address of resource
             pCurDataEntry->OffsetToData -  // file offset of resource
                pRsrcHeader->VirtualAddress + pRsrcHeader->PointerToRawData,
             pCurDataEntry->Size,           // resource size
             pCurDataEntry->CodePage);      // resource code page
    AddLine(temp);
}

//
// ShowResourceTree -- formats and displays a tree-like listing of
// all resource directories, directory entries, and data entries
//
VOID ShowResourceTree(VOID)
{
    if(pRsrcDirectory == NULL)              // bail if no resource section
    {
        PostMessage(hFrame, WM_COMMAND, IDM_SECT, 0);
        return;
    }

    iTreeLevel = 0;                         // reset tree indent level
    ShowRsrcTreeDir(pRsrcDirectory);        // start with root directory
}

//
// ShowRsrcTreeDir -- audit a resource directory and all its dependent 
// data structures. Called recursively to walk through the resource
// directory tree.
//
VOID ShowRsrcTreeDir(PRSRCDIR pCurRsrcDir)
{
    PRSRCDIRENTRY  pCurDirEntry;
    UINT i, j;
    TCHAR temp[256];

    // display file offset of this directory
    wsprintf(temp,"%sDirectory at %08XH", Spaces, FileOffset(pCurRsrcDir));
    AddLine(temp);

    // calculate address of first entry for this directory
    pCurDirEntry = (PRSRCDIRENTRY) ((PBYTE) pCurRsrcDir + 
                   sizeof(IMAGE_RESOURCE_DIRECTORY));

    // find number of entries (either by ID or by name)
    j = max(pCurRsrcDir->NumberOfNamedEntries, pCurRsrcDir->NumberOfIdEntries);

    for(i = 0; i < j; i++)
    {
        // audit each entry for this directory
        ShowRsrcTreeDirEntry(pCurDirEntry); 
        pCurDirEntry++;
    }
}

//
// ShowRsrcTreeDirEntry -- formats and displays the contents of a
// resource directory entry.  If the directory entry's name
// field points to a resource directory string record containing 
// a UNICODE resource name, also displays address of that record.
//
VOID ShowRsrcTreeDirEntry(PRSRCDIRENTRY pCurDirEntry)
{
    PRSRCDIRSTR pCurDirString;
    PRSRCDATAENTRY pCurDataEntry;
    TCHAR temp[256];

    // format information about current directory entry
    wsprintf(temp, "%s  Dir Entry at %08XH, Name = %08Xh, Offset = %08Xh", 
             Spaces, FileOffset(pCurDirEntry), pCurDirEntry->Name, 
             pCurDirEntry->OffsetToData);
    AddLine(temp);

    // format address of directory string structure, if any
    if(pCurDirEntry->Name & IMAGE_RESOURCE_NAME_IS_STRING)
    {
        // calculate file address of UNICODE resource name
        pCurDirString = (PRSRCDIRSTR) ((PBYTE) pRsrcDirectory + 
                        (pCurDirEntry->Name &
                        ~IMAGE_RESOURCE_NAME_IS_STRING));

        wsprintf(temp, "%s  Dir String at %08Xh", Spaces, 
                 FileOffset(pCurDirString));
        AddLine(temp);
    }

    // calculate address of resource data entry or subdirectory for 
    // the current directory entry
    pCurDataEntry = (PRSRCDATAENTRY) ((PBYTE) pRsrcDirectory + 
                    (pCurDirEntry->OffsetToData & 
                    ~IMAGE_RESOURCE_DATA_IS_DIRECTORY));

    // if data field of entry points to a resource subdirectory, 
    // call ShowRsrcTreeDir to audit the subdirectory, otherwise, call
    // ShowRsrcTreeDataEntry to format the resource data entry record.
    if(pCurDirEntry->OffsetToData & IMAGE_RESOURCE_DATA_IS_DIRECTORY)
    {
        SetSpaces(++iTreeLevel);                    // indent tree display
        ShowRsrcTreeDir((PRSRCDIR) pCurDataEntry);  // audit subdirectory
        SetSpaces(--iTreeLevel);                    // outdent tree display
    }
    else
        ShowRsrcTreeDataEntry(pCurDataEntry);   // audit resource data entry 
}

//
// ShowRsrcTreeDataEntry -- formats and displays the contents of a 
// resource data entry record within the resource section header.
//
VOID ShowRsrcTreeDataEntry(PRSRCDATAENTRY pCurDataEntry)
{
    TCHAR temp[256];

    wsprintf(temp, "%s  Resource Data Entry at %08Xh", Spaces, 
             FileOffset(pCurDataEntry));
    AddLine(temp);
}

// 
// SetSpaces -- creates an ASCIIZ string of spaces whose length
// depends on the current resource directory tree nesting level.
//
VOID SetSpaces(INT iSpaces)
{
    memset(Spaces, 0, sizeof(Spaces));
    memset(Spaces, ' ', iSpaces*4);
}

//
// SetCurLine -- called to set CurLine to valid value, clamped to
// the range (0...TopLine), and redraw thumb on scroll bar.
//
VOID SetCurLine(INT NewLine)
{
    CurLine = min(max(NewLine, 0), TopLine);
    SetScrollPos(hFrame, SB_VERT, CurLine, TRUE);
}

//
// ConfigWindow -- Configures various display parameters and scrollbar
// according to total lines of output, current window size, and the
// number of lines that will fit into the window.
//
VOID ConfigWindow(VOID)
{
    // calc line number of first line of last page
    TopLine = max(TotLines - LinesPerPage,0);
    
    // update scroll bar range and thumb position
    SetScrollRange(hFrame, SB_VERT, 0, TopLine, FALSE);
    SetScrollPos(hFrame, SB_VERT, CurLine, TRUE);
}

//
// AddLine -- called with a pointer to an ASCIIZ string, allocates
// memory from the heap to hold the string, puts the pointer
// to the heap block into the next position in the LinePtr[] array,
// and updates the total line count.
//
VOID AddLine(TCHAR * p)
{
    TCHAR * q;                              // scratch pointer

    if(TotLines == MAXLINES)                // bail out if line pointer
        return;                             // array is already full
    q = malloc(strlen(p)+1);                // allocate memory for line
    if(q == 0)                              // bail out out if no 
        return;                             // heap space available
    strcpy(q, p);                           // copy string to heap
    LinePtr[TotLines] = q;                  // put heap pointer into array
    TotLines++;                             // count lines of output
}

//
// EmptyLines -- releases all heap blocks in LinePtr[] array,
// then zeros out the line pointers and the total line count
//
VOID EmptyLines(VOID)
{
    INT i;                                  // scratch variable

    for(i = 0; i < MAXLINES; i++)
    {
        if(LinePtr[i])                      // if this position in
        {                                   // the LinePtr array is
            free(LinePtr[i]);               // nonzero, release the
            LinePtr[i] = NULL;              // heap block, then zero
        }                                   // out the LinePtr slot
    }

    CurLine = 0;                            // initialize various
    TotLines = 0;                           // other global variables
    TopLine = 0;
}

//
// PaintLine -- paint a single line of text in the window.
// The passed line number is relative to the window, NOT to the
// total array of formatted output available to be painted.
//
VOID PaintLine(HDC hdc, INT RelLine)
{
    INT Line = RelLine + CurLine;

    if(LinePtr[Line])
        TabbedTextOut(hdc, CharX, RelLine*CharY, LinePtr[Line], 
            strlen(LinePtr[Line]), 0, NULL, 0);
}

//
// Repaint -- force repaint of all formatted output in main window
//
VOID Repaint(VOID)
{
    InvalidateRect(hFrame, NULL, TRUE);     // force repaint entire window
}

//
// SetWindowCaption -- concatenate a descriptive string with the 
// application name, then update the frame window's title bar.
// If called with NULL pointer, removes any previous description from
// the title bar, leaving only the application name.
//
VOID SetWindowCaption(TCHAR * szDescription)
{
    TCHAR szTemp[2*EXENAMESIZE+1];             

    // if no description string or no file open, display app name only
    if((szDescription == NULL) || (hFile == -1))
        SetWindowText(hFrame, szAppName);   
    else
    {                                       // otherwise...
        strcpy(szTemp, szFileName);         // get current filename
        strcat(szTemp, " - ");              // add separator
        strcat(szTemp, szDescription);      // add descriptive string
        SetWindowText(hFrame, szTemp);      // put result into title bar
    }
}

//
// UpdateProfile() --  saves the current window size and position
// and display type in the application's private INI file.
//
VOID UpdateProfile(VOID)
{
    RECT rect;
    TCHAR temp[20];

    if(IsIconic(hFrame) || IsZoomed(hFrame)) return;

    GetWindowRect(hFrame, &rect);           

    wsprintf(temp,"%d", rect.left);
    WritePrivateProfileString("Frame", "xul", temp, szIni);

    wsprintf(temp,"%d", rect.top);
    WritePrivateProfileString("Frame", "yul", temp, szIni);

    wsprintf(temp,"%d", rect.right);
    WritePrivateProfileString("Frame", "xlr", temp, szIni);

    wsprintf(temp,"%d", rect.bottom);
    WritePrivateProfileString("Frame", "ylr", temp, szIni);

    wsprintf(temp,"%d", DisplayType);
    WritePrivateProfileString("Frame", "type", temp, szIni);

    if(hFile == -1) return;

    WritePrivateProfileString("File", "filename", szFileName, szIni);
}

//
// OpenDataFile -- opens the file whose name is found in szFileName[] 
// and creates memory mapping to the file's contents.  The filename
// was previously obtained from the INI file or by a call to the
// OpenFile common dialog.
//
VOID OpenDataFile(VOID)
{
    TCHAR temp[256];

    if(hFile != -1)                         // close previous file if any
        CloseDataFile();                    // and destroy its mappings

    hFile = _lopen(szFileName, OF_READ);    // try and open the new file

    if(hFile == -1)                         // bail out if no such file
    {
        wsprintf(temp, "Can't open file: %s", szFileName);
        MessageBox(hFrame, temp, szAppName, MB_ICONSTOP | MB_OK);
        return;
    }

    FileSize = _llseek(hFile, 0, 2);        // get size of file
    
    if(FileSize == 0)                       // bail out if file is empty
    {
        MessageBox(hFrame, "File is empty!", szAppName, 
            MB_ICONSTOP | MB_OK);
        CloseDataFile();
        return;
    }

    // create file mapping object
    hMap = CreateFileMapping((HANDLE) hFile,
        (LPSECURITY_ATTRIBUTES) NULL, PAGE_READONLY, 0, 0, (LPSTR) NULL);

    if(hMap == 0)                           // bail out if no mapping object
    {
        MessageBox(hFrame, "Can't create file mapping object!", 
            szAppName, MB_ICONSTOP | MB_OK);
        CloseDataFile();
        return;
    }

    pMap = (LPSTR) MapViewOfFile(hMap, FILE_MAP_READ, 0, 0, 0);

    if(pMap == 0)                           // bail out if no mapping object
    {
        MessageBox(hFrame, "Can't map view of file!", 
            szAppName, MB_ICONSTOP | MB_OK);
        CloseDataFile();
        return;
    }

    ConfigWindow();                         // calc display parameters
    SetWindowCaption(szFileName);           // put filename in title bar
    SetHeaderPtrs();                        // set up pointers
}

//
// CloseDataFile -- close any previously opened file, destroy mappings
// if necessary.
//
VOID CloseDataFile(VOID)
{
    if(pMap)        UnmapViewOfFile(pMap);  // destroy mapping
    if(hMap)        CloseHandle(hMap);      // release mapping object
    if(hFile != -1) _lclose(hFile);         // release file handle

    hFile = -1;                             // reset everything
    pMap = NULL;
    hMap = 0;

    // remove any previous filename from title bar
    SetWindowCaption(NULL);
}

//
// SetHeaderPtrs -- validates EXE file or DLL, sets up pointers 
// to various structures and sections within the NT executable file. 
// Called after the file has been successfully opened and mapped.
// 
VOID SetHeaderPtrs(VOID)
{
    UINT i;                                 // scratch variables
    PSCNHEADER pCurScnHeader;

    // calculate address of DOS real mode (MZ) file header
    pMZHeader = (PMZHEADER) pMap;

    // calculate address of NT protected mode (PE) file header
    pPEHeader = (PPEHEADER) ((PBYTE) pMZHeader + pMZHeader->e_lfanew);

    if((pMZHeader->e_magic != IMAGE_DOS_SIGNATURE) ||
       (pPEHeader->Signature != IMAGE_NT_SIGNATURE))
    {
        MessageBox(hFrame, "Not a Windows/NT program or DLL!", szAppName,
            MB_ICONSTOP | MB_OK);
        CloseDataFile();
        return;
    }

    // calculate address of COFF File Header and Optional Header
    pCoffHeader = (PCOFFHEADER) &pPEHeader->FileHeader;
    pOptHeader = (POPTHEADER) &pPEHeader->OptionalHeader;

    // calculate address of data directory (embedded in Optional Header)
    pDataDirectory = (PDATADIR) &pOptHeader->DataDirectory;

    // calculate address of first section header
    pFirstScnHeader = (PSCNHEADER) ((PBYTE) pOptHeader + 
                      pCoffHeader->SizeOfOptionalHeader);

    // default = no sections found
    pCurScnHeader = pFirstScnHeader;
    pIdataHeader = NULL;
    pIdata = NULL;
    pEdataHeader = NULL;
    pExportDirectory = NULL;
    pRsrcHeader = NULL;
    pRsrcDirectory = NULL;

    // look through the section headers to find header for file section
    // containing import table (.idata), export table (.edata), and
    // resources (.rsrc).  For each section found, save address of
    // section header and raw data.
    for(i = 0; i < pCoffHeader->NumberOfSections; i++)
    {
        if(!strcmp(pCurScnHeader->Name, ".idata"))
        {
            pIdataHeader = pCurScnHeader;
            pIdata = (PMODULEDIR) (pMap + pIdataHeader->PointerToRawData);
        }
        else if(!strcmp(pCurScnHeader->Name, ".edata"))
        {
            pEdataHeader = pCurScnHeader;
            pExportDirectory = (PEXPORTDIR) (pMap + 
                               pCurScnHeader->PointerToRawData);
        }
        else if(!strcmp(pCurScnHeader->Name, ".rsrc"))
        {
            pRsrcHeader = pCurScnHeader;
            pRsrcDirectory = (PRSRCDIR) (pMap + 
                             pCurScnHeader->PointerToRawData);
        }

        pCurScnHeader++;
    }
}

