//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

import het, het.obj, het.ui;

// https://www.pioneerdj.com/en/product/mixer/djm-900nxs2/black/overview/

class DJMChannel: HetObj{ mixin HETOBJ;
  DJM owner;
  int idx;
  @jsonize{
    float
      trim = .5,
      hi   = .5,
      mid  = .5,
      low  = .5;
  }
  float vu   = 0;

  this(){
    //default constructor needed vor HetObject.initValues
  }

  this(DJM owner, int idx){
    super();
    this.owner = owner;
    this.idx = idx;
  }

  void ui(){ with(im){
    Column({
      border = "1";
      margin = "2";

      Row({ flags.hAlign = HAlign.right; style.fontHeight = 40; style.bold = true; Text((idx+1).text); });

      Row({ flags.hAlign = HAlign.center; Text("TRIM"); });
      Slider(trim, "width=60 height=60");

      Text(" ");

      Row({ flags.hAlign = HAlign.center; Text("HI"); });          Slider(hi, "width=60 height=60");    Row({ flags.hAlign = HAlign.center; Text("-26   +6"); });

      Row({ flags.hAlign = HAlign.center; Text("MID"); });         Slider(mid, "width=60 height=60");

      Row({ flags.hAlign = HAlign.center; Text("LOW"); });         Slider(low, "width=60 height=60");

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
    channels = iota(4).map!(i => new DJMChannel(this, i)).array;
  }

  void ui(){ with(im){
    Row({
      foreach(i, chn; channels)
        chn.ui;
    });
  }}
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
    view.navigate(!im.wantKeys, !im.wantMouse);

    with(im) Panel(PanelPosition.topLeft, {
      width = 416;
      vScroll;

      djm.ui;
    });

    caption = lastFrameStats;//    glHandleStats;
  }

  override void onPaint(){
    dr.clear(clGray);
    drGUI.clear;      //this is needed, not automatic yet...

    im.draw(drGUI);

  }
}
