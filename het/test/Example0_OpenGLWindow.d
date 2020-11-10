//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release

import het;

class MyWin: GLWindow{
  mixin autoCreate;  //automatically creates an instance of this form at startup

  override void onCreate(){
    writeln("Console test");
    writeln("Press Enter to create an OpenGL Window!");
    readln;
    caption = "Hello DLang OpenGL World!";      //Set Window caption
  }
  override void onPaint(){
    //Do some simple OpenGL stuff
    gl.clearColor(clLime);
    gl.clear(GL_COLOR_BUFFER_BIT);
  }
}


