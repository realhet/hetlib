//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

//what to do when throw exceptions
enum testOSException = 1;  //os exception  otherwise sw exception

version = windowed;
    //version = testWinOnCreate;
    version = testWinOnUpdate;
    //version = testWinOnPaint;
    //version = threadException;  //use only this

void doException(){
  sleep(1000);
  static if(testOSException){
    print("doing OS exception");
    asm { mov RAX, 0; mov [RAX], 0; }
  }else{//swException
    print("doing SW exception");
    throw new Exception("Custom exception");
  }
}


version(windowed) {

  import het, het.ui;

  class FrmMain: GLWindow { mixin autoCreate; // FrmMain ////////////////////////////

    override void onCreate(){
      print("win.onCreate");
      version(testWinOnCreate) doException;

      version(threadException){
        import core.thread;
        new Thread(&doException).start;
      }
    }

    override void onUpdate(){
      print("win.onUpdate");
      version(testWinOnUpdate) doException;
    }

    override void onPaint(){
      print("win.onPaint");
      dr.clear(clGray);
      dr.textOut(0, 0, "Hello World");
      version(testWinOnPaint) doException;
    }
  }

}else{ //nonWindowes

  import het.utils;

  void main(){
    application.runConsole({
      print("console runing");
      doException;
    });
  }

}