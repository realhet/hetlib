module het.com;

import het.utils;

import std.windows.registry,
       core.sys.windows.winbase,
       core.sys.windows.winnt,
       core.sys.windows.basetsd : HANDLE;

struct ComPortSettings{ // ComPortSettings ////////////////////////////////////////////////
  @STORED string port = "";
  @STORED int baud = 9600;
  @STORED string params = "8N1";
  bool enabled;
}

HANDLE open(in ComPortSettings settings){
  enforce(settings.params.sameText("8N1"), "Only 8N1 supported"); //todo: interpret params

  string s = settings.port;
  if(s.map!isDigit.all) s = "COM" ~ s;
  if(s.uc.startsWith("COM") && s.length>4) s = `\\.\`~s;

  auto h = CreateFile(s.toPWChar, GENERIC_READ | GENERIC_WRITE, 0, null, OPEN_EXISTING, 0, null);
  if(h == INVALID_HANDLE_VALUE)
    raise("Can't open serial port "~s.quoted~" "~getLastErrorStr);

  try{
    DCB dcb;
    if(!GetCommState(h, &dcb)) raise("GetComState", getLastErrorStr);
    with(dcb){
      BaudRate = settings.baud;
      Parity = 0; //One
      StopBits = 0; //None
      ByteSize = 8;
      _bf = 0;
    }
    if(!SetCommState(h, &dcb)) raise("SetComState", getLastErrorStr);

    COMMTIMEOUTS ct;
    with(ct){
      ReadIntervalTimeout = 0xFFFFFFFF;
      ReadTotalTimeoutMultiplier = 0;
      ReadTotalTimeoutConstant = 0;
      WriteTotalTimeoutMultiplier = 1;
      WriteTotalTimeoutConstant = 500;
    }
    if(!SetCommTimeouts(h, &ct)) raise("SetComTimeouts", getLastErrorStr);
  }catch(Exception e){
    CloseHandle(h);
    throw e;
  }

  return h;
}

struct ComPortStats{ //ComPortStats /////////////////////////////////////////////////////////
  size_t messagesOut, bytesOut, messagesIn, bytesIn, errorCnt, dataErrorCnt;

  bool opened;
  string lastError;
  DateTime lastErrorTime, lastIncomingDataTime, lastIncomingMessageTime;

  void reset(){
    this = typeof(this).init;
  }
}

enum ComPortProtocol { raw, textPackets, binaryPackets }

struct MsgComPortError{ string error; }
struct MsgComPortClosed{ }
struct MsgComPortOpened{ }
struct MsgComPortDestroy{ }

private void comPortWorker(shared ComPort owner_){
  auto owner = cast()owner_; //nasty hack

  import core.thread, std.concurrency;
  Thread.getThis.isDaemon = true;

  //local things
  ComPortSettings settings;
  size_t openedConfig; //change detection hash
  HANDLE hCom;
  Time tLastFailedOpen=0*second;
  string lastError;

  bool enabled(){ return settings.enabled; }
  bool active(){ return enabled && hCom; }

  void error(string s){
    synchronized(owner){
      owner.workerHasError = true;
      owner.workerError = s;
    }
  }

  void errorClear(){ error(""); }

  void comClose(){
    openedConfig = 0;
    if(hCom){
      CloseHandle(hCom);
      hCom = null;
      errorClear;
    }
    owner.stats.opened = false;
  }

  void comOpen(){
    if(hCom) comClose;

    try{
      hCom = settings.open;

      openedConfig = settings.hashOf;
      owner.stats.opened = true;
      errorClear;
    }catch(Exception e){
      error(e.simpleMsg);
      tLastFailedOpen = QPS;
    }
  }

  while(1){
    //disabled or config changed. Just shut it down
    if(hCom && (!enabled || openedConfig!=settings.hashOf)){
      comClose;
    }

    //enabled, but not opened yet
    if(enabled && !hCom){
      if(QPS-tLastFailedOpen > .5*second) //don't try to reopen at max FPS
        comOpen;
    }

    ubyte[] inBuf, outBuf;

    if(enabled && hCom){
      //read if can
      ubyte[4096] buf;
      uint bytesRead;
      again: if(ReadFile(hCom, buf.ptr, buf.length, &bytesRead, null)){
        if(bytesRead>0){
          inBuf ~= buf[0..bytesRead]; //todo: appender???
          goto again;
        }

      }else{
        error("ReadFile: "~getLastErrorStr); //ERROR after 4 hours: The handle is invalid. (it is ok, because it was set to 0))
        comClose; //close it as it will be unable to recover anyways
      }
    }

    //communicate with master
    synchronized(owner){

      if(owner.terminated){
        owner.terminated = 2; //ack
        CloseHandle(hCom);
        break;
      }

      //latch outgoing data
      settings = owner.settings;
      outBuf = owner.outBuf;
      owner.outBuf = [];

      //latch incoming data
      if(inBuf.length){
        owner.inBuf ~= inBuf;
        owner.stats.lastIncomingDataTime = now;
        owner.stats.bytesIn += inBuf.length;
      }
    }

    if(enabled && hCom && outBuf.length){
      //write if there is something in outBuf

      uint bytesWritten;
      if(WriteFile(hCom, outBuf.ptr, cast(uint)outBuf.length, &bytesWritten, null)){
        //todo: verify bytesWritten
        synchronized(owner){ owner.stats.bytesOut += bytesWritten; }
      }else{
        error("WriteFile error: "~getLastErrorStr);
        comClose; //close it as it will be unable to recover anyways
      }
    }

    sleep(10);
  }//endless loop
}


class ComPort{ // ComPort /////////////////////////////////////////
  import std.concurrency;

  @STORED ComPortSettings settings;

  ComPortProtocol protocol;
  string prefix; //messages: Packet protocols, Application dependent prefix. both for incoming and outgoing messages.
  bool showErrors;

  protected ubyte[] inBuf, outBuf; //must synchronize

  protected string lineBuf; //messages buffer
  protected ubyte[] binaryBuf; //used in binary mode

  uint maxLineBufSize = 4096;

  //stats
  ComPortStats stats;

  protected Tid workerTid;
  protected int terminated;

  protected bool workerHasError; //latched string
  protected string workerError;

  this(){
    workerTid = spawn(&comPortWorker, cast(shared)this);
  }

  ~this(){
    terminated = 1;
    while(terminated != 2)
      sleep(1);
  }

  override string toString() const{
    with(stats) with(settings) return format!`port: %s  baud: %s  %s  errors: %s, %s  out: %s, %sB  in: %s, %sB`(
      port, baud, enabled ? active ? "Active" : "Enabled" : "Disabled",
      errorCnt, dataErrorCnt,
      messagesOut, shortSizeText(bytesOut),
      messagesIn, shortSizeText(bytesIn)
    );
  }

  private void error(string s){
    if(s==""){
      stats.lastError = "";
      stats.lastErrorTime = DateTime.init;
    }else{
      stats.errorCnt++;
      stats.lastError = s;
      stats.lastErrorTime = now;
      if(showErrors) ERR(s);
    }
  }

  @property inout ref enabled() { return settings.enabled; }

  bool opened() const { return stats.opened; }
  bool active() const { return enabled && opened; }

  // ComPort - simple message protocol /////////////////////////

  static int computeCheckSum(string s){ return (cast(ubyte[])s).sum &0xFF; }

  void send(in void[] msg){
    final switch(protocol){
      case ComPortProtocol.raw:
        outBuf ~= cast(ubyte[])msg;
      break;
      case ComPortProtocol.textPackets:
        const str = cast(string)msg;
        outBuf ~= cast(ubyte[])(format!"%s%s~%x\n"(prefix, str, computeCheckSum(str)));
        stats.messagesOut ++;
      break;
      case ComPortProtocol.binaryPackets:
        outBuf ~= cast(ubyte[])(msg) ~ cast(ubyte[])[crc32(msg)] ~ cast(ubyte[])(prefix~"\n");
        stats.messagesOut ++;
      break;
    }
  }

  private size_t lastSettingsHash;

  void receive(T)(void delegate(T) fun){
    //latch inconing data
    ubyte[] raw;
    synchronized(this){
      raw = inBuf;
      inBuf = [];

      if(chkClear(workerHasError))
        error(workerError);
    }

    if(raw.empty) return;

    void returnPacket(U)(U data){
      stats.messagesIn++;
      stats.lastIncomingMessageTime = now;

      try{
        static assert(is(T==string) || !isSomeString!T, "Only string (of char) or other nonstring types supported.");

        static if(is(T==string) && !is(U==string))
          fun((cast(string)data).safeUTF8); //make sure that the string is valid
        else
          fun(cast(T)data);

      }catch(Exception e){
        ERR("Unhandled Exception in receive().", e.simpleMsg);
      }
    }

    void processRaw(){
      returnPacket(raw);
    }

    void processBinaryPackets(){
      binaryBuf ~= raw;
      while(1){
        const idx = binaryBuf.countUntil(cast(ubyte[])(prefix~'\n'));
        if(idx<0) break;

        auto actLine = binaryBuf[0..idx];
        binaryBuf = binaryBuf[idx+prefix.length+1..$];
        if(actLine.length<4){
          stats.dataErrorCnt++;
          error("Binary message too small. Can't check crc32.");
        }else{
          const crc = (cast(uint[])actLine[$-4..$])[0];
          actLine = actLine[0..$-4];
          const crc2 = actLine.crc32;

          if(crc==crc2){
            returnPacket(actLine);
          }else{
            error("Crc error: "~prefix.quoted~" "~actLine.format!"%(%02X %)");
            stats.dataErrorCnt++;
          }
        }
      }

      if(binaryBuf.length>maxLineBufSize){ //todo: refactor: maxMessageBytes
        binaryBuf = [];
        stats.dataErrorCnt++;
        error("Receiving garbage instead of valid packages: "~prefix.quoted);
      }
    }

    void processTextPackets(){
      lineBuf = (cast(string)raw).safeUTF8;

      while(1){
        const idx = lineBuf.indexOf('\n'); //todo: variable declaration in while condition. Needs latest LDC.
        if(idx<0)break; //todo: if no \n received after a timeout, that's an error too.
        const actLine = lineBuf[0..idx];
        lineBuf = lineBuf[idx+1..$];

        //check msg checkSum
        const cIdx = actLine.retro.indexOf('~');

        if(actLine.startsWith(prefix) && cIdx>0){
          const
            msg = actLine[prefix.length..$-cIdx-1],
            crc = actLine[$-cIdx..$],
            crc2 = computeCheckSum(msg).format!"%x";

          if(crc==crc2){
            returnPacket(msg);
          }else{
            error("Crc error: "~msg.quoted);
            stats.dataErrorCnt++;
          }
        }else{
          stats.dataErrorCnt++;
          error("Invalid package format: "~actLine.quoted);
        }
      }

      if(lineBuf.length>=maxLineBufSize){
        lineBuf = [];
        stats.dataErrorCnt++;
        error("Receiving garbage instead of valid packages: "~prefix.quoted);
      }
    }

    final switch(protocol){
      case ComPortProtocol.raw          : processRaw            ; break;
      case ComPortProtocol.binaryPackets: processBinaryPackets  ; break;
      case ComPortProtocol.textPackets  : processTextPackets    ; break;
    } //end switch
  }

  bool thereWasAnError() const{ return stats.lastErrorTime > stats.lastIncomingMessageTime; }

  bool thereWasAMessage(in Time since=9999*second, in Time blink=0*second) const{
    if(thereWasAnError) return false;
    const t = stats.lastIncomingMessageTime,
          t0 = now;
    return t && t>=t0-since && t<t0-blink;;
  }

  void UI(string title = "", void delegate() fun = null){ import het.ui; with(im){ //UI //////////////////////////////////////

    Row(bold(title=="" ? "Serial Communication" : title), "  ", {
      ChkBox(this.enabled, "Enabled");  //todo: enabled conflicts with im.enable

      Text("  ");

      Row({ Led(opened, clLime); Text("Open"); });

      Text("  ");

      Row({
        if(!this.enabled) Led(false, clGray);
        else if(thereWasAnError) Led(true, clRed); //note: toSeconds needed for nan->0
        else Led(thereWasAMessage(1*hour, (1.0f/20)*second), clLime);
        Text("Comm");
      });

      Text("  ");

      if(fun) fun();
    });

    Row({
      Text("Port\t");
      Edit(settings.port, { width = fh*3; });

      static bool choosePort;
      if(!choosePort){
        if(Btn("...")) choosePort = true;
      }else{
        Text(" Select ");
        foreach(p; comPorts.existingPorts){
          if(Btn(p.name, selected(sameText(p.name, settings.port)), hint([p.description, p.deviceId].join(' ')), genericId(p.id))){
            settings.port = p.name;
            choosePort = false;
          }
        }
        if(Btn("\u25C0", hint("Cancel Serial Port selection."))) choosePort = false;
      }
    });

    Row("Stats\t", {
      Static(toString.split(" ")[2..$].join(" "));
    });

    Row("Error\t", {
      Static(stats.lastError=="" ? " " : stats.lastError, { /*flex = 1;*/ });
      if(Btn("Clear")) stats.lastError = "";
    });

    //todo: statistics
  }}
}


class ComPortInfo{ //ComPortInfo //////////////////////////////////////////////////

  enum Parity { none, odd, even, mark, space}  enum ParityLetters = ["N","O","E","M","S"];
  enum StopBits { one, onePointFive, two }     enum StopBitStrings = ["1", "1.5", "2"];
  enum ComPortState { offline, online, createError, writeError }

  mixin template ReadonlyField(T, string name, string _default="$.init"){
    mixin( "private $ _*=#; @property auto *() const{ return _*; }".replace('#', _default).replace('$', T.stringof).replace('*', name) );
  }

  mixin ReadonlyField!(int      , "id");
  mixin ReadonlyField!(bool     , "exists");
  mixin ReadonlyField!(string   , "description");
  mixin ReadonlyField!(string   , "deviceId");

  @property string name() const{ return "COM"~id.text; }

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

    void config(string s){  //todo: refactor com port config
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
      return format!`ComPort(COM%s, %s, %s, config="%s", description="%s", deviceId="%s")`(id, exists ? "exists" : "absent", state.text, config, description, deviceId);
    }

  }

}

class ComPorts{ // ComPorts //////////////////////////////////////////////////////////
  enum totalPorts = 32;

  ComPortInfo[] ports;

  auto opIndex(int idx){ return ports.get(idx-1); }

  auto existingPorts() { return ports.filter!("a.exists"); }

  //cache some registry keys
  //private __gshared static Key regKeyPortConfig_read, regKeyPortConfig_write;

  static Key regKeyPortConfig      (){ return Registry.localMachine.getKey(`Software\Microsoft\Windows NT\CurrentVersion\Ports`); }
  static Key regKeyPortConfig_write(){ return Registry.localMachine.getKey(`Software\Microsoft\Windows NT\CurrentVersion\Ports`, std.windows.registry.REGSAM.KEY_ALL_ACCESS); }

  this(){
    //create ports
    ports = iota(totalPorts).map!(i => new ComPortInfo(i+1)).array;

    updateDeviceInfo;

    import std.concurrency : spawn;
    spawn(&worker);
  }

  override string toString() const{
    return ports.map!text.join("\n");
  }

  static void worker(){
    while(1){
      sleep(1000);
      comPorts.updateDeviceInfo; //below 1ms
    }
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

    static void set(ComPortInfo p, bool exists, string description="", string deviceId=""){
      p._exists      = exists     ;
      p._description = description;
      p._deviceId    = deviceId   ;
    }

    //unplugged ports
    int[] unplugged;
    foreach(p; ports){
      if(p.id !in portMap){
        unplugged ~= p.id;
        set(p, false);
      }
    }

    int[] plugged, replugged;
    foreach(i; portMap.keys){
      auto p = ports[i-1];
      auto pd = portMap[i];
      if(!p.exists){
        set(p, true, pd.name, pd.deviceId);
        plugged ~= i;
      }else if(p.description != pd.name || p.deviceId != pd.deviceId){
        set(p, true, pd.name, pd.deviceId);
        replugged ~= i;
      }
    }

    auto changed = plugged.length || unplugged.length || replugged.length;
    //todo: process changes
  }

}

alias comPorts = Singleton!ComPorts;


