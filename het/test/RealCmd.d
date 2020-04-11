//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

import het, het.ui;

struct FileEntry{
  @property{
    string fullName;
    bool isPath()const { return fullName.endsWith('\\'); }
    bool isFile()const { return !isPath; }
    //string name() { return Path(fullName).name; }
    string ext()  { return File(fullName).ext; }

  }
}

class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////
  override void onCreate(){ // create /////////////////////////////////
    //VSynch = 1;
    //SetPriorityClass(GetCurrentProcess, REALTIME_PRIORITY_CLASS);
  }

  override void onDestroy(){ // destroy //////////////////////////////
  }

  override void onUpdate(){ // update ////////////////////////////////
    invalidate; //todo: opt
    //view.navigate(!im.wantKeys, !im.wantMouse);

    caption = FPS.text;

    with(im) Panel({
      width = 416;

      //uiContainerAlignTest;

      static s = "Hello\r\nWorld!",
             editWidth = 100;

      Row({  Text("Test control  ");  Slider(editWidth, range(1, 300));  });
      Row({  foreach(i; 0..2) Edit(s, id(i), { width = editWidth; style.fontHeight = 40; });  });
      Text(im.textEditorState.dbg);

    });

    if(inputs.F1.pressed){ textures.dump; }

   }

  override void onPaint(){ // paint //////////////////////////////////////
    dr.clear(clSilver);
    drGUI.clear;

    im.draw(drGUI);

    drawFpsTimeLine;
  }

}


