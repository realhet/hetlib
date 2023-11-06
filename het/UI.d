module het.ui; /+DIDE+/
version(/+$DIDE_REGION+/all)
{
	public import het.opengl; 
	import het.parser: SyntaxKind, SyntaxPreset, syntaxTable, defaultSyntaxPreset; 
	
	import std.bitmanip: bitfields; 
	import std.traits, std.meta; 
	
	
	//Todo: rename "hovered" -> "hot"
	//Todo: multiple 2D view controls in hetlib
	
	//enums/constants ///////////////////////////////////////
	
	//adjust the size of the original Tab character
	enum 
		VisualizeContainers	= 0,
		VisualizeContainerIds	= 0,
		VisualizeGlyphs	= 0,
		VisualizeTabColors	= 0, //Todo: spaces at row ends
		VisualizeHitStack	= 0,
		VisualizeSliders	= 0,
		VisualizeCodeLineIndices 	= 0,
			
		addHitRectAsserts	= 0; //Verifies that Cell.Id is non null and unique
	
	//Todo: bug: NormalFontHeight = 18*4	-> RemoteUVC.d crashes.
	immutable DefaultFontName = //this is	the cached font
		"Segoe UI"
	//"Lucida Console"
	//"Consolas" <- too curvy
	; 
	
	immutable
		DefaultFontHeight	= 18,
		InvDefaultFontHeight	= 1.0f/DefaultFontHeight,
	
		MinScrollThumbSize	= 4, //pixels
		DefaultScrollThickness	= 15, //pixels
	
		LeadingTabWidth	=	 7.25f*4,	 LeadingTabAspect	= LeadingTabWidth	/ DefaultFontHeight,
		InternalTabWidth	=	 3.25f  ,	 InternalTabAspect	= InternalTabWidth	/ DefaultFontHeight; 
	
	static assert(DefaultFontHeight==18, "//fucking keep it on 18!!!!"); 
	
	
	Glyph newLineGlyph()
	{
		 //newLineGlyph /////////////////////////////////////////////
		import std.concurrency; 
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
	
	private enum 
		AlignEpsilon = .001f; //avoids float errors that come from float sums of subCell widths/heights
	
	
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
	__gshared void function(Drawing, Container) function(Container) g_getDrawCallbackFunct; 
	
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
	
	private vec2 calcGlyphSize_clearType(in TextStyle ts, int stIdx)
	{
		auto info = textures.accessInfo(stIdx); 
		
		float	aspect	= float(info.width)/(info.height*3/*clearType x3*/); //Opt: rcp_fast
		auto	size	= vec2(ts.fontHeight*aspect, ts.fontHeight); 
		
		if(ts.bold)
		size.x += size.y*(BoldOffset*2); 
		
		return size; 
	} 
	
	private vec2 calcGlyphSize_image(/*in TextStyle ts,*/ int stIdx)
	{
			auto info = textures.accessInfo(stIdx); 
		
		//float aspect = float(info.width)/(info.height); //opt: rcp_fast
			auto size =  vec2(info.width, info.height); 
		
			//image frame goes here
		
			return size; 
	} 
	
	//Template Parameter Processing /////////////////////////////////
	
	private
	{
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
	
	
	//HitTest ///////////////////////////////
	
	struct HitInfo
	{
		 //Btn returns it
		SrcId id; 
		bool enabled = true; 
		bool hover, captured, clicked, pressed, released; 
		float hover_smooth, captured_smooth; 
		bounds2 hitBounds; //this is in ui coordinates. Problematic with zoomable and GUI views.
		
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
	} 
	
	struct HitTestManager
	{
		
		struct HitTestRec
		{
			SrcId id; 	  //in the	next frame this must be the isSame
			bounds2 hitBounds; 		//absolute bounds on the drawing where the hittesi was made, later must be combined with View's transformation
			vec2 localPos; 	  //relative to outerPos
			bool clickable; 
		} 
		
		//act frame
		HitTestRec[] hitStack, lastHitStack; 
		
		float[SrcId] smoothHover; 
		private void updateSmoothHover(ref HitTestRec[] actHitStack)
		{
			enum upSpeed = 0.5f, downSpeed = 0.25f; 
			
			//raise hover values
			auto hoveredIds = actHitStack.map!"a.id".filter!"a".array.sort; 
			foreach(id; hoveredIds)
			smoothHover[id] = mix(smoothHover.get(id, 0), 1, upSpeed); 
			
			//lower (and remove) hover values
			SrcId[] toRemove; 
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
		
		SrcId capturedId, clickedId, pressedId, releasedId; 
		private void updateMouseCapture(ref HitTestRec[] hits)
		{
			//const topClickableId = hits.get(hits.length-1).id;
			const topId = hits.retro.filter!(h => h.clickable).take(1).array.get(0).id; 
			
			//if LMB was just pressed, then it will be the captured control
			//if LMB released, and the captured id is also hovered, the it is clicked.
			
			clickedId = pressedId = releasedId = SrcId.init; //normally it's 0 all the time, except that one frame it's clicked.
			
			with(cast(GLWindow)mainWindow)
			{
				 //Todo: get the mouse state from elsewhere!!!!!!!!!!!!!
				if(topId && mouse.LMB && mouse.justPressed && isForeground)
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
					capturedId = SrcId.init; 
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
		
		void addHitRect(in SrcId id, in bounds2 hitBounds, in vec2 localPos, in bool clickable)
		{
			//must be called from each cell that needs mouse hit test
			static if(addHitRectAsserts)
			{
				assert(id, "Null Id is illegal"); 
				assert(!hitStack.any!(a => a.id==id), "Id already defined for cell: "~id.text); 
			}
			hitStack ~= HitTestRec(id, hitBounds, localPos, clickable); 
		} 
		
		auto check(in SrcId id)
		{
			HitInfo h; 
			h.id = id; 
			if(id==SrcId.init)
			return h; 	
			h.hover		=	lastHitStack.map!"a.id".canFind(id); 
			h.pressed		=	pressedId ==id; 
			h.released		= releasedId==id; 
			h.clicked	  = clickedId ==id; 
			h.captured	  = h.pressed || capturedId==id && h.hover; //Todo: architectural bug: captured is delayed by 1 frame according to repeated
			h.hover_smooth	  = smoothHover.get(id, 0); 
			h.captured_smooth	  = max(h.hover_smooth, h.captured); 
			h.hitBounds	  = lastHitStack.get(lastHitStack.map!"a.id".countUntil(id)).hitBounds; 
			return h; 
		} 
		
		void draw(Drawing dr)
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
		
		auto stats()
		{ return format("HitTest lengths: hitStack:%s, lastHitStack::%s, smoothHover::%s", hitStack.length, lastHitStack.length, smoothHover.length); } 
		
	} 
	
	__gshared HitTestManager hitTestManager; 
	
	
	
	
	auto paramByType(Tp, bool fallback=false, Tp def = Tp.init, T...)(T args)
	{
		Tp res = def; 
		
		enum isWrapperStruct = __traits(hasMember, Tp, "val") && Fields!Tp.length==1; //is it encapsulated in a wrapper struct?  -> struct{ type val; }
		
		enum checkDuplicatedParams = q{
			static assert(!__traits(compiles, duplicated_parameter), "Duplicated parameter type: %s%s".format(Tp.stringof, fallback ? "("~typeof(Tp.val).stringof~")" : ""));
			enum duplicated_parameter = 1;
		}; 
		
		static foreach_reverse(idx, t; T)
		{
			//check simple types/structs
			static if(isCompatible!(typeof(res), t, __traits(compiles,	res = args[idx]), __traits(compiles, res = args[idx].toDelegate)))
			{
				static if(__traits(compiles, res = args[idx]))
				res = args[idx]; else
				res = args[idx].toDelegate; 
				mixin(checkDuplicatedParams); 
			}
			else static if(
				fallback && isWrapperStruct && isCompatible!(typeof(res.val), t, __traits(compiles,	res.val = args[idx]), __traits(compiles, res.val = args[idx].toDelegate))//check fallback struct.val
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
				static if((isFunctionPointer!t || isDelegate!t) && Parameters!t.length==0 && !is(ReturnType!t==void) && __traits(compiles, res = args[idx]().to!Tr))
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
				static if((isFunctionPointer!t || isDelegate!t) && Parameters!t.length==1 && is(ReturnType!t==void) && __traits(compiles, args[idx](val.to!Tr)))
				{ args[idx](val.to!Tr); }else static if(isPointer!t && __traits(compiles, *args[idx] = val.to!Tr))
				{ *args[idx] = val.to!Tr; }
			}
		}
	} 
	
	
	
	shared static this()
	{
		//static init///////////////////////////////
		initTextStyles; 
	} 
	
	//TextStyle ////////////////////////////////////
	struct TextStyle
	{
		string font = DefaultFontName; 
		ubyte fontHeight = DefaultFontHeight; 
		bool bold, italic, underline, strikeout, transparent; 
		RGB fontColor=clBlack, bkColor=clWhite; 
		
		ubyte fontFlags() const
		{ return cast(ubyte)boolMask(bold, italic, underline, strikeout, 0/+isImage+/, transparent); } 
		//Todo: implement monospaced font style for string literals, but firts I must refactor fontFlags.
		
		bool isDefaultFont() const
		{ return font == DefaultFontName; } //Todo: slow. 'font' Should be a property.
		
		void modify(string[string] map)
		{
			map.rehash; 
			if(auto p="font"	in map)
			font	  = (*p); 
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
			fontColor		=	(*p).toRGB; 
			if(auto p="bkColor"	in map)
			bkColor	  =	(*p).toRGB; 
		} 
		void modify(string cmdLine)
		{ modify(commandLineToMap(cmdLine)); } 
	} 
	
	//TextStyles ////////////////////////////////////////////
	
	TextStyle tsNormal, tsComment, tsError, tsBold, tsBold2, tsCode, tsQuote, tsLink, tsTitle, tsChapter, tsChapter2, tsChapter3,
		tsBtn, tsKey, tsLarger, tsSmaller, tsHalf; 
	
	TextStyle*[string] textStyles; 
	
	TextStyle newTextStyle(string name)(in TextStyle base, string props)
	{
		TextStyle ts = base; 
		ts.modify(props); 
		return ts; 
	} 
	
	
	//https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-getsyscolor
	const
				clChapter	              = RGB(221,	3,  48),
				clAccent														 = RGB(0, 120,	215),
				clMenuBk														 = RGB(235, 235, 236),
				clMenuHover	              = RGB(222, 222, 222),
				clLink	              = RGB(0, 120, 215),
	
				clLinkHover	           =	RGB(102, 102, 102),
				clLinkPressed		= RGB(153,	153, 153),
				clLinkDisabled		= RGB(122, 122, 122), //clWinBtnHoverBorder
	
				clWinRed                  = RGB(232,17,35),
	
				clWinText	     = clBlack,
				clWinBackground	     = clWhite,
				clWinFocusBorder	     = clBlack,
				clWinBtn	     = RGB(204,	204, 204),
				clWinBtnHoverBorder		= RGB(122, 122, 122),
				clWinBtnPressed	     = clWinBtnHoverBorder,
				clWinBtnDisabledText	     = clWinBtnHoverBorder,
	
				clHintText		= clWinText,
				clHintBk	        =	RGB(236, 233, 216),
				clHintDetailsText			= clWinText,
				clHintDetailsBk	        =	clWhite,
	
				clSliderLine	     = clLinkPressed,
				clSliderLineHover		=	clLinkHover,
				clSliderLinePressed		=	clLinkPressed,
				clSliderThumb	     = clAccent,
				clSliderThumbHover		=	RGB(23, 23, 23),
				clSliderThumbPressed		=	clWinBtn,
				clSliderHintBorder		=	clMenuBk,
				clSliderHintBk	     = clWinBtn,
	
				clScrollBk	     = clMenuBk,
				clScrollThumb	     = clWinBtn,
				clScrollThumbPressed	     = clWinBtnPressed; 
	
	
	void initTextStyles()
	{
		
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
		
		
		a("normal"	, tsNormal	, TextStyle(DefaultFontName, rfh(18), false, false, false, false, false, clBlack, clWhite)); 
		a("larger"	, tsLarger	, tsNormal, { tsLarger.fontHeight = rfh(22); }); 
		a("smaller"	, tsSmaller	, tsNormal, { tsSmaller.fontHeight = rfh(14); }); 
		a("half"	, tsHalf	, tsNormal, { tsHalf.fontHeight = rfh(9); }); 
		a("comment"	, tsComment	, tsNormal, { tsComment.fontHeight = rfh(12); }); 
		a("error"	, tsError	, tsNormal,	{ tsError.bold = tsError.underline = true; tsError.bkColor = clRed; tsError.fontColor = clYellow; }); 
		a("bold"	, tsBold	, tsNormal, { tsBold.bold = true; }); 
		a("bold2"	, tsBold2	, tsBold	, { tsBold2.fontColor = clChapter; }); 
		a("quote"	, tsQuote	, tsNormal,	{ tsQuote.italic = true; }); 
		a("code"	, tsCode	, tsNormal, { tsCode.font = "Lucida Console"; tsCode.fontHeight = rfh(18); tsCode.bold = false; }); //Todo: should be half bold?
		a("link"	, tsLink	, tsNormal, { tsLink.underline = true; tsLink.fontColor = clLink; }); 
		a("title"	, tsTitle	, tsNormal,	{ tsTitle.bold = true; tsTitle.fontColor = clChapter; tsTitle.fontHeight = rfh(64); }); 
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
		return chkSet(tsError.underline, act); 
	} 
	
	//Helper functs ///////////////////////////////////////////
	
	private bool isSame(T1, T2)()
	{ return is(immutable(T1)==immutable(T2)); } 
	
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
	{ return cells.map!"a.flex".sum; } 
	
	bool isWhite(const Cell c)
	{ auto g = cast(const Glyph)c; return g && g.isWhite; } 
	
	void adjustTabSize(Cell c, bool isLeading)
	{ c.outerWidth = c.outerHeight * (isLeading ? LeadingTabAspect : InternalTabAspect); } 
	
	
	
	struct Padding
	{
		  //Padding, Margin ///////////////////////////////////////////////////
		//alias all this; not working that way
		
		float top=0, right=0, bottom=0, left=0; 
		@property
		{
			float all() const
			{ return avg(horz, vert); } 
			void all(float a)
			{ left = right = top = bottom = a; } 
			
			float horz() const
			{ return avg(left, right); } 
			void horz(float a)
			{ left = right = a; } 
			float vert() const
			{ return avg(top, bottom); } 
			void vert(float a)
			{ top = bottom = a; } 
		} 
		
		private static float toF(string s)
		{ return s.toWidthHeight(g_actFontHeight); } 
		
		void opAssign(in string s)
		{ setProps(s); } 
		
		void setProps(in string s)
		{
			 //shorthand
			if(s.empty)
			return; 
			auto p = s.split(' ').filter!"!a.empty".array; 
			if(p.empty)
			return; 
			
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
			top 	= bottom 	= a; 
			left	= right	= b; 
		} 
		
		void set(float a, float b, float c, float d)
		{
			top	= a; 
			right	= b; 
			bottom 	= c; 
			left	= d; 
		} 
		
		void apply(T)(ref T r, float scale = 1)
		{
			r.left 	+= scale*left; 
			r.top 	+= scale*top; 
			r.right 	-= scale*right; 
			r.bottom 	-= scale*bottom; 
		} 
		
		void unapply(T)(ref T r)
		{ apply(r, -1); } 
	} 
	
	alias Margin = Padding; 
	
	enum BorderStyle
	{ none, normal, dot, dash, dashDot, dash2, dashDot2, double_} 
	
	auto toBorderStyle(string s)
	{
		 //Border ///////////////////////////
		//synomyms
				 if(s=="single")
		s="normal"; 
		else if(s=="double") s="double_"; 
		return s.to!BorderStyle; 
	} 
	
	struct Border
	{
		float width = 0; 
		BorderStyle style = BorderStyle.normal;  //Todo: too many bits
		RGB color = clBlack; 
		
		bool inset;  //border has a size inside gap and margin
		float ofs = 0; //border is offsetted by ofs*width
		bool extendBottomRight; //for grid cells
		bool borderFirst; //for code editor: it is possible to make round borders with it.
		
		float gapWidth() const
		{ return inset ? 0 : width; } //effective borderWidth
		
		void opAssign(in string s)
		{ setProps(s); } 
		
		void setProps(in string s)
		{
			//shortHand: [width] style [color]
			if(s.empty)
			return; 
			auto p = s.split(' ').filter!"!a.empty".array; 
			if(p.empty)
			return; 
			
			//Todo: the properties can be in any order.
			//Todo: support the inset property
			
			//width
			bool hasWidth; 
			if(p[0][0].isDigit)
			{
				hasWidth = true; 
				width = p[0].to!float; 
				p = p[1..$]; 
				if(p.empty)
				return; 
			}
			
			//style
			style = p[0].toBorderStyle; 
			if(!hasWidth && style!=BorderStyle.none)
			width = 1; //default width
			p = p[1..$]; 
			if(p.empty)
			{
				color = g_actFontColor; //default color
				return; 
			}
			
			//color
			color = p[0].toRGB; 
		} 
		
		void setProps(string[string] p, string prefix)
		{
			p.setParam(prefix, (string s){ setProps(s); }); 
			
			p.setParam(prefix~".width", (string	a){ width = a.toWidthHeight(g_actFontHeight); }); 
			p.setParam(prefix~".color", (RGB	a){ color = a; }); 
			p.setParam(prefix~".style", (string	a){ style = a.toBorderStyle; }); 
		} 
		
		
		bounds2 adjustBounds(in bounds2 bb)
		{
			bounds2 res = bb; 
			if(extendBottomRight)
			with(res.high)
			{ x += width; y += width; }
			return res; 
		} 
	} 
	
	auto toLineStyle(BorderStyle bs)
	{
		with(BorderStyle)
		switch(bs)
		{
			case dot: 	   return LineStyle.dot; 
			case dash: 	   return LineStyle.dash; 
			case dashDot: 	   return LineStyle.dashDot; 
			case dash2: 	   return LineStyle.dash2; 
			case dashDot2: 	   return LineStyle.dashDot2; 
			default: return LineStyle.normal; 
		}
		
	} 
	
	
	struct _FlexValue
	{ float val=0; alias val this; } //ganyolas
	
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
		 //Cell ////////////////////////////////////
		
		/+
			  static shared int[string] objCnt;  //todo: ha ez nem shared, akkor beszarik a hatterben betolto jpeg. Miert?
				this(){
			//			 auto n = this.classinfo.name;
			//			 if(n !in objCnt) objCnt[n]=0;
			//			 objCnt[n]++;
				}
			
				~this(){
			//			 auto n = this.classinfo.name;
			//			 objCnt[n]--;
					//ennek qrvara sharednek kell lennie, mert a gc akarmelyik threadbol mehet.
					//egy atomic lenne a legjobb
				} 
		+/
		
		///Optionally the container can have a parent.
		inout(Container) getParent() inout
		{ return null; } 
		void setParent(Container p)
		{} 
		
		auto thisAndAllParents(
			Base : Cell = Cell, bool thisToo = true, 
			bool isConst=is(typeof(this)==const)
		)() inout
		{
			
			struct ParentRange
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
		
		vec2 outerPos, outerSize; 
		
		ref _FlexValue flex()
		{ static _FlexValue nullFlex; return nullFlex	; } //Todo: this is bad, but fast. maybe do it with a setter and const ref.
		ref Margin	margin ()
		{ static Margin	nullMargin; return nullMargin	; } 
		ref Border	border ()
		{ static Border	nullBorder; return nullBorder	; } 
		ref Padding	padding()
		{ static Padding	nullPadding; return nullPadding; }  //Todo: inout ref
		
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
			//calculated prioperties. No += operators are allowed.
			
			/+
				Todo: ezt at kell irni, hogy az outerSize legyen a tarolt cucc, ne az inner. Indoklas: az outerSize kizarolag csak az
							outerSize ertek atriasakor valtozzon meg, a border modositasatol ne. Viszont az autoSizet ekkor mashogy kell majd detektalni...
			+/
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
				const hb = border.width*location; 
				return bounds2(
					outerPos	+ vec2(margin.left  + extraMargin + hb, margin.top    + extraMargin + hb),
					outerBottomRight 	- vec2(margin.right + extraMargin + hb, margin.bottom + extraMargin + hb)
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
			
			auto outerLeft	() const
			{ return outerX; } 
			auto outerRight	() const
			{ return outerX+outerWidth; } 
			auto outerTop	() const
			{ return outerY; } 
			auto outerBottom() const
			{ return outerY+outerHeight; } 
			auto innerCenter() const
			{ return innerPos + innerSize*.5f; } 
			
			auto outerTopLeft	  () const
			{ return outerPos; } 
			auto outerTopRight	  () const
			{ return outerPos + vec2(outerWidth, 0); } 
			auto outerBottomRight() const
			{ return outerPos + outerSize; } 
			auto outerBottomLeft () const
			{ return outerPos + vec2(0, outerHeight); } 
			
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
					if(container.flags.noHitTest)
					return false; //Note: false means -> keep continue the search
					hitTestManager.addHitRect(container.id, hitBnd, mouse-(innerPos+ofs), container.flags.clickable); 
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
			if(!border.width || border.style == BorderStyle.none)
			return; 
			
			auto bw = border.width, bb = borderBounds; 
			dr.lineStyle = border.style.toLineStyle; 
			dr.color = border.color; 
			dr.lineWidth = bw * (border.style==BorderStyle.double_ ? 0.33f : 1); 
			
			if(border.ofs)
			{ auto o = border.ofs *= bw; bb = bb.inflated(o, o); }
			bb = border.adjustBounds(bb); 
			
			void doit(float sh=0)
			{
				const m = bw*sh; 
				auto r = bb.inflated(m, m); 
				if(r.width<=0 || r.height<=0)
				{
					dr.line(r.topLeft, r.bottomRight); //Todo: just a line. Used for Spacer, but it's wrond, because it goes negative
				}else
				{ dr.drawRect(r); }
			} 
			
			if(border.style==BorderStyle.double_)
			{ doit(-0.333f); doit(0.333f); 	}
			else { doit; 	}
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
	int fontTexture(Args...)(in dchar ch, in Args args)
	if(Args.length==0 || Args.length==1 && (is(Args[0] == TextStyle) || is(Args[0] == string)))
	{
		int stIdx; //the result texture index
		
		static if(Args.length==0)
		{
			enum fontName = DefaultFontName; 
			enum isDefault = true; 
		}else static if(is(Args[0] == TextStyle))
		{
			auto 	fontName 	= args[0].font,
				isDefault	= args[0].isDefaultFont; 
		}else
		{
			auto 	fontName 	= args[0],
				isDefault	= args[0] == DefaultFontName; 
		}
		
		//ch -> subTexIdx lookup. Cached with a map.   10 FPS -> 13..14 FPS
		void lookupSubTexIdx()
		{
			string glyphSpec = `font:\`~fontName~`\72\x3\?`~[ch].toUTF8; 
			stIdx = textures[File(glyphSpec)]; //fonts are loaded immediatelly
		} 
		
		if(isDefault)
		{
			 //cached version for the default font
			if(auto p = ch in DefaultFont_subTexIdxMap)
			{ stIdx = *p; }else
			{
				lookupSubTexIdx; 
				DefaultFont_subTexIdxMap[ch] = stIdx; 
			}
		}else
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
	
	
	class Glyph : Cell
	{
		int stIdx; 
		dchar ch; 
		
		RGB fontColor, bkColor; 
		ubyte fontFlags; //Todo: compress information
		
		bool isWhite, isTab, isNewLine, isReturn; //needed for wordwrap and elastic tabs
		
		ubyte syntax; //needed for DIDE
		int lineIdx; //1based. needed for DIDE.
		
		this(dchar ch, in TextStyle ts)
		{
			this.ch = ch; 
			
			//tab is the isSame as a space
			isTab = ch==9; 
			isWhite = isTab || ch==32; 
			isNewLine = ch==10; 
			isReturn = ch==13;         //Todo: ezt a boolean mess-t kivaltani. a chart meg el kene tarolni. ossz 16byte all rendelkezeser ugyis.
			
			dchar visibleCh = ch; 
			if(VisualizeGlyphs)
			{
				if(isReturn)
				visibleCh = 0x240D; else if(isNewLine)
				visibleCh = 0x240A; //0x23CE;
			}else
			{
				if(isReturn || isNewLine)
				visibleCh = ' '; 
				else if(ch==0xb) visibleCh = 0x240B; //vertical tab. It is used for multiColumns
			}
			
			stIdx = visibleCh.fontTexture(ts); 
			
			fontFlags = ts.fontFlags; 
			fontColor = ts.fontColor; 
			bkColor = ts.bkColor; 
			
			innerSize = calcGlyphSize_clearType(ts, stIdx); 
			
			if(!VisualizeGlyphs)
			if(isReturn || isNewLine)
			innerWidth = 0; 
		} 
		
		this(dchar ch, in TextStyle ts, SyntaxKind sk)
		{
			this(ch, ts); 
			syntax = cast(ubyte) sk; 
		} 
		
		override void draw(Drawing dr)
		{
			drawBorder(dr); //Todo: csak a containernek kell border elvileg, ez hatha gyorsit.
			dr.color = fontColor; 
			dr.drawFontGlyph(stIdx, innerBounds, bkColor, fontFlags); 
			
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
				dr.line2(innerBounds); 
				
				if(isTab)
				{
					dr.lineWidth = innerHeight*0.04f; 
					dr.line2(ArrowStyle.vector, innerBounds.leftCenter, innerBounds.rightCenter); 
				}else if(isWhite)
				{ dr.drawX(innerBounds); }
			}
		} 
		
		override string toString()
		{ return format!"Glyph(%s, %s, %s)"(ch.text.quoted, stIdx, outerBounds); } 
	} 
	
	
	enum ShapeType
	{ led} 
	
	class Shape : Cell
	{
		 //Shape /////////////////////////////////////
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
				case ShapeType.led: {
						auto r = min(innerWidth, innerHeight)*0.92f; 
					
					
						auto p = innerCenter; 
					
						dr.pointSize = r; 	 dr.color = RGB(.3, .3, .3);  dr.point(p); 
						dr.pointSize = r*.8f; 	 dr.color = color;   dr.point(p); 
						dr.pointSize = r*0.4f; 	 dr.alpha = 0.4f; dr.color = clWhite; dr.point(p-vec2(1,1)*(r*0.15f)); 
						dr.pointSize = r*0.2f; 	 dr.alpha = 0.4f; dr.color = clWhite; dr.point(p-vec2(1,1)*(r*0.18f)); 
						dr.alpha = 1; 
					
					break; 
				}
			}
		} 
	} 
	
	class Img : Container
	{
		File file; 
		bool transparent; 
		
		this(File file)
		{
			this.file = file; 
			id = srcId(genericId("Img")); //Todo: this is bad
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
			const stIdx = textures[file]; //Todo: no delayed load support
			const siz = calcGlyphSize_image(stIdx); 
			
			if(flags.autoHeight && flags.autoWidth)
			{ innerSize = siz; }
			else if(flags.autoHeight)
			{ innerHeight = innerWidth/max(siz.x, 1)*siz.y; }
			else if(flags.autoWidth)
			{ innerWidth = innerHeight/max(siz.y, 1)*siz.x; }
		} 
		
		override void draw(Drawing dr)
		{
			if(flags.hidden)
			return; 
			
			drawBorder(dr); 
			
			const stIdx = textures[file]; 
			if(transparent)
			dr.drawFontGlyph(stIdx, innerBounds, bkColor, 32/*transparent font*/); 
			else dr.drawFontGlyph(stIdx, innerBounds, bkColor, 16/*image*/); 
		} 
	} 
}
version(/+$DIDE_REGION+/all)
{
	
	//TextPos ///////////////////////////////////////////////////
	
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
	
	struct TextPos
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
	struct TextRange
	{ TextPos st, en; } 
	
	struct EditCmd
	{
		 //EditCmd ////////////////////////////////////////
		private enum _intParamDefault = int.min+1,
								 _pointParamDefault = vec2(-1e30, -1e30); 
		
		enum Cmd
		{
			//caret commands              //parameters
			nop,
			cInsert,	        //text to insert
			cDelete, cDeleteBack,	        //number of glyphs to delete. Default 1
			cLeft, cRight,	        //number of repetitions. Default 1
			cUp, cDown,
			cHome, cEnd,
			cMouse                        //caret goes to mouse
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
	
	/// All the information needed for a text editor
	struct TextEditorState
	{
		 //TextEditorState /////////////////////////////////////
		string str; 	     //the string	being edited	Edit() fills it
		float defaultFontHeight; 		//used when there's no text to display	0	-> uibase.NortmalFontHeight
		int[] cellStrOfs; 	     //mapping petween glyphs and string ranges	Edit() fills it
		
		Row row; 	  //editor container. Must be a row.	             Edit() fills it
		WrappedLine[] wrappedLines; 	  //formatted glyphs	             Measure fills it when edit is same as wrappedLines
		
		bool strModified; 	            //string is modified, and it is needed to reformat.
		            //cellStrOfs and wrappedLines are invalid.
		
		TextPos caret;                //first there is only one caret, no selection   persistent
		
		EditCmd[] cmdQueue;           //commands waiting for execution                Edit() fills, it is proecessed after the hittest
		
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
			
					float yMin = wrappedLines[0].top,
								yMax = wrappedLines.back.bottom,
								y = point.y; 
			
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
			
					float xMin = wl.left,
								xMax = wl.right,
								x = point.x; 
			
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
				
				caret = toIdx(TextPos(vec2(c.point.x, c.point.y + c.height*.5 + c.height*delta), 0)); //Todo: it only works for the same fontHeight and  monospaced stuff
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
				
				auto insLen = countMarkupLineCells(ins); //cellcount can be adjusted by this, but the wrappedLines is ruined now.
				
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
				case Cmd.nop: break; 
				case Cmd.cInsert					: 	caretRestrict; modify(toIdx(caret).idx, 0, strParam); break; 
				case Cmd.cDelete					: 	deleteAtCaret(false); break; 
				case Cmd.cDeleteBack		: deleteAtCaret(true ); break; 
				case Cmd.cLeft	: caretMoveRel(-intParam(1)); break; 
				case Cmd.cRight	: caretMoveRel(intParam(1)); break; 
				case Cmd.cUp		: 	caretMoveVert(-intParam(1)); break; 
				case Cmd.cDown		: 	caretMoveVert(intParam(1)); break; 
				case Cmd.cHome		: 	caretMoveAbs(0); break; 
				case Cmd.cEnd			: 	caretMoveAbs(cellCount); break; 
				case Cmd.cMouse		: 	caret = toIdx(TextPos(pointParam, 0)); break; 
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
					auto oldFont = ts.font; 
					ts.font = "Segoe MDL2 Assets"; 
					container.appendChar(ch, ts); 
					ts.font = oldFont; 
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
	
	void appendMarkupLine(bool returnSubCellStrOfs=true)(Container cntr, string s, ref TextStyle ts, ref int[] subCellStrOfs)
	{
		enum CommandStartMarker	= '\u00B6',
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
	
	void appendCode(Container cntr, string text, in ubyte[] syntax, void delegate(ubyte) applySyntax, ref TextStyle ts, int nonStringTabToSpaces=-1)
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
	
	bool updateSyntax(TC:Container)(TC cntr, string text, in ubyte[] syntax, void delegate(ubyte) applySyntax, ref TextStyle ts, out bool wasWidthChange, int nonStringTabToSpaces=-1)
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
							
							wasUpdate = true; //Todo: return this flag somehow... Maybe it is useful for recalculating cached row stuff. But currently the successful flag is returned.
						}
					}
					else
					{
						//not the same char as it was expected. Only the syntax highlight can change, not the text.
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
		
		
		wasWidthChange = wasBoldShift;  //Bug: this only works with elastic tabs when the whole line grows, not when shrinks.
		return !wasError && cntrSubCellsLength == dstIdx; 
	} 
	
	//toro: Refactor the whole Row/Glyph/Syntax mystery
	
	/*
		enum updateCodeSyntax = appendCode!(Yes.updateSyntax);
		
		void appendCode(Flag!updateInplace = No.updateSyntax)(Container cntr, string text, in ubyte[] syntax, void delegate(ubyte) applySyntax, ref TextStyle ts, int nonStringTabToSpaces=-1)
		in(text.length == syntax.length)
		{
			int resultCode; //0==ok
		
			static if(updateInplace){
				const cntrSubCellsLength = cntr.subCells.length;
				size_t dstIdx = 0;
				bool wasError, wasUpdate;
		
				void doit(dchar ch, ref TextStyle ts, ubyte actSyntax){
					if(dstIdx<cntrSubCellsLength){
						if(auto g = cast(Glyph)cntr.subCells[dstIdx]){
							if(g.ch==ch){
								if(g.syntax.chkSet(actSyntax)){
									g.bkColor	= ts.bkColor  ;
									g.fontColor	= ts.fontColor;
									g.fontFlags	= ts.fontFlags;
									wasUpdate =	true; //todo: return this flag somehow... Maybe it is useful for recalculating cached row stuff. But currently the successful flag is returned.
								}
							}else{
								wasError = true;
							}
						}else{
							//it's not a glyph. Do nothing.
						}
					}
					dstIdx++;
				}
		
				scope(exit) resultCode = !wasError && cntrSubCellsLength == dstIdx;
			}else{ //appendCode
		
				void doit(dchar ch, ubyte actSyntax){
					cntr.appendSyntaxChar(ch, ts, actSyntax);
				}
		
			}
		
			size_t numCodeUnits, currentOfs;
			ubyte lastSyntax = 255;
		
			while(text.length){
				auto actSyntax = syntax[currentOfs];
				auto ch = text.decodeFront!(Yes.useReplacementDchar)(numCodeUnits);
				currentOfs += numCodeUnits;
		
				if(chkSet(lastSyntax, actSyntax)) applySyntax(actSyntax);
		
				if(ch=='\t' && nonStringTabToSpaces>=0 && actSyntax!=6/+string+/){
					foreach(i; 0..nonStringTabToSpaces)
						doit(' ', ts);
				}else{
					doit(ch, ts);
				}
			}
		
			return resultCode;
		}
	*/
	
	
	/// Lookup a syntax style and apply it to a TextStyle reference
	void applySyntax(Flag!"bkColor" bkColor = Yes.bkColor)(ref TextStyle ts, uint syntax, SyntaxPreset preset)
	in(syntax<syntaxTable.length)
	{
		auto fmt = &syntaxTable[syntax].formats[preset]; 
		ts.fontColor = fmt.fontColor; 
		if(bkColor)
		ts.bkColor   = fmt.bkColor; 
		ts.bold	= fmt.fontFlags.getBit(0); 
		ts.italic	= fmt.fontFlags.getBit(1); 
		ts.underline	= fmt.fontFlags.getBit(2); 
	} 
	
	
	/// Shorthand with global default preset
	void applySyntax(Flag!"bkColor" bkColor = Yes.bkColor)(ref TextStyle ts, uint syntax)
	{ applySyntax!bkColor(ts, syntax, defaultSyntaxPreset); } 
	
	auto tsSyntax(uint syntax, SyntaxPreset preset)
	{
		auto ts = tsNormal; 
		applySyntax(ts, syntax, preset); 
		return ts; 
	} 
	
	auto tsSyntax(uint syntax)
	{
		auto ts = tsNormal; 
		applySyntax(ts, syntax, defaultSyntaxPreset); 
		return ts; 
	} 
	
	private struct WrappedLine
	{
		 //WrappedLine /////////////////////////////////////////////////////////
		Cell[] cells; 
		float y0, height; 
		
		//const{ //todo: outerRight is not const
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
		} //Todo: assume left is 0
		//}
		
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
			if(cells.length && isWhite(cells[0]))
			{
				auto w = cells[0].outerWidth; 
				cells[0].outerWidth = 0; 
				foreach(c; cells[1..$])
				c.outerPos.x -= w; //shift back the remaining ones
			}
		} 
		
		void hideRightSpace()
		{
			if(cells.length && isWhite(cells.back))
			cells[0].outerWidth = 0; 
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
	
	/+
			Elastic Tabstops License
		https://nickgravgaard.com/elastic-tabstops/
		https://github.com/nickgravgaard/AlwaysAlignedVS/blob/master/LICENSE.md
		
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
	
	//elastic tabs
	int[] tabIdx(Cell c)
	{
		if(auto r = cast(Row)c)
		return r.tabIdxInternal; 
		else return []; 
	} 
	
	int tabCnt(Cell c)
	{
		return cast(int)c.tabIdx.length; //Todo: int -> size_t
	} 
	
	float tabPos(Cell c, int i)
	{
		if(auto r = cast(Row)c)
		return r.subCells[r.tabIdxInternal[i]].outerRight; 
		else return 0; 
	} 
	
	Glyph[] subGlyphs(Cell c)
	{
		if(auto r = cast(Container)c)
		return cast(Glyph[])r.subCells; 
		else return []; 
	} 
	
	
	Glyph subGlyph(Cell c, int i)
	{
		if(auto r = cast(Container)c)
		return cast(Glyph)r.subCells.get(i); 
		else return null; 
	} 
	
	void processElasticTabs(Cell[] rows, int level=0)
	{
		bool tabCntGood(Cell row)
		{ return row.tabCnt > level; } 
		
		while(1)
		{
			//search the islands
			while(rows.length && !tabCntGood(rows[0]))
			rows = rows[1..$]; 
			int n; while(n<rows.length && tabCntGood(rows[n]))
			n++; 
			if(!n)
			break; 
			auto range = rows[0..n]; 
			
			auto rightMostTabPos = range.map!(r => r.tabPos(level)).maxElement; 
			
			foreach(row; range)
			{
				auto tIdx = row.tabIdx[level],
						 tab = row.subGlyph(tIdx),
						 delta = rightMostTabPos-(tab.outerRight); 
				
				if(delta)
				{
					tab.innerWidth = tab.innerWidth + delta; //Todo: after this, the flex width are fucked up.
					
					//Todo: itt ha tordeles van, akkor ez szar.
					float flexRatioSum = 0; 
					foreach(g; (cast(Container)row).subCells[tIdx+1..$])
					{
						g.outerPos.x += delta; //shift the cells
						if(g.flex)
						flexRatioSum += g.flex; 
					}
					
					if(flexRatioSum>0)
					{
						//WARN("flex and tab processing not implemented yet");
						//Todo: flex and tab processing
					}
				}
				
				if(VisualizeTabColors)
				{
					tab.bkColor = mix(clGray, clRainbow[level%$], .25f); //debug coloring
				}
				
			}
			processElasticTabs(range, level+1); //recursive
			
			rows = rows[n..$]; //advance
		}
	} 
	
	//Todo: this WrappedLine tab processing is terribly unoptimal
	private bool isTab(in Cell c)
	{
		if(const g = cast(Glyph)c)
		return g.isTab; 
		else return false; 
	} 
	
	private int tabCnt(in WrappedLine wl)
	{ return cast(int) wl.cells.count!(c => c.isTab); } 
	
	private int tabIdx(in WrappedLine wl, int i)
	{
		int j; 
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
	
	float tabPos(WrappedLine wl, int i)
	{
		with(wl.cells[wl.tabIdx(i)])
		return outerRight; 
	} 
	
	void processElasticTabs(WrappedLine[] rows, int level=0)
	{
		bool tabCntGood(in WrappedLine wl)
		{ return wl.tabCnt > level; }       //!!!!!!!!!!!!!!!!
		
		while(1)
		{
			//search the islands
			while(rows.length && !tabCntGood(rows[0]))
			rows = rows[1..$]; 
			int n; while(n<rows.length && tabCntGood(rows[n]))
			n++; 
			if(!n)
			break; 
			auto range = rows[0..n]; 
			
			auto rightMostTabPos = range.map!(r => r.tabPos(level)).maxElement; 
			
			foreach(row; range)
			{
				auto tIdx = row.tabIdx(level),
						 tab = cast(Glyph)(row.cells[tIdx]),
						 delta = rightMostTabPos-(tab.outerRight); 
				
				if(delta)
				{
									tab.innerWidth = tab.innerWidth + delta; 
					
									//Todo: itt ha tordeles van, akkor ez szar.
									foreach(g; row.cells[tIdx+1..$])
					g.outerPos.x += delta; 
					//row.innerWidth += delta;
				}
				
				if(VisualizeTabColors)
				{
					tab.bkColor = avg(clWhite, clRainbow[level%$]); //debug coloring
				}
				
			}
			processElasticTabs(range, level+1); //recursive
			
			rows = rows[n..$]; //advance
		}
	} 
	
	
	//enum WrapMode { clip, wrap, shrink } //todo: break word, spaces on edges, tabs vs wrap???
	
	enum ScrollState
	{ off, on, autoOff, autoOn, auto_ = autoOff} 
	
	bool getEffectiveScroll(ScrollState s) pure
	{ return s.among(ScrollState.on, ScrollState.autoOn)>0; } 
	
	union ContainerFlags
	{
		 //------------------------------ ContainerFlags /////////////////////////////////
		//Todo: do this nicer with a table
		ulong _data = 0b_000_00000001____00_00_0_0_0_0____0_0_0_0_0_0_1_0____1_0_0_0_0_0_0_0____001_00_00_1; //Todo: ui editor for this
		mixin(
			bitfields!(
				bool	, "wordWrap"	, 1,
				HAlign	, "hAlign"	, 2, //alignment for all subCells
				VAlign	, "vAlign"	, 2,
				YAlign	, "yAlign"	, 3,
						
				bool	, "dontHideSpaces"	, 1, //useful for active edit mode
				bool	, "canSelect"	, 1,
				bool	, "focused"	, 1, //maintained by system, not by user
				bool	, "hovered_deprecated"	, 1, //maintained by system, not by user
				bool	, "clipSubCells"	, 1,
				bool	, "_saveComboBounds"	, 1, //marks the container to save the absolute bounds to align the popup window to.
				bool	, "_hasOverlayDrawing"	, 1,
				bool	, "columnElasticTabs"	, 1, //Column will do ElasticTabs its own Rows.
						
				bool	, "rowElasticTabs"	, 1, //Row will do elastic tabs inside its own WrappedLines.
				uint	, "targetSurface"	, 1, //0: zoomable view, 1: GUI screen
				bool	, "_debug"	, 1, //the container can be marked, for debugging
				bool	, "btnRowLines"	, 1, //draw thin, dark lines between the buttons of a btnRow
				bool	, "autoWidth"	, 1, //kinda readonly: It's set by Container in measure to outerSize!=0
				bool	, "autoHeight"	, 1, //later everything else can read it.
				bool	, "hasHScrollBar"	, 1, //system manages this, not the user.
				bool	, "hasVScrollBar"	, 1,
						
				bool	, "_measured"	, 1, //used to tell if a top level container was measured already
				bool	, "saveVisibleBounds"	, 1, //draw() will save the visible innerBounds under the name id.appendIdx("visibleBounds");
				bool	, "_measureOnlyOnce"	, 1,
				bool	, "acceptEditorKeys"	, 1, //accepts Enter and Tab if it is a textEditor. Conflicts with transaction mode.
				ScrollState	, "hScrollState"	, 2,
				ScrollState	, "vScrollState"	, 2,
						//------------------------ 32bits ---------------------------------------
				bool	, "clickable"	, 1, //If false, hittest will not check this as clicked. It checks the parent instead.
				bool	, "noBackground"	, 1,
				bool	, "cullSubCells"	, 1, //clipSubCells must be enabled too
				bool	, "_hasDrawCallback"	, 1,
				bool	, "selected"	, 1, //maintained by system, not by user (in applyBtnStyle)
				bool	, "hidden"	, 1, //only affects draw() calls.
				bool	, "dontSearch"	, 1, //no search() inside this container
				bool	, "noHitTest"	, 1, //don't even bother to add this container and it's subcontainers to the hit list.
						
				bool	, "dontLocate"	, 1, //disables the locate() method for this container and its subcontainers
				bool	, "oldSelected"	, 1, //SelectionManager2 needs this.
						
				bool	, "changedCreated"	, 1, //Dide2.CodeRow: changed by creationg a new cell
				bool	, "changedRemoved"	, 1, //Dide2.CodeRow: changed by removing existing cells
						
				bool	, "dontStretchSubCells"	, 1, //Column: don't stretch the items to the innerWidth of the column.
						
				int	, "_dummy"	,19,
			)
		); 
	} 
	
	/+
		https://chat.openai.com/c/8be74a95-293e-405e-806d-f12483c2e8f1
		
		const string[] DataTypes = {
					 "ulong", "bool", "HAlign", "VAlign", "YAlign", "bool", "bool", "bool",
					 "bool", "bool", "bool", "bool", "bool", "bool", "uint", "bool", "bool",
					 "bool", "bool", "bool", "bool", "bool", "bool", "bool", "bool", "ScrollState",
					 "ScrollState", "bool", "bool", "bool", "bool", "bool", "bool", "bool",
					 "bool", "bool", "bool", "int"
		}; 
		
		const string[] NameFields = {
					 "_data", "wordWrap", "hAlign", "vAlign", "yAlign", "dontHideSpaces", "canSelect", "focused",
					 "hovered_deprecated", "clipSubCells", "_saveComboBounds", "_hasOverlayDrawing", "columnElasticTabs",
					 "rowElasticTabs", "targetSurface", "_debug", "btnRowLines", "autoWidth", "autoHeight", "hasHScrollBar",
					 "hasVScrollBar", "_measured", "saveVisibleBounds", "_measureOnlyOnce", "acceptEditorKeys",
					 "hScrollState", "vScrollState", "clickable", "noBackground", "cullSubCells", "_hasDrawCallback",
					 "selected", "hidden", "dontSearch", "noHitTest", "dontLocate", "oldSelected", "changedCreated",
					 "changedRemoved", "dontStretchSubCells", "_dummy"
		};
		
		const int[] SizeFields = {1, 2, 2, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 19};
	+/
	
	
	static assert(ContainerFlags.sizeof==8); 
	
	//Effective horizontal and vertical flow configuration of subCells
	enum FlowConfig
	{ autoSize, wrap, noScroll, scroll, autoScroll} 
	
	auto getHFlowConfig(in bool autoWidth, in bool wordWrap, in ScrollState hScroll) pure
	{
		return autoWidth	? FlowConfig.autoSize :
					 wordWrap	? FlowConfig.wrap :
					 hScroll==ScrollState.off	? FlowConfig.noScroll :
					 hScroll==ScrollState.on	? FlowConfig.scroll : FlowConfig.autoScroll; 
	} 
	
	bool getEffectiveHScroll(in bool autoWidth, in bool wordWrap, in ScrollState hScroll) pure
	{ return !autoWidth && !wordWrap && hScroll.getEffectiveScroll; } 
	
	auto getVFlowConfig(in bool autoHeight, in ScrollState vScroll) pure
	{
		return autoHeight ? FlowConfig.autoSize :
					 vScroll==ScrollState.off	? FlowConfig.noScroll :
					 vScroll==ScrollState.on	? FlowConfig.scroll : FlowConfig.autoScroll; 
	} 
	
	bool getEffectiveVScroll(in bool autoHeight, in ScrollState vScroll) pure
	{ return !autoHeight && vScroll.getEffectiveScroll; } 
	
}
version(/+$DIDE_REGION+/all)
{
	class Container : Cell
	{
		 //Container ////////////////////////////////////
		SrcId id; //Scrolling needs it. Also useful for debugging.
		
		auto getHScrollBar()
		{ return flags.hasHScrollBar ? im.hScrollInfo.getScrollBar(id) : null; } 
		auto getVScrollBar()
		{ return flags.hasVScrollBar ? im.vScrollInfo.getScrollBar(id) : null; } 
		auto getHScrollOffset()
		{ return flags.hasHScrollBar ? im.hScrollInfo.getScrollOffset(id) : 0; } 
		auto getVScrollOffset()
		{ return flags.hasVScrollBar ? im.vScrollInfo.getScrollOffset(id) : 0; } 
		auto getScrollOffset()
		{ return vec2(getHScrollOffset, getVScrollOffset); } 
		
		protected
		{
			public
			{
				 //Todo: ezt a publicot leszedni es megoldani szepen
				_FlexValue flex_; 
				Margin margin_; 
				Padding	padding_; 
				Border	border_; 
			} 
		} 
		
		/*
			 override{
			 void clearSubCells(){ subCells_ = []; }
			 @property Cell[] subCells() { return subCells_; }
			 @property void subCells(Cell[] cells) { subCells_ = cells; }
			}
		*/
		
		//subCells
		Cell[] subCells; 
		void clearSubCells()
		{ subCells = []; } 
		final auto subContainers()
		{ return subCells.map!(c => cast(Container)c).filter!"a"; } 
		
		void appendCell (Cell c)
		{
			if(c)
			subCells ~= c; 
		} 
		
		int cellCount()
		{ return cast(int)subCells.length; } 
		
		int subCellIndex(in Cell c) const
		{
			//Note: overflows at 2G items, I don't care because that would be 128GB memory usage.
			return cast(int)subCells.countUntil(c); 
		} 
		
		void adoptSubCells()
		{ subCells.each!(c => c.setParent(this)); } 
		
		final void append(Cell c)
		{ appendCell(c); } 
		final void append(Cell[] r)
		{ r.each!(c => appendCell(c)); } 
		
		final void append(void delegate() fun)
		{
			import het.ui : im; 
			append(im.build(fun)); 
		} 
		
		void	appendImg (File	fn, in TextStyle ts)
		{ appendCell(new Img(fn, ts.bkColor)); } 	//Todo: ezeknek az appendeknek a Container-ben lenne a helyuk
		void	appendChar(dchar	ch, in TextStyle ts)
		{ appendCell(new Glyph(ch, ts)); } 
		void appendStr (string s, in TextStyle ts)
		{
			foreach(ch; s.byDchar)
			appendChar(ch, ts); 
		} //Todo: elvileg NEM kell a byDchar mert az az alapertelmezett a foreach-ban.
		
		void appendCodeChar(dchar	ch, in TextStyle ts, SyntaxKind sk)
		{ appendCell(new Glyph(ch, ts, sk)); } 
		void appendCodeStr(string s, in TextStyle ts, SyntaxKind sk)
		{
			foreach(ch; s.byDchar)
			appendCodeChar(ch, ts, sk); 
		} 
		
		void appendCodeStr(string s, SyntaxKind sk)
		{
			static TextStyle style; 
			style.applySyntax(sk); 
			appendCodeStr(s, style, sk);  //Todo: syntax and style are redundant: syntax defines the style (more or less)
		} 
		
		void appendSyntaxChar(dchar ch, in TextStyle ts, ubyte syntax)
		{
			 //Todo: redundant: there is appendCodeChar too
			auto g = new Glyph(ch, ts); 
			g.syntax = syntax; 
			appendCell(g); 
		} 
		
		void appendSyntaxCharWithLineIdx(dchar ch, in TextStyle ts, ubyte syntax, int lineIdx)
		{
			 //Todo: this is used from CodeCOlumnBuildet.
			auto g = new Glyph(ch, ts); 
			g.syntax = syntax; 
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
		
		void internal_setSubCells(Cell[] c)
		{
			 //Todo: remove this
			subCells = c; 
		} 
		
		final override
		{
			ref _FlexValue flex()
			{ return flex_	; } 
			ref Margin	margin ()
			{ return margin_	; } //Todo: ezeknek nem kene virtualnak lennie, csak a containernek van borderje, a glyphnek nincs.
			ref Padding	padding()
			{ return padding_; } 
			ref Border	border ()
			{ return border_; } 
		} 
		
		RGB bkColor=clWhite; //Todo: background struct
		ContainerFlags flags; 
		
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
			auto getHFlowConfig()	const
			{ return .getHFlowConfig     (flags.autoWidth , flags.wordWrap,	flags.hScrollState); } 
			auto getEffectiveHScroll()	const
			{ return .getEffectiveHScroll(flags.autoWidth , flags.wordWrap,	flags.hScrollState); } 
			auto getVFlowConfig()	const
			{ return .getVFlowConfig     (flags.autoHeight,	flags.vScrollState); } 
			auto getEffectiveVScroll()	const
			{ return .getEffectiveVScroll(flags.autoHeight,	flags.vScrollState); } 
		} 
		
		float calcContentWidth ()
		{ return subCells.map!(c => c.outerRight ).maxElement(0); } 
		float calcContentHeight()
		{ return subCells.map!(c => c.outerBottom).maxElement(0); } 
		vec2 calcContentSize  ()
		{ return vec2(calcContentWidth, calcContentHeight); } 
		
		final void setSubContainerWidths(bool setAll=true)(float targetWidth)
		{
			foreach(c; subContainers)
			if(setAll ? true : c.outerWidth!=targetWidth)
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
			innerWidth	= calcContentWidth; 
			if(flags.autoHeight)
			innerHeight	= calcContentHeight; 
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
			{
				flags.autoWidth	= outerSize.x==0; 
				flags.autoHeight	= outerSize.y==0; 
			}
			
			//detect scrollbars
			const hFlow = getHFlowConfig, vFlow = getVFlowConfig, maxFlow = max(hFlow, vFlow); 
			
			flags.hasHScrollBar = false; 
			flags.hasVScrollBar = false; 
			
			if(maxFlow<=FlowConfig.noScroll)
			{
				 //very simple case with no scrolling, only autoSizing and wordWrapping
				rearrange; 
			}
			else
			{
				 //scr9ollbars are a possibility from here
				
				//Opt: cache calcContentSize. It is called too much
				//Opt: rearrange should optionally return contentSize
				
				const scrollThickness = DefaultScrollThickness,
							e = 1; //minimum area that must remain after the scrollbar.
				
				bool alloc(char o)()
				{
					const size = innerSize; 
					static if(o=='H')
					if(size.x>=e && (size.y>=scrollThickness+e || vFlow==FlowConfig.autoSize) && !flags.hasHScrollBar)
					{
						flags.hasHScrollBar = true; 
						if(vFlow!=FlowConfig.autoSize)
						outerSize.y -= scrollThickness; 
						return true; 
					}
					
					static if(o=='V')
					if(size.y>=e && (size.x>=scrollThickness+e || hFlow==FlowConfig.autoSize) && !flags.hasVScrollBar)
					{
						flags.hasVScrollBar = true; 
						if(hFlow!=FlowConfig.autoSize)
						outerSize.x -= scrollThickness; 
						return true; 
					}
					
					return false; 
				} 
				
				if(maxFlow<=FlowConfig.scroll)
				{
					 //there can be scrollbars, but no autoScrollbars
					if(hFlow==FlowConfig.scroll)
					alloc!'H'; 
					if(vFlow==FlowConfig.scroll)
					alloc!'V'; 
					rearrange; 
				}
				else
				{
					 //at least one axis is autoScroll, this is the most complicated case.
					if(hFlow==FlowConfig.autoScroll && vFlow==FlowConfig.autoScroll)
					{
						 //2 auto scrollbars
						rearrange; 
						const cs = calcContentSize; 
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
									if(cast(Column)this)
									rearrange; 
									else
									alloc!'H'; 
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
								alloc!'V'; //possivle V overflow because of HScrollBar
							}
						}
					}
					else if(hFlow==FlowConfig.autoScroll)
					{
						 //only auto hscroll
						if(vFlow==FlowConfig.scroll)
						alloc!'V'; //alloc fixed if needed
						rearrange; 
						if(calcContentWidth > innerWidth)
						alloc!'H'; 
					}
					else
					{
						 //only auto vscroll
						if(hFlow==FlowConfig.scroll)
						alloc!'H'; //alloc fixed if needed
						rearrange;    //Opt: this rearrange can exit early when the wordWrap and contentheight becomes too much.
						if(calcContentHeight > innerHeight)
						{
							if(alloc!'V' && (hFlow==FlowConfig.wrap || cast(Column)this/*column also changes the width!*/))
							{
								rearrange; //second rearrange
								//I think this is overkill, not needed: if(!flags.hasHScrollBar && calcContentWidth > innerWidth) alloc!'H';
							}
						}
					}
				}
				
				//setup the scrollbars
				if(flags.hasHScrollBar)
				im.hScrollInfo.update(this, calcContentWidth, innerWidth); 
				if(flags.hasVScrollBar)
				im.vScrollInfo.update(this, calcContentHeight, innerHeight); 
				
				//restore size after rearrange. (Autosize wont subtract the scrollbarthickness, so it will be added here as an extra.)
				if(flags.hasHScrollBar)
				outerSize.y += scrollThickness; 
				if(flags.hasVScrollBar)
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
		
		
		protected void drawSubCells_cull(Drawing dr)
		{
			//this uses linear search. It can be optimized in subClasses.
			if(auto b = dr.clipBounds)
			{
				b = dr.inverseInputTransform(b); 
				foreach(c; subCells)
				if(b.overlaps(c.outerBounds))
				c.draw(dr); 
			}
		} 
		
		static bounds2 _savedComboBounds; //when saveComboBounds flag is active it saves the absolute bounds
		
		override void draw(Drawing dr)
		{
			if(flags.hidden)
			return; 
			//Todo: automatic measure when needed. Currently it is not so well. Because of elastic tabs.
			//if(chkSet(measured)) measure;
			
			if(border.borderFirst)
			{
				border.color = bkColor; 
				drawBorder(dr); //for code editor
			}
			
			//autofill background
			if(!flags.noBackground)
			{
				dr.color = bkColor;          //Todo: refactor backgorund and border drawing to functions
				
				if(border.borderFirst)
				{ dr.fillRect(innerBounds); }
				else
				{ dr.fillRect(border.adjustBounds(borderBounds_inner)); }
			}
			
			if(flags._saveComboBounds)
			_savedComboBounds = dr.inputTransform(outerBounds); 
			
			const 	scrollOffset = getScrollOffset,
				hasScrollOffset = !isnull(scrollOffset); 
			
			if(flags.saveVisibleBounds)
			{
				flags.saveVisibleBounds = true; 
				imstVisibleBounds(id) = bounds2(scrollOffset, scrollOffset+innerSize); 
				//print("draw", id, imstVisibleBounds(id));
			}
			
			dr.translate(innerPos); 
			const useClipBounds = flags.clipSubCells; 
			if(useClipBounds)
			dr.pushClipBounds(bounds2(0, 0, innerWidth, innerHeight)); 
			
			if(hasScrollOffset)
			dr.translate(-scrollOffset); 
			
			//recursively draw subCells
			if(flags.cullSubCells)
			{
				drawSubCells_cull(dr); //it can be optimized
			}
			else
			{ subCells.each!(c => c.draw(dr)); }
			
			if(flags._hasOverlayDrawing)
			dr.copyFrom(g_getOverlayDrawing(this)); 
			
			if(flags._hasDrawCallback)
			g_getDrawCallback(this)(dr, this); 
			
			onDraw(dr); 
			
			if(flags.btnRowLines && subCells.length>1)
			{
				dr.color = clWinText; dr.lineWidth = 1; dr.alpha = 0.25f; 
				foreach(sc; subCells[1..$])
				dr.vLine(sc.outerX, sc.outerY+sc.margin.top+.25f, sc.outerY+sc.outerHeight-sc.margin.bottom-.25f); 
				dr.alpha = 1; 
			}
			
			if(hasScrollOffset)
			dr.pop; 
			
			{
				auto hb = getHScrollBar, vb = getVScrollBar; 
				if(hb || vb)
				{
					if(hb)
					hb.draw(dr);  //Todo: getHScrollBar?.draw(gl);
					if(vb)
					vb.draw(dr); 
					
					if(hb&&vb)
					{
						const bnd = getScrollResizeBounds(hb, vb); 
						dr.color = clScrollBk; 
						dr.fillRect(bnd); 
					}
				}
			}
			
			if(useClipBounds)
			dr.popClipBounds; 
			dr.pop; 
			
			if(!border.borderFirst)
			drawBorder(dr); //border is the last by default
			
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
		} ; 
		
		
		struct SearchResult
		{
			Container container; 
			vec2 absInnerPos; 
			Cell[] cells; //Todo: if this is empty, the whole container should be marked
			string reference; //user can use it to identify the search result
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
					dr.drawFontGlyph(stIdx, innerBounds + absInnerPos, clHighlight, fontFlags); 
				}
			} 
		} 
		
		/// do a recursive visit. Search result and continuation is supplied by alias functions
		auto search(string searchText, vec2 origin = vec2.init)
		{
			
			static struct SearchContext
			{
				dstring searchText; 
				vec2 absInnerPos; 
				Cell[] cellPath; 
				
				SearchResult[] results; 
				int maxResults = 9999; 
				
				bool canStop() const
				{ return results.length >= maxResults; } 
			} 
			
			static bool cntrSearchImpl(Container thisC, ref SearchContext context)
			{
				//returns: "you can exit from recursion now"    It is possible to do an optimized exit when context.canStop==true.
				if(thisC.flags.dontSearch)
				return false; 
				
				//recursive entry/leave
				context.cellPath ~= thisC; 
				context.absInnerPos += thisC.innerPos; 
				
				scope(exit)
				{
					context.absInnerPos -= thisC.innerPos; 
					context.cellPath.popBack; 
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
						
						//print("searching in", chars.text);
						
						size_t searchBaseIdx = 0; 
						while(1)
						{
							auto idx = chars.indexOf(context.searchText, No.caseSensitive); 
							if(idx<0)
							break; 
							
							context.results ~= SearchResult(
								thisC, 
								context.absInnerPos, 
								cells[baseIdx+searchBaseIdx+idx..$][0..context.searchText.length]
							); 
							if(context.canStop)
							return true; 
							
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
			
			auto context = SearchContext(searchText.to!dstring, origin); 
			if(!searchText.empty)
			cntrSearchImpl(this, context); 
			return context.results; 
		} 
		
		
		private enum genSetChanged = q{
			if(!flags.changed#){
				flags.changed# = true;
				if(auto p = getParent) if(p)
					p.setChanged#;
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
			if(flags.changed#){
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
		
		//changed tracking for syntax highlight /////////////////////////////
		
		///Override these to implement changedTime tracking.
		/+
			int getThisChangedTime(){ return 0; }
				void setThisChangedTime(int i){ } ///Ditto
			
				@property int changedTime(){
						return getThisChangedTime;
				}
			
				@property void changedTime(int	i){
						//no optimization: Because	there can be non channgedTime aware classes in the parent chain.
						if(i>getThisChangedTime){	//only proceed when previous changedTime time is lower than current.
							setThisChangedTime(i);
							if(auto p = getParent())
									p.changedTime = i;
						}
				}
		+/
		
	} 
	
	
	class Row : Container
	{
		 //Row ////////////////////////////////////
		
		//for Elastic tabs
		/+private+/ int[] tabIdxInternal; 
		int rearrangedLineCount; 
		
		void refreshTabIdx()
		{ tabIdxInternal = subCells.enumerate.filter!(a => isTab(a.value)).map!(a => cast(int)a.index).array; } 
		
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
				{ return subCells[i]; } 
				auto actWidth()
				{ return act.outerWidth; } 
				auto actIsNewLine()
				{
					if(auto g = cast(Glyph)act)
					return g.isNewLine; else
					return false; 
				} 
				
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
				
				act.outerPos = cursor; //because of this, newline and wrapped space goes to the next line. This allocates a new wrapped_row for them.
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
			if(flags.rowElasticTabs)
			adjustTabSizes_multiLine; 
			else adjustTabSizes_singleLine; 
			
			solveFlexAndMeasureAll();  //Opt: a containerFlag to disable the slow flexSum calculation
			
			const doWrap = flags.wordWrap && !flags.autoWidth; 
			
			auto wrappedLines = makeWrappedLines(doWrap); 
			//LOG("wl", wrappedLines, autoWidth, wrappedLines.calcWidth);
			
			if(flags.rowElasticTabs)
			processElasticTabs(wrappedLines); 
			
			//hide spaces on the sides by wetting width to 0. This needs for size calculation.
			//Todo: don't do this for the line being edited!!!
			if(doWrap && !flags.dontHideSpaces)
			wrappedLines.hideSpaces(flags.hAlign); 
			
			//horizontal alignment, sizing
			if(flags.autoWidth)
			innerWidth = wrappedLines.calcWidth; //set actual size if automatic
			
			//horizontal text align on every line
			if(!flags.autoWidth || wrappedLines.length>1)
			wrappedLines.applyHAlign(flags.hAlign, innerWidth); 
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
				wrappedLines.applyVAlign(flags.vAlign, innerHeight); 
			}
			
			wrappedLines.applyYAlign(flags.yAlign); 
			
			//remember the contents of the edited row
			rememberEditedWrappedLines(this, wrappedLines); 
			
			rearrangedLineCount = wrappedLines.length.to!int; 
		} 
		
		override void draw(Drawing dr)
		{
			if(/*flags.targetSurface==0*/1)
			{
				//dr.clipBounds.print;
				//dump;
			}
			
			super.draw(dr); //draw frame, bkgnd and subCells
			
			//draw the carets and selection of the editor
			drawTextEditorOverlay(dr, this); 
		} 
		
		
		override Cell[] internal_hitTest_filteredSubCells(vec2 p)
		{
			if(rearrangedLineCount!=1)
			{
				return super.internal_hitTest_filteredSubCells(p); //Todo: wrapped filter support
			}
			else
			{
				return sortedSubCellsAroundX(subCells, p); //Bug: it wont work for multiline
			}
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
			assert(!flags.wordWrap); //Todo: no multiline either
			
			if(subCells.empty)
			return null; 
			
			if(x<subCells.front.outerLeft)
			return snapToNearest ? subCells.front : null; 
			
			foreach(sc; subCells)
			if(x<sc.outerRight)
			return sc; 
			
			return snapToNearest ? subCells.back : null; 
		} 
		
	} 
	
	class Column : Container
	{
		override void rearrange()
		{
			
			//measure the subCells and stretch them to a maximum width
			if(flags.dontStretchSubCells)
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
			
			if(flags.columnElasticTabs)
			processElasticTabs(subCells); //Todo: ez a flex=1 -el egyutt bugzik.
			
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
			
			subCells.spreadV; 
			
			if(flags.autoHeight)
			innerHeight = calcContentHeight; 
		} 
		
		override void drawSubCells_cull(Drawing dr)
		{
			if(auto b = dr.clipBounds)
			{
				b = dr.inverseInputTransform(b); 
				
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
							c.draw(dr); 
						}
					}
				} 
				
				void drawPages(Cell[][] pages)
				{
					if(flags.dontStretchSubCells)
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
				if(flags.dontStretchSubCells)
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
		{ idle, move, rectSelect} 
		MouseOp mouseOp; 
		
		vec2 mouseLast; 
		
		enum SelectOp
		{ none, add, sub, toggle, clearAdd} 
		SelectOp selectOp; 
		
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
}
version(/+$DIDE_REGION+/all)
{
	//Todo: Unqual is not needed to check a type. Try to push this idea through a whole testApp.
	//Todo: form resize eseten remeg a viewGUI-ra rajzolt cucc.
	//Todo: Beavatkozas / gombnyomas utan NE jojjon elo a Button hint. Meg a tobbi controllon se!
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
		
		p.fullName	   = FieldProps.makeFullName(parentFullName, fieldName); 
		p.name	   = fieldName; 
		p.caption	   = getUDA!(f, CAPTION).text; 
		p.hint	   = getUDA!(f, HINT   ).text; 
		//Todo: readonly
		p.unit	    = getUDA!(f, UNIT   ).text; 
		p.range	    = getUDA!(f, RANGE); 
		p.indent	    = hasUDA!(f, INDENT); 
		p.choices	    = EnumMemberNames!T; 
		
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
		if(prop is null)
		return; 
		auto fp = FieldProps(FieldProps.makeFullName(parentFullName, prop.name), prop.name, prop.caption, prop.hint); 
		fp.isReadOnly = prop.isReadOnly; 
		
		void doit(T)(ref T act)
		{
			immutable old = act; 
			stdUI(act, fp); 
			prop.uiChanged |= old != act; 
		} 
		
		if(auto p = cast(IntProperty)prop)
		{
			fp.range.low = p.min; 
			fp.range.high = p.max; 
			doit(p.act); 
		}else if(auto p = cast(FloatProperty)prop)
		{
			fp.range.low = p.min; 
			fp.range.high = p.max; 
			doit(p.act); 
		}else if(auto p = cast(StringProperty)prop)
		{
			fp.choices = p.choices; 
			doit(p.act); 
		}else if(auto p = cast(BoolProperty)prop)
		{ doit(p.act); }else if(auto p = cast(PropertySet)prop)
		{ stdStructFrame(fp.getCaption, { p.properties.each!stdUI; }); }
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
						{ ComboBox(data, thisFieldProps.choices, genericId(thisFieldProps.hash), hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly), { width = fh*10; }); }else
						{ Edit(data, genericId(thisFieldProps.hash), hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly), { width = fh*10; }); }
					}
				); 
			}else static if(isFloatingPoint!T)
			{
				Row(
					{
						Text(thisFieldProps.getCaption, "\t"); 
						auto s = format("%g", data); 
						Edit(s, genericId(thisFieldProps.hash), hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly), { width = fh*4.5; }); 
						try
						{ data = s.to!T; }catch(Throwable)
						{}
						Text(thisFieldProps.unit, "\t"); 
						if(
							thisFieldProps.range.valid//Todo: im.range() conflict
						)
						Slider(data, hint(thisFieldProps.hint), range(thisFieldProps.range.low, thisFieldProps.range.high), genericId(thisFieldProps.hash+1), { width = 180; }); //Todo: rightclick
						//Todo: Bigger slider height when (theme!="tool")
					}
				); 
			}else static if(isIntegral!T)
			{
				Row(
					{
						Text(thisFieldProps.getCaption, "\t"); 
						auto s = data.text; 
						Edit(s, genericId(thisFieldProps.hash), hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly), { width = fh*4.5; }); 
						try
						{ data = s.to!T; }catch(Throwable)
						{}
						Text(thisFieldProps.unit, "\t"); 
						if(
							thisFieldProps.range.valid//Todo: im.range() conflict
						)
						Slider(data, range(thisFieldProps.range.low, thisFieldProps.range.high), genericId(thisFieldProps.hash+1), hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly), { width = 180; }); //Todo: rightclick
					}
				); 
			}else static if(is(T == bool))
			{
				Row(
					{
						Text(thisFieldProps.getCaption, "\t"); 
						ChkBox(data, "", genericId(thisFieldProps.hash), hint(thisFieldProps.hint), enable(!thisFieldProps.isReadOnly)); 
						Text("\t"); 
					}
				); 
			}else static if(isAggregateType!T)
			{
				 //Struct, Class
				
				enum bool notHidden(string fieldName) = !hasUDA!(__traits(getMember, T, fieldName), HIDDEN); 
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
			updateInternal(
				{
					//collect and actualize data
					textureCount.act[0] = textures.length; 
					texturePoolSize.act[0] = textures.poolSizeBytes; 
					textureUsedSize.act[0] = textures.usedSizeBytes; 
					
					const bs = bitmaps.stats; 
					bitmapCount	    .act[0] = bs.count; 
					residentBitmapSize	    .act[0] = bs.residentSizeBytes; 
					nonUnloadableBitmapSize.act[0] = bs.nonUnloadableSizeBytes; 
					allBitmapSize          .act[0] = bs.allSizeBytes; 
					
					const vs = virtualFiles.stats; 
					virtualFileCount.act[0]	= vs.count; 
					residentVirtualFileSize	.act[0] = vs.residentSizeBytes; 
					allVirtualFileSize	.act[0] = vs.allSizeBytes; 
					
					UPS.act[0] = mainWindow.UPS; 
					FPS.act[0] = mainWindow.FPS; 
					
					TPS.act[0] = het.win.TPS; 
					VPS.act[0] = het.win.VPS; 
					
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
					clTexturePool 	= RGB(255, 180, 40),
					clTextureUsed 	= RGB(180, 255, 40),
						
					clBitmap	= clAqua,
					clHotBitmap	= mix(clGray, clBitmap, .5),
					clResidentBitmap	= mix(clGray, clBitmap, .25),
						
					clVirtualFile	= RGB(100, 150, 255),
					clResidentVirtualFile	= mix(clGray, clVirtualFile, .25),
						
					clUPS	= RGB(180, 40, 255),
					clFPS	= RGB(255, 40, 180),
						
					clTPS	= RGB(40,  80, 255),
					clVPS	= RGB(40, 255,  80),
						
					clGcUsed	= RGB(120, 180, 40),
					clGcAll	= RGB(40, 220, 120),
					clGcRate	= RGB(80, 160,  90); 
				
				static int timeIdx = 0; 
				int gridXStepSize = Item.N/(timeIdx==2 ? 10 : 5); 
				
				
				void Legend(string title, float size=float.nan, RGB color = RGB(1, 2, 3), string suffix="")
				{
					if(color != RGB(1, 2, 3))
					Text(color, symbol("CheckboxFill"), tsNormal.fontColor, " "); 
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
							bkColor = RGB(40, 40, 40); 
							padding = "3"; 
							margin = "2 0"; 
							innerWidth = graphWidth; 
							innerHeight = fh*3.5; 
							
							/*
								auto hit = hitTest(actContainer, true);
								const w = hit.hitBounds.width-actContainer.totalGapSize.x;
								const h = innerHeight;
							*/
							
							const w = innerWidth; 
							const h = innerHeight; 
							
							auto dr = new Drawing; 
							with(dr)
							{
								const
									dataWidth	= data.map!(d => d.values.length).maxElement(1),
									dataHeight 	= data.map!(d => d.values.maxElement(1)).maxElement(1),
									sx	=  (w+1) / dataWidth,
									sy	= -(h) / dataHeight; 
								
								dr.color = RGB(70, 70, 70); 
								dr.lineWidth = 1; 
								if(gridXStepSize)
								iota(0, dataWidth+1, gridXStepSize).each!(i => vLine(round(sx*i)-.5f, 0, h)); 
								if(gridYDivisions)
								iota(gridYDivisions+1).each!(i => hLine(0, (h*i/gridYDivisions).round-.5f, w)); 
								
								dr.lineWidth = 2; 
								foreach(d; data)
								{ color = d.color;  hGraph(0, h, d.values, sx, sy); }
							}
							addOverlayDrawing(dr); 
						},
						genericId(name)
					); 
				} 
				
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
							Data(allVirtualFileSize     .history[timeIdx][], clVirtualFile        )
						], gridXStepSize
					); 
				} 
				
				void BitmapCacheGraph()
				{
					Row(
						{
							Text(format!"Bitmaps (%s)"(bitmapCount.val)); 	Flex; 
							Legend("Res" , residentBitmapSize.val	, clResidentBitmap	, "B"); 	Spacer; 
							Legend("Hot" , nonUnloadableBitmapSize.val	, clHotBitmap	, "B"); 	Spacer; 
							Legend("All" , allBitmapSize.val	, clBitmap	, "B"); 
						}
					); 
					Graph(
						"BitmapCache", [
							Data(residentBitmapSize     .history[timeIdx][], clResidentBitmap),
							Data(nonUnloadableBitmapSize.history[timeIdx][], clHotBitmap	    ),
							Data(allBitmapSize          .history[timeIdx][], clBitmap	    )
						], gridXStepSize
					); 
				} 
				
				void TextureCacheGraph()
				{
					Row(
						{
							Text(format!"Textures (%s)"(textureCount.val));  Flex; 
							Legend("Used", textureUsedSize.val, clTextureUsed, "B");   Text("   "); 
							Legend("Pool", texturePoolSize.val, clTexturePool, "B"); 
						}
					); 
					//Text("Config: "~textures.megaTextureConfig);
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
				
				void SelectTimeIdx(ref int t)
				{
					Row(
						HAlign.right, {
							Text("Time step"); 	ComboBox(timeIdx, Item.timeStepNames , { width = fh*4; }); 
							Text("   Visible interval"); 	ComboBox(timeIdx, Item.timeRangeNames, { width = fh*4; }); 
						}
					); 
				} 
				
				Column(
					{
						padding = "4"; 
						border = "1 normal silver"; 
						theme = "tool"; 
						Text(bold("Resource Monitor")); 	Spacer; 
						VirtualFileGraph; 	Spacer; 
						BitmapCacheGraph; 	Spacer; 
						TextureCacheGraph; 	Spacer; 
						TPSGraph; 	Spacer; 
						FPSGraph; 	Spacer; 
						GCGraph; 	Spacer; 
						GCRateGraph; 	Spacer; 
						SelectTimeIdx(timeIdx); 
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
							if(auto w = cast(GLWindow)mainWindow)
							ChkBox(w.showFPS	, "Show FPS Graph"       ); 
							ChkBox(showResMonitor,	"Show Resource Monitor"); 
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
							foreach(idx, ref b; Drawing.globalShaderParams.bools)
							ChkBox(b, idx.format!"bool%d", genericId(idx)); 
						}
					); 
					Spacer; 
					Column(
						{
							foreach(idx, ref f; Drawing.globalShaderParams.floats)
							Row(
								{
									theme = "tool"; 
									Text(idx.format!"float%d\t"); 
									Slider(f, range(0, 1), { width = 12*fh; }, genericId(idx)); 
								}
							); 
							
						}
					); 
				}
			); 
		}
	} 
	
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
}version(/+$DIDE_REGION Graph+/all)
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
		 //GraphNode /////////////////////////////
		mixin CachedDrawing; 
		
		Graph parent; 
		
		this()
		{ flags._measureOnlyOnce = true; } 
		
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
		{ return innerBounds + parent.innerPos; } ; 
		auto absInnerPos   () const
		{ return innerPos    + parent.innerPos; } ; 
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
			enforce(!node.parent                , "Node already has a parent."                                  ); 
			
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
			alias GraphNode = Node; /*Todo: fucking name collision with im.Node */   with(im)
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
			bool mouseOverUI, wantMouse, wantKeys; 
			private bool inFrame, canDraw; //synchronization for internal methods
		
			//target surface is a view and a drawing
			struct TargetSurface
		{ View2D view; } 
			private TargetSurface[2] targetSurfaces;  //surface0: zoomable view, surface1: GUI view
		
			void setTargetSurfaceViews(View2D viewWorld, View2D viewGUI)
		{
			targetSurfaces[0].view = viewWorld; 
			targetSurfaces[1].view = viewGUI; 
		} 
		
			auto getView()
		{ return targetSurfaces[0].view; } 
			auto getViewGUI()
		{ return targetSurfaces[1].view; } 
		
			/*private*/ View2D actView; //this is only used for getting mouse position from actview
		
			//Todo: this should be the only opportunity to switch between GUI and World. Better that a containerflag that is initialized too late.
			private void selectTargetSurface(int n)
		{
			enforce(n.among(0, 1)); 
			with(targetSurfaces[n])
			{ actView = view; }
		} 
		
			float deltaTime=0; 
		
			bool comboState; //automatically cleared on focus.change
			bool comboOpening; //popup cant disappear when clicking away and this is set true by the combo
			Id comboId;    //when the focus of this is lost, comboState goes false
		
			//GUI area that tracks PanelPosition changes
			bounds2 clientArea; 
		
			enum doTiming = false; 
		
			static if(doTiming)
		{ double tBeginFrame, tEndFrame, tDraw; }
		
			//Todo: package visibility is not working as it should -> remains public
			void _beginFrame(TargetSurface[2] targetSurfaces)
		{
			//called from mainform.update
			//PING(5);
			
			static if(doTiming)
			{ const T0 = QPS; scope(exit) tBeginFrame = QPS-T0; }
			enforce(!inFrame, "im.beginFrame() already called."); 
			
			this.targetSurfaces = targetSurfaces; 
			selectTargetSurface(1); //default is the GUI surface
			
			//inject stuff into het.uibase. So no import het.ui is needed there.
			//Todo: het.uibase was merged with het.ui. This is no longer needed.
			static auto getActFontHeight()
			{ return float(textStyle.fontHeight); 	} 	 .g_actFontHeightFunct	= &getActFontHeight; 
			static auto getActFontColor ()
			{ return textStyle.fontColor; 	} 	 .g_actFontColorFunct	= &getActFontColor; 
			.g_getOverlayDrawingFunct = &getOverlayDrawing; 
			.g_getDrawCallbackFunct = &getDrawCallback; 
			
			//update building/measuring/drawing state
			inFrame = true; 
			canDraw = false; 
			
			im.reset; 
			//this goes into endFrame, so the latest hit data will be accessible more early. hitTestManager.initFrame;
			
			//clear last frame's object references
			focusedState.container = null; 
			textEditorState.beginFrame; 
			
			popupState.reset; 
			comboOpening = false; 
			
			//this is needed for PanelPosition
			clientArea = targetSurfaces[1].view.screenBounds_anim.bounds2; //Maybe it is the same as the bounds for clipping rects: flags.clipChildren
			
			static DeltaTimer dt; 
			deltaTime = dt.update; 
			
			ImStorageManager.purge(200); 
			
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
			//PING(6);
			
			updateFlashMessages_internal_onEndFrame; 
			
			static if(doTiming)
			{ const T0 = QPS; scope(exit) tEndFrame = QPS-T0; }
			
			enforce(inFrame, "im.endFrame(): must call beginFrame() first."); 
			enforce(stack.length==1, "FATAL ERROR: im.endFrame(): stack is corrupted. 1!="~stack.length.text); 
			
			selectTargetSurface(1); //GUI surface by default
			
			auto rc = rootContainers(true); 
			rc = rc.sort!((a, b) => a.flags.targetSurface < b.flags.targetSurface, SwapStrategy.stable).array; 
			
			//measure
			foreach(a; rc)
			if(!a.flags._measured)
			a.measure; //some panels are already have been measured
			
			const screenBounds = targetSurfaces[1].view.screenBounds_anim.bounds2; 
			
			//Todo: remove this: applyScrollers(screenBounds);
			
			hScrollInfo.createBars(true); 
			vScrollInfo.createBars(true); 
			
			popupState.doAlign; 
			
			//from here, all positions are valid
			
			//hittest in zOrder (currently in reverse creation order)
			bool[2] mouseOverUI; 
			bool mouseOverPopup; 
			foreach_reverse(a; rc)
			{
				const surf = a.flags.targetSurface; //1: gui, 0:view
				
				const uiMousePos = targetSurfaces[surf].view.mousePos.vec2; 
				if(a.internal_hitTest(uiMousePos))
				{
					mouseOverUI[surf] = true; 
					
					if(popupState.cell==a)
					mouseOverPopup = true; 
					
					break; //got a hit, so escape now
				}
			}
			
			if(VisualizeHitStack)
			{
				drVisualizeHitStack = new Drawing; 
				hitTestManager.draw(drVisualizeHitStack); 
			}
			
			//all hitTest are done, move hitTestManager to the next frame. Latest hittest data will be accessible right after this.
			hitTestManager.nextFrame; 
			
			//clicking away from popup closes the popup
			if(comboState && !comboOpening && !mouseOverPopup && (inputs.LMB.pressed || inputs.RMB.pressed))
			comboState = false; 
			
			//the IM GUI wants to use the mouse for scrolling or clicking. Example: It tells the 'view' not to zoom.
			wantMouse = mouseOverUI[1]; 
			
			if(textEditorState.active)
			{
				 //an edit control is active.
				//Todo: mainWindow.isForeground check
				auto err = textEditorState.processQueue; 
			}
			wantKeys = textEditorState.active; 
			
			generateHints(screenBounds); 
			
			//update building/measuring/drawing state
			canDraw = true; 
			inFrame = false; 
		} 
		
			bounds2[2] surfaceBounds; 
		
			Drawing drVisualizeHitStack; 
		
			int actTargetSurface; //0:world, 1:GUI
		
			private enum bool reuseDr = 0; 
			private Drawing[2] staticDr; 
		
			void _drawFrame(string restrict="")()
		{
			
			//PING(7);
			static if(doTiming)
			{
				const T0 = QPS; scope(exit)
				{ tDraw = QPS-T0; print(format!"im.timing: begin %5.1f   end %5.1f   draw %5.1f ms"(tBeginFrame*1000, tEndFrame*1000, tDraw*1000)); } 
			}
			
			static assert(restrict=="system call only", "im.draw() is restricted to call by system only."); 
			enforce(canDraw, "im.draw(): canDraw must be true. Nothing to draw now."); 
			
			static if(reuseDr)
			{
				if(!staticDr[0])
				staticDr = [new Drawing("im0"), new Drawing("im1")]; 
				auto dr = staticDr; 
			}else
			{ auto dr = [new Drawing, new Drawing]; }
			
			//init clipbounds
			foreach(i, ref d;	dr)
			{
				ref view()
				{ return targetSurfaces[i].view; } 
				d.zoomFactor	= view.scale; 
				d.invZoomFactor	= view.invScale; 
				d.pushClipBounds(view.screenBounds_anim.bounds2.inflated(-view.screenBounds_anim.bounds2.size*0)); 
			}
			
			foreach(i; 0..2)
			surfaceBounds[i] = bounds2.init; 
			foreach(a; rootContainers(true))
			{
				const s = a.flags.targetSurface; 
				surfaceBounds[s] |= a.outerBounds; 
				actTargetSurface = s; 
				a.draw(dr[s]); //draw in zOrder
			}
			
			foreach(i, d; dr)
			{
				//it's not good because of invisible scrollable elements. -> surfaceBounds[i] |= dr[i].bounds;
				d.popClipBounds; 
				d.glDraw(targetSurfaces[i].view); 
				d.clear; 
			}
			
			if(VisualizeHitStack && drVisualizeHitStack)
			{
				drVisualizeHitStack.glDraw(targetSurfaces[1].view); //Todo: problem with hitStack: it is assumed to be on GUI view
			}
			drVisualizeHitStack.free; 
			
			//not needed, gc is perfect.  foreach(r; root) if(r){ r.destroy; r=null; } root.clear;
			//Todo: ezt tesztelni kene sor cell-el is! Hogy mekkorak a gc spyke-ok, ha manualisan destroyozok.
			
			//Todo: if window resizing, draw is called without update!!!  canDraw = false; can detect it.
		} 
		
			//PanelPosition ///////////////////////////////////////////
			//aligns the container on the screen
		
			enum PanelPosition
		{
			none, topLeft, topCenter, topRight, leftCenter, center, rightCenter, bottomLeft, bottomCenter, bottomRight,
			topClient, leftClient, client, rightClient, bottomClient	
		} 
		
			private bool isAlignPosition (PanelPosition pp)
		{
			with(PanelPosition)
			return pp.inRange(topLeft  , bottomRight ); 
		} //it will only position the container
			private bool isClientPosition(PanelPosition pp)
		{
			with(PanelPosition)
			return pp.inRange(topClient, bottomClient); 
		} //it will change the client rect too
		
			private void initializePanelPosition(.Container cntr, PanelPosition pp, in bounds2 area)
		{
			with(PanelPosition)
			{
				//flags.targetSurface is unknown at this point, will check it later	in 'finalize'
				if(pp.among(client, topClient, bottomClient))
				cntr.outerWidth	= area.width; 
				else if(pp.among(client, leftClient, rightClient)) cntr.outerHeight	= area.height; 
			}
		} 
		
			private void finalizePanelPosition(.Container cntr, PanelPosition pp, ref bounds2 area)
		{
			with(PanelPosition)
			{
				if(pp == none)
				return; 
				
				enforce(cntr.flags.targetSurface == 1, "Unable to set PanelPosition on world_surface."); 
				
				cntr.measure; //must know all the sizes from now on
				
				if(isAlignPosition(pp))
				{
					ivec2 p; divMod(cast(int)pp-1, 3, p.y, p.x); 
					if(p.x.inRange(0, 2) && p.y.inRange(0, 2))
					{
						auto t = p*.5f,
								 u = vec2(1)-t; 
						
						cntr.outerPos = area.topLeft*u + area.bottomRight*t //Todo: bug: fucking vec2.lerp is broken again
													- cntr.outerSize*t; 
					}
				}else if(isClientPosition(pp))
				{
					//Todo: put checking for running out of area and scrolling here.
					switch(pp)
					{
						case topClient: cntr.outerPos = area.topLeft; area.top	+= cntr.outerHeight; break; 
						case bottomClient: area.bottom	-= cntr.outerHeight; cntr.outerPos	= area.bottomLeft	; break; 
						case leftClient	: cntr.outerPos	= area.topLeft	; area.left    += cntr.outerWidth	; break; 
						case rightClient	: area.right	-= cntr.outerWidth	; cntr.outerPos = area.topRight	; break; 
						case client	: cntr.outerPos = area.topLeft	; cntr.outerSize = area.size; area = bounds2.init; break; 
						default: ERR("invalid PanelPosition"); 
					}
				}
			}
		} 
		
			void Panel(alias string srcModule=__MODULE__, size_t srcLine=__LINE__, T...)(in T args)
		{
			 //Todo: multiple Panels, but not call them frames...
			enforce(actContainer is null, "Panel() must be on root level"); 
			
			//Todo: this should work for all containers, not just high level ones
			PanelPosition pp; 
			static foreach(idx, a; args)
			static if(is(Unqual!(T[idx]) == PanelPosition))
			pp = a; 
			
			.Container cntr; 
			
			Document!(srcModule, srcLine)(
				{
					 //Todo: why document? It should be a template parameter!
					cntr = actContainer; 
					
					//preparations
					initializePanelPosition(cntr, pp, clientArea); 
					//Todo: outerSize should be stored, not innerSize, because the padding/border/margin settings after this can fuck up the alignment.
					
					//default panel frame
					padding = "4"; 
					border = "1 normal silver"; 
					
					//call the delegates
					static foreach(a; args)
					static if(__traits(compiles, a()))
					if(a)
					a(); //delegate/function
				}
			); 
			
			finalizePanelPosition(cntr, pp, clientArea); 
		} 
		
			//Focus handling /////////////////////////////////
			struct FocusedState
		{
			Id id;              //globally store the current hash
			.Container container;  //this is sent to the Selection/Draw routines. If it is null, then the focus is lost.
			
			void reset()
			{ this = typeof(this).init; } 
		} 
			FocusedState focusedState; 
		
			TextEditorState textEditorState; //maintained by edit control
		
			void onFocusLost(in Id oldId)
		{
			if(comboId && oldId==comboId)
			{
				comboState = false; 
				comboId = Id.init; 
			}
		} 
		
			/// internal use only
			bool focusUpdate(
			.Container container, in Id id, bool canFocus, lazy bool enterFocusNow, lazy bool exitFocusNow, 
			void delegate() onEnter, void delegate() onFocused, void delegate() onExit
		)
		{
			if(focusedState.id==id)
			{
				if(!canFocus || exitFocusNow)
				{
					 //not enabled anymore: exit focus
					if(onExit)
					onExit(); 
					focusedState.reset; 
					
					onFocusLost(id); 
				}
			}else
			{
				if(canFocus && enterFocusNow)
				{
					 //newly enter the focus
					onFocusLost(focusedState.id); 
					
					focusedState.reset; 
					focusedState.id = id;     //Todo: ez bugos, mert nem hivodik meg a focusExit, amikor ez elveszi a focust
					focusedState.container = container; 
					if(onEnter)
					onEnter(); 
				}
			}
			
			bool res = focusedState.id==id; 
			if(res)
			focusedState.container = container; 
			container.flags.focused = res; 
			
			if(res && onFocused)
			onFocused(); 
			
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
		
			//hints /////////////////////////////////////////////////////////////////
		
			const float HintActivate_sec	 = 0.5,
									HintDetails_sec	 = 2.5,
									HintRelease_sec	 = 1; 
		
			struct HintRec
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
		
			private enum hintHandler = q{
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
		
			private void generateHints(in bounds2 screenBounds)
		{
			 //called on the end of the frame
			static float mouseStopped_secs = 0; 
			static float noHint_secs = 0; 
			
			const userBlocking = "Esc,Enter,LMB,RMB,MMB,Space".split(",").map!(k => inputs[k].active).any; 
			
			if(inputs.MX.delta==0 && inputs.MY.delta==0)
			mouseStopped_secs += deltaTime; 
			else mouseStopped_secs = 0; 
			
			if(hints.empty)
			noHint_secs += deltaTime; 
			else noHint_secs = 0; 
			
			//enter hint mode
			if(!hints.empty && !userBlocking)
			{
				if(hintState == HintState.idle	&& mouseStopped_secs>HintActivate_sec)
				hintState = HintState.active; 
				if(hintState == HintState.active	&& mouseStopped_secs>HintDetails_sec)
				hintState = HintState.details; 
			}
			
			//exit hint mode
			if(hintState != HintState.idle)
			{
				//immediately hide on particular user events
				if(userBlocking)
				hideHints; 
				
				//hide after no hints to display for a while
				if(noHint_secs>HintRelease_sec)
				hideHints; 
			}
			
			//actual hint generation
			HintRec lastHint; 
			if(hints.length)
			lastHint = hints[$-1]; 
			auto hintOwner = lastHint.owner; 
			
			if(hintState != HintState.idle && hintOwner)
			{
				.Container hintContainer; 
				
				Panel(
					{
						hintContainer = actContainer; 
						padding = "0"; 
						border.color = clGray; 
						
						if(lastHint.markup!="")
						Row(
							{
								 //Todo: row kell?
								padding = "4"; 
								style.fontColor = clHintText; 
								style.bkColor = bkColor = clHintBk; 
								
								Text(lastHint.markup); 
							}
						); 
						
						if(hintState == HintState.details && lastHint.markupDetails!="")
						Row(
							{
								padding = "4"; 
								style.fontColor = clHintDetailsText; 
								style.bkColor = bkColor = clHintDetailsBk; 
								
								Text(lastHint.markupDetails); 
							}
						); 
						
						
					}
				); 
				
				hintContainer.measure; 
				
				//align the hint
				hintContainer.outerPos 	= lastHint.bounds.bottomCenter //Bounds.bottomCenter
					+ vec2(-hintContainer.outerWidth*.5, 5); 
				
				//clamp horizontaly
				hintContainer.outerPos.x = clamp(hintContainer.outerPos.x, 0, max(0, screenBounds.width-hintContainer.outerWidth)); 
				
				//Todo: HintSettings: on/off, hintLocation:nextTo/statusBar/bottomRight, save to ini
			}
			
			hints = []; 
		} 
		
			//! im internal state ////////////////////////////////////////////////////////////////
		
			Cell[] root; //when containerStack is empty, this is the container
		
			auto rootContainers(bool forceAll)
		{
			auto res = root.map!(c => cast(.Container)c)
										 .filter!"a"
										 .array; 
			if(forceAll)
			enforce(root.length == res.length, "FATAL ERROR: All of root[] must be non null and a descendant of Container."); 
			return res; 
		} 
		
			//double QPS=0, lastQPS=0, dt=0;
			//Todo: ez qrvara megteveszto igy, jobb azonositokat kell kitalalni QPS helyett
		
			//Todo: ezt egy alias this-el egyszerusiteni. Jelenleg az im-ben is meg az im.StackEntry-ben is ugyanaz van redundansan deklaralva
			.Container actContainer, lastContainer; //top of the containerStack for faster access
			bool enabled; 
			TextStyle textStyle;   alias style = textStyle; //Todo: style.opDispatch("fontHeight=0.5x")
			string theme; //for now it's a str, later it will be much more complex
			//valid valus: "", "tool"
		
			Id actId()
		{ return actContainer ? actContainer.id : Id.init; } 
		
			auto lastCell(T:Cell=Cell)()
		{
			Cell cell; 
			if(actContainer && actContainer.subCells.length)
			cell = actContainer.subCells[$-1]; 
			return cast(T)cell; 
		} 
		
			private struct StackEntry
		{ .Container container; bool enabled; TextStyle textStyle; string theme; } 
			private StackEntry[] stack; 
		
			//Note: build* functions are only callable from update()
		
			//Build an array of cells using a temporary container
			Cell[] build(string srcModule=__MODULE__, size_t srcLine=__LINE__,A...)(in A args)
		{
			Container!(.Container, srcModule, srcLine)(args); 
			return removeLastContainer.subCells; 
		} 
		
			auto buildContainer(T : .Container, string srcModule=__MODULE__, size_t srcLine=__LINE__, A...)(in A args)
		{
			Container!(T, srcModule, srcLine)(args); 
			return cast(T)removeLastContainer; 
		} 
		
			auto buildRow   (string srcModule=__MODULE__, size_t srcLine=__LINE__, A...)(in A args)
		{ return buildContainer!(.Row   , srcModule, srcLine)(args); } 
			auto buildColumn(string srcModule=__MODULE__, size_t srcLine=__LINE__, A...)(in A args)
		{ return buildContainer!(.Column, srcModule, srcLine)(args); } 
		
			void reset()
		{
			//statck reset
			enabled = true; 
			textStyle = tsNormal; 
			theme = ""; 
			
			root = []; 
			stack = [StackEntry(null, enabled, textStyle, theme)]; 
			actContainer = null; 
			
			overlayDrawings.clear; 
			drawCallbacks.clear; 
		} 
		
			private void push(T : .Container)(T c, in Id newId)
		{
			 //Todo: ezt a newId-t ki kell valahogy valtani. im.id-t kell inkabb modositani.
			c.id = newId; 
			stack ~= StackEntry(c, enabled, textStyle, theme); 
			
			//actContainer is the top of the stack or null
			actContainer = c; 
		} 
		
			private void pop()
		{
			enforce(stack.length>1); //stack[0] is always null and it is never popped.
			
			//restore	the last textStyle & theme. Changes inside a subHierarchy doesn't count.
			enabled	= stack.back.enabled; 
			textStyle	= stack.back.textStyle; 
			theme	= stack.back.theme; 
			
			stack.popBack; 
			
			//save actContainer here.
			lastContainer = actContainer; 
			
			//actContainer is the top of the stack or null
			actContainer = stack.empty ? null : stack.back.container; 
			//Todo: the first stack container is always 0.
		} 
		
			void dump()
		{
			writeln("---- IM dump --------------------------------"); 
			foreach(cell; root)
			cell.dump; 
			writeln("---- End of IM dump -------------------------"); 
		} 
		
			private auto find(C:.Container)()
		{
			foreach_reverse(ref s;stack)
			if(auto r = cast(C)(s.container))
			return r; 
			return null; 
		} 
		
			private void append(Cell c)
		{
			if(actContainer !is null)
			actContainer.appendCell(c); 
			else root ~= c; 
		} 
		
			.Container removeLastContainer()
		{
			//needed for temporary composable building
			return actContainer 	? actContainer.removeLastContainer
				: cast(.Container)root.fetchBack; 
		} 
		
			//overlay drawing //////////////////////////
			private Drawing[.Container] overlayDrawings; 
		
			void addOverlayDrawing(Drawing dr)
		{
			enforce(actContainer !is null); 
			enforce(!actContainer.flags._hasOverlayDrawing, "Container already has an OverlayDrawing."); 
			
			actContainer.flags._hasOverlayDrawing = true; 
			overlayDrawings[actContainer] = dr; 
		} 
		
			private Drawing getOverlayDrawing(.Container cntr)
		{
			if(auto drOverlay = cntr in overlayDrawings)
			return *drOverlay; 
			else return null; 
		} 
		
			//DrawCallback ////////////////////////
			alias DrawCallback = void function(Drawing, .Container); 
		
			private DrawCallback[.Container] drawCallbacks; 
		
			void addDrawCallback(DrawCallback fun)
		{
			enforce(actContainer !is null); 
			enforce(!actContainer.flags._hasDrawCallback, "Container already has a DrawCallback."); 
			
			actContainer.flags._hasDrawCallback = true; 
			drawCallbacks[actContainer] = fun; 
		} 
		
			private auto getDrawCallback(.Container cntr)
		{
			if(auto cb = cntr in drawCallbacks)
			return *cb; 
			else return null; 
		} 
		
			//easy access
		
			@property
		{
			float fh()
			{ return textStyle.fontHeight; } 
			void fh(float v)
			{ textStyle.fontHeight = cast(ubyte)(v.iround); } 
		} 
		
			auto subCells()
		{ return actContainer.subCells; } 
			auto subCells(T : .Cell)()
		{ return actContainer.subCells.map!(c => cast(T)c).filter!(c => c !is null); } 
			auto subContainers()
		{ return actContainer.subContainers; } 
		
			//container delegates
			//void opDispatch(string name, T...)(T args) { mixin("containerStack[$-1]." ~ name)(args); }
		
			auto ContainerProp(string name)
		{
			 //Todo: assignment operation sucks with this: width = height = fh
			return q{
				@property auto #()
				{ return actContainer.#; } 
				@property void #(typeof(actContainer.#) val)
				{ actContainer.# = val; } 
			}.replace("#", name); 
		} 
		
			auto ContainerRef(string name)
		{
			return q{
				ref auto #()
				{ return actContainer.#; } 
			}.replace("#", name); 
		} 
		
			mixin(
			["innerWidth", "outerWidth", "innerHeight", "outerHeight", "innerSize", "outerSize", "innerPos", "outerPos", "pos", "width", "height"].map!ContainerProp.join ~
			["flags", "flex", "margin", "border", "padding", "bkColor"].map!ContainerRef.join
		); 
		
			//Parameter structs ///////////////////////////////////
			//deprecated struct id      { uint val;  /*private*/ enum M = q{ auto id_ = file.xxh(line)^baseId;                          static foreach(a; args) static if(is(Unqual!(typeof(a)) == id      )) id_       = [a.val].xxh(id_); }; }
			immutable prepareId = q{auto id_ = combine(actId, srcId!(srcModule, srcLine)(args)); }; 
		
			struct enable 
		{ bool val; 	 private enum M = q{auto oldEnabled = enabled; scope(exit) enabled = oldEnabled;	  static foreach(a; args) static if(is(Unqual!(typeof(a)) == enable  )) enabled	= enabled && a.val;	}; } 
			struct selected
		{ bool val; 	 private enum M = q{auto _selected = false;	  static foreach(a; args) static if(is(Unqual!(typeof(a)) == selected)) _selected	= a.val;	}; } 
		
			enum RangeType
		{ linear, log, circular, endless} 
			struct range
		{
										//endless can go out of range, circular always using modulo.
			float min, max, step=1; RangeType type;  //Todo: this is an 1D bounds
			
			//Todo: handle invalid intervals
			bool isComplete() const
			{ return !isnan(min) && !isnan(max); } 
			
			bool isLinear	 () const
			{ return type==RangeType.linear	; } 
			bool isLog	 () const
			{ return type==RangeType.log	; } 
			bool isCircular() const
			{ return type==RangeType.circular; } 
			bool isEndless () const
			{ return type==RangeType.endless; } 
			bool isClamped () const
			{ return isLinear || isLog || isCircular; } 
			bool isOrdered () const
			{ return min <= max; } 
			
			float normalize(float x) const
			{
				auto n = isLog ? x.log2.remap(min.log2, max.log2, 0, 1)  //Todo: handle log(0)
											 : x     .remap(min     , max     , 0, 1); 
				if(isCircular)
				if(n<0 || n>1)
				n = n-n.floor; 
				if(isClamped)
				n = n.clamp(0, 1); 
				return n; 
			} 
			
			float denormalize(float n) const
			{
				if(isCircular)
				if(n<0 || n>1)
				n = n-n.floor; 
				if(isClamped)
				n = n.clamp(0, 1); 
				
				return clamp(
					isLog ?  2 ^^	n.remap(0, 1, min.log2, max.log2)
																	 :	n.remap(0, 1, min     , max     )
				); //clamp is needed because of rounding errors
			} 
			
			Unqual!T clamp(T)(T f) const
			{
				if(isComplete)
				{
					static if(isIntegral!T)
					{
						if(isOrdered)
						f = f.clamp(min.ceil.to!T, max.floor.to!T); 
						else f = f.clamp(max.ceil.to!T, min.floor.to!T); 
					}else
					{
						if(isOrdered)
						f = f.clamp(min.to!T, max.to!T); 
						else f = f.clamp(max.to!T, min.to!T); 
					}
				}else
				{
					 //incomplete range: eiter min or max is nan
					static if(isIntegral!T)
					{
						if(!isnan(min) && f<min.iceil)
						f = min.iceil; else if(!isnan(max) && f>max.ifloor)
						f = max.ifloor; 
					}else
					{
						if(!isnan(min) && f<min)
						f = min; else if(!isnan(max) && f>max)
						f = max; 
					}
				}
				return f; 
			} 
			
			private enum M = q{range _range;  static foreach(a; args) static if(is(Unqual!(typeof(a)) == range)) _range = a;}; 
		} 
		
			auto logRange     (float min, float max, float step=1)
		{ return range(min, max, step, RangeType.log     ); } 
			auto circularRange(float min, float max, float step=1)
		{ return range(min, max, step, RangeType.circular); } 
			auto endlessRange (float min, float max, float step=1)
		{ return range(min, max, step, RangeType.endless ); } 
		
			static auto hitTest(.Container container, bool enabled=true)
		{
			assert(container !is null); 
			auto res = hitTestManager.check(container.id); 
			res.enabled = enabled; 
			return res; 
		} 
		
			auto hitTest(bool enabled=true)
		{ return hitTest(actContainer, enabled); } 
		
			string symbol(string def)
		{ return tag(`symbol `~def); } 
			void Symbol(string def)
		{ Text(symbol(def)); } 
			
			void Img(string def)
		{ Img(File(def)); } 
			
			void Img(File f)
		{
			//Text(tag(`img ` ~ f.fullName.optionallyQuotedFileName));
			//Todo: Markup thing is broken with complicated filenames. Quoted filename not works: range error.
			
			bitmaps(f); //need to pull this crap
			append(new .Img(f)); 
		} 
		
			struct ScrollInfo
		{
			 //------------------------------- ScrollInfo //////////////////////////////
			char orientation; 
			
			struct ScrollInfoRec
			{
				Id id; 
				.Container container; //contains id
				uint lastAccess; //to purge the old ones
				
				//current parameters for the scrollbar
				float contentSize=0, pageSize=0; //only valid if container has the has[H/V]ScrollBar flag.
				
				//persistent data
				float offset=0; 
				im.SliderClass slider; 
			} 
			
			protected ScrollInfoRec[Id] infos; 
			
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
					container.id, (ref ScrollInfoRec info){
						info.container	= container; 
						info.id	= container.id; 
						info.contentSize	= contentSize; 
						info.pageSize	= pageSize; 
						info.lastAccess	= application.tick; 
					}
				); 
			} 
			
			//optional
			/*
				void purge(){  createBars has it.
							Id[] toRemove;
							foreach(k, const v; infos) if(v.lastAccess < global_updateTick) toRemove ~= k;
							foreach(k; toRemove) infos.remove(k);
							//opt: assocArray.rehash test
						}
			*/
			
			//Todo: IDE: nicer error display, and autoSolve: "undefined identifier `global_updateTick`, did you mean variable `global_UpdateTick`?"
			
			//2. called after measure when the final local positions are known. It creates the bars if needed and registers them with hitTestManager
			void createBars(bool doPurge)
			{
				assert(orientation.among('H', 'V')); 
				
				Id[] toRemove; 
				foreach(id, ref info; infos)
				{
					if(info.lastAccess<application.tick)
					{
						if(doPurge)
						toRemove ~= id; 
						continue; 
					}
					const exists = (orientation=='H' && info.container.flags.hasHScrollBar)
											|| (orientation=='V' && info.container.flags.hasVScrollBar); 
					if(!exists)
					continue; 
					
					bool enabled; 
					float normValue; 
					float normThumbSize; 
					float activeRange = info.contentSize - info.pageSize; 
					
					const flip = orientation=='V'; 
					void doFlip()
					{
						if(flip)
						normValue = 1-normValue; 
					} 
					
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
					auto actView = targetSurfaces[1].view; //Todo: scrollbars only work on GUI surface. This flag shlould be inherited automatically, just like the upcoming enabled flag.
					auto sl = new SliderClass(
						combine(info.container.id, orientation), enabled, normValue, range(0, 1), userModified, actView.mousePos.vec2, tsNormal, hit,
						orientation=='H' ? SliderOrientation.horz : SliderOrientation.vert, SliderStyle.scrollBar, 1, normThumbSize
					); 
					
					info.slider = sl; 
					
					//set the position of the slider.
					//Todo: Because it's after hitTest, interaction will be delayed for 1 frame. But it should not.
					const scrollThickness = DefaultScrollThickness; //Todo: this is duplicated!!!
					with(info.container)
					if(orientation=='H')
					{
						sl.outerPos = vec2(0, innerHeight-scrollThickness); 
						sl.outerSize = vec2(innerWidth-(flags.hasVScrollBar ? scrollThickness : 0), scrollThickness); 
					}else
					{
						sl.outerPos = vec2(innerWidth-scrollThickness, 0); 
						sl.outerSize = vec2(scrollThickness, innerHeight-(flags.hasHScrollBar ? scrollThickness : 0)); 
					}
					
					
					//Todo: the hitInfo is for the last frame. It should be processed a bit later
					if(userModified && enabled)
					{
						doFlip; 
						info.offset = normValue*activeRange; 
					}
				}
				
				//purge old ones
				foreach(id; toRemove)
				infos.remove(id); 
			} 
			
			
			void dump()
			{
				print("-".replicate(40), orientation.to!string.lc~"ScrollInfo dump"); 
				infos.values.each!print; 
			} 
		} 
		
			auto hScrollInfo = ScrollInfo('H'); 
			auto vScrollInfo = ScrollInfo('V'); 
		
			private void processContainerArgs(Args...)(in Args args)
		{
			static foreach(a; args)
			{
				{
					alias T = typeof(cast()a); 
					static if(isFunctionPointer!a)	a(); 
					else static if(isDelegate!a)	a(); 
					else static if(isSomeString!T)	Text(a); 
					else static if(is(T == YAlign))	flags.yAlign = a; 
					else static if(is(T == HAlign))	flags.hAlign = a; 
					else static if(is(T == VAlign))	flags.vAlign = a; 
					else static if(is(T == TextStyle))	textStyle = a; 
					else static if(is(T == RGB))	style.bkColor = bkColor = a; 
					else static if(is(T == Padding))	padding = a; 
					else static if(is(T == Border))	border = a; 
					else static if(is(T == Margin))	margin = a; 
					else static if(is(T == SyntaxKind))	{ textStyle.applySyntax(a); bkColor = textStyle.bkColor; }
					else static if(isGenericArg!(T, "id"))	{/+ Already processed by prepareId.srcId +/}
					else static if(isGenericArg!(T, "theme"))	theme = a; 
					else static if(isGenericArg!(T, "syntax"))	{ textStyle.applySyntax(a.to!SyntaxKind); bkColor = textStyle.bkColor; }
					else static if(isGenericArg!(T, "fontColor"))	style.fontColor = a; 
					else static if(isGenericArg!(T, "bold"))	style.bolt = a; 
					else static if(isGenericArg!(T, "italic"))	style.italic = a; 
					else static if(isGenericArg!(T, "bkColor"))	style.bkColor = bkColor = a; 
					else static if(isGenericArg!(T, "padding"))	padding = a; 
					else static if(isGenericArg!(T, "border"))	border = a; 
					else static if(isGenericArg!(T, "margin"))	margin = a; 
					else	static assert(false, "Unsupported type: "~T.stringof); 
				}
			}
		} 
		
			void Container(CType = .Container, string srcModule=__MODULE__, size_t srcLine=__LINE__, T...)(in T args)
		{
			  //Container //////////////////////////////
			mixin(prepareId, enable.M); 
			
			static if(__traits(compiles, new CType))
			{ auto cntr = new CType; }else
			{
				alias FirstCtorParam = ParameterTypeTuple!(__traits(getOverloads, CType, "__ctor")[0])[0]; 
				static assert(is(FirstCtorParam : .Container), "If there is no () constructor, the first parameter must be a Container. actContainer will be sent to it as the parent."); 
				auto cntr = new CType(cast(FirstCtorParam)actContainer); //try to give parent for the new control
			}
			
			append(cntr); push(cntr, id_); scope(exit) pop; 
			
			cntr.bkColor = style.bkColor; //Note: inheriting bkcolor in a weird way, from the fontStyle
			
			processContainerArgs(args); 
		} 
		
			void Row   (string	srcModule=__MODULE__, size_t srcLine=__LINE__, T...)(in T args)
		{ Container!(.Row	, srcModule, srcLine)(args); } 
			void Column(string	srcModule=__MODULE__, size_t srcLine=__LINE__, T...)(in T args)
		{ Container!(.Column, srcModule, srcLine)(args); } 
		
			/// It is used to put cached cells or subcells into the imgui.
			void CellRef(Cell cell)
		{
			if(cell)
			Container({ actContainer.append(cell); }); 
		} 
		
			void CellRef(Cell[] cells)
		{
			if(cells.length)
			Container({ actContainer.append(cells); }); 
		} 
		
			//popup state
			struct PopupState
		{
			Cell cell; //the popup itself
			Cell parent; //the initiator of the popup
			
			HAlign hAlign; 
			VAlign vAlign; 
			
			void reset()
			{
				hAlign = HAlign.left; 
				vAlign = VAlign.bottom; 
				cell = null; 
				parent = null; 
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
				
				if(cell)
				{
				if(parent)
				{
					auto bnd = .Container._savedComboBounds; 
					cell.outerPos = vec2(bnd.left+2, bnd.bottom-2); 
				}
				}
			} 
		} 
			PopupState popupState; 
		
			private void Popup(Cell parent, void delegate() contents)
		{
			 //Popup for combobox only ////////////////////////////////////
			//Todo: this check is not working because of the IM gui. When ComboBox1 is pulled down and the user clicks on ComboBox2
			//commented out intentionally: enforce(popupState.cell is null, "im.Popup() already called.");
			
			auto oldLen = actContainer.subCells.length; 
			contents(); 
			auto extraLen = actContainer.subCells.length-oldLen; 
			
			if(extraLen==0)
			return; 
			if(extraLen>1)
			raise("Popup must contain only one Cell"); 
			
			auto popup = actContainer.removeLast; 
			root ~= popup; 
			
			popupState.cell = popup; 
			popupState.parent = parent; 
		} 
		
		
			deprecated void Code_old(string src)
		{
			 //Code /////////////////////////////
			//Todo: syntax highlight
			//Spacer(0.5*fh);
			Column(
				{
					margin = Margin(0.5*fh, 0.5*fh, 0.5*fh, 0.5*fh); 
					
					style = tsCode; 
					const bkColors = [0.06f, 0.09f].map!(t => mix(textStyle.bkColor, textStyle.fontColor, t)).array; 
					border = "1 single gray"; 
					
					foreach(idx, line; src.split('\n'))
					{
						style.bkColor = bkColors[idx&1]; //alternated bkColor
						line = line.withoutEnding('\r'); 
						Text(line); 
					}
					
					//don't hide any spaces
					foreach(r; actContainer.subCells)
					(cast(.Container)r).flags.dontHideSpaces = true; 
				}
			); 
			//Spacer(0.5*fh);
		} 
		
			void Flex(float value = 1)
		{
			 //Flex //////////////////////////////////
			Row({ flex = value; }); 
		} 
		
			string bold	  (string s)	
		{ return tag("style bold=1"	  )~s~tag("style bold=0"	  ); } 
			string italic		(string s)
		{ return tag("style italic=1"	  )~s~tag("style italic=0"	  ); } 
			string underline(string s)
		{ return tag("style underline=1")~s~tag("style underline=0"); } 
			string strikeout(string s)
		{ return tag("style strikeout=1")~s~tag("style strikeout=0"); } 
		
			string progressSpinner(int style=1)
		{
			int t(int n)
			{ return ((QPS.value(second)*n*1.5).ifloor)%n; } 
			auto ch(int i)
			{ return [cast(dchar)i].to!string; } 
			
			switch(style)
			{
				case 0: return ch(0x25f4+3-t(4)); //circle 90deg lines
				case 1: return ch(0x25d0+3-[0, 2, 1, 3][t(4)]); //circle 90deg lines
				case 2: return ch(0x1f550+t(12)); //clock
				default: return "..."; 
			}
		} 
		
			void ProgressSpinner(int progressStyle = 0)
		{
			Row(
				{
					style.fontColor = mix(style.bkColor, style.fontColor, .66f); 
					Text(" "~progressSpinner(progressStyle)~" "); 
				}
			); 
		} 
		
		//Todo: flex N is fucked up. Treats N as 1 always.
		//Todo: flex() function cant work because of flex property.
		//string flex(string markup){ return tag(["flex", markup].join(" ")); }
		//string flex(float value){ return flex(value.text); } //kinda lame to do it with texts
		
			//Text /////////////////////////////////
			void Text(/*string srcModule=__MODULE__, size_t srcLine=__LINE__,*/ T...)(T args)
		{
			//Todo: not multiline yet
			
			//multiline behaviour:
			//parent is Row: if multiline -> make a column around it
			//parent is column: multiline is ok. Multiple row emit
			//actContainer is null: root level gets a lot of rows
			
			//Text is always making one line, even in a container. Use \n for multiple rows
			if(args.length>1 &&(actContainer is null || cast(.Column)actContainer !is null))
			{
				 //implicit row
				Row({ Text/*!(file, line)*/(args); }); 
				return; 
			}
			
			bool restoreTextStyle = false; 
			TextStyle oldTextStyle; 
			static foreach(a; args)
			{
				{
					alias t = Unqual!(typeof(a)); 
					
					static if(is(t == _FlexValue))
					{
						 //nasty workaround for flex() and flex property
						append(new FlexRow("", style)); 
					}else static if(is(t == TextStyle))
					{
						if(chkSet(restoreTextStyle))
						oldTextStyle = textStyle; 
						textStyle = a; 
					}else static if(is(t == RGB))
					{ textStyle.fontColor = a; }else static if(is(t == SyntaxKind))
					{ textStyle.applySyntax(a); }else static if(__traits(compiles, a()))
					{ a(); }else
					{
						   //general case, handles as string
						
						/*
							 mar nem ez tordel, hanem a Row.
											auto lines = a.split('\n').map!(a => a.withoutTrailing('\r')).array;
											if(!lines.empty){
												.Row row = cast(.Row)actContainer;
												if(row){
													row.appendMarkupLine(lines[0], textStyle);
													auto id = file.xxh(line);
													foreach(int idx, line; lines[1..$]){
														pop;
														row = new .Row(line, textStyle);
														append(row);
														push(row, [idx].xxh(id));
													}
												}else{
													foreach(int idx, line; lines){
														append(new .Row(line, textStyle)); //todo: not clear how it works with multiple parameters. All arg strings should be packed in one string and then processed by lines.
													}
												}
											}
						*/
						
						//this variant gives \n to the row
						auto s = a.text; 
						if(.Column col = cast(.Column)actContainer)
						{
							Row({ Text(s); });  //implicit Rows for Column
						}else if(.Row row = cast(.Row)actContainer)
						{ row.appendMarkupLine(s, textStyle); }else
						{ actContainer.appendMarkupLine(s, textStyle); }
					}
				}
			}
			
			if(restoreTextStyle)
			textStyle = oldTextStyle; 
			
			/*
					auto r = cast(.Row)actContainer;
				if(r) r.appendMarkupLine(text, textStyle);
				 else Row({ Text(text); });
			*/
		} 
		
			void Tab()
		{ Text("\t"); } 	void NL()
		{ Text("\n"); } 
		
			void Comment(/*string srcModule=__MODULE__, size_t srcLine=__LINE__, */T...)(T args)
		{
			//It seems a good idea, as once I wanted to type Comment(.. instead of Text(tsComment...
			Text/*!(file, line)*/(tsComment, args); 
		} 
		
			//Bullet ///////////////////////////////////
			void Bullet()
		{
			Row({ outerWidth = fh*2; Flex; Text(tag("char 0x2022")); Flex; }); //Todo: no flex needed, -> center aligned. Constant width is needed however, for different bullet styles.
		} 
		
			void Bullet(void delegate() contents)
		{
			Row(
				{
					Bullet; 
					if(contents)
					contents(); 
				}
			); 
		} 	void Bullet(string text)
		{ Bullet({ Text(text); }); } 
		
			//Spacer //////////////////////////
			private void SpacerRow(Args...)(float size, in Args args)
		{
			const vert = cast(.Row)actContainer !is null; 
			Row(
				args, {
					if(vert)
					{ innerWidth	= size; flags.yAlign = YAlign.stretch; }
					else { innerHeight	= size; /+width is auto by default. A Column will stretch it properly.+/}
				}
			); 
		} 
		
			void Spacer(Args...)(in Args args)
		{
			float size; 
			static if(args.length && isNumeric!(Args[0]))
			{
				size = args[0]; 
				enum argStart = 1; 
			}else
			{ enum argStart = 0; }
			if(isnan(size))
			size = fh*.5f; 
			
			SpacerRow(size, args[argStart..$]); 
		} 
		
			void HR()
		{
			SpacerRow(
				fh*InvDefaultFontHeight, {
					margin = "0.33333x 0"; 
					bkColor = mix(style.bkColor, style.fontColor, 0.25f); 
				}
			); 
		} 
		
			void HLine()
		{ Row({ innerHeight = 1; bkColor = mix(clWinBackground, clWinText, .25f); }); } 
		
			void Grp(alias Cntr=Column, string srcModule=__MODULE__, size_t srcLine=__LINE__, A...)(void delegate() fun, A args)
		{
			 //Grp /////////////////////////////
			Cntr(
				{
					border = "2 normal silver"; padding = "2 4"; margin = "2 4"; 
					fun(); 
				}, args
			); 
		} 
		
			void Grp(alias Cntr=Column, string srcModule=__MODULE__, size_t srcLine=__LINE__, T, A...)(T title, void delegate() fun, A args)
		{
			Container(
				{
					Row({ padding.left+=fh/4; padding.right+=fh/4; }, title); 
					lastContainer.outerPos.x = fh/2; 
					lastContainer.measure; 
					const hh = lastContainer.outerHeight; 
					
					Grp!(Cntr, srcModule, srcLine)(
						{
							margin.top += (hh*(3/8.0f)).iround; 
							padding.top = max(padding.top, hh-margin.top-border.width); 
							fun(); 
						}, args
					); 
				}
			); 
			
			swap(lastContainer.subCells[0], lastContainer.subCells[1]); //nasty trick to measure the caption first
		} 
		
			//apply Btn and Edit style////////////////////////////////////
		
			void applyBtnBorder(in RGB bColor = clWinBtn)
		{
			 //Todo: use it for edit as well
			margin	= Margin(2, 2, 2, 2); 
			border	= Border(2, BorderStyle.normal, bColor); 
			padding	= Padding(2, 2, 2, 2); 
			if(theme == "tool")
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
		
			void applyBtnStyle(bool isWhite, bool enabled, bool focused, bool selected, bool captured, float hover)
		{
			const oldFh = style.fontHeight; 
			style = tsBtn; 
			style.fontHeight = oldFh; 
			
			auto bColor = mix(style.bkColor, clWinBtnHoverBorder, hover); 
			
			applyBtnBorder(bColor); 
			
			flags.selected = selected; 
			//Todo: nem itt van a helye. minden containernek kezelnie kell a selected generic parametert, a focused mar kozpontositva van. Az enabledet is meg kell igy csinalni.
			
			if(!enabled)
			{
				style.fontColor	= clWinBtnDisabledText; 
				style.bkColor 	= mix(style.bkColor, clWinBackground, .66f); 
				border.color	= style.bkColor; 
			}else if(captured)
			{
				border.style	  = BorderStyle.none; 
				style.bkColor	  = clWinBtnPressed; 
			}
			
			if(isWhite)
			{
				if(captured)
				style.bkColor = mix(clWinBackground, clWinBtnPressed, .5f); 
				else style.bkColor = clWinBackground; //Todo: ez felulirja a
			}
			
			if(theme == "tool")
			{
				 //every appearance is lighter on a toolBtn
				style.bkColor   = mix(style.bkColor, tsNormal.bkColor, .5f); 
				if(captured && enabled)
				border.width = 0; //this if() makes the edge squareish
			}
			
			if(selected)
			{
				style.bkColor	= mix(style.bkColor, clAccent, .5f); 
				border.color	= mix(border.color , clAccent, .5f); 
			}
			
			bkColor = style.bkColor; //Todo: update the backgroundColor of the container. Should be automatic, but how?...
			
			//Todo: handle focused
		} 
		
			void applyEditStyle(bool enabled, bool focused, float hover)
		{
				style   = tsNormal; 
			
				auto bColor = focused	? clAccent :
											!enabled	? mix(clWinBtn       , style.bkColor, 0.5f)
			: mix(clWinBtn, clWinBtnHoverBorder, hover); 
			
				applyBtnBorder(bColor); 
			
				if(!enabled)
			{ style.fontColor = mix(style.fontColor, style.bkColor, 0.5f); }
			
				bkColor = style.bkColor; 
		} 
	}
	version(/+$DIDE_REGION+/all)
	{
		
		struct EditResult
		{
			HitInfo hit; 
			bool changed, focused; 
			alias changed this; 
		} 
		
		auto Edit(string srcModule=__MODULE__, size_t srcLine=__LINE__, T0, T...)(ref T0 value, T args)
		{
			NOTIMPL("Doube precision View2D bug: Clicking at any position seeks only to the beginning os text."); 
			
			static if(is(T0==Path))
			return EditPath!(srcModule, srcLine)(value, args); //Todo: not good! There will be 2 returns!!!
			static if(is(T0==File))
			return EditFile!(srcModule, srcLine)(value, args); //Todo: not good! There will be 2 returns!!!
			
			enum IsNum = std.traits.isNumeric!T0; 
			
			mixin(prepareId, enable.M); 
			static if(IsNum)
			mixin(range.M); 
			
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
					auto localMouse = actView.mousePos - hit.hitBounds.topLeft - row.topLeftGapSize; 
					//Todo: this is not when dr and drGUI is used concurrently. currentMouse id for drUI only.
					
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
					
					//Note: This would be the implementation with a struct: static foreach(a; args) static if(is(typeof(a) == ManualFocus)) manualFocus = a.value;
					//The downside is that the struct litters the namespace with simple names.
					//220820: this is too specific. Use the ManualFocus parameter instead. static foreach(a; args) static if(is(typeof(a) == KeyCombo)) if(a.pressed) manualFocus = true;
					
					const focused = focusUpdate(
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
						/*onFocus	*/ { /*_EditHandleInput(value, textEditorState.str, chg);*/},
						/*onExit	*/ {}
					); 
					res.focused = focused; 
					
					//text editor functionality
					if(focused)
					{
						//get the modified string
						//if(strModified) editor2value; //only when changed?
						editor2value; //Todo: when to write back? always / only when change/exit?
						
						textEditorState.row = row; 
						textEditorState.strModified = false; //ready for next modifications
						
						//fetch and queue input
						string unprocessed; 
						import het.win: mainWindow; 
						with(textEditorState)
						with(EditCmd)
						{
							foreach(ch; mainWindow.inputChars.unTag.byDchar)
							{
								 //Todo: preprocess: with(a, b) -> with(a)with(b)
								switch(ch)
								{
									default: 
										if(ch==9 && ch==10)
									{
										if(flags.acceptEditorKeys)
										cmdQueue ~= EditCmd(cInsert, [ch].to!string); 
									}else if(ch>=32)
									{ cmdQueue ~= EditCmd(cInsert, [ch].to!string); }else
									{ unprocessed ~= ch; }
								}	//jajj de korulmenyes ez a switch case fos....
							}
							
							{
								if(KeyCombo("LMB"	).hold)
								cmdQueue ~= EditCmd(cMouse, localMouse	); 
								if(KeyCombo("Backspace"	).typed)
								cmdQueue ~= EditCmd(cDeleteBack	); 
								if(KeyCombo("Del"	).typed)
								cmdQueue ~= EditCmd(cDelete	); 
								if(KeyCombo("Left"	).typed)
								cmdQueue ~= EditCmd(cLeft	); 
								if(KeyCombo("Right"	).typed)
								cmdQueue ~= EditCmd(cRight	); 
								if(KeyCombo("Home"	).typed)
								cmdQueue ~= EditCmd(cHome	); 
								//Todo: When the edit is focused, don't let the view to zoom home. Problem: Editor has a priority here, but the view is checked first.
								if(KeyCombo("End"	).typed)
								cmdQueue ~= EditCmd(cEnd	); 
								if(KeyCombo("Up"	).typed)
								cmdQueue ~= EditCmd(cUp	); 
								if(KeyCombo("Down"	).typed)
								cmdQueue ~= EditCmd(cDown	); 
								
								if(KeyCombo("Ctrl+V Shift+Ins").typed)
								{
									cmdQueue ~= EditCmd(cInsert, clipboard.text); 
									//LDC 1.28: with(het.inputs){ clipboard } <- het.inputs has opDispatch(), anc it tried to search 'clipboard' in that.
								}
							}
							//Todo: A KeyCombo az ambiguous... nem jo, ha control is meg az input beli is ugyanolyan nevu.
							
						}
						
						
						mainWindow.inputChars = unprocessed; 
					}
					
					static if(std.traits.isNumeric!T0)
					flags.hAlign = HAlign.right; 
					else flags.hAlign = HAlign.left; 
					
					applyEditStyle(enabled, focused, hit.hover_smooth); 
					
					if(focused)
					flags.dontHideSpaces = true; 
					
					
					//execute the delegate funct parameters
					static foreach(a; args)
					static if(__traits(compiles, a()))
					{ a(); }
					
					//put the text out
					if(focused)
					{
						if(wasConvertError)
						textStyle.fontColor = clRed; 
						row.appendMarkupLine(textEditorState.str, textStyle, textEditorState.cellStrOfs); 
					}else
					{ row.appendMarkupLine(value.text         , textStyle); }
					
					//get default fontheight for the editor after the (possibly empty) string was displayed
					auto defaultFontHeight = style.fontHeight; 
					
					//set editor's defaultFontHeight for the caret when the string is empty
					if(focused)
					textEditorState.defaultFontHeight = defaultFontHeight; 
					
					//set minimal height for the control
					if(row.subCells.empty)
					{
						if(innerHeight<style.fontHeight)
						innerHeight = style.fontHeight; //Todo: Container.minInnerSize
					}
					
				}
			); 
			
			return res; //a hit testet vissza kene adni im.valtozoban
		} 
		
		auto EditPath(string srcModule=__MODULE__, size_t srcLine=__LINE__, Args...)(ref Path actPath, in Args args)
		{
			 //EditPath ///////////////////////////////////////
			static struct Res
			{
				bool mustRefresh; alias mustRefresh this; 
				bool valid, editing, changed; 
			} 
			Res res; 
			
			Row!(srcModule, srcLine)(
				args, {
					auto editedPath = &ImStorage!Path.access(actContainer.id); 
					
					auto normalize = (in Path p) => p.normalized; 
					auto validate = (in Path p) => p.exists; 
					
					Edit(
						editedPath.fullPath, {
							flex = 1; 
							if(flags.focused)
							{
								res.editing = true; 
								
								auto normalizedValue = normalize(*editedPath); 
								res.valid = validate(normalizedValue); 
								res.changed = actPath != *editedPath; 
								
								void colorize(RGB cl)
								{
									style.bkColor = bkColor = mix(bkColor, cl, 0.25f); 
									border.color = cl; 
								} 
								
								if(!res.valid)
								colorize(clRed); else if(res.changed)
								colorize(clGreen); 
								
								if(inputs.Esc.pressed)
								{ *editedPath = actPath; }
								if(inputs.Enter.pressed && res.valid)
								{
									actPath = normalizedValue; 
									focusedState.reset; 
									res.mustRefresh = true; 
								}
							}else
							{
								*editedPath = actPath; 
								res.valid =  validate(actPath); 
								if(!res.valid)
								style.fontColor = clRed; 
							}
						}
					); 
					
					if(res.editing)
					{
						if(res.changed)
						{
							//Todo: These buttons ain't work with mouse. Only Enter/Esc works.
							if(Btn(symbol("Accept"), enable(res.valid)))
							{ actPath = *editedPath; res.editing = false; res.valid = validate(actPath); res.mustRefresh = true; focusedState.reset; }
							if(Btn(symbol("Cancel")))
							{ *editedPath = actPath; res.editing = false; res.valid = validate(actPath); focusedState.reset; }
						}
					}else
					{
						if(res.valid && Btn(symbol("Refresh")))
						{ res.mustRefresh = true; }
					}
				}
			); 
			
			return res; 
		} 
		
		auto EditFile(string srcModule=__MODULE__, size_t srcLine=__LINE__, Args...)(ref File actFile, in Args args)
		{
			 //EditFile ///////////////////////////////////////
			//Todo: CopyPasta
			static struct Res
			{
				bool mustRefresh; alias mustRefresh this; 
				bool valid, editing, changed; 
			} 
			Res res; 
			
			Row!(srcModule, srcLine)(
				args, {
					auto editedFile = &ImStorage!File.access(actContainer.id); 
					
					auto normalize = (in File p) => p.normalized; 
					auto validate = (in File p) => p.exists; 
					
					Edit(
						editedFile.fullName, {
							flex = 1; 
							if(flags.focused)
							{
								res.editing = true; 
								
								auto normalizedValue = normalize(*editedFile); 
								res.valid = validate(normalizedValue); 
								res.changed = actFile != *editedFile; 
								
								void colorize(RGB cl)
								{
									style.bkColor = bkColor = mix(bkColor, cl, 0.25f); 
									border.color = cl; 
								} 
								
								if(!res.valid)
								colorize(clRed); else if(res.changed)
								colorize(clGreen); 
								
								if(inputs.Esc.pressed)
								{ *editedFile = actFile; }
								if(inputs.Enter.pressed && res.valid)
								{
									actFile = normalizedValue; 
									focusedState.reset; 
									res.mustRefresh = true; 
								}
							}else
							{
								*editedFile = actFile; 
								res.valid =  validate(actFile); 
								if(!res.valid)
								style.fontColor = clRed; 
							}
						}
					); 
					
					if(res.editing)
					{
						if(res.changed)
						{
							if(Btn(symbol("Accept"), enable(res.valid)))
							{ actFile = *editedFile; res.editing = false; res.valid = validate(actFile); res.mustRefresh = true; focusedState.reset; }
							if(Btn(symbol("Cancel")))
							{ *editedFile = actFile; res.editing = false; res.valid = validate(actFile); focusedState.reset; }
						}
					}else
					{
						//Todo: optional refresh button. Disabled for file
						//if(res.valid && Btn(symbol("Refresh"))){ res.mustRefresh = true; }
					}
				}
			); 
			
			return res; 
		} 
		
		
		auto Static(string srcModule=__MODULE__, size_t srcLine=__LINE__, T0, T...)(in T0 value, T args)
		{
			 //Static /////////////////////////////////
			static if(is(T0 : Property))
			{
				auto p = cast(Property)value; 
				Static!(srcModule, srcLine)(p.asText, hint(p.hint),args); 
			}else
			{
				Row(
					{
						mixin(prepareId); 
						actContainer.id = id_; 
						auto hit = hitTest(enabled); 
						
						mixin(hintHandler); 
						applyEditStyle(true, false, 0); //Todo: Enabled in static???
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
		
		auto IncBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__, int sign=1, T0, T...)(ref T0 value, T args) if(sign!=0 && isNumeric!T0)
		{
			 //IncBtn /////////////////////////////////
			mixin(enable.M, range.M); 
			
			auto capt = symbol(`Calculator` ~ (sign>0 ? `Addition` : `Subtract`)); 
			enum isInt = isIntegral!T0; 
			
			auto hit = Btn!(srcModule, srcLine)(capt, args, genericId(sign)); //2 id's can pass because of the static foreach
			bool chg; 
			if(hit.repeated)
			{
				auto oldValue = value,
						 step = abs(_range.step),
						 newValue = _range.clamp(value+step*sign); 
				
				if(isInt)
				value = cast(T0)(round(newValue)); 
				else value = cast(T0)newValue; 
				
				chg = newValue != oldValue; 
			}
			
			return chg; 
		} 
		
		auto DecBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__, T0, T...)(ref T0 value, T args)
		{ return IncBtn!(srcModule, srcLine, -1)(value, args); } 
		
		auto IncDecBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__, T0, T...)(ref T0 value, T args)
		{
			bool res; 
			Row(
				{
					flags.btnRowLines = true; 
					auto r1 = DecBtn!(srcModule, srcLine)(value, args); 
					lastCell.margin.right = 0; 
					auto r2 = IncBtn!(srcModule, srcLine)(value, args); 
					lastCell.margin.left = 0; 
					res = r1 || r2; 
				}
			); 
			return res; 
		} 
		
		auto IncDec(string srcModule=__MODULE__, size_t srcLine=__LINE__, T0, T...)(ref T0 value, T args)
		{
			auto oldValue = value; 
			Edit!(srcModule, srcLine)(value, { width = 2*fh; }, args); //Todo: na itt total nem vilagos, hogy az args hova megy, meg mi a result
			IncDecBtn(value, args); 
			return oldValue != value; 
		} 
		
		auto WhiteBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__, T0, T...)(T0 text, T args)
		{ return Btn!(srcModule, srcLine, true, T0, T)(text, args); } 
		
		auto Btn(string srcModule=__MODULE__, size_t srcLine=__LINE__, bool isWhite=false, T0, T...)(T0 text, T args)  //Btn //////////////////////////////
			if(isSomeString!T0 || __traits(compiles, text()) )
		{
			mixin(prepareId, enable.M, selected.M); 
			
			const isToolBtn = theme=="tool"; 
			
			HitInfo hit; 
			
			Row(
				{
					actContainer.id = id_; 
					hit = hitTest(enabled); 
					mixin(hintHandler); 
					
					bool focused = focusUpdate(
						actContainer, id_,
										enabled, hit.pressed, inputs.Esc.pressed,  //enabled, enter, exit
										/*onEnter	*/ {},
										/*onFocus	*/ {},
										/*onExit	*/ {}
					); 
					
					//flags.wordWrap = false;
					flags.hAlign = HAlign.center; 
					
					applyBtnStyle(isWhite, enabled, focused, _selected, hit.captured, hit.hover_smooth); 
					
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
			if(mainWindow.canProcessUserInput && a.pressed)
			hit.clicked = true; 
			
			return hit; 
		} 
		
		//BtnRow //////////////////////////////////
		auto BtnRow(string srcModule=__MODULE__, size_t srcLine=__LINE__, T...)(void delegate() fun, in T args)
		{
			Row!(srcModule, srcLine)(
				{
					flags.btnRowLines = true; 
					
					fun(); 
					
					foreach(i, c; subCells)
					{
						const first = i==0, last = i+1==subCells.length; 
						
						//stick them together with 0 margin
						if(!first)
						c.margin.left = 0; 
						if(!last)
						c.margin.right= 0; 
					}
				}, args
			); 
		} 
		
		auto BtnRow(string srcModule=__MODULE__, size_t srcLine=__LINE__, T...)(ref int idx, in string[] captions, in T args)
		{
			mixin(enable.M); 
			
			auto last = idx; 
			
			BtnRow!(srcModule, srcLine)(
				{
					foreach(i0, capt; captions)
					{
						const i = cast(int)i0; 
						if(Btn(capt, genericId(i), selected(idx==i)))
						idx = i; 
					}
				}, args
			); 
			
			return last != idx; 
		} 
		
		auto BtnRow(string srcModule=__MODULE__, size_t srcLine=__LINE__, A, Args...)(ref A value, in A[] items, in Args args)
		{
			auto idx = cast(int) items.countUntil(value); //Todo: it's a copy from ListBox. Refactor needed
			auto res = BtnRow!(srcModule, srcLine)(idx, items, args); 
			if(res)
			value = items[idx]; 
			return res; 
		} 
		
		//Todo: (enum, enum[]) is ambiguous!!! only (enum) works on its the full members.
		auto BtnRow(string srcModule=__MODULE__, size_t srcLine=__LINE__, E, Args...)(ref E e, in Args args) if(is(E==enum))
		{
			string s = e.text; 
			auto res = BtnRow!(srcModule, srcLine)(s, EnumMemberNames!E, args); 
			if(res)
			ignoreExceptions({ e = s.to!E; }); 
			return res; 
		} 
		
		
		bool TabsHeader(string srcModule=__MODULE__, size_t srcLine=__LINE__, T, I, A...)(T[] items, ref I idx, A args) //TabsHeader /////////////////////////////
			if(isIntegral!I)
		{
			static customDraw(Drawing dr, .Container cntr)
			{
				bool materialStyle = true; //Todo: theme selection.  tool, white, material... these are conflicting now.
				
				auto btns = cast(.Container[])(cntr.subCells); 
				if(btns.empty)
				return; 
				
				if(!materialStyle)
				{
					dr.lineWidth = 2; 
					bool first = true; 
					vec2 bOfs; 
					foreach(btn; btns)
					{
						const bnd = btn.borderBounds; 
						const sel = btn.flags.selected; 
						
						if(first)
						bOfs = bnd.bottomLeft; 
						
						dr.color = clWinBtn; 
						dr.lineTo(bnd.bottomLeft, first); first = false; 
						if(sel)
						{
							dr.lineTo(bnd.topLeft); 
							dr.lineTo(bnd.topRight); 
						}
						dr.lineTo(bnd.bottomRight); 
					}
					
					dr.lineTo(cntr.innerWidth-bOfs.x, bOfs.y); //extend right
				}else
				{
					dr.lineWidth = 4; 
					dr.color = clWinBtn; 
					const bOfs = btns[0].borderBounds.bottomLeft; 
					dr.hLine(bOfs.x, bOfs.y, cntr.innerWidth-bOfs.x); 
					
					dr.color = clAccent; 
					btns.filter!(b => b.flags.selected).each!(
						(b){
							with(b.borderBounds)
							dr.hLine(left, bottom, right); 
						}
					); 
				}
			} 
			
			bool clicked; 
			Row!(srcModule, srcLine)
			(
				{
					foreach(i; 0..items.length)
					{
						if(
							WhiteBtn(
								items[i], genericId(i), /*selected(i==idx)*/
								{
									//if(border.color==clWinBtn) border.color = bkColor; //todo: this is a nasty workaround. Need a completely white Btn (link) for this.
									bkColor = clWinBackground; 
									border.color = clWinBackground; 
									flags.selected = i==idx;  //Todo: Ez kurvaga'ny! Ez adja at a selectiont a draw callbacknak
									
									padding = "4"; 
								}
							)
						)
						{ idx = i.to!I; clicked = true; }
					}
					
					addDrawCallback(&customDraw); 
					
					
				}, args
			); 
			
			return clicked; 
		} 
		
		void TabsPage(string srcModule=__MODULE__, size_t srcLine=__LINE__, A...)(A args)
		{
			 //TabsPage ////////////////////////////////
			Column!(srcModule, srcLine)(
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
		
		void Tabs(alias mapTitle = "a.title", alias mapUI = "a.UI()", R, I, string srcModule=__MODULE__, size_t srcLine=__LINE__, A...)(R r, ref I idx, A args)
		{
			 //Tabs/////////////////////////////
			mixin(prepareId); 
			
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
			
			/*
				if(includeAll){
							static if(isSomeString!TT) titles ~= "All";
							else static if(isFunction!TT) titles ~= TT({ Text("All"); }, {} ); //inferred type
							else static if(isDelegate!TT) titles ~= TT({ Text("All"); }, {} ); //inferred type
							else static assert(0, "Unhandled type: "~TT.stringof);
						}
			*/
			//Todo: includeAll is broken when title is a callable 
			
			
			TabsHeader!(srcModule, srcLine)(titles, idx); 
			TabsPage!(srcModule, srcLine)(
				{
					if(idx>=0 && idx<len)
					{
						auto r2 = r.drop(idx); 
						if(!r2.empty)
						r2.front.unaryFun!mapUI(); 
					}else
					{
						if(includeAll && idx==len)
						foreach(a; r)
						a.unaryFun!mapUI; 
					}
				}
			); 
		} 
		
		auto Link(string srcModule=__MODULE__, size_t srcLine=__LINE__, T0, T...)(T0 text, T args)  //Link //////////////////////////////
			if(isSomeString!T0 || __traits(compiles, text()) )
		{
			mixin(prepareId, enable.M); 
			
			HitInfo hit; 
			
			Row(
				{
					actContainer.id = id_; 
					hit = hitTest(enabled); 
					
					mixin(hintHandler); 
					
					bool focused = focusUpdate(
						actContainer, id_,
										enabled, hit.pressed, inputs.Esc.pressed,  //enabled, enter, exit
										/*onEnter	*/ {},
										/*onFocus	*/ {},
										/*onExit	*/ {}
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
					
					applyLinkStyle(enabled, focused, hit.captured, hit.hover_smooth); 
					
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
			if(mainWindow && a.pressed)
			hit.clicked = true; 
			
			return hit; 
		} 
		
		auto ToolBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__, T0, T...)(T0 text, T args)
		{
			 //shorthand for tool theme
			auto old = theme; theme = "tool"; scope(exit) theme = old; 
			return Btn!(srcModule, srcLine)(text, args); 
		} 
		
		auto OldListItem(string srcModule=__MODULE__, size_t srcLine=__LINE__, T0, T...)(T0 text, T args)  //OldListItem //////////////////////////////
			if(isSomeString!T0 || __traits(compiles, text()) )
		{
			mixin(prepareId, enable.M, selected.M); 
			
			//Todo: This is only the base of a listitem. Later it must communicate with a container
			
			HitInfo hit; 
			Row(
				{
					actContainer.id = id_; 
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
						style.fontColor = mix(style.fontColor, clGray, 0.5f); //Todo: rather use an 50% overlay for disabled?
					}
					
					if(_selected)
					{
						style.bkColor	= mix(style.bkColor, clAccent, .5f); 
						border.color	= mix(border.color , clAccent, .5f); 
					}
					
					bkColor = style.bkColor; //Todo: update the backgroundColor of the container. Should be automatic, but how?...
					
					static if(isSomeString!T0)
					Text(text); 
					else text(); 
					 //delegate
				}
			); 
			
			return hit; 
		} 
		
		
		//ChkBox //////////////////////////////
		auto ChkBox(string srcModule=__MODULE__, size_t srcLine=__LINE__, string chkBoxStyle="chk", C, T...)(ref bool state, C caption, T args)
		{
			mixin(prepareId, enable.M, selected.M); 
			
			HitInfo hit; 
			Row(
				{
					flags.wordWrap = false; 
					margin.left = margin.right = 2; 
					
					actContainer.id = id_; 
					hit = hitTest(enabled); 
					mixin(hintHandler); 
					
					//update checkbox state
					if(enabled && hit.clicked)
					state.toggle; 
					
					//mixin GetChkBoxColors;
					RGB hoverColor(RGB baseColor, RGB bkColor)
					{
						return !enabled 	? clWinBtnDisabledText
							: mix(baseColor, bkColor, hit.captured ? 0.5f : hit.hover_smooth*0.3f); 
					} 
					
					auto markColor = hoverColor(state ? clAccent : style.fontColor, style.bkColor); 
					auto textColor = hoverColor(style.fontColor, style.bkColor); 
					
					auto bullet = chkBoxStyle=="radio" 	? tag(`symbol RadioBtn`~(state?"On":"Off"))
						: tag(`symbol Checkbox`~(state?"CompositeReversed":"")); 
					
					//Text(format(tag("style fontColor=\"%s\"")~bullet~" "~tag("style fontColor=\"%s\"")~caption, markColor, textColor));
					Text(markColor, bullet~" ", textColor, caption); 
					
					foreach(a; args)
					static if(isDelegate!a || isFunction!a)
					a(); 
				}
			); 
			
			return hit; 
		} 
		
		auto ChkBox(string srcModule=__MODULE__, size_t srcLine=__LINE__, string chkBoxStyle="chk", T...)(Property prop, string caption, T args)
		{
			auto bp = cast(BoolProperty)prop; 
			enforce(bp !is null); 
			auto last = bp.act; 
			auto res = ChkBox!(srcModule, srcLine)(bp.act, caption.empty ? prop.caption : caption, genericId(prop.name), hint(prop.hint), args); 
			bp.uiChanged |= last != bp.act; 
			return res; 
		} 
		
		auto RadioBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__, C, T...)(ref bool state, C caption, T args)
		{ return ChkBox!(srcModule, srcLine, "radio")(state, caption, args); } 
		
		auto Led(string srcModule=__MODULE__, size_t srcLine=__LINE__, T, Ta...)(T param, Ta args)
		{
			mixin(prepareId); 
			auto hit = hitTestManager.check(id_); 
			
			float state = 0; 
			
			static if(is(Unqual!T==bool))
			state = param ? 1 : 0; 
			else static if(isIntegral!T) state = param ? 1 : 0; 
			else static if(isFloatingPoint!T) state = param.clamp(0, 1); 
			else enforce(0, "im.Led() Unhandled param type: " ~ T.stringof); 
			
			auto shp = new .Shape; 
			//set defaults
			shp.innerSize = vec2(0.7, 1)*style.fontHeight; 
			shp.color = clRainbowRed; 
			
			static foreach(a; args)
			{
				{
					 alias t = Unqual!(typeof(a)); 
					static if(is(t==RGB))
					shp.color = a; 
					static if(is(t==vec2))
					shp.innerSize = a; 
				}
			}
			
			shp.color = mix(clBlack, shp.color, state.remap(0, 1, 0.2f, 1)); 
			
			actContainer.append(cast(.Cell)shp); 
			
			/*
				Composite({
							style.fontColor = clLime;
							Text(tag(`symbol StatusCircleInner`));
							style.fontColor = clGray;
							Text(tag(`symbol StatusCircleRing`));
						});
			*/
		} 
		
		auto LedBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__, T, Args...)(void delegate() ledFun, T caption, in Args args)
		{
			return Btn!(srcModule, srcLine)(
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
		
		auto LedBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__, T, Args...)(bool ledState, RGB ledColor, T caption, in Args args)
		{
			return LedBtn!(srcModule, srcLine)(
				{
					if(ledColor!=clBlack)
					{ flags.hAlign = HAlign.left; Led(ledState, ledColor); }
				}, caption, args
			); 
		} 
		
		
		auto ListBoxItem(string srcModule=__MODULE__, size_t srcLine=__LINE__, C, Args...)(ref bool isSelected, C s, in Args args)
		{
			HitInfo hit; 
			Row!(srcModule, srcLine)(
				{
					hit = hitTest(enabled); 
					
					if(!isSelected && hit.hover && (inputs.LMB.down || inputs.RMB.down))
					isSelected = true; //mosue down left or right
					
					padding = "2 2"; 
					bkColor = mix(bkColor, clAccent, max(isSelected ? 0.66f:0, hit.hover_smooth*0.33f)); 
					style.bkColor = bkColor; 
					
					static if(__traits(compiles, s()))
					s(); 
					else Text(s.text); 
				}, args
			); 
			
			return hit; 
		} 
		
		
		struct ListBoxResult
		{
			HitInfo hit; 
			bool changed; 
			alias changed this; 
		} 
		
		auto ListBox(string srcModule=__MODULE__, size_t srcLine=__LINE__, A, Args...)(ref int idx, in A[] items, in Args args)
		{
			 //LixtBox ///////////////////////////////
			mixin(prepareId); //Todo: enabled, tool theme
			
			//find translator function . This translates data to gui.
			enum isTranslator(T) = __traits(compiles, T.init(A.init)); //is(T==void delegate(in A)) || is(T==void delegate(A)) || is(T==void function(in A)) || is(T==void function(A));
			enum translated = anySatisfy!(isTranslator, Args); 
			
			HitInfo hit; 
			bool changed; 
			Column(
				{
					actContainer.id = id_; //Todo: lame way of passing that fucking genericId
					hit = hitTest(enabled); 
					border = "1 normal gray"; 
					
					foreach(i, s; items)
					{
						auto selected = idx==i, oldSelected = selected; 
						
						static if(translated)
						{
							static foreach(f; args)
							static if(isTranslator!(typeof(f)))
							auto hit = ListBoxItem(selected, { f(s); }, genericId(i)); 
							
						}else
						{ auto hit = ListBoxItem(selected, s, genericId(i)); }
						if(!oldSelected && selected)
						{
							idx = cast(int) i; 
							changed = true; 
						}
					}
					
					static foreach(a; args)
					static if(__traits(compiles, a()))
					a(); 
				}/*, args*/
			); //Todo: passing that fucking genericId
			return ListBoxResult(hit, changed); 
		} 
		
		auto ListBox(string srcModule=__MODULE__, size_t srcLine=__LINE__, A, Args...)(ref A value, A[] items, Args args)
		{
			auto idx = cast(int) items.countUntil(value); //Opt: slow search. iterates items twice: 1. in this, 2. in the main ListBox funct
			auto res = ListBox!(srcModule, srcLine)(idx, items, args); 
			if(res)
			value = items[idx]; 
			return res; 
		} 
		
		auto ListBox(string srcModule=__MODULE__, size_t srcLine=__LINE__, E, Args...)(ref E e, Args args) if(is(E==enum))
		{
			auto s = e.text; 
			auto res = ListBox!(srcModule, srcLine)(s, getEnumMembers!E, args); 
			if(res)
			ignoreExceptions({ e = s.to!E; }); 
			return res; 
		} 
		
		//Todo: the parameters of all the ListBox-es, ComboBoxes must be refactored. It's a lot of copy paste and yet it's far from full accessible functionality.
		static void ScrollListBox(T, U, string srcModule=__MODULE__ , size_t srcLine=__LINE__)(ref T focusedItem, U items, void delegate(in T) cellFun, int pageSize, ref int topIndex)
			if(isInputRange!U && is(ElementType!U == T))
		{
			auto scrollMax = max(0, items.walkLength.to!int-pageSize); 
			topIndex = topIndex.clamp(0, scrollMax); 
			auto view = items.drop(topIndex).take(pageSize).array; 
			Row!(srcModule, srcLine)(
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
		
		
		/+
			  auto Btn(string srcModule=__MODULE__, size_t srcLine=__LINE__, bool isWhite=false, T0, T...)(T0 text, T args)  // Btn //////////////////////////////
				if(isSomeString!T0 || __traits(compiles, text()) )
				{
					mixin(id.M ~ enable.M ~ selected.M);
			
					const isToolBtn = theme=="tool";
			
					HitInfo hit;
			
					Row({
						hit = hitTest(id_, enabled_);
			
						mixin(hintHandler);
			
						bool focused = focusUpdate(actContainer, id_,
							enabled, hit.pressed, false,  //enabled, enter, exit
							/* onEnter	*/ { },
							/* onFocus	*/ { },
							/* onExit	*/ { }
						);
			
						//flags.wordWrap = false;
						flags.hAlign = HAlign.center;
			
						applyBtnStyle(isWhite, enabled, focused, _selected, hit.captured, hit.hover_smooth);
			
						static if(isSomeString!T0) Text(text); //centered text
																	else text(); //delegate
			
						static foreach(a; args) static if(__traits(compiles, a())) a();
					});
			
					return hit;
				}         
		+/
		
		
		auto PopupBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__, T0, Args...)(T0 text, Args args) //PopupBtn ////////////////////////////////
			if((isSomeString!T0 || __traits(compiles, text())) && Args.length>=1 && __traits(compiles, args[$-1]()) )
		{
			Cell btn; 
			auto hit = Btn(text, args[0..$-1], { btn = actContainer; }); 
			
			if(isFocused(hit.id))
			(cast(.Container)btn).flags._saveComboBounds = true; //notifies glDraw to place the popup
			
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
		
		
		auto ComboBox_idx(string srcModule=__MODULE__, size_t srcLine=__LINE__, A, Args...)(ref int idx, in A[] items, Args args)
		{
			 //ComboBox ////////////////////////////////
			//Todo: enabled
			
			//find translator function . This translates data to gui.
			enum isTranslator(T) = __traits(compiles, T.init(A.init)); 
			enum translated = anySatisfy!(isTranslator, Args); 
			
			Cell btn; 
			auto hit = WhiteBtn!(srcModule, srcLine)(
				{
					btn = actContainer; 
					flags.hAlign = HAlign.left; 
					
					if(idx.inRange(items))
					{
						static if(translated)
						{
							static foreach(f; args)
							static if(isTranslator!(typeof(f)))
							f(items[idx]); 
							
						}else
						{ Text(items[idx].text); }
					}else
					{
						Text(clGray, "none"); 
						//null value
					}
					
					Flex; 
					Row({ flags.clickable = false; Text(" ", symbol("ChevronDown"), " "); }); 
				}, args
			); 
			
			if(isFocused(hit.id))
			(cast(.Container)btn).flags._saveComboBounds = true; //notifies glDraw to place the popup
			
			if(hit.pressed)
			{
				comboId = hit.id; 
				comboState.toggle; 
				comboOpening = true; //ignore this mousepress when closing popup
			}
			
			ListBoxResult res; 
			
			if(isFocused(hit.id) && comboState)
			{
				Popup(
					btn, {
						
						void inheritComboWidth()
						{
							if(btn.innerWidth>0)
							innerWidth = btn.innerWidth+6; //Todo: tool theme*/
						} 
						
						static if(translated)
						{
							static foreach(f; args)
							static if(isTranslator!(typeof(f)))
							res = ListBox!(srcModule, srcLine)(idx, items, genericId(1), &inheritComboWidth, f); 
							 //Todo: this translator appending is a big mess
						}else
						{ res = ListBox!(srcModule, srcLine)(idx, items, genericId(1), &inheritComboWidth); }
						
						if(res.hit.hover && inputs.LMB.released)
						{
							comboState = false; //close the box
						}
					}
				); 
			}
			
			return res; 
		} 
		
		auto ComboBox_ref(string srcModule=__MODULE__, size_t srcLine=__LINE__, A, Args...)(ref A value, in A[] items, Args args)
		{
			auto idx = cast(int) items.countUntil(value); 
			auto res = ComboBox_idx!(srcModule, srcLine)(idx, items, args); 
			if(res)
			value = items[idx]; 
			return res; 
		} 
		
		auto ComboBox(string srcModule=__MODULE__, size_t srcLine=__LINE__, A, Args...)(ref int idx, in A[] items, Args args)
		{ return ComboBox_idx!(srcModule, srcLine, A, Args)(idx, items, args); } 
		
		auto ComboBox(string srcModule=__MODULE__, size_t srcLine=__LINE__, A, Args...)(ref A value, in A[] items, Args args)
		{ return ComboBox_ref!(srcModule, srcLine, A, Args)(value, items, args); } 
		
		auto ComboBox(string srcModule=__MODULE__, size_t srcLine=__LINE__, E, T...)(ref E e, T args) if(is(E==enum))
		{
			auto s = e.text; 
			auto res = ComboBox!(srcModule, srcLine)(s, getEnumMembers!E, args); 
			if(res)
			ignoreExceptions({ e = s.to!E; }); 
			return res; 
		} 
	}
	version(/+$DIDE_REGION+/all)
	{
			//------------------------------->>>>>>>>>>    Slider ////////////////////////////////////////////////////////////////////////////////////////////////////////////
		
			enum SliderOrientation
		{ horz, vert, round, auto_} 
			private pure bool isLinear(in SliderOrientation o)
		{
			with(SliderOrientation)
			return o==horz || o==vert; 
		} 
			private pure bool isRound (in SliderOrientation o)
		{
			with(SliderOrientation)
			return o==round; 
		} 
		
			enum SliderStyle
		{ slider, scrollBar} 
		
			struct ScrollBarOptions
		{
			float pageSize = 0; //pageSize in win32
			int thickness = 13; 
			int margin = 2; 
			int minThumbSize_pixels = 5; 
		} 
		
			pure static auto getActualSliderOrientation(SliderOrientation orientation, in bounds2 r, SliderStyle style)
		{
			//scrollbar can only be horz or vert.
			if(style==SliderStyle.scrollBar && !isLinear(orientation))
			orientation = SliderOrientation.auto_; 
			
			if(orientation != SliderOrientation.auto_)
			return orientation; 
			
			immutable THRESHOLD = 1.5f; 
			float aspect = safeDiv(r.width/r.height, 1); 
			return aspect>=THRESHOLD	? SliderOrientation.horz:
						 aspect<=(1/THRESHOLD)	? SliderOrientation.vert:
																		 SliderOrientation.round; 
		} 
		
			private struct SliderState
		{
			 //information about the current slider being modified
			
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
					pressed_thumbMouseOfs.x = drawn_p1.x-mousePos.x - (isEndless ? 1 : 0); //otherwise endles range_ gets into an endless incrementing loop
				}else if(drawn_orientation==SliderOrientation.vert)
				{
					pressed_thumbMouseOfs.y = 0; 
					nPos = remap_clamp(mousePos.y, drawn_p0.y, drawn_p1.y, 0, 1); 
					//Note: p1 and p0 are intentionally swapped!!!
					if(mousePos.y<drawn_p1.y)
					pressed_thumbMouseOfs.y = drawn_p1.y-mousePos.y; //Todo: test vertical circular slider jump to the very ends, and see if not jumps to opposite si
					if(mousePos.y>drawn_p0.y)
					pressed_thumbMouseOfs.y = drawn_p0.y-mousePos.y - (isEndless ? 1 : 0); 
				}else
				{ NOTIMPL; }
			} 
			
			void mouseAdjust(ref float nPos, in vec2 mousePos, bool isClamped, bool isCircular, bool isEndless, ref int wrapCnt, float adjustSpeed)
			{
				if(drawn_orientation==SliderOrientation.horz)
				{
					slowMouse(adjustSpeed!=1, adjustSpeed); 
					auto p = mousePos.x+pressed_thumbMouseOfs.x; 
					if(isCircular || isEndless)
					mouseMoveRelX(wrapInRange(p, drawn_p0.x, drawn_p1.x, wrapCnt)); //circular wrap around
					nPos = remap(p, drawn_p0.x, drawn_p1.x, 0, 1); 
					if(isClamped)
					nPos = nPos.clamp(0, 1); 
				}else if(drawn_orientation==SliderOrientation.vert)
				{
					slowMouse(adjustSpeed!=1, adjustSpeed); 
					auto p = mousePos.y+pressed_thumbMouseOfs.y; 
					if(isCircular || isEndless)
					mouseMoveRelY(wrapInRange(p, drawn_p0.y, drawn_p1.y, wrapCnt)); //circular wrap around
					nPos = remap(p, drawn_p0.y, drawn_p1.y, 0, 1); 
					if(isClamped)
					nPos = nPos.clamp(0, 1); 
				}else if(drawn_orientation==SliderOrientation.round)
				{
					auto diff = rawMousePos-pressed_rawMousePos; 
					auto act_dir = abs(diff.x)>abs(diff.y) ? 1 : 2; 
					if(lockedDirection==0 && length(diff)>=3)
					lockedDirection = act_dir; 
					
					const omniDirection = true; //right or up is the positive side
					auto delta = omniDirection 	? inputs.MXraw.delta -inputs.MYraw.delta
						: (lockedDirection ? lockedDirection : act_dir)==1 ? inputs.MXraw.delta : -inputs.MYraw.delta; 
					
					pressed_nPos += delta*(adjustSpeed*(1.0f/180)); //it adds small delta's, so it could be overdriven
					pressed_nPos = pressed_nPos.clamp(0, 1); 
					nPos = pressed_nPos; //Todo: it can't modify npos because npos can be an integer too. In this case, the pressed_nPos name is bad.
					//Todo: endless????
					//Todo: ha tulmegy, akkor vinnie kell magaval a base-t is!!!
					//Todo: Ctrl precizitas megoldasa globalisan az inputs.d-ben.
				}else
				{ raise("Invalid orientation"); }
			} 
			
			void mouseAdjust(ref float nPos, in vec2 mousePos, in range range_, ref int wrapCnt, float adjustSpeed)
			{ mouseAdjust(nPos, mousePos, range_.isClamped, range_.isCircular, range_.isEndless, wrapCnt, adjustSpeed); } 
			
			bool handleKeyboard(ref float nPos, in range range_, float pageSize)
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
					auto nStep()
					{ return range_.step / (range_.max-range_.min); } 
					set(nPos + nStep *scale); 
				} 
				
				const horz = drawn_orientation != SliderOrientation.vert, //round knobs are working for both
							vert = drawn_orientation != SliderOrientation.horz; 
				
				if(horz && inputs.Left.repeated	|| vert && inputs.Down.repeated)
				delta(-1); 
				if(horz && inputs.Right.repeated	|| vert && inputs.Up.repeated)
				delta(1); 
				if(inputs.PgDn.repeated)
				delta(-pageSize); 
				if(inputs.PgUp.repeated)
				delta(pageSize); 
				if(inputs.Home.down)
				set(0); 
				if(inputs.End .down)
				set(1); 
				
				return userModified; 
			} 
			
			bool handleMouse(in Id id, in HitInfo hit, ref float nPos, in vec2 mousePos, in range range_, ref int wrapCnt)
			{
				if(nPos.isnan)
				return false; 
				
				bool userModified; 
				
				if(hit.pressed && enabled)
				{
					//Todo: enabled handling
					userModified = true; 
					
					onPress(id, nPos, mousePos); 
					
					//decide wether the knob has to jump to the mouse position or not
					const doJump = isLinear(drawn_orientation) && !drawn_thumbRect.contains!"[)"(mousePos); 
					if(doJump)
					{ jumpToPoint(nPos, mousePos, range_.isEndless); }
					
					//round knob: lock the mouse and start measuring delta movement
					if(isRound(drawn_orientation))
					{
						 //Todo: "round" knob never jumps
						mouseLock;  //Bug: possible bug when the slider disappears, amd the mouse stays locked forever
					}
				}
				
				//continuous update if active
				if(id==pressed_id)
				{
					userModified = true; 
					const adjustSpeed = inputs.Shift.active ? 0.125f : 1; //Note: this is a scaling factor...
					mouseAdjust(nPos, mousePos, range_, wrapCnt, adjustSpeed); 
				}
				
				//hit.released
				if(hit.released)
				{
					pressed_id = Id.init; 
					
					//Todo: this isn't safe! what if the control disappears!!!
					if(isLinear(drawn_orientation))
					{ slowMouse(false); }else
					{ mouseUnlock; }
				}
				
				return userModified; 
			} 
			
		} 
		
			SliderState sliderState; 
		
			class SliderClass : .Container
		{
			//Note: must be a Container because hitTest works on Containers only.
			
			//Todo: shift precise mode: must use float knob position to improve the precision
			
			SliderOrientation orientation; 
			SliderStyle sliderStyle; 
			RGB bkColor, clLine, clThumb, clRuler; 
			float baseSize; //this is calculated from current fontHeight and theme.
			float normThumbSize; //if it is a scrollbar, this is not nan and specifies the normalized size of the thumb.
			//these are the derived sizes
			float rulerOfs	()
			{ return baseSize*0.5f; } 
			float lwLine	()
			{ return baseSize*(2.0f*InvDefaultFontHeight); } 
			float lwRuler	()
			{ return lwLine*0.5f; } 
			
			/// this is the half thickness of the thumb in the active direction
			float calcLwThumb	(SliderOrientation ori)
			{
				if(sliderStyle ==	SliderStyle.scrollBar && !isnan(normThumbSize))
				{
					const minSizePixels = min(innerWidth, MinScrollThumbSize); 
					return max((ori==SliderOrientation.horz ? innerWidth : innerHeight) * normThumbSize.clamp(0, 1), minSizePixels) * .5f; 
				}else
				{ return baseSize*(1.0f/3); }
			} 
			
			
			int rulerDiv0 = 9, rulerDiv1 = 4; 
			ubyte rulerSides=3; 
			
			float nPos, nCenter=0;  //center is the start of the marking on the line
			int wrapCnt; //for endless, to see if there was a wrapping or not. Used to reconstruct actual value
			
			bounds2 hitBounds; 
			
			bool focused; 
			
			this(
				in Id id, bool enabled, ref float nPos_, in im.range range_, ref bool userModified, vec2 mousePos, 
				TextStyle ts, out HitInfo hit, SliderOrientation orientation, SliderStyle sliderStyle, float fhScale, float normThumbSize=float.init
			)
			{
				this.id = id; 
				this.orientation = orientation; 
				this.sliderStyle = sliderStyle; 
				this.nPos = enabled ? nPos_ : float.init; 
				this.normThumbSize = normThumbSize; 
				
				if(sliderStyle==SliderStyle.scrollBar)
				padding = "2"; 
				
				hit = im.hitTest(this, enabled); 
				hitBounds = hit.hitBounds; 
				
				if(1 || sliderStyle==SliderStyle.slider)
				focused = im.focusUpdate(
					this, id,
					enabled,
					hit.pressed/*|| manualFocus*/, //when to enter
					inputs["Esc"].pressed,  //when to exit
					/*onEnter	*/ {},
					/*onFocus	*/ {},
					/*onExit	*/ {}
				); 
				
				//res.focused = focused;
				
				if(focused)
				userModified |= sliderState.handleKeyboard(nPos, range_, 8); 
				
				bkColor = ts.bkColor; 
				const hoverOrFocus = enabled ? max(hit.hover_smooth*.5f, focused ? 1.0f : 0) : 0; 
				
				final switch(sliderStyle)
				{
					case SliderStyle.slider: 
						clThumb =	mix(mix(clSliderThumb, clSliderThumbHover, hoverOrFocus), clSliderThumbPressed, hit.captured_smooth); 
						clLine =	mix(mix(clSliderLine , clSliderLineHover , hoverOrFocus), clSliderLinePressed , hit.captured_smooth); 
						clRuler =	mix(bkColor, ts.fontColor, 0.5); //disable ruler for now
						rulerSides = 3 *0; 
					break; 
					case SliderStyle.scrollBar: 
						clThumb = mix(clScrollThumb, clScrollThumbPressed, hoverOrFocus); 
						bkColor = mix(clScrollBk, clScrollThumb, min(hoverOrFocus, .5f)); 
					
						//clThumb = mix(clWinBtn, clWinBtnPressed, max(hit.hover_smooth*.5f, sliderState.pressed_id==id ? 1 : 0));
						rulerSides = 0; 
					break; 
				}
				
				if(!enabled)
				clLine = clThumb = clGray; //Todo: nem clGray ez, hanem clDisabledText vagy ilyesmi
				
				baseSize = ts.fontHeight*fhScale*0.8f; 
				outerSize = vec2(baseSize*6, baseSize); //default size
				
				userModified |= sliderState.handleMouse(id, hit, nPos, mousePos, range_, wrapCnt); 
				
				if(userModified)
				nPos_ = nPos; 
			} 
			
			override bounds2 getHitBounds()
			{ return outerBounds; } 
			
			private void drawThumb(Drawing dr, vec2 a, vec2 t, float lwThumb)
			{
				final switch(sliderStyle)
				{
					case SliderStyle.slider: 
						dr.lineWidth = lwThumb; dr.color = clThumb; 
						const t90 = t.rotate90; 
						dr.line(a-t90, a+t90); 
					break; 
					case SliderStyle.scrollBar: 
						dr.color = clThumb; 
						const horz = orientation==SliderOrientation.horz,
									halfSize = horz ? vec2(lwThumb, innerHeight*.5f) : vec2(innerWidth*.5f, lwThumb),
									bnd = bounds2(a, a).inflated(halfSize); 
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
				const actOrientation = getActualSliderOrientation(orientation, b, sliderStyle),
							lwThumb = calcLwThumb(actOrientation); 
				
				if(isLinear(actOrientation))
				{
					const horz = actOrientation == SliderOrientation.horz,
								thumbOfs = (horz ? vec2(1,	0) : vec2(0, -1)) * lwThumb,
								p0 = (horz ? b.leftCenter	: b.bottomCenter) + thumbOfs,
								p1 = (horz ? b.rightCenter	: b.topCenter   ) - thumbOfs; 
					
					if(sliderStyle==SliderStyle.slider && rulerSides)
					{
						const rp0 = horz ? p0 : p1,
									rp1 = horz ? p1 : p0,
									ro0 = horz ? vec2(0, rulerOfs) : vec2(rulerOfs, 0),
									ro1 = ro0*.4f; 
						if(rulerSides&1)
						drawStraightRuler(dr, bounds2(rp0-ro0, rp1-ro1), rulerDiv0, rulerDiv1, true ); 
						if(rulerSides&2)
						drawStraightRuler(dr, bounds2(rp0+ro1, rp1+ro0), rulerDiv0, rulerDiv1, false); 
					}
					
					if(sliderStyle==SliderStyle.slider)
					drawLine(dr, p0, p1, clLine); 
					
					if(!isnan(nPos))
					{
						auto p = mix(p0, p1, nPos); 
						if(!isnan(nCenter) && sliderStyle==SliderStyle.slider)
						drawLine(dr, mix(p0, p1, nCenter), p, clThumb); 
						
						drawThumb(dr, p, thumbOfs, lwThumb); 
						
						if(mod_update)
						{
							vec2 thumbHalfSize; 
							if(sliderStyle==SliderStyle.slider)
							{
								thumbHalfSize = lwThumb * vec2(0.5f, 1.5f); 
								if(!horz)
								swap(thumbHalfSize.x, thumbHalfSize.y); 
							}else
							{ thumbHalfSize = horz ? vec2(lwThumb, outerHeight*.5f) : vec2(outerWidth*.5f, lwThumb); }
							const thumbRect = bounds2(p, p).inflated(thumbHalfSize); 
							sliderState.afterDraw(id, actOrientation, dr.inputTransform(p0), dr.inputTransform(p1), dr.inputTransform(thumbRect)); 
						}
					}
					
				}else if(isRound(actOrientation))
				{
					//center square
					bool endless = false; 
					
					b = b.fittingSquare; 
					if(mod_update)
					sliderState.afterDraw(id, actOrientation, dr.inputTransform(b.center), dr.inputTransform(b.center), dr.inputTransform(b)); 
					
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
			protected void drawStraightRuler(Drawing dr, in bounds2 r, int cnt, int cnt2=-1, bool topleft=true)
			{
				cnt--; 
				if(cnt<=0)
				return; 
				if(cnt2<0)
				cnt2 = cnt; 
				dr.color = clRuler; dr.lineWidth = lwRuler; 
				if(r.height < r.width)
				{
					float c = r.center.y,
								b = r.top,
								t = r.bottom,
								j = r.left,
								ja = r.width/cnt; 
					if(!topleft)
					swap(b, t); 
					foreach(i; 0..cnt+1)
					{
						dr.vLine(j, b, cnt2 && i%cnt2==0 ? t : c); 
						j += ja; 
					}
				}else
				{
					float c = r.center.x,
								b = r.left,
								t = r.right,
								j = r.top,
								ja = r.height/cnt; 
					if(!topleft)
					swap(b, t); 
					foreach(i; 0..cnt+1)
					{
						dr.hLine(b, j, cnt2 && i%cnt2==0 ? t : c); 
						j += ja; 
					}
				}
			} 
			
			protected void drawRoundRuler(Drawing dr, in vec2 center, float radius, int cnt, int cnt2=-1, bool endless=false)
			{
					cnt--; 
					if(cnt<=0)
				return; 
					if(cnt2<0)
				cnt2 = cnt; 
				//radius *= (1/1.25f);
					dr.color = clRuler; dr.lineWidth = lwRuler; 
					foreach(i; 0..cnt+1)
				{
					float a = endless ? 2*PIf*i/cnt
														: -0.25f*PIf + 1.5f*PIf*i/cnt; 
					float co = -cos(a), si = -sin(a); 
					dr.moveTo(center.x+co*radius, center.y+si*radius); 
					float radius2 = radius*(!endless && (cnt2 && i%cnt2==0) ? 1.25f : 1.125f); 
					dr.lineTo(center.x+co*radius2, center.y+si*radius2); 
				}
			} 
		} 
		
		
			auto Slider(string srcModule=__MODULE__, size_t srcLine=__LINE__, V, T...)(ref V value, T args)
			if(isFloatingPoint!V || isIntegral!V)
		{
			mixin(prepareId, enable.M, selected.M, range.M);  //Todo: selected???
			
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
			
			float normValue = _range.normalize(flipped ? _range.max-value : value); //FLIP
			
			int wrapCnt; 
			if(_range.isEndless)
			{
				wrapCnt = normValue.floor.iround;  //Todo: refactor endless wrapCnt stuff
				normValue = normValue-normValue.floor; 
			}
			
			bool userModified; 
			HitInfo hit; 
			auto sl = new SliderClass(
				id_, enabled, normValue, _range, userModified, actView.mousePos.vec2, 
				style, hit, getStaticParamDef(SliderOrientation.auto_, args), 
				getStaticParamDef(SliderStyle.slider, args), theme=="tool" ? 1 : 1.4f
			); 
			
			append(sl); push(sl, id_); scope(exit) pop; 
			
			mixin(hintHandler); 
			static foreach(a; args)
			static if(__traits(compiles, a()))
			a(); 
			
			if(userModified && enabled)
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
			
			//Todo: what to return on from slider
			return userModified; 
		} 
		
			//AdvancedSlider //////////////////////////////
			void AdvancedSlider_impl(T)(T prop, void delegate() fun=null) if(is(T==FloatProperty) || is(T==IntProperty))
		{
			//slider, min/max/act value display, default, edit/inc/dec
			
			const postFix = (" "~prop.unit).stripRight; 
			const caption = prop.name.camelToCaption; 
			
			const variant = 0; 
			
			auto range = im.range(prop.min, prop.max, prop.step); 
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
										actContainer.flags.hAlign = HAlign.right; 
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
										flags.hAlign = HAlign.center; //Todo: not precise center!!!
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
		
			auto Node(string srcModule=__MODULE__, size_t srcLine=__LINE__, Args...)(ref bool state, void delegate() title, void delegate() contents, Args args)
		{
			 //Node ////////////////////////////
			HitInfo hit; 
			Column!(srcModule, srcLine)(
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
		
			auto Node(string srcModule=__MODULE__, size_t srcLine=__LINE__, Args...)(ref bool state, string title, void delegate() contents, Args args)
		{ return Node!(srcModule, srcLine)(state, { Text(title); }, contents, args); } 
		
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
				  //Todo: this could go inside het.ui.im
				if(ext.empty)
				return; 
				
				static Cell[][string] cache;  //Todo: when megatexture is reallocated, the texture id's of icons become invalid.
				
				Cell[] cells; 
				
				cache.update(
					ext, 
					{
						Container(
							{
								Text(tag(format!`img "icon:\%s" height=%f`(ext, iconHeight)));  //Note: this is fucking slow, but works
							}
						); 
						auto cntr = removeLastContainer; 
						cells = cntr.subCells;  //Note: this retirns the last char or a whole error string produced by text markup processor.
						return cells; 
					},
					(ref Cell[] c){ cells = c; }
				); 
				
				CellRef(cells); 
			}
		} 
		
			void FileIcon_small (string ext)
		{ FileIcon_internal!(DefaultFontHeight*1-2)(ext); } 
			void FileIcon_normal(string ext)
		{ FileIcon_internal!(DefaultFontHeight*2-2)(ext); } 
			void FileIcon_large (string ext)
		{ FileIcon_internal!(DefaultFontHeight*4-2)(ext); } 
			alias FileIcon = FileIcon_normal; 
		
		
			//Document ////////////////////////
			void Document(string srcModule=__MODULE__, size_t srcLine=__LINE__)(string title, void delegate() contents = null)
		{
			auto doc = new .Document; 
			doc.title = title; 
			doc.lastChapterLevel = 0; 
			append(doc); push(doc, srcId!(srcModule, srcLine)); scope(exit) pop; 
			
			if(!title.empty)
			{
				Text(doc.getChapterTextStyle, title); 
				Spacer(1.5f*fh); 
			}
			if(contents)
			contents(); 
		} 
		
			void Document(string srcModule=__MODULE__, size_t srcLine=__LINE__)(void delegate() contents = null)
		{ Document!(srcModule, srcLine)("", contents); } 
		
			//Chapter /////////////////////////
			void Chapter(string title, void delegate() contents = null)
		{
			auto doc = find!(.Document); 
			enforce(doc, "Document container not found"); 
			
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
			const
				c2 = style.fontColor,
				f = fh,
				oldBkColor = bkColor; //Todo: it has to be inherited
			
			Container(
				{
					flags.clickable = false; 
					width = f; 
					height = f; 
					bkColor = oldBkColor; 
					//Todo: make mouse clicks fall throug this to the parent container
					
					auto dr = new Drawing; 
					
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
					
					addOverlayDrawing(dr); 
				}
			); 
		} 
		
	}version(/+$DIDE_REGION Flash meggages+/all)
	{
		///Brings up an error message on the center of the screen for a short duration
		struct FlashMessage {
			DateTime when; 
			enum Type { info, warning, error} 
			Type type; 
			string msg; 
			
			RGB color()
			{
				with(Type)
				final switch(type)
				{
					case info: 	return clWhite; 
					case warning: 	return clYellow; 
					case error: 	return clRed; 
				}
				
			} 
		} 
		
		FlashMessage[] flashMessages; 
		
		void flashMessage(FlashMessage.Type type, string msg)
		{
			if(msg=="") return; 
			//Todo: implement flashing error UI
			enum maxLen = 10; 
			if(flashMessages.length>maxLen)
			flashMessages = flashMessages[$-maxLen..$]; 
			flashMessages ~= FlashMessage(now, type, msg); 
			
			with(FlashMessage.Type)
			final switch(type)
			{
				case error: 	winSnd("Windows Critical Stop"); 	break; 
				case warning: 	winSnd("Windows Default"); 	break; 
				case info: 	winSnd("Windows Information Bar"); 	
			}
		} 
		
		void flashInfo(string msg)
		{ flashMessage(FlashMessage.Type.info, msg); } 
		
		void flashWarning(string msg)
		{ flashMessage(FlashMessage.Type.warning, msg); } 
		
		void flashError(string msg)
		{ flashMessage(FlashMessage.Type.error, msg); } 
		
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
					PanelPosition.bottomCenter, 
					{
						bkColor = clWhite; 
						style.bold = true; 
						foreach(m; flashMessages)
						Row(
							{
								style.bkColor = m.color; 
								style.fontColor = blackOrWhiteFor(style.bkColor); 
								
								if(m.type == FlashMessage.Type.error)
								style.fontColor = mix(style.fontColor, style.bkColor, blink^^2); 
								
								padding = "4 24"; 
								flags.hAlign = HAlign.center; 
								const 	tIn = (now-m.when).value(.5f*second),
									tOut = (m.when+flashMessageDuration-now).value(.25f*second); 
								
								fh = DefaultFontHeight*2 	* (tIn<1 ? easeOutElastic(tIn.clamp(0, 1), 0, 1, 1) : 1)
									* (tOut<1 ? easeOutQuad(tOut.clamp(0, 1), 0, 1, 1) : 1); 
								Text(m.msg); 
							}
						); 
					}
				); 
			}
		} 
	}
	
} 