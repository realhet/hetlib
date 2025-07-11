module het.draw2d; 
version(/+$DIDE_REGION+/all)
{
	import het.opengl; 
	
	public import het.algorithm; 
	public import het.opengl : textures; 
	
	import std.bitmanip; 
	
	__gshared bool logDrawing = 0; 
	
	enum InvBoldOffset = 40; //relative to height: texel offset is 1/N
	enum BoldOffset = 1.0f/InvBoldOffset; 
	
	GLTexture debugTexture; 
	
	/+
		Todo: A shader errorokat visszakovetni valahogy: Annyit tudunk rola, hogy a neve az, 
		hogy pl. DrawingShader, ezt a nevet lehetne magabol a shader szovegebol generalni. 
		A GCN compilerbol kell lopkodni, ott mar megy.
	+/
	
	/*
		enum LineStyle { normal, dot, dash, dashDot, dash2, dashDot2 }
		enum ArrowStyle { none, arrow, doubleArrow, normalLeft, normalRight, vector }
		enum PointStyle { dot, square, triangle, cross, plus }
		enum HTextAlign { left, right, center, justify }
		enum VTextAlign { top, bottom, center }
	*/
	
	
	/+
		Note: GPU Data format
		
			0	1	2	3	4	5	6	7	8	9	10	11	12	13	14	15	//4*16 = 64bytes/primitive
			Ax	Ay	Bx	By	Cx	Cy	Col	Typ	Dx	Dy	col2	unused	ClipX0	ClipY0	ClipX1	ClipY1	
		Primitive																	
		Point	X	Y	Siz	Col	Siz			1				...	...	...	...	...	//-Siz = screen_relative
		Point2	X1	Y1	X2	Y2	Siz1	Siz2	Col	2				...	...	...	...	...	//-Siz = screen_relative
		Line	X1	Y1	X1	Y1	Width	L.Style	Col	3..3+63				...	...	...	...	...	//arrowStyle
		Rect	X1	Y1	X2	Y2	Width	L.Style	Col	67				...	...	...	...	...	//Id: symbol id in texture  sc:symScale(1 = (xs, ys))
		Tri	X0	Y0	X1	Y1	X2	Y2	col	68				...	...	...	...	...	
		Glyph	X0	Y0	X1	Y1	TX0	TY0	col	256	TX1	TY1	col2	...	...	...	...	...	//TX0 MSBs: fontFlags
		Bez2	Ax	Ay	Bx	By	Cx	Cy	col	69	Width			...	...	...	...	...	
																			
		Text(new)	X0	X1	SF	STR	STR	STR	col	70?	STR	STR	col2	...	...	...	...	...	 SF=size+flags, STR: 4 chas strings = 20 total chars
		
		/+Note: SubTextIdx is encoded in the MSB of  Typ+/
		
		/+Todo: Shadow/Outline for everything+/
	+/
	
	//Standard LineStyles
	enum LineStyle : ubyte
	{
		normal	= 0,
		dot	= 2,
		dash	= 19,
		dashDot	= 29,
		dash2	= 35,
		dashDot2	= 44
	} //Todo: this is a piece of shit. dot is so long that it is already a fucking dash. And what fucking format is this anyways???
	
	//these are also used in ui.d
	enum HAlign : ubyte
	{left, center, right, justify} 	 //when the container width is fixed
	enum VAlign : ubyte
	{top, center, bottom, justify} 	 //when the container height is fixed
	enum YAlign : ubyte
	{top, center, bottom, baseline, stretch} 	//this aligns the y position of each cell in a line. baseline is 0.7ish
	
	
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
	
	
	/+
		Note: Version 2.0 plans
		
		Goals:
		 - compress more characters into one command.
		 - Optionally enable 64bit positoning.
		 - Support integer and 16 bit formats too.
		 - Support syntax colors
		
		
		
	+/
	
	
	
	//DrawingBuffers //////////////////////////////////////////////////////////////////
	
	//Todo: Appendert kell hasznalni!
	
	//select buffer appenders method here:
	alias DrawingBuffers = DrawingBuffersAppender2; 
	
	
	struct DrawingBuffersOld(T)
	{
		private const bufferMax =	(2<<20)/T.sizeof; 
		private T[][] buffers; 	//Todo: immutable
		
		void initialize()
		{} 
		size_t objCount()
		const { return buffers.map!"a.length".sum; } 
		bool empty()
		const { return buffers.empty; } 
		void clear()
		{ buffers.clear; } 
		auto allObjs()
		{ return buffers.join; } 
		auto toVBOs()
		{ return buffers.map!(b => new VBO(b)).array; } 
		
		void put(ref T obj)
		{
			if(buffers.empty || buffers[$-1].length>=bufferMax) {
				T[] act; 
				act.reserve(bufferMax); 
				buffers ~= act; 
			}
			buffers[$-1] ~= obj; 
		} 
	} 
	
	struct DrawingBuffersSimple(T)
	{
		private const bufferMax = (2<<20)/T.sizeof; 
		private T[] buffer; 
		
		void initialize()
		{ buffer.reserve(bufferMax); } 
		size_t objCount() const
		{ return buffer.length; } 
		bool empty() const
		{ return buffer.empty; } 
		void clear()
		{ buffer.clear; } 
		auto allObjs()
		{ return buffer; } 
		auto toVBOs()
		{ return [new VBO(buffer)]; } 
		void put(ref T obj)
		{ buffer ~= obj; } 
	} struct DrawingBuffersAppender1(T)
	{
		private T[] buffer; 
		RefAppender!(T[]) app; 
		
		void initialize()
		{ app = appender(&buffer); } 
		size_t objCount() const
		{ return app[].length; } 
		bool empty() const
		{ return app[].empty; } 
		void clear()
		{ app.clear; } 
		auto allObjs()
		{ return app[]; } 
		auto toVBOs()
		{ return [new VBO(app[])]; } 
		void put(ref T obj)
		{ app.put(obj); } 
	} 
	
	struct DrawingBuffersAppender2(T)
	{
		Appender!(T[]) app;   //Note: const(T)[] is not good because that can't be cleared.
		
		void initialize()
		{} //Note: No need to initialize an empty Appender. It's already initialized.
		size_t objCount() const
		{ return app[].length; } 
		bool empty() const
		{ return app[].empty; } 
		void clear()
		{ app.clear; } /+
			Todo: This keeps the buffer capacity in memory. 
				For 24/7 operation, in every minute is 
				should be shrinked to the half if possible.
		+/
		auto allObjs()
		{ return app[]; } 
		auto toVBOs()
		{ return [new VBO(app[])]; } 
		void put(in T obj)
		{ app.put(obj); } 
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
	
	////////////////////////////////////////////////////////////////////////////////
	//Logger                                                                    //
	////////////////////////////////////////////////////////////////////////////////
	
	deprecated class Logger
	{
		Drawing dr; //graphic log
		bool wr;     //writeln log
		
		this(bool dump=false, Drawing dr=null)
		{ this.dr = dr; wr = dump; } 
		this(Drawing dr, bool dump=false)
		{ this.dr = dr; wr = dump; } 
		
		void opCall(string s)
		{ log(s); } 
		
		enum LogType { Text, Dump, Code} 
		
		void log(string s, LogType type = LogType.Text)
		{
			//multiline?
			if(s.canFind('\n')) {
				s.split("\n").map!stripRight.each!(a => log(a, type)); 
				return; 
			}
			
			if(dr) {
				auto oldc = dr.color; 	dr.color = clSilver; 
				auto oldfh = dr.fontHeight; 	dr.fontHeight = 1; 
				auto oldFontMonoSpace = dr.fontMonoSpace; 	dr.fontMonoSpace = type!=LogType.Text; 
				
				dr.textOut(0, 0, s); 
				dr.origin = dr.origin+vec2(0, 1); 
				
				dr.color = oldc; 
				dr.fontHeight = oldfh; 
				dr.fontMonoSpace = oldFontMonoSpace; 
			}
			if(wr) writeln(s); 
		} 
		
		void dump(string s)
		{ log(s, LogType.Dump); } 
		
		void code(string s)
		{ log(s, LogType.Code); } 
		
		void tableRow(R)(R row)
		if(isInputRange!R)
		{
			string s; 
			if(dr) {
				static if(__traits(compiles, row.front.toDrawing(dr)))
				{
					for(auto r2 = row; !r2.empty;)
					{
						 const cell = r2.front; r2.popFront; 
						auto oldy = dr.origin.y; 
						cell.toDrawing(dr); 
						if(r2.empty) dr.origin.x = 0; 
						else
						dr.origin.y = oldy; 
						 //preserve line
					}
				}
				else {
					auto oldWr = wr; 
					wr = false; 
					scope(exit) wr = oldWr; 
					dump(row.map!text.join(" ")); 
				}
			}
			if(wr) writeln(row.map!text.join(" ")); 
		} 
		
		void table(R)(R tbl)
		if(isInputRange!R)
		{ foreach(const row; tbl) tableRow(row[]); } 
		
		void table(R)(string capt, R tbl)
		if(isInputRange!R)
		{
			title(capt); 
			table(tbl); 
		} 
		
		void title(string s)
		{
			if(dr) {
				auto oldc = dr.color; 	      dr.color = clWhite; 
				auto oldfh = dr.fontHeight; 	      dr.fontHeight = 3; 
				
				dr.textOut(0, 2, s); 
				dr.origin = dr.origin+vec2(0, 6); 
				
				dr.color = oldc; 
				dr.fontHeight = oldfh; 
			}
			if(wr) writefln("\n\33\17%s\n\33\7", s); 
		} 
		
		
	} 
	
	void drawVasarellyEffect(Drawing dr)
	{
		const N=1000, step = N/100; 
		if(0)
		iota(0, N+1, step)	.map!(a => pow(float(a)/N, 1+sin(blinkf(.25)*PIf*2))*N)
			.each!((i){
			dr.color = mix(clYellow, clAqua, float(i)/N); 
			dr.line(i,	0,	0,	N-i	); 
			dr.line(i,	0,	0,	-(N-i)	); 
			dr.line(-i,	0,	0,	N-i	); 
			dr.line(-i,	0,	0,	-(N-i)	); 
		}); 
		
	} 
	
	
	enum DrawTextOption
	{ monoSpace, italic, vertFlip} 
	
	struct plotFont
	{
		static: 
			enum fontHeight 	= 25.0f,
		fontMonoWidth 	= 20.0f, //height = 40
		fontYAdjust 	= 4.0f; 
		
			float textWidth (float scale, bool monoSpace, string text)
		{
			if(monoSpace) return text.length*fontMonoWidth                              *scale; 
			else return text.map!(ch => charMap[(cast(int)ch).clamp(0,255)].gfx.width).sum    *scale; 
		} 
		
			float textHeight(float scale, string text)
		{ return fontHeight*scale; } 
			vec2 textExtent  (float scale, bool monoSpace, string text)
		{ return vec2(textWidth(scale, monoSpace, text), textHeight(scale, text)); } 
		
			void drawText(Drawing dr, vec2 pos, float scale, bool monoSpace, bool italic, string text, bool vertFlip)
		{
			pos.y += scale*fontYAdjust; 
			foreach(ch; text) {
				auto cg = charMap[cast(int)ch].gfx; 
				
				foreach(const poly; cg.points)
				foreach(i, const p; poly)
				{
					vec2 v = vec2(p.x, p.y); 
					if(!vertFlip) v.y = fontHeight-v.y; 
					if(monoSpace) v.x += (fontMonoWidth-cg.width)*0.5; 
					if(italic) v.x += 4 - v.y*0.25; 
					dr.lineTo(pos+v*scale, !!i); 
				}
				
				pos.x += (monoSpace ? fontMonoWidth : cg.width)*scale; 
			}
		} 
		
			auto drawTextStrokes(vec2 pos, string text, float scale=1, DrawTextOption[] options=[])
		{
			vec2[][] res;    //Todo: refactor this funct
			pos.y += scale*fontYAdjust; 
			
			const monoSpace	= options.canFind(DrawTextOption.monoSpace); 
			const italic	= options.canFind(DrawTextOption.italic	); 
			const vertFlip	= options.canFind(DrawTextOption.vertFlip	); 
			
			foreach(ch; text) {
				auto cg = charMap[cast(int)ch].gfx; 
				
				foreach(const poly; cg.points)
				foreach(i, const p; poly)
				{
					auto v = vec2(p.x, p.y); 
					if(!vertFlip) v.y = fontHeight-v.y; 
					if(monoSpace) v.x += (fontMonoWidth-cg.width)*0.5; 
					if(italic) v.x += 4 - v.y*0.25; 
					
					//exporting it
					if(i==0) res ~= [[]]; 
					res[$-1] ~= pos+v*scale; 
				}
				
				pos.x += (monoSpace ? fontMonoWidth : cg.width)*scale; 
			}
			return res; 
		} 
		
			private const(CharRec)*[256] charMap; 
			static this()
		{
			 //static init
			foreach(ref cr; chars)
			charMap[cast(int)cr.ch] = &cr; 
			
			//set default char for undefinied ones
			foreach(ref m; charMap) if(!m) m = charMap[cast(int)'?']; 
		} 
		
			struct CharPoint { int x, y; } 
			struct CharGfx { float width; CharPoint[][] points; } 
			struct CharRec { char ch; CharGfx gfx; } 
			//data source: https://hackage.haskell.org/package/plotfont
			//Todo: Editor: linkek highlightolasa es raugras.
			
			const CharRec[] chars =
		[
			{' ',{16,[]}}
			 ,{'!',{10,[[{ 5,2},{ 4,1},{ 5,0},{ 6,1},{ 5,2}],[{ 5,7},{ 5,21}]]}}
			 ,{
				'"',{
					16,[
						[{ 4,15},{ 5,16},{ 6,18},{ 6,20},{ 5,21},{ 4,20},{ 5,19}],
						[{ 10,15},{ 11,16},{ 12,18},{ 12,20},{ 11,21},{ 10,20},{ 11,19}]
					]
				}
			}
			 ,{'\'',{10,[[{ 4,15},{ 5,16},{ 6,18},{ 6,20},{ 5,21},{ 4,20},{ 5,19}]]}}
			 ,{
				'#',{
					21,[
						[{ 10,-7},{ 17,25}],[{ 11,25},{ 4,-7}],[{ 3,6},{ 17,6}],
						[{ 18,12},{ 4,12}]
					]
				}
			}
			 ,{
				'$',{
					20,[
						[
							{ 3,3},{ 5,1},{ 8,0},{ 12,0},{ 15,1},{ 17,3},{ 17,6}
							,{ 16,8},{ 15,9},{ 13,10},{ 7,12},{ 5,13},{ 4,14},{ 3,16}
							,{ 3,18},{ 5,20},{ 8,21},{ 12,21},{ 15,20},{ 17,18}
						],
						[{ 12,25},{ 12,-4}],[{ 8,-4},{ 8,25}]
					]
				}
			}
			 ,{
				'%',{
					24,[
						[
							{ 8,21},{ 10,19},{ 10,17},{ 9,15},{ 7,14},{ 5,14},
							{ 3,16},{ 3,18},{ 4,20},{ 6,21},{ 8,21},{ 10,20},
							{ 13,19},{ 16,19},{ 19,20},{ 21,21},{ 3,0}
						],
						[
							{ 17,7},{ 15,6},{ 14,4},{ 14,2},{ 16,0},{ 18,0},
							{ 20,1},{ 21,3},{ 21,5},{ 19,7},{ 17,7}
						]
					]
				}
			}
			 ,{
				'&',{
					26,[
						[
							{ 23,2},{ 23,1},{ 22,0},{ 20,0},{ 18,1},{ 16,3},
							{ 11,10},{ 9,13},{ 8,16},{ 8,18},{ 9,20},{ 11,21},
							{ 13,20},{ 14,18},{ 14,16},{ 13,14},{ 12,13},{ 5,9},
							{ 4,8},{ 3,6},{ 3,4},{ 4,2},{ 5,1},{ 7,0},{ 11,0},
							{ 13,1},{ 15,3},{ 17,6},{ 19,11},{ 20,13},{ 21,14},
							{ 22,14},{ 23,13},{ 23,12}
						]
					]
				}
			}
			 ,{
				'(',{
					14,[
						[
							{ 11,-7},{ 9,-5},{ 7,-2},{ 5,2},{ 4,7},{ 4,11},
							{ 5,16},{ 7,20},{ 9,23},{ 11,25}
						]
					]
				}
			}
			 ,{
				')',{
					14,[
						[
							{ 3,-7},{ 5,-5},{ 7,-2},{ 9,2},{ 10,7},{ 10,11},
							{ 9,16},{ 7,20},{ 5,23},{ 3,25}
						]
					]
				}
			}
			 ,{'*',{16,[[{ 3,12},{ 13,18}],[{ 8,21},{ 8,9}],[{ 13,12},{ 3,18}]]}}
			 ,{'+',{26,[[{ 4,9},{ 22,9}],[{ 13,0},{ 13,18}]]}}
			 ,{',',{10,[[{ 4,-4},{ 5,-3},{ 6,-1},{ 6,1},{ 5,2},{ 4,1},{ 5,0},{ 6,1}]]}}
			 ,{'-',{26,[[{ 4,9},{ 22,9}]]}}
			 ,{'.',{10,[[{ 5,2},{ 4,1},{ 5,0},{ 6,1},{ 5,2}]]}}
			 ,{'/',{22,[[{ 2,-7},{ 20,25}]]}}
			 ,{
				'0',{
					20,[
						[
							{ 9,21},{ 6,20},{ 4,17},{ 3,12},{ 3,9},{ 4,4},{ 6,1}
							,{ 9,0},{ 11,0},{ 14,1},{ 16,4},{ 17,9},{ 17,12}
							,{ 16,17},{ 14,20},{ 11,21},{ 9,21}
						]
					]
				}
			}
			 ,{'1',{20,[[{ 6,17},{ 8,18},{ 11,21},{ 11,0}]]}}
			 ,{
				'2',{
					20,[
						[
							{ 4,16},{ 4,17},{ 5,19},{ 6,20},{ 8,21},{ 12,21}
							,{ 14,20},{ 15,19},{ 16,17},{ 16,15},{ 15,13}
							,{ 13,10},{ 3,0},{ 17,0}
						]
					]
				}
			}
			 ,{
				'3',{
					20,[
						[
							{ 3,4},{ 4,2},{ 5,1},{ 8,0},{ 11,0},{ 14,1}
							,{ 16,3},{ 17,6},{ 17,8},{ 16,11},{ 15,12},{ 13,13}
							,{ 10,13},{ 16,21},{ 5,21}
						]
					]
				}
			}
			 ,{'4',{20,[[{ 13,0},{ 13,21},{ 3,7},{ 18,7}]]}}
			 ,{
				'5',{
					20,[
						[
							{ 3,4},{ 4,2},{ 5,1},{ 8,0},{ 11,0},{ 14,1}
							,{ 16,3},{ 17,6},{ 17,8},{ 16,11},{ 14,13},{ 11,14}
							,{ 8,14},{ 5,13},{ 4,12},{ 5,21},{ 15,21}
						]
					]
				}
			}
			 ,{
				'6',{
					20,[
						[
							{ 4,7},{ 5,10},{ 7,12},{ 10,13},{ 11,13},{ 14,12}
							,{ 16,10},{ 17,7},{ 17,6},{ 16,3},{ 14,1},{ 11,0}
							,{ 10,0},{ 7,1},{ 5,3},{ 4,7},{ 4,12},{ 5,17}
							,{ 7,20},{ 10,21},{ 12,21},{ 15,20},{ 16,18}
						]
					]
				}
			}
			 ,{'7',{20,[[{ 3,21},{ 17,21},{ 7,0}]]}}
			 ,{
				'8',{
					20,[
						[
							{ 8,21},{ 5,20},{ 4,18},{ 4,16},{ 5,14},{ 7,13}
							,{ 11,12},{ 14,11},{ 16,9},{ 17,7},{ 17,4},{ 16,2}
							,{ 15,1},{ 12,0},{ 8,0},{ 5,1},{ 4,2},{ 3,4}
							,{ 3,7},{ 4,9},{ 6,11},{ 9,12},{ 13,13},{ 15,14}
							,{ 16,16},{ 16,18},{ 15,20},{ 12,21},{ 8,21}
						]
					]
				}
			}
			 ,{
				'9',{
					20,[
						[
							{ 4,3},{ 5,1},{ 8,0},{ 10,0},{ 13,1},{ 15,4}
							,{ 16,9},{ 16,14},{ 15,18},{ 13,20},{ 10,21}
							,{ 9,21},{ 6,20},{ 4,18},{ 3,15},{ 3,14},{ 4,11}
							,{ 6,9},{ 9,8},{ 10,8},{ 13,9},{ 15,11},{ 16,14}
						]
					]
				}
			}
			 ,{
				':',{
					10,[
						[{ 5,2},{ 4,1},{ 5,0},{ 6,1},{ 5,2}],
						[{ 5,14},{ 4,13},{ 5,12},{ 6,13},{ 5,14}]
					]
				}
			}
			 ,{
				';',{
					10,[
						[{ 4,-4},{ 5,-3},{ 6,-1},{ 6,1},{ 5,2},{ 4,1},{ 5,0},{ 6,1}],
						[{ 5,14},{ 4,13},{ 5,12},{ 6,13},{ 5,14}]
					]
				}
			}
			 ,{'<',{24,[[{ 20,0},{ 4,9},{ 20,18}]]}}
			 ,{'=',{26,[[{ 4,6},{ 22,6}],[{ 22,12},{ 4,12}]]}}
			 ,{'>',{24,[[{ 4,0},{ 20,9},{ 4,18}]]}}
			 ,{
				'?',{
					18,[
						[
							{ 3,16},{ 3,17},{ 4,19},{ 5,20},{ 7,21},{ 11,21},{ 13,20},
							{ 14,19},{ 15,17},{ 15,15},{ 14,13},{ 13,12},{ 9,10},
							{ 9,7}
						]
						,[{ 9,2},{ 8,1},{ 9,0},{ 10,1},{ 9,2}]
					]
				}
			}
			 ,{
				'@',{
					27,[
						[{ 11,5},{ 10,6},{ 9,8},{ 9,11},{ 10,14},{ 12,16}]
						,[
							{ 18,13},{ 17,15},{ 15,16},{ 12,16},{ 10,15},{ 9,14}
							,{ 8,11},{ 8,8},{ 9,6},{ 11,5},{ 14,5},{ 16,6},{ 17,8}
						],
						[{ 19,5},{ 18,6},{ 18,8},{ 19,16}]
						,[
							{ 18,16},{ 17,8},{ 17,6},{ 19,5},{ 21,5},{ 23,7}
							,{ 24,10},{ 24,12},{ 23,15},{ 22,17},{ 20,19}
							,{ 18,20},{ 15,21},{ 12,21},{ 9,20},{ 7,19}
							,{ 5,17},{ 4,15},{ 3,12},{ 3,9},{ 4,6},{ 5,4}
							,{ 7,2},{ 9,1},{ 12,0},{ 15,0},{ 18,1},{ 20,2},{ 21,3}
						]
					]
				}
			}
			 ,{'A',{18,[[{ 1,0},{ 9,21},{ 17,0}],[{ 14,7},{ 4,7}]]}}
			 ,{
				'B',{
					21,[
						[
							{ 4,11},{ 13,11},{ 16,10},{ 17,9},{ 18,7},{ 18,4}
							,{ 17,2},{ 16,1},{ 13,0},{ 4,0},{ 4,21},{ 13,21}
							,{ 16,20},{ 17,19},{ 18,17},{ 18,15},{ 17,13}
							,{ 16,12},{ 13,11}
						]
					]
				}
			}
			 ,{
				'C',{
					21,[
						[
							{ 18,5},{ 17,3},{ 15,1},{ 13,0},{ 9,0},{ 7,1},{ 5,3},
							{ 4,5},{ 3,8},{ 3,13},{ 4,16},{ 5,18},{ 7,20},{ 9,21},
							{ 13,21},{ 15,20},{ 17,18},{ 18,16}
						]
					]
				}
			}
			 ,{
				'D',{
					21,[
						[
							{ 4,0},{ 4,21},{ 11,21},{ 14,20},{ 16,18},{ 17,16}
							,{ 18,13},{ 18,8},{ 17,5},{ 16,3},{ 14,1},{ 11,0},{ 4,0}
						]
					]
				}
			}
			 ,{'E',{19,[[{ 4,11},{ 12,11}],[{ 17,21},{ 4,21},{ 4,0},{ 17,0}]]}}
			 ,{'F',{18,[[{ 12,11},{ 4,11}],[{ 4,0},{ 4,21},{ 17,21}]]}}
			 ,{
				'G',{
					21,[
						[
							{ 13,8},{ 18,8},{ 18,5},{ 17,3},{ 15,1},{ 13,0}
							,{ 9,0},{ 7,1},{ 5,3},{ 4,5},{ 3,8},{ 3,13}
							,{ 4,16},{ 5,18},{ 7,20},{ 9,21},{ 13,21},{ 15,20}
							,{ 17,18},{ 18,16}
						]
					]
				}
			}
			 ,{'H',{22,[[{ 4,0},{ 4,21}],[{ 4,11},{ 18,11}],[{ 18,21},{ 18,0}]]}}
			 ,{'I',{8,[[{ 4,0},{ 4,21}]]}}
			 ,{
				'J',{
					16,[
						[
							{ 2,7},{ 2,5},{ 3,2},{ 4,1},{ 6,0},{ 8,0},{ 10,1}
							,{ 11,2},{ 12,5},{ 12,21}
						]
					]
				}
			}
			 ,{'K',{21,[[{ 18,0},{ 9,12}],[{ 4,21},{ 4,0}],[{ 4,7},{ 18,21}]]}}
			 ,{'L',{17,[[{ 4,21},{ 4,0},{ 16,0}]]}}
			 ,{'M',{24,[[{ 4,0},{ 4,21},{ 12,0},{ 20,21},{ 20,0}]]}}
			 ,{'N',{22,[[{ 4,0},{ 4,21},{ 18,0},{ 18,21}]]}}
			 ,{
				'O',{
					22,[
						[
							{ 9,21},{ 7,20},{ 5,18},{ 4,16},{ 3,13},{ 3,8}
							,{ 4,5},{ 5,3},{ 7,1},{ 9,0},{ 13,0},{ 15,1}
							,{ 17,3},{ 18,5},{ 19,8},{ 19,13},{ 18,16},{ 17,18}
							,{ 15,20},{ 13,21},{ 9,21}
						]
					]
				}
			}
			 ,{
				'P',{
					21,[
						[
							{ 4,0},{ 4,21},{ 13,21},{ 16,20},{ 17,19},{ 18,17}
							,{ 18,14},{ 17,12},{ 16,11},{ 13,10},{ 4,10}
						]
					]
				}
			}
			 ,{
				'Q',{
					22,[
						[
							{ 9,21},{ 7,20},{ 5,18},{ 4,16},{ 3,13},{ 3,8}
							,{ 4,5},{ 5,3},{ 7,1},{ 9,0},{ 13,0},{ 15,1}
							,{ 17,3},{ 18,5},{ 19,8},{ 19,13},{ 18,16},{ 17,18}
							,{ 15,20},{ 13,21},{ 9,21}
						],
						[{ 12,4},{ 18,-2}]
					]
				}
			}
			 ,{
				'R',{
					21,[
						[
							{ 4,0},{ 4,21},{ 13,21},{ 16,20},{ 17,19},{ 18,17}
							,{ 18,15},{ 17,13},{ 16,12},{ 13,11},{ 4,11}
						]
						,[{ 11,11},{ 18,0}]
					]
				}
			}
			 ,{
				'S',{
					20,[
						[
							{ 3,3},{ 5,1},{ 8,0},{ 12,0},{ 15,1},{ 17,3}
							,{ 17,6},{ 16,8},{ 15,9},{ 13,10},{ 7,12},{ 5,13}
							,{ 4,14},{ 3,16},{ 3,18},{ 5,20},{ 8,21},{ 12,21}
							,{ 15,20},{ 17,18}
						]
					]
				}
			}
			 ,{'T',{16,[[{ 1,21},{ 15,21}],[{ 8,21},{ 8,0}]]}}
			 ,{
				'U',{
					22,[
						[
							{ 4,21},{ 4,6},{ 5,3},{ 7,1},{ 10,0},{ 12,0}
							,{ 15,1},{ 17,3},{ 18,6},{ 18,21}
						]
					]
				}
			}
			 ,{'V',{18,[[{ 1,21},{ 9,0},{ 17,21}]]}}
			 ,{'W',{24,[[{ 2,21},{ 7,0},{ 12,21},{ 17,0},{ 22,21}]]}}
			 ,{'X',{20,[[{ 3,0},{ 17,21}],[{ 3,21},{ 17,0}]]}}
			 ,{'Y',{18,[[{ 1,21},{ 9,11},{ 9,0}],[{ 9,11},{ 17,21}]]}}
			 ,{'Z',{20,[[{ 3,21},{ 17,21},{ 3,0},{ 17,0}]]}}
			 ,{'[',{14,[[{ 5,-7},{ 5,25}],[{ 11,25},{ 4,25},{ 4,-7},{ 11,-7}]]}}
			 ,{'\\',{22,[[{ 20,-7},{ 2,25}]]}}
			 ,{']',{14,[[{ 3,-7},{ 10,-7},{ 10,25},{ 3,25}],[{ 9,25},{ 9,-7}]]}}
			 ,{'^',{16,[[{ 2,12},{ 8,18},{ 14,12}],[{ 11,15},{ 8,19},{ 5,15}]]}}
			 ,{'_',{16,[[{ 0,-2},{ 16,-2}]]}}
			 ,{'`',{10,[[{ 5,17},{ 6,16},{ 5,15},{ 4,16},{ 4,18},{ 5,20},{ 6,21}]]}}
			 ,{
				'a',{
					19,[
						[{ 15,0},{ 15,14}],[
							{ 15,11},{ 13,13},{ 11,14},{ 8,14}
							,{ 6,13},{ 4,11},{ 3,8},{ 3,6},{ 4,3}
							,{ 6,1},{ 8,0},{ 11,0},{ 13,1},{ 15,3}
						]
					]
				}
			}
			 ,{
				'b',{
					19,[
						[
							{ 4,11},{ 6,13},{ 8,14},{ 11,14},{ 13,13},{ 15,11}
							,{ 16,8},{ 16,6},{ 15,3},{ 13,1},{ 11,0},{ 8,0}
							,{ 6,1},{ 4,3}
						],
						[{ 4,0},{ 4,21}]
					]
				}
			}
			 ,{
				'c',{
					18,[
						[
							{ 15,3},{ 13,1},{ 11,0},{ 8,0},{ 6,1},{ 4,3},{ 3,6}
							,{ 3,8},{ 4,11},{ 6,13},{ 8,14},{ 11,14},{ 13,13},{ 15,11}
						]
					]
				}
			}
			 ,{
				'd',{
					19,[
						[
							{ 15,11},{ 13,13},{ 11,14},{ 8,14},{ 6,13},{ 4,11}
							,{ 3,8},{ 3,6},{ 4,3},{ 6,1},{ 8,0},{ 11,0},{ 13,1}
							,{ 15,3}
						],
						[{ 15,0},{ 15,21}]
					]
				}
			}
			 ,{
				'e',{
					18,[
						[
							{ 3,8},{ 15,8},{ 15,10},{ 14,12},{ 13,13},{ 11,14}
							,{ 8,14},{ 6,13},{ 4,11},{ 3,8},{ 3,6},{ 4,3},{ 6,1}
							,{ 8,0},{ 11,0},{ 13,1},{ 15,3}
						]
					]
				}
			}
			 ,{
				'f',{
					12,[
						[{ 2,14},{ 9,14}],[
							{ 10,21},{ 8,21},{ 6,20},{ 5,17}
							,{ 5,0}
						]
					]
				}
			}
			 ,{
				'g',{
					19,[
						[
							{ 6,-6},{ 8,-7},{ 11,-7},{ 13,-6},{ 14,-5},{ 15,-2}
							,{ 15,14}
						],
						[
							{ 15,11},{ 13,13},{ 11,14},{ 8,14},{ 6,13}
							,{ 4,11},{ 3,8},{ 3,6},{ 4,3},{ 6,1},{ 8,0}
							,{ 11,0},{ 13,1},{ 15,3}
						]
					]
				}
			}
			 ,{
				'h',{
					19,[
						[{ 4,21},{ 4,0}],[
							{ 4,10},{ 7,13},{ 9,14},{ 12,14}
							,{ 14,13},{ 15,10},{ 15,0}
						]
					]
				}
			}
			 ,{'i',{8,[[{ 3,21},{ 4,20},{ 5,21},{ 4,22},{ 3,21}],[{ 4,14},{ 4,0}]]}}
			 ,{
				'j',{
					10,[
						[{ 1,-7},{ 3,-7},{ 5,-6},{ 6,-3},{ 6,14}]
						,[{ 5,21},{ 6,20},{ 7,21},{ 6,22},{ 5,21}]
					]
				}
			}
			 ,{'k',{17,[[{ 4,21},{ 4,0}],[{ 4,4},{ 14,14}],[{ 8,8},{ 15,0}]]}}
			 ,{'l',{8,[[{ 4,0},{ 4,21}]]}}
			 ,{
				'm',{
					30,[
						[{ 4,0},{ 4,14}],[
							{ 4,10},{ 7,13},{ 9,14},{ 12,14}
							,{ 14,13},{ 15,10},{ 15,0}
						]
						,[
							{ 15,10},{ 18,13},{ 20,14},{ 23,14},{ 25,13}
							,{ 26,10},{ 26,0}
						]
					]
				}
			}
			 ,{
				'n',{
					19,[
						[{ 4,0},{ 4,14}],[
							{ 4,10},{ 7,13},{ 9,14}
							,{ 12,14},{ 14,13},{ 15,10},{ 15,0}
						]
					]
				}
			}
			 ,{
				'o',{
					19,[
						[
							{ 8,14},{ 6,13},{ 4,11},{ 3,8},{ 3,6}
							,{ 4,3},{ 6,1},{ 8,0},{ 11,0},{ 13,1},{ 15,3}
							,{ 16,6},{ 16,8},{ 15,11},{ 13,13},{ 11,14},{ 8,14}
						]
					]
				}
			}
			 ,{
				'p',{
					19,[
						[{ 4,-7},{ 4,14}],[
							{ 4,11},{ 6,13},{ 8,14},
							{ 11,14},{ 13,13},{ 15,11},
							{ 16,8},{ 16,6},{ 15,3},{ 13,1},
							{ 11,0},{ 8,0},{ 6,1},{ 4,3}
						]
					]
				}
			}
			 ,{
				'q',{
					19,[
						[{ 15,-7},{ 15,14}],[
							{ 15,11},{ 13,13},{ 11,14},
							{ 8,14},{ 6,13},{ 4,11},{ 3,8},
							{ 3,6},{ 4,3},{ 6,1},{ 8,0},
							{ 11,0},{ 13,1},{ 15,3}
						]
					]
				}
			}
			 ,{
				'r',{
					13,[
						[{ 4,0},{ 4,14}]
						,[{ 4,8},{ 5,11},{ 7,13},{ 9,14},{ 12,14}]
					]
				}
			}
			 ,{
				's',{
					17,[
						[
							{ 3,3},{ 4,1},{ 7,0},{ 10,0},{ 13,1}
							,{ 14,3},{ 14,4},{ 13,6},{ 11,7},{ 6,8},{ 4,9}
							,{ 3,11},{ 4,13},{ 7,14},{ 10,14},{ 13,13}
							,{ 14,11}
						]
					]
				}
			}
			 ,{
				't',{
					12,[
						[{ 9,14},{ 2,14}],[
							{ 5,21},{ 5,4},{ 6,1}
							,{ 8,0},{ 10,0}
						]
					]
				}
			}
			 ,{
				'u',{
					19,[
						[
							{ 4,14},{ 4,4},{ 5,1}
							,{ 7,0},{ 10,0},{ 12,1},{ 15,4}
						],[{ 15,0},{ 15,14}]
					]
				}
			}
			 ,{'v',{16,[[{ 2,14},{ 8,0},{ 14,14}]]}}
			 ,{'w',{22,[[{ 3,14},{ 7,0},{ 11,14},{ 15,0},{ 19,14}]]}}
			 ,{'x',{17,[[{ 3,0},{ 14,14}],[{ 3,14},{ 14,0}]]}}
			 ,{
				'y',{
					16,[
						[{ 2,14},{ 8,0}],[
							{ 1,-7},{ 2,-7},{ 4,-6}
							,{ 6,-4},{ 8,0},{ 14,14}
						]
					]
				}
			}
			 ,{'z',{17,[[{ 3,14},{ 14,14},{ 3,0},{ 14,0}]]}}
			 ,{
				'{',{
					14,[
						[
							{ 7,-6},{ 6,-4},{ 6,-2},{ 7,0},{ 8,1}
							,{ 9,3},{ 9,5},{ 8,7},{ 4,9},{ 8,11}
							,{ 9,13},{ 9,15},{ 8,17},{ 7,18},{ 6,20}
							,{ 6,22},{ 7,24}
						]
						,[
							{ 9,25},{ 7,24},{ 6,23},{ 5,21},{ 5,19},{ 6,17}
							,{ 7,16},{ 8,14},{ 8,12},{ 6,10}
						]
						,[
							{ 6,8},{ 8,6},{ 8,4},{ 7,2},{ 6,1},{ 5,-1}
							,{ 5,-3},{ 6,-5},{ 7,-6},{ 9,-7}
						]
					]
				}
			}
			 ,{'|',{8,[[{ 4,-7},{ 4,25}]]}}
			 ,{
				'}',{
					14,[
						[
							{ 5,-7},{ 7,-6},{ 8,-5},{ 9,-3},{ 9,-1}
							,{ 8,1},{ 7,2},{ 6,4},{ 6,6},{ 8,8}
						]
						,[
							{ 8,10},{ 6,12},{ 6,14},{ 7,16},{ 8,17}
							,{ 9,19},{ 9,21},{ 8,23},{ 7,24},{ 5,25}
						]
						,[
							{ 7,24},{ 8,22},{ 8,20},{ 7,18},{ 6,17}
							,{ 5,15},{ 5,13},{ 6,11},{ 10,9},{ 6,7}
							,{ 5,5},{ 5,3},{ 6,1},{ 7,0},{ 8,-2}
							,{ 8,-4},{ 7,-6}
						]
					]
				}
			}
			 ,{
				'~',{
					24,[
						[
							{ 3,6},{ 3,8},{ 4,11},{ 6,12},{ 8,12}
							,{ 10,11},{ 14,8},{ 16,7},{ 18,7},{ 20,8}
							,{ 21,10}
						]
						,[
							{ 21,12},{ 21,10},{ 20,7},{ 18,6},{ 16,6}
							,{ 14,7},{ 10,10},{ 8,11},{ 6,11},{ 4,10},{ 3,8}
						]
					]
				}
			}
		]; 
	} 
	static void drawProbes(Drawing dr, PROBE.Event[][string] events)
	{
		if(events.empty) return; 
		
		const t0 = events.values.map!(a => a[0].when).minElement; 
		
		string[] keys = events.keys.sort.array; 
		foreach(y, key; keys)
		{
			float y0 = y; 
			auto 	arr	= events[key],
				values 	= arr.map!"a.value"; 
			const 	max 	= values.maxElement(0),
				min	= values.minElement(0); 
			
			dr.color = clWhite; 
			dr.fontHeight = 1; 
			dr.textOut(-5, y0, key); 
			
			vec2 p(in PROBE.Event a) { return vec2((a.when-t0).value(second/60), y0+0.9f-a.value*0.8f); } 
			
			vec2 lastP = p(PROBE.Event(0)); lastP.x = 0; 
			
			dr.lineWidth = -1; 
			dr.pointSize = -4; 
			dr.moveTo(lastP); 
			foreach(a; arr)
			{
				auto c = clRainbow[a.coreIdx % clRainbow.length]; 
				
				auto nextP = p(a); 
				dr.color = c; 
				dr.fillRect(lastP.x, lastP.y, nextP.x, y0+0.9f); 
				dr.color = c.lighten(0.5f); 
				dr.lineTo(nextP.x, lastP.y); 
				dr.lineTo(nextP); 
				//dr.point(nextP);
				lastP = nextP; 
			}
		}
	} 
}
version(/+$DIDE_REGION View2D+/all)
{
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
		Window owner_; 
		
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
		
		float animSpeed = 0.3; //0=off, 0.3=normal, 0.9=slow
		
		//extra information from external source in screen space. All is in world coords
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
		
		public: 
		@property auto owner()
		{
			enforce(owner_ !is null, "Forgot to set View2D.owner"); 
			return owner_; 
		} 
		@property void owner(Window w)
		{ owner_ = w; } 
		
		@property bool isMouseInside() const
		{ return mousePos in subScreenBounds_anim; } 
		
		this()
		{} 
		
		this(T)(in T origin, float scale)
		{
			this.origin = V(origin); 
			this.scale = scale; 
		} 
		
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
		
		
		vec2 clientSize()
		{ return vec2(owner.clientSize); } 
		vec2 clientSizeHalf()
		{ return clientSize/2; } 
		//floor because otherwise it would make aliasing in the center of the view
		
		bounds2 visibleArea(bool animated = true)
		{
			V	mi = invTrans(V(0), animated),
				ma = invTrans(clientSize, animated); 
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
		T trans(T)(in T world, bool animated=true)
		{ return ((world-getOrigin(animated))*getScale(animated)+clientSizeHalf); } 
		//Opt: fucking slow, need to be cached
		
		T invTrans(T)(in T client, bool animated=true)
		{ return T((client-clientSizeHalf)/getScale(animated) + getOrigin(animated)); } 
		
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
		{ zoomAround(trans(mousePos), amount); } 
		
		///Automatically call zoomAll() when workArea changes
		bool autoZoom()
		{
			if(workArea.area>0 && chkSet(lastWorkArea, workArea)) {
				zoomAll; 
				return true; 
			}
			return false; 
		} 
		
		//navigate 2D view with the keyboard and the mouse
		//it optionally calls invalidate
		bool navigate(bool keyboardEnabled, bool mouseEnabled)
		{
			auto oldOrigin = origin; 
			auto oldScale = scale; 
			
			with(owner.actions)
			{
				const 	scrollSpeed	= owner.deltaTime.value(second)*800*4,
					zoomSpeed	= owner.deltaTime.value(second)*6,
					wheelSpeed	= 0.375f; 
				
				group("View controls"); ////todo: ctrl+s es s (mint move osszeakad!)
				
				const enm = mouseEnabled; 
				/+
					Todo: actions are deprecated. This view.navigate function 
					should be replaced with az IMGUI enable flag and a hidden window.
				+/
				
				onActive	(
					"Scroll", "MMB RMB", enm,
					{ scroll(inputs.mouseDelta); }
				); 
				onDelta	(
					"Zoom", "MW", enm ,
					(x){ zoomAroundMouse(x*wheelSpeed); }
				); 
				
				const enk = keyboardEnabled; 
				onActive(
					"Scroll left", "A", enk,
					{ scrollH(scrollSpeed); }
				); 
				onActive	(
					"Scroll right", "D", enk,
					{ scrollH(-scrollSpeed); }
				); 
				onActive(
					"Scroll up", "W", enk,
					{ scrollV(scrollSpeed); }
				); 
				onActive(
					"Scroll down", "S", enk,
					{ scrollV(-scrollSpeed); }
				); 
				
				onActive	(
					"Zoom in", "PgUp", enk ,
					{ zoom(zoomSpeed); }
				); 
				onActive	(
					"Zoom out", "PgDn", enk ,
					{ zoom(-zoomSpeed); }
				); 
				onModifier(
					"Scroll/Zoom slower", "Shift", enk || enm,
					scrollSlower
				); 
				onPressed (
					"Zoom all", "Home", enk ,
					{ zoomAll; }
				); 
			}
			
			bool res = origin!=oldOrigin || scale!=oldScale; 
			if(res) owner.invalidate; 
			return res; 
		} 
		
		bool updateAnimation(float deltaTime, bool callInvalidate)
		{
			  //Todo: use quantities.time
			float at = calcAnimationT(deltaTime, animSpeed); 
			if(chkSet(animStarted)) at = 1; 
			
			bool res; 
			res |= follow(m_origin_anim, origin, at, invScale*1e-2f); 
			res |= follow(m_logScale_anim, logScale, at, 1e-2f); 
			
			if(res && callInvalidate) owner.invalidate; 
			return res; 
		} 
		
		//skips the animated moves to their destination immediately
		void skipAnimation() { updateAnimation(9999, false); } 
		
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
}
class Drawing
{
	version(/+$DIDE_REGION+/all)
	{
		auto shortName() const
		{ return "Drawing("~(cast(void*)this).text~")"; } 
		
		private VBO[] vboList; 
		private void destroyVboList()
		{
			foreach(ref v; vboList) destroy(v); 
			vboList.clear; 
			totalDrawObj = 0; 
		} 
		
		uint 	drawCnt, //GLWindow will use it for automatic display
			totalDrawObj /+total DrawingObjects on GPU+/; 
		const bool isClone; 
		
		string name; 
		
		this()
		{
			isClone = false; 
			buffers.initialize; 
		} this(string name)
		{
			this.name = name; 
			this(); 
		} 
		
		this(Drawing src)
		{
			//make a clone
			if(src.isClone) CRIT("It is invalid to clone a clone"); 
			if(logDrawing) LOG(shortName, "cloning", cast(void*) src); 
			isClone = true; 
			actState = src.actState; 
			clipBounds = src.clipBounds; 
		} 
		
		Drawing clone()
		{ return new Drawing(this); } 
		
		private Drawing[] subDrawings; //clones to draw at the very end
		
		void subDraw(Drawing src)
		{
			//Todo: revisit this subdrawing thing
			if(!src.isClone) CRIT("src must be a clone (at least for now.)"); 
			
			//Note: potential problem, the subDrawing has no location. It is useless for dynamic changes.
			
			if(logDrawing) LOG(shortName, "queued subDrawing", cast(void*) src, src.totalDrawObj); 
			subDrawings ~= src; 
			
			bounds_ |= src.bounds_; 
		} 
		
		void copyFrom(Drawing src)
		{
			/// Appends the contents of another drawing into itself. Used in UI to draw overlays on top of cells.
			if(src is null) return; 
			
			foreach(o; src.exportDrawingObjs) {
				o.applyTransform(&inputTransform); 
				oldAppend(o); //Todo: this is a terrible slow copy
			}
		} 
		
		~this()
		{
			//destroyVboList; //not needed: gc will release it anyways
		} 
		
		string stats()
		{
			return format!"(total:%d pending:%d vbo:[%s])"
			(totalDrawObj, buffers.objCount, vboList.map!(a => a.handle).array.text); 
		} 
		
		////////////////////////////////////////////////////////////////////////////////
		//State variables                                                           //
		////////////////////////////////////////////////////////////////////////////////
		
		struct DrawState
		{
			//saveable area
			RGB drawColor = clWhite; //RGB fillColor = clBlack;
			ubyte alpha = 0xFF; 
			LineStyle lineStyle; 
			ArrowStyle arrowStyle; 
			ushort fontFlags;  //customShaderIdx can be bigger than a ubyte.
			//end	of saveable area
			
			float	pointSize = -1,
				lineWidth = -1; 
			//auto	arrowSize = vec2(8, 2.5);   //this is fixed in the shader
			
			float fontHeight = 18; 
			float fontWeight = 1.0; 
			static foreach(
				i, s; [
					/+1+/"MonoSpace",
					/+2+/"Italic",
					/+4+/"Underline",
					/+8+/"StrikeOut",
					/+16+/"Image",
					/+from here: customshader if image, or for font-> +/
					/+32+/"Transparent"
				]
			)
			{
				mixin(
					"@property bool font*() const { return (fontFlags>>#)&1; }
@property void font*(bool b){ fontFlags = cast(ushort) (fontFlags & ~(1<<#) | (cast(int)b << #)); }"
					.replace('*', s).replace('#', i.text)
				); 
			}
			
			private enum fontWeightBold =	1.4f; 
			@property bool fontBold()
			{ return fontWeight> (fontWeightBold+1)*.5f; } 
			@property void fontBold(bool b)
			{ fontWeight = b ? fontWeightBold : 1; } 
			
			auto drawScale = vec2(1, 1); 
			auto drawOrigin = vec2(0, 0); 
			
			
			/// used in advanced drawing functions such as line2()
			long quickSave()
			{
				static assert(drawColor.offsetof + 8 == fontFlags.offsetof + fontFlags.sizeof); 
				return *(cast(long*) &this); 
			} 
			
			/// ditto
			void quickRestore(long data)
			{ *(cast(long*) &this) = data; } 
		} 
		
		private DrawState actState; 
		private DrawState[] stateStack; 
		
		//Todo: Examine push VS saveState, seems redundant. UI uses only translate() and pop()
		private vec2[2][] stack; //matrix stack
		
		
		@property float alpha()
		{ return actState.alpha*(1.0f/255); } 
		@property void alpha(float a)
		{ actState.alpha = cast(ubyte) iround(a.clamp(0, 1)*255); } 
		
		@property RGB color()
		{ return actState.drawColor; } 
		@property void color(RGB c)
		{ actState.drawColor = c; } 
		
		//@property RGB fillColor()	     { return actState.fillColor; }
		//@property void fillColor(RGB c)	     { actState.fillColor = c; }
		
		ref float pointSize()
		{ return actState.pointSize; } 
		ref float lineWidth()
		{ return actState.lineWidth; } 
		ref lineStyle()
		{ return actState.lineStyle; } 
		
		ref arrowStyle()
		{ return actState.arrowStyle; } 
		
		ref scaleFactor()
		{ return actState.drawScale; } 
		ref origin()
		{ return actState.drawOrigin; } 
		
		ref fontHeight()
		{ return actState.fontHeight					; } 
		ref fontWeight()
		{ return actState.fontWeight					; } 
		@property bool	fontMonoSpace() const
		{ return actState.fontMonoSpace	; } 
		@property bool	fontItalic()const
		{ return actState.fontItalic	; } 
		@property bool	fontUnderline() const
		{ return actState.fontUnderline			; } 
		@property bool	fontStrikeOut() const
		{ return actState.fontStrikeOut			; } 
		@property fontMonoSpace(bool b)
		{ return actState.fontMonoSpace	= b		; } 
		@property fontItalic(bool b)
		{ return actState.fontItalic	= b	; } 
		@property fontUnderline(bool b)
		{ return actState.fontUnderline	= b			; } 
		@property fontStrikeOut(bool b)
		{ return actState.fontStrikeOut	= b			; } 
		
		@property bool fontBold()
		{ return actState.fontBold; } 
		@property fontBold(bool b)
		{ actState.fontBold = b; } 
		
		//save/restore DrawState
		void saveState()
		{ stateStack ~= actState; } 
		void restoreState()
		{
			enforce(stateStack.length, "Canvas.restoreState(): State stack is empty"); 
			actState = stateStack.back; 
			stateStack.popBack; 
		} 
		alias pushState = saveState; 
		alias popState = restoreState; 
		
		//access combined colors
		private uint realDrawColor()
		{ return actState.drawColor.raw | actState.alpha<<24; } 
		//private uint realFillColor()	{ return actState.fillColor.raw | actState.alpha<<24; }
		
		void push()
		{
			enforce(
				stack.length<1024, 
				"Drawing.glDraw() matrix stack is too big.  It has %d items.".format(stack.length)
			); 
			stack ~= [origin, scaleFactor]; 
		} 
		
		auto pop(int count=1)
		{
			foreach(i; 0..count) {
				enforce(!stack.empty, "Drawing.pop() stack is empty"); 
				auto a = stack.fetchBack; 
				origin = a[0]; 
				scaleFactor = a[1]; 
			}
			return this; //fluid interface
		} 
		
		auto translate(float	dx, float dy)
		{
			push; 	//seems like origin is in scale units, not in screen units.
			origin.x = origin.x + dx; //*scaleFactor.x;
			origin.y = origin.y + dy; //*scaleFactor.y;
			return this; //fluid interface
		} 
		auto translate(in vec2 d)
		{ return translate(d.x, d.y); } 
		auto translate(in ivec2 d)
		{ return translate(d.x, d.y); } 
		
		auto scale(float s)
		{
			 //Todo: ezt meg kell csinalni matrixosra.
			push; 
			origin *= scaleFactor; 
			scaleFactor *= s; 
			origin /= scaleFactor; 
			return this; //fluid interface
		} 
		
		////////////////////////////////////////////////////////////////////////////////
		//Draw primitives                                                           //
		////////////////////////////////////////////////////////////////////////////////
		
		struct DrawingObj
		{
			 align(1): 
			/+0+/uint aType; 	           //4
			/+4+/vec2 aA, aB, aC; 	           //24
			/+28+/uint aColor; 	           //4
			
			//drawGlyph only
			/+32+/vec2 aD; 	              //8
			/+40+/uint aColor2; 	              //4
			/+44+/uint aDummy; 	              //4
			
			/+48+/vec2 aClipMin, aClipMax;    //16  clipping rect.
			
			/+64+///total: 64 bytes: Terribly unoptimal
			
			void expandBounds(ref bounds2 b) const
			{
				if(isOldCmd(aType))
				{
					const t = getOldCmd(aType); 
					void x(in vec2 v)
					{ b |= v; } 
					
					if(t==1) x(aA); 
					else if(t.among(5, 6)) {
						//Point
						x(aA); x(aB); x(aC); 
					}
					else if(t.among(2, 3, 4, 7)) {
						//Tri, Bez2
						x(aA); x(aB); 
					}
					else
					raise("aType %s not impl".format(aType)); 
				}
				else
				NOTIMPL; 
				
			} 
			
			void applyTransform(vec2 delegate(in vec2) tr)
			{
				if(isOldCmd(aType))
				{
					auto t = getOldCmd(aType); 
					
					void x(ref vec2 v)
					{ v = tr(v); } 
					
					if(t==1) x(aA); 
					else if(t.among(5, 6)) {
						//Point
						x(aA); x(aB); x(aC); 
					}
					else if(t.among(2, 3, 4, 7)) {
						//Tri
						x(aA); x(aB); 
					}
				}
				else
				NOTIMPL; 
			} 
		} 
		static assert(DrawingObj.sizeof==64); 
		
		DrawingBuffers!DrawingObj buffers; 
		
		bool empty() const
		{ return buffers.empty && vboList.empty; } 
		
		
		static uint oldCmd(uint cmd, uint param=0) { return 1 | cmd<<1 | param<<4; } 
		
		static bool isOldCmd(uint type)
		{ return !!(type & 1); } 
		
		static uint getOldCmd(uint type)
		{ return type>>1&7; } 
		
		
		private void oldAppend(DrawingObj o)
		{
			assert(isOldCmd(o.aType)); 
			o.aClipMin = clipBounds.low; 
			o.aClipMax = clipBounds.high; 
			o.expandBounds(bounds_); 
			buffers.put(o); 
		} 
		
		void appendNewDrawObj(void[] buf)
		{
			enum requiredBufSize = DrawingObj.sizeof; 
			
			if(buf.length==requiredBufSize)
			{ buffers.put(*(cast(DrawingObj*)buf.ptr)); }
			else if(buf.length<requiredBufSize)
			{
				DrawingObj tmp; 
				(cast(void*)&tmp)[0..buf.length] = buf; 
				buffers.put(tmp); 
			}
			else
			enforce(0, "NewDrawObj: Buffer too big."); 
		} 
		
		public DrawingObj[] exportDrawingObjs()
		{ return buffers.allObjs; } 
		
		public DrawingObj[] exportDrawingObjs2()
		{ return buffers.allObjs ~ subDrawings.map!((sd)=>(sd.exportDrawingObjs2)).join; } 
		
		//private int dirty = -1; //must set to -1 data[] is changed. bit0 = VBO, bit1 = bounds
		private void markDirty()
		{/*dirty = -1;*/} 
		
		private bounds2 bounds_; 
		@property bounds2 bounds()const
		{ return bounds_; } 
		
		float inputTransformSize(float s)
		{ return s<=0 ? s : s*actState.drawScale.x; } 
		
		vec2 inputTransformRel(in vec2 p)
		{ return p*actState.drawScale; } //for relative movements
		
		vec2 inputTransform(in vec2 p)
		{ return (p+actState.drawOrigin)*actState.drawScale; } 
		vec2 inputTransform(in ivec2 p)
		{ return (p+actState.drawOrigin)*actState.drawScale; } 
		bounds2 inputTransform(in bounds2 b)
		{ return bounds2(inputTransform(b.low), inputTransform(b.high)); } 
		bounds2 inputTransform(in ibounds2 b)
		{ return bounds2(inputTransform(b.low), inputTransform(b.high)); } 
		
		vec2 inverseInputTransform(in vec2 v)
		{ return v/actState.drawScale-actState.drawOrigin; } //Todo: slow divide
		bounds2 inverseInputTransform(in bounds2 b)
		{ return bounds2(inverseInputTransform(b.low), inverseInputTransform(b.high)); } 
		
		float zoomFactor = 1; //comes from outside view: units * zoomFactor == unit size in pixels
		float invZoomFactor = 1; //comes from outside view
		//Todo: rename invScale and invZoomFactor to pixelSize, scale and zoomFactor to scaleFactor.
		
		//Todo: zoomFactor naming is incompatible with view.scale
		
		private enum clipBounds_init = bounds2(-1e30, -1e30, 1e30, 1e30); 
		bounds2 clipBounds = clipBounds_init; 
		private bounds2[] clipBoundsStack; 
		
		void pushClipBounds(bounds2 bnd)
		{
			 //bnd is in local coords
			clipBoundsStack ~= clipBounds; 
			clipBounds = inputTransform(bnd) & clipBounds; 
		} 
		
		void popClipBounds()
		{
			if(clipBoundsStack.length) {
				clipBounds = clipBoundsStack[$-1]; 
				clipBoundsStack = clipBoundsStack[0..$-1]; 
			}
		} 
		
		void clear()
		{
			if(logDrawing) LOG(shortName, "clearing", stats); 
			destroyVboList; 
			buffers.clear; 
			bounds_ = bounds2.init; 
			markDirty; 
			
			clipBounds = clipBounds_init; 
			clipBoundsStack = []; 
			
			actState = DrawState.init; 
			stateStack = []; 
			stack.clear; 
			
			subDrawings = []; 
		} 
		
		void clear(RGB background)
		{
			clear; 
			gl.clearColor(background);  gl.clear(GL_COLOR_BUFFER_BIT); 
		} 
		
		//Points //////////////////////////////////////////////////////////////////////
		
		void point(in vec2 p)
		{
			markDirty; 
			auto c = realDrawColor, s = inputTransformSize(pointSize); 
			/*
				if(data_.length) with(data[$-1]) if(aType==1 && aColor==c) {//extend the last Point1 to Point2
					aType = 2;
					aB = inputTransform(p);
					aC.y = s;
					return;
				}
			*/
			//Todo: point2 is not working with appender. should use vec2[]
			
			//Create a new Point1
			oldAppend(DrawingObj(oldCmd(1), inputTransform(p), vec2(0), vec2(s, 0), c)); 
		} 
		
		void point(in RGB c, in vec2 p)
		{
			 //Todo: refactor this
			const oldc = color; scope(exit) color = oldc; 
			color = c; 
			point(p); 
		} 
		
		void point(in float x, in float y)
		{ point(vec2(x, y)); } 
		void point(in RGB c, in float x, in float y)
		{ point(c, vec2(x, y)); } 
		
		void point(in ivec2 p)
		{ point(p.x, p.y); } 
		
		void point(in vec2[] p)
		{
			if(p.length==0) return; 
			markDirty; 
			auto c = realDrawColor, s = inputTransformSize(pointSize); 
			int idx = 0; 
			if(p.length&1) {
				 //first odd element. Try to snap to the prev point
				point(inputTransform(p[0])); 
				idx++; 
			}
			//from now process 2 points at a time
			while(idx<p.length) {
				oldAppend(DrawingObj(oldCmd(2), inputTransform(p[idx]), inputTransform(p[idx+1]), vec2(s, s), c)); 
				idx += 2; 
			}
		} 
		
		//Lines ///////////////////////////////////////////////////////////////////////
		
		vec2 lineCursor; //untransformed for fastness, but can't survive a transformation
		
		void lineTo(in vec2 p_)
		{
			 //Todo: const struct->in struct
			vec2 p = inputTransform(p_); 
			markDirty; 
			auto c = realDrawColor, w = inputTransformSize(lineWidth); 
			oldAppend(DrawingObj(oldCmd(3, actState.arrowStyle), inputTransform(lineCursor), p, vec2(w, lineStyle), c)); 
			lineCursor = p_; 
		} 
		void lineTo(in vec2 p, bool isLine)
		{ if(isLine) lineTo(p); else moveTo(p); } 
		
		void lineTo(in ivec2 p)
		{ lineTo(p); 	} void lineTo(in ivec2 p, bool isLine)
		{ lineTo(p, isLine); } 
		
		void moveTo(in vec2 p)
		{ lineCursor = p; } void moveTo(in ivec2 p)
		{ moveTo(p); } 
		
		void lineRel(in vec2 p)
		{ lineTo(lineCursor+p); } //kinda slow, but can change transformations between relative movements
		void moveRel(in vec2 p)
		{ moveTo(lineCursor+p); } 	void line(in vec2 p0, in vec2 p1)
		{ lineCursor = p0; lineTo(p1); } 
		
		void line(in ivec2 p0, in ivec2 p1)
		{ line(vec2(p0), vec2(p1)); } void line(in seg2 s)
		{ line(s.p[0], s.p[1]); } void line(in seg2[] a)
		{ foreach(const s; a) line(s); } 
		
		void lineTo(float x, float y)
		{ lineTo(vec2(x, y)); } 	void lineTo(float x, float y, bool isLine)
		{ lineTo(vec2(x, y), isLine); } 	
		void moveTo(float x, float y)
		{ moveTo(vec2(x, y)); } 	void lineRel(float x, float y)
		{ lineRel(vec2(x, y)); } 	void moveRel(float x, float y)
		{ moveRel(vec2(x, y)); } 
		void line(float x0, float y0, float x1, float y1)
		{ line(vec2(x0, y0), vec2(x1, y1)); } 	
		
		void line(T)(in T[] points)
		{ if(points.length>1) { moveto(points[0]); foreach(const p; points[1..$]) lineto(p); }} 
		void lineLoop(T)(in T[] points)
		{ if(points.length>1) { line(points); lineto(points[0]); }} 
		
		void hLine(in vec2 p0, float x1)
		{ line(p0.x, p0.y, x1, p0.y); } void hLine(float x0, float y, float x1)
		{ line(x0, y, x1, y); } 
		void vLine(in vec2 p0, float y1)
		{ line(p0.x, p0.y, p0.x, y1); } void vLine(float x, float y0, float y1)
		{ line(x, y0, x, y1); } 
		
		/*
			void line2(T...)(in args T){
			foreach(a; args){
				alias A = unqual!(typeof(a));
				static if(is(A == vec2)) lineTo(a);
				static if(is(A == ivec2)) lineTo(a);
				static if(is(A == vec2[])) lineTo(a);
				static if(is(A == ivec2[])) lineTo(a);
				static if(is(A == RGB )){ color = a;	alpha = 1;	}
				static if(is(A == RGBA)){ color = a.to!RGB;	alpha = a.a/255.0f;	}
				static if(isIntegral!A || isFloatingPoint!A) lineWidth = a;
				//todo: static if(is(A == LineStyle)) lineStyle = a;
				}
			}
		*/
		
		void line2(A...)(in A args)
		{
			
			//backup current drawState (only a	subset of it)
			auto backup = actState.quickSave; 	scope(exit) actState.quickRestore(backup); 
			//Todo: only do this when tere are	colors, or styles in the args
			
			bool first = false; 
			float coord; //it remembers the first coordinate
			
			static foreach(a; args)
			{
				{
					alias T = Unqual!(typeof(a)); 
					static if(is(T == RGB	))	{ color = a; }
					else static if(is(T == RGBA	))	{ color = a.rgb; alpha = a.a/255.0f; }
					else static if(is(T == LineStyle))	{ lineStyle = a; }
					else static if(is(T == ArrowStyle))	{ arrowStyle = a; }
					else static if(is(T == vec2	))	{ lineTo(a, first); first = true; }
					else static if(is(T == ivec2	))	{ lineTo(a, first); first = true; }
					else static if(is(T == seg2	))	{ lineTo(a[0], first); first = true; lineTo(a[1]); }
					else static if(is(T == bounds2	))	{
						lineTo(a.topLeft, first); lineTo(a.topRight); 
						lineTo(a.bottomRight), lineTo(a.bottomLeft), lineTo(a.topLeft); 
					}
					else static if(is(T == ibounds2	))	{
						lineTo(a.topLeft, first); lineTo(a.topRight); 
						lineTo(a.bottomRight), lineTo(a.bottomLeft), lineTo(a.topLeft); 
					}
					else static if(isNumeric!T	)	{
						if(isnan(coord)) coord = a; 
						else { lineTo(coord, a, first); first = true; coord = float.init; }
					}
					else static if(is(T==GenericArg!(N, T2), string N, T2))
					{
						static if(N=="lineWidth" || N=="lw")	{ lineWidth = a.value; }
						else static if(N=="pointSize" || N=="ps")	{ pointSize = a.value; }
						else static if(N=="alpha" || N=="a")	{ alpha = a.value; }
						else static assert("Invalid genericArg: "~T.stringof); 
					}
					else static assert(0, "invalid type: "~T.stringof); 
				}
			}
		} 
		
		void bezier2(in vec2 A, in vec2 B, in vec2 C)
		{
			markDirty; 
			auto c = realDrawColor, w = inputTransformSize(lineWidth); 
			oldAppend(DrawingObj(oldCmd(6), inputTransform(A), inputTransform(B), inputTransform(C), c,vec2(w, lineStyle))); 
		} 
		
		protected static auto genRgbGraph(string fv)()
		{
			return 
			q{
				auto oldColor = color; 
				//Note: this is not sure if black or white, or ignored. color = clWhite; @(x0, y0, data.map!"a.l".array, xScale, yScale);
				color = clRed	; @(x0, y0, data.map!"a.r".array, xScale, yScale); 
				color = clLime	; @(x0, y0, data.map!"a.g".array, xScale, yScale); 
				color = clBlue	; @(x0, y0, data.map!"a.b".array, xScale, yScale); 
				static if(is(T==RGBA8)) { color = clFuchsia; @(x0, y0, data.map!"a.a".array, xScale, yScale); }
				color = oldColor; 
			}
			.replace("@", fv); 
		} 
		
		void vGraph(T)(float x0, float y0, in T[] data, float xScale=1, float yScale=1)
		{
			if(data.empty) return; 
			static if(is(T==RGB8)||is(T==RGBA8))	{ mixin(genRgbGraph!"vGraph"); }
			else static if(is(T==vec2) || is(T==ivec2))	{ foreach(i, const v; data) lineTo(x0+v.y*xScale, y0+v.x*yScale, i); }
			else	{
				moveTo(x0+data[0]*xScale, y0); 
				foreach(d; data[1..$]) {
					y0 += yScale; 
					lineTo(x0+d*xScale, y0); 
				}
			}
		} 
		
		void hGraph(T)(float x0, float y0, in T[] data, float xScale=1, float yScale=1)
		{
			if(data.empty) return; 
			static if(is(T==RGB8)||is(T==RGBA8))	{ mixin(genRgbGraph!"hGraph"); }
			else static if(is(T==vec2) || is(T==ivec2))	{ foreach(i, const v; data) lineTo(x0+v.x*xScale, y0+v.y*yScale, i); }
			else	{
				moveTo(x0, y0+data[0]*yScale); 
				foreach(d; data[1..$]) {
					x0 += xScale; 
					lineTo(x0, y0+d*yScale); 
				}
			}
		} 
		
		void hBars(R1)(float x0, float y0, R1 data, float xScale=1, float yScale=1, float sideGap = .1f)
		if(isRandomAccessRange!R1)
		{
			if(data.empty) return; 
			void doit(bool flip)()
			{
				foreach(i, val; data)
				{
					float v0 = 0, v1 = val; 
					static if(flip) (mixin(配(q{v0, v1},q{=},q{v1, v0}))); 
					fillRect(
						x0+(i+(0+sideGap))*xScale, y0+v0*yScale, 
						x0+(i+(1-sideGap))*xScale, y0+v1*yScale
					); 
				}
			} 
			if((xScale>0)==(yScale>0)) doit!false; else doit!true; 
		} 
		
		
		void vGraph(T)(in vec2 v0, in T[] data, float xScale=1, float yScale=1)
		{ vGraph(v0.x, v0.y, data, xScale, yScale); } 
		void hGraph(T)(in vec2 v0, in T[] data, float xScale=1, float yScale=1)
		{ hGraph(v0.x, v0.y, data, xScale, yScale); } 
		
		void vGraph(T)(in ivec2 v0, in T[] data, float xScale=1, float yScale=1)
		{ vGraph(v0.x, v0.y, data, xScale, yScale); } 
		void hGraph(T)(in ivec2 v0, in T[] data, float xScale=1, float yScale=1)
		{ hGraph(v0.x, v0.y, data, xScale, yScale); } 
		
		alias vline = vLine, hline = hLine, moveto = moveTo, lineto = lineTo; 
		
		void drawRect(float x0, float y0, float x1, float	y1)
		{ hLine(x0, y0, x1); hLine(x0, y1, x1); vLine(x0, y0, y1); vLine(x1, y0, y1); } 
		void drawRect(in vec2 a, in vec2 b)
		{ drawRect(a.x, a.y, b.x, b.y); } 
		void drawRect(in bounds2 b)
		{ drawRect(b.low, b.high); } void drawRect(in ibounds2 b)
		{ drawRect(bounds2(b)); } 
		
		void drawX(float x0, float y0, float x1, float y1)
		{ line(x0, y0, x1, y1); line(x0, y1, x1, y0); } void drawX(in vec2 a, in vec2 b)
		{ drawX(a.x, a.y, b.x, b.y); } 
		void drawX(in bounds2 b)
		{ drawX(b.low, b.high); } void drawX(in ibounds2 b)
		{ drawX(bounds2(b)); } 
		
		void fillRect(float x0, float y0, float x1, float y1)
		{
			auto c = realDrawColor; 
			oldAppend(DrawingObj(oldCmd(4), inputTransform(vec2(x0, y0)), inputTransform(vec2(x1,y1)), vec2(0, 0), c)); 
		} 
		void fillRect(in vec2 a, in vec2 b)
		{ fillRect(a.x, a.y, b.x, b.y); } void fillRect(in bounds2 b)
		{ fillRect(b.low, b.high); } void fillRect(in ibounds2 b)
		{ fillRect(bounds2(b)); } 
		//Todo: ibounds2 automatikusan atalakulhasson bounds2-re
		struct DrawGlyphScale { float value=1; } 
		
		void drawGlyph_impl(T...)(int idx, in bounds2 bnd, in T args)
		{
			if(idx<0) return; 
			
			auto rectAlign = RectAlign(HAlign.center, VAlign.center, true, false, true); //shrink, enlarge, aspect
			auto nearest = No.nearest; 
			
			auto 	color 	= realDrawColor,
				bkColor 	= (RGBA(0, 0, 0, 255)); 
			int shaderIdx = -1; 
			SamplerEffect samplerEffect = SamplerEffect.none; 
			float drawScale = 1; 
			
			static foreach(i, A_; T)
			{
				{
					alias A = Unqual!A_; auto a() { return args[i]; } 
					static if(is(A==RGB8	))	bkColor = a.to!RGBA8; 
					else static if(is(A==RGBA8	))	bkColor = a; 
					else static if(is(A==Flag!"nearest"	))	nearest = a; 
					else static if(is(A==RectAlign	))	rectAlign = a; 
					else static if(is(A==DrawGlyphScale	))	drawScale = a.value; 
					else static if(is(A==SamplerEffect	))	samplerEffect = a; 
					else static if(is(A==GenericArg!(N, T), string N, T))
					{
						static if(N=="shaderIdx")	shaderIdx = a.value; 
						else static if(N=="color")	color = a.value; 
						else static if(N=="bkColor")	bkColor = a.value; 
					}
					else { static assert(0, "Unhandled parameter: " ~ A.stringof); }
				}
			}
			
			auto c = color; 
			auto c2 = bkColor; 
			
			auto 	tx0 = vec2(
				(nearest ? 0 : 1) | 16/*fontflag=image*/ | 
				(shaderIdx>=0 ? 32 + 64*shaderIdx : 0) | ((cast(int)(samplerEffect))<<16), 0
			),
				tx1 = vec2(0, 1)/+y subRange [0..1]+/; 
			
			auto info = textures.accessInfo(idx); //Todo: csunya, kell egy texture wrapper erre
			
			auto b2 = rectAlign.apply(bnd, bounds2(0, 0, info.width*drawScale, info.height*drawScale)); 
			
			oldAppend(DrawingObj(oldCmd(7, idx), inputTransform(b2.low), inputTransform(b2.high), tx0, c, tx1, c2.raw)); 
		} 
		
		void drawGlyph_impl(T...)(int idx, in vec2 topLeft, in T args)
		{
			//autosize version
			if(idx<0) return; 
			auto info = textures.accessInfo(idx); //Opt: double call to accessInfo
			drawGlyph_impl(idx, bounds2(topLeft, topLeft+info.size), args); 
		} 
		
		void drawGlyph(Img, T...)(/+Not const because CustomTexture.texIdx is mutable+/Img img, in T args)
		{
			//Img can be int or Bmp File or string
			//Todo: Bitmap, Image2D
			int idx = -1; 
			static if(isSomeString!Img)	idx = textures.accessLater(img); 
			else static if(is(Img : File))	idx = textures.accessLater(img); 
			else static if(is(Img == Bitmap))	{ if(img) idx = textures.accessLater(img.file); }
			else static if(isIntegral!Img)	idx = img; 
			else	static assert(0, "Unsupported Img param: "~Img.stringof); 
			
			//position can be x,y  vec2,   ivec2      the size is automatic
			//bounds can be bounds2, ibounds2   2x vec2,
			static if(T.length>=1 && isBounds!(T[0]))
			{ drawGlyph_impl(idx, bounds2(args[0   ]), args[1..$]); }
			else static if(T.length>=1 && isVector!(T[0]))
			{
				static if(T.length>=2 && isVector!(T[1]))
				drawGlyph_impl(idx, bounds2(args[0..2]), args[2..$]); 
				else
				drawGlyph_impl(idx, vec2   (args[0	]), args[1..$]); 
			}
			else static if(T.length>=2 && __traits(isArithmetic, T[0]) && __traits(isArithmetic, T[1]))
			{
				static if(T.length>=4 && __traits(isArithmetic, T[2]) && __traits(isArithmetic, T[3]))
				drawGlyph_impl(idx, bounds2(args[0..4]), args[4..$]); 
				else
				drawGlyph_impl(idx, vec2   (args[0..2]), args[2..$]); 
			}
			else static assert(0, "Unsupported Bounds param: "~Img.stringof); 
			
			/+
				Todo: DIDE bug with double nested "else static if"s when there is no {}
						The else static if is lost after an inner else
			+/
		} 
		
		/+
			//old shit
			
				/*  void drawGlyph(int idx	, in bounds2 b, in RGB8 bkColor = clBlack){
				void drawGlyph(in File fileName,	in bounds2 b, in RGB8 bkColor = clBlack){
				void drawGlyph(in File fileName,	in vec2 p, in RGB8 bkColor = clBlack){
				void drawGlyph(int idx								 ,	in vec2 p, in RGB8 bkColor = clBlack){ //todo: ezeket az fv headereket racionalizalni kell
				void drawGlyph(int idx								 ,	float x=0, float y=0, in RGB8 bkColor = clBlack){ */
			
				void drawGlyph(int idx, in bounds2 b, in RGB8 bkColor = clBlack){
					auto c = realDrawColor;
					auto c2 = bkColor.to!RGBA8;
			
					auto tx0 = vec2(16/*fontflag=image*/, 0),
							 tx1 = vec2(1, 1);
			
					//align proportiolally
					auto al = RectAlign(HAlign.center, VAlign.center, true, false, true); //shrink, enlarge, aspect
			
					auto info = textures.accessInfo(idx); //todo: csunya, kell egy texture wrapper erre
			
					auto b2 = al.apply(b, bounds2(0, 0, info.width, info.height));
			
					append(DrawingObj(256+idx, inputTransform(b2.low), inputTransform(b2.high), tx0, c, tx1, c2.raw));
				}
			
				void drawGlyph(in File fileName, in bounds2 b, in RGB8 bkColor = clBlack){
					drawGlyph(textures(fileName), b, bkColor);
				}
			
				void drawGlyph(in File fileName, in vec2 p, in RGB8 bkColor = clBlack){
					drawGlyph(textures(fileName), p, bkColor);
				}
			
				void drawGlyph(int idx, in vec2 p, in RGB8 bkColor = clBlack){ //todo: ezeket az fv headereket racionalizalni kell
					auto info = textures.accessInfo(idx);
					drawGlyph(idx, bounds2(p.x, p.y, p.x+info.width, p.y+info.height), bkColor);
				}
			
				void drawGlyph(int idx, float x=0, float y=0, in RGB8 bkColor = clBlack){
					drawGlyph(idx, vec2(x, y), bkColor);
				} 
		+/
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		void drawTexture(B, T...)(int stIdx, in B bnd, in T args)
		{
			//Note: This simplified version is used in TimeView/KarcLogger
			if(stIdx<0) return; 
			
			auto nearest = No.nearest; 
			int shaderIdx = -1; 
			SamplerEffect samplerEffect = SamplerEffect.none; 
			auto 	color 	= (RGBA(0xFFFFFFFF)),
				bkColor 	= (RGBA(0xFF000000)); 
			
			static foreach(i, A_; T)
			{
				{
					alias A = Unqual!A_; auto a() { return args[i]; } 
					static if(is(A==Flag!"nearest"	))	nearest = a; 
					else static if(is(A==SamplerEffect)) samplerEffect = a; 
					else static if(is(A==GenericArg!(N,	T), string N, T))
					{
						static if(N=="shaderIdx")	shaderIdx = a.value; 
						else static if(N=="color")	color = a.value; 
						else static if(N=="bkColor")	bkColor = a.value; 
					}
					else static assert(0, "Unhandled parameter "~typeof(a).stringof); 
				}
			}
			
			auto 	tx0 = vec2(
				(nearest ? 0 : 1) | 16/*fontflag=image*/ | 
				(shaderIdx>=0 ? 32 + 64*shaderIdx : 0) | ((cast(int)(samplerEffect))<<16) , 0
			),
				tx1 = vec2(0, 1)/+y subRange [0..1]+/; 
			
			oldAppend(
				DrawingObj(
					oldCmd(7, stIdx), inputTransform(bnd.low), inputTransform(bnd.high), 
					tx0, color.raw, tx1, bkColor.raw
				)
			); 
		} 
		
		void drawFontGlyph(
			int idx, in bounds2 b, in RGB8 bkColor = clBlack, 
			in int fontFlags = 0, in vec2 ySubRange = vec2(0, 1)
		)
		{
			//bit0:bold
			auto c = realDrawColor; 
			auto c2 = bkColor.to!RGBA8; 
			
			auto 	tx0 = vec2(fontFlags, 0),
				tx1 = ySubRange; 
			
			//Todo: must combine this with drawGlyph
			
			//align proportiolally
			//auto al = RectAlign(HAlign.center, VAlign.center, true, true, false); //shrink, enlarge, aspect
			
			//auto info = textures.accessInfo(idx); //todo: csunya, kell egy texture wrapper erre
			
			//auto b2 = al.apply(b, bounds2(0, 0, info.width, info.height));
			
			oldAppend(DrawingObj(oldCmd(7, idx), inputTransform(b.low), inputTransform(b.high), tx0, c, tx1, c2.raw)); 
		} 
		
		void fillTriangle(float x0, float y0, float x1, float y1, float x2, float y2)
		{
			auto c = realDrawColor; 
			oldAppend(
				DrawingObj(
					oldCmd(5), 
					inputTransform(vec2(x0, y0)), 
					inputTransform(vec2(x1,y1)), 
					inputTransform(vec2(x2,y2)), 
					c
				)
			); 
		} 
		void fillTriangle(in vec2 a, in vec2 b, in vec2 c)
		{ fillTriangle(a.x, a.y, b.x, b.y, c.x, c.y); } 
		
		void fillConvexPoly(in vec2[] p)
		{ foreach(i; 2..p.length) fillTriangle(p[0], p[i], p[i-1]); } 
		
		void drawRombus(float x0, float y0, float x2, float y2)
		{
			auto 	x1 = (x0+x2)*0.5f,
				y1 = (y0+y2)*0.5f; 
			moveTo(x0, y1); lineTo(x1, y0); lineTo(x2, y1); lineTo(x1, y2); lineTo(x0, y1); 
		} 
		void drawRombus(in vec2 a, in vec2 b)
		{ drawRombus(a.x, a.y, b.x, b.y); } 
		void drawRombus(in bounds2 b)
		{ drawRombus(b.low, b.high); } 
		
		void fillRombus(float x0, float y0, float x2, float y2)
		{
			auto x1 = (x0+x2)*0.5f,
					 y1 = (y0+y2)*0.5f; 
			fillConvexPoly([vec2(x0,y1), vec2(x1, y0), vec2(x2, y1), vec2(x1, y2)]); 
		} 
		void fillRombus(in vec2 a, in vec2 b)
		{ fillRombus(a.x, a.y, b.x, b.y); } 
		void fillRombus(in bounds2 b)
		{ fillRombus(b.low, b.high); } 
		//gridLines ////////////////////////////////////////////////////
		
		void gridLines(
			View2D view, float dist, RGB color=clGray, 
			float width=-1, LineStyle style = LineStyle.normal, string hv = "hv"
		)
		{
			//Todo: this is not working with translate()
			auto horz = hv.canFind('h'), vert = hv.canFind('v'); 
			if(!horz && !vert) return; 
			
			saveState; 
			const savedBounds = bounds_; 
			
			scope(exit) {
				bounds_ = savedBounds; 
				restoreState; 
			}
			
			this.color = color; 
			lineWidth = width; 
			lineStyle = style; 
			
			auto vis = view.visibleArea; 
			vis.low = (vis.low/dist-1).floor*dist; 
			vis.high = (vis.high/dist+1).ceil*dist; 
			const 	cnt 	= vis.size/dist,
				siz	= view.clientSize/cnt; 
			
			foreach(c; 0..2)
			{
				if(c==0 && horz || c==1 && vert)
				{
					alpha = remap_clamp(siz[c], 4, 16, 0, 0.20); 
					if(!alpha) continue; 
					
					for(float a = vis.low[c]; a<=vis.high[c]; a+=dist)
					{
						if(c==0) vLine(a, vis.low.y, vis.high.y); 
						else hLine(vis.low.x, a, vis.high.x); 
					}
				}
			}
		} 
		
		void mmGrid(View2D view)
		{
			auto a = 0.55f; 
			gridLines(view, 1,	clGray,	0.05*a); 
			gridLines(view, 5,	clGray,	0.10*a); 
			gridLines(view, 10,	clWhite,	0.15*a); 
		} 
		
		void inchGrid(View2D view)
		{
			gridLines(view, 25.4/16, clGray , 0.05); 
			gridLines(view, 25.4/ 4, clGray , 0.10); 
			gridLines(view, 25.4   , clWhite, 0.15); 
		} 
		
		//Ellipse/circle //////////////////////////////////////////////////////////////
		
		void ellipse(float x, float y, float ra, float rb, float arc0=0, float arc1=2*PI, float incr=0)
		{
			while(arc0>arc1) arc1 += 2*PI; //Todo: lame
			
			int cnt; 
			if(incr>0)
			{ cnt = iround((arc1-arc0)/incr); }
			else
			{
				float rounds = (arc1-arc0)*(0.5f/PI); 	
				cnt = iround(rounds*64); 	//resolution  //todo: it should be done in the shader
				incr = cnt ? (arc1-arc0)/cnt : 0; 
			}
			
			foreach(i; 0..cnt+1) {
				float a = arc0+incr*i; 
				lineTo(x+sin(a)*ra, y+cos(a)*rb, !!i); 
			}
		} 
		void ellipse(in vec2 p, float r, float arc0=0, float arc1=2*PI)
		{ ellipse(p.x, p.y, r, r, arc0, arc1); } 
		void ellipse(in vec2 p, in vec2 r, float arc0=0, float arc1=2*PI)
		{ ellipse(p.x, p.y, r.x, r.y, arc0, arc1); } 
		
		void circle(float x, float y, float r, float arc0=0, float arc1=2*PI)
		{ ellipse(x, y, r, r, arc0, arc1); } 
		void circle(in vec2 p, float r, float arc0=0, float arc1=2*PI)
		{ ellipse(p.x, p.y, r, r, arc0, arc1); } 
		
		//Text ////////////////////////////////////////////////////////////////////////
		
		float textWidth(string text)
		{
			auto scale = fontHeight*(1.0f/40); 
			//Todo: nem mukodik a negativ lineWidth itt! Sot! Egyaltalan nem mukodik a linewidth
			
			return plotFont.textWidth(scale, fontMonoSpace, text); 
		} 
		
		void textOut(vec2 p, string text, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false)
		{
			saveState; scope(exit) restoreState; //Opt: slow
			
			auto scale = fontHeight*(1.0f/40); 
			//Todo: nem mukodik a negativ lineWidth itt! Sot! Egyaltalan nem mukodik a linewidth
			
			lineWidth = 3*scale*fontWeight; 
			lineStyle = LineStyle.normal; 
			
			//align
			with(HAlign)
			if(align_!=left) {
				auto tw = plotFont.textWidth(scale, fontMonoSpace, text); 
				p.x += (width-tw)*(align_==center ? 0.5f : 1.0f); 
			}
			
			
			plotFont.drawText(this, p, scale, fontMonoSpace, fontItalic, text, vertFlip); 
		} 
		void textOut(float x, float y, string text, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false)
		{ textOut(vec2(x, y), text, width, align_, vertFlip); } 
		void textOut(in ivec2 p, string text, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false)
		{ textOut(vec2(p), text, width, align_, vertFlip); } 
		
		void textOut(vec2 p, string[] lines, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false)
		{
			foreach(s; lines) {
				textOut(p, s, width, align_, vertFlip); 
				p.y += fontHeight; 
			}
			return; 
		} 
		
		void textOut(float x, float y, string[] lines, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false)
		{ textOut(vec2(x, y), lines, width, align_, vertFlip); } 
		
		void textOutMulti(float x, float y, string lines, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false)
		{ textOut(x, y, lines.splitLines, width, align_, vertFlip); } 
		
		void textOutMulti(vec2 p, string lines, float width = 0, HAlign align_ = HAlign.left, bool vertFlip = false)
		{ textOut(p, lines.splitLines, width, align_, vertFlip); } 
		
		void autoSizeText(vec2 p, string s, float aspect=1.0f)
		{
			auto fh = fontHeight; 
			const baseSize = vec2(textWidth(s), fh); 
			
			const target = fh*aspect; 
			vec2 size = baseSize; 
			while(size.x > target) {
				enum step = .75f; 
				fh *= step; 
				size *= step; 
			}
			
			const oldFh = fontHeight; 
			fontHeight = fh; 
			
			textOut(p-size/2, s); 
			
			fontHeight = oldFh; 
		} 
		
		
		//Draw Bitmap ////////////////////////////////////
		
		void fillRectClearType(float x0, float y0, float x1, float y1)
		{
			auto xa = mix(x0, x1, 0.333333); 
			auto xb = mix(x0, x1, 0.666666); 
			auto oldc = color; 
			color = RGB8(oldc.raw & 0x0000FF); fillRect(x0, y0, xa, y1); 
			color = RGB8(oldc.raw & 0x00FF00); fillRect(xa, y0, xb, y1); 
			color = RGB8(oldc.raw & 0xFF0000); fillRect(xb, y0, x1, y1); 
			color = oldc; 
		} 
		
		//It's slow but simple. Can be used to debug without using textures.
		void drawPixels(Bitmap bmp, float x0=0, float y0=0, bool clearTypeEffect=false)
		{
			if(bmp is null || bmp.empty) return; 
			
			auto img = bmp.get!RGB; 
			foreach(x, y, c; img) {
				color = c; 
				if(clearTypeEffect) fillRectClearType	(x0+x, y0+y, x0+x+1, y0+y+1); 
				else fillRect	(x0+x, y0+y, x0+x+1, y0+y+1); 
			}
		} 
		
		void drawClearType(Bitmap bmp, float x0=0, float y0=0)
		{ drawPixels(bmp, x0, y0, true); } 
		
		void drawAlpha(Bitmap bmp, float x0=0, float y0=0)
		{
			//Todo: bmp.to    auto tmp = bmp.to!LA8;
			enforce("not impl"); 
			/*
				auto tmp = bmp.dup;
				if(tmp.channels==4) tmp.rgba.data.each!((ref c){ c.r = c.a; c.g = c.a; c.b = c.a; });
				draw(tmp, x0, y0);
			*/
		} 
		
		
		//Complex stuff: debug scene //////////////////////////////////////////////////
		
		
		void debugDrawings(View2D view)
		{
			mmGrid(view); 
			
			foreach(i; 1..9) {
				//draw points
				pointSize =  i; point(i*10    , 0); //absolute size
				pointSize = -i; point(i*10+100, 0); //relative size
				
				//draw lines
				lineWidth =  i; moveTo(i*10    , 10); lineRel(20, 30); //absolute size
				lineWidth = -i; moveTo(i*10+100, 10); lineRel(20, 30); //relative size
			}
			
			import std.traits; 
			lineWidth = 1; 
			moveTo(0, 50.5f); 
			foreach(ls; EnumMembers!LineStyle) {
				lineStyle = ls; 
				lineRel(200, 0);  moveRel(-200, 10); 
			}
			lineStyle = LineStyle.normal; 
			
			lineWidth = 2; 
			color = clYellow; 
			drawRect(-10, -10, 210, 110); 
		} 
		
		
		void draw(F)(in Image!(F, 2) img, RGB delegate(F) fun, in vec2 pos = vec2(0), in vec2 scale = vec2(1))
		{
			foreach(p; img.size.iota2D) {
				color = fun(img[p]); 
				fillRect(bounds2(pos + p*scale, ((scale).genericArg!q{size}))); 
			}
		} 
		
		
		
		
		
		//these can be used from the customShaders
		static {
			//Shader management /////////////////////////////
			
			struct GlobalShaderParams {
				float[] floats; 
				bool[] bools; 
			} 
			
			GlobalShaderParams globalShaderParams; 
			
			static this()
			{
				globalShaderParams.floats = [0.0f].replicate(8); 
				globalShaderParams.bools = [false].replicate(8); 
			} 
			
			private string customShader_; 
			private bool customShaderChanged; 
			
			@property void customShader(string s)
			{ if(chkSet(customShader_, s)) { customShaderChanged = true; }} 
			@property string customShader()
			{ return customShader_; } 
			
			void delegate(Shader) onCustomShaderSetup; //entry point to setup custom variables for the customShader
			
			Shader getShader()
			{
				auto recompile(Flag!"ignoreCustomShader" ignoreCustomShader)
				{
					//const t0 = QPS;
					
					string code = shaderCode; 
					if(!ignoreCustomShader && customShader_!="")
					{
						auto p = code.split("vec4 customShader(){"); 
						if(p.length!=2) p = code.split("vec4 customShader() {"); 
						if(p.length!=2) p = code.split("vec4 customShader()\r\n{"); 
						enforce(p.length==2); 
						auto i = p[1].map!(ch => ch.among('\r', '\n')).countUntil(true); 
						enforce(i>0); 
						p[1] = p[1][i+1..$]; 
						
						code = p[0] ~ customShader ~ "\n" ~ p[1]; 
					}
					
					return new Shader("Draw2D", code); 
					//LOG("Shader compiled in", QPS-t0, "sec");
				} 
				
				static Shader sh, shDefault; 
				if(!sh || customShaderChanged)
				{
					
					customShaderChanged = false; 
					try { sh = recompile(No.ignoreCustomShader); }
					catch(Exception e)
					{
						if(!shDefault)
						try { shDefault = sh = recompile(Yes.ignoreCustomShader); }
						catch(Exception e2)
						{
							ERR(e2.simpleMsg); 
							throw new Exception("FATAL ERROR: can't compile default shader for Draw2D"); 
						}
						
						ERR("Error compiling Draw2D shader\n" ~ e.simpleMsg); 
						beep; 
						sh = shDefault; 
					}
				}
				
				return sh; 
			} 
		} 
		
		
		
		//Draw the objects on GPU  /////////////////////////////
		
		void glDraw(View2D view, in View2D.V translate=0)
		{
			glDraw(view.getOrigin(true), view.getScale(true), translate); 
			
			view.workArea_accum |= View2D.B(this.bounds); 
		} 
		
		void glDraw(in View2D.V center, float scale, in View2D.V translate=0)
		{
			
			//static if(1){ const T0 = QPS; scope(exit) print("DR", (QPS-T0)*1000); }
			
			enforce(stack.empty, "Drawing.glDraw() matrix stack is not empty.  It has %d items.".format(stack.length)); 
			enforce(clipBoundsStack.empty, "Drawing.glDraw() clipBounds stack is not empty.  It has %d items.".format(clipBoundsStack.length)); 
			
			if(logDrawing) LOG(shortName, "drawing", stats, "center:", center, "scale:", scale, "translate:", translate); 
			
			enum enableLogging = (常!(bool)(1)); 
			static if(enableLogging)
			{
				{
					static logTick = 0u; 
					static bool pressed; 
					const f = File(`c:\dl\hetlib_draw.log`); 
					if(pressed.chkSet(KeyCombo("Ctrl+Alt+Shift+PrtScn").down) && pressed)
					{
						logTick = application.tick+4; 
						f.remove; 
					}
					if(logTick==application.tick)
					{
						f.append(exportDrawingObjs); 
						LOG(this, "saved to", f); 
					}
				}
			}
			
			drawCnt++; 
			vboList ~= buffers.toVBOs; 
			buffers.clear; 
			
			//LOG(identityStr(this), name, drawCnt, vboList.length);
			
			/*
				//transfer buffers into vboes
					//LOG("B", buffers.length);
					foreach(data; buffers){
						//LOG("DL", data.length);
						totalDrawObj += data.length;
						vboList ~= new VBO(data);
					}
					buffers.clear;
			*/
			
			auto shader = getShader; 
			
			auto vpSize = gl.getViewport.size;  //Todo: ezek a vbo hivas elott mehetnek kifele
			
			auto 	uScale = vec2(scale),
				uShift = -center; 
			
			shader.uniform("uScale", uScale); 
			
			vec2 extractTileIndex(T)(T vIn)
			{
				static if(is(T==dvec2))
				{
					//Todo: Implement double FP64 WORLD Coordinates
				}
				return vec2(vIn); 
			} 
			
			shader.uniform("uShift", extractTileIndex(uShift+translate)); 
			shader.uniform("uViewPortSize", vec2(vpSize)); 
			
			shader.uniform("appRunningTime_sec", mainWindow.appRunningTime_sec); 
			
			//map all megaTextures
			foreach(i, t; textures.getGLTextures) {
				t.bind(cast(int)i, i==0 ? GLTextureFilter.Nearest : GLTextureFilter.Linear); 
				auto name = i==0 ? "smpInfo" : "smpMega[%d]".format(i-1); 
				shader.uniform(name, cast(int)i, false); 
			}
			
			//update shader uniform values
			foreach(idx, b; globalShaderParams.bools) shader.uniform("GB"~idx.text, b, false); 
			foreach(idx, f; globalShaderParams.floats) shader.uniform("GF"~idx.text, f, false); 
			
			if(onCustomShaderSetup) onCustomShaderSetup(shader); 
			
			//Todo: ezeket az allapotokat elmenteni es visszacsinalni, ha kell, de leginkabb bele kene rakni egy nagy functba az egesz hobelevancot...
			
			gl.enable(GL_CULL_FACE); 	gl.cullFace(GL_BACK); gl.frontFace(GL_CCW); 
			gl.enable(GL_BLEND); 	gl.blendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); 
			gl.enable(GL_ALPHA_TEST); 	gl.alphaFunc(GL_GREATER, 0); 
			gl.disable(GL_DEPTH_TEST); 
			
			foreach(vbo; vboList) {
				shader.attrib(vbo); //this bings the VBO and the Shader too
				
				//gl.polygonMode(GL_FRONT_AND_BACK, GL_LINE);
				vbo.draw(GL_POINTS); 
			}
			
			foreach(sd; subDrawings) { sd.glDraw(center, scale, translate); }
		} 
			//Todo: A binaris konstansokat is szemleltethetne az ide!
			//Todo: az IDE automatikusan irhatna a bezaro } jelek utan, hogy mit zar az be. Csak annak a scopenak, amiben a cursor van.
		
		
		void strip(R)(dvec2 p0)
		{} 
		
	}
	
	static immutable shaderCode =
		format!q{
		#version 330
		// 231013: 150 -> 330
		
		#define MegaTexMaxCnt	%s
		#define SubTexCellBits	%s
		#define InvBoldOffset	%s
		#define BoldOffset	(1.0/InvBoldOffset)
	}(
		MegaTexMaxCnt,
		SubTexCellBits,
		InvBoldOffset
	)~
		q{
		int fetchBits(inout int a, in int bits)
		
		{
			int res = a & ((1<<bits)-1); 
			a = a>>bits; 
			return res; 
		} 
		
		#define sqr(a)  ((a)*(a))
		#define PI 3.14159265359
		
		vec4 uint_to_vec4(uint a)
		{
			return vec4(
				(a>> 0&0xFFU)/255.0,
				(a>> 8&0xFFU)/255.0,
				(a>>16&0xFFU)/255.0,
				(a>>24&0xFFU)/255.0
			); 
		} 
		
		@vertex: //////////////////////////////////////////////////////////////////////////
		in uint aType; in vec2 aA, aB, aC, aD; in  uint aColor, aColor2, aDummy; in vec2 aClipMin, aClipMax; 
		out uint Type; out vec2 A, B, C, D; out uint Color, Color2, Dummy; out vec2 ClipMin , ClipMax; 
		void main()
		{
			A=aA; B=aB; C=aC; Color=aColor; Type=aType; 
			
			//glyph only
			D=aD; 
			Color2=aColor2; 
			Dummy = aDummy; 
			
			//all
			ClipMin = aClipMin; 
			ClipMax = aClipMax; //Todo: culling in geometry shader
		} //just shovels the data through
		
		@geometry: ////////////////////////////////////////////////////////////////////////
		#define MaxArrowVertices 12
		#define MaxCurveVertices 22
		#define TotalVertices 34
		//TotalVertices = MaxCurveVertices + MaxArrowVertices
		
		//NV GTX650 384core 1GB 128bit	 totalVertices = 39	    GL_MAX_GEOMETRY_TOTAL_OUTPUT_COMPONENTS = 1K
		//AMD R9 Fury X 4096core 4GB HBM	 totalVertices = 84	    GL_MAX_GEOMETRY_TOTAL_OUTPUT_COMPONENTS = 4K
		
		//GL_MAX_GEOMETRY_OUTPUT_VERTICES
		//GL_MAX_GEOMETRY_OUTPUT_COMPONENTS
		
		/*
			Todo: 200909 Csobi kartyajan nem megy az uj vertex attribok miatt. -> attribok tomoritese 
			-> MaxCurveRertices hardvertol fuggo szamitasa.
		*/
		layout(points) in; 
		layout(triangle_strip, max_vertices = TotalVertices) out; //Extra vertices are there for arrowheads
		
		//inputs ---------------------------------------------------------------------
		
		in uint Type[]; in vec2 A[], B[], C[], D[]; in uint Color[], Color2[], Dummy[]; in vec2 ClipMin[], ClipMax[]; 
		
		//outputs ---------------------------------------------------------------------
		   //4 gl_Position
		flat out vec4 fColor; 	    //4
		out vec2 fStipple; //type, phase:    //note: it was "varying out", but NVidia don't like it, just "out"	    // 2
		
		//glyph only
		flat out vec4 fColor2; //alpha holds special stuff	                                             // 4
		out vec2 fTexCoord; //Todo: osszevonhato lenne az fStipple-vel	                                             // 2
		
		flat out ivec2 stPos, stSize; 	//4
		flat out int stConfig, stIdx; 	//2
		flat out vec2 texelPerPixel; 	//2
		flat out float boldTexelOffset; 	//1
		flat out int fontFlags; 	//1
		flat out vec2 fClipMin, fClipMax; 	//4
			//sum = 30,   1024/30 = 34    GTX650: 1024 components max
		//uniforms ---------------------------------------------------------------------
		
		//transformation
		uniform vec2 uShift, uScale, uViewPortSize; 
		
		uniform sampler2D smpInfo; 
		
		struct SubTexInfo {
			ivec2 pos, size; 
			int megaTexIdx; 
			int config; 
		}; 
		
		SubTexInfo decodeSubTexInfo(in vec4 p[2])
		{
			/*
				uint, "cellX",	 14,	     uint, "texIdx_lo", 2,
							uint, "cellY",	 14,	     uint, "texIdx_hi", 2,
							uint, "width1",	 14,	     uint, "texChn_lo", 2,
							uint, "height1",	 14,	     uint, "texChn_hi", 2 
			*/
			
			SubTexInfo info; 
			ivec4 i1 = ivec4(round(p[0]*255.0)); 
			ivec4 i2 = ivec4(round(p[1]*255.0)); 
			
			/*
				int[4] tmp = { i1.x + (i1.y<<8), i1.z + (i1.w<<8),
															 i2.x + (i2.y<<8), i2.z + (i2.w<<8) };
			*/ 
			//NV error: error C7549: OpenGL does not allow C style initializers
			int[4] tmp = int[4](
				i1.x + (i1.y<<8), i1.z + (i1.w<<8),
							i2.x + (i2.y<<8), i2.z + (i2.w<<8) 
			); 
			
			info.pos.x	= fetchBits(tmp[0], 14)<<SubTexCellBits; 
			info.pos.y	= fetchBits(tmp[1], 14)<<SubTexCellBits; 
			info.size.x	= fetchBits(tmp[2], 14)+1; 
			info.size.y	= fetchBits(tmp[3], 14)+1; 
			
			info.megaTexIdx	= tmp[0] + (tmp[1]<<2); 
			info.config	= tmp[2] + (tmp[3]<<2); 
			
			return info; 
		} 
		
		SubTexInfo fetchSubTexInfo(uint subTexIdx)
		{
			uint infoTexWidth = uint(textureSize(smpInfo, 0).x); 
			ivec2 infoTexCoord = ivec2((subTexIdx<<1)%infoTexWidth, (subTexIdx<<1)/infoTexWidth); 
			
			vec4[2] subTexInfoRaw; 
			subTexInfoRaw[0] = texelFetch(smpInfo, infoTexCoord, 0); 
			infoTexCoord.x += 1; 
			subTexInfoRaw[1] = texelFetch(smpInfo, infoTexCoord, 0); 
			
			return decodeSubTexInfo(subTexInfoRaw); 
		} 
		
		void emitSubTexInfo(SubTexInfo info)
		{
			stIdx	= info.megaTexIdx; 
			stConfig	= info.config	; 
			stPos	= info.pos	; 
			stSize	= info.size	; 
		} 
		
		//common math stuff
		float clamp(float a, float mi, float ma)
		{ return min(max(a, mi), ma); } 
		vec2 rot90(vec2 p)
		{ return vec2(-p.y, p.x); } 
		
		float split(inout float value, in float range)
		{
			float tmp = value*(1.0/range); 
			float outp = fract(tmp)*range; 
			value = floor(tmp); 
			return outp; 
		} 
		
		//Transforms into screenSpace. uScale means the pixelsize.
		vec2 trans(vec2 p)
		{ return (p+uShift)*uScale; } 
		vec2 invTrans(vec2 p)
		{ return (p/uScale)-uShift; } 
		//Transforms into normalized view coordinates for opengl.
		vec2 finalTrans(vec2 p)
		{ return p/(uViewPortSize)*vec2(2,-2); } 
		
		//calculates halfCircle subdivision count
		float calcSegCnt(float radius, int maxVerts)
		{ return clamp(round(radius/3.0+2.0), 2.0, maxVerts/2.0-2.0); } 
		
		//calculates halfSize vector from a float. Uses screenPixel based size when the input is negative.
		vec2 calcRadius(float size)
		{
			vec2 res = (size>=0) 	? uScale*size
				: -vec2(size, size); 
			return res*0.5; 
		} 
		float calcHalfSize(float size)
		{
			vec2 r = calcRadius(size); 
			return mix(r.x, r.y, 0.5); 
		} 
		
		
		//emits a vertex. Uses screen coords
		void emit(vec2 p)
		{ gl_Position = vec4(finalTrans(p), 0, 1.0);  EmitVertex(); } 
		void emit(float x, float y)
		{ emit(vec2(x, y)); } 
		
		void emitTex(vec2 p, vec2 t)
		{ gl_Position = vec4(finalTrans(p), 0, 1.0); fTexCoord = t;  EmitVertex(); } 
		
		//emits a rectangle using halfWidth and halfHeight
		void emitBlock(vec2 p, float xs, float ys)
		{
			emit(p.x+xs, p.y-ys); 
			emit(p.x-xs, p.y-ys); 
			emit(p.x+xs, p.y+ys); 
			emit(p.x-xs, p.y+ys); 
		} 
		void emitBlock(vec2 p, vec2 halfSize)
		{ emitBlock(p, halfSize.x, halfSize.y); } 
		
		void emitRect(vec2 a, vec2 b)
		{
			emit(a.x, a.y); 
			emit(a.x, b.y); 
			emit(b.x, a.y); 
			emit(b.x, b.y); 
		} 
		
		void emitGlyph(vec2 a, vec2 b, vec2 ta, vec2 tb)
		{
			const float gap0 = 0; 
			const float gap1 = 0; 
			emitTex(vec2(a.x, a.y), vec2(ta.x+gap0, ta.y+gap0)); 
			emitTex(vec2(a.x, b.y), vec2(ta.x+gap0, tb.y-gap1)); 
			emitTex(vec2(b.x, a.y), vec2(tb.x-gap1, ta.y+gap0)); 
			emitTex(vec2(b.x, b.y), vec2(tb.x-gap1, tb.y-gap1)); 
		} 
		
		void emitTriangle(vec2 a, vec2 b, vec2 c)
		{ emit(a); emit(b); emit(c); } 
		
		//emits an ellipse. 2 axes are vert and horz only.
		void emitEllipse(vec2 p, vec2 radius, int maxVerts)
		{
			float minRadius = min(radius.x, radius.y); 
			if(minRadius>0.75)
			{
				float 	segCnt	= calcSegCnt(minRadius, maxVerts),
					incr	= 1/segCnt; 
				emit(p.x, p.y+radius.y); 
				for(float i=1; i<segCnt; i += 1.0) {
					float 	ph = i*incr*3.14159265,
						xa = sin(ph)*radius.x,
						ya = cos(ph)*radius.y; 
					emit(p.x+xa, p.y+ya); 
					emit(p.x-xa, p.y+ya); 
				}
				emit(p.x, p.y-radius.y); 
			}
			else
			{
				 //simple block
				emitBlock(p, radius); 
			}
			EndPrimitive(); 
		} 
		void emitCircle(vec2 p, float radius, int maxVerts)
		{ emitEllipse(p, vec2(radius, radius), maxVerts); } 
		
		void EmitTrapezoid(vec2 p0, vec2 p1, vec2 s0, vec2 s1)
		{
			//p0
			///--|--\   --> s0
			///   |   \        
			///----|----\ ----> s1
			//p1
			/*
				Todo: DIDE this comment should not convert tabs to spaces.
				There should be an option to make ascii art in comments.
			*/
			emit(p0-s0); 	 emit(p0+s0); 
			emit(p1-s1); 	 emit(p1+s1); 
			EndPrimitive(); 
		} 
		
		
		void emitLine(vec2 u0, vec2 u1, float lineWidth, float stipple, int maxVerts, float arrowStyle)
		{
			float halfWidth = calcHalfSize(lineWidth); 
			vec2 p0 = trans(u0),  p1 = trans(u1); 
			
			if(p0==p1) p1.x += halfWidth*0.01; //failsafe: adjust 0 length line
			
			fStipple.x = stipple; 
			
			vec2 	dir = normalize(p1-p0),
				absDir = abs(dir.x)>abs(dir.y) ? vec2(1,0) : vec2(0,1),
				hdir = dir*halfWidth,
				hside = rot90(hdir),
				stippleDir = lineWidth<0 	? absDir/(halfWidth*2)
					: absDir/lineWidth; 
			
			float segCnt = halfWidth<0.75 	? 1 //simple line, like a rectangle
				: calcSegCnt(halfWidth, maxVerts), incr = 1/segCnt; 
			for(float i=0; i<=segCnt; i += 1.0)
			{
				float 	ph 	= i*incr*3.14159265,
					xa	= sin(ph),
					ya	= cos(ph); vec2 	sside 	= hside*ya,
					sdir	= hdir*xa,
					q0	= p0-sdir+sside,
					q1	= p1+sdir+sside; 
				fStipple.y = dot(lineWidth<0 ? q0-uScale*uShift : invTrans(q0), stippleDir); emit(q0); 
				fStipple.y = dot(lineWidth<0 ? q1-uScale*uShift : invTrans(q1), stippleDir); emit(q1); 
			}
			EndPrimitive(); 
			
			//Draw optional ArrowHeads
			if(arrowStyle!=0)
			{
				
				fStipple.x = 0; //disable line stipple
				
				vec2 arrowSize = vec2(8.0, 2.5); 
				vec2 	pc	= (p1+p0)*0.5,
					fwd	= hdir *2*arrowSize.x,
					side 	= hside*2*arrowSize.y; 
				
				float arrowHead	= split(arrowStyle, 4.0); 
				float arrowTail	= split(arrowStyle, 4.0); 
				float centerNormal	= split(arrowStyle, 4.0); 
				
				if(arrowTail==1.0)	EmitTrapezoid(p0+fwd, p0	, -side, -hside); 
				else if(arrowTail==2.0)	EmitTrapezoid(p0+side,	p0-side, hdir,  hdir); 
				
				if(arrowHead==1.0)	EmitTrapezoid(p1-fwd, p1	, side, hside); 
				else if(arrowHead==2.0)	EmitTrapezoid(p1+side,	p1-side, hdir, hdir); 
				
				if(centerNormal==1.0)	EmitTrapezoid(pc     , pc-side, hdir, hdir); 
				else if(centerNormal==2.0)	EmitTrapezoid(pc+side, pc     , hdir, hdir); 
				else if(centerNormal==3.0)	EmitTrapezoid(pc+side, pc-side, hdir, hdir); 
			}
			
		} 
		
		vec2 evalBezier2(vec2 A, vec2 B, vec2 C, float t)
		{ return mix(mix(A, B, t), mix(B, C, t), t); } 
		
		void emitBezier2(vec2 A, vec2 B, vec2 C,float lineWidth, int maxVerts)
		{
			float halfWidth = calcHalfSize(lineWidth); 
			float tStep = 1.0/(maxVerts/2-1); 
			float t = 0.0; 
			vec2 lastPos = A - (evalBezier2(A, B, C, tStep) - A); //mirror the first step backwards
			
			for(int i = 0; i<maxVerts/2; i++, t += tStep)
			{
				vec2 pos = evalBezier2(A, B, C, t); 
				vec2 dir = normalize(pos-lastPos); 
				lastPos = pos; 
				
				vec2 hSide = rot90(dir)*halfWidth; 
				
				emit(pos-hSide); emit(pos+hSide); 
			}
			
			EndPrimitive(); 
		} 
		
		void oldMain()
		{
			//bit 0 must be 1!!!
			uint type = Type[0]>>1&7U; 
			uint param = Type[0]>>4; 
			
			fColor = uint_to_vec4(Color[0]); 
			fStipple = vec2(0, 0); 
			boldTexelOffset = 0; 
			fontFlags = 0; 
			fClipMin = trans(ClipMin[0]) + uViewPortSize*0.5; 
			fClipMax = trans(ClipMax[0]) + uViewPortSize*0.5; 
			
			if(type==1U)
			{
				//Point
				emitEllipse(trans(A[0]), calcRadius(C[0].x), MaxCurveVertices); 
			}
			else if(type==2U)
			{
				//Point2
				emitEllipse(trans(A[0]), calcRadius(C[0].x), MaxCurveVertices/2); 
				emitEllipse(trans(B[0]), calcRadius(C[0].y), MaxCurveVertices/2); 
			}
			else if(type==3U/*type>=3 && type<=3+63*/)
			{
				//Line
				emitLine(A[0], B[0], C[0].x/*lineWidth*/, C[0].y/*stipple*/, MaxCurveVertices, param); 
			}
			else if(type==4U/*67*/)
			{
				//Filled rect
				emitRect(trans(A[0]), trans(B[0])); 
			}
			else if(type==5U/*68*/)
			{
				//Triangle
				emitTriangle(trans(A[0]), trans(B[0]), trans(C[0])); 
			}
			else if(type==6U/*69*/)
			{
				//Bezier 2nd order
				emitBezier2(trans(A[0]), trans(B[0]), trans(C[0]), D[0].x/*lineWidth*/, MaxCurveVertices); 
			}
			else if(type==7U/*type>=256 && type<256+0x10000*/)
			{
				//glyph rect geom shader////////////////////////////////
				fontFlags = int(floor(C[0].x)); 
				
				fColor2 = uint_to_vec4(Color2[0]); 
				
				SubTexInfo info = fetchSubTexInfo(param); 
				emitSubTexInfo(info); 
				
				//texture coordinates (non-normalized)  //adjust to the textel centers
				vec2 t0 = info.pos + vec2(.5); 
				vec2 t1 = info.pos + info.size - vec2(.5); 
				
				{
					//ySubRange   D.x, D.y -> Top..Bottom 0..1 range.  Only for fonts.
					float new_t0y = mix(t0.y, t1.y, D[0].x); 
					float new_t1y = mix(t0.y, t1.y, D[0].y); 
					t0.y = new_t0y; 
					t1.y = new_t1y; 
				}
				
				//enlarge for boldness
				bool isBold = (fontFlags & 16)==0 && (fontFlags & 1)!=0; 
				if(isBold) {
					float o = info.size.y*BoldOffset; 
					boldTexelOffset = o; 
					
					o *= 3; //cleartype
					t0.x -= o; t1.x += o; 
				}
				
				//transform to screenPixelSpace
				vec2 tA = trans(A[0]), tB = trans(B[0]); 
				
				//calculate pixel size on the texture
				texelPerPixel = (t1-t0)/(tB-tA); 
				
				emitGlyph(tA, tB, t0, t1); 
			}
		} 
		
		uint stream_getDw(uint ui)
		{
			int i = int(ui); 
			//in uint Type[]; in vec2 A[], B[], C[], D[]; in uint Color[], Color2[]; in vec2 ClipMin[], ClipMax[]; 
			if(i<8)	{
				if(i< 4)	{
					if(i< 2)	{
						return i==0 	? Type[0]
							: floatBitsToUint(A[0].x); 
					}
					else	{
						return i==2 	? floatBitsToUint(A[0].y)
							: floatBitsToUint(B[0].x); 
					}
				}
				else	{
					if(i< 6)	{
						return i==4 	? floatBitsToUint(B[0].y)
							: floatBitsToUint(C[0].x); 
					}
					else	{
						return i==6 	? floatBitsToUint(C[0].y)
							: floatBitsToUint(D[0].x); 
					}
				}
			}
			else	{
				if(i<12)	{
					if(i<10)	{
						return i==8 	? floatBitsToUint(D[0].y)
							: Color[0]; 
					}
					else	{
						return i==10 	? Color2[0]
							: Dummy[0]; 
					}
				}
				else	{
					if(i<14)	{
						return i==12 	? floatBitsToUint(ClipMin[0].x)
							: floatBitsToUint(ClipMin[0].y); 
					}
					else	{
						return i==14 	? floatBitsToUint(ClipMax[0].x)
							: floatBitsToUint(ClipMax[0].y); 
					}
				}
			}
		} 
		
		uint streamDwIdx, streamActDw, streamActBits; 
		bool streamOverflow; 
		
		void stream_init()
		{
			streamDwIdx = 0u; 
			streamActBits = 0u; 
			streamOverflow = false; 
		} 
		
		void stream_internalFetchDw()
		{
			streamOverflow  = streamDwIdx>=16u; 
			if(streamOverflow) return; 
			streamActDw = stream_getDw(streamDwIdx); 
			streamDwIdx ++; 
		} 
		
		uint stream_fetchBits(uint bits)
		{
			if(bits==0u) return 0u; 
			
			if(streamActBits==0u) stream_internalFetchDw(); 
			if(streamOverflow) return 0u; 
			
			if(bits<=streamActBits)
			{
				uint res = streamActDw & ((1u<<bits)-1u); 
				streamActDw >>= bits; 
				streamActBits -= bits; 
				return res; 
			}
			
			uint res = streamActDw; 
			bits -= streamActBits; 
			uint sh = streamActBits; 
			streamActBits = 0u; 
			stream_internalFetchDw(); 
			if(streamOverflow) return 0u; 
			
			res |= (streamActDw & ((1u<<bits)-1u))<<sh; 
			streamActDw >>= bits; 
			streamActBits -= bits; 
			
			return res; 
		} 
		
		uint stream_fetchUint()
		{ return stream_fetchBits(32u); } 
		
		float stream_fetchFloat()
		{ return uintBitsToFloat(stream_fetchBits(32u)); } 
		
		vec2 stream_fetchVec2()
		{ return vec2(stream_fetchFloat(), stream_fetchFloat()); } 
		
		
		void main()
		{
			#define T_oldCommand 1u
			//losing this bit to the old format
			
			/*
				
				# - bytestream size
				
				bit 0:	 oldCommand
				bit 1:	 absolute position format: 
						0: vec2	#8
						1: uint_tileIndex + vec2 	#12
				bit 2..3:	 relative position format:
						0: vec2	#8
						1: short2              	#4
						2: -
						3: -
				bit 4..5:	 relative scale format:
						0: 1x
						1: 0.625x
						2: 0.001x
						3: float               	#4
				bit 6:	 clipping:
						0: disabled
						1: bounds2
				bit 5..7	 primary color format
						0: black
						1: white
						2: R
						3: G
						4: B
						5: Y
						6: RGB
						7: RGBA
				
				bit 6..7:	 primitive type
						0: strip   width is the first relative coord
			*/
			
			uint T = Type[0]; 
			if((T&T_oldCommand)!=0u)
			{ oldMain(); }
			else
			{
				fColor = vec4(1, 1, 1, 1); 
				fColor2 = vec4(0, 0, 0, 1); 
				
				fStipple = vec2(0, 0); 
				boldTexelOffset = 0; fontFlags = 0; 
				fClipMin = vec2(-1e30); 
				fClipMax = vec2(+1e30); 
				
				
				fColor = vec4(1, 0, .5, .5); 
				fColor2 = fColor; 
				emitRect(trans(vec2(0, 0)), trans(vec2(20, 10))); 
			}
		} 
		
		@fragment: 
		layout(origin_upper_left) in vec4 gl_FragCoord; 
		
		flat in vec4 fColor; 
		in vec2 fStipple; //type, phase
		
		//glyph only
		in vec2 fTexCoord; 
		flat in vec4 fColor2; //
		
		//subTexture
		flat in ivec2 stPos, stSize; 
		flat in int stConfig, stIdx; 
		
		flat in vec2 texelPerPixel; 
		flat in float boldTexelOffset; 
		flat in int fontFlags; 
		
		flat in vec2 fClipMin, fClipMax; 
		
		out vec4 FragColor; //NV compatibility: gl_FragColor is deprecated
		
		uniform sampler2D smpMega[MegaTexMaxCnt]; 
		
		//customShader global input variables
		uniform float	GF0, GF1, GF2, GF3, GF4, GF5, GF6, GF7; 
		uniform bool	GB0, GB1, GB2, GB3, GB4, GB5, GB6, GB7; 
		
		uniform float appRunningTime_sec; 
		
		//Todo: replace these with samplerEffect enum
		bool enableQuadEffect; //display the RGBA channels separatedly
		bool enableKarcEffect; //Karc sample visualization effect
		
		
		vec4 megaSample_nearest_internal(vec2 tc)
		{
			//if(stIdx!=0) return vec4(1, 0, 1, 1); //return fuschia for multitexturing
			
			int quadIdx; 
			if(enableQuadEffect)
			{
				quadIdx = 0; 
				tc = (tc-stPos)*2; 
				if(tc.x>=stSize.x) { tc.x -= stSize.x; quadIdx |= 1; }
				if(tc.y>=stSize.y) { tc.y -= stSize.y; quadIdx |= 2; }
				tc += stPos; 
			}
			
			ivec2 itc = ivec2(floor(tc)); 
			
			bool outside = 	itc.x<stPos.x || itc.x>=stPos.x+stSize.x ||
				itc.y<stPos.y || itc.y>=stPos.y+stSize.y; 
			
			itc.x = clamp(itc.x, stPos.x, stPos.x+stSize.x-1); 
			itc.y = clamp(itc.y, stPos.y, stPos.y+stSize.y-1); 
			
			vec4 t = texelFetch(smpMega[stIdx], itc, 0); 
			if(outside) t = vec4(0); 
			
			if(stConfig==0) t.yzw = t.xxx; //spread 1 channel to 4ch
			
			if(enableQuadEffect)
			{
				switch(quadIdx)
				{
					case 0: t.rgb = t.rrr; break; 
					case 1: t.rgb = t.ggg; break; 
					case 2: t.rgb = t.bbb; break; 
					default: t.rgb = t.aaa; 
				}
				t.a = 1; 
			}
			else if(enableKarcEffect)
			{
				//Todo: This is way too karc specific
				float y = t.g,  u = t.r,  v = t.b,  a = t.a; 
				
				float 	errorVisibility 	= 1, 
					maskVisibility 	= 1; u *= errorVisibility,
				v *= maskVisibility; 
				
				t.rgb =	vec3(y)
					+errorVisibility*vec3(u, -(u+v)/2, v)
					+maskVisibility*(-y*(1-a))*vec3(1, 0, 1); 
				t.a = 1; 
			}
			
			
			return t; 
			
			/*
				vec4 t; //this is the proper way to fetch multitexturing
							for(int i=0; i<=stIdx; i++) t += texelFetch(smpMega[i], itc, 0)*(i==stIdx ? 1 : 0);
							return t;
			*/
		} 
		
		bool hline(float tcy, float pos, float thickness)
		{
			float base = stPos.y + stSize.y*pos; 
			float h = stSize.y*thickness; 
			
			return (tcy>base && tcy<base+h); 
		} 
		
		vec2 calcNearestTc(vec2 tc)
		{
			/*
				sampling forrection for nearest filtering:
				linear: the coords on the edge must fall into the center of the textels.
				nearest: the coords on the edge must fall into the very edge the textels.
			*/
			
			tc -= 0.5; tc -= stPos; tc /= stSize-1; tc *= stSize; tc += stPos; 
			return tc; 
		} 
		
		vec2 calcLinearTc(vec2 tc)
		{
			tc -= 0.5; 
			return tc; 
		} 
		
		//Todo: megatexture error: Maybe it's a fix: wiki glsl samples Non-uniform flow control !!!!!
		
		vec4 megaSample_nearest(vec2 tc)
		{
			vec4 center = megaSample_nearest_internal(tc); 
			if(boldTexelOffset>0)
			{
				//maximize 4 diagonal alpha's
				vec2 d = vec2(boldTexelOffset*3, boldTexelOffset)*0.71; 
				vec2 e = vec2(d.x, -d.y); 
				float a = max(
					max(megaSample_nearest_internal(tc+d).a, megaSample_nearest_internal(tc-d).a),
					max(megaSample_nearest_internal(tc+e).a, megaSample_nearest_internal(tc-e).a)
				); 
				center.a = max(center.a, a); 
			}
			
			//underline, strikeout
			if((fontFlags&16)==0)
			{
				if(
					((fontFlags&4)!=0) && hline(tc.y, 0.875, 0.075) ||
					((fontFlags&8)!=0) && hline(tc.y, 0.48, 0.075)
				) center = vec4(0,0,0,1); 
			}
			
			return center; 
		} 
		
		vec4 megaSample_linear(vec2 tc)
		{
			ivec2	itc = ivec2(floor(tc)); 
			vec2	ftc = fract(tc); 
			
			vec4 a = mix(megaSample_nearest(itc+ivec2(0,0)), megaSample_nearest(itc+ivec2(1,0)), ftc.x); 
			vec4 b = mix(megaSample_nearest(itc+ivec2(0,1)), megaSample_nearest(itc+ivec2(1,1)), ftc.x); 
			
			return mix(a, b, ftc.y); 
		} 
		
		//texture coordinates for rooks 6
		vec2 tc6(in vec2 tc, float x, float y)
		{ return tc+vec2(texelPerPixel.x, texelPerPixel.y)*(vec2(x-2.5, y-2.5)*(1.0/6.0)); } 
		
		vec4 megaSample_rooks6(in vec2 tc)
		{
			vec4 texel = 	megaSample_nearest(tc6(tc,0,4))+
				megaSample_nearest(tc6(tc,1,0))+
				megaSample_nearest(tc6(tc,2,2))+
				megaSample_nearest(tc6(tc,3,3))+
				megaSample_nearest(tc6(tc,4,5))+
				megaSample_nearest(tc6(tc,5,1)); 
			
			return texel*(1.0/6); 
		} 
		
		void megaSample_clearType(in vec2 tc, out vec3 color, out float[3] alpha)
		{
			vec4[7] s; 
			s[0] = megaSample_nearest(tc6(tc,-4,2)); 
			s[1] = megaSample_nearest(tc6(tc,-2,3)); 
			s[2] = megaSample_nearest(tc6(tc, 0,2)); 
			s[3] = megaSample_nearest(tc6(tc, 2,3)); 
			s[4] = megaSample_nearest(tc6(tc, 4,2)); 
			s[5] = megaSample_nearest(tc6(tc, 6,3)); 
			s[6] = megaSample_nearest(tc6(tc, 8,2)); 
			
			for(int i=0; i<3;	i++) {
				alpha[i] = 	+s[i  ].a*0.08
					+s[i+1].a*0.25
					+s[i+2].a*0.34
					+s[i+3].a*0.25
					+s[i+4].a*0.08; 
			}
			
			color = (s[2].rgb+s[3].rgb+s[4].rgb)*0.3333333; 
		} 
		
		vec4 clearTypeMix(vec4 c0, vec4 c1, float[3] alpha)
		{
			return vec4(
				mix(c0.r, c1.r, alpha[0]),
				mix(c0.g, c1.g, alpha[1]),
				mix(c0.b, c1.b, alpha[2]),
				mix(c0.a, c1.a, (alpha[0]+alpha[1]+alpha[2])*(1.0/3)) 
			); 
		} 
		
		
		vec4 megaTexIdxColor()
		{
			vec3 c; 
			if(stIdx==0) c = vec3(1, 0, 0); 
			else if(stIdx==1) c = vec3(1, 1, 0); 
			else if(stIdx==2) c = vec3(0, 1, 0); 
			else if(stIdx==3) c = vec3(0, 1, 1); 
			return vec4(c, 1); 
		} 
		
		bool chkClip(in vec2 mi, in vec2 ma)
		{
			return 	gl_FragCoord.x>ma.x || gl_FragCoord.x<mi.x || 
				gl_FragCoord.y>ma.y || gl_FragCoord.y<mi.y; 
		} 
		
		vec4 applyBorder(vec4 color, vec2 tc, float borderWidth)
		{
			if(borderWidth<=0) return color; 
			
			ivec2 itc = ivec2(floor(tc)); 
			float borderDist = min(
				min(abs(tc.x-(stPos.x-boldTexelOffset*2.6)), abs(tc.x-(stPos.x+stSize.x+boldTexelOffset*2.6))) ,
				min(abs(tc.y-stPos.y)                    , abs(tc.y-(stPos.y+stSize.y))) 
			); 
			
			return mix(color, vec4(0.5, 0.5, 0.5, 1), (1-smoothstep(-borderWidth, borderWidth, borderDist))*0.5); 
		} 
		
		//global variables for default and custom shader
		vec4 bkColor, fontColor; 
		vec2 tc; 
		
		bool isImage, isFont, isItalic; 
		
		/*image	only*/ bool isCustomShader;  int customShaderIdx; 
		/*font	only*/ bool isTransparent; 
		
		
		vec4 defaultShader()
		{
			vec4 finalColor, texel; 
			
			//italic
			if(isFont && isItalic) {
				float dy = tc.y-(stPos.y+stSize.y*0.5); 
				tc.x += dy*0.5; //Bug: it alters tc!!!
			}
			
			//samplingLevel : 0 = nearest, 1 = linear, 2 = rooks6, 3 = cleartype
			int samplingLevel = 0; 
			float L = length(texelPerPixel); 
			if(isImage) {
				if(L<=2) samplingLevel = fontFlags & 1; 
				else
				samplingLevel = 2; 
				
			}
			else {
				samplingLevel = 	L>32 ? 	2: //minify
					L< 1 ? 	1: //magnify
					(isTransparent ? 2 : 3/*cleartype*/)/*medium zoom*/; 
			}
			
			if(samplingLevel==-1)
			{
				 //debug
				finalColor = vec4(1,0,1,1); 
			}
			else if(samplingLevel==0 || samplingLevel==1)
			{
				//nearest, linear
				
				if(samplingLevel==0) texel = megaSample_nearest(calcNearestTc(tc)); 
				else texel = megaSample_linear(calcLinearTc(tc)); 
				
				if(stConfig==8)	finalColor = vec4(texel.rgb, fontColor.a); 
				else if(stConfig==12)
				finalColor = isTransparent 	? vec4(texel.rgb, texel.a)
					: mix(bkColor, vec4(texel.rgb, fontColor.a), texel.a); 
				else if(stConfig==0)
				{
					if(isImage) finalColor = vec4(texel.rrr, 1); 
					else
					finalColor = isTransparent 	? vec4(fontColor.rgb, texel.a)
						: mix(bkColor, fontColor, texel.a); 
					 //fonts interpolate the 2 colors
				}
				
				/*
					if(stConfig==0) finalColor = vec4(.5, 0, 0, 1);
					else if(stConfig==8) finalColor = vec4(0, 1, 0, 1);
					else if(stConfig==12) finalColor = vec4(0, 0, 1, 1);
					else finalColor = vec4(.5, .5, .5, 1);
				*/
				
				//experimental grid
				/*
					it's broken if(fontFlags&2) if(texelPerPixel.x < 0.1){
						if(fract(tc).x<0.1 && fract(tc).y<0.1) finalColor = vec4(0, 0, 0, 0.5);
					}
				*/
			}
			else if(samplingLevel==2)
			{
				//rooks6
				vec4 texel = megaSample_rooks6(tc); 
				if(stConfig==8) finalColor = vec4(texel.rgb, fontColor.a);  //wtf is this????
				if(stConfig==12)
				finalColor = isTransparent 	? vec4(texel.rgb, texel.a)
					: mix(bkColor, vec4(texel.rgb, fontColor.a), texel.a); 
				else if(stConfig==0)
				finalColor = isTransparent 	? vec4(fontColor.rgb, texel.a)
					: mix(bkColor, fontColor, texel.a); 
				 //FONT
			}
			else
			{
				 //clearType
				vec3 smp; float[3] alpha; 
				megaSample_clearType(tc, smp, alpha); 
				
				if(stConfig==12) finalColor = clearTypeMix(bkColor, vec4(smp, fontColor.a), alpha); 
				else if(stConfig==0) finalColor = clearTypeMix(bkColor, fontColor             , alpha); //FONT
			}
			
			return finalColor; 
		} 
		
		vec4 customShader() { return vec4(((int(tc.x)^int(tc.y))&255)/255.0 * vec3(1, 0, 1), 1); } 
		//Note: ^^^^^^^^^^	this SINGLE(!) line marks the place of the custom shader
		
		void main()
		{
			if(chkClip(fClipMin, fClipMax)) discard; //I think this is not subpixel accurate
			
			if(fColor2.w==0)
			{
				 //plain color stuff
				
				vec4 color = fColor; 
				
				//stipple
				float stippleType = fStipple.x; 
				if(stippleType!=0)
				{
					float a = 0; 
					
					stippleType = stippleType/16; 
					float mask = fract(stippleType)*16; 
					float scale = floor(stippleType); 
					
					float phase = fract(fStipple.y/(pow(2,scale+2.6)) + fract(appRunningTime_sec*2.1))*6; 
					
					//this is crazy and not having the docs for it.
					mask /= 2; 	 if(fract(mask)>0) { if(phase<1 || phase>=2 && phase<3) a = 1; mask -= 0.5; }
					mask /= 2; 	 if(fract(mask)>0) { if(phase>=1 && phase<2) a = 1; mask -= 0.5; }
					mask /= 2; 	 if(fract(mask)>0) { if(phase>=3 && phase<4) a = 1; mask -= 0.5; }
					mask /= 2; 	 if(fract(mask)>0) { if(phase>=4 && phase<5) a = 1; mask -= 0.5; }
					
					color.a *= a; 
				}
				
				FragColor = color; 
				
			}
			else
			{
				 //!----------------> glyph fragment shader /////////////////////////////
				
				//initialize global variables
				bkColor = fColor2; 
				fontColor = fColor; 
				
				tc = fTexCoord; 
				
				isImage = (fontFlags&16)!=0; 
				isFont = !isImage; 
				isItalic = (fontFlags&2)!=0; 
				
				//decode image or font specific flags
				isCustomShader = false; 
				customShaderIdx = 0; 
				isTransparent = false; 
				
				int samplerEffect = (fontFlags>>16)&3; 
				enableQuadEffect = samplerEffect==1; 
				enableKarcEffect = samplerEffect==2; 
				
				if(isFont) { isTransparent = (fontFlags&32)!=0; }
				else {
					isCustomShader = (fontFlags&32)!=0; 
					customShaderIdx = (fontFlags/64)/*&7*/; 
				}
				
				if(!isCustomShader) {
					//default shader for images and text
					FragColor = defaultShader(); 
				}
				else {
					 //customShader
					FragColor = customShader(); 
				}
				
			}
		} 
		
		
		//Todo: megaTexMaxCount-ot meg a tobbi konstanst kivulrol szedni
		//Todo: arrowless curves could use max vertices
		//Todo: arrows -> triangles instead of trapezoids
		//Todo: arrows: no curcature needed
		//Todo: compress geom shader output size
		
		
	}; 
	
} 