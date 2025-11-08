# DIDE & hetlib

## Install steps:

### Download hetlib:
__Copy modules into__	: c:\D\libs\het\

### Download DIDE:
__Copy modules into__	: c:\D\projects\DIDE\
__Notes__	: 
<<<<<<< HEAD
* If you rename "dide.exe" to "dide_x.exe" it will save the workspace config ".dide" file under that different name next to the exe. This is how to create multiple workspaces atm.
=======
* If you rename "dide.exe" to "dide_x.exe" it will save the workspace config .ini file under that different name next to the exe. This is how to create multiple workspaces atm.
>>>>>>> 22f3fbd37bdabb1774a8c426afb04f455dae87db
* It will require a Z: drive for temp files (use a ramdrive!). And it will need Projected FileSystem to be able to handle external compilers, like glslc.exe.
* It will create an "WebCache" directory next to the exe whenever the online help function downloads something.

### LDC compiler:
* __Go to__	: https://github.com/ldc-developers/ldc/releases/tag/v1.41.0	
* __Download__	: ldc2-1.41.0-windows-x64.7z
* __Unpack into__	: c:\D\ldc\
* __Add to PATH__	: c:\D\ldc\bin\
* __Verify__	: ldc2 --version

### Win32 static library:
* __Go to__	: https://visualstudio.microsoft.com/downloads/
* __Download__	: Visual Studio Build Tools 2022  (scroll down, open a pulldown thing, download the file "vs_BuildTools.exe".)
* __Install__	: vs_BuildTools.exe
* __Verify__	: Find file "user32.lib" -> "c:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\um\x64\User32.Lib" (something like this)

### Install a ramdrive
* __Search for__	: Radeon Ramdisk
* __Install__	: Radeon_RAMDisk_4_4_0_RC36.msi
* __Setup__	: Size=256MB  Drive=Z:  Save_on_exit=No(free version)

### Enable Porojected FileSystem component in Windows:
* __Info__	: https://learn.microsoft.com/en-us/windows/win32/projfs/enabling-windows-projected-file-system
* __Run PowerShell__	: Enable-WindowsOptionalFeature -Online -FeatureName Client-ProjFS -NoRestart
* __Restart__	: Only if it asks for.

### Install libwebp:
* __Download__	: libwebp-1.6.0-windows-x64.zip
* __Copy into__	: c:\D\libs\libwebp-1.6.0-windows-x64\
* __Add to PATH__	: c:\D\libs\libwebp-1.6.0-windows-x64\bin\
* __Linker Fix__	: Copy "libwebp.lib" into "c:\D\ldc\lib\"

### Install libjpeg-turbo:
* __Download__	: libjpeg-turbo-3.1.1-vc-x64.exe
* __Copy into__	: c:\D\libs\libjpeg-turbo64\
* __Add to PATH__	: c:\D\libs\libjpeg-turbo64\lib\
* __Linker Fix__	: Copy "turbojpeg-static.lib" into "c:\D\ldc\lib\"
 
### Install Vulkan SDK:
* __Download__	: vulkansdk-windows-X64-1.4.321.0.exe
* __Install into__	: "c:\Program Files (x86)\VulkanSDK" 
* __Add to PATH__	: "C:\Program Files (x86)\VulkanSDK\1.4.321.0\Bin"
* __Verify__	: glslc --version

### Install VideoLAN dynamic library (Optional)
* __Go to__	: https://www.videolan.org/vlc/download-windows.html
* __Install__	: vlc-3.0.21-win64.exe 
* __Add to PATH__ : c:\Program Files\VideoLAN\VLC\
* __Verify__	: where libvlc.dll