module het.dbg;

import het.utils, core.sys.windows.windows, std.regex, std.demangle;

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
}

string makeSrcLocation(string file, string funct, int line)
{
	auto fi = file.split(`\`),
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

void DBG (int level = 10, string file = __FILE__, int line = __LINE__, string funct = __FUNCTION__, T...)(T args)
{
	
	enum location = makeSrcLocation(file, funct, line);
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


///////////////////////////////////////////////////////////////////////////////////

void PING(int index = 0)
{ dbg.ping(index); }
void PING0()
{ PING(0); }void PING1()
{ PING(1); }void PING2()
{ PING(2); }void PING3()
{ PING(3); }
void PING4()
{ PING(4); }void PING5()
{ PING(5); }void PING6()
{ PING(6); }void PING7()
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


//DebugLogClient ////////////////////////////////////////////////////////////////////////////////////

alias dbg = Singleton!DebugLogClient;

//Todo: ha relativ a hibauzenetben a filename, akkor egeszitse ki! hdmd!

class DebugLogClient
{
	//Todo: rewrite it with utils.sharedMemClient
	
	private:
	enum cBufSize = 1<<16; //the same as in DIDE.exe
	
	static struct BreakRec
	{ uint locationHash, state; }
	
	static struct BreakTable
	{
		BreakRec[64] records;
		
		void waitFor(uint locationHash);
	}
	
	static struct Data
	{
		 //raw shared data. Careful with 64/32bit stuff!!!!!!
		uint ping;
		BreakTable breakTable;
		CircBuf!(uint, cBufSize) buf; //CircBuf is a struct, not a reference
		float[potiCount] poti;
		int forceExit;
		int exe_waiting;
		int dide_ack; /+
			exception utan exe_waiting = 1 -> dide ekkor F9-re beleir 1-et 
			az ackba es tovabbmegy az exe. ha -1-et ir az ack-ba, akkor kill.
		+/
		int dide_hwnd; //to call setforegroundwindow
		int exe_hwnd;
	}
	
	static immutable dataFileName = `Global\DIDE_DebugFileMappingObject`;
	HANDLE dataFile;
	Data* data;
	
	void tryOpen()
	{
		
		dataFile = OpenFileMappingW(
			 FILE_MAP_ALL_ACCESS,	 //read/write access
			 false,	 //do not inherit the name
			 dataFileName.toPWChar	 /+name of mapping object+/
		);
		
		data = cast(Data*)MapViewOfFile(
			dataFile,	//handle to map object
			FILE_MAP_ALL_ACCESS, 	//read/write permission
			0,
			0,
			Data.sizeof
		);
		//ensure(data, "DebugLogClient: Can't open mapFile.");
	}
	
	public:
	
	enum potiCount = 8;
	this()
	{
		version(noDebugClient)
		{ return; }else
		{
			tryOpen;
			sendLog("START:"~appFile.toString);
		}
	}
	
	void ping(int index = 0)
	{
		if(!data)
		return;
		data.ping |= 1<<index;
	}
	
	void sendLog(string s)
	{
		if(!data)
		return;
		ubyte[] packet;
		packet.length = 4+s.length;
		*cast(uint*)(packet.ptr) = cast(uint)s.length;
		memcpy(&packet[4], s.ptr, s.length);
		while(!data.buf.store(packet))
		sleep(1);
	}
	
	string getLog()
	{
		 //not needed on exe side. It's needed on dide side. Only for testing.
		if(!data)
		return "";
		
		uint siz;  if(!data.buf.get(&siz, 4))
		return "";
		
		ubyte[] buf;  buf.length = siz;
		
		while(!data.buf.get(buf.ptr, siz))
		sleep(1); //probably an error+deadlock...
		return cast(string)buf;
	}
	
	float getPotiValue(size_t idx)
	{
		if(data && idx>=0 && idx<data.poti.length)
		return data.poti[idx];
		else return 0;
	}
	
	bool isActive()
	{ return data !is null; }
	
	bool forceExit_set()
	{
		if(!data)
		return false; data.forceExit = 1; return true;
	}
	void forceExit_clear()
	{
		if(data)
		data.forceExit = 0;
	}
	bool forceExit_check()
	{
		if(data)
		return data.forceExit!=0;else
		return false;
	}
	
	void handleException(string msg)
	{
		if(!data)
		return;
		
		data.dide_ack = 0;
		data.exe_waiting = 1;
		
		SetForegroundWindow(cast(void*)data.dide_hwnd);
		
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
}
//Todo: Set a unique name to the dbgserver's Shared Memory, and pass it to the launched program.

alias dbgsrv = Singleton!DebugLogServer;

class DebugLogServer
{
	private:
	alias Data = DebugLogClient.Data;
	alias dataFileName = DebugLogClient.dataFileName;
	
	HANDLE dataFile;
	Data* data;
	
	enum pingLedCount = 8;
	int[pingLedCount] pingLedState;
	
	void tryCreate()
	{
		dataFile = CreateFileMappingW(
			INVALID_HANDLE_VALUE,	 //use paging file
			null,	 //default security
			PAGE_READWRITE,	 //read/write access
			0,	 //maximum object size (high-order DWORD)
			Data.sizeof,	 //maximum object size (low-order DWORD)
			dataFileName.toPWChar	 /+dataFileName.toPWChar+/
		);
		
		data = cast(Data*)MapViewOfFile(
			dataFile,	//handle to map object
			FILE_MAP_ALL_ACCESS,	//read/write permission
			0,
			0,
			Data.sizeof
		);
		
		if(!dataFile || !data)
		ERR(`dbgsrv: Could not map create debug fileMapping. Run this as Admin!`);
	}
	
	void updatePingLeds()
	{
		if(!data)
		return;
		
		auto st = data.ping;  data.ping = 0; //latch
		
		foreach(i, ref ps; pingLedState)
		ps = st.getBit(i) ? 255: ps*7 >> 3;
	}
	
	string[] logEvents;
	bool logChanged_;
	
	ubyte[] CircBuf_getLog(ref uint tail, ref uint head, in uint cap, ubyte* buf)
	{
		 //reads a packet from the circbuff
		uint capacity()
		{ return cap; }
		uint length()
		{ return head-tail; }
		uint canGet()
		{ return length; }
		
		uint truncate(uint x)
		{ return x % cap; }
		
		void Move(in void *source, void *destination, uint num)
		{ (cast(ubyte*)destination)[0 .. num][]=(cast(const(ubyte)*)source)[0 .. num]; }
		
		bool get(ubyte* dst, uint dstLen)
		{
			//var i, o, fullLen:cardinal;
			if(dstLen>canGet)
			return false;
			
			uint o = truncate(tail),
						 fullLen = dstLen;
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
		auto res = new ubyte[siz]; //Opt: uninitialized
		auto t0 = now;
		while(!get(res.ptr, siz))
		{
			sleep(1); //probably an error+deadlock...
			if(now-t0>0.1*second)
			{
				flush;
				return [];
			}
		}
		return res;
	}
	
	void processLogMessage(string s)
	{
		logEvents ~= s;
		logChanged_ = true;
		
		if(s.isWild("LOG:*"))
		{
			if(onDebugLog)
			onDebugLog(wild[0]);
		}
		else if(s.isWild("EXCEPTION:*")) {
			if(onDebugException)
			onDebugException(wild[0]);
		}
		else if(s.isWild("START:*")) { clearLog; }
	}
	
	void updateLog()
	{
		if(!data)
		return;
		
		while(1)
		{
			auto d = CircBuf_getLog(data.buf.tail, data.buf.head, data.buf.capacity, data.buf.buf.ptr);
			if(d.empty)
			break;
			
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
	
	public:
	immutable het.math.RGB[pingLedCount] pingLedColors = 
		[0xffffff, 0x00FF00, 0x00FFe0, 0x2020FF, 0xFF2020, 0x00b0FF, 0xb000FF, 0xFFFF00];
	
	void delegate(string) onDebugLog, onDebugException;
	
	this()
	{ tryCreate; }
	
	bool update()
	{
		if(!data)
		return false;
		updatePingLeds;
		updateLog;
		return true; //Todo: only when chg...
	}
	
	string pingLedStateText()
	{ return pingLedState[].enumerate.map!(a => a.value ? a.index.text : "_").join; }
	
	void clearLog()
	{
		logEvents = [];
		logChanged_ = true;
	}
	
	int getLogCount()
	{ return logEvents.length.to!int; }
	string getLogStr(int idx)
	{ return logEvents.get(idx); }
	bool logChanged()
	{ return logChanged_; } //signal to redraw log list
	
	void setPotiValue(int idx, float val)
	{
		if(data && idx.inRange(data.poti))
		data.poti[idx] = val;
	}
	
	void clearExit()
	{ data.forceExit = 0; }
	void forceExit()
	{ data.forceExit = 1; }
	
	void resetBeforeRun()
	{
		if(!data)
		return;
		with(data)
		{
			dide_hwnd = cast(uint)application.handle;
			exe_hwnd = 0;
			forceExit = 0;
			dide_ack = 0;
			exe_waiting = 0;
		}
	}
	
	void forcedStop()
	{
		if(!data)
		return;
		with(data)
		{
			dide_ack = -1;
			forceExit = 1;
			exe_waiting = 0;
			//220429: This is needed when the exe is dead. It resets the IDE *break* state.
		}
	}
	
	bool isExeWaiting()
	{ return data && data.exe_waiting!=0; }
	
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
			ULONG TypeIndex;	/+
				A unique value that identifies the type data that describes the symbol.
				This value does not persist between sessions.
			+/
			ULONG64[2] Reserved;	
			ULONG Index;	/+
				The unique value for the symbol. The value associated with a symbol 
				is not guaranteed to be the same each time you run the process.
			+/
			ULONG Size;	/+
				The symbol size, in bytes	(or bits, if the symbol is a bitfield member).
				For Types it's PDB only.	For Symbols it's the code size.
			+/
			ULONG64 ModBase;	
			ULONG Flags;	
			ULONG64 Value;	
			ULONG64 Address;	
			ULONG Register;	
			ULONG Scope;	/+
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
			PVOID Key;//This member is not used.
			DWORD64 ModBase;
			CHAR[MAX_PATH + 1] Obj;
			CHAR[MAX_PATH + 1] FileName;
			DWORD LineNumber;
			DWORD64 Address;
		}
		
		alias SYM_ENUMMODULES_CALLBACK64 	= extern(Windows) BOOL function(
			in PCSTR ModuleName,
			in ULONG64 BaseOfDll,
			in PVOID UserContext
		),
		SYM_ENUMERATESYMBOLS_CALLBACK 	= extern(Windows) BOOL function(
			in SYMBOL_INFO* pSymInfo,
			in ULONG SymbolSize,
			in PVOID UserContext
		),
		SYM_ENUMLINES_CALLBACK 	= extern(Windows) BOOL function(
			in SRCCODEINFO* LineInfo,
			in PVOID UserContext
		);
		
		enum SYMENUM_OPTIONS_DEFAULT 	= 1,
		SYMENUM_OPTIONS_INLINE	= 2;
		
		struct DbgHelp2
		{
			extern(Windows)
			{
				BOOL function(
					in HANDLE	hProcess,
					SYM_ENUMMODULES_CALLBACK64 	EnumModulesCallback,
					in PVOID	UserContext
				) SymEnumerateModules64;
				BOOL function(
					in HANDLE	hProcess,
					in ULONG64	BaseOfDll,
					in PCSTR	Mask,
					in SYM_ENUMERATESYMBOLS_CALLBACK 	EnumSymbolsCallback,
					in PVOID	UserContext
				) SymEnumSymbols;
				BOOL function(
					in HANDLE	hProcess,
					in ULONG64	BaseOfDll,
					in PCSTR	Mask,
					in SYM_ENUMERATESYMBOLS_CALLBACK 	EnumSymbolsCallback,
					in PVOID	UserContext,
					in DWORD	Options
				) SymEnumSymbolsEx;
				BOOL function(
					in HANDLE	hProcess,
					in ULONG64	Base,
					in PCSTR	Obj,
					in PCSTR	File,
					in DWORD	Line,
					in DWORD	Flags,
					in SYM_ENUMLINES_CALLBACK 	EnumLinesCallback,
					in PVOID	UserContext
				) SymEnumSourceLines;
				BOOL function(
					in	HANDLE	hProcess,
					in	ULONG64	BaseOfDll,
					in	SYM_ENUMERATESYMBOLS_CALLBACK	EnumSymbolsCallback,
					in	PVOID	UserContext
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
						getProcAddress(lib, "SymEnumSymbolsEx", inst.SymEnumSymbolsEx, true);//Note: *
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
			case SymTagEnum.Typedef:	return Typedef;
			case SymTagEnum.Enum:	return Enum;
			case SymTagEnum.UDT:	return UDT;
			case SymTagEnum.Data:	return Data;
			case SymTagEnum.Function:	return Function;
			case SymTagEnum.PublicSymbol:	return Public;
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
			if(blen==0xFF) a.stRead(len);else len = blen;
			
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
		nameOffsets.clear;
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
		BOOL enumModulesProc(in PCSTR ModuleName, in ULONG64 BaseOfDll, in PVOID UserContext)
		{
			DebugInfo.actInstance.addRecord(SymbolType.Module, BaseOfDll, 0, ModuleName.text);
			return true;
		}
		dh2.SymEnumerateModules64(process, &enumModulesProc, null);
		
		if(records.length)
		{
			const mainBase = records[0].addr;
			
			extern(Windows) BOOL enumSymProc(
				in SYMBOL_INFO* pSymInfo, in ULONG SymbolSize, 
				in PVOID UserContext
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
			
			extern(Windows) BOOL enumLineProc(in SRCCODEINFO* LineInfo, in PVOID UserContext)
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
	
}