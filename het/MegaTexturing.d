module het.megatexturing;

import het.opengl, het.binpacker;

// Global access ///////////////////////////////

TextureManager textures(){
  __gshared static TextureManager t;
  if(!t) t = new TextureManager;
  return t;
}

// MegaTexturing constants ///////////////////////////////

enum
  //the alignment of a subTexture. Also the number of mipmaps.
  SubTexCellBits = 3,
  SubTexCellSize = 1<<SubTexCellBits,
  SubTexCellMask = SubTexCellSize-1,

  //Maximum size of textures. Hardware dependent. Max 16K
  SubTexSizeBits = 14,               //16K at max.
  SubTexMaxSize = 1<<SubTexSizeBits,
  SubTexSizeMask = SubTexMaxSize-1;


enum
  //starting size for textures
  MegaTexMinSizeBits = 10,
  MegaTexMinSize = 1<<MegaTexMinSizeBits,

  MegaTexMaxSizeBits = SubTexSizeBits, //it can be the same... why not
  MegaTexMaxSize = 1<<MegaTexMaxSizeBits,

  SubTexPosBits = MegaTexMaxSizeBits-SubTexCellBits,

  MegaTexIdxBits = 4,                 //samplerArray[8]
  MegaTexMaxCnt = 1<<MegaTexIdxBits,

  SubTexIdxBits = 16,
  SubTexIdxCnt = 1<<SubTexIdxBits;


// SubTexInfo struct ////////////////////////

enum SubTexChannelConfig{
  R   , G       , B       , A             ,
  RG  , GB      , BA      , unknown0      ,
  RGB , GBA     , unknown1, unknown2      ,
  RGBA, unknown3, unknown4, RGBA_ClearType,
}

private struct SubTexInfo{ align(1): import std.bitmanip;
  mixin(bitfields!(
    uint, "cellX",    14,      uint, "texIdx_lo", 2,
    uint, "cellY",    14,      uint, "texIdx_hi", 2, //texIdxHi = 3-x, to be likely visible
    uint, "width1",   14,      uint, "texChn_lo", 2,
    uint, "height1",  14,      uint, "texChn_hi", 2));

  this(in V2i pos, in V2i size, int texIdx, in SubTexChannelConfig texChn)   //pos and size is in pixels
  {
    enforce((pos.x & SubTexCellMask)==0
         && (pos.y & SubTexCellMask)==0, "unaligned pos");

    enforce(pos.x>=0 && size.x>0 && pos.x+size.x<=SubTexMaxSize
         && pos.y>=0 && size.y>0 && pos.y+size.y<=SubTexMaxSize, "pos, size: Out of range");
    enforce(texIdx.inRange(0, MegaTexMaxCnt-1), "texIdx: Out of range");

    cellX = pos.x>>SubTexCellBits;  texIdx_lo = texIdx.getBits(0, 2);
    cellY = pos.y>>SubTexCellBits;  texIdx_hi = texIdx.getBits(2, 2);
    auto tc = cast(int)texChn;
    width1  = size.x-1;             texChn_lo = tc.getBits(0, 2);
    height1 = size.y-1;             texChn_hi = tc.getBits(2, 2);
  }

  bool isNull() const{ return this==typeof(this).init; }
  V2i pos   () const{ return V2i(cellX, cellY)<<SubTexCellBits; }

  int width() const{ return width1+1; }
  int height() const{ return height1+1; }
  V2i size  () const{ return V2i(width, height); }

  int texIdx() const{ return texIdx_lo | texIdx_hi<<2; }

  auto channelConfig() const{ return cast(SubTexChannelConfig)(texChn_lo | texChn_hi<<2); }
  int  channelBase  () const{ return texChn_lo; }
  int  channelCnt   () const{ return texChn_hi+1; }

  auto toString() const{ return isNull ? "SubTexInfo(null)" : "SubTexInfo((%d, %d), (%d, %d), #%d, %s, %s)".format(pos.x, pos.y, size.x, size.y, texIdx, channelConfig, (cast(ubyte*)(&this))[0..8].to!string ); }
}

class MegaTexture{ // MegaTexture class /////////////////////////////
private:
  int texIdx, channels;
public  MaxRectsBin bin;
  GLTexture glTexture;

  int texWidth () const{ return bin.width <<SubTexCellBits; }
  int texHeight() const{ return bin.height<<SubTexCellBits; }

  void resizeGLTexture(){
    if(glTexture.width!=texWidth || glTexture.height!=texHeight){
      glTexture.fastBind;
      glTexture.resize(texWidth, texHeight);
    }
  }
public:
  this(int texIdx, int channels){
    enforce(texIdx.inRange(0, MegaTexMaxCnt-1), "texIdx out of range");
    enforce(channels==4, "Only 4chn Megatextures supported");

    this.texIdx = texIdx;
    this.channels = channels;

    const minSize = 64>>SubTexCellBits,
          maxSize = min(MegaTexMaxSize, gl.maxTextureSize)>>SubTexCellBits;
    bin = new MaxRectsBin(minSize, minSize, maxSize, maxSize);

    glTexture = new GLTexture("MegaTexture[%d]".format(texIdx), texWidth, texHeight, GLTextureType.RGBA8, false/*no mipmap*/); //todo: MegaTexture.mipmap
    glTexture.bind;
  }

  ~this(){
    glTexture.free;
    bin.free;
  }

  override string toString(){ return "MegaTexture(%s)".format(glTexture); }

  bool add(in V2i size, int channels, int data/*subTexIdx*/, out SubTexInfo info){
    auto cellSize = (size+SubTexCellMask)>>SubTexCellBits,
         rect = bin.add(cellSize.x, cellSize.y, data);

    if(rect is null){
      //todo: MegaTexture.repack()
      return false; //unable to allocate because out of space.
    }

    resizeGLTexture;//apply the possible binSize change

    auto pos = V2i(rect.x, rect.y)<<SubTexCellBits;
    info = SubTexInfo(pos, size, texIdx, cast(SubTexChannelConfig)((channels-1)*4)); //todo: MegaTexture.channels = 1, 2, 3, not just 4

    return true;
  }

  void remove(in int data){
    bin.remove(data).enforce("nothing to remove");
  }

  void dump() const{
    bin.dump;
  }

  void drawMaxRects(Drawing dr){
    dr.scale(SubTexCellSize); scope(exit) dr.pop;

    foreach(r; bin.freeRects){
      dr.color = clGray;
      dr.drawRect(r.bounds.toF.inflated(-0.125));
    }

    foreach(j, r; bin.rects){
      dr.color = clVga[(cast(int)j % ($-1))+1];
      dr.alpha = 0.5;
      dr.fillRect(r.bounds);
      dr.drawRect(r.bounds);
    }

    dr.color = clWhite;  dr.drawRect(0, 0, bin.width, bin.height);
  }

}


class InfoTexture{ // InfoTexture class ////////////////////////////////
private:
  enum TexelsPerInfo = 2; //for rgba & 8byte subTexInfo
  enum TexWidth = 512, InfoPerLine = TexWidth/TexelsPerInfo;

public  GLTexture glTexture;

public  SubTexInfo[] infoArray;
  int[] freeIndices;

  int capacity() const{ return InfoPerLine * glTexture.height; }
  int length() const{ return cast(int)infoArray.length; }

  void upload(int idx){ //opt: ezt megcsinalni kotegelt feldolgozasura
    glTexture.fastBind;
    glTexture.upload(infoArray[idx..idx+1], idx % InfoPerLine * TexelsPerInfo, idx / InfoPerLine, 2, 1);
  }

  void grow(){
    glTexture.fastBind;
    glTexture.resize(TexWidth, glTexture.height*2); //exponential grow
  }

  bool isValidIdx(int idx) const{ return idx.inRange(infoArray); }

  void checkValidIdx(int idx) const{ //todo: refactor to isValidIdx
    enforce(isValidIdx(idx), "subTexIdx out of range (%s)".format(idx));
    //ez nem kell, mert a delayed loader null-t allokal eloszor. enforce(!infoArray[idx].isNull, "invalid subTexIdx (%s)".format(idx));
  }

public:

  this(){
    enforce(SubTexInfo.sizeof==8, "Only implemented for 8 byte SubTextInfo");

    glTexture = new GLTexture("InfoTexture", TexWidth, 1/*height*/, GLTextureType.RGBA8, false/*no mipmap*/);
    glTexture.bind;
  }

  ~this(){
    glTexture.free;
  }

  //peeks the next subTex idx. Doesn't allocate it. Must be analogous with add()
  int peekNextIdx() const{
    if(!freeIndices.empty){//reuse a free slot
      return freeIndices[$-1];
    }else{ //add an extra slot
      return cast(int)infoArray.length;
    }
  }

  //allocates a new subTexture slot
  int add(in SubTexInfo info){
    //ez nem kell, mert a delayed loader pont null-t allokal eloszor: enforce(!info.isNull, "cannot allocate SubTexInfo.null");

    int actIdx;

    //this must be analogous with peekNextIdx
    if(!freeIndices.empty){//reuse a free slot
      actIdx = freeIndices.popLast;
      infoArray[actIdx] = info;
    }else{ //add an extra slot
      infoArray ~= info;
      actIdx = cast(int)infoArray.length-1;

      enforce(actIdx<SubTexIdxCnt, "FATAL: SubTexIdxCnt limit reached");

      if(capacity<infoArray.length) grow;
    }

    upload(actIdx);

    return actIdx;
  }

  //removes a subTex by idx
  void remove(int idx){
    checkValidIdx(idx);

    infoArray[idx] = SubTexInfo.init;
    freeIndices ~= idx;

    upload(idx); //upload the null for safety
    //todo: feltetelesen fordithatova tenni ezeket a felszabaditas utani zero filleket
  }

  //gets a subTexInfo by idx
  SubTexInfo access(int idx){
    checkValidIdx(idx);
    return infoArray[idx];
  }

  void modify(int idx, in SubTexInfo info){
    checkValidIdx(idx);
    infoArray[idx] = info;

    upload(idx);
  }


  void dump() const{
    //infoArray.enumerate.each!writeln;
    //!!! LDC 1.20.0 win64 linker bug when using enumerate here!!!!!

    //foreach(i, a; infoArray) writeln(tuple(i, a));
    //!!! linker error as well

    //foreach(i, a; infoArray) writeln(tuple(i, i+1));
    //!!! this is bad as well, the problem is not related to own structs, just to tuples

    foreach(i, a; infoArray) writefln("(%s, %s)", i, a);  //this works
  }
}

//todo: make the texture class
class Texture{ // Texture class /////////////////////////////////
//this holds all the info to access a subTexture
private:
  TextureManager owner;
  int idx;
  File file;

  private this(TextureManager owner, int idx){ //this is unnamed and empty
    this.owner = owner;
    this.idx = idx;
  }

public:
  this(TextureManager owner, int idx, File file, bool delayed = false){
    this(owner, idx);
    this.file = file;
  }

  override string toString() const{ return "Texture(#%d, %s)".format(idx, file); }
}


class TextureManager{ // TextureManager class /////////////////////////////////
private:
  InfoTexture infoTexture;
  MegaTexture[] megaTextures;

  int[File] byFileName;
  bool mustRehash;

  private bool[int] pendingIndices; //files being loaded by a worker thread
  private bool[int] invalidateAgain; //files that cannot be invalidated yet, because they are loading right now

  void enforceSize(const V2i size){
    enforce(size.x<=SubTexMaxSize     && size.y<=SubTexMaxSize    , "Texture too big (%s)"                                 .format(size));
    enforce(size.x<=gl.maxTextureSize && size.y<=gl.maxTextureSize, "Texture too big on current opengl implementation (%s)".format(size));
  }

  bool isCompatible(const Bitmap bmp, const MegaTexture mt){
    return true;
    //mt.channels==bmp.channels;
  }

  void addNewMegaTexture(int channels){
    if(megaTextures.length>=MegaTexMaxCnt){
      raise("Out of megatextures"); //todo: make a texture garbage collect cycle here
    }
    megaTextures ~= new MegaTexture(megaTextures.length.to!int, channels);
  }

  int allocSubTexInfo(in SubTexInfo info = SubTexInfo.init){ //info should point to a 'loading progress image'
    return infoTexture.add(info);
  }

  SubTexInfo allocSpace(int subTexIdx, in Bitmap bmp){
    enforceSize(bmp.size);

    SubTexInfo info;
    bool check(MegaTexture mt){
      return isCompatible(bmp, mt) && mt.add(bmp.size, bmp.channels, subTexIdx, info);
    }

    foreach(mt; megaTextures) if(check(mt)) return info;

    //add a new one
    addNewMegaTexture(4);
    enforce(check(megaTextures[$-1]));
    return info;
  }

  void uploadData(SubTexInfo info, Bitmap bmp, bool dontUploadData=false){
    auto mtIdx = info.texIdx;

    enforce(mtIdx>=0 && mtIdx<megaTextures.length, "mtIdx out of range (%s)".format(mtIdx));
    auto mt = megaTextures[mtIdx];

    if(!dontUploadData){
      mt.glTexture.fastBind;

      //todo: this is wasting ram and not work with custom non 4ch bitmaps
      //note: temporary solution: there is a nondestructive converter inside
      //bmp.channels = 4;

      mt.glTexture.upload(bmp, info.pos.x, info.pos.y, info.size.x, info.size.y);
    }
  }

  void uploadSubTex(int idx, Bitmap bmp, bool dontUploadData=false){ //it has an existing id
    auto info = allocSpace(idx, bmp);
    infoTexture.modify(idx, info);
    uploadData(info, bmp, dontUploadData);
  }

  int createSubTex(Bitmap bmp){ //creates a new one, returns the idx
    if(bmp.empty) return 0; //special null texture

    auto idx = infoTexture.peekNextIdx;
    auto info = allocSpace(idx, bmp);
    infoTexture.add(info);
    uploadData(info, bmp);
    return idx;
  }

  void removeSubTex(int idx){
    //get SubTexInfo
    auto info = infoTexture.access(idx);

    //get megaTex idx
    auto mtIdx = info.texIdx;

    enforce(mtIdx>=0 && mtIdx<megaTextures.length, "mtIdx out of range (%s)".format(mtIdx));

    //clear the area
    if(1) with(megaTextures[mtIdx].glTexture){
      fastBind;
      fill(0xFFFF00FF, info.pos.x, info.pos.y, info.size.x, info.size.y);
    }

    megaTextures[mtIdx].remove(idx);
    infoTexture.remove(idx);
  }

  Bitmap[] bmpQueue;

public:
  this(){
    infoTexture = new InfoTexture;
  }

  bool update(){
    bool inv;

    if(mustRehash) byFileName.rehash;

    auto t0 = QPS;

    enum UploadTextureMaxTime = 0.1; //10 fps
    do{

      Bitmap bmp;
      synchronized(textures) bmp = bmpQueue.popFirst(null);

      if(!bmp) break;

      auto idx = bmp.tag;

      pendingIndices.remove(idx); //not pending anymore so it can be reinvalidated

      if(idx in invalidateAgain){
        //WARN("Delayed loaded bmp is in invalidateAgain.", idx);

        uploadSubTex(idx, bmp, true); //this is here to finalize the allocation of the texture before the invalidation
        //opt: disable the upload of this texture data

        invalidateAgain.remove(idx);
        foreach(f, i; byFileName) if(i == idx){ //opt: slow linear search
          //WARN("Reinvalidating", f, idx);
          invalidate(f);
          break;
        }
      }else{
        uploadSubTex(idx, bmp);
      }

      inv = true;

    }while(QPS-t0<UploadTextureMaxTime/*sec*/);

    return inv;
  }

  void invalidate(in File fileName){
    if(auto idx = (fileName in byFileName)){
      if(*idx in pendingIndices){
        //WARN("Texture loader is pending", fileName, *idx);
        invalidateAgain[*idx] = true;
        return;
      }
      byFileName.remove(fileName);
      removeSubTex(*idx);
    }
  }

  int access(in File fileName, bool delayed = true){ //todo: bugos a delayed leader

    //delayed = false;

    if(!(fileName in byFileName)){

      if(fileName.fullName.startsWith(`font:\`) || fileName.fullName.startsWith(`custom:\`)) delayed = false; //todo: delayed restriction. should refactor this nicely

      if(delayed){
        auto idx = allocSubTexInfo;

        pendingIndices[idx] = true;
        byFileName[fileName] = idx;
        mustRehash = true;

        static void loader(int idx, File fileName){
//          enforce(SetProcessAffinityMask(GetCurrentProcess, 0xFE), getLastErrorStr);
//          sleep(random(1000));
          //SetPriorityClass(GetCurrentProcess, BELOW_NORMAL_PRIORITY_CLASS);

//"fuck".writeln;

//          "Loader.start %.2d %s".writefln(idx, GetCurrentProcessorNumber);
//          "B%s ".writef(idx);

          /*if(GetCurrentProcessorNumber==mainThreadProcessorNumber) */

//          sleep(100);
          Bitmap bmp;
          try{
            bmp = newBitmap(fileName); // <- this takes time. This should be delayed
          }catch(Throwable){
            //bmp = new Bitmap(new Image!RGBA([RGBA(0xFFFF00FF)], 1, 1));
            //bmp = newBitmap(`font:\Segoe MDL2 Assets\16?`~"\uE783");
            WARN("Bitmap decode error. Using errorBitmap", fileName); //todo: ezt megoldani a placeholder bitmappal rendesen
            bmp = errorBitmap;
          }

          //bmp.channels = 4; //todo: not just 4 chn bitmap support
          bmp.tag = idx; //tag = SubTexIdx

//          "E%s ".writef(idx);

          synchronized(textures){
            textures.bmpQueue ~= bmp;
            mainWindow.invalidate;  //todo: issue a redraw. it only works for one window apps.
          }

        }

        if(0){
          import std.concurrency;
          spawn(&loader, idx, fileName);
        }else{
          import std.parallelism;
          auto t = task!loader(idx, fileName);
          taskPool.put(t);
//          t.yieldForce;
//          loader(idx, fileName);

/*          Bitmap[int] queue;
          synchronized(textures){
            queue = bmpQueue.dup;
            bmpQueue.clear;
          }

          foreach(kv; queue.byKeyValue)
            uploadSubTex(kv.key, kv.value);*/

        }

      }else{ //immediate loader
        Bitmap bmp;
        try{
          bmp = newBitmap(fileName); // <- this takes time. This should be delayed
        }catch(Throwable){
          WARN("Bitmap decode error. Using errorBitmap", fileName); //todo: ezt megoldani a placeholder bitmappal rendesen
          bmp = errorBitmap;
        }

        //auto bmp = newBitmap(fileName); // <- this takes time. This should be delayed
        //bmp.channels = 4; //todo: not just 4 chn bitmap support

        auto idx = createSubTex(bmp); //it uploads immediatelly

        byFileName[fileName] = idx;
        mustRehash = true;
      }
    }

    return byFileName[fileName];
  }

  int custom(string name, Bitmap bmp=null){ //if bitmap != null then refresh
enum log = false;
if(log) "testures.custom(%s, %s)".writefln(name, bmp);

    auto fileName = File("custom://"~name);

    if(auto a = (fileName in byFileName)){
      if(bmp){ //update existing
        removeSubTex(*a);
        auto idx = createSubTex(bmp);
        byFileName[fileName] = idx;
        mustRehash = true;
if(log) "Updated subtex %s:".writefln(fileName);
        return idx;
      }else{
if(log) "Found subtex %s:".writefln(fileName);
        return *a;
      }
    }else{
      if(bmp is null){
        bmp = new Bitmap(8, 8, 4);  //just create a purple placeholder
        bmp.rgba.clear(clFuchsia);
      }
      auto idx = createSubTex(bmp);
      byFileName[fileName] = idx;
      mustRehash = true;
if(log) "Created subtex %s:".writefln(fileName);
      return idx;
    }
  }

  int custom(string name, ubyte[] data){
    return custom(name, new Bitmap(data));
  }


  int opIndex(File fileName){
    return access(fileName);
  }

  SubTexInfo accessInfo(int idx){ //todo ez egy texture class-ba kell, hogy benne legyen
    return infoTexture.access(idx);
  }

  SubTexInfo opIndex(int idx){
    return infoTexture.access(idx);
  }

  void dump() const{
    infoTexture.dump;
  }

  GLTexture[] getGLTextures(){ return infoTexture.glTexture ~ megaTextures.map!(a => a.glTexture).array; }

  V2i textureSize(int idx){
    return infoTexture.isValidIdx(idx) ? accessInfo(idx).size
                                       : V2i.Null;
  }

  V2i textureSize(File file){
    return textureSize(access(file));
  }
}

