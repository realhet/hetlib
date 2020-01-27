module libvlc;

import het.utils, het.image, het.geometry, core.sync.rwmutex;

private:

void log(string s){
//  writeln("VLC: "~s);
}

alias libvlc_video_format_cb  = extern(C) uint function(ref void* opaque, char* chroma, ref uint width, ref uint height, uint *pitches, uint *lines);
alias libvlc_video_cleanup_cb = extern(C) void function(void* opaque);

alias libvlc_video_lock_cb    = extern(C) void function(void* opaque, void** planes);
alias libvlc_video_unlock_cb  = extern(C) void function(void* opaque, void* picture, void** planes);
alias libvlc_video_display_cb = extern(C) void function(void* opaque, void* picture);

// structs /////////////////////////////////////////////////////

struct libvlc_instance_t{}
struct libvlc_media_player_t{}
struct libvlc_media_t{}

// DLL imports /////////////////////////////////////////////////

struct libvlc{
  static extern(C){
    libvlc_instance_t* function(int argc, const char** argv) new_;
    libvlc_media_t* function(libvlc_instance_t* p_instance, const char* psz_mrl) media_new_location;
    void function(libvlc_media_t* p_md, const char * psz_options) media_add_option;
    libvlc_media_player_t* function(libvlc_media_t* p_media) media_player_new_from_media;

    void function(libvlc_media_player_t* mp, libvlc_video_lock_cb lock, libvlc_video_unlock_cb unlock, libvlc_video_display_cb display, void *opaque) video_set_callbacks;
    void function(libvlc_media_player_t* mp, libvlc_video_format_cb setup, libvlc_video_cleanup_cb cleanup) video_set_format_callbacks;
    void function(libvlc_media_player_t* mp, const char* chroma, uint width, uint height, uint pitch) video_set_format;

    int  function(libvlc_media_player_t* mp) media_player_play;
    int  function(libvlc_media_player_t* mp) media_player_stop;
    void function(libvlc_media_player_t* mp) media_player_release;
    bool function(libvlc_media_player_t* mp) media_player_is_playing;

    void function(libvlc_media_t* p_media) media_release;
    void function(libvlc_instance_t* p_instance) release;
  }

  static void loadFuncts() //must be called right after it got an active opengl contect
  {
    if(new_ !is null) return; //Don't load twice!

    auto vlcPath = programFilesPath ~ `VideoLAN\VLC`;

    auto fnCore = File(vlcPath, `libvlccore.dll`);
    auto fnLib  = File(vlcPath, `libvlc.dll`);

    auto hModule = loadLibrary(fnCore); //just need to load this first

    hModule = loadLibrary(fnLib); //this is the actual lib
    mixin(genLoadLibraryFuncts!(typeof(this), "hModule"));
  }
}

// wrapper classes ////////////////////////////////////////////////

public:

VlcInstance vlc(){ //global entry point for the lib
  __gshared static VlcInstance ins;
  if(!ins){
    ins = new VlcInstance;
  }
  return ins;
}


class VlcInstance{
private:
  libvlc_instance_t* instance;
public:
  this(string[] args = []){
    libvlc.loadFuncts;

    args = ["--ignore-config", "--verbose=1"]; //todo: no-audio ezt playerenkent kulon valaszthatova tenni. A PEM-nel meg mindig kuss legyen! -> libvlc_media_add_option

    const(char*)[] array;
    foreach(const s; args) array ~= toPChar(s);

    instance = libvlc.new_(cast(int)args.length, array.ptr);
  }

  ~this(){
    if(instance) release;
  }

  void onDestroy(VlcPlayer p){
    players = players.remove!(a => a==p);
  }

  void release(){
    enforce(instance, "VLCInstance.release unable to release null");

    //free players
    foreach(ref p; players) destroy(p);
    players.clear;

    libvlc.release(instance);
    instance = null;
  }

  VlcPlayer[] players;

  VlcPlayer newPlayer(const string uri, const V2i size=V2i.Null){
    auto p = new VlcPlayer(this, uri, size);
    players ~= p;
    return p;
  }
}

class VlcPlayer{
private:
  VlcInstance owner;
  libvlc_media_player_t* mp;
  string uri, error_open;

  //max I420 dimensions
  enum maxWidth = 4096, //todo: memory footprint: pool is allovating 4K for all the time. pool must be locked properly with the dimensons.
       maxHeight = maxWidth*2/3;

  V2i size;

private: //resource
  ReadWriteMutex mutex;
  uint width, height;
  ubyte[] pool;
public:
  //getters
  int changedCnt;

  bool canGet(ref Image!ubyte dst) const {
    if(uri=="" || width==0 || height==0) return false; //nothing to get

    //only get if dst is not in synch
    return dst is null || dst.changedCnt!=changedCnt;
  }

  bool get(ref Image!ubyte dst, string components){
    if(!canGet(dst)) return false;

    int w = width, h = height, p = width, o = 0;

    switch(components){
      case "Y": break;
      case "YUV": h = h*3/2; break;
      case "UV": h /= 2; break;
      case "U": h /= 2; w /= 2; o = width*height    ; break;
      case "V": h /= 2; w /= 2; o = width*height + w; break;
      default: enforce(0, "VlcPlayer.get: invalid components: \"%s\"".format(components));
    }

    synchronized(mutex.reader){
      dst = new Image!ubyte(null, 0, 0);
      dst.acquire(pool[o..$], w, h, p, true);
      dst.setChangedCnt(changedCnt);
    }

    return true;
  }

  bool getY  (ref Image!ubyte dst){ return get(dst, "Y"  ); }
  bool getYUV(ref Image!ubyte dst){ return get(dst, "YUV"); }

private:
  @safe @nogc void*[3] planes () { return [&pool[0], &pool[width*height], &pool[width*height+width/2]]; }
  @safe @nogc videoCleanup() { width = height = 0; }

  static extern(C) /*@nogc*/ {
    uint my_video_format_cb(ref void* opaque, char* chroma, ref uint width, ref uint height, uint *pitches, uint *lines){
      auto pl = cast(VlcPlayer)opaque;

//      writefln("pre my_video_format_cb(%s, %d, %d, %s, %s)", chroma.to!string, width, height, pitches[0..3].text, lines[0..3].text);

      width = pl.size.x; height = pl.size.y;

      chroma[0..4] = "I420";
      lines[0] = height;  lines[1] = lines[2] = height/2;
      pitches[0..3] = width;

//      writefln("my_video_format_cb(%s, %d, %d, %s, %s)", chroma.to!string, width, height, pitches[0..3].text, lines[0..3].text);

      pl.width = width;   //redundant
      pl.height = height;

      return 3;
    }

    void my_video_cleanup_cb(void* opaque){
    //  writeln("my_video_cleanup_cb()");
      auto pl = cast(VlcPlayer)opaque;
      pl.videoCleanup;
    }

    void my_video_lock_cb(void* opaque, void** planes){
      auto pl = cast(VlcPlayer)opaque;
      //write(".");
      planes[0..3] = pl.planes;
//      writeln("my_video_lock_cb ", pl.uri, " ", pl.width, " ", pl.height, " ", planes[0..3], " ", planes[1]-planes[0], " ", planes[2]-planes[1]);
      pl.mutex.writer.lock;
    }

    void my_video_unlock_cb(void* opaque, void* picture, void** planes){
      auto pl = cast(VlcPlayer)opaque;
      //writeln("my_video_unlock_cb ", pl.uri);
      pl.mutex.writer.unlock;
    }

    void my_video_display_cb(void* opaque, void* picture){
      auto pl = cast(VlcPlayer)opaque;
      //writeln("my_video_display_cb ", pl.uri);
      pl.changedCnt ++;
    }
  }

public:
  this(VlcInstance owner, string uri, V2i size){
    this.owner = owner;
    this.size = size;

    //todo: ez lehet kisebb helyu is, a size meg lehet rugalmasabb is
    pool.length = maxWidth*maxWidth; //maxWidth is texture width and height. Maxheight is the maximum video height that can be stored using I420 format on a maxHeight^^2 texture surface.
    mutex = new ReadWriteMutex(ReadWriteMutex.Policy.PREFER_WRITERS);

    if(!uri.empty) open(uri);
  }

  override string toString(){
    return "VlcPlayer(%s, %sx%s, %s)".format(uri, width, height, opened ? (playing ? "playing":"stopped") : "closed");
  }

  bool open(string uri){
    this.uri = uri;
    error_open = "";

    release;
    if(uri.strip=="") return true; //closed all

    string[] options = splitCommandLine(uri);
    string fn = options[0];
    options = options[1..$];

    //writeln("opening: ", fn);

    if(File(fn).exists){
      error_open = "Media files not supported yet"; return false;
    }else{
      auto m = libvlc.media_new_location(owner.instance, toPChar(fn));
      scope(exit) libvlc.media_release(m);
      if(m is null){ error_open = "libvlc.media_new_location() fail"; return false; }

      //options
      //string s = "dshow-vdev=Microsoft\u00AE LifeCam Cinema(TM)".toUTF8;
      foreach(opt; options){
        libvlc.media_add_option(m, toPChar(opt));
        writeln("  opt: ", opt);
        writefln("  opth: %(%.2X %)", cast(ubyte[])opt);
      }

      mp = libvlc.media_player_new_from_media(m);
      if(mp is null){ error_open = "libvlc.media_player_new_from_media() fail"; return false; }

      //setup video callbacks
      libvlc.video_set_callbacks(mp, &my_video_lock_cb, &my_video_unlock_cb, &my_video_display_cb, cast(void*)this);
      libvlc.video_set_format_callbacks(mp, &my_video_format_cb, &my_video_cleanup_cb);
    }
    return true;
  }

  void close(){ open(""); }

  bool opened() { return mp !is null; }
  bool playing() { return (mp !is null) && libvlc.media_player_is_playing(mp); }

  ~this(){
    release;
    owner.onDestroy(this);
  }

  private void release(){
    if(mp){
      libvlc.media_player_release(mp);
      mp = null;
    }
  }


  @property bool isPlaying(){ return mp && libvlc.media_player_is_playing(mp); }
  @property void isPlaying(bool b){ if(b) play; else stop; }
  bool toggle(){ isPlaying = !isPlaying; return isPlaying;}
  void play(){ if(mp) libvlc.media_player_play(mp); }
  void stop(){ if(mp) libvlc.media_player_stop(mp); }
}

