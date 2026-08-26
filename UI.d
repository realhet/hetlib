module het.ui; 
version(/+$DIDE_REGION+/all)
{
	//originally it was public import het.opengl
	public import het; 
	public import het.win; 
	
	public import het.bitmap: Bitmap, bitmaps, BITMAPEFFECT, bitmapEffects; 
	import het.bitmap: segoeSymbolByName; 
	
	//public import het.inputs: 	inputs, KeyCombo, ClickDetector; 
	import het.inputs: 	rawMousePos, 
		/+for slider:+/slowMouse, mouseMoveRelX, mouseMoveRelY, mouseLock, mouseUnlock; 
	
	import het.parser: SyntaxKind, syntaxStyle; 
	
	import std.bitmanip: bitfields; 
	import std.traits, std.meta; 
	
	version(/+$DIDE_REGION OpenGL -> Vulkan transition+/all)
	{
		version(VulkanUI) {}else version = OpenGLUI; 
		
		//Todo: I have to manually comment these out because the buildSystem is lame and imports EVERYTHING
		//public import het.opengl: GLWindow, gl, GL_COLOR_BUFFER_BIT; import het.opengl: oldTextures = textures, DefaultFont_subTexIdxMap; 
		public import het.vulkanwin; 
		
		version(OpenGLUI)
		{
			
			alias UIWindow = GLWindow; 
			
			shared static this()
			{
				//static init///////////////////////////////
				initTextStyles; 
			} 
			
			alias Drawing = IDrawing; 
			enum BoldOffset = 1.0f/40 /+
				This is a deprecated constant for resizing bold text.
				Used in the old font shader.
			+/; 
			
			alias TexHandle = Typedef!(uint, 0, "TexHandle"); //The aame in Vulkan.
			
			//texture access
			
			TexHandle textures_getNow(File f) => TexHandle(oldTextures[f]); 
			void textures_invalidate(File f) { oldTextures.invalidate(f); } 
			auto textures_accessInfo(TexHandle stIdx)
			{
				auto info = oldTextures.accessInfo((cast(int)(stIdx))); 
				static struct Res { int width, height; } 
				with(info) return Res(width, height); 
			} 
			
			//texture statistics
			size_t textures_length() => oldTextures.length; 
			size_t textures_poolSizeBytes() => oldTextures.poolSizeBytes; 
			size_t textures_usedSizeBytes() => oldTextures.usedSizeBytes; 
			
			vec2 inputTransformFix(in vec2 p) => p; 
			bounds2 inputTransformFix(in bounds2 b) => b; 
			
		}
		
		version(VulkanUI)
		{
			
			
			alias UIWindow = VulkanWindow; 
			
			//must call initTextStyles from outside
			
			deprecated
			{
				
				alias Drawing = IDrawing; 
				
				enum BoldOffset = 1.0f/40 /+
					This is a deprecated constant for resizing bold text.
					Used in the old font shader.
				+/; 
				
				__gshared int[dchar] DefaultFont_subTexIdxMap; 
				//Used by UI, must be cleared after every megatexture GC
				
				__gshared Texture[File] g_tempLoadedTextures; 
				
				__gshared TexHandle delegate(File) gányolás_textures_getNow; 
				TexHandle textures_getNow(File f)
				=> gányolás_textures_getNow(f); 
				
				__gshared void delegate(File) gányolás_textures_invalidate; 
				void textures_invalidate(File f) 
				=> gányolás_textures_invalidate(f); 
				
				__gshared ivec2 delegate(TexHandle) gányolás_textures_getSize; 
				auto textures_accessInfo(TexHandle stIdx)
				{
					auto v = gányolás_textures_getSize(stIdx); 
					static struct Res { int width, height; } 
					return Res(v.x, v.y); 
				} 
				
				//texture statistics
				//Todo: implement these with a global system info collector object.
				
				private TextureManagerStats cachedTextureManagerStats; 
				private uint cachedTextureManagerStats_tick; 
				private ref const(TextureManagerStats) getTextureManagerStats()
				{
					if(cachedTextureManagerStats_tick.chkSet(application.tick))
					cachedTextureManagerStats = mainVulkanWindow.textureManagerStats; 
					return cachedTextureManagerStats; 
				} 
				
				size_t textures_length() => getTextureManagerStats.length_all; 
				size_t textures_poolSizeBytes() => getTextureManagerStats.totalBytes; 
				size_t textures_usedSizeBytes() => getTextureManagerStats.usedBytes; 
				
			} 
		}
		
		
		/+
			History:
			250930: Removed things:	Contaniner.CachedDrawing, GraphLabel, GraphNode, 
				ContainerGraph, MegaTexturing.debugDraw, GLWindow.drawMegaTextures,
				VisualizeHitStack
			/+Todo: Revive Graph thing with grammar example+/
			
			Replaced addOverlayDrawing with addDrawCallback, because it ain't need to creat a drawing instance.
			/+Todo: VirtualTreeView treeview graphics is broken. It can't capture a foreach loop.+/
			
			No more /+Code: new Drawing+/ remains, I can write a DrawingProxy now.
			
			/+Todo: Rewrite DIDE / bloodScreenEffect+/
			
			251001: View2D understood, refactored. Preparing for single view vulkan rendering.
			251002: Isolating texture and font handling stuff.
		+/
	}
	
	
	
	/+Todo: implement layouting as seen in /+Link: https://libfluid.org/docs/main+/+/
	//Todo: rename "hovered" -> "hot"
	//Todo: multiple 2D view controls in hetlib
	
	//enums/constants ///////////////////////////////////////
	
	//adjust the size of the original Tab character
	enum 
		VisualizeContainers	= (常!(bool)(0)),
		VisualizeContainerIds	= (常!(bool)(0)),
		VisualizeGlyphs	= (常!(bool)(0)),
		VisualizeTabColors	= (常!(bool)(0)), //Todo: spaces at row ends
		//VisualizeHitStack	= (常!(bool)(0)),
		VisualizeSliders	= (常!(bool)(0)),
		VisualizeCodeLineIndices 	= (常!(bool)(0)), //Todo: ezt csak a row-ban kene megcsinalni, runtime opcionalisra.
			
		addHitRectAsserts	= (常!(bool)(0)); //Verifies that Cell.Id is non null and unique
	//Todo: DIDE, look inside  enum statement  not just  enum block.   enum; enum{}
	
	//Todo: bug: NormalFontHeight = 18*4	-> RemoteUVC.d crashes.
	
	/+
		Todo: 241231 id generalas
		- adat pointer alapjan  (ref parameter vagy T*)
		- elmentett hash alapjan. Ugyanaz a hash, mint a DIDE.Inspector-nal.
		
		Ezekkel meg lehetne oldani az 1 soron levo dolgok kulonbozo ID-jét végre.
	+/
	
	enum TargetSurface { world = 0, gui = 1 } 
	
	version(/+$DIDE_REGION+/none) {
		immutable DefaultFontName = //this is the cached font
		"Segoe UI"
		//"Lucida Console"
		//"Consolas" <- too curvy
		//"Times New Roman"
		; 
	}
	
	immutable DefaultUIFontId = FontId.
	Segoe_UI
	//Times_New_Roman
	; 
	
	immutable
		DefaultFontHeight	= 18, /+Todo: This must be the same in Geometry Stream Processor too!+/
		InvDefaultFontHeight 	= 1.0f/DefaultFontHeight,
			
		LeadingTabWidth 	= 7.25f*4 	*(DefaultFontHeight/18.0f),	 LeadingTabAspect 	= LeadingTabWidth	/ DefaultFontHeight,
		InternalTabWidth	= 3.25f	*(DefaultFontHeight/18.0f),	 InternalTabAspect	= InternalTabWidth	/ DefaultFontHeight,
			
		MinScrollThumbSize	= 4, 
		DefaultScrollThickness 	= 15; 
	
	//static assert(DefaultFontHeight==18, "//fucking keep it on 18!!!!"); 
	
	
	Glyph newLineGlyph()
	{
		//newLineGlyph /////////////////////////////////////////////
		__gshared Glyph g; 
		return initOnce!g((){ auto a = new Glyph("\u240A\u2936\u23CE"d[1], tsNormal); a.innerSize = DefaultFontNewLineSize; return a; }()); 
	} 
	
	///Used for minimum length in a CodeRow if it's empty. Also the virtual newline chars at the end.
	enum DefaultFontNewLineSize = vec2(DefaultFontHeight*6/18, DefaultFontHeight); ///Ditto
	enum DefaultFontEmptyEditorSize = vec2(1, DefaultFontHeight); 
	
	
	immutable
		EmptyCellWidth	= 0,
		EmptyCellHeight	= 0,
		EmptyCellSize	= vec2(EmptyCellWidth, EmptyCellHeight); 
	
	private enum AlignEpsilon = .001f; //avoids float errors that come from float sums of subCell widths/heights
	
	
	//Global dependency injection shit //////////////////////////////
	
	//Todo: these ugly things are only here to separate uiBase for ui.
	
	__gshared RGB function() g_actFontColorFunct; 
	
	auto g_actFontColor()
	{
		assert(g_actFontColorFunct); 
		return  g_actFontColorFunct(); 
	} 
	
	__gshared float function() g_actFontHeightFunct; 
	
	auto g_actFontHeight()
	{
		assert(g_actFontHeightFunct); 
		return g_actFontHeightFunct(); 
	} 
	
	
	__gshared Drawing function(Container) g_getOverlayDrawingFunct; 
	
	auto g_getOverlayDrawing(Container cntr)
	{
		assert(g_getOverlayDrawingFunct); 
		return g_getOverlayDrawingFunct(cntr); 
	} 
	
	
	//Todo: Eliminate this dependency injection: addDrawCallback() should be maintained by het.uibase and not het.ui!!
	//Todo: uibase is merged with ui. This is no longer needed.
	__gshared void delegate(Drawing, Container) function(Container) g_getDrawCallbackFunct; 
	
	auto g_getDrawCallback(Container cntr)
	{
		assert(g_getDrawCallbackFunct); 
		return g_getDrawCallbackFunct(cntr); 
	} 
	
	
	void rememberEditedWrappedLines(Row row, WrappedLine[] wrappedLines)
	{
		import het.ui: im; 
		if(im.textEditorState.row is row)
		im.textEditorState.wrappedLines = wrappedLines; 
	} 
	
	void drawTextEditorOverlay(Drawing dr, Row row)
	{
		import het.ui: im; 
		if(im.textEditorState.row is row)
		{
			dr.translate(row.innerPos); 
			im.textEditorState.drawOverlay(dr, clWhite-row.bkColor); 
			dr.pop; 
		}
	} 
	
	
	//allows relative sizes to current fontHeight
	//15	: 15 pixels
	//15x	: 15*baseHeight
	float toWidthHeight(string s, float baseHeight)
	{
		s = s.strip; 
		if(s.endsWith('x'))
		{
			//12x
			return baseHeight*s[0..$-1].to!float; 
		}else
		{ return s.to!float; }
	} 
	
	///It is needed for syntax highlighter when it changes font.bold
	///Also used by CodeColumnBuilder
	float adjustBoldWidth(Glyph g, int prevFontFlags)
	{
		//Todo: also check monospaceness
		enum boldMask = 1; 
		if((prevFontFlags&boldMask) == (g.fontFlags&boldMask))
		return 0; 
		auto delta = g.innerHeight * (BoldOffset*2); 
		if(prevFontFlags&boldMask)
		delta = -delta; 
		g.outerSize.x += delta; 
		return delta; 
	} 
	
	private vec2 calcGlyphSize_clearType(in TextStyle ts, TexHandle stIdx)
	{
		auto info = textures_accessInfo(stIdx); 
		
		float	aspect	= float(info.width)/(info.height*3/*clearType x3*/); //Opt: rcp_fast
		auto	size	= vec2(ts.fontHeight*aspect, ts.fontHeight); 
		
		if(ts.bold)
		size.x += size.y*(BoldOffset*2); 
		
		return size; 
	} 
	
	private vec2 calcGlyphSize_image(/*in TextStyle ts,*/ TexHandle stIdx)
	{
		auto info = textures_accessInfo(stIdx); 
		
		//float aspect = float(info.width)/(info.height); //opt: rcp_fast
		auto size =  vec2(info.width, info.height); 
		
		//image frame goes here
		return size; 
	} 
	
	//Template Parameter Processing /////////////////////////////////
	
	private
	{
		//Todo: These should be templates
		
		bool is2(A, B)()
		{ return is(immutable(A)==immutable(B)); } 
		
		bool isBool	(A)()
		{ return is2!(A, bool	); } 
		bool isInt	(A)()
		{ return is2!(A, int	) || is2!(A, uint  ); } 
		bool isFloat	(A)()
		{ return is2!(A, float	) || is2!(A, double); } 
		bool isString(A)()
		{ return is2!(A, string); } 
		
		bool isSimple(A)()
		{ return isBool!A || isInt!A || isFloat!A || isString!A; } 
		
		bool isGetter(A, T)()
		{
			enum a = A.stringof, t = T.stringof; 
			return a.startsWith(t~" delegate()")
					|| a.startsWith(t~" function()"); 
		} 
		bool isSetter(A, T)()
		{
			enum a = A.stringof, t = T.stringof; 
			return a.startsWith("void delegate("~t~" ")
					|| a.startsWith("void function("~t~" "); 
		} 
		bool isEvent(A)()
		{ return isGetter!(A, void); } //event = void getter
		
		bool isCompatible(TDst, TSrc, bool	compiles, bool compilesDelegate)()
		{
			return (isBool	!TDst && isBool	!TSrc)
					|| (isInt	!TDst && isInt	!TSrc)
					|| (isFloat	!TDst && isFloat	!TSrc)
					|| (isString!TDst && isString!TSrc)
					|| !isSimple!TDst && (compiles || compilesDelegate); //assignment is working. This is the last priority
		} 
	} 
	
	
	
	
	
	auto paramByType(Tp, bool fallback=false, Tp def = Tp.init, T...)(T args)
	{
		Tp res = def; 
		
		enum isWrapperStruct = __traits(hasMember, Tp, "val") && Fields!Tp.length==1; 
		//is it encapsulated in a wrapper struct?  -> struct{ type val; }
		
		enum checkDuplicatedParams = 
		q{
			static assert(
				!__traits(compiles, duplicated_parameter), 
				"Duplicated parameter type: %s%s"
				.format(Tp.stringof, fallback ? "("~typeof(Tp.val).stringof~")" : "")
			); 
			enum duplicated_parameter = 1; 
		}; 
		
		static foreach_reverse(idx, t; T)
		{
			static if(
				//check simple types/structs
				isCompatible!(
					typeof(res), t, 
					__traits(compiles,	res = args[idx]), 
					__traits(compiles, res = args[idx].toDelegate)
				)
			)
			{
				static if(__traits(compiles, res = args[idx]))
				res = args[idx]; else
				res = args[idx].toDelegate; 
				mixin(checkDuplicatedParams); 
			}
			else static if(
				//check fallback struct.val
				fallback && isWrapperStruct && 
				isCompatible!(
					typeof(res.val), t, 
					__traits(compiles,	res.val = args[idx]), 
					__traits(compiles, res.val = args[idx].toDelegate)
				)
			)
			{
				static if(__traits(compiles, res.val = args[idx]))
				res.val = args[idx]; else
				res.val = args[idx].toDelegate; 
				mixin(checkDuplicatedParams); 
			}
		}
		
		static if(isWrapperStruct)
		return res.val; 
		else return res; 
	} 
	
	void paramCall(Tp, bool fallback=false, T...)(T args)
	{
		auto e = paramByType!(Tp, fallback)(args); 
		static assert(isEvent!(typeof(e)), "paramCallEvent() error: %s is not an event.".format(Tp.stringof)); 
		if(e !is null)
		e(); 
	} 
	
	template paramGetterType(T...)
	{
		static foreach(t; T)
		{
			static if(isPointer!t)
			{
				static if(isFunctionPointer!t)
				{
					static if(Parameters!t.length==0)
					alias paramGetterType = ReturnType!t; //type function()
				}else
				{
					alias paramGetterType = PointerTarget!t; //type*
				}
			}else static if(isDelegate!t)
			{
				static if(Parameters!t.length==0)
				alias paramGetterType = ReturnType!t; //type delegate()
			}
		}
		
		static assert(is(paramGetterType), "Unable to get paramGetterType "~ T.stringof); 
	} 
	
	void paramGetter(Tr, T...)(T args, ref Tr res)
	{
		//duplicate checking is in paramGetterType
		static foreach_reverse(idx, t; T)
		{
			static foreach(t; T)
			{
				static if(
					(isFunctionPointer!t || isDelegate!t) && Parameters!t.length==0 
					&& !is(ReturnType!t==void) && __traits(compiles, res = args[idx]().to!Tr)
				)
				{ res = args[idx]().to!Tr; }else static if(isPointer!t && __traits(compiles, res = (*args[idx]).to!Tr))
				{ res = (*args[idx]).to!Tr; }
			}
		}
	} 
	
	void paramSetter(Tr, T...)(T args, in Tr val)
	{
		//duplicates are allowed
		static foreach_reverse(idx, t; T)
		{
			static foreach(t; T)
			{
				static if(
					(isFunctionPointer!t || isDelegate!t) && Parameters!t.length==1 
					&& is(ReturnType!t==void) && __traits(compiles, args[idx](val.to!Tr))
				)
				{ args[idx](val.to!Tr); }else static if(isPointer!t && __traits(compiles, *args[idx] = val.to!Tr))
				{ *args[idx] = val.to!Tr; }
			}
		}
	} 
	
	struct TextStyle
	{
		FontId fontId; 
		ubyte fontHeight = DefaultFontHeight; 
		ubyte fontFlags; 
		RGB fg=clBlack, bg=clWhite; 
		
		alias fontColor = fg, bkColor = bg; 
		
		private static BOOLPROP(string name, int bitIdx)
		=> iq{
			@property
			{
				bool $(name)()const
				=> fontFlags.getBit($(bitIdx)); 
				bool $(name)(bool a)
				{ fontFlags = (cast(ubyte)(fontFlags.setBit($(bitIdx), a))); return $(name); } 
			} 
		}.text; 
		mixin(
			BOOLPROP("bold", 0), 
			BOOLPROP("italic", 1),
			BOOLPROP("underline", 2),
			BOOLPROP("strikeout", 3),
			BOOLPROP("transparent", 5)
		); 
		
		//Todo: implement monospaced font style for string literals, but firts I must refactor fontFlags.
		
		void modify(string[string] map)
		{
			map.rehash; 
			if(auto p="font"	in map)
			fontId = (*p).nameToStandardFontId; 
			if(auto p="fontHeight"	in map)
			fontHeight	  = (*p).toWidthHeight(g_actFontHeight).iround.to!ubyte; 
			if(auto p="bold"	in map)
			bold	  =	(*p).toInt!=0; 
			if(auto p="italic"	in map)
			italic		= (*p).toInt!=0; 
			if(auto p="underline"	in map)
			underline		 =	(*p).toInt!=0; 
			if(auto p="strikeout"	in map)
			strikeout		 =	(*p).toInt!=0; 
			if(auto p="transparent"	in map)
			transparent		= (*p).toInt!=0; 
			if(auto p="fontColor"	in map)
			fontColor	=	(*p).toRGB; 
			if(auto p="bkColor"	in map)
			bkColor	  =	(*p).toRGB; 
		} 
		void modify(string cmdLine)
		{ modify(commandLineToMap(cmdLine)); } 
		
		/// Lookup a syntax style and apply it to a TextStyle reference
		void applySyntax(Flag!"bkColor" setBkColor = Yes.bkColor)(SyntaxKind syntax)
		in(syntax<=SyntaxKind.max)
		{
			const ref fmt = syntaxStyle(syntax); 
			this.fontColor = fmt.fontColor; 
			if(setBkColor) this.bkColor = fmt.bkColor; 
			this.bold = fmt.fontFlags.getBit(0); 
			this.italic = fmt.fontFlags.getBit(1); 
			this.underline = fmt.fontFlags.getBit(2); 
		} 
		
		void applySyntax_noBk(SyntaxKind syntax)
		{ applySyntax!(No.bkColor)(syntax); } 
	} 
	
	auto tsSyntax(SyntaxKind syntax)
	{ auto ts = tsNormal; ts.applySyntax(syntax); return ts; } 
	
	
	mixin((
		(表([
			[q{clChapter},q{(RGB(221,   3,  48))}],
			[q{clAccent},q{(RGB(  0, 120, 215))}],
			[],
			[q{clMenuBk},q{(RGB(235, 235, 236))}],
			[q{clMenuHover},q{(RGB(222, 222, 222))}],
			[],
			[q{clLink},q{(RGB(  0, 120, 215))}],
			[q{clLinkHover},q{(RGB(102, 102, 102))}],
			[q{clLinkPressed},q{(RGB(153, 153, 153))}],
			[q{clLinkDisabled},q{
				(RGB(122, 122, 122))
				/+clWinBtnHoverBorder+/
			}],
			[],
			[q{clWinRed},q{(RGB(232,  17,  35))}],
			[q{clWinText},q{clBlack}],
			[q{clWinBackground},q{clWhite}],
			[q{clWinFocusBorder},q{clBlack}],
			[q{clWinBtn},q{(RGB(204, 204, 204))}],
			[q{clWinBtnHoverBorder},q{(RGB(122, 122, 122))}],
			[q{clWinBtnPressed},q{clWinBtnHoverBorder}],
			[q{clWinBtnDisabledText},q{clWinBtnHoverBorder}],
			[q{clHintText},q{clWinText}],
			[q{clHintBk},q{(RGB(236, 233, 216))}],
			[q{clHintDetailsText},q{clWinText}],
			[q{clHintDetailsBk},q{clWhite}],
			[],
			[q{clSliderLine},q{clLinkPressed}],
			[q{clSliderLineHover},q{clLinkHover}],
			[q{clSliderLinePressed},q{clLinkPressed}],
			[q{clSliderThumb},q{clAccent}],
			[q{clSliderThumbHover},q{(RGB( 23,  23,  23))}],
			[q{clSliderThumbPressed},q{clWinBtn}],
			[q{clSliderHintBorder},q{clMenuBk}],
			[q{clSliderHintBk},q{clWinBtn}],
			[],
			[q{clScrollBk},q{clMenuBk}],
			[q{clScrollThumb},q{clWinBtn}],
			[q{clScrollThumbPressed},q{clWinBtnPressed}],
		]))
	) .GEN!q{(mixin(求map(q{r},q{rows},q{r.join('=')}))).format!q{const %-(%s,%); }}); 
	
	//TextStyles ////////////////////////////////////////////
	
	__gshared TextStyle tsNormal, tsComment, tsError, tsBold, tsBold2, tsCode, tsQuote, tsLink, tsTitle, tsChapter, tsChapter2, tsChapter3,
		tsBtn, tsKey, tsLarger, tsSmaller, tsHalf; 
	
	__gshared TextStyle*[string] textStyles; 
	
	TextStyle newTextStyle(string name)(in TextStyle base, string props)
	{
		TextStyle ts = base; 
		ts.modify(props); 
		return ts; 
	} 
	
	
	//https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-getsyscolor
	
	
	void initTextStyles()
	{
		__gshared bool initialized; if(initialized) return; scope(exit) initialized = true; 
		
		
		
		void a(string n, ref TextStyle r, in TextStyle s, void delegate() setup = null)
		{
			r = s; 
			if(setup!is null)
			setup(); 
			textStyles[n] = &r; 
		} 
		
		//relativeFontHeight ()
		ubyte rfh(float r)
		{ return (DefaultFontHeight*(r/18.0f)).iround.to!ubyte; } 
		
		
		a("normal"	, tsNormal	, TextStyle(DefaultUIFontId, rfh(18), 0, clBlack, clWhite)); 
		a("larger"	, tsLarger	, tsNormal, { tsLarger.fontHeight = rfh(22); }); 
		a("smaller"	, tsSmaller	, tsNormal, { tsSmaller.fontHeight = rfh(14); }); 
		a("half"	, tsHalf	, tsNormal, { tsHalf.fontHeight = rfh(9); }); 
		a("comment"	, tsComment	, tsNormal, { tsComment.fontHeight = rfh(12); }); 
		a("error"	, tsError	, tsNormal,	{ tsError.bold = tsError.underline = true; tsError.bkColor = clRed; tsError.fontColor = clYellow; }); 
		a("bold"	, tsBold	, tsNormal, { tsBold.bold = true; }); 
		a("bold2"	, tsBold2	, tsBold	, { tsBold2.fg = clChapter; }); 
		a("quote"	, tsQuote	, tsNormal,	{ tsQuote.italic = true; }); 
		a("code"	, tsCode	, tsNormal, { tsCode.fontId = FontId.Lucida_Console; tsCode.fontHeight = rfh(18); tsCode.bold = false; }); //Todo: should be half bold?
		a("link"	, tsLink	, tsNormal, { tsLink.underline = true; tsLink.fg = clLink; }); 
		a("title"	, tsTitle	, tsNormal,	{ tsTitle.bold = true; tsTitle.fg = clChapter; tsTitle.fontHeight = rfh(64); }); 
		a("chapter"	, tsChapter	, tsTitle , { tsChapter.fontHeight = rfh(40); }); 
		a("chapter2", tsChapter2, tsTitle , { tsChapter2.fontHeight = rfh(32); }); 
		a("chapter3", tsChapter3, tsTitle , { tsChapter3.fontHeight = rfh(27); }); 
		
		a("btn"						 , tsBtn				 , tsNormal, { tsBtn.bkColor =  clWinBtn; }); 
		a("key"						 , tsKey				 , tsSmaller, { tsKey.bkColor =  RGB(236, 235, 230); tsKey.bold = true; }); 
		
		textStyles["" ] = &tsNormal; 
		textStyles["n" ] = &tsNormal; 
		textStyles["b" ] = &tsBold; 
		textStyles["b2"] = &tsBold2; 
		textStyles["q" ] = &tsQuote; 
		textStyles["c" ] = &tsCode; 
		
		textStyles.rehash; 
	} 
	
	
	
	bool updateTextStyles()
	{
		//flashing error
		bool act = (QPS.value(second)/60*132).fract<0.66; 
		tsError.fontColor	= act ? clYellow : clRed; 
		tsError.bkColor	= act ? clRed : clYellow; 
		
		if(tsError.underline != act)
		{ tsError.underline = act; return true; }else return false; 
	} 
	
	//Helper functs ///////////////////////////////////////////
	
	private bool isSame(T1, T2)()
	{ return is(immutable(T1)==immutable(T2)); } 
	
	//Todo: tag() must be inside im.
	string tag(string s)
	{ return "\u00B6"~s~"\u00A7"; } 
	
	string unTag(string s)
	{
		//converts tag characters to their visual symbols
		string res; 
		res.reserve(s.length); 
		
		foreach(dchar ch; s)
		switch(ch)
		{
			case '\u00A7': res ~= tag("char 0xA7"); break; 
			case '\u00B6': res ~= tag("char 0xB6"); break; 
			default: res ~= ch; 
		}
		
		return res; 
	} 
	
	bool startsWithTag(ref string s, string tag)
	{
		tag = "\u00B6"~tag~"\u00A7"; 
		if(s.startsWith(tag))
		{
			s = s[tag.length..$]; 
			return true; 
		}
		return false; 
	} 
	
	void setParam(T)(string[string] p, string name, void delegate(T) dg)
	{
		if(auto a = name in p)
		{
			static if(is(T == RGB))
			{ dg(toRGB(*a)); }else
			{
				auto v = (*a).to!T; 
				dg(v); 
			}
		}
	} 
	
	void spreadH(Cell[] cells, in vec2 origin = vec2(0))
	{
		float cx = origin.x; 
		foreach(c; cells)
		{
			c.outerPos = vec2(cx, origin.y); 
			cx += c.outerWidth; 
		}
	} 
	
	void spreadV(Cell[] cells, in vec2 origin = vec2(0))
	{
		float cy = origin.y; 
		foreach(c; cells)
		{
			c.outerPos = vec2(origin.x, cy); 
			cy += c.outerHeight; 
		}
	} 
	
	void spreadH(Cell[] cells, float x)
	{
		foreach(c; cells)
		{
			c.outerPos.x = x; 
			x += c.outerWidth; 
		}
	} 
	
	void spreadV(Cell[] cells, float y)
	{
		foreach(c; cells)
		{
			c.outerPos.y = y; 
			y += c.outerHeight; 
		}
	} 
	
	float maxOuterWidth (Cell[] cells, float def = EmptyCellWidth )
	{ return cells.empty ? def : cells.map!"a.outerWidth" .maxElement; } 
	float maxOuterHeight(Cell[] cells, float def = EmptyCellHeight)
	{ return cells.empty ? def : cells.map!"a.outerHeight".maxElement; } 
	
	float maxOuterRight (Cell[] cells, float def = EmptyCellWidth )
	{ return cells.empty ? def : cells.map!"a.outerRight" .maxElement; } 
	float maxOuterBottom(Cell[] cells, float def = EmptyCellWidth )
	{ return cells.empty ? def : cells.map!"a.outerBottom" .maxElement; } 
	
	vec2 maxOuterSize(Cell[] cells, vec2 def = EmptyCellSize)
	{ return vec2(maxOuterRight(cells, def.x), maxOuterBottom(cells, def.y)); } 
	
	float totalOuterWidth (Cell[] cells, float def = EmptyCellWidth )
	{ return cells.empty ? def : cells.map!"a.outerWidth" .sum; } 
	float totalOuterHeight(Cell[] cells, float def = EmptyCellHeight)
	{ return cells.empty ? def : cells.map!"a.outerHeight".sum; } 
	
	float calcFlexSum(Cell[] cells)
	{ return cells.map!"a.flex.value.value".sum; } 
	
	bool isWhite(const Cell c)
	{ auto g = cast(const Glyph)c; return g && g.isWhite; } 
	
	void adjustTabSize(Cell c, bool isLeading)
	{ c.outerWidth = c.outerHeight * (isLeading ? LeadingTabAspect : InternalTabAspect); } 
	
	
	
	struct Padding
	{
		//This is the same as Margin
		//alias all this; not working that way
		
		//float top=0, right=0, bottom=0, left=0; 
		
		UpperFloat top, right, bottom, left; 
		@property
		{
			float all() const
			{ return avg(horz, vert); } 
			void all(float a)
			{ left = a, right = left, top = left, bottom = left; } 
			
			float horz() const
			{ return avg(left, right); } 
			void horz(float a)
			{ left = a, right = left; } 
			float vert() const
			{ return avg(top, bottom); } 
			void vert(float a)
			{ top = a, bottom = top; } 
		} 
		
		private static float toF(string s)
		{ return s.toWidthHeight(g_actFontHeight); } 
		
		void opAssign(in string s)
		{ setProps(s); }  void opAssign(in float f)
		{ set(f); } 
		
		void setProps(in string s)
		{
			//shorthand
			if(s.empty) return; 
			auto p = s.split(' ').filter!"!a.empty".array; 
			if(p.empty) return; 
			
			float f()
			{ auto a = toF(p[0]); p = p[1..$]; return a; } 
			
			switch(p.length)
			{
				case 4: top = f; right = f; bottom = f; left = f; break; 
				case 3: top = f; horz = f; bottom = f; break; 
				case 2: vert = f; horz = f; break; 
				case 1: all = f; break; 
				default: enforce(false, "Invalid padding/margin shorthand format."); 
			}
		} 
		
		void setProps(string[string] p, string prefix)
		{
			p.setParam(prefix, (string s){ setProps(s); }); 
			
			p.setParam(prefix~".all"	, (string s){ all	= toF(s); }); 
			p.setParam(prefix~".horz"	, (string s){ horz	= toF(s); }); 
			p.setParam(prefix~".vert"	, (string s){ vert	= toF(s); }); 
			p.setParam(prefix~".left"	, (string s){ left	= toF(s); }); 
			p.setParam(prefix~".right"	, (string s){ right	= toF(s); }); 
			p.setParam(prefix~".top"	, (string s){ top	= toF(s); }); 
			p.setParam(prefix~".bottom", (string s){ bottom	= toF(s); }); 
		} 
		
		void set(float a)
		{ top = right = bottom = left = a; } 
		
		void set(float a, float b)
		{
			top = bottom = a; 
			left = right = b; 
		} 
		
		void set(float a, float b, float c, float d)
		{ top = a, right = b, bottom = c, left = d; } 
		
		void apply(T)(ref T r, float scale)
		{
			r.left 	+= scale*left,
			r.top 	+= scale*top,
			r.right 	-= scale*right,
			r.bottom 	-= scale*bottom; 
		} void apply(T)(ref T r)
		{
			r.left 	+= left,
			r.top 	+= top,
			r.right 	-= right,
			r.bottom 	-= bottom; 
		} 
		
		void unapply(T)(ref T r)
		{ apply(r, -1); } 
		
		this(float a) { set(a); } 
		this(float a, float b) { set(a, b); } 
		this(float a, float b, float c, float d) { set(a, b, c, d); } 
	} 
	
	alias Margin = Padding; 
	
	enum BorderStyle : ubyte
	{
		none, normal, dot, dash, dashDot, dash2, dashDot2, double_,
		halfFilletIn, halfFilletOut, fullFilletIn, fullFilletOut
	} 
	
	auto toBorderStyle(string s)
	{
		//synomyms
		if(s=="single")
		s="normal"; 
		else if(s=="double") s="double_"; 
		return s.to!BorderStyle; 
	} 
	
	struct UpperFloat
	{
		/+This is a way too simple version of Float16+/
		
		ushort _raw;  //Only store the 16 upper bits.  Enough for font sizes and such.
		@property value() const 
		=> uintBitsToFloat((cast(uint)(_raw))<<16);  @property value(float a)
		{ _raw = (cast(ushort)(a.floatBitsToUint>>16)); } 
		alias this = value; 
		this(float a) { this.value = a; } 
		
		bool opCast(B:bool)() const
		=> !!_raw /+just a nonzero check+/; 
		
		UpperFloat opAssign(float a)
		{ this.value = a; return this; } 
		
		UpperFloat opOpAssign(string op)(float rhs)
		{ this.value = mixin("this.value"~op~"rhs"); return this; } 
	} 
	
	
	struct Border
	{
		UpperFloat width; 
		ubyte flags; 
		RGB color = clBlack; 
		
		@property style() const 
		=> (cast(BorderStyle)(flags.getBits(0, 4))); 	@property style(BorderStyle a)
		{ flags = (cast(ubyte)(flags.setBits(0, 4, a))); } 
		@property inset() const 
		=> !!flags.getBit(4); 	@property inset(bool a)
		{ flags = (cast(ubyte)(flags.setBits(4, 1, a))); } 
		@property extendBottomRight() const 
		=> !!flags.getBit(5); 	@property extendBottomRight(bool a)
		{ flags = (cast(ubyte)(flags.setBits(5, 1, a))); } 
		@property borderFirst() const 
		=> !!flags.getBit(6); 	@property borderFirst(bool a)
		{ flags = (cast(ubyte)(flags.setBits(6, 1, a))); } 
		
		@property isLineBorder() => mixin(界3(q{mixin(舉!((BorderStyle),q{normal}))},q{style},q{mixin(舉!((BorderStyle),q{double_}))})); 
		@property isShadedBorder() => style>mixin(舉!((BorderStyle),q{double_})); 
		@property valid() const
		=> !!style && !!width; bool opCast(B:bool)() const
		=> valid; 
		
		
		this(
			float width, BorderStyle style=BorderStyle.normal, RGB color = clBlack,
			bool inset=false /+border has no allocated space, it is just painted over+/, 
			bool extendBottomRight=false /+for grid cells+/, 
			bool borderFirst=false /+for code editor: it is possible to make round borders with it.+/
		)
		{
			this.width = width; 
			this.color = color; 
			this.style = style; 
			this.inset = inset; 
			this.extendBottomRight = extendBottomRight; 
			this.borderFirst = borderFirst; 
		} 
		
		float gapWidth() const
		=> inset ? 0 : width; //effective borderWidth
		
		void opAssign(in string s)
		{ setProps(s); } 
		
		void setProps(in string s)
		{
			//shortHand: [width] style [color]
			
			if(s.empty) return; 
			auto p = s.split(' ').filter!"!a.empty".array; 
			if(p.empty) return; 
			
			//Todo: the properties can be in any order.
			//Todo: support the inset property
			
			bool hasWidth; 
			if(p[0][0].isDigit)
			{
				hasWidth = true; width = p[0].to!float; 
				p = p[1..$]; if(p.empty) return; 
			}
			
			style = p[0].toBorderStyle; 
			if(!hasWidth && style!=BorderStyle.none)
			width = 1 /+default width+/; 
			p = p[1..$]; 
			
			color = ((p.empty)?(g_actFontColor):(p[0].toRGB)); 
		} 
		
		void setProps(string[string] p, string prefix)
		{
			p.setParam(prefix, (string s){ setProps(s); }); 
			
			p.setParam(prefix~".width", (string	a){ width = a.toWidthHeight(g_actFontHeight); }); 
			p.setParam(prefix~".color", (RGB	a){ color = a; }); 
			p.setParam(prefix~".style", (string	a){ style = a.toBorderStyle; }); 
		} 
		
		
		bounds2 adjustBounds(in bounds2 bb)
		{ bounds2 res = bb; if(extendBottomRight) res.high += width.value; return res; } 
		void drawLineBorder(Drawing dr, in bounds2 bCenter)
		{
			const float bw = width; 
			const isDouble = style==BorderStyle.double_; 
			
			dr.lineStyle = style.toLineStyle; 
			dr.color = color; 
			dr.lineWidth = bw * (isDouble ? 0.33f : 1); 
			
			const bb = adjustBounds(bCenter); 
			
			void doit(float sh=0)
			{
				const m = bw*sh; 
				auto r = ((m)?(bb.inflated(m)):(bb)); 
				if(!r.empty)	{ dr.drawRect(r); }
				else	{
					dr.line(r.topLeft, r.bottomLeft); 
					/+
						Just a vertical line. 
						Can be used as a separator.
					+/
				}
			} 
			
			if(isDouble)	{
				doit(-0.333f); 
				doit( 0.333f); 
			}else	{ doit; }
		} 
		
		void drawShadedBorder(Drawing dr, in bounds2 bOuter)
		{
			with(BorderStyle)
			if(
				const bs = style.among(
					halfFilletIn, halfFilletOut, 
					fullFilletIn, fullFilletOut
				)
			)
			{
				const float bw = width; 
				
				static bevel = mixin(體!((BevelParams),q{param : .5})); 
				bevel.rounding = bevel.width = bw/2; 
				if(bs<=2) bevel.width /= 2; 
				bevel.inverted = !!bs.among(1, 3); 
				static shape = mixin(體!((ShapeParams),q{})); 
				
				auto gfx = (cast(GfxBuilder)(dr.getGfxBuilder)); 
				gfx.PC = color; 
				gfx.drawShape(bOuter, shape, bevel); 
			}
		} 
	} 
	
	LineStyle toLineStyle(BorderStyle style)
	=> style.predSwitch(
		BorderStyle.dot	, LineStyle.dot,
		BorderStyle.dash	, LineStyle.dash,
		BorderStyle.dashDot	, LineStyle.dashDot,
		BorderStyle.dash2	, LineStyle.dash2,
		BorderStyle.dashDot2	, LineStyle.dashDot2,
			LineStyle.normal
	); 
	
	struct FlexAmount
	{ UpperFloat value=0; alias this = value; } 
	static assert(FlexAmount.sizeof==2); 
	
	///This struct is returned by locate()
	struct CellLocation
	{
		Cell cell; 
		vec2 localPos; 	//innerPos is the origin, not outerPos. It's on the containers client area.
		bounds2 globalOuterBounds; 	//absolute outerBounds
		
		vec2 calcSnapOffsetFromPadding(float epsilon)
		{
			
			static float doit(float coord, float innerSize, float pad0, float pad1, float epsilon)
			{
				epsilon = min(innerSize*.5f, epsilon); 
				if(coord.inRange(-pad0, 0))
				return -coord + epsilon; 
				coord -= innerSize; 
				if(coord.inRange(0, pad1))
				return -coord - epsilon; 
				return 0; 
			} 
			
			with(cell)
			return vec2(
				doit(localPos.x, innerSize.x, padding.left, padding.right, epsilon),
						doit(localPos.y, innerSize.y, padding.top, padding.bottom, epsilon)
			); 
			
		} 
		
	} 
	
	class Cell
	{
		vec2 outerPos, outerSize; 
		
		this()
		{} this(vec2 pos, vec2 size)
		{ outerPos = pos; outerSize = size; } 
		
		///Optionally the container can have a parent.
		inout(Container) getParent() inout
		=> null; 
		void setParent(Container p)
		{} 
		
		auto thisAndAllParents(
			Base : Cell = Cell, bool thisToo = true, 
			bool isConst=is(typeof(this)==const)
		)() inout
		{
			
			static struct ParentRange
			{
				private Cell act; 
				
				private void skip()
				{
					static if(is(Base==Cell))
					{}
					else
					while(!empty && (cast(Base)act is null))
					popFront; 
					
				} 
				
				this(const Cell a)
				{ act = cast()a; skip; } 
				
				@property bool empty() const
				{ return act is null; } 
				void popFront()
				{ act = act.getParent; skip; } 
				
				auto front()
				{
					static if(isConst)
					return cast(const	Base)act; 
					else return cast(Base)act; 
				} 
			} 
			
			return ParentRange(thisToo ? this : getParent); 
		} 
		
		auto allParents(Base : Cell = Container)() inout
		{ return thisAndAllParents!(Base, false); } 
		
		ref FlexAmount flex()
		{
			static FlexAmount nullFlex; return nullFlex; 
			//Todo: this is bad, but fast. maybe do it with a setter and const ref.
		} 
		ref Margin	margin()
		{ static Margin nullMargin; return nullMargin	; } 
		ref Border border ()
		{ static Border nullBorder; return nullBorder	; } 
		ref Padding padding()
		{ static Padding nullPadding; return nullPadding; }  //Todo: inout ref
		
		version(/+$DIDE_REGION SelectionManager  virtual functs+/all)
		{
			bool getSelected()
			{ return false; } 
			void setSelected(bool b)
			{} 
			bool getOldSelected()
			{ return false; } 
			void setOldSelected(bool b)
			{ } 
			
			bounds2 getBounds()
			{ return outerBounds; } 
		}
		
		float extraMargin()	const
		{ return (VisualizeContainers && cast(Container)this)? 3:0; } 
		vec2 topLeftGapSize()	const
		{
			with(cast()this)
			return vec2(
				margin.left	+ extraMargin + border.gapWidth+padding.left ,
				margin.top 	+ extraMargin + border.gapWidth+padding.top   
			); 
		} 
		vec2 bottomRightGapSize()	const
		{
			with(cast()this)
			return vec2(
				margin.right	+ extraMargin + border.gapWidth+padding.right,
				margin.bottom 	+ extraMargin + border.gapWidth+padding.bottom
			); 
		} 
		vec2 totalGapSize()	const
		{ return topLeftGapSize + bottomRightGapSize; } 
		
		//Todo: remove 'Size' from 'GapSize'!   It's implicit.
		
		
		@property
		{
			//accessing the raw values as an lvalue
			//version 1: property setters+getters. No += support.
			/*
				auto outerX	() const { return outerPos.x; } void outerX(float v) { outerPos.x = v; }
				auto outerY	() const { return outerPos.y; } void outerY(float v) { outerPos.y = v; }
				auto innerWidth	() const { return innerSize.x; } void innerWidth (float v) { innerSize.x = v; }
				auto innerHeight() const { return innerSize.y; } void innerHeight(float v) { innerSize.y = v; }
			*/
			
			//version 2: "auto ref const" and "auto ref" lvalues. Better but the code is redundant.
			auto ref outerX	() const
			{ return outerPos .x; } 	auto ref outerX	()
			{ return outerPos .x; } 
			auto ref outerY	() const
			{ return outerPos .y; } 	auto ref outerY	()
			{ return outerPos .y; } 
			auto ref outerWidth	() const
			{ return outerSize.x; } 	auto ref outerWidth	()
			{ return outerSize.x; } 
			auto ref outerHeight() const
			{ return outerSize.y; } 	auto ref outerHeight()
			{ return outerSize.y; } 
		} 
		
		@property
		{
			//calculated properties. No += operators are allowed.
			
			const(vec2) innerPos () const
			{ return outerPos+topLeftGapSize; } 	void innerPos (in vec2 p)
			{ outerPos	= p-topLeftGapSize; } 
			const(vec2) innerSize() const
			{ return outerSize-totalGapSize; } 	void innerSize(in vec2 s)
			{ outerSize	= s+totalGapSize; } 
			auto innerBounds() const
			{ return bounds2(innerPos, innerPos+innerSize); } 	void innerBounds(in bounds2 b)
			{ innerPos =	b.low; innerSize = b.size; } 
			auto outerBounds() const
			{ return bounds2(outerPos, outerPos+outerSize); } 	void outerBounds(in bounds2 b)
			{ outerPos =	b.low; outerSize = b.size; } 
			
			auto outerBottomRight()
			{ return outerPos+outerSize; } 
			
			auto borderBounds(float location=0.5f)()
			{
				const hb = border.width*location + extraMargin; 
				return bounds2(
					outerPos	+ (vec2((float(margin.left)) , (float(margin.top))   ) + hb),
					outerBottomRight 	- (vec2((float(margin.right)), (float(margin.bottom))) + hb)
				); 
			} 
			auto borderBounds_inner()
			{ return borderBounds!1; } 
			auto borderBounds_outer()
			{ return borderBounds!0; } 
			
			auto innerX() const
			{ return innerPos.x; } 	void innerX(float v)
			{ outerPos.x = v-topLeftGapSize.x; } 
			auto innerY() const
			{ return innerPos.y; } 	void innerY(float v)
			{ outerPos.y = v-topLeftGapSize.y; } 
			auto innerWidth () const
			{ return innerSize.x; } 	void innerWidth (float v)
			{ outerSize.x = v+totalGapSize.x; } 
			auto innerHeight() const
			{ return innerSize.y; } 	void innerHeight(float v)
			{ outerSize.y = v+totalGapSize.y; } 
			
			alias innerLeft = innerX; 
			alias innerTop = innerY; 
			auto innerRight() const
			{ return innerX + innerWidth; } 
			auto innerBottom() const
			{ return innerY + innerHeight; } 
			
			alias outerLeft = outerX; 
			alias outerTop = outerY; 
			auto outerRight	() const
			{ return outerX+outerWidth; } 
			auto outerBottom() const
			{ return outerY+outerHeight; } 
			
			auto innerCenter() const
			{ return innerPos + innerSize*.5f; } 
			
			auto ref outerTopLeft	  () const
			{ return outerPos; } auto ref outerTopLeft	  ()
			{ return outerPos; } 
			auto outerTopRight	  () const
			{ return outerPos + vec2(outerWidth, 0); } 
			auto outerBottomRight() const
			{ return outerPos + outerSize; } 
			auto outerBottomLeft () const
			{ return outerPos + vec2(0, outerHeight); } 
			/+
				float leftGap()const 
				{ return topLeftGapSize.x; } 
				float rightGap()const 
				{ return bottomRightGapSize.x; } 
				float topGap()const 
				{ return topLeftGapSize.y; } 
				float bottomGap()const 
				{ return bottomRightGapSize.y; } 
				/+
					Todo: nem tudom belerakni, tul nagy a nevter a DideWorkspace-ben!  
					Amint azt megoldottam, ezeket a gap elereseket vissza lehet hozni!
				+/
			+/
			
			/+
				Note: when working with controls, it is like specify border and then the width, 
				not including the border. So width is mostly means innerWidth
			+/
			
			alias pos = outerPos; 
			alias size = innerSize; 
			alias width = innerWidth; 
			alias height = innerHeight; 
		} 
		
		bounds2 getHitBounds()
		{ return borderBounds_outer; } //Used by hittest. Can override.
		
		private void notImpl(string s)
		{ raise(s~" in "~typeof(this).stringof); } 
		
		//params
		void setProps(string[string] p)
		{
			p.setParam("width" , (string s){ width	= s.toWidthHeight(g_actFontHeight); }); 
			p.setParam("height", (string s){ height	= s.toWidthHeight(g_actFontHeight); }); 
			p.setParam("innerWidth" , (string s){ innerWidth	= s.toWidthHeight(g_actFontHeight); }); 
			p.setParam("innerHeight", (string s){ innerHeight	= s.toWidthHeight(g_actFontHeight); }); 
			p.setParam("outerWidth" , (string s){ outerWidth	= s.toWidthHeight(g_actFontHeight); }); 
			p.setParam("outerHeight", (string s){ outerHeight	= s.toWidthHeight(g_actFontHeight); }); 
		} 
		
		final void setProps(string cmdLine)
		{ setProps(cmdLine.commandLineToMap); } 
		
		void draw(Drawing dr)
		{} 
		
		bool internal_hitTest(in vec2 mouse, vec2 ofs=vec2(0))
		{
			auto hitBnd = getHitBounds + ofs; 
			if(hitBnd.contains!"[)"(mouse))
			{
				if(auto container = cast(Container)this)
				{
					if(container.flags.dontHitTest)
					return false; //Note: false means -> keep continue the search
					im.hitTestManager.addHitRect(
						container.id, hitBnd, mouse-(innerPos+ofs), 
						container.flags.clickable
					); 
				}else
				{
					//it's just a regular cell. Can't add to hitTest because it has no ID.
				}
				return true; 
			}else
			{ return false; }
		} 
		
		///this hitTest is only works after measure.
		Tuple!(Cell, vec2)[] contains(in vec2 p, vec2 ofs=vec2.init)
		{
			Tuple!(Cell, vec2)[] res; 
			
			if((outerBounds+ofs).contains!"[)"(p))
			res ~= tuple(this, ofs); 
			
			return res; 
		} 
		
		//this is the third version: it returns
		CellLocation[] locate(in vec2 mouse, vec2 ofs=vec2.init)
		{
			auto bnd = outerBounds + ofs; //Note: locate() searches in outerBounds, not just the borderBounds.
			if(bnd.contains!"[)"(mouse))
			return [CellLocation(this, mouse-(innerPos+ofs), bnd)]; 
			return []; 
		} 
		
		final void drawBorder(Drawing dr)
		{
			if(border) {
				if(border.isLineBorder)	border.drawLineBorder   (dr, borderBounds     ); 
				else	border.drawShadedBorder(dr, borderBounds_outer); 
			}
		} 
		
		
		
		void dump(int indent=0)
		{
			print(
				"  ".replicate(indent), this.classinfo.name.split('.').back, " ",
							outerPos, innerSize, flex,
				//cast(.Container)this ? (cast(.Container)this).flags.text : "",
							cast(.Glyph)this ? (cast(.Glyph)this).ch.text.quoted : ""
			); 
			if(auto cntr = cast(Container)this)
			foreach(c; cntr.subCells)
			c.dump(indent+1); 
			
		} 
		
	} 
	
	
	
	//helper function to access a texture of a font character
	
	enum EnableFontstats = (常!(bool)(0)); 
	
	static if(EnableFontstats)
	{
		struct FontStats
		{
			static: 
			uint[uint] rootDirs; 
			uint[uint] subDirs; 
			uint[uint] codes; 
			
			void doit(dchar ch)
			{
				const 	code 	= (cast(uint)(ch)),
					subDir 	= code >> 7,
					rootDir 	= subDir >> 7; 
						
				if(code !in codes)
				{
					codes[code]++; 
					subDirs[subDir]++; 
					rootDirs[rootDir]++; 
					writeln("fontStats"); 
					rootDirs.keys.sort.writeln; 
					subDirs.keys.sort.writeln; 
				}
			} 
		} 
	}
	
	TexHandle fontTexture(Args...)(in dchar ch, in TextStyle ts)
	{
		TexHandle stIdx; //the result texture index
		
		const 	fontId 	= ((ts.fontId)?(ts.fontId):(DefaultUIFontId)),
			isDefault 	= fontId==DefaultUIFontId; 
		
		//ch -> subTexIdx lookup. Cached with a map.   10 FPS -> 13..14 FPS
		void lookupSubTexIdx()
		{
			const fontName = accessFontFace(fontId).name; 
			const glyphSpec = `font:\`~fontName~`\72\x3\?`~ch.only.toUTF8; 
			stIdx = textures_getNow(File(glyphSpec)); //fonts are loaded immediatelly
		} 
		
		if(isDefault)
		{
			//cached version for the default font
			if(auto p = ch in DefaultFont_subTexIdxMap)
			{ stIdx = TexHandle(*p); }
			else
			{
				static if(EnableFontstats) FontStats.doit(ch); 
				lookupSubTexIdx; 
				DefaultFont_subTexIdxMap[ch] = (cast(int)(stIdx)); 
			}
		}
		else
		{
			//uncached for non-default fonts
			lookupSubTexIdx; 
		}
		
		return stIdx; 
	} 
	
	
	void drawText(R)(Drawing dr, vec2 pos, R str, in TextStyle ts)
	if(isInputRange(R) && isSomeChar!(ElementType!R))
	{
		foreach(dchar ch; str)
		{
			auto stIdx = ch.fontTexture(ts); 
			auto size = calcGlyphSize_clearType(ts, stIdx); 
			dr.color = ts.fontColor; 
			dr.drawFontGlyph(stIdx, bounds2(pos, pos+size), ts.bkColor, ts.fontFlags); 
			pos.x += size.x; 
		}
	} 
	
	vec2 textExtent(R)(R str, in TextStyle ts)
	if(isInputRange(R) && isSomeChar!(ElementType!R))
	{
		vec2 res; 
		foreach(dchar ch; str)
		{
			auto stIdx = ch.fontTexture(ts); 
			auto size = calcGlyphSize_clearType(ts, stIdx); 
			res.x += size.x; 
			res.y.maximize(size.y); 
		}
	} 
	
	bool cellIsNewLine(Cell c) { return cast(Glyph)c && (cast(Glyph)c).isNewLine; } 
	
	private bool isTab(in Cell c)
	{
		if(const g = (cast(Glyph)(c)))	return g.isTab; 
		else	return false; 
	} 
	
	
	struct GlyphFlags
	{
		mixin((
			(表([
				[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
				[q{ubyte},q{6},q{"fontFlags"},q{},q{/++/}],
				[q{SyntaxKind},q{6},q{"syntax"},q{},q{/++/}],
				[q{bool},q{1},q{"isWhite"},q{},q{/++/}],
				[q{bool},q{1},q{"isTab"},q{},q{/++/}],
				[q{bool},q{1},q{"isNewLine"},q{},q{/++/}],
				[q{bool},q{1},q{"isReturn"},q{},q{/++/}],
			]))
		) .GEN!q{GEN_bitfields}); 
	} 
	static assert(GlyphFlags.sizeof==2); 
	
	class Glyph : Cell
	{
		TexHandle stIdx; 
		dchar ch; //21 bits should be enough in 2026.
		
		RGB fontColor, bkColor; 
		//ubyte fontFlags; 
		//SyntaxKind syntax; //needed for DIDE
		
		//bool isWhite, isTab, isNewLine, isReturn; //needed for wordwrap and elastic tabs
		GlyphFlags flags; alias this = flags; /+Todo: bitfields can't alias_this the bool foelds.+/
		
		int lineIdx; //1based. needed for DIDE.
		
		this(Glyph src)
		{
			outerPos 	= src.outerPos,
			outerSize 	= src.outerSize,
			stIdx	= src.stIdx,
			ch	= src.ch,
			fontColor	= src.fontColor,
			bkColor	= src.bkColor,
			flags	= src.flags,
			lineIdx	= src.lineIdx; 
		} 
		
		this(dchar ch, in TextStyle ts)
		{
			this.ch = ch; 
			
			//tab is the isSame as a space
			flags.isTab = ch=='\t'/+9+/; 
			flags.isWhite = flags.isTab || ch==' '/+32+/; 
			flags.isNewLine = ch=='\n'/+10+/; 
			flags.isReturn = ch=='\r'/+13+/; 
			/+
				Todo: ezt a boolean mess-t kivaltani. a chart meg el kene tarolni. 
				ossz 16byte all rendelkezeser ugyis.
			+/
			
			dchar visibleCh = ch; 
			if(VisualizeGlyphs)
			{
				if(flags.isReturn)	visibleCh = 0x240D; 
				else if(flags.isNewLine)	visibleCh = 0x240A; 
			}
			else
			{
				if(flags.isReturn || flags.isNewLine)	{ visibleCh = ' '; }
				else if(ch=='\v'/+11+/)	{
					visibleCh = 0x240B; 
					//vertical tab. It is used for multiColumns
				}
			}
			
			stIdx = fontTexture(visibleCh, ts); 
			
			fontColor = ts.fontColor; 
			bkColor = ts.bkColor; 
			flags.fontFlags = ts.fontFlags; 
			
			innerSize = calcGlyphSize_clearType(ts, stIdx); 
			
			if(!VisualizeGlyphs)
			if(flags.isReturn || flags.isNewLine)
			innerWidth = 0; 
		} 
		
		this(dchar ch, in TextStyle ts, SyntaxKind sk)
		{ this(ch, ts); flags.syntax = sk; } 
		
		override string toString()
		{ return format!"Glyph(%s, %s, %s)"(ch.text.quoted, stIdx, outerBounds); } 
		
		final void drawVisualizers(Drawing dr)
		{
			if(VisualizeCodeLineIndices)
			{
				dr.color = clWhite; 
				dr.fontHeight = 1.25; 
				dr.textOut(outerPos, format!"%s"(lineIdx)); 
			}
			
			if(VisualizeGlyphs)
			{
				dr.color = clGray; 
				dr.lineStyle = LineStyle.normal; 
				dr.lineWidth = 0.16f*2; 
				dr.drawRect(innerBounds); 
				
				if(flags.isTab)
				{
					dr.lineWidth = innerHeight*0.04f; dr.arrowStyle = ArrowStyle.vector; 
					dr.line(innerBounds.leftCenter, innerBounds.rightCenter); 
					dr.arrowStyle = ArrowStyle.none; 
				}
				else if(flags.isWhite)
				{ dr.drawX(innerBounds); }
			}
		} 
		
		override void draw(Drawing dr)
		{
			dr.color = fontColor; 
			dr.drawFontGlyph((cast(int)(stIdx)), innerBounds, bkColor, fontFlags); 
			drawVisualizers(dr); 
		} 
	} 
	
	class StretchedGlyph : Glyph
	{
		/+
			stretch the glyph vertically.  
			This operation depends on the character.  Used for  [] () {} etc...
		+/
		
		UpperFloat invStretchRatio;  //Note: At this point, there is no textStyle, so have to store the stretch ratio.
		
		this(Glyph src, in float y0, in float y1)
		{
			assert(!(cast(StretchedGlyph)(src)), "Already stretched."); 
			
			super(src); 
			
			const originalHeight = outerHeight; 
			outerTop = y0; 
			outerHeight = y1-y0; 
			
			invStretchRatio = originalHeight/outerHeight; 
		} 
		
		override void draw(Drawing dr)
		{
			dr.color = fontColor; 
			
			
			const float isr = invStretchRatio; //inverse stretch ratio
			enum center 	= .53f, /+The center of the { symbol measured from the top. 0..1 range.+/
			side 	= .12f /+The straight part in the { symbol measured from the center.+/; 
			
			/+
				Code: {}()[]
				⎧⎫⎛⎞⎡⎤⌈⌉⎾⏋⌜⌝
				⎨⎬⎜⎟⎢⎥⌊⌋⎿⏌⌞⌟
				⎪⎪⎝⎠⎣⎦
				⎩⎭
			+/ void part(float targety0, float targety1, float srcy0, float srcy1)
			{
				dr.drawFontGlyph
				(
					(cast(int)(stIdx)), bounds2(
						0	, targety0*outerSize.y,
						outerSize.x	, targety1*outerSize.y
					)+innerPos, 
					bkColor, fontFlags, vec2(srcy0, srcy1)
				); 
			} 
			
			switch(ch)
			{
				case 	'[', ']', 
					'(', ')', 
					'|', '‖',
					'⎡', '⎤',
					'⎣', '⎦': {
					auto 	y0 = 0f,
						y1 = center*isr, 
						y2 = 1-(1-center)*isr,
						y3 = 1f; 
					
					if(ch.among('⎡', '⎤')) { y3 -= .05; }
					if(ch.among('⎣', '⎦')) { y0 += .1; }
					
					part(y0, y1, 0, center); 
					part(y1, y2, center, center); 
					part(y2, y3, center, 1); 
				}break; 
				case 	'{', '}',
					'⁅', '⁆': {
					//First draw the { without the center peak.
					const 	y1 = (center-side)*isr, 
						y2 = .5f-side*isr,
						y3 = .5f+side*isr,
						y4 = 1-(1-(center+side))*isr; 
					part( 0, y1, 0, center-side); 
					part(y1, y2, center-side, center-side); 
					part(y2, y3, center-side, center+side); 
					part(y3, y4, center+side, center+side); 
					part(y4,  1, center+side, 1); 
				}break; 
				
				
				default: {
					/+simple default stretching+/
					dr.drawFontGlyph((cast(int)(stIdx)), innerBounds, bkColor, fontFlags); 
				}
			}
			
			drawVisualizers(dr); 
		} 
	} 
	
	void stretchGlyph(ref Cell g, in float y0, in float y1)
	{ g = new StretchedGlyph((cast(Glyph)(g)), y0, y1); } 
	
	
	enum ShapeType
	{led} 
	
	class Shape : Cell
	{
		ShapeType type; 
		RGB color; 
		
		/*
			 this(T)(ShapeType shapeType, RGB color, T state, float fontHeight){
			 this.type = shapeType;
			 this.color = color;
			 innerSize = vec2(fontHeight*.5, fontHeight);
			}
		*/
		
		override void draw(Drawing dr)
		{
			final switch(type)
			{
				case ShapeType.led: 
				{
					auto r = min(innerWidth, innerHeight)*0.92f; 
					auto p = innerCenter; 
					
					static if(0)
					{
						dr.pointSize = r; 	dr.color = RGB(.3, .3, .3); dr.point(p); 
						dr.pointSize = r*.8f; 	dr.color = color; dr.point(p); 
						dr.pointSize = r*0.4f; 	dr.alpha = 0.4f; dr.color = clWhite; dr.point(p-vec2(1,1)*(r*0.15f)); 
						dr.pointSize = r*0.2f; 	dr.alpha = 0.4f; dr.color = clWhite; dr.point(p-vec2(1,1)*(r*0.18f)); 
						dr.alpha = 1; 
					}
					else
					{
						/+dr.pointSize = r; 	dr.color = RGB(.3, .3, .3); dr.point(p); +/
						
						{
							const bnd = bounds2(((p).名!q{center}), ((r).名!q{size})); 
							static bevel = mixin(體!((BevelParams),q{
								param 	: .5,
								inverted	: true
							})); 
							bevel.rounding = r, bevel.width = 1.5; 
							static shape = mixin(體!((ShapeParams),q{})); 
							
							auto gfx = (cast(GfxBuilder)(dr.getGfxBuilder)); 
							gfx.PC = color.darken(.6); 
							gfx.drawShape(bnd, shape, bevel); 
						}
						
						r *= .8f; 
						
						{
							const bnd = bounds2(((p).名!q{center}), ((r).名!q{size})); 
							static bevel = mixin(體!((BevelParams),q{param 	: .5})); 
							bevel.rounding = bevel.width = r; 
							static shape = mixin(體!((ShapeParams),q{})); 
							
							auto gfx = (cast(GfxBuilder)(dr.getGfxBuilder)); 
							gfx.PC = color; 
							gfx.drawShape(bnd, shape, bevel); 
						}
						
						if(color[].max>=128)
						{
							dr.pointSize = r/.8f; dr.alpha = .25; dr.color = color; dr.point(p); dr.alpha = 1; 
							dr.pointSize = r; dr.alpha = .35; dr.color = color; dr.point(p); dr.alpha = 1; 
						}
					}
				}
				break; 
			}
		} 
	} 
	
	class Img : Container
	{
		File file; 
		bool transparent; 
		bool autoRefresh; 
		SamplerEffect samplerEffect; 
		
		TexHandle stIdx; 
		
		this(File file)
		{
			this.file = file; 
			id = srcId(genericId("Img:"~file.fullName)); //Todo: this is not so standard...
		} 
		
		this(File file, RGB bkColor)
		{
			this.bkColor = bkColor; 
			this(file); 
		} 
		
		override void rearrange()
		{
			//Note: this is a Container and has the measure() method, so it can be resized by a Column or something. Unlike the Glyph which has constant size.
			//Todo: do something to prevent a column to resize this. Current workaround: put the Img inside a Row().
			
			try
			{
				stIdx = textures_getNow(file); //Todo: no delayed load support
				const siz = calcGlyphSize_image(stIdx); 
				
				if(flags.autoHeight && flags.autoWidth)
				{ innerSize = siz; }
				else if(flags.autoHeight)
				{ innerHeight = innerWidth/max(siz.x, 1)*siz.y; }
				else if(flags.autoWidth)
				{ innerWidth = innerHeight/max(siz.y, 1)*siz.x; }
			}
			catch(Exception e)
			{
				innerSize = vec2(1); 
				stIdx = 0; 
			}
		} 
		
		override void draw(Drawing dr)
		{
			if(flags.hidden)
			return; 
			
			drawBorder(dr); 
			
			if(autoRefresh) { stIdx = textures_getNow(file).ifThrown(TexHandle.init); }//Todo: this does not reflect size change.
			
			int baseFontFlags = ((cast(int)(samplerEffect))<<16); 
			
			if(stIdx)
			{
				if(transparent)	dr.drawFontGlyph((cast(int)(stIdx)), innerBounds, bkColor, baseFontFlags | 32/*transparent font*/); 
				else	dr.drawFontGlyph((cast(int)(stIdx)), innerBounds, bkColor, baseFontFlags | 16/*image*/); 
			}
		} 
	} 
}
version(/+$DIDE_REGION+/all)
{
	struct TextEditorState
	{
		/*
			Text editing.
			
			Problemas dolgok:
			- wrapping
			- 3 fele pozicio meghatarozas szovegen belul:
			
				TextPosition{
					TextIndex	  :	int
					TextLineCol		: { int line, int col; }
					TextXY	  : { float x, float y0, float y1; }  //y0 and y1 covers the whole wrappedLine.height
				}
			
				TextRange{ TextPosition p0, p1; }
			
		*/
		
		/// TextPos marks a specific place inside a text.
		static struct TextPos
		{
			enum Type
			{ none, idx, lc, xy} 
			
			private
			{
				Type type; 
				int fIdx, fLine, fColumn; //Todo: union
				vec2 fPoint; 
				float fHeight=0; 
				
				void enforceType(string file = __FILE__, int line = __LINE__)(Type t) const
				{
					if(t!=type)
					throw new Exception("TextPos type mismatch error. %s required.".format(t), file, line); 
				} 
			} 
			
			this(int idx	     )
			{ type = Type.idx	; 	 fIdx	 = idx	;                     } 
			this(int line, int column	     )
			{ type = Type.lc	; 		fLine	 = line	; 	 fColumn = column; 	} 
			this(in vec2 point, float height)
			{ type = Type.xy; 	fPoint = point; 	 fHeight = height; 	} 
			
			bool valid() const
			{ return type != Type.none; } 
			bool isIdx() const
			{ return type == Type.idx	; } 
			bool isLC () const
			{ return type == Type.lc	; } 
			bool isXY () const
			{ return type == Type.xy	; } 
			
			auto idx	 (string file = __FILE__, int line = __LINE__)() const
			{ enforceType!(file, line)(Type.idx); return fIdx	; } 
			auto line	 (string file = __FILE__, int lin_ = __LINE__)() const
			{ enforceType!(file, lin_)(Type.lc ); return fLine	; } 
			auto column(string file = __FILE__, int line = __LINE__)() const
			{ enforceType!(file, line)(Type.lc ); return fColumn; } 
			auto point (string file = __FILE__, int line = __LINE__)() const
			{ enforceType!(file, line)(Type.xy ); return fPoint; } 
			auto height(string file = __FILE__, int line = __LINE__)() const
			{ enforceType!(file, line)(Type.xy ); return fHeight; } 
			
			string toString() const
			{
				string s; 
				with(Type)
				final switch(type)
				{
					case none: s = "none"; break; 
					case idx	: s = format!"idx = %s"(idx); break; 
					case lc	: s = format!"line = %s, column = %s"(line, column); break; 
					case xy	: s = format!"point = (%.1f, %.1f), height = %.1f"(point.x, point.y, height); break; 
				}
				
				return Unqual!(typeof(this)).stringof ~ "(" ~ s ~ ")"; 
			} 
		} 
		
		/// a linearly selected range of text.
		static struct TextRange
		{ TextPos st, en; } 
		
		static struct EditCmd
		{
			private enum _intParamDefault 	= int.min+1,
			_pointParamDefault 	= vec2(-1e30, -1e30); 
			
			enum Cmd
			{
				/+caret commands+/	//parameters
				nop,	
				cInsert,	//text to insert
				cDelete, cDeleteBack, 	//number of glyphs to delete. Default 1
				cLeft, cRight,	//number of repetitions. Default 1
				cUp, cDown,	
				cHome, cEnd,	
				cMouse	//caret goes to mouse
			} 
			alias cmd this; 
			
			Cmd cmd; 
			int _intParam = _intParamDefault; 
			vec2 _pointParam = _pointParamDefault; 
			
			//parameter access
			string strParam; 
			int intParam(int def=0) const
			{ return _intParam==_intParamDefault ? def : _intParam; } 
			vec2 pointParam(in vec2 def=vec2(0)) const
			{ return _pointParam==_pointParamDefault ? def : _pointParam; } 
			
			this(T...)(Cmd cmd, T args)
			{
				this.cmd = cmd; 
				static foreach(a; args)
				{
					static if(isSomeString!(typeof(a)))
					strParam = a; 
					static if(isIntegral  !(typeof(a)))
					_intParam = a; 
					static if(is(const typeof(a) == ConstOf!vec2))
					_pointParam = a; 
				}
			} 
			
			auto toString() const
			{
				auto s = format!"EditCmd(%s"(cmd); 
				if(_intParam != _intParamDefault)
				s ~= " " ~ _intParam.text; 
				if(strParam.length)
				s ~= " " ~ strParam.text; 
				if(_pointParam != _pointParamDefault)
				s ~= " " ~ format!"(%.1f, %.1f)"(pointParam.x, pointParam.y); 
				return s ~ ")"; 
			} 
		} 
		
		string str; 	//the string being edited Edit() fills it
		float defaultFontHeight; 	//used when there's no text to display 0 -> uibase.NortmalFontHeight
		int[] cellStrOfs; 	//mapping petween glyphs and string ranges Edit() fills it
			
		Row row; 	//editor container. Must be a row. Edit() fills it
		WrappedLine[] wrappedLines; 	//formatted glyphs. Measure fills it when edit is same as wrappedLines
			
		bool strModified; 	//string is modified, and it is needed to reformat.
			//cellStrOfs and wrappedLines are invalid.
			
		TextPos caret; 	//first there is only one caret, no selection persistent
			
		EditCmd[] cmdQueue; 	//commands waiting for execution. Edit() fills, it is proecessed after the hittest
		
		string dbg; 
		
		/// Must be called before a new frame. Clears data that isn't safe to keep from the last frame.
		void beginFrame()
		{
			row = null; 
			wrappedLines = null; 
			cellStrOfs = null; 
			defaultFontHeight = DefaultFontHeight; 
		} 
		
		bool active()                 const
		{ return row !is null; } 
		
		//access helpers
		auto cells()	      
		{ return row.subCells; } 
		int cellCount()	      
		{ return cast(int)cells.length; } 
		int wrappedLineCount()	      
		{ return cast(int)wrappedLines.length; } 
		int clampIdx(int idx)	      
		{ return idx.clamp(0, cellCount); } 
		
		//raw caret conversion routines
		
		private int lc2idx(int line, int col)
		{
			if(line<0)
			return 0; //above first line
			if(line>=wrappedLines.length)
			return cellCount; //below last line
			
			int baseIdx = wrappedLines[0..line].map!(l => l.cellCount).sum; //Todo: opt
			int clampedColumn = col.clamp(0, wrappedLines[line].cellCount); 
			return clampIdx(baseIdx + clampedColumn); 
		} 
		
		private int lc2idx(in ivec2 colLine)
		{
			with(colLine)
			return lc2idx(y, x); 
		} 
		
		private ivec2 xy2lc(in vec2 point)
		{
			if(wrappedLines.empty)
			return ivec2(0); 
			
			float 	yMin 	= wrappedLines[0].top,
				yMax 	= wrappedLines.back.bottom,
				y 	= point.y; 
			
			static if(1)
			{
				//above or below: snap to first/last line or start/end of the whole text.
				if(y<yMin)
				return ivec2(0); 
				if(y>yMax)
				return ivec2(wrappedLineCount-1, wrappedLines[wrappedLineCount-1].cellCount); 
			}else
			{
				 //other version: just clamp it to the nearest
				y = tp.point.y.clamp(yMin, yMax); 
			}
			
			//search the line
			int line; //Opt: binary search? (not important: only 1 screen of information)
			foreach_reverse(int i; 0..wrappedLineCount)
			{
				if(y >= wrappedLines[i].y0)
				{ line = i; break; }
			}
			
			auto wl = &wrappedLines[line]; 
			
			float 	xMin 	= wl.left,
				xMax 	= wl.right,
				x 	= point.x; 
			
			x = x.clamp(xMin, xMax); //always clamp x coordinate
			
			int column; 
			
			/*
					 if(x >= xMax){
					 column = wl.cellCount; //last char past 1
				}else if(x <= xMin){
					column = 0;
				}else{
					//search the column in the line
					foreach_reverse(int i; 0..wl.cellCount){
						if(x >= wl.cells[i].outerPos.x){ column = i; break; }
					}
				}
			*/
			
			column = wl.selectNearestGap(x); 
			
			return ivec2(column, line); 
		} 
		
		private int xy2idx(in vec2 point)
		{ return lc2idx(xy2lc(point)); } 
		
		private ivec2 idx2lc(int idx)
		{
			if(idx<=0 || cellCount==0)
			return ivec2(0, 0); 
			
			int col = idx; 
			if(idx < cellCount)
			foreach(int line; 0..wrappedLineCount)
			{
				const count = wrappedLines[line].cellCount; 
				if(col < count)
				return ivec2(col, line); 
				col -= count; 
			}
			
			
			return ivec2(wrappedLines.back.cellCount, wrappedLineCount); //The cell after the last.
		} 
		
		TextPos toIdx(in TextPos tp)
		{
			if(!tp.valid)
			return tp; 
			
			if(!cellCount)
			return TextPos(0); 	//empty
			if(tp.isIdx	)
			return TextPos(clampIdx(tp.idx)); 	//no need to convert, only clamp the idx.
			if(tp.isLC	)
			return TextPos(lc2idx(tp.line, tp.column)); 	//
			if(tp.isXY	)
			return TextPos(xy2idx(tp.point)); 	//first convert to the nearest LC, then that to Idx
			return TextPos(0); 	//when all fails
		} 
		
		TextPos toLC(in TextPos tp)
		{
			if(!tp.valid)
			return tp; 
			
			if(!cellCount)
			return TextPos(0, 0); 
			if(tp.isLC	)
			return tp; 
			if(tp.isIdx	)
			with(idx2lc(tp.idx))
			return TextPos(y, x); 
			if(tp.isXY	)
			with(idx2lc(xy2idx(tp.point)))
			return TextPos(y, x); 
			return TextPos(0, 0); //when all fails
		} 
		
		TextPos toXY(in TextPos tp)
		{
			if(!tp.valid)
			return tp; 
			
			if(!cellCount)
			return TextPos(vec2(0, 0), defaultFontHeight); 
			if(tp.isXY)
			return tp; 
			
			TextPos lc; 
			if(tp.isIdx	)
			lc = toLC(tp); 
			if(tp.isLC	)
			lc = tp;    //Todo: more error checking
			
			int line = lc.line.clamp(0, wrappedLineCount-1); 
			int col = lc.column.clamp(0, wrappedLines[line].cellCount); 
			bool isRight; 
			if(col == wrappedLines[line].cellCount)
			{
				col--; 
				isRight = true; 
			}
			
			auto cell = wrappedLines[line].cells[col];  //Todo: refactor
			auto pos = vec2(cell.outerPos.x + (isRight ? cell.outerWidth : 0), wrappedLines[line].top); 
			return TextPos(pos, wrappedLines[line].height); 
		} 
		
		string execute(EditCmd eCmd)
		{
			  //returs: "" success:  "error msg" when fail
			
			void checkConsistency()
			{
				enum e0 = "textEditorState consistency check fail: "; 
				enforce(row !is null		, e0~"row is null"   ); 
				enforce(cellStrOfs.length	== cellCount+1	     , e0~"invalid cellStrOfs"  ); 
				enforce(wrappedLines.map!(l => l.cellCount).sum == cellCount	     , e0~"invalid wrappedLines"); 
			} 
			
			void caretRestrict()
			{
				//Todo: this should work all the 3 types of carets: idx, lc and xy
				int i	= toIdx(caret).idx,
						mi	= 0,
						ma	= cellCount; 
				
				bool wrong = i<mi || i>ma; 
				if(wrong)
				caret = TextPos(i<mi ? mi : ma); 
			} 
			
			void caretMoveAbs(int idx)
			{
				caret = TextPos(idx); 
				caretRestrict; 
			} 
			
			void caretMoveRel(int delta)
			{ caretMoveAbs(toIdx(caret).idx + delta); } 
			
			void caretMoveVert(int delta)
			{
				if(!delta)
				return; 
				auto c = toXY(caret); 
				
				caret = toIdx(TextPos(vec2(c.point.x, c.point.y + c.height*.5 + c.height*delta), 0)); 
				//Todo: it only works for the same fontHeight and  monospaced stuff
				
				caretRestrict; 
			} 
			
			void caretAdjust(ref TextPos caret, int idx, int delLen, int insLen, int insOffset=0)
			{
				 //insOffset is 1 for selection.left
				int cIdx = toIdx(caret).idx; 
				
				//adjust for deletion.
				//if it is right of idx, then it goes left by delLen, towards idx
				if(cIdx > idx)
				cIdx = max(cIdx-delLen, idx); 
				
				//adjust for insertion
				if(cIdx >= idx+insOffset)
				cIdx += insLen; 
				
				caret = TextPos(cIdx); 
				caretRestrict; //failsafe
			} 
			
			void modify(int idx, int delLen, string ins)
			{
				
				int fullLen = cellCount; 
				
				//if idx is after the end, pull it back
				idx.minimize(fullLen); 
				
				//if idx is below the start, move it to 0, also make the deleteCount smaller
				if(idx<0)
				{ delLen -= idx; idx = 0; }
				
				//clamp delLen
				int maxDelLen = fullLen-idx; 
				delLen.minimize(maxDelLen); 
				delLen.maximize(0); 
				
				if(delLen<=0 && ins=="")
				return; //exit if nothing happens
				
				auto insLen = countMarkupLineCells(ins); 
				//cellcount can be adjusted by this, but the wrappedLines is ruined now.
				
				//adjust the caret
				caretAdjust(caret, idx, delLen, insLen); 
				
				//make the	new modified string
				auto left	= str[0..cellStrOfs[idx]],
						 right	= str[cellStrOfs[idx+delLen]..$]; 
				str = left	~ ins ~ right; 
				
				//invalidate the formatted data
				strModified = true; 
			} 
			
			void deleteAtCaret(bool isBackSpace)
			{
				caretRestrict; 
				int i = toIdx(caret).idx; 
				
				if(isBackSpace && i<=0)
				return; //nothing to delete
				
				modify(i-isBackSpace, 1, ""); 
			} 
			
			//---------------------------------------------
			string err; 
			
			checkConsistency; 
			
			with(eCmd)
			final switch(cmd)
			{
				case Cmd.nop: 		break; 
				case Cmd.cInsert: 	caretRestrict; modify(toIdx(caret).idx, 0, strParam); 	break; 
				case Cmd.cDelete: 	deleteAtCaret(false); 	break; 
				case Cmd.cDeleteBack: 	deleteAtCaret(true ); 	break; 
				case Cmd.cLeft: 	caretMoveRel(-intParam(1)); 	break; 
				case Cmd.cRight: 	caretMoveRel(intParam(1)); 	break; 
				case Cmd.cUp: 	caretMoveVert(-intParam(1)); 	break; 
				case Cmd.cDown: 	caretMoveVert(intParam(1)); 	break; 
				case Cmd.cHome: 	caretMoveAbs(0); 	break; 
				case Cmd.cEnd: 	caretMoveAbs(cellCount); 	break; 
				case Cmd.cMouse: 	caret = toIdx(TextPos(pointParam, 0)); 	break; 
				//Todo: cMouse pontatlan.
				//Todo: minden cursor valtozaskor a caret legyen teljesen fekete
			}
			
			
			return err; 
		} 
		
		string processQueue()
		{
			string err; 
			
			while(cmdQueue.length)
			{
				//check if the command can be executed.
				if(strModified)
				break; //string is modified, needs to reformat first.
				
				auto cmd = cmdQueue.front; 
				cmdQueue.popFront; 
				
				err ~= execute(cmd); 
			}
			
			dbg = format("caret: %s  %s  %s\n", toIdx(caret), toLC(caret), toXY(caret))
					~ wrappedLines.map!(l => l.text).join("\n"); 
			
			return err; 
		} 
		
		void drawOverlay(Drawing dr, RGB color)
		{
			auto c = toXY(caret); 
			if(c.valid)
			{
				dr.color = color; 
				dr.lineWidth = sqr(1-(QPS.value(second)*1.5).fract)*2.5; //sin((QPS*1.5).fract*PI*2).remap(-1, 1, 0.1, 2);
				
				dr.vLine(c.point.x, c.point.y, c.point.y+c.height); 
			}
		} 
		
		void handleKeyboardInput(ref string inputChars, in bool acceptEditorKeys, in vec2 localMouse)
		{
			with(EditCmd)
			{
				inputChars.processInputChars
				((ch){
					if(((ch>=32) || (acceptEditorKeys && ch.among(9, 10))))
					{ cmdQueue ~= EditCmd(cInsert, ch.text); return true; }
					else { return false; }
				}); 
				
				mixin((
					(表([
						[q{ KeyCombo("LMB").hold},q{cmdQueue ~= EditCmd(cMouse, localMouse); }],
						[q{ KeyCombo("Backspace").typed},q{cmdQueue ~= EditCmd(cDeleteBack); }],
						[q{ KeyCombo("Del").typed},q{cmdQueue ~= EditCmd(cDelete); }],
						[q{ KeyCombo("Left").typed},q{cmdQueue ~= EditCmd(cLeft); }],
						[q{ KeyCombo("Right").typed},q{cmdQueue ~= EditCmd(cRight); }],
						[q{ KeyCombo("Home").typed},q{cmdQueue ~= EditCmd(cHome); }],
						[q{ KeyCombo("End").typed},q{cmdQueue ~= EditCmd(cEnd); }],
						[q{ KeyCombo("Up").typed},q{cmdQueue ~= EditCmd(cUp); }],
						[q{ KeyCombo("Down").typed},q{cmdQueue ~= EditCmd(cDown); }],
						[q{ KeyCombo("Ctrl+V Shift+Ins").typed},q{cmdQueue ~= EditCmd(cInsert, clipboard.text); }],
					]))
				) .GEN!q{mixin(求map(q{r},q{rows},q{iq{if($(r[0])) {$(r[1])}}.text})).join}); 
				
				/+
					Todo: When the edit is focused, don't let the view to zoom home. 
					Problem: Editor has a priority here, but the view is checked first.
				+/
			}
		} 
	} 
	
	
	//markup parser /////////////////////////////////////////
	
	void processMarkupCommandLine(Container container, string cmdLine, ref TextStyle ts)
	{
		if(cmdLine=="")
		{ ts	= tsNormal; }
		else if(auto t = cmdLine in textStyles)
		{
			 //standard style.	Should be mentioned by an index
			ts = **t; //now it is a copy;
		}
		else
		{
			try
			{
				auto params = cmdLine.commandLineToMap; 
				auto cmd = params.get("0", ""); 
				if(cmd=="row")
				{
					auto a = new Row(params["1"], tsNormal); 
					a.setProps(params); 
					container.appendCell(a); 
				}
				else if(cmd=="img")
				{
					auto img = new Img(File(params["1"]), ts.bkColor); 
					img.setProps(params); 
					container.appendCell(img); 
				}
				else if(cmd=="char")
				{ container.appendChar(dchar(params["1"].toInt), ts); }
				else if(cmd=="symbol")
				{
					auto name = params["1"]; 
					auto ch = segoeSymbolByName(name); 
					const oldFontId = ts.fontId; 
					ts.fontId = FontId.Segoe_MDL2_Assets; 
					container.appendChar(ch, ts); 
					ts.fontId = oldFontId; 
				}
				else if(cmd=="space"	)
				{
					auto r = new Row("",	ts); 
					r.innerHeight = ts.fontHeight; 
					r.outerWidth = params["1"].toWidthHeight(g_actFontHeight); 
					r.setProps(params); 
					container.appendCell(r); 
				}
				else if(cmd=="flex")
				{ container.appendCell(new Row(tag("prop flex=1"), ts)); }
				else if(cmd=="link")
				{
					/*
						import het.ui: Link;
						container.append(new Link(params["1"], 0, false, null));
					*/
					raise("not impl"); 
				}
				else if(cmd=="btn" || cmd=="button")
				{
					/*
						auto btn = new Clickable(params["1"], 0, false, null);
						btn.setProps(params);
						append(btn);
					*/
					raise("not impl"); 
				}
				else if(cmd=="key" || cmd=="keyCombo")
				{
					/*
						import het.ui: KeyComboOld;
						auto kc = new KeyComboOld(params["1"]);
						kc.setProps(params);
						container.append(kc);
					*/
					raise("not impl"); 
				}
				else if(cmd=="style")
				{
					 //textStyle
					ts.modify(params); 
				}
				else if(cmd=="prop" || cmd=="props")
				{
					 //container's properties
					container.setProps(params); 
				}
				else
				{
					//try to set container properties
					
					throw new Exception(`Unknown command: "%s"`.format(cmd)); 
				}
			}
			catch(Throwable t)
			{ container.appendStr("["~t.msg~": "~cmdLine~"]", tsError); }
		}
	} 
	
	int countMarkupLineCells(string markup)
	{
		try
		{
			auto cntr = new Row(markup); 
			return cast(int)cntr.subCells.length; 
		}catch(Throwable)
		{ return 0; }
	} 
	
	void appendMarkupLine(Container cntr, string s, ref TextStyle ts)
	{
		int[] dummy; 
		appendMarkupLine!(false)(cntr, s, ts, dummy); 
	} 
	
	void appendMarkupLine	(bool returnSubCellStrOfs=true)
		(Container cntr, string s, ref TextStyle ts, ref int[] subCellStrOfs)
	{
		enum CommandStartMarker 	= '\u00B6',
		CommandEndMarker	= '\u00A7'; 
		
		int inCommand; 
		string commandLine; 
		
		static if(returnSubCellStrOfs)
		subCellStrOfs = [0]; //the first implicit offset.
		
		//foreach(ch; s.byDchar){ //todo: dchar ch;s test
		int currentOfs; 
		size_t numCodeUnits; 
		
		while(s.length)
		{
			auto ch = s.decodeFront!(Yes.useReplacementDchar)(numCodeUnits); 
			
			static if(returnSubCellStrOfs)
			currentOfs += cast(int)numCodeUnits; 
			
			if(ch==CommandStartMarker)
			{
				 //handle start marker
				if(inCommand)
				commandLine ~= ch; //only if already in a command, not the first one
				inCommand++; 
			}
			else if(ch==CommandEndMarker)
			{
				 //handle end marker
				enforce(inCommand>0, "Unexpected command end marker"); 
				if(inCommand>1)
				commandLine ~= ch; //dont append level 1 end marker
				if(!(--inCommand))
				{
					cntr.processMarkupCommandLine(commandLine, ts); 
					commandLine = ""; 
					
					static if(returnSubCellStrOfs)
					while(subCellStrOfs.length <= cntr.subCells.length)
					subCellStrOfs ~= currentOfs; //COPY!
				}
			}
			else
			{
				if(inCommand)
				{
					 //collect command
					commandLine ~= ch; 
				}
				else
				{
					 //process text
					cntr.appendChar(ch, ts); 
					
					static if(returnSubCellStrOfs)
					while(subCellStrOfs.length <= cntr.subCells.length)
					subCellStrOfs ~= currentOfs; //PASTE!!!
				}
			}
			
		}
	} 
	
	/+
		This appendCode() stuff is not used by DIDE anymore. ->CodeColumnBuilder
		I keep it for simple syntax highlighting.
	+/
	
	/*
		*
		Append syntax highlighted source code to a container (normally a Row).
		Params:
						cntr =		 the container being updated
						text =		 the input text
						syntax =	  byte	array of syntax indices
						applySyntax =		delegate to apply a syntax index to the TextStyle
						ts =	  reference to the TextStyle used while appending all the characters
	*/
	
	void appendCode(
		Container cntr, string text, in SyntaxKind[] syntax, 
		void delegate(SyntaxKind) applySyntax, ref TextStyle ts, 
		int nonStringTabToSpaces=-1
	)
	in(text.length == syntax.length)
	{
		size_t numCodeUnits, currentOfs; 
		ubyte lastSyntax = 255; 
		
		while(text.length)
		{
			auto actSyntax = syntax[currentOfs]; 
			auto ch = text.decodeFront!(Yes.useReplacementDchar)(numCodeUnits); 
			currentOfs += numCodeUnits; 
			
			if(chkSet(lastSyntax, actSyntax))
			applySyntax(actSyntax); 
			
			if(ch=='\t' && nonStringTabToSpaces>=0 && actSyntax!=6/+string+/)
			{
				foreach(i; 0..nonStringTabToSpaces)
				cntr.appendSyntaxChar(' ', ts, actSyntax); 
			}
			else
			{ cntr.appendSyntaxChar(ch, ts, actSyntax); }
		}
	} 
	
	bool updateSyntax(TC:Container)(
		TC cntr, string text, in SyntaxKind[] syntax, 
		void delegate(SyntaxKind) applySyntax, 
		ref TextStyle ts, out bool wasWidthChange, 
		int nonStringTabToSpaces=-1
	)
	in(text.length == syntax.length)
	{
		const cntrSubCellsLength = cntr.subCells.length; 
		size_t dstIdx = 0; 
		bool wasError, wasUpdate, wasBoldShift; 
		float boldShift = 0; 
		void pushSyntaxChar(dchar ch, ref TextStyle ts, ubyte actSyntax)
		{
			if(dstIdx<cntrSubCellsLength)
			{
				if(auto g = cast(Glyph)cntr.subCells[dstIdx])
				{
					if(g.ch==ch)
					{
						
						if(boldShift)
						g.outerPos.x += boldShift; //always shift remaining glyphs
						
						if(g.syntax.chkSet(actSyntax))
						{
							 //only set syntax if changed
							g.bkColor	= ts.bkColor; 
							g.fontColor	= ts.fontColor; 
							
							const prevFontFlags = g.fontFlags; 
							g.fontFlags = ts.fontFlags; 
							if(auto delta = g.adjustBoldWidth(prevFontFlags))
							{
								boldShift += delta; 
								wasBoldShift = true; 
							}
							
							wasUpdate = true; 
							/+
								Todo: return this flag somehow... 
								Maybe it is useful for recalculating cached row stuff. 
								But currently the successful flag is returned.
							+/
						}
					}
					else
					{
						/+
							not the same char as it was expected. 
							Only the syntax highlight can change, not the text.
						+/
						wasError = true; 
					}
				}
				else
				{
					//it's not a glyph... Do nothing.
				}
			}
			dstIdx++; 
		} 
		
		size_t numCodeUnits, currentOfs; 
		ubyte lastSyntax = 255; 
		
		while(text.length)
		{
				//Todo: combine and refactor this with appendCode
			auto actSyntax = syntax[currentOfs]; 
			auto ch = text.decodeFront!(Yes.useReplacementDchar)(numCodeUnits); 
			currentOfs += numCodeUnits; 
			
			if(chkSet(lastSyntax, actSyntax))
			applySyntax(actSyntax); 
			
			if(ch=='\t' && nonStringTabToSpaces>=0 && actSyntax!=6/+string+/)
			{
				foreach(i; 0..nonStringTabToSpaces)
				pushSyntaxChar(' ', ts, actSyntax); 
			}
			else
			{ pushSyntaxChar(ch, ts, actSyntax); }
			
			if(wasError)
			break; 
		}
		
		
		wasWidthChange = wasBoldShift; /+
			Bug: this only works with elastic tabs
			 when the whole line grows, not when shrinks.
		+/
		return !wasError && cntrSubCellsLength == dstIdx; 
	} 
	
	//Todo: Refactor the whole Row/Glyph/Syntax mystery
	
	
	
	private struct WrappedLine
	{
		Cell[] cells; 
		float y0, height; 
		
		auto top()
		{ return y0; } 
		auto bottom()
		{ return top+height; } 
		auto right()
		{ return cells.length ? cells.back.outerRight : 0; } 
		auto left()
		{ return cells.length ? cells[0].outerPos.x : 0; } 
		auto calcWidth()
		{
			assert(left==0, "Trying to rearrange subCells of a Row that were already realigned."); 
			return right; 
		} 
		//Todo: assume left is 0
		
		
		int cellCount() const
		{ return cast(int)cells.length; } 
		
		void translateX(float dx)
		{
			if(!dx)
			return; foreach(c; cells)
			c.outerPos.x += dx; 
		} 
		void translateY(float dy)
		{
			if(!dy)
			return; foreach(c; cells)
			c.outerPos.y += dy; y0 += dy; 
		} 
		
		void scaleX(float scale, bool whiteOnly)
		{
			float shift = 0; 
			
			if(scale)
			foreach(c; cells)
			{
				c.outerPos.x += shift; 
				if(!whiteOnly || c.isWhite)
				{
					auto oldWidth = c.outerWidth; 
					auto newWidth = oldWidth*scale; 
					shift += newWidth - oldWidth; 
				}
			}
			
		} 
		
		void alignY(float t)
		{
			 //only callable once, as it is relative
			if(t)
			foreach(c; cells)
			c.outerPos.y += (height-c.outerHeight)*t; 
		} 
		
		void stretchY()
		{
			foreach(c; cells)
			c.outerHeight = height; 
		} 
		
		void alignX(float fullWidth, float t)
		{
			if(t)
			translateX((fullWidth-calcWidth)*t); 
		} 
		
		void justifyX(float fullWidth)
		{
			auto whiteSum = cells.filter!(c => c.isWhite && c.outerWidth).map!(c => c.outerWidth).sum; 
			if(!whiteSum)
			return; 
			auto fixedSum = calcWidth - whiteSum; 
			
			//fixedSum + whiteSum*scale = fullWidth
			//scale*whiteSum = fullWidth - fixedSum
			auto scale = (fullWidth - fixedSum)/whiteSum; 
			enum MaxJustifyScale = 999; 
			if(scale<MaxJustifyScale)
			scaleX(scale, true); 
		} 
		
		void hideLeftSpace()
		{
			if(cells.length && isWhite(cells.front))
			{
				auto w = cells.front.outerWidth; 
				cells.front.outerWidth = 0; 
				foreach(c; cells[1..$])
				c.outerPos.x -= w; //shift back the remaining ones
			}
		} 
		
		void hideRightSpace()
		{
			if(cells.length && isWhite(cells.back))
			cells.back.outerWidth = 0; 
		} 
		
		void hideBothSpaces()
		{
			hideRightSpace; 
			hideLeftSpace; 
		} 
		
		void hideSpaces(HAlign hAlign)
		{
			final switch(hAlign)
			{
				case HAlign.left: 	hideLeftSpace; 	break; 
				case HAlign.right: 	hideRightSpace; 	break; 
				case HAlign.center: 	hideBothSpaces; 	break; 
				case HAlign.justify: 	hideBothSpaces; 	break; 
			}
		} 
		
		/// functions for text selections
		int selectNearestGap(float x)
		{
			 //x: local x coordinate. (innerPos.x = 0)
			if(cells.empty)
			return 0; 
			foreach(i, c; cells)
			if(x<c.outerPos.x + c.outerWidth*.5f)
			return cast(int)i; 
			return cellCount; 
		} 
		
		int selectNearestCell(float x)
		{
			 //always select something on either side
			if(cells.empty)
			return 0; 
			foreach_reverse(i, c; cells)
			if(x >= c.outerPos.x)
			return cast(int)i; 
			return 0; 
		} 
		
		auto selectCellsInRange(float x0, float x1)
		{
			 //cell only need to touch the range
			int lo = 0, hi = 0; 
			sort(x0, x1); 
			if(cells.empty || x1<cells[0].outerPos.x || x0>cells.back.outerRight)
			return tuple(lo, hi); //no intersection
			
			foreach(i, c; cells)
			if(x0 <= c.outerRight)
			{ lo = cast(int)i; break; }
			foreach_reverse(i, c; cells)
			if(x1 >= c.outerPos.x)
			{ hi = cast(int)i+1; break; }
			
			return tuple(lo, hi); 
		} 
		
	} 
	
	private
	{
		 //wrappedLine[] functionality
		
		float calcHeight(WrappedLine[] lines)
		{
			return lines.length	? lines.back.bottom - lines[0].y0 //Todo: ezt nem menet kozben, hanem egy eloszamitaskent kene meghivni
				: 0; 
		} 
		
		float calcWidth(WrappedLine[] lines)
		{ return lines.length ? lines.map!"a.calcWidth".maxElement : 0; } 
		
		void translateY(WrappedLine[] lines, float dy)
		{
			if(dy)
			foreach(ref l; lines)
			l.translateY(dy); 
		} 
		
		void alignY(WrappedLine[] lines, float availableHeight, float t)
		{
			if(t)
			lines.translateY((availableHeight - lines.calcHeight)*t); 
		} 
		
		void justifyY(WrappedLine[] lines, float availableHeight)
		{
			if(lines.empty)
			return; 
			auto	remaining	= availableHeight - lines.calcHeight,
				step	= remaining / (lines.length),
				act	= step*.5; 
			
			if(step<=0)
			return; //Todo: shrink?
			
			foreach(ref l; lines)
			{
				l.translateY(act); 
				act += step; 
			}
		} 
		
		void hideSpaces(WrappedLine[] lines, HAlign hAlign)
		{
			foreach(l; lines)
			l.hideSpaces(hAlign); 
		} 
		
		///vertical cell align in each line. Only works right after the warpedLines was created
		void applyYAlign(WrappedLine[] lines, YAlign yAlign)
		{
			if(yAlign == YAlign.top)
			return; 
			if(yAlign != YAlign.top)
			foreach(ref wl; lines)
			final switch(yAlign)
			{
				case YAlign.center	: wl.alignY(0.5); 	break; 
				case YAlign.bottom	: wl.alignY(1.0); 	break; 
				case YAlign.baseline	: wl.alignY(0.8); 	break; 
				case YAlign.stretch	: wl.stretchY; 	break; 
				case YAlign.top	: 	break; 
			}
				
			
		} 
		
		///horizontal align.  Only works right after the warpedLines was created
		void applyHAlign(WrappedLine[] wrappedLines, HAlign hAlign, float targetWidth)
		{
			if(hAlign == HAlign.left)
			return; 
			foreach(ref wl; wrappedLines)
			final switch(hAlign)
			{
				case HAlign.center	: wl.alignX	(targetWidth, 0.5); 	break; 
				case HAlign.right	: wl.alignX	(targetWidth, 1); 	break; 
				case HAlign.justify	: wl.justifyX	(targetWidth); 	break; 
				case HAlign.left	: 		break; 
			}
			
		} 
		
		///vertical align.  Only works right after the warpedLines was created
		void applyVAlign(WrappedLine[] wrappedLines, VAlign vAlign, float targetHeight)
		{
			final switch(vAlign)
			{
				case VAlign.center	: wrappedLines.alignY	(targetHeight, 0.5); 	break; 
				case VAlign.bottom	: wrappedLines.alignY	(targetHeight, 1.0); 	break; 
				case VAlign.justify	: wrappedLines.justifyY	(targetHeight); 	break; 
				case VAlign.top	: 		break; 
			}
		} 
		
		
	} 
	
	
	//Elastic Tabs //////////////////////////////////////////
	
	
	void processElasticTabs(R)(R[] rows, in float flexMaxWidth = float.nan, in int level=0)  if(is(R==Cell) || is(R==WrappedLine))
	{
		/+
			Copyright: Nick Gravgaard
			licensed under a Creative Commons Attribution 3.0 Licence
			/+Link: https://nickgravgaard.com/elastic-tabstops+/
			/+Link: https://github.com/nickgravgaard/AlwaysAlignedVS/blob/master/LICENSE.md+/
			
			Copyright 2010-2017 Nick Gravgaard
			
			Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
			associated documentation files (the "Software"), to deal in the Software without restriction,
			including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
			and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
			subject to the following conditions:
			
			The above copyright notice and this permission notice shall be included in all copies or substantial
			portions of the Software.
			
			THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
			LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
			IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
			WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
			SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
		+/
		
		static if(is(R==Cell))
		{
			static int getTabCnt(in Cell c)
			{
				if(auto r = (cast(Row)(c)))
				return (cast(int)(r.tabIdxInternal.length)); 
				else return 0; 
			} 
			
			static int getTabIdx(in Cell c, int i)
			{
				if(auto r = (cast(Row)(c)))
				return r.tabIdxInternal[i]; 
				else return -1; 
			} 
			
			static float getTabPos(in Cell c, int i)
			{
				if(auto r = (cast(Row)(c)))
				return r.subCells[r.tabIdxInternal[i]].outerRight; 
				else return 0; 
			} 
			
			static Cell[] getSubCells(Cell c)
			{
				if(auto r = (cast(Row)(c)))
				return r.subCells; 
				else return []; 
			} 
		}static if(is(R==WrappedLine))
		{
			static int getTabCnt(in WrappedLine wl)
			=> (cast(int)(wl.cells.count!((c)=>(c.isTab))/+Opt: SLOW+/)); 
			
			static int getTabIdx(in WrappedLine wl, int i)
			{
				int j; //Opt: SLOW
				foreach(idx, const cell; wl.cells)
				{
					if(cell.isTab)
					{
						if(j==i)
						return cast(int) idx; 
						j++; 
					}
				}
				return -1; 
			} 
			//Opt: WrappedLine tab processing is terribly unoptimal
			
			static float getTabPos(in WrappedLine wl, int i)
			=> wl.cells[getTabIdx(wl, i)].outerRight; 
			
			static Cell[] getSubCells(WrappedLine wl)
			=> wl.cells; 
			
			
			
			
			
			
			
			
			
		}
		
		static struct FlexCellStats
		{
			int flexCnt; 
			float totalFlexWidth=0, totalFlexRatio=0, invFlexRatio=0; 
			
			bool valid() const => flexCnt && totalFlexRatio; 
			bool opCast(B:bool)() const => valid; 
			
			void growFlexCellsBackwardsUntilTab(Cell[] cells, float actRightPos, float Δ)
			{
				if(!valid) return; 
				foreach_reverse(c; cells)
				{
					if(c.isTab) break; 
					if(c.flex)
					{
						c.outerWidth += Δ * (c.flex * invFlexRatio); 
						if(auto cntr = (cast(Container)(c)))
						{
							cntr.flags.autoHeight = false; cntr.measure; 
							//Todo: height can change if wordwrapped!!!
						}
					}
					
					//align all cells while going to the left
					c.outerPos.x = actRightPos - c.outerWidth; 
					actRightPos = c.outerPos.x; //adcance
				}
			} 
		} 
		static FlexCellStats summarizeFlexCellsBackwardsUntilTab(Cell[] cells)
		{
			FlexCellStats res; 
			with(res) {
				//collect statistics about flex cells
				foreach_reverse(c; cells)
				{
					if(c.isTab) break; 
					if(c.flex) {
						flexCnt 	+= 1,
						totalFlexWidth 	+= c.outerWidth,
						totalFlexRatio	+= c.flex; 
					}
				}
				if(totalFlexRatio) invFlexRatio = 1.0f / totalFlexRatio; 
			}
			return res; 
		} 
		
		enum ε = AlignEpsilon; 
		const doFlex = !flexMaxWidth.isnan && level==0; 
		while(1)
		{
			//search the islands
			bool tabCntGood(T)(in T row)
			=> getTabCnt(row) > level; 
			while(rows.length && !tabCntGood(rows[0]))
			rows = rows[1..$]; 
			int n; while(
				n<rows.length && 
				tabCntGood(rows[n])
			) n++; if(!n)
			break; 
			auto range = rows[0..n]; 
			
			const rightMostTabPos = range.map!((r)=>(getTabPos(r, level))).maxElement; 
			
			bool anyFlexToTheRight /+true if any row has a flex cell after the first tab+/; 
			foreach(row; range)
			{
				auto 	subCells 	= getSubCells(row),
					tIdx 	= getTabIdx(row, level),
					tab 	= subCells[tIdx],
					Δ 	= rightMostTabPos - (tab.outerRight); 
				
				if(Δ>ε /+can't be negative+/)
				{
					if(auto flexStats = summarizeFlexCellsBackwardsUntilTab(subCells[0..tIdx]))
					{
						//move the Tab to the right,, flex cells will grow to that space
						tab.outerPos.x += Δ; 
						//spread Δ across flex cells, align other cells to the right
						flexStats.growFlexCellsBackwardsUntilTab
							(subCells[0..tIdx], tab.outerPos.x, Δ); 
					}
					else
					{
						//extend the Tab to the right
						tab.innerWidth = tab.innerWidth + Δ; 
					}
					
					version(/+$DIDE_REGION Shift all cells on the right side of the tab to the right+/all)
					{ subCells[tIdx+1..$].spreadH(tab.outerRight); }
				}
				
				if(doFlex && !anyFlexToTheRight)
				{ anyFlexToTheRight = subCells[tIdx+1..$].map!((c)=>(c.flex!=0)).any; }
				
				if(VisualizeTabColors)
				{ (cast(Glyph)(tab)).bkColor = mix(clGray, clRainbow[level%$], .25f); }
			}
			processElasticTabs(range, flexMaxWidth, level+1); //recursive
			
			if(doFlex && (false || anyFlexToTheRight))
			{
				foreach(row; range)
				{
					auto 	subCells 	= getSubCells(row),
						Δ 	= subCells.back.outerRight - flexMaxWidth; 
					if(Δ>ε /+avoid float sum precision loss+/)
					{
						if(auto flexStats = summarizeFlexCellsBackwardsUntilTab(subCells))
						{
							//spread Δ across flex cells, align other cells to the right
							flexStats.growFlexCellsBackwardsUntilTab
								(
								subCells, flexMaxWidth, -Δ
								/+the actual grow direction is negative!+/
							); 
						}
					}
				}
			}
			
			rows = rows[n..$]; //advance
		}
	} 
	
	
	enum WrapMode { clip, wrap, shrink } 
	//Todo: Implement WrapMode.  break word, spaces on edges, tabs vs wrap???
	
	
	enum ScrollState
	{ off, on, autoOff, autoOn, auto_ = autoOff}  bool getEffectiveScroll(ScrollState s) pure
	=> s.among(ScrollState.on, ScrollState.autoOn)>0; 
	
	struct ContainerFlags
	{
		mixin((
			(表([
				[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
				[q{bool},q{1},q{"enabled"},q{1},q{/++/}],
				[q{bool},q{1},q{"clickable"},q{1},q{/+If false, hittest will not check this as clicked. It checks the parent instead.+/}],
				[q{bool},q{1},q{"focused"},q{},q{/+readonly.+/}],
				[q{bool},q{1},q{"hover"},q{},q{/+readonly. Anything with a HitRec sets this.+/}],
				[q{bool},q{1},q{"captured"},q{},q{/+readonly. Anything with a HitRec sets this.+/}],
				[q{bool},q{1},q{"selected"},q{},q{/++/}],
				[],
				[q{//Size / scrolling
				}],
				[q{bool},q{1},q{"autoWidth"},q{},q{/+kinda readonly: It's set by Container in measure to outerSize!=0+/}],
				[q{bool},q{1},q{"autoHeight"},q{},q{/+later everything else can read it.+/}],
				[q{ScrollState},q{2},q{"hScrollState"},q{},q{/++/}],
				[q{ScrollState},q{2},q{"vScrollState"},q{},q{/++/}],
				[],
				[q{//Visuals
				}],
				[q{TargetSurface},q{1},q{"targetSurface"},q{1},q{/+0: zoomable view, 1: GUI screen+/}],
				[q{bool},q{1},q{"hidden"},q{},q{/+disable all draw calls recursively+/}],
				[q{bool},q{1},q{"noBackground"},q{},q{/++/}],
				[q{bool},q{1},q{"clipSubCells"},q{},q{/+drawings will be clipped outside the container's visible area.+/}],
				[q{bool},q{1},q{"cullSubCells"},q{},q{/+only those cells will be drawn which are in the container's visible area.+/}],
				[],
				[q{//Behavior
				}],
				[q{bool},q{1},q{"dontSearch"},q{},q{/+no search() inside this container+/}],
				[q{bool},q{1},q{"dontHitTest"},q{},q{/+don't even bother to add this container and it's subcontainers to the hit list.+/}],
				[q{bool},q{1},q{"dontLocate"},q{},q{/+disables the locate() method for this container and its subcontainers+/}],
				[],
				[q{//Change detection
				}],
				[q{bool},q{1},q{"oldSelected"},q{},q{/+SelectionManager2 needs this.+/}],
				[q{bool},q{1},q{"changedCreated"},q{},q{/+Dide2.CodeRow: changed by creationg a new cell+/}],
				[q{bool},q{1},q{"changedRemoved"},q{},q{/+Dide2.CodeRow: changed by removing existing cells+/}],
				[q{bool},q{1},q{"removed"},q{},q{/+At the moment it is only used by DIDE: SearchResults, BuildMessages can detect validity+/}],
				[],
				[q{//System managed
				}],
				[q{bool},q{1},q{"_measureOnlyOnce"},q{},q{/++/}],
				[q{bool},q{1},q{"_measured"},q{},q{/+used to tell if a top level container was measured already+/}],
				[q{bool},q{1},q{"_saveVisibleBounds"},q{},q{/+draw() will save the visible innerBounds into imstVisibleBounds+/}],
				[q{bool},q{1},q{"_saveOuterBounds"},q{},q{/+draw() will save the outer world outerBounds into imstOuterBounds +/}],
				[q{bool},q{1},q{"_hasDrawCallback"},q{},q{/++/}],
				[q{bool},q{1},q{"_hasHScrollBar"},q{},q{/+readonly.+/}],
				[q{bool},q{1},q{"_hasVScrollBar"},q{},q{/+readonly.+/}],
				[q{bool},q{1},q{"_debug"},q{},q{/+the container can be marked, for debugging+/}],
			]))
		) .GEN!q{GEN_bitfields}); 
	} 
	static assert(ContainerFlags.sizeof==4); 
	
	struct RowFlags
	{
		mixin((
			(表([
				[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
				[q{bool},q{1},q{"wordWrap"},q{1},q{/++/}],
				[q{HAlign},q{2},q{"hAlign"},q{},q{/+alignment for all subCells+/}],
				[q{VAlign},q{2},q{"vAlign"},q{},q{/++/}],
				[q{YAlign},q{3},q{"yAlign"},q{1},q{/++/}],
				[q{bool},q{1},q{"dontHideSpaces"},q{},q{/+useful for active edit mode+/}],
				[q{bool},q{1},q{"rowElasticTabs"},q{},q{/+Row will do elastic tabs inside its own WrappedLines.+/}],
				[q{bool},q{1},q{"acceptEditorKeys"},q{},q{/+accepts Enter and Tab if it is a textEditor. Conflicts with transaction mode.+/}],
				[q{bool},q{1},q{"btnRowLines"},q{},q{/+draw thin, dark lines between the buttons of a btnRow+/}],
				[q{bool},q{1},q{"strictCellOrder"},q{},q{/++/}],
			]))
		) .GEN!q{GEN_bitfields}); 
	} 
	static assert(RowFlags.sizeof==2); 
	
	struct ColumnFlags
	{
		mixin((
			(表([
				[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
				[q{bool},q{1},q{"columnElasticTabs"},q{1},q{/+Column will do ElasticTabs its own Rows.+/}],
				[q{bool},q{1},q{"dontStretchSubCells"},q{},q{/+Column: don't stretch the items to the innerWidth of the column.+/}],
				[q{bool},q{1},q{"columnIsTable"},q{},q{/+At the moment it is only used by DIDE+/}],
				[q{uint},q{3},q{"languageId"},q{},q{/+0: DLang/GLSL (Default), 1: SQL+/}],
			]))
		) .GEN!q{GEN_bitfields}); 
	} 
	static assert(ColumnFlags.sizeof==1); 
	
	
	//Effective horizontal and vertical flow configuration of subCells
	enum FlowConfig
	{autoSize, wrap, noScroll, scroll, autoScroll} 
	
	auto getHFlowConfig(in bool autoWidth, in bool wordWrap, in ScrollState hScroll) pure
	=> autoWidth 	? FlowConfig.autoSize 	:
		wordWrap	? FlowConfig.wrap 	:
		hScroll==ScrollState.off 	? FlowConfig.noScroll 	:
		hScroll==ScrollState.on 	? FlowConfig.scroll 
			: FlowConfig.autoScroll; 
	
	bool getEffectiveHScroll(in bool autoWidth, in bool wordWrap, in ScrollState hScroll) pure
	=> !autoWidth && !wordWrap && hScroll.getEffectiveScroll; 
	
	auto getVFlowConfig(in bool autoHeight, in ScrollState vScroll) pure
	=> autoHeight 	? FlowConfig.autoSize 	:
		vScroll==ScrollState.off	? FlowConfig.noScroll 	:
		vScroll==ScrollState.on	? FlowConfig.scroll 
			: FlowConfig.autoScroll; 
	
	bool getEffectiveVScroll(in bool autoHeight, in ScrollState vScroll) pure
	=> !autoHeight && vScroll.getEffectiveScroll; 
	
}
version(/+$DIDE_REGION+/all)
{
	class Container : Cell
	{
		Cell[] subCells; 
		SrcId id; //Scrolling needs it. Also useful for debugging. Also DIDE heavily relies on it.
		ContainerFlags flags; 
		ColumnFlags colFlags; 
		RGB bkColor=clWhite; //Todo: background struct
		protected
		{
			Margin margin_; 
			Padding padding_; 
			Border border_; 
			FlexAmount flex_; 
		} 
		
		auto getHScrollBar()
		{ return flags._hasHScrollBar ? im.hScrollInfo.getScrollBar(id) : null; } 
		auto getVScrollBar()
		{ return flags._hasVScrollBar ? im.vScrollInfo.getScrollBar(id) : null; } 
		auto getHScrollOffset()
		{ return flags._hasHScrollBar ? im.hScrollInfo.getScrollOffset(id) : 0; } 
		auto getVScrollOffset()
		{ return flags._hasVScrollBar ? im.vScrollInfo.getScrollOffset(id) : 0; } 
		auto getScrollOffset()
		{ return vec2(getHScrollOffset, getVScrollOffset); } 
		
		
		void clearSubCells()
		{ subCells = []; } 
		
		final auto subContainers()
		=> subCells.map!((c)=>((cast(Container)(c)))).filter!"a"; 
		
		void appendCell(Cell c)
		{
			//This is the central append function. It can be overridden.
			if(c)	subCells ~= c; 
		} 
		
		int cellCount() const
		=> (cast(int)(subCells.length)); 
		
		int subCellIndex(in Cell c) const
		{
			//Note: overflows at 2G items, I don't care because that would be 128GB memory usage.
			return (cast(int)(subCells.countUntil(c))); 
		} 
		
		void adoptSubCells()
		{ subCells.each!((c)=>(c.setParent(this))); } 
		
		bool empty() const
		=> subCells.empty /+not final, because CodeColumn is more complex than this+/; 
		
		final void append(Cell c)
		{ appendCell(c); } 
		final void append(Cell[] r)
		{ r.each!((c)=>(appendCell(c))); } 
		
		final void append(void delegate() fun)
		{ append(im.buildCells(fun)); } 
		
		void	appendImg (File fn, in TextStyle ts)
		{ appendCell(new Img(fn, ts.bkColor)); } 
		void	appendChar(dchar ch, in TextStyle ts)
		{ appendCell(new Glyph(ch, ts)); } 
		void appendStr (string s, in TextStyle ts)
		{
			foreach(ch; s.byDchar) appendChar(ch, ts); 
			/+byDchar is important! char is the default for string!+/
		} 
		
		void appendCodeChar(dchar	ch, in TextStyle ts, SyntaxKind sk)
		{ appendCell(new Glyph(ch, ts, sk)); } 
		void appendCodeStr(string s, in TextStyle ts, SyntaxKind sk)
		{ foreach(ch; s.byDchar) appendCodeChar(ch, ts, sk); } 
		
		void appendCodeStr(string s, SyntaxKind sk)
		{
			static TextStyle style; style.applySyntax(sk); 
			appendCodeStr(s, style, sk); 
		} 
		
		void appendSyntaxChar(dchar ch, in TextStyle ts, in SyntaxKind syntax)
		{
			//Todo: redundant: there is appendCodeChar too
			auto g = new Glyph(ch, ts, syntax); 
			appendCell(g); 
		} 
		
		void appendSyntaxCharWithLineIdx(dchar ch, in TextStyle ts, in SyntaxKind syntax, in int lineIdx)
		{
			//Todo: this is used from CodeCOlumnBuildet.
			auto g = new Glyph(ch, ts, syntax); 
			g.lineIdx = lineIdx; 
			appendCell(g); 
		} 
		
		auto removeLast(T = Cell)()
		{ return cast(T)(subCells.fetchBack); } 
		auto removeLastContainer()
		{ return removeLast!Container; } 
		
		bool removeLastChar(dchar ch)
		{
			if(subCells.length)
			if(auto c = cast(Glyph)subCells.back)
			if(c.ch==ch)
			{
				subCells = subCells[0..$-1]; 
				return true; 
			}
			return false; 
		} 
		
		bool removeLastNewLine()
		{
			if(removeLastChar('\n'))
			{
				removeLastChar('\r'); 
				return true; 
			}
			return false; 
		} 
		
		final override
		{
			ref FlexAmount flex()
			=> flex_	; 
			ref Margin margin ()
			=> margin_	; 
			ref Padding padding()
			=> padding_; 
			ref Border border ()
			=> border_; 
		} 
		
		override void setProps(string[string] p)
		{
			super.setProps(p); 
			
			margin_ .setProps(p, "margin" ); 
			padding_.setProps(p, "padding"); 
			border_ .setProps(p, "border" ); 
			
			p.setParam("flex"   , (float	f){ flex_	= f; }); 
			p.setParam("bkColor", (RGB	c){ bkColor	= c; }); 
			
			//Todo: flags.setProps param
		} 
		
		void parse(string s, TextStyle ts = tsNormal)
		{ enforce("notimpl"); } 
		
		
		protected
		{
			bool getWordWrap() const
			{
				if(auto row = (cast(Row)(this))) return row.rowFlags.wordWrap; 
				return false; 
			} 
			
			auto getHFlowConfig() const
			=> .getHFlowConfig(flags.autoWidth, getWordWrap, flags.hScrollState); 
			auto getEffectiveHScroll() const
			=> .getEffectiveHScroll(flags.autoWidth, getWordWrap, flags.hScrollState); 
			auto getVFlowConfig() const
			=> .getVFlowConfig(flags.autoHeight, flags.vScrollState); 
			auto getEffectiveVScroll() const
			=> .getEffectiveVScroll(flags.autoHeight, flags.vScrollState); 
		} 
		
		float calcContentWidth()
		=> subCells.map!((c)=>(c.outerRight)).maxElement(0); 
		float calcContentHeight()
		=> subCells.map!((c)=>(c.outerBottom)).maxElement(0); 
		vec2 calcContentSize()
		=> vec2(calcContentWidth, calcContentHeight); 
		
		final void setSubContainerWidths(bool setAll=true)(float targetWidth)
		{
			foreach(c; subContainers)
			if(setAll || (magnitude(c.outerWidth-targetWidth)) > AlignEpsilon)
			{
				c.outerWidth = targetWidth; 
				c.flags.autoWidth = false; 
				c.measure; 
			}
		} 
		
		final void setSubContainerWidths_differentOnly(float targetWidth)
		{ setSubContainerWidths!false(targetWidth); } 
		
		/// this must overrided by every descendant. Its task is to measure and then place all the subcells.
		/// must update innerSize if autoWidth or autoHeight is specified.
		void rearrange()
		{
			measureSubCells; 
			if(flags.autoWidth)
			innerWidth = calcContentWidth; 
			if(flags.autoHeight)
			innerHeight = calcContentHeight; 
		} 
		
		/// Mark the container, so it will be re-measured on the next measure() call.
		/// Normal behaviour is ALWAYS measure. (It is the normal behaviour for immediate mode UI)
		/// returns: If it was effective. So it could do more things recursively.
		bool needMeasure()
		{
			flags._measureOnlyOnce = true; 
			
			if(flags._measured)
			{
				//preserve autoWidth and autoHeight for the next measure
				//Todo: this is not completely sane...
				//if(flags.autoWidth ) outerSize.x = 0;
				//if(flags.autoHeight) outerSize.y = 0;
			}
			
			const effective = flags._measured; 
			if(effective)
			{
				flags._measured = false; 
				//outerSize.x = 0;   //todo: this is how to make it autosize. it's lame.
				//outerSize.y = 0;
			}
			
			if(auto c = getParent)
			c.needMeasure; 
			
			return effective; 
		} 
		
		/// this must be called from outside. It calls rearrange and measures subContainers if needed.
		final void measure()
		{
			if(flags._measureOnlyOnce && flags._measured)
			return; 
			
			//autodetect autoWidth and autoHeight. If the user didn't changed it, then it's auto.
			if(!flags._measured)
			flags.autoWidth 	= outerSize.x==0, 
			flags.autoHeight 	= outerSize.y==0; 
			
			const 	hFlow 	= getHFlowConfig, 
				vFlow 	= getVFlowConfig, 
				maxFlow 	= max(hFlow, vFlow); 
			
			const 	scrollThickness 	= DefaultScrollThickness,
				e 	= 1/+minimum area that must remain after the scrollbar.+/; 
			
			bool alloc(char o)()
			{
				const size = innerSize; 
				static if(o=='H')
				if(
					size.x>=e && (
						size.y>=scrollThickness+e || 
						vFlow==FlowConfig.autoSize
					) && !flags._hasHScrollBar
				)
				{
					flags._hasHScrollBar = true; if(vFlow!=FlowConfig.autoSize)
					outerSize.y -= scrollThickness; 
					return true; 
				}
				static if(o=='V')
				if(
					size.y>=e && (
						size.x>=scrollThickness+e || 
						hFlow==FlowConfig.autoSize
					) && !flags._hasVScrollBar
				)
				{
					flags._hasVScrollBar = true; if(hFlow!=FlowConfig.autoSize)
					outerSize.x -= scrollThickness; 
					return true; 
				}
				return false; 
			} 
			
			void handleNoScroll()
			{
				//very simple case with no scrolling, only autoSizing and wordWrapping
				rearrange; 
			} 
			
			void handlePersistents()
			{
				//there can be scrollbars, but no autoScrollbars
				if(hFlow==FlowConfig.scroll)
				alloc!'H'; if(vFlow==FlowConfig.scroll)
				alloc!'V'; 
				rearrange; 
			} 
			
			void handleBothAuto()
			{
				//2 auto scrollbars
				rearrange; 
				const cs = calcContentSize; 
				/+
					Opt: rearrange should return contentSize 
					because calcContentSize is slow
				+/
				if(cs.y>innerHeight)
				{
					if(cs.x>innerWidth)
					{
						//H&V overflow
						alloc!'H'; alloc!'V'; 
					}
					else
					{
						//V overflow
						if(alloc!'V' && cs.x > innerWidth)
						{
							//possivle H overflow because of VScrollBar
							if((cast(Column)(this)))	rearrange; 
							else	alloc!'H'; 
							//Other things will need a scrollbar
						}
					}
				}
				else
				{
					if(cs.x>innerWidth)
					{
						//H overflow
						if(alloc!'H' && cs.y > innerHeight)
						{ alloc!'V'; }
						//possivle V overflow because of HScrollBar
					}
				}
			} 
			void handleHAuto()
			{
				//only auto hscroll
				if(vFlow==FlowConfig.scroll)
				alloc!'V'; //alloc fixed if needed
				rearrange; 
				if(calcContentWidth > innerWidth)
				alloc!'H'; 
			} 
			
			void handleVAuto()
			{
				//only auto vscroll
				if(hFlow==FlowConfig.scroll)
				alloc!'H'; //alloc fixed if needed
				rearrange; 
				/+
					Opt: This rearrange can exit early when the wordWrap 
					and contentheight becomes too much.
				+/
				if(calcContentHeight > innerHeight)
				{
					if(
						alloc!'V' && (
							hFlow==FlowConfig.wrap || cast(Column)this
							/*column also changes the width!*/
						)
					)
					{
						rearrange; 
						//second rearrange
						version(none)
						{
							/+I think this is overkill, not needed: +/
							if(
								!flags.hasHScrollBar && 
								calcContentWidth > innerWidth
							) alloc!'H'; 
						}
					}
				}
			} 
			
			//detect scrollbars
			flags._hasHScrollBar = false; 
			flags._hasVScrollBar = false; 
			
			if(maxFlow<=FlowConfig.noScroll)
			{ handleNoScroll; }
			else
			{
				//scrollbars are a possibility from here
				if(maxFlow<=FlowConfig.scroll)
				{ handlePersistents; }
				else
				{
					//at least one axis is autoScroll, this is the most complicated case.
					if(
						hFlow==FlowConfig.autoScroll && 
						vFlow==FlowConfig.autoScroll
					)	handleBothAuto; 
					else if(hFlow==FlowConfig.autoScroll)	handleHAuto; 
					else	handleVAuto; 
				}
				
				//setup the scrollbars
				if(flags._hasHScrollBar)
				im.hScrollInfo.update(this, calcContentWidth, innerWidth); 
				if(flags._hasVScrollBar)
				im.vScrollInfo.update(this, calcContentHeight, innerHeight); 
				
				/+
					restore size after rearrange. 
					(Autosize wont subtract the scrollbarthickness, so it will be added here as an extra.)
				+/
				if(flags._hasHScrollBar)
				outerSize.y += scrollThickness; 
				if(flags._hasVScrollBar)
				outerSize.x += scrollThickness; 
			}
			
			flags._measured = true; 
		} 
		
		
		protected void measureSubCells()
		{
			subContainers.each!"a.measure"; //recursive in the front
		} 
		
		protected auto getScrollResizeBounds(in Cell hb, in Cell vb) const
		{ return bounds2(vb.outerPos.x, hb.outerPos.y, innerWidth, innerHeight); } 
		
		static Cell[] sortedSubCellsAroundAxis(int axis)(Cell[] subCells, vec2 p)
		{
			 //Note: only tests for the given direction. It's a speedup for internal_hitTest.
			auto sc = subCells; 
			if(sc.length)
			{
				//2 binary searches      //note: does not work with vertical newLine!!!
				const lowerCnt = sc.map!(c => c.outerPos[axis] + c.outerSize[axis]).assumeSorted.lowerBound(p[axis]).length; //drop cells on top
				sc = sc[lowerCnt..$]; 
				if(sc.length)
				{
					const higherCnt = sc.map!(c => c.outerPos[axis]).assumeSorted.upperBound(p[axis]).length; //drop cells on bottom
					sc = sc[0..$-higherCnt]; 
				}
			}
			return sc; 
		} 
		
		static Cell[] sortedSubCellsAroundX(Cell[] subCells, vec2 p)
		{ return sortedSubCellsAroundAxis!0(subCells, p); } 
		static Cell[] sortedSubCellsAroundY(Cell[] subCells, vec2 p)
		{ return sortedSubCellsAroundAxis!1(subCells, p); } 
		
		Cell[] internal_hitTest_filteredSubCells(vec2 p)
		{
			 //Note: for column, it only needs to filter the y direction because this is just an optimization.
			//slow linear filter
			//Todo: this should return a range not an array
			return subCells.filter!(c => c.outerBounds.contains!"[)"(p)).array; //otp: what if I unroll it to 4 comparations?
		} 
		
		override bool internal_hitTest(in vec2 mouse, vec2 ofs=vec2(0))
		{
			if(super.internal_hitTest(mouse, ofs))
			{
				//flags.hovered = true; //note: can't update 'hovered' flag here because hitTest does NOT evaluate the WHOLE tree.
				
				ofs += innerPos; 
				
				auto hb = getHScrollBar, vb = getVScrollBar; 
				if(vb)
				if(vb.internal_hitTest(mouse, ofs))
				return true; 
				if(hb)
				if(hb.internal_hitTest(mouse, ofs))
				return true; 
				if(vb&&hb)
				{
					const bnd = getScrollResizeBounds(hb, vb); 
					if(bnd.contains!"[)"(mouse-ofs))
					{
						//Todo: resizeButton area between 2 scrollBars. It is now just ignored.
						return true; 
					}
				}
				
				ofs -= getScrollOffset; 
				
				foreach_reverse(sc; internal_hitTest_filteredSubCells(mouse-ofs))
				if(sc.internal_hitTest(mouse, ofs))
				return true; //recursive
				return true; 
			}
			else
			{
				//flags.hovered = false;
				return false; 
			}
		} 
		
		///This version of hit_test is for static stuff. It ignores scrollbars but has a fast optimizes search in rows and columns
		override CellLocation[] locate(in vec2 mouse, vec2 ofs=vec2(0))
		{
			if(flags.dontLocate)
			return []; 
			auto res = super.locate(mouse, ofs); 
			if(res.length)
			{
				ofs += innerPos; 
				res ~= internal_hitTest_filteredSubCells(mouse-ofs).map!(a => a.locate(mouse, ofs)).join; 
				//this is the optimized search function specific to custom containers.
				//The order is forward. Visits every container, not just the first it finds. Overlays containers should be filtered out later.
			}
			return res; 
		} 
		
		///this hitTest only works after measure.
		override Tuple!(Cell, vec2)[] contains(in vec2 p, vec2 ofs=vec2.init)
		{
			auto res = super.contains(p, ofs); 
			
			if(res.length)
			{
				ofs += innerPos - getScrollOffset; 
				foreach(sc; subCells)
				{
					auto act = sc.contains(p, ofs); 
					if(act.length)
					{
						res ~= act; 
						break; 
					}
				}
			}
			
			return res; 
		} 
		
		T pick(T : Cell = Cell)(in vec2 p)
		{
			//it returns the topmost subCell. It's not recursive. coordinate is local.
			foreach_reverse(sc; cubCells)
			if(sc.outerBounds.contains!"[)"(p)) return sc; 
			return null; 
		} 
		
		void onDraw(Drawing dr)
		{} //can override to draw some custom things.
		
		
		void visitSubCells_cull(bounds2 clipBounds, void delegate(Cell) fun)
		{
			//this uses linear search. It can be optimized in subClasses.
			if(clipBounds)
			{
				foreach(c; subCells)
				if(clipBounds.overlaps(c.outerBounds))
				fun(c); 
			}
		} 
		
		final void drawSubCells_cull(Drawing dr)
		{
			//this uses linear search. It can be optimized in subClasses.
			if(auto b = dr.clipBounds)
			{
				b = dr.inverseInputTransform(b); 
				visitSubCells_cull(b, (c){ c.draw(dr); }); 
			}
		} 
		
		static bounds2 _savedComboBounds; //when saveComboBounds flag is active it saves the absolute bounds
		
		override void draw(Drawing dr)
		{
			if(flags.hidden) return; 
			//Todo: automatic measure when needed. Currently it is not so well. Because of elastic tabs.
			//if(chkSet(measured)) measure;
			
			if(border.borderFirst) {
				border.color = bkColor; 
				drawBorder(dr); //for code editor
			}
			
			//autofill background
			if(!flags.noBackground)
			{
				dr.color = bkColor; //Todo: refactor backgorund and border drawing to functions
				
				if(border.borderFirst)	{ dr.fillRect(innerBounds); }
				else	{ dr.fillRect(border.adjustBounds(borderBounds_inner)); }
			}
			
			const 	scrollOffset = getScrollOffset,
				hasScrollOffset = !isnull(scrollOffset); 
			
			if(flags._saveVisibleBounds)
			{ imstVisibleBounds(id) = bounds2(scrollOffset, scrollOffset+innerSize); }
			if(flags._saveOuterBounds)
			{ imstOuterBounds(id) = dr.inputTransform(outerBounds); }
			
			dr.translate(innerPos); 
			const useClipBounds = flags.clipSubCells; 
			if(useClipBounds)
			dr.pushClipBounds(bounds2(0, 0, innerWidth, innerHeight)); 
			
			if(hasScrollOffset) dr.translate(-scrollOffset); 
			
			//recursively draw subCells
			if(flags.cullSubCells)	{
				drawSubCells_cull(dr); //it can be optimized
			}
			else	{ subCells.each!(c => c.draw(dr)); }
			
			version(/+$DIDE_REGION+/none) { if(flags._hasOverlayDrawing) dr.copyFrom(g_getOverlayDrawing(this)); }
			
			if(flags._hasDrawCallback) g_getDrawCallback(this)(dr, this); 
			
			onDraw(dr); 
			
			if(hasScrollOffset) dr.pop; 
			
			{
				auto hb = getHScrollBar, vb = getVScrollBar; 
				if(hb || vb)
				{
					if(hb) hb.draw(dr);  //Todo: getHScrollBar?.draw(gl);
					if(vb) vb.draw(dr); 
					
					if(hb&&vb) {
						const bnd = getScrollResizeBounds(hb, vb); 
						dr.color = clScrollBk; 
						dr.fillRect(bnd); 
					}
				}
			}
			
			if(useClipBounds) dr.popClipBounds; 
			dr.pop; 
			
			if(!border.borderFirst) drawBorder(dr); //border is the last by default
			
			drawDebug(dr); 
		} 
		
		void drawDebug(Drawing dr)
		{
			if(VisualizeContainers)
			{
				if(cast(Column)this)
				{ dr.color = clRed; }
				else if(cast(Row)this) { dr.color = clBlue; }
				else dr.color = clLime; 
				
				dr.lineWidth = 1; 
				dr.lineStyle = LineStyle.normal; 
				dr.drawRect(outerBounds.inflated(-1.5)); 
			}
			
			if(VisualizeContainerIds)
			{
				dr.fontHeight = 14; 
				dr.color = clFuchsia; 
				dr.textOut(outerPos+vec2(3), id.text); 
			}
		} 
		
		
		version(/+$DIDE_REGION+/none) {
			//these can mixed in
			mixin template CachedDrawing()
			{
				Drawing cachedDrawing; 
				
				override void draw(Drawing dr)
				{
					if(dr.isClone)
					{
						super.draw(dr); //prevent recursion
						print("Drawing recursion prevented"); 
					}
					else
					{
						if(!cachedDrawing)
						{
							cachedDrawing = dr.clone; 
							super.draw(cachedDrawing); 
						}
						dr.subDraw(cachedDrawing); 
					}
				} 
			}; 
		}
		version(/+$DIDE_REGION Search+/all)
		{
			static struct SearchOptions
			{
				enum BoundaryType : byte {none, word, line /+otlet: Tab is lehetne+/} 
				
				bool caseSensitive; 
				BoundaryType 	boundaryTypeStart, 
					boundaryTypeEnd; 
				
				static foreach(
					name, bt; [
						"wholeWords"	: BoundaryType.word,
						"wholeLines"	: BoundaryType.line
					]
				)
				mixin(iq{
					@property $(name)() const
					=> boundaryTypeStart 	== $(bt.stringof) &&
					boundaryTypeEnd	== $(bt.stringof); 
					@property $(name)(bool a)
					{
						const b = ((a)?($(bt.stringof)):(BoundaryType.none)); 
						boundaryTypeStart = b; 
						boundaryTypeEnd = b; 
					} 
					void $(name)_toggle()
					{$(name) = !$(name); } 
				}.text); 
			} 
			
			static struct SearchResult
			{
				Container container; 
				vec2 absInnerPos; 
				Cell[] cells; //Todo: if this is empty, the whole container should be marked
				Object reference; //user can use it to identify the search result
				bool showArrow = true; //The searchresult is amade out of multiple parts. Only one of those should display an arrow.
				
				
				bool valid() const
				{ return !!container; } bool opCast(T : bool)() const
				{ return valid; } 
				
				auto cellBounds() const
				{ return cells.map!(c => c.outerBounds + absInnerPos); } 
				auto bounds() const
				{ return cellBounds.fold!"a|b"(bounds2.init); } 
				
				void drawHighlighted(Drawing dr, RGB clHighlight) const
				{
					foreach(cell; cells)
					if(auto glyph = cast(Glyph)cell)
					with(glyph)
					{
						dr.color = bkColor; 
						dr.drawFontGlyph((cast(int)(stIdx)), innerBounds + absInnerPos, clHighlight, fontFlags); 
					}
				} 
			} 
			
			auto search(A...)(string searchText, A args)
			{
				SearchOptions o; 
				vec2 origin = vec2(0); 
				void delegate(SearchResult) cb; 
				DateTime* dt; 
				
				static foreach(i, a; args)
				{
					{
						alias T = A[i]; 
						static if((is(T : Flag!"caseSensitive"))) o.caseSensitive = !!a; 
						else static if((is(T : Flag!"wholeWords"))) o.wholeWords = !!a; 
						else static if((is(T : vec2))) origin = a; 
						else static if((is(T : void delegate(SearchResult)))) cb = a; 
						else static if((is(T : DateTime*))) dt = a; 
						else static assert(0, "Unhandled type"); 
					}
				}
				
				return search(searchText, o, origin, cb, dt); 
			} 
			/// do a recursive visit. Search result and continuation is supplied by alias functions
			auto search(
				string searchText, SearchOptions options = SearchOptions.init, 
				vec2 origin = vec2.init, 	/+The world position of this container (innerPos=origin).+/
				void delegate(SearchResult) onMatch = null, 	/+
					When set, it will return the results using this callback.
					And not collecting results in an array.
				+/
				DateTime* timeLimit=null	/+If this is reached, it will call Fiber.yield;+/
			)
			{
				enum MeasureStack = false; /+measured: 24K, level:84+/
				
				static struct SearchContext
				{
					dstring searchText; 
					SearchOptions options; 
					vec2 absInnerPos; 
					void delegate(SearchResult) onMatch; 
					DateTime* timeLimit; 
					//---------------------------------------
					
					Cell[] cellPath; 
					
					SearchResult[] results; 
					int maxResults = 9999; 
					
					bool canStop() const
					{ return results.length >= maxResults; } 
					
					static if(MeasureStack) ulong baseSP; 
				} 
				
				static bool cntrSearchImpl(Container thisC, ref SearchContext context)
				{
					//returns: "you can exit from recursion now"    It is possible to do an optimized exit when context.canStop==true.
					if(thisC.flags.dontSearch)
					return false; 
					
					//recursive entry/leave
					context.cellPath ~= thisC; 
					const previousAbsInnerPos = context.absInnerPos; 
					context.absInnerPos += thisC.innerPos; 
					
					scope(exit)
					{
						static if(MeasureStack)
						{
							{
								ulong tmp; asm { mov tmp, RSP; } 
								long actPos = context.baseSP-tmp; 
								static long maxPos; 
								if(maxPos < actPos) { maxPos = actPos; print(actPos, context.cellPath.length); }
								
								/+
									Todo: Write a guard for this.  Get the cache size from the outside and 
									make an Exception when running low.
								+/
							}
						}
						
						context.absInnerPos = previousAbsInnerPos; 
						context.cellPath.popBack; 
						
						if(context.timeLimit && now > *context.timeLimit)
						{ import core.thread.fiber; Fiber.yield; /+Note: Fiber time limitation.+/}
					}
					
					//print("enter");
					
					Cell[] cells = thisC.subCells; 
					size_t baseIdx; 
					foreach(isGlyph, len; cells.map!(c => cast(Glyph)c !is null).group)
					{
						auto act = cells[baseIdx..baseIdx+len]; 
						
						if(!isGlyph)
						{
							foreach(c; act.map!(c => cast(Container)c).filter!"a")
							{
								if(cntrSearchImpl(c, context))
								return true; //end recursive call
							}
						}
						else
						{
							auto chars = act.map!(c => (cast(Glyph)c).ch); 
							
							size_t searchBaseIdx = 0; 
							while(1)
							{
								auto idx = chars.indexOf(context.searchText, (cast(CaseSensitive)(context.options.caseSensitive))); 
								if(idx<0) break; 
								
								alias BT = SearchOptions.BoundaryType; 
								bool checkBoundary(BT type, sizediff_t inside, sizediff_t outside )
								{
									dchar ch(alias i)() => ((i>=0 && i<chars.length)?(chars[i]):('\0')); 
									final switch(type)
									{
										case BT.none: 	return true; 
										case BT.word: 	return 	!isDLangIdentifierCont(ch!inside) || !isDLangIdentifierCont(ch!outside)
											/+
											Note: Only word-word is not OK.
											Any combination with symbols are OK.
										+/; 
										case BT.line: 	return ch!outside=='\0'; 
									}
								} 
								
								const 	idxLast = idx + context.searchText.length-1 /+last character index+/,
									valid = 	checkBoundary(context.options.boundaryTypeStart, idx, idx-1) && 
										checkBoundary(context.options.boundaryTypeEnd, idxLast, idxLast+1); 
								
								if(valid)
								{
									auto sr = SearchResult(
										thisC, context.absInnerPos, 
										cells[baseIdx+searchBaseIdx+idx..$][0..context.searchText.length]
									); 
									if(context.onMatch)
									{
										/+Note: callback mode: unlimited number of results. The caller can stop it by a Fiber.+/
										context.onMatch(sr); 
									}
									else
									{
										/+Note: classic mode: returns limited number of results.+/
										context.results ~= sr; 
										if(context.canStop) return true; 
									}
								}
								
								const skip = idx + context.searchText.length; 
								chars.popFrontExactly(skip); 
								searchBaseIdx += skip; 
							}
						}
						
						//readln;
						//print("advance", len);
						baseIdx += len; 
					}
					
					return false; 
				} 
				
				auto context = SearchContext(searchText.to!dstring, options, origin, onMatch, timeLimit); 
				
				static if(MeasureStack)
				{ { ulong tmp; asm { mov tmp, RSP; } context.baseSP = tmp; }}
				
				if(!searchText.empty)
				cntrSearchImpl(this, context); 
				return context.results; 
			} 
		}
		
		
		private enum genSetChanged = q{
			if(!flags.changed#) {
				flags.changed# = true; 
				if(auto p = getParent) if(p) p.setChanged#; 
			}
		}; 
		
		//changed tracking for file change detection //////////////////////////////////
		
		/// Sets flags.changed* if needed. Also sets it for the parents recursively.
		void setChangedCreated()
		{ mixin(genSetChanged.replace("#", "Created")); } 
		void setChangedRemoved()
		{ mixin(genSetChanged.replace("#", "Removed")); } //Ditto
		
		void setChanged()
		{
			setChangedCreated; 
			setChangedRemoved; 
		} 
		
		private enum genClearChanged = q{
			if(flags.changed#) {
				flags.changed# = false; 
				subContainers.each!"a.clearChanged#"; 
			}
		}; 
		
		/// Clears flags.changed* if needed. Also clears it for all the children recursively.
		void clearChangedCreated()
		{ mixin(genClearChanged.replace("#", "Created")); } 
		void clearChangedRemoved()
		{ mixin(genClearChanged.replace("#", "Removed")); } 
		
		@property int changedMask() const
		{ return (flags.changedCreated?1:0) | (flags.changedRemoved?2:0); } 
		
		@property bool changed() const
		{ return flags.changedCreated || flags.changedRemoved; } 
		
		void clearChanged()
		{
			clearChangedCreated; 
			clearChangedRemoved; 
		} 
		
		version(/+$DIDE_REGION SelectionManager  virtual functs+/all)
		{
			override bool getSelected()
			{ return flags.selected; } 
			override void setSelected(bool b)
			{ flags.selected = b; } 
			override bool getOldSelected()
			{ return flags.oldSelected; } 
			override void setOldSelected(bool b)
			{ flags.oldSelected = b; } 
			
			/+
				override bounds2 getBounds()
						{ return outerBounds; } 
			+/
		}
		
		void setRemoved()
		{
			if(flags.removed) return; 
			flags.removed = true; 
			foreach(sc; subCells) if(auto cntr = cast(Container)(sc)) cntr.setRemoved; 
		} 
	} 
	
	
	class Row : Container
	{
		/+private+/ int[] tabIdxInternal; //for Elastic tabs
		RowFlags rowFlags; 
		
		void refreshTabIdx()
		{ tabIdxInternal = subCells.enumerate.filter!((a)=>(isTab(a.value))).map!(a => (cast(int)(a.index))).array; } 
		
		void clearTabIdx()
		{ tabIdxInternal = []; } 
		
		override void clearSubCells()
		{
			super.clearSubCells; 
			clearTabIdx; 
			/+hasFlex = false; +/
		} 
		
		/// Must be called manually when needed for debugging
		bool verifyTabIdx()
		{
			auto prev = tabIdxInternal.dup; 
			refreshTabIdx; 
			return equal(tabIdxInternal, prev); 
		} 
		
		
		this()
		{} 
		
		this(string markup, TextStyle ts = tsNormal)
		{
			bkColor = ts.bkColor; 
			appendMarkupLine(this, markup, ts); 
		} 
		
		this(T:Cell)(T[] cells,in TextStyle ts)
		{
			bkColor = ts.bkColor; 
			appendMulti(cast(Cell[])cells); 
		} 
		
		
		override void appendCell(Cell c)
		{
			if(isTab(c))
			tabIdxInternal ~= cast(int)subCells.length; 
			/+if(c.flex) hasFlex = true; +/
			super.appendCell(c); 
		} 
		
		/*
			override void appendChar(dchar ch, in TextStyle ts){
					if(ch==9) tabIdxInternal ~= cast(int)subCells.length; //Elastic Tabs
					super.appendChar(ch, ts);
				}
		*/
		
		private void solveFlexAndMeasureAll()
		{
			float flexSum = 0; 
			bool doFlex; 
			if(!flags.autoWidth)
			{
				flexSum = subCells.calcFlexSum; 
				doFlex = flexSum>0; 
			}
			
			if(doFlex)
			{
				//calc remaining space from nonflex cells
				float remaining = innerWidth; 
				foreach(sc; subCells)
				if(!sc.flex)
				{
					if(auto co = cast(Container)sc)
					co.measure; //measure nonflex
					remaining -= sc.outerWidth; 
				}
				
				
				//distrubute among flex cells
				if(remaining>AlignEpsilon)
				{
					remaining /= flexSum; 
					foreach(sc; subCells)
					if(sc.flex)
					{
						sc.outerWidth = sc.flex*remaining; 
						if(auto co = cast(Container)sc)
						{ co.flags.autoWidth = false; co.measure; }//measure flex
					}
					
				}
			}
			else
			{
				 //no flex
				measureSubCells; 
			}
		} 
		
		private auto makeWrappedLines(bool doWrap)
		{
			//align/spread horizontally
			size_t iStart = 0; 
			auto cursor = vec2(0); 
			float maxLineHeight = 0; 
			WrappedLine[] wrappedLines; 
			
			void lineEnd(size_t iEnd)
			{
				wrappedLines ~= WrappedLine(subCells[iStart..iEnd], cursor.y, maxLineHeight); 
				
				cursor = vec2(0, cursor.y+maxLineHeight); 
				maxLineHeight = 0; 
				iStart = iEnd; 
			} 
			
			const limit = innerWidth + AlignEpsilon; 
			for(size_t i=0; i<subCells.length; i++)
			{
				
				auto act()
				{ return subCells[i]; } auto actWidth()
				{ return act.outerWidth; } 
				bool actIsNewLine()
				{ if(auto g = cast(Glyph)act) return g.isNewLine; return false; } 
				
				//wrap
				if(actIsNewLine)
				{ lineEnd(i); }
				else if(doWrap && cursor.x>0 && cursor.x+actWidth > limit)
				{
					
					if(1)
					{
						 //WordWrap: go back to a space
						bool failed; 
						auto j = i; while(j>iStart && !isWhite(subCells[j]))
						{
							j--; 
							if(j==iStart || subCells[j].outerPos.y != cursor.y)
							{ failed = true; break; }
						}
						if(!failed)
						{ i = j; }
					}
					
					lineEnd(i); 
				}
				
				act.outerPos = cursor; /+
					because of this, newline and wrapped space 
					goes to the next line. 
					This allocates a new wrapped_row for them.
				+/
				cursor.x += actWidth; 
				maxLineHeight.maximize(act.outerHeight); 
			}
			if(subCells.length)
			lineEnd(subCells.length); 
			
			return wrappedLines; 
		} 
		
		/// this works on the Row as if it were a one-liner. This is not the WrappedLines version.
		private void adjustTabSizes_singleLine()
		{
			foreach(idx, tIdx; tabIdxInternal)
			{
				const isLeading = idx==tIdx; //it's not good for multiline!!!
				adjustTabSize(subCells[tIdx], isLeading); 
			}
		} 
		
		//this handles multiple lines. Must count	newline chars too, so the tabIdx[] array is useless here.
		private void adjustTabSizes_multiLine()
		{
			//Todo: refactor this
			int tabCnt, colCnt; 
			foreach(c; subCells)
			{
				if(auto g = cast(Glyph)c)
				{
					if(g.isNewLine || g.isReturn)
					{ tabCnt = colCnt = 0; continue; }
					else if(g.isTab) {
						const isLeading = tabCnt == colCnt; 
						adjustTabSize(c, isLeading); 
						tabCnt++; 
					}
				}
				colCnt++; 
			}
		} 
		
		override void rearrange()
		{
			//adjust length of leading and internal tabs
			if(rowFlags.rowElasticTabs)
			adjustTabSizes_multiLine; 
			else adjustTabSizes_singleLine; 
			
			solveFlexAndMeasureAll();  //Opt: a containerFlag to disable the slow flexSum calculation
			
			const doWrap = rowFlags.wordWrap && !flags.autoWidth; 
			
			auto wrappedLines = makeWrappedLines(doWrap); 
			//LOG("wl", wrappedLines, autoWidth, wrappedLines.calcWidth);
			
			if(rowFlags.rowElasticTabs)
			processElasticTabs(wrappedLines, ((flags.autoWidth)?(float.nan):(innerWidth))); 
			
			//hide spaces on the sides by wetting width to 0. This needs for size calculation.
			//Todo: don't do this for the line being edited!!!
			if(doWrap && !rowFlags.dontHideSpaces)
			wrappedLines.hideSpaces(rowFlags.hAlign); 
			
			//horizontal alignment, sizing
			if(flags.autoWidth)
			innerWidth = wrappedLines.calcWidth; //set actual size if automatic
			
			//horizontal text align on every line
			if(!flags.autoWidth || wrappedLines.length>1)
			wrappedLines.applyHAlign(rowFlags.hAlign, innerWidth); 
			//Note: >1 because autoWidth and 1 line is already aligned
			
			//vertical alignment, sizing
			if(flags.autoHeight)
			{
				innerHeight = wrappedLines.calcHeight; 
				//height is calculated, no remaining space, so no align is needed
			}
			else
			{
				//height is fixed
				auto remaining = innerHeight - wrappedLines.calcHeight; 
				if(remaining > AlignEpsilon)
				wrappedLines.applyVAlign(rowFlags.vAlign, innerHeight); 
			}
			
			wrappedLines.applyYAlign(rowFlags.yAlign); 
			
			//remember the contents of the edited row
			rememberEditedWrappedLines(this, wrappedLines); 
			
			rowFlags.strictCellOrder = wrappedLines.length<=1; 
		} 
		
		override void draw(Drawing dr)
		{
			super.draw(dr); //draw frame, bkgnd and subCells
			
			//draw the carets and selection of the editor
			drawTextEditorOverlay(dr, this); 
		} 
		
		override void onDraw(Drawing dr)
		{
			if(rowFlags.btnRowLines && subCells.length>1)
			{
				dr.color = clWinText; dr.lineWidth = 1; dr.alpha = 0.25f; 
				foreach(sc; subCells[1..$])
				dr.vLine(
					sc.outerX, 	sc.outerY + sc.margin.top	+.25f, 
						sc.outerY + sc.outerHeight - sc.margin.bottom 	-.25f
				); 
				dr.alpha = 1; 
			}
		} 
		
		
		override Cell[] internal_hitTest_filteredSubCells(vec2 p)
		{
			if(rowFlags.strictCellOrder)
			{
				return sortedSubCellsAroundX(subCells, p); 
				/+Todo: make this work for multiline too+/
			}
			else
			{ return super.internal_hitTest_filteredSubCells(p); }
		} 
		
		//fast content size calculations (after measure)
		//Todo: these content calculations should be universal along all Containers.
		float contentInnerWidth () const
		{ return subCells.length ? subCells.back.outerRight : DefaultFontEmptyEditorSize.x; } 
		float contentInnerHeight() const
		{ return subCells.map!"a.outerHeight".maxElement(DefaultFontHeight); } 
		vec2 contentInnerSize() const
		{ return vec2(contentInnerWidth, contentInnerHeight); } 
		
		Cell subCellAtX(float x, Flag!"snapToNearest" snapToNearest = No.snapToNearest)
		{
			assert(!rowFlags.wordWrap); //Todo: no multiline either
			
			if(subCells.empty)
			return null; 
			
			if(x<subCells.front.outerLeft)
			return snapToNearest ? subCells.front : null; 
			
			foreach(sc; subCells)
			if(x<sc.outerRight)
			return sc; 
			
			return snapToNearest ? subCells.back : null; 
		} 
		
		void stretchSubGlyph(sizediff_t idx/+index of glyph, -1 means [$-1]+/)
		{
			if(idx<0) idx += subCells.length; 
			if(auto g = (cast(Glyph)(subCells.get(idx))))
			{ .stretchGlyph(subCells[idx], 0, innerHeight); }
		} 
		
		void stretchSubGlyphs(sizediff_t[] idx... /+indices of glyphs+/)
		{ idx.each!((i)=>(stretchSubGlyph(i))); } 
	} 
	class Column : Container
	{
		override void rearrange()
		{
			//measure the subCells and stretch them to a maximum width
			if(colFlags.dontStretchSubCells)
			{
				measureSubCells; 
				innerWidth = calcContentWidth; 
			}
			else if(flags.autoWidth) {
				//measure maxWidth
				measureSubCells; 
				innerWidth = calcContentWidth; 
				//at this point all the subCells are measured
				//now set the width of every subcell in this column if it differs, and remeasure only when necessary
				
				setSubContainerWidths_differentOnly(innerWidth); 
				/+
					Note: this is not perfectly optimal when autoWidth and fixedWidth Rows are mixed. 
						But that's not an usual case: ListBox: all textCells are fixedWidth, 
						Document: all paragraphs are autoWidth.
				+/
			}
			else {
				//first set the width of every subcell in this column, and measure all (for the first time).
				setSubContainerWidths(innerWidth); 
			}
			
			if(colFlags.columnElasticTabs)
			processElasticTabs(subCells, ((flags.autoWidth)?(float.nan):(innerWidth))); //Todo: ez a flex=1 -el egyutt bugzik.
			
			//process vertically flexible items
			if(!flags.autoHeight)
			{
				auto flexSum = subCells.calcFlexSum; 
				
				if(flexSum > 0)
				{
					//calc remaining space from nonflex cells
					float remaining = innerHeight - subCells.filter!"!a.flex".map!"a.outerHeight".sum; 
					
					//distrubute among flex cells
					if(remaining > AlignEpsilon)
					{
						remaining /= flexSum; 
						foreach(sc; subCells)
						if(sc.flex)
						{
							sc.outerHeight = sc.flex*remaining; 
							if(auto co = cast(Container)sc)
							{ co.flags.autoHeight = false; co.measure; }
							//height changed, measure again
						}
						
					}
				}
			}
			
			subCells.spreadV;   //Todo: MultiPageSupport should be here!!!!
			
			if(flags.autoHeight)
			innerHeight = calcContentHeight; 
		} 
		
		override void visitSubCells_cull(bounds2 clipBounds, void delegate(Cell) fun)
		{
			alias b = clipBounds; 
			
			void drawPage(Cell[] subCells)
			{
				const ub = subCells.map!(c => c.outerBottom).assumeSorted.upperBound(b.top).length; 
				if(ub>0)
				{
					auto scUpper = subCells[$-ub..$]; 
					const lb = scUpper.map!(c => c.outerTop).assumeSorted.lowerBound(b.bottom).length; 
					if(lb>0)
					{
						foreach(c; scUpper[0..lb])
						if(
							b.overlaps(c.outerBounds)
							/+Opt: There is overlaps() check and binary search too. I think only one is enough.+/
						)
						fun(c); 
					}
				}
			} 
			
			void drawPages(Cell[][] pages)
			{
				if(colFlags.dontStretchSubCells)
				WARN("flags.dontStretchSubCells should be disabled for multiPage Column."); 
				
				const ub = pages.map!(c => c.front.outerRight).assumeSorted.upperBound(b.left).length; 
				//Note: SubRows must be stretched.
				if(ub>0)
				{
					auto pgUpper = pages[$-ub..$]; 
					const lb = pgUpper.map!(c => c.front.outerLeft).assumeSorted.lowerBound(b.right).length; 
					if(lb>0)
					{
						foreach(p; pgUpper[0..lb])
						if(
							b.overlaps(bounds2(p.front.outerTopLeft, p.back.outerBottomRight))
							/+Opt: There is overlap check and binary search too. I think only one is enough.+/
						)
						drawPage(p); 
					}
				}
			} 
			
			auto pages = getPageRowRanges; 
			if(pages.length>1)
			drawPages(cast(Cell[][]) pages); 
			else drawPage(subCells); 
		} 
		
		
		override Cell[] internal_hitTest_filteredSubCells(vec2 p)
		{
			auto pages = getPageRowRanges; 
			if(pages.length>1)
			{
				auto xStarts = pages.map!(p => p.front.outerPos.x).assumeSorted; 
				size_t idx = (xStarts.length - xStarts.upperBound(p.x).length - 1); 
				return idx<pages.length 	? sortedSubCellsAroundY(cast(Cell[]) pages[idx], p)
					: null; 
			}
			else return sortedSubCellsAroundY(subCells, p); 
		} 
		
		version(/+$DIDE_REGION Multiple page support+/all)
		{
			Row[][] getPageRowRanges()
			{
				/+
					To implement a multiPage Column,
						* override this method.
						* make a cached storage for Row[][] and return it.
						* at the end of rearrange(), call rearrangePages_ to refresh the Row[][] cache.
						
					drawSubCells_cull(), internal_hitTest_filteredSubCells() will use this overridden method.
				+/
				return null; 
			} 
			
			Row[][] rearrangePages_byLastRows(alias isLastRow)(float pageGapWidth)
			{
				if(colFlags.dontStretchSubCells)
				WARN("flags.dontStretchSubCells should be disabled for multiPage Column."); 
				
				auto rows = cast(Row[]) subCells; 
				if(rows.empty)
				return null; 
				
				int[] breakRowIndices; 
				foreach(i, r; rows)
				if(unaryFun!isLastRow(r))
				breakRowIndices ~= cast(int) i; 
				
				if(breakRowIndices.length)
				{
					Row[][] result; 
					result.reserve(breakRowIndices.length+1); 
					
					float x0 = 0, maxY = 0; 
					void processPage(size_t st, size_t en)
					{
						assert(
							en>st, "Empty pages are not allowed. "~
							"Because the pages are delimited by marker rows, minimum pageSize is 1 row."
						); 
						
						auto pageRows = rows[st..en]; 
						const emptyWidth = pageRows.map!(r => r.innerWidth - r.contentInnerWidth).minElement; 
						
						const y0 = pageRows.front.outerY; 
						foreach(r; pageRows)
						{
							r.outerPos.x = x0; 
							r.outerSize.x -= emptyWidth; 
							r.outerPos.y -= y0; 
						}
						
						with(pageRows.back)
						{
							x0 = outerRight + pageGapWidth; 
							maxY.maximize(outerBottom); 
						}
						
						result ~= pageRows; 
					} 
					
					version(/+$DIDE_REGION Go through all pages+/all)
					{
						const rowCount = rows.length; 
						size_t lastIdx = 0; 
						foreach(i; breakRowIndices)
						{
							processPage(lastIdx, i+1); 
							lastIdx = i+1; 
						}
						if(lastIdx < rowCount)
						processPage(lastIdx, rowCount); 
					}
					
					innerSize = vec2(rows.back.outerRight, maxY); 
					
					return result; 
				}
				else return null; 
			} 
		}
	} 
	
}
version(/+$DIDE_REGION+/all)
{
	//Todo: Ezt le kell valtani egy container.backgroundImage-al.
	class Document : Column
	{
		 //Document /////////////////////////////////
		this()
		{ bkColor = tsNormal.bkColor; } 
		
		string title; 
		string[] chapters; 
		int[3] actChapterIdx; 
		
		int lastChapterLevel; 
		float cy=0; 
		
		void addChapter(ref string s, int level)
		{
			enforce(level.inRange(0, actChapterIdx.length-1), "chapter level out of range "~level.text); 
			actChapterIdx[level]++; 
			actChapterIdx[level+1..$] = 0; 
			
			s = actChapterIdx[0..level+1].map!(a => (a).text~'.').join ~ " " ~ s; 
		} 
		
		ref auto getChapterTextStyle()
		{
			switch(lastChapterLevel)
			{
				case 0: return tsTitle; 
				case 1: return tsChapter; 
				case 2: return tsChapter2; 
				case 3: return tsChapter3; 
				default: return tsBold; 
			}
		} 
		
		override void parse(string s, TextStyle ts = tsNormal)
		{
			if(s=="")
			return; 
			
			int actChapterLevel = 0; 
			
			if(s.startsWithTag("title"	))
			{ ts = tsTitle	; actChapterLevel = 1; title = s; }
			else if(s.startsWithTag("chapter"	)) { ts = tsChapter	; actChapterLevel = 2; addChapter(s, 0); }
			else if(s.startsWithTag("chapter2")) { ts = tsChapter2; actChapterLevel = 3; addChapter(s, 1); }
			else if(s.startsWithTag("chapter3")) { ts = tsChapter3; actChapterLevel = 4; addChapter(s, 2); }
			
			//extra space, todo:margins
			if(chkSet(lastChapterLevel, actChapterLevel))
			appendCell(new Row(tag("prop height=1x"), tsNormal)); 
			
			super.parse(s, ts); 
		} 
		
	} 
	
	class GrpContainer : Container /+more info-> im.Grp()+/
	{
		override void rearrange()
		{
			super.rearrange; 
			
			auto 	content 	= (cast(.Container)(subCells.get(0))), //<- automatically resized when resizing this
				title 	= (cast(.Container)(subCells.get(1))); 
			if(content && title)
			{
				bool eq(float a, float b) => (magnitude(a - b))<=AlignEpsilon; 
				bool set(ref float dst, float src)
				{
					if(!eq(src, dst))	{ dst = src; return true; }
					else	return false; 
				} 
				
				if(!flags.autoWidth)
				{
					content.flags.autoWidth = false; 
					if(set(content.outerWidth, innerWidth))
					{
						content.measure; //width forced, height can possibly changed
						if(content.flags.autoHeight && !eq(content.outerHeight, innerHeight))
						innerHeight = content.outerHeight; 
					}
				}
				
				if(!flags.autoHeight)
				{
					content.flags.autoHeight = false; 
					if(set(content.outerHeight, innerHeight))
					{
						content.measure; //height forced, width can change
						if(content.flags.autoWidth && !eq(content.outerWidth, innerWidth))
						innerWidth = max(content.outerWidth, title.outerRight); 
					}
				}
			}
		} 
	} 
	
	enum DockAlignment
	{
		none, 
		topLeft, 	topCenter, 	topRight, 	
		leftCenter, 	center, 	rightCenter, 	
		bottomLeft, 	bottomCenter, 	bottomRight, 	
			topClient, 		
		leftClient, 	client, 	rightClient, 	
			bottomClient		
	} 
	
	class DockSite : Container
	{
		/+This is not full automatic. The imGui builder must call the before and after dock administrative methods manually.+/
		
		bounds2 clientArea; //must be initialized before receiving contained cells.
		
		im.SplittedAreaState splittedAreaState; 
		
		void beforeDock(.Container cntr, in DockAlignment da)
		{
			with(DockAlignment)
			{
				//flags.targetSurface is unknown at this point, will check it later in 'finalize'
				if(da)
				{
					if(da.among(client, topClient, bottomClient))	cntr.outerWidth = clientArea.width; 
					if(da.among(client, leftClient, rightClient))	cntr.outerHeight = clientArea.height; 
				}
			}
		} 
		
		private void afterDock(.Container cntr, in DockAlignment da)
		{
			with(DockAlignment)
			{
				if(da)
				{
					enforce(cntr.flags.targetSurface == TargetSurface.gui, "Unable to set DockAlignment on world_surface."); 
					
					cntr.measure; //must know all the sizes from now on
					
					const 	isAlignPosition 	= da.inRange(topLeft, bottomRight)	/+it will only position the container+/,
						isClientPosition 	= da.inRange(topClient, bottomClient)/+it will change the client rect too+/; 
					
					if(isAlignPosition)
					{
						ivec2 p; divMod((cast(int)(da-1)), 3, p.y, p.x); 
						if(p.x.inRange(0, 2) && p.y.inRange(0, 2))
						{
							auto 	t = p*.5f,
								u = vec2(1)-t; 
							
							cntr.outerPos = clientArea.topLeft*u 	+ clientArea.bottomRight*t //Todo: bug: fucking vec2.lerp is broken again
								- cntr.outerSize*t; 
						}
					}
					else if(isClientPosition)
					{
						//Todo: put checking for running out of area and scrolling here.
						switch(da)
						{
							case topClient: 	cntr.outerPos     = clientArea.topLeft; 	clientArea.top += cntr.outerHeight; 	break; 
							case bottomClient: 	clientArea.bottom -= cntr.outerHeight; 	cntr.outerPos = clientArea.bottomLeft; 	break; 
							case leftClient: 	cntr.outerPos     = clientArea.topLeft; 	clientArea.left += cntr.outerWidth; 	break; 
							case rightClient: 	clientArea.right   -= cntr.outerWidth; 	cntr.outerPos = clientArea.topRight; 	break; 
							case client: 	cntr.outerPos     = clientArea.topLeft; 	cntr.outerSize = clientArea.size,
							clientArea = bounds2(
								clientArea.center, 
								clientArea.center
							); 	break; 
							default: 	ERR("invalid DockAlignment"); 
						}
					}
				}
			}
		} 
	} 
	
	class SelectionManager(T : Cell)
	{
		//Todo: Combine and refactor this with the one inside DIDE
		
		//T must have some bool properties:
		static assert(
			__traits(
				compiles, {
					T a; 
					a.isSelected = true; 
					a.oldSelected = true; 
				}
			), "Field requirements not met."
		); 
		
		bounds2 getBounds(T item)
		{ return item.outerBounds; } 
		
		T hoveredItem; 
		
		enum MouseOp
		{ idle, move, rectSelect} MouseOp mouseOp; 
		
		vec2 mouseLast; 
		
		enum SelectOp
		{ none, add, sub, toggle, clearAdd} SelectOp selectOp; 
		
		vec2 dragSource; 
		bounds2 dragBounds; 
		
		bounds2 selectionBounds()
		{
			if(mouseOp == MouseOp.rectSelect)
			return dragBounds; 
			else return bounds2.init; 
		} 
		
		//notification functions: the manager must know when an item is deleted
		void notifyRemove(T cell)
		{
			if(hoveredItem && hoveredItem is cell)
			hoveredItem = null; 
		} 
		void notifyRemove(T[] cells)
		{
			if(hoveredItem)
			cells.each!(c => notifyRemove(c)); 
		} 
		void notifyRemoveAll()
		{ hoveredItem = null; } 
		
		T[] delegate() onBringToFront; //Use bringSelectedItemsToFront() for default behavior
		bool deselectBelow; 
		
		void update(bool mouseEnabled, View2D view, T[] items)
		{
			
			void selectNone()
			{
				foreach(a; items)
				a.isSelected = false; 
			} 	void selectOnly(T item)
			{
				selectNone; if(item)
				item.isSelected = true; 
			} 
			void selectHoveredOnly()
			{ selectOnly(hoveredItem); } 	void saveOldSelected()
			{
				foreach(a; items)
				a.oldSelected = a.isSelected; 
			} 
			
			//acquire mouse positions
			auto mouseAct = view.mousePos.vec2; 
			auto mouseDelta = mouseAct-mouseLast; 
			scope(exit) mouseLast = mouseAct; 
			
			const 	LMB	= inputs.LMB.down,
				LMB_pressed	= inputs.LMB.pressed,
				LMB_released 	= inputs.LMB.released,
				Shift	= inputs.Shift.down,
				Ctrl	= inputs.Ctrl.down; 	const 	modNone	= !Shift 	&& !Ctrl,
				modShift	= Shift	&& !Ctrl,
				modCtrl	= !Shift	&& Ctrl,
				modShiftCtrl 	= Shift	&& Ctrl; 
			
			const inputChanged = mouseDelta || inputs.LMB.changed || inputs.Shift.changed || inputs.Ctrl.changed; 
			
			//update current selection mode
			if(modNone)
			selectOp = SelectOp.clearAdd; 	if(modShift)
			selectOp = SelectOp.add; 
			if(modCtrl)
			selectOp = SelectOp.sub; 	if(modShiftCtrl)
			selectOp = SelectOp.toggle; 
			
			//update dragBounds
			if(LMB_pressed)
			dragSource = mouseAct; 
			if(LMB)
			dragBounds = bounds2(dragSource, mouseAct).sorted; 
			
			//update hovered item
			hoveredItem = null; 
			foreach(item; items)
			if(getBounds(item).contains!"[)"(mouseAct))
			hoveredItem = item; 
			
			if(LMB_pressed && mouseEnabled)
			{
				//Left Mouse pressed //
				if(hoveredItem)
				{
					if(modNone)
					{
						if(!hoveredItem.isSelected) selectHoveredOnly; 
						mouseOp = MouseOp.move; 
						if(deselectBelow) .deselectBelow(items, hoveredItem); 
						if(onBringToFront) items = onBringToFront(); 
					}
					if(modShift || modCtrl || modShiftCtrl)
					hoveredItem.isSelected.toggle; 
				}
				else
				{
					mouseOp = MouseOp.rectSelect; 
					saveOldSelected; 
				}
			}
			
			{
				//update ongoing things //
				if(mouseOp == MouseOp.rectSelect && inputChanged)
				{
					foreach(a; items)
					if(dragBounds.contains!"[]"(getBounds(a)))
					{
						final switch(selectOp)
						{
							case 	SelectOp.add,
								SelectOp.clearAdd: 	a.isSelected = true; 	break; 
							case SelectOp.sub: 	a.isSelected = false; 	break; 
							case SelectOp.toggle: 	a.isSelected = !a.oldSelected; 	break; 
							case SelectOp.none: 		break; 
						}
					}
					else
					{ a.isSelected = (selectOp == SelectOp.clearAdd) ? false : a.oldSelected; }
					
				}
			}
			
			if(mouseOp == MouseOp.move && mouseDelta)
			{
				foreach(a; items)
				if(a.isSelected)
				{
					a.outerPos += mouseDelta; 
					static if(__traits(compiles, { a.cachedDrawing.free; }))
					a.cachedDrawing.free; 
				}
				
			}
			
			
			if(LMB_released)
			{
				 //left mouse released //
				
				//...
				
				mouseOp = MouseOp.idle; 
			}
		} 
	} 
	
	T[] bringSelectedItemsToFront(T)(T[] items, bool selectAbove)
	{
		static assert(__traits(compiles, { items[0].isSelected.toggle; }), "Missing bool property: Item.isSelected"); 
		static assert(__traits(compiles, { items[0].zIndex = 0; }), "Missing int property: Item.zIndex"); 
		
		auto selectedItems() { return items.filter!"a.isSelected"; } 
		auto unselectedItems() { return items.filter!"!a.isSelected"; } 
		
		if(selectAbove)
		{
			foreach(i, p; items) p.zIndex = cast(int) i; 
			void selectMoreOnTopOf(T base)
			{
				foreach(p; unselectedItems.filter!(p=>p.zIndex>base.zIndex && base.outerBounds.overlaps(p.outerBounds)))
				{ p.isSelected = true; selectMoreOnTopOf(p); }
			} 
			foreach(p; selectedItems) selectMoreOnTopOf(p); 
		}
		
		return chain(unselectedItems, selectedItems).array; 
	} 
	
	void deselectBelow(T)(T[] items, T actItem)
	{
		foreach(i, p; items) p.zIndex = cast(int) i; 
		
		void doit(T actItem)
		{
			foreach(item; items)
			if(item.isSelected && (item.zIndex < actItem.zIndex) && item.outerBounds.overlaps(actItem.outerBounds))
			{
				item.isSelected = false; 
				doit(item); 
			}
		} 
		
		doit(actItem); 
	} 
	static class VirtualTreeView(Item) if(is(Item==struct))
	{
		/+
			Todo: implement keyboard handling: 
			/+Link: https://wiki.openjdk.org/spaces/OpenJFX/pages/15368267/TreeView+User+Experience+Documentation+/
		+/
		
		Item _root; 
		@property root(Item a) { if(_root.chkSet(a)) refresh; } 
		@property ref root() => _root; 
		
		void refresh()
		{ changed = now; } 
		
		static struct TreeRow
		{
			Item* item; 
			string prefix; 
		} 
		TreeRow[] rows; 
		float maxRowWidth = 0; 
		DateTime rowsUpdated, changed; 
		bool showBullet = true; /+if there is no open/close icon, a bullet mark looks nice in front of the item name+/
		bool showRoot = true; 
		
		Item* getParentItem(Item* child)
		{
			/+Opt: this is not so fast.  Items should know their parents...+/
			//Todo: refactor this crap in functional style
			foreach(i, ref a; rows)
			if(a.item is child)
			{
				if(i>0) {
					const desiredPrefixLen = (cast(sizediff_t)(rows[i].prefix.length))-1; 
					if(desiredPrefixLen>=0)
					{
						foreach_reverse(ref b; rows[0..i])
						if(b.prefix.length==desiredPrefixLen)
						return b.item; 
					}
				}
			}
			return null; 
		} 
		
		auto getAllParentItems(Item* child)
		{
			Item*[] res; 
			while(child)
			{
				child = getParentItem(child); 
				if(child) res ~= child; 
			}
			return res.retro.array; 
		} 
		
		void makeRows()
		{
			void doit(ref Item act, string prefix, bool isLast, bool doPrefix=true)
			{
				rows ~= TreeRow(&act, prefix ~ ((doPrefix)?(((isLast)?("L"):("+"))):(""))); 
				if(act.opened /+recustion+/)
				{
					const newPrefix = (prefix ~ ((doPrefix)?(((isLast)?(" "):("I"))):(""))).text; 
					foreach(i, ref a; act.subNodes) doit(a, newPrefix, (i+1==act.subNodes.length)); 
				}
			} 
			{
				rows = []; maxRowWidth = 0; 
				if(showRoot)	{ doit(_root, "", true, false); }
				else	{ root.open; foreach(ref a; root.subNodes) doit(a, "", false, false); }
				rowsUpdated = now; 
			}
		} 
		
		this()
		{} 
		
		void UI(
			void delegate() onSetup/+must set outerSize in onSetup! Optionally can set fontHeight+/,
			void delegate(Item*) onItem=null
		)
		{
			with(im)
			{
				Container(
					((this).名!q{id}), Theme.tool,
					{
						with(flags)
						vScrollState 	= ScrollState.auto_,
						hScrollState 	= ScrollState.auto_,
						clipSubCells 	= true; 
						if(rowsUpdated<changed) makeRows; 
						if(onSetup) onSetup(); 
						
						//total size placeholder
						const float 	fh 	= style.fontHeight/+For faster access. Many things depend on 'fh'.+/, 
							rowHeight 	= fh, 
							invRowHeight 	= 1/rowHeight; 
						imAppend(new Cell(vec2(maxRowWidth, rows.length*rowHeight), vec2(0))); 
						/+Container({ outerPos = vec2(maxRowWidth, rows.length*rowHeight); outerSize = vec2(0); }); +/
						
						flags._saveVisibleBounds = true; 
						if(const visibleBounds = imstVisibleBounds(thisId))
						{
							void doit(int i, TreeRow r)
							{
								with(im)
								{
									Row(
										((identityStr(r.item)).genericArg!q{id}),
										{
											rowFlags.wordWrap = false; outerPos = vec2(0, i*rowHeight); outerHeight = fh; 
											
											version(/+$DIDE_REGION Tree graphics+/all)
											{
												Row(
													{
														outerSize = vec2(r.prefix.length, 1)*fh; 
														const float siz = fh; 
														void customDraw(Drawing dr, .Container cntr)
														{
															dr.color = clGray; dr.lineWidth = 1.0625f; 
															float x = siz*.5f; 
															foreach(ch; r.prefix.byChar)
															{
																if(ch.among('+', 'I')) dr.vLine(x, 0, siz); 
																if(ch.among('+', 'L')) {
																	dr.circle(vec2(x+.5*siz, 0), siz*.5f, -π/2, 0); 
																	if(showBullet) dr.hLine(x+.5f*siz, siz*.5f, x+.75f*siz); 
																}
																x += fh; 
															}
														} 
														addDrawCallback(&customDraw); 
													}
												); 
											}
											
											version(/+$DIDE_REGION Tree Open/Close Button+/all)
											{
												if(r.item.canOpen)
												{
													if(
														Btn(
															Margin.init, VAlign.center,
															{
																outerSize = vec2(fh); fh = 14; 
																Text(symbolStr((r.item.opened)?("ChevronDown") :("ChevronRight"))); 
															}
														).pressed
													) {
														r.item.toggle; 
														this.changed = now; 
													}
												}
												else
												{ if(showBullet) { Spacer(fh*0.275f); Text("●"); Spacer(fh*0.275f); }}
											}
											
											Spacer(fh*.25f); 
											
											if(onItem)	onItem(r.item); 
											else	{
												static if(__traits(compiles, { r.item.UI(); }))	r.item.UI(); 
												else	Text(r.item.text); 
											}
										}
									); 
								}
							} 
							foreach(
								i; 	(ifloor(visibleBounds.top    * invRowHeight    )).max(0) ..
									(iceil(visibleBounds.bottom * invRowHeight + 1)).min(rows.length.to!int)
							)
							{
								doit(i, rows[i]); /+must put inside a function, so the customDraw can capture its stack.+/
								/+Todo: Do it with a better way that dr.addDrawCallback()+/
							}
						}
						
						//Arrange the visible rows
						auto rowCtrls() => thisContainer.subCells.drop(1).map!((a)=>((cast(het.ui.Row)(a)))); 
						maxRowWidth = 0; 
						foreach(r; rowCtrls) { r.needMeasure; r.measure; maxRowWidth.maximize(r.outerWidth); }
						
						//foreach(r; rowCtrls) { r.outerWidth = maxRowWidth; }
					}
				); 
			}
		} 
	} 
	
	/+AI:+/
	
	
	
	/+
		260718: Size reduction
		Border: 20, Cell: 32, Glyph: 61, Container: 136, Row: 153, Column: 136
		
		After refactoring Border:
		Border: 8, Cell:32, Glyph:61, Container:128, Row:145, Column:128
		
		Further refactor: 16bit upper float:
		Border: 6, Cell:32, Glyph:61, Container:128, Row:145, Column:128
		
		Padding, Border uses UpperFloats:
		Border: 6, Cell:32, Glyph:61, Container:112, Row:129, Column:112
		
		FlexValue -> UpperFloat
		Border: 6, Cell:32, Glyph:61, Container:104, Row:121, Column:104 
		
		260805: Can't remember
		Border: 6, Cell:32, Glyph:61, Container:96, Row:113, Column:96, TextStyle: 32
		
		260809: TextStyle.font:  string -> FontId
		Border: 6, Cell:32, Glyph:61, Container:96, Row:113, Column:97, TextStyle: 9
		
		260810: realigning fields in Container
		Border: 6, Padding:8, Cell:32, Glyph:61, Container:91, Row:113, Column:91, Style: 9
		
		260821: split flags to -> flags, rowFlags, colFlags
		Border: 6, Padding:8, Cell:32, Glyph:61, Container:88, Row:106, Column:88, Style: 9
	+/
	
	pragma(msg,i"Border: $(Border.sizeof), Padding:$(Padding.sizeof), Cell:$(__traits(classInstanceSize, Cell)), Glyph:$(__traits(classInstanceSize, Glyph)), Container:$(__traits(classInstanceSize, Container)), Row:$(__traits(classInstanceSize, Row)), Column:$(__traits(classInstanceSize, Column)), Style: $(TextStyle.sizeof)".text.注); 
	
	alias SliderOrientation = Slider.Orientation, SliderType = Slider.Type; 
	class Slider : Container
	{
		//Note: must be a Container because hitTest works on Containers only.
		
		//Todo: shift precise mode: must use float knob position to improve the precision
		
		enum Orientation { horz, vert, round, auto_} 
		enum Type { slider, scrollBar} 
		
		Orientation orientation; 
		Type type; 
		RGB /+bkColor, <-already defined in Container+/clLine, clThumb, clRuler; 
		float baseSize; //this is calculated from current fontHeight and theme.
		float normThumbSize; //if it is a scrollbar, this is not nan and specifies the normalized size of the thumb.
		//these are the derived sizes
		float rulerOfs	()
		{ return baseSize*0.5f; } 
		float lwLine	()
		{ return baseSize*(2.0f*InvDefaultFontHeight); } 
		float lwRuler	()
		{ return lwLine*0.5f; } 
		
		static isRound(in Orientation orientation)
		=> orientation==Orientation.round; 
		static isLinear(in Orientation orientation)
		=> !!orientation.among(Orientation.horz, Orientation.vert); 
		static getActualSliderOrientation(Orientation orientation, in bounds2 r, in Type type)
		{
			//scrollbar can only be horz or vert.
			if(type==Type.scrollBar && !isLinear(orientation))
			orientation = Orientation.auto_; 
			
			if(orientation != Orientation.auto_)
			return orientation; 
			enum THRESHOLD = 1.5f; 
			float aspect = safeDiv(r.width/r.height, 1); 
			return aspect>=THRESHOLD	? Orientation.horz:
			aspect<=(1/THRESHOLD)	? Orientation.vert:
				Orientation.round; 
		} 
		
		/// this is the half thickness of the thumb in the active direction
		float calcLwThumb	(Orientation ori)
		{
			if(type == Type.scrollBar && !isnan(normThumbSize))
			{
				const minSizePixels = min(innerWidth, MinScrollThumbSize); 
				return max((ori==Orientation.horz ? innerWidth : innerHeight) * normThumbSize.clamp(0, 1), minSizePixels) * .5f; 
			}else
			{ return baseSize*(1.0f/3); }
		} 
		
		
		int rulerDiv0 = 9, rulerDiv1 = 4; 
		ubyte rulerSides=3; 
		
		float nPos, nCenter=0;  //center is the start of the marking on the line
		int wrapCnt; //for endless, to see if there was a wrapping or not. Used to reconstruct actual value
		
		bounds2 hitBounds; 
		
		void setupAppearance(bool enabled, bool focused, float hover_smooth, float captured_smooth, float baseSize)
		{
			const hoverOrFocus = enabled ? max(hover_smooth*.5f, focused ? 1.0f : 0) : 0; 
			
			final switch(type)
			{
				case Type.slider: 
					clThumb = mix(mix(clSliderThumb, clSliderThumbHover, hoverOrFocus), clSliderThumbPressed, captured_smooth); 
					clLine = mix(mix(clSliderLine , clSliderLineHover , hoverOrFocus), clSliderLinePressed , captured_smooth); 
					clRuler = clGray/+mix(bkColor, ts.fontColor, 0.5)+/; //disable ruler for now
				
					if(focused) { clThumb = clBlack; clLine = clBlack; }//Todo: lame logic
				
					rulerSides = 0; 
				break; 
				case Type.scrollBar: 
					clThumb = mix(clScrollThumb, clScrollThumbPressed, hoverOrFocus); 
					bkColor = mix(clScrollBk, clScrollThumb, min(hoverOrFocus, .5f)); 
				
					if(focused) { clThumb = clBlack; }//Todo: lame logic
				
					//clThumb = mix(clWinBtn, clWinBtnPressed, max(hit.hover_smooth*.5f, sliderState.pressed_id==id ? 1 : 0));
					rulerSides = 0; 
				break; 
			}
			
			if(!enabled) clLine = clThumb = clGray; //Todo: nem clGray ez, hanem clDisabledText vagy ilyesmi
			
			this.baseSize = baseSize; 
			if(!outerSize) outerSize = vec2(baseSize*6, baseSize); //default size
		} 
		
		
		override bounds2 getHitBounds()
		{ return outerBounds; } 
		
		private void drawThumb(Drawing dr, vec2 a, vec2 t, float lwThumb)
		{
			final switch(type)
			{
				case Type.slider: 
					dr.lineWidth = lwThumb; dr.color = clThumb; 
					const t90 = t.rotate90; 
					dr.line(a-t90, a+t90); 
				break; 
				case Type.scrollBar: 
					dr.color = clThumb; 
					const 	horz 	= orientation==Orientation.horz,
					halfSize 	= horz ? vec2(lwThumb, innerHeight*.5f) : vec2(innerWidth*.5f, lwThumb),
					bnd 	= bounds2(a, a).inflated(halfSize); 
					dr.fillRect(bnd); 
				break; 
			}
		} 
		
		private void drawLine(Drawing dr, vec2 a, vec2 b, RGB cl)
		{ dr.lineWidth = lwLine; dr.color = cl; dr.line(a, b); } 
		
		
		override void draw(Drawing dr)
		{
			const mod_update = !hitBounds.empty && !inputs.LMB.value; 
			
			dr.color = bkColor; dr.fillRect(borderBounds_inner); 
			drawBorder(dr); 
			
			dr.alpha = 1; dr.lineStyle = LineStyle.normal; dr.arrowStyle = ArrowStyle.none; 
			
			auto b = innerBounds; 
			const 	actOrientation = getActualSliderOrientation(orientation, b, type),
				lwThumb = calcLwThumb(actOrientation); 
			
			if(isLinear(actOrientation))
			{
				const 	horz 	= actOrientation == Orientation.horz,
					thumbOfs 	= (horz ? vec2(1,	0) : vec2(0, -1)) * lwThumb,
					p0 	= (horz ? b.leftCenter	: b.bottomCenter) + thumbOfs,
					p1 	= (horz ? b.rightCenter	: b.topCenter  ) - thumbOfs; 
				
				if(type==Type.slider && rulerSides)
				{
					const 	rp0 	= horz ? p0 : p1,
						rp1 	= horz ? p1 : p0,
						ro0 	= horz ? vec2(0, rulerOfs) : vec2(rulerOfs, 0),
						ro1 	= ro0*.4f; 
					if(rulerSides&1)
					drawStraightRuler(dr, bounds2(rp0-ro0, rp1-ro1), rulerDiv0, rulerDiv1, true ); 
					if(rulerSides&2)
					drawStraightRuler(dr, bounds2(rp0+ro1, rp1+ro0), rulerDiv0, rulerDiv1, false); 
				}
				
				if(type==Type.slider)
				drawLine(dr, p0, p1, clLine); 
				
				if(!isnan(nPos))
				{
					auto p = mix(p0, p1, nPos); 
					if(!isnan(nCenter) && type==Type.slider)
					drawLine(dr, mix(p0, p1, nCenter), p, clThumb); 
					
					drawThumb(dr, p, thumbOfs, lwThumb); 
					
					if(mod_update)
					{
						vec2 thumbHalfSize; 
						if(type==Type.slider)
						{
							thumbHalfSize = lwThumb * vec2(0.5f, 1.5f); 
							if(!horz)
							swap(thumbHalfSize.x, thumbHalfSize.y); 
						}else
						{ thumbHalfSize = horz ? vec2(lwThumb, outerHeight*.5f) : vec2(outerWidth*.5f, lwThumb); }
						const thumbRect = bounds2(p, p).inflated(thumbHalfSize); 
						im.sliderState.afterDraw(id, actOrientation, dr.inputTransform(p0), dr.inputTransform(p1), dr.inputTransform(thumbRect)); 
					}
				}
				
			}
			else if(isRound(actOrientation))
			{
				//center square
				bool endless = false; 
				
				b = b.fittingSquare; 
				if(mod_update)
				im.sliderState.afterDraw(id, actOrientation, dr.inputTransform(b.center), dr.inputTransform(b.center), dr.inputTransform(b)); 
				
				auto c = b.center, r = b.width*0.4f; 
				
				if(rulerSides)
				drawRoundRuler(dr, c, r, rulerDiv0, rulerDiv1, endless); 
				r *= 0.8f; 
				
				float a0 = (endless ? 0 : 0.25f)*PIf; 
				float a1 = (endless ? 2 : 1.75f)*PIf; 
				
				dr.lineWidth = lwLine; 
				dr.color = clLine; 
				dr.circle(c, r, a0, a1); 
				
				if(!isnan(nPos))
				{
					float n = 1-nPos; 
					n = endless ? n.fract : n.clamp(0, 1);  //Todo: ezt megcsinalni a range-val
					float a = mix(a0, a1, n); 
					if(!endless && !isnan(nCenter))
					{
						float ac = mix(a0, a1, (1-nCenter).clamp(0, 1)); 
						dr.color = clThumb; 
						if(ac>=a)
						dr.circle(c, r, a, ac); 
						else dr.circle(c, r, ac, a); 
					}
					
					dr.lineWidth = lwThumb; 
					dr.color = clThumb; 
					auto v = vec2(sin(a), cos(a)); 
					dr.line(c, c+v*r); 
				}
			}
			
			drawDebug(dr); 
		} 
		//Draw Rulers
		protected void drawStraightRuler(
			Drawing dr, in bounds2 r, int cnt, 
			int cnt2=-1, bool topleft=true
		)
		{
			cnt--; 
			if(cnt<=0) return; 
			if(cnt2<0) cnt2 = cnt; 
			dr.color = clRuler; dr.lineWidth = lwRuler; 
			if(r.height < r.width)
			{
				float 	c 	= r.center.y,
					b 	= r.top,
					t 	= r.bottom,
					j 	= r.left,
					ja 	= r.width/cnt; 
				if(!topleft) swap(b, t); 
				foreach(i; 0..cnt+1)
				{
					dr.vLine(j, b, cnt2 && i%cnt2==0 ? t : c); 
					j += ja; 
				}
			}else
			{
				float 	c 	= r.center.x,
					b 	= r.left,
					t 	= r.right,
					j 	= r.top,
					ja 	= r.height/cnt; 
				if(!topleft) swap(b, t); 
				foreach(i; 0..cnt+1)
				{
					dr.hLine(b, j, cnt2 && i%cnt2==0 ? t : c); 
					j += ja; 
				}
			}
		} 
		
		protected void drawRoundRuler(
			Drawing dr, in vec2 center, float radius, 
			int cnt, int cnt2=-1, bool endless=false
		)
		{
			cnt--; 
			if(cnt<=0) return; 
			if(cnt2<0) cnt2 = cnt; 
			//radius *= (1/1.25f);
			dr.color = clRuler; dr.lineWidth = lwRuler; 
			foreach(i; 0..cnt+1)
			{
				float a = endless 	? 2*PIf*i/cnt
					: -0.25f*PIf + 1.5f*PIf*i/cnt; 
				float co = -cos(a), si = -sin(a); 
				dr.moveTo(center.x+co*radius, center.y+si*radius); 
				float radius2 = radius*(
					!endless && (cnt2 && i%cnt2==0) 
					? 1.25f : 1.125f
				); 
				dr.lineTo(center.x+co*radius2, center.y+si*radius2); 
			}
		} 
	} 
	
	class DateTimeRuler : Container
	{
		//Note: must be a Container because hitTest works on Containers only.
		
		RGB clText, clRedText, clMajorTick, clMinorTick; 
		DateTime tMin, tMax, t0, t1, t0_draw, t1_draw; 
		bounds2 hitBounds; 
		
		bool mouseAtTopHalf; 
		@property mouseAtBottomHalf() => !mouseAtTopHalf; 
		
		bool focused; float hoverOrFocus=0; 
		
		DateTime highlighted_t; 
		bool show_highlighted_t; 
		
		void sanitizeRanges()
		{
			//both ranges must be always valid
			if(tMax<=tMin)
			{
				tMax = tMin; 
				if(tMin.raw==ulong.max) tMin.raw--; 
				tMax.raw = tMin.raw+1; 
			}
			t0 = t0.clamp(tMin, tMax); 
			t1 = t1.clamp(t0, tMax); 
			if(t0==t1)
			{ if(t0==tMax) t0.raw--; else t1.raw++; }
		} 
		
		static struct NormalizedSliderData
		{
			ulong w, w_outer; 
			float nPos; 
			float pageSize; 
			ValueRange rng; 
			
			int wrapCnt; 
			
			bool changed_kb, changed_m; 
			
			this(
				DateTime tMin, DateTime tMax, 
				DateTime t0, DateTime t1
			)
			{
				w = t1.raw - t0.raw; 
				w_outer = tMax.raw - tMin.raw; 
				
				nPos = (((float(t0.raw - tMin.raw)))/(w_outer - w)); 
				pageSize = (((float(w)))/(w_outer)); 
				rng = ValueRange(0, 1, pageSize / 8); 
			} 
			
			bool handleKeyboard()
			{
				const b = im.sliderState.handleKeyboard(nPos, rng, pageSize); 
				if(b) changed_kb = true; return b; 
			} 
			
			bool handleMouse(in im.Id id, in im.HitInfo hit, in vec2 mousePos)
			{
				const b = im.sliderState.handleMouse	(
					id, hit, nPos, mousePos,
					rng, wrapCnt
				); 
				if(b) changed_m = true; return b; 
			} 
			
			@property changed() => changed_kb || changed_m; 
		} 
		
		auto getNormalizedSliderData()
		=> NormalizedSliderData(tMin, tMax, t0, t1); 
		
		bool jumpTo(float nPos)
		{
			if(nPos.isnan) return false; nPos = nPos.clamp(0, 1); 
			const 	w 	= t1.raw 	- t0.raw,
				w_outer 	= tMax.raw 	- tMin.raw; 
			const t0_prev = t0, t1_prev = t1; 
			t0 = tMin .shift(w_outer - w, nPos, tMin, tMax), 
			t1 = t0   .shift(w, 1, tMin, tMax); 
			sanitizeRanges; return (t0!=t0_prev) || (t1!=t1_prev); 
		} 
		
		bool scrollByTime(DateTime startT0, Time Δt)
		{
			const len = t1.raw - t0.raw; const t0_prev = t0, t1_prev = t1; 
			t0 = startT0             .scroll(Δt, tMin.raw, tMax.raw-len),
			t1 = startT0.add_raw(len).scroll(Δt, tMin.raw+len, tMax.raw); 
			sanitizeRanges; return (t0!=t0_prev) || (t1!=t1_prev); 
		} 
		
		bool zoomAround(DateTime center, float amount)
		{
			if(amount.isnan || !amount) return false; 
			
			float sc = 1 + inputs.MW.delta.abs * .25; 
			if(inputs.MW.delta>0) sc = 1/sc; 
			
			bool tryZoom()
			{
				auto calcLen() => t1.raw-t0.raw; 
				const len = calcLen; 
				t0 = t0.scale(center, sc, tMin, tMax); 
				t1 = t1.scale(center, sc, tMin, tMax); 
				sanitizeRanges; 
				return len!=calcLen; 
			} 
			
			if(!tryZoom)
			{
				if(sc>1/+zoom out attempt failed?+/)
				{
					sc = 2/+increase coom out amount+/; 
					if(!tryZoom)
					{
						/+
							Maybe it is next to tMax, then 
							zoom away from t1.
						+/
						center = t1; 
						if(!tryZoom)
						{
							t0 = tMin, t1 = tMax; 
							/+return home as a last resort.+/
						}
					}
				}
			}
			
			return true; 
		} 
		
		
		
		
		/+Note: Step 1.+/
		void setup(
			const 	DateTime tMin_, 	const 	DateTime tMax_, 
			ref 	DateTime t0_, 	ref 	DateTime t1_, 
			vec2 mousePos, ref im.HitInfo hit
		)
		{
			tMin 	= tMin_,
			tMax 	= tMax_,
			t0 	= t0_,
			t1 	= t1_; 
			sanitizeRanges; 
			
			hitBounds = hit.hitBounds; 
			
			mouseAtTopHalf = !hitBounds || mousePos.y < hitBounds.center.y; 
			
			const 	norm_mouseX 	= ((
				hitBounds && 
				hitBounds.width
			)?(((mousePos.x-hitBounds.left)/(hitBounds.width))):(0)),
				t_hovered_top 	= tMin.shift(tMax.raw-tMin.raw, norm_mouseX, tMin, tMax),
				t_hovered_bottom 	= t0.shift(t1.raw-t0.raw, norm_mouseX, tMin, tMax); 
			
			show_highlighted_t = mouseAtBottomHalf; 
			highlighted_t = t_hovered_bottom; 
		} 
		
		/+Note: Step 2.+/
		void perform(
			bool focused_, const ref TextStyle ts, vec2 mousePos, const ref im.HitInfo hit,
			ref bool userModified, ref 	DateTime t0_, 	ref 	DateTime t1_
		)
		{
			this.focused = focused_; 
			ref rss = im.dateTimeRulerScrollState; 
			
			if(focused && im.canProcessUserInput)
			{
				//mouse and kbd handling on the top half as a scrollbar slider
				{
					auto nsd = getNormalizedSliderData; 
					
					nsd.handleKeyboard; 
					
					if(hit.pressed && mouseAtBottomHalf)
					{/+beep; +//+left button pressed at highlighted_t+/}
					else { nsd.handleMouse(id, hit, mousePos); }
					
					if(nsd.changed)
					{ if(jumpTo(nsd.nPos)) userModified = true; }
				}
				
				//Zooming
				if(hitBounds && mouseAtBottomHalf && inputs.MW.delta)
				{
					if(zoomAround(highlighted_t, inputs.MW.delta))
					userModified = true; 
				}
				
				//Scrolling
				{
					if(hitBounds && mouseAtBottomHalf && inputs.MMB.pressed)
					{ rss.startScroll(mousePos, t0, t1); }
					
					if(hitBounds && rss.scrolling)
					{
						//It can be only measured inside the hitbox.
						rss.updateScroll((t1-t0)/hitBounds.width); 
					}
					
					if(rss.scrolling)
					{
						if(
							scrollByTime(
								rss.startT0,
								rss.currentDelta(mousePos)
							)
						)
						userModified = true; 
					}
				}
			}
			
			if(!focused || !inputs.MMB.down) rss.scrolling = false; 
			
			bkColor = ts.bkColor; 
			clText = ts.fontColor; 
			
			hoverOrFocus = hit.enabled ? max(hit.hover_smooth*.33f, focused ? 1.0f : 0) : 0; 
			
			clRedText = clRed; 
			clMajorTick = clText; 
			clMinorTick = mix(clMajorTick, bkColor, .125f); 
			
			const fh = ts.fontHeight; 
			innerSize = vec2(fh*20, fh*2.5*2) /+default size+/; 
			
			if(userModified)
			{ t0_ = t0, t1_ = t1; }
		} 
		
		override void draw(Drawing dr)
		{
			const t0 = t0_draw, t1 = t1_draw; 
			
			
			const mod_update = !hitBounds.empty && !inputs.LMB.value; 
			
			const b = innerBounds/+ + innerPos <- FUUUUUUUUUUUUUUCK!!!!+/; 
			const fh = b.height/5.625f, rh = fh*5/2; 
			auto 	bTop 	= bounds2(b.left, b.top, b.right, b.top+rh),
				bBottom 	= bounds2(b.left, b.bottom-rh, b.right, b.bottom); 
			bounds2 bCenter, bThumb; 
			float t0x, t1x; 
			
			{
				dr.pushClipBounds(b); scope(exit) dr.popClipBounds; 
				
				import het.ui_ruler; 
				const 	topIsFine 	= drawHRuler(dr, bTop, tMin, tMax, shiftUpwards: true),
					bottomIsFine 	= drawHRuler(dr, bBottom, t0, t1); 
				if(!topIsFine) bTop.bottom -= fh; 
				if(!bottomIsFine) bBottom.top += fh; 
				bCenter = bounds2(b.left, bTop.bottom, b.right, bBottom.top); 
				
				{
					dr.color = clAccent; dr.alpha = .25; scope(exit) dr.alpha = 1; 
					void fill(float leftX0, float leftX1, float rightX0, float rightX1, int y0, int y1)
					{
						const step = 1.0f/(y1-y0); float t=step/2; 
						foreach(i; 0..y1-y0)
						{
							const y = i+y0, tt = (1-cos(t*(float(π))).signedpow(0.0625))/2; 
							dr.fillRect(
								bounds2(
									mix(leftX0 , leftX1 , tt), y, 
									mix(rightX0, rightX1, tt), y+1
								)
							); 
							t += step; 
						}
					} 
					
					float remap(DateTime t)
					=> b.left + ((b.width*(t.raw.clamp(tMin.raw, tMax.raw) - tMin.raw))/(tMax.raw - tMin.raw)); 
					t0x = remap(t0), t1x = remap(t1); 
					
					dr.fillRect(bounds2(b.left, b.top, t0x, bCenter.top.ifloor)); 
					dr.fillRect(bounds2(t1x, b.top, b.right, bCenter.top.ifloor)); 
					fill(bCenter.left, bCenter.left, t0x, bCenter.left, bCenter.top.ifloor, bCenter.bottom.iceil); 
					fill(t1x, bCenter.right, bCenter.right, bCenter.right, bCenter.top.ifloor, bCenter.bottom.iceil); 
					
					bThumb = bounds2(t0x, bTop.top, t1x, bTop.bottom); 
				}
			}
			
			drawBorder(dr); 
			if(hoverOrFocus)
			{
				dr.alpha = hoverOrFocus; scope(exit) dr.alpha = 1; 
				dr.color = clBlack; dr.lineWidth = 2; 
				dr.drawRect(b.inflated(vec2(-1, 0/+Todo: A bit lame, but looks good+/))); 
				
				
				if(!mouseAtTopHalf) dr.alpha = hoverOrFocus/2; 
				const bt = bThumb.inflated(vec2(-1,0)); 
				if(false)
				{ dr.color = clAccent; dr.drawRect(bt); }
				else
				with(bt)
				{
					dr.line(topLeft, bottomLeft); 
					dr.line(topRight, bottomRight); 
					dr.line(bottomLeft, bottomRight); 
				}
				
				if(show_highlighted_t)
				{
					dr.alpha = hoverOrFocus; 
					
					const t = highlighted_t; 
					const xTop = b.left + ((b.width*(t.raw.clamp(tMin.raw, tMax.raw) - tMin.raw))/(tMax.raw - tMin.raw)); 
					const xBottom = b.left + ((b.width*(t.raw.clamp(t0.raw, t1.raw) - t0.raw))/(t1.raw - t0.raw)); 
					
					dr.lineWidth = 1.05f; dr.color = clRedText; 
					
					const 	A = vec2(xTop, bTop.top), 
						B = vec2(xTop, bCenter.top),
						C = vec2(xBottom, bCenter.center.y), 
						D = vec2(xBottom, bBottom.bottom); 
					dr.line(A, B); /+dr.line(B, C);+/ dr.line(C, D); 
					
					version(/+$DIDE_REGION+/none) {
						//curver line is ugly
						dr.line(A, B); 
						enum N = 10; 
						const P = iota(N).map!((i){
							const t = i*(1.0f/(N-1)); 
							const tt = (1-cos(t*(float(π))).signedpow(0.0625))/2; 
							return vec2(mix(B.x, C.x, tt), mix(B.y, C.y, t)); 
						}).array; 
						foreach(i; 1..P.length) dr.line(P[i-1], P[i]); 
						dr.line(C, D); 
					}
				}
			}
			
			im.sliderState.afterDraw(
				id, SliderOrientation.horz, 
				dr.inputTransform(bTop.topLeft     + bThumb.size/2), 
				dr.inputTransform(bTop.bottomRight - bThumb.size/2), 
				dr.inputTransform(bThumb)
			); 
			
			drawDebug(dr); 
		} 
	} 
	
	//Todo: Unqual is not needed to check a type. Try to push this idea through a whole testApp.
	//Todo: form resize eseten remeg a viewGUI-ra rajzolt cucc.
	//Todo: Beavatkozas / gombnyomas utan NE jojjon elo a Button hint. Meg a tobbi controllon se!
	//Todo: Hint should move in realtime with the mouse, not just popup and stay.
	//! FieldProps stdUI /////////////////////////////
	
	
	//UDA declarations in het
	
	struct FieldProps
	{
		string fullName, name, caption, hint, unit; 
		RANGE range; 
		bool indent; 
		string[] choices; 
		bool isReadOnly; 
		
		static string makeFullName(string parentFullName, string fieldName)
		{ return [parentFullName, fieldName].filter!(not!empty).join('.'); } 
		
		string getCaption() const
		{
			auto s = caption!="" ? caption : camelToCaption(name); 
			if(s.length && indent)
			s = "      "~s; 
			return s; 
		} 
		
		size_t hash() const
		{ return fullName.xxh3; } 
		
		//Todo: compile time flexible struct builder. Eg.: FieldProps().caption("Capt").unit("mm").logRange(0.1, 1000)
		/+
			https://forum.dlang.org/post/etgucrtletedjssysqqu@forum.dlang.org
			struct S{
					private int _a, _b;
			
					auto opDispatch(string name)(int value)
					if (name.among("a", "b"))
					{
							mixin("_", name, "= value;");
							return this;
					}
			
					auto opDispatch(string name)()
					if (name.among("a", "b"))
					{
							 mixin("return _", name, ";");
					}
			}
			
			void main(){
					S.init.a(123).b(456).writeln;
					S().b(456).a(123).writeln;  // Alternative syntax, may not work if opCall is defined
			}
		+/
		
	} 
	FieldProps getFieldProps(T, string fieldName)(string parentFullName)
	{
		alias f = __traits(getMember, T, fieldName); 
		FieldProps p; 
		
		p.fullName 	= FieldProps.makeFullName(parentFullName, fieldName),
		p.name	= fieldName,
		p.caption	= getUDA!(f, CAPTION).text,
		p.hint	= getUDA!(f, HINT).text,
		p.unit	= getUDA!(f, UNIT).text,
		p.range	= getUDA!(f, RANGE),
		p.indent	= hasUDA2!(f, INDENT),
		p.choices	= EnumMemberNames!T; 
		//Todo: readonly
		
		return p; 
	} 
	 void stdStructFrame(string caption, void delegate() contents)
	{
		with(im)
		{
			Column(
				{
					if(caption!="")
					{
						border = "1 normal black"; 
						padding = "2"; 
						margin = "2"; 
						
						Row({ Text(tsBold, caption); }); 
					}
					
					contents(); 
				}
			); 
		}
	} 
	
	void stdUI(Property prop, string parentFullName="")
	{
		//Todo: ennek inkabb benne kene lennie a Property class-ban...
		if(prop is null) return; 
		auto fp = FieldProps(
			FieldProps.makeFullName(parentFullName, prop.name), 
			prop.name, prop.caption, prop.hint
		); 
		fp.isReadOnly = prop.isReadOnly; 
		
		void doit(T)(ref T act)
		{ immutable old = act; stdUI(act, fp); prop.uiChanged |= old != act; } 
		
		if(auto p = cast(IntProperty)prop)	{
			fp.range.min = p.min; 
			fp.range.max = p.max; 
			doit(p.act); 
		}
		else if(auto p = cast(FloatProperty)prop)	{
			fp.range.min = p.min; 
			fp.range.max = p.max; 
			doit(p.act); 
		}
		else if(auto p = cast(StringProperty)prop)	{
			fp.choices = p.choices; 
			doit(p.act); 
		}
		else if(auto p = cast(BoolProperty)prop)	{ doit(p.act); }
		else if(auto p = cast(PropertySet)prop)	{
			stdStructFrame
			(
				fp.getCaption, 
				{ p.properties.each!stdUI; }
			); 
		}
	} 
	
	void stdUI(T)(ref T data, in FieldProps thisFieldProps=FieldProps.init)
	{
		with(im)
		{
			//print("generating UI for ", T.stringof, thisFieldProps.name);
			
			/*
				static if(is(T==enum)){ //todo: ComboBox
						Row({
							Text(thisFieldProps.getCaption, "\t");
				
						});
					}else
			*/
			
			static if(isSomeString!T)
			{
				Row(
					{
						Text(thisFieldProps.getCaption, "\t"); 
						if(thisFieldProps.choices.length)
						{ ComboBox(data, thisFieldProps.choices, genericId(thisFieldProps.hash), hint(thisFieldProps.hint), ((!thisFieldProps.isReadOnly).名!q{enabled}), { width = fh*10; }); }else
						{ Edit(data, genericId(thisFieldProps.hash), hint(thisFieldProps.hint), ((!thisFieldProps.isReadOnly).名!q{enabled}), { width = fh*10; }); }
					}
				); 
			}else static if(isFloatingPoint!T)
			{
				Row(
					{
						Text(thisFieldProps.getCaption, "\t"); 
						auto s = format("%g", data); 
						Edit(s, genericId(thisFieldProps.hash), hint(thisFieldProps.hint), ((!thisFieldProps.isReadOnly).名!q{enabled}), { width = fh*4.5; }); 
						try
						{ data = s.to!T; }catch(Throwable)
						{}
						Text(thisFieldProps.unit, "\t"); 
						if(thisFieldProps.range.isComplete)
						Slider(data, hint(thisFieldProps.hint), thisFieldProps.range, genericId(thisFieldProps.hash+1), ((!thisFieldProps.isReadOnly).名!q{enabled}), { width = 180; }); //Todo: rightclick
						//Todo: Bigger slider height when (theme!="tool")
					}
				); 
			}else static if(isIntegral!T)
			{
				Row(
					{
						Text(thisFieldProps.getCaption, "\t"); 
						auto s = data.text; 
						Edit(s, genericId(thisFieldProps.hash), hint(thisFieldProps.hint), ((!thisFieldProps.isReadOnly).名!q{enabled}), { width = fh*4.5; }); 
						try
						{ data = s.to!T; }catch(Throwable)
						{}
						Text(thisFieldProps.unit, "\t"); 
						if(thisFieldProps.range.isComplete)
						Slider(data, thisFieldProps.range, genericId(thisFieldProps.hash+1), hint(thisFieldProps.hint), ((!thisFieldProps.isReadOnly).名!q{enabled}), { width = 180; }); //Todo: rightclick
					}
				); 
			}else static if(is(T == bool))
			{
				Row(
					{
						Text(thisFieldProps.getCaption, "\t"); 
						ChkBox(data, "", genericId(thisFieldProps.hash), hint(thisFieldProps.hint), ((!thisFieldProps.isReadOnly).名!q{enabled})); 
						Text("\t"); 
					}
				); 
			}else static if(isAggregateType!T)
			{
				 //Struct, Class
				
				enum bool notHidden(string fieldName) = !hasUDA2!(__traits(getMember, T, fieldName), HIDDEN); 
				import std.meta; 
				enum visibleFields = Filter!(notHidden, AllFieldNames!T); 
				
				stdStructFrame(
					thisFieldProps.getCaption, {
						//recursive call for each field
						foreach(fieldName; visibleFields)
						{
							{
								auto fp = getFieldProps!(T, fieldName)(thisFieldProps.fullName); 
								stdUI(mixin("data.", fieldName), fp); 
							}
						}
					}
				); 
				
			}else
			{ static assert(0 ,"Unhandle type: "~T.stringof); }
		}
	} 
	
	
	
	
	
	
	
	__gshared ResourceMonitor resourceMonitor; //automatically updated
	
	struct ResourceMonitor
	{
		struct Item
		{
			bool isAccumulator=true; 
			
			enum timeStepNames 	= ["1 sec",   "10 sec",   "2 min",    "24 min"],
			counterMax	= [1,	  10,          12,          12         ],
			timeRangeNames	= [   "5 min",   "50 min",  "10 hour",   "5 day"],
			M	= timeStepNames.length.to!int,
			N	= 300; 
			static assert(counterMax.length == M && timeRangeNames.length == M); 
			
			/+
				enum M = 4;
				enum string[M] timeStepNames = [   "1 sec",     "10	sec",     "2	min",    "24 min"];
				enum int[M] counterMax = [1,         10,	12,         12	];
				enum N = 300;
				enum string[M] timeRangeNames = ["5 min",    "50 min",     "10 hour",   "5 day" ];
			+/
			float[M] act; 
			float[N][M] history; 
			int[M] counter; 
			
			float val() const
			{ return history[0][$-1]; } 
			
			void update()
			{
				 //must call in every seconds
				if(isnan(history[0][0]))
				{
					//initialize fucking nans
					foreach(ref a; act)
					a = 0; 
					foreach(ref b; history)
					foreach(ref a; b)
					a = 0; 
				}
				
				foreach(i; 0..M)
				{
					//print(i, counter[i], counterMax[i]);
					counter[i] ++; 
					if(counter[i] >= counterMax[i])
					{
						counter[i] = 0; 
						
						//latch it out fast
						float a = act[i]; 
						if(isAccumulator)
						{
							act[i] = 0; 
							a /= counterMax[i]; //average
						}
						
						//shift
						history[i][0..$-1] = history[i][1..$]; 
						history[i][$-1] = a; 
						
						//carry
						if(i+1<M)
						{
							if(isAccumulator)
							act[i+1] += a; 
							else act[i+1] = a; 
						}
					}else
					{ break; }
				}
			} 
			
		} 
		
		Item
			textureCount, texturePoolSize, textureUsedSize,
		
			bitmapCount, allBitmapSize, nonUnloadableBitmapSize, residentBitmapSize,
		
			virtualFileCount, allVirtualFileSize, residentVirtualFileSize,
		
			UPS, FPS, TPS/+Bug: TPS calculation is bogus, it shows too big values+/, VPS,
		
			gcUsed, gcFree, gcAll, gcRate; 
		
		private DeltaTimer DT; 
		
		void updateInternal(void delegate() onCollectData)
		{
			
			/+
				immutable unit = 24*60*60;
				__gshared static long lastUnit;
				long actUnit = cast(long)(floor(now.raw*unit));
				long deltaUnit = actUnit-lastUnit;
				lastUnit = actUnit;
				
				if(deltaUnit>100) deltaUnit = 1; //ignore to big lag
				
				if(deltaUnit>0) onCollectData();
				
				foreach(i; 0..deltaUnit){
				
					static foreach(idx, name; FieldNameTuple!(typeof(this))){{
						alias T = Fields!(typeof(this))[idx];
						static if(is(T==Item)) mixin(name).update;
					}}
				} 
			+/
			
			__gshared static DateTime next; 
			
			bool collected = false; 
			while(now>=next || !next)
			{
				next = now + 1*second; 
				if(next + 100*second < now)
				next = now; //ignore to big lag
				
				if(chkSet(collected))
				onCollectData(); //collect only once, but update on every second
				
				static foreach(idx, name; FieldNameTuple!(typeof(this)))
				{
					{
						alias T = Fields!(typeof(this))[idx]; 
						static if(is(T==Item))
						mixin(name).update; 
					}
				}
			}
			
		} 
		
		void update()
		{
			updateInternal
			(
				{
					//collect and actualize data
					textureCount	.act[0] = textures_length,
					texturePoolSize	.act[0] = textures_poolSizeBytes,
					textureUsedSize	.act[0] = textures_usedSizeBytes; 
					
					const bs = bitmaps.stats; 
					bitmapCount	.act[0] = bs.count,
					residentBitmapSize	.act[0] = bs.residentSizeBytes,
					nonUnloadableBitmapSize	.act[0] = bs.nonUnloadableSizeBytes,
					allBitmapSize	.act[0] = bs.allSizeBytes; 
					
					const vs = virtualFiles.stats; 
					virtualFileCount	.act[0] = vs.count,
					residentVirtualFileSize	.act[0] = vs.residentSizeBytes,
					allVirtualFileSize	.act[0] = vs.allSizeBytes; 
					
					UPS	.act[0] = mainWindow.UPS, 
					FPS	.act[0] = mainWindow.FPS; 
					
					TPS	.act[0] = global_TPS,
					VPS	.act[0] = global_VPS; 
					
					import core.memory : GC; 
					with(GC.stats)
					{
						gcUsed.act[0] = usedSize; 
						gcFree.act[0] = freeSize; 
						gcAll.act[0] = usedSize+freeSize; 
						
						const long act = allocatedInCurrentThread; 
						__gshared long last; 
						
						gcRate.act[0] = act-last; 
						last = act; 
					}
				}
			); 
		} 
		
		void UI(float graphWidth)
		{
			with(im)
			{
				
				immutable
					clTexturePool 	= (RGB(255, 180, 40)),
					clTextureUsed 	= (RGB(180, 255, 40)),
						
					clBitmap	= clAqua,
					clHotBitmap	= mix(clGray, clBitmap, .5),
					clResidentBitmap	= mix(clGray, clBitmap, .25),
						
					clVirtualFile	= (RGB(100, 150, 255)),
					clResidentVirtualFile	= mix(clGray, clVirtualFile, .25),
						
					clUPS	= (RGB(180, 40, 255)),
					clFPS	= (RGB(255, 40, 180)),
						
					clTPS	= (RGB(40,  80, 255)),
					clVPS	= (RGB(40, 255,  80)),
						
					clGcUsed	= (RGB(120, 180, 40)),
					clGcAll	= (RGB(40, 220, 120)),
					clGcRate	= (RGB(80, 160,  90)); 
				
				static int timeIdx = 0; 
				int gridXStepSize = Item.N/(timeIdx==2 ? 10 : 5); 
				
				
				void Legend(string title, float size=float.nan, RGB color = RGB(1, 2, 3), string suffix="")
				{
					if(color != RGB(1, 2, 3))
					Text(color, symbolStr("CheckboxFill"), tsNormal.fontColor, " "); 
					Text(title); 
					if(!isnan(size))
					Row(HAlign.right, shortSizeText!1024(size)~suffix, { width = fh*(2.25 + suffix.length*0.3); }); 
				} 
				
				struct Data
				{ float[] values; RGB color; } 
				
				void Graph(string name, Data[] data, int gridXStepSize = 0, int gridYDivisions=4)
				{
					Btn(
						{
							background = (RGB(40, 40, 40)); 
							padding = "3"; 
							margin = "2 0"; 
							innerWidth = graphWidth; 
							innerHeight = fh*3; 
							
							/*
								auto hit = hitTest(actContainer, true);
								const w = hit.hitBounds.width-actContainer.totalGapSize.x;
								const h = innerHeight;
							*/
							
							const w = innerWidth; 
							const h = innerHeight; 
							
							void customDraw(Drawing dr, .Container cntr)
							{
								with(dr)
								{
									const
										dataWidth	= data.map!(d => d.values.length).maxElement(1),
										dataHeight 	= data.map!(d => d.values.maxElement(1)).maxElement(1),
										sx	=  (w+1) / dataWidth,
										sy	= -(h) / dataHeight; 
									
									dr.color = (RGB(70, 70, 70)); 
									dr.lineWidth = 1; 
									if(gridXStepSize)
									iota(0, dataWidth+1, gridXStepSize).each!(i => vLine(round(sx*i)-.5f, 0, h)); 
									if(gridYDivisions)
									iota(gridYDivisions+1).each!(i => hLine(0, (h*i/gridYDivisions).round-.5f, w)); 
									
									dr.lineWidth = 2; 
									foreach(d; data)
									{ color = d.color;  hGraph_f(0, h, d.values, sx, sy); }
								}
							} 
							addDrawCallback(&customDraw); 
						},
						genericId(name)
					); 
				} 
				
				void Spacer() { im.Spacer(2); } 
				
				void VirtualFileGraph()
				{
					Row(
						{
							Text(format!"Virtual files[] (%s)"(virtualFileCount.val)); 	Flex; 
							Legend("Resident", residentVirtualFileSize.val, clResidentVirtualFile, "B"); 	Spacer; 
							Legend("All"     , allVirtualFileSize.val     , clVirtualFile        , "B"); 	
						}
					); 
					Graph(
						"VirtualFiles", [
							Data(residentVirtualFileSize.history[timeIdx][], clResidentVirtualFile),
							Data(allVirtualFileSize     .history[timeIdx][], clVirtualFile       )
						], gridXStepSize
					); 
				} 
				
				void BitmapCacheGraph()
				{
					Row(
						{
							Text(format!"Bitmaps (%s)"(bitmapCount.val)); 	Flex; 
							Legend("Res", residentBitmapSize.val, clResidentBitmap, "B"); 	Spacer; 
							Legend("Hot", nonUnloadableBitmapSize.val, clHotBitmap, "B"); 	Spacer; 
							Legend("All" , allBitmapSize.val, clBitmap, "B"); 
						}
					); 
					Graph(
						"BitmapCache", [
							Data(residentBitmapSize      .history[timeIdx][], clResidentBitmap),
							Data(nonUnloadableBitmapSize.history[timeIdx][], clHotBitmap),
							Data(allBitmapSize           .history[timeIdx][], clBitmap)
						], gridXStepSize
					); 
				} 
				
				void TextureCacheGraph()
				{
					Row(
						{
							Text(format!"Textures (%s)"(textureCount.val)); 	Flex; 
							Legend("Used", textureUsedSize.val, clTextureUsed, "B"); 	Text("   "); 
							Legend("Pool", texturePoolSize.val, clTexturePool, "B"); 
						}
					); 
					Graph(
						"TextureCache", [
							Data(texturePoolSize.history[timeIdx][], clTexturePool),
							Data(textureUsedSize.history[timeIdx][], clTextureUsed)
						], gridXStepSize
					); 
				} 
				
				void FPSGraph()
				{
					Row(
						{
							Text("Refresh rate"); 	Flex; 
							Legend("UPS", UPS.val, clUPS, "Hz"); 	Text("   "); 
							Legend("FPS", FPS.val, clFPS, "Hz"); 	
						}
					); 
					Graph(
						"FPS", [
							Data(UPS.history[timeIdx][], clUPS),
							Data(FPS.history[timeIdx][], clFPS)
						], gridXStepSize
					); 
				} 
				
				void TPSGraph()
				{
					Row(
						{
							Text("GPU data upload"); 	Flex; 
							Legend("TEX", TPS.val, clTPS, "B/s"); 	Text("   "); 
							Legend("VBO", VPS.val, clVPS, "B/s"); 	
						}
					); 
					Graph(
						"TPS", [
							Data(TPS.history[timeIdx][], clTPS),
							Data(VPS.history[timeIdx][], clVPS)
						], gridXStepSize
					); 
				} 
				
				void GCGraph()
				{
					Row(
						{
							Text("GC memory"); 	Flex; 
							Legend("Used", gcUsed.val,	clGcUsed,	"B"); 	Text("   "); 
							Legend("All" , gcAll.val,	clGcAll ,	"B"); 	
						}
					); 
					Graph(
						"GC", [
							Data(gcUsed.history[timeIdx][], clGcUsed),
							Data(gcAll .history[timeIdx][], clGcAll)
						], gridXStepSize
					); 
				} 
				
				void GCRateGraph()
				{
					Row(
						{
							Text("GC memory (main thread)"); 	Flex; 
							Legend("allocation rate", gcRate.val, clGcRate, "B/s"); 	
						}
					); 
					Graph("GCRate", [Data(gcRate.history[timeIdx][], clGcRate)], gridXStepSize); 
				} 
				
				void SelectTimeIdx()
				{
					Row(
						{
							Column(
								{
									Text("Time step"); 
									ComboBox(timeIdx, Item.timeStepNames , { width = fh*4; }); 
								}
							); 
							Column(
								{
									Text("Visible interval"); 
									ComboBox(timeIdx, Item.timeRangeNames, { width = fh*4; }); 
								}
							); 
						}
					); 
				} 
				
				Column(
					{
						padding = "4"; 
						border = "1 normal silver"; 
						theme.tool; 
						Row(
							YAlign.top,
							{
								Text(boldStr("Resource Monitor")); 
								Flex; SelectTimeIdx; 
							}
						); 	Spacer; 
						VirtualFileGraph; 	Spacer; 
						BitmapCacheGraph; 	Spacer; 
						TextureCacheGraph; 	Spacer; 
						TPSGraph; 	Spacer; 
						FPSGraph; 	Spacer; 
						GCGraph; 	Spacer; 
						GCRateGraph; 	Spacer; 
					}
				); 
				
			}
		} 
	} 
	void UI_SystemDiagnostics()
	{
		with(im)
		{
			Row("Build\t", { Static(__TIMESTAMP__, { width = fh*16; }); }); 
			auto n = now, ldt = n.localDelphiTime; 
			Row("UTC time:\t"  , { Static(n.utcText                                                       , { width = fh*16; }); }); 
			Row("Delphi time\t", { Static(ldt.format!"%.6f"~"   hours only: "~(ldt.fract*24).format!"%.6f", { width = fh*16; }); }); 
			Row("Unix time\t"  , { Static(n.unixTime.format!"%.6f"                                        , { width = fh*16; }); }); 
			static bool showResMonitor; 
			Row(
				YAlign.top, "Diagnostics\t", {
					Column(
						{
							ChkBox(mainWindow.showFPS, "Show FPS Graph"); 
							ChkBox(showResMonitor, "Show Resource Monitor"); 
						}
					); 
				}
			); 
			if(showResMonitor)
			{
				resourceMonitor.UI(344); 
				Row(
					"GC manual control ", {
						import core.memory; 
						foreach(b; AliasSeq!(GC.collect, GC.minimize, GC.enable, GC.disable))
						if(Btn(b.stringof, genericId(b.stringof)))
						b(); 
						Text("\n", GC.stats.toJson); 
					}
				); 
			}
		}
	} 
	
	
	//! Misc UIs //////////////////////////////////
	
	void UI_globalShaderParams()
	{
		with(im)
		{
			Row("global Shader Parameters"); 
			Row(
				{
					padding = "4"; 
					Column(
						{
							foreach(idx, ref b; globalShaderParams.bools)
							ChkBox(b, idx.format!"bool%d", genericId(idx)); 
						}
					); 
					Spacer; 
					Column(
						{
							foreach(idx, ref f; globalShaderParams.floats)
							Row(
								{
									theme.tool; 
									Text(idx.format!"float%d\t"); 
									Slider(f, linRange(0, 1), { width = 12*fh; }, genericId(idx)); 
								}
							); 
							
						}
					); 
				}
			); 
		}
	} 
	
	
}
struct im
{
	static: 
	version(/+$DIDE_REGION+/all)
	{
		/+
			Note: This is also a way to create a 'namespace' in D, with a template.
			template Algo_ns()
			{
			   void drawLine() { writeln("drawLine"); }
			}
			
			// need this to avoid the instantiation syntax
			alias Algo = Algo_ns!();
		+/
		
		alias Id = het.SrcId; 
		
		//Frame handling
		bool 	mouseOverUI, /+readonly: GUI noticed that the ouse is over a GUI element.+/
			wantMouse, wantKeys, /+readonly: GUI is currently wanting to process keyboard/mouse input+/
			dialogKeysEnabled=false /+
			writeOnly: GUI will not process Dialog keys, for 
			example Space key in the focused Btn
			/+
				Todo: 260824 This is experimental and turned off by default.
				Every key should have the option to enabled/disabled.
				For example: Space = no, ArrowKeys = yes.
				My GUI is more like an overlay visualization, 
				it's not the center of attention, like in busisess sw.
			+/
		+/; 
		private bool inFrame, canDraw; //synchronization for internal methods
		
		version(/+$DIDE_REGION Views+/all)
		{
			private View2D[2] targetSurfaceViews; 
			private TargetSurface selectedTargetSurface; 
			
			@property view_world()
			=> targetSurfaceViews[0]; 	@property view_gui()
			=> targetSurfaceViews[1]; @property targetView()
			=> targetSurfaceViews[selectedTargetSurface]; 
			
			void setTargetSurfaces(View2D view_world, View2D view_gui)
			{ targetSurfaceViews = [view_world, view_gui]; } 
			
			/+
				Todo: this should be the only opportunity to switch between 
				GUI and World. Better than a containerflag that is initialized too late.
			+/
			void selectTargetSurface(TargetSurface n)
			{ selectedTargetSurface = n; } 
			
			private TargetSurface _targetSurfaceBeingDrawn; 
			@property targetSurfaceBeingDrawn()
			=> _targetSurfaceBeingDrawn; 
		}
		float deltaTime=0; 
		
		
		version(/+$DIDE_REGION Frame handling+/all)
		{
			private bool _canProcessUserInput; //it is latched per every frame
			bool canProcessUserInput()
			=> _canProcessUserInput; 
			bool canProcessDialogKeys()
			=> canProcessUserInput && dialogKeysEnabled; 
			
			//Todo: package visibility is not working as it should -> remains public
			void _beginFrame(View2D viewWorld, View2D viewGUI)
			{
				//called from mainform.update
				
				enforce(!inFrame, "im.beginFrame() already called."); 
				
				_canProcessUserInput = mainWindow.canProcessUserInput; 
				
				setTargetSurfaces(viewWorld, viewGUI); 
				selectTargetSurface(TargetSurface.gui); //default is the GUI surface
				
				//inject stuff into het.uibase. So no import het.ui is needed there.
				//Todo: het.uibase was merged with het.ui. This is no longer needed.
				static auto getActFontHeight()
				{ return float(textStyle.fontHeight); 	} 	.g_actFontHeightFunct	= &getActFontHeight; 
				static auto getActFontColor ()
				{ return textStyle.fontColor; 	} 	.g_actFontColorFunct	= &getActFontColor; 
				version(/+$DIDE_REGION+/none) { .g_getOverlayDrawingFunct = &getOverlayDrawing; }
				.g_getDrawCallbackFunct = &getDrawCallback; 
				
				//update building/measuring/drawing state
				inFrame = true; 
				canDraw = false; 
				
				imReset; 
				//this goes into endFrame, so the latest hit data will be accessible more early. hitTestManager.initFrame;
				
				//clear last frame's object references
				focusedState.container = null; 
				textEditorState.beginFrame; 
				
				dropdownState.beginFrame; 
				
				//this is needed for DockAlignment
				rootContainer.clientArea = view_gui.screenBounds_anim.bounds2; 
				//Maybe it is the same as the bounds for clipping rects: flags.clipChildren
				
				static DeltaTimer dt; 
				deltaTime = dt.update; 
				
				ImStorageManager.purge(200/+maxAge 200? Why?+/); 
				
				{
					static uint	tbmp; if(tbmp.chkSet((QPS.value(second).ifloor  )/2))
					bitmaps	.garbageCollect; 
				}
				{
					static uint tvf; if(tvf .chkSet((QPS.value(second).ifloor+1)/2))
					virtualFiles.garbageCollect; 
				}
				
				resourceMonitor.update; 
			} 
			
			void _endFrame()
			{
				//called from end of update
				
				enforce(inFrame, "im.endFrame(): must call beginFrame() first."); 
				enforce(stack.length==1, "FATAL ERROR: im.endFrame(): stack is corrupted. 1!="~stack.length.text); 
				
				selectTargetSurface(TargetSurface.gui); //GUI surface by default
				
				version(/+$DIDE_REGION Finalize UI composition+/all)
				{
					updateFlashMessages_internal_onEndFrame; 
					
					if(dropdownState.dropdownContainer)
					imAppend(dropdownState.dropdownContainer); 
				}
				
				auto rc = rootContainers(true); 
				
				//it's not sorted in DIDE... It's a problem...
				//LOG("ISSORTED", rc.isSorted!((a, b)=>(a.flags.targetSurface < b.flags.targetSurface))); 
				
				rc = rc.sort!(((a, b)=>(a.flags.targetSurface < b.flags.targetSurface)), SwapStrategy.stable).array; 
				
				version(/+$DIDE_REGION Measure every containers+/all)
				{
					foreach(cntr; rc) {
						if(!cntr.flags._measured) cntr.measure; 
						/+
							Some panels are already have been measured.
							But this optimization is only at the root level.
							Column can re-measure all its subCells more than once.
						+/
					}
				}
				
				
				dropdownState.doAlign; 
				
				hScrollInfo.createBars(true); 
				vScrollInfo.createBars(true); 
				
				//from here, all positions are valid
				
				version(/+$DIDE_REGION Perform HitTest+/all)
				{
					bool[2] mouseOverUI; 
					bool mouseOverDropdownContainer; 
					foreach_reverse(a; rc /+from neares to farthest+/)
					{
						const surf = a.flags.targetSurface; //1: gui, 0:view
						
						const uiMousePos = targetSurfaceViews[surf].mousePos.vec2; 
						if(a.internal_hitTest(uiMousePos))
						{
							mouseOverUI[surf] = true; 
							
							if(dropdownState.dropdownContainer==a)
							mouseOverDropdownContainer = true; 
							
							break; //got a hit, so escape now
						}
					}
					
					version(/+$DIDE_REGION+/none) {
						if(VisualizeHitStack)
						{
							drVisualizeHitStack = new_Drawing; 
							hitTestManager.draw(drVisualizeHitStack); 
						}
					}
					
					/+
						all hitTest are done, move hitTestManager to the next frame. 
								Latest hittest data will be accessible right after this.
					+/
					hitTestManager.nextFrame; 
				}
				
				//clicking away from popup closes the popup
				if(
					dropdownState.active && !dropdownState.opening && !mouseOverDropdownContainer 
					&& (inputs.LMB.pressed || inputs.RMB.pressed)
				)
				dropdownState.active = false; 
				
				/+
					The IM GUI wants to use the mouse for scrolling or clicking. 
					Example: It tells the 'view' not to zoom.
				+/
				wantMouse = mouseOverUI[1]; 
				
				if(textEditorState.active)
				{
					//an edit control is active.
					//Todo: canProcessUserInput check
					auto err = textEditorState.processQueue; 
				}
				wantKeys = textEditorState.active; 
				/+Todo: dialog key handling: Make it completely disabled in DIDE where the main attraction is the editor always receives all the keys.+/
				
				const guiBounds = view_gui.screenBounds_anim.bounds2; 
				generateHints(guiBounds); 
				
				//update building/measuring/drawing state
				canDraw = true; 
				inFrame = false; 
			} 
			
			bounds2[2] surfaceBounds; 
			
			void _drawFrame(string restrict="")(
				Drawing drWorld, Drawing drGUI, 
				void delegate() funBefore=null, void delegate() funAfter=null
			)
			{
				static assert(restrict=="system call only", "im.draw() is restricted to call by system only."); 
				enforce(canDraw, "im.draw(): canDraw must be true. Nothing to draw now."); 
				
				Drawing[2] dr = [drWorld, drGUI]; 
				
				//init clipbounds
				foreach(i, ref d; dr)
				{
					auto view = targetSurfaceViews[i].enforce; 
					d.pushClipBounds(view.screenBounds_anim.bounds2); 
				}
				
				foreach(i; 0..2)
				surfaceBounds[i] = bounds2.init; 
				
				
				if(funBefore) funBefore(); 
				
				foreach(a; rootContainers(true))
				{
					const s = a.flags.targetSurface; 
					surfaceBounds[s] |= a.outerBounds; 
					_targetSurfaceBeingDrawn = s; 
					a.draw(dr[s]); //draw in zOrder
				}
				
				if(funAfter) funAfter(); 
				
				foreach(i, d; dr)
				{ d.popClipBounds; }
				
				//set mouse cursor icon once per frame
				mainWindow.mouseCursor = mouseCursor; 
				
				version(/+$DIDE_REGION+/none) {
					if(VisualizeHitStack && drVisualizeHitStack)
					{
						drVisualizeHitStack.glDraw(targetSurfaces[1].view); 
						//Todo: problem with hitStack: it is assumed to be on GUI view
					}
					drVisualizeHitStack.destroy; 
				}
				
				//not needed, gc is perfect.  foreach(r; root) if(r){ r.destroy; r=null; } root.clear;
				//Todo: ezt tesztelni kene sor cell-el is! Hogy mekkorak a gc spyke-ok, ha manualisan destroyozok.
				
				//Todo: if window resizing, draw is called without update!!!  canDraw = false; can detect it.
			} 
		}
		version(/+$DIDE_REGION HitTest+/all)
		{
			HitTestManager hitTestManager; 
			
			static struct HitInfo
			{
				Id id; 
				bool enabled; 
				bool hover, captured, clicked, pressed, released; 
				float hover_smooth, captured_smooth; 
				bounds2 hitBounds; //this is in ui coordinates. Problematic with zoomable and GUI views.
				vec2 localPos; //relative to outerPos
				
				@property bool down() const
				{ return captured && enabled; } 
				
				@property bool clickedAndEnabled() const
				{ return clicked & enabled; } 
				alias clickedAndEnabled this; 
				
				bool repeated() const
				{
					return pressed || captured && inputs.LMB.repeated; 
					//Todo: architectural bug: captured is delayed by 1 frame according to repeated
				} 
				
				void simulateKey(bool keyPressed, bool keyDown, bool keyReleased)
				{
					if(!enabled) return; 
					
					if(keyPressed)	{
						pressed = hover = captured = clicked = true; 
						/+hover_smooth = 1; captured_smooth = 1; +/
					}
					else if(keyDown)	{
						hover = captured = true; 
						/+hover_smooth = 1; captured_smooth = 1; +/
					}
					else if(keyReleased)	{ released = true; }
				} 
				
				void simulateKey(KeyCombo key)
				{ simulateKey(key.pressed, key.down, key.released); } 
			} 
			static struct HitTestManager
			{
				
				static struct HitTestRec
				{
					Id id; 	//in the	next frame this must be the isSame
					bounds2 hitBounds; 	/+
						absolute bounds on the drawing where the hit test was made, 
						later must be combined with View's transformation
					+/
					vec2 localPos; 	//relative to outerPos
					bool clickable; 
				} 
				
				//act frame
				HitTestRec[] hitStack, lastHitStack; 
				
				float[Id] smoothHover; 
				private void updateSmoothHover(ref HitTestRec[] actHitStack)
				{
					enum upSpeed = 0.5f, downSpeed = 0.25f; 
					
					//raise hover values
					auto hoveredIds = actHitStack.map!"a.id".filter!"a".array.sort; 
					foreach(id; hoveredIds)
					smoothHover[id] = mix(smoothHover.get(id, 0), 1, upSpeed); 
					
					//lower (and remove) hover values
					Id[] toRemove; 
					foreach(id, ref value; smoothHover)
					{
						if(!hoveredIds.canFind(id))
						{
							value = mix(value, 0, downSpeed); 
							if(value<0.02f)
							toRemove ~= id; 
						}
					}
					
					foreach(h; toRemove)
					smoothHover.remove(h); 
				} 
				
				Id capturedId, clickedId, pressedId, releasedId; 
				private void updateMouseCapture(ref HitTestRec[] hits)
				{
					//const topClickableId = hits.get(hits.length-1).id;
					const topId = hits.retro.filter!(h => h.clickable).take(1).array.get(0).id; 
					
					//if LMB was just pressed, then it will be the captured control
					//if LMB released, and the captured id is also hovered, the it is clicked.
					
					clickedId = pressedId = releasedId = Id.init; 
					//normally it's 0 all the time, except that one frame it's clicked.
					
					with(mainWindow)
					{
						//Todo: get the mouse state from elsewhere!!!!!!!!!!!!!
						if(topId && mouse.LMB && mouse.justPressed && canProcessUserInput)
						{
							//Note: isForeground will not work with a toolwindow
							pressedId = capturedId = topId; 
						}
						if(mouse.justReleased)
						{
							if(capturedId)
							{
								releasedId = capturedId; 
								if(topId==capturedId)
								clickedId = capturedId; 
							}
							capturedId = Id.init; 
						}
					}
				} 
				
				void nextFrame()
				{
					lastHitStack = hitStack; 
					hitStack = []; 
					
					updateSmoothHover(lastHitStack); 
					updateMouseCapture(lastHitStack); 
				} 
				
				void addHitRect(in Id id, in bounds2 hitBounds, in vec2 localPos, in bool clickable)
				{
					//must be called from each cell that needs mouse hit test
					static if(addHitRectAsserts)
					{
						assert(id, "Null Id is illegal"); 
						assert(!hitStack.any!(a => a.id==id), "Id already defined for cell: "~id.text); 
					}
					hitStack ~= HitTestRec(id, hitBounds, localPos, clickable); 
				} 
				
				auto check(in Id id)
				{
					HitInfo h; 
					if(id)
					{
						const idx = lastHitStack.map!"a.id".countUntil(id); 
						h.id 	= id,
							h.hover	= lastHitStack.map!"a.id".canFind(id),
							h.pressed	= pressedId ==id,
							h.released	= releasedId==id,
							h.clicked	= clickedId ==id,
							h.captured	= h.pressed || capturedId==id && h.hover,
							h.hover_smooth	= smoothHover.get(id, 0),
							h.captured_smooth 	= max(h.hover_smooth, h.captured),
							h.hitBounds	= lastHitStack.get(idx).hitBounds,
							h.localPos	= lastHitStack.get(idx).localPos; 
						
					}
					return h; 
					//Todo: architectural bug: captured is delayed by 1 frame according to repeated
				} 
				
				version(/+$DIDE_REGION+/none) {
					void draw(DrawingOld dr)
					{
						if(VisualizeHitStack)
						{
							dr.lineWidth = (QPS.value(second)*3).fract; 
							dr.color = clFuchsia; 
							
							hitStack.map!"a.hitBounds".each!(b => dr.drawRect(b)); 
							
							dr.lineWidth = 1; 
							dr.lineStyle = LineStyle.normal; 
						}
					} 
				}
				
				auto stats()
				{
					return format(
						"HitTest lengths: hitStack:%s, lastHitStack::%s, smoothHover::%s", 
						hitStack.length, lastHitStack.length, smoothHover.length
					); 
				} 
				
			} 
			
			static auto hitTest(.Container container)
			{
				assert(container !is null); 
				auto res = hitTestManager.check(container.id); 
				res.enabled = container.flags.enabled; 
				
				container.flags.hover = res.hover; 
				container.flags.captured = res.captured; 
				
				
				return res; 
			} 
			
			auto hitTest()
			{ return hitTest(thisContainer); } 
		}
		version(/+$DIDE_REGION Focus+/all)
		{
			static struct FocusedState
			{
				Id id; 	//globally store the current hash
				.Container container;  	//this is sent to the Selection/Draw routines. If it is null, then the focus is lost.
				
				void reset()
				{ this = typeof(this).init; } 
			} 
			FocusedState focusedState; 
			
			TextEditorState textEditorState; //maintained by edit control
			
			void onFocusLost(in Id oldId)
			{
				if(!oldId) return; 
				if(dropdownState.active && oldId==dropdownState.comboId)
				{ dropdownState.close; }
			} 
			
			/// internal use only
			
			static struct FocusState
			{
				mixin((
					(表([
						[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/}],
						[q{bool},q{1},q{"focused"}],
						[q{bool},q{1},q{"entered"}],
						[q{bool},q{1},q{"exited"}],
					]))
				).調!(GEN_bitfields)); 
				alias this = focused; 
			} 
			//Todo: this needs only 2 bits! none, exited, entered, focused
			
			FocusState focusUpdate(.Container container, in Id id, bool canFocus, lazy bool enterFocusNow, lazy bool exitFocusNow)
			{
				FocusState res; 
				
				if(focusedState.id==id)
				{
					if(!canFocus || exitFocusNow)
					{
						//not enabled anymore: exit focus
						res.exited = true; 
						focusedState.reset; 
						onFocusLost(id); 
					}
				}
				else
				{
					if(canFocus && enterFocusNow)
					{
						 //newly enter the focus
						onFocusLost(focusedState.id); 
						
						focusedState.reset; 
						focusedState.id = id; 
						//Todo: ez bugos, mert nem hivodik meg a focusExit, amikor ez elveszi a focust
						
						focusedState.container = container; 
						res.entered = true; 
					}
				}
				
				res.focused = focusedState.id==id; 
				if(res) focusedState.container = container; 
				container.flags.focused = res; 
				
				return res; 
			} 
			
			bool isFocused(in Id id)	
			{ return focusedState.id!=Id.init	&& focusedState.id == id; } 
			bool isFocused(.Container container)	
			{ return focusedState.container !is null	&& focusedState.container is container; } 
			
			void focusNothing()
			{
				if(focusedState.id)
				{
					onFocusLost(focusedState.id); 
					
					focusedState.reset; 
				}
			} 
			
			//void focusExit(in Id id)	  { if(isFocused(id)) focusedState.reset; }
			//void focusExit(Container container)	  { if(isFocused(container)) focusedState.reset; }
			//void focusExit()	  { focusedState.reset; }
		}
		version(/+$DIDE_REGION Hints+/all)
		{
			const 	float HintActivate_sec	 = 0.5,
				HintDetails_sec	 = 2.5,
				HintRelease_sec	 = 1; 
			
			static struct HintRec
			{
				.Container owner; 
				bounds2 bounds; 
				string markup, markupDetails; //Todo: support delegates too
			} 
			private HintRec[] hints; 
			
			enum HintState
			{ idle, active, details} 
			static hintState = HintState.idle; 
			
			/// This can be used to inject a hint into the parameters of a Control
			auto hint(string markup, string markupDetails="")
			{
				 //Todo: delegate too
				return HintRec(null, bounds2.Null, markup, markupDetails); //Todo: lazyness
			} 
			
			void addHint(HintRec hr)
			{ hints ~= hr; } 
			
			void hideHints()
			{ hintState = HintState.idle; } 
			
			void handleHint(.Container container, ref HintRec hintRec, ref HitInfo hit)
			{
				if(hintRec.markup.length && hit.hover)
				{
					hintRec.owner = container; 
					hintRec.bounds = hit.hitBounds; 
					addHint(hintRec); 
				}
			} 
			
			private void generateHints(in bounds2 screenBounds)
			{
				 //called on the end of the frame
				static float mouseStopped_secs = 0; 
				static float noHint_secs = 0; 
				
				const userBlocking = 	["Esc", "Enter", "LMB", "RMB", "MMB", "Space"]
					.map!((k)=>(inputs[k].active)).any; 
				
				if(inputs.MX.delta==0 && inputs.MY.delta==0)	mouseStopped_secs += deltaTime; 
				else	mouseStopped_secs = 0; 
				
				if(hints.empty)	noHint_secs += deltaTime; 
				else	noHint_secs = 0; 
				
				//enter hint mode
				if(!hints.empty && !userBlocking)
				{
					if(hintState==HintState.idle && mouseStopped_secs>HintActivate_sec)
					hintState = HintState.active; 
					if(hintState==HintState.active && mouseStopped_secs>HintDetails_sec)
					hintState = HintState.details; 
				}
				
				//exit hint mode
				if(hintState != HintState.idle)
				{
					//immediately hide on particular user events
					if(userBlocking) hideHints; 
					
					//hide after no hints to display for a while
					if(noHint_secs>HintRelease_sec) hideHints; 
				}
				
				//actual hint generation
				HintRec lastHint; 
				if(hints.length) lastHint = hints[$-1]; 
				auto hintOwner = lastHint.owner; 
				
				if(hintState != HintState.idle && hintOwner)
				{
					.Container hintContainer; 
					
					Panel(
						{
							hintContainer = thisContainer; 
							padding = "0"; border.color = clGray; 
							
							void HintRow(RGB clText, RGB clBack, string str)
							{
								Row(
									{
										padding.set(4); 
										style.fontColor = clText; 
										background = style.bkColor = clBack; 
										rowFlags.rowElasticTabs = true; 
										Text(str); 
									}
								); 
							} 
							
							if(lastHint.markup!="")
							HintRow(clHintText, clHintBk, lastHint.markup); 
							if(hintState == HintState.details && lastHint.markupDetails!="")
							HintRow(clHintDetailsText, clHintDetailsBk, lastHint.markupDetails); 
						}
					); 
					
					hintContainer.measure; 
					
					//align the hint
					hintContainer.outerPos = 	lastHint.bounds.bottomCenter //Bounds.bottomCenter
						+ vec2(-hintContainer.outerWidth*.5, 5); 
					
					//clamp horizontaly
					const remainingWidth = max(0, screenBounds.width-hintContainer.outerWidth); 
					hintContainer.outerPos.x = clamp(
						hintContainer.outerPos.x, 0, 
						remainingWidth
					); 
					
					//Todo: HintSettings: on/off, hintLocation:nextTo/statusBar/bottomRight, save to ini
				}
				
				hints = []; 
			} 
		}
		
		DateTimeRulerScrollState dateTimeRulerScrollState; 
		private static struct DateTimeRulerScrollState
		{
			bool scrolling; 
			vec2 startMousePos; 
			DateTime startT0, startT1; 
			
			Time pixelDuration /+Must update this regularly+/; 
			
			void startScroll(vec2 mousePos, DateTime t0, DateTime t1)
			{
				scrolling = true; startMousePos = mousePos; 
				startT0 = t0; startT1 = t1; 
			} 
			
			void updateScroll(Time pixelDuration)
			{ this.pixelDuration = pixelDuration; } 
			@property currentDelta(in vec2 mousePos)
			=> pixelDuration * (startMousePos.x - mousePos.x); 
		} 
		
		SliderState sliderState; 
		private static struct SliderState
		{
			//information about the current slider being modified
			
			/+Usage: Call handleKeyboard(), handleMouse() and don't forget to call afterDraw()!!!+/
			
			//information generated and maintained in update
			Id pressed_id; 
			vec2 pressed_thumbMouseOfs, pressed_rawMousePos; 
			float pressed_nPos; //normalized pos
			int lockedDirection; //0:unknown, 1:h, 2:v
			
			void onPress(in Id id, ref float nPos, in vec2 mousePos)
			{
				//mouse was pressed, initialize values
				pressed_id = id; 
				pressed_rawMousePos = rawMousePos; 
				pressed_nPos = nPos; 
				
				//remember the thumb-mouse offset at the time of press
				pressed_thumbMouseOfs = drawn_thumbRect.center-mousePos;  //
				
				//if pressed on a round knob, first it must decide if up/down or left/right
				lockedDirection = 0; 
			} 
			
			//information saved in draw(). All vectors are transformed into view space.
			Id drawn_id; 
			SliderOrientation drawn_orientation; 
			vec2 drawn_p0, drawn_p1; 
			bounds2 drawn_thumbRect; 
			
			void afterDraw(in Id id, in SliderOrientation ori, vec2 p0, vec2 p1, in bounds2 bKnob)
			{
				drawn_id = id; 
				drawn_orientation = ori; 
				drawn_p0 = p0; 
				drawn_p1 = p1; 
				drawn_thumbRect = bKnob; 
			} 
			
			//after onPress() it can jump to the mouse
			void jumpToPoint(ref float nPos, in vec2 mousePos, bool isEndless)
			{
				if(drawn_orientation==SliderOrientation.horz)
				{
					pressed_thumbMouseOfs.x = 0; 
					nPos = remap_clamp(mousePos.x, drawn_p0.x, drawn_p1.x, 0, 1); 
					if(mousePos.x<drawn_p0.x)
					pressed_thumbMouseOfs.x = drawn_p0.x-mousePos.x; 
					if(mousePos.x>drawn_p1.x)
					pressed_thumbMouseOfs.x = drawn_p1.x-mousePos.x 
						- ((isEndless)?(1):(0))/+prevent infinite incrementing+/; 
				}
				else if(drawn_orientation==SliderOrientation.vert)
				{
					pressed_thumbMouseOfs.y = 0; 
					nPos = remap_clamp(mousePos.y, drawn_p0.y, drawn_p1.y, 0, 1); 
					//Note: p1 and p0 are intentionally swapped!!!
					if(mousePos.y<drawn_p1.y)
					pressed_thumbMouseOfs.y = drawn_p1.y-mousePos.y; 
					/+
						Todo: test vertical circular slider jump to the very ends, 
						and see if not jumps to opposite si
					+/
					if(mousePos.y>drawn_p0.y)
					pressed_thumbMouseOfs.y = drawn_p0.y-mousePos.y 
						- ((isEndless)?(1):(0)); 
				}
				else { NOTIMPL; }
			} 
			
			void mouseAdjust(
				ref float nPos, in vec2 mousePos, bool isClamped, bool isCircular, bool isEndless, 
				ref int wrapCnt, float adjustSpeed
			)
			{
				if(drawn_orientation==SliderOrientation.horz)
				{
					slowMouse(adjustSpeed!=1, adjustSpeed); 
					auto p = mousePos.x+pressed_thumbMouseOfs.x; 
					if(isCircular || isEndless)
					mouseMoveRelX(wrapInRange(p, drawn_p0.x, drawn_p1.x, wrapCnt)); 
					nPos = remap(p, drawn_p0.x, drawn_p1.x, 0, 1); 
					if(isClamped)
					nPos = nPos.clamp(0, 1); 
				}
				else if(drawn_orientation==SliderOrientation.vert)
				{
					slowMouse(adjustSpeed!=1, adjustSpeed); 
					auto p = mousePos.y+pressed_thumbMouseOfs.y; 
					if(isCircular || isEndless)
					mouseMoveRelY(wrapInRange(p, drawn_p0.y, drawn_p1.y, wrapCnt)); 
					nPos = remap(p, drawn_p0.y, drawn_p1.y, 0, 1); 
					if(isClamped)
					nPos = nPos.clamp(0, 1); 
				}
				else if(drawn_orientation==SliderOrientation.round)
				{
					auto diff = rawMousePos-pressed_rawMousePos; 
					auto act_dir = abs(diff.x)>abs(diff.y) ? 1 : 2; 
					if(lockedDirection==0 && length(diff)>=3)
					lockedDirection = act_dir; 
					
					const omniDirection = true; //right or up is the positive side
					const delta = 
						((omniDirection)?(inputs.MXraw.delta -inputs.MYraw.delta) :(((((lockedDirection)?(lockedDirection) :(act_dir))==1) ?(inputs.MXraw.delta):(-inputs.MYraw.delta)))); 
					
					pressed_nPos += delta*(adjustSpeed*(1.0f/180)); 
					//it adds small delta's, so it could be overdriven
					
					pressed_nPos = pressed_nPos.clamp(0, 1); 
					nPos = pressed_nPos; 
					/+
						Todo: it can't modify npos because npos can be an integer 
						too. In this case, the pressed_nPos name is bad.
					+/
					
					//Todo: endless????
					//Todo: ha tulmegy, akkor vinnie kell magaval a base-t is!!!
					//Todo: Ctrl precizitas megoldasa globalisan az inputs.d-ben.
				}
				else { raise("Invalid orientation"); }
			} 
			
			void mouseAdjust(ref float nPos, in vec2 mousePos, in ValueRange range_, ref int wrapCnt, float adjustSpeed)
			{ mouseAdjust(nPos, mousePos, range_.isClamped, range_.isCircular, range_.isEndless, wrapCnt, adjustSpeed); } 
			
			bool handleKeyboard(ref float nPos, in ValueRange range_, float pageSize)
			{
				if(nPos.isnan)
				return false; 
				
				bool userModified; 
				
				void set(float n)
				{
					nPos = n.clamp(0, 1); 
					userModified = true; 
				} 
				
				void delta(float scale)
				{
					//modifiers
					if(scale) {
						if(inputs.Shift) scale*=10; 
						if(inputs.Ctrl) scale/=10; 
						if(inputs.Alt) scale/=100; 
					}
					/+Todo: this layout is incompatible with the mouse Shift = slow behavior.+/
					
					auto nStep()
					{ return range_.step.ifz(1) / (range_.max-range_.min); } 
					set(nPos + nStep *scale); 
				} 
				
				const 	horz 	= drawn_orientation != SliderOrientation.vert, //round knobs are working for both
					vert 	= drawn_orientation != SliderOrientation.horz; 
				
				if(horz && inputs.Left.repeated	|| vert && inputs.Down.repeated)
				delta(-1); 
				if(horz && inputs.Right.repeated	|| vert && inputs.Up.repeated)
				delta(1); 
				version(none)
				{
					/+
						Todo: Make a forking focused control system that only sends these keys to only the focused control.
						Until that only the arrows will work.
						A mouse click somewhere else should also loce focus automatically
					+/
					if(inputs.PgDn.repeated)
					delta(-pageSize); 
					if(inputs.PgUp.repeated)
					delta(pageSize); 
					if(inputs.Home.down)
					set(0); 
					if(inputs.End .down)
					set(1); 
				}
				
				return userModified; 
			} 
			
			bool handleMouse(in Id id, in HitInfo hit, ref float nPos, in vec2 mousePos, in ValueRange range_, ref int wrapCnt)
			{
				if(nPos.isnan)
				return false; 
				
				bool userModified; 
				
				if(hit.pressed && hit.enabled)
				{
					//Todo: enabled handling
					userModified = true; 
					
					onPress(id, nPos, mousePos); 
					
					//decide wether the knob has to jump to the mouse position or not
					const doJump = .Slider.isLinear(drawn_orientation) && !drawn_thumbRect.contains!"[)"(mousePos); 
					if(doJump)
					{ jumpToPoint(nPos, mousePos, range_.isEndless); }
					
					//round knob: lock the mouse and start measuring delta movement
					if(.Slider.isRound(drawn_orientation))
					{
						//Todo: "round" knob never jumps
						mouseLock; /+
							Bug: possible bug when the slider disappears, 
							and the mouse stays locked forever
						+/
					}
				}
				
				//continuous update if active
				if(id==pressed_id)
				{
					userModified = true; 
					const adjustSpeed = 	inputs.Shift.active 	? 10 : 
						inputs.Ctrl.active 	? 0.1f : 
						inputs.Alt.active 	? 0.01f 
							: 1; //Note: this is a scaling factor...
					mouseAdjust(nPos, mousePos, range_, wrapCnt, adjustSpeed); 
				}
				
				//hit.released
				if(hit.released)
				{
					pressed_id = Id.init; 
					
					//Todo: this isn't safe! what if the control disappears!!!
					if(.Slider.isLinear(drawn_orientation))	{ slowMouse(false); }
					else	{ mouseUnlock; }
				}
				
				return userModified; 
			} 
			
		} 
		
		auto hScrollInfo = ScrollInfo('H'), vScrollInfo = ScrollInfo('V'); 
		
		static struct ScrollInfo
		{
			char orientation; 
			
			static struct ScrollInfoRec
			{
				Id id; 
				.Container container; //contains id
				uint lastAccess; //to purge the old ones
				
				//current parameters for the scrollbar
				float contentSize=0, pageSize=0; //only valid if container has the has[H/V]ScrollBar flag.
				
				//persistent data
				float offset=0; 
				.Slider slider; 
			} 
			
			protected ScrollInfoRec[Id] infos; 
			
			void dump()
			{
				print("-".replicate(40), orientation.to!string.lc~"ScrollInfo dump"); 
				infos.values.each!print; 
			} 
			
			auto getScrollBar(in Id id)
			{
				if(auto p = id in infos)
				return (*p).slider; else
				return null; 
			} 
			
			auto getScrollOffset(in Id id)
			{
				 //Opt: Should combine get offset and getScrollBar
				if(auto p = id in infos)
				return (*p).offset; else
				return 0; 
			} 
			
			//1. called from measure() when it decided the scrollbars needed
			auto update(.Container container, float contentSize, float pageSize)
			in(container)
			in(container.id!=Id.init)
			{
				infos.findAdd(
					container.id, ((ref ScrollInfoRec info){
						info.container	= container,
						info.id	= container.id,
						info.contentSize	= contentSize,
						info.pageSize	= pageSize,
						info.lastAccess	= application.tick; 
					})
				); 
			} 
			
			/+
				2. called after measure when the final local positions are known. 
					It creates the bars if needed and registers them with hitTestManager
			+/
			void createBars(bool doPurge)
			{
				assert(orientation.among('H', 'V')); 
				
				Id[] toRemove; 
				foreach(id, ref info; infos)
				{
					if(info.lastAccess<application.tick)
					{
						if(doPurge) toRemove ~= id; 
						continue; 
					}
					const exists 	= (orientation=='H' && info.container.flags._hasHScrollBar)
						|| (orientation=='V' && info.container.flags._hasVScrollBar); 
					if(!exists) continue; 
					
					bool enabled; 
					float normValue; 
					float normThumbSize; 
					float activeRange = info.contentSize - info.pageSize; 
					
					const flip = orientation=='V'; 
					void doFlip() { if(flip) normValue = 1-normValue; } 
					
					if(activeRange > 0.001f)
					{
						//restrict range
						info.offset.minimize(activeRange); 
						info.offset.maximize(0); 
						
						enabled = true; 
						normValue = info.offset/activeRange; 
						normThumbSize = info.pageSize/info.contentSize; 
						
						doFlip; 
					}
					else
					{
						info.offset = 0; //no active range, so just reset it to 0
					}
					//inherit container's target surface
					im.selectTargetSurface(info.container.flags.targetSurface); 
					
					const bool userModified = im.Slider
						(
						normValue, linRange(0, 1), ((combine(info.container.id, orientation)).名!q{id}),
						((orientation=='H')?(SliderOrientation.horz):(SliderOrientation.vert)),
						SliderType.scrollBar, ((normThumbSize).名!q{normThumbSize}),
						((
							{
								//set the position of the slider.
								const scrollThickness = DefaultScrollThickness; 
								with(info.container)
								if(orientation=='H')
								{
									im.outerPos = vec2(0, innerHeight-scrollThickness); 
									im.outerSize = vec2(innerWidth-((flags._hasVScrollBar) ?(scrollThickness):(0)), scrollThickness); 
								}
								else
								{
									im.outerPos = vec2(innerWidth-scrollThickness, 0); 
									im.outerSize = vec2(scrollThickness, innerHeight-((flags._hasHScrollBar) ?(scrollThickness):(0))); 
								}
							}
						).名!q{init})
					); 
					info.slider = (cast(.Slider)(removeLastContainer)); 
					
					if(userModified && enabled)
					{
						doFlip; 
						info.offset = normValue*activeRange; 
					}
				}
				
				//purge old ones
				foreach(id; toRemove) infos.remove(id); 
			} 
		} 
		
		version(/+$DIDE_REGION Flash meggages+/all)
		{
			///Brings up an error message on the center of the screen for a short duration
			static struct FlashMessage
			{
				DateTime when; 
				enum Type { info, warning, error, exception} 
				Type type; 
				string msg; 
				int count=1; 
				
				RGB color() const
				{
					with(Type)
					final switch(type)
					{
						case info: 	return clWhite; 
						case warning: 	return clYellow; 
						case error, exception: 	return clRed; 
					}
				} 
				
				RGB fontColor() const
				{
					if(type==Type.exception) return clYellow; 
					return blackOrWhiteFor(color); 
				} 
			} 
			
			FlashMessage[] flashMessages; 
			
			protected void appendMessage(FlashMessage.Type type, string msg, int count)
			{
				enum maxLen = 10; 
				if(flashMessages.length>maxLen)
				flashMessages = flashMessages[$-maxLen..$]; 
				flashMessages ~= FlashMessage(now, type, msg, count); 
				
				with(FlashMessage.Type)
				final switch(type)
				{
					case error, exception: 	winSnd("Windows Critical Stop"); 	break; 
					case warning: 	if(count==1) winSnd("Windows Default"); 	break; 
					case info: 	if(count==1) winSnd("Windows Information Bar"); 	
				}
			} 
			
			void flashMessage(FlashMessage.Type type, string msg)
			{
				if(msg=="") return; 
				
				//duplicated item
				auto count = 1; 
				
				const duplicatedIdx = flashMessages.countUntil!((m)=>(m.type==type && m.msg==msg)); 
				if(duplicatedIdx>=0)
				{
					auto duplicatedItem = flashMessages[duplicatedIdx]; 
					count = duplicatedItem.count+1; 
					flashMessages = flashMessages.remove(duplicatedIdx); 
				}
				
				appendMessage(type, msg, count); 
			} 
			
			void flashMessage(FlashMessage.Type type, string prefix, string msg)
			{
				if(prefix=="") return; 
				
				const duplicatedIdx = flashMessages.countUntil!((m)=>(m.msg.startsWith(prefix))); 
				DateTime when = now; 
				if(duplicatedIdx>=0)
				{
					when = flashMessages[duplicatedIdx].when; 
					flashMessages = flashMessages.remove(duplicatedIdx); 
				}
				
				appendMessage(type, prefix~msg, 0/+clear counter, the status itself will be the signal.+/); 
				
				if(flashMessages.length) flashMessages.back.when = when; 
			} 
			
			void flashInfo(string msg)
			{ flashMessage(FlashMessage.Type.info, msg); } 	void flashInfo(string prefix, string msg)
			{ flashMessage(FlashMessage.Type.info, prefix, msg); } 
			void flashWarning(string msg)
			{ flashMessage(FlashMessage.Type.warning, msg); } 	void flashWarning(string prefix, string msg)
			{ flashMessage(FlashMessage.Type.warning, prefix, msg); } 
			void flashError(string msg)
			{ flashMessage(FlashMessage.Type.error, msg); } 	void flashError(string prefix, string msg)
			{ flashMessage(FlashMessage.Type.error, prefix, msg); } 
			
			void flashException(string msg)
			{ flashMessage(FlashMessage.Type.exception, msg); } 
			
			enum flashMessageDuration = 4*second; 
			
			private bool flashMessagesInvoked; 
			
			private void updateFlashMessages_internal_onEndFrame()
			{
				const t = now-flashMessageDuration; 
				flashMessages = flashMessages.remove!(a => a.when<t); 
				
				if(!flashMessagesInvoked)
				UI_FlashMessages; 
				flashMessagesInvoked = false; 
			} 
			
			void UI_FlashMessages()
			{
				flashMessagesInvoked = true; 
				//Note: User can call it wherever, but if not, it will drawn automatically.
				with(im) {
					if(flashMessages.empty) return; 
					Panel(
						DockAlignment.bottomCenter, 
						{
							background = clWhite; 
							style.bold = true; 
							foreach(m; flashMessages)
							Row(
								{
									style.bkColor = m.color; 
									style.fontColor = m.fontColor; 
									
									if(m.type == FlashMessage.Type.error)
									style.fontColor = mix(style.fontColor, style.bkColor, blink^^2); 
									
									padding = "4 24"; 
									rowFlags.hAlign = HAlign.center; 
									const 	tIn = (now-m.when).value(.5f*second),
										tOut = (m.when+flashMessageDuration-now).value(.25f*second); 
									
									fh = DefaultFontHeight*1.68f 	* (tIn<1 ? easeOutElastic(tIn.clamp(0, 1), 0, 1, 1) : 1)
										* (tOut<1 ? easeOutQuad(tOut.clamp(0, 1), 0, 1, 1) : 1); 
									
									const s = m.msg ~ (m.count>1 ? m.count.format!" (x%d)" : ""); 
									Text(s); 
								}
							); 
						}
					); 
				}
			} 
		}
	}
	version(/+$DIDE_REGION+/all) {
		version(/+$DIDE_REGION internal state+/all)
		{
			.DockSite rootContainer; 
			
			ref rootCells() => rootContainer.subCells; 
			
			auto rootContainers(bool forceAll)
			{
				auto res = rootCells.map!((c)=>((cast(.Container)(c)))).filter!"a".array; 
				if(forceAll)
				enforce(rootCells.length == res.length, "FATAL ERROR: All of rootCells[] must be non null and a descendant of Container."); 
				return res; 
			} 
			
			//double QPS=0, lastQPS=0, dt=0;
			//Todo: ez qrvara megteveszto igy, jobb azonositokat kell kitalalni QPS helyett
			
			//Todo: ezt egy alias this-el egyszerusiteni. Jelenleg az im-ben is meg az im.StackEntry-ben is ugyanaz van redundansan deklaralva
			.Container thisContainer, lastContainer; //top of the containerStack for faster access
			auto thisRow()
			=> (cast(.Row)(thisContainer)); auto thisColumn()
			=> (cast(.Column)(thisContainer)); auto thisDockSite()
			=> (cast(.DockSite)(thisContainer)); 
			
			auto thisId()
			=> thisContainer.id; 
			
			bounds2 thisOuterBounds()
			{
				if(thisContainer)
				{
					thisContainer.flags._saveOuterBounds = true; 
					return imstOuterBounds(thisContainer.id); 
				}
				return typeof(return).init; 
			} 
			
			.Container parentContainer()
			{
				if(stack.length<2) enforce(0, "im.Stack underflow."); 
				return stack[$-2].container; 
			}  auto parentDockSite()
			=> (cast(.DockSite)(parentContainer)); 
			
			auto subCells()
			=> thisContainer.subCells; 
			auto subCells(T : .Cell)()
			=> thisContainer.subCells.map!((c)=>((cast(T)(c)))).filter!((c)=>(c !is null)); 
			auto subContainers()
			=> thisContainer.subContainers; 
			
			Cell[] siblingCells()
			{
				auto p = parentContainer; 
				return ((p)?(p.subCells):(rootCells)); 
			} 
			
			Cell prevSiblingCell()
			{
				auto siblings = siblingCells; 
				enforce(siblings.length>=2 && siblings.back is thisContainer, "siblingCells() broken."); 
				return siblings[$-2]; 
			} 
			
			private
			{
				/+Foc convinience inside the template.+/
				void imBeforeDock(in DockAlignment dockAlignment)
				{
					if(dockAlignment) {
						if(auto ds = parentDockSite) ds.beforeDock(thisContainer, dockAlignment); 
						else WARN("ParentDockSite is null, unable to dock."); 
					}
				} 
				void imAfterDock(in DockAlignment dockAlignment)
				{
					if(dockAlignment) {
						if(auto ds = parentDockSite) ds.afterDock(thisContainer, dockAlignment); 
						else WARN("ParentDockSite is null, unable to dock."); 
					}
				} 
			} 
			
			
			TextStyle textStyle;   alias style = textStyle; //Todo: style.opDispatch("fontHeight=0.5x")
			
			enum Theme: ubyte
			{
				reset, 
				noTool, 	tool,
				noWhite, 	white
			} 
			
			static struct ThemeState
			{
				mixin((
					(表([
						[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
						[q{bool},q{1},q{"isTool"},q{},q{/+Smaller controls that exactly fit info a row of text.+/}],
						[q{bool},q{1},q{"isWhite"},q{},q{/+Buttons are white, not grey.+/}],
					]))
				).調!(GEN_bitfields)); 
				
				void reset() { this = ThemeState.init; } 
				void tool() { isTool = true; } 	void noTool() { isTool = false; } 
				void white() { isWhite = true; } 	void noWhite() { isWhite = false; } 
				
				
				void set(Theme t)
				{
					if(!t) reset; 
					else
					{
						ref val = *(cast(ubyte*)(&this)); 
						const i = (cast(int)(t))-1; 
						val = (cast(ubyte)(((i&1)?(val.setBit(i/2)) :(val.clearBit(i/2))))); 
					}
				} 
			} 
			
			ThemeState theme; 
			
			MouseCursor mouseCursor; 
			
			
			private static struct StackEntry
			{ .Container container; TextStyle textStyle; ThemeState theme; } 
			private StackEntry[] stack; 
			
			
			void imReset()
			{
				//statck reset
				_incomingId = Id.init; 
				textStyle = tsNormal; 
				theme.clear; 
				mouseCursor = MouseCursor.DEFAULT; 
				drawCallbacks.clear; 
				stack = []; 
				
				rootContainer = new .DockSite; 
				imPush(rootContainer, Id.init); 
			} 
			
			public void imPush(T : .Container)(T c, in Id newId)
			{
				//Todo: ezt a newId-t ki kell valahogy valtani. im.id-t kell inkabb modositani.
				c.id = newId; 
				c.flags.targetSurface = selectedTargetSurface; 
				
				stack ~= StackEntry(c, textStyle, theme); 
				
				//thisContainer is the top of the stack or null
				thisContainer = c; 
			} 
			
			public void imPop()
			{
				enforce(stack.length>1); //stack[0] is always null and it is never popped.
				
				//restore	the last textStyle & theme. Changes inside a subHierarchy doesn't count.
				textStyle = stack.back.textStyle; 
				theme = stack.back.theme; 
				
				stack.popBack; 
				
				//save lastContainer here.
				lastContainer = thisContainer; 
				
				//thisContainer is the top of the stack or null
				thisContainer = stack.empty ? null : stack.back.container; 
				//Todo: the first stack container is always 0.
			} 
			
			void imDump()
			{
				writeln("---- IM dump --------------------------------"); 
				foreach(cell; rootCells) cell.dump; 
				writeln("---- End of IM dump -------------------------"); 
			} 
			
			/+
				270804: removed. It was only used in Chapter, this and also the stack artray must go.
				In the future, stact will be replaced with the actual stack.
				
				private auto find(C:.Container)()
				{
					foreach_reverse(ref s;stack)
					if(auto r = cast(C)(s.container))
					return r; 
					return null; 
				} 
			+/
			
			public void imAppend(T)(T c)
			{
				/+Only appends non-nulls.+/
				if(thisContainer !is null)	thisContainer.append(c); 
				else	{ if(c) rootCells ~= c; }
			} 
			
			.Container removeLastContainer()
			{
				//needed for temporary composable building
				return thisContainer 	? thisContainer.removeLastContainer
					: (cast(.Container)(rootCells.fetchBack)); 
			} 
			
			version(/+$DIDE_REGION DrawCallback+/all)
			{
				alias DrawCallback = void delegate(Drawing, .Container); 
				
				private DrawCallback[.Container] drawCallbacks; 
				
				void addDrawCallback(DrawCallback fun)
				{
					enforce(thisContainer !is null); 
					enforce(
						!thisContainer.flags._hasDrawCallback, 
							"Container already has a DrawCallback."
					); 
					
					thisContainer.flags._hasDrawCallback = true; 
					drawCallbacks[thisContainer] = fun; 
				} 
				
				private auto getDrawCallback(.Container cntr)
				{
					if(auto cb = cntr in drawCallbacks)
					return *cb; 
					else return null; 
				} 
			}
			
			
			
			
			
			
			@property
			{
				//must use `im` prefixes because these are dangerously common identifier names.
				
				bool imFocused()
				=> ((thisContainer)?(thisContainer.flags.focused):(false)); 
				
				bool imEnabled()
				=> ((thisContainer)?(thisContainer.flags.enabled):(true/+empty root is always enabled+/)); 
				bool imEnabled(bool a)
				{ if(thisContainer) thisContainer.flags.enabled = a; return a; } 
				
				bool imSelected()
				=> ((thisContainer)?(thisContainer.flags.selected):(false)); 
				bool imSelected(bool a)
				{ if(thisContainer) thisContainer.flags.selected = a; return a; } 
			} 
			
			@property
			{
				float fh()
				=> textStyle.fontHeight; 
				float fh(float v)
				{ textStyle.fontHeight = cast(ubyte)(v.iround); return v; } 
			} 
			
			
			//container delegates
			
			private auto _ContainerProp(string name)
			=> q{
				auto #()
				=> thisContainer.#; auto #(typeof(thisContainer.#) val)
				{ thisContainer.# = val; return val; } 
			}.replace("#", name); 
			private auto _ContainerRef(string name)
			=> q{
				ref auto #()
				=> thisContainer.#; 
			}.replace("#", name); 
			@property
			{
				mixin(
					[
						"innerPos", "innerX", "innerY",
						"innerSize", "size", 
						"innerWidth", "width", 
						"innerHeight", "height"
					].map!_ContainerProp.join ~
					[
						"outerPos", "outerX", "outerY", "pos", 
						"outerSize", "outerWidth", "outerHeight", 
						"flags", "flex", "margin", "border", "padding", 
						/+"bkColor" removed: 260815+/
					].map!_ContainerRef.join
				); 
			} 
			
			@property
			{
				ref auto rowFlags()
				=> thisRow.rowFlags; ref auto colFlags()
				=> thisColumn.colFlags; 
				
				
				@property background()
				=> thisContainer.bkColor; 
				
				@property background(RGB a)
				{ thisContainer.bkColor = a; style.bkColor = a; return a; } 
				
				@property ref bg()
				=> style.bg; 
				
				@property ref fg()
				=> style.fg; 
			} 
			
			
			/+
				Todo: Play with disabled inlining of Composable functions: /+Code: pragma(inline, false)+/
				It requires an ASM inspector first.
				Also I can try put _incomingId on the `im` scope too, so the parameters can remain the same.
			+/
			
			private
			{
				/+Todo: 260812 I think the first parameter of _container is enough. This is just overcomplication.+/
				
				Id _incomingId; //This must be loaded from __MODULE__ and __LINE__ before Container creation.
				
				enum Debug_incomingId 	= (常!(bool)(0)),
				Log_incomingId 	= (常!(bool)(0)); 
				
				/+
					AI: /+User: One traditional Chinese Unicode character that represents the English word: id?+/
					/+
						Assistant: /+
							Para: 它 (tā) — meaning "it" — is the traditional Chinese Unicode character that literally corresponds
							to the Latin word /+Italic: id+/ (the pronoun "it"). In psychology, /+Italic: id+/ is conventionally rendered as /+Bold: 本我+/
							(two characters), but if a single character is required, /+Bold: 它+/ is the closest direct translation.
						+/
						
						/+Note: Usage(prompt_hit: 128, prompt_miss: 204, completion: 1419, HUF: 0.26, price: 200%)+/
					+/
				+/
				
				public void setIncomingId(string srcModule, size_t srcLine)()
				{
					static if(Debug_incomingId) enforce(!_incomingId, "_incomingId already set."); 
					_incomingId = Id(srcModule, srcLine); 
				} 
				
				public auto fetchIncomingId()
				{
					static if(Debug_incomingId) enforce(_incomingId, "_incomingId not set."); 
					auto res = _incomingId; 
					static if(Debug_incomingId) _incomingId = Id.init; 
					static if(Log_incomingId) LOG(res); 
					return res; 
				} 
			} 
			
			version(/+$DIDE_REGION Build functions+/all)
			{
				//Note: build* functions are only callable from update()
				
				//Build an array of cells using a temporary container
				Cell[] buildCells(
					string _M_=__MODULE__, 
					size_t _L_=__LINE__, Args...
				)(in Args args)
				{
					Container!(.Container, _M_, _L_)(args); 
					return removeLastContainer.subCells; 
				} 
				
				auto buildContainer(
					CType : .Container, 
					string _M_=__MODULE__, 
					size_t _L_=__LINE__, Args...
				)(in Args args)
				{
					Container!(CType, _M_, _L_)(args); 
					return (cast(T)(removeLastContainer)); 
				} 
				
				auto buildRow(
					string _M_=__MODULE__, 
					size_t _L_=__LINE__, Args...
				)(in Args args)
				{ return buildContainer!(.Row   , _M_, _L_)(args); } 
				auto buildColumn(
					string _M_=__MODULE__, 
					size_t _L_=__LINE__, Args...
				)(in Args args)
				{ return buildContainer!(.Column, _M_, _L_)(args); } 
			}
		}
		
		enum StdPropertyDefs = 
		(表([
			[q{//Properties (set only once at creation)
			}],
			[q{isG!"id"},q{/+already handled+/}],
			[q{isG!"init"},q{a(); }],
			[q{isT!YAlign},q{rowFlags.yAlign = a; }],
			[q{isT!HAlign},q{rowFlags.hAlign = a; }],
			[q{isT!VAlign},q{rowFlags.vAlign = a; }],
			[q{isT!Theme},q{theme.set(a); }],
			[q{isG!"padding" || isT!Padding},q{padding = a; }],
			[q{isG!"border" || isT!Border},q{border = a; }],
			[q{isG!"margin" || isT!Margin},q{margin = a; }],
			[q{isG!"background"},q{background = a; }],
			[q{isG!"outerWidth"},q{outerWidth = a; }],
			[q{isG!"outerHeight"},q{outerHeight = a; }],
			[q{isG!"outerSize"},q{outerSize = a; }],
			[q{isG!"innerWidth"},q{innerWidth = a; }],
			[q{isG!"innerHeight"},q{innerHeight = a; }],
			[q{isG!"innerSize"},q{innerSize = a; }],
			[q{isT!RGB},q{style.fg = a; }],
			[q{isG!"flex"},q{flex = a; }],
			[q{isG!"enabled"},q{imEnabled = a; }],
			[q{isG!"selected"},q{imSelected = a; }],
		])),
		
		StdCompositionDefs = 
		(表([
			[q{//Composition updates (can be changed any time)
			}],
			[q{isT!TextStyle},q{textStyle = a; }],
			[q{isG!"style"},q{textStyle.modify(a); }],
			[q{isG!"syntax" || isT!SyntaxKind},q{textStyle.applySyntax(a.to!SyntaxKind); }],
			[q{isG!"fg"},q{style.fontColor = a; }],
			[q{isG!"bg"},q{style.bkColor = a; }],
			[q{isG!"bold"},q{style.bold = a; }],
			[q{isG!"italic"},q{style.italic = a; }],
			[q{isG!"underline"},q{style.underline = a; }],
			[],
			[q{/+Emitters /+Todo: It should not inject editable chars Edit!+/+/}],
			[q{isSomeString!T},q{Text(a); }],
			[q{is(T : Cell)},q{imAppend(cast()a); }],
			[q{is(T : const(Cell)[])},q{imAppend(cast(Cell[])a); }],
			[q{__traits(compiles, a())},q{a(); }],
			[],
			[q{/+
				Todo: Read about undefined behaior when casting away consts.
				In the parameters, const is maybe more efficient if the compiler 
				does not analyze variable usage patterns.
				ASM viewer needed.
				/+Link: https://www.jmdavisprog.com/articles/why-const-sucks.html+/
			+/}],
		])); 
		
		mixin template ContainerScript_Init(CType_, string optionsStr_, 表 props, 表 comps)
		{
			alias CType = CType_; 
			alias SCR = ContainerScript!(optionsStr_); 
			enum CustomPropertyDefs = props; 
			enum CustomCompositionDefs = comps; 
			/+Statement mixin can't go here, because mixin()  can only emit declarations.+/
		} 
		
		void imApply(Args...)(in Args args)
		{
			enum AllRows = chain(StdPropertyDefs.rows, StdPropertyDefs.rows).array; 
			static foreach(a; args)
			{
				{
					alias T = typeof(cast()a); enum isT(Type) 	= is(T == Type),
					isG(string Name) 	= isGenericArg!(T, Name); 
					mixin(
						AllRows.map!((r)=>(iq{static if($(r[0])) {$(r[1])}}.text)).join(q{ else })
						~q{else static assert(0, "Unsupported type: "~T.stringof); }
					); 
				}
			}
		} 
		
		template ContainerScript(string optionsStr)
		{
			enum ThisStr = "ContainerScript!(`"~optionsStr~"`)"; 
			enum Option {dockAlignment, hit, key, focus, hint, range, spaceKey} 
			
			enum options = optionsStr.split(' ').map!(to!Option).array; 
			
			string OPT(string optionStr)(string sTrue, string sFalse="")
			{ return ' ' ~ ((options.canFind(optionStr.to!Option))?(sTrue):(sFalse)) ~ ' '; } 
			
			string Create() /+Note: Step 1.+/ /+Use ContainerScript_Init!+/
			=> iq{
				auto _id = combine(thisContainer.id, fetchIncomingId); 
				static foreach(a; args) static if(isGenericArg!(typeof(cast()a), "id")) _id.appendIdx(a.value); 
				
				const parentEnabled = imEnabled; //Inherit `enabled` from parent.
				
				auto _container = new CType; 
				imAppend(_container); imPush(_container, _id); scope(exit) imPop; 
				imEnabled = parentEnabled; //Inherit `enabled` from parent.
				_container.bkColor = style.bkColor; //Inherit `bkcolor` from the current fontStyle.
				
				$(OPT!"dockAlignment"(q{DockAlignment dockAlignment; }))
				$(OPT!"focus"       (q{bool mustEnterFocus, mustExitFocus, focusMMB, focusRMB, focusMW; }))
				$(OPT!"hint"        (q{HintRec hintRec; }))
				$(OPT!"range"      (q{ValueRange range; }))
			}.text; 
			
			/+/+Note: Step 2.+/ Declare local variables to load properties into.+/
			
			string ProcessProperties() /+Note: Step 3.+/
			=> iq{
				enum AllPropertyDefRows = CustomPropertyDefs.rows.array 
				$(OPT!"dockAlignment"(q{~(表([[q{isT!DockAlignment},q{dockAlignment = a; }],])).rows.array}))
				$(
					OPT!"focus"       (
						q{
							~(表([
								[q{isG!"enter"},q{mustEnterFocus |= a; }],
								[q{isG!"exit"},q{mustExitFocus |= a; }],
							])).rows.array
						}
					)
				)
				$(OPT!"hint"        (q{~(表([[q{isT!HintRec},q{hintRec = cast()a; }],])).rows.array}))
				$(OPT!"range"      (q{~(表([[q{isT!ValueRange},q{range = a; }],])).rows.array}))
				$(OPT!"key"        (q{~(表([[q{isG!"key" || isT!KeyCombo},q{/+handled after props+/}],])).rows.array}))
				~ StdPropertyDefs.rows.array; 
				
				static foreach(a; args)
				{
					{
						alias T = typeof(cast()a); enum isT(Type) 	= is(T == Type),
						isG(string Name) 	= isGenericArg!(T, Name); 
						mixin(AllPropertyDefRows.map!((r)=>(iq{static if($(r[0])) {$(r[1])}}.text)).join(q{ else })); 
					}
				}
				
				$(OPT!"dockAlignment"(q{imBeforeDock(dockAlignment); scope(exit) imAfterDock(dockAlignment); }))
				$(OPT!"hit"(q{auto hit = hitTest(_container); }))
				$(
					OPT!"key" /+Must be after `hit` and before `focus`.+/
					(
						q{
							static foreach(a; args)
							{
								{
									alias T = typeof(cast()a); enum isT(Type) 	= is(T == Type),
									isG(string Name) 	= isGenericArg!(T, Name); 
									static if(isG!"key" || isT!KeyCombo)
									{ if(canProcessUserInput) hit.simulateKey(KeyCombo(cast()a)); }
								}
							}
						}
					)
				)
				$(
					OPT!"focus"
					(
						q{
							mustEnterFocus |= (
								imEnabled && canProcessUserInput && hit.hover &&
								(
									(focusRMB && inputs.RMB.pressed) ||
									(focusMMB && inputs.MMB.pressed) ||
									(focusMW && inputs.MW.delta)
								)
							); 
							const focused = focusUpdate(
								_container, _id, 
								imEnabled && canProcessUserInput,
								mustEnterFocus || hit.pressed,
								mustExitFocus || inputs.Esc.pressed
							); 
						}
					)
				)
				$(OPT!"hint"(q{handleHint(_container, hintRec, hit); }))
				$(
					OPT!"spaceKey" /+Must be after `hit` and `focus`.+/
					(
						q{
							if(focused && canProcessDialogKeys)
							{ hit.simulateKey(KeyCombo("Space")); }
						}
					)
				)
			}.text; 
			
			/+/+Note: Step 4.+/ Implement custom behavior based on properties.+/
			
			string ProcessComposition() /+Note: Step 5.+/
			=> iq{
				enum AllCompositionDefRows = CustomCompositionDefs.rows.array ~ StdCompositionDefs.rows.array; 
				static foreach(a; args)
				{
					{
						alias T = typeof(cast()a); enum isT(Type) 	= is(T == Type),
						isG(string Name) 	= isGenericArg!(T, Name); 
						mixin(
							chain(
								AllPropertyDefRows.map!((r)=>(iq{static if($(r[0])) {}}.text)),
								AllCompositionDefRows.map!((r)=>(iq{static if($(r[0])) {$(r[1])}}.text))
							)
							.join(q{ else })
							~q{else static assert(0, "Unsupported type: "~T.stringof); }
						); 
					}
				}
			}.text; 
			
			/+/+Note: Step 6.+/ Finalize/deallocate temporary things, measure nested content, etc.+/
		} 
		
	}
	version(/+$DIDE_REGION+/all)
	{
		
		
		
		
		
		private void _Container(CType_, Args...)(in Args args)
		{
			version(/+$DIDE_REGION Create a new CustomContainer instance+/all)
			{
				mixin ContainerScript_Init!(CType_, q{dockAlignment}, (表([[],])), (表([[],]))); 
				mixin(SCR.Create); 
			}
			
			version(/+$DIDE_REGION Local variable declarations+/all)
			{}
			
			version(/+$DIDE_REGION Load all properties+/all)
			{ mixin(SCR.ProcessProperties); }
			
			version(/+$DIDE_REGION Do custom behavior+/all)
			{}
			
			version(/+$DIDE_REGION Handle the recursive composition+/all)
			{ mixin(SCR.ProcessComposition); }
			
			version(/+$DIDE_REGION Return custom results+/all)
			{ return; }
		} 
		
		void Container(CType=.Container, string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		{
			setIncomingId!(_M_, _L_)(); 
			return _Container!(CType)(args); 
		} 
		
		void Row(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		{
			setIncomingId!(_M_, _L_)(); 
			return _Container!(.Row)(args); 
		} 
		
		void Column(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		{
			setIncomingId!(_M_, _L_)(); 
			return _Container!(.Column)(args); 
		} 
		
		void Flex(float value = 1)
		{ Row(((value).名!q{flex})); } 
		
		private void SpacerRow(Args...)(float size, in Args args)
		{
			const vert = (cast(.Row)(thisContainer)) !is null; 
			Row(
				args, {
					if(vert) { innerWidth = size; rowFlags.yAlign = YAlign.stretch; }
					else {
						innerHeight = size; 
						/+width is auto by default. A Column will stretch it properly.+/
					}
				}
			); 
		} 
		
		void Spacer(Args...)(in Args args)
		{
			float size; 
			static if(args.length && isNumeric!(Args[0]))	{
				size = args[0]; 
				enum argStart = 1; 
			}
			else	{ enum argStart = 0; }
			if(isnan(size)) size = fh*.5f; 
			
			SpacerRow(size, args[argStart..$]); 
		} 
		
		void HR()
		{
			SpacerRow(
				fh*InvDefaultFontHeight, {
					margin = "0.33333x 0"; 
					background = mix(style.bkColor, style.fontColor, 0.25f); 
				}
			); 
		} 
		
		void HLine()
		{ Row({ innerHeight = 1; background = mix(clWinBackground, clWinText, .25f); }); } 
		void Panel(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		{ Panel!(.Column, _M_, _L_, Args)(args); } 
		void PanelRow(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		{ Panel!(.Row, _M_, _L_, Args)(args); } 
		void Panel(CType, string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		{
			setIncomingId!(_M_, _L_)(); 
			_Container!(CType)
			(
				{
					padding = "3"; border = "6 normal silver"; 
					with(border) inset = true, style = BorderStyle.fullFilletOut, borderFirst = true; 
					flags.noBackground = true; 
				}
				, args
			); 
		} 
		
		void Grp(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)
			(void delegate() fun, in Args args)
		{ Grp!(Column, _M_, _L_, Args)(fun, args); } 
		void GrpRow(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)
			(void delegate() fun, in Args args)
		{ Grp!(Row, _M_, _L_, Args)(fun, args); } 
		void Grp(alias Cntr, string _M_=__MODULE__, size_t _L_=__LINE__, Args...)
			(void delegate() fun, in Args args)
		{
			Cntr(
				((Id(_M_, _L_)).名!q{id}),
				{
					border = "2 normal silver"; padding = "2 4"; margin = "2 4"; 
					fun(); 
				}, args
			); 
		} 
		
		void Grp(string _M_=__MODULE__, size_t _L_=__LINE__, T, Args...)
			(T title, void delegate() fun, in Args args)
		{ Grp!(Column, _M_, _L_, T, Args)(title, fun, args); } 
		void GrpRow(string _M_=__MODULE__, size_t _L_=__LINE__, T, Args...)
			(T title, void delegate() fun, in Args args)
		{ Grp!(Row, _M_, _L_, T, Args)(title, fun, args); } 
		void Grp(alias Cntr, string _M_=__MODULE__, size_t _L_=__LINE__, T, A...)
			(T title, void delegate() fun, in A args)
		{
			Container!GrpContainer
			(
				{
					Row({ padding.left+=fh/4; padding.right+=fh/4; }, title); 
					lastContainer.outerPos.x = fh/2; 
					lastContainer.measure; 
					const hh = lastContainer.outerHeight; 
					
					Grp!(Cntr, _M_, _L_)
					(
						{
							margin.top += (hh*(3/8.0f)).iround; 
							padding.top = max(padding.top, hh-margin.top-border.width); 
							fun(); 
						}, args
					); 
					
					with(thisContainer) swap(subCells[0], subCells[1]); /+Correct Z-Order+/
				}
			); 
		} 
		
		
		private
		{
			SplitterState splitterState; 
			struct SplitterState
			{
				vec2 startMousePos; 
				float startTargetSize = 0; 
				Id draggedSplitterId; 
			} 
		} 
		
		///Splitter is a thin stripe shaped container used to resize other containers.
		bool Splitter(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)
		(ref float targetSize, float targetMinSize, float targetMaxSize, in Args args)
		{
			setIncomingId!(_M_, _L_)(); 
			return _Splitter(targetSize, targetMinSize, targetMaxSize, args); 
		} 
		
		private bool _Splitter(Args...)(ref float targetSize, float targetMinSize, float targetMaxSize, in Args args)
		{
			version(/+$DIDE_REGION Create a new CustomContainer instance+/all)
			{
				mixin ContainerScript_Init!(.Container, q{dockAlignment hit}, (表([[],])), (表([[],]))); 
				mixin(SCR.Create); 
			}
			
			version(/+$DIDE_REGION Local variable declarations+/all)
			{}
			
			version(/+$DIDE_REGION Load all properties+/all)
			{ mixin(SCR.ProcessProperties); }
			
			version(/+$DIDE_REGION Do custom behavior+/all)
			{
				const 	isHorz 	= !!dockAlignment.among(mixin(舉!((DockAlignment),q{leftClient})), mixin(舉!((DockAlignment),q{rightClient}))),
					isVert 	= !!dockAlignment.among(mixin(舉!((DockAlignment),q{topClient})), mixin(舉!((DockAlignment),q{bottomClient}))); 
				enforce(
					isHorz || isVert, 
					"Splitter: invalid panelPosition: `"~dockAlignment.text~"`"
				); 
				
				const siz = fh/6; 
				if(isHorz) outerWidth = siz; if(isVert) outerHeight = siz; 
				
				with(splitterState)
				{
					auto actMousePos() => targetView.mousePos.vec2; 
					bool dragging() => draggedSplitterId == _id; 
					void setDragging(bool b) { draggedSplitterId = ((b)?(_id):(Id.init)); } 
					
					if(canProcessUserInput && hit.pressed)
					{
						startMousePos = actMousePos; 
						startTargetSize = targetSize; 
						setDragging = true; 
					}
					
					if(dragging)
					{
						if(!(canProcessUserInput && inputs.LMB.down))
						{ setDragging = false; }
						else
						{
							const ofs = actMousePos - startMousePos; 
							float a = startTargetSize; 
							with(DockAlignment)
							switch(dockAlignment)
							{
								case leftClient: 	a += ofs.x; 	break; 
								case rightClient: 	a -= ofs.x; 	break; 
								default: 
							}
							targetSize = a.clamp(targetMinSize, targetMaxSize.max(targetMinSize)); 
						}
					}
					
					if(dragging || canProcessUserInput && hit.hover)
					mouseCursor = MouseCursor.SIZEWE; 
					
					background = ((dragging)?(clAccent) :(
						mix(
							clWinBackground, clWinBtnPressed, 
							hit.hover_smooth
						)
					)); 
					
					version(/+$DIDE_REGION Handle the recursive composition+/all)
					{ mixin(SCR.ProcessComposition); }
					
					version(/+$DIDE_REGION Return custom results+/all)
					{ return dragging; }
				}
			}
		} 
		
		private
		{
			static struct SplittedAreaState
			{
				bool active; 
				
				.DockSite dockSite; 
				
				bool isHorz, isVert; 
				float fullSize, totalResizableSize, totalStaticSize; 
				size_t lastDockSiteSubCellCount; 
				float minRemainingSize; 
				
				float*[] sizePtrs; 
				
				void reset()
				{ this = typeof(this).init; } 
				
				
				void beginArea()
				{
					enforce(!active, "Already inside a SplitterArea."); 
					active = true; 
					dockSite = im.thisDockSite.enforce("Resizable!Container requires a DockSite."); 
				} 
				
				float addUpSubCellSizes()
				{
					enforce(lastDockSiteSubCellCount <= dockSite.subCells.length); 
					float res = 0; 
					while(lastDockSiteSubCellCount < dockSite.subCells.length)
					{
						with(subCells[lastDockSiteSubCellCount].outerSize) res += ((isHorz)?(x):(y)); 
						lastDockSiteSubCellCount++; 
					}
					return res; 
				} 
				
				void beforeResizableContainer(in DockAlignment dockAlignment, ref float actSize)
				{
					enforce(im.thisDockSite is dockSite, "Resizable!Container's DockSite lost."); 
					
					const 	isDockAlignmentHorz 	= !!dockAlignment.among(mixin(舉!((DockAlignment),q{leftClient})), mixin(舉!((DockAlignment),q{rightClient}))),
						isDockAlignmentVert 	= !!dockAlignment.among(mixin(舉!((DockAlignment),q{topClient})), mixin(舉!((DockAlignment),q{bottomClient}))); 
					if(!(isHorz || isVert))
					{
						isHorz 	= isDockAlignmentHorz,
						isVert 	= isDockAlignmentVert; 
						enforce(
							isHorz!=isVert /+either one or another+/,
							"Invalid DockAlignment in Resizable!Container "~dockAlignment.text
						); 
						
						//Now that orientation is known, fullSize can be determined.
						with(dockSite.clientArea.size) fullSize = ((isHorz)?(x):(y)); 
						lastDockSiteSubCellCount = dockSite.subCells.length; 
						totalResizableSize = totalStaticSize = 0; 
					}
					else
					{
						enforce(
							(isHorz && isDockAlignmentHorz) || (isVert && isDockAlignmentVert),
							((isHorz)?("Horizontal"):("Vertical"))
							~" DockAlignment expected Resizable!Container "~dockAlignment.text
						); 
						totalStaticSize += addUpSubCellSizes; 
					}
					
					sizePtrs ~= &actSize; 
				} 
				
				void afterResizableContainer()
				{
					enforce(im.thisDockSite is dockSite, "Resizable!Container's DockSite lost."); 
					totalResizableSize += addUpSubCellSizes; 
				} 
				
				void endArea()
				{
					enforce(active, "Not inside SplitterArea. Nothing to end."); 
					enforce(im.thisDockSite is dockSite, "Resizable!Container's DockSite lost."); 
					
					if(const N = sizePtrs.length)
					{
						enum minRemainingSize = 32; 
						
						const 	remainingSize 	= fullSize - totalResizableSize - totalStaticSize,
							invN 	= 1.0f/N,
							minSize 	= min(minRemainingSize, fullSize * invN); 
						
						const at = calcAnimationT(deltaTime/+1.0f/60+/, .01), sd = .01f; 
						
						if(remainingSize < minSize)
						{
							const adjust = (remainingSize - minSize) * invN; 
							foreach(pSize; sizePtrs)
							{
								ref size = *pSize; 
								size.follow(size + adjust, at, sd); 
							}
						}
						
						foreach(pSize; sizePtrs)
						{
							ref size = *pSize; 
							if(size<minSize) size.follow(minSize, at, sd); 
						}
					}
					
					reset; 
				} 
			} 
		} 
		
		
		
		///Containers can dock into a DockSite, bye specifying DockAlignment.
		void DockSite(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		{
			setIncomingId!(_M_, _L_)(); 
			_DockSite(args); 
		} 
		
		void _DockSite(Args...)(in Args args)
		{
			mixin ContainerScript_Init!(.DockSite, q{dockAlignment}, (表([[],])), (表([[],]))); 
			mixin(SCR.Create); 
			mixin(SCR.ProcessProperties); 
			
			version(/+$DIDE_REGION Do custom behavior+/all)
			{
				enforce(outerSize, "DockSite's outerSize muse be specified."); 
				(cast(.DockSite)(_container)).clientArea = bounds2(0, innerSize); 
			}
			
			mixin(SCR.ProcessComposition); 
		} 
		
		///Inside a DockSite, this creates a block for Resizable!Containers.
		static void SplittedArea(void delegate() fun)
		{
			ref splittedAreaState = thisDockSite.splittedAreaState; 
			
			splittedAreaState.beginArea; 
			
			scope(exit) splittedAreaState.endArea; 
			
			fun(); 
		} 
		
		/+
			Resizable!Container can be placed inside a DockSite's SplittedArea. 
				It creates and synchronizes Splitters.
		+/
		static void Resizable(alias Cntr, string _M_=__MODULE__, size_t _L_=__LINE__, Args...)
			(in DockAlignment dockAlignment, ref float actSize, in Args args)
		{
			//Cntr: For specials Containers, make a dedicated function. Must start with _M_, _L_!
			
			ref splittedAreaState = thisDockSite.splittedAreaState; 
			
			enforce(splittedAreaState.active, "Resizable!Container called without active SplittedArea."); 
			
			splittedAreaState.beforeResizableContainer(dockAlignment, actSize); 
			scope(exit) splittedAreaState.afterResizableContainer; 
			
			const fullSize = splittedAreaState.fullSize; 
			enforce(!fullSize.isnan, "Resizable!Container's fullSize is nan."); 
			
			enum defaultSize = 32; if(actSize.isnan) actSize = defaultSize; 
			
			Cntr!(_M_, _L_)(dockAlignment, ((actSize).名!q{outerWidth}), args); 
			
			enum extraId = Id("Splitter")
			/+So the splitter id will be not the same as the content's id.+/; 
			float nextSize = actSize; 
			if(Splitter!(_M_, _L_)(nextSize, 0, splittedAreaState.fullSize, dockAlignment, ((extraId).名!q{id})))
			{
				const at = calcAnimationT(deltaTime/+1.0f/60+/, .7), sd = .01f; 
				if(!nextSize.isnan) actSize.follow(nextSize, at, sd); 
			}
			
			
		} 
		
		
		
		
		void Text(Args...)(in Args args)
		{
			//Todo: not multiline yet
			
			/+
				multiline behaviour:
					parent is Row: if multiline -> make a column around it
					parent is column: multiline is ok. Multiple row emit
					thisContainer is null: root level gets a lot of rows
					
					Text is always making one line, even in a container. Use \n for multiple rows
			+/
			
			/+
				if(Args.length>1 && !(cast(.Column)(thisContainer))(thisContainer is null || (cast(.Column)(thisContainer)) !is null))
				{/*implicit row*/Row({ Text(args); }); return; }
			+/
			
			bool restoreTextStyle = false; 
			TextStyle oldTextStyle; 
			void saveTextStyle() { if(restoreTextStyle.chkSet) oldTextStyle = textStyle; } 
			scope(exit) if(restoreTextStyle) textStyle = oldTextStyle; 
			
			void emitStr(string s)
			{
				if(thisColumn || thisContainer is rootContainer)
				{
					//implicit Rows for Column
					Row(
						{
							/+before 260812: Text(s); +/
							thisContainer.appendMarkupLine(s, textStyle); 
							//Difference: the new version can alter the style
						}
					); 
				}
				else if(auto row = thisRow)
				{ row.appendMarkupLine(s, textStyle); }
				else
				{ thisContainer.appendMarkupLine(s, textStyle); }
			} 
			
			static foreach(a; args)
			{
				{
					alias T = typeof(cast()a); 
					enum isT(Type) 	= is(T == Type),
					isG(string Name) 	= isGenericArg!(T, Name); 
					
					/+
						static if(isG!"flex")	{ Flex(a); }
						else static if(isT!TextStyle)	{ saveTextStyle; textStyle = a; }
						else static if(isT!RGB)	{ saveTextStyle; textStyle.fontColor = a; }
						else static if(isT!SyntaxKind)	{ saveTextStyle; textStyle.applySyntax(a); }
						else static if(__traits(compiles, a()))	{ a(); }
						else	{ emitStr(a.text); /+general case+/}
					+/
					
					mixin((
						(表([
							[q{isG!"flex"},q{Flex(a); }],
							[q{isT!TextStyle},q{saveTextStyle; textStyle = a; }],
							[q{isG!"style"},q{saveTextStyle; textStyle.modify(a); }],
							[q{
								isG!"fontColor" || isT!RGB
								
							},q{saveTextStyle; textStyle.fontColor = a; }],
							[q{isG!"bkColor"},q{saveTextStyle; style.bkColor = a; }],
							[q{isG!"syntax" || isT!SyntaxKind},q{saveTextStyle; textStyle.applySyntax(a); }],
							[q{isG!"bold"},q{saveTextStyle; style.bold = a; }],
							[q{isG!"italic"},q{saveTextStyle; style.italic = a; }],
							[q{isG!"underline"},q{saveTextStyle; style.underline = a; }],
							[q{__traits(compiles, a())},q{a(); }],
							[q{true},q{emitStr(a.text); /+general case+/}],
						]))
					) .GEN!q{
						rows.map!((r)=>(iq{static if($(r[0])) {$(r[1])}}.text))
						.join(q{ else })
					}); 
				}
			}
		} 
		
		auto Led(string _M_=__MODULE__, size_t _L_=__LINE__, T, Ta...)(in T param, Ta args)
		{
			float state = 0; 
			
			static if(is(T==bool))	state = param ? 1 : 0; 
			else static if(isIntegral!T)	state = param ? 1 : 0; 
			else static if(isFloatingPoint!T)	state = param.clamp(0, 1); 
			else enforce(0, "im.Led() Unhandled param type: " ~ T.stringof); 
			
			auto shp = new .Shape; 
			//set defaults
			shp.innerSize = vec2(0.7, 1)*style.fontHeight; 
			shp.color = clRainbowRed; 
			
			static foreach(a; args)
			{
				{
					alias t = Unqual!(typeof(a)); 
					static if(is(t==RGB))	shp.color = a; 
					else static if(is(t==vec2))	shp.outerSize = a; 
				}
			}
			
			shp.color = mix(clBlack, shp.color, state.remap(0, 1, 0.2f, 1)); 
			
			imAppend(cast(.Cell)shp); 
		} 
		
		string symbolStr(string def)
		{ return tag(`symbol `~def); }  void Symbol(string def)
		{ Text(symbolStr(def)); } 
		
		string boldStr(string s)	
		=> tag("style bold=1"	  )~s~tag("style bold=0"	  ); 
		string italicStr(string s)
		=> tag("style italic=1"	  )~s~tag("style italic=0"	  ); 
		string underlineStr(string s)
		=> tag("style underline=1")~s~tag("style underline=0"); 
		string strikeoutStr(string s)
		=> tag("style strikeout=1")~s~tag("style strikeout=0"); 
		
		string progressSpinnerStr(int progressStyle=0)
		{
			int t(int n)
			{ return ((QPS.value(second)*n*1.5).ifloor)%n; } 
			auto ch(int i)
			{ return [cast(dchar)i].to!string; } 
			
			switch(progressStyle)
			{
				case 0: 	return ch(0x25f4+3-t(4)); 	//◴ circle 90deg lines
				case 1: 	return ch(0x25d0+3-[0, 2, 1, 3][t(4)]); 	//◐ circle 180deg filled
				case 2: 	return ch(0x1f550+t(12)); 	//🕐 clock
				default: 	return "..."; 
			}
		} 
		
		void ProgressSpinner(int progressStyle = 0)
		{
			Row(
				{
					style.fontColor = mix(style.bkColor, style.fontColor, .66f); 
					Text(" "~progressSpinnerStr(progressStyle)~" "); 
				}
			); 
		} 
		
		void TAB()
		{ Text("\t"); } 	void NL()
		{ Text("\n"); } 
		
		void Comment(Args...)(in Args args)
		{ Text(tsComment, args); } 
		
		void Bullet()
		{
			Row({ outerWidth = fh*2; Flex; Text(tag("char 0x2022")); Flex; }); 
			/+
				Todo: no flex needed, -> center aligned. 
				Constant width is needed however, for different bullet styles.
			+/
		} 
		
		void Bullet(void delegate() contents)
		{ Row({ Bullet; if(contents) contents(); }); } 
		
		void Bullet(string text)
		{ Bullet({ Text(text); }); } 
		
		void Img(File f)
		{
			//Text(tag(`img ` ~ f.fullName.optionallyQuotedFileName));
			//Todo: Markup thing is broken with complicated filenames. Quoted filename not works: range error.
			//Todo: The Id is not specifiable.
			//Todo: This should be a fully customizable container. Img is in fact a container.
			
			version(VulkanUI) {
				bitmaps[f]; 
				/+
					Todo: 260812 This is not necessary, inside Img there is a cached bitmaps[f] call.
					But for safety I'm not commenting it out.
				+/
			}
			else { bitmaps(f); }
			/+
				Todo: In vulkan there is no delayed refresh of images.
				All this have to be solved! 
				26.02.03 It is temporarily fixed.
			+/
			
			imAppend(new .Img(f)); 
		} 
		
		void Img(string def)
		{ Img(File(def)); } 
		
		version(/+$DIDE_REGION Styling+/all)
		{
			void applyBtnBorder(in RGB bColor = clWinBtn)
			{
				//Todo: use it for edit as well
				margin	= Margin(2, 2, 2, 2); 
				border	= Border(2, BorderStyle.normal, bColor); 
				padding	= Padding(2, 2, 2, 2); 
				if(theme.isTool)
				{
					border.width    = 1; 
					border.inset = true; 
					margin .top = margin .bottom = 0; 
					padding.top = padding.bottom = 0; 
				}
			} 
			
			void applyLinkStyle(bool enabled, bool focused, bool captured, float hover)
			{
				style = tsNormal; 
				
				float highlight = 0; 
				if(!enabled)
				{ style.fontColor = clWinBtnDisabledText; }else
				{
					highlight = max(hover*0.66f, captured); 
					style.fontColor = mix(clWinText, clAccent, highlight); 
				}
				
				style.underline = highlight > 0.5f; 
				
				//Todo: handle focused
			} 
			
			void applyBtnStyle(
				bool isWhite, bool enabled, bool focused, 
				bool selected, bool captured, float hover
			)
			{
				const oldFh = style.fontHeight; 
				style = tsBtn; 
				style.fontHeight = oldFh; 
				
				auto bColor = mix(style.bkColor, clWinBtnHoverBorder, hover); 
				
				applyBtnBorder(bColor); 
				
				if(!enabled)
				{
					style.fontColor	= clWinBtnDisabledText; 
					style.bkColor 	= mix(style.bkColor, clWinBackground, .66f); 
					border.color	= style.bkColor; 
				}
				else if(captured)
				{
					border.style	  = BorderStyle.none; 
					style.bkColor	  = clWinBtnPressed; 
				}
				
				if(isWhite)
				{
					if(captured)
					style.bkColor = mix(clWinBackground, clWinBtnPressed, .5f); 
					else style.bkColor = clWinBackground; 
				}
				
				if(theme.isTool)
				{
					//every appearance is lighter on a toolBtn
					style.bkColor   = mix(style.bkColor, tsNormal.bkColor, .5f); 
					if(captured && enabled)
					border.width = 0; //this if() makes the edge squareish
				}
				
				if(selected)
				{
					style.bkColor = mix(style.bkColor, clAccent, .5f); 
					border.color = mix(border.color , clAccent, .5f); 
				}
				
				background = style.bkColor; 
				//Todo: update the backgroundColor of the container. Should be automatic, but how?...
				//Todo: handle focused
			} 
			
			void applyEditStyle(bool enabled, bool focused, float hover)
			{
				const oldFh = style.fontHeight; 
				style   = tsNormal; 
				style.fontHeight = oldFh; 
				
				auto bColor = focused	? clAccent : !enabled
					? mix(clWinBtn, style.bkColor, 0.5f)
					: mix(clWinBtn, clWinBtnHoverBorder, hover); 
				
				applyBtnBorder(bColor); 
				
				if(!enabled)
				{ style.fontColor = mix(style.fontColor, style.bkColor, 0.5f); }
				
				background = style.bkColor; 
			} 
		}
		version(/+$DIDE_REGION+/all) {
			HitInfo Static(string _M_=__MODULE__, size_t _L_=__LINE__, V, Args...)
				(in V value, in Args args)
			{
				setIncomingId!(_M_, _L_)(); 
				static if(is(V : Property))
				return _Static(value.asText, hint(value.hint), args); 
				else
				return _Static(value, args); 
			} 
			
			private HitInfo _Static(V, Args...)(in V value, in Args args)
			{
				version(/+$DIDE_REGION Create a new CustomContainer instance+/all)
				{
					mixin ContainerScript_Init!(.Row, q{hit hint}, (表([[],])), (表([[],]))); 
					mixin(SCR.Create); 
				}
				
				version(/+$DIDE_REGION Local variable declarations+/all)
				{
					applyEditStyle(true, false, 0); 
					rowFlags.hAlign = ((isNumeric!V)?(HAlign.right) :(HAlign.left)); 
				}
				
				version(/+$DIDE_REGION Load all properties+/all)
				{ mixin(SCR.ProcessProperties); }
				
				version(/+$DIDE_REGION Do custom behavior+/all)
				{
					static if(__traits(compiles, value()))	value(); 
					else { _container.appendMarkupLine(value.text, style); }
				}
				
				version(/+$DIDE_REGION Handle the recursive composition+/all)
				{ mixin(SCR.ProcessComposition); }
				
				version(/+$DIDE_REGION Return custom results+/all)
				{
					//set minimal height for the control if empty
					if(_container.empty && _container.innerHeight<=0)
					_container.innerHeight = fh; 
					
					return hit; 
				}
			} 
		}
		auto Edit(string _M_=__MODULE__, size_t _L_=__LINE__, V, Args...)(ref V value, in Args args)
		{
			static if(is(T0==Path))
			return EditPath!(_M_, _L_)(value, args); 
			else static if(is(T0==File))
			return EditFile!(_M_, _L_)(value, args); 
			else
			{
				setIncomingId!(_M_, _L_)(); 
				return _Edit(value, args); 
			}
		} 
		
		private auto _Edit(V, Args...)(ref V value, in Args args)
		{
			version(/+$DIDE_REGION Create a new CustomContainer instance+/all)
			{
				mixin ContainerScript_Init!(.Row, q{hit focus hint range}, (表([[],])), (表([[],]))); 
				mixin(SCR.Create); 
			}
			
			version(/+$DIDE_REGION Local variable declarations+/all)
			{
				auto _row = cast(.Row)_container; 
				
				rowFlags.hAlign = ((isNumeric!V)?(HAlign.right) :(HAlign.left)); 
				flags.clipSubCells = true; 
			}
			
			version(/+$DIDE_REGION Load all properties+/all)
			{ mixin(SCR.ProcessProperties); }
			
			version(/+$DIDE_REGION Do custom behavior+/all)
			{
				static struct EditResult {
					HitInfo hit; 
					bool changed, focused; 
					alias this = changed; 
				} 
				EditResult res; 
				
				res.hit = hit; 
				res.focused = focused; 
				
				applyEditStyle(imEnabled, focused, res.hit.hover_smooth); 
				
				version(/+$DIDE_REGION Editor data transfer+/all)
				{
					void value2editor()
					{ textEditorState.str = value.text; } 
					
					bool wasConvertError; //editor2value messaging back with this
					void editor2value()
					{
						try
						{
							auto newValue = textEditorState.str.to!V; 
							
							static if(isNumeric!V)
							{
								auto clamped = range.clamp(newValue); 
								wasConvertError = clamped != newValue; 
								newValue = clamped; 
							}
							
							res.changed = newValue != value; 
							value = newValue; 
						}
						catch(Exception) { wasConvertError = true; }
					} 
				}
				
				if(focused.entered)
				{
					value2editor; 
					with(textEditorState) cmdQueue ~= EditCmd(EditCmd.cEnd); 
				}
				
				version(/+$DIDE_REGION Text editor functionality 1+/all)
				{
					if(focused)
					{
						editor2value; 
						
						textEditorState.row = _row; 
						textEditorState.strModified = false; //ready for next modifications
						
						const localMouse = res.hit.hover ? res.hit.localPos : vec2(0); 
						
						textEditorState.handleKeyboardInput
							(mainWindow.inputChars, rowFlags.acceptEditorKeys, localMouse); 
						
						rowFlags.dontHideSpaces = true; 
					}
				}
			}
			
			version(/+$DIDE_REGION Handle the recursive composition+/all)
			{ mixin(SCR.ProcessComposition); }
			
			version(/+$DIDE_REGION Text editor functionality 2+/all)
			{
				//put the text out
				if(focused)
				{
					if(wasConvertError) textStyle.fontColor = clRed; 
					_row.appendMarkupLine(textEditorState.str, textStyle, textEditorState.cellStrOfs); 
				}
				else { _row.appendMarkupLine(value.text, textStyle); }
				
				//get default fontheight for the editor after the (possibly empty) string was displayed
				const fh = style.fontHeight; 
				
				//set editor's defaultFontHeight for the caret when the string is empty
				if(focused)
				textEditorState.defaultFontHeight = fh; 
				
				//set minimal height for the control
				if(_row.empty && _row.innerHeight<=0)
				{ _row.innerHeight = fh; }
			}
			
			version(/+$DIDE_REGION Return custom results+/all)
			{ return res; }
		} 
		alias EditFile = EditFileOrPath, EditPath = EditFileOrPath; 
		auto EditFileOrPath(string _M_=__MODULE__, size_t _L_=__LINE__, T, Args...)
			(ref T act, in Args args)
			if (is(T == Path) || is(T == File))
		{
			static struct Res
			{
				bool mustRefresh; alias mustRefresh this; 
				bool valid, editing, changed; 
			} Res res; 
			
			
			Row!(_M_, _L_)
			(
				args,
				{
					ref edited = ImStorage!T.access(thisContainer.id); 
					
					auto normalize(in T p) => p.normalized; 
					auto validate(in T p) => p.exists; 
					
					static if(is(T == Path))	ref editField() => edited.fullPath; 
					else	ref editField() => edited.fullName; 
					
					Edit(
						editField,
						{
							flex = 1; 
							if(flags.focused)
							{
								res.editing = true; 
								
								auto normalizedValue = normalize(edited); 
								res.valid = validate(normalizedValue); 
								res.changed = act != edited; 
								
								void colorize(RGB cl)
								{
									background = style.bkColor = mix(background, cl, 0.25f); 
									border.color = cl; 
								} 
								
								if(!res.valid)	colorize(clRed); 
								else if(res.changed)	colorize(clGreen); 
								if(inputs.Esc.pressed) edited = act; 
								if(
									inputs.Enter.pressed 
									&& res.valid
								) {
									{
										act = normalizedValue; 
										focusedState.reset; 
										res.mustRefresh = true; 
									}
								}
							}
							else
							{
								edited = act; 
								res.valid = validate(act); 
								if(!res.valid) { style.fontColor = clRed; }
							}
						}
					); 
					
					if(res.editing)
					{
						if(res.changed)
						{
							//Todo: These buttons ain't work with mouse. Only Enter/Esc works.
							if(Btn(symbolStr("Accept"), ((res.valid).名!q{enabled})))
							{
								act = edited; 
								res.editing = false; 
								res.valid = validate(act); 
								res.mustRefresh = true; 
								focusedState.reset; 
							}
							if(Btn(symbolStr("Cancel")))
							{
								edited = act; 
								res.editing = false; 
								res.valid = validate(act); 
								focusedState.reset; 
							}
						}
					}
					else
					{
						static if(is(T == Path))
						{
							if(res.valid && Btn(symbolStr("Refresh")))
							{ res.mustRefresh = true; }
						}
					}
				}
			); 
			
			return res; 
		} 
		HitInfo Btn(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		{
			setIncomingId!(_M_, _L_)(); 
			return _Btn(args); 
		} 
		
		auto WhiteBtn(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		=> Btn!(_M_, _L_)(args, Theme.white); 
		
		auto ToolBtn(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		=> Btn!(_M_, _L_)(args, Theme.tool); 
		
		private HitInfo _Btn(Args...)(in Args args)
		{
			version(/+$DIDE_REGION Create a new CustomContainer instance+/all)
			{
				mixin ContainerScript_Init!
				(.Row, q{hit focus hint key spaceKey}, (表([[],])), (表([[],]))); 
				mixin(SCR.Create); 
			}
			
			version(/+$DIDE_REGION Local variable declarations+/all)
			{
				//flags.wordWrap = false;
				rowFlags.hAlign = HAlign.center; 
			}
			
			version(/+$DIDE_REGION Load all properties+/all)
			{ mixin(SCR.ProcessProperties); }
			
			version(/+$DIDE_REGION Do custom behavior+/all)
			{
				applyBtnStyle(
					theme.isWhite, imEnabled, focused, imSelected, 
					hit.captured, hit.hover_smooth
				); 
			}
			
			version(/+$DIDE_REGION Handle the recursive composition+/all)
			{ mixin(SCR.ProcessComposition); }
			
			version(/+$DIDE_REGION Return custom results+/all)
			{ return hit; }
		} 
		
		auto BtnRow(Cntr = .Row, string _M_=__MODULE__, size_t _L_=__LINE__, Args...)
			(void delegate() fun, in Args args)
		{
			Container!(Cntr, _M_, _L_)
			(
				{
					static if(is(Cntr : .Row)) rowFlags.btnRowLines = true; 
					
					fun(); 
					
					foreach(i, c; subCells)
					{
						const 	first = i==0, 
							last = i+1==subCells.length; 
						//stick them together with 0 margin
						static if(is(Cntr : .Row))
						{
							if(!first)
							c.margin.left = 0; if(!last)
							c.margin.right= 0; 
						}
						static if(is(Cntr : .Column))
						{
							if(!first)
							c.margin.top = 0; if(!last)
							c.margin.bottom= 0; 
						}
					}
				}, args
			); 
		} 
		
		auto BtnRow(Cntr = .Row, string _M_=__MODULE__, size_t _L_=__LINE__, T...)
			(ref int idx, in string[] captions, in T args)
		{
			auto last = idx; 
			
			BtnRow!(Cntr, _M_, _L_)
			(
				{
					foreach(i0, capt; captions)
					{
						const i = cast(int)i0; 
						if(Btn(capt, genericId(i), ((idx==i).名!q{selected})))
						idx = i; 
					}
				}, args
			); 
			
			return last != idx; 
		} 
		
		auto BtnRow(Cntr = .Row, string _M_=__MODULE__, size_t _L_=__LINE__, A, Args...)
			(ref A value, in A[] items, in Args args)
		{
			auto idx = cast(int) items.countUntil(value); //Todo: it's a copy from ListBox. Refactor needed
			auto res = BtnRow!(Cntr, _M_, _L_)(idx, items, args); 
			if(res) value = items[idx]; 
			return res; 
		} 
		
		//Todo: (enum, enum[]) is ambiguous!!! only (enum) works on its the full members.
		auto BtnRow(Cntr = .Row, string _M_=__MODULE__, size_t _L_=__LINE__, E, Args...)
			(ref E e, in Args args)
		if(is(E==enum))
		{
			string s = e.text; 
			auto res = BtnRow!(Cntr, _M_, _L_)(s, EnumMemberNames!E, args); 
			if(res) ignoreExceptions({ e = s.to!E; }); 
			return res; 
		} 
		
		HitInfo Link(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		{ setIncomingId!(_M_, _L_)(); return _Link(args); } 
		
		private HitInfo _Link(Args...)(in Args args)
		{
			mixin ContainerScript_Init!(.Row, q{hit focus hint key spaceKey}, (表([[],])), (表([[],]))); 
			mixin(SCR.Create); mixin(SCR.ProcessProperties); 
			applyLinkStyle(imEnabled, focused, hit.captured, hit.hover_smooth); 
			mixin(SCR.ProcessComposition); return hit; 
			
			//Todo: set the mouse cursor!!!
			/+Todo: Underline is broken in Vulkan...+/
		} 
		
		HitInfo ChkBox(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(ref bool state, in Args args)
		{ setIncomingId!(_M_, _L_)(); return _ChkBox!"chk"(state, args); } 
		
		HitInfo RadioBtn(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(ref bool state, in Args args)
		{ setIncomingId!(_M_, _L_)(); return _ChkBox!"radio"(state, args); } 
		
		auto ChkBox(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)
			(Property prop, string caption, in Args args)
		{
			auto bp = cast(BoolProperty)prop; 
			enforce(bp !is null); 
			auto last = bp.act; 
			auto res = ChkBox!(_M_, _L_)(
				bp.act, caption.empty ? prop.caption : caption, 
				((prop.name).名!q{id}), hint(prop.hint), args
			); 
			bp.uiChanged |= last != bp.act; 
			return res; 
		} 
		
		private HitInfo _ChkBox(string chkBoxStyle, Args...)(ref bool state, in Args args)
		{
			version(/+$DIDE_REGION Create a new CustomContainer instance+/all)
			{
				mixin ContainerScript_Init!
				(.Row, q{hit focus key hint spaceKey}, (表([[],])), (表([[],]))); 
				mixin(SCR.Create); 
			}
			
			version(/+$DIDE_REGION Local variable declarations+/all)
			{
				/+flags.wordWrap = false; +/
				margin.left = margin.right = 2; 
			}
			
			version(/+$DIDE_REGION Load all properties+/all)
			{ mixin(SCR.ProcessProperties); }
			
			version(/+$DIDE_REGION Do custom behavior+/all)
			{
				if(imEnabled && hit.clicked) { state.toggle; }//update checkbox state
				
				RGB hoverColor(RGB baseColor, RGB bkColor)
				{
					return !imEnabled ? clWinBtnDisabledText
						: mix(baseColor, bkColor, hit.captured ? 0.5f : hit.hover_smooth*0.3f); 
				} 
				
				const markColor = hoverColor(state ? clAccent : style.fontColor, style.bkColor); 
				const textColor = hoverColor(style.fontColor, style.bkColor); 
				
				const bullet = ((chkBoxStyle=="radio") ?(symbolStr(`RadioBtn`~(state?"On":"Off"))) :(symbolStr(`Checkbox`~(state?"CompositeReversed":"")))); 
				
				style.fg = markColor; 
				Text(bullet, ` `); 
				style.fg = textColor; 
			}
			
			version(/+$DIDE_REGION Handle the recursive composition+/all)
			{ mixin(SCR.ProcessComposition); }
			
			version(/+$DIDE_REGION Return custom results+/all)
			{ return hit; }
		} 
		
		
		bool IncBtn(string _M_=__MODULE__, size_t _L_=__LINE__, Value, Args...)
			(ref Value value, in Args args)
		{ setIncomingId!(_M_, _L_)(); return _IncBtn!(+1)(value, args, ((+1).名!q{id})); } 
		
		bool DecBtn(string _M_=__MODULE__, size_t _L_=__LINE__, Value, Args...)
			(ref Value value, in Args args)
		{ setIncomingId!(_M_, _L_)(); return _IncBtn!(-1)(value, args, ((-1).名!q{id})); } 
		
		private bool _IncBtn(int sign=1, Value, Args...)(ref Value value, in Args args)
			if(sign!=0 && isNumeric!Value)
		{
			version(/+$DIDE_REGION Create a new CustomContainer instance+/all)
			{
				mixin ContainerScript_Init!
				(.Row, q{hit hint focus range}, (表([[],])), (表([[],]))); 
				mixin(SCR.Create); 
			}
			
			version(/+$DIDE_REGION Local variable declarations+/all)
			{ rowFlags.hAlign = HAlign.center; }
			
			version(/+$DIDE_REGION Load all properties+/all)
			{ mixin(SCR.ProcessProperties); }
			
			version(/+$DIDE_REGION Do custom behavior+/all)
			{
				applyBtnStyle(
					theme.isWhite, imEnabled, focused, imSelected, 
					hit.captured, hit.hover_smooth
				); 
				
				Text(symbolStr(`Calculator` ~ ((sign>0)?(`Addition`) :(`Subtract`)))); 
			}
			
			version(/+$DIDE_REGION Handle the recursive composition+/all)
			{
				bool chg; 
				void increment()
				{
					auto 	oldValue 	= value,
						step 	= abs(range.step),
						newValue 	= range.clamp(value+step*sign); 
					
					//Todo: use shift/alt/ctrl to scale step.
					
					if(isIntegral!Value)	value = (cast(Value)((round(newValue)))); 
					else	value = (cast(Value)(newValue)); 
					
					chg |= newValue != oldValue; 
				} 
				
				if(hit.repeated) increment; 
				
				mixin(SCR.ProcessComposition); 
			}
			
			version(/+$DIDE_REGION Return custom results+/all)
			{ return chg; }
		} 
		
		auto IncDecBtn(string _M_=__MODULE__, size_t _L_=__LINE__, Value, Args...)
			(ref Value value, in Args args)
		{
			bool res; 
			Row(
				{
					rowFlags.btnRowLines = true; 
					auto r1 = DecBtn!(_M_, _L_)(value, args); 
					lastContainer.margin.right = 0; 
					auto r2 = IncBtn!(_M_, _L_)(value, args); 
					lastContainer.margin.left = 0; 
					res = r1 || r2; 
				}
			); 
			return res; 
		} 
		
		auto IncDec(string _M_=__MODULE__, size_t _L_=__LINE__, Value, Args...)
			(ref Value value, in Args args)
		{
			auto oldValue = value; 
			
			Edit!(_M_, _L_)(value, { width = 2*fh; }, args); 
			
			IncDecBtn(value, args); 
			return oldValue != value; 
		} 
		
		auto LedBtn(string _M_=__MODULE__, size_t _L_=__LINE__, S, Args...)
			(in S ledState, RGB ledColor, in Args args)
		{
			return Btn!(_M_, _L_)(
				mixin(舉!((HAlign),q{left})), {
					Led(ledState, ledColor); 
					Spacer(fh*0.25f); 
				}, args
			); 
		} 
		
		bool TabsHeader(string _M_=__MODULE__, size_t _L_=__LINE__, T, I, A...)
			(T[] items, ref I idx, A args)
			if(isIntegral!I)
		{
			static customDraw(Drawing dr, .Container cntr)
			{
				bool materialStyle = true; 
				//Todo: theme selection.  tool, white, material... these are conflicting now.
				
				auto btns = (cast(.Container[])(cntr.subCells)); if(btns.empty) return; 
				
				if(!materialStyle)
				{
					dr.lineWidth = 2; bool first = true; vec2 bOfs; 
					foreach(btn; btns)
					{
						const bnd = btn.borderBounds; 
						const sel = btn.flags.selected; 
						
						if(first) bOfs = bnd.bottomLeft; 
						
						dr.color = clWinBtn; 
						if(first)	dr.moveTo(bnd.bottomLeft); 
						else	dr.lineTo(bnd.bottomLeft); 
						if(sel) {
							dr.lineTo(bnd.topLeft); 
							dr.lineTo(bnd.topRight); 
						}
						dr.lineTo(bnd.bottomRight); 
						
						first = false; 
					}
					
					dr.lineTo(cntr.innerWidth-bOfs.x, bOfs.y); //extend right
				}
				else
				{
					dr.lineWidth = 4; 
					dr.color = clWinBtn; 
					const bOfs = btns[0].borderBounds.bottomLeft; 
					dr.hLine(bOfs.x, bOfs.y, cntr.innerWidth-bOfs.x); 
					
					dr.color = clAccent; 
					btns	.filter!((b)=>(b.flags.selected))
						.each!((b){
						with(b.borderBounds)
						dr.hLine(left, bottom, right); 
					}); 
				}
			} 
			
			bool clicked; 
			Row!(_M_, _L_)
			(
				{
					foreach(i; 0..items.length)
					{
						if(
							WhiteBtn
							(
								items[i], genericId(i), /*selected(i==idx)*/
								{
									//if(border.color==clWinBtn) border.color = bkColor; 
									/+
										Todo: this is a nasty workaround. 
										Need a completely white Btn (link) for this.
									+/
									
									background = clWinBackground; 
									border.color = clWinBackground; 
									flags.selected = i==idx; 
									//Todo: Ez kurvaga'ny! Ez adja at a selectiont a draw callbacknak
									
									padding = "4"; 
								}
							)
						)
						{ idx = i.to!I; clicked = true; }
					}
					addDrawCallback(toDelegate(&customDraw)); 
				}
				, args
			); 
			
			return clicked; 
		} 
		
		void TabsPage(string _M_=__MODULE__, size_t _L_=__LINE__, A...)(A args)
		{
			Column!(_M_, _L_)
			(
				{
					bool materialStyle = true; 
					if(materialStyle)
					{ margin = "4 0"; }else
					{
						margin	= Margin(0, 2, 2, 2); 
						border	= Border(2, BorderStyle.normal, clWinBtn); 
						padding	= Padding(2, 2, 2, 2); 
					}
				}, args
			); 
		} 
		
		void Tabs(
			alias mapTitle = "a.title", alias mapUI = "a.UI()", R, I, 
			string _M_=__MODULE__, size_t _L_=__LINE__, A...
		)(R r, ref I idx, A args)
		{
			bool includeAll = false; 
			static foreach(a; args)
			{
				{
					static if(is(typeof(a) == GenericArg!(N, T), string N, T) && N=="includeAll")
					{ includeAll = a; }
				}
			}
			
			auto titles = r.map!mapTitle.array; 
			alias TT = typeof(titles[0]); 
			const len = titles.length; 
			
			//Todo: includeAll is broken when title is a callable 
			
			
			TabsHeader!(_M_, _L_)(titles, idx); 
			TabsPage!(_M_, _L_)
			(
				{
					if(mixin(界1(q{0},q{idx},q{len})))	{
						auto r2 = r.drop(idx); 
						if(!r2.empty) r2.front.unaryFun!mapUI(); 
					}
					else	{
						if(includeAll && idx==len)
						foreach(a; r) a.unaryFun!mapUI; 
					}
				}
			); 
		} 
		
		
		
		auto Slider(string _M_=__MODULE__, size_t _L_=__LINE__, Value, Args...)
			(ref Value value, in Args args)
			if(isFloatingPoint!Value || isIntegral!Value)
		{ setIncomingId!(_M_, _L_)(); return _Slider(value, args); } 
		
		private auto _Slider(Value, Args...)(ref Value value, in Args args)
		{
			version(/+$DIDE_REGION Create a new CustomContainer instance+/all)
			{
				mixin ContainerScript_Init!
				(
					.Slider, q{hit focus range hint}, 
					(表([
						[q{isT!SliderOrientation},q{slider.orientation = a; }],
						[q{isT!SliderType},q{slider.type = a; }],
						[q{isG!"normThumbSize"},q{slider.normThumbSize = a; }],
					])), (表([[],]))
				); 
				mixin(SCR.Create); 
				focusRMB = true; //Todo: mosude wheel support
			}
			
			version(/+$DIDE_REGION Local variable declarations+/all)
			{
				auto slider = (cast(.Slider)(_container)); 
				
				//set some defaults
				slider.orientation 	= SliderOrientation.auto_,
				slider.type 	= SliderType.slider; 
			}
			
			version(/+$DIDE_REGION Load all properties+/all)
			{ mixin(SCR.ProcessProperties); }
			
			version(/+$DIDE_REGION Do custom behavior+/all)
			{
				slider.hitBounds = hit.hitBounds; 
				slider.setupAppearance(
					imEnabled, focused, hit.hover_smooth, hit.captured_smooth, 
					fh*(((theme.isTool)?(1):(1.4f))*0.8f)
				); 
				
				//flipped range interval. Needed for vertical scrollbar
				const flipped = !range.isOrdered; 
				if(flipped) swap(range.min, range.max); 
				
				slider.nPos = range.normalize(flipped ? range.max-value : value); //FLIP
				
				int wrapCnt; 
				if(range.isEndless)
				{
					wrapCnt = slider.nPos.floor.iround;  /+Todo: refactor endless wrapCnt stuff+/
					slider.nPos = slider.nPos - slider.nPos.floor; 
				}
				
				if(slider.type==SliderType.scrollBar) padding.set(2); 
				
				bool userModified; 
				if(focused && im.canProcessUserInput)
				{
					if(im.sliderState.handleKeyboard(slider.nPos, range, 8))
					userModified = true; 
					if(
						im.sliderState.handleMouse(
							slider.id, hit, slider.nPos, 
							targetView.mousePos.vec2, range, wrapCnt
						)
					)
					userModified = true; 
				}
				
				if(userModified)
				{
					if(range.isEndless) slider.nPos += wrapCnt - slider.wrapCnt; 
					
					float f = range.denormalize(slider.nPos); 
					static if(isIntegral!Value) f = round(f); 
					value = f.to!Value; 
					if(flipped) value = (range.max - value).to!Value; //UNFLIP
				}
			}
			
			version(/+$DIDE_REGION Handle the recursive composition+/all)
			{ mixin(SCR.ProcessComposition); }
			
			version(/+$DIDE_REGION Return custom results+/all)
			{ return userModified; }
		} 
		
		auto HRuler(string _M_=__MODULE__, size_t _L_=__LINE__, T : DateTime, Args...)
			(
			in 	T tMin	, in 	T tMax, 
			ref 	T t0	, ref 	T t1, 
			ref 	T t0_smooth 	, ref 	T t1_smooth, in Args args
		)
		{ setIncomingId!(_M_, _L_)(); return _HRuler(__traits(parameters)); } 
		
		auto _HRuler(T : DateTime, Args...)(
			in 	T tMin	, in 	T tMax, 
			ref 	T t0	, ref 	T t1, 
			ref 	T t0_smooth 	, ref 	T t1_smooth, in Args args
		)
		{
			version(/+$DIDE_REGION Create a new CustomContainer instance+/all)
			{
				mixin ContainerScript_Init!
				(.DateTimeRuler, q{hit focus hint}, (表([[],])), (表([[],]))); 
				mixin(SCR.Create); 
				focusRMB = focusMMB, focusMW = true; 
			}
			
			version(/+$DIDE_REGION Local variable declarations+/all)
			{ auto ruler = (cast(.DateTimeRuler)(_container)); }
			
			version(/+$DIDE_REGION Load all properties+/all)
			{ mixin(SCR.ProcessProperties); }
			
			version(/+$DIDE_REGION Do custom behavior+/all)
			{
				bool userModified; 
				ref rangeFollower = ImStorage!(RangeFollower!DateTime).access(_id); 
				rangeFollower.beforeUpdate(false, t0, t1, tMin, tMax); 
				
				ruler.setup(tMin, tMax, t0, t1, targetView.mousePos.vec2, hit); 
				ruler.perform(focused, textStyle, targetView.mousePos.vec2, hit, userModified, t0, t1); 
				
				rangeFollower.afterUpdate(userModified, t0, t1, calcAnimationT(deltaTime, .7)); 
				ruler.t0_draw = t0_smooth = rangeFollower.smooth[0],
				ruler.t1_draw = t1_smooth = rangeFollower.smooth[1]; 
			}
			
			version(/+$DIDE_REGION Handle the recursive composition+/all)
			{ mixin(SCR.ProcessComposition); }
			
			version(/+$DIDE_REGION Return custom results+/all)
			{ return userModified; }
		} 
		
		enum ListBoxItemEvent : ubyte
		{
			none, 
			selected, /+user actively selected an unselected item by pressing the mouse+/
			clickedOnSelected /+user released the mouse on the currently selected item+/
		} 
		
		ListBoxItemEvent ListBoxItem(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)(in Args args)
		{ setIncomingId!(_M_, _L_)(); return _ListBoxItem(args); } 
		
		private ListBoxItemEvent _ListBoxItem(Args...)(in Args args)
		{
			version(/+$DIDE_REGION Create a new CustomContainer instance+/all)
			{
				mixin ContainerScript_Init!(.Row, q{hit}, (表([[],])), (表([[],]))); 
				mixin(SCR.Create); 
			}
			
			version(/+$DIDE_REGION Local variable declarations, initialize default properties+/all)
			{ padding.set(2); }
			
			version(/+$DIDE_REGION Load all properties+/all)
			{ mixin(SCR.ProcessProperties); }
			
			version(/+$DIDE_REGION Do custom behavior+/all)
			{
				ListBoxItemEvent event; 
				if(hit.hover && canProcessUserInput && imEnabled)
				{
					if(!imSelected)
					{
						if(inputs.LMB.pressed || inputs.RMB.pressed)
						{ event = ListBoxItemEvent.selected; imSelected = true; }
					}
					else
					{
						if(inputs.LMB.released || inputs.RMB.released)
						event = ListBoxItemEvent.clickedOnSelected; 
					}
				}
				
				background = mix(background, clAccent, max(imSelected ? 0.66f:0, hit.hover_smooth*0.33f)); 
				style.bkColor = background; 
			}
			
			version(/+$DIDE_REGION Handle the recursive composition+/all)
			{ mixin(SCR.ProcessComposition); }
			
			version(/+$DIDE_REGION Return custom results+/all)
			{ return event; }
		} 
		
		
		static struct ListBoxResult
		{ HitInfo hit; bool userSelected, userClickedOnSelected; alias this = userSelected; } 
		
		auto ListBox(
			alias translator = "a.text", string _M_=__MODULE__, size_t _L_=__LINE__, 
			Item, Args...
		)
			(ref int idx, in Item[] items, in Args args)
		{
			setIncomingId!(_M_, _L_)(); 
			return _ListBox!(translator, Item, Args)(idx, items, args); 
		} 
		
		auto ListBox(
			alias translator = "a.text", string _M_=__MODULE__, size_t _L_=__LINE__, 
			Item, Args...
		)
			(ref Item value, in Item[] items, in Args args)
		{
			auto idx = (cast(int)(items.countUntil(value))); 
			auto res = ListBox!(translator, _M_, _L_)(idx, items, args); 
			if(res) value = items[idx]; return res; 
		} 
		
		auto ListBox(string _M_=__MODULE__, size_t _L_=__LINE__, E, Args...)
			(ref E e, in Args args)
			if(is(E==enum))
		{
			auto s = e.text; 
			auto res = ListBox!(translator, _M_, _L_)(s, getEnumMembers!E, args); 
			if(res) ignoreExceptions({ e = s.to!E; }); return res; 
		} 
		
		auto _ListBox(alias translator, Item, Args...)
			(ref int idx, in Item[] items, in Args args)
		{
			version(/+$DIDE_REGION Create a new CustomContainer instance+/all)
			{
				mixin ContainerScript_Init!(.Column, q{hit}, (表([[],])), (表([[],]))); 
				mixin(SCR.Create); 
			}
			
			version(/+$DIDE_REGION Local variable declarations, initialize default properties+/all)
			{ border = "1 normal gray"; }
			
			version(/+$DIDE_REGION Load all properties+/all)
			{ mixin(SCR.ProcessProperties); }
			
			version(/+$DIDE_REGION Do custom behavior+/all)
			{
				auto res = ListBoxResult(hit); 
				foreach(i, item; items)
				{
					const e = ListBoxItem(((i).名!q{id}), ((i==idx).名!q{selected}), unaryFun!translator(item), args); 
					if(e==mixin(舉!((ListBoxItemEvent),q{selected})))	{ idx = (cast(int)(i)); res.userSelected = true; }
					else if(e==mixin(舉!((ListBoxItemEvent),q{clickedOnSelected})))	{ res.userClickedOnSelected = true; }
				}
			}
			
			version(/+$DIDE_REGION Handle the recursive composition+/all)
			{ mixin(SCR.ProcessComposition); }
			
			return res; 
		} 
		DropdownState dropdownState; 
		static struct DropdownState
		{
			Id comboId;    //when the focus of this is lost, comboState goes false
			
			.Container 	ownerContainer 	/+the initiator of the popup+/, 
				dropdownContainer	/+the popup itself+/; 
			
			bool active; //automatically cleared on focus.change
			bool opening; //popup cant disappear when clicking away and this is set true by the combo
			
			/+
				HAlign hAlign; 
				VAlign vAlign; 
			+/
			void open(Id id)
			{
				active = true; comboId = id; 
				opening = true; //ignore this mousepress when closing popup
			} 
			
			
			void close()
			{
				active = false; comboId = Id.init; 
				opening = false; 
			} 
			
			void toggle(Id id)
			{ if(active) close; else open(id); } 
			
			private void beginFrame()
			{
				/+`active` and `comboId` is retained.+/
				
				opening = false; 
				ownerContainer = null; 
				dropdownContainer = null; 
				/+
					hAlign = HAlign.left; 
					vAlign = VAlign.bottom; 
				+/
			} 
			
			void doAlign()
			{
				//must be called after measure
				/*
					if(cell && parent){
						switch(hAlign){
							case HAlign.right: cell.outerPos.x = parent.outerRight-cell.outerWidth; break;
							default: cell.outerPos.x = parent.outerPos.x;
						}
						switch(vAlign){
							case VAlign.top: cell.outerY = parent.outerBottom-cell.outerHeight; break;
							default: cell.outerY = parent.outerY; break;
						}
					}
				*/
				
				/+
					Todo: When the ComboBox is stretched, 
					this dropdown and all it's lines should be stretched too!
				+/
				
				if(dropdownContainer && ownerContainer)
				{
					//first try to align to the bottom.
					auto bnd = imstOuterBounds(ownerContainer.id); 
					dropdownContainer.outerPos = vec2(bnd.left+2, bnd.bottom-2); 
					
					//then if it clips the sceen, put it on top.
					if(dropdownContainer.flags.targetSurface == TargetSurface.gui)
					{
						const maxy = view_gui.screenBounds_anim.bounds2.bottom; 
						if(dropdownContainer.outerBottom > maxy)
						dropdownContainer.outerPos.y = 
							bnd.top - 2 - dropdownContainer.outerHeight; 
					}
				}
			} 
		} 
		
		private void Dropdown(.Container parent, void delegate() contents)
		{
			enforce(parent, "Dropdown parent can't be null."); 
			
			auto oldLen = subCells.length; 
			contents(); 
			auto extraLen = subCells.length-oldLen; 
			
			if(extraLen==0) return; 
			if(extraLen>1) raise("Popup must contain only one Cell"); 
			
			auto container = removeLastContainer; 
			enforce(container, "Dropdown content must be a single Container."); 
			
			dropdownState.dropdownContainer = container; 
			dropdownState.ownerContainer = parent; 
		} 
		
		version(/+$DIDE_REGION+/none) {
			deprecated("Copy the working stuff from ComboBox_idx!")
			auto PopupBtn(string _M_=__MODULE__, size_t _L_=__LINE__, T0, Args...)
				(T0 text, Args args)
				if(
				(isSomeString!T0 || __traits(compiles, text())) 
				&& Args.length>=1 && __traits(compiles, args[$-1]()) 
			)
			{
				/+
					Todo: Too many copy+paste, this is the same as ComboBox.
					The newer one is in ComboBox_idx. 260819
				+/
				
				Cell btn; 
				auto hit = Btn(text, args[0..$-1], { btn = thisContainer; }); 
				
				if(isFocused(hit.id))
				{
					(cast(.Container)(btn)).flags._saveComboBounds = true; 
					//notifies glDraw to place the popup
				}
				
				
				if(hit.pressed)
				{
					comboId = hit.id; 
					comboState.toggle; 
					comboOpening = true; //ignore this mousepress when closing popup
				}
				
				const popupVisible = isFocused(hit.id) && comboState; 
				if(popupVisible)
				{ Popup(btn, { Column({ args[$-1](); }); }); }
				return popupVisible; 
				//callee must handle the if and optionally set "comboState" to false
				//Todo: what if callee don't handle it????
			} 
		}
		
		auto ComboBox_idx(alias translator = "a.text", string _M_=__MODULE__, size_t _L_=__LINE__, A, Args...)
			(ref int idx, in A[] items, in Args args)
		{
			.Container btn; 
			auto hit = WhiteBtn!(_M_, _L_)
				(
				{
					btn = thisContainer; 
					rowFlags.hAlign = HAlign.left; 
					
					if(idx.inRange(items))	{ Text(unaryFun!translator(items[idx])); }
					else	{ Text(clGray, "none"); }
					
					Flex; 
					Row(
						{
							flags.clickable = false; 
							Text(" ", symbolStr("ChevronDown"), " "); 
						}
					); 
				}
				, args
			); 
			
			ListBoxResult res; 
			if(isFocused(hit.id))
			{
				btn.flags._saveOuterBounds = true /+world outer bounds will be saved on next Draw()+/; 
				/+It is saved ALL the time, so it survives the 1 frame delay.+/
				
				if(hit.pressed) dropdownState.toggle(hit.id); 
				
				if(dropdownState.active)
				{
					Dropdown
					(
						btn, {
							void inheritComboWidth()
							{
								if(btn.innerWidth>0)
								innerWidth = btn.innerWidth+6; //Todo: tool theme*/
								/+Todo: Why +6? This is lame....+/
							} 
							
							res = ListBox!(translator, _M_, _L_)(idx, items, ((1).名!q{id}), &inheritComboWidth); 
							
							if(dropdownState.active && res.userClickedOnSelected)
							{
								dropdownState.close; //close the dropdown
							}
						}
					); 
				}
			}
			return res; 
		} 
		
		auto ComboBox_ref(alias translator = "a.text", string _M_=__MODULE__, size_t _L_=__LINE__, Item, Args...)
			(ref Item item, in Item[] items, in Args args)
		{
			auto idx = (cast(int)(items.countUntil(item))); 
			auto res = ComboBox_idx!(translator, _M_, _L_)(idx, items, args); 
			if(res) item = items[idx]; return res; 
		} 
		
		auto ComboBox(alias translator = "a.text", string _M_=__MODULE__, size_t _L_=__LINE__, Item, Args...)
			(ref int idx, in Item[] items, in Args args)
		{ return ComboBox_idx!(translator, _M_, _L_, Item, Args)(idx, items, args); } 
		
		auto ComboBox(alias translator = "a.text", string _M_=__MODULE__, size_t _L_=__LINE__, Item, Args...)
			(ref Item value, in Item[] items, in Args args)
		{ return ComboBox_ref!(translator, _M_, _L_, Item, Args)(value, items, args); } 
		
		auto ComboBox(alias translator = "a.text", string _M_=__MODULE__, size_t _L_=__LINE__, E, Args...)
			(ref E e, in Args args)
			if(is(E==enum))
		{
			auto s = e.text; 
			auto res = ComboBox!(translator, _M_, _L_)(s, EnumMemberNames!E, args); 
			if(res) ignoreExceptions({ e = s.to!E; }); 
			return res; 
		} 
		
		version(/+$DIDE_REGION+/all)
		{
			void AdvancedSlider_impl(T)(T prop, void delegate() fun=null) if(is(T==FloatProperty) || is(T==IntProperty))
			{
				//slider, min/max/act value display, default, edit/inc/dec
				
				const postFix = (" "~prop.unit).stripRight; 
				const caption = prop.name.camelToCaption; 
				
				const variant = 0; 
				
				auto range = ValueRange(prop.min, prop.max, prop.step); 
				auto hint = im.hint(prop.hint); 
				
				const last = prop.act; 
				
				if(variant == 0)
				{
					Column(
						genericId(prop.name), 
						{
							width = 300; 
							Row(
								{
									Text(/*bold*/(caption)); 
									//Spacer;
									Row(
										{
											flex = 1; 
											rowFlags.hAlign = HAlign.right; 
											Text(" "); 
										}
									); 
									Flex; 
									
									if(fun !is null)
									{
										fun(); 
										Spacer; 
									}
									Edit(prop.act, range, hint, { width = fh*3.5; }); 
									Text(postFix~" "); 
									if(prop.step>0)
									{
										IncDecBtn(prop.act, range); //Todo: hint is annoying here
									}
								}
							); 
							Slider(prop.act, range, hint, { flex = 1; }); 
							Row(
								{
									if(Link(prop.min.text ~ postFix))
									prop.act = prop.min; 
									Row(
										{
											flex = 1; 
											rowFlags.hAlign = HAlign.center; //Todo: not precise center!!!
											if(Link("default: " ~ prop.def.text ~ postFix))
											prop.act = prop.def; 
										}
									); 
									if(Link(prop.max.text ~ postFix))
									prop.act = prop.max; 
								}
							); 
						}
					); 
				}
				
				prop.uiChanged |= last != prop.act; 
			} 
			
			void AdvancedSlider(Property prop, void delegate() fun=null)
			{
				//this just casts the Property and	calls the appropriate implementation
				if(auto p = cast(IntProperty	)prop)
				AdvancedSlider_impl(p, fun); 
				else if(auto p = cast(FloatProperty)prop) AdvancedSlider_impl(p, fun); 
				else raise("Invalid type"); 
			} 
			
			void AdvancedSliderChkBox(Property p, Property pBool, string capt="")
			{ AdvancedSlider(p, { ChkBox(pBool, capt); }); } 
			auto Node(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)
				(ref bool state, void delegate() title, void delegate() contents, Args args)
			{
				HitInfo hit; 
				Column!(_M_, _L_)
				(
					{
						border.width = 1; //Todo: ossze kene tudni kombinalni a szomszedos node-ok bordereit.
						border.color = mix(style.bkColor, style.fontColor, state ? .1f : 0); 
						
						Row(
							{
								hit = ToolBtn(symbol("Caret"~(state ? "Down" : "Right")~"Solid8")); 
								if(hit.pressed)
								state.toggle; 
								Text("\t"); 
								if(title)
								title(); 
							}
						); 
						
						if(state && contents)
						Row(
							{
								Text("\t"); 
								Column({ contents(); }); 
							}
						); 
					}, args
				); 
				return hit; 
			} 
			
			auto Node(string _M_=__MODULE__, size_t _L_=__LINE__, Args...)
				(ref bool state, string title, void delegate() contents, Args args)
			{ return Node!(_M_, _L_)(state, { Text(title); }, contents, args); } 
			
			/// A node header that usually connects to a server, can have an error message and a state of refreshing. It can has a refresh button too
			void RefreshableNodeHeader(THeader)(THeader header, string error, bool refreshing, void delegate() onRefresh)
			{
				 //RefreshableNodeHeader ////////////////////////////
				static if(isSomeString!THeader)
				Text(header); 
				else header(); 
				//Todo: node header click = open/close node
				
				if(refreshing)
				{ Text(" "); ProgressSpinner(1); }
				
				if(error.length)
				Text(" \u26a0"); //warning symbol
				//Todo: warning symbol click = open node
				//Todo: warning symbol hint: error message
				
				Flex; 
				if(onRefresh !is null)
				{
					if(ToolBtn(symbol("Refresh"), enable(!refreshing)))
					onRefresh(); 
				}
			} 
			
			
			private void FileIcon_internal(int iconHeight)(string ext)
			{
				with(im)
				{
					if(ext.empty) return; 
					
					static Cell[][string] cache;  //Todo: when megatexture is reallocated, the texture id's of icons become invalid.
					
					Cell[] cells; 
					
					cache.update
					(
						ext, 
						{
							Container(
								{
									Text(tag(format!`img "icon:\%s" height=%f`(ext, iconHeight))); 
									//Note: this is fucking slow, but works
								}
							); 
							auto cntr = removeLastContainer; 
							cells = cntr.subCells;  //Note: this returns the last char or a whole error string produced by text markup processor.
							return cells; 
						},
						((ref Cell[] c){ cells = c; })
					); 
					
					Container(cells); //Must create a new container because of the different outerPos when used multiple times.
				}
			} 
			
			void FileIcon_small (string ext)
			{ FileIcon_internal!(DefaultFontHeight*1-2)(ext); } 
			void FileIcon_normal(string ext)
			{ FileIcon_internal!(DefaultFontHeight*2-2)(ext); } 
			void FileIcon_large (string ext)
			{ FileIcon_internal!(DefaultFontHeight*4-2)(ext); } 
			alias FileIcon = FileIcon_normal; 
			
			
				.Document actDocument; 
			
				void Document(string _M_=__MODULE__, size_t _L_=__LINE__)(string title, void delegate() contents = null)
			{
				auto doc = new .Document; 
				
				enforce(actDocument is null, "No Document nesting allowed"); 
				actDocument =  doc; 
				
				doc.title = title; 
				doc.lastChapterLevel = 0; 
				append(doc); push(doc, srcId!(_M_, _L_)); scope(exit) { pop; actDocument = null; }
				
				if(!title.empty)
				{
					Text(doc.getChapterTextStyle, title); 
					Spacer(1.5f*fh); 
				}
				if(contents)
				contents(); 
			} 
			
				void Document(string _M_=__MODULE__, size_t _L_=__LINE__)(void delegate() contents = null)
			{ Document!(_M_, _L_)("", contents); } 
			
				//Chapter /////////////////////////
				void Chapter(string title, void delegate() contents = null)
			{
				auto doc = actDocument; 
				enforce(doc, "Document parent container null"); 
				
				auto baseLevel = doc.lastChapterLevel; 
				doc.addChapter(title, baseLevel); 
				doc.lastChapterLevel = baseLevel+1; 
				scope(exit) doc.lastChapterLevel = baseLevel; 
				
				//Spacer(1*fh);
				
				Text(doc.getChapterTextStyle, title); 
				//Spacer(0.5*fh);
				
				if(contents)
				contents(); 
			} 
			
				//CrashTestMarker /////////////////////////
				void CrashTestMarker(double angle, RGB c1 = clYellow)
			{
				const 	c2 = style.fontColor,
					f = fh; 
				const RGB 	oldBkColor = background; //Todo: it has to be inherited
				
				Container(
					{
						flags.clickable = false; 
						width = f; 
						height = f; 
						background = oldBkColor; 
						//Todo: make mouse clicks fall throug this to the parent container
						
						
						void customDraw(Drawing dr, .Container cntr)
						{
							auto p = vec2(f*.5), r = f*.45; 
							
							dr.color = c2; 
							dr.pointSize = r*2;  dr.point(p); 
							
							r -= f/12; 
							
							void pie(double angle)
							{
								enum N=8; 
								dr.color = c1; 
								iota(N+1).map!(i => p + vec2(r, 0).rotate(i*(PI/2/N)+angle))
												 .slide(2)
												 .each!((a){ dr.fillTriangle(p, a[1], a[0]); }); 
							} 
							
							pie(angle); pie(angle+PI); 
						} 
						addDrawCallback(&customDraw); 
					}
				); 
			} 
			
		}
	}
	version(/+$DIDE_REGION+/all) {
		
		
		
		
		
		
		
	}
} 
version(/+$DIDE_REGION Dead code+/none)
{
	////////////////////////////////////////////////////////
	///  Dead code                                       ///
	////////////////////////////////////////////////////////
	
	
	//PropertySet tests ///////////////////////////////
	
	/+
		// PropertySet test -----------------------------------------------------------
		Row({ toolHeader;
			Text(bold("PropertySet test:  "));
		});
		
		{// test a single property
			auto ip = new IntProperty;
			ip.name = "intProp";
			ip.caption = "Integer property";
			ip.min = 1;
			ip.max = 10;
			stdUI(ip);
		}
		
		{// test a property loaded from json
			auto str = q{
				{
					"class": "PropertySet",
					"name": "Test property set",
					"properties": [
						{
							"class": "StringProperty",
							"name": "cap.type",
							"caption": "",
							"hint": "Type of capture source.",
							"act": "file",
							"def": "auto",
							"choices": [ "auto", "file", "dshow", "gstreamer", "v4l2", "ueye", "any" ]
						},
						{
							"class": "IntProperty",
							"name": "cap.width",
							"caption": "",
							"hint": "Desired image width",
							"act": 640,
							"def": 640,
							"min": 0,
							"max": 8192,
							"step": 0
						}
					]
				}
			};
	+/
	
	//ListItem ////////////////////////////////
	/+
		Row newListItem(string s, TextStyle ts = tsNormal){
			auto left  = new Row("\u2022", ts);
			left.outerWidth = ts.fontHeight*2;
			left.subCells = new FlexRow("", ts) ~ left.subCells ~ new FlexRow("", ts);
		
			auto right	= new Row(s, ts); right.flex_=1;
			auto act	= new Row([left, right], ts);
		
			act.bkColor = ts.bkColor;
			return act;
		}
		
		class FlexRow : Row{ //FlexRow///////////////////////////////
			this(string markup, TextStyle ts=tsNormal){
				super(markup, ts);
				flex_ = 1;
			}
		}
		
		class Link : Row{ //Link ///////////////////////////////
		
			this(string cmdLine, in SrcId hash, bool enabled, void delegate() onClick, TextStyle ts = tsLink){
				this.id = hash;
				auto hit = im.hitTest(this, enabled);
		
				if(enabled && onClick !is null && hit.clicked){
					onClick();
				}
		
				if(!enabled){
					ts.fontColor = clLinkDisabled;
					ts.underline = false;
				}else if(hit.captured){
					ts.fontColor = clLinkPressed;
				}else{
					ts.fontColor = mix(ts.fontColor, clLinkHover, hit.hover_smooth);
					ts.underline = hit.hover;
				}
		
				flags.wordWrap = false;
		
				auto params = cmdLine.commandLineToMap;
				super(params["0"], ts);
				setProps(params);
			}
		}
		
		
		class KeyComboOld : Row{ //KeyCombo ///////////////////////////////
		
			this(string markup, TextStyle ts = tsKey){
				auto allKeys = inputs.entries.values.filter!(e => e.isButton && e.value).array.sort!((a,b)=>a.pressedTime<b.pressedTime, SwapStrategy.stable).map!"a.name".array;
		
				if(allKeys.canFind(markup)) ts.bkColor = clLime;
		
				margin_ = Margin(1, 1, 0.75, 0.75);
				padding_ = Padding(2, 2, 0, 0);
				border_.width = 1;
				border_.color = clGray;
				flags.wordWrap = false;
		
				super(markup, ts);
			}
		
		}
		
		
		class WinRow : Row{ //WinRow ///////////////////////////////
		
			this(string markup, TextStyle ts = tsNormal){
				padding_ = Padding(4, 16, 4, 16);
		
				super(markup, ts);
			}
		
			this(Cell[] cells, TextStyle ts = tsNormal){
				padding_ = Padding(4, 16, 4, 16);
		
				super(cells, ts);
			}
		
			override{
			}
		}
		
	+/
	version(/+$DIDE_REGION Graph+/all)
	{
		class GraphLabel(Node) : Row
		{
			 //GraphLabel /////////////////////////////
			Node parent; 
			bool isReference; //a non reference is the caption of the definition
			string name; 
			
			this()
			{} 
			
			this(Node parent, bool isReference, string name, string caption, in TextStyle ts)
			{
				this.name = name; 
				this.parent = parent; 
				this.isReference = isReference; 
				appendStr(caption, ts); 
			} 
			
			this(Node parent, bool isReference, string name, in TextStyle ts)
			{ this(parent, isReference, name, name, ts); } 
			
			this(Node parent, bool isReference, string name)
			{
					//Todo: this is for languageGraph only
				auto ts = tsNormal; 
				ts.applySyntax(isReference ? SyntaxKind.Whitespace : SyntaxKind.BasicType); 
				ts.underline = isReference; 
				ts.italic = true; 
				this(parent, isReference, name, ts); 
			} 
			
			auto absOuterBounds() const
			{ return innerBounds + parent.absInnerPos; } 
			auto absOutputPos	 () const
			{ return absOuterBounds.rightCenter; } 
			auto absInputPos	 () const
			{ return absOuterBounds.leftCenter; } 
		} 
		
		class GraphNode(Graph, Label) : Row
		{
			mixin CachedDrawing; 
			
			Graph parent; 
			
			this(Graph parent)
			{
				this.parent = parent; 
				flags._measureOnlyOnce = true; 
			} 
			
			bool isSelected, oldSelected; 
			bool isHovered()
			{ return this is parent.hoveredNode; } 
			
			string groupName_original; 
			string groupName_override; 
			string groupName() const
			{ return groupName_override.length ? groupName_override : groupName_original; } 
			
			string fullName() const
			{ return groupName ~ "/" ~ name; } 
			
			auto labels	  ()
			{ return subCells.map!(a => cast(Label)a).filter!"a"; } 
			auto targets	  ()
			{ return labels.filter!(a => !a.isReference); } 
			auto references()
			{ return labels.filter!(a =>  a.isReference); } 
			
			Label nameLabel()
			{
				pragma(msg, Label, typeof(this)); 
				foreach(t; targets)
				return t; return null; 
			} 
			
			string name() const
			{
					//default implementation
				foreach(t; (cast()this).targets)
				return t.name; 
				ERR("Unable to get default name. Should override GraphNode.name()."); 
				return ""; 
			} 
			
			auto absInnerBounds() const
			{ return innerBounds + parent.innerPos; } 
			auto absInnerPos   () const
			{ return innerPos    + parent.innerPos; } 
		} 
		
		class ContainerGraph(Node : Cell, Label : GraphLabel!Node) : Container
		{
			 //ContainerGraph ///////////////////////////////////////////
			bool showSelection = true; 
			
			static assert(
				__traits(
					compiles, {
						Node n; string s = n.groupName; //this could be optional.
					}
				), "Field requirements not met."
			); 
			
			SelectionManager!Node selection; 
			
			bool invertEdgeDirection; 
			float groupMargin = 30; 
			
			auto nodes        ()
			{ return cast(Node[])subCells; } //Note: all subcells' type must be Node
			auto selectedNodes()
			{ return nodes.filter!(a => a.isSelected); } 
			auto hoveredNode  ()
			{ return selection.hoveredItem; } 
			
			private Node[string] nodeByName; 
			
			auto findNode(string name)
			{ auto a = name in nodeByName; return a ? *a : null; } 
			
			Node addNode(string name, Node node)
			{
				enforce(cast(Node)node !is null     , "addNode() param must be an instance of "~Node.stringof       ); 
				enforce(name.length                 , "Name must be non-empty."                                     ); 
				enforce(findNode(name) is null      , "Node named "~name.quoted~" already exists"                   ); 
				//enforce(!node.parent                , "Node already has a parent."                                  ); 
				
				const bnd = allBounds; 
				const nextPos = bnd.valid ? bnd.bottomLeft + vec2(0, 32) : vec2(0); 
				node.outerPos = nextPos; 
				
				nodeByName[name] = node; 
				append(node); //this is Container.append()
				return node; 
			} 
			
			Node findAddNode(string name, lazy Node node)
			{
				if(auto n = findNode(name))
				return n; 
				return addNode(name, node/+lazy!!!+/); 
			} 
			
			bool removeNode(Node node)
			{
				const oldLen = subCells.length; 
				subCells = subCells.filter!(c => c !is node).array; //Todo: use remove()
				if(subCells.length < oldLen)
				{
					nodeByName.remove(node.name); 
					selection.notifyRemove(node); 
					return true; 
				}else
				return false; 
			} 
			
			bool removeNode(string name)
			{
				if(auto node = findNode(name))
				{
					removeNode(node); 
					return true; 
				}else
				return false; 
			} 
			
			auto removeNodes(R)(R nodes) if(isInputRange!R && is(ElementType!R == Node))
			{ return nodes.count!(n => removeNode(n)).to!int; } 
			
			auto removeNodes(string nameFilter)
			{ return nodes.filter!(n => n.name.isWild(nameFilter)); } 
			
			Node toggleNode(string name, lazy Node node)
			{
				if(removeNode(name))
				return null; 
				else	return addNode(name, node/+lazy!!!+/); 
			} 
			
			void removeAll()
			{
				subCells = []; 
				nodeByName.clear; 
				selection.notifyRemoveAll; 
			} 
			
			auto nodeGroups()
			{ return nodes.dup.sort!((a, b) => a.groupName < b.groupName).groupBy; } //note .dup is important because .sort works in-place.
			
			auto groupBounds()
			{
				return nodeGroups.filter!(g => g.front.groupName!="")          //exclude unnamed groups
								 .map!(
					grp => grp.map!(a => a.outerBounds)
														 .fold!"a|b"
				); 
			} 
			
			auto allBounds()
			{
				return nodes.map!(n => n.outerBounds)
							.fold!"a|b"(bounds2.init); 
			} 
			
			
			Container.SearchResult[] searchResults; 
			bool searchBoxVisible; 
			string searchText; 
			
			//inputs from outside
			private
			{
				float viewScale = 1; //used for automatic screenspace linewidth
				vec2[2] searchBezierStart; //first 2 point of search bezier lines. Starting from the GUI matchCount display.
			} 
			
			this()
			{
				bkColor = clBlack; 
				selection = new typeof(selection); 
			} 
			
			struct Link
			{ Label from; Node to; } 
			Link[] _links; 
			
			auto links()
			{
				if(_links.empty)
				foreach(d; nodes)
				foreach(from; d.labels)
				if(from.isReference)
				if(auto to = findNode(from.name))
				_links ~= Link(from, to); 
				return _links; 
			} 
			
			void update(View2D view, vec2[2] searchBezierStart)
			{
				this.viewScale = view.scale; 
				this.searchBezierStart = searchBezierStart; 
				
				selection.update(!im.wantMouse, view, subCells.map!(a => cast(Node)a).array); 
			} 
			
			//drawing routines ////////////////////////////////////////////
			
			protected void drawSearchResults(Drawing dr, RGB clSearchHighLight)
			{
				with(dr)
				{
					 //this is copied to dide2
					foreach(sr; searchResults)
					sr.drawHighlighted(dr, clSearchHighLight); 
					
					lineWidth = -2 * sqr(sin(QPS.value(second).fract*PIf*2)); 
					alpha = 0.66; 
					color = clSearchHighLight; 
					foreach(sr; searchResults)
					bezier2(searchBezierStart[0], searchBezierStart[1], sr.absInnerPos + sr.cells.back.outerBounds.rightCenter); 
					
					alpha = 1; 
				}
			} 
			
			protected void drawSelectedItems(Drawing dr, RGB clSelected, float selectedAlpha, RGB clHovered, float hoveredAlpha)
			{
				with(dr)
				{
					color = clSelected; alpha = selectedAlpha; 	 foreach(a; selectedNodes)
					dr.fillRect(a.outerBounds); 
					color = clHovered; alpha = hoveredAlpha; 	 if(hoveredNode !is null)
					dr.fillRect(hoveredNode.outerBounds); 
					alpha = 1; 
				}
			} 
			
			protected void drawSelectionRect(Drawing dr, RGB clRect)
			{
				if(auto bnd = selection.selectionBounds)
				with(dr)
				{
					lineWidth = -1; 
					color = clRect; 
					drawRect(bnd); 
				}
			} 
			
			protected void drawGroupBounds(Drawing dr, RGB clGroupFrame)
			{
				with(dr)
				{
					color = clGroupFrame; 
					lineWidth = -1; 
					foreach(bnd; groupBounds)
					drawRect(bnd.inflated(groupMargin)); 
				}
			} 
			
			protected void drawLinks(Drawing dr)
			{
				with(dr)
				{
					/+
							alpha = 0.66;
							foreach(link; links){
								const h1 = link.from.parent.isHovered, h2 = link.to.isHovered;
						
								//hide interGroup links
								if(!h1 && !h2 && link.from.parent.groupName != link.to.groupName) continue;
						
								color	 = h1 && !h2 ? clAqua
						 : h2 && !h1 ? clLime
																	 : clSilver;
						
								lineWidth = viewScale>1 ? 1 : -1; //line can't be thinner than 1 pixel, but can be thicker
						
								//OutputPos = rightCenter, InputPos = leftCenter
						
								vec2 P0, P1, P2, P3, P4, ofs;
								if(!invertEdgeDirection){ //arrows go the the right. It's good for a grammar graph
									P0 = link.from.absOutputPos; P4 = link.to.nameLabel.absInputPos;
									float a = min(50, distance(P0, P4)/3);
									ofs = P0.x<P4.x ? vec2(a, 0) : vec2(a, -a);
								}else{ //arrows go to the left. Good for module hierarchy. Rightmost module is the main project.
									P0 = link.from.absInputPos; P4 = link.to.nameLabel.absOutputPos;
									float a = min(50, distance(P0, P4)/3);
									ofs = P0.x>P4.x ? vec2(-a, 0) : vec2(-a, -a);
								}
								P1 = P0 + ofs,
								P3 = P4 + ofs*vec2(-1, 1),
								P2 = avg(P1, P3);
								bezier2(P0, P1, P2);
								bezier2(P2, P3, P4);
						
							}
							alpha = 1; 
					+/
				}
			} 
			
			protected void drawOverlay(Drawing dr)
			{
				with(dr)
				{
					drawLinks(dr); 
					if(showSelection)
					drawSelectedItems(dr, clAccent, 0.25, clWhite, 0.2); 
					drawSelectionRect(dr, clWhite); 
					drawGroupBounds(dr, clSilver); 
					drawSearchResults(dr, clYellow); 
				}
			} 
			
			override void draw(Drawing dr)
			{
				super.draw(dr); //draw cached stuff
				
				auto dr2 = dr.clone; 
				drawOverlay(dr2); //draw uncached stuff on top
				dr.subDraw(dr2); 
			} 
			
			void UI_SearchBox(View2D view)
			{
					//UI SearchBox ////////////////////////////////
				with(im)
				Row(
					{
						//Keyboard shortcuts
						auto kcFind	= KeyCombo("Ctrl+F"),
								 kcFindZoom	= KeyCombo("Enter"), //only when edit is focused
								 kcFindClose	= KeyCombo("Esc"); //always
						
						if(kcFind.pressed)
						searchBoxVisible = true; //this is needed for 1 frame latency of the Edit
						//Todo: focus on the edit when turned on
						if(searchBoxVisible)
						{
							width = fh*12; 
							
							Text("Find "); 
							.Container editContainer; 
							if(Edit(searchText, kcFind, { flex = 1; editContainer = actContainer; }))
							{
								//refresh search results
								searchResults = search(searchText); 
							}
							
							//display the number of matches. Also save the location of that number on the screen.
							const matchCnt = searchResults.length; 
							Row(
								{
									if(matchCnt)
									Text(" ", clGray, matchCnt.text, " "); 
								}
							); 
							
							if(Btn(symbol("Zoom"), isFocused(editContainer) ? kcFindZoom : KeyCombo(""), enable(matchCnt>0), hint("Zoom screen on search results.")))
							{
								const maxScale = max(view.scale, 1); 
								view.zoom(searchResults.map!(r => r.bounds).fold!"a|b", 12); 
								view.scale = min(view.scale, maxScale); 
							}
							
							if(Btn(symbol("ChromeClose"), kcFindClose, hint("Close search box.")))
							{
								searchBoxVisible = false; 
								searchText = ""; 
								searchResults = []; 
							}
						}else
						{
							
							if(Btn(symbol("Zoom"       ), kcFind, hint("Start searching.")))
							{
								searchBoxVisible = true; //Todo: Focus the Edit control
							}
						}
					}
				); 
			} 
			
			//scroller state
			Node actNode; //state
			auto topIndex = 0; //state
			enum pageSize = 10; 
			
			void UI_Editor()
			{
				alias GraphNode = Node; /*Todo: fucking name collision with im.Node */   
				with(im)
				{
					 //UI_Editor ///////////////////////////////////
					//WildCard filter
					static hideUI = true; 
					static filterStr = ""; 
					Row({ ChkBox(hideUI, "Hide Graph UI "); }); 
					
					if(!hideUI)
					{
						
						  Row({ Text("Filter "); Edit(filterStr, { flex = 1; }); }); 
						
							 //filtered data source
							 auto filteredNodes = nodes.filter!(a => a.name.isWild(filterStr~"*")).array; 
							 ScrollListBox(actNode, filteredNodes, (in GraphNode n){ Text(n.name); width = 260; }, pageSize, topIndex); 
						
							 Spacer; 
							 Row(
							{
								auto selected = selectedNodes.array; 
								Row({ Text("Selected items: "), Static(selected.length), Text("  Total: "), Static(nodes.length); }); 
								
								const selectedGroupNames = selected.map!(a => a.groupName).array.sort.uniq.array; 
								static string editedGroupName; 
								Row(
									{
										Text("Selected groups: "); 
										foreach(i, name; selectedGroupNames)
										if(Btn(name, genericId(i)))
										editedGroupName = name; 
									}
								); 
								
								Spacer; 
								Row(
									{
										Text("Group name os felected items: \n"); 
										Edit(editedGroupName, { width = 200; }); 
										if(Btn("Set", enable(selected.length>0)))
										foreach(a; selected)
										a.groupName_override = editedGroupName; 
									}
								); 
								
							}
						); 
						
							 Spacer; 
							 if(Btn("test"))
						{}
						
					}
				}
			} 
			
		} 
	}
}
version(/+$DIDE_REGION Dead code 260813+/none)
{
	auto Static_old(string _M_=__MODULE__, size_t _L_=__LINE__, T0, T...)(in T0 value, T args)
	{
		static if(is(T0 : Property))
		{
			auto p = cast(Property)value; 
			Static!(_M_, _L_)(p.asText, hint(p.hint), args); 
		}
		else
		{
			Row!(_M_, _L_)
			(
				{
					mixin(prepareId); 
					actContainer.id = id_; 
					auto hit = hitTest(enabled); 
					
					mixin(hintHandler); 
					applyEditStyle(true, false, 0); 
					style = tsNormal; 
					
					border.color = mix(border.color, style.bkColor, .5f); 
					
					static if(std.traits.isNumeric!T0)
					flags.hAlign = HAlign.right; 
					else flags.hAlign = HAlign.left; 
					
					static if(__traits(compiles, value()))
					value(); 
					else Text(value.text); 
					
					static foreach(a; args)
					static if(__traits(compiles, a()))
					a(); 
					
					//set minimal height for the control if empty
					if(actContainer.subCells.empty && innerHeight<=0)
					innerHeight = fh; 
				}
			); 
		}
	} 
	
	
	auto Btn0(string _M_=__MODULE__, size_t _L_=__LINE__, bool isWhite=false, T0, T...)(T0 text, T args)
		if(isSomeString!T0 || __traits(compiles, text()) )
	{
		mixin(prepareId, selected.M); 
		
		bool focusOnPress = false; 
		mixin(processGenericArgs(q{static if(N=="focusOnPress")	focusOnPress = a; })); 
		
		const isToolBtn = theme=="tool"; 
		
		HitInfo hit; 
		
		Row(
			{
				actContainer.id = id_; 
				hit = hitTest(enabled); 
				mixin(hintHandler); 
				
				bool focused = focusUpdate
				(
					actContainer, id_,
					enabled, ((focusOnPress)?(hit.pressed) :(hit.clicked)), inputs.Esc.pressed,  //enabled, enter, exit
					/*onEnter	*/ {},
					/*onFocus	*/ {},
					/*onExit	*/ {}
				); 
				
				//flags.wordWrap = false;
				flags.hAlign = HAlign.center; 
				
				applyBtnStyle(isWhite, enabled, focused, _selected, hit.captured, hit.hover_smooth); 
				
				static if(isSomeString!T0)
				Text(text); 
				else text();  static foreach(a; args)
				static if(__traits(compiles, a()))
				a(); 
			}
		); 
		
		//KeyCombo in click mode.
		static foreach(a; args)
		static if(is(typeof(a) == KeyCombo))
		if(canProcessUserInput && a.pressed)
		hit.clicked = true; 
		
		return hit; 
	} 
	
	version(/+$DIDE_REGION+/all) {
		auto Btn1(string _M_=__MODULE__, size_t _L_=__LINE__, bool isWhite=false, Args...)(in Args args)
		{
			
			CustomContainer!
			(
				.Row, 
				
				/+Local variable declarations+/
				q{
					bool focusOnPress, _selected; 
					const isToolBtn = theme=="tool"; 
					HitInfo hit; 
				},
				
				//Property declarations
				(表([
					[q{isG!"focusOnPress"},q{focusOnPress = a; }],
					[q{isG!"selected"},q{_selected = a; }],
					[q{isT!selected},q{_selected = a.val; }],
					[q{isT!HintRec},q{/+Todo: hintHandler+/}],
					[q{isT!range},q{/+Todo: IncBtn!!!+/}],
				])),
				
				//After properties, before composition
				q{
					hit = hitTest(enabled); 
					//Todo: mixin(hintHandler); 
					
					bool focused = focusUpdate
					(
						actContainer, id_,
						enabled, ((focusOnPress)?(hit.pressed) :(hit.clicked)), inputs.Esc.pressed,  //enabled, enter, exit
						/*onEnter	*/ {},
						/*onFocus	*/ {},
						/*onExit	*/ {}
					); 
					
					//flags.wordWrap = false;
					flags.hAlign = HAlign.center; 
					
					applyBtnStyle(
						false/+Todo: isWhite+/, enabled, focused, 
						_selected, hit.captured, hit.hover_smooth
					); 
				}, 
				
				//Composition
				(表([[],])), 
				
				//After composition, finalization
				q{}
			)
			(Id(_M_, _L_), args); 
			
			HitInfo hit;  //Todo: hit
			//Todo: keycombo
			
			return hit; 
		} 
		
	}
	auto Edit_old(string _M_=__MODULE__, size_t _L_=__LINE__, T0, T...)(ref T0 value, T args)
	{
		/+
			Solved 260813:
			NOTIMPL("Doube precision View2D bug: Clicking at any position seeks only to the beginning os text."); 
		+/
		
		static if(is(T0==Path))
		return EditPath!(_M_, _L_)(value, args); //Todo: not good! There will be 2 returns!!!
		static if(is(T0==File))
		return EditFile!(_M_, _L_)(value, args); //Todo: not good! There will be 2 returns!!!
		
		enum IsNum = std.traits.isNumeric!T0; 
		
		mixin(prepareId); 
		static if(IsNum)
		mixin(range_M); 
		
		static struct EditResult
		{
			HitInfo hit; 
			bool changed, focused; 
			alias changed this; 
		} 
		EditResult res; 
		
		void value2editor()
		{ textEditorState.str = value.text; } 
		
		bool wasConvertError; //editor2value messaging back with this
		
		void editor2value()
		{
			try
			{
				auto newValue = textEditorState.str.to!T0;  //Todo: range clamp
				
				static if(IsNum)
				{
					auto clamped = _range.clamp(newValue); 
					wasConvertError = clamped != newValue; 
					newValue = clamped; 
				}
				
				res.changed = newValue != value; 
				value = newValue; 
			}catch(Exception)
			{ wasConvertError = true; }
		} 
		
		Row(
			{
				actContainer.id = id_; 
				
				auto ref hit()
				{ return res.hit; } 
				
				flags.clipSubCells = true; 
				auto row = cast(.Row)actContainer; 
				
				hit = hitTest(enabled); 
				
				mixin(hintHandler); 
				
				bool focusEnter; 
				mixin(
					processGenericArgs(
						q{
							static if(N=="focusEnter")
							focusEnter = a; 
						}
					)
				); 
				
				//const focusEnter = getGenericArg!(args, bool, "focusEnter");
				
				/+
					Note: This would be the implementation with a struct: 
					static foreach(a; args) static if(is(typeof(a) == ManualFocus)) manualFocus = a.value;
				+/
				//The downside is that the struct litters the namespace with simple names.
				/+
					220820: this is too specific. Use the ManualFocus parameter instead. 
						static foreach(a; args) static if(is(typeof(a) == KeyCombo)) if(a.pressed) manualFocus = true;
				+/
				
				const focused = focusUpdate
					(
					actContainer, id_,
					enabled,
					hit.pressed || focusEnter, //enter
					inputs["Esc"].pressed,  //exit
					/*onEnter*/ {
						value2editor; 
						
						//must override the previous value from another edit
						//Todo: this must be rewritten with imStorage bounds.
						textEditorState.cmdQueue ~= EditCmd(EditCmd.cEnd); 
						
						//for keyboard entry: textEditorState.cmdQueue ~= EditCmd(EditCmd.cEnd);
					},
					/*onFocus	*/ {/*_EditHandleInput(value, textEditorState.str, chg);*/},
					/*onExit	*/ {}
				); 
				res.focused = focused; 
				
				static if(std.traits.isNumeric!T0)
				flags.hAlign = HAlign.right; 
				else flags.hAlign = HAlign.left; 
				
				applyEditStyle(enabled, focused, hit.hover_smooth); 
				
				//text editor functionality
				if(focused)
				{
					editor2value; //Todo: when to write back? always / only when change/exit?
					
					textEditorState.row = row; 
					textEditorState.strModified = false; //ready for next modifications
					
					const localMouse = hit.hover ? 
						vec2(targetView.mousePos) - hit.hitBounds.topLeft - row.topLeftGapSize : vec2(0); 
					//Todo: this is not when dr and drGUI is used concurrently. currentMouse id for drUI only.
					
					((0x53FEBEB16D5C4).檢(hit.toJson)); 
					
					
					((0x54025EB16D5C4).檢(localMouse)); 
					
					
					textEditorState.handleKeyboardInput	(mainWindow.inputChars, flags.acceptEditorKeys, localMouse); 
				}
				
				if(focused)
				flags.dontHideSpaces = true; 
				
				
				//execute the delegate funct parameters
				static foreach(a; args)
				static if(__traits(compiles, a()))
				{ a(); }
				
				//put the text out
				if(focused)
				{
					if(wasConvertError) textStyle.fontColor = clRed; 
					row.appendMarkupLine(textEditorState.str, textStyle, textEditorState.cellStrOfs); 
				}
				else { row.appendMarkupLine(value.text         , textStyle); }
				
				//get default fontheight for the editor after the (possibly empty) string was displayed
				const fh = style.fontHeight; 
				
				//set editor's defaultFontHeight for the caret when the string is empty
				if(focused)
				textEditorState.defaultFontHeight = fh; 
				
				//set minimal height for the control
				if(row.empty && row.innerHeight<=0)
				{ row.innerHeight = fh; }
			}
		); 
		
		return res; //a hit testet vissza kene adni im.valtozoban
	} 
	auto IncBtn_old(string _M_=__MODULE__, size_t _L_=__LINE__, int sign=1, Value, Args...)
		(ref Value value, in Args args)
		if(sign!=0 && isNumeric!Value)
	{
		mixin(range_M); 
		
		auto capt = symbolStr(`Calculator` ~ ((sign>0)?(`Addition`) :(`Subtract`))); 
		enum isInt = isIntegral!Value; 
		
		auto hit = Btn!(_M_, _L_)(capt, args, ((sign).名!q{id})); 
		//2 id's can pass because of the static foreach
		
		bool chg; 
		if(hit.repeated)
		{
			auto 	oldValue 	= value,
				step 	= abs(_range.step),
				newValue 	= _range.clamp(value+step*sign); 
			
			if(isInt)
			value = cast(Value)(round(newValue)); 
			else value = cast(Value)newValue; 
			
			chg = newValue != oldValue; 
		}
		
		return chg; 
	} 
	
	auto DecBtn_old(string _M_=__MODULE__, size_t _L_=__LINE__, Value, Args...)
		(ref Value value, in Args args)
	{ return IncBtn!(_M_, _L_, -1)(value, args); } 
	
	auto LedBtn_old(string _M_=__MODULE__, size_t _L_=__LINE__, T, Args...)(void delegate() ledFun, T caption, in Args args)
	{
		return Btn!(_M_, _L_)(
			{
				flags.hAlign = HAlign.left; 
				ledFun(); 
				if(actContainer.subCells.length)
				Spacer(fh*0.25f); 
				width = 3.5*fh; 
				static if(isSomeString!T)
				Text(caption); 
				else caption(); 
			}, args
		); 
	} 
	
	auto LedBtn_old(string _M_=__MODULE__, size_t _L_=__LINE__, T, Args...)(bool ledState, RGB ledColor, T caption, in Args args)
	{
		return LedBtn_old!(_M_, _L_)(
			{
				if(ledColor!=clBlack)
				{ flags.hAlign = HAlign.left; Led(ledState, ledColor); }
			}, caption, args
		); 
	} 
	
	auto Link(string _M_=__MODULE__, size_t _L_=__LINE__, T0, T...)(T0 text, T args)
		if(isSomeString!T0 || __traits(compiles, text()) )
	{
		mixin(prepareId); 
		
		HitInfo hit; 
		
		Row(
			{
				actContainer.id = id_; 
				hit = hitTest(imEnabled); 
				
				mixin(hintHandler); 
				
				bool focused = focusUpdate	(
					actContainer, id_, imEnabled, 
					hit.pressed, inputs.Esc.pressed
				); 
				
				//handle the space key when focused
				if(focused)
				{
					with(inputs.Space)
					{
						if(down)
						hit.captured	= true; 
						if(pressed)
						hit.clicked	= true; 
					}
				}
				
				applyLinkStyle(imEnabled, focused, hit.captured, hit.hover_smooth); 
				
				static if(isSomeString!T0)
				Text(text); 
				else text(); 
				 //delegate
				
				static foreach(a; args)
				static if(__traits(compiles, a()))
				a(); 
			}
		); 
		
		//KeyCombo in click mode.
		static foreach(a; args)
		static if(is(typeof(a) == KeyCombo))
		if(canProcessUserInput && a.pressed)
		hit.clicked = true; 
		
		return hit; 
	} 
	
	auto ChkBox(string _M_=__MODULE__, size_t _L_=__LINE__, string chkBoxStyle="chk", C, T...)(ref bool state, C caption, T args)
	{
		mixin(prepareId); 
		
		HitInfo hit; 
		Row(
			{
				flags.wordWrap = false; 
				margin.left = margin.right = 2; 
				
				actContainer.id = id_; 
				hit = hitTest(imEnabled); 
				mixin(hintHandler); 
				
				//update checkbox state
				if(imEnabled && hit.clicked)
				state.toggle; 
				
				//mixin GetChkBoxColors;
				RGB hoverColor(RGB baseColor, RGB bkColor)
				{
					return !imEnabled 	? clWinBtnDisabledText
						: mix(baseColor, bkColor, hit.captured ? 0.5f : hit.hover_smooth*0.3f); 
				} 
				
				auto markColor = hoverColor(state ? clAccent : style.fontColor, style.bkColor); 
				auto textColor = hoverColor(style.fontColor, style.bkColor); 
				
				auto bullet = chkBoxStyle=="radio" 	? tag(`symbol RadioBtn`~(state?"On":"Off"))
					: tag(`symbol Checkbox`~(state?"CompositeReversed":"")); 
				
				//Text(format(tag("style fontColor=\"%s\"")~bullet~" "~tag("style fontColor=\"%s\"")~caption, markColor, textColor));
				
				static if(__traits(compiles, caption==""))	const captionIsEmpty = caption==""; 
				else	enum captionIsEmpty = false; 
				
				if(captionIsEmpty)	Text(markColor, bullet); 
				else	Text(markColor, bullet, " ", textColor, caption); 
				
				static foreach(a; args) static if(__traits(compiles, a())) a(); 
			}
		); 
		
		return hit; 
	} 
	
	auto ChkBox(string _M_=__MODULE__, size_t _L_=__LINE__, string chkBoxStyle="chk", T...)(Property prop, string caption, T args)
	{
		auto bp = cast(BoolProperty)prop; 
		enforce(bp !is null); 
		auto last = bp.act; 
		auto res = ChkBox!(_M_, _L_)(bp.act, caption.empty ? prop.caption : caption, genericId(prop.name), hint(prop.hint), args); 
		bp.uiChanged |= last != bp.act; 
		return res; 
	} 
	
	auto RadioBtn(string _M_=__MODULE__, size_t _L_=__LINE__, C, T...)(ref bool state, C caption, T args)
	{ return ChkBox!(_M_, _L_, "radio")(state, caption, args); } 
	
	version(/+$DIDE_REGION+/none) {
		auto Slider_old(string _M_=__MODULE__, size_t _L_=__LINE__, V, T...)(ref V value, T args)
			if(isFloatingPoint!V || isIntegral!V)
		{
			mixin(prepareId, selected_M, range_M);  //Todo: selected???
			
			//flipped range interval. Needed for vertical scrollbar
			const flipped = !_range.isOrdered; 
			if(flipped)
			swap(_range.min, _range.max); 
			
			//string props;
			static foreach(a; args)
			{
				{
					alias t = Unqual!(typeof(a)); 
					static if(isSomeString!t)
					{
						//props = a; //todo: ennek is
						static assert(0, "string parameter in Slider is deprecated. Use {} delegate instead!"); 
					}
				}
			}
			
			float normValue = _range.normalize(flipped ? _range.max-value : value); 
			
			int wrapCnt; 
			if(_range.isEndless)
			{
				wrapCnt = normValue.floor.iround;  //Todo: refactor endless wrapCnt stuff
				normValue = normValue-normValue.floor; 
			}
			
			bool userModified; 
			HitInfo hit; 
			auto sl = new .Slider(
				id_, imEnabled, normValue, _range, userModified, targetView.mousePos.vec2, 
				style, hit, getStaticParamDef(SliderOrientation.auto_, args), 
				getStaticParamDef(SliderType.slider, args), theme.isTool ? 1 : 1.4f
			); 
			
			append(sl); push(sl, id_); scope(exit) pop; 
			
			mixin(hintHandler); 
			static foreach(a; args)
			static if(__traits(compiles, a()))
			a(); 
			
			//Todo: args hanfling is bad here! only handles delegates. Ignored named parameters!
			
			if(userModified && imEnabled)
			{
				
				if(_range.isEndless)
				normValue += wrapCnt-sl.wrapCnt; 
				
				float f = _range.denormalize(normValue); 
				static if(isIntegral!V)
				f = round(f); 
				value = f.to!V; 
				if(flipped)
				value = (_range.max-value).to!V; //UNFLIP
			}
			
			return userModified; 
		} 
	}
	
	version(/+$DIDE_REGION+/none) {
		this(
			in im.Id id, bool enabled, ref float nPos_, in ValueRange range_, ref bool userModified, vec2 mousePos, 
			TextStyle ts, out im.HitInfo hit, Orientation orientation, Type type, float fhScale, float normThumbSize=float.init
		)
		{
			this.id = id; 
			this.orientation = orientation; 
			this.type = type; 
			this.nPos = enabled ? nPos_ : nPos_/+float.init+//+Todo: hideThumb option+/; 
			this.normThumbSize = normThumbSize; 
			
			if(type==Type.scrollBar) padding = "2"; 
			
			hit = im.hitTest(this, enabled); 
			hitBounds = hit.hitBounds; 
			
			if(1 || type==Type.slider)
			focused = im.focusUpdate(
				this, id, enabled,
				hit.pressed || hit.hover && inputs.RMB.pressed, //when to enter
				inputs.Esc.pressed,  //when to exit
			); 
			
			//res.focused = focused;
			
			if(focused && im.canProcessUserInput)
			userModified |= im.sliderState.handleKeyboard(nPos, range_, 8); 
			
			bkColor = ts.bkColor; 
			const hoverOrFocus = enabled ? max(hit.hover_smooth*.5f, focused ? 1.0f : 0) : 0; 
			
			final switch(type)
			{
				case Type.slider: 
					clThumb =	mix(mix(clSliderThumb, clSliderThumbHover, hoverOrFocus), clSliderThumbPressed, hit.captured_smooth); 
					clLine =	mix(mix(clSliderLine , clSliderLineHover , hoverOrFocus), clSliderLinePressed , hit.captured_smooth); 
					clRuler = clGray/+mix(bkColor, ts.fontColor, 0.5)+/; //disable ruler for now
					
					if(focused) { clThumb = clBlack; clLine = clBlack; }//Todo: lame logic
					
					rulerSides = 0; 
				break; 
				case Type.scrollBar: 
					clThumb = mix(clScrollThumb, clScrollThumbPressed, hoverOrFocus); 
					bkColor = mix(clScrollBk, clScrollThumb, min(hoverOrFocus, .5f)); 
					
					if(focused) { clThumb = clBlack; }//Todo: lame logic
					
					//clThumb = mix(clWinBtn, clWinBtnPressed, max(hit.hover_smooth*.5f, sliderState.pressed_id==id ? 1 : 0));
					rulerSides = 0; 
				break; 
			}
			
			if(!enabled)
			clLine = clThumb = clGray; //Todo: nem clGray ez, hanem clDisabledText vagy ilyesmi
			
			baseSize = ts.fontHeight*fhScale*0.8f; 
			outerSize = vec2(baseSize*6, baseSize); //default size
			
			userModified |= im.sliderState.handleMouse(id, hit, nPos, mousePos, range_, wrapCnt); 
			
			if(userModified)
			nPos_ = nPos; 
		} 
		
		this(
			in im.Id id, bool enabled, ref float nPos_, in ValueRange range_, ref bool userModified, vec2 mousePos, 
			TextStyle ts, out im.HitInfo hit, Orientation orientation, Type type, float fhScale, float normThumbSize=float.init
		)
		{
			this.id = id; 
			this.orientation = orientation; 
			this.type = type; 
			this.nPos = enabled ? nPos_ : nPos_/+float.init+//+Todo: hideThumb option+/; 
			this.normThumbSize = normThumbSize; 
			
			if(type==Type.scrollBar) padding = "2"; 
			
			hit = im.hitTest(this, enabled); 
			hitBounds = hit.hitBounds; 
			
			bool focused; 
			if(1 || type==Type.slider)
			focused = im.focusUpdate(
				this, id, enabled,
				hit.pressed || hit.hover && inputs.RMB.pressed, //when to enter
				inputs.Esc.pressed,  //when to exit
			); 
			
			//res.focused = focused;
			
			if(focused && im.canProcessUserInput)
			userModified |= im.sliderState.handleKeyboard(nPos, range_, 8); 
			
			bkColor = ts.bkColor; 
			setupAppearance(enabled, focused, hit.hover_smooth, hit.captured_smooth, ts.fontHeight*fhScale*0.8f); 
			
			userModified |= im.sliderState.handleMouse(id, hit, nPos, mousePos, range_, wrapCnt); 
			
			if(userModified)
			nPos_ = nPos; 
		} 
	}
	version(/+$DIDE_REGION+/none) {
		void createBars(bool doPurge)
		{
			assert(orientation.among('H', 'V')); 
			
			Id[] toRemove; 
			foreach(id, ref info; infos)
			{
				if(info.lastAccess<application.tick)
				{
					if(doPurge) toRemove ~= id; 
					continue; 
				}
				const exists 	= (orientation=='H' && info.container.flags.hasHScrollBar)
					|| (orientation=='V' && info.container.flags.hasVScrollBar); 
				if(!exists) continue; 
				
				bool enabled; 
				float normValue; 
				float normThumbSize; 
				float activeRange = info.contentSize - info.pageSize; 
				
				const flip = orientation=='V'; 
				void doFlip()
				{ if(flip) normValue = 1-normValue; } 
				
				if(activeRange > 0.001f)
				{
					//restrict range
					info.offset.minimize(activeRange); 
					info.offset.maximize(0); 
					
					enabled = true; 
					normValue = info.offset/activeRange; 
					normThumbSize = info.pageSize/info.contentSize; 
					
					doFlip; 
				}else
				{
					info.offset = 0; //no active range, so just reset it to 0
				}
				
				bool userModified; 
				HitInfo hit; 
				/+
					Todo: scrollbars only work on GUI surface. This flag shlould be inherited automatically, 
							just like the upcoming enabled flag.
				+/
				auto sl = new .Slider
					(
					combine(info.container.id, orientation), enabled, normValue, 
					linRange(0, 1), userModified, view_gui.mousePos.vec2, tsNormal, hit,
					orientation=='H' ? SliderOrientation.horz : SliderOrientation.vert, 
					SliderType.scrollBar, 1, normThumbSize
				); 
				/+
					Code: this(
						in im.Id id, bool enabled, ref float nPos_, in ValueRange range_, ref bool userModified, vec2 mousePos, 
						TextStyle ts, out im.HitInfo hit, Orientation orientation, Type type, float fhScale, float normThumbSize=float.init
					)
					{
						this.id = id; 
						this.orientation = orientation; 
						this.type = type; 
						this.nPos = enabled ? nPos_ : nPos_/+float.init+//+Todo: hideThumb option+/; 
						this.normThumbSize = normThumbSize; 
						
						if(type==Type.scrollBar) padding = "2"; 
						
						hit = im.hitTest(this, enabled); 
						hitBounds = hit.hitBounds; 
						
						bool focused; 
						if(1 || type==Type.slider)
						focused = im.focusUpdate(
							this, id, enabled,
							hit.pressed || hit.hover && inputs.RMB.pressed, //when to enter
							inputs.Esc.pressed,  //when to exit
						); 
						
						//res.focused = focused;
						
						if(focused && im.canProcessUserInput)
						userModified |= im.sliderState.handleKeyboard(nPos, range_, 8); 
						
						bkColor = ts.bkColor; 
						setupAppearance(enabled, focused, hit.hover_smooth, hit.captured_smooth, ts.fontHeight*fhScale*0.8f); 
						
						userModified |= im.sliderState.handleMouse(id, hit, nPos, mousePos, range_, wrapCnt); 
						
						if(userModified)
						nPos_ = nPos; 
					} 
				+/
				
				info.slider = sl; 
				
				//set the position of the slider.
				//Todo: Because it's after hitTest, interaction will be delayed for 1 frame. But it should not.
				const scrollThickness = DefaultScrollThickness; //Todo: this is duplicated!!!
				with(info.container)
				if(orientation=='H')
				{
					sl.outerPos = vec2(0, innerHeight-scrollThickness); 
					sl.outerSize = vec2(innerWidth-((flags.hasVScrollBar) ?(scrollThickness):(0)), scrollThickness); 
				}
				else
				{
					sl.outerPos = vec2(innerWidth-scrollThickness, 0); 
					sl.outerSize = vec2(scrollThickness, innerHeight-((flags.hasHScrollBar) ?(scrollThickness):(0))); 
				}
				
				
				
				//Todo: the hitInfo is for the last frame. It should be processed a bit later
				if(userModified && enabled)
				{
					doFlip; 
					info.offset = normValue*activeRange; 
				}
			}
			
			//purge old ones
			foreach(id; toRemove) infos.remove(id); 
		} 
		/+
			Code: auto HRuler(string _M_=__MODULE__, size_t _L_=__LINE__, T, Args...)
				(
				const T tMin, const T tMax, ref T t0, ref T t1,
				Args args /+optional: /+Structured: &t0_smooth, &t1_smooth+/+/
			)
			{
				mixin(prepareId); bool userModified; 
				
				static if(is(T==DateTime))
				{
					{
						HitInfo hit; 
						
						enum isSmooth = Args.length>=2 	&& is(Args[0]==DateTime*) 
							&& is(Args[1]==DateTime*); 
						
						static if(isSmooth)
						{
							ref rangeFollower = ImStorage!(RangeFollower!DateTime).access(id_); 
							rangeFollower.beforeUpdate(false, t0, t1, tMin, tMax); 
						}
						
						auto ruler = new DateTimeRuler(
							id_, imEnabled, tMin, tMax, t0, t1,
							style, targetView.mousePos.vec2, userModified, hit
						); 
						
						static if(isSmooth)
						{
							rangeFollower.afterUpdate(userModified, t0, t1, calcAnimationT(deltaTime, .7)); 
							ruler.t0_draw = *(args[0]) = rangeFollower.smooth[0],
							ruler.t1_draw = *(args[1]) = rangeFollower.smooth[1]; 
						}
						else
						{
							ruler.t0_draw = t0,
							ruler.t1_draw = t1; 
						}
						
						append(ruler); push(ruler, id_); scope(exit) pop; 
						
						static foreach(a; args) static if(__traits(compiles, a())) a(); 
					}
				}
				else static assert(0, "Unsupported type: "~T.stringof); 
				
				return userModified; 
			} 
		+/
		
		void ScrollBox()
		{
			NOTIMPL; 
			version(/+$DIDE_REGION+/none) {
				Panel(
					DockAlignment.bottomClient,
					{
						margin = "0"; padding = "0"; //border = "1 normal gray";
						outerHeight = 200; 
						auto siz = innerSize; 
						Container
						(
							{
								outerSize = siz; 
								with(flags) {
									clipSubCells = true; 
									vScrollState = ScrollState.auto_; 
									hScrollState = ScrollState.auto_; 
								}
								
								if(auto mod = errorModule)
								{
									if(auto col = mod.content)
									{
										//total size placeholder
										Container({ outerPos = col.outerSize; outerSize = vec2(0); }); 
										
										flags.saveVisibleBounds = true; 
										if(auto visibleBounds = imstVisibleBounds(actId))
										{
											CodeRow[] visibleRows = col.rows.filter!(
												r => r.outerBounds.overlaps(visibleBounds)
												&& r.subCells.length
											).array; 
											//Opt: binary search
											
											actContainer.append(cast(Cell[])visibleRows); 
											//Note: append is important because it already has the spaceHolder Container.
										}
									}
									else
									WARN("Invalid errorList"); 
								}
							}
						); 
					}
				); 
			}
		} 
	}
	version(/+$DIDE_REGION+/none) {
		auto OldListItem(string _M_=__MODULE__, size_t _L_=__LINE__, T0, T...)(T0 text, T args)
			if(isSomeString!T0 || __traits(compiles, text()) )
		{
			mixin(prepareId, enable.M, selected_M); 
			
			//Todo: This is only the base of a listitem. Later it must communicate with a container
			
			HitInfo hit; 
			Row(
				{
					/+actContainer.id = id_; +/
					hit = hitTest(enabled); 
					
					style = tsNormal; //!!! na ez egy gridbol kell, hogy jojjon!
					
					margin = "0"; 
					auto bcolor = mix(style.fontColor, style.bkColor, .5f); 
					border	= Border(1, BorderStyle.normal, mix(bcolor, style.fontColor, hit.hover_smooth)); 
					border.inset	= true; 
					border.extendBottomRight = true; 
					padding = Padding(0, 2, 0, 2); 
					
					style.bkColor = mix(style.bkColor, clGray, hit.hover_smooth*.16f); 
					
					if(!enabled)
					{
						style.fontColor = mix(style.fontColor, clGray, 0.5f); 
						//Todo: rather use an 50% overlay for disabled?
					}
					
					if(_selected)
					{
						style.bkColor	= mix(style.bkColor, clAccent, .5f); 
						border.color	= mix(border.color , clAccent, .5f); 
					}
					
					bkColor = style.bkColor; 
					//Todo: update the backgroundColor of the container. Should be automatic, but how?...
					
					static if(isSomeString!T0)
					Text(text); 
					else text(); 
					 //delegate
				}
			); 
			
			return hit; 
		} 
	}
	version(/+$DIDE_REGION+/none) {
		auto ListBoxItem(string _M_=__MODULE__, size_t _L_=__LINE__, C, Args...)
			(ref bool isSelected, C s, in Args args)
		{
			HitInfo hit; 
			Row!(_M_, _L_)
			(
				{
					hit = hitTest(imEnabled); 
					
					if(
						!isSelected && hit.hover && (
							inputs.LMB.down || inputs.RMB.down
							/+mosue down left or right+/
						)
					)
					isSelected = true; 
					
					padding = "2 2"; 
					background = mix(background, clAccent, max(isSelected ? 0.66f:0, hit.hover_smooth*0.33f)); 
					style.bkColor = background; 
					
					static if(__traits(compiles, s()))
					s(); 
					else Text(s.text); 
				}, args
			); 
			
			return hit; 
		} 
	}
	
	version(/+$DIDE_REGION+/none) {
		auto ListBox(string _M_=__MODULE__, size_t _L_=__LINE__, A, Args...)
			(ref A value, A[] items, Args args)
		{
			auto idx = cast(int) items.countUntil(value); 
			//Opt: slow search. iterates items twice: 1. in this, 2. in the main ListBox funct
			
			auto res = ListBox!(_M_, _L_)(idx, items, args); 
			if(res)
			value = items[idx]; 
			return res; 
		} 
		
		auto ListBox(string _M_=__MODULE__, size_t _L_=__LINE__, E, Args...)
			(ref E e, Args args)
			if(is(E==enum))
		{
			auto s = e.text; 
			auto res = ListBox!(_M_, _L_)(s, getEnumMembers!E, args); 
			if(res)
			ignoreExceptions({ e = s.to!E; }); 
			return res; 
		} 
		
		/+
			Todo: the parameters of all the ListBox-es, ComboBoxes must be refactored. 
			It's a lot of copy paste and yet it's far from full accessible functionality.
		+/
		static void ScrollListBox(T, U, string _M_=__MODULE__ , size_t _L_=__LINE__)
			(ref T focusedItem, U items, void delegate(in T) cellFun, int pageSize, ref int topIndex)
			if(isInputRange!U && is(ElementType!U == T))
		{
			auto scrollMax = max(0, items.walkLength.to!int-pageSize); 
			topIndex = topIndex.clamp(0, scrollMax); 
			auto view = items.drop(topIndex).take(pageSize).array; 
			Row!(_M_, _L_)(
				{
					ListBox(focusedItem, view, cellFun); 
					if(1 || scrollMax)
					{
						Spacer; 
						Slider(topIndex, range(scrollMax, 0), { width = 1*fh; }); 
						flags.yAlign = YAlign.stretch; 
					}
				}
			); 
		} 
	}
	version(/+$DIDE_REGION+/none) {
		//Parameter structs ///////////////////////////////////
		//deprecated struct id      { uint val;  /*private*/ enum M = q{ auto id_ = file.xxh(line)^baseId;                          static foreach(a; args) static if(is(Unqual!(typeof(a)) == id      )) id_       = [a.val].xxh(id_); }; }
		deprecated immutable prepareId = q{auto id_ = combine(imId, srcId!(_M_, _L_)(args)); }; 
		
		/*
			struct enable 
				{ bool val; 	 enum M = q{auto oldEnabled = enabled; scope(exit) enabled = oldEnabled; 	  static foreach(a; args) static if(is(Unqual!(typeof(a)) == enable  )) enabled = enabled && a.val; 	}; } 
		*/
		
		deprecated immutable selected_M = q{static foreach(a; args) static if(isGenericArg!(typeof(cast()a), "selected")) imSelected	= a.val; 	}; 
		
		
		/+private enum range_M = q{range _range;  static foreach(a; args) static if(is(Unqual!(typeof(a)) == range)) _range = a; }; +/
		/+deprecated private enum range_M = q{ValueRange _range;  static foreach(a; args) static if(is(Unqual!(typeof(a)) == ValueRange)) _range = a; }; +/
	}
	
	deprecated private enum hintHandler = 
	q{
		{
			static foreach(a; args)
			static if(is(Unqual!(typeof(a)) == HintRec))
			{
				if(a.markup.length && hit.hover)
				{
					auto hr = a; 
					hr.owner = actContainer; 
					hr.bounds = hit.hitBounds; 
					addHint(hr); 
				}
			}
		}
	}; 
	
}