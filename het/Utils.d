module het.utils;

__gshared logFileOps = false;


pragma(lib, "ole32.lib"); //COM (OLE Com Object) initialization is in utils.d, not in win.d

//todo: msvcrt.lib(initializers.obj): warning LNK4098: defaultlib 'libcmt.lib' conflicts with use of other libs; use /NODEFAULTLIB:library
     //https://stackoverflow.com/questions/3007312/resolving-lnk4098-defaultlib-msvcrt-conflicts-with

//todo: UTILS lots of todes commented out, because of the compile log is small
/+
//todo: IDE: % as postFix operator: 25% -> (25)*.01
//todo: IDE: visszajatszo debugger/logger
//todo: IDE syntax highlight control chars in "" and ''. Also format %f in format strings

//todo: error display: hibas parameterlistanal a jot meg a rosszat egymas melle parositani, hogy ne guvvadjon ki a szemem.

//todo: uj todo kategoria: //fixme: //bug: if something is fucked up. todo is for new stuff
//todo: DIDE: Hibauzenetben a fileok elerhetove tetele: "Module not found: hetlib\debugclient.d referenced from: c:\d\libs\het\utils.d"
//todo: legyen //bug:comment is!
//todo: textformatter: egy grafikus ize, amivel a writefln()-t meg lehet formazni: tobbsoros is lehessen, meg egerrel menjen. Szinezni is lehessen!
//todo: editor: a commenteket nyelvtani elementhez kene kapcsolni. Es akkor mar lebeghetnenek, mint egy gondolatbuborek. Haszonlo szerkeszthetoseg kene, mint az onshape commentjeinel.
//todo: exception mutatasanal fatal exception kezelese: amikor a program mindenkeppen megall utana.
//todo: syntax level visualizalas 3d kiemelkedo effekttel.
//todo: syntax: visualize number literals: ad thousands and at 64K ranges. 0x12345678 -> 0x|1234|5678
//todo: editor: irja ki a selection hosszat, rect-meretet!
//todo: syntax: 0x2ef7fc2c0b4e5915; ennel bugzik a binary 0 1 highlight

//todo: az absolut modulneveknek a ctrlklikket kezelni kell! Ha ugyanaz a prefix van az ugraskor, mint ami a current modul, akkor nem kell uj konyvtarban keresni
//todo: legyen nyilvantartva a main project es abban a searchpath es a navigalas akkor mehet azokhoz relativan is

//todo: todo kijelzes: el vannak csuszva a sorok. multiline string bekavarhat.
//todo: todo kijelzes: legyen szurke a text, az errortype kozpontositas utan

//todo: linker, dmd.exe elerese absolute path-al a builderbol.
//todo: DIDE Ctrl+F amikor raugrik egy talalatra, mutassa a korulotte levo sorokat is, mint a gotoError()

//todo: syntax highlight std.string: ne legyen alap tipus szine a stringnek az importban
//todo: map file alapjan az accessviolat visszakuldeni a DIDE-be.
//todo: editor mutassa az indent hibakat!

//todo: editor.exception: mutassa az std\stdio.d(404,1): Exception: blabla jellegu hibakat!

//todo: editor: tablazatos kod rendberakasa
/*Poti("PolyOpt SmallSegLen"     , polyOpt_SmallSegLen        , 1        , 500     , 10 ),
  Poti("PolyOpt Epsilon"           , polyOpt_Epsilon            , 0        , 500     ,  1 ),
  Poti("PolyOpt parallelThreshold"  , polyOpt_ParallelThreshold    , 0.0        , 1.0     ,  0.01 ),
  Poti("PolyOpt Removable Seg Len"  , polyOpt_tinySegLen       , 1        , 300     ,  1 ),
  Poti("PolyOpt Seg Len Mult"  , polyOpt_tinySegLocalErrorFactor       , 0        , 20     ,  0.5 ), */

//todo: a bookmarkok is menjenek a tartalomjegyzek melle
//todo: tokenizer/syntax highlighter bexarik a unicode-tol

//todo: version stringek osszegyujtese a programban es az IDE ajanlja fel, hogy mik a lehetosegek!
//todo: editor cursor over bigComments
//todo: editor: amikor kijelolok egy szovegreszt, szurkevel jelolje a kepernyon az ugyanolyan szovegreszeket! Egy special keyre odarakhatna a tobbihez is egy-egy kurzort
//todo: editor: accumulation clipboard: hozzacsapja a kijelolest a clipboard vegehez. Amikor sok szirszard szedek ossze es egy helyre akarom azokat rakni.
//todo: linker errort detektalni: Kell hozza csinalni egy classt, aminek csak forwardolva vannak a dolgai. " Error " a trigger. Elozo sor is kell. OPTLINK, Copyright, http://www.digitalmars kezdetu sorokkal nem foglalkozni.
//todo: preprocess: implement with(a,b,c,...)
//todo: multiline todo /* es / + commentekre

//todo: logging automatizalasa class osszes functionjara

//todo: ide: o'rajel summa'zo': a soroktol utasitasoktol jobbra irt szamokat osszeadogatja.
//todo: ide/debug: consolera vagy logba iraskor latszodjon a kibocsajto utasitas helye.
//todo: a main()-t automatikusan belerakni egy app.runconsole-ba

//todo: File.write doesn't creates the path appPath~\temp
//todo: nyelvi bovites: ismerje fel a szamoknal az informatikai kilo, mega, giga, tera postfixeket! A decimalisakra ott van az e3 e6 e9 e12.

//todo: az uj tokenizerben meg syntax highlighterben az x"string"-et hexString-et jelolni.
//todo: View2D: zoom to cursort es a nemlinearis follow()-ot osszehozni.

//todo: IDE: ha nem release build van forditva, akkor az assert/in/out/invariant legyen jelolve szurkevel!
+/

// Imports /////////////////////////////

// std imports
public import std.string, std.array, std.conv, std.typecons, std.range, std.format, std.traits, std.meta, core.stdc.string; //het.math also imports std.algorithm, std.functional
public import std.utf;
public import std.uni : byCodePoint, isAlpha, isNumber, isAlphaNum;
public import std.uri: urlEncode = encode, urlDecode = decode;
public import std.process : environment, thisThreadID;
public import std.zlib : compress, uncompress;
public import std.stdio : stdin, stdout, stderr, readln, StdFile = File, stdWrite = write;
public import std.bitmanip : swapEndian, BitArray, bitfields, bitsSet;

import std.encoding : transcode, Windows1252String;
import std.exception : stdEnforce = enforce;
import std.getopt;

// hetlib imports
public import het.debugclient;
public import het.math;
public import het.color;

// Windows imports
public import core.sys.windows.windows : GetCurrentProcess, SetPriorityClass,
  HIGH_PRIORITY_CLASS, REALTIME_PRIORITY_CLASS, NORMAL_PRIORITY_CLASS,
  BELOW_NORMAL_PRIORITY_CLASS, ABOVE_NORMAL_PRIORITY_CLASS, IDLE_PRIORITY_CLASS, //, PROCESS_MODE_BACKGROUND_BEGIN, PROCESS_MODE_BACKGROUND_END;
  HRESULT, HWND, GUID, SYSTEMTIME, FILETIME, MB_OK, STD_OUTPUT_HANDLE, HMODULE,
  GetCommandLine, ExitProcess, GetConsoleWindow, SetConsoleTextAttribute, SetConsoleCP, SetConsoleOutputCP, ShowWindow,
  SetFocus, SetForegroundWindow, GetForegroundWindow,
  SetWindowPos, GetLastError, FormatMessageA, MessageBeep, QueryPerformanceCounter, QueryPerformanceFrequency,
  GetStdHandle, GetTempPathW, GetFileTime, SetFileTime,
  FileTimeToSystemTime, GetLocalTime, Sleep, GetComputerNameW, GetProcAddress,
  SW_SHOW, SW_HIDE, SWP_NOACTIVATE, SWP_NOOWNERZORDER, FORMAT_MESSAGE_FROM_SYSTEM, FORMAT_MESSAGE_IGNORE_INSERTS,
  GetSystemTimes, MEMORYSTATUSEX, GlobalMemoryStatusEx,
  HICON;

import std.windows.registry, core.sys.windows.winreg, core.thread, std.file, std.path,
  std.json, std.digest.digest, std.parallelism, core.runtime;

public import core.sys.windows.com : IUnknown, CoInitialize, CoUninitialize;

// MSVC compatibility /////////////////////////

// __iob_func - needed for turbojpeg
// https://stackoverflow.com/questions/30412951/unresolved-external-symbol-imp-fprintf-and-imp-iob-func-sdl2
extern (C){
  import core.stdc.stdio : FILE;
  shared FILE[3] __iob_func;
}

private void init__iob_func(){
  import core.stdc.stdio : stdin, stdout, stderr;
  __iob_func = [*stdin, *stdout, *stderr];
}

// Obj.Destroy is not clearing the reference
void free(T)(ref T o)if(is(T==class)){
  if(o !is null){
    o.destroy;
    o = null;
  }
}

void SafeRelease(T:IUnknown)(ref T i){
  if (i !is null){
    i.Release;
    i = null;
  }
}

////////////////////////////////////////////////////////////////////////////////
///  Application                                                             ///
////////////////////////////////////////////////////////////////////////////////

__gshared HWND mainWindowHandle; //het.win fills it

__gshared struct application{
__gshared static private:
  bool initialized, finalized;

  string[] arg_;
  void initArgs(){
    arg_ = splitCommandLine(toStr(GetCommandLine));
  }

  KillerThread killerThread;

__gshared static public:///////////////////////////////////////////////////////////////////
  void function() initFunct;

  auto argc()            { return arg_.length; }
  string arg(size_t idx){
    if(arg_.empty) initArgs;
    if(idx<argc)return arg_[idx]; else return "";
  }
  alias args = arg;


  void exit(int code=0){ //immediate exit
    try{ finalize; }catch(Throwable){}
    ExitProcess(code);
  }

  void initialize(){
    if(chkSet(initialized)){
      SetPriorityClass(GetCurrentProcess, HIGH_PRIORITY_CLASS);

      dbg; //start it up
      killerThread = new KillerThread;  killerThread.start;
      console.handleException({ globalInitialize; });
    }
  }

  void finalize(){
    if(!initialized) return;
    if(chkSet(finalized)){
      console.handleException({ globalFinalize; });
      killerThread.stop;
      //dont! -> destroy(killerThread); note: Sometimes it is destroyed automatically, and this causes an access viole reading from addr 0
    }else{ enforce(false, "Application is already finalized"); }
  }

  int runConsole(void delegate() dg){
    return runConsole(null, dg);

    //todo: replace exception handler (no info on it yet)
    //todo: replace main() with -> void main(string[] args){ application.runConsole(args, { });}
  }

  int runConsole(string[] args, void delegate() dg){
    initialize;
    arg_ = args;
    auto ret = console.handleException(dg);
    finalize;
    //here we wait all threads. In windowed mode we don't
    return ret;
  }

  @property HWND handle() { return mainWindowHandle; }
}


// Console //////////////////////////////////////////////////////////////////////

struct console{  //todo: ha ezt a writeln-t hivja a gc.collect-bol egy destructor, akkor crash.
static private:
  __gshared bool visible_;
  __gshared bool exceptionHandlerActive_;
  HWND hwnd(){
    __gshared static void* handle;
    if(handle is null){
      handle = GetConsoleWindow;
    }
    return handle;
  }

  void textAttr(int attr){
    flush;
    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), cast(ushort)attr);
  }

  void indentAdjust(int param){
    switch(param){
      case 0: indent = 0; break;
      case 1: indent++; break;
      case 2: indent--; break;
      default:
    }
    //stdWrite("[INDENT <- %d]".format(indent));
  }

  struct Recorder{
    string recordedStr;
    bool recording;

    // recording ------------------
    void start(){
      if(recording) WARN("Already recording.");
      recording = true;
    }

    string stop(){
      if(!recording) WARN("Did not started recording.");
      recording = false;
      auto a = recordedStr; //todo: sync fails here
      recordedStr = "";
      return a;
    }
  }
  __gshared Recorder recorder;

  void myWrite(string s){

    void wr(string s) {
      if(indent>0){
        auto si = "\n" ~ "    ".replicate(indent.min(20));
        s = s.replace("\n", si);
      }

      stdWrite(s);
      if(recorder.recording) synchronized recorder.recordedStr ~= s;
    }

    while(!s.empty){
      auto i = s.countUntil!"a>='\33' && a<='\34'";
      if(i<0) { wr(s); break; } //no escapes at all
      if(i>0) { wr(s[0..i]); s = s[i..$]; } //write test before the escape
      //here comes a code
      if(s.length>1){
        auto param = cast(int)s[1];
        switch(s[0]){
          case '\33': textAttr(param); break;
          case '\34': indentAdjust(param); break;
          default:
        }
        s = s[2..$];
      }else{
        s = s[1..$]; //bad code, do nothing
      }
    }
    flush; //it is needed
  }

static public:
  __gshared int indent = 0;

  void flush(){ stdout.flush; }

  void setUTF8(){
    const cp = 65001;
    SetConsoleCP(cp);
    SetConsoleOutputCP(cp);
  }

  void show()                   { if(chkSet  (visible_)){ ShowWindow (hwnd, SW_SHOW); } }
  void hide(bool forced=false)  { if(chkClear(visible_) || forced) ShowWindow (hwnd, SW_HIDE); }

  void setFocus()               { SetFocus(hwnd); } //it's only keyboard focus
  void setForegroundWindow()    { show; SetForegroundWindow(hwnd); }
  bool isForeground()           { return GetForegroundWindow == hwnd; }   //this 3 funct is the same in Win class too.

  void setPos(int x, int y, int w, int h){ SetWindowPos(hwnd, null, x, y, w, h, SWP_NOACTIVATE | SWP_NOOWNERZORDER); }

  @property bool visible()              { return visible_; }
  @property void visible(bool vis)      { vis ? show : hide; }

  @property bool exceptionHandlerActive() { return exceptionHandlerActive_; }

  int handleException(void delegate() dg){
    if(exceptionHandlerActive_){
      dg();
    }else{
      try{
        exceptionHandlerActive_ = true;
        dg();
        exceptionHandlerActive_ = false;
      }catch(Throwable e){
        showException(e.toString);
        exceptionHandlerActive_ = false;
        return -1;
      }
    }
    return 0;
  }
}

void write(T...)(auto ref T args)
{
  console.show;
  foreach(const s; args)
    console.myWrite(to!string(s)); //calls own write with coloring
}

void writeln (T...)(auto ref T args){ write(args, '\n'); }
void writef  (T...)(string fmt, auto ref T args){ write(format(fmt, args)); }
void writefln(T...)(string fmt, auto ref T args){ write(format(fmt, args), '\n'); }

void print(T...)(auto ref T args){ //like in python
  string[] s;
  static foreach(a; args){{
    s ~= a.text;
  }}
  writeln(s.filter!(s => s.length).join(' '));
}

void safePrint(T...)(auto ref T args){ //todo: ez nem safe, mert a T...-tol is fugg.
  synchronized
    print(args);
}


// Error handling

string getLastErrorStr()
{
  auto e = GetLastError;
  if(!e) return ""; //no error
  char[512] error;
  FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, null, e, 0, error.ptr, error.length, null );
  return toStr(&error[0]);
}

alias raiseLastError = throwLastError;
void throwLastError(string file = __FILE__, int line = __LINE__, string fn = __FUNCTION__)
{
  auto error = getLastErrorStr;
  enforce(error=="", "LastError: "~error, file, line, fn);
}

// Cmdline params ///////////////////////////////////////////

string helpText(in GetoptResult opts){
  return opts.options.map!(o => format(`  %-20s %s`, [o.optShort, o.optLong].join(" "), o.help)).join("\n");
}

auto parseOptions(T)(string[] args, ref T options, Flag!"handleHelp" handleHelp){
  /* exampls struct: struct Options {
    @(`Exits right after a solution.`)                                                    EarlyExit = false;
    @(`t|BenchmarkTime = Minimum duration of the benchmark. Default: $DEFAULT$ sec`)      BenchmarkMinTime = 12;
    @(`WFPerCU = Number of WaveFronts on each Compute Units. Default: $DEFAULT$`)         WFPerCU = 8;
    @(`p = Calls the payload outside the mixer.`)                                         SeparatePayload = false;
  }*/

  string[] getoptLines = getStructInfo(options).getoptLines("options");
  auto opts = mixin("getopt(args, std.getopt.config.bundling,\r\n"~getStructInfo!T.getoptLines("options").join(",")~")");

  if(opts.helpWanted && handleHelp){
    writeln(opts.helpText);
    application.exit;
  }

  return opts;
}

// Exception handling ///////////////////////////////////////

T enforce(T)(T value, lazy string str="", string file = __FILE__, int line = __LINE__, string fn=__FUNCTION__)  //__PRETTY_FUNCTION__ <- is too verbose
{
  if(!value) stdEnforce(0, str, file, line);
  return value;
}

///this version compares 2 values and shows the difference too
void enforceDiff(T)(in T expected, in T actual, lazy string caption="", string file = __FILE__, int line = __LINE__){
  if(expected == actual) return;

  auto exp  = expected.text,
       act  = actual.text,
       diff = strDiff(exp, act),
       capt = caption=="" ? "Test failed:" : caption;
  enforce(0, format!"%s\n  Exp : %s\n  Act : %s\n  Diff: %s"(capt, exp, act, diff), file, line);
}

template CustomEnforce(string prefix){
  T enforce(T)(T value, lazy string str="", string file = __FILE__, int line = __LINE__, string fn=__FUNCTION__)  //__PRETTY_FUNCTION__ <- is too verbose
  {
    if(!value) stdEnforce(0, "["~fn~"()] "~prefix~" "~str, file, line);
    return value;
  }
}

void raise(string str="", string file = __FILE__, int line = __LINE__, string fn=__FUNCTION__){
  enforce(0, str, file, line, fn);
}

void hrChk(HRESULT res, lazy string str = "", string file = __FILE__, int line = __LINE__, string fn=__FUNCTION__){
  if(res==0) return;

  string h; switch(res){
    case 0x80004001: h="E_NOTIMPL"      ; break;
    case 0x80004002: h="E_NOINTERFACE"  ; break;
    case 0x80004003: h="E_POINTER"      ; break;
    case 0x80004004: h="E_ABORT"        ; break;
    case 0x80004005: h="E_FAIL"         ; break;
    case 0x8000FFFF: h="E_UNEXPECTED"   ; break;
    case 0x80070005: h="E_ACCESSDENIED" ; break;
    case 0x80070006: h="E_HANDLE"       ; break;
    case 0x8007000E: h="E_OUTOFMEMORY"  ; break;
    case 0x80070057: h="E_INVALIDARG"   ; break;
    default: h = "%X".format(res);
  }

  enforce(false, "HRESULT=%s %s".format(h, str), file, line, fn);
}

void beep(int MBType = MB_OK){
  //pragma(lib, "Winmm"); import core.sys.windopws.mmsystem PlaySound("c:\Windows\media\tada.wav", NULL, SND_FILENAME | SND_ASYNC);
  MessageBeep(MBType);
}

string extendExceptionMsg(string lines){

  static string processLine(string line){
    if(line.isWild("0x????????????????")){
      auto addr = cast(void*) line[2..$].to!ulong(16);
      auto mi = getModuleInfoByAddr(addr);
      line ~= " " ~ mi.location;

      if(line.isWild(`*"*.d", *`)){ //search src line locations in the parameters
        auto fn = wild[1]~".d";
        int srcLine;
        try{ auto tmp = wild[2]; srcLine = parse!int(tmp); }catch(Throwable){}
        if(srcLine>0 && File(fn).exists)
          line = format!"%s(%s,1): Error: %s"(fn, srcLine, line);
      }
      return line;
    }
    if(line.isWild("*@*.d(*): *")){ //exception
      return format!"%s.d(%s,1): Error: %s: %s"(wild[1], wild[2], wild[0], wild[3]);
    }
    return line;
  }

  return lines.split("\n").map!processLine.filter!(not!empty).join("\n");
}

void showException(string s) nothrow
{
  try{
    string err = extendExceptionMsg(s);

    if(dbg.isActive){
      dbg.handleException(err);
    }else{
      import core.sys.windows.windows;
      MessageBeep(MB_ICONERROR); //idegesit :D
      writeln("\33\14"~err~"\33\7");
      writeln("Press Enter to continue...");
      console.setForegroundWindow;
      readln;
      application.exit;
    }
  }catch(Throwable o){}
}

void showException(Throwable o) nothrow
{
  string s;
  try{ s = o.toString(); }catch(Throwable o){}
  showException(s);
}

//cuts off traqce info
string simplifiedMsg(Throwable t){
  string[] s;
  foreach(line; t.msg.split("\n").map!strip){ //todo: use countUntil here!
    if(line == "") break;
    s ~= line;
  }
  return s.join("\n");
}


void forceAssertions(string file=__FILE__, int line=__LINE__)(){ //todo: this crap drops an ILLEGAL INSTRUCTION exception. At least it works...
  enforce(ignoreExceptions({ assert(false); }), "Enable DEBUG compiler output! %s(%s)".format(file, line));
}

// Filter for OS exceptions //////////////////////////

pragma(lib, "Psapi.lib");

class ExeMapFile{
  ulong baseAddr;

  struct Rec{
    string mangledName;
    ulong addr;
    string objName;

    string name(){
      import std.demangle;
      return demangle(mangledName);
    }
  }

  Rec[] list;

  this(File fn = File("$ThisExeFile$")){

    if(fn.fullName == "$ThisExeFile$")
      fn = appFile.otherExt("map");

    foreach(line; fn.readLines(false)){
      auto p = line.split.array;
      switch(p.length){
        case 5:{
          if(p[0]=="Preferred") baseAddr = p[4].to!ulong(16);
        } break;
        case 6:{
          if(p[0].isWild("0001:*")){
            list ~= Rec(p[1], p[2].to!ulong(16) - baseAddr, p[$-1]);
          }
        } break;
        /*case 4:{ //this is DATA, not CODE
          if(p[0].isWild("0002:*") && !p[2].startsWith(".")){
            list ~= Rec(p[1], p[2].to!ulong(16) - baseAddr, p[$-1]);
          }
        } break;*/
        default:
      }
    }

    list = list.sort!"a.addr < b.addr".array; //not sure if already sorted
  }

  string locate(ulong relAddr){
    foreach(idx; 1..list.length)
      if(list[idx-1].addr <= relAddr && list[idx].addr > relAddr)
        return list[idx-1].name;
    return "";
  }
}


alias exeMapFile = Singleton!ExeMapFile;

auto exceptionCodeToStr(uint code){
  import core.sys.windows.windows;
  enum names = ["ACCESS_VIOLATION", "DATATYPE_MISALIGNMENT", "BREAKPOINT", "SINGLE_STEP", "ARRAY_BOUNDS_EXCEEDED",
    "FLT_DENORMAL_OPERAND", "FLT_DIVIDE_BY_ZERO", "FLT_INEXACT_RESULT", "FLT_INVALID_OPERATION", "FLT_OVERFLOW",
    "FLT_STACK_CHECK", "FLT_UNDERFLOW", "INT_DIVIDE_BY_ZERO", "INT_OVERFLOW", "PRIV_INSTRUCTION", "IN_PAGE_ERROR",
    "ILLEGAL_INSTRUCTION", "NONCONTINUABLE_EXCEPTION", "STACK_OVERFLOW", "INVALID_DISPOSITION", "GUARD_PAGE", "INVALID_HANDLE"];
  switch(code){
    static foreach(s ;names) mixin(q{ case EXCEPTION_*: return "*"; }.replace('*', s));
    default: return format!"%X"(code);
  }
}

auto getModuleInfoByAddr(void* addr){
  struct Res{
    HMODULE handle;
    File fileName;
    void* base;
    size_t size;
    string location;
  }

  Res res; with(res){
    import core.sys.windows.windows;
    if(GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                         GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, cast(wchar*)addr, &handle)){
      wchar[256] tmp;
      if(GetModuleFileNameW(handle, tmp.ptr, 256))
        fileName = File(tmp.toStr);

      import core.sys.windows.psapi;
      MODULEINFO mi;
      if(GetModuleInformation(GetCurrentProcess, handle, &mi, mi.sizeof)){
        base = mi.lpBaseOfDll;
        size = mi.SizeOfImage;

        if(fileName==appFile)
          res.location = exeMapFile.locate(addr-base);

        if(location.empty)
          location = fileName.fullName.quoted;
      }
    }

  }

  return res;
}

void installExceptionFilter(){

  __gshared static installed = false;
  if(!chkSet(installed)) return;

  import core.sys.windows.windows;

  static extern(Windows) LONG filter(EXCEPTION_POINTERS* p){
    string msg;
    with(p.ExceptionRecord){

      auto mi = getModuleInfoByAddr(ExceptionAddress);

      string excInfo;
      if(NumberParameters) excInfo = "info: " ~ ExceptionInformation[0..NumberParameters].map!(a => a.format!"%X").join(", ");

      //print("\n\33\14OS Exception:\33\17", exceptionCodeToStr(ExceptionCode), "\33\7at", ExceptionAddress, excInfo);
      msg = format!"Error: OS Exception: %s at %s %s"(exceptionCodeToStr(ExceptionCode), ExceptionAddress, excInfo);

      //if(mi.handle){
        //print("module:", mi.fileName.fullName.quoted, "base:", mi.base, "rel_addr:\33\17", format("%X",ExceptionAddress-mi.base), mi.location, "\33\7");
        //msg ~= "\n" ~ mi.location;  //not needed, already in stack trace
      //}
    }

    if(1){ //stacktrace
      import core.sys.windows.stacktrace;
      auto st = new StackTrace(0/*skip frames*/, p.ContextRecord);
      msg ~= "\n----------------\n"~st.text;
      /*foreach(s; st.text.splitLines){
        write(s, " ");

        if(s.isWild("0x????????????????")){
          auto addr = cast(void*) s[2..$].to!ulong(16);
          write(addr, " \33\13");
          auto mi = getModuleInfoByAddr(addr);
          if(mi.handle){
            auto relAddr = cast(ulong) (addr-mi.base);
            write(mi.fileName.name, ":", relAddr.format!"%X");

            write(" ", mi.location);
          }
        }

        writeln("\33\7");
      }*/
      //print(st);
    }

    //if(0) print((*(p.ContextRecord)).toJson);

    //todo: Break point handling
    // Decide what to do. On BREAKPOINT it is possible to continue.
    /*if(p.ExceptionRecord.ExceptionCode == EXCEPTION_BREAKPOINT){
      console.setForegroundWindow;
      write("Continue (y/n) ? ");
      auto s = readln;
      if(s.lc.strip == "y"){
        if(mainWindow) mainWindow.setForegroundWindow;

        p.ContextRecord.Rip ++; //advance IP
        return EXCEPTION_CONTINUE_EXECUTION;
      }
    }else{
      write("Press enter to exit..."); readln;
    }*/

    showException(msg);

    return
      EXCEPTION_EXECUTE_HANDLER;    //exits because D runtime has no registered handler
      //EXCEPTION_CONTINUE_SEARCH;    //exits, unhandled by this filter.
      //EXCEPTION_CONTINUE_EXECUTION; //continues, but it becomes an endless as it retriggers an exception on the same error
  }

  auto res = SetUnhandledExceptionFilter(&filter);
  //LOG("Exception filter installed: ", res);
}


void selftest(T)(lazy const T a, uint xb, string name, string notes="", string file=__FILE__, int line=__LINE__){
version(disableselftest){ return; }else{
  import het.inputs;
  shared static bool skip; if(inputs["Shift"].active) skip = true;
//todo:selftest skippelesen gondolkozni... A problema, hogy csak akkor kezelheto belul, ha a selftest lazy parametereben tortenik minden.

  if(!notes.empty) notes = "\33\10 "~notes~"\33\7";
  const sHoldShift = "Hold SHIFT to skip...";
  write("SELFTEST [\33\17"~name~"\33\7"~notes~"]: \33\10"~sHoldShift~"\33\7"); console.flush;
  void clearBack(){ write("\b \b".map!(a => [a].replicate(sHoldShift.length)).join); }

  if(skip){
    clearBack;
    writeln("\33\10SKIPPED\33\7");
    return;
  }

  auto xa = a.xxh; //this could take long time

  clearBack;

  if(xa==xb){
    writeln("\33\x0AOK\33\x07");
  }else{
    writefln("\33\x0CFAILED\33\x07 (%d!=%d)", xa, xb);
    auto e = new Exception(format("Error: selftest [%s] failed (%d!=%d)", name, xa, xb), file, line);
    console.handleException({ throw e; });
    application.exit; //todo: this is a fatal exception, should the IDE know about this also...
  }
}}


bool ignoreExceptions(void delegate() f){
  bool res;
  try{
    f();
  }catch(Throwable){
    res = true;
  }
  return res;
}

// KillerThread //////////////////////////////////////////////////////////////

//Lets the executable stopped from DIDE when the windows message loop is not responding.
class KillerThread: Thread{
public:
  bool over, finished;
  this(){
    super({
      double t0 = 0;
      const timeOut = 0.66; //it shut downs after a little less than the DIDE.killExeTimeout (1sec)
      while(!over){
        if(t0==0){
          if(dbg.forceExit_check) t0 = QPS; //start timer
        }else{
          auto elapsed = QPS-t0;
          if(!dbg.forceExit_check){
            t0 = 0; //reset timer. exiting out normally.
          }else{
            if(elapsed>timeOut){
              dbg.forceExit_clear; //timeout reached, exit drastically
              application.exit;
            }
          }
        }
        .sleep(15);
      }
      finished = true;
    });
  }

  void stop(){
    over = true;
    while(!finished) .sleep(5); //Have to wait the thread
  }
}

////////////////////////////////////////////////////////////////////////////////
///  Numeric                                                                 ///
////////////////////////////////////////////////////////////////////////////////

//enum PIf = 3.14159265358979323846f;  //todo: not sure about where is it used or not used. If float*double(pi) doesnt calculates using double cpu instructions then it is obsolete.

//it replaces the exception with a default value.
T safeConv(T, U)(const U src, lazy const T def){
  try{
    return src.to!T;
  }catch(Throwable){
    return def;
  }
}

T safeDiv(T)(T a, T b, T def=0){
  return b==0 ? def : a/b;
}

/*  it's het.math.mod auto cyclicMod(T, U)(T a, U b) if(__traits(compiles, a%b)){
  auto c = a%b;
  if(c<0) c += b;
  return c;
}*/


float wrapInRange(ref float p, float pMin, float pMax){
  float len = pMax-pMin, pOld = p;
  while(p<pMin) p += len; //todo: opt with fract
  while(p>pMax) p -= len;
  return p-pOld;
}

float wrapInRange(ref float p, float pMin, float pMax, ref int wrapCnt){ //specialised version for endless sliders
  float len = pMax-pMin, pOld = p;
  wrapCnt = 0;
  while(p<pMin){ p += len; wrapCnt++; }
  while(p>pMax){ p -= len; wrapCnt--; }
  return p-pOld;
}


T rcpf_fast(T)(const T x)if(__traits(isFloating, T)){
  return 1.0f/x; //todo: Ezt megcsinalni SSE-vel
}

struct percent{
  float value = 0;
  @property multiplier() const{ return value*1e-2f; }
  @property multiplier(float p) { value = p*1e2f; }

  string toString() const{ return "%6.2f%%".format(value); }

  percent opBinary   (string op)(in percent b) const{ return mixin( q{percent(multiplier %s b.multiplier)}.format(op) ); }
  float opBinary     (string op)(in float b)   const{ return mixin( q{multiplier %s b}.format(op) ); }
  float opBinaryRight(string op)(in float a)   const{ return mixin( q{a %s multiplier}.format(op) ); }
}


//todo: unittest nem megy. lehet, hogy az egesz projectet egyszerre kell forditani a DMD-ben?!!!
//todo: 'in' operator piros, de annak ciankeiknek kene lennie, mint az out-nak. Azazhogy helyzettol figg annak a szine


//todo: remap goes to math
T remap(T)(in T src, in T srcFrom, in T srcTo, in T dstFrom, in T dstTo)
{
  float s = srcTo-srcFrom;
  if(s==0){
    return dstFrom;
  }else{
    return cast(T)((src-srcFrom)/s*(dstTo-dstFrom)+dstFrom);
  }
}

T remap_clamp(T)(in T src, in T srcFrom, in T srcTo, in T dstFrom, in T dstTo)
{
  return clamp(remap(src, srcFrom, srcTo, dstFrom, dstTo), dstFrom, dstTo);
}

int iRemap_clamp(T)(in T src, in T srcFrom, in T srcTo, in T dstFrom, in T dstTo)
{
  return cast(int)remap_clamp(src, srcFrom, srcTo, dstFrom, dstTo);
}

//todo: rewrite to greaterThan, lessThan
bool isAscending (T0, T1)(in T0 a, in T1 b){ return a < b; }
bool isDescending(T0, T1)(in T0 a, in T1 b){ return a > b; }

bool isAscending (T0, T1)(in T0 a, in T1 b, lazy bool chain=true){ return a == b ? chain : a < b; }
bool isDescending(T0, T1)(in T0 a, in T1 b, lazy bool chain=true){ return a == b ? chain : a > b; }

public import std.algorithm: sort, swap;

void sort(T)(ref T a, ref T b){
  if(a>b) swap(a,b);
}

void sort(T)(ref T a, ref T b, ref T c){
  sort(a, b);
  sort(a, c);
  sort(b, c);
}

auto alignUp  (T)(T p, int align_) { return (p+(align_-1))/align_*align_; }
auto alignDown(T)(T p, int align_) { return p/align_*align_; }

bool chkSet  (ref bool b) { if( b) return false; else { b = true ; return true; } }
bool chkClear(ref bool b) { if(!b) return false; else { b = false; return true; } }

bool chkSet(T)(ref T a, in T b) { if(a==b) return false; else { a = b; return true; } }

void divMod(T)(in T a, in T b, out T div, out T mod){
  div = a/b;
  mod = a%b;
}

void sinCos(T)(T a, out T si, out T co){ si = sin(a); co = cos(a); }

T aSinCos(T)(T x, T y)
{
  T d = x*x + y*y, res;
  if(d==0) return 0;
  if(d!=1) d = 1.0f/sqrt(d);
  if(abs(x)<abs(y)){
    T res = acos(x*d);
    if(y<0) res = -res + PI*2;
  }else{
    res = asin(y*d);
    if(x<0) res = -res + PI;
    if(res<0) res = res + PI*2;
  }
  return res;
}


int nearest2NSize(int size)
{
  return size>0 ? 2^^iceil(log2(size)) //todo: slow
                : 0;
}

bool isPrime(uint num){
  if (num == 2) return true;
  if (num <= 1 || num % 2 == 0) return false; // 0, 1, and all even numbers
  uint snum = cast(uint)sqrt(cast(double)num);
  for (uint x = 3; x <= snum; x += 2) {
    if (num % x == 0)
      return false;
  }
  return true;
}

// max |error| > 0.01
float atan_fast(float x, float y)
{
  const float ONEQTR_PI = PIf / 4.0f;
  const float THRQTR_PI = 3.0f * PIf / 4.0f;
  float r, angle;
  float abs_y = abs(y) + 1e-10f;      // kludge to prevent 0/0 condition
  if(x < 0.0f){
    r = (x + abs_y) / (abs_y - x);
    angle = THRQTR_PI;
  }else{
    r = (x - abs_y) / (x + abs_y);
    angle = ONEQTR_PI;
  }
  angle += (0.1963f * r * r - 0.9817f) * r;
  if ( y < 0.0f ) return( -angle );     // negate if in quad III or IV
             else return( angle );
}

float ease(float in_=2, float out_=2)(float x){
  return (x^^in_)*(1-x)+(1-(1-x)^^out_)*x;
}

float peakLocation(float a, float b, float c, float* y=null){
  //https://ccrma.stanford.edu/~jos/sasp/Quadratic_Interpolation_Spectral_Peaks.html
  auto d = (a-2*b+c),
       p = abs(d)<1e-4 ? 0 : 0.5f*(a-c)/d;
  if(y) *y = b-0.25f*(a-c)*p;
  return p;
}

//https://www.desmos.com/calculator/otwqwldvpj
auto logCodec(bool encode, T, float digits, int max)(float x){
  enum mul = (0.30101f*max)/digits,
       add = max/mul;
  static if(encode){
    return cast(T)(iround((log2(x)+add)*mul).clamp(0, max));
  }else{
    return 2.0f^^(x*(1/mul)-add);
  }
}

auto logEncode(T, float digits)(float x){ return logCodec!(true , T, digits, T.max)(x); }
auto logDecode(T, float digits)(int   x){ return logCodec!(false, T, digits, T.max)(x); }

unittest{
  string s;
  foreach(j; 0..11){
    auto i = j*255/10;
    auto f = i.logDecode!(ubyte, 3);
    s ~= format("%4d -> %8.5f -> %4d\r\n", i, f, f.logEncode!(ubyte, 5/*on purpose*/));
  }

  //digit count test
  static foreach(dig; 2..8){{
    alias cfg = AliasSeq!(ubyte, dig);
    s~= format("%d %f %f\r\n", dig, -log10(0.logDecode!cfg), 1.logDecode!cfg/0.logDecode!cfg);
  }}

  assert(s.xxh==2704795724, "logEncoder/Decoder fucked up.");
}


// Bitwise //////////////////////////////////////////////

public import core.bitop : rol, ror,
  bitCount = popcnt,
  bitSwap = bitswap,
  byteSwap = bswap,
  bitScan = bsf,
  bitScan_reverse = bsr;

ushort byteSwap(ushort a){ return cast(ushort)((a>>>8)|(a<<8)); }
 short byteSwap( short a){ return cast( short)((a>>>8)|(a<<8)); }

wstring byteSwap(wstring s){ return cast(wstring)((cast(ushort[])s).map!(c => cast(wchar)(c.byteSwap)).array); }
dstring byteSwap(dstring s){ return cast(dstring)((cast(uint  [])s).map!(c => cast(dchar)(c.byteSwap)).array); }

bool getBit(T)(T a, size_t idx){ return ((a>>idx)&1)!=0; }
T setBit(T)(T a, size_t idx, bool v=true){ return a&~(cast(T)1<<idx)|(cast(T)v<<idx); }
T clearBit(T)(T a, size_t idx){ return setBit(a, idx, false); }

T getBits(T)(T a, size_t idx, size_t cnt){ return (a>>idx)&((cast(T)1<<cnt)-1); }
T setBits(T)(T a, size_t idx, size_t cnt, T v){
  T msk0 = (cast(T)1<<cnt)-1,
    msk = msk0<<idx;
  return a&~msk|((v&msk0)<<idx);
}

T maskLowBits(T)(T a){ //todo: slow
  foreach_reverse(i; 0..T.sizeof*8) if(a.getBit(i)) return (cast(T)1<<(i+1))-1;
  return 0;
}

int countHighZeroBits(T)(T a){ //todo: slow
  foreach_reverse(int i; 0..T.sizeof*8) if(a.getBit(i)) return cast(int)T.sizeof*8-1-i;
  return T.sizeof*8;
}

T vec_sel  (T)(T a, T b, T c){ return c &  a | ~c & b; } //CAL style
T bitselect(T)(T a, T b, T c){ return a & ~c |  b & c; } //OCL style
T bfi      (T)(T a, T b, T c){ return a &  b | ~a & c; } //GCN style

auto bitalign(uint lo, uint hi, uint ofs){
  return cast(uint)((lo | (cast(ulong)hi<<32))>>ofs);
}


uint hammondDist(uint a, uint b){ return bitCount(a^b); }

int boolMask(in bool[] arr...){
  return arr.enumerate.map!(a => a.value<<a.index).sum;
}

bool toggle(ref bool b){ b = !b; return b; }

T negate(T)(ref T a){ a = -a; return a; }

T binaryToGray(T)(T x){ return x ^ (x >> 1); }

//http://kodhus.com/easings/
float easeInQuad   (float t, float b, float c, float d) { return c*(t/=d)*t + b; }
float easeOutQuad  (float t, float b, float c, float d) { return -c *(t/=d)*(t-2) + b; }
float easeInOutQuad(float t, float b, float c, float d) {
  if ((t/=d/2) < 1) return c/2*t*t + b;
  return -c/2 * ((--t)*(t-2) - 1) + b;
}

// Interval ////////////////////////////////////////
// Interval: Keeps an integer or float range. It can clamp values using that range,
// and can easily extend the range. Also manages the validity of the range (NULL range).
// There are 2 specializations: some FloatInterval/IntInterval.
/+ this in in math now. struct Interval(T){
  static if(__traits(isFloating, T)){ T min = T.max,  max = -T.max; }
                                else{ T min = T.max,  max =  T.min; }

  bool valid() const          { return min<=max; }

  bool opBinary(string op)(T b) const if(op=="in"){ return inRange(b, min, max); }

  T clamp(const T a) const    { return .clamp(a, min, max); }
  void extendTo(T a)          { minimize(min, a); maximize(max, a); }

  T inclusiveLength() const { if(valid) return max-min+1; else return 0; }

  static if(__traits(isFloating, T)){
    IntInterval toIntInterval()const {
      const mi = int.min+1, ma = int.max-1;
      int lo, hi;
      if(min<mi) lo = mi;else if(min>ma) lo = ma;else lo = ifloor(min);
      if(max<mi) hi = mi;else if(max>ma) hi = ma;else hi = iceil (max);
      return IntInterval(lo, hi);
    }
  }

  alias Type = typeof(this);

  Type opBinary(string op)(const Type other)const if(op=="&"){
    if(!valid || !other.valid) return Type();
    if(max < other.min || other.max<min) return Type();
    if(max <= other.max && min <= other.min) return Type(other.min, max);
    if(min >= other.min && max >= other.max) return Type(min, other.max);
    return inclusiveLength<=other.inclusiveLength ? this : other;
  }

  Type opBinary(string op)(const Type other)const if(op=="|"){
    if(!valid) return other;
    if(!other.valid) return this;
    return Type(.min(this.min, other.min), .max(this.max, other.max));
  }

  Type opBinary(string op)(const Type other)const if(op=="=="){
    if(!valid || !other.valid) return valid==other.valid;
    return min==other.min && max==other.max;
  }

  bool opBinaryRight(string op)(const T val)const if(op=="in"){
    return val>=min && val<=max;
  }

};

alias IntInterval   = Interval!int  ;
alias FloatInterval = Interval!float;
+/

struct UpdateInterval{
  float tLast, tAct;

  private int test(float t){ return t>tLast && t<=tAct; } //open-closed interval

  int repeater(float tBase, float dtFirst, float dt = 0){
    if(dt==0) dt = dtFirst;

    int res = test(tBase);
    if(dtFirst>0){
      tBase += dtFirst;
      res += test(tBase);
    }
    if(dt>0){
      float idt = 1/dt;

      //simple & stupid: foreach(i; max(1, iFloor((tLast-tBase)*idt))..1+iCeil((tAct-tBase)*idt)) res += chk(tBase+i*dt);
      int st = max(1, ifloor((tLast-tBase)*idt)); //inclusive  0th is the base
      int en = ifloor((tAct-tBase)*idt)+1;        //exclusive

      //simple loop: foreach(i; st..en) res += test(tBase+i*dt);

      if(st<en){
        res += test(tBase+st*dt); st++; //check at start
        if(st<en){
          en--; res += test(tBase+en*dt); //check at end
          res += en-st; //remaining inbetween is always 1
        }
      }

    }

    return res;
  }

  private static void _testRepeater(/*Drawing dr = null*/){
    float tBase = 3, tDelta = 1, tFirstDelta = 5;
    uint h;
    foreach(i; 1..25){
      float step = i*0.2f;
      float tLast = 0;
      while(1){
        float tAct = tLast+step;
        if(tLast>40.5) break;

        /*auto r = Bounds2f(tLast, i*0.2, tAct, (i+1)*0.2);  dr.color = clWhite;  dr.drawRect(r);*/

        int n = UpdateInterval(tLast, tAct).repeater(tBase, tFirstDelta, tDelta);

        h = xxh([n], h);

        /*if(n){ dr.color = clVGA[n];  dr.fillRect(r); }
        dr.color = clWhite;  dr.fontHeight = 0.1;  dr.textOut(r.x, r.y, n.text);*/

        tLast = tAct;
      }
    }

    enforce(h==3069201956, "UpdateInterval.testRepeater test fail.");

    /*foreach(i; -1..40){
      dr.color = clFuchsia;
      float x = i==-1 ? tBase
              : i==0  ? tBase+tFirstDelta
                      : tBase+tFirstDelta+i*tDelta;
      dr.vline(x, 0, 10);
    }*/

  }

}




////////////////////////////////////////////////////////////////////////////////
///  Arrays                                                                  ///
////////////////////////////////////////////////////////////////////////////////


//make initialized static 1d, 2d, 3d arrays
auto makeArray(T, size_t N, T val)()
{
  T[N] result;
  foreach(i; 0..N) element[i] = val;
  return result;
}

auto makeArray2(T, size_t N, size_t M, T val)()
{
  T[N][M] result;
  foreach(j; 0..M) foreach(i; 0..N) result[j][i] = val;
  return result;
}

auto makeArray3(T, size_t N, size_t M, size_t O, T val)()
{
  T[N][M][O] result;
  foreach(k; 0..O) foreach(j; 0..M) foreach(i; 0..N) result[k][j][i] = val;
  return result;
}


// safely get a copy of and array element
T get(T)(T[] arr, size_t idx, T def = T.init){
  return idx<arr.length ? arr[idx]
                        : def;
}

// safely get an element ptr
T* getp(T)(T[] arr, size_t idx, T* def = null){
  return idx<arr.length ? &arr[idx]
                        : def;
}

// safely access and element, putting default values in front of it when needed
ref T access(T)(ref T[] arr, size_t idx, T def = T.init){
  while(idx>=arr.length) arr ~= def; //optional extend
  return arr[idx];
}

// safely set an array element
void set(T)(ref T[] arr, size_t idx, T val, T def = T.init){
  arr.access(idx, def) = val;
}


void clear(T)(ref T[] arr)        { arr.length = 0; }
bool addIfCan(T)(ref T[] arr, in T item) { if(!arr.canFind(item)){ arr ~= item; return true; }else return false; }
bool addIfCan(T)(ref T[] arr, in T[] items) { bool res; foreach(const item; items) if(arr.addIfCan(item)) res = true; return res; }

T popFirst(T)(ref T[] arr){ auto res = arr[0  ]; arr = arr[1..$  ]; return res; }
T popLast (T)(ref T[] arr){ auto res = arr[$-1]; arr = arr[0..$-1]; return res; }

T popFirst(T)(ref T[] arr, T default_){ if(arr.empty) return default_; return popFirst(arr); }
T popLast (T)(ref T[] arr, T default_){ if(arr.empty) return default_; return popLast (arr); }


//converts an array to uint[], badding the end with a specified byte. ByteOrder is machine specific.
uint[] toUints(in void[] data, ubyte filler=0){
  import std.traits;
  enum unitSize = ElementType!(typeof(return)).sizeof;
  const uint dataLength = data.length.to!uint,
             extLength  = dataLength.alignUp(unitSize);
  return cast(uint[])((cast(ubyte[])data) ~ [ubyte(0)].replicate(extLength - dataLength));
}

/* Ezek LDC-vel nem mennek!!!!
void appendUninitializedReserved(T)(ref T[] arr, size_t N = 1) {
  auto length_p = cast(size_t*)(&arr);
  *length_p += N;
}

void appendUninitialized(T)(ref T[] arr, size_t N = 1) {
  arr.reserve(arr.length + N);
  auto length_p = cast(size_t*)(&arr);
  *length_p += N;
}*/


float[] gaussianBlur(float[] a, int kernelSize){
  //http://dev.theomader.com/gaussian-kernel-calculator/
  //todo: refactor this

  float g3(int i){
   return (a[max(i-1, 0)]+a[min(i+1, $-1)])*0.27901f +
          a[i]*0.44198f;
  }

  float g5(int i){
    return (a[max(i-2, 0)]+a[min(i+2, $-1)])*0.06136f +
           (a[max(i-1, 0)]+a[min(i+1, $-1)])*0.24477f +
            a[i]*0.38774f;
  }

  float g7(int i){
    return (a[max(i-3, 0)]+a[min(i+3, $-1)])*0.00598f +
           (a[max(i-2, 0)]+a[min(i+2, $-1)])*0.060626f +
           (a[max(i-1, 0)]+a[min(i+1, $-1)])*0.241843f +
            a[i]*0.383103f;
  }

  float g9(int i){
    return (a[max(i-5, 0)]+a[min(i+5, $-1)])*0.000229f +
           (a[max(i-3, 0)]+a[min(i+3, $-1)])*0.005977f +
           (a[max(i-2, 0)]+a[min(i+2, $-1)])*0.060598f +
           (a[max(i-1, 0)]+a[min(i+1, $-1)])*0.241732f +
            a[i]*0.382928f;
  }

  float delegate(int) fv;
  switch(kernelSize){
    case 1: return a;
    case 3: fv = &g3; break;
    case 5: fv = &g5; break;
    case 7: fv = &g7; break;
    case 9: fv = &g9; break;
    default: enforce(0, "Unsupported kernel size "~kernelSize.text);
  }

  return iota(a.length.to!int).map!(i => fv(i)).array;
}

class ResonantFilter{  //https://www.music.mcgill.ca/~gary/307/week2/filters.html
  float b0, b1, b2, a1, a2;
  float x, x1, x2, y, y1, y2;

  this(float rate, float q){
    reset;
    setup(rate, q);
  }

  void setup(float rate, float q){
//    enforce(q.inRange(0, 1) && rate.inRange(0, 1));
    a1 = -2*q*cos(2*PIf*rate);
    a2 = q^^2;
    b0 = (1-a2)*.5f;
    b1 = 0; //todo: opt for b1
    b2 = -b0;
  }

  void reset(float val=0){
    x=x1=x2=val;
    y=y1=y2=0;
  }

  float process(float newX){
    x2 = x1;    y2 = y1;
    x1 = x;     y1 = y;
    x = newX;   y = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2;
    return y;
  }

  float[] process(T)(in T[] data){
    if(data.empty) return [];
    reset(data[0]);
    float[] res;
    foreach(d; data) res ~= process(d);
    return res;
  }
}

T[] derived(T)(in T[] arr){
  if(arr.empty) return [];
  T[] res;  res.reserve(arr.length);
  T last = arr[0];
  foreach(a; arr){
    res ~= a-last;
    last = a;
  }
  return res;
}

struct IdxValuePair(T){ int idx; T value=0; }

auto zeroCrossings(T, bool positive=true, bool negative=true)(in T[] arr, T minDelta=0)
{
  alias IV = IdxValuePair!T;
  IV[] res;
  foreach(i; 0..arr.length.to!int-1){
    static if(positive){
      if(arr[i]<=0 && arr[i+1]>0){ auto d = arr[i+1]-arr[i]; if(d>=minDelta) res ~= IV(i, d); }
    }
    static if(negative){
      if(arr[i]>=0 && arr[i+1]<0){ auto d = arr[i+1]-arr[i]; if(-d>=minDelta) res ~= IV(i, d); }
    }
  }
  return res;
}

auto zeroCrossings_positive(T)(in T[] arr, T minDelta=0){ return zeroCrossings!(T, true, false)(arr, minDelta); }
auto zeroCrossings_negative(T)(in T[] arr, T minDelta=0){ return zeroCrossings!(T, false, true)(arr, minDelta); }

//todo: implement mean for ranges
typeof(T.init/1) mean(T)(in T[] a){
  return a.sum/a.length;
}

/*auto auto mean(R) (R r) if(isInputRange!R && !isInfinite!R && is(typeof(r.front + r.front))){
}

auto auto mean(R, E) (R r, E seed) if(isInputRange!R && !isInfinite!R && is(typeof(seed = seed + r.front))){
}*/


//Signal smoothing /////////////////////////////

struct BinarySignalSmoother{
  private{
    int outSameCnt;
    bool actOut, lastOut, lastIn;
  }

  bool process(bool actIn, int N=2){
    if(outSameCnt>=N-1)
      actOut = lastIn!=actIn ? !actOut : actIn;

    outSameCnt = lastOut==actOut ? outSameCnt+1 : 0;
    lastOut = actOut;
    lastIn   = actIn;
    return actOut;
  }

  @property bool output() const{ return actOut; }

  static void selfTest(int N=2)(){
    BinarySignalSmoother bss;

    const input = "..1.1.1..1.1.11.1.1..111111..11..111..111.1........1...11...1.11111111.1111.1";
    auto output = input.map!(c => bss.process(c=='1', N) ? '1' : '.').array;

    writeln("----");
    writeln(input);
    writeln(output);

    BinarySignalSmootherNew!N bss2;
    auto output2 = input.map!(c => bss2.process(c=='1') ? '1' : '.').array;
    writeln(output2);
  }
}


struct BinarySignalSmootherNew(int N){  //different algo, also slower
  private bool[N] input, output;

  bool process(bool newInput){

    enum N = 15;

    input[] = newInput ~ input[0..$-1];

    const o1 = output[].all, o0 = !output[].any, oStable = o0 || o1;

    bool newOutput;
    if(oStable){ //output is stable so it's possible to change it now
      const i1 = input[].all, i0 = !input[].any, iStable = i0 || i1;
      newOutput = iStable ? i1          //input is stable, so update output
                          : !output[0]; //input is diverging, just toggle the output on and off
    }else{
      newOutput = output[0];
    }

    output[] = newOutput ~ output[0..$-1];

    return newOutput;
  }

}

// SparseArray ///////////////////////////////////////////////////////////

struct SparseArray(K, V, V Def=V.init){ //todo: bitarray-ra megcsinalni a bool-t. Array!bool
  K[] keys;
  V[] values;

  V def = Def; //can overwrite if needed

/*  this(){ clear; }*/

  void clear(){ keys = []; values = []; }

  auto get(int key) const{
    auto bnd = keys.assumeSorted.lowerBound(key+1);
    return bnd.length ? values[bnd.length-1] : def;
  }

  void append_unsafe(in K key, in V value){ //unsafe way to append
    keys   ~= key  ;
    values ~= value;
  }

  void set(in K key, in V value){
    if(keys.length && key>keys[$-1]){ //fast path: append or update the last value
      if(values[$-1] != value) append_unsafe(key, value);
      return;
    }

    auto lo = keys.assumeSorted.lowerBound(key);
    auto hi = keys[lo.length..$];

    if(hi.length && keys[$-hi.length] == key) hi = hi[1..$]; //if the key exists

    if(!lo.length || values[lo.length-1] != value){ //must insert value in the middle
      keys   = keys  [0..lo.length] ~ key   ~ keys  [$-hi.length..$];
      values = values[0..lo.length] ~ value ~ values[$-hi.length..$];
    }else{
      if(lo.length && hi.length && values[lo.length-1]==values[$-hi.length]){
        hi = hi[1..$]; //the 2 side of the hole is the same. Keep the left one only.
      }
      keys   = keys  [0..lo.length] ~ keys  [$-hi.length..$];
      values = values[0..lo.length] ~ values[$-hi.length..$];
    }
  }

  auto opIndex(in K key) const{ return get(key); }
  auto opIndexAssign(in V value, in K key) { set(key, value); return value; }
  auto opIndexOpAssign(string op)(in V value, in K key) {
    mixin("auto tmp = get(key) "~op~" value;");
    set(key, tmp); return tmp;
  }

  bool isCompact() const{
    foreach(i; 1..keys.length)
      if(keys[i-1]>=keys[i] || values[i-1]==values[i]) return false;

    return true;
  }

  void compact(){
    if(isCompact) return;

    K[] newKeys  ; newKeys  .reserve(keys.length);
    V[] newValues; newValues.reserve(values.length);
    K lastKey;
    V lastValue;

    void add(in K k, in V v){
      newKeys   ~= k; lastKey   = k;
      newValues ~= v; lastValue = v;
    }

    add(keys[0], values[0]);

    foreach(i; 1..keys.length){
      const k = keys[i], v = values[i];
      if(k >= lastKey && v != lastValue)
        add(k, v);
    }

    keys   = newKeys  ;
    values = newValues;
  }

}

unittest{
  enum N = 5;
  SparseArray!(int, ubyte) sa;
  auto dump(){ return iota(N).map!(i => sa[i].text).join; }

              assert(dump == "00000");
  sa[3] = 1;  assert(dump == "00011");
  sa[4] = 2;  assert(dump == "00012");
  sa[4] = 4;  assert(dump == "00014");
  sa[1] = 1;  assert(dump == "01114");
  sa[3] = 3;  assert(dump == "01134");
  sa[2] = 2;  assert(dump == "01234");
  sa[0] = 9;  assert(dump == "91234");
  sa[4] = 9;  assert(dump == "91239");
  sa[2] = 9;  assert(dump == "91939");
  sa[1] = 9;  assert(dump == "99939" && sa.isCompact);
  sa[3] = 9;  assert(dump == "99999" && sa.isCompact);

  sa.clear;
  sa.append_unsafe(1, 1);
  sa.append_unsafe(2, 1);
  sa.append_unsafe(2, 3);
  sa.append_unsafe(3, 3);
  sa.append_unsafe(4, 3);  assert(!sa.isCompact);
  sa.compact;              assert(sa.keys.equal([1, 2]) && sa.values.equal([1, 3]));
}


// CircBuf class ///////////////////////////////////////////////////////////////

struct CircBuf(size_type, size_type cap){
//  size_type: for debugClient communication, it must be 32bit because it communicates with debugClient

  size_type tail, head;
  ubyte[cap] buf;

  private auto truncate(size_type x) const {
    static if(cap&(cap-1)) return x % cap;
                      else return x & (cap-1);
  }

  auto length()      const { return head-tail; }
  bool empty()       const { return length==0; }
  auto capacity()    const { return cap; }
  auto canGet()      const { return length; }
  auto canStore()    const { return capacity-length; }

  bool store(void* src, size_type srcLen){
    if(srcLen>canStore) return false;

    auto o = head % capacity;
    auto fullLen = srcLen;
    if(o+srcLen>=capacity){ //multipart
      auto i = capacity-o;
      memcpy(&(buf[o]), src, i);
      o = 0;
      src += i;
      srcLen -= i;
    }
    if(srcLen>0){
      memcpy(&(buf[o]), src, srcLen);
    }

    //advance in one step
    head += fullLen; //no atomic needed as one writes and the other reads

    return true;
  }

  bool store(void[] data){ return store(data.ptr, cast(size_type)data.length); }

  bool get(void* dst, size_type dstLen){
    if(dstLen>canGet) return false;

    auto o = truncate(tail);
    auto fullLen = dstLen;
    if(o+dstLen>=capacity){ //multipart
      auto i = capacity-o;
      memcpy(dst, &(buf[o]), i);
      o = 0;
      dst += i;
      dstLen -= i;
    }
    if(dstLen>0){
      memcpy(dst, &(buf[o]), dstLen);
    }

    //advance in one step
    tail += fullLen; //no atomic needed as one writes and the other reads

    return true;
  }

  ubyte[] getBytes(size_type dstLen){
    ubyte[] res;
    if(dstLen>canGet) return res;
    res.length = dstLen;
    get(res.ptr, dstLen);
    return res;  //todo: tail,head tulcsordulhat 4gb-nel!
  }
}

unittest{
  void doTest(uint N)(){
    CircBuf!(uint, N) cb;

    RNG rng;
    ubyte[] orig;  foreach(i;1..20) orig ~= cast(ubyte)i;
    ubyte[] src = orig.dup, dst;
    while(1){
      if(src.empty && cb.empty)break;
      //string s;
      if(random(2)){ //store
        uint i = rng.random(min(cb.canStore+1, cast(uint)src.length+1));
        ubyte[] buf;
        foreach(a; 0..i) { buf ~= src[0]; src = src[1..$]; }
        //s = format("PUT%s %-30s", i, to!string(buf));
        assert(cb.store(buf));
      }else{ //get
        uint i = rng.random(cb.canGet+1);
        auto buf = cb.getBytes(i);
        assert(buf.length==i);
        dst ~= buf;
        //s = format("GOT%s %-30s", i, to!string(buf));
      }
      //writeln(s, cb);
    }
    assert(orig==dst, "Fatal Error in CircBuff.");
  }

  doTest!4; doTest!5; //test bo the & and the % case
}


// BigArray //////////////////////////////////////////////////////////////////

//todo: a synchronizedet megcsinalni win32-re

/*synchronized*/ class BigArray(T){
private:
  struct Block{
    T[] data;
    size_t idxSt, idxEn;
  }
  size_t length_;

  File fileName_;
  bool loading_;
  Block[] blocks;
  size_t blockSize;
  bool doSeekForward;
  T seekForwardUntil;

  struct Slice{ size_t st, en; }

public:
  this(size_t blockSize_, const T seekForwardUntil_=T.init){
    blockSize = blockSize_;
    if(seekForwardUntil_!=T.init){
      doSeekForward = true;
      seekForwardUntil = seekForwardUntil_;
    }
  }

  File fileName()     const { return fileName_; }
  bool loading()        const { return loading_; }

  // modifications ////////////
  void appendBlock(T[] data){
    if(data.empty) return;
    auto newLen = length_ + data.length;
    //blocks ~= shared(Block)(cast(shared T[])data, length_, newLen);
    blocks ~= Block(data, length_, newLen);
    length_ = newLen;
  }

  void append(T[] data){
    if(data.empty) return;

    size_t len = data.length;

    if(len>blockSize){ //multiblock insert
      append(data[0..blockSize]);
      append(data[blockSize..$]);
      return;
    }

    if(blocks.empty || blocks[$-1].data.length>=blockSize){
      appendBlock(data);
    }else{
      blocks[$-1].data ~= data;
      blocks[$-1].idxEn += len;
      length_ += len;
    }
  }

  // array access ////////////
  size_t length()const { return length_; } //todo: gecilassu
  size_t opDollar()const { return length_; }

  Slice opSlice(int idx)(size_t st, size_t en)const { return Slice(st, en); }

  private auto findBlock(size_t idx)const {
    foreach(i, const b; blocks)
      if(idx>=b.idxSt && idx<b.idxEn)
        return i;
    return -1;
  }
  private T getElement(size_t idx)const {
    auto i = findBlock(idx);
    if(i>=0) with(blocks[i]) return data[idx-idxSt];
                        else return T.init;
  }

  T opIndex(size_t idx)const {  //opt: cacheolni kene a poziciot es burst-ban nyomni
    enforce(idx<length);
    return getElement(idx);
  }

  T[] opIndex(const Slice s)const {
    enforce(s.st<=s.en && s.en<=length_);
    T[] res;
    res.reserve(s.en-s.st);

    size_t i = s.st; while(i<s.en){
      auto bi = findBlock(i);
      with(blocks[bi]){
        auto st = i-idxSt;
        auto en = min(s.en-idxSt, data.length);
        res ~= data[st..en];
        i += en-st;
      }
    }
    return res;
  }

  T[] opIndex()const { return this[0..$]; } //all

  ///////////////////
  static _loader(/*shared */BigArray!T bt, bool delegate(float percent) onPercent=null){

    StdFile f;
    try{
      f.open(bt.fileName.fullName, "rb");
      ulong size = f.size,
            maxBlockSize = bt.blockSize*3/2,
            current;

      while(1){
        ulong toRead = maxBlockSize,
              remaining = size-f.tell;
        if(remaining>maxBlockSize) toRead = bt.blockSize;
                              else toRead = remaining;
        if(toRead>0){
          auto data = f.rawRead(new T[cast(size_t)toRead]);

          if(bt.doSeekForward && data[$-1]!=bt.seekForwardUntil){
            T[] extra;
            char[1] buff;
            while(!f.eof){
              extra ~= f.rawRead(buff);
              if(extra[$-1]==bt.seekForwardUntil) break;
            }
            data ~= extra;
          }

          bt.appendBlock(data);
          current += data.length*T.sizeof;

          if(onPercent){
            if(!onPercent(current.to!double/size*100)) break;
          }

        }else break;
      }

      if(!size && onPercent) onPercent(100);

    }catch(Throwable t){ showException(t); } //todo: ez multithread miatt.
    bt._notifyLoaded;
  }

  void _notifyLoaded(){
    loading_ = false;
    //...something should connect here
  }

  private void initLoad(File fileName){
    enforce(!loading_,            format(`%s.load() already loading`    , typeof(this).stringof));
    enforce(fileName.exists, format(`%s.load() file not found "%s"`, typeof(this).stringof, fileName));
    fileName_ = fileName;
    loading_ = true;
  }

  void loadLater(File fileName, bool delegate(float percent) onPercent=null){
//    initLoad(fileName);
//    task!_loader(this, onPercent).executeInNewThread;
    loadNow(fileName, onPercent);
  }

  void loadNow(File fileName, bool delegate(float percent) onPercent=null){
    initLoad(fileName);
    _loader(this, onPercent);
  }

  void saveNow(string fileName){
    enforce(!loading_,            format(`%s.save() already loading`    , typeof(this).stringof));
    StdFile f; //todo: sima file-ra lecserelni
    f.open(fileName, "wb"); scope(exit) f.close;
    foreach(ref b; blocks)
      f.rawWrite(cast(T[])b.data);
  }

  void dump(){
    writeln(blocks.map!(b => format("%s", b.data.length)).join(", "));
  }
}

bool waitFor(T)(/*shared*/ BigArray!T ba, float timeOut_sec = 9999){
  if(!ba.loading) return true;
  auto tMax = QPS+timeOut_sec;
  while(ba.loading){
    if(QPS>tMax) return false; //timeout
    sleep(1);
  }
  return true;
}

alias BigText = /*shared*/ BigArray!char;

// BigStream //////////////////////////////////////////////////////////////////////////

/*synchronized*/ class BigStream_: BigArray!ubyte {
  this(size_t blockSize_ = 256<<10){
    super(blockSize_);
  }

  private size_t position;

  private ubyte[] rawRead(size_t len){
    auto res = this[position..position+len];
    cast(size_t)position += len;
    return res;
  }

  private void rawWrite(ubyte[] data){   //todo: const-nak kene lennie...
    append(data);
  }

  T read(T)(){
    return *cast(T*)rawRead(T.sizeof).ptr;
  }

  T[] readArray(T)(){
    uint len = read!uint;
    return cast(T[])rawRead(len*T.sizeof);
  }

  void write(T)(const T src){
    T[] temp = [src]; //todo: lame
    rawWrite(cast(ubyte[])temp);
  }

  void writeArray(T)(const T[] src){
    write(cast(int)src.length);
    rawWrite(cast(ubyte[])src);
  }


}

alias BigStream = /*shared*/ BigStream_;


////////////////////////////////////////////////////////////////////////////////
///  Strings                                                                 ///
////////////////////////////////////////////////////////////////////////////////

bool isAsciiLower(char c) pure{ return c.inRange('a', 'z'); }
bool isAsciiUpper(char c) pure{ return c.inRange('A', 'Z'); }

char asciiUpper(char c) pure{ return cast(char)(cast(int)c + (c.isAsciiUpper ? 0 : 'A'-'a')); }
char asciiLower(char c) pure{ return cast(char)(cast(int)c + (c.isAsciiLower ? 0 : 'a'-'A')); }

string asciiUpper(string s) { char[] res = s.dup; foreach(ref char ch; res) ch = ch.asciiUpper; return cast(string)res; }
string asciiLower(string s) { char[] res = s.dup; foreach(ref char ch; res) ch = ch.asciiLower; return cast(string)res; }

auto uc(char s) pure{ return s.toUpper; }
auto lc(char s) pure{ return s.toLower; }

auto uc(wchar s) pure{ return s.toUpper; }
auto lc(wchar s) pure{ return s.toLower; }

auto uc(dchar s) pure{ return s.toUpper; }
auto lc(dchar s) pure{ return s.toLower; }

string uc(string s) pure{ return s.toUpper; }
string lc(string s) pure{ return s.toLower; }

///generates D source string format from values
string escape(T)(T s){
  return format!"%(%s%)"([s]);
}

string capitalize(alias fv = toUpper)(string s){
  if(!s.empty){
    char u = fv([s[0]])[0];
    if(u != s[0]) s = u~s[1..$];
  }
  return s;
}

void listAppend(ref string s, string what, string separ){
  auto w = what.strip;
  if(w.empty) return;
  if(!s.strip.empty) s ~= separ;
  s ~= w;
}

string truncate(string ellipsis="...")(string s, size_t maxLen){ //todo: string.truncate-t megcsinalni unicodeosra rendesen.
/*  enum ellipsisLen = ellipsis.walkLength;
  auto len = s.walkLength;
  return len<=maxLen ? s
                     : len>ellipsisLen ? s.take(maxLen-ellipsisLen)~ellipsis
                                       : s.take(maxLen);*/
  enum ellipsisLen = ellipsis.length;
  auto len = s.length;
  return len<=maxLen ? s
                     : maxLen>ellipsisLen ? s[0..maxLen-ellipsisLen]~ellipsis
                                          : s[0..maxLen];
}


string decapitalize()(string s){ return s.capitalize!toLower; }

bool sameString(string a, string b) { return a==b; }
bool sameText(string a, string b) { return uc(a)==uc(b); }

/// Show the differences in 2 strings
string strDiff(char diffChar='^', char sameChar='_')(string a, string b){
  string res;
  foreach(i; 0..min(a.length, b.length)) res ~= a[i]==b[i] ? sameChar : diffChar;
  res ~= [diffChar].replicate(a.length>b.length ? a.length-b.length : b.length>a.length);
  return res;
}

//strips specific strings at both ends.
string strip2(string s, string start, string end){
  if(s.length >= start.length + end.length && s.startsWith(start) && s.endsWith(end))
    return s[start.length..$-end.length];
  else
    return s;
}

private S _withoutStarting(bool start, bool remove, S, T)(in S s, in T end){
  static if(start) alias fv = startsWith;
              else alias fv = endsWith;
  const e = end.to!S;
  if(e != "" && fv(s, e) == remove){
    return remove ? start ? s[e.length..$]
                          : s[0..$-e.length]
                  : start ? e ~ s
                          : s ~ e;
  }else return s;
}

S withoutStarting(S, T)(in S s, in T end){ return _withoutStarting!(1, 1)(s, end); }
S withoutEnding  (S, T)(in S s, in T end){ return _withoutStarting!(0, 1)(s, end); }
S withStarting   (S, T)(in S s, in T end){ return _withoutStarting!(1, 0)(s, end); }
S withEnding     (S, T)(in S s, in T end){ return _withoutStarting!(0, 0)(s, end); }

//todo: unittest
/*    assert("a/".withoutEnding("/") == .print;
    "a/b".withoutEnding("/").print;
    "a/".withoutStarting("/").print;
    "/a".withoutStarting("/").print;

a
a/b
a/
a*/

string getFirstDir(char sep='\\')(string s){
  auto i = s.indexOf(sep);
    return i<0 ? "" : s[0..i];
}

string withoutFirstDir(char sep='\\')(string s){
  auto i = s.indexOf(sep);
    if(i<0) return s;
    return i<0 ? s : s[i+1..$];
}


string[] withoutLastEmpty(string[] lines){
  if(!lines.empty && lines[$-1].strip.empty) return lines[0..$-1];
  return lines;
}

void removeLastEmpty(ref string[] lines){
  lines = lines.withoutLastEmpty;
}

//todo: revisit string pchar conversion

auto toPChar(S)(S s) nothrow { //converts to Windows' string
  const(char)* r;
  try { r = toUTFz!(char*)(s); }catch{}
  return r;
}

auto toPWChar(S)(S s) nothrow { //converts to Windows' widestring
  const(wchar)* r;
  try { r = toUTF16z(s); }catch{}
  return r;
}

//builds c zterminated string
void strMake(string src, char* dst, size_t dstLen)
in{
  assert(dst !is null);
  assert(dstLen>=1);
}body{
  size_t sLen = min(dstLen-1, src.length);
  memcpy(dst, src.ptr, sLen);           //todo: this is so naive. Must revisit...
  dst[sLen] = 0; //zero terminated
}

void strMake(string src, char[] dst){
  strMake(src, dst.ptr, dst.length);
}

string dataToStr(const(void)* src, size_t len){ //todo: this is ultra-lame:  (cast(char[])src)[0..len].to!string
  char[] s;
  s.length = len;
  memcpy(s.ptr, src, len);
  return s.to!string;
}

string dataToStr(const(void)[] src){
  return dataToStr(src.ptr, src.length);
}

string dataToStr(T)(const T src){
  return dataToStr(&src, src.sizeof);
}


string toStr(T)(const(T)* s){ return s.to!string; }

string toStr(T)(const(T)* s, size_t maxLen){ return toStr(s[0..maxLen]); }

string toStr(const char[] s){ //safe version, handles well without zero too
  auto e = (cast(ubyte[])s).countUntil(0);
  if(e<0) e = s.length;
  return s[0..e].to!string;
}

string toStr(const wchar[] s){ //safe version, handles well without zero too
  auto e = (cast(ushort[])s).countUntil(0);
  if(e<0) e = s.length;
  return s[0..e].to!string;
}

string toStr(const dchar[] s){ //safe version, handles well without zero too
  auto e = (cast(uint[])s).countUntil(0);
  if(e<0) e = s.length;
  return s[0..e].to!string;
}

string binToHex(in void[] input){
  return toHexString!(LetterCase.upper)(cast(ubyte[])input);
}

string toHex(in void[] input){ return(binToHex(input)); }

ubyte[] hexToBin(string s){
  if(s.startsWith("0x") || s.startsWith("0X")) s = s[2..$];

  ubyte[] r;
  r.reserve(s.length/2);

  bool state;
  int tmp;
  void append(int num){
    if(state) r ~= cast(ubyte)(tmp<<4 | num);
         else tmp = num;
    state = !state;
  }

  foreach(ch; s){
    if(ch.among(' ', '\r', '\n', '\t')) {}
    else if(inRange(ch, '0', '9')) append(ch-'0');
    else if(inRange(ch, 'a', 'f')) append(ch-'a'+10);
    else if(inRange(ch, 'A', 'F')) append(ch-'A'+10);
    else break;
  }

  //state is true (odd number of digits) -> don't care
  return r;
}

string hexToStr(in string s){ return cast(string)hexToBin(s); }

bool isHexDigit(dchar ch) @safe {
  return isDigit(ch)
      || inRange(ch, 'a', 'f')
      || inRange(ch, 'A', 'F');
}

bool isDigit(dchar ch) @safe { // also there is std.uni.inNumber
  return inRange(ch, '0', '9');
}

bool isLetter(dchar ch) @safe { // also there is std.uni.isAlpha
  return inRange(ch, 'a', 'z')
      || inRange(ch, 'A', 'Z');
}

bool isWordChar(dchar ch) @safe
{
  return isLetter(ch) || isDigit(ch) || ch=='_';
}

bool isWordCharExt(dchar ch) @safe
{
  return isWordChar(ch) || ch.among('#', '$', '~');
}

bool isIdentifier(const string s) @safe
{
  if(isDigit(s.get(0))) return false; //can't be number
  auto w = s.wordAt(0);
  return w.length==s.length;
}

string wordAt(const string s, const ptrdiff_t pos) @safe //todo: this is ascii!!!! fails if isWordChar contains uni.isAlpha or uni.isNumber!!!!
{
  if(!isWordChar(s.get(pos))) return "";

  size_t st = pos;   while(isWordChar(s.get(st-1))) st--;
  size_t en = pos+1; while(isWordChar(s.get(en))) en++;

  return s[st..en];
}

ptrdiff_t indexOfWord(const string s, const string sub, size_t startIdx, in std.string.CaseSensitive cs = Yes.caseSensitive) @safe
{
  ptrdiff_t res;
  while(1){
    res = indexOf(s, sub, startIdx, cs);
    if(res<0) break;
    if(!isWordChar(s.get(res-1)) && !isWordChar(s.get(res+sub.length))) break;
    startIdx = res+1;
  }
  return res;
}

ptrdiff_t indexOfWord(const string s, const string sub, in std.string.CaseSensitive cs = Yes.caseSensitive) @safe
{
  return indexOfWord(s, sub, 0, cs);
}

T toInt(T=int)(string s){ //todo: toLong
  if(s.length>2 && s[0]=='0'){
    if(s[1].among('x', 'X')) return s[2..$].to!T(16);
    if(s[1].among('b', 'B')) return s[2..$].to!T( 2);
  }
  return s.to!T;
}

string replaceWords(alias fun = isWordChar)(string str, string from, string to){
  auto src = (&str).refRange;

  auto fetchAndReplace(bool isWord, uint len){
    auto act = src.takeExactly(len).text;
    return isWord && act==from ? to : act;
  }

  static if(0){  //todo: compare the speed of this functional approach
    return str.map!fun
              .group
              .map!(p => fetchAndReplace(p[]));
              .join;
  }else{
    string res;
    foreach(isWord, len; str.map!fun.group)
      res ~= fetchAndReplace(isWord, len);
    return(res);
  }
}

//todo: isWild variadic return parameters list, like formattedtext
struct WildResult{ static:
  private string[] p;
  void _reset()                         { p = []; }
  void _append(string s)                { p ~= s; }

  auto length()                         { return p.length; }
  auto empty()                          { return p.empty; }
  auto strings(size_t i, string def="") { return i<length ? p[i] : def; }
  auto opIndex(size_t i)                { return strings(i); }

  auto to(T)(size_t i, T def = T.init){
    try{
      auto s = strings(i).strip;
      static if(isIntegral!T){
        return s.toInt.to!T; //use toint for 0x hex and 0b bin. long is not supported yet
      }else{
        return s.to!T;
      }
    }catch(Throwable){ return def; }
  }

  auto ints(size_t i, int def = 0)      { try return to!int  (i); catch(Throwable) return def; }
  auto floats(size_t i, float def = 0)  { try return to!float(i); catch(Throwable) return def; }

  void stripAll(){
    foreach(ref s; p) s = s.strip;
  }

  string toString() { return p.text; }
}

alias wild = WildResult;

bool isWild(bool ignoreCase = true, char chAny = '*', char chOne = '?')(string input, string wildStr){
  //bool cmp(char a, char b){ return ignoreCase ? a.toLower==b.toLower : a==b; }
  const cs = ignoreCase ? No.caseSensitive : Yes.caseSensitive;   //kibaszott kisbetu a caseSensitive c-je. Kulonben osszeakad az std.path.CaseSensitive enummal.
  if(1) wild._reset;

  while(1){
    string wildSuffix;   //string precedding wildcards
    size_t wildReq;      //number of '?' in wild
    bool wildAnyLength;  //there is * in the wildcard
    string actOutput;

    //fetch wildBlock  [??*abc]
    while(wildStr.length){
      if(wildStr[0]==chAny) { wildAnyLength = true; wildStr = wildStr[1..$]; }
      else if(wildStr[0]==chOne) { wildReq++; wildStr = wildStr[1..$]; }
      else break;
    }
    while(wildStr.length && !wildStr[0].among(chAny, chOne))
      wildSuffix ~= wildStr.popFirst; //slow

    //get the required minimal amount of chars
    if(input.length<wildReq) return false;
    if(1) actOutput = input[0..wildReq];
    input = input[wildReq..$];

    if(wildSuffix.empty){ //search for end of input
      if(wildAnyLength){  //if there is a * at the end
        if(1){
          actOutput ~= input;
          wild._append(actOutput);
        }
        return true;
      }else{ //if not *
        if(wildReq>0 && 1) wild._append(actOutput);
        return input.empty;
      }
    }

    //there is a string to match
    auto i = input.indexOf(wildSuffix, cs);
    if(i<0) return false;
    if(!wildAnyLength && i!=0) return false;

    if(1 && (wildAnyLength || wildReq)){
      actOutput ~= input[0..i];
      wild._append(actOutput);
    }
    input = input[i+wildSuffix.length..$];
  }

}

alias StrMap = string[string];

auto mapToStr(const StrMap map){
  return map.length ? JSONValue(map).toString
                    : "";
}

auto strToMap(const string str)
{
  string[string] map;
  try{
    auto j = str.parseJSON;
    if(j.type==JSONType.OBJECT)
      foreach(string key, ref val; j)
        map[key] = val.str;
  }catch(Throwable){}
  return map;
}

string withoutQuotes(string s, char q){
  if(s.length>=2 && s.startsWith('\"') && s.endsWith('\"'))
    s = s[1..$-1].replace([q, q], [q]);
  return s;
}


auto splitQuotedStr(string line, char delim, char quote){
  auto s = line.dup;

  //mark non-quoted spaces
  bool inQuote;
  foreach(ref char ch; s){
    if(ch==quote) inQuote = !inQuote;
    if(!inQuote && ch==delim) ch = '\1'; //use #1 as a marker for splitting
  }

  return s.split('\1').to!(string[]);
}


auto splitCommandLine(string line){
  //split, convert, strip, filter empties
  return line.splitQuotedStr(' ', '"')
             .map!(a => a.strip.to!string.withoutQuotes('"'))
             .filter!(a => !a.empty)
             .array;
}


auto commandLineToMap(string line){
  string[string] map;
  int paramIdx;
  foreach(s; line.splitCommandLine){
    string key, value;

    //try to split at '='
    bool keyValueFound;
    foreach(i, ch; s){
      if(ch=='"') break;
      if(ch=='='){
        key = s[0..i];
        value = s[i+1..$].withoutQuotes('"');
        keyValueFound = !key.empty;
        break;
      }
    }

    //unnamed parameter
    if(!keyValueFound){
      key = (paramIdx++).text;
      value = s;
    }

    map[key] = value;
  }

  map.rehash;
  return map;
}

string quoted(string s, char q = '"'){
  if(q=='"') return format!"%(%s%)"([s]);
  else if(q=='`') return q ~ s.replace(q, ' ') ~ q;
  else ERR("Unsupported quote char: "~q);
  assert(0);
}

/*string quoteForDos(){

}*/


auto joinCommandLine(string[] cmd)//todo: handling quotes
{
  auto wcmd = cmd.map!(a => to!wstring(a)).array; //convert to wstrings
  foreach(ref a; wcmd){
    if(a.canFind('"')) continue; //already quoted.
    if(a.empty){
      a = `""`; //empty string
    }else if(a.canFind(' ')){
      if(a[0]=='/' && a.canFind(':')){
        //quotes for MSLink.exe.   /OUT:"c:\file name.b"
        auto p = a.countUntil(':')+1;
        a = a[0..p]~'"'~a[p..$]~'"';
      }else{
        a = '"'~a~'"'; //add quotes
      }
    }
  }
  return to!string(wcmd.join(' ')); //join
}

unittest{
  auto s = "\"hello\u00dc aa\" world";
  assert(joinCommandLine(splitCommandLine(s))==s);
  assert(joinCommandLine([`/OUT:file name.exe`])==`/OUT:"file name.exe"`);
}

public import std.net.isemail : isEmail;

string indent(int cnt, char space = ' ') @safe { return [space].replicate(cnt); }
string indent(string s, int cnt, char space = ' ') @safe {
  string id = indent(cnt, space);
  return s.split('\n')
          .map!strip
          .map!(l => l.empty ? "" : id~l)
          .join("\r\n");
}

//std.algorithm.findsplit is similar
bool split2(string s, string delim, out string a, out string b, bool doStrip = true){ //split to 2 parts
  auto i = s.countUntil(delim);
  if(i>=0){
    a = s[0..i];
    b = s[i+delim.length..$];
  }else{
    a = s;
    b = "";
  }

  if(doStrip){
    a = a.strip;
    b = b.strip;
  }

  return i>=0;
}

string[] split2(string s, string delim, bool doStrip = true){
  string s1, s2;
  split2(s, delim, s1, s2, doStrip);
  return [s1, s2];
}

string join2(string a, string delim, string b){
  if(a.length && b.length) return a ~ delim ~ b;
  if(a.length) return a;
  return b;
}

string capitalizeFirstLetter(string s){
  if(s.empty) return s;
  return s[0..1].uc ~ s[1..$];
}

string stripRightReturn(string a){
  if(a.length && a[$-1]=='\r') return a[0..$-1];
  return a;
}

auto tabTextToCells(string text, immutable(char)[2] delims = "\t\n"){
  string[] lines = text.split(delims[1]).array;
  string[][]cells = lines.map!(s => s.stripRightReturn.split(delims[0]).map!strip.array).array;

  //add empty cells where needed
  auto maxCols = cells.map!(c => c.length).maxElement;
  foreach(ref c; cells) c.length = maxCols;
  return cells;
}

auto csvToCells(string text){
  return tabTextToCells(text, ";\n");
}

string[] splitLines(string s){
  return s.split('\n').map!(a => a.withoutEnding('\r')).array;
}

dstring[] splitLines(dstring s){
  return s.split('\n').map!(a => a.withoutEnding('\r')).array;
}

bool startsWith_ci(string s, string w) pure{
  if(w.length>s.length) return false;
  foreach(i, ch; w){
    if(uc(s[i]) != uc(ch)) return false;
  }
  return true;
}

string skipOver_ci(string s, string w) pure{
  return s.startsWith_ci(w) ? s[w.length..$] : s;
}

auto splitSections(string sectionNameMarker="*")(ubyte[] data, string sectionDelim){
  //example of a section delimiter: "\n\n$$$SECTION:*\n\n"
  struct SectionRec{
    string key;
    ubyte[] value;
  }

  string d0, d1;
  sectionDelim.split2(sectionNameMarker, d0, d1, false);
  enforce(d0.length && d1.length, "Invalid sectionDelimiter");

  auto parts = data.split(cast(const ubyte[])d0);
  SectionRec[] res;

  if(parts.length && parts[0].length)
    res ~= SectionRec("", parts[0]); //first noname section

  if(parts.length>1) foreach(p; parts[1..$]){
    auto i = p.countUntil(cast(const ubyte[])d1);
    if(i>=0) res ~= SectionRec(cast(string)(p[0..i]), p[i+d1.length..$]);
  }

  return res;
}

/// Because the one in std is bugging
string outdent(string s){
  return s.split('\n').map!(a => a.withoutEnding('\r').stripLeft).join('\n');
}

/// makes "Hello world" from "helloWorld"
string camelToCaption(string s){
  import std.uni;
  if(s=="") return s; //empty
  if(s[0].isUpper) return s; //starts with uppercase

  //fetch a word
  auto popWord(){
    string word;
    while(s.length){
      char ch = s[0]; //no unicode support
      if(!word.empty && ch.isUpper) break;
      s = s[1..$];
      word ~= ch;
    }
    return word;
  }

  string[] res;
  while(s.length){ res ~= popWord; }

  foreach(idx, ref w; res) w = idx ? w.toLower : w.capitalize;

  return res.join(' ');
}

void mergeUrlParams(ref string s1, string s2){
  string path1, params1; split2(s1, "?", path1, params1);
  string path2, params2; split2(s2, "?", path2, params2);

  enforce(path1.empty || path1==path2);

  string[string] m;

  foreach(s; chain(params1.split('&'), params2.split('&'))){
    string name, value; split2(s, "=", name, value);
    m[name] = value;
  }

  string[] res;
  foreach(k, v; m)
    res ~= k~'='~v;

  s1 = path2~'?'~res.join('&');
}

// structs to text /////////////////////////////////////

string toString2(T)(in T obj)
if(isAggregateType!T)
{
  string[] parts;
  alias types = FieldTypeTuple!T;
  foreach(idx, name; FieldNameTuple!T){
    string value = mixin("obj."~name~".text;");
    if(isSomeString!(types[idx])) value = value.quoted;
    parts ~= format!"%s : %s"(name, value);
  }
  return format!"%s(%s)"(T.stringof, parts.join(", "));
}

void clearFields(T)(T obj)
if(isAggregateType!T)
{
  foreach(f; FieldNameTuple!T) mixin("obj.$ = T.$.init;".replace("$", f));
}

// Meta helpers ///////////////////////////

auto getSymbolNamesByUDA(T, string uda)(){
  string[] res;
  static foreach(a; getSymbolsByUDA!(T, uda)) res ~= a.stringof;
  return res;
}

/*
// this is a __traits only version for string UDAs
auto getSymbolNamesByUDA(T, string uda)(){
  string[] res;
  static foreach(n; __traits(allMembers, T)) {
    // static, but don't use static foreach so you can break
    foreach(u; __traits(getAttributes, __traits(getMember, T, n)))
      static if(is(typeof(u) == string) && u == uda) {
        res ~= n;
        break;
      }
   }
  return res;
}*/

template getUDA(alias a, U){
  enum u = q{ getUDAs!(a, U)[$-1] };
    static if(hasUDA!(a, U) && !is(mixin(u)))
      enum getUDA = mixin(u);
    else
      enum getUDA = U.init;
}

///helper templates to get all the inherited class fields, works for structs as well
template AllClasses(T){
       static if(is(T == Object)) alias AllClasses = AliasSeq!();
  else static if(is(T == class )) alias AllClasses = Reverse!(AliasSeq!(T, BaseClassesTuple!T[0..$-1]));
  else                            alias AllClasses = T;
}

alias AllFieldNames(T) = staticMap!(FieldNameTuple, AllClasses!T);

alias AllFields(T) = staticMap!(tupleof, AllClasses!T);

template FieldNamesWithUDA(T, U, bool allIfNone){
  enum fields = AllFieldNames!T;
  enum bool hasThisUDA(string fieldName) = hasUDA!(__traits(getMember, T, fieldName), U);

  static if(allIfNone){
    static if(anySatisfy!(hasThisUDA, fields))
      enum FieldNamesWithUDA = Filter!(hasThisUDA, fields);
    else
      enum FieldNamesWithUDA = fields;
  }else{
    enum FieldNamesWithUDA = Filter!(hasThisUDA, fields);
  }
}


string[] getEnumMembers(T)(){
  static if(is(T == enum)) return [__traits(allMembers, T)];
  else return [];
}


alias toAlias(alias T) = T;

void inspectSymbol(alias T)(string before="", int level=0) {
  enum maxInspectLevel = 10;

  // step 2
  foreach(memberName; __traits(allMembers, T)) static if(__traits(compiles, toAlias!(__traits(getMember, T, memberName)))) {
    // step 3
    alias member = toAlias!(__traits(getMember, T, memberName));  //sometimes this alias declaration fails.
    // step 4 - inspecting types
    static if(is(member)) {
      string specifically;
      static if(is(member == struct))
        specifically = "struct";
      else static if(is(member == class))
        specifically = "class";
      else static if(is(member == enum))
        specifically = "enum";
      writeln(before, fullyQualifiedName!member, " is a type (", specifically, ")");
      // drill down (step 1 again)
      static if(is(member == struct) || is(member == class) || is(member == enum)){
        static if(!is(T) || !is(member == T)){ //ignore types that contain an alias for typeof(this)
          if(level<maxInspectLevel){ //limit recursion
            inspectSymbol!member(before ~ "\t", level+1);
          }
        }
      }else{
        writeln(before ~"\t", fullyQualifiedName!member, " : ", member.stringof);
      }
    } else static if(is(typeof(member) == function)) {
      // step 5, inspecting functions
      writeln(before, fullyQualifiedName!member, " is a function typed ", typeof(member).stringof);
    } else {
      // step 6, everything else

        static if(__traits(compiles, member.stringof)) enum s = member.stringof; else enum s = "";

        static if(s.startsWith("module "))
          writeln(before, fullyQualifiedName!member, " is a module");
        else static if(s.startsWith("package "))
          writeln(before, fullyQualifiedName!member, " is a package");
        else static if(is(typeof(member.init))){
          static if(member.stringof.endsWith(')')){
            writeln(before, fullyQualifiedName!member, " is a property typed ", typeof(member).stringof);
          }else{
            writeln(before, fullyQualifiedName!member, " is a variable typed ", typeof(member).stringof);
          }
        }else{
          string fn = memberName;
          static if(__traits(compiles, fullyQualifiedName!member)) fn = fullyQualifiedName!member;
          writeln(before, fn, " is template ", s);
        }
    }
  }else{
    print("!!!!!!!!!!!!!!!!!!!!!!! unable to compile toAlias!(__traits(getMember, T, memberName) on symbol:", T.stringof ~ "." ~ memberName);
  }
}


static T Singleton(T)() if(is(T == class)){ // Singleton ////////////////////////
  import std.traits : SharedOf;
  enum isShared = is(SharedOf!T == T);
  enum log = false;

  static if(isShared){
    static T instance;
    static bool initialized;
    if(!initialized){
      synchronized{
        if(instance is null){
          instance = new T;
          if(log) LOG(`created.`);
        }
      }
      initialized = true;
    }
  }else{
    __gshared static T instance;
    if(instance is null){
      instance = new T;
      if(log) LOG(`created.`);
    }
  }

  return instance;
}


// hexDump ///////////////////////////
//import std.algorithm, std.stdio, std.file, std.range;

void hexDump(in void[] data){
  auto d = cast(const ubyte[])data;
  int idx;
  foreach(chunk; d.chunks(16)){
    "%.4X %(%02X %)%*s  %s".writefln(idx++*16, chunk,
      3 * (16 - chunk.length), "", // Padding
      chunk.map!(c => // Replace non-printable
        c < 0x20 || c > 0x7E ? '.' : char(c)));
  }
}

// UNICODE /////////////////////////////////////////////

//unicodeStandardLetter: these can be stylized by fonts, such as Arial/Consolas/Times. Other characters are usually the same, eg.: Chineese chars.
//  containt ranges of latin, greek, cyril, armenian chars. These can have different representations across each fonts
bool isUnicodeStandardLetter(dchar ch){
  immutable unicodeStandardLetterRanges = [ [0x0020, 0x024F], [0x0370, 0x058F], [0x1C80, 0x1C8F], [0x1E00, 0x1FFF], [0x2C60, 0x2C7F], [0x2DE0, 0x2DFF], [0xA640, 0xA69F], [0xA720, 0xA7FF], [0xAB30, 0xAB6F] ];
  foreach(const r; unicodeStandardLetterRanges)
    if(ch.inRange(r[0], r[1])>=r[0] && ch<=r[1]) return true;
  return false;
}

enum UnicodePrivateUserAreaBase = 0xF0000;

bool isUnicodeColorChar(dchar ch){
  enforce(0, "not impl");
  return false;
}

/*
    int[] UnicodeEmojiBlocks = [
      0x00A,           //Latin1 supplement

      0x203, 0x204,    //2000-206F General Punctuation
      0x212, 0x213,    //2100-214F Letterlike Symbols
      0x219, 0x21A,    //2190-21FF Arrows

      0x231, 0x232,    //2300-23FF Miscellaneous Technical
      0x23C,
      0x23E, 0x23F,

      0x24C,           //2460-24FF Enclosed Alphanumerics

      0x25A, 0x25B, 0x25C, //25A0-25FF Geometric Shapes
      0x25F,

      0x260, 0x261, 0x262, 0x263, 0x264, 0x265, 0x266, 0x267,  //2600-26FF Miscellaneous Symbols
      0x269, 0x26A, 0x26B, 0x26C, 0x26D, 0x26E, 0x26F,

      0x270, 0x271, 0x272, 0x273, 0x274, 0x275, 0x276,         //2700-27BF Dingbats
      0x279, 0x27A, 0x27B,

      0x293,  //2900-297F Supplemental Arrows-B

      0x2B0, 0x2B1, //2B00-2BFF Miscellaneous Symbols and Arrows
      0x2B5,

      0x303,        //3000-303FCJK Symbols and Punctuation

      0x329,        //3200-32FF Enclosed CJK Letters and Months

      0x1F00,       //1F000-1F02F Mahjong Tiles

      0x1F0C,       //1F0A0-1F0FF Playing Cards

      0x1F17, 0x1F18, 0x1F19, //1F100-1F1FF Enclosed Alphanumeric Supplement

      0x1F20, 0x1F21, 0x1F22, 0x1F23, //1F200-1F2FF Enclosed Ideographic Supplement
      0x1F25,

      //1F300-1F5FF Miscellaneous Symbols and Pictographs
      0x1F30, 0x1F31, 0x1F32, 0x1F33, 0x1F34, 0x1F35, 0x1F36, 0x1F37, 0x1F38, 0x1F39, 0x1F3A, 0x1F3B, 0x1F3C, 0x1F3D, 0x1F3E, 0x1F3F, 0x1F40, 0x1F41, 0x1F42, 0x1F43, 0x1F44, 0x1F45, 0x1F46, 0x1F47, 0x1F48, 0x1F49, 0x1F4A, 0x1F4B, 0x1F4C, 0x1F4D, 0x1F4E, 0x1F4F, 0x1F50, 0x1F51, 0x1F52, 0x1F53, 0x1F54, 0x1F55, 0x1F56, 0x1F57, 0x1F58, 0x1F59, 0x1F5A, 0x1F5B, 0x1F5C, 0x1F5D, 0x1F5E, 0x1F5F,

      0x1F60, 0x1F61, 0x1F62, 0x1F63, 0x1F64, //1F600-1F64F Emoticons (Emoji)

      0x1F68, 0x1F69, 0x1F6A, 0x1F6B, 0x1F6C, 0x1F6D, 0x1F6E, 0x1F6F, //1F680-1F6FF Transport and Map Symbols

      //1F900-1F9FF Supplemental Symbols and Pictographs
      0x1F91, 0x1F92, 0x1F93, 0x1F94, 0x1F95, 0x1F96, 0x1F97, 0x1F98, 0x1F99, 0x1F9A, 0x1F9B, 0x1F9C, 0x1F9D, 0x1F9E, 0x1F9F
    ];
*/


// byLineBlock /////////////////////////////////////////////////

enum DefaultLineBlockSize =  1<<20,
     MaxLineBlockSeekBack = 16<<10;

struct FileBlock{
  //todo: kiprobalni stdFile-val is, hogy gyorsabb-e
  File file;
  size_t pos, size;
  bool truncated; //The block is not on boundary, because it was unable to seek back
}

auto read   (in FileBlock fb, bool mustExists=true){ with(fb) return file.read   (mustExists, pos, size); }
auto readStr(in FileBlock fb, bool mustExists=true){ with(fb) return file.readStr(mustExists, pos, size); }

auto byLineBlock(File file, size_t maxBlockSize=DefaultLineBlockSize){

  static struct TextFileBlockRange{
    File file;
    size_t maxBlockSize, pos, size;

    size_t actBlockSize;

    bool empty() const{ return pos>=size; }

    auto front(){
      if(actBlockSize) return FileBlock(file, pos, actBlockSize); //already fetched

      if(pos>=size) return FileBlock(file, size, 0); //eof

      auto remaining = size-pos;

      if(remaining<=maxBlockSize){
        actBlockSize = remaining;
      }else{
        auto endPos = pos + maxBlockSize;
        const seekBackSize    = min(maxBlockSize/2, MaxLineBlockSeekBack), // max 16K-val vissza, de csak a block 50%-ig.
              seekBackLimit   = endPos-seekBackSize,
              stepSize        = min(256, seekBackSize);
        while(endPos > seekBackLimit){
          auto idx = file.read(false, endPos-stepSize, stepSize)
                         .retro.countUntil(0x0A);

          if(idx>=0){ //got a newline
            actBlockSize = (endPos-idx)-pos;
            break;
          }

          endPos -= stepSize; //try prev block...
        }

        if(!actBlockSize){
          actBlockSize = maxBlockSize;
          return FileBlock(file, pos, actBlockSize, true); //signal truncated with a true flag
          //INFO("Unable to seek to a newline. Using maxBlockLength");

        }
      }

      return FileBlock(file, pos, actBlockSize);
    }

    void popFront(){
      front; //make sure to seek
      pos += actBlockSize;
      actBlockSize = 0;
    }
  }

  assert(maxBlockSize>0);

  auto res = TextFileBlockRange(file, maxBlockSize);
  if(file.exists){
    res.size = cast(size_t)(file.size);
  }else{
    WARN("File not found ", file);
  }

  return res;
}


auto byLineBlock(string str, size_t maxBlockSize=DefaultLineBlockSize){  //todo: egy kalap ala hozni a stringest meg a fileost

  static struct StringBlockRange{
    string str;
    size_t maxBlockSize, pos;
    auto size() const{ return str.length; }

    size_t actBlockSize;

    bool empty() const{ return pos>=size; }

    auto front(){
      if(actBlockSize) return str[pos..pos+actBlockSize]; //already fetched

      if(pos>=size) return "";

      auto remaining = size-pos;

      if(remaining<=maxBlockSize){
        actBlockSize = remaining;
      }else{
        auto endPos = pos + maxBlockSize;
        const seekBackSize    = min(maxBlockSize/2, MaxLineBlockSeekBack), // max 16K-val vissza, de csak a block 50%-ig.
              seekBackLimit   = endPos-seekBackSize,
              stepSize        = min(256, seekBackSize);
        while(endPos > seekBackLimit){
          auto idx = (cast(ubyte[])str[endPos-stepSize..endPos])
                     .retro.countUntil(0x0A);

          if(idx>=0){ //got a newline
            actBlockSize = (endPos-idx)-pos;
            break;
          }

          endPos -= stepSize; //try prev block...
        }

        if(!actBlockSize){ //truncated block
          actBlockSize = maxBlockSize;
        }

      }

      return str[pos..pos+actBlockSize];
    }

    void popFront(){
      front; //make sure to seek
      pos += actBlockSize;
      actBlockSize = 0;
    }
  }

  assert(maxBlockSize>0);

  auto res = StringBlockRange(str, maxBlockSize);

  return res;
}

/*void testByLineBlock(){
  auto file = File(tempPath, `testByLineBlocks.tmp`);
  scope(exit) file.remove;

  RNG rng;
  auto text = iota(10).map!(i => iota(rng(3)+(i==5 ? 30 : 2)).map!(j => j.text).join)
                      .join("\r\n");
  text.saveTo(file);

  auto a = file.byLineBlock(12).map!readStr.array,
       b = file.readStr.byLineBlock(12).array;

  //writeln("text\n", text);

  //writeln("a\n", a.join('|'));
  //writeln("b\n", b.join('|'));

  //writeln("a\n", a.map!"cast(ubyte[])a".array);
  //writeln("b\n", b.map!"cast(ubyte[])a".array);

  enforce(a.join == text, "file.byLineBlocks fail1");
  enforce(b.join == text, "string.byLineBlocks fail1");
  enum h = 3496071129;
  enforce(a.join('|').xxh == h, "file.byLineBlocks fail2");
  enforce(b.join('|').xxh == h, "string.byLineBlocks fail2");
}*/

enum TextEncoding               { ANSI, UTF8          ,            UTF32BE,            UTF32LE,    UTF16BE, UTF16LE   } //UTF32 must be checked BEFORE UTF16
private const encodingHeaders = [""   , "\xEF\xBB\xBF", "\x00\x00\xFE\xFF", "\xFF\xFE\x00\x00", "\xFE\xFF", "\xFF\xFE"];
private const encodingCharSize= [1    , 1             ,                  4,                  4,          2,          2];

TextEncoding encodingOf(const string s, TextEncoding def = TextEncoding.UTF8, string* withoutEnc=null){
  foreach(i, hdr; encodingHeaders){
    if(!hdr.empty && s.startsWith(hdr)){
      if(withoutEnc) *withoutEnc = s[hdr.length..$];
      return cast(TextEncoding)(i);
    }
  }

  //default encoding
  if(withoutEnc) *withoutEnc = s;
  return def;
}

string stripEncoding(const string s){
  string res;
  encodingOf(s, TextEncoding.UTF8, &res);
  return res;
}

string ansiToUTF8(string s){
  wstring ws; .transcode(cast(Windows1252String)s, ws); return ws.toUTF8;
}

dstring ansiToUTF32(string s){
  wstring ws; .transcode(cast(Windows1252String)s, ws); return ws.toUTF32;
}

string textToUTF8(string s, TextEncoding defaultEncoding=TextEncoding.UTF8){ //my version handles BOM
  final switch(encodingOf(s, defaultEncoding, &s)){
    case TextEncoding.ANSI   : return s.ansiToUTF8;
    case TextEncoding.UTF8   : return s;
    case TextEncoding.UTF16LE: auto ws = cast(wstring)s; return ws         .toUTF8;      //todo: cast can fail. What to do then?
    case TextEncoding.UTF16BE: auto ws = cast(wstring)s; return ws.byteSwap.toUTF8;
    case TextEncoding.UTF32LE: auto ds = cast(dstring)s; return ds         .toUTF8;
    case TextEncoding.UTF32BE: auto ds = cast(dstring)s; return ds.byteSwap.toUTF8;
  }
}

dstring textToUTF32(string s, TextEncoding defaultEncoding=TextEncoding.UTF8){ //my version handles BOM
  final switch(encodingOf(s, defaultEncoding, &s)){
    case TextEncoding.ANSI   : return s.ansiToUTF32;
    case TextEncoding.UTF8   : return s.toUTF32;
    case TextEncoding.UTF16LE: auto ws = cast(wstring)s; return ws         .toUTF32;      //todo: cast can fail. What to do then?
    case TextEncoding.UTF16BE: auto ws = cast(wstring)s; return ws.byteSwap.toUTF32;
    case TextEncoding.UTF32LE: return cast(dstring)s;
    case TextEncoding.UTF32BE: auto ds = cast(dstring)s; return ds.byteSwap.toUTF32;
  }
}

class DynCharMap{
private:
  mixin CustomEnforce!"DynCharMap";
//  static void enforce(bool b, lazy string s, string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__){ if(!b) throw new Exception("DynCharMap: "~s, file, line, funct); }

  enum bankSh     = 5,
       bankSize   = 1<<bankSh,
       bankMask   = bankSize-1,
       invMapSize = 1<<(21-bankSh),
       invMapMask = invMapSize-1,       //unicode is 21 bits max
       maxBanks   = 0x200,
       maxChars   = maxBanks<<bankSh;   //max symbol count is limited

  //it keeps growing by 32 char banks
  ushort bankCnt;
  ushort[maxBanks] map;   //tells the unicode bankIdx of a mapped bank. Bank0 is always mapped.
  ushort[invMapSize] invMap; //tells where to find the maps backwards

public:
  this(){
    //bank 0 is always needed to be mapped
    //map ascii charset, 128 chars
    bankCnt = 128/bankSize;
    foreach(ushort i; 0..bankCnt) map[i] =i;
    invMap[0..bankCnt] = map[0..bankCnt];
  }

  override string toString(){
    return "DynCharMap(charCnt/Max=%d/%d, bankSize=%s, [%s])".format(
      (map[].count!"a!=b"(0)+1)<<bankSh,
      maxChars,
      bankSize,
      map[].enumerate.filter!"a.value".map!(a => "%X:%X".format(a.index<<bankSh, a.value<<bankSh)).join(", ")
    );
  }

  ushort encode(dchar ch){
    if(ch<0x80) return cast(ushort)ch; //fastpath... nem sokat gyorsit, simd kene

    ushort uniBank = (cast(uint)ch)>>>bankSh;
    if(uniBank>0){
      if(!invMap[uniBank]){
        enforce(bankCnt < maxBanks, "Ran out of banks.");
        invMap[uniBank] = bankCnt;
        map[bankCnt] = uniBank;
        bankCnt++;

        //writefln("Bank %.6x mapped to %.2x", map[bankCnt-1] << bankSh, bankCnt-1 << bankSh);
      }
    }
    return cast(ushort)(invMap[uniBank]<<bankSh | (cast(ushort)ch)&bankMask);
  }

  dchar decode(const ushort ch){
    if(ch<0x80) return cast(ushort)ch; //fastpath... nem sokat gyorsit, simd kene

    ushort mapBank = ch>>bankSh;
    ushort uniBank = map[mapBank & maxBanks-1];
    return cast(dchar)((uniBank<<bankSh) | ch & bankMask);
  }

  private enum utfInvalidCode = 0xFFFD; //replacement char

  auto encodeUTF8(ref ushort[] res, string s){
    import std.encoding;
    //todo: ez bugos
    while(s.length>=8){
      auto raw = cast(ulong*)s.ptr;
      if(*raw & 0x80808080_80808080){ //slow decode
        foreach(i; 0..8) res ~= encode(s.decode);
      }else{ //everyithing is <0x80
        //res.appendUninitialized(8); //nem megy
        res.length += 8;
        foreach(i, ref c; res[$-8..$]) c = cast(ushort)((*raw>>(i<<3))&0xFF);  //todo: sse opt
        s = s[8..$];
      }
    }

    //remainder
    while(!s.empty) res ~= encode(s.decode);
  }

  ushort[] encode(string s, TextEncoding encoding){
    import std.encoding;

    ushort[] res;
    res.reserve(s.length/encodingCharSize[encoding]);                            //ascii  uni
    switch(encoding){
      case TextEncoding.ANSI   : wstring ws; transcode(cast(Windows1252String)s, ws); while(!ws.empty) res ~= encode(ws.decode); break;
      case TextEncoding.UTF8   :                                             encodeUTF8(res, s); break;
      case TextEncoding.UTF16LE: auto ws = cast(wstring)s;                   while(!ws.empty) res ~= encode(ws.decode); break;
      case TextEncoding.UTF16BE: auto ws = cast(wstring)s; ws = ws.byteSwap; while(!ws.empty) res ~= encode(ws.decode); break;
      case TextEncoding.UTF32LE: auto ds = cast(dstring)s;                   while(!ds.empty) res ~= encode(ds.decode); break;
      case TextEncoding.UTF32BE: auto ds = cast(dstring)s; ds = ds.byteSwap; while(!ds.empty) res ~= encode(ds.decode); break;
      default: enforce(false, "TextEncoding not supported: "~encoding.text);
    }
    return res;
  }

  string decode(ushort[] s){
    string res;
    res.reserve(s.length);
    while(s.length>=4){
      auto raw = cast(ulong*)s.ptr;
      if(*raw & 0xff80ff80_ff80ff80){ //any of the 4 wchars are > 0x7F
        foreach(i; 0..4) res ~= decode(s[i]);
      }else{ //all 4 wchars are <= 0x7F, no conversion needed
        char[4] tmp;
        foreach(i, ref c; tmp) c = cast(char)((*raw>>(i<<4))&0xFF);    //todo: sse opt
        res ~= tmp;
      }
      s = s[4..$];
    }

    foreach(ch; s) res ~= decode(ch); //remaining
    return res;
  }

}


////////////////////////////////////////////////////////////////////////////////
///  Random                                                                  ///
////////////////////////////////////////////////////////////////////////////////

// a simple one from Delphi

struct SeedStream{
  // https://en.wikipedia.org/wiki/Linear_congruential_generator
  uint a, c;
  uint seed; // modulo = 2^32 only

  enum empty = false; //infinite range
  uint front() const{ return seed; }
  void popFront() { seed = seed * a + c; }

  void test(int seed){
    print("Testing SeedStream: a:", a, format!"(0x%x)"(a), "  c:", c, format!"(0x%x)"(c));
    BitArray ba;
    ba.length = 1L << 32;
    write("seed = ", seed, "  ");
    ba[] = false;
    auto ss = typeof(this)(seed);
    auto act(){ return ss.front; }
    long cnt = 0;
    while(!ba[act]){
      ba[act] = true;
      ss.popFront;
      cnt++;
    }
    long firstZero = -1; foreach(idx, b; ba) if(!b){ firstZero = idx; break; }
    print("cycle length =", cnt.format!"0x%x", "  first false at:", firstZero);
  }
}

SeedStream SeedStream_numericalRecipes(uint seed){ return SeedStream(   1664525, 1013904223, seed); }
SeedStream SeedStream_pascal          (uint seed){ return SeedStream( 0x8088405,          1, seed); }
SeedStream SeedStream_borlandC        (uint seed){ return SeedStream(  22695477,          1, seed); }

struct RNG {
  auto seedStream = SeedStream_pascal(0x41974702);

  ref uint seed() { return seedStream.seed; }

  void randomize(uint seed) { this.seed = seed; }

  void randomize(){
    long c;
    QueryPerformanceCounter(&c);
    c ^= thisThreadID;
    seed = cast(uint)c*0x784921;
  }

  uint randomUint(){
    seedStream.popFront;
    return seed;
  }

  int randomInt(){
    seedStream.popFront;
    return int(seed);
  }

  float randomFloat(){
    seedStream.popFront;
    return seed*0x1.0p-32;
  }

  uint random(uint n){
    seedStream.popFront;
    return (ulong(seed)*n)>>32;
  }

  int random(int n){
    return int(random(uint(n)));
  }

  ulong random(ulong n){
    if(n<=0xFFFF_FFFF) return random(cast(uint)n);

    return (ulong(randomUint)<<32 | randomUint)%n; //terribly slow
  }

  auto randomGaussPair()
  {
    float x1, x2, w;
    do{
      x1 = randomFloat;
      x2 = randomFloat;
      w = x1*x1 + x2*x2;
    }while(w>1);
    w = sqrt((-2*log(w))/w);

    return tuple(x1*w, x2*w);
  }

  auto randomGauss(){ return randomGaussPair[0]; }

  void randomFill(uint[] values){
    foreach(ref uint v; values)
      v = randomUint;
  }

  void randomFill(uint[] values, uint customSeed){
    uint oldSeed = seed;
    seed = customSeed;
    randomFill(values);
    seed = oldSeed;
  }

  // not good: disables default constructor. int opCall(int max){ return random(max); }
}

RNG defaultRng; //Every thread get's its own, because of different QPC

ref uint randSeed()                             { return defaultRng.seed; }
void randomize(uint seed)                       { defaultRng.randomize(seed); }
void randomize()                                { defaultRng.randomize; }
uint  random(uint  n)                           { return defaultRng.random(n); }
int   random(int   n)                           { return defaultRng.random(n); }
ulong random(ulong n)                           { return defaultRng.random(n); }
uint randomUint()                               { return defaultRng.randomUint; }
uint randomInt()                                { return defaultRng.randomInt; }
float randomFloat()                             { return defaultRng.randomFloat; }
auto randomGaussPair()                          { return defaultRng.randomGaussPair; }
auto randomGauss()                              { return defaultRng.randomGauss; }
void randomFill(uint[] values)                  { defaultRng.randomFill(values); }
void randomFill(uint[] values, uint customSeed) { defaultRng.randomFill(values, customSeed); }


/+ Wonder what's this crap?!!
int getUniqueSeed(T)(in T ptr){ //gets a 32bit seed from a ptr and the current time
  long cnt;  QueryPerformanceCounter(&cnt);
  auto arr = (cast(const void[])[ptr]) ~ (cast(const void[])[cnt]);
  return arr.xxh_internal;
}+/

////////////////////////////////////////////////////////////////////////////////
///  Hashing                                                                 ///
////////////////////////////////////////////////////////////////////////////////

/// Returns a string that represents the identity of the parameter: and object or a pointer or a string
/// If a string is passed, the caller must ensure if it's system wide unique.
string identityStr(T)(in T a){ // identityStr /////////////////////////
       static if(isSomeString!T) return a;
  else static if(isPointer!T   ) return a is null ? "" : format!"%s(%s)"(PointerTarget!T.stringof, cast(void*)a);
  else static if(is(T == class)) return a is null ? "" : format!"%s(%s)"(T.stringof, cast(void*)a);
  else static if(is(T == typeof(null))) return "";
  else static assert(0, "identityStr() unhandled type: "~T.stringof);
}

// xxh //////////////////////////////////////////////////////
// a fast hashing function

//Source: https://github.com/repeatedly/xxhash-d/blob/master/src/xxhash.d
//        https://code.google.com/p/xxhash/
// Copyright: Masahiro Nakagawa 2014-.
// above 8MB it is unofficially parallel
@trusted
uint xxh(bool enableParallel=true)(in void[] source, uint seed = 0){
  if(source.length <= 1<<19){    //Dont change it from 1<<19, otherwise the hash is broken   (was 8<<20)
    return xxh_internal(source, seed);
  }else{
    enum chunkSh   = 16,  //Dont change it from 16, otherwise the hash is broken   (was 20)
         chunkSize = 1<<chunkSh;

    auto hlist = new uint[(source.length+chunkSize-1)>>chunkSh];

    auto ch(size_t i){ return source[i<<chunkSh .. min((i+1)<<chunkSh, $)]; }//todo: megcsinalni ezt funkcionalisra

    static if(enableParallel){
      import std.parallelism;
      foreach(i, ref h; parallel(hlist))
        h = ch(i).xxh_internal;
    }else{
      foreach(i, ref h; hlist)
        h = ch(i).xxh_internal;
    }

    return hlist.xxh_internal(seed);
  }
}

private @trusted pure nothrow
uint xxh_internal(in void[] source, uint seed = 0)   //todo: it must run at compile time too
{
    enum Prime32_1 = 2654435761U,
         Prime32_2 = 2246822519U,
         Prime32_3 = 3266489917U,
         Prime32_4 = 668265263U,
         Prime32_5 = 374761393U;

    enum UpdateValuesRound = q{
        v1 += loadUint(srcPtr) * Prime32_2;  v1 = rol(v1, 13);  v1 *= Prime32_1;  srcPtr++;
        v2 += loadUint(srcPtr) * Prime32_2;  v2 = rol(v2, 13);  v2 *= Prime32_1;  srcPtr++;
        v3 += loadUint(srcPtr) * Prime32_2;  v3 = rol(v3, 13);  v3 *= Prime32_1;  srcPtr++;
        v4 += loadUint(srcPtr) * Prime32_2;  v4 = rol(v4, 13);  v4 *= Prime32_1;  srcPtr++;
    };

    static void xxh_rounds(ref const(uint)* src, const(uint)* limit, uint* v) nothrow{
                         //                 RCX,                RDX,      R8
      //Intel byteorder only!
      if(1){
        do {
          v[0] += *(src  ) * Prime32_2;  v[0] = rol(v[0], 13);  v[0] *= Prime32_1;
          v[1] += *(src+1) * Prime32_2;  v[1] = rol(v[1], 13);  v[1] *= Prime32_1;
          v[2] += *(src+2) * Prime32_2;  v[2] = rol(v[2], 13);  v[2] *= Prime32_1;
          v[3] += *(src+3) * Prime32_2;  v[3] = rol(v[3], 13);  v[3] *= Prime32_1;  src+=4;
        } while (src <= limit);
      }else{  //todo: this is not working
        asm{
          mov EAX, 2246822519;    //XMM4 : Prime2
          movd XMM4, EAX;
          pshufd XMM4, XMM4, 0;

          mov EAX, 2654435761;    //XMM5 : Prime1
          movd XMM5, EAX;
          pshufd XMM5, XMM5, 0;

          movdqu XMM0, [R8];      //XMM0 : v

          mov RAX, [RCX];         //RAX : src
                                  //RDX : limit

        loop:
          movdqu XMM1, [RAX];  add RAX, 16;  //load src

          movdqa XMM2, XMM1;                  //mul with Prime2
          punpckldq XMM1, XMM1;
          punpckldq XMM2, XMM2;
          pmuludq XMM1, XMM4;
          pmuludq XMM2, XMM4;
          pshufd XMM1, XMM2, 0x88;

          paddd XMM0, XMM1;                   //add to v

          movdqa XMM2, XMM0;
          pslld XMM2, 13;              //rol(v, 13)
          psrld XMM0, 32-13;
          por XMM0, XMM2;

          movdqa XMM2, XMM0;                  //mul with Prime1
          punpckldq XMM0, XMM0;
          punpckldq XMM2, XMM2;
          pmuludq XMM0, XMM5;
          pmuludq XMM2, XMM5;
          pshufd XMM0, XMM2, 0x88;

          cmp RAX, RDX;
          jbe loop;

          mov [RCX], RAX;      //write back src

          movdqu [R8], XMM0;   //write back state
        }
      }
    }

    enum FinishRound = q{
        while (ptr < end) {
            result += *ptr * Prime32_5;
            result = rol(result, 11) * Prime32_1 ;
            ptr++;
        }
        result ^= result >> 15;  result *= Prime32_2;
        result ^= result >> 13;  result *= Prime32_3;
        result ^= result >> 16;
    };

    @safe pure nothrow
    uint loadUint(in uint* source)
    {
        version (LittleEndian)
            return *source;
        else
            return swapEndian(*source);
    }

    auto srcPtr = cast(const(uint)*)source.ptr;
    auto srcEnd = cast(const(uint)*)(source.ptr + source.length);
    uint result = void;

    if (source.length >= 16) {
        auto limit = srcEnd - 4;
        auto v = [seed + Prime32_1 + Prime32_2,
                  seed + Prime32_2,
                  seed,
                  seed - Prime32_1];

        xxh_rounds(srcPtr, limit, v.ptr);

        result = rol(v[0], 1) + rol(v[1], 7) + rol(v[2], 12) + rol(v[3], 18);
    } else {
        result = seed + Prime32_5;
    }

    result += source.length;

    while (srcPtr+1 <= srcEnd) {
        result += loadUint(srcPtr) * Prime32_3;
        result = rol(result, 17) * Prime32_4;
        srcPtr++;
    }

    auto ptr = cast(const(ubyte)*)srcPtr;
    auto end = cast(const(ubyte)*)srcEnd;

    mixin(FinishRound);

    return result;
} //todo: xxh unittest

uint xxhuc(in void[] source, uint seed = 0)
{
  return xxh(uc(cast(string)source));
}

void benchmark_xxh(){
  size_t len = 1;
  while(len<2_000_000_000){
    auto data = new ubyte[len];
    auto t0 = QPS;
    xxh(data);
    auto t1 = QPS;

    writefln("len = %10d   time = %6.3f   MB/s = %9.3f", len, t1-t0, len/(t1-t0)/1024/1024);

    len = iceil(len*1.5);
  }
}


// crc32 //////////////////////////////////////////////////////////////////

@trusted pure nothrow
uint crc32(in void[] source, uint seed = 0xffffffff)
{
  immutable uint[256] CRC32tab = [
      0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f,
      0xe963a535, 0x9e6495a3, 0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
      0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91, 0x1db71064, 0x6ab020f2,  //todo: 0b binary syntax highlight bug in 0x hex literals
      0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
      0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9,
      0xfa0f3d63, 0x8d080df5, 0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
      0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b, 0x35b5a8fa, 0x42b2986c,
      0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
      0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423,
      0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
      0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d, 0x76dc4190, 0x01db7106,
      0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
      0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d,
      0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
      0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
      0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
      0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7,
      0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
      0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa,
      0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
      0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81,
      0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
      0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683, 0xe3630b12, 0x94643b84,
      0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
      0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
      0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
      0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5, 0xd6d6a3e8, 0xa1d1937e,
      0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
      0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55,
      0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
      0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe, 0xb2bd0b28,
      0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
      0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f,
      0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
      0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
      0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
      0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69,
      0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
      0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc,
      0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
      0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693,
      0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
      0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d  ];

  uint r = seed;

  foreach(const d; cast(ubyte[])source)
    r = CRC32tab[cast(ubyte)r^d]^(r>>>8);

  return ~r;
}

uint crc32uc(in void[] source, uint seed = 0xffffffff)
{
  return crc32(uc(cast(string)source));
}

enum bigPrime = 1515485863;

uint hashCombine(uint c1, uint c2)
{
  return c1*bigPrime+c2;
}

//! norx /////////////////////////////////////

struct norx(int w/*wordSize*/, int l/*loopCnt*/, int p/*parallelCnt*/)
if(w.among(32, 64) && l.inRange(1, 63) && p==1)
{
private static:
                  //word type         ror offsets
  static if(w==32){ alias T = uint ;  enum sh = [8, 11, 16, 31];  }
  static if(w==64){ alias T = ulong;  enum sh = [8, 19, 40, 63];  }

  enum t = w*4;         //tagSize in bits
  enum r = T.sizeof*12; //S[0..12] size in bytes

  enum instance = format!"NORX%d-%d-%d"(w, l, p);

  //some utils

  void fill(T)(T[] arr, T base=0){ foreach(i, ref a; arr) a = cast(T)(i+base); }
  string dump(in T[16] s){ return format!"%(%.8X %)"(s); }


  //low level functions

  void G(ref T a, ref T b, ref T c, ref T d){
    import core.bitop : ror;

    static T H(in T x, in T y){  return (x^y)^((x&y)<<1);  }

    a = H(a, b);  d = ror((d^a), sh[0]);  //aabdda
    c = H(c, d);  b = ror((b^c), sh[1]);  //ccdbbc
    a = H(a, b);  d = ror((d^a), sh[2]);  //aabdda
    c = H(c, d);  b = ror((b^c), sh[3]);  //ccdbbc
  }

  void col(ref T[16] S){
    static foreach(i; 0..4)
      G(S[0+i], S[4+i], S[8+i], S[12+i]);
  }

  void diag(ref T[16] S){
    G(S[0], S[5], S[10], S[15]);
    G(S[1], S[6], S[11], S[12]);
    G(S[2], S[7], S[ 8], S[13]);
    G(S[3], S[4], S[ 9], S[14]);
  }

  void F(int l, ref T[16] S){
    foreach(i; 0..l){
      col(S); diag(S);
    }
  }

  enum u = uCalc;  auto uCalc(){ T[16] S;  fill(S);  F(2, S);  return S; }

  static assert(u[15] == (w==32 ? 0xD7C49104 : 0x86026AE8536F1501), "norx%d F() test failed".format(w));

  // high level functions

  const(void)[] pad(size_t len)(const(void)[] arr){
    if(arr.length >= len) return arr;
    ubyte[] e; e.length = len-arr.length;
    e[0  ] |= 0x01;
    e[$-1] |= 0x80;
    return arr ~ e;
  }

  T[4] prepareKey(in void[] K){
    enum byteCnt = T[4].sizeof;

    const(void)[] arr = K; //work on this slice

    if(arr.length > byteCnt){ //longer than needed: set the last dword to the hast of the remaining part.
      uint hash = arr[byteCnt-4..$].xxh; //todo: ellenorizni ezt es az xxh-t is. Lehet, hogy le kene cserelni norx-ra.
      arr = arr[0..byteCnt-4] ~ cast(void[])[hash];
    }

    arr = pad!byteCnt(arr); //pad if smaller

    T[4] key;  key[] = (cast(T[])arr)[0..4];
    return key;
  }

  T[16] initialize(in T[4] k, in T[4] n){
    T[16] S = n ~ k ~ u[8..16];
    S[12..16] ^= [w, l, p, t].to!(T[])[];
    F(l, S);
    S[12..16] ^= k[];
    return S;
  }

  void absorb(ref T[16] S, const(void)[] X, in T v/*domain constant*/){
    for(; X.length; X = X[r..$]){
      X = pad!r(X);

      S[15] ^= v;
      F(l, S);
      S[0..12] ^= (cast(T[]) X[0..r])[];
    }
  }

  ubyte[] encrypt(ref T[16] S, const(void)[] M, in T v/*domain constant*/){
    void[] C; //ciphertext
    C.reserve(M.length);

    for(; M.length; M = M[r..$]){
      const blockLen = min(M.length, r);
      S[15] ^= v; F(l, S);

      if(blockLen == r){
        S[0..12] ^= (cast(T[]) M[0..r])[];
        C ~= (cast(void[]) S)[0..r];
      }else{
        M = pad!r(M);
        S[0..12] ^= (cast(T[]) M[0..r])[];
        C ~= (cast(void[]) S)[0..blockLen];
      }
    }

    return cast(ubyte[])C;
  }

  ubyte[] decrypt(ref T[16] S, const(void)[] C, in T v/*domain constant*/){
    enum r = T.sizeof*12;

    void[] M; //reconstructed message
    M.reserve(C.length);

    while(C.length){
      const blockLen = min(C.length, r);
      S[15] ^= v; F(l, S);

      if(blockLen == r){ //full block
        S[0..12] ^= (cast(T[])C[0..r])[];
        M ~= S[0..12];
        S[0..12] = (cast(T[])C[0..r])[];
      }else{
        auto MLast = (cast(ubyte[]) S[])[0..blockLen].dup;  //todo: ez qrvalassu
        MLast[] ^= (cast(ubyte[])C)[0..blockLen];
        M ~= MLast;
        S[0..12] ^= (cast(T[]) pad!r(MLast))[];
      }

      C = C[blockLen..$];
    }

    return cast(ubyte[])M;
  }

  ubyte[] finalize(ref T[16] S, in T[4] k, in T v/*domain constant*/){
    S[15] ^= v;
    F(l, S);
    S[12..16] ^= k[];
    F(l, S);
    S[12..16] ^= k[];
    return (cast(ubyte[]) S)[$-(t/8)..$].dup;  //kibaszott dup nagyon kell ide
  }

  auto testVector(){
    struct Res{
      ubyte[4*T.sizeof] K, N;
      ubyte[128] A, M, Z;
    }
    Res res;
    with(res){
      fill(K);
      fill(N, 0x20);
      fill(A);
      fill(M);
      fill(Z);
    }
    return res;
  }

  auto crypt(bool doTests=false, bool doDecrypt=false)(const(void)[] K, const(void)[] N, const(void)[] A, const(void)[] M, const(void)[] Z){

    static void test(int idx, string caption, T, string file=__FILE__, int line=__LINE__)(const T[] a){
      static if(doTests){
        string expected;
        static if(instance=="NORX32-4-1"){
          expected = [
            "7DD54975 C374FFC8 1DF66F83 08CEF7E9 CA5295E8 8E1E6324 538244DA 3091DC5D 5288E900 EDDAFB81 1A345AE0 933EC3AB BED76EB5 8B64D948 A59BD31B 6BBBD034",
            "2DFDA46B 956D99E2 DE62A45D 59A4AD56 F9A5411A 759C0658 45CF1EA3 A9515464 60CCA3C1 A29F076D FAA12E42 EA22ED90 7D10BA9D 407E2C5B 97DC4FA4 80401262",
            "9769850C 41240274 A264E03A B808815A 9285A6D3 8665C774 ED279CE2 9571FB11 F39624ED 3DCE8561 81879FF2 45B5E234 10D6694E AFF8A691 9991AECE BFFA4576",
            "BBAB2C4A 42BF34A5 3AD53DFA AF184F4D 66A33356 481AAE25 471E110F 9FBC7740 33A4CBDB 5CA77A41 ABCDF216 1A213FE2 353816EC 8EFF5ABE 3FB2298B E4A9EC82",
            "97537D63 63AC168C 6CEF0F5B EC0114E9 D6A022EC FF4395E0 4F29B8B5 B8CC8998 D92C5C49 74BA3CEF 964EEDD3 23DF1024 BCE454D5 89B75B6B EA597754 47CFFFCD",
            "6C E9 4C B5 48 B2 0F ED 7B 68 C6 AC 60 AC 4C B5 EB B1 F0 9A EC 5A 75 0E CF 50 EC 0E 64 93 8B F2 40 17 A4 FF 06 84 F8 08 A6 7C 19 6C 31 A0 AF 12 56 9B E5 F7 C5 6A D3 BC AC 88 DA 36 86 57 5F 93 43 96 8D A2 20 77 EE CC E7 D6 63 17 49 08 A3 F7 3C 9E 9A C1 49 B5 CE 6B E6 9C 9E 31 7C D7 E7 E8 0C 85 69 97 74 02 24 41 3A E0 64 A2 5A 81 08 B8 D3 A6 85 92 74 C7 65 86 E2 9C 27 ED 11 FB 71 95",
            "D5 54 E4 BC 6B 5B B7 89 54 77 59 EA CD FF CF 47"][idx];
        }else static if(instance=="NORX64-4-1"){
          expected = [
            "ED1C05E4E034B18B A98C191C6015FA6D 288C3313ACF5E185 94E37DCA8C2B520F 841D5FBE319581DE 6BA9AE4E997C10DF 9ACC31C63498AAB8 BC4F4AA085B8FAD9 24A958D377B4FBBF 8DDB5DC488A3A710 7F776980AAA321EF 4D4C321A44EE66D9 C6439632673FBDC2 950244CDFEAEA45E EB8B0AFF16BEDBE0 68A7A80B2838111F",
            "07D9A7A131D4D6E0 5B60B0B0847E0416 57F3CB734EC314B3 F9CFDC4B605A6CCC 5E3F25A15BF57819 3501EA9EDDF5CC6C 69BAAF08D99F96C2 CF86E9721020F64E 3352D33F5677CBC4 331C29A0674FEF14 CB74AFFFA9BD69D9 5810E32F833F0370 44C3442263959E68 522FC8BBFE971C48 4EC92E818EA35AD3 BB223CBC51462414",
            "A4461CDB6586E74B BDDF7652BF4F1AB0 DCF86684B8BFEB30 D870D0D016787A89 C5DC8F2CC92A2D60 404DE2D5457A5178 8A2475887B1ABF74 AD5BEFE2F99B111F D258C60C34FC528A 69C0DA88A6C5CD25 3328D007C5C35CC3 3744B8E898EC83DD 70AB4D51F1570C40 5E3331A6663C18EE BA01BA7CFDF2C4BF 36FA274968BF8B0A",
            "B1B64376441A2AB0 2F5BE2578863D5EC 66F953E878E37E6B EEE236C48DEDFFEE 6778F573276FDF5F E3C3E60EDC6DB52D B0AAEFFFF4764978 2A0F46F39ED63CF1 A9C34DCB7057873C 594CC2D6E926D398 D85F144A45107F10 EE584A7C1D80E6D3 7B763E9FCBB1F9D3 9A55D3CAC654F97A 9308DF76F6D7995E 6D9E59C21CC59E3B",
            "45D70450C188B282 44CB44A8ACC7D823 6CF99985A76DD706 F76D93B792F90C83 BCB8EC0B3370F727 011728D02D035E19 CC7972F3E89E595A A75510060F10F800 D3314C7CDF7C4C99 52A16E0D4BD61F3C 4EA70ACD1A1F1D3A B56927EF60BB58D4 7623A30533FAF2D1 3F3089C9D1613AE2 E4175BA55A93BDBF 8E4073C4334725E7",
            "C0 81 6E 50 8A E4 A0 50 0B 93 38 7B BB AB C2 41 AC 42 38 7E F5 E8 BF 0E C3 82 6C ED E1 66 A1 D5 CA A3 E8 D6 2C D6 41 B3 FA F2 AA 2A DD E3 E5 ED 0A 13 BD 8B 96 D5 F0 FB 7F E3 9C A7 80 95 31 75 E2 45 BC 3E 53 4B 80 0E 96 46 77 1F 13 EA 40 85 CB 3E 26 7F 10 6F 5F 17 A0 64 FF 23 4A 02 7C 64 4B E7 86 65 DB 1C 46 A4 B0 1A 4F BF 52 76 DF BD 30 EB BF B8 84 66 F8 DC 89 7A 78 16 D0 D0 70 D8",
            "D1 F2 FA 33 05 A3 23 76 E2 3A 61 D1 C9 89 30 3F BF BD 93 5A A5 5B 17 E4 E7 25 47 33 C4 73 40 8E"][idx];
        }else{
          WARN(instance ~ " is not covered by tests.");
          return;
        }
        auto actual = format("%(%."~(T.sizeof*2).text~"X %)", a);

        enforceDiff(expected, actual, format!"Test failed %s %s"(instance, caption), file, line);
      }
    }

    struct Res{
      ubyte[] data;
      ubyte[] tag;
      alias data this;
    }
    Res res;

    const k = prepareKey(K),
          n = prepareKey(N);
    auto S = initialize(k, n);   test!(0, "S after initialize")(S);
             absorb  (S, A, 1);  test!(1, "S after header"    )(S);

    static if(doDecrypt){
      res.data  = decrypt (S, M, 2);
    }else{
      res.data  = encrypt (S, M, 2);  test!(2, "S after message"   )(S);
    }

               absorb  (S, Z, 4);  test!(3, "S after trailer"   )(S);
    res.tag  = finalize(S, k, 8);  test!(4, "S after finalize"  )(S);

    if(doTests){
      test!(5, "cipherText")(res.data);
      test!(6, "tag"       )(res.tag);
    }

    return res;
  }

public static: // public declarations ////////////////////////////////////

  auto encrypt(in void[] key, in void[] nonce, in void[] header, in void[] message, in void[] trailer){ return crypt!(false, false)(key, nonce, header, message, trailer); } //todo: tag checking
  auto decrypt(in void[] key, in void[] nonce, in void[] header, in void[] crypted, in void[] trailer){ return crypt!(false, true )(key, nonce, header, crypted, trailer); } //todo: tag checking

  //shorthands without header and trailer
  auto encrypt(in void[] key, in void[] nonce, in void[] message){ return encrypt(key, nonce, [], message, []); }
  auto decrypt(in void[] key, in void[] nonce, in void[] crypted){ return decrypt(key, nonce, [], crypted, []); }

  bool test(){
    const tv = testVector;
    with(tv){
      //do the detailed tests
      crypt!(true, false)(K, N, A, M, Z);

      foreach(len; [48, 0, 128, 47, 49]){
        const X = M[0..len];
        auto enc = encrypt(K, N, X, X, X);
        const Y = enc.data;
        auto dec = decrypt(K, N, X, Y, X);

        auto expected = format("%(%.2X %)", X),
             actual   = format("%(%.2X %)", dec.data);
        enforceDiff(expected, actual, "Encrypt/Decrypt test failed. len=%d".format(len));
      }

    }

    //LOG("All tests \33\12passed\33\7.");
    return true;
  }

  shared static this(){
    test;
  }
}

void benchmark_norx(){
  const MB = 100;
  auto plainText = iota((1<<(20-2))*MB).array;
  print("generated %d MiB data".format((plainText.length*plainText[0].sizeof) >> 20));
  auto t0 = QPS;
  print("encoding");
  auto enc = norx!(64, 4, 1).encrypt("1234", "nonce", plainText);
  auto t1 = QPS;
  print("decoding");
  auto dec = norx!(64, 4, 1).decrypt("1234", "nonce", enc);
  auto t2 = QPS;
  print(plainText.xxh);
  auto t3 = QPS;
  print(plainText.crc32);
  auto t4 = QPS;
  print("comparing");
  enforce(cast(ubyte[])plainText == cast(ubyte[])dec);

  print("MB/s: enc:", MB/(t1-t0), "dec:", MB/(t2-t1), "xxh:", MB/(t3-t2), "crc32:", MB/(t4-t3));
}


////////////////////////////////////////////////////////////////////////////////
///  Path                                                                ///
////////////////////////////////////////////////////////////////////////////////

char pathDelimiter() {
  //static __gshared c = dirSeparator[0]; return c;  <- After all I'm Windows only...
  return '\\';
}

string includeTrailingPathDelimiter(string fn) { if(!fn.endsWith(pathDelimiter)) fn ~= pathDelimiter; return fn; }
string excludeTrailingPathDelimiter(string fn) { if(fn.endsWith(pathDelimiter)) fn = fn[0..$-1]; return fn; }

bool samePath(string a, string b){
  return sameText(a.excludeTrailingPathDelimiter,
                  b.excludeTrailingPathDelimiter);
}

struct Path{
  private static{

    bool dirExists(string dir){
      bool res;
      try{ res = isDir(dir); }catch(Throwable){}
      return res;
    }

  }
public:
  string fullPath;

  this(string path_){ dir = path_; }
  this(string path_, string name_) { this(combinePath(path_, name_)); }
  this(Path path_, string name_) { this(combinePath(path_.fullPath, name_)); }

  string toString() const { return "Path("~fullPath.quoted('`')~")"; }
  bool isNull() const{ return fullPath==""; }
  bool opCast() const{ return !isNull(); }

  bool exists() const { return dirExists(dir); }

  @property string dir() const { return excludeTrailingPathDelimiter(fullPath); }
  @property void dir(string dir_) { fullPath = dir_=="" ? "" : includeTrailingPathDelimiter(dir_); }

  auto isAbsolute()const{ return isAbsolutePath(fullPath); }

  Path normalized()             const { return Path(buildNormalizedPath(absolutePath(fullPath))); }
  Path normalized(string base)  const { return Path(buildNormalizedPath(absolutePath(fullPath, base))); }
  Path normalized(in Path base) const { return normalized(base.fullPath); }

  Path parent() const { string s = dir; while(s!="" && s[$-1]!='\\') s.length--; return Path(s); }

  bool make(bool mustSucceed=true)const{
    if(exists) return true;
    try{
      mkdirRecurse(dir);
    }catch(Throwable){
      enforce(!mustSucceed, format(`Can't make directory : "%s"`, dir)); //todo: common file errors
    }
    return exists;
  }

  bool remove(alias rmdirfunc=rmdir)(bool mustSucceed=true)const{
    if(!exists) return true;
    try{
      rmdirfunc(dir);
    }catch(Throwable){
      enforce(!mustSucceed, format(`Can't remove directory : "%s"`, dir)); //todo: common file errors
    }
    return !exists;
  }

  bool wipe(bool mustSucceed=true)const{
    if(dir.length==2 && dir.endsWith("\\")) throw new Exception(`Unable to wipeing a whole drive "`~dir~`"`);

    return remove!rmdirRecurse(mustSucceed);
  }

  private static void preparePattern(ref string pattern){
    //convert multiple filters to globMatch's format
    if(pattern.canFind(';'))
      pattern = pattern.replace(";", ",");

    if(pattern.canFind(',') && !pattern.startsWith('{'))
      pattern = '{'~pattern~'}';
  }

  File[] files(string pattern="*", bool recursive=false) const{
    preparePattern(pattern);
    return dirEntries(fullPath, pattern, recursive ? SpanMode.depth : SpanMode.shallow)
      .filter!isFile
      .map!(e => File(e.name)).array;
  }

  Path[] paths(string pattern="*", bool recursive=false) const{
    preparePattern(pattern);
    return dirEntries(fullPath, pattern, recursive ? SpanMode.depth : SpanMode.shallow)
      .filter!(e => !e.isFile)
      .map!(e => Path(e.name)).array;
  }

  Path opBinary(string op:"~")(string p2){
    return Path(this, p2);
  }
}

Path tempPath() {
  static __gshared string s;
  if(!s){
    wchar[512] buf;
    GetTempPathW(buf.length, buf.ptr);
    s = includeTrailingPathDelimiter(buf.toStr);
  }
  return Path(s);
}

Path programFilesPath32(){ static __gshared Path s; if(!s){ s = Path(includeTrailingPathDelimiter(environment.get("ProgramFiles(x86)", `c:\program Files(x86)\`))); } return s; }
Path programFilesPath64(){ static __gshared Path s; if(!s){ s = Path(includeTrailingPathDelimiter(environment.get("ProgramFiles"     , `c:\program Files\`     ))); } return s; }

Path programFilesPath() {
  version(Win32) return programFilesPath32;
  version(Win64) return programFilesPath64;
}

////////////////////////////////////////////////////////////////////////////////
///  File                                                                    ///
////////////////////////////////////////////////////////////////////////////////

private bool isAbsolutePath(string fn) { return std.path.isAbsolute(fn); }

private string combinePath(string a, string b){
  if(!a) return b;
  if(!b) return a;

  //note: in buildPath() "c:\a" + "\xyz" equals "c:\syz". This is bad.
  b = b.withoutStarting(`\`);

  return std.path.buildPath(a, b);
}

struct File{
private static{/////////////////////////////////////////////////////////////////
  bool fileExists(string fn)
  {
    if(fn.empty) return false;
    try{
      auto f = StdFile(fn, "rb");
      return true;
    }catch(Throwable){
      return false;
    }
  }

  ulong fileSize(string fn)
  {
    try{
      auto f = StdFile(fn, "rb");
      return f.size;
    }catch(Throwable){
      return 0;
    }
  }

  struct FileTimes{
    DateTime created, modified, accessed;
  }

  FileTimes fileTimes(string fn)
  {
    FileTimes res;

    StdFile f;
    try{
      f = StdFile(fn, "rb");
    }catch(Throwable){
      return res;
    }

    FILETIME cre, acc, wri;
    if(GetFileTime(f.windowsHandle, &cre, &acc, &wri)){
      SYSTEMTIME st;

      FileTimeToSystemTime(&cre, &st); res.created  = DateTime(st);
      FileTimeToSystemTime(&acc, &st); res.accessed = DateTime(st);
      FileTimeToSystemTime(&wri, &st); res.modified = DateTime(st);
    }

    return res;
  }

  string extractFilePath(string fn) {
    auto s = dirName(fn);
    if(s==".") return "";
          else return includeTrailingPathDelimiter(s);
  }
  string extractFileDir(string fn) { return excludeTrailingPathDelimiter(extractFilePath(fn)); }
  string extractFileName(string fn) { return baseName(fn); }
  string extractFileExt(string fn) { return extension(fn); }
  string changeFileExt(const string fn, const string ext) { return setExtension(fn, ext); }
}
public:
  this(string fullName_) { fullName = fullName_; }
  this(string path_, string name_) { fullName = combinePath(path_, name_); }
  this(Path path_, string name_) { fullName = combinePath(path_.fullPath, name_); }
  this(Path path_, File file_) { fullName = combinePath(path_.fullPath, file_.fullName); }

  string fullName;

  string toString()const{ return "File("~fullName.quoted('`')~")"; }
  bool isNull()    const{ return fullName==""; }
  bool opCast()    const{ return !isNull(); }

  auto exists()    const{ return fileExists     (fullName); }
  auto size()      const{ return fileSize       (fullName); }
  auto isAbsolute()const{ return isAbsolutePath (fullName); }

  File normalized()             const{ return File(buildNormalizedPath(absolutePath(fullName))); }
  File normalized(string base)  const{ return File(buildNormalizedPath(absolutePath(fullName, base))); }
  File normalized(in Path base) const{ return normalized(base.fullPath); }

  auto times()     const{ return fileTimes      (fullName); }
  auto modified()  const{ return times.modified; }
  auto accessed()  const{ return times.accessed; }
  auto created()   const{ return times.created ; }


  @property string dir()const           { return extractFileDir(fullName); }
  @property void dir(string newDir)     { fullName = combinePath(newDir, extractFileName(fullName)); }

  @property Path path()const          { return Path(extractFilePath(fullName)); }
  @property void path(Path newPath)   { fullName = combinePath(newPath.fullPath, extractFileName(fullName)); }
  @property void path(string newPath) { fullName = combinePath(newPath         , extractFileName(fullName)); }

  @property string name()const          { return extractFileName(fullName); }
  @property void name(string newName)   { fullName = combinePath(extractFilePath(fullName), newName); }

  @property string nameWithoutExt()const { return extractFileName(otherExt("").fullName); }

  @property string ext()const           { return extractFileExt(fullName); }
  @property void ext(string newExt)     { fullName = changeFileExt(fullName, newExt); }

  File otherExt(const string ext_) const { File a = this; a.ext = ext_; return a;  }

  bool extIs(in string[] exts...)const {
    string e0 = lc(ext);
    foreach(s; exts){
      string e = s;
      if(e!="" && e[0]!='.') e = '.'~e;
      if(lc(e)==e0) return true;
    }
    return false;
  }

  bool remove(bool mustSucceed = true) const{
    if(exists){
      try{
        std.file.remove(fullName);
      }catch(Throwable){
        enforce(!mustSucceed, format(`Can't delete file: "%s"`, fullName));
      }
    }
    return !exists;
  }

  /// Useful to remove files that are generated from std output. Those aren't closed immediatelly.
  void forcedRemove() const{
    foreach(k; 0..500){
      if(exists){ try{ remove; }catch(Exception e){ sleep(10); } }
      if(!exists) return;
    }
    ERR("Failed to forcedRemove file ", this);
  }

  ubyte[] forcedRead() const{
    foreach(k; 0..500){
      try{
        auto res = read(true);
        return res;
      }catch(Exception e){ sleep(10); }
    }
    ERR("Failed to forcedRead file ", this);
    assert(0);
  }

  ubyte[] read(bool mustExists = true, ulong offset = 0, size_t len = size_t.max)const{ //todo: void[] kellene ide talan, nem ubyte[] es akkor stringre is menne?
    ubyte[] data;

    if(!mustExists && !exists) return data;
    try{
      auto f = StdFile(fullName, "rb");
      scope(exit) f.close;

      if(offset) f.seek(offset);
      ulong avail = f.size-offset;
      ulong actualSiz = len;

      minimize(actualSiz, avail);
      if(actualSiz>0){
        data.length = cast(size_t)actualSiz;
        data = f.rawRead(data);
      }

    }catch(Throwable){
      enforce(!mustExists, format(`Can't read file: "%s"`, fullName)); //todo: egysegesiteni a file hibauzeneteket
    }

    if(logFileOps) LOG(fullName);
    return data;
  }

  string readStr(bool mustExists = true, ulong offset = 0, size_t len = size_t.max) const{
    auto s = cast(string)(read(mustExists, offset, len));
    return s;
  }

  string readText(bool mustExists = true, TextEncoding defaultEncoding = TextEncoding.UTF8, ulong offset = 0, size_t len = size_t.max) const{
    auto s = readStr(mustExists, offset, len);
    return textToUTF8(s, defaultEncoding); //own converter. Handles BOM
  }

  string[] readLines(bool mustExists = true, TextEncoding defaultEncoding = TextEncoding.UTF8, ulong offset = 0, size_t len = size_t.max) const{
    return readText(mustExists, defaultEncoding, offset, len).splitLines;
  }

  //utf32 versions
  dstring readText32(bool mustExists = true, TextEncoding defaultEncoding = TextEncoding.UTF8, ulong offset = 0, size_t len = size_t.max) const{
    auto s = readStr(mustExists, offset, len);
    return textToUTF32(s, defaultEncoding); //own converter. Handles BOM
  }

  dstring[] readLines32(bool mustExists = true, TextEncoding defaultEncoding = TextEncoding.UTF8, ulong offset = 0, size_t len = size_t.max) const{
    return readText32(mustExists, defaultEncoding, offset, len).splitLines;
  }

  void write(const void[] data, ulong offset = 0, Flag!"preserveTimes" preserveTimes = No.preserveTimes)const{ //todo: compression, automatic uncompression
    try{
      path.make;
      auto f = StdFile(fullName, offset ? "r+b" : "wb");
      scope(exit) f.close;

      FILETIME cre, acc, wri;
      bool getTimeSuccess;
      if(preserveTimes) getTimeSuccess = GetFileTime(f.windowsHandle, &cre, &acc, &wri)!=0;

      if(offset) f.seek(offset);
      f.rawWrite(data);
      if(logFileOps) LOG(fullName);

      if(preserveTimes && getTimeSuccess)
        enforce(SetFileTime(f.windowsHandle, null, &acc, &cre)!=0, "Error writing file times.");

    }catch(Throwable){
      enforce(false, format(`Can't write file: "%s"`, fullName));
    }
  }

  bool sameContents(const void[] data){
    return size==data.length && equal(cast(const ubyte[])data, read(false));
  }

  bool writeIfNeeded(const void[] data){
    const needToWrite = !sameContents(data);
    if(needToWrite) write(data);
    //if(!needToWrite) print("SKIPPING WRITING IDENTICAL FILE");
    return needToWrite;
  }

  void writeText(string s){
    immutable bom = "\uFEFF";
    write(s.startsWith(bom) ? s : bom~s);
  }

  void append(const void[] data)const{ write(data, size); } //todo: compression, automatic uncompression

  int opCmp(const File b) const{ return fullName>b.fullName ? 1 : fullName<b.fullName ? -1 : 0; }
  bool opEquals(const File b) const{ return sameText(fullName, b.fullName); }

  size_t toHash() const{
    return fullName.xxh;
  }
}

//helpers for saving and loading
void saveTo(T)(const T[] data, const File file)if( is(T == char))                               { file. writeStr(cast(string)data); }
void saveTo(T)(const T[] data, const File file)if(!is(T == char))                               { file. write(data); }
void saveTo(T)(const T data, const File file)if(!isDynamicArray!T)                              { file .write([data]); }

void saveTo(string data, const File file, Flag!"onlyIfChanged" FOnlyIfChanged = No.onlyIfChanged){ //todo: combine all saveTo functions into one funct.
  if(FOnlyIfChanged == Yes.onlyIfChanged){
    if(file.size == data.length && file.readStr == data) return;
  }
  file.write(data);
}

void saveTo(T)(const T[] data, const string fileName)                                           { data.saveTo(File(fileName)); }
void saveTo(T)(const T data, const string fileName)if(!isDynamicArray!T)                        { [data].saveTo(File(fileName)); }

void loadFrom(T)(ref T[]data, const File fileName, bool mustExists=true)if( is(T == char))          { data = fileName.readStr(mustExists); }
void loadFrom(T)(ref T[]data, const File fileName, bool mustExists=true)if(!is(T == char))          { data = cast(T[])fileName.read(mustExists); }
void loadFrom(T)(ref T data, const File fileName, bool mustExists=true)if(!isDynamicArray!T)        { data = (cast(T[])fileName.read(mustExists))[0]; }


File appFile() { static __gshared File s; if(s.isNull) s = File(thisExePath); return s; }
Path appPath() { static __gshared Path s; if(s.isNull) s = appFile.path; return s; }
Path currentPath() { return Path(std.file.getcwd); }
alias workPath = currentPath;

// FileEntry, listFiles, findFiles //////////////////////////////////

import core.sys.windows.windows : WIN32_FIND_DATAW, HANDLE, INVALID_HANDLE_VALUE, FindFirstFileW, FileTimeToSystemTime, FindNextFileW, FindClose,
  FILE_ATTRIBUTE_DIRECTORY, FILE_ATTRIBUTE_READONLY, FILE_ATTRIBUTE_ARCHIVE, FILE_ATTRIBUTE_SYSTEM, FILE_ATTRIBUTE_HIDDEN;

struct FileEntry{
  Path path;
  string name;

  FILETIME ftCreationTime, ftLastWriteTime, ftLastAccessTime;
  long size;
  uint dwFileAttributes;

  @property{
    string ext() const{ return File(name).ext; }
    bool isDirectory() const{ return (dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)!=0; }
    bool isReadOnly () const{ return (dwFileAttributes & FILE_ATTRIBUTE_READONLY )!=0; }
    bool isArchive  () const{ return (dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE  )!=0; }
    bool isSystem   () const{ return (dwFileAttributes & FILE_ATTRIBUTE_SYSTEM   )!=0; }
    bool isHidden   () const{ return (dwFileAttributes & FILE_ATTRIBUTE_HIDDEN   )!=0; }
  }

  this(in WIN32_FIND_DATAW data, in Path path){
    this.path                   = path;
    this.name                   = data.cFileName.toStr;
    this.ftCreationTime         = data.ftCreationTime;
    this.ftLastWriteTime        = data.ftLastWriteTime;
    this.ftLastAccessTime       = data.ftLastAccessTime;
    this.size                   = data.nFileSizeLow | (long(data.nFileSizeHigh)<<32);
    this.dwFileAttributes       = data.dwFileAttributes;

  }

  string toString() const{ return format!"%-80s %s%s%s%s%s %12d"(File(path, name).fullName, isDirectory?"D":".", isReadOnly?"R":".", isArchive?"A":".", isSystem?"S":".", isHidden?"H":".", size); }
}

///similar directory listing like the one in totalcommander
FileEntry[] listFiles(Path path, string mask="", string order="name", Flag!"onlyFiles" onlyFiles = No.onlyFiles, Flag!"recursive" recursive = No.recursive){ //this is similar to
  FileEntry[] files, paths, parent;

  if(mask=="*") mask = "";

  WIN32_FIND_DATAW data;
  HANDLE hFind = FindFirstFileW((path.dir~`\*`).toPWChar, &data);
  if(hFind != INVALID_HANDLE_VALUE){
    do{
      auto entry = FileEntry(data, path);
      if(entry.isDirectory){
        if(entry.name == ".") continue;
        if(entry.name == ".."){ parent ~= entry; continue; }
        paths ~= entry;
      }else{
        if(mask=="" || entry.name.isWild(mask)) files ~= entry;
      }
    }while(FindNextFileW(hFind, &data));
    FindClose(hFind);
  }

  auto pathIdx = new int[paths.length];
  paths.makeIndex!((a, b) => icmp(a.name, b.name)<0)(pathIdx);


  auto fileIdx = new int[files.length];

  auto ascending = 1;
  if(order.startsWith("-")){ order = order[1..$]; ascending = -1; }
  order = order.withoutStarting("+");

  static auto cmpChain(int c1, lazy int c2){ return c1 ? c1 : c2; }
  static auto cmpSize(long a, long b){ return a==b?0:a<b?1:-1; }
  static auto cmpTime(FILETIME a, FILETIME b){ return cmpSize(*cast(long*)&a, *cast(long*)&b); }

  switch(order.lc){
    case "name": files.makeIndex!((a, b) => ascending*icmp(a.name, b.name)<0)(fileIdx); break;
    case "ext": files.makeIndex!((a, b) => ascending*cmpChain(icmp(File(a.name).ext, File(b.name).ext), icmp(a.name, b.name))<0)(fileIdx); break;
    case "size": files.makeIndex!((a, b) => ascending*cmpSize(a.size,b.size)<0)(fileIdx); break;
    case "date": files.makeIndex!((a, b) => ascending*(*cast(long*)&a.ftLastWriteTime-*cast(long*)&b.ftLastWriteTime)>0)(fileIdx); break;
    default: raise("Invalid sort order: " ~ order.quoted);
  }

  return chain(parent, pathIdx.map!(i => paths[i]), fileIdx.map!(i => files[i])).array;
}

///this is a recursive search
FileEntry[] findFiles(Path path, string mask="", string order="name", int level=0){ //this is similar to
  FileEntry[] files, paths;

  if(mask=="*") mask = "";

  WIN32_FIND_DATAW data;
  HANDLE hFind = FindFirstFileW((path.dir~`\*`).toPWChar, &data);
  if(hFind != INVALID_HANDLE_VALUE){
    do{
      auto entry = FileEntry(data, path);
      if(entry.isDirectory){
        if(entry.name.among(".", "..")) continue;
        paths ~= entry;
      }else{
        if(mask=="" || entry.name.isWild(mask)) files ~= entry;
      }
    }while(FindNextFileW(hFind, &data));
    FindClose(hFind);
  }

  //recursion
  files ~= paths.map!(p => findFiles(Path(p.path, p.name), mask, order, level+1)).join;

  //only sort on root level
  if(level==0){
    PERF("makeIndex");
    auto fileIdx = new int[files.length];

    auto ascending = 1;
    if(order.startsWith("-")){ order = order[1..$]; ascending = -1; }
    order = order.withoutStarting("+");

    static auto cmpChain(int c1, lazy int c2){ return c1 ? c1 : c2; }
    static auto cmpSize(long a, long b){ return a==b?0:a<b?1:-1; }
    static auto cmpTime(FILETIME a, FILETIME b){ return cmpSize(*cast(long*)&a, *cast(long*)&b); }

    switch(order.lc){
      case "name": files.makeIndex!((a, b) => ascending*icmp(a.name, b.name)<0)(fileIdx); break;
      case "ext": files.makeIndex!((a, b) => ascending*cmpChain(icmp(File(a.name).ext, File(b.name).ext), cmpChain(icmp(a.path.fullPath, b.path.fullPath), icmp(a.name, b.name)))<0)(fileIdx); break;
      case "size": files.makeIndex!((a, b) => ascending*cmpSize(a.size,b.size)<0)(fileIdx); break;
      case "date": files.makeIndex!((a, b) => ascending*(*cast(long*)&a.ftLastWriteTime-*cast(long*)&b.ftLastWriteTime)>0)(fileIdx); break;
      default: raise("Invalid sort order: " ~ order.quoted);
    }
    PERF("buildArray");

    files = fileIdx.map!(i => files[i]).array;

    print(PERF.report);

    return files;
  }else{
    return files;
  }

}

// Stream IO -> het.stream /////////////////////////////////////////////////////////////////
T stRead(T)(ref ubyte[] st)
{
  auto siz = T.sizeof;
  auto res = (cast(T[])st[0..siz])[0];
  st = st[siz..$];
  return res;
}

void stRead(T)(ref ubyte[] st, ref T res){
  res = stRead!T(st);
}


T[] stReadArray(T)(ref ubyte[] st)
{
  auto len = stRead!uint(st);
  auto siz = len * T.sizeof;
  auto res = cast(T[])st[0..siz];
  st = st[siz..$];
  return res;
}

uint stReadSize(ref ubyte[] st){ //read compressed 32bit
  auto b = stRead!ubyte(st);
  if(b&0x80){
    uint s = b & 0x3f | (stRead!ubyte(st)<<8);
    if(b&0x40) return s |= (stRead!ushort(st)<<16);
    return s;
  }else return b;
}

void stWrite(T)(ref ubyte[] st, const T data)
{
  auto siz = T.sizeof;
  ubyte* dst = st.ptr+st.length;
  st.length += siz;
  memcpy(dst, &data, siz);
}

void stWriteSize(ref ubyte[] st, const uint s){ //compressed 32bit
  if(s<0x80) stWrite(st, cast(ubyte)s);
  if(s<0x4000) stWrite(st, cast(ushort)s | 0x8000);
  if(s<0x4000_0000) stWrite(st, cast(ushort)s | 0xC000_0000);
}

void stWrite(T)(ref ubyte[] st, const T[] data)
{
  stWrite(st, len);
  foreach(const a; data) stWrite(st, data);
}


//todo: DIDE GotoError must show 5 lines up and down around the error.


// loadCachedFile /////////////////////////////////////////////////////

auto loadCachedFile(alias fun)(File file)
if(__traits(isStaticFunction, fun))
{
  alias T = ReturnType!fun;

  static struct Rec{
    File file;
    DateTime modified;
    T payload; //todo: tesztelni, hogy a Shader-eket felszabaditja-e es mikor. Elvileg onalloan jol fog mukodni.
    string error;
  }

  static Rec[File] loaded;

  auto p = file in loaded,
       actModified = file.modified;

  //found but too old.
  if(p !is null && file.modified != p.modified){
    loaded.remove(file);
    p = null;
  }//p is valid

  if(p is null){
    //1. load
    string text;
    try{
      text = file.readStr;
    }catch{
      throw new Exception("Unable to load cached file: "~file.fullName);
    } //it will try again later

    //2. create
    T obj;  string error;
    try{
      obj = fun(text);
    }catch(Throwable t){
      error = simplifiedMsg(t);
    }

    loaded[file] = Rec(file, actModified, obj, error); //todo: fileRead and getDate should be system-wide-atomic
    p = &loaded[file];
  }//p is valid

  //return the latest object if can
  assert(p !is null);
  if(p.payload !is null) return p.payload;
                    else throw new Exception(p.error);
}


// Shared Memory /////////////////////////////////////////////////////

class SharedMem(SharedDataType, string sharedFileName, bool isServer) {
  HANDLE sharedFileHandle;
  SharedDataType* sharedData;

  void initialize() {
    if(isActive) return;

    import core.sys.windows.windows;
    sharedFileHandle = isServer ? CreateFileMappingW(INVALID_HANDLE_VALUE,          // use paging file
                                            null,                          // default security
                                            PAGE_READWRITE,                // read/write access
                                            0,                             // maximum object size (high)
                                            SharedDataType.sizeof.to!uint, // maximum object size (low)
                                            sharedFileName.toPWChar)       // name of mapping object

                                :  OpenFileMappingW(FILE_MAP_ALL_ACCESS,     // read/write access
                                            false,                   // do not inherit the name
                                            sharedFileName.toPWChar);  // name of mapping object

    sharedData = cast(SharedDataType*) MapViewOfFile(sharedFileHandle, // handle to map object
                 FILE_MAP_ALL_ACCESS,       // read/write permission
                 0,
                 0,
                 SharedDataType.sizeof);
    //ensure(data, "DebugLogClient: Can't open mapFile.");

    LOG(sharedData);
  }

public:
  alias sharedData this;
  bool isActive() { return sharedData !is null; }

  this(){ initialize; }
}

alias SharedMemServer(SharedDataType, string sharedFileName) = SharedMem!(SharedDataType, sharedFileName, true );
alias SharedMemClient(SharedDataType, string sharedFileName) = SharedMem!(SharedDataType, sharedFileName, false);


////////////////////////////////////////////////////////////////////////////////////
/// Ini/Registry                                                                 ///
////////////////////////////////////////////////////////////////////////////////////

struct ini{
private:
  static const useRegistry = true;
  static File iniFile()   { auto fn = appFile; fn.ext = ".ini"; return fn; }

  static string[string] map;

  static Key baseKey()          { return Registry.currentUser.getKey("Software"); }
  static string companyName()   { return "realhet"; }
  static string configName()    { return "Config:"~appFile.fullName; }

  static string loadRegStr()    {
    string s;
    if(useRegistry){
      try{
        s = baseKey.getKey(companyName).getValue(configName).value_SZ;
      }catch(Throwable){}
    }else{
      s = iniFile.readStr(false);
    }
    return s;
  }

  static void loadMap()         {
    map = strToMap(loadRegStr);
  }

  static void saveMap() {
    bool empty = map.length==0;
    if(empty && !loadRegStr) return;

    if(useRegistry){
      auto key = baseKey.createKey(companyName);
      if(empty){
        key.deleteValue(configName); key.flush;
        if(!key.valueCount) baseKey.deleteKey(companyName);
      }else{
        auto s = mapToStr(map);
        key.setValue(configName, s); key.flush;
      }
    }else{
      auto s = mapToStr(map);
      if(empty) iniFile.remove;
           else iniFile.write(s);
    }
  }
public:
  static void loadIni() { loadMap; }
  static void saveIni() { saveMap; }

  static void remove(string name)    { map.remove(name); }
  static void removeAll()            { map = null; }

  static void write(T)(string name, in T value) { map[name] = value.to!string; }

  static T read(T)(string name, in T def = T.init) {
    if(auto x = name in map) try{ return (*x).to!T; }catch(Throwable){}
    return def;
  }
}

/////////////////////////////////////////////////////////////////////////////////
/// Date/Time                                                                 ///
/////////////////////////////////////////////////////////////////////////////////

void sleep(int ms)
{
  Sleep(ms);
}

private{
  enum dateReference = 693594;
  enum secsInDay = 24*60*60;
  enum msecsInDay = secsInDay*1000;

  immutable monthDays = [[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31],
                         [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]];

  bool isLeapYear(int year){
    return year%4==0 && (year%100!=0 || year%400==0);
  }

  double encodeTime(int hour, int min, int sec, double ms){
    return (((ms/1000+sec)/60+min)/60+hour)/24;
  }

  double encodeDate(int year, int month, int day) //returns NaN if invalid
  {
    auto dayTable = monthDays[isLeapYear(year)][];
    if(inRange(year,  1, 9999) && inRange(month, 1, 12) && inRange(day, 1, dayTable[month-1])){
      foreach(i; 0..month-1) day += dayTable[i];
      int i = year-1;
      return i*365 + i/4 - i/100 + i/400 + day - dateReference;
    }else{
      return double.nan;
    }
  }

  SYSTEMTIME decodeDate(double dateTime)
  {
    enum D1 = 365,
         D4 = D1 * 4 + 1,
         D100 = D4 * 25 - 1,
         D400 = D100 * 4 + 1;

    SYSTEMTIME result;
    if(isnan(dateTime)) return result;
    int D, I, T = ifloor(dateTime)+dateReference;
    if(T<=0) return result;

    result.wDayOfWeek = cast(ushort)(T%7 + 1);
    T--;
    int Y = 1;
    while(T>=D400){
      T -= D400;
      Y += 400;
    }
    divMod(T, D100, I, D);
    if(I==4){
      I--;
      D += D100;
    }
    Y += I*100;
    divMod(D, D4, I, D);
    Y += I*4;
    divMod(D, D1, I, D);
    if(I==4){
      I--;
      D += D1;
    }
    Y += I;

    auto dayTable = monthDays[isLeapYear(Y)][];
    int M = 0;
    while(1){
      I = dayTable[M];
      if(D<I) break;
      D -= I;
      M++;
    }
    result.wYear  = cast(ushort)Y;
    result.wMonth = cast(ushort)(M+1);
    result.wDay   = cast(ushort)(D+1);
    return result;
  }

  SYSTEMTIME decodeTime(double dateTime)
  {
    SYSTEMTIME result;
    if(isnan(dateTime))return result;
    int M, I = iround(fract(dateTime)*msecsInDay);
    with(result){
      divMod(I, 1000, I, M); wMilliseconds = cast(ushort)M;
      divMod(I,   60, I, M); wSecond       = cast(ushort)M;
      divMod(I,   60, I, M); wMinute       = cast(ushort)M;
                             wHour         = cast(ushort)I;
    }
    return result;
  }

  SYSTEMTIME decodeDateTime(double dateTime)
  {
    auto d = decodeDate(dateTime),
         t = decodeTime(dateTime);
    d.wMilliseconds = t.wMilliseconds;
    d.wSecond       = t.wSecond      ;
    d.wMinute       = t.wMinute      ;
    d.wHour         = t.wHour        ;
    return d;
  }

  int dblCmp(const double a, const double b){ return a>b ? 1 : a<b ? -1 : 0; }

  int year2k(int y){
    if(y< 50) y += 2000;
    if(y<100) y += 1900;
    return y;
  }
}

struct Date{
  private int raw;
  this(int year, int month, int day){
    double a = encodeDate(year, month, day);
    if(isnan(a)) raw = 0;
            else raw = cast(int)a;
  }
  this(const SYSTEMTIME st){
    with(st) this = Date(wYear, wMonth, wDay);
  }
  this(string str){
    int y,m,d;
    enforce(3==str.formattedRead!"%d.%d.%d"(y, m, d), "Invalid date format. -> [yy]yy.mm.dd");
    this(year2k(y), m, d);
  }
  static Date current() {
    SYSTEMTIME st;  GetLocalTime(&st);
    return Date(st);
  }

  @property int year ()const { auto st = decodeDate(raw); return st.wYear ; }
  @property int month()const { auto st = decodeDate(raw); return st.wMonth; }
  @property int day  ()const { auto st = decodeDate(raw); return st.wDay  ; }

  @property void year (ushort x) { auto st = decodeDate(raw); st.wYear  = x; this = Date(st); }
  @property void month(ushort x) { auto st = decodeDate(raw); st.wMonth = x; this = Date(st); }
  @property void day  (ushort x) { auto st = decodeDate(raw); st.wDay   = x; this = Date(st); }

  string toString()const {
    if(!raw) return "[NULL Date]";
    auto st = decodeDate(raw);
    with(st) return format("%.4d.%.2d.%.2d", wYear, wMonth, wDay);
  }

  int opCmp(const Date d)      const { return dblCmp(raw, d.raw); }
  int opCmp(const DateTime dt) const { return dblCmp(raw, dt.raw); }

  //todo: make more operator overloads for date/time/dateTime
  int opBinary(string op)(Date b) if(op=="-") { return raw - b.raw; }
}

struct Time{
  private double raw;
  this(int hour, int min, int sec=0, double ms=0){
    raw = encodeTime(hour, min, sec, ms);
  }
  this(const SYSTEMTIME st){
    with(st) this = Time(wHour, wMinute, wSecond, wMilliseconds);
  }
  static Time current(){
    SYSTEMTIME st;  GetLocalTime(&st);
    return Time(st);
  }
  this(string str){
    int h,m; double s=0;
    try{
      const len = str.split(':').length;
           if(len==3) str.formattedRead!"%s:%s:%s"(h, m, s);
      else if(len==2) str.formattedRead!"%s:%s"   (h, m   );
      else raise("");
    }catch(Throwable){ raise(`Invalid time format: "` ~ str ~ `"`); }
    this(h, m, s.ifloor, s.fract*1000);
  }

  @property int hour()const { auto st = decodeTime(raw); return st.wHour        ; }
  @property int min ()const { auto st = decodeTime(raw); return st.wMinute      ; }
  @property int sec ()const { auto st = decodeTime(raw); return st.wSecond      ; }
  @property int ms  ()const { auto st = decodeTime(raw); return st.wMilliseconds; }

  @property void hour(ushort x) { auto st = decodeTime(raw); st.wHour         = x; this = Time(st); }
  @property void min (ushort x) { auto st = decodeTime(raw); st.wMinute       = x; this = Time(st); }
  @property void sec (ushort x) { auto st = decodeTime(raw); st.wSecond       = x; this = Time(st); }
  @property void ms  (ushort x) { auto st = decodeTime(raw); st.wMilliseconds = x; this = Time(st); }

  string toString()const {
    with(decodeTime(raw)) return format!"%.2d:%.2d:%.2d.%.3d"(wHour, wMinute, wSecond, wMilliseconds);
  }

  int opCmp(const Time t) const { return dblCmp(raw, t.raw); }
}

struct DateTime{
  /+private+/ double raw;

  this(const SYSTEMTIME st){
    with(st) raw = encodeDate(wYear, wMonth, wDay) + encodeTime(wHour, wMinute, wSecond, wMilliseconds);
  }
  this(int year, int month, int day, int hour=0, int minute=0, int second=0, int milliseconds=0){
    raw = encodeDate(year, month, day) + encodeTime(hour, minute, second, milliseconds);
  }
  this(const Date date, const Time time){
    raw = date.raw+time.raw;
  }
  this(string str){
    if(str.canFind(' ')){
      auto parts = str.split(' '); //dateTime
      this(Date(parts[0]), Time(parts[1]));
    }else{
      //todo: check for digits here, not any chars!
      if(str.isWild("????????-??????-???")){ //timestamp 4 digit year
        this(       str[0..4].to!int,  str[4..6].to!int, str[6..8].to!int, str[9..11].to!int, str[11..13].to!int, str[13..15].to!int, str[16..19].to!int);
      }else if(str.isWild("??????-??????-???")){ //timestamp 2 digit year
        this(year2k(str[0..2].to!int), str[2..4].to!int, str[4..6].to!int, str[7.. 9].to!int, str[ 9..11].to!int, str[11..13].to!int, str[14..17].to!int);
      }else{
        this(Date(str), Time(0, 0)); //Date only
      }
    }
  }

  this(double val){ raw = val; }
  void opAssign(T)(T val) if(isNumeric!T) { raw = val; }

  static DateTime current(){
    SYSTEMTIME st;  GetLocalTime(&st);
    return DateTime(st);
  }

  @property int year ()const { auto st = decodeDate(raw); return st.wYear        ; }
  @property int month()const { auto st = decodeDate(raw); return st.wMonth       ; }
  @property int day  ()const { auto st = decodeDate(raw); return st.wDay         ; }
  @property int hour ()const { auto st = decodeTime(raw); return st.wHour        ; }
  @property int min  ()const { auto st = decodeTime(raw); return st.wMinute      ; }
  @property int sec  ()const { auto st = decodeTime(raw); return st.wSecond      ; }
  @property int ms   ()const { auto st = decodeTime(raw); return st.wMilliseconds; }

  @property void year (ushort x) { auto st = decodeDateTime(raw); st.wYear         = x; this = DateTime(st); }
  @property void month(ushort x) { auto st = decodeDateTime(raw); st.wMonth        = x; this = DateTime(st); }
  @property void day  (ushort x) { auto st = decodeDateTime(raw); st.wDay          = x; this = DateTime(st); }
  @property void hour (ushort x) { auto st = decodeDateTime(raw); st.wHour         = x; this = DateTime(st); }
  @property void min  (ushort x) { auto st = decodeDateTime(raw); st.wMinute       = x; this = DateTime(st); }
  @property void sec  (ushort x) { auto st = decodeDateTime(raw); st.wSecond       = x; this = DateTime(st); }
  @property void ms   (ushort x) { auto st = decodeDateTime(raw); st.wMilliseconds = x; this = DateTime(st); }

  @property bool isNull() const{ return isnan(raw) || raw==0; }

  string toString()const {
    if(isNull) return "[NULL DateTime]";
    Date d; d.raw = ifloor(raw);
    Time t; t.raw = fract(raw);
    return d.toString ~ ' ' ~ t.toString;
  }

  string timeStamp()const {
    if(isNull) return "null";
    //4 digit year is better. return format("%.2d%.2d%.2d-%.2d%.2d%.2d-%.3d", year%100, month, day, hour, min, sec, ms);
    return format("%.4d%.2d%.2d-%.2d%.2d%.2d-%.3d", year, month, day, hour, min, sec, ms);
  }

  int opCmp(const DateTime dt) const { return dblCmp(raw, dt.raw); }
  int opCmp(const Date     d ) const { return dblCmp(raw, d .raw); }
}

Time     time () { return Time    .current; } //0 = midnight  1 = 24hours
Date     today() { return Date    .current; } //same system as in Delphi
DateTime now  () { return DateTime.current; }


double QPS() //it's in seconds and synchronized with now() only at the start
{
  long cntr;
  QueryPerformanceCounter(&cntr);
  static __gshared double timeBase;
  static __gshared long   cntrBase;
  static __gshared double invFreq;
  if(!cntrBase){
    timeBase = time.raw*secsInDay;
    cntrBase = cntr;

    //query the freq only once
    long freq;
    QueryPerformanceFrequency(&freq);
    invFreq = 1.0/cast(double)freq;
  }
  return cast(double)(cntr-cntrBase)*invFreq + timeBase; //cntr has to be 'normalized' before multiplication to preserve precision
}

float QPS_local(){ //todo: mi a faszom kurvaannya ez is... 0-tol indulo QPS bazzz
  __gshared static double firstQPS = 0;
  if(!firstQPS) firstQPS = QPS;
  return QPS-firstQPS;
}

struct DeltaTimer {
  double tLast = 0;
public:
  float total = 0;
  float delta = 0; //the time from the last update

  void reset() //resets the total elapsed time
  {
    total = 0;
    tLast = QPS;
  }

  float update() {  //returns time since last update
    double tAct = QPS;
    if(tLast==0) tLast = tAct;
    delta = tAct-tLast;
    total += delta;
    tLast = tAct; //restart
    return delta;
  }

  bool update_periodic(float secs, bool enableOverflow) //enableOF: false for user-interface, true for physics simulations
  {
    update();
    bool res = total>=secs;
    if(res){
      total -= secs;
      if(!enableOverflow){
        if(total>=secs) total = 0;
      }
    }
    return res;
  }
};

synchronized class Perf {
  private{
    float[string] table;
    string actName;
    float T0;
  }

  void reset(){
    table = null;
    actName = "";
  }

  void addTime(string name, float time){
    if(name !in table) table[name] = 0;
    table[name] = table[name]+time;
  }

  string report(){
    if(actName!="") end;
    //pragma(msg, typeof(table));
    auto r = (cast(float[string])table).byKeyValue.map!(kv => "%-30s:%9.3f ms\n".format(kv.key, kv.value*1e3)).join;
           //^^^^^^^^^^^^^^^^^^^^ ez egy uj ldc 2020-as buzisag miatt kell, nem megy sharedre....
    reset;
    return r;
  }

  void opCall(string name, void delegate() dg = null){
    float T = QPS;
    if(actName!=""){ //flush
      addTime(actName, T-T0);
      actName = "";
    }
    if(name!=""){
      T0 = T;
      actName = name;
    }

    //call with delegate
    if(dg !is null){
      dg();
      end;
    }
  }

  void end(){
    opCall("");
  }
}

shared PERF = new shared Perf;

//TODO: strToDateTime, creators

struct Sequencer(T){ //Sequencer /////////////////////////////
  T[float] events;

  void opIndexAssign(in T what, float t){ events[t] = what; }
  T opIndex(float t) const{ auto a = t in events; return a ? *a : T.init; }

  void scale(float mult){
    T[float] e;
    foreach(i; events.byKeyValue) e[i.key*mult] = i.value;
    events = e;
  }

  private auto getEvents(float tLast, float tAct){
    return events.keys.filter!(k => tLast<k && k<=tAct)
                      .map!(k => events[k]).array;  //todo: this is slow
  }

  private bool anyEventsAfter(float tMin){
    return events.keys.filter!(k => tMin<k).any; //todo: this is also slow
  }

  auto run(void delegate() onIdle = null){

    static struct SequencerRunner(T){  ////todo: opApply a range helyett!
      Sequencer!T seq;
      void delegate() onIdle = null;
      double t0;
      float tLast = -1e30;

      private T[] actEvents;
      private bool eof;

      private void fetch(){
        if(eof || actEvents.length) return;

        do{
          auto tAct = QPS-t0;
          actEvents = seq.getEvents(tLast, tAct);
          tLast = tAct;

          if(actEvents.empty){ //wait more or break on EOS
            if(!seq.anyEventsAfter(tLast)){
              eof = true;
              break;
            }

            if(onIdle !is null) onIdle();
                           else sleep(1);
          }
        }while(actEvents.empty);
      }


      bool empty(){
        fetch;
        return eof && actEvents.empty;
      }

      T front(){
        fetch;
        return actEvents.empty ? T.init : actEvents[0];
      }

      void popFront(){
        fetch;
        if(!actEvents.empty)
          actEvents.popFirst;
      }
    }

    return SequencerRunner!T(this, onIdle, QPS);
  }
}


///////////////////////////////////////////////////////////////////////////
/// SysInfo                                                             ///
///////////////////////////////////////////////////////////////////////////

string computerName(){
  wchar[256] a = void;
  uint len = a.length;
  if(GetComputerNameW(a.ptr, &len)) return toStr(a.ptr);
                                    return "";
}

string targetFeatures(){
  string res = format("Target CPU: %s", __traits(targetCPU));
  static foreach(f; ["sse", "sse2", "sse3", "ssse3", /*"sse4",*/ "sse4.1", "sse4.2"])
    static if(__traits(targetHasFeature, f)) res ~= " "~f;
  return res;
}

import core.sys.windows.windef;

extern(C){
  uint GetCurrentProcessorNumber();
  bool SetProcessAffinityMask(HANDLE process, DWORD_PTR mask);
}

public import std.parallelism: GetNumberOfCores = totalCPUs;

private auto GetCPULoadPercent_internal(){
  // get tick counters
  ulong idle, kernel, user;
  auto ft(ref ulong a){ return cast(FILETIME*)(&a); }
  if(!GetSystemTimes(ft(idle), ft(kernel), ft(user))) return float.nan;

  // calculate  1 - (delta(Idle) / delta(kernel+user))
  __gshared static ulong prevTotal, prevIdle;
  auto total = kernel+user;
  auto res = 1 - float(idle-prevIdle) / (total-prevTotal); //can divide by zero when called too frequently
  prevTotal = total;
  prevIdle  = idle ;

  return res*100;
}

auto GetCPULoadPercent(){
  __gshared static double lastTime = 0;
  __gshared static float lastPercent = 0;

  const interval = 0.33f; //seconds

  auto actTime = QPS;
  if(actTime-lastTime > interval){
    lastTime = actTime;
    auto a = GetCPULoadPercent_internal;
    if(!isnan(a)) lastPercent = a;
  }

  return lastPercent;
}


auto GetMemUsagePercent(){
  MEMORYSTATUSEX ms; ms.dwLength = ms.sizeof; GlobalMemoryStatusEx(&ms);
  with(ms) return ((1-(float(ullAvailPhys)/ullTotalPhys))*100).percent;
}

auto GetMemAvailMB(){
  MEMORYSTATUSEX ms; ms.dwLength = ms.sizeof; GlobalMemoryStatusEx(&ms);
  return ms.ullAvailPhys>>20;
}


///////////////////////////////////////////////////////////////////////////
/// RTTI                                                                ///
///////////////////////////////////////////////////////////////////////////


struct StructInfo{

  struct FieldInfo{
    string uda, type, name, default_;
    size_t ofs, size;

    string toString()const {
      return (uda.empty ? `` : `@(`~uda~`) `) ~ "%s %s = %s; // ofs:%d size:%d".format(type, name, default_, ofs, size);
    }

    string getoptLine(string ownerName)const { //returns a line used by std.getopt()
      //example: "w|WFPerCU"     , `Number of WaveFronts on each Compute Units. Default: `~defOptions.WFPerCU.text, &WFPerCU  ,

      //split at param = descr
      string param, descr;
      if(!split2(uda, "=", param, descr)){
        descr = param;
        param = "";
      }

      //split at shortParam | longParam
      string shortParam, longParam;
      if(!split2(param, "|", shortParam, longParam)){
        if(shortParam.length!=1){
          longParam = shortParam;
          shortParam = "";
        }
      }

      //default short and long param
      if(shortParam=="") shortParam = name[0..1].lc;
      if(longParam=="") longParam = name;

      descr = descr.replace("$DEFAULT$", default_);

      //format the final string that can be used in getopt()
      return `"%s|%s", "%s", &%s.%s`.format(shortParam, longParam, descr.replace(`"`, `\"`), ownerName, name);
    }
  }

  string name;
  size_t size;
  FieldInfo[] fields;

  string toString()const {
    return "struct "~name~" {"~
      fields.map!(f => "\r\n  "~f.text).join
    ~"\n\r} // size:%s \n\r".format(size);
  }

  string[] getoptLines(string ownerName)const {
    return fields.map!(f => f.getoptLine(ownerName)).array;
  }
}

auto getStructInfo(T)()
if(isAggregateType!T)
{
  StructInfo si;
  si.name = T.stringof;
  si.size = T.sizeof;

  T defStruct;

  import std.traits;
  foreach(name; FieldNameTuple!T){
    //get some rtti
    StructInfo.FieldInfo fi;
    fi.name = name;
    mixin(q{
      fi.default_ = defStruct.*.text;
      fi.type = typeof(T.*).stringof;
      fi.uda = __traits(getAttributes, T.*).text;
      fi.ofs = T.*.offsetof;
      fi.size = typeof(T.*).sizeof;
    }.replace("*", name));
    si.fields ~= fi;
  }

  return si;
}

auto getStructInfo(T)(const T t)
if(isAggregateType!T)
{
  return getStructInfo!T;
}


//todo: list members of a module recursively. Adam Ruppe book
/*
pragma(msg, __traits(allMembers, thisModule));


struct S{}
enum E {asdf};
class C{}

template symbols(alias mod){
  alias symbols = staticMap!(__traits(getMember, mod, T), __traits(allMembers, mod));
}

void listModuiles(){
    static foreach(s; symbols!thisModule){
       pragma(msg, fullyQualifiedName!s);
    }

    alias notmods = Filter!(templateNot!notmodule, symbols!thismodule);


}
*/

///////////////////////////////////////////////////////////////////////////
/// UDAs                                                                ///
///////////////////////////////////////////////////////////////////////////

struct UDA{}

@UDA{
  // het.stream
  struct STORED{}
  struct HEX{}
  struct BASE64{}

  //het.opengl
  struct UNIFORM{ string name=""; } //marks a variable as gl.Shader attribute

  // het.ui
  struct CAPTION{ string text; }
  struct HINT{ string text; }
  struct UNIT{ string text; }
  struct RANGE{ float low, high; bool valid()const{ return !low.isnan && !high.isnan; } }
  struct INDENT{ }
  struct HIDDEN{ }
}

///////////////////////////////////////////////////////////////////////////
/// Executing / System                                                  ///
///////////////////////////////////////////////////////////////////////////

auto loadLibrary(string fn, bool mustLoad = true){
  auto h = Runtime.loadLibrary(fn);
  if(mustLoad) enforce(h, "("~fn~") "~getLastErrorStr);
  return h;
}

auto loadLibrary(File fn, bool mustLoad = true){
  return loadLibrary(fn.fullName, mustLoad);
}

void getProcAddress(T)(HMODULE hModule, const string name, ref T func, bool mustSucceed = true)
{
  func = cast(T)GetProcAddress(hModule, toStringz(name));
  if(mustSucceed) enforce(func, "getProcAddress() fail: "~name);
}

string genLoadLibraryFuncts(T, alias hMod = "hModule", alias prefix=T.stringof ~ "_")(){
  string res;
  void append(string s){ res ~= s ~ "\r\n"; }

  import std.traits;
  static foreach(f; __traits(allMembers, T))with(T){
    mixin(q{
      static if(typeof($).stringof.startsWith("extern"))
        append(hMod~`.getProcAddress("`~prefix~`" ~ "$".withoutEnding('_'), $);`);
    }.replace("$", f));
  }

  return res;
}

int spawnProcessMulti(const string[][] cmdLines, const string[string] env, out string[] sOutput, void delegate(int i) onProgress = null){
  //it was developed for running multiple compiler instances.
  import std.process;

  //create log files
  StdFile[] logFiles;
  foreach(i; 0..cmdLines.length){
    auto fn = File(tempPath, "spawnProcessMulti.$log"~to!string(i));
    logFiles ~= StdFile(fn.fullName, "w");
  }

  //create pool of commands
  Pid[] pool;
  foreach(i, cmd; cmdLines){
    pool ~= spawnProcess(cmd, stdin, logFiles[i], logFiles[i], env,
                         Config.retainStdout | Config.retainStderr | Config.suppressConsole);
  }

  //execute
  bool[] running;  //todo:bugzik az stdOut fileDelete itt, emiatt nem megy az, hogy a leghamarabb keszen levot ki lehessen jelezni. fuck this shit!
  running.length = pool.length;
  running[] = true;

  int res = 0;
  do{
    sleep(10);
    foreach(i; 0..pool.length){
      if(running[i]){
        auto w = tryWait(pool[i]);
        if(w.terminated){
          running[i] = false;
          if(w.status != 0){
            res = w.status;
            running[] = false;
          }
          if(onProgress !is null) onProgress(cast(int)i);
        }
      }
    }
  }while(running.any);

  /*foreach(i, p; pool){
    int r = wait(p);
    if(r) res = r;
    if(onProgress !is null) onProgress(i);
  }*/

  //make sure every process is closed (when one of them yielded an error)
  foreach(p; pool) { try{ kill(p);}catch(Exception e){} }

  //read/clear logfiles
  foreach(i, ref f; logFiles){
    File fn = File(f.name);
    f.close;
    sOutput ~= fn.readStr;

    //fucking lame because tryWait doesn't wait the file to be closed;
    foreach(k; 0..100){
      if(fn.exists){ try{ fn.remove; }catch(Exception e){ sleep(10); } }
      if(!fn.exists) break;
    }
  }
  logFiles.clear;

  return res;
}


alias const(GUID)* REFIID, PGUID;

template uuid(T, string g) {
  const uuid = "const IID IID_"~T.stringof~"={ 0x" ~ g[0..8] ~ ",0x" ~ g[9..13] ~ ",0x" ~ g[14..18] ~ ",[0x" ~ g[19..21] ~ ",0x" ~ g[21..23] ~ ",0x" ~ g[24..26] ~ ",0x" ~ g[26..28] ~ ",0x" ~ g[28..30] ~ ",0x" ~ g[30..32] ~ ",0x" ~ g[32..34] ~ ",0x" ~ g[34..36] ~ "]};"~
               "template uuidof(T:"~T.stringof~"){ const uuidof = IID_"~T.stringof~";}";
}


//////////////////////////////////
/// Global initialize/finalize ///
//////////////////////////////////

// for main thread only, called from application class ////////////////////////////

private void globalInitialize(){ //note: ezek a runConsole-bol vagy a winmainbol hivodnak es csak egyszer.
                                 //todo: a unittest alatt nem indul ez el.
  //todo: functional tests: nem ide kene
  //functional tests

  installExceptionFilter;

  enforce(xxh("hello")==0xfb0077f9);
  enforce(xxh("Nobody inspects the spammish repetition", 123456) == 0xc2845cee);
  enforce(crc32("Hello")==0xf7d18982);
  enforce(crc32("Nobody inspects the spammish repetition") == 0xAD4270ED);

  { RNG rng; rng.seed = 0; enforce(iota(30).map!(i => rng.random(100).text).join(' ') == "0 3 86 20 27 67 31 16 37 42 8 47 7 84 5 29 91 36 77 32 69 84 71 30 16 32 46 24 82 27"); }

  enforce(maskLowBits(0)==0);
  enforce(maskLowBits(1)==1);
  enforce(maskLowBits(2)==3);
  enforce(maskLowBits(3)==3);
  enforce(maskLowBits(4)==7);

  enforce(countHighZeroBits(0)==32);
  enforce(countHighZeroBits(1)==31);
  enforce(countHighZeroBits(2)==30);
  enforce(countHighZeroBits(0x7FFF0000)==1);
  enforce(countHighZeroBits(0xFFFF0000)==0);

  UpdateInterval()._testRepeater;

  enforce([8,9,10,11,12,13].map!(a => alignUp(a, 4)).equal([8,12,12,12,12,16]));

  //startup
  CoInitialize(null);
  ini.loadIni;

  console.setUTF8;
}

private void globalFinalize(){ //note: ezek a runConsole-bol vagy a winmainbol hivodnak es csak egyszer.
  //cleanup
  ini.saveIni;
  CoUninitialize;
}

// static this for each thread ////////////////////////////

static this(){ //for all threads <- bullshit!!! It's not shared!!!
  randomize; //randomices for every thread using QPC and thisThreadID
  init__iob_func;
}

// static this for process ////////////////////////////

shared float QPS0;

shared static this(){
  QPS0 = QPS;
}
