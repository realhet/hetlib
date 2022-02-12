module het.mcu;

import het, het.ui;

// WireColor //////////////////////////////////////////////////////////////////

RGB toWireColor(string s){
  static RGB[string]map;  if(!map) map = [
    "white"  : clWhite,
    "black"  : clBlack,
    "grey"   : RGB(183, 183, 183),
    "brown"  : RGB(120, 63, 4),
    "blue"   : RGB(17, 85, 204),
    "red"    : RGB(255, 16, 0),
    "orange" : clOrange,
    "yellow" : clYellow,
    "green"  : RGB(51, 204, 51),
    "pink"   : RGB(234, 153, 153),
    "violet" : RGB(103, 78, 167),
  ];

  return *enforce(s.lc in map, "unknown wire color: "~s.quoted);
}

/// Displays a wire color with it's name
@UI void ColorRow(string colorName, float hScale = 1){ with(im){
  if(colorName.isWild("*-*")){
    Column({
      const c0 = wild[0], c1 = wild[1];
      ColorRow(c0, .5);
      ColorRow(c1, .5);
    });
  }else{
    Row({
      if(hScale==1){
        border = "1 normal gray";
        border.inset = true;
      }
      outerWidth = 52;
      style.bkColor = bkColor = colorName.toWireColor;
      style.fontColor = blackOrWhiteFor(bkColor); flags.hAlign = HAlign.center;
      fh = fh*hScale;
      Text(colorName);
    });
  }
}}


struct ConnectorInfo{// ConnectorInfo ///////////////////////////////////////
  enum Type{ Unknown, Wire, DSub, DSubHD, M12 }
  Type type;
  ubyte numPins;
  bool isMale, isFemale;

  //view parameters
  bool backSide, rot90, rot180;

  bool valid;

  @property hasGender() const{ return isMale || isFemale; }

  string toString() const{
    if(!valid || type==Type.Unknown) return "";

    auto res = type.text;
    if(numPins) res ~= " " ~ numPins.text ~ "pin";
    if(isMale) res~= " M";
    if(isFemale) res~= " F";

    return res;
  }

  vec2 baseSize() const{
    if(!valid) return vec2(0);

    with(Type) return type.predSwitch(
      DSub   , vec2(numPins/2*2+4, 5),
      DSubHD , numPins==78 ? vec2(43, 9) : vec2(numPins/3*2+5 + (numPins%3==0 ? -1 : 0) , 7),
      M12    , vec2(numPins<=5 ? 7.5 : numPins<=8 ? 9.5 : 10),
      vec2(0)
    );
  }

  enum unitFromFh = 0.5f;
  enum fontScale = 0.88f;

  vec2 transformedSize(float fh) const{
    auto s = baseSize;
    if(rot90) s = vec2(s.y, s.x);
    return s*(fh*unitFromFh);
  }

  void draw(Drawing dr, float fh, in string[string] pinColorMap = null) const{
    // Draws the schematic aligned to the top left. Use calcSize() to get the size and align.
    // Drawing size depends on fontHeight
    const
      unit = fh*unitFromFh,
      size = transformedSize(fh),
      uSize = baseSize*unit,
      center = size*.5f;

    vec2 tr(vec2 p){
      p -= uSize*.5f;

      if(backSide!=isMale) p.x = -p.x;
      if(rot90) p = vec2(-p.y, p.x);
      if(rot180) p = vec2(-p.x, -p.y);

      p += center;

      return p;
    }

    enum
      clOutline = clGray,
      clBody = RGB(196, 196, 212);

    dr.fontHeight = fh*fontScale;


    void drawPin(vec2 p, string label){
      string colorName = pinColorMap.get(label, "");

      RGB cRing;
      bool hasRingColor;
      if(colorName.isWild("*:*")){
        hasRingColor = true;
        cRing = wild[0].toWireColor;
        colorName = wild[1];
      }

      RGB c0, c1;
      if(colorName==""){
        c0 = c1 = clBody;
      }else if(colorName.isWild("*-*")){
        c0 = wild[0].toWireColor;
        c1 = wild[1].toWireColor;
      }else{
        c0 = c1 = colorName.toWireColor;
      }

      auto a = unit*1.8f;

      dr.color = hasRingColor ? cRing : clOutline;
      dr.pointSize = a*(hasRingColor ? 1.25f : 1.1f); //todo: intelligent point() function
      dr.point(tr(p));

      if(hasRingColor) a *= .9f;

      dr.color = c0;
      dr.pointSize = a;
      dr.point(tr(p));

      if(c1!=c0){
        dr.color = c1;
        dr.lineWidth = a*.5f;
        dr.line(tr(vec2(p.x-unit*.5f, p.y)), tr(vec2(p.x+unit*.5f, p.y)));
      }

      if(label!=""){
        dr.color = (colorName=="" ? clOutline : blackOrWhiteFor(c1));
        dr.autoSizeText(tr(p), label, 1.25f);
      }

    }


    void drawDSubBody(float rScale, float slope){
      dr.color = clBody;
      const r = unit*rScale;
      dr.lineWidth = r*2; // factor less than 2.0 -> It will have a margin.

      const sl = (uSize.y-r*2)*slope,
            a = vec2(r, r),
            b = vec2(uSize.x-r, r),
            c = vec2(a.x + sl, uSize.y-r),
            d = vec2(b.x - sl, uSize.y-r);

      dr.line(tr(a), tr(c));  dr.line(tr(b), tr(d));

      const N = iceil(uSize.y/dr.lineWidth), invN = 1.0f/N;
      foreach(i; 0..N+1){
        const t = float(i)*invN;
        dr.line(tr(mix(a, c, t)), tr(mix(b, d, t)));
      }
    }


    if(type==Type.DSub){
      const h = (numPins+1)/2;

      drawDSubBody(1, .25f);
      foreach(i; 0..h      ) drawPin(vec2(i*2+2    , 1.5)*unit, (i+1).text);
      foreach(i; h..numPins) drawPin(vec2((i-h)*2+3, 3.5)*unit, (i+1).text);
    }else if(type==Type.DSubHD){

      const t = (numPins+1)/3;

      drawDSubBody(1, .25f);
      if(numPins==50){
        foreach(i; 0..t          ) drawPin(vec2(i*2+2.5          , 1.5)*unit, (i+1).text);
        foreach(i; t..t*2-1      ) drawPin(vec2((i-t)*2+3.5      , 3.5)*unit, (i+1).text);
        foreach(i; t*2-1..numPins) drawPin(vec2((i-(t*2-1))*2+2.5, 5.5)*unit, (i+1).text);
      }else if(numPins==78){
        foreach(i; 0 ..20) drawPin(vec2((i   )*2+2.5, 1.5)*unit, (i+1).text);
        foreach(i; 20..39) drawPin(vec2((i-20)*2+3.5, 3.5)*unit, (i+1).text);
        foreach(i; 39..59) drawPin(vec2((i-39)*2+2.5, 5.5)*unit, (i+1).text);
        foreach(i; 59..78) drawPin(vec2((i-59)*2+3.5, 7.5)*unit, (i+1).text);
      }else{
        foreach(i; 0..t        ) drawPin(vec2(i*2+3      , 1.5)*unit, (i+1).text);
        foreach(i; t..t*2      ) drawPin(vec2((i-t)*2+2  , 3.5)*unit, (i+1).text);
        foreach(i; t*2..numPins) drawPin(vec2((i-t*2)*2+3, 5.5)*unit, (i+1).text);
      }
    }else if(type==Type.M12){

      //body
      dr.pointSize = size.x;       dr.color = clBody;     dr.point(tr(center));
      dr.pointSize = size.x*.15f;  dr.color = clOutline;  dr.point(tr(center-vec2(0, (size.y-dr.pointSize)/2)));

      void P(float r, float a, string label){ //polar coords
        drawPin(unit*(vec2(0, -r).rotate(-PIf*a))+center, label);
      }

      if(numPins.inRange(3, 5)){
        enum R = 2.25f;
        P(R,  .25, "1");
        P(R, 1.25, "3");
        P(R,  .75, "4");
        if(numPins>=4) P(R, 1.75, "2");
        if(numPins>=5) P(0, 0   , "5");
      }else if(numPins==8){
        enum R = 3.25f, e = .2f, N = 8;
        iota(N).each!(i => P(R, i.remap(0, N-1, e, 2-e), [1, 8, 7, 6, 5, 4, 3, 2][i].text));
      }else if(numPins==12){
        {
          enum R = 3.5f, e = .18f, N = 9;
          iota(N).each!(i => P(R, i.remap(0, N-1, e, 2-e), [1, 9, 8, 7, 6, 5, 4, 3, 2][i].text));
        }
        {
          enum R = 1.33f;
          P(R, 0   , "10");
          P(R,  .66, "12");
          P(R, 1.33, "11");
        }
      }


    }

  }
}

auto connectorInfo(string s){
  ConnectorInfo ci;
  with(ci){
    s = s.strip;

    bool chk(string[] choices...){
      const idx = choices.map!(a => s.startsWith_ci(a)).countUntil(true);
      if(idx>=0){
        s = s[choices[idx].length..$].stripLeft;
        return true;
      }
      return false;
    }

    void fetchPins(){
      ignoreExceptions({
        numPins = s.parse!ubyte;
        s = s.strip;
        chk("pins", "pin");
      });
    }

    void fetchGender(){
      isMale = chk("Male", "M");
      isFemale = chk("Female", "F");
    }

    //standard connectors: https://docs.rs-online.com/06b0/0900766b81424442.pdf
    if(chk("DSubHD", "D-SubHD", "DSub HD", "D-Sub HD")){ type = Type.DSubHD;
      fetchPins; fetchGender;
      valid = hasGender & [15, 26, 44, 50, 62, 78].canFind(numPins);
    }else if(chk("DSub", "D-Sub")){ type = Type.DSub; //do not move this IF before DSubHD!!!
      fetchPins; fetchGender;
      valid = hasGender & [ 9, 15, 19, 25, 37].canFind(numPins);
    }else if(chk("M12_", "M12")){ type = Type.M12;
      fetchPins; fetchGender;
      valid = hasGender & [3, 4, 5, 8, 12].canFind(numPins);
    }else if(chk("Wire")){ type = Type.Wire;
      fetchPins;
      valid = true;
    }

    valid &= s==""; //no remaining text allowed
  }

  return ci;
}

auto allDSubConnectors(){ return chain([9, 15, 19, 25, 37].map!`a.format!"DSub%dM"`, [15, 26, 44, 50, 62, 78].map!`a.format!"DSubHD%dM"`); }
auto allM12Connectors(){ return chain([3, 4, 5, 8, 12].map!`a.format!"M12_%dM"`); }
auto allConnectors(){ return chain(allDSubConnectors, allM12Connectors); }

// A clickable button with the connector type. Clicking shows a ConnectorPanel.

//ConnectorBtn //////////////////////////////////////////////////
@UI void ConnectorBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__, bool isWhite=false, T...)(string conn, T args)
{ with(im){

  //optional parameter
  string[string] pinColorMap;
  static if(args.length && is(T[0] == string[string]))
    pinColorMap = args[0];

  auto  ci = connectorInfo(conn);
  const hasDetail = ci.valid && ci.type!=ConnectorInfo.Type.Wire,
        bk = actContainer.bkColor;

  struct IMData{
    bool opened, genderOverride, backSide;
    int rotation;
  }

  IMData* imData;

  if(Btn!(srcModule, srcLine)({

    if(!ci.valid){ //unable to identify the connector

      Text("\U0001F50C", conn);

    }else{ //valid connector

      imData = &ImStorage!IMData.access(actContainer.id);
      if(!hasDetail) imData.opened = false;

      if(imData.opened){ // show the details

        //name, pinCount
        Text("\U0001F50C" ~ ci.type.text);
        if(ci.numPins) Text(" "~ci.numPins.text~"pin");

        // gender. Optional override.
        if(ci.hasGender){
          bool isMale = ci.isMale;
          if(imData.genderOverride) isMale.toggle;
          if(Btn({ innerWidth = fh*.7f; if(imData.genderOverride){ style.fontColor = clRed; style.bold = true; } Text(isMale ? "M" : "F"); }))
            imData.genderOverride.toggle;
        }

        // front of back. Default is front. Optional override.
        if(Btn({ innerWidth = fh*1.8f; if(imData.backSide){ style.fontColor = clRed; style.bold = true; } Text(imData.backSide ? "back" : "front"); }))
          imData.backSide.toggle;

        // 90deg rotation
        if(Btn({ innerWidth = fh*1.6f; Text(((imData.rotation&3)*90).text~"\u00b0"); }))
          imData.rotation = (imData.rotation+1)&3;

        // the actual schematic visualization
        Text("\n");
        Row({
          flags.clickable = false;
          margin = "2";

          //update orientation params
          if(imData.genderOverride) swap(ci.isMale, ci.isFemale);
          ci.backSide = imData.backSide;
          ci.rot90 = (imData.rotation&1)!=0;
          ci.rot180 = (imData.rotation&2)!=0;

          innerSize = ci.transformedSize(fh).ceil;
          auto dr = new Drawing;
          ci.draw(dr, fh, pinColorMap);
          addOverlayDrawing(dr);
        });
      }else{
        Text("\U0001F50C"~ci.text);
      }

    }
  }, args)){
    if(imData){
      imData.opened.toggle;
      if(!hasDetail) imData.opened = false;
    }else{
      WARN("Invalid connector: "~conn.quoted);
      beep;
    }
  }

}}



/// This class contains common things around an Arduino Nano controller project.
class ArduinoNanoProject{ // ArduinoNanoProject /////////////////////////////////////////////////////

  struct Wire{ // Wire ////////////////////////////////////////////////////////
    string identifier;
    int pin_A;
    string color, description;
    int pin_B;

    auto decodeIdentifier() const{
      if(identifier=="") return tuple("", "");
      identifier.isWild("*:*").enforce("Wire.identifier must be in format: pinName:variableName "~identifier.quoted); //todo: refactor these into the struct
      enforce(wild[1].startsWith("IN_") || wild[1].startsWith("OUT_"), "Wire.variableName must starts with IN_ or OUT_ "~identifier.quoted);
      return tuple(wild[0], wild[1]);
    }

    @property string pinName()      const{ return decodeIdentifier[0]; }
    @property string variableName() const{ return decodeIdentifier[1]; }
    @property bool isInput () const{ return identifier!="" &&  variableName.startsWith("IN_"); }
    @property bool isOutput() const{ return identifier!="" && !variableName.startsWith("IN_"); }


    void ui(float panelWidth) const{
      with(im) Row(YAlign.top, {
        style.bkColor = bkColor = clWhite;
        margin = "0";
        border = "1 normal gray";
        border.extendBottomRight = true;
        padding = "1 0 0 1";
        Row(HAlign.right, { width=fh; Text(pin_A ? pin_A.text:" "); });
        Text(" ");
        ColorRow(color);
        Text(" ");
        Row({ width=fh; Text(pin_B ? pin_B.text:" "); });
        Text("  ");
        Row(YAlign.top, {
          width = panelWidth;
          Row({
            flex = 1;
            if(identifier!=""){
              Text(bold(variableName), "  ");
            }
            if(description.isWild("*WARNING:*")){
              Text(wild[0]);
              const blink = QPS.fract<.5;
              style.bkColor = blink ? clRed : clWhite;
              style.fontColor = !blink ? clRed : clWhite;
              Text("\u26A0 ", bold(wild[1]));
            }else{
              if(description!="") Text(description);
              else                Text(clGray, "not connected");
            }
          });
          if(identifier!="") Row({
            Btn({ Text(pinName~" ");  Led(random(2)==0, isInput ? clLime : clRed); }, genericId(pinName));
          });
        });
      });
    }
  }

  struct Cable{ // Cable /////////////////////////////////////////////////
    string name, color, connector_A, connector_B;
    Wire[] wires;

    string[string] pinColorMap_A, pinColorMap_B;
    bool pinColorMaps_valid; //must clear when changed: pin_A, pin_B, color

    void update_pinColorMaps(){
      if(chkSet(pinColorMaps_valid)){
        pinColorMap_A = wires.filter!(w => w.pin_A && w.description!="").map!(w => tuple(w.pin_A.text, (color==""?"":color~':')~w.color)).assocArray;
        pinColorMap_B = wires.filter!(w => w.pin_B && w.description!="").map!(w => tuple(w.pin_B.text, (color==""?"":color~':')~w.color)).assocArray;
      }
    }

    void ui(float panelWidth=340) { with(im){
      CableFrame({
        flags.yAlign = YAlign.baseline;
        ColorRow(color);
        fh = 22;   Text("  ", bold(name));
        fh = 3;    Text("\n ");
        fh = 18;
        foreach(const wire; wires){
          Text("\n    ");
          wire.ui(panelWidth);
        }
        Text("\n");
        Row({
          margin = "4 0 0 0";
          fh = 18;   Text("    ");

          update_pinColorMaps;

          ConnectorBtn(connector_A, pinColorMap_A);
          Text("-");
          ConnectorBtn(connector_B, pinColorMap_B);
        });
      }, genericId(name));
    }}
  }



  Cable[] cables; //all the cables connected to the MCU

  abstract string generateProgram();


  // helper functs /////////////////////////////////////////////////////

  static bool arduinoPinLessThan(string a, string b){ //sort index for arduino pin names

    string process(string s){
      if(s.length>=2){
        dchar ch = s[0].toUpper;
        if(ch=='A') ch = 'Z';

        ubyte idx;
        ignoreExceptions({ idx = s[1..$].to!ubyte; });

        if(idx) return format!"%c%02d"(ch, idx);
      }
      return "unknown:"~s;
    }

    return lessThan(process(a), process(b));
  }


  struct PinReg{ char regName; ubyte regBit; }

  static auto getNanoPinReg(string pin){ //access port register/bit of an Arduino NANO pin
    try{

      enforce(pin.length>=2, "too short");
      const idx = pin[1..$].to!ubyte;

      if(pin[0]=='D'){
        if(idx.inRange(2,  7)) return PinReg('D', idx  ); //0, 1 is for serial!!!
        if(idx.inRange(8, 13)) return PinReg('B', cast(ubyte)(idx-8));
      }
      if(pin[0]=='A'){
        if(idx.inRange(0,  5)) return PinReg('C', idx  ); //6 is reset
      }

      raise("unhandled");

    }catch(Exception e){
      raise(format!"Invalid arduino pin: %s (%s)"(pin.quoted, e.simpleMsg));
    }

    assert(0);
  }

  static @UI{ // ui /////////////////////////////////////////////

    void CableFrame(T...)(in T args ){
      with(im) Row({
        theme = "tool";
        margin = "2 4";
        border = "2 normal gray";
        padding = "4";
        style.bkColor = bkColor = RGB(230, 230, 230);
        flags.yAlign = YAlign.baseline;
      }, args);
    }

  }//static @UI

  void UI(){ with(im){
    CableFrame({
      if(Btn("Generate program")){
        auto s = generateProgram;
        clipBoard.text = s;
        s.print;
      }
    });

    //cables.each!"a.ui";
    Row({
      Column({ cables[0..3].each!"a.ui"; });
      Column({ cables[3..$].each!"a.ui"; });
    });

    /+foreach(conn; allConnectors){
      Row({
        flags.yAlign = YAlign.center;
        Text(conn, "\t");
        //const ci = connectorInfo(conn);
        ConnectorBtn(conn, genericId(conn)); //opt: this graphics is fucking slow. 30FPS
      });
    }+/
  }}


}




