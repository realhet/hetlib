//@exe
//@import c:\D\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3

//@release
///@debug

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

    const backgroundMode = args.get(1)=="background";

    if(backgroundMode){
      auto cmdFile = File(tempPath, "hldc_cmd.txt");
      auto outFile = File(tempPath, "hldc_out.txt");
      auto errFile = File(tempPath, "hldc_err.txt");

      while(1){
        print;
        print("> Background mode active.");
        print("> Expecting commandline in", cmdFile, "...");

        while(!cmdFile.exists){ sleep(10); } sleep(10);
        string[] cmdArgs = cmdFile.readStr.splitCommandLine;

        string[] newArgs = args.dup;
        newArgs[1] = cmdArgs.get(1);
        foreach(i; 2..cmdArgs.length) newArgs ~= cmdArgs[i];

        print("> Executing:", joinCommandLine(newArgs));
        print;

        code = bs.commandInterface(newArgs, sOut, sErr);
        if(code) writeln("\33\14", sErr, "\33\7");

        print;
        print("> Writing output:", outFile);
        outFile.writeStr(sOut);
        print("> Writing error:", errFile);
        errFile.writeStr(sErr);

        print("> Deleting cmd file:", cmdFile);
        cmdFile.forcedRemove;
      }

    }else{ //normal mode
      code = bs.commandInterface(args, sOut, sErr);
      if(code) writeln("\33\14", sErr, "\33\7");
    }

  });
  return code;
}