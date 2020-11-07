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

auto convertColorComponentType(CT, A)(auto ref A a){
  alias ST = ScalarType!A;

       static if(is(ST == ubyte) && is(CT == float)) return a.generateVector!(CT, a => a * (1.0f/255));
  else static if(is(ST == float) && is(CT == ubyte)) return a.generateVector!(CT, a => a * 255       );
  else                                               return a.generateVector!(CT, a => a             );
}

auto convertColorChannels(int DstLen, A)(auto ref A a){
  alias SrcLen = VectorLength!A,
        T      = ScalarType  !A,
        VT     = Vector!(T, DstLen);
  //              Src: L              LA        RGB       RGBA         Dst:
  immutable table = [["a          ", "a.r   ", "a.l   ", "a.l  "],  // L
                     ["VT(a,1)    ", "a     ", "a.l1  ", "a.la "],  // LA
                     ["VT(a,a,a)  ", "a.rrr ", "a     ", "a.rgb"],  // RGB
                     ["VT(a,a,a,1)", "a.rrrg", "a.rgb1", "a    "]]; // RGBA

  static foreach(i; 1..5) static if(DstLen == i)
    static foreach(j; 1..5) static if(SrcLen == j)
      return mixin(table[i-1][j-1]);

  static assert(VectorLength!(typeof(return)) == DstLen, "DstLen mismatch");
}

auto convertColor(B, A)(auto ref A a){
  alias DstType = ScalarType  !B,
        DstLen  = VectorLength!B;

  return a.convertColorComponentType!DstType     // 2 step conversion: type and channels
          .convertColorChannels!DstLen;
}

class Bitmap{ // Bitmap class /////////////////////////////////////////////
private:
  void[] data_;
  int width_, height_, channels_=4;
  string type_ = "ubyte";
public:
  int tag;     // can be an external id
  int counter; // can notify of cnahges

  @property width   () const{ return width_   ; }
  @property height  () const{ return height_  ; }
  @property channels() const{ return channels_; }
  @property type    () const{ return type_    ; }

  void set(E)(Image!(E, 2) im){
    counter++;
    width_      = im.width ;
    height_     = im.height;
    channels_   = VectorLength!E;
    type_       = (ScalarType!E).stringof;
    data_       = im.asArray;
  }

  auto castedImage(E)(){
    return image2D(width_, height_, cast(Unqual!E[]) data_);
  }

  auto access(E)(){
    enforce(VectorLength!E == channels, "channel mismatch");
    enforce((ScalarType!E).stringof == type, "type mismatch");
    return castedImage!E;
  }

  auto get(E)(){ //it converts
    static foreach(T; AliasSeq!(ubyte, RG, RGB, RGBA, float, vec2, vec3, vec4)){{
      alias CT = ScalarType   !T,
            len = VectorLength!T;
      if(CT.stringof == type && len==channels)
        return mixin("access!(", T.stringof, ").image2D!(a => a.convertColor!(", E.stringof, "))");
    }}

    raise("invalid bitmap format"); assert(0);
  }


  override string toString() const { return format("Bitmap(%d, %d, %d, \"%s\")", width, height, channels, type); }
}

// Bitmap/Image serializer //////////////////////////////////////////

__gshared serializeImage_defaultFormat = "png"; // png is the best because it knows 1..4 components and it's moderately compressed.

auto convertImage(Dst, T)(Image!(T, 2) src){ //compile time image convert
  scope auto bmp = new Bitmap;
  bmp.set(src);
  return bmp.get!(Dst);
}

/// converts it to ubyte and remaps chn using a chn expression string
private auto convertImage_ubyte_chnRemap(int[4] chnRemap, T)(Image!(T, 2) a){
  enum chn = VectorLength!T,
       newChn = chnRemap[chn-1];
  static assert(newChn.inRange(1,4));

  static if(is(ScalarType!T == ubyte) && chn == newChn) return a;
  else return a.convertImage!(Vector!(ubyte, newChn));
}

private static ubyte[] write_webp_to_mem(int width, int height, ubyte[] data, int quality){  //Reasonable quality = 95,  lossless = 100
  //note: the header is in the same syntax like in the imageformats module.
  import webp.encode, core.stdc.stdlib : free;

  ubyte* output;
  size_t size;
  const lossy = quality<100; //100 means lossless
  const channels = data.length.to!int/(width*height);
  enforce(data.length = width*height*channels, "invalid image data");
  switch(channels){
    case 4: size = lossy ? WebPEncodeRGBA        (data.ptr, width, height, width*channels, quality, &output)
                         : WebPEncodeLosslessRGBA(data.ptr, width, height, width*channels,          &output);  break;
    case 3: size = lossy ? WebPEncodeRGB         (data.ptr, width, height, width*channels, quality, &output)
                         : WebPEncodeLosslessRGB (data.ptr, width, height, width*channels,          &output);  break;
    default: enforce(0, "8/16bit webp not supported"); //todo: Y, YA plane-kkal megoldani ezeket is
  }

  //todo: tovabbi info a webp-rol: az alpha az csak lossless modon van tomoritve. Lehet, hogy azt is egy Y-al kene megoldani...

  enforce(size, "WebPEncode failed.");

  ubyte[] res = output[0..size].dup; //unoptimal copy
  free(output);
  return res;
}

private void[] serializeImage(T)(Image!(T, 2) img, string format=""){ // compile time version
  import imageformats;

  enum chn = VectorLength!T,
       type = (ScalarType!T).stringof;
  if(format=="") format = serializeImage_defaultFormat;
  auto fmt = format.commandLineToMap;

  auto getQuality(){
    return ("quality" in fmt) ? fmt["quality"].to!int.clamp(0, 100)
                              : 95; //Default quality for jpeg and webp
  }

  switch(fmt["0"]){
    case "bmp":  return write_bmp_to_mem (img.width, img.height, cast(ubyte[]) img.convertImage_ubyte_chnRemap!([3,4,3,4]).asArray); //only 3 and 4 chn supported
    case "png":  return write_png_to_mem (img.width, img.height, cast(ubyte[]) img.convertImage_ubyte_chnRemap!([1,2,3,4]).asArray); //all chn supported
    case "tga":  return write_tga_to_mem (img.width, img.height, cast(ubyte[]) img.convertImage_ubyte_chnRemap!([1,4,3,4]).asArray); //all except 2 chn supported
    case "webp": return write_webp_to_mem(img.width, img.height, cast(ubyte[]) img.convertImage_ubyte_chnRemap!([3,4,3,4]).asArray, getQuality); //only 3 and 4 chn
    case "jpg": raise("encoding to jpg not supported"); return [];
    default: raise("invalid image compression format: "~format); return [];
  }
}

immutable serializeImage_supportedFormats   = ["webp", "png", "bmp", "tga"];

private void[] serializeImage(Bitmap bmp, string format=""){ // runtime version

  // todo: this runtime code generator should be centralized in Bitmap
  static foreach(T; AliasSeq!(ubyte, RG, RGB, RGBA, float, vec2, vec3, vec4)){{
    alias CT = ScalarType   !T,
          len = VectorLength!T;
    if(CT.stringof == bmp.type && len==bmp.channels)
      return mixin("serializeImage(bmp.access!(", T.stringof, "), format)");
  }}

  raise("invalid bitmap format"); assert(0);
}


//combined compress function
void[] serialize(A)(A a, string format=""){
       static if(is(A==Bitmap)  ) return a.serializeImage(format);        // Bitmap
  else static if(isImage2D!A    ) return a.serializeImage(format);        // 2D Image
  else static assert(0, "invalid arg");
}


void maintest(){ //import het.utils; het.utils.application.runConsole({ //! Main ////////////////////////////////////////////
  het.math.unittest_main;

  import het.geometry;
  import het.win;


//  writeln("4.5".to!float);

  auto bmp = new Bitmap;
  bmp.writeln;
  bmp.set(image2D(32, 32, (ivec2 p)=> mix( mix(RGBA(clRed, 255), RGBA(clGreen, 255), p.x/32.0f),
                                           mix(RGBA(clBlue,255), RGBA(clWhite,   0), p.x/32.0f), p.y/32.0f) ));

  serializeImage_supportedFormats.writeln;
  foreach(ext; serializeImage_supportedFormats)
    static foreach(Type; AliasSeq!(ubyte, RG, RGB, RGBA))
      bmp.get!Type.serialize(ext).saveTo(File(`c:\dl\a`~(Type.sizeof*8).text~`.`~ext));

  //bmp.toPng.saveTo(File(`c:\test\a.png`));

/*  bmp.get!RGB.toBmp.saveTo(File(`c:\test\rgb.bmp`));
  bmp.get!RGBA.toBmp.saveTo(File(`c:\test\rgba.bmp`));
  bmp.get!ubyte.toTga.saveTo(File(`c:\test\gray.bmp`));

  bmp.writeln;
  bmp.set(bmp.access!RGB.image2D!(a => a.convertColor!vec4)); //access as RGB and convert to vec4  (RGBA32F, set alpha to 1)
  bmp.set(bmp.get!vec2); //get as whatever and convert to vec2  (RG32F, RGB->grayscale, Alpha remains unchanged)
  bmp.writeln;
  bmp.access!vec2.rows.writeln;*/


  writeln("done");
  readln;

}//); }

import het.win;

class MyWin: Window{
  mixin autoCreate;  //automatically creates an instance of this form ath startup

  override void onCreate(){
    maintest;
  }

  override void onPaint(){
    import core.sys.windows.windows;

    auto rect = clientRect;
    FillRect(hdc, &rect, cast(HBRUSH) (COLOR_WINDOW+2));

    iResolution = vec2(320, 240);
    foreach(p; iResolution.itrunc.iota2){
      vec2 fragCoord = p;
      vec4 fragColor;
      mainImage(fragColor, fragCoord);
      SetPixel(hdc, p.x, p.y, fragColor.floatToRgb.lll.raw);
    }
  }

}
