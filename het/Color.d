module het.color;

import het.utils;

auto floatToRgb(T, int N)(in Vector!(T, N) x)  if(is(T == float)) { return Vector!(ubyte, N)(iround(x.clamp(0, 1)*255));  }
auto rgbToFloat(T, int N)(in Vector!(T, N) x)  if(is(T == ubyte)) { return x * (1.0f/255);                                }

/// changes/converts the ComponentType of a color  support float and ubyte, ignores others.
auto convertPixelComponentType(CT, A)(auto ref A a){
  alias ST = ScalarType!A;

       static if(is(ST == ubyte) && is(CT == float)) return a.generateVector!(CT, a => a * (1.0f/255));
  else static if(is(ST == float) && is(CT == ubyte)) return a.generateVector!(CT, a => a * 255       );
  else                                               return a.generateVector!(CT, a => a             );
}

/// converts between different number of color components
auto convertPixelChannels(int DstLen, A)(auto ref A a){
  alias SrcLen = VectorLength!A,
        T      = ScalarType  !A,
        VT     = Vector!(T, DstLen);
  //              Src: L              LA        RGB       RGBA         Dst:
  immutable table = [["a          ", "a.r   ", "a.l   ", "a.l  "],  // L
                     ["VT(a,*)    ", "a     ", "a.l1  ", "a.la "],  // LA
                     ["VT(a,a,a)  ", "a.rrr ", "a     ", "a.rgb"],  // RGB
                     ["VT(a,a,a,*)", "a.rrrg", "a.rgb1", "a    "]]; // RGBA

  enum one = is(T==ubyte) ? "255" : "1"; // * : ubyte alpha, and float alpha is different!!!

  static foreach(i; 1..5) static if(DstLen == i)
    static foreach(j; 1..5) static if(SrcLen == j)
      return mixin(table[i-1][j-1].replace("*", one));

  static assert(VectorLength!(typeof(return)) == DstLen, "DstLen mismatch");
}

// converts a color to another color type (different channels and type)
auto convertPixel(B, A)(auto ref A a){
  alias DstType = ScalarType  !B,
        DstLen  = VectorLength!B;

  return a.convertPixelComponentType!DstType     // 2 step conversion: type and channels
          .convertPixelChannels!DstLen;
}

auto hsvToRgb(A)(in A val) if(isColor!A){
  static if(A.length==4){
    return A(val.rgb.hsvToRgb, val.a); // preserve alpha
  }else{
    static if(is(A.ComponentType == float)) return hsvToRgb(val.x, val.y, val.z);
                                       else return val.rgbToFloat.hsvToRgb.floatToRgb;
  }
}

auto hsvToRgb(float H, float S, float V){ //0..1 range
  int sel;
  auto mod = modf(H * 6, sel),
       a = vec4(V,
                V * (1 - S),
                V * (1 - S * mod),
                V * (1 - S * (1 - mod)));
  switch(sel){
    case  0: return a.xwy;
    case  1: return a.zxy;
    case  2: return a.yxw;
    case  3: return a.yzx;
    case  4: return a.wyx;
    case  5: return a.xyz;
    default: return a.xwy;
  }
}


auto toGrayscale(T, N)(in Vector!(T, N) x)
{
       static if(N==3) return x.lll;
  else static if(N==4) return x.llla;
  else                 return x;
}

char toGrayscaleAscii(float luma){
  immutable charMap = " .:-=+*#%@";
  return charMap[luma.quantize!(charMap.length)];
}



// RGB formats ////////////////////////////////////////////////

/+alias RGB = RGB8, RGBA = RGBA8;

RGB  BGR (uint a){ auto c = RGB (a); c.rbSwap; return c; }
RGBA BGRA(uint a){ auto c = RGBA(a); c.rbSwap; return c; }

auto inverse(in RGB  a){ return RGB (a.r^255, a.g^255, a.b^255     ); }
auto inverse(in RGBA a){ return RGBA(a.r^255, a.g^255, a.b^255, a.a); }

private ubyte f2b(float f){ return cast(ubyte)((f.clamp(0, 1)*255.0f).iround); }
private float b2f(int b){ return b*(1/255.0f); }
private ubyte _rgb_to_l_fast(in ubyte[3] rgb)       { return cast(ubyte)((rgb[0]+(rgb[1]<<1)+rgb[2])>>2); }
private float _rgbf_to_l(in float[3] comp)      { return comp[0]*0.299f + comp[1]*0.586f + comp[2]*0.114f; }

private mixin template ColorMembers(){
  @jsonize this(in typeof(comp) array){ comp = array; }

  auto l8   () const { return L8   ([l         ]); }
  auto la8  () const { return LA8  ([l, a      ]); }
  auto rgb8 () const { static if(is(typeof(this)==RGB8 )) return this; else return RGB8 ([r, g, b   ]); }
  auto bgr8 () const { return RGB8 ([b, g, r   ]); }
  auto rgba8() const { static if(is(typeof(this)==RGBA8)) return this; else return RGBA8([r, g, b, a]); }
  auto bgra8() const { return RGBA8([b, g, r, a]); }

  auto lf   () const { return Lf   ([l         ]); }
  auto laf  () const { return LAf  ([l, a      ]); }
  auto rgbf () const { static if(is(typeof(this)==RGBf )) return this; else return RGBf ([r, g, b   ]); }
  auto bgrf () const { return RGBf ([b, g, r   ]); }
  auto rgbaf() const { static if(is(typeof(this)==RGBAf)) return this; else return RGBAf([r, g, b, a]); }
  auto bgraf() const { return RGBAf([b, g, r, a]); }

  void rbSwap(){ auto t=r; r=b; b=t; }

  T to(T)() const if(is(T==L8   )){ return l8   ; }
  T to(T)() const if(is(T==LA8  )){ return la8  ; }
  T to(T)() const if(is(T==RGB8 )){ return rgb8 ; }
  T to(T)() const if(is(T==RGBA8)){ return rgba8; }
  T to(T)() const if(is(T==Lf   )){ return lf   ; }
  T to(T)() const if(is(T==LAf  )){ return laf  ; }
  T to(T)() const if(is(T==RGBf )){ return rgbf ; }
  T to(T)() const if(is(T==RGBAf)){ return rgbaf; }
}

private mixin template Color8Members(){
  mixin ColorMembers;
}

private mixin template ColorFMembers(){
  mixin ColorMembers;
}

/*struct L8{ align(1): @jsonize ubyte[1] comp; mixin Color8Members;
  @jsonize this(in typeof(comp) array){ comp = array; }
  this(in float[comp.length] a){ this(a[0]); }
  this(in float[] a){ enforce(a.length==comp.length); this(a[0]); }

  this(int data) { comp[0] = cast(ubyte)data; }
  this(float luminance) { comp[0] = f2b(luminance); }

  //access
  @property{ ubyte l() const { return comp[0]; } void l(ubyte luminance){ comp[0] = luminance; }}
  alias r = l, g = l, b = l;
  @property{ ubyte a() const { return 0xFF; } void a(ubyte alpha) { } }

  @property{ ubyte raw() const { return comp[0]; } void raw(uint x) { this = L8(x); } }
}

struct LA8{ align(1): @jsonize ubyte[2] comp; mixin Color8Members;
  @jsonize this(in typeof(comp) array){ comp = array; }
  this(in float[comp.length] a){ this(a[0], a[1]); }
  this(in float[] a){ enforce(a.length==comp.length); this(a[0], a[1]); }

  this(int data) { comp[0] = cast(ubyte)data; comp[1] = cast(ubyte)(data>>8); }
  this(int luminance, int alpha) { comp[0] = cast(ubyte)luminance; comp[1] = cast(ubyte)alpha; }
  this(float luminance, float alpha) { comp[0] = luminance.f2b; comp[1] = alpha.f2b; }

  //access
  @property{ ubyte l() const { return comp[0]; } void l(ubyte luminance){ comp[0] = luminance; }}
  alias r = l, g = l, b = l;
  @property{ ubyte a() const { return comp[1]; } void a(ubyte alpha){ comp[1] = alpha; }}

  @property{ ushort raw() const { return (cast(ushort[])comp)[0]; } void raw(uint x) { this = LA8(x); } }
}

struct RGB8{ align(1): @jsonize ubyte[3] comp; mixin Color8Members;
  @jsonize this(in typeof(comp) array){ comp = array; }
  this(in float[comp.length] a){ this(a[0], a[1], a[2]); }
  this(in float[] a){ enforce(a.length==comp.length); this(a[0], a[1], a [2]); }

  this(int data) { comp[0] = cast(ubyte)data; comp[1] = cast(ubyte)(data>>8); comp[2] = cast(ubyte)(data>>16); }
  this(int red, int green, int blue) { comp[0] = cast(ubyte)red; comp[1] = cast(ubyte)green; comp[2] = cast(ubyte)blue; }
  this(float red, float green, float blue) { comp[0] = red.f2b; comp[1] = green.f2b; comp[2] = blue.f2b; }

  //access
  @property{ ubyte r() const { return comp[0]; } void r(ubyte red  ){ comp[0] = red  ; }}
  @property{ ubyte g() const { return comp[1]; } void g(ubyte green){ comp[1] = green; }}
  @property{ ubyte b() const { return comp[2]; } void b(ubyte blue ){ comp[2] = blue ; }}
  @property{ ubyte l() const { return _rgb_to_l_fast(comp[0..3]); } void l(ubyte luminance) { comp[0] = comp[1] =comp[2] = luminance; } }
  @property{ ubyte a() const { return 0xFF; } void a(ubyte alpha) { } }

  @property{ uint raw() const { return comp[0] | (comp[1]<<8) | (comp[2]<<16); } void raw(uint x) { this = RGB8(x); } }

  alias rgba8 this; //implicit conversion to rgba8. And that will be converted to uint
}

struct RGBA8{ align(1): @jsonize ubyte[4] comp; mixin Color8Members;
  @jsonize this(in typeof(comp) array){ comp = array; }
  this(in float[comp.length] a){ this(a[0], a[1], a[2], a[3]); }
  this(in float[] a){ enforce(a.length==comp.length); this(a[0], a[1], a [2], a[3]); }

  this(uint data) { comp[0] = cast(ubyte)data; comp[1] = cast(ubyte)(data>>8); comp[2] = cast(ubyte)(data>>16); comp[3] = cast(ubyte)(data>>24); }
  this(int red, int green, int blue, int alpha=255) { comp[0] = cast(ubyte)red; comp[1] = cast(ubyte)green; comp[2] = cast(ubyte)blue; comp[3] = cast(ubyte)alpha; }
  this(float red, float green, float blue, float alpha=1.0f) { comp[0] = red.f2b; comp[1] = green.f2b; comp[2] = blue.f2b; comp[3] = alpha.f2b; }

  this(RGB8 rgb, int alpha=255 ){ comp[0..3] = rgb.comp[0..3]; comp[3] = cast(ubyte)alpha; }
  this(RGB8 rgb, float alpha=1.0f){ comp[0..3] = rgb.comp[0..3]; comp[3] = alpha.f2b; }

  @property{ ubyte r() const { return comp[0]; } void r(ubyte red  ){ comp[0] = red  ; }}
  @property{ ubyte g() const { return comp[1]; } void g(ubyte green){ comp[1] = green; }}
  @property{ ubyte b() const { return comp[2]; } void b(ubyte blue ){ comp[2] = blue ; }}
  @property{ ubyte a() const { return comp[3]; } void a(ubyte alpha){ comp[3] = alpha; }}
  @property{ ubyte l() const { return _rgb_to_l_fast(comp[0..3]); } void l(ubyte luminance) { comp[0] = comp[1] =comp[2] = luminance; } }

  @property{ uint raw() const { return comp[0] | (comp[1]<<8) | (comp[2]<<16) | (comp[3]<<24); } void raw(uint x) { this = RGBA8(x); } }

  alias raw this; //implicit conversion
}

union Lf{ align(1): @jsonize float[1] comp; mixin ColorFMembers;
  @jsonize this(in typeof(comp) array){ comp = array; }
  this(in ubyte[comp.length] a){ this(a[0].b2f); }
  this(in ubyte[] a){ enforce(a.length==comp.length); this(a[0].b2f); }

  this(float luminance) { comp[0] = luminance; }

  //access
  @property{ float l() const { return comp[0]; } void l(float luminance){ comp[0] = luminance; }}
  alias r = l, g = l, b = l;
  @property{ float a() const { return 1.0f; } void a(float alpha) { } }
}

union LAf{ align(1): @jsonize float[2] comp; mixin ColorFMembers;
  @jsonize this(in typeof(comp) array){ comp = array; }
  this(in ubyte[comp.length] a){ this(a[0].b2f, a[1].b2f); }
  this(in ubyte[] a){ enforce(a.length==comp.length); this(a[0].b2f, a[1].b2f); }

  this(float luminance, float alpha) { comp[0] = luminance; comp[1] = alpha; }

  //access
  @property{ float l() const { return comp[0]; } void l(float luminance){ comp[0] = luminance; }}
  alias r = l, g = l, b = l;
  @property{ float a() const { return comp[1]; } void a(float alpha){ comp[1] = alpha; }}
}

struct RGBf{ align(1): @jsonize float[3] comp; mixin ColorFMembers;
  @jsonize this(in typeof(comp) array){ comp = array; }
  this(in ubyte[comp.length] a){ this(a[0].b2f, a[1].b2f, a[2].b2f); }
  this(in ubyte[] a){ enforce(a.length==comp.length); this(a[0].b2f, a[1].b2f, a[2].b2f); }

  this(float red, float green, float blue) { comp[0] = red; comp[1] = green; comp[2] = blue; }

  //access
  @property{ float r() const { return comp[0]; } void r(float red  ){ comp[0] = red  ; }}
  @property{ float g() const { return comp[1]; } void g(float green){ comp[1] = green; }}
  @property{ float b() const { return comp[2]; } void b(float blue ){ comp[2] = blue ; }}
  @property{ float l() const { return _rgbf_to_l(comp); } void l(float luminance) { comp[0] = comp[1] =comp[2] = luminance; } }
  @property{ float a() const { return 1.0f; } void a(float alpha) { } }
}

union RGBAf{ align(1): @jsonize float[4] comp;  mixin ColorFMembers;
  @jsonize this(in typeof(comp) array){ comp = array; }
  this(in ubyte[comp.length] a){ this(a[0].b2f, a[1].b2f, a[2].b2f, a[3].b2f); }
  this(in ubyte[] a){ enforce(a.length==comp.length); this(a[0].b2f, a[1].b2f, a[2].b2f, a[3].b2f); }

  this(float red, float green, float blue, float alpha=1.0f) { comp[0] = red; comp[1] = green; comp[2] = blue; comp[3] = alpha; }

  @property{ float r() const { return comp[0]; } void r(float red  ){ comp[0] = red  ; }}
  @property{ float g() const { return comp[1]; } void g(float green){ comp[1] = green; }}
  @property{ float b() const { return comp[2]; } void b(float blue ){ comp[2] = blue ; }}
  @property{ float l() const { return _rgbf_to_l(comp[0..3]); } void l(float luminance) { comp[0] = comp[1] =comp[2] = luminance; } }
  @property{ float a() const { return comp[3]; } void a(float alpha){ comp[3] = alpha; }}
}

bool isColor8(T)(){ return is(T==   L8)||is(T==LA8)||is(T==RGB8)||is(T==RGBA8); }
bool isColorF(T)(){ return is(T==   Lf)||is(T==LAf)||is(T==RGBf)||is(T==RGBAf); }
bool isColor(T)(){ return isColor8!T || isColorF!T; }

auto lerp(T, U)(in T a, in T b, U t)if(isColor8!T && isIntegral!U){
  T res; int it = (255-t);
  foreach(i; 0..a.comp.length)
    res.comp[i] = cast(ubyte)((a.comp[i]*it + b.comp[i]*t)>>8);
  return res;
}

auto lerp(T, U)(in T a, in T b, U tf)if(isColor8!T && isFloatingPoint!U){
  T res; int t = iround(tf*255),  it = (255-t);
  foreach(i; 0..a.comp.length)
    res.comp[i] = cast(ubyte)((a.comp[i]*it + b.comp[i]*t)>>8);
  return res;
}

auto darken (T, U)(in T a, U f)if(isColor8!T){ return lerp(a, clBlack, f); }
auto lighten(T, U)(in T a, U f)if(isColor8!T){ return lerp(a, clWhite, f); }

auto avg(T)(in T a, in T b)if(isColor8!T){
  T res;
  foreach(i; 0..a.comp.length)
    res.comp[i] = cast(ubyte)((a.comp[i]+b.comp[i]+1)>>1);
  return res;
}

auto avg(T)(in T a, in T b)if(isColorF!T){
  T res;
  foreach(i; 0..a.comp.length)
    res.comp[i] = (a.comp[i]+b.comp[i])*0.5f;
  return res;
}


private auto colorFunct2(T, alias fv)(in T a, in T b)if(isColor8!T){
  T res;
  foreach(i; 0..a.comp.length)
    res.comp[i] = cast(ubyte)fv(a.comp[i], b.comp[i]);
  return res;
}

private auto colorFunct2(T, alias fv)(in T a, in T b)if(isColorF!T){
  T res;
  foreach(i; 0..a.comp.length)
    res.comp[i] = fv(a.comp[i], b.comp[i]);
  return res;
}


auto min    (T)(in T a, in T b)if(isColor8!T || isColorF!T){ return colorFunct2(T, "min")(a, b); }
auto max    (T)(in T a, in T b)if(isColor8!T || isColorF!T){ return colorFunct2(T, "max")(a, b); }
auto absDiff(T)(in T a, in T b)if(isColor8!T || isColorF!T){ return colorFunct2(T, "absDiff")(a, b); }

int sad(T)(in T a, in T b)if(isColor8!T){
  int res = 0;
  foreach(i; 0..a.comp.length)
    res += abs(a.comp[i]-b.comp[i]);
  return res;
}

float sad(T)(in T a, in T b)if(isColorF!T){
  float res = 0;
  foreach(i; 0..a.comp.length)
    res += abs(a.comp[i]-b.comp[i]);
  return res;
} */


/*RGB HSVToRGB(float H, float S, float V){ return RGB(HSVToRGBf(H, S, V)); }

RGBf HSVToRGBf(float H, float S, float V) //0..1 range
{
  if(!S) return RGBf(V,V,V);
  if(!V) return RGBf(0,0,0);

  auto Hval = H * 6,
       sel = ifloor(Hval),
       mod = Hval - sel,
       v1 = V * (1 - S),
       v2 = V * (1 - S * mod),
       v3 = V * (1 - S * (1 - mod));

  switch(sel){
    case 0: return RGBf(V , v3, v1);
    case 1: return RGBf(v2, V , v1);
    case 2: return RGBf(v1, V , v3);
    case 3: return RGBf(v1, v2, V );
    case 4: return RGBf(v3, v1, V );
    case 5: return RGBf(V , v1, v2);
    case 6: return RGBf(V , v3, v1);
    default: return RGBf(1, 0, 1); //impossible
  }
} */

+/

//const test = lerp(RGB8(1,2,3), RGB8(0x808080), 128);

//auto lerp(T)(in T a, in T b, int t)if(is(T==  LA8)){ T res; int it = (255-i); foreach(i; 0..a.comp.length) res.comp[i] = (a.comp[i]*t + b.comp[i]*it)>>8; return res; }
//auto lerp(T)(in T a, in T b, int t)if(is(T== RGB8)){ T res; int it = (255-i); foreach(i; 0..a.comp.length) res.comp[i] = (a.comp[i]*t + b.comp[i]*it)>>8; return res; }
//auto lerp(T)(in T a, in T b, int t)if(is(T==RGBA8)){ T res; int it = (255-i); foreach(i; 0..a.comp.length) res.comp[i] = (a.comp[i]*t + b.comp[i]*it)>>8; return res; }

/*
//this was commented out long ago

struct RGB{
  align(1):
  ubyte r, g, b;
  ubyte a() const { return 0xff; }

  this(uint x){
    r = cast(ubyte)(x    );
    g = cast(ubyte)(x>>8 );
    b = cast(ubyte)(x>>16);
  }

  this(int x){
    this(cast(uint)x);
  }

  this(ubyte r_, ubyte g_, ubyte b_){
    r = r_;  g = g_;  b = b_;
  }

  this(float r_, float g_, float b_){
    r = cast(ubyte)iRound(clamp(r_, 0, 1)*255);
    g = cast(ubyte)iRound(clamp(g_, 0, 1)*255);
    b = cast(ubyte)iRound(clamp(b_, 0, 1)*255);
  }

  float[3] toF()const {
    enum d = 1.0f/255;
    return [r*d, g*d, b*d];
  }

  @property uint raw()const { return r | (g<<8) | (b<<16); }

  RGB fadeTo(const RGB dst, float t)const { return rgbLerp(this, dst, clamp(t, 0, 1)); }
  RGB darker (float t)const { return fadeTo(clBlack, t); }
  RGB lighter(float t)const { return fadeTo(clWhite, t); }
  RGB brighter(float t)const { return lighter(t); }

  //swizzle
  RGB bgr()const { return RGB(b, g, r); }
}


RGB rgbLerp(const RGB a, const RGB b, float t){
  RGB res;
  res.r = cast(ubyte)iLerp(a.r, b.r, t);
  res.g = cast(ubyte)iLerp(a.g, b.g, t);
  res.b = cast(ubyte)iLerp(a.b, b.b, t);
  return res;
}

RGB rgbAvg(const RGB a, const RGB b, float t){ return rgbLerp(a, b, .5); }

int rgbSad(const RGB a, const RGB b){
  int res;
  res += abs((a.r)-(b.r));
  res += abs((a.g)-(b.g));
  res += abs((a.b)-(b.b));
  return res;
}

RGB rgbMax(const RGB a, const RGB b){ return RGB(max(a.r, b.r), max(a.g, b.g), max(a.b, b.b)); }
RGB rgbMin(const RGB a, const RGB b){ return RGB(min(a.r, b.r), min(a.g, b.g), min(a.b, b.b)); }

RGB rainbow_HUE(float H){
  auto h2 = (H-iFloor(H))*8,
       i0 = iTrunc(h2),
       i1 = (i0+1)&7,
       fr = fract(h2);
  RGB clr = rgbLerp(clRainbow[i0], clRainbow[i1], iRemapClamp(fr, 1, 0, 0, 255)); //interpolate rainbow palette
  return clr;
}

RGB HSVToRGB_rainbow(float H, float S, float V){
  auto h2 = (H-iFloor(H))*8,
       i0 = iTrunc(h2),
       i1 = (i0+1)&7,
       fr = fract(h2);
  RGB clr = rgbLerp(clRainbow[i0], clRainbow[i1], iRemapClamp(fr, 1, 0, 0, 255)); //interpolate rainbow palette
  clr = rgbLerp(RGB(0xFFFFFF), clr, iRemapClamp(S, 1, 0, 0, 255)); //saturate
  clr = rgbLerp(RGB(0x000000), clr, iRemapClamp(V, 1, 0, 0, 255)); //darken
enforce(false, "HSVToRGB_rainbow() ez total fos");
  return clr;
}
*/

// color constants ////////////////////////////////////////////////////////////////////////////////////

immutable RGB
//classic delphi palette
  clBlack           = 0x000000,
  clMaroon          = 0x000080,
  clGreen           = 0x008000,
  clOlive           = 0x008080,
  clNavy            = 0x800000,
  clPurple          = 0x800080,
  clTeal            = 0x808000,
  clGray            = 0x808080,
  clSilver          = 0xC0C0C0,
  clRed             = 0x0000FF,
  clLime            = 0x00FF00,
  clYellow          = 0x00FFFF,
  clBlue            = 0xFF0000,
  clFuchsia         = 0xFF00FF,
  clAqua            = 0xFFFF00,
  clLtGray          = 0xC0C0C0,
  clDkGray          = 0x808080,
  clWhite           = 0xFFFFFF,

  clSkyBlue         = 0xF0CAA6,
  clMoneyGreen      = 0xC0DCC0,

//standard vga palette
  clVgaBlack        = 0x000000,
  clVgaDarkGray     = 0x555555,
  clVgaLowBlue      = 0xAA0000,
  clVgaHighBlue     = 0xFF5555,
  clVgaLowGreen     = 0x00AA00,
  clVgaHighGreen    = 0x55FF55,
  clVgaLowCyan      = 0xAAAA00,
  clVgaHighCyan     = 0xFFFF55,
  clVgaLowRed       = 0x0000AA,
  clVgaHighRed      = 0x5555FF,
  clVgaLowMagenta   = 0xAA00AA,
  clVgaHighMagenta  = 0xFF55FF,
  clVgaBrown        = 0x0055AA,
  clVgaYellow       = 0x55FFFF,
  clVgaLightGray    = 0xAAAAAA,
  clVgaWhite        = 0xFFFFFF,

//C64 palette
  clC64Black        = 0x000000,
  clC64White        = 0xFFFFFF,
  clC64Red          = 0x354374,
  clC64Cyan         = 0xBAAC7C,
  clC64Purple       = 0x90487B,
  clC64Green        = 0x4F9764,
  clC64Blue         = 0x853240,
  clC64Yellow       = 0x7ACDBF,
  clC64Orange       = 0x2F5B7B,
  clC64Brown        = 0x00454f,
  clC64Pink         = 0x6572a3,
  clC64DGrey        = 0x505050,
  clC64Grey         = 0x787878,
  clC64LGreen       = 0x8ed7a4,
  clC64LBlue        = 0xbd6a78,
  clC64LGrey        = 0x9f9f9f,

//WOW palette
  clWowGrey         = 0x9d9d9d,
  clWowWhite        = 0xffffff,
  clWowGreen        = 0x00ff1e,
  clWowBlue         = 0xdd7000,
  clWowPurple       = 0xee35a3,
  clWowRed          = 0x0080ff,
  clWowRed2         = 0x80cce5,

//VIM
  clVimBlack        = 0x141312,
  clVimBlue         = 0xDAA669,
  clVimGreen        = 0x4ACAB9,
  clVimTeal         = 0xB1C070,
  clVimRed          = 0x534ED5,
  clVimPurple       = 0xD897C3,
  clVimYellow       = 0x47C5E7,
  clVimWhite        = 0xFFFFFF,
  clVimGray         = 0x9FA19E,
  clVimOrange       = 0x458CE7,

//Rainbow       https://github.com/FastLED/FastLED/wiki/Pixel-reference
/*  clRainbowRed      = 0x0000FF,
  clRainbowOrange   = 0x0055AA,
  clRainbowYellow   = 0x00AAAA,
  clRainbowGreen    = 0x00FF00,
  clRainbowAqua     = 0x55AA00,
  clRainbowBlue     = 0xFF0000,
  clRainbowPurple   = 0xAA0055,
  clRainbowPing     = 0x5500AA,*/

//Rainbow. Distinct colors for the human eye. This is a better version.
  clRainbowRed      = 0x0000FF,
  clRainbowOrange   = 0x0088FF,
  clRainbowYellow   = 0x00EEEE,
  clRainbowGreen    = 0x00FF00,
  clRainbowAqua     = 0xCCCC00,
  clRainbowBlue     = 0xFF0000,
  clRainbowPurple   = 0xFF0088,
  clRainbowPink     = 0x8800FF,

//solarized colors -> https://ethanschoonover.com/solarized/
  clSolBase03       = 0x362b00,
  clSolBase02       = 0x423607,
  clSolBase01       = 0x756e58,
  clSolBase00       = 0x837b65,
  clSolBase0        = 0x969483,
  clSolBase1        = 0xa1a193,
  clSolBase2        = 0xd5e8ee,
  clSolBase3        = 0xe3f6fd,
  clSolYellow       = 0x0089b5,
  clSolOrange       = 0x164bcb,
  clSolRed          = 0x2f32dc,
  clSolMagenta      = 0x8236d3,
  clSolViolet       = 0xc4716c,
  clSolBlue         = 0xd28b26,
  clSolCyan         = 0x98a12a,
  clSolGreen        = 0x009985,

  clAxisX           = RGB(213, 40, 40),
  clAxisY           = RGB(40, 166, 40),
  clAxisZ           = RGB(40, 40, 215),

  clOrange          = clRainbowOrange;

immutable RGB8[]
  clDelphi  = [clBlack, clMaroon, clGreen, clOlive, clNavy, clPurple, clTeal, clGray, clSilver, clRed, clLime, clYellow, clBlue, clFuchsia, clAqua, clLtGray, clDkGray, clWhite],
  clVga     = [clVgaBlack, clVgaLowBlue, clVgaLowGreen, clVgaLowCyan, clVgaLowRed, clVgaLowMagenta, clVgaBrown, clVgaLightGray, clVgaDarkGray, clVgaHighBlue, clVgaHighGreen, clVgaHighCyan, clVgaHighRed, clVgaHighMagenta, clVgaYellow, clVgaWhite],
  clC64     = [clC64Black, clC64White, clC64Red, clC64Cyan, clC64Purple, clC64Green, clC64Blue, clC64Yellow, clC64Orange, clC64Brown, clC64Pink, clC64DGrey, clC64Grey, clC64LGreen, clC64LBlue, clC64LGrey],
  clWow     = [clBlack, clWowGrey, clWowWhite, clWowGreen, clWowBlue, clWowPurple, clWowRed, clWowRed2],
  clVim     = [clVimBlack, clVimBlue, clVimGreen, clVimTeal, clVimRed, clVimPurple, clVimYellow, clVimWhite, clVimGray, clVimOrange],
  clRainbow = [clRainbowRed, clRainbowOrange, clRainbowYellow, clRainbowGreen, clRainbowAqua, clRainbowBlue, clRainbowPurple, clRainbowPink],
  clSol     = [clSolBase03, clSolBase02, clSolBase01, clSolBase00, clSolBase0, clSolBase1, clSolBase2, clSolBase3, clSolYellow, clSolOrange, clSolRed, clSolMagenta, clSolViolet, clSolBlue, clSolCyan, clSolGreen],
  clAxis    = [clAxisX, clAxisY, clAxisZ],
  clAll     = clDelphi ~ clVga ~ clC64 ~ clWow ~ clVim ~ clRainbow ~ clSol;


private RGB colorByName(string name, bool mustExists=false){

  __gshared static RGB[string] map;

  if(map is null){ //todo: user driendly editing of all the colors
    import std.traits;
    static foreach(member; __traits(allMembers, mixin(__MODULE__)))
      static if(is(Unqual!(typeof(mixin(member)))==RGB))
        map[member.withoutStarting("cl").decapitalize] = mixin(member);  //todo: utils

    map.rehash;
  }

  //todo: decapitalize, enforce
  auto a = name.decapitalize in map;
  if(a is null){
    enforce(!mustExists, `Unknown color name "%s"`.format(name));
    return clFuchsia;
  }
  return *a;
}

//toRGB //////////////////////////////////

RGB toRGB(string s, bool mustExists=false){
  s = s.strip;
  enforce(!s.empty, `Empty RGB literal.`);

  //decimal or hex number
  if(s[0].inRange('0', '9')) return RGB(s.toInt);

  //rgb(0,0,255)
  if(s.isWild("*?(*?,*?,*?)"))
    if(wild[0].toUpper.among("RGB", "RGB8"))
      return RGB(wild.ints(1), wild.ints(2), wild.ints(3));

  return colorByName(s, mustExists);
}

unittest{
  assert(toRGB("blue")==RGB(0, 0, 255));
  assert(toRGB("Red").rgbToFloat==vec3(1, 0, 0));
}

//operations //////////////////////////////

//RGB  opBinary(string op : "*")(in RGB a , in RGB b )     { return RGB (a.r*b.r>>8, a.g*b.g>>8, a.b*b.b>>8); }    //todo: nem jo a color szorzas, mert implicit uint konverzio van
//RGBA opBinary(string op : "*")(in RGBA a, in RGBA b)     { return RGBA(a.r*b.r>>8, a.g*b.g>>8, a.b*b.b>>8, a.a*b.a>>8); }


//import std.traits;
//todo: pragma(msg, "Megcsinalni a szinek listazasat traits-al." ~ [__traits(allMembers, het.color)].filter!(s => s.startsWith("cl")).array);

//! ColorMaps //////////////////////////////////////////////////////////////////////////////////////////////

//todo: there should be a bezier interpolated colormap too. RegressionColorMap is so bad for HSV and JET for example.

class ColorMap{
  string name, category;
  int index;

  abstract RGB eval(float x);

  T[] toArray(T=RGB)(int len){
    float invLen = 1.0f/max(len-1, 1);
    return iota(len).map!(i => eval(i*invLen).convertPixel!T).array;
  }
}


class RegressionColorMap: ColorMap{
  double[][3] polys;

  this(string name, string category, double[][3] polys){
    this.name = name;
    this.category = category;
    this.polys = polys;
  }

  override RGB eval(float x){
    x = x.clamp(0, 1);
    return vec3(evalPoly(x, polys[0]), evalPoly(x, polys[1]), evalPoly(x, polys[2])).floatToRgb;
  }
}


class DistinctColorMap: ColorMap{
  RGB[] pal;
  bool isLinear;

  this(string name, string category, int[3][] pal, bool isLinear=false){
    this.name = name;
    this.category = category;
    import std.array : array; import std.algorithm : map; //todo:utils
    this.pal = pal.map!(c => RGB(c[0], c[1], c[2])).array;
    this.isLinear = isLinear;
  }

  override RGB eval(float x){
    if(x<=0) return pal[0];
    if(x>=0.9999) return pal[$-1];

    if(isLinear){
      x *= pal.length-1;
      const i = x.ifloor, fr = x.fract; //todo: modf
      return mix(pal[i], pal[i+1], fr);
    }else{ // nearest
      x *= pal.length;
      return pal[x.ifloor];
    }
  }
}

class ColorMapCategory{
  string name;
  ColorMaps colorMaps;
  alias colorMaps this;

  this(string name){
    this.name = name;
    colorMaps = new ColorMaps;
  }
}

class ColorMapCategories{
  ColorMapCategory[string] byName;
  ColorMapCategory[] byIndex;

  private void add(ColorMap m){
    if(!(m.category in byName)){
      auto cat = new ColorMapCategory(m.category);
      byName[m.category] = cat;
      byIndex ~= cat;
    }
    byName[m.category].colorMaps.add(m);
  }

  @property auto length() const { return byIndex.length; }
  auto opIndex(size_t idx){ return byIndex[idx]; }
  auto opIndex(string name){ return byName[name]; }

  auto opDispatch(string name)(){ return byName[name]; }

  //todo: Range

  int opApply(int delegate(ColorMapCategory) dg){
    int result = 0;
    foreach(c; byIndex){
      result = dg(c);
      if(result) break;
    }
    return result;
  }
}

class ColorMaps{
  ColorMap[string] byName;
  ColorMap[] byIndex;

  ColorMapCategories categories;

  private void add(ColorMap m){
    import std.conv; //utils
    m.index = byIndex.length.to!int;
    byIndex ~= m;
    byName[m.name] = m;
  }

  this(){
    categories = new ColorMapCategories;
  }

  @property auto length() const { return byIndex.length; }
  auto opIndex(size_t idx){ return byIndex[idx]; }
  auto opIndex(string name){ return byName[name]; }

  auto opDispatch(string name)(){ return byName[name]; }

  bool opBinaryRight(string op)(string lhs) const if(op=="in") { return (lhs in byName) !is null; }

  int opApply(int delegate(ColorMap) dg){
    int result = 0;
    foreach(c; byIndex){
      result = dg(c);
      if(result) break;
    }
    return result;
  }
}

class StandardColorMaps : ColorMaps {

  this(){
    initColorMaps((ColorMap m){
      add(m);
      categories.add(m);
    });
  }

  private static void initColorMaps(void delegate(ColorMap) add){
    //Exported from python
    add(new RegressionColorMap("viridis", "Uniform", [[0.2753652,-0.05184015,1.717864,-13.64572,24.0259,-11.33279],[0.01529448,1.245687,-0.1677699,-0.1776745],[0.331099,1.350983,0.6340607,-21.84333,62.08875,-70.69913,28.27274]]));
    add(new RegressionColorMap("plasma", "Uniform", [[0.07050842,1.846171,-0.5688886,-0.3956234],[0.02749319,0.1857873,-7.011921,40.69019,-79.73788,68.91157,-22.09464],[0.5189733,1.480299,-4.612459,3.238719,-0.488916]]));
    add(new RegressionColorMap("inferno", "Uniform", [[0.001327787,0.009644044,12.44225,-44.74039,82.7469,-76.31698,26.83947],[0.01018034,0.07107646,1.393175,-4.544394,8.313788,-4.239053],[0.01324062,1.360481,13.89826,-50.29397,-207.9872,1476.927,-3440.86,3950.336,-2249.96,507.2107]]));
    add(new RegressionColorMap("magma", "Uniform", [[-0.001056089,0.2086954,8.414332,-27.03387,49.82702,-47.92527,17.50701],[-0.01226924,1.697227,-18.85727,103.8391,-282.0351,401.9937,-284.1511,78.51863],[0.02257798,-0.1336941,43.49071,-306.8667,1033.189,-1972.302,2150.426,-1238.54,291.4641]]));
    add(new RegressionColorMap("cividis", "Uniform", [[0.004867613,-1.373322,29.5757,-140.1297,330.4008,-416.7607,269.6471,-70.36864],[0.1407279,0.611976,0.1473766],[0.299587,2.763263,-20.14296,65.65921,-103.2274,77.2379,-22.38728]]));
    add(new RegressionColorMap("Greys", "Sequential", [[1.00188,-0.3776376,-1.076465,0.4515921],[1.00188,-0.3776376,-1.076465,0.4515921],[1.00188,-0.3776376,-1.076465,0.4515921]]));
    add(new RegressionColorMap("Purples", "Sequential", [[0.9943569,-0.3635322,-1.125815,0.7564731],[0.9825725,-0.295309,-1.065359,0.3711998],[1.002707,-0.310729,-0.2172503]]));
    add(new RegressionColorMap("Blues", "Sequential", [[0.9640408,-0.6848032,0.7231472,-6.71995,9.323603,-3.578733],[0.9838041,-0.3983304,-0.4135137],[0.9939348,-0.02735043,-1.362508,2.308459,-1.494721]]));
    add(new RegressionColorMap("Greens", "Sequential", [[0.9708491,-0.6463783,1.410661,-12.11126,23.53188,-19.42088,6.268454],[0.9891632,-0.1683416,-0.5541972],[0.958096,-0.378251,-2.675335,3.800997,-1.608774]]));
    add(new RegressionColorMap("Oranges", "Sequential", [[0.9943825,0.2783882,-3.175885,11.55517,-16.27355,7.119251],[0.9549578,-0.194053,-1.876715,1.278326],[0.9199493,-0.7070352,-1.541605,-2.854956,8.828911,-4.631098]]));
    add(new RegressionColorMap("Reds", "Sequential", [[1.002536,-0.069215,-0.3823209,3.257759,-6.273296,2.873386],[0.9539357,-0.02952599,-7.684742,27.8715,-55.52702,53.66999,-19.26047],[0.9383569,-0.5750223,-3.986057,6.524778,-2.85329]]));
    add(new RegressionColorMap("YlOrBr", "Sequential", [[0.9990683,0.1157627,-1.69745,7.376928,-11.82314,5.431688],[0.9889852,0.1800437,-2.79592,1.782192],[0.905389,-2.151394,16.65872,-109.4322,309.6544,-433.5393,299.8086,-81.88536]]));
    add(new RegressionColorMap("YlOrRd", "Sequential", [[1.007837,-0.1954425,0.7577178,-0.5443974,-0.5385435],[0.9939479,-0.1366723,-4.802413,20.96242,-49.97206,50.96066,-18.00391],[0.8001015,-1.455894,3.507234,-33.01823,125.4178,-215.7354,174.9292,-54.30566]]));
    add(new RegressionColorMap("OrRd", "Sequential", [[1.001049,-0.1257674,0.7040524,-1.092909],[0.9640021,0.3112739,-17.25948,144.7576,-602.6837,1334.988,-1622.694,1021.24,-259.622],[0.9284024,-2.264321,44.3868,-612.9268,4109.246,-15499.49,35194.85,-49094.87,41153.87,-19014.5,3720.767]]));
    add(new RegressionColorMap("PuRd", "Sequential", [[0.9704971,-0.8383752,8.605635,-73.5064,261.8788,-425.6387,319.3959,-90.46502],[0.9605051,-1.646228,34.259,-388.2909,2022.52,-5782.367,9589.64,-9194.954,4732.579,-1012.7],[0.9798234,-0.8971576,15.17699,-142.2227,591.9549,-1285.39,1502.234,-895.1943,213.4742]]));
    add(new RegressionColorMap("RdPu", "Sequential", [[1.002849,-0.1181552,-0.2749962,4.18575,-9.743464,5.245328],[0.9693509,-0.7670555,1.228309,-9.275643,24.5475,-48.529,53.06413,-21.24509],[0.9490611,-0.2347976,-6.583422,29.47778,-55.81673,48.14649,-15.52411]]));
    add(new RegressionColorMap("BuPu", "Sequential", [[0.9614898,-0.2275982,-4.644432,9.768894,-5.569028],[0.9879448,-0.4045968,-1.266799,2.761224,-5.102823,3.028789],[0.9881732,-0.1216244,-1.197505,1.768901,-1.147187]]));
    add(new RegressionColorMap("GnBu", "Sequential", [[0.9644057,-0.6378398,0.706042,-5.228842,6.01205,-1.786668],[0.9921003,-0.4184938,1.111607,-2.795616,1.36238],[0.9390684,0.005097648,-20.46887,242.9244,-1432.469,4626.279,-8487.847,8832.591,-4861.983,1100.536]]));
    add(new RegressionColorMap("PuBu", "Sequential", [[0.9939339,-0.07977941,-6.444068,28.19269,-68.82041,74.17442,-28.01609],[0.9694938,-0.5136097,-0.2334397],[0.9835465,-0.2009541,-0.8581221,1.869981,-1.459495]]));
    add(new RegressionColorMap("YlGnBu", "Sequential", [[1.005623,-1.087432,9.602415,-61.95867,128.1164,-107.7916,32.1362],[0.9955562,0.1169872,-3.348035,8.119295,-11.1324,5.375331],[0.8493738,-0.2583054,-34.73764,406.4949,-2093.879,6014.343,-10210.52,10148.26,-5450.338,1220.136]]));
    add(new RegressionColorMap("PuBuGn", "Sequential", [[1.000965,-1.078253,20.9331,-312.579,2263.668,-9330.651,23051.13,-34760.15,31337.3,-15508.54,3238.97],[0.9589328,-0.3876129,-1.1222,1.920854,-1.090379],[0.9900182,-0.966087,11.14282,-73.81004,230.4158,-361.3102,272.5262,-78.77697]]));
    add(new RegressionColorMap("BuGn", "Sequential", [[0.9718871,-0.9677532,7.603039,-45.79734,96.59922,-88.37143,29.9761],[0.9907807,-0.1667634,-0.5571327],[0.9909846,0.002492409,-1.225382,-1.187381,1.541323]]));
    add(new RegressionColorMap("YlGn", "Sequential", [[0.9968858,0.09135531,-4.241359,14.47433,-54.02978,102.7885,-88.55247,28.48084],[0.9956981,0.0764644,-1.296713,0.4942138],[0.9092246,-2.041375,6.709668,-14.43298,13.52214,-4.501648]]));
    add(new RegressionColorMap("binary", "Sequential2", [[1.001636,-1.003271],[1.001636,-1.003271],[1.001636,-1.003271]]));
    add(new RegressionColorMap("gist_yarg", "Sequential2", [[1.001636,-1.003271],[1.001636,-1.003271],[1.001636,-1.003271]]));
    add(new RegressionColorMap("gist_gray", "Sequential2", [[-0.001635581,1.003271],[-0.001635581,1.003271],[-0.001635581,1.003271]]));
    add(new RegressionColorMap("gray", "Sequential2", [[-0.001635581,1.003271],[-0.001635581,1.003271],[-0.001635581,1.003271]]));
    add(new RegressionColorMap("bone", "Sequential2", [[-0.008784384,1.033052,-0.5934138,0.5744974],[0.01445017,0.5452215,1.153349,-0.7143174],[-0.01195305,1.441361,-0.7421807,0.3133882]]));
    add(new RegressionColorMap("pink", "Sequential2", [[0.1390393,3.118536,-5.619675,5.04288,-1.681207],[0.01460264,3.986171,-20.13017,58.92311,-82.68645,54.79184,-13.89987],[0.01640588,3.910254,-20.16342,65.8281,-113.7587,96.78714,-31.62747]]));
    add(new RegressionColorMap("spring", "Sequential2", [[1,2.26089e-16],[-0.001635581,1.003271],[1.001636,-1.003271]]));
    add(new RegressionColorMap("summer", "Sequential2", [[-0.001635581,1.003271],[0.4991822,0.5016356],[0.4,7.273802e-17]]));
    add(new RegressionColorMap("autumn", "Sequential2", [[1,2.26089e-16],[-0.001635581,1.003271],[0.0,0]]));
    add(new RegressionColorMap("winter", "Sequential2", [[0,0.0],[-0.001635581,1.003271],[1.000818,-0.5016356]]));
    add(new RegressionColorMap("cool", "Sequential2", [[-0.001635581,1.003271],[1.001636,-1.003271],[1,2.26089e-16]]));
    add(new RegressionColorMap("Wistia", "Sequential2", [[0.8916084,0.5771672,-0.9190709,0.445015],[0.9916546,-0.03851729,-1.878249,2.535797,-1.116227],[0.4869933,-1.699644,-0.1424205,6.976584,-9.36134,3.74447]]));
    add(new RegressionColorMap("hot", "Sequential2", [[0.04400761,1.083752,56.45801,-784.6625,5375.45,-20476.3,46209.31,-63473.24,52217.96,-23684.52,4559.427],[-6.53321e-05,0.9390913,-74.63733,2208.389,-33524.43,299934.7,-1707516,6478810,-1.684286e+07,3.039444e+07,-3.80191e+07,3.233357e+07,-1.783785e+07,5757209,-825257.9],[-0.0003722964,2.276648,-175.9221,5189.797,-80745.65,762609.8,-4725671,2.013378e+07,-6.065568e+07,1.311082e+08,-2.039297e+08,2.261388e+08,-1.742948e+08,8.866798e+07,-2.675474e+07,3624977]]));
    add(new RegressionColorMap("afmhot", "Sequential2", [[-0.002352444,2.748123,-31.70079,467.2322,-3371.677,13618.78,-32717.7,47669.99,-41319.84,19605.73,-3922.571],[0.003729495,-1.361162,46.52012,-564.9612,3219.729,-9762.752,16961.76,-16970.37,9093.112,-2020.691],[0.001814115,-0.8352974,32.73938,-473.9859,3400.082,-13694.43,32841.85,-47790.99,41383.98,-19619.98,3922.571]]));
    add(new RegressionColorMap("gist_heat", "Sequential2", [[-0.002489772,1.84508,-9.710313,94.73447,-437.1439,1066.125,-1403.422,937.5674,-248.9978],[0.001814115,-0.8352974,32.73938,-473.9859,3400.082,-13694.43,32841.85,-47790.99,41383.98,-19619.98,3922.571],[-0.0003866005,2.293281,-176.5099,5185.532,-80333.8,755429.7,-4660846,1.977178e+07,-5.931006e+07,1.276571e+08,-1.977326e+08,2.183644e+08,-1.676205e+08,8.493229e+07,-2.552686e+07,3445243]]));
    add(new RegressionColorMap("copper", "Sequential2", [[0.005256354,0.8097105,4.997437,-22.03609,43.80944,-39.26019,12.66606],[-0.001277716,0.7837554],[-0.0008137016,0.4991274]]));
    add(new RegressionColorMap("PiYG", "Diverging", [[0.5454175,3.169233,-14.15834,45.12639,-78.03891,60.07602,-16.55967],[0.004148211,2.067085,-58.47564,912.1992,-5789.504,20114.77,-42292.08,55277.75,-43966.61,19501.64,-3701.379],[0.3202559,2.058512,-16.15093,215.4605,-1265.554,3978.887,-7230.506,7530.652,-4156.031,940.9636]]));
    add(new RegressionColorMap("PRGn", "Diverging", [[0.240665,3.138791,-16.26083,72.05801,-144.6037,121.3134,-35.87999],[-0.0005091017,2.3291,-37.78648,604.3451,-4153.032,15723.82,-35793.2,50138.36,-42316.44,19746.3,-3914.436],[0.2939401,1.908709,9.164541,-110.1134,493.458,-1116.898,1317.244,-776.0007,181.0501]]));
    add(new RegressionColorMap("BrBG", "Diverging", [[0.3259664,2.233975,1.558473,-26.63698,105.6104,-216.5362,199.216,-65.77085],[0.1843412,2.043522,-21.79604,212.9038,-843.1833,1714.476,-1927.045,1137.79,-275.1404],[0.01795185,0.8747753,-25.41493,317.8396,-1754.632,6136.053,-14032.64,20289.43,-17696.58,8477.341,-1712.107]]));
    add(new RegressionColorMap("PuOr", "Diverging", [[0.4870847,2.352066,-1.411496,-4.404916,3.161546],[0.2280941,2.2825,-43.88991,599.0242,-3963.487,15218.1,-35826.81,52125.86,-45614.24,21986.09,-4483.158],[0.03080723,2.743821,-201.9493,5377.307,-73818.09,602661.7,-3160160,1.118069e+07,-2.746009e+07,4.738169e+07,-5.725255e+07,4.743392e+07,-2.566855e+07,8171618,-1160579]]));
    add(new RegressionColorMap("RdGy", "Diverging", [[0.3965083,3.733364,-12.1724,32.82119,-57.16952,46.10805,-13.61791],[-0.001731808,2.361627,-66.23397,988.7644,-6536.244,24368.15,-55283.5,77574.67,-65677.26,30732.9,-6103.506],[0.1219723,-0.2491758,42.94243,-1001.326,11753.99,-76987.47,308856,-795156.7,1338139,-1463609,1002559,-390734.4,66138.04]]));
    add(new RegressionColorMap("RdBu", "Diverging", [[0.4033661,2.082337,38.33317,-577.4216,3778.289,-14055.95,31952.69,-45207.94,38787.46,-18438.68,3720.766],[0.006171795,0.01472633,11.94421,-10.58839,-34.82899,60.42811,-30.1175,3.326138],[0.1192284,1.958517,-67.55607,1089.345,-8606.521,39783.65,-114322.6,210068.3,-247445.9,181078.4,-75057.43,13478.65]]));
    add(new RegressionColorMap("RdYlBu", "Diverging", [[0.642991,2.067689,2.4008,-55.7673,211.3794,-367.0767,296.6767,-90.13596],[0.003358569,1.534511,2.58159,9.139769,-47.10558,52.97244,-18.92271],[0.1492362,-1.774662,140.4997,-4027.591,58288.17,-490759,2635118,-9516457,2.380624e+07,-4.176496e+07,5.122995e+07,-4.302485e+07,2.357008e+07,-7587209,1088446]]));
    add(new RegressionColorMap("RdYlGn", "Diverging", [[0.6435861,2.88086,-34.32824,489.2461,-3677.644,15161.53,-36874,54402.67,-47897.65,23161.17,-4734.525],[0.002077279,1.3899,8.922088,-62.35206,304.0934,-827.2703,1153.393,-788.2902,210.5216],[0.1491436,-3.728705,327.0102,-10811.14,187471.3,-1971161,1.368395e+07,-6.595642e+07,2.275601e+08,-5.719496e+08,1.055226e+09,-1.426568e+09,1.395522e+09,-9.608228e+08,4.413951e+08,-1.214213e+08,1.51253e+07]]));
    add(new RegressionColorMap("Spectral", "Diverging", [[0.6197774,1.325334,36.91148,-607.1633,4916.959,-24178.17,75373.96,-151123,193707.6,-153219.7,68098.81,-13007.83],[-0.0006841462,2.829995,-6.620532,4.091712,161.4834,-672.9894,1094.098,-812.316,229.7395],[0.2589552,-2.181501,238.262,-8420.458,160478.3,-1863041,1.407996e+07,-7.257249e+07,2.635618e+08,-6.886375e+08,1.308207e+09,-1.807834e+09,1.797604e+09,-1.252463e+09,5.801753e+08,-1.604564e+08,2.004581e+07]]));
    add(new RegressionColorMap("coolwarm", "Diverging", [[0.2378759,0.8307598,2.688646,-4.249058,1.187732],[0.292213,2.162399,-6.286292,29.26612,-70.3687,69.76932,-24.81265],[0.7441923,1.809667,-3.085519,-0.9781447,1.671971]]));
    add(new RegressionColorMap("bwr", "Diverging", [[-0.002352444,2.748123,-31.70079,467.2322,-3371.677,13618.78,-32717.7,47669.99,-41319.84,19605.73,-3922.571],[-0.0005569724,3.598096,-128.353,3642.699,-52683.23,450437.8,-2466718,9070761,-2.30124e+07,4.075804e+07,-5.026342e+07,4.229463e+07,-2.31529e+07,7432520,-1061789],[0.9981859,0.8352974,-32.73938,473.9859,-3400.082,13694.43,-32841.85,47790.99,-41383.98,19619.98,-3922.571]]));
    add(new RegressionColorMap("seismic", "Diverging", [[3.964812e-05,5.414254,-567.191,23621.4,-531010.7,7350797,-6.757792e+07,4.334047e+08,-2.006023e+09,6.859573e+09,-1.759342e+10,3.411472e+10,-5.005975e+10,5.52169e+10,-4.503404e+10,2.633266e+10,-1.04382e+10,2.511931e+09,-2.770266e+08],[-0.0001357102,18.12995,-1807.127,71642.7,-1543116,2.065181e+07,-1.852585e+08,1.169065e+09,-5.360936e+09,1.825901e+10,-4.683032e+10,9.106584e+10,-1.34278e+11,1.490291e+11,-1.224019e+11,7.210954e+10,-2.880414e+10,6.98486e+09,-7.760949e+08],[0.2998091,8.033093,-534.4544,20781.05,-434427.2,5652565,-4.968447e+07,3.10246e+08,-1.420702e+09,4.866503e+09,-1.261343e+10,2.485771e+10,-3.719605e+10,4.190709e+10,-3.4928e+10,2.086473e+10,-8.442551e+09,2.071525e+09,-2.326271e+08]]));
    add(new RegressionColorMap("twilight", "Cyclic", [[0.8835512,1.73132,-158.733,2756.899,-27038.06,161040.6,-605458.5,1478880,-2378009,2498389,-1651116,623228.8,-102517.2],[0.8461764,1.809967,-74.55782,805.0225,-4756.084,16269.59,-33841.89,43660.32,-34196.72,14913.63,-2781.108],[0.8881449,-1.900196,106.3215,-3454.897,53676.75,-479211.8,2710581,-1.024234e+07,2.660624e+07,-4.810743e+07,6.041161e+07,-5.165145e+07,2.867778e+07,-9323296,1347196]]));
    add(new RegressionColorMap("twilight_shifted", "Cyclic", [[0.1876353,-0.09718201,65.55269,-1156.117,11337.55,-71008.82,288921.9,-766887.8,1331526,-1497035,1049527,-417033.4,71743.67],[0.07576997,0.2363898,-31.87285,683.9268,-5040.303,19783.32,-45965.69,64958.51,-54812.75,25403.67,-4979.056],[0.215371,4.645766,-221.106,6443.81,-89077.21,717094.1,-3710525,1.298319e+07,-3.154976e+07,5.381883e+07,-6.42093e+07,5.246134e+07,-2.796953e+07,8767175,-1225662]]));
    add(new RegressionColorMap("hsv", "Cyclic", [[1.000338,-17.28982,1617.077,-59417.76,1182046,-1.467382e+07,1.23274e+08,-7.369719e+08,3.236412e+09,-1.065203e+10,2.659145e+10,-5.061662e+10,7.338606e+10,-8.037306e+10,6.533174e+10,-3.818289e+10,1.516152e+10,-3.660957e+09,4.056307e+08],[0.0001101397,1.91883,210.1927,-2423.517,-54268.66,1861445,-2.432878e+07,1.876249e+08,-9.660806e+08,3.522176e+09,-9.390744e+09,1.862867e+10,-2.767389e+10,3.06872e+10,-2.504338e+10,1.460715e+10,-5.764404e+09,1.379382e+09,-1.511792e+08],[-5.833184e-05,-0.9309754,109.1302,-4943.711,117245.9,-1668700,1.546196e+07,-9.851114e+07,4.486609e+08,-1.502369e+09,3.772156e+09,-7.187003e+09,1.043452e+10,-1.149286e+10,9.457926e+09,-5.640076e+09,2.303272e+09,-5.761771e+08,6.655107e+07]]));
    add(new DistinctColorMap("Pastel1", "Qualitative", [[251,180,174],[179,205,227],[204,235,197],[222,203,228],[254,217,166],[255,255,204],[229,216,189],[253,218,236],[242,242,242]]));
    add(new DistinctColorMap("Pastel2", "Qualitative", [[179,226,205],[253,205,172],[203,213,232],[244,202,228],[230,245,201],[255,242,174],[241,226,204],[204,204,204]]));
    add(new DistinctColorMap("Paired", "Qualitative", [[166,206,227],[31,120,180],[178,223,138],[51,160,44],[251,154,153],[227,26,28],[253,191,111],[255,127,0],[202,178,214],[106,61,154],[255,255,153],[177,89,40]]));
    add(new DistinctColorMap("Accent", "Qualitative", [[127,201,127],[190,174,212],[253,192,134],[255,255,153],[56,108,176],[240,2,127],[191,91,23],[102,102,102]]));
    add(new DistinctColorMap("Dark2", "Qualitative", [[27,158,119],[217,95,2],[117,112,179],[231,41,138],[102,166,30],[230,171,2],[166,118,29],[102,102,102]]));
    add(new DistinctColorMap("Set1", "Qualitative", [[228,26,28],[55,126,184],[77,175,74],[152,78,163],[255,127,0],[255,255,51],[166,86,40],[247,129,191],[153,153,153]]));
    add(new DistinctColorMap("Set2", "Qualitative", [[102,194,165],[252,141,98],[141,160,203],[231,138,195],[166,216,84],[255,217,47],[229,196,148],[179,179,179]]));
    add(new DistinctColorMap("Set3", "Qualitative", [[141,211,199],[255,255,179],[190,186,218],[251,128,114],[128,177,211],[253,180,98],[179,222,105],[252,205,229],[217,217,217],[188,128,189],[204,235,197],[255,237,111]]));
    add(new DistinctColorMap("tab10", "Qualitative", [[31,119,180],[255,127,14],[44,160,44],[214,39,40],[148,103,189],[140,86,75],[227,119,194],[127,127,127],[188,189,34],[23,190,207]]));
    add(new DistinctColorMap("tab20", "Qualitative", [[31,119,180],[174,199,232],[255,127,14],[255,187,120],[44,160,44],[152,223,138],[214,39,40],[255,152,150],[148,103,189],[197,176,213],[140,86,75],[196,156,148],[227,119,194],[247,182,210],[127,127,127],[199,199,199],[188,189,34],[219,219,141],[23,190,207],[158,218,229]]));
    add(new DistinctColorMap("tab20b", "Qualitative", [[57,59,121],[82,84,163],[107,110,207],[156,158,222],[99,121,57],[140,162,82],[181,207,107],[206,219,156],[140,109,49],[189,158,57],[231,186,82],[231,203,148],[132,60,57],[173,73,74],[214,97,107],[231,150,156],[123,65,115],[165,81,148],[206,109,189],[222,158,214]]));
    add(new DistinctColorMap("tab20c", "Qualitative", [[49,130,189],[107,174,214],[158,202,225],[198,219,239],[230,85,13],[253,141,60],[253,174,107],[253,208,162],[49,163,84],[116,196,118],[161,217,155],[199,233,192],[117,107,177],[158,154,200],[188,189,220],[218,218,235],[99,99,99],[150,150,150],[189,189,189],[217,217,217]]));
    add(new RegressionColorMap("flag", "Miscellaneous", [[1.003054,57.48744,-7657.769,284277.5,-5332442,6.067249e+07,-4.589828e+08,2.436671e+09,-9.388949e+09,2.680706e+10,-5.734934e+10,9.219607e+10,-1.107695e+11,9.791904e+10,-6.179076e+10,2.633413e+10,-6.7926e+09,8.022537e+08,-675293.2],[0.005824759,362.1842,-29967.06,1040391,-2.002559e+07,2.425556e+08,-1.990366e+09,1.160379e+10,-4.961581e+10,1.589089e+11,-3.861964e+11,7.165118e+11,-1.014196e+12,1.086468e+12,-8.655482e+11,4.967743e+11,-1.940862e+11,4.619641e+10,-5.054287e+09],[0.001589468,555.5726,-45411.3,1547538,-2.93891e+07,3.539016e+08,-2.907366e+09,1.706326e+10,-7.374981e+10,2.394602e+11,-5.911438e+11,1.11544e+12,-1.606854e+12,1.752304e+12,-1.420968e+12,8.298629e+11,-3.297375e+11,7.97663e+10,-8.862914e+09]]));
    add(new RegressionColorMap("prism", "Miscellaneous", [[0.9991309,203.1754,-15404.71,407578.1,-5407141,3.957736e+07,-1.43008e+08,-7.377359e+07,3.676521e+09,-2.122731e+10,7.202517e+10,-1.677467e+11,2.813021e+11,-3.443355e+11,3.058151e+11,-1.92204e+11,8.112104e+10,-2.063642e+10,2.392231e+09],[-0.003734142,-82.37906,13308.32,-563644.9,1.172902e+07,-1.462303e+08,1.206418e+09,-6.983605e+09,2.94347e+10,-9.249605e+10,2.198209e+11,-3.977475e+11,5.477706e+11,-5.696431e+11,4.395415e+11,-2.437668e+11,9.180245e+10,-2.100833e+10,2.203849e+09],[0.005485634,52.36028,-7290.473,355455.8,-8428500,1.173614e+08,-1.06448e+09,6.695955e+09,-3.040472e+10,1.022695e+11,-2.588835e+11,4.970849e+11,-7.243866e+11,7.954061e+11,-6.47017e+11,3.778735e+11,-1.497591e+11,3.605577e+10,-3.97962e+09]]));
    add(new RegressionColorMap("ocean", "Miscellaneous", [[-0.0005458377,1.094546,-69.00678,1631.291,-19916.77,144336.5,-668989,2067598,-4348435,6239188,-6005498,3706540,-1324824,208438.7],[0.5008673,-3.179374,115.0827,-2798.928,34215.83,-243059.8,1086082,-3199969,6379373,-8664454,7906641,-4641420,1584416,-239136.7],[-0.001635581,1.003271]]));
    add(new RegressionColorMap("gist_earth", "Miscellaneous", [[-0.0002762251,0.4136413,13.21714,-242.0193,2085.699,-9693.582,25994.06,-41308.43,38376.76,-19258.26,4033.133],[-0.001158982,-1.11939,67.12907,-673.1108,3906.444,-14129.28,32121.98,-45561.89,38982.81,-18368.58,3656.612],[0.001107328,27.02537,-648.3809,8552.686,-70015.5,379682.8,-1410563,3648733,-6604605,8313870,-7120912,3954885,-1283984,184977.6]]));
    add(new RegressionColorMap("terrain", "Miscellaneous", [[0.1998541,18.31149,-1914.396,74379.28,-1571220,2.064986e+07,-1.822744e+08,1.134484e+09,-5.142908e+09,1.73515e+10,-4.415997e+10,8.533415e+10,-1.251849e+11,1.383629e+11,-1.132617e+11,6.654501e+10,-2.652383e+10,6.420755e+09,-7.12434e+08],[0.1998249,9.283184,-685.4568,27432.39,-592685,7957289,-7.178133e+07,4.56809e+08,-2.117762e+09,7.305019e+09,-1.899421e+10,3.746006e+10,-5.601448e+10,6.301888e+10,-5.243487e+10,3.127015e+10,-1.2634e+10,3.096168e+09,-3.473731e+08],[0.6002002,-2.234188,278.4137,-2233.399,-142602.1,4285348,-5.694594e+07,4.554154e+08,-2.44032e+09,9.258323e+09,-2.566322e+10,5.287008e+10,-8.147461e+10,9.360736e+10,-7.904515e+10,4.76374e+10,-1.939314e+10,4.779111e+09,-5.384401e+08]]));
    add(new RegressionColorMap("gist_stern", "Miscellaneous", [[0.0002345148,-56.12932,6274.73,-202409.7,3471624,-3.749081e+07,2.761692e+08,-1.455382e+09,5.659909e+09,-1.657715e+10,3.70199e+10,-6.338434e+10,8.31149e+10,-8.276796e+10,6.148308e+10,-3.299379e+10,1.208205e+10,-2.70134e+09,2.781708e+08],[-0.001635581,1.003271],[-0.0002086733,15.95523,-1403.785,55547.98,-1191957,1.591513e+07,-1.428558e+08,9.050411e+08,-4.179162e+09,1.436763e+10,-3.726041e+10,7.334851e+10,-1.095618e+11,1.232244e+11,-1.025713e+11,6.12355e+10,-2.478233e+10,6.086752e+09,-6.847317e+08]]));
    add(new RegressionColorMap("gnuplot", "Miscellaneous", [[0.01540058,5.27125,-32.41231,128.9701,-287.9833,357.4067,-230.2836,60.01988],[0.0004682807,-0.00766732,0.01773881,0.993135],[2.174191e-05,-5.966946,1101.784,-40918.34,838716.8,-1.083111e+07,9.470293e+07,-5.870363e+08,2.659603e+09,-8.986304e+09,2.292773e+10,-4.443231e+10,6.536459e+10,-7.242569e+10,5.940983e+10,-3.496238e+10,1.395237e+10,-3.380332e+09,3.752661e+08]]));
    add(new RegressionColorMap("gnuplot2", "Miscellaneous", [[0.0003712145,-3.926377,317.0111,-9684.757,154084.3,-1466660,9031891,-3.77987e+07,1.10921e+08,-2.322662e+08,3.488747e+08,-3.730419e+08,2.771769e+08,-1.360201e+08,3.963975e+07,-5195486],[-0.004158209,1.176903,-36.70984,422.5831,-2361.849,7182.688,-12472.24,12384.04,-6551.556,1432.871],[5.690406e-05,-12.5525,1582.16,-61273.32,1299019,-1.718545e+07,1.528e+08,-9.574842e+08,4.366656e+09,-1.481292e+10,3.78965e+10,-7.362202e+10,1.086208e+11,-1.208086e+11,9.957818e+10,-5.895306e+10,2.369424e+10,-5.787626e+09,6.483878e+08]]));
    add(new RegressionColorMap("CMRmap", "Miscellaneous", [[0.0001979309,-3.66959,408.3956,-13384.48,233621.8,-2489575,1.749516e+07,-8.507316e+07,2.951744e+08,-7.443139e+08,1.375497e+09,-1.860667e+09,1.820062e+09,-1.252512e+09,5.74957e+08,-1.580127e+08,1.966233e+07],[0.003568684,-0.6664486,68.39045,-887.9126,5507.664,-19568.16,42469.27,-57130.48,46452.52,-20912.9,4003.269],[-0.0002387746,-0.1996876,412.2208,-17271.16,393609.7,-5480214,5.024197e+07,-3.197753e+08,1.465944e+09,-4.963678e+09,1.261517e+10,-2.426865e+10,3.5381e+10,-3.883033e+10,3.155586e+10,-1.841009e+10,7.290211e+09,-1.754487e+09,1.936916e+08]]));
    add(new RegressionColorMap("cubehelix", "Miscellaneous", [[-0.006161774,2.061333,-6.955477,-60.45436,418.3087,-872.8088,761.9777,-241.1359],[-0.0008024276,0.7467273,-5.591583,92.70041,-380.2072,658.1632,-517.1637,152.3574],[0.0007520252,1.310252,8.664477,-9.898132,-359.5616,1518.347,-2446.942,1772.75,-483.6743]]));
    add(new RegressionColorMap("brg", "Miscellaneous", [[-0.0005569724,3.598096,-128.353,3642.699,-52683.23,450437.8,-2466718,9070761,-2.30124e+07,4.075804e+07,-5.026342e+07,4.229463e+07,-2.31529e+07,7432520,-1061789],[0.001814115,-0.8352974,32.73938,-473.9859,3400.082,-13694.43,32841.85,-47790.99,41383.98,-19619.98,3922.571],[1.002352,-2.748123,31.70079,-467.2322,3371.677,-13618.78,32717.7,-47669.99,41319.84,-19605.73,3922.571]]));
    add(new RegressionColorMap("gist_rainbow", "Miscellaneous", [[0.9998056,16.73438,-1613.674,61346.36,-1259948,1.603787e+07,-1.368809e+08,8.239254e+08,-3.617589e+09,1.184536e+10,-2.931683e+10,5.518802e+10,-7.897766e+10,8.523917e+10,-6.818115e+10,3.915922e+10,-1.526054e+10,3.611896e+09,-3.917856e+08],[-0.0001738693,-0.3934147,-100.5865,7462.335,-137611.8,1143246,-2991509,-2.68824e+07,3.200039e+08,-1.699809e+09,5.765079e+09,-1.365678e+10,2.336954e+10,-2.91662e+10,2.635739e+10,-1.681866e+10,7.192099e+09,-1.850438e+09,2.166262e+08],[0.1601925,-14.84199,794.972,-25136.91,480696.2,-5913733,4.953337e+07,-2.949579e+08,1.288189e+09,-4.215369e+09,1.047341e+10,-1.987913e+10,2.88025e+10,-3.159208e+10,2.576793e+10,-1.513602e+10,6.048294e+09,-1.471178e+09,1.643269e+08]]));
    add(new RegressionColorMap("rainbow", "Miscellaneous", [[0.5001498,-4.354137,218.3764,-7207.772,120843.8,-1193016,7538821,-3.21559e+07,9.580327e+07,-2.032831e+08,3.091743e+08,-3.346945e+08,2.518038e+08,-1.25144e+08,3.694108e+07,-4904646],[-0.001247067,3.04538,0.7957139,-7.682188,3.841094],[0.9974692,0.06258826,-1.51852,0.4545314]]));
    add(new RegressionColorMap("jet", "Miscellaneous", [[9.530817e-05,-6.013702,573.5187,-21532.53,436111.5,-5460347,4.564564e+07,-2.675394e+08,1.13616e+09,-3.574124e+09,8.446758e+09,-1.510449e+10,2.044509e+10,-2.079881e+10,1.563716e+10,-8.422029e+09,3.071699e+09,-6.791723e+08,6.869829e+07],[-7.115363e-06,9.645774,-958.1951,37326.1,-775502.6,9834169,-8.25421e+07,4.845279e+08,-2.06503e+09,6.551605e+09,-1.571655e+10,2.873057e+10,-4.004324e+10,4.223967e+10,-3.314788e+10,1.875035e+10,-7.223587e+09,1.696116e+09,-1.831123e+08],[0.4997902,7.644723,-302.7537,9921.265,-161086,1534750,-9418685,3.794642e+07,-9.272047e+07,7.344644e+07,3.814001e+08,-1.78678e+09,4.110009e+09,-6.138973e+09,6.292081e+09,-4.416626e+09,2.037044e+09,-5.57502e+08,6.870991e+07]]));
    add(new RegressionColorMap("nipy_spectral", "Miscellaneous", [[-0.001206257,53.31128,-4299.214,163237.6,-3316665,4.133337e+07,-3.454638e+08,2.046836e+09,-8.901047e+09,2.903197e+10,-7.191536e+10,1.360109e+11,-1.961268e+11,2.137749e+11,-1.729889e+11,1.006479e+11,-3.977534e+10,9.554834e+09,-1.052669e+09],[-9.864143e-05,-13.25711,1333.054,-52527.71,1102747,-1.408904e+07,1.183304e+08,-6.873801e+08,2.859697e+09,-8.719151e+09,1.974626e+10,-3.337548e+10,4.193378e+10,-3.860321e+10,2.528916e+10,-1.116758e+10,2.986101e+09,-3.693357e+08,1853919],[-0.0006056399,5.900594,159.1363,4982.974,-301372.2,5445169,-5.407943e+07,3.463394e+08,-1.540796e+09,4.964353e+09,-1.187217e+10,2.135994e+10,-2.904603e+10,2.973474e+10,-2.259205e+10,1.237664e+10,-4.630595e+09,1.061123e+09,-1.125584e+08]]));
    add(new RegressionColorMap("gist_ncar", "Miscellaneous", [[-0.0003636799,16.80427,-1564.536,57053.79,-1119805,1.359276e+07,-1.105008e+08,6.333613e+08,-2.650792e+09,8.297157e+09,-1.972478e+10,3.590456e+10,-5.009425e+10,5.320661e+10,-4.230506e+10,2.440159e+10,-9.646657e+09,2.338251e+09,-2.620135e+08],[0.001020357,-73.79832,6854.985,-216902.5,3557532,-3.561335e+07,2.374844e+08,-1.10875e+09,3.724163e+09,-9.093487e+09,1.602623e+10,-1.966945e+10,1.497659e+10,-3.485777e+09,-6.402194e+09,8.532396e+09,-5.089658e+09,1.599026e+09,-2.143133e+08],[0.5014435,100.752,-9618.786,320063,-5681982,6.387999e+07,-4.958721e+08,2.793526e+09,-1.177335e+10,3.779987e+10,-9.333461e+10,1.777016e+11,-2.59914e+11,2.889721e+11,-2.394783e+11,1.430871e+11,-5.817503e+10,1.439236e+10,-1.633829e+09]]));
  }

}

alias colorMaps = Singleton!StandardColorMaps;

