# hetlib

## Install steps:

### Download hetlib:
Copy modules into: c:\d\libs\het\

### LDC compiler:
* Go to	: https://github.com/ldc-developers/ldc/releases/tag/v1.41.0	
* Download	: ldc2-1.41.0-windows-x64.7z
* Unpack into	: c:\d\ldc\
* Add to PATH	: c:\D\ldc\bin\
* Verify	: ldc2 --version

### Win32 static library:
Go to	: https://visualstudio.microsoft.com/downloads/
Download	: Visual Studio Build Tools 2022  (scroll down, open a pulldown thing, download the file "vs_BuildTools.exe".)
Install	: vs_BuildTools.exe
Verify	: Find file "user32.lib" -> "c:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\um\x64\User32.Lib"

### Install a ramdrive
Search for	: Radeon Ramdisk
Install	: Radeon_RAMDisk_4_4_0_RC36.msi
Setup	: Size=256MB  Drive=Z:  Save_on_exit=No(free version)

### Enable Porojected FileSystem component in Windows:
Info	: https://learn.microsoft.com/en-us/windows/win32/projfs/enabling-windows-projected-file-system
Run PowerShell	: Enable-WindowsOptionalFeature -Online -FeatureName Client-ProjFS -NoRestart
Restart	: Only if it asks for.

### Install libwebp:
Download	: libwebp-1.6.0-windows-x64.zip
Copy into	: c:\D\libs\libwebp-1.6.0-windows-x64\
Add to PATH	: c:\D\libs\libwebp-1.6.0-windows-x64\bin\
Linker Fix	: Copy "libwebp.lib" into "c:\D\ldc\lib\"

### Install libjpeg-turbo:
Download	: libjpeg-turbo-3.1.1-vc-x64.exe
Copy into	: c:\D\libs\libjpeg-turbo64\
Add to PATH	: c:\D\libs\libjpeg-turbo64\lib\
Linker Fix	: Copy "turbojpeg-static.lib" into "c:\D\ldc\lib\"
 
### Install Vulkan SDK:
Download	: vulkansdk-windows-X64-1.4.321.0.exe
Install into	: "c:\Program Files (x86)\VulkanSDK" 
Add to PATH	: "C:\Program Files (x86)\VulkanSDK\1.4.321.0\Bin"
Verify	: glslc --version

### Install VideoLAN dynamic library (Optional)
Go to	: https://www.videolan.org/vlc/download-windows.html
Install	: vlc-3.0.21-win64.exe 
Add to PATH : c:\Program Files\VideoLAN\VLC\
Verify	: where libvlc.dll