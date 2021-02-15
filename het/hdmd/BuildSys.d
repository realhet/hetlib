module buildsys;

//todo: editor: goto line
//TODO: a todokat, meg optkat meg warningokat, ne jelolje mar pirossal az editorban a filenevek tabjainal.
//TODO: editor find in project files.
//TODO: editor clear errorline when compiling
//TODO: -g flag: symbolic debug info
//TODO: invalid //@ direktivaknal error
//TODO: a dll kilepeskor takaritsa el az obj fileokat

import het.utils, het.parser, std.file, std.digest.sha, std.regex, std.path, std.process;

//////////////////////////////////////////////////////////////////////////////
//  Builder help text                                                       //
//////////////////////////////////////////////////////////////////////////////

immutable
  versionStr = "1.02",
  helpStr =  //todo: ehhez edditort csinalni
  "\33\16HDMD\33\7 "~versionStr~" - An automatic build tool for the \33\17DMD\33\7 and \33\17LDC\33\7 compilers.
by \33\xC0re\33\xF0al\33\xA0het\33\7 2016-2021

\33\17Usage:\33\7    hdmd.exe <mainSourceFile.d> [options]

\33\17Options:\33\7
$$$OPTS$$$

\33\17Build macros:\33\7
  These special comments are embedded in the source files to control various
  options in HDMD. No other external/redundant files needed, every information
  needed for a build is stored inside your precious sources files.
  Double quotes are supported for parameters containing spaces.

\33\17//@MACRO_COMMAND [param1 [param2 [paramN...]]]\33\7
  Every build macro starts with the //@ symbols and must placed at the
  beginning of a line. You can easily disable a macro by putting a / or a
  space in front of it.

\33\17//@EXE [name]\33\7
  Specifies that this module must be compiled to an exe file.
  The name is optional and must not containing the file extension.

\33\17//@DLL [name]\33\7
  Same as the above but for DLL and LIB output. A .def file is automatically
  generated, but you can also add custom DEF lines to it..

\33\17//@DEF <line>\33\7
  Creates a .def file and puts the line into it. The linker will use it later.

\33\17//@RES <fileName> [resourceName]\33\7
  Inserts a file into the project's .res file. If the resourceName is omitted,
  then it will use the fileName without the path. In the program these files
  can be accessed by this way -> res:\\resource1.dat.

\33\17//@RES <searchPath> [prefix]\33\7
  Inserts the resource files it finds using searchPath. It's recursive.
  Puts the optional prefix before the induvidual fileNames.

\33\17//@WIN\33\7
  Specifies that is a windowed application. The default run.bat will not
  include the 'pause' command at the end.

\33\17//@COMPILE [param1 [param2 [paramN...]]]\33\7
\33\17//@LINK [param1 [param2 [paramN...]]]\33\7
  Passes parameters to the DMD compiler and to the OPTLINK linker.

\33\17//@RUN <command>\33\7
  After successful compile/link it puts these commands into a .bat file
  and runs it. Example:
    //@RUN $ 1234
    //@RUN @pause
  It will run the current executable using 1234 as a parameter and leave the
  console window on screen by using pause.
  Special characters:
    \"$\" is a wildcard for the target executable fileName without the extension.

Experimental:
\33\17//@RELEASE\33\7
  Adds -release -O -inline -boundscheck=off params to the COMPILE options

\33\17//@SINGLE\33\7
  Single pass compilation without caching

\33\17//@LDC\33\7
  Use LDMD2 compiler instead of DMD.
";

//////////////////////////////////////////////////////////////////////////////
//  Common structs                                                          //
//////////////////////////////////////////////////////////////////////////////

//todo: editor: amikor higlightolja a szot, amin allok, akkor .-al egyutt is meg . nelkul is kene csinalni.
//todo: info/error logging kozpontositasa.

struct EditorFile{ align(1):  //Editor sends it's modified files using this struct
  char* fileName, source;     //align1 for Delphi compatibility
  int length;
  DateTime dateTime;
}

struct BuildSettings{
  bool verbose, compileOnly, generateMap, leaveObjs, rebuild, killExe, collectTodos, useLDC, singleStepCompilation;
  bool isWindowedApp;
  string[] importPaths, compileArgs, linkArgs;

  /// This is needed because the main source header can override the string arrays
  auto dup(){
    auto res = this;
    res.importPaths = importPaths.dup;
    res.compileArgs = compileArgs.dup;
    res.linkArgs    = linkArgs   .dup;
    return res;
  }
}

private struct MSVCEnv{ static{ // MSVCEnv ///////////////////////////////
  private{
    string[string] amd64, x86;
    string current;
    void get(ref string[string] e, string cmd){
      import std.process;
      auto r = executeShell(cmd, null, Config.suppressConsole).output;
      if(r.empty) throw new Exception("Unable to run msvcEnv.bat. Please put LDC2/bin into the PATH.");

      void add(string s){
        auto i = s.indexOf("=");
        if(i<0) return;
        auto name = s[0..i], value = s[i+1..$];
        e[name] = value;
      }
      r.lineSplitter.each!add;
    }

    string[string] acquire(ref string[string] e, string arch){
      if(e.empty) get(e, `msvcenv `~arch~` && set`);
      return e;
    }
  }

  string[string] getEnv(bool amd64_){
    if(amd64_) return acquire(amd64, "amd64");
          else return acquire(x86  , "x86"  );
  }
}}

//////////////////////////////////////////////////////////////////////////////
//  Hash calculation                                                        //
//////////////////////////////////////////////////////////////////////////////

private string calcHash(string data, string data2 = "") //todo: XXH-ra atirni ezt
{
  auto sha = new SHA1Digest;
  sha.reset;
  sha.put(cast(ubyte[])data);
  sha.put(cast(ubyte[])data2);
  return toHexString(sha.finish);
}

//////////////////////////////////////////////////////////////////////////////
//  BuildSys Source File Cache                                              //
//////////////////////////////////////////////////////////////////////////////

private struct BuildCache{
private:
  //first look inside this
  EditorFile[File] editorFiles;

  //then look into the filesystem
  struct Content{
    File file;
    string source;
    DateTime dateTime;
    string hash;

    //processed things
    Parser parser;
    bool processed;

    void unProcess(){
      processed = false;
      parser = new Parser();
    }

    void process(){
      parser.tokenize(file.fullName, source); //todo: fileName-t tovabb vinni
    }
  }
  Content[File] cache;

public:
  void reset() { cache.clear; }

  void dump() { foreach(ref ch; cache) writeln(ch.file); } //todo: editor: ha typo-t ejtek, es egy nekifutasra irtam be a szot, akkor magatol korrigaljon!

  void setEditorFiles(int count, EditorFile* data){
    editorFiles.clear;
    foreach(i; 0..count){
      auto fn = File(to!string(data[i].fileName));
      editorFiles[fn] = data[i];
    }
    editorFiles.rehash;
  }

  Content* access(File file){
    //id  cache editor what_to_do_with_cache
    //0   0     0      load from file
    //1   0     1      load from editor
    //2   1     0      load from file if fileDate>cacheDate
    //3   1     1      load from editor if editorDate>cacheDate

    auto ef = file in editorFiles;
    auto ch = file in cache;

    void refresh(){
      ch.unProcess;
      if(ef){ //refresh from editor
        ch.dateTime = ef.dateTime;
        ch.source = to!string(ef.source[0..ef.length]);
      }else{ //refresh from file
        ch.dateTime = file.modified;
        ch.source = file.readStr(false); //not mustexists because some files are nonexistent due to conditional imports
      }
      ch.hash = calcHash(ch.source);
    }

    if(!ch){ //not in cache
      cache[file] = Content(file);
      ch = file in cache; //opt: unoptimal
      refresh;
    }else{ //already in cache
      auto dt = ef ? ef.dateTime
                   : file.modified;
      if(ch.dateTime<dt) refresh;
    }

    //access now temporarily has automatic processing
    if(chkSet(ch.processed))
      ch.process;

    return ch;
  }

}

//Todo: editor: ha ilyen bazinagy commentbe irok, akkor a keretet ne csusztassa el a jobbszelen.
//Todo: editor: ha ratehenkedek a //-re, es FOLYAMATOSAN nyomom, akkor egeszitse ki 80 char-ig! Ugyanez --ra meg =-re
//Todo: editor: ha hosszan nyomom az r-t, akkor egeszitse ki return-ra!
//Todo: editor: while, if utan rakjon()-t is leptesse a kurzort!

//////////////////////////////////////////////////////////////////////////////
//  ModuleInfo class used by Builder                                        //
//////////////////////////////////////////////////////////////////////////////

class ModuleInfo{
  File file; //todo: rename it to just 'file'
  string fileHash;
  string moduleFullName;
  File[] imports;
  File[] deps; //dependencies
  string objHash; //calculated by hashing the dependencies and the compiler flags

  int sourceLines, sourceBytes; //stats

  this(BuildCache.Content* content){
    file = content.file;
    fileHash = content.hash;
    sourceLines = content.parser.sourceLines;
    sourceBytes = content.source.length.to!int;

    moduleFullName = content.parser.getModuleFullName;
    if(moduleFullName.empty) moduleFullName = file.nameWithoutExt;
  }
}

//todo: editor ha egy wordon allok, akkor a tobbi wordot case sensitiven keresse! Ez mar nem pascal!

//todo: editor: ha kijelolok egy szovegreszt es replacezni akarok akkor az autocomplete legordulobe csak az ott elofordulo szavakat rakja ki!
//todo: editorban ha typo error van es mar nincs rajta a cursor, akkor villogjon az az error, meg legyen egy gomb, ami javitja is az

//////////////////////////////////////////////////////////////////////////////
//  Module Import Dependency Solver                                         //
//////////////////////////////////////////////////////////////////////////////

void resolveModuleImportDependencies(ref ModuleInfo[] modules)
{
  //todo: az addIfCan linearis kereses miatt ez igy szornyen lassu: 209 file-t 1.8sec alatt csinalt meg: kesobb majd meg kell csinalni binaris keresesre vagy ami megjobb: NxN-es boolean matrixosra.

  //extend module imports to dependency lists
  foreach(ref m; modules){
    m.deps = m.imports.dup;           //it's depending on it's imports...
    m.deps.addIfCan(m.file);      //...and itself. (In D a module can import itself too)
  }

  bool any;
  do{
    any = false;
    foreach(ref m1; modules) foreach(ref m2; modules){
      if(m1.deps.canFind(m2.file)){ //when m1 deps m2
        foreach(fn; m2.deps){
          any |= m1.deps.addIfCan(fn); //add m2's deps to m1's import list if can. Don't add self
        }
      }
    }
  }while(any);

  //sort it to make it consequent
  modules.each!q{a.deps.sort};
}

void calculateObjHashes(ref ModuleInfo[] modules, string salt)
{
  foreach(ref m; modules){
    string s = salt~"|"~m.file.fullName;
    foreach(dep; m.deps){
      s ~= modules.filter!(m => m.file==dep).map!"a.file.fullName~a.fileHash".reduce!"a~b"; //opt: ez 2x olyan gyors lehetne filter nelkul
    }
    m.objHash = calcHash(s);
    //contains hash of all the required filenames and fileContents plus a salt (compiler options)
  }
}


//////////////////////////////////////////////////////////////////////////////
//  Build System                                                            //
//////////////////////////////////////////////////////////////////////////////

struct BuildSystem{
private: //current build
  //input data
  File mainFile;
  BuildSettings settings;

  //flags
  //bool verbose, compileOnly, generateMap, isWindowedApp, collectTodos, useLDC, singleStepCompilation;

  //derived data
  bool isExe, isDll, hasCoreModule;
  File targetFile, mapFile, defFile, resFile;
  File[string] resFiles;
  string[] runLines, defLines;
  ModuleInfo[] modules;
  string[] todos;

  //cached data
  BuildCache cache;
  ubyte[][string] objCache, exeCache, mapCache, resCache;

  //logging
  string sLog;
  void log(T...)(T args)
  {
    if(settings.verbose) { write(args); console.flush; }
    foreach(const s; args)
      sLog ~= to!string(s);
  }
  void logln (T...)(T args){ log(args, '\n'); }
  void logf  (T...)(string fmt, T args){ log(format(fmt, args)); }
  void logfln(T...)(string fmt, T args){ log(format(fmt, args), '\n'); }

  //Performance monitoring
  struct Times{
    float compile=0, res=0, link=0, all=0;
    float other() { return all-compile-res-link; }
    string report(){
      float pc = 100/all;
      return bold("PERFORMANCE:  ")~
             format("All:%.3f  =  Compile:%.3f + RC:%.3f + Link:%.3f + other:%.3f    (%.1f %.1f %.1f %.1f)%%",
             all, compile   , res   , link   , other   ,
                  compile*pc, res*pc, link*pc, other*pc);
    }
  }
  Times times;

  struct Perf{
    float *t;
    double T0;
    this(ref float f){ T0 = QPS; t = &f; }
    ~this(){ *t += QPS-T0; }
  }
  static perf(string f){ return "auto _perfMeasurerStruct = Perf(times."~f~");"; }

  void prepareMapResDef(){
    //mapFile
    File mf = targetFile.otherExt(".map");
    mf.remove;
    if(settings.generateMap){
      mapFile = mf;
    }

    //defFile
    File df = targetFile.otherExt(".def"); //todo:redundant
    df.remove;
    if(!defLines.empty){
      defFile = df;
      string defContent = defLines.join("\r\n");
      defFile.write(defContent);
      foreach(idx, line; defLines) logln(idx ? " ".replicate(5):bold("DEF: "), line);
    }

    //resFile
    if(resFiles.length>0) resFile = targetFile.otherExt(".res"); //todo:redundant
  }

  void initData(File mainFile_){ //clears the above
    mainFile = mainFile_;
    isExe = isDll = hasCoreModule = false;
    targetFile = File("");
    runLines    .clear;
    defLines    .clear;
    resFiles    .clear;
    modules     .clear;
    todos       .clear;
  }

  static bool removePath(ref File fn, Path path){ //todo: belerakni az utils-ba, megcsinalni path-osra a DPath-ot.
    bool res = fn.fullName.startsWith(path.fullPath);
    if(res) fn.fullName = fn.fullName[path.fullPath.length..$];
    return res;
  }
  static bool removePath(ref File fn, string path){ return removePath(fn, Path(path)); }

  static string bold(string s) { return "\33\17"~s~"\33\7"; }

  string smallName(File fn){ //strips down extension, removes filePath
    fn.ext = "";

    if(!removePath(fn, mainFile.path))
      foreach(p; DPaths.allPaths)
        if(removePath(fn, p)) break;

    return fn.fullName.replace(`\`, `.`);
  }

  void processBuildMacro(string buildMacro){
    void addCompileArgs(const string[] args){ foreach(p; args) settings.compileArgs.addIfCan(p); }
    void addLinkArgs   (const string[] args){ foreach(p; args) settings.linkArgs   .addIfCan(p); }

    const args = splitCommandLine(buildMacro),
          cmd = lc(args[0]),
          param1 = args.length>1 ? args[1] : "";

    const isMain = modules.length==1;

    const isTarget = ["exe", "dll"].canFind(cmd);
    if(!isExe && !isDll){
      enforce(isTarget, "Main project file must start with target declaration (//@EXE or //@DLL) with an optional projectName.");
    }else{
      enforce(!isTarget, "Target declaration (//@EXE or //@DLL) is already specified.");
    }

    switch(cmd){
      case "exe": case "dll":{
        enforce(isMain, "Target declaration (//@EXE or //@DLL) is not in the main file.");

        isExe = cmd=="exe";
        isDll = cmd=="dll";

        auto ext = "."~cmd;
        targetFile = param1.empty ? mainFile.otherExt(ext)
                                  : File(mainFile.path, param1~ext); //todo: pathosra

        if(isDll){ //add implicit macros for DLL
          settings.compileArgs ~= "-shared";
          defLines ~= "LIBRARY";
          defLines ~= "EXETYPE NT";
          defLines ~= "SUBSYSTEM WINDOWS";
          defLines ~= "CODE SHARED EXECUTE";
          defLines ~= "DATA WRITE";
        }
        break;
      }
      case "res":{
        string id = args.length>2 ? args[2] : "";
        auto src = File(param1);

        if(!src.isAbsolute) src.path = mainFile.path; //all resources are relative to the project, unless they as absolute.

        bool any;
        if(src.exists){ //one file
          if(id=="") id = src.name;
          resFiles[id] = src;
          any = true;
        }else{
          string pattern = src.name;
          if(pattern=="") pattern = "*.*";
          try{
            //todo: filekeresest belerakni a filePath-ba.
            foreach(f; dirEntries(src.path.fullPath, pattern, SpanMode.shallow)){ //many files
              auto fn = File(f.name);
              if(fn.exists){
                resFiles[id ~ fn.name] = fn;
                any = true;
              }
            }
          }catch(Throwable){}
        }
        enforce(any, format(`Can't find any resources at: "%s"`, src)); //todo: source file/line number visszajelzes

        break;
      }
      case "def"    :{ defLines ~= buildMacro[3..$].strip;                                      break; }
      case "win"    :{ settings.isWindowedApp = true;                                           break; }
      case "compile":{ settings.compileArgs.addIfCan(args[1..$]);                               break; }
      case "link"   :{ addLinkArgs(args[1..$]);                                                 break; }
      case "run"    :{ runLines ~= buildMacro[3..$].strip.replace("$", targetFile.fullName);    break; }
      case "import" :{ DPaths.addImportPathList(buildMacro[6..$]);                              break; }
      case "release":{ addCompileArgs(["-release", "-O", "-inline", "-boundscheck=off"]);       break; }
      case "ldc"    :{ settings.useLDC = true;                                                  break; }
      case "single" :{ settings.singleStepCompilation = true;                                   break; }
      default: enforce(false, "Unknown BuildMacro command: "~cmd);
    }
  }

  //process source files recursively
  void processSourceFile(File file){
    if(modules.canFind!(a => a.file==file)) return;

    enforce(file.exists, format(`File not found: "%s"`, file));

    //add this module
    double dateTime;
    auto act = cache.access(file);
    modules ~= new ModuleInfo(act);
    auto mAct = &modules[$-1];

    //process buildMacros
    foreach(bm; act.parser.buildMacros) processBuildMacro(bm);

    //collect Todo/Opt list
    todos ~= act.parser.todos;

    //decide if it has to link with windows libs
    if(!hasCoreModule){
      foreach(const imp; act.parser.importDecls) if(imp.isCoreModule){
        addIfCan(settings.linkArgs, ["kernel32.lib", "user32.lib"]); //todo: not needed to add these, they're implicit -> try it out!
        hasCoreModule = true;
        break;
      }
    }

    //collect imports NEW
    act.parser.importDecls.filter!q{a.isUserModule}
                          .each!(a => mAct.imports.addIfCan(File(a.resolveFileName(mainFile.path.fullPath, file.fullName, true))) );

    //reqursive walk on imports
    foreach(imp; mAct.imports) processSourceFile(imp);
  }

  static string processDMDErrors(string sErr, string path){ //processes each errorlog individually, making absolute filepaths
    string[] list;
    auto rx = ctRegex!`(.+)\(.+\): `;
    foreach(s; sErr.splitLines){

      //Make absolute paths.
      auto m = matchFirst(s, rx);
      if(!m.empty){
        string fn = m[1];
        if(!fn.canFind(`:\`))
          s = path ~ s;
      }

      list ~= s~"\r\n";
    }
    return list.join;
  }

  static string mergeDMDErrors(ref string sErr){ //processes the combined log
    string[] list;
    foreach(s; sErr.splitLines){
      s ~= "\r\n";
      if(!list.canFind(s))
        list ~= s;
    }
    return list.join;
  }

  ModuleInfo* findModule(File fn){
    foreach(ref m; modules) if(m.file==fn) return &m;
    return null;
  }

  auto objFileOf(File srcFile)
  {
    //for incremental builds: main file is OBJ, all others are LIBs
    //auto ext = srcFile==mainFile ? ".obj" : ".lib";
    auto ext = ".obj";
    return srcFile.otherExt(ext);
  }

  bool is64bit(){ return settings.compileArgs.canFind("-m64"); }
  bool isOptimized(){ return settings.compileArgs.canFind("-O"); }

  void compile(File[] srcFiles, string[] compileArgs, bool multi) // Compile ////////////////////////
  {
    mixin(perf("compile"));
    if(srcFiles.empty) return;

    //make DMD commandline args
    auto args = [settings.useLDC ? "ldmd2" : "dmd", "-vcolumns"];

    if(multi){
      args ~= ["-c", "-op", "-allinst"];
    }else{
      if(settings.generateMap && !settings.useLDC/+LDC doesn't supports+/) args ~= "-map";
    }

    if(settings.useLDC && !is64bit){ args.addIfCan("-m32"); }

    if(!DPaths.importPaths.empty) args ~= "-I"~DPaths.getImportPathList; //TODO: space in path == bug?
    args ~= compileArgs;

    //make commandLines
    string[][] cmdLines;
    if(multi){
      foreach(fn; srcFiles){
        auto c = args ~ fn.fullName;
        //ez nem tudom, mi. if(sameText(fn.ext, `.lib`)) c ~= "-lib";
        cmdLines ~= c;
      }
    }else{//single
      auto c = args;
      c ~= `-of=`~targetFile.fullName;
      foreach(fn; srcFiles) c ~= fn.fullName;
      if(defFile.fullName!="") c ~= defFile.fullName;
      if(resFile.fullName!="") c ~= resFile.fullName;

      string[] libFiles;
      foreach(fn; settings.linkArgs) switch(lc(File(fn).ext)){ //todo: ezt osszevonni a linkerrel
        case ".lib": libFiles ~= fn; break;
        default: break;
      }
      if(is64bit && !settings.useLDC) c ~= libFiles;

      cmdLines ~= c;
    }

//////////////////////////////////////////////////////////////////////////////////////

    string[] sOutputs;
    int res = spawnProcessMulti(cmdLines, null, sOutputs, (i){ logln(bold("COMPILING: ")~joinCommandLine(cmdLines[i])); });
    logln;

    //postprocess the combined error log
    string sOutput;
    foreach(i, ref o; sOutputs) sOutput ~= processDMDErrors(o, srcFiles[i].path.fullPath);
    sOutput = mergeDMDErrors(sOutput);
    //add todos
    if(settings.collectTodos)
      sOutput ~= todos.map!(s => s~"\r\n").join;

    //check results
    enforce(res==0, sOutput);
    if(!sOutput.empty) logln(sOutput);

//////////////////////////////////////////////////////////////////////////////////////

    //store freshly compiled obj files for later use
    if(multi){
      File[] objStored;
      foreach(fn; srcFiles){
        auto objFn = objFileOf(fn);
        objCache[findModule(fn).objHash] = objFn.read;
        objStored ~= objFn;
      }
      if(!objStored.empty)
        logln(bold("STORING OBJ -> CACHE: "), objStored.map!(a=>smallName(a)).join(", "));
    }
  }

  void overwriteObjsFromCache(File[] filesInCache)
  {
    File[] objWritten;
    foreach(fn; filesInCache){ //provide files already in cache
      auto data = objCache[findModule(fn).objHash];
      auto objFn = objFileOf(fn);
      if(!equal(data, fn.read(false))){ //only write if needed
        objFn.write(data);
        objWritten ~= fn;
      }
    }
    if(!objWritten.empty)
      logln(bold("WRITING CACHE -> OBJ: "), objWritten.map!(a=>smallName(a)).join(", "));
  }

  void resCompile(File resFile, string resHash) //todo: ez igy csunya, ahogy at van passzolva
  {
    mixin(perf("res"));
    resFile.remove;
    if(resFiles.length>0){
      auto resInCache = (resHash in resCache) !is null;
      if(resInCache){ //found in cache
        auto data = resCache[resHash];
        if(!equal(resFile.read, data)){
          logln(bold("WRITING CACHE -> RES: "), resFile);
          resFile.write(data);
        }
      }else{ //recompiling
        auto rcFile = resFile.otherExt(".rc");

        string toCString(File s) { return `"`~s.fullName.replace(`\`, `\\`).replace(`"`, `\"`)~`"`; }

        //create rc content
        auto rcContent = resFiles.byKeyValue
          .map!(kv => format("Z%s 999 %s", toHexString(cast(ubyte[])kv.key), toCString(kv.value))).join("\r\n");
        rcFile.write(rcContent);

        //call RC.exe
        auto rcCmd = ["rc", rcFile.fullName];
        logln(bold("CALLING RC: "), joinCommandLine(rcCmd));
        auto rc = execute(rcCmd, null, Config.suppressConsole);

        //cleanup
        rcFile.remove;

        enforce(enforce(rc.status==0, rc.output));

        logln(bold("STORING RES -> CACHE: "), resFile);
        resCache[resHash] = resFile.read;
      }
    }else{
      resFile.remove; //no resfile needed
    }
  }

  void link(string[] linkArgs)// Link ////////////////////////
  {
    mixin(perf("link"));
    if(modules.empty) return;

    const useOptLink = !settings.useLDC && !is64bit,
          useMSLink = !useOptLink;

    string[] objFiles = modules.map!(m => objFileOf(m.file).fullName).array,
             libFiles,           //user32, kernel32 nem kell, megtalalja magatol
             linkOpts; //todo: kideriteni, hogy ez miert kell a windowsos cuccokhoz

    if(useOptLink) linkOpts ~= "/noi";

    if(settings.generateMap) addIfCan(linkOpts, useMSLink ? "/MAP" : "/DETAILEDMAP");

    foreach(fn; linkArgs) switch(lc(File(fn).ext)){ //sort out different link commandline parts
      case ".obj": objFiles ~= fn; break;
      case ".lib": libFiles ~= fn; break;
      case ".map": mapFile = File(fn); break;
      default: linkOpts ~= fn; //treat as an option
    }

    if(useOptLink){//////////////////////////////////////////////////////////////////////////
      string[] tol(string s) { return s.empty ? [] : [s]; }
      auto cmd = ["link"] ~ objFiles                  ~","
                          ~ targetFile.fullName       ~","
                          ~ tol(mapFile.fullName)     ~","
                          ~ libFiles                  ~","
                          ~ tol(defFile.fullName)     ~","
                          ~ tol(resFile.fullName);
      while(cmd[$-1]==",") cmd = cmd[0..$-1]; //cut back last commas
      cmd ~= linkOpts.join("") ~";";  //add options and a semicolon

      logln(bold("LINKING: "), joinCommandLine(cmd));
      auto link = execute(cmd, [`LIB`:DPaths.libPath], Config.suppressConsole);

      defFile.remove; //cleanup
      enforce(link.status==0, link.output);  if(!link.output.empty) logln(link.output);
    }else if(useMSLink){//////////////////////////////////////////////////////////////////////////
      auto cmd = ["link",
                  `/LIBPATH:`~(settings.useLDC?(is64bit?`c:\D\ldc2\lib64`:`c:\D\ldc2\lib32`):(is64bit?`c:\D\dmd2\windows\lib64`:`c:\D\dmd2\windows\lib`)), //todo: the place for these is in DPath
                  `/OUT:`~targetFile.fullName,
                  `/MACHINE:`~(is64bit ? "X64" : "X86")]
                  ~linkOpts
                  ~libFiles
                  ~`legacy_stdio_definitions.lib`
                  ~objFiles;

      if(settings.useLDC){
        cmd ~= ["druntime-ldc.lib", "phobos2-ldc.lib", /*msvcrt.lib*/ "libcmt.lib"];
        /+note: LDC 1.20.0: "msvcrt.lib": gives a warning in the linker.
          https://stackoverflow.com/questions/3007312/resolving-lnk4098-defaultlib-msvcrt-conflicts-with
            libcmt.lib: static CRT link library for a release build (/MT)
            msvcrt.lib: import library for the release DLL version of the CRT (/MD) +/
      }

      auto line = joinCommandLine(cmd);
      logln(bold("LINKING: "), line);
      auto link = executeShell(line, MSVCEnv.getEnv(is64bit), Config.suppressConsole | Config.newEnv);

      defFile.remove; //cleanup
      enforce(link.status==0, link.output);  if(!link.output.empty) logln(link.output);
    }
  }


public:
  void reset_cache()
  {
    cache.reset;
    objCache.clear;
    exeCache.clear;
    mapCache.clear;
    resCache.clear;
  };

  bool killDeleteExe(File file){
    const killTimeOut   = 1.0,//sec
          deleteTimeOut = 1.0;//sec

    bool doDelete(){
      auto t0 = QPS;
      while(QPS-t0<deleteTimeOut){
        file.remove(false);
        if(!file.exists) return true;//success
        sleep(50);
      }
      return false;
    }

    if(!dbg.forceExit_set) return false; //fail: no DIDE present
    auto t0 = QPS;
    const timeOut = 1.0;//sec
    while(QPS-t0<killTimeOut){
      if(!dbg.forceExit_check) return doDelete; //success, delete it
      sleep(50);
    }
    dbg.forceExit_clear;
    return false; //fail: timeout
  }

  // Errors returned in exceptions
  void build(File mainFile_, BuildSettings settings_ = BuildSettings.init) // Build //////////////////////
  {
    {// compile
      times = times.init;
      mixin(perf("all"));

      sLog = "";
      initData(mainFile_);
      settings = settings_.dup;

      //Rebuild all?
      if(settings.rebuild)
        reset_cache;

      //reqursively collect modules
      processSourceFile(mainFile);

      //check if target exists
      enforce(isExe||isDll, "Must specify project target (//@EXE or //@DLL).");

      //calculate dependency hashed of obj files to lookup in the objCache
      modules.resolveModuleImportDependencies;
      modules.calculateObjHashes(joinCommandLine(settings.compileArgs)~" useLDC:"~text(settings.useLDC));

      //ensure that no std or core files are going to be recompiled
      foreach(const m; modules)
        enforce(!m.file.fullName.startsWith(DPaths.stdPath) && !m.file.fullName.startsWith(DPaths.etcPath) && !m.file.fullName.startsWith(DPaths.corePath),
          `It is forbidden to recompile an std/etc/core module.`);

      //select files for compilation
      File[] filesToCompile, filesInCache;
      foreach(ref m; modules) ((m.objHash !in objCache) ? filesToCompile : filesInCache) ~= m.file;

      //print out information
      {
        int totalLines = modules.map!"a.sourceLines".sum,
            totalBytes = modules.map!"a.sourceBytes".sum;

        logln(bold("BUILDING PROJECT:    "), mainFile);
        logln(bold("TARGET FILE:         "), targetFile);
        logln(bold("OPTIONS:             "), settings.useLDC?"LDC":"DMD", " ", is64bit?64:32, "bit ", isOptimized?"REL":"DBG", " ", settings.singleStepCompilation?"SINGLE":"INCR");
        logln(bold("SOURCE STATS:        "), format("Lines: %s   Bytes: %s", totalLines, totalBytes));

        foreach(i, const m; modules){
          auto list = m.deps.filter!(fn => fn!=m.file).map!(a => smallName(a)).join(", ");
          bool comp = filesToCompile.canFind(m.file);
          logln((comp ? " \33\16*\33\7 " : "  "), bold(smallName(m.file))~" : "~list);
        }
      }


      //delete target file and bat file.
      //It ensures that nothing uses it, and there will be no previous executable present after a failed compilation.
      targetFile.remove(false);
      if(targetFile.exists){
        if(settings.killExe){
          enforce(killDeleteExe(targetFile), "Failed to close target process.");
        }else{
          enforce(false, "Unable to delete target file.");
        }
      }

      /////////////////////////////////////////////////////////////////////////////////////
      // calculate resource hash
      string resHash = calcHash(resFiles.byKeyValue.map!(kv => format("(%s|%s|%.8f)", kv.key, kv.value, kv.value.modified)).join);

      /////////////////////////////////////////////////////////////////////////////////////
      // compile and link
      auto exeHash = calcHash(joinCommandLine(settings.linkArgs ~ targetFile.fullName ~ modules[0].objHash ~ resHash)); //depends on main obj and on linker params.  //todo: include resource hash
      bool exeInCache = (exeHash in exeCache) !is null;
      if(exeInCache){ //exe file is already found in cache
        auto data = exeCache[exeHash];
        logln(bold("WRITING CACHE -> EXE: "), targetFile);
        targetFile.write(data); //overwrite if needed
        if(exeHash in mapCache)
          mapFile.write(mapCache[exeHash]);
      }else{
        prepareMapResDef;
        resCompile(resFile, resHash);

        if(settings.singleStepCompilation){
          compile(filesToCompile, settings.compileArgs, false);
        }else{
          compile(filesToCompile, settings.compileArgs, true);
          overwriteObjsFromCache(filesInCache);
          link(settings.linkArgs);
        }

        logln(bold("STORING EXE -> CACHE: "), targetFile);
        exeCache[exeHash] = targetFile.read;
        if(mapFile.exists)
          mapCache[exeHash] = mapFile.read;
      }

      /////////////////////////////////////////////////////////////////////////////////////
      // cleanup
      if(!settings.leaveObjs){ //including res file
        resFile.remove;
        foreach(fn; filesToCompile~filesInCache) fn.otherExt(".obj").remove;
      }

      if(!settings.generateMap) mapFile.remove; //linker makes it for dlls even not wanted

    }//end of compile

    /////////////////////////////////////////////////////////////////////////////////////
    // performance monitoring
    logln(times.report);

    /////////////////////////////////////////////////////////////////////////////////////
    // run
    if(!settings.compileOnly){
      const batFile = File(targetFile.path, "$run.bat");
      batFile.remove;

      auto runCmd = runLines.join("\r\n");

      //make the default runCmd for exe
      if(runCmd.empty && isExe){
        runCmd = targetFile.fullName;
        if(!settings.isWindowedApp) runCmd ~= "\r\n@pause";
      }

      if(!runCmd.empty){
        batFile.write(runCmd);
        foreach(idx, line; runCmd.split('\n')) logln(idx ? " ".replicate(9):bold("RUNNING: "), line);
        spawnProcess(batFile.fullName);  //todo: editor kesobb letorolhetne ezt a bat-ot magatol.
      }
    }
  }

  auto findDependencies(File mainFile_, BuildSettings settings_=BuildSettings.init){ // findDependencies //////////////////////////////////////
    sLog = "";
    initData(mainFile_);
    settings = settings_.dup;

    //Rebuild all?
    if(settings.rebuild)
      reset_cache;

    //reqursively collect modules
    processSourceFile(mainFile);

    //check if target exists
    enforce(isExe||isDll, "Must specify project target (//@EXE or //@DLL).");

    //calculate dependency hashed of obj files to lookup in the objCache
    modules.resolveModuleImportDependencies;

    int totalLines = modules.map!"a.sourceLines".sum,
        totalBytes = modules.map!"a.sourceBytes".sum;
    logln(bold("SOURCE STATS:        "), format("Modules: %s   Lines: %s   Bytes: %s", modules.count, totalLines, totalBytes));

    logln(bold("\nDEPENDENCIES:"));
    foreach(i, const m; modules){
      auto list = m.deps.filter!(fn => fn!=m.file).map!(a => smallName(a)).join(", ");
      logln(bold(smallName(m.file))~" : "~list);
    }

    logln(bold("\nIMPORTS:"));
    foreach(const m; modules){
      auto list = m.imports.filter!(fn => fn!=m.file).map!(a => smallName(a)).join(", ");
      logln(bold(smallName(m.file))~" : "~list);
    }

    return modules;
  }


  // This can be used by commandline or by a dll export.
  //    Input: args (args[0] is ignored)
  //    Outputs: statnard ans error outputs.
  //    result: 0 = no error
  int commandInterface(string[] args, ref string sOutput, ref string sError) nothrow // command interface /////////////////////////////
  {
    try{
      sLog = sError = sOutput = "";

      File mainFile;
      bool help = false;


todo: utils.parseOptions(T)(string[] args, ref T options){

      BuildSettings settings;
      import std.getopt;
      auto opts = getopt(args,
        std.getopt.config.bundling,
        "v|verbose"     , `Verbose output. Otherwise it will only display the errors.`  , &settings.verbose      ,
        "m|map"         , `Generate map file.`                                          , &settings.generateMap  ,
        "c|compileOnly" , `Compile and link only, do not run.`                          , &settings.compileOnly  ,
        "e|leaveObj"    , `Leave behind .obj and .res files after compilation.`         , &settings.leaveObjs    ,
        "r|rebuild"     , `Rebuilds everything. Clears all caches.`                     , &settings.rebuild      ,
        "I|include"     , `Add include path to search for .d files.`                    , &settings.importPaths  ,
        "o|compileOpt"  , `Pass extra compiler option.`                                 , &settings.compileArgs  ,
        "L|linkOpt"     , `Pass extra linker option.`                                   , &settings.linkArgs     ,
        "k|kill"        , `Kill currently running executable before compile.`           , &settings.killExe      ,
        "t|todo"        , `Collect //Todo: and //Opt: comments.`                        , &settings.collectTodos ,

        "n|single"      , `Single step compilation`                                     , &settings.singleStepCompilation,
        "d|ldc"         , `Use LDC2 compiler instead of DMD`                            , &settings.useLDC       ,
      );

      if(opts.helpWanted || args.length<=1) {
        string s = opts.options.map!(o => format(`  %-19s %s`,
          [o.optShort, o.optLong].join(" "), o.help)).join("\r\n");
        this.settings.verbose = true;
        logln(helpStr.replace(`$$$OPTS$$$`, s));
      }else{
        mainFile = File(absolutePath(args[1]));
        enforce(mainFile.exists, "Error: File not found: "~mainFile.fullName);
        build(mainFile, settings);
      }

      sOutput = sLog;
      return 0;

    }catch(Throwable t){
      sError = t.msg;
//      try{ sError = format("[hdmd/%s(%s)]: %s", t.file, t.line, t.msg); }catch{}
      sOutput = sLog;
      return -1;
    }
  }
}