//@exe
///@release

import het, het.ui;

// Id system ////////////////////////////////////////////////////////////

version = stringId;
//version = longId;


struct SrcId{
       version(stringId) alias T = string;
  else version(longId  ) alias T = ulong ;
  else                   alias T = uint  ;

  T value;


}

string processGenericArgs(string code){
  return "static foreach(a; args){{ static if(isGenericArg!(typeof(a))){ enum N = a.name; alias T = a.type; }else{ enum N = ``; alias T = typeof(a); } "~code~" }}";
}

static if(is(SrcId.T==uint) || is(SrcId.T==ulong)){

  auto srcId(in SrcId i1, in SrcId i2){ return SrcId(cast(SrcId.T)hashOf(i2.value, i1.value));      }

  //note: string hash is 32 bit only, so the proper way to combine line and module is hash(line, hash(module))
  auto srcId(string srcModule=__MODULE__, size_t srcLine=__LINE__, Args...)(in Args args){
    auto id = SrcId(cast(SrcId.T)hashOf(srcLine, hashOf(srcModule)));
    mixin(processGenericArgs(q{
      static if(N=="id") id = SrcId(cast(SrcId.T)hashOf(a, id.value));
    }));
    return id;
  }

}else static if(is(SrcId.T==string)){

  auto srcId(in SrcId i1, in SrcId i2) { return SrcId(i1.value ~ '.' ~ i2.value); }

  auto srcId(string srcModule=__MODULE__, size_t srcLine=__LINE__, Args...)(in Args args){
    auto id = SrcId(srcModule ~ `.d(` ~ srcLine.text ~ ')'); // .d is included to make sourceModule detection easier
    mixin(processGenericArgs(q{
      static if(N=="id") id = SrcId(id.value ~ '[' ~ a.text ~ ']');
    }));
    return id;
  }

}else static assert(0, "Invalid SrcId.T");




void test_SrcId(){

  string[] strings = File(`c:\d\libs\het\utils.d`).readLines;

  immutable str = "Hello";
  import core.internal.hash;
  enum test = bytesHash(str.ptr, str.length, 0);
  print(test);

  foreach(batch; 0..5){
    auto t0 = QPS;
    foreach(const s; strings) s.xxh(0);
    auto t1 = QPS;
    foreach(const s; strings) hashOf(s);
    auto t2 = QPS;

    print("xxh: ", t1-t0, "hashOf: ", t2-t1);
  }

  print("IdType =", SrcId.T.stringof);

  { //simple id test: id's on same lines are equal, except with extra params

    auto f1(string srcModule = __MODULE__, size_t srcLine = __LINE__, Args...)(in Args args){
      auto id = srcId!(srcModule, srcLine)(args);
      return id.value;
    }

    enum i1 = srcId; enum i2 = srcId;
    enum i3 = srcId; auto i4 = srcId(genericArg!"id"("Hello"), genericArg!"id"(123));
    enforce(i1==i2 && i2!=i3 && i3!=i4);
  }
}


//  void combine(uint nextId){ return value = value*22695477+1; }
//  void combine(in ImId nextId){ combine(nextId.value); }

// ImStorage ///////////////////////////////////////////////

interface ImStorageInfo{
  void purge(uint maxAge);

  string name();
  string infoSummary();
  string[] infoDetails();
}

struct ImStorageManager{ static:
  ImStorageInfo[string] storages;

  void registerStorage(ImStorageInfo info){
    storages[info.name] = info;
  }

  void purge(uint maxAge){
    storages.values.each!(s => s.purge(maxAge));
  }

  string stats(string details=""){
    string res;
    foreach(name; storages.keys.sort){
      const maskOk = name.isWild(details);
      if(maskOk || details=="") res ~= storages[name].infoSummary ~ '\n';
      if(maskOk               ) res ~= storages[name].infoDetails.join('\n') ~ '\n';
    }
    return res;
  }

  string detailedStats(){ return stats("*"); }
}

struct ImStorage(T){ static:
  alias ID = uint;

  struct Item{
    T data;
    ID id;
    uint tick;
  }

  Item[uint] items; //by Id

  void purge(uint maxAge){ //age = 0 purge all
    uint limit = global_tick-maxAge;
    auto toRemove = items.byKeyValue.filter!((a) => a.value.tick<=limit).map!"a.key".array;
    toRemove.each!(k => items.remove(k));
  }

  class InfoClass : ImStorageInfo {
    string name(){ return ImStorage!T.stringof; }
    string infoSummary(){
      return format!("%s(count: %s, minAge = %s, maxAge = %s")(name, items.length,
          global_tick - items.values.map!(a => a.tick).minElement(uint.max),
          global_tick - items.values.map!(a => a.tick).maxElement(uint.min)
      );
    }
    string[] infoDetails(){
      return items.byKeyValue.map!((in a) => format!"  age=%-4d | id=%-9d | %s"(global_tick-a.value.tick, a.key, a.value.data)).array.sort.array;
    }
    void purge(uint maxAge){
      ImStorage!T.purge(maxAge);
    }
  }

  auto ref access(in ID id){
    auto p = id in items;
    if(!p){
      items[id] = Item.init;
      p = id in items;
      p.id = id;
    }
    p.tick = global_tick;
    return p.data;
  }

  void set(in ID id, in T data){ access(id) = data; }

  bool exists(in ID id){ return (id in items) !is null; }

  uint age(in ID id){
    if(auto p = id in items){
      return global_tick-p.tick;
    }else return typeof(return).max;
  }

  static this(){
    ImStorageManager.registerStorage(new InfoClass);
  }
}

class CustomTexture{ // CustomTexture ///////////////////////////////
  string name(){ return this.identityStr; }
  protected{
    Bitmap bmp;
    bool mustUpload;
  }

  void update(){ mustUpload = true; }
  void update(Bitmap bmp){ this.bmp = bmp; mustUpload = true; }

  int texIdx(){
    if(bmp is null) return -1; //nothing to draw
    if(!textures.isCustomExists(name)) mustUpload = true; //prepare for megaTexture GC
    Bitmap b = chkClear(mustUpload) ? bmp : null;
    return textures.custom(name, b);
  }
}

class PathEditor{ // PathEditor ////////////////////////////////
  Path editedPath;

/*  @property Path path() const{ return actPath; }
  @property void path(in Path p) { actPath = editedPath = p; }

  this(){ path = currentPath.normalized; }
  this(in Path p){ path = p.normalized; }*/

  bool UI(Args...)(ref Path actPath, in Args args){ with(im){
    bool mustRefresh;
    Edit(editedPath.fullPath, args, {
      if(flags.focused){
        auto normalizedPath = editedPath.normalized;
        const isPathOk = normalizedPath.exists;

        void colorize(RGB cl){
          style.bkColor = bkColor = mix(bkColor, cl, 0.25f);
          border.color = cl;
        }

        if(!isPathOk) colorize(clRed);
        else if(!samePath(normalizedPath, actPath)) colorize(clGreen);

        if(inputs.Esc.pressed){ editedPath = actPath; }
        if(inputs.Enter.pressed && isPathOk){
          actPath = normalizedPath;
          focusedState.reset;
          mustRefresh = true;
        }
      }else{
        editedPath = actPath;
        if(!actPath.exists) style.fontColor = clRed;
      }
    });
    return mustRefresh;
  }}
}


class FrmTestInputs: GLWindow { mixin autoCreate;  // Frm ///////////////////////////////////

  CustomTexture customTexture;
  int threshold = 2;

  PathEditor pathEditor;
  Path actPath;

  override void onCreate(){
    auto id = srcId;
    print(id);

    test_SrcId;

    readln;

    customTexture = new CustomTexture;

    pathEditor = new PathEditor;
    actPath = Path(`c:\d\projects\karc\samples`);

    refresh;
  }

  void refresh(){
    static Bitmap bOrig;
    if(!bOrig) bOrig = newBitmap(`\dl\ebaytest2.png`);
    //`c:\D\projects\Karc\Samples\old\200221-213031-481.jpg`);

    //`c:\dl\s-l1600 (54).jpg`;
    //`c:\dl\books-notebook-notepad-pencil.jpg`);//c:\dl\s-l1600 (19).jpg`);

    auto iSrc = bOrig.get!ubyte;
    auto iDst = image2D(bOrig.size, bOrig.get!RGB.asArray);

    auto img = image2D(bOrig.size*ivec2(1, 2), ubyte(0));
    img[0, 0] = iSrc;

    foreach(y; 0..iSrc.height-2) foreach(x; 0..iSrc.width-2){
      auto subImg = iSrc[x..x+2, y..y+2],
           hDiff = min(absDiff(subImg[0,0],subImg[1,0]), absDiff(subImg[0,1],subImg[1,1])),
           vDiff = min(absDiff(subImg[0,0],subImg[0,1]), absDiff(subImg[1,0],subImg[1,1])),
           xDiff = min(absDiff(subImg[0,0],subImg[1,0]), absDiff(subImg[0,0],subImg[0,1]), absDiff(subImg[0,0],subImg[1,1]), absDiff(subImg[1,0],subImg[0,1])),
           xDiffAvg = max(absDiff(subImg[0,0],subImg[1,0]), absDiff(subImg[0,0],subImg[0,1]), absDiff(subImg[0,0],subImg[1,1]), absDiff(subImg[1,0],subImg[0,1]));

      void set(RGB col){ iDst[x, y] = col; }
      switch(xDiff/*+xDiffAvg/4*/){
        case 1: set(clLime);                  break;
        case 2: set(clYellow);                break;
        case 3: set(clOrange);                break;
        case 4: set(clRed);                   break;
        case 5:..case 255: set(clFuchsia);    break;
        default: set(clBlack);
      }
    }

    customTexture.update(new Bitmap(iDst));
  }

  override void onUpdate(){
    view.navigate(!im.wantKeys, !im.wantMouse);
    invalidate;

    bool mustRefresh;
    static Path browserPath;
    static FileEntry[] browserFiles;

    ImStorageManager.purge(10);

    struct MyInt{ int value; }
    auto a = ImStorage!MyInt.access(123).value++;
    if(inputs.Shift.down) ImStorage!int.access(1234) += 10;

    print(ImStorageManager.detailedStats);

    with(im){
      Panel(PanelPosition.topClient, {
        fh = fh*3;
        Text("Header");
      });
      Panel(PanelPosition.rightClient, {
        padding = "2";
        Column({
          margin = "2";
          Row({
            if(pathEditor.UI(actPath, { flex = 1; })) mustRefresh = true;
            if(Btn("Refresh")) mustRefresh = true;
          });
        });
        Container({
          margin = "2";
          border = "1 normal gray";
          width = 300;
          flex = 1;
          bkColor = clSilver;

          if(chkSet(browserPath, actPath)) mustRefresh = true;

          if(mustRefresh){
            browserFiles = listFiles(browserPath, "*.jpg", "name");
          }

          static int idx = -1;
          ListBox(idx, browserFiles, (in FileEntry e){
            if(e.isDirectory){ style.bold = true; Text("["~e.name~"]"); }
                        else { Text(File(e.name).nameWithoutExt); }
          });

/*            foreach(i, const e; browserFiles){
              Row({
                //actContainer.outerPos = vec2(0, i*NormalFontHeight);
                if(e.isDirectory){ style.bold = true; Text("["~e.name~"]"); }
                            else { Text(File(e.name).nameWithoutExt); }
              });
            }*/


          flags.clipChildren = true;
          flags.vScrollState = ScrollState.auto_;
          flags.wordWrap = false;
          flags.hScrollState = ScrollState.auto_;
        });
        Column({
          margin = "2";
          Row("Details:");
          Row("Blabla:");
          Row("Blabla:");
        });



/*        Row({
          border = "1 normal black";
          width = 50;
          flags.hAlign = HAlign.center;
          Text("abc");
        });

        Row({ border = "1 normal black"; width = 50; flags.hAlign = HAlign.center;
          Text("abc");
        });

        flags.wordWrap = false;
        width  = 150; flags.autoHeight=false; flags.hScrollState = ScrollState.on;
        height = 150; flags.autoWidth =false; flags.vScrollState = ScrollState.on;
        style.bkColor = clAqua;
        fh = 255; Text("\U0001F0CF");*/

        /* Row({
          Text("threshold");
          if(Slider(threshold, logRange(1, 255), { width = 512; })) refresh;
          Text(threshold.text);
        });*/

      });
    }
  }

  override void onPaint(){
    {
      auto dr = new Drawing; scope(exit) dr.glDraw(view);
      dr.clear(clBlack);

      //draw something
      dr.textOut(0, 0, "Hello");

      if(customTexture.texIdx>=0) dr.drawGlyph(customTexture.texIdx, vec2(0), Yes.nearest);

      view.workArea = dr.bounds;
      //view.zoomAll;
    }

    im.draw;
  }
}