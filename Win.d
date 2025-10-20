module het.win; /+DIDE+/

version(/+$DIDE_REGION+/all) {
	//The next @comment is important: It marks the app as a windowed app.
	//@win
	
	pragma(lib, "gdi32.lib"); 
	pragma(lib, "winmm.lib"); 
	//pragma(lib, "opengl32.lib"); //needed for initWglChoosePixelFormat()
	
	public import het; 
	
	import het.inputs: ActionManager, _notifyMouseWheel; 
	
	public import het.inputs: inputs, KeyCombo, MouseState, ClickDetector; 
	
	//moved into utils.application.tick __gshared uint global_tick; //counts in every update cycle
	__gshared size_t global_TPSCnt, global_TPS; //texture upload bytes /sec
	__gshared size_t global_VPSCnt, global_VPS; //VBO upload bytes /sec
	
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
		
		bool opCast(B : bool)() const => !!handle; 
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
	
	auto waitWindow(string classNameWild, string titleWild, Time timeout = 10*second)
	{
		WindowInfo wi; 
		auto t0 = now, tMax = t0+timeout; 
		while(1) {
			if(now>tMax) raise("Timeout waiting for window "~classNameWild.quoted~" "~titleWild.quoted); 
			sleep(100); //wait for page loading
			wi = GetForegroundWindow.getWindowInfo; 
			if(wi.className.isWild(classNameWild) && wi.title.isWild(titleWild))
			break; 
		}
		return wi; 
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
	
	
	//MouseCursor /////////////////////////////////////////////////////////////////////
	
	enum MouseCursor {
		ARROW, IBEAM, WAIT, CROSS, UPARROW, /+SIZE, ICON,+/ 
		SIZENWSE, SIZENESW, SIZEWE, SIZENS, SIZEALL, NO, HAND, APPSTARTING, HELP
	} 
	
	void SetCursor(MouseCursor c)
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
	
	
	static void _createMainWindow(T)(string name = Window.getUniqueName(__traits(identifier, T)) )
	{
		enforce(mainWindow is null, "MainWindow already created."); 
		Window._upcomingWindowName = name; 
		new T; //call the actual creator
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
	///  WINDOWS ENTRY POINT                                                     ///
	////////////////////////////////////////////////////////////////////////////////
	
	//Note: main() used here instead of WinMain() to tell the linker to act like a console app in order to have a working stdout.
	///@compile -L/SUBSYSTEM:console -L/ENTRY:WinMainCRTStartup
	///@link /SUBSYSTEM:console /ENTRY:WinMainCRTStartup
	//extern(Windows) int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
	
	
	//this main() is recognized by druntime.
	
	int main(string[] args)
	{
		MSG  msg; 
		Runtime.initialize; 
		application._initialize; 
		
		try {
			SetPriorityClass(GetCurrentProcess, HIGH_PRIORITY_CLASS); 
			
			//Creates main window
			if(Window._mainWindowInitFunct) Window._mainWindowInitFunct(); 
			
			while(1)
			{
				//Note: GetMessage waits, if there is nothing;
				//Note: PeekMessage returns even if there is nothing.
				
				while(PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
				{
					TranslateMessage(&msg); 
					DispatchMessage(&msg); 
					if(Window.mainWindowDestroyed) goto done; 
				}
				
				const isMainWindowHidden = mainWindow && mainWindow.isHidden; 
				bool canSleep; 
				if(isMainWindowHidden)
				{
					canSleep = true; 
					foreach(w; Window.windowList.values) w.doUpdate; //WM_TIMER just sucks....
				}
				else
				{
					canSleep = true; 
					foreach(w; Window.windowList.values) {
						w.doUpdate; //This is forced 100%cpu update.
						if(!w.canSleep) canSleep = false; 
					}
				}
				
				if(canSleep) { sleep(1); }
			}
			
			done: 
			Window.destroyAllWindows; 
		}
		catch(Throwable o) { showException(o); }
		
		application._finalize; 
		Runtime.terminate; 
		
		//Todo: Mark the unused threads as daemon threads (in karc2.d, utils.d, bitmap.d) and remove this application.exit!!!!
		application.exit; //let it exit even if there are threads stuck in
		
		return 0; //never reached
	} 
	
	
	struct WindowStyle { DWORD style=WS_OVERLAPPEDWINDOW, styleEx=0; } 
	
	class Window 
	{
		//Todo: opPaint can't process KeyCombo().pressed events
		
		static /+WINDOW CLASS STATIC FUNCTIONS+/
		{
			private: 
			string _upcomingWindowName; 
			Window[HWND] windowList; 
			int windowCntr; 
			bool mainWindowDestroyed; 
			
			Window windowByName(string name)
			{ foreach(w; windowList) if(w.name==name) return w; return null; } 
			
			string getUniqueName(string name)
			{
				foreach(i; 0..int.max) {
					string n = name~(i ? format("(%s)", i) : ""); 
					if(!windowByName(n)) return n; 
				}
				throw new Exception("Window.getUniqueName() failed."); 
			} 
			
			public extern(Windows) nothrow 
				LRESULT GlobalWndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
			{
				LRESULT res; 
				try {
					//find the window by handle
					auto w = hwnd in windowList; 
					
					//call the windows message handler
					if(w) return w.WndProc(message, wParam, lParam); 
					
				}
				catch(Throwable o)
				{ showException(o); }
				return DefWindowProc(hwnd, message, wParam, lParam); 
			} 
			
			HWND createWin(
				string className, string caption, 
				uint style = WS_OVERLAPPEDWINDOW, uint exStyle = WS_EX_OVERLAPPEDWINDOW
			)
			{
				registerWindowClass(className); 
				HWND hwnd = CreateWindowExW
					(
					exStyle,	/+
						styleEx: WS_EX_ACCEPTFILES, WS_EX_NOACTIVATE, 
						WS_EX_OVERLAPPEDWINDOW, WS_EX_PALETTEWINDOW, 
						WS_EX_TOOLWINDOW, WS_EX_TOPMOST,
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
				
				if(!hwnd) raise("CreateWindow() failed "~text(GetLastError)); 
				return hwnd; 
			} 
			
			void destroyAllWindows()
			{
				while(windowList.length)
				windowList.values[$-1].destroy; 
			} 
			
			//update control
			private uint disableCounter; 
			
			public void disableUpdate()
			{ disableCounter++; } 
			public void enableUpdate ()
			{ disableCounter--; } 
		} 
		
		template autoCreate()
		{
			//include this into any window ant it will be the mainWindow
			shared static this()
			{
				enforce(_mainWindowInitFunct is null, "Window.autoCreate can be used only once."); 
				_mainWindowInitFunct = { _createMainWindow!(typeof(this)); }; 
			} 
			
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
		
		
		__gshared void function() _mainWindowInitFunct; //this will be accessed from main()
		
		private: 
		HWND fhwnd; 
		HDC fhdc; 
		string fName; 
		string paintErrorStr; 
		bool 	isMain, //this is the main windows
			pendingInvalidate, //invalidate() was called. Timer checks it and clears it.
			canSleep /+In the last update, there was no invalidate() calls, so it can sleep in the main loop.+/; 
		
		enum WM_MyStartup = WM_USER+0; 
		
		public: 
		
		string inputChars; //aaccumulated WM_CHAR input flushed in update()
		string lastFrameStats; 
		
		//Fields accessed from het.ui
		bool showFPS; //shows FPS graph overlay, UI switching it on and off.
		MouseState mouse; //it is updated in descendant classes where views are maintained.
		het.math.RGB backgroundColor = clBlack; 
		
		HWND hwnd()
		{ return fhwnd; }  HDC hdc()
		{ return fhdc; } 
		
		@property string name()
		{ return fName; }  @property void name(string name_)
		{
			bool setCapt = name==caption; 
			fName = name_; 
			if(setCapt) caption = name; 
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
		}  @property caption(string value)
		{
			if(lastCaption==value) return; 
			lastCaption = value; 
			SetWindowText(hwnd, value.toPWChar); 
		} 
		
		
		version(/+$DIDE_REGION Virtual events+/all)
		{
			uint getWindowStyle()
			{ return WS_OVERLAPPEDWINDOW; } 
			
			uint getWindowStyleEx()
			{ return 0; } 
			
			void onCreate()
			{} 	 void onDestroy()
			{} 	 void onUpdate()
			{} 
			
			void doUpdate()
			{
				internalUpdate; 
				//vulkan can override this
			} 
			
			protected void onInitialZoomAll()
			{} 
			protected void onInitializeGLWindow()
			{} 
			protected void onFinalizeGLWindow()
			{} 
			protected void onWglMakeCurrent(bool activate)
			{} 
			void onSwapBuffers()
			{
				 //for opengl. the latest step with the optional sleep
			} 
			
			void onBeginPaint()
			{ lastFrameStats = ""; } 
			
			void onPaint()
			{
				auto rect = clientRect; 
				DrawText(hdc, "Default Window.doPaint()", -1, &rect, DT_SINGLELINE | DT_CENTER | DT_VCENTER); 
			}; 
			
			void onEndPaint()
			{
				auto rect = clientRect; 
				ValidateRect(hwnd, &rect); 
				
				if(!paintErrorStr.empty)
				{
					int c = (rect.bottom+rect.top)/2; 
					DrawText(hdc, toPWChar("Error: "~paintErrorStr), -1, &rect, DT_LEFT | DT_VCENTER); 
				}
			}; 
			
			protected void onMouseUpdate()
			{/+forwarded to GLWindow. Must be called right after view.update+/} 
			protected void onUpdateViewAnimation() 
			{/+forwarded to GLWindow+/} 
			
			protected void onUpdateUIBeginFrame()
			{/+GLWindow implements these too+/} 
			protected void onUpdateUIEndFrame() 
			{} 
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
		
		~this()
		{
			//Todo: multiWindow: szolni kene a tobbinek, hogy destroyozzon, vagy nemtom...
			
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
			
			//Todo: multiwindownal a destructort osszerakni, mert most az le van xarva...
			//auto className = getClassName;
			//DestroyWindow(hwnd);
			//UnregisterClassW(className.toPWChar, GetModuleHandle(NULL));
		} 
		
		
		//static bool wasUpdateAfterPaint;
		
		LRESULT onWmUser(UINT message, WPARAM wParam, LPARAM lParam)
		{ return 0; } 
		
		protected bool inRedraw; 
		protected bool _isSizingMoving; 
		protected int updatesSinceLastDraw; 
		
		private enum showWarnings = false; 
		
		static struct TimeLine
		{
			
			static struct Event
			{
				enum Type
				{ update, beginPaint, paint, endPaint, swapBuffers} 
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
		TimeLine timeLine; 
		
		bool disableInternalRedraw;  //Vulkan can disable this. No onpaint will be called.
		
		protected void internalRedraw()
		{
			if(inRedraw) { if(showWarnings) WARN("Already in internalRedraw()"); return; }
			if(inUpdate) { if(showWarnings) WARN("Already in internalUpdate()"); return; }
			
			inRedraw = true; scope(exit) { inRedraw = false; updatesSinceLastDraw = 0; }
			
			if(disableInternalRedraw) return; 
			
			auto t0 = QPS; 
			onBeginPaint; 	timeLine.addEvent(TimeLine.Event.Type.beginPaint , t0); 	t0 = QPS; 
			internalPaint; 	timeLine.addEvent(TimeLine.Event.Type.paint      , t0); 	t0 = QPS; 
			onEndPaint; 	timeLine.addEvent(TimeLine.Event.Type.endPaint   , t0); 	t0 = QPS; 
			onSwapBuffers; 	timeLine.addEvent(TimeLine.Event.Type.swapBuffers, t0); 	//t0 = QPS;
			timeLine.restrictSize(60); 
		} 
		
		protected void forceRedraw()
		{
			if(disableInternalRedraw) return; 
			RedrawWindow(hwnd, null, null, RDW_INVALIDATE | RDW_UPDATENOW); 
		} 
		
		protected wchar lastSurrogateHi; 
		
		ivec2 minWindowSize; 
		
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
						doUpdate; //this will cause an invalidate. But don't redraw right now, or it freezes.
					}
					else
					{
						//Todo: window resize eseten nincs update, csak paint. Emiatt az UI szarul frissul.
						//if(!wasUpdateAfterPaint) doUpdate;  // <--- Ez meg mouse input bugokat okoz.
						
						if(updatesSinceLastDraw==0) doUpdate; 
						//fix: move window with mouse, no update called. 220324
						internalRedraw; 
					}
					
					return 0; 
				}
				
				case WM_DESTROY: 	this.destroy; if(isMain) PostQuitMessage(0); return 0; 
				
				case WM_MyStartup: 	if(isMain) SetTimer(hwnd, 999, 10, null); return 0; 
					//this is a good time to launch the timer. Called by a delayed PostMessage
				
				case WM_TIMER: 	if(wParam==999) { doUpdate; if(chkClear(pendingInvalidate)) forceRedraw; }return 0; 
					/+Todo: Try Windows Multimedia Timer (timeBeginPeriod)+/
				case WM_SIZE: 	doUpdate; forceRedraw; return 0; 
				
				case WM_MOUSEWHEEL: 	_notifyMouseWheel((cast(int)wParam>>16)*(1.0f/WHEEL_DELTA)); return 0; 
				
				case WM_CHAR: {
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
						{
							const isCtrlSpace = ch==' ' && (GetKeyState(VK_CONTROL)&0x8000); 
							if(!isCtrlSpace) inputChars ~= ch; 
						}
					}
					catch(Exception e) { WARN(e.simpleMsg); }
					
					return 0; 
				}
				
				//Disable beeps when Alt+keypress and F10
				case WM_SYSKEYDOWN: 	return 0;  //just ignore these. It let's me handle Alt and F10 properly.
				case WM_SYSCHAR: 	if(wParam==' ') break; else return 0; //Only enable Alt+Space
				case WM_MENUCHAR: 	return MNC_CLOSE; //It disables beeps when Alt+keypress
				
				case WM_ENTERSIZEMOVE: 	_isSizingMoving = true; return 0; 
				case WM_EXITSIZEMOVE: 	_isSizingMoving = false; return 0; 
				
				case WM_SETCURSOR: 	if(!isMouseInside) DefWindowProc(hwnd, message, wParam, lParam); 
					internalUpdateMouseCursor(Yes.forced); return 1; 
				
				case WM_DROPFILES: {
					auto files = hDropToFiles(cast(HANDLE)wParam); 
					if(files.length)
					whenFilesDropped.emit(files); 
					
					//Note: the sending and the receiving process must have the same elevation.
					//Todo: detect if there was a failed drop and tell the user to solve elevation issues.
					/+Todo: get precise drop position with: DragQueryPoint+/
					return 0; 
				}
				//WM_TIMECHANGE: LOG("WM_TIMECHANGE"); return 0;
				//case WM_SETTINGCHANGE: LOG("WM_SETTINGSCHANGE"); return 0;
				
				case WM_GETMINMAXINFO: {
					if(!minWindowSize) break; 
					with(cast(LPMINMAXINFO)lParam)
					{
						ptMinTrackSize.x = minWindowSize.x; 
						ptMinTrackSize.y = minWindowSize.y; 
					}
					return 0; 
				}
				
				default: 	if(message.inRange(WM_USER, 0x7FFF))
				return onWmUser(message-WM_USER, wParam, lParam); 
			}
			return DefWindowProc(hwnd, message, wParam, lParam); 
			
			//Todo: Beautify this sugly switch
			
		} 
		
		
		void show()
		{ ShowWindow(hwnd, SW_SHOW); }  void hide()
		{ ShowWindow(hwnd, SW_HIDE); } 
		bool isHidden()
		{
			WINDOWPLACEMENT wp; wp.length = wp.sizeof; 
			enforce(GetWindowPlacement(hwnd, &wp)); return ~wp.showCmd & 1; 
		} 
		bool isVisible()
		{ return !isHidden; } 
		
		void maximizeWin()
		{ ShowWindow(hwnd, SW_MAXIMIZE); }  void minimizeWin()
		{ ShowWindow(hwnd, SW_MINIMIZE); } 
		void setFocus()
		{ SetFocus(hwnd); } //it's only keyboard focus
		void setForegroundWindow()
		{ show; SetForegroundWindow(hwnd); }  void setForegroundWindowIfVisible()
		{ if(isVisible) SetForegroundWindow(hwnd); } 
		bool isForeground()
		{ return GetForegroundWindow == hwnd; } 
		
		bool isSizingMoving()
		{ return _isSizingMoving; } 
		
		bool isMouseInside()
		{
			if(isSizingMoving || isHidden) return false; 
			return clientBounds.contains!"[)"(screenToClient(inputs.mouseAct)); 
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
				SWP_NOACTIVATE | SWP_NOMOVE | 
				SWP_NOOWNERZORDER |SWP_NOZORDER | SWP_NOREDRAW
			); 
		} 
		
		@property auto windowPos()
		{ return windowBounds.topLeft; } 
		@property void windowPos(in ivec2 p)
		{
			SetWindowPos(
				hwnd, null, p.x, p.y, 0, 0, 
				SWP_NOACTIVATE | SWP_NOSIZE | 
				SWP_NOOWNERZORDER | SWP_NOZORDER | SWP_NOREDRAW
			); 
		} 
		
		RECT clientRect()
		{ RECT r; GetClientRect(hwnd, &r); return r; } 
		auto clientBounds()
		{
			//Note: the topleft is always 0,0.  Use clientToScreen on this to get the client bounds in screenSpace.
			with(clientRect) return ibounds2(left, top, right, bottom); 
		} 
		
		@property auto clientSize()
		{ return clientBounds.size; } 
		@property void clientSize(in ivec2 newSize)
		{
			auto r = RECT(0, 0, newSize.x, newSize.y); 
			AdjustWindowRectEx(&r, getWindowStyle, false, getWindowStyleEx); 
			
			auto adjustedSize = ivec2(r.right-r.left, r.bottom-r.top); 
			SetWindowPos(
				hwnd, null, 0, 0, adjustedSize.x, adjustedSize.y,
				SWP_NOACTIVATE | SWP_NOMOVE | 
				SWP_NOOWNERZORDER | SWP_NOZORDER | SWP_NOREDRAW
			); 
			//Todo: if this is called always, disable the resizeableness of the window automatically
		} 
		
		@property auto clientPos()
		{ with(clientRect) return ivec2(left, top); } 
		auto clientSizeHalf()
		{ return clientSize * 0.5f;  } 
		int clientWidth()
		{ return clientSize.x; }  int clientHeight()
		{ return clientSize.y; } 
		
		//matches both error! Bounds2f clientBounds() { with(clientRect) return Bounds2f(left, top, right, bottom); }
		auto _clientToScreenOfs()
		{ ivec2 p; MapWindowPoints(hwnd, null, cast(LPPOINT)&p, 1); return p; } 
		auto screenToClient(T)(in T p)
		{ return p-_clientToScreenOfs; }  auto clientToScreen(T)(in T p)
		{ return p+_clientToScreenOfs; } 
		
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
		
		
		ActionManager actions; //every form has this
		
		float targetUpdateRate=70; //must be slightly higher than target display freq.
		//Or much higher if it is a physical simulation.
		//Todo: ezt is meg kell csinalni jobban.
		
		private Time time0=0*second, timeAct=0*second, timeLast=0*second; //internal vars for timing
		private int FPSCnt, UPSCnt; //internal counters for statistics
		private long PSSec; //second tetection
		
		Time totalTime=0*second, deltaTime=0*second, lagTime=0*second; //
		int FPS, UPS, lagCnt; //FramesPerSec, UpdatePerSec
		
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
		
		void offscreenPaint(void delegate() fun)
		{
			//Todo: BeginBufferedPaint!!! ilyen van: https://learn.microsoft.com/en-us/windows/win32/api/uxtheme/nf-uxtheme-beginbufferedpaint   BPBF_DIB
			
			/+
				Paint into an offscreen GDI bitmap to avoid flicker.
				Because WS_LAYERED+WS_COMPOSITE is too slow, sometimes it has 0.5 lags.
				/+Link: https://learn.microsoft.com/en-us/previous-versions/ms969905(v=msdn.10)?redirectedfrom=MSDN+/
			+/
			
			HANDLE hdcMem, hbmMem, hbmOld, hdcOld; 
			
			RECT rc; GetClientRect(hwnd, &rc); 
			hdcMem = CreateCompatibleDC(hdc); 
			hbmMem = CreateCompatibleBitmap(hdc, rc.right-rc.left, rc.bottom-rc.top); 
			hbmOld = SelectObject(hdcMem, hbmMem); 
			hdcOld = this.fhdc; 
			this.fhdc = hdcMem; 
			
			scope(exit)
			{
				this.fhdc = hdcOld; 
				BitBlt(hdc, rc.left, rc.top, rc.right-rc.left, rc.bottom-rc.top, hdcMem, 0, 0, SRCCOPY); 
				SelectObject(hdcMem, hbmOld); 
				DeleteObject(hbmMem); 
				DeleteDC(hdcMem); 
			}
			
			fun(); 
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
		protected final void internalUpdate()
		{
			//handle debug.kill
			if(dbg.forceExit_check) {
				import core.sys.windows.windows; 
				PostMessage(hwnd, WM_CLOSE, 0, 0); 
				return; 
			}
			
			if(inUpdate) { if(showWarnings) WARN("Already in internalUpdate()"); return; }
			inUpdate = true; 
			scope(exit) { inUpdate = false; }
			
			enforce(isMain, "Window.internalUpdate() called from non main window."); 
			
			//lock
			if(disableCounter) return; 
			disableUpdate; 
			scope(exit) { enableUpdate; }
			
			
			const timeTarget = (1.0f/targetUpdateRate)*second; 
			
			//refresh processorId
			mainThreadProcessorNumber = GetCurrentProcessorNumber; 
			
			//initialize timing system
			if(!time0) { time0 = timeLast = QPS-timeTarget-0.001*second; }
			
			const tickNow = now; //this is for application.tickTime. Taken at the same time as timeAct.
			timeAct = QPS; 
			
			deltaTime = timeAct-timeLast; 
			if(deltaTime>=timeTarget)
			{
				
				if(deltaTime>0.5*second) {
					//LAG handling
					lagCnt++; 
					lagTime += deltaTime; 
					deltaTime = timeTarget; 
				}
				
				scope(exit) timeLast = timeAct; 
				
				bool anyInvalidate; 
				
				totalTime = timeLast; 
				
				//ticking. The same timing information as what the windows are receiving
				application.tick++; 
				application.tickTime = tickNow - deltaTime; 	//Todo: This timing is unclear. It's a mess...
				application.appTime = application.tickTime -	appStarted; 
				application.deltaTime = deltaTime; 
				
				if((application.tick & 0x3F)==0)
				application._updateTimeZone/+Opt: This one is slow: 0.75ms+/; 
				
				//Opt: measure the performance of these update events
				inputs.update; //Note: 0.5ms  it's main window only
				clipboard.update; 
				updateDragAcceptFilesState; 
				
				updateWithActionManager; //update Main
				anyInvalidate |= pendingInvalidate; 
				
				//update other windows.  Not used at the moment.
				foreach(w; windowList)
				if(!w.isMain)
				{
					 //call othyer forms.updates
					w.totalTime = totalTime; 
					w.deltaTime = deltaTime; 
					w.FPS = FPS; 
					w.UPS = UPS; 
					
					w.updateWithActionManager; //update Others
					anyInvalidate |= w.pendingInvalidate; 
				}
				
				inputs.clearDeltas; 
				
				//update FPS, UPS
				UPSCnt++; 
				if(chkSet(PSSec,	ltrunc(totalTime.value(second))))
				{
					FPS = FPSCnt; 	FPSCnt = 0; 
					UPS = UPSCnt; 	UPSCnt = 0; 
					if(isMain) {
						global_TPS = global_TPSCnt; 	 global_TPSCnt = 0; //texture upload/sec
						global_VPS = global_VPSCnt; 	 global_VPSCnt = 0; //VBO upload/sec
					}
				}
				
				canSleep = !anyInvalidate; 
				//if there was an actual update cycle, update the canSleep state. It can only sleep when tere was no invalidate() calls
				
				internalUpdateMouseCursor; 
			}
		} 
		
		
		version(/+$DIDE_REGION DragAcceptFiles+/all)
		{
			@property void dragAcceptFiles(bool val)
			{ DragAcceptFiles(hwnd, val); } 
			
			mixin Signal!(File[]) whenFilesDropped; 
			
			private bool dragAcceptFilesState; 
			protected void updateDragAcceptFilesState()
			{
				auto newState = whenFilesDropped.slots_idx>0; 
				if(dragAcceptFilesState.chkSet(newState))
				dragAcceptFiles = newState; 
			} 
		}
		
		version(/+$DIDE_REGION ProgressBar on taskbar+/all)
		{
			enum TBPFLAGS
			{
				NOPROGRESS 	= 0,
				INDETERMINATE 	= 0x1,
				NORMAL 	= 0x2,
				ERROR 	= 0x4,
				PAUSED 	= 0x8
			} 
			
			mixin(clsid!(ITaskbarList, "56FDF344-FD6D-11D0-958A-006097C9A090")); 
			mixin(uuid!(ITaskbarList, "56FDF342-FD6D-11D0-958A-006097C9A090")); 
			interface ITaskbarList : IUnknown
			{
				HRESULT HrInit(); 
				HRESULT AddTab(HWND hwnd); 
				HRESULT DeleteTab(HWND hwnd); 
				HRESULT ActivateTab(HWND hwnd); 
				HRESULT SetActiveAlt(HWND hwnd); 
			} 
			
			mixin(uuid!(ITaskbarList2, "602D4995-B13A-429B-A66E-1935E44F4317")); 
			interface ITaskbarList2 : ITaskbarList
			{ HRESULT MarkFullscreenWindow(HWND hwnd, BOOL fFullscreen); } 
			
			mixin(uuid!(ITaskbarList3, "EA1AFB91-9E28-4B86-90E9-9E9F8A5EEFAF")); 
			interface ITaskbarList3 : ITaskbarList2
			{
				HRESULT SetProgressValue(HWND hwnd, ulong ullCompleted, ulong ullTotal); 
				HRESULT SetProgressState(HWND hwnd, DWORD tbpFlags); 
				/+
					HRESULT RegisterTab(hwndTab: Cardinal; hwndMDI: Cardinal); safecall;
					HRESULT UnregisterTab(hwndTab: Cardinal); safecall;
					HRESULT SetTabOrder(hwndTab: Cardinal; hwndInsertBefore: Cardinal); safecall;
					HRESULT SetTabActive(hwndTab: Cardinal; hwndMDI: Cardinal; tbatFlags: DWORD); safecall;
					HRESULT ThumbBarAddButtons(hwnd: Cardinal; cButtons: UINT; Button: THUMBBUTTONLIST); safecall;
					HRESULT ThumbBarUpdateButtons(hwnd: Cardinal; cButtons: UINT; pButton: THUMBBUTTONLIST); safecall;
					HRESULT ThumbBarSetImageList(hwnd: Cardinal; himl: Cardinal); safecall;
					HRESULT SetOverlayIcon(hwnd: Cardinal; hIcon: HICON; pszDescription: LPCWSTR); safecall;
					HRESULT SetThumbnailTooltip(hwnd: Cardinal; pszTip: LPCWSTR); safecall;
					HRESULT SetThumbnailClip(hwnd: Cardinal; prcClip: PRect); safecall;
				+/
			} 
			
			ITaskbarList3 taskbarList3; 
			
			void setTaskbarProgress(bool active, long pos, long total)
			{
				if(!hwnd) return; 
				
				if(!taskbarList3)
				{
					CoCreateInstance(
						&CLSID_ITaskbarList, null, 1/+INPROC_SERVER+/, 
						&IID_ITaskbarList3, cast(void**) &taskbarList3
					).hrChk; 
					if(taskbarList3) taskbarList3.HrInit().hrChk; 
				}
				
				if(taskbarList3)
				{
					if(active)
					{
						taskbarList3.SetProgressState(hwnd, TBPFLAGS.NORMAL).hrChk; 
						taskbarList3.SetProgressValue(hwnd, pos, total).hrChk; 
					}
					else
					{ taskbarList3.SetProgressState(hwnd, TBPFLAGS.NOPROGRESS).hrChk; }
				}
			} 
		}
		
	} 
}
version(/+$DIDE_REGION Stuff saved from Draw2D+/all)
{
	//these are also used in ui.d
	enum HAlign : ubyte
	{left, center, right, justify} 	 //when the container width is fixed
	enum VAlign : ubyte
	{top, center, bottom, justify} 	 //when the container height is fixed
	enum YAlign : ubyte
	{top, center, bottom, baseline, stretch} 	//this aligns the y position of each cell in a line. baseline is 0.7ish
	
	//Standard LineStyles
	enum LineStyle : ubyte
	{
		normal	= 0,
		dot	= 2,
		dash	= 19,
		dashDot	= 29,
		dash2	= 35,
		dashDot2	= 44
	} 
	/+
		Todo: this is a piece of shit. dot is so long that it is already a fucking dash. 
			And what fucking format is this anyways???
	+/
	
	//Standard arrows
	private int encodeArrowStyle(int headArrow, int tailArrow, int centerNormal)
	{ return headArrow<<0 | tailArrow<<2 | centerNormal<<4; } 
	
	enum ArrowStyle : ubyte
	{
		none	= 0,
		arrow	= encodeArrowStyle(1,0,0),
		doubleArrow	= encodeArrowStyle(1,1,0),
		normalLeft	= encodeArrowStyle(0,0,1),
		normalRight	= encodeArrowStyle(0,0,2),
		arrowNormalLeft	= encodeArrowStyle(1,0,1),
		arrowNormalRight 	= encodeArrowStyle(1,0,2),
		vector	= encodeArrowStyle(1,2,0),
		segment	= encodeArrowStyle(2,2,0)
	} 
	
	enum SamplerEffect : ubyte
	{none, quad, karc} 
	
	struct GlobalShaderParams {
		float[] floats; 
		bool[] bools; 
	} 
	
	__gshared GlobalShaderParams globalShaderParams; 
	
	shared static this()
	{
		globalShaderParams.floats = [0.0f].replicate(8); 
		globalShaderParams.bools = [false].replicate(8); 
	} 
	
	interface IDrawing
	{
		ref float zoomFactor(); //for LOD
		ref float invZoomFactor(); 
		
		void translate(vec2); void scale(float); 
		void pop(); 
		
		bounds2 inputTransform(in bounds2); 
		vec2 inputTransform(in vec2); 
		bounds2 inverseInputTransform(in bounds2); 
		
		ref bounds2 clipBounds(); 
		void pushClipBounds(bounds2); 
		void popClipBounds(); 
		
		ref float fontHeight();  //ez a stickfont csak!!!
		ref float lineWidth(); 
		ref float pointSize(); 
		
		ref LineStyle lineStyle(); 
		ref ArrowStyle arrowStyle(); 
		
		@property het.math.RGB color(); 
		@property void color(het.math.RGB); 
		@property float alpha(); 
		@property void alpha(float a); 
		void point(in vec2); 
		
		void moveTo(float, float); void lineTo(float, float); 
		void moveTo(in vec2); void lineTo(in vec2); 
		void moveRel(float, float); void lineRel(float, float); 
		
		void line(in vec2 p0, in vec2 p1); 
		void hLine(float x0, float y, float x1); 
		void vLine(float x, float y0, float y1); 
		void drawRect(in bounds2); 
		void drawX(in bounds2); 
		void fillRect(in bounds2); 
		void fillRect(float x0, float y0, float x1, float y1); 
		void circle(in vec2 p, float r, float arc0=0, float arc1=2*PI); 
		void drawFontGlyph(
			int idx, in bounds2 b, in RGB8 bkColor = clBlack, 
			in int fontFlags = 0, in vec2 ySubRange = vec2(0, 1)
		); 
		void drawTexture(int idx, in bounds2 b, Flag!"nearest" nearest = Yes.nearest); 
		float textWidth(string text); //stickFont
		void textOut(
			vec2 p, string text, float width = 0, 
			HAlign align_ = HAlign.left, bool vertFlip = false
		); //stickFont
		void autoSizeText(vec2 p, string s, float aspect=1.0f); 
		void hGraph_f(
			float x0, float y0, in float[] data, float 
			xScale=1, float yScale=1
		); //resMon
		void bezier2(in vec2 A, in vec2 B, in vec2 C); //DIDE/message arrows
		void fillTriangle(in vec2 a, in vec2 b, in vec2 c); //not important
		
		
	} 
	struct RectAlign
	{
		align(1): import std.bitmanip; 
		mixin(
			bitfields!(
				HAlign,	"hAlign",	2,
				VAlign,	"vAlign",	2,
				bool,	"canShrink",	1,
				bool,	"canEnlarge",	1,
				bool,	"keepAspect",	1,
				bool,	"_dummy0",	1
			)
		); 
		
		this(HAlign hAlign, VAlign vAlign, bool canShrink, bool canEnlarge, bool keepAspect)
		{
			//Todo: dumb stupid copy paste constructor
			this.hAlign = hAlign; 
			this.vAlign = vAlign; 
			this.canShrink = canShrink; 
			this.canEnlarge = canEnlarge; 
			this.keepAspect = keepAspect; 
		} 
		
		bounds2 apply(in bounds2 rCanvas, in bounds2 rImage)
		{
			
			void alignOne(ref float dst1, ref float dst2,ref float src1, ref float src2, bool shrink, bool enlarge, int align_)
			{
				if(shrink && enlarge) return; 
				if(!shrink && (dst2-dst1<src2-src1))
				{
					//a bmp nagyobb es nincs kicsinyites
					final switch(align_)
					{
						case 0: 	src2 = src1+dst2-dst1; 	break; 
						case 1, 3: 	src1 = ((src1+src2)-(dst2-dst1))*.5; src2 = src1+dst2-dst1; 	break; 
						case 2: 	src1 = src2-(dst2-dst1); 	break; 
					}
				}
				if(!enlarge && (dst2-dst1>src2-src1))
				{
					//a bmp kisebb es nincs nagyitas
					final switch(align_)
					{
						case 0: 	dst2 = dst1+src2-src1; 	break; 
						case 1, 3: 	dst1 = ((dst1+dst2)-(src2-src1))*.5; dst2 = dst1+src2-src1; 	break; 
						case 2: 	dst1 = dst2-(src2-src1); 	break; 
					}
				}
			} 
			
			bounds2 rdst = rCanvas, rdst2 = rdst, rsrc = rImage; 
			alignOne(rdst2.left, rdst2.right, rsrc.left, rsrc.right, canShrink, canEnlarge, cast(int)hAlign); 
			alignOne(rdst2.top, rdst2.bottom, rsrc.top, rsrc.bottom, canShrink, canEnlarge, cast(int)vAlign); 
			if(keepAspect)
			{
				float 	a1 = rdst2.right-rdst2.left,	b1 = rdst2.bottom-rdst2.top,
					a2 = rImage.right-rImage.left,	b2 = rImage.bottom-rImage.top,
					r1 = a1/max(1, b1),	r2 = a2/max(1, b2); 
				if(r1<r2)
				{
					b1 = a1/max(0.000001f,r2); 
					final switch(cast(int)vAlign)
					{
						case 0: 	rdst2.top = rdst.top; 	break; 
						case 1, 3: 	rdst2.top = (rdst.top+rdst.bottom-b1)*.5; 	break; 
						case 2: 	rdst2.top = rdst.bottom-b1; 	break; 
					}
					rdst2.bottom = rdst2.top+b1; 
					rsrc.top = 0; rsrc.bottom = rImage.bottom-rImage.top; 
				}
				else if(r1>r2)
				{
					a1 = b1*r2; 
					final switch(cast(int)hAlign)
					{
						case 0: 	rdst2.left = rdst.left; 	break; 
						case 1, 3: 	rdst2.left = (rdst.left+rdst.right-a1)*.5; 	break; 
						case 2: 	rdst2.left = rdst.right-a1; 	break; 
					}
					rdst2.right = rdst2.left+a1; 
					rsrc.left = 0; rsrc.right = rImage.right-rImage.left; 
				}
			}
			
			return rdst2; 
		} 
		
	} 
	class View2D
	{
		alias F = double, V = Vector!(F, 2), B = Bounds!V; 
		
		private: 
		
		float 	m_logScale	= 0, //base value. all others are derived from it
			m_scale	= 1,
			m_invScale	= 1, /+1 -> 1unit = pixel on screen+/
			m_logScale_anim 	= 0; 
		V m_origin_anim; 
		bool animStarted; 
		
		B lastWorkArea; //detection change for autoZoom()
		
		//smart zooming stuff
		static struct ScrollTarget {
			bounds2 rect; 
			DateTime when; 
		} 
		
		ScrollTarget[] scrollTargets; 
		bool mustScroll; //a new scroll target has been added, so on next update it needs to scroll there
		
		public: 
		V origin; 
		
		float animSpeed = 0.5; //0=off, 0.3=normal, 0.9=slow
		
		//extra information from external source in screen space. All is in world coords
		vec2 clientSize; 
		V mousePos, mouseLast; 
		
		B screenBounds_anim, screenBounds_dest; 	/+
			Todo: maybe anim/destination should be 2 identical viewTransform struct.
			Not a boolean parameter in EVERY member...
		+/
		B workArea; 	//The last complete workarea.
		B workArea_accum; 	/+
			The current workarea being updated by glDraw() commands.
			There are only a few glDraw calls, so it can be double.
		+/
		auto subScreenArea = bounds2(0, 0, 1, 1); 	/+
			if there is some things on the screen that is
			in front of the view, it can be used to set
			the screen to a smaller portion of the viewPort
		+/
		bool centerCorrection; 	/+
			it is needed for center aligned images.
			Prevents aliasing effect on odd client widths/heights.
		+/
		bool scrollSlower; 	//It's the current 'shift' modifier state. also affects zoom
		bool _mustZoomAll; 	//schedule zoom all on the next draw
		
		
		
		static auto fromViewToView(View2D viewMain, View2D viewGui, bool animated=true)
		{
			/+ Use origin point for translation +/ 
			V worldOrigin = V(0, 0); 
			V screenOrigin = viewMain.worldToScreen(worldOrigin, animated); 
			V guiWorldOrigin = viewGui.screenToWorld(screenOrigin, animated); 
			
			/+ Use unit point for scale calculation +/
			V worldUnit = V(1, 0); 
			V screenUnit = viewMain.worldToScreen(worldUnit); 
			V guiWorldUnit = viewGui.screenToWorld(screenUnit); 
			
			float scale = guiWorldUnit.x - guiWorldOrigin.x; 
			V origin = guiWorldOrigin; 
			
			static struct Res
			{
				V origin; float scale; 
				V transform(V p) => p*scale + origin; 
				
				/+
					alternate way: /+Code: shift = origin/scale; => (p+shift)*scale;+/
					But the addition is at the same magnitude in both ways.
				+/
			} 
			return Res(origin, scale); 
		} 
		
		public: 
		
		@property bool isMouseInside() const
		{ return mousePos in subScreenBounds_anim; } 
		
		this()
		{} 
		
		override string toString() const
		{ return format!"View2D(%s, %s)"(origin, scale); } 
		
		@property
		{
			float logScale() const
			{ return m_logScale; } 	void	 logScale(float s)
			{
				m_logScale = s; 
				m_scale = pow(2, logScale); 
				m_invScale = 1/scale; 
			} 
			float scale()const
			{ return m_scale; } 	void scale(float s)
			{ logScale = log2(s); } 
			float invScale() const
			{ return m_invScale; } 	void invScale(float s)
			{ logScale = log2(1/s); } 	
		} 
		
		//animated stuff
		
		V origin_anim()const
		{ return m_origin_anim; } 
		float logScale_anim()const
		{ return m_logScale_anim; } 
		float scale_anim()const
		{ return pow(2, m_logScale_anim); } 	//zoomFactor
		float invScale_anim()const
		{ return 1.0f/scale_anim; } 	//pixelSize
		
		V subScreenOrigin()
		{
			V res = origin; 
			if(subScreenArea.valid) {
				auto subScreenShift = clientSize * (subScreenArea.center - V(.5)); //in pixels
				
				res += subScreenShift * invScale; 
			}
			return res; 
		} 
		
		V subScreenOrigin_anim()
		{
			V res = origin_anim; 
			if(subScreenArea.valid) {
				auto subScreenShift = clientSize * (subScreenArea.center - V(.5)); //in pixels
				//Todo: refactor this redundant crap
				
				res += subScreenShift * invScale_anim; 
			}
			return res; 
		} 
		
		B subScreenBounds_anim() const
		{
			/+
				Note: subsceen is the mostly visible area on the view's surface.
				The portion of the screen that remains visible aster the overlayed GUI.
			+/
			return B(
				mix(screenBounds_anim.topLeft, screenBounds_anim.bottomRight, subScreenArea.topLeft),
				mix(screenBounds_anim.topLeft, screenBounds_anim.bottomRight, subScreenArea.bottomRight)
			); 
		} 
		
		B subScreenBounds_dest() const
		{
			/+
				Note: subsceen is the mostly visible area on the view's surface.
				The portion of the screen that remains visible aster the overlayed GUI.
			+/
			return B(
				mix(screenBounds_dest.topLeft, screenBounds_dest.bottomRight, subScreenArea.topLeft),
				mix(screenBounds_dest.topLeft, screenBounds_dest.bottomRight, subScreenArea.bottomRight)
			); 
		} 
		
		vec2 clientSizeHalf()
		=> clientSize/2; 
		
		bounds2 visibleArea(bool animated = true)
		{
			V	mi = screenToWorld(V(0), animated),
				ma = screenToWorld(clientSize, animated); 
			return bounds2(mi, ma).sorted; 
		} 
		
		
		auto getOrigin(bool animated)
		{
			V res = animated ? origin_anim : origin; 
			if(centerCorrection) {
				with(clientSize) {
					if(x.iround&1) res.x += 0.5/getScale(animated); 
					if(y.iround&1) res.y += 0.5/getScale(animated); 
					//Opt: fucking slow, need to be cached
				}
			}
			return res; 
		} 
		auto getScale(bool animated)
		{
			float res = animated ? scale_anim : scale; 
			return res; 
		} 
		
		//Todo: make this transformation cached and fast!
		T worldToScreen(T)(in T world, bool animated=true)
		{ return ((world-getOrigin(animated))*getScale(animated)+clientSizeHalf); } 
		//Opt: fucking slow, need to be cached
		
		T screenToWorld(T)(in T screen, bool animated=true)
		{ return T((screen-clientSizeHalf)/getScale(animated) + getOrigin(animated)); } 
		
		//Scroll/Zoom User controls
		float scrollRate() const
		{ return scrollSlower ? 0.125f : 1; } 
		
		void scroll(T)(in T delta)
		{ origin -= delta*(scrollRate*invScale); } 
		void scrollH(T)(T delta)
		{ scroll(V(delta, 0)); } 
		void scrollV(T)(T delta)
		{ scroll(V(0, delta)); } 
		
		void zoom(float amount)
		{ scale = pow(2, log2(scale)+amount*scrollRate); } 
		
		enum DefaultOverZoomPercent = 8; 
		
		vec2 subScreenClientCenter() {
			return clientSize * subScreenArea.center; //in pixels
		} 
		
		void zoom(T)(in T bb, float overZoomPercent = DefaultOverZoomPercent)
		{
			if(!bb.valid || !subScreenArea.valid) return; 
			//corrigate according to subScreenArea
			auto realClientSize = clientSize * subScreenArea.size; //in pixels
			auto subScreenShift = clientSize * (subScreenArea.center - V(.5)); //in pixels
			
			origin = V(bb.center); 
			auto s = bb.size; 
			//maximize(s.x, .001f); maximize(s.y, .001f);
			auto sc = realClientSize/bb.size; 
			scale = min(sc.x, sc.y)*(1 - overZoomPercent*.01); //overzoom a bit
			
			//corrigate according to subScreenArea: shift
			origin -= subScreenShift * invScale; 
		} 
		
		void scrollZoomIn(T)(in T target, float overZoomPercent = DefaultOverZoomPercent)
		{ scrollZoom!(Yes.zoomIn)(target, overZoomPercent); } 
		void scrollZoom(Flag!"zoomIn" doZoomIn = No.zoomIn, T)(in T target, float overZoomPercent = DefaultOverZoomPercent)
		{
			if(!target.valid || !subScreenArea.valid) return; 
			
			//world space screen bounds offseted inside
			auto sb = subScreenBounds_dest; 
			if(overZoomPercent>0) {
				auto border = min(abs(sb.width), abs(sb.height))*(0.01f*overZoomPercent); 
				sb = sb.inflated(-border); 
			}
			
			//scale up the screen if the target donesn't fit inside
			const baseScale = doZoomIn ? 0.0001f : 1; 
			F requiredScale = max(max(baseScale, target.height/sb.height), max(baseScale, target.width/sb.width)); 
			if(requiredScale>baseScale) {
				const c = origin; 
				sb = (sb-c)*requiredScale+c; 
			}
			
			//calculate offset needed to shift target into screen
			F calcOfs(F s0, F s1, F t0, F t1)
			{ return s0>t0 ? s0-t0 : s1<t1 ? s1-t1 : 0; } 
			auto ofs = V(
				calcOfs(sb.left, sb.right , target.left, target.right ),
				calcOfs(sb.top , sb.bottom, target.top , target.bottom)
			); 
			
			//execute changes
			if(requiredScale>baseScale) scale = scale/requiredScale; 
			if(ofs) origin -= ofs; 
		} 
		
		void zoomAll_later()
		{ _mustZoomAll = true; } 
		
		void zoomAll()
		{ zoom(workArea); } 
		
		void zoomAll_immediate()
		{
			zoomAll; 
			skipAnimation; 
		} 
		
		void zoomAround(T)(in T screenPoint, float amount)
		{
			/+
				Todo: the zoom and the translation amount is not proportional.
				Fast zooming to the side looks bad. Zoom in center is ok.
			+/
			if(!amount) return; 
			auto sh = screenPoint-clientSizeHalf; 
			origin += sh*invScale; 
			zoom(amount); 
			origin -= sh*invScale; 
		} 
		void zoomAroundMouse(float amount)
		{ zoomAround(worldToScreen(mousePos), amount); } 
		
		///Automatically call zoomAll() when workArea changes
		bool autoZoom()
		{
			if(workArea.area>0 && chkSet(lastWorkArea, workArea)) {
				zoomAll; 
				return true; 
			}
			return false; 
		} 
		
		bool updateAnimation(float deltaTime)
		{
			float at = calcAnimationT(deltaTime, animSpeed); 
			if(chkSet(animStarted)) at = 1; 
			
			bool res; 
			res |= ((0xD96E285F33B4).檢(follow(m_origin_anim, origin, at, invScale*1e-2f))); 
			res |= ((0xD9C5285F33B4).檢(follow(m_logScale_anim, logScale, at, 1e-2f))); 
			return res; 
			
			/+
				Todo: Make better animation when zooming with mouse!
				Use not just a single large 'impulse' but a series of tiny zoomAround commands!
				The mouse wheel is a button anyways, so it is needed to stretch in time.
				A bell curve can be better maybe.
				But I don't wanna store a pivot point. There are multiple zoom/pan sources, 
				a single pivot point is unclear with lerp.
			+/
		} 
		
		//skips the animated moves to their destination immediately
		void skipAnimation() { updateAnimation(9999); } 
		
		//update smooth navigation. invalidates automatically
		/*
			bool _updateInternal(bool processActions){
				bool res;
				//if(processActions) res |= updateActions; -> call it manually with navigate()
				res |= updateAnimation(owner.deltaTime, true);
				return res;
			}
		*/
		
		@property string config()
		{ return format("%f %f %f", logScale, origin.x, origin.y); } 
		@property void config(string s)
		{
			try {
				auto a = s.split(' ').map!(x => to!float(x)); 
				if(a.length==3) {
					logScale = a[0]; 
					origin.x = a[1]; 
					origin.y = a[2]; 
				}
			}catch(Throwable) {}
		} 
		
		//Smart scrolling/zooming /////////////////////////////////////////////////////////
		
		void smartScrollTo(bounds2 rect)
		{
			if(!rect) return; 
			
			auto 	t	= application.tickTime,
				idx 	= scrollTargets.map!"a.rect".countUntil(rect); 
			
			if(idx>=0) {
				scrollTargets[idx].when = t; //just update the time
			}else {
				scrollTargets ~= ScrollTarget(rect, t); 
				mustScroll = true; 
			}
		} 
		
		void updateSmartScroll()
		{
			if(mustScroll.chkClear) {
				auto bnd = scrollTargets.map!"a.rect".fold!"a |= b"(bounds2.init); 
				if(bnd) { scrollZoom(bnd); }
			}
			
			//filter out too old rocts
			const t = now-1*second; 
			scrollTargets = scrollTargets.filter!(a => a.when>t).array; 
		} 
		
	} 
	
	/// Clamps worldCoord points into a view's visible subSurface
	alias RectClamperF	= RectClamper_!float, 
	RectClamperD 	= RectClamper_!double; 
	struct RectClamper_(F)
	{
		alias V = Vector!(F, 2), B = Bounds!V; 
		const {
			B outerBnd, innerBnd; 
			V center, innerHalfSize; 
		} 
		
		this(View2D view, float borderSizePixels)
		{
			auto ob = B(view.subScreenBounds_anim); 
			this(ob, ob.inflated(-view.invScale_anim*borderSizePixels)); 
		} 
		
		this(in B outerBnd, in B innerBnd)
		{
			this.outerBnd = outerBnd; 
			this.innerBnd = innerBnd; 
			center = outerBnd.center; 
			innerHalfSize = innerBnd.size/2; 
		} 
		
		private V clamp_noCenter(V p) const
		{
			p -= center; 
			if(p.x > innerHalfSize.x) p *= innerHalfSize.x/p.x; /*else*/
			if(p.x < -innerHalfSize.x) p *= -innerHalfSize.x/p.x; 
			
			if(p.y > innerHalfSize.y) p *= innerHalfSize.y/p.y; /*else*/
			if(p.y < -innerHalfSize.y) p *= -innerHalfSize.y/p.y; 
			return p; 
		} 
		
		V clamp(V p) const
		{ return clamp_noCenter(p) + center; } 
		
		V[2] clampArrow(in V p, float scale0=.99f, float scale1=1) const
		{
			//these are the flashing target arrows in DIDE on the edge of the screen
			auto cc = clamp_noCenter(p); 
			return [cc*scale0+center, cc*scale1+center]; 
		} 
		
		bool overlaps(in B b) const { return outerBnd.overlaps(b); } 
	} 
	/+
		Assistant: /+H1: View2D Graphics API Cheat Sheet+/
		
		/+H2: Core Properties+/
			/+Bullet: /+Highlighted: origin+/: World space center point (Vector2D)+/
			/+Bullet: /+Highlighted: scale+/: Zoom factor (1.0 = 1 unit = 1 pixel)+/
			/+Bullet: /+Highlighted: invScale+/: Pixel size in world units+/
			/+Bullet: /+Highlighted: animSpeed+/: Animation smoothness (0.0-0.9)+/
		
		/+H2: Coordinate Transformation+/
		/+
			Structured: // World → Screen
			vec2 screenPos = view.trans(worldPos); 
			vec2 screenPos = view.trans(worldPos, false); // skip animation
			
			// Screen → World  
			vec2 worldPos = view.screenToWorld(screenPos); 
			vec2 worldPos = view.screenToWorld(screenPos, false); // skip animation
		+/
		
		/+H2: Navigation Controls+/
		/+
			Structured: // Scroll
			view.scroll(vec2(dx, dy)); 	// Relative world units
			view.scrollH(pixels); 	// Horizontal pixels
			view.scrollV(pixels); 	// Vertical pixels
			
			// Zoom
			view.zoom(factor); 	// Relative zoom (logarithmic)
			view.zoomAround(screenPoint, factor); 	// Zoom around specific point
			view.zoomAroundMouse(factor); 	// Zoom around mouse position
			
			// View fitting
			view.zoom(bounds); 	// Fit bounds to view
			view.zoomAll(); 	// Fit workArea to view
			view.zoomAll_immediate(); 	// Instant fit
			view.autoZoom(); 	// Auto-fit when workArea changes
		+/
		
		/+H2: Viewport Management+/
		/+
			Structured: // Sub-screen area (for UI overlays)
			view.subScreenArea = bounds2(0.1, 0.1, 0.9, 0.9); 
			
			// Center correction (anti-aliasing)
			view.centerCorrection = true; 
			
			// Get visible area
			bounds2 visible = view.visibleArea(); 
			bounds2 visibleNow = view.visibleArea(false); // no animation
		+/
		
		/+H2: Mouse Interaction+/
		/+
			Structured: // Mouse position tracking
			vec2 worldMousePos = view.mousePos; 
			bool mouseInside = view.isMouseInside(); 
			
			// Screen bounds
			bounds2 screenBounds = view.subScreenBounds_anim(); 
		+/
		
		/+H2: Animation Control+/
		/+
			Structured: view.skipAnimation(); 	// Jump to target immediately
			view.updateAnimation(deltaTime, true); 	// Manual animation update
		+/
		
		/+H2: Smart Navigation+/
		/+
			Structured: view.smartScrollTo(targetBounds); 	// Queue smooth scroll-to
			view.updateSmartScroll(); 	// Process scroll queue
		+/
		
		/+H2: Configuration+/
		/+
			Structured: // Save/load view state
			string config = view.config; 
			view.config = savedConfig; 
		+/
		
		/+H2: Input Handling+/
		/+
			Structured: // Built-in navigation (keyboard + mouse)
			view.navigate(true, true); // Enable both input methods
			
			// Default controls:
			// - MMB/RMB: Pan
			// - Mouse Wheel: Zoom at mouse
			// - WASD: Keyboard panning  
			// - PgUp/PgDn: Keyboard zoom
			// - Shift: Slower movement
			// - Home: Zoom to fit
		+/
		
		/+H2: Work Area Management+/
		/+
			Structured: // Set drawing bounds
			view.workArea = calculatedBounds; 
			
			// Automatic fitting
			if(view.autoZoom()) {
				    // View was automatically adjusted
			}
		+/
		
		/+H2: Performance Notes+/
			/+Bullet: Transformation functions are computationally expensive+/
			/+Bullet: Use /+Highlighted: animated = false+/ for performance-critical operations+/
			/+Bullet: Center correction adds per-frame overhead+/
		
		/+Note: Usage(prompt_hit: 64, prompt_miss: 4948, completion: 704, HUF: 0.80, price: 100%)+/
	+/
}