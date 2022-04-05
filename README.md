# hetlib

Setup:
- HETLIB location: C:\D\libs\het
- DIDE and HLDC location: C:\D\dide\win32\debug\
- Install VisualStudio C++ 2017 Community
- Install VisualD with LDC 1.28.0
- LDC executable path must be: c:\d\ldc2\bin\ldc2.exe
- Copy additional static libraries to: c:\d\ldc2\lib64
- Install AMD RamDrive 128MB Z: with TEMP directory, clear on exit
- Task Scheduler/My/dide -> C:\D\dide\win32\debug\dide.exe
- Task Scheduler/My/hldc -> C:\D\dide\win32\debug\hldc.exe daemon -v -w=z:\temp
- launch shortcut: C:\Windows\System32\schtasks.exe /RUN /TN "My\dide"


VisualD solution setup with multiple packages:
- Each package should be in a separate solution_project. target=library.
- The main project is also in a separate solution_project. target=exe
- module file names must be renamed to lowercase (the same case as their module identifiers).
- SUBSYSTEM is always CONSOLE.
- het.win.main() should be called from the main module manually: void main(string[] args){ het.win.main(args); }
- dependencies must be set manually, primary project must be selected for the debugger.
