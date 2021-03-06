module het.debugclient;

import het.utils, core.sys.windows.windows, std.regex, std.demangle;

// LOGGER /////////////////////////////////////////////////////////////

__gshared int
  LOG_console = 0,
  LOG_dide = 0,
  LOG_throw = 50;

private template LOGLevelString(int level){
  enum levelIdx = ((level+1)/10-1).clamp(0, 4),
       subLevelDiff = level - levelIdx*10-10;

  enum LOGLevelString = ["\33\13DBG_", "\33\17LOG_", "\33\16WARN", "\33\14ERR_", "\33\14CRIT"][levelIdx]
                      ~ (subLevelDiff ? subLevelDiff.text : "");
}

string makeSrcLocation(string file, string funct, int line){
  auto fi = file.split(`\`),
       fu = funct.split(`.`);

  //ignore extension
  if(fi.length) fi[$-1] = fi[$-1].withoutEnding(".d");

  foreach_reverse(i;  1..min(fi.length, fu.length)){
    if(fi[$-i..$].equal(fu[0..i])){
      funct = fu[i..$].join('.');
      break;
    }
  }

  auto res = format!"%s(%d):"(file, line);
  if(funct!="") res ~= " @"~funct;

  return res;
}

void DBG (int level = 10, string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args){

  enum location = makeSrcLocation(file, funct, line);
  //format colorful message
  string s = format!"%s\33\7: T%0.4f: C%x: %s:  "(LOGLevelString!level, QPS-QPS0, GetCurrentProcessorNumber, location);
  static foreach(idx, a; args){ if(idx) s ~= " "; s ~= a.text; }
  s ~= "\33\7";

  if(level>=LOG_console) synchronized(dbg) writeln(s);
//  if(level>=LOG_dide   ) synchronized(dbg) dbg.sendLog(s);
  if(level>=LOG_throw  ) throw new Exception(s);
}

void LOG (string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args){ DBG!(20, file, line, funct)(args); }
void WARN(string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args){ DBG!(30, file, line, funct)(args); }
void ERR (string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args){ DBG!(40, file, line, funct)(args); }
void CRIT(string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args){ DBG!(50, file, line, funct)(args); }

void NOTIMPL(string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args){ ERR!(file, line, funct)("Not implemented."); }

///////////////////////////////////////////////////////////////////////////////////

void PING(int index = 0) { dbg.ping(index); }
void PING0(){ PING(0); };
void PING1(){ PING(1); };
void PING2(){ PING(2); };
void PING3(){ PING(3); };
void PING4(){ PING(4); };
void PING5(){ PING(5); };
void PING6(){ PING(6); };
void PING7(){ PING(7); };

//todo: (forceExit) a thread which kills the process. for example when readln is active.

/*void log(string s, string f = __FUNCTION__){
  StdFile(`c:\dl\a.txt`, "a").writeln(f, " ", s);
}*/

alias dbg = Singleton!DebugLogClient;

//todo: ha relativ a hibauzenetben a filename, akkor egeszitse ki! hdmd!

class DebugLogClient{ //todo: rewrite it with utils.sharedMemClient
public:
  enum potiCount = 8;
private:
  enum cBufSize = 1<<16; //the same as in DIDE.exe

  struct BreakRec {
    uint locationHash, state;
  }

  struct BreakTable {
    BreakRec[64] records;

    void waitFor(uint locationHash);
  }

  struct Data { //raw shared data. Careful with 64/32bit stuff!!!!!!
    uint ping;
    BreakTable breakTable;
    CircBuf!(uint, cBufSize) buf; //CircBuf is a struct, not a reference
    float[potiCount] poti;
    int forceExit;
    int exe_waiting;
    int dide_ack; //exception utan exe_waiting = 1 -> dide ekkor F9-re beleir 1-et az ackba es tovabbmegy az exe. ha -1-et ir az ack-ba, akkor kill.
    int dide_hwnd; //to call setforegroundwindow
    int exe_hwnd;
  }

  HANDLE dataFile;
  Data* data;

  void tryOpen() {
    string dataFileName = `Global\DIDE_DebugFileMappingObject`;

    dataFile = OpenFileMappingW(
                   FILE_MAP_ALL_ACCESS,    // read/write access
                   false,                  // do not inherit the name
                   dataFileName.toPWChar);  // name of mapping object

    data = cast(Data*)MapViewOfFile(dataFile,    // handle to map object
                 FILE_MAP_ALL_ACCESS,     // read/write permission
                 0,
                 0,
                 Data.sizeof);
    //ensure(data, "DebugLogClient: Can't open mapFile.");
  }

public:
  this(){
    tryOpen;
    sendLog("START:"~appFile.toString);
  }

  void ping(int index = 0){
    if(!data) return;
    data.ping |= 1<<index;
  }

  void sendLog(string s){
    if(!data) return;
    ubyte[] packet;
    packet.length = 4+s.length;
    *cast(uint*)(packet.ptr) = cast(uint)s.length;
    memcpy(&packet[4], s.ptr, s.length);
    while(!data.buf.store(packet)) sleep(1);
  }

  string getLog(){ //not needed on exe side. It's needed on dide side. Only for testing.
    if(!data) return "";

    uint siz;  if(!data.buf.get(&siz, 4)) return "";

    ubyte[] buf;  buf.length = siz;

    while(!data.buf.get(buf.ptr, siz)) sleep(1); //probably an error+deadlock...
    return cast(string)buf;
  }

  float getPotiValue(size_t idx){
    if(data && idx>=0 && idx<data.poti.length) return data.poti[idx];
                                          else return 0;
  }

  bool isActive() { return data !is null; }

  bool forceExit_set() { if(!data) return false; data.forceExit = 1; return true; }
  void forceExit_clear() { if(data) data.forceExit = 0; }
  bool forceExit_check() { if(data) return data.forceExit!=0; else return false; }

  void handleException(string msg){
    if(!data) return;

    data.dide_ack = 0;
    data.exe_waiting = 1;

    SetForegroundWindow(cast(void*)data.dide_hwnd);

    //fileWriteStr(`c:\dl\exc.txt`, msg);
    string s = "EXCEPTION:"~msg;
    dbg.sendLog(s);

    while(!data.dide_ack) sleep(1); //wait for dide

    data.exe_waiting = 0;

    if(data.dide_ack<0){
      data.dide_ack = 0;
      application.exit;
    }

    data.dide_ack = 0;
  }

  void setExeHwnd(void* hwnd){
    if(data) data.exe_hwnd = cast(int)hwnd;
  }
}


T _DATALOGMIXINFUNCT(T)(T t, string s, string file = __FILE__, int line = __LINE__){
  auto fn = file;
  fn.length = fn.indexOf("-mixin-");
  fn = extractFileName(fn)~'('~format("%s", line)~')';

  string msg = "LOG:"~fn~":"~s~":"~to!string(t);
  dbg.sendLog(msg);
  return t;
}

string _DATALOGMIXIN(string p) {
  return `_DATALOGMIXINFUNCT(`~p~`, q{`~p~`})`;
}

string _DATABRKMIXIN(string p) {
  return `_DATALOGMIXINFUNCT(`~p~`, q{`~p~`})`;
}

