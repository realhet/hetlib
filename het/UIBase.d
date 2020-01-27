module het.uibase;

import het.utils, het.geometry, het.draw2d, het.image, het.win,
  std.bitmanip: bitfields;

//import core.vararg; //todo: ez nem kell majd.
//import std.traits;

// enums ///////////////////////////////////////

//adjust the size of the original Tab character
enum
  VisualizeContainers   = 0,
  VisualizeGlyphs       = 0,
  VisualizeTabColors    = 0;

enum
  NormalFontHeight = 18;

const
  InternalTabScale = 0.1,   //around 0.15
  LeadingTabScale  = 0.31;  //for programming

enum
  EmptyCellWidth  = 0,
  EmptyCellHeight = 0,
  EmptyCellSize   = V2f(EmptyCellWidth, EmptyCellHeight);

private enum
  AlignEpsilon = .001f; //avoids float errors that come from float sums of subCell widths/heights


// Global shit //////////////////////////////

/*deprecated*/ __gshared V2f currentMouse; //current mouse position in world

/*deprecated*/ float actFontHeight(){
  import het.ui;
  return im.style.fontHeight;
}

/*deprecated*/ RGB actFontColor(){
  import het.ui;
  return im.style.fontColor;
}

//todo: deprecation is handled extremely unraliable. Sometimes the fucking compiller passes, sometimes not.

//__gshared float actFontHeight = 18;
//__gshared RGB actFontColor = clBlack;

//allows relative sizes to current fontHeight
// 15  : 15 pixels
// 15x : 15*baseHeight
float toWidthHeight(string s, float baseHeight){
  s = s.strip;
  if(s.endsWith('x')){ //12x
    return baseHeight*s[0..$-1].to!float;
  }else{
    return s.to!float;
  }
}

private V2f calcGlyphSize_clearType(in TextStyle ts, int stIdx){
  auto info = textures.accessInfo(stIdx);

  float aspect = float(info.width)/(info.height*3/*clearType x3*/); //opt: rcp_fast
  auto size =  V2f(ts.fontHeight*aspect, ts.fontHeight);

  if(ts.bold) size.x += size.y*(BoldOffset*2);

  return size;
}

private V2f calcGlyphSize_image(/*in TextStyle ts,*/ int stIdx){
  auto info = textures.accessInfo(stIdx);

//  float aspect = float(info.width)/(info.height); //opt: rcp_fast
  auto size =  V2f(info.width, info.height);

  //image frame goes here

  return size;
}

// NEW! ------------------------> ImStorage /////////////////////////////

__gshared int globalUpdateTick;

struct ImStorage(T){
  struct StorageEntry{
    T value;
    int age; //in update ticks
    float smoothTime=0; //last time accessed smoothly

  }

  private static StorageEntry[string] map;

  static T get(string name){
    auto a = name in map;
    if(a){
      return a.value;
    }else{
      return T.init;
    }
  }

  static void set(string name, in T newValue){
    auto a = name in map;
    if(a){
      a.value = newValue;
      a.age = globalUpdateTick;
    }else{
      map[name] = StorageEntry(newValue, globalUpdateTick);
    }
  }

/*  static auto smoothGet(float rate)(string name){


  }*/
}



// HitTest ///////////////////////////////

struct HitTestManager{

  struct HitTestRec{
    uint hash;            //in the next frame this must be the isSame
    Bounds2f hitBounds;   //absolute bounds on the drawing where the hittesi was made, later must be combined with View's transformation
    V2f localPos;
  }

  //act frame
  HitTestRec[] hitStack, lastHitStack;
  uint[void*] cellHashMap;

  float[uint] smoothHover;
  private void updateSmoothHover(ref HitTestRec[] actMap){
    enum upSpeed = 0.5f, downSpeed = 0.25f;

    auto act = actMap.map!"a.hash".filter!"a";  //todo: refactor this

    foreach(h; act)
      smoothHover[h] = lerp(smoothHover.get(h, 0.0f), 1, upSpeed);

    uint[] toRemove;
    foreach(h; smoothHover.keys){
      if(!act.canFind(h)){
        if(h in smoothHover){
          smoothHover[h] = lerp(smoothHover[h], 0, downSpeed);
          if(smoothHover[h]<0.02) toRemove ~= h; //todo: test if it is allowed to remove from az assoc array while iterating on it's keys
        }
      }
    }

    foreach(h; toRemove) smoothHover.remove(h);
  }

// -------- SliderInfo - a base to store historical data for every control //////////////////////////////
/*  struct SliderInfo{
    Bounds2f localRect; //mouse is from hittest.local
    bool expired;
  }

  SliderInfo[uint] sliderInfo;

  void addSliderInfo(uint id, in Bounds2f localRect){
    sliderInfo[id] = SliderInfo(localRect);
  }

  void updateSliderInfo(){
    uint[] toRemove;
    foreach(id; sliderInfo.keys) with(sliderInfo[id]){
      if(expired) toRemove ~= id;
      expired = true; //must be preserved through 2 frames
    }
    toRemove.each!(a => sliderInfo.remove(a));
  }*/

  uint capturedHash, clickedHash, pressedHash, releasedHash;
  private void updateMouseCapture(ref HitTestRec[] hits){
    const topHash = hits.length ? hits[$-1].hash : 0;

    //if LMB was just pressed, then it will be the captured control
    //if LMB released, and the captured hash is also hovered, the it is clicked.

    clickedHash = pressedHash = releasedHash = 0; //normally it's 0 all the time, except that one frame it's clicked.

    with(mainWindow){ //todo: get the mouse state from elsewhere!!!!!!!!!!!!!
      if(topHash && mouse.LMB && mouse.justPressed){
        capturedHash = topHash;
        pressedHash = topHash;
      }
      if(mouse.justReleased){
        if(capturedHash && topHash==capturedHash) clickedHash = capturedHash;
        if(capturedHash) releasedHash = capturedHash;
        capturedHash = 0;
      }
    }
  }

  void initFrame(){
    cellHashMap.clear;
    lastHitStack = hitStack.dup;
    hitStack.clear;

    updateSmoothHover(lastHitStack);
    updateMouseCapture(lastHitStack);
//    updateSliderInfo;
  }

  //Used to identify the cell when it later calls addHitRect()
  void addHash(Cell cell, uint hash){
    cellHashMap[cast(void*)cell] = hash;     //todo: error on duplicated ID
  }

  void addHitRect(Cell cell, Bounds2f hitBounds, V2f localPos){//it is called automatically from each cell
    if(auto hash = cellHashMap.get(cast(void*)cell, 0)){
      enforce(!hitStack.any!(a => a.hash==hash), "hash already defined for cell: "~cell.text);
      hitStack ~= HitTestRec(hash, hitBounds, localPos);
    }
  }

  //todo: elrejteni ezeket az individual check-eket a check()en belulre.
  bool checkHover(uint hash){
    auto idx = lastHitStack.map!"a.hash".countUntil(hash);
    return idx<0 ? false
                 : true;
  }

  auto checkHitBounds(uint hash){
    auto idx = lastHitStack.map!"a.hash".countUntil(hash);
    return idx<0 ? Bounds2f()
                 : lastHitStack[idx].hitBounds;
  }

  float checkHover_smooth(uint hash){
    if(capturedHash) return 0;
    return smoothHover.get(hash, 0);
  }

  bool checkCaptured(uint h){
    return capturedHash==h && checkHover(h);
  }

  float checkCaptured_smooth(uint h){
    return capturedHash==h ? checkHover_smooth(h) : 0;
  }

  bool checkClicked(uint h){ return clickedHash==h; }
  bool checkPressed(uint h){ return pressedHash==h; }
  bool checkReleased(uint h){ return releasedHash==h; }

  struct HitInfo{ //Btn returns it
    bool hover, captured, clicked, pressed, released;
    float hover_smooth, captured_smooth;
    Bounds2f hitBounds;

    alias clicked this;
  }

  auto check(uint id){
    HitInfo h;
    h.hover = checkHover(id);
    h.hover_smooth = checkHover_smooth(id);
    h.captured = checkCaptured(id);
    h.captured_smooth = checkCaptured_smooth(id);
    h.clicked = checkClicked(id);
    h.pressed = checkPressed(id);
    h.released = checkReleased(id);
    h.hitBounds = checkHitBounds(id);
    return h;
  }

}

__gshared HitTestManager hitTestManager;


/+
[x] listitem is black filled
[x] color by name
[ ] Put runtime colors in the list too: clAccent, clWinBtn, etc
[x] string.toRGB
[x] toSize: 5.5x = 5.5*fontHeight
[ ] round border. (shader?)
[x] border: should be a struct: lineStipple, width, color
[x] margin, padding: stored in Container
[x] border stored in container
[x] border groove ridge outset inset
[x] border shorthand
[x] padding shorthand
[x] margin shorthand
[ ] Link reacting to mousehover
[x] parameter loading: generate error on unknown parameter! For example on "flex=1" vs "felx=1"
[x] symbol tag
  [ ] composite symbol
[x] keyboard shortcut
  [ ] keyboard shortcut proper highlighting
  [ ] inputs: updateKeyCombos
  [ ] testInputs ujracsinalasa az uj ui-val
[x] edge menuitem
[ ] edge menubuttons
[ ] subAlign
[ ] icon
[ ] stretch align
[x] hover over edgemenus
  [x] smooth animated hover using a map
  [ ] meniutem frame darker around mouse.

[ ] image.height = 1x : ennek az eredeti meretnek kene lennie, viszont egy az actFontHeight-hez van viszonyitva.

[ ] font.shadow (color, size)
[ ] font.outline (color, size)

[ ]   import core.cpuid; ez lehetne a teszt

190605
[x] variadric control creation parameters
[x] checkbox


190710
[ ] button hittest is slow: In the creator, the current mouse position should be checked against the previous hitBounds!!!

Column:
  - align subCells (mostly Rows but not Columns) vertically
  - width behaviour:
    - unspecified: calculated from rightMost subCell
    - specified: forces subCells(mostly Rows) to be that width with wrap/clip
  - height behaviour:
    - unspecified: calculated from bottomMost subCell
    - not now!! specified: wraps subRows into wrapCount pages.

Row:
  - aligns subCells (mostly glyphs or columns but not rows) horizontaly
  - width behaviour:
    - unspec: calculated from rightmost subCell
    - specified: wraps and cuts contents.
  - height behaviour:
    - unspec: calculated from bottomMost cell
    x not needed: spec: Exact value with ... marks

Glyphs:
  - no subCells

Tests:

1. Row with text, width=unspec
2. Row with text, width=100, wrapCnt=1..10


+/



/*
[x] fontFlags
[ ] texelPerPixel -> dfdxy
[x] bold
[x] italic
[x] underline
[x] strikeout
[x] errorline

[x] boolMask(b0, b1, ...) builds a bitmask from booleans

*/

// Template Parameter Processing /////////////////////////////////

import std.traits;

private{
  bool is2(A, B)() { return is(immutable(A)==immutable(B)); }

  bool isBool  (A)(){ return is2!(A, bool  ); }
  bool isInt   (A)(){ return is2!(A, int   ) || is2!(A, uint  ); }
  bool isFloat (A)(){ return is2!(A, float ) || is2!(A, double); }
  bool isString(A)(){ return is2!(A, string); }

  bool isSimple(A)(){ return isBool!A || isInt!A || isFloat!A || isString!A; }

  bool isGetter(A, T)(){
    enum a = A.stringof, t = T.stringof;
    return a.startsWith(t~" delegate()")
        || a.startsWith(t~" function()");
  }
  bool isSetter(A, T)(){
    enum a = A.stringof, t = T.stringof;
    return a.startsWith("void delegate("~t~" ")
        || a.startsWith("void function("~t~" ");
  }
  bool isEvent(A)(){ return isGetter!(A, void); } //event = void getter

  bool isCompatible(TDst, TSrc, bool compiles, bool compilesDelegate)(){
    return (isBool  !TDst && isBool  !TSrc)
        || (isInt   !TDst && isInt   !TSrc)
        || (isFloat !TDst && isFloat !TSrc)
        || (isString!TDst && isString!TSrc)
        || !isSimple!TDst && (compiles || compilesDelegate); //assignment is working. This is the last priority
  }
}

auto paramByType(Tp, bool fallback=false, Tp def = Tp.init, T...)(T args){
  Tp res = def;

  enum isWrapperStruct = __traits(hasMember, Tp, "val") && Fields!Tp.length==1; //is it encapsulated in a wrapper struct?  -> struct{ type val; }

  enum checkDuplicatedParams = q{
    static assert(!__traits(compiles, duplicated_parameter), "Duplicated parameter type: %s%s".format(Tp.stringof, fallback ? "("~typeof(Tp.val).stringof~")" : ""));
    enum duplicated_parameter = 1;
  };

  static foreach_reverse(idx, t; T){
    //check simple types/structs
    static if(isCompatible!(typeof(res), t, __traits(compiles, res = args[idx]), __traits(compiles, res = args[idx].toDelegate))){
      static if(__traits(compiles, res = args[idx]))           res = args[idx];                else res = args[idx].toDelegate;
      mixin(checkDuplicatedParams);
    }else
    //check fallback struct.val
    static if(fallback && isWrapperStruct && isCompatible!(typeof(res.val), t, __traits(compiles, res.val = args[idx]), __traits(compiles, res.val = args[idx].toDelegate))){
      static if(__traits(compiles, res.val = args[idx]))                                          res.val = args[idx];                else res.val = args[idx].toDelegate;
      mixin(checkDuplicatedParams);
    }
  }

  static if(isWrapperStruct) return res.val;
                        else return res;
}

void paramCall(Tp, bool fallback=false, T...)(T args){
  auto e = paramByType!(Tp, fallback)(args);
  static assert(isEvent!(typeof(e)), "paramCallEvent() error: %s is not an event.".format(Tp.stringof));
  if(e !is null) e();
}

template paramGetterType(T...){
  static foreach(t; T){
    static if(isPointer!t){
      static if(isFunctionPointer!t){
        static if(Parameters!t.length==0)
          alias paramGetterType = ReturnType!t; //type function()
      }else{
        alias paramGetterType = PointerTarget!t; //type*
      }
    }else static if(isDelegate!t){
      static if(Parameters!t.length==0)
        alias paramGetterType = ReturnType!t; //type delegate()
    }
  }

  static assert(is(paramGetterType), "Unable to get paramGetterType "~ T.stringof);
}

void paramGetter(Tr, T...)(T args, ref Tr res){ //duplicate checking is in paramGetterType
  static foreach_reverse(idx, t; T){
    static foreach(t; T){
      static if((isFunctionPointer!t || isDelegate!t) && Parameters!t.length==0 && !is(ReturnType!t==void) && __traits(compiles, res = args[idx]().to!Tr)){
        res = args[idx]().to!Tr;
      }else static if(isPointer!t && __traits(compiles, res = (*args[idx]).to!Tr)){
        res = (*args[idx]).to!Tr;
      }
    }
  }
}

void paramSetter(Tr, T...)(T args, in Tr val){ //duplicates are allowed
  static foreach_reverse(idx, t; T){
    static foreach(t; T){
      static if((isFunctionPointer!t || isDelegate!t) && Parameters!t.length==1 && is(ReturnType!t==void) && __traits(compiles, args[idx](val.to!Tr))){
        args[idx](val.to!Tr);
      }else static if(isPointer!t && __traits(compiles, *args[idx] = val.to!Tr)){
        *args[idx] = val.to!Tr;
      }
    }
  }
}



shared static this(){ //static init///////////////////////////////
  initTextStyles;
}

// TextStyle ////////////////////////////////////
struct TextStyle{
  string font;
  ubyte fontHeight=NormalFontHeight;
  bool bold, italic, underline, strikeout;
  RGB fontColor=clBlack, bkColor=clWhite;

  int fontFlags() const{ return boolMask(bold, italic, underline, strikeout); }

  void modify(string[string] map){
    map.rehash;
    if(auto p="font"       in map) font          = (*p);
    if(auto p="fontHeight" in map) fontHeight    = (*p).toWidthHeight(actFontHeight).iRound.to!ubyte;
    if(auto p="bold"       in map) bold          = (*p).toInt!=0;
    if(auto p="italic"     in map) italic        = (*p).toInt!=0;
    if(auto p="underline"  in map) underline     = (*p).toInt!=0;
    if(auto p="strikeout"  in map) strikeout     = (*p).toInt!=0;
    if(auto p="fontColor"  in map) fontColor     = (*p).toRGB;
    if(auto p="bkColor"    in map) bkColor       = (*p).toRGB;
  }
  void modify(string cmdLine){
    modify(commandLineToMap(cmdLine));
  }
}

// TextStyles ////////////////////////////////////////////

TextStyle tsNormal, tsComment, tsError, tsBold, tsBold2, tsCode, tsQuote, tsLink, tsTitle, tsChapter, tsChapter2, tsChapter3,
  tsBtn, tsKey, tsLarger, tsSmaller, tsHalf;

TextStyle*[string] textStyles;

TextStyle newTextStyle(string name)(in TextStyle base, string props){
  TextStyle ts = base;
  ts.modify(props);
  return ts;
}

/*  hlDefault:TTextFormats=(
{skWhitespace}  (FontColor:clBlack    ;BackColor:clWhite      ;Style:[]             ),
{skSelected}    (FontColor:clWhite    ;BackColor:10841427     ;Style:[]             ),
{skFoundAct}    (FontColor:$FCFDCD    ;BackColor:clBlack      ;Style:[]             ),
{skFoundAlso}   (FontColor:clBlack    ;BackColor:$78AAFF      ;Style:[]             ),
{skNavLink}     (FontColor:clBlue     ;BackColor:clWhite      ;Style:[fsUnderline]  ),
{skNumber}      (FontColor:clBlue     ;BackColor:clWhite      ;Style:[]             ),
{skString}      (FontColor:clBlue     ;BackColor:clSkyBlue    ;Style:[]             ),
{skKeyword}     (FontColor:clNavy     ;BackColor:clWhite      ;Style:[fsBold]       ),
{skSymbol}      (FontColor:clBlack    ;BackColor:clWhite      ;Style:[]             ),
{skComment}     (FontColor:clNavy     ;BackColor:clYellow     ;Style:[fsItalic]     ),
{skDirective}   (FontColor:clTeal     ;BackColor:clWhite      ;Style:[]             ),
{skIdentifier1} (FontColor:clBlack    ;BackColor:clWhite      ;Style:[]             ),
{skIdentifier2} (FontColor:clGreen    ;BackColor:clWhite      ;Style:[]             ),
{skIdentifier3} (FontColor:clTeal     ;BackColor:clWhite      ;Style:[]             ),
{skIdentifier4} (FontColor:clPurple   ;BackColor:clWhite      ;Style:[]             ),
{skIdentifier5} (FontColor:$0040b0    ;BackColor:clWhite      ;Style:[]             ),
{skIdentifier6} (FontColor:$b04000    ;BackColor:clWhite      ;Style:[]             ),
{skLabel}       (FontColor:clBlack    ;BackColor:$DDFFEE      ;Style:[fsUnderline]  ),
{skAttribute}   (FontColor:clPurple   ;BackColor:clWhite      ;Style:[fsBold]       ),
{skBasicType}   (FontColor:clTeal     ;BackColor:clWhite      ;Style:[fsBold]       ),
{skError}       (FontColor:clRed      ;BackColor:clWhite      ;Style:[fsUnderline]  ),
{skBinary1}     (FontColor:clWhite    ;BackColor:clBlue       ;Style:[]             )
);*/

//https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-getsyscolor
const clChapter                 = RGB(221,   3,  48),
      clAccent                  = RGB(0  , 120, 215),
      clMenuBk                  = RGB(240, 240, 241),
      clMenuHover               = RGB(222, 222, 222),
      clLink                    = RGB(0  , 120, 215),
      clLinkHover               = RGB(102, 102, 102),
      clLinkPressed             = RGB(153, 153, 153),
      clLinkDisabled            = clWinBtnHoverBorder,

      clWinRed                  = RGB(232,17,35),

      clWinText                 = clBlack,
      clWinBackground           = clWhite,
      clWinFocusBorder          = clBlack,
      clWinBtn                  = RGB(204, 204, 204),
      clWinBtnHoverBorder       = RGB(122, 122, 122),
      clWinBtnPressed           = clWinBtnHoverBorder,
      clWinBtnDisabledText      = clWinBtnHoverBorder,

      clSliderLine              = clLinkPressed,
      clSliderLineHover         = clLinkHover,
      clSliderLinePressed       = clLinkPressed,
      clSliderThumb             = clAccent,
      clSliderThumbHover        = RGB(23, 23, 23),
      clSliderThumbPressed      = clWinBtn,
      clSliderHintBorder        = clMenuBk,
      clSliderHintBk            = clWinBtn;

void initTextStyles(){

  void a(string n, ref TextStyle r, in TextStyle s, void delegate() setup = null){
    r = s;
    if(setup!is null) setup();
    textStyles[n] = &r;
  }

  //relativeFontHeight ()
  ubyte rfh(float r){ return (NormalFontHeight*(r/18.0)).iRound.to!ubyte; }


  a("normal"      , tsNormal  , TextStyle("Segoe UI", rfh(18), false, false, false, false, clBlack, clWhite));
  a(  "larger"    , tsLarger  , tsNormal, { tsLarger.fontHeight = rfh(22); });
  a(  "smaller"   , tsSmaller , tsNormal, { tsSmaller.fontHeight = rfh(14); });
  a(  "half"      , tsHalf    , tsNormal, { tsSmaller.fontHeight = rfh(9); });
  a(  "comment"   , tsComment , tsNormal, { tsComment.fontHeight = rfh(12); });
  a(  "error"     , tsError   , tsNormal, { tsError.bold = tsError.underline = true; tsError.bkColor = clRed; tsError.fontColor = clYellow; });
  a(  "bold"      , tsBold    , tsNormal, { tsBold.bold = true; });
  a(    "bold2"   , tsBold2   , tsBold  , { tsBold2.fontColor = clChapter; });
  a(  "quote"     , tsQuote   , tsNormal, { tsQuote.italic = true; });
  a(  "code"      , tsCode    , tsNormal, { tsCode.font = "Courier New"; tsCode.fontHeight = rfh(18); tsCode.bold = true; });
  a(  "link"      , tsLink    , tsNormal, { tsLink.underline = true; tsLink.fontColor = clLink; });
  a(  "title"     , tsTitle   , tsNormal, { tsTitle.bold = true; tsTitle.fontColor = clChapter; tsTitle.fontHeight = rfh(64); });
  a(    "chapter" , tsChapter , tsTitle , { tsChapter.fontHeight = rfh(40); });
  a(    "chapter2", tsChapter2, tsTitle , { tsChapter2.fontHeight = rfh(32); });
  a(    "chapter3", tsChapter3, tsTitle , { tsChapter3.fontHeight = rfh(27); });

  a(  "btn"       , tsBtn     , tsNormal, { tsBtn.bkColor =  clWinBtn; });
  a(  "key"       , tsKey     , tsSmaller, { tsKey.bkColor =  RGB(236, 235, 230); tsKey.bold = true; });

  textStyles["" ] = &tsNormal;
  textStyles["n" ] = &tsNormal;
  textStyles["b" ] = &tsBold;
  textStyles["b2"] = &tsBold2;
  textStyles["q" ] = &tsQuote;
  textStyles["c" ] = &tsCode;

  textStyles.rehash;
}

bool updateTextStyles(){
  //flashing error
  bool act = (QPS/60*132).fract<0.66;
  tsError.fontColor = act ? clYellow : clRed;
  tsError.bkColor   = act ? clRed : clYellow;
  return chkSet(tsError.underline, act);
}

// Helper functs ///////////////////////////////////////////

private bool isSame(T1, T2)(){
  return is(immutable(T1)==immutable(T2));
}

string tag(string s) { return "\u00B6"~s~"\u00A7"; }

string unTag(string s){ //converts tag characters to their visual symbols
  string res;
  res.reserve(s.length);

  foreach(dchar ch; s) switch(ch){
    case '\u00A7': res ~= tag("char 0xA7"); break;
    case '\u00B6': res ~= tag("char 0xB6"); break;
    default: res ~= ch;
  }

  return res;
}

bool startsWithTag(ref string s, string tag){
  tag = "\u00B6"~tag~"\u00A7";
  if(s.startsWith(tag)){
    s = s[tag.length..$];
    return true;
  }
  return false;
}

void setParam(T)(string[string] p, string name, void delegate(T) dg){
  if(auto a = name in p){
    static if(is(T == RGB)){
      dg(toRGB(*a));
    }else{
      auto v = (*a).to!T;
      dg(v);
    }
  }
}

void spreadH(Cell[] cells, in V2f origin = V2f.Null){
  float cx = origin.x;
  foreach(c; cells){
    c.outerPos = V2f(cx, origin.y);
    cx += c.outerWidth;
  }
}

void spreadV(Cell[] cells, in V2f origin = V2f.Null){
  float cy = origin.y;
  foreach(c; cells){
    c.outerPos = V2f(origin.x, cy);
    cy += c.outerHeight;
  }
}

float maxOuterWidth (Cell[] cells, float def = EmptyCellWidth ) { return cells.empty ? def : cells.map!"a.outerWidth" .maxElement; }
float maxOuterHeight(Cell[] cells, float def = EmptyCellHeight) { return cells.empty ? def : cells.map!"a.outerHeight".maxElement;}

float maxOuterRight (Cell[] cells, float def = EmptyCellWidth ) { return cells.empty ? def : cells.map!"a.outerRight" .maxElement; }
float maxOuterBottom(Cell[] cells, float def = EmptyCellWidth ) { return cells.empty ? def : cells.map!"a.outerBottom" .maxElement; }

V2f maxOuterSize(Cell[] cells, V2f def = EmptyCellSize) { return V2f(maxOuterRight(cells, def.x), maxOuterBottom(cells, def.y)); }

float totalOuterWidth (Cell[] cells, float def = EmptyCellWidth ) { return cells.empty ? def : cells.map!"a.outerWidth" .sum; }
float totalOuterHeight(Cell[] cells, float def = EmptyCellHeight) { return cells.empty ? def : cells.map!"a.outerHeight".sum;}

float calcFlexSum(Cell[] cells) { return cells.map!"a.flex".sum; }

bool isWhite(const Cell c){ auto g = cast(const Glyph)c; return g && g.isWhite; }




struct Padding{  //Padding, Margin ///////////////////////////////////////////////////
  alias all this;

  float top=0, right=0, bottom=0, left=0;
  @property{
    float all() const{ return avg(horz, vert); }
    void all(float a){ left = right = top = bottom = a; }

    float horz() const{ return avg(left, right); }
    void horz(float a) { left = right = a; }
    float vert() const{ return avg(top, bottom); }
    void vert(float a) { top = bottom = a; }
  }

  private static float toF(string s){ return s.toWidthHeight(actFontHeight); }

  void opAssign(in string s){ setProps(s); }

  void setProps(in string s){ //shorthand
    if(s.empty) return;
    auto p = s.split(' ').filter!"!a.empty".array;
    if(p.empty) return;

    float f(){ auto a = toF(p[0]); p = p[1..$]; return a; }

    switch(p.length){
      case 4: top = f; right = f; bottom = f; left = f; break;
      case 3: top = f; horz = f; bottom = f; break;
      case 2: vert = f; horz = f; break;
      case 1: all = f; break;
      default: enforce(false, "Invalid padding/margin shorthand format.");
    }
  }

  void setProps(string[string] p, string prefix){
    p.setParam(prefix, (string s){ setProps(s); });

    p.setParam(prefix~".all"   , (string s){ all    = toF(s); });
    p.setParam(prefix~".horz"  , (string s){ horz   = toF(s); });
    p.setParam(prefix~".vert"  , (string s){ vert   = toF(s); });
    p.setParam(prefix~".left"  , (string s){ left   = toF(s); });
    p.setParam(prefix~".right" , (string s){ right  = toF(s); });
    p.setParam(prefix~".top"   , (string s){ top    = toF(s); });
    p.setParam(prefix~".bottom", (string s){ bottom = toF(s); });
  }
}

alias Margin = Padding;

enum BorderStyle { none, normal, dot, dash, dashDot, dash2, dashDot2, double_ }

auto toBorderStyle(string s){ //Border ///////////////////////////
  //synomyms
       if(s=="single") s="normal";
  else if(s=="double") s="double_";
  return s.to!BorderStyle;
}

struct Border{
  float width = 0;
  BorderStyle style = BorderStyle.normal;  //todo: too many bits
  RGB color = clBlack;
  bool inset = false; // put inside the padding or have it's own place

  float gapWidth() const{ return inset ? 0 : width; } //effective borderWidth

  void opAssign(in string s){ setProps(s); }

  void setProps(in string s){//shortHand: [width] style [color]
    if(s.empty) return;
    auto p = s.split(' ').filter!"!a.empty".array;
    if(p.empty) return;

    //todo: the properties can be in any order.
    //todo: support the inset property

    //width
    bool hasWidth;
    if(p[0][0].isDigit){
      hasWidth = true;
      width = p[0].to!float;
      p = p[1..$];
      if(p.empty) return;
    }

    //style
    style = p[0].toBorderStyle;
    if(!hasWidth && style!=BorderStyle.none) width = 1; //default width
    p = p[1..$];
    if(p.empty){
      color = actFontColor; //default color
      return;
    }

    //color
    color = p[0].toRGB;
  }

  void setProps(string[string] p, string prefix){
    p.setParam(prefix, (string s){ setProps(s); });

    p.setParam(prefix~".width", (string a){ width = a.toWidthHeight(actFontHeight); });
    p.setParam(prefix~".color", (RGB    a){ color = a; });
    p.setParam(prefix~".style", (string a){ style = a.toBorderStyle; });
  }
}

int toLineStipple(BorderStyle bs){
  with(BorderStyle) switch(bs){
    case dot:         return lsDot;
    case dash:        return lsDash;
    case dashDot:     return lsDashDot;
    case dash2:       return lsDash2;
    case dashDot2:    return lsDashDot2;
    default: return lsNormal;
  }
}


/*auto isClass(C)(TypeInfo_Class i){
  if(i==typeid(C)) return true;
  auto n = i.base;
  return n is null ? false : n.isClass!C;
}

alias isCell = isClass!(Cell);*/

struct _FlexValue{ float val=0; alias val this; } //ganyolas


class Cell{ // Cell ////////////////////////////////////
  V2f outerPos, innerSize;

  ref _FlexValue flex() { static _FlexValue nullFlex; return nullFlex   ; } //todo: this is bad, but fast. maybe do it with a setter and const ref.
  ref Margin  margin () { static Margin  nullMargin ; return nullMargin ; }
  ref Border  border () { static Border  nullBorder ; return nullBorder ; }
  ref Padding padding() { static Padding nullPadding; return nullPadding; }

  float extraMargin()      { return (VisualizeContainers && cast(Container)this)? 3:0; }
  V2f topLeftGapSize()     { return V2f(margin.left +extraMargin+border.gapWidth+padding.left , margin.top   +extraMargin+border.gapWidth+padding.top   ); }
  V2f bottomRightGapSize() { return V2f(margin.right+extraMargin+border.gapWidth+padding.right, margin.bottom+extraMargin+border.gapWidth+padding.bottom); }
  V2f gapSize() { return topLeftGapSize + bottomRightGapSize; }

  @property{
    //todo: ezt at kell irni, hogy az outerSize legyen a tarolt cucc, ne az inner. Indoklas: az outerSize kizarolag csak az outerSize ertek atriasakor valtozzon meg, a border modositasatol ne. Viszont az autoSizet ekkor mashogy kell majd detektalni...
    V2f innerPos () { return outerPos+topLeftGapSize; } void innerPos(in V2f p){ outerPos = p+topLeftGapSize; }
    V2f outerSize() { return innerSize+gapSize; } void outerSize(in V2f s){ innerSize = s-gapSize; }
    auto innerBounds() { return Bounds2f(innerPos, innerPos+innerSize); }
    void innerBounds(in Bounds2f b) { innerPos = b.bMin; innerSize = b.size; }
    auto outerBounds() { return Bounds2f(outerPos, outerPos+outerSize); }
    void outerBounds(in Bounds2f b) { outerPos = b.bMin; outerSize = b.size; }

    auto outerBottomRight() { return outerPos+outerSize; }

    auto borderBounds(float location=0.5)(){
      auto hb = border.width*location;
      return Bounds2f(outerPos+V2f(margin.left+extraMargin+hb, margin.top+extraMargin+hb), outerBottomRight-V2f(margin.right+extraMargin+hb, margin.bottom+extraMargin+hb));
    }
    auto borderBounds_inner() { return borderBounds!1; }
    auto borderBounds_outer() { return borderBounds!0; }

    auto outerX     () { return outerPos.x; } void outerX(float v) { outerPos.x = v; }
    auto outerY     () { return outerPos.y; } void outerY(float v) { outerPos.y = v; }
    auto innerX     () { return outerPos.x+topLeftGapSize.x; } void x(float v) { outerPos.x = v-topLeftGapSize.x; }
    auto innerY     () { return outerPos.y+topLeftGapSize.y; } void y(float v) { outerPos.y = v-topLeftGapSize.y; }
    auto innerWidth () { return innerSize.x; } void innerWidth (float v) { innerSize.x = v; }
    auto innerHeight() { return innerSize.y; } void innerHeight(float v) { innerSize.y = v; }
    auto outerWidth () { return innerSize.x+gapSize.x; } void outerWidth (float v) { innerSize.x = v-gapSize.x; }
    auto outerHeight() { return innerSize.y+gapSize.y; } void outerHeight(float v) { innerSize.y = v-gapSize.y; }
    auto outerRight () { return outerX+outerWidth; }
    auto outerBottom() { return outerY+outerHeight; }

    alias size = innerSize;
    alias width = innerWidth;
    alias height = innerHeight;
  }

  Bounds2f getHitBounds() { return borderBounds_outer; } //Used by hittest. Can override.

  private void notImpl(string s){ raise(s~" in "~typeof(this).stringof); }

  //params
  void setProps(string[string] p){
    p.setParam("width" , (string s){ width  = s.toWidthHeight(actFontHeight); });
    p.setParam("height", (string s){ height = s.toWidthHeight(actFontHeight); });
    p.setParam("innerWidth" , (string s){ innerWidth  = s.toWidthHeight(actFontHeight); });
    p.setParam("innerHeight", (string s){ innerHeight = s.toWidthHeight(actFontHeight); });
    p.setParam("outerWidth" , (string s){ outerWidth  = s.toWidthHeight(actFontHeight); });
    p.setParam("outerHeight", (string s){ outerHeight = s.toWidthHeight(actFontHeight); });
  }
  final void setProps(string cmdLine){ setProps(cmdLine.commandLineToMap); }

  //subCells
  @property Cell[] subCells() { return []; }
  @property void subCells(Cell[] cells) { notImpl("setSubCells"); }

  void append(Cell   c){ notImpl("append()"); }
  void append(Cell[] a){ notImpl("append()"); }

  void draw(ref Drawing dr) { }

  //append Glyphs
  void appendg(File  fn, in TextStyle ts){ append(new Img(fn, ts)); }
  void appendg(dchar ch, in TextStyle ts){ append(new Glyph(ch, ts)); }
  void appendg(string s, in TextStyle ts){ foreach(ch; s.byDchar) appendg(ch, ts); }

  //elastic tabs
  int[] tabIdx() { return []; }
  int tabCnt() { return tabIdx.length.to!int; } //todo: int -> size_t
  float tabPos(int i) { with(subCells[tabIdx[i]]) return outerRight; }

/* advanced insert delete. Not needed for IMGUI
  void insert(Cell[] ins, int at=int.max, int del=0, Cell[]* cutCells=null) { notImpl("modifySubCells() not implemented"); }
  void append(Cell[] c)         { insert(c); }
  void delete_(int at, int cnt) { insert([], at, cnt); }
  Cell[] cut(int at, int cnt)   { Cell[] res; insert([], at, cnt, &res); }*/

  bool hitTest(in V2f mouse, V2f ofs=V2f.Null){ //todo: only check when the hitTest flag is true
    auto bnd = getHitBounds.translated(ofs);
    if(bnd.checkInside(mouse)){
      hitTestManager.addHitRect(this, bnd, mouse-outerPos);
      return true;
    }else{
      return false;
    }
  }

  final void drawBorder(ref Drawing dr){
    if(!border.width || border.style == BorderStyle.none) return;

    const bw = border.width, bb = borderBounds;
    dr.lineStipple = border.style.toLineStipple;
    dr.color = border.color;
    dr.lineWidth = bw * (border.style==BorderStyle.double_ ? 0.33f : 1);

    void doit(float sh=0){
      const m = bw*sh;
      auto r = bb.inflated(m, m);
      if(r.width<=0 || r.height<=0){
        dr.line(r.topLeft, r.bottomRight); //todo: just a line. Used for Spacer, but it's wrond, because it goes negative
      }else{
        dr.drawRect(r);
      }
    }

    if(border.style==BorderStyle.double_){ doit(-0.333); doit(0.333); }
                                     else{ doit;                      }
  }
}


class TestClass{ ubyte x; }

shared static this(){
  import std.stdio;
  writeln(__traits(classInstanceSize, TestClass).stringof);
  writeln(TestClass.x.offsetof);

  auto c = new TestClass;
  synchronized(c){
    writeln("hello");
  }
}


class Img : Container { // Img ////////////////////////////////////
  int stIdx;

  this(File fn, in TextStyle ts){
    stIdx = textures[fn];
  }

  override void draw(ref Drawing dr){
    drawBorder(dr);

    dr.drawFontGlyph(stIdx, innerBounds, bkColor, 16/*image*/);
  }

  override void measure(){
    const autoWidth  = innerWidth ==0,
          autoHeight = innerHeight==0,
          siz = calcGlyphSize_image(stIdx);

    if(autoHeight && autoWidth){
      innerSize = siz;
    }else if(autoHeight){
      innerSize.y = innerSize.x/max(siz.x, 1)*siz.y;
    }else if(autoWidth){
      innerSize.x = innerSize.y/max(siz.y, 1)*siz.x;
    }
  }
}

class Glyph : Cell { // Glyph ////////////////////////////////////
  int stIdx;

  int fontFlags; //todo: compress information
  bool isWhite, isTab; //needed for wordwrap and elastic tabs
  RGB fontColor, bkColor;


  this(dchar ch, in TextStyle ts){
    //tab is the isSame as a space
    isTab = ch==9;
    isWhite = isTab || ch==32;

    string glyphSpec = `font:\`~ts.font~`\72\x3\?`~[ch].toUTF8;

    stIdx = textures[File(glyphSpec)];
    fontFlags = ts.fontFlags;
    fontColor = ts.fontColor;
    bkColor = ts.bkColor;

    innerSize = calcGlyphSize_clearType(ts, stIdx);
  }

  override void draw(ref Drawing dr){
    drawBorder(dr);
    dr.color = fontColor;
    dr.drawFontGlyph(stIdx, innerBounds, bkColor, fontFlags);

    if(VisualizeGlyphs){
      dr.color = clGray;
      dr.lineStipple = lsNormal;
      dr.lineWidth = 0.16*2;
      dr.drawRect(innerBounds);

      if(isTab){
        dr.arrowStyle = asVector;
        dr.lineWidth = innerHeight*0.04;
        dr.line(innerBounds.leftCenter, innerBounds.rightCenter);
        dr.arrowStyle = asNone;
      }else if(isWhite){
        dr.drawX(innerBounds);
      }
    }
  }
}

enum WrapMode { clip, wrap, shrink } //todo: break word, spaces on edges, tabs vs wrap???


union ContainerFlags{
  ubyte _data = 0b0_01_00_00_1;
  mixin(bitfields!(
    bool          , "canWrap"         , 1,
    HAlign        , "hAlign"          , 2,
    VAlign        , "vAlign"          , 2,
    YAlign        , "yAlign"          , 2,
    bool          , "dontHideSpaces"  , 1,  //useful for active edit mode
    //int, "_dummy"       , 1,
  ));

  //todo: setProps, mint a margin-nal
}


class Container : Cell { // Container ////////////////////////////////////
  private{
    Cell[] subCells_;
    public{ //todo: ezt a publicot leszedni es megoldani szepen
      _FlexValue flex_;
      Margin margin_  ;
      Padding padding_;
      Border  border_ ;
    }
  }
  final override{
    ref _FlexValue flex() { return flex_   ; }
    ref Margin  margin () { return margin_ ; } //todo: ezeknek nem kene virtualnak lennie, csak a containernek van borderje, a glyphnek nincs.
    ref Padding padding() { return padding_; }
    ref Border  border () { return border_ ; }
  }

  RGB bkColor=clWhite; //todo: background struct
  ContainerFlags flags;

  override void setProps(string[string] p){
    super.setProps(p);

    margin_ .setProps(p, "margin" );
    padding_.setProps(p, "padding");
    border_ .setProps(p, "border" );

    p.setParam("flex"   , (float f){ flex_   = f; });
    p.setParam("bkColor", (RGB   c){ bkColor = c; });

    //todo: flags.setProps param
  }

  void parse(string s, TextStyle ts = tsNormal){
    enforce("notimpl");
  }

  override{
    @property Cell[] subCells() { return subCells_; }
    @property void subCells(Cell[] cells) { subCells_ = cells; }

    void append(Cell   c){ if(c !is null) subCells_ ~= c; }
    void append(Cell[] a){ subCells_ ~= a; }
  }

  void measure(){
    enforce("not impl");
  }

  private void measureSubCells(){
    foreach(sc; subCells) if(auto co = cast(Container)sc) co.measure(); //recursive in the front
  }

  override bool hitTest(in V2f mouse, V2f ofs=V2f.Null){
    if(super.hitTest(mouse, ofs)){
      ofs += innerPos;
      foreach(sc; subCells) sc.hitTest(mouse, ofs); //recursive
      return true;
    }else{
      return false;
    }
  }

  override void draw(ref Drawing dr){

    //todo: automatic measure when needed. Currently it is not so well. Because of elastic tabs.
    //if(chkSet(measured)) measure;

    //autofill background
    dr.color = bkColor;
    dr.fillRect(borderBounds_inner);

    dr.translate(innerPos);

    foreach(sc; subCells){
      sc.draw(dr); //recursive
    }

    dr.pop;

    drawBorder(dr); //border is the last

    if(VisualizeContainers){
      if(cast(Column)this){ dr.color = clRed; }
      else if(cast(Row)this){ dr.color = clBlue; }
      else dr.color = clGray;

      dr.lineWidth = 1;
      dr.lineStipple = lsNormal;
      dr.drawRect(outerBounds.inflated(-1.5));
    }
  }

}


// markup parser /////////////////////////////////////////

private void processMarkupCommandLine(C:Container)(C container, string cmdLine, ref TextStyle ts){
  import het.ui; //can spawn controls

  if(cmdLine==""){
    ts = tsNormal;
  }else if(auto t = cmdLine in textStyles){ //standard style.  Should be mentioned by an index
    ts = **t; //now it is a copy;
  }else{
    try{
      auto params = cmdLine.commandLineToMap;
      auto cmd = params.get("0", "");

            if(cmd=="row"   ){ auto a = new Row   (params["1"], tsNormal); a.setProps(params); container.append(a);
//      }else if(cmd=="column"){ auto a = new Column(params["1"], tsNormal); a.setProps(params); append(a);
      }else if(cmd=="img"){
        auto img = new Img(File(params["1"]), ts);
        img.setProps(params);
        container.append(img);
      }else if(cmd=="char"   ){ container.appendg(dchar(params["1"].toInt), ts);
      }else if(cmd=="symbol"    ){
        auto name = params["1"];
        auto ch = segoeSymbolByName(name);
        auto oldFont = ts.font;
        ts.font = "Segoe MDL2 Assets";
        container.appendg(ch, ts);
        ts.font = oldFont;
      }else if(cmd=="space"  ){
        auto r = new Row("", ts);
        r.innerHeight = ts.fontHeight;
        r.outerWidth = params["1"].toWidthHeight(actFontHeight);
        r.setProps(params);
        container.append(r);
      }else if(cmd=="flex"  ){
        container.append(new Row(tag("prop flex=1"), ts));
      }else if(cmd=="link"   ){
        container.append(new Link(params["1"], 0, false, null));
/*      }else if(cmd=="btn" || cmd=="button"   ){
        auto btn = new Clickable(params["1"], 0, false, null);
        btn.setProps(params);
        append(btn);*/
      }else if(cmd=="key" || cmd=="keyCombo"  ){
        auto kc = new KeyCombo(params["1"]);
        kc.setProps(params);
        container.append(kc);
      }else if(cmd=="style"){ //textStyle
        ts.modify(params);
      }else if(cmd=="prop" || cmd=="props"){ //container's properties
        container.setProps(params);
      }else{
        //try to set container properties

        throw new Exception(`Unknown command: "%s"`.format(cmd));
      }
    }catch(Throwable t){
      container.appendg("["~t.msg~": "~cmdLine~"]", tsError);
    }
  }
}

void appendMarkupLine(Row row, string s, ref TextStyle ts){
  enum CommandStartMarker = '\u00B6',
       CommandEndMarker   = '\u00A7';

  int inCommand;
  string commandLine;

  foreach(ch; s.byDchar){

//    ushort dynChar = dcm.encode(ch); //dr.textOut(x+i*lineSpacing/2, y, [ch].toUTF8);  //todo: process the compressed thing

    if(ch==CommandStartMarker){ //handle start marker
      if(inCommand) commandLine ~= ch; //only if already in a command, not the first one
      inCommand++;
    }else if(ch==CommandEndMarker){ //handle end marker
      enforce(inCommand>0, "Unexpected command end marker");
      if(inCommand>1) commandLine ~= ch; //dont append level 1 end marker
      if(!(--inCommand)){
        row.processMarkupCommandLine(commandLine, ts);
        commandLine = "";
      }
    }else{
      if(inCommand){ //collect command
        commandLine ~= ch;
      }else{ //process text
        if(ch==9) row.tabIdxInternal ~= row.subCells.length.to!int; //Elastic Tabs
        row.appendg(ch, ts);
      }
    }

  }
}


private struct WrappedLine{ // WrappedLine /////////////////////////////////////////////////////////
  Cell[] cells;
  float y0, height;

  //const{ //todo: outerRight is not const
    auto top(){ return y0; }
    auto bottom(){ return top+height; }
    auto right(){ return cells.length ? cells[$-1].outerRight : 0; }
    auto left(){ return cells.length ? cells[0].outerPos.x : 0; }
    auto calcWidth(){ assert(left==0); return right; } //todo: assume left is 0
  //}

  void translateX(float dx){ if(!dx) return; foreach(c; cells) c.outerPos.x += dx; }
  void translateY(float dy){ if(!dy) return; foreach(c; cells) c.outerPos.y += dy; y0 += dy; }

  void scaleX(float scale, bool whiteOnly){
    float shift = 0;

    if(scale) foreach(c; cells){
      c.outerPos.x += shift;
      if(!whiteOnly || c.isWhite){
        auto oldWidth = c.outerWidth;
        auto newWidth = oldWidth*scale;
        shift += newWidth - oldWidth;
      }
    }
  }

  void alignY(float t){ //only callable once, as it is relative
    if(t) foreach(c; cells) c.outerPos.y += (height-c.outerHeight)*t;
  }

  void alignX(float fullWidth, float t){
    if(t) translateX( (fullWidth-calcWidth)*t );
  }

  void justifyX(float fullWidth){
    auto whiteSum = cells.filter!(c => c.isWhite && c.outerWidth).map!(c => c.outerWidth).sum;
    if(!whiteSum) return;
    auto fixedSum = calcWidth - whiteSum;

    //fixedSum + whiteSum*scale = fullWidth
    //scale*whiteSum = fullWidth - fixedSum
    auto scale = (fullWidth - fixedSum)/whiteSum;
    enum MaxJustifyScale = 999;
    if(scale<MaxJustifyScale) scaleX(scale, true);
  }

  void hideLeftSpace(){
    if(cells.length && isWhite(cells[0])){
      auto w = cells[0].outerWidth;
      cells[0].outerWidth = 0;
      foreach(c; cells[1..$]) c.outerPos.x -= w; //shift back the remaining ones
    }
  }

  void hideRightSpace(){
    if(cells.length && isWhite(cells[$-1]))
      cells[0].outerWidth = 0;
  }

  void hideBothSpaces(){
    hideRightSpace;
    hideLeftSpace;
  }

  void hideSpaces(HAlign hAlign){
    final switch(hAlign){
      case HAlign.left    : hideLeftSpace;  break;
      case HAlign.right   : hideRightSpace; break;
      case HAlign.center  : hideBothSpaces; break;
      case HAlign.justify : hideBothSpaces; break;
    }
  }
}

private{ //wrappedLine[] functionality

  float calcHeight(WrappedLine[] lines){
    return lines.length ? lines[$-1].bottom - lines[0].y0 //todo: ezt nem menet kozben, hanem egy eloszamitaskent kene meghivni
                        : 0;
  }

  float calcWidth(WrappedLine[] lines){
    return lines.length ? lines.map!"a.calcWidth".maxElement : 0;
  }

  void translateY(WrappedLine[] lines, float dy){ if(dy) foreach(ref l; lines) l.translateY(dy); }

  void alignY(WrappedLine[] lines, float availableHeight, float t){
    if(t) lines.translateY( (availableHeight - lines.calcHeight)*t );
  }

  void justifyY(WrappedLine[] lines, float availableHeight){
    if(lines.empty) return;
    auto remaining = availableHeight - lines.calcHeight,
         step = remaining/(lines.length),
         act = step*.5;

    if(step<=0) return; //todo: shrink?

    foreach(int i, ref l; lines){
      l.translateY(act);
      act += step;
    }
  }

  void hideSpaces(WrappedLine[] lines, HAlign hAlign){ foreach(l; lines) l.hideSpaces(hAlign); }

}


// Elastic Tabs //////////////////////////////////////////
private void processElasticTabs(Cell[] rows, int level=0){ //todo
  bool tabCntGood(Cell c){ return c.tabCnt>level; }
//"processElasticTabs".print;
  while(1){
    //search the islands
    while(rows.length && !tabCntGood(rows[0])) rows = rows[1..$];
    int n; while(n<rows.length && tabCntGood(rows[n])) n++;
    if(!n) break;
    auto range = rows[0..n];

    auto rightMostTabPos = range.map!(r => r.tabPos(level)).maxElement;

    foreach(row; range){
      auto tIdx = row.tabIdx[level],
           tab = cast(Glyph)(row.subCells[tIdx]),
           delta = rightMostTabPos-(tab.outerRight);

      if(delta){
        tab.innerSize.x += delta;

        //todo: itt ha tordeles van, akkor ez szar.
        foreach(g; row.subCells[tIdx+1..$]) g.outerPos.x += delta;
//        row.innerSize.x += delta;
      }

      if(VisualizeTabColors){
        tab.bkColor = avg(clWhite, clRainbow[level%$]); //debug coloring
      }

    }
    processElasticTabs(range, level+1); //recursive

    //writeln(range.map!(a => a.tabCnt));

    rows = rows[n..$];//advance
  }
}


class Row : Container { // Row ////////////////////////////////////

  //for Elastic tabs
  private int[] tabIdxInternal;

  override int[] tabIdx() { return tabIdxInternal; }

  this(T:Cell)(T[] cells){
    append(cast(Cell[])cells);
  }

  this(string markup, TextStyle ts = tsNormal){
    bkColor = ts.bkColor;
    this.appendMarkupLine(markup, ts);
  }

  this(in TextStyle ts){
    bkColor = ts.bkColor;
  }

  private void solveFlexAndMeasureAll(bool autoWidth){
    //print("solveFlex ", subCells.count, autoWidth);

    float flexSum = 0;
    bool doFlex;
    if(!autoWidth){
      flexSum = subCells.calcFlexSum;
      doFlex = flexSum>0;
    }

    //print("flexSum", flexSum, doFlex);

    if(doFlex){
      //calc remaining space from nonflex cells
      float remaining = innerWidth;
      foreach(sc; subCells) if(!sc.flex){
        if(auto co = cast(Container)sc) co.measure; //measure nonflex
        remaining -= sc.outerWidth;
      }

      //distrubute among flex cells
      if(remaining>AlignEpsilon){
        remaining /= flexSum;
        foreach(sc; subCells) if(sc.flex){
          sc.outerWidth = sc.flex*remaining;
          if(auto co = cast(Container)sc) co.measure; //measure flex
        }
      }
    }else{ //no flex
      foreach(sc; subCells){
        if(auto co = cast(Container)sc) co.measure; //measure all
      }
    }
  }

  private auto makeWrappedLines(bool doWrap){
    //print(subCells.length, "iw", innerWidth, "dw", doWrap);

    //align/spread horizontally
    size_t iStart = 0;
    auto cursor = V2f.Null;
    float maxLineHeight = 0;
    WrappedLine[] wrappedLines;

    void lineEnd(size_t iEnd){
      wrappedLines ~= WrappedLine(subCells[iStart..iEnd], cursor.y, maxLineHeight);

      cursor = V2f(0, cursor.y+maxLineHeight);
      maxLineHeight = 0;
      iStart = iEnd;
    }

    const limit = innerWidth + AlignEpsilon;
    for(size_t i=0; i<subCells.length; i++){ auto subCell = subCells[i];
      //It is illegal to use \n here. Make a new Row instead!

      //wrap
      if(doWrap && cursor.x>0 && cursor.x+subCell.outerWidth > limit){

        if(1){ //WordWrap: go back to a space
          bool failed;
          auto j = i; while(j>iStart && !isWhite(subCells[j])){
            j--;
            if(j==iStart || subCells[j].outerPos.y != cursor.y){ failed = true; break; }
          }
          if(!failed){
            i = j; subCell = subCells[i];
          }
        }

        lineEnd(i);
      }

      subCell.outerPos = cursor;
      cursor.x += subCell.outerWidth;
      maxLineHeight.maximize(subCell.outerHeight);
    }
    if(subCells.length) lineEnd(subCells.length);

    return wrappedLines;
  }

  override void measure(){
    const autoWidth  = innerSize.x==0,
          autoHeight = innerSize.y==0,
          doWrap = flags.canWrap && !autoWidth;

    //print("  rm begin", subCells.length, innerSize, "flex:", flex, "canWrap:", flags.canWrap, "autoWidth:", autoWidth, "doWrap,", doWrap);
    //scope(exit) print("  rm end", subCells.length, innerSize, "flex:", flex, flags.canWrap, doWrap);

    //adjust length of leading and internal tabs
    foreach(int idx, tIdx; tabIdx){
      const isLeading = idx==tIdx;
      subCells[tIdx].innerSize.x *= (isLeading ? LeadingTabScale : InternalTabScale);
    }

    solveFlexAndMeasureAll(autoWidth);

    auto wrappedLines = makeWrappedLines(doWrap);

    //hide spaces on the sides by wetting width to 0. This needs for size calculation.
    //todo: don't do this for the line being edited!!!
    if(doWrap && !flags.dontHideSpaces) wrappedLines.hideSpaces(flags.hAlign);

    //horizontal alignment, sizing
    if(autoWidth ) innerSize.x = wrappedLines.calcWidth; //set actual size if automatic

    //horizontal text align on every line
    //todo: clip or stretch
    if(!autoWidth || wrappedLines.length>1) foreach(ref wl; wrappedLines){
      final switch(flags.hAlign){
        case HAlign.left    : break;
        case HAlign.center  : wl.alignX(innerSize.x, 0.5); break;
        case HAlign.right   : wl.alignX(innerSize.x, 1  ); break;
        case HAlign.justify : wl.justifyX(innerSize.x); break;
      }
    }

    //vertical alignment, sizing
    if(autoHeight){
      innerSize.y = wrappedLines.calcHeight;
      //height is calculated, no remaining space, so no align is needed
    }else{
      //height is fixed
      auto remaining = innerSize.y - wrappedLines.calcHeight;
      if(remaining > AlignEpsilon){
        final switch(flags.vAlign){
          case VAlign.top         : break;
          case VAlign.center      : wrappedLines.alignY(innerSize.y, 0.5); break;
          case VAlign.bottom      : wrappedLines.alignY(innerSize.y, 1.0); break;
          case VAlign.justify     : wrappedLines.justifyY(innerSize.y); break;
        }
      }else if(remaining < AlignEpsilon){
        //todo: clipping/scrolling
      }
    }

    //vertical cell align in each line
    if(flags.yAlign != YAlign.top)foreach(ref wl; wrappedLines){
      final switch(flags.yAlign){
        case YAlign.top         : break;
        case YAlign.center      : wl.alignY(0.5); break;
        case YAlign.bottom      : wl.alignY(1.0); break;
        case YAlign.baseline    : wl.alignY(0.8); break;
      }
    }


  }

}

class Column : Container { // Column ////////////////////////////////////

  override void parse(string s, TextStyle ts = tsNormal){
    beep;
    if(s.startsWithTag("li")){ //lame
      import het.ui;
      append(newListItem(s, ts));
    }else{
      append(new Row(s, ts));
    }
  }

  override void measure(){
    bool autoWidth  = innerSize.x==0;
    bool autoHeight = innerSize.y==0;

    //fixed width or autoWidth
    if(autoWidth){
      //measure maxWidth
      measureSubCells;
      innerWidth = subCells.map!"a.outerWidth".maxElement(0);
    }

    //set uniform widths for all cells of the column
    //todo: this is too much, and should be optional. What's with containers with explicit width?!
    foreach(sc; subCells){
      sc.outerWidth = innerWidth; //set the width of every subcell in this column
      if(auto co = cast(Container)sc) co.measure; //width changed, need a new measure
    }

    //process flexible items
    if(!autoHeight){
      auto flexSum = subCells.calcFlexSum;

      if(flexSum > 0){
        //calc remaining space from nonflex cells
        float remaining = innerHeight - subCells.filter!"!a.flex".map!"a.outerHeight".sum;

        //distrubute among flex cells
        if(remaining > AlignEpsilon){
          remaining /= flexSum;
          foreach(sc; subCells) if(sc.flex){
            sc.outerHeight = sc.flex*remaining;
            if(auto co = cast(Container)sc) co.measure; //height changed, measure again
          }
        }
      }
    }

    subCells.spreadV;

    processElasticTabs(subCells);

    innerSize = subCells.maxOuterSize;
  }
}
