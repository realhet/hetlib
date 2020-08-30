//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

import het, /*het.com, */het.ui;

import std.windows.registry;

enum Parity { none, odd, even, mark, space}  enum ParityLetters = ["N","O","E","M","S"];
enum StopBits { one, onePointFive, two }     enum StopBitStrings = ["1", "1.5", "2"];
enum ComPortState { offline, online, createError, writeError }

class ComPort{
  static private string READONLYPROP(T, string name, string _default="$.init")(){ return "private $ _*=#; @property auto *(){ return _*; }".replace('#', _default).replace('$', T.stringof).replace('*', name); }

  mixin(READONLYPROP!(int, "id"));
  mixin(READONLYPROP!(bool, "exists"));
  mixin(READONLYPROP!(string, "description"));
  mixin(READONLYPROP!(int, "iconIndex"));

  enum defaultBaud = 9600, defaultBits = 8;

  //@SUGGESTIONS([2400u, 4800, 9600, 14400, 19200, 38400, 57600, 115200, 128000, 256000]);
  uint baud = defaultBaud;

  //@SUGGESTIONS([ubyte(5), 6, 7, 8])
  ubyte bits = defaultBits;

  Parity parity;
  StopBits stopBits;

  bool active = false;

  private string configInRegistry;
  @property{
    auto config(){
      return format!"%s %s%s%s"(baud, bits, ParityLetters.get(cast(int) parity), StopBitStrings.get(cast(int) stopBits));
    }

    void config(string s){
      baud = defaultBaud;
      bits = defaultBits;
      parity = Parity.none;
      stopBits = StopBits.one;

      if(s.isWild("?* ?*")){
        baud = wild.ints(0, defaultBaud);               //print(baud);

        s = wild[1].uc;

        //get bits from the start
        if(s.length>=1 && s[0].inRange('5', '8')){
          bits = s[0..1].to!ubyte;                      //print(bits);
          s = s[1..$];
        }

        //get stopBits.from the end
        foreach(idx, p; StopBitStrings) if(s.endsWith(p)){
          stopBits = cast(StopBits) idx;                //print(stopBits);
          s = s[0..$-p.length];
          break;
        }

        //get the Parity
        foreach(idx, p; ParityLetters) if(s.startsWith(p)){
          parity = cast(Parity) idx;                    //print(parity);
          s = s[0..$-p.length];
          break;
        }

      }
    }

    this(int id){ //1based
      enforce(id.inRange(1, ComPorts.totalPorts));
      _id = id;

      readPortConfig;
    }

    private void readPortConfig(){
      try{
        string s = comPorts.regKeyPortConfig_read.getValue("COM"~text(id)~":").value_SZ;
        if(isWild(s, "*,*,*,*")){ //baud,parity,bits,stopBits
          string configInRegistry = format!"%s %s%s%s"(wild[0], wild[2], wild[1].uc, wild[3]);
          print("COM"~id.text~":", "Reading portConfig from registry:", s, configInRegistry);
          config = configInRegistry;
        }
      }catch(Throwable){}
    }

    private void writePortConfig(){
      try{
        auto s = format!"%s,%s,%s,%s"(baud, (parity.text)[0], bits, StopBitStrings[cast(int)stopBits]);
        comPorts.regKeyPortConfig_write.setValue("COM"~text(id)~":", s);
        print("COM"~id.text~":", "Written portConfig to registry:", s);
      }catch(Throwable){}
    }

  }

/*  private{
    FHandle:integer;
    FBuff:RawByteString;
    FOutBuff,FInBuff:ansistring;
    FCritSec:TCriticalSection;
    FChanged:boolean;
    FThrd:TComThread;
    FState:TComPortState;
    function CritSec:TCriticalSection;
    procedure thrdStart;
    procedure thrdStop;
    procedure thrdUpdate;
    procedure ReadConfigFromRegistry;
    procedure WriteConfigToRegistry;
    function GetInBuff:ansistring;
    procedure SetOutBuff(const Value:ansistring);
  public
    procedure AppendToInBuff(const s: ansistring);
    function FetchOutBuff(const MaxSize: integer=1024): ansistring;
    function TryRead: ansistring;
    procedure SetState(const st:TComPortState);
    property Handle:integer read FHandle;
  public
    CustomCOMHandler:TCustomCOMHandler;
    constructor Create(const AOwner:THetObject);override;
    destructor Destroy;override;
    procedure ObjectChanged(const AObj:THetObject;const AChangeType:TChangeType);override;
    property InBuff:ansistring read GetInBuff;
    property OutBuff:ansistring write SetOutBuff;
    property State:TComPortState read FState;
  public //extensibility
    property Changed:boolean read FChanged;
  end;*/
}

class ComPorts{
  enum totalPorts = 32;

  ComPort[] ports;

  auto opIndex(int idx){ return ports.get(idx-1); }

  //get and cache some registry keys
  private Key regKeyPortConfig_read, regKeyPortConfig_write;
  private void _initRegKeys(){
    try{
      auto base = Registry.localMachine.getKey("Software").getKey("Microsoft").getKey("Windows NT").getKey("CurrentVersion");
      regKeyPortConfig_read  = base.getKey("Ports");
      regKeyPortConfig_write = base.getKey("Ports", REGSAM.KEY_ALL_ACCESS);
    }catch(Throwable){}
  }

  this(){
    _initRegKeys;
  }

  private void _createPorts(){
    ports = iota(totalPorts).map!(i => new ComPort(i+1)).array;  //takes 2.2 millisecs for 32 ports
  }

}

auto comPorts(){
  __gshared static ComPorts _comPorts;
  if(_comPorts is null){
    _comPorts = new ComPorts;
    _comPorts._createPorts;
  }
  return _comPorts;
}

class FrmMain: GLWindow { mixin autoCreate; // FrmMain ////////////////////////////

  override void onCreate(){
/*    version(threadException){
      import core.thread;
      new Thread(&doException).start;
    }*/

    auto port = comPorts[9];
    port.baud = 14400;
    port.writePortConfig;
  }

  override void onUpdate(){
  }

  override void onPaint(){
    dr.clear(clGray);
    drGUI.clear;
    dr.textOut(0, 0, "Hello World");
  }
}