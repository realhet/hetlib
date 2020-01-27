module het.gcode;

import het.utils, het.geometry, std.regex;

//todo: gcode point allocation: reserve() avg gcode line size = 29+2, but later it should be allocated from actual stats.
//todo: byGCodeWord.cache.filter! https://forum.dlang.org/post/uivanfpxxeyczbbsmwsj@forum.dlang.org

// GCode notes ///////////////////////////////////

//case insensitive

/+gcodes to implement:
  -     Ignore
  !     Alters state
  #     Alters absolute position

  G28 G161 G162      #  Homing. If no params at all then XYZ=0
  G29                -  Ignore. Detailed Z probe
  G0 G1            !!!  move XYZEAF (0 -> optimal path for travel)  ha van x vagy y vagy v vagy nincs se E, se A, akkor update feedrate, kulonben az extrusion rate nem erdekes(time pontatlansag)
  G92                #  set abs positions fo XYZEA
  G4                 -  Ignore, wait P millisecs
  G20                !  units = inches
  G21                !  units = mm
  G90                !  movement, extruder = abs
  G91                !  movement, extruder = rel
  G130               -  Ignore, stepper motor VRef, Makerbot
  G17                -  Ignore, XY plane for arcs, 3DimMaker
  G10 G11            -  Ignore, retract/prime ultimaker

  M82                !  extruder = abs
  M83                !  extruder = rel
  M106               -  Fan = S  0..255
  M107               -  Fan = 0
  M104 M109          -  ExtruderTemp = S    109: wait
  M140 M190          -  BedTemp = S         190: wait

  M17                -  Enable steppers
  M18                -  Disable steppers
  M84                -  Disable steppers until next move, (S=inactivity timeout is sec)

  //Makerbot Specific
  M70                -  P5 (We <3 Making Things!)
  M72                -  P1 (Play Ta-Da song)
  M73                -  Build percentage
  M132               -  MaqkerBot: Recall stored home offsets for XYZAB axis  //!!!!!!!!!! Makerbot uses this, shifts x,y into bed center -> don't modify gcode here
  M133               -  T0 unknown!!!  Ignore T0 as ToolHeadChange!!!
  M135               -  T0 unknown!!!  Ignore T0 as ToolHeadChange!!!
  M136 M137          -  Begin/End notification
  M126               -  Fan = 0xFF                   //T0 is not Tool here
  M127               -  Fan = 0     //non reprap     //T0 is not Tool here
  M117               -  display on lcd screen

  Tx                 !  select toolhead


Essentials:
  ; .. \n               comment, ignore.
  ( .. ) or \n          comment, ignore.
  G0 G1                 move XYZEAF (0 -> optimal path for travel)  ha van x vagy y vagy v vagy nincs se E, se A, akkor update feedrate, kulonben az extrusion rate nem erdekes(time pontatlansag)

Important Rares:
  G28 G161 G162         Homing If no params at all then XYZ=0
  G92                   Set absolute AEXYZ

Mode changers:
  G20                !  units = inches
  G21                !  units = mm
  G90                !  movement, extruder = abs
  G91                !  movement, extruder = rel
  M82                !  extruder = abs
  M83                !  extruder = rel
  Tx                 !  select toolhead   (must check the M before M133 M135)

+/

// GCode utils ///////////////////////////////////////////////////////

template LetterMask(string s){ enum LetterMask = s.map!(ch => 1u<<((cast(int)ch)&31)).sum; }

// SegType ///////////////////////////////////////////////////////////

enum SegType : ubyte { Unknown, Travel, Perimeter, Loop, HShell, Infill, Support, SoftSupport, Skirt, Raft, OuterHair, InnerHair }

auto toSegType(string s) pure{ with(SegType){
  struct KV{ SegType k; string[] v; } enum KV[] kv =[  //todo: skeinforge "(<boundaryPoint*"
    {Unknown    , ["Unknown"]},
    {Travel     , ["Travel"]},
    {Perimeter  , ["Perimeter", "WALL-OUTER", "Outline", "edge"]},
    {Loop       , ["Loop", "WALL-INNER", "Inset"]},
    {HShell     , ["HShell", "SKIN", "Infill", "Solid"]},
    {Infill     , ["Infill", "FILL", "Sparse", "Stacked"]},
    {SoftSupport, ["SoftSupport", "Support I"]},  //order is important -> Before Support.
    {Support    , ["Support"]},                   //order !!!
    {Skirt      , ["Skirt"]},
    {Raft       , ["Raft", "Pillar", "Prime"]},
    {OuterHair  , ["OuterHair"]},
    {InnerHair  , ["InnerHair", "Crown", "thin perimeters"]},
  ];

  if(s.length>100) return Unknown;
  while(s.length && "(;< ".canFind(s[0])) s = s[1..$];

  s = s.skipOver_ci("segType");

  while(s.length && "=: ".canFind(s[0])) s = s[1..$];

  foreach(i; kv) foreach(p; i.v) if(s.startsWith_ci(p)) return i.k;
  return Unknown;
}}

unittest{
  assert(SegType.SoftSupport == ";(< support inter".toSegType);
}

// GCodeWordSplitter /////////////////////////////////////////////////

struct GCodeWord{
  float value=0;
  char code='\0';

  auto toString() const{
    return format!"%s%s"(code, value);
  }

  bool valid() const{ return code!=0; }
}

auto toGCodeWord(string s) pure{
  //s must be not empty

  //command processing to extract segType
  if(s[0].among(';', '(')){
    auto st = toSegType(s).to!int;
    if(st) return GCodeWord(s.toSegType.to!int, ';'); //SegType
      else return GCodeWord();
  }

  return GCodeWord(s[1..$].to!float, s[0].asciiUpper);
}

auto byGCodeWord_slow(string gcode){
  //BbEeFfGgXxYyZzMmPpSsTt
  auto rxGCodeWord = ctRegex!(`(?:[A-Za-z](?:-|\+)?(?:\d+)(?:\.\d+)?)|(?:;.*)|(?:\(.*\))`, `gm`); //this version has non-reporting groups.
//auto rxGCodeComment = ctRegex!(`;(.*)|\((.*)\)`, `gm`); //gets the comments without comment chars: ();
  return gcode.matchAll(rxGCodeWord).map!(a => a[0].toGCodeWord);
}

// GCodeSentence ////////////////////////////////////////////////

float[32] _gcodeValues; //global result of fetchGCodeSequence()

uint fetchGCodeSentence(R)(ref R r) if(isInputRange!R && is(ElementType!R == GCodeWord)){
  enum commandMask = "GMT".map!(i => 1<<(i&31)).sum;

  uint res = 0;
  static foreach(pass; 0..2){ //pass0: fetch the first command,  pass1: fetch while not command
    while(!r.empty){
      auto act = r.front,  slot = act.code & 31,  mask = 1<<slot;  //peek
      static if(pass==1) if(mask & commandMask) break; //pass1: this is the next command, don't pop it, just break
      res |= mask;  _gcodeValues[slot] = act.value;  r.popFront;   //consume
      static if(pass==0) if(mask & commandMask) break; //pass0: got the command, go to next stage
    }
  }
  return res & ~1; //ignore 0's produced by the gcode word decoder (non-segtype comments)
}

string gcodeSentenceToStr(uint mask, bool onlyCodes=false){
  auto r = `NGMT@XYZABCDEFHIJKLOPQRSUVW[\]^_`.map!(ch => (cast(int)ch)&31).filter!(i => 1<<i & mask);

  return onlyCodes ? r.map!(i => format!"%s"(cast(char)(i+0x40))).join
                   : r.map!(i => format!"%s%s"(cast(char)(i+0x40), _gcodeValues[i].text) ).join(' ');
}

auto byGCodeSentence(R)(R r) if(isInputRange!R && is(ElementType!R == GCodeWord)){
  static struct ByGCodeSentence{
    enum dbg = 0;
    private { R r;  uint act; }

    this(R r){
      version(dbg) "new".print;
      this.r = r;
      popFront;
    }

    bool empty() const{
      version(dbg) "empty".print;
      return !act;
    }

    uint front(){
      version(dbg) "front".print;
      return act;
    }

    void popFront(){
      version(dbg) "pop'".print;
      act = r.fetchGCodeSentence;
    }
  }

  return ByGCodeSentence(r);
}


unittest{
  auto gcode =`m190s69
    m109s222
    g28x0y0
    g28z0
    g21
    g90
    g92e0
    m106s0
    g1e10f500
    (segType:perimeter)g92(comment2)e0(comment3);comment4
    g1z0f5000 ;comment5
    M127 T0
    T1
    M126 T0
    T2
    G0 F500
    G0 X160.000 Y100.000 Z0.300
    G0 X160.000 Y100.000 Z0.200
    ; segType:Perimeter
    G0 X160.400 Y100.400 Z0.200
    G1 X139.600 Y100.400 Z0.200 E0.74982
    G1 X139.600 Y79.600 Z0.200 A1.49964
    G1 X160.400 Y79.600 Z0.200 E2.24946`;

  assert(gcode.byGCodeWord_slow.byGCodeSentence.map!(s => s.gcodeSentenceToStr(true)).join('\n').xxh==2129184341, "gcode sequence test fail.");
}


// GCodeCompressedPoint /////////////////////////////////////////////////
struct GCodeCompressedPoint {                                     //compressed size
  V3f V;                                                //6 byte
  ubyte logWidth, logHeight, logSpeed, lenPhase;        //4 byte
  SegType segType; ubyte toolHead;                      //1 byte


//  @property float speed(){ return logSpeed ? 2.0f^^(logSpeed*(1.0f/16)-8) : 0; }
//  @property void  speed(float a){ logSpeed = cast(ubyte)(iRound(log2(a)*16).clamp(1, 255)); } //opt: fastLog

  @property float width(){ return logSpeed ? 2.0f^^(logWidth*(1.0f/16)-8) : 0; }
  @property void  width(float a){ logSpeed = cast(ubyte)(iRound(log2(a)*16).clamp(1, 255)); } //opt: fastLog

  @property float height(){ return logSpeed ? 2.0f^^(logSpeed*(1.0f/16)-8) : 0; }
  @property void  height(float a){ logSpeed = cast(ubyte)(iRound(log2(a+8)*16).clamp(1, 255)); } //opt: fastLog
}


struct GCodePoint{ float X, Y, Z, E; }  // GCodePoint /////////////////////////////////


struct GCodeBlockData{ // GCodeBlockData ////////////////////////////////////
  GCodePoint actPoint;
  GCodePoint[] points;

  SparseArray!(int, bool) inches, relMove, relExtr;
  SparseArray!(int, float, 0) homeX, homeY, homeZ, absX, absY, absZ, absE;
  SparseArray!(int, int) toolHead, fan, bedTemp, headTemp, feedRate, wait;

  void interpret(int idx, uint mask){ //uses global _gcodeValues

    bool has(string m)(){ return (mask & LetterMask!m) == LetterMask!m; }
    bool hasOnly(string m)(){ return (mask & ~LetterMask!m) == 0; }
    float fVal(char ch)(float def=0){ return has!([ch]) ? _gcodeValues[ch&31] : def; }
    int   iVal(char ch)(float def=0){ return fVal!ch(def).iFloor; }
    void unknown(){ INFO("Unknown gcode sentence: ", mask.gcodeSentenceToStr); }

    while(points.length<idx) points ~= actPoint; //catch up idx

    if(false && has!"GXY" && hasOnly!"GXYZEF" && fVal!'G'<2){ //FastPath G0, G1.  E, F, Z is optional

    }else{
      if(has!"G"){
        switch(iVal!'G'){
          case 0: case 1: { //move
            GCodePoint p;
            bool move, extr;

            if(has!"X"){ actPoint.X = fVal!'X'; move = true; }
            if(has!"Y"){ actPoint.Y = fVal!'Y'; move = true; }
            if(has!"Z"){ actPoint.Z = fVal!'Z'; move = true; }
            if(has!"E"){ actPoint.E = fVal!'E'; extr = true; } else if(has!"A") { actPoint.E = fVal!'A'; extr = true; }

            if((move || !extr) && has!"F") feedRate[idx] = iVal!'F'; //feedrate is when move OR NOT extrude
          break;}

          case 28: case 161:{ /*case 162:*/ //(homing, min, max)
            const any = has!"X" || has!"Y" || has!"Z";
            if(!any){
              homeX[idx] = homeY[idx] = homeZ[idx] = 0;
            }else{
              if(has!"X") homeX[idx] = fVal!'X';
              if(has!"Y") homeY[idx] = fVal!'Y';
              if(has!"Z") homeZ[idx] = fVal!'Z';
            }
          break;}

          case 92:{  //set abs positions
            if(has!"X") absX[idx] = fVal!'X';
            if(has!"Y") absY[idx] = fVal!'Y';
            if(has!"Z") absZ[idx] = fVal!'Z';
            if(has!"E") absE[idx] = fVal!'E'; else if(has!"A") absE[idx] = fVal!'A';
          break;}

          case 4: {
            wait[idx] = iVal!'P'; //wait millisecs
          break;}

          case 20: inches[idx] = true ; break;
          case 21: inches[idx] = false; break;
          case 90: relExtr[idx] = relMove[idx] = false; break;
          case 91: relExtr[idx] = relMove[idx] = true ; break;

          case 162: break; //Homing max
          case 29: break; //detailed Z probe... just ignore it
          //Makerbot Specific
          case 130: break;  //Set stepper motor VRefs
          //3DimMaker Specific
          case 17: break;  //Select XY plane for acrs
          case 197: break;  //CB pause
          case 10: case 11: break; //Ultimaker retract/prime

          default: unknown;
        }
      }else if(has!"M"){
        switch(iVal!'M'){
          case 82: relExtr[idx] = false; break;
          case 83: relExtr[idx] = true ; break;

          //Fan
          case 106: { //Fan ON  (works with floats too)
            auto tmp = fVal!'S'(255);
            if(tmp.inRange(0.00001f,1.0f)) tmp *= 255;
            fan[idx] = tmp.iRound.clamp(0, 255);
          break;}

          case 107: fan[idx] =   0; break; //Fan Off

          //Heating
          case 104: case 109: print(idx, iVal!'S'(headTemp[idx]));     headTemp[idx] = iVal!'S'(headTemp[idx]); break; //109: +wait
          case 140: case 190: bedTemp [idx] = iVal!'S'(bedTemp [idx]); break; //190: +wait

          //Makerbot Extruder ValveFan ON/OFF
          case 126: case 127: toolHead[idx] = -1; break;  //mark toolhead that an invalid value will follow
          //todo: fix toolhead: ignore toolheadchanges after -1 (M126, M127 marks -1)

          default:
        }
      }else if(has!"T"){
        toolHead[idx] = iVal!'T';
      }else{
        unknown;
      }
    }

    points ~= actPoint; //always append, as every point is mapped to every sentence
  }

}


class GCodeBlock{ // GCodeBlock //////////////////////////////////////////////////
  enum GCodeBlockState {
    Empty,     //just created
    Loaded,    //loaded from file
    Converted, //ready to upload to gpu
    Uploaded   //can be drawn
  }

  GCodeBlockState state;

// Empty ------------------------------------

  File file;
  size_t filePos;
  int idx;

  this(in File file, size_t filePos, int idx){
    this.file = file;
    this.filePos = filePos;
    this.idx = idx;

    state = GCodeBlockState.Empty;
  }

// Loaded ------------------------------------
  ubyte[] text;
  void loadFrom(ubyte[] text){
    this.text = text;
    state = GCodeBlockState.Loaded;
  }

// Converted ---------------------------------
  GCodeBlockData data;
  void convert(){
    assert(state==GCodeBlockState.Loaded);
    scope(exit) state = GCodeBlockState.Converted;


  }



  //uploaded
}

struct GCodeLoaderStats{
  float loadedPercent = 0;

  float loadWorkTime = 0;
  float loadIdleTime = 0;

  void reset(){ this = this.init; }
}

enum GCodeLoaderState { Idle, Loading, Canceled, Success }

class GCode{ // GCode main class ///////////////////////////////////////////////////////////
  enum MaxBlockSize = 1<<20;

  //file operations
  File file;

  int numThreads = 1;
  auto state = GCodeLoaderState.Idle;

  GCodeLoaderStats stats;

  GCodeBlock[] blocks;
  bool blocksLoaded;

  public static void loadBlocksWorker(GCode gcode){
    gcode.loadBlocks();
  }

  private void loadBlocks(){
    assert(state == GCodeLoaderState.Loading);

    blocks = [];

    import std.parallelism;

    size_t pos; int idx;
    foreach(buf; taskPool.parallel(file.byLineBlock(10<<20).map!(b => b.read))){
      LOG(format("%X %s", buf.length, buf[$-20..$]));

      auto b = new GCodeBlock(file, pos, idx);
      b.loadFrom(buf);
      pos += buf.length; idx++;

      synchronized(this)
        blocks ~= b;
    }

    enforce(blocks.map!(b => b.text.length).sum == file.size, "GCode BlockReader: sum of blockSize test failed.");

    LOG("GCode file blockLoader Successful", GetNumberOfCores);
    blocksLoaded = true;
  }

  this(in File file){
    this.file = file;
  }

  private void waitWorkers(){
    //todo
  }

  void reset(){
    cancel;
    stats.reset;
    blocksLoaded = false;
  }

  void load(/*int maxThreads*/){
    reset;

/*    numThreads = maxThreads.clamp(1, GetNumberOfCores);
    if(numThreads<=1){

    }else{
      cancel = false;
      numThreads =


    }*/
    //todo: multithread

    state = GCodeLoaderState.Loading;

    //loadBlocks;

    blocksLoaded = false;
    import std.parallelism;
    auto t = task!loadBlocksWorker(this);
    t.executeInNewThread;

    while(1){
      synchronized(this){

      }
      break;
    }

    foreach(i; 0..10){
      sleep(100);
      LOG("main thread waiting");
      if(blocksLoaded) break;
    }
    LOG("main thread done");
  }

  void cancel(){
    if(state==GCodeLoaderState.Loading){
      state = GCodeLoaderState.Canceled;
      waitWorkers;
    }
  }

}



////////////////////////////////////////////////
// GCode analytics                            //
////////////////////////////////////////////////

void makeGCodeStats(){ makeGCodeStats(Path(`c:\!gcodes`).files(`*.*`)); }

void makeGCodeStats(in File[] files){

  size_t actSize, totalSize = files.map!"a.size".sum;

  float parseTime = 0; //parser stats
  float parseMB = 0;
  size_t parseSentence;

  size_t[256] charProbability; //probability of ascii chars
  size_t[string] patternMap;
  size_t[string] commentMap;
  size_t[string] sentenceMap;
  enum MaxStringLen = 48;

  void processLine(string line){
    try{
      static cnt=0; if(((cnt++) &((32<<10)-1))== 0) write('.');

      //replace all numbers with 0
      line = cast(string)(line.map!(ch => ch.isDigit ? '0' : cast(char)ch).array);

      //process comments
      enum rxGCodeComment = ctRegex!(`;(.*)|\((.*)\)`, `gm`); //gets the comments without comment chars: ();
      line.matchAll(rxGCodeComment)
          .each!((c){ commentMap[c[0].truncate(MaxStringLen)]++; });

      //remove comments
      line = line.replaceAll(rxGCodeComment, "()"); //strip comments

      //char probability
      foreach(i; 0..line.length) charProbability[cast(ubyte)(line[i])]++;
      charProbability['\n']++; //newline

      patternMap[line.truncate(MaxStringLen)]++;
    }catch(Throwable){
      patternMap["!!!! UNICODE ERROR !!!!"]++;
    }
  }

  void processSentence(uint mask){
    auto s = gcodeSentenceToStr(mask, true);

    static foreach(ch; ["G", "M", "T"])
      if(mask & LetterMask!ch)
        s = ch ~ _gcodeValues[ch[0]&31].text ~ " " ~ s.replace(ch, "");

    sentenceMap[s]++;
  }

  // do the statistics
  foreach(f; files){
    write(f);
    auto text = f.readStr;

    //do the pattern/character analysis
    text.split('\n').each!(line => processLine(line));

    //process it using the gcode parser
    try{
      auto t0 = QPS;
      int cnt;

      text.byGCodeWord_slow.byGCodeSentence.each!((s){ processSentence(s); cnt++; });

      parseTime += QPS-t0;
      parseMB += text.length.to!float/(1<<20);
      parseSentence += cnt;
    }catch(Throwable){}

    actSize += f.size;
    print("  ", f.name, (actSize*100/totalSize).text~'%');
  }

  //save/display the results
  string saveMap(size_t[string] m){
    auto total = m.values.sum;
    return m.byKeyValue.array
            .sort!((a, b) => a.value > b.value)
            .map!(i => "%d\t%4.1f%%\t%s".format(i.value, i.value.to!float/total*100, i.key))
            .join("\n");
  }

  string res;
  res ~= format!"GCode statistics\n  Number of files: %d\n  Total size: %7.3f MB\n"(files.length, totalSize.to!float/(1<<20));
  res ~= format!"  sentences: %d\n  parseTime: %f sec\n  parse speed:    %10.3f MB/s\n  sentence speed: %10.3f MSentence/s\n"(parseSentence, parseTime, parseMB/parseTime, parseSentence/1024.0/1024/parseTime);

  res ~= "\n\nCharacter map in 1/1000 units\n";
  auto totalProbability = charProbability[].sum;
  foreach(y; iota(16)){
    foreach(x; iota(16)){
      int i = y+x*16;
      res ~= format!"| %s:%4s "(cast(char)(i>=32 && i<=127 ? i : 64), charProbability[i] ? format!"%4d"(charProbability[i]*1000/totalProbability): "");
    }
    res ~= "\n";
  }

  res ~= "\n\nCount\tSentence\n"~saveMap(sentenceMap);
  res ~= "\n\nCount\tPattern\n"~saveMap(patternMap);
  res ~= "\n\nCount\tComment\n"~saveMap(commentMap);

  writeln(res);
  File("GCodeStats.txt").write(res);
}


////////////////////////////////////////////////
// Test course                                //
////////////////////////////////////////////////


string gcodeTestCourse(){
  string[] res = ["; GCODE TestCourse", ";"];
  V3f lastPos;
  float lastE=0;
  float EW = 0.4;
  float LH = 0.2;

  void moveTo3(in V3f v, float dE = 0){
    if(lastPos == v) return;
    res ~= dE ? format!"G1 X%f Y%f Z%f E%f F4000"(v.x, v.y, v.z, lastE+dE)
              : format!"G0 X%f Y%f Z%f F4000"(v.x, v.y, v.z);  //todo: only write the changes for better testing of gcode parser
    lastPos = v;
    lastE += dE;
  }

  void lineTo3(in V3f v){
    if(lastPos == v) return;
    moveTo3(v, (lastPos-v).len_prec * (EW*LH) / ((1.75/2)^^2 * PI));
  }

  void moveTo(in V2f v){ moveTo3(V3f(v.x, v.y, lastPos.z)); }
  void lineTo(in V2f v){ lineTo3(V3f(v.x, v.y, lastPos.z)); }

  void text(in V2f pos, string text, float scale){
    import het.fonts;
    auto strokes = plotFont.drawTextStrokes(pos, text, scale/plotFont.fontHeight, [DrawTextOption.vertFlip]);

    //auto points = strokes.join;

    foreach(stroke; strokes){
      foreach(int idx, point; stroke){
        if(idx==0) moveTo(point);
              else lineTo(point);
      }
    }
  }

  //////////////////////////////////////////////////////////////////

  moveTo3(V3f(0, 0, LH));

  void testCorners(float len, float step, float z=0){
    auto angles = iota(0.0f, 180.1f, step).array;
    angles = angles[1..$].retro.map!"-a".array ~ angles;

    auto p0 = lastPos.xy;
    auto z0 = lastPos.z;
    foreach(int i, a; angles){
      auto o = p0 + V2f(len*i+len, len);

      moveTo3(V3f(o.x, o.y, z0));
      lineTo(lastPos.xy + V2f(0, len));
      auto tmp = lastPos.xy + V2f(0, len/2).vRot(a.toRad);
      lineTo3(V3f(tmp.x, tmp.y, z0+z));

      text(o, a.text, 2.5);
    }

    moveTo3(V3f(p0.x, p0.y+len*3, z0));
  }

  void testFill(){
    auto p0 = lastPos.xy;
    auto lastEW = EW;

    auto p = p0;
    for(float f = 0.5; f<1.5; f *= 1.01){
      EW = f*lastEW;

      moveTo(V2f(lastPos.x+EW, p0.y+5));
      lineTo(V2f(lastPos.x, p0.y+20 + (abs(f-1)<0.012 ? 5:0)));
    }

    moveTo(V2f(p0.x, p0.y+30));
    EW = lastEW;
  }

  void testChangingEW(){
    moveTo(V2f(0, lastPos.y+5));
    auto EW0 = EW;
    for(float i=0.3; i<2; i *= 1.2){
      moveTo(V2f(0, lastPos.y+EW0*2));

      for(float f = 1.5; f>0.2; f /= (1 + i^^2*0.2)){
        EW = EW0*f;
        lineTo(V2f(lastPos.x + EW0*2, lastPos.y));
      }
    }

    EW = EW0;
    moveTo(V2f(0, lastPos.y+5));
  }

  testCorners(10, 15); //todo: bug: nem latszik a legelso vonal, ha ez a legelso teszt
  testCorners(10, 15, 5);
  testCorners(10, 15, 15);
  testFill;
  testChangingEW;

  return res.join("\n");
}