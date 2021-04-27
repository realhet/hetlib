module het.ui;

import het.utils, het.draw2d, het.inputs, het.stream, het.opengl;

//todo: Unqual is not needed to check a type. Try to push this idea through a whole testApp.

import std.traits, std.meta;

public import het.uibase;

struct clipBoard{ static:
  import core.sys.windows.windows : OpenClipboard, CloseClipboard, IsClipboardFormatAvailable, CF_TEXT, EmptyClipboard, GetClipboardData, SetClipboardData, HGLOBAL, GlobalLock, GlobalUnlock, GlobalAlloc;

  bool hasFormat(uint fmt){
    bool res;
    if(OpenClipboard(null)){ scope(exit) CloseClipboard;
      res = IsClipboardFormatAvailable(fmt)!=0;
    }
    return res;
  }

  bool hasText(){ return hasFormat(CF_TEXT); }

  string getText(){
    string res;
    if(OpenClipboard(null)){ scope(exit) CloseClipboard;
      auto hData = GetClipboardData(CF_TEXT);
      if(hData){
        auto pData = cast(char*)GlobalLock(hData);
        scope(exit) GlobalUnlock(hData);
        res = pData.toStr;
      }
    }
    return res;
  }

  bool setText(string text, bool mustSucceed){
    bool success;
    if(OpenClipboard(null)){ scope(exit) CloseClipboard;
      EmptyClipboard;
      HGLOBAL hClipboardData;
      auto hData = GlobalAlloc(0, text.length+1);
      auto pData = cast(char*)GlobalLock(hData);
      pData[0..text.length] = text[];
      pData[text.length] = 0;
      GlobalUnlock(hClipboardData);
      success = SetClipboardData(CF_TEXT, hData) !is null;
    }
    if(mustSucceed && !success) ERR("clipBoard.setText fail: "~getLastErrorStr);
    return success;
  }

  @property{
    string text(){ return getText; }
    void text(string s){ setText(s, true); }
  }
}


//todo: form resize eseten remeg a viewGUI-ra rajzolt cucc.

//todo: Beavatkozas / gombnyomas utan NE jojjon elo a Button hint. Meg a tobbi controllon se!

// utility stuff ////////////////////////////////

class Document : Column { // Document /////////////////////////////////
  this(){
    bkColor = tsNormal.bkColor;
  }

  string title;
  string[] chapters;
  int[3] actChapterIdx;

  int lastChapterLevel;
  float cy=0;

  void addChapter(ref string s, int level){
    enforce(level.inRange(0, actChapterIdx.length-1), "chapter level out of range "~level.text);
    actChapterIdx[level]++;
    actChapterIdx[level+1..$] = 0;

    s = actChapterIdx[0..level+1].map!(a => (a).text~'.').join ~ " " ~ s;
  }

  ref auto getChapterTextStyle(){
    switch(lastChapterLevel){
      case 0: return tsTitle;
      case 1: return tsChapter;
      case 2: return tsChapter2;
      case 3: return tsChapter3;
      default: return tsBold;
    }
  }

  override void parse(string s, TextStyle ts = tsNormal){
    if(s=="") return;

    int actChapterLevel = 0;

         if(s.startsWithTag("title"   )){ ts = tsTitle   ; actChapterLevel = 1; title = s; }
    else if(s.startsWithTag("chapter" )){ ts = tsChapter ; actChapterLevel = 2; addChapter(s, 0); }
    else if(s.startsWithTag("chapter2")){ ts = tsChapter2; actChapterLevel = 3; addChapter(s, 1); }
    else if(s.startsWithTag("chapter3")){ ts = tsChapter3; actChapterLevel = 4; addChapter(s, 2); }

    //extra space, todo:margins
    if(chkSet(lastChapterLevel, actChapterLevel)) append(new Row(tag("prop height=1x"), tsNormal));

    super.parse(s, ts);
  }

}

// ListItem ////////////////////////////////

Row newListItem(string s, TextStyle ts = tsNormal){
  auto left  = new Row("\u2022", ts);
  left.outerWidth = ts.fontHeight*2;
  left.subCells = new FlexRow("", ts) ~ left.subCells ~ new FlexRow("", ts);

  auto right = new Row(s, ts); right.flex_=1;
  auto act   = new Row([left, right], ts);

  act.bkColor = ts.bkColor;
  return act;
}

class FlexRow : Row{ //FlexRow///////////////////////////////
  this(string markup, TextStyle ts=tsNormal){
    super(markup, ts);
    flex_ = 1;
  }
}

class Link : Row{ //Link ///////////////////////////////

  this(string cmdLine, uint hash, bool enabled, void delegate() onClick, TextStyle ts = tsLink){

    auto hit = im.hitTest(this, hash, enabled);

    if(enabled && onClick !is null && hit.clicked){
      onClick();
    }

    if(!enabled){
      ts.fontColor = clLinkDisabled;
      ts.underline = false;
    }else if(hit.captured){
      ts.fontColor = clLinkPressed;
    }else{
      ts.fontColor = mix(ts.fontColor, clLinkHover, hit.hover_smooth);
      ts.underline = hit.hover;
    }

    flags.wordWrap = false;

    auto params = cmdLine.commandLineToMap;
    super(params["0"], ts);
    setProps(params);
  }
}

/*class Clickable : Row{ //Clickable / ChkBox / RadioBtn ///////////////////////////////

  this(uint id, string markup, TextStyle ts, string[string] params){
    hitTestManager.addHash(this, id);

    flags.wordWrap = false;

    super(markup, ts);
    setProps(params);
  }
} */

class KeyComboOld : Row{ //KeyCombo ///////////////////////////////

  this(string markup, TextStyle ts = tsKey){
    auto allKeys = inputs.entries.values.filter!(e => e.isButton && e.value).array.sort!((a,b)=>a.pressedTime<b.pressedTime, SwapStrategy.stable).map!"a.name".array;

    if(allKeys.canFind(markup)) ts.bkColor = clLime;

    margin_ = Margin(1, 1, 0.75, 0.75);
    padding_ = Padding(2, 2, 0, 0);
    border_.width = 1;
    border_.color = clGray;
    flags.wordWrap = false;

    super(markup, ts);
  }

}


class WinRow : Row{ //WinRow ///////////////////////////////

  this(string markup, TextStyle ts = tsNormal){
    padding_ = Padding(4, 16, 4, 16);

    super(markup, ts);
  }

  this(Cell[] cells, TextStyle ts = tsNormal){
    padding_ = Padding(4, 16, 4, 16);

    super(cells, ts);
  }

  override{
  }
}



//////////////////////////////////////////////////////////////////////////////
/// ImWin  (experimental)                                                  ///
//////////////////////////////////////////////////////////////////////////////


/*  enum FrameItem {
    edgeTop,
    cornerTopRight,
    edgeRight,
    cornerBottomRight,
    edgeBottom,
    cornerBottomLeft,
    edgeLeft,
    cornedTopLeft,

    //optional
    caption,
    close,
    maximize,
    minimize,

    scrollH,
    scrollV
  }*/


struct WinContext{ //WinContext /////////////////////////////
  //appearance
  float frameThickness       = 1.5,  //these values are independent from zoom level, based on dr.pixelSize
        cornerThickness      =   6,
        cornerHighlightRange =  16,
        cornerLength         =  20;
  bool inwardFrame = true;   // moves the frame a slightly inward in order to keep the same distance from other frames at every zoom levels.

  private import ub = het.uibase; //het.uibase,clAccent egyszeruen nem megy.
  RGB clNormal = ub.clWinBackground,
      clAccent = ub.clAccent;//ub.clAccent;

  //runtime updated stuff
  Drawing dr;
  float pixelSize;
  int pass;
  vec2 mouse;
}


struct SizingFrame{
  bounds2 bounds;
  vec2 cornerSize;
  vec2 cornerSize2; //inner with gap added

  seg2[] edge(int idx){ with(bounds){  // top, right, bottom, left
    alias c = cornerSize2;
    switch(idx&3){
      case  0: return [seg2(x0+c.x, y0, x1-c.x, y0)];
      case  2: return [seg2(x0+c.x, y1, x1-c.x, y1)];
      case  1: return [seg2(x1, y0+c.y, x1, y1-c.y)];
      default: return [seg2(x0, y0+c.y, x0, y1-c.y)];
    }
  }}

  seg2[] corner(int idx){ with(bounds){  // topRight, bottomRight, bottomLeft, topLeft
    alias c = cornerSize;
    auto a(float x, float y, float dx, float dy){ return [ seg2(x, y, x+dx*c.x, y), seg2(x, y, x, y+dy*c.y) ]; }
    switch(idx&3){
      case  0: return a(x1, y0, -1,  1);
      case  1: return a(x1, y1, -1, -1);
      case  2: return a(x0, y1,  1, -1);
      default: return a(x0, y0,  1,  1);
    }
  }}

  seg2[][] cornersAndEdges(){
    return iota(8).map!(i => i&1 ? corner(i>>1) : edge(i>>1)).array;
  }
}


auto calcSizingFrame(in bounds2 fullBounds, in WinContext ctx){

  auto calcFrameBounds() { // calculates bounds moved inward
    if(!ctx.inwardFrame) return fullBounds;
    auto a = ctx.pixelSize*ctx.frameThickness,
         aw = min(fullBounds.width *0.25f, a),
         ah = min(fullBounds.height*0.25f, a);

    return fullBounds.inflated(-aw, -ah);
  }

  SizingFrame f;
  f.bounds = calcFrameBounds;
  auto w = f.bounds.width ;
  auto h = f.bounds.height;

  auto maxCornerSize = f.bounds.size * 0.66f;
  auto maxCornerLen = ctx.cornerLength * ctx.pixelSize;
  f.cornerSize = min(vec2(maxCornerLen, maxCornerLen), maxCornerSize);
  auto gapLen = ctx.cornerThickness * ctx.pixelSize * 1.0f;
  f.cornerSize2 = min(f.cornerSize + vec2(gapLen, gapLen), maxCornerSize);

  return f;
}


class ImWin{ // ImWin //////////////////////////////////
  static WinContext ctx; //must update from outside

  bounds2 bounds;
  string caption;
  bool focused;

  this(string caption_, bounds2 bounds_){
    caption = caption_;
    bounds = bounds_;
    adjustBounds;
  }

  vec2 sizeMin = vec2(32, 32);
  vec2 sizeMax;               // ignored if less than sizeMin
  float sizeStep = 0;        // ignored if <=0
  float aspect = 0;          // if nonzero

  vec2 placementBase;
  float placementStep = 0;

  void draw(Drawing dr, in vec2 size){
    dr.color = clGray;
//    dr.fillRect(vec2(0, 0), size);

    auto tex = textures[File(`c:\dl\oida6.png`)];
    dr.drawGlyph(tex, bounds2(vec2(0, 0), size));

    dr.scale(ctx.pixelSize); scope(exit) dr.pop;

    PERF("capt", {
      auto doc = scoped!Column;
      doc.innerWidth = size.x/dr.scaleFactor.x;
      auto icon = "\U0001F4F9";
      auto rIcon = new Row(" "~icon~" ");

      auto clHeaderBackground = clWinBackground;
      auto clHeaderText       = mix(clWinText, clHeaderBackground, focused ? 0 : 0.35f);

      auto toolBtn(string s, RGB textColor=clHeaderText, RGB bkColor=clHeaderBackground){
        return new Row(tag(`style fontColor="%s" bkColor="%s"`.format(textColor, bkColor))~" "~s~" ");
      }

      auto rCaption  = toolBtn(caption);
      auto rMaximize = toolBtn(tag("symbol ChromeMaximize"));
      auto rClose    = toolBtn(tag("symbol ChromeClose"), clWhite, clWinRed);

      auto rPlay     = toolBtn(tag("symbol PlaySolid"), clAccent);
      auto rPause    = toolBtn(tag("symbol Pause"));

      auto rLeft = new Row("");
      rLeft.appendMulti([rIcon, rCaption, rPlay, rPause]);
      rLeft.measure;

      auto rRight = new Row("");
      rRight.appendMulti([rMaximize, rClose]);
      rRight.measure;


      rLeft.draw(dr);
      dr.translate(size.x/dr.scaleFactor.x - rRight.outerWidth, 0);
      rRight.draw(dr);
      dr.pop;
    });
    //perf.report.writeln;
  }

  void adjustBounds(){

    static float adjustPlacement(float a, float base, float step){
      return round((a-base)/step)*step+base;
    }

    static float adjustSize(float a, float min, float max, float step){
      if(a<min) return min; //min is the dominant constrait
      a = adjustPlacement(a, min, step);
      if(max<=min) return a;
      //optional max check
      if(a<=max) return a;
      return round(max-min/step)*step+min;
    }

    bounds = bounds.sorted;
    return;
    float w = bounds.width, h = bounds.height;

    if(aspect>0){
      //tries to make the diagonal az close az can
      auto dBounds = length(vec2(w, h)),
           dAspect = length(vec2(aspect, 1));
      auto dRate =  dBounds/dAspect;

      w = aspect*dRate;
      h = dRate;
    }

    auto newPos  = vec2(adjustPlacement(bounds.low.x, placementBase.x, placementStep),
                       adjustPlacement(bounds.low.y, placementBase.y, placementStep)),
         newSize = vec2(adjustSize(w, sizeMin.x, sizeMax.x, sizeStep),
                       adjustSize(h, sizeMin.y, sizeMax.y, sizeStep));

    //anchor is topLeft
    bounds.low = newPos;
    bounds.high = newPos + newSize;
  }

  void drawFrame(bool focused, ref ImWin hovered){ with(ctx){

    auto sizingFrame = calcSizingFrame(bounds, ctx);
    auto bounds = sizingFrame.bounds;
    this.focused = focused;

    void drawFrameRect(in RGB c){
      dr.color = c;
      dr.lineWidth = -frameThickness;
      dr.drawRect(bounds);
    }

    auto clHalf = mix(clNormal, clAccent, .5f),
         inside = bounds.contains!"[)"(mouse);

    if(pass==0){
      if(inside) hovered = this;

      //draw contents
      dr.translate(bounds.topLeft);
      draw(dr, bounds.size);
      dr.pop;

      if(focused){
        auto elements = sizingFrame.cornersAndEdges;

        dr.lineWidth = -cornerThickness;
        dr.color = mix(clNormal, clAccent, 0.99f);
        foreach(e; elements){
          //dr.line(e);
        }

        drawFrameRect(clAccent);
      }else{//not focused
        drawFrameRect(clNormal);
      }

    }else if(pass==1){

      if(this is hovered && !focused){ //hovered frame always visible
        drawFrameRect(clHalf);
      }
    }
  }}

}

auto testWin(Drawing dr, vec2 mouse, float pixelSize){ // testWin() ///////////////////////////////////////

  static wins = [
    new ImWin("win1", bounds2(0  ,   0, 640, 480)),
    new ImWin("win2", bounds2(640,   0, 640, 480)),
    new ImWin("win3", bounds2(0  , 480, 600, 300)),
  ];

  ImWin hovered;

  ImWin.ctx.dr = dr;
  ImWin.ctx.mouse = mouse;
  ImWin.ctx.pixelSize = pixelSize;

  foreach(pass; 0..2) foreach_reverse(idx, win; wins){
    ImWin.ctx.pass = pass;
    win.drawFrame(idx==0, hovered);
  }
}


//////////////////////////////////////////////////////////////////////////////
/// im: New Composable based stuff                                         ///
//////////////////////////////////////////////////////////////////////////////


struct im{ static:

  //Frame handling
  bool mouseOverUI, wantMouse, wantKeys;
  private bool inFrame, canDraw; //synchronization for internal methods

  // target surface is a view and a drawing
  struct TargetSurface{ View2D view; }
  private TargetSurface[2] targetSurfaces;  //surface0: zoomable view, surface1: GUI view

  void setTargetSurfaceViews(View2D viewWorld, View2D viewGUI){
    targetSurfaces[0].view = viewWorld;
    targetSurfaces[1].view = viewGUI;
  }

  private View2D actView; //this is only used for getting mouse position from actview

  //todo: this should be the only opportunity to switch between GUI and World. Better that a containerflag that is initialized too late.
  private void selectTargetSurface(int n){
    enforce(n.among(0, 1));
    with(targetSurfaces[n]){
      actView = view;
    }
  }

  float deltaTime=0;

  bool comboState; //automatically cleared on focus.change
  bool comboOpening; //popup cant disappear when clicking away and this is set true by the combo
  uint comboId;    //when the focus of this is lost, comboState goes false

  //GUI area that tracks PanelPosition changes
  bounds2 clientArea;

  //todo: package visibility is not working as it should -> remains public
  void _beginFrame(TargetSurface[2] targetSurfaces){ //called from mainform.update
    enforce(!inFrame, "im.beginFrame() already called.");

    this.targetSurfaces = targetSurfaces;
    selectTargetSurface(1); //default is the GUI surface

    //inject stuff into het.uibase. So no import het.ui is needed there.
    static auto getActFontHeight(){ return float(textStyle.fontHeight); }  het.uibase.g_actFontHeightFunct = &getActFontHeight;
    static auto getActFontColor (){ return textStyle.fontColor;         }  het.uibase.g_actFontColorFunct  = &getActFontColor ;
    het.uibase.g_getOverlayDrawingFunct = &getOverlayDrawing;

    //update building/measuring/drawing state
    inFrame = true;
    canDraw = false;

    im.reset;
    //this goes into endFrame, so the latest hit data will be accessible more early. hitTestManager.initFrame;

    //clear last frame's object references
    focusedState.container = null;
    textEditorState.beginFrame;

    popupState.reset;
    comboOpening = false;

    //this is needed for PanelPosition
    clientArea = targetSurfaces[1].view.clipBounds; //Maybe it is the same as the bounds for clipping rects: flags.clipChildren

    static DeltaTimer dt;
    deltaTime = dt.update;
  }

  void _endFrame(){ //called from end of update
    enforce(inFrame, "im.endFrame(): must call beginFrame() first.");
    enforce(stack.length==1, "FATAL ERROR: im.endFrame(): stack is corrupted. 1!="~stack.length.text);

    selectTargetSurface(1); // GUI surface by default

    auto rc = rootContainers(true);
    rc = rc.sort!((a, b) => a.flags.targetSurface < b.flags.targetSurface, SwapStrategy.stable).array;

    //measure
    foreach(a; rc) if(!a.flags._measured) a.measure; //some panels are already have been measured

    const screenBounds = targetSurfaces[1].view.clipBounds;

    //todo: remove this: applyScrollers(screenBounds);

    hScrollInfo.createBars(true);
    vScrollInfo.createBars(true);

    popupState.doAlign;

    //from here, all positions are valid

    //hittest in zOrder (currently in reverse creation order)
    bool[2] mouseOverUI;
    bool mouseOverPopup;
    foreach_reverse(a; rc){
      const surf = a.flags.targetSurface; //1: gui, 0:view

      const uiMousePos = targetSurfaces[surf].view.mousePos;
      if(a.internal_hitTest(uiMousePos)){
        mouseOverUI[surf] = true;

        if(popupState.cell==a)
          mouseOverPopup = true;

        break; //got a hit, so escape now
      }
    }

    //all hitTest are done, move hitTestManager to the next frame. Latest hittest data will be accessible right after this.
    hitTestManager.nextFrame;

    //clicking away from popup closes the popup
    if(comboState && !comboOpening && !mouseOverPopup && (inputs.LMB.pressed || inputs.RMB.pressed))
      comboState = false;

    //the IM GUI wants to use the mouse for scrolling or clicking. Example: It tells the 'view' not to zoom.
    wantMouse = mouseOverUI[1];

    updateScrollers(screenBounds);
    resetScrollers; //needed no more

    if(textEditorState.active){ //an edit control is active.
      //todo: mainWindow.isForeground check
      auto err = textEditorState.processQueue;
    }
    wantKeys = textEditorState.active;

    generateHints(screenBounds);

    //update building/measuring/drawing state
    canDraw = true;
    inFrame = false;
  }

  bounds2[2] surfaceBounds;

  void draw(){
    enforce(canDraw, "im.draw(): canDraw must be true. Nothing to draw now.");

    auto dr = [new Drawing, new Drawing];

    foreach(a; rootContainers(true)){
      a.draw(dr[a.flags.targetSurface]); //draw in zOrder
    }

    foreach(i; 0..2){
      surfaceBounds[i] = dr[i].bounds;
      dr[i].glDraw(targetSurfaces[i].view);
      dr[i].clear;
    }

    if(VisualizeHitStack){
      auto d = new Drawing;
      hitTestManager.draw(d);
      d.glDraw(targetSurfaces[1].view); //todo: problem with hitStack: it is assumed to be on GUI view
      d.free;
    }

    //not needed, gc is perfect.  foreach(r; root) if(r){ r.destroy; r=null; } root.clear;
    //todo: ezt tesztelni kene sor cell-el is! Hogy mekkorak a gc spyke-ok, ha manualisan destroyozok.
  }

  //PanelPosition ///////////////////////////////////////////
  //aligns the container on the screen

  enum PanelPosition{ none, topLeft, topCenter, topRight, leftCenter, center, rightCenter, bottomLeft, bottomCenter, bottomRight,
                                     topClient,           leftClient, client, rightClient,             bottomClient               }

  private bool isAlignPosition (PanelPosition pp){ with(PanelPosition) return pp.inRange(topLeft  , bottomRight ); } //it will only position the container
  private bool isClientPosition(PanelPosition pp){ with(PanelPosition) return pp.inRange(topClient, bottomClient); } //it will change the client rect too

  private void initializePanelPosition(.Container cntr, PanelPosition pp, in bounds2 area){ with(PanelPosition){
    //flags.targetSurface is unknown at this point, will check it later in 'finalize'
    if     (pp.among(client, topClient, bottomClient)) cntr.outerWidth  = area.width ;
    else if(pp.among(client, leftClient, rightClient)) cntr.outerHeight = area.height;
  }}

  private void finalizePanelPosition(.Container cntr, PanelPosition pp, ref bounds2 area){ with(PanelPosition){
    if(pp == none) return;

    enforce(cntr.flags.targetSurface == 1, "Unable to set PanelPosition on world_surface.");

    cntr.measure; //must know all the sizes from now on

    if(isAlignPosition(pp)){
      ivec2 p; divMod(cast(int)pp-1, 3, p.y, p.x);
      if(p.x.inRange(0, 2) && p.y.inRange(0, 2)){
        auto t = p*.5f,
             u = vec2(1)-t;

        cntr.outerPos = area.topLeft*u + area.bottomRight*t //todo: bug: fucking vec2.lerp is broken again
                      - cntr.outerSize*t;
      }
    }else if(isClientPosition(pp)){
      //todo: put checking for running out of area and scrolling here.
      switch(pp){
        case topClient   : cntr.outerPos = area.topLeft    ; area.top     += cntr.outerHeight; break;
        case bottomClient: area.bottom  -= cntr.outerHeight; cntr.outerPos = area.bottomLeft ; break;
        case leftClient  : cntr.outerPos = area.topLeft    ; area.left    += cntr.outerWidth ; break;
        case rightClient : area.right   -= cntr.outerWidth ; cntr.outerPos = area.topRight   ; break;
        case client      : cntr.outerPos = area.topLeft    ; cntr.outerSize = area.size; area = bounds2.init; break;
        default: ERR("invalid PanelPosition");
      }
    }
  }}

  void Panel(T...)(in T args){ //todo: multiple Panels, but not call them frames...
    enforce(actContainer is null, "Panel() must be on root level");

    //todo: this should work for all containers, not just high level ones
    PanelPosition pp;
    static foreach(idx, a; args) static if(is(Unqual!(T[idx]) == PanelPosition)) pp = a;

    .Container cntr;

    Document({
      cntr = actContainer;

      //preparations
      initializePanelPosition(cntr, pp, clientArea); //todo: outerSize should be stored, not innerSize, because the padding/border/margin settings after this can fuck up the alignment.

      //default panel frame
      padding = "4";
      border = "1 normal silver";

      //call the delegates
      static foreach(a; args) static if(__traits(compiles, a())) if(a) a(); //delegate/function
    });

    finalizePanelPosition(cntr, pp, clientArea);
  }

  // Focus handling /////////////////////////////////
  struct FocusedState{
    uint id;              //globally store the current hash
    .Container container;  //this is sent to the Selection/Draw routines. If it is null, then the focus is lost.

    void reset(){ this = typeof(this).init; }
  }
  FocusedState focusedState;

  TextEditorState textEditorState; //maintained by edit control

  void onFocusLost(uint oldId){
    if(comboId && oldId==comboId){
      comboState = false;
      comboId = 0;
    }
  }

  /// internal use only
  bool focusUpdate(.Container container, uint id, bool canFocus, lazy bool enterFocusNow, lazy bool exitFocusNow, void delegate() onEnter, void delegate() onFocused, void delegate() onExit){
    if(focusedState.id==id){
      if(!canFocus || exitFocusNow){ //not enabled anymore: exit focus
        if(onExit) onExit();
        focusedState.reset;

        onFocusLost(id);
      }
    }else{
      if(canFocus && enterFocusNow){ //newly enter the focus
        onFocusLost(focusedState.id);

        focusedState.reset;
        focusedState.id = id;     //todo: ez bugos, mert nem hivodik meg a focusExit, amikor ez elveszi a focust
        focusedState.container = container;
        if(onEnter) onEnter();
      }
    }

    bool res = focusedState.id==id;
    if(res) focusedState.container = container;
    container.flags.focused = res;

    if(res && onFocused) onFocused();

    return res;
  }

  bool isFocused(uint id)               { return focusedState.id                 && focusedState.id == id; }
  bool isFocused(.Container container)  { return focusedState.container !is null && focusedState.container is container; }

//  void focusExit(uint id)               { if(isFocused(id)) focusedState.reset; }
//  void focusExit(Container container)   { if(isFocused(container)) focusedState.reset; }
//  void focusExit()                      { focusedState.reset; }


// OldScrollState, scroller ////////////////////////////////////////////////
  deprecated struct OldScrollState{ //currently it's for y only
    float scrollY = 0;
    float scrollY_smooth = 0;
  }

  deprecated class OldScroller{   //todo: kinetic scrolling
    .Container container, parent;
    OldScrollState* state;

    this(.Container container, .Container parent, ref OldScrollState state){
      this.container = container;
      this.parent = parent;
      this.state = &state;
    }

    void apply(in bounds2 screenBounds){ //must be called first, before update, so the positions are calculated well
      if(state) with(*state){
        float totalHeight = parent ? parent.innerHeight : screenBounds.height;
        float docHeight = container.outerHeight;  //todo: COPY

        if(totalHeight<docHeight){
          container.outerPos.y = scrollY_smooth;
        } //otherwise assume it's aligned properly. Only change the position when it doesn't fit in.
      }
    }

    void update(in bounds2 screenBounds){
      if(state) with(*state){
        float totalHeight = parent ? parent.innerHeight : screenBounds.height;
        float docHeight = container.outerHeight; //todo: PASTE

        if(container.flags.hovered){ //todo: overlapping Panels not handled properly (all of them are scrolling, not just the topmost)
          import het.win;
          scrollY += (cast(GLWindow)mainWindow).mouse.delta.wheel*120; //todo: Window/mouse should it should come from outside
        }

        scrollY = scrollY.clamp(min(0, totalHeight-docHeight), 0);
        scrollY_smooth = mix(scrollY_smooth, scrollY, 0.25f);
        scrollY_smooth = scrollY_smooth.clamp(min(0, totalHeight-docHeight), 0);
      }
    }

  }

  OldScroller[] scrollers;

  auto vScroll(ref OldScrollState state){
    enforce(stack.length>=2);
    //todo: get the bounds from the previous container on the stack
    //todo: handle PanelPosition center/bottom
    //todo: hscroll

    //scroller workflow:
    //1. build: make the scrolling list -> scroll(myScrollState)
    //2. measure
    //3. scrollers.update

    auto idx = scrollers.map!(s => s.container).countUntil(actContainer);
    enforce(idx<0, "Scroller already defined");

    scrollers ~= new OldScroller(actContainer, stack[$-2].container, state);

    return scrollers[$-1];
  }

  auto vScroll(string file=__FILE__ , int line=__LINE__, T...)(T args){ //todo: this is only good for unique panels
    mixin(id.M);
    __gshared static ScrollState[uint] cache;

    if(id_ !in cache) cache[id_] = ScrollState();

    return vScroll(cache[id_]);
  }

  private void applyScrollers(in bounds2 screenBounds){
    foreach(sc; scrollers) sc.apply(screenBounds);
  }

  private void updateScrollers(in bounds2 screenBounds){
    foreach(sc; scrollers) sc.update(screenBounds);
  }

  private void resetScrollers(){
    scrollers = [];
  }

  // hints /////////////////////////////////////////////////////////////////

  const float HintActivate_sec  = 0.5,
              HintDetails_sec   = 2.5,
              HintRelease_sec   = 1  ;

  private struct HintRec{
    .Container owner;
    bounds2 bounds;
    string markup, markupDetails; //todo: support delegates too
  }
  private HintRec[] hints;

  enum HintState { idle, active, details }
  static hintState = HintState.idle;

  /// This can be used to inject a hint into the parameters of a Control
  auto hint(string markup, string markupDetails=""){ //todo: delegate too
    return HintRec(null, bounds2.Null, markup, markupDetails); //todo: lazyness
  }

  void addHint(HintRec hr){ hints ~= hr; }

  void hideHints(){ hintState = HintState.idle; }

  private enum hintHandler = q{
    static foreach(a; args) static if(is(Unqual!(typeof(a)) == HintRec)){
      if(a.markup.length && hit.hover){
        auto hr = a;
        hr.owner = actContainer;
        hr.bounds = hit.hitBounds;
        addHint(hr);
      }
    }
  };

  private void generateHints(in bounds2 screenBounds){ //called on the end of the frame
    static float mouseStopped_secs = 0;
    static float noHint_secs = 0;

    const userBlocking = "Esc,Enter,LMB,RMB,MMB,Space".split(",").map!(k => inputs[k].active).any;

    if(inputs.MX.delta==0 && inputs.MY.delta==0) mouseStopped_secs += deltaTime;
                                            else mouseStopped_secs = 0;

    if(hints.empty) noHint_secs += deltaTime;
               else noHint_secs = 0;

    //enter hint mode
    if(!hints.empty && !userBlocking){
      if(hintState == HintState.idle   && mouseStopped_secs>HintActivate_sec) hintState = HintState.active ;
      if(hintState == HintState.active && mouseStopped_secs>HintDetails_sec ) hintState = HintState.details;
    }

    //exit hint mode
    if(hintState != HintState.idle){
      //immediately hide on particular user events
      if(userBlocking) hideHints;

      //hide after no hints to display for a while
      if(noHint_secs>HintRelease_sec) hideHints;
    }

    //actual hint generation
    HintRec lastHint;
    if(hints.length) lastHint = hints[$-1];
    auto hintOwner = lastHint.owner;

    if(hintState != HintState.idle && hintOwner){
      .Container hintContainer;

      Panel({
        hintContainer = actContainer;
        padding = "0";
        border.color = clGray;

        if(lastHint.markup!="") Row({ //todo: row kell?
          padding = "4";
          style.fontColor = clHintText;
          style.bkColor = bkColor = clHintBk;

          Text(lastHint.markup);
        });
        if(hintState == HintState.details && lastHint.markupDetails!="") Row({
          padding = "4";
          style.fontColor = clHintDetailsText;
          style.bkColor = bkColor = clHintDetailsBk;

          Text(lastHint.markupDetails);
        });

      });

      hintContainer.measure;

      //align the hint
      hintContainer.outerPos = lastHint.bounds.bottomCenter //Bounds.bottomCenter
                             + vec2(-hintContainer.outerWidth*.5, 5);

      //clamp horizontaly
      hintContainer.outerPos.x = clamp(hintContainer.outerPos.x, 0, max(0, screenBounds.width-hintContainer.outerWidth));

      //todo: HintSettings: on/off, hintLocation:nextTo/statusBar/bottomRight, save to ini
    }

    hints = [];
  }

  //! im internal state ////////////////////////////////////////////////////////////////

  Cell[] root; //when containerStack is empty, this is the container

  auto rootContainers(bool forceAll){
    auto res = root.map!(c => cast(.Container)c)
                   .filter!"a"
                   .array;
    if(forceAll) enforce(root.length == res.length, "FATAL ERROR: All of root[] must be a descendant of Container.");
    return res;
  }

  //double QPS=0, lastQPS=0, dt=0;
  //todo: ez qrvara megteveszto igy, jobb azonositokat kell kitalalni QPS helyett

  //todo: ezt egy alias this-el egyszerusiteni. Jelenleg az im-ben is meg az im.StackEntry-ben is ugyanaz van redundansan deklaralva
  .Container actContainer, lastContainer; //top of the containerStack for faster access
  bool enabled;
  uint baseId;
  TextStyle textStyle;   alias style = textStyle; //todo: style.opDispatch("fontHeight=0.5x")
  string theme; //for now it's a str, later it will be much more complex
  //valid valus: "", "tool"

  auto lastCell(T:Cell=Cell)(){
    Cell cell;
    if(actContainer && actContainer.subCells.length) cell = actContainer.subCells[$-1];
    return cast(T)cell;
  }

  private struct StackEntry{ .Container container; uint baseId; bool enabled; TextStyle textStyle; string theme; }
  private StackEntry[] stack;

  void reset(){
    //statck reset
    baseId = 0;
    enabled = true;
    textStyle = tsNormal;
    theme = "";

    root = [];
    stack = [StackEntry(null, 0, enabled, textStyle, theme)];
    actContainer = null;

    overlayDrawings.clear;


    //time calculation
    //todo: jobb neveket kell kitalalni erre
    //QPS = .QPS;
    //dt = lastQPS.isNaN ? 1.0f/60 : QPS-lastQPS;
    //lastQPS = QPS;
  }

  private void push(T : .Container)(T c, uint newId){ //todo: ezt a newId-t ki kell valahogy valtani. im.id-t kell inkabb modositani.
    newId = [newId].xxh(baseId);
    c.id = newId;
    stack ~= StackEntry(c, newId, enabled, textStyle, theme);

    //actContainer is the top of the stack or null
    actContainer = c;
  }

  private void pushNull(){
  }

  private void pop(){
    enforce(stack.length>1); //stack[0] is always null and it is never popped.

    //restore the last textStyle & theme. Changes inside a subHierarchy doesn't count.
    baseId    = stack.back.baseId;
    enabled   = stack.back.enabled;
    textStyle = stack.back.textStyle;
    theme     = stack.back.theme;

    stack.popBack;

    //save actContainer here.
    lastContainer = actContainer;

    //actContainer is the top of the stack or null
    actContainer = stack.empty ? null : stack.back.container;
    //todo: the first stack container is always 0.
  }

  void dump(){
    writeln("---- IM dump --------------------------------");
    foreach(cell; root) cell.dump;
    writeln("---- End of IM dump -------------------------");
  }

  private auto find(C:.Container)(){
    foreach_reverse(ref s;stack)
      if(auto r = cast(C)(s.container))
        return r;
    return null;
  }

  private void append(T : Cell)(T c){
    if(actContainer !is null) actContainer.append(c);
                         else root ~= c;
  }

  // overlay drawing //////////////////////////
  Drawing[.Container] overlayDrawings;

  void addOverlayDrawing(Drawing dr){
    enforce(actContainer !is null);
    enforce(!actContainer.flags._hasOverlayDrawing, "Container already has an overlay drawing.");

    actContainer.flags._hasOverlayDrawing = true;
    overlayDrawings[actContainer] = dr;
  }

  Drawing getOverlayDrawing(.Container cntr){
    if(auto drOverlay = cntr in overlayDrawings) return *drOverlay;
                                            else return null;
  }

  //easy access

  @property{
    float fh(){ return textStyle.fontHeight; }
    void fh(float v){ textStyle.fontHeight = cast(ubyte)(v.iround); }
  }

  auto subCells(){ return actContainer.subCells; }
  auto subCells(T : .Cell)(){ return actContainer.subCells.map!(c => cast(T)c).filter!(c => c !is null); }
  auto subContainers(){ return actContainer.subContainers; }

  //container delegates
  //void opDispatch(string name, T...)(T args) { mixin("containerStack[$-1]." ~ name)(args); }

  auto ContainerProp(string name) {
    return q{
      @property auto #() { return actContainer.#; }
      @property void #(typeof(actContainer.#) val){ actContainer.# = val; }
    }.replace("#", name);
  }

  auto ContainerRef(string name) {
    return q{
      ref auto #() { return actContainer.#; }
    }.replace("#", name);
  }

  mixin(
    ["innerWidth", "outerWidth", "innerHeight", "outerHeight", "innerSize", "outerSize", "width", "height"].map!ContainerProp.join ~
    ["flags", "flex", "margin", "border", "padding", "bkColor"].map!ContainerRef.join
  );

  //Parameter structs ///////////////////////////////////
  struct id      { uint val;  /*private*/ enum M = q{ auto id_ = file.xxh(line)^baseId;                          static foreach(a; args) static if(is(Unqual!(typeof(a)) == id      )) id_       = [a.val].xxh(id_); }; }
  struct enable  { bool val;  private enum M = q{ auto oldEnabled = enabled; scope(exit) enabled = oldEnabled;   static foreach(a; args) static if(is(Unqual!(typeof(a)) == enable  )) enabled   = enabled && a.val; }; }
  struct selected{ bool val;  private enum M = q{ auto _selected = false;                                        static foreach(a; args) static if(is(Unqual!(typeof(a)) == selected)) _selected = a.val;            }; }

  enum RangeType{ linear, log, circular, endless }
  struct range{                                    //endless can go out of range, circular always using modulo.
    float min, max, step=1; RangeType type;  //todo: this is an 1D bounds

    //todo: handle invalid intervals
    bool isComplete() const { return !isnan(min) && !isnan(max); }

    bool isLinear  () const { return type==RangeType.linear  ; }
    bool isLog     () const { return type==RangeType.log     ; }
    bool isCircular() const { return type==RangeType.circular; }
    bool isEndless () const { return type==RangeType.endless ; }
    bool isClamped () const { return isLinear || isLog || isCircular; }
    bool isOrdered () const { return min <= max; }

    float normalize(float x) const{
      auto n = isLog ? x.log2.remap(min.log2, max.log2, 0, 1)  //todo: handle log(0)
                     : x     .remap(min     , max     , 0, 1);
      if(isCircular) if(n<0 || n>1) n = n-n.floor;
      if(isClamped) n = n.clamp(0, 1);
      return n;
    }

    float denormalize(float n) const{
      if(isCircular) if(n<0 || n>1) n = n-n.floor;
      if(isClamped ) n = n.clamp(0, 1);

      return clamp(isLog ?  2 ^^ n.remap(0, 1, min.log2, max.log2)
                         :       n.remap(0, 1, min     , max     )); //clamp is needed because of rounding errors
    }

    Unqual!T clamp(T)(T f) const{
      if(isComplete){
        static if(isIntegral!T){
          if(isOrdered) f = f.clamp(min.ceil.to!T, max.floor.to!T);
                   else f = f.clamp(max.ceil.to!T, min.floor.to!T);
        }else{
          if(isOrdered) f = f.clamp(min.to!T, max.to!T);
                   else f = f.clamp(max.to!T, min.to!T);
        }
      }else{ //incomplete range: eiter min or max is nan
        static if(isIntegral!T){
          if(!isnan(min) && f<min.iceil ) f = min.iceil ; else
          if(!isnan(max) && f>max.ifloor) f = max.ifloor;
        }else{
          if(!isnan(min) && f<min) f = min; else
          if(!isnan(max) && f>max) f = max;
        }
      }
      return f;
    }

    private enum M = q{ range _range;  static foreach(a; args) static if(is(Unqual!(typeof(a)) == range)) _range = a; };
  }

  auto logRange     (float min, float max, float step=1){ return range(min, max, step, RangeType.log     ); }
  auto circularRange(float min, float max, float step=1){ return range(min, max, step, RangeType.circular); }
  auto endlessRange (float min, float max, float step=1){ return range(min, max, step, RangeType.endless ); }

  static auto hitTest(.Container container, uint id, bool enabled){
    assert(container !is null);
    auto res = hitTestManager.check(id);
    res.enabled = enabled;
    hitTestManager.addHash(container, id);
    return res;
  }

  auto hitTest(uint id, bool enabled){
    return hitTest(actContainer, id, enabled);
  }


  string symbol(string def){ return tag(`symbol `~def); }
  void Symbol(string def){ Text(symbol(def)); }

  struct ScrollInfo{ // ------------------------------- ScrollInfo //////////////////////////////
    char orientation;

    struct ScrollInfoRec{
      uint id;
      .Container container; //contains id
      uint lastAccess; //to purge the old ones

      //current parameters for the scrollbar
      float contentSize=0, pageSize=0; //only valid if container has the has[H/V]ScrollBar flag.

      //persistent data
      float offset=0;
      im.SliderClass slider;
    }

    protected ScrollInfoRec[uint] infos;

    auto getScrollBar(uint id){
      if(auto p = id in infos) return (*p).slider; else return null;
    }

    auto getScrollOffset(uint id){ //opt: Should combine get offset and getScrollBar
      if(auto p = id in infos) return (*p).offset; else return 0;
    }

    //1. called from measure() when it decided the scrollbars needed
    auto update(.Container container, float contentSize, float pageSize)
    in(container)
    in(container.id)
    {
      infos.findAdd(container.id, (ref ScrollInfoRec info){
        info.container   = container;
        info.id          = container.id;
        info.contentSize = contentSize;
        info.pageSize    = pageSize;
        info.lastAccess  = global_tick;
      });
    }

    //optional
    /*void purge(){  createBars has it.
      uint[] toRemove;
      foreach(k, const v; infos) if(v.lastAccess < global_updateTick) toRemove ~= k;
      foreach(k; toRemove) infos.remove(k);
      //opt: assocArray.rehash test
    }*/

    //todo: IDE: nicer error display, and autoSolve: "undefined identifier `global_updateTick`, did you mean variable `global_UpdateTick`?"

    //2. called after measure when the final local positions are known. It creates the bars if needed and registers them with hitTestManager
    void createBars(bool doPurge){
      assert(orientation.among('H', 'V'));

      uint[] toRemove;
      foreach(id, ref info; infos){
        if(info.lastAccess<global_tick){
          if(doPurge) toRemove ~= id;
          continue;
        }
        const exists = (orientation=='H' && info.container.flags.hasHScrollBar)
                    || (orientation=='V' && info.container.flags.hasVScrollBar);
        if(!exists) continue;

        bool enabled;
        float normValue;
        float normThumbSize;
        float activeRange = info.contentSize - info.pageSize;

        const flip = orientation=='V';
        void doFlip(){ if(flip) normValue = 1-normValue; }

        if(activeRange > 0.001f){
          //restrict range
          info.offset.minimize(activeRange);
          info.offset.maximize(0);

          enabled = true;
          normValue = info.offset/activeRange;
          normThumbSize = info.pageSize/info.contentSize;

          doFlip;
        }else{
          info.offset = 0; //no active range, so just reset it to 0
        }

        bool userModified;
        HitInfo hit;
        auto actView = targetSurfaces[1].view; //todo: scrollbars only work on GUI surface. This flag shlould be inherited automatically, just like the upcoming enabled flag.
        auto sl = new SliderClass(info.container.id^(0x84389f40+orientation), enabled, normValue, range(0, 1), userModified, actView.mousePos, tsNormal, hit,
          orientation=='H' ? SliderOrientation.horz : SliderOrientation.vert, SliderStyle.scrollBar, 1, normThumbSize);

        info.slider = sl;

        //set the position of the slider.
        //todo: Because it's after hitTest, interaction will be delayed for 1 frame. But it should not.
        const scrollThickness = DefaultScrollThickness; //todo: this is duplicated!!!
        with(info.container) if(orientation=='H'){
          sl.outerPos = vec2(0, innerHeight-scrollThickness);
          sl.outerSize = vec2(innerWidth-(flags.hasVScrollBar ? scrollThickness : 0), scrollThickness);
        }else{
          sl.outerPos = vec2(innerWidth-scrollThickness, 0);
          sl.outerSize = vec2(scrollThickness, innerHeight-(flags.hasHScrollBar ? scrollThickness : 0));
        }

        //todo: the hitInfo is for the last frame. It should be processed a bit later
        if(userModified && enabled){
          doFlip;
          info.offset = normValue*activeRange;
        }
      }

      //purge old ones
      foreach(id; toRemove) infos.remove(id);
    }


    void dump(){
      print("-".replicate(40), orientation.to!string.lc~"ScrollInfo dump");
      infos.values.each!print;
    }
  }

  auto hScrollInfo = ScrollInfo('H');
  auto vScrollInfo = ScrollInfo('V');

  void Column(string file=__FILE__, int line=__LINE__, Args...)(in Args args){  // Column //////////////////////////////
    mixin(id.M ~ enable.M);

    auto column = new .Column;
    column.bkColor = style.bkColor;
    append(column); push(column, file.xxh(line)); scope(exit) pop;

    static foreach(a; args){{ alias t = typeof(a);
      static if(isFunctionPointer!a){
        a();
      }else static if(isDelegate!a){
        a();
      }else static assert(false, "Unsupported type: "~typeof(a).stringof);
    }}
  }

  void Row(string file=__FILE__, int line=__LINE__, T...)(in T args){  // Row //////////////////////////////
    mixin(id.M ~ enable.M);

    auto row = new .Row("", textStyle);
    append(row); push(row, file.xxh(line)); scope(exit) pop;

    static foreach(a; args){{ alias t = Unqual!(typeof(a));

           static if(isFunctionPointer!a) a();
      else static if(isDelegate!a       ) a();
      else static if(isSomeString!t     ) Text(a);
      else static if(is(t == YAlign)    ) flags.yAlign = a;
      else static if(is(t == HAlign)    ) flags.hAlign = a;
      else static if(is(t == VAlign)    ) flags.vAlign = a;
      else static if(is(t == RGB)       ){ bkColor = a; style.bkColor = a; }
      else static assert(false, "Unsupported type: "~t.stringof);

    }}
  }

  void Control(string srcModule=__MODULE__, size_t srcLine=__LINE__, Args...)(in Args args){  // Row //////////////////////////////
    mixin(enable.M);

    auto row = new .Row("", textStyle);
    append(row); push(row, srcModuleile.xxh(line)); scope(exit) pop;

    static foreach(a; args){{ alias t = Unqual!(typeof(a));

           static if(isFunctionPointer!a) a();
      else static if(isDelegate!a       ) a();
      else static if(isSomeString!t     ) Text(a);
      else static if(is(t == YAlign)    ) flags.yAlign = a;
      else static if(is(t == HAlign)    ) flags.hAlign = a;
      else static if(is(t == VAlign)    ) flags.vAlign = a;
      else static if(is(t == RGB)       ){ bkColor = a; style.bkColor = a; }
      else static assert(false, "Unsupported type: "~t.stringof);

    }}
  }


  void Container(string file=__FILE__, int line=__LINE__, T...)(T args){  // Container //////////////////////////////
    mixin(id.M ~ enable.M);

    auto cntr = new .Container;
    append(cntr); push(cntr, file.xxh(line)); scope(exit) pop;

    static foreach(a; args){{ alias t = typeof(a);
      static if(isFunctionPointer!a){
        a();
      }else static if(isDelegate!a){
        a();
      }else static if(isSomeString!t){
        Text(a);
      }else{
        static assert(false, "Unsupported type: "~t.stringof);
      }
    }}
  }

  // popup state
  struct PopupState{
    Cell cell; // the popup itself
    Cell parent; // the initiator of the popup

    HAlign hAlign;
    VAlign vAlign;

    void reset(){
      hAlign = HAlign.left;
      vAlign = VAlign.bottom;
      cell = null;
      parent = null;
    }

    void doAlign(){
      // must be called after measure
      /*
      if(cell && parent){
        switch(hAlign){
          case HAlign.right: cell.outerPos.x = parent.outerRight-cell.outerWidth; break;
          default: cell.outerPos.x = parent.outerPos.x;
        }
        switch(vAlign){
          case VAlign.top: cell.outerY = parent.outerBottom-cell.outerHeight; break;
          default: cell.outerY = parent.outerY; break;
        }
      }*/

      if(cell && parent){
        auto bnd = het.uibase.Container._savedComboBounds;
        cell.outerPos = vec2(bnd.left+2, bnd.bottom-2);
      }
    }
  }
  PopupState popupState;

  private void Popup(Cell parent, void delegate() contents){ // Popup for combobox only ////////////////////////////////////
    //todo: this check is not working because of the IM gui. When ComboBox1 is pulled down and the user clicks on ComboBox2
    //commented out intentionally: enforce(popupState.cell is null, "im.Popup() already called.");

    auto oldLen = actContainer.subCells.length;
    contents();
    auto extraLen = actContainer.subCells.length-oldLen;

    if(extraLen==0) return;
    if(extraLen>1) raise("Popup must contain only one Cell");

    auto popup = actContainer.removeLast;
    root ~= popup;

    popupState.cell = popup;
    popupState.parent = parent;
  }


  void Code(string src){ // Code /////////////////////////////
    //todo: syntax highlight
    //Spacer(0.5*fh);
    Column({
      margin = Margin(0.5*fh, 0.5*fh, 0.5*fh, 0.5*fh);

      style = tsCode;
      const bkColors = [0.06f, 0.09f].map!(t => mix(textStyle.bkColor, textStyle.fontColor, t)).array;
      border = "1 single gray";

      foreach(idx, line; src.split('\n')){
        style.bkColor = bkColors[idx&1]; //alternated bkColor
        line = line.withoutEnding('\r');
        Text(line);
      }

      //don't hide any spaces
      foreach(r; actContainer.subCells)
        (cast(.Container)r).flags.dontHideSpaces = true;
    });
    //Spacer(0.5*fh);
  }

  void Flex(float value = 1){ // Flex //////////////////////////////////
    Row({ flex = value; });
  }

  string bold     (string s){ return tag("style bold=1"     )~s~tag("style bold=0"     ); }
  string italic   (string s){ return tag("style italic=1"   )~s~tag("style italic=0"   ); }
  string underline(string s){ return tag("style underline=1")~s~tag("style underline=0"); }
  string strikeout(string s){ return tag("style strikeout=1")~s~tag("style strikeout=0"); }

  string progressSpinner(int style=1){
    int t(int n){ return ((QPS*n*1.5).ifloor)%n; }
    auto ch(int i){ return [cast(dchar)i].to!string; }

    switch(style){
      case 0: return ch(0x25f4+3-t(4)); //circle 90deg lines
      case 1: return ch(0x25d0+3-[0, 2, 1, 3][t(4)]); //circle 90deg lines
      case 2: return ch(0x1f550+t(12)); //clock
      default: return "...";
    }
  }

  void ProgressSpinner(int progressStyle = 0){
    Row({
      style.fontColor = mix(style.bkColor, style.fontColor, .66f);
      Text(" "~progressSpinner(progressStyle)~" ");
    });
  }

//todo: flex N is fucked up. Treats N as 1 always.
//todo: flex() function cant work because of flex property.
//  string flex(string markup){ return tag(["flex", markup].join(" ")); }
//  string flex(float value){ return flex(value.text); } //kinda lame to do it with texts

  //Text /////////////////////////////////
  void Text(/*string file=__FILE__, int line=__LINE__,*/ T...)(T args){ //todo: not multiline yet

    //multiline behaviour:
    //  parent is Row: if multiline -> make a column around it
    //  parent is column: multiline is ok. Multiple row emit
    //  actContainer is null: root level gets a lot of rows

    //Text is always making one line, even in a container. Use \n for multiple rows
    if(args.length>1 &&(actContainer is null || cast(.Column)actContainer !is null)){ //implicit row
      Row({ Text/*!(file, line)*/(args); });
      return;
    }

    bool restoreTextStyle = false;
    TextStyle oldTextStyle;
    static foreach(a; args){{
      alias t = Unqual!(typeof(a));

      static if(is(t == _FlexValue)){ //nasty workaround for flex() and flex property
        append(new FlexRow("", style));
      }else static if(is(t == TextStyle)){
        if(chkSet(restoreTextStyle)) oldTextStyle = textStyle;
        textStyle = a;
      }else static if(is(t == RGB)){
        textStyle.fontColor = a;
      }else /*static if(isSomeString!t)*/{   //general case, handles as string

        /* mar nem ez tordel, hanem a Row.
        auto lines = a.split('\n').map!(a => a.withoutTrailing('\r')).array;
        if(!lines.empty){
          .Row row = cast(.Row)actContainer;
          if(row){
            row.appendMarkupLine(lines[0], textStyle);
            auto id = file.xxh(line);
            foreach(int idx, line; lines[1..$]){
              pop;
              row = new .Row(line, textStyle);
              append(row);
              push(row, [idx].xxh(id));
            }
          }else{
            foreach(int idx, line; lines){
              append(new .Row(line, textStyle)); //todo: not clear how it works with multiple parameters. All arg strings should be packed in one string and then processed by lines.
            }
          }
        }*/

        //this variant gives \n to the row
        auto s = a.text;
        if(.Column col = cast(.Column)actContainer){
          Row({ Text(s); });  //implicit Rows for Column
        }else if(.Row row = cast(.Row)actContainer){
          row.appendMarkupLine(s, textStyle);
        }else {
          actContainer.appendMarkupLine(s, textStyle);
        }
      }
    }}

    if(restoreTextStyle)
      textStyle = oldTextStyle;

/*    auto r = cast(.Row)actContainer;
    if(r) r.appendMarkupLine(text, textStyle);
     else Row({ Text(text); });*/
  }

  void Comment(/*string file=__FILE__, int line=__LINE__, */T...)(T args){
    // It seems a good idea, as once I wanted to type Comment(.. instead of Text(tsComment...
    Text/*!(file, line)*/(tsComment, args);
  }

  //Bullet ///////////////////////////////////
  void Bullet(){
    Row({ outerWidth = fh*2; Flex; Text(tag("char 0x2022")); Flex; }); //todo: no flex needed, -> center aligned. Constant width is needed however, for different bullet styles.
  }

  void Bullet(void delegate() contents){
    Row({
      Bullet;
      if(contents) contents();
    });
  }

  void Bullet(string text){
    Bullet({ Text(text); });
  }

  //Spacer //////////////////////////
  private void SpacerRow(Args...)(float size, in Args args){
    const vert = cast(.Row)actContainer !is null;
    Row(args, {
      if(vert){ innerWidth  = size; flags.yAlign = YAlign.stretch; }
          else{ innerHeight = size; /+ width is auto by default. A Column will stretch it properly. +/ }
    });
  }

  void Spacer(Args...)(in Args args){
    float size;
    static if(args.length && isNumeric!(Args[0])){
      size = args[0];
      enum argStart = 1;
    }else{
      enum argStart = 0;
    }
    if(isnan(size)) size = fh*.5f;

    SpacerRow(size, args[argStart..$]);
  }

  void HR(){
    SpacerRow(fh*InvNormalFontHeight, {
      margin = "0.33333x 0";
      bkColor = mix(style.bkColor, style.fontColor, 0.25f);
    });
  }

  // apply Btn and Edit style////////////////////////////////////

  void applyBtnBorder(in RGB bColor = clWinBtn){ //todo: use it for edit as well
    margin  = Margin(2, 2, 2, 2);
    border  = Border(2, BorderStyle.normal, bColor);
    padding = Padding(2, 2, 2, 2);
    if(theme == "tool"){
      border.width    = 1;
      border.inset = true;
      margin .top = margin .bottom = 0;
      padding.top = padding.bottom = 0;
    }
  }

  void applyLinkStyle(bool enabled, bool focused, bool captured, float hover){
    style = tsNormal;

    float highlight = 0;
    if(!enabled){
      style.fontColor = clWinBtnDisabledText;
    }else{
      highlight = max(hover*0.66f, captured);
      style.fontColor = mix(clWinText, clAccent, highlight);
    }

    style.underline = highlight > 0.5f;

    //todo: handle focused
  }

  void applyBtnStyle(bool isWhite, bool enabled, bool focused, bool selected, bool captured, float hover){
    style = tsBtn;

    auto bColor = mix(style.bkColor, clWinBtnHoverBorder, hover);

    applyBtnBorder(bColor);

    if(!enabled){
      style.fontColor = clWinBtnDisabledText;
      border.color    = style.bkColor;
    }else if(captured){
      border.style    = BorderStyle.none;
      style.bkColor   = clWinBtnPressed;
    }

    if(isWhite){
      if(captured) style.bkColor = mix(clWinBackground, clWinBtnPressed, .5f);
              else style.bkColor = clWinBackground; //todo: ez felulirja a
    }

    if(theme == "tool"){ //every appearance is lighter on a toolBtn
      style.bkColor   = mix(style.bkColor, tsNormal.bkColor, .5f);
      if(captured && enabled) border.width = 0; //this if() makes the edge squareish
    }

    if(selected){
      style.bkColor = mix(style.bkColor, clAccent, .5f);
      border.color  = mix(border.color , clAccent, .5f);
    }

    bkColor = style.bkColor; //todo: update the backgroundColor of the container. Should be automatic, but how?...

    //todo: handle focused
  }

  void applyEditStyle(bool enabled, bool focused, float hover){
    style   = tsNormal;

    auto bColor = focused  ? clAccent :
                  !enabled ? mix(clWinBtn       , style.bkColor, 0.5f)
                           : mix(clWinBtn, clWinBtnHoverBorder, hover);

    applyBtnBorder(bColor);

    if(!enabled){
      style.fontColor = mix(style.fontColor, style.bkColor, 0.5f);
    }

    bkColor = style.bkColor;
  }

  struct EditResult{
    HitInfo hit;
    bool changed, focused;
    alias changed this;
  }

  auto Edit(string file=__FILE__, int line=__LINE__, T0, T...)(ref T0 value, T args){ // Edit /////////////////////////////////
    enum IsNum = std.traits.isNumeric!T0;

    mixin(id.M ~ enable.M);
    static if(IsNum) mixin(range.M);

    EditResult res;

    void value2editor(){ textEditorState.str = value.text; }

    bool wasConvertError; //editor2value messaging back with this

    void editor2value(){
      try{
        auto newValue = textEditorState.str.to!T0;  //todo: range clamp

        static if(IsNum){
          auto clamped = _range.clamp(newValue);
          wasConvertError = clamped != newValue;
          newValue = clamped;
        }

        res.changed = newValue != value;
        value = newValue;
      }catch(Exception){
        wasConvertError = true;
      }
    }

    Row({
      auto ref hit(){ return res.hit; }

      flags.clipChildren = true;
      auto row = cast(.Row)actContainer;

      hit = hitTest(id_, enabled);
      auto localMouse = actView.mousePos - hit.hitBounds.topLeft - row.topLeftGapSize; //todo: this is not when dr and drGUI is used concurrently. currentMouse id for drUI only.

      mixin(hintHandler);

      bool manualFocus;
      static foreach(a; args) static if(is(typeof(a) == KeyCombo)) if(a.pressed) manualFocus = true;

      const focused = focusUpdate(actContainer, id_,
        enabled,
        hit.pressed || manualFocus, //enter
        inputs["Esc"].pressed,  //exit
        /* onEnter */ {
          value2editor;

          //must ovverride the previous value from another edit
          //todo: this must be rewritten with imStorage bounds.
          textEditorState.cmdQueue ~= EditCmd(EditCmd.cEnd);

          //for keyboard entry: textEditorState.cmdQueue ~= EditCmd(EditCmd.cEnd);
        },
        /* onFocus */ { /*_EditHandleInput(value, textEditorState.str, chg);*/ },
        /* onExit  */ { }
      );
      res.focused = focused;

      //text editor functionality
      if(focused){
        //get the modified string
        //if(strModified) editor2value; //only when changed?
        editor2value; //todo: when to write back? always / only when change/exit?

        textEditorState.row = row;
        textEditorState.strModified = false; //ready for next modifications

        //fetch and queue input
        string unprocessed;
        import het.win: mainWindow;
        with(textEditorState) with(EditCmd){
          foreach(ch; mainWindow.inputChars.unTag.byDchar){ //todo: preprocess: with(a, b) -> with(a)with(b)
            switch(ch){
              //case 8:  cmdQueue ~= EditCmd(cDeleteBack);  break; //todo: bug: ha caret.idx=0, akkor benazik.
              default:
                if(ch>=32 || ch==9){
                  cmdQueue ~= EditCmd(cInsert, [ch].to!string);
                }else{
                  unprocessed ~= ch;
                }
            }  //jajj de korulmenyes ez a switch case fos....
          }

          with(het.inputs){
            if(KeyCombo("LMB"      ).hold ) cmdQueue ~= EditCmd(cMouse, localMouse);
            if(KeyCombo("Backspace").typed) cmdQueue ~= EditCmd(cDeleteBack       );
            if(KeyCombo("Del"      ).typed) cmdQueue ~= EditCmd(cDelete           );
            if(KeyCombo("Left"     ).typed) cmdQueue ~= EditCmd(cLeft             );
            if(KeyCombo("Right"    ).typed) cmdQueue ~= EditCmd(cRight            );
            if(KeyCombo("Home"     ).typed) cmdQueue ~= EditCmd(cHome             ); //todo: When the edit is focused, don't let the view to zoom home. Problem: Editor has a priority here, but the view is checked first.
            if(KeyCombo("End"      ).typed) cmdQueue ~= EditCmd(cEnd              );
            if(KeyCombo("Up"       ).typed) cmdQueue ~= EditCmd(cUp               );
            if(KeyCombo("Down"     ).typed) cmdQueue ~= EditCmd(cDown             );

            if(KeyCombo("Ctrl+V Shift+Ins").typed){
              cmdQueue ~= EditCmd(cInsert, clipBoard.text);
            }
          }
          //todo: A KeyCombo az ambiguous... nem jo, ha control is meg az input beli is ugyanolyan nevu.

        }

        mainWindow.inputChars = unprocessed;
      }

      static if(std.traits.isNumeric!T0) flags.hAlign = HAlign.right;
                                    else flags.hAlign = HAlign.left;

      applyEditStyle(enabled, focused, hit.hover_smooth);

      if(focused)
        flags.dontHideSpaces = true;


      //execute the delegate funct parameters
      static foreach(a; args) static if(__traits(compiles, a())){ a(); }

      //put the text out
      if(focused){
        if(wasConvertError) textStyle.fontColor = clRed;
        row.appendMarkupLine(textEditorState.str, textStyle, textEditorState.cellStrOfs);
      }else{
        row.appendMarkupLine(value.text         , textStyle);
      }

      //get default fontheight for the editor after the (possibly empty) string was displayed
      auto defaultFontHeight = style.fontHeight;

      //set editor's defaultFontHeight for the caret when the string is empty
      if(focused) textEditorState.defaultFontHeight = defaultFontHeight;

      //set minimal height for the control
      if(row.subCells.empty){
        if(innerHeight<style.fontHeight)
          innerHeight = style.fontHeight; //todo: Container.minInnerSize
      }

    });

    return res; //a hit testet vissza kene adni im.valtozoban
  }

  auto Static(string file=__FILE__, int line=__LINE__, T0, T...)(in T0 value, T args){ // Static /////////////////////////////////
    static if(is(T0 : Property)){
      auto p = cast(Property)value;
      Static!(file, line)(p.asText, hint(p.hint),args);
    }else{
      Row({
        mixin(id.M);
        auto hit = hitTest(id_, enabled);
        mixin(hintHandler);
        applyEditStyle(true, false, 0); //todo: Enabled in static???
        style = tsNormal;

        static if(std.traits.isNumeric!T0) flags.hAlign = HAlign.right;
                                      else flags.hAlign = HAlign.left;

        static if(__traits(compiles, value())) value();
                                          else Text(value.text);

        static foreach(a; args) static if(__traits(compiles, a())) a();

        //set minimal height for the control if empty
        if(actContainer.subCells.empty && innerHeight==0)
            innerHeight = fh;
      });
    }
  }

  auto IncBtn(string file=__FILE__, int line=__LINE__, int sign=1, T0, T...)(ref T0 value, T args) if(sign!=0 && isNumeric!T0){ //IncBtn /////////////////////////////////
    mixin(id.M ~ enable.M ~ range.M);

    auto capt = symbol(`Calculator` ~ (sign>0 ? `Addition` : `Subtract`));
    enum isInt = isIntegral!T0;

    auto hit = Btn!(file, line)(capt, args, id(sign)); //2 id's can pass because of the static foreach
    bool chg;
    if(hit.repeated){
      auto oldValue = value,
           step = abs(_range.step),
           newValue = _range.clamp(value+step*sign);

      if(isInt) value = cast(T0)(round(newValue));
           else value = cast(T0)newValue;

      chg = newValue != oldValue;
    }

    return chg;
  }

  auto DecBtn(string file=__FILE__, int line=__LINE__, T0, T...)(ref T0 value, T args){
    return IncBtn!(file, line, -1)(value, args);
  }

  auto IncDecBtn(string file=__FILE__, int line=__LINE__, T0, T...)(ref T0 value, T args){
    bool res;
    Row({
      flags.btnRowLines = true;
      auto r1 = DecBtn!(file, line)(value, args);
      lastCell.margin.right = 0;
      auto r2 = IncBtn!(file, line)(value, args);
      lastCell.margin.left = 0;
      res = r1 || r2;
    });
    return res;
  }

  auto IncDec(string file=__FILE__, int line=__LINE__, T0, T...)(ref T0 value, T args){
    auto oldValue = value;
    Edit!(file, line)(value, { width = 2*fh; }, args); //todo: na itt total nem vilagos, hogy az args hova megy, meg mi a result
    IncDecBtn(value, args);
    return oldValue != value;
  }

  auto WhiteBtn(string file=__FILE__, int line=__LINE__, T0, T...)(T0 text, T args){
    return Btn!(file, line, true, T0, T)(text, args);
  }

  auto Btn(string file=__FILE__, int line=__LINE__, bool isWhite=false, T0, T...)(T0 text, T args)  // Btn //////////////////////////////
  if(isSomeString!T0 || __traits(compiles, text()) )
  {
    mixin(id.M ~ enable.M ~ selected.M);

    const isToolBtn = theme=="tool";

    HitInfo hit;

    Row({
      hit = hitTest(id_, enabled);
      mixin(hintHandler);

      bool focused = focusUpdate(actContainer, id_,
        enabled, hit.pressed, inputs.Esc.pressed,  //enabled, enter, exit
        /* onEnter */ { },
        /* onFocus */ { },
        /* onExit  */ { }
      );

      //flags.wordWrap = false;
      flags.hAlign = HAlign.center;

      applyBtnStyle(isWhite, enabled, focused, _selected, hit.captured, hit.hover_smooth);

      static if(isSomeString!T0) Text(text); //centered text
                            else text(); //delegate

      static foreach(a; args) static if(__traits(compiles, a())) a();
    });

    //KeyCombo in click mode.
    static foreach(a; args) static if(is(typeof(a) == KeyCombo)) if(a.pressed) hit.clicked = true;

    return hit;
  }

  // BtnRow //////////////////////////////////
  auto BtnRow(string file=__FILE__, int line=__LINE__, T...)(void delegate() fun, in T args){
    mixin(id.M);
    Row({
      flags.btnRowLines = true;

      fun();

      foreach(i, c; subCells){
        const first = i==0, last = i+1==subCells.length;
        if(!first) c.margin.left = 0;
        if(!last ) c.margin.right= 0;
      }
    });
  }

  auto BtnRow(string file=__FILE__, int line=__LINE__, T...)(ref int idx, in string[] captions, in T args){
    mixin(id.M ~ enable.M);

    auto last = idx;

    BtnRow!(file, line)({
      foreach(i0, capt; captions){
        const i = cast(int)i0;
        if(Btn(capt, id(i), selected(idx==i))) idx = i;
      }
    });

    return last != idx;
  }

  auto BtnRow(string file=__FILE__, int line=__LINE__, A, Args...)(ref A value, in A[] items, in Args args){
    auto idx = cast(int) items.countUntil(value); //todo: it's a copy from ListBox. Refactor needed
    auto res = BtnRow!(file, line)(idx, items, args);
    if(res) value = items[idx];
    return res;
  }

  //todo: (enum, enum[]) is ambiguous!!! only (enum) works on its the full members.
  auto BtnRow(string file=__FILE__, int line=__LINE__, E, Args...)(ref E e, in Args args) if(is(E==enum)){
    string s = e.text;
    auto res = BtnRow!(file, line)(s, getEnumMembers!E, args);
    if(res) ignoreExceptions({ e = s.to!E; });
    return res;
  }

  auto Link(string file=__FILE__, int line=__LINE__, T0, T...)(T0 text, T args)  // Link //////////////////////////////
  if(isSomeString!T0 || __traits(compiles, text()) )
  {
    mixin(id.M ~ enable.M);

    HitInfo hit;

    Row({
      hit = hitTest(id_, enabled);

      mixin(hintHandler);

      bool focused = focusUpdate(actContainer, id_,
        enabled, hit.pressed, inputs.Esc.pressed,  //enabled, enter, exit
        /* onEnter */ { },
        /* onFocus */ { },
        /* onExit  */ { }
      );

      // handle the space key when focused
      if(focused){
        with(inputs.Space){
          if(down   ) hit.captured = true;
          if(pressed) hit.clicked  = true;
        }
      }

      applyLinkStyle(enabled, focused, hit.captured, hit.hover_smooth);

      static if(isSomeString!T0) Text(text); //centered text
                            else text(); //delegate

      static foreach(a; args) static if(__traits(compiles, a())) a();
    });

    //KeyCombo in click mode.
    static foreach(a; args) static if(is(typeof(a) == KeyCombo)) if(a.pressed) hit.clicked = true;

    return hit;
  }

  auto ToolBtn(string file=__FILE__, int line=__LINE__, T0, T...)(T0 text, T args){ //shorthand for tool theme
    auto old = theme; theme = "tool"; scope(exit) theme = old;
    return Btn!(file, line)(text, args);
  }

  auto OldListItem(string file=__FILE__, int line=__LINE__, T0, T...)(T0 text, T args)  // OldListItem //////////////////////////////
  if(isSomeString!T0 || __traits(compiles, text()) )
  {
    mixin(id.M ~ enable.M ~ selected.M);

    //todo: This is only the base of a listitem. Later it must communicate with a container

    HitInfo hit;
    Row({
      hit = hitTest(id_, enabled);

      style = tsNormal; //!!! na ez egy gridbol kell, hogy jojjon!

      margin = "0";
      auto bcolor = mix(style.fontColor, style.bkColor, .5f);
      border       = Border(1, BorderStyle.normal, mix(bcolor, style.fontColor, hit.hover_smooth));
      border.inset = true;
      border.extendBottomRight = true;
      padding = Padding(0, 2, 0, 2);

      style.bkColor = mix(style.bkColor, clGray, hit.hover_smooth*.16f);

      if(!enabled){
        style.fontColor = mix(style.fontColor, clGray, 0.5f); //todo: rather use an 50% overlay for disabled?
      }

      if(_selected){
        style.bkColor = mix(style.bkColor, clAccent, .5f);
        border.color  = mix(border.color , clAccent, .5f);
      }

      bkColor = style.bkColor; //todo: update the backgroundColor of the container. Should be automatic, but how?...

      static if(isSomeString!T0) Text(text); //centered text
                            else text(); //delegate
    });

    return hit;
  }


  //ChkBox //////////////////////////////
  auto ChkBox(string file=__FILE__, int line=__LINE__, string chkBoxStyle="chk", T...)(ref bool state, string caption, T args){
    mixin(id.M ~ enable.M ~ selected.M);

    HitInfo hit;
    Row({
      flags.wordWrap = false;

      hit = hitTest(id_, enabled);
      mixin(hintHandler);

      //update checkbox state
      if(enabled && hit.clicked) state.toggle;

      //mixin GetChkBoxColors;
      RGB hoverColor(RGB baseColor, RGB bkColor) {
        return !enabled ? clWinBtnDisabledText
                        : mix(baseColor, bkColor, hit.captured ? 0.5f : hit.hover_smooth*0.3f);
      }

      auto markColor = hoverColor(state ? clAccent : style.fontColor, style.bkColor);
      auto textColor = hoverColor(style.fontColor, style.bkColor);

      auto bullet = chkBoxStyle=="radio" ? tag(`symbol RadioBtn`~(state?"On":"Off"))
                                         : tag(`symbol Checkbox`~(state?"CompositeReversed":""));

      //Text(format(tag("style fontColor=\"%s\"")~bullet~" "~tag("style fontColor=\"%s\"")~caption, markColor, textColor));
      Text(markColor, bullet~" ", textColor, caption);

      foreach(a; args) static if(isDelegate!a || isFunction!a) a();
    });

    return hit;
  }

  auto ChkBox(string file=__FILE__, int line=__LINE__, string chkBoxStyle="chk", T...)(Property prop, string caption, T args){
    auto bp = cast(BoolProperty)prop;
    enforce(bp !is null);
    auto last = bp.act;
    auto res = ChkBox!(file, line)(bp.act, caption.empty ? prop.caption : caption, hint(prop.hint), args);
    bp.uiChanged |= last != bp.act;
    return res;
  }

  auto Led(string file=__FILE__, int line=__LINE__, T, Ta...)(T param, Ta args){
    mixin(id.M);
    auto hit = hitTestManager.check(id_);

    float state = 0;

    static if(is(Unqual!T==bool))       state = param ? 1 : 0;
    else static if(isIntegral!T)        state = param ? 1 : 0;
    else static if(isFloatingPoint!T)   state = param.clamp(0, 1);
    else enforce(0, "im.Led() Unhandled param type: " ~ T.stringof);

    auto shp = new .Shape;
    //set defaults
    shp.innerSize = vec2(0.7, 1)*style.fontHeight;
    shp.color = clRainbowRed;

    static foreach(a; args){{ alias t = Unqual!(typeof(a));
      static if(is(t==RGB)) shp.color = a;
      static if(is(t==vec2)) shp.innerSize = a;
    }}

    shp.color = mix(clBlack, shp.color, state.remap(0, 1, 0.2f, 1));

    actContainer.append(cast(.Cell)shp);

    /*Composite({
      style.fontColor = clLime;
      Text(tag(`symbol StatusCircleInner`));
      style.fontColor = clGray;
      Text(tag(`symbol StatusCircleRing`));
    });*/
  }

  // RadioBtn //////////////////////////
  auto RadioBtn(string file=__FILE__, uint line=__LINE__, T...)(ref bool state, string caption, T args){ return ChkBox!(file, line, "radio")(state, caption, args); }

  auto ListBoxItem(C)(ref bool isSelected, C s, uint itemId){ with(im){ //todo: ezt osszahozni a ListItem-el
    HitInfo hit;
    Row({
      hit = hitTest(itemId, enabled);

      if(!isSelected && hit.hover && (inputs.LMB.down || inputs.RMB.down)) isSelected = true; //mosue down left or right

      padding = "2 2";
      bkColor = mix(bkColor, clAccent, max(isSelected ? 0.66f:0, hit.hover_smooth*0.33f));
      style.bkColor = bkColor;

      static if(__traits(compiles, s())) s();
                                    else Text(s.text);
    });

    return hit;
  }}


  struct ListBoxResult{
    HitInfo hit;
    bool changed;
    alias changed this;
  }

  auto ListBox(string file=__FILE__, int line=__LINE__, A, Args...)(ref int idx, in A[] items, Args args){ // LixtBox ///////////////////////////////
    mixin(id.M); //todo: enabled, tool theme

    //find translator function . This translates data to gui.
    enum isTranslator(T) = __traits(compiles, T.init(A.init)); //is(T==void delegate(in A)) || is(T==void delegate(A)) || is(T==void function(in A)) || is(T==void function(A));
    enum translated = anySatisfy!(isTranslator, Args);

    HitInfo hit;
    bool changed;
    Column({
      hit = hitTest(id_, enabled);
      border = "1 normal gray";

      foreach(i, s; items){
        auto itemId = id_ + cast(int) i + 1;
        auto selected = idx==i, oldSelected = selected;

        static if(translated){
          static foreach(f; args) static if(isTranslator!(typeof(f)))
            auto hit = ListBoxItem(selected, { f(s); }, itemId);
        }else{
          auto hit = ListBoxItem(selected, s, itemId);
        }
        if(!oldSelected && selected){
          idx = cast(int) i;
          changed = true;
        }
      }

      static foreach(a; args) static if(__traits(compiles, a())) a();
    });
    return ListBoxResult(hit, changed);
  }

  auto ListBox(string file=__FILE__, int line=__LINE__, A, Args...)(ref A value, A[] items, Args args){
    auto idx = cast(int) items.countUntil(value); //opt: slow search. iterates items twice: 1. in this, 2. in the main ListBox funct
    auto res = ListBox!(file, line)(idx, items, args);
    if(res) value = items[idx];
    return res;
  }

  auto ListBox(string file=__FILE__, int line=__LINE__, E, Args...)(ref E e, Args args) if(is(E==enum)){
    auto s = e.text;
    auto res = ListBox!(file, line)(s, getEnumMembers!E, args);
    if(res) ignoreExceptions({ e = s.to!E; });
    return res;
  }

  //todo: the parameters of all the ListBox-es, ComboBoxes must be refactored. It's a lot of copy paste and yet it's far from full accessible functionality.
  static void ScrollListBox(T, U, string file=__FILE__ , int line=__LINE__)(ref T focusedItem, U items, void delegate(in T) cellFun, int pageSize, ref int topIndex)
  if(isInputRange!U && is(ElementType!U == T)) {
    auto scrollMax = max(0, items.walkLength.to!int-pageSize);
    topIndex = topIndex.clamp(0, scrollMax);
    auto view = items.drop(topIndex).take(pageSize).array;
    Row!(file, line)({
      ListBox(focusedItem, view, cellFun);
      if(1 || scrollMax){
        Spacer;
        Slider(topIndex, range(scrollMax, 0), { width = 1*fh; });
        flags.yAlign = YAlign.stretch;
      }
    });
  }


/+  auto Btn(string file=__FILE__, int line=__LINE__, bool isWhite=false, T0, T...)(T0 text, T args)  // Btn //////////////////////////////
  if(isSomeString!T0 || __traits(compiles, text()) )
  {
    mixin(id.M ~ enable.M ~ selected.M);

    const isToolBtn = theme=="tool";

    HitInfo hit;

    Row({
      hit = hitTest(id_, enabled_);

      mixin(hintHandler);

      bool focused = focusUpdate(actContainer, id_,
        enabled, hit.pressed, false,  //enabled, enter, exit
        /* onEnter */ { },
        /* onFocus */ { },
        /* onExit  */ { }
      );

      //flags.wordWrap = false;
      flags.hAlign = HAlign.center;

      applyBtnStyle(isWhite, enabled, focused, _selected, hit.captured, hit.hover_smooth);

      static if(isSomeString!T0) Text(text); //centered text
                            else text(); //delegate

      static foreach(a; args) static if(__traits(compiles, a())) a();
    });

    return hit;
  }         +/


  auto PopupBtn(string file=__FILE__, int line=__LINE__, T0, Args...)(T0 text, Args args) // PopupBtn ////////////////////////////////
  if((isSomeString!T0 || __traits(compiles, text())) && Args.length>=1 && __traits(compiles, args[$-1]()) )
  {
    Cell btn;
    auto hit = Btn(text, args[0..$-1], { btn = actContainer; });

    if(isFocused(hit.id)) (cast(het.uibase.Container)btn).flags._saveComboBounds = true; //notifies glDraw to place the popup

    if(hit.pressed){
      comboId = hit.id;
      comboState.toggle;
      comboOpening = true; //ignore this mousepress when closing popup
    }

    const popupVisible = isFocused(hit.id) && comboState;
    if(popupVisible){
      Popup(btn, { Column({
        args[$-1]();
      }); });
    }
    return popupVisible;
    //callee must handle the if and optionally set "comboState" to false
    //todo: what if callee don't handle it????
  }


  auto ComboBox_idx(string file=__FILE__, int line=__LINE__, A, Args...)(ref int idx, in A[] items, Args args){ // ComboBox ////////////////////////////////
    mixin(id.M); //todo: enabled

    //find translator function . This translates data to gui.
    enum isTranslator(T) = __traits(compiles, T.init(A.init));
    enum translated = anySatisfy!(isTranslator, Args);

    Cell btn;
    auto hit = WhiteBtn({
      btn = actContainer;
      flags.hAlign = HAlign.left;

      if(idx.inRange(items)){
        static if(translated){
          static foreach(f; args) static if(isTranslator!(typeof(f)))
            f(items[idx]);
        }else{
          Text(items[idx].text);
        }
      }else{
        Text(clGray, "none");
        //null value
      }

      Flex;
      Row({ Text(" ", symbol("ChevronDown"), " "); });
    }, args);

    if(isFocused(hit.id)) (cast(het.uibase.Container)btn).flags._saveComboBounds = true; //notifies glDraw to place the popup

    if(hit.pressed){
      comboId = hit.id;
      comboState.toggle;
      comboOpening = true; //ignore this mousepress when closing popup
    }

    ListBoxResult res;

    if(isFocused(hit.id) && comboState){
      Popup(btn, {

        void inheritComboWidth(){
          if(btn.innerWidth>0)
            innerWidth = btn.innerWidth+6; //todo: tool theme*/
        }

        static if(translated){
          static foreach(f; args) static if(isTranslator!(typeof(f)))
            res = ListBox(idx, items, id(id_+1), &inheritComboWidth, f); //todo: this translator appending is a big mess
        }else{
          res = ListBox(idx, items, id(id_+1), &inheritComboWidth);
        }

        if(res.hit.hover && inputs.LMB.released){
          comboState = false; //close the box
        }
      });
    }

    return res;
  }

  auto ComboBox_ref(string file=__FILE__, int line=__LINE__, A, Args...)(ref A value, in A[] items, Args args){
    auto idx = cast(int) items.countUntil(value);
    auto res = ComboBox_idx!(file, line)(idx, items, args);
    if(res) value = items[idx];
    return res;
  }

  auto ComboBox(string file=__FILE__, int line=__LINE__, A, Args...)(ref int idx, in A[] items, Args args){
    return ComboBox_idx!(file, line, A, Args)(idx, items, args);
  }

  auto ComboBox(string file=__FILE__, int line=__LINE__, A, Args...)(ref A value, in A[] items, Args args){
    return ComboBox_ref!(file, line, A, Args)(value, items, args);
  }

  auto ComboBox(string file=__FILE__, int line=__LINE__, E, T...)(ref E e, T args) if(is(E==enum)){
    auto s = e.text;
    auto res = ComboBox!(file, line)(s, getEnumMembers!E, args);
    if(res) ignoreExceptions({ e = s.to!E; });
    return res;
  }

  // ------------------------------->>>>>>>>>>    Slider ////////////////////////////////////////////////////////////////////////////////////////////////////////////

  enum SliderOrientation{ horz, vert, round, auto_ }
  private pure bool isLinear(in SliderOrientation o){ with(SliderOrientation) return o==horz || o==vert; }
  private pure bool isRound (in SliderOrientation o){ with(SliderOrientation) return o==round; }

  enum SliderStyle{ slider, scrollBar }

  struct ScrollBarOptions{
    float pageSize = 0; //pageSize in win32
    int thickness = 13;
    int margin = 2;
    int minThumbSize_pixels = 5;
  }

  pure static auto getActualSliderOrientation(SliderOrientation orientation, in bounds2 r, SliderStyle style){
    // scrollbar can only be horz or vert.
    if(style==SliderStyle.scrollBar && !isLinear(orientation)) orientation = SliderOrientation.auto_;

    if(orientation != SliderOrientation.auto_) return orientation;

    immutable THRESHOLD = 1.5f;
    float aspect = safeDiv(r.width/r.height, 1);
    return aspect>=THRESHOLD     ? SliderOrientation.horz:
           aspect<=(1/THRESHOLD) ? SliderOrientation.vert:
                                   SliderOrientation.round;
  }

  private struct SliderState{ //information about the current slider being modified

    // information generated and maintained in update
    uint pressed_id;
    vec2 pressed_thumbMouseOfs, pressed_rawMousePos;
    float pressed_nPos; //normalized pos
    int lockedDirection; //0:unknown, 1:h, 2:v

    void onPress(uint id, ref float nPos, in vec2 mousePos){
      //mouse was pressed, initialize values
      pressed_id = id;
      pressed_rawMousePos = rawMousePos;
      pressed_nPos = nPos;

      //remember the thumb-mouse offset at the time of press
      pressed_thumbMouseOfs = drawn_thumbRect.center-mousePos;  //

      //if pressed on a round knob, first it must decide if up/down or left/right
      lockedDirection = 0;
    }

    // information saved in draw(). All vectors are transformed into view space.
    uint drawn_id;
    SliderOrientation drawn_orientation;
    vec2 drawn_p0, drawn_p1;
    bounds2 drawn_thumbRect;

    void afterDraw(uint id, in SliderOrientation ori, vec2 p0, vec2 p1, in bounds2 bKnob){
      drawn_id = id;
      drawn_orientation = ori;
      drawn_p0 = p0;
      drawn_p1 = p1;
      drawn_thumbRect = bKnob;
    }

    //after onPress() it can jump to the mouse
    void jumpToPoint(ref float nPos, in vec2 mousePos, bool isEndless){
      if(drawn_orientation==SliderOrientation.horz){
        pressed_thumbMouseOfs.x = 0;
        nPos = remap_clamp(mousePos.x, drawn_p0.x, drawn_p1.x, 0, 1);
        if(mousePos.x<drawn_p0.x) pressed_thumbMouseOfs.x = drawn_p0.x-mousePos.x;
        if(mousePos.x>drawn_p1.x) pressed_thumbMouseOfs.x = drawn_p1.x-mousePos.x - (isEndless ? 1 : 0); //otherwise endles range_ gets into an endless incrementing loop
      }else if(drawn_orientation==SliderOrientation.vert){
        pressed_thumbMouseOfs.y = 0;
        nPos = remap_clamp(mousePos.y, drawn_p0.y, drawn_p1.y, 0, 1);
        //note: p1 and p0 are intentionally swapped!!!
        if(mousePos.y<drawn_p1.y) pressed_thumbMouseOfs.y = drawn_p1.y-mousePos.y; //todo: test vertical circular slider jump to the very ends, and see if not jumps to opposite si
        if(mousePos.y>drawn_p0.y) pressed_thumbMouseOfs.y = drawn_p0.y-mousePos.y - (isEndless ? 1 : 0);
      }else{
        NOTIMPL;
      }
    }

    void mouseAdjust(ref float nPos, in vec2 mousePos, bool isClamped, bool isCircular, bool isEndless, ref int wrapCnt, float adjustSpeed){
      if(drawn_orientation==SliderOrientation.horz){
        slowMouse(adjustSpeed!=1, adjustSpeed);
        auto p = mousePos.x+pressed_thumbMouseOfs.x;
        if(isCircular || isEndless) mouseMoveRelX(wrapInRange(p, drawn_p0.x, drawn_p1.x, wrapCnt)); //circular wrap around
        nPos = remap(p, drawn_p0.x, drawn_p1.x, 0, 1);
        if(isClamped) nPos = nPos.clamp(0, 1);
      }else if(drawn_orientation==SliderOrientation.vert){
        slowMouse(adjustSpeed!=1, adjustSpeed);
        auto p = mousePos.y+pressed_thumbMouseOfs.y;
        if(isCircular || isEndless) mouseMoveRelY(wrapInRange(p, drawn_p0.y, drawn_p1.y, wrapCnt)); //circular wrap around
        nPos = remap(p, drawn_p0.y, drawn_p1.y, 0, 1);
        if(isClamped) nPos = nPos.clamp(0, 1);
      }else if(drawn_orientation==SliderOrientation.round){
        auto diff = rawMousePos-pressed_rawMousePos;
        auto act_dir = abs(diff.x)>abs(diff.y) ? 1 : 2;
        if(lockedDirection==0 && length(diff)>=3) lockedDirection = act_dir;
        auto delta = (lockedDirection ? lockedDirection : act_dir)==1 ? inputs.MXraw.delta : -inputs.MYraw.delta;
        pressed_nPos += delta*(adjustSpeed*(1.0f/180)); //it adds small delta's, so it could be overdriven
        pressed_nPos = pressed_nPos.clamp(0, 1);
        nPos = pressed_nPos; //todo: it can't modify npos because npos can be an integer too. In this case, the pressed_nPos name is bad.
        //todo: endless????
        //todo: ha tulmegy, akkor vinnie kell magaval a base-t is!!!
        //todo: Ctrl precizitas megoldasa globalisan az inputs.d-ben.
      }else{
        raise("Invalid orientation");
      }
    }

    void mouseAdjust(ref float nPos, in vec2 mousePos, in range range_, ref int wrapCnt, float adjustSpeed){
      mouseAdjust(nPos, mousePos, range_.isClamped, range_.isCircular, range_.isEndless, wrapCnt, adjustSpeed);
    }

    bool handleKeyboard(ref float nPos, in range range_, float pageSize){
      if(nPos.isnan) return false;

      bool userModified;

      void set(float n){
        nPos = n.clamp(0, 1);
        userModified = true;
      }

      void delta(float scale){
        auto nStep(){ return range_.step / (range_.max-range_.min); }
        set(nPos + nStep *scale);
      }

      const horz = drawn_orientation != SliderOrientation.vert, // round knobs are working for both
            vert = drawn_orientation != SliderOrientation.horz;

      if(horz && inputs.Left.repeated  || vert && inputs.Down.repeated) delta(-1);
      if(horz && inputs.Right.repeated || vert && inputs.Up.repeated  ) delta( 1);
      if(inputs.PgDn.repeated)                          delta(-pageSize);
      if(inputs.PgUp.repeated)                          delta( pageSize);
      if(inputs.Home.down)                              set(0);
      if(inputs.End .down)                              set(1);

      return userModified;
    }

    bool handleMouse(uint id, in HitInfo hit, ref float nPos, in vec2 mousePos, in range range_, ref int wrapCnt){
      if(nPos.isnan) return false;

      bool userModified;

      if(hit.pressed && enabled){  //todo: enabled handling
        userModified = true;

        onPress(id, nPos, mousePos);

        //decide wether the knob has to jump to the mouse position or not
        const doJump = isLinear(drawn_orientation) && !drawn_thumbRect.contains!"[)"(mousePos);
        if(doJump){
          jumpToPoint(nPos, mousePos, range_.isEndless);
        }

        //round knob: lock the mouse and start measuring delta movement
        if(isRound(drawn_orientation)){ //todo: "round" knob never jumps
          mouseLock;  //todo: possible bug when the slider disappears, amd the mouse stays locked forever
        }
      }

      //continuous update if active
      if(id==pressed_id){
        userModified = true;
        const adjustSpeed = inputs.Shift.active ? 0.125f : 1; //note: this is a scaling factor...
        mouseAdjust(nPos, mousePos, range_, wrapCnt, adjustSpeed);
      }

      //hit.released
      if(hit.released){
        pressed_id = 0;

        //todo: this isn't safe! what if the control disappears!!!
        if(isLinear(drawn_orientation)){
          slowMouse(false);
        }else{
          mouseUnlock;
        }
      }

      return userModified;
    }

  }

  SliderState sliderState;

  class SliderClass : .Container {
    //note: must be a Container because hitTest works on Containers only.

    //todo: shift precise mode: must use float knob position to improve the precision

    SliderOrientation orientation;
    SliderStyle sliderStyle;
    RGB bkColor, clLine, clThumb, clRuler;
    float baseSize; //this is calculated from current fontHeight and theme.
    float normThumbSize; //if it is a scrollbar, this is not nan and specifies the normalized size of the thumb.
    //these are the derived sizes
    float rulerOfs (){ return baseSize*0.5f; }
    float lwLine   (){ return baseSize*(2.0f/NormalFontHeight); }
    float lwRuler  (){ return lwLine*0.5f; }

    /// this is the half thickness of the thumb in the active direction
    float calcLwThumb  (SliderOrientation ori){
      if(sliderStyle == SliderStyle.scrollBar && !isnan(normThumbSize)){
        const minSizePixels = min(innerWidth, MinScrollThumbSize);
        return max((ori==SliderOrientation.horz ? innerWidth : innerHeight) * normThumbSize.clamp(0, 1), minSizePixels) * .5f;
      }else{
        return baseSize*(1.0f/3);
      }
    }


    int rulerDiv0 = 9, rulerDiv1 = 4;
    ubyte rulerSides=3;

    float nPos, nCenter=0;  //center is the start of the marking on the line
    int wrapCnt; //for endless, to see if there was a wrapping or not. Used to reconstruct actual value

    bounds2 hitBounds;

    bool focused;

    this(uint id, bool enabled, ref float nPos_, in im.range range_, ref bool userModified, vec2 mousePos, TextStyle ts, out HitInfo hit, SliderOrientation orientation, SliderStyle sliderStyle, float fhScale, float normThumbSize=float.init){
      this.id = id;
      this.orientation = orientation;
      this.sliderStyle = sliderStyle;
      this.nPos = enabled ? nPos_ : float.init;
      this.normThumbSize = normThumbSize;

      if(sliderStyle==SliderStyle.scrollBar) padding = "2";

      hit = im.hitTest(this, id, enabled);
      hitBounds = hit.hitBounds;

      if(1 || sliderStyle==SliderStyle.slider) focused = im.focusUpdate(this, id,
        enabled,
        hit.pressed/* || manualFocus*/, //when to enter
        inputs["Esc"].pressed,  //when to exit
        /* onEnter */ { },
        /* onFocus */ { },
        /* onExit  */ { }
      );
      //res.focused = focused;

      if(focused) userModified |= sliderState.handleKeyboard(nPos, range_, 8);

      bkColor = ts.bkColor;
      const hoverOrFocus = enabled ? max(hit.hover_smooth*.5f, focused ? 1.0f : 0) : 0;

      final switch(sliderStyle){
        case SliderStyle.slider:
          clThumb = mix(mix(clSliderThumb, clSliderThumbHover, hoverOrFocus), clSliderThumbPressed, hit.captured_smooth);
          clLine =  mix(mix(clSliderLine , clSliderLineHover , hoverOrFocus), clSliderLinePressed , hit.captured_smooth);
          clRuler = mix(bkColor, ts.fontColor, 0.5); //disable ruler for now
          rulerSides = 3 *0;
        break;
        case SliderStyle.scrollBar:
          clThumb = mix(clScrollThumb, clScrollThumbPressed, hoverOrFocus);
          bkColor = mix(clScrollBk, clScrollThumb, min(hoverOrFocus, .5f));

          //clThumb = mix(clWinBtn, clWinBtnPressed, max(hit.hover_smooth*.5f, sliderState.pressed_id==id ? 1 : 0));
          rulerSides = 0;
        break;
      }

      if(!enabled) clLine = clThumb = clGray; //todo: nem clGray ez, hanem clDisabledText vagy ilyesmi

      baseSize = ts.fontHeight*fhScale*0.8f;
      outerSize = vec2(baseSize*6, baseSize); //default size

      userModified |= sliderState.handleMouse(id, hit, nPos, mousePos, range_, wrapCnt);

      if(userModified)
        nPos_ = nPos;
    }

    override bounds2 getHitBounds(){
      return outerBounds;
    }

    private void drawThumb(Drawing dr, vec2 a, vec2 t, float lwThumb){
      final switch(sliderStyle){
      case SliderStyle.slider:
        dr.lineWidth = lwThumb; dr.color = clThumb;
        const t90 = t.rotate90;
        dr.line(a-t90, a+t90);
      break;
      case SliderStyle.scrollBar:
        dr.color = clThumb;
        const horz = orientation==SliderOrientation.horz,
              halfSize = horz ? vec2(lwThumb, innerHeight*.5f) : vec2(innerWidth*.5f, lwThumb),
              bnd = bounds2(a, a).inflated(halfSize);
        dr.fillRect(bnd);
      break;
      }
    }

    private void drawLine(Drawing dr, vec2 a, vec2 b, RGB cl){ dr.lineWidth = lwLine; dr.color = cl; dr.line(a, b); }

    override void draw(Drawing dr){
      const mod_update = !hitBounds.empty && !inputs.LMB.value;

      dr.color = bkColor; dr.fillRect(borderBounds_inner);
      drawBorder(dr);

      dr.alpha = 1; dr.lineStyle = LineStyle.normal; dr.arrowStyle = ArrowStyle.none;

      auto b = innerBounds;
      const actOrientation = getActualSliderOrientation(orientation, b, sliderStyle),
            lwThumb = calcLwThumb(actOrientation);

      if(isLinear(actOrientation)){
        const horz = actOrientation == SliderOrientation.horz,
              thumbOfs = (horz ? vec2(1, 0) : vec2(0, -1)) * lwThumb,
              p0 = (horz ? b.leftCenter  : b.bottomCenter) + thumbOfs,
              p1 = (horz ? b.rightCenter : b.topCenter   ) - thumbOfs;

        if(sliderStyle==SliderStyle.slider && rulerSides){
          const rp0 = horz ? p0 : p1,
                rp1 = horz ? p1 : p0,
                ro0 = horz ? vec2(0, rulerOfs) : vec2(rulerOfs, 0),
                ro1 = ro0*.4f;
          if(rulerSides&1) drawStraightRuler(dr, bounds2(rp0-ro0, rp1-ro1), rulerDiv0, rulerDiv1, true );
          if(rulerSides&2) drawStraightRuler(dr, bounds2(rp0+ro1, rp1+ro0), rulerDiv0, rulerDiv1, false);
        }

        if(sliderStyle==SliderStyle.slider) drawLine(dr, p0, p1, clLine);

        if(!isnan(nPos)){
          auto p = mix(p0, p1, nPos);
          if(!isnan(nCenter) && sliderStyle==SliderStyle.slider) drawLine(dr, mix(p0, p1, nCenter), p, clThumb);

          drawThumb(dr, p, thumbOfs, lwThumb);

          if(mod_update){
            vec2 thumbHalfSize;
            if(sliderStyle==SliderStyle.slider){
              thumbHalfSize = lwThumb * vec2(0.5f, 1.5f);
              if(!horz) swap(thumbHalfSize.x, thumbHalfSize.y);
            }else{
              thumbHalfSize = horz ? vec2(lwThumb, outerHeight*.5f) : vec2(outerWidth*.5f, lwThumb);
            }
            const thumbRect = bounds2(p, p).inflated(thumbHalfSize);
            sliderState.afterDraw(id, actOrientation, dr.inputTransform(p0), dr.inputTransform(p1), dr.inputTransform(thumbRect));
          }
        }

      }else if(isRound(actOrientation)){
        //center square
        bool endless = false;

        b = b.fittingSquare;
        if(mod_update) sliderState.afterDraw(id, actOrientation, dr.inputTransform(b.center), dr.inputTransform(b.center), dr.inputTransform(b));

        auto c = b.center, r = b.width*0.4f;

        if(rulerSides) drawRoundRuler(dr, c, r, rulerDiv0, rulerDiv1, endless);
        r *= 0.8f;

        float a0 = (endless ? 0 : 0.25f)*PIf;
        float a1 = (endless ? 2 : 1.75f)*PIf;

        dr.lineWidth = lwLine;
        dr.color = clLine;
        dr.circle(c, r, a0, a1);

        if(!isnan(nPos)){
          float n = 1-nPos;
          n = endless ? n.fract : n.clamp(0, 1);  //todo: ezt megcsinalni a range-val
          float a = mix(a0, a1, n);
          if(!endless && !isnan(nCenter)){
            float ac = mix(a0, a1, (1-nCenter).clamp(0, 1));
            dr.color = clThumb;
            if(ac>=a) dr.circle(c, r, a, ac);
                 else dr.circle(c, r, ac, a);
          }

          dr.lineWidth = lwThumb;
          dr.color = clThumb;
          auto v = vec2(sin(a), cos(a));
          dr.line(c, c+v*r);
        }
      }

      drawDebug(dr);
    }

    // Draw Rulers
    protected void drawStraightRuler(Drawing dr, in bounds2 r, int cnt, int cnt2=-1, bool topleft=true){
      cnt--;
      if(cnt<=0) return;
      if(cnt2<0) cnt2 = cnt;
      dr.color = clRuler; dr.lineWidth = lwRuler;
      if(r.height < r.width){
        float c = r.center.y,
              b = r.top,
              t = r.bottom,
              j = r.left,
              ja = r.width/cnt;
        if(!topleft) swap(b, t);
        foreach(i; 0..cnt+1){
          dr.vLine(j, b, cnt2 && i%cnt2==0 ? t : c);
          j += ja;
        }
      }else{
        float c = r.center.x,
              b = r.left,
              t = r.right,
              j = r.top,
              ja = r.height/cnt;
        if(!topleft) swap(b, t);
        foreach(i; 0..cnt+1){
          dr.hLine(b, j, cnt2 && i%cnt2==0 ? t : c);
          j += ja;
        }
      }
    }

    protected void drawRoundRuler(Drawing dr, in vec2 center, float radius, int cnt, int cnt2=-1, bool endless=false){
      cnt--;
      if(cnt<=0) return;
      if(cnt2<0) cnt2 = cnt;
    //  radius *= (1/1.25f);
      dr.color = clRuler; dr.lineWidth = lwRuler;
      foreach(i; 0..cnt+1){
        float a = endless ? 2*PIf*i/cnt
                          : -0.25f*PIf + 1.5f*PIf*i/cnt;
        float co = -cos(a), si = -sin(a);
        dr.moveTo(center.x+co*radius, center.y+si*radius);
        float radius2 = radius*( !endless && (cnt2 && i%cnt2==0) ? 1.25f : 1.125f);
        dr.lineTo(center.x+co*radius2, center.y+si*radius2);
      }
    }
  }


  auto Slider(string file=__FILE__, uint line=__LINE__, V, T...)(ref V value, T args)
  if(isFloatingPoint!V || isIntegral!V)
  {
    mixin(id.M ~ enable.M ~ selected.M ~ range.M);  //todo: selected???

    //flipped range interval. Needed for vertical scrollbar
    const flipped = !_range.isOrdered;
    if(flipped) swap(_range.min, _range.max);

    //string props;
    static foreach(a; args){{ alias t = Unqual!(typeof(a));
      static if(isSomeString!t){
        //props = a; //todo: ennek is
        static assert(0, "string parameter in Slider is deprecated. Use {} delegate instead!");
      }
    }}

    float normValue = _range.normalize(flipped ? _range.max-value : value); // FLIP

    int wrapCnt;
    if(_range.isEndless){
      wrapCnt = normValue.floor.iround;  //todo: refactor endless wrapCnt stuff
      normValue = normValue-normValue.floor;
    }

    bool userModified;
    HitInfo hit;
    auto sl = new SliderClass(id_, enabled, normValue, _range, userModified, actView.mousePos, style, hit, getStaticParamDef(SliderOrientation.auto_, args), getStaticParamDef(SliderStyle.slider, args), theme=="tool" ? 1 : 1.4f);

    append(sl); push(sl, id_); scope(exit) pop;

    mixin(hintHandler);
    static foreach(a; args) static if(__traits(compiles, a())) a();

    if(userModified && enabled){

      if(_range.isEndless) normValue += wrapCnt-sl.wrapCnt;

      float f = _range.denormalize(normValue);
      static if(isIntegral!V) f = round(f);
      value = f.to!V;
      if(flipped) value = (_range.max-value).to!V; // UNFLIP
    }

    //todo: what to return on from slider
    return userModified;
  }

  // AdvancedSlider //////////////////////////////
  void AdvancedSlider_impl(T)(T prop, void delegate() fun=null) if(is(T==FloatProperty) || is(T==IntProperty)){
    //slider, min/max/act value display, default, edit/inc/dec

    const postFix = (" "~prop.unit).stripRight;
    const caption = prop.name.camelToCaption;

    const variant = 0;

    auto range = im.range(prop.min, prop.max, prop.step);
    auto hint = im.hint(prop.hint);

    const last = prop.act;

    if(variant == 0){
      Column({
        width = 300;
        Row({
          Text(/*bold*/(caption));
          //Spacer;
          Row({
            flex = 1;
            actContainer.flags.hAlign = HAlign.right;
            Text(" ");
          });
          Flex;

          if(fun !is null){
            fun();
            Spacer;
          }
          Edit(prop.act, range, hint, { width = fh*3; });
          Text(postFix~" ");
          if(prop.step>0){
            IncDecBtn(prop.act, range); //todo: hint is annoying here
          }
        });
        Slider(prop.act, range, hint, { flex = 1; });
        Row({
          if(Link(prop.min.text ~ postFix)) prop.act = prop.min;
          Row({
            flex = 1;
            flags.hAlign = HAlign.center; //todo: not precise center!!!
            if(Link("default: " ~ prop.def.text ~ postFix)) prop.act = prop.def;
          });
          if(Link(prop.max.text ~ postFix)) prop.act = prop.max;
        });
      });
    }

    prop.uiChanged |= last != prop.act;
  }

  void AdvancedSlider(Property prop, void delegate() fun=null){
    //this just casts the Property and calls the appropriate implementation
         if(auto p = cast(IntProperty  )prop) AdvancedSlider_impl(p, fun);
    else if(auto p = cast(FloatProperty)prop) AdvancedSlider_impl(p, fun);
    else raise("Invalid type");
  }

  void AdvancedSliderChkBox(Property p, Property pBool, string capt=""){
    AdvancedSlider(p, {
      ChkBox(pBool, capt);
    });
  }

  auto Node(ref bool state, void delegate() title, void delegate() contents){ // Node ////////////////////////////
    HitInfo hit;
    Column({
      border.width = 1; //todo: ossze kene tudni kombinalni a szomszedos node-ok bordereit.
      border.color = mix(style.bkColor, style.fontColor, state ? .1f : 0);

      Row({
        hit = ToolBtn(symbol("Caret"~(state ? "Down" : "Right")~"Solid8"));
        if(hit.pressed) state.toggle;
        Text("\t");
        if(title) title();
      });

      if(state && contents) Row({
        Text("\t");
        Column({
          contents();
        });
      });

    });
    return hit;
  }

  auto Node(ref bool state, string title, void delegate() contents){
    return Node(state, { Text(title); }, contents);
  }

  /// A node header that usually connects to a server, can have an error message and a state of refreshing. It can has a refresh button too
  void RefreshableNodeHeader(THeader)(THeader header, string error, bool refreshing, void delegate() onRefresh){ // RefreshableNodeHeader ////////////////////////////
    static if(isSomeString!THeader) Text(header);
                               else header();
    //todo: node header click = open/close node

    if(refreshing) { Text(" "); ProgressSpinner(1); }

    if(error.length) Text(" \u26a0"); //warning symbol
    //todo: warning symbol click = open node
    //todo: warning symbol hint: error message

    Flex;
    if(onRefresh !is null){
      if(ToolBtn(symbol("Refresh"), enable(!refreshing))) onRefresh();
    }
  }


  // Document ////////////////////////
  void Document(void delegate() contents = null){ Document("", contents); }

  void Document(string title, void delegate() contents = null){
    auto doc = new .Document;
    doc.title = title;
    doc.lastChapterLevel = 0;
    append(doc); push(doc, 0); scope(exit) pop;

    if(!title.empty){
      Text(doc.getChapterTextStyle, title);
      Spacer(1.5f*fh);
    }
    if(contents) contents();
  }

  // Chapter /////////////////////////
  void Chapter(string title, void delegate() contents = null){
    auto doc = find!(.Document);
    enforce(doc, "Document container not found");

    auto baseLevel = doc.lastChapterLevel;
    doc.addChapter(title, baseLevel);
    doc.lastChapterLevel = baseLevel+1;
    scope(exit) doc.lastChapterLevel = baseLevel;

    //Spacer(1*fh);

    Text(doc.getChapterTextStyle, title);
    //Spacer(0.5*fh);

    if(contents) contents();
  }

}

//! FieldProps stdUI /////////////////////////////


// UDA declarations in het.utils

struct FieldProps{
  string fullName, name, caption, hint, unit;
  RANGE range;
  bool indent;
  string[] choices;
  bool isReadOnly;

  static string makeFullName(string parentFullName, string fieldName){
    return [parentFullName, fieldName].filter!(not!empty).join('.');
  }

  string getCaption() const{
    auto s = caption!="" ? caption : camelToCaption(name);
    if(s.length && indent) s = "      "~s;
    return s;
  }

  auto hash() const{ return fullName.xxh; }

  //todo: compile time flexible struct builder. Eg.: FieldProps().caption("Capt").unit("mm").logRange(0.1, 1000)
  /+
  https://forum.dlang.org/post/etgucrtletedjssysqqu@forum.dlang.org
  struct S{
      private int _a, _b;

      auto opDispatch(string name)(int value)
      if (name.among("a", "b"))
      {
          mixin("_", name, "= value;");
          return this;
      }

      auto opDispatch(string name)()
      if (name.among("a", "b"))
      {
           mixin("return _", name, ";");
      }
  }

  void main(){
      S.init.a(123).b(456).writeln;
      S().b(456).a(123).writeln;  // Alternative syntax, may not work if opCall is defined
  }
  +/

}

FieldProps getFieldProps(T, string fieldName)(string parentFullName){
  alias f = __traits(getMember, T, fieldName);
  FieldProps p;

  p.fullName    = FieldProps.makeFullName(parentFullName, fieldName);
  p.name        = fieldName;
  p.caption     = getUDA!(f, CAPTION).text;
  p.hint        = getUDA!(f, HINT   ).text;
  //todo: readonly
  p.unit        = getUDA!(f, UNIT   ).text;
  p.range       = getUDA!(f, RANGE);
  p.indent      = hasUDA!(f, INDENT);
  p.choices     = getEnumMembers!T;

  return p;
}

void stdStructFrame(string caption, void delegate() contents){ with(im){
  Column({
    if(caption!=""){
      border = "1 normal black";
      padding = "2";
      margin = "2";

      Row({ Text(tsBold, caption); });
    }

    contents();
  });
}}


void stdUI(T)(ref T data, in FieldProps thisFieldProps=FieldProps.init)
{ with(im){
  //print("generating UI for ", T.stringof, thisFieldProps.name);

  /*static if(is(T==enum)){ //todo: ComboBox
    Row({
      Text(thisFieldProps.getCaption, "\t");

    });
  }else*/

  static if(isSomeString!T){
    Row({
      Text(thisFieldProps.getCaption, "\t");
      if(thisFieldProps.choices.length){
        ComboBox(data, thisFieldProps.choices, hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly), { width = fh*10; });
      }else{
        Edit(data, id(thisFieldProps.hash), hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly), { width = fh*10; });
      }
    });
  }else static if(isFloatingPoint!T     ){
    Row({
      Text(thisFieldProps.getCaption, "\t");
      auto s = format("%g", data);
      Edit(s, id(thisFieldProps.hash), hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly), { width = fh*4; });
      try{ data = s.to!T; }catch(Throwable){}
      Text(thisFieldProps.unit, "\t");
      if(thisFieldProps.range.valid) //todo: im.range() conflict
        Slider(data, hint(thisFieldProps.hint), range(thisFieldProps.range.low, thisFieldProps.range.high), id(thisFieldProps.hash+1), { width = 180; }); //todo: rightclick
      //todo: Bigger slider height when (theme!="tool")
    });
  }else static if(isIntegral!T          ){
    Row({
      Text(thisFieldProps.getCaption, "\t");
      auto s = data.text;
      Edit(s, id(thisFieldProps.hash), hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly), { width = fh*4; });
      try{ data = s.to!T; }catch(Throwable){}
      Text(thisFieldProps.unit, "\t");
      if(thisFieldProps.range.valid) //todo: im.range() conflict
        Slider(data, range(thisFieldProps.range.low, thisFieldProps.range.high), id(thisFieldProps.hash+1), hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly), { width = 180; }); //todo: rightclick
    });
  }else static if(is(T == bool)         ){
    Row({
      Text(thisFieldProps.getCaption, "\t");
      ChkBox(data, "", id(thisFieldProps.hash), hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly));
      Text("\t");
    });
  }else static if(isAggregateType!T     ){ // Struct, Class

    enum bool notHidden(string fieldName) = !hasUDA!(__traits(getMember, T, fieldName), HIDDEN);
    import std.meta;
    enum visibleFields = Filter!(notHidden, AllFieldNames!T);

    stdStructFrame(thisFieldProps.getCaption, {
      //recursive call for each field
      foreach (fieldName; visibleFields){{
        auto fp = getFieldProps!(T, fieldName)(thisFieldProps.fullName);
        stdUI(mixin("data.", fieldName), fp);
      }}
    });

  }else{
    static assert(0 ,"Unhandle type: "~T.stringof);
  }
}}

void stdUI(Property prop, string parentFullName=""){ //todo: ennek inkabb benne kene lennie a Property class-ban...
  if(prop is null) return;
  auto fp = FieldProps(FieldProps.makeFullName(parentFullName, prop.name), prop.name, prop.caption, prop.hint);
  fp.isReadOnly = prop.isReadOnly;

  void doit(T)(ref T act){
    immutable old = act;
    stdUI(act, fp);
    prop.uiChanged |= old != act;
  }

  if(auto p = cast(IntProperty)prop){
    fp.range.low = p.min;
    fp.range.high = p.max;
    doit(p.act);
  }else if(auto p = cast(FloatProperty)prop){
    fp.range.low = p.min;
    fp.range.high = p.max;
    doit(p.act);
  }else if(auto p = cast(StringProperty)prop){
    fp.choices = p.choices;
    doit(p.act);
  }else if(auto p = cast(BoolProperty)prop){
    doit(p.act);
  }else if(auto p = cast(PropertySet)prop){
    stdStructFrame(fp.getCaption, {
      p.properties.each!stdUI;
    });
  }
}


// PropertySet tests ///////////////////////////////

/+
      // PropertySet test -----------------------------------------------------------
      Row({ toolHeader;
        Text(bold("PropertySet test:  "));
      });

      {// test a single property
        auto ip = new IntProperty;
        ip.name = "intProp";
        ip.caption = "Integer property";
        ip.min = 1;
        ip.max = 10;
        stdUI(ip);
      }

      {// test a property loaded from json
        auto str = q{
          {
            "class": "PropertySet",
            "name": "Test property set",
            "properties": [
              {
                "class": "StringProperty",
                "name": "cap.type",
                "caption": "",
                "hint": "Type of capture source.",
                "act": "file",
                "def": "auto",
                "choices": [ "auto", "file", "dshow", "gstreamer", "v4l2", "ueye", "any" ]
              },
              {
                "class": "IntProperty",
                "name": "cap.width",
                "caption": "",
                "hint": "Desired image width",
                "act": 640,
                "def": 640,
                "min": 0,
                "max": 8192,
                "step": 0
              }
            ]
          }
        };
+/

