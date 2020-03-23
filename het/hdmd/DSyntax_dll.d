//@DLL dsyntax

//@import c:\D\libs
//@release
///@ldc   //ezzel forditva accesviolazik a delphiben.
//@single

module dsyntax_dll; //D language syntax highlighter dll

import hetlib.utils, buildsys, tokenizer,
  core.sys.windows.windows, core.sys.windows.dll;

__gshared HINSTANCE g_hInst;

extern (Windows) BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved)
{
  switch(ulReason){
	   case DLL_PROCESS_ATTACH:
	     g_hInst = hInstance;
      dll_process_attach( hInstance, true );
	   break;
   	case DLL_PROCESS_DETACH:
	     dll_process_detach( hInstance, true );
	   break;
   	case DLL_THREAD_ATTACH:
	     dll_thread_attach( true, true );
	   break;
   	case DLL_THREAD_DETACH:
	     dll_thread_detach( true, true );
	   break;
    default:
  }

//todo: make own simplified switch statements
/*  case(ulReason){
     DLL_PROCESS_ATTACH:{
       g_hInst = hInstance;
       dll_process_attach( hInstance, true );
     }
     DLL_PROCESS_DETACH:   dll_process_detach( hInstance, true );
     DLL_THREAD_ATTACH:    dll_thread_attach( true, true );
     DLL_THREAD_DETACH:    dll_thread_detach( true, true );
     default: ;
  }*/


  return true;
}

extern(Windows) export void syntaxHighLight(char* ch, ubyte* syntax, ushort* hierarchy, char* bigComments, int bigCommentsLen)
{
  tokenizer.syntaxHighLight("", to!string(ch), syntax, hierarchy, bigComments, bigCommentsLen);
}

extern(Windows) export int callHDMD(char** argv, int argc, char* pOut, int pOutLen, char* pErr, int pErrLen)
{
  string[] cmd; //todo: translate for -> foreach, if there is less than 2 ; inside
  foreach(i; 0..argc) cmd ~= toStr(argv[i]);

  static BuildSystem bs;

  string sOut, sErr;
  int code = bs.commandInterface(cmd, sOut, sErr);

  //copy c strings
  strMake(sOut, pOut, pOutLen);
  strMake(sErr, pErr, pErrLen);

  return code;
}

//todo: undeclared identifier 'memcpy' -> ekkor felajanlhatna segitseget, hogy melyik module-t kene importolni
//todo: todo system. A todo commenteknek legyen kicsit mas a szine!
//todo: latvanyos syntax szinbeallito form