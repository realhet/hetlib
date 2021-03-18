module het.draw2d;

import het.opengl, het.fonts, het.megatexturing;

public import het.geometry, het.color;
public import het.megatexturing : textures;

import std.bitmanip;

__gshared bool logDrawing = 0;


enum InvBoldOffset = 40; //relative to height: texel offset is 1/N
enum BoldOffset = 1.0f/InvBoldOffset;

GLTexture debugTexture;

//todo: A shader errorokat visszakovetni valahogy: Annyit tudunk rola, hogy a neve az, hogy pl. DrawingShader, ezt a nevet lehetne magabol a shader szovegebol generalni. A GCN compilerbol kell lopkodni, ott mar megy.

/*
enum LineStyle { normal, dot, dash, dashDot, dash2, dashDot2 }
enum ArrowStyle { none, arrow, doubleArrow, normalLeft, normalRight, vector }
enum PointStyle { dot, square, triangle, cross, plus }
enum HTextAlign { left, right, center, justify }
enum VTextAlign { top, bottom, center }
*/


/* GPU Data format

todo:
  Shadow/Outline for everything


Data record:


       0    1    2    3   4     5       6     7       8   9   10                   8*4 = 32bytes/primitive
       Ax   Ay   Bx   By  Cx    Cy      Col   Typ     Dx  Dy  col2
Point: X    Y             Siz           Col   1    //-Siz = screen_relative
Point2:X1   Y1   X2  Y2   Siz1  Siz2    Col   2    //-Siz = screen_relative
Line : X1   Y1   X1, Y1,  Width L.Style Col   3..3+63   //arrowStyle
Rect : X1   Y1   X2, Y2,                Col   67   //Id: symbol id in texture  sc:symScale(1 = (xs, ys))

Tri  : X0   Y0   X1, Y1, X2     Y2      col,  68

Glyph: x0,  y0,  x1, y1,  tx0, ty0      col,  256     tx1, ty1, col2
                          tx0:fontFlags

Bez2 : Ax   Ay   Bx  By   Cx    Cy      Col   69      Width - -


////////////Text:  x0,  y0,  sf, c4,  c4,  c4,      c4 ,  69,     c4,  c4,  c4   //sf = size+flags

*/


//Todo: Appendert kell hasznalni!

//Standard LineStyles
enum LineStyle:ubyte {
  normal        =  0,
  dot           =  2,
  dash          = 19,
  dashDot       = 29,
  dash2         = 35,
  dashDot2      = 44
}

//these are also used in ui.d
enum HAlign { left, center, right, justify }  //when the container width is fixed
enum VAlign { top, center, bottom, justify }  //when the container height is fixed
enum YAlign { top, center, bottom, baseline, stretch } //this aligns the y position of each cell in a line. baseline is 0.7ish



struct RectAlign{align(1): import std.bitmanip;
  mixin(bitfields!(
    HAlign, "hAlign"    , 2,
    VAlign, "vAlign"    , 2,
    bool  , "canShrink" , 1,
    bool  , "canEnlarge", 1,
    bool  , "keepAspect", 1,
    bool  , "_dummy0"   , 1
  ));

  this(HAlign hAlign, VAlign vAlign, bool canShrink, bool canEnlarge, bool keepAspect){ //todo: dumb stupid copy paste constructor
    this.hAlign = hAlign;
    this.vAlign = vAlign;
    this.canShrink = canShrink;
    this.canEnlarge = canEnlarge;
    this.keepAspect = keepAspect;
  }

  bounds2 apply(in bounds2 rCanvas, in bounds2 rImage){

    void alignOne(ref float dst1, ref float dst2,ref float src1, ref float src2, bool shrink, bool enlarge, int align_){
      if(shrink && enlarge) return;
      if(!shrink && (dst2-dst1<src2-src1)){ //a bmp nagyobb es nincs kicsinyites
        final switch(align_){
          case 0: src2 = src1+dst2-dst1;                                        break;
          case 1, 3: src1 = ((src1+src2)-(dst2-dst1))*.5; src2 = src1+dst2-dst1;   break;
          case 2: src1 = src2-(dst2-dst1);                                      break;
        }
      }
      if(!enlarge && (dst2-dst1>src2-src1)){ //a bmp kisebb es nincs nagyitas
        final switch(align_){
          case 0: dst2 = dst1+src2-src1;                                        break;
          case 1, 3: dst1 = ((dst1+dst2)-(src2-src1))*.5; dst2 = dst1+src2-src1;   break;
          case 2: dst1 = dst2-(src2-src1);                                      break;
        }
      }
    }

    bounds2 rdst = rCanvas, rdst2 = rdst, rsrc = rImage;
    alignOne(rdst2.left, rdst2.right, rsrc.left, rsrc.right, canShrink, canEnlarge, cast(int)hAlign);
    alignOne(rdst2.top, rdst2.bottom, rsrc.top, rsrc.bottom, canShrink, canEnlarge, cast(int)vAlign);
    if(keepAspect){
      float a1 = rdst2.right-rdst2.left  , b1 = rdst2.bottom-rdst2.top  ,
            a2 = rImage.right-rImage.left, b2 = rImage.bottom-rImage.top,
            r1 = a1/max(1, b1)           , r2 = a2/max(1, b2)           ;
      if(r1<r2){
        b1 = a1/max(0.000001f,r2);
        final switch(cast(int)vAlign){
          case 0:rdst2.top = rdst.top;                          break;
          case 1, 3:rdst2.top = (rdst.top+rdst.bottom-b1)*.5;   break;
          case 2:rdst2.top = rdst.bottom-b1;                    break;
        }
        rdst2.bottom = rdst2.top+b1;
        rsrc.top = 0; rsrc.bottom = rImage.bottom-rImage.top;
      }else if(r1>r2){
        a1 = b1*r2;
        final switch(cast(int)hAlign){
          case 0:rdst2.left = rdst.left;                        break;
          case 1, 3:rdst2.left = (rdst.left+rdst.right-a1)*.5;  break;
          case 2:rdst2.left = rdst.right-a1;                    break;
        }
        rdst2.right = rdst2.left+a1;
        rsrc.left = 0; rsrc.right = rImage.right-rImage.left;
      }
    }

    return rdst2;
  }

}

//Standard arrows
private int encodeArrowStyle(int headArrow, int tailArrow, int centerNormal){
  return headArrow<<0 | tailArrow<<2 | centerNormal<<4;
}

enum ArrowStyle:ubyte {
  none                  = 0,
  arrow                 = encodeArrowStyle(1,0,0),
  doubleArrow           = encodeArrowStyle(1,1,0),
  normalLeft            = encodeArrowStyle(0,0,1),
  normalRight           = encodeArrowStyle(0,0,2),
  arrowNormalLeft       = encodeArrowStyle(1,0,1),
  arrowNormalRight      = encodeArrowStyle(1,0,2),
  vector                = encodeArrowStyle(1,2,0),
  segment               = encodeArrowStyle(2,2,0)
}

class Drawing {

  auto shortName() const { return "Drawing("~(cast(void*)this).text~")"; }

  private static Shader shader;

  private VBO[] vboList;
  private void destroyVboList(){
    foreach(ref v; vboList) destroy(v);
    vboList.clear;
    totalDrawObj = 0;
  }

  uint drawCnt, //GLWindow will use it for automatic display
       totalDrawObj; //total DrawingObjects on GPU
  const bool isClone;

  this(){
    isClone = false;
  }

  this(Drawing src){ //make a clone
    if(src.isClone) CRIT("It is invalid to clone a clone");
    if(logDrawing) LOG(shortName, "cloning", cast(void*) src);
    isClone = true;
    actState = src.actState;
    clipBounds = src.clipBounds;
  }

  Drawing clone(){
    return new Drawing(this);
  }

  private Drawing[] subDrawings; //clones to draw at the very end

  void subDraw(Drawing src){ //todo: revisit this subdrawing thing
    if(!src.isClone) CRIT("src must be a clone (at least for now.)");

    //note: potential problem, the subDrawing has no location. It is useless for dynamic changes.

    if(logDrawing) LOG(shortName, "queued subDrawing", cast(void*) src, src.totalDrawObj);
    subDrawings ~= src;

    bounds_ |= src.bounds_;
  }

  void copyFrom(Drawing src){ /// Appends the contents of another drawing into itself. Used in UI to draw overlays on top of cells.
    if(src is null) return;

    foreach(obj; src.exportDrawingObjs){
      obj.applyTransform(&inputTransform);
      append(obj); //todo: this is a terrible slow copy
    }
  }

  ~this(){
    //destroyVboList; //not needed: gc will release it anyways
  }

  string stats(){ return format!"(total:%d pending:%d vbo:[%s])"(totalDrawObj, buffers.map!"a.length".sum, vboList.map!(a => a.handle).array.text); }

////////////////////////////////////////////////////////////////////////////////
//  State variables                                                           //
////////////////////////////////////////////////////////////////////////////////

  struct DrawState {
    // saveable area
    RGB drawColor = clWhite;    //    RGB fillColor = clBlack;
    ubyte alpha = 0xFF;
    LineStyle lineStyle;
    ArrowStyle arrowStyle;
    ubyte fontFlags;

    ubyte _dummy1;
    // end of saveable area
    float  pointSize = -1,
           lineWidth = -1;
//    auto arrowSize = vec2(8, 2.5);   //this is fixed in the shader

    float fontHeight = 18;
    float fontWeight = 1.0;

    static foreach(i, s; ["MonoSpace", "Italic", "Underline", "StrikeOut"]){
      mixin("@property bool font*() const { return (fontFlags>>#)&1; }  @property void font*(bool b){ fontFlags = cast(ubyte) (fontFlags & ~(1<<#) | (cast(int)b << #)); }".replace('*', s).replace('#', i.text));
    }

    private enum fontWeightBold = 1.4f;
    @property bool fontBold()           { return fontWeight> (fontWeightBold+1)*.5f; }
    @property void fontBold(bool b)     { fontWeight = b ? fontWeightBold : 1; }

    auto drawScale = vec2(1, 1);
    auto drawOrigin = vec2(0, 0);


    /// used in advanced drawing functions such as line2()
    long quickSave(){
      static assert(drawColor.offsetof + 8 == _dummy1.offsetof + _dummy1.sizeof);
      return *(cast(long*) &this);
    }

    /// ditto
    void quickRestore(long data){
      *(cast(long*) &this) = data;
    }
  }

  private DrawState actState;
  private DrawState[] stateStack;

  //todo: Examine push VS saveState, seems redundant. UI uses only translate() and pop()
  private vec2[2][] stack; //matrix stack


  @property float alpha()       { return actState.alpha*(1.0f/255); }
  @property void alpha(float a) { actState.alpha = cast(ubyte) iround(a.clamp(0, 1)*255); }

  @property RGB color()        { return actState.drawColor; }
  @property void color(RGB c)  { actState.drawColor = c; }

//  @property RGB fillColor()            { return actState.fillColor; }
//  @property void fillColor(RGB c)      { actState.fillColor = c; }

  ref float pointSize()         { return actState.pointSize; }
  ref float lineWidth()         { return actState.lineWidth; }
  ref lineStyle()           { return actState.lineStyle; }

  ref arrowStyle() { return actState.arrowStyle; }

  ref scaleFactor() { return actState.drawScale; }
  ref origin()      { return actState.drawOrigin; }

  ref fontHeight      () { return actState.fontHeight           ; }
  ref fontWeight      () { return actState.fontWeight           ; }
  @property bool fontMonoSpace   () const { return actState.fontMonoSpace        ; }
  @property bool fontItalic      () const { return actState.fontItalic           ; }
  @property bool fontUnderline   () const { return actState.fontUnderline        ; }
  @property bool fontStrikeOut   () const { return actState.fontStrikeOut        ; }
  @property      fontMonoSpace   (bool b) { return actState.fontMonoSpace = b    ; }
  @property      fontItalic      (bool b) { return actState.fontItalic    = b    ; }
  @property      fontUnderline   (bool b) { return actState.fontUnderline = b    ; }
  @property      fontStrikeOut   (bool b) { return actState.fontStrikeOut = b    ; }

  @property bool fontBold(){ return actState.fontBold; }
  @property fontBold(bool b){ actState.fontBold = b; }

  //save/restore DrawState
  void saveState() { stateStack ~= actState; }
  void restoreState() {
    enforce(stateStack.length, "Canvas.restoreState(): State stack is empty");
    actState = stateStack.back;
    stateStack.popBack;
  }
  alias pushState = saveState;
  alias popState = restoreState;

  //access combined colors
  private uint realDrawColor()  { return actState.drawColor.raw | actState.alpha<<24; }
//  private uint realFillColor()  { return actState.fillColor.raw | actState.alpha<<24; }

  void push() {
    enforce(stack.length<1024, "Drawing.glDraw() matrix stack is too big.  It has %d items.".format(stack.length));
    stack ~= [origin, scaleFactor];
  }

  void pop() {
    enforce(!stack.empty, "Drawing.pop() stack is empty");
    auto a = stack.popLast;
    origin = a[0];
    scaleFactor = a[1];
  }

  void translate(float dx, float dy){
    push;                //seems like origin is in scale units, not in screen units.
    origin.x = origin.x + dx;//*scaleFactor.x;
    origin.y = origin.y + dy;//*scaleFactor.y;
  }
  void translate(in vec2 d){ translate(d.x, d.y); }
  void translate(in ivec2 d){ translate(d.x, d.y); }

  void scale(float s){ //todo: ezt meg kell csinalni matrixosra.
    push;
    origin *= scaleFactor;
    scaleFactor *= s;
    origin /= scaleFactor;
  }

////////////////////////////////////////////////////////////////////////////////
//  Draw primitives                                                           //
////////////////////////////////////////////////////////////////////////////////

  struct DrawingObj {
    float aType;                //4
    vec2 aA, aB, aC;            //24
    uint aColor;                //4

    //drawGlyph only
    vec2 aD;                    //8
    uint aColor2;               //4

    vec2 aClipMin, aClipMax;    //16  clipping rect. Terribly unoptimal

    void expandBounds(ref bounds2 b) const{
      auto t = aType.iround;
      void x(in vec2 v){ b |= v; }

      if(t==1) x(aA); //Point
      else if(t.among(68, 69)){ x(aA); x(aB); x(aC); } //Tri, Bez2
      else if(t.inRange(2, 67) || t.inRange(256, 256+0xFFFF)) { x(aA); x(aB); } //Point2, Line, rect, glyph
      else raise("aType %s not impl".format(aType));
    }

    void applyTransform(vec2 delegate(in vec2) tr){
      auto t = aType.iround;

      void x(ref vec2 v){ v = tr(v); }

      if(t==1) x(aA); //Point
      else if(t.among(68, 69)){ x(aA); x(aB); x(aC); } //Tri
      else if(t.inRange(2, 67) || t.inRange(256, 256+0xFFFF)) { x(aA); x(aB); } //Point2, Line, rect, glyph
    }
  };
  private const bufferMax = (2<<20)/DrawingObj.sizeof;
  private DrawingObj[][] buffers;

  const bool empty() { return buffers.empty && vboList.empty; }

  private void append(DrawingObj o){
    if(buffers.empty || buffers[$-1].length>=bufferMax){
      DrawingObj[] act;
      act.reserve(bufferMax);
      buffers ~= act;
    }
    o.aClipMin = clipBounds.low;
    o.aClipMax = clipBounds.high;
    buffers[$-1] ~= o;
    o.expandBounds(bounds_);
  }

  private auto exportDrawingObjs(){
    return buffers.join;
  }

//  private int dirty = -1; //must set to -1 data[] is changed. bit0 = VBO, bit1 = bounds
  private void markDirty() { /*dirty = -1;*/ }

  private bounds2 bounds_;
  @property bounds2 bounds()const { return bounds_; }

  vec2 inputTransformRel(in vec2 p) { return p*actState.drawScale; } //for relative movements

  vec2 inputTransform(in vec2 p) { return (p+actState.drawOrigin)*actState.drawScale; }
  bounds2 inputTransform(in bounds2 b) { return bounds2(inputTransform(b.low), inputTransform(b.high)); }

  vec2 inverseInputTransform(in vec2 v) { return v/actState.drawScale-actState.drawOrigin; } //todo: slow divide
  bounds2 inverseInputTransform(in bounds2 b) { return bounds2(inverseInputTransform(b.low), inverseInputTransform(b.high)); }

  private enum clipBounds_init = bounds2(-1e30, -1e30, 1e30, 1e30);
  bounds2 clipBounds = clipBounds_init;
  private bounds2[] clipBoundsStack;

  void pushClipBounds(bounds2 bnd){ //bnd is in local coords
    clipBoundsStack ~= clipBounds;
    clipBounds = inputTransform(bnd);
  }

  void popClipBounds(){
    if(clipBoundsStack.length){
      clipBounds = clipBoundsStack[$-1];
      clipBoundsStack = clipBoundsStack[0..$-1];
    }
  }

  void clear(){
    if(logDrawing) LOG(shortName, "clearing", stats);
    destroyVboList;
    destroy(buffers);
    bounds_ = bounds2.init;
    markDirty;

    clipBounds = clipBounds_init;
    clipBoundsStack = [];

    actState = DrawState.init;
    stateStack = [];
    stack.clear;

    subDrawings = [];
  }

  void clear(RGB background){
    clear;
    gl.clearColor(background);  gl.clear(GL_COLOR_BUFFER_BIT);
  }

// Points //////////////////////////////////////////////////////////////////////

  void point(in vec2 p) {
    markDirty;
    auto c = realDrawColor, s = pointSize;
/*    if(data_.length) with(data[$-1]) if(aType==1 && aColor==c) {//extend the last Point1 to Point2
      aType = 2;
      aB = inputTransform(p);
      aC.y = s;
      return;
    }*/ //todo: point2 is not working with appender. should use vec2[]

    //Create a new Point1
    append(DrawingObj(1, inputTransform(p), vec2(0), vec2(s, 0), c));
  }

  void point(float x, float y) { point(vec2(x, y)); }

  void point(in ivec2 p) { point(p.x, p.y); }

  void point(in vec2[] p) {
    if(p.length==0) return;
    markDirty;
    auto c = realDrawColor, s = pointSize;
    int idx = 0;
    if(p.length&1) { //first odd element. Try to snap to the prev point
      point(inputTransform(p[0]));
      idx++;
    }
    //from now process 2 points at a time
    while(idx<p.length) {
      append(DrawingObj(2, inputTransform(p[idx]), inputTransform(p[idx+1]), vec2(s, s), c));
      idx += 2;
    }
  }

// Lines ///////////////////////////////////////////////////////////////////////

  private vec2 lineCursor; // untransformed for fastness, but can't survive a transformation

  void lineTo(in vec2 p_) { //todo: const struct->in struct
    vec2 p = inputTransform(p_);
    markDirty;
    auto c = realDrawColor, w = lineWidth;
    append(DrawingObj(3+actState.arrowStyle, inputTransform(lineCursor), p, vec2(w, lineStyle), c));
    lineCursor = p_;
  }
  void lineTo(in vec2 p, bool isMove)                    { if(isMove) moveTo(p); else lineTo(p); }

  void lineTo(in ivec2 p)                                 { lineTo(p); }
  void lineTo(in ivec2 p, bool isMove)                    { lineTo(p, isMove); }

  void moveTo(in vec2 p)                                 { lineCursor = p; }
  void moveTo(in ivec2 p)                                 { moveTo(p); }

  void lineRel(in vec2 p)                                { lineTo(lineCursor+p); }  //kinda slow, but can change transformations between relative movements
  void moveRel(in vec2 p)                                { moveTo(lineCursor+p); }
  void line(in vec2 p0, in vec2 p1)                       { lineCursor = p0; lineTo(p1); }

  void line(in ivec2 p0, in ivec2 p1)                       { line(p0, p1); }
  void line(in seg2 s)                                 { line(s.p[0], s.p[1]); }
  void line(in seg2[] a)                               { foreach(const s; a) line(s); }

  void lineTo(float x, float y)                         { lineTo(vec2(x, y)); }
  void lineTo(float x, float y, bool isMove)            { lineTo(vec2(x, y), isMove); }
  void moveTo(float x, float y)                         { moveTo(vec2(x, y)); }
  void lineRel(float x, float y)                        { lineRel(vec2(x, y)); }
  void moveRel(float x, float y)                        { moveRel(vec2(x, y)); }
  void line(float x0, float y0, float x1, float y1)     { line(vec2(x0, y0), vec2(x1, y1)); }

  void line(T)(in T[] points)                           { if(points.length>1){ moveto(points[0]); foreach(const p; points[1..$]) lineto(p); } }
  void lineLoop(T)(in T[] points)                       { if(points.length>1){ line(points); lineto(points[0]); } }

  void hLine(in vec2 p0, float x1)                       { line(p0.x, p0.y, x1, p0.y); }
  void hLine(float x0, float y, float x1)               { line(x0, y, x1, y); }
  void vLine(in vec2 p0, float y1)                       { line(p0.x, p0.y, p0.x, y1); }
  void vLine(float x, float y0, float y1)               { line(x, y0, x, y1); }

/*  void line2(T...)(in args T){
    foreach(a; args){
      alias A = unqual!(typeof(a));
      static if(is(A == vec2)) lineTo(a);
      static if(is(A == ivec2)) lineTo(a);
      static if(is(A == vec2[])) lineTo(a);
      static if(is(A == ivec2[])) lineTo(a);
      static if(is(A == RGB )){ color = a;        alpha = 1;          }
      static if(is(A == RGBA)){ color = a.to!RGB; alpha = a.a/255.0f; }
      static if(isIntegral!A || isFloatingPoint!A) lineWidth = a;
      //todo: static if(is(A == LineStyle)) lineStyle = a;
    }
  }*/

  void line2(A...)(in A args){

    // backup current drawState (only a subset of it)
    auto backup = actState.quickSave;  scope(exit) actState.quickRestore(backup);
    // todo: only do this when tere are colors, or styles in the args

    bool first = true;
    float coord; //it remembers the first coordinate

    static foreach(a; args){{
      alias T = Unqual!(typeof(a));
            static if(is(T == RGB       )){ color = a;
      }else static if(is(T == RGBA      )){ alpha = a.a/255.0f;
      }else static if(is(T == LineStyle )){ lineStyle = a;
      }else static if(is(T == ArrowStyle)){ arrowStyle = a;
      }else static if(is(T == vec2      )){ lineTo(a, first); first = false;
      }else static if(is(T == ivec2     )){ lineTo(a, first); first = false;
      }else static if(is(T == seg2      )){ lineTo(a[0], first); first = false; lineTo(a[1]);
      }else static if(is(T == bounds2   )){ lineTo(a.topLeft, first); lineTo(a.topRight); lineTo(a.bottomRight), lineTo(a.bottomLeft), lineTo(a.topLeft);
      }else static if(is(T == ibounds2  )){ lineTo(a.topLeft, first); lineTo(a.topRight); lineTo(a.bottomRight), lineTo(a.bottomLeft), lineTo(a.topLeft);
      }else static if(isNumeric!T        ){ if(isnan(coord)) coord = a; else { lineTo(coord, a, first); first = false; coord = float.init; }
      }else static assert("invalid type: "~T.stringof);
    }}
  }

  void bezier2(in vec2 A, in vec2 B, in vec2 C) {
    markDirty;
    auto c = realDrawColor, w = lineWidth;
    append(DrawingObj(69, inputTransform(A), inputTransform(B), inputTransform(C), c,vec2(w, lineStyle)));
  }

  protected static auto genRgbGraph(string fv)(){
    return q{
      auto oldColor = color;
      color = clWhite; @(x0, y0, data.map!"a.l".array, xScale, yScale);
      color = clRed  ; @(x0, y0, data.map!"a.r".array, xScale, yScale);
      color = clLime ; @(x0, y0, data.map!"a.g".array, xScale, yScale);
      color = clBlue ; @(x0, y0, data.map!"a.b".array, xScale, yScale);
      static if(is(T==RGBA8)){ color = clFuchsia; @(x0, y0, data.map!"a.a".array, xScale, yScale); }
      color = oldColor;
    }.replace("@", fv);
  }

  void vGraph(T)(float x0, float y0, in T[] data, float xScale=1, float yScale=1){
    if(data.empty) return;
    static if(is(T==RGB8)||is(T==RGBA8)){
      mixin(genRgbGraph!"vGraph");
    }else static if(is(T==vec2) || is(T==ivec2)){
      foreach(i, const v; data) lineTo(x0+v.y*xScale, y0+v.x*yScale, !i);
    }else{
      moveTo(x0+data[0]*xScale, y0);
      foreach(d; data[1..$]) {
        y0 += yScale;
        lineTo(x0+d*xScale, y0);
      }
    }
  }

  void hGraph(T)(float x0, float y0, in T[] data, float xScale=1, float yScale=1){
    if(data.empty) return;
    static if(is(T==RGB8)||is(T==RGBA8)){
      mixin(genRgbGraph!"hGraph");
    }else static if(is(T==vec2) || is(T==ivec2)){
      foreach(i, const v; data) lineTo(x0+v.x*xScale, y0+v.y*yScale, !i);
    }else{
      moveTo(x0, y0+data[0]*yScale);
      foreach(d; data[1..$]) {
        x0 += xScale;
        lineTo(x0, y0+d*yScale);
      }
    }
  }


  void vGraph(T)(in vec2 v0, in T[] data, float xScale=1, float yScale=1){ vGraph(v0.x, v0.y, data, xScale, yScale); }
  void hGraph(T)(in vec2 v0, in T[] data, float xScale=1, float yScale=1){ hGraph(v0.x, v0.y, data, xScale, yScale); }

  void vGraph(T)(in ivec2 v0, in T[] data, float xScale=1, float yScale=1){ vGraph(v0.x, v0.y, data, xScale, yScale); }
  void hGraph(T)(in ivec2 v0, in T[] data, float xScale=1, float yScale=1){ hGraph(v0.x, v0.y, data, xScale, yScale); }

  alias vline = vLine, hline = hLine, moveto = moveTo, lineto = lineTo;

  void drawRect(float x0, float y0, float x1, float y1) { hLine(x0, y0, x1); hLine(x0, y1, x1); vLine(x0, y0, y1); vLine(x1, y0, y1); }
  void drawRect(in vec2 a, in vec2 b)               { drawRect(a.x, a.y, b.x, b.y); }
  void drawRect(in bounds2 b)                       { drawRect(b.low, b.high); }
  void drawRect(in ibounds2 b)                       { drawRect(bounds2(b)); }

  void drawX(float x0, float y0, float x1, float y1)    { line(x0, y0, x1, y1); line(x0, y1, x1, y0); }
  void drawX(in vec2 a, in vec2 b)                  { drawX(a.x, a.y, b.x, b.y); }
  void drawX(in bounds2 b)                          { drawX(b.low, b.high); }
  void drawX(in ibounds2 b)                          { drawX(bounds2(b)); }

  void fillRect(float x0, float y0, float x1, float y1) {
    auto c = realDrawColor;
    append(DrawingObj(67, inputTransform(vec2(x0, y0)), inputTransform(vec2(x1,y1)), vec2(0, 0), c));
  }
  void fillRect(in vec2 a, in vec2 b)               { fillRect(a.x, a.y, b.x, b.y); }
  void fillRect(in bounds2 b)                       { fillRect(b.low, b.high); }
  void fillRect(in ibounds2 b)                      { fillRect(bounds2(b)); } //todo: ibounds2 automatikusan atalakulhasson bounds2-re

  void drawGlyph(int idx, in bounds2 b, in RGB8 bkColor = clBlack){
    auto c = realDrawColor;
    auto c2 = bkColor.to!RGBA8;

    auto tx0 = vec2(16/*fontflag=image*/, 0),
         tx1 = vec2(1, 1);

    //align proportiolally
    auto al = RectAlign(HAlign.center, VAlign.center, true, false, true); //shrink, enlarge, aspect

    auto info = textures.accessInfo(idx); //todo: csunya, kell egy texture wrapper erre

    auto b2 = al.apply(b, bounds2(0, 0, info.width, info.height));

    append(DrawingObj(256+idx, inputTransform(b2.low), inputTransform(b2.high), tx0, c, tx1, c2.raw));
  }

  void drawGlyph(in File fileName, in bounds2 b, in RGB8 bkColor = clBlack){
    drawGlyph(textures[fileName], b, bkColor);
  }

  void drawGlyph(in File fileName, in vec2 p, in RGB8 bkColor = clBlack){
    drawGlyph(textures[fileName], p, bkColor);
  }

  void drawGlyph(int idx, in vec2 p, in RGB8 bkColor = clBlack){ //todo: ezeket az fv headereket racionalizalni kell
    auto info = textures.accessInfo(idx);
    drawGlyph(idx, bounds2(p.x, p.y, p.x+info.width, p.y+info.height), bkColor);
  }

  void drawGlyph(int idx, float x=0, float y=0, in RGB8 bkColor = clBlack){
    drawGlyph(idx, vec2(x, y), bkColor);
  }

  void drawFontGlyph(int idx, in bounds2 b, in RGB8 bkColor = clBlack, in int fontFlags = 0){   //bit0:bold
    auto c = realDrawColor;
    auto c2 = bkColor.to!RGBA8;

    auto tx0 = vec2(fontFlags, 0),
         tx1 = vec2(0, 0);

    //align proportiolally
//    auto al = RectAlign(HAlign.center, VAlign.center, true, true, false); //shrink, enlarge, aspect

//    auto info = textures.accessInfo(idx); //todo: csunya, kell egy texture wrapper erre

//    auto b2 = al.apply(b, bounds2(0, 0, info.width, info.height));

    append(DrawingObj(256+idx, inputTransform(b.low), inputTransform(b.high), tx0, c, tx1, c2.raw));
  }

  void fillTriangle(float x0, float y0, float x1, float y1, float x2, float y2){
    auto c = realDrawColor;
    append(DrawingObj(68, inputTransform(vec2(x0, y0)), inputTransform(vec2(x1,y1)), inputTransform(vec2(x2,y2)), c));
  }
  void fillTriangle(in vec2 a, in vec2 b, in vec2 c){ fillTriangle(a.x, a.y, b.x, b.y, c.x, c.y); }

  void fillConvexPoly(in vec2[] p){
    foreach(i; 2..p.length) fillTriangle(p[0], p[i], p[i-1]);
  }

  void drawRombus(float x0, float y0, float x2, float y2){
    auto x1 = (x0+x2)*0.5f,
         y1 = (y0+y2)*0.5f;
    moveTo(x0, y1); lineTo(x1, y0); lineTo(x2, y1); lineTo(x1, y2); lineTo(x0, y1);
  }
  void drawRombus(in vec2 a, in vec2 b)               { drawRombus(a.x, a.y, b.x, b.y); }
  void drawRombus(in bounds2 b)                       { drawRombus(b.low, b.high); }

  void fillRombus(float x0, float y0, float x2, float y2){
    auto x1 = (x0+x2)*0.5f,
         y1 = (y0+y2)*0.5f;
    fillConvexPoly([vec2(x0,y1), vec2(x1, y0), vec2(x2, y1), vec2(x1, y2)]);
  }
  void fillRombus(in vec2 a, in vec2 b)               { fillRombus(a.x, a.y, b.x, b.y); }
  void fillRombus(in bounds2 b)                       { fillRombus(b.low, b.high); }

// gridLines ////////////////////////////////////////////////////

  void gridLines(View2D view, float dist, RGB color=clGray, float width=-1, LineStyle style = LineStyle.normal, string hv = "hv")
  {
    //todo: this is not working with translate()
    auto horz = hv.canFind('h'), vert = hv.canFind('v');
    if(!horz && !vert) return;

    saveState; scope(exit) restoreState;

    this.color = color;
    lineWidth = width;
    lineStyle = style;

    auto vis = view.visibleArea;
    vis.low  = (vis.low /dist-vec2(1,1)).floor*dist;
    vis.high = (vis.high/dist+vec2(1,1)).ceil *dist;
    auto cnt = vis.size/dist,
         siz = view.clientSize/cnt;

    foreach(c; 0..2){
      if(c==0 && horz || c==1 && vert) {

        alpha = remap_clamp(siz[c], 4, 16, 0, 0.20);
        if(!alpha) continue;

        for(float a = vis.low[c]; a<=vis.high[c]; a+=dist) {
          if(c==0) vLine(a, vis.low.y, vis.high.y);
              else hLine(vis.low.x, a, vis.high.x);
        }
      }
    }

    alpha = 1; //todo: nem tul jo
  }

  void mmGrid(View2D view) {
    auto a = 0.55f;
    gridLines(view, 1,  clGray,  0.05*a);
    gridLines(view, 5,  clGray,  0.10*a);
    gridLines(view, 10, clWhite, 0.15*a);
  }

  void inchGrid(View2D view) {
    gridLines(view, 25.4/16, clGray , 0.05);
    gridLines(view, 25.4/ 4, clGray , 0.10);
    gridLines(view, 25.4   , clWhite, 0.15);
  }

// Ellipse/circle //////////////////////////////////////////////////////////////

  void ellipse(float x, float y, float ra, float rb, float arc0=0, float arc1=2*PI) {
    while(arc0>arc1) arc1 += 2*PI; //todo: lame

    float rounds = (arc1-arc0)*(0.5f/PI);
    int cnt = iround(rounds*64);  //resolution  //todo: it should be done in the shader
    float incr = cnt ? (arc1-arc0)/cnt : 0;
    foreach(i; 0..cnt+1){
      float a = arc0+incr*i;
      lineTo(x+sin(a)*ra, y+cos(a)*rb, !i);
    }
  }
  void ellipse(in vec2 p, float r, float arc0=0, float arc1=2*PI) { ellipse(p.x, p.y, r, r, arc0, arc1); }
  void ellipse(in vec2 p, in vec2 r, float arc0=0, float arc1=2*PI) { ellipse(p.x, p.y, r.x, r.y, arc0, arc1); }

  void circle(float x, float y, float r, float arc0=0, float arc1=2*PI) { ellipse(x, y, r, r, arc0, arc1); }
  void circle(in vec2 p, float r, float arc0=0, float arc1=2*PI) { ellipse(p.x, p.y, r, r, arc0, arc1); }

// Text ////////////////////////////////////////////////////////////////////////

  float textWidth(string text){
    auto scale = fontHeight*(1.0f/40);         //todo: nem mukodik a negativ lineWidth itt! Sot! Egyaltalan nem mukodik a linewidth
    return plotFont.textWidth(scale, fontMonoSpace, text);
  }

  void textOut(vec2 p, string text, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false){
    saveState; scope(exit) restoreState; //opt:slow

    auto scale = fontHeight*(1.0f/40);         //todo: nem mukodik a negativ lineWidth itt! Sot! Egyaltalan nem mukodik a linewidth
    lineWidth = 3*scale*fontWeight*scaleFactor.x;
    lineStyle = LineStyle.normal;

    //align
    with(HAlign) if(align_!=left){
      auto tw = plotFont.textWidth(scale, fontMonoSpace, text);
      p.x += (width-tw)*(align_==center ? 0.5f : 1.0f);
    }

    plotFont.drawText(this, p, scale, fontMonoSpace, fontItalic, text, vertFlip);
  }
  void textOut(float x, float y, string text, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false){
    textOut(vec2(x, y), text, width, align_, vertFlip);
  }
  void textOut(in ivec2 p, string text, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false){
    textOut(vec2(p), text, width, align_, vertFlip);
  }

  void textOut(vec2 p, string[] lines, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false){
    foreach(s; lines){
      textOut(p, s, width, align_, vertFlip);
      p.y += fontHeight;
    }
    return;
  }

  void textOut(float x, float y, string[] lines, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false){
    textOut(vec2(x, y), lines, width, align_, vertFlip);
  }

  void textOutMulti(float x, float y, string lines, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false){
    textOut(x, y, lines.splitLines, width, align_, vertFlip);
  }

  void textOutMulti(vec2 p, string lines, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false){
    textOut(p, lines.splitLines, width, align_, vertFlip);
  }




// Draw Bitmap ////////////////////////////////////

  void fillRectClearType(float x0, float y0, float x1, float y1){
    auto xa = mix(x0, x1, 0.333333);
    auto xb = mix(x0, x1, 0.666666);
    auto oldc = color;
    color = RGB8(oldc.raw & 0x0000FF); fillRect(x0, y0, xa, y1);
    color = RGB8(oldc.raw & 0x00FF00); fillRect(xa, y0, xb, y1);
    color = RGB8(oldc.raw & 0xFF0000); fillRect(xb, y0, x1, y1);
    color = oldc;
  }

  void draw(Bitmap bmp, float x0=0, float y0=0, bool clearTypeEffect=false){
    if(bmp is null || bmp.empty) return;

    auto img = bmp.get!RGB;
    foreach(x, y, c; img){
      color = c;
      if(clearTypeEffect) fillRectClearType(x0+x, y0+y, x0+x+1, y0+y+1);
                     else fillRect         (x0+x, y0+y, x0+x+1, y0+y+1);
    }
  }

  void drawClearType(Bitmap bmp, float x0=0, float y0=0){
    draw(bmp, x0, y0, true);
  }

  void drawAlpha(Bitmap bmp, float x0=0, float y0=0){
    //todo: bmp.to    auto tmp = bmp.to!LA8;
    enforce("not impl");
    /*auto tmp = bmp.dup;
    if(tmp.channels==4) tmp.rgba.data.each!((ref c){ c.r = c.a; c.g = c.a; c.b = c.a; });
    draw(tmp, x0, y0);*/
  }


// Complex stuff: debug scene //////////////////////////////////////////////////

  void debugDrawings(View2D view){
    mmGrid(view);

    foreach(i; 1..9){
      //draw points
      pointSize =  i; point(i*10    , 0); //absolute size
      pointSize = -i; point(i*10+100, 0); //relative size

      //draw lines
      lineWidth =  i; moveTo(i*10    , 10); lineRel(20, 30); //absolute size
      lineWidth = -i; moveTo(i*10+100, 10); lineRel(20, 30); //relative size
    }

    import std.traits;
    lineWidth = 1;
    moveTo(0, 50.5f);
    foreach (ls; EnumMembers!LineStyle){
      lineStyle = ls;
      lineRel(200, 0);  moveRel(-200, 10);
    }
    lineStyle = LineStyle.normal;

    lineWidth = 2;
    color = clYellow;
    drawRect(-10, -10, 210, 110);
  }


////////////////////////////////////////////////////////////////////////////////
//  Shader code                                                               //
////////////////////////////////////////////////////////////////////////////////


  //todo: megaTexMaxCount-ot meg a tobbi konstanst kivulrol szedni
  //todo: arrowless curves could use max vertices
  //todo: arrows -> triangles instead of trapezoids
  //todo: arrows: no curcature needed
  //todo: compress geom shader output size
  immutable shaderCode = q{
    #version 150

    #define MegaTexMaxCnt       }~MegaTexMaxCnt         .text~q{
    #define SubTexCellBits      }~SubTexCellBits        .text~q{
    #define InvBoldOffset       }~InvBoldOffset         .text~q{
    #define BoldOffset          (1.0/InvBoldOffset)

    int fetchBits(inout int a, in int bits){
      int res = a & ((1<<bits)-1);
      a = a>>bits;
      return res;
    }

    @vertex://////////////////////////////////////////////////////////////////////////
    in  float aType; in  vec2 aA, aB, aC, aD; in  vec4 aColor, aColor2; in  vec2 aClipMin, aClipMax;
    out float Type; out vec2  A,  B,  C,  D; out vec4  Color,  Color2 ; out vec2 ClipMin , ClipMax ;
    void main() {
      A=aA; B=aB; C=aC; Color=aColor; Type=aType;

      //glyph only
      D=aD;
      Color2=aColor2;

      //all
      ClipMin = aClipMin;
      ClipMax = aClipMax;
    } //just shovels the data through

    @geometry:////////////////////////////////////////////////////////////////////////
    #define MaxArrowVertices 12
    #define MaxCurveVertices 22
    #define TotalVertices 34
    // TotalVertices = MaxCurveVertices + MaxArrowVertices

    //NV GTX650 384core 1GB 128bit    totalVertices = 39     GL_MAX_GEOMETRY_TOTAL_OUTPUT_COMPONENTS = 1K
    //AMD R9 Fury X 4096core 4GB HBM  totalVertices = 84     GL_MAX_GEOMETRY_TOTAL_OUTPUT_COMPONENTS = 4K

    // GL_MAX_GEOMETRY_OUTPUT_VERTICES
    // GL_MAX_GEOMETRY_OUTPUT_COMPONENTS

    //todo: 200909 Csobi kartyajan nem megy az uj vertex attribok miatt. -> attribok tomoritese -> MaxCurveRertices hardvertol fuggo szamitasa.

    layout(points) in;
    layout(triangle_strip, max_vertices = TotalVertices) out; //Extra vertices are there for arrowheads

    //inputs ---------------------------------------------------------------------

    in float Type[]; in vec2 A[], B[], C[], D[]; in vec4 Color[], Color2[]; in vec2 ClipMin[], ClipMax[];

    //outputs ---------------------------------------------------------------------
                                                                                                                // 4 gl_Position
    flat out vec4 fColor;                                                                                       // 4
    out vec2 fStipple; //type, phase:    //note: it was "varying out", but NVidia don't like it, just "out"     // 2

    //glyph only
    flat out vec4 fColor2; //alpha holds special stuff                                                          // 4
    out vec2 fTexCoord; //todo: osszevonhato lenne az fStipple-vel                                              // 2

    flat out ivec2 stPos, stSize;                                                                               // 4
    flat out int stConfig, stIdx;                                                                               // 2
    flat out vec2 texelPerPixel;                                                                                // 2
    flat out float boldTexelOffset;                                                                             // 1
    flat out int fontFlags;                                                                                     // 1
    flat out vec2 fClipMin, fClipMax;                                                                           // 4
                                                                                                                // sum = 30,   1024/30 = 34    GTX650: 1024 components max
    //uniforms ---------------------------------------------------------------------

    //transformation
    uniform vec2 uShift, uScale, uViewPortSize;

    uniform sampler2D smpInfo;

    struct SubTexInfo{
      ivec2 pos, size;
      int megaTexIdx;
      int config;
    };

    SubTexInfo decodeSubTexInfo(in vec4 p[2]){
    /*uint, "cellX",    14,      uint, "texIdx_lo", 2,
      uint, "cellY",    14,      uint, "texIdx_hi", 2,
      uint, "width1",   14,      uint, "texChn_lo", 2,
      uint, "height1",  14,      uint, "texChn_hi", 2 */

      SubTexInfo info;
      ivec4 i1 = ivec4(round(p[0]*255.0));
      ivec4 i2 = ivec4(round(p[1]*255.0));

      /*int[4] tmp = { i1.x + (i1.y<<8), i1.z + (i1.w<<8),
                       i2.x + (i2.y<<8), i2.z + (i2.w<<8) };*/ //NV error: error C7549: OpenGL does not allow C style initializers
      int[4] tmp = int[4]( i1.x + (i1.y<<8), i1.z + (i1.w<<8),
                           i2.x + (i2.y<<8), i2.z + (i2.w<<8) );

      info.pos.x  = fetchBits(tmp[0], 14)<<SubTexCellBits;
      info.pos.y  = fetchBits(tmp[1], 14)<<SubTexCellBits;
      info.size.x = fetchBits(tmp[2], 14)+1;
      info.size.y = fetchBits(tmp[3], 14)+1;

      info.megaTexIdx = tmp[0] + (tmp[1]<<2);
      info.config     = tmp[2] + (tmp[3]<<2);

      return info;
    }

    SubTexInfo fetchSubTexInfo(int subTexIdx){
      int infoTexWidth = int(textureSize(smpInfo, 0).x);
      ivec2 infoTexCoord = ivec2((subTexIdx<<1)%infoTexWidth, (subTexIdx<<1)/infoTexWidth);

      vec4[2] subTexInfoRaw;
      subTexInfoRaw[0] = texelFetch(smpInfo, infoTexCoord, 0);
      infoTexCoord.x += 1;
      subTexInfoRaw[1] = texelFetch(smpInfo, infoTexCoord, 0);

      return decodeSubTexInfo(subTexInfoRaw);
    }

    void emitSubTexInfo(SubTexInfo info){
      stIdx    = info.megaTexIdx;
      stConfig = info.config    ;
      stPos    = info.pos       ;
      stSize   = info.size      ;
    }

    //common math stuff
    float clamp(float a, float mi, float ma) { return min(max(a, mi), ma); }
    vec2 rot90(vec2 p) { return vec2(-p.y, p.x); }

    float split(inout float value, in float range){
      float tmp = value*(1.0/range);
      float outp = fract(tmp)*range;
      value = floor(tmp);
      return outp;
    }

    //Transforms into screenSpace. uScale means the pixelsize.
    vec2 trans(vec2 p) { return (p+uShift)*uScale; }
    vec2 invTrans(vec2 p) { return (p/uScale)-uShift; }
    //Transforms into normalized view coordinates for opengl.
    vec2 finalTrans(vec2 p) { return p/(uViewPortSize)*vec2(2,-2); }

    //calculates halfCircle subdivision count
    float calcSegCnt(float radius, int maxVerts) { return clamp(round(radius/3.0+2.0), 2.0, maxVerts/2.0-2.0); }

    //calculates halfSize vector from a float. Uses screenPixel based size when the input is negative.
    vec2 calcRadius(float size) {
      vec2 res = (size>=0) ? uScale*size
                           : -vec2(size, size);
      return res*0.5;
    }
    float calcHalfSize(float size) {
      vec2 r = calcRadius(size);
      return mix(r.x, r.y, 0.5);
    }


    //emits a vertex. Uses screen coords
    void emit(vec2 p){ gl_Position = vec4(finalTrans(p), 0, 1.0);  EmitVertex(); }
    void emit(float x, float y){ emit(vec2(x, y)); }

    void emitTex(vec2 p, vec2 t){ gl_Position = vec4(finalTrans(p), 0, 1.0); fTexCoord = t;  EmitVertex(); }

    //emits a rectangle using halfWidth and halfHeight
    void emitBlock(vec2 p, float xs, float ys){
      emit(p.x+xs, p.y-ys);
      emit(p.x-xs, p.y-ys);
      emit(p.x+xs, p.y+ys);
      emit(p.x-xs, p.y+ys);
    }
    void emitBlock(vec2 p, vec2 halfSize) { emitBlock(p, halfSize.x, halfSize.y); }

    void emitRect(vec2 a, vec2 b){
      emit(a.x, a.y);
      emit(a.x, b.y);
      emit(b.x, a.y);
      emit(b.x, b.y);
    }

    void emitGlyph(vec2 a, vec2 b, vec2 ta, vec2 tb){
      const float gap0 = 0;
      const float gap1 = 0;
      emitTex(vec2(a.x, a.y), vec2(ta.x+gap0, ta.y+gap0));
      emitTex(vec2(a.x, b.y), vec2(ta.x+gap0, tb.y-gap1));
      emitTex(vec2(b.x, a.y), vec2(tb.x-gap1, ta.y+gap0));
      emitTex(vec2(b.x, b.y), vec2(tb.x-gap1, tb.y-gap1));
    }

    void emitTriangle(vec2 a, vec2 b, vec2 c){
      emit(a); emit(b); emit(c);
    }

    //emits an ellipse. 2 axes are vert and horz only.
    void emitEllipse(vec2 p, vec2 radius, int maxVerts){
      float minRadius = min(radius.x, radius.y);
      if(minRadius>0.75){
        float segCnt = calcSegCnt(minRadius, maxVerts),
              incr   = 1/segCnt;
        emit(p.x, p.y+radius.y);
        for(float i=1; i<segCnt; i += 1.0){
          float ph = i*incr*3.14159265,
                xa = sin(ph)*radius.x,
                ya = cos(ph)*radius.y;
          emit(p.x+xa, p.y+ya);
          emit(p.x-xa, p.y+ya);
        }
        emit(p.x, p.y-radius.y);
      }else{ //simple block
        emitBlock(p, radius);
      }
      EndPrimitive();
    }
    void emitCircle(vec2 p, float radius, int maxVerts) { emitEllipse(p, vec2(radius, radius), maxVerts); }

    void EmitTrapezoid(vec2 p0, vec2 p1, vec2 s0, vec2 s1){
      //        p0
      //     /--|--\   --> s0
      //    /   |   \
      //   /----|----\ ----> s1
      //        p1
      emit(p0-s0);  emit(p0+s0);
      emit(p1-s1);  emit(p1+s1);
      EndPrimitive();
    }

    void emitLine(vec2 u0, vec2 u1, float lineWidth, float stipple, int maxVerts, float arrowStyle){
      float halfWidth = calcHalfSize(lineWidth);
      vec2 p0 = trans(u0),  p1 = trans(u1);

      if(p0==p1) p1.x += halfWidth*0.01; //failsafe: adjust 0 length line

      fStipple.x = stipple;

      vec2 dir = normalize(p1-p0),
           absDir = abs(dir.x)>abs(dir.y) ? vec2(1,0) : vec2(0,1),
           hdir = dir*halfWidth,
           hside = rot90(hdir),
           stippleDir = lineWidth<0 ? absDir/(halfWidth*2)
                                    : absDir/lineWidth;

      float segCnt = halfWidth<0.75 ? 1 //simple line, like a rectangle
                                    : calcSegCnt(halfWidth, maxVerts), incr = 1/segCnt;
      for(float i=0; i<=segCnt; i += 1.0){
        float ph = i*incr*3.14159265,
              xa = sin(ph),
              ya = cos(ph);
        vec2 sside = hside*ya,
             sdir = hdir*xa,
             q0 = p0-sdir+sside,
             q1 = p1+sdir+sside;
        fStipple.y = dot(lineWidth<0 ? q0-uScale*uShift : invTrans(q0), stippleDir);  emit(q0);
        fStipple.y = dot(lineWidth<0 ? q1-uScale*uShift : invTrans(q1), stippleDir);  emit(q1);
      }
      EndPrimitive();

      //Draw optional ArrowHeads
      if(arrowStyle!=0.0 || true){

        fStipple.x = 0; //disable line stipple

        vec2 arrowSize = vec2(8.0, 2.5);
        vec2 pc   = (p1+p0)*0.5,
             fwd  = hdir *2*arrowSize.x,
             side = hside*2*arrowSize.y;

        float arrowHead    = split(arrowStyle, 4.0);
        float arrowTail    = split(arrowStyle, 4.0);
        float centerNormal = split(arrowStyle, 4.0);

        if(arrowTail==1.0) EmitTrapezoid(p0+fwd, p0, -side, -hside);else
        if(arrowTail==2.0) EmitTrapezoid(p0+side, p0-side,  hdir,  hdir);

        if(arrowHead==1.0) EmitTrapezoid(p1-fwd, p1,  side,  hside);else
        if(arrowHead==2.0) EmitTrapezoid(p1+side, p1-side,  hdir,  hdir);

        if(centerNormal==1.0) EmitTrapezoid(pc     , pc-side,  hdir,  hdir);else
        if(centerNormal==2.0) EmitTrapezoid(pc+side, pc     ,  hdir,  hdir);else
        if(centerNormal==3.0) EmitTrapezoid(pc+side, pc-side,  hdir,  hdir);
      }

    }

    vec2 evalBezier2(vec2 A, vec2 B, vec2 C, float t){
      return mix(mix(A, B, t), mix(B, C, t), t);
    }

    void emitBezier2(vec2 A, vec2 B, vec2 C,float lineWidth, int maxVerts){
      float halfWidth = calcHalfSize(lineWidth);
      float tStep = 1.0/(maxVerts/2-1);
      float t = 0.0;
      vec2 lastPos = A - (evalBezier2(A, B, C, tStep) - A); //mirror the first step backwards

      for(int i = 0; i<maxVerts/2; i++, t += tStep){
        vec2 pos = evalBezier2(A, B, C, t);
        vec2 dir = normalize(pos-lastPos);
        lastPos = pos;

        vec2 hSide = rot90(dir)*halfWidth;

        emit(pos-hSide); emit(pos+hSide);
      }

      EndPrimitive();
    }

    void main(){
      fColor = Color[0];
      fStipple = vec2(0, 0);
      boldTexelOffset = 0;
      fontFlags = 0;
      fClipMin = trans(ClipMin[0]) + uViewPortSize*0.5;
      fClipMax = trans(ClipMax[0]) + uViewPortSize*0.5;

      int type = int(Type[0]);
      if(type==1){ //Point
        emitEllipse(trans(A[0]), calcRadius(C[0].x), MaxCurveVertices);
      }else if(type==2){ //Point2
        emitEllipse(trans(A[0]), calcRadius(C[0].x), MaxCurveVertices/2);
        emitEllipse(trans(B[0]), calcRadius(C[0].y), MaxCurveVertices/2);
      }else if(type>=3 && type<=3+63){ //Line
        emitLine(A[0], B[0], C[0].x/*lineWidth*/, C[0].y/*stipple*/, MaxCurveVertices, type-3);
      }else if(type==67){ //Filled rect
        emitRect(trans(A[0]), trans(B[0]));
      }else if(type==68){ //Triangle
        emitTriangle(trans(A[0]), trans(B[0]), trans(C[0]));
      }else if(type==69){ //Bezier 2nd order
        emitBezier2(trans(A[0]), trans(B[0]), trans(C[0]), D[0].x/*lineWidth*/, MaxCurveVertices);
      }else if(type>=256 && type<256+0x10000){ //glyph rect geom shader////////////////////////////////
        fontFlags = int(floor(C[0].x));

        fColor2 = Color2[0];

        SubTexInfo info = fetchSubTexInfo(type-256);
        emitSubTexInfo(info);

        //texture coordinates (non-normalized)  //adjust to the textel centers
        vec2 t0 = info.pos                        + vec2(.5);
        vec2 t1 = info.pos+info.size              - vec2(.5);

        //enlarge for boldness
        bool isBold = (fontFlags & 1)!=0;
        if(isBold){
          float o = info.size.y*BoldOffset;
          boldTexelOffset = o;

          o *= 3; //cleartype
          t0.x -= o; t1.x += o;
        }

        //transform to screenPixelSpace
        vec2 tA = trans(A[0]), tB = trans(B[0]);

        //calculate pixel size on the texture
        texelPerPixel = (t1-t0)/(tB-tA);

        emitGlyph(tA, tB, t0, t1);
      }
    }

    @fragment:
    layout(origin_upper_left) in vec4 gl_FragCoord;

    flat in vec4 fColor;
    in vec2 fStipple; //type, phase

    //glyph only
    in vec2 fTexCoord;
    flat in vec4 fColor2; //

    //subTexture
    flat in ivec2 stPos, stSize;
    flat in int stConfig, stIdx;

    flat in vec2 texelPerPixel;
    flat in float boldTexelOffset;
    flat in int fontFlags;

    flat in vec2 fClipMin, fClipMax;

    out vec4 FragColor; //NV compatibility: gl_FragColor is deprecated

    uniform sampler2D smpMega[MegaTexMaxCnt];

    vec4 megaSample_nearest_internal(vec2 tc){
//      if(stIdx!=0) return vec4(1, 0, 1, 1); //return fuschia for multitexturing

      ivec2 itc = ivec2(floor(tc));

      bool outside = itc.x<stPos.x || itc.x>=stPos.x+stSize.x ||
                     itc.y<stPos.y || itc.y>=stPos.y+stSize.y;

      itc.x = clamp(itc.x, stPos.x, stPos.x+stSize.x-1);
      itc.y = clamp(itc.y, stPos.y, stPos.y+stSize.y-1);

      vec4 t = texelFetch(smpMega[stIdx], itc, 0);
      if(outside) t = vec4(0);

      if(stConfig==0) t.yzw = t.xxx; //spread 1 channel to 4ch

      return t;

/*      vec4 t; //this is the proper way to fetch multitexturing
      for(int i=0; i<=stIdx; i++) t += texelFetch(smpMega[i], itc, 0)*(i==stIdx ? 1 : 0);
      return t;*/
    }

    bool hline(float tcy, float pos, float thickness){
      float base = stPos.y + stSize.y*pos;
      float h = stSize.y*thickness;

      return (tcy>base && tcy<base+h);
    }

    //todo: megatexture error: Maybe it's a fix: wiki glsl samples Non-uniform flow control !!!!!

    vec4 megaSample_nearest(vec2 tc){
      vec4 center = megaSample_nearest_internal(tc);
      if(boldTexelOffset>0){
        //maximize 4 diagonal alpha's
        vec2 d = vec2(boldTexelOffset*3, boldTexelOffset)*0.71;
        vec2 e = vec2(d.x, -d.y);
        float a = max(max(megaSample_nearest_internal(tc+d).a, megaSample_nearest_internal(tc-d).a),
                      max(megaSample_nearest_internal(tc+e).a, megaSample_nearest_internal(tc-e).a));
        center.a = max(center.a, a);
      }

      //underline, strikeout
      if(((fontFlags&4)!=0) && hline(tc.y, 0.875, 0.075)
       ||((fontFlags&8)!=0) && hline(tc.y, 0.48, 0.075)) center = vec4(0,0,0,1);

      return center;
    }

    vec4 megaSample_linear(vec2 tc){
      ivec2 itc = ivec2(floor(tc));
      vec2  ftc = fract(tc);

      vec4 a = mix(megaSample_nearest(itc+ivec2(0,0)), megaSample_nearest(itc+ivec2(1,0)), ftc.x);
      vec4 b = mix(megaSample_nearest(itc+ivec2(0,1)), megaSample_nearest(itc+ivec2(1,1)), ftc.x);

      return mix(a, b, ftc.y);
    }

    //texture coordinates for rooks 6
    vec2 tc6(in vec2 tc, float x, float y){ return tc+vec2(texelPerPixel.x, texelPerPixel.y)*(vec2(x-2.5, y-2.5)*(1.0/6.0)); }

    vec4 megaSample_rooks6(in vec2 tc){
      vec4 texel = megaSample_nearest(tc6(tc,0,4))+
                   megaSample_nearest(tc6(tc,1,0))+
                   megaSample_nearest(tc6(tc,2,2))+
                   megaSample_nearest(tc6(tc,3,3))+
                   megaSample_nearest(tc6(tc,4,5))+
                   megaSample_nearest(tc6(tc,5,1));

      return texel*(1.0/6);
    }

    void megaSample_clearType(in vec2 tc, out vec3 color, out float[3] alpha){
      vec4[7] s;
      s[0] = megaSample_nearest(tc6(tc,-4,2));
      s[1] = megaSample_nearest(tc6(tc,-2,3));
      s[2] = megaSample_nearest(tc6(tc, 0,2));
      s[3] = megaSample_nearest(tc6(tc, 2,3));
      s[4] = megaSample_nearest(tc6(tc, 4,2));
      s[5] = megaSample_nearest(tc6(tc, 6,3));
      s[6] = megaSample_nearest(tc6(tc, 8,2));

      for(int i=0; i<3; i++){
        alpha[i] = +s[i  ].a*0.08
                   +s[i+1].a*0.25
                   +s[i+2].a*0.34
                   +s[i+3].a*0.25;
                   +s[i+4].a*0.08;
      }

      color = (s[2].rgb+s[3].rgb+s[4].rgb)*0.3333333;
    }

    vec4 clearTypeMix(vec4 c0, vec4 c1, float[3] alpha){
      return vec4( mix(c0.r, c1.r, alpha[0]),
                   mix(c0.g, c1.g, alpha[1]),
                   mix(c0.b, c1.b, alpha[2]),
                   mix(c0.a, c1.a, (alpha[0]+alpha[1]+alpha[2])*(1.0/3)) );
    }


    vec4 megaTexIdxColor(){
      vec3 c;
           if(stIdx==0) c = vec3(1, 0, 0);
      else if(stIdx==1) c = vec3(1, 1, 0);
      else if(stIdx==2) c = vec3(0, 1, 0);
      else if(stIdx==3) c = vec3(0, 1, 1);
      return vec4(c, 1);
    }

    bool chkClip(in vec2 mi, in vec2 ma){
      return gl_FragCoord.x>ma.x || gl_FragCoord.x<mi.x
          || gl_FragCoord.y>ma.y || gl_FragCoord.y<mi.y;
    }

    void main(){
      if(chkClip(fClipMin, fClipMax)) discard;

      if(fColor2.w==0){ // plain color stuff

        vec4 color = fColor;

        //stipple
        float stippleType = fStipple.x;
        if(stippleType!=0){
          float a = 0;

          stippleType = stippleType/16;
          float mask = fract(stippleType)*16;
          float scale = floor(stippleType);

          float phase = fract(fStipple.y/(pow(2,scale+2.6)))*6;

          //this is crazy and not having the docs for it.
          mask /= 2;  if(fract(mask)>0){ if(phase<1 || phase>=2 && phase<3) a = 1;  mask -= 0.5; }
          mask /= 2;  if(fract(mask)>0){ if(phase>=1 && phase<2) a = 1; mask -= 0.5; }
          mask /= 2;  if(fract(mask)>0){ if(phase>=3 && phase<4) a = 1; mask -= 0.5; }
          mask /= 2;  if(fract(mask)>0){ if(phase>=4 && phase<5) a = 1; mask -= 0.5; }

          color.a *= a;
        }

        FragColor = color;

      }else{ //!----------------> glyph fragment shader /////////////////////////////
        vec4 bkColor = fColor2;
        vec4 fontColor = fColor;
        vec4 finalColor, texel;

        vec2 tc = fTexCoord;

        //italic
        if((fontFlags&2)!=0){
          float dy = tc.y-(stPos.y+stSize.y*0.5);
          tc.x += dy*0.5;
        }

        bool isImage = (fontFlags&16)!=0;
        bool isFont = !isImage;

        //samplingLevel : 0 = nearest, 1 = linear, 2 = rooks6, 3 = cleartype
        int samplingLevel = 0;
        if(isImage){
          samplingLevel = 1;
        }else{
          float L = length(texelPerPixel);
          samplingLevel = L>32 ? 2: //minify
                          L< 1 ? 1: //magnify
                                 3; //medium
        }

        if(samplingLevel==-1){ //debug
          finalColor = vec4(1,0,1,1);
        }else if(samplingLevel==0 || samplingLevel==1){//nearest, linear

          if(samplingLevel==0) texel = megaSample_nearest(tc);
                          else texel = megaSample_linear(tc-vec2(0.5, 0.5));

          if(stConfig==8 )      finalColor = vec4(texel.rgb, fontColor.a);
          else if(stConfig==12) finalColor = mix(bkColor, vec4(texel.rgb, fontColor.a), texel.a);
          else if(stConfig==0)  finalColor = mix(bkColor, fontColor                   , texel.a);

        }else if(samplingLevel==2){//rooks6
          vec4 texel = megaSample_rooks6(tc);
          if(stConfig==8 )      finalColor = vec4(texel.rgb, fontColor.a);
          if(stConfig==12)      finalColor = mix(bkColor, vec4(texel.rgb, fontColor.a), texel.a);
          else if(stConfig==0)  finalColor = mix(bkColor, fontColor                   , texel.a);
        }else{ //clearType
          vec3 smp; float[3] alpha;
          megaSample_clearType(tc, smp, alpha);

          if(stConfig==12)      finalColor = clearTypeMix(bkColor, vec4(smp, fontColor.a), alpha);
          else if(stConfig==0)  finalColor = clearTypeMix(bkColor, fontColor             , alpha);
        }

        FragColor = finalColor;
      }
    }
  };


// Draw the objects on GPU  /////////////////////////////

  void glDraw(View2D view, in vec2 translate = vec2(0)) { glDraw(view.getOrigin(true), view.getScale(true), translate); }

  void glDraw(in vec2 center, float scale, in vec2 translate=vec2(0)) {
    enforce(stack.empty, "Drawing.glDraw() matrix stack is not empty.  It has %d items.".format(stack.length));
    enforce(clipBoundsStack.empty, "Drawing.glDraw() clipBounds stack is not empty.  It has %d items.".format(clipBoundsStack.length));

    if(logDrawing) LOG(shortName, "drawing", stats, "center:", center, "scale:", scale, "translate:", translate);

    drawCnt++;

    //transfer buffers into vboes
    foreach(ref data; buffers){
      totalDrawObj += data.length;
      vboList ~= new VBO(data);
    }
    buffers.clear;

    foreach(vbo; vboList){
      if(!shader) shader = new Shader("DrawingShader", shaderCode);

      auto vpSize = gl.getViewport.size;  //todo: ezek a vbo hivas elott mehetnek kifele

      auto uScale = vec2(scale, scale),
           uShift = -center;

      shader.uniform("uScale", uScale);
      shader.uniform("uShift", uShift+translate);
      shader.uniform("uViewPortSize", vec2(vpSize));

      //map all megaTextures
      foreach(i, t; textures.getGLTextures){
        t.bind(cast(int)i, i==0 ? GLTextureFilter.Nearest : GLTextureFilter.Linear);
        auto name = i==0 ? "smpInfo" : "smpMega[%d]".format(i-1);
        shader.uniform(name, cast(int)i, false);
      }

      shader.attrib(vbo);

      //todo: ezeket az allapotokat elmenteni es visszacsinalni, ha kell, de leginkabb bele kene rakni egy nagy functba az egesz hobelevancot...
      gl.enable(GL_CULL_FACE);
      gl.enable(GL_BLEND);        gl.blendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      gl.enable(GL_ALPHA_TEST);   gl.alphaFunc(GL_GREATER, 0);
      gl.disable(GL_DEPTH_TEST);

      //gl.polygonMode(GL_FRONT_AND_BACK, GL_LINE);
      vbo.draw(GL_POINTS);
    }

    foreach(sd; subDrawings){
      sd.glDraw(center, scale, translate);
    }
  }
  //todo: A binaris konstansokat is szemleltethetne az ide!
  //todo: az IDE automatikusan irhatna a bezaro } jelek utan, hogy mit zar az be. Csak annak a scopenak, amiben a cursor van.
}

////////////////////////////////////////////////////////////////////////////////
//  Logger                                                                    //
////////////////////////////////////////////////////////////////////////////////

deprecated class Logger{
  Drawing dr; //graphic log
  bool wr;     //writeln log

  this(bool dump=false, Drawing dr=null) { this.dr = dr; wr = dump; }
  this(Drawing dr, bool dump=false)      { this.dr = dr; wr = dump; }

  void opCall(string s){ log(s); }

  enum LogType { Text, Dump, Code }

  void log(string s, LogType type = LogType.Text){
    //multiline?
    if(s.canFind('\n')){
      s.split("\n").map!stripRight.each!(a => log(a, type));
      return;
    }

    if(dr){
      auto oldc             = dr.color        ;     dr.color         = clSilver;
      auto oldfh            = dr.fontHeight   ;     dr.fontHeight    = 1       ;
      auto oldFontMonoSpace = dr.fontMonoSpace;     dr.fontMonoSpace = type!=LogType.Text;

      dr.textOut(0, 0, s);
      dr.origin = dr.origin+vec2(0, 1);

      dr.color         = oldc            ;
      dr.fontHeight    = oldfh           ;
      dr.fontMonoSpace = oldFontMonoSpace;
    }
    if(wr) writeln(s);
  }

  void dump(string s){
    log(s, LogType.Dump);
  }

  void code(string s){
    log(s, LogType.Code);
  }

  void tableRow(R)(R row)
  if(isInputRange!R)
  {
    string s;
    if(dr){
      static if(__traits(compiles, row.front.toDrawing(dr))){
        for(auto r2 = row; !r2.empty;){ const cell = r2.front; r2.popFront;
          auto oldy = dr.origin.y;
          cell.toDrawing(dr);
          if(r2.empty) dr.origin.x = 0; //newLine
                  else dr.origin.y = oldy; //preserve line
        }
      }else{
        auto oldWr = wr;
        wr = false;
        scope(exit) wr = oldWr;
        dump(row.map!text.join(" "));
      }
    }
    if(wr) writeln(row.map!text.join(" "));
  }

  void table(R)(R tbl)
  if(isInputRange!R)
  {
    foreach(const row; tbl) tableRow(row[]);
  }

  void table(R)(string capt, R tbl)
  if(isInputRange!R)
  {
    title(capt);
    table(tbl);
  }

  void title(string s){
    if(dr){
      auto oldc = dr.color;             dr.color = clWhite;
      auto oldfh = dr.fontHeight;       dr.fontHeight = 3;

      dr.textOut(0, 2, s);
      dr.origin = dr.origin+vec2(0, 6);

      dr.color = oldc;
      dr.fontHeight = oldfh;
    }
    if(wr) writefln("\n\33\17%s\n\33\7", s);
  }


}
