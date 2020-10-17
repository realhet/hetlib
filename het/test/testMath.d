//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

///@compile --unittest  //this is broken because of my shitty linker usage

import het.math, std.stdio;

void main(){ import het.utils; application.runConsole({
  unittest_main;
  writeln("done main");
}); }
