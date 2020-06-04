module het.ui;

import het.utils, het.geometry, het.draw2d, het.inputs, std.traits;

public import het.uibase;

//todo: Beavatkozas / gombnyomas utan NE jojjon elo a Button hint. Meg a tobbi controllon se!

// utility stuff ////////////////////////////////


enum SliderOrientation{ horz, vert, round, auto_ }
enum HoverState { normal, hover, pressed, disabled }

void calcSliderOrientation(ref SliderOrientation orientation, in Bounds2f r){
  if(orientation == SliderOrientation.auto_){
    float aspect = safeDiv(r.width/r.height, 1);
    enum THRESHOLD = 1.5f;

    orientation = aspect>=THRESHOLD     ? SliderOrientation.horz:
                  aspect<=(1/THRESHOLD) ? SliderOrientation.vert:
                                          SliderOrientation.round;
  }
}


class Slider : Cell { // Slider //////////////////////////////////
  //todo: shift precise mode: must use float knob position to improve the precision

  __gshared static{ //information about the current slider being modified
    uint mod_id, mod_actid;
    SliderOrientation mod_ori;
    V2f mod_p0, mod_p1;
    Bounds2f mod_knob;
    V2f mod_ofs, mod_mouseBase;
    float mod_nPosBase;
    int mod_dir; //0:unknown, 1:h, 2:v

    void modSet(uint id, in SliderOrientation ori, V2f p0, V2f p1, in Bounds2f bKnob){
      mod_id = id;
      mod_ori = ori;
      mod_p0 = p0;
      mod_p1 = p1;
      mod_knob = bKnob;
    }
  }

  uint id;
  SliderOrientation orientation = SliderOrientation.auto_;
  RGB bkColor;
  RGB   clLine, clThumb, clRuler;
  float lwLine, lwThumb, lwRuler, rulerOfs;

  int rulerDiv0 = 9, rulerDiv1 = 4;
  ubyte rulerSides=3;

  float nPos, nCenter=0;  //center is the start of the marking on the line
  int wrapCnt; //for endless, to see if there was a wrapping or not. Used to reconstruct actual value

  Bounds2f hitBounds;

  this(uint id, ref float nPos_, in im.range range_, ref bool userModified, TextStyle ts=tsNormal){
    this.id = id;
    hitTestManager.addHash(this, id);
    auto hit = hitTestManager.check(id);

    hitBounds = hit.hitBounds;

    //todo: enabled for slider
/*    bool en = true;
    if(!en){
    }else if(hit.captured){
//      ts.fontColor = clLinkPressed;
    }else{
//      ts.fontColor = lerp(ts.fontColor, clLinkHover, hit.hover_smooth);
//      ts.underline = hit.hover;
    }*/

    nPos = nPos_;

    bkColor = ts.bkColor;

    clThumb = lerp(lerp(clSliderThumb, clSliderThumbHover, hit.hover_smooth), clSliderThumbPressed, hit.captured_smooth);
    clLine =  lerp(lerp(clSliderLine , clSliderLineHover , hit.hover_smooth), clSliderLinePressed , hit.captured_smooth);
    clRuler = lerp(bkColor, ts.fontColor, 0); //disable ruler for now

    innerSize = V2f(ts.fontHeight*6, ts.fontHeight); //default size

    float thumbSize = ts.fontHeight*0.8;
    rulerOfs = thumbSize*0.5f;
    lwThumb = thumbSize*(1.0f/3);
    lwLine  = thumbSize*(2.0f/NormalFontHeight);
    lwRuler = lwLine*0.5f;

    //hit.pressed
    const isLinear = mod_ori.among(SliderOrientation.horz, SliderOrientation.vert);
    const isRound = mod_ori==SliderOrientation.round;
    const precise = inputs.Shift.active ? 0.125f : 1;
    if(hit.pressed){  //todo: enabled handling
      userModified = true;
      mod_actid = id;

      //decide wether the knob has to jump to the mouse position or not
      const doJump = mod_id==id && isLinear && !mod_knob.checkInside(currentMouse);
      if(doJump) mod_ofs = V2f.Null;
            else mod_ofs = mod_knob.center-currentMouse;

      if(doJump){
        if(mod_ori==SliderOrientation.horz){
          nPos = remap_clamp(currentMouse.x, mod_p0.x, mod_p1.x, 0, 1);
          if(currentMouse.x<mod_p0.x) mod_ofs.x = mod_p0.x-currentMouse.x;
          if(currentMouse.x>mod_p1.x) mod_ofs.x = mod_p1.x-currentMouse.x - (range_.isEndless ? 1 : 0); //otherwise endles range_ gets into an endless incrementing loop
        }else if(mod_ori==SliderOrientation.vert){
          nPos = remap_clamp(currentMouse.y, mod_p0.y, mod_p1.y, 0, 1);
          if(currentMouse.y<mod_p0.y) mod_ofs.y = mod_p0.y-currentMouse.y; //todo: test vertical circular slider jump to the very ends, and see if not jumps to opposite si
          if(currentMouse.y>mod_p1.y) mod_ofs.y = mod_p1.y-currentMouse.y - (range_.isEndless ? 1 : 0);
        }
      }

      if(isRound){
        mouseLock;
        mod_mouseBase = rawMousePos;
        mod_nPosBase = nPos;
        mod_dir = 0;
      }
    }

    //continuous update if active
    if(id==mod_actid){
      userModified = true;

      clThumb = clRed;

      if(isLinear) slowMouse(precise!=1, precise);

      if(mod_ori==SliderOrientation.horz){
        auto p = currentMouse.x+mod_ofs.x;
        if(range_.isCircular || range_.isEndless) mouseMoveRelX(wrapInRange(p, mod_p0.x, mod_p1.x, wrapCnt)); //circular wrap around
        nPos = remap(p, mod_p0.x, mod_p1.x, 0, 1);
        if(range_.isClamped) nPos = nPos.clamp(0, 1);
      }else if(mod_ori==SliderOrientation.vert){
        auto p = currentMouse.y+mod_ofs.y;
        if(range_.isCircular || range_.isEndless) mouseMoveRelY(wrapInRange(p, mod_p0.y, mod_p1.y, wrapCnt)); //circular wrap around
        nPos = remap(p, mod_p0.y, mod_p1.y, 0, 1);
        if(range_.isClamped) nPos = nPos.clamp(0, 1);
      }else{
        auto diff = rawMousePos-mod_mouseBase;

        auto act_dir = abs(diff.x)>abs(diff.y) ? 1 : 2;

        if(mod_dir==0 && diff.len_prec>=3) mod_dir = act_dir;

        auto delta = (mod_dir ? mod_dir : act_dir)==1 ? inputs.MXraw.delta : inputs.MYraw.delta;

        mod_nPosBase += delta*(precise*(1.0f/180));

        mod_nPosBase = mod_nPosBase.clamp(0, 1);

        nPos = mod_nPosBase;
          //todo: endless????
          //todo: ha tulmegy, akkor vinnie kell magaval a base-t is!!!
          //todo: Ctrl precizitas megoldasa globalisan az inputs.d-ben.
      }
    }

    //hit.released
    if(hit.released){
      mod_actid = 0;

      //todo: this isn't safe! what if the control disappears!!!
      if(isLinear){
        slowMouse(false);
      }else{
        mouseUnlock;
      }
    }

    if(userModified)
      nPos_ = nPos;
  }

  override Bounds2f getHitBounds(){
    return innerBounds;
  }

  override void draw(Drawing dr){
    const mod_update = !hitBounds.isNull && !inputs.LMB.value;

    dr.color = bkColor; dr.fillRect(borderBounds_inner);
    drawBorder(dr);

    dr.alpha = 1; dr.lineStipple = lsNormal; dr.arrowStyle = asNone;
    void drawThumb(V2f a, V2f t){ dr.lineWidth = lwThumb; dr.color = clThumb; dr.line(a-t.vRot90, a+t.vRot90); }
    void drawLine(V2f a, V2f b, RGB cl){ dr.lineWidth = lwLine; dr.color = cl; dr.line(a, b); }

    auto b = innerBounds;
    orientation.calcSliderOrientation(b);

    if(orientation==SliderOrientation.horz){
      auto t = V2f(lwThumb, 0),
           ro = V2f(0, rulerOfs),
           p0 = b.leftCenter  + t,
           p1 = b.rightCenter - t;

      drawLine(p0, p1, clLine);

      if(rulerSides&1) drawStraightRuler(dr, Bounds2f(p0-ro, p1-ro*0.4f), rulerDiv0, rulerDiv1, true );
      if(rulerSides&2) drawStraightRuler(dr, Bounds2f(p0+ro*0.4f, p1+ro), rulerDiv0, rulerDiv1, false);

      if(!nPos.isNaN){
        auto p = vLerp(p0, p1, nPos);
        if(!nCenter.isNaN) drawLine(vLerp(p0, p1, nCenter), p, clThumb);
        drawThumb(p, t);

        if(mod_update) modSet(id, orientation, dr.inputTransform(p0), dr.inputTransform(p1), dr.inputTransform(Bounds2f(p, p).inflated(lwThumb*0.5, lwThumb*1.5)));
      }

    }else if(orientation==SliderOrientation.vert){
      auto t = V2f(0, -lwThumb),
           ro = V2f(rulerOfs, 0),
           p0 = b.bottomCenter + t,
           p1 = b.topCenter    - t;

      drawLine(p0, p1, clLine);

      if(rulerSides&1) drawStraightRuler(dr, Bounds2f(p1-ro, p0-ro*0.4f), rulerDiv0, rulerDiv1, true );
      if(rulerSides&2) drawStraightRuler(dr, Bounds2f(p1+ro*0.4f, p0+ro), rulerDiv0, rulerDiv1, false);

      if(!nPos.isNaN){
        auto p = vLerp(p0, p1, nPos);
        if(!nCenter.isNaN) drawLine(vLerp(p0, p1, nCenter), p, clThumb);
        drawThumb(p, t);
        if(mod_update) modSet(id, orientation, dr.inputTransform(p0), dr.inputTransform(p1), dr.inputTransform(Bounds2f(p, p).inflated(lwThumb*1.5, lwThumb*0.5)));
      }
    }else if(orientation==SliderOrientation.round){
      //center square
      bool endless = false;

      b = b.fittingSquare;
      if(mod_update) modSet(id, orientation, dr.inputTransform(b.center), dr.inputTransform(b.center), dr.inputTransform(b));

      auto c = b.center, r = b.width*0.4f;

      if(rulerSides) drawRoundRuler(dr, c, r, rulerDiv0, rulerDiv1, endless);
      r *= 0.8f;

      float a0 = (endless ? 0 : 0.25f)*PIf;
      float a1 = (endless ? 2 : 1.75f)*PIf;

      dr.lineWidth = lwLine;
      dr.color = clLine;
      dr.circle(c, r, a0, a1);

      if(!nPos.isNaN){
        float n = 1-nPos;
        n = endless ? n.fract : n.clamp(0, 1);  //todo: ezt megcsinalni a range-val
        float a = lerp(a0, a1, n);
        if(!endless && !nCenter.isNaN){
          float ac = lerp(a0, a1, (1-nCenter).clamp(0, 1));
          dr.color = clThumb;
          if(ac>=a) dr.circle(c, r, a, ac);
               else dr.circle(c, r, ac, a);
        }

        dr.lineWidth = lwThumb;
        dr.color = clThumb;
        auto v = V2f(sin(a), cos(a));
        dr.line(c, c+v*r);
      }
    }
  }

  // Draw Rulers
  protected void drawStraightRuler(Drawing dr, in Bounds2f r, int cnt, int cnt2=-1, bool topleft=true){
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

  protected void drawRoundRuler(Drawing dr, in V2f center, float radius, int cnt, int cnt2=-1, bool endless=false){
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

class Document : Column { // Document /////////////////////////////////
  this(){
    super(tsNormal);
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

    auto hit = hitTestManager.check(hash);

    if(enabled && onClick !is null && hit.clicked){
      onClick();
    }

    if(!enabled){
      ts.fontColor = clLinkDisabled;
      ts.underline = false;
    }else if(hit.captured){
      ts.fontColor = clLinkPressed;
    }else{
      ts.fontColor = lerp(ts.fontColor, clLinkHover, hit.hover_smooth);
      ts.underline = hit.hover;
    }

    hitTestManager.addHash(this, hash); //register this hash for this cell

    flags.canWrap = false;

    auto params = cmdLine.commandLineToMap;
    super(params["0"], ts);
    setProps(params);
  }
}

class Clickable : Row{ //Clickable / ChkBox / RadioBtn ///////////////////////////////

  this(uint id, string markup, TextStyle ts, string[string] params){
    hitTestManager.addHash(this, id);

    flags.canWrap = false;

    super(markup, ts);
    setProps(params);
  }
}

class KeyComboOld : Row{ //KeyCombo ///////////////////////////////

  this(string markup, TextStyle ts = tsKey){
    auto allKeys = inputs.entries.values.filter!(e => e.isButton && e.value).array.sort!((a,b)=>a.pressedTime<b.pressedTime, SwapStrategy.stable).map!"a.name".array;

    if(allKeys.canFind(markup)) ts.bkColor = clLime;

    margin_ = Margin(1, 1, 0.75, 0.75);
    padding_ = Padding(2, 2, 0, 0);
    border_.width = 1;
    border_.color = clGray;
    flags.canWrap = false;

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

/+
ContainerBuilder builder(Container cntr){
  return ContainerBuilder(cntr);
}

struct ContainerBuilder{ //ContainerBuilder //////////////////////////////

//type containers
  struct id       { uint val; }
  struct enabled  { bool val = true; }
  struct disabled { bool val; }
  struct selected { bool val; }

  struct color    { RGB val; }
  struct bkColor  { RGB val; }
  struct fontColor{ RGB val; }

  struct onClick  { void delegate() val; }
  struct onPress  { void delegate() val; }
  struct onRelease{ void delegate() val; }
  struct onHold   { void delegate() val; }
  struct onChange { void delegate() val; }

  struct onRightClick{ void delegate() val; }
  struct manual   { bool val; } //emulate button press

//builder state

  Container container;
  private uint indentCnt; //todo: ez qrvara nem ide, mert mi van, ha tobb builder van

  this(Container container_){
    container = container_;
    enforce(container !is null);
  }

  ~this(){
  }

  string prop (string s){ return tag(`prop ` ~s);}
  string style(string s){ return tag(`style `~s);}

  void indent(int delta=1){ indentCnt += delta; }
  void unindent(int delta=1){ indent(-delta); }

  /*deprecated*/ void row(T...)(T args){
    TextStyle ts = tsNormal;

    Row actRow;

    void ensureActRow(){
      if(actRow is null){
        actRow = new Row("", ts);
        actRow.bkColor = ts.bkColor;
        container.append(actRow);
      }
    }

    void closeActRow(){
      if((actRow !is null) && actRow.subCells is null){
        actRow.innerHeight = ts.fontHeight;
      }
      actRow = null;
    }

    void appendText(string s){
      ensureActRow;
      if(actRow.subCells.empty && indentCnt>0)
        s = "\t".replicate(indentCnt) ~ s;
      actRow.appendMarkupLine(s, ts);
    }

    void appendLines(string a){
      auto lines = a.split('\n').map!(a => a.withoutEnding('\r')).array;
      foreach(int i, s; lines){
        appendText(s);
        const isLast = i+1==lines.length;
        if(!isLast) closeActRow;
      }
    }

    static foreach(a; args){
      static if(is(typeof(a)==string)){
        appendLines(a);
      }else static if(is(typeof(a) : Cell)){
        if(a !is null){
          ensureActRow;
          actRow.append(cast(Cell)a);
        }
      }else static if(is(immutable typeof(a)==immutable TextStyle)){ //todo: is2 or std.traits.isSame
        ts = a;
      }else static if(is(immutable typeof(a)==immutable RGB8)){
        ts.fontColor = a;
      }else static if(is(immutable typeof(a)==immutable Cell[])){ //todo: ne csak cellre menjen
        foreach(int idx, cell; a){
          ensureActRow;
          if(cell !is null){
            if(idx>0) appendText("  "); //todo: ez nem lesz jo igy, mert Row[]-ra mashogy megy.
            actRow.append(cast(Cell)cell);
          }
        }
      }else static if(is(immutable typeof(a)==immutable Row[])){ //todo: ne csak cellre meg row-ra menjen
        foreach(int idx, cell; a){
          ensureActRow;
          if(cell !is null){
            actRow.append(cast(Cell)cell);
          }
        }
      }else static if(isIterable!(typeof(a))){ //todo: ezt rendberakni, hogy a felso kettot ki lehessen szedni
        foreach(v; a){
          auto cell = cast(Cell)v;
          if(cell !is null)
            actRow.append(cell);
        }
      }else static if(__traits(compiles, a.text)){
        appendText(a.text);
      }else{
        static assert(false, "Unsupported type: "~typeof(a).stringof);
      }
    }

    closeActRow;

  }

  //special rows
  void title   (string s) { container.parse(tag("title"   )~s); } //todo: it's not good, because it is not inside row(...)
  void chapter (string s) { container.parse(tag("chapter" )~s); }
  void chapter1(string s) { container.parse(tag("chapter1")~s); }
  void chapter2(string s) { container.parse(tag("chapter2")~s); }
  void comment (string s) { container.parse(tag("comment" )~s); }

  string bold(string s) { return tag("bold")~s~tag(""); }

  void img(string s) { row(tag(`img "`~s~`"`)); }

  void vSpace(int height=8, RGB color = clWhite){
    TextStyle ts = tsNormal;
    ts.fontHeight = height.to!ubyte;
    ts.bkColor = color;
    row(ts, " ");
  }

  void _winRowinternal(string markup, TextStyle ts = tsNormal){
    auto wr = new WinRow(markup, ts); //does extra padding
    container.append(wr);
  }

  void winHeader(string caption, string title, RGB bkColor = clWhite){
    if(!caption.empty){
      TextStyle ts = tsSmaller; ts.bkColor = bkColor;
      _winRowinternal("User Account Control", ts);
    }
    if(!title.empty){
      TextStyle ts = tsLarger; ts.bkColor = bkColor;
      _winRowinternal(`Do you want to allow this app to make changes to your device?`, ts);
      vSpace(4, bkColor);
    }
  }

  void winRowLarge(string text){ vSpace(4); _winRowinternal(text, tsLarger ); vSpace(4); }
  void winRowSmall(string text){ _winRowinternal(text, tsSmaller); }
  void winRow     (string text){ _winRowinternal(text           ); }

  void winLink(string text, uint hash, bool enabled, void delegate() onClick){
/*    auto wr = new WinRow("");
    auto l = new Link(text, hash, enabled, onClick);
    wr.append(l);
    container.append(wr);*/
  }

  void winBtnRow(T : Cell)(T[] cells, TextStyle ts = tsNormal){
    vSpace(4);
    auto wr = new WinRow("", ts);

    foreach(i, c; cells){
      wr.append(c);
      const last = i+1==cells.length;
      if(!last) wr.append(new Row(tag("prop width=8"), ts)); //todo: make it with join()
    }

    container.append(wr);

    vSpace(4);
  }

  protected  uint resolveId(uint id1, lazy uint id2){ return id1 ? id1 : id2;  }

  //gets params from cmdLine, enabled, id, hit
  protected mixin template Helper(){
    auto params = cmdLine.commandLineToMap,
         en = args.paramByType!(enabled, true) && !args.paramByType!disabled,
         sel = args.paramByType!(selected),
         id = resolveId(args.paramByType!(ContainerBuilder.id, true), file.xxh(line)),
         hit = hitTestManager.check(id),

         onRightClick_ = args.paramByType!onRightClick,
         manualHold = args.paramByType!(manual, false); //todo: ezt megcsinalni szepen

    void handleRightClick(){
      if(en && onRightClick_ !is null && hit.hover && inputs.RMB.pressed){
        onRightClick_();
      }
    }

    void btnEvents(){
      if(en){
        if(hit.clicked) args.paramCall!(onClick, true);
        if(hit.captured || manualHold) args.paramCall!onHold;
        if(hit.pressed)  args.paramCall!onPress;
        if(hit.released) args.paramCall!onRelease;
        if(hit.pressed || hit.released) args.paramCall!onChange;
      }
    }

    RGB hoverColor(RGB baseColor, RGB bkColor) {
      return !en ? clWinBtnDisabledText
                 : lerp(baseColor, bkColor, hit.captured ? 0.5 : hit.hover_smooth*0.3);
    }
  };

  protected mixin template GetChkBoxColors(){
    auto baseFontColor = args.paramByType!(fontColor, false, fontColor(clWinText));
    auto baseMarkColor = args.paramByType!(color, true, color(clAccent));
    auto baseBkColor = args.paramByType!(bkColor, false, bkColor(clWinBackground));
    auto markColor = hoverColor(state ? baseMarkColor : baseFontColor, baseBkColor);
    auto textColor = hoverColor(baseFontColor                        , baseBkColor);

    Clickable newChkBox(string mark){
      auto ts = tsNormal; ts.fontColor = markColor;

      auto capt = params.get("0", "");

      return new Clickable(id, mark~
                         tag(`style fontColor="`~textColor.text~`"`)~
                         (capt=="" ? "" : " ")~capt, ts, params);
    }
  }

  FlexRow flex(string markup=""){ return new FlexRow(markup); }

  Clickable btn(string file=__FILE__, int line=__LINE__, T...)(string cmdLine, T args){ mixin Helper; handleRightClick();
    btnEvents;

    auto ts = tsBtn,
         brd = Border(2, BorderStyle.normal, lerp(ts.bkColor, clWinBtnHoverBorder, hit.hover_smooth));
    if(!en){
      ts.fontColor = clWinBtnDisabledText;
      brd.color = ts.bkColor;
    }else if(hit.captured){
      brd.style = BorderStyle.none;
      ts.bkColor = clWinBtnPressed;
    }

    if(sel){
      ts.bkColor = lerp(ts.bkColor, clAccent, .5);
      brd.color  = lerp(brd.color , clAccent, .5);
    }

    auto b = new Clickable(id, tag("flex")~params.get("0", "")~tag("flex"), ts, params);
    b.margin = Margin(2, 2, 2, 2); //todo: adjacent margin's should collapse into each other
    b.border = brd;
    b.padding = Padding(2, 2, 2, 2);

    return b;
  }

  Clickable chkBox(string file=__FILE__, int line=__LINE__, T...)(string cmdLine, T args){ mixin Helper; handleRightClick();
    btnEvents;

    //update checkbox state
    auto state = false;
    args.paramGetter(state);
    if(en && hit.clicked){
      state.toggle;
      args.paramSetter(state);
    }

    mixin GetChkBoxColors;
    return newChkBox(tag(`symbol Checkbox`~(state?"CompositeReversed":"")));
  }

  Clickable radioBtn(string file=__FILE__, uint line=__LINE__, T...)(string cmdLine, T args){ mixin Helper; handleRightClick();
    btnEvents;

    //update checkbox state
    auto state = false;
    args.paramGetter(state);
    if(en && hit.clicked){
      state = true;
      args.paramSetter(state);
    }

    mixin GetChkBoxColors;
    return newChkBox(tag(`symbol RadioBtn`~(state?"On":"Off")));
  }

  void menuItem(string ico, string caption, string key){

    const
      hash = caption.xxh,
      hover = hitTestManager.checkHover(hash), //check if the last frame had a hit
      smoothHover = hitTestManager.checkHover_smooth(hash);

    auto ts = tsNormal; ts.bkColor = clMenuBk;

    ts.bkColor = lerp(ts.bkColor, clMenuHover, smoothHover);

    auto r = new Row(tag("prop padding.vert=2 padding.horz=12"), ts);
    hitTestManager.addHash(r, hash); //register this hash for this cell. This rtegistration is for the next frame only

    r.border.width = 1;
    r.border.color = clRed;

    auto icon = new Row((ico.length ? tag(`symbol "`~ico~`"`) : ""), ts); icon.outerWidth = 28;
    auto capt = new Row(caption, ts); capt.flex_ = 1;

    r.append([icon, capt]);

    if(key=="*SUBMENU*"){
      r.append(new Row(tag("symbol ChevronRight"), ts));
    }else{
      if(key.length) r.append(new KeyComboOld(key));
    }



    container.append(r);
  }

  void subMenu(string ico, string s){ menuItem(ico, s, "*SUBMENU*"); }

  void menuLine(){
    auto rOuter = new Row(tag("prop padding.vert=4 padding.horz=14"));
    rOuter.bkColor = clMenuBk;

    auto rLine = new Row(tag("prop height=0.5 bkColor=0x808080 flex=1"));
    rOuter.append(rLine);

    container.append(rOuter);
  }


/*  void hSlider(string capt, ref float value, ContainerBuilder.range range, string outputFormat, float outputWidth=50){
    float a = range.normalize(value);

    auto sl = new Slider(capt.xxh, a);

    row(capt.empty ? "" : capt~"\t", sl, outputFormat.empty ? null : new Row(tag("prop width="~outputWidth.text)~tag("flex")~outputFormat.format(value)));
  }*/

  Slider hSlider(string file=__FILE__, int line=__LINE__, T...)(string cmdLine, T args){ mixin Helper; handleRightClick(); //todo: so many things are the same for vSlider
    btnEvents;

/*    auto ts = tsBtn,
         brd = Border(2, BorderStyle.normal, lerp(ts.bkColor, clWinBtnHoverBorder, hit.hover_smooth));
    if(!en){
      ts.fontColor = clWinBtnDisabledText;
      brd.color = ts.bkColor;
    }else if(hit.captured){
      brd.style = BorderStyle.none;
      ts.bkColor = clWinBtnPressed;
    }*/

    auto range = args.paramByType!range;

    alias ValueType = paramGetterType!T;
    //todo: check for suitable types here

    ValueType value;
    args.paramGetter(value);
    static assert(isIntegral!ValueType || isFloatingPoint!ValueType, "Slider needs integer or floating point input. Got: "~ValueType.stringof);

    float normValue = range.normalize(value);

    int wrapCnt;
    if(range.isEndless){
      wrapCnt = normValue.floor.iRound;  //todo: refactor endless wrapCnt stuff
      normValue = normValue-normValue.floor;
    }

    bool userModified;
    auto sl = new Slider(id, normValue, range, userModified);
    sl.setProps(params);

    if(userModified){

      if(range.isEndless) normValue += wrapCnt-sl.wrapCnt;

      float f = range.denormalize(normValue);
      static if(isIntegral!ValueType) f = round(f);
      value = f.to!ValueType;

      args.paramSetter(value);
    }

    return sl;
  }


} +/


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
  V2f mouse;
}


struct SizingFrame{
  Bounds2f bounds;
  V2f cornerSize;
  V2f cornerSize2; //inner with gap added

  Seg2f[] edge(int idx){ with(bounds){  // top, right, bottom, left
    alias c = cornerSize2;
    switch(idx&3){
      case  0: return [Seg2f(x0+c.x, y0, x1-c.x, y0)];
      case  2: return [Seg2f(x0+c.x, y1, x1-c.x, y1)];
      case  1: return [Seg2f(x1, y0+c.y, x1, y1-c.y)];
      default: return [Seg2f(x0, y0+c.y, x0, y1-c.y)];
    }
  }}

  Seg2f[] corner(int idx){ with(bounds){  // topRight, bottomRight, bottomLeft, topLeft
    alias c = cornerSize;
    auto a(float x, float y, float dx, float dy){ return [ Seg2f(x, y, x+dx*c.x, y), Seg2f(x, y, x, y+dy*c.y) ]; }
    switch(idx&3){
      case  0: return a(x1, y0, -1,  1);
      case  1: return a(x1, y1, -1, -1);
      case  2: return a(x0, y1,  1, -1);
      default: return a(x0, y0,  1,  1);
    }
  }}

  Seg2f[][] cornersAndEdges(){
    return iota(8).map!(i => i&1 ? corner(i>>1) : edge(i>>1)).array;
  }
}


auto calcSizingFrame(in Bounds2f fullBounds, in WinContext ctx){

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
  f.cornerSize = vMin(V2f(maxCornerLen, maxCornerLen), maxCornerSize);
  auto gapLen = ctx.cornerThickness * ctx.pixelSize * 1.0f;
  f.cornerSize2 = vMin(f.cornerSize + V2f(gapLen, gapLen), maxCornerSize);

  return f;
}


class ImWin{ // ImWin //////////////////////////////////
  static WinContext ctx; //must update from outside

  Bounds2f bounds;
  string caption;
  bool focused;

  this(string caption_, Bounds2f bounds_){
    caption = caption_;
    bounds = bounds_;
    adjustBounds;
  }

  V2f sizeMin = V2f(32, 32);
  V2f sizeMax;               // ignored if less than sizeMin
  float sizeStep = 0;        // ignored if <=0
  float aspect = 0;          // if nonzero

  V2f placementBase;
  float placementStep = 0;

  void draw(Drawing dr, in V2f size){
    dr.color = clGray;
//    dr.fillRect(V2f(0, 0), size);

    auto tex = textures[File(`c:\dl\oida6.png`)];
    dr.drawGlyph(tex, Rect2f(V2f(0, 0), size));

    dr.scale(ctx.pixelSize); scope(exit) dr.pop;

    PERF("capt", {
      auto doc = scoped!Column(tsNormal);
      doc.innerWidth = size.x/dr.scaleFactor.x;
      auto icon = "\U0001F4F9";
      auto rIcon = new Row(" "~icon~" ");

      auto clHeaderBackground = clWinBackground;
      auto clHeaderText       = lerp(clWinText, clHeaderBackground, focused ? 0 : 0.35);

      auto toolBtn(string s, RGB textColor=clHeaderText, RGB bkColor=clHeaderBackground){
        return new Row(tag(`style fontColor="%s" bkColor="%s"`.format(textColor, bkColor))~" "~s~" ");
      }

      auto rCaption  = toolBtn(caption);
      auto rMaximize = toolBtn(tag("symbol ChromeMaximize"));
      auto rClose    = toolBtn(tag("symbol ChromeClose"), clWhite, clWinRed);

      auto rPlay     = toolBtn(tag("symbol PlaySolid"), clAccent);
      auto rPause    = toolBtn(tag("symbol Pause"));

      auto rLeft = new Row("");
      rLeft.append([rIcon, rCaption, rPlay, rPause]);
      rLeft.measure;

      auto rRight = new Row("");
      rRight.append([rMaximize, rClose]);
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

    bounds.sortBounds;
    return;
    float w = bounds.width, h = bounds.height;

    if(aspect>0){
      //tries to make the diagonal az close az can
      auto dBounds = V2f(w, h).len_prec,
           dAspect = V2f(aspect, 1).len_prec;
      auto dRate =  dBounds/dAspect;

      w = aspect*dRate;
      h = dRate;
    }

    auto newPos  = V2f(adjustPlacement(bounds.bMin.x, placementBase.x, placementStep),
                       adjustPlacement(bounds.bMin.y, placementBase.y, placementStep)),
         newSize = V2f(adjustSize(w, sizeMin.x, sizeMax.x, sizeStep),
                       adjustSize(h, sizeMin.y, sizeMax.y, sizeStep));

    //anchor is topLeft
    bounds.bMin = newPos;
    bounds.bMax = newPos + newSize;
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

    auto clHalf = lerp(clNormal, clAccent, .5),
         inside = bounds.checkInside(mouse);

    if(pass==0){
      if(inside) hovered = this;

      //draw contents
      dr.translate(bounds.topLeft);
      draw(dr, bounds.size);
      dr.pop;

      if(focused){
        auto elements = sizingFrame.cornersAndEdges;

        dr.lineWidth = -cornerThickness;
        dr.color = lerp(clNormal, clAccent, 0.99f);
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

auto testWin(Drawing dr, V2f mouse, float pixelSize){ // testWin() ///////////////////////////////////////

  static wins = [
    new ImWin("win1", Rect2f(0  ,   0, 640, 480)),
    new ImWin("win2", Rect2f(640,   0, 640, 480)),
    new ImWin("win3", Rect2f(0  , 480, 600, 300)),
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
  import std.traits;

  //Frame handling
  bool mouseOverUI, wantMouse, wantKeys;
  private bool inFrame, canDraw; //synchronization for internal methods

  float deltaTime=0;

  //todo: package visibility is not working as it should -> remains public
  void _beginFrame(in V2f mousePos){ //called from mainform.update
    enforce(!inFrame, "im.beginFrame() already called.");

    //update building/measuring/drawing state
    inFrame = true;
    canDraw = false;

    im.reset;
    currentMouse = mousePos;
    hitTestManager.initFrame;

    //clear last frame's object references
    focusedState.container = null;
    textEditorState.beginFrame;

    static DeltaTimer dt;
    deltaTime = dt.update;
  }

  void _endFrame(in Bounds2f screenBounds){ //called from end of update
    enforce(inFrame, "im.endFrame(): must call beginFrame() first.");
    enforce(stack.length==1, "FATAL ERROR: im.endFrame(): stack is corrupted. 1!="~stack.length.text);

    auto rc = rootContainers(true);

    //measure
    foreach(a; rc) a.measure;

    //align
    foreach(a; rc) a.applyPanelPosition(screenBounds);

    applyScrollers(screenBounds);

    //from here, all positions are valid

    //hittest in zOrder (currently in reverse creation order)
    mouseOverUI = false;
    foreach_reverse(a; rc)
      if(a.hitTest(currentMouse))
        mouseOverUI = true;

    //the IM GUI wants to use the mouse for scrolling or clicking. Example: It tells the 'view' not to zoom.
    wantMouse = mouseOverUI;

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

  void draw(Drawing dr){
    enforce(canDraw, "im.draw(): canDraw must be true. Nothing to draw now.");

    foreach(r; root) r.draw(dr); //draw in zOrder

    hitTestManager.draw(dr);

    //not needed, gc is perfect.  foreach(r; root) if(r){ r.destroy; r=null; } root.clear;
  }

  void Panel(T...)(T args){ //todo: multiple Panels, but not call them frames...
    import het.win;
auto t0=QPS;
    //im.beginFrame(mainWindow.mouse.act.screen.toF);  called from winMain update
auto t1=QPS;
    Document({
      padding = "4";
      border = "1 normal silver";

      static foreach(a; args){{
        alias t = Unqual!(typeof(a));
        static if(is(t == PanelPosition)) flags.panelPosition = a; //PanelPosition
        static if(__traits(compiles, a())) if(a) a(); //delegate/function
      }}

    });
auto t2=QPS;
    //im.endFrame;  //called from winMain update
auto t3=QPS;

static cnt=0;
    if(((cnt++)&31)==0){
    //todo: ezeket a performance adatokat egy uira kirakni.
//      writefln("begin: %5.3f  build:  %5.3f  end: %5.3f", t1-t0, t2-t1, t3-t2);
//      writeln(mainWindow.lastFrameStats);
//      import het.opengl;
//      glHandleStats.print;
//      hitTestManager.stats.print;
//      Cell.objCnt.print;
    }
  }

  // Focus handling /////////////////////////////////
  struct FocusedState{
    uint id;              //globally store the current hash
    .Container container;  //this is sent to the Selection/Draw routines. If it is null, then the focus is lost.

    void reset(){ this = typeof(this).init; }
  }
  FocusedState focusedState;

  TextEditorState textEditorState; //maintained by edit control


  bool focusUpdate(.Container container, uint id, bool canFocus, lazy bool enterFocusNow, lazy bool exitFocusNow, void delegate() onEnter, void delegate() onFocused, void delegate() onExit){
    if(focusedState.id==id){
      if(!canFocus || exitFocusNow){ //not enabled anymore: exit focus
        if(onExit) onExit();
        focusedState.reset;
      }
    }else{
      if(canFocus && enterFocusNow){ //newly enter the focus
        focusedState.id = id;
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
  bool isFocused(.Container container)  { return focusedState.container !is null && focusedState.container == container; }

//  void focusExit(uint id)               { if(isFocused(id)) focusedState.reset; }
//  void focusExit(Container container)   { if(isFocused(container)) focusedState.reset; }
//  void focusExit()                      { focusedState.reset; }


// ScrollState, scroller ////////////////////////////////////////////////
  struct ScrollState{ //currently it's for y only
    float scrollY = 0;
    float scrollY_smooth = 0;
  }

  class Scroller{   //todo: kinetic scrolling
    .Container container, parent;
    ScrollState* state;

    this(.Container container, .Container parent, ref ScrollState state){
      this.container = container;
      this.parent = parent;
      this.state = &state;
    }

    void apply(in Bounds2f screenBounds){ //must be called first, before update, so the positions are calculated well
      if(state) with(*state){
        float totalHeight = parent ? parent.innerHeight : screenBounds.height;
        float docHeight = container.outerHeight;  //todo: COPY

        if(totalHeight<docHeight){
          container.outerPos.y = scrollY_smooth;
        } //otherwise assume it's aligned properly. Only change the position when it doesn't fit in.
      }
    }

    void update(in Bounds2f screenBounds){
      if(state) with(*state){
        float totalHeight = parent ? parent.innerHeight : screenBounds.height;
        float docHeight = container.outerHeight; //todo: PASTE

        if(container.flags.hovered){ //todo: overlapping Panels not handled properly (all of them are scrolling, not just the topmost)
          import het.win;
          scrollY += mainWindow.mouse.delta.wheel*120; //todo: Window/mouse should it should come from outside
        }

        scrollY = scrollY.clamp(min(0, totalHeight-docHeight), 0);
        scrollY_smooth = lerp(scrollY_smooth, scrollY, 0.25);
        scrollY_smooth = scrollY_smooth.clamp(min(0, totalHeight-docHeight), 0);
      }
    }

  }

  Scroller[] scrollers;

  auto vScroll(ref ScrollState state){
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

    scrollers ~= new Scroller(actContainer, stack[$-2].container, state);

    return scrollers[$-1];
  }

  auto vScroll(string file=__FILE__ , int line=__LINE__, T...)(T args){ //todo: this is only good for unique panels
    mixin(id.M);
    __gshared static ScrollState[uint] cache;

    if(id_ !in cache) cache[id_] = ScrollState();

    return vScroll(cache[id_]);
  }

  private void applyScrollers(in Bounds2f screenBounds){
    foreach(sc; scrollers) sc.apply(screenBounds);
  }

  private void updateScrollers(in Bounds2f screenBounds){
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
    Bounds2f bounds;
    string markup, markupDetails; //todo: support delegates too
  }
  private HintRec[] hints;

  enum HintState { idle, active, details }
  static hintState = HintState.idle;

  /// This can be used to inject a hint into the parameters of a Control
  auto hint(string markup, string markupDetails=""){ //todo: delegate too
    return HintRec(null, Bounds2f.Null, markup, markupDetails); //todo: lazyness
  }

  void addHint(HintRec hr){ hints ~= hr; }

  void hideHints(){ hintState = HintState.idle; }

  private enum hintHandler = q{
    static foreach(a; args) static if(is(Unqual!(typeof(a)) == HintRec)){
      if(hit.hover){
        HintRec hr = a;
        hr.owner = actContainer;
        hr.bounds = hit.hitBounds;
        addHint(hr);
      }
    }
  };

  private void generateHints(in Bounds2f screenBounds){ //called on the end of the frame
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
                             + V2f(-hintContainer.outerWidth*.5, 5);

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
  .Container actContainer; //top of the containerStack for faster access
  bool enabled;
  uint baseId;
  TextStyle textStyle;   alias style = textStyle; //todo: style.opDispatch("fontHeight=0.5x")
  string theme; //for now it's a str, later it will be much more complex
  //valid valus: "", "tool"

  private struct StackEntry{ .Container container; uint baseId; bool enabled; TextStyle textStyle; string theme; }
  private StackEntry[] stack;

  void reset(){
    //statck reset
    baseId = 0;
    enabled = true;
    textStyle = tsNormal;
    theme = "";

    root = [];
    stack = [];
    push!(.Container)(null, 0); //null meaning -> root[] is the container

    //time calculation
    //todo: jobb neveket kell kitalalni erre
    //QPS = .QPS;
    //dt = lastQPS.isNaN ? 1.0f/60 : QPS-lastQPS;
    //lastQPS = QPS;
  }

  private void push(T : .Container)(T c, uint newId){ //todo: ezt a newId-t ki kell valahogy valtani. im.id-t kell inkabb modositani.
    stack ~= StackEntry(c, [newId].xxh(baseId), enabled, textStyle, theme);

    //actContainer is the top of the stack or null
    actContainer = c;
  }

  private void pop(){
    enforce(stack.length>1); //stack[0] is always null and it is never popped.

    //restore the last textStyle & theme. Changes inside a subHierarchy doesn't count.
    baseId    = stack.back.baseId;
    enabled   = stack.back.enabled;
    textStyle = stack.back.textStyle;
    theme     = stack.back.theme;

    stack.popBack;

    //actContainer is the top of the stack or null
    actContainer = stack.empty ? null : stack.back.container;
    //todo: the first stack container is always 0.
  }

  void dump(){
    void doit(Cell cell, int indent=0){
      print("  ".replicate(indent), cell.classinfo.name.split('.')[$-1], " ", cell.outerPos, cell.innerSize, cell.flex, cast(.Container)cell ? (cast(.Container)cell).flags.text : "");
      foreach(subCell; cell.subCells)
        doit(subCell, indent+1);
    }

    writeln("---- IM dump --------------------------------");
    foreach(cell; root) doit(cell);
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

  //easy access

  float fh(){ return textStyle.fontHeight; }

  auto subCells(){ return actContainer.subCells; }
  auto subCells(T : .Cell)(){ return actContainer.subCells.map!(c => cast(T)c).filter!(c => c !is null); }

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
  struct id      { uint val;  private enum M = q{ auto id_ = file.xxh(line)^baseId;                              static foreach(a; args) static if(is(Unqual!(typeof(a)) == id      )) id_       = [a.val].xxh(id_); }; }
  struct enable  { bool val;  private enum M = q{ auto oldEnabled = enabled; scope(exit) enabled = oldEnabled;   static foreach(a; args) static if(is(Unqual!(typeof(a)) == enable  )) enabled   = enabled && a.val; }; }
  struct selected{ bool val;  private enum M = q{ auto _selected = false;                                        static foreach(a; args) static if(is(Unqual!(typeof(a)) == selected)) _selected = a.val;            }; }

  enum RangeType{ linear, log, circular, endless }
  struct range{                                    //endless can go out of range, circular always using modulo.
    float min, max, step=1; RangeType type;

    //todo: handle invalid intervals
    bool isLinear  () const { return type==RangeType.linear  ; }
    bool isLog     () const { return type==RangeType.log     ; }
    bool isCircular() const { return type==RangeType.circular; }
    bool isEndless () const { return type==RangeType.endless ; }
    bool isClamped () const { return isLinear || isLog || isCircular; }

    float normalize(float x){
      auto n = isLog ? x.log2.remap(min.log2, max.log2, 0, 1)  //todo: handle log(0)
                     : x     .remap(min     , max     , 0, 1);
      if(isCircular) if(n<0 || n>1) n = n-n.floor;
      if(isClamped) n = n.clamp(0, 1);
      return n;
    }

    float denormalize(float n){
      if(isCircular) if(n<0 || n>1) n = n-n.floor;
      if(isClamped ) n = n.clamp(0, 1);

      return clamp(isLog ?  2 ^^ n.remap(0, 1, min.log2, max.log2)
                         :       n.remap(0, 1, min     , max     )); //clamp is needed because of rounding errors
    }

    T clamp(T)(T f){
      if(isIntegral!T){
        if(!min.isNaN && f<min.iCeil ) f = min.iCeil ; else
        if(!max.isNaN && f>max.iFloor) f = max.iFloor;
      }else{
        if(!min.isNaN && f<min) f = min; else
        if(!max.isNaN && f>max) f = max;
      }
      return f;
    }

    private enum M = q{ range _range;  static foreach(a; args) static if(is(Unqual!(typeof(a)) == range)) _range = a; };
  }

  auto logRange     (float min, float max, float step=1){ return range(min, max, step, RangeType.log     ); }
  auto circularRange(float min, float max, float step=1){ return range(min, max, step, RangeType.circular); }
  auto endlessRange (float min, float max, float step=1){ return range(min, max, step, RangeType.endless ); }


  string symbol(string def){ return tag(`symbol `~def); }
  void Symbol(string def){ Text(symbol(def)); }


  void Column(string file=__FILE__, int line=__LINE__, T...)(T args){  // Column //////////////////////////////
    auto column = new .Column(style);
    append(column); push(column, file.xxh(line)); scope(exit) pop;

    static foreach(a; args){{ alias t = typeof(a);
      static if(isFunctionPointer!a){
        a();
      }else static if(isDelegate!a){
        a();
      }else static assert(false, "Unsupported type: "~typeof(a).stringof);
    }}
  }

  void Row(string file=__FILE__, int line=__LINE__, T...)(T args){  // Row //////////////////////////////
    auto row = new .Row("", textStyle);
    append(row); push(row, file.xxh(line)); scope(exit) pop;

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

  void Container(string file=__FILE__, int line=__LINE__, T...)(T args){  // Composite //////////////////////////////
    auto cntr = new .Container(style);
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

  void Code(string src){ // Code /////////////////////////////
    //todo: syntax highlight
    //Spacer(0.5*fh);
    Column({
      margin = Margin(0.5*fh, 0.5*fh, 0.5*fh, 0.5*fh);

      style = tsCode;
      const bkColors = [0.06, 0.12].map!(t => lerp(textStyle.bkColor, textStyle.fontColor, t)).array;
      border = "1 single gray";

      foreach(idx, line; src.split('\n')){
        style.bkColor = bkColors[idx&1]; //alternated bkColor
        line = line.withoutEnding('\r');
        Text(line);
      }
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
    int t(int n){ return ((QPS*n*1.5).iFloor)%n; }
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
      style.fontColor = lerp(style.bkColor, style.fontColor, .66);
      Text(" "~progressSpinner(progressStyle)~" ");
    });
  }

//todo: flex N is fucked up. Treats N as 1 always.
//todo: flex() function cant work because of flex property.
//  string flex(string markup){ return tag(["flex", markup].join(" ")); }
//  string flex(float value){ return flex(value.text); } //kinda lame to do it with texts

  //Text /////////////////////////////////
  void Text(string file=__FILE__, int line=__LINE__, T...)(T args){ //todo: not multiline yet

    //todo: ugy nez ki, hogy nem kell ide a file, line.

    //multiline behaviour:
    //  parent is Row: if multiline -> make a column around it
    //  parent is column: multiline is ok. Multiple row emit
    //  actContainer is null: root level gets a lot of rows

    //Text is always making one line, even in a container. Use \n for multiple rows
    if(args.length>1 &&(actContainer is null || cast(.Column)actContainer !is null)){ //implicit row
      Row({ Text!(file, line)(args); });
      return;
    }

    bool restoreTextStyle = false;
    TextStyle oldTextStyle;
    static foreach(a; args){{
      alias t = typeof(a);
      static if(isSomeString!t){

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
        if(.Column col = cast(.Column)actContainer){
          Row({ Text(a); });  //implicit Rows for Column
        }else if(.Row row = cast(.Row)actContainer){
          row.appendMarkupLine(a, textStyle);
        }else {
          actContainer.appendMarkupLine(a, textStyle);
        }
      }else static if(is(Unqual!t == _FlexValue)){ //nasty workaround for flex() and flex property
        append(new FlexRow("", style));
      }else static if(is(Unqual!t == TextStyle)){
        if(chkSet(restoreTextStyle)) oldTextStyle = textStyle;
        textStyle = a;
      }
    }}

    if(restoreTextStyle)
      textStyle = oldTextStyle;

/*    auto r = cast(.Row)actContainer;
    if(r) r.appendMarkupLine(text, textStyle);
     else Row({ Text(text); });*/
  }

  void Comment(string file=__FILE__, int line=__LINE__, T...)(T args){
    // It seems a good idea, as once I wanted to type Comment(.. instead of Text(tsComment...
    Text!(file, line)(tsComment, args);
  }

  //ListItem ///////////////////////////////////
  void Bullet(){
    Row({ outerWidth = fh*2; Flex; Text(tag("char 0x2022")); Flex; }); //todo: no flex needed, -> center aligned. Constant width is needed however, for different bullet styles.
  }

  void ListItem(void delegate() contents = null){
    Row({
      Bullet;
      if(contents) contents();
    });
  }

  void ListItem(string text){
    ListItem({ Text(text); });
  }

  //Spacer //////////////////////////
  void Spacer(float size){
    const vertical = cast(.Row)actContainer !is null;

/*    auto r = new .Row("", textStyle);
    auto a = size/2;
    r.margin = vertical ? Margin(0, a, 0, a)
                        : Margin(a, 0, a, 0);
    append(r);*/

    Row({
      auto a = size/2;
      margin = vertical ? Margin(0, a, 0, a)
                        : Margin(a, 0, a, 0);
    });
  }


  /+private void _EditHandleInput(T0)(ref T0 value, ref string str, ref bool chg){ //handles e
    import het.win;
    if(mainWindow.inputChars.empty) return;

    with(EditCmd) foreach(ch; mainWindow.inputChars.unTag.byDchar){
      writeln(ch.to!int);
      if(ch>=32){
        textEditState.cmdQueue ~= EditCmd(cInsert, ch);
      }

/+      switch(ch){
        case 8:{ //backSpace
/*          try{
            str = str[0..$-str.strideBack];
          }catch{
            beep;
          }*/
          textEditState.cmdQueue ~= EditCmd(cDeleteBack);
        break;}
        case 13, 27: break;
        default: str ~= ch;+/
      }
    }

    try{
      auto newValue = str.to!T0; //write back value
      //todo: validate/clamp
      chg = value != newValue;
      if(chg) value = newValue;
    }catch(Throwable){}
  }+/

  auto Edit(string file=__FILE__, int line=__LINE__, T0, T...)(ref T0 value, T args){ // Edit /////////////////////////////////
    mixin(id.M ~ enable.M);
    bool chg;

    void value2editor(){ textEditorState.str = value.text; }
    void editor2value(){ try value = textEditorState.str.to!T0; catch{} } //todo: range clamp

    Row({
      flags.clipChildren = true;
      auto row = cast(.Row)actContainer;

      auto hit = hitTestManager.check(id_); //get the hittert from the last frame
      auto localMouse = currentMouse - hit.hitBounds.topLeft - row.topLeftGapSize;
      hitTestManager.addHash(actContainer, id_); //save the rect of this container for the next frame

      mixin(hintHandler);

      bool focused = focusUpdate(actContainer, id_,
        enabled,
        hit.pressed, //enter
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
                if(ch>=32){
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
          }
          //todo: A KeyCombo az ambiguous... nem jo, ha control is meg az input beli is ugyanolyan nevu.

        }
        mainWindow.inputChars = unprocessed;
      }

      style   = tsNormal;

      static if(std.traits.isNumeric!T0) flags.hAlign = HAlign.right;
                                    else flags.hAlign = HAlign.left;

      margin  = Margin(2, 2, 2, 2);
      border  = Border(2, BorderStyle.normal, lerp(clWinBtn, clWinBtnHoverBorder, hit.hover_smooth));
      padding = Padding(2, 2, 2, 2);

      if(!enabled){
        style.fontColor = lerp(style.fontColor, style.bkColor, 0.5);
        border.color    = lerp(clWinBtn       , style.bkColor, 0.5);
      }

      if(theme=="tool"){ //todo: refactor as this is same as in Btn
        style.bkColor   = lerp(style.bkColor, tsNormal.bkColor, .5);
        border.width    = 1;
//        border.location = BorderLocation.inside;
        margin .top = margin .bottom = 0;
        padding.top = padding.bottom = 0;
      }

      if(focused){
        border.color = clBlack;
        flags.dontHideSpaces = true;
      }

      //execute the delegate funct parameters
      static foreach(a; args) static if(__traits(compiles, a())){ a(); }

      //put the text out
      if(focused){
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

    return chg; //a hit testet vissza kene adni im.valtozoban
  }

  auto IncBtn(string file=__FILE__, int line=__LINE__, int sign=1, T0, T...)(ref T0 value, T args) if(sign!=0 && isNumeric!T0){ //IncBtn /////////////////////////////////
    mixin(id.M ~ enable.M ~ range.M);

    auto capt = symbol(`Calculator` ~ (sign>0 ? `Addition` : `Subtract`));
    enum isInt = isIntegral!T0;

    auto hit = Btn!(file, line)(capt, args, id(sign)); //2 id's can pass because of the static foreach
    bool chg;
    if(hit){
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
    return IncBtn!(file, line)(value, args)
        || DecBtn!(file, line)(value, args);
  }

  auto IncDec(string file=__FILE__, int line=__LINE__, T0, T...)(ref T0 value, T args){
    auto oldValue = value;
    Edit!(file, line)(value, { width = 2*fh; }, args); //todo: na itt total nem vilagos, hogy az args hova megy, meg mi a result
    IncDecBtn(value, args);
    return oldValue != value;
  }

  void applyBtnBorder(in RGB bColor = clWinBtn){ //todo: use it for edit as well
    margin  = Margin(2, 2, 2, 2);
    border  = Border(2, BorderStyle.normal, bColor);
    padding = Padding(2, 2, 2, 2);
    if(theme=="tool"){
      border.width    = 1;
      border.inset = true;
      margin .top = margin .bottom = 0;
      padding.top = padding.bottom = 0;
    }
  }

  auto Btn(string file=__FILE__, int line=__LINE__, T0, T...)(T0 text, T args)  // Btn //////////////////////////////
  if(isSomeString!T0 || __traits(compiles, text()) )
  {
    mixin(id.M ~ enable.M ~ selected.M);

    const isToolBtn = theme=="tool";

    auto hit = hitTestManager.check(id_); //get the hittest from the last frame

    Row({
      hitTestManager.addHash(actContainer, id_); //save the rect of this container for the next frame

      mixin(hintHandler);

      bool focused = focusUpdate(actContainer, id_,
        enabled, hit.pressed, false,  //enabled, enter, exit
        /* onEnter */ { },
        /* onFocus */ { },
        /* onExit  */ { }
      );

      //flags.canWrap = false;
      flags.hAlign = HAlign.center;

      style   = tsBtn;
      auto bColor = lerp(style.bkColor, clWinBtnHoverBorder, hit.hover_smooth);
      applyBtnBorder(bColor);

      if(!enabled){
        style.fontColor = clWinBtnDisabledText;
        border.color    = style.bkColor;
      }else if(hit.captured){
        border.style    = BorderStyle.none;
        style.bkColor   = clWinBtnPressed;
      }

      if(isToolBtn){ //every appearance is lighter on a toolBtn
        style.bkColor   = lerp(style.bkColor, tsNormal.bkColor, .5);
        if(hit.captured && enabled) border.width = 0; //this if() makes the edge squareish
      }

      if(_selected){
        style.bkColor = lerp(style.bkColor, clAccent, .5);
        border.color  = lerp(border.color , clAccent, .5);
      }

      bkColor = style.bkColor; //todo: update the backgroundColor of the container. Should be automatic, but how?...

      static if(isSomeString!T0) Text(text); //centered text
                            else text(); //delegate

    });

    return hit;
  }

  auto ToolBtn(string file=__FILE__, int line=__LINE__, T0, T...)(T0 text, T args){ //shorthand for tool theme
    auto old = theme; theme = "tool"; scope(exit) theme = old;
    return Btn!(file, line)(text, args);
  }

  auto ListItem(string file=__FILE__, int line=__LINE__, T0, T...)(T0 text, T args)  // ListItem //////////////////////////////
  if(isSomeString!T0 || __traits(compiles, text()) )
  {
    mixin(id.M ~ enable.M ~ selected.M);

    //todo: This is only the base of a listitem. Later it must communicate with a container

    auto hit = hitTestManager.check(id_); //get the hittert from the last frame
    Row({
      hitTestManager.addHash(actContainer, id_); //save the rect of this container for the next frame

      style = tsNormal; //!!! na ez egy gridbol kell, hogy jojjon!

      margin = "0";
      auto bcolor = lerp(style.fontColor, style.bkColor, .5);
      border       = Border(1, BorderStyle.normal, lerp(bcolor, style.fontColor, hit.hover_smooth));
      border.inset = true;
      border.extendBottomRight = true;
      padding = Padding(0, 2, 0, 2);

      style.bkColor = lerp(style.bkColor, clGray, hit.hover_smooth*.16);

      if(!enabled){
        style.fontColor = lerp(style.fontColor, clGray, 0.5); //todo: rather use an 50% overlay for disabled?
      }

      if(_selected){
        style.bkColor = lerp(style.bkColor, clAccent, .5);
        border.color  = lerp(border.color , clAccent, .5);
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
    auto hit = hitTestManager.check(id_);

    //update checkbox state
    if(enabled && hit.clicked) state.toggle;

    //mixin GetChkBoxColors;
    RGB hoverColor(RGB baseColor, RGB bkColor) {
      return !enabled ? clWinBtnDisabledText
                      : lerp(baseColor, bkColor, hit.captured ? 0.5 : hit.hover_smooth*0.3);
    }

    auto markColor = hoverColor(state ? clAccent : style.fontColor, style.bkColor);
    auto textColor = hoverColor(style.fontColor, style.bkColor);

    auto bullet = chkBoxStyle=="radio" ? tag(`symbol RadioBtn`~(state?"On":"Off"))
                                       : tag(`symbol Checkbox`~(state?"CompositeReversed":""));

    auto ts = style;
    auto ctrl = new Clickable(id_, format(tag("style fontColor=\"%s\"")~bullet~" "~tag("style fontColor=\"%s\"")~caption, markColor, textColor), ts, (string[string]).init);

    append(ctrl);
    return hit;
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
    shp.innerSize = V2f(0.7, 1)*style.fontHeight;
    shp.color = clRainbowRed;

    static foreach(a; args){{ alias t = Unqual!(typeof(a));
      static if(is(t==RGB)) shp.color = a;
      static if(is(t==V2f)) shp.innerSize = a;
    }}

    shp.color = lerp(clBlack, shp.color, state.remap(0, 1, 0.2, 1));

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

  // Slider ///////////////////////////
  auto Slider(string file=__FILE__, uint line=__LINE__, V, T...)(ref V value, T args)
  if(isFloatingPoint!V || isIntegral!V)
  {
    mixin(id.M ~ enable.M ~ selected.M ~ range.M);

//    float customWidth_;
    string props;
    static foreach(a; args){{ alias t = Unqual!(typeof(a));
      static if(isFloatingPoint!t || isIntegral!t) customWidth = a; //todo: ennek delegatenek kene lennie
      static if(isSomeString!t) props = a; //todo: ennek is
    }}

    float normValue = _range.normalize(value);

    int wrapCnt;
    if(_range.isEndless){
      wrapCnt = normValue.floor.iRound;  //todo: refactor endless wrapCnt stuff
      normValue = normValue-normValue.floor;
    }

    bool userModified;
    auto oldFh = style.fontHeight;
    if(theme != "tool") style.fontHeight = (fh*1.4).to!ubyte;

    auto sl = new .Slider(id_, normValue, _range, userModified, style);

    style.fontHeight = oldFh;

    sl.setProps(props);
    append(sl);

    if(userModified){

      if(_range.isEndless) normValue += wrapCnt-sl.wrapCnt;

      float f = _range.denormalize(normValue);
      static if(isIntegral!V) f = round(f);
      value = f.to!V;
    }

    //todo: what to return on from slider
    //return sl;
  }

  auto Node(ref bool state, void delegate() title, void delegate() contents){ // Node ////////////////////////////
    HitTestManager.HitInfo hit;
    Column({
      border.width = 1; //todo: ossze kene tudni kombinalni a szomszedos node-ok bordereit.
      border.color = lerp(style.bkColor, style.fontColor, state ? .1 : 0);

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
      Spacer(1.5*fh);
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

struct CAPTION{ string text; }
struct UNIT{ string text; }
struct RANGE{ float low, high; bool valid()const{ return !low.isNaN && !high.isNaN; } }
struct INDENT{ }
struct HIDDEN{ }

struct FieldProps{
  string fullName, name, caption, unit;
  RANGE range;
  bool indent;

  string getCaption() const{
    auto s = caption!="" ? caption : camelToCaption(name);
    if(s.length && indent) s = "      "~s;
    return s;
  }

  auto hash() const{ return fullName.xxh; }
}

FieldProps getFieldProps(T, string fieldName)(string parentFullName){
  alias f = __traits(getMember, T, fieldName);
  return FieldProps(
    [parentFullName, fieldName].filter!(not!empty).join('.'),
    fieldName,
    getUDA!(f, CAPTION).text,
    getUDA!(f, UNIT   ).text,
    getUDA!(f, RANGE),
    hasUDA!(f, INDENT)
  );
}

void stdUI(T)(ref T data, in FieldProps thisFieldProps=FieldProps.init){ with(im){
  //print("generating UI for ", T.stringof, thisName);


  /* */ static if(isFloatingPoint!T     ){
    Row({
      Text(thisFieldProps.getCaption, "\t");
      auto s = format("%.2f", data);
      Edit(s, id(thisFieldProps.hash), { width = fh*3; });
      try{ data = s.to!T; }catch(Throwable){}
      Text(thisFieldProps.unit, "\t");
      if(thisFieldProps.range.valid) //todo: im.range() conflict
        Slider(data, range(thisFieldProps.range.low, thisFieldProps.range.high), id(thisFieldProps.hash+1), "width=180"); //todo: rightclick
      //todo: Bigger slider height when (theme!="tool")
    });
  }else static if(isIntegral!T          ){
    Row({
      Text(thisFieldProps.getCaption, "\t");
      auto s = data.text;
      Edit(s, id(thisFieldProps.hash), { width = fh*3; });
      try{ data = s.to!T; }catch(Throwable){}
      Text(thisFieldProps.unit, "\t");
      if(thisFieldProps.range.valid) //todo: im.range() conflict
        Slider(data, range(thisFieldProps.range.low, thisFieldProps.range.high), id(thisFieldProps.hash+1), "width=180"); //todo: rightclick
    });
  }else static if(isSomeString!T        ){
    Row({
      Text(thisFieldProps.getCaption, "\t");
      Edit(data, id(thisFieldProps.hash), { width = fh*10; });
    });
  }else static if(is(T == bool)         ){
    Row({
      Text(thisFieldProps.getCaption, "\t");
      ChkBox(data, "", id(thisFieldProps.hash));
      Text("\t");
    });
  }else static if(isAggregateType!T     ){ // Struct, Class

    enum bool notHidden(string fieldName) = !hasUDA!(__traits(getMember, T, fieldName), HIDDEN);
    import std.meta;
    enum visibleFields = Filter!(notHidden, AllFieldNames!T);

    Column({
      const caption = thisFieldProps.getCaption;
      if(caption!=""){
        Row({ Text(tsBold, caption); });

        border = "1 normal black";
        padding = "2";
        margin = "2";
      }
      //recursive call for each field
      foreach (fieldName; visibleFields){{
          auto fp = getFieldProps!(T, fieldName)(thisFieldProps.fullName);

          //stdUI(__traits(getMember, data, fieldName), fp);
          stdUI(mixin("data.", fieldName), fp);
      }}

    });
  }else{
    static assert(0 ,"Unhandle type: "~T.stringof);
  }
}}


//Test ///////////////////////////////////

void uiCellDocumentation(){ with(im){
  Document(`CELL Documentation`, {
  //  Toc;

    void LI(string capt, string text){ ListItem(bold(capt) ~ "\t\t\t\t" ~ text); }

    Chapter(`Markup text format`, {
      Text(`The preferred text format is UTF8.
Every line can contain a definition, so the new-line character marks the end of the definition.
Empty lines are either ignored or used to break the continuity of lists/tables.
There are exceptions for this, but it will be specified there.`);

      Chapter(`Embedding meta information into the text`, {
        Text(`The fundamental building block is the "cell". The simplest cell is this single line of text, like this one for example.
For more complex cells, meta information (tags) can be inserted along with the text:`);

        Code(`text` ~ tag(`char 0xB6`) ~ `meta commands` ~ tag(`char 0xA7`) ~ `more text`);
        Text(`The opening symbol is the "`~tag("char 0xB6")~`" "Pilcrow" character, Alt+20.`);
        Text(`The closing symbol is the "`~tag("char 0xA7")~`" "Section sign" character, Alt+21.`);
        Text(`Lines starting with special tags can define the meaning of the whole line. These starter tags can build special types of cells or they can create more than one cells too.`);
        Text(`The above text representation can be issued from code by using the tag() function:`);
        Code(`"text" ~ tag("meta connamds") ~ "more text"`);
      });
      Chapter(`Formatting the text`, {
        Chapter(`Setting text format manually`, {
          Text(`The format to modify the current TextStyle is:`);
          Code(tag(`char 0xB6`) ~ `style param1=value1 param2=value2 ...` ~ tag(`char 0xA7`));
        });
        Text(`The available parameters are:`);
        [`font="Segoe Script"|Selects a different @fontFace`,
         `fontHeight=24|Sets the font's height to @24 pixels`,
         `bold=1|Turn on @bold`,
         `italic=1|Turn on @italic`,
         `underline=1|Turn on @underline`,
         `strikeout=1|Turn on @strikeout`,
         `fontColor=0xFF0080|Sets the @color of the font`,
         `bkColor=lime|Sets the @color of the font background`].each!((s){
           s.isWild("*=*|*");
           ListItem( format("%s=%s\t\t\t\t%s", bold(wild[0]), wild[1], wild[2].replace("@", tag("style "~wild[0]~"="~wild[1]))) );
        }); //todo: minTabSize a \t\t\t\t halmozas helyett. Ehhez kell egy theme is valoszinuleg.
        Text("Note: Valid color formats are the following: 0xFF00FF, rgb(255, 0, 255), fuchsia");
        Chapter(`Predefined text formats`, {
          Text(`There are some predefined textstyles. They can be selected simply by their name (or their short name):`);
          Code(tag(`char 0xB6`) ~ `name` ~ tag(`char 0xA7`));

          auto styles = ["normal, n", "larger", "smaller", "half", "comment", "error", "bold, b", "bold2, b2", "quote, q", "code, c", "link", "title", "chapter", "chapter2", "chapter3"];
          foreach(s; styles)
            ListItem(s ~ "\t\t\t\t" ~ tag(s.split(",")[0])~"Demo");
        });
      });
      Chapter(`Properties`, {
        Chapter(`Cell properties`, {
          Text(`To modify the properties of the current cell (normally a Row), use the 'prop' tag:`);
          Code(tag(`char 0xB6`) ~ `prop name1=value1 name2=value2 ...` ~ tag(`char 0xA7`));
        });
        Chapter(`Container properties`, {
          Text(`These are the properties for every kind of cells.`);
          Spacer(0.5*fh);
          LI("innerWidth, innerHeight", "Sets the size of the cell inside its pading.");
          LI("outerWidth, outerHeight", "Sets the total size of the cell including its margin.");
          LI("width, height", "Shorthand for "~bold("outerWidth")~" and "~bold("outerHeight")~".");
          Spacer(0.5*fh);
          Text("Note: By default sizes are defined in pixels. If you want to use fontHeight units, put an \"x\" after the number. Eg.: \"1.5x\".");
          Spacer(0.5*fh);
          LI("margin.all", "Defines the margin size in all 4 directions around the cell.");
          LI("margin.horz", "Sets margin on left and right.");
          LI("margin.vert", "Sets margin on top and bottom.");
          LI("margin.left/right/top/bottom", "Sets margin on specific directions.");
          LI("margin", "This is a shorthand for the above, the number of elements (separated by spaces) defines which sides to set.");
          //todo: this should be a table
          Spacer(0.5*fh);
          Text("The following examples are demonstrating the usage of the the shortHand format:
1\tall=1
1 2\tvert=1, horz=2
1 2 3\ttop=1, horz=2, bottom=3
1 2 3 4\ttop=1, right=2, bottom=3, left=4");
          Spacer(0.5*fh);
          Text("Padding:");
          LI("padding", "Defines the inner area of the cell. Can be used in the exact same way as "~bold("margin")~".");
          Spacer(0.5*fh);
          Text("The border in is between the margin and the padding:");
          LI("border.width", "Sets the width(thickness) of the border");
          LI("border.color", "Sets color.");
          auto borders = ["none","normal","dot","dash","dashDot","dash2","dashDot2","double"].map!(s => tag("row \""~s~"\" border="~s)).join("  ");
          LI("border.style", "Can be the following: "~borders); //todo: bug: double border is single
          LI("border", "ShortHand, that sets all the border parameters. Example: \"0.5x dot red\". Width and color is optional.");
          Spacer(0.5*fh);
          Text("Other container properties:");
          Spacer(0.5*fh);
          LI("flex", "This cell is flexible. The remaining size of the parent cell will be shared across flexible cells. Each flex cell will get a size proportional to its flex value.");
          LI("bkColor", "Background color. Later this will be a background object with more properties.");
        });
      });
      Chapter(`Special tags in Rows`, {
        LI("row", "Inserts a row which is acts like a cell. First parameter is the nontent of that row, remaining are properties.");
        auto rowExample = `row "Test row" border="2 dash SkyBlue" width=160 height=2x`;
        Code(rowExample);
        Text(tag(rowExample));

        LI("img", "Loads and displays an image. The first parameter can be a fileName.");
        auto imgExample = `img "c:\dl\hehe.png"`;
        Code(imgExample);
        Text(tag(imgExample));
        Text(`Note: Use the `~bold(`font:\`)~` drive prefix to load one ore more characters of a specific font:`);

        auto imgFontExample = "img \"font:\\Segoe UI Emoji\\32?\U0001F355\U0001F35F\U0001f964\"";
        Code(imgFontExample);
        Text(tag(imgFontExample));
        Text("Note: You can attach some parameters to the font render like adding a directory to the filePath.");
        LI("<integer>", "Sets the fontHeight. 32 is used in the above example."); //todo: this should be a table
        LI("ct", "ClearType");
        LI("x3", "Stretch the image 3x wider. Can be usebul in a cleartype shader.");
        LI("x2", "...2x wider.");

        Spacer(1*fh);
        LI("char", "Access a character by (dec or hex) code.");
        auto charExample = "char 0x61";
        Code(charExample);
        Text(tag(charExample));

        Spacer(1*fh);
        LI("symbol", "Inserts a symbol from \"Segoe MDL2 Assets\" font. Parameter can be an index or a name.");
        auto symbolExample1 = "symbol 0xE80F";
        auto symbolExample2 = "symbol Wifi";
        Code(symbolExample1~"         "~symbolExample2);
        Text(tag(symbolExample1)~tag(symbolExample2));

        Spacer(1*fh);
        LI("space", "Inserts whitespace. First param specifies the width.");
        auto spaceExample = "space 5x border=normal bkColor=yellow";
        Code(spaceExample);
        Text("some text"~tag(spaceExample)~"more text");

      });
    });
  });

}}

void uiContainerAlignTest(){ with(im){
  Column({
    enum lorem = "In\r\npublishing and graphic design, lorem ipsum is a placeholder text commonly used to demonstrate(...)";

    void TestFlag(T)(T[] items, void delegate(T) fun, string lorem){
      Row({ foreach(i; items){ Row({
        flex = 1;  //no autoWidth, so it will enable wrap
        margin = "1";
        border = "1 single black";
        padding = "1";
        fun(i);
        Text(bold(T.stringof~"."~i.text), " ", "\U0001F4A1", lorem);
        //flags.canSelectCells = true;
      }); }
      Spacer(.5*fh); //todo: ez is bugos
    }); }

    Text("HAlign Test  width=explicit(flex=1)  height=auto  wrap=on");
    TestFlag([EnumMembers!(het.uibase.HAlign)], (het.uibase.HAlign i){ flags.hAlign=i; }, lorem); //todo: ambigious names: draiwng.HAlign

    Text("VAlign Test  width=explicit(flex=1)  height=5 lines  wrap=on");
    TestFlag([EnumMembers!(het.uibase.VAlign)], (het.uibase.VAlign i){ height = fh*5; flags.vAlign=i; }, lorem[0..$/4]); //todo: ambigious names: draiwng.HAlign

    //todo: ez el van baszva
    Text("YAlign Test  width=explicit(flex=1)  height=5 lines  wrap=on");
    TestFlag([EnumMembers!YAlign], (YAlign i){ flags.yAlign=i; }, "     M_"~tag("style fontHeight=40")~"_M");
  });

}}
