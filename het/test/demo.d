//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

/////////////////////////////////
//   hetlib demo application   //
/////////////////////////////////


import het, het.ui;

struct DemoChapter{
  string name;
  void function() ui;
}

struct DemoCategory{
  string name;
  DemoChapter[] chapters;
}

const DemoChapter[] chapters = [
  DemoChapter("Draw2D", {with(im){

  }}),
  DemoChapter("TextStyle", {with(im){
    static TextStyle ts;
    static bool running;
    if(running.chkSet) ts = tsNormal;


    Chapter("TextStyle struct properties");

    [`font="Segoe Script"|Selects a different @fontFace`,
     `fontHeight=24|Sets the font's height to @24 pixels`,
     `bold=1|Turn on @bold`,
     `italic=1|Turn on @italic`,
     `underline=1|Turn on @underline`,
     `strikeout=1|Turn on @strikeout`,
     `fontColor=0xFF0080|Sets the @color of the font`,
     `bkColor=lime|Sets the @color of the font background`].each!((s){
       s.isWild("*=*|*");
       OldListItem( format("%s=%s\t\t\t\t%s", bold(wild[0]), wild[1], wild[2].replace("@", tag("style "~wild[0]~"="~wild[1]))) );
     });

     //stdUI(ts);

     enum fonts = ["Courier New", "Times New Roman", "Arial", "Consolas"];
     static string actFont;
     ComboBox(actFont, fonts, (string f){ style.font = f; Text(f, "  \t"); Text("The quick brown fox jumps over the lazy dog."); });

     //immutable colors = AliasSeq!(clRed, clGreen, clLime, clYellow );

     //mixin("immutable NamedColor[] colors = [", "Red Lime Blue Yellow".split(' ').map!(a => `{"*",cl*}`.replace("*", a)).join(","), "];");

     struct NamedColor { string name; RGB color; }
     immutable NamedColor[] colors = [{ "red", clRed }, { "green", clLime }, { "blue", clBlue }, { "yellow", clYellow },];
     static colorIdx = -1;
     ComboBox(colorIdx, colors, (in NamedColor nc){ Row({ bkColor = nc.color; width = 24; height = 16; border = "1 normal black"; }); Text(" ", nc.name); });
  }}),
];

class FrmDemo: GLWindow { mixin autoCreate; // FrmDemo ////////////////////////////

  DemoChapter actChapter;

  override void onCreate(){
  }

  override void onUpdate(){
    invalidate; //todo: opt

    //const PanelWidth = 416;

    //view.subScreenArea = Bounds2f(float(PanelWidth) / clientWidth, 0, 1, 1);
    view.navigate(!im.wantKeys, !im.wantMouse);

    //automatically ZoomAll when the resolution
    //if(view.workArea.width>8 && view.workArea.height>8 && chkSet(lastWorkArea, view.workArea)) view.zoomAll;


    with(im) Panel(PanelPosition.topLeft, {
      //todo: conflicts with PanelPosition //outerHeight = clientHeight;
      margin = "0"; padding = "0";
      vScroll;
      Row({
        flags.yAlign = YAlign.top;
        outerSize = clientSize.toF;
        Column({
          ListBox(actChapter, chapters, (in DemoChapter c){ Text(c.name); });
        });
        Text(" ");
        Column({
          if(actChapter.ui) Panel(PanelPosition.topRight, {
            actChapter.ui();
          });
        });
      });

    });

  }

  override void onPaint(){
    dr.clear;
    drGUI.clear; //todo: why is this mandatory

    //drGUI.textOut(0, 0, "Hello World");

    im.draw(drGUI);
  }
}


// floating panel test //////////////////////////////
/*    if(1) foreach(i; 0..100) with(im) Panel({
      actContainer.outerPos = V2f(300 + 200*cos(QPS+i*0.8), 300 + 200*sin(QPS+i*(sin(QPS))*.1));
      Text(tsTitle, "Hello %s. Panel!".format(i+1));
    });*/
