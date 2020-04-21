//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

import het.utils;

struct TestStruct{
  static void testLogs(){
    DBG("Location", __PRETTY_FUNCTION__, __FUNCTION__, __FILE__, __LINE__);
    DBG("Another debug message", 1, 2, 3);
    LOG("#tag1 #tag2 An imformation");
    WARN("Another warning");
    ERR("Another error");
    CRIT("A fatal error");
  }
}


void main(){
  application.runConsole({
    TestStruct.testLogs;
  });
}