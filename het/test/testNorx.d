//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

import het.utils;

void test(){
  auto data = norx!(32, 4, 1).encrypt("1234", "basic", "Hello world!");
  norx!(32, 4, 1).decrypt("1234", "basic", data).to!string.print;

  benchmark_norx;

  benchmark_xxh;
}

void main(){
  application.runConsole({
    test;
  });
}