//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

import het, het.obj, het.ui;

class DJMChannel: HetObj{ mixin HETOBJ;
  @jsonize{
    float
      trim = .5,
      hi   = .5,
      mid  = .5,
      low  = .5;
  }
  float vu   = 0;

  void ui(){ with(im){
    Column({
      Slider(trim, "width=4x height=4x");

    });
  }}
}

struct HetLink(T:HetObj){
  HetObj obj;
  alias obj this;
}

class DJM: HetObj{ mixin HETOBJ;
  DJMChannel[4] channels;

  this(){
    channels = iota(4).map!(i => new DJMChannel).array;
  }
}



class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////
  DJM djm;

  override void onCreate(){
    djm = new DJM;
    djm.loadFromJSON(ini.read("djm", ""));
  }

  override void onDestroy(){
    ini.write("djm", djm.saveToJSON);
  }

  override void onUpdate(){
    invalidate;
  }

  override void onPaint(){
    dr.clear(clGray);
  }
}
