module het.com;

import het.utils;

import std.windows.registry,
       core.sys.windows.winbase,
       core.sys.windows.winnt,
       core.sys.windows.basetsd : HANDLE;


class ComPort{ // ComPort /////////////////////////////////////////
  enum InputBufferSize = 4096;


  string port;
  int baud = 9600;
  string config = "8N1";
  bool enabled;
  bool showErrors;

  ubyte[] inBuf, outBuf;

  bool binary; //select message protocol

  protected string lineBuf; //messages buffer
  protected ubyte[] binaryBuf; //used in binary mode

  uint maxLineBufSize = 4096;

  string prefix; //messages: Application dependent prefix. both for incoming and outgoing messages.

  //stats
  size_t messagesOut, bytesOut, messagesIn, bytesIn, errorCnt, dataErrorCnt;
  string lastError;

  void resetStats(){
    foreach(a; AliasSeq!(messagesOut, bytesOut, messagesIn, bytesIn, errorCnt, dataErrorCnt)) a=0;
    lastError="";
  }

  override string toString() const{
    return format!`port: %s  baud: %s  %s  errors: %s, %s  out: %s, %sB  in: %s, %sB`(
      port, baud, enabled ? active ? "Active" : "Enabled" : "Disabled",
      errorCnt, dataErrorCnt,
      messagesOut, shortSizeText(bytesOut),
      messagesIn, shortSizeText(bytesIn)
    );
  }

  protected{
    HANDLE hCom;
    double tLastFailedOpen=0;

    void error(string s){
      errorCnt++;
      lastError = s;
      if(showErrors) ERR(s);
    }

    void comClose(){
      CloseHandle(hCom);
      hCom = null;
      inBuf = [];
      outBuf = [];
      lineBuf = "";
      binaryBuf = [];
    }

    void comOpen(){
      comClose;

      try{
        enforce(config.sameText("8N1"), "Only 8N1 supported");

        auto s = port;
        if(s.uc.startsWith("COM") && s.length>4) s = `\\.\`~s;

        auto h = CreateFile(s.toPWChar, GENERIC_READ | GENERIC_WRITE, 0, null, OPEN_EXISTING, 0, null);
        if(h == INVALID_HANDLE_VALUE)
          raise("Can't open serial port "~s.quoted~" "~getLastErrorStr);

        hCom = h;
        DCB dcb;
        if(!GetCommState(hCom, &dcb)) raise("GetComState", getLastErrorStr);
        with(dcb){
          BaudRate = baud;
          Parity = 0; //One
          StopBits = 0; //None
          ByteSize = 8;
          _bf = 0;
        }
        if(!SetCommState(hCom, &dcb)) raise("SetComState", getLastErrorStr);

        COMMTIMEOUTS ct;
        with(ct){
          ReadIntervalTimeout = 0xFFFFFFFF;
          ReadTotalTimeoutMultiplier = 0;
          ReadTotalTimeoutConstant = 0;
          WriteTotalTimeoutMultiplier = 1;
          WriteTotalTimeoutConstant = 500;
        }
        if(!SetCommTimeouts(hCom, &ct)) raise("SetComTimeouts", getLastErrorStr);

        lastError = "";
      }catch(Exception e){
        error(e.simpleMsg);
        tLastFailedOpen = QPS;
      }
    }

  }

  bool opened() const { return hCom !is null; }
  bool active() const { return enabled && opened; }

  bool write(in ubyte[] msg){ //low level write. Skips outBuf.
    if(!active) return false;

    uint bytesWritten;
    if(WriteFile(hCom, msg.ptr, msg.length.to!uint, &bytesWritten, null)){
      bytesOut += msg.length;
      return true;
    }else{
      error("WriteFile error: "~getLastErrorStr);
      comClose; //close it as it will be unable to recover anyways
      return false;
    }
  }

  void update(){

    //disabled. Just shut it down
    if(!enabled && hCom){
      comClose;
      lastError = "";
    }

    //enabled, but not opened yet
    if(enabled && !hCom){
      if(QPS-tLastFailedOpen > .5f) //don't try to reopen at max FPS
        comOpen;
    }

    if(enabled && hCom){

      //write if there is something in outBuf
      if(outBuf.length){ write(outBuf); outBuf=[]; }

      //read if can
      ubyte[InputBufferSize] buf;
      uint bytesRead;
      if(ReadFile(hCom, buf.ptr, buf.length.to!uint, &bytesRead, null)){
        if(bytesRead>0){
          bytesIn += bytesRead;

          inBuf ~= buf[0..bytesRead]; //appender???
        }
      }else{
        error("ReadFile: "~getLastErrorStr); //ERROR after 4 hours: The handle is invalid. (it is ok, because it was set to 0))
        comClose; //close it as it will be unable to recover anyways
      }
    }

  }

  // ComPort - simple message protocol /////////////////////////

  static int computeCheckSum(string s){ return (cast(ubyte[])s).sum &0xFF; }

  void send(in void[] msg){
    if(binary){
      write(cast(ubyte[])(msg) ~ cast(ubyte[])[crc32(msg)] ~ cast(ubyte[])(prefix~"\n"));
    }else{
      const str = cast(string)msg;
      write(cast(ubyte[])(format!"%s%s~%x\n"(prefix, str, computeCheckSum(str))));
    }
    messagesOut ++;
  }

  void update_messages(void delegate(in void[]) fun){
    update;

    if(inBuf.length){
      if(binary){
        binaryBuf ~= inBuf;
        inBuf = [];

        while(1){
          const idx = binaryBuf.countUntil(cast(ubyte[])(prefix~'\n'));
          if(idx<0) break;

          auto actLine = binaryBuf[0..idx];
          binaryBuf = binaryBuf[idx+prefix.length+1..$];

          if(actLine.length<4){
            dataErrorCnt++;
            error("Binary message too small. Can't check crc32.");
          }else{
            const crc = (cast(uint[])actLine[$-4..$])[0];
            actLine = actLine[0..$-4];
            const crc2 = actLine.crc32;

            if(crc==crc2){
              messagesIn++;
              fun(actLine);
            }else{
              error("Crc error: "~prefix.quoted~" "~actLine.format!"%(%02X %)");
              dataErrorCnt++;
            }
          }
        }

        if(binaryBuf.length>maxLineBufSize){ //todo: refactor: maxMessageBytes
          binaryBuf = [];
          dataErrorCnt++;
          error("Receiving garbage instead of valid packages: "~prefix.quoted);
        }

      }else{
        ignoreExceptions({ lineBuf ~= (cast(char[])inBuf).text; });
        inBuf = [];

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
              messagesIn++;
              fun(msg);
            }else{
              error("Crc error: "~msg.quoted);
              dataErrorCnt++;
            }
          }else{
            dataErrorCnt++;
            error("Invalid package format: "~lineBuf.quoted);
          }
        }

        if(lineBuf.length>=maxLineBufSize){
          lineBuf = [];
          dataErrorCnt++;
          error("Receiving garbage instead of valid packages: "~prefix.quoted);
        }
      }
    }
  }

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
