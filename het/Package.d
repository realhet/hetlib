module het; /+DIDE+/

version(/+$DIDE_REGION Global System stuff+/all)
{
	version(/+$DIDE_REGION+/all) {
		__gshared logFileOps = false; 
		 
		pragma(lib, "ole32.lib"); //COM (OLE Com Object) initialization is in utils.d, not in win.d
		pragma(lib, "comdlg32.lib"); //for the dialogs
		pragma(lib, "winmm.lib"); //for playsound
		
		//Todo: ref const for opCmp and opEquals
		
		//Todo: msvcrt.lib(initializers.obj): warning LNK4098: defaultlib 'libcmt.lib' conflicts with use of other libs; use /NODEFAULTLIB:library
		//https://stackoverflow.com/questions/3007312/resolving-lnk4098-defaultlib-msvcrt-conflicts-with
		
		//Todo: UTILS lots of todes commented out, because of the compile log is small
		/+
			//todo: IDE: % as postFix operator: 25% -> (25)*.01
			//todo: IDE: visszajatszo debugger/logger
			//todo: IDE syntax highlight control chars in "" and ''. Also format %f in format strings
			
			//todo: error display: hibas parameterlistanal a jot meg a rosszat egymas melle parositani, hogy ne guvvadjon ki a szemem.
			
			//todo: uj todo kategoria: //fixme: //bug: if something is fucked up. todo is for new stuff
			//todo: DIDE: Hibauzenetben a fileok elerhetove tetele: "Module not found: hetlib\debugclient.d referenced from: c:\d\libs\het\utils.d"
			//todo: legyen //bug:comment is!
			//todo: textformatter: egy grafikus ize, amivel a writefln()-t meg lehet formazni: tobbsoros is lehessen, meg egerrel menjen. Szinezni is lehessen!
			//todo: editor: a commenteket nyelvtani elementhez kene kapcsolni. Es akkor mar lebeghetnenek, mint egy gondolatbuborek. Haszonlo szerkeszthetoseg kene, mint az onshape commentjeinel.
			//todo: exception mutatasanal fatal exception kezelese: amikor a program mindenkeppen megall utana.
			//todo: syntax level visualizalas 3d kiemelkedo effekttel.
			//todo: syntax: visualize number literals: ad thousands and at 64K ranges. 0x12345678 -> 0x|1234|5678
			//todo: editor: irja ki a selection hosszat, rect-meretet!
			//todo: syntax: 0x2ef7fc2c0b4e5915; ennel bugzik a binary 0 1 highlight
			
			//todo: az absolut modulneveknek a ctrlklikket kezelni kell! Ha ugyanaz a prefix van az ugraskor, mint ami a current modul, akkor nem kell uj konyvtarban keresni
			//todo: legyen nyilvantartva a main project es abban a searchpath es a navigalas akkor mehet azokhoz relativan is
			
			//todo: todo kijelzes: el vannak csuszva a sorok. multiline string bekavarhat.
			//todo: todo kijelzes: legyen szurke a text, az errortype kozpontositas utan
			
			//todo: linker, dmd.exe elerese absolute path-al a builderbol.
			//todo: DIDE Ctrl+F amikor raugrik egy talalatra, mutassa a korulotte levo sorokat is, mint a gotoError()
			
			//todo: syntax highlight std.string: ne legyen alap tipus szine a stringnek az importban
			//todo: map file alapjan az accessviolat visszakuldeni a DIDE-be.
			//todo: editor mutassa az indent hibakat!
			
			//todo: editor.exception: mutassa az std\stdio.d(404,1): Exception: blabla jellegu hibakat!
			
			//todo: editor: tablazatos kod rendberakasa
			
			//test tabs		12353124fewq	1342314	54321rt
			//test tabs		34561243	gre12tg43	4321
			//			splitted	by 3 tabs needed
			
			/*Poti("PolyOpt SmallSegLen"     ,	polyOpt_SmallSegLen        ,	1        ,	500     ,	10	),
				Poti("PolyOpt Epsilon"	, polyOpt_Epsilon	, 0	, 500	,	1	),
				Poti("PolyOpt parallelThreshold"	 , polyOpt_ParallelThreshold    , 0.0        , 1.0		,  0.01 ),
				Poti("PolyOpt Removable Seg Len"	 , polyOpt_tinySegLen       , 1        , 300	,  1 ),
				Poti("PolyOpt Seg Len Mult"  , polyOpt_tinySegLocalErrorFactor       , 0        ,	20     ,  0.5 ), */
			
			//todo: a bookmarkok is menjenek a tartalomjegyzek melle
			//todo: tokenizer/syntax highlighter bexarik a unicode-tol
			
			//todo: version stringek osszegyujtese a programban es az IDE ajanlja fel, hogy mik a lehetosegek!
			//todo: editor cursor over bigComments
			//todo: editor: amikor kijelolok egy szovegreszt, szurkevel jelolje a kepernyon az ugyanolyan szovegreszeket! Egy special keyre odarakhatna a tobbihez is egy-egy kurzort
			//todo: editor: accumulation clipboard: hozzacsapja a kijelolest a clipboard vegehez. Amikor sok szirszard szedek ossze es egy helyre akarom azokat rakni.
			//todo: linker errort detektalni: Kell hozza csinalni egy classt, aminek csak forwardolva vannak a dolgai. " Error " a trigger. Elozo sor is kell. OPTLINK, Copyright, http://www.digitalmars kezdetu sorokkal nem foglalkozni.
			//todo: preprocess: implement with(a,b,c,...)
			//todo: multiline todo /* es / + commentekre
			
			//todo: logging automatizalasa class osszes functionjara
			
			//todo: ide: o'rajel summa'zo': a soroktol utasitasoktol jobbra irt szamokat osszeadogatja.
			//todo: ide/debug: consolera vagy logba iraskor latszodjon a kibocsajto utasitas helye.
			//todo: a main()-t automatikusan belerakni egy app.runconsole-ba
			
			//todo: File.write doesn't creates the path appPath~\temp
			//todo: nyelvi bovites: ismerje fel a szamoknal az informatikai kilo, mega, giga, tera postfixeket! A decimalisakra ott van az e3 e6 e9 e12.
			
			//todo: az uj tokenizerben meg syntax highlighterben az x"string"-et hexString-et jelolni.
			//todo: View2D: zoom to cursort es a nemlinearis follow()-ot osszehozni.
			
			//todo: IDE: ha nem release build van forditva, akkor az assert/in/out/invariant legyen jelolve szurkevel!
		+/
		
		
		//Imports /////////////////////////////
		version(/+$DIDE_REGION Imports+/all)
		{
			//std imports
			public import std.array, std.conv, std.typecons, std.range, std.format, std.traits, std.meta; //het.math also imports std.string, std.uni, std.algorithm, std.functional
			public import core.stdc.string : memcpy; 
			public import std.utf; 
			public import std.uni : byCodePoint, isAlpha, isNumber, isAlphaNum; 
			public import std.uri: urlEncode = encode, urlDecode = decode; 
			public import std.process : environment, thisThreadID, execute, executeShell, ExecuteConfig = Config; 
			public import std.zlib : compress, uncompress; 
			public import std.stdio : stdin, stdout, stderr, readln, StdFile = File, stdWrite = write; 
			//public import std.bitmanip : swapEndian, BitArray, bitfields, bitsSet;
			public import std.bitmanip; 
			public import std.typecons: Typedef; 
			public import std.path: baseName; 
			public import std.exception : collectException, ifThrown, assertThrown; 
			public import std.system : endian, os; 
			
			public import het.quantities; 
			
			public import std.concurrency, std.signals; 
			
			import std.encoding : transcode, Windows1252String; 
			import std.exception : stdEnforce = enforce; 
			import std.getopt; 
			
			
			//hetlib imports
			public import het.math; 
			
			//Windows imports
			public import core.sys.windows.windows : 
				HANDLE, GetCurrentProcess, SetPriorityClass, GetModuleHandle,
				HIGH_PRIORITY_CLASS, REALTIME_PRIORITY_CLASS, NORMAL_PRIORITY_CLASS,
				BELOW_NORMAL_PRIORITY_CLASS, ABOVE_NORMAL_PRIORITY_CLASS, IDLE_PRIORITY_CLASS, //, PROCESS_MODE_BACKGROUND_BEGIN, PROCESS_MODE_BACKGROUND_END;
				HRESULT, HWND, HINSTANCE, GUID, SYSTEMTIME, FILETIME, STD_OUTPUT_HANDLE, HMODULE,
				GetCommandLine, ExitProcess, GetConsoleWindow, SetConsoleTextAttribute, SetConsoleCP, SetConsoleOutputCP, ShowWindow,
				SetFocus, SetForegroundWindow, GetForegroundWindow,
				SetWindowPos, GetLastError, FormatMessageA, MessageBeep, QueryPerformanceCounter, QueryPerformanceFrequency,
				GetStdHandle, GetTempPathW, GetFileTime, SetFileTime, GetFileAttributesW,
				FileTimeToLocalFileTime, LocalFileTimeToFileTime, FileTimeToSystemTime, SystemTimeToFileTime, GetLocalTime, GetSystemTimeAsFileTime, DosDateTimeToFileTime,
				Sleep, GetComputerNameW, GetProcAddress,
				SW_SHOW, SW_HIDE, SWP_NOACTIVATE, SWP_NOOWNERZORDER, FORMAT_MESSAGE_FROM_SYSTEM, FORMAT_MESSAGE_IGNORE_INSERTS,
				GetSystemTimes, MEMORYSTATUSEX, GlobalMemoryStatusEx,
				HICON,
				GetLongPathNameA, GetShortPathNameA,
				CreateEventA, CloseHandle, WaitForSingleObject, WAIT_OBJECT_0,
				
				//flags for Dialogs
				MessageBoxW, CoTaskMemFree, SendMessage, PostMessage,
				IDOK, IDCANCEL, IDABORT, IDRETRY, IDIGNORE, IDYES, IDNO, IDCLOSE, IDHELP, IDTRYAGAIN, IDCONTINUE,
				MB_OK, MB_OKCANCEL,
				MB_ABORTRETRYIGNORE, MB_YESNOCANCEL, MB_YESNO, MB_RETRYCANCEL, MB_CANCELTRYCONTINUE, MB_TYPEMASK, MB_ICONHAND, MB_ICONSTOP, MB_ICONERROR,
				MB_ICONQUESTION,MB_ICONEXCLAMATION ,MB_ICONWARNING,MB_ICONASTERISK,MB_ICONINFORMATION,MB_USERICON,MB_ICONMASK,
				MB_DEFBUTTON1 ,MB_DEFBUTTON2,MB_DEFBUTTON3,MB_DEFBUTTON4,MB_DEFMASK,MB_APPLMODAL,MB_SYSTEMMODAL ,MB_TASKMODAL,MB_MODEMASK,
				MB_HELP,MB_NOFOCUS,MB_MISCMASK ,MB_SETFOREGROUND,MB_DEFAULT_DESKTOP_ONLY,MB_TOPMOST,MB_SERVICE_NOTIFICATION_NT3X ,
				MB_RIGHT,MB_RTLREADING,MB_SERVICE_NOTIFICATION,
				
				TIME_ZONE_INFORMATION, GetTimeZoneInformation,
				
				HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER; 
			
			import std.windows.registry, core.sys.windows.winreg, core.thread, std.file, std.path,
			std.json, std.parallelism, core.runtime; 
			
			public import core.sys.windows.com : IUnknown; 
			import core.sys.windows.com : CoInitializeEx, CoUninitialize; 
			
			import core.sys.windows.shlobj; 
			
			//LDC 1.28 bugfix:
			
			import std.digest : toHexString;  //unknown id: toHexString   -> std.digest.digest is deprecated
			public import std.array : join;  //het.utils:  blabla.join conflicts with blabla.join
			//het.ui: LDC 1.28: with(het.inputs){ clipboard } <- het.inputs has opDispatch(), anc it tried to search 'clipboard' in that.
			
		}
		
	}version(/+$DIDE_REGION+/all)
	{
		//these are updated by het.win
		__gshared HWND _mainWindowHandle; //het.win fills it
		__gshared bool delegate() _mainWindowIsForeground = ()=>false; 
		
		alias const(GUID)* REFIID, PGUID; 
		
		template uuid(T, string g)
		{
			const uuid = "const IID IID_"~T.stringof~"={ 0x" ~ g[0..8] ~ ",0x" ~ g[9..13] ~ ",0x" ~ g[14..18] ~ ",[0x" ~ g[19..21] ~ ",0x" ~
				g[21..23] ~ ",0x" ~ g[24..26] ~ ",0x" ~ g[26..28] ~ ",0x" ~ g[28..30] ~ ",0x" ~ g[30..32] ~ ",0x" ~ g[32..34] ~ ",0x" ~ g[34..36] ~ "]};"~
				"template uuidof(T:"~T.stringof~"){ const uuidof = IID_"~T.stringof~";}"; 
		} 
		
		template clsid(T, string g)
		{
			const clsid = "const IID CLSID_"~T.stringof~"={ 0x" ~ g[0..8] ~ ",0x" ~ g[9..13] ~ ",0x" ~ g[14..18] ~ ",[0x" ~ g[19..21] ~ ",0x" ~
				g[21..23] ~ ",0x" ~ g[24..26] ~ ",0x" ~ g[26..28] ~ ",0x" ~ g[28..30] ~ ",0x" ~ g[30..32] ~ ",0x" ~ g[32..34] ~ ",0x" ~ g[34..36] ~ "]};"~
				"template clsidof(T:"~T.stringof~"){ const clsidof = IID_"~T.stringof~";}"; 
			
			//Todo: it's not so good.
		} 
		
		
		//for main thread only, called from application class //
		
		private void globalInitialize()
		{
			//Note: ezek a runConsole-bol vagy a winmainbol hivodnak es csak egyszer.
			//Todo: a unittest alatt nem indul ez el.
			//Todo: functional tests: nem ide kene
			//functional tests
			
			application.tickTime = now; 
			
			installExceptionFilter; 
			
			DateTime.selftest; 
			het.math.unittest_main; //1ms
			
			const s1 = "hello", s2 = "Nobody inspects the spammish repetition"; 
			enforce(xxh32(s1)==0xfb0077f9); 
			enforce(xxh32(s2, 123456) == 0xc2845cee); 
			enforce(crc32("Hello")==0xf7d18982); 
			enforce(crc32(s2) == 0xAD4270ED); 
			
			XXH3.selftest; 
			
			{ RNG rng; rng.seed = 0; enforce(iota(30).map!(i => rng.random(100).text).join(' ') == "0 3 86 20 27 67 31 16 37 42 8 47 7 84 5 29 91 36 77 32 69 84 71 30 16 32 46 24 82 27"); }
			
			enforce(maskLowBits(0)==0); 
			enforce(maskLowBits(1)==1); 
			enforce(maskLowBits(2)==3); 
			enforce(maskLowBits(3)==3); 
			enforce(maskLowBits(4)==7); 
			
			enforce(countHighZeroBits(0)==32); 
			enforce(countHighZeroBits(1)==31); 
			enforce(countHighZeroBits(2)==30); 
			enforce(countHighZeroBits(0x7FFF0000)==1); 
			enforce(countHighZeroBits(0xFFFF0000)==0); 
			
			UpdateInterval()._testRepeater; 
			
			enforce([8,9,10,11,12,13].map!(a => alignUp(a, 4)).equal([8,12,12,12,12,16])); 
			
			//startup
			
			CoInitializeEx(null, 0); //fixes problem with "file explorer wont refrest when different filetype selected.". No need for COINIT_APARTMENTTHREADED, just a 0 is enough.
			//before 220623 it was: CoInitialize(null);
			
			ini.loadIni; 
			
			console.setUTF8; 
			
			test_SrcId; 
		} 
		
		private void globalFinalize() {
			 //Note: ezek a runConsole-bol vagy a winmainbol hivodnak es csak egyszer.
			//cleanup
			ini.saveIni; 
			CoUninitialize; 
		} 
		
		//static this for each thread ////////////////////////////
		
		static this() {
			 //for all threads <- bullshit!!! It's not shared!!!
			randomize; //randomices for every thread using QPC and thisThreadID
			init__iob_func; 
		} 
		
		//static this for process ////////////////////////////
		
		__gshared const DateTime appStarted, appStartedDay; //Todo: how to make it readonly?
		
		shared static this() {
			cast()appStarted = now; 
			cast()appStartedDay = appStarted.localDayStart; 
			het.parser.initializeKeywordDictionaries; 
		} 
	}struct application
	{
		/// application /////////////////////////
		__gshared static private
		{
			//__gshared is for variables, static is for functions. Doesn't matter what is in front of the 'struct' keyword.
			bool initialized, finalized, running_; 
			/+
				No need for KillerThread anymore: DIDE can kill.
				
				//Lets the executable stopped from DIDE when the windows message loop is not responding.
				class KillerThread: Thread
				{
					bool over, finished; 
					this()
					{
						super(
							{
								auto t0	= 0.0 *second; 
								const timeOut	= 0.66*second; //it shut downs after a little less than the DIDE.killExeTimeout (1sec)
								while(!over)
								{
									if(t0 == 0*second)
									{
										if(dbg.forceExit_check) t0 = QPS; //start timer
									}
									else
									{
										auto elapsed = QPS-t0; 
										if(!dbg.forceExit_check)
										{
											t0 = 0*second; //reset timer. exiting out normally.
										}
										else
										{
											if(elapsed>timeOut)
											{ application.exit; }
										}
									}
									.sleep(15); 
								}
								finished = true; 
							}
						); 
					} 
					
					void stop()
					{
						over = true; 
						while(!finished) .sleep(5); //Have to wait the thread
					} 
				} 
				
				KillerThread killerThread; 
			+/
		} 
		__gshared static public
		{
			uint tick; //enough	for 2 years @ 60Hz
			DateTime tickTime; 	//it is always behind one frame time compared to now(). But it is only accessed once per frame. If there is LAG, it is interpolated.
			Time deltaTime; 
			string timeZoneName; 
			
			import core.runtime : Runtime; 
			alias args = Runtime.args; 
			
			@property bool running()
			{ return running_; } 
			
			void exit(uint code=0, Flag!"finalize" finalize=No.finalize)
			{
				//immediate exit
				if(finalize) try { _finalize; }catch(Throwable) {}
				ExitProcess(code); 
			} 
			
			///win.main() or runConsole() calls this from the main thread only.
			void _initialize()
			{
				if(chkSet(initialized))
				{
					running_ = true; 
					SetPriorityClass(GetCurrentProcess, HIGH_PRIORITY_CLASS); 
					application.timeZoneName = DateTime.currentTimeZoneName; 
					dbg; //start it up
					if(dbg.data) {
						 import std.process; 
						dbg.data.exe_pid = thisProcessID; 
						dbg.data.console_hwnd = cast(int)(console.hwnd); 
					}
					//killerThread = new KillerThread;  killerThread.start; 
					console.handleException({ globalInitialize; } ); 
				}
			} 
			
			void _finalize()
			{
				//win.main() or runConsole() calls this.
				if(!initialized) return; 
				if(chkSet(finalized))
				{
					console.handleException({ globalFinalize; } ); 
					//killerThread.stop; 
					//dont! -> destroy(killerThread); note: Sometimes it is destroyed automatically, and this causes an access viole reading from addr 0
					running_ = false; 
				}else
				enforce(false, "Application is already finalized"); 
			} 
			
			void _updateTimeZone()
			{
				//Opt: This query takes 0.75 millisec, I tried WM_TIMECHANGE but that not works.
				const t0 = now; 
				if(application.timeZoneName.chkSet(DateTime.currentTimeZoneName))
				{
					LocalDateTime.resetLocalDateCache; 
					LOG("TimeZone changed to:", application.timeZoneName, now-t0); 
				}
			} 
			
			int runConsole(void delegate() dg)
			{
				enforce(!initialized, "Application.run(): Already running."); 
				_initialize; 
				auto ret = console.handleException(dg); 
				_finalize; 
				//here we wait all threads. In windowed mode we don't
				return ret; 
			} 
			
			@property HWND handle()
			{ return _mainWindowHandle; } 
			
			bool isForeground()
			{ return _mainWindowIsForeground(); } 
		} 
	} version(/+$DIDE_REGION+/all)
	{
		struct console
		{
			//Console //////////////////////////////////////////////////////////////////////
			static private
			{
				__gshared bool visible_; 
				__gshared bool exceptionHandlerActive_; 
				HWND hwnd() {
					__gshared void* handle; 
					if(handle is null) { handle = GetConsoleWindow; }
					return handle; 
				} 
				
				auto outputHandle() { return GetStdHandle(STD_OUTPUT_HANDLE); } 
				
				private int _textAttr = 7; 
				private void setTextAttr() { flush; SetConsoleTextAttribute(outputHandle, cast(ushort)_textAttr); } 
				@property int	color()	 { return _textAttr.getBits	(0, 4); } 
				@property void	color(int c)	 { _textAttr =	_textAttr.setBits	(0, 4, c); setTextAttr(); } 
				@property int	bkColor()	 { return _textAttr.getBits	(4, 4); } 
				@property void	bkColor(int c)	 { _textAttr =	_textAttr.setBits	(4, 4, c); setTextAttr(); } 
				@property bool	reversevideo()	 { return _textAttr.getBits	(14, 1)!=0; } 
				@property void	reversevideo(bool b)	 { _textAttr =	_textAttr.setBits	(14, 1, b); setTextAttr(); } 
				@property bool	underscore()	 { return _textAttr.getBits	(15, 1)!=0; } 
				@property void	underscore(bool b)	 { _textAttr =	_textAttr.setBits	(15, 1, b); setTextAttr(); } 
				
				void indentAdjust(int param) {
					switch(param) {
						case 0: indent = 0; break; 
						case 1: indent++; break; 
						case 2: indent--; break; 
						default: 
					}
					//stdWrite("[INDENT <- %d]".format(indent));
				} 
				
				struct Recorder
				{
					string recordedStr; 
					bool recording; 
					
					//recording ------------------
					void start() {
						if(recording) WARN("Already recording."); 
						recording = true; 
					} 
					
					string stop() {
						if(!recording) WARN("Did not started recording."); 
						recording = false; 
						auto a = recordedStr; //Todo: sync fails here
						recordedStr = ""; 
						return a; 
					} 
				} 
				__gshared Recorder recorder; 
				
				private bool triggerFocusMainWindow; 
				
				void myWrite(string s)
				{
					if(s.empty) return; 
					
					void wr(string s)
					{
						if(indent>0) {
							auto si = "\n" ~ "    ".replicate(indent.min(20)); 
							s = s.safeUTF8.replace("\n", si);   //Opt: safeUTF8 is fucking slow!!!!
						}
						
						stdWrite(s); //this is safe for UTF8 errors.
						if(recorder.recording) synchronized recorder.recordedStr ~= s; 
					} 
					
					while(!s.empty)
					{
						auto i = (cast(ubyte[])s).countUntil!(a => a.inRange('\33', '\36'));  //works on ubyte[], so it can't raise UTF8 errors
						if(i<0) { wr(s); break; }//no escapes at all
						if(i>0) { wr(s[0..i]); s = s[i..$]; }//write test before the escape
						//here comes a code
						if(s.length>1)
						{
							auto param = cast(int)s[1]; 
							switch(s[0]) {
								case '\33'	: color = param; 	break; 
								case '\34'	: bkColor = param; 	break; 
								case '\35'	: reversevideo = (param&1)!=0; underscore = (param&2)!=0; 	break; 
								case '\36'	: indentAdjust(param); 	break; 
								default: 
							}
							s = s[2..$]; 
						}else
						{
							s = s[1..$]; //bad code, do nothing
						}
					}
					flush; //it is needed
					
					if(chkSet(triggerFocusMainWindow) && afterFirstPrintFlushed) afterFirstPrintFlushed(); 
				} 
			} static public
			{
				/+
					Todo: Faster console IO
					/+
						Code: wchar_t PipeName[32];
						wsprintfW(PipeName, L"\\\\.\\pipe\\fastpipe%x", GetCurrentProcessId());
						HANDLE FastPipe = CreateFileW(PipeName, GENERIC_READ|GENERIC_WRITE, 0, 0, OPEN_EXISTING, 0, 0);
						if(FastPipe != INVALID_HANDLE_VALUE)
						{
							SetStdHandle(STD_OUTPUT_HANDLE, FastPipe);
							SetStdHandle(STD_INPUT_HANDLE, FastPipe);
						}
					+/
					/+Link: https://github.com/cmuratori/refterm/blob/main/fast_pipe.h+/
					/+Link: https://youtu.be/hxM8QmyZXtg?t=2988+/
					Molly Rocket, Remedybg
				+/
				
				//Todo: ha ezt a writeln-t hivja a gc.collect-bol egy destructor, akkor crash.
				
				//execute program in hetlib console({ program }); (colorful console, debug and exception handling)
				//args in application.args
				static void opCall(void delegate() dg) { application.runConsole(dg); } 
				static void opCall(void function() dg) { application.runConsole(dg.toDelegate); } 
				
				__gshared int indent = 0; 
				
				void delegate() afterFirstPrintFlushed; //MainWindow can regain it's focus
				
				void flush() { stdout.flush; } 
				
				void setUTF8() {
					const cp = 65001; 
					SetConsoleCP(cp); 
					SetConsoleOutputCP(cp); 
				} 
				
				void show()	 {
					if(chkSet	(visible_)	) ShowWindow (hwnd, SW_SHOW	); 
					/+Opt: Measure the speed of ShowWindow when it effectively does nothing!+/
				} 
				void hide(bool forced=false)	 {
					__gshared first=true; 
					if(chkClear	(visible_) || chkClear	(first) || forced) ShowWindow (hwnd, SW_HIDE	); 
				} 
				
				void setFocus()	 { SetFocus(hwnd); } //it's only keyboard focus
				void setForegroundWindow()	 { show; SetForegroundWindow(hwnd); 	} 
				bool isForeground()	 { return GetForegroundWindow == hwnd; } 	//this 3 funct is the same in Win class too.
				
				void setPos(int x, int y, int w, int h) { SetWindowPos(hwnd, null, x, y, w, h, SWP_NOACTIVATE | SWP_NOOWNERZORDER); } 
				
				@property bool visible()	 { return visible_; } 
				@property void visible(bool vis)	 { vis ? show : hide; } 
				
				@property bool exceptionHandlerActive() { return exceptionHandlerActive_; } 
				
				int handleException(void delegate() dg)
				{
					if(exceptionHandlerActive_) { dg(); }else {
						try
						{
							exceptionHandlerActive_ = true; 
							dg(); 
							exceptionHandlerActive_ = false; 
						}
						catch(Throwable e) {
							showException(e); 
							exceptionHandlerActive_ = false; 
							return -1; 
						}
					}
					return 0; 
				} 
				
				int consoleStrLength(string s)
				{
					int len; 
					bool expectParam; 
					foreach(ch; s)
					{
						if(chkClear(expectParam)) continue; 
						if(ch.inRange('\33', '\36')) { expectParam = true; continue; }
						len++; 
					}
					return len; 
				} 
				
				string leftJustify(string s, int size) { return s ~ " ".replicate(max(size-consoleStrLength(s), 0)); } 
				
				string rightJustify(string s, int size) { return " ".replicate(max(size-consoleStrLength(s), 0)) ~ s; } 
			} 
		} 
		
		void write(T...)(auto ref T args)
		{
			console.show; 
			foreach(const s; args)
			console.myWrite(to!string(s)); //calls own write with coloring
		} 
		
		void writeln	(T...)(auto ref T args)	 { write(args, '\n'	); 	} 
		void writef	(T...)(string fmt, auto ref T args)	 { write(format(fmt, args)	); 	} 
		void writefln	(T...)(string fmt, auto ref T args)	 { write(format(fmt, args), '\n'	); 	} 
		void writef	(string fmt, T...)(auto ref T args)	 { write(format!fmt(args)	); 	} 
		void writefln	(string fmt, T...)(auto ref T args) 	 { write(format!fmt(args), '\n'	); 	} 
		
		void print(T...)(auto ref T args) {
			 //like in python
			string[] s; 
			static foreach(a; args) { { s ~= text(a); }}
			writeln(s.filter!(s => s.length).join(' ')); 
		} 
		
		void safePrint(T...)(auto ref T args) {
			 //Todo: ez nem safe, mert a T...-tol is fugg.
			synchronized
				print(args); 
		} 
		
		private string aliasToString(alias a)()
		{ return fullyQualifiedName!a ~ " / " ~ a.stringof ~ " = " ~ a.text; } 
		
		void print(alias x, A...)(A args) { print(aliasToString!x, args); } 
		void print(alias x, alias y, A...)(A args) { print(aliasToString!x, aliasToString!y,  args); } 
		void print(alias x, alias y, alias z, A...)(A args) { print(aliasToString!x, aliasToString!y, aliasToString!z, args); } 
		
		//Todo: interpolated string support for print, write*, LOG, ERR, WARN
	}version(/+$DIDE_REGION+/all)
	{
		version(/+$DIDE_REGION UDAs+/all)
		{
			struct UDA
			{} 
			
			enum VerbFlag
			{ hold=1} 
			
			@UDA
			{
				//used by stream
				struct STORED
				{} 
				
				struct OPTIONAL
				{} 
				
				struct NAKED
				{} 
				
				struct VERB
				{ string keyCombo; int flags; } 
				auto HOLD(string keyCombo)
				{ return VERB(keyCombo, VerbFlag.hold); } 
							
				struct HEX
				{} 
				struct BASE64
				{} 
							
				//het.ui
				//struct UI{}    // similar to @Composable.  It alters the UI's state
				//Note: UI is ised for the default UI function. Conflicts with this UDA
							
				//het.opengl
				struct UNIFORM
				{ string name=""; } //marks a variable as gl.Shader attribute
							
				//het.ui
				struct CAPTION
				{ string text; } 
				struct HINT
				{ string text; } 
				struct UNIT
				{ string text; } 
				struct RANGE
				{
					float low, high; bool valid()const
					{ return !low.isnan && !high.isnan; } 
				} 
				struct STEP
				{ float s = 1; } 
				struct INDENT
				{} 
				struct HIDDEN
				{} 
			} 
			
			enum isStoredField(alias Field) = hasUDA2!(Field, STORED); 
			
			template StoredFields(alias Struct)
			{
				alias Fields = Struct.tupleof; 
				static if(allSatisfy!(templateNot!(isStoredField), Fields))
				alias StoredFields = Fields; 
				else
				alias StoredFields = Filter!(isStoredField, Fields); 
			} 
		}
		
		version(/+$DIDE_REGION DLLs+/all)
		{
			
			auto loadLibrary(string fn, bool mustLoad = true)
			{
				auto h = Runtime.loadLibrary(fn); 
				if(mustLoad)
				enforce(h, "("~fn~") "~getLastErrorStr); 
				return h; 
			} 
			
			auto loadLibrary(File fn, bool mustLoad = true)
			{ return loadLibrary(fn.fullName, mustLoad); } 
			
			void getProcAddress(T)(HMODULE hModule, string name, ref T func, bool mustSucceed = true)
			{
				func = cast(T)GetProcAddress(hModule, toStringz(name)); 
				if(mustSucceed)
				enforce(func, "getProcAddress() fail: "~name); 
			} 
			
			void getProcAddress(alias func)(HMODULE hModule, string name="", bool mustSucceed = true)
			{
				if(name=="") name = func.stringof; 
				getProcAddress(hModule, name, func); 
			} 
			
			void getProcAddress(T)(HMODULE hModule, size_t idx, ref T func, bool mustSucceed = true)
			{
				func = cast(T)GetProcAddress(hModule, cast(char*)idx); 
				if(mustSucceed)
				enforce(func, "getProcAddress() fail: idx("~idx.text~")"); 
			} 
			
			string genLoadLibraryFuncts(T, alias hMod = "hModule", alias prefix=T.stringof ~ "_")()
			{
				string res; 
				void append(string s)
				{ res ~= s ~ "\r\n"; } 
							
				import std.traits; 
				static foreach(f; __traits(allMembers, T))
				with(T)
				{
					mixin(
						q{
							static if(typeof($).stringof.startsWith("extern"))
							append(hMod~`.getProcAddress("`~prefix~`" ~ "$".withoutEnding('_'), $);`); 
						}.replace("$", f)
					); 
				}
							
				return res; 
			} 
			
		}
		
		version(/+$DIDE_REGION MSVC compatibility+/all)
		{
			//MSVC compatibility /////////////////////////
			
			//__iob_func - needed for turbojpeg
			//https://stackoverflow.com/questions/30412951/unresolved-external-symbol-imp-fprintf-and-imp-iob-func-sdl2
			extern (C)
			{
				import core.stdc.stdio : FILE; 
				shared FILE[3] __iob_func; 
			} 
			
			private void init__iob_func()
			{
				import core.stdc.stdio : stdin, stdout, stderr; 
				__iob_func = [*stdin, *stdout, *stderr]; 
			} 
			
			//240113: free() is removed. Now it is clearing it, and it's also safe to call on nulls.
			
			void SafeRelease(T:IUnknown)(ref T i)
			{
				if(i !is null)
				{
					i.Release; 
					i = null; 
				}
			} 
			
		}
		
		File[] hDropToFiles(HANDLE hDrop)
		{
			import core.sys.windows.windows: DragQueryFile; 
			//Link: https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-dragqueryfilea
			File[] res; 
			if(hDrop)
			{
				foreach(i; 0..DragQueryFile(hDrop, uint.max, null, 0))
				{
					if(auto cc = DragQueryFile(hDrop, i, null, 0))
					{
						cc++; //Needed to fit trailing zero.
						auto tmp = new wchar[cc]; 
						if(DragQueryFile(hDrop, i.to!uint, tmp.ptr, cc))
						{
							tmp.popBack; //Remove trailing zero
							res ~= File(tmp.text); 
						}
					}
				}
			}
			return res; 
		} 
		
		alias clipboard = Singleton!Clipboard; 
		
		class Clipboard	
		{
			import core.sys.windows.windows: 	OpenClipboard, CloseClipboard, IsClipboardFormatAvailable,
				EmptyClipboard, GetClipboardData, SetClipboardData, 
				HGLOBAL, GlobalLock, GlobalUnlock, GlobalAlloc, 
				GetClipboardSequenceNumber,
				
				CF_UNICODETEXT, /+Todo: Support CF_UNICODETEXT+/
				
				CF_BITMAP, HBITMAP,
				
				CF_HDROP; 
			
			bool hasFormat(uint fmt)
			{
				bool res; 
				if(OpenClipboard(null))
				{
					 scope(exit) CloseClipboard; 
					res = IsClipboardFormatAvailable(fmt)!=0; 
				}
				return res; 
			} 
			
			bool hasText()
			{ return hasFormat(CF_UNICODETEXT); } 
			
			string getText()
			{
				string res; 
				if(OpenClipboard(null))
				{
					scope(exit) CloseClipboard; 
					auto hData = GetClipboardData(CF_UNICODETEXT); 
					if(hData)
					{
						auto pData = cast(wchar*)GlobalLock(hData); 
						scope(exit) GlobalUnlock(hData); 
						res = pData.toStr; 
					}
				}
				return res; 
			} 
			
			bool hasHDrop()
			{ return hasFormat(CF_HDROP); } 
			
			File[] getHDrop()
			{
				File[] res; 
				if(OpenClipboard(null))
				{
					scope(exit) CloseClipboard; 
					auto hDrop = GetClipboardData(CF_HDROP); 
					return hDropToFiles(hDrop); 
				}
				return res; 
			} 
			
			bool setText(string btext, bool mustSucceed)
			{
				bool success; 
				if(OpenClipboard(null))
				{
					auto wtext = btext.to!wstring; 
					
					scope(exit) CloseClipboard; 
					EmptyClipboard; 
					HGLOBAL hClipboardData; 
					
					auto hData = GlobalAlloc(0, (wtext.length+1)*2); 
					auto pData = cast(wchar*)GlobalLock(hData); 
					pData[0..wtext.length] = wtext[]; 
					pData[wtext.length] = 0; 
					GlobalUnlock(hClipboardData); 
					success = SetClipboardData(CF_UNICODETEXT, hData) !is null; 
				}
				if(mustSucceed && !success)
				ERR("clipBoard.setText fail: "~getLastErrorStr); 
				return success; 
			} 
			
			bool hasBitmap()
			{ return hasFormat(CF_BITMAP); } 
			
			bool getBitmapHandle(void delegate(HBITMAP) onGetHandle)
			{
				if(hasBitmap)
				if(OpenClipboard(null/+clipboard is associated with the current task.+/))
				{
					scope(exit) CloseClipboard; 
					if(auto hbm = cast(HBITMAP)(GetClipboardData(CF_BITMAP)))
					{
						onGetHandle(hbm); 
						return true; 
					}
				}
				
				return false; 
			} 
			
			@property
			{
				string text()
				{ return getText; } 
				void text(string s)
				{ setText(s, true); } 
				
				File[] files()
				{ return getHDrop; } 
				File file()
				{ return files.frontOr(File.init); } 
				
				uint sequenceNumber()
				{ return GetClipboardSequenceNumber; } 
			} 
			
			mixin Signal; 
			
			void update()
			{
				static uint seq; 
				const isFirst = !seq; 
				if(seq.chkSet(sequenceNumber))
				if(!isFirst) emit; 
			} 
		} 
		
	}version(/+$DIDE_REGION+/all)
	{
		version(/+$DIDE_REGION SysInfo+/all)
		{
			//SysInfo////////////////////////////////////////////////
			
			string computerName()
			{
				wchar[256] a = void; 
				uint len = a.length; 
				if(GetComputerNameW(a.ptr, &len)) return toStr(a.ptr); 
				return ""; 
			} 
			
			string targetFeatures()
			{
				string res = format("Target CPU: %s", __traits(targetCPU)); 
				static foreach(f; ["sse", "sse2", "sse3", "ssse3", /*"sse4",*/ "sse4.1", "sse4.2"])
				static if(__traits(targetHasFeature, f)) res ~= " "~f; 
				return res; 
			} 
			
			import core.sys.windows.windef; 
			
			extern(C) {
				uint GetCurrentProcessorNumber(); 
				bool SetProcessAffinityMask(HANDLE process, DWORD_PTR mask); 
			} 
			
			public import std.parallelism: GetNumberOfCores = totalCPUs; 
			
			private auto GetCPULoadPercent_internal()
			{
				//get tick counters
				ulong idle, kernel, user; 
				auto ft(ref ulong a) { return cast(FILETIME*)(&a); } 
				if(!GetSystemTimes(ft(idle), ft(kernel), ft(user))) return float.nan; 
				
				//calculate  1 - (delta(Idle) / delta(kernel+user))
				__gshared static ulong prevTotal, prevIdle; 
				auto total = kernel+user; 
				auto res = 1 - float(idle-prevIdle) / (total-prevTotal); 
				//Bug: can divide by zero when called too frequently
				prevTotal	= total; 
				prevIdle	= idle; 
				
				return res*100; 
			} 
			
			auto GetCPULoadPercent()
			{
				__gshared static double lastTime = 0; //Todo: Use DateTime
				__gshared static float lastPercent = 0; 
				
				const interval = 0.33f; //seconds
				
				auto actTime = QPS.value(second); 
				if(actTime-lastTime > interval) {
					lastTime = actTime; 
					auto a = GetCPULoadPercent_internal; 
					if(!isnan(a)) lastPercent = a; 
				}
				
				return lastPercent; 
			} 
			
			
			auto GetMemUsagePercent()
			{
				MEMORYSTATUSEX ms; ms.dwLength = ms.sizeof; GlobalMemoryStatusEx(&ms); 
				with(ms) return ((1-(float(ullAvailPhys)/ullTotalPhys))*100).percent; 
			} 
			
			auto GetMemAvailMB()
			{
				MEMORYSTATUSEX ms; ms.dwLength = ms.sizeof; GlobalMemoryStatusEx(&ms); 
				return ms.ullAvailPhys>>20; 
			} 
			
		}
		
		/+
			Todo: process snapshots : 
				https://learn.microsoft.com/en-us/windows/win32/toolhelp
				/taking-a-snapshot-and-viewing-processes?redirectedfrom=MSDN
		+/
	}version(/+$DIDE_REGION+/all)
	{
		class SharedMem(SharedDataType, bool isServer_)
		{
			enum isServer = isServer_; 
			/+
				Todo: Creating a shared memory block that can grow in size
				SEC_RESERVE, VirtualAlloc  https://devblogs.microsoft.com/oldnewthing/20150130-00/?p=44793
				
				VirtualAlloc(pView, BLOCK_SIZE, MEM_COMMIT, PAGE_READWRITE);
				
				void ReportMemoryPresence(void *p)
				{
				 MEMORY_BASIC_INFORMATION mbi;
				 VirtualQuery(p, &mbi, sizeof(mbi));
				 printf("Memory at %p is %s\n", p,
					(mbi.State & MEM_COMMIT) ? "committed" : "not committed");
				}
			+/
			
			protected: 
			const string sharedFileName; 
			HANDLE sharedFileHandle; 
			SharedDataType* sharedData; 
			uint extraCreationFlags = 0; 
			
			void initialize()
			{
				if(isActive) return; 
				
				import core.sys.windows.windows; 
				sharedFileHandle = 
				((isServer)?(
					CreateFileMappingW
					(
						INVALID_HANDLE_VALUE,	//use paging file
						null,	//default security
						PAGE_READWRITE | extraCreationFlags,	//read/write access
						0,	//maximum object size (high)
						SharedDataType.sizeof.to!uint,	//maximum object size (low)
						sharedFileName.toPWChar	//name of mapping object
					)
				) :(
					OpenFileMappingW
					(
						FILE_MAP_ALL_ACCESS,	//read/write access
						false,	//do not inherit the name
						sharedFileName.toPWChar	//name of mapping object
					)
				)); 
				sharedData = 
				(cast(SharedDataType*)(
					MapViewOfFile(
						sharedFileHandle,	//handle to map object
						FILE_MAP_ALL_ACCESS,	//read/write permission
						0,
						0,
						SharedDataType.sizeof
					)
				)); 
			} 
			
			public: 
			SharedDataType* data() { return sharedData; } 
			@property isActive() { return sharedData !is null; } 
			
			this(string sharedFileName, Flag!"reserve" reserve = No.reserve)
			{
				this.sharedFileName = sharedFileName; 
				if(reserve) extraCreationFlags |= SEC_RESERVE; 
				initialize; 
			} 
		} 
		
		alias SharedMemServer(SharedDataType) = SharedMem!(SharedDataType, true); 
		alias SharedMemClient(SharedDataType) = SharedMem!(SharedDataType, false); 
		
		
		////////////////////////////////////////////////////////////////////////////////////
		/// Ini/Registry                                                                 ///
		////////////////////////////////////////////////////////////////////////////////////
		
		struct ini
		{
			private: 
				static const useRegistry = true; 
				static File iniFile()
			{ auto fn = appFile; fn.ext = ".ini"; return fn; } 
			
				static string[string] map; 
			
				static Key baseKey()
			{ return Registry.currentUser.getKey("Software"); } 
				static string companyName()
			{ return "realhet"; } 
				static string configName()
			{ return "Config:"~appFile.fullName; } 
			
				static string loadRegStr()
			{
				string s; 
				if(useRegistry)
				{
					try
					{ s = baseKey.getKey(companyName).getValue(configName).value_SZ; }
					catch(Exception) {}
				}
				else
				{ s = iniFile.readStr(false); }
				return s; 
			} 
			
				static void loadMap()
			{ map = strToMap(loadRegStr); } 
			
				static void saveMap()
			{
				bool empty = map.length==0; 
				if(empty && !loadRegStr) return; 
						
				if(useRegistry)
				{
					auto key = baseKey.createKey(companyName); 
					if(empty)
					{
						key.deleteValue(configName); key.flush; 
						if(!key.valueCount) baseKey.deleteKey(companyName); 
					}
					else
					{
						auto s = mapToStr(map); 
						key.setValue(configName, s); key.flush; 
					}
				}
				else
				{
					auto s = mapToStr(map); 
					if(empty) iniFile.remove; 
					else iniFile.write(s); 
				}
			} 
			public: 
				static void loadIni()
			{ loadMap; } 
				static void saveIni()
			{ saveMap; } 
			
				static void remove(string name)
			{ map.remove(name); } 
				static void removeAll()
			{ map =	null; } 
			
				static void write(T)(string name, in T value)
			{ map[name] = value.to!string; } 
			
				static T read(T)(string name, in T def = T.init)
			{
				if(auto x = name in map) try { return (*x).to!T; }catch(Throwable) {}
				return def; 
			} 
		} 
	}
}version(/+$DIDE_REGION Error hnd.+/all)
{
	version(/+$DIDE_REGION+/all) {
		enum ErrorHandling { ignore, warn, raise, track} 
		
		alias enforce = stdEnforce/+Todo: should work with interpolated strings!!!+/; 
		
		///this version compares 2 values and shows the difference too
		void enforceDiff(T)(in T expected, in T actual, lazy string caption="", string file = __FILE__, int line = __LINE__)
		{
			if(expected == actual) return; 
					
			auto	exp	= expected.text,
				act	= actual.text,
				diff	= strDiff(exp, act),
				capt	= caption=="" ? "Test failed:" : caption; 
			enforce(0, format!"%s\n  Exp : %s\n  Act : %s\n  Diff: %s"(capt, exp, act, diff), file, line); 
		} 
		
		template CustomEnforce(string prefix)
		{
			T enforce(T)(
				T value, lazy string str="", string file = __FILE__, int line = __LINE__, string fn=__FUNCTION__
								/+__PRETTY_FUNCTION__ <- is too verbose+/
			)
			{
				if(!value) stdEnforce(0, "["~fn~"()] "~prefix~" "~str, file, line); 
				return value; 
			} 
		} 
		
		void raise(string file = __FILE__, int line = __LINE__, T...)(T str)
		{
			enforce(0, str.text, file, line); 
			
			//Todo: use noreturn and/or learn about abort.
			//Link: https://dlang.org/spec/type.html#noreturn
		} 
		
		bool ignoreExceptions(void delegate() f) {
			bool res; 
			try { f(); }catch(Exception) { res = true; }
			return res; 
		} 
		bool warnExceptions(void delegate() f) {
			bool res; 
			try { f(); }catch(Exception e) { WARN(e.simpleMsg); res = true; }
			return res; 
		} 
		
		/// Plays a wav file in the windows media folder
		void winSnd(string name)
		{
			import core.sys.windows.mmsystem; 
			PlaySound(name.format!`c:\Windows\media\%s.wav`.toPWChar, null, SND_FILENAME | SND_ASYNC); 
		} 
		
		void beep(int MBType = MB_OK)
		{
			version(/+$DIDE_REGION+/none) {
				pragma(lib, "Winmm"); import core.sys.windopws.mmsystem; 
				PlaySound(`c:\Windows\media\tada.wav`, NULL, SND_FILENAME | SND_ASYNC); 
			}
			
			MessageBeep(MBType); 
		} 
		
		string extendedMsg(string lines)
		{
			
			/+
				examples:
					Exception: ACCESS_VIOLATION at 7FF793EC1A1E info: 0, 0
					----------------
					0x00007FF793EC1A1E in onPaint at c:\d\testcleartypemultisampling.d(83)
				
				
			+/
			
			static string processLine(string line)
			{
				if(line.isWild("0x????????????????"))
				{
					auto addr = cast(void*) line[2..$].to!ulong(16); 
					
					auto mi = getModuleInfoByAddr(addr, true); 
					line ~= " " ~ mi.location; 
					
					if(line.isWild(`*"*.d", *`))
					{
						 //search src line locations in the parameters
						auto fn = wild[1]~".d"; 
						int srcLine; 
						try { auto tmp = wild[2]; srcLine = parse!int(tmp); }catch(Throwable) {}
						if(srcLine>0 && File(fn).exists)
						line = format!"%s(%s,1): Exception: %s"(fn, srcLine, line); 
					}
					return line; 
				}
				if(line.isWild("*@*.d(*): *"))
				{
					//exception
					return format!"%s.d(%s,1): Exception: %s: %s"(wild[1], wild[2], wild[0], wild[3]); 
				}
				return line; 
			} 
			
			return lines.splitLines.map!processLine.cache.filter!(not!empty).join("\n"); 
		} 
		
		string extendedMsg(Throwable t) { return t.msg.extendedMsg; } 
		
		//cuts off traqce info
		string simpleMsg(string exceptionMsg)
		{
			string[] s; 
			foreach(line; exceptionMsg.split("\n").map!strip)
			{
					//Todo: use countUntil here!
				if(line == "") break; 
				s ~= line; 
			}
			return s.join("\n"); 
		} 
		
		string simpleMsg(Throwable t) { return t.msg.simpleMsg; } 
		
		void showException(string msg) nothrow
		{
			try {
				string err = msg.extendedMsg; 
				/+
					example msg:
					Error: OS Exception: ACCESS_VIOLATION at 7FF7D0AE1A1E info: 0, 0
					----------------
					0x00007FF7D0AE1A1E in onPaint at c:\d\testapp.d(83)
					...
				+/
				if(dbg.isActive)
				{ dbg.handleException(err); }else
				{
					import core.sys.windows.windows; 
					MessageBeep(MB_ICONERROR); //idegesit :D
					writeln("\33\14"~err~"\33\7"); 
					writeln("Press Enter to continue..."); 
					console.setForegroundWindow; 
					readln; 
					application.exit; 
				}
			}catch(Throwable o) {}
		} 
		
		void showException(Throwable o) nothrow
		{
			string s; 
			try { s = o.toString(); }catch(Throwable o) { s = "Unable to get exception.toString"; }
			showException(s); 
		} 
		
		void forceAssertions(string file=__FILE__, int line=__LINE__)()
		{
				//Todo: this crap drops an ILLEGAL INSTRUCTION exception. At least it works...
			enforce(ignoreExceptions({ assert(false); } ), "Enable DEBUG compiler output! %s(%s)".format(file, line)); 
		} 
		
	}version(/+$DIDE_REGION+/all) {
		
		pragma(lib, "Psapi.lib"); 
		
		class ExeMapFile
		{
			ulong baseAddr; 
			
			struct Rec {
				string mangledName; 
				ulong addr; 
				string objName; 
				
				string name() {
					import std.demangle; 
					return demangle(mangledName); 
				} 
			} 
			
			Rec[] list; 
			
			this(File f = File.init)
			{
				if(!f) f = appFile.otherExt("map"); 
				
				bool active=false; 
				foreach(line; f.readLines(false))
				{
					LOG(line); 
					
					if(!active) active = line.isWild("*Address*Publics by Value*Rva+Base*Lib:Object"); 
					auto p = line.split.array; 
					switch(p.length) {
						case 5: { if(p[0]=="Preferred") { baseAddr = p[4].to!ulong(16); }}break; 
						case 4: {
							if(active && p[0].isWild("0001:*"))
							{
								//LDC1.28+
								list ~= Rec(p[1], p[2].to!ulong(16) - baseAddr, p[3]); 
							}
						}break; 
						default: 
					}
				}
				
				list = list.sort!"a.addr < b.addr".array; //not sure if already sorted
				
				if(list.empty) ERR("EXEMAPFILE is fucked up."); 
			} 
			
			string locate(ulong relAddr)
			{
				//Todo: Try core.runtime.defaultTraceHandler
				
				foreach(idx; 1..list.length)
				if(list[idx-1].addr <= relAddr && list[idx].addr > relAddr)
				return list[idx-1].name; 
				return ""; 
			} 
		} 
		
		alias exeMapFile = Singleton!ExeMapFile; 
		
		auto exceptionCodeToStr(uint code)
		{
			import core.sys.windows.windows; 
			enum names = [
				"ACCESS_VIOLATION"	, "DATATYPE_MISALIGNMENT"	, "BREAKPOINT"	,
				"SINGLE_STEP"	, "ARRAY_BOUNDS_EXCEEDED"	,"FLT_DENORMAL_OPERAND"	,
				"FLT_DIVIDE_BY_ZERO"	, "FLT_INEXACT_RESULT"	, "FLT_INVALID_OPERATION"	,
				"FLT_OVERFLOW"	, "FLT_STACK_CHECK"	, "FLT_UNDERFLOW"	,
				"INT_DIVIDE_BY_ZERO"	, "INT_OVERFLOW"	, "PRIV_INSTRUCTION"	,
				"IN_PAGE_ERROR"	, "ILLEGAL_INSTRUCTION"	, "NONCONTINUABLE_EXCEPTION"	,
				"STACK_OVERFLOW"	, "INVALID_DISPOSITION"	, "GUARD_PAGE"	, 
				"INVALID_HANDLE"
			]; 
			
			switch(code) {
				static foreach(s ;names)
				mixin(q{case EXCEPTION_*: return "*"; }.replace('*', s)); 
				
				default: return format!"%X"(code); 
			}
		} 
		
		auto getModuleInfoByAddr(void* addr_, bool locateInMapFile=false)
		{
			struct Res {
				HMODULE handle; 
				File fileName; 
				void* addr, base; 
				size_t size; 
				string location; 
				uint offset() const
				{ return (addr-base).to!uint.ifThrown(uint.max); } 
			} 
			Res res; 
			
			with(res)
			{
				import core.sys.windows.windows; 
				addr = addr_; 
				if(
					GetModuleHandleEx(
						GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
						GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, 
						cast(wchar*)addr, &handle
					)
				)
				{
					
					wchar[256] tmp; 
					if(GetModuleFileNameW(handle, tmp.ptr, 256))
					fileName = File(tmp.toStr); 
					
					import core.sys.windows.psapi; 
					MODULEINFO mi; 
					if(GetModuleInformation(GetCurrentProcess, handle, &mi, mi.sizeof))
					{
						base = mi.lpBaseOfDll; 
						size = mi.SizeOfImage; 
						
						if(location.empty)
						location = fileName.fullName.quoted; 
						
						enum enableExeMapFile = false; 
						/+
							Bug: memory error can happen here, 
							when the exe map file is loaded.
							splitLines() needs a lot of dynamic allocations.
							
							Now I disable it.  In the IDE it seems ok...
						+/
						
						if(locateInMapFile && enableExeMapFile)
						{
							if(fileName==appFile)
							{ res.location = exeMapFile.locate(addr-base); }
						}
					}
				}
				
			}
			
			return res; 
		} 
		
		private __gshared int gDisableOSExceptionsCouinter; 
		
		void convertOSExceptionsToNormalExceptions(void delegate() fun)
		{
			gDisableOSExceptionsCouinter++; 
			scope(exit) gDisableOSExceptionsCouinter--; 
			if(fun) fun(); 
		} 
		
		version(/+$DIDE_REGION Windows PID queryes+/all)
		{
			@property bool PIDIsRunning(int pid)
			{
				import core.sys.windows.windows; 
				if(auto hProcess = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, dbgsrv.exe_pid))
				{ CloseHandle(hProcess); return true; }
				return false; 
			} 
			
			@property File PIDModuleFile(int pid)
			{
				import core.sys.windows.windows, core.sys.windows.psapi; 
				if(auto hProcess = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, dbgsrv.exe_pid))
				{
					scope(exit) CloseHandle(hProcess); 
					wchar[MAX_PATH] fn; 
					auto len = fn.length.to!uint; 
					if(GetModuleFileNameExW(hProcess, null, fn.ptr, len))
					{ return fn.toStr.File; }
				}
				return File.init; 
			} 
			
			@property bool PIDModuleFileIsRunning(int pid, File e)
			{ return e && sameText(PIDModuleFile(pid).fullName, e.fullName); } 
		}
	}version(/+$DIDE_REGION+/all) {
			
		void installExceptionFilter()
		{
			__gshared static installed = false; 
			if(!chkSet(installed)) return; 
			
			import core.sys.windows.windows; 
			
			static extern(Windows) LONG customExceptionFilter(EXCEPTION_POINTERS* p)
			{
				if(gDisableOSExceptionsCouinter)
				{
					throw new Exception("OS Exception Ignored: "~(*p).ExceptionRecord.text); 
					//Todo: Decode the message properly.
					//Todo: lehet hogy kellene egyb sajat OSExceptiont csinalnom es nem tovabbengedni a Winapi Exception Filteren
					//return EXCEPTION_CONTINUE_EXECUTION;
				}
				
				string msg; 
				with(p.ExceptionRecord)
				{
					auto mi = getModuleInfoByAddr(ExceptionAddress, true); 
					
					string excInfo; 
					if(NumberParameters) excInfo = "info: " ~ ExceptionInformation[0..NumberParameters].map!(a => a.format!"%X").join(", "); 
					
					//print("\n\33\14OS Exception:\33\17", exceptionCodeToStr(ExceptionCode), "\33\7at", ExceptionAddress, excInfo);
					msg = format!"Exception: %s at %s %s"(exceptionCodeToStr(ExceptionCode), ExceptionAddress, excInfo); 
					//examplem msg: Exception: ACCESS_VIOLATION at 7FF7A62B1A1E info: 0, 0
					
					//if(mi.handle){
						//print("module:", mi.fileName.fullName.quoted, "base:", mi.base, "rel_addr:\33\17", format("%X",ExceptionAddress-mi.base), mi.location, "\33\7");
						//msg ~= "\n" ~ mi.location;  //not needed, already in stack trace
					//}
				}
						
				if(1) {
					 //stacktrace
					import core.sys.windows.stacktrace; 
					auto st = new StackTrace(0/*skip frames*/, p.ContextRecord); 
					msg ~= "\n----------------\n"~st.text; 
					
					version(/+$DIDE_REGION+/none)
					{
						foreach(s; st.text.splitLines)
						{
							write(s, " "); 
							
							if(s.isWild("0x????????????????"))
							{
								auto addr = cast(void*) s[2..$].to!ulong(16); 
								write(addr, " \33\13"); 
								auto mi = getModuleInfoByAddr(addr, true); 
								if(mi.handle) {
									auto relAddr = cast(ulong) (addr-mi.base); 
									write(mi.fileName.name, ":", relAddr.format!"%X"); 
									
									write(" ", mi.location); 
								}
							}
							
							writeln("\33\7"); 
						}
					}
					
					//print(st);
				}
						
				//if(0) print((*(p.ContextRecord)).toJson);
						
				//Todo: Break point handling
				//Decide what to do. On BREAKPOINT it is possible to continue.
				/*
					if(p.ExceptionRecord.ExceptionCode == EXCEPTION_BREAKPOINT){
										console.setForegroundWindow;
										write("Continue (y/n) ? ");
										auto s = readln;
										if(s.lc.strip == "y"){
											if(mainWindow) mainWindow.setForegroundWindow;
							
											p.ContextRecord.Rip ++; //advance IP
											return EXCEPTION_CONTINUE_EXECUTION;
										}
									}else{
										write("Press enter to exit..."); readln;
									}
				*/
						
				static if(1)
				{
					//1 = disable exception handling
					showException(msg); 
					
					return 
						EXCEPTION_EXECUTE_HANDLER;    //exits because D runtime has no registered handler
						//EXCEPTION_CONTINUE_SEARCH;	//exits, unhandled by this filter.
						//EXCEPTION_CONTINUE_EXECUTION;	//continues, but it becomes an endless as it retriggers an exception on the same error
				}
				else
				{
					//showException(msg);
					//WARN(msg);
					return EXCEPTION_CONTINUE_EXECUTION; 
				}
			} 
					
			auto res = SetUnhandledExceptionFilter(&customExceptionFilter); 
			//LOG("Exception filter installed: ", res);
					
					
		} version(/+$DIDE_REGION+/all) {
			version(/+$DIDE_REGION Windows errors+/all)
			{
				//Windows error handling //////////////////////////////
				
				string getLastErrorStr() {
					auto e = GetLastError; 
					if(!e) return ""; //no error
					char[512] error; 
					FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, null, e, 0, error.ptr, error.length, null ); 
					return toStr(&error[0]); 
				} 
				
				alias raiseLastError = throwLastError; 
				void throwLastError(string file = __FILE__, int line = __LINE__) {
					auto error = getLastErrorStr; 
					enforce(error=="", "LastError: "~error, file, line); 
				} 
				
				void hrChk(HRESULT res, lazy string str = "", string file = __FILE__, int line = __LINE__)
				{
					if(res==0) return; 
					
					auto h = res.predSwitch(
						0x80004001, 	"E_NOTIMPL"	,
						0x80004002,	"E_NOINTERFACE"	,
						0x80004003,	"E_POINTER"	,
						0x80004004,	"E_ABORT"	,
						0x80004005,	"E_FAIL"	,
						0x8000FFFF,	"E_UNEXPECTED"	,
						0x80070005,	"E_ACCESSDENIED"	,
						0x80070006,	"E_HANDLE"	,
						0x8007000E,	"E_OUTOFMEMORY"	,
						0x80070057,	"E_INVALIDARG"	,
							format!"%X"(res)
					); 
					
					enforce(false, "HRESULT=%s %s".format(h, str), file, line); 
				} 
				
			}
			
			void selftest(T)(lazy const T a, uint xb, string name, string notes="", string file=__FILE__, int line=__LINE__)
			{
				version(disableselftest)
				return; 
				else {
					import het.inputs; 
					
					
					shared static bool skip; if(inputs["Shift"].active) skip = true; 
					//Todo: selftest skippelesen gondolkozni... A problema, hogy csak akkor kezelheto belul, ha a selftest lazy parametereben tortenik minden.
					
					if(!notes.empty) notes = "\33\10 "~notes~"\33\7"; 
					const sHoldShift = "Hold SHIFT to skip..."; 
					write("SELFTEST [\33\17"~name~"\33\7"~notes~"]: \33\10"~sHoldShift~"\33\7"); console.flush; 
					void clearBack() { write("\b \b".map!(a => [a].replicate(sHoldShift.length)).join); } 
									
					if(skip) {
						clearBack; 
						writeln("\33\10SKIPPED\33\7"); 
						return; 
					}
					
					auto xa = a.xxh; //this could take long time
					
					clearBack; 
					
					if(xa==xb)
					writeln("\33\x0AOK\33\x07"); 
					else
					{
						writefln("\33\x0CFAILED\33\x07 (%d!=%d)", xa, xb); 
						auto e = new Exception(format("Error: selftest [%s] failed (%d!=%d)", name, xa, xb), file, line); 
						console.handleException({ throw e; } ); 
						application.exit; //Todo: this is a fatal exception, should the IDE know about this also...
					}
				}
			} 
		}
	}
}version(/+$DIDE_REGION Meta programming       +/all)
{
	
	void free(O)(ref O o)
	if(is(O == class))
	{ if(o) { o.destroy; o = null; }} 
	
	static T Singleton(T)() if(is(T == class))
	{
		//Singleton ////////////////////////
		import std.traits : SharedOf; 
		enum isShared = is(SharedOf!T == T); 
		enum log = false; 
				
		static if(isShared)
		{
			static T instance; //Todo: initOnce does this locking too.
			static bool initialized; 
			if(!initialized) {
				synchronized {
					if(instance is null) {
						instance = new T; 
						if(log) LOG(`created.`); 
					}
				} 
				initialized = true; 
			}
		}
		else
		{
			__gshared static T instance; 
			if(instance is null) {
				instance = new T; 
				if(log) LOG(`created.`); 
			}
		}
				
		return instance; 
	} 
	
	//structs to text /////////////////////////////////////
	
	string toString2(T)(in T obj)
	if(isAggregateType!T)
	{
		string[] parts; 
		alias types = FieldTypeTuple!T; 
		foreach(idx, name; FieldNameTuple!T) {
			string value = mixin("obj."~name~".text;"); 
			if(isSomeString!(types[idx])) value = value.quoted; 
			parts ~= format!"%s : %s"(name, value); 
		}
		return format!"%s(%s)"(T.stringof, parts.join(", ")); 
	} 
	
	void clearFields_init(T)(T obj)
	if(isAggregateType!T)
	{ foreach(f; FieldNameTuple!T) mixin("obj.$ = T.$.init;".replace("$", f)); } 
	
	//Note: at stream, there is a clearFields_default version
	//Todo: bad naming:  initFields and initStoredField would be better.
	
	//Meta helpers ///////////////////////////
	
	auto getSymbolNamesByUDA(T, string uda)()
	{
		string[] res; 
		static foreach(a; getSymbolsByUDA!(T, uda)) res ~= a.stringof; 
		return res; 
	} 
	
	
	enum SameType(A, B) = is(Unqual!A == Unqual!B); 
	
	///This is copied from Phobos.
	private template isDesiredUDA(alias attribute)
	{
		template isDesiredUDA(alias toCheck)
		{
			static if(is(typeof(attribute)) && !__traits(isTemplate, attribute))
			{
				static if(__traits(compiles, toCheck == attribute))
				enum isDesiredUDA = toCheck == attribute; 
				else
				enum isDesiredUDA = false; 
			}
			else static if(is(typeof(toCheck)))
			{
				static if(__traits(isTemplate, attribute))
				enum isDesiredUDA =  isInstanceOf!(attribute, typeof(toCheck)); 
				else
				enum isDesiredUDA = is(typeof(toCheck) == attribute); 
			}
			else static if(__traits(isTemplate, attribute))
			enum isDesiredUDA = isInstanceOf!(attribute, toCheck); 
			else
			enum isDesiredUDA = is(toCheck == attribute); 
		} 
	} 
	
	///returns the first overload of the symbol if it has any.  Otherwise returns the symbol itself.
	template getFirstOverload(alias Sym)
	{
		static if(
			/+
				__traits(compiles, __traits(parent, Sym))
				&& !__traits(isSame, Sym, __traits(parent, Sym)) /+this trick is from fullyQualifiedName+/
				/+Note: these tests are not necessary+/
			+/ 
			/+
				__traits(compiles,  __traits(getOverloads, __traits(parent, Sym), __traits(identifier, Sym)))
				&&        typeof(__traits(getOverloads, __traits(parent, Sym), __traits(identifier, Sym))).length > 0
				/+Note: no need for these either...+/
			+/
			__traits(compiles,   __traits(getOverloads, __traits(parent, Sym), __traits(identifier, Sym), true)[0])
		)
		{ alias getFirstOverload = __traits(getOverloads, __traits(parent, Sym), __traits(identifier, Sym), true)[0]; }
		else
		{ alias getFirstOverload = Sym; }
	} 
	
	template getAttributesOfFirstOverload(alias Sym)
	{ alias getAttributesOfFirstOverload = __traits(getAttributes, getFirstOverload!Sym); } 
	
	///This version checks only the first overloads.  Avoids the Deprecation hint.
	template hasUDA2(alias S, U)
	{ enum hasUDA2 = Filter!(isDesiredUDA!U, getAttributesOfFirstOverload!S).length != 0; } 
	
	
	
	///Returns only the last UDA if more than one exists.
	template getUDA(alias S, U, U def = U.init)
	{
		//Todo: handle overloads
		static if(hasUDA!(S, U))	alias getUDA = getUDAs!(S, U)[$-1]; 
		else	alias getUDA = def; 
	} 
	
	
	///helper templates to get all the inherited class fields, works for structs as well
	template AllClasses(T)
	{
		static if(is(T == Object))	alias AllClasses = AliasSeq!(); 
		else static if(is(T == class ))	alias AllClasses = Reverse!(AliasSeq!(T, BaseClassesTuple!T[0..$-1])); 
		else	alias AllClasses = T; 
	} 
	
	/// returns the member names of only this child class only, not the ancestor classes.
	/// Analogous to FieldNameTuple template
	/// Works for structs too
	template ThisClassMemberNameTuple(T)
	{
		static if(is(T == class) && !is(T == Object))
		{
			//Todo: this can be allmembers
			alias AM = __traits(allMembers, T); 
			alias BM = __traits(allMembers, BaseClassesTuple!T[0]); 
			enum ThisClassMemberNameTuple = AM[0..AM.length-BM.length]; 
		}
		else static if(is(T == struct))
		{ enum ThisClassMemberNameTuple = __traits(allMembers, T); }
		else
		{ enum ThisClassMemberNameTuple = AliasSeq!(); }
	} 
	
	alias AllFieldNames(T) = staticMap!(FieldNameTuple, AllClasses!T); //good order, but no member properties
	alias AllMemberNames(T) = __traits(allMembers, T); //wrong backward inheritance order.
	
	/// used by stream. This is the old version, without properties. Fields are in correct order.
	template FieldNamesWithUDA(T, U, bool allIfNone)
	{
		enum fields = AllFieldNames!T; 
		enum bool hasThisUDA(string fieldName) = hasUDA2!(__traits(getMember, T, fieldName), U); 
		
		static if(allIfNone && !anySatisfy!(hasThisUDA, fields))
		enum FieldNamesWithUDA = fields; 
		else
		enum FieldNamesWithUDA = Filter!(hasThisUDA, fields); 
	} 
	
	/// The new version with properties. Sort order: fields followed by functions
	template FieldAndFunctionNamesWithUDA(T, U, bool allIfNone)
	{
		enum bool isUda       (string name) = (is(U==void) || hasUDA2!(__traits(getMember, T, name), U)); 
		
		static if(allIfNone && !anySatisfy!(isUda, AllMemberNames!T))
		{ enum FieldAndFunctionNamesWithUDA = AllFieldNames!T; /+only fields, not properties+/}
		else
		{
			enum bool isUdaFunction(string name) = isUda!name && isFunction!(__traits(getMember, T, name)); 
			enum UdaFieldAndFunctionNameTuple(T) = 	AliasSeq!(
				Filter!(isUda, FieldNameTuple!T), 
				Filter!(isUdaFunction, ThisClassMemberNameTuple!T)
			); 
			enum FieldAndFunctionNamesWithUDA = staticMap!(UdaFieldAndFunctionNameTuple, AllClasses!T); 
		}
		
		static if((常!(bool)(0))) {
			enum hdr = i"$(__FILE__)($(__LINE__+1),1): ".text; 
			pragma(
				msg, hdr, "Warning: ", fullyQualifiedName!T, 
					[FieldAndFunctionNamesWithUDA].map!((a)=>("\n"~hdr~"          	• "~a)).join
			); 
		}
	} 
	
	enum FieldAndFunctionNames(T) = FieldAndFunctionNamesWithUDA!(T, void, false); 
	
	static if(0)
	deprecated(`use EnumMemberNames`) string[] getEnumMembers(T)()
	{
		static if(is(T == enum)) return [__traits(allMembers, T)]; 
		else return []; 
	} 
	
	
	enum EnumMemberNames(T) = is(T==enum) ? [__traits(allMembers, T)] : []; 
	
	
	alias toAlias(alias T) = T; //Todo: Alias!T alreadyb exists
	
	void inspectSymbol(alias T)(string before="", int level=0)
	{
		enum maxInspectLevel = 10; 
		
		//step 2
		foreach(memberName; __traits(allMembers, T))
		static if(__traits(compiles, toAlias!(__traits(getMember, T, memberName))))
		{
			//step 3
			alias member = toAlias!(__traits(getMember, T, memberName));  //sometimes this alias declaration fails.
			//step 4 - inspecting types
			static if(is(member))
			{
				string specifically; 
				static if(is(member == struct))
				specifically = "struct"; 
				else static if(is(member == class))
				specifically = "class"; 
				else static if(is(member == enum))
				specifically = "enum"; 
				writeln(before, fullyQualifiedName!member, " is a type (", specifically, ")"); 
				//drill down (step 1 again)
				static if(is(member == struct) || is(member == class) || is(member == enum))
				{
					static if(!is(T) || !is(member == T))
					{
						 //ignore types that contain an alias for typeof(this)
						if(level<maxInspectLevel) {
							 //limit recursion
							inspectSymbol!member(before ~ "\t", level+1); 
						}
					}
				}
				else
				{ writeln(before ~"\t", fullyQualifiedName!member, " : ", member.stringof); }
			}
			else static if(is(typeof(member) == function))
			{
				//step 5, inspecting functions
				writeln(before, fullyQualifiedName!member, " is a function typed ", typeof(member).stringof); 
			}
			else
			{
				//step 6, everything else
				
				static if(__traits(compiles, member.stringof)) enum s = member.stringof; else enum s = ""; 
				
				static if(s.startsWith("module "))
				writeln(before, fullyQualifiedName!member, " is a module"); 
				else static if(s.startsWith("package "))
				writeln(before, fullyQualifiedName!member, " is a package"); 
				else static if(is(typeof(member.init)))
				{
					static if(__traits(compiles, member.stringof))
					{
						static if(member.stringof.endsWith(')'))
						{ writeln(before, fullyQualifiedName!member, " is a property typed ", typeof(member).stringof); }
						else
						{ writeln(before, fullyQualifiedName!member, " is a non-property typed ", typeof(member).stringof); }
					}
					else
					{ writeln(before, fullyQualifiedName!member, " is a member, but unable access its .stringof ", memberName); }
				}
				else
				{
					string fn = memberName; 
					static if(__traits(compiles, fullyQualifiedName!member)) fn = fullyQualifiedName!member; 
					writeln(before, fn, " is template ", s); 
				}
			}
		}
		else
		{
			print(
				"!!!!!!!!!!!!!!!!!!!!!!! unable to compile toAlias!(__traits(getMember, T, memberName) on symbol:", 
				T.stringof ~ "." ~ memberName
			); 
		}
	} 
		
	auto arraySwitch(alias sourceRange, alias targetRangeOrFunction, T = ElementType!(typeof(sourceRange)))(in T input)
	{
		static if(isInputRange!(typeof(targetRangeOrFunction))) alias targetRange = targetRangeOrFunction; 
		else alias targetRange = sourceRange.map!targetRangeOrFunction; 
		
		switch(input) {
			
			static foreach(a; zip(StoppingPolicy.requireSameLength, sourceRange, targetRange))
			case a[0]: return a[1]; 
			
			//Todo: DIDE: the parser stops at case a[0]: and doesn't include return a[1]; inside this foreach
			
			default: 
				throw new Exception(__FUNCTION__~": Invalid input value: "~input); 
		}
	} 
	
	auto functionSwitch(alias fun, E)(E e)
	/+Todo: bad naming.+/
	/+Todo: DIDE jopinpreposition bug above+/
	{
		final switch(e)
		static foreach(a; EnumMembers!E)
		case a: return a.unaryFun!fun; 
	} 
	
	
	//StaticParam ////////////////////
	
	auto getStaticParamDef(T, Args...)(in T def, in Args args)
	{
		Unqual!T res = def; 
		static foreach(a; args) static if(__traits(compiles, res = a)) return a; 
		return res; 
	} 
	
	auto getStaticParam(T, Args...)(in Args args)
	{
		Unqual!T res; 
		static foreach(a; args) static if(__traits(compiles, res = a)) return a; 
		static assert(0, "Can't find required param: "~T.stringof); 
	} 
	
	enum hasStaticParam(T, Args...) = staticIndexOf!(Unqual!T, staticMap!(Unqual, Args))>0; 
	
	//GenericArg /////////////////////////////////////
	
	//Todo: rename to NamedParameter
	
	//overloadable arguments. args!(fun, param1 => x, param2 => y)   fun must be a struct, not a function. It's not what I want.
	//Link: https://github.com/CyberShadow/ae/blob/master/utils/meta/args.d
	
	//They never made it:
	//Link: https://wiki.dlang.org/DIP88
	
	
	//GenericArg moved into math.
	
	
	string processGenericArgs(string code)
	{
		//generates a static foreach. "code" is a static if chain evaluating N (name) and T (type). Inputs: args:
		return "static foreach(a; args){{ static if(isGenericArg!(typeof(a))){ enum N = a.name; alias T = a.type; }else{ enum N = ``; alias T = typeof(a); } "~code~" }}"; 
	} 
	
	string appendGenericIds(string idVariable)
	{ return processGenericArgs(`static if(N=="id") `~idVariable~`.appendIdx(a.value);`); } 
	
	
	auto genericId(T)(in T a)
	{
		static if(is(T==class))
		return genericArg!"id"(a.identityStr); 
		else
		return genericArg!"id"(a); 
	} 
	
	//SrcId ////////////////////////////////////////////////////////////
	
	enum srcLocationStr(string srcModule, size_t srcLine) = srcModule ~ `.d(` ~ srcLine.text ~ ')'; 
	
	struct SrcId
	{
		/// select Id datatype. Default=string if debug, long if release
		version(stringId	) alias T = string	; 
		else version(longId	) alias T = ulong	; 
		else version(intId	) alias T = uint	; 
		else {
			alias T = ulong; 
			//Todo: it could be string in debug mode. Needs a new ide to handle that.
		}
		
		T value; 
		
		bool opCast(B : bool)() const { return value != T.init; } 
		
		/*
			  bool opEquals(in SrcId b) const{ return value == b.value; }
						size_t toHash() const{ return .toHash(value); }
		*/
		
		alias value this; 
	} 
	
	static if(is(SrcId.T==uint) || is(SrcId.T==ulong))
	{
		//auto srcId(in SrcId i1, in SrcId i2){ return SrcId(cast(SrcId.T)hashOf(i2.value, i1.value)); }
		
		auto combine(T)(in SrcId i1, in T i2) { return SrcId(cast(SrcId.T)hashOf(i2, i1.value)); } 
		void appendIdx(T)(ref SrcId id, in T idx) { id = combine(id, idx); } 
		
		//Note: string hash is 32 bit only, so the proper way to combine line and module is hash(line, hash(module))
		auto srcId(string srcModule=__MODULE__, size_t srcLine=__LINE__, Args...)(in Args args)
		{
			auto id = SrcId(cast(SrcId.T)hashOf(srcLine, hashOf(srcModule))); 
			//Note: direkt van 2 hashOf, mert a hashOf(srcModule, x), az csak 32 bites!!!!
			mixin(appendGenericIds("id")); 
			return id; 
		} 
	}
	else static if(is(SrcId.T==string))
	{
		//auto srcId(in SrcId i1, in SrcId i2) { return SrcId(i1.value ~ '.' ~ i2.value); }
		
		auto combine(T)(in SrcId i1, in T i2) { return SrcId(i1.value ~ '.' ~ i2.text); } 
		void appendIdx(T)(ref SrcId id, in T idx) { id ~= '[' ~ idx.text ~ ']'; } 
		//for clarity string uses the [idx] form, instead of a.b;
		
		auto srcId(string srcModule=__MODULE__, size_t srcLine=__LINE__, Args...)(in Args args)
		{
			auto id = SrcId(srcLocationStr!(srcModule, srcLine)); 
			//.d is included to make sourceModule detection easier
			mixin(appendGenericIds("id")); 
			return id; 
		} 
	}
	else
	static assert(0, "Invalid SrcId.T"); 
	
	void test_SrcId()
	{
		{
			//simple id test: id's on same lines are equal, except with extra params
			
			auto f1(string srcModule = __MODULE__, size_t srcLine = __LINE__, Args...)(in Args args)
			{
				auto id = srcId!(srcModule, srcLine)(args); 
				return id.value; 
			} 
			
			//newlines in source do matter here!!!!
			/+1+/ enum i1 = srcId; enum i2 = srcId; 
			/+2+/ enum i3 = srcId; auto i4 = srcId(genericArg!"id"("Hello"), genericArg!"id"(123)), i5 = srcId(genericArg!"id"("Hello")); 
			/+3+/ auto i6 = i5.combine("Test"); 
			/+4+/ auto i7 = i6.combine(0); 
			enforce(i1==i2 && i2!=i3 && i3!=i4 && i4!=i5 && i5!=i6 && i6!=i7); 
		}
	} 
	version(/+$DIDE_REGION FieldDeclarations+/all)
	{
		struct StructInfo
		{
			struct FieldInfo
			{
				string uda, type, name, default_; 
				size_t ofs, size; 
				
				string toString()const
				{ return (uda.empty ? `` : `@(`~uda~`) `) ~ "%s %s = %s; // ofs:%d size:%d".format(type, name, default_, ofs, size); } 
				
				string getoptLine(string ownerName)const
				{
					//returns a line used by std.getopt()
					//example: "w|WFPerCU"     , `Number of WaveFronts on each Compute Units. Default: `~defOptions.WFPerCU.text, &WFPerCU  ,
					
					//split at param = descr
					string param, descr; 
					if(!split2(uda, "=", param, descr))
					{
						descr = param; 
						param = ""; 
					}
					
					//split at shortParam | longParam
					string shortParam, longParam; 
					if(!split2(param, "|", shortParam, longParam))
					{
						if(shortParam.length!=1)
						{
							longParam = shortParam; 
							shortParam = ""; 
						}
					}
					
					//default short and long param
					if(shortParam=="") shortParam = name[0..1].lc; 
					if(longParam=="") longParam = name; 
					
					descr = descr.replace("$DEFAULT$", default_); 
					
					//format the final string that can be used in getopt()
					return `"%s|%s", "%s", &%s.%s`.format(shortParam, longParam, descr.replace(`"`, `\"`), ownerName, name); 
				} 
			} 
			
			string name; 
			size_t size; 
			FieldInfo[] fields; 
			
			string toString()const
			{
				return "struct "~name~" {"~
					fields.map!(f => "\r\n  "~f.text).join
				~"\n\r} // size:%s \n\r".format(size); 
			} 
			
			string[] getoptLines(string ownerName)const
			{ return fields.map!(f => f.getoptLine(ownerName)).array; } 
		} 
		
		auto getStructInfo(T)()
		if(isAggregateType!T)
		{
			StructInfo si; 
			si.name = T.stringof; 
			si.size = T.sizeof; 
			
			T defStruct; 
			
			import std.traits; 
			foreach(name; FieldNameTuple!T)
			{
				//get some rtti
				StructInfo.FieldInfo fi; 
				fi.name = name; 
				mixin(
					q{
						fi.default_ = defStruct.*.text; 
						fi.type = typeof(T.*).stringof; 
						fi.uda = __traits(getAttributes, T.*).text; 
						fi.ofs = T.*.offsetof; 
						fi.size = typeof(T.*).sizeof; 
					}.replace("*", name)
				); 
				si.fields ~= fi; 
			}
			
			return si; 
		} 
		
		auto getStructInfo(T)(const T t)
		if(isAggregateType!T)
		{ return getStructInfo!T; } 
		
		static string[] tupleToStringArray(A...)()
		{
			string[] res; 
			static foreach(i; 0..A.length) res ~= A[i].stringof; 
			return res; 
		} 
		
		enum FieldDeclarations(T) = zip(tupleToStringArray!(FieldTypeTuple!T), [FieldNameTuple!T]).map!"a[0]~' '~a[1]~';'".join('\n'); 
		
		//Todo: list members of a module recursively. Adam Ruppe book
		/*
			pragma(msg, __traits(allMembers, thisModule));
			
			
			struct S{}
			enum E {asdf};
			class C{}
			
			template symbols(alias mod){
				alias symbols = staticMap!(__traits(getMember, mod, T), __traits(allMembers, mod));
			}
			
			void listModuiles(){
					static foreach(s; symbols!thisModule){
						 pragma(msg, fullyQualifiedName!s);
					}
			
					alias notmods = Filter!(templateNot!notmodule, symbols!thismodule);
			
			
			}
		*/
	}
	
	///Used for get a hash based on the aggregated content type of a struct
	///align and nested structs matter.
	uint getStructHash(S)()
	{
		size_t h = hashOf("structHash", S.sizeof); 
		static foreach(f; FieldNameTuple!S)
		{
			{
				alias m = mixin("S.", f); 
				alias T = typeof(m); 
				h = hashOf(f, h); 
				h = hashOf(m.sizeof, h); 
				h = hashOf(m.offsetof, h); 
				h = hashOf(T.stringof, h); 
				static if(is(T==struct)) h = hashOf(getStructHash!T, h); 
			}
		}
		return h & 0xFFFFFFFF; 
	} 
	
	version(/+$DIDE_REGION+/all)
	{
		template staticSizeSum(A...)
		{
			static if(A.length==0) enum staticSizeSum = 0; 
			else enum staticSizeSum = A[0].sizeof + staticSizeSum!(A[1..$]); 
		} 
		
		/+
			+ Tells that all the @STORED fields of a type:
			- has fixed size, statically streamable data (only contains static array and struct)
			- struct fields are tightly aligned
			So the whole type can be serialized directly with a single copy/move operation.
		+/
		template isFixedSizeOpaqueType(T)
		{
			static if(isScalarType!T)
			{ enum isFixedSizeOpaqueType = true; }
			else static if(isStaticArray!T)
			{ enum isFixedSizeOpaqueType = isFixedSizeOpaqueType!(ElementType!T); }
			else static if(is(T==struct))
			{
				alias Fields = T.tupleof; 
				static if(allSatisfy!(templateNot!(isStoredField), Fields))
				alias StoredFields = Fields; 
				else
				alias StoredFields = Filter!(isStoredField, Fields); 
				
				alias getType(alias f) = typeof(f); 
				enum isFixedSizeOpaqueType 	= allSatisfy!(.isFixedSizeOpaqueType, staticMap!(getType, StoredFields))
					&& T.sizeof==staticSizeSum!StoredFields; 
			}
			else
			enum isFixedSizeOpaqueType = false; 
		} 
	}
	
	version(/+$DIDE_REGION NiceExpression implementations+/all)
	{
		static auto 體(T, string def)() //struct
		{ return format!`((){%s _={%s};return _;}())`(T.stringof, def); } 
		static auto 舉(T, string def)() //enum
		{ return format!`(%s.%s)`(T.stringof, def); } 
		static auto 幟(T, string def)() //flags
		{ return format!`((){with(%s) return %s;}())`(T.stringof, def); } 
	}
	
	version(/+$DIDE_REGION SmartClass+/all)
	{
		struct PARENT {} 
		
		mixin template SmartParentTemplate()
		{
			private
			{
				bool _ignoreChildDestructionNotifocations; 
				bool[Object] _childMap; 
				
				void _notifyParent_childCreated(Object a)
				{
					_childMap[a] = true; 
					
					//Note: parent.onChildCreated is called always.
					static if(__traits(compiles, { this._onChildCreated(a); } ))
					this._onChildCreated(a); 
				} 
				
				void _notifyParent_childDestroying(Object a)
				{
					if(!_ignoreChildDestructionNotifocations)
					{
						
						//Note: parent.onChildDestroying is only called when the parent is NOT destroying.
						static if(__traits(compiles, { this._onChildDestroying(a); } ))
						this._onChildDestroying(a); 
						
						_childMap.remove(a);  
					}
				} 
				
				auto _children()
				{ return _childMap.byKey; } 
				
				void _thisParentDestroying()
				{
					//Note: ⚠This must be called frrom a destructor first
					//LOG("~parent", typeof(this).stringof); 
					_ignoreChildDestructionNotifocations = true; 
					_children.each!destroy; 
					_childMap = null; 
				} 
			} 
		} 
		
		mixin template SmartChildTemplate(alias parentField)
		{
			private
			{
				alias _parent = parentField; 
				
				void _thisChildCreated()
				{
					//Note: ⚠This must be called right after a successful constructor
					if(_parent) _parent._notifyParent_childCreated(this); 
				} 
				
				void _thisChildDestroying()
				{ if(_parent) _parent._notifyParent_childDestroying(this); } 
			} 
		} 
		
		template FunctionParameterProcessor(alias f /+this must be a function, defining field types, names and defaults+/)
		{
			alias types = Parameters!f; 
			alias names = ParameterIdentifierTuple!f; 
			alias defaults = ParameterDefaults!f; 
			
			enum length = types.length; 
			
			enum typeStr	(int i) = types[i].stringof; //it has no UDAs
			enum typeUdaStr	(int i) = types[i..i+1].stringof[1..$-1];  //It has UDAs -> @(AliasSeq!((PARENT)), AliasSeq!("hello")) type
			enum defaultEqStr	(int i) = defaults[i].stringof!="void" ? "="~defaults[i].stringof : ""; 
			enum fieldDeclaration   (int i) = format!"%s %s;"(typeUdaStr!i, names[i]); //udas, but no defaults here
			enum fieldInitialization(int i) = format!"this.%s = %s;"(names[i], names[i]); 
			enum paramDeclaration	(int i) = (i ? "," : "") ~ format!"%s %s%s"(typeStr!i, names[i], defaultEqStr!i); //no udas, but has defaults
			
			string transform(alias fv)() { string res; 	static foreach(i; 0..length) res ~= fv!i; return res; } 
			
			enum fieldDeclarations = transform!fieldDeclaration; 
			enum paramDeclarations = transform!paramDeclaration; 
			enum fieldInitializations = transform!fieldInitialization; 
		} 
		
		string generateSmartClassCode_impl(alias f, Flag!"hasChildren" hasChildren, string customConstructor)()
		{
			alias P = FunctionParameterProcessor!f; 
			
			string res; 
			enum hasParent = P.typeUdaStr!0.canFind("(PARENT)"); //hasUDA not works...
			
			res ~= P.fieldDeclarations ~ "\n"; 
			if(hasChildren) res ~= format!"mixin SmartParentTemplate; \n"; 
			if(hasParent) res ~= format!"mixin SmartChildTemplate!%s; \n"(P.names[0]); 
			version(/+$DIDE_REGION+/none) {
				res ~= format!"this(%s){ %s static if(__traits(compiles, { _construct; })) _construct; %s%s}\n"
					(
					P.paramDeclarations, P.fieldInitializations, 
					hasParent ? "_thisChildCreated;" : "",
					customConstructor
				); 
				res ~= format!"~this(){ %s %s static if(__traits(compiles, { _destruct; })) _destruct; }\n"
					(
					hasChildren ? "_thisParentDestroying;" : "",
					hasParent ? "_thisChildDestroying;" : "",
				); 
			}
			
			res ~= iq{
				this($(P.paramDeclarations))
				{
					$(P.fieldInitializations); $(customConstructor); 
					static if(__traits(compiles, { _construct; })) _construct; 
					$(((hasParent)?("_thisChildCreated;"):(""))); 
				} 
				~this()
				{
					$(((hasChildren)?("_thisParentDestroying;"):(""))); 
					$(((hasParent)?("_thisChildDestroying;"):(""))); 
					static if(__traits(compiles, { _destruct; })) _destruct; 
				} 
			}.text; 
			
			return res; 
		} 
		
		mixin template SmartClass(string fieldDefs, Flag!"hasChildren" hasChildren = No.hasChildren, string customConstructor = "")
		{ mixin(generateSmartClassCode!(fieldDefs, hasChildren, customConstructor)); } 
		
		mixin template SmartClass(string fieldDefs, string customConstructor, Flag!"hasChildren" hasChildren = No.hasChildren)
		{ mixin(generateSmartClassCode!(fieldDefs, hasChildren, customConstructor)); } 
		
		mixin template SmartClassParent(string fieldDefs)
		{ mixin SmartClass!(fieldDefs, Yes.hasChildren); } 
		
		mixin template SmartClassGenerator()
		{
			/+
				Note: This shoud be mixed in into a place to see the imports of the actual fieldDefs.
				Usage: /+Code: mixin SmartClassGenerator;+/
				Example: High level Vulkan classes
			+/
			
			private string generateSmartClassCode(string fieldDefs, Flag!"hasChildren" hasChildren, string customConstructor)()
			{
				//pragma(msg, generateSmartClassCode!(fieldDefs, hasChildren, customConstructor)); 
				mixin("void f("~fieldDefs~"){}"); 
				return generateSmartClassCode_impl!(f, hasChildren, customConstructor); 
				
				/+Todo: Read the manual and fix this mixin template mess!  Use minimal string mixins!+/
			} 
		} 
		
		
	}
	
	version(/+$DIDE_REGION+/all)
	{
		struct 表
		{
			string[][] allRows; 
			
			auto rows()
			{
				/+It skips empty rows and rows with only one cell starting with a comment.+/
				static isComment(string s)
				{
					if(s.length>=2 && s[0]=='/')
					{
						if(s[1]=='+' && s[$-2..$]=="+/") return true; 
						if(s[1]=='*' && s[$-2..$]=="*/") return true; 
						if(s[1]=='/') return true; 
					}
					return false; 
				} 
				
				return allRows.filter!(r=>r.length>=1 && !r.all!isComment); 
				//Todo: full row //comment detection is failing
			} 
			
			string cell(long x, long y)
			{ return allRows.get(y).get(x); } 
			
			auto column(int x)()
			{ return rows.map!(r=>r.get(x)); } 
			
			string headerCell(long x)
			{
				auto s = cell(x, 0); 
				if(s.length>=4 && s.startsWith("/+") && s.endsWith("+/"))
				{
					s = s[2..$-2]; 
					foreach(prefix; ["note:"].map!"[a, a.capitalize]".joiner)
					if(s.startsWith(prefix)) {
						s = s.withoutStarting(prefix).withoutStarting(' '); 
						break; 
					}
				}
				return s; 
			} 
			
			string[] headerRow()
			{
				//return allRows.get(0).length.iota.map!((i)=>(this.headerCell(i))).array; 
				const cnt = allRows.get(0).length; 
				string[] res; foreach(i; 0..cnt) res ~= headerCell(i); return res; 
				//Todo: weird bug: .iota won't work here...
				
			} 
			
			string GEN(string src)()
			{
				static if(__traits(compiles, { return mixin(src); }))	return mixin(src); 
				else	mixin(src); 
			} 
			
			string GEN_bitfields(R)(R rows)
			{
				/+Todo: This must be replaced by a template mixin!+/
				static if(isInputRange!R)
				{
					string[] res; ulong totalDef; int totalBits; 
					foreach(r; rows)
					{
						{
							auto type = r[0], name = r[2], bits = r[1].to!int, def = r[3].to!int.ifThrown(0); 
							totalDef = totalDef.setBits(totalBits, bits, def); 
							if(def) totalDef |= (long(def) & ((1<<bits)-1))<<totalBits; 
							res ~= format!`%s,%s,%s,`(type, name, bits); //Note: Name must evaluate to string literal
							totalBits += bits; 
						}
					}
					enforce(totalBits.inRange(1, 64), format!"Invalid bitCount: %s"(totalBits)); 
					const 	roundedBits = max(totalBits.nearest2NSize, 8),
						defT = roundedBits.predSwitch(8, "ubyte", 16, "ushort", 32, "uint", 64, "ulong"); 
					if(totalBits < roundedBits) res ~= format!q{uint,"_dummy",%s}(roundedBits - totalBits); 
					return format!q{
						union  {
							%s _default = %s; 
							mixin(std.bitmanip.bitfields!(%s)); 
						} 
					}(
						defT, totalDef.format!"0x%X", 
						res.join
					); 
				}
				else
				{ return GEN_bitfields(rows.rows); }
			} 
			
			string GEN_bitfields()
			{
				/+Todo: This must be replaced by a template mixin!+/
				return GEN_bitfields(rows); 
			} 
			
			string GEN_fields()
			{
				/+Todo: This must be replaced by a template mixin!+/
				const 	hdr 	= headerRow,
					cType 	= hdr.countUntil("Type"),
					cName 	= hdr.countUntil("Name"),
					cDefault 	= hdr.countUntil("Default"),
					cUDAs	= hdr.enumerate.filter!((a)=>(a.value.startsWith('@'))).map!"a.index".array; 
				return (
					mixin(求map(q{r},q{rows},q{
						string getUDA(long c) => 
						((r.get(c)=="")?("") : (iq{$(hdr[c])($(r[c])) }.text)); string getDefault() => 
						((r.get(cDefault)=="")?("") : ("="~r[cDefault])); 
						return iq{$(cUDAs.map!getUDA.join)$(r[cType]) $(r[cName]) $(getDefault); }.text ~ '\n'; 
					}))
				).join; 
			} 
			
			string GEN_verbs(Flag!"hold" hold = No.hold)
			{
				/+Todo: This must be replaced by a template mixin!+/
				const 	hdr 	= headerRow,
				cKey 	= hdr.countUntil("Key"),
				cName 	= hdr.countUntil("Name"),
				cScript 	= hdr.countUntil("Script"),
				cUDAs	= hdr.enumerate.filter!((a)=>(a.value.startsWith('@'))).map!"a.index".array; 
				return (
					mixin(求map(q{r},q{rows},q{
						string getUDA(long c) => ((r.get(c)=="")?(""): (iq{$(hdr[c])($(r[c])) }.text)); 
						const 	udas = cUDAs.map!getUDA.join ~ iq{@$(((hold)?("HOLD"):("VERB")))($(r[cKey])) }.text,
							functName = r[cName]~((r[cName].stripRight.endsWith(')'))?(""):("()")); 
						return iq{$(udas)void $(functName) {$(r[cScript])} }.text ~ '\n'; 
					}))
				).join; 
			} 
			
			string GEN_enumTable()
			{
				/+Todo: This must be replaced by a template mixin!+/
				const 	numCols 	= headerRow.length, 
					prefix 	= headerCell(0).strip; 
				
				string withoutType(string s) => ((s.canFind(':'))?(s.splitter(':').front.strip):(s)); 
				
				
				string generateColumn(string fmt)(size_t colIdx, string label)
				{
					/+Todo: these nasty hacks should be marked with a hidden comment, not a special symbol character.+/
					if(label.endsWith('#'))	return format!fmt(label[0..$-1], rows.map!((a)=>("q{"~a[colIdx].unpackDComment!"Code"~"}"))); 
					else if(label.endsWith('$'))	return format!fmt(label[0..$-1], rows.map!((a)=>("q{"~a[colIdx]~"}"))); 
					else	return format!fmt(label, rows.map!((a)=>(a[colIdx]))); 
				} 
				
				string res = generateColumn!"enum %s {%-(%s,%)}"(0, prefix.capitalize); 
				foreach(i; 1..numCols)
				res ~= generateColumn!"enum %s = [%-(%s,%)];"(i, withoutType(prefix.decapitalize) ~ headerCell(i).capitalize); 
				return res; 
				
				/+
					Use this code to verify the generated enums.
					/+
						Code: mixin template DumpEnumTable(string prefix)
						{
							pragma(msg, prefix~"\t"~EnumMemberNames!Type/+!!!!+/.stringof); 
							static foreach(name; __traits(allMembers, typeof(this)))
							static if(name.startsWith(prefix) && name.length>prefix.length)
							pragma(msg, name~"\t"~mixin(name).text); 
							pragma(msg, prefix~"\t"~EnumMemberNames!Type/+!!!!+/.stringof.hashOf.to!string(26)); 
							static foreach(name; __traits(allMembers, typeof(this)))
							static if(name.startsWith(prefix) && name.length>prefix.length)
							pragma(msg, name~"\t"~mixin(name).text.hashOf.to!string(26)); 
						} 
					+/
				+/
			} 
			
			string GEN_enum(R)(string name, R items)
			{
				/+Todo: This must be replaced by a template mixin!+/
				return format!q{enum %s {%s} }(name, items.join(", "))~'\n'; 
			} 
			
			
			
			version(/+$DIDE_REGION GEN_StructureScanner+/all)
			{
				
				string GEN_StructureScanner_State(R)(R items)
				{ return GEN_enum("State : "~((items.walkLength<0x100)?("ubyte"):("ushort")), items); } 
				
				string GEN_StructureScanner_EntryTransitions(R0, R1)(string name, R0 tokens, R1 states)
				{
					return format!q{enum %s = chain(%s).array; }
					(name, zip(tokens, states).filter!q{a[0]!=""}.map!q{format!"Push(%s, State.%s)"(a[0], a[1])}	.join(","))~'\n'; 
				} 
				
				string GEN_StructureScanner_EntryTransitions(R0, R1)(R0 tokens, R1 states)
				{ return GEN_StructureScanner_EntryTransitions("EntryTransitions", tokens, states); } 
				
				string GEN_StructureScanner_StateTransitions(R0, R1, R2)(string name, string enumName, R0 transitionItems, R1 leaveItems, R2 eofItems)
				{
					return format!q{static immutable %s = ((){ with(%s) return [%s]; }()); }
					(
						name, enumName,
						zip(transitionItems, leaveItems, eofItems).map!
						((a){
							string preprocess(string s)
							{ s = s.strip; if(s.startsWith("/+")&&s.endsWith("+/")) s = ""; return s; } 
							auto trans = preprocess(a[0]); 
							auto leave = preprocess(a[1]); if(leave!="") leave = "Pop("~leave~")"; 
							auto eof = preprocess(a[2]); 
							return only(trans, leave, eof).filter!"a!=``".join("~"); 
						})
						.join(",")
					)~'\n'; 
				} 
				
				string GEN_StructureScanner_StateTransitions(R0, R1, R2)(R0 transitionItems, R1 leaveItems, R2 eofItems)
				{ return GEN_StructureScanner_StateTransitions("StateTransitions", "State", transitionItems, leaveItems, eofItems); } 
				
				string GEN_StructureScanner(string initializations="")
				{
					//Help -> StructureScanner_DLang
					return [
						GEN_StructureScanner_State(column!1),
						q{static: mixin StructureScanner.prologue; },
						
						initializations,
						
						GEN_StructureScanner_EntryTransitions(column!0, column!1),
						GEN_StructureScanner_StateTransitions(column!2, column!3, column!4),
						
						q{mixin StructureScanner.epilogue; }
					].join('\n'); 
				} 
			}
		} 
		
		//put popular generators onto the global scope
		/+Todo: This must be replaced by a template mixin!+/
		static foreach(name; "bitfields fields enumTable StructureScanner".split)
		mixin(iq{string GEN_$(name)(表 t) => t.GEN_$(name); }.text); 
		/+Todo: Nonstandard casing (sometimes capitalized, sometimes not)  I thing everything capitalized would be better.+/
		
		//This is the new way: template mixin instead of string mixin.
		mixin template INJECTOR_TEMPLATE(alias _data, string _script)
		{ mixin(_script); } 
		alias 入 = INJECTOR_TEMPLATE; 
		
		string 求(string low, string high, string expr, string fun /+the final function: including "."   eg: ".sum"+/)
		/+Note: Code generator for sigma operations.  Used in DIDE NiceExpressions.+/
		{
			static fetchType(ref string id)
			{
				string type; 
				if(!id.isDLangIdentifier)
				{
					auto parts = id.split(" "); 
					auto id2 = parts.back; 
					type = id[0..$-id2.length]; 
					id = id2; 
				}
				return type; 
			} static fetchStep(ref string src)
			{
				string step; 
				auto parts = src.splitDLang(","); 
				if(parts.length == 2)
				{
					step = parts[1]; 
					src = parts[0]; 
				}
				return step; 
			} 
			
			static fetchInclusivity1(ref string src)
			{
				if(src.startsWith('='))
				{ src = src[1..$].stripLeft; return true; }return false; 
			} 
			static fetchInclusivity2(ref string src)/+Note: < or <=   default <=+/
			{
				if(src.startsWith("<"))
				{ src = src[1..$]; return fetchInclusivity1(src); }return true; 
			} 
			
			static string formatGeneratorCode(
				string start, bool includeStart, 
				string end, bool includeEnd, string step
			)
			{
				if(step=="") step = "1"; 
				static foreach(a; AliasSeq!(start, end, step)) a = "("~a~")"; 
				if(!includeStart) start ~= "+"~step; 
				return format	!"iota%s(%s,%s,%s)"
					(
					includeEnd ? "_closed" : "", 
					start, end, step,
				); 
			} 
			
			static string formatCode(
				string generatorCode, string type, string id, 
				string expr, string fun
			)
			{
				expr = expr.removeDLangComments; 
				const isCode = expr.length && expr.back.among(';', '}'); 
				if(fun=="each")
				{
					if(!isCode) expr ~= ';'; //make it a valid statement
					return format	!"%s.each!((%s){%s});"
						(generatorCode, strip(type~' '~id), expr); 
				}
				else
				{
					return format(
						((isCode)?("(%s.map!((%s){%s})%s)") :("(%s.map!((%s)=>(%s))%s)")),
						generatorCode, strip(type~' '~id), expr, fun
					); 
				}
			} 
			
			auto parts = low.splitDLang("<"); 
			if(parts.length==3 /+Note: min <= var <= max ,step+/)
			{
				auto 	start 	= parts[0],
					id 	= parts[1],
					end 	= parts[2],
					includeStart 	= fetchInclusivity1(id),
					includeEnd 	= fetchInclusivity1(end),
					step	= fetchStep(end),
					type	= fetchType(id); 
				//also include 'high' to generate an error.
				high = high.removeDLangComments; 
				if(high!="") step ~= ","~high; 
				return formatCode(
					formatGeneratorCode
					(
						start, includeStart, 
						end, includeEnd, step
					), 
					type, id, expr, fun
				); 
			}
			
			parts = low.splitDLang("="); 
			if(parts.length==2 /+Note: var=min, step  |  <=max+/)
			{
				auto 	id	= parts[0],
					type	= fetchType(id),
					start	= parts[1],
					step	= fetchStep(start),
					end	= removeDLangComments(high),
					includeStart 	= true,
					includeEnd	= fetchInclusivity2(end); 
				return formatCode(
					formatGeneratorCode
					(
						start, includeStart, 
						end, includeEnd, step
					), 
					type, id, expr, fun
				); 
			}
			
			{
				/+Note: If non of the above,  ->  it is a .map() on a range.+/
				auto 	elements 	= removeDLangComments(high),
					id 	= removeDLangComments(low),
					type	= fetchType(id); 
				
				/+Add optional [] if there is more "," separated items.+/
				const brackets = ((elements.splitDLang(",").length>=2) ?("[]"):("()")); 
				elements = brackets[0] ~ elements ~ brackets[1]; 
				
				//Todo: a,b..c,d  felsorolas.
				
				return formatCode(elements, type, id, expr, fun); 
			}
			
			//throw new Exception("Invalid sigma-operation operands."); 
		} 
		
		string 求map(string low, string high, string expr)
		{ return 求(low, high, expr, ""/+Note: map is the default behavior: nothing, just iterate.+/); } 
		
		string 求each(string low, string high, string expr)
		{ return 求(low, high, expr, "each"/+Note: "each" is a special case+/); } 
		
		string 求sum(string low, string high, string expr)
		{ return 求(low, high, expr, ".sum"); } 
		
		string 求product(string low, string high, string expr)
		{ return 求(low, high, expr, ".product"); } 
		
		
		//Inspector
		auto 檢(A...)(ulong location, A args)
		{
			static assert(A.length>=1); 
			
			if(dbg.isActive)
			{
				static if(isImage2D!(A[0]))
				{
					static assert(A.length==1); 
					auto data = args[0].asArray; 
					auto blobAddress = dbg.setBlob(location, data); 
					dbg.sendLog(
						"LOG:INSP_IMG_BLB:"~location.to!string(16)~":"~blobAddress.to!string(16)
							~":"~typeof(data[0]).stringof
							~":"~args[0].width.to!string(16)
							~":"~args[0].height.to!string(16)
					); 
				}
				else
				{
					static if(A.length==1)	auto txt = args[0].text; 
					else	auto txt = text(args[0..$]); 
					if(txt.length<=1024)
					{ dbg.sendLog("LOG:INSP_TXT:"~location.to!string(16)~":"~txt); }
					else
					{
						auto blobAddress = dbg.setBlob(location, cast(void[])txt); 
						dbg.sendLog("LOG:INSP_TXT_BLB:"~location.to!string(16)~":"~blobAddress.to!string(16)); 
					}
				}
			}
			
			static if(A.length==1)	return args[0]; 
			else	return tuple(args[0..$]); 
		} 
		
		
		//StopWatch
		auto init間()
		{ return now; } 
		
		auto update間(ref DateTime state)
		{
			const 	act = now,
				ΔT = act-state,
				ms = (float(ΔT.value(milli(second)))),
				str = 	(
				ms<1 	? ms.format!"%.2f" :
				ms<10 	? ms.format!"%.1f"
					: ms.format!"%.0f"
			) ~ " ms"; 
			state = act; 
			return str; 
		} 
		
		
		string ONCE(string scr)
		{ return scr.format!q{{ static bool running; if(running.chkSet) {%s}}}; } 
		
		//call a function
		auto 調(alias fun, Args...)(Args args)
		{
			/+Todo: Should deprecate this! Use template mixins!+/
			return fun(args); 
		} 
		
		//constant literals (compile time)
		auto 常(T)(T val)
		{ return val; } 
		
		//index operation
		string 指(string var, string idx)
		=> var~'['~idx~']'; 
		
		bool waitForZeroAndSet(T)(T* reference, T newValue, int numTries)
		{
			import core.atomic; int cnt=0; 
			while(!cas(reference, T(0), newValue)) { cnt++; if(cnt>=numTries) return false; }
			return true; 
		} 
		
		//interactive values (run time)
		auto 互(T, T def, ulong id)()
		{
			static int index=-1; 
			if(dbg.isActive)
			{
				auto iv = &dbg.data.interactiveValues; 
				if(index<0)
				{ index = iv.resolveIndex(id, def.to!float); }
				return iv.floats[index].to!T; 
			}
			else
			return def/+debugger is inactive+/; 
		} 
		
		bool 同internal(T, ulong id)(ref T val)
		{
			static int index=-1; 
			if(dbg.isActive)
			{
				auto iv = &dbg.data.interactiveValues; 
				if(index<0)
				{ index = iv.resolveIndex(id, val.to!float); }
				if(iv.ticks[index])	{ val = cast(T)iv.floats[index]; return true; }
				else	{ iv.floats[index] = val; return false; }
			}
			else
			return false; 
		} 
		
		auto 同(string T, string sym, string id)()
		{
			return iq{
				() {
					$(T) act = $(sym); 
					if(同internal!($(T), $(id))(act))
					$(sym) = act; 
					return act; 
				} ()
			}.text; 
		} 
		
		auto tuplify(size_t n, R)(R r) if (isInputRange!R)
		{
			/+Link: https://stackoverflow.com/questions/47046850/is-there-any-way-to-assign-multiple-variable-at-once-with-dlang+/
			Tuple!(Repeat!(n, ElementType!R)) result; 
			static foreach(i; 0..n) { result[i] = r.front; r.popFront(); }assert(r.empty); 
			return result; 
		} 
		
		auto tupleOp(string op, A, B)(A a, B b)
		{
			static if(a.length==b.length)	return mixin("tuple(",iota(a.length).map!(i=>iq{a[$(i)] $(op) b[$(i)],}.text).join,")"); 
			else static if(a.length==1)	return mixin("tuple(",iota(b.length).map!(i=>iq{a[0] $(op) b[$(i)],}.text).join,")"); 
			else static if(b.length==1)	return mixin("tuple(",iota(a.length).map!(i=>iq{a[$(i)] $(op) b[0],}.text).join,")"); 
			else static assert(false, "Invalid params."); 
		} 
		
		string 配(string left, string op, string right) /+Note: Tuple operations: (x,y) += (y,x)+/
		{
			auto opStr() => '"'~op~'"'; 
			auto isBinaryOp(string op) => !!op.among("+", "-", "*", "/", "%", "^", "~", "<<", ">>", ">>>", "^^"); 
			
			if(op.among("=", "==", "is"))
			return iq{tuple(AliasSeq!($(left)) $(op) tuple($(right)))}.text; 
			else if(isBinaryOp(op))
			return iq{tupleOp!$(opStr)(tuple($(left)),tuple($(right)))}.text; 
			else if(op.endsWith('=') && isBinaryOp(op[0..$-1]))
			return iq{tuple(AliasSeq!($(left))=(tupleOp!$(opStr)(tuple($(left)),tuple($(right)))))}.text; 
			else enforce(false, "Invalid params."); 
			assert(0); 
		} 
		
		/+Note: tenary relationals+/
		string 界0(string mi, string x, string ma) => iq{($(mi))<($(x)) && ($(x))<($(ma))}.text; 
		string 界1(string mi, string x, string ma) => iq{($(mi))<=($(x)) && ($(x))<($(ma))}.text; 
		string 界2(string mi, string x, string ma) => iq{($(mi))<($(x)) && ($(x))<=($(ma))}.text; 
		string 界3(string mi, string x, string ma) => iq{($(mi))<=($(x)) && ($(x))<=($(ma))}.text; 
		
		/+Note: tenary equal+/
		string 等(string a, string b, string c) => iq{($(a))==($(b)) && ($(b))==($(c))}.text; 
		
		/+
			Todo: UnitTest relational operations.
			/+
				Code: string[5] x; auto a(bool b) => ((b)?('✅'):('❌')); 
				(mixin(求each(q{i=0},q{4},q{
					((0x5188F6F833B).檢((mixin(指(q{x},q{0}))) ~= a(mixin(界0(q{1},q{i},q{4 }))))),
					((0x5708F6F833B).檢((mixin(指(q{x},q{1}))) ~= a(mixin(界1(q{1},q{i},q{4 }))))),
					((0x5C88F6F833B).檢((mixin(指(q{x},q{2}))) ~= a(mixin(界2(q{1},q{i},q{4 }))))),
					((0x6208F6F833B).檢((mixin(指(q{x},q{3}))) ~= a(mixin(界3(q{1},q{i},q{4 }))))),
					((0x6788F6F833B).檢((mixin(指(q{x},q{4}))) ~= a(mixin(等(q{2},q{i},q{4-i})))))
				}))); 
			+/
		+/
		
	}
	
}
version(/+$DIDE_REGION Numeric+/all)
{
	//Numeric ///////////////////////////////////////
	version(/+$DIDE_REGION+/all) {
		alias uint64_t 	= ulong	, int64_t 	= long	,
		uint32_t	= uint	, int32_t	= int	,
		uint16_t	= ushort	, int16_t	= short	,
		uint8_t	= ubyte	, int8_t	= byte	; 
		
		//Todo: Table based programming. definition: : rowmajor col=2 "alias %1s = %2s, ...; "
		
		//enum PIf = 3.14159265358979323846f;
		/+
			Todo: not sure about where is it used or not used. 
					      If float*double(pi) doesnt calculates using double cpu instructions then it is obsolete. 
		+/
		
		//it replaces the exception with a default value.
		T safeConv(T, U)(const U src, lazy const T def)
		{ try { return src.to!T; }catch(Throwable) { return def; }} 
		
		T safeDiv(T)(T a, T b, T def=0)
		{ return b==0 ? def : a/b; } 
		
		/*
			  it's het.math.mod auto cyclicMod(T, U)(T a, U b) if(__traits(compiles, a%b)){
						auto c = a%b;
						if(c<0) c += b;
						return c;
					}
		*/
		
		
		float wrapInRange(ref float p, float pMin, float pMax)
		{
			float len = pMax-pMin, pOld = p; 
			while(p<pMin) p += len; //Todo: opt with fract
			while(p>pMax) p -= len; 
			return p-pOld; 
		} 
		
		float wrapInRange(ref float p, float pMin, float pMax, ref int wrapCnt)
		{
			//specialised version for endless sliders
			float len = pMax-pMin, pOld = p; 
			wrapCnt = 0; 
			while(p<pMin) { p += len; wrapCnt++; }
			while(p>pMax) { p -= len; wrapCnt--; }
			return p-pOld; 
		} 
		
		///Calculates circular rotation delta where the circle is divided to N segments.
		///Example: cyclicDelta(270, 5, 360) == 95
		auto cyclicDelta(A, B, N)(A a, B b, N n)
		if(isIntegral!A && isIntegral!B && isIntegral!N)
		in(n>=3)
		in(a.inRange(0, n))
		in(b.inRange(0, n))
		do {
			const m = (n-1)/2; 
			if(a==b) return 0; 
			auto d = b-a; 
			d = d>m ? d-n : d<-m ? d+n : d; 
			return d; 
		} 
		//Todo: unittest on a 0..N+1 square. N e 3, 4, 5
		
		
		T rcpf_fast(T)(const T x)if(__traits(isFloating, T))
		{
			return 1.0f/x; //Todo: Ezt megcsinalni SSE-vel
		} 
		
		struct percent
		{
			float value = 0; 
			@property multiplier() const { return value*1e-2f; } 
			@property multiplier(float p) { value = p*1e2f; } 
					
			string toString() const { return "%6.2f%%".format(value); } 
					
			percent opBinary(string op)(in percent b)	const
			{ return mixin(q{percent(multiplier %s b.multiplier)}.format(op)); } 
			float opBinary(string op)(in float b)	const
			{ return mixin(q{multiplier %s b}.format(op)); } 
			float opBinaryRight(string op)(in float a)	const
			{ return mixin(q{a %s multiplier}.format(op)); } 
		} 
		
		
		//Todo: unittest nem megy. lehet, hogy az egesz projectet egyszerre kell forditani a DMD-ben?!!!
		//Todo: 'in' operator piros, de annak ciankeiknek kene lennie, mint az out-nak. Azazhogy helyzettol figg annak a szine
		
		
		auto calcLinearCoefficients(T1, T2, T3, T4 )(T1 x1, T2 y1, T3 x2, T4 y2)
		{
			auto m = safeDiv(y2 - y1, x2 - x1),
					 c = y1 - x1*m; 
			return tuple(m, c); //Todo: use this in remap
		} 
		
		struct SquaredByte
		{
			/+
				Note: This applies quadratic compression on a byte
				stored range: -128 .. 127
				unpacked range: -1.0 .. 1.0  (not inclusive at the end.)
			+/
			
			@STORED byte storage; 
			@property value() { return ((((float(storage))^^(2)))/(0x4000))*sign(storage); } 
			@property value(float f) { storage = cast(byte)(sqrt(abs(f)*0x4000)*sign(f)); } 
			alias value this; 
		} 
		
	}version(/+$DIDE_REGION+/all) {
		
		//Todo: remap goes to math
		
		T remap(alias srcFrom, alias srcTo, alias dstFrom, alias dstTo, T)(in T src)
		=> (cast(T)(((srcTo-srcFrom)?((src-srcFrom)*((dstTo-dstFrom)/(srcTo-srcFrom)) + dstFrom):(dstFrom)))); 
		
		T remap(T)(in T src, in T srcFrom, in T srcTo, in T dstFrom, in T dstTo)
		{ return src.remap!(srcFrom, srcTo, dstFrom, dstTo); } 
		
		template CommonFloatType(A...)
		{
			alias C = Unqual!(CommonType!A); 
			static if(__traits(isFloating, C))	alias CommonFloatType = C; 
			else	alias CommonFloatType = float; 
		} 
		
		T mapTo(alias dstFrom, alias dstTo, T)(in T src)
		{
			alias R = CommonFloatType!(typeof(dstFrom), typeof(dstTo), T); 
			return (cast(T)(dstFrom + (dstTo-dstFrom)*R(src))); 
		} 
		
		auto mapTo(Tfrom, Tto, T)(in T src, in Tfrom dstFrom, in Tto dstTo)
		=> src.mapTo!(dstFrom, dstTo); 
		
		//Todo: Decide what to return when input is NAN. Result is now NAN.
		T remap_clamp(T)(in T src, in T srcFrom, in T srcTo, in T dstFrom, in T dstTo)
		{ return clamp(remap(src, srcFrom, srcTo, dstFrom, dstTo), dstFrom, dstTo); } 
		
		int iRemap_clamp(T)(in T src, in T srcFrom, in T srcTo, in T dstFrom, in T dstTo)
		{ return cast(int)remap_clamp(src, srcFrom, srcTo, dstFrom, dstTo); } 
		
		//Todo: rewrite to greaterThan, lessThan
		bool isAscending	(T0, T1)(in T0 a, in T1 b)
		{ return a < b; } 
		
		bool isDescending	(T0, T1)(in T0 a, in T1 b)
		{ return a > b; } 
		
		bool isAscending	(T0, T1)(in T0 a, in T1 b, lazy bool chain=true)
		{ return a == b ? chain : a < b; } 
		
		bool isDescending	(T0, T1)(in T0 a, in T1 b, lazy bool chain=true)
		{ return a == b ? chain : a > b; } 
		
		auto alignUp	(T, U)(T p, U align_)
		{ return (p+(align_-1))/align_*align_; } 
		
		auto alignDown	(T, U)(T p, U align_)
		{ return p/align_*align_; } 
		
		bool chkSet(ref bool b)
		{
			if(b) return false; else { b = true	; return true; }
			//Todo: make it work with properties, bitfields
		} 
		
		bool chkClear(ref bool b)
		{ if(!b) return false; else { b = false; return true; }} 
		
		bool chkSet(T)(ref T a, T b)
		{ if(a==b) return false; else { a = b; return true; }} 
		
		auto returnThenSet(T, U)(ref T a, in U b)
		{
			auto res = a; 
			a = b; 
			return res; 
		} 
		
		void divMod(T)(in T a, in T b, out T div, out T mod)
		{
			div = a/b; 
			mod = a%b; 
		} 
		
		void sinCos(T)(T a, out T si, out T co)
		{
			si 	= sin(a); 
			co 	= cos(a); 
		} 
		
		T aSinCos(T)(T x, T y)
		{
			T d = x*x + y*y, res; 
			if(d==0) return 0; 
			if(d!=1) d = 1.0f/sqrt(d); 
			if(abs(x)<abs(y))
			{
				T res = acos(x*d); 
				if(y<0) res = -res + PI*2; 
			}
			else
			{
				res = asin(y*d); 
				if(x	<0) res = -res + PI; 
				if(res	<0) res =  res + PI*2; 
			}
			return res; 
		} 
		
	}version(/+$DIDE_REGION+/all) {
		
		int nearest2NSize(int size)
		{
			return size>0	? 2^^iceil(log2(size)) //Todo: slow
				: 0; 
		} 
		
		bool isPrime(uint num)
		{
			if(num == 2) return true; 
			if(num <= 1 || num % 2 == 0) return false; //0, 1, and all even numbers
			uint snum = cast(uint)sqrt(cast(double)num); 
			
			for(uint x = 3; x <= snum; x += 2)
			if(num % x == 0)
			return false; 
					
			return true; 
		} 
		
		//max |error| > 0.01
		float atan_fast(float x, float y)
		{
			const float ONEQTR_PI = PIf / 4.0f; 
			const float THRQTR_PI = 3.0f * PIf / 4.0f; 
			float r, angle; 
			float abs_y = abs(y) + 1e-10f;      //kludge to prevent 0/0 condition
			if(x < 0.0f) {
				r = (x + abs_y) / (abs_y - x); 
				angle = THRQTR_PI; 
			}else {
				r = (x - abs_y) / (x + abs_y); 
				angle = ONEQTR_PI; 
			}
			angle += (0.1963f * r * r - 0.9817f) * r; 
			if(y < 0.0f) return -angle; 
			else
			return  angle; 
			
		} 
		
		float peakLocation(float a, float b, float c, float* y=null)
		{
			NOTIMPL; //Todo: this is possibly buggy. must refactor.
			//Link: https://ccrma.stanford.edu/~jos/sasp/Quadratic_Interpolation_Spectral_Peaks.html
			auto 	d = (a-2*b+c),
				p = abs(d)<1e-4 ? 0 : 0.5f*(a-c)/d; 
			if(y) *y = b-0.25f*(a-c)*p; 
			return p; 
		} 
		
		//https://www.desmos.com/calculator/otwqwldvpj
		auto logCodec(bool encode, T, float digits, int max)(float x)
		{
			enum 	mul = (0.30101f*max)/digits,
				add = max/mul; 
			
			static if(encode)
			return cast(T)(iround((log2(x)+add)*mul).clamp(0, max)); 
			else
			return 2.0f^^(x*(1/mul)-add); 
		} 
		
		auto logEncode(T, float digits)(float	x)
		{ return logCodec!(true	, T, digits, T.max)(x); } 
		auto logDecode(T, float digits)(int	x)
		{ return logCodec!(false	, T, digits, T.max)(x); } 
		
		
		float ease(float in_=2, float out_=2)(float x)
		{ return (x^^in_)*(1-x)+(1-(1-x)^^out_)*x; } 
		
		//http://kodhus.com/easings/
		float easeInQuad	 (float t, float b, float c, float d)
		{ return c*(t/=d)*t + b; } 
		float easeOutQuad	 (float t, float b, float c, float d)
		{ return -c *(t/=d)*(t-2) + b; } 
		float easeInOutQuad(float t, float b, float c, float d)
		{
			if((t/=d/2) < 1) return c/2*t*t + b; 
			return -c/2 * ((--t)*(t-2) - 1) + b; 
		} 
		
		//https://github.com/jesusgollonet/ofpennereasing/blob/master/PennerEasing/Quad.cpp
		
		//http://vitiy.info/easing-functions-for-your-animations/
		float easeOutElastic(float t, float b, float c, float d)
		{
			//t: time elapsed from start of animation
			//b: start value
			//c: value change
			//d: duration of animation
			if(t==0) return b; 	if((t/=d)==1) return b+c;  
			float p=d*.3f; 	
			float a=c; 
			float s=p/4; 
			return (a*pow(2,-10*t) * sin((t*d-s)*(2*PIf)/p) + c + b); 
		} 
		
		//draws a slope, starts and ends it with sines transitioning to horizontal.
		auto easeSlope(float x, float slope, float trans, float shift)
		{
			const bump = 	x<0 	? 0 :
				x<trans 	? (x.remap(0, trans, -PIf, 0).cos.remap(-1, 1, 0, 1)) :
				x<1-trans 	? 1 :
				x<1	? (x.remap(1, 1-trans, -PIf, 0).cos.remap(-1, 1, 0, 1)) :
					  0; 
			const line = ((-.5f-x+1)*slope).remap(-.5f, .5f, 1, 0) + shift; 
			return mix(x<.5f ? 0 : 1, line, bump); 
			
			//Todo: Embedded testing  (graphical unit testing)
			/+
				auto slope = 0.1f, trans = 0.2f; 
				
				{
				Text("timeWarpFunction test."); 
				Text("Slope\t ", { Slider(slope, range(0, 0.9, 0.01), { width = 200; }); }); 
				Text("Transition\t ", { Slider(trans, range(0, 0.5, 0.01), { width = 200; }); }); 
				}
				
				const s = 11.2;
				dr.line(iota(0, s, 0.01f).map!(x => vec2(x, -(1-x/s).easeSlope(slope, trans)*s)).array); 
				
			+/
		} 
		
		unittest
		{
			string s; 
			foreach(j; 0..11)
			{
				auto i = j*255/10; 
				auto f = i.logDecode!(ubyte, 3); 
				s ~= format("%4d -> %8.5f -> %4d\r\n", i, f, f.logEncode!(ubyte, 5/*on purpose*/)); 
			}
					
			//digit count test
			static foreach(dig; 2..8)
			{
				{
					alias cfg = AliasSeq!(ubyte, dig); 
					s~= format("%d %f %f\r\n", dig, -log10(0.logDecode!cfg), 1.logDecode!cfg/0.logDecode!cfg); 
				}
			}
					
			assert(s.xxh==2704795724, "logEncoder/Decoder fucked up."); 
		} 
		
	}version(/+$DIDE_REGION Bitwise+/all)
	{
		//Bitwise //////////////////////////////////////////////
		
		public import core.bitop : rol, ror,
			bitCount	= popcnt	,
			bitSwap	= bitswap	,
			byteSwap	= bswap	,
			bitScan	= bsf	,
			bitScan_reverse	= bsr	; 
		
		ushort byteSwap(ushort a)
		{ return cast(ushort)((a>>>8)|(a<<8)); } 
		short byteSwap(short a)
		{ return cast(short)((a>>>8)|(a<<8)); } 
		
		wstring byteSwap(wstring s)
		{ return cast(wstring)((cast(ushort[])s).map!(c => cast(wchar)(c.byteSwap)).array); } 
		dstring byteSwap(dstring s)
		{ return cast(dstring)((cast(uint  [])s).map!(c => cast(dchar)(c.byteSwap)).array); } 
		
		bool getBit(T)(T a, size_t idx)
		{ return ((a>>idx)&1)!=0; } 
		T setBit(T)(T a, size_t idx, bool v=true)
		{ return cast(T)(a&~(cast(T)1<<idx)|(cast(T)v<<idx)); } 
		T clearBit(T)(T a, size_t idx)
		{ return setBit(a, idx, false); } 
		
		T getBits(T)(T a, size_t idx, size_t cnt)
		{ return (a>>idx)&((cast(T)1<<cnt)-1); } 
		T setBits(T)(T a, size_t idx, size_t cnt, T v) {
			T msk0 = (cast(T)1<<cnt)-1,
				msk = msk0<<idx; 
			return a&~msk|((v&msk0)<<idx); 
		} 
		
		T maskLowBits(T)(T a)
		{
			//Opt: slow
			foreach_reverse(i; 0..T.sizeof*8) if(a.getBit(i)) return (cast(T)1<<(i+1))-1; 
			return 0; 
		} 
		
		int countHighZeroBits(T)(T a)
		{
			//Opt: slow
			foreach_reverse(int i; 0..T.sizeof*8) if(a.getBit(i)) return cast(int)T.sizeof*8-1-i; 
			return T.sizeof*8; 
		} 
		
		T vec_sel	(T)(T a, T b, T c)
		{ return c &  a | ~c	& b; } //CAL style
		T bitselect	(T)(T a, T b, T c)
		{ return a & ~c |	b & c; } //OCL style
		T bfi	(T)(T a, T b, T c)
		{ return a &  b | ~a & c; } //GCN style
		
		auto bitalign(uint lo, uint hi, uint ofs)
		{ return cast(uint)((lo | (cast(ulong)hi<<32))>>ofs); } 
		
		
		uint hammondDist(uint a, uint b)
		{ return bitCount(a^b); } 
		
		int boolMask(in bool[] arr...)
		{ return arr.enumerate.map!(a => a.value<<a.index).sum; } 
		
		bool toggle(ref bool b)
		{ b = !b; return b; } 
		
		T negate(T)(ref T a)
		{ a = -a; return a; } 
		
		T binaryToGray(T)(T x)
		{ return x ^ (x >> 1); } 
		
		//?. optional chaining operator
		
		/+
			auto ifNotNull(alias fun, T)(T p)
			{
				if(p !is null) return unaryFun!fun(p); 
				else return typeof(return).init; 
			} 
			
			auto ifNotNull(alias fun, T, U)(T p, lazy U def)
			{
				if(p !is null) return unaryFun!fun(p); 
				else return def; 
			} 
		+/
	}
}version(/+$DIDE_REGION Arrays Ranges+/all)
{
	/// Arrays ops///////////////////////////////////////////////
	version(/+$DIDE_REGION+/all) {
		size_t sizeBytes(T)(in T a)
		{
			static if(isDynamicArray!T) return a.length * ElementType!T.sizeof; 
			else return T.sizeof; 
		} 
		
		void requireLength(T, L)(ref T[] arr, L len)
		{
			if(arr.length<len)
			arr.length = len; 
		} 
		
		@property auto frontOr(R, T)(R r, T e = ElementType!R.init)if(isInputRange!R)
		{
			return r.empty ? e : r.front; //Todo: constness
		} 
		@property auto backOr(R, T)(R r, T e = ElementType!R.init)if(isBidirectionalRange!R)
		{ return r.empty ? e : r.back; } 
		
		@property auto frontOrNull(R)(R r)if(isInputRange!R && is(ElementType!R==class))
		{
			return r.empty ? null : r.front; //Todo: constness
		} 
		@property auto backOrNull(R)(R r)if(isBidirectionalRange!R && is(ElementType!R==class))
		{ return r.empty ? null : r.back; } 
		
		auto fetchFront(T)(ref T arr, lazy ElementType!T def = ElementType!T.init)
		{
			static if(isInputRange!T)
			{
				if(arr.empty) return def; 
				auto res = arr.front; 
				arr.popFront; 
				return res; 
			}
			else static if(isDynamicArray!T)
			{
				if(arr.length) {
					auto res = arr[0]; 
					arr = arr[1..$]; 
					return res; 
				}else { return def; }
			}
			else static assert(0, "unhandled type"); 
		} 
		
		auto fetchFrontN(T)(ref T[] arr, sizediff_t count)
		{
			auto i = min(arr.length, count),
					 res = arr[0..i]; 
			arr = arr[i..$]; 
			return res; 
		} 
		
		auto fetchAll(T)(ref T[] arr)
		{
			auto res = arr; 
			arr = []; 
			return res; 
		} 
		
		string fetchStringZ(T)(ref T[] arr)
		{
			static assert(T.sizeof==1); 
			const len = arr.countUntil(0); 
			enforce(len>=0, "Unable to fetch zero terminated string. Run out of buffer."); 
			auto res = cast(string)arr.fetchFrontN(len); 
			arr.fetchFront; //fetch the zero
			return res; 
		} 
		
		auto fetchBack(T)(ref T arr, lazy ElementType!T def = ElementType!T.init)
		{
			static if(isInputRange!T)
			{
				if(arr.empty) return def; 
				auto res = arr.back; 
				arr.popBack; 
				return res; 
			}
			else static if(isDynamicArray!T)
			{
				if(arr.length) {
					auto res = arr.back; 
					arr = arr[0..$-1]; 
					return res; 
				}else { return def; }
			}
			else static assert(0, "unhandled type"); 
		} 
		
		auto fetchBackN(T)(ref T[] arr, sizediff_t count)
		{
			auto i = max(arr.length-count, 0),
					 res = arr[i..$]; 
			arr = arr[0..i]; 
			return res; 
		} 
		
		
		//make initialized static 1d, 2d, 3d arrays
		auto makeArray(T, size_t N, T val)()
		{
			T[N] result; 
			foreach(i; 0..N) element[i] = val; 
			return result; 
		} 
		
		auto makeArray2(T, size_t N, size_t M, T val)()
		{
			T[N][M] result; 
			foreach(j; 0..M) foreach(i; 0..N) result[j][i] = val; 
			return result; 
		} 
		
		auto makeArray3(T, size_t N, size_t M, size_t O, T val)()
		{
			T[N][M][O] result; 
			foreach(k; 0..O) foreach(j; 0..M) foreach(i; 0..N) result[k][j][i] = val; 
			return result; 
		} 
		
	}version(/+$DIDE_REGION+/all) {
		
		auto ifz(A, B)(A a, lazy B b)
		{ return a ? a : b; } 
		alias ifNull = ifz; 
		
		auto ife(A, B, C)(A a, B b, lazy C c)
		{ return a==b ? c : a; } 
		
		auto ifne(A, B, C)(A a, B b, lazy C c)
		{ return a!=b ? c : a; } 
		
		auto ifEmpty(A, B)(A a, lazy B b)
		=> ((a.empty)?(b):(a)); 
		
		//safe assoc array lookup
		
		//Todo: DIDE fails when opening object.d. It should know that's a system module.
		
		V get(K, V)(V[K] aa, K key)
		{
			return object.get(aa, key, V.init); 
			/+this is object.get()+/
		} 
		
		//safe array access
		//Note: inout(V) doesn't work with class[]: it says can't convert const(Class) to inout(Class)
		V get(V, I)(V[] arr, I idx)
			if(isIntegral!I)
		{
			enum def = V.init; 
			static if(isSigned!I)	return idx<arr.length && idx>=0 ? arr[idx] : def; 
			else	return idx<arr.length	? arr[idx] : def; 
		} 
		
		//Default can be a different type. In that case, result	will be converted
		D get(V, I, D)(V[] arr, I idx, lazy D	def)
			if(isIntegral!I)
		{
			static if(isSigned!I)	return idx<arr.length && idx>=0 ? arr[idx].to!D.ifThrown(def) : def; 
			else	return idx<arr.length ? arr[idx].to!D.ifThrown(def) : def; 
		} 
		
		//safe randomAccessRange access. The array overloads can not be omitted.  Overloading sometimes a myth.
		auto get(R, I)(R arr, I idx)
		if(isIntegral!I && isRandomAccessRange!R && !isArray!R)
		{
			enum def = ElementType!R.init; 
			static if(isSigned!I)	return idx<arr.length && idx>=0 ? arr[idx] : def; 
			else	return idx<arr.length	? arr[idx] : def; 
		} 
		
		D get(R, I, D)(R arr, I idx, lazy D def) 
		if(isIntegral!I && isRandomAccessRange!R && !isArray!R)
		{
			static if(isSigned!I)	return idx<arr.length && idx>=0 ? arr[idx].to!D.ifThrown(def) : def; 
			else	return idx<arr.length ? arr[idx].to!D.ifThrown(def) : def; 
		} 
		
		/+
			Todo: unittest    auto aa = ["cica": 5, "kutya": 10];
			writeln( aa.get("cica") );
			writeln( aa.get("haha") );
			writeln( aa.get("hehe",  99) );
		+/
		
		
		//safely get an element ptr
		auto getPtr(V, I)(inout(V[]) arr, I idx, lazy V* def = null) if(isIntegral!I)
		{
			static if(isSigned!I)
			return idx<arr.length && idx>=0 ? &arr[idx] : def; 
			else
			return idx<arr.length ? &arr[idx] : def; 
		} 
		
		//safely access and element, putting default values in front of it when needed
		ref V access(V)(ref V[] arr, size_t idx, lazy V def = V.init) if(isIntegral!I)
		{
			while(idx>=arr.length) arr ~= def; //optional extend
			return arr[idx]; 
		} 
		
		//safely set an array element, extending with extra elements if idx is too high
		void set(V)(ref V[] arr, size_t idx, V val, lazy V def = T.init)
		{ arr.access(idx, def) = val; } 
		
		//original dlang functionality: .clear removes all keys and values from associative array.
		
		void clear(T)(ref T[] a)
		{ a.length = 0; } 
		void clear(T)(ref T a)if(is(T==struct))
		{ a = T.init; } 
		
		//references cleared only if not null
		//For classes it's a BAD idea!!! It clears the reference only. Assign null instead!  void clear(T)(T  a)if(is(T==class )){ if(a) a.clear; }
		void clear(T)(T* a)if(is(T==struct))
		{ if(a) (*a).clear; } 
		
		//Note: clear for classes is not OK, because it can't clear protected fields. Solution: mixin ClassMixin_clear
		//void clear(T)(T cla)if(is(T==class)){ with(cla) foreach(f; FieldNameTuple!(T)) mixin("$ = $.init;".replace("$", f)); }
		mixin template ClassMixin_clear()
		{
			void clear()
			{
				foreach(f; FieldNameTuple!(typeof(this)))
				mixin("$ = $.init;".replace("$", f)); 
			} 
		} 
		
		auto nonNulls(R)(R r)
		{ return r.filter!"a"; } 
			
	}version(/+$DIDE_REGION+/all) {
		
		bool addIfCan(T)(ref T[] arr, in T item)
		{ if(arr.countUntil(item)<0) { arr ~= item; return true; }else return false; } 
		bool addIfCan(T)(ref T[] arr, in T[] items)
		{ bool res; foreach(const item; items) if(arr.addIfCan(item)) res = true; return res; } 
		
		bool toggle(T)(ref T[] arr, in T item)
		{
			const idx = arr.countUntil(item); 
			if(idx<0) { arr ~= item; return true; }else { arr = arr.remove(idx); return false; }
		} 
		
		bool removeIfCan(T)(ref T[] arr, in T item)
		{
			const idx = arr.countUntil(item); 
			if(idx>=0) { arr = arr.remove(idx); return true; }
			return false; 
		} 
		
		deprecated("fetchFirst, not popFirst!")
		{
			//Todo: This is dumb... There is also popFront...
			T popFirst(T)(ref T[] arr)
			{ auto res = arr[0]; arr = arr[1..$  ]; return res; } 
			T popLast(T)(ref T[] arr)
			{ auto res = arr.back; arr = arr[0..$-1]; return res; } 
					
			T popFirst(T)(ref T[] arr, T default_)
			{ if(arr.empty) return default_; return popFirst(arr); } 
			T popLast(T)(ref T[] arr, T default_)
			{ if(arr.empty) return default_; return popLast(arr); } 
		} 
		
		/// My version of associativeArray.update: Makes sur the thing is exists and lets it to modify. Returns true if already found.
		bool findAdd(K, V)(ref V[K] aa, in K key, void delegate(ref V) update)
		{
			auto p = key in aa; 
			if(p) {
				update(*p); 
				return true; 
			}else {
				V value; 
				update(value); 
				aa[key] = value; 
				return false; 
			}
		} 
		
		//converts an array to uint[], padding the end with a specified byte. ByteOrder is machine specific.
		uint[] toUints(in void[] data, ubyte filler=0)
		{
			import std.traits; 
			enum 	unitSize	= ElementType!(typeof(return)).sizeof; 
			const	dataLength	= data.length,
				extLength	= dataLength.alignUp(unitSize); 
			return cast(uint[])((cast(ubyte[])data) ~ [ubyte(0)].replicate(extLength - dataLength)); 
		} 
		
		
		T[]	withoutDuplicates(alias pred = "a", T)(in T[] arr)
		{
			/*
				auto getKey(in T item){ return unaryFun!pred(item); }
					
						bool[ReturnType!getKey] m;
						T[] res;
						auto app = appender(&res);
						foreach(item; arr){
							const key = getKey(item);
							if(key !in m){
								m[key] = true;
								app ~= item;
							}
						}
						return app[];
			*/
			
				auto getKey(in T item) { return unaryFun!pred(item); } 
			
				bool[ReturnType!getKey] m; 
				T[] res; 
				foreach(item; arr) {
				const key = getKey(item); 
				if(key !in m) {
					m[key] = true; 
					res ~= item; 
				}
			}
				return res; 
		} 
		
		
		/*
			 Ezek LDC-vel nem mennek!!!!
					void appendUninitializedReserved(T)(ref T[] arr, size_t N = 1) {
						auto length_p = cast(size_t*)(&arr);
						*length_p += N;
					}
					
					void appendUninitialized(T)(ref T[] arr, size_t N = 1) {
						arr.reserve(arr.length + N);
						auto length_p = cast(size_t*)(&arr);
						*length_p += N;
					}
		*/
		
		auto iota_closed(B, E, S)(B b, E e, S s)
		{
			static struct Stepper(T)
			{
				T b, e, s; //Bug: What if step<=0 or e<b
				@property empty() { return b>e; } 
				auto front() { return b; } 
				void popFront() { b += s; } 
				auto save() { return this; } 
			} 
			alias T = CommonType!(B, E, S); 
			return Stepper!T(b, e, s); 
			
			
			/+
				static if(isFloatingPoint!S) s = s.nextUp; 
				else s++; 
				return iota(b, e, s); 
			+/
		} 
	}version(/+$DIDE_REGION st R/W+/all)
	{
		//rather use bitmanip stuff!!!
		
		
		//st R/W //////////////////////////////////////////////
		
		
		T stRead(T)(ref ubyte[] st)
		{
			auto siz = T.sizeof; 
			enforce(st.length >= siz, "stRead: Out of stream."); 
			auto res = (cast(T[])st[0..siz])[0]; 
			st = st[siz..$]; 
			return res; 
		} 
		
		void stRead(T)(ref ubyte[] st, ref T res)
		{ res = stRead!T(st); } 
		
		
		T[] stReadArray(T)(ref ubyte[] st)
		{
			auto len = stRead!uint(st); 
			auto siz = len * T.sizeof; 
			auto res = cast(T[])st[0..siz]; 
			st = st[siz..$]; 
			return res; 
		} 
		
		uint stReadSize(ref ubyte[] st)
		{
			//This crap is for the opposite byte order!!!!!!!
			//read compressed 32bit
			auto b = stRead!ubyte(st); 
			if(b&0x80) {
				uint s = b & 0x3f | (stRead!ubyte(st)<<8); 
				if(b&0x40) return s |= (stRead!ushort(st)<<16); 
				return s; 
			}else return b; 
		} 
		
		void stWrite(T)(ref ubyte[] st, const T data)
		{
			/*
				auto siz = T.sizeof;
				ubyte* dst = st.ptr+st.length;
				st.length += siz;
				memcpy(dst, &data, siz);
			*/
					
			st ~= (cast(ubyte*)&data)[0..T.sizeof]; 
		} 
		
		void stWriteSize(ref ubyte[] st, const uint s)
		{
			//compressed 32bit
			if(s<0x80) stWrite(st, cast(ubyte)s); 
			else if(s<0x4000) stWrite(st, cast(ushort)s | 0x8000); 
			else if(s<0x4000_0000) stWrite(st, cast(ushort)s | 0xC000_0000); 
		} 
		
		void stWrite(T)(ref ubyte[] st, const T[] data)
		{
			stWrite(st, len); 
			foreach(const a; data) stWrite(st, data); 
		} 
		
		
		void byteArrayAppend(T)(ref ubyte[] st, const T data)
		{ st ~= (cast(ubyte*)&data)[0..T.sizeof]; } 
		
		auto toBytes(T)(ref T data)
		{ return (cast(ubyte*)&data)[0..T.sizeof]; } 
		
		
		//Todo: DIDE GotoError must show 5 lines up and down around the error.
	}version(/+$DIDE_REGION byLineBlock+/all)
	{
		//byLineBlock /////////////////////////////////////////////////
		
		enum 	DefaultLineBlockSize	=  1<<20,
			MaxLineBlockSeekBack 	= 16<<10; 
		
		struct FileBlock
		{
			//Todo: kiprobalni stdFile-val is, hogy gyorsabb-e
			File file; 
			size_t pos, size; 
			bool truncated; //The block is not on boundary, because it was unable to seek back
			
			auto read(bool mustExists=true) const
			{ return file.read	(mustExists, pos, size); } 
			auto readStr(bool mustExists=true) const
			{ return file.readStr(mustExists, pos, size); } 
		} 
		
		auto byLineBlock(File file, size_t maxBlockSize=DefaultLineBlockSize)
		{
			static struct TextFileBlockRange
			{
				File file; 
				size_t maxBlockSize, pos, size; 
						
				size_t actBlockSize; 
						
				bool empty() const
				{ return pos>=size; } 
						
				auto front()
				{
					if(actBlockSize) return FileBlock(file, pos, actBlockSize); //already fetched
							
					if(pos>=size) return FileBlock(file, size, 0); //eof
							
					auto remaining = size-pos; 
							
					if(remaining<=maxBlockSize)
					{ actBlockSize = remaining; }
					else
					{
						auto endPos = pos + maxBlockSize; 
						const	seekBackSize	= min(maxBlockSize/2, MaxLineBlockSeekBack), //max 16K-val vissza, de csak a block 50%-ig.
							seekBackLimit	= endPos-seekBackSize,
							stepSize	= min(256, seekBackSize); 
						while(endPos > seekBackLimit)
						{
							auto idx = file.read(false, endPos-stepSize, stepSize)
														 .retro.countUntil(0x0A); 
									
							if(idx>=0) {
								 //got a newline
								actBlockSize = (endPos-idx)-pos; 
								break; 
							}
									
							endPos -= stepSize; //try prev block...
						}
								
						if(!actBlockSize)
						{
							actBlockSize = maxBlockSize; 
							return FileBlock(file, pos, actBlockSize, true); //signal truncated with a true flag
							//INFO("Unable to seek to a newline. Using maxBlockLength");
									
						}
					}
							
					return FileBlock(file, pos, actBlockSize); 
				} 
						
				void popFront()
				{
					front; //make sure to seek
					pos += actBlockSize; 
					actBlockSize = 0; 
				} 
			} 
					
			assert(maxBlockSize>0); 
					
			auto res = TextFileBlockRange(file, maxBlockSize); 
			if(file.exists) { res.size = cast(size_t)(file.size); }else { WARN("File not found ", file); }
					
			return res; 
		} auto byLineBlock(string str, size_t maxBlockSize=DefaultLineBlockSize)
		{
			//Todo: egy kalap ala hozni a stringest meg a fileost
					
			static struct StringBlockRange
			{
				string str; 
				size_t maxBlockSize, pos; 
				auto size() const
				{ return str.length; } 
						
				size_t actBlockSize; 
						
				bool empty() const
				{ return pos>=size; } 
						
				auto front()
				{
					if(actBlockSize) return str[pos..pos+actBlockSize]; //already fetched
							
					if(pos>=size) return ""; 
							
					auto remaining = size-pos; 
							
					if(remaining<=maxBlockSize)
					{ actBlockSize = remaining; }
					else
					{
						auto endPos = pos + maxBlockSize; 
						const	seekBackSize	= min(maxBlockSize/2, MaxLineBlockSeekBack), //max 16K-val vissza, de csak a block 50%-ig.
							seekBackLimit	= endPos-seekBackSize,
							stepSize	= min(256, seekBackSize); 
						while(endPos > seekBackLimit)
						{
							auto idx = (cast(ubyte[])str[endPos-stepSize..endPos])
												 .retro.countUntil(0x0A); 
									
							if(idx>=0) {
								 //got a newline
								actBlockSize = (endPos-idx)-pos; 
								break; 
							}
									
							endPos -= stepSize; //try prev block...
						}
								
						if(!actBlockSize) {
							 //truncated block
							actBlockSize = maxBlockSize; 
						}
								
					}
							
					return str[pos..pos+actBlockSize]; 
				} 
						
				void popFront()
				{
					front; //make sure to seek
					pos += actBlockSize; 
					actBlockSize = 0; 
				} 
			} 
					
			assert(maxBlockSize>0); 
					
			auto res = StringBlockRange(str, maxBlockSize); 
					
			return res; 
		} /*
			void testByLineBlock(){
						auto file = File(tempPath, `testByLineBlocks.tmp`);
						scope(exit) file.remove;
					
						RNG rng;
						auto text = iota(10).map!(i => iota(rng(3)+(i==5 ? 30 : 2)).map!(j => j.text).join)
																.join("\r\n");
						text.saveTo(file);
					
						auto a = file.byLineBlock(12).map!readStr.array,
								 b = file.readStr.byLineBlock(12).array;
					
						//writeln("text\n", text);
					
						//writeln("a\n", a.join('|'));
						//writeln("b\n", b.join('|'));
					
						//writeln("a\n", a.map!"cast(ubyte[])a".array);
						//writeln("b\n", b.map!"cast(ubyte[])a".array);
					
						enforce(a.join == text, "file.byLineBlocks fail1");
						enforce(b.join == text, "string.byLineBlocks fail1");
						enum h = 3496071129;
						enforce(a.join('|').xxh == h, "file.byLineBlocks fail2");
						enforce(b.join('|').xxh == h, "string.byLineBlocks fail2");
					}
		*/
		
	}
	
}version(/+$DIDE_REGION RNG+/all)
{
	//RNG////////////////////////////////////
	version(/+$DIDE_REGION+/all)
	{
		struct RNG
		{
			auto seedStream = SeedStream_pascal(0x41974702); 
					
			ref uint seed()
			{ return seedStream.seed; } 
					
			void randomize(uint seed)
			{ this.seed = seed; } 
					
			void randomize()
			{
				long c; 
				QueryPerformanceCounter(&c); 
				c ^= thisThreadID; 
				seed = cast(uint)c*0x784921; 
			} 
					
			uint randomUint()
			{
				seedStream.popFront; 
				return seed; 
			} 
					
			int randomInt()
			{
				seedStream.popFront; 
				return int(seed); 
			} 
					
			float randomFloat()
			{
				seedStream.popFront; 
				return seed*0x1.0p-32; 
			} 
					
			uint random(uint n)
			{
				seedStream.popFront; 
				return (ulong(seed)*n)>>32; 
			} 
					
			int random(int n)
			{ return int(random(uint(n))); } 
					
			ulong random(ulong n)
			{
				if(n<=0xFFFF_FFFF) return random(cast(uint)n); 
				return (ulong(randomUint)<<32 | randomUint)%n; //terribly slow
			} 
			
			auto randomElement(T)(T t)
			{ return t[random(t.length)]; } 
			
			auto randomGaussPair()
			{
				float x1, x2, w; 
				do {
					x1 = randomFloat; 
					x2 = randomFloat; 
					w = x1*x1 + x2*x2; 
				}while(w>1); 
				w = sqrt((-2*log(w))/w); 
				return tuple(
					x1*w * ((seedStream.front&1)?-1:1), 
					x2*w * ((seedStream.front&2)?-1:1)
				); 
			} 
					
			auto randomGauss()
			{ return randomGaussPair[0]; } 
					
			void randomFill(uint[] values)
			{
				foreach(ref uint v; values)
				v = randomUint; 
			} 
					
			void randomFill(uint[] values, uint customSeed)
			{
				uint oldSeed = seed; 
				seed = customSeed; 
				randomFill(values); 
				seed = oldSeed; 
			} 
			
			T[] randomShuffle(T)(T[] arr)
			{
				auto idx = iota(arr.length).array; 
				foreach(i; 0..idx.length) swap(idx[i], idx[random(idx.length)]); 
				return idx.map!(i=>arr[i]).array; 
			} 
			
			//not good: disables default constructor. int opCall(int max){ return random(max); }
		} 
		
		RNG defaultRng; //Every thread get's its own, because of different QPC
		
		ref uint randSeed()
		{ return defaultRng.seed; } 
		void randomize(uint seed)
		{ defaultRng.randomize(seed); } 
		void randomize()
		{ defaultRng.randomize; } 
		uint random(uint n)
		{ return defaultRng.random(n); } 
		int random(int n)
		{ return defaultRng.random(n); } 
		ulong random(ulong n)
		{ return defaultRng.random(n); } 
		auto randomElement(T)(T t)
		{ return defaultRng.randomElement(t); } 
		uint randomUint()
		{ return defaultRng.randomUint; } 
		uint randomInt()
		{ return defaultRng.randomInt; } 
		float randomFloat()
		{ return defaultRng.randomFloat; } 
		auto randomGaussPair()
		{ return defaultRng.randomGaussPair; } 
		auto randomGauss()
		{ return defaultRng.randomGauss; } 
		void randomFill(uint[] values)
		{ defaultRng.randomFill(values); } 
		void randomFill(uint[] values, uint customSeed)
		{ defaultRng.randomFill(values, customSeed); } 
		T[] randomShuffle(T)(T[] arr)
		{ return defaultRng.randomShuffle(arr); } 
		
		
		/+
			 Wonder what's this crap?!!
					int getUniqueSeed(T)(in T ptr){ //gets a 32bit seed from a ptr and the current time
						long cnt;	QueryPerformanceCounter(&cnt);
						auto arr =	(cast(const void[])[ptr]) ~ (cast(const void[])[cnt]);
						return arr.xxh_internal;
					}
		+/
		
	}version(/+$DIDE_REGION+/all) {
		//a simple one from Delphi
		struct SeedStream
		{
			//https://en.wikipedia.org/wiki/Linear_congruential_generator
			uint a, c; 
			uint seed; //modulo = 2^32 only
					
			enum empty = false; //infinite range
			uint front() const
			{ return seed; } 
			void popFront()
			{ seed = seed * a + c; } 
					
			void test()
			{
				print("Testing SeedStream: a:", a, format!"(0x%x)"(a), "  c:", c, format!"(0x%x)"(c)); 
				BitArray ba; 
				ba.length = 1L << 32; 
						
				{
					auto s = this; s.seed=0; 
					print("First few values:", s.take(10).map!"a.to!string(10)".join(", ")); 
					print("             hex:", s.take(10).map!"a.to!string(16)".join(", ")); 
				}
						
				print("seed = ", seed); 
				ba[] = false; 
				auto ss = this; 
				auto act() { return ss.front; } 
				long cnt = 0; 
				while(!ba[act]) {
					ba[act] = true; 
					ss.popFront; 
					cnt++; 
					if((cnt & 0xFFFFFF)==0) write("\b\b\b", cnt>>24); 
				}
				print; 
				long firstZero = -1; foreach(idx, b; ba) if(!b) { firstZero = idx; break; }
				print("cycle length =", cnt.format!"0x%x", "  first false at:", firstZero); 
			} 
		} 
		
		SeedStream SeedStream_numericalRecipes(uint seed)
		{ return SeedStream(   1664525, 1013904223, seed); } 
		SeedStream SeedStream_pascal	       (uint seed)
		{ return SeedStream(0x8088405,	         1, seed); } 
		SeedStream SeedStream_borlandC	       (uint seed)
		{ return SeedStream(22695477,	         1, seed); } 
			
	}
}version(/+$DIDE_REGION Cryptography+/all)
{
	
	alias norx6441 = norx!(64, 4, 1); 
	
	struct norx(int w/*wordSize*/, int l/*loopCnt*/, int p/*parallelCnt*/)
	{
		//! norx /////////////////////////////////////
		version(/+$DIDE_REGION+/all) {
			private static: 
				static assert(w.among(32, 64) && l.inRange(1, 63) && p==1); 
			
				//word type	 ror offsets
				static if(w==32) { alias T = uint; 	 enum sh = [8, 11, 16, 31]; 	}
				static if(w==64) { alias T = ulong; 	 enum sh = [8, 19, 40, 63]; 	}
			
				enum t = w*4; 	//tagSize in bits
				enum r = T.sizeof*12; 	//S[0..12] size in bytes
			
				enum instance = format!"NORX%d-%d-%d"(w, l, p); 
			
				//some utils
			
				void fill(T)(T[] arr, T base=0)
			{ foreach(i, ref a; arr) a = cast(T)(i+base); } 
				string dump(in T[16] s)
			{ return format!"%(%.8X %)"(s); } 
			
			
				//low level functions
			
				void G(ref T a, ref T b, ref T c, ref T d)
			{
				import core.bitop : ror; 
						
				static T H(in T x, in T y)
				{ return (x^y)^((x&y)<<1);  } 
						
				a = H(a, b); 	 d = ror((d^a), sh[0]); 	 //aabdda
				c = H(c, d); 	 b = ror((b^c), sh[1]); 	 //ccdbbc
				a = H(a, b); 	 d = ror((d^a), sh[2]); 	 //aabdda
				c = H(c, d); 	 b = ror((b^c), sh[3]); 	 //ccdbbc
			} 
			
				void col(ref T[16] S)
			{
				static foreach(i; 0..4)
				G(S[0+i], S[4+i], S[8+i], S[12+i]); 
			} 
			
				void diag(ref T[16] S)
			{
				G(S[0], S[5], S[10], S[15]); 
				G(S[1], S[6], S[11], S[12]); 
				G(S[2], S[7], S[8], S[13]); 
				G(S[3], S[4], S[9], S[14]); 
			} 
			
				void F(int l, ref T[16] S)
			{ foreach(i; 0..l) { col(S); diag(S); }} 
			
				enum u = uCalc;  auto	uCalc()
			{ T[16] S;  fill(S); 	F(2, S);  return S; } 
			
				static assert(u[15] == (w==32 ? 0xD7C49104 : 0x86026AE8536F1501), "norx%d F() test failed".format(w)); 
			
				//high level functions
			
				const(void)[] pad(size_t len)(const(void)[] arr)
			{
				if(arr.length >= len) return arr; 
				ubyte[] e; e.length = len-arr.length; 
				e[0  ] |= 0x01; 
				e.back |= 0x80; 
				return arr ~ e; 
			} 
			
				T[4] prepareKey(in void[] K)
			{
				enum byteCnt = T[4].sizeof; 
						
				const(void)[] arr = K; //work on this slice
						
				if(arr.length > byteCnt) {
					 //longer than needed: set the last dword to the hast of the remaining part.
					uint hash = arr[byteCnt-4..$].xxh32; //Todo: ellenorizni ezt es az xxh-t is. Lehet, hogy le kene cserelni norx-ra.
					arr = arr[0..byteCnt-4] ~ cast(void[])[hash]; 
				}
						
				arr = pad!byteCnt(arr); //pad if smaller
						
				T[4] key;  key[] = (cast(T[])arr)[0..4]; 
				return key; 
			} 
			
		}version(/+$DIDE_REGION+/all) {
			private static: 
				T[16] initialize(in T[4] k, in T[4] n)
			{
				T[16] S = n ~ k ~ u[8..16]; 
				S[12..16] ^= [w, l, p, t].to!(T[])[]; 
				F(l, S); 
				S[12..16] ^= k[]; 
				return S; 
			} 
			
				void absorb(ref T[16] S, const(void)[] X, in T v/*domain constant*/)
			{
				for(; X.length; X = X[r..$]) {
					X = pad!r(X); 
							
					S[15] ^= v; 
					F(l, S); 
					S[0..12] ^= (cast(T[]) X[0..r])[]; 
				}
			} 
			
				ubyte[] encrypt(ref T[16] S, const(void)[] M, in T v/*domain constant*/)
			{
				void[] C; //ciphertext
				C.reserve(M.length); 
						
				for(; M.length; M = M[r..$]) {
					const blockLen = min(M.length, r); 
					S[15] ^= v; F(l, S); 
							
					if(blockLen == r)
					{
						S[0..12] ^= (cast(T[]) M[0..r])[]; 
						C ~= (cast(void[]) S)[0..r]; 
					}
					else
					{
						M = pad!r(M); 
						S[0..12] ^= (cast(T[]) M[0..r])[]; 
						C ~= (cast(void[]) S)[0..blockLen]; 
					}
				}
						
				return cast(ubyte[])C; 
			} 
			
				ubyte[] decrypt(ref T[16] S, const(void)[] C, in T v/*domain constant*/)
			{
				enum r = T.sizeof*12; 
						
				void[] M; //reconstructed message
				M.reserve(C.length); 
						
				while(C.length) {
					const blockLen = min(C.length, r); 
					S[15] ^= v; F(l, S); 
							
					if(blockLen == r)
					{
						//full block
						S[0..12] ^= (cast(T[])C[0..r])[]; 
						M ~= S[0..12]; 
						S[0..12] = (cast(T[])C[0..r])[]; 
					}
					else
					{
						auto MLast = (cast(ubyte[]) S[])[0..blockLen].dup;  //Todo: ez qrvalassu
						MLast[] ^= (cast(ubyte[])C)[0..blockLen]; 
						M ~= MLast; 
						S[0..12] ^= (cast(T[]) pad!r(MLast))[]; 
					}
							
					C = C[blockLen..$]; 
				}
						
				return cast(ubyte[])M; 
			} 
			
				ubyte[] finalize(ref T[16] S, in T[4] k, in T v/*domain constant*/)
			{
				S[15] ^= v; 
				F(l, S); 
				S[12..16] ^= k[]; 
				F(l, S); 
				S[12..16] ^= k[]; 
				return (cast(ubyte[]) S)[$-(t/8)..$].dup;  //kibaszott dup nagyon kell ide
			} 
			
				auto testVector()
			{
				struct Res {
					ubyte[4*T.sizeof] K, N; 
					ubyte[128] A, M, Z; 
				} 
				Res res; 
				with(res) {
					fill(K); 
					fill(N, 0x20); 
					fill(A); 
					fill(M); 
					fill(Z); 
				}
				return res; 
			} 
			
		}version(/+$DIDE_REGION+/all) {
			private static: 
				auto crypt(bool doTests=false, bool doDecrypt=false)(const(void)[] K, const(void)[] N, const(void)[] A, const(void)[] M, const(void)[] Z)
			{
						
				static void test(int idx, string caption, T, string file=__FILE__, int line=__LINE__)(const T[] a)
				{
					static if(doTests)
					{
						string expected; 
						static if(instance=="NORX32-4-1")
						{
							expected = 
							[
								"7DD54975 C374FFC8 1DF66F83 08CEF7E9 CA5295E8 8E1E6324 538244DA 3091DC5D 5288E900 EDDAFB81 1A345AE0 933EC3AB BED76EB5 8B64D948 A59BD31B 6BBBD034",
								"2DFDA46B 956D99E2 DE62A45D 59A4AD56 F9A5411A 759C0658 45CF1EA3 A9515464 60CCA3C1 A29F076D FAA12E42 EA22ED90 7D10BA9D 407E2C5B 97DC4FA4 80401262",
								"9769850C 41240274 A264E03A B808815A 9285A6D3 8665C774 ED279CE2 9571FB11 F39624ED 3DCE8561 81879FF2 45B5E234 10D6694E AFF8A691 9991AECE BFFA4576",
								"BBAB2C4A 42BF34A5 3AD53DFA AF184F4D 66A33356 481AAE25 471E110F 9FBC7740 33A4CBDB 5CA77A41 ABCDF216 1A213FE2 353816EC 8EFF5ABE 3FB2298B E4A9EC82",
								"97537D63 63AC168C 6CEF0F5B EC0114E9 D6A022EC FF4395E0 4F29B8B5 B8CC8998 D92C5C49 74BA3CEF 964EEDD3 23DF1024 BCE454D5 89B75B6B EA597754 47CFFFCD",
								"6C E9 4C B5 48 B2 0F ED 7B 68 C6 AC 60 AC 4C B5 EB B1 F0 9A EC 5A 75 0E CF 50 EC 0E 64 93 8B F2 40 17 A4 FF 06 84 F8 08 A6 7C 19 6C 31 A0 AF 12 56"
								~" 9B E5 F7 C5 6A D3 BC AC 88 DA 36 86 57 5F 93 43 96 8D A2 20 77 EE CC E7 D6 63 17 49 08 A3 F7 3C 9E 9A C1 49 B5 CE 6B E6 9C 9E 31 7C D7 E7 E8 0C"~
								" 85 69 97 74 02 24 41 3A E0 64 A2 5A 81 08 B8 D3 A6 85 92 74 C7 65 86 E2 9C 27 ED 11 FB 71 95",
								"D5 54 E4 BC 6B 5B B7 89 54 77 59 EA CD FF CF 47"
							][idx]; 
						}
						else static if(instance=="NORX64-4-1")
						{
							expected = 
							[
								"ED1C05E4E034B18B A98C191C6015FA6D 288C3313ACF5E185 94E37DCA8C2B520F 841D5FBE319581DE 6BA9AE4E997C10DF 9ACC31C63498AAB8 BC4F4AA085B8FAD9"~
								" 24A958D377B4FBBF 8DDB5DC488A3A710 7F776980AAA321EF 4D4C321A44EE66D9 C6439632673FBDC2 950244CDFEAEA45E EB8B0AFF16BEDBE0 68A7A80B2838111F",
								"07D9A7A131D4D6E0 5B60B0B0847E0416 57F3CB734EC314B3 F9CFDC4B605A6CCC 5E3F25A15BF57819 3501EA9EDDF5CC6C 69BAAF08D99F96C2 CF86E9721020F64E"~
								" 3352D33F5677CBC4 331C29A0674FEF14 CB74AFFFA9BD69D9 5810E32F833F0370 44C3442263959E68 522FC8BBFE971C48 4EC92E818EA35AD3 BB223CBC51462414",
								"A4461CDB6586E74B BDDF7652BF4F1AB0 DCF86684B8BFEB30 D870D0D016787A89 C5DC8F2CC92A2D60 404DE2D5457A5178 8A2475887B1ABF74 AD5BEFE2F99B111F"~
								" D258C60C34FC528A 69C0DA88A6C5CD25 3328D007C5C35CC3 3744B8E898EC83DD 70AB4D51F1570C40 5E3331A6663C18EE BA01BA7CFDF2C4BF 36FA274968BF8B0A",
								"B1B64376441A2AB0 2F5BE2578863D5EC 66F953E878E37E6B EEE236C48DEDFFEE 6778F573276FDF5F E3C3E60EDC6DB52D B0AAEFFFF4764978 2A0F46F39ED63CF1"~
								" A9C34DCB7057873C 594CC2D6E926D398 D85F144A45107F10 EE584A7C1D80E6D3 7B763E9FCBB1F9D3 9A55D3CAC654F97A 9308DF76F6D7995E 6D9E59C21CC59E3B",
								"45D70450C188B282 44CB44A8ACC7D823 6CF99985A76DD706 F76D93B792F90C83 BCB8EC0B3370F727 011728D02D035E19 CC7972F3E89E595A A75510060F10F800"~
								" D3314C7CDF7C4C99 52A16E0D4BD61F3C 4EA70ACD1A1F1D3A B56927EF60BB58D4 7623A30533FAF2D1 3F3089C9D1613AE2 E4175BA55A93BDBF 8E4073C4334725E7",
								"C0 81 6E 50 8A E4 A0 50 0B 93 38 7B BB AB C2 41 AC 42 38 7E F5 E8 BF 0E C3 82 6C ED E1 66 A1 D5 CA A3 E8 D6 2C D6 41 B3 FA F2 AA 2A DD E3"~
								" E5 ED 0A 13 BD 8B 96 D5 F0 FB 7F E3 9C A7 80 95 31 75 E2 45 BC 3E 53 4B 80 0E 96 46 77 1F 13 EA 40 85 CB 3E 26 7F 10 6F 5F 17 A0 64 FF 23 4A"~
								" 02 7C 64 4B E7 86 65 DB 1C 46 A4 B0 1A 4F BF 52 76 DF BD 30 EB BF B8 84 66 F8 DC 89 7A 78 16 D0 D0 70 D8",
								"D1 F2 FA 33 05 A3 23 76 E2 3A 61 D1 C9 89 30 3F BF BD 93 5A A5 5B 17 E4 E7 25 47 33 C4 73 40 8E"
							][idx]; 
						}
						else
						{
							WARN(instance ~ " is not covered by tests."); 
							return; 
						}
						auto actual = format("%(%."~(T.sizeof*2).text~"X %)", a); 
								
						enforceDiff(expected, actual, format!"Test failed %s %s"(instance, caption), file, line); 
					}
				} 
						
				struct Res {
					ubyte[] data; 
					ubyte[] tag; 
					alias data this; 
				} 
				Res res; 
						
				const k = prepareKey(K),
							n = prepareKey(N); 
				auto S = initialize(k, n); 	 test!(0, "S after initialize")(S); 
								 absorb  (S, A, 1); 	 test!(1, "S after header"    )(S); 
						
				static if(doDecrypt) { res.data  = decrypt (S, M, 2); }else { res.data  = encrypt (S, M, 2);  test!(2, "S after message"   )(S); }
						
									 absorb  (S, Z, 4); 	 test!(3, "S after trailer"	 )(S); 
				res.tag  = finalize(S, k, 8); 	 test!(4, "S after finalize"	 )(S); 
						
				if(doTests) {
					test!(5, "cipherText")(res.data); 
					test!(6, "tag"       )(res.tag); 
				}
						
				return res; 
			} 
			
		}version(/+$DIDE_REGION+/all) {
			public static: //public declarations ////////////////////////////////////
			
				auto encrypt(in void[] key, in void[] nonce, in void[] header, in void[] message, in void[] trailer)
			{ return crypt!(false, false)(key, nonce, header, message, trailer); } //Todo: tag checking
				auto decrypt(in void[] key, in void[] nonce, in void[] header, in void[] crypted, in void[] trailer)
			{ return crypt!(false, true )(key, nonce, header, crypted, trailer); } //Todo: tag checking
			
				//shorthands without header and trailer
				auto encrypt(in void[] key, in void[] nonce, in void[] message)
			{ return encrypt(key, nonce, [], message, []); } 
				auto decrypt(in void[] key, in void[] nonce, in void[] crypted)
			{ return decrypt(key, nonce, [], crypted, []); } 
			
				bool test()
			{
				const tv = testVector; 
				with(tv)
				{
					//do the detailed tests
					crypt!(true, false)(K, N, A, M, Z); 
							
					foreach(len; [48, 0, 128, 47, 49])
					{
						const X = M[0..len]; 
						auto enc = encrypt(K, N, X, X, X); 
						const Y = enc.data; 
						auto dec = decrypt(K, N, X, Y, X); 
								
						auto expected	= format("%(%.2X %)", X),
								 actual	= format("%(%.2X %)", dec.data); 
						enforceDiff(expected, actual, "Encrypt/Decrypt test failed. len=%d".format(len)); 
					}
							
				}
						
				//LOG("All tests \33\12passed\33\7.");
				return true; 
			} 
				
				void benchmark()
			{
				const MB = 100; 
				auto plainText = iota((1<<(20-2))*MB).array; 
				print("generated %d MiB data".format((plainText.length*plainText[0].sizeof) >> 20)); 
				auto t0 = QPS; 
				print("encoding"); 
				auto enc = norx!(64, 4, 1).encrypt("1234", "nonce", plainText); 
				auto t1 = QPS; 
				print("decoding"); 
				auto dec = norx!(64, 4, 1).decrypt("1234", "nonce", enc); 
				auto t2 = QPS; 
				print(plainText.xxh32); 
				auto t3 = QPS; 
				print(plainText.crc32); 
				auto t4 = QPS; 
				print("comparing"); 
				enforce(cast(ubyte[])plainText == cast(ubyte[])dec); 
							
				print("MB/s: enc:", MB/(t1-t0), "dec:", MB/(t2-t1), "xxh:", MB/(t3-t2), "crc32:", MB/(t4-t3)); 
			} 
			
				shared static this() { test; } 
				
		}
	} 
}version(/+$DIDE_REGION Signal processing+/all)
{
	//Signal processing /////////////////////////////
	version(/+$DIDE_REGION+/all) {
		version(/+$DIDE_REGION+/all) {
			struct SymmetricKernel(T)
			{ T[] value; alias value this; } 
			
			SymmetricKernel!float gaussKernel(float σ)
			{
				const N = (iround(σ*3)); if(N<=0) return SymmetricKernel!float([1]); 
				auto kernel = (mixin(求map(q{0<=x<N},q{},q{(exp(((-((x)^^(2)))/(2*((σ)^^(2))))))}))).array; 
				kernel[] *= ((1)/(kernel[0] + 2*kernel[1..$].sum)); /+
					more precise 
					discrete normalization
				+/
				
				return SymmetricKernel!float(kernel); 
			} 
			
			vec4 incrementalGaussKernelParams(float σ)
			{
				const N = (iround(σ*3)); if(N<=0) return vec4(1, 0, 0, 1); 
				auto g = vec4(((1)/(σ * (float((sqrt(2*π)))))), exp((-1)/(2 * ((σ)^^(2)))), 0, N); g.z = ((g.y)^^(2)); 
				return g; //N is stored in g.w
			} 
			
			auto incrementalGaussKernel(float σ)
			{
				/+
					Note: This version is for testing a GPU friendly algorithm, 
					that works without table lookups.
					/+
						Link: https://developer.nvidia.com/gpugems/gpugems3/
						part-vi-gpu-computing/chapter-40-incremental-computation-gaussian
					+/
				+/
				auto g = incrementalGaussKernelParams(σ); 
				const N = g.w; 
				auto kernel = (mixin(求map(q{0<=i<N},q{},q{auto tmp = g.x; g.xy *= g.yz; return tmp; }))).array; 
				return SymmetricKernel!float(kernel); 
			} 
			
			T[] convolve(string chn_="", T)(T[] signal, in SymmetricKernel!float kernel)
			{
				alias CT = ScalarType!T; 
				enum chn = chn_!="" ? chn_.withStarting('.') : ""; 
				const 	N = signal.length.to!int, 
					M = kernel.length.to!int; 
				
				auto read(int i)
				{ return mixin("signal[i]"~chn); } 
				
				auto combine(A)(int i, A a)
				{
					static if(isIntegral!CT)	auto b = (round(a)).vectorClampCast!CT; 
					else	alias b = a; 
					auto s = signal[i]; 
					mixin("s"~chn~"=b;"); 
					return s; 
				} 
				
				return mixin(求map(q{0<=i<N},q{},q{combine(i, mixin(求sum(q{-M<j<M},q{},q{kernel[(magnitude(j))] * read((i+j).clamp(0, N-1))})))})).array; 
			} 
			
			auto convolve(string chn="", E)(Image!(E, 2) img, in SymmetricKernel!float kernel)
			{ mixin(求each(q{pass=1},q{2},q{img = mixin(求map(q{line},q{img.columns},q{line.convolve!chn(kernel)})).image2D})); return img; } 
			
			float translateDeprecatedGaussParameter(int i)
			{
				//translated from old deprecated window size parameters to the commonly used 'phi' parameter
				if(i<3) return 0.333f; if(i<5) return 0.906f; if(i<7) return 1.042f; return 1.0565f; 
			} 
			
		}
		class ResonantFilter
		{
			//https://www.music.mcgill.ca/~gary/307/week2/filters.html
			float b0, b1, b2, a1,	a2; 
			float x, x1, x2, y, y1, y2; 
			
			this(float rate, float q)
			{
				reset; 
				setup(rate, q); 
			} 
			
			void	setup(float rate, float q)
			{
				//enforce(q.inRange(0, 1) && rate.inRange(0, 1));
				a1 = -2*q*cos(2*PIf*rate); 
				a2 = q^^2; 
				b0 = (1-a2)*.5f; 
				b1 = 0; //Todo: opt for b1
				b2 = -b0; 
			} 
			
			void reset(float val=0)
			{
				x=x1=x2=val; 
				y=y1=y2=0; 
			} 
			
			float process(float newX)
			{
				x2 = x1; 	y2 = y1; 
				x1 = x; 	y1 = y; 
				x = newX; 	y = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2; 
				return y; 
			} 
			
			float[] process(T)(in T[] data)
			{
				if(data.empty) return []; 
				reset(data[0]); 
				float[] res; 
				foreach(d; data) res ~= process(d); 
				return res; 
			} 
		} 
			
	}version(/+$DIDE_REGION+/all) {
		
		T[] derived(T)(in T[] arr)
		{
			//Todo: this should be a map function, not something that allocates
			if(arr.empty) return []; 
			T[] res; res.reserve(arr.length); 
			T last = arr[0]; 
			foreach(a; arr) {
				res ~= a-last; 
				last = a; 
			}
			return res; 
		} 
		
		struct IdxValuePair(T)
		{ int idx; T value=0; } 
		
		auto zeroCrossings(T, bool positive=true, bool negative=true)(in T[] arr, T minDelta=0)
		{
			alias IV = IdxValuePair!T; 
			IV[] res; 
			foreach(i; 0..arr.length.to!int-1)
			{
				static if(positive) {
					if(arr[i]<=0 && arr[i+1]>0)
					{
						auto d = arr[i+1]-arr[i]; 
							if(d>=minDelta) res ~= IV(i, d); 
					}
				}
				static if(negative) {
					if(arr[i]>=0 && arr[i+1]<0)
					{
						auto d = arr[i+1]-arr[i]; 
						if(-d>=minDelta) res ~= IV(i, d); 
					}
				}
			}
			return res; 
		} 
		
		auto zeroCrossings_positive	(T)(in T[] arr, T minDelta=0)
		{ return zeroCrossings!(T, true, false)(arr, minDelta); } 
		auto zeroCrossings_negative	(T)(in T[] arr, T minDelta=0)
		{ return zeroCrossings!(T, false, true)(arr, minDelta); } 
		
		
		public import std.algorithm : mean; 
		auto mean(R)(R r)
		if(isInputRange!R && !isNumeric!(ElementType!R))
		{
			//Note: this version adds an automatic seed for user types: T.init
			return std.algorithm.mean(r, ElementType!R.init); 
		} 
		
		
		///	returns 1.0 if all bytes are the same
		//common values: 0.5 for d source files, 0.25 for .exe, 0.05 for jpg, zip, below 0.01 for png
		float calcRedundance(in void[] data)
		{
			int[8] bins; 
					
			foreach(b; cast(ubyte[])data)
			foreach(i; 0..8)
			bins[i] += (b>>i)&1; 
					
			auto invLen = 1.0f / data.length.to!int; 
					
			return sqrt(bins[].map!(b => sqr(b*invLen-0.5f)).sum * 0.5f); 
		} 
		
		
		auto stdDev(R)(R a)
		{
			auto	n	= a.length,
				avg	= a.sum / n,
				var	= reduce!((a, b) => a + pow(b - avg, 2) / n)(0.0f, a),
				sd	= sqrt(var); 
			return sd; 
		} 
		
		//Todo: FFT for double precision.
		
		T bitReverse(T)(T x, uint log2n)
		{
			T n; 
			foreach(i; 0..log2n)
			{
				n <<= 1; 
				n |= (x & 1); 
				x >>= 1; 
			}
			return n; 
		} 
		
		void fft(F)(in Complex!F[] a, Complex!F[] b, int log2n)
		{
			if(false && log2n==6)
			{
				{
					b[0]=a[0]; b[1]=a[32]; b[2]=a[16]; b[3]=a[48]; b[4]=a[8]; b[5]=a[40]; b[6]=a[24]; b[7]=a[56]; b[8]=a[4]; b[9]=a[36]; b[10]=a[20]; b[11]=a[52]; b[12]=a[12]; b[13]=a[44]; b[14]=a[28]; b[15]=a[60]; 
					b[16]=a[2]; b[17]=a[34]; b[18]=a[18]; b[19]=a[50]; b[20]=a[10]; b[21]=a[42]; b[22]=a[26]; b[23]=a[58]; b[24]=a[6]; b[25]=a[38]; b[26]=a[22]; b[27]=a[54]; b[28]=a[14]; b[29]=a[46]; b[30]=a[30]; 
					b[31]=a[62]; b[32]=a[1]; b[33]=a[33]; b[34]=a[17]; b[35]=a[49]; b[36]=a[9]; b[37]=a[41]; b[38]=a[25]; b[39]=a[57]; b[40]=a[5]; b[41]=a[37]; b[42]=a[21]; b[43]=a[53]; b[44]=a[13]; b[45]=a[45]; 
					b[46]=a[29]; b[47]=a[61]; b[48]=a[3]; b[49]=a[35]; b[50]=a[19]; b[51]=a[51]; b[52]=a[11]; b[53]=a[43]; b[54]=a[27]; b[55]=a[59]; b[56]=a[7]; b[57]=a[39]; b[58]=a[23]; b[59]=a[55]; b[60]=a[15]; 
					b[61]=a[47]; b[62]=a[31]; b[63]=a[63]; 
				}
				void bf(size_t a0, size_t a1, ℂ f)
				{
					const t = b[a1]*f; 
					const u = b[a0]; 
					b[a0] = u+t; 
					b[a1] = u-t; 
				} 
				{
					bf(0,1, ℂ(1,0)); bf(2,3, ℂ(1,0)); bf(4,5, ℂ(1,0)); bf(6,7, ℂ(1,0)); bf(8,9, ℂ(1,0)); bf(10,11, ℂ(1,0)); bf(12,13, ℂ(1,0)); bf(14,15, ℂ(1,0)); bf(16,17, ℂ(1,0)); bf(18,19, ℂ(1,0)); bf(20,21, ℂ(1,0)); bf(22,23, ℂ(1,0)); bf(24,25, ℂ(1,0)); 
					bf(26,27, ℂ(1,0)); bf(28,29, ℂ(1,0)); bf(30,31, ℂ(1,0)); bf(32,33, ℂ(1,0)); bf(34,35, ℂ(1,0)); bf(36,37, ℂ(1,0)); bf(38,39, ℂ(1,0)); bf(40,41, ℂ(1,0)); bf(42,43, ℂ(1,0)); bf(44,45, ℂ(1,0)); bf(46,47, ℂ(1,0)); bf(48,49, ℂ(1,0)); 
					bf(50,51, ℂ(1,0)); bf(52,53, ℂ(1,0)); bf(54,55, ℂ(1,0)); bf(56,57, ℂ(1,0)); bf(58,59, ℂ(1,0)); bf(60,61, ℂ(1,0)); bf(62,63, ℂ(1,0)); bf(0,2, ℂ(1,0)); bf(4,6, ℂ(1,0)); bf(8,10, ℂ(1,0)); bf(12,14, ℂ(1,0)); bf(16,18, ℂ(1,0)); 
					bf(20,22, ℂ(1,0)); bf(24,26, ℂ(1,0)); bf(28,30, ℂ(1,0)); bf(32,34, ℂ(1,0)); bf(36,38, ℂ(1,0)); bf(40,42, ℂ(1,0)); bf(44,46, ℂ(1,0)); bf(48,50, ℂ(1,0)); bf(52,54, ℂ(1,0)); bf(56,58, ℂ(1,0)); bf(60,62, ℂ(1,0)); bf(1,3, ℂ(0,-1)); 
					bf(5,7, ℂ(0,-1)); bf(9,11, ℂ(0,-1)); bf(13,15, ℂ(0,-1)); bf(17,19, ℂ(0,-1)); bf(21,23, ℂ(0,-1)); bf(25,27, ℂ(0,-1)); bf(29,31, ℂ(0,-1)); bf(33,35, ℂ(0,-1)); bf(37,39, ℂ(0,-1)); bf(41,43, ℂ(0,-1)); bf(45,47, ℂ(0,-1)); bf(49,51, ℂ(0,-1)); 
					bf(53,55, ℂ(0,-1)); bf(57,59, ℂ(0,-1)); bf(61,63, ℂ(0,-1)); bf(0,4, ℂ(1,0)); bf(8,12, ℂ(1,0)); bf(16,20, ℂ(1,0)); bf(24,28, ℂ(1,0)); bf(32,36, ℂ(1,0)); bf(40,44, ℂ(1,0)); bf(48,52, ℂ(1,0)); bf(56,60, ℂ(1,0)); 
					bf(1,5, ℂ(0.7071068,-0.7071068)); bf(9,13, ℂ(0.7071068,-0.7071068)); bf(17,21, ℂ(0.7071068,-0.7071068)); bf(25,29, ℂ(0.7071068,-0.7071068)); bf(33,37, ℂ(0.7071068,-0.7071068)); bf(41,45, ℂ(0.7071068,-0.7071068)); bf(49,53, ℂ(0.7071068,-0.7071068)); 
					bf(57,61, ℂ(0.7071068,-0.7071068)); bf(2,6, ℂ(0,-1)); bf(10,14, ℂ(0,-1)); bf(18,22, ℂ(0,-1)); bf(26,30, ℂ(0,-1)); bf(34,38, ℂ(0,-1)); bf(42,46, ℂ(0,-1)); bf(50,54, ℂ(0,-1)); bf(58,62, ℂ(0,-1)); bf(3,7, ℂ(-0.7071068,-0.7071068)); 
					bf(11,15, ℂ(-0.7071068,-0.7071068)); bf(19,23, ℂ(-0.7071068,-0.7071068)); bf(27,31, ℂ(-0.7071068,-0.7071068)); bf(35,39, ℂ(-0.7071068,-0.7071068)); bf(43,47, ℂ(-0.7071068,-0.7071068)); bf(51,55, ℂ(-0.7071068,-0.7071068)); 
					bf(59,63, ℂ(-0.7071068,-0.7071068)); bf(0,8, ℂ(1,0)); bf(16,24, ℂ(1,0)); bf(32,40, ℂ(1,0)); bf(48,56, ℂ(1,0)); bf(1,9, ℂ(0.9238795,-0.3826835)); bf(17,25, ℂ(0.9238795,-0.3826835)); bf(33,41, ℂ(0.9238795,-0.3826835)); 
					bf(49,57, ℂ(0.9238795,-0.3826835)); bf(2,10, ℂ(0.7071068,-0.7071068)); bf(18,26, ℂ(0.7071068,-0.7071068)); bf(34,42, ℂ(0.7071068,-0.7071068)); bf(50,58, ℂ(0.7071068,-0.7071068)); bf(3,11, ℂ(0.3826833,-0.9238796)); bf(19,27, ℂ(0.3826833,-0.9238796)); 
					bf(35,43, ℂ(0.3826833,-0.9238796)); bf(51,59, ℂ(0.3826833,-0.9238796)); bf(4,12, ℂ(0,-1)); bf(20,28, ℂ(0,-1)); bf(36,44, ℂ(0,-1)); bf(52,60, ℂ(0,-1)); bf(5,13, ℂ(-0.3826836,-0.9238794)); bf(21,29, ℂ(-0.3826836,-0.9238794)); 
					bf(37,45, ℂ(-0.3826836,-0.9238794)); bf(53,61, ℂ(-0.3826836,-0.9238794)); bf(6,14, ℂ(-0.7071068,-0.7071068)); bf(22,30, ℂ(-0.7071068,-0.7071068)); bf(38,46, ℂ(-0.7071068,-0.7071068)); bf(54,62, ℂ(-0.7071068,-0.7071068)); 
					bf(7,15, ℂ(-0.9238796,-0.3826831)); bf(23,31, ℂ(-0.9238796,-0.3826831)); bf(39,47, ℂ(-0.9238796,-0.3826831)); bf(55,63, ℂ(-0.9238796,-0.3826831)); bf(0,16, ℂ(1,0)); bf(32,48, ℂ(1,0)); bf(1,17, ℂ(0.9807853,-0.1950903)); 
					bf(33,49, ℂ(0.9807853,-0.1950903)); bf(2,18, ℂ(0.9238794,-0.3826834)); bf(34,50, ℂ(0.9238794,-0.3826834)); bf(3,19, ℂ(0.8314695,-0.5555702)); bf(35,51, ℂ(0.8314695,-0.5555702)); bf(4,20, ℂ(0.7071068,-0.7071068)); 
					bf(36,52, ℂ(0.7071068,-0.7071068)); bf(5,21, ℂ(0.55557,-0.8314695)); bf(37,53, ℂ(0.55557,-0.8314695)); bf(6,22, ℂ(0.3826832,-0.9238794)); bf(38,54, ℂ(0.3826832,-0.9238794)); bf(7,23, ℂ(0.1950901,-0.9807851)); bf(39,55, ℂ(0.1950901,-0.9807851)); 
					bf(8,24, ℂ(0,-1)); bf(40,56, ℂ(0,-1)); bf(9,25, ℂ(-0.1950904,-0.9807849)); bf(41,57, ℂ(-0.1950904,-0.9807849)); bf(10,26, ℂ(-0.3826835,-0.9238791)); bf(42,58, ℂ(-0.3826835,-0.9238791)); bf(11,27, ℂ(-0.5555702,-0.8314691)); 
					bf(43,59, ℂ(-0.5555702,-0.8314691)); bf(12,28, ℂ(-0.7071068,-0.7071068)); bf(44,60, ℂ(-0.7071068,-0.7071068)); bf(13,29, ℂ(-0.8314694,-0.5555697)); bf(45,61, ℂ(-0.8314694,-0.5555697)); bf(14,30, ℂ(-0.9238791,-0.3826829)); 
					bf(46,62, ℂ(-0.9238791,-0.3826829)); bf(15,31, ℂ(-0.9807848,-0.1950899)); bf(47,63, ℂ(-0.9807848,-0.1950899)); bf(0,32, ℂ(1,0)); bf(1,33, ℂ(0.9951847,-0.09801714)); bf(2,34, ℂ(0.9807853,-0.1950903)); bf(3,35, ℂ(0.9569403,-0.2902847)); 
					bf(4,36, ℂ(0.9238795,-0.3826835)); bf(5,37, ℂ(0.8819212,-0.4713967)); bf(6,38, ℂ(0.8314695,-0.5555702)); bf(7,39, ℂ(0.7730104,-0.6343933)); bf(8,40, ℂ(0.7071068,-0.7071068)); bf(9,41, ℂ(0.6343932,-0.7730104)); bf(10,42, ℂ(0.5555701,-0.8314696)); 
					bf(11,43, ℂ(0.4713966,-0.8819212)); bf(12,44, ℂ(0.3826833,-0.9238794)); bf(13,45, ℂ(0.2902846,-0.9569402)); bf(14,46, ℂ(0.1950902,-0.9807852)); bf(15,47, ℂ(0.09801706,-0.9951846)); bf(16,48, ℂ(0,-1)); bf(17,49, ℂ(-0.09801719,-0.9951846)); 
					bf(18,50, ℂ(-0.1950904,-0.9807851)); bf(19,51, ℂ(-0.2902847,-0.9569402)); bf(20,52, ℂ(-0.3826835,-0.9238794)); bf(21,53, ℂ(-0.4713967,-0.8819211)); bf(22,54, ℂ(-0.5555702,-0.8314694)); bf(23,55, ℂ(-0.6343933,-0.7730103)); 
					bf(24,56, ℂ(-0.7071068,-0.7071068)); bf(25,57, ℂ(-0.7730104,-0.6343931)); bf(26,58, ℂ(-0.8314695,-0.55557)); bf(27,59, ℂ(-0.8819212,-0.4713965)); bf(28,60, ℂ(-0.9238794,-0.3826832)); bf(29,61, ℂ(-0.9569402,-0.2902845)); 
					bf(30,62, ℂ(-0.9807851,-0.1950901)); bf(31,63, ℂ(-0.9951845,-0.09801695)); 
				}
			}
			else
			{
				/+Link: https://www.sanfoundry.com/cpp-program-compute-discrete-fourier-transform-using-fast-fourier-transform-approach+/
				const J = Complex!F(0, 1); 
				int n = 1 << log2n; 
				for(uint i = 0; i < n; ++i)
				{ b[bitReverse(i, log2n)] = a[i]; }
				
				for(int s = 1; s <= log2n; ++s)
				{
					int m = 1 << s; 
					int m2 = m >> 1; 
					auto w = Complex!F(1, 0); 
					auto wm = exp(-J * (PI / m2)); 
					for(int j = 0; j < m2; ++j)
					{
						for(int k = j; k < n; k += m)
						{
							auto t = w * b[k + m2]; 
							auto u = b[k]; 
							b[k] = u + t; 
							b[k + m2] = u - t; 
						}
						w *= wm; 
					}
				}
			}
		} 
		
		void test_fft()
		{
			//Todo: this must be a selftest at startup
			
			alias cx = Complex!float; 
			
			cx[] a = [cx(0, 0), cx(1, 1), cx(3, 3), cx(4, 4), cx(4, 4), cx(3, 3), cx(1, 1), cx(0, 0)]; 
			cx[] b; b.length=8; 
			fft(a, b, 3); 
			b.each!writeln; 
			/+
				16+16i
				-4.82843-11.6569i
				0+0i
				-0.343146+0.828427i
				0+0i
				0.828427-0.343146i
				0+0i
				-11.6569-4.82843i
			+/
		} 
		
		auto fft(in ℂ[] a)
		{
			auto b = uninitializedArray!(ℂ[])(a.length); 
			fft(a, b, a.length.log2.itrunc); 
			return b; 
		} 
		
		auto fft(in float[] a)
		{
			//only real part is specified
			return a.map!ℂ.array.fft; 
		} 
		
		auto ifft(in ℂ[] a)
		{
			//Only returns the real part.
			return a.fft.map!(a=>a.re).array.fftFlip; 
			//Bug: a != a.fft.ifft  [1,2,1,2]->[4,8,4,8]    4x annyi es torzitva van, ha nem periodikus!!!!  Tukrozve is van!
		} 
		
		auto fftShift(uint sh=1, T)(in T[] a)
		{
			const mask = cast(uint)a.length-1>>sh; 
			return iota(a.length).map!(i=>cast()(a[i^mask])).array; 
		} 
		
		auto fftFlip(T)(in T[] a)
		{ return a.fftShift!0; } 
		
		auto fft(Image2D!(Complex!float) a)
		{
			auto 	b = image2D(a.size.x, a.size.y, Complex!float(0)),
				c = image2D(a.size.y, a.size.x, Complex!float(0)); 
			
			const log2size = a.size.log2.ifloor; 
			foreach(y; 0..a.height) fft(a.rows[y], b.rows[y], log2size.x); b = image2D(b.columns); 
			foreach(y; 0..b.height) fft(b.rows[y], c.rows[y], log2size.y); c = image2D(c.columns); 
			
			return c; 
		} 
		
		auto fft(Image2D!float img)
		{
			//only real part is specified
			return img.image2D!(a=>Complex!float(a)).fft; 
			//Opt: all imaginary value is 0
		} 
		
		auto ifft(Image2D!(Complex!float) img)
		{
			//It's for conjugate symmetric matrices. Only returns the real part.
			return img.fft.image2D!(a=>a.re).fftFlip; 
			//Opt: imaginary value is not used
			//Bug: Ez kozeppontosan tukrozve van! -> fftFlip
		} 
		
		auto fftShift(uint sh=1, F)(in Image!(F, 2) a)
		{
			const mask = a.size-1>>sh; 
			return image2D(a.size, iota2D(a.size).map!(p=>cast()(a[p^mask]))); 
		} 
		
		auto fftFlip(F)(in Image!(F, 2) a)
		{ return a.fftShift!0; } 
		
		
		
	}version(/+$DIDE_REGION+/all) {
		
		struct BinarySignalSmoother
		{
			private {
				int outSameCnt; 
				bool actOut, lastOut, lastIn; 
			} 
					
			bool process(bool actIn, int N=2)
			{
				if(outSameCnt>=N-1)
				actOut = lastIn!=actIn ? !actOut : actIn; 
						
				outSameCnt	= lastOut==actOut ? outSameCnt+1 : 0; 
				lastOut	= actOut; 
				lastIn  	= actIn; 
				return actOut; 
			} 
					
			@property bool output() const
			{ return actOut; } 
					
			static void selfTest(int N=2)()
			{
				//Todo: unittest
				BinarySignalSmoother bss; 
						
				const input = "..1.1.1..1.1.11.1.1..111111..11..111..111.1........1...11...1.11111111.1111.1"; 
				auto output = input.map!(c => bss.process(c=='1', N) ? '1' : '.').array; 
						
				writeln("----"); 
				writeln(input); 
				writeln(output); 
						
				BinarySignalSmootherNew!N bss2; 
				auto output2 = input.map!(c => bss2.process(c=='1') ? '1' : '.').array; 
				writeln(output2); 
			} 
		} 
		
		struct BinarySignalSmootherNew(int N)
		{
			//different algo, also slower
			private bool[N] input, output; 
					
			bool process(bool newInput)
			{
						
				enum N = 15; 
						
				input[] = newInput ~ input[0..$-1]; 
						
				const o1 = output[].all, o0 = !output[].any, oStable = o0 || o1; 
						
				bool newOutput; 
				if(oStable)
				{
					 //output is stable so it's possible to change it now
					const i1 = input[].all, i0 = !input[].any, iStable = i0 || i1; 
					newOutput = iStable 	? i1 	//input is stable, so update output
						: !output[0] 	/+input is diverging, just toggle the output on and off+/; 
				}
				else
				{ newOutput = output[0]; }
						
				output[] = newOutput ~ output[0..$-1]; 
						
				return newOutput; 
			} 
					
		} 
		
	}
}version(/+$DIDE_REGION Multithread+/all)
{
	auto futureFetch(alias fun, RT = ReturnType!fun)(RT* data = null)
	{
		__gshared RT[] queue; 
		
		RT[] res; 
		synchronized
		{
			if(data)
			{ queue ~= *data; }
			else
			{
				res = queue; 
				queue = []; 
			}
		} 	
		return res; 
	} 
	
	void future(alias fun, Args...)(Args args)
	{
		static void futureWrapper(alias fun, Args...)(Args args)
		{
			auto res = fun(args); 
			futureFetch!fun(&res); 
		} 
		
		taskPool.put(task!(futureWrapper!(fun, Args))(args)); 
	} 
	
	class MainThreadJob
	{
		/+
			Note: This can be used to implement the following:
			In a worker thread there are image processung stuff that 
			can only be done in the main thread inside the onPaint event.
			Implementation details for this example:
			   /+
				Code: onPaintJob = new MainThreadJob;
				...
				onPaint()
				{
					...
					onPaintJob.update;
					...
				}
			+/   /+
				Code: worker()
				{
					...
					onPaintJob({ process; });
					...
				}
			+/   
		+/
		
		private void delegate()[] queue; 
		
		//queue work and wait for it to finish.
		void opCall(void delegate() f)
		{
			synchronized(this) queue ~= f; 
			while(1)
			{
				sleep(3); 
				bool found; 
				synchronized(this) found = queue.canFind(f); 
				if(!found) break; 
			}
		} 
		
		//must call this periodically from the main thread
		void update()
		{
			synchronized(this)
			{
				void delegate() job; 
				if(queue.length)
				{
					job = queue.front; 
					job(); /+
						other requests will wait, but not a problem 
						because there is only one thread serving the queue
					+/
					queue.popFront; //it's also the signal to the caller
				}
			} 
		} 
	} 
	
	struct PROBE
	{
		string name; 
		bool logZeroOnExit; 
		
		static struct Event {
			DateTime when; 
			float value; 
			ubyte coreIdx; 
			this(float value)
			{
				when = now; 
				this.value = value; 
				coreIdx = cast(ubyte) GetCurrentProcessorNumber; 
			} 
		} 
		
		__gshared Event[][string] events, recordedEvents; 
		__gshared bool enabled; 
		
		static start()
		{
			synchronized(typeid(typeof(this)))
			{
				recordedEvents = null; 
				events = null; 
				enabled = true; 
			} 
		} 
		
		static stop()
		{
			synchronized(typeid(typeof(this)))
			{
				enabled = false; 
				recordedEvents = events; 
				events = null; 
				LOG(recordedEvents.length); 
			} 
		} 
		
		static void log(string name, float value)
		{
			if(!enabled) return; 
			synchronized(typeid(typeof(this)))
			{ events[name] ~= Event(value); } 
		} 
		
		/+
			+ Register an event which have a duration.
				It will log '1' immediatelly.
				Later when the scope exits, it will log '0'.
		+/
		static if(0)
		{
			this(string name)
			{
				this.name = name; 
				logZeroOnExit = true; 
				log(name, 1); 
			} 
			
			/// Register a current value for of name
			this(string name, float value)
			{ log(name, value); } 
		}
		else
		{
			static auto opCall(string name)
			{
				PROBE p; 
				p.name = name; 
				p.logZeroOnExit = true; 
				log(name, 1); 
				return p; 
			} 
			
			static void opCall(string name, float value)
			{ log(name, value); } 
		}
		~this()
		{
			if(logZeroOnExit)
			log(name, 0); 
		} 
		
		
	} 
}version(/+$DIDE_REGION ASM+/all)
{
	public import ldc.llvmasm; 
	public import core.simd : byte16, double2, float4, int4, long2, short8, ubyte16, uint4, ulong2, ushort8, void16,
	loadUnaligned,  prefetch, storeUnaligned, SimdVector = Vector /+Because there is het.math.Vector already defined.+/; 
	
	/+
		Note: Important note on SSE constants:
			/+Code: enum          ubyte16 a = [1, 2, 3];+/	⛔ It calculates BAD results!!!
			/+Code: static immutable ubyte16 a = [1, 2, 3];+/ 	⚠ It works, but the compiler crashes when used in pragma(msg).
		Possible workarounds:
			/+Code: mixin([1, 2, 3])+/ 	put the array literal inside mixin().
			/+Code: [1, 2, 3].dup+/	pass it through the std library. array(), dup() template functions will work.
		/+Link: https://forum.dlang.org/post/ekicvpjxpjwwsdallwnk@forum.dlang.org+/
	+/
	
	//Imported builtins ////////////////////////////////////////////
	
	mixin template asmFunctions()
	{
		//must import as a mixin, to enable inlining in each module. Az LTO sucks.
		
		//example: 	__asm("movl $1, $0", "=*m,r", &i, j);
		
		
		//public import ldc.gccbuiltins_x86 : pshufb	= __builtin_ia32_pshufb128; //note: this maps to signed bytes. I wand unsigneds for chars and for color channels.
		//byte16 pshufb(byte16 a, byte16 b){return __asm!ubyte16("pshufb $2, $1", "=x,0,x", a, b); }
		T pshufb(T, U)(T a, in U b) { return __asm!ubyte16("pshufb $2, $1", "=x,0,x", a, b); } 
		
		T palignr(ubyte im, T)(T a, in T b) { return __asm!ubyte16("palignr $3, $2, $1", "=x,0,x,i", a, b, im); } 
		
		//__builtin_ia32_pcmpestri128
		T pcmpestri(ubyte im, T)(T a, in T b) { return __asm!ubyte16("pcmpestri $3, $2, $1", "=x,0,x,i", a, b, im); } 
		
		//Todo: In old LDC 1.28   it generates a mask, but it's bad.  So I use this instead.
		ubyte16 pcmpeqb(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("pcmpeqb $2, $1", "=x,0,x", a, b); } 
		ubyte16 pmaxub(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("pmaxub $2, $1", "=x,0,x", a, b); } 
		ubyte16 pminub(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("pminub $2, $1", "=x,0,x", a, b); } 
		ubyte16 pavgb(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("pavgb $2, $1", "=x,0,x", a, b); } 
		
		ubyte16 punpcklbw(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("punpcklbw $2, $1", "=x,0,x", a, b); } 
		ubyte16 punpckhbw(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("punpckhbw $2, $1", "=x,0,x", a, b); } 
		ubyte16 punpcklwd(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("punpcklwd $2, $1", "=x,0,x", a, b); } 
		ubyte16 punpckhwd(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("punpckhwd $2, $1", "=x,0,x", a, b); } 
		ubyte16 punpckldq(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("punpckldq $2, $1", "=x,0,x", a, b); } 
		ubyte16 punpckhdq(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("punpckhdq $2, $1", "=x,0,x", a, b); } 
		ubyte16 punpcklqdq(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("punpcklqdq $2, $1", "=x,0,x", a, b); } 
		ubyte16 punpckhqdq(in ubyte16 a, in ubyte16 b) { return __asm!ubyte16("punpckhqdq $2, $1", "=x,0,x", a, b); } 
	} 
}

version(/+$DIDE_REGION Containers+/all)
{
	struct SparseArray(K, V, V Def=V.init)
	{
		//SparseArray ///////////////////////////////////////////////////////////
		version(/+$DIDE_REGION+/all) {
			//Todo: bitarray-ra megcsinalni a bool-t. Array!bool
			K[] keys; 
			V[] values; 
					
			V def = Def; //can overwrite if needed
					
			/*this(){ clear; }*/
					
			void clear()
			{ keys = []; values = []; } 
					
			auto get(int key) const
			{
				auto bnd = keys.assumeSorted.lowerBound(key+1); 
				return bnd.length ? values[bnd.length-1] : def; 
			} 
					
			void append_unsafe(in K key, in V value)
			{
				 //unsafe way to append
				keys	~= key; 
				values	~= value; 
			} 
					
			void set(in K key, in V value)
			{
				if(keys.length && key>keys.back)
				{
					//fast path: append or update the last value
					if(values.back != value) append_unsafe(key, value); 
					return; 
				}
						
				auto lo = keys.assumeSorted.lowerBound(key); 
				auto hi = keys[lo.length..$]; 
						
				if(hi.length && keys[$-hi.length] == key) hi = hi[1..$]; //if the key exists
						
				if(!lo.length ||	values[lo.length-1] !=	value)
				{
					//must insert value in the middle
					keys	= keys	[0..lo.length] ~ key	~ keys	[$-hi.length..$]; 
					values	= values[0..lo.length] ~ value	~ values[$-hi.length..$]; 
				}
				else
				{
					if(lo.length && hi.length && values[lo.length-1]==values[$-hi.length])
					{ hi = hi[1..$] /+the 2 side of the	hole is the same. Keep the left one only.+/; }
					keys	= keys  [0..lo.length] ~ keys	[$-hi.length..$]; 
					values	= values[0..lo.length] ~ values[$-hi.length..$]; 
				}
			} 
					
			auto opIndex(in K key) const
			{ return get(key); } 
			auto opIndexAssign(in V value, in K key)
			{ set(key, value); return value; } 
			auto opIndexOpAssign(string op)(in V value, in K key)
			{
				mixin("auto tmp = get(key) "~op~" value;"); 
				set(key, tmp); return tmp; 
			} 
			
			bool isCompact() const
			{
				foreach(i; 1..keys.length)
				if(keys[i-1]>=keys[i] || values[i-1]==values[i]) return false; 
						
				return true; 
			} 
					
			void compact()
			{
				if(isCompact) return; 
				
				K[] newKeys; newKeys  .reserve(keys.length); 
				V[] newValues; newValues.reserve(values.length); 
				K lastKey; 
				V lastValue; 
				
				void add(in	K k, in V v)
				{
					newKeys	~= k; lastKey	= k; 
					newValues	~= v; lastValue	= v; 
				} 
				
				add(keys[0], values[0]); 
						
				foreach(i; 1..keys.length)
				{
					const k = keys[i], v = values[i]; 
					if(k >= lastKey && v != lastValue)
					add(k, v); 
				}
				
				keys	= newKeys; 
				values	= newValues; 
			} 
			
			unittest
			{
				enum N = 5; 
				SparseArray!(int, ubyte) sa; 
				auto dump() { return iota(N).map!(i => sa[i].text).join; } 
							
				 assert(dump == "00000"); 
				sa[3] = 1; 	 assert(dump == "00011"); 
				sa[4] = 2; 	 assert(dump == "00012"); 
				sa[4] = 4; 	 assert(dump == "00014"); 
				sa[1] = 1; 	 assert(dump == "01114"); 
				sa[3] = 3; 	 assert(dump == "01134"); 
				sa[2] = 2; 	 assert(dump == "01234"); 
				sa[0] = 9; 	 assert(dump == "91234"); 
				sa[4] = 9; 	 assert(dump == "91239"); 
				sa[2] = 9; 	 assert(dump == "91939"); 
				sa[1] = 9; 	 assert(dump == "99939" && sa.isCompact); 
				sa[3] = 9; 	 assert(dump == "99999" && sa.isCompact); 
							
				sa.clear; 
				sa.append_unsafe(1, 1); 
				sa.append_unsafe(2, 1); 
				sa.append_unsafe(2, 3); 
				sa.append_unsafe(3, 3); 
				sa.append_unsafe(4, 3); 	 assert(!sa.isCompact); 
				sa.compact; 	 assert(sa.keys.equal([1, 2]) && sa.values.equal([1, 3])); 
			} 
		}
	} struct CircBuf(size_type, size_type cap)
	{
		//CircBuf class ///////////////////////////////////////////////////////////////
		version(/+$DIDE_REGION+/all) {
			//size_type: for debugClient communication, it must be 32bit because it communicates with debugClient
					
			size_type tail, head; 
			ubyte[cap] buf = void; 
					
			private auto truncate(size_type x) const
			{
				static if(cap&(cap-1))
				return x % cap; 
				else
				return x & (cap-1); 
			} 
					
			auto length()	const 
			{ return head-tail; } 
			bool empty()	const 
			{ return length==0; } 
			auto capacity()	const 
			{ return cap; } 
			auto canGet()	const 
			{ return length; } 
			auto canStore()	const 
			{ return capacity-length; } 
					
			bool store(void* src, size_type srcLen)
			{
				if(srcLen>canStore) return false; 
						
				auto o = head % capacity; 
				auto fullLen = srcLen; 
				if(o+srcLen>=capacity)
				{
					//multipart
					auto i = capacity-o; 
					memcpy(&(buf[o]), src, i); 
					o = 0; 
					src += i; 
					srcLen -= i; 
				}
				if(srcLen>0)
				{ memcpy(&(buf[o]), src, srcLen); }
						
				//advance in one step
				head += fullLen; //no atomic needed as one writes and the other reads
						
				return true; 
			} 
					
			bool store(void[] data)
			{ return store(data.ptr, cast(size_type)data.length); } 
			
			bool get(void* dst, size_type dstLen)
			{
				if(dstLen>canGet) return false; 
						
				auto o = truncate(tail); 
				auto fullLen = dstLen; 
				if(o+dstLen>=capacity)
				{
					//multipart
					auto i = capacity-o; 
					memcpy(dst, &(buf[o]), i); 
					o = 0; 
					dst += i; 
					dstLen -= i; 
				}
				if(dstLen>0)
				{ memcpy(dst, &(buf[o]), dstLen); }
						
				//advance in one step
				tail += fullLen; //no atomic needed as one writes and the other reads
						
				return true; 
			} 
					
			ubyte[] getBytes(size_type dstLen)
			{
				ubyte[] res; 
				if(dstLen>canGet) return res; 
				res.length = dstLen; 
				get(res.ptr, dstLen); 
				return res; //Todo: tail,head tulcsordulhat 4gb-nel!
			} 
			
			unittest
			{
				void doTest(uint N)()
				{
					CircBuf!(uint, N) cb; 
								
					RNG rng; 
					ubyte[] orig;  foreach(i;1..20) orig ~= cast(ubyte)i; 
					ubyte[] src = orig.dup, dst; 
					while(1)
					{
						if(src.empty && cb.empty) break; 
						//string s;
						if(random(2))
						{
							//store
							uint i = rng.random(min(cb.canStore+1, cast(uint)src.length+1)); 
							ubyte[] buf; 
							foreach(a; 0..i) { buf ~= src[0]; src = src[1..$]; }
							//s = format("PUT%s %-30s", i, to!string(buf));
							assert(cb.store(buf)); 
						}
						else
						{
							//get
							uint i = rng.random(cb.canGet+1); 
							auto buf = cb.getBytes(i); 
							assert(buf.length==i); 
							dst ~= buf; 
							//s = format("GOT%s %-30s", i, to!string(buf));
						}
						//writeln(s, cb);
					}
					assert(orig==dst, "Fatal Error in CircBuff."); 
				} 
							
				doTest!4; doTest!5; //test bo the & and the % case
			} 
		}
	} 
	
	class SafeQueue(T, bool multiSrc, bool multiDst)
	{
		struct Node { T data; Node* next; } 
		Node* head, tail; 
		
		this()
		{ head = tail = new Node; } 
		
		void put(T data)
		{
			auto node = new Node(data); 
			void doit()
			{
				tail.next = node; 
				tail = node; 
			} 
			static if(multiSrc) synchronized doit; else doit; 
		} 
		
		T* fetch()
		{
			T* res; 
			void doit()
			{
				if(auto newHead = head.next)
				{
					res = &newHead.data; 
					head = newHead; 
				}
			} 
			static if(multiDst) synchronized doit; else doit; 
			return res; 
		} 
		
		auto fetchAll()
		{
			//Opt: it could be optimized into a single syncronize block.
			T[] res; /+Not the fastest but it's synchronous.+/
			while(1) if(auto a = fetch) res ~= *a; else break; 
			return res; 
		} 
	} 
	
	alias SSQueue	(T) = SafeQueue!(T, 0, 0),
	MSQueue	(T) = SafeQueue!(T, 1, 0),
	SMQueue	(T) = SafeQueue!(T, 0, 1),
	MMQueue	(T) = SafeQueue!(T, 1, 1); 
	
	
	struct GroupByTime(T)
	{
		T[] queue; 
		DateTime lastT; 
		@property empty() const => queue.empty; 
		
		void put(T a)
		{ queue ~= a; lastT = now; } 
		
		void put(R)(R a) if(isInputRange!(R, T))
		{ if(a.empty) return; queue ~= a.array; lastT = now; } 
		
		bool canGet(Time minElapsedTime)
		{
			if(!queue.empty) {
				const Δt = now-lastT; 
				if(Δt>=minElapsedTime)
				return true; 
			}
			return false; 
		} 
		
		T[] get(Time minElapsedTime)
		{
			T[] res; 
			if(canGet(minElapsedTime))
			{ res = queue; queue = []; }
			return res; 
		} 
	} 
	
	
	version(/+$DIDE_REGION+/all)
	{
		class BigArray(T)
		{
			//BigArray //////////////////////////////////////////////////////////////////
			version(/+$DIDE_REGION+/all) {
					//Todo: a synchronizedet megcsinalni win32-re
				private: 
					struct Block {
					T[] data; 
					size_t idxSt, idxEn; 
				} 
					size_t length_; 
				
					File fileName_; 
					bool loading_; 
					Block[] blocks; 
					size_t blockSize; 
					bool doSeekForward; 
					T seekForwardUntil; 
				
					struct Slice { size_t st, en; } 
				
				public: 
					this(size_t blockSize_, const T seekForwardUntil_=T.init)
				{
					blockSize = blockSize_; 
					if(seekForwardUntil_!=T.init) {
						doSeekForward = true; 
						seekForwardUntil = seekForwardUntil_; 
					}
				} 
				
					File fileName() const
				{ return fileName_; } 
					bool loading() const
				{ return loading_; } 
				
					//modifications ////////////
					void appendBlock(T[] data)
				{
					if(data.empty) return; 
					auto newLen = length_ + data.length; 
					//blocks ~= shared(Block)(cast(shared T[])data, length_, newLen);
					blocks ~= Block(data, length_, newLen); 
					length_ = newLen; 
				} 
				
					void append(T[] data)
				{
					if(data.empty) return; 
								
					size_t len = data.length; 
								
					if(len>blockSize) {
						 //multiblock insert
						append(data[0..blockSize]); 
						append(data[blockSize..$]); 
						return; 
					}
								
					if(blocks.empty || blocks.back.data.length>=blockSize)
					{ appendBlock(data); }
					else
					{
						blocks.back.data ~= data; 
						blocks.back.idxEn += len; 
						length_ += len; 
					}
				} 
			}version(/+$DIDE_REGION+/all) {
				//array access ////////////
				size_t length()const
				{ return length_; } //Todo: gecilassu
				size_t opDollar()const
				{ return length_; } 
							
				Slice opSlice(int idx)(size_t st, size_t en)const
				{ return Slice(st, en); } 
							
				private auto findBlock(size_t idx)const
				{
					foreach(i, const b; blocks)
					if(idx>=b.idxSt && idx<b.idxEn)
					return i; 
					return -1; 
				} 
				private T getElement(size_t idx)const
				{
					auto i = findBlock(idx); 
					if(i>=0)
					with(blocks[i]) return data[idx-idxSt]; 
					else
					return T.init; 
				} 
							
				T opIndex(size_t idx)const
				{
					//Opt: cacheolni kene a poziciot es burst-ban nyomni
					enforce(idx<length); 
					return getElement(idx); 
				} 
							
				T[] opIndex(const Slice s)const
				{
					enforce(s.st<=s.en && s.en<=length_); 
					T[] res; 
					res.reserve(s.en-s.st); 
								
					size_t i = s.st; 
					while(i<s.en)
					{
						auto bi = findBlock(i); 
						with(blocks[bi])
						{
							auto st = i-idxSt; 
							auto en = min(s.en-idxSt, data.length); 
							res ~= data[st..en]; 
							i += en-st; 
						}
					}
					return res; 
				} 
							
				T[] opIndex()const
				{ return this[0..$]; } //all
			}version(/+$DIDE_REGION+/all) {
				///////////////////
				static _loader(/*shared */BigArray!T bt, bool delegate(float percent) onPercent=null)
				{
					StdFile f; 
					try
					{
						f.open(bt.fileName.fullName, "rb"); 
						ulong size = f.size,
									maxBlockSize = bt.blockSize*3/2,
									current; 
									
						while(1)
						{
							ulong toRead = maxBlockSize,
										remaining = size-f.tell; 
							if(remaining>maxBlockSize) toRead = bt.blockSize; 
							else toRead = remaining; 
							if(toRead>0)
							{
								auto data = f.rawRead(new T[cast(size_t)toRead]); 
											
								if(bt.doSeekForward && data.back!=bt.seekForwardUntil)
								{
									T[] extra; 
									char[1] buff; 
									while(!f.eof) {
										extra ~= f.rawRead(buff); 
										if(extra.back==bt.seekForwardUntil) break; 
									}
									data ~= extra; 
								}
											
								bt.appendBlock(data); 
								current += data.length*T.sizeof; 
											
								if(onPercent) { if(!onPercent(current.to!double/size*100)) break; }
											
							}
							else
							break; 
						}
									
						if(!size && onPercent) onPercent(100); 
									
					}
					catch(Throwable t) { showException(t); }
					//Todo: ez multithread miatt.
					
					bt._notifyLoaded; 
				} 
			}version(/+$DIDE_REGION+/all) {
				void _notifyLoaded()
				{
					loading_ = false; 
					//...something should connect here
				} 
							
				private void initLoad(File fileName)
				{
					enforce(!loading_,	format(`%s.load() already loading`    , typeof(this).stringof)); 
					enforce(fileName.exists,	format(`%s.load() file not found "%s"`, typeof(this).stringof, fileName)); 
					fileName_ = fileName; 
					loading_ = true; 
				} 
							
				void	loadLater(File fileName, bool delegate(float percent) onPercent=null)
				{
					//initLoad(fileName);
					//task!_loader(this, onPercent).executeInNewThread;
					loadNow(fileName, onPercent); 
				} 
							
				void loadNow(File fileName, bool delegate(float percent) onPercent=null)
				{
					initLoad(fileName); 
					_loader(this, onPercent); 
				} 
							
				void saveNow(string fileName)
				{
					enforce(!loading_, format(`%s.save() already loading`, typeof(this).stringof)); 
					StdFile f; //Todo: sima file-ra lecserelni
					f.open(fileName, "wb"); scope(exit) f.close; 
					foreach(ref b; blocks)
					f.rawWrite(cast(T[])b.data); 
				} 
							
				void dump()
				{ writeln(blocks.map!(b => format("%s", b.data.length)).join(", ")); } 
				
				bool waitFor(Time timeOut = 9999*second)
				{
					if(!loading) return true; 
					auto tMax = QPS+timeOut; 
					while(loading)
					{
						if(QPS>tMax) return false; //timeout
						sleep(1); 
					}
					return true; 
				} 
			}
		} 
		class BigStream_: BigArray!ubyte
		{
			//BigStream //////////////////////////////////////////////////////////////////////////
			this(size_t blockSize_ = 256<<10)
			{ super(blockSize_); } 
					
			private size_t position; 
					
			private ubyte[] rawRead(size_t len)
			{
				auto res = this[position..position+len]; 
				cast(size_t)position += len; 
				return res; 
			} 
					
			private void rawWrite(ubyte[] data)
			{
				//Todo: const-nak kene lennie...
				append(data); 
			} 
					
			T read(T)()
			{ return *cast(T*)rawRead(T.sizeof).ptr; } 
					
			T[] readArray(T)()
			{
				uint len = read!uint; 
				return cast(T[])rawRead(len*T.sizeof); 
			} 
					
			void write(T)(const T src)
			{
				T[] temp = [src]; //Todo: lame
				rawWrite(cast(ubyte[])temp); 
			} 
					
			void writeArray(T)(const T[] src)
			{
				write(cast(int)src.length); 
				rawWrite(cast(ubyte[])src); 
			} 
		} 
		
		alias BigText = /*shared*/ BigArray!char; 
		alias BigStream = /*shared*/ BigStream_; 
		
	}version(/+$DIDE_REGION ImStorage+/all)
	{
		//ImStorage ///////////////////////////////////////////////
		
		//Usage:  ImStorage!float.set(srcId!("module", 123)(genericArg!"id"(456)), newValue)  //this is the most complicated one
		
		/+
			ImStorageManager.purge(10);
					
			struct MyInt{ int value; }
			auto a = ImStorage!MyInt.access(srcId(genericArg!"id"("fuck"))).value++;
			if(inputs.Shift.down) ImStorage!int.access(srcId(genericArg!"id"("shit"))) += 10;
					
			print(ImStorageManager.detailedStats);
		+/
		
		
		interface ImStorageInfo {
			void purge(uint maxAge); 
					
			string name(); 
			string infoSummary(); 
			string[] infoDetails(); 
		} 
		
		struct ImStorageManager
		{
			static: 
			__gshared ImStorageInfo[string] storages; 
			
			void registerStorage(ImStorageInfo info)
			{ storages[info.name] = info; } 
			
			void purge(uint maxAge)
			{ storages.values.each!(s => s.purge(maxAge)); } 
			
			string stats(string details="")
			{
				string res; 
				foreach(name; storages.keys.sort)
				{
					const maskOk = name.isWild(details); 
					if(maskOk || details=="") res ~= storages[name].infoSummary ~ '\n'; 
					if(maskOk) res ~= storages[name].infoDetails.join('\n') ~ '\n'; 
				}
				return res; 
			} 
			
			string detailedStats() { return stats("*"); } 
		} 
		
		struct ImStorage(T)
		{
			static: 
			alias Id = SrcId; 
			
			struct Item {
				T data; 
				Id id; 
				uint tick; 
			} 
			
			Item[Id] items; //by Id
			
			void purge(uint maxAge)
			{
				 //age = 0 purge all
				uint limit = application.tick-maxAge; 
				auto toRemove = items.byKeyValue.filter!((a) => a.value.tick<=limit).map!"a.key".array; 
				toRemove.each!(k => items.remove(k)); 
			} 
			
			class InfoClass : ImStorageInfo
			{
				string name()
				{ return ImStorage!T.stringof; } 
				string infoSummary()
				{
					return format!("%s(count: %s, minAge = %s, maxAge = %s")(
						name, items.length,
						application.tick - items.values.map!(a => a.tick).minElement(uint.max),
						application.tick - items.values.map!(a => a.tick).maxElement(uint.min)
					); 
				} 
				string[] infoDetails()
				{ return items.byKeyValue.map!((in a) => format!"  age=%-4d | id=%18s | %s"(application.tick-a.value.tick, a.key, a.value.data)).array.sort.array; } 
				void purge(uint maxAge)
				{ ImStorage!T.purge(maxAge); } 
			} 
			
			auto ref access(in Id id, lazy T default_ = T.init)
			{
				auto p = id in items; 
				if(!p) {
					items[id] = Item.init; 
					p = id in items; 
					p.data = default_; 
					p.id = id; 
				}
				p.tick = application.tick; 
				return p.data; 
			} 
			
			void set(in Id id, T data)
			{ access(id) = data; } 
			
			bool exists(in Id id)
			{ return (id in items) !is null; } 
			
			uint age(in Id id)
			{ if(auto p = id in items) { return application.tick-p.tick; }else return typeof(return).max; } 
			
			//Todo: ez egy nagy bug: ha static this, akkor cyclic module initialization. ha shared static this, akkor meg 3 masodperc utan eled csak fel.
			//shared static this(){ ImStorageManager.registerStorage(new InfoClass); }
		} 
		
		
		///note: This has been moved here to avoid circular module initialization in uiBase
		ref auto imstVisibleBounds(in SrcId id)
		{ return ImStorage!bounds2.access(id.combine("VisibleBounds")); } 
		ref auto imstOuterBounds(in SrcId id)
		{ return ImStorage!bounds2.access(id.combine("OuterBounds")); } 
		//Todo: Fix this circular module initialization mess
		
	}class DynCharMap
	{
		private: 
			mixin CustomEnforce!"DynCharMap"; 
			//static void enforce(bool b, lazy string s, string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__){ if(!b) throw new Exception("DynCharMap: "~s, file, line, funct); }
		
			enum 	bankSh	= 5,
				bankSize	= 1<<bankSh,
				bankMask	= bankSize-1,
				invMapSize	= 1<<(21-bankSh),
				invMapMask	= invMapSize-1,	//unicode is 21 bits max
				maxBanks	= 0x200,	
				maxChars	= maxBanks<<bankSh;  	//max symbol count is limited
		
			//it keeps growing by 32 char banks
			ushort bankCnt; 
			ushort[maxBanks] map;   //tells the unicode bankIdx of a mapped bank. Bank0 is always mapped.
			ushort[invMapSize] invMap; //tells where to find the maps backwards
		
		public: 
			this()
		{
			//bank 0 is always needed to be mapped
			//map ascii charset, 128 chars
			bankCnt = 128/bankSize; 
			foreach(ushort i; 0..bankCnt) map[i] =i; 
			invMap[0..bankCnt] = map[0..bankCnt]; 
		} 
		
			override string toString()
		{
			return "DynCharMap(charCnt/Max=%d/%d, bankSize=%s, [%s])"	.format(
				(map[].count!"a!=b"(0)+1)<<bankSh,
				maxChars, 
				bankSize,
				map[].enumerate.filter!"a.value".map!(a => "%X:%X".format(a.index<<bankSh, a.value<<bankSh)).join(", ")
			); 
		} 
		
			ushort encode(dchar ch)
		{
			if(ch<0x80) return cast(ushort)ch; //fastpath... nem sokat gyorsit, simd kene
				
			ushort uniBank = (cast(uint)ch)>>>bankSh; 
			if(uniBank>0) {
				if(!invMap[uniBank]) {
					enforce(bankCnt < maxBanks, "Ran out of banks."); 
					invMap[uniBank] = bankCnt; 
					map[bankCnt] = uniBank; 
					bankCnt++; 
						
					//writefln("Bank %.6x mapped to %.2x", map[bankCnt-1] << bankSh, bankCnt-1 << bankSh);
				}
			}
			return cast(ushort)(invMap[uniBank]<<bankSh | (cast(ushort)ch)&bankMask); 
		} 
		
			dchar decode(const ushort ch)
		{
			if(ch<0x80) return cast(ushort)ch; //fastpath... nem sokat gyorsit, simd kene
				
			ushort mapBank = ch>>bankSh; 
			ushort uniBank = map[mapBank & maxBanks-1]; 
			return cast(dchar)((uniBank<<bankSh) | ch & bankMask); 
		} 
		
			private enum utfInvalidCode = 0xFFFD; //replacement char
		
			auto encodeUTF8(ref ushort[] res, string s)
		{
			import std.encoding; 
			//Todo: ez bugos
			while(s.length>=8) {
				auto raw = cast(ulong*)s.ptr; 
				if(*raw & 0x80808080_80808080)
				{
					//slow decode
					foreach(i; 0..8) res ~= encode(s.decode); 
				}
				else
				{
					 //everyithing is <0x80
					//res.appendUninitialized(8); //nem megy
					res.length += 8; 
					foreach(i, ref c; res[$-8..$]) c = cast(ushort)((*raw>>(i<<3))&0xFF);  //Todo: sse opt
					s = s[8..$]; 
				}
			}
				
			//remainder
			while(!s.empty) res ~= encode(s.decode); 
		} 
		
			ushort[] encode(string s, TextEncoding encoding)
		{
			import std.encoding; 
				
			ushort[] res; 
			res.reserve(s.length/encodingCharSize[encoding]);                            //ascii  uni
			switch(encoding)
			{
				case TextEncoding.ANSI	: wstring ws; transcode(cast(Windows1252String)s, ws); 	while(!ws.empty) res ~= encode(ws.decode); 	break; 
				case TextEncoding.UTF8	: encodeUTF8(res, s); 		break; 
				case TextEncoding.UTF16LE	: auto ws = cast(wstring)s; 	while(!ws.empty) res ~= encode(ws.decode); 	break; 
				case TextEncoding.UTF16BE	: auto ws = cast(wstring)s; ws = ws.byteSwap; 	while(!ws.empty) res ~= encode(ws.decode); 	break; 
				case TextEncoding.UTF32LE	: auto ds = cast(dstring)s; 	while(!ds.empty) res ~= encode(ds.decode); 	break; 
				case TextEncoding.UTF32BE	: auto ds = cast(dstring)s; ds = ds.byteSwap; 	while(!ds.empty) res ~= encode(ds.decode); 	break; 
				default: enforce(false, "TextEncoding not supported: "~encoding.text); 
			}
			return res; 
		} 
		
			string decode(ushort[] s)
		{
			string res; 
			res.reserve(s.length); 
			while(s.length>=4)
			{
				auto raw = cast(ulong*)s.ptr; 
				if(*raw & 0xff80ff80_ff80ff80)
				{
					//any of the 4 wchars are > 0x7F
					foreach(i; 0..4) res ~= decode(s[i]); 
				}
				else
				{
					 //all 4 wchars are <= 0x7F, no conversion needed
					char[4] tmp; 
					foreach(i, ref c; tmp) c = cast(char)((*raw>>(i<<4))&0xFF);    //Todo: sse opt
					res ~= tmp; 
				}
				s = s[4..$]; 
			}
				
			foreach(ch; s) res ~= decode(ch); //remaining
			return res; 
		} 
	} 
}version(/+$DIDE_REGION Ranges+/all)
{
	auto orderedInterleave(alias keyFun="a", R1, R2)(R1 s1, R2 s2)
	if(isInputRange!R1 && isInputRange!R1 && is(ElementType!R1==ElementType!R2))
	{
		import std.concurrency: Generator, yield; 
		alias T = ElementType!R1; 
		return new Generator!(Nullable!T)
		((){
			while(!s1.empty || !s2.empty)
			{
				void blank() { yield(Nullable!T.init); } 
				void y1() { yield(s1.front.nullable); s1.popFront; } 
				void y2() { yield(s2.front.nullable); s2.popFront; } 
				const k1() => s1.front.unaryFun!keyFun; 
				const k2() => s2.front.unaryFun!keyFun; 
				
				if(s1.empty)	{ blank; y2; }
				else if(s2.empty)	{ y1; blank; }
				else	{
					if(k1<=k2)	{
						y1; if(s1.empty || k1>=k2)	y2; 
						else	blank; 
					}
					else	{ blank; y2; }
				}
			}
		}); 
	} 
}version(/+$DIDE_REGION String operations+/all)
{
	version(/+$DIDE_REGION+/all) {
		//Strings //////////////////////////////////
		
		bool isUpper(A)(in A a)
		{ return a==a.toUpper; } 
		bool isLower(A)(in A a)
		{ return a==a.toLower; } 
		
		bool isAsciiLower(char c) pure
		{ return c.inRange('a', 'z'); } 
		bool isAsciiUpper(char c) pure
		{ return c.inRange('A', 'Z'); } 
		
		char asciiUpper(char c) pure
		{ return cast(char)(cast(int)c + (c.isAsciiUpper ? 0 : 'A'-'a')); } 
		char asciiLower(char c) pure
		{ return cast(char)(cast(int)c + (c.isAsciiLower ? 0 : 'a'-'A')); } 
		
		string asciiUpper(string s)
		{
			//Opt: this is terrible coding from the times when I was so dumb
			char[] res = s.dup; 
			foreach(ref char ch; res) ch = ch.asciiUpper; 
			return cast(string)res; 
		} 
		string asciiLower(string s)
		{
			char[] res = s.dup; 
			foreach(ref char ch; res) ch = ch.asciiLower; 
			return cast(string)res; 
		} 
		
		//Todo: lc and uc is so redundant... Maybe I should use toUpper everywhere...
		auto uc(char s) pure
		{ return s.toUpper; }  
		auto lc(char s) pure
		{ return s.toLower; } 
		
		auto uc(wchar s) pure
		{ return s.toUpper; } 
		auto lc(wchar s) pure
		{ return s.toLower; } 
		
		auto uc(dchar s) pure
		{ return s.toUpper; } 
		auto lc(dchar s) pure
		{ return s.toLower; } 
		
		string uc(string s) pure
		{ return s.toUpper; } 
		string lc(string s) pure
		{ return s.toLower; } 
		
		///generates D source string format from values
		string escape(T)(T s)
		{ return format!"%(%s%)"([s]); } 
		
		string capitalize(alias fv = toUpper)(string s)
		{
			//Todo: terrible looking solution, with NO unicode handling.
			//Todo: use std.string.capitalize or std.uni.asCapitalized
			if(!s.empty)
			{
				char u = fv([s[0]])[0]; 
				if(u != s[0]) s = u~s[1..$]; 
			}
			return s; 
		} 
		
		void listAppend(ref string s, string what, string separ)
		{
			auto w = what.strip; 
			if(w.empty) return; 
			if(!s.strip.empty) s ~= separ; 
			s ~= w; 
		} 
		
		string truncate(string ellipsis="...")(string s, size_t maxLen)
		{
			//Todo: string.truncate-t megcsinalni unicodeosra rendesen.
			/*
				  enum ellipsisLen = ellipsis.walkLength;
				auto len = s.walkLength;
				return len<=maxLen 	? s
					: len>ellipsisLen ? s.take(maxLen-ellipsisLen)~ellipsis
					: s.take(maxLen);
			*/
			enum ellipsisLen = ellipsis.length; 
			auto len = s.length; 
			return len<= 	maxLen 	? s
				: maxLen>ellipsisLen 	? s[0..maxLen-ellipsisLen]~ellipsis
					: s[0..maxLen]; 
		} 
		
		
		string decapitalize()(string s)
		{ return s.capitalize!toLower; } 
		
		bool sameString(string a, string b)
		{ return a==b; } 
		bool sameText(string a, string b) 
		{ return icmp(a, b)==0; } 
		bool sameFile(File a, File b) 
		{ return sameText(a.normalized.fullName, b.normalized.fullName); } 
		
		auto amongText(Values...)(string value, Values values)
		{ return value.among!sameText(values); } 
		
		/// Show the differences in 2 strings
		string strDiff(char diffChar='^', char sameChar='_')(string a, string b)
		{
			string res; 
			foreach(i; 0..min(a.length, b.length)) res ~= a[i]==b[i] ? sameChar : diffChar; 
			res ~= [diffChar].replicate(a.length>b.length ? a.length-b.length : b.length>a.length); 
			return res; 
		} 
		
		//strips specific strings at both ends.
		string strip2(string s, string start, string end)
		{
			if(s.length >= start.length + end.length && s.startsWith(start) && s.endsWith(end))
			return s[start.length..$-end.length]; 
			else
			return s; 
		} 
		
		private S _withoutStarting(bool start, bool remove, S, T)(in S s, in T end)
		{
			static if(start)
			alias fv = startsWith; 
			else
			alias fv = endsWith; 	
			const e = end.to!S; 	//Todo: this is fucking lame.
			if(e != "" && fv(s, e) == remove)
			{
				return remove 	? start 	? s[e.length..$]
						: s[0..$-e.length]
					: start 	? e ~ s
						: s ~ e; 
			}
			else return s; 
		} 
		
		//Todo: inconvenience with includeTrailingPathDelimiter
		S withoutStarting	(S, T)(in S s, in T end)
		{ return _withoutStarting!(1, 1)(s, end); } 
		S withoutEnding	(S, T)(in S s, in T end)
		{ return _withoutStarting!(0, 1)(s, end); } 
		S withStarting	(S, T)(in S s, in T end)
		{ return _withoutStarting!(1, 0)(s, end); } 
		S withEnding	(S, T)(in S s, in T end)
		{ return _withoutStarting!(0, 0)(s, end); } 
		
		S withoutEndingNewLine(S)(in S s)
		{ return ((s.endsWith('\n'))?(s[0..$-1].withoutEnding('\r')):(s)); } 
		
		auto withoutStartingEnding(S, ST, EN)(in S s, in ST st, in EN en)
		{
			if(s.startsWith(st) && s.endsWith(en))
			return s.withoutStarting(st).withoutEnding(en); 
			return s; 
		} 
		
		auto unpackDComment(string prefix="")(string s)
		{
			static assert(prefix.all!isAlpha); 
			string p = ((prefix!="")?(prefix~':'):("")); 
			if(s.length>=2+p.length+2 && s.startsWith("/+") && s.endsWith("+/") && sameText(s[2..2+p.length], p))
			{ s = s[2+p.length..$-2].withoutStarting(' '); }
			return s; 
		} 
	}version(/+$DIDE_REGION+/all) {
		//Todo: unittest
		/*
				assert("a/".withoutEnding("/") == .print;
					"a/b".withoutEnding("/").print;
					"a/".withoutStarting("/").print;
					"/a".withoutStarting("/").print;
			
			a
			a/b
			a/
			a
		*/
		
		
		string getFirstDir(char sep='\\')(string s)
		{
			auto i = s.indexOf(sep); 
				return i<0 ? "" : s[0..i]; 
		} 
		
		string withoutFirstDir(char sep='\\')(string s)
		{
			auto i = s.indexOf(sep); 
			if(i<0) return s; 
			return i<0 ? s : s[i+1..$]; 
		} 
		
		
		string[] withoutLastEmpty(string[] lines)
		{
			if(!lines.empty && lines.back.strip.empty) return lines[0..$-1]; 
			return lines; 
		} 
		
		void removeLastEmpty(ref string[] lines)
		{ lines = lines.withoutLastEmpty; } 
		
		//Todo: revisit string pchar conversion
		
		auto toPChar(S)(S s) nothrow
		{
			//converts to Windows' string
			const(char)* r; 
			try { r = toUTFz!(char*)(s); }catch(Throwable) {}
			return r; 
		} 
		
		auto toPWChar(S)(S s) nothrow
		{
			//converts to Windows' widestring
			const(wchar)* r; 
			try { r = toUTF16z(s); }catch(Throwable) {}
			return r; 
		} 
		
		/// replaces UTF errors with the error character. So the string will be safe for further processing.
		string safeUTF8(string s)
		{
			try
			{
				std.utf.validate(s); 
				return s; 
			}
			catch(Exception)
			{
				auto res = appender!string; 
				size_t i, len = s.length; 
				while(i<len)
				res ~= s.decode!(Yes.useReplacementDchar)(i); 
				return res[]; 
			}
		} 
		
		//builds c zterminated string
		void strMake(string src, char* dst, size_t dstLen)
		{
			assert(dst !is null); 
			assert(dstLen>=1); 
			
			size_t sLen = min(dstLen-1, src.length); 
			memcpy(dst, src.ptr, sLen);           //Todo: this is so naive. Must revisit...
			dst[sLen] = 0; //zero terminated
		} 
		
		void strMake(string src, char[] dst)
		{ strMake(src, dst.ptr, dst.length); } 
		
		string dataToStr(const(void)* src, size_t len)
		{
			//Todo: this is ultra-lame: (cast(char[])src)[0..len].to!string
			//https://stackoverflow.com/questions/32220621/converting-a-temporary-character-array-to-a-string-in-d    .idup
			//this would be the good solution.  Now Testing with file.originalCasing()	 return (cast(const(char)*) src)[0..len].idup;
			char[] s; 
			s.length = len; 
			memcpy(s.ptr, src, len); 
			return s.to!string; 
		} 
		string dataToStr(const(void)[] src)
		{ return dataToStr(src.ptr, src.length); } 
		string dataToStr(T)(const T src)
		{ return dataToStr(&src, src.sizeof); } 
		
		
		string toStr(T)(const(T)* s)
		{ return s.to!string; } 
		string toStr(T)(const(T)* s, size_t maxLen)
		{ return toStr(s[0..maxLen]); } 
		string toStr(const char[] s)
		{
			//safe version, handles well without zero too
			auto e = (cast(ubyte[])s).countUntil(0); 
			if(e<0) e = s.length; 
			return s[0..e].to!string; 
			
			//Todo: use proper string api
		} 
		string toStr(const wchar[] s)
		{
			//safe version, handles well without zero too
			auto e = (cast(ushort[])s).countUntil(0); 
			if(e<0) e = s.length; 
			return s[0..e].to!string; 
		} 
		string toStr(const dchar[] s)
		{
			//safe version, handles well without zero too
			auto e = (cast(uint[])s).countUntil(0); 
			if(e<0) e = s.length; 
			return s[0..e].to!string; 
		} 
	}version(/+$DIDE_REGION+/all) {
		string binToHex(in void[] input)
		{ return toHexString!(LetterCase.upper)(cast(ubyte[])input); } 
		
		string toHex(in void[] input)
		{ return(binToHex(input)); } 
		
		ubyte[] hexToBin(string s)
		{
			if(s.startsWith_ci("0x")) s = s[2..$]; 
					
			ubyte[] r; 
			r.reserve(s.length/2); 
					
			bool state; 
			int tmp; 
			void append(int num)
			{
				if(state) r ~= cast(ubyte)(tmp<<4 | num); 
				else tmp = num; 
				state = !state; 
			} 
					
			foreach(ch; s) {
				if(ch.among(' ', '\r', '\n', '\t')) {}
				else if(inRange(ch, '0', '9'	)) append(ch-'0'	); 
				else if(inRange(ch, 'a', 'f'	)) append(ch-'a'	+10); 
				else if(inRange(ch, 'A', 'F'	)) append(ch-'A'	+10); 
				else break; 
			}
					
			//state is true (odd number of digits) -> don't care
			return r; 
		} 
		
		string hexToStr(in string s)
		{ return cast(string)hexToBin(s); } 
		
		//hexDump ///////////////////////////
		//import std.algorithm, std.stdio, std.file, std.range;
		
		/+
			void hexDump(in void[] data){
						auto d = cast(const ubyte[])data;
						int idx;
						foreach(chunk; d.chunks(16)){
							"%.4X %(%02X %)%*s  %s".writefln(idx++*16, chunk,
								3 * (16 - chunk.length), "", // Padding
								chunk.map!(c => // Replace non-printable
									c < 0x20 || c > 0x7E ? '.' : char(c)));
						}
					}
		+/
		
		void hexDump(T=ubyte)(in void[] data, int width=16)
		{
			enum digits = T.sizeof*2; 
			
			string hexLine(in T[] buf)
			{
				return buf	.take(width)
					.map!(a => a.format!("%0"~digits.text~"X"))
					.padRight(" ".replicate(digits), width)
					.join(' '); 
			} 
			
			string binaryLine(in void[] buf)
			{
				return (cast(ubyte[])buf)	.take(width*T.sizeof)
					.map!`a>=32 && a<=127 ? char(a) : '.'`
					.array; 
			} 
			
			foreach(i, a; (cast(T[])data).chunks(width).map!array.enumerate)
			writefln!"%04X : %s : %s"(i*width, hexLine(a), binaryLine(a)); 
		} 
		
		bool isHexDigit(dchar ch) @safe
		{
			return   isDigit(ch)
				|| inRange(ch, 'a', 'f')
				|| inRange(ch, 'A', 'F'); 
		} 
		
		bool isDigit(dchar ch) @safe
		{
			//Todo: also there is std.uni.isNumber
			return inRange(ch, '0', '9'); 
		} 
		
		bool isLetter(dchar ch) @safe 
		{
			//Todo: also there is std.uni.isAlpha
			return   inRange(ch, 'a', 'z')
				|| inRange(ch, 'A', 'Z'); 
		} 
		
		bool isWordChar(dchar ch) @safe
		{ return isLetter(ch) || isDigit(ch) || ch=='_'; } 
		
		bool isWordCharExt(dchar ch) @safe
		{ return isWordChar(ch) || ch.among('#', '$', '~'); } 
		
		bool isIdentifier(const string s) @safe
		{
			//Todo: ezt esszerusiteni!
			if(isDigit(s.get(0))) return false; //can't be number
			auto w = s.wordAt(0); 
			return w.length==s.length; 
		} 
		
		string wordAt(string s, size_t pos) @safe
		{
			if(!isWordChar(s.get(pos))) return ""; 
			
			auto st = pos; 	while(isWordChar(s.get(st-1))) st--; 
			auto en = pos+1; 	while(isWordChar(s.get(en))) en++; 
			
			return s[st..en]; 
		} 
		
		ptrdiff_t wordPos(
			const string s, const string sub, size_t startIdx,
			in std.string.CaseSensitive cs = Yes.caseSensitive
		) @safe
		{
			ptrdiff_t res; 
			while(1) {
				res = indexOf(s, sub, startIdx, cs); 
				if(res<0) break; 
				if(!isWordChar(s.get(res-1)) && !isWordChar(s.get(res+sub.length))) break; 
				startIdx = res+1; 
			}
			return res; 
		} 
		
		ptrdiff_t wordPos(const string s, const string sub, in std.string.CaseSensitive cs = Yes.caseSensitive) @safe
		{ return wordPos(s, sub, 0, cs); } 
		
		T toInt(T=int)(string s)
		{
			//Todo: toLong
			if(s.length>2 && s[0]=='0') {
				if(s[1].among('x', 'X')) return s[2..$].to!T(16); 
				if(s[1].among('b', 'B')) return s[2..$].to!T(2); 
			}
			return s.to!T; 
		} 
		
		bool isDLangWhitespace	(C)(in C ch)
		{ return !!ch.among(' ', '\t', '\x0b', '\x0c'); } 
		
		bool isDLangNewLine(T)(T ch)if(isSomeChar!T)
		{ return !!ch.among('\n', '\r', '\u2028', '\u2029'); } 
		bool isDLangNewLine	(S)(in S str)if(isSomeString!S)
		{ return !!str.among("\r\n", "\n", "\r", "\u2028", "\u2029"); } 
		
		bool isDLangIdentifierStart	(T)(T ch)if(isSomeChar!T)
		{ return ch.inRange('a', 'z') || ch.inRange('A', 'Z') || ch=='_' || isUniAlpha(ch); } 
		bool isDLangIdentifierCont	(T)(T ch)if(isSomeChar!T)
		{ return isDLangIdentifierStart(ch) || isDLangNumberStart(ch); } 
		bool isDLangIdentifier(T)(T s)
		if(isSomeString!T)
		{ return !s.empty && s.front.isDLangIdentifierStart && s.drop(1).all!isDLangIdentifierCont; } 
		
		bool isDLangNumberStart	(T)(T ch)if(isSomeChar!T)
		{ return ch.inRange('0', '9'); } 
		bool isDLangNumberCont	(T)(T ch)if(isSomeChar!T)
		{ return isDLangIdentifierCont(ch); } 
		
		bool isDLangSymbol(T)(T ch)if(isSomeChar!T)
		{
			return "~`!@#$%^&*()_+-=[]{}'\\\"|<>?,./".canFind(ch); //Todo: optimize this to a lookup
		} 
		
		bool isSingleDString(string src)
		{
			return src.length>=2 && src.startsWith('`') && src.endsWith('`') 
			&& !src[1..$-1].canFind('`'); 
		} 
		bool isSingleCString(string src)
		{
			return src.length>=2 && src.startsWith('"') && src.endsWith('"') 
			&& !src[1..$-1].replace(`\"`, `\'`).canFind('"'); 
		} 
		
		bool validDCommentBody(string s)
		{
			//check if the nesting is correct
			auto a = s, level = 0, ok = true; 
			while(a.length>=2)
			{
				if(a.startsWith("/+"))	{ level++; a = a[2..$]; }
				else if(a.startsWith("+/"))	{ level--; a = a[2..$]; if(level<0) ok = false; }
				else	a = a[1..$]; 
			}
			if(level!=0) ok = false; 
			
			return ok; 
		} 
		
		string safeDCommentBody(string s)
		{
			//if it's wrong, then defuse all the comment prefixes and postfixes.
			return ((s.validDCommentBody)?(s) :(s.replace("/+", "／+").replace("+/", "+／"))); 
		} 
		
	}version(/+$DIDE_REGION+/all) {
		string replaceWords(alias fun = isWordChar)(string str, string from, string to)
		{
			auto src = (&str).refRange; 
					
			auto fetchAndReplace(bool isWord, uint len)
			{
				auto act = src.takeExactly(len).text; 
				return isWord && act==from ? to : act; 
			} 
					
			static if(0)
			{
				//Todo: compare the speed of this functional approach
				return str	.map!fun
					.group
					.map!(p => fetchAndReplace(p[])); 
					.join; 
			}
			else
			{
				string res; 
				foreach(isWord, len; str.map!fun.group)
				res ~= fetchAndReplace(isWord, len); 
				return(res); 
			}
		} 
		
		//Todo: isWild variadic return parameters list, like formattedtext
		struct WildResult
		{
			static: 
			private string[] p; 
			void _reset()
			{ p = []; } 
			void _append(string s)
			{ p ~= s; } 
			
			auto length()
			{ return p.length; } 
			auto empty()
			{ return p.empty; } 
			auto strings(size_t i, string def="")
			{ return i<length ? p[i] : def; } 
			auto opIndex(size_t i)
			{ return strings(i); } 
			
			auto to(T)(size_t i, T def = T.init)
			{
				try {
					auto s = strings(i).strip; 
					static if(isIntegral!T)
					{
						return s.toInt.to!T; //😎
						//use toint for 0x hex and 0b bin. long is not supported yet
					}
					else
					{ return s.to!T; }
				}
				catch(Throwable) { return def; }
			} 
			
			auto ints	(size_t i, int def = 0)
			{ try return to!int	(i); catch(Throwable) return def; } 
			auto floats	(size_t i, float def = 0)
			{ try return to!float	(i); catch(Throwable) return def; } 
			auto doubles	(size_t i, double def = 0)
			{ try return to!double	(i); catch(Throwable) return def; } 
			
			void stripAll()
			{ foreach(ref s; p) s = s.strip; } 
			
			string toString()
			{ return p.text; } 
		} 
		
		alias wild = WildResult; 
		
		bool isWildMask(char chAny = '*', char chOne = '?')(string s)
		{ return s.any!(a => a.among(chAny, chOne)); } 
		
		bool isWild(bool ignoreCase = true, char chAny = '*', char chOne = '?')(string input, string[] wildStrs)
		{
			foreach(w; wildStrs)
			{
				if(isWild!(ignoreCase, chAny, chOne)(input, w))
				return true; 
			}
			return false; 
		} 
		
		bool isWildMulti(bool ignoreCase = true, 	char chAny = '*', char chOne = '?', char chSepar = ';')(string input, string wildStrs)
		{
			foreach(w; wildStrs.splitter(chSepar))
			{
				if(isWild!(ignoreCase, chAny, chOne)(input, w))
				return true; 
			}
			return false; 
		} 
		
		bool isWild(bool ignoreCase = true, char chAny = '*', char chOne = '?')(string input, string wildStr)
		{
			//Bug: isWild invalid utf sequence bug!!!  with string: `Árak` mask `?* Ft?* Ft/?*`
			
			//bool cmp(char a, char b){ return ignoreCase ? a.toLower==b.toLower : a==b; }
			const cs = ignoreCase ? No.caseSensitive : Yes.caseSensitive;   
			//Note: kibaszott kisbetu a caseSensitive c-je. Kulonben osszeakad az std.path.CaseSensitive enummal.
			if(1) wild._reset; 
					
			while(1)
			{
				string wildSuffix; 	 //string precedding wildcards
				size_t wildReq; 	 //number of '?' in wild
				bool wildAnyLength; 	 //there is * in the wildcard
				string actOutput; 
						
				//fetch wildBlock  [??*abc]
				while(wildStr.length)
				{
					if(wildStr[0]==chAny) { wildAnyLength = true; wildStr = wildStr[1..$]; }
					else if(wildStr[0]==chOne) { wildReq++; wildStr = wildStr[1..$]; }
					else break; 
				}
				while(wildStr.length && !wildStr.front.among(chAny, chOne))
				wildSuffix ~= wildStr.fetchFront; //slow
				
				//get the required minimal amount of chars
				actOutput = input.take(wildReq).text; 
				if(actOutput.walkLength<wildReq) return false; 
				input = input[actOutput.length..$]; 
				
				if(wildSuffix.empty)
				{
					//search for end of input
					if(wildAnyLength)
					{
						//if there is a * at the end
						if(1) {
							actOutput ~= input; 
							wild._append(actOutput); 
						}
						return true; 
					}
					else
					{
						//if not *
						if(wildReq>0 && 1) wild._append(actOutput); 
						return input.empty; 
					}
				}
						
				//there is a string to match
				auto i = input.indexOf(wildSuffix, cs); 
				if(i<0) return false; 
				if(!wildAnyLength && i!=0) return false; 
						
				if(1 && (wildAnyLength || wildReq)) {
					actOutput ~= input[0..i]; 
					wild._append(actOutput); 
				}
				input = input[i+wildSuffix.length..$]; 
			}
					
		} 
	}version(/+$DIDE_REGION+/all) {
		alias StrMap = string[string]; 
		
		auto mapToStr(const StrMap map)
		{
			return map.length 	? JSONValue(map).toString
				: ""; 
		} 
		
		auto strToMap(const string str)
		{
			string[string] map; 
			try {
				auto j = str.parseJSON; 
				if(j.type==JSONType.OBJECT)
				foreach(string key, ref val; j)
				map[key] = val.str; 
			}catch(Exception) {}
			return map; 
		} 
		
		string withoutQuotes(string s, char q)
		{
			if(s.length>=2 && s.startsWith('\"') && s.endsWith('\"'))
			s = s[1..$-1].replace([q, q], [q]); 
			return s; 
		} 
		
		
		auto splitQuotedStr(string line, char delim, char quote)
		{
			auto s = line.dup; 
			
			//mark non-quoted spaces
			bool inQuote; 
			foreach(ref char ch; s)
			{
				if(ch==quote) inQuote = !inQuote; 
				if(!inQuote && ch==delim) ch = '\1'; //use #1 as a marker for splitting
			}
			
			return cast(string[]) s.split('\1'); 
		} 
		
		
		auto splitCommandLine(string line)
		{
			//split, convert, strip, filter empties
			return line	.splitQuotedStr(' ', '"')
				.filter!"a.length"
				.map!(a => a.strip.to!string.withoutQuotes('"'))
				.array; 
		} 
		
		auto commandLineToMap(string[] parts)
		{
			string[string] map; 
			int paramIdx; 
			foreach(s; parts)
			{
				string key, value; 
				
				//try to split at '='
				bool keyValueFound; 
				foreach(i, ch; s)
				{
					if(ch=='"') break; 
					if(ch=='=') {
						key = s[0..i]; 
						value = s[i+1..$].withoutQuotes('"'); 
						keyValueFound = !key.empty; 
						break; 
					}
				}
				
				//unnamed parameter
				if(!keyValueFound) {
					key = (paramIdx++).text; 
					value = s; 
				}
				
				map[key] = value; 
			}
			
			map.rehash; 
			return map; 
		} 
		
		auto commandLineToMap(string line)
		{ return commandLineToMap(line.splitCommandLine); } 
		
		string helpText(in GetoptResult opts)
		{ return opts.options.map!(o => format(`  %-20s %s`, [o.optShort, o.optLong].join(" "), o.help)).join("\n"); } 
		
		auto parseOptions(T)(string[] args, ref T options, Flag!"handleHelp" handleHelp)
		{
			/*
				exampls struct: struct Options {
					@(`Exits right after a solution.`)	     EarlyExit = false;
					@(`t|BenchmarkTime = Minimum duration of the benchmark. Default: $DEFAULT$ sec`)	     BenchmarkMinTime = 12;
					@(`WFPerCU = Number of WaveFronts on each Compute Units. Default: $DEFAULT$`)	     WFPerCU = 8;
					@(`p = Calls the payload outside the mixer.`)	     SeparatePayload = false;
				}
			*/
			
			string[] getoptLines = getStructInfo(options).getoptLines("options"); 
			auto opts = mixin("getopt(args, std.getopt.config.bundling,\r\n"~getStructInfo!T.getoptLines("options").join(",")~")"); 
			
			if(opts.helpWanted && handleHelp) {
				writeln(opts.helpText); 
				application.exit; 
			}
			
			return opts; 
		} 
		
		string quoted(T)(T src, char q = '"')
		{
			string s; 
			static if(is(T : File))	s = src.fullName; 
			else static if(is(T : Path))	s = src.fullPath; 
			else	s = src; 
			
			if(q=='"') return format!"%(%s%)"([s]); 
			else if(q=='`') return s.canFind(q) ? quoted(s, '"') : q ~ s ~ q; 
			else
			ERR("Unsupported quote char: "~q); 
			
			assert(0); 
		} 
		
		string cmdArg(string s)
		{
			//Bug: Don't give a fuck about quoting quotes.
			/+Todo: make proper dos/windows command line argument encoding.+/
			return s.canFind(' ') ? '"' ~ s ~ '"' : s; 
		} 
		
		string cmdArg(File f)
		{ return f.fullName.cmdArg; } 
		
		auto joinCommandLine(string[] cmd)//Todo: handling quotes
		{
			auto wcmd = cmd.map!(a => to!wstring(a)).array; //convert to wstrings
			foreach(ref a; wcmd)
			{
				if(a.canFind('"')) continue; //already quoted.
				if(a.empty)
				{
					a = `""`; //empty string
				}
				else if(a.canFind(' '))
				{
					if(a[0]=='/' && a.canFind(':'))
					{
						//quotes for MSLink.exe.   /OUT:"c:\file name.b"
						auto p = a.countUntil(':')+1; 
						a = a[0..p]~'"'~a[p..$]~'"'; 
					}
					else
					{
						a = '"'~a~'"'; //add quotes
					}
				}
			}
			return to!string(wcmd.join(' ')); //join
		} 
		
		unittest
		{
			auto s = "\"hello\u00dc aa\" world"; 
			assert(joinCommandLine(splitCommandLine(s))==s); 
			assert(joinCommandLine([`/OUT:file name.exe`])==`/OUT:"file name.exe"`); 
		} 
		
		private mixin template ComandLineTemplate(char chDelim, char chQuote , char chEqu)
		{
			//Todo: boolean handling
			//Todo: same option multimple times: the last one is the real one
			
			struct Item {
				bool hasValue; 
				string name, value; 
				//Todo: toString() with proper quotes and error checking
				
				string toString() const
				{
					static string autoQuote(string s)
					{
						//Todo: what if " is in the string
						//Todo: what if space is in QueryString
						//Todo: QueryString don't even have quotes anyways
						
						//now this is fixed like this:
						if(s.canFind(' '))
						return chQuote ~ s ~ chQuote; 
						
						return s; 
					} 
					
					return hasValue 	? autoQuote(name) ~ chEqu ~ autoQuote(value)
						:autoQuote(name); 
				} 
			} 
			
			Item[] items; //all items
			string[] names; //only names without values
			string[string] options; //all name/value pairs
			
			auto files() const { return names.map!File; } 
			auto paths() const { return names.map!Path; } 
			
			this(string line)
			{
				foreach(s; line.splitQuotedStr(chDelim, chQuote))
				{
					string key, value; 
					
					bool keyValueFound; 
					foreach(i, ch; s)
					{
						if(ch==chQuote) break; 
						
						if(ch=='?') break; 
						/+
							Don't look after '?' because the there could be '=' too.
							Example: c:\a.bmp?thumb&h=64
						+/
						
						if(ch==chEqu) {
							key = s[0..i]; 
							value = s[i+1..$].withoutQuotes(chQuote); 
							keyValueFound = !key.empty; 
							break; 
						}
					}
					
					if(keyValueFound)
					{
						items ~= Item(true, key, value); 
						options[key] = value; 
					}
					else
					{
						const name = s.withoutQuotes(chQuote); 
						items ~= Item(false, name); 
						names ~= name; 
					}
				}
			} 
			
			string option(string name) const
			{ return option(name, ""); } 
			
			T option(T)(string name, in T def) const
			{
				if(auto a = name in options)
				try { return (*a).to!T; }catch(Exception) {}
				return def; 
			} 
			
			//these opCalls are loaders. They need a reference or a setter.
			void opCall(T)(string name, void delegate(T) fun) const
			{ if(auto a = name in options) fun((*a).to!T); } 
			
			void opCall(T)(string name, ref T var) const
			{ if(auto a = name in options) var = (*a).to!T; } 
			
			alias items this;  //Todo: items[] can throw, not good.
			
			string command() const
			{
				if(items.empty) return ""; 
				return items[0].name; 
			} 
			
			string toString() const
			{ return items.map!text.join(chDelim); } 
			
			const @property empty() => !!items.length; 
		} 
		
		//Todo: Use this instead of CommandLineToMap
		struct CommandLine
		{ mixin ComandLineTemplate!(' ', '"', '='); } 
		struct QueryString
		{ mixin ComandLineTemplate!('&', '"', '='); } 
		
		//Todo: make unittest for CommandLine and QueryString
		void testCommandLineQueryString()
		{
			const a = CommandLine(`dir "C:\Program Files" > C:\lists.txt param=" abc def " float=5.4 "c:\a.b?thumb&h=64"`); 
			
			static if(1)
			{
				write("Command "); a.command.print; 
				write("Items "); a.each.print; 
				write("Names "); a.names.each!print; 
				write("Files "); a.files.each!print; 
				write("Param access "); a.option("param").print; 
				write("Float access "); a.option("float", 0.0f).print; 
				print; 
				write("QueryString access"); a.files.back.queryString.each!print; 
			}
			
			static if(0)
			testConsole(
				q{
					Comment //Code: a.command
					Items //Code: a.each
					Names //Code: a.names.each
					Files //Code: a.files.each
					Param access //Code: a("param")
					Float access //Code: a("float", 0.0f)
					
					QueryString access //Code: a.files.back.queryString.each
				}
			); 
			
			
		} 
		
		
		public import std.net.isemail : isEmail; 
		
		string indent(int cnt, char space = ' ') @safe
		{ return [space].replicate(cnt); } 
		
		string indent(string s, int cnt, char space = ' ') @safe
		{
			string id = indent(cnt, space); 
			return s	.split('\n')
				.map!strip
				.map!(l => l.empty ? "" : id~l)
				.join("\r\n"); 
		} 
	}version(/+$DIDE_REGION+/all) {
		//std.algorithm.findsplit is similar
		
		string firstLine(string s)
		{
			auto a = s.splitter("\n").map!strip; 
			if(a.empty) return ""; 
			auto res = a.front; a.popFront; 
			if(!a.empty) res ~= "…"; 
			return res; 
		} 
		
		bool split2(string s, string delim, out string a, out string b, bool doStrip = true)
		{
			//split to 2 parts
			auto i = s.countUntil(delim); 
			if(i>=0) {
				a = s[0..i]; 
				b = s[i+delim.length..$]; 
			}else {
				a = s; 
				b = ""; 
			}
					
			if(doStrip) {
				a = a.strip; 
				b = b.strip; 
			}
					
			return i>=0; 
		} 
		
		auto split2(string s, string delim, bool doStrip = true)
		{
			string s1, s2; 
			split2(s, delim, s1, s2, doStrip); 
			return tuple(s1, s2); 
		} 
		
		string join2(string a, string delim, string b)
		{
			if(a.length && b.length) return a ~ delim ~ b; 
			if(a.length) return a; 
			return b; 
		} 
		
		string capitalizeFirstLetter(string s) {
			if(s.empty) return s; 
			return s[0..1].uc ~ s[1..$]; 
		} 
		
		string stripRightReturn(string a)
		{
			if(a.length && a.back=='\r') return a[0..$-1]; 
			return a; 
		} 
		
		auto tabTextToCells(string text, immutable(char)[2] delims = "\t\n")
		{
			string[] lines = text.split(delims[1]).array; 
			string[][]cells = lines.map!(s => s.stripRightReturn.split(delims[0]).map!strip.array).array; 
					
			//add empty cells where needed
			auto maxCols = cells.map!(c => c.length).maxElement; 
			foreach(ref c; cells) c.length = maxCols; 
			return cells; 
		} 
		
		auto csvToCells(string text)
		{ return tabTextToCells(text, ";\n"); } 
		
		//Todo: import splitLines from std.string
		
		string[] splitLines(string s)
		{ return s.splitter('\n').map!(a => a.withoutEnding('\r')).array; } 
		
		dstring[] splitLines(dstring s)
		{ return s.splitter('\n').map!(a => a.withoutEnding('\r')).array; } 
		
		bool startsWith_ci(string s, string w) pure
		{
			if(w.length>s.length) return false; //Todo: refactor functionally
			foreach(i, ch; w)
			{ if(uc(s[i]) != uc(ch)) return false; }
			return true; 
		} 
		
		string skipOver_ci(string s, string w) pure
		{ return s.startsWith_ci(w) ? s[w.length..$] : s; } 
		
		auto splitSections(string sectionNameMarker="*")(ubyte[] data, string sectionDelim)
		{
			//example of a section delimiter: "\n\n$$$SECTION:*\n\n"
			struct SectionRec {
				string key; 
				ubyte[] value; 
			} 
			
			string d0, d1; 
			sectionDelim.split2(sectionNameMarker, d0, d1, false); 
			enforce(d0.length && d1.length, "Invalid sectionDelimiter"); 
			
			auto parts = data.split(cast(const ubyte[])d0); 
			SectionRec[] res; 
			
			if(parts.length && parts[0].length)
			res ~= SectionRec("", parts[0]); //first noname section
			
			if(parts.length>1)
			foreach(p; parts[1..$])
			{
				auto i = p.countUntil(cast(const ubyte[])d1); 
				if(i>=0) res ~= SectionRec(cast(string)(p[0..i]), p[i+d1.length..$]); 
			}
			
			return res; 
		} 
		
		/// Because the one in std is bugging
		string outdent(string s)
		{
			//Todo: this is lame
			return s.split('\n').map!(a => a.withoutEnding('\r').stripLeft).join('\n'); 
		} 
		
		/// makes "Hello world" from "helloWorld"
		string camelToCaption(string s)
		{
			import std.uni; 
			if(s=="") return s; //empty
			if(s[0].isUpper) return s; //starts with uppercase
					
			//fetch a word
			auto popWord()
			{
				string word; 
				while(s.length) {
					char ch = s[0]; //no unicode support
					if(!word.empty && ch.isUpper) break; 
					s = s[1..$]; 
					word ~= ch; 
				}
				return word; 
			} 
					
			string[] res; 
			while(s.length) { res ~= popWord; }
					
			foreach(idx, ref w; res) w = idx ? w.toLower : w.capitalize; 
					
			return res.join(' '); 
		} 
		
		
		struct OrderedAA(K,V)
		{
			V[K] _impl; 
			K[] keyOrder; 
					
			void opIndexAssign(V value, K key)
			{
				if(key !in _impl) keyOrder ~= key; 
				_impl[key] = value; 
			} 
					
			V opIndex(K key)
			{ return _impl[key]; } 
					
			int opApply(int delegate(K,V) dg)
			{
				foreach(key; keyOrder)
				if(dg(key, _impl[key])) return 1; 
				return 0; 
			} 
					
			auto byKeyValue()
			{ return keyOrder.map!(k => tuple!("key", "value")(k, _impl[k])); } 
		} 
	}version(/+$DIDE_REGION+/all) {
		struct UrlParams {
			string path; 
			OrderedAA!(string, string) params; 
		} 
		
		UrlParams decodeUrlParams(string url)
		{
			string path, params; split2(url, "?", path, params); 
					
			auto res = UrlParams(path); 
					
			foreach(s; params.split('&'))
			{
				string name, value; split2(s, "=", name, value); 
				res.params[urlDecode(name)] = urlDecode(value); 
			}
					
			return res; 
		} 
		
		string encodeUrlParams(UrlParams up)
		{
			string p = up.params.byKeyValue.map!(a => urlEncode(a.key) ~ '=' ~ urlEncode(a.value)).join('&'); 
			return up.path ~ (p.length ? '?' ~ p : ""); 
		} 
		
		string overrideUrlParams(string url, string overrides)
		{
			if(!overrides.canFind('?')) overrides = '?' ~ overrides; 
			auto base = url.decodeUrlParams, ovr = overrides.decodeUrlParams; 
					
			foreach(k, v; ovr.params)
			base.params[k] = v; 
					
			return encodeUrlParams(base); 
		} 
		
		string overrideUrlPath(string url, string path)
		{
			auto a = url.decodeUrlParams; 
			a.path = path; 
			return a.encodeUrlParams; 
		} 
		
		void mergeUrlParams(ref string s1, string s2)
		{
			//used by het.stream.proparray only. Kinda deprecated
			string path1, params1; split2(s1, "?", path1, params1); 
			string path2, params2; split2(s2, "?", path2, params2); //s2 overrides the path!!!!
					
			enforce(path1.empty || path1==path2); 
					
			string[string] m; 
					
			foreach(s; chain(params1.split('&'), params2.split('&')))
			{
				string name, value; split2(s, "=", name, value); 
				m[name] = value; 
			}
					
			string[] res; 
			foreach(k, v; m)
			res ~= k~'='~v; 
					
			s1 = path2~'?'~res.join('&'); 
		} 
		
		//strips off regex-like /flags off the input string.
		string fetchRegexFlags(ref string s)
		{
			string res; 
			foreach_reverse(idx, ch; s)
			{
				if(ch.inRange('a', 'z') || ch.inRange('A', 'Z') || ch.inRange('0', '9') || ch=='_') continue; 
				if(ch=='/') {
					res = s[idx+1..$]; 
					s = s[0..idx].stripRight; 
					return res; 
				}
				break; 
			}
			return res; 
		} 
		
		
		string shortSizeText(int base, string spacing="", T)(in T n)
		{
			//Todo: optimize this
			//Todo: 4096 -> 4k
			//toso: 4.0k -> 4k
			
			static if(base==1024) enum divFactor(int n) = (1.0/1024)^^n; 
			else static if(base==1000) enum divFactor(int n) = (1.0/1000)^^n; 
			else static assert(0, "invalid base"); 
			
			string s = n.text; 	if(s.length<=4) return s~spacing; 
			s = format!"%.1f"(n*divFactor!1); 	if(s.length<=3) return s~spacing~'k'; 
			s = format!"%.0f"(n*divFactor!1); 	if(s.length<=3) return s~spacing~'k'; 
			s = format!"%.1f"(n*divFactor!2); 	if(s.length<=3) return s~spacing~'M'; 
			s = format!"%.0f"(n*divFactor!2); 	if(s.length<=3) return s~spacing~'M'; 
			s = format!"%.1f"(n*divFactor!3); 	if(s.length<=3) return s~spacing~'G'; 
			s = format!"%.0f"(n*divFactor!3); 	if(s.length<=3) return s~spacing~'G'; 
			s = format!"%.1f"(n*divFactor!4); 	if(s.length<=3) return s~spacing~'T'; 
			s = format!"%.0f"(n*divFactor!4); 		return s~spacing~'T'; 
		} 
		
		string shortDurationText(Time t)
		{
			if(!t) return ""; 
			if(t<0*second) return "-" ~ shortDurationText(-t); 
			if(t<1000*nano(second)) return siFormat("%.0f ns", t); 
			if(t<1000*micro(second)) return siFormat("%.0f µs", t); 
			if(t<1000*milli(second)) return siFormat("%.0f ms", t); 
			if(t<60*second) return siFormat("%.1f s", t); 
			if(t<60*minute) return siFormat("%.1f min", t); 
			if(t<24*hour) return siFormat("%.1f h", t); 
			auto d = t.value(day); 
			if(d<7) return d.format!"%.1f d"; 
			if(d<31) return d.format!"%.1f week"; 
			if(d<365) return d.format!"%.1f month"; 
			return (d/gregorianDaysInYear).format!"%.1f year"; 
		} void test_shortDurationText()
		{
			Time[] t = [
				123*pico(second),
				123*nano(second),
				123*micro(second),
				123*milli(second),
				12*second,
				129*second,
				12*minute,
				123*minute,
				12*hour,
				123*hour,
				10*day,
				100*day,
				1000*day,
				10000*day
			]; 
			
			t.map!shortDurationText.each!print; 
		} 
		
		
		//UNICODE /////////////////////////////////////////////
		
		/*
			int[] UnicodeEmojiBlocks = [
				0x00A,           //Latin1 supplement
				
				0x203, 0x204,			 //2000-206F General Punctuation
				0x212, 0x213,			 //2100-214F Letterlike Symbols
				0x219, 0x21A,			 //2190-21FF Arrows
				
				0x231, 0x232,    //2300-23FF Miscellaneous Technical
				0x23C,
				0x23E, 0x23F,
				
				0x24C,           //2460-24FF Enclosed Alphanumerics
				
				0x25A, 0x25B, 0x25C, //25A0-25FF Geometric Shapes
				0x25F,
				
				0x260, 0x261, 0x262, 0x263, 0x264, 0x265, 0x266, 0x267,  //2600-26FF Miscellaneous Symbols
				0x269, 0x26A, 0x26B, 0x26C, 0x26D, 0x26E, 0x26F,
				
				0x270, 0x271, 0x272, 0x273, 0x274, 0x275, 0x276,         //2700-27BF Dingbats
				0x279, 0x27A, 0x27B,
				
				0x293,  //2900-297F Supplemental Arrows-B
				
				0x2B0, 0x2B1, //2B00-2BFF Miscellaneous Symbols and Arrows
				0x2B5,
				
				0x303,        //3000-303FCJK Symbols and Punctuation
				
				0x329,        //3200-32FF Enclosed CJK Letters and Months
				
				0x1F00,       //1F000-1F02F Mahjong Tiles
				
				0x1F0C,       //1F0A0-1F0FF Playing Cards
				
				0x1F17, 0x1F18, 0x1F19, //1F100-1F1FF Enclosed Alphanumeric Supplement
				
				0x1F20, 0x1F21, 0x1F22, 0x1F23, //1F200-1F2FF Enclosed Ideographic Supplement
				0x1F25,
				
				//1F300-1F5FF Miscellaneous Symbols and Pictographs
				0x1F30, 0x1F31, 0x1F32, 0x1F33, 0x1F34, 0x1F35, 0x1F36, 0x1F37, 0x1F38, 0x1F39,
				0x1F3A, 0x1F3B, 0x1F3C, 0x1F3D, 0x1F3E, 0x1F3F, 0x1F40, 0x1F41, 0x1F42, 0x1F43,
				0x1F44, 0x1F45, 0x1F46, 0x1F47, 0x1F48, 0x1F49, 0x1F4A, 0x1F4B, 0x1F4C, 0x1F4D,
				0x1F4E, 0x1F4F, 0x1F50, 0x1F51, 0x1F52, 0x1F53, 0x1F54, 0x1F55, 0x1F56, 0x1F57,
				0x1F58, 0x1F59, 0x1F5A, 0x1F5B, 0x1F5C, 0x1F5D, 0x1F5E, 0x1F5F,
				
				0x1F60, 0x1F61, 0x1F62, 0x1F63, 0x1F64, //1F600-1F64F Emoticons (Emoji)
				
				0x1F68, 0x1F69, 0x1F6A, 0x1F6B, 0x1F6C, 0x1F6D, 0x1F6E, 0x1F6F, //1F680-1F6FF Transport and Map Symbols
				
				//1F900-1F9FF Supplemental Symbols and Pictographs
				0x1F91, 0x1F92, 0x1F93, 0x1F94, 0x1F95, 0x1F96, 0x1F97, 0x1F98, 0x1F99, 0x1F9A, 0x1F9B, 0x1F9C, 0x1F9D, 0x1F9E, 0x1F9F
			];
		*/
		
	}version(/+$DIDE_REGION+/all) {
			
		//unicodeStandardLetter: these can be stylized by fonts, such as Arial/Consolas/Times. Other characters are usually the same, eg.: Chineese chars.
		//containt ranges of latin, greek, cyril, armenian chars. These can have different representations across each fonts
		bool isUnicodeStandardLetter(dchar ch)
		{
			immutable unicodeStandardLetterRanges = [
				[0x0020, 0x024F], [0x0370, 0x058F], [0x1C80, 0x1C8F], [0x1E00, 0x1FFF],
				[0x2C60, 0x2C7F], [0x2DE0, 0x2DFF], [0xA640, 0xA69F], [0xA720, 0xA7FF],
				[0xAB30, 0xAB6F] 
			]; 
			foreach(const r; unicodeStandardLetterRanges)
			if(ch.inRange(r[0], r[1])>=r[0] && ch<=r[1]) return true; 
			return false; 
		} 
		
		enum UnicodePrivateUserAreaBase = 0xF0000; 
		
		bool isUnicodeColorChar(dchar ch)
		{
			enforce(0, "not impl"); 
			return false; 
		} 
		
		/*
			******************************
					 * Return !=0 if unicode alpha.
					 * Use table from C99 Appendix D.
		*/
		///Copied from: ldc-master\dmd\root\utf.d
		bool isUniAlpha(dchar c)
		{
			static immutable wchar[2][] ALPHA_TABLE =
			[
				//Todo: discover these chars. Decide if they are useful or not.
				[0x00AA, 0x00AA],[0x00B5, 0x00B5],[0x00B7, 0x00B7],[0x00BA, 0x00BA],[0x00C0, 0x00D6],[0x00D8, 0x00F6],[0x00F8, 0x01F5],[0x01FA, 0x0217],
				[0x0250, 0x02A8],[0x02B0, 0x02B8],[0x02BB, 0x02BB],[0x02BD, 0x02C1],[0x02D0, 0x02D1],[0x02E0, 0x02E4],[0x037A, 0x037A],[0x0386, 0x0386],
				[0x0388, 0x038A],[0x038C, 0x038C],[0x038E, 0x03A1],[0x03A3, 0x03CE],[0x03D0, 0x03D6],[0x03DA, 0x03DA],[0x03DC, 0x03DC],[0x03DE, 0x03DE],
				[0x03E0, 0x03E0],[0x03E2, 0x03F3],[0x0401, 0x040C],[0x040E, 0x044F],[0x0451, 0x045C],[0x045E, 0x0481],[0x0490, 0x04C4],[0x04C7, 0x04C8],
				[0x04CB, 0x04CC],[0x04D0, 0x04EB],[0x04EE, 0x04F5],[0x04F8, 0x04F9],[0x0531, 0x0556],[0x0559, 0x0559],[0x0561, 0x0587],[0x05B0, 0x05B9],
				[0x05BB, 0x05BD],[0x05BF, 0x05BF],[0x05C1, 0x05C2],[0x05D0, 0x05EA],[0x05F0, 0x05F2],[0x0621, 0x063A],[0x0640, 0x0652],[0x0660, 0x0669],
				[0x0670, 0x06B7],[0x06BA, 0x06BE],[0x06C0, 0x06CE],[0x06D0, 0x06DC],[0x06E5, 0x06E8],[0x06EA, 0x06ED],[0x06F0, 0x06F9],[0x0901, 0x0903],
				[0x0905, 0x0939],[0x093D, 0x094D],[0x0950, 0x0952],[0x0958, 0x0963],[0x0966, 0x096F],[0x0981, 0x0983],[0x0985, 0x098C],[0x098F, 0x0990],
				[0x0993, 0x09A8],[0x09AA, 0x09B0],[0x09B2, 0x09B2],[0x09B6, 0x09B9],[0x09BE, 0x09C4],[0x09C7, 0x09C8],[0x09CB, 0x09CD],[0x09DC, 0x09DD],
				[0x09DF, 0x09E3],[0x09E6, 0x09F1],[0x0A02, 0x0A02],[0x0A05, 0x0A0A],[0x0A0F, 0x0A10],[0x0A13, 0x0A28],[0x0A2A, 0x0A30],[0x0A32, 0x0A33],
				[0x0A35, 0x0A36],[0x0A38, 0x0A39],[0x0A3E, 0x0A42],[0x0A47, 0x0A48],[0x0A4B, 0x0A4D],[0x0A59, 0x0A5C],[0x0A5E, 0x0A5E],[0x0A66, 0x0A6F],
				[0x0A74, 0x0A74],[0x0A81, 0x0A83],[0x0A85, 0x0A8B],[0x0A8D, 0x0A8D],[0x0A8F, 0x0A91],[0x0A93, 0x0AA8],[0x0AAA, 0x0AB0],[0x0AB2, 0x0AB3],
				[0x0AB5, 0x0AB9],[0x0ABD, 0x0AC5],[0x0AC7, 0x0AC9],[0x0ACB, 0x0ACD],[0x0AD0, 0x0AD0],[0x0AE0, 0x0AE0],[0x0AE6, 0x0AEF],[0x0B01, 0x0B03],
				[0x0B05, 0x0B0C],[0x0B0F, 0x0B10],[0x0B13, 0x0B28],[0x0B2A, 0x0B30],[0x0B32, 0x0B33],[0x0B36, 0x0B39],[0x0B3D, 0x0B43],[0x0B47, 0x0B48],
				[0x0B4B, 0x0B4D],[0x0B5C, 0x0B5D],[0x0B5F, 0x0B61],[0x0B66, 0x0B6F],[0x0B82, 0x0B83],[0x0B85, 0x0B8A],[0x0B8E, 0x0B90],[0x0B92, 0x0B95],
				[0x0B99, 0x0B9A],[0x0B9C, 0x0B9C],[0x0B9E, 0x0B9F],[0x0BA3, 0x0BA4],[0x0BA8, 0x0BAA],[0x0BAE, 0x0BB5],[0x0BB7, 0x0BB9],[0x0BBE, 0x0BC2],
				[0x0BC6, 0x0BC8],[0x0BCA, 0x0BCD],[0x0BE7, 0x0BEF],[0x0C01, 0x0C03],[0x0C05, 0x0C0C],[0x0C0E, 0x0C10],[0x0C12, 0x0C28],[0x0C2A, 0x0C33],
				[0x0C35, 0x0C39],[0x0C3E, 0x0C44],[0x0C46, 0x0C48],[0x0C4A, 0x0C4D],[0x0C60, 0x0C61],[0x0C66, 0x0C6F],[0x0C82, 0x0C83],[0x0C85, 0x0C8C],
				[0x0C8E, 0x0C90],[0x0C92, 0x0CA8],[0x0CAA, 0x0CB3],[0x0CB5, 0x0CB9],[0x0CBE, 0x0CC4],[0x0CC6, 0x0CC8],[0x0CCA, 0x0CCD],[0x0CDE, 0x0CDE],
				[0x0CE0, 0x0CE1],[0x0CE6, 0x0CEF],[0x0D02, 0x0D03],[0x0D05, 0x0D0C],[0x0D0E, 0x0D10],[0x0D12, 0x0D28],[0x0D2A, 0x0D39],[0x0D3E, 0x0D43],
				[0x0D46, 0x0D48],[0x0D4A, 0x0D4D],[0x0D60, 0x0D61],[0x0D66, 0x0D6F],[0x0E01, 0x0E3A],[0x0E40, 0x0E5B],[0x0E81, 0x0E82],[0x0E84, 0x0E84],
				[0x0E87, 0x0E88],[0x0E8A, 0x0E8A],[0x0E8D, 0x0E8D],[0x0E94, 0x0E97],[0x0E99, 0x0E9F],[0x0EA1, 0x0EA3],[0x0EA5, 0x0EA5],[0x0EA7, 0x0EA7],
				[0x0EAA, 0x0EAB],[0x0EAD, 0x0EAE],[0x0EB0, 0x0EB9],[0x0EBB, 0x0EBD],[0x0EC0, 0x0EC4],[0x0EC6, 0x0EC6],[0x0EC8, 0x0ECD],[0x0ED0, 0x0ED9],
				[0x0EDC, 0x0EDD],[0x0F00, 0x0F00],[0x0F18, 0x0F19],[0x0F20, 0x0F33],[0x0F35, 0x0F35],[0x0F37, 0x0F37],[0x0F39, 0x0F39],[0x0F3E, 0x0F47],
				[0x0F49, 0x0F69],[0x0F71, 0x0F84],[0x0F86, 0x0F8B],[0x0F90, 0x0F95],[0x0F97, 0x0F97],[0x0F99, 0x0FAD],[0x0FB1, 0x0FB7],[0x0FB9, 0x0FB9],
				[0x10A0, 0x10C5],[0x10D0, 0x10F6],[0x1E00, 0x1E9B],[0x1EA0, 0x1EF9],[0x1F00, 0x1F15],[0x1F18, 0x1F1D],[0x1F20, 0x1F45],[0x1F48, 0x1F4D],
				[0x1F50, 0x1F57],[0x1F59, 0x1F59],[0x1F5B, 0x1F5B],[0x1F5D, 0x1F5D],[0x1F5F, 0x1F7D],[0x1F80, 0x1FB4],[0x1FB6, 0x1FBC],[0x1FBE, 0x1FBE],
				[0x1FC2, 0x1FC4],[0x1FC6, 0x1FCC],[0x1FD0, 0x1FD3],[0x1FD6, 0x1FDB],[0x1FE0, 0x1FEC],[0x1FF2, 0x1FF4],[0x1FF6, 0x1FFC],[0x203F, 0x2040],
				[0x207F, 0x207F],[0x2102, 0x2102],[0x2107, 0x2107],[0x210A, 0x2113],[0x2115, 0x2115],[0x2118, 0x211D],[0x2124, 0x2124],[0x2126, 0x2126],
				[0x2128, 0x2128],[0x212A, 0x2131],[0x2133, 0x2138],[0x2160, 0x2182],[0x3005, 0x3007],[0x3021, 0x3029],[0x3041, 0x3093],[0x309B, 0x309C],
				[0x30A1, 0x30F6],[0x30FB, 0x30FC],[0x3105, 0x312C],[0x4E00, 0x9FA5],[0xAC00, 0xD7A3],
			]; 
					
			size_t high = ALPHA_TABLE.length - 1; 
			//Shortcut search if c is out of range
			size_t low = (c < ALPHA_TABLE[0][0] || ALPHA_TABLE[high][1] < c) ? high + 1 : 0; 
			//Binary search
			while(low <= high)
			{
				size_t mid = (low + high) >> 1; 
				if(c < ALPHA_TABLE[mid][0])
				high = mid - 1; 
				else if(ALPHA_TABLE[mid][1] < c)
				low = mid + 1; 
				else
				{
					assert(ALPHA_TABLE[mid][0] <= c && c <= ALPHA_TABLE[mid][1]); 
					return true; 
				}
			}
			return false; 
		} 
		
		enum TextEncoding	 { ANSI, UTF8	,            UTF32BE,            UTF32LE,	UTF16BE, UTF16LE   } //UTF32 must be checked BEFORE UTF16
		private const encodingHeaders =	[""	  ,	"\xEF\xBB\xBF", "\x00\x00\xFE\xFF",	"\xFF\xFE\x00\x00", "\xFE\xFF", "\xFF\xFE"]; 
		private const encodingCharSize=	[1	  , 1             ,                  4,                  4,          2,          2]; 
		
		TextEncoding encodingOf(const string s, TextEncoding def = TextEncoding.UTF8, string* withoutEnc=null)
		{
			foreach(i, hdr; encodingHeaders)
			{
				if(!hdr.empty && s.startsWith(hdr))
				{
					if(withoutEnc) *withoutEnc = s[hdr.length..$]; 
					return cast(TextEncoding)(i); 
				}
			}
					
			//default encoding
			if(withoutEnc) *withoutEnc = s; 
			return def; 
		} 
		
		string stripEncoding(const string s)
		{
			string res; 
			encodingOf(s, TextEncoding.UTF8, &res); 
			return res; 
		} 
		
		string ansiToUTF8(string s)
		{ wstring ws; .transcode(cast(Windows1252String)s, ws); return ws.toUTF8; } 
		
		dstring ansiToUTF32(string s)
		{ wstring ws; .transcode(cast(Windows1252String)s, ws); return ws.toUTF32; } 
		
		string textToUTF8(string s, TextEncoding defaultEncoding=TextEncoding.UTF8)
		{
			//my version handles BOM
			final switch(encodingOf(s, defaultEncoding, &s))
			{
				case TextEncoding.ANSI	: return s.ansiToUTF8; 
				case TextEncoding.UTF8	: return s; 
				case TextEncoding.UTF16LE	: auto ws 	= cast(wstring	)s; return ws	.toUTF8;  //Todo: cast can fail. What to do then?
				case TextEncoding.UTF16BE	: auto ws 	= cast(wstring	)s; return ws.byteSwap	.toUTF8; 
				case TextEncoding.UTF32LE	: auto ds 	= cast(dstring	)s; return ds	.toUTF8; 
				case TextEncoding.UTF32BE	: auto ds 	= cast(dstring	)s; return ds.byteSwap	.toUTF8; 
			}
		} 
		
		dstring textToUTF32(string s, TextEncoding defaultEncoding=TextEncoding.UTF8)
		{
			//my version handles BOM
			final switch(encodingOf(s, defaultEncoding, &s))
			{
				case TextEncoding.ANSI	: return s.ansiToUTF32; 
				case TextEncoding.UTF8	: return s.toUTF32; 
				case TextEncoding.UTF16LE	: auto ws = cast(wstring)s; return ws	.toUTF32;  //Todo: cast can fail. What to do then?
				case TextEncoding.UTF16BE	: auto ws = cast(wstring)s; return ws.byteSwap	.toUTF32; 
				case TextEncoding.UTF32LE	: return cast(dstring)s; 
				case TextEncoding.UTF32BE	: auto ds = cast(dstring)s; return ds.byteSwap.toUTF32; 
			}
		} 
		
		char[4] fourC(string s)
		{
			//Link: https://forum.dlang.org/post/aypjoqdrwglcufdgseex@forum.dlang.org
			if(s.length >= 4)
			return s[0 .. 4]; 
			char[4] res = 0; 
			res[0 .. s.length] = s; 
			return res; 
		} 
		
		uint fourCC(string s)
		{ return s.take(4).enumerate.map!(a => a.value << cast(uint)a.index*8).sum; } 
		
		auto splitDLang(string src, string separ)
		{
			auto res = [""]; 
			string stack; 
			
			void skip(size_t n)
			{
				foreach(i; 0..n)
				{
					if(src.empty) break; 
					
					if(/+remove comments+/["\n", "*/", "+/"].any!(a=>stack.startsWith(a)))
					{ if(!res.back.endsWith(' ')) res.back ~= ' '; }
					else
					res.back ~= src.front; 
					
					src.popFront; 
				}
			} 
			
			while(src.length)
			{
				if(src.length>=2 && src[0]=='\\')
				if(stack.length && stack[0].among('"', '\'') && src[1]==stack[0])
				{ skip(2); continue; /+ignore string escapes+/}
				
				auto cp = commonPrefix(stack, src); 
				if(cp.length && cp.back.among('+','*')) cp.length--; 
				if(cp.length)
				{ skip(cp.length); stack = stack[cp.length..$]; continue; /+block closes+/}
				
				if(stack.empty || [`}`, `)`, "]"].any!(a => stack.startsWith(a)))
				{
					if(const i = src[0].among('{', '[', '(', '"', '\'', '`'))
					{
						stack =        ['\0', '}', ']', ')', '"', '\'', '`'][i] ~ stack; 
						skip(1); continue; /+block begins+/
					}
					foreach(i, s; ["//", "/*", "/+"])
					if(src.startsWith(s))
					{
						stack = ["\n", "*/", "+/"][i] ~ stack; 
						skip(2); continue; /+comment begins+/
					}
				}
				
				if(stack.startsWith("+/") && src.startsWith("/+"))
				{ stack = "+/" ~ stack; skip(2); continue; /+nested comment begins+/}
				
				if(!separ.empty && stack.empty && src.startsWith(separ))
				{ src.popFront; res ~= ""; continue; /+separator processed+/}
				
				skip(1); 
			}
			
			if(stack=="\n") stack = ""; 
			enforce(stack.empty, "splitDLang: bad syntax"); 
			
			foreach(ref s; res) s = s.strip; 
			return res; 
		} 
		
		static removeDLangComments(string src)
		{ return src.splitDLang("")[0].strip; } 
		
		void unittest_splitDLang()
		{
			//Todo: proper unittest when starting.  It's a critical test...
			writeln(splitDLang(`i=0,(5,6)"\""/+,/++/+/`, `,`)); 
			writeln(splitDLang(`i=0,()//5`, `,`)); 
			writeln(splitDLang(`0>=i>=6, 3`, `,`)); 
			
			const s = "int a = 5, b = 10; /* comment, not a split point */ int c = 15, d = 20; // Another comment, still not a split point
	float e = 3.14, f = 2.71; void func(int x, int y) { int arr[2] = {1, 2}; if (x == y) { x++; } }"; 
			writeln(splitDLang(s, `,`)); 
		} 
	}
}version(/+$DIDE_REGION Hashing+/all)
{
	//Hashing//////////////////////////////////////////
	version(/+$DIDE_REGION+/all) {
		/// Returns a string that represents the identity of the parameter: and object or a pointer or a string
		/// If a string is passed, the caller must ensure if it's system wide unique.
		string identityStr(T)(in T a)
		{
			//identityStr /////////////////////////
			static if(isSomeString!T	) return a; 
			else static if(isPointer!T   	) return a is null ? "" : format!"%s(%s)"(PointerTarget!T.stringof, cast(void*)a); 
			else static if(is(T == class)	) return a is null ? "" : format!"%s(%s)"(T.stringof, cast(void*)a); 
			else static if(is(T == typeof(null))	) return ""; 
			else static assert(0, "identityStr() unhandled type: "~T.stringof); 
		} 
		
		//some really symple hashes.
		
		uint uintHash(uint h0, string haFun)(string s)
		{
			uint h = h0; 
			foreach(a; s.byChar.map!"cast(uint)a") h = mixin(haFun); 
			return h; 
		} 
		
		uint djb2Hash(bool opt)(string s)
		{
			//http://www.cse.yorku.ca/~oz/hash.html
			return s.uintHash!(5381, opt ? "(h << 5) + h + a" : "h*33u + a"); 
		} 
		
		uint sdbmHash(bool opt)(string s)
		{
			//http://www.cse.yorku.ca/~oz/hash.html
			return s.uintHash!(0, opt ? "(h << 6) + (h << 16) - h + a" : "h* 65599u + a"); 
		} 
		
		/// It's fast
		uint tokenHash()(string s)
		{
			switch(s.length) {
				case 0: return 0; 
				case 1: return *(cast(ubyte*)s.ptr)+7123u; 
				case 2: return *(cast(ushort*)s.ptr)+2541281u; 
				default: return s.sdbmHash!1; 
			}
		} 
		
		enum bigPrime = 1515485863; 
		
		uint hashCombine(uint c1, uint c2)
		{ return c1*bigPrime+c2; } 
		
		void testSmallHashes()
		{
			//Todo: unittest
			auto data = [
				`(`, `{`, `[`, "/*", "/+", "//", `'`, `"`, "`", "r\"", "q\"", "q{", 
							`#line `, `#!`, `)`, `}`, `]`, "\0", "\x1A", "__EOF__"
			].replicate(10); 
			
			data.take(20).each!(s => print(s.djb2Hash!0, s.djb2Hash!1, s.sdbmHash!0, s.sdbmHash!1, s.xxh32, s.hashOf)); 
			
			
			uint h; 
			void f0() { h += data.map!(djb2Hash!0).sum; } 
			void f1() { h += data.map!(djb2Hash!1).sum; } 
			void f2() { h += data.map!(sdbmHash!0).sum; } 
			void f3() { h += data.map!(sdbmHash!1).sum; } 
			void f4() { h += data.map!(xxh32).sum; } 
			void f5() { h += data.map!(hashOf).sum; } 
			void f6() { h += data.map!(tokenHash).sum; } 
					
			import std.datetime.stopwatch; 
			benchmark!(f0, f1, f2, f3, f4, f5, f6)(1000).each!print; 
		} 
		
			//! crc32 //////////////////////////////////////////////////////////////////
		
		@trusted pure nothrow
		uint crc32(in void[] source, uint seed = 0xffffffff)
		{
			//Todo: 0b binary syntax highlight bug in 0x hex literals
			immutable uint[256] CRC32tab = 
			[
				0x00000000, 0x77073096, 0xee0e612c, 0x990951ba,	0x076dc419, 0x706af48f,
				0xe963a535, 0x9e6495a3, 0x0edb8832, 0x79dcb8a4,	0xe0d5e91e, 0x97d2d988,
				0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91,	0x1db71064, 0x6ab020f2,  
				0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb,	0xf4d4b551, 0x83d385c7,
				0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec,	0x14015c4f, 0x63066cd9,
				0xfa0f3d63, 0x8d080df5, 0x3b6e20c8, 0x4c69105e,	0xd56041e4, 0xa2677172,
				0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,	0x35b5a8fa, 0x42b2986c,
				0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75,	0xdcd60dcf, 0xabd13d59,
				0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116,	0x21b4f4b5, 0x56b3c423,
				0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808,	0xc60cd9b2, 0xb10be924,
				0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,	0x76dc4190, 0x01db7106,
				0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f,	0x9fbfe4a5, 0xe8b8d433,
				0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818,	0x7f6a0dbb, 0x086d3d2d,
				0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162,	0x856530d8, 0xf262004e,
				0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457,	0x65b0d9c6, 0x12b7e950,
				0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49,	0x8cd37cf3, 0xfbd44c65,
				0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2,	0x4adfa541, 0x3dd895d7,
				0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc,	0xad678846, 0xda60b8d0,
				0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9,	0x5005713c, 0x270241aa,
				0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3,	0xb966d409, 0xce61e49f,
				0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4,	0x59b33d17, 0x2eb40d81,
				0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6,	0x03b6e20c, 0x74b1d29a,
				0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683,	0xe3630b12, 0x94643b84,
				0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d,	0x0a00ae27, 0x7d079eb1,
				0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe,	0xf762575d, 0x806567cb,
				0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0,	0x10da7a5a, 0x67dd4acc,
				0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,	0xd6d6a3e8, 0xa1d1937e,
				0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767,	0x3fb506dd, 0x48b2364b,
				0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60,	0xdf60efc3, 0xa867df55,
				0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a,	0x256fd2a0, 0x5268e236,
				0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f,	0xc5ba3bbe, 0xb2bd0b28,
				0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31,	0x2cd99e8b, 0x5bdeae1d,
				0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a,	0x9c0906a9, 0xeb0e363f,
				0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14,	0x7bb12bae, 0x0cb61b38,
				0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21,	0x86d3d2d4, 0xf1d4e242,
				0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b,	0x6fb077e1, 0x18b74777,
				0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c,	0x8f659eff, 0xf862ae69,
				0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee,	0x4e048354, 0x3903b3c2,
				0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db,	0xaed16a4a, 0xd9d65adc,
				0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5,	0x47b2cf7f, 0x30b5ffe9,
				0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6,	0xbad03605, 0xcdd70693,
				0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8,	0x5d681b02, 0x2a6f2b94,
				0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
			]; 
					
			uint r = seed; 
					
			foreach(const d; cast(ubyte[])source)
			r = CRC32tab[cast(ubyte)r^d]^(r>>>8); 
					
			return ~r; 
		} 
		
		uint crc32uc(in void[] source, uint seed = 0xffffffff)
		{ return crc32(uc(cast(string)source)); } 
		
	}version(/+$DIDE_REGION+/all) {
		@trusted nothrow uint xxh32(in void[] source, uint seed = 0)//Todo: it must run at compile time too
		{
			//! xxh32 //////////////////////////////////////////////////////
			//a fast hashing function
			
			//Source:	https://github.com/repeatedly/xxhash-d/blob/master/src/xxhash.d
			//https://code.google.com/p/xxhash/
			//Copyright: Masahiro Nakagawa 2014-.
				enum 	Prime32_1 = 2654435761U,
					Prime32_2 = 2246822519U,
					Prime32_3 = 3266489917U,
					Prime32_4 = 668265263U,
					Prime32_5 = 374761393U; 
				
				enum UpdateValuesRound = q{
				v1 += loadUint(srcPtr) * Prime32_2; 	 v1 = rol(v1, 13); 	 v1 *= Prime32_1; 	 srcPtr++; 
				v2 += loadUint(srcPtr) * Prime32_2; 	 v2 = rol(v2, 13); 	 v2 *= Prime32_1; 	 srcPtr++; 
				v3 += loadUint(srcPtr) * Prime32_2; 	 v3 = rol(v3, 13); 	 v3 *= Prime32_1; 	 srcPtr++; 
				v4 += loadUint(srcPtr) * Prime32_2; 	 v4 = rol(v4, 13); 	 v4 *= Prime32_1; 	 srcPtr++; 
			}; 
				
				enum FinishRound = q{
				while(ptr < end) {
					result += *ptr * Prime32_5; 
					result = rol(result, 11) * Prime32_1; 
					ptr++; 
				}
				result ^= result >> 15; 	 result *= Prime32_2; 
				result ^= result >> 13; 	 result *= Prime32_3; 
				result ^= result >> 16; 
			}; 
				
				static void xxh_rounds(ref const(uint)*	src, const(uint)* limit, uint* v) nothrow
			{
													 //RCX,                RDX,      R8
				//Intel byteorder only!
				if(1)
				{
					do {
						v[0] += *(src  ) * Prime32_2; 	 v[0] = rol(v[0], 13); 	 v[0] *= Prime32_1; 
						v[1] += *(src+1) * Prime32_2; 	 v[1] = rol(v[1], 13); 	 v[1] *= Prime32_1; 
						v[2] += *(src+2) * Prime32_2; 	 v[2] = rol(v[2], 13); 	 v[2] *= Prime32_1; 
						v[3] += *(src+3) * Prime32_2; 	 v[3] = rol(v[3], 13); 	 v[3] *= Prime32_1;  src+=4; 
					}
					while(src <= limit); 
				}
				else
				{
					//Todo: this is not working
					asm {
							mov EAX, 2246822519;    	//XMM4 : Prime2
							movd XMM4, EAX; 	
							pshufd XMM4, XMM4, 0; 	
								
							mov EAX, 2654435761; 	//XMM5 : Prime1
							movd XMM5, EAX; 	
							pshufd XMM5, XMM5, 0; 	
								
							movdqu XMM0, [R8]; 	//XMM0 : v
								
							mov RAX, [RCX]; 	//RAX : src
								//RDX : limit
								
						loop: 
							movdqu XMM1, [RAX];  add RAX, 16;  //load src
								
							movdqa XMM2, XMM1;                  //mul with Prime2
							punpckldq XMM1, XMM1; 
							punpckldq XMM2, XMM2; 
							pmuludq XMM1, XMM4; 
							pmuludq XMM2, XMM4; 
							pshufd XMM1, XMM2, 0x88; 
								
							paddd XMM0, XMM1;                   //add to v
								
							movdqa XMM2, XMM0; 
							pslld XMM2, 13;              //rol(v, 13)
							psrld XMM0, 32-13; 
							por XMM0, XMM2; 
								
							movdqa XMM2, XMM0;                  //mul with Prime1
							punpckldq XMM0, XMM0; 
							punpckldq XMM2, XMM2; 
							pmuludq XMM0, XMM5; 
							pmuludq XMM2, XMM5; 
							pshufd XMM0, XMM2, 0x88; 
								
							cmp RAX, RDX; 
							jbe loop; 
								
							mov [RCX], RAX;      //write back src
								
							movdqu [R8], XMM0;   //write back state
					} 
				}
			} 
				
				@safe pure nothrow
				uint loadUint(in uint* source)
			{
				version(LittleEndian)
				return *source; 
				else
				return swapEndian(*source); 
			} 
			
				auto srcPtr = cast(const(uint)*)source.ptr; 
				auto srcEnd = cast(const(uint)*)(source.ptr + source.length); 
				uint result = void; 
			
				if(source.length >= 16)
			{
				auto limit = srcEnd - 4; 
				auto v = [
					seed + Prime32_1 + Prime32_2,
					seed + Prime32_2,
					seed,
					seed - Prime32_1
				]; 
				
				xxh_rounds(srcPtr, limit, v.ptr); 
				
				result = rol(v[0], 1) + rol(v[1], 7) + rol(v[2], 12) + rol(v[3], 18); 
			}
			else
			{ result = seed + Prime32_5; }
				
				result += source.length; 
				
				while(srcPtr+1 <= srcEnd) {
				result += loadUint(srcPtr) * Prime32_3; 
				result = rol(result, 17) * Prime32_4; 
				srcPtr++; 
			}
			
				auto ptr = cast(const(ubyte)*)srcPtr; 
				auto end = cast(const(ubyte)*)srcEnd; 
			
				mixin(FinishRound); 
			
				return result; 
				//Todo: xxh unittest
		} 
		
		uint xxh32uc(in void[] source, uint seed = 0)
		{ return xxh32(uc(cast(string)source)); } 
		
		void benchmark_xxh32()
		{
				size_t len = 1; 
				while(len<2_000_000_000)
			{
				auto data = new ubyte[len]; 
				auto t0 = QPS; 
				cast(void)xxh32(data); 
				auto t1 = QPS; 
						
				writefln("len = %10d   time = %6.3f   MB/s = %9.3f", len, t1-t0, len/(t1-t0)/1024/1024); 
						
				len = iceil(len*1.5); 
			}
			
			/+
				string[] strings = File(`c:\d\libs\het\utils.d`).readLines;
						
				immutable str = "Hello";
				import core.internal.hash;
				enum test = bytesHash(str.ptr, str.length, 0);
				print(test);
						
				foreach(batch; 0..5){
					auto t0 = QPS;
					foreach(const s; strings) s.xxh(0);
					auto t1 = QPS;
					foreach(const s; strings) hashOf(s);
					auto t2 = QPS;
						
					print("xxh: ", t1-t0, "hashOf: ", t2-t1);
				}
			+/
		} 
		
	}version(/+$DIDE_REGION+/all) {
		struct XXH3
		{
			static: //! xxh3 ///////////////////////////////////////////////////////////////////
					version(/+$DIDE_REGION+/all) {
				enum 	STRIPE_LEN 	=  64,
					SECRET_CONSUME_RATE	=   8,  /*nb of secret bytes consumed at each accumulation*/
					ACC_NB	= STRIPE_LEN / ulong.sizeof,
					SECRET_MERGEACCS_START 	=  11,
					SECRET_LASTACC_START	=   7,  /*not aligned on 8, last secret is different from acc & scrambler*/
					MIDSIZE_STARTOFFSET	=   3,
					MIDSIZE_LASTOFFSET	=  17,
					SECRET_SIZE_MIN	= 136,
					SECRET_DEFAULT_SIZE	= 192,
					
					PRIME32_1 = 0x9E3779B1U,	 PRIME64_1 = 0x9E3779B185EBCA87UL,
					PRIME32_2 = 0x85EBCA77U,	 PRIME64_2 = 0xC2B2AE3D27D4EB4FUL,
					PRIME32_3 = 0xC2B2AE3DU,	 PRIME64_3 = 0x165667B19E3779F9UL,
					PRIME32_4 = 0x27D4EB2FU,	 PRIME64_4 = 0x85EBCA77C2B2AE63UL,
					PRIME32_5 = 0x165667B1U,	 PRIME64_5 = 0x27D4EB2F165667C5UL; 
						
				immutable ulong[ACC_NB] INIT_ACC = [PRIME32_3, PRIME64_1, PRIME64_2, PRIME64_3, PRIME64_4, PRIME32_2, PRIME64_5, PRIME32_1]; 
						
				immutable ubyte[SECRET_DEFAULT_SIZE] kSecret = 
				[
					0xb8, 0xfe, 0x6c, 0x39, 0x23, 0xa4, 0x4b, 0xbe, 0x7c, 0x01, 0x81, 0x2c, 0xf7, 0x21, 0xad, 0x1c,
					0xde, 0xd4, 0x6d, 0xe9, 0x83, 0x90, 0x97, 0xdb, 0x72, 0x40, 0xa4, 0xa4, 0xb7, 0xb3, 0x67, 0x1f,
					0xcb, 0x79, 0xe6, 0x4e, 0xcc, 0xc0, 0xe5, 0x78, 0x82, 0x5a, 0xd0, 0x7d, 0xcc, 0xff, 0x72, 0x21,
					0xb8, 0x08, 0x46, 0x74, 0xf7, 0x43, 0x24, 0x8e, 0xe0, 0x35, 0x90, 0xe6, 0x81, 0x3a, 0x26, 0x4c,
					0x3c, 0x28, 0x52, 0xbb, 0x91, 0xc3, 0x00, 0xcb, 0x88, 0xd0, 0x65, 0x8b, 0x1b, 0x53, 0x2e, 0xa3,
					0x71, 0x64, 0x48, 0x97, 0xa2, 0x0d, 0xf9, 0x4e, 0x38, 0x19, 0xef, 0x46, 0xa9, 0xde, 0xac, 0xd8,
					0xa8, 0xfa, 0x76, 0x3f, 0xe3, 0x9c, 0x34, 0x3f, 0xf9, 0xdc, 0xbb, 0xc7, 0xc7, 0x0b, 0x4f, 0x1d,
					0x8a, 0x51, 0xe0, 0x4b, 0xcd, 0xb4, 0x59, 0x31, 0xc8, 0x9f, 0x7e, 0xc9, 0xd9, 0x78, 0x73, 0x64,
					0xea, 0xc5, 0xac, 0x83, 0x34, 0xd3, 0xeb, 0xc3, 0xc5, 0x81, 0xa0, 0xff, 0xfa, 0x13, 0x63, 0xeb,
					0x17, 0x0d, 0xdd, 0x51, 0xb7, 0xf0, 0xda, 0x49, 0xd3, 0x16, 0x55, 0x26, 0x29, 0xd4, 0x68, 0x9e,
					0x2b, 0x16, 0xbe, 0x58, 0x7d, 0x47, 0xa1, 0xfc, 0x8f, 0xf8, 0xb8, 0xd1, 0x7a, 0xd0, 0x31, 0xce,
					0x45, 0xcb, 0x3a, 0x8f, 0x95, 0x16, 0x04, 0x28, 0xaf, 0xd7, 0xfb, 0xca, 0xbb, 0x4b, 0x40, 0x7e,
				]; 
						
				ulong readLE64(in void* memPtr)
				{ return *cast(const ulong*)memPtr; } 
				uint readLE32(in void* memPtr)
				{ return *cast(const uint*)memPtr; } 
				void writeLE64(void* memPtr, ulong val)
				{ *cast(ulong*)memPtr = val; } 
						
				ulong mult32to64(T, U)(T x, U y)
				{ return (cast(ulong)cast(uint)(x) * cast(ulong)cast(uint)(y)); } 
						
				ulong[2] mult64to128(ulong lhs, ulong rhs)
				{
					/*First calculate all of the cross products.*/
					const	lo_lo 	= mult32to64(lhs & 0xFFFFFFFF, rhs & 0xFFFFFFFF),
						hi_lo 	= mult32to64(lhs >> 32       , rhs & 0xFFFFFFFF),
						lo_hi 	= mult32to64(lhs & 0xFFFFFFFF, rhs >> 32),
						hi_hi 	= mult32to64(lhs >> 32       , rhs >> 32),
						
						/*Now add the products together. These will never overflow.*/
						cross 	= (lo_lo >> 32) + (hi_lo & 0xFFFFFFFF) + lo_hi,
						upper 	= (hi_lo >> 32) + (cross >> 32       ) + hi_hi,
						lower 	= (cross << 32) | (lo_lo & 0xFFFFFFFF); 
							
					return [lower, upper]; 
				} 
						
				import std.bitmanip : swapEndian; 
				uint swap32(uint x)
				{ return x.swapEndian; } 
				ulong swap64(ulong x)
				{ return x.swapEndian; } 
						
				uint rotl32(uint x, uint r)
				{ return ((x << r) | (x >> (32 - r))); } 
				ulong rotl64(ulong x, uint r)
				{ return ((x << r) | (x >> (64 - r))); } 
						
				ulong mul128_fold64(ulong lhs, ulong rhs)
				{
					auto a = mult64to128(lhs, rhs); 
					return a[0] ^ a[1]; 
				} 
						
				ulong xorshift64(ulong v64, uint shift)
				{ return v64 ^ (v64 >> shift); } 
						
				ulong avalanche(ulong h64)
				{
					h64 = xorshift64(h64, 37); 
					h64 *= 0x165667919E3779F9UL; 
					h64 = xorshift64(h64, 32); 
					return h64; 
				} 
						
				ulong avalanche64(ulong h64)
				{
					h64 ^= h64 >> 33; 
					h64 *= PRIME64_2; 
					h64 ^= h64 >> 29; 
					h64 *= PRIME64_3; 
					h64 ^= h64 >> 32; 
					return h64; 
				} 
						
				ulong rrmxmx(ulong h64, ulong len)
				{
					/*this mix is inspired by Pelle Evensen's rrmxmx*/
					h64 ^= rotl64(h64, 49) ^ rotl64(h64, 24); 
					h64 *= 0x9FB21C651E98DF25UL; 
					h64 ^= (h64 >> 35) + len; 
					h64 *= 0x9FB21C651E98DF25UL; 
					return xorshift64(h64, 28); 
				} 
						
			}version(/+$DIDE_REGION+/all) {
						
				ulong mix16B(in ubyte* input, in ubyte* secret, ulong seed64)
				{
					const 	input_lo = readLE64(input    ),
						input_hi = readLE64(input + 8); 
					return mul128_fold64(
						input_lo ^ (readLE64(secret    ) + seed64),
						input_hi ^ (readLE64(secret + 8) - seed64)
					); 
				} 
						
				ulong mix2Accs(const ulong* acc, in ubyte* secret)
				{
					return mul128_fold64(
						acc[0] ^ readLE64(secret    ),
										acc[1] ^ readLE64(secret + 8) 
					); 
				} 
						
				ulong mergeAccs(in ulong* acc, in ubyte* secret, ulong start)
				{ return avalanche(start + iota(4).map!(i => mix2Accs(acc + 2 * i, secret + 16 * i)).sum); } 
						
				void accumulate512_scalar(ulong* acc/+presumed aligned+/, in ubyte* input, in ubyte* secret)
				{
					//Note: a XXH3.readLE64 nem inlineolodik, csak akkor, ha az XXH3-on belulrol van meghivva!!!
					foreach(i; 0..ACC_NB)
					{
						auto data_val = readLE64(input + 8 * i), //Todo: const
								 data_key = data_val ^ readLE64(secret + i * 8); 
						acc[i ^ 1] += data_val; /*swap adjacent lanes*/
						acc[i    ] += mult32to64(data_key & 0xFFFFFFFF, data_key >> 32); 
					}
				} 
						
				void accumulate512_sse(ulong* acc/+presumed aligned+/, in ubyte* input, in ubyte* secret)
				{
					enum ver = "opt"/+"unroll2"+/; 
					
					auto inp = cast(const ulong*) input, sec = cast(const ulong*) secret; 
					
					static if(ver=="normal")
					{
						//1250ms
						foreach(i; 0..8)
						{
							const v = inp[i],  k = sec[i] ^ v; 
							acc[i  ] += (k & 0xFFFFFFFF) * (k >> 32); 
							acc[i^1] += v; 
						}
					}
					
					static if(ver=="unroll2")
					{
						//1150ms
						for(int i; i<8; i+=2)
						{
							 //a bit faster, because	only 1 write into acc
							const v0 = inp[i	 ]	,	 v1 = inp[i+1]	,
										k0 = sec[i	 ] ^ v0,		k1 = sec[i+1] ^ v1; 
							const a0 = k0 & 0xFFFFFFFF,	 a1 = k1 & 0xFFFFFFFF,
										b0 = k0 >> 32       ,	 b1 = k1 >> 32; 
							acc[i  ] += a0*b0 + v1; 
							acc[i+1] += a1*b1 + v0; 
						}
					}
					
					static if(ver=="opt")
					asm {
						/+Bug: LDC__ASM__BUG+/
						//860ms
						
						/+R8 acc, RDX input, RCX secret.+/
						
						//LDC 1.35: Must load these regs manually. Assumptions aren't work anymore.
						mov R8, acc; mov RDX, input; mov RCX, secret; 
						
						//free: RAX, RCX, RDX, R8, R9, R10, R11, XMM0-XMM5
						prefetcht0 [R8 + 0x200]; 
						mov R11, 0;  L0: ; 
							movdqu	XMM0,	[RDX + R11]; 	  //v0, v1
							movdqu	XMM1,	[RCX + R11]; pxor XMM1,	XMM0; 	  //k0, k1,  also a0, a1
							movdqa	XMM2,	XMM1; psrlq XMM2, 32; 		//b0, b1
							pmuludq	XMM1,	XMM2; 
							shufps	XMM0,	XMM0, 0b01_00_11_10;            //v1, v0 swapped
							movdqu	XMM3,	[R8 + R11]; 
							paddq	XMM0,	XMM1; 
							paddq	XMM0,	XMM3; 
							movdqu	[R8 +	R11], XMM0; 
						add R11, 0x10; cmp R11, 0x40;  jnz L0; 
					} 
				} 
						
				auto accumulate512 = &accumulate512_sse; 
						
				void accumulate(ulong* acc,in ubyte* input,in ubyte* secret, size_t nbStripes)
				{
					foreach(n; 0..nbStripes) {
						const inp = input + n * STRIPE_LEN; 
						//Opt: PREFETCH(in + PREFETCH_DIST);
						accumulate512(acc, inp, secret + n * SECRET_CONSUME_RATE); 
					}
				} 
						
				void scrambleAcc_scalar(ulong* acc/+presumed aligned+/, in ubyte* secret)
				{
					foreach(i; 0..ACC_NB)
					acc[i] = (xorshift64(acc[i], 47) ^ readLE64(secret + 8 * i)) * PRIME32_1; 
				} 
						
				void hashLong_internal_loop(ulong* acc, in ubyte* input, size_t len, in ubyte* secret, size_t secretSize)
				{
					const nbStripesPerBlock = (secretSize - STRIPE_LEN) / SECRET_CONSUME_RATE,
								block_len = STRIPE_LEN * nbStripesPerBlock,
								nb_blocks = (len - 1) / block_len; 
							
					foreach(n; 0..nb_blocks) {
						accumulate(acc, input + n * block_len, secret, nbStripesPerBlock); 
						scrambleAcc_scalar(acc, secret + secretSize - STRIPE_LEN); 
					}
							
					/*last partial block*/
					const nbStripes = ((len - 1) - (block_len * nb_blocks)) / STRIPE_LEN; 
					accumulate(acc, input + nb_blocks * block_len, secret, nbStripes); 
							
					/*last stripe*/
					const p = input + len - STRIPE_LEN; 
					accumulate512(acc, p, secret + secretSize - STRIPE_LEN - SECRET_LASTACC_START); 
				} 
						
				void initCustomSecret_scalar(void* customSecret, ulong seed64)
				{
					const kSecretPtr = kSecret.ptr; 
							
					const nbRounds = SECRET_DEFAULT_SIZE / 16; 
					foreach(i; 0..nbRounds) {
						auto lo = readLE64(kSecretPtr + 16	* i	) + seed64,
								 hi = readLE64(kSecretPtr + 16	* i + 8)	- seed64; 
						writeLE64(customSecret + 16 * i	, lo); 
						writeLE64(customSecret + 16 * i + 8, hi); 
					}
				} 
			}version(/+$DIDE_REGION+/all) {
				ulong generate64_internal(in ubyte* input, size_t len, ulong seed, in ubyte* secret, size_t secretLen)
				{
								
					ulong len_0to16()
					{
						ulong len_1to3()
						{
							const	c1	= input[0],
								c2	= input[len >> 1],
								c3	= input[len - 1],
								combined	= (c1 << 16) | (c2	<< 24) | (c3 <<  0) | (len <<  8),
								bitflip	= (readLE32(secret)	^ readLE32(secret + 4)) + seed,
								keyed	= combined ^ bitflip; 
							return avalanche64(keyed); 
						} 
								
						ulong len_4to8()
						{
							seed ^= cast(ulong)swap32(cast(uint)seed) << 32; 
							const 	input1	= readLE32(input),
								input2	= readLE32(input + len - 4),
								bitflip	= (readLE64(secret + 8) ^ readLE64(secret + 16)) - seed,
								input64	= input2 + ((cast(ulong)input1) << 32),
								keyed	= input64 ^ bitflip; 
							return rrmxmx(keyed, len); 
						} 
								
						ulong len_9to16()
						{
							const 	bitflip1 = (readLE64(secret + 24) ^ readLE64(secret + 32)) + seed,
								bitflip2	= (readLE64(secret + 40) ^ readLE64(secret + 48)) - seed,
								input_lo	= readLE64(input) ^ bitflip1,
								input_hi	= readLE64(input + len - 8) ^ bitflip2,
								acc	= len + swap64(input_lo) + input_hi + mul128_fold64(input_lo, input_hi); 
							return avalanche(acc); 
						} 
								
						if(len >	8) return len_9to16; 
						if(len >=	4) return len_4to8; 
						if(len) return len_1to3; 
						return avalanche64(seed ^ (readLE64(secret + 56) ^ readLE64(secret + 64))); 
					} 
							
					ulong len_17to128()
					{
						ulong acc = len * PRIME64_1; 
						if(len > 32) {
							if(len > 64) {
								if(len > 96) {
									acc += mix16B(input + 48      , secret +  96, seed); 
									acc += mix16B(input + len - 64, secret + 112, seed); 
								}
								acc += mix16B(input + 32      , secret + 64, seed); 
								acc += mix16B(input + len - 48, secret + 80, seed); 
							}
							acc += mix16B(input + 16      , secret + 32, seed); 
							acc += mix16B(input + len - 32, secret + 48, seed); 
						}
						acc += mix16B(input +        0, secret +  0, seed); 
						acc += mix16B(input + len - 16, secret + 16, seed); 
								
						return avalanche(acc); 
					} 
							
					ulong len_129to240()
					{
						ulong acc = len * PRIME64_1; 
								
						foreach(i; 0..8)
						acc += mix16B(input + (16 * i), secret + (16 * i), seed); 
						acc = avalanche(acc); 
								
						const nbRounds = len / 16; 
						foreach(i; 8..nbRounds)
						acc += mix16B(input + (16 * i), secret + (16 * (i - 8)) + MIDSIZE_STARTOFFSET, seed); 
								
						/*last bytes*/
						acc += mix16B(input + len - 16, secret + SECRET_SIZE_MIN - MIDSIZE_LASTOFFSET, seed); 
						return avalanche(acc); 
					} 
							
					ulong hashLong_withSeed()
					{
						ubyte[SECRET_DEFAULT_SIZE] secret; 
						initCustomSecret_scalar(secret.ptr, seed); 
						ulong[ACC_NB] acc = INIT_ACC; 
								
						hashLong_internal_loop(acc.ptr, input, len, secret.ptr, secret.length); 
						return mergeAccs(acc.ptr, secret.ptr + SECRET_MERGEACCS_START, len * PRIME64_1); 
					} 
							
					if(len <=  16) return len_0to16; 
					if(len <= 128) return len_17to128; 
					if(len <= 240) return len_129to240; 
					return hashLong_withSeed; 
				} 
						
				ulong generate64(in void* input, size_t len, ulong seed=0)
				{ return generate64_internal(cast(const ubyte*)input, len, seed, kSecret.ptr, kSecret.sizeof); } 
						
				void selftest()
				{
					const lengths = [
						0, 1, 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 
						64, 65, 95, 96, 97, 127, 128, 129, 239, 240, 241, 255, 256, 257, 511, 512, 513 
					]; 
					const results = [
						0x2d06800538d394c2, 0x0fe498556034255e, 0xe72a1171b2f83a1a, 0x4366019a3823dccf, 
						0x4b48e4f5d655d132, 0xd8fae3d7a0c3754b, 0x0f5f4187bb0b7b70, 0x9c84d18587e10b2c,
						0x00d94b281bba523e, 0x127c8cf284a2ac8d, 0x7d553d9cba2010cb, 0xc6c419714f465d1b,
						0x974813de6f540eb4, 0xf9e1b4199e9b6ccb, 0x35691ab299857461, 0x40fcd44dc3049173,
						0x62cd23a00db02a2c, 0x969b2300ea907020, 0x8382b2fb55a25b3e, 0x9e0f9ae9891b607c,
						0x86cf3e266cdbe658, 0xf529e83950d89de1, 0xf2e216f8f8e10db5, 0xfba432f419d27644,
						0x3339807d2a21fd56, 0xc4bdbce6762c4ac7, 0x795d6a504c1cfecc, 0xa6bfe3904a35af5c,
						0xeb5c4226460ec2c9, 0xcb803070815f2ab2, 0x21b7914a0ab293ec, 0xa56955aa7e5d2e12,
						0x40273dbf31e227c9 
					]; 
					foreach(i, len; lengths)
					{
						const str = iota(len).map!(j => cast(char)(j*i % 51 + ' ')).to!string,
									seed = i%5,
									hash = .xxh3(str, seed); 
						enforce(hash==results[i], "FATAL ERROR: XXH3_64 failed at len:"~len.text); 
					}
				} 
			}
		} 
		
		ulong xxh3_64(in void[] data, ulong seed=0)
		{ return XXH3.generate64(data.ptr, data.length, seed); } 
		
		alias xxh3 = xxh3_64; 
		
		uint xxh3_32(in void[] data, ulong seed=0)
		{ return cast(uint)xxh3(data, seed); } 
		
	}
}

version(/+$DIDE_REGION Colors+/all)
{
	version(/+$DIDE_REGION Color processing+/all)
	{
		
		/+
			use to_unorm, from_unorm
			auto floatToRgb(T, int N)(in Vector!(T, N) x)	 if(is(T == float))
			{ return Vector!(ubyte, N)(iround(x.clamp(0, 1)*255)); } 
			auto rgbToFloat(T, int N)(in Vector!(T, N) x)	 if(is(T == ubyte))
			{ return x * (1.0f/255); } 
		+/
		
		
		template transformArray(alias fun, alias sseFun, bool inplace=false)
		{
			alias SrcElementType = const(Parameters!fun[0]), 	SrcElementTypeSSE = const(Parameters!sseFun[0]),
			DstElementType = Parameters!fun[1],	DstElementTypeSSE = Parameters!sseFun[1]; 
			
			enum batchSize = SrcElementTypeSSE.sizeof / SrcElementType.sizeof; 
			static assert(SrcElementType.sizeof * batchSize == SrcElementTypeSSE.sizeof); 
			static assert(DstElementType.sizeof * batchSize == DstElementTypeSSE.sizeof); 
			
			//Todo: Do automatic tests using scalar and simd versions.
			
			void classic2(in SrcElementType[] src, DstElementType[] dst)
			{
				for(
					auto 	pSrc	= src.ptr,
						pEnd 	= pSrc + src.length,
						pDst	= dst.ptr
					; pSrc<pEnd 
					; pDst++, pSrc++
				)
				{ fun(*pSrc, *pDst); }
			} 
			
			void transformArray2(in SrcElementType[] src, DstElementType[] dst)
			{
				size_t 	i = 0; 
				const 	len = src.length; 
				
				//do non-simd until src is aligned
				enum alignMask = 0xF; 
				while(i<len)
				{
					auto p = src.ptr+i; 
					if((cast(size_t)p & alignMask) == 0) break; 
					fun(src[i], dst[i]); 
					i++; 
				}
				
				//do simd until possible
				const batchEnd = i + ((len-i)/(batchSize))*batchSize; 
				while(i<batchEnd)
				{
					sseFun(
						*(cast(SrcElementTypeSSE*)(src.ptr + i)),
						*(cast(DstElementTypeSSE*)(dst.ptr + i))
					); 
					i+=batchSize; 
				}
				/+
					Opt: When the compiler is NOT optimizing,
					this loop could be optimized in ASM 
				+/
				/+Opt: The inplace version should use only 1 parameter+/
				
				//do the remaining with non-simd
				while(i<len)
				{
					fun(src[i], dst[i]); 
					i++; 
				}
			} 
			
			auto classic(in SrcElementType[] src, DstElementType[] optionalDst = null)
			{
				static if(inplace)
				{
					static assert(SrcElementType.sizeof==DstElementType.sizeof); 
					auto dst = cast(DstElementType[])src; 
				}
				else
				{ auto dst = optionalDst.length ? optionalDst : uninitializedArray!(DstElementType[])(src.length); }
				classic2(src, dst); 
				return dst; 
			} 
			
			auto transformArray(in SrcElementType[] src, DstElementType[] optionalDst = null)
			{
				static if(inplace)
				{
					static assert(SrcElementType.sizeof==DstElementType.sizeof); 
					auto dst = cast(DstElementType[])src; 
				}
				else
				{ auto dst = optionalDst.length ? optionalDst : uninitializedArray!(DstElementType[])(src.length); }
				transformArray2(src, dst); 
				return dst; 
			} 
			
		} 
		
		private
		{ mixin asmFunctions; } 
		
		void rgb_to_rgba_scalar(const ref RGB src, ref RGBA dst)
		{ dst = src.rgb1; } 
		void rgb_to_rgba_simd(const ref ubyte16[3] src, ref ubyte16[4] dst)
		{
			enum _ = 255; 
			enum ubyte16 	mask0	= mixin([0, 1, 2, _, 3, 4, 5, _, 6, 7, 8, _, 9, 10, 11, _]),
				mask1a	= mixin([12, 13, 14, _, 15, _, _, _, _, _, _, _, _, _, _, _]),
				mask1b	= mixin([_, _, _, _, _, 0, 1, _, 2, 3, 4, _, 5, 6, 7, _]),
				mask2a	= mixin([8, 9, 10, _, 11, 12, 13, _, 14, 15, _, _, _, _, _, _]),
				mask2b 	= mixin([_, _, _, _, _, _, _, _, _, _, 0, _, 1, 2, 3, _]),
				mask3	= mixin([4, 5, 6, _, 7, 8, 9, _, 10, 11, 12, _, 13, 14, 15, _]),
				alpha	= mixin([0, 0, 0, 255].replicate(4)); 
			dst[0] = pshufb(src[0], mask0) | alpha; 
			dst[1] = pshufb(src[0], mask1a) | pshufb(src[1], mask1b) | alpha; 
			dst[2] = pshufb(src[1], mask2a) | pshufb(src[2], mask2b) | alpha; 
			dst[3] = pshufb(src[2], mask3) | alpha; 
		} 
		alias rgb_to_rgba = transformArray!(rgb_to_rgba_scalar, rgb_to_rgba_simd); 
		
		void rgba_to_bgra_scalar(const ref RGBA src, ref RGBA dst)
		{ dst = src.bgra; } 
		void rgba_to_bgra_simd(const ref ubyte16 src, ref ubyte16 dst)
		{
			static immutable ubyte16 mask = [2, 1, 0, 3, 6, 5, 4, 7, 10, 9, 8, 11, 14, 13, 12, 15]; 
			dst = pshufb(src, mask); 
		} 
		alias rgba_to_bgra 	= transformArray!(rgba_to_bgra_scalar, rgba_to_bgra_simd),
		rgba_to_bgra_inplace 	= transformArray!(rgba_to_bgra_scalar, rgba_to_bgra_simd, true); 
		
		void rgba_invert_rgb_scalar(const ref RGBA src, ref RGBA dst)
		{ dst = RGBA(dst.raw ^ 0xFFFFFF); } 
		void rgba_invert_rgb_simd(const ref ubyte16 src, ref ubyte16 dst)
		{
			static immutable ubyte16 mask = mixin([255, 255, 255, 0].replicate(4)); 
			dst = src ^ mask; 
		} 
		alias rgba_invert_rgb 	= transformArray!(rgba_invert_rgb_scalar, rgba_invert_rgb_simd),
		rgba_invert_rgb_inplace 	= transformArray!(rgba_invert_rgb_scalar, rgba_invert_rgb_simd, true); 
		
		
		void rgb_to_bgra_scalar(const ref RGB src, ref RGBA dst)
		{ dst = src.bgr1; } 
		void rgb_to_bgra_simd(const ref ubyte16[3] src, ref ubyte16[4] dst)
		{
			enum _ = 255; 
			enum ubyte16 	mask0	= mixin([2, 1, 0, _, 5, 4, 3, _, 8, 7, 6, _, 11, 10, 9, _]),
				mask1a	= mixin([14, 13, 12, _, _, _, 15, _, _, _, _, _, _, _, _, _]),
				mask1b	= mixin([_, _, _, _, 1, 0, _, _, 4, 3, 2, _, 7, 6, 5, _]),
				mask2a	= mixin([10, 9, 8, _, 13, 12, 11, _, _, 15, 14, _, _, _, _, _]),
				mask2b 	= mixin([_, _, _, _, _, _, _, _, 0, _, _, _, 3, 2, 1, _]),
				mask3	= mixin([6, 5, 4, _, 9, 8, 7, _, 12, 11, 10, _, 15, 14, 13, _]),
				alpha	= mixin([0, 0, 0, 255].replicate(4)); 
			dst[0] = pshufb(src[0], mask0) | alpha; 
			dst[1] = pshufb(src[0], mask1a) | pshufb(src[1], mask1b) | alpha; 
			dst[2] = pshufb(src[1], mask2a) | pshufb(src[2], mask2b) | alpha; 
			dst[3] = pshufb(src[2], mask3) | alpha; 
		} 
		alias rgb_to_bgra = transformArray!(rgb_to_bgra_scalar, rgb_to_bgra_simd); 
		
		
		void l_to_rgba_scalar(const ref ubyte src, ref RGBA dst)
		{ dst = RGBA(src, src, src, 255); } 
		void l_to_rgba_simd(const ref ubyte16[1] src, ref ubyte16[4] dst)
		{
			enum _ = 255; 
			enum ubyte16 	mask0	= mixin([0, 0, 0, _, 1, 1, 1, _, 2, 2, 2, _, 3, 3, 3, _]),
				mask1	= mixin([4, 4, 4, _, 5, 5, 5, _, 6, 6, 6, _, 7, 7, 7, _]),
				mask2	= mixin([8, 8, 8, _, 9, 9, 9, _, 10, 10, 10, _, 11, 11, 11, _]),
				mask3	= mixin([12, 12, 12, _, 13, 13, 13, _, 14, 14, 14, _, 15, 15, 15, _]),
				alpha	= mixin([0, 0, 0, 255].replicate(4)); 
			dst[0] = pshufb(src[0], mask0) | alpha; 
			dst[1] = pshufb(src[0], mask1) | alpha; 
			dst[2] = pshufb(src[0], mask2) | alpha; 
			dst[3] = pshufb(src[0], mask3) | alpha; 
		} 
		alias l_to_rgba = transformArray!(l_to_rgba_scalar, l_to_rgba_simd); 
		
		
		
		void RGBtoRGBA(bool flipRG = false)(const(ubyte16)* src, ubyte16* dst, in size_t srcLen)
		{
			//Bug: unaligned ofs and size!!!
			//https://stackoverflow.com/questions/7194452/fast-vectorized-conversion-from-rgb-to-bgra
			auto w = srcLen/3; 
			while(w-- > 0)
			{
				enum shuf(int x) = ubyte16(
					mixin(
						iota(12)	.map!(i => (x+i)&15)
							.chunks(3)
							.map!("a"~(flipRG ? ".retro" : "")~".array~0")
							.join
					)
				); 
				enum ubyte16 	alpha	 = mixin([0, 0, 0, 0xff].replicate(4)),
					loHalf	 = mixin([0xff	].replicate(8) ~ [0	].replicate(8)),
					hiHalf	 = mixin([0	].replicate(8) ~ [0xff	].replicate(8)); 
				//print(alpha, loHalf, hiHalf);
				const in0 = src[0];  	dst[0] = pshufb(in0	, shuf!0	) | alpha; 
				const in1 = src[1]; 	dst[1] = pshufb(in0 & hiHalf | in1 & loHalf	, shuf!12	) | alpha; 
				const in2 = src[2]; 	dst[2] = pshufb(in1 & hiHalf | in2 & loHalf	, shuf!8	) | alpha; 
					dst[3] = pshufb(in2	, shuf!4	) | alpha; 
				src += 3; 	dst += 4; 
			}
			//Opt: palignr sucks. Why? Debug it! asm{ int 3; } //ou = palignr!8(in1, in0);
		} 
		alias BGRtoRGBA = RGBtoRGBA!true; 
		alias RGBtoBGRA = BGRtoRGBA; 
		
		void LtoRGBA(const(ubyte16)* src, ubyte16* dst, size_t srcLen)
		{
			//Bug: unaligned ofs and size!!!
			while(srcLen-- > 0)
			{
				enum ubyte16 	alpha	= mixin([0, 0, 0, 0xff].replicate(4)),
					spread(int x) 	= mixin(iota(4).map!(i => [x+i].replicate(4)).join); 
				
				const tmp = src[0]; 	src += 1; 
				static foreach(i; 0..4) { dst[i] = pshufb(tmp, spread!(i*4)) | alpha; }	dst += 4; 
			}
		} 
		alias LtoBGRA = LtoRGBA; 
		
		//Todo: test suite for all the bitmap stuff
		
		
		/+
			RGBA[] rgb_to_rgba(in RGB[] src)
					{
						T0; scope(exit) DT.print;
						return src.map!"a.rgb1".array;
					}
		+/
		
		/// changes/converts the ComponentType of a color  support float and ubyte, ignores others.
		auto convertPixelComponentType(CT, A)(auto ref A a)
		{
			alias ST = ScalarType!A; 
			
			static if(is(ST == ubyte) && is(CT == float))
			return a.generateVector!(CT, a => a * (1.0f/255)); 
			else static if(is(ST == float) && is(CT == ubyte))
			return a.generateVector!(CT, a => a * 255	      ); 
			else return a.generateVector!(CT, a => a	      ); 
		} 
		
		/// converts between different number of color components
		auto convertPixelChannels(int DstLen, A)(auto ref A a)
		{
			alias 	SrcLen	= VectorLength!A,
				T	= ScalarType!A,
				VT	= Vector!(T, DstLen); 
			
			//Src: L              LA        RGB       RGBA Dst:
			immutable table =
			[
				["a          ", "a.r   ", "a.l   ", "a.l  "], //L
				["VT(a,*)    ", "a     ", "a.l1  ", "a.la "],	//LA
				["VT(a,a,a)  ", "a.rrr ", "a     ", "a.rgb"],	//RGB
				["VT(a,a,a,*)", "a.rrrg", "a.rgb1", "a    "]
			]; 	//RGBA
			
			enum one = is(T==ubyte) ? "255" : "1"; 
			//* : ubyte alpha, and float alpha is different!!!
			
			static foreach(i; 1..5)
			static if(DstLen == i)
			static foreach(j; 1..5)
			static if(SrcLen == j)
			return mixin(table[i-1][j-1].replace("*", one)); 
			
			static assert(VectorLength!(typeof(return)) == DstLen, "DstLen mismatch"); 
		} 
		
		//converts a color to another color type (different channels and type)
		auto convertPixel(B, A)(auto ref A a)
		{
			/+
				Todo: auto ref is not good, because it wont work with const(RGB).
						If I replace auto ref with const ref, 100 errors will pop.
			+/
			
			alias DstType	= ScalarType	!B,
			DstLen	= VectorLength!B; 
			
			return a.	convertPixelComponentType!DstType //2 step conversion: type and channels
				.convertPixelChannels!DstLen; 
		} 
		
		auto convertPixel(B, A)(in A a)
		{
			/+Todo: auto ref thing is fixed with this, but it seems lame...+/
			return convertPixel(cast()a); 
		} 
		
		auto hsvToRgb(A)(in A val) if(isColor!A)
		{
			static if(A.length==4) {
				return A(val.rgb.hsvToRgb, val.a); //preserve alpha
			}
			else {
				static if(is(A.ComponentType == float)) return hsv2rgb(val.xyz); 
				else return val.rgbToFloat.hsvToRgb.floatToRgb; 
			}
		} 
		auto rgbToHsv(A)(in A val) if(isColor!A)
		{
			static if(A.length==4) {
				return A(val.rgb.rgbToHsv, val.a); //preserve alpha
			}
			else {
				static if(is(A.ComponentType == float)) return rgb2hsv(val.xyz); 
				else return val.rgbToFloat.hsvToRgb.floatToRgb; 
			}
		} 
		
		auto hsvToRgb_prev(float H, float S, float V)
		{
			//0..1 range
			int sel; 
			auto	mod	= modf(H * 6, sel),
				a 	= vec4(
				V,
				V * (1 - S),
				V * (1 - S * mod),
				V * (1 - S * (1 - mod))
			); 
			switch(sel) {
				case 0: 	return a.xwy; 
				case 1: 	return a.zxy; 
				case 2: 	return a.yxw; 
				case 3: 	return a.yzx; 
				case 4: 	return a.wyx; 
				case 5: 	return a.xyz; 
				default: 	return a.xwy; 
			}
		} 
		
		vec3 rgb2hsv(vec3 c)
		{
			 vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0); 
			 vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g)); 
			 vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r)); 
					
			 float d = q.x - min(q.w, q.y); 
			 float e = 1.0e-10; 
			 return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x); 
		} 
		
		vec3 hsv2rgb(vec3 c)
		{
			 vec4 K = vec4(1.0f, 2.0f / 3.0f, 1.0f / 3.0f, 3.0f); 
			 vec3 p = abs(fract(c.xxx + K.xyz) * 6.0f - K.www); 
			 return mix(K.xxx, clamp(p - K.xxx, 0.0f, 1.0f), c.y) * c.z; 
		} 
		
		
		
		auto toGrayscale(T, N)(in Vector!(T, N) x)
		{
			static if(N==3) return x.lll; 
			else static if(N==4) return x.llla; 
			else return x; 
		} 
		
		char toGrayscaleAscii(float luma)
		{
			immutable charMap = " .:-=+*#%@"; 
			return charMap[luma.quantize!(charMap.length)]; 
		} 
		
		char toGrayscaleAscii(ubyte luma)
		{ return toGrayscaleAscii(luma * (1.0f/255)); } 
		
		auto textColorFor(RGB c)
		{ return c.l>=128 ? clBlack : clWhite; } 
		
		auto blackOrWhiteFor(RGB c)
		{ return textColorFor(c); } 
		
		auto darken(in RGB a, float t) { return mix(a, clBlack, t); } 
		auto lighten(in RGB a, float t) { return mix(a, clWhite, t); } 
		alias brighten = lighten; 
		
		struct RGBSum
		{
			float totalWeight = 0; 
			vec3 totalColor; 
			
			void add(RGB c, float weight = 1)
			{
				totalColor += c*weight; 
				totalWeight += weight; 
			} 
			
			RGB avg()
			{ return avg(clBlack); } 
			
			RGB avg(lazy RGB def)
			{ return totalWeight ? RGB((totalColor*(1.0f/totalWeight)).iround) : def; } 
		} 
		
		
		/+
			
			
			
			int rgbSad(const RGB a, const RGB b){
				int res;
				res += abs((a.r)-(b.r));
				res += abs((a.g)-(b.g));
				res += abs((a.b)-(b.b));
				return res;
			}
			
			RGB rgbMax(const RGB a, const RGB b){ return RGB(max(a.r, b.r), max(a.g, b.g), max(a.b, b.b)); }
			RGB rgbMin(const RGB a, const RGB b){ return RGB(min(a.r, b.r), min(a.g, b.g), min(a.b, b.b)); }
			
			RGB rainbow_HUE(float H){
				auto h2 = (H-iFloor(H))*8,
						 i0 = iTrunc(h2),
						 i1 = (i0+1)&7,
						 fr = fract(h2);
				
				RGB clr = rgbLerp(clRainbow[i0], clRainbow[i1], iRemapClamp(fr, 1, 0, 0, 255));
				//interpolate rainbow palette
				
				return clr;
			}
			
			RGB HSVToRGB_rainbow(float H, float S, float V){
				auto h2 = (H-iFloor(H))*8,
						 i0 = iTrunc(h2),
						 i1 = (i0+1)&7,
						 fr = fract(h2);
				
				RGB clr = rgbLerp(clRainbow[i0], clRainbow[i1], iRemapClamp(fr, 1, 0, 0, 255));
				//interpolate rainbow palette
				
				clr = rgbLerp(RGB(0xFFFFFF), clr, iRemapClamp(S, 1, 0, 0, 255)); //saturate
				clr = rgbLerp(RGB(0x000000), clr, iRemapClamp(V, 1, 0, 0, 255)); //darken
				
				enforce(false, "HSVToRGB_rainbow() ez total fos");
				return clr;
			}
		+/
		
		void drawPhaseAveragingTests(Dr)(Dr dr)
		{
			const π = PIf; 
			
			auto range = iota(0, 2*π, 0.01f); 
			void plot(alias fun)(float y0=0, float ySize=1)
			{
				foreach(i, y; range.map!(fun).enumerate)
				dr.lineTo(i*0.05f, (y0 + y/ySize)*-10, i); 
			} 
			
			dr.lineWidth = .1; 
			dr.color = clAqua; 	plot!(α=>cos(α).remap(-1, 1, 0, 1)); 
			dr.color = clYellow; 	plot!(α=>sin(α).remap(-1, 1, 0, 1)); 
			dr.color = clWhite; 	plot!(α=>((atan(-sin(α), -cos(α)) + π)/(π*2))); 
			
			dr.translate(0, 10); 
			dr.color = clRed; 	plot!(α=>vec3(α/π/2, 1, 1).hsvToRgb.r); 
			dr.color = clLime; 	plot!(α=>vec3(α/π/2, 1, 1).hsvToRgb.g); 
			dr.color = clBlue; 	plot!(α=>vec3(α/π/2, 1, 1).hsvToRgb.b); 
			dr.color = clWhite; 	plot!(α=>vec3(α/π/2, 1, 1).hsvToRgb.rgbToHsv.x); 
			dr.translate(0, 10); 
			
			const β = time.value(10*second).fract.remap(0, 1, 0, 2*π).sin*π/2; 
			dr.color = clWhite; 	plot!(α=>((atan(-sin(avg(α, β)), -cos(avg(α, β))) + π)/(π*2))); 
			dr.color = clFuchsia; 	plot!(
				(α){
					auto v = vec2(
						avg(sin(α), sin(β)), 
						avg(cos(α), cos(β))
					).normalize; 
					return ((atan(-v.x, -v.y) + π)/(π*2)); 
				} 
			); 
			dr.color = clOrange; 	plot!(
				(α){
					auto v = avg(
						vec3(α/π/2, 1, 1).hsvToRgb,
						vec3(β/π/2, 1, 1).hsvToRgb
					); 
					return v.rgbToHsv.x; 
				} 
			); 
			
			dr.pop; dr.pop; 
			//conclusion: 2 phase sin+cos is the best and sin(a+b) = sin(a)+sin(b)
		} 
	}version(/+$DIDE_REGION Color constants+/all)
	{
		//Todo: all these should be static immutable
		/+Todo: LEGO periodic table of colors+/
		version(/+$DIDE_REGION classic delphi palette+/all)
		{
			immutable
			clBlack	= (RGB(0x000000)),
			clMaroon	= (RGB(0x000080)),
			clGreen	= (RGB(0x008000)),
			clOlive	= (RGB(0x008080)),
			clNavy	= (RGB(0x800000)),
			clPurple	= (RGB(0x800080)),
			clTeal	= (RGB(0x808000)),
			clGray	= (RGB(0x808080)),
			clSilver	= (RGB(0xC0C0C0)),
			clRed	= (RGB(0x0000FF)),
			clLime	= (RGB(0x00FF00)),
			clYellow	= (RGB(0x00FFFF)),
			clBlue	= (RGB(0xFF0000)),
			clFuchsia	= (RGB(0xFF00FF)),
			clAqua	= (RGB(0xFFFF00)),
			clLtGray	= (RGB(0xC0C0C0)),
			clDkGray	= (RGB(0x808080)),
			clWhite	= (RGB(0xFFFFFF)),
				
			clSkyBlue	= (RGB(0xF0CAA6)),
			clMoneyGreen	= (RGB(0xC0DCC0)); 
		}
		
		version(/+$DIDE_REGION standard vga palette+/all)
		{
			immutable
			clVgaBlack	= (RGB(0x000000)),
			clVgaDarkGray	= (RGB(0x555555)),
			clVgaLowBlue	= (RGB(0xAA0000)),
			clVgaHighBlue	= (RGB(0xFF5555)),
			clVgaLowGreen	= (RGB(0x00AA00)),
			clVgaHighGreen	= (RGB(0x55FF55)),
			clVgaLowCyan	= (RGB(0xAAAA00)),
			clVgaHighCyan	= (RGB(0xFFFF55)),
			clVgaLowRed	= (RGB(0x0000AA)),
			clVgaHighRed	= (RGB(0x5555FF)),
			clVgaLowMagenta	= (RGB(0xAA00AA)),
			clVgaHighMagenta	= (RGB(0xFF55FF)),
			clVgaBrown	= (RGB(0x0055AA)),
			clVgaYellow	= (RGB(0x55FFFF)),
			clVgaLightGray	= (RGB(0xAAAAAA)),
			clVgaWhite	= (RGB(0xFFFFFF)); 
		}
		
		version(/+$DIDE_REGION C64 palette+/all)
		{
			immutable
			clC64Black	= (RGB(0x000000)),
			clC64White	= (RGB(0xFFFFFF)),
			clC64Red	= (RGB(0x354374)),
			clC64Cyan	= (RGB(0xBAAC7C)),
			clC64Purple	= (RGB(0x90487B)),
			clC64Green	= (RGB(0x4F9764)),
			clC64Blue	= (RGB(0x853240)),
			clC64Yellow	= (RGB(0x7ACDBF)),
			clC64Orange	= (RGB(0x2F5B7B)),
			clC64Brown	= (RGB(0x00454f)),
			clC64Pink	= (RGB(0x6572a3)),
			clC64DGrey	= (RGB(0x505050)),
			clC64Grey	= (RGB(0x787878)),
			clC64LGreen	= (RGB(0x8ed7a4)),
			clC64LBlue	= (RGB(0xbd6a78)),
			clC64LGrey	= (RGB(0x9f9f9f)); 
		}
		
		version(/+$DIDE_REGION WOW palette+/all)
		{
			immutable
			clWowGrey	= (RGB(0x9d9d9d)),
			clWowWhite	= (RGB(0xffffff)),
			clWowGreen	= (RGB(0x00ff1e)),
			clWowBlue	= (RGB(0xdd7000)),
			clWowPurple	= (RGB(0xee35a3)),
			clWowOrange	= (RGB(0x0080ff)),
			clWowPink	= (RGB(0xBA8CF4)),
			clWowGold	= (RGB(0x80cce5)); 
		}
		
		version(/+$DIDE_REGION VIMpalette+/all)
		{
			immutable
			clVimBlack	= (RGB(0x141312)),
			clVimBlue	= (RGB(0xDAA669)),
			clVimGreen	= (RGB(0x4ACAB9)),
			clVimTeal	= (RGB(0xB1C070)),
			clVimRed	= (RGB(0x534ED5)),
			clVimPurple	= (RGB(0xD897C3)),
			clVimYellow	= (RGB(0x47C5E7)),
			clVimWhite	= (RGB(0xFFFFFF)),
			clVimGray	= (RGB(0x9FA19E)),
			clVimOrange	= (RGB(0x458CE7)); 
		}
		
		version(/+$DIDE_REGION Rainbow palette+/none)
		{
			//https://github.com/FastLED/FastLED/wiki/Pixel-reference
			immutable
			clRainbowRed	= (RGB(0x0000FF)),
			clRainbowOrange	= (RGB(0x0055AA)),
			clRainbowYellow	= (RGB(0x00AAAA)),
			clRainbowGreen	= (RGB(0x00FF00)),
			clRainbowAqua	= (RGB(0x55AA00)),
			clRainbowBlue	= (RGB(0xFF0000)),
			clRainbowPurple	= (RGB(0xAA0055)),
			clRainbowPink	= (RGB(0x5500AA)); 
		}
		
		version(/+$DIDE_REGION Rainbow palette+/all)
		{
			//More distinct colors for the human eye.
			//This is a better version.
			immutable
			clRainbowRed	= (RGB(0x0000FF)),
			clRainbowOrange	= (RGB(0x0088FF)),
			clRainbowYellow	= (RGB(0x00EEEE)),
			clRainbowGreen	= (RGB(0x00FF00)),
			clRainbowAqua	= (RGB(0xCCCC00)),
			clRainbowBlue	= (RGB(0xFF0000)),
			clRainbowPurple	= (RGB(0xFF0088)),
			clRainbowPink	= (RGB(0x8800FF)); 
		}
		
		version(/+$DIDE_REGION Solarized palette+/all)
		{
			//https://ethanschoonover.com/solarized/
			immutable
			clSolBase03	= (RGB(0x362b00)),
			clSolBase02	= (RGB(0x423607)),
			clSolBase01	= (RGB(0x756e58)),
			clSolBase00	= (RGB(0x837b65)),
			clSolBase0	= (RGB(0x969483)),
			clSolBase1	= (RGB(0xa1a193)),
			clSolBase2	= (RGB(0xd5e8ee)),
			clSolBase3	= (RGB(0xe3f6fd)),
			clSolYellow	= (RGB(0x0089b5)),
			clSolOrange	= (RGB(0x164bcb)),
			clSolRed	= (RGB(0x2f32dc)),
			clSolMagenta	= (RGB(0x8236d3)),
			clSolViolet	= (RGB(0xc4716c)),
			clSolBlue	= (RGB(0xd28b26)),
			clSolCyan	= (RGB(0x98a12a)),
			clSolGreen	= (RGB(0x009985)); 
		}
		
		version(/+$DIDE_REGION Other colors+/all)
		{
			immutable
			clAxisX	= (RGB(213,  40,  40)),
			clAxisY	= (RGB( 40, 166,  40)),
			clAxisZ	= (RGB( 40,  40, 215)),
				
			clOrange	= clRainbowOrange,
			clGold	= (RGB(0x00D7FF)),
			clBronze	= (RGB(0x327FCD)),
			clPink	= (RGB(0xCBC0FF)),
			clPostit	= (RGB(0x99FFFF)); 
		}
		
		version(/+$DIDE_REGION Sticky Note Colors+/all)
		{
			immutable
			clStickyYellow	= (RGB(0xb1f9ff)),
			clStickyWhite	= (RGB(0xf8f6f5)),
			clStickyLightOrange	= (RGB(0x28d1f5)),
			clStickyOlive	= (RGB(0x7ae1d0)),
			clStickyGreen	= (RGB(0x92f6d5)),
			clStickyPastelBlue	= (RGB(0xf5cca6)),
			clStickyAqua	= (RGB(0xc0c667)),
			clStickyBlue	= (RGB(0xe7bf23)),
			clStickyOrange	= (RGB(0x489dff)),
			clStickyPink	= (RGB(0xbb94ea)),
			clStickyRed	= (RGB(0x7f6cf1)),
			clStickyPurple	= (RGB(0xbbb384))
			/+Todo: NiceExpressions, hex RGB+/; 
		}
		
		version(/+$DIDE_REGION Windows.UI.Colors+/all)
		{
			immutable
			clUiAliceBlue	= (RGB(240, 248, 255)),
			clUiAntiqueWhite	= (RGB(250, 235, 215)),
			clUiAqua	= (RGB(  0, 255, 255)),
			clUiAquamarine	= (RGB(127, 255, 212)),
			clUiAzure	= (RGB(240, 255, 255)),
			clUiBeige	= (RGB(245, 245, 220)),
			clUiBisque	= (RGB(255, 228, 196)),
			clUiBlack	= (RGB(  0,   0,   0)),
			clUiBlanchedAlmond	= (RGB(255, 235, 205)),
			clUiBlue	= (RGB(  0,   0, 255)),
			clUiBlueViolet	= (RGB(138,  43, 226)),
			clUiBrown	= (RGB(165,  42,  42)),
			clUiBurlyWood	= (RGB(222, 184, 135)),
			clUiCadetBlue	= (RGB( 95, 158, 160)),
			clUiChartreuse	= (RGB(127, 255,   0)),
			clUiChocolate	= (RGB(210, 105,  30)),
			clUiCoral	= (RGB(255, 127,  80)),
			clUiCornflowerBlue	= (RGB(100, 149, 237)),
			clUiCornsilk	= (RGB(255, 248, 220)),
			clUiCrimson	= (RGB(220,  20,  60)),
			clUiCyan	= (RGB(  0, 255, 255)),
			clUiDarkBlue	= (RGB(  0,   0, 139)),
			clUiDarkCyan	= (RGB(  0, 139, 139)),
			clUiDarkGoldenrod	= (RGB(184, 134,  11)),
			clUiDarkGray	= (RGB(169, 169, 169)),
			clUiDarkGreen	= (RGB(  0, 100,   0)),
			clUiDarkKhaki	= (RGB(189, 183, 107)),
			clUiDarkMagenta	= (RGB(139,   0, 139)),
			clUiDarkOliveGreen	= (RGB( 85, 107,  47)),
			clUiDarkOrange	= (RGB(255, 140,   0)),
			clUiDarkOrchid	= (RGB(153,  50, 204)),
			clUiDarkRed	= (RGB(139,   0,   0)),
			clUiDarkSalmon	= (RGB(233, 150, 122)),
			clUiDarkSeaGreen	= (RGB(143, 188, 143)),
			clUiDarkSlateBlue	= (RGB( 72,  61, 139)),
			clUiDarkSlateGray	= (RGB( 47,  79,  79)),
			clUiDarkTurquoise	= (RGB(  0, 206, 209)),
			clUiDarkViolet	= (RGB(148,   0, 211)),
			clUiDeepPink	= (RGB(255,  20, 147)),
			clUiDeepSkyBlue	= (RGB(  0, 191, 255)),
			clUiDimGray	= (RGB(105, 105, 105)),
			clUiDodgerBlue	= (RGB( 30, 144, 255)),
			clUiFirebrick	= (RGB(178,  34,  34)),
			clUiFloralWhite	= (RGB(255, 250, 240)),
			clUiForestGreen	= (RGB( 34, 139,  34)),
			clUiFuchsia	= (RGB(255,   0, 255)),
			clUiGainsboro	= (RGB(220, 220, 220)),
			clUiGhostWhite	= (RGB(248, 248, 255)),
			clUiGold	= (RGB(255, 215,   0)),
			clUiGoldenrod	= (RGB(218, 165,  32)),
			clUiGray	= (RGB(128, 128, 128)),
			clUiGreen	= (RGB(  0, 128,   0)),
			clUiGreenYellow	= (RGB(173, 255,  47)),
			clUiHoneydew	= (RGB(240, 255, 240)),
			clUiHotPink	= (RGB(255, 105, 180)),
			clUiIndianRed	= (RGB(205,  92,  92)),
			clUiIndigo	= (RGB( 75,   0, 130)),
			clUiIvory	= (RGB(255, 255, 240)),
			clUiKhaki	= (RGB(240, 230, 140)),
			clUiLavender	= (RGB(230, 230, 250)),
			clUiLavenderBlush	= (RGB(255, 240, 245)),
			clUiLawnGreen	= (RGB(124, 252,   0)),
			clUiLemonChiffon	= (RGB(255, 250, 205)),
			clUiLightBlue	= (RGB(173, 216, 230)),
			clUiLightCoral	= (RGB(240, 128, 128)),
			clUiLightCyan	= (RGB(224, 255, 255)),
			clUiLightGoldenrodYellow	= (RGB(250, 250, 210)),
			clUiLightGray	= (RGB(211, 211, 211)),
			clUiLightGreen	= (RGB(144, 238, 144)),
			clUiLightPink	= (RGB(255, 182, 193)),
			clUiLightSalmon	= (RGB(255, 160, 122)),
			
			
			clUiLightSeaGreen	= (RGB( 32, 178, 170)),
			clUiLightSkyBlue	= (RGB(135, 206, 250)),
			clUiLightSlateGray	= (RGB(119, 136, 153)),
			clUiLightSteelBlue	= (RGB(176, 196, 222)),
			clUiLightYellow	= (RGB(255, 255, 224)),
			clUiLime	= (RGB(  0, 255,   0)),
			clUiLimeGreen	= (RGB( 50, 205,  50)),
			clUiLinen	= (RGB(250, 240, 230)),
			clUiMagenta	= (RGB(255,   0, 255)),
			clUiMaroon	= (RGB(128,   0,   0)),
			clUiMediumAquamarine	= (RGB(102, 205, 170)),
			clUiMediumBlue	= (RGB(  0,   0, 205)),
			clUiMediumOrchid	= (RGB(186,  85, 211)),
			clUiMediumPurple	= (RGB(147, 112, 219)),
			clUiMediumSeaGreen	= (RGB( 60, 179, 113)),
			clUiMediumSlateBlue	= (RGB(123, 104, 238)),
			clUiMediumSpringGreen	= (RGB(  0, 250, 154)),
			clUiMediumTurquoise	= (RGB( 72, 209, 204)),
			clUiMediumVioletRed	= (RGB(199,  21, 133)),
			clUiMidnightBlue	= (RGB( 25,  25, 112)),
			clUiMintCream	= (RGB(245, 255, 250)),
			clUiMistyRose	= (RGB(255, 228, 225)),
			clUiMoccasin	= (RGB(255, 228, 181)),
			clUiNavajoWhite	= (RGB(255, 222, 173)),
			clUiNavy	= (RGB(  0,   0, 128)),
			clUiOldLace	= (RGB(253, 245, 230)),
			clUiOlive	= (RGB(128, 128,   0)),
			clUiOliveDrab	= (RGB(107, 142,  35)),
			clUiOrange	= (RGB(255, 165,   0)),
			clUiOrangeRed	= (RGB(255,  69,   0)),
			clUiOrchid	= (RGB(218, 112, 214)),
			clUiPaleGoldenrod	= (RGB(238, 232, 170)),
			clUiPaleGreen	= (RGB(152, 251, 152)),
			clUiPaleTurquoise	= (RGB(175, 238, 238)),
			clUiPaleVioletRed	= (RGB(219, 112, 147)),
			clUiPapayaWhip	= (RGB(255, 239, 213)),
			clUiPeachPuff	= (RGB(255, 218, 185)),
			clUiPeru	= (RGB(205, 133,  63)),
			clUiPink	= (RGB(255, 192, 203)),
			clUiPlum	= (RGB(221, 160, 221)),
			clUiPowderBlue	= (RGB(176, 224, 230)),
			clUiPurple	= (RGB(128,   0, 128)),
			clUiRed	= (RGB(255,   0,   0)),
			clUiRosyBrown	= (RGB(188, 143, 143)),
			clUiRoyalBlue	= (RGB( 65, 105, 225)),
			clUiSaddleBrown	= (RGB(139,  69,  19)),
			clUiSalmon	= (RGB(250, 128, 114)),
			clUiSandyBrown	= (RGB(244, 164,  96)),
			clUiSeaGreen	= (RGB( 46, 139,  87)),
			clUiSeaShell	= (RGB(255, 245, 238)),
			clUiSienna	= (RGB(160,  82,  45)),
			clUiSilver	= (RGB(192, 192, 192)),
			clUiSkyBlue	= (RGB(135, 206, 235)),
			clUiSlateBlue	= (RGB(106,  90, 205)),
			clUiSlateGray	= (RGB(112, 128, 144)),
			clUiSnow	= (RGB(255, 250, 250)),
			clUiSpringGreen	= (RGB(  0, 255, 127)),
			clUiSteelBlue	= (RGB( 70, 130, 180)),
			clUiTan	= (RGB(210, 180, 140)),
			clUiTeal	= (RGB(  0, 128, 128)),
			clUiThistle	= (RGB(216, 191, 216)),
			clUiTomato	= (RGB(255,  99,  71)),
			clUiTransparent	= (RGB(255, 255, 255)),
			clUiTurquoise	= (RGB( 64, 224, 208)),
			clUiViolet	= (RGB(238, 130, 238)),
			clUiWheat	= (RGB(245, 222, 179)),
			clUiWhite	= (RGB(255, 255, 255)),
			clUiWhiteSmoke	= (RGB(245, 245, 245)),
			clUiYellow	= (RGB(255, 255,   0)),
			clUiYellowGreen	= (RGB(154, 205,  50)); 
		}
		
		immutable RGB[]
			clDelphi	= [
			clBlack, clMaroon, clGreen, clOlive, clNavy, clPurple, clTeal, clGray, clSilver, clRed,
			clLime, clYellow, clBlue, clFuchsia, clAqua, clLtGray, clDkGray, clWhite, clSkyBlue, clMoneyGreen
		],
			clVga	= [
			clVgaBlack, clVgaLowBlue, clVgaLowGreen, clVgaLowCyan, clVgaLowRed,
			clVgaLowMagenta, clVgaBrown, clVgaLightGray, clVgaDarkGray, clVgaHighBlue,
			clVgaHighGreen, clVgaHighCyan, clVgaHighRed, clVgaHighMagenta, clVgaYellow,
			clVgaWhite
		],
			clC64	= [
			clC64Black, clC64White, clC64Red, clC64Cyan, clC64Purple, clC64Green, clC64Blue,
			clC64Yellow, clC64Orange, clC64Brown, clC64Pink, clC64DGrey, clC64Grey,
			clC64LGreen, clC64LBlue, clC64LGrey
		],
			clWow	= [
			clBlack, clWowGrey, clWowWhite, clWowGreen, clWowBlue, clWowPurple,
			clWowOrange, clWowPink, clWowGold
		],
			clVim	= [
			clVimBlack, clVimBlue, clVimGreen, clVimTeal, clVimRed, clVimPurple, clVimYellow,
			clVimWhite, clVimGray, clVimOrange
		],
			clRainbow	= [
			clRainbowRed, clRainbowOrange, clRainbowYellow, clRainbowGreen,
			clRainbowAqua, clRainbowBlue, clRainbowPurple, clRainbowPink
		],
			clSol	= [
			clSolBase03, clSolBase02, clSolBase01, clSolBase00, clSolBase0, clSolBase1,
			clSolBase2, clSolBase3, clSolYellow, clSolOrange, clSolRed, clSolMagenta,
			clSolViolet, clSolBlue, clSolCyan, clSolGreen
		],
			clSticky	= [
			clStickyYellow, clStickyWhite, clStickyLightOrange, clStickyOlive, clStickyGreen, clStickyPastelBlue, 
			clStickyAqua, clStickyBlue, clStickyOrange, clStickyPink, clStickyRed, clStickyPurple
		],
			clAxis	= [clAxisX, clAxisY, clAxisZ],
			clAll	= clDelphi ~ clVga ~ clC64 ~ clWow ~ clVim ~ clRainbow ~ clSol ~ clAxis ~ clSticky; 
		
		
		private RGB colorByName(string name, bool mustExists=false)
		{
			
			__gshared static RGB[string] map; 
			
			if(map is null)
			{
				//Todo: user driendly editing of all the colors
				static foreach(member; __traits(allMembers, mixin(__MODULE__)))
				static if(is(Unqual!(typeof(mixin(member)))==RGB))
				map[member.withoutStarting("cl").decapitalize] = mixin(member); 
				
				map.rehash; 
			}
			
			//Todo: decapitalize, enforce
			auto a = name.decapitalize in map; 
			if(a is null)
			{
				enforce(!mustExists, `Unknown color name "%s"`.format(name)); 
				return clFuchsia; 
			}
			return *a; 
		} 
		
		//toRGB //////////////////////////////////
		
		RGB toRGB(string s, bool mustExists=false)
		{
			s = s.strip; 
			enforce(!s.empty, `Empty RGB literal.`); 
			
			//decimal or hex number
			if(s[0].inRange('0', '9')) return RGB(s.toInt); 
			
			//rgb(0,0,255)
			if(s.isWild("*?(*?,*?,*?)"))
			if(wild[0].toUpper.among("RGB", "RGB8"))
			return RGB(wild.ints(1), wild.ints(2), wild.ints(3)); 
			
			return colorByName(s, mustExists); 
		} 
		
		unittest {
			assert(toRGB("blue")==RGB(0, 0, 255)); 
			assert(toRGB("Red").rgbToFloat==vec3(1, 0, 0)); 
		} 
		
		
		//Ega color codes
		struct EgaColor/*(bool enabled = true)*/
		{
			enum enabled = true; 
			static foreach(idx, s; "black blue green cyan red magenta brown white gray ltBlue ltGreen ltCyan ltRed ltMagenta yellow ltWhite".split(' '))
			mixin(format!`static auto %s(string s){ return enabled ? "\33\%s"~s~"\33\7" : s; }`(s, idx.to!string(8))); 
			
			//Usage: Print(EgaColor.red("Red text"));
		} 
		//operations //////////////////////////////
		
		//import std.traits;
		/+
			Todo: pragma(msg, "Megcsinalni a szinek listazasat traits-al." ~
			[__traits(allMembers, het.color)].filter!(s => s.startsWith("cl")).array);
		+/
	}version(/+$DIDE_REGION ColorMaps+/all)
	{
		
		//Todo: there should be a bezier interpolated colormap too. RegressionColorMap is so bad for HSV and JET for example.
		
		class ColorMap
		{
			string name, category; 
			int index; 
			
			abstract RGB eval(float x); 
			
			T[] toArray(T=RGB)(int len)
			{
				float invLen = 1.0f/max(len-1, 1); 
				return iota(len).map!(i => eval(i*invLen).convertPixel!T).array; 
			} 
		} 
		class RegressionColorMap: ColorMap
		{
			double[][3] polys; 
			
			this(string name, string category, double[][3] polys)
			{
				this.name = name; 
				this.category = category; 
				this.polys = polys; 
			} 
			
			override RGB eval(float x)
			{
				x = x.clamp(0, 1); 
				return vec3(evalPoly(x, polys[0]), evalPoly(x, polys[1]), evalPoly(x, polys[2])).to_unorm; 
			} 
		} 
		class DistinctColorMap: ColorMap
		{
			RGB[] pal; 
			bool isLinear; 
			
			this(string name, string category, int[3][] pal, bool isLinear=false)
			{
				this.name = name; 
				this.category = category; 
				this.pal = pal.map!(c => RGB(c[0], c[1], c[2])).array; 
				this.isLinear = isLinear; 
			} 
			
			override RGB eval(float x)
			{
				if(x<=0) return pal[0]; 
				if(x>=0.9999) return pal[$-1]; 
				
				if(isLinear) {
					x *= pal.length-1; 
					const i = x.ifloor, fr = x.fract; //Todo: modf
					return mix(pal[i], pal[i+1], fr); 
				}else {
					 //nearest
					x *= pal.length; 
					return pal[x.ifloor]; 
				}
			} 
		} 
		class ColorMapCategory
		{
			string name; 
			ColorMaps colorMaps; 
			alias colorMaps this; 
			
			this(string name) {
				this.name = name; 
				colorMaps = new ColorMaps; 
			} 
		} 
		class ColorMapCategories
		{
			ColorMapCategory[string] byName; 
			ColorMapCategory[] byIndex; 
			
			private void add(ColorMap m)
			{
				if(!(m.category in byName)) {
					auto cat = new ColorMapCategory(m.category); 
					byName[m.category] = cat; 
					byIndex ~= cat; 
				}
				byName[m.category].colorMaps.add(m); 
			} 
			
			@property auto length() const
			{ return byIndex.length; } 
			auto opIndex(size_t idx)
			{ return byIndex[idx]; } 
			auto opIndex(string name)
			{ return byName[name]; } 
			
			auto opDispatch(string name)()
			{ return byName[name]; } 
			
			//Todo: Range
			
			int opApply(int delegate(ColorMapCategory) dg)
			{
				int result = 0; 
				foreach(c; byIndex) {
					result = dg(c); 
					if(result) break; 
				}
				return result; 
			} 
		} 
		class ColorMaps
		{
			ColorMap[string] byName; 
			ColorMap[] byIndex; 
			
			ColorMapCategories categories; 
			
			private void add(ColorMap m)
			{
				import std.conv; //utils
				m.index = byIndex.length.to!int; 
				byIndex ~= m; 
				byName[m.name] = m; 
			} 
			
			this()
			{ categories = new ColorMapCategories; } 
			
			@property auto length() const
			{ return byIndex.length; } 
			auto opIndex(size_t idx)
			{ return byIndex[idx]; } 
			auto opIndex(string name)
			{ return byName[name]; } 
			
			auto opDispatch(string name)()
			{ return byName[name]; } 
			
			bool opBinaryRight(string op)(string lhs) const if(op=="in")
			{ return (lhs in byName) !is null; } 
			
			int opApply(int delegate(ColorMap) dg)
			{
				int result = 0; 
				foreach(c; byIndex) {
					result = dg(c); 
					if(result) break; 
				}
				return result; 
			} 
		} 
		class StandardColorMaps : ColorMaps
		{
			
			this()
			{
				initColorMaps(
					(ColorMap m){
						add(m); 
						categories.add(m); 
					} 
				); 
			} 
			
			private static void initColorMaps(void delegate(ColorMap) add)
			{
				//Exported from python
				add(new RegressionColorMap("viridis", "Uniform", [[0.2753652,-0.05184015,1.717864,-13.64572,24.0259,-11.33279],[0.01529448,1.245687,-0.1677699,-0.1776745],[0.331099,1.350983,0.6340607,-21.84333,62.08875,-70.69913,28.27274]])); 
				add(new RegressionColorMap("plasma", "Uniform", [[0.07050842,1.846171,-0.5688886,-0.3956234],[0.02749319,0.1857873,-7.011921,40.69019,-79.73788,68.91157,-22.09464],[0.5189733,1.480299,-4.612459,3.238719,-0.488916]])); 
				add(new RegressionColorMap("inferno", "Uniform", [[0.001327787,0.009644044,12.44225,-44.74039,82.7469,-76.31698,26.83947],[0.01018034,0.07107646,1.393175,-4.544394,8.313788,-4.239053],[0.01324062,1.360481,13.89826,-50.29397,-207.9872,1476.927,-3440.86,3950.336,-2249.96,507.2107]])); 
				add(new RegressionColorMap("magma", "Uniform", [[-0.001056089,0.2086954,8.414332,-27.03387,49.82702,-47.92527,17.50701],[-0.01226924,1.697227,-18.85727,103.8391,-282.0351,401.9937,-284.1511,78.51863],[0.02257798,-0.1336941,43.49071,-306.8667,1033.189,-1972.302,2150.426,-1238.54,291.4641]])); 
				add(new RegressionColorMap("cividis", "Uniform", [[0.004867613,-1.373322,29.5757,-140.1297,330.4008,-416.7607,269.6471,-70.36864],[0.1407279,0.611976,0.1473766],[0.299587,2.763263,-20.14296,65.65921,-103.2274,77.2379,-22.38728]])); 
				add(new RegressionColorMap("Greys", "Sequential", [[1.00188,-0.3776376,-1.076465,0.4515921],[1.00188,-0.3776376,-1.076465,0.4515921],[1.00188,-0.3776376,-1.076465,0.4515921]])); 
				add(new RegressionColorMap("Purples", "Sequential", [[0.9943569,-0.3635322,-1.125815,0.7564731],[0.9825725,-0.295309,-1.065359,0.3711998],[1.002707,-0.310729,-0.2172503]])); 
				add(new RegressionColorMap("Blues", "Sequential", [[0.9640408,-0.6848032,0.7231472,-6.71995,9.323603,-3.578733],[0.9838041,-0.3983304,-0.4135137],[0.9939348,-0.02735043,-1.362508,2.308459,-1.494721]])); 
				add(new RegressionColorMap("Greens", "Sequential", [[0.9708491,-0.6463783,1.410661,-12.11126,23.53188,-19.42088,6.268454],[0.9891632,-0.1683416,-0.5541972],[0.958096,-0.378251,-2.675335,3.800997,-1.608774]])); 
				add(new RegressionColorMap("Oranges", "Sequential", [[0.9943825,0.2783882,-3.175885,11.55517,-16.27355,7.119251],[0.9549578,-0.194053,-1.876715,1.278326],[0.9199493,-0.7070352,-1.541605,-2.854956,8.828911,-4.631098]])); 
				add(new RegressionColorMap("Reds", "Sequential", [[1.002536,-0.069215,-0.3823209,3.257759,-6.273296,2.873386],[0.9539357,-0.02952599,-7.684742,27.8715,-55.52702,53.66999,-19.26047],[0.9383569,-0.5750223,-3.986057,6.524778,-2.85329]])); 
				add(new RegressionColorMap("YlOrBr", "Sequential", [[0.9990683,0.1157627,-1.69745,7.376928,-11.82314,5.431688],[0.9889852,0.1800437,-2.79592,1.782192],[0.905389,-2.151394,16.65872,-109.4322,309.6544,-433.5393,299.8086,-81.88536]])); 
				add(new RegressionColorMap("YlOrRd", "Sequential", [[1.007837,-0.1954425,0.7577178,-0.5443974,-0.5385435],[0.9939479,-0.1366723,-4.802413,20.96242,-49.97206,50.96066,-18.00391],[0.8001015,-1.455894,3.507234,-33.01823,125.4178,-215.7354,174.9292,-54.30566]])); 
				add(new RegressionColorMap("OrRd", "Sequential", [[1.001049,-0.1257674,0.7040524,-1.092909],[0.9640021,0.3112739,-17.25948,144.7576,-602.6837,1334.988,-1622.694,1021.24,-259.622],[0.9284024,-2.264321,44.3868,-612.9268,4109.246,-15499.49,35194.85,-49094.87,41153.87,-19014.5,3720.767]])); 
				add(
					new RegressionColorMap(
						"PuRd", "Sequential", [
							[0.9704971,-0.8383752,8.605635,-73.5064,261.8788,-425.6387,319.3959,-90.46502],[0.9605051,-1.646228,34.259,-388.2909,2022.52,-5782.367,9589.64,-9194.954,4732.579,-1012.7],
							[0.9798234,-0.8971576,15.17699,-142.2227,591.9549,-1285.39,1502.234,-895.1943,213.4742]
						]
					)
				); 
				add(new RegressionColorMap("RdPu", "Sequential", [[1.002849,-0.1181552,-0.2749962,4.18575,-9.743464,5.245328],[0.9693509,-0.7670555,1.228309,-9.275643,24.5475,-48.529,53.06413,-21.24509],[0.9490611,-0.2347976,-6.583422,29.47778,-55.81673,48.14649,-15.52411]])); 
				add(new RegressionColorMap("BuPu", "Sequential", [[0.9614898,-0.2275982,-4.644432,9.768894,-5.569028],[0.9879448,-0.4045968,-1.266799,2.761224,-5.102823,3.028789],[0.9881732,-0.1216244,-1.197505,1.768901,-1.147187]])); 
				add(new RegressionColorMap("GnBu", "Sequential", [[0.9644057,-0.6378398,0.706042,-5.228842,6.01205,-1.786668],[0.9921003,-0.4184938,1.111607,-2.795616,1.36238],[0.9390684,0.005097648,-20.46887,242.9244,-1432.469,4626.279,-8487.847,8832.591,-4861.983,1100.536]])); 
				add(new RegressionColorMap("PuBu", "Sequential", [[0.9939339,-0.07977941,-6.444068,28.19269,-68.82041,74.17442,-28.01609],[0.9694938,-0.5136097,-0.2334397],[0.9835465,-0.2009541,-0.8581221,1.869981,-1.459495]])); 
				add(new RegressionColorMap("YlGnBu", "Sequential", [[1.005623,-1.087432,9.602415,-61.95867,128.1164,-107.7916,32.1362],[0.9955562,0.1169872,-3.348035,8.119295,-11.1324,5.375331],[0.8493738,-0.2583054,-34.73764,406.4949,-2093.879,6014.343,-10210.52,10148.26,-5450.338,1220.136]])); 
				add(new RegressionColorMap("PuBuGn", "Sequential", [[1.000965,-1.078253,20.9331,-312.579,2263.668,-9330.651,23051.13,-34760.15,31337.3,-15508.54,3238.97],[0.9589328,-0.3876129,-1.1222,1.920854,-1.090379],[0.9900182,-0.966087,11.14282,-73.81004,230.4158,-361.3102,272.5262,-78.77697]])); 
				add(new RegressionColorMap("BuGn", "Sequential", [[0.9718871,-0.9677532,7.603039,-45.79734,96.59922,-88.37143,29.9761],[0.9907807,-0.1667634,-0.5571327],[0.9909846,0.002492409,-1.225382,-1.187381,1.541323]])); 
				add(new RegressionColorMap("YlGn", "Sequential", [[0.9968858,0.09135531,-4.241359,14.47433,-54.02978,102.7885,-88.55247,28.48084],[0.9956981,0.0764644,-1.296713,0.4942138],[0.9092246,-2.041375,6.709668,-14.43298,13.52214,-4.501648]])); 
				add(new RegressionColorMap("binary", "Sequential2", [[1.001636,-1.003271],[1.001636,-1.003271],[1.001636,-1.003271]])); 
				add(new RegressionColorMap("gist_yarg", "Sequential2", [[1.001636,-1.003271],[1.001636,-1.003271],[1.001636,-1.003271]])); 
				add(new RegressionColorMap("gist_gray", "Sequential2", [[-0.001635581,1.003271],[-0.001635581,1.003271],[-0.001635581,1.003271]])); 
				add(new RegressionColorMap("gray", "Sequential2", [[-0.001635581,1.003271],[-0.001635581,1.003271],[-0.001635581,1.003271]])); 
				add(new RegressionColorMap("bone", "Sequential2", [[-0.008784384,1.033052,-0.5934138,0.5744974],[0.01445017,0.5452215,1.153349,-0.7143174],[-0.01195305,1.441361,-0.7421807,0.3133882]])); 
				add(new RegressionColorMap("pink", "Sequential2", [[0.1390393,3.118536,-5.619675,5.04288,-1.681207],[0.01460264,3.986171,-20.13017,58.92311,-82.68645,54.79184,-13.89987],[0.01640588,3.910254,-20.16342,65.8281,-113.7587,96.78714,-31.62747]])); 
				add(new RegressionColorMap("spring", "Sequential2", [[1,2.26089e-16],[-0.001635581,1.003271],[1.001636,-1.003271]])); 
				add(new RegressionColorMap("summer", "Sequential2", [[-0.001635581,1.003271],[0.4991822,0.5016356],[0.4,7.273802e-17]])); 
				add(new RegressionColorMap("autumn", "Sequential2", [[1,2.26089e-16],[-0.001635581,1.003271],[0.0,0]])); 
				add(new RegressionColorMap("winter", "Sequential2", [[0,0.0],[-0.001635581,1.003271],[1.000818,-0.5016356]])); 
				add(new RegressionColorMap("cool", "Sequential2", [[-0.001635581,1.003271],[1.001636,-1.003271],[1,2.26089e-16]])); 
				add(new RegressionColorMap("Wistia", "Sequential2", [[0.8916084,0.5771672,-0.9190709,0.445015],[0.9916546,-0.03851729,-1.878249,2.535797,-1.116227],[0.4869933,-1.699644,-0.1424205,6.976584,-9.36134,3.74447]])); 
				add(
					new RegressionColorMap(
						"hot", "Sequential2", [
							[0.04400761,1.083752,56.45801,-784.6625,5375.45,-20476.3,46209.31,-63473.24,52217.96,-23684.52,4559.427],
							[-6.53321e-05,0.9390913,-74.63733,2208.389,-33524.43,299934.7,-1707516,6478810,-1.684286e+07,3.039444e+07,-3.80191e+07,3.233357e+07,-1.783785e+07,5757209,-825257.9],
							[-0.0003722964,2.276648,-175.9221,5189.797,-80745.65,762609.8,-4725671,2.013378e+07,-6.065568e+07,1.311082e+08,-2.039297e+08,2.261388e+08,-1.742948e+08,8.866798e+07,-2.675474e+07,3624977]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"afmhot", "Sequential2", [
							[-0.002352444,2.748123,-31.70079,467.2322,-3371.677,13618.78,-32717.7,47669.99,-41319.84,19605.73,-3922.571],[0.003729495,-1.361162,46.52012,-564.9612,3219.729,-9762.752,16961.76,-16970.37,9093.112,-2020.691],
							[0.001814115,-0.8352974,32.73938,-473.9859,3400.082,-13694.43,32841.85,-47790.99,41383.98,-19619.98,3922.571]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"gist_heat", "Sequential2", [
							[-0.002489772,1.84508,-9.710313,94.73447,-437.1439,1066.125,-1403.422,937.5674,-248.9978],[0.001814115,-0.8352974,32.73938,-473.9859,3400.082,-13694.43,32841.85,-47790.99,41383.98,-19619.98,3922.571],
							[-0.0003866005,2.293281,-176.5099,5185.532,-80333.8,755429.7,-4660846,1.977178e+07,-5.931006e+07,1.276571e+08,-1.977326e+08,2.183644e+08,-1.676205e+08,8.493229e+07,-2.552686e+07,3445243]
						]
					)
				); 
				add(new RegressionColorMap("copper", "Sequential2", [[0.005256354,0.8097105,4.997437,-22.03609,43.80944,-39.26019,12.66606],[-0.001277716,0.7837554],[-0.0008137016,0.4991274]])); 
				add(
					new RegressionColorMap(
						"PiYG", "Diverging", [
							[0.5454175,3.169233,-14.15834,45.12639,-78.03891,60.07602,-16.55967],[0.004148211,2.067085,-58.47564,912.1992,-5789.504,20114.77,-42292.08,55277.75,-43966.61,19501.64,-3701.379],
							[0.3202559,2.058512,-16.15093,215.4605,-1265.554,3978.887,-7230.506,7530.652,-4156.031,940.9636]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"PRGn", "Diverging", [
							[0.240665,3.138791,-16.26083,72.05801,-144.6037,121.3134,-35.87999],[-0.0005091017,2.3291,-37.78648,604.3451,-4153.032,15723.82,-35793.2,50138.36,-42316.44,19746.3,-3914.436],
							[0.2939401,1.908709,9.164541,-110.1134,493.458,-1116.898,1317.244,-776.0007,181.0501]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"BrBG", "Diverging", [
							[0.3259664,2.233975,1.558473,-26.63698,105.6104,-216.5362,199.216,-65.77085],[0.1843412,2.043522,-21.79604,212.9038,-843.1833,1714.476,-1927.045,1137.79,-275.1404],
							[0.01795185,0.8747753,-25.41493,317.8396,-1754.632,6136.053,-14032.64,20289.43,-17696.58,8477.341,-1712.107]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"PuOr", "Diverging", [
							[0.4870847,2.352066,-1.411496,-4.404916,3.161546],[0.2280941,2.2825,-43.88991,599.0242,-3963.487,15218.1,-35826.81,52125.86,-45614.24,21986.09,-4483.158],
							[0.03080723,2.743821,-201.9493,5377.307,-73818.09,602661.7,-3160160,1.118069e+07,-2.746009e+07,4.738169e+07,-5.725255e+07,4.743392e+07,-2.566855e+07,8171618,-1160579]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"RdGy", "Diverging", [
							[0.3965083,3.733364,-12.1724,32.82119,-57.16952,46.10805,-13.61791],[-0.001731808,2.361627,-66.23397,988.7644,-6536.244,24368.15,-55283.5,77574.67,-65677.26,30732.9,-6103.506],
							[0.1219723,-0.2491758,42.94243,-1001.326,11753.99,-76987.47,308856,-795156.7,1338139,-1463609,1002559,-390734.4,66138.04]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"RdBu", "Diverging", [
							[0.4033661,2.082337,38.33317,-577.4216,3778.289,-14055.95,31952.69,-45207.94,38787.46,-18438.68,3720.766],[0.006171795,0.01472633,11.94421,-10.58839,-34.82899,60.42811,-30.1175,3.326138],
							[0.1192284,1.958517,-67.55607,1089.345,-8606.521,39783.65,-114322.6,210068.3,-247445.9,181078.4,-75057.43,13478.65]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"RdYlBu", "Diverging", [
							[0.642991,2.067689,2.4008,-55.7673,211.3794,-367.0767,296.6767,-90.13596],[0.003358569,1.534511,2.58159,9.139769,-47.10558,52.97244,-18.92271],
							[0.1492362,-1.774662,140.4997,-4027.591,58288.17,-490759,2635118,-9516457,2.380624e+07,-4.176496e+07,5.122995e+07,-4.302485e+07,2.357008e+07,-7587209,1088446]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"RdYlGn", "Diverging", [
							[0.6435861,2.88086,-34.32824,489.2461,-3677.644,15161.53,-36874,54402.67,-47897.65,23161.17,-4734.525],[0.002077279,1.3899,8.922088,-62.35206,304.0934,-827.2703,1153.393,-788.2902,210.5216],
							[0.1491436,-3.728705,327.0102,-10811.14,187471.3,-1971161,1.368395e+07,-6.595642e+07,2.275601e+08,-5.719496e+08,1.055226e+09,-1.426568e+09,1.395522e+09,-9.608228e+08,4.413951e+08,-1.214213e+08,1.51253e+07]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"Spectral", "Diverging", [
							[0.6197774,1.325334,36.91148,-607.1633,4916.959,-24178.17,75373.96,-151123,193707.6,-153219.7,68098.81,-13007.83],[-0.0006841462,2.829995,-6.620532,4.091712,161.4834,-672.9894,1094.098,-812.316,229.7395],
							[0.2589552,-2.181501,238.262,-8420.458,160478.3,-1863041,1.407996e+07,-7.257249e+07,2.635618e+08,-6.886375e+08,1.308207e+09,-1.807834e+09,1.797604e+09,-1.252463e+09,5.801753e+08,-1.604564e+08,2.004581e+07]
						]
					)
				); 
				add(new RegressionColorMap("coolwarm", "Diverging", [[0.2378759,0.8307598,2.688646,-4.249058,1.187732],[0.292213,2.162399,-6.286292,29.26612,-70.3687,69.76932,-24.81265],[0.7441923,1.809667,-3.085519,-0.9781447,1.671971]])); 
				add(
					new RegressionColorMap(
						"bwr", "Diverging", [
							[-0.002352444,2.748123,-31.70079,467.2322,-3371.677,13618.78,-32717.7,47669.99,-41319.84,19605.73,-3922.571],
							[-0.0005569724,3.598096,-128.353,3642.699,-52683.23,450437.8,-2466718,9070761,-2.30124e+07,4.075804e+07,-5.026342e+07,4.229463e+07,-2.31529e+07,7432520,-1061789],
							[0.9981859,0.8352974,-32.73938,473.9859,-3400.082,13694.43,-32841.85,47790.99,-41383.98,19619.98,-3922.571]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"seismic", "Diverging", [
							[3.964812e-05,5.414254,-567.191,23621.4,-531010.7,7350797,-6.757792e+07,4.334047e+08,-2.006023e+09,6.859573e+09,-1.759342e+10,3.411472e+10,-5.005975e+10,5.52169e+10,-4.503404e+10,2.633266e+10,-1.04382e+10,2.511931e+09,-2.770266e+08],
							[-0.0001357102,18.12995,-1807.127,71642.7,-1543116,2.065181e+07,-1.852585e+08,1.169065e+09,-5.360936e+09,1.825901e+10,-4.683032e+10,9.106584e+10,-1.34278e+11,1.490291e+11,-1.224019e+11,7.210954e+10,-2.880414e+10,6.98486e+09,-7.760949e+08],
							[0.2998091,8.033093,-534.4544,20781.05,-434427.2,5652565,-4.968447e+07,3.10246e+08,-1.420702e+09,4.866503e+09,-1.261343e+10,2.485771e+10,-3.719605e+10,4.190709e+10,-3.4928e+10,2.086473e+10,-8.442551e+09,2.071525e+09,-2.326271e+08]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"twilight", "Cyclic", [
							[0.8835512,1.73132,-158.733,2756.899,-27038.06,161040.6,-605458.5,1478880,-2378009,2498389,-1651116,623228.8,-102517.2],[0.8461764,1.809967,-74.55782,805.0225,-4756.084,16269.59,-33841.89,43660.32,-34196.72,14913.63,-2781.108],
							[0.8881449,-1.900196,106.3215,-3454.897,53676.75,-479211.8,2710581,-1.024234e+07,2.660624e+07,-4.810743e+07,6.041161e+07,-5.165145e+07,2.867778e+07,-9323296,1347196]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"twilight_shifted", "Cyclic", [
							[0.1876353,-0.09718201,65.55269,-1156.117,11337.55,-71008.82,288921.9,-766887.8,1331526,-1497035,1049527,-417033.4,71743.67],[0.07576997,0.2363898,-31.87285,683.9268,-5040.303,19783.32,-45965.69,64958.51,-54812.75,25403.67,-4979.056],
							[0.215371,4.645766,-221.106,6443.81,-89077.21,717094.1,-3710525,1.298319e+07,-3.154976e+07,5.381883e+07,-6.42093e+07,5.246134e+07,-2.796953e+07,8767175,-1225662]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"hsv", "Cyclic", [
							[1.000338,-17.28982,1617.077,-59417.76,1182046,-1.467382e+07,1.23274e+08,-7.369719e+08,3.236412e+09,-1.065203e+10,2.659145e+10,-5.061662e+10,7.338606e+10,-8.037306e+10,6.533174e+10,-3.818289e+10,1.516152e+10,-3.660957e+09,4.056307e+08],
							[0.0001101397,1.91883,210.1927,-2423.517,-54268.66,1861445,-2.432878e+07,1.876249e+08,-9.660806e+08,3.522176e+09,-9.390744e+09,1.862867e+10,-2.767389e+10,3.06872e+10,-2.504338e+10,1.460715e+10,-5.764404e+09,1.379382e+09,-1.511792e+08],
							[-5.833184e-05,-0.9309754,109.1302,-4943.711,117245.9,-1668700,1.546196e+07,-9.851114e+07,4.486609e+08,-1.502369e+09,3.772156e+09,-7.187003e+09,1.043452e+10,-1.149286e+10,9.457926e+09,-5.640076e+09,2.303272e+09,-5.761771e+08,6.655107e+07]
						]
					)
				); 
				add(new DistinctColorMap("Pastel1", "Qualitative", [[251,180,174],[179,205,227],[204,235,197],[222,203,228],[254,217,166],[255,255,204],[229,216,189],[253,218,236],[242,242,242]])); 
				add(new DistinctColorMap("Pastel2", "Qualitative", [[179,226,205],[253,205,172],[203,213,232],[244,202,228],[230,245,201],[255,242,174],[241,226,204],[204,204,204]])); 
				add(new DistinctColorMap("Paired", "Qualitative", [[166,206,227],[31,120,180],[178,223,138],[51,160,44],[251,154,153],[227,26,28],[253,191,111],[255,127,0],[202,178,214],[106,61,154],[255,255,153],[177,89,40]])); 
				add(new DistinctColorMap("Accent", "Qualitative", [[127,201,127],[190,174,212],[253,192,134],[255,255,153],[56,108,176],[240,2,127],[191,91,23],[102,102,102]])); 
				add(new DistinctColorMap("Dark2", "Qualitative", [[27,158,119],[217,95,2],[117,112,179],[231,41,138],[102,166,30],[230,171,2],[166,118,29],[102,102,102]])); 
				add(new DistinctColorMap("Set1", "Qualitative", [[228,26,28],[55,126,184],[77,175,74],[152,78,163],[255,127,0],[255,255,51],[166,86,40],[247,129,191],[153,153,153]])); 
				add(new DistinctColorMap("Set2", "Qualitative", [[102,194,165],[252,141,98],[141,160,203],[231,138,195],[166,216,84],[255,217,47],[229,196,148],[179,179,179]])); 
				add(new DistinctColorMap("Set3", "Qualitative", [[141,211,199],[255,255,179],[190,186,218],[251,128,114],[128,177,211],[253,180,98],[179,222,105],[252,205,229],[217,217,217],[188,128,189],[204,235,197],[255,237,111]])); 
				add(new DistinctColorMap("tab10", "Qualitative", [[31,119,180],[255,127,14],[44,160,44],[214,39,40],[148,103,189],[140,86,75],[227,119,194],[127,127,127],[188,189,34],[23,190,207]])); 
				add(
					new DistinctColorMap(
						"tab20", "Qualitative", [
							[31,119,180],[174,199,232],[255,127,14],[255,187,120],[44,160,44],[152,223,138],[214,39,40],[255,152,150],[148,103,189],[197,176,213],[140,86,75],[196,156,148],[227,119,194],[247,182,210],
							[127,127,127],[199,199,199],[188,189,34],[219,219,141],[23,190,207],[158,218,229]
						]
					)
				); 
				add(
					new DistinctColorMap(
						"tab20b", "Qualitative", [
							[57,59,121],[82,84,163],[107,110,207],[156,158,222],[99,121,57],[140,162,82],[181,207,107],[206,219,156],[140,109,49],[189,158,57],[231,186,82],[231,203,148],[132,60,57],[173,73,74],[214,97,107],
							[231,150,156],[123,65,115],[165,81,148],[206,109,189],[222,158,214]
						]
					)
				); 
				add(
					new DistinctColorMap(
						"tab20c", "Qualitative", [
							[49,130,189],[107,174,214],[158,202,225],[198,219,239],[230,85,13],[253,141,60],[253,174,107],[253,208,162],[49,163,84],[116,196,118],[161,217,155],[199,233,192],[117,107,177],[158,154,200],
							[188,189,220],[218,218,235],[99,99,99],[150,150,150],[189,189,189],[217,217,217]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"flag", "Miscellaneous", [
							[1.003054,57.48744,-7657.769,284277.5,-5332442,6.067249e+07,-4.589828e+08,2.436671e+09,-9.388949e+09,2.680706e+10,-5.734934e+10,9.219607e+10,-1.107695e+11,9.791904e+10,-6.179076e+10,2.633413e+10,-6.7926e+09,8.022537e+08,-675293.2],
							[0.005824759,362.1842,-29967.06,1040391,-2.002559e+07,2.425556e+08,-1.990366e+09,1.160379e+10,-4.961581e+10,1.589089e+11,-3.861964e+11,7.165118e+11,-1.014196e+12,1.086468e+12,-8.655482e+11,4.967743e+11,-1.940862e+11,4.619641e+10,-5.054287e+09],
							[0.001589468,555.5726,-45411.3,1547538,-2.93891e+07,3.539016e+08,-2.907366e+09,1.706326e+10,-7.374981e+10,2.394602e+11,-5.911438e+11,1.11544e+12,-1.606854e+12,1.752304e+12,-1.420968e+12,8.298629e+11,-3.297375e+11,7.97663e+10,-8.862914e+09]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"prism", "Miscellaneous", [
							[0.9991309,203.1754,-15404.71,407578.1,-5407141,3.957736e+07,-1.43008e+08,-7.377359e+07,3.676521e+09,-2.122731e+10,7.202517e+10,-1.677467e+11,2.813021e+11,-3.443355e+11,3.058151e+11,-1.92204e+11,8.112104e+10,-2.063642e+10,2.392231e+09],
							[-0.003734142,-82.37906,13308.32,-563644.9,1.172902e+07,-1.462303e+08,1.206418e+09,-6.983605e+09,2.94347e+10,-9.249605e+10,2.198209e+11,-3.977475e+11,5.477706e+11,-5.696431e+11,4.395415e+11,-2.437668e+11,9.180245e+10,-2.100833e+10,2.203849e+09],
							[0.005485634,52.36028,-7290.473,355455.8,-8428500,1.173614e+08,-1.06448e+09,6.695955e+09,-3.040472e+10,1.022695e+11,-2.588835e+11,4.970849e+11,-7.243866e+11,7.954061e+11,-6.47017e+11,3.778735e+11,-1.497591e+11,3.605577e+10,-3.97962e+09]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"ocean", "Miscellaneous", [
							[-0.0005458377,1.094546,-69.00678,1631.291,-19916.77,144336.5,-668989,2067598,-4348435,6239188,-6005498,3706540,-1324824,208438.7],
							[0.5008673,-3.179374,115.0827,-2798.928,34215.83,-243059.8,1086082,-3199969,6379373,-8664454,7906641,-4641420,1584416,-239136.7],[-0.001635581,1.003271]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"gist_earth", "Miscellaneous", [
							[-0.0002762251,0.4136413,13.21714,-242.0193,2085.699,-9693.582,25994.06,-41308.43,38376.76,-19258.26,4033.133],[-0.001158982,-1.11939,67.12907,-673.1108,3906.444,-14129.28,32121.98,-45561.89,38982.81,-18368.58,3656.612],
							[0.001107328,27.02537,-648.3809,8552.686,-70015.5,379682.8,-1410563,3648733,-6604605,8313870,-7120912,3954885,-1283984,184977.6]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"terrain", "Miscellaneous", [
							[0.1998541,18.31149,-1914.396,74379.28,-1571220,2.064986e+07,-1.822744e+08,1.134484e+09,-5.142908e+09,1.73515e+10,-4.415997e+10,8.533415e+10,-1.251849e+11,1.383629e+11,-1.132617e+11,6.654501e+10,-2.652383e+10,6.420755e+09,-7.12434e+08],
							[0.1998249,9.283184,-685.4568,27432.39,-592685,7957289,-7.178133e+07,4.56809e+08,-2.117762e+09,7.305019e+09,-1.899421e+10,3.746006e+10,-5.601448e+10,6.301888e+10,-5.243487e+10,3.127015e+10,-1.2634e+10,3.096168e+09,-3.473731e+08],
							[0.6002002,-2.234188,278.4137,-2233.399,-142602.1,4285348,-5.694594e+07,4.554154e+08,-2.44032e+09,9.258323e+09,-2.566322e+10,5.287008e+10,-8.147461e+10,9.360736e+10,-7.904515e+10,4.76374e+10,-1.939314e+10,4.779111e+09,-5.384401e+08]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"gist_stern", "Miscellaneous", [
							[0.0002345148,-56.12932,6274.73,-202409.7,3471624,-3.749081e+07,2.761692e+08,-1.455382e+09,5.659909e+09,-1.657715e+10,3.70199e+10,-6.338434e+10,8.31149e+10,-8.276796e+10,6.148308e+10,-3.299379e+10,1.208205e+10,-2.70134e+09,2.781708e+08],
							[-0.001635581,1.003271],
							[-0.0002086733,15.95523,-1403.785,55547.98,-1191957,1.591513e+07,-1.428558e+08,9.050411e+08,-4.179162e+09,1.436763e+10,-3.726041e+10,7.334851e+10,-1.095618e+11,1.232244e+11,-1.025713e+11,6.12355e+10,-2.478233e+10,6.086752e+09,-6.847317e+08]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"gnuplot", "Miscellaneous", [
							[0.01540058,5.27125,-32.41231,128.9701,-287.9833,357.4067,-230.2836,60.01988],[0.0004682807,-0.00766732,0.01773881,0.993135],
							[2.174191e-05,-5.966946,1101.784,-40918.34,838716.8,-1.083111e+07,9.470293e+07,-5.870363e+08,2.659603e+09,-8.986304e+09,2.292773e+10,-4.443231e+10,6.536459e+10,-7.242569e+10,5.940983e+10,-3.496238e+10,1.395237e+10,-3.380332e+09,3.752661e+08]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"gnuplot2", "Miscellaneous", [
							[0.0003712145,-3.926377,317.0111,-9684.757,154084.3,-1466660,9031891,-3.77987e+07,1.10921e+08,-2.322662e+08,3.488747e+08,-3.730419e+08,2.771769e+08,-1.360201e+08,3.963975e+07,-5195486],
							[-0.004158209,1.176903,-36.70984,422.5831,-2361.849,7182.688,-12472.24,12384.04,-6551.556,1432.871],
							[5.690406e-05,-12.5525,1582.16,-61273.32,1299019,-1.718545e+07,1.528e+08,-9.574842e+08,4.366656e+09,-1.481292e+10,3.78965e+10,-7.362202e+10,1.086208e+11,-1.208086e+11,9.957818e+10,-5.895306e+10,2.369424e+10,-5.787626e+09,6.483878e+08]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"CMRmap", "Miscellaneous", [
							[0.0001979309,-3.66959,408.3956,-13384.48,233621.8,-2489575,1.749516e+07,-8.507316e+07,2.951744e+08,-7.443139e+08,1.375497e+09,-1.860667e+09,1.820062e+09,-1.252512e+09,5.74957e+08,-1.580127e+08,1.966233e+07],
							[0.003568684,-0.6664486,68.39045,-887.9126,5507.664,-19568.16,42469.27,-57130.48,46452.52,-20912.9,4003.269],
							[-0.0002387746,-0.1996876,412.2208,-17271.16,393609.7,-5480214,5.024197e+07,-3.197753e+08,1.465944e+09,-4.963678e+09,1.261517e+10,-2.426865e+10,3.5381e+10,-3.883033e+10,3.155586e+10,-1.841009e+10,7.290211e+09,-1.754487e+09,1.936916e+08]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"cubehelix", "Miscellaneous", [
							[-0.006161774,2.061333,-6.955477,-60.45436,418.3087,-872.8088,761.9777,-241.1359],[-0.0008024276,0.7467273,-5.591583,92.70041,-380.2072,658.1632,-517.1637,152.3574],
							[0.0007520252,1.310252,8.664477,-9.898132,-359.5616,1518.347,-2446.942,1772.75,-483.6743]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"brg", "Miscellaneous", [
							[-0.0005569724,3.598096,-128.353,3642.699,-52683.23,450437.8,-2466718,9070761,-2.30124e+07,4.075804e+07,-5.026342e+07,4.229463e+07,-2.31529e+07,7432520,-1061789],
							[0.001814115,-0.8352974,32.73938,-473.9859,3400.082,-13694.43,32841.85,-47790.99,41383.98,-19619.98,3922.571],
							[1.002352,-2.748123,31.70079,-467.2322,3371.677,-13618.78,32717.7,-47669.99,41319.84,-19605.73,3922.571]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"gist_rainbow", "Miscellaneous", [
							[0.9998056,16.73438,-1613.674,61346.36,-1259948,1.603787e+07,-1.368809e+08,8.239254e+08,-3.617589e+09,1.184536e+10,-2.931683e+10,5.518802e+10,-7.897766e+10,8.523917e+10,-6.818115e+10,3.915922e+10,-1.526054e+10,3.611896e+09,-3.917856e+08],
							[-0.0001738693,-0.3934147,-100.5865,7462.335,-137611.8,1143246,-2991509,-2.68824e+07,3.200039e+08,-1.699809e+09,5.765079e+09,-1.365678e+10,2.336954e+10,-2.91662e+10,2.635739e+10,-1.681866e+10,7.192099e+09,-1.850438e+09,2.166262e+08],
							[0.1601925,-14.84199,794.972,-25136.91,480696.2,-5913733,4.953337e+07,-2.949579e+08,1.288189e+09,-4.215369e+09,1.047341e+10,-1.987913e+10,2.88025e+10,-3.159208e+10,2.576793e+10,-1.513602e+10,6.048294e+09,-1.471178e+09,1.643269e+08]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"rainbow", "Miscellaneous", [
							[0.5001498,-4.354137,218.3764,-7207.772,120843.8,-1193016,7538821,-3.21559e+07,9.580327e+07,-2.032831e+08,3.091743e+08,-3.346945e+08,2.518038e+08,-1.25144e+08,3.694108e+07,-4904646],[-0.001247067,3.04538,0.7957139,-7.682188,3.841094],
							[0.9974692,0.06258826,-1.51852,0.4545314]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"jet", "Miscellaneous", [
							[9.530817e-05,-6.013702,573.5187,-21532.53,436111.5,-5460347,4.564564e+07,-2.675394e+08,1.13616e+09,-3.574124e+09,8.446758e+09,-1.510449e+10,2.044509e+10,-2.079881e+10,1.563716e+10,-8.422029e+09,3.071699e+09,-6.791723e+08,6.869829e+07],
							[-7.115363e-06,9.645774,-958.1951,37326.1,-775502.6,9834169,-8.25421e+07,4.845279e+08,-2.06503e+09,6.551605e+09,-1.571655e+10,2.873057e+10,-4.004324e+10,4.223967e+10,-3.314788e+10,1.875035e+10,-7.223587e+09,1.696116e+09,-1.831123e+08],
							[0.4997902,7.644723,-302.7537,9921.265,-161086,1534750,-9418685,3.794642e+07,-9.272047e+07,7.344644e+07,3.814001e+08,-1.78678e+09,4.110009e+09,-6.138973e+09,6.292081e+09,-4.416626e+09,2.037044e+09,-5.57502e+08,6.870991e+07]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"nipy_spectral", "Miscellaneous", [
							[-0.001206257,53.31128,-4299.214,163237.6,-3316665,4.133337e+07,-3.454638e+08,2.046836e+09,-8.901047e+09,2.903197e+10,-7.191536e+10,1.360109e+11,-1.961268e+11,2.137749e+11,-1.729889e+11,1.006479e+11,-3.977534e+10,9.554834e+09,-1.052669e+09],
							[-9.864143e-05,-13.25711,1333.054,-52527.71,1102747,-1.408904e+07,1.183304e+08,-6.873801e+08,2.859697e+09,-8.719151e+09,1.974626e+10,-3.337548e+10,4.193378e+10,-3.860321e+10,2.528916e+10,-1.116758e+10,2.986101e+09,-3.693357e+08,1853919],
							[-0.0006056399,5.900594,159.1363,4982.974,-301372.2,5445169,-5.407943e+07,3.463394e+08,-1.540796e+09,4.964353e+09,-1.187217e+10,2.135994e+10,-2.904603e+10,2.973474e+10,-2.259205e+10,1.237664e+10,-4.630595e+09,1.061123e+09,-1.125584e+08]
						]
					)
				); 
				add(
					new RegressionColorMap(
						"gist_ncar", "Miscellaneous", [
							[-0.0003636799,16.80427,-1564.536,57053.79,-1119805,1.359276e+07,-1.105008e+08,6.333613e+08,-2.650792e+09,8.297157e+09,-1.972478e+10,3.590456e+10,-5.009425e+10,5.320661e+10,-4.230506e+10,2.440159e+10,-9.646657e+09,2.338251e+09,-2.620135e+08],
							[0.001020357,-73.79832,6854.985,-216902.5,3557532,-3.561335e+07,2.374844e+08,-1.10875e+09,3.724163e+09,-9.093487e+09,1.602623e+10,-1.966945e+10,1.497659e+10,-3.485777e+09,-6.402194e+09,8.532396e+09,-5.089658e+09,1.599026e+09,-2.143133e+08],
							[0.5014435,100.752,-9618.786,320063,-5681982,6.387999e+07,-4.958721e+08,2.793526e+09,-1.177335e+10,3.779987e+10,-9.333461e+10,1.777016e+11,-2.59914e+11,2.889721e+11,-2.394783e+11,1.430871e+11,-5.817503e+10,1.439236e+10,-1.633829e+09]
						]
					)
				); 
			} 
			
		} 
		
		alias colorMaps = Singleton!StandardColorMaps; 
	}
	
}version(/+$DIDE_REGION Dialogs+/all)
{
	
	uint messageBox(HWND hwnd, string text, string caption, uint flags)
	{
		//Todo: !!!!!!!!!!!!!! zero terminate strings!!!
		return MessageBoxW(hwnd, text.toUTF16z, caption.toUTF16z, flags); 
	} 
	
	void showMessage(string text)
	{ messageBox(null, text, "", MB_OK); } 
	
	//browseForFolder /////////////////////////////////////////////////////////////////////////
	
	
	extern (Windows) int _browseCallback(HWND hwnd, uint uMsg, LPARAM lParam, LPARAM lpData)
	{
		switch(uMsg) {
			case BFFM_INITIALIZED: {
				if(lpData)
				SendMessage(hwnd, BFFM_SETSELECTION, 1, lpData); 
				break; 
			}
			default: 
		}
		return 0; 
	} 
	
	Path browseForFolder(HWND hwnd, string title, Path foldr)
	{
		Path res; 
		BROWSEINFO bi; 
		with(bi) {
			hwndOwner = hwnd; 
			pszDisplayName = cast(wchar*)toPWChar(title); 
			lpszTitle = toPWChar(title); 
			ulFlags = BIF_RETURNONLYFSDIRS; 
			lpfn = &_browseCallback; 
			lParam = cast(LPARAM)toPWChar(foldr.dir); 
		}
		auto itemIDList = SHBrowseForFolder(&bi); 
		if(itemIDList) {
			wchar[MAX_PATH] str; 
			if(SHGetPathFromIDList(itemIDList, str.ptr)) { res.dir = toStr(str.ptr); }
			CoTaskMemFree(itemIDList); 
		}
		return res; 
	} 
	
	private string checkCommDlgError(int res)
	{
		
		if(res) return ""; //no error
		
		import core.sys.windows.commdlg, core.sys.windows.cderr; 
		auto err = CommDlgExtendedError; 
		
		if(err==0) return "CDERR_CANCEL"; 
		
		immutable errorStrs = [
			"CDERR_DIALOGFAILURE",
			"CDERR_FINDRESFAILURE",
			"CDERR_INITIALIZATION",
			"CDERR_LOADRESFAILURE",
			"CDERR_LOADSTRFAILURE",
			"CDERR_LOCKRESFAILURE",
			"CDERR_MEMALLOCFAILURE",
			"CDERR_MEMLOCKFAILURE",
			"CDERR_NOHINSTANCE",
			"CDERR_NOHOOK",
			"CDERR_NOTEMPLATE",
			"CDERR_STRUCTSIZE",
			"FNERR_BUFFERTOOSMALL",
			"FNERR_INVALIDFILENAME",
			"FNERR_SUBCLASSFAILURE"
		]; 
		
		static foreach(e; errorStrs)
		mixin(format(q{if(err==%s) return "%s"; }, e, e)); 
		
		return "CDERR_UNKNOWN"; 
	} 
	
	
	class FileDialog
	{
		HWND owner; 
		string what; 	//the name of the thing. Title is auto-generated.
		string defaultExt; 	//up to 3 letters without leading '.'
		string filter; 	//in custom format. See -> processExtFilter()
		Path initialPath; 
		
		this(HWND owner_, string what_, string defaultExt_, string filter_, Path initialPath_ = Path.init)
		{
			//bah... this sucks in D
			owner = owner_; 
			what = what_; 
			defaultExt = defaultExt_; 
			filter = filter_; 
			initialPath = initialPath_; 
		} 
		
		
		auto open(File fileName=File.init)
		{
			return File  (
				getFileName(
					GetFileNameMode.Open, 
					owner, what, fileName.fullName, defaultExt, filter, initialPath.dir
				)
			); 
		} 
		auto openMulti(File fileName=File.init)
		{
			return toList(
				getFileName(
					GetFileNameMode.OpenMulti, 
					owner, what, fileName.fullName, defaultExt, filter, initialPath.dir
				)
			); 
		} 
		auto saveAs(File fileName=File.init)
		{
			return File	 (
				getFileName(
					GetFileNameMode.SaveAs, 
					owner, what, fileName.fullName, defaultExt, filter, initialPath.dir
				)
			); 
		} 
		auto renameTo	(File fileName=File.init)
		{
			return File	 (
				getFileName(
					GetFileNameMode.RenameTo, 
					owner, what, fileName.fullName, defaultExt, filter, initialPath.dir
				)
			); 
		} 
		
		private: 
		
		File[] toList(string s)
		{
			
			const list = s.split('\0'); 
			return list.length.predSwitch(
				0, File[].init,
						1,	[File(list[0])],
							list[1..$].map!(a => File(list[0], a)).array
			); 
			
			/*
				 Example of why old school programming is bad.
				
						File[] res;
						if(s.empty) return res;
				
						//converts zero separated list from the form [basePath,name1,name2...] to [file1,file2...]
						auto list = s.split('\0');
						if(list.length==1){
							res = [File(list[0])];
						}else{
							res.reserve(list.length-1);
							if(list.length<2) return res;
							foreach(i; 1..list.length)
								res ~= File(list[0], list[i]);
						}
				
						return res;
			*/
		} 
		
		enum GetFileNameMode { Open, OpenMulti, Save, SaveAs, RenameTo} 
		
		static private string getFileName(
			GetFileNameMode mode, HWND owner, string what, string fileName, 
			string defaultExt, string filter, string initialDir
		)
		{
			import core.sys.windows.commdlg; 
			
			bool isOpen = mode==GetFileNameMode.Open || mode==GetFileNameMode.OpenMulti; 
			bool isMulti = mode==GetFileNameMode.OpenMulti; 
			
			OPENFILENAMEW ofn; 
			ofn.hwndOwner = owner; 
			ofn.Flags = OFN_OVERWRITEPROMPT | OFN_EXPLORER | OFN_EXTENSIONDIFFERENT; 
			if(isMulti	) ofn.Flags |= OFN_ALLOWMULTISELECT; 
			
			//Note: this is commented out to allow using virtual files in hetLib.
			//if(isOpen	) ofn.Flags |= OFN_FILEMUSTEXIST;
			ofn.Flags |= OFN_NOVALIDATE; 
			/+
				Todo: this workaround is needed to extract `virtual:\file.ext` files. 
						Because there will be the current path in front of that.
			+/
			//-> if(f.fullName.isWild(`*\?*:*`)) f.fullName = wild[1].split('\\').back~':'~wild[2];
			//Todo: make options for this:  mustExists, noValidate
			
			if(!isOpen	) ofn.Flags |= OFN_NOREADONLYRETURN; 
			
			/+
				Note: change file type won't refresh folder bug -> 
						https://stackoverflow.com/questions/922204/getopenfilename-does-not-refresh-when-changing-filter
			+/
			//filename
			wchar[0x1000] fileStr; 
			fileStr[] = 0; 
			fileStr[0..fileName.length] = fileName.to!wstring[]; 
			ofn.lpstrFile = fileStr.ptr; 
			ofn.nMaxFile = fileStr.length; 
			
			//initialDir
			ofn.lpstrInitialDir = initialDir.toPWChar; 
			
			//filter
			filter = processExtFilter(filter, true); 
			ofn.lpstrFilter = filter.toPWChar; 
			uint filterHash = xxh32(filter); 
			string filterIniEntry = format("FileFilterIndex%8x", filterHash); 
			ofn.nFilterIndex = ini.read(filterIniEntry, "1").to!int; 
			
			//default ext
			ofn.lpstrDefExt = defaultExt.toPWChar; 
			
			//title
			string title; 
			if(what!="")
			{
				string fn = File(fileName).name; 
				if(fn!="") fn = `"`~fn~`"`; 
				
				with(GetFileNameMode)
				final switch(mode)
				{
					case Open	: title = "Open "~what; break; 
					case OpenMulti	: title = "Open "~what~" (multiple files can be selected)"; break; 
					case Save	: title = "Save "~what; break; //this is the first save
					case SaveAs	: title = "Save "~what~` `~fn~` As`; break; 
					case RenameTo	: title = "Rename "~what~` `~fn~` To`; break; 
				}
				
				ofn.lpstrTitle = title.toPWChar; 
			}
			
			//execute
			auto res = isOpen 	? GetOpenFileNameW(&ofn)
				: GetSaveFileNameW(&ofn); 
			
			string err = checkCommDlgError(res); 
			bool ok = err==""; 
			
			//save filterIndex
			ini.write(filterIniEntry, ofn.nFilterIndex.to!string); 
			
			if(err=="CDERR_CANCEL") fileName = err = ""; //cancel is no error, but empty fileName
			
			//check errors
			enforce(err=="", "FileDialog.getFileName(): "~err); 
			
			//read back filename
			if(ok) {
				if(isMulti) {
					 //extract the whole double zero terminated string
					int zcnt=0; 
					foreach(ch; fileStr) {
						if(ch) zcnt=0; else zcnt++; 
						if(zcnt==2) break; 
						fileName ~= ch; 
					}
					if(!fileName.empty) fileName = fileName[0..$-1]; 
					//remove last '\0', make it az a zero separated list.
				}
				else { fileName = ofn.lpstrFile.to!string; }
			}
			else { fileName=""; }
			
			return fileName; 
		} 
		
			
		
	} 
	
	
	//utility stuff ///////////////////////////////////////////////////////////////////////////////
	
	/*
		***********************************
			* Input special chars:	"(" ")" brackets creating groups.
			*	"," comma separates multiple subgroups inside a group
			* Example input: "All files(Pictures(*.bmp;*.jpg),Sound files(*.wav;*.mp3))"
			* Returns: double zero terminated list of (filterName, filterExtList) pairs later used by getOpenFileName and others.
	*/
	private string processExtFilter(string filter, bool includeExts)
	{
		void enforce(bool b, lazy string s)
		{ if(!b) .enforce(b, "processExtFilter(): "~s); } 
		
		//test filter=`All Files(Program files(Sources(*.d),Executables(*.exe;*.com;*.bat)),Graphic Files(Bitmaps(*.bmp),Jpeg files(*.jpg;*.jpeg))))`;
		string[] names; 
		string[] filterNames, filterExts; 
		string act; 
		
		void emit()
		{
			string a = act.strip; 
			if(!a.empty)
			{
				foreach(n; names)
				{
					int idx = cast(int)filterNames.countUntil(n); 
					if(idx<0) { filterNames ~= n; filterExts ~= ""; idx = cast(int)filterNames.length-1; }
					if(!filterExts[idx].empty) filterExts[idx] ~= ";"; 
					filterExts[idx] ~= a; 
				}
			}
			//reset act
			act = ""; 
		} 
		
		foreach(ch; filter)
		{
			switch(ch)
			{
				case '(': 
					names ~= act.strip; 
					act = ""; 
				break; 
				case ')': 
					emit; 
					enforce(!names.empty, "too many closing brackets ')'"); 
					names = names[0..$-1]; 
				break; 
				case ',': case ';': 
					emit; 
				break; 
				default: 
					act ~= ch; 
			}
		}
		enforce(names.empty, "unclosed brackets"); 
		enforce(act.strip=="", "garbage at end"); 
		
		//combine
		string filterStr; 
		foreach(i, n; filterNames) {
			if(includeExts) n ~= " ("~filterExts[i].replace(";", " ")~")"; 
			filterStr ~= n ~ "\0" ~ filterExts[i] ~ "\0"; 
		}
		filterStr ~= '\0'; //double zero terminate
		
		//test writeln(filterStr.replace("\0", "\n"));
		
		return filterStr; 
	} 
	
	RGB chooseColor(HWND hwnd, RGB color, bool fullOpen)
	{
		import core.sys.windows.commdlg; 
		static uint[16] customColors; //Todo: save/load ini
		CHOOSECOLOR cc = {
			hwndOwner: hwnd,
			rgbResult: color.raw,
			lpCustColors: customColors.ptr,
			Flags: CC_RGBINIT | CC_ANYCOLOR | (fullOpen ? CC_FULLOPEN : 0)
		}; 
		RGB8 res = color; 
		if(ChooseColor(&cc)) res = RGB(cc.rgbResult); 
		return res; 
	} 
	
	//testing /////////////////////////////////
	
	void testDialogs()
	{
		print(browseForFolder(null, "title", appPath)); 
		
		print(new FileDialog(null, "Dlang source file", ".d", "Sources(*.d)", appPath).open); 
		
		print(chooseColor(null, clBlue, false)); 
		print(chooseColor(null, clAqua, true )); 
	} 
	
	
	class FileOps
	{
		enum Op
		{ FileLoad, FileSave, UndoLoad, UndoSave} 
		
		private {
			alias Data = ubyte[]; 
			
			//filename, protected from outside
			File fileName_; 
			@property fileName(File fn)
			{ fileName_ = fn; } 
			public @property File fileName() const
			{ return fileName_; } 
			
			public  File defaultSaveFileName; //app sets it. For the new file being saved
			
			Data fileData; 
			FileDialog fileDialog; 
			
			int savedCnt=0; //if == 0 -> cansave is false.
			//new, open, save, saveas: set to 0
			//undo: dec;  redo: inc;  chg: inc if >=0
			
			immutable historyMaxSize = 20; 
			File[] history; 
			
			struct UndoRec
			{
				Data data; 
				string caption; 
			}; 
			
			bool lastOpWasNew, blockChg; 
			Data lastData; //saved before chg()
			UndoRec[] undoBuf, redoBuf; 
			
			File delegate(File) onSave; 
			File delegate() onLoad; 
			void delegate(Op) onFileOp; 
		} 
		
		this(FileDialog fileDialog_, void delegate(Op) onFileOp_)
		{
			assert(fileDialog_); 
			assert(onFileOp_); 
			
			fileDialog = fileDialog_; 
			onFileOp = onFileOp_; 
			
			clickNew; 
		} 
		
		bool isChanged()	     const
		{ return savedCnt!=0; } 
		bool isNew()	     const
		{ return lastOpWasNew && !isChanged; } 
		
		size_t undoCount()	     const
		{ return undoBuf.length; } 
		size_t redoCount()	     const
		{ return redoBuf.length; } 
		string undoCaption()	 const
		{ return canUndo ? undoBuf[$-1].caption : ""; } 
		string redoCaption()	 const
		{ return canRedo ? redoBuf[$-1].caption : ""; } 
		
		string fileCaption()  const
		{ return (isChanged?"*":"")~(fileName.toString=="" ? "unnamed" : fileName.toString); } 
		
		size_t memUsage() const
		{
			return fileData.sizeof +
						 undoBuf.map!"a.data.sizeof".sum +
						 redoBuf.map!"a.data.sizeof".sum; 
		} 
		
		string stats() const
		{
				//Todo: erre a stats()-ra valami mixint csinalni, tul sok az ismetles
			return format(
				"undoCnt:%d redoCnt:%d isChanged:%d isNew:%d memUsage:%d savedCnt:%d fileName:%s",
								   undoCount, redoCount, isChanged,   isNew,   memUsage,   savedCnt,   fileName
			); 
		} 
		
		bool canCloseApp()
		{
				//should be called before exit
			return trySaveBeforeNewOrOpen; 
		} 
		
		struct action
		{} 
		
		//user commands
		@action
		{
			void clickNew()
			{ new_(true); } 
			
			void clickDiscard()
			{ new_(false); } 
			
			void clickOpen()
			{ open(File("")); } 
			
			bool canSave()        const
			{ return isChanged || isNew; } 
			void clickSave()
			{
				if(!fileName)
				{ clickSaveAs; return; }
				save(fileName); //Save always, even when unchanged!!!!
			} 
			
			void clickSaveAs()
			{
				auto fn = fileDialog.saveAs(fileName ? fileName : defaultSaveFileName); 
				if(!fn)
				return; 
				save(fn); 
			} 
			
			bool canUndo() const
			{ return undoCount>0; } 
			void clickUndo()
			{
				if(!canUndo)
				return; 
				redoBuf ~= UndoRec(lastData, ""); 
				lastData = undoBuf.back.data; 
				undoBuf.popBack; 
				contentLoad(lastData, false); 
				savedCnt--; 
			} 
			
			bool canRedo() const
			{ return redoCount>0; } 
			void clickRedo()
			{
				if(!canRedo)
				return; 
				undoBuf ~= UndoRec(lastData, ""); 
				lastData = redoBuf.back.data; 
				redoBuf.popBack; 
				contentLoad(lastData, false); 
				savedCnt++; 
			} 
		} 
		
		//editor notifies this when there is a modification
		void notifyChg(string undoCaption = "")
		{
			redoBuf.clear; 
			undoBuf ~= UndoRec(lastData, undoCaption); 
			lastData = contentSave(false); 
			if(savedCnt>=0)
			++savedCnt; 
		} 
		
		private: 
			void clearUndo()
		{
			undoBuf.clear; 
			redoBuf.clear; 
			savedCnt = 0; 
		} 
		
			void contentLoad(Data data_, bool isFile)
		{
			blockChg = true; 
			fileData = data_; 
			onFileOp(isFile ? Op.FileLoad : Op.UndoLoad); 
			blockChg = false; 
		} 
			Data contentSave(bool isFile)
		{
			fileData = null; 
			onFileOp(isFile ? Op.FileSave : Op.UndoSave); 
			return fileData; 
		} 
		
			//internal commands  (fn=="" means file dialog query)
			bool new_(bool trySave = true)
		{
			if(trySave && !trySaveBeforeNewOrOpen)
			return false; 
			
			fileName.fullName = ""; 
			lastOpWasNew = true; 
			contentLoad(null, true); 
			clearUndo; 
			
			return true; 
		} 
		
			bool open(File fn, bool trySave = true)
		{
			  //!!!!!!!trysave-nek mindig igaznak kene lennie, viszont akkor kellene discard parancs
			if(trySave && !trySaveBeforeNewOrOpen)
			return false; 
			
			if(!fn)
			{
				fn = onLoad(); //!!!!!!!!!!!!!!!Ezeket a dialogokat inkabb egy FileDialog class-al kene csinalni.
				if(!fn)
				return false; 
			}
			
			fileName = fn; 
			lastOpWasNew = false; 
			contentLoad(fn.read, true); 
			lastData = contentSave(false); //Why???????
			clearUndo; 
			
			return true; 
		} 
		
			bool save(File fn)
		{
			if(!fn)
			{
				fn = fileDialog.saveAs(File("")); 
				if(!fn)
				return false; 
			}
			
			fileName = fn; 
			lastOpWasNew = false; 
			fileName.write(contentSave(true)); 
			
			//undoBuf.clear(); redoBuf.clear(); NO undo clear on save!!!!
			savedCnt = 0; //only savecnt.reset
			
			return true; 
		} 
		
			void updateHistory()
		{
			if(!fileName)
			return; 
			if(!history.empty && history[0]==fileName)
			return; 
			
			//remove older items of the same name
			history = history.filter!(h => h!=fileName).array; 
			
			//insert latest fileName
			history = fileName ~ history; 
			
			//restrict history size
			if(history.length>historyMaxSize)
			history.length = historyMaxSize; 
		} 
		
			//saves before New or Open. returns true if saved or nothing to save or user don't wanna save.
			bool trySaveBeforeNewOrOpen()
		{
			if(!isChanged())
			return true; 
			
			switch(
				messageBox(
					fileDialog.owner, 
					"The edited "~fileDialog.what~" has been modified.\nDo you want to save your changes?", 
					"Unsaved changes", MB_ICONWARNING|MB_YESNOCANCEL
				)
			)
			{
				case IDYES: return save(fileName); 
				case IDNO: return true; 
				default: return false; 
			}
		} 
	} 
}
version(/+$DIDE_REGION Date Time handling+/all)
{
	version(/+$DIDE_REGION+/all)
	{
		void sleep(int ms) { Sleep(ms); } 
		
		void sleep(in Time t) { sleep(t.value(milli(second)).to!int); } 
		
		immutable string[12] MonthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]; 
		
		immutable monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]; 
		
		
		bool isLeapYear(int year)
		{ return year%4==0 && (year%100!=0 || year%400==0); } 
		
		 //Todo: delete old crap from datetime
		
		version(/+$DIDE_REGION Old routines+/all)
		{
			private
			{
				enum dateReference = 693594; 
				enum secsInDay = 24*60*60; 
				enum msecsInDay = secsInDay*1000; 
				
				immutable monthDays2 = [
					[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31],
					[31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
				]; 
				
				deprecated double encodeTime(int hour, int min, int sec, double ms)
				{ return (((ms/1000+sec)/60+min)/60+hour)/24; } 
				
				deprecated double encodeDate(int year, int month, int day)
				{
					//returns NaN if invalid
					auto dayTable = monthDays2[isLeapYear(year)][]; //Opt: It calculates isleap for every month.
					if(inRange(year,  1, 9999) && inRange(month, 1, 12) && inRange(day, 1, dayTable[month-1]))
					{
						foreach(i; 0..month-1) day += dayTable[i]; 
						int i = year-1; 
						return i*365 + i/4 - i/100 + i/400 + day - dateReference; 
					}
					else
					{ return double.nan; }
				} 
						
				deprecated public SYSTEMTIME decodeDate(double dateTime)
				{
					enum 	D1 = 365,
						D4 = D1 * 4 + 1,
						D100 = D4 * 25 - 1,
						D400 = D100 * 4 + 1; 
							
					SYSTEMTIME result; 
					if(isnan(dateTime)) return result; 
					int D, I, T = ifloor(dateTime)+dateReference; 
					if(T<=0) return result; 
							
					result.wDayOfWeek = cast(ushort)(T%7 + 1); 
					T--; 
					int Y = 1; 
					while(T>=D400) {
						T -= D400; 
						Y += 400; 
					}
					divMod(T, D100, I, D); 
					if(I==4) {
						I--; 
						D += D100; 
					}
					Y += I*100; 
					divMod(D, D4, I, D); 
					Y += I*4; 
					divMod(D, D1, I, D); 
					if(I==4) {
						I--; 
						D += D1; 
					}
					Y += I; 
							
					auto dayTable = monthDays2[isLeapYear(Y)][]; 
					int M = 0; 
					while(1) {
						I = dayTable[M]; 
						if(D<I) break; 
						D -= I; 
						M++; 
					}
					result.wYear	= cast(ushort)Y; 
					result.wMonth	= cast(ushort)(M+1); 
					result.wDay	= cast(ushort)(D+1); 
					return result; 
				} 
						
				deprecated SYSTEMTIME decodeTime(double dateTime)
				{
					SYSTEMTIME result; 
					if(isnan(dateTime)) return result; 
					int M, I = iround(fract(dateTime)*msecsInDay); 
					with(result) {
						divMod(I, 1000, I, M); 	wMilliseconds	= cast(ushort)M; 
						divMod(I,		60, I, M); 	wSecond	= cast(ushort)M; 
						divMod(I,		60, I, M); 	wMinute	= cast(ushort)M; 
							wHour	= cast(ushort)I; 
					}
					return result; 
				} 
						
				deprecated SYSTEMTIME decodeDateTime(double dateTime)
				{
					auto d = decodeDate(dateTime),
							 t = decodeTime(dateTime); 
					d.wMilliseconds	= t.wMilliseconds; 
					d.wSecond	= t.wSecond					; 
					d.wMinute	= t.wMinute					; 
					d.wHour	= t.wHour	; 
					return d; 
				} 
						
				int dblCmp(const double a, const double b) { return a>b ? 1 : a<b ? -1 : 0; } 
						
				int year2k(int y) {
					if(y< 50) y += 2000; 
					if(y<100) y += 1900; 
					return y; 
				} 
			} 
		}
		
		//this one is a new routine: 230920
		void adjustDate(Y, M, D)(ref Y year, ref M month, ref D day)
		if(allSatisfy!(isIntegral, Y, M, D))
		{
			static void adjustYear(Y)(ref Y year)
			if(isIntegral!Y)
			{
				//it's just an error check because there is no possible overflow from here
				enforce(
					DateTime.RawUnit._minYear <= year && 
					DateTime.RawUnit._maxYear+1/+include the last fraction year too+/ >= year, 
					year.format!"adjustYear(): Out of range: %s"
				); 
			} 
			
			static void adjustMonth(Y, M)(ref Y year, ref M month)
			if(allSatisfy!(isIntegral, Y, M))
			{
				if(month.inRange(1, 12)) {/+it's a correct month index.+/}
				else if(month<=24) { month -= 12; year++; }
				else if(month >= -11) { month += 12; year--; }
				else {
					auto Δy = month>0 ? (month-1)/12 : -((12-month)/12); 
					month -= Δy*12; 
					year += Δy; 
				}
				adjustYear(year); 
			} 
			
			static void adjustDay(Y, M, D)(ref Y year, ref M month, ref D day)
			if(allSatisfy!(isIntegral, Y, M, D))
			{
				auto adjustMonthAndGetNumDays()
				{
					adjustMonth(year, month); 
					int n = monthDays[month-1]; 
					if(n==28 && isLeapYear(year)) n++; 
					return n; 
				} 
				
				if(day.inRange(1, 28)) { adjustMonth(year, month); }
				else if(day<1) {
					while(day<1)
					{
						month--; 
						adjustMonth(year, month); 
						day += adjustMonthAndGetNumDays; 
					}
				}
				else {
					while(1)
					{
						const n = adjustMonthAndGetNumDays; 
						if(day<=n) break; 
						day -= n; 
						month++; 
					}
				}
			} 
			
			adjustDay(year, month, day); 
		} 
		
	}version(/+$DIDE_REGION+/all) {
		
		struct TimeZone { byte shift; } 
		
		enum UTC = TimeZone(0); 
		enum Local = TimeZone(127); 
		
		enum gregorianDaysInYear 	= 365.2524, 
		gregorianDaysInMonth 	= gregorianDaysInYear/12; 
		
		auto RawDateTime(ulong t) { DateTime a; a.raw = t; return a; } 
		
		struct DateTime
		{
			version(/+$DIDE_REGION+/all)
			{
				///a 64-bit value representing the number of 100/64 nanosecond(!!!not 100ns!!!) intervals since January 1, 1601 (UTC).
				ulong raw;      //0 = null
				
				void set(in TimeZone tz, in SYSTEMTIME a)
				{
					switch(tz.shift) {
						case 0: utcSystemTime = a; break; 
						case 127: localSystemTime = a; break; 
						default: throw new Exception("Invalid "~tz.text); 
					}
				} 
				
				void set(in TimeZone tz, in FILETIME a)
				{
					switch(tz.shift) {
						case 0: utcFileTime = a; break; 
						case 127: localFileTime = a; break; 
						default: throw new Exception("Invalid "~tz.text); 
					}
				} 
				
				void set(in TimeZone tz, in string s)
				{ this = parseDateTime(tz, s); } 
				
				this(T)(in T a)
				{ this(Local, a); } this(T)(in TimeZone tz, in T a)
				{ set(tz, a); } 
				
				this(in int y, in int m, in int d, in int h, in int mi=0, in int s=0, in int ms=0)
				{ this(Local, y, m, d, h, mi, s, ms); } 
				this(in TimeZone tz,	in int y, in int m, in int d, in int h, in int mi=0, in int s=0, in int ms=0)
				{
					//Todo: adjust carry overflow
					this(tz, SYSTEMTIME(year2k(y).to!ushort, m.to!ushort, 0, d.to!ushort, h.to!ushort, mi.to!ushort, s.to!ushort, ms.to!ushort)); 
				} 
				
				this(in int y, in int m, in int d)
				{ this(Local, y, m, d); } this(in TimeZone tz, in int y, in int m, in int d)
				{ this(tz   , y, m, d, 0); } 
				
				this(in int y, in int m, in int d, in Time t)
				{ this(Local, y, m, d, t); } this(in TimeZone tz, in int y, in int m, in int d, in Time t)
				{ this(tz, y, m, d); this += t; } 
				
				bool isNull() const
				{ return raw==0; } 
				bool opCast() const
				{ return !isNull(); } 
				nothrow @safe {
					int opCmp(in DateTime b) const
					{ return cmp(raw, b.raw); } 
					bool opEquals(in DateTime b) const
					{ return raw==b.raw; } 
					size_t toHash() const
					{ return raw; } 
				} 
				
				enum RawShift = 6; 
				enum RawUnit : ulong 
				{
					//37ns is the fastest measurable interval. Using Windown 10 QPC
					_100ns	= 1<<RawShift	, //100ns = Unit of FILETIME.  6 extra bits of precision below 100ns. Useful time based unique id generation.
					us	= 10 * _100ns	, μs = us,
					ms	= 1000 * us 	,
					sec	= 1000 * ms 	, //1 sec = Unit of quantities.SI
					min	= 60 * sec 	,
					hour	= 60 * min 	,
					day	= 24 * hour	,
					week	= 7 * day	,
					month	= cast(ulong)(gregorianDaysInMonth * day)	, //Gregorian average
					year	= cast(ulong)(gregorianDaysInYear * day)	,
					_minYear	= 1601,
					_maxYear	= _minYear + ulong.max/year - 1,
					_numYears	= _maxYear - _minYear + 1
				} 
				
				//lock the above calculations
				static assert(RawUnit._numYears==913); //these are all the full years covered
				static assert(RawUnit._numYears * RawUnit.year == 0xffe78926_3bb40000); 
				static assert(format!"%.16f"(double(DateTime.RawUnit.year) / DateTime.RawUnit.day) == "365.2524000000000228"); 
				
				private enum UnixShift_sec = 11644473600; 
				private enum UnixShift_unit = UnixShift_sec*RawUnit.sec; 
				
				static private
				{
					//Conversions between windows local/utc/filetime/systemtime/raw. Also throw exceptions.
					
					double rawToSeconds(in ulong a)
					{ return a*(1.0/RawUnit.sec); } 
					ulong secondsToRaw(in double a)
					{ return (a*RawUnit.sec).to!ulong; } 
					
					auto fileTimeToRaw(in FILETIME ft)
					{
						if(ft.dwHighDateTime > (uint.max>>>RawShift)) throw new ConvException("FileTimeToRaw() overflow."); 
						return ((cast(ulong)ft.dwLowDateTime )<<(RawShift))|
							((cast(ulong)ft.dwHighDateTime)<<(RawShift+32)); 
						//Opt: optimize this. one shift should be enough. High and LowDateTime is in order anyways.
					} 
					
					auto rawToFileTime(in ulong raw)
					{
						return FILETIME(
							cast(uint)(raw>>>(RawShift   )),
							cast(uint)(raw>>>(RawShift+32))
						); 
					} 
					
					import core.sys.windows.windows :
						FileTimeToSystemTime, SystemTimeToFileTime, 
						SystemTimeToTzSpecificLocalTime, TzSpecificLocalTimeToSystemTime; 
					
					//unify 2 parameter form by adding a default null parameter in front
					int MySystemTimeToTzSpecificLocalTime(in SYSTEMTIME* a, SYSTEMTIME* b)
					{ return SystemTimeToTzSpecificLocalTime(null, cast(SYSTEMTIME*)a, b); } 
					int MyTzSpecificLocalTimeToSystemTime(in SYSTEMTIME* a, SYSTEMTIME* b)
					{ return TzSpecificLocalTimeToSystemTime(null, cast(SYSTEMTIME*)a, b); } 
					
					template tmpl(SRC, alias fun, DST)
					{
						auto tmpl()(in SRC src)
						{
							DST dst = void; 
							if(!fun(&src, &dst)) throw new ConvException(__traits(identifier, fun)~"() error.  src: "~src.text); 
							return dst; 
						} 
					} 
					
					alias systemTimeToLocalTzSystemTime	= tmpl!(SYSTEMTIME, MySystemTimeToTzSpecificLocalTime, SYSTEMTIME); 
					alias localTzSystemTimeToSystemTime	= tmpl!(SYSTEMTIME, MyTzSpecificLocalTimeToSystemTime, SYSTEMTIME); 
					alias fileTimeToSystemTime	= tmpl!(FILETIME  , FileTimeToSystemTime, SYSTEMTIME); 
					alias systemTimeToFileTime	= tmpl!(SYSTEMTIME, SystemTimeToFileTime, FILETIME  ); 
				} 
			}version(/+$DIDE_REGION+/all)
			{
				private
				{
					///unified way of getting/setting Local/UTC FILETIME/SYSTEMTIME
					T _get(bool isLocal, T)() const
					{
						const ft = rawToFileTime(raw); 
						static if(isLocal)
						{
							const st = systemTimeToLocalTzSystemTime(fileTimeToSystemTime(ft)); 
							static if(is(T==FILETIME  )) return systemTimeToFileTime(st); 
							static if(is(T==SYSTEMTIME)) return st; 
						}
						else
						{
							static if(is(T==FILETIME  )) return ft; 
							static if(is(T==SYSTEMTIME)) return fileTimeToSystemTime(ft); 
						}
					} 
					
					void _set(bool isLocal, T)(in T src)
					{
						static if(isLocal)
						{
							static if(is(T==FILETIME  )) const st = fileTimeToSystemTime(src); 
							static if(is(T==SYSTEMTIME)) const st = src; 
							_set!false(localTzSystemTimeToSystemTime(st)); //recursion
						}
						else
						{
							static if(is(T==FILETIME  )) const ft = src; 
							static if(is(T==SYSTEMTIME)) const ft = systemTimeToFileTime(src); 
							raw = fileTimeToRaw(ft); 
						}
					} 
				} 
				
				@property
				{
					auto utcFileTime() const
					{ return _get!(false, FILETIME)(); } 	void utcFileTime	(in FILETIME	a)
					{ _set!false(a); } 
					auto utcSystemTime() const
					{ return _get!(false, SYSTEMTIME	)(); } 	void utcSystemTime	(in SYSTEMTIME	a)
					{ _set!false(a); } 
					auto localFileTime() const
					{ return _get!(true , FILETIME	)(); } 	void localFileTime	(in FILETIME	a)
					{ _set!true(a); } 
					auto localSystemTime() const
					{ return _get!(true , SYSTEMTIME	)(); } 	void localSystemTime	(in SYSTEMTIME	a)
					{ _set!true(a); } 
					
					double unixTime() const
					{ return raw ? rawToSeconds(raw-UnixShift_unit) : double.nan; } 
					void unixTime(in double a)
					{ raw = a.isnan ? 0 : secondsToRaw(a)+UnixShift_unit; } 
					
					private enum RawDelphiShift = 109205*RawUnit.day; 
					double localDelphiTime() const
					{
						return isNull	? 0
							: double(fileTimeToRaw(localFileTime)-RawDelphiShift)/RawUnit.day; 
					} 
					void localDelphiTime(double d)
					{
						if(d.isnan || d==0)
						raw = 0; 
						else
						localFileTime = rawToFileTime((d*RawUnit.day).to!ulong + RawDelphiShift); 
					} 
					
					DateTime utcDayStart() const
					{ if(isNull) return this; return RawDateTime(raw - raw%RawUnit.day); } 
					DateTime utcDayEnd	() const
					{ if(isNull) return this; return RawDateTime(utcDayStart.raw + RawUnit.day); } 
					
					DateTime localDayStart() const
					{
						if(isNull) return this; 
						auto st = localSystemTime; 
						st.wHour	= 0; 
						st.wMinute	= 0; 
						st.wSecond	= 0; 
						st.wMilliseconds	= 0; 
						return DateTime(st); 
					} 
					
					DateTime localDayEnd() const
					{
						if(isNull) return this; 
						
						auto	res	= localDayStart + day	,
							st	= res.localSystemTime	,
							diff_ms	= ((st.wHour*60L + st.wMinute)*60 + st.wSecond)*1000L + st.wMilliseconds	; 
						
						if(diff_ms<12L*60*60*1000) res -= 	diff_ms*milli(second); 
						else res += day - 	diff_ms*milli(second); 
						
						return res; 
						
						/+
							Todo: unittest assert(iota(366)	.map!(a => DateTime(2022, 1, 1) + a*day)
								.map!(a => (a.localDayEnd - a.localDayStart).value(hour))
								.uniq
								.equal([24, 23, 24, 25, 24]), "localDayStart/End is bad."); 
						+/
									
					} 
					
					Time utcTime  () const
					{ return this-utcDayStart; } 
					Time localTime() const
					{ return this-localDayStart; } 
					
					Time time() const
					{ return localTime; } 
					DateTime dayStart() const
					{ return localDayStart; } 
				} 
				
				///calculate the difference between DateTimes
				Time opBinary(string op : "-")(in DateTime b) const
				{ return long(raw-b.raw)*(1.0/RawUnit.sec)*het.quantities.second; } 
				
				///adjust DateTime by si.Time
				DateTime opBinary(string op)(in Time b) const if(op.among("+", "-"))
				{
					DateTime res = this; 
					mixin("res.raw", op, "=(b.value(het.quantities.second)*RawUnit.sec).to!long;"); 
					return res; 
				} 
				
				DateTime add_raw(in ulong delta) const
				{ return RawDateTime(raw + delta); } 
				
				///adjust this DateTime by si.Time
				DateTime opOpAssign(string op)(in Time b) if(op.among("+", "-"))
				{
					mixin("raw", op,"= (b.value(het.quantities.second)*RawUnit.sec).to!long;"); 
					return this; 
				} 
				
				private long timeZoneOffset_raw() const
				{
					//Todo: rename to utcOffset (read aboit it on web first!)
					if(raw<RawUnit.day) throw new Exception("Unable to calculate timeZone for NULL"); 
					DateTime dt = void; dt.utcFileTime = localFileTime; 
					return dt.raw-this.raw; 
				} 
				
				Time timeZoneOffset() const
				{
					if(raw<RawUnit.day) throw new Exception("Unable to calculate timeZone for NULL"); 
					DateTime dt = void; dt.utcFileTime = localFileTime; 
					return dt-this; 
				} 
				
				static currentTimeZoneOffset()
				{ return now.timeZoneOffset; } 
				
				static currentTimeZoneName()
				{
					TIME_ZONE_INFORMATION tzi; 
					switch(GetTimeZoneInformation(&tzi))
					{
						case 2: return tzi.DaylightName.text; 
						default: return tzi.StandardName.text; 
					}
				} 
				
				@property
				{
					//dayOfWeek stuff
					//Note: 0=sun, 6=sat
					int localDayOfWeek()
					{ return localSystemTime.wDayOfWeek; } 	int utcDayOfWeek()
					{ return utcSystemTime.wDayOfWeek; } 
					bool localIsWeekend()
					{ return localDayOfWeek.among(0, 6)!=0; } 	bool utcIsWeekend()
					{ return utcDayOfWeek.among(0, 6)!=0; } 
					bool localIsWeekday()
					{ return !localIsWeekend; } 	bool utcIsWeekday()
					{ return !utcIsWeekend; } 
				} 
			}version(/+$DIDE_REGION+/all)
			{
				/// This is the hash for bitmap objects
				ulong toId_deprecated() const
				{ return raw; } 
				
				/// Sets to now. Makes sure it will greater than the actual value. Used for change notification.
				auto actualize()
				{
					auto c = now.raw; 
					if(isNull || c>raw) raw = c; 
					else raw++; //now it's the exact same as the previous one. Just increment.
					
					return this; 
				} 
				
				string dateText(alias fun = localSystemTime)() const
				{
					//Todo: format
					if(isNull) return "NULL Date"; 
					with(fun) return format!"%.4d.%.2d.%.2d"(wYear, wMonth, wDay); 
				} 
				
				string timeText(alias fun = localSystemTime)() const
				{
					//todo format
					if(isNull) return "NULL Time"; 
					with(fun) return format!"%.2d:%.2d:%.2d.%.3d"(wHour, wMinute, wSecond, wMilliseconds); 
				} 
				
				string toString(alias fun = localSystemTime)()const
				{
					if(isNull) return "NULL DateTime"; 
					with(fun) return format("%.4d.%.2d.%.2d %.2d:%.2d:%.2d.%.3d", wYear, wMonth, wDay, wHour, wMinute, wSecond, wMilliseconds); 
				} 
				
				string timestamp(alias fun = localSystemTime)(in Flag!"shortened" shortened = No.shortened)const
				{
					//Note: ⚠TimeView depends on this format!!!!
					//Todo: make a proper datetimeformatter tool.
					
					if(isNull) return "null"; 
					//4 digit year is better. return format("%.2d%.2d%.2d-%.2d%.2d%.2d-%.3d", year%100, month, day, hour, min, sec, ms);
					//return format("%.4d%.2d%.2d-%.2d%.2d%.2d-%.3d", year, month, day, hour, min, sec, ms);
					
					//windows timestamp format (inserts it after duplicate files)
					string s; 
					with(fun) s = format("%.4d-%.2d-%.2dT%.2d%.2d%.2d.%.3d", wYear, wMonth, wDay, wHour, wMinute, wSecond, wMilliseconds); 
					
					if(shortened) {
						 //Todo: not so fast
						if(s.endsWith(".000")) {
							s = s[0..$-4]; 
							if(s.endsWith("00")) {
								s = s[0..$-2]; 
								if(s.endsWith("0000")) { s = s[0..$-4]; }
							}
						}
					}
					
					return s; 
				} 
				
				string timestamp_compact(alias fun = localSystemTime)()const
				{ return timestamp!fun(Yes.shortened); } 
				
				//Todo: utcXXX not good! should ude TimeZone as first param
				string utcDateText() const
				{ return dateText!utcSystemTime; } 
				string utcTimeText() const
				{ return timeText!utcSystemTime; } 
				string utcToString() const
				{ return toString!utcSystemTime; } 
				string utcText() const
				{ return utcToString; } 
				string utcTimestamp(in Flag!"shortened" shortened = No.shortened)const
				{ return timestamp!utcSystemTime(shortened); } 
				string utcTtimestamp_compact()const
				{ return utcTimestamp(Yes.shortened); } 
				
				@property int utcYearMonth(DateTime d)
				{ if(!this) return 0; with(utcSystemTime) return wYear*100 + wMonth; } 
				
				@property int utcYearQuarter(DateTime d)
				{ if(!this) return 0; with(utcSystemTime) return wYear*10 + ((wMonth-1)/3)+1; } 
				
				@property int utcYear(DateTime d)
				{ if(!this) return 0; with(utcSystemTime) return wYear; } 
				
				static
				{
					//self diagnostics
					
					void selftest()
					{ enforce(DateTime(2000, 1, 2) - DateTime(RawUnit._minYear, 1, 2) == 145731 * day); } 
					
					void benchmark()
					{
						print("DateTime RawUnits"); 
						foreach(a; EnumMembers!(DateTime.RawUnit))
						format!"%-10s %29d %16x"(a, a, a).replace(' ', '_').print; 
						
						print; 
						print("now() call frequency: "); 
						20.iota.map!(a => now).array.slide(2).each!((a){ (a[1]-a[0]).siFormat!"%8.0f ns".print; } ); 
						
						void bench(string code, size_t N=1000)()
						{
							write(code, "   //"); 
							const t0 = now; 
							mixin(code); 
							((now-t0)/N).siFormat!"%8.0f ns".print; 
						} 
						
						print; 
						bench!q{foreach(i; 0..N) cast(void)now; 	}; 
						bench!q{N.iota.each!((i){ cast(void)now; } ); 	}; 
						bench!q{foreach(i; 0..N) cast(void)(now-now); 	}; 
						bench!q{foreach(i; 0..N) cast(void).today; 	}; 
						bench!q{foreach(i; 0..N) cast(void).time; 	}; 
						
						void dstTest()
						{
							void doit(bool summer)
							{
								const m = summer ? 7 : 1; 
								print; 
								print((m?"Winter":"Summer")~" DST test:"); 
								print("  UTC   -> UTC   ", DateTime(UTC	 ,	21, m,30,12).toString!(DateTime.utcSystemTime)); 
								print("  UTC   -> Local ", DateTime(UTC	 ,	21, m,30,12)); 
								print("  Local -> UTC   ", DateTime(21, m,30,12).toString!(DateTime.utcSystemTime)); 
								print("  Local -> Local ", DateTime(21, m,30,12)); 
							} 
							doit(0); doit(1); 
							
							print; 
							print("Test local-utc for 12 31*24hour steps."); 
							foreach(u; [UTC, Local])
							iota(12)	.map!(i => DateTime(u, 21, 1, 30, 12) + i*31*day)
								.enumerate.map!(
								a => //A month is not a real month!!!! it's 32*24 hours!!!!
								format!"%2s %2s %2s"
								(a[0], a[1].utcSystemTime.wHour, a[1].localSystemTime.wHour)
							)
								.each!print; 
						} 
						dstTest; 
					} 
					
				} 
			}
		} 
	}version(/+$DIDE_REGION+/all)
	{
		private extern(Windows) nothrow @nogc void GetSystemTimePreciseAsFileTime(FILETIME*); 
		
		DateTime now()
		{
			DateTime dt = void; FILETIME ft = void; 
			GetSystemTimePreciseAsFileTime(&ft); 
			dt.utcFileTime = ft; 
			return dt; 
		} 
		
		DateTime UnixDateTime(uint a)
		{ return RawDateTime(a ? DateTime.UnixShift_unit + a*DateTime.RawUnit.sec : 0); } 
		
		DateTime DosDateTime(uint a)
		{
			FILETIME ft; 
			if(DosDateTimeToFileTime(a>>16, a & 0xFFFF, &ft)) return DateTime(ft); 
			return DateTime.init; 
		} 
		
		DateTime uniqueNow()
		{
			/+
				Note: The average difference between consecutive valies is qaround 150.
				(Measured on AMD FX-8350)
				
				{ ulong prev; iota(10).map!(a => uniqueNow).array.map!((a)
				{ auto res = a.raw-prev; prev = a.raw; return iround(res*1.5625); }).array.drop(1).print; }
				
				[100, 100, 2, 98, 200, 2, 98, 100, 2] <- consecutive delta times in nanoseconds.
			+/
			synchronized
			{
				__gshared DateTime state; 
				auto act = now; 
				//increment it at least by 1
				if(act>state) state = act; else state.raw++; 
				return state; 
			} 
		} 
		
		DateTime	today()
		{ return now.localDayStart; } 
		Time	time ()
		{ return now.localTime; } 
		
		Time QPS()
		{ return now - appStartedDay; } 
		Time QPS_local()
		{ return now - appStarted; } 
		
		private __gshared  Time _TLast; 
		
		long timeToRaw(Time t)
		{ return cast(long)(t.value(second) * DateTime.RawUnit.sec); } 
		Time rawToTime(long raw)
		{ return raw * (second/DateTime.RawUnit.sec); } 
		
		auto T0() { _TLast = QPS; return QPS; } 
		auto DT() { const Q = QPS, res = Q-_TLast; _TLast = Q; return res; } 
		auto DTms() { const t = DT; const s = siFormat("%.1f ms", t); DT; return s; } 
		
		alias ΔT = DT; 
		alias ΔTms = DTms; 
		
		DateTime parseDate(in TimeZone tz, string str)
		{
			int y,m,d; 
			enforce(3==str.formattedRead!"%d.%d.%d"(y, m, d), "Invalid date format. -> [yy]yy.mm.dd"); 
			return DateTime(tz, year2k(y), m, d); 
		} 
		
		Time parseTime(string str)
		{
			int h,m; double s=0; 
			try {
				const len = str.split(':').length; 
						 if(len==3) str.formattedRead!"%s:%s:%s"(h, m, s); 
				else if(len==2) str.formattedRead!"%s:%s"   (h, m   ); 
				else raise(""); 
			}catch(Throwable) { raise(`Invalid time format: "` ~ str ~ `"`); }
			return h*hour + m*minute + s*second; 
		} 
		
		DateTime parseDateTime(in TimeZone tz, string str)
		{
			if(str.canFind(' '))
			{
				auto parts = str.split(' '); //dateTime
						
				if(parts.length==2)
				{ return parseDate(tz, parts[0]) + parseTime(parts[1]); }else if(parts.length==5)
				{
					 //__TIMESTAMP__   Sat Aug 14 09:51:45 2021
					return DateTime(tz, parts[4].to!uint, parts[1].among("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"), parts[2].to!int) + parseTime(parts[3]); 
				}
			}
			else
			{
				//Todo: check for digits here, not any chars!
				if(str.isWild("????-??-??T??????.???"))
				{
					 //windows timestamp.zzz   //!!!!!! todo: What if ends with a Z!!!!! Then it's ITC!!!!!!
					return DateTime(tz, wild.ints(0), wild.ints(1), wild.ints(2), wild[3][0..2].to!int, wild[3][2..4].to!int, wild[3][4..6].to!int, wild.ints(4)); 
				}else if(str.isWild("????-??-??T??????"))
				{
					 //windows timestamp
					return DateTime(tz, wild.ints(0), wild.ints(1), wild.ints(2), wild[3][0..2].to!int, wild[3][2..4].to!int, wild[3][4..6].to!int); 
				}else if(str.isWild("????-??-??T????"))
				{
					 //windows timestamp, no seconds
					return DateTime(tz, wild.ints(0), wild.ints(1), wild.ints(2), wild[3][0..2].to!int, wild[3][2..4].to!int); 
				}else if(str.isWild("????-??-??T"))
				{
					 //windows timestamp, no time
					return DateTime(tz, wild.ints(0), wild.ints(1), wild.ints(2)); 
				}else if(str.isWild("????-??-??"))
				{
					 //windows timestamp, no time, no T
					return DateTime(tz, wild.ints(0), wild.ints(1), wild.ints(2)); 
				}else if(str.isWild("????????-??????-???"))
				{
					 //timestamp 4 digit year
					return DateTime(tz,        str[0..4].to!int,  str[4..6].to!int, str[6..8].to!int, str[9..11].to!int, str[11..13].to!int, str[13..15].to!int, str[16..19].to!int); 
				}else if(str.isWild("??????-??????-???"))
				{
					 //timestamp 2 digit year
					return DateTime(tz, year2k(str[0..2].to!int), str[2..4].to!int, str[4..6].to!int, str[7.. 9].to!int, str[9..11].to!int, str[11..13].to!int, str[14..17].to!int); //Todo: ugly but works
				}else
				{
					return parseDate(tz, str); //Date only
				}
			}
					
			throw new Exception("Invalid datetime format: "~str); 
		} 
		
		
		public import std.range : iota; 
		
		auto iota(in DateTime begin, in DateTime end, in Time step)
		{
			//https://forum.dlang.org/post/ivskeghrhbuhpiytesas@forum.dlang.org -> Ali's solution
					
			static struct Result {
				DateTime current, end; 
				Time step; 
						
				@property bool empty() { return current >= end; } 
				@property auto front() { return current; } 
				void popFront() { assert(!empty); current += step; } 
			} 
					
			return Result(begin, end, step); 
		} 
		
		auto by(in DateTime begin, in Time step)
		{
					
			static struct Result {
				DateTime current; 
				Time step; 
						
				enum empty = false; 
				@property auto front() { return current; } 
				void popFront() { current += step; } 
			} 
					
			return Result(begin, step); 
		} 
		
		auto by(in DateTime begin, in Frequency f)
		{ return begin.by(1/f); } 
		
		bool PERIODIC(string moduleName=__MODULE__, size_t moduleLine=__LINE__)(Time periodLength, size_t hash=0)
		{
			enum staticHash = hashOf(moduleName, moduleLine); 
			hash ^= staticHash; 
			
			static DeltaTimer[size_t] timers; 
			
			auto a = hash in timers; 
			if(!a) {
				timers[hash] = DeltaTimer.init; 
				a = hash in timers; 
			}
			
			return a.update_periodic(periodLength.value(second), false); 
			//Todo: result should be an int counting how many updates missed since last time
		} 
		
		bool blink(float freq=3/*hz*/, float duty=.5f)
		{ return blinkf(freq) < duty; } 
		
		float blinkf(float freq=3)
		{ return (QPS.value(second)*freq).fract; } 
		
		float blinks(float freq=3)
		{ return (sin(blinkf(freq) * ((2)*(π)))+1)/2; } 
		
		
		synchronized class Perf
		{
			//all is shared, this is not good.
			//Todo: revisit this crap
			private {
				double[string] table; 
				double[string] firstAppearance; 
				string actName; 
				double T0; 
			} 
					
			void reset()
			{
				table = null; 
				firstAppearance = null; 
				actName = ""; 
			} 
					
			void addTime(string name, in double time)
			{
				if(name !in table) {
					table[name] = 0; 
					firstAppearance[name] = QPS.value(second); 
				}
				table[name] = table[name]+time; 
			} 
					
			string report()
			{
				if(actName!="") end; 
				auto r = (cast()firstAppearance).keys.sort!((a, b) => firstAppearance[a] < firstAppearance[b]).map!(k => format!"%-30s:%9.3f ms\n"(k, table[k]*1e3)).join; 
				reset; 
				return r; 
			} 
					
			void opCall(string name, void delegate() dg = null)
			{
				auto T = QPS.value(second); 
				if(actName!="") {
					 //flush
					addTime(actName, T-T0); 
					actName = ""; 
				}
				if(name!="") {
					T0 = T; 
					actName = name; 
				}
						
				//call with delegate
				if(dg !is null) {
					dg(); 
					end; 
				}
			} 
					
			void end()
			{
				opCall("")
				; 
			} 
		} 
		
		shared PERF = new shared Perf; 
		
		//Todo: strToDateTime, creators
		
	}version(/+$DIDE_REGION+/all)
	{
		struct DeltaTimer
		{
				double tLast = 0; 
			public: 
				float total = 0; 
				float delta = 0; //the time from the last update
			
				void reset()
			{
				//resets the total elapsed time
				total = 0; 
				tLast = QPS.value(second); 
			} 
			
				float update()
			{
				//returns time since last update
				double tAct = QPS.value(second); 
				if(tLast==0) tLast = tAct; 
				delta = tAct-tLast; 
				total += delta; 
				tLast = tAct; //restart
				return delta; 
			} 
			
				bool update_periodic(float secs, bool enableOverflow)
			{
				//enableOF: false for user-interface, true for physics simulations
				update(); 
				bool res = total>=secs; 
				if(res) {
					total -= secs; 
					if(!enableOverflow) {
						 //Todo: batch overflow when the callbact receives how many times it needs to update
						if(total>=secs) total = 0; 
					}
				}
				return res; 
			} 
		}; 
		
		struct Sequencer(T)
		{
			//Sequencer /////////////////////////////
			T[float] events; 
					
			void opIndexAssign(in T what, float t)
			{ events[t] = what; } 
			T opIndex(float t) const
			{ auto a = t in events; return a ? *a : T.init; } 
					
			void scale(float mult)
			{
				T[float] e; 
				foreach(i; events.byKeyValue) e[i.key*mult] = i.value; 
				events = e; 
			} 
					
			private auto getEvents(float tLast, float tAct)
			{
				return events	.keys
					.filter!(k => tLast<k && k<=tAct)
					.map!(k => events[k]).array;  //Todo: this is slow
			} 
					
			private bool anyEventsAfter(float tMin)
			{
				return events.keys.filter!(k => tMin<k).any; //Todo: this is also slow
			} 
					
			auto run(void delegate() onIdle = null)
			{
				static struct SequencerRunner(T)
				{
					////todo: opApply a range helyett!
					Sequencer!T seq; 
					void delegate() onIdle = null; 
					double t0; 
					float tLast = -1e30; 
							
					private T[] actEvents; 
					private bool eof; 
							
					private void fetch()
					{
						if(eof || actEvents.length) return; 
								
						do {
							auto tAct = QPS-t0; 
							actEvents = seq.getEvents(tLast, tAct); 
							tLast = tAct; 
							
							if(actEvents.empty) {
								 //wait more or break on EOS
								if(!seq.anyEventsAfter(tLast)) {
									eof = true; 
									break; 
								}
										
								if(onIdle !is null) onIdle(); 
								else sleep(1); 
							}
						}while(actEvents.empty); 
					} 
							
							
					bool empty()
					{
						fetch; 
						return eof && actEvents.empty; 
					} 
							
					T front()
					{
						fetch; 
						return actEvents.empty ? T.init : actEvents[0]; 
					} 
							
					void popFront()
					{
						fetch; 
						if(!actEvents.empty)
						actEvents.popFirst; 
					} 
				} 
						
				return SequencerRunner!T(this, onIdle, QPS); 
			} 
		} 
		
		struct UpdateInterval
		{
			//Note: these are old comments:
			//Interval: Keeps an integer or float range. It can clamp values using that range,
			//and can easily extend the range. Also manages the validity of the range (NULL range).
			//There are 2 specializations: some FloatInterval/IntInterval.
			
			float tLast, tAct; 
					
			private int test(float t) { return t>tLast && t<=tAct; } //open-closed interval
					
			int repeater(float tBase, float dtFirst, float dt = 0)
			{
				if(dt==0) dt = dtFirst; 
						
				int res = test(tBase); 
				if(dtFirst>0) {
					tBase += dtFirst; 
					res += test(tBase); 
				}
				if(dt>0) {
					float idt = 1/dt; 
							
					//simple & stupid: foreach(i; max(1, iFloor((tLast-tBase)*idt))..1+iCeil((tAct-tBase)*idt)) res += chk(tBase+i*dt);
					int st = max(1, ifloor((tLast-tBase)*idt)); 	//inclusive  0th is the base
					int en = ifloor((tAct-tBase)*idt)+1; 	//exclusive
							
					//simple loop: foreach(i; st..en) res += test(tBase+i*dt);
							
					if(st<en) {
						res += test(tBase+st*dt); st++; //check at start
						if(st<en) {
							en--; res += test(tBase+en*dt); //check at end
							res += en-st; //remaining inbetween is always 1
						}
					}
							
				}
						
				return res; 
			} 
					
			private static void _testRepeater(/*Drawing dr = null*/)
			{
				float tBase = 3, tDelta = 1, tFirstDelta = 5; 
				uint h; 
				foreach(i; 1..25) {
					float step = i*0.2f; 
					float tLast = 0; 
					while(1) {
						float tAct = tLast+step; 
						if(tLast>40.5) break; 
								
						/*auto r = Bounds2f(tLast, i*0.2, tAct, (i+1)*0.2);  dr.color = clWhite;  dr.drawRect(r);*/
								
						int n = UpdateInterval(tLast, tAct).repeater(tBase, tFirstDelta, tDelta); 
								
						h = xxh32([n], h); 
								
						/*
							if(n){ dr.color = clVGA[n];  dr.fillRect(r); }
													dr.color = clWhite;  dr.fontHeight = 0.1;  dr.textOut(r.x, r.y, n.text);
						*/
								
						tLast = tAct; 
					}
				}
						
				enforce(h==3069201956, "UpdateInterval.testRepeater test fail."); 
						
				/*
					foreach(i; -1..40){
										dr.color = clFuchsia;
										float x = i==-1	? tBase
														: i==0	? tBase+tFirstDelta
								: tBase+tFirstDelta+i*tDelta;
										dr.vline(x, 0, 10);
									}
				*/
						
			} 
		} 
		
		struct LocalDateTime
		{
			/+
				Note: This struct can be used to convert raw UTC DateTime to it's local and decoded form.
				For display purposes.
				
				It contains	all the fields of SYSTEMTIME.
				It has extra	fields to optionaly store DayLightSaving information.
				
				The size of the struct is only 8 bytes. (SYSTEMTIME: 16)
			+/
			//Todo: periodically chack if the current time zona changed or not
			mixin(
				bitfields!(
					uint, "min"	, 6,
					uint, "hour"	, 5,
					uint, "day"	, 5,
					uint, "month"	, 4,
					uint, "yearShifted"	, 10, //0=1601
					int , "dlsHourAdjust"	, 2
				)
			); 
			mixin(
				bitfields!(
					uint, "ms"	, 10,
					uint, "sec"	, 6,
					uint, "dlsHourOfs"	, 10, //valid hours until DLS transition
					uint, "dayOfWeek"	, 3, //0=sun
					bool, "valid"	, 1,
					uint, "_reserved"	, 2
				)
			); 
			static assert(typeof(this).sizeof==8); 
			
			enum _yearBase = cast(int) DateTime.RawUnit._minYear; 
			
			@property int year() const
			{ return yearShifted + _yearBase; } 
			@property void year(int y) 
			{
				yearShifted = (y - _yearBase).clamp(0, 1023); 
				/+Todo: This covers more than DateTime, but here's no error handling+/
			} 
			
			this(in SYSTEMTIME st)
			{
				if(st.wYear)
				{
					year	= st.wYear,
					month	= st.wMonth,
					day	= st.wDay,
					hour	= st.wHour,
					min	= st.wMinute,
					sec	= st.wSecond,
					ms	= st.wMilliseconds,
					dayOfWeek 	= st.wDayOfWeek; 
					valid = true; 
				}
			}  auto systemTime() const
			{
				if(!valid) return SYSTEMTIME.init; 
				return SYSTEMTIME
				(
					cast(ushort) year, 
					cast(ushort) month, 
					cast(ushort) dayOfWeek,
					cast(ushort) day,
					cast(ushort) hour, 
					cast(ushort) min, 
					cast(ushort) sec, 
					cast(ushort) ms
				); 
			} 
			
			bool isNull() const
			{ return !valid; } 	bool opCast(b : bool)() const
			{ return !!valid; } 	
			
			string toString() const
			{
				return isNull ? "NULL LocalDateTime" : format!"%04d.%02d.%02d %02d:%02d:%02d.%03d"
				(year, month, day, hour, min, sec, ms); 
			} 
			
			static ulong dlsTransitionSearch(ulong r0, int h0, ulong r1, int h1)
			{
				//returns: Inputs raw utc day range, and local hours at that day.
				//returns: The raw utc hour position of the DLS transition or zero if there is none.
				//Bug: Not sure if it works good in the USA side of the world. Was tested for Hungary only.
				const hourAdjust = h1-h0; 
				if(hourAdjust /+Don't care about minutes, only hours across 28 days.+/)
				{
					const dayDiff = (r1-r0)/DateTime.RawUnit.day; 
					if(dayDiff>=2)
					{
						const 	rm	= r0+dayDiff/2*DateTime.RawUnit.day,
							hm 	= rm.RawDateTime.localSystemTime.wHour; 
						//recursion
						if(hm!=h0) return dlsTransitionSearch(r0, h0, rm, hm); 
						if(hm!=h1) return dlsTransitionSearch(rm, hm, r1, h1); 
					}
					else
					{
						int localHour(int i)
						{ return (r0 + i*DateTime.RawUnit.hour).RawDateTime.localSystemTime.wHour; } 
						auto differentHours = iota(24).map!(i => localHour(i) != (h0+i)%24).assumeSorted; 
						
						const hourOfs = differentHours.lowerBound(true).length.to!int; 
						
						return r0 + hourOfs*DateTime.RawUnit.hour; 
					}
				}
				
				return 0; 
			} 
			
			static void test()
			{
				print(now.utcText); 
				print(now); 
				print(now.LocalDateTime); 
				
				const 	rawFourWeeks	= DateTime.RawUnit.day*28,
					numFourWeeks 	= ulong.max / rawFourWeeks; 
				ulong cnt; 
				
				auto testRange() { return iota(DateTime.RawUnit.day*10, ulong.max, 1*DateTime.RawUnit.day - 19*DateTime.RawUnit.min); } 
				
				print("testing"); 
				foreach(i; testRange)
				{
					const dt = RawDateTime(i); 
					
					if(dt.text != dt.LocalDateTime.text)
					{
						print("Input/UTC    :", dt.utcText); 
						print("Input/Local  :", dt); 
						with(dt.LocalDateTime) print("Local result :", toString); 
						print; 
					}
					
					cnt++; 
				}
				
				T0; 
				testRange.each!((i){ RawDateTime(i).localSystemTime; } ); 
				DT.print; 
				testRange.each!((i){ RawDateTime(i).LocalDateTime; } ); 
				DT.print; 
				
				print("Total tests:", cnt); 
			} 
			
			private {
				enum rawFourWeeks	= DateTime.RawUnit.day*28,
				numFourWeeks 	= ulong.max / rawFourWeeks; 
				
				//The global cache of 4 week intervals
				__gshared LocalDateTime[
					numFourWeeks 
					+ 1/+last is a fraction of four weeks+/
				] fourWeekCache; 
			} 
			package static void resetLocalDateCache()
			{ fourWeekCache = typeof(fourWeekCache).init; } 
			
			this(DateTime dt)
			{
				if(!dt) return; 
				
				const LocalDateTime accessCache(size_t idx, ulong raw)
				{
					ref actLdt() { return fourWeekCache[idx]; } 
					if(!actLdt)
					{
						assert(raw == idx*rawFourWeeks, "LocalDateTime.fourWeekCache incosistency."); 
						
						static toLocalDateTime(ulong raw)
						{
							return raw	.max(1) //because 0 means null
								.RawDateTime
								.localSystemTime
								.LocalDateTime
								.ifThrown(LocalDateTime.init/+Negative timezones, first index will be null.+/); 
						} 
						
						actLdt = toLocalDateTime(raw); 
						
						//Note: Only 1 hour timezone shifts are supported. -> North Korea has 30min shift.
						if(actLdt.min != 0) actLdt = LocalDateTime.init; 
						
						if(actLdt && idx+1<fourWeekCache.length)
						{
							const	nextIdx	= idx + 1,
								nextRaw 	= raw + rawFourWeeks,
								nextLdt	= ((fourWeekCache[nextIdx])?(fourWeekCache[nextIdx]) :(toLocalDateTime(nextRaw))); 
							//Note: Must avoid recursion here, it would do all the way to the end polluting the stack.
							if(actLdt.hour!=nextLdt.hour/+Detect DayLighSavings transition+/)
							{
								if(
									const rawDLSTransition = dlsTransitionSearch(
										raw	, actLdt.hour, 
										nextRaw	, nextLdt.hour
									)
								)
								{
									with(actLdt)
									{
										dlsHourAdjust = nextLdt.hour - actLdt.hour; 
										dlsHourOfs = ((rawDLSTransition - raw)/(DateTime.RawUnit.hour)); 
									}
								}
							}
						}
						//print("Cached: ", idx.format!"%5d", actLdt, actLdt.dlsHourAdjust, actLdt.dlsHourOfs); 
					}
					
					return actLdt; 
				} 
				
				const 	idx	= dt.raw / rawFourWeeks,
					raw	= idx * rawFourWeeks; 
				LocalDateTime res = accessCache(idx, raw); 
				
				if(!res) {
					/+
						Note: This can happen with negative timezones at cache index 0.
						Revert to the slower windows method.
					+/
					this = dt	.localSystemTime
						.LocalDateTime
						.ifThrown(LocalDateTime.init); 
					return; 
				}
				
				//split up delta to all time components below 'day'
				auto Δ = dt.raw - raw; 
				static foreach(s; ["day", "hour", "min", "sec", "ms"])
				mixin(
					q{
						auto Δ$ = cast(int) (Δ / DateTime.RawUnit.$); 
						Δ -= Δ$ * DateTime.RawUnit.$; 
					}.replace("$", s)
				); 
				//Opt: first I should div by 1 msec and then do the rest on an integer.
				alias Δμs = Δ; 
				//print(Δday, Δhour, Δmin, Δsec, Δms, Δμs); 
				
				int 	year	= res.year,
					month 	= res.month,
					day	= res.day + Δday,
					hour	= res.hour + Δhour; 
				//minutes and below are not handled.
				
				//apply optional DayLightSaving shift.
				if(res.dlsHourAdjust && (Δday*24 + Δhour)>=res.dlsHourOfs)
				hour += res.dlsHourAdjust; 
				
				while(hour<0) { day--; hour -= 24; }
				while(hour>=24) { day++; hour -= 24; }
				adjustDate(year, month, day); 
				
				res.year	= year,
				res.month 	= month,
				res.day	= day,
				res.hour	= hour,
				res.min	= Δmin.to!uint,
				res.sec	= Δsec.to!uint,
				res.ms	= Δms.to!uint; 
				
				this = res; 
			} 
			
			//Todo: Check timeZone change and invalidate cache.
		} 
	}
}version(/+$DIDE_REGION File System+/all)
{
	/// File System //////////////////////////////////////////////
	version(/+$DIDE_REGION Path+/all)
	{
		///  Path //////////////////////////////////////////////
		
		//char pathDelimiter() {
			//static __gshared c = dirSeparator[0]; return c;  <- After all I'm Windows only...
		//return '\\';
		//}
		immutable pathDelimiter = '\\'; 
		
		string includeTrailingPathDelimiter(string fn)
		{ if(!fn.endsWith(pathDelimiter)) fn ~= pathDelimiter; return fn; } 
		string excludeTrailingPathDelimiter(string fn)
		{ if(fn.endsWith(pathDelimiter)) fn = fn[0..$-1]; return fn; } 
		
		bool samePath(string a, string b)
		{
			return sameText(
				a.excludeTrailingPathDelimiter,
				b.excludeTrailingPathDelimiter
			); 
		} 
		
		bool samePath(in Path a, in Path b)
		{ return samePath(a.fullPath, b.fullPath); } 
		
		struct DriveInfo
		{
			this(string drive)
			{
				this.drive = drive; 
				import core.sys.windows.winnt : ULARGE_INTEGER, PULARGE_INTEGER; 
				import core.sys.windows.winbase : GetDiskFreeSpaceExA; 
				ULARGE_INTEGER freeBytes, totalBytes; 
				if(GetDiskFreeSpaceExA(drive.toPChar, &freeBytes, &totalBytes, null))
				{
					valid = true; 
					this.freeBytes = freeBytes.QuadPart; 
					this.totalBytes = totalBytes.QuadPart; 
				}
			} const
			{
				string drive; 
				bool valid; B opCast(B: bool)() => valid; 
				long totalBytes, freeBytes; 
				@property totalGB()
				=> ((totalBytes)/(((2.0f)^^(30)))); 	@property freeGB()
				=> ((freeBytes)/(((2.0f)^^(30)))); 
			} 
		} 
		
		struct Path
		{
			version(/+$DIDE_REGION+/all) {
				private static
				{
					bool dirExists(string dir)
					{
						if(dir.empty) return false; 
						bool res; 
						try { res = isDir(dir); }catch(Throwable) {}
						return res; 
					} 
					
				} 
				
				string fullPath; 
				
				this(string path_)
				{ dir = path_; } 
				this(string path_, string name_)
				{ this(combinePath(path_, name_)); } 
				this(Path path_, string name_)
				{ this(combinePath(path_.fullPath, name_)); } 
				this(Path path_)
				{ this(path_.fullPath); } 
				
				string toString() const
				{
					/+
						Todo: this is bad naming. It's sourceText, not text.  
						Text() or toString() should be fullPath.
						Same for File.
					+/
					return "Path("~fullPath.quoted('`')~")"; 
				} 
				bool isNull() const
				{ return fullPath==""; } 
				bool opCast() const
				{ return !isNull(); } 
				
				bool exists() const
				{ return fullPath.length && dirExists(dir); } 
				
				string name() const
				{
					auto 	a 	= fullPath.withoutEnding(pathDelimiter),
						i	= a.retro.countUntil(pathDelimiter); 
					return i<0 ? a : a[$-i..$]; 
				} 
				
				@property string dir() const
				{ return excludeTrailingPathDelimiter(fullPath); } 
				@property void dir(string dir_)
				{ fullPath = dir_=="" ? "" : includeTrailingPathDelimiter(dir_); } 
				
				auto times()const
				{ return File.fileTimes(dir); } 
				auto modified()const
				{ return times.modified; } 
				auto accessed()const
				{ return times.accessed; } 
				auto created()const
				{ return times.created; } 
							
				auto isAbsolute()const
				{ return isAbsolutePath(fullPath); } 
							
				Path normalized()const
				{ return Path(buildNormalizedPath(absolutePath(fullPath))); } 
				Path normalized(string base)const
				{ return Path(buildNormalizedPath(absolutePath(fullPath, base))); } 
				Path normalized(in Path base)const
				{ return normalized(base.fullPath); } 
			}version(/+$DIDE_REGION+/all) {
				string drive()const
				{
					foreach(i, ch; fullPath) {
						if(ch.isAlphaNum) continue; 
						if(ch==':') return fullPath[0..i + 1/+including ':'+/]; 
						return ""; 
					}
					return ""; 
				} 
				
				size_t driveIs(in string[] drives...)const
				{
					string e0 = drive.lc.withoutEnding(':'); 
					foreach(i, s; drives) if(s.lc.withoutEnding(':')==e0) return i+1; 
					return 0; 
				} 
				
				
				
				@property hasDrive()const
				=> drive!=""; @property driveInfo()const 
				=> DriveInfo(drive); 
				
				Path parent() const
				{ string s = dir; while(s!="" && s.back!='\\') s.length--; return Path(s); } 
				
				bool make(bool mustSucceed=true)const
				{
					if(exists) return true; 
					ignoreExceptions({ mkdirRecurse(dir); } ); 
					
					const res = exists; 
					if(mustSucceed && !res) raise(format!`Unable to make directory : %s`(dir.quoted)); 
					return res; 
				} 
				
				bool remove(alias rmdirfunc=rmdir)(bool mustSucceed=true)const
				{
					if(!exists) return true; 
					try
					{ rmdirfunc(dir); }
					catch(Throwable)
					{
						enforce(!mustSucceed, format(`Can't remove directory : "%s"`, dir)); //Todo: common file errors
					}
					return !exists; 
				} 
				
				bool wipe(bool mustSucceed=true)const
				{
					if(dir.length==2 && dir.endsWith("\\"))
					throw new Exception(`Unable to wipeing a whole drive "`~dir~`"`); 
					
					return remove!rmdirRecurse(mustSucceed); 
				} 
				
				private static void preparePattern(ref string pattern)
				{
					//convert multiple filters to globMatch's format
					if(pattern.canFind(';'))
					pattern = pattern.replace(";", ","); 
					
					if(pattern.canFind(',') && !pattern.startsWith('{'))
					pattern = '{'~pattern~'}'; 
				} 
				
				File[] files(string pattern="*", bool recursive=false) const
				{
					preparePattern(pattern); 
					return dirEntries(fullPath, pattern, recursive ? SpanMode.depth : SpanMode.shallow)
						.filter!isFile
						.map!(e => File(e.name)).array; 
				} 
				
				Path[] paths(string pattern="*", bool recursive=false) const
				{
					preparePattern(pattern); 
					return dirEntries(fullPath, pattern, recursive ? SpanMode.depth : SpanMode.shallow)
						.filter!(e => !e.isFile)
						.map!(e => Path(e.name)).array; 
				} 
				
				Path opBinary(string op:"~")(string p2)
				{ return Path(this, p2); } 
				
				/+Note: Equality and hashing of filenames must be CASE SENSITIVE and WITHOUT NORMALIZATION.  See -> File.opEquals+/
				int opCmp(in Path b)const
				{ return cmp(fullPath, b.fullPath); } 
				bool opEquals(in Path b)const
				{ return fullPath==b.fullPath; } 
				size_t toHash()const
				{ return fullPath.hashOf; } 
			}
		} 
		
		Path tempPath() {
			static __gshared string s; 
			if(!s) {
				wchar[512] buf; 
				GetTempPathW(buf.length, buf.ptr); 
				s = includeTrailingPathDelimiter(buf.toStr); 
			}
			return Path(s); 
		} 
		
		Path programFilesPath32() { __gshared Path s; if(!s) { s = Path(includeTrailingPathDelimiter(environment.get("ProgramFiles(x86)", `c:\Program Files(x86)\`))); }return s; } 
		Path programFilesPath64() { __gshared Path s; if(!s) { s = Path(includeTrailingPathDelimiter(environment.get("ProgramFiles"     , `c:\Program Files\`     ))); }return s; } 
		
		Path programFilesPath() {
			version(Win32) return programFilesPath32; 
			version(Win64) return programFilesPath64; 
		} 
		
		Path knownPath(int CSIDL)()
		{
			__gshared Path p; 
			if(!p) {
				wchar[MAX_PATH ] szPath; 
				if(S_OK==SHGetFolderPath(null, CSIDL_APPDATA, null, 0, szPath.ptr))
				p = Path(szPath.toStr); 
			}
			return p; 
		} 
		
		alias appDataPath = knownPath!CSIDL_APPDATA; 
		
	}struct File
	{
		private static
		{
			/////////////////////////////////////////////////////////////////
			bool fileExists(string fn)
			{
				if(fn.empty) return false; 
				if(fn.isVirtualFileName) return virtualFileQuery(VirtualFileCommand.getInfo, fn).exists; 
				try {
					auto f = StdFile(fn, "rb"); 
					return true; 
				}catch(Throwable) { return false; }
			} 
			
			ulong fileSize(string fn)
			{
				if(fn.isVirtualFileName) return virtualFileQuery(VirtualFileCommand.getInfo, fn).size; 
				try {
					auto f = StdFile(fn, "rb"); 
					return f.size; 
				}catch(Throwable) { return 0; }
			} 
			
			bool fileReadOnly(string fn)
			{
				if(fn.isVirtualFileName) return false; //Todo: virtual files / readOnly
				auto a = GetFileAttributesW(toPWChar(fn)); 
				if(a==INVALID_FILE_ATTRIBUTES) return false; 
				return a & FILE_ATTRIBUTE_READONLY; 
			} 
			
			struct FileTimes
			{
				DateTime created, modified, accessed; 
				DateTime latest() const { return max(created, modified, accessed); } 
			} 
			
			FileTimes fileTimes(string fn)
			{
				FileTimes res; 
				if(fn=="") return res; 
				
				if(fn.isVirtualFileName)
				return virtualFileQuery(VirtualFileCommand.getInfo, fn).fileTimes; 
				
				StdFile f; 
				try { f = StdFile(fn, "rb"); }catch(Exception e) { return res; }
					
				FILETIME cre, acc, wri; 
				if(GetFileTime(f.windowsHandle, &cre, &acc, &wri))
				{
					res.created	= DateTime(UTC, cre); 
					res.accessed	= DateTime(UTC, acc); 
					res.modified	= DateTime(UTC, wri); 
				}
				
				return res; 
			} 
			
			void setFileTimes_modified(string fn, DateTime modified)
			{
				if(fn=="") return; 
				
				if(fn.isVirtualFileName)
				throw new Exception("Can't set time of virtual files"); 
				
				StdFile f; 
				try
				{ f = StdFile(fn, "a+b"); }
				catch(Exception e)
				{ throw new Exception("Can't open file "~fn.quoted); }
				
				FILETIME wri = modified.utcFileTime; 
				if(!SetFileTime(f.windowsHandle, null, null, &wri))
				throw new Exception("Error setting filetime "~fn.quoted); 
			} 
			
			string extractFilePath(string fn)
			{
				auto s = dirName(fn); 
				if(s==".") return ""; 
				else return includeTrailingPathDelimiter(s); 
			} 
			string extractFileDir(string fn)
			{ return excludeTrailingPathDelimiter(extractFilePath(fn)); } 
			string extractFileName(string fn)
			{ return baseName(fn); } 
			string extractFileExt(string fn)
			{ return extension(fn); } 
			string changeFileExt(const string fn, const string ext)
			{ return setExtension(fn, ext); } 
		}    version(/+$DIDE_REGION+/all) {
			this(string fullName_)
			{ fullName = fullName_; } 
			this(string path_, string name_)
			{ this(combinePath(path_, name_)); } 
			this(Path path_, string name_)
			{ this(combinePath(path_.fullPath, name_)); } 
			this(Path path_, File file_)
			{ this(combinePath(path_.fullPath, file_.fullName)); } 
			this(File file)
			{ this(file.fullName); } 
			
			string fullName; 
			
			string toString()const
			{ return "File("~fullName.quoted('`')~")"; } 
			bool isNull()const
			{ return fullName==""; } 
			bool opCast()const
			{ return !isNull(); } 
			
			auto exists()const
			{ return fileExists(fullName); } 
			auto size()const
			{ return fileSize(fullName); } 
			auto isAbsolute()const
			{ return isAbsolutePath(fullName); } 
			
			File normalized()const
			{ return File(buildNormalizedPath(absolutePath(fullName))); } 
			File normalized(string base)const
			{ return File(buildNormalizedPath(absolutePath(fullName, base))); } 
			File normalized(in Path base)const
			{ return normalized(base.fullPath); } 
			
			bool isReadOnly() const
			{ return fileReadOnly(fullName); } 
			
			auto times()const
			{ return fileTimes(fullName); } 
			@property auto modified()const
			{ return times.modified; } 
			auto accessed()const
			{ return times.accessed; } 
			auto created()const
			{ return times.created; } 
			
			@property void modified(in DateTime m)
			{ setFileTimes_modified(fullName, m); } 
			
			@property bool isPath()const
			{ return asPath.exists; } 
			
			@property Path asPath()const
			{ return Path(fullName); } 
			
			@property string dir()const
			{ return extractFileDir(fullName); } 
			@property void dir(string newDir)
			{ fullName = combinePath(newDir, extractFileName(fullName)); } 
			
			@property string fullPath()const
			{ return extractFilePath(fullName); } 
			@property Path path()const
			{ return Path(extractFilePath(fullName)); } 
			@property void path(Path newPath)
			{ fullName = combinePath(newPath.fullPath,	extractFileName(fullName)); } 
			@property void path(string newPath)
			{ fullName = combinePath(newPath	, extractFileName(fullName)); } 
			
			string drive() const
			{ return Path(fullName).drive; } 
			size_t driveIs(in string[] drives...) const
			{ return Path(fullName).driveIs(drives); } 
			@property bool hasDrive()const
			{ return drive!=""; } 
			
			@property driveInfo()const 
			=> DriveInfo(drive); 
			
			@property string name()const
			{ return extractFileName(fullName); } 
			@property void name(string newName)
			{ fullName = combinePath(extractFilePath(fullName), newName); } 
			
			@property string nameWithoutExt()const
			{ return extractFileName(otherExt("").fullName); } 
			
			@property string ext()const
			{ return extractFileExt(fullName); } 
			@property void ext(string newExt)
			{ fullName = changeFileExt(fullName, newExt); } 
			
			File otherExt(const string ext_) const
			{ File a = this; a.ext = ext_; return a;  } 
			
			size_t extIs(in string[] exts...)const
			{
				//Todo: ez full ganyolas...
				string e0 = lc(ext); 
				foreach(i, s; exts) {
					string e = s; 
					if(e!="" && e[0]!='.') e = '.'~e; 
					if(lc(e)==e0) return i+1; 
				}
				return 0; 
			} 
		}version(/+$DIDE_REGION+/all) {
			bool remove(bool mustSucceed = true) const
			{
				if(exists) {
					try
					{
						if(this.isVirtual) virtualFileQuery(VirtualFileCommand.remove, fullName); 
						else std.file.remove(fullName); 
					}
					catch(Exception)
					{ enforce(!mustSucceed, format(`Can't delete file: "%s"`, fullName)); }
				}
				return !exists; 
			} 
			
			/// Useful to remove files that are generated from std output. Those aren't closed immediatelly.
			void forcedRemove() const
			{
				foreach(k; 0..500)
				{
					if(exists) { try { remove; }catch(Exception e) { sleep(1); }}
					if(!exists) return; 
				}
				ERR("Failed to forcedRemove file ", this); 
			} 
			
			ubyte[] forcedRead() const
			{
				foreach(k; 0..500)
				{
					try {
						auto res = read(true); 
						return res; 
					}catch(Exception e) { sleep(1); }
				}
				ERR("Failed to forcedRead file ", this); 
				assert(0); 
			} 
			
			ubyte[] read(
				bool mustExists = true, ulong offset = 0, size_t len = size_t.max,
				string srcFile=__FILE__, int srcLine=__LINE__
			)const
			{
				//Todo: void[] kellene ide talan, nem ubyte[] es akkor stringre is menne?
				ubyte[] data; 
				
				if(!exists) {
					if(mustExists) raise(format!`Can't read file: "%s"`(fullName), srcFile, srcLine); 
					return data; 
				}
				
				if(!mustExists && !exists) return data; 
				try
				{
					if(this.isVirtual)
					{ data = virtualFileQuery_raise(VirtualFileCommand.read, fullName, data, offset, len).dataOut; }
					else
					{
						auto f = StdFile(fullName, "rb"); 
						scope(exit) f.close; 
						
						if(offset) f.seek(offset); 
						ulong siz = f.size; 
						ulong avail = offset<siz ? siz-offset : 0; 
						ulong actualSiz = min(len, avail); 
						
						if(actualSiz>0) {
							data.length = cast(size_t)actualSiz; 
							data = f.rawRead(data); 
						}
					}
				}
				catch(Exception)
				{
					enforce(!mustExists, format!`Can't read file: "%s"`(fullName), srcFile, srcLine); 
					//Todo: egysegesiteni a file hibauzeneteket
				}
				
				if(logFileOps) LOG(fullName); 
				return data; 
			} 
			
			string readStr(
				bool mustExists = true,
				ulong offset = 0, size_t len = size_t.max
			) const
			{
				auto s = cast(string)(read(mustExists, offset, len)); 
				return s; 
			} 
			
			string readText(
				bool mustExists = true, TextEncoding defaultEncoding = TextEncoding.UTF8,
				ulong offset = 0, size_t len = size_t.max
			) const
			{ return readStr(mustExists, offset, len).textToUTF8(defaultEncoding)/+own converter. Handles BOM+/; } 
			
			string[] readLines(
				bool mustExists = true, TextEncoding defaultEncoding = TextEncoding.UTF8,
				ulong offset = 0, size_t len = size_t.max
			) const
			{ return readText(mustExists, defaultEncoding, offset, len).splitLines; } 
			
			//utf32 versions
			dstring readText32(
				bool mustExists = true, TextEncoding defaultEncoding = TextEncoding.UTF8,
				ulong offset = 0, size_t len = size_t.max
			) const
			{
				auto s = readStr(mustExists, offset, len); 
				return textToUTF32(s, defaultEncoding); //own converter. Handles BOM
			} 
			
			dstring[] readLines32(
				bool mustExists = true, TextEncoding defaultEncoding = TextEncoding.UTF8,
				ulong offset = 0, size_t len = size_t.max
			) const
			{ return readText32(mustExists, defaultEncoding, offset, len).splitLines; } 
		}version(/+$DIDE_REGION+/all) {
			private void write_internal(const void[] data, bool rewriteAll, ulong offset, Flag!"preserveTimes" preserveTimes)const
			{
				//Bug: Ha nincs path a file elott, akkor nem a .-ba irja, hanem lefagy.
				try
				{
					if(this.isVirtual)
					{
						enforce(!preserveTimes, "preserveTimes not supported with virtual files."); 
						auto v = virtualFileQuery_raise(
							rewriteAll ? VirtualFileCommand.writeAndTruncate : VirtualFileCommand.write,
							fullName, cast(ubyte[])data, rewriteAll ? 0 : offset
						); 
					}
					else
					{
						path.make; 
						
						auto f = StdFile(fullName, rewriteAll ? "wb" : "r+b"); 
						scope(exit) f.close; 
						
						FILETIME cre, acc, wri; 
						bool getTimeSuccess; 
						if(preserveTimes) getTimeSuccess = GetFileTime(f.windowsHandle, &cre, &acc, &wri)!=0; 
						
						if(!rewriteAll) f.seek(offset); 
						f.rawWrite(data); 
						if(logFileOps) LOG(fullName); 
						
						if(preserveTimes && getTimeSuccess)
						enforce(SetFileTime(f.windowsHandle, &cre, &acc, &wri)!=0, "Error writing file times."); 
					}
				}
				catch(Exception)
				{ enforce(false, format(`Can't write file: "%s"`, fullName)); }
			} 
			
			void write(const void[] data, Flag!"preserveTimes" preserveTimes=No.preserveTimes)const
			{ write_internal(data, true, 0, preserveTimes); } 
			
			void write(const void[] data, ulong offset, Flag!"preserveTimes" preserveTimes=No.preserveTimes)const
			{ write_internal(data, false, offset, preserveTimes); } 
			
			bool sameContents(const void[] data)
			{ return size==data.length && equal(cast(const ubyte[])data, read(false)); } 
			
			bool writeIfNeeded(const void[] data)
			{
				const needToWrite = !sameContents(data); 
				if(needToWrite) write(data); 
				//if(!needToWrite) print("SKIPPING WRITING IDENTICAL FILE");
				return needToWrite; 
			} 
			
			void writeText(string s)
			{
				immutable bom = "\uFEFF"; 
				write(s.startsWith(bom) ? s : bom~s); 
			} 
			
			void append(const void[] data)const
			{
				if(!exists) write(data); 
				else write(data, size); 
				//Todo: compression, automatic uncompression
				
				//Opt: this is lame and slow.
			} 
			
			void truncate(size_t desiredSize)
			{
				if(size>desiredSize)
				write(read(true, 0, desiredSize)); 
				//Opt: it's very ineffective
			} 
			
			
			/+
				Note: Equality and hashing of filenames must be CASE SENSITYIVE and WITHOUT NORMALIZATION.
				`font:\Arial\a` MUST NOT EQUAL TO `font:\Arial\A`
				Also avoid normalization because it is depends on the contents of the HDD.
			+/
			
			int opCmp(in File b) const
			{ return cmp(fullName, b.fullName); } 
			bool opEquals(in File b) const
			{ return fullName==b.fullName; } 
			size_t toHash() const
			{ return fullName.hashOf; } 
			
			@property bool hasQueryString() const
			{ return fullName.canFind('?'); } 
			
			File withoutQueryString() const
			{
				auto i = fullName.indexOf('?'); 
				return File(i>=0 ? fullName[0..i] : fullName); 
			} 
			
			@property QueryString queryString() const
			{
				//Todo: test querystrings with bitmap/font renderer
				auto i = fullName.indexOf('?'); 
				return QueryString(i>=0 ? fullName[i+1..$] : ""); 
			} 
			
			@property auto queryStringMulti() const
			{ return fullName.splitter('?').drop(1).map!QueryString; } 
			
			@property void queryString(string s)
			{
				s = s.strip.withoutStarting('?'); 
				auto fn = withoutQueryString.fullName; 
				if(s!="") fn ~= '?' ~ s; 
				fullName = fn; 
			} 
			
			@property void queryString(in QueryString qs)
			{ queryString = qs.text; } 
			
			
			File opBinary(string op)(string s) const if(op == "~")
			{ return File(fullName~s); } 
		}
	} version(/+$DIDE_REGION+/all) {
		
		private bool isAbsolutePath(string fn)
		{ return std.path.isAbsolute(fn); } 
		
		private string combinePath(string a, string b)
		{
			if(!a) return b; 
			if(!b) return a; 
			
			//Note: in buildPath() "c:\a" + "\xyz" equals "c:\syz". This is bad.
			b = b.withoutStarting(`\`); 
			
			return std.path.buildPath(a, b); 
		} 
		
		bool FileTimeToLocalSystemTime(in FILETIME* ft, SYSTEMTIME* st)
		{
			FILETIME ftl; 
			return FileTimeToLocalFileTime(ft, &ftl) && FileTimeToSystemTime(&ftl, st); 
		} 
		
		File actualFile(in File f)
		{
			if(!f) return File.init; 
			char[MAX_PATH] buf; 
			auto len = GetShortPathNameA(f.normalized.fullName.toPChar, buf.ptr, MAX_PATH); 
			if(len && len<MAX_PATH) {
				auto fs = File(buf[0..len].idup); 
				len = GetLongPathNameA(fs.fullName.toPChar, buf.ptr, MAX_PATH); 
				if(len && len<MAX_PATH) {
					import std.ascii : toLower; 
					buf[0] = toLower(buf[0]); 
					return File(buf[0..len].idup); 
				}
			}
			return f; 
		} 
		
		Path actualPath(in Path p)
		=> ((p)?(p.dir.File.actualFile.fullName.Path):(p)); 
		
		//helpers for saving and loading
		
		string otherExt(string fn, string ext)
		{ return fn.File.otherExt(ext).fullName; } 
		void saveTo(T)(const T[] data, const File file)if(is(T == char))
		{ file.write(cast(string)data); } 
		void saveTo(T)(const T[] data, const File file)if(!is(T == char))
		{ file.write(data); } 
		void saveTo(T)(const T data, const File file)if(!isDynamicArray!T)
		{ file .write([data]); } 
		
		void saveTo(string data, const File file, Flag!"onlyIfChanged" FOnlyIfChanged = No.onlyIfChanged)
		{
			//Todo: combine all saveTo functions into one funct.
			if(FOnlyIfChanged == Yes.onlyIfChanged)
			{ if(file.size == data.length && file.readStr == data) return; }
			file.write(data); 
		} 
		
		void saveTo(T)(const T[] data, const string fileName)
		{ data.saveTo(File(fileName)); } 
		void saveTo(T)(const T data, const string fileName)if(!isDynamicArray!T)
		{ [data].saveTo(File(fileName)); } 
		
		void loadFrom(T)(ref T[]data, const File fileName, bool mustExists=true)if(is(T == char))
		{ data = fileName.readStr(mustExists); } 
		void loadFrom(T)(ref T[]data, const File fileName, bool mustExists=true)if(!is(T == char))
		{ data = cast(T[])fileName.read(mustExists); } 
		void loadFrom(T)(ref T data, const File fileName, bool mustExists=true)if(!isDynamicArray!T)
		{ data = (cast(T[])fileName.read(mustExists))[0]; } 
		
		File appFile()
		{ static __gshared File s; if(s.isNull) s = File(thisExePath); return s; } 
		Path appPath()
		{ static __gshared Path s; if(s.isNull) s = appFile.path; return s; } 
		Path currentPath()
		{ return Path(std.file.getcwd); } 
		
		alias workPath = currentPath; 
		
		
		auto loadCachedTextFile(alias fun)(File file)
		if(__traits(isStaticFunction, fun))
		{
			//loadCachedFile /////////////////////////////////////////////////////
			alias T = ReturnType!fun; 
					
			static struct Rec
			{
				File file; 
				DateTime modified; 
				T payload; 
				/+
					Todo: tesztelni, hogy a Shader-eket felszabaditja-e es mikor.
									Elvileg onalloan jol fog mukodni. 
				+/
				string error; 
			} 
					
			static Rec[File] loaded; 
					
			auto p = file in loaded,
					 actModified = file.modified; 
					
			//found but too old.
			if(p !is null && file.modified != p.modified) {
				loaded.remove(file); 
				p = null; 
			}//p is valid
					
			if(p is null)
			{
				//1. load
				string text; 
				try
				{ text = file.readText; }
				catch(Exception)
				{ throw new Exception("Unable to load cached file: "~file.fullName); }
				//it will try again later
						
				//2. create
				T obj;  string error; 
				try
				{ obj = fun(text); }
				catch(Exception t)
				{ error = t.simpleMsg; }
						
				loaded[file] = Rec(file, actModified, obj, error); 
				//Todo: fileRead and getDate should be system-wide-atomic
				p = &loaded[file]; 
			}
			//p is valid
					
			//return the latest object if can
			assert(p !is null); 
			if(p.payload !is null)
			return p.payload; 
			else
			throw new Exception(p.error); 
		} 
		
		class FileNameFixer
		{
			private File[string] nameMap; 
			Path defaultPath; 
			File fix(File f)
			{
				return nameMap.require(
					f.fullName, (
						defaultPath && !f.hasDrive 
						? File(defaultPath, f) : f
					).actualFile
				); 
			}  
			File opCall(File f)
			{ return fix(f); } File opCall(string s)
			{ return fix(s.File); } 
		} 
	}version(/+$DIDE_REGION Compress+/all)
	{
		//Base64 //////////////////////////////////
		
		string toBase64(in void[] src)
		{
			import std.base64; 
			return Base64.encode(cast(ubyte[])src); 
		} 
		
		ubyte[] fromBase64(string src)
		{
			import std.base64; 
			return Base64.decoder(cast(ubyte[])src).array; 
		} 
		
		/// Helps to track a value whick can be updated. Remembers the
		/// last falue too. Has boolean and autoinc notification options.
		struct ChangingValue(T)
		{
			//ChangingValue /////////////////////////////////
			T actValue, lastValue; 
			uint changedCount; 
			bool changed; 
					
			@property T value() const 
			{ return actValue; } 
			@property void value(in T newValue)
			{
				lastValue = actValue; 
				actValue = newValue; 
				changed = actValue != lastValue; 
				if(changed)
				changedCount++; 
			} 
					
			alias value this; 
		} 
		
		
		//Time series compression /////////////////////////////////////////
		
		//https://www.timescale.com/blog/time-series-compression-algorithms-explained/
		
		struct DeltaCompressor(T)
		{
			T threshold = T(0); 
			enum initial = T.init; 
			T last = initial; 
			
			void reset() { this = typeof(this).init; } 
			
			T compress(T act)
			{
				T res; 
				if(threshold==0)
				{
					res = act-last; 
					last = act; 
				}
				else
				{
					if(abs(act-last)>threshold)
					{
						res = act>last ? act-last-threshold : act-last+threshold; 
						last = act; 
					}
					else
					{ res = 0; }
				}
				return res; 
			} 
					
			T uncompress(T input)
			{
				if(threshold==0)
				{ last += input; }
				else
				{
					if(input>0)
					{ last += input + threshold; }
					else if(input<0)
					{ last += input - threshold; }
				}
				return last; 
			} 
		} 
		
		struct CompressorChain(C1, C2)
		{
			C1 c1; 	 //first compression
			C2 c2; 	 //second compression
			
			void reset()
			{ this = typeof(this).init; } 
			
			alias CT = ReturnType!(C2.compress); 
			alias UT = ReturnType!(C1.uncompress); 
			
			auto compress	(UT act)
			{ return c2.compress(c1.compress(act)); } 
			auto uncompress	(CT act)
			{ return c1.uncompress(c2.uncompress(act)); } 
		} 
		
		alias DeltaDeltaCompressor(T) = CompressorChain!(DeltaCompressor!T, DeltaCompressor!T); 
		
		//zip files ////////////////////////////////
			
		/// extrazt a zip stream appended to the end.
		ubyte[] trailingZip(ubyte[] buf)
		{
			ubyte[] res; 
					
			//find central directory signature from the back
			struct PKCentralDirectoryRecord
			{
				align(1): 
				uint signature; 
				ushort diskNumber, diskCD, diskEntries, totalEntries; 
				uint cdSize, cdOfs; 
				ushort commentLen; 
			} 
					
			if(buf.length < PKCentralDirectoryRecord.sizeof) return res; 
					
			auto cdr = cast(PKCentralDirectoryRecord*)&buf[$-PKCentralDirectoryRecord.sizeof]; 
			auto zipSize = cdr.cdOfs+cdr.cdSize+PKCentralDirectoryRecord.sizeof; 
			auto cdrGood = cdr.signature == 0x06054b50 
				&& cdr.diskNumber==0 
				&& cdr.diskCD==0	//signature  &&  one dist only
				&& cdr.diskEntries==cdr.totalEntries 	
				&& cdr.commentLen==0	//entries are ok	&&  no comment
				&& buf.length >= zipSize	/+buf size is	sufficient+/; 
			
			if(!cdrGood) return res; 
					
			buf = buf[buf.length-zipSize..$]; 
			if(buf[0]==0x50 && buf[1]==0x4b) res = buf; //must be something with PK
					
			return res; 
		} 
		
		void unzip(ubyte[] zipData, void delegate(string, lazy ubyte[]) fun)
		{
			import std.zip; 
			auto zip = scoped!ZipArchive(zipData); 
			foreach(member; zip.directory)
			fun(member.name, cast(ubyte[])zip.expand(member)); 
		} 
		
		void unzip(ubyte[] zipData, string filter, string prefix)
		{
			zipData.unzip(
				(string name, lazy ubyte[] data)
				{
					if(name.isWild(filter))
					{
						auto outFile = File(prefix~name); 
						outFile.write(data); 
					}
				} 
			); 
		} 
		
		void unzip(ubyte[] zipData, string prefix)
		{ zipData.unzip("*", prefix); } 
		
		//Todo: make a simple zipper function
		/+
			ZipArchive zip = new ZipArchive; 
			
			ArchiveMember file1 = new ArchiveMember; 
			file1.name = "output.txt"; 
			file1.expandedData = cast(ubyte[]) allOutput; 
			file1.compressionMethod = CompressionMethod.deflate; 
			
			zip.addMember(file1); 
			
			File(`z:\temp\$output.zip`).write(zip.build); 
		+/
	}version(/+$DIDE_REGION Virtual files+/all)
	{
		///  Virtual files //////////////////////////////////////////////
		
		__gshared size_t VirtualFileCacheMaxSizeBytes = 64<<20; 
		
		bool isVirtualFileName(string fileName)
		{ return fileName.startsWith(`virtual:\`); } 
		bool isVirtual(in File file)
		{ return file.fullName.isVirtualFileName; } 
		
		enum VirtualFileCommand { getInfo, remove, read, write, writeAndTruncate, stats, garbageCollect} 
		
		private auto virtualFileQuery_raise(in VirtualFileCommand cmd, string fileName, const void[] dataIn=null, size_t offset=0, size_t size=size_t.max)
		{
			auto res = virtualFileQuery(cmd, fileName, dataIn, offset, size); 
			if(!res) raise(res.error); 
			return res; 
		} 
		
		struct VirtualFileCacheStats {
			size_t count; 
			size_t allSizeBytes, residentSizeBytes; 
		} 
		
		private VirtualFileCacheStats _virtualFileCacheStats; //used as a result
		
		private auto virtualFileQuery(in VirtualFileCommand cmd, string fileName, const void[] dataIn=null, size_t offset=0, size_t size=size_t.max)
		{
			 synchronized
			{
				struct Res {
					string error; 
					bool success() { return error==""; } 
					alias success this; 
							
					//query results
					bool exists; 
					ulong size; 
					File.FileTimes fileTimes; 
					ubyte[] dataOut; 
					bool resident; 
				} 
						
				struct Rec {
					string fileName; 
					File.FileTimes fileTimes; 
					ubyte[] data; 
					bool resident; //garbageCollect will not free this file
												 //Todo: make a way to set 'resident' bit
				} 
						
				__gshared static Rec[string] files; 
						
				enum log = 0; 
				Res res; 
				final switch(cmd)
				{
					case VirtualFileCommand.getInfo: 	{
						auto p = fileName in files; 
						res.exists = p !is null; 
						if(res.exists) {
							res.size = p.data.length; 
							res.fileTimes = p.fileTimes; 
							res.resident = p.resident; 
						}
					}break; 
						
					case VirtualFileCommand.stats: 	{
						_virtualFileCacheStats.count = files.length; 
						_virtualFileCacheStats.allSizeBytes	= files.byValue                         .map!(f => f.data.length).sum; 
						_virtualFileCacheStats.residentSizeBytes	= files.byValue.filter!(f => f.resident).map!(f => f.data.length).sum; 
					}break; 
						
					case VirtualFileCommand.remove: 	{
						auto p = fileName in files; 
						res.exists = p !is null; 
						if(res.exists) files.remove(fileName); 
						else res.error = "Can't remove Virtual File: "~fileName.quoted; 
					}break; 
						
					case VirtualFileCommand.read: 	{
						auto p = fileName in files; 
						if(p is null) { res.error = "Virtual File not found: "~fileName.quoted; return res; }
						
						if(offset<p.data.length) {
							const actSize = min(size, p.data.length-offset); 
							if(actSize>0)
							res.dataOut = p.data[offset..offset+actSize]; 
						}
						p.fileTimes.accessed = now; 
						
						if(log) LOG("Accessed", fileName.quoted); 
					}break; 
						
					case VirtualFileCommand.write, 
					VirtualFileCommand.writeAndTruncate: 	{
						if(!fileName.isVirtualFileName) { res.error = "Invalid virtual fileName: "~fileName.quoted; return res; }
						
						auto p = fileName in files; 
						if(p is null) {
							auto dt = now; 
							files[fileName] = Rec(fileName, File.FileTimes(dt, dt, DateTime.init), []); 
							if(log) LOG("Created", fileName.quoted); 
							p = fileName in files; 
							assert(p); 
							(*p).fileTimes.created = now; 
						}
						
						auto end = offset + dataIn.length; 
						if(end<offset) { res.error = "Offset overflow: "~fileName.quoted; return res; }
						
						p.data.length = max(p.data.length, end); //enlarge
						p.data[offset..end] = cast(const ubyte[])dataIn[]; //copy
						
						if(cmd == VirtualFileCommand.writeAndTruncate)
						p.data.length = end; //truncate
						
						p.fileTimes.modified = now; 
						if(log) LOG("Updated", fileName.quoted); 
						
					}	break; 
						
					case VirtualFileCommand.garbageCollect: 	{
						//auto T0 = QPS;
						const sizeBytes = files.byValue.filter!(f => !f.resident).map!(f => f.data.length).sum; //sum of non-resident size
						
						if(sizeBytes > VirtualFileCacheMaxSizeBytes)
						{
							 //LOG("Bitmap cache GC");
							const t = now; 
							
							//ascending by access time
							auto list = files.values.sort!((a, b) => a.fileTimes.latest < b.fileTimes.latest); 
							
							const targetSize = VirtualFileCacheMaxSizeBytes; 
							size_t remaining = sizeBytes; 
							string[] toRemove; 
							foreach(f; list) {
								toRemove ~= f.fileName; 
								remaining -= f.data.length; 
								if(remaining<=targetSize) break; 
							}
							
							toRemove.each!(f => files.remove(f)); 
							
							//LOG(QPS-T0);
						}
					}break; 
				}
				
				return res; //no error
			} 
		} 
		
		void unittest_virtualFileReadWrite()
		{
			auto f = File(`virtual:\test_virtualFileReadWrite.dat`); 
			f.write("012345678"); 	assert(cast(string)f.read(true)=="012345678"); 
			f.write("CDEF", 12); 	assert(cast(string)f.read(true, 12, 4)=="CDEF"); 
			f.write("89AB", 8); 	assert(cast(string)f.read(true, 6)=="6789ABCDEF"); 
			f.write("XY"); 	assert(cast(string)f.read(true)=="XY"); 
			f.remove; 
		} 
		
		//globally accessible virtual file stuff
		struct virtualFiles {
			 __gshared static: 
					
						auto stats() {
				virtualFileQuery(VirtualFileCommand.stats, ""); 
				return _virtualFileCacheStats; 
			} 
					
						void garbageCollect() { virtualFileQuery(VirtualFileCommand.garbageCollect, ""); } 
		} 
		
	}version(/+$DIDE_REGION File listing+/all)
	{
		//FileEntry, listFiles, findFiles //////////////////////////////////
		version(/+$DIDE_REGION+/all)
		{
			
			import core.sys.windows.windows : WIN32_FIND_DATAW, INVALID_HANDLE_VALUE, FindFirstFileW, FileTimeToSystemTime, FindNextFileW, FindClose,
			FILE_ATTRIBUTE_DIRECTORY, FILE_ATTRIBUTE_READONLY, FILE_ATTRIBUTE_ARCHIVE, FILE_ATTRIBUTE_SYSTEM, FILE_ATTRIBUTE_HIDDEN; 
			
			struct FileEntry
			{
				Path path; 
				string name; 
				
				string fullName() const
				{ return path.fullPath~name; } 
				File file()const
				{ return File(fullName); } 
				
				FILETIME ftCreationTime, ftLastWriteTime, ftLastAccessTime; 
				long size; 
				uint dwFileAttributes; 
				
				@property
				{
					string ext() const
					{ return File(name).ext; } 
					bool isDirectory() const
					{ return (dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)!=0; } 
					bool isReadOnly() const
					{ return (dwFileAttributes & FILE_ATTRIBUTE_READONLY	)!=0; } 
					bool isArchive() const
					{ return (dwFileAttributes & FILE_ATTRIBUTE_ARCHIVE	)!=0; } 
					bool isSystem() const
					{ return (dwFileAttributes & FILE_ATTRIBUTE_SYSTEM	)!=0; } 
					bool isHidden() const
					{ return (dwFileAttributes & FILE_ATTRIBUTE_HIDDEN	)!=0; } 
				} 
				
				this(in WIN32_FIND_DATAW data, in Path path)
				{
					this.path	= path; 
					this.name	= data.cFileName.toStr; 
					this.ftCreationTime	= data.ftCreationTime; 
					this.ftLastWriteTime	= data.ftLastWriteTime; 
					this.ftLastAccessTime 	= data.ftLastAccessTime; 
					this.size	= data.nFileSizeLow | (long(data.nFileSizeHigh)<<32); 
					this.dwFileAttributes	= data.dwFileAttributes; 
				} 
				
				string toString() const
				{
					return format!"%-80s %s%s%s%s%s %12d cre:%s mod:%s"
					(
						File(path, name).fullName,
						isDirectory?"D":".", isReadOnly?"R":".", isArchive?"A":".", isSystem?"S":".", isHidden?"H":".",
						size, DateTime(UTC, ftCreationTime), DateTime(UTC, ftLastWriteTime)
					); 
				} 
				
				auto created () const
				{ return DateTime(UTC, ftCreationTime  ); } 
				auto accessed() const
				{ return DateTime(UTC, ftLastAccessTime); } 
				auto modified() const
				{ return DateTime(UTC, ftLastWriteTime ); } 
			} FileEntry[] listFiles(
				Path path, string mask="", string order="name",
				Flag!"onlyFiles" onlyFiles = Yes.onlyFiles, Flag!"recursive" recursive = No.recursive
			)
			{
				///similar directory listing like the one in totalcommander
				path = path.normalized; 
				
				enforce(!(!onlyFiles && recursive), "Invalid params"); 
				
				FileEntry[] files, paths, parent; 
				
				WIN32_FIND_DATAW data; 
				HANDLE hFind = FindFirstFileW((path.dir~`\*`).toPWChar, &data); 
				if(hFind != INVALID_HANDLE_VALUE)
				{
					do {
						auto entry = FileEntry(data, path); 
						if(entry.isDirectory)
						{
							if(entry.name == ".") continue; 
							if(entry.name == "..") { if(!onlyFiles) parent ~= entry; continue; }
							if(!onlyFiles || recursive) paths ~= entry; 
						}
						else
						{ if(mask=="" || entry.name.isWildMulti(mask)) files ~= entry; }
					}
					while(FindNextFileW(hFind, &data)); 
					FindClose(hFind); 
				}
				
				//Todo: implement recursive
				//Todo: onlyFiles && recursive, watch out for ".."!!!
				
				if(recursive)
				{
					foreach(p; paths.map!(a => Path(path, a.name)))
					{
						//LOG("listFiles recursion:", p);
						files ~= listFiles(p, mask, "", Yes.onlyFiles, Yes.recursive); 
					}
					
					paths.clear; 
				}
				
				if(order=="")
				{
					 //fast exit when no ordering needed
					if(onlyFiles) return files; 
					return chain(parent, paths, files).array; 
				}
				
				auto pathIdx = new int[paths.length]; 
				paths.makeIndex!((a, b) => icmp(a.name, b.name)<0)(pathIdx); 
				
				auto fileIdx = new int[files.length]; 
				
				auto ascending = 1; 
				if(order.startsWith("-")) { order = order[1..$]; ascending = -1; }
				order = order.withoutStarting("+"); 
				
				//Todo: these sorting routines are bad.  I should use DateTime, lessThan
				static auto cmpSize(long a, long b) { return a==b?0:a<b?1:-1; } 
				static auto cmpTime(FILETIME a, FILETIME b) { return cmpSize(*cast(long*)&a, *cast(long*)&b); } 
				
				switch(order.lc)
				{
					case "name": 	files.makeIndex!((a, b) => ascending*icmp(a.name, b.name)<0)(fileIdx); 	break; 
					case "ext": 	files.makeIndex!((a, b) => ascending*cmpChain(icmp(File(a.name).ext, File(b.name).ext), icmp(a.name, b.name))<0)(fileIdx); 	break; 
					case "size": 	files.makeIndex!((a, b) => cmpChain(ascending*cmpSize(a.size,b.size), icmp(a.name, b.name))<0)(fileIdx); 	break; 
					case "date": 	files.makeIndex!((a, b) => cmpChain(ascending*cmpTime(a.ftLastWriteTime, b.ftLastWriteTime), icmp(b.name, a.name))>0)(fileIdx); 	break; 
					default: 	raise("Invalid sort order: " ~ order.quoted); 
				}
				
				if(onlyFiles) return fileIdx.map!(i => files[i]).array; 
				return chain(parent, pathIdx.map!(i => paths[i]), fileIdx.map!(i => files[i])).array; 
			} 
			
			FileEntry[] findFiles(Path path, string mask="", string order="name", int level=0)
			{
				///this is a recursive search
				path = path.normalized; 
							
				FileEntry[] files, paths; 
							
				if(mask=="*") mask = ""; 
							
				WIN32_FIND_DATAW data; 
				HANDLE hFind = FindFirstFileW((path.dir~`\*`).toPWChar, &data); 
				if(hFind != INVALID_HANDLE_VALUE)
				{
					do {
						auto entry = FileEntry(data, path); 
						if(entry.isDirectory)
						{
							if(entry.name.among(".", "..")) continue; 
							paths ~= entry; 
						}
						else
						{ if(mask=="" || entry.name.isWild(mask)) files ~= entry; }
					}
					while(FindNextFileW(hFind, &data)); 
					FindClose(hFind); 
				}
							
				//recursion
				files ~= paths.map!(p => findFiles(Path(p.path, p.name), mask, order, level+1)).join; 
							
				//only sort on root level
				if(level==0)
				{
					//PERF("makeIndex");
					auto fileIdx = new int[files.length]; 
								
					auto ascending = 1; 
					if(order.startsWith("-")) { order = order[1..$]; ascending = -1; }
					order = order.withoutStarting("+"); 
								
					static auto cmpChain(int c1, lazy int c2) { return c1 ? c1 : c2; } 
					static auto cmpSize(long a, long b) { return a==b?0:a<b?1:-1; } 
					static auto cmpTime(FILETIME a, FILETIME b) { return cmpSize(*cast(long*)&a, *cast(long*)&b); } 
								
					switch(order.lc)
					{
						case "name": 	files.makeIndex!((a, b) => ascending*icmp(a.name, b.name)<0)(fileIdx); 	break; 
						case "ext": 	files.makeIndex!((a, b) => ascending*cmpChain(icmp(File(a.name).ext, File(b.name).ext), cmpChain(icmp(a.path.fullPath, b.path.fullPath), icmp(a.name, b.name)))<0)(fileIdx); 	break; 
						case "size": 	files.makeIndex!((a, b) => ascending*cmpSize(a.size,b.size)<0)(fileIdx); 	break; 
						case "date": 	files.makeIndex!((a, b) => ascending*(*cast(long*)&a.ftLastWriteTime-*cast(long*)&b.ftLastWriteTime)>0)(fileIdx); 	break; 
						default: 	raise("Invalid sort order: " ~ order.quoted); 
					}
					//PERF("buildArray");
								
					files = fileIdx.map!(i => files[i]).array; 
								
					//print(PERF.report);
								
					return files; 
				}
				else
				{ return files; }
							
			} 			 struct DirResult
			{
				static struct DirFile
				{
					File file; 
					ulong size; 
					DateTime modified; 
									
					string toString() const
					{ return format!"%s %12d %s"(modified, size, file.fullName); } 
				} 
				DirFile[] files; 
				
				static struct DirPath
				{
					Path path; 
					DateTime modified; 
					string toString() const
					{ return format!"%s %12s %s"(modified, "", path.fullPath); } 
				} 
				DirPath[] paths; 
				
				static struct DirExt
				{
					string ext; 
					ulong count, size; 
					string toString() const
					{ return format!"%-10s %7d %3sB"(ext, count, size.shortSizeText!1024); } 
				} 
				DirExt[] exts; 
				
				string toString() const
				{
					return 	files	.map!text.join('\n')~'\n'~
						paths	.map!text.join('\n')~'\n'~
						exts	.map!text.join('\n')~'\n'; 
				} 
			} 			 auto dirPerS(in Path path, string pattern = "*")
			{
				//dirPerS//////////////////////////
				
				/+
					 List files using dir DOS command
									note: this is bad: it's fast, but no second and millisecond precision, only hour:minute.
									use listFiles with recursion 
				+/
				
				DirResult res; 
				with(res)
				{
					
					Path actPath; 
					foreach(line; execute([`cmd`,	`/c`, `dir`, path.fullPath, `/s`, `/-c`]).output.splitLines)
					{
						//2011-01-03	01:05             93407 10-5.jpg
						if(line.isWild("????-??-??  ??:??     ????????????? *"))
						{
							auto f = File(actPath, wild[6]),
									 s = wild[5].strip.to!ulong,
									 d = DateTime(wild.ints(0), wild.ints(1), wild.ints(2), wild.ints(3), wild.ints(4), 0); 
							if(f.name.isWildMulti(pattern)) files ~= DirFile(f, s, d); 
						}
						else if(line.isWild(" Directory of *"))
						actPath = Path(wild[0]); 
					}
					
					files = files.sort!((a, b) => a.modified < b.modified).array; 
					
					DateTime[string] pathTimes; 
					files.each!((f){ if(f.file.fullPath !in pathTimes) pathTimes[f.file.fullPath] = f.modified; } ); 
					
					foreach(k, v; pathTimes)
					paths ~= DirPath(Path(k), v); 
					paths = paths.sort!((a, b) => a.modified<b.modified).array; 
					
					ulong[string] extCnt, extSize; 
					files.each!(
						(f){
							extCnt[f.file.ext.lc]++; 
							extSize[f.file.ext.lc]+=f.size; 
						} 
					); 
					
					foreach(k; extCnt.keys)
					exts ~= DirExt(k, extCnt[k], extSize[k]); 
					
					exts = exts.sort!((a, b) => a.size > b.size).array; 
					
				}
				return res; 
			} 
					
		}
	}
}
version(/+$DIDE_REGION debug+/all)
{
	version(/+$DIDE_REGION+/all)
	{
		import std.regex, std.demangle; 
		import core.sys.windows.windows: OpenFileMappingW, MapViewOfFile, CreateFileMappingW, FILE_MAP_ALL_ACCESS; 
		//Note: LLVM debugging: https://llvm.org/docs/SourceLevelDebugging.html
		
		//LOGGER /////////////////////////////////////////////////////////////
		
		__gshared int
			LOG_console = 0,
			LOG_dide = 0,
			LOG_throw = 50; 
		
		private template LOGLevelString(int level)
		{
			enum levelIdx	= ((level+1)/10-1).clamp(0, 4),
			subLevelDiff 	= level - levelIdx*10-10; 
			
			enum LOGLevelString 	= ["\33\13DBG_", "\33\17LOG_", "\33\16WARN", "\33\14ERR_", "\33\14CRIT"][levelIdx]
				~ (subLevelDiff ? subLevelDiff.text : ""); 
			
			enum Text 	= ["Debug", "Info", "Warning", "Error", "Critical"][levelIdx]; 
		} 
		
		private template LOGLevelText(int level)
		{
			enum levelIdx	= ((level+1)/10-1).clamp(0, 4); 
			enum LOGLevelText 	= ["Debug", "Info", "Warning", "Error", "Critical"][levelIdx]; 
			//Todo: this shit is overcomplicated
		} 
		
		string makeSrcLocation(string file, string funct, int line)
		{
			auto 	fi = file.split(`\`),
				fu = funct.split(`.`); 
			
			//ignore extension
			if(fi.length)
			fi[$-1] = fi[$-1].withoutEnding(".d"); 
			
			foreach_reverse(i;  1..min(fi.length, fu.length))
			{
				if(fi[$-i..$].equal(fu[0..i]))
				{
					funct = fu[i..$].join('.'); 
					break; 
				}
			}
			
			auto res = format!"%s(%d):"(file, line); 
			if(funct!="")
			res ~= " @"~funct; 
			
			return res; 
		} 
		
		__gshared MSQueue!string globalDbgRerouteQueue; 
		
		void DBG (int level = 10, string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args)
		{
			enum location = makeSrcLocation(file, funct, line); 
			
			if(globalDbgRerouteQueue)
			{
				string s = format!"%s: %s: "(LOGLevelText!level, location); 
				static foreach(idx, a; args)
				{
					if(idx)
					s ~= " "; s ~= a.text; 
				}
				//Todo: refactor this redundant crap
				globalDbgRerouteQueue.put(s); 
				return; 
			}
			
			//format colorful message
			string s = format!"%s\33\10: T%0.4f: C%x: %s:  \33\7"(LOGLevelString!level, QPS_local, GetCurrentProcessorNumber, location); 
			static foreach(idx, a; args)
			{
				if(idx)
				s ~= " "; s ~= a.text; 
			}
			s ~= "\33\7"; 
			
			if(level>=LOG_console)
			synchronized(dbg) writeln(s); 
			//if(level>=LOG_dide	) synchronized(dbg) dbg.sendLog(s);
			if(level>=LOG_throw)
			throw new Exception(s); 
		} 
		
		void LOG(string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args)
		{ DBG!(20, file, line, funct)(args); } 
		void WARN(string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args)
		{ DBG!(30, file, line, funct)(args); } 
		void ERR(string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args)
		{ DBG!(40, file, line, funct)(args); } 
		void CRIT(string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args)
		{ DBG!(50, file, line, funct)(args); } 
		
		void NOTIMPL(string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args)
		{
			synchronized
			{
				
				//show this error only once
				const h = file.hashOf(line); 
				__gshared bool[size_t] map; 
				if(h in map)
				return; 
				
				map[h] = true; 
				ERR!(file, line, funct)("NOT IMPLEMENTED"); 
			} 
		} 
		
		T HIST(size_t N, size_t M=0x10000, string name="", T)(T value)
		{
			static assert(M.isPowerOf2); 
			//Todo: this should be a measurement tool in DIDE
			static size_t[N] bucketCnt; 
			static size_t totalCnt; 
			
			bucketCnt[value.clamp(0, N-1)] ++; 
			totalCnt++; 
			if(totalCnt%M == 0)
			{
				writeln("HIST.totalCnt=", totalCnt); 
				bucketCnt[].each!writeln; 
				writeln; 
			}
			return value; 
		} 
		
		string COUNT(T, string file=__FILE__, int line=__LINE__)(T key)
		{
			synchronized
			{
				__gshared uint[T] a; a[key]++; 
				return a.byKeyValue.array.sort!"a.value>b.value"
					.map!((a)=>(format!"%9d %s"(a.value, a.key))).join('\n'); 
			} 
		} 
		
		
		///////////////////////////////////////////////////////////////////////////////////
		
		void PING(int index = 0)
		{ dbg.ping(index); } 
		void PING0()
		{ PING(0); } void PING1()
		{ PING(1); } void PING2()
		{ PING(2); } void PING3()
		{ PING(3); } 
		void PING4()
		{ PING(4); } void PING5()
		{ PING(5); } void PING6()
		{ PING(6); } void PING7()
		{ PING(7); } 
		
		//Todo: (forceExit) a thread which kills the process. for example when readln is active.
		
		/*
			void log(string s, string f = __FUNCTION__){
				StdFile(`c:\dl\a.txt`, "a").writeln(f, " ", s);
			}
		*/
		
		T _DATALOGMIXINFUNCT(T)(T t, string s, string file = __FILE__, int line = __LINE__)
		{
			auto fn = file; 
			fn.length = fn.indexOf("-mixin-"); 
			fn = extractFileName(fn)~'('~format("%s", line)~')'; 
			
			string msg = "LOG:"~fn~":"~s~":"~to!string(t); 
			dbg.sendLog(msg); 
			return t; 
		} 
		
		string _DATALOGMIXIN(string p)
		{ return `_DATALOGMIXINFUNCT(`~p~`, q{`~p~`})`; } 
		
		string _DATABRKMIXIN(string p)
		{ return `_DATALOGMIXINFUNCT(`~p~`, q{`~p~`})`; } 
		
		
		//Probe / inspection
		T PR(T, string file = __FILE__, int line = __LINE__)(T what)
		{
			dbg.sendLog(format!"LOG:PR(%s(%s)):%s"(file, line, what.text.toBase64)); 
			return what; 
		} 
		
		
		//DebugLogClient ////////////////////////////////////////////////////////////////////////////////////
		
		alias dbg = Singleton!DebugLogClient; 
		
		class DebugLogClient
		{
			//Todo: rewrite it with utils.sharedMemClient
			private: 
			
			
			version(/+$DIDE_REGION Shared Debug struct+/all)
			{
				enum circularBufferSize = 64<<10,
				memoryPoolSize = 64<<20; 
				
				struct BreakRec
				{ uint locationHash, state; } 
				static assert(BreakRec.sizeof==8); 
				
				struct BreakTable
				{
					BreakRec[64] records; 
					
					void waitFor(uint locationHash); 
				} 
				
				struct InteractiveValues
				{
					enum maxCount = 256; 
					ulong[maxCount] ids; 
					uint[maxCount] ticks/+nonzero: the value was modified recently by the server+/; 
					float[maxCount] floats = 0 /+Note: must be zero!!!+/; 
					ulong synchId; 
					
					void reset()
					{ this = this.init; } 
					
					int resolveIndex(ulong id, float def)
					{
						version(/+$DIDE_REGION Synchronization with multiple threads and with the debugger (another process).+/all)
						{
							waitForZeroAndSet(&synchId, id, 100_000).enforce("InteractiveValues: Timeout."); 
							scope(exit) synchId = 0; 
						}
						
						//the first time this thread accessed this interactive value
						auto i = ids[].until(0).countUntil(id).to!int; 
						if(i<0) {
							i = ids[].countUntil(0).to!int; 
							enforce(i>=0, "InteractiveValues: Run out of slots."); 
							ids[i] = id; /+allocate slot+/
							floats[i] = def; 
						}
						return i; 
					} 
				} 
				
				struct Data
				{
					/+
						Note: Important note:	All fields must be initialized to ZERO or VOID.	
						Otherwise a very	large initialization block will be placed on the	data segment.
						
						-> dumpbin /SECTION:rdata 
						SECTION HEADER #37B6
						 40102C0	size of raw data
							Initialized Data
							COMDAT; sym= _D3het14DebugLogClient4Data6__initZ
							
						/+Link: https://forum.dlang.org/thread/rdk3m2$725$1@digitalmars.com+/
					+/
					
					uint dbgDataStructHash; 
					uint ping; 
					BreakTable breakTable; 
					float[potiCount] poti = 0 /+Note: must be zero!!+/; 
					int forceExit; 
					int exe_waiting; 
					int dide_ack; /+
						exception utan exe_waiting = 1 -> dide ekkor F9-re beleir 1-et 
						az ackba es tovabbmegy az exe. ha -1-et ir az ack-ba, akkor kill.
					+/
					int dide_hwnd; //to call setforegroundwindow
					int exe_hwnd; 
					int exe_pid; 
					int console_hwnd; 
					InteractiveValues interactiveValues; 
					
					align(64) CircBuf!(uint, circularBufferSize) circularBuffer; //CircBuf is a struct, not a class
					
					align(64) ubyte[memoryPoolSize] memoryPool = void; //allocator on the client uses this to send big blobs
				} 
			}
			
			
			private SharedMemClient!Data sharedMem; 
			public Data* data; 
			
			MyAllocator!(16) allocator; 
			
			bool isActive()
			{ return data !is null; } 
			
			struct BlobRec { void* ptr; uint length; } 
			BlobRec[ulong] blobs; 
			//Todo: statistics: number of blobs, size of blobs
			
			
			ulong setBlob(ulong id, void[] buf)
			{
				if(!data) return 0; 
				
				ulong copyAndCalcBlobAddress(void* ptr)
				{
					ptr[0..buf.length] = buf; 
					return 	(cast(ulong)(buf.length)) |
						((cast(ulong)(ptr))-(cast(ulong)(data.memoryPool.ptr)))<<32; 
				} 
				
				if(auto a = id in blobs)
				{
					if(buf.length==a.length)
					{ return copyAndCalcBlobAddress(a.ptr); }
					
					allocator.free(a.ptr); 
					blobs.remove(id); 
				}
				
				if(auto p = allocator.alloc(buf.length))
				{
					blobs[id] = BlobRec(p, buf.length.to!uint); 
					return copyAndCalcBlobAddress(p); 
				}
				
				return 0; 
			} 
			
			
			public: 
			
			enum potiCount = 8; 
			
			this()
			{
				if(typeid(Data).initializer.ptr !is null)
				throw new Exception("het.DbgClient.Data: Nonzero initializer. Obj file has an enormous waste of zeroes inside."); 
				
				auto dataFileName = environment.get("DideDbgEnv", ""); 
				if(dataFileName=="") return; 
				
				sharedMem = new SharedMemClient!Data(dataFileName); 
				data = sharedMem.data; 
				
				if(data && data.dbgDataStructHash != getStructHash!Data)
				{
					//Todo: show this error on the server side
					/+
						writeln(
						"DebugClient: Incompatible dbgDataStructHash.  "~
						"Further debug communications are disabled."
						); 
					+/
					data = null; 
				}
				
				if(data) allocator = new typeof(allocator)(data.memoryPool[]); 
				
				sendLog("START:"~appFile.toString); 
			} 
			
			void ping(int index = 0)
			{
				if(!data) return; 
				data.ping |= 1<<index; 
			} 
			
			void sendLog(string s)
			{
				if(!data) return; 
				ubyte[] packet; 
				packet.length = 4+s.length; 
				*cast(uint*)(packet.ptr) = cast(uint)s.length; 
				memcpy(&packet[4], s.ptr, s.length); 
				while(!data.circularBuffer.store(packet))
				sleep(1); 
			} 
			
			string getLog()
			{
				//not needed on exe side. It's needed on dide side. Only for testing.
				if(!data) return ""; 
				
				uint siz; if(!data.circularBuffer.get(&siz, 4)) return ""; 
				
				ubyte[] buf; buf.length = siz; 
				
				while(!data.circularBuffer.get(buf.ptr, siz))
				sleep(1); //probably an error+deadlock...
				return cast(string)buf; 
			} 
			
			float getPotiValue(size_t idx)
			{
				if(data && idx>=0 && idx<data.poti.length)
				return data.poti[idx]; 
				else return 0; 
			} 
			
			bool forceExit_check()
			{ return data && !!data.forceExit; } 
			
			void focusIde()
			{
				if(data && data.dide_hwnd)
				SetForegroundWindow(cast(void*)data.dide_hwnd); 
			} 
			alias focusIDE = focusIde; 
			
			void handleException(string msg)
			{
				if(!data) return; 
				
				data.dide_ack = 0; 
				data.exe_waiting = 1; 
				
				focusIde; 
				
				//fileWriteStr(`c:\dl\exc.txt`, msg);
				string s = "EXCEPTION:"~msg; 
				dbg.sendLog(s); 
				
				while(!data.dide_ack)
				sleep(1); //wait for dide
				
				data.exe_waiting = 0; 
				
				if(data.dide_ack<0)
				{
					data.dide_ack = 0; 
					application.exit; 
				}
				
				data.dide_ack = 0; 
			} 
			
			void setExeHwnd(void* hwnd)
			{
				if(data)
				data.exe_hwnd = cast(int)hwnd; 
			} 
			
			void sendBlob(string s)
			{} 
		} 
		//Todo: Set a unique name to the dbgserver's Shared Memory, and pass it to the launched program.
		
		alias dbgsrv = Singleton!DebugLogServer; 
		
		class DebugLogServer
		{
			private: 
			alias Data = DebugLogClient.Data; 
			
			string dataFileName; 
			public @property getDataFileName() const
			{ return dataFileName; } 
			
			SharedMemServer!Data sharedMem; 
			public Data* data; 
			
			enum pingLedCount = 8; 
			int[pingLedCount] pingLedState; 
			
			void updatePingLeds()
			{
				if(!data) return; 
				
				auto st = data.ping;  data.ping = 0; //latch
				
				foreach(i, ref ps; pingLedState)
				ps = st.getBit(i) ? 255: ps*7 >> 3; 
			} 
			
			
			void processLogMessage(string s)
			{
				if(s.isWild("LOG:*"))	{
					if(onDebugLog)
					onDebugLog(wild[0]); 
				}
				else if(s.isWild("EXCEPTION:*"))	{
					if(onDebugException)
					onDebugException(wild[0]); 
				}
				else if(s.isWild("START:*"))	{
					if(onDebugStart)
					onDebugStart(wild[0]); 
				}
			} 
			
			void updateLog()
			{
				if(!data) return; 
				
				while(1)
				{
					auto d = CircBuf_getLog(
						data.circularBuffer.tail	, data.circularBuffer.head, 
						data.circularBuffer.capacity	, data.circularBuffer.buf.ptr
					); 
					if(d.empty) break; 
					
					//safely interpret it as UTF8. If fails, convert it from Latin1
					auto s = cast(string)d; 
					try
					{ validate(s); }catch(Exception)
					{
						import std.encoding; 
						transcode(cast(Latin1String)d, s); 
					}
					
					processLogMessage(s); 
				}
			} 
			
			ubyte[] CircBuf_getLog(ref uint tail, ref uint head, in uint cap, ubyte* buf)
			{
				//reads a packet from the circbuff
				uint capacity()
				{ return cap; } 	uint length()
				{ return head-tail; } 
				uint canGet()
				{ return length; } 	uint truncate(uint x)
				{ return x % cap; } 
				
				void Move(in void *source, void *destination, uint num)
				{ (cast(ubyte*)(destination))[0 .. num] = (cast(ubyte*)(source))[0 .. num]; } 
				
				bool get(ubyte* dst, uint dstLen)
				{
					//var i, o, fullLen:cardinal;
					if(dstLen>canGet)
					return false; 
					
					uint 	o 	= truncate(tail),
						fullLen 	= dstLen; 
					if(o+dstLen >= capacity)
					{
						//multipart
						uint i = capacity-o; 
						Move(&(buf[o]), dst, i); 
						o = 0; 
						dst += i; 
						dstLen -= i; 
					}
					if(dstLen>0)
					{ Move(&(buf[o]), dst, dstLen); }
					
					//advance in one step
					tail += fullLen; //no atomic needed as one writes and the other reads
					
					return true; 
				} 
				
				void flush()
				{ tail += canGet; } 
				
				uint siz; 
				if(!get(cast(ubyte*)(&siz), 4))
				return []; 
				//Todo: sanity check for siz
				if(siz>capacity-4)
				{
					WARN(i"Invalid message size. ($(siz))"); 
					flush; return []; 
				}
				
				auto res = uninitializedArray!(ubyte[])(siz); 
				auto t0 = now; 
				while(!get(res.ptr, siz))
				{
					sleep(1); //probably an error+deadlock...
					if(now-t0>0.1*second)
					{ flush; return []; }
				}
				return res; 
			} 
			public: 
			immutable het.math.RGB[pingLedCount] pingLedColors = 
				[0xffffff, 0x00FF00, 0x00FFe0, 0x2020FF, 0xFF2020, 0x00b0FF, 0xb000FF, 0xFFFF00]; 
			
			void delegate(string) onDebugStart, onDebugLog, onDebugException; 
			
			this()
			{
				//make a unique filename each time dbgsrv starts.
				dataFileName = format!"DIDEDGB_%08X"([now.raw].crc32); 
				sharedMem = new SharedMemServer!Data(dataFileName); 
				data = sharedMem.data; 
				
				if(data)
				{
					data.dbgDataStructHash = getStructHash!Data; 
					//client will compare its structureHash to this one.
				}
				
				
				
				if(!data)
				ERR(`dbgsrv: Could not map create debug fileMapping. Run this as Admin!`); 
			} 
			
			@property isActive() { return !!data; } 
			
			bool update()
			{
				if(!data) return false; 
				updatePingLeds; 
				updateLog; 
				return true; //Todo: only when chg...
			} 
			
			string pingLedStateText()
			{ return pingLedState[].enumerate.map!(a => a.value ? a.index.text : "_").join; } 
			
			void setPotiValue(int idx, float val)
			{
				if(data && idx.inRange(data.poti))
				data.poti[idx] = val; 
			} 
			
			void resetBeforeRun()
			{
				if(!data) return; 
				with(data)
				{
					dide_hwnd = cast(int)application.handle; 
					exe_hwnd = 0; 
					exe_pid = 0; 
					console_hwnd = 0; 
					forceExit = 0; 
					dide_ack = 0; 
					exe_waiting = 0; 
					interactiveValues.reset; 
				}
			} 
			
			void forceExit()
			{
				if(!data) return; 
				with(data)
				{
					dide_ack = -1; 
					forceExit = 1; 
					exe_waiting = 0; 
					//220429: This is needed when the exe is dead. It resets the IDE *break* state.
				}
			} 
			
			bool isForcingExit()
			{ return data && !!data.forceExit; } 
			
			bool isExeWaiting()
			{ return data && data.exe_waiting!=0; } 
			
			void setAck(int val)
			{ if(data) data.dide_ack = val; } 
			
			@property exe_pid()
			{ return data ? data.exe_pid : 0; } 	@property exe_pid(int val)
			{ if(data) data.exe_pid = val; } 
				
			@property console_hwnd()
			{ return data ? data.console_hwnd : 0; } 	@property console_hwnd(int val)
			{ if(data) data.console_hwnd = val; } 
				
			@property exe_hwnd()
			{ return data ? data.exe_hwnd : 0; } 	@property exe_hwnd(int val)
			{ if(data) data.exe_hwnd = val; } 
			
			void[] getBlob(ulong blobAddress)
			{
				if(!data) return null; 
				const 	base = blobAddress>>>32,
					length = cast(uint)blobAddress; 
				enforce(base>=0 && base+length<=Data.memoryPool.length, "blobAddress out of range"); 
				return data.memoryPool[base..base+length]; 
			} 
			
		} 
	}
	class DebugInfo
	{
		static private
		{
			alias DWORD 	= uint	, ULONG	= uint,
			DWORD64 	= ulong	, ULONG64 	= ulong,
			CHAR 	= char	, PCHAR	= char*	, PCSTR	= char*, PVOID = void*,
			BOOL	= DWORD	; 
			
			import core.sys.windows.windef : MAX_PATH; 
			enum FALSE=0, TRUE=1; 
			
			
			enum SYMFLAG_CLR_TOKEN	= 0x00040000,	//The symbol is a CLR token.
			SYMFLAG_CONSTANT	= 0x00000100,	//The symbol is a constant.
			SYMFLAG_EXPORT	= 0x00000200,	//The symbol is from the export table.
			SYMFLAG_FORWARDER	= 0x00000400,	//The symbol is a forwarder.
			SYMFLAG_FRAMEREL	= 0x00000020,	//Offsets are frame relative.
			SYMFLAG_FUNCTION	= 0x00000800,	//The symbol is a known function.
			SYMFLAG_ILREL	= 0x00010000,	/+
				//The symbol address is an offset relative to the beginning of the 
				intermediate language block. Managed code only.
			+/
			SYMFLAG_LOCAL	= 0x00000080,	//The symbol is a local variable.
			SYMFLAG_METADATA	= 0x00020000,	//The symbol is managed metadata.
			SYMFLAG_PARAMETER	= 0x00000040,	//The symbol is a parameter.
			SYMFLAG_REGISTER	= 0x00000008,	//The symbol is a register. The Register member is used.
			SYMFLAG_REGREL	= 0x00000010,	//Offsets are register relative.
			SYMFLAG_SLOT	= 0x00008000,	//The symbol is a managed code slot.
			SYMFLAG_THUNK	= 0x00002000,	//The symbol is a thunk.
			SYMFLAG_TLSREL	= 0x00004000,	//The symbol is an offset into the TLS data area.
			SYMFLAG_VALUEPRESENT	= 0x00000001,	//The Value member is used.
			SYMFLAG_VIRTUAL	= 0x00001000	/+
				The symbol is a virtual symbol created 
				by the SymAddSymbol function.
			+/; 
			
			enum SymTagEnum : ULONG
			{
				Null, Exe, Compiland, CompilandDetails, CompilandEnv, Function, Block, Data, Annotation, Label, PublicSymbol, UDT, Enum, 
				FunctionType, PointerType, ArrayType,  BaseType, Typedef, BaseClass, Friend, FunctionArgType, FuncDebugStart,  
				FuncDebugEnd, UsingNamespace, VTableShape, VTable, Custom, Thunk, CustomType, ManagedType, Dimension 
			} 
			
			struct SYMBOL_INFO
			{
				ULONG SizeOfStruct; 
				ULONG TypeIndex; 	/+
					A unique value that identifies the type data that describes the symbol.
					This value does not persist between sessions.
				+/
				ULONG64[2] Reserved; 	
				ULONG Index; 	/+
					The unique value for the symbol. The value associated with a symbol 
					is not guaranteed to be the same each time you run the process.
				+/
				ULONG Size; 	/+
					The symbol size, in bytes	(or bits, if the symbol is a bitfield member).
					For Types it's PDB only.	For Symbols it's the code size.
				+/
				ULONG64 ModBase; 	
				ULONG Flags; 	
				ULONG64 Value; 	
				ULONG64 Address; 	
				ULONG Register; 	
				ULONG Scope; 	/+
					The DIA scope. For more information, see the 
						Debug Interface Access SDK in the Visual Studio documentation.
				+/
				SymTagEnum Tag; 	
				ULONG NameLen; 	
				ULONG MaxNameLen; 	
				CHAR[1] Name; 	
				/+
					Note: Notes for LDC2:
					Address, Size 	0 for Types.  Meaningful for Symbols
					Value	0 for Types and Symbols
					Register	0 for Types and Symbols
					Scope	1: Tag.Data, Tag.Function  (Not needed: the Tag enum covers this.)
						10: Tag.PublicSymbol (internal mangledn functions names: starting with "D2", "D3", "weak.")
					Tag	EnumSymbols: Data, Function, PublicSymbol   
						EnumTypes: Typedef, Enum, UDT
						Meaningful for Types and Symbols
					Flags	FUNCTION: all the "weak." PublicSymbols    All flags are quite  useless.
					
					EnumTypes(): TypeIndex==Index. This TipeIndex IS NOT THE ONE that EnumSymbols.TypeIndex refers to!!!
						So this way the EnumTypes() is useless.
					
				+/
			} 
			
			struct SRCCODEINFO
			{
				DWORD SizeOfStruct; 
				PVOID Key; //This member is not used.
				DWORD64 ModBase; 
				CHAR[MAX_PATH + 1] Obj; 
				CHAR[MAX_PATH + 1] FileName; 
				DWORD LineNumber; 
				DWORD64 Address; 
			} 
			
			alias SYM_ENUMMODULES_CALLBACK64 	= extern(Windows) BOOL function(
				const PCSTR ModuleName,
				const ULONG64 BaseOfDll,
				const PVOID UserContext
			),
			SYM_ENUMERATESYMBOLS_CALLBACK 	= extern(Windows) BOOL function(
				const SYMBOL_INFO* pSymInfo,
				const ULONG SymbolSize,
				const PVOID UserContext
			),
			SYM_ENUMLINES_CALLBACK 	= extern(Windows) BOOL function(
				const SRCCODEINFO* LineInfo,
				const PVOID UserContext
			); 
			
			enum SYMENUM_OPTIONS_DEFAULT 	= 1,
			SYMENUM_OPTIONS_INLINE	= 2; 
			
			struct DbgHelp2
			{
				extern(Windows)
				{
					BOOL function(
						const HANDLE	hProcess,
						SYM_ENUMMODULES_CALLBACK64 	EnumModulesCallback,
						const PVOID	UserContext
					) SymEnumerateModules64; 
					BOOL function(
						const HANDLE	hProcess,
						const ULONG64	BaseOfDll,
						const PCSTR	Mask,
						const SYM_ENUMERATESYMBOLS_CALLBACK 	EnumSymbolsCallback,
						const PVOID	UserContext
					) SymEnumSymbols; 
					BOOL function(
						const HANDLE	hProcess,
						const ULONG64	BaseOfDll,
						const PCSTR	Mask,
						const SYM_ENUMERATESYMBOLS_CALLBACK 	EnumSymbolsCallback,
						const PVOID	UserContext,
						const DWORD	Options
					) SymEnumSymbolsEx; 
					BOOL function(
						const HANDLE	hProcess,
						const ULONG64	Base,
						const PCSTR	Obj,
						const PCSTR	File,
						const DWORD	Line,
						const DWORD	Flags,
						const SYM_ENUMLINES_CALLBACK 	EnumLinesCallback,
						const PVOID	UserContext
					) SymEnumSourceLines; 
					BOOL function(
						const HANDLE	hProcess,
						const ULONG64	BaseOfDll,
						const SYM_ENUMERATESYMBOLS_CALLBACK	EnumSymbolsCallback,
						const PVOID	UserContext
					) SymEnumTypes; 
				} 
				static auto get()
				{
					__gshared HANDLE lib; 
					__gshared DbgHelp2 inst; 
					if(!lib)
					{
						lib = loadLibrary("dbghelp.dll", false); 
						if(lib)
						{
							getProcAddress(lib, "SymEnumerateModules64", inst.SymEnumerateModules64, true); 
							getProcAddress(lib, "SymEnumSymbols", inst.SymEnumSymbols, true); 
							getProcAddress(lib, "SymEnumSymbolsEx", inst.SymEnumSymbolsEx, true); //Note: *
							getProcAddress(lib, "SymEnumSourceLines", inst.SymEnumSourceLines, true); 
							getProcAddress(lib, "SymEnumTypes", inst.SymEnumTypes, true); 
							
							/+
								Note: Notes:
								* Using SymEnumSymbolsEx with SYMENUM_OPTIONS_INLINE returns nothing.
							+/
						}
					}
					
					return inst; 
				} 
			} 
		} 
		
		
		
		enum SymbolType : ubyte
		{
			Unknown,
			Typedef, Enum, UDT,	//Address is 0, Size is usually valid
			Module, Data, Function, Public, 	//Address and Size are valid. Som data is based on offset:0
			Line 	//Address is valid,  Size is Line
		} 
		
		static private auto toSymbolType(SymTagEnum a)
		{
			with(SymbolType)
			switch(a)
			{
				case SymTagEnum.Typedef: 	return Typedef; 
				case SymTagEnum.Enum: 	return Enum; 
				case SymTagEnum.UDT: 	return UDT; 
				case SymTagEnum.Data: 	return Data; 
				case SymTagEnum.Function: 	return Function; 
				case SymTagEnum.PublicSymbol: 	return Public; 
				default: return Unknown; 
			}
			
		} 
		
		static struct Symbol
		{
			string name; 
			ulong addr; 
			uint size; alias line = size; 
			SymbolType type; 
			
			string toString() const
			{ return format!"0x%016x %5d %8s %s"(addr, size, type, name); } 
		} 
		
		static struct SymbolRecord
		{
			ulong addr; 
			uint size; alias line = size; 
			uint _dw; 
			@property uint nameOffset() const { return _dw.getBits(0, 24); } 
			@property void nameOffset(uint a) { _dw = _dw.setBits(0, 24, a); } 
			@property SymbolType type() const { return cast(SymbolType)_dw.getBits(24, 8); } 
			@property void type(SymbolType a) { _dw = _dw.setBits(24, 8, a); } 
			
			static assert(SymbolRecord.sizeof==16); 
			
			Symbol decode(DebugInfo di)
			{
				auto 	a = di.nameStream[nameOffset..$]; 
				
				//decompress length
				ubyte blen; uint len; 
				a.stRead(blen); 
				if(blen==0xFF) a.stRead(len); else len = blen; 
				
				return Symbol(cast(string)a[0..len], addr, size, type); 
			} 
		} 
		
		private
		{
			ubyte[] nameStream; 
			uint[string] nameOffsets; 
			SymbolRecord[] records; 
			
			static DebugInfo actInstance; 
			
			void addRecord(SymbolType type, ulong addr, uint sizeLine, string name)
			{
				SymbolRecord rec; 
				
				rec.addr = addr; 
				rec.size = sizeLine; 
				
				auto ofs = name in nameOffsets; 
				if(!ofs)
				{
					enforce(nameStream.length<0x100_0000, "nameStream overflow"); 
					nameOffsets[name] = cast(uint)nameStream.length; 
					
					//compress length
					const 	len = name.length.to!uint,
						lenb = cast(ubyte) len.min(0xFF); 
					nameStream.stWrite(lenb); 
					if(lenb==0xFF) nameStream.stWrite(len); 
					//write text
					nameStream ~= cast(ubyte[])name; 
					
					ofs = &nameOffsets[name]; 
				}
				
				rec.nameOffset = *ofs; 
				rec.type = type; 
				
				records ~= rec; 
			} 
		} 
		
		void clear()
		{
			nameStream.clear; 
			object.clear(nameOffsets); //Todo: clear is ambiguous here.
			records.clear; 
		} 
		
		auto symbols()
		{ return records.map!(r => r.decode(this)); } 
		
		//Detect from the current process
		this()
		{
			auto dh2 = DbgHelp2.get; 
			actInstance = this; 
			const process = GetCurrentProcess; 
			
			//find modules
			extern(Windows) 
			BOOL enumModulesProc(const PCSTR ModuleName, const ULONG64 BaseOfDll, const PVOID UserContext)
			{
				DebugInfo.actInstance.addRecord(SymbolType.Module, BaseOfDll, 0, ModuleName.text); 
				return true; 
			} 
			dh2.SymEnumerateModules64(process, &enumModulesProc, null); 
			
			if(records.length)
			{
				const mainBase = records[0].addr; 
				
				extern(Windows) BOOL enumSymProc(
					const SYMBOL_INFO* pSymInfo, const ULONG SymbolSize, 
					const PVOID UserContext
				)
				{
					with(pSymInfo)
					DebugInfo.actInstance.addRecord(
						toSymbolType(Tag), Address, Size, 
						(cast(char*) &pSymInfo.Name).text
					); 
					return TRUE; 
				} 
				
				static if(0)
				{
					/+
						There is typeinfo, but with the Index and TypeIndex fields 
						it is not possible to connect to the Symbols.
						It takes .3 seconds, So it is omitted.  This info is also in the obj.JSON file.
					+/
					dh2.SymEnumTypes(process, mainBase, &enumSymProc, null); 
				}
				
				dh2.SymEnumSymbols(process, mainBase, null, &enumSymProc, null); 
				
				extern(Windows) BOOL enumLineProc(const SRCCODEINFO* LineInfo, const PVOID UserContext)
				{
					with(LineInfo)
					{
						auto fn = FileName.toStr; 
						if(!fn.endsWith('d')/+Don't check extensions like ".d", those are good+/)
						{
							/+
								These source positions are linked at the end of the module.
								So it is possible to exit and finish faster.
								Hopefully after these there will be no dlang functions.
							+/
							if(fn.canFind(`\vcruntime\src\`)) return FALSE; 
							if(fn.canFind(`\WINDOWS\system32\`)) return FALSE; 
						}
						DebugInfo.actInstance.addRecord(SymbolType.Line, Address, LineNumber, fn); 
					}
					
					return TRUE; 
				} 
				dh2.SymEnumSourceLines(
					process, mainBase, 
					null, null, 0, 0,
					&enumLineProc, null
				); 
			}
			
			records = records.sort!((a, b) => a.addr==b.addr ? a.type<b.type : a.addr<b.addr).array; 
		} 
		
		this(ubyte[] stream)
		{ raw = stream; } 
		
		enum signature = "$DIDE_DBG ver=230815\n\n\n\n"; 
		static assert(signature.length==24); 
		
		@property auto raw()
		{
			ubyte[] stream; 
			stream ~= cast(ubyte[]) signature; 
			stream ~= cast(ubyte[]) cast(void[]) [
				records.length.to!uint, 
				nameStream.length.to!uint
			]; 
			stream ~= cast(ubyte[]) records; 
			stream ~= cast(ubyte[]) nameStream; 
			const hash = stream.xxh3_64; 
			stream ~= (cast(byte*)&hash)[0..typeof(hash).sizeof]; 
			return stream; 
		} 
		
		@property void raw(ubyte[] stream)
		{
			if(stream.empty) return; 
			
			const sign = stream.take(signature.length).array; 
			enforce(cast(string)sign==signature, "Invalid $DIDE_DBG signature"); 
			
			const ulong hash = *(cast(ulong*)&stream[$-8]); 
			enforce(stream[0..$-8].xxh3_64==hash ,"Invalid $DIDE_DBG hash"); 
			
			stream = stream[signature.length..$-8]; 
			
			uint recordCount, nameStreamSize; 
			stream.stRead(recordCount); 
			stream.stRead(nameStreamSize); 
			
			records = (cast(SymbolRecord*)&stream[0])[0..recordCount]; 
			stream = stream[records.sizeBytes..$]; 
			nameStream = stream; 
		} 
		
	} class MyAllocator(uint alignment_)
	{
		import std.container : RedBlackTree; 
		
		enum alignment = alignment_; 
		static assert(alignment>0 && !(alignment & (alignment-1))); 
		
		protected: 
		
		alias Chunk = ubyte[alignment]; 
		Chunk[] memory; 
		struct Block {
			uint st, en; 
			@property length() const
			{ return en-st; } 
			@property sizeBytes() const
			{ return length*Chunk.sizeof; } 
		} 
		
		static bool lessThanBySize(in Block a, in Block b)
		{
			if(a.length==b.length) return a.st<b.st; 
			return a.length<b.length; 
		} 
		
		static bool lessThanByPos(in Block a, in Block b)
		{ return a.st<b.st; } 
		
		Block[uint] usedBlocks; 
		RedBlackTree!(Block, lessThanBySize, false) freeBlocksBySize; 
		RedBlackTree!(Block, lessThanByPos, false) freeBlocksByPos; 
		
		void addFreeBlock(Block fb)
		{
			assert(fb.en>fb.st); 
			
			freeBlocksBySize.insert(fb); 
			freeBlocksByPos.insert(fb); 
		}  void removeFreeBlock(Block fb)
		{
			freeBlocksBySize.removeKey(fb); 
			freeBlocksByPos.removeKey(fb); 
		} 
		
		void addUsedBlock(Block ub)
		{
			assert(ub.en>ub.st); 
			
			usedBlocks[ub.st] = ub; 
		}  void removeUsedBlock(uint st)
		{ usedBlocks.remove(st); } 
		
		public: 
		
		this(void[] memory_)
		{
			auto 	p0 = (cast(size_t)(memory_.ptr)).alignUp(alignment), 
				p1 = (p0 + memory_.length).alignDown(alignment); 
			enforce(p1>p0, "MyAlloc.init: Memory pool is too small."); 
			enforce(p1-p0<=uint.max, "MyAlloc.init: Memory pool is too big."); 
			memory = (cast(Chunk[])((cast(void*)(p0))[0 .. p1-p0])); 
			
			freeBlocksBySize = new typeof(freeBlocksBySize); 
			freeBlocksByPos = new typeof(freeBlocksByPos); 
			
			addFreeBlock(Block(0, memory.length.to!uint)); //the very first block
		} 
		
		void* alloc(size_t requiredBytes)
		{
			const requiredChunksL = ((max(requiredBytes, 1) + Chunk.sizeof - 1)/(Chunk.sizeof)); 
			if(requiredChunksL>uint.max) return null; //way too big
			const requiredChunks = (cast(uint)(requiredChunksL)); 
			if(requiredChunks<=0) return null; //nothing to alloc
			auto sufficientFreeBlocks = 	freeBlocksBySize.upperBound
				(
				Block(
					uint.max-(requiredChunks-1), 
					uint.max
				)
				/+
					Note: Special non-inclusive bound value
					of one less length.
				+/
			); 
			
			if(sufficientFreeBlocks.empty) return null; //out of memory
			auto fb = sufficientFreeBlocks.front; 
			assert(fb.length>=requiredChunks); 
			removeFreeBlock(fb); 
			if(fb.length==requiredChunks)
			{
				addUsedBlock(fb); 
				return &memory[fb.st]; 
			}
			else
			{
				auto nb = Block(fb.st, fb.st + requiredChunks); 
				fb.st += requiredChunks; 
				
				addFreeBlock(fb); 
				addUsedBlock(nb); 
				return &memory[nb.st]; 
			}
		} 
		
		bool free(void* ptr)
		{
			if(ptr<memory.ptr) return false; 
			if(ptr>=memory.ptr+memory.length) return false; 
			
			const st = (cast(uint)((((cast(size_t)(ptr))-(cast(size_t)(memory.ptr)))/(Chunk.sizeof)))); 
			if(auto a = st in usedBlocks)
			{
				auto ub = *a; 
				removeUsedBlock(st); 
				
				
				bool tryExtendLeft()
				{
					auto a = freeBlocksByPos.lowerBound(Block(ub.st, ub.st)); 
					if(!a.empty && a.front.en==ub.st)
					{ ub.st = a.front.st; removeFreeBlock(a.front); return true; }
					return false; 
				} 
				while(tryExtendLeft) {}
				bool tryExtendRight()
				{
					auto a = freeBlocksByPos.upperBound(Block(ub.st, ub.st)); 
					if(!a.empty && a.front.st==ub.en)
					{ ub.en = a.front.en; removeFreeBlock(a.front); return true; }
					return false; 
				} 
				while(tryExtendRight) {}
				
				addFreeBlock(ub); 
				
				//Todo: join with other free blocks
				return true; 
			}
			return false; 
		} 
		
		@property countUsed()
		=> usedBlocks.length; 	@property sizeUsed() => (mixin(求sum(q{b},q{usedBlocks.byValue},q{b.sizeBytes}))); 
		@property countFree()
		=> freeBlocksByPos[].walkLength; 	@property sizeFree() => (mixin(求sum(q{b},q{freeBlocksByPos[]},q{b.sizeBytes}))); 
		@property stats() {
			return i"    	Count	Size
	Used:	$(countUsed)	$(sizeUsed)
	Free:	$(countFree)	$(sizeFree)
	Total:	$(countUsed+
	countFree)	$(sizeUsed+
	sizeFree)".text; 
		} 
		
		static void test()
		{
			randSeed = 123; 
			const M = 512<<20; 
			const N = 16384; 
			auto memory = new ubyte[M]; 
			auto ta = new MyAllocator(memory); 
			ta.stats.print; 
			
			size_t totalSize; 
			
			auto randomAlloc()
			{
				const size = random(max(M/N, 1)); 
				totalSize += size; 
				return ta.alloc(random(max(M/N, 1))).enforce("alloc() failed"); 
			} 
			
			auto ptrs = (mixin(求map(q{0<=i<N},q{},q{randomAlloc}))).array; 
			T0; 
			mixin(求each(q{i=1},q{1<<20},q{
				if(!(i&0xFFFF)) { print(i, totalSize); ta.stats.print; }
				auto j=random(N); 
				ta.free(ptrs[j]).enforce("free() failed."); 
				ptrs[j]=randomAlloc; 
			})); 
			DT.print; 
			
			/+
					Count	  Size
				Used:	16384	 268572624
				Free:	12549	 268298288
				Total:	28933	 536870912
				2.37975	[T]
			+/
			
			totalSize.print; 
		} 
		
	} 
}version(/+$DIDE_REGION Stream+/all)
{
	import het.parser; 
	
	//Todo: Try binary serialization: https://github.com/atilaneves/cerealed
	
	//Todo: auto ref parameters.
	//Todo: srcFunct seems obsolete.
	//Todo: srcFunct seems obsolete.
	
	//21.02.03
	//Todo: propertySet getters with typed defaults
	//Todo: propertySet getters with reference output
	//Todo: propertySet export to json with act values (or defaults)
	//Todo: propertySet import from json with act values (or defaults)
	//Todo: string.fromJson(`"hello"`),   int.fromJson("124");	 ...
	//Todo: "hello".toJson(),   1234.toJson("fieldName");  ...	 //must work on const!
	//Todo: import a struct from a propertySet
	//Todo: HitInfo.toJson is fucked up.
	
	private __gshared string[string] classFullNameMap; 
	
	private alias LoaderFunc = void function(ref JsonDecoderState state, int idx, void*); 
	private alias SaverFunc = void function(ref string st, void* data, bool dense=false, bool hex=false, string thisName="", string indent=""); 
	
	private __gshared LoaderFunc[string] classLoaderFunc; 
	private __gshared SaverFunc [string] classSaverFunc; 
	
	void registerStoredClass(T)()
	{
		classFullNameMap[T.stringof] = fullyQualifiedName!T; 
		
		classLoaderFunc[fullyQualifiedName!T] = cast(LoaderFunc) (&streamDecode_json!T); 
		classSaverFunc [fullyQualifiedName!T] = cast(SaverFunc ) (&streamAppend_json!T); 
	} 
	
	private auto quoteIfNeeded(string s)
	{ return s.canFind(" ") ? quoted(s) : s; } //Todo: this is lame, must make it better in utils/filename routines
	
	public /+Translate some reserved words in D, that is acceptable in Json.+/
	{
		static immutable jsonReservedWords = [
			"alias", "align", "char", "default", "in", "init", "out", "this",
			"public", "private", "package", "protected", "export",
			"class", "interface", "mixin", "struct", "template", "union",
			"import", "enum", "function"
		]; 
		static immutable jsonReservedWordMap = assocArray(jsonReservedWords, true.repeat); 
		
		string jsonFieldToIdentifier(string js)
		{
			if(__ctfe /+because no assoc arrays in CT.+/)
			return ((jsonReservedWords.canFind(js))?(js~"_"):(js)); 
			else
			return ((js in jsonReservedWordMap)?(js~"_"):(js)); 
		} 
		
		
		string identifierToJsonField(string id)
		=> ((id.endsWith('_') && id[0..$-1] in jsonReservedWordMap)?(id[0..$-1]):(id)); 
	} 
	
	struct JsonDecoderOptions
	{
		string moduleName; 
		ErrorHandling errorHandling; 
		bool checkIgnoredFields; 
	} 
	
	struct JsonDecoderState
	{
		//JsonDecoderState
		string stream; 
		JsonDecoderOptions options; 
		
		
		string srcFile, srcFunct; int srcLine; //These are for raising errors
		
		
		Token[] tokens; 
		string[] errors; 
		
		string errorMsg(string msg, int tokenIdx=-1)
		{
			
			string location; 
			if(tokenIdx.inRange(tokens))
			{
				auto t = &tokens[tokenIdx]; 
				location = format!`%s(%s:%s): `(quoteIfNeeded(options.moduleName), t.line+1, t.posInLine+1); 
			}
			else if(options.moduleName!="")
			{ location = quoteIfNeeded(options.moduleName) ~ ": "; }
			
			return (location ~ " " ~ msg).strip; 
		} 
		
		void raise(string msg, int tokenIdx=-1)
		{ throw new Exception(errorMsg(msg, tokenIdx), srcFile, srcLine); } 
		
		void onError(string msg, int tokenIdx=-1)
		{
			if(msg=="") return; 
			
			with(ErrorHandling)
			final switch(
				options.
				errorHandling
			) {
				case ignore: break; 
				case warn: WARN(errorMsg(msg, tokenIdx)); break; 
				case raise: this.raise(msg, tokenIdx); break; 
				case track: errors ~= errorMsg(msg, tokenIdx); 
			}
		} 
		
	} 
	
	//! fromJson ///////////////////////////////////
	
	string[] fromJson/*_ignore*/(Type)
	(
		ref Type data, string st, JsonDecoderOptions options,
		string srcFile=__FILE__, string srcFunct=__FUNCTION__, int srcLine=__LINE__
	)
	{
		auto state = JsonDecoderState(st, options, srcFile, srcFunct, srcLine); 
		
		try
		{
			//1. tokenize
			auto err = tokenize(state.options.moduleName, state.stream, state.tokens); //Todo: tokenize throw errors
			if(err!="") throw new Exception(err); 
			if(state.tokens.empty) throw new Exception("Empty json document."); 
			
			//2. hierarchy
			discoverJsonHierarchy(state.tokens); 
			
			//3. jsonParse
			streamDecode_json(state, 0, data); 
		}
		catch(Throwable e) { state.onError(e.msg); }
		
		return state.errors; 
	} 
	
	//Default version, errors are ignored.
	//alias fromJson = fromJson_ignore;
	string[] fromJson/*_ignore*/(Type)
	(
		ref Type data, string st, string moduleName="unnamed_json",
		ErrorHandling errorHandling=ErrorHandling.ignore,
		string srcFile=__FILE__, string srcFunct=__FUNCTION__, int srcLine=__LINE__
	)
	{ return data.fromJson(st, JsonDecoderOptions(moduleName, errorHandling), srcFile, srcFunct, srcLine); } 
	
	/+
		auto fromJson_raise(Type)(ref Type data, string st, string moduleName="", string srcFile=__FILE__, string srcFunct=__FUNCTION__,int srcLine=__LINE__){
		fromJson!(Type)(data, st, moduleName, ErrorHandling.raise, srcFile, srcFunct, srcLine); }
		auto fromJson_track(Type)(ref Type data, string st, string moduleName="", string srcFile=__FILE__, string srcFunct=__FUNCTION__, int srcLine=__LINE__){
		return	fromJson!(Type)(data, st, moduleName, ErrorHandling.track, srcFile, srcFunct, srcLine); }
	+/
	
	//Todo: this should be a nonDestructive overwrite for not just classes but for assocArrays too.
	string[] propsFromJson(Type)
	(
		Type data, string st, string moduleName="unnamed_json",
		ErrorHandling errorHandling=ErrorHandling.ignore,
		string srcFile=__FILE__, string srcFunct=__FUNCTION__, int srcLine=__LINE__
	)
	if(is(Type == class))
	{
		auto orig = data; 
		auto errors = fromJson(data, st, moduleName, errorHandling, srcFile, srcFunct, srcLine); 
		if(data !is orig) {
			auto msg = "propsFromJson: Unable to read object fields."; 
			with(ErrorHandling)
			final switch(errorHandling) {
				case ignore: 		break; 
				case warn: 	WARN(msg); 	break; 
				case raise: 	.raise(msg); 	break; 
				case track: 	errors ~= msg; 
			}
		}
		return errors; 
	} 
	
	//errorHandling: 0: no errors, 1:just collect the errors, 2:raise
	
	///Creates a write only property which redirect a json field into an existing field. 
	///Gives ERR message when the existing field already have data.
	mixin template RedirectJsonField(
		alias 	_dstField	/+The target field of the struct we are in.+/, 
		string 	_srcField	/+The name of the field in the JSon object.+/, 
		string 	_unaryFun="a"	/+
			Optional transformation of the data. Eg:/+Code: a+1+/
			'a' is the identifier of the incoming value as a parameter.
		+/
	)
	{
		mixin(
			iq{
				void $(_srcField)(typeof(_dstField) a)
				{
					if(_dstField!=typeof(_dstField).init)
					{
						ERR(
							i"Error combining values from multiple JSON fields, target already HAS a value.
Target field: $(_dstField.stringof)
Source field: $(_srcField)"
						); 
					}
					_dstField = $(_unaryFun); 
				} 
			}.text
		); 
	} 
	
	mixin template RedirectJsonFields(
		alias 	_dstField	/+single target field+/, 
		string[] 	_srcFields	/+multiple source JSon fields+/, 
		string 	_unaryFun="a"
	)
	{ static foreach(_srcField; _srcFields) mixin RedirectJsonField!(_dstField, _srcField, _unaryFun); } 
	
	version(none)
	{
		/+Note: Example usage:+/
		mixin RedirectJsonField!(base, "baseDeco", q{a.demangleType}); 
		
		/+Note: Code injected by string mixin() inside template:+/
		void baseDeco(typeof(_dstField) a)
		{
			if(_dstField!=typeof(_dstField).init)
			{
				ERR(
					i"Error combining values from multiple JSON fields, target already HAS a value.
Target field: 	$(_dstField.stringof) 	Target value: 	$(_dstField)
Source field: 	$(_srcField) 	Source field: 	$(a)"
					/+Note: Only the outermost level of $() is processed, by the string interpolator.+/
				); 
			}
			_dstField = a.demangleType; 
		} 
		
		/+Note: Code transformed by template mixin instantiation+/
		void baseDeco(typeof(base) a)
		{
			if(base!=typeof(base).init)
			{
				ERR(
					i"Error combining values from multiple JSON fields, target already HAS a value.
Target field: 	$(base.stringof) 	Target value: 	$(base)
Source field: 	$("baseDeco") 	Source field: 	$(a)"
				); 
			}
			base = a.demangleType; 
		} 
		
		/+
			Note: What the nested interpolated string looks like in RunTime:
			/+
				Code: Target field: 	this.base	Target value: 	_oldValue_from_field
				Source field: 	baseDeco 	Source value: 	_new_value_in_param_a
			+/
		+/
	}
	
	void streamDecode_json(Type)(ref JsonDecoderState state, int idx, ref Type data) 
	{
		ref Token actToken() { return state.tokens[idx]; } 
		
		//Todo: this mapping is lame
		bool isOp(char b)()
		{
			static if(b=='[') return actToken.isOperator(opsquareBracketOpen); 
			else static if(b==']')	return actToken.isOperator(opsquareBracketClose); 
			else static if(b=='{')	return actToken.isOperator(opcurlyBracketOpen); 
			else static if(b=='}')	return actToken.isOperator(opcurlyBracketClose); 
			else static if(b==',')	return actToken.isOperator(opcomma); 
			else static if(b==':')	return actToken.isOperator(opcolon); 
			else static if(b=='-')	return actToken.isOperator(opsub); 
			else	static assert(0, `Unhandled op "%s"`.format(b)); 
		} 
		
		string peekClassName(int[string] elementMap)
		{
			string res; 
			
			bool check(string cn)
			{
				if(auto p = cn in elementMap) {
					auto idx = *p; 
					if(state.tokens[idx].isString) {
						res = state.tokens[idx].data.to!string; 
						//print("Json className found:", res);
						return true; 
					}
				}
				return false; 
			} 
			
			/+Note: !!! Use the identifier form, NOT the json form. -> "class_"+/
			if(check(q{class_})) return res; 
			
			/+
				Todo: Special class detection can be implemented here.
				 - Different `class` keyword
				 - Modified className in res
			+/
			
			return ""; 
		} 
		
		void expect(char b)()
		{
			if(!isOp!b) throw new Exception(format!`"%s" expected.`(b)); 
			idx++; 
		} 
		
		bool isNegative; //Opt: is multiply with 1/-1 better?
		void getSign()
		{ if(isOp!'-') { isNegative = true; idx++; }} 
		
		auto extractElements()
		{
			int[string] elementMap; 
			
			enum log = false; 
			if(log) write("JSON discover fields: "); 
			
			const level = actToken.level; 
			expect!'{'; 
			
			while(1)
			{
				if(isOp!'}') break; //"}" right after "," or "{"
				
				if(actToken.kind != TokenKind.literalString) throw new Exception("Field name string literal expected."); 
				auto fieldName = actToken.data.to!string.jsonFieldToIdentifier; 
				idx++; 
				
				expect!':'; 
				
				//remember the start of the element
				elementMap[fieldName] = idx;              //Opt: ez a megoldas igy qrvalassu
				if(log) write(fieldName, " ", idx, " "); 
				
				//skip until the next '}' or ','
				int idx0 = idx; 
				while(actToken.level>level) idx++; 
				//skip to next thing. No error checking because validiti is already checked in the hierarchy building process.
				
				if(idx==idx0) throw new Exception("Value expected"); 
				
				if(isOp!'}') break; //"}" at the end
				
				if(!isOp!',') throw new Exception(`"}" or "," expected.`); 
				idx++; 
			}
			if(log) writeln; 
			
			return elementMap; 
		} 
		
		alias T = Unqual!Type; 
		
		try {
			 //the outermost exception handler calls state.onError
			
			//switch all possible types
			static if(isFloatingPoint!T)
			{
				getSign; 
				data = cast(Type)(actToken.data.get!double); 
				if(isNegative) data = -data; 
			}
			else static if(is(T == enum))
			{
				const s = actToken.data.get!string.jsonFieldToIdentifier; 
				data = ((s=="")?(Type.min):(s.to!Type)); 
			}
			else static if(isIntegral!T)
			{
				getSign; 
				
				try { data = actToken.data.get!long .to!Type; }
				catch(Exception)	{ data = actToken.data.get!ulong.to!Type; }
				
				if(isNegative) data = cast(typeof(data))(-data); 
				
				//slow workaround: data = ((isNegative ? "-" : "")~actToken.source).to!Type;
				
				//previous version had a bug.
				/+
					try{
					
						//static if(is(T == ulong)) auto L = actToken.data.get!ulong;
																 else auto L = actToken.data.get!long;
						//if(isNegative) L = -L;
						//data = L.to!Type;*/
						//this also has a bug.
						UL = actToken.data.get!ulong; //variant fails at long - ulong shit.
					}catch(Exception e){
						LOG("DECODING LONG END", actToken, actToken.data, Type.stringof, isNegative, e.simpleMsg);
						throw e;
					}
				+/
				
				//Todo: fix this variant long/ulong bug
				/+
					void variantError(){
						import std.variant;
						Variant v;
						v = "36290379465".to!long;
						v.get!long.print; //good
						v.get!ulong.print; //bad: Variant: attempting to use incompatible types long and ulong
					}
				+/
			}
			else static if(isSomeString!T)
			{ data = actToken.data.get!string.to!Type; }
			else static if(isSomeChar!T)
			{
				dstring s = actToken.data.get!string.to!dstring; 
				if(s.length!=1) throw new ConvException("Expecting 1 char only."); 
				data = s[0].to!Type; 
			}
			else static if(is(T == bool))
			{
				if(actToken.kind.among(TokenKind.literalInt, TokenKind.literalFloat))
				data = actToken.data != 0; 
				else if(actToken.isKeyword(kwfalse))	data = false; 
				else if(actToken.isKeyword(kwtrue))	data = true; 
				else	throw new ConvException(`Invalid bool value`); 
			}
			else static if(isVector!T)
			{
				streamDecode_json(state, idx, data.components); //just forward reading the field: Vector.components
			}
			else static if(isMatrix!T)
			{
				streamDecode_json(state, idx, data.columns); //just forward it to its internal array
			}
			else static if(isAggregateType!T)
			{
				//Struct, Class
				//handle null
				if(actToken.isKeyword(kwnull))
				{
					static if(is(T == class))
					{
						 //null class found
						data = null; //can free by the GC
					}
					else
					{
						data = T.init; //if it's a struct, reset it
						/+
							Todo: Need an own struct initializer because assignment doesn't work: 
							"cannot modify strict instance 'data' of type ... because it contains 'const' or 'immutable' members.
						+/
					}
					return; //nothing else to expect after null
				}
				
				auto oldIdx = idx; 
				auto elementMap = extractElements; 
				//Opt: with inherited classes it seeks twice. If the tokenizer would be hierarchical then it wouldn't take any time to extract.
				
				idx = oldIdx; //keep idx on the class instance,
				
				//handle null for class
				
				static if(is(T == class))
				{
					{
						//create a new instance with the default creator if needed
						//Todo: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
						//Ezt at kell gondolni es a linkelt classt is meg kell tudni csinalni
						
						//peek className   "class" : "name"
						auto className = peekClassName(elementMap),
								 p = className in classFullNameMap,
								 classFullName = p ? *p : "",
								 currentClassFullName = data !is null ? typeid(data).to!string : ""; 
						
						//Todo: error handling when there is no classloader for the class in json
						
						/+
							print("className in Json:", className); 
							print("Trying to load class:", classFullName); 
							print("Currently in Loader:", fullyQualifiedName!Type); 
							print("Current Instance:", currentClassFullName); 
							print("data1:", data); 
						+/
						
						//call a different loader if needed
						if(classFullName.length && fullyQualifiedName!Type != classFullName)
						{
							//print("Calling appropriate loader", classFullName);
							
							//Todo: ezt felvinni a legtetejere es megcsinalni, hogy csak egyszer legyen a tipus ellenorizve
							//Todo: Csak descendant classok letrehozasanak engedelyezese, kulonben accessviola
							
							auto fv = classLoaderFunc[classFullName]; //Opt: inside here, elementMap is extracted once more
							fv(state, idx, &data); 
							return; 
						}
						
						//free if the class type is different.
						if(data !is null && classFullName.length && currentClassFullName != classFullName) { data.destroy; }
						
						
						//create only if original is null
						if(data is null) {
							static assert(
								__traits(compiles, new Type), 
								i"fromJson(): Class $(Type.stringof) must have this() to be loaded.".text
							); 
							/+Todo: This can't load nested classes.  Not a big problem, but it can't.+/
							data = new Type; 
						}
					}
				}
				
				//recursive call for each field
				void loadFields(bool checkIgnoredFields)()
				{
					static if(checkIgnoredFields) bool[string] usedFields; 
					
					static foreach(fieldName; FieldAndFunctionNamesWithUDA!(T, STORED, true))
					{
						{
							
							
							version(/+$DIDE_REGION Dirty fix for LDCXJSON reading. (not writing)+/all)
							{
								/+Todo: Make this for writing json too+/
								/+
									enum reservedWords = ["in", "out", "init", "default", "align", "alias", "char"]; 
									enum fn = ((fieldName.among(aliasSeqOf!(reservedWords.map!((a)=>(a~'_')))))?(fieldName[0..$-1]) :(fieldName)); 
								+/
								enum fn = fieldName; 
							}
							
							
							
							if(auto p = fn in elementMap)
							{
								alias member 	= __traits(getMember, data, fieldName); 
								/+Note: !!! alias is NOT good for __traits code generation, it can only hold types.+/
								
								static if(isFunction!member)
								{
									//@property setter
									//it not modifies the existing property, it cretes new data.
									version(/+$DIDE_REGION+/none) {
										/+Note: Old version: This is not working with both setter & getter.+/
										alias MT = Parameters!member; 
										static if(MT.length==1)
										{
											Unqual!(MT[0]) tmp; streamDecode_json(state, *p, tmp); 
											//__traits(getMember, data, fieldName) = tmp; 
											mixin("data.", fieldName.text, " = tmp;"); 
										}
									}
									
									static foreach(ovl; __traits(getOverloads, data, fieldName))
									{
										static if(Parameters!ovl.length==1)
										{
											/+
												Todo: it is possible to found more than one overloads here, 
												a compiler error should be nice in that case...
											+/
											Unqual!(Parameters!ovl[0]) tmp; streamDecode_json(state, *p, tmp); 
											mixin("data.", fieldName.text, " = tmp;"); 
										}
									}
								}
								else
								{
									//normal field
									streamDecode_json(state, *p, __traits(getMember, data, fieldName)); 
								}
								
								static if(checkIgnoredFields) usedFields[fn] = true; 
							}
						}
					}
					
					static if(__traits(compiles, { data.afterLoad(); } )) data.afterLoad(); 
					
					static if(checkIgnoredFields)
					{
						foreach(e; elementMap.keys)
						if(e !in usedFields)
						if(e != "class"/+Todo: It's problematic.  Class detection only works with MY json...+/)
						WARN(i"Ignored JSON field in module $(state.options.moduleName.quoted): $(e)"); 
						
					}
				} 
				
				if(state.options.checkIgnoredFields)	loadFields!true; 
				else	loadFields!false; 
			}
			else static if(isArray!T)
			{
				 //Array
				
				int cnt=0; //number of imported elements
				
				const level = actToken.level; 
				expect!'['; 
				
				while(1)
				{
					if(isOp!']') break; //"]" right after "," or "["
					
					//skip until the next '}' or ','
					int idx0 = idx; 
					while(actToken.level>level)
					{
						idx++; 
						//skip to next thing. No error checking because validity is already checked in the hierarchy building process.
						assert(idx < state.tokens.length, "Fatal error: something is wrong with discoverJsonHierarchy()"); 
					}
					if(idx==idx0) throw new Exception("Value expected"); 
					
					//when array is too small
					if(cnt>=data.length)
					{
						static if(isDynamicArray!T) {
							data.length = cnt+1; //make room
						}
						else {
							if(state.options.errorHandling==ErrorHandling.raise) { throw new Exception("Static array overflow."); }
							else {
								state.onError("Static array overflow."); //track or ignore
							}
							break; //stop processing when the static array is full, to avoid index overflow
						}
					}
					
					//decode array element
					streamDecode_json(state, idx0, data[cnt]); 
					cnt++; 
					
					if(isOp!']') break; //"]" at the end
					
					if(!isOp!',') throw new Exception(`"]" or "," expected.`); 
					idx++; 
				}
				
				static if(isDynamicArray!T)
				{
					data.length = cnt; 
					//Todo: cut back the array  !!!!!!!!!!!!!!!! what if these are linked classes !!!!!!!!!!!!!!! managed resize array needed
				}
				else
				{
					if(data.length != cnt)
					throw new Exception("Static array size mismatch: %s < %s".format(cnt, data.length)); 
				}
				
			}
			else static if(isAssociativeArray!T)
			{
				//handle null
				if(actToken.isKeyword(kwnull)) {
					data = T.init; 
					return; //nothing else to expect after null
				}
				
				auto elementMap = extractElements; 
				
				alias VT = Unqual!(ValueType!T),
				KT = Unqual!(KeyType!T); 
				
				foreach(k, v; elementMap) {
					VT tmp; 
					streamDecode_json(state, v, tmp); 
					data[k.to!KT] = tmp; 
				}
				
			}
			else static if(isPointer!T)
			{
				//handle null
				if(actToken.isKeyword(kwnull)) {
					data = null; 
					return; //nothing else to expect after null
				}
				
				data = new PointerTarget!T; 
				streamDecode_json(state, idx, *data); 
			}
			else static assert(0, "Unhandled type: "~T.stringof); 
			
		}
		catch(Exception t) { state.onError(t.msg, idx); }
	} 
	
	
	//! toJson ///////////////////////////////////
	string toJson(Type)(
		in Type data, 
		bool dense=false, bool hex=false, bool omitZeroes=false, string thisName=""
	) 
	{
		string st; 
		streamAppend_json!(Type)(st, data, dense, hex, omitZeroes, thisName); 
		return st; 
	} 
	
	void streamAppend_json(Type)(
		ref string st, /*!!!!!*/in Type data,
		bool dense=false, bool hex=false, bool omitZeroes=false, string thisName="", string indent=""
	) 
	{
		alias T = Unqual!Type; 
		
		//call dynamic class writer. For example Type==Property and the actual class in data is StringProperty
		static if(is(T == class))
		{
			if(data !is null)
			{
				const currentFullName = typeid(data).to!string; //Todo: try to understand this
				if(currentFullName != fullyQualifiedName!T)
				{
					 //use a different writer if needed
					auto p = currentFullName in classSaverFunc; 
					if(p)	{
						(*p)(st, /*!!!!!*/cast(void*) data, dense, hex, thisName, indent); 
						return; 
					}
					else	{
						//Todo: error if there is no classSaver, throw error
						raise(
							"toJson: unregisteded inherited class. Must call registerStoredClass!%s"
							.format(currentFullName)
						); 
					}
				}
			}
		}
		
		//append ',' and newline(dense only) if needed
		{
			//get the last symbol before any whitespace
			char lastSymbol; 
			auto s = st.stripRight; 
			if(s.length) lastSymbol = s[$-1]; 
			//Todo: this is unoptimal, but at least safe. It is possible to put this inside the [] and {} loop.
			
			const needComma = !lastSymbol.among('{', '[', ',', ':', '\xff'); 
			//ff is empty stream, no comma needed
			
			if(dense) { if(needComma) st ~= ","; }else {
				if(needComma) st ~= ",\n"; 
				st ~= indent; 
			}
		}
		
		//append the associative name if there is one
		if(thisName!="")
		st ~= quoted(thisName)~(dense ? ":" : ": "); 
		 
		//switch all possible types
		static if(isFloatingPoint!T)	{ st ~= data.text_precise; }
		else static if(is(T == enum))	{ st ~= quoted(data.text.identifierToJsonField); }
		else static if(isIntegral!T)	{ if(hex) st ~= format!"0x%X"(data); else st ~= data.text; }
		else static if(isSomeString!T)	{ st ~= quoted(data); }
		else static if(isSomeChar!T)	{ st ~= quoted(data.text); }
		else static if(is(T == bool))	{ st ~= data ? "true" : "false"; }
		else static if(isVector!T)	{ streamAppend_json(st, data.components, dense || true, hex, omitZeroes, "", indent); }
		else static if(isMatrix!T)	{ streamAppend_json(st, data.columns   , dense || true, hex, omitZeroes, "", indent); }
		else static if(isAggregateType!T)
		{
			//Struct, Class
			//handle null for class
			static if(is(T == class)) { if(data is null) { st ~= "null"; return; }}
			
			static if(__traits(compiles, { (cast()data).beforeSave(); } ))
			{
				(cast()data).beforeSave(); //Todo: this violates constness.
			}
			
			st ~= dense ? "{" : "{\n";                  //opening bracket {
			const nextIndent = dense ? "" : indent~"  "; 
			
			static if(is(T == class))
			{
				 //write class type name
				string s = T.stringof; 
				streamAppend_json(
					st, s, dense, hex, omitZeroes, 
					"class"/+'class' in the json, exactly.+/, nextIndent
				); 
			}
			
			//recursive call for each field
			static foreach(fieldName; FieldAndFunctionNamesWithUDA!(T, STORED, true))
			{
				{
					enum hasHex = hasUDA2!(__traits(getMember, T, fieldName), HEX); 
					enum jsonField = fieldName.identifierToJsonField; 
					static if(__traits(compiles, { auto a = __traits(getMember, data, fieldName); }))
					{
						static bool chkNonZero(T)(in T a)
						{
							static if(isIntegral!T || isFloatingPoint!T || isPointer!T || isVector!T) return !!a; 
							else static if(isDynamicArray!T || isAssociativeArray!T) return !a.empty; 
							else return true; 
						} 
						
						if(!omitZeroes || chkNonZero(__traits(getMember, data, fieldName)))
						{
							streamAppend_json(
								st, __traits(getMember, data, fieldName),
								dense, hex || hasHex, omitZeroes, jsonField, nextIndent
							); 
						}
					}
					else {/+static assert(0, "Unable to read property. (Maybe it's not const!)"); +/}
				}
			}
			
			st ~= dense ? "}" : "\n"~indent~"}";        //closing bracket }
		}
		else static if(isArray!T)
		{
			 //Array
			if(data.empty) { st ~= "[]"; return; }
			
			st ~= dense ? "[" : "[\n";                  //opening bracket [
			const nextIndent = dense ? "" : indent~"  "; 
			
			const actHex = hex || hasUDA!(data, HEX); 
			foreach(const val; data)
			streamAppend_json(st, val, dense, actHex, omitZeroes, "", nextIndent); 
			
			st ~= dense ? "]" : "\n"~indent~"]";        //closing bracket ]
		}
		else static if(isAssociativeArray!T)
		{
			 //Associative array
			if(data.empty) { st ~= "null"; return; }
			
			st ~= dense ? "{" : "{\n";                  //opening bracket {
			const nextIndent = dense ? "" : indent~"  "; 
			
			foreach(k, ref v; data)
			streamAppend_json(st, v, dense, hex, omitZeroes, k.text, nextIndent); 
			
			st ~= dense ? "}" : "\n"~indent~"}";        //closing bracket }
		}
		else static if(isPointer!T)
		{
			/+optional field+/
			if(data)	streamAppend_json(st, *data, dense, hex, omitZeroes); 
			else	st ~= "null"; 
		}
		else
		{ static assert(0, "Unhandled type: "~T.stringof); }
	} 
	
	
	version(/+$DIDE_REGION jsonPacket+/all)
	{
		
		/+
			Note: jsonPacket is a dense json object.
			It starts with: /+Code: "signature":+/
			It ends with: /+Code: "\n"+/  new line character.
		+/
		
		string jsonPacket(T, string signature=T.stringof)(in T data)
		{
			enum hdr = signature.quoted ~ ':'; 
			return hdr ~ data.toJson(true/+dense+/) ~ '\n'; 
		} 
		
		T fetchJsonPacket(T, string signature=T.stringof)(ref ubyte[] stream)
		{
			enum hdr = signature.quoted ~ ':'; 
			
			enforce(stream.startsWith(hdr), format!"Can't fetch JsonPacket %s"(signature.quoted)); 
			
			const endIdx = stream[hdr.length..$].countUntil('\n'); 
			enforce(endIdx>=0, format!"Corrupt JsonPacket %s"(signature.quoted)); 
			
			T res; res.fromJson(cast(string) stream[hdr.length..hdr.length+endIdx]); 
			stream = stream[hdr.length+endIdx+1 .. $]; 
			
			return res; 
		} 
	}
	
	//tests /////////////////////////////////////////////////
	
	private void unittest_JsonClassInheritance()
	{
		static class A { int id; } 
		static class B:A { string bStr; } 
		static class C:A { string cStr;  } 
		
		registerStoredClass!A; 
		registerStoredClass!B; 
		registerStoredClass!C; 
		
		A[] arr; 
		{ auto a = new A; a.id = 9; 	arr ~= a; }
		{ auto b = new B; b.id = 1; b.bStr = "b"; 	arr ~= b; }
		{ auto c = new C; c.id = 2; c.cStr = "c"; 	arr ~= c; }
		arr ~= null; 
		
		auto json1 = arr.toJson; 
		arr.clear; 
		arr.fromJson(json1); 
		auto json2 = arr.toJson; 
		
		//json1.print; json2.print;
		
		assert(json1 == json2, "fromJson inherited classes fail."); 
	} 
	
	private void unittest_toJson()
	{
		//check formatting of 2d arrays
		assert([[1,2],[3,4]].toJson(true) == "[[1,2],[3,4]]"); 
		assert([[1,2],[3,4]].toJson(false) == "[\n  [\n    1,\n    2\n  ],\n  [\n    3,\n    4\n  ]\n]"); 
		assert(mat2(1,2,3,4).toJson(false) == [[1,2],[3,4]].toJson(true)); 
	} 
	
	//! clearFields /////////////////////////////////////////
	
	void clearFields_defaults(Type)(auto ref Type data)
	if(is(Type==class) || __traits(isRef, data)) //only let classes not to be references  (auto ref template parameter)
	{
		static if(is(Type==class)) if(data is null) return; //ignore empty null instances
		
		static string savedData = "\0"; //Todo: use binaryJson
		if(savedData=="\0") {
			static Type temp; 
			static if(is(Type==class)) temp = new Type; 
			savedData = temp.toJson; 
			
			print("Generate defaults for ", Type.stringof, "\n", savedData); 
		}
		
		data.fromJson(savedData); 
	} 
	
	
	
	version(/+$DIDE_REGION Properties+/all)
	{
		
		class Property
		{
			@STORED {
				string name, caption, hint, unit; 
				bool isReadOnly; 
			} 
			
			bool uiChanged; //stdUi sets this to true
			//Todo: would be better to save the last value, than update this (and sometimes forget to update)
			
			string asText()
			{ return ""; } 
			string asDecl()
			{ return format!"Property %s;"(name); } 
		} 
		
		class StringProperty : Property
		{
			shared static this()
			{ registerStoredClass!(typeof(this)); } 
			
			@STORED {
				string act, def; 
				string[] choices; 
			} 
			
			override string asText()
			{ return act; } 
			
			override string asDecl()
			{
				auto s = "@STORED string "~name; 
				if(def!=string.init) s ~= " = "~def.quoted; 
				s ~= ";"; 
				if(choices.length) s ~= format!" enum %s_choices = %s;"(name, choices); 
				s ~= "\n"; 
				return s; 
			} 
			
		} 
		
		class IntProperty : Property
		{
			shared static this()
			{ registerStoredClass!(typeof(this)); } 
			
			@STORED int act, def, min, max, step=0; 
			
			override string asText()
			{ return act.text; } 
			
			override string asDecl()
			{
				auto s = "@STORED int "~name; 
				if(def) s ~= " = "~def.text; 
				s ~= ";\n"; 
				if(min || max) s = format!"@RANGE(%s, %s) %s"(min, max, s); 
				if(step) s = format!"@STEP(%s) %s"(step, s); 
				return s; 
			} 
		} 
		
		class FloatProperty : Property
		{
			shared static this()
			{ registerStoredClass!(typeof(this)); } 
			
			@STORED float act=0, def=0, min=0, max=0, step=0; 
			
			override string asText()
			{ return act.text; } 
			
			override string asDecl()
			{
				auto s = "@STORED float "~name; 
				s ~= " = "~def.text; 
				s ~= ";\n"; 
				if(min || max) s = format!"@RANGE(%g, %g) %s"(min, max, s); 
				if(step) s = format!"@STEP(%g) %s"(step, s); 
				return s; 
			} 
		} 
		
		class BoolProperty : Property
		{
			shared static this()
			{ registerStoredClass!(typeof(this)); } 
			
			@STORED bool act, def; 
			
			override string asText()
			{ return act.text; } 
			
			override string asDecl()
			{
				auto s = "@STORED bool "~name; 
				if(def) s ~= " = "~def.text; 
				s ~= ";\n"; 
				return s; 
			} 
		} 
		
		class PropertySet : Property
		{
			shared static this()
			{ registerStoredClass!(typeof(this)); } 
			
			@STORED Property[]
			properties; 
			
			override string asText()
			{ return ""; } 
			
			override string asDecl()
			{
				auto s = "struct _T"~name~" {\n"~
					properties.map!(a => "  "~a.asDecl).join~
					"}\n"~
					"@STORED _T"~name~" "~name~";\n"; 
				return s; 
			} 
			
			//copy paste from propArray --------------------------------------------------
			bool empty()
			{ return properties.empty; } 
			
			auto access(T=void, bool mustExists=true)(string name)
			{
				static if(is(T==void))	alias PT = Property; 
				else static if(is(T : Property))	alias PT = T; 
				else	mixin("alias PT = ", T.stringof.capitalize ~ "Property;"); 
				
				auto p = cast(PT)findProperty(properties, name); 
				static if(mustExists) enforce(p !is null, format!`%s not found: "%s"`(PT.stringof, name)); 
				return p; 
			} 
			
			auto get(T=void)(string name)
			{ return access!(T, false)(name); } 
			
			bool exists(string name)
			{ return get(name) !is null; } 
			//end of copy paste ----------------------------------------------------------
			
			void toStruct(T, bool reverse=false)(ref T data)
			{
				static foreach(fieldName; FieldAndFunctionNames!T)
				{
					{
						auto p = access!(mixin("typeof(T."~fieldName~")"), true)(fieldName); 
						static if(!reverse) mixin("data."~fieldName~" = p.act;"); 
						else	mixin("p.act = data."~fieldName~";"); 
					}
				}
			} 
			
			void fromStruct(T)(ref T data)
			{ toStruct!(T, true)(data); } 
		} 
		
		void expandPropertySets(char sep='.')(ref Property[] props)
		{
			 //creates propertySets from properties named like "set.name"
			Property[] res; 
			PropertySet[string] sets; 
			
			foreach(prop; props)
			{
				auto dir = prop.name.getFirstDir!sep; 
				
				if(dir.length)
				{
					auto set = dir in sets;  //Todo: associativearray.update
					if(!set) {
						auto ps = new PropertySet; 
						ps.name = dir; 
						res ~= ps; 
						sets[dir] = ps; 
						set = dir in sets; 
					}
					set.properties ~= prop; 
				}
				else
				{ res ~= prop; }
				
				prop.name = prop.name.withoutFirstDir!sep; 
			}
			
			//apply recursively
			foreach(ps; sets.values)
			ps.properties.expandPropertySets!sep; 
			
			props = res; 
		} 
		
		string[] getPropertyValues(string filter = "true")(Property[] props, string rootPath="")
		{
			string[] res; 
			foreach(a; props)
			{
				auto fullName = join2(rootPath, ".", a.name); 
				if(auto ps = cast(PropertySet)a)	{ res ~= getChangedPropertyValues(ps.properties, fullName); }
				else	{ if(mixin(filter)) { res ~= fullName ~ '=' ~ a.asText; }}
			}
			return res; 
		} 
		
		Property findProperty(Property[] props, string nameFilter, string rootPath="")
		{
			foreach(a; props)
			{
				auto fullName = join2(rootPath, ".", a.name); 
				if(fullName.isWild(nameFilter)) return a; 
				if(auto ps = cast(PropertySet)a) {
					auto res = ps.properties.findProperty(nameFilter, fullName); 
					if(res) return res; 
				}
			}
			return null; 
		} 
		
		
		Property[] findProperties(Property[] props, string nameFilter, string rootPath="")
		{
			Property[] res; 
			foreach(a; props) {
				auto fullName = join2(rootPath, ".", a.name); 
				if(fullName.isWild(nameFilter)) res ~= a; 
				if(auto ps = cast(PropertySet)a)
				res ~= ps.properties.findProperties(nameFilter, fullName); 
			}
			return res; 
		} 
		
		
		string[] getChangedPropertyValues(Property[] props, string rootPath="")
		{ return getPropertyValues!"chkClear(a.uiChanged)"(props, rootPath); } 
		
		
		struct PropArray
		{
			 //PropArray ////////////////////////////////////////////
			string queryName; //name of the
			Property[] props; 
			string pendingQuery; //url of changed settings
			
			bool pending() { return !pendingQuery.empty; } 
			void clear() { props.clear; pendingQuery = ""; } 
			
			bool empty() { return props.empty; } 
			
			auto access(T=void, bool mustExists=true)(string name)
			{
				static if(is(T==void))	alias PT = Property; 
				else static if(is(T : Property))	alias PT = T; 
				else	mixin("alias PT = ", T.stringof.capitalize ~ "Property;"); 
				
				auto p = cast(PT)findProperty(props, name); 
				static if(mustExists) enforce(p !is null, format!`%s not found: "%s"`(PT.stringof, name)); 
				return p; 
			} 
			
			auto get(T=void)(string name)
			{ return access!(T, false)(name); } 
			
			auto get(string name, string def)
			{
				auto p = get(name); 
				if(p is null) return def; 
				return p.asText; 
			} 
			
			//Todo: getDef is a bad name. Should be combined with normal get()
			auto getDef(string name, string def)
			{
				if(auto p = get(name)) return p.asText; 
				return def; 
			} 
			
			auto getDef(string name, int def)
			{
				if(auto p = get(name)) try { return p.asText.to!int; }catch(Exception) {}
				return def; 
			} 
			
			bool exists(string name)
			{ return get(name) !is null; } 
			
			void update()
			{
				if(queryName=="") ERR("Unspecified queryname"); 
				
				auto s = props.getChangedPropertyValues; 
				if(s.length) {
					auto q = queryName~"?"~s.join("&"); 
					mergeUrlParams(pendingQuery, q); 
				}
			} 
			
			string fetchPendingQuery()
			{
				auto res = pendingQuery; 
				pendingQuery = ""; 
				return res; 
			} 
		} 
	}
	
	//! Archiver //////////////////////////////////////////////////////
	
	
	/+
		//cache data to files /////////////////////////////////
		
		T cache(T)(lazy T data, File file, bool refresh=false)
		{
			T res;
			if(refresh) file.remove;
			
			if(file.exists) {
				try {
					string s = file.read.uncompress.to!string;
					res.fromJson(s, "", ErrorHandling.raise);
					LOG("Cache loaded:", file);
					//res.toJson.saveTo(file.otherExt(".txt"));
					return res;
				}
				catch(Exception e)
				{
					WARN("Cache error:", file, e.extendedMsg/+e.simpleMsg+/);
					file.remove;
				}
			}
			
			res = data;
			res.toJson.compress.saveTo(file);
			LOG("Cache recalculated:", file);
			return res;
		}
	+/
	
	void unittest_property_inherited()
	{
		
		static class C1
		{
			int a; 
			@STORED int i; 
			@STORED @property {
				auto p() const { return a+100; } void p(int v) { a = v-100; } 
				auto q() const { return a+100; } void q(int v) { a = v-100; } 
			} 
			@STORED int j; 
		} 
		
		static class C2:C1
		{
			@STORED {
				int b, c; 
				@property {
					auto s() const { return a+100; } void s(int v) { a = v-100; } 
					auto t() const { return a+100; } void t(int v) { a = v-100; } 
					auto u() const { return a+100; } void u(int v) { a = v-100; } 
				} 
			} 
		} 
		
		auto c1 = new C1, c2 = new C2; 
		
		print(FieldNamesWithUDA!(C1, STORED, true).stringof); 
		print(FieldNamesWithUDA!(C2, STORED, true).stringof); 
		print(FieldNamesWithUDA!(DateTime, STORED, true).stringof); 
		print(FieldAndFunctionNamesWithUDA!(C1, STORED, true).stringof); 
		print(FieldAndFunctionNamesWithUDA!(C2, STORED, true).stringof); 
		print(FieldAndFunctionNamesWithUDA!(DateTime, STORED, true).stringof); 
		
		print(c1.toJson); 
		print(c2.toJson); 
		c2.u = 555; 
		string saved = c2.toJson; 
		print(c2.toJson); 
		
		registerStoredClass!C2; 
		
		C1 d = new C2; (cast(C2)d).u = 1000; 
		C1 tmp; 
		tmp.fromJson(d.toJson); 
		tmp.toJson.print; 
	} 
	
	//Unittest //////////////////////////////////////////////////////
	
	void unittest_stream()
	{
		//Todo: more tests!
		unittest_JsonClassInheritance; 
		unittest_toJson; 
		unittest_property_inherited; 
		
		//check the precision of jsonized vectors
		foreach(T; AliasSeq!(float, double, real)) {
			auto v = vec3(1,2,3)*T(PI); 
			auto s = v.toJson; 
			Vector!(T, 3) v2; v2.fromJson(s); 
			//print(v, s, v2);
			assert(v2 == v); 
		}
	} 
	
	
	
	version(/+$DIDE_REGION to/from Bin+/none)
	{
		/+
			Note: It doesn't read unaligned padding.
			It also doesn't reads non-STORED fields.
			Generally we're not writing unaligned stuff onto the HDD, rather making 
			the read operation slower.
			If a struct is opaque, then it is possible to do optimized reads. But that
			is an optional opportunity for speedup.
		+/
		
		void toBin(T)(ref T data, ref ubyte[] stream)
		{ ioBin!false(data, stream); } 
		
		void fromBin(T)(ref T data, ref ubyte[] stream)
		{ ioBin!true(data, stream); } 
		
		void ioBin(bool read, T)(ref T data, ref ubyte[] stream)
		{
			static if(isScalarType!T)
			{
				static if(read)
				{
					data = *(cast(T*) stream[0..T.sizeof].ptr); 
					stream = stream[T.sizeof..$]; 
				}
				else
				{ stream ~= (cast(ubyte*)(&data))[0..T.sizeof]; }
			}
			else static if(isStaticArray!T)
			{
				//Opt: if the element is opaque, read it fast! ->isFixedSizeOpaqueType
				foreach(ref a; data[])
				a.ioBin!read(stream); 
			}
			else static if(is(T==struct))
			{
				alias Fields = T.tupleof; 
				static if(allSatisfy!(templateNot!(isStoredField), Fields))
				alias StoredFields = Fields; 
				else
				alias StoredFields = Filter!(isStoredField, Fields); 
				
				//Opt: if it's an opaque struct, read it fast! ->isFixedSizeOpaqueType
				static foreach(F; StoredFields)
				mixin("data.", F.stringof).ioBin!read(stream); 
			}
		} 
		
		void test_fromBin()
		{
			//Todo: this test requires an extra file from outside.
			
			struct ModSample
			{
				align(1): 
				char[22] name; 
				ushort length2; 
				ubyte tune, volume; 
				ushort loopStart2, loopLength2; 
			} 
			
			struct ModCell
			{
				align(1): 
				ushort instrPeriod; 
				ubyte instrEffect, special; 
			} 
			
			struct ModFile
			{
				align(1): 
				@STORED
				{
					char[20] title; 
					ModSample[31] samples; 
					ubyte songLength, songRestart; 
					ubyte[128] patternSequence; 
					char[4] ID; 
				} 
				
				ModCell[][][] patterns; 
				
				void ioBin(bool read)(ref ubyte[] stream)
				{
					.ioBin!read(this, stream); 
					
					LOG(ID.text); 
				} 
			} 
			
			
			auto raw = `c:\dl\krakout-chip.mod`.File.read(true); 
			ModFile mod, mod2; 
			mod.fromBin(raw); 
			mod.toJson.print; 
			
			ubyte[] raw2; mod.toBin(raw2); 
			mod2.fromBin(raw2); 
			mod2.toJson.print; 
		} 
	}
	
	version(/+$DIDE_REGION Struct Import+/all)
	{
		private string injectFQNInitializer(string fqn)
		{
			auto parts = fqn.split('.'); 
			parts[$-1] = "init."~parts[$-1]; 
			return parts.join('.'); 
		} 
		//Todo: This FQN shit only works for global structs.
		
		/+
			Todo: FieldDef.def is not working yet.
			Because the following mixin can't use symbols from other modules.
			/+
				Code: enum 
				fieldInitText	(alias Field) = Field.init.text,
				structFieldInitText	(alias Field) = mixin(fullyQualifiedName!Field.injectFQNInitializer).text,
				nonDefaultStructFieldInitText	(alias Field) = structFieldInitText!Field == fieldInitText!Field ? "" : structFieldInitText!Field; 
			+/
		+/
		
		struct FieldDef
		{
			string name, type/+, def+/; 
			uint offset, size; 
		} 
		
		enum fieldDefOf(alias Field) = FieldDef(
			Field.stringof, 
			typeof(Field).stringof,
			/+nonDefaultStructFieldInitText!Field,+/
			Field.offsetof, 
			Field.sizeof
		); 
		
		struct StructDef
		{
			string name; 
			uint size; 
			FieldDef[] fieldDefs; 
			
			bool valid() const
			{ return !fieldDefs.empty; } 
		}  
		
		enum structDefOf(alias Struct) = StructDef(
			Struct.stringof, 
			Struct.sizeof, 
			[staticMap!(fieldDefOf, StoredFields!Struct)]
		); 
		
		alias FieldConvertFunct = void function(void* src, void* dst); 
		
		struct FieldImportOperation
		{
			uint srcOfs, dstOfs, size; 
			FieldConvertFunct convert; //null -> it's a raw memory copy
			
			void execute(void* src, void* dst)
			{
				if(convert)	convert(src+srcOfs, dst+dstOfs); 
				else	dst[srcOfs .. srcOfs+size] = src[dstOfs .. dstOfs+size]; 
			} 
		} 
		
		void standardFieldConvertFunct(Src, Dst)(void* src, void* dst)
		{
			auto 	s = cast(Src*) src,
				d = cast(Dst*) dst; 
			
			*d = (*s).to!Dst; 
			//it can throw, but then it writes nothing, keeps the default.
		} 
		
		struct StructImporter
		{
			StructDef srcStructDef, dstStructDef; 
			
			FieldImportOperation[] operations; 
			
			this(StructDef srcStructDef, StructDef dstStructDef, FieldConvertFunct[string] fieldConvertFuncts)
			{
				this.srcStructDef = srcStructDef; 
				this.dstStructDef = dstStructDef; 
				
				//LOG(format!"Generating StructImporter for: %s -> %s"(srcStructDef.name, dstStructDef.name)); 
				
				foreach(df; dstStructDef.fieldDefs)
				foreach(sf; srcStructDef.fieldDefs)
				if(df.name==sf.name)
				{
					if(df.type==sf.type && df.size==sf.size)
					{ operations ~= FieldImportOperation(sf.offset, df.offset, df.size); }
					else
					{ NOTIMPL("Data conversions with fieldConvertFunct"); }
					break; 
				}
			} 
			
			void execute(void* src, void* dst)
			{
				foreach(ref op; operations)
				op.execute(src, dst); 
			} 
		} 
		
		ref structImporter(StructDef srcStructDef, StructDef dstStructDef, FieldConvertFunct[string] fieldConvertFuncts=null)
		{
			const hash = hashOf(srcStructDef, hashOf(dstStructDef)); 
			synchronized
			{
				__gshared StructImporter[ulong] cache; 
				if(auto a = hash in cache) return *a; 
				
				cache[hash] = StructImporter(srcStructDef, dstStructDef, fieldConvertFuncts); 
				return cache[hash]; 
			} 
		} 
		
		template Structize(T)
		{
			static if(is(T==struct))	alias Structize=T; 
			else	struct Structize { T _; alias _ this; } 
		} 
		
		struct KeyValueDef
		{
			StructDef keyDef, valueDef; 
			
			bool valid() const
			{ return keyDef.valid && valueDef.valid; } 
		} 
		
		enum keyValueDefOf(alias K, alias V) = KeyValueDef(
			structDefOf!(Structize!K),
			structDefOf!(Structize!V)
		); 
		
		auto importKeyValues(K, V, V_default=void)(ubyte[] stream, ref K[] keys, ref V[] values)
		{
			enforce(keys.length==values.length, "Key/Value array size mismatch."); 
			
			alias raw = stream; 
			
			enum dstDef = keyValueDefOf!(K, V); 
			
			static if(is(V_default==void))
			enum defaultSrcDef = KeyValueDef.init; 
			else
			enum defaultSrcDef = keyValueDefOf!(K, V_default); 
			
			//try to read srcDef from the stream.
			auto srcDef = stream.fetchJsonPacket!KeyValueDef.ifThrown(defaultSrcDef); 
			
			enforce(srcDef.valid, "Unable to detect key/value stream structure."); 
			
			auto 	keyImporter	= structImporter(srcDef.keyDef, dstDef.keyDef),
				valueImporter 	= structImporter(srcDef.valueDef, dstDef.valueDef); 
			
			//note! it only works with fixed size structs!!!
			//Bug: Check if the structsize is fixed.
			const recordSize = srcDef.keyDef.size + srcDef.valueDef.size; 
			
			for(; raw.length >= recordSize; raw = raw[recordSize .. $])
			{
				try {
					keys.length++; values.length++; 
					//!!!! Fixed size record fetching from raw!
					keyImporter.execute(raw.ptr, &keys.back); 
					valueImporter.execute(raw[srcDef.keyDef.size .. $].ptr, &values.back); 
				}
				catch(Exception e)
				{
					WARN("Struct import error ignored, record skipped: "~e.simpleMsg); 
					keys.length--; //most likely the key increment was successful, so undo that first.
					values.length = keys.length; //then resynchronize the sizes of the arrays.
				}
			}
			
			if(raw.length)
			WARN("Extra garbage at end of Key/Value stream"); 
		} 
		
		private {
			struct _TestImportOldStruct
			{
				align(1) {
					ivec2 size; 
					RGBA avgColor; 
				} 
			} 
			
			struct _TestImportNewStruct
			{
				align(1) {
					ivec2 size2 = ivec2(5, 10); 
					RGBA avgColor; 
					uint 	encoderPos	= uint.max,
						snapshotCounter 	= uint.max; 
				} 
			} 
		} 
		
		void test_importKeyValue()
		{
			//Todo: this test is too specific to karc.
			enum hasFileHeader	= true,
			hasDefaultSpecification 	= true; 
			
			auto raw = `f:\!KarcDataLogs\Karc_C1.2023-06-07T18-15-13Z.main`.File.read(true); 
			if(hasFileHeader) raw = (cast(ubyte[]) keyValueDefOf!(DateTime, _TestImportOldStruct).jsonPacket) ~ raw; 
			
			DateTime[] keys; 
			_TestImportNewStruct[] values; 
			
			static if(hasDefaultSpecification)
			raw.importKeyValues
			!(
				DateTime, _TestImportNewStruct, /+Note: ← Ez a mindenkori legujabb formatum.+/
				_TestImportOldStruct /+
					Note: 	Ez pedig az alapertelmezett formatum, 
					←	ha nincs a file elejere kiirva, akkor ezt hasznalja.
						Ha nincs megadva es nincs formatum a fileban, 
						akkor pedig errort dob.
				+/
			)(keys, values); 
			else
			raw.importKeyValues!(DateTime, _TestImportNewStruct)(keys, values); 
			
			auto aa = assocArray(keys, values); 
			
			aa.keys.each!print; 
			aa.values.each!print; 
			
			keyValueDefOf!(DateTime, _TestImportNewStruct).jsonPacket.print; 
		} 
	}
	
}