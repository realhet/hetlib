module het.win;/+DIDE+/

//The next @comment is important: It marks the app as a windowed app.
//@win

version(/+$DIDE_REGION+/all)
{
	
	pragma(lib, "gdi32.lib");
	pragma(lib, "winmm.lib");
	pragma(lib, "opengl32.lib"); //needed for initWglChoosePixelFormat()
	
	public import het.utils, het.geometry, het.inputs;
	
	//moved into utils.application.tick __gshared uint global_tick; //counts in every update cycle
	__gshared size_t global_TPSCnt, TPS; //texture upload bytes /sec
	__gshared size_t global_VPSCnt, VPS; //VBO upload bytes /sec
	
	//het.draw2d
	
	import core.runtime,
	core.sys.windows.windows,
	core.sys.windows.windef,
	core.sys.windows.winuser,
	core.sys.windows.wingdi,
	core.sys.windows.wincon,
	core.sys.windows.mmsystem;
	
	public import core.sys.windows.winuser:
		WS_OVERLAPPED, WS_TILED, WS_MAXIMIZEBOX, WS_MINIMIZEBOX, WS_TABSTOP, WS_GROUP, WS_THICKFRAME,
		WS_SIZEBOX, WS_SYSMENU, WS_HSCROLL, WS_VSCROLL, WS_DLGFRAME, WS_BORDER, WS_CAPTION,
		WS_OVERLAPPEDWINDOW, WS_TILEDWINDOW, WS_MAXIMIZE, WS_CLIPCHILDREN, WS_CLIPSIBLINGS, WS_DISABLED,
		WS_VISIBLE, WS_MINIMIZE, WS_ICONIC, WS_CHILD, WS_CHILDWINDOW, WS_POPUP, WS_POPUPWINDOW,
		WS_EX_ACCEPTFILES, WS_EX_APPWINDOW, WS_EX_CLIENTEDGE, WS_EX_COMPOSITED, WS_EX_CONTEXTHELP, 
		WS_EX_CONTROLPARENT, WS_EX_DLGMODALFRAME, WS_EX_LAYERED, WS_EX_LAYOUTRTL, WS_EX_LEFT, 
		WS_EX_LEFTSCROLLBAR, WS_EX_LTRREADING, WS_EX_MDICHILD, WS_EX_NOACTIVATE, WS_EX_NOINHERITLAYOUT,
		WS_EX_NOPARENTNOTIFY, WS_EX_OVERLAPPEDWINDOW, WS_EX_PALETTEWINDOW, WS_EX_RIGHT, 
		WS_EX_RIGHTSCROLLBAR, WS_EX_RTLREADING, WS_EX_STATICEDGE, 	WS_EX_TOOLWINDOW, WS_EX_TOPMOST, 
		WS_EX_TRANSPARENT, WS_EX_WINDOWEDGE;
	
	
	//use het.bitmap.getDesktopBounds instead!
	//auto desktopRect()	{ RECT r; GetClientRect(GetDesktopWindow, &r); return r; }
	//auto desktopBounds()	{ with(desktopRect) return ibounds2(left, top, right, bottom); }
	
	
	//window info ////////////////////////////////////////////////////////////
	
	string getWindowText(HWND handle)
	{
		wchar[256] buf;
		auto n = GetWindowTextW(handle, buf.ptr, buf.length);
		return buf[0..n].toStr;
	}
	
	string getClassName(HWND handle)
	{
		wchar[256] buf;
		auto n = GetClassNameW(handle, buf.ptr, buf.length);
		return buf[0..n].toStr;
	}
	
	uint getWindowThreadProcessId(HWND handle)
	{
		uint pid;
		GetWindowThreadProcessId(handle, &pid);
		return pid;
	}
	
	struct WindowInfo
	{
		HWND handle;
		string title, className;
		uint pid;
		File file;
	}
	
	auto getWindowInfo(HWND handle)
	{
		//const t0 = QPS;
		
		WindowInfo res;
		res.handle = handle;
		res.title = getWindowText(handle);
		res.className = getClassName(handle);
		res.pid = getWindowThreadProcessId(handle);
		
		if(res.pid)
		if(auto hProc = OpenProcess(0x1000/+PROCESS_QUERY_LIMITED_INFORMATION+/, false, res.pid))
		{
			wchar[256] buf;
			import core.sys.windows.psapi;
			auto n = GetModuleFileNameExW(hProc, null, buf.ptr, buf.length);
			res.file.fullName = buf.toStr;
		}
		
		
		//print(QPS-t0); // .1 ms
		
		return res;
	}
	
	
	//windows message decoding //////////////////////////////////////////////
	
	string winMsgToString(uint msg)
	{
		enum list =
		[
			"CREATE", "DESTROY", "MOVE", "SIZE", "ACTIVATE", "SETFOCUS", "KILLFOCUS",
			"ENABLE", "SETREDRAW", "SETTEXT", "GETTEXT", "GETTEXTLENGTH", "PAINT", "CLOSE",
			"QUERYENDSESSION", "QUIT", "QUERYOPEN", "ERASEBKGND", "SYSCOLORCHANGE",
			"ENDSESSION", "SHOWWINDOW", "CTLCOLORMSGBOX", "CTLCOLOREDIT", "CTLCOLORLISTBOX",
			"CTLCOLORBTN", "CTLCOLORDLG", "CTLCOLORSCROLLBAR", "CTLCOLORSTATIC", "WININICHANGE",
			"SETTINGCHANGE", "DEVMODECHANGE", "ACTIVATEAPP", "FONTCHANGE", "TIMECHANGE",
			"CANCELMODE", "SETCURSOR", "MOUSEACTIVATE", "CHILDACTIVATE", "QUEUESYNC", 
			"GETMINMAXINFO", "ICONERASEBKGND", "NEXTDLGCTL", "SPOOLERSTATUS", "DRAWITEM", 
			"MEASUREITEM", "DELETEITEM", "VKEYTOITEM", "CHARTOITEM", "SETFONT", "GETFONT", 
			"QUERYDRAGICON", "COMPAREITEM", "COMPACTING", "NCCREATE", "NCDESTROY", 
			"NCCALCSIZE", "NCHITTEST", "NCPAINT", "NCACTIVATE", "GETDLGCODE", "NCMOUSEMOVE",
			"NCLBUTTONDOWN", "NCLBUTTONUP", "NCLBUTTONDBLCLK", "NCRBUTTONDOWN",
			"NCRBUTTONUP", "NCRBUTTONDBLCLK", "NCMBUTTONDOWN", "NCMBUTTONUP", 
			"NCMBUTTONDBLCLK", "KEYDOWN", "KEYUP", "CHAR", "DEADCHAR", "SYSKEYDOWN", 
			"SYSKEYUP", "SYSCHAR", "SYSDEADCHAR", "KEYLAST", "INITDIALOG", "COMMAND", 
			"SYSCOMMAND", "TIMER", "HSCROLL", "VSCROLL", "INITMENU", "INITMENUPOPUP", 
			"MENUSELECT", "MENUCHAR", "ENTERIDLE", "MOUSEWHEEL", "MOUSEMOVE", 
			"LBUTTONDOWN", "LBUTTONUP", "LBUTTONDBLCLK", "RBUTTONDOWN", "RBUTTONUP", 
			"RBUTTONDBLCLK", "MBUTTONDOWN", "MBUTTONUP", "MBUTTONDBLCLK", "PARENTNOTIFY", 
			"MDICREATE", "MDIDESTROY", "MDIACTIVATE", "MDIRESTORE", "MDINEXT", "MDIMAXIMIZE", 
			"MDITILE", "MDICASCADE", "MDIICONARRANGE", "MDIGETACTIVE", "MDISETMENU", "CUT", 
			"COPYDATA", "COPY", "PASTE", "CLEAR", "UNDO", "RENDERFORMAT", "RENDERALLFORMATS",
			"DESTROYCLIPBOARD", "DRAWCLIPBOARD", "PAINTCLIPBOARD", "VSCROLLCLIPBOARD", 
			"SIZECLIPBOARD", "ASKCBFORMATNAME", "CHANGECBCHAIN", "HSCROLLCLIPBOARD",
			"QUERYNEWPALETTE", "PALETTEISCHANGING", "PALETTECHANGED", "DROPFILES", "POWER", 
			"WINDOWPOSCHANGED", "WINDOWPOSCHANGING", "HELP", "NOTIFY", "CONTEXTMENU", 
			"TCARD", "MDIREFRESHMENU", "MOVING", "STYLECHANGED", "STYLECHANGING", "SIZING", 
			"SETHOTKEY", "PRINT", "PRINTCLIENT", "POWERBROADCAST", "HOTKEY", "GETICON", 
			"EXITMENULOOP", "ENTERMENULOOP", "DISPLAYCHANGE", "STYLECHANGED", "STYLECHANGING",
			"GETICON", "SETICON", "SIZING", "MOVING", "CAPTURECHANGED", "DEVICECHANGE", 
			"PRINT", "PRINTCLIENT"
		];
		
		static string[uint] map;
		if(map.empty) static foreach(s; list) map[mixin("WM_", s)] = s;
		
		if(auto a = msg in map) return "WM_" ~ *a;
		else return "WM_0x"~format!"%X"(msg);
	}
	
	
	//timeLine //////////////////////////////
	
	struct TimeLine
	{
		
		struct Event
		{
			enum Type
			{ update, beginPaint, paint, endPaint, swapBuffers }
			Type type;
			Time t0, t1;
			
			auto color()
			{
				enum typeColors = [clBlue, clLime, clYellow, clRed, clGray];
				return typeColors[cast(int)type];
			}
		}
		
		private Event[][] groups;
		
		bool isComplete(in Event[] group)
		{
			 //Group Completeness: there must be a paint event at the end.
			return !group.empty && group[$-1].type == Event.Type.max;
		}
		
		void addEvent(Event.Type type, Time t0, Time t1=QPS)
		{
			auto ev = Event(type, t0, t1);
			
			const  newGroup = groups.empty || isComplete(groups[$-1]);
			if(newGroup) groups ~= [ev];
			else groups[$-1] ~= ev;
		}
		
		void restrictSize(int maxGroups)
		{
			const n = maxGroups+1;
			if(n<groups.length) groups = groups[groups.length-n..$];
		}
		
		Event[][] getGroups()
		{
			if(groups.length>1) return groups[0..$-1];
			else return [];
		}
		
	}
	
	
	//MouseCursor /////////////////////////////////////////////////////////////////////
	
	enum MouseCursor {
		ARROW, IBEAM, WAIT, CROSS, UPARROW, /+SIZE, ICON,+/ 
		SIZENWSE, SIZENESW, SIZEWE, SIZENS, SIZEALL, NO, HAND, APPSTARTING, HELP
	}
	
	private void SetCursor(MouseCursor c)
	{
		immutable _cursorIds = mixin("[", [EnumMembers!MouseCursor].map!`"IDC_"~a.text`.join(','), "]");
		__gshared HCURSOR[MouseCursor.max] _loadedCursors;
		
		auto ref h() { return _loadedCursors[c]; }
		if(!h) { h = LoadCursorW(null, _cursorIds[c]); }
		core.sys.windows.winuser.SetCursor(h);
	}
	
	
	//Todo: ezek a specialis commentek szekciokra oszthatnak a filet es az editorban lehetne maszkalni a szekciok kozott
	//Todo: Ha a console ablak bezarodik, az ablakozorendszer destruktora akkor is hivodjon meg!
	
	//Todo: a sysmenu hasznalatakor ne klikkeljen az alkalmazasba bele
	
	////////////////////////////////////////////////////////////////////////////////
	///  Global Application entry point                                          ///
	////////////////////////////////////////////////////////////////////////////////
	
	/+
		global window creation.
		Passes name so the constructors must not be specified explicitly.
		(In D, classes doesnt inherit empty constructors...)
	+/
	T createWindow(T)(string name = Window.getUniqueName(__traits(identifier, T)) )
	{
		Window._upcomingWindowName = name;
		return new T;
	}
	
	__gshared Window mainWindow; //global access to mainWindow. Lame
	
	__gshared uint mainThreadProcessorNumber;
	
	////////////////////////////////////////////////////////////////////////////////
	///  WINDOW CLASS REGISTRATION                                               ///
	////////////////////////////////////////////////////////////////////////////////
	
	private __gshared static string[] _registeredClasses;
	
	void registerWindowClass(string className, wchar* icon = IDI_APPLICATION)
	{
		if(_registeredClasses.canFind(className)) return;
		
		WNDCLASS wndclass;
		with(wndclass) {
			style	= CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
			lpfnWndProc	= &Window.GlobalWndProc;
			cbClsExtra	= 0;
			cbWndExtra	= 0;
			hInstance	= GetModuleHandleW(null);
			hIcon	= LoadIcon(null, icon);
			hCursor	= LoadCursor(null, IDC_ARROW);
			hbrBackground	= null;
			lpszMenuName	= null;
			lpszClassName	= toPWChar(className);
		}
		RegisterClassW(&wndclass);
	}
	
	void unregisterWindowClass(string className)
	{
		if(!_registeredClasses.canFind(className)) return;
		_registeredClasses = _registeredClasses.remove(_registeredClasses.countUntil(className));
		UnregisterClassW(toPWChar(className), GetModuleHandleW(NULL));
	}
	
	
	////////////////////////////////////////////////////////////////////////////////
	///  DUMMY HELPER WINDOW                                                     ///
	////////////////////////////////////////////////////////////////////////////////
	
	HWND helperWindow() //Source: GLFW3
	{
		__gshared static HWND window;
		if(window) return window;
		
		string className = "Helper window class";
		registerWindowClass(className);
		window = CreateWindowExW(
			WS_EX_OVERLAPPEDWINDOW,
			toPWChar(className),
			"Helper window",
			WS_CLIPSIBLINGS | WS_CLIPCHILDREN,
			0, 0, 1, 1,
			HWND_MESSAGE, NULL,
			GetModuleHandleW(NULL),
			NULL
		);
		
		//HACK:	The first call to ShowWindow is ignored if the parent process
		//passed along a STARTUPINFO, so clear that flag with a no-op call
		ShowWindow(window, SW_HIDE);
		
		MSG msg;
		while(PeekMessageW(&msg, window, 0, 0, PM_REMOVE))
		{
			try
			{
				TranslateMessage(&msg);
				DispatchMessageW(&msg);
			}
			catch(Throwable e)
			{ writeln("Unhandled Exception: "~__traits(identifier, typeof(e))~"\r\n"~e.toString); }
		}
		
		return window;
	}
	
	
	auto createSimplePFD()
	{
		PIXELFORMATDESCRIPTOR pfd;
		with(pfd) {
			nSize	= pfd.sizeof;
				
			nVersion	= 1;
			dwFlags	= PFD_SUPPORT_OPENGL | PFD_SWAP_EXCHANGE |
				PFD_DRAW_TO_WINDOW | PFD_DOUBLEBUFFER;
			iPixelType	= PFD_TYPE_RGBA;
				
			cColorBits	= 32;
			cAccumBits	= 0;
			cDepthBits	= 24;
			cStencilBits	= 8;
			iLayerType	= PFD_MAIN_PLANE;
		}
		return pfd;
	}
	
	extern(Windows) bool function(
		HDC hdc, const(int*) piAttribIList, const(float*) pfAttribFList, 
		int nMaxFormats, int* piFormats, int* nNumFormats
	) wglChoosePixelFormatARB;
	
	private void initWglChoosePixelFormat()
	//gets it with a dummy window, so the first opengl window can use it. Losing 250ms for nothing by this shit.
	{
		void error(string err) { throw new Exception("initWglChoosePixelFormat() "~err); }
		auto w = helperWindow;
		auto dc = GetDC(w);
		
		auto pfd = createSimplePFD;
		if(!SetPixelFormat(dc, ChoosePixelFormat(dc, &pfd), &pfd)) error("SetPixelFormat failed");
		
		auto rc = wglCreateContext(dc);
		if(!rc) error("createContext failed");
		wglMakeCurrent(dc, rc);
		
		wglChoosePixelFormatARB = cast(typeof(wglChoosePixelFormatARB))wglGetProcAddress("wglChoosePixelFormatARB");
		if(wglChoosePixelFormatARB is null) error("getProcAddress failed");
		
		wglMakeCurrent(null, null);
		wglDeleteContext(rc);
	}
	
	
	////////////////////////////////////////////////////////////////////////////////
	///  WINDOWS ENTRY POINT                                                     ///
	////////////////////////////////////////////////////////////////////////////////
	
	//Note: main() used here instead of WinMain() to tell the linker to act like a console app in order to have a working stdout.
	///@compile -L/SUBSYSTEM:console -L/ENTRY:WinMainCRTStartup
	///@link /SUBSYSTEM:console /ENTRY:WinMainCRTStartup
	
	//extern(Windows) int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
	
	
	/*
		//this is not complete... It keeps staying inside this loop... Maybe because the opengl redraw is slow...
		void application_processMessages(){
			MSG  msg;
			while(PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)){
				TranslateMessage(&msg);
				DispatchMessage(&msg);
			}
		}
	*/
	
	
	//this main() is recognized by druntime.
	
	int main(string[] args)
	{
		MSG  msg;
		Runtime.initialize;
		application._initialize;
		
		try {
			SetPriorityClass(GetCurrentProcess, HIGH_PRIORITY_CLASS);
			initWglChoosePixelFormat(); //hack
			
			if(application._windowInitFunct) application._windowInitFunct();
			
			while(1)
			{
				//Note: GetMessage waits, if there is nothing;
				//Note: PeekMessage returns even if there is nothing.
				
				//PING(2);
				
				while(PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
				{
					//PING(3);
					
					TranslateMessage(&msg);
					DispatchMessage(&msg);
					
					if(Window.mainWindowDestroyed) goto done;
				}
				
				const isMainWindowHidden = mainWindow && mainWindow.isHidden;
				bool canSleep;
				if(isMainWindowHidden)
				{
					canSleep = true;
					foreach(w; Window.windowList.values) w.internalUpdate; //WM_TIMER just sucks....
				}
				else
				{
					canSleep = true;
					foreach(w; Window.windowList.values) {
						w.internalUpdate; //This is forced 100%cpu update.
						if(!w.canSleep) canSleep = false;
					}
				}
				
				if(canSleep) {
					//PING(4);
					sleep(1); //sleep 1 does nothing
				}
			}
			
			done:
			
			Window.destroyAllWindows;
		}
		catch(Throwable o) { showException(o); }
		
		application._finalize;
		Runtime.terminate;
		
		//Todo: Mark the unused threads as daemon threads (in karc2.d, utils.d, bitmap.d) and remove this application.exit!!!!
		application.exit; //let it exit even if there are threads stuck in
		
		return cast(int)msg.wParam;
	}
	
	
	struct WindowStyle { DWORD style=WS_OVERLAPPEDWINDOW, styleEx=0; }
}
class Window 
{
	////////////////////////////////////////////////////////////////////////////////
	///  WINDOW CLASS STATIC FUNCTIONS                                           ///
	////////////////////////////////////////////////////////////////////////////////
	private:
	static string _upcomingWindowName;
	static Window[HWND] windowList;
	static int windowCntr;
	static bool mainWindowDestroyed;
	static Window windowByName(string name)
	{ foreach(w; windowList) if(w.name==name) return w; return null; }
	
	static string getUniqueName(string name)
	{
		foreach(i; 0..int.max) {
			string n = name~(i ? format("(%s)", i) : "");
			if(!windowByName(n)) return n;
		}
		throw new Exception("Window.getUniqueName() failed.");
	}
	
	static extern(Windows) LRESULT GlobalWndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
	{
		LRESULT res;
		try {
			//find the window by handle
			auto w = hwnd in windowList;
			
			//call the windows message handler
			if(w) return w.WndProc(message, wParam, lParam);
			
		}catch(Throwable o) { showException(o); }
		return DefWindowProc(hwnd, message, wParam, lParam);
	}
	
	static HWND createWin(
		string className, string caption, 
		uint style = WS_OVERLAPPEDWINDOW, uint exStyle = WS_EX_OVERLAPPEDWINDOW
	)
	{
		/*
			//bool resizeable = 0;
			bool tool = 0;
			bool dialog = 1;
			bool topmost = 0;
			
			//normal
			style = 0; exStyle = 0;
			if(dialog){
				style = WS_OVERLAPPEDWINDOW - WS_SIZEBOX - WS_MAXIMIZEBOX - WS_MINIMIZEBOX;
			}else if(tool){
				style = WS_OVERLAPPEDWINDOW - WS_SIZEBOX - WS_MAXIMIZEBOX - WS_MINIMIZEBOX;
				exStyle = WS_EX_TOOLWINDOW;
			}else{
				style = WS_OVERLAPPEDWINDOW;
			}
			
			if(topmost){
				exStyle |= WS_EX_TOPMOST;
			}
		*/
		
		registerWindowClass(className);
		HWND hwnd = CreateWindowExW
			(
			exStyle,	/+
				styleEx: WS_EX_ACCEPTFILES, WS_EX_NOACTIVATE, WS_EX_OVERLAPPEDWINDOW, 
				WS_EX_PALETTEWINDOW, WS_EX_TOOLWINDOW, WS_EX_TOPMOST,
			+/
			className.toPWChar,	//window class name
			caption.toPWChar,	//window caption
			style,	/+
				window style, WS_ICONIC, WS_HSCROLL, WS_MAXIMIZE, 
				WS_OVERLAPPEDWINDOW, WS_POPUP, WS_SIZEBOX
			+/
			CW_USEDEFAULT,	//initial x position
			CW_USEDEFAULT,	//initial y position
			CW_USEDEFAULT,	//initial x size
			CW_USEDEFAULT,	//initial y size
			NULL,	//parent window handle
			NULL,	//window menu handle
			GetModuleHandle(NULL),	//program instance handle
			NULL
		);
		
		if(!hwnd) error("CreateWindow() failed "~text(GetLastError));
		return hwnd;
	}
	
	static void destroyAllWindows()
	{
		while(windowList.length)
		windowList.values[$-1].destroy;
	}
	
	//update control
	private static uint disableCounter;
	public static void disableUpdate()
	{ disableCounter++; }
	public static void enableUpdate ()
	{ disableCounter--; }
	
	////////////////////////////////////////////////////////////////////////////////
	///  WINDOW CLASS PRIVATE STUFF                                              ///
	////////////////////////////////////////////////////////////////////////////////
	private:
	HWND fhwnd;
	HDC fhdc;
	string fName;
	string paintErrorStr;
	bool 	isMain, //this is the main windows
		pendingInvalidate, //invalidate() was called. Timer checks it and clears it.
		canSleep /+In the last update, there was no invalidate() calls, so it can sleep in the main loop.+/;
	enum WM_MyStartup = WM_USER+0;
	
	string getClassName()
	{
		char[256] s;
		GetClassNameA(hwnd, s.ptr, s.length);
		return to!string(fromStringz(s.ptr)); //ez eleg nagy buzisag...
	}
	
	////////////////////////////////////////////////////////////////////////////////
	///  WINDOW CLASS PUBLIC STUFF                                               ///
	////////////////////////////////////////////////////////////////////////////////
	public:
	static error(string s)
	{ throw new Exception(s); }
	
	HWND hwnd()
	{ return fhwnd; }
	HDC hdc()
	{ return fhdc; }
	string inputChars; //aaccumulated WM_CHAR input flushed in update()
	string lastFrameStats;
	//bool autoUpdate;  deprecated: es csak a
	
	@property string name()
	{ return fName; }
	@property void name(string name_)
	{
		bool setCapt = name==caption;
		fName = name_;
		if(setCapt) caption = name;
	}
	
	template autoCreate()
	{
		//include this into any window ant it will be the mainWindow
		static this()
		{ application._windowInitFunct = { createWindow!(typeof(this)); }; }
		
		override uint getWindowStyle()
		{
			uint res = WS_OVERLAPPEDWINDOW;
			foreach(t; __traits(getAttributes, typeof(this))) if(is(typeof(t)==WindowStyle)) res = t.style;
			return res;
		}
		
		override uint getWindowStyleEx()
		{
			uint res;
			foreach(t; __traits(getAttributes, typeof(this))) if(is(typeof(t)==WindowStyle)) res = t.styleEx;
			return res;
		}
	}
	
	protected void onInitialZoomAll()
	{}
	protected void onInitializeGLWindow()
	{}
	protected void onFinalizeGLWindow()
	{}
	protected void onWglMakeCurrent(bool activate)
	{}
	
	uint getWindowStyle()
	{ return WS_OVERLAPPEDWINDOW; }
	uint getWindowStyleEx()
	{ return 0; }
	
	TimeLine timeLine;
	
	void setForegroundWindowIfVisible()
	{ if(isVisible) SetForegroundWindow(hwnd); }
	
	@property void dragAcceptFiles(bool val)
	{ DragAcceptFiles(hwnd, val); }
	
	mixin Signal!(File[]) whenFilesDropped;
	
	private bool dragAcceptFilesState;
	void updateDragAcceptFilesState()
	{
		auto newState = whenFilesDropped.slots_idx>0;
		if(dragAcceptFilesState.chkSet(newState))
		dragAcceptFiles = newState;
	}
	
	
	this()
	{
		//acquire window name
		fName = _upcomingWindowName;
		_upcomingWindowName = "";
		enforce(fName!="", "Window.create() Error: You must use createWindow() and specify a name.");
		enforce(!windowByName(fName), format(`Window.create() Error: Window "%s" already exists.`, fName));
		
		isMain = windowList.length==0;
		
		fhwnd = createWin(name, name, getWindowStyle, getWindowStyleEx);
		windowList[hwnd] = this; //after this, the window can accept wm_messages
		
		if(isMain) {
			mainWindow = this;
			_mainWindowHandle = hwnd;
			_mainWindowIsForeground = ()=>mainWindow.isForeground;
			
			console.afterFirstPrintFlushed = &setForegroundWindowIfVisible;
		}
		
		dbg.setExeHwnd(hwnd);
		
		fhdc = GetDC(hwnd);
		
		onInitializeGLWindow;
		
		//load configs from ini
		actions.config = ini.read(name~".actions", "");
		
		//call the user defined creator
		{
			onWglMakeCurrent(true); scope(exit) onWglMakeCurrent(false);
			
			onCreate;
			onInitialZoomAll;
			//it zooms if there is a drawing that was made in the onCreate... From now it is handled by GlWindow
		}
		
		if(isMain) {
			//By default the console is visible. Hide it at start if there is no writeln() in mainform.doCreate
			if(!console.visible) console.hide(true);
			
			//show the main window automatically
			show;
		}
		
		//this will launch the update timer a bit later.
		PostMessage(hwnd, WM_MyStartup, 0, 0);
	}
	
	private void destroy_impl()
	//Todo: multiWindow: szolni kene a tobbinek, hogy destroyozzon, vagy nemtom...
	{
		enforce(hwnd, format(`Window "%s" already destroyed.`, name));
		
		{
			onWglMakeCurrent(true); scope(exit) onWglMakeCurrent(false);
			
			onDestroy; //call user definied destroy
		}
		
		//save keyboard config
		if(!actions.isDefault || ini.read(name~".actions", ""))
		ini.write(name~".actions", actions.config);
		
		onFinalizeGLWindow;
		ReleaseDC(hwnd, hdc); fhdc  = null;
		
		windowList.remove(hwnd); //Todo: WRONG PLACE!
		DestroyWindow(hwnd);  fhwnd = null;
		
		if(isMain) {
			mainWindow = null;
			_mainWindowHandle = null;
			_mainWindowIsForeground = ()=>false;
			mainWindowDestroyed = true;
		}
	}
	
	
	~this()
	{
		destroy_impl;
		//Todo: multiwindownal a destructort osszerakni, mert most az le van xarva...
		//auto className = getClassName;
		//DestroyWindow(hwnd);
		//UnregisterClassW(className.toPWChar, GetModuleHandle(NULL));
	}
	
	//virtuals
	void onCreate() {};
	void onDestroy() {};
	
	//static bool wasUpdateAfterPaint;
	
	LRESULT onWmUser(UINT message, WPARAM wParam, LPARAM lParam)
	{ return 0; }
	
	protected bool inRedraw;
	protected bool _isSizingMoving;
	protected int updatesSinceLastDraw;
	
	private enum showWarnings = false;
	
	protected void internalRedraw()
	{
		if(inRedraw) { if(showWarnings) WARN("Already in internalRedraw()"); return; }
		if(inUpdate) { if(showWarnings) WARN("Already in internalUpdate()"); return; }
		
		inRedraw = true; scope(exit) { inRedraw = false; updatesSinceLastDraw = 0; }
		
		auto t0 = QPS;
		onBeginPaint;
		timeLine.addEvent(TimeLine.Event.Type.beginPaint , t0);  t0 = QPS;
		internalPaint;
		timeLine.addEvent(TimeLine.Event.Type.paint      , t0);  t0 = QPS;
		onEndPaint;
		timeLine.addEvent(TimeLine.Event.Type.endPaint   , t0);  t0 = QPS;
		onSwapBuffers;
		timeLine.addEvent(TimeLine.Event.Type.swapBuffers, t0);  //t0 = QPS;
		timeLine.restrictSize(60);
	}
	
	protected void forceRedraw()
	{ RedrawWindow(hwnd, null, null, RDW_INVALIDATE | RDW_UPDATENOW); }
	
	protected wchar lastSurrogateHi;
	
	protected LRESULT WndProc(UINT message, WPARAM wParam, LPARAM lParam)
	{
		auto _ = PROBE("WndProc");
		
		if(0) LOG(message.winMsgToString, wParam, lParam);
		
		//Todo: rendesen megcsinalni a game loopot.
		/+
			https://www.google.com/search?q=win32+game+loop&rlz=1C1CHBF_enHU813HU813
					&oq=win32+game+loop&aqs=chrome..69i57.3265j0j4&sourceid=chrome&ie=UTF-8
		+/
		//https://gist.github.com/lynxluna/4242170
		//https://gamedev.stackexchange.com/questions/59857/game-loop-on-windows
		//https://docs.microsoft.com/en-us/cpp/mfc/idle-loop-processing?view=msvc-170
		
		switch(message)
		{
			
			case WM_ERASEBKGND: return 1;
			case WM_PAINT: {
				pendingInvalidate = false;
				
				FPSCnt++;
				
				static bool running;
				if(chkSet(running))
				{
					internalUpdate; //this will cause an invalidate. But don't redraw right now, or it freezes.
				}
				else
				{
					//Todo: window resize eseten nincs update, csak paint. Emiatt az UI szarul frissul.
					//if(!wasUpdateAfterPaint) internalUpdate;  // <--- Ez meg mouse input bugokat okoz.
					
					if(updatesSinceLastDraw==0) internalUpdate;
					//fix: move window with mouse, no update called. 220324
					internalRedraw;
				}
				
				return 0;
			}
			
			case WM_DESTROY: 	this.destroy; if(isMain) PostQuitMessage(0); return 0;
			
			case WM_MyStartup:	if(isMain) SetTimer(hwnd, 999, 10, null); return 0; 
				//this is a good time to launch the timer. Called by a delayed PostMessage
			
			case WM_TIMER:	if(wParam==999) { internalUpdate; if(chkClear(pendingInvalidate)) forceRedraw; } return 0;
			case WM_SIZE:	internalUpdate; forceRedraw; return 0;
			
			case WM_MOUSEWHEEL:	_notifyMouseWheel((cast(int)wParam>>16)*(1.0f/WHEEL_DELTA)); return 0;
			
			case WM_CHAR:{
				try
				{
					const ch = cast(wchar)wParam;
					if(ch.isSurrogateHi)
					{ lastSurrogateHi = ch; }
					else if(ch.isSurrogateLo)
					{
						if(lastSurrogateHi != wchar.init)
						{
							inputChars ~= ([lastSurrogateHi, ch]).text;
							lastSurrogateHi = wchar.init;
						}
					}
					else
					{ inputChars ~= ch; }
				}
				catch(Exception e) { WARN(e.simpleMsg); }
				
				return 0;
			}
			
			//Disable beeps when Alt+keypress and F10
			case WM_SYSKEYDOWN:	return 0;  //just ignore these. It let's me handle Alt and F10 properly.
			case WM_SYSCHAR:	if(wParam==' ') break;else return 0; //Only enable Alt+Space
			case WM_MENUCHAR:	return MNC_CLOSE; //It disables beeps when Alt+keypress
			
			case WM_ENTERSIZEMOVE:	_isSizingMoving = true; return 0;
			case WM_EXITSIZEMOVE:	_isSizingMoving = false; return 0;
			
			case WM_SETCURSOR:	if(!isMouseInside) DefWindowProc(hwnd, message, wParam, lParam);
				internalUpdateMouseCursor(Yes.forced); return 1;
			
			case WM_DROPFILES: {
				auto files = hDropToFiles(cast(HANDLE)wParam);
				if(files.length)
				whenFilesDropped.emit(files);
				
				//Note: the sending and the receiving process must have the same elevation.
				/+Todo: get precise drop position with: DragQueryPoint+/
				return 0;
			}
			default:	if(message.inRange(WM_USER, 0x7FFF))
			return onWmUser(message-WM_USER, wParam, lParam);
		}
		return DefWindowProc(hwnd, message, wParam, lParam);
		
		//Todo: Beautify this sugly switch
		
	}
	
	
	////////////////////////////////////////////////////////////////////////////////
	///  BASIC WINDOW HANDLING, PROPERTIES                                       ///
	////////////////////////////////////////////////////////////////////////////////
	
	//window management
	void show()
	{ ShowWindow(hwnd, SW_SHOW); }
	void hide()
	{ ShowWindow(hwnd, SW_HIDE); }
	bool isHidden()
	{ WINDOWPLACEMENT wp; wp.length = wp.sizeof; enforce(GetWindowPlacement(hwnd, &wp)); return ~wp.showCmd & 1; }
	bool isVisible()
	{ return !isHidden; }
	void maximizeWin()
	{ ShowWindow(hwnd, SW_MAXIMIZE); }
	void minimizeWin()
	{ ShowWindow(hwnd, SW_MINIMIZE); }
	void setFocus()
	{ SetFocus(hwnd); } //it's only keyboard focus
	void setForegroundWindow()
	{ show; SetForegroundWindow(hwnd); }
	bool isForeground()
	{ return GetForegroundWindow == hwnd; }
	bool isSizingMoving()
	{ return _isSizingMoving; }
	
	bool isMouseInside() {
		if(isSizingMoving || isHidden) return false;
		return clientBounds.contains!"[)"(inputs.mouseAct);
	}
	
	bool canProcessUserInput()
	{ return isForeground && !isSizingMoving; }
	
	RECT windowRect()
	{ RECT r; GetWindowRect(hwnd, &r); return r; }
	@property auto windowBounds()
	{ with(windowRect) return ibounds2(left, top, right, bottom); }
	@property void windowBounds(in ibounds2 b)
	{
		SetWindowPos(
			hwnd, null, b.left, b.top, b.width, b.height,
			SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_NOZORDER | SWP_NOREDRAW
		);
	}
	
	@property auto windowSize()
	{ return windowBounds.size; }
	@property void windowSize(in ivec2 newSize)
	{
		SetWindowPos(
			hwnd, null, 0, 0, newSize.x, newSize.y,
			SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOOWNERZORDER | SWP_NOZORDER | SWP_NOREDRAW
		);
	}
	
	@property auto windowPos()
	{ return windowBounds.topLeft; }
	@property void windowPos(in ivec2 p)
	{
		SetWindowPos(
			hwnd, null, p.x, p.y, 0, 0,
			SWP_NOACTIVATE | SWP_NOSIZE | SWP_NOOWNERZORDER | SWP_NOZORDER | SWP_NOREDRAW
		);
	}
	
	RECT clientRect()
	{ RECT r; GetClientRect(hwnd, &r); return r; }
	auto clientBounds()
	{ with(clientRect) return ibounds2(left, top, right, bottom); }
	
	@property auto clientSize()
	{ return clientBounds.size; }
	@property void clientSize(in ivec2 newSize)
	{
		auto r = RECT(0, 0, newSize.x, newSize.y);
		AdjustWindowRect(&r, getWindowStyle, false);
		
		auto adjustedSize = ivec2(r.right-r.left, r.bottom-r.top);
		SetWindowPos(
			hwnd, null, 0, 0, adjustedSize.x, adjustedSize.y,
			SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOOWNERZORDER | SWP_NOZORDER | SWP_NOREDRAW
		);
		//Todo: if this is called always, disable the resizeableness of the window automatically
	}
	
	@property auto clientPos()
	{ with(clientRect) return ivec2(left, top); }
	auto clientSizeHalf()
	{ return clientSize * 0.5f;  }
	int clientWidth()
	{ return clientSize.x; }
	int clientHeight()
	{ return clientSize.y; }
	
	//matches both error! Bounds2f clientBounds() { with(clientRect) return Bounds2f(left, top, right, bottom); }
	auto screenPos()
	{ ivec2 p;MapWindowPoints(hwnd, null, cast(LPPOINT)&p, 1);return p; }
	auto screenToClient(T)(in T p)
	{ return p-screenPos; }
	auto clientToScreen(T)(in T p)
	{ return p+screenPos; }
	
	void invalidate()
	{
		if(chkSet(pendingInvalidate))
		{
			/*auto r = clientRect;*/
			//InvalidateRect(hwnd, null, 0);
			//RedrawWindow(hwnd, null, null, RDW_INVALIDATE);
			//https://stackoverflow.com/questions/2325894/difference-between-invalidaterect-and-redrawwindow
		}
	}
	
	private string lastCaption = "\0";
	@property string caption()
	{
		if(lastCaption!="\0") return lastCaption;
		wchar[] s;
		s.length = GetWindowTextLength(hwnd);
		GetWindowText(hwnd, s.ptr, cast(int)s.length+1);
		lastCaption = s.to!string;
		return lastCaption;
	}
	@property caption(string value)
	{
		if(lastCaption==value) return;
		lastCaption = value;
		SetWindowText(hwnd, value.toPWChar);
	}
	
	////////////////////////////////////////////////////////////////////////////////
	///  PAINT                                                                   ///
	////////////////////////////////////////////////////////////////////////////////
	
	void onBeginPaint()
	{ lastFrameStats = ""; };
	
	private final void internalPaint()
	{
		auto t0 = QPS; scope(exit) { timeLine.addEvent(TimeLine.Event.Type.paint, t0, QPS); }
		
		paintErrorStr = "";
		try
		{ onPaint; }
		catch(Throwable o)
		{
			
			/*
				if(dbg.isActive){
					dbg.handleException(extendExceptionMsg(o.text));
				}else{
					paintErrorStr = simplifiedMsg(o);  // <- this is meaningless. Must handle all the exceptions!!!
				}
			*/
			
			showException(o);
		}
	}
	
	void onPaint()
	{
		auto rect = clientRect;
		DrawText(hdc, "Default Window.doPaint()", -1, &rect, DT_SINGLELINE | DT_CENTER | DT_VCENTER);
	};
	
	void onEndPaint()
	{
		auto rect = clientRect;
		ValidateRect(hwnd, &rect);
		
		if(!paintErrorStr.empty) {
			int c = (rect.bottom+rect.top)/2;
			DrawText(hdc, toPWChar("Error: "~paintErrorStr), -1, &rect, DT_LEFT | DT_VCENTER);
		}
	};
	
	void onSwapBuffers()
	{
		 //for opengl. the latest step with the optional sleep
	}
	
	////////////////////////////////////////////////////////////////////////////////
	///  UPDATE                                                                  ///
	////////////////////////////////////////////////////////////////////////////////
	
	ActionManager actions; //every form has this
	
	float targetUpdateRate=70; //must be slightly higher than target display freq.
														 //Or much higher if it is a physical simulation.
														 //Todo: ezt is meg kell csinalni jobban.
	
	private Time time0=0*second, timeAct=0*second, timeLast=0*second; //internal vars for timing
	private int FPSCnt, UPSCnt; //internal counters for statistics
	private long PSSec; //second tetection
	
	Time totalTime=0*second, deltaTime=0*second, lagTime=0*second; //
	int FPS, UPS, lagCnt; //FramesPerSec, UpdatePerSec
	
	protected void onMouseUpdate() {} //forwarded to GLWindow. Must be called right after view.update
	protected void onUpdateViewAnimation() {} //forwarded to GLWindow
	
	protected void onUpdateUIBeginFrame() {} //GLWindow implements these too
	protected void onUpdateUIEndFrame() {}
	
	private void updateWithActionManager()
	{
		auto _ = PROBE("updateWAM");
		
		//const A = QPS;
		//scope(exit) print((QPS-A)*1000);
				//this calls the update on every window. But right now it is only for one window.
		
				//timing
				auto t0 = QPS; scope(exit) timeLine.addEvent(TimeLine.Event.Type.update, t0, QPS);
		
				//flush the keyboard input queue (WM_CHAR event)
				scope(exit) inputChars = "";
		
				//make openGL accessible
				onWglMakeCurrent(true);
		
				//prepare/finalize the old, immediate mode keyboard 'actions' interface (inputs.d)
				actions.beginUpdate;
		
				//update the local mouse struct
				onMouseUpdate;
		
				//update the smooth scolling of the fullscreen 'view'. Navigation using actions must be issued manually -> view.navigate
				onUpdateViewAnimation;
		
				//UI integration: prepare and finalize the IMGUI for every frame
				onUpdateUIBeginFrame;
		
		
				//call the user overridden update method for the window
				try { onUpdate; }catch(Throwable t) { showException(t); }
		
				onUpdateUIEndFrame;
		
				{ if(actions.changed) invalidate;  actions.endUpdate; }
		
				onWglMakeCurrent(false);
	}
	
	MouseCursor mouseCursor;
	private MouseCursor lastMouseCursor;
	private void internalUpdateMouseCursor(Flag!"forced" forced = No.forced)
	{
		if(!isMouseInside) return;
		if(lastMouseCursor.chkSet(mouseCursor) || forced)
		SetCursor(mouseCursor);
	}
	
	private bool inUpdate;
	
	private final void internalUpdate()
	{
		//static if(1){ const T0 = QPS; scope(exit) print("IU", (QPS-T0)*1000); }
		
		if(inUpdate) { if(showWarnings) WARN("Already in internalUpdate()"); return; }
		inUpdate = true;
		scope(exit) inUpdate = false;
		
		enforce(isMain, "Window.internalUpdate() called from non main window.");
		
		//lock
		if(disableCounter) return;
		disableUpdate;
		scope(exit) {
			enableUpdate;
			//wasUpdateAfterPaint = true;
			
			//forceRedraw; //Bug: ha ez itt van, akkor az ablakot lehetetlen bezarni
		}
		
		//handle debug.kill
		if(dbg.forceExit_check) { dbg.forceExit_clear; this.destroy; } //Todo: ez multiWindow-ra nem tudom, hogy hogy fog menni...
		
		const timeTarget = (1.0f/targetUpdateRate)*second;
		
		//refresh processorId
		mainThreadProcessorNumber = GetCurrentProcessorNumber;
		
		//initialize timing system
		if(!time0) { time0 = timeLast = QPS-timeTarget-0.001*second; }
		
		const tickNow = now; //this is for application.tickTime. Taken at the same time as timeAct.
		timeAct = QPS;
		deltaTime = timeAct-timeLast;
		if(deltaTime<timeTarget) return; //too small elapsed time
		
		if(deltaTime>0.5*second) {
			 //LAG handling
			lagCnt++;
			lagTime += deltaTime;
			deltaTime = timeTarget;
		}
		
		//int updateCnt = iround(deltaTime.value(second)/timeTarget.value(second)).clamp(0, 1);
		int updateCnt = 1; //220814: It is better to be stable. This game loop is already way too complicated. This performs best for DIDE2
		
		deltaTime /= updateCnt;
		
		try
		{
			bool anyInvalidate;
			foreach(i; 0..updateCnt)
			{
				totalTime = timeLast + deltaTime*i;
				
				//ticking. The same timing information as what the windows are receiving
				application.tick++;
				application.tickTime	= tickNow - deltaTime*(updateCnt-i);
				application.deltaTime	= deltaTime;
				
				inputs.update; //Note: it's main window only
				clipboard.update;
				updateDragAcceptFilesState;
				
				updateWithActionManager; //update Main
				foreach(w; windowList)
				if(!w.isMain)
				{
					 //call othyer forms.updates
					w.totalTime = totalTime;
					w.deltaTime = deltaTime;
					w.FPS = FPS;
					w.UPS = UPS;
					
					w.updateWithActionManager;//update Others
					anyInvalidate |= w.pendingInvalidate;
				}
				
				
				if(i==0) inputs.clearDeltas;
				//only the first update is used for input processing... Later maybe interpolation can kick in...
				
				UPSCnt++;
				
				//update FPS, UPS
				if(chkSet(PSSec,	ltrunc(totalTime.value(second))))
				{
					FPS = FPSCnt;	FPSCnt = 0;
					UPS = UPSCnt;	UPSCnt = 0;
					if(isMain) {
						TPS = global_TPSCnt;	 global_TPSCnt = 0; //texture upload/sec
						VPS = global_VPSCnt;	 global_VPSCnt = 0; //VBO upload/sec
					}
				}
			}
			
			if(updateCnt>0) canSleep = !anyInvalidate;
			//if there was an actual update cycle, update the canSleep state. It can only sleep when tere was no invalidate() calls
			
			internalUpdateMouseCursor;
		}
		finally { timeLast = timeAct; }
	}
	
	void onUpdate()
	{
		 //this is just an example
		/*
			updateView(true, true);
			
			with(actions){
				group("Basic commands");
				onPressed("Help", "F1", { writeln(actions); });
			}
			
			if(autoUpdate) invalidate;
		*/
	}
	
	
}