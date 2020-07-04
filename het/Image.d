module het.image;

import het.utils, het.geometry, jsonizer, core.sys.windows.windows, std.uni;

import imageformats; //external package

//turn Direct2D linkage on/off
version = D2D_FONT_RENDERER;

// newBitmap ////////////////////////////

//todo: ezt is bepakolni a Bitmap class-ba... De kell a delayed betoltes lehetosege is talan...
auto isFontDeclaration(string s){ return s.startsWith(`font:\`); }

Bitmap newBitmap(in File file, bool mustExist=true){
  return newBitmap(file.fullName, mustExist);
}


private __gshared Bitmap function(string)[string] customBitmapLoaders;

void registerCustomBitmapLoader(string prefix, Bitmap function(string) loader)
in(prefix.length>=2, "invalid prefix string")
{
  prefix = prefix.lc;
  enforce(!(prefix in customBitmapLoaders), "Already registered customBitmapLoader. Prefix: "~prefix);

  customBitmapLoaders[prefix] = loader;
}


Bitmap newBitmap(string fn, bool mustExist=true){
  // split prefix:\line
  auto prefix = fn.until!(not!isAlphaNum).text;
  auto line = fn;
  if(prefix.length>1 && fn[prefix.length..$].startsWith(`:\`)){
    line = fn[prefix.length+2..$];
    prefix = prefix.lc;
  }else{
    prefix = "";
  }

  if(prefix==""){ //threat it as a simple filename
    return new Bitmap(File(fn).read(mustExist));
  }else if(prefix=="font"){
    version(D2D_FONT_RENDERER){
      return bitmapFontRenderer.renderDecl(fn); //todo: error handling, mustExists
    }else{
      enforce(0, "No font renderer linked into the exe. Use version D2D_FONT_RENDERER!");
    }
  }else if(prefix=="screen"){
    raise("screen(shot) is not implemented");
  }else if(prefix=="debug"){ //debug images
    auto tmp = new Bitmap(1600, 1200, 4);

    uint color = (line.to!int)>>1;
    color = color | (255-color)<<8;

    tmp.rgba.clear(RGBA(0xFF000000 | color));
    return tmp;
  }else{
    auto loader = prefix in customBitmapLoaders;
    if(loader)
      return (*loader)(line);
  }

  raise("Unknown prefix: "~prefix~`:\`);
  return null; //raise is not enough

//  if(fn.startsWith(`screenShot:\`)){
    //todo: screenshot implementalasa

/*   auto gBmp = new GdiBitmap(V2i(screenWidth, screenHeight), 4);
  BitBlt(gBmp.hdcMem, 0, 0, gBmp.size.x, gBmp.size.y, GetDC(NULL), 0, 0, SRCCOPY).writeln;
*/

//todo: bitmap clipboard operations
/*    // save bitmap to clipboard
    OpenClipboard(NULL);
    EmptyClipboard();
    SetClipboardData(CF_BITMAP, hBitmap);
    CloseClipboard();*/


/*    HDC     hScreen = GetDC(NULL);
    HDC     hDC     = CreateCompatibleDC(hScreen);
    HBITMAP hBitmap = CreateCompatibleBitmap(hScreen, abs(b.x-a.x), abs(b.y-a.y));
    HGDIOBJ old_obj = SelectObject(hDC, hBitmap);
    BOOL    bRet    = BitBlt(hDC, 0, 0, abs(b.x-a.x), abs(b.y-a.y), hScreen, a.x, a.y, SRCCOPY);

    // save bitmap to clipboard
    OpenClipboard(NULL);
    EmptyClipboard();
    SetClipboardData(CF_BITMAP, hBitmap);
    CloseClipboard();

    // clean up
    SelectObject(hDC, old_obj);
    DeleteDC(hDC);
    ReleaseDC(NULL, hScreen);
    DeleteObject(hBitmap);*/
//  }

  //debug images

  //otherwise File
//  return new Bitmap(File(fn).read(mustExist));
}

// utility stuff //////////////////////////////////////////////////////////

//todo: a het.bitmap-ot belerakni ebbe.

float cubicInterpolate(float[4] p, float x) { //http://www.paulinternet.nl/?page=bicubic
  return p[1] + 0.5f * x*(p[2] - p[0] + x*(2*p[0] - 5*p[1] + 4*p[2] - p[3] + x*(3*(p[1] - p[2]) + p[3] - p[0])));
}

T cubicInterpolate(T)(T[4] p, float x) if(__traits(isIntegral, T)){ //http://www.paulinternet.nl/?page=bicubic
  float f = (p[1] + 0.5f * x*(p[2] - p[0] + x*(2*p[0] - 5*p[1] + 4*p[2] - p[3] + x*(3*(p[1] - p[2]) + p[3] - p[0]))));
  return cast(T)f.iRound.clamp(T.min, T.max);
}

T bicubicInterpolate (T)(T[4][4] p, float x, float y) { //unoptimized recursive version
  T[4] a = [ cubicInterpolate(p[0], x),
             cubicInterpolate(p[1], x),
             cubicInterpolate(p[2], x),
             cubicInterpolate(p[3], x) ];
  return cubicInterpolate(a, y);
}

//Extract a sub-region of a given image
//x,y :    top, left coordinate of the rect
//w,h :    size of the output image
//xs, ys:  stepSize int x, y directions  <1 means magnification
Image!T extract_bicubic(T)(Image!T iSrc, float x0, float y0, int w, int h, float xs=1, float ys=1){
  auto res = new Image!T(w, h);
  auto x00 = x0;

  foreach(int y; 0..h){
    auto yt = y0.iFloor,
         yf = y0-yt;

    x0 = x00; //advance row
    foreach(int x; 0..w){
      auto xt = x0.iFloor,
           xf = x0-xt;

      //get a sample form x0, y0
      T[4][4] a; foreach(j; 0..4) foreach(i; 0..4) a[j][i] = iSrc[iSrc.ofs_safe(i+xt-1, j+yt-1)];

      res[x, y] = bicubicInterpolate(a, xf, yf);

      x0 += xs;
    }
    y0 += ys;
  }

  return res;
}

float linearInterpolate(float[2] p, float x) { //http://www.paulinternet.nl/?page=bicubic
  return p[1]*x + p[0]*(1-x);
}

T linearInterpolate(T)(T[2] p, float x) if(__traits(isIntegral, T)){ //http://www.paulinternet.nl/?page=bicubic
  float f = p[1]*x + p[0]*(1-x);
  return cast(T)f.iRound.clamp(T.min, T.max);
}

T bilinearInterpolate (T)(T[2][2] p, float x, float y) { //unoptimized recursive version
  T[2] a = [ linearInterpolate(p[0], x),
             linearInterpolate(p[1], x) ];
  return linearInterpolate(a, y);
}

Image!T extract_bilinear(T)(Image!T iSrc, float x0, float y0, int w, int h, float xs=1, float ys=1){
  auto res = new Image!T(w, h);
  auto x00 = x0;

  foreach(int y; 0..h){
    auto yt = y0.iFloor,
         yf = y0-yt;

    x0 = x00; //advance row
    foreach(int x; 0..w){
      auto xt = x0.iFloor,
           xf = x0-xt;

      //get a sample form x0, y0
      T[2][2] a; foreach(j; 0..2) foreach(i; 0..2) a[j][i] = iSrc[iSrc.ofs_safe(i+xt, j+yt)];

      res[x, y] = bilinearInterpolate(a, xf, yf);

      x0 += xs;
    }
    y0 += ys;
  }

  return res;
}

Image!T extract_nearest(T)(Image!T iSrc, float x0, float y0, int w, int h, float xs=1, float ys=1){
  auto res = new Image!T(w, h);
  auto x00 = x0;

  foreach(int y; 0..h){
    auto yt = y0.iFloor,
         yf = y0-yt;

    x0 = x00; //advance row
    foreach(int x; 0..w){
      auto xt = x0.iFloor,
           xf = x0-xt;

      res[x, y] = iSrc[iSrc.ofs_safe(xt, yt)];

      x0 += xs;
    }
    y0 += ys;
  }

  return res;
}

//This is a special one: it only processes the first 2 ubytes of an uint
//todo: should be refactored to an image that handles RGBA types
Image!uint extract_bilinear_rg00(Image!uint iSrc, float x0, float y0, int w, int h, float xs=1, float ys=1){
  auto res = new Image!uint(w, h);
  auto x00 = x0;

  foreach(int y; 0..h){
    auto yt = y0.iFloor,
         yf = y0-yt;

    x0 = x00; //advance row
    foreach(int x; 0..w){
      auto xt = x0.iFloor,
           xf = x0-xt;

      //get a sample form x0, y0
      ubyte[2][2] a;

      //r
      foreach(j; 0..2) foreach(i; 0..2) a[j][i] = iSrc[iSrc.ofs_safe(i+xt, j+yt)] & 0xFF;
      res[x, y] = bilinearInterpolate(a, xf, yf);

      //g
      foreach(j; 0..2) foreach(i; 0..2) a[j][i] = (iSrc[iSrc.ofs_safe(i+xt, j+yt)]>>8) & 0xFF;
      res[x, y] |= bilinearInterpolate(a, xf, yf)<<8;

      x0 += xs;
    }
    y0 += ys;
  }

  return res;
}


Image!uint extract_bicubic_rg00(Image!uint iSrc, float x0, float y0, int w, int h, float xs=1, float ys=1){
  auto res = new Image!uint(w, h);
  auto x00 = x0;

  foreach(int y; 0..h){
    auto yt = y0.iFloor,
         yf = y0-yt;

    x0 = x00; //advance row
    foreach(int x; 0..w){
      auto xt = x0.iFloor,
           xf = x0-xt;

      //get a sample form x0, y0
      ubyte[4][4] a;

      foreach(j; 0..4) foreach(i; 0..4) a[j][i] = cast(ubyte)(iSrc[iSrc.ofs_safe(i+xt-1, j+yt-1)] & 0xFF);
      res[x, y] = bicubicInterpolate(a, xf, yf);

      foreach(j; 0..4) foreach(i; 0..4) a[j][i] = cast(ubyte)((iSrc[iSrc.ofs_safe(i+xt-1, j+yt-1)]>>8) & 0xFF);
      res[x, y] |= bicubicInterpolate(a, xf, yf)<<8;

      x0 += xs;
    }
    y0 += ys;
  }

  return res;
}


//todo: implement PPM image codec
/*
class Bitmap {
  int width;
  int height;
  ubyte[] data;
  int[] rgba;

  this(File fn) {
    load(fn);
  }

  this(int w, int h) {
    width = w; height = h;
    data = new ubyte[w * h];
  }

  void load(File fn) {
    if(lc(fn.ext)==".ppm") {
      loadPPM(fn);
    }
  }

  void loadPPM(File fn) {
    ulong fsize = fn.size;

    data = fn.read;

    int i, ec;
    while(i<fsize) {
      if(data[i] == '\n') {
        ec++;
        if(ec == 3) break;
      }
      i++;
    }

    enforce(ec == 3);

    auto header = cast(string)data[0..i];

    data = data[i+1..$];

    auto list = header.split('\n')
               .map!(a => to!string(a).strip)
               .filter!(a => !a.empty)
               .array;

    enforce(list.length == 3);

    auto dim = list[1].split(' ')
               .map!(a => to!int(a))
               .filter!(a => a>0)
               .array;

    enforce(dim.length == 2);

    width = dim[0];
    height = dim[1];

    rgba = new int[width*height];
    for(i=0; i<width*height; i++) {
      ubyte R,G,B;
      R = data[3*i];
      G = data[3*i+1];
      B = data[3*i+2];

      rgba[i] = 0xFF << 24 | B << 16 | G << 8 | R;
    }
  }
}
  */

// Bitmap image processing //////////////////////////

/*if(calculateAvgAlpha) foreach(ref p; img.data) p.a = ((p.r+p.g+p.b)*85)>>8; //alpha = rgb average. can be used as grayscale
ezt a feldolgozast kell kiboviteni:
- grayscale vagy szines: Ez egyreszt johet az codepoint-bol.
- Ha a codepoint alapjan lehet, hogy szines, akkor azt ellenorizni kell.
- Ha tenyleg szines, akkor fekete es feher hatter segitsegevel meg kell hatarozni a maszkot.
- a BGR-t is meg lehet forditani, esetleg a shaderbe kene azt beleintegralni. Az +1 bit. */


class Image(T){ // Image class //////////////////////
  mixin JsonizeMe;
private:
  @jsonize("width") int width_;
  @jsonize("height") int height_;
  @jsonize("data")  T[] data_;

  int changedCnt_;

  void realloc(int w, int h){
    enforce(w>=0 && h>=0, "Invalid image dimensions");
    width_ = w;
    height_ = h;
    data_.length = w*h;

    changed;
  }
public:

  this(){
    changed; //just get the first random changedCnt seed
  }

  @jsonize this(T[] data=null, int width=0, int height=0, int pitch=-1, bool dup=false){

LOG("IMAGE THIS1");
    acquire(data, width, height, pitch, dup);
  }

  this(void[] data=null, int width=0, int height=0, int pitch=-1, bool dup=false){
LOG("IMAGE THIS2", data.length, data.length&4, T.sizeof);
    T[] ca;
    try{ //todo: ha nem try-except-elek, akkor ez az egesz lenyelodik valahogy feldolgozas NELKUL
      ca = cast(T[])data; //todo: itt egy convert error van: 512byte RGBA-t akar RGB-re castolni a geci.
    }catch(Throwable t){
      auto s = t.text[0..4]; //todo: ha az egesz t.msg textet adom at az ERR-nek, akkor elbaszodik az ERR-en belul.
      ERR(s);
    }
LOG("IMAGE THIS2 CAST SUCCESS", ca);
    acquire(ca, width, height, pitch, dup);
  }

  this(Image!T src, bool dup=false){
    acquire(src.data, src.width, src.height, src.width, dup);
  }

  this(int width, int height, T delegate(int x, int y) generator){
    realloc(width, height);
    int i=0;
    foreach(int y; 0..height)
      foreach(int x; 0..width)
        data_[i++] = generator(x, y);
  }
  this(int width, int height){
    realloc(width, height); //todo: should realloc garbage. also needs a constructor to fill with a specified value
  }

  //vector variants
  this(in V2i size, T delegate(int x, int y) generator){ this(size.x, size.y, generator); }
  this(in V2i size){ this(size.x, size.y); }

  //fixme: even with an empty destructor it is a crash
  //~this(){ realloc(0, 0);  }

  @property changedCnt() const { return changedCnt_; };
  void setChangedCnt(uint n) { changedCnt_ = n; };

  void changed(){
/*    if(!changedCnt_) changedCnt_ = getUniqueSeed(this);
                else changedCnt_ = RNG.nextRandom(changedCnt_);*/
    //todo: a randomSeed nem megy, mert compile timeban is kene az
    changedCnt_++;
  };

  Image!T dup(){
    return new Image!T(data.dup, width, height, width, false/*eleve mar duplikalva lett*/);
  }

  auto to(T2)(){
    return new Image!T2(width, height, (x, y) => this[x, y].to!T2 );  //todo: ezt megcsinalni 1D-re is.
    //return new Image!T2(data.map!(a => a.to!T2).array, width, height);
  }

  @property int width() const { return width_; }
  @property void width(int w) { realloc(w, height); }
  @property int height() const { return height_; }
  @property void height(int h) { realloc(width, h); }

  alias xs = width, ys = height;

  @property V2i size() const { return V2i(width_, height_); }
  @property void size(const V2i s) { realloc(s.x, s.y); }
  int area() const { return width*height; }

  final bool empty() const { return (this is null) || !size.x || !size.y; } //final, so it is not virtual

  Bounds2i bounds() const { return Bounds2i(0, 0, width_, height_); }

  ref T[] data() { return data_; }
  const(T)[] cdata()const { return cast(const(T)[])data_; }

  int ofs(int x, int y) const { return y*width + x; }
  int ofs(in V2i v) const { return ofs(v.x, v.y); }

  int ofs_safe(int x, int y) const {
    x = min(x, width -1); x = max(x, 0);
    y = min(y, height-1); y = max(y, 0);
    return ofs(x, y);
  }
  int ofs_safe(in V2i v) const { return ofs_safe(v.x, v.y); }

  ref T opIndex(int o) { return data_[o]; }
  ref T opIndex(int x, int y){ return data_[ofs(x, y)]; }
  ref T opIndex(in V2i v) { return opIndex(v.x, v.y); }

  ref T pix(int x, int y){ return data_[ofs(x, y)]; }
  ref T pix_safe(int x, int y){ return data_[ofs_safe(x, y)]; }

  ref T pix(in V2i p){ return data_[ofs(p)]; }
  ref T pix_safe(in V2i p){ return data_[ofs_safe(p)]; }

  void acquire(void[] src, int width, int height, int pitch=-1, bool dup=false){

//if(DEBUGIMG){
  LOG("IMG.ACQUIRE", cast(T[])src, width, height);
//}

    if(src is null){
      realloc(width, height);
      return;
    }

    if(pitch<0) pitch = width;

    auto minLength = height*pitch*T.sizeof;
    enforce(src.length>=minLength);

    if(pitch==width){
      auto tmp = (cast(T[])src)[0..width*height];
      if(dup){
        realloc(width, height);
        data[] = tmp;
      }else{
        width_  = width ;
        height_ = height;
        data = tmp;
      }
    }else{
      realloc(width, height);
      size_t s = 0, d = 0;
      foreach(int y; 0..height){
        data[d..d+width] = (cast(T[])src)[s..s+width];
        d += width;
        s += pitch;
      }
    }

    changed;
  }

  void clear(T val = T.init){
    data[] = val;
    changed;
  }

  override string toString() const {
    return format("Image[%d*%d %s]", width, height, T.stringof);
  }

  T[] row(int y, int x0=0, int x1=int.max){
    x0.maximize(0);
    x1.minimize(width);
    if(x0>=x1) return [];
    int o = y.clamp(0, height-1)*width + x0;
    int w = x1-x0;
    return data[o..o+w];
  }

  T[] column(int x, int y0=0, int y1=int.max){
    y0.maximize(0);
    y1.minimize(height);
    if(y0>=y1) return [];
    int o = x.clamp(0, width-1) + y0*width;
    int h = y1-y0;
    T[] res; res.reserve(h);
    foreach(i; 0..h){
      res ~= data[o];
      o += width;
    }
    return res;
  }

}

//utility functions

auto peakDetect(T)(Image!T img, int border=1, T minValue=T.min){ with(img){
  V2i[] peaks;
  foreach(int y; border..height-border){ int o0 = y*width;
    foreach(int x; border..width-border){ auto o = o0+x, val = data[o];
      if(val>minValue && img.isPeak(o))
        peaks ~= V2i(x, y);
    }
  }
  return peaks;
}}

void maskAll(T)(Image!T img, T mask){ with(img){
  data[] &= mask;
}}

void mask(T)(Image!T img, Bounds2i b, T msk){ with(img){
  with(bounds.clamp(b)){
    if(isNull) return;
    foreach(int y; bMin.y..bMax.y){
      int o0 = y*width_;
      foreach(int o; o0+bMin.x..o0+bMax.x){
        data_[o] &= msk;
      }
    }

  }
}}

void maskBorder(T)(Image!T img, int border, T mask){ with(img){
  if(border*2>=width || border*2>=height) img.maskAll(mask);

  data[0..width*border] &= mask;
  data[$-width*border..$] &= mask;
  foreach(int y; border..height-border){
    int o = y*width;
    data[o..o+border] &= mask;
    data[o+width-border..o+width] &= mask;
  }
}}

bool isPeak(T)(Image!T img, int o){ with(img){
  const center = data[o];
  bool g(int delta){
    const val = data[o+delta];
    return center>val || (center==val && delta>0);
  }

  return g(      -1) && g(       1) &&
         g(-width  ) && g( width  ) &&
         g( width-1) && g( width+1) &&
         g(-width-1) && g(-width+1);
}}


/// Calculates sum of vertical and horicontal derivates of the green channel. 0..255
float measureContrast(T)(Image!T img, Bounds2i b){ with(img){
  with(bounds.clamp(b)){
    if(isNull) return 0;

    long total = long(max(0, b.width-1)) * max(0, b.height-1) * 2;
    if(total<=0) return 0;

    long diffSum;
    foreach(int y; bMin.y..bMax.y-1){
      int o0 = y*width_;
      foreach(int o; o0+bMin.x..o0+bMax.x-1){
        int p(int ofs){ return (data_[o+ofs] & 0xff00)>>8; }
        auto center = p(0);
        diffSum += (center - p(1     ))^^2+
                   (center - p(width_))^^2;
         //todo: this is kinda lame and slow
      }
    }

    return float(diffSum) / total;
  }
}}


// Bitmap Detection ///////////////////////////////////

immutable supportedBitmapExts = ["webp", "png", "jpg", "jpeg", "bmp", "tga"];
immutable supportedBitmapFilter = supportedBitmapExts.map!(a=>"*."~a).join(';');

File[] imageFiles(in Path p){
  return p.files(supportedBitmapFilter);
}

struct BitmapInfo{
  string format;
  V2i size;
  int chn;

  bool valid() const{ return supportedBitmapExts.canFind(format) && chn.inRange(1, 4); }

private static{

  bool isWebp(in ubyte[] s){ return s.length>16 && s[0..4].equal("RIFF") && s[8..15].equal("WEBPVP8") && s[15].among(' ', 'L', 'X'); }
  bool isJpg (in ubyte[] s){ return s.startsWith([0xff, 0xd8, 0xff]); }
  bool isPng (in ubyte[] s){ return s.startsWith([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]); }
  bool isBmp (in ubyte[] s){ return s.length>18 && s[0..2].equal("BM") && (cast(uint[])s[14..18])[0].among(12, 40, 52, 56, 108, 124); }

  bool isTga (in ubyte[] s){ //tga detection is really loose, so it's on the last place...
    if(s.length>18){
      auto us(int i){ return (cast(ushort[])s[i..i+2])[0]; }
      const badTga = (us(12) < 1 || us(14) < 1 || s[1] > 1
          || (s[1] == 0 && (us(3) || us(5) || s[7])) //palette is off, but has palette info
          || (4 <= s[2] && s[2] <= 8) || 12 <= s[2]); //format
      if(!badTga) return true;
    }
    return false;
  }

  string detectFormat(in File fileName, in ubyte[] stream){ alias s = stream;
    if(!stream.empty){
      if(isJpg (s)) return "jpg";
      if(isPng (s)) return "png";
      if(isBmp (s)) return "bmp";
      if(isWebp(s)) return "webp";
      if(isTga (s)) return "tga";
    }

    //unable to detect from stream, try fileExt
    if(stream.empty){
      string e = fileName.ext.lc;
      if(e.startsWith(".")) e = e[1..$];

      if(supportedBitmapExts.canFind(e)){
        if(e=="jpeg") e = "jpg"; //synonim
        return e;
      }
    }

    return "";
  }

}

private:

  void detectInfo(in ubyte[] stream){
    if(stream.empty) return;
    if(format=="webp"){ //use libWebp
      import webp.decode;

      WebPBitstreamFeatures features;
      if(WebPGetFeatures(stream.ptr, stream.length, &features)==VP8StatusCode.VP8_STATUS_OK){
        size = V2i(features.width, features.height);
        chn = features.has_alpha ? 4 : 3;
      }
    }else if(supportedBitmapExts.canFind(format)){ //use imageFormats package
      try{
        read_image_info_from_mem(stream, size.x, size.y, chn);
      }catch(Throwable){}
    }
  }

public:

  this(in File fileName, in ubyte[] stream){
    format = detectFormat(fileName, stream);

    if(format.empty) return;
    detectInfo(stream);
  }

  this(in ubyte[] stream){
    this(File(""), stream);
  }

  this(in File fileName){
    enum peekSize = 32;
    this(fileName, fileName.read(false, 0, peekSize));
  }

}

// Bitmap class //////////////////////////////////////////////////////////////////////////////

class Bitmap{    //todo: jsonize
private:
  Image!L8    i1; //todo: algebraic
  Image!LA8   i2;
  Image!RGB8  i3;
  Image!RGBA8 i4;

  void freeAll(){ i1.free; i2.free; i3.free; i4.free; }

  void chkChannels(int cnt){ enforce(cnt.inRange(1, 4), "channelCnt out of range ("~cnt.text~")"); }
public:
  int tag;

  override string toString() const { return format("Bitmap[%d*%d %dchn]", width, height, channels); }

  enum
    DefaultQuality = 95,
    LosslessQuality = 101;

  @property {
    int channels() const { return i4 ? 4 : i3 ? 3 : i2 ? 2 : i1 ? 1 : 0; }
    void channels(int chn){ chkChannels(chn);
      if(channels==chn) return;
      if(i1){                            if(chn==2) i2 = i1.to!LA8;  if(chn==3) i3 = i1.to!RGB8;  if(chn==4) i4 = i1.to!RGBA8;  i1.free; }else
      if(i2){ if(chn==1) i1 = i2.to!L8;                              if(chn==3) i3 = i2.to!RGB8;  if(chn==4) i4 = i2.to!RGBA8;  i2.free; }else
      if(i3){ if(chn==1) i1 = i3.to!L8;  if(chn==2) i2 = i3.to!LA8;                               if(chn==4) i4 = i3.to!RGBA8;  i3.free; }else
      if(i4){ if(chn==1) i1 = i4.to!L8;  if(chn==2) i2 = i4.to!LA8;  if(chn==3) i3 = i4.to!RGB8;                                i4.free; }
    }
  }

  @property {
    V2i size() const{
      return i4 ? i4.size : i3 ? i3.size : i2 ? i2.size : i1 ? i1.size : V2i.Null;
    }

    void size(in V2i s){
      if(i4) i4.size = s; else if(i3) i3.size = s; else if(i2) i2.size = s; else if(i1) i1.size = s;
    }
  }

  @property { int width () const { return size.x; } void width (int w){ size = V2i(w    , height); } }
  @property { int height() const { return size.y; } void height(int h){ size = V2i(width,      h); } }

  auto bounds() const { return Bounds2i(V2i.Null, size); }

  final bool empty() const { return (this is null) || !size.x || !size.y; } //final, so it is not virtual

  void realloc(in V2i size, int chn){ chkChannels(chn);
    freeAll;
    if(chn==1) i1 = new typeof(i1)(size);else
    if(chn==2) i2 = new typeof(i2)(size);else
    if(chn==3) i3 = new typeof(i3)(size);else
    if(chn==4) i4 = new typeof(i4)(size);
    this.size = size;
  }

  this(in V2i size, int chn = 4){
    realloc(size, chn);
  }

  this(int width, int height, int chn = 4){
    this(V2i(width, height), chn);
  }

  this(T)(Image!T src)if(isColor8!T){
    static if(is(T==L8   )) i1 = src;
    static if(is(T==LA8  )) i2 = src;
    static if(is(T==RGB8 )) i3 = src;
    static if(is(T==RGBA8)) i4 = src;
  }

  this(ubyte[] stream, bool raiseError = true){
    decode(stream, raiseError);
  }

  ~this(){
    size = V2i(0, 0); //release memory
  }

  int changedCnt() const{
    if(i4) return i4.changedCnt;
    if(i3) return i3.changedCnt;
    if(i2) return i2.changedCnt;
    if(i1) return i1.changedCnt;
    return -1;
  }

  void changed() {
    if(i4) return i4.changed;
    if(i3) return i3.changed;
    if(i2) return i2.changed;
    if(i1) return i1.changed;
  }

  auto rgba() { return i4; }
  auto rgb () { return i3; }
  auto la  () { return i2; }
  auto l   () { return i1; }

  ubyte[] data() {
    if(i4) return cast(ubyte[])i4.data;
    if(i3) return cast(ubyte[])i3.data;
    if(i2) return cast(ubyte[])i2.data;
    if(i1) return cast(ubyte[])i1.data;
    return [];
  }

  const(ubyte)[] cdata() const {
    if(i4) return cast(const(ubyte)[])i4.cdata;
    if(i3) return cast(const(ubyte)[])i3.cdata;
    if(i2) return cast(const(ubyte)[])i2.cdata;
    if(i1) return cast(const(ubyte)[])i1.cdata;
    return [];
  }

  Bitmap dup(){
    if(i1){ return new Bitmap(i1.dup); }
    if(i2){ return new Bitmap(i2.dup); }
    if(i3){ return new Bitmap(i3.dup); }
    if(i4){ return new Bitmap(i4.dup); }
    return null;
  }

  Bitmap to(T)(){
    if(i1){ return new Bitmap(i1.dup.to!T); } //todo: miert kell ide dup???!!!
    if(i2){ return new Bitmap(i2.dup.to!T); }
    if(i3){ return new Bitmap(i3.dup.to!T); }
    if(i4){ return new Bitmap(i4.dup.to!T); }
    return null;
  }

  Bitmap as(T)(){
    if(T.sizeof==channels) return this;
                      else return to!T;
  }

  Image!T asImage(T)(){
    static if(is(T==L8   )) return as!T.i1;else
    static if(is(T==LA8  )) return as!T.i2;else
    static if(is(T==RGB8 )) return as!T.i3;else
    static if(is(T==RGBA8)) return as!T.i4;else
    return null;
  }

  Bitmap extract_nearest(float x0, float y0, int w, int h, float xs=1, float ys=1){
    if(i1) return new Bitmap(.extract_nearest(i1, x0, y0, w, h, xs, ys));
    if(i2) return new Bitmap(.extract_nearest(i2, x0, y0, w, h, xs, ys));
    if(i3) return new Bitmap(.extract_nearest(i3, x0, y0, w, h, xs, ys));
    if(i4) return new Bitmap(.extract_nearest(i4, x0, y0, w, h, xs, ys));
    return null;
  }

  // Bitmap Stream Encode ///////////////////////////////////
  ubyte[] toPng(){ return write_png_to_mem(width, height, data); }
  ubyte[] toBmp(){ enforce(channels.among(3, 4), "8/16bit bmp not supported"); return write_bmp_to_mem(width, height, data); }
  ubyte[] toTga(){ enforce(channels.among(1, 3, 4), "16bit tga not supported"); return write_tga_to_mem(width, height, data); }
  ubyte[] toJpg(int quality = DefaultQuality){ raise("encoding to jpg not supported"); return []; }

  ubyte[] toWebp(int quality = DefaultQuality){
    import webp.encode;
    import core.stdc.stdlib : free;

    ubyte* output;
    size_t size;
    const lossy = quality<LosslessQuality;
    switch(channels){
      case 4: size = lossy ? WebPEncodeRGBA        (data.ptr, width, height, width*channels, quality, &output)
                           : WebPEncodeLosslessRGBA(data.ptr, width, height, width*channels,          &output);  break;
      case 3: size = lossy ? WebPEncodeRGB         (data.ptr, width, height, width*channels, quality, &output)
                           : WebPEncodeLosslessRGB (data.ptr, width, height, width*channels,          &output);  break;
      default: enforce(0, "8/16bit webp not supported"); //todo: Y, YA plane-kkal megoldani ezeket is
    }

    //todo: tovabbi info a webp-rol: az alpha az csak lossless modon van tomoritve. Lehet, hogy azt is egy Y-al kene megoldani...

    enforce(size, "WebPEncode failed.");

    ubyte[] res = output[0..size].dup;
    free(output);
    return res;
  }

  ubyte[] toWebpLossless(){ return toWebp(LosslessQuality); }

  ubyte[] encode(string fmt, int quality = DefaultQuality){
    switch(lc(fmt)){
      case "png": return toPng;
      case "tga": return toTga;
      case "bmp": return toBmp;
      case "jpg": case "jpeg": return toJpg(quality);
      case "webp": return toWebp(quality);
      default: raise(`unsupported format: "%s"`.format(fmt));
    }
    return [];
  }

  void saveTo(File fn, int quality = DefaultQuality){
    encode(fn.ext.withoutStarting("."), quality).saveTo(fn);
  }

  // Bitmap Stream Decode ///////////////////////////////////

  bool decode(ubyte[] stream, bool raiseError=false){
    try{
      auto info = BitmapInfo(stream);
      enforce(info.valid, "Invalid bitmap format");

      if(info.format=="webp"){
        import webp.decode;

        realloc(info.size, info.chn);
        switch(info.chn){
          case 3: WebPDecodeRGBInto (stream.ptr, stream.length, data.ptr, data.length, width*channels); break;
          case 4: WebPDecodeRGBAInto(stream.ptr, stream.length, data.ptr, data.length, width*channels); break;
          //todo: WebPDecodeYUVInto-val megcsinalni az 1 es 2 channelt.
          default: raise("webp 1-2chn not impl");
        }
      }else{ //imageFormats package

        auto img = read_image_from_mem(stream);
        enforce(img.c.inRange(1, 4), "imgformat: fatal error: channels out of range");

        freeAll;
        final switch(info.chn){
          case 1: i1 = new typeof(i1)(img.pixels, img.w, img.h); break;
          case 2: i2 = new typeof(i2)(img.pixels, img.w, img.h); break;
          case 3: i3 = new typeof(i3)(img.pixels, img.w, img.h); break;
          case 4: i4 = new typeof(i4)(img.pixels, img.w, img.h); break;
        }
      }

      return true;

    }catch(Throwable t){
      if(raiseError) throw t;
    }
    return false; //todo: return the error too
  }

  void loadFrom(File fn, bool raiseError=false){
    decode(fn.read(raiseError), raiseError);
  }

  // Bitmap image processing ////////////////////////////

  bool isGrayscale() const {
    if(empty || channels<=2) return true;
    return channels==3 ? i3.cdata.all!(c => c.r==c.g && c.r==c.b)
                       : i4.cdata.all!(c => c.r==c.g && c.r==c.b);
  }

  void invert(){
    //todo: az ilyen int3 debuggolasra kitalalni valami jobbat.
    cast(ubyte[])(data)[] ^= 0xff;  //todo: Bitmap.invert optimizaciojat megvizsgalni
  }

  Bitmap copyRect(int x0, int y0, int xs, int ys)const{
    if(x0<0 || x0+xs>width || y0+ys>height) raise("Out of range");
    if(xs<=0 || ys<=0) return null; //empty selection

    const ch = channels,
          dstLineSize = xs*ch,
          srcLineSize = width*ch,
          srcBase = x0*ch;

    Bitmap res = new Bitmap(xs, ys, ch);

    int srcOfs = (width*y0+x0)*ch, dstOfs;
    foreach(y; 0..ys){
      res.data[dstOfs..dstOfs+srcLineSize] = cdata[srcOfs..srcOfs+srcLineSize];
      srcOfs += srcLineSize;
      dstOfs += dstLineSize;
    }

    return res;
  }

}


// GdiBitmap class ////////////////////////////////////

class GdiBitmap{
  V2i size;
  HBITMAP hBitmap;
  static HDC hdcMem; //needs only one of this
  BITMAPINFO bmi;

  this(in V2i size, int channels=4){
    enforce(channels==4, "Only 32bit windows bitmaps supported");

    this.size = size;

    static HDC hdcScreen;
    if(!hdcScreen) hdcScreen = GetDC(null);
    if(!hdcMem) hdcMem  = CreateCompatibleDC(hdcScreen);

    hBitmap = CreateCompatibleBitmap(hdcScreen, size.x, size.y);
                                   //^^^^^^^^^ mest be hdcScreen, otherwise 1bit monochrome

    SelectObject(hdcMem, hBitmap);

    with(bmi.bmiHeader){
      biSize        = BITMAPINFOHEADER.sizeof;
      biWidth       = size.x;
      biHeight      = -size.y;
      biPlanes      = 1;
      biBitCount    = 32;
      biCompression = BI_RGB;
      biSizeImage   = size.x*size.y*4;
    }
  }

  this(int width, int height, int channels=4){ this(V2i(width, height), channels); }

  ~this(){
    DeleteObject(hBitmap);
    //and the hdcMem is static
  }

  Image!RGBA8 toImage(){
    auto img = new Image!RGBA8(size);
    if(!img.empty){
      if(!GetDIBits(hdcMem, hBitmap, 0, size.y, img.data.ptr, &bmi, DIB_RGB_COLORS)) raiseLastError;
    }
    return img;
  }

  Bitmap toBitmap(){ return new Bitmap(toImage); }
}


// FontDeclaration ///////////////////////////////

struct BitmapFontProps{
  string fontName = "Tahoma";
  int height = 32;
  int xScale = 1;
  bool clearType = false;
}

auto decodeFontDeclaration(string s, out string text){
  BitmapFontProps res;

  enforce(isFontDeclaration(s), `Not a font declaration. "%s" `.format(s));
  //example: `font:\Times New Roman\64\x3\ct?text`
  //                ^ fontName
  // optional size, x3: width*=3, x2, ct=clearType
  // last part is the text to write after the '?'

  s.split2("?", s, text, false/*no strip*/);

  auto p = s.split('\\').array;
  enforce(p.length>=2, `Invalid format. "%s"`.format(s));

  res.fontName = p[1];
  foreach(a; p[2..$]){
    int i; bool ok;
    try{ i = a.to!int; ok = true; }catch(Throwable){}
    if(ok){
      enforce(i.inRange(0, 0x10000), `Height out of range %d in "%s"`.format(i, s));
      res.height = i;
    }else if(a=="ct"){
      res.clearType = true;
    }else if(a=="x3"){
      res.xScale = 3;
    }else if(a=="x2"){
      res.xScale = 2;
    }else if(a==""){
      //empty is ok. Easier to make conditional declarations that way
    }else{
      enforce(0, `Invalid param "%s" in "%s"`.format(a, s));
    }
  }

  return res;
}

version(D2D_FONT_RENDERER){ private:
  // Direct2D stuff ////////////////////////////////////////////////////////

  pragma(lib, "D2d1.lib");
  pragma(lib, "DWrite.lib");

  alias FLOAT = float, UINT32 = uint, UINT64 = ulong, D2D1_TAG = UINT64;

  struct D2D_RECT_F{ float left=0, top=0, right=0, bottom=0;}
  alias D2D1_RECT_F = D2D_RECT_F;
  struct D2D1_COLOR_F { float r=0, g=0, b=0, a=1;}
  alias DWRITE_COLOR_F = D2D1_COLOR_F;
  struct D2D1_POINT_2F{ float x=0, y=0; }
  alias D2D1_SIZE_F = D2D1_POINT_2F;
  struct D2D1_SIZE_U { uint x=0, y=0; }
  struct D2D1_MATRIX_3X2_F{ float m11=1, m12=0, m21=0, m22=1, dx=0, dy=0; }
  struct DWRITE_TEXT_RANGE { uint start, length; }

  struct D2D1_RENDER_TARGET_PROPERTIES{
    int type, pixelFormat, alphaMode;
    float dpiX=0, dpiY=0;
    int usage, minLevel;
  }
  auto DCRenderTargetProps() { return D2D1_RENDER_TARGET_PROPERTIES(0, 87 /*DXGI_FORMAT_B8G8R8A8_UNORM*/, 3/*3:IGNORE, 2:STRAIGHT(unsupported)*/); }

  mixin( uuid!(ID2D1Factory, "06152247-6f50-465a-9245-118bfd3b6007") );
  interface    ID2D1Factory : IUnknown{ extern(Windows):
    HRESULT ReloadSystemMetrics();
    void GetDesktopDpi(/*out*/ FLOAT *dpiX,/*out*/ FLOAT *dpiY);
    HRESULT CreateRectangleGeometry(/**/);
    HRESULT CreateRoundedRectangleGeometry(/**/);
    HRESULT CreateEllipseGeometry(/**/);
    HRESULT CreateGeometryGroup(/**/);
    HRESULT CreateTransformedGeometry(/**/);
    HRESULT CreatePathGeometry(/**/);
    HRESULT CreateStrokeStyle(/**/);
    HRESULT CreateDrawingStateBlock(/**/);
    HRESULT CreateWicBitmapRenderTarget(/**/);
    HRESULT CreateHwndRenderTarget(/**/);
    HRESULT CreateDxgiSurfaceRenderTarget(/**/);
    HRESULT CreateDCRenderTarget(in D2D1_RENDER_TARGET_PROPERTIES renderTargetProperties, out ID2D1DCRenderTarget dcRenderTarget);
  }

  enum D2D1_FACTORY_TYPE:uint { SINGLE_THREADED, MULTI_THREADED, FORCE_DWORD = 0xffffffff }

  extern(Windows) HRESULT D2D1CreateFactory(D2D1_FACTORY_TYPE factoryType, REFIID riid, void* pFactoryOptions, out ID2D1Factory);

  enum D2D1_ANTIALIAS_MODE        :uint { PER_PRIMITIVE, ALIASED, FORCE_DWORD = 0xffffffff }
  enum D2D1_DRAW_TEXT_OPTIONS     :uint { NONE=0, NO_SNAP=1, CLIP=2, ENABLE_COLOR_FONT=4, FORCE_DWORD=0xffffffff }
  enum D2D1_TEXT_ANTIALIAS_MODE   :uint { DEFAULT, CLEARTYPE, GRAYSCALE, ALIASED, FORCE_DWORD = 0xffffffff }

  enum DWRITE_TEXT_ALIGNMENT      :int { LEADING, TRAILING, CENTER, JUSTIFIED }
  enum DWRITE_PARAGRAPH_ALIGNMENT :int { NEAR, FAR, CENTER }
  enum DWRITE_WORD_WRAPPING       :int { WRAP, NO_WRAP, EMERGENCY_BREAK, WHOLE_WORD, CHARACTER }
  enum DWRITE_READING_DIRECTION   :int { LEFT_TO_RIGHT, RIGHT_TO_LEFT, TOP_TO_BOTTOM, BOTTOM_TO_TOP }
  enum DWRITE_FLOW_DIRECTION      :int { TOP_TO_BOTTOM, BOTTOM_TO_TOP, LEFT_TO_RIGHT, RIGHT_TO_LEFT }
  enum DWRITE_TRIMMING_GRANULARITY:int { NONE, CHARACTER, WORD }
  enum DWRITE_LINE_SPACING_METHOD :int { DEFAULT, UNIFORM }
  enum DWRITE_FONT_WEIGHT         :int { THIN=100, EXTRA_LIGHT=200, ULTRA_LIGHT=200, LIGHT=300, SEMI_LIGHT=350, NORMAL=400, REGULAR=400, MEDIUM=500, DEMI_BOLD=600, SEMI_BOLD=600, BOLD=700, EXTRA_BOLD=800, ULTRA_BOLD=800, BLACK=900, HEAVY=900, EXTRA_BLACK=950, ULTRA_BLACK=950 }
  enum DWRITE_FONT_STRETCH        :int { UNDEFINED=0, ULTRA_CONDENSED=1, EXTRA_CONDENSED=2, CONDENSED=3, SEMI_CONDENSED=4, NORMAL=5, MEDIUM=5, SEMI_EXPANDED=6, EXPANDED=7, EXTRA_EXPANDED=8, ULTRA_EXPANDED=9 }
  enum DWRITE_FONT_STYLE          :int { NORMAL, OBLIQUE, ITALIC }

  struct DWRITE_TEXT_METRICS{
    float left, top,
      width, widthIncludingTrailingWhitespace,
      height,
      layoutWidth, layoutHeight;
    uint maxBidiReorderingDepth, lineCount;
  }

  mixin( uuid!(IDWriteTextFormat, "9c906818-31d7-4fd3-a151-7c5e225db55a") );
  interface    IDWriteTextFormat : IUnknown { extern(Windows):
    HRESULT SetTextAlignment(DWRITE_TEXT_ALIGNMENT textAlignment);
    HRESULT SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT paragraphAlignment);
    HRESULT SetWordWrapping(DWRITE_WORD_WRAPPING wordWrapping);
    HRESULT SetReadingDirection(DWRITE_READING_DIRECTION readingDirection);
    HRESULT SetFlowDirection(DWRITE_FLOW_DIRECTION flowDirection);
    HRESULT SetIncrementalTabStop(FLOAT incrementalTabStop);
    HRESULT SetTrimming(/**/);
    HRESULT SetLineSpacing(DWRITE_LINE_SPACING_METHOD lineSpacingMethod, FLOAT lineSpacing, FLOAT baseline);
    DWRITE_TEXT_ALIGNMENT GetTextAlignment();
    DWRITE_PARAGRAPH_ALIGNMENT GetParagraphAlignment();
    DWRITE_WORD_WRAPPING GetWordWrapping();
    DWRITE_READING_DIRECTION GetReadingDirection();
    DWRITE_FLOW_DIRECTION GetFlowDirection();
    FLOAT GetIncrementalTabStop();
    HRESULT GetTrimming(/**/);
    HRESULT GetLineSpacing(/*out*/ DWRITE_LINE_SPACING_METHOD* lineSpacingMethod, /*out*/ FLOAT* lineSpacing, /*out*/ FLOAT* baseline);
    HRESULT GetFontCollection(/**/);
    UINT32 GetFontFamilyNameLength();
    HRESULT GetFontFamilyName(/*out*/ WCHAR* fontFamilyName, UINT32 nameSize);
    DWRITE_FONT_WEIGHT GetFontWeight();
    DWRITE_FONT_STYLE GetFontStyle();
    DWRITE_FONT_STRETCH GetFontStretch();
    FLOAT GetFontSize();
    UINT32 GetLocaleNameLength();
    HRESULT GetLocaleName(/*out*/ WCHAR* localeName, UINT32 nameSize);
  }

  struct D2D1_BRUSH_PROPERTIES{
    FLOAT opacity = 1;
    D2D1_MATRIX_3X2_F transform;
  }

  mixin( uuid!(ID2D1Brush, "2cd906a8-12e2-11dc-9fed-001143a055f9") );
  interface    ID2D1Brush : ID2D1Resource { extern(Windows):
    void SetOpacity( FLOAT opacity );
    void SetTransform( in D2D1_MATRIX_3X2_F transform );
    FLOAT GetOpacity() const;
    void GetTransform( out D2D1_MATRIX_3X2_F transform ) const;
  }

  mixin( uuid!(ID2D1SolidColorBrush, "2cd906a9-12e2-11dc-9fed-001143a055f9") );
  interface    ID2D1SolidColorBrush : ID2D1Brush { extern(Windows):
    void SetColor( in D2D1_COLOR_F color);
    ref D2D1_COLOR_F GetColor() const; // BUG: got crash? see ID2D1RenderTarget.GetSize()
  }

  mixin( uuid!(ID2D1Resource, "2cd90691-12e2-11dc-9fed-001143a055f9") );
  interface    ID2D1Resource : IUnknown { extern(Windows):
    void GetFactory(out ID2D1Factory factory) const;
  }

  mixin( uuid!(ID2D1RenderTarget, "2cd90694-12e2-11dc-9fed-001143a055f9") );
  interface    ID2D1RenderTarget : ID2D1Resource { extern(Windows):
    HRESULT CreateBitmap(/**/);
    HRESULT CreateBitmapFromWicBitmap(/**/);
    HRESULT CreateSharedBitmap(/**/);
    HRESULT CreateBitmapBrush(/**/);
    HRESULT CreateSolidColorBrush(in D2D1_COLOR_F color, in D2D1_BRUSH_PROPERTIES brushProperties, out ID2D1SolidColorBrush solidColorBrush);
    HRESULT CreateGradientStopCollection(/**/);
    HRESULT CreateLinearGradientBrush(/**/);
    HRESULT CreateRadialGradientBrush(/**/);
    HRESULT CreateCompatibleRenderTarget(/**/);
    HRESULT CreateLayer(/**/);
    HRESULT CreateMesh(/**/);
    void DrawLine(/**/);
    void DrawRectangle(/**/);
    void FillRectangle(in D2D1_RECT_F rect, ID2D1Brush brush);
    void DrawRoundedRectangle(/**/);
    void FillRoundedRectangle(/**/);
    void DrawEllipse(/**/);
    void FillEllipse(/**/);
    void DrawGeometry(/**/);
    void FillGeometry(/**/);
    void FillMesh(/**/);
    void FillOpacityMask(/**/);
    void DrawBitmap(/**/);
    void DrawText(/**/);

    void DrawTextLayout(D2D1_POINT_2F origin, IDWriteTextLayout textLayout, ID2D1Brush defaultForegroundBrush,
      D2D1_DRAW_TEXT_OPTIONS options = D2D1_DRAW_TEXT_OPTIONS.NONE);

    void DrawGlyphRun(/**/);

    void SetTransform(in D2D1_MATRIX_3X2_F transform);
    void GetTransform(out D2D1_MATRIX_3X2_F transform) const;
    void SetAntialiasMode(D2D1_ANTIALIAS_MODE antialiasMode);
    D2D1_ANTIALIAS_MODE GetAntialiasMode() const;
    void SetTextAntialiasMode(D2D1_TEXT_ANTIALIAS_MODE textAntialiasMode);
    D2D1_TEXT_ANTIALIAS_MODE GetTextAntialiasMode() const;
    void SetTextRenderingParams(/**/); //todo: SetTextRenderingParams gdi classic-ra allitani, hogy szebb legyen az ui font, ekkor a 3x miatt pont cleartype-ra fog illeszkedni.
    void GetTextRenderingParams(/**/) const;
    void SetTags(D2D1_TAG tag1, D2D1_TAG tag2);
    void GetTags(/*out*/ D2D1_TAG *tag1 = null, /*out*/ D2D1_TAG *tag2 = null) const;
    void PushLayer(/**/);
    void PopLayer();
    HRESULT Flush(/*out*/ D2D1_TAG *tag1 = null, /*out*/ D2D1_TAG *tag2 = null);
    void SaveDrawingState(/**/) const;
    void RestoreDrawingState(/**/);
    void PushAxisAlignedClip(/**/);
    void PopAxisAlignedClip();

    void Clear(in D2D1_COLOR_F clearColor);

    void BeginDraw();
    HRESULT EndDraw(/*out*/ D2D1_TAG *tag1 = null,/*out*/ D2D1_TAG *tag2 = null);

    void GetPixelFormat(/**/) const;
    void SetDpi(/**/);
    void GetDpi(/*out*/ FLOAT *dpiX,/*out*/ FLOAT *dpiY) const;
    void GetSize(D2D1_SIZE_F* outSize) const; // <-- NOTE: ABI bug workaround, see D2D1_SIZE_F GetSize() below
    void GetPixelSize(D2D1_SIZE_U* outSize) const; // <-- NOTE: ABI bug workaround, see D2D1_SIZE_U GetPixelSize() below
    UINT32 GetMaximumBitmapSize() const;
    BOOL IsSupported(const(D2D1_RENDER_TARGET_PROPERTIES)* renderTargetProperties) const;
  }

  //------------------------------------------------------------------------------
  mixin( uuid!(ID2D1DCRenderTarget, "1c51bc64-de61-46fd-9899-63a5d8f03950") );
  interface    ID2D1DCRenderTarget : ID2D1RenderTarget { extern(Windows):
    HRESULT BindDC(const HDC  hDC, const(RECT)* pSubRect);
  }

  mixin( uuid!(IDWriteFactory, "b859ee5a-d838-4b5b-a2e8-1adc7d93db48") );
  interface    IDWriteFactory : IUnknown { extern(Windows):
    HRESULT GetSystemFontCollection(/**/);
    HRESULT CreateCustomFontCollection(/**/);
    HRESULT RegisterFontCollectionLoader(/**/);
    HRESULT UnregisterFontCollectionLoader(/**/);
    HRESULT CreateFontFileReference(/**/);
    HRESULT CreateCustomFontFileReference(/**/);
    HRESULT CreateFontFace(/**/);
    HRESULT CreateRenderingParams(/**/);
    HRESULT CreateMonitorRenderingParams(/**/);
    HRESULT CreateCustomRenderingParams(/**/);
    HRESULT RegisterFontFileLoader(/**/);
    HRESULT UnregisterFontFileLoader(/**/);

    HRESULT CreateTextFormat(const(WCHAR)* fontFamilyName, void* fontCollection,
      DWRITE_FONT_WEIGHT fontWeight, DWRITE_FONT_STYLE fontStyle, DWRITE_FONT_STRETCH fontStretch,
      FLOAT fontSize, const(WCHAR)* localeName, out IDWriteTextFormat textFormat);

    HRESULT CreateTypography(/**/);
    HRESULT GetGdiInterop(/**/);

    HRESULT CreateTextLayout(const(WCHAR)* string, UINT32 stringLength, IDWriteTextFormat textFormat,
      FLOAT maxWidth, FLOAT maxHeight, out IDWriteTextLayout textLayout);

    HRESULT CreateGdiCompatibleTextLayout(/**/);
    HRESULT CreateEllipsisTrimmingSign(/**/);
    HRESULT CreateTextAnalyzer(/**/);
    HRESULT CreateNumberSubstitution(/**/);
    HRESULT CreateGlyphRunAnalysis(/**/);
  }

  enum DWRITE_FACTORY_TYPE : int { SHARED, ISOLATED }

  export extern(C) HRESULT DWriteCreateFactory(DWRITE_FACTORY_TYPE factoryType, REFIID iid, out IDWriteFactory factory);

  mixin( uuid!(IDWriteTextLayout, "53737037-6d14-410b-9bfe-0b182bb70961") );
  interface    IDWriteTextLayout : IDWriteTextFormat { extern(Windows):
    HRESULT SetMaxWidth(FLOAT maxWidth);
    HRESULT SetMaxHeight(FLOAT maxHeight);
    HRESULT SetFontCollection(/**/);
    HRESULT SetFontFamilyName(const(WCHAR)* fontFamilyName, DWRITE_TEXT_RANGE textRange);
    HRESULT SetFontWeight(DWRITE_FONT_WEIGHT fontWeight, DWRITE_TEXT_RANGE textRange);
    HRESULT SetFontStyle(DWRITE_FONT_STYLE fontStyle, DWRITE_TEXT_RANGE textRange);
    HRESULT SetFontStretch(DWRITE_FONT_STRETCH fontStretch, DWRITE_TEXT_RANGE textRange);
    HRESULT SetFontSize(FLOAT fontSize, DWRITE_TEXT_RANGE textRange);
    HRESULT SetUnderline(BOOL hasUnderline, DWRITE_TEXT_RANGE textRange);
    HRESULT SetStrikethrough(BOOL hasStrikethrough, DWRITE_TEXT_RANGE textRange);
    HRESULT SetDrawingEffect(IUnknown drawingEffect, DWRITE_TEXT_RANGE textRange);
    HRESULT SetInlineObject(/**/);
    HRESULT SetTypography(/**/);
    HRESULT SetLocaleName(const(WCHAR)* localeName, DWRITE_TEXT_RANGE textRange);
    FLOAT GetMaxWidth();
    FLOAT GetMaxHeight();
    HRESULT GetFontCollection(/**/);
    HRESULT GetFontFamilyNameLength(UINT32 currentPosition, UINT32* nameLength, /*out*/ DWRITE_TEXT_RANGE* textRange = null);
    HRESULT GetFontFamilyName(UINT32 currentPosition, /*out*/ WCHAR* fontFamilyName, UINT32 nameSize, DWRITE_TEXT_RANGE* textRange = null);
    HRESULT GetFontWeight(UINT32 currentPosition, /*out*/ DWRITE_FONT_WEIGHT* fontWeight, /*out*/ DWRITE_TEXT_RANGE* textRange = null);
    HRESULT GetFontStyle(UINT32 currentPosition, /*out*/ DWRITE_FONT_STYLE* fontStyle, /*out*/ DWRITE_TEXT_RANGE* textRange = null);
    HRESULT GetFontStretch(UINT32 currentPosition,/*out*/ DWRITE_FONT_STRETCH* fontStretch, /*out*/ DWRITE_TEXT_RANGE* textRange = null);
    HRESULT GetFontSize(UINT32 currentPosition, /*out*/ FLOAT* fontSize, /*out*/ DWRITE_TEXT_RANGE* textRange = null);
    HRESULT GetUnderline(UINT32 currentPosition,/*out*/ BOOL* hasUnderline, /*out*/ DWRITE_TEXT_RANGE* textRange = null);
    HRESULT GetStrikethrough(UINT32 currentPosition, /*out*/ BOOL* hasStrikethrough, /*out*/ DWRITE_TEXT_RANGE* textRange = null);
    HRESULT GetDrawingEffect(UINT32 currentPosition, /*out*/ IUnknown* drawingEffect, /*out*/ DWRITE_TEXT_RANGE* textRange = null);
    HRESULT GetInlineObject(/**/);
    HRESULT GetTypography(/**/);
    HRESULT GetLocaleNameLength(UINT32 currentPosition, /*out*/ UINT32* nameLength, /*out*/ DWRITE_TEXT_RANGE* textRange = null);
    HRESULT GetLocaleName(UINT32 currentPosition, /*out*/ WCHAR* localeName, UINT32 nameSize, /*out*/ DWRITE_TEXT_RANGE* textRange = null);
    HRESULT Draw(/**/);
    HRESULT GetLineMetrics(/**/);
    HRESULT GetMetrics(out DWRITE_TEXT_METRICS textMetrics);
    HRESULT GetOverhangMetrics(/**/);
    HRESULT GetClusterMetrics(/**/);
    HRESULT DetermineMinWidth(/*out*/ FLOAT* minWidth);
    HRESULT HitTestPoint(/**/);
    HRESULT HitTestTextPosition(/**/);
    HRESULT HitTestTextRange(/**/);
  }


  class BitmapFontRenderer{ // BitmapFontRenderer ////////////////////////////
  private:
    BitmapFontProps props;
    alias props this;
    bool isSegoeAssets;

    ID2D1Factory d2dFactory;
    IDWriteFactory dwFactory;

    ID2D1DCRenderTarget dcrt;

    IDWriteTextFormat textFormat;
    ID2D1SolidColorBrush brush;

    bool mustRebuild = true;

    const
      white     = D2D1_COLOR_F(1, 1, 1),
      black     = D2D1_COLOR_F(0, 0, 0),
      heightScale = 0.75f;

    void initialize(){
      //Create factories
      D2D1CreateFactory(D2D1_FACTORY_TYPE.SINGLE_THREADED, &IID_ID2D1Factory, null, d2dFactory).hrChk("D2D1CreateFactory");
      DWriteCreateFactory(DWRITE_FACTORY_TYPE.SHARED, &IID_IDWriteFactory, dwFactory).hrChk("DWriteCreateFactory");

      //Create DCRenderTarget
      d2dFactory.CreateDCRenderTarget(DCRenderTargetProps, dcrt).hrChk("CreateDCRenderTarget");

      //Create brush
      dcrt.CreateSolidColorBrush(black, D2D1_BRUSH_PROPERTIES(1), brush).hrChk("CreateSolidColorBrush");
    }

    void rebuild(){
      if(!chkClear(mustRebuild)) return;

      isSegoeAssets = fontName=="Segoe MDL2 Assets";

      //Create font
      SafeRelease(textFormat);
      dwFactory.CreateTextFormat(fontName.toPWChar, null/*fontCollection*/,
        DWRITE_FONT_WEIGHT.REGULAR, DWRITE_FONT_STYLE.NORMAL, DWRITE_FONT_STRETCH.NORMAL,
        height*heightScale, "".toPWChar/*locale*/, textFormat
      ).hrChk("CreateTextFormat");

      dcrt.SetTransform(D2D1_MATRIX_3X2_F(xScale, 0, 0, 1, 0, 0));
      dcrt.SetTextAntialiasMode(clearType ? D2D1_TEXT_ANTIALIAS_MODE.CLEARTYPE : D2D1_TEXT_ANTIALIAS_MODE.GRAYSCALE);
    }

    void finalize(){
      SafeRelease(textFormat);
      SafeRelease(brush);
      SafeRelease(dcrt);
      SafeRelease(d2dFactory);
      SafeRelease(dwFactory);
    }
  public:
    this(){ initialize; }

    ~this(){ finalize; }

    void setProps(in BitmapFontProps props_){
      if(props==props_) return;
      props = props_;
      mustRebuild = true;
    }

    Bitmap render(in BitmapFontProps props_, string text){
      setProps(props_);
      return renderText(text);
    }

    Bitmap renderDecl(string fontDecl){
      string text;
      setProps(decodeFontDeclaration(fontDecl, text));
      return renderText(text);
    }

    Bitmap renderText(string text){
      enforce(!text.empty, "Nothing to render.");

      if(mustRebuild) rebuild;

      //a single space character needs special care
      const isSpace = text==" ";
      if(isSpace) text = "j";  //191229:????

      // Create text layout
      IDWriteTextLayout textLayout;
      auto ws = text.toUTF16;

      dwFactory.CreateTextLayout(ws.ptr, cast(uint)ws.length, textFormat, float.max, height, textLayout).hrChk("CreateTextLayout");
      scope(exit) SafeRelease(textLayout);

      // get text extents
      DWRITE_TEXT_METRICS metrics;
      textLayout.GetMetrics(metrics).hrChk("GetMetrics");

      auto bmpSize(){ return V2i((metrics.width*props.xScale).iRound, props.height); }

      if(isSpace){
        return new Bitmap(bmpSize, 1);
      }

      Bitmap doRender(bool inverse=false){
        auto gBmp = new GdiBitmap(bmpSize);
        scope(exit) gBmp.free;

        //draw
        auto rect = RECT(0, 0, gBmp.size.x, gBmp.size.y); //todo: this can be null???
        dcrt.BindDC(gBmp.hdcMem, &rect).hrChk("BindDC");

        dcrt.BeginDraw;
          dcrt.Clear(inverse ? white : black);
          brush.SetColor(inverse ? black : white);
          dcrt.DrawTextLayout(D2D1_POINT_2F(0, isSegoeAssets ? 0 : props.height*(-1.0f/18)), textLayout, brush, D2D1_DRAW_TEXT_OPTIONS.ENABLE_COLOR_FONT);
        dcrt.EndDraw.hrChk("EndDraw");

        return gBmp.toBitmap;
      }

      auto res = doRender;
      if(res.isGrayscale){
        res.channels = 1;
      }else{
        auto res2 = doRender(true);
        auto d1 = res.rgba.data, d2 = res2.rgba.data;

        //ha ide betuk keverednek, akkor aszoknak zajos lesz a konturjuk ugyanis nem csak a hatterszin valtozik,
        //hanem az eloteszin is. Az mar duplaannyi, mint kene.
        foreach(idx, ref p2; d2){
          auto p1 = d1[idx];

          //p2.a = ~cast(ubyte)(p2.r-p1.r);
          p2.a = cast(ubyte)(~(p2.r-p1.r));

          if(p2.a<0xff) p2.l = 0;
                   else p2.rbSwap;
        }

        res = res2;
      }

      if(isSegoeAssets){ //align the assets font with letters
        int ysh = iRound(res.height*0.16f);
        res = res.extract_nearest(0, -ysh, res.width, res.height);
        res.data[0..res.width*ysh] = 0;
      }

      return res;
    }
  }

  auto bitmapFontRenderer(){
    __gshared static BitmapFontRenderer r;
    if(!r) r = new BitmapFontRenderer();
    return r;
  }

}//version(D2D_FONT_RENDERER)

//Segoe Symbol database ////////////////////////////////
dchar segoeSymbolByName(string name){
  immutable tableData =
    "Wifi2=59507;UnderscoreSpace=59229;MailReply=59594;IBeam=59699;FolderHorizontal=61739;WifiCallBars=60372;StatusErrorCircle7=61624"~
    ";Dial6=61771;MobWifi1=60476;NarratorForwardMirrored=60842;BumperLeft=61708;Unpin=59258;CalendarReply=59637;Annotation=59684;Setl"~
    "ockScreen=59317;CollateLandscapeSeparated=62892;AlignLeft=59620;Attach=59171;ReturnKey=59217;ChromeAnnotateContrast=61689;Pinned"~
    "=59456;EndPoint=59419;DataSense=59281;Read=59587;AlignCenter=59619;PrintDefault=62829;VerticalBatteryCharging1=62974;ReminderFil"~
    "l=60239;ReturnToWindow=59716;CollapseContent=61797;eSIMNoProfile=63004;SyncError=60010;LanguageJpn=60485;PowerButton=59368;Keybo"~
    "ardRightAligned=61965;FlickRight=59704;CalligraphyPen=60923;KeyboardLeftDock=62061;Headset=59739;AppIconDefault=60586;SpatialVol"~
    "ume3=61678;People=59158;RepeatOne=59629;CallForwarding=59378;WifiWarning2=60257;TaskViewSettings=60992;FavoriteStar=59188;Grippe"~
    "rResizeMirrored=59984;WifiCall4=60377;Location=59421;MapPin=59143;CityNext2=60423;RoamingInternational=59512;Edit=59151;CityNext"~
    "=60422;GoToStart=59644;EMI=59185;BatterySaver2=59493;StatusDualSIM2=59522;Bluetooth=59138;ResizeMouseTallMirrored=60001;DeviceDi"~
    "scovery=60382;PieSingle=60165;ChevronLeftSmall=59759;LightningBolt=59717;ToggleFilled=60433;TreeFolderFolderOpenFill=60740;Chrom"~
    "eBackContrastMirrored=61654;PPSTwoLandscape=62859;AdjustHologram=60370;QuietHoursBadge12=61646;StaplingLandscapeTwoRight=62886;A"~
    "rrowLeft8=61616;CollapseContentSingle=61798;NUIFPStartSlideAction=60291;FileExplorer=60496;NUIFPContinueSlideHand=60292;SignalBa"~
    "rs1=59500;StatusCircleCheckmark=61758;Volume1=59795;PreviewLink=59553;Korean=59773;MobBattery6=60326;AddRemoteDevice=59446;Check"~
    "List=59861;ResizeMouseSmallMirrored=60000;BrushSize=60840;DeviceLaptopPic=59383;TiltDown=59402;DuplexLandscapeTwoSidedShortEdge="~
    "62850;Battery5=59477;ResizeTouchNarrowerMirrored=60002;PenWorkspaceMirrored=61205;MobileTablet=59596;FuzzyReading=62959;ResizeMo"~
    "useWide=59205;ProgressRingDots=61802;TaskView=59332;MobBatteryCharging6=60337;Forward=59178;DrivingMode=59372;ThisPC=60494;Direc"~
    "tAccess=59451;Connected=61625;SmallErase=61737;MicOff=60500;BandBattery2=60603;ExploreContentSingle=61796;ResizeTouchNarrower=59"~
    "370;InkingColorFill=60775;PaymentCard=59591;Photo=59675;NUIFPPressRepeatAction=60301;ActionCenter=59676;ChevronRightMed=59764;Vo"~
    "lume=59239;RightArrowKeyTime0=60391;CalculatorSquareroot=59723;Groceries=60425;InternetSharing=59140;ChecklistMirrored=61621;Att"~
    "achCamera=59554;DoublePinyin=61573;Underline=59612;Keyboard12Key=62049;Dialpad=59231;StrokeEraseMirrored=61207;DefenderBadge12=6"~
    "1691;BusSolid=60231;History=59420;MobSignal3=60473;AllAppsMirrored=59968;Package=59320;StopPoint=59418;ChromeMinimizeContrast=61"~
    "229;Share=59181;WifiError2=60252;AirplaneSolid=60236;RingerSilent=59373;Connect=59139;Repair=59663;StatusError=60035;Down=59211;"~
    "WifiCall3=60376;MusicSharingOff=63012;MusicNote=60495;MobBattery5=60325;MobBatterySaver7=60349;View=59536;EyeGaze=61853;SpeedHig"~
    "h=60490;GripperBarVertical=59268;PuncKey0=59468;Reply=59770;ExploreContent=60621;ChinesePunctuation=61713;ChromeMinimize=59681;B"~
    "andBattery5=60606;StatusCircleRing=61752;JpnRomanji=59516;ImportMirrored=59986;TrainSolid=60237;Trim=59274;Zoom=59166;RightQuote"~
    "=59465;ActionCenterNotification=59367;FileExplorerApp=60497;Lock=59182;Unit=60614;VerticalBattery7=62969;ErrorBadge=59961;DateTi"~
    "me=60562;Reshare=59627;HolePunchPortraitRight=62865;AddFriend=59642;Broom=60057;Input=59745;MobSIMError=62891;InkingColorOutline"~
    "=60774;UnsyncFolder=59638;Manage=59666;Stop=59162;CaretBottomRightSolidCenter8=61801;StatusCircleErrorX=61757;StatusTriangleOute"~
    "r=61753;JpnRomanjiShift=59518;VerticalBattery8=62970;DockLeft=59660;PenPaletteMirrored=61206;TollSolid=61793;PuncKeyLeftBottom=5"~
    "9469;FontSize=59625;Permissions=59607;MapCompassBottom=59411;Print=59209;OutlineHalfStarRight=61672;Streaming=59710;ToggleBorder"~
    "=60434;DisableUpdates=59608;Caption=59578;KeyboardNarrow=62048;Lightbulb=60032;Type=59772;Code=59715;BatterySaver5=59496;Landsca"~
    "peOrientationMirrored=62831;BrowsePhotos=59333;Dial5=61770;TreeFolderFolder=60737;PuncKey1=59828;CalculatorMultiply=59719;HWPScr"~
    "atchOut=62563;Ethernet=59449;SIPMove=59225;WifiCall1=60374;Globe=59252;Sensor=59735;Tiles=60581;MobBatterySaver5=60347;PoliceCar"~
    "=60545;DeviceMonitorLeftPic=59386;PageMarginPortraitNarrow=62835;Search=59169;Shop=59161;eSIMBusy=63006;TapAndSend=59809;HolePun"~
    "chPortraitBottom=62867;MobBatteryCharging10=60341;EmojiTabFavorites=60762;Dial7=61772;BandBattery3=60604;QWERTYOn=59778;MusicAlb"~
    "um=59708;CheckboxIndeterminateCombo14=61805;Wifi=59137;WifiError0=60250;StatusSGLTECell=59527;Set=62957;VerticalBatteryCharging0"~
    "=62973;ResizeTouchSmaller=59202;MobSignal1=60471;Like=59617;Battery10=59455;DuplexLandscapeTwoSidedShortEdgeMirrored=62851;Flick"~
    "Down=59701;MapDirections=59414;DuplexPortraitTwoSidedLongEdge=62854;Tag=59628;CopyTo=62483;TabletSelected=60532;ResizeMouseMediu"~
    "m=59204;MobWifi2=60477;Devices2=59765;DuplexLandscapeTwoSidedLongEdge=62848;PageLeft=59232;NUIFPStartSlideHand=60290;FullScreen="~
    "59200;Lexicon=61824;NewWindow=59275;BumperRight=61709;SendMirrored=60003;Speakers=59381;Tablet=59146;MobeSIMBusy=60717;Accident="~
    "59423;ClippingTool=62470;StatusPause7=61813;StatusDualSIM1VPN=59525;CheckboxComposite=59194;Frigid=59850;DictionaryCloud=60355;L"~
    "ockScreenGlance=61029;Website=60225;TouchPointer=59337;ChinesePinyin=59786;StrokeErase2=61736;MailReplyAll=59586;TwoPage=59546;M"~
    "obBatteryCharging9=60340;Characters=59585;CalendarWeek=59584;Click=59568;MyNetwork=60455;ExpandTileMirrored=59982;StatusCheckmar"~
    "kLeft=61913;VerticalBattery6=62968;MobBatterySaver4=60346;DefenderApp=59453;Dpad=61710;Dictionary=59437;ExportMirrored=60898;Ren"~
    "ame=59564;TriggerRight=61707;DMC=59729;EraseTool=59228;ChromeRestoreContrast=61231;StatusVPN=59529;CalendarMirrored=60712;Constr"~
    "uctionCone=59791;eSIMLocked=63005;CallForwardRoamingMirrored=59972;Cafe=60466;Record=59336;ReturnKeySm=59750;Construction=59426;"~
    "MailForwardMirrored=59990;ParkingLocationSolid=60043;BatteryCharging1=59483;HWPNewLine=62565;QuarentinedItems=61618;AddTo=60616;"~
    "WifiWarning0=60255;MobSignal2=60472;PenTips=62558;MusicSharing=63011;SpatialVolume2=61677;BatterySaver4=59495;NUIFace=60264;Bull"~
    "etedList=59645;Favicon=59191;MusicInfo=59659;MobBattery7=60327;SearchAndApps=59251;StatusCheckmark=61912;LangJPN=59358;StatusCir"~
    "cleBlock2=61761;DrawSolid=60552;QuarterStarLeft=61642;Key12On=59776;PageMarginLandscapeNarrow=62839;Remove=59192;Add=59152;Comma"~
    "ndPrompt=59222;PenTipsMirrored=62559;Safe=62784;Walk=59397;OutlineStarLeftHalf=61687;Warning=59322;Earbud=62656;PageMirrored=628"~
    "30;ClearSelectionMirrored=59976;DuplexPortraitOneSided=62852;PenWorkspace=60870;JpnRomanjiLock=59517;ChromeSwitchContast=61900;M"~
    "obWifi3=60478;InkingTool=59245;MediaStorageTower=59749;Ferry=59363;Switch=59563;SpeedOff=60488;LeaveChat=59547;ContactInfoMirror"~
    "ed=59978;PPSOneLandscape=62858;Delete=59213;SignatureCapture=61247;DynamicLock=62521;RotateCamera=59550;InkingToolFill=59535;Cer"~
    "tificate=60309;ArrowDown8=61614;HalfDullSound=59824;Airplane=59145;MobBattery8=60328;StatusCircleOuter=61750;MobBatteryCharging4"~
    "=60335;CheckboxCompositeReversed=59197;SpatialVolume1=61676;ResizeMouseLarge=59207;StreamingEnterprise=60719;VerticalBattery4=62"~
    "966;Export=60897;WifiError1=60251;Video=59156;Devices3=60012;CellPhone=59626;MailFill=59560;eSIM=63003;Battery0=59472;BatteryCha"~
    "rging0=59482;Movies=59570;OpenFolderHorizontal=60709;ZoomIn=59555;HolePunchOff=62863;CalculatorBackspace=59727;LineDisplay=61245"~
    ";HeadlessDevice=61841;StatusErrorFull=60304;CalculatorPercentage=59724;CaretRightSolid8=60890;VerticalBatteryCharging3=62976;Tra"~
    "fficCongestionSolid=61795;Touchpad=61349;MobSIMLock=59509;SurfaceHub=59566;Microphone=59168;BatterySaver0=59491;ScrollUpDown=605"~
    "59;MicError=60502;SIPRedock=59227;NetworkTower=60421;SetTile=59771;HWPStrikeThrough=62562;Info2=59935;OutlineQuarterStarLeft=616"~
    "69;BandBattery4=60605;IBeamOutline=59700;Equalizer=59881;RightArrowKeyTime2=59463;Component=59728;Page=59331;GroupList=61800;Bat"~
    "teryCharging4=59486;LanguageKor=59531;NewFolder=59636;MicOn=60529;MailReplyMirrored=59991;ZoomOut=59167;NarratorForward=60841;Ri"~
    "ghtArrowKeyTime1=59462;BarcodeScanner=60506;FlickUp=59702;SurfaceHubSelected=62654;RotationLock=59221;DeviceLaptopNoPic=59384;Ch"~
    "evronUp=59150;TreeFolderFolderOpen=60739;Relationship=61443;CalculatorDivide=59722;StatusCheckmark7=61623;WindowsInsider=61869;G"~
    "oMirrored=59983;MobBatteryCharging1=60332;SwitchApps=59641;Battery4=59476;QuietHours=59144;BatterySaver8=59499;Robot=59802;PageM"~
    "arginLandscapeNormal=62840;StaplingPortraitTwoLeft=62876;NetworkConnected=62341;StatusInfoLeft=62413;GlobalNavigationButton=5913"~
    "6;ForwardMirrored=61651;SetSolid=62958;PanMode=60649;UpdateRestore=59255;MobActionCenter=60482;Draw=60551;MiracastLogoLarge=6043"~
    "8;PrintAllPages=62833;WifiCall2=60375;NoiseCancelationOff=63008;TabletMode=60412;FullHiragana=59782;Devices=59250;SIMMissing=630"~
    "01;VerticalBattery5=62967;SaveAs=59282;AddSurfaceHub=60612;CashDrawer=60505;ShowResults=59580;Heart=60241;Swipe=59687;NetworkPri"~
    "nter=60837;SendFill=59173;Previous=59538;Design=60220;ResizeMouseMediumMirrored=59999;BatteryCharging3=59485;BackSpaceQWERTYMd=5"~
    "9686;Street=59667;Bank=59429;Light=59283;RedEye=59315;VerticalBatteryCharging4=62977;Apps=60725;CaretDownSolid8=60892;XboxOneCon"~
    "sole=59792;NUIFPRollLeftHand=60296;ImportAllMirrored=59987;StatusUnsecure=60249;HardDrive=60834;ThoughtBubble=60049;StatusTriang"~
    "leLeft=60414;Wifi1=59506;ButtonMenu=60899;DuplexLandscapeTwoSidedLongEdgeMirrored=62849;ChevronUpSmall=59757;BuildingEnergy=6042"~
    "7;CompletedSolid=60513;ShoppingCart=59327;DevUpdate=60613;Back=59179;PPSTwoPortrait=62860;DetachablePC=61699;Bold=59613;Multimed"~
    "iaDVR=59732;KeyboardOneHanded=60748;MoveToFolder=59614;GotoToday=59601;Preview=59647;USBSafeConnect=60659;Dock=59730;MobBatteryS"~
    "aver2=60344;StaplingLandscapeBookBinding=62889;MobWifi4=60479;Copy=59592;ButtonB=61588;SmartcardVirtual=59748;MobBatterySaver9=6"~
    "0351;Asterisk=59960;VerticalBatteryCharging2=62975;OpenPane=59552;StaplingPortraitBookBinding=62880;ChromeBack=59440;InfoSolid=6"~
    "1799;Devices4=60262;WifiHotspot=59530;Sustainable=60426;KeyboardBrightness=60729;HolePunchPortraitLeft=62864;HomeGroup=60454;Und"~
    "o=59303;ContactSolid=60044;OtherUser=59374;StaplingLandscapeTopRight=62882;LockFeedback=60379;ReplyMirrored=60981;Dislike=59616;"~
    "HomeSolid=60042;BatteryCharging10=60051;LandscapeOrientation=61291;TrafficLight=61233;DullSoundKey=59823;ReadingList=59324;Spati"~
    "alVolume0=61675;WifiEthernet=61047;ChevronDownMed=59762;Webcam=59576;ResetDrive=60356;DuplexLandscapeOneSided=62846;HolePunchLan"~
    "dscapeLeft=62868;MapCompassTop=59410;MobBatteryUnknown=60418;NetworkSharing=61843;SwitchUser=59208;ResizeTouchShorter=59371;TVMo"~
    "nitor=59380;GameConsole=59751;CallForwardRoaming=59515;ShowBcc=59588;StatusTriangleExclamation=61755;PresenceChicklet=59768;Remo"~
    "te=59567;Dial16=61781;Media=60009;ProtectedDocument=59558;ReceiptPrinter=60507;StatusCircleLeft=60413;Unfavorite=59609;ShowResul"~
    "tsMirrored=60005;Label=59698;CalendarSolid=60041;BackSpaceQWERTY=59216;Mouse=59746;TaskbarPhone=61028;ChromeFullScreenContrast=6"~
    "1656;ChromeFullScreen=59693;DialUp=59452;ResizeMouseTall=59206;Pause=59241;Rotate=59309;RepeatAll=59630;Narrator=60749;ParkingLo"~
    "cationMirrored=59998;StaplingPortraitBottomRight=62875;Health=59742;BatteryCharging2=59484;BatterySaver9=60052;ChromeBackToWindo"~
    "wContrast=61655;TreeFolderFolderFill=60738;IOT=61996;SyncFolder=59639;HalfKatakana=59784;LaptopSelected=60534;SyncBadge12=60843;"~
    "FontDecrease=59623;CaretUpSolid8=60891;ChatBubbles=59634;Cancel=59153;Megaphone=59273;PersonalFolder=60453;StreetsideSplitMinimi"~
    "ze=59394;BatteryCharging5=59487;EmojiTabCelebrationObjects=60757;Badge=60443;KeyboardDock=62059;ClearAllInk=60770;StatusCircle7="~
    "61622;Photo2=60319;ButtonA=61587;BidiRtl=59819;MobBatteryCharging5=60336;FreeFormClipping=62472;Video360=61745;StockUp=60177;Bid"~
    "iLtr=59818;DateTimeMirrored=61075;NUIFPPressRepeatHand=60300;Process=59891;MobBatterySaver8=60350;Reminder=60240;DuplexPortraitT"~
    "woSidedShortEdgeMirrored=62857;QuarentinedItemsMirrored=61619;LeftStick=61704;Dial15=61780;StorageTape=59754;VerticalBattery3=62"~
    "965;CalculatorEqualTo=59726;BatterySaver3=59494;ViewAll=59561;OneBar=59653;Courthouse=60424;PostUpdate=59635;LEDLight=59265;Coll"~
    "ateLandscape=62843;GripperBarHorizontal=59247;HalfStarLeft=59334;PointEraseMirrored=61208;StatusDualSIM1=59524;StatusCircleInner"~
    "=61751;LeftQuote=59464;ArrowRight8=61615;Family=60378;WifiError4=60254;OpenPaneMirrored=59995;ChromeClose=59579;LeftArrowKeyTime"~
    "0=60498;Drop=60226;Dial11=61776;Car=59396;MicClipping=60530;NUIIris=60263;Webcam2=59744;ChevronLeft=59243;VPN=59141;StartPointSo"~
    "lid=60233;StatusWarning=60036;SIMError=63000;LaptopSecure=62802;MobBatterySaver10=60352;RadioBtnOff=60618;KnowledgeArticle=61440"~
    ";MobBatterySaver3=60345;Upload=59544;MobBattery10=60330;WifiCall0=60373;EmojiTabFoodPlants=60758;NetworkOffline=62340;Message=59"~
    "581;StaplingPortraitBottomLeft=62894;ContactInfo=59257;ImportAll=59574;SaveLocal=59276;StaplingPortraitTwoTop=62878;DullSound=59"~
    "665;PC1=59767;StatusConnecting1=60247;Play36=61002;ArrowUp8=61613;StatusCircleInfo=61759;EditMirrored=60286;OutlineHalfStarLeft="~
    "61671;HolePunchLandscapeBottom=62871;SliderThumb=60435;MicrophoneListening=61742;VerticalBatteryCharging5=62978;Shuffle=59569;Ba"~
    "ndBattery6=60607;NearbySharing=62434;Stopwatch=59670;RevToggleKey=59461;Accounts=59664;WifiError3=60253;MobeSIMLocked=60716;Chro"~
    "meAnnotate=59697;OpenLocal=59610;OpenInNewWindow=59559;LanguageChs=59533;Subtitles=60702;DataSenseBar=59301;PlaybackRateOther=60"~
    "504;KeyboardRightHanded=59236;InteractiveDashboard=62468;VolumeBars=60357;ActionCenterQuiet=61049;LargeErase=61738;Cloud=59219;B"~
    "attery9=59481;Comment=59658;Italic=59611;BatteryCharging9=59454;PuncKey4=59831;DockRightMirrored=59979;TwoBars=59654;CalendarDay"~
    "=59583;PPSFourLandscape=62861;Memo=59260;FontColor=59603;MobBatteryCharging2=60333;TimeLanguage=59253;KeyboardShortcut=60839;TVM"~
    "onitorSelected=60535;CircleRingBadge12=60847;PaginationDotSolid10=61735;PlayBadge12=60853;HorizontalTabKey=59389;MultimediaPMP=5"~
    "9733;DuplexPortraitTwoSidedLongEdgeMirrored=62855;DashKey=59822;HWPOverwrite=62566;LikeDislike=59615;BookmarksMirrored=59969;Rot"~
    "ateMapLeft=59405;PointErase=60769;KeyboardDismiss=59695;Projector=59741;CaretRight8=60886;NetworkConnectedCheckmark=62342;ListMi"~
    "rrored=59989;PLAP=60441;StockDown=60175;MultimediaDMS=59731;Error=59267;Home=59407;ToggleThumb=60436;Sync=59541;CC=59376;Insider"~
    "HubApp=60452;Dial2=61767;KeyboardLeftAligned=61964;PresenceChickletVideo=59769;Marker=60772;Network=59752;BatterySaver6=59497;Mo"~
    "bBattery2=60322;ClipboardListMirrored=61668;StatusSGLTEDataVPN=59528;PuncKey3=59830;ChineseChangjie=59777;HalfAlpha=59774;Batter"~
    "yCharging8=59490;PencilFill=61638;MobileSelected=60533;ChevronRightSmall=59760;DockLeftMirrored=59980;LockscreenDesktop=60991;Si"~
    "gnalBars5=59504;MobWifiWarning1=62579;SendFillMirrored=60004;Touchscreen=60836;DictionaryAdd=59438;Priority=59600;PuncKey=59460;"~
    "Japanese=59781;Cut=59590;WalkSolid=59174;HoloLensSelected=62655;SkipBack10=60732;DownloadMap=59430;HighlightFill2=59434;MobBatte"~
    "ryCharging3=60334;More=59154;MobileLocked=60448;Protractor=61620;EmojiTabTransitPlaces=60759;GripperResize=59272;Send=59172;Info"~
    "=59718;ErrorBadge12=60846;CallForwardInternational=59514;PinFill=59457;SettingsDisplaySound=59379;Save=59214;SelectAll=59571;Key"~
    "boardSplit=59238;MixVolumes=62659;Clear=59540;RightStick=61705;Emoji=59545;OEM=59212;MobCallForwarding=60542;ChromeSwitch=61899;"~
    "MobWifiWarning4=62582;Volume2=59796;Pin=59160;Calendar=59271;ThreeQuarterStarLeft=61644;Work=59425;SIPUndock=59226;HWPJoin=62560"~
    ";Bullseye=62066;ClipboardList=61667;RoamingDomestic=59513;OutlineThreeQuarterStarLeft=61673;UnknownMirrored=61998;SignalNotConne"~
    "cted=59505;FeedbackApp=59705;Dial9=61774;OpenWith=59308;BatterySaver1=59492;WifiWarning3=60258;EthernetWarning=60246;Smartcard=5"~
    "9747;MailForward=59548;StatusDataTransferVPN=59521;USB=59534;SaveCopy=59957;MiracastLogoSmall=60437;ThreeBars=59655;BatterySaver"~
    "7=59498;Next=59539;KeyboardLowerBrightness=60730;ButtonX=61590;ChineseBoPoMoFo=59785;EraseToolFill=59435;PenPalette=61014;Headph"~
    "one=59382;BandBattery1=60602;VerticalBattery10=62972;OutlineThreeQuarterStarRight=61674;CtrlSpatialRight=61723;BatteryUnknown=59"~
    "798;Radar=60228;Group=59650;ResizeTouchLarger=59201;HeartFill=60242;CalculatorNegate=59725;SDCard=59377;HMD=61721;QuickNote=5914"~
    "7;FerrySolid=60232;Battery3=59475;MobBatterySaver0=60342;AllApps=59165;MobLocation=60483;Battery1=59473;Feedback=60693;Companion"~
    "App=60516;MobBatteryCharging0=60331;MobBattery1=60321;Wheel=61076;Redo=59302;Checkbox=59193;CircleFill=59963;BackgroundToggle=61"~
    "215;StatusInfo=62412;StatusErrorLeft=60415;ParkingLocation=59409;StatusCircleQuestionMark=61762;Admin=59375;EmojiSwatch=60763;Do"~
    "wnload=59542;HolePunchLandscapeRight=62869;DownShiftKey=59466;HolePunchPortraitTop=62866;RightArrowKeyTime3=59470;BulletedListMi"~
    "rrored=59970;Import=59573;StopPointSolid=60234;NUIFPRollLeftAction=60297;VideoSolid=59916;MobBattery9=60329;CalculatorAddition=5"~
    "9720;MagStripeReader=60508;PuncKey5=59832;VerticalBatteryUnknown=62984;Processing=59893;MailBadge12=60851;EaseOfAccess=59254;Dev"~
    "iceMonitorRightPic=59385;NUIFPRollRightHandAction=60295;Camera=59170;DeveloperTools=60538;NUIFPPressHand=60298;Brightness=59142;"~
    "ChevronRight=59244;PinnedFill=59458;Filter=59164;System=59248;ImageExport=61041;Contact=59259;StatusTriangle=60034;MobBatteryCha"~
    "rging8=60339;RightArrowKeyTime4=59471;FingerInking=60767;MobeSIM=60714;OpenFile=59621;KeyboardLeftHanded=59235;StaplingLandscape"~
    "TwoBottom=62888;StreetsideSplitExpand=59395;DuplexLandscapeOneSidedMirrored=62847;PeriodKey=59459;ConnectApp=60764;Beta=59940;Fo"~
    "lder=59575;LeaveChatMirrored=59988;ChromeBackMirrored=59975;LanguageCht=59532;Replay=61243;DuplexPortraitTwoSidedShortEdge=62856"~
    ";OutlineStarRightHalf=61688;Communications=59738;VerticalBatteryCharging6=62979;CheckboxIndeterminateCombo=61806;ButtonY=61589;A"~
    "lignRight=59618;ChromeRestore=59683;StorageNetworkWireless=59753;Color=59280;MobBatterySaver1=60343;Help=59543;PPSFourPortrait=6"~
    "2862;FontIncrease=59624;CallForwardingMirrored=60055;StaplingPortraitTopLeft=62873;EmojiTabTextSmiles=60761;Battery2=59474;Trigg"~
    "erLeft=61706;StaplingOff=62872;Calculator=59631;Trackers=60127;ChevronUpMed=59761;Rewind=60318;SignalRoaming=60446;PINPad=61246;"~
    "BandBattery0=60601;Dial12=61777;PointerHand=62065;Highlight=59366;PasswordKeyShow=59816;StaplingLandscapeTopLeft=62881;Diagnosti"~
    "c=59865;Wifi3=59508;ClearAllInkMirrored=61209;Checkbox14=61803;PinyinIMELogo=60901;MobWifiWarning3=62581;StatusCircleExclamation"~
    "=61756;Eyedropper=61244;PageMarginLandscapeWide=62842;RectangularClipping=62471;SettingsBattery=61027;Dial13=61778;Leaf=59582;Fi"~
    "tPage=59814;ColorOff=62832;RememberedDevice=59148;CaretLeftSolid8=60889;SubtitlesAudio=60703;PlaybackRate1x=60503;Printer3D=5966"~
    "8;FullCircleMask=59679;TaskViewExpanded=60305;CheckboxFill=59195;MobBattery0=60320;Dial4=61769;AreaChart=59858;BatterySaver10=60"~
    "053;Unlock=59269;ZoomMode=60648;PuncKeyRightBottom=59827;Headphone2=60722;VerticalBattery9=62971;Touch=59413;Volume3=59797;Audio"~
    "=59606;StatusTriangleInner=61754;Dial8=61773;PageMarginLandscapeModerate=62841;OutlineQuarterStarRight=61670;GuestUser=61015;Cal"~
    "culatorSubtract=59721;BatteryCharging7=59489;ClearSelection=59622;Personalize=59249;World=59657;PassiveAuthentication=62250;Sign"~
    "alBars4=59503;EthernetError=60245;PaginationDotOutline10=61734;HighlightFill=59537;ChromeBackContrast=61653;ActionCenterAsterisk"~
    "=59937;Puzzle=60038;MobBattery4=60324;PuncKey2=59829;Play=59240;Settings=59155;StatusExclamationCircle7=61743;HolePunchLandscape"~
    "Top=62870;Completed=59696;MobeSIMNoProfile=60715;Dial3=61768;ActionCenterMirrored=60685;KeyboardFull=60465;WifiWarning4=60259;So"~
    "rt=59595;StatusCircle=60033;ScrollMode=60647;WorkSolid=60238;SIMLock=63002;AccidentSolid=60046;Library=59633;PageMarginPortraitM"~
    "oderate=62837;Emoji2=59246;PartyLeader=60583;CompanionDeviceFramework=60765;CommaKey=59821;PhoneBook=59264;HeartBroken=60050;Sta"~
    "plingLandscapeTwoTop=62887;MobBatterySaver6=60348;MobSignal4=60474;HalfStarRight=59335;KeyboardSettings=61968;BlueLight=61580;Si"~
    "gnalBars3=59502;ProvisioningPackage=59445;PuncKey9=59834;Bug=60392;NoiseCancelation=63007;StaplingPortraitTopRight=62874;UserAPN"~
    "=61569;RingerBadge12=60844;HideBcc=59589;FastForward=60317;CircleRing=59962;BackSpaceQWERTYSm=59685;IncidentTriangle=59412;Direc"~
    "tions=59632;Mute=59215;Accept=59643;UpArrowShiftKey=59218;NUIFPPressAction=60299;UpShiftKey=59467;StaplingLandscapeBottomRight=6"~
    "2884;PageMarginPortraitWide=62838;SlowMotionOn=60025;FlickLeft=59703;InkingCaret=60773;CollatePortraitSeparated=62845;PageMargin"~
    "PortraitNormal=62836;ReportDocument=59897;SkipForward30=60733;Slideshow=59270;CloudSeach=60900;BodyCam=60544;Orientation=59572;R"~
    "esizeMouseSmall=59203;ChevronDown=59149;WindDirection=60390;StatusDataTransfer=59520;ThreeQuarterStarRight=61645;Battery8=59480;"~
    "DisconnectDisplay=59924;LowerBrightness=60554;MobSIMMissing=59510;Project=60358;PlayerSettings=61272;Flag=59329;MapPin2=59319;Pa"~
    "geRight=59233;EmojiTabSymbols=60760;FolderFill=59605;DialShape3=61784;StaplingPortraitTwoRight=62877;MapDrive=59598;RightDoubleQ"~
    "uote=59825;BackToWindow=59199;Sticker2=62634;RotateMapRight=59404;FullKatakana=59783;VerticalBatteryCharging7=62980;ZeroBars=596"~
    "52;PrintfaxPrinterFile=59734;NUIFPContinueSlideAction=60293;ImportantBadge12=60849;Education=59326;ActionCenterNotificationMirro"~
    "red=60684;ButtonView2=61130;NUIFPRollRightHand=60294;CheckboxComposite14=61804;Scan=59646;VerticalBattery0=62962;CheckMark=59198"~
    ";Calories=60589;Volume0=59794;SpeedMedium=60489;ExploitProtectionSettings=62041;MobWifiHotspot=60484;Bookmarks=59556;HelpMirrore"~
    "d=59985;GIF=62633;ChipCardCreditCardReader=61248;MapLayers=59422;FourBars=59656;Handwriting=59689;ClosePane=59551;Go=59565;PageS"~
    "olid=59177;PuncKey6=59833;BackMirrored=61650;Dial14=61779;PrintCustomRange=62834;CollatePortrait=62844;FolderOpen=59448;Ruler=60"~
    "766;Picture=59577;Ear=62064;ResetDevice=60688;VerticalBatteryCharging10=62983;GiftboxOpen=61747;MicSleep=60501;Refresh=59180;Wir"~
    "edUSB=60656;StatusConnecting2=60248;CloudPrinter=60838;ChromeMaximize=59682;MultiSelect=59234;ChevronDownSmall=59758;LeftDoubleQ"~
    "uote=59826;CtrlSpatialLeft=62439;MobSignal5=60475;Headphone0=60720;BatteryCharging6=59488;RadioBullet=59669;WirelessUSB=60657;Pa"~
    "ste=59263;Game=59388;KeyboardUndock=62060;Headphone3=60723;KeyboardRightDock=62062;AsteriskBadge12=60845;GridView=61666;Speech=6"~
    "1353;InkingToolFill2=59433;StatusSGLTE=59526;PasswordKeyHide=59817;MailReplyAllMirrored=59992;OpenWithMirrored=59996;StaplingLan"~
    "dscapeTwoLeft=62885;Font=59602;KeyboardStandard=59694;StatusCircleBlock=61760;ExpandTile=59766;CheckboxIndeterminate=59196;MobBa"~
    "ttery3=60323;NetworkAdapter=60835;ChromeCloseContrast=61228;TiltUp=59401;DefaultAPN=61568;DialShape4=61785;Vibrate=59511;ChromeB"~
    "ackToWindow=59692;ChineseQuick=59780;StatusWarningLeft=60416;TrackersMirrored=61074;MobDrivingMode=60487;VerticalBatteryCharging"~
    "8=62981;ReturnKeyLg=60311;ReportHacked=59184;RemoveFrom=60617;Train=59328;DialShape2=61783;GripperTool=59230;Recent=59427;PlaySo"~
    "lid=62896;List=59959;VerticalBattery1=62963;Bus=59398;FavoriteStarFill=59189;MobBatteryCharging7=60338;Link=59163;HWPInsert=6256"~
    "1;Marquee=61216;StaplingLandscapeBottomLeft=62883;Mail=59157;StorageOptical=59736;QuarterStarRight=61643;PuncKey8=59836;MobQuiet"~
    "Hours=60486;Important=59593;HangUp=59256;Battery6=59478;Battery7=59479;Document=59557;StatusCircleSync=61763;SwipeRevealArt=6052"~
    "5;ConstructionSolid=60045;CalligraphyFill=61639;PauseBadge12=60852;VerticalBattery2=62964;PPSOnePortrait=62893;CharacterAppearan"~
    "ce=61823;SignalBars2=59501;PuncKey7=59835;StaplingPortraitTwoBottom=62879;ToolTip=59439;QWERTYOff=59779;DisconnectDrive=59597;Fl"~
    "ashlight=59220;Crop=59304;WifiAttentionOverlay=59800;MobAirplane=60480;StatusDualSIM2VPN=59523;DockRight=59661;ChromeMaximizeCon"~
    "trast=61230;Dial10=61775;EnglishPunctuation=61712;ActionCenterQuietNotification=61050;RadioBullet2=60620;JpnRomanjiShiftLock=595"~
    "19;MobWifiWarning2=62580;Fingerprint=59688;EmojiTabSmilesAnimals=60756;Up=59210;ScreenTime=61826;ShareBroadband=59450;BlockConta"~
    "ct=59640;CircleFillBadge12=60848;EmojiTabPeople=60755;ViewDashboard=62022;MultiSelectMirrored=60056;ChevronLeftMed=59763;StrokeE"~
    "rase=60768;MultimediaDMP=60743;KeyboardClassic=59237;EraseToolFill2=59436;ClosePaneMirrored=59977;VideoChat=59562;DockBottom=596"~
    "62;Unknown=59854;DuplexPortraitOneSidedMirrored=62853;AspectRatio=59289;CallForwardInternationalMirrored=59971;Shield=59928;MobC"~
    "allForwardingMirrored=60543;MobBluetooth=60481;EndPointSolid=60235;DeviceMonitorNoPic=59387;Dial1=61766;SignalError=60718;Forwar"~
    "dSm=59820;ContactPresence=59599;BackSpaceQWERTYLg=60310;FavoriteList=59176;Ringer=60047;VerticalBatteryCharging9=62982;RadioBtnO"~
    "n=60619;Pencil=60771;HWPSplit=62564;Contact2=59604;FullAlpha=59775;DialShape1=61782;InPrivate=59175;StartPoint=59417;Headphone1="~
    "60721;Phone=59159;WifiWarning1=60256";

  shared static dchar[string] table;
  if(table is null){
    foreach(s; tableData.split(';')){
      auto p = s.split('=');
      table[p[0]] = (p[1].to!int).to!dchar;
    }
    table.rehash;
  }

  //get by dec or hex code
  if(name.length && name[0].inRange('0', '9')) return name.toInt.to!dchar;

  auto a = name in table;
  return a ? *a : '\uFFFD';
}

/*void importSegoeSymbols(){
  wchar[string] segoeSymbols;

  foreach(s; File(`c:\dl\segoe_assets.txt`).readLines){
    auto p = s.split('\t');
    if(p.length>=2){
      segoeSymbols[p[0].strip] = p[1].to!int(16).to!wchar;
    }
  }

  segoeSymbols.rehash;

  segoeSymbols.byKeyValue.map!(kv => "%s=%s".format(kv.key, kv.value.to!int)).join(';').chunks(128).map!(s=>`"`~s.text~`"~`).join("\r\n").saveTo(File(`c:\dl\a.txt`));

  readln;
  application.exit;
}*/
