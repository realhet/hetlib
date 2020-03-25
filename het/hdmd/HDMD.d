//@exe
//@import c:\D\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@run $ c:\D\HDMD\dsyntax_dll.d -cv
///@run @pause

//todo: linker error: undeclared identifier. Ertelmesen probalja megkeresni es ajanlja fel. Azazhogy nem! Inkabb legyen jo az import felderites!
//todo: editor: legyen egy fugg vonal a 80. meg a 132. karakter utan.
//todo: "//@import c:\d" should be automatic

import het.utils, buildsys;

int main(string[] args){
  int code;
  application.runConsole(args,{
    string sOut, sErr;
    BuildSystem bs;
    code = bs.commandInterface(args, sOut, sErr);
    if(code) writeln("\33\14", sErr, "\33\7");
  });
  return code;
}