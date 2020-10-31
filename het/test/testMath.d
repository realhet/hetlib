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

//! Image ///////////////////////////////////////////////////////////////

enum isImage(A) = is(A.ImageType);

template ImageDimension(A){
  static if(isImage!A) enum ImageDimension = A.Dimension;
  else                 enum ImageDimension = 0;
}

enum isImage1D(A) = ImageDimension!A == 1;
enum isImage2D(A) = ImageDimension!A == 2;
enum isImage3D(A) = ImageDimension!A == 3;

// tells the elementType of an 1D range.  Returns void if can't.
template ElementType1D(R){
  static if(!isVector!R) alias ElementType1D = ElementType!R;
                    else alias ElementType1D = void;
}

template ElementType2D(R){
  alias T = ElementType1D!R;
  static if(!is(T==void) && !isVector!T) alias ElementType2D = ElementType!T;
                                    else alias ElementType2D = void;
}

template ElementType3D(R){
  alias T = ElementType2D!R;
  static if(!is(T==void) && !isVector!T) alias ElementType3D = ElementType!T;
                                    else alias ElementType3D = void;
}

template RangeDimension(R){
       static if(!is(ElementType3D!R == void)) enum RangeDimension = 3;
  else static if(!is(ElementType2D!R == void)) enum RangeDimension = 2;
  else static if(!is(ElementType1D!R == void)) enum RangeDimension = 1;
  else                                         enum RangeDimension = 0;
}

template InnerElementType(R){
       static if(RangeDimension!R==3) alias InnerElementType = ElementType3D!R;
  else static if(RangeDimension!R==2) alias InnerElementType = ElementType2D!R;
  else static if(RangeDimension!R==1) alias InnerElementType = ElementType1D!R;
  else                                alias InnerElementType = R;
}

private void unittest_ImageElementType() {
  static assert(is(ElementType1D!(RGB  ) == void));
  static assert(is(ElementType1D!(RGB[]) == RGB));

  static assert(is(ElementType2D!(RGB[]  ) == void));
  static assert(is(ElementType2D!(RGB[][]) == RGB));

  static assert(is(ElementType3D!(RGB[][]  ) == void));
  static assert(is(ElementType3D!(RGB[][][]) == RGB));

  alias Types = AliasSeq!(RGB, RGB[], RGB[][], RGB[][][]);
  static foreach(i, T; Types){
    static assert(RangeDimension!T == i);
    static assert(is(InnerElementType!T == RGB));
  }
}

private auto maxImageSize2D(A...)(A args){
  auto res = ivec2(0);
  void extendSize(ivec2 act){ maximize(res, act); }

  static foreach(a; args){{
    alias T = Unqual!(typeof(a));
    alias E = ElementType2D!T;
    static if(isImage2D!T){ //an actual 2D image
      extendSize(a.size);
    }else static if(!is(E==void)){ //nested 2D array
      extendSize(ivec2(a.map!(a => a.length.to!int).maxElement, a.length));
    }else{
      extendSize(ivec2(1)); // a single pixel
    }
  }}
  return res;
}

private void enforceImageSize2D(A...)(in ivec2 size, A args){
  static foreach(a; args){{
    alias T = Unqual!(typeof(a));
    static if(isImage2D!T){ //an actual 2D image
      enforce(a.size == size, "Image size mismatch");
    } //other types are clipped or used as uniform
  }}
}

private auto getDefaultArg(T, A...)(A a){ //gets a default if can, ensures that the type is T
  static if(A.length>=1) return cast(T) a[0];
                    else return T.init;
}

private auto image2DfromRanges(R, D...)(in ivec2 size, R range, D def){
  static assert(D.length<=1, "too many args. Expected a multidimensional range and optionally a default.");

  // try to get an image from 1D or 2D ranges
  enum Dim = RangeDimension!R;
  static if(Dim.among(1, 2)){
    alias T = InnerElementType!R;
    Unqual!T filler = getDefaultArg!T(def); //Unqual needed for padRight
    static if(Dim == 2) auto arr = std.range.join( range.take(size.y).map!(a => a.padRight(filler, size.x).array) );
                   else auto arr = range.array;
    arr = arr.padRight(filler, size[].product).array;
    return Image!(T, 2)(size, arr);
  }else static assert(0, "invalid args");
}

auto image2D(alias fun="", A...)(A args){  // image2D constructor //////////////////////////////////
  static assert(A.length>0, "invalid args");

  static if(A.length>=2 && is(Unqual!(A[0])==int) && is(Unqual!(A[1])==int)){ // Starts with 2 ints: width, height
    return image2D!fun(ivec2(args[0], args[1]), args[2..$]);

  }else static if(is(Unqual!(A[0])==ivec2)){ // Starts with known ivec2 size
    ivec2 size = args[0];

    static assert(A.length>1, "not enough args");

    alias funIsStr = isSomeString!(typeof(fun));

    static if(funIsStr && fun==""){ //default behaviour: one bitmap, optional default
      alias R = A[1];
      static if(RangeDimension!R.among(1, 2)){
        return image2DfromRanges(size, args[1..$]); //1D, 2D range
      }else{
        static assert(A.length<=2, "too many args");
        static if(__traits(compiles, args[1](size))){ // delegate or function (ivec2)
          alias RT = ReturnType!R;
          static if(is(RT == void)){ //return is void, just call the delegate.
            foreach(pos; size.iota2) args[1](pos);
            return; // the result is void
          }else{
            return Image!(RT, 2)(size, size.iota2.map!(p => args[1](p)).array); //return tupe is something, make an Image out of it.
          }
        }else{ // non-callable
          return Image!(R, 2)(size, [cast()(args[1])].replicate(size[].product)); // one pixel stretched all over the size
        }
      }
    }else{ // fun is specified
      enforceImageSize2D(size, args[1..$]);

      return image2D(size, (ivec2 pos){

        // generate all the access functions
        static auto importArg(T)(int i){
          string index;
          static if(isImage2D!T) index = "[pos.x, pos.y]";
          return format!"auto ref %s(){ return args[i+1]%s; }"(cast(char)('a'+i), index);
        }
        static foreach(i, T; A[1..$]) mixin( importArg!T(i) );

        static if(funIsStr){
          enum isStatement = fun.strip.endsWith(';');
          static if(isStatement){
            mixin(fun); //note: if the fun has a return statement, it will make an image. Otherwise return void.
          }else{
            return mixin(fun);
          }
        }else{
          return mixin("fun(", (A.length-1).iota.map!(i => (cast(char)('a'+i)).to!string).join(","), ")");
        }
      });
    }

  }else{ // automatically calculate size from args
    return image2D!fun(maxImageSize2D(args), args);
  }
}


struct Image(E, int N)  // Image struct //////////////////////////////////
{ //copied from dlang opSlice() documentation
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

  auto toString() const{
    static if(N==1) return format!"image1D(%s)"(impl);
    else static if(N==2) return "image2D([\n" ~ rows.map!(r => "  " ~ r.text).join(",\n") ~ "\n])";
    else static assert(0, "not impl");
  }

  // these returning single arrays / maps of arrays
  auto row(int y)    const { return impl[stride*y .. stride*y + width]; }
  auto row(int y)          { return impl[stride*y .. stride*y + width]; }

  auto rows()        const { return height.iota.map!(y => row(y)); }
  auto rows()              { return height.iota.map!(y => row(y)); }

  auto column(int x) const { return height.iota.map!(y => cast(E)(impl[stride*y + x])).array; } //cast needed to remove constness
  auto columns()     const { return width.iota.map!(x => column(x)); }

  void regenerate(E delegate(ivec2) generator){ impl = size.iota2.map!generator.array; }

  @property auto asArray(){
    if(size.x==stride) return impl[];
                  else return rows.array.join;
  }

  @property void asArray(A)(A a){
    this[0, 0] = image2D(size, a); //creates a same size image from 'a' and copies it into itself.
  }

  auto dup(string op="")() const { //optional predfix op
    static if(op==""){
      return Image!(E, N)(size, height.iota.map!(i => impl[i*stride..i*stride+width].dup).join); //todo:2D only
      //todo: optimize for stride==width case
      //todo: check if dup.join copies 2x or not.
    }else{
      auto tmp = this.dup;
      foreach(ref a; tmp.impl) a = cast(E) (mixin(op, "a")); //transform all the elements manually
      return tmp;
    }
  }

  // Index a single element, e.g., arr[0, 1]
  ref E opIndex(int i, int j) { return impl[i + stride*j]; }
  E opIndex(int i, int j) const { return impl[i + stride*j]; }

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

  auto opSlice(){ return this; }

  // Support `$` in slicing notation, e.g., arr[1..$, 0..$-1].
  @property {
    static if(N==1) int opDollar(size_t dim : 0)() { return size;    }
               else int opDollar(size_t dim : 0)() { return size[0]; }
    static if(N>=2) int opDollar(size_t dim : 1)() { return size[1]; }
    static if(N>=3) int opDollar(size_t dim : 2)() { return size[2]; }
  }

  // Index/Slice assign

  /*private void clampx(ref int x){ x = x.clamp(0, width -1); }
  private void clampy(ref int y){ y = y.clamp(0, height-1); }
  private void clampx(ref int[2] x){ x[0].clampx; x[1].clampx; }
  private void clampy(ref int[2] y){ y[0].clampy; y[1].clampy; }*/


  private void assignHorizontal(string op, A)(A a, int[2] r1, int j) { // todo: optimizalasi kiserlet: tesztelni az optimizalt eredmenyt, ha ezt kivaltom az assignRectangular-al.
    static if(isImage2D!A){
      return assignHorizontal!op(a.rows.join, r1, j);
    }else{
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
  }

  private void assignVertical(string op, A)(A a, int i, int[2] r2) {
    static if(isImage2D!A){
      return assignVertical!op(a.rows.join, i, r2);
    }else{

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
  }

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

  void opIndexAssign(A)(A a, int i, int j){
    static if(isImage2D!A){ //simplified way to copy an image. dst[3, 5] = src.
      this[i..min($, i+a.width), j..min($, j+a.height)] = a;
    }else static if(RangeDimension!A == 1){ // insert a line
      foreach(x; i..width){
        if(a.empty) break;
        opIndex(x, j) = cast(E) a.front;
        a.popFront;
      }
    }else{ // set a pixel
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

  // Index/Slice unary ops. All non-const, I don't wanna suck with constness
  auto opIndexUnary(string op)(int     i, int     j) { return mixin(op, "this[i, j]"); }
  auto opIndexUnary(string op)(int[2] r1, int     j) { return this[r1[0]..r1[1], j           ].dup!op; }
  auto opIndexUnary(string op)(int     i, int[2] r2) { return this[i           , r2[0]..r2[1]].dup!op; }
  auto opIndexUnary(string op)(int[2] r1, int[2] r2) { return this[r1[0]..r1[1], r2[0]..r2[1]].dup!op; }
  auto opIndexUnary(string op)(                    ) { return mixin(op, "this[0..$, 0..$]"); }

  auto opIndexBinary(string op, A)(other A) { return mixin(op, "this[0..$, 0..$]"); }

  // operations on the whole image
  auto opUnary(string op)(){ return mixin(op, "this[]"); }

  auto opBinary(string op, bool reverse=false, A)(A a){ //todo: refactor this in the same way as generateVector()
    static if(isImage2D!A){
      alias T = Unqual!(typeof(mixin("this[0,0]", op, "a[0,0]")));
      if(a.size == size){ // elementwise operations
        return image2D(size, (ivec2 p){
          return reverse ? mixin("a   [p.x, p.y]", op, "this[p.x, p.y]")
                         : mixin("this[p.x, p.y]", op, "a   [p.x, p.y]"); //opt: too much index calculations
        });
      }else enforce(0, "incompatible image size");
    }else{ //single element
      alias T = Unqual!(typeof(mixin("this[0,0]", op, "a")));
      return image2D(size, (ivec2 p){
        return reverse ? mixin("a"             , op, "this[p.x, p.y]")
                       : mixin("this[p.x, p.y]", op, "a"             ); //opt: too much index calculations
      });
    }
  }

  auto opBinaryRight(string op, A)(A a){ return opBinary!(op, true)(a); }

  bool opEquals(A)(in A a) const{
    static assert(isImage2D!A);
    return (size == a.size) && size.iota2.map!(p => this[p.x, p.y] == a[p.x, p.y]).all;
  }

  private int myOpApply(string payload, DG)(DG dg){
    int result = 0, lineOfs = 0;
    outer: foreach(y; 0..height){
      foreach(x; 0..width){
        result = mixin(payload);
        if (result) break outer;
      }
      lineOfs += stride;
    }
    return result;
  }

  int opApply(int delegate(int x, int y, ref E) dg)  { return myOpApply!"dg(x, y, impl[lineOfs+x])"(dg); }
  int opApply(int delegate(ivec2 pos   , ref E) dg)  { return myOpApply!"dg(ivec2(x, y), impl[lineOfs+x])"(dg); }
  int opApply(int delegate(ref E) dg)                { return myOpApply!"dg(impl[lineOfs+x])"(dg); }
  /+int opApply(int delegate(E) dg) const              { return myOpApply!"dg(impl[lineOfs+x])"(dg); }+/ //todo: Not gonna suck with constness now...
}


private void unittest_Image(){  // image2D tests /////////////////////////////////
  {// various image constructors
    assert(image2D(2, 2, [1, 2, 3], -1).rows.equal([[1,2],[3,-1]])); //size = 2x2, default fill value = -1
    assert(image2D(2, 2, [[1, 2], [3,-1]]).rows.equal([[1,2],[3,-1]])); //size = 2x2, 2D range
    assert(image2D([[1, 2], [3]], -1).rows.equal([[1,2],[3,-1]])); //size = automatic, 2D range, default fill value = -1
    assert(image2D(2, 1, clRed) == image2D(2, 1, [clRed], clRed));
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
  img[] = 1; //fill all
  img[0..$, $-1] = [1, 2, 3, 4]; //set the bottom line to an array
  img[2, 0..$] = -img[2, 0..$]; //flip the sign of 3rd column
  img[0..$, 2] = -img[0..$, 2]; //flip the sign of last row
  img[0..2, 0..2] = -img[0..2, 0..2]; //flip a rectangular area
  img = -img[];
  assert(img == image2D([ [1, 1, 1, -1], [1, 1, 1, -1], [1, 2, -3, 4] ]));

  // test opBinary
  img[0,0..$] = img[0,0..$] + 10;
  img = img + 100;
  img[0,0] = -img[2..4, 1..3]/2; //copy subimage. The destination can be a point too, not just a slice
  img = 500-img;
  assert(img == image2D([ [550, 549, 399, 401], [548, 552, 399, 401], [389, 398, 403, 396] ]));
  assert(img[0..1, 0..1]*0.25f == image2D(1, 1, (float[]).init, 137.5f));

  { //insert rows/columns at a specific location
    auto i1 = image2D(2, 2, [1, 2, 3, 4]);
    i1[0, 0] = [5, 6];                  assert(i1 == image2D(2, 2, [5, 6, 3, 4]));
    i1[1, 0] = image2D(1, 2, [7, 8]);   assert(i1 == image2D(2, 2, [5, 7, 3, 8]));
    i1[0, 0] = image2D(2, 2, 3);        assert(i1 == image2D(2, 2, 3));

    //access/modify as array
    assert(i1.asArray.equal([3,3,3,3]));
    i1.asArray[1..3] = [4, 5];    assert(i1.asArray.equal([3,4,5,3])); //if stride==width, it elements can be modified too.
    i1.asArray = [1, 2, 3];       assert(i1.asArray.equal([1,2,3,0])); //set the first 3 elements. The remaining elements will be cleared with T.init.
  }

  assert(is(typeof(img[0..1, 0..1]*0.25f) == Image!(float, 2))); // float promotion
  assert( (){ auto sum = 0; img.each!(a => sum += a); return sum; }() == 5385 ); // .each test

  { //foreach tests
    int sum1; foreach(x, y, ref v; img) sum1 += v+x+y;         assert(sum1 == 5415);
    int sum2; foreach(pos , ref v; img) sum2 += v+pos.x+pos.y; assert(sum2 == 5415);
    int sum3; foreach(      ref v; img) sum3 += v;             assert(sum3 == 5385);
  }

  { // image2D operations
    auto im1 = image2D([[1, 2],[3, 4]]);
    auto im2 = image2D([[4, 3],[2, 1]]);
    const target = image2D([ [11, 12], [12, 11] ]);

    assert(image2D!"min(a, b)+c"(im1, im2, 10) == target); // mixin string function

    const increment = 10;
    assert(image2D!( (a,b) => min(a, b)+increment)(im1, im2) == target); // delegate
    assert(image2D!( (a) => 123)(im1) == image2D(2, 2, 123) ); //return is a const

    //check simple function and delegate
    auto del = (ivec2 pos) { return increment; };
    auto fun = (ivec2 pos) { return cast(const)10; }; //cast because increment is const too
    assert( [image2D(2, 2, fun), image2D(2, 2, del)].map!(i => i == image2D(2,2,10)).all );
  }

  {// delegate with void result: operation on Images
    static assert(is(typeof(image2D(2, 2, (ivec2 pos){ })) == void)); //inside image2D() it produces void results

    auto im1 = image2D(2, 2, (ivec2 p) => (p.x+1) + 10*(p.y+1) );
    auto im3 = im1.dup;
    const im2 = image2D(2, 2, 10 );
    const target = image2D([ [115, 125], [215, 225] ]);

    // minimal delegate form
    image2D!( (ref a, b, c){ a = a*b+c; } ) (im1, im2, 5);  assert(im1 == target);

    // string form, but with an extra return statement.
    assert( image2D!q{ a = a*b+c; return clWhite; } (im3, im2, 5) == image2D(2, 2, clWhite) && im3 == target);
  }

}

void unittest_main(){
  unittest_Image;
  unittest_ImageElementType;
}

void main(){ import het.utils; het.utils.application.runConsole({ //! Main ////////////////////////////////////////////
  het.math.unittest_main;
  unittest_main;

  //application.exit;

  if(1) foreach(frame; 0..100000){
    writeln;

    iTime = frame*0.1;

    iResolution = vec2(80, 60);
    auto invAspect = vec2(.5, 1); // textmode chars are 2x taller

    // create the image in memory
    auto img = image2D((iResolution / invAspect).itrunc, (ivec2 p){
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
