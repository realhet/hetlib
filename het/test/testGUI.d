//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

import het, het.ui;

/////////////////////////////////////////////////////////
// UTF TESTS                                          ///
/////////////////////////////////////////////////////////

void testUTF32(){
  writeln("\nByte encodings of max UTF32 char");
  auto s32 = "\U0010FFFF"d;
  auto s16 = "\U0010FFFF"w;
  auto s8 = "\U0010FFFF";

  writefln("utf32 bytes %( %X %)", cast(ubyte[])s32);
  writefln("utf16 bytes %( %X %)", cast(ubyte[])s16);
  writefln("utf8  bytes %( %x %)", cast(ubyte[])s8);

  // --------------------------------------------------
  void dFileTest(in File file){
    auto size = file.size;
    double _t0;
    void t0(string name){ write("Test:"~name, "  "); _t0 = QPS; }
    void t1(){ enum MB = 1.0/1024/1024; auto dt = QPS-_t0; writefln("Time: %5.3f  Size: %5.3fMB  Speed: %7.3fMB/s", dt, size*MB, size*MB/dt); }

    foreach(i; 0..2){
      t0(format("%-30s 8 ", file.name));
      auto lines = file.readLines;
      t1;
      t0(format("%-30s 32", file.name));
      auto lines32 = file.readLines32;
      t1;
    }

    writeln;
  }

  auto dFiles = [
    `c:\D\ldc2\import\std\internal\unicode_tables.d`,
    `c:\D\ldc2\import\std\datetime\systime.d`,
    `c:\D\ldc2\import\core\sys\windows\uuid.d`,
    `c:\D\ldc2\import\std\datetime\date.d`,
    `c:\d\libs\het\Utils.d`,
    `c:\d\libs\het\OpenCL.d`
  ].map!(a => File(a));

  writeln("\nLoad and decode big .d files");
  foreach(f; dFiles) dFileTest(f);

  writeln("\nIsletter test");

  import std.uni;
  dchar ch;
  void u(){ print(ch,
    ch.isAlpha?"Alpha":"",
    ch.isNumber?"Number":"",
    ch.isGraphical?"Graphical":"",
    ch.isControl?"Control":"",
    ch.isWhite?"White":"",
    ch.isSpace?"Space":"",
    ch.isPunctuation?"Punctuation":"",
    ch.isSymbol?"Symbol":"",
    ch.isMark?"Mark":""
  ); }

  ch = 'A'; u;
  ch = '0'; u;
  ch = 0x2161; u; //roman II.
  ch = 0x00E9; u; //e'
  ch = 0x1D6FC; u; //alpha  complicated
  ch = 0x3b1; u; //alpha
  ch = 0x1F600; u; //smiley
  ch = 0x1F600; u; //smiley
  ch = '+'; u;
  ch = '*'; u;
  ch = '~'; u;
  ch = '.'; u;
  ch = '['; u; //[ symbol
  ch = ' '; u;
  ch = '\r'; u; //[ control
  ch = '\r'; u; //[ control
  ch = '\t'; u; //[ control

  readln;
}




class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////
  override void onCreate(){ // create /////////////////////////////////
    //testUTF32;

    //VSynch = 1;
    //SetPriorityClass(GetCurrentProcess, REALTIME_PRIORITY_CLASS);
  }

  override void onDestroy(){ // destroy //////////////////////////////
  }

  override void onUpdate(){ // update ////////////////////////////////
    invalidate; //todo: opt
    updateView(1, 1);

    caption = FPS.text;

    with(im) Panel({
      width = 416;

      //uiContainerAlignTest;

      static s = "Hello\r\nWorld!",
             editWidth = 100;

      Row({  Text("Test control  ");  HSlider(editWidth, range(1, 300));  });
      Row({  foreach(i; 0..2) Edit(s, id(i), { width = editWidth; style.fontHeight = 40; });  });
      Text(im.textEditorState.dbg);

    });

    if(inputs.F1.pressed){
      textures.dump;
    }
   }

  override void onPaint(){ // paint //////////////////////////////////////
    dr.clear(clSilver);
    drGUI.clear;

    im.draw(drGUI);

    drawFpsTimeLine;
  }

}


