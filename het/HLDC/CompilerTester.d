//@exe
//@import c:\d\

module compilertester;

import hetlib.utils, std.process;

/**
 * DLang Compiler Tester
 *
 * This is a test workbench for testing various dlang compilation techniques:
 *   - compiler         : DMD/LDC
 *   - machine          : x86/x64
 *   - purpose          : debug/release
 *   - interface        : console/windowed
 *   - way of build     : complete/incremental
 * Also does other things:
 *   - finding compiler/linker executables and libraries automatically.
 *   - measuring time (complete/incremental/cached_incremental*) *only one module is changed
 *   - run a batch of tests
 * The purpose of this test application is to generate know-how info used by the HDMD builder.
 */

enum
  pathDMD       = `c:\D\dmd2\`,
  pathLDC       = `c:\D\ldc2\`,
  fnMSLink      = `c:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.12.25827\bin\Hostx64\x64\link.exe`;

//derived filenames
string fnDMD     => combinePath(pathDMD, `windows\bin\dmd.exe`    );
string fnOptLink => combinePath(pathDMD, `windows\bin\link.exe`   );
string fnLDC     => combinePath(pathLDC, `bin\ldmd2.exe`          );

enum
  pathSource            = `testSources\`,
  fnConsoleSource       = `testConsole.d`,
  fnWindowedSources     = [`testWindowed.d`,
                           `testlib\OpenGL.d`,
                           `testlib\InputManager.d`,
                           `testlib\DebugClient.d`,
                           `testlib\Win.d`,
                           `testlib\utils.d`,
                           `testlib\Drawing.d`,
                           `testlib\View.d`,
                           `testlib\Geometry.d`,
                           `testlib\PlotFont.d`,
                           `testlib\Bitmap.d`,
                           `testlib\package.d`];



string[] makeLDCLinkerParams(string output, string[] objs, int bits){
  string[] res;

  res = [`/NOLOGO`, `/OPT:REF`, `/OPT:ICF`, `/DEFAULTLIB:libcmt`, `/DEFAULTLIB:libvcruntime`, `/OUT:`~output], objs, ]
         `/LIBPATH:`~LDCBinPath~`../lib`~(machine==Machine.x86 ? `32` : `64`),
phobos2-ldc.lib
druntime-ldc.lib
kernel32.lib
user32.lib
gdi32.lib
winspool.lib
shell32.lib
ole32.lib
oleaut32.lib
uuid.lib
comdlg32.lib
advapi32.lib

}


enum Compiler{ DMD, LDC }
enum Machine { x86, x64 }

/// buildConfig struct: able to hold all the different types of compilation properties
struct BuildConfig{
  Compiler      compiler        ;
  bool          windowed        ;
  Machine       machine         ;
  bool          release         ,
                incremental     ;

  string toString(){
    return format("%s_%s%s_%s_%s",
                  to!string(compiler),
                  windowed ? "WIN" : "CON",
                  machine==Machine.x86 ? 32:64,
                  release ? "REL" : "DBG",
                  incremental ? "INC" : "ALL");
  }

  private void run(const string[][] cmdLines){
    string[] sOutput;
    int res;

    foreach(c; cmdLines) writeln(">", c.join(' '));

    res = spawnProcessMulti(cmdLines, null, sOutput);
    writeln("\33\17RESULT=", res, "\33\7");
    if(res) writeln("\33\14"~sOutput.join~"\33\7");
    enforce(!res, sOutput.join);
  }

  void build(){
    writeln("\33\17Building: ", toString, "\33\7");

    //Get a list of source files. First one is the executable.
    string[] sources = windowed ? fnWindowedSources
                                : [fnConsoleSource];
    sources = sources.map!(a=>appPath~pathSource~a).array;
    sources.each!(a=>enforce(fileExists(a), "Source file not found: "~a));

    //select compiler
    string[] compilerCMD;
    final switch(compiler){
      case Compiler.DMD: compilerCMD ~= fnDMD; break;
      case Compiler.LDC: compilerCMD ~= fnLDC; break;
    }
    enforce(fileExists(compilerCMD[0]), "Compiler executable not found.");

    //debug or release
    compilerCMD ~= release ? ["-O", "-release", "-inline", "-boundscheck=off"]
                           : ["-debug"];
/*    final switch(compiler){
      case Compiler.DMD: break;
      case Compiler.LDC: enforce(false, "not impl"); break;
    }*/

    //add include path. it's a must for the library
    compilerCMD ~= "-I"~appPath~pathSource;

    //apply 32/64bit
    string[] linkerCMD;
    final switch(machine){
      case Machine.x86:
        compilerCMD ~= ["-m32"];
      break;
      case Machine.x64:
        compilerCMD ~= ["-m64"];
        compilerCMD ~= ["-Lkernel32.lib", "-Luser32.lib"];  //todo:kiszedni a libeket lentrol is
      break;
    }

    //compile
    const exeFileName = appPath ~ pathSource ~ toString ~ ".exe",
          complete = !incremental;

    if(complete){ //complete build
      run([compilerCMD~exeFileName~sources]);
    }else{ //incremental build
      string[][] c;
      foreach(s; sources) c ~= compilerCMD~"-c"~"-op"~"-allinst"~s;
      run(c);

      //link
      auto objs = sources.map!(a=>changeFileExt(a, "obj")).array;
      final switch(machine){
        case Machine.x86:
          linkerCMD ~= [fnOptLink]~objs.map!(x=>`"`~x~`"`).array~[ ",", `"`~exeFileName~`"`, ",,", "/noi", ";"];
          break;           //todo meg kell csinalni a sajat commandline osszerakot. Ami a D-s valtozaton felul az MSLinker /OUT:"formatumaval is megy"
        case Machine.x64:
          auto libs = ["legacy_stdio_definitions.lib", "kernel32.lib", "user32.lib", "opengl32.lib"];

/+Todo: Ezt a sok kakit innen lehet kiszedni:
  "c:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\VsDevCmd.bat"
  de inkabb egy intelligens * path-os keresot kene ra csinalni.
  pl:
    c:\Program Files (x86)\Windows Kits\10\Lib\10.0.*\um\x64`,
    c:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.*\lib\x64`,
+/

          auto libPaths = [
            machine==Machine.x64 ? (compiler==compiler.DMD ? `c:\D\dmd2\windows\lib64`  : `c:\D\ldc2\lib64`)
                                 : (compiler==compiler.DMD ? `c:\D\dmd2\windows\lib`    : `c:\D\ldc2\lib32`),
            `c:\Program Files (x86)\Windows Kits\10\Lib\10.0.16299.0\um\x64`,
            `c:\Program Files (x86)\Windows Kits\10\Lib\10.0.16299.0\ucrt\x64`,
            `c:\Program Files (x86)\Windows Kits\10\Lib\10.0.16299.0\um\x64`,
            `c:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.12.25827\lib\x64`,
          ].map!(a=>`/LIBPATH:"`~a~`"`).array;

          //if(compiler==Compiler.LDC) libs ~= ["druntime-ldc.lib", "phobos2-ldc.lib"];

          linkerCMD ~= [`"`~fnMSLink~`"`]~["/MACHINE:X64", `/OUT:"`~exeFileName~`"`] ~ libPaths ~ objs.map!(x=>`"`~x~`"`).array ~ libs;
          break;
      }

      writeln(linkerCMD.join(' '));

      auto a = executeShell(linkerCMD.join(' '));
      int res = a.status;
      writeln("\33\17RESULT=", res, "\33\7");
      if(res) writeln("\33\14"~a.output~"\33\7");
      enforce(!res, a.output);

      /*writeln("--------------------");
      writeln(fileReadStr("a.txt", false));
      fileDelete("a.txt", false);*/

    }

  }


}






void main(string[] args){
  application.runConsole(args, {
//    auto  bc = BuildConfig(Compiler.DMD, true, Machine.x64, true, false); bc.build;

    foreach(compiler; [Compiler.LDC])
    foreach(windowed; [false, true])
    foreach(machine; [Machine.x64])
    foreach(release; [false])
    foreach(incremental; [true])
    {
      auto  bc = BuildConfig(compiler, windowed, machine, release, incremental);
      bc.build;
    }
  });
}
