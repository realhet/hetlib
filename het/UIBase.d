module het.uibase;

import het.utils, het.geometry, het.draw2d, het.bitmap, het.win, het.opengl,
  het.keywords/*apply syntax*/,
  het.megatexturing : DefaultFont_subTexIdxMap;

import std.bitmanip: bitfields;

// enums/constants ///////////////////////////////////////

//adjust the size of the original Tab character
enum
  VisualizeContainers      = 0,
  VisualizeGlyphs          = 0,
  VisualizeTabColors       = 0,
  VisualizeHitStack        = 0;

//todo: bug: NormalFontHeight = 18*4  -> RemoteUVC.d crashes.
immutable DefaultFontName = //this is the cached font
  "Segoe UI"
//  "Lucida Console"
//  "Consolas" <- too curvy
;

immutable
  NormalFontHeight = 18;  //fucking keep it on 18!!!!

enum
  InternalTabScale = 0.12f/2,  //around 0.15 for programming
  LeadingTabScale  = 0.12f*3;  //these are relative to the original length which is 8 spaces or something like that

immutable
  EmptyCellWidth  = 0,
  EmptyCellHeight = 0,
  EmptyCellSize   = vec2(EmptyCellWidth, EmptyCellHeight);

private enum
  AlignEpsilon = .001f; //avoids float errors that come from float sums of subCell widths/heights


// Global shit //////////////////////////////

//todo: these ugly things are only here to separate uiBase for ui.

__gshared RGB function() g_actFontColorFunct;

auto actFontColor(){
  return enforce(g_actFontColorFunct , "initialize g_actFontColor!")();
}

__gshared float function() g_actFontHeightFunct;

auto actFontHeight(){
  return enforce(g_actFontHeightFunct , "initialize g_actFontHeight!")();
}

__gshared Drawing function(Container) g_getOverlayDrawingFunct;

auto getOverlayDrawing(Container cntr){
  return enforce(g_getOverlayDrawingFunct, "g_getOverlayDrawingFunct")(cntr);
}

void rememberEditedWrappedLines(Row row, WrappedLine[] wrappedLines){
  import het.ui: im;
  if(im.textEditorState.row is row)
    im.textEditorState.wrappedLines = wrappedLines;
}

void drawTextEditorOverlay(Drawing dr, Row row){
  import het.ui: im;
  if(im.textEditorState.row is row){
    dr.translate(row.innerPos);
    im.textEditorState.drawOverlay(dr, clWhite-row.bkColor);
    dr.pop;
  }
}


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

private vec2 calcGlyphSize_clearType(in TextStyle ts, int stIdx){
  auto info = textures.accessInfo(stIdx);

  float aspect = float(info.width)/(info.height*3/*clearType x3*/); //opt: rcp_fast
  auto size =  vec2(ts.fontHeight*aspect, ts.fontHeight);

  if(ts.bold) size.x += size.y*(BoldOffset*2);

  return size;
}

private vec2 calcGlyphSize_image(/*in TextStyle ts,*/ int stIdx){
  auto info = textures.accessInfo(stIdx);

//  float aspect = float(info.width)/(info.height); //opt: rcp_fast
  auto size =  vec2(info.width, info.height);

  //image frame goes here

  return size;
}

// NEW! ------------------------> ImStorage /////////////////////////////

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

struct HitInfo{ //Btn returns it
  uint id;
  bool enabled = true;
  bool hover, captured, clicked, pressed, released;
  float hover_smooth, captured_smooth;
  bounds2 hitBounds; // this is in ui coordinates. Problematic with zoomable and GUI views.

  @property bool clickedAndEnabled() const{ return clicked & enabled; }
  alias clickedAndEnabled this;

  bool repeated() const{ return captured && inputs.LMB.repeated; }
}

struct HitTestManager{

  struct HitTestRec{
    uint hash;            //in the next frame this must be the isSame
    bounds2 hitBounds;   //absolute bounds on the drawing where the hittesi was made, later must be combined with View's transformation
    vec2 localPos;
  }

  //act frame
  HitTestRec[] hitStack, lastHitStack;
  uint[void*] cellHashMap;

  float[uint] smoothHover;
  private void updateSmoothHover(ref HitTestRec[] actMap){
    enum upSpeed = 0.5f, downSpeed = 0.25f;

    auto act = actMap.map!"a.hash".filter!"a";  //todo: refactor this

    foreach(h; act)
      smoothHover[h] = mix(smoothHover.get(h, 0.0f), 1, upSpeed);

    uint[] toRemove;
    foreach(h; smoothHover.keys){
      if(!act.canFind(h)){
        if(h in smoothHover){
          smoothHover[h] = mix(smoothHover[h], 0, downSpeed);
          if(smoothHover[h]<0.02f) toRemove ~= h; //todo: test if it is allowed to remove from az assoc array while iterating on it's keys
        }
      }
    }

    foreach(h; toRemove) smoothHover.remove(h);
  }

// -------- SliderInfo - a base to store historical data for every control //////////////////////////////
/*  struct SliderInfo{
    bounds2 localRect; //mouse is from hittest.local
    bool expired;
  }

  SliderInfo[uint] sliderInfo;

  void addSliderInfo(uint id, in bounds2 localRect){
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

    with(cast(GLWindow)mainWindow){ //todo: get the mouse state from elsewhere!!!!!!!!!!!!!
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

  void addHitRect(Cell cell, bounds2 hitBounds, vec2 localPos){//it is called automatically from each cell
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
    return idx<0 ? bounds2()
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

  auto check(uint id){
    HitInfo h;
    h.id = id;
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

  void draw(Drawing dr){
    if(VisualizeHitStack){
      dr.lineWidth = (QPS*3).fract;
      dr.color = clFuchsia;

      foreach(hr; hitStack)
        dr.drawRect(hr.hitBounds);

      dr.lineWidth = 1;
      dr.lineStyle = LineStyle.normal;
    }
  }

  auto stats(){
    return format("HitTest lengths: hitStack:%s, lastHitStack::%s, cellHashMap:%s, smoothHover::%s", hitStack.length, lastHitStack.length, cellHashMap.length, smoothHover.length);
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
[x] border: should be a struct: lineStyle, width, color
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

[ ]   core.cpuid; ez lehetne a teszt

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

  bool isDefaultFont() const{ return font == DefaultFontName; } //todo: slow. 'font' Should be a property.

  void modify(string[string] map){
    map.rehash;
    if(auto p="font"       in map) font          = (*p);
    if(auto p="fontHeight" in map) fontHeight    = (*p).toWidthHeight(actFontHeight).iround.to!ubyte;
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


//https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-getsyscolor
const
      clChapter                 = RGB(221,   3,  48),
      clAccent                  = RGB(0  , 120, 215),
      clMenuBk                  = RGB(240, 240, 241),
      clMenuHover               = RGB(222, 222, 222),
      clLink                    = RGB(0  , 120, 215),

      clLinkHover               = RGB(102, 102, 102),
      clLinkPressed             = RGB(153, 153, 153),
      clLinkDisabled            = RGB(122, 122, 122), // clWinBtnHoverBorder

      clWinRed                  = RGB(232,17,35),

      clWinText                 = clBlack,
      clWinBackground           = clWhite,
      clWinFocusBorder          = clBlack,
      clWinBtn                  = RGB(204, 204, 204),
      clWinBtnHoverBorder       = RGB(122, 122, 122),
      clWinBtnPressed           = clWinBtnHoverBorder,
      clWinBtnDisabledText      = clWinBtnHoverBorder,

      clHintText                = clWinText,
      clHintBk                  = RGB(236, 233, 216),
      clHintDetailsText         = clWinText,
      clHintDetailsBk           = clWhite,

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
  ubyte rfh(float r){ return (NormalFontHeight*(r/18.0)).iround.to!ubyte; }


  a("normal"      , tsNormal  , TextStyle(DefaultFontName, rfh(18), false, false, false, false, clBlack, clWhite));
  a(  "larger"    , tsLarger  , tsNormal, { tsLarger.fontHeight = rfh(22); });
  a(  "smaller"   , tsSmaller , tsNormal, { tsSmaller.fontHeight = rfh(14); });
  a(  "half"      , tsHalf    , tsNormal, { tsHalf.fontHeight = rfh(9); });
  a(  "comment"   , tsComment , tsNormal, { tsComment.fontHeight = rfh(12); });
  a(  "error"     , tsError   , tsNormal, { tsError.bold = tsError.underline = true; tsError.bkColor = clRed; tsError.fontColor = clYellow; });
  a(  "bold"      , tsBold    , tsNormal, { tsBold.bold = true; });
  a(    "bold2"   , tsBold2   , tsBold  , { tsBold2.fontColor = clChapter; });
  a(  "quote"     , tsQuote   , tsNormal, { tsQuote.italic = true; });
  a(  "code"      , tsCode    , tsNormal, { tsCode.font = "Lucida Console"; tsCode.fontHeight = rfh(18); tsCode.bold = false; }); //todo: should be half bold?
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

void spreadH(Cell[] cells, in vec2 origin = vec2(0)){
  float cx = origin.x;
  foreach(c; cells){
    c.outerPos = vec2(cx, origin.y);
    cx += c.outerWidth;
  }
}

void spreadV(Cell[] cells, in vec2 origin = vec2(0)){
  float cy = origin.y;
  foreach(c; cells){
    c.outerPos = vec2(origin.x, cy);
    cy += c.outerHeight;
  }
}

float maxOuterWidth (Cell[] cells, float def = EmptyCellWidth ) { return cells.empty ? def : cells.map!"a.outerWidth" .maxElement; }
float maxOuterHeight(Cell[] cells, float def = EmptyCellHeight) { return cells.empty ? def : cells.map!"a.outerHeight".maxElement;}

float maxOuterRight (Cell[] cells, float def = EmptyCellWidth ) { return cells.empty ? def : cells.map!"a.outerRight" .maxElement; }
float maxOuterBottom(Cell[] cells, float def = EmptyCellWidth ) { return cells.empty ? def : cells.map!"a.outerBottom" .maxElement; }

vec2 maxOuterSize(Cell[] cells, vec2 def = EmptyCellSize) { return vec2(maxOuterRight(cells, def.x), maxOuterBottom(cells, def.y)); }

float totalOuterWidth (Cell[] cells, float def = EmptyCellWidth ) { return cells.empty ? def : cells.map!"a.outerWidth" .sum; }
float totalOuterHeight(Cell[] cells, float def = EmptyCellHeight) { return cells.empty ? def : cells.map!"a.outerHeight".sum;}

float calcFlexSum(Cell[] cells) { return cells.map!"a.flex".sum; }

bool isWhite(const Cell c){ auto g = cast(const Glyph)c; return g && g.isWhite; }




struct Padding{  //Padding, Margin ///////////////////////////////////////////////////
  //alias all this; not working that way

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

  bool inset;  //border has a size inside gap and margin
  float ofs = 0; //border is offsetted by ofs*width
  bool extendBottomRight; //for grid cells

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


  bounds2 adjustBounds(in bounds2 bb){
    bounds2 res = bb;
    if(extendBottomRight)with(res.high){ x += width; y += width; }
    return res;
  }
}

auto toLineStyle(BorderStyle bs){
  with(BorderStyle) switch(bs){
    case dot:         return LineStyle.dot;
    case dash:        return LineStyle.dash;
    case dashDot:     return LineStyle.dashDot;
    case dash2:       return LineStyle.dash2;
    case dashDot2:    return LineStyle.dashDot2;
    default: return LineStyle.normal;
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

/+  static shared int[string] objCnt;  //todo: ha ez nem shared, akkor beszarik a hatterben betolto jpeg. Miert?
  this(){
//    auto n = this.classinfo.name;
//    if(n !in objCnt) objCnt[n]=0;
//    objCnt[n]++;
  }

  ~this(){
//    auto n = this.classinfo.name;
//    objCnt[n]--;
    //ennek qrvara sharednek kell lennie, mert a gc akarmelyik threadbol mehet.
    //egy atomic lenne a legjobb
  } +/

  vec2 outerPos, innerSize;

  ref _FlexValue flex() { static _FlexValue nullFlex; return nullFlex   ; } //todo: this is bad, but fast. maybe do it with a setter and const ref.
  ref Margin  margin () { static Margin  nullMargin ; return nullMargin ; }
  ref Border  border () { static Border  nullBorder ; return nullBorder ; }
  ref Padding padding() { static Padding nullPadding; return nullPadding; }

  float extraMargin()       const { return (VisualizeContainers && cast(Container)this)? 3:0; }
  vec2 topLeftGapSize()     const { with(cast()this) return vec2(margin.left +extraMargin+border.gapWidth+padding.left , margin.top   +extraMargin+border.gapWidth+padding.top   ); }
  vec2 bottomRightGapSize() const { with(cast()this) return vec2(margin.right+extraMargin+border.gapWidth+padding.right, margin.bottom+extraMargin+border.gapWidth+padding.bottom); }
  vec2 totalGapSize()       const { return topLeftGapSize + bottomRightGapSize; }

  @property{ //accessing the raw values as an lvalue
    //version 1: property setters+getters. No += support.
    /*
    auto outerX     () const { return outerPos.x; } void outerX(float v) { outerPos.x = v; }
    auto outerY     () const { return outerPos.y; } void outerY(float v) { outerPos.y = v; }
    auto innerWidth () const { return innerSize.x; } void innerWidth (float v) { innerSize.x = v; }
    auto innerHeight() const { return innerSize.y; } void innerHeight(float v) { innerSize.y = v; }
    */

    //version 2: "auto ref const" and "auto ref" lvalues. Better but the code is redundant.
    auto ref const outerX     () { return outerPos .x; }    auto ref outerX     () { return outerPos .x; }
    auto ref const outerY     () { return outerPos .y; }    auto ref outerY     () { return outerPos .y; }
    auto ref const innerWidth () { return innerSize.x; }    auto ref innerWidth () { return innerSize.x; }
    auto ref const innerHeight() { return innerSize.y; }    auto ref innerHeight() { return innerSize.y; }
  }

  @property{ //calculated prioperties. No += operators are allowed.

    //todo: ezt at kell irni, hogy az outerSize legyen a tarolt cucc, ne az inner. Indoklas: az outerSize kizarolag csak az outerSize ertek atriasakor valtozzon meg, a border modositasatol ne. Viszont az autoSizet ekkor mashogy kell majd detektalni...
    vec2 innerPos () const { return outerPos+topLeftGapSize; } void innerPos(in vec2 p){ outerPos = p+topLeftGapSize; }
    vec2 outerSize() const { return innerSize+totalGapSize; } void outerSize(in vec2 s){ innerSize = s-totalGapSize; }
    auto innerBounds() const { return bounds2(innerPos, innerPos+innerSize); }
    void innerBounds(in bounds2 b) { innerPos = b.low; innerSize = b.size; }
    auto outerBounds() const { return bounds2(outerPos, outerPos+outerSize); }
    void outerBounds(in bounds2 b) { outerPos = b.low; outerSize = b.size; }

    auto outerBottomRight() { return outerPos+outerSize; }

    auto borderBounds(float location=0.5f)(){
      auto hb = border.width*location;
      return bounds2(outerPos+vec2(margin.left+extraMargin+hb, margin.top+extraMargin+hb), outerBottomRight-vec2(margin.right+extraMargin+hb, margin.bottom+extraMargin+hb));
    }
    auto borderBounds_inner() { return borderBounds!1; }
    auto borderBounds_outer() { return borderBounds!0; }

    auto innerX     () const { return outerPos.x+topLeftGapSize.x; } void x(float v) { outerPos.x = v-topLeftGapSize.x; }
    auto innerY     () const { return outerPos.y+topLeftGapSize.y; } void y(float v) { outerPos.y = v-topLeftGapSize.y; }
    auto outerWidth () const { return innerSize.x+totalGapSize.x; } void outerWidth (float v) { innerSize.x = v-totalGapSize.x; }
    auto outerHeight() const { return innerSize.y+totalGapSize.y; } void outerHeight(float v) { innerSize.y = v-totalGapSize.y; }
    auto outerRight () const { return outerX+outerWidth; }
    auto outerBottom() const { return outerY+outerHeight; }
    auto innerCenter() const { return innerPos + innerSize*.5f; }

    alias size = innerSize;
    alias width = innerWidth;
    alias height = innerHeight;
  }

  bounds2 getHitBounds() { return borderBounds_outer; } //Used by hittest. Can override.

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
  void clearSubCells() { }
  @property Cell[] subCells() { return []; }
  @property void subCells(Cell[] cells) { notImpl("setSubCells"); }

  void append(Cell   c){ notImpl("append()"); }
  void append(Cell[] a){ notImpl("append()"); }

  void draw(Drawing dr) { }

  //append Glyphs
  void appendImg (File  fn, in TextStyle ts){ append(new Img(fn, ts.bkColor)); }    //todo: ezeknek az appendeknek a Container-ben lenne a helyuk
  void appendChar(dchar ch, in TextStyle ts){ append(new Glyph(ch, ts)); }
  void appendStr (string s, in TextStyle ts){ foreach(ch; s.byDchar) appendChar(ch, ts); }

  //elastic tabs
  int[] tabIdx() { return []; }
  int tabCnt() { return cast(int)tabIdx.length; } //todo: int -> size_t
  float tabPos(int i) { with(subCells[tabIdx[i]]) return outerRight; }

/* advanced insert delete. Not needed for IMGUI
  void insert(Cell[] ins, int at=int.max, int del=0, Cell[]* cutCells=null) { notImpl("modifySubCells() not implemented"); }
  void append(Cell[] c)         { insert(c); }
  void delete_(int at, int cnt) { insert([], at, cnt); }
  Cell[] cut(int at, int cnt)   { Cell[] res; insert([], at, cnt, &res); }*/

  bool internal_hitTest(in vec2 mouse, vec2 ofs=vec2(0)){ //todo: only check when the hitTest flag is true
    auto bnd = getHitBounds + ofs;
    if(bnd.contains!"[)"(mouse)){
      hitTestManager.addHitRect(this, bnd, mouse-outerPos);
      return true;
    }else{
      return false;
    }
  }

  ///this hitTest is only works after measure.
  Tuple!(Cell, vec2)[] contains(in vec2 p, vec2 ofs=vec2.init){
    Tuple!(Cell, vec2)[] res;

    if((outerBounds+ofs).contains!"[)"(p))
      res ~= tuple(this, ofs);

    return res;
  }

  final void drawBorder(Drawing dr){
    if(!border.width || border.style == BorderStyle.none) return;

    auto bw = border.width, bb = borderBounds;
    dr.lineStyle = border.style.toLineStyle;
    dr.color = border.color;
    dr.lineWidth = bw * (border.style==BorderStyle.double_ ? 0.33f : 1);

    if(border.ofs){ auto o = border.ofs *= bw; bb = bb.inflated(o, o); }
    bb = border.adjustBounds(bb);

    void doit(float sh=0){
      const m = bw*sh;
      auto r = bb.inflated(m, m);
      if(r.width<=0 || r.height<=0){
        dr.line(r.topLeft, r.bottomRight); //todo: just a line. Used for Spacer, but it's wrond, because it goes negative
      }else{
        dr.drawRect(r);
      }
    }

    if(border.style==BorderStyle.double_){ doit(-0.333f); doit(0.333f); }
                                     else{ doit;                        }
  }
}


class Img : Container { // Img ////////////////////////////////////
  int stIdx;

  this(File fn){
    stIdx = textures[fn];
  }

  this(File fn, RGB bkColor){
    this.bkColor = bkColor;
    this(fn);
  }

  override void draw(Drawing dr){
    drawBorder(dr);

    dr.drawFontGlyph(stIdx, innerBounds, bkColor, 16/*image*/);
  }

  override void measure_impl(){
    //note: this is a Container and has the measure() method, so it can be resized by a Column or something. Unlike the Glyph which has constant size.
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

enum ShapeType{ led }

class Shape : Cell{ // Shape /////////////////////////////////////
  ShapeType type;
  RGB color;

/*  this(T)(ShapeType shapeType, RGB color, T state, float fontHeight){
    this.type = shapeType;
    this.color = color;
    innerSize = vec2(fontHeight*.5, fontHeight);
  }*/

  override void draw(Drawing dr){
    final switch(type){
      case ShapeType.led:{
        auto r = min(innerWidth, innerHeight)*0.92f;


        auto p = innerCenter;

        dr.pointSize = r;       dr.color = RGB(.3, .3, .3);  dr.point(p);
        dr.pointSize = r*.8f;   dr.color = color;   dr.point(p);
        dr.pointSize = r*0.4f;  dr.alpha = 0.4f; dr.color = clWhite; dr.point(p-vec2(1,1)*(r*0.15f));
        dr.pointSize = r*0.2f;  dr.alpha = 0.4f; dr.color = clWhite; dr.point(p-vec2(1,1)*(r*0.18f));
        dr.alpha = 1;

      break;}
    }
  }
}

class Glyph : Cell { // Glyph ////////////////////////////////////
  int stIdx;

  int fontFlags; //todo: compress information
  bool isWhite, isTab, isNewLine, isReturn; //needed for wordwrap and elastic tabs
  RGB fontColor, bkColor;

  dchar ch;

  this(dchar ch, in TextStyle ts){
    this.ch = ch;

    //tab is the isSame as a space
    isTab = ch==9;
    isWhite = isTab || ch==32;
    isNewLine = ch==10;
    isReturn = ch==13;         //todo: ezt a boolean mess-t kivaltani. a chart meg el kene tarolni. ossz 16byte all rendelkezeser ugyis.

    if(VisualizeGlyphs){
      if(isReturn) ch = 0x240D;else
      if(isNewLine) ch = 0x240A; //0x23CE;
    }else{
      if(isReturn || isNewLine) ch = ' ';
    }

    // ch -> subTexIdx lookup. Cached with a map.   10 FPS -> 13..14 FPS
    void lookupSubTexIdx(){
      string glyphSpec = `font:\`~ts.font~`\72\x3\?`~[ch].toUTF8;
      stIdx = textures[File(glyphSpec)];
    }

    if(ts.isDefaultFont){ // cached version for the default font
      if(auto p = ch in DefaultFont_subTexIdxMap){
        stIdx = *p;
      }else{
        lookupSubTexIdx;
        DefaultFont_subTexIdxMap[ch] = stIdx;
      }
    }else{ //uncached for non-default fonts
      lookupSubTexIdx;
    }

    fontFlags = ts.fontFlags;
    fontColor = ts.fontColor;
    bkColor = ts.bkColor;

    innerSize = calcGlyphSize_clearType(ts, stIdx);

    if(!VisualizeGlyphs) if(isReturn || isNewLine) innerWidth = 0;
  }

  override void draw(Drawing dr){
    drawBorder(dr); //todo: csak a containernek kell border elvileg, ez hatha gyorsit.
    dr.color = fontColor;
    dr.drawFontGlyph(stIdx, innerBounds, bkColor, fontFlags);

    if(VisualizeGlyphs){
      dr.color = clGray;
      dr.lineStyle = LineStyle.normal;
      dr.lineWidth = 0.16f*2;
      dr.line2(innerBounds);

      if(isTab){
        dr.lineWidth = innerHeight*0.04f;
        dr.line2(ArrowStyle.vector, innerBounds.leftCenter, innerBounds.rightCenter);
      }else if(isWhite){
        dr.drawX(innerBounds);
      }
    }
  }

  override string toString() { return format!"Glyph(%s, %s, %s)"(ch.text.quoted, stIdx, outerBounds); }
}

enum WrapMode { clip, wrap, shrink } //todo: break word, spaces on edges, tabs vs wrap???

union ContainerFlags{ //todo: do this nicer with a table
  ulong _data = 0b0_001_0_1_0_0_0_0_0_0_0_001_00_00_1; //todo: ui editor for this
  mixin(bitfields!(
    bool          , "canWrap"           , 1,
    HAlign        , "hAlign"            , 2,  //alignment for all subCells
    VAlign        , "vAlign"            , 2,
    YAlign        , "yAlign"            , 3,
    bool          , "dontHideSpaces"    , 1,  //useful for active edit mode
    bool          , "canSelect"         , 1,
    bool          , "focused"           , 1,  //maintained by system, not by user
    bool          , "hovered"           , 1,  //maintained by system, not by user
    bool          , "clipChildren"      , 1,
    bool          , "_saveComboBounds"  , 1,  //marks the container to save the absolute bounds to align the popup window to.
    bool          , "_hasOverlayDrawing", 1,
    bool          , "columnElasticTabs" , 1, //Column will do ElasticTabs its own Rows.
    bool          , "rowElasticTabs"    , 1, //Row will do elastic tabs inside its own WrappedLines.
    uint          , "targetSurface"     , 1, // 0: zoomable view, 1: GUI screen
    bool          , "_debug"            , 1, // the container can be marked, for debugging
    bool          , "btnRowLines"       , 1, // draw thin, dark lines between the buttons of a btnRow
    bool          , "_measured"         , 1, // used to tell if a top level container was measured already
    int           , ""                  , 11,
  ));

  //todo: setProps, mint a margin-nal
}


// TextPos ///////////////////////////////////////////////////

/*
Text editing.

Problemas dolgok:
- wrapping
- 3 fele pozicio meghatarozas szovegen belul:

  TextPosition{
    TextIndex     : int
    TextLineCol   : { int line, int col; }
    TextXY        : { float x, float y0, float y1; }  //y0 and y1 covers the whole wrappedLine.height
  }

  TextRange{ TextPosition p0, p1; }

*/


/// TextPos marks a specific place inside a text.

struct TextPos{
  enum Type { none, idx, lc, xy }

  private{
    Type type;
    int fIdx, fLine, fColumn; //todo: union
    vec2 fPoint;
    float fHeight=0;

    void enforceType(string file = __FILE__, int line = __LINE__)(Type t) const{
      if(t!=type) throw new Exception("TextPos type mismatch error. %s required.".format(t), file, line);
    }
  }

  this(int idx                   ){ type = Type.idx ;  fIdx   = idx  ;                     }
  this(int line, int column      ){ type = Type.lc  ;  fLine  = line ;  fColumn = column; }
  this(in vec2 point, float height){ type = Type.xy  ;  fPoint = point;  fHeight = height;  }

  bool valid() const{ return type != Type.none; }
  bool isIdx() const{ return type == Type.idx ; }
  bool isLC () const{ return type == Type.lc  ; }
  bool isXY () const{ return type == Type.xy  ; }

  auto idx   (string file = __FILE__, int line = __LINE__)() const{ enforceType!(file, line)(Type.idx); return fIdx   ; }
  auto line  (string file = __FILE__, int lin_ = __LINE__)() const{ enforceType!(file, lin_)(Type.lc ); return fLine  ; }
  auto column(string file = __FILE__, int line = __LINE__)() const{ enforceType!(file, line)(Type.lc ); return fColumn; }
  auto point (string file = __FILE__, int line = __LINE__)() const{ enforceType!(file, line)(Type.xy ); return fPoint ; }
  auto height(string file = __FILE__, int line = __LINE__)() const{ enforceType!(file, line)(Type.xy ); return fHeight; }

  string toString() const{
    string s;
    with(Type) final switch(type){
      case none: s = "none"; break;
      case idx : s = format!"idx = %s"(idx); break;
      case lc  : s = format!"line = %s, column = %s"(line, column); break;
      case xy  : s = format!"point = (%.1f, %.1f), height = %.1f"(point.x, point.y, height); break;
    }
    return Unqual!(typeof(this)).stringof ~ "(" ~ s ~ ")";
  }
}

/// a linearly selected range of text.
struct TextRange{
  TextPos st, en;
}

struct EditCmd{ // EditCmd ////////////////////////////////////////
  private enum _intParamDefault = int.min+1,
               _pointParamDefault = vec2(-1e30, -1e30);

  enum Cmd {
    //caret commands              //parameters
    nop,
    cInsert,                      //text to insert
    cDelete, cDeleteBack,         //number of glyphs to delete. Default 1
    cLeft, cRight,                //number of repetitions. Default 1
    cUp, cDown,
    cHome, cEnd,
    cMouse                        //caret goes to mouse
  }
  alias cmd this;

  Cmd cmd;
  int _intParam = _intParamDefault;
  vec2 _pointParam = _pointParamDefault;

  //parameter access
  string strParam;
  int intParam(int def=0) const{ return _intParam==_intParamDefault ? def : _intParam; }
  vec2 pointParam(in vec2 def=vec2(0)) const{ return _pointParam==_pointParamDefault ? def : _pointParam; }

  this(T...)(Cmd cmd, T args){
    this.cmd = cmd;
    static foreach(a; args){
      static if(isSomeString!(typeof(a))) strParam = a;
      static if(isIntegral  !(typeof(a))) _intParam = a;
      static if(is(const typeof(a) == ConstOf!vec2)) _pointParam = a;
    }
  }

  auto toString() const{
    auto s = format!"EditCmd(%s"(cmd);
    if(_intParam != _intParamDefault) s ~= " " ~ _intParam.text;
    if(strParam.length) s ~= " " ~ strParam.text;
    if(_pointParam != _pointParamDefault) s ~= " " ~ format!"(%.1f, %.1f)"(pointParam.x, pointParam.y);
    return s ~ ")";
  }
}

/// All the information needed for a text editor
struct TextEditorState{ // TextEditorState /////////////////////////////////////
  string str;                   //the string being edited                       Edit() fills it
  float defaultFontHeight;      //used when there's no text to display 0 -> uibase.NortmalFontHeight
  int[] cellStrOfs;             //mapping petween glyphs and string ranges      Edit() fills it

  Row row;                      //editor container. Must be a row.              Edit() fills it
  WrappedLine[] wrappedLines;   //formatted glyphs                              Measure fills it when edit is same as wrappedLines

  bool strModified;             //string is modified, and it is needed to reformat.
                                //cellStrOfs and wrappedLines are invalid.

  TextPos caret;                //first there is only one caret, no selection   persistent

  EditCmd[] cmdQueue;           //commands waiting for execution                Edit() fills, it is proecessed after the hittest

  string dbg;

  /// Must be called before a new frame. Clears data that isn't safe to keep from the last frame.
  void beginFrame(){
    row = null;
    wrappedLines = null;
    cellStrOfs = null;
    defaultFontHeight = NormalFontHeight;
  }

  bool active()                 const { return row !is null; }

  //access helpers
  auto cells()                  { return row.subCells; }
  int cellCount()               { return cast(int)cells.length; }
  int wrappedLineCount()        { return cast(int)wrappedLines.length; }
  int clampIdx(int idx)         { return idx.clamp(0, cellCount); }

  // raw caret conversion routines

  private int lc2idx(int line, int col){
    if(line<0) return 0; //above first line
    if(line>=wrappedLines.length) return cellCount; //below last line

    int baseIdx = wrappedLines[0..line].map!(l => l.cellCount).sum; //todo: opt
    int clampedColumn = col.clamp(0, wrappedLines[line].cellCount);
    return clampIdx(baseIdx + clampedColumn);
  }

  private int lc2idx(in ivec2 colLine){ with(colLine) return lc2idx(y, x); }

  private ivec2 xy2lc(in vec2 point){
    if(wrappedLines.empty) return ivec2(0);

    float yMin = wrappedLines[0].top,
          yMax = wrappedLines[$-1].bottom,
          y = point.y;

    static if(1){ //above or below: snap to first/last line or start/end of the whole text.
      if(y<yMin) return ivec2(0);
      if(y>yMax) return ivec2(wrappedLineCount-1, wrappedLines[wrappedLineCount-1].cellCount);
    }else{ //other version: just clamp it to the nearest
      y = tp.point.y.clamp(yMin, yMax);
    }

    //search the line
    int line; //opt: binary search? (not important: only 1 screen of information)
    foreach_reverse(int i; 0..wrappedLineCount){
      if(y >= wrappedLines[i].y0){ line = i; break; }
    }

    auto wl = &wrappedLines[line];

    float xMin = wl.left,
          xMax = wl.right,
          x = point.x;

    x = x.clamp(xMin, xMax); //always clamp x coordinate

    int column;

/*    if(x >= xMax){
      column = wl.cellCount; //last char past 1
    }else if(x <= xMin){
      column = 0;
    }else{
      //search the column in the line
      foreach_reverse(int i; 0..wl.cellCount){
        if(x >= wl.cells[i].outerPos.x){ column = i; break; }
      }
    }*/

    column = wl.selectNearestGap(x);

    return ivec2(column, line);
  }

  private int xy2idx(in vec2 point){ return lc2idx(xy2lc(point)); }

  private ivec2 idx2lc(int idx){
    if(idx<=0 || cellCount==0) return ivec2(0, 0);

    int col = idx;
    if(idx < cellCount) foreach(int line; 0..wrappedLineCount){
      const count = wrappedLines[line].cellCount;
      if(col < count)
        return ivec2(col, line);
      col -= count;
    }

    return ivec2(wrappedLines[$-1].cellCount, wrappedLineCount); //The cell after the last.
  }

  TextPos toIdx(in TextPos tp){
    if(!tp.valid) return tp;

    if(!cellCount) return TextPos(0);                          // empty
    if(tp.isIdx  ) return TextPos(clampIdx(tp.idx));           // no need to convert, only clamp the idx.
    if(tp.isLC   ) return TextPos(lc2idx(tp.line, tp.column)); //
    if(tp.isXY   ) return TextPos(xy2idx(tp.point));           // first convert to the nearest LC, then that to Idx
    return TextPos(0);                                         // when all fails
  }

  TextPos toLC(in TextPos tp){
    if(!tp.valid) return tp;

    if(!cellCount) return TextPos(0, 0);
    if(tp.isLC   ) return tp;
    if(tp.isIdx  ) with(idx2lc(tp.idx)) return TextPos(y, x);
    if(tp.isXY   ) with(idx2lc(xy2idx(tp.point))) return TextPos(y, x);
    return TextPos(0, 0); //when all fails
  }

  TextPos toXY(in TextPos tp){
    if(!tp.valid) return tp;

    if(!cellCount) return TextPos(vec2(0, 0), defaultFontHeight);
    if(tp.isXY   ) return tp;

    TextPos lc;
    if(tp.isIdx  ) lc = toLC(tp);
    if(tp.isLC   ) lc = tp;    //todo: more error checking

    int line = lc.line.clamp(0, wrappedLineCount-1);
    int col = lc.column.clamp(0, wrappedLines[line].cellCount);
    bool isRight;
    if(col == wrappedLines[line].cellCount){
      col--;
      isRight = true;
    }

    auto cell = wrappedLines[line].cells[col];  //todo: refactor
    auto pos = vec2(cell.outerPos.x + (isRight ? cell.outerWidth : 0), wrappedLines[line].top);
    return TextPos(pos, wrappedLines[line].height);
  }

  string execute(EditCmd eCmd){  //returs: "" success:  "error msg" when fail

    void checkConsistency(){
      enum e0 = "textEditorState consistency check fail: ";
      enforce(row !is null                                              , e0~"row is null"   );
      enforce(cellStrOfs.length == cellCount+1                          , e0~"invalid cellStrOfs"  );
      enforce(wrappedLines.map!(l => l.cellCount).sum == cellCount      , e0~"invalid wrappedLines");
    }

    void caretRestrict(){
      //todo: this should work all the 3 types of carets: idx, lc and xy
      int i  = toIdx(caret).idx,
          mi = 0,
          ma = cellCount;

      bool wrong = i<mi || i>ma;
      if(wrong) caret = TextPos(i<mi ? mi : ma);
    }

    void caretMoveAbs(int idx){
      caret = TextPos(idx);
      caretRestrict;
    }

    void caretMoveRel(int delta){
      caretMoveAbs(toIdx(caret).idx + delta);
    }

    void caretMoveVert(int delta){
      if(!delta) return;
      auto c = toXY(caret);

      caret = toIdx(TextPos(vec2(c.point.x, c.point.y + c.height*.5 + c.height*delta), 0)); //todo: it only works for the same fontHeight and  monospaced stuff
      caretRestrict;
    }

    void caretAdjust(ref TextPos caret, int idx, int delLen, int insLen, int insOffset=0){ //insOffset is 1 for selection.left
      int cIdx = toIdx(caret).idx;

      //adjust for deletion.
      //if it is right of idx, then it goes left by delLen, towards idx
      if(cIdx > idx) cIdx = max(cIdx-delLen, idx);

      //adjust for insertion
      if(cIdx >= idx+insOffset) cIdx += insLen;

      caret = TextPos(cIdx);
      caretRestrict; //failsafe
    }

    void modify(int idx, int delLen, string ins){

      int fullLen = cellCount;

      //if idx is after the end, pull it back
      idx.minimize(fullLen);

      //if idx is below the start, move it to 0, also make the deleteCount smaller
      if(idx<0){ delLen -= idx; idx = 0; }

      //clamp delLen
      int maxDelLen = fullLen-idx;
      delLen.minimize(maxDelLen);
      delLen.maximize(0);

      if(delLen<=0 && ins=="") return; //exit if nothing happens

      auto insLen = countMarkupLineCells(ins); //cellcount can be adjusted by this, but the wrappedLines is ruined now.

      //adjust the caret
      caretAdjust(caret, idx, delLen, insLen);

      //make the new modified string
      auto left  = str[0..cellStrOfs[idx]],
           right = str[cellStrOfs[idx+delLen]..$];
      str = left ~ ins ~ right;

      //invalidate the formatted data
      strModified = true;
    }

    void deleteAtCaret(bool isBackSpace){
      caretRestrict;
      int i = toIdx(caret).idx;

      if(isBackSpace && i<=0) return; //nothing to delete

      modify(i-isBackSpace, 1, "");
    }

    //---------------------------------------------
    string err;

    checkConsistency;

    with(eCmd) final switch(cmd){
      case Cmd.nop: break;
      case Cmd.cInsert          : caretRestrict; modify(toIdx(caret).idx, 0, strParam); break;
      case Cmd.cDelete          : deleteAtCaret(false); break;
      case Cmd.cDeleteBack      : deleteAtCaret(true ); break;
      case Cmd.cLeft            : caretMoveRel(-intParam(1)); break;
      case Cmd.cRight           : caretMoveRel( intParam(1)); break;
      case Cmd.cUp              : caretMoveVert(-intParam(1)); break;
      case Cmd.cDown            : caretMoveVert( intParam(1)); break;
      case Cmd.cHome            : caretMoveAbs(        0); break;
      case Cmd.cEnd             : caretMoveAbs(cellCount); break;
      case Cmd.cMouse           : caret = toIdx(TextPos(pointParam, 0)); break;
      //todo: cMouse pontatlan.
      //todo: minden cursor valtozaskor a caret legyen teljesen fekete
    }

    return err;
  }

  string processQueue(){
    string err;

    while(cmdQueue.length){
      //check if the command can be executed.
      if(strModified) break; //string is modified, needs to reformat first.

      auto cmd = cmdQueue.front;
      cmdQueue.popFront;

      err ~= execute(cmd);
    }

    dbg = format("caret: %s  %s  %s\n", toIdx(caret), toLC(caret), toXY(caret))
        ~ wrappedLines.map!(l => l.text).join("\n");

    return err;
  }

  void drawOverlay(Drawing dr, RGB color){
    auto c = toXY(caret);
    if(c.valid){
      dr.color = color;
      dr.lineWidth = sqr(1-(QPS*1.5).fract)*2.5;//sin((QPS*1.5).fract*PI*2).remap(-1, 1, 0.1, 2);

      dr.vLine(c.point.x, c.point.y, c.point.y+c.height);
    }
  }
}


/*int opCmp(in TextPoint a, in TextPoint b){   //b-a
  auto l = b.line-a.line;
  return l ? l : b.col-a.col;
}*/

// Selection struct //
/+
struct Selection{ //selection of cells in a container.
  TextPoint[2][] sel; //s[0]==s[1] -> it's a caret.  s[0]>s[1]: nothing,  s[0]<s[1]: selection

  void clear(){ sel = []; }

/*todo:  bool isSelected(in TextPoint i){ //is a cell selected?
    return sel.map!(s => s[0]<=i && i<s[1]).any;
  }

  bool isCaret(in TextPoint i){ //is there a caret on the left?
    return sel.map!(s => s[0]==i && s[0]==s[1]).any;
  }*/
}+/

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

  Cell removeLast() {
    enforce(subCells_.length);
    auto res = subCells_[$-1];
    subCells_ = subCells_[0..$-1];
    return res;
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
    void clearSubCells(){ subCells_ = []; }
    @property Cell[] subCells() { return subCells_; }
    @property void subCells(Cell[] cells) { subCells_ = cells; }

    void append(Cell   c){ if(c !is null) subCells_ ~= c; }
    void append(Cell[] a){ subCells_ ~= a; }
  }

  final void measure(){
    measure_impl;
    flags._measured = true;
  }

  protected void measure_impl(){
    bool autoWidth  = innerSize.x==0;
    bool autoHeight = innerSize.y==0;

    measureSubCells;

    if(autoWidth ) innerWidth  = subCells.map!(c => c.outerRight ).maxElement(0);
    if(autoHeight) innerHeight = subCells.map!(c => c.outerBottom).maxElement(0);
  }

  protected void measureSubCells(){
    foreach(sc; subCells) if(auto co = cast(Container)sc) co.measure; //recursive in the front
  }

  override bool internal_hitTest(in vec2 mouse, vec2 ofs=vec2(0)){
    if(super.internal_hitTest(mouse, ofs)){
      ofs += innerPos;
      foreach(sc; subCells) sc.internal_hitTest(mouse, ofs); //recursive
      flags.hovered = true;
      return true;
    }else{
      flags.hovered = false;
      return false;
    }
  }

  ///this hitTest is only works after measure.
  override Tuple!(Cell, vec2)[] contains(in vec2 p, vec2 ofs=vec2.init){
    auto res = super.contains(p, ofs);

    if(res.length){
      ofs += innerPos;
      foreach(sc; subCells){
        auto act = sc.contains(p, ofs);
        if(act.length){
          res ~= act;
          break;
        }
      }
    }

    return res;
  }


  static bounds2 _savedComboBounds; //when saveComboBounds flag is active it saves the absolute bounds

  override void draw(Drawing dr){
    //todo: automatic measure when needed. Currently it is not so well. Because of elastic tabs.
    //if(chkSet(measured)) measure;

    //autofill background
    dr.color = bkColor;          //todo: refactor backgorund and border drawing to functions
    //dr.alpha = 0.1;

    dr.fillRect(border.adjustBounds(borderBounds_inner));
    //dr.alpha = 1;

    if(flags._saveComboBounds) _savedComboBounds = dr.inputTransform(outerBounds);

    dr.translate(innerPos);
    if(flags.clipChildren) dr.pushClipBounds(bounds2(0, 0, innerWidth, innerHeight));

    foreach(sc; subCells){
      sc.draw(dr); //recursive
    }

    if(flags._hasOverlayDrawing)
      dr.copyFrom(getOverlayDrawing(this));

    if(flags.btnRowLines && subCells.length>1){
      dr.color = clWinText; dr.lineWidth = 1; dr.alpha = 0.25f;
      foreach(sc; subCells[1..$])
        dr.vLine(sc.outerX, sc.outerY+sc.margin.top+.25f, sc.outerY+sc.outerHeight-sc.margin.bottom-.25f);
      dr.alpha = 1;
    }

    if(flags.clipChildren) dr.popClipBounds;
    dr.pop;

    drawBorder(dr); //border is the last

    if(VisualizeContainers){
      if(cast(Column)this){ dr.color = clRed; }
      else if(cast(Row)this){ dr.color = clBlue; }
      else dr.color = clGray;

      dr.lineWidth = 1;
      dr.lineStyle = LineStyle.normal;
      dr.drawRect(outerBounds.inflated(-1.5));
    }


  }

// these can mixed in

  mixin template CachedMeasuring(){
    bool measured;

    override void measure_impl(){
      WARN("Ezt felulvizsgalni, mert van mar flags._measured is!!!");
      if(measured.chkSet) super.measure_impl;
    }
  }

  mixin template CachedDrawing(){
    Drawing cachedDrawing;

    override void draw(Drawing dr){
      if(dr.isClone){
        super.draw(dr); //prevent recursion
        //print("Drawing recursion prevented");
      }else{
        if(!cachedDrawing){
          cachedDrawing = dr.clone;
          super.draw(cachedDrawing);
        }
        dr.subDraw(cachedDrawing);
      }
    }
  };


  struct SearchResult{
    Container container;
    vec2 absInnerPos;
    Cell[] cells;

    auto cellBounds(){ return cells.map!(c => c.outerBounds + absInnerPos); }
    auto bounds(){ return cellBounds.fold!"a|b"; }

    void drawHighlighted(Drawing dr, RGB clHighlight){
      foreach(cell; cells)if(auto glyph = cast(Glyph)cell) with(glyph){
        dr.color = bkColor;
        dr.drawFontGlyph(stIdx, innerBounds + absInnerPos, clHighlight, fontFlags);
      }
    }
  }

  /// Search for a text recursively in the Cell structure
  auto search(string searchText, vec2 origin = vec2.init){

    struct SearchContext{
      dstring searchText;
      vec2 absInnerPos;
      Cell[] cellPath;

      SearchResult[] results;
      int maxResults = 9999;

      bool canStop() const { return results.length >= maxResults; }
    }

    static bool cntrSearchImpl(Container thisC, ref SearchContext context){  //returns: "exit from recursion"
      //recursive entry/leave
      context.cellPath ~= thisC;
      context.absInnerPos += thisC.innerPos;

      scope(exit){
        context.absInnerPos -= thisC.innerPos;
        context.cellPath.popBack;
      }

    //print("enter");

      Cell[] cells = thisC.subCells;
      size_t baseIdx;
      foreach(isGlyph, len; cells.map!(c => cast(Glyph)c !is null).group){
        auto act = cells[baseIdx..baseIdx+len];

        if(!isGlyph){
          foreach(c; act.map!(c => cast(Container)c).filter!"a"){
            if(cntrSearchImpl(c, context)) return true; //end recursive call
          }
        }else{
          auto chars = act.map!(c => (cast(Glyph)c).ch);

    //print("searching in", chars.text);

          size_t searchBaseIdx = 0;
          while(1){
            auto idx = chars.indexOf(context.searchText, No.caseSensitive);
            if(idx<0) break;

            context.results ~= SearchResult(thisC, context.absInnerPos, cells[baseIdx+searchBaseIdx+idx..$][0..context.searchText.length]);
            if(context.canStop) return true;

            const skip = idx + context.searchText.length;
            chars.popFrontExactly(skip);
            searchBaseIdx += skip;
          }
        }

    //readln;
    //print("advance", len);
        baseIdx += len;
      }

      return false;
    }

    auto context = SearchContext(searchText.to!dstring, origin);
    if(!searchText.empty)
      cntrSearchImpl(this, context);
    return context.results;
  }

}

// markup parser /////////////////////////////////////////

void processMarkupCommandLine(Container container, string cmdLine, ref TextStyle ts){
  if(cmdLine==""){
    ts = tsNormal;
  }else if(auto t = cmdLine in textStyles){ //standard style.  Should be mentioned by an index
    ts = **t; //now it is a copy;
  }else{
    try{
      auto params = cmdLine.commandLineToMap;
      auto cmd = params.get("0", "");
      if(cmd=="row"   ){
        auto a = new Row(params["1"], tsNormal);
        a.setProps(params);
        container.append(a);
      }else if(cmd=="img"){
        auto img = new Img(File(params["1"]), ts.bkColor);
        img.setProps(params);
        container.append(img);
      }else if(cmd=="char"   ){
        container.appendChar(dchar(params["1"].toInt), ts);
      }else if(cmd=="symbol"    ){
        auto name = params["1"];
        auto ch = segoeSymbolByName(name);
        auto oldFont = ts.font;
        ts.font = "Segoe MDL2 Assets";
        container.appendChar(ch, ts);
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
        /*import het.ui: Link;
        container.append(new Link(params["1"], 0, false, null));*/
        raise("not impl");
      }else if(cmd=="btn" || cmd=="button"   ){
        /*auto btn = new Clickable(params["1"], 0, false, null);
        btn.setProps(params);
        append(btn);*/
        raise("not impl");
      }else if(cmd=="key" || cmd=="keyCombo"  ){
        /*import het.ui: KeyComboOld;
        auto kc = new KeyComboOld(params["1"]);
        kc.setProps(params);
        container.append(kc);*/
        raise("not impl");
      }else if(cmd=="style"){ //textStyle
        ts.modify(params);
      }else if(cmd=="prop" || cmd=="props"){ //container's properties
        container.setProps(params);
      }else{
        //try to set container properties

        throw new Exception(`Unknown command: "%s"`.format(cmd));
      }
    }catch(Throwable t){
      container.appendStr("["~t.msg~": "~cmdLine~"]", tsError);
    }
  }
}

int countMarkupLineCells(string markup){
  try{
    auto cntr = new Row(markup);
    return cast(int)cntr.subCells.length;
  }catch(Throwable){
    return 0;
  }
}

void appendMarkupLine(Container cntr, string s, ref TextStyle ts){
  int[] dummy;
  appendMarkupLine!(false)(cntr, s, ts, dummy);
}

void appendMarkupLine(bool returnSubCellStrOfs=true)(Container cntr, string s, ref TextStyle ts, ref int[] subCellStrOfs){
  enum CommandStartMarker = '\u00B6',
       CommandEndMarker   = '\u00A7';

  int inCommand;
  string commandLine;

  static if(returnSubCellStrOfs) subCellStrOfs = [0]; //the first implicit offset.

  //foreach(ch; s.byDchar){ //todo: dchar ch;s test
  int currentOfs;
  size_t numCodeUnits;

  while(s.length){
    auto ch = s.decodeFront!(Yes.useReplacementDchar)(numCodeUnits);

    static if(returnSubCellStrOfs) currentOfs += cast(int)numCodeUnits;

    if(ch==CommandStartMarker){ //handle start marker
      if(inCommand) commandLine ~= ch; //only if already in a command, not the first one
      inCommand++;
    }else if(ch==CommandEndMarker){ //handle end marker
      enforce(inCommand>0, "Unexpected command end marker");
      if(inCommand>1) commandLine ~= ch; //dont append level 1 end marker
      if(!(--inCommand)){
        cntr.processMarkupCommandLine(commandLine, ts);
        commandLine = "";

        static if(returnSubCellStrOfs) while(subCellStrOfs.length <= cntr.subCells.length) subCellStrOfs ~= currentOfs; //COPY!
      }
    }else{
      if(inCommand){ //collect command
        commandLine ~= ch;
      }else{ //process text
        cntr.appendChar(ch, ts);

        static if(returnSubCellStrOfs) while(subCellStrOfs.length <= cntr.subCells.length) subCellStrOfs ~= currentOfs; //PASTE!!!
      }
    }

  }
}

/**
Append syntax highlighted source code to a container (normally a Row).
Params:
        cntr =          the container being updated
        text =          the input text
        syntax =        byte array of syntax indices
        applySyntax =   delegate to apply a syntax index to the TextStyle
        ts =            reference to the TextStyle used while appending all the characters
 */
void appendCode(TC:Container)(TC cntr, string text, in ubyte[] syntax, void delegate(ubyte) applySyntax, ref TextStyle ts)
in(text.length == syntax.length)
{
  size_t numCodeUnits, currentOfs;
  ubyte lastSyntax = 255;

  while(text.length){
    auto actSyntax = syntax[currentOfs];
    auto ch = text.decodeFront!(Yes.useReplacementDchar)(numCodeUnits);
    currentOfs += numCodeUnits;

    if(chkSet(lastSyntax, actSyntax)) applySyntax(actSyntax);

    cntr.appendChar(ch, ts);
  }
}

/// Lookup a syntax style and apply it to a TextStyle reference
void applySyntax(ref TextStyle ts, uint syntax, SyntaxPreset preset)
in(syntax<syntaxTable.length)
{
  auto fmt = &syntaxTable[syntax].formats[preset];
  ts.fontColor = fmt.fontColor;
  ts.bkColor   = fmt.bkColor;
  ts.bold      = fmt.fontFlags.getBit(0);
  ts.italic    = fmt.fontFlags.getBit(1);
  ts.underline = fmt.fontFlags.getBit(2);
}

/// Shorthand with global default preset
void applySyntax(ref TextStyle ts, uint syntax){
  applySyntax(ts, syntax, defaultSyntaxPreset);
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

  int cellCount() const{ return cast(int)cells.length; }

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

  void stretchY(){
    foreach(c; cells) c.outerHeight = height;
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

  /// functions for text selections
  int selectNearestGap(float x){ //x: local x coordinate. (innerPos.x = 0)
    if(cells.empty) return 0;
    foreach(i, c; cells) if(x<c.outerPos.x + c.outerWidth*.5f) return cast(int)i;
    return cellCount;
  }

  int selectNearestCell(float x){ //always select something on either side
    if(cells.empty) return 0;
    foreach_reverse(i, c; cells) if(x >= c.outerPos.x) return cast(int)i;
    return 0;
  }

  auto selectCellsInRange(float x0, float x1){ //cell only need to touch the range
    int lo = 0, hi = 0;
    sort(x0, x1);
    if(cells.empty || x1<cells[0].outerPos.x || x0>cells[$-1].outerRight) return tuple(lo, hi); //no intersection

    foreach(i, c; cells) if(x0 <= c.outerRight){ lo = cast(int)i; break; }
    foreach_reverse(i, c; cells) if(x1 >= c.outerPos.x){ hi = cast(int)i+1; break; }

    return tuple(lo, hi);
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

    foreach(ref l; lines){
      l.translateY(act);
      act += step;
    }
  }

  void hideSpaces(WrappedLine[] lines, HAlign hAlign){ foreach(l; lines) l.hideSpaces(hAlign); }

}


// Elastic Tabs //////////////////////////////////////////
void processElasticTabs(Cell[] rows, int level=0){
  bool tabCntGood(Cell row){ return row.tabCnt > level; }

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

    rows = rows[n..$];//advance
  }
}

//todo: this WrappedLine tab processing is terribly unoptimal
private bool isTab(in Cell c){
  if(const g = cast(Glyph)c) return g.isTab;
                        else return false;
}

private int tabCnt(in WrappedLine wl){
  return cast(int) wl.cells.count!(c => c.isTab);
}

private int tabIdx(in WrappedLine wl, int i){
  int j;
  foreach(idx, const cell; wl.cells){
    if(cell.isTab){
      if(j==i) return cast(int) idx;
      j++;
    }
  }
  return -1;
}

float tabPos(WrappedLine wl, int i) { with(wl.cells[wl.tabIdx(i)]) return outerRight; }

void processElasticTabs(WrappedLine[] rows, int level=0){
  bool tabCntGood(in WrappedLine wl){ return wl.tabCnt > level; }       //!!!!!!!!!!!!!!!!

  while(1){
    //search the islands
    while(rows.length && !tabCntGood(rows[0])) rows = rows[1..$];
    int n; while(n<rows.length && tabCntGood(rows[n])) n++;
    if(!n) break;
    auto range = rows[0..n];

    auto rightMostTabPos = range.map!(r => r.tabPos(level)).maxElement;

    foreach(row; range){
      auto tIdx = row.tabIdx(level),
           tab = cast(Glyph)(row.cells[tIdx]),
           delta = rightMostTabPos-(tab.outerRight);

      if(delta){
        tab.innerSize.x += delta;

        //todo: itt ha tordeles van, akkor ez szar.
        foreach(g; row.cells[tIdx+1..$]) g.outerPos.x += delta;
//        row.innerSize.x += delta;
      }

      if(VisualizeTabColors){
        tab.bkColor = avg(clWhite, clRainbow[level%$]); //debug coloring
      }

    }
    processElasticTabs(range, level+1); //recursive

    rows = rows[n..$];//advance
  }
}


class Row : Container { // Row ////////////////////////////////////

  //for Elastic tabs
  private int[] tabIdxInternal;

  override int[] tabIdx() { return tabIdxInternal; }

  this(){
  }

  this(string markup, TextStyle ts = tsNormal){
    bkColor = ts.bkColor;
    appendMarkupLine(this, markup, ts);
  }

  this(T:Cell)(T[] cells,in TextStyle ts){
    bkColor = ts.bkColor;
    append(cast(Cell[])cells);
  }

  override void appendChar(dchar ch, in TextStyle ts){
    if(ch==9) tabIdxInternal ~= cast(int)subCells.length; //Elastic Tabs
    super.appendChar(ch, ts);
  }

  private void solveFlexAndMeasureAll(bool autoWidth){
    float flexSum = 0;
    bool doFlex;
    if(!autoWidth){
      flexSum = subCells.calcFlexSum;
      doFlex = flexSum>0;
    }

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
    //align/spread horizontally
    size_t iStart = 0;
    auto cursor = vec2(0);
    float maxLineHeight = 0;
    WrappedLine[] wrappedLines;

    void lineEnd(size_t iEnd){
      wrappedLines ~= WrappedLine(subCells[iStart..iEnd], cursor.y, maxLineHeight);

      cursor = vec2(0, cursor.y+maxLineHeight);
      maxLineHeight = 0;
      iStart = iEnd;
    }

    const limit = innerWidth + AlignEpsilon;
    for(size_t i=0; i<subCells.length; i++){

      auto act(){ return subCells[i]; }
      auto actWidth(){ return act.outerWidth; }
      auto actIsNewLine(){ if(auto g = cast(Glyph)act) return g.isNewLine; else return false; }

      //wrap
      if(actIsNewLine){
        lineEnd(i);
      }else if(doWrap && cursor.x>0 && cursor.x+actWidth > limit){

        if(1){ //WordWrap: go back to a space
          bool failed;
          auto j = i; while(j>iStart && !isWhite(subCells[j])){
            j--;
            if(j==iStart || subCells[j].outerPos.y != cursor.y){ failed = true; break; }
          }
          if(!failed){
            i = j;
          }
        }

        lineEnd(i);
      }

      act.outerPos = cursor; //because of this, newline and wrapped space goes to the next line. This allocates a new wrapped_row for them.
      cursor.x += actWidth;
      maxLineHeight.maximize(act.outerHeight);
    }
    if(subCells.length) lineEnd(subCells.length);

    return wrappedLines;
  }

  /// this works on the Row as if it were a one-liner. This is not the WrappedLines version.
  private void adjustTabSizes_singleLine(){
    foreach(idx, tIdx; tabIdx){
      const isLeading = idx==tIdx; //it's not good for multiline!!!
      subCells[tIdx].innerSize.x *= (isLeading ? LeadingTabScale : InternalTabScale);
    }
  }

  //this handles multiple lines. Must count newline chars too, so the tabIdx[] array is useless here.
  private void adjustTabSizes_multiLine(){  //todo: refactor this
    int tabCnt, colCnt;
    foreach(c; subCells){
      if(auto g = cast(Glyph)c){
        if(g.isNewLine || g.isReturn){ tabCnt = colCnt = 0; continue; }
        else if(g.isTab){
          const isLeading = tabCnt == colCnt;
          c.innerSize.x *= (isLeading ? LeadingTabScale : InternalTabScale);  //copy+paste
          tabCnt++;
        }
      }
      colCnt++;
    }
  }

  override void measure_impl(){
    //print(typeid(this).name, ".measure", width, height); scope(exit) print(typeid(this).name, ".measure", width, height, "END");

    const autoWidth  = innerSize.x==0,
          autoHeight = innerSize.y==0,
          doWrap = flags.canWrap && !autoWidth;

    //adjust length of leading and internal tabs
    if(flags.rowElasticTabs) adjustTabSizes_multiLine;
                        else adjustTabSizes_singleLine;

    solveFlexAndMeasureAll(autoWidth);

    auto wrappedLines = makeWrappedLines(doWrap);

    if(flags.rowElasticTabs) processElasticTabs(wrappedLines);

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
        case YAlign.stretch     : wl.stretchY; break;
      }
    }

    //remember the contents of the edited row
    rememberEditedWrappedLines(this, wrappedLines);
  }

  override void draw(Drawing dr){
    super.draw(dr); //draw frame, bkgnd and subCells

    //draw the carets and selection of the editor
    drawTextEditorOverlay(dr, this);
  }

}

class Column : Container { // Column ////////////////////////////////////

/*  override void parse(string s, TextStyle ts = tsNormal){   //todo: I guess it's deprecated
    beep;
    if(s.startsWithTag("li")){ //lame
      import het.ui;
      append(newListItem(s, ts));
    }else{
      append(new Row(s, ts));
    }
  }*/

  override void measure_impl(){
    //print(typeid(this).name, ".measure", width); scope(exit) print(typeid(this).name, ".measure", width, "END");

    bool autoWidth  = innerSize.x==0;
    bool autoHeight = innerSize.y==0;

    //measure the subCells and stretch them to a maximum width
    if(autoWidth){
      //measure maxWidth
      measureSubCells;
      innerWidth = subCells.map!"a.outerWidth".maxElement(0);

      //at this point all the subCells are measured
      //now set the width of every subcell in this column if it differs, and remeasure only when necessary
      foreach(sc; subCells) if(sc.outerWidth != innerWidth){
        sc.outerWidth = innerWidth;
        if(auto co = cast(Container)sc) co.measure;
      }
      //note: this is not perfectly optimal when autoWidth and fixedWidth Rows are mixed. But that's not an usual case: ListBox: all textCells are fixedWidth, Document: all paragraphs are autoWidth.
    }else{
      foreach(sc; subCells){ //first set the width of every subcell in this column, and measure all (for the first time).
        sc.outerWidth = innerWidth;
        if(auto co = cast(Container)sc) co.measure;
      }
    }

    if(flags.columnElasticTabs) processElasticTabs(subCells); //todo: ez a flex=1 -el egyutt bugzik.

    //process vertically flexible items
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

    const contentSize = autoWidth || autoHeight ? subCells.maxOuterSize : vec2(0);
    bool hScrollNeeded, vScrollNeeded;
    if(autoWidth ) innerSize.x = contentSize.x; else hScrollNeeded = innerSize.x<contentSize.x;
    if(autoHeight) innerSize.y = contentSize.y; else vScrollNeeded = innerSize.y<contentSize.y;

    if(vScrollNeeded || hScrollNeeded){ print(this.identityStr, "scroll needed"); }
  }
}


class SelectionManager(T : Cell){ // SelectionManager ///////////////////////////////////////////////

  //T must have some bool properties:
  static assert(__traits(compiles, { T a;
    a.isSelected  = true;
    a.oldSelected = true;
  }), "Field requirements not met.");

  bounds2 getBounds(T item){ return item.outerBounds; }

  T hoveredItem;

  enum MouseOp { idle, move, rectSelect }
  MouseOp mouseOp;

  vec2 mouseLast;

  enum SelectOp { none, add, sub, toggle, clearAdd }
  SelectOp selectOp;

  vec2 dragSource;
  bounds2 dragBounds;

  bounds2 selectionBounds(){
    if(mouseOp == MouseOp.rectSelect) return dragBounds;
                                 else return bounds2.init;
  }

  void update(bool mouseEnabled, View2D view, T[] items){

    void selectNone()           { foreach(a; items) a.isSelected = false; }
    void selectOnly(T item)     { selectNone; if(item) item.isSelected = true; }
    void selectHoveredOnly()    { selectOnly(hoveredItem); }
    void saveOldSelected()      { foreach(a; items) a.oldSelected = a.isSelected; }

    // acquire mouse positions
    auto mouseAct = view.mousePos;
    auto mouseDelta = mouseAct-mouseLast;
    scope(exit) mouseLast = mouseAct;

    const LMB          = inputs.LMB.down,
          LMB_pressed  = inputs.LMB.pressed,
          LMB_released = inputs.LMB.released,
          Shift        = inputs.Shift.down,
          Ctrl         = inputs.Ctrl.down;

    const modNone       = !Shift && !Ctrl,
          modShift      =  Shift && !Ctrl,
          modCtrl       = !Shift &&  Ctrl,
          modShiftCtrl  =  Shift &&  Ctrl;

    const inputChanged = mouseDelta || inputs.LMB.changed || inputs.Shift.changed || inputs.Ctrl.changed;

    // update current selection mode
    if(modNone      ) selectOp = SelectOp.clearAdd;
    if(modShift     ) selectOp = SelectOp.add;
    if(modCtrl      ) selectOp = SelectOp.sub;
    if(modShiftCtrl ) selectOp = SelectOp.toggle;

    // update dragBounds
    if(LMB_pressed) dragSource = mouseAct;
    if(LMB        ) dragBounds = bounds2(dragSource, mouseAct).sorted;

    //update hovered item
    hoveredItem = null;
    if(mouseEnabled) foreach(item; items) if(getBounds(item).contains!"[)"(mouseAct)) hoveredItem = item;

    if(LMB_pressed && mouseEnabled){ // Left Mouse pressed //
      if(hoveredItem){
        if(modNone){ if(!hoveredItem.isSelected) selectHoveredOnly;  mouseOp = MouseOp.move; }
        if(modShift || modCtrl || modShiftCtrl) hoveredItem.isSelected.toggle;
      }else{
        mouseOp = MouseOp.rectSelect;
        saveOldSelected;
      }
    }

    {// update ongoing things //
      if(mouseOp == MouseOp.rectSelect && inputChanged){
        foreach(a; items) if(dragBounds.contains!"[]"(getBounds(a))){
          final switch(selectOp){
            case SelectOp.add, SelectOp.clearAdd : a.isSelected = true ; break;
            case SelectOp.sub                    : a.isSelected = false; break;
            case SelectOp.toggle                 : a.isSelected = !a.oldSelected; break;
            case SelectOp.none                   : break;
          }
        }else{
          a.isSelected = (selectOp == SelectOp.clearAdd) ? false : a.oldSelected;
        }
      }
    }

    if(mouseOp == MouseOp.move && mouseDelta){
      foreach(a; items) if(a.isSelected){
        a.outerPos += mouseDelta;
        a.cachedDrawing.free;
      }
    }


    if(LMB_released){ // left mouse released //

      //...

      mouseOp = MouseOp.idle;
    }
  }

}
