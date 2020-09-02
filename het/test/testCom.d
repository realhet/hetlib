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

mixin template ReadonlyField(T, string name, string _default="$.init"){
  mixin( "private $ _*=#; @property auto *() const{ return _*; }".replace('#', _default).replace('$', T.stringof).replace('*', name) );
}

class ComPort{
  //static private string READONLYPROP(T, string name, string _default="$.init")(){ return ; }

  mixin ReadonlyField!(int      , "id");
  mixin ReadonlyField!(bool     , "exists");
  mixin ReadonlyField!(string   , "description");
  mixin ReadonlyField!(int      , "iconIndex");

  enum defaultBaud = 9600, defaultBits = 8;

  //@SUGGESTIONS([2400u, 4800, 9600, 14400, 19200, 38400, 57600, 115200, 128000, 256000]);
  uint baud = defaultBaud;

  //@SUGGESTIONS([ubyte(5), 6, 7, 8])
  ubyte bits = defaultBits;

  Parity parity;
  StopBits stopBits;
  ComPortState state;

  @property{
    auto config() const{
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

      readConfigFromRegistry;
    }

    private void readConfigFromRegistry(){
      try{
        auto key = ComPorts.regKeyPortConfig;
        if(key is null) return;
        string s = key.getValue("COM"~text(id)~":").value_SZ;
        if(isWild(s, "*,*,*,*")){ //baud,parity,bits,stopBits
          string configInRegistry = format!"%s %s%s%s"(wild[0], wild[2], wild[1].uc, wild[3]);
          //print("COM"~id.text~":", "Reading portConfig from registry:", s, configInRegistry);
          config = configInRegistry;
        }
      }catch(Throwable){}
    }

    private void writeConfigToRegistry(){
      try{
        auto s = format!"%s,%s,%s,%s"(baud, (parity.text)[0], bits, StopBitStrings[cast(int)stopBits]);
        auto key = ComPorts.regKeyPortConfig_write;
        if(key is null) return;
        key.setValue("COM"~text(id)~":", s);
        //print("COM"~id.text~":", "Written portConfig to registry:", s);
      }catch(Throwable){}
    }

    override string toString() const{
      return format!`ComPort(COM%s, %s, %s, config="%s", descr="%s")`(id, exists ? "exists" : "absent", state.text, config, description);
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

  //cache some registry keys
  //private __gshared static Key regKeyPortConfig_read, regKeyPortConfig_write;

  static Key regKeyPortConfig      (){ return Registry.localMachine.getKey(`Software\Microsoft\Windows NT\CurrentVersion\Ports`); }
  static Key regKeyPortConfig_write(){ return Registry.localMachine.getKey(`Software\Microsoft\Windows NT\CurrentVersion\Ports`, REGSAM.KEY_ALL_ACCESS); }


  this(){
    //create ports
    ports = iota(totalPorts).map!(i => new ComPort(i+1)).array;

    updateDeviceInfo;
  }

  private void updateDeviceInfo(){

    bool decodePortIdx(string name, out int com){
      if(name.isWild("COM?*")){
        com = wild.ints(0);
        return this[com] !is null;
      }else{
        return false;
      }
    }

    struct PortDecl{ string name, deviceId; }

    PortDecl[int] portMap;

    void updatePortDecl(int idx, Key key){
      try{
        string devId;
        try{ devId = key.getValue("MatchingDeviceId").value_SZ; }catch(Throwable){}
        portMap[idx] = PortDecl(key.getValue("DriverDesc").value_SZ, devId);
      }catch(Throwable){}
    }

    void findExistingPorts(){
      try{
        auto baseKey = Registry.localMachine.getKey(`HARDWARE\DEVICEMAP\SERIALCOMM`);
        foreach(a; baseKey.values) try{
          int idx;
          if(decodePortIdx(a.value_SZ, idx)){
            portMap[idx] = PortDecl(a.name.withoutStarting(`\Device\`));

            //try to get comport info
            if(a.name.isWild(`\Device\Serial?*`)){
              const serialIdx = wild.ints(0, -1);
              if(serialIdx>=0){
                auto key = Registry.localMachine.getKey(`SYSTEM\CurrentControlSet\Control\Class\{4D36E978-E325-11CE-BFC1-08002BE10318}\` ~ format!"%.4d"(serialIdx));
                updatePortDecl(idx, key);
              }
            }

          }
        }catch(Throwable){}
      }catch(Throwable){}
    }

    void findModems(){
      try{
        auto baseKey = Registry.localMachine.getKey(`SYSTEM\CurrentControlSet\Control\Class\{4D36E96D-E325-11CE-BFC1-08002BE10318}`);
        foreach(k; baseKey.keys) try{
          int idx;
          if(decodePortIdx(k.getValue("AttachedTo").value_SZ, idx))
            if(idx in portMap)
              updatePortDecl(idx, k);
        }catch(Throwable){}
      }catch(Throwable){}
    }

    void findUsbSerials(string vid, string pid){
      try{
        auto baseKey = Registry.localMachine.getKey(`SYSTEM\CurrentControlSet\Enum\USB\VID_`~vid~`&PID_`~pid);
        foreach(k; baseKey.keys) try{
          int idx;
          auto kdp = k.getKey("Device Parameters");
          if(decodePortIdx(kdp.getValue("PortName").value_SZ, idx)){
            //print("USBSER found", idx);
            if(idx in portMap) try{
              portMap[idx].deviceId = kdp.getValue("SymbolicName").value_SZ.withoutStarting(`\??\`).withoutEnding(`#{a5dcbf10-6530-11d2-901f-00c04fb951ed}`);
            }catch(Throwable){}
          }
        }catch(Throwable){}
      }catch(Throwable){}
    }

    //print("Finding existing COM ports in Registry...");

    findExistingPorts; //1.4 msec
    findModems;
    findUsbSerials("04D8", "000A"); //CraftBot std Microsoft Serial
    findUsbSerials("1A86", "7523"); //Arduino CH34
    //14 msec

    //unplugged ports
    int[] unplugged;
    foreach(p; ports){
      if(p.id !in portMap){
        unplugged ~= p.id;
        p._exists = false;
        p._description = "";
      }
    }

    int[] plugged, replugged;
    foreach(i; portMap.keys){
      auto p = ports[i-1];
      auto descr = [portMap[i].name, portMap[i].deviceId].join("\t");
      if(!p.exists){
        p._exists = true;
        p._description = descr;
        plugged ~= i;
      }else if(p.description != descr){
        p._description = descr;
        replugged ~= i;
      }
    }

    auto changed = plugged.length || unplugged.length || replugged.length;
    //todo: process changes
  }

}

alias comPorts = Singleton!ComPorts;

/*auto comPorts(){
  __gshared static ComPorts _comPorts;
  if(_comPorts is null){
    _comPorts = new ComPorts;
  }
  return _comPorts;
}*/

class FrmMain: GLWindow { mixin autoCreate; // FrmMain ////////////////////////////

  override void onCreate(){
/*    version(threadException){
      import core.thread;
      new Thread(&doException).start;
    }*/

    import het.http;
    testHttpQueue;


    while(true){
      auto t0=QPS; comPorts.updateDeviceInfo; print(QPS-t0);
      foreach(i; 1..20){
        print(comPorts[i]);
      }
      sleep(1000);
    }
  }

  override void onUpdate(){
  }

  override void onPaint(){
    dr.clear(clGray);
    drGUI.clear;
    dr.textOut(0, 0, "Hello World");
  }
}