module het.color;

import het.utils, jsonizer, std.traits;

// RGB formats ////////////////////////////////////////////////

alias RGB = RGB8, RGBA = RGBA8;

RGB  BGR (uint a){ auto c = RGB (a); c.rbSwap; return c; }
RGBA BGRA(uint a){ auto c = RGBA(a); c.rbSwap; return c; }

private ubyte f2b(float f){ return cast(ubyte)(f*255.0f).iRound.clamp(0, 255); }
private float b2f(int b){ return b*(1.0f/255.0f); }
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

struct L8{ align(1): @jsonize ubyte[1] comp; mixin Color8Members;
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
  T res; int t = iRound(tf*255),  it = (255-t);
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
}


RGB HSVToRGB(float H, float S, float V){ return HSVToRGBf(H, S, V).rgb8; }

RGBf HSVToRGBf(float H, float S, float V)
{
  if(!S) return RGBf(V,V,V);
  if(!V) return RGBf(0,0,0);

  auto Hval = H * 6,
       sel = iFloor(Hval),
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
}


//const test = lerp(RGB8(1,2,3), RGB8(0x808080), 128);

//auto lerp(T)(in T a, in T b, int t)if(is(T==  LA8)){ T res; int it = (255-i); foreach(i; 0..a.comp.length) res.comp[i] = (a.comp[i]*t + b.comp[i]*it)>>8; return res; }
//auto lerp(T)(in T a, in T b, int t)if(is(T== RGB8)){ T res; int it = (255-i); foreach(i; 0..a.comp.length) res.comp[i] = (a.comp[i]*t + b.comp[i]*it)>>8; return res; }
//auto lerp(T)(in T a, in T b, int t)if(is(T==RGBA8)){ T res; int it = (255-i); foreach(i; 0..a.comp.length) res.comp[i] = (a.comp[i]*t + b.comp[i]*it)>>8; return res; }

/*


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

immutable RGB8
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
  clSolGreen        = 0x009985;

enum clOrange = clRainbowOrange; //todo: belerakni a listaba

immutable{
  RGB8[18] clDelphi  = [clBlack, clMaroon, clGreen, clOlive, clNavy, clPurple, clTeal, clGray, clSilver, clRed, clLime, clYellow, clBlue, clFuchsia, clAqua, clLtGray, clDkGray, clWhite];
  RGB8[16] clVga     = [clVgaBlack, clVgaLowBlue, clVgaLowGreen, clVgaLowCyan, clVgaLowRed, clVgaLowMagenta, clVgaBrown, clVgaLightGray, clVgaDarkGray, clVgaHighBlue, clVgaHighGreen, clVgaHighCyan, clVgaHighRed, clVgaHighMagenta, clVgaYellow, clVgaWhite];
  RGB8[16] clC64     = [clC64Black, clC64White, clC64Red, clC64Cyan, clC64Purple, clC64Green, clC64Blue, clC64Yellow, clC64Orange, clC64Brown, clC64Pink, clC64DGrey, clC64Grey, clC64LGreen, clC64LBlue, clC64LGrey];
  RGB8[ 8] clWow     = [clBlack, clWowGrey, clWowWhite, clWowGreen, clWowBlue, clWowPurple, clWowRed, clWowRed2];
  RGB8[10] clVim     = [clVimBlack, clVimBlue, clVimGreen, clVimTeal, clVimRed, clVimPurple, clVimYellow, clVimWhite, clVimGray, clVimOrange];
  RGB8[ 8] clRainbow = [clRainbowRed, clRainbowOrange, clRainbowYellow, clRainbowGreen, clRainbowAqua, clRainbowBlue, clRainbowPurple, clRainbowPink];
  RGB8[16] clSol     = [clSolBase03, clSolBase02, clSolBase01, clSolBase00, clSolBase0, clSolBase1, clSolBase2, clSolBase3, clSolYellow, clSolOrange, clSolRed, clSolMagenta, clSolViolet, clSolBlue, clSolCyan, clSolGreen];
  RGB8[] clAll = clDelphi ~ clVga ~ clC64 ~ clWow ~ clVim ~ clRainbow ~ clSol;
}

RGB colorByName(string name, bool mustExists=false){

  __gshared static RGB[string] map;

  if(map is null){ //todo: user driendly editing of all the colors

    enum data = "clBlack=000000,clMaroon=000080,clGreen=008000,clOlive=008080,clNavy=800000,clPurple=800080,clTeal=808000,clGray=808080,clSilver=C0C0C0,
      clRed=0000FF,clLime=00FF00,clYellow=00FFFF,clBlue=FF0000,clFuchsia=FF00FF,clAqua=FFFF00,clLtGray=C0C0C0,clDkGray=808080,clWhite=FFFFFF,
      clSkyBlue=F0CAA6,clMoneyGreen=C0DCC0,clVgaBlack=000000,clVgaDarkGray=555555,clVgaLowBlue=AA0000,clVgaHighBlue=FF5555,clVgaLowGreen=00AA00,
      clVgaHighGreen=55FF55,clVgaLowCyan=AAAA00,clVgaHighCyan=FFFF55,clVgaLowRed=0000AA,clVgaHighRed=5555FF,clVgaLowMagenta=AA00AA,clVgaHighMagenta=FF55FF,
      clVgaBrown=0055AA,clVgaYellow=55FFFF,clVgaLightGray=AAAAAA,clVgaWhite=FFFFFF,clC64Black=000000,clC64White=FFFFFF,clC64Red=354374,clC64Cyan=BAAC7C,
      clC64Purple=90487B,clC64Green=4F9764,clC64Blue=853240,clC64Yellow=7ACDBF,clC64Orange=2F5B7B,clC64Brown=00454f,clC64Pink=6572a3,clC64DGrey=505050,
      clC64Grey=787878,clC64LGreen=8ed7a4,clC64LBlue=bd6a78,clC64LGrey=9f9f9f,clWowGrey=9d9d9d,clWowWhite=ffffff,clWowGreen=00ff1e,clWowBlue=dd7000,
      clWowPurple=ee35a3,clWowRed=0080ff,clWowRed2=80cce5,clVimBlack=141312,clVimBlue=DAA669,clVimGreen=4ACAB9,clVimTeal=B1C070,clVimRed=534ED5,
      clVimPurple=D897C3,clVimYellow=47C5E7,clVimWhite=FFFFFF,clVimGray=9FA19E,clVimOrange=458CE7,clRainbowRed=0000FF,clRainbowOrange=0088FF,
      clRainbowYellow=00EEEE,clRainbowGreen=00FF00,clRainbowAqua=CCCC00,clRainbowBlue=FF0000,clRainbowPurple=FF0088,clRainbowPink=8800FF,clSolBase03=362b00,
      clSolBase02=423607,clSolBase01=756e58,clSolBase00=837b65,clSolBase0=969483,clSolBase1=a1a193,clSolBase2=d5e8ee,clSolBase3=e3f6fd,clSolYellow=0089b5,
      clSolOrange=164bcb,clSolRed=2f32dc,clSolMagenta=8236d3,clSolViolet=c4716c,clSolBlue=d28b26,clSolCyan=98a12a,clSolGreen=009985";

    foreach(l; data.split(',')){
      auto p = l.strip.split('=');

      //preprocess name: take off cl, lowercase first letter
      auto n = p[0].withoutStarting("cl").decapitalize;

      map[n] = RGB(p[1].to!uint(16));
    }

    map.rehash;
  }

  auto a = name.decapitalize in map;
  if(a is null){
    enforce(!mustExists, `Unknown color name "%s"`.format(name));
    return clFuchsia;
  }
  return *a;
}

//toRGB //////////////////////////////////

RGB toRGB(string s){
  s = s.strip;
  enforce(!s.empty, `Empty RGB literal.`);

  //decimal or hex number
  if(s[0].inRange('0', '9')) return RGB(s.toInt);

  //rgb(0,0,255)
  if(s.isWild("rgb(?*,?*,?*)") || s.isWild("RGB8([?*,?*,?*])")){
    return RGB(wild.ints(0), wild.ints(1), wild.ints(2));
  }

  return colorByName(s, true);
}

//operations //////////////////////////////

RGB  opBinary(string op : "*")(in RGB a , in RGB b )     { return RGB (a.r*b.r>>8, a.g*b.g>>8, a.b*b.b>>8); }    //todo: nem jo a color szorzas, mert implicit uint konverzio van
RGBA opBinary(string op : "*")(in RGBA a, in RGBA b)     { return RGBA(a.r*b.r>>8, a.g*b.g>>8, a.b*b.b>>8, a.a*b.a>>8); }


import std.traits;
pragma(msg, "Megcsinalni a szinek listazasat traits-al." ~ [__traits(allMembers, het.color)].filter!(s => s.startsWith("cl")).array);
