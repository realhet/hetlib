import core.sys.windows.windows;
import core.sys.windows.winuser;

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    MessageBoxA(null, "Hello, Win32!", "D Language", MB_OK);
    return 0;
}