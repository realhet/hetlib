//@exe
//@release

//todo: linker error: undeclared identifier. Ertelmesen probalja megkeresni es ajanlja fel. Azazhogy nem! Inkabb legyen jo az import felderites!
//todo: editor: legyen egy fugg vonal a 80. meg a 132. karakter utan.
//todo: "//@import c:\d" should be automatic
//todo: "Must specify project target (//@EXE or //@DLL)." -> module(line,col): error:

import het.utils, buildsys;

string bold(string s) { return "\33\13"~s~"\33\7"; }

int main(string[] args){
  int code;
  application.runConsole(args,{
    string sOut, sErr;
    BuildSystem bs;

    const isDaemon = args.get(1)=="daemon";

    if(isDaemon){

      bs.disableKillProgram = true;
      bs.isDaemon           = true;

      auto commPath = getWorkPath(args, tempPath),
           cmdFile = File(commPath, "hldc_cmd.txt"),
           outFile = File(commPath, "hldc_out.txt"),
           errFile = File(commPath, "hldc_err.txt");

      while(1){
        print;
        print(bold("> Daemon mode active."), "Expecting commandline in", cmdFile, "...");

        while(!cmdFile.exists){ sleep(10); } sleep(10);
        string[] cmdArgs = cmdFile.readStr.splitCommandLine;

        string[] newArgs = args.dup;
        newArgs[1] = cmdArgs.get(1);
        foreach(i; 2..cmdArgs.length) newArgs ~= cmdArgs[i];

        print(bold("> Executing command:"), joinCommandLine(newArgs));
        print("> Build process be terminated by writing \"stop\" into the command file"); //todo: stop build process
        print;

        code = bs.commandInterface(newArgs, sOut, sErr);
        if(code) writeln("\33\14", sErr, "\33\7");

        print;
        bs.cacheInfo;

        print;
        print(bold("> Writing output:"), outFile);
        outFile.write(sOut);
        print(bold("> Writing error:"), errFile);
        errFile.write(sErr);

        print(bold("> Deleting cmd file:"), cmdFile);
        cmdFile.forcedRemove;
      }

    }else{ //normal mode
      code = bs.commandInterface(args, sOut, sErr);
      if(code) writeln("\33\14", sErr, "\33\7");
    }

  });
  return code;
}