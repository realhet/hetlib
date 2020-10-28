//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

//@compile --cov

import het.utils;

//! ShaderToy tests ///////////////////////////////////////////////////////////////////

vec2 iResolution;
float iTime = 0;

static if(1){ // 3D Julia ////////////////////////////////////////////////
  // https://www.shadertoy.com/view/MtfGWM
  //another holy grail candidate from msltoe found here:
  //http://www.fractalforums.com/theory/choosing-the-squaring-formula-by-location

  //I have altered the formula to make it continuous but it still creates the same nice julias - eiffie

  alias time = iTime;
  alias size = iResolution;

  vec3 C,mcol;
  bool bColoring=false;
  enum pi = 3.14159f;
  float DE(vec3 p){
    float dr=1.0,r=length(p);
    //C=p;
    for(int i=0;i<10;i++){
      if(r>20.0)break;
      dr=dr*2.0*r;
      float psi = abs(mod(atan(p.z,p.y)+pi/8.0,pi/4.0)-pi/8.0);
      p.yz=vec2(cos(psi),sin(psi))*length(p.yz);
      vec3 p2=p*p;
      p=vec3(vec2(p2.x-p2.y,2.0*p.x*p.y)*(1.0-p2.z/(p2.x+p2.y+p2.z)),
        2.0*p.z*sqrt(p2.x+p2.y))+C;
      r=length(p);
      if(bColoring && i==3)mcol=p;
    }
    return min(log(r)*r/max(dr,1.0),1.0);
  }

  float rnd(vec2 c){return fract(sin(dot(vec2(1.317,19.753),c))*413.7972);}
  float rndStart(vec2 fragCoord){
    return 0.5+0.5*rnd(fragCoord.xy+vec2(time*217.0));
  }
  float shadao(vec3 ro, vec3 rd, float px, vec2 fragCoord){//pretty much IQ's SoftShadow
    float res=1.0,d,t=2.0*px*rndStart(fragCoord);
    for(int i=0;i<4;i++){
      d=max(px,DE(ro+rd*t)*1.5);
      t+=d;
      res=min(res,d/t+t*0.1);
    }
    return res;
  }
  vec3 Sky(vec3 rd){//what sky??
    return vec3(0.5+0.5*rd.y);
  }
  vec3 L;
  vec3 Color(vec3 ro, vec3 rd, float t, float px, vec3 col, bool bFill, vec2 fragCoord){
    ro+=rd*t;
    bColoring=true;float d=DE(ro);bColoring=false;
    vec2 e=vec2(px*t,0.0);
    vec3 dn=vec3(DE(ro-e.xyy),DE(ro-e.yxy),DE(ro-e.yyx));
    vec3 dp=vec3(DE(ro+e.xyy),DE(ro+e.yxy),DE(ro+e.yyx));
    vec3 N=(dp-dn)/(length(dp-vec3(d))+length(vec3(d)-dn));
    vec3 R=reflect(rd,N);
    vec3 lc=vec3(1.0,0.9,0.8),sc=sqrt(abs(sin(mcol))),rc=Sky(R);
    float sh=clamp(shadao(ro,L,px*t,fragCoord)+0.2,0.0,1.0);
    sh=sh*(0.5+0.5*dot(N,L))*exp(-t*0.125);
    vec3 scol=sh*lc*(sc+rc*pow(max(0.0,dot(R,L)),4.0));
    if(bFill)d*=0.05;
    col=mix(scol,col,clamp(d/(px*t),0.0,1.0));
    return col;
  }
  mat3 lookat(vec3 fw){
    fw=normalize(fw);vec3 rt=normalize(cross(fw,vec3(0.0,1.0,0.0)));return mat3(rt,cross(rt,fw),fw);
  }

  vec3 Julia(float t){
    t=mod(t,5.0);
    if(t<1.0)return vec3(-0.8,0.0,0.0);
    if(t<2.0)return vec3(-0.8,0.62,0.41);
    if(t<3.0)return vec3(-0.8,1.0,-0.69);
    if(t<4.0)return vec3(0.5,-0.84,-0.13);
    return vec3(0.0,1.0,-1.0);
  }

  void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    float px=0.5/size.y;
    L=normalize(vec3(0.4,0.8,-0.6));
    float tim=time*0.5;

    vec3 ro=vec3(cos(tim*1.3),sin(tim*0.4),sin(tim))*3.0;
    vec3 rd=lookat(vec3(-0.1)-ro)*normalize(vec3((2.0*fragCoord.xy-size.xy)/size.y,3.0));

    tim*=0.6;
    if(mod(tim,15.0)<5.0)C=mix(Julia(tim-1.0),Julia(tim),smoothstep(0.0,1.0,fract(tim)*5.0));
    else C=vec3(-cos(tim),cos(tim)*abs(sin(tim*0.3)),-0.5*abs(-sin(tim)));

    float t=DE(ro)*rndStart(fragCoord),d=0.0,od=10.0;
    vec3 edge=vec3(-1.0);
    bool bGrab=false;
    vec3 col=Sky(rd);
    for(int i=0;i<78;i++){
      t+=d*0.5;
      d=DE(ro+rd*t);
      if(d>od){
        if(bGrab && od<px*t && edge.x<0.0){
          edge=vec3(edge.yz,t-od);
          bGrab=false;
        }
      }else bGrab=true;
      od=d;
      if(t>10.0 || d<0.00001)break;
    }
    bool bFill=false;
    d*=0.05;
    if(d<px*t && t<10.0){
      if(edge.x>0.0)edge=edge.zxy;
      edge=vec3(edge.yz,t);
      bFill=true;
    }
    for(int i=0;i<3;i++){
      if(edge.z>0.0)col=Color(ro,rd,edge.z,px,col,bFill,fragCoord);
      edge=edge.zxy;
      bFill=false;
    }
    fragColor = vec4(2.0*col,1.0);
  }

}

//! Image2D (new image) ///////////////////////////////////////////////////////////////

enum isImage(A) = is(A.ImageType);

template isImage2D(A){
  static if(isImage!A) enum isImage2D = A.Dimension == 2;
                  else enum isImage2D = false;
}

// universal constructor for images

// multidimensional elementtype. The index is just the maximum limit of recusrion. Returns the first non-range type.
private template ElementType1(R) {
  static if(isInputRange!R) alias ElementType1 = ElementType!R;
                       else alias ElementType1 = R;
}
private alias ElementType2(R) = ElementType1!(ElementType1!R);
private alias ElementType3(R) = ElementType1!(ElementType2!R);

private enum isInputRange2(R) = isInputRange !R && isInputRange!(ElementType!R);
private enum isInputRange3(R) = isInputRange2!R && isInputRange!(ElementType!(ElementType!R));

auto image2D(R, T = ElementType3!R)(in ivec2 size, R r, in T def = 0) if(isInputRange!R){
  static if(isInputRange2!R){ // 2D range
    const castedDef = cast(T) def;
    auto arr = std.range.join( r.take(size.y).map!(a => a.padRight(castedDef, size.x).array) );
    arr = arr.padRight(def, size[].product).array;
    return Image!(T, 2)(size, arr);
  }else static if(isInputRange!R){ // 1D range: linear data
    auto arr = r.array;
    arr = arr.padRight(def, size[].product).array.to!(T[]);
    return Image!(T, 2)(size, arr);
  }else{
    static assert(0, "invalid args");
  }
}

auto image2D(R, T = ElementType3!R)(int width, int height, R r, in T def = 0) if(isInputRange!R){
  return image2D(ivec2(width, height), r, def);
}

auto image2D(R, T = ElementType3!R)(R r, in T def = 0) if(isInputRange!R){
  static if(isInputRange2!R){ // 2D range
    const size = ivec2(r.map!(a => a.length.to!int).maxElement, r.length);
    return image2D(size, r, def);
  }else{
    static assert(0, "invalid args: unable to decide 2D image size");
  }
}

auto image2D(T)(in ivec2 size        , T delegate(ivec2) generator){ return image2D(size, size.iota2.map!generator); }
auto image2D(T)(int width, int height, T delegate(ivec2) generator){ return image2D(ivec2(width, height), generator); }


struct Image(E, int N)  // copied from dlang opSlice() documentation
{
  static assert(N == 2);

  alias ImageType = typeof(this);
  alias ElementType = E;
  enum Dimension = N;

  static if(N>1) Vector!(int, N) size; //todo: it's not 1D compatible.  Vector!(T, 1) should be equal to an alias=T.  In Bounds as well.
            else int size;

  int stride;
  // here 4 bytes extra data can fit: a change-hash for example
  E[] impl;

  // size properties
  static foreach(i, name; ["width", "height", "depth"].take(N))
    mixin("ref auto @(){ return size[#]; }  auto @() const { return size[#]; }"
          .replace("@", name).replace("#", i.text) );

  this(in ivec2 size, E[] initialData = []) { //from array
    this.size = size;
    stride = size.x;
    impl = initialData;
    impl.length = size[].product;
  }

  // these returning single arrays / maps of arrays
  auto row(int y)   { return impl[stride*y .. stride*y + width]; }
  auto rows()       { return height.iota.map!(y => row(y)); }

  auto column(int x) const { return height.iota.map!(y => cast(E)(impl[stride*y + x])).array; } //cast needed to remove constness
  auto columns() const { return width.iota.map!(x => column(x)); }

  void regenerate(E delegate(ivec2) generator){ impl = size.iota2.map!generator.array; }

  auto dup(string op="")() const{
    return Image!(E, N)(size, height.iota.map!(i => mixin(op, "impl[i*stride..i*stride+width].dup[]")).join); //todo:2D only
    //todo: optimize for stride==width case
    //todo: check if dup.join copies 2x or not.
  }

  // Index a single element, e.g., arr[0, 1]
  ref E opIndex(int i, int j) { return impl[i + stride*j]; }

  // Array slicing, e.g., arr[1..2, 1..2], arr[2, 0..$], arr[0..$, 1].
  auto opIndex(int[2] r1, int[2] r2){
    ImageType result;

    auto startOffset = r1[0] + r2[0]*stride;
    auto endOffset = r1[1] + (r2[1] - 1)*stride;
    result.impl = this.impl[startOffset .. endOffset];

    result.stride = this.stride;
    result.width  = r1[1] - r1[0];
    result.height = r2[1] - r2[0];

    return result;
  }
  auto opIndex(int[2] r1, int j) { return opIndex(r1, [j, j+1]); }
  auto opIndex(int i, int[2] r2) { return opIndex([i, i+1], r2); }

  // Support for `x..y` notation in slicing operator for the given dimension.
  int[2] opSlice(size_t dim)(int start, int end) if (dim >= 0 && dim < 2)
  in { assert(start >= 0 && end <= this.opDollar!dim); }
  body {
    return [start, end];
  }

  // Support `$` in slicing notation, e.g., arr[1..$, 0..$-1].
  @property int opDollar(size_t dim : 0)() { return width; }
  @property int opDollar(size_t dim : 1)() { return height; }

  // Index/Slice assign

  private void assignHorizontal(string op, A)(A a, int[2] r1, int j) { // todo: tesztelni az optimizalt eredmenyt, ha ezt kivaltom az assignRectangular-al.
    const ofs = j*stride;
    static if(!isInputRange!A) const casted = cast(E) a;
    foreach(ref val; impl[ofs+r1[0]..ofs+r1[1]]){
      static if(!isInputRange!A){
        mixin("val", op, "= casted;");
      }else{
        if(a.empty) return;
        mixin("val", op, "= cast(E) a.front;");
        a.popFront;
      }
    }
  }

  private void assignVertical(string op, A)(A a, int i, int[2] r2) {
    auto ofs = i + r2[0]*stride;
    static if(!isInputRange!A) const casted = cast(E) a;
    foreach(_; r2[0]..r2[1]){
      static if(!isInputRange!A){
        mixin("impl[ofs]", op, "= casted;");
      }else{
        if(a.empty) return;
        mixin("impl[ofs]", op, "= cast(E) a.front;");
        a.popFront;
      }
      ofs += stride;
    }
  }

  /*private void clampx(ref int x){ x = x.clamp(0, width -1); }
  private void clampy(ref int y){ y = y.clamp(0, height-1); }
  private void clampx(ref int[2] x){ x[0].clampx; x[1].clampx; }
  private void clampy(ref int[2] y){ y[0].clampy; y[1].clampy; }*/

  private void assignRectangular(string op, A)(A a, int[2] r1, int[2] r2){
    static if(isImage2D!A){
      minimize(r1[1], r1[0]+a.width );  const w = r1[1]-r1[0]; //adjust slice to topLeft if the source is smaller
      minimize(r2[1], r2[0]+a.height);  const h = r2[1]-r2[0];

      auto dstOfs = r1[0] + r2[0]*stride,  srcOfs = 0;

      foreach(j; 0..h){
        foreach(i; 0..w)
          mixin("impl[dstOfs+i]", op, "= cast(E) a.impl[srcOfs+i];");

        srcOfs += a.stride;  dstOfs += stride;
      }
    }else static if(isInputRange!A){ //fill with continuous range. Break on empty.
      const w = r1[1]-r1[0];
      const h = r2[1]-r2[0];

      auto dstOfs = r1[0] + r2[0]*stride;

      foreach(j; 0..h){
        foreach(i; 0..w){
          if(a.empty) return;
          mixin("impl[dstOfs+i]", op, "= cast(E) a.front;");
          a.popFront;
        }
        dstOfs += stride;
      }

    }else{ // single value
      foreach(j; r2[0]..r2[1])
        assignHorizontal!op(a, r1, j);
    }
  }

  void opIndexAssign(A)(in A a, int i, int j){
    static if(isImage2D!A){ //simplified way to copy an image. dst[3, 5] = src.
      this[i..min($, i+a.width), j..min($, j+a.height)] = a;
    }else{
      opIndex(i, j) = cast(E) a;
    }
  }

  void opIndexAssign(A)(in A a, int[2] r1, int     j){ assignHorizontal !""(a, r1,  j); }
  void opIndexAssign(A)(in A a, int     i, int[2] r2){ assignVertical   !""(a,  i, r2); }
  void opIndexAssign(A)(in A a, int[2] r1, int[2] r2){ assignRectangular!""(a, r1, r2); }
  void opIndexAssign(A)(in A a                      ){ this[0..$, 0..$] = a; }

  void opIndexAssign(string op, A)(in A a, int     i, int     j){ mixin("this[i, j]", op, "= a;"); }
  void opIndexAssign(string op, A)(in A a, int[2] r1, int     j){ assignHorizontal !op(a, r1,  j); }
  void opIndexAssign(string op, A)(in A a, int     i, int[2] r2){ assignVertical   !op(a,  i, r2); }
  void opIndexAssign(string op, A)(in A a, int[2] r1, int[2] r2){ assignRectangular!op(a, r1, r2); }
  void opIndexAssign(string op, A)(in A a                      ){ mixin("this[0..$, 0..$]", op, "= a;"); }

  // Index/Slice unary ops. All const, so no ++ and -- support.
  auto opIndexUnary(string op)(int     i, int     j) const { return mixin(op, "this[i, j]"); }
  auto opIndexUnary(string op)(int[2] r1, int     j) const { return this[r1[0]..r1[1], j           ].dup!op; }
  auto opIndexUnary(string op)(int     i, int[2] r2) const { return this[i           , r2[0]..r2[1]].dup!op; }
  auto opIndexUnary(string op)(int[2] r1, int[2] r2) const { return this[r1[0]..r1[1], r2[0]..r2[1]].dup!op; }
  auto opIndexUnary(string op)() const { return mixin(op, "this[0..$, 0..$]"); }
}


private void unittest_Image(){
  {// various image constructors
    assert(image2D(2, 2, [1, 2, 3], -1).rows.equal([[1,2],[3,-1]])); //size = 2x2, default fill value = -1
    assert(__traits(compiles, image2D(2, 2, [clRed, clGreen, clBlue].dup, clYellow)));
  }

  auto img = image2D(4, 3, [ 0, 1,  2,  3,
                             4, 5,  6,  7,
                             8, 9, 10, 11 ]);

  assert(img.width == 4 && img.height == 3);

  // indexing: img[x, y]
  assert([img[0,0], img[$-1, 0], img[$-1, $-1]] == [0, 3, 11]);

  // slicing, rows(), columns() access
  assert(img[1, 1..$].rows.array == [[5], [9]] && img[0..$, 2].rows.equal([[8, 9, 10, 11]])); //vert/horz slice
  assert(img[2..$, 1..$].rows.join == [6, 7, 10, 11]); // rectangular slice
  assert(img[2..3, 0..$].columns.array == [[2, 6, 10]]);

  // some calculations on arrays:
  assert(img.columns.map!sum.equal([12, 15, 18, 21]));
  assert(img.rows.map!sum.equal([6, 22, 38]));

  // opIndexAssign tests
  auto saved = img.dup; //dup test
  img[0, 0..$] = 0;  img[$-1, 0..$] = 0; //columns
  img[0..$, 0] = 0;  img[0..$, $-1] = 0; //rows
  img[0..2, 0..3] = 9; //rect
  img[$-1, $-1] = 8; //point
  assert(img.rows.equal([[9,9,0,0], [9,9,6,0], [9,9,0,8]]));
  img = saved;

  // various flips
  assert(image2D(img.columns).rows.equal([[0,4,8],[1,5,9],[2,6,10],[3,7,11]])); //diagonal flip
  assert(image2D(img.rows.map!retro).rows[0].equal([3,2,1,0])); //horizontal flip
  assert(image2D(img.rows.retro).columns[0].equal([8,4,0])); //vertical flip

  // updating slices with slices


/*


    auto subImg = img[5..20, 10..30];
    foreach(y; 0..subImg.height)
      foreach(x; 0..subImg.width)
        subImg[x, y] = (x^y)&4 ? '.' : ' ';

    //draw a border
    subImg[0  , 0..$] = '|'; subImg[$-1, 0..$] = '|';
    subImg[0..$, 0  ] = '-'; subImg[0..$, $-1] = '-';

    //fill a subRect
    subImg[2..$-2, 2..5] = '@';
    subImg[4..$, 2] = "Hello World...";
    subImg[2, 4..$] = "Hello World...";

    subImg[3..6, 4..6] = "123456";  // contiguous fill
    subImg[10..13, 4..6] = '~';     // constant fill
    subImg[10..15, 15..20] = subImg[0..5-1, 0..5+1]; //copy rectangle
    subImg[10, 10] = subImg[0..4, 0..5]; // also copy rectangle. Size is taken form source image

    // display the image (it's upside down)
    img.rows.retro.each!writeln;   */

}

void main(){ import het.utils; het.utils.application.runConsole({ //! Main ////////////////////////////////////////////
  het.math.unittest_main;
  unittest_Image;

  if(1) foreach(frame; 0..100000){
    writeln;

    iTime = frame*0.1;

    iResolution = vec2(80, 60);
    auto invAspect = vec2(.5, 1); // textmode chars are 2x taller

    // create the image in memory
    auto img = image2D((iResolution / invAspect).itrunc, (p){
      // call the shadertoy shader
      vec2 fragCoord = p * invAspect;
      vec4 fragColor;
      mainImage(fragColor, fragCoord);

      // transform color to grayscale ascii
      return fragColor.toGrayscaleAscii;
    });

    auto subImg = img[5..20, 10..30];
    foreach(y; 0..subImg.height)
      foreach(x; 0..subImg.width)
        subImg[x, y] = (x^y)&4 ? '.' : ' ';

    //draw a border
    subImg[0  , 0..$] = '|'; subImg[$-1, 0..$] = '|';
    subImg[0..$, 0  ] = '-'; subImg[0..$, $-1] = '-';

    //fill a subRect
    subImg[2..$-2, 2..5] = '@';
    subImg[4..$, 2] = "Hello World...";
    subImg[2, 4..$] = "Hello World...";

    subImg[3..6, 4..6] = "123456";  // contiguous fill
    subImg[10..13, 4..6] = '~';     // constant fill
    subImg[10..15, 15..20] = subImg[0..5-1, 0..5+1]; //copy rectangle
    subImg[10, 10] = subImg[0..4, 0..5]; // also copy rectangle. Size is taken form source image

    // display the image (it's upside down)
    img.rows.retro.each!writeln;

    break;
  }

}); }
