#include <windows.h>
 
long FAR PASCAL WndProc (HWND, WORD, WORD, LONG);
 
/**********************************************************
  WinMain starts the program.
 **********************************************************/
 
int PASCAL WinMain (HANDLE hInstance, HANDLE hPrevInstance,
                    LPSTR lpszCmdLine, int nCmdShow)
{
    static char szClassName[] = "SysIcons";
    WNDCLASS wndclass;
    HWND hwnd;
    MSG msg;
 
    if (!hPrevInstance) {
        wndclass.style = 0;
        wndclass.lpfnWndProc = (WNDPROC) WndProc;
        wndclass.cbClsExtra = 0;
        wndclass.cbWndExtra = 0;
        wndclass.hInstance = hInstance;
        wndclass.hIcon = LoadIcon (NULL, IDI_ASTERISK);
        wndclass.hCursor = LoadCursor (NULL, IDC_ARROW);
        wndclass.hbrBackground = (HBRUSH) COLOR_APPWORKSPACE + 1;
        wndclass.lpszMenuName = (LPCSTR) NULL;
        wndclass.lpszClassName = szClassName;
 
        RegisterClass (&wndclass);
    }
 
    hwnd = CreateWindow (szClassName,
            "System Icons", WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            CW_USEDEFAULT, CW_USEDEFAULT,
            NULL, NULL, hInstance, NULL);
 
    ShowWindow (hwnd, nCmdShow);
    UpdateWindow (hwnd);
 
    while (GetMessage (&msg, NULL, 0, 0))
            DispatchMessage (&msg);
 
    return msg.wParam;
}
 
/**********************************************************
  WndProc processes messages to the main window.
 **********************************************************/
 
long FAR PASCAL WndProc (HWND hwnd, WORD message,
                         WORD wParam, LONG lParam)
{
    static HICON hIcon[5];
    PAINTSTRUCT ps;
    HDC hdc;
    int i;
 
    switch (message) {
 
    case WM_CREATE:
        // Obtain handles to the five system icons
        hIcon[0] = LoadIcon (NULL, IDI_APPLICATION);
        hIcon[1] = LoadIcon (NULL, IDI_EXCLAMATION);
        hIcon[2] = LoadIcon (NULL, IDI_ASTERISK);
        hIcon[3] = LoadIcon (NULL, IDI_HAND);
        hIcon[4] = LoadIcon (NULL, IDI_QUESTION);
        return 0;
 
    case WM_PAINT:
        // Draw the icons
        hdc = BeginPaint (hwnd, &ps);
        for (i=0; i<5; i++)
            DrawIcon (hdc, (i*72)+32, 32, hIcon[i]);
        EndPaint (hwnd, &ps);
        return 0;
 
    case WM_DESTROY:
        PostQuitMessage (0);
        return 0;
    }
    return DefWindowProc (hwnd, message, wParam, lParam);
}
