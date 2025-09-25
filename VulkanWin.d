module vulkanwin; 

version(/+$DIDE_REGION+/all)
{
	
	public import het.win, het.bitmap, het.vulkan; 
	
	import core.stdc.string : memset; 
	
	enum GSP_DefaultFontHeight = 18; 
	
	
	//global references initialized by main Vulkan Window
	__gshared VulkanWindow mainVulkanWindow; //this is how textures can be created outside mainWindow
	private __gshared FontFaceManager g_fontFaceManager; 
	
	alias Texture = VulkanWindow.Texture; 
	
	
	enum bugFix_LastTwoGeometryShaderStreamsMissing = (常!(bool)(1))
	/+
		Todo: It happens with the Windows default driver.
		Try this with new drivers! (official and radeon-ID)
	+/; 
	
	/+
		Code: (表([
			[q{/+Note: Limits/Cards+/},q{/+Note: MAX+/},q{/+Note: R9 Fury X+/},q{/+Note: R9 280+/},q{/+Note: GTX 1060+/},q{/+Note: RX 580+/},q{/+Note: RTX 5090+/},q{/+Note: RX 9070+/}],
			[q{maxPushConstantsSize},q{128},q{256},q{128},q{256},q{256},q{256},q{256}],
			[q{maxVertexInputAttributes},q{32},q{32},q{64},q{32},q{32},q{32},q{64}],
			[q{maxGeometryInputComponents},q{64},q{64},q{128},q{128},q{64},q{128},q{128}],
			[q{maxGeometryOutputComponents},q{128},q{128},q{128},q{128},q{128},q{128},q{128}],
			[q{maxGeometryOutputVertices},q{256},q{1024},q{1024},q{1024},q{256},q{1024},q{256}],
			[q{maxGeometryTotalOutputComponents},q{1024},q{
				16384
				/*bug?!!*/
			},q{
				16384
				/*bug?!!*/
			},q{1024},q{1024},q{1024},q{1024}],
			[q{maxGeometryShaderInvocations},q{32},q{127},q{127},q{32},q{32},q{32},q{32}],
			[q{maxFragmentInputComponents},q{128},q{128},q{128},q{128},q{128},q{128},q{128}],
		]))
	+/
	
	struct BezierTesselationSettings
	{
		enum Mode { points, lines, perPixel } 
		Mode mode; 
		int quadraticSegments, cubicSegments; 
		
		int estimateVertexCount(char cmd_) const
		{
			const cmd = cmd_.toAsciiUpper; 
			const order = cmd.predSwitch(
				'M', 1, /+only 0 if there are more adjacent 2 moves+/
				'L', 1, 
				'Q', 2, 'T', 2, 
				'C', 3, 'S', 3, 'A', 3, 
				0
			); 
			if(!order) return 0; 
			
			enum arcMaxParts = 4; 
			const arcScale = cmd=='A' ? arcMaxParts : 1; 
			
			final switch(mode)
			{
				case Mode.points: 	return order*4 /+4 vertices per points+/; 
				case Mode.lines: 	switch(order) {
					case 1: return 2; 
					case 2: return 2 * quadraticSegments * arcScale; 
					case 3: return 2 * cubicSegments * arcScale; 
					default: return 0; 
				}
				case Mode.perPixel: 	switch(order) {
					case 1: return 2; 
					case 2: return 2 * 2 * quadraticSegments * arcScale; 
					case 3: return 2 * 2 * cubicSegments * arcScale; 
					default: return 0; 
				}
			}
		} 
	} 
	
	alias BTSM = BezierTesselationSettings.Mode; 
	
	enum bezierTesselationSettings =
		1.predSwitch
		(
		0, mixin(體!((BezierTesselationSettings),q{
			mode 	: BTSM.perPixel,
			quadraticSegments 	: 3,
			cubicSegments	: 4
		})),
		1, mixin(體!((BezierTesselationSettings),q{
			mode 	: BTSM.lines,
			quadraticSegments 	: 6,
			cubicSegments	: 8
		})),
		2, mixin(體!((BezierTesselationSettings),q{mode : BTSM.points/+debug only+/}))
	)
		/+Todo: It is a line style property, not a system-wide constant setting+/; 
	
	
	mixin((
		(表([
			[q{/+Note: Idx+/},q{/+Note: Oct+/},q{/+Note: Hex+/},q{/+Note: Name+/},q{/+Note: Color+/}],
			[q{0},q{"\0"},q{0x0},q{black},q{(RGB(0x000000))}],
			[q{1},q{"\1"},q{0x1},q{blue},q{(RGB(0xAA0000))}],
			[q{2},q{"\2"},q{0x2},q{green},q{(RGB(0x00AA00))}],
			[q{3},q{"\3"},q{0x3},q{cyan},q{(RGB(0xAAAA00))}],
			[q{4},q{"\4"},q{0x4},q{red},q{(RGB(0x0000AA))}],
			[q{5},q{"\5"},q{0x5},q{magenta},q{(RGB(0xAA00AA))}],
			[q{6},q{"\6"},q{0x6},q{brown},q{(RGB(0x0055AA))}],
			[q{7},q{"\7"},q{0x7},q{ltGray},q{(RGB(0xAAAAAA))}],
			[q{/+Note: Idx+/},q{/+Note: Oct+/},q{/+Note: Hex+/},q{/+Note: Name+/},q{/+Note: Color+/}],
			[q{8},q{"\10"},q{0x8},q{dkGray},q{(RGB(0x555555))}],
			[q{9},q{"\11"},q{0x9},q{ltBlue},q{(RGB(0xFF5555))}],
			[q{10},q{"\12"},q{0xA},q{ltGreen},q{(RGB(0x55FF55))}],
			[q{11},q{"\13"},q{0xB},q{ltCyan},q{(RGB(0xFFFF55))}],
			[q{12},q{"\14"},q{0xC},q{ltRed},q{(RGB(0x5555FF))}],
			[q{13},q{"\15"},q{0xD},q{ltMagenta},q{(RGB(0xFF55FF))}],
			[q{14},q{"\16"},q{0xE},q{yellow},q{(RGB(0x55FFFF))}],
			[q{15},q{"\17"},q{0xF},q{white},q{(RGB(0xFFFFFF))}],
		]))
	).調!(GEN_ColorEnum!q{EGAColor})); 
	
	mixin((
		(表([
			[q{/+Note: Idx+/},q{/+Note: Oct+/},q{/+Note: Hex+/},q{/+Note: Name+/},q{/+Note: Color+/}],
			[q{0},q{"\0"},q{0x0},q{black},q{(RGB(0x000000))}],
			[q{1},q{"\1"},q{0x1},q{white},q{(RGB(0xFFFFFF))}],
			[q{2},q{"\2"},q{0x2},q{red},q{(RGB(0x2E2896))}],
			[q{3},q{"\3"},q{0x3},q{cyan},q{(RGB(0xCED65B))}],
			[q{4},q{"\4"},q{0x4},q{purple},q{(RGB(0xAD2D9F))}],
			[q{5},q{"\5"},q{0x5},q{green},q{(RGB(0x36B941))}],
			[q{6},q{"\6"},q{0x6},q{blue},q{(RGB(0xC42427))}],
			[q{7},q{"\7"},q{0x7},q{yellow},q{(RGB(0x47F3EF))}],
			[q{/+Note: Idx+/},q{/+Note: Oct+/},q{/+Note: Hex+/},q{/+Note: Name+/},q{/+Note: Color+/}],
			[q{8},q{"\10"},q{0x8},q{orange},q{(RGB(0x15489F))}],
			[q{9},q{"\11"},q{0x9},q{brown},q{(RGB(0x00355E))}],
			[q{10},q{"\12"},q{0xA},q{pink},q{(RGB(0x665FDA))}],
			[q{11},q{"\13"},q{0xB},q{dkGray},q{(RGB(0x474747))}],
			[q{12},q{"\14"},q{0xC},q{gray},q{(RGB(0x787878))}],
			[q{13},q{"\15"},q{0xD},q{ltGreen},q{(RGB(0x84FF91))}],
			[q{14},q{"\16"},q{0xE},q{ltBlue},q{(RGB(0xFF6468))}],
			[q{15},q{"\17"},q{0xF},q{ltGray},q{(RGB(0xAEAEAE))}],
		]))
	).調!(GEN_ColorEnum!q{C64Color})); 
	
	
	
	
	version(/+$DIDE_REGION Meta+/all)
	{
		mixin template GEN_GLSLBitfields(表 table, string GLSLPrefix, string GLSLReg)
		{
			struct FieldInfo { string type, name; uint bitOfs, bitCnt; bool isBool() => type=="bool"; } 
			enum _fields = std.range.zip(
				table.column!0,
				table.column!(2, unpackCString),
				0 ~ table.column!(1, "a.to!uint").cumulativeFold!"a+b".array,
				table.column!(1, "a.to!uint")
			)
			.map!((Tuple!(string, string, uint, uint) a)=>(FieldInfo(a.expand))).array; 
			
			//total bitCount
			enum bitCnt = _fields.back.bitOfs + _fields.back.bitCnt; 
			static assert(_raw.sizeof*8 >= bitCnt, i"_raw is too small for $(bitCnt) bits.".text); 
			
			//getters, setters
			static foreach(f; _fields)
			{
				mixin(iq{
					@property $(f.type) $(f.name)() const
					=> (cast($(f.type))(_raw.getBits($(f.bitOfs), $(f.bitCnt)))); 
					@property $(f.name)($(f.type) _value)
					{ _raw = _raw.setBits($(f.bitOfs), $(f.bitCnt), _value); } 
				}.text); 
				
				//_builder_ functions for Builder Pattern
				static if(f.isBool)
				{
					mixin(iq{
						@property _builder_$(f.name)(bool _value = true) const
						{ auto tmp = cast()this; tmp.$(f.name) = _value; return tmp; } 
					}.text); 
				}
				else static if(is(mixin(f.type)==enum))
				{
					static foreach(i, e; EnumMembers!(mixin(f.type)))
					static if(e)
					mixin(iq{
						@property _builder_$(EnumMemberNames!(mixin(f.type))[i])() const
						{ auto tmp = cast()this; tmp.$(f.name) = e; return tmp; } 
					}.text); 
				}
			}
			
			enum GLSLCode = _fields.map!
			((FieldInfo f) =>(((f.isBool) ?(iq{bool $(GLSLPrefix)_$(f.name)() { return getBit($(GLSLReg), $(f.bitOfs)); } }.text) :(iq{uint $(GLSLPrefix)_$(f.name)() { return getBits($(GLSLReg), $(f.bitOfs), $(f.bitCnt)); } }.text))))
			.join("\r\n"); 
		} 
		
		enum GetBuilderMethodNames(T) = [__traits(allMembers, T)]
			.filter!((a)=>(a.startsWith    ("_builder_")))
			.map!((a)=>(a.withoutStarting("_builder_"))).array; 
	}
	
	
	alias TexFormat 	= TexSizeFormat.TexFormat; 
	
	enum TexInfoFlag {
		error 	= 1,
		loading 	= 2,
		resident 	= 4
	}; alias TexInfoFlags = VkBitFlags!TexInfoFlag; 
	
	static struct TexSizeFormat
	{
		enum TexInfoBits	= 3,
		TexDimBits 	= 2, 
		TexChnBits 	= 2, 
		TexBppBits 	= 4, 
		TexInfoBitOfs	= 0,
		TexDimBitOfs	= 6,
		TexFormatBitOfs 	= 8 /+inside info_dword[0]+/,
		TexFormatBits 	= TexChnBits + TexBppBits + 1 /+alt+/; 
		
		enum TexDim {_1D, _2D, _3D} 	static assert(TexDim.max < 1<<TexDimBits); 
		
		mixin 入 !((
			(表([
				[q{/+Note: chn/bpp+/},q{/+Note: 1+/},q{/+Note: 2+/},q{/+Note: 4+/},q{/+Note: 8+/},q{/+Note: 16+/},q{/+Note: 24+/},q{/+Note: 32+/},q{/+Note: 48+/},q{/+Note: 64+/},q{/+Note: 96+/},q{/+Note: 128+/},q{/+Note: Count+/}],
				[q{/+Note: 1+/},q{
					u1
					wa_u1
				},q{
					u2
					wa_u2
				},q{
					u4
					wa_u4
				},q{
					u8
					wa_u8
				},q{
					u16
					wa_u16
				},q{},q{
					f32
					wa_f32
				},q{},q{},q{},q{},q{12}],
				[q{/+Note: 2+/},q{},q{},q{},q{},q{la_u8},q{},q{la_u16},q{},q{la_f32},q{},q{},q{3}],
				[q{/+Note: 3+/},q{},q{},q{},q{},q{
					rgb_565
					bgr_565
				},q{
					rgb_u8
					bgr_u8
				},q{},q{
					rgb_u16
					bgr_u16
				},q{},q{
					rgb_f32
					bgr_f32
				},q{},q{8}],
				[q{/+Note: 4+/},q{},q{},q{},q{},q{
					rgba_5551
					bgra_5551
				},q{},q{
					rgba_u8
					bgra_u8
				},q{},q{
					rgba_u16
					bgra_u16
				},q{},q{
					rgba_f32
					bgra_f32
				},q{8}],
				[q{/+
					Alternate modes: 	1ch 	: wa_* 	: white+alpha for fonts 
						2ch, 3ch 	: bgr* 	: red blue swap
				+/}],
			]))
		),q{
			static string GEN_TexFormat()
			{
				version(/+$DIDE_REGION Process table cells, generate types+/all)
				{
					auto 	table = _data,
						bppCount = table.width-2,
						chnCount = table.rowCount; struct Format {
						string name; 
						int value, chn, bpp; 
					} Format[] formats; 
					int chnVal(int chn) => table.headerColumnCell(chn+1).to!int; 
					int bppVal(int bpp) => table.headerCell(bpp+1).to!int; 
					void processCell(int bpp, int chn)
					{
						foreach(alt, n; table.cell(bpp+1, chn+1).split)
						formats ~= Format(n, chn | (bpp<<2) | (!!alt<<6), chnVal(chn), bppVal(bpp)); 
					} 
					foreach(bpp; 0..bppCount) foreach(chn; 0..chnCount) processCell(bpp, chn); 
				}
				
				return iq{
					enum TexFormat {$(formats.map!"a.name~`=`~a.value.text".join(','))} 
					enum TexChn {$(chnCount.iota.map!((i)=>('_'~chnVal(i).text)).join(','))} 
					enum TexBpp {$(bppCount.iota.map!((i)=>('_'~bppVal(i).text)).join(','))} 
					enum texFormatChnVals 	= [$(formats.map!q{a.chn.text}.join(','))],
					texFormatBppVals 	= [$(formats.map!q{a.bpp.text}.join(','))]; 
				}.text; 
			} 
			
			mixin(GEN_TexFormat); 
			
			static assert(TexChn.max < 1<<TexChnBits); 
			static assert(TexBpp.max < 1<<TexBppBits); 
			static assert(TexFormat.max < 1<<TexFormatBits); 
		}); 
		
		
		mixin((
			(表([
				[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
				[q{bool},q{1},q{"error"},q{},q{/+No sampling, 0xFFFF00FF color /+Todo: Error can be marked by chunkIdx=null+/+/}],
				[q{bool},q{1},q{"loading"},q{},q{/+No sampling, 0xC0C0C0C0 color+/}],
				[q{bool},q{1},q{"resident"},q{},q{/+GC will not unload it, just relocate it /+Todo: not needed on GPU+/+/}],
				[q{uint},q{3},q{"_unused1"},q{},q{/++/}],
				[q{TexDim},q{2},q{"dim"},q{},q{/++/}],
				[],
				[q{TexChn},q{2},q{"chn"},q{},q{/+channels (0: 1ch, ..., 3: 4ch)+/}],
				[q{TexBpp},q{4},q{"bpp"},q{},q{/+bits per pixel (enum)+/}],
				[q{bool},q{1},q{"alt"},q{},q{/+alternate mode: 1ch: white_alpha, 3ch, 4ch: swapRB+/}],
				[q{uint},q{1},q{"_unused2"},q{},q{/++/}],
				[],
				[q{uint},q{16},q{"_rawSize0"},q{},q{/++/}],
				[q{uint},q{32},q{"_rawSize12"},q{},q{/++/}],
			]))
		).調!(GEN_bitfields)); 
		
		@property format() const => (cast(TexFormat)((*(cast(ulong*)(&this))).getBits(TexFormatBitOfs, TexFormatBits))); 
		@property format(TexFormat t) { auto p = (cast(ulong*)(&this)); *p = (*p).setBits(TexFormatBitOfs, TexFormatBits, t); } 
		
		protected
		{
			static string SharedCode()
			=> q{
				ivec3 decodeDimSize(in uint dim, in uint raw0, in uint raw12)
				{
					switch(dim)
					{
						case TexDim._1D: 	return ivec3(raw12, 1, 1); 
						case TexDim._2D: 	return ivec3((raw0 | ((raw12 & 0xFF)<<16)), raw12>>8, 1); 
						case TexDim._3D: 	return ivec3(raw0, raw12 & 0xFFFF, raw12>>16); 
						default: 	return ivec3(0); 
					}
				} 
				
				uint calcFlatIndex(in ivec3 v, in uint dim, in ivec3 size)
				{
					switch(dim)
					{
						case TexDim._1D: 	return v.x; 
						case TexDim._2D: 	return v.x + (v.y * size.x); 
						case TexDim._3D: 	return v.x + (v.y + v.z * size.y) * size.x; 
						default: 	return 0; 
					}
				} 
			}; 
			
			static string GLSLCode()
			=> iq{
				$(GEN_enumDefines!TexDim)
				$(GEN_enumDefines!TexFormat)
				$(GEN_enumDefines!TexChn)
				$(GEN_enumDefines!TexBpp)
				$(SharedCode.replace("TexDim._", "TexDim_"))
			}.text; 
			static { mixin(SharedCode); } 
		} 
		
		@property ivec3 size() const
		=> decodeDimSize(dim, _rawSize0, _rawSize12); 
		@property size(int a)
		{ dim = TexDim._1D; _rawSize0 = 0; _rawSize12 = a; } 
		@property size(ivec2 a)
		{ dim = TexDim._2D; _rawSize0 = a.x & 0xFFFF; _rawSize12 = ((a.x>>16) & 0xFF) | (a.y << 8); } 
		@property size(ivec3 a)
		{ dim = TexDim._3D; _rawSize0 = a.x; _rawSize12 = (a.y & 0xFFFF) | (a.z << 16); } 
		
		@property flags() const
		=> mixin(幟!((TexInfoFlag),q{getBits(*(cast(ubyte*)(&this)), TexInfoBitOfs, TexInfoBits)})); 
		
		@property flags(in TexInfoFlags a)
		{ auto b = (cast(ubyte*)(&this)); *b = setBits(*b, TexInfoBitOfs, TexInfoBits, (cast(ubyte)((cast(uint)(a))))); } 
		
		static void selfTest()
		{
			void doit(T)(T v, ivec3 r) { TexSizeFormat t; t.size = v; enforce(t.size==r); } 
			{
				const a = [1, 84903, 0x7F12_345F]; 
				foreach(x; a) doit(x, ivec3(x, 1, 1)); 
			}
			{
				const a = [1, 84903, 0xF1234F]; 
				foreach(x; a) foreach(y; a) doit(ivec2(x, y), ivec3(x, y, 1)); 
			}
			{
				const a = [1, 14903, 0xF12F]; 
				foreach(x; a) foreach(y; a) foreach(z; a) doit(ivec3(x, y, z), ivec3(x, y, z)); 
			}
		} 
		
		string toString() const
		=> i"TexSizeFormat($(format), $(size.x) x $(size.y) x $(size.z)$(error?", ERR":"")$(loading?", LD":"")$(resident?", RES":""))".text; 
		
		static assert(TexSizeFormat.sizeof==8); 
	} 
	
	/+
		General rules of enums:
		 - enum item Order is important, GLSL sources rely on it by using < > ops.
		 - Defaults are always 0. The the first enum member is the default.
	+/
	
	version(/+$DIDE_REGION Texturing enums+/all)
	{
		alias TexHandle = Typedef!(uint, 0, "TexHandle"); 
		
		enum TexXAlign : ubyte {left, xcenter, hcenter = xcenter, right} 
		enum TexYAlign : ubyte {top, ycenter, vcenter = ycenter, baseline, bottom} 
		enum TexSizeSpec : ubyte {original, scaled, exact} 
		enum TexAspect : ubyte {stretch, keep, crop} 
		
		enum TexOrientation : ubyte
		{
			normal 	= 0, //Default orientation (0,0)-(1,1)
			mirrorX 	= 1, //Flip horizontally (1,0)-(0,1)
			mirrorY 	= 2, //Flip vertically (0,1)-(1,0)
			mirrorXY 	= 3, //Flip both X and Y (1,1)-(0,0) (same as rot180)
			mirrorDiag 	= 4, //Mirror across main diagonal (0,0)-(1,1)
			mirrorXDiag 	= 5, //Mirror X then diagonal
			mirrorYDiag 	= 6, //Mirror Y then diagonal
			mirrorXYDiag 	= 7, //Mirror X and Y then diagonal
			
			//Additional rotation names
			rot90 	= mirrorYDiag,	//90° counter-clockwise rotation
			rot180 	= mirrorXY,	//180° rotation (same as mirrorXY)
			rot270 	= mirrorXDiag,	//270° counter-clockwise rotation
			
			//Alternative names
			flipH 	= mirrorX, 	//Horizontal flip
			flipV 	= mirrorY, 	//Vertical flip
			flipHV 	= mirrorXY, 	//Both flips
			transpose 	= mirrorDiag 	//Swap X and Y coordinates
		} 
		
		struct TexFlags
		{
			ushort _raw; 
			mixin 入 !((
				(表([
					[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Comment+/}],
					[q{TexXAlign},q{2},q{"xAlign"},q{/++/}],
					[q{TexYAlign},q{2},q{"yAlign"},q{/++/}],
					[q{TexSizeSpec},q{2},q{"sizeSpec"},q{/++/}],
					[q{TexAspect},q{2},q{"aspect"},q{/++/}],
					[q{TexOrientation},q{3},q{"orientation"},q{/++/}],
				]))
			),q{mixin GEN_GLSLBitfields!(_data, "tex", "TF"); }); 
		} 
	}
	version(/+$DIDE_REGION Font enums+/all)
	{
		enum FontType : ubyte
		{
			monospace3D,	//fontmap is a 3D texture of same sized glyphs.
			unicodeBlockMap128, 	/+
				fontMap is a texture of 0x110000>>7 = 8704 uints.
				block = code>>7; blkTex = texture[fontMap[block]];
				charTex = blkTex[code & 0x7F];
				/+Opt: fast 0th block at the very start of the fontMap+/
			+/
			texture2DHandles	//individual uint texture handles
		} 
		
		enum FontLine : ubyte {none, underline, strikethrough, errorline } 
		enum FontWidth : ubyte {normal, thin/+.66+/, wide/+1.5+/, wider/+2+/ } 
		enum FontScript : ubyte {none, superscript, subscript, smallscript} 
		enum FontBlink : ubyte {none, blink, slowblink, fastblink } 
		
		struct FontFlags
		{
			ushort _raw; 
			mixin 入 !((
				(表([
					[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Comment+/}],
					[q{FontType},q{2},q{"type"},q{/+initialized externally from FontFace+/}],
					[q{bool},q{1},q{"bold"},q{/++/}],
					[q{bool},q{1},q{"italic"},q{/++/}],
					[q{bool},q{1},q{"monospace"},q{/+for coding and terminals+/}],
					[q{FontLine},q{2},q{"line"},q{/+underline, errorline, strikethrough+/}],
					[q{FontWidth},q{2},q{"width"},q{/+66%, 150%, 200%+/}],
					[q{FontScript},q{2},q{"script"},q{/+subscript, superscript, smallscript+/}],
					[q{FontBlink},q{2},q{"blink"},q{/+normal, fast, slow+/}],
				]))
			),q{mixin GEN_GLSLBitfields!(_data, "font", "FF"); }); 
		} 
	}
	
	version(/+$DIDE_REGION Common enums+/all)
	{
		enum HandleFormat : ubyte {u12, u16, u24, u32} 
		
		enum SizeUnit : ubyte
		{
			world, 	/+one unit in the world+/
			screen, 	/+one pixel at the screen (similar to fwidth())+/
			model 	/+Todo: one unit inside scaled model space+/
		} 
		
		enum ColorFormat : ubyte {rgba_u8, rgb_u8, la_u8, a_u8, u1, u2, u4, u8} 
			enum colorFormatBitCnt = [32,  24,     16,    8,    1,   2,  4,  8]; 
		
		enum CoordFormat : ubyte {f32, i32, i16, i8} 
		enum SizeFormat : ubyte {u4, u8, ulog12/+4G range+/, f32} 
		enum XYFormat : ubyte {absXY, relXY, absX, relX, absY, relY, absXrelY1, relX1absY} 
		enum FlagFormat : ubyte {tex, font, vec, all} 
		enum AngleFormat : ubyte {i10, f32} 
		enum TransFormat : ubyte {
			unity, transXY, scale, scaleXY, 
			skewX, rotZ, clipBounds
			/+, tileXY, transXYZ, axisXY+/
		} 
		
		struct VecFlags
		{
			ubyte _raw; 
			mixin 入 !((
				(表([
					[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Comment+/}],
					[q{CoordFormat},q{2},q{"coordFormat"},q{/++/}],
					[q{XYFormat},q{3},q{"xyFormat"},q{/++/}],
				]))
			),q{mixin GEN_GLSLBitfields!(_data, "vec", "VF"); }); 
		} 
		
		template FlagBits(T)
		{
			static foreach(A; AliasSeq!(TexFlags, FontFlags, VecFlags))
			static if(is(T : A)) enum FlagBits = A.bitCnt; 
		} 
	}
	
	version(/+$DIDE_REGION GSP Opcodes+/all)
	{
		mixin 入 !((
			(表([
				[q{/+Note: lvl0+/},q{/+Note: lvl1+/},q{/+Note: lvl2+/},q{/+Note: op+/},q{/+Note: comment+/}],
				[q{/+settings+/}],
				[q{/+	system+/}],
				[q{"0"},q{"00"},q{"00"},q{end},q{/+5 zeroed at end of VBO+/}],
				[q{},q{},q{"01"},q{setOP},q{/+opacity, affects both colors+/}],
				[q{},q{},q{"10"},q{setFlags},q{/+FlagFormat Flags+/}],
				[q{},q{},q{"11"},q{setTrans},q{/+TransformFormat data+/}],
				[q{/+	colors: op ColorFormat, data+/}],
				[q{},q{"01"},q{"00"},q{setPC},q{/+primary color+/}],
				[q{},q{},q{"01"},q{setSC},q{/+secondary color+/}],
				[q{},q{},q{"10"},q{setPCSC},q{/+load two colors+/}],
				[q{},q{},q{"11"},q{setC},q{/+broadcast one color+/}],
				[q{/+	sizes: op SizeFormat data+/}],
				[q{},q{"10"},q{"00"},q{setPS},q{/+pixel size+/}],
				[q{},q{},q{"01"},q{setLW},q{/+line width+/}],
				[q{},q{},q{"10"},q{setDL},q{/+dot length+/}],
				[q{},q{},q{"11"},q{setFH},q{/+font height+/}],
				[q{/+	handles: op HandleFormat data+/}],
				[q{},q{"11"},q{"00"},q{setFMH},q{/+FontMap+/}],
				[q{},q{},q{"01"},q{setLFMH},q{/+LatinFontMap+/}],
				[q{},q{},q{"10"},q{setPALH},q{/+Palette+/}],
				[q{},q{},q{"11"},q{setLTH},q{/+LineTexture+/}],
				[],
				[q{/+Note: lvl0+/},q{/+Note: lvl1+/},q{/+Note: lvl2+/},q{/+Note: op+/},q{/+Note: comment+/}],
				[q{/+drawing+/}],
				[q{/+	SVG path1+/}],
				[q{"1"},q{"00"},q{"00"},q{drawPathZ},q{/++/}],
				[q{},q{},q{"01"},q{drawPathM},q{/+xy+/}],
				[q{},q{},q{"10"},q{drawPathL},q{/+xy+/}],
				[q{},q{},q{"11"},q{drawPathT},q{/+xt+/}],
				[q{/+	SVG path2+/}],
				[q{},q{"01"},q{"00"},q{drawPathQ},q{/+xy xy+/}],
				[q{},q{},q{"01"},q{drawPathS},q{/+xy xy+/}],
				[q{},q{},q{"10"},q{drawPathC},q{/+xy xy xy+/}],
				[q{},q{},q{"11"},q{drawPathTG},q{/+tangents at curve split points+/}],
				[q{/+	unused+/}],
				[q{},q{"10"},q{"00"},q{unused0},q{/+TransformFormat+/}],
				[q{},q{},q{"01"},q{unused1},q{/++/}],
				[q{},q{},q{"10"},q{unused2},q{/++/}],
				[q{},q{},q{"11"},q{unused3},q{/++/}],
				[q{/+	textured rect, chars, text+/}],
				[q{},q{"11"},q{"00"},q{drawMove},q{/+CoordFormat Coords+/}],
				[q{},q{},q{"01"},q{drawTexRect},q{/+CoordFormat Coords HandleFormat Handle+/}],
				[q{},q{},q{"10"},q{drawFontASCII},q{/+ubyte+/}],
				[q{},q{},q{"11"},q{drawFontASCII_rep},q{/+ubyte+/}],
				[],
			]))
		),q{
			struct OpcodeInfo { string name; uint bits, bitCnt; } 
			static immutable opInfo = 
			(){
				enum N=3/+no of levels+/; string[N] lvl; 
				return mixin(求map(q{r},q{_data.rows},q{
					mixin(求each(q{0<=i<N},q{},q{if(mixin(指(q{r},q{i}))!="") mixin(指(q{lvl},q{i}))=mixin(指(q{r},q{i})).withoutStartingEnding('"'); })); 
					return OpcodeInfo(
						mixin(指(q{r},q{N})), 	lvl[].retro.join.to!uint(2), 
							lvl[].join.length.to!uint
					); 
				}))
				.filter!q{a.name!=""}.array; 
			}(); 
			mixin(iq{enum Opcode {$(opInfo.map!q{a.name}.join(','))} }.text); 
		}); 
		/+
			AI: Generate case switch for instruction set: /+
				Hidden: Generate a nested case switch structure from this:
				This is a hierarchical representation of an instruction set.
				Every node has a few number of bits associated them, for example [0] means 1 bit and it must be a 0. [10] means 2 bits and has a decimal value of 2.
				The tab characters in front of the lines represent the nesting level.
				Sometimes there are lines without [ ] and ; characters, just ignore those.
				You can fetch 1 bit by using fetchBool(GS) and do an if/else based on that. In an if else block, please start with the false value first, keep the order same as in the input.
				You can fetch 2 bits by using fetchBits(GS, 2) and doing a case switch on that.
				You can extract the commands by the first identifiers, example end, setPh, drawM. Call thos by GLSL syntax: end();  
				Please preserve the comments you find in the input, also preserve the optional parameters and do dense code by putting the instruction calling and the case break and the comment on the same line.
				Put the { on a new line. Use /* or // comments only, this is GLSL!
			+/ refine: /+
				Hidden: Remove meaningless redundant comments and put parameters into comments!
				Example:
				`case 2: drawC(xy, xy, xy); break; // [10] drawC - cubic bezier`
				->
				`case 2: drawC(/*xy, xy, xy)*/); break; // cubic bezier`
			+/
		+/
		
		
		static if((常!(bool)(0)))
		static foreach(op; EnumMembers!Opcode)
		pragma(msg, opInfo[op].bits.to!string(2).padLeft('0', opInfo[op].bitCnt).text, " : ", op.text); 
	}
	
	class GeometryStreamProcessor
	{
		protected
		{
			enum SharedCode = 
			q{
				void orientQuadTexCoords(
					in vec2 inTopLeft, in vec2 inBottomRight, TexOrientation orientation,
					out vec2 outTopLeft, out vec2 outBottomLeft,
					out vec2 outTopRight, out vec2 outBottomRight
				)
				{
					//initialize texCoords on foor corners
					vec2 tl = inTopLeft, br = inBottomRight, tr = vec2(br.x, tl.y), bl = vec2(tl.x, br.y); 
					
					//Apply the transformations
					if(orientation)
					{
						if(
							(orientation & 1) != 0
							/*mirrorX*/
						) {
							vec2 tmp = tl; tl = tr; tr = tmp; 
							tmp = bl; bl = br; br = tmp; 
						}
						if(
							(orientation & 2) != 0
							/*mirrorY*/
						) {
							vec2 tmp = tl; tl = bl; bl = tmp; 
							tmp = tr; tr = br; br = tmp; 
						}
						if(
							(orientation & 4) != 0
							/*mirrorDiag*/
						) {
							tl = vec2(tl.y, tl.x); tr = vec2(bl.y, bl.x); 
							bl = vec2(tr.y, tr.x); br = vec2(br.y, br.x); 
						}
					}
					
					//Output final coordinates
					outTopLeft = tl; outBottomLeft = bl; outTopRight = tr; outBottomRight = br; 
				} 
				
				bool isLatinChar(uint code)
				{
					return (
						(code >= 0x0020u && code <= 0x024Fu) || // Basic Latin + Latin-1 + Ext-A/B
						(code >= 0x1E00u && code <= 0x1EFFu)   // Latin Extended Additional
					); 
				} 
				
				bool isLatinChar_blk128(uint code)
				{
					uint blk = code >> 7; 
					return (
						(blk < (0x0280u>>7)) || // Basic Latin + Latin-1 + Ext-A/B
						(
							blk >=(0x1E00u>>7) && 
							blk < (0x1D00Fu>>7)
						) // Latin Extended Additional
					); 
				} 
			}; 
			static { mixin(SharedCode); } 
		} 
	} 
	
	version(/+$DIDE_REGION GSP assembler functs+/all)
	{
		struct Bits(T)
		{
			static assert(isIntegral!T); 
			//static assert(!isSigned!T); 
			
			
			
			/+
				Todo: lock the type for ulong here. Not just in assemble()! 
				So cast everything to raw ulong here.
				assemble() does this ulong casting by starting with an empty Bits!ulong.
			+/
			
			T data; 
			size_t bitCnt; 
			
			///'other' is casted to T
			
			auto opBinary(string op : "~", B)(B other) const
			{
				static if(is(B==Bits!T2, T2))
				{
					static if(isSigned!T) data = data << (64-bitCnt) >>> (64-bitCnt); 
					//Opt: dont allow signed types here, to be able to avoid negative masking
					
					return Bits!T(data | ((cast(T)(other.data))<<bitCnt), bitCnt+other.bitCnt); 
				}
				else
				return this ~ bits(other); 
			} 
		} 
		
		auto bits(T)(T data, size_t bitCnt)
		=> Bits!T(data, bitCnt); 
		
		auto bits(T)(in T a)
		{
			static if(is(T==vec2)||is(T==ivec2))	return bits(a.bitCast!ulong); 
			else static if(
				is(T==float)||is(T==RGBA)||
				is(T==Vector!(short, 2))||
				is(T==Vector!(ushort, 2))
			)	return bits(a.bitCast!uint); 
			else static if(is(T==RGB))	return Bits!uint(a.raw, 24); 
			else static if(
				is(T==Vector!(byte, 2))||
				is(T==Vector!(ubyte, 2))
			)	return bits(a.bitCast!ushort); 
			else static if(is(T==enum))
			{
				static if(is(T==Opcode))	return bits(opInfo[a].bits, opInfo[a].bitCnt); 
				else	return bits((cast(uint)(a)), EnumBits!T); 
			}
			else
			{ return bits(a, T.sizeof * 8); }
		} 
		
		auto assemble(A...)(A args)
		{
			Bits!ulong res; 
			static foreach(i, a; args)
			{
				{
					static if(is(A[i] : Bits!B, B))	res = res ~ a; 
					else	res = res ~ bits(a); 
				}
			}
			
			assert(res.bitCnt <= 64, i"assemble($(A.stringof)): overflow $(res.bitCnt)".text); 
			return res; 
		} 
		
		Bits!ulong assembleHandle(T)(in T handle)
		{
			const h = (cast(uint)(handle)); 
			if(h<(1<<12)) return assemble(mixin(舉!((HandleFormat),q{u12})), bits(h, 12)); 
			if(h<(1<<16)) return assemble(mixin(舉!((HandleFormat),q{u16})), bits(h, 16)); 
			if(h<(1<<24)) return assemble(mixin(舉!((HandleFormat),q{u24})), bits(h, 24)); 
			return assemble(mixin(舉!((HandleFormat),q{u32})), h); 
		} 
		
		Bits!ulong assembleSize(T)(in T size)
		{
			static if(is(T : int))	{ const i = size.max(0), f = float(i), isInt = true; }
			else static if(is(T : float))	{ const f = size.max(0), i = (iround(f)), isInt = i==f; }
			else static assert(false, "Unhandled type: "~T.stringof); 
			if(isInt)
			{
				if(i<(1<<4)) return assemble(mixin(舉!((SizeFormat),q{u4})), bits((cast(uint)(i)), 4)); 
				if(i<(1<<8)) return assemble(mixin(舉!((SizeFormat),q{u8})), bits((cast(uint)(i)), 8)); 
			}
			const logf = f.log2*128.0f, logi = (iround(logf)), exact = logf==logi; 
			if(exact && mixin(界1(q{0},q{logi},q{1<<12})))	return assemble(mixin(舉!((SizeFormat),q{ulog12})), bits((cast(uint)(logi)), 12)); 
			else	return assemble(mixin(舉!((SizeFormat),q{f32})), f); 
		} 
		
		void unittest_assembleSize()
		{
			// Test integer cases
			assert(assembleSize(5) == assemble(mixin(舉!((SizeFormat),q{u4})), bits(5, 4))); 
			assert(assembleSize(20) == assemble(mixin(舉!((SizeFormat),q{u8})), bits(20, 8))); 
			
			// Test exact log cases
			float exactSize = exp2(64.0f / 128.0f); // log2(exactSize)*128 = 64
			assert(assembleSize(exactSize) == assemble(mixin(舉!((SizeFormat),q{ulog12})), bits(64, 12))); 
			
			// Test float fallback
			float nonExactSize = 3.14159f; 
			assert(assembleSize(nonExactSize) == assemble(mixin(舉!((SizeFormat),q{f32})), nonExactSize)); 
			
			// Test negative clamping
			assert(assembleSize(-5) == assemble(mixin(舉!((SizeFormat),q{u4})), bits(0, 4))); 
			assert(assembleSize(-1.5f) == assemble(mixin(舉!((SizeFormat),q{u4})), bits(0, 4))); 
		} 
		
		Bits!ulong assembleAngle_deg(T)(in T angle)
		{
			static if(is(T : int))
			{ const i = angle; const isInt = true; }
			else static if(is(T : float))
			{ const i = (itrunc(angle)); const isInt = i == angle; }
			else static assert(false, "Unhandled type: "~T.stringof); 
			
			if(
				isInt && 
				mixin(界1(q{-1<<9},q{i},q{1<<9}))
			)	{ return assemble(mixin(舉!((AngleFormat),q{i10})), bits((cast(uint)(i)), 10)); }
			else	{ return assemble(mixin(舉!((AngleFormat),q{f32})), float(angle)); }
		} 
		
		void unittest_assembleAngle()
		{
			// Test integer cases within range
			assert(assembleAngle_deg(0) == assemble(mixin(舉!((AngleFormat),q{i10})), bits(0, 10))); 
			assert(assembleAngle_deg(256) == assemble(mixin(舉!((AngleFormat),q{i10})), bits(256, 10))); 
			assert(assembleAngle_deg(511) == assemble(mixin(舉!((AngleFormat),q{i10})), bits(511, 10))); 
			assert(assembleAngle_deg(-512) == assemble(mixin(舉!((AngleFormat),q{i10})), bits((cast(uint)(-512)), 10))); 
			
			// Test float cases that are exact integers within range
			assert(assembleAngle_deg(128.0f) == assemble(mixin(舉!((AngleFormat),q{i10})), bits(128, 10))); 
			
			// Test float fallback for non-integer values
			assert(assembleAngle_deg(128.5f) == assemble(mixin(舉!((AngleFormat),q{f32})), 128.5f)); 
			
			// Test out-of-range values use float32 (no clamping)
			assert(assembleAngle_deg(-513) == assemble(mixin(舉!((AngleFormat),q{f32})), -513.0f)); 
			assert(assembleAngle_deg(600) == assemble(mixin(舉!((AngleFormat),q{f32})), 600.0f)); 
			assert(assembleAngle_deg(-512.5f) == assemble(mixin(舉!((AngleFormat),q{f32})), -512.5f)); 
			assert(assembleAngle_deg(600.0f) == assemble(mixin(舉!((AngleFormat),q{f32})), 600.0f)); 
		} 
		
		Bits!ulong assemblePoint(in Vector!(byte, 2) p)
		{ return assemble(mixin(舉!((CoordFormat),q{i8})), p); } 
		
		Bits!ulong assemblePoint(in Vector!(short, 2) p)
		{
			if(mixin(界1(q{-128},q{p.x},q{128})) && mixin(界1(q{-128},q{p.y},q{128})))
			return assemble(mixin(舉!((CoordFormat),q{i8})), (cast(ubyte)(p.x)), (cast(ubyte)(p.y))); 
			else return assemble(mixin(舉!((CoordFormat),q{i16})), p); 
		} 
		
		Bits!(ulong)[2] assemblePoint(in ivec2 p)
		{
			if(mixin(界1(q{-128},q{p.x},q{128})) && mixin(界1(q{-128},q{p.y},q{128})))
			return [assemble(mixin(舉!((CoordFormat),q{i8})), (cast(ubyte)(p.x)), (cast(ubyte)(p.y))), bits(0UL,0)]; 
			else if(mixin(界1(q{-32768},q{p.x},q{32768})) && mixin(界1(q{-32768},q{p.y},q{32768})))
			return [assemble(mixin(舉!((CoordFormat),q{i16})), (cast(ushort)(p.x)), (cast(ushort)(p.y))), bits(0UL,0)]; 
			else return[assemble(mixin(舉!((CoordFormat),q{i32}))), assemble(p)]; 
		} 
		
		Bits!(ulong)[2] assemblePoint(in vec2 p)
		{
			const i = (itrunc(p)); 
			if(p==i) return assemblePoint(i); 
			else return [assemble(mixin(舉!((CoordFormat),q{f32}))), assemble(p)]; 
		} 
		
		void unittest_assemblePoint()
		{
			void test(alias vec, alias fmt, int len)()
			{
				const p = assemblePoint(vec); enum fmtBitCnt = EnumBits!(typeof(fmt)); 
				static if(isStaticArray!(typeof(p)))
				{ const p0 = p[0],  actualLen = p[0].bitCnt + p[1].bitCnt; }
				else
				{ const p0 = p,  actualLen = p.bitCnt; }
				assert(p0.data.getBits(0, fmtBitCnt) == fmt, "bad fmtCode"); 
				assert(actualLen - fmtBitCnt == len, "bad len"); 
			} 
			
			test!(vec2(0), mixin(舉!((CoordFormat),q{i8})), 8*2); 
			test!(ivec2(-128, 27), mixin(舉!((CoordFormat),q{i8})), 8*2); 
			test!(ivec2(129, 129), mixin(舉!((CoordFormat),q{i16})), 16*2); 
			test!(ivec2(-32768, 32767), mixin(舉!((CoordFormat),q{i16})), 16*2); 
			test!(vec2(40000, -40000), mixin(舉!((CoordFormat),q{i32})), 32*2); 
			test!(vec2(1.0f, 2.0f), mixin(舉!((CoordFormat),q{i8})), 8*2); 
			test!(vec2(1.5f, 2.5f), mixin(舉!((CoordFormat),q{f32})), 32*2); 
			test!(Vector!(byte, 2)(0, 0), mixin(舉!((CoordFormat),q{i8})), 8*2); 
			test!(Vector!(short, 2)(-128, 127), mixin(舉!((CoordFormat),q{i8})), 8*2); 
			test!(Vector!(short, 2)(129, 129), mixin(舉!((CoordFormat),q{i16})), 16*2); 
		} 
		
		static struct FormattedColor
		{
			uint value; 
			ColorFormat format; 
			
			this(FT)(in uint a, in FT fmt)
			{
				static if(is(FT : ColorFormat))
				{ value = a, format = fmt; }
				else
				{
					switch(fmt/+bitCnt+/)
					{
						case 1: 	{ format = mixin(舉!((ColorFormat),q{u1})); value = a; }	break; 
						case 2: 	{ format = mixin(舉!((ColorFormat),q{u2})); value = a; }	break; 
						case 4: 	{ format = mixin(舉!((ColorFormat),q{u4})); value = a; }	break; 
						case 8: 	{ format = mixin(舉!((ColorFormat),q{u8})); value = a; }	break; 
						default: 
					}
				}
			} 
			
			this(T)(in T a)
			{
				static if(is(T : FormattedColor)) { this = a; }
				else static if(is(T : Bits!U, U)) { this((cast(uint)(a.data)), a.bitCnt); }
				else static if(isColorEnum!T)	{ this((cast(uint)(a)), 4/+Todo: !!!! Calculate BitCount!!!+/); }
				else static if(isFloatingPoint!T)	{ this(a.to_unorm, 8); }
				else static if(is(T : RG))	{ format = mixin(舉!((ColorFormat),q{la_u8})); value = a.raw; }
				else static if(is(T : vec2))	{ this(a.to_unorm); }
				else static if(is(T : RGB))	{ format = mixin(舉!((ColorFormat),q{rgb_u8})); value = a.raw; }
				else static if(is(T : vec3))	{ this(a.to_unorm); }
				else static if(is(T : RGBA))	{ format = mixin(舉!((ColorFormat),q{rgba_u8})); value = a.raw; }
				else static if(is(T : vec4))	{ this(a.to_unorm); }
				else static assert(false, "unhandled type: "~T.stringof); 
			} 
			
			static assert(FormattedColor.sizeof==8); 
		} 
		
		
		auto assembleColor(A...)(in A args)
		{
			const fc = FormattedColor(args); 
			return assemble(fc.format, bits(fc.value, colorFormatBitCnt[fc.format])); 
		} 
		
		auto assembleColor_noFormat(A...)(in A args)
		{
			const fc = FormattedColor(args); 
			return assemble(bits(fc.value, colorFormatBitCnt[fc.format])); 
		} 
	}
	
	version(/+$DIDE_REGION+/all) {
		enum FontId: ubyte
		{
			_default_, 
			
			CGA_8x8, 
			VGA_9x16, 
			
			Arial,
			Bahnschrift,
			Calibri,
			Cambria,
			Cambria_Math,
			Candara,
			Cascadia_Code,
			Cascadia_Mono,
			Comic_Sans_MS,
			Consolas,
			Constantia,
			Corbel,
			Courier_New,
			Franklin_Gothic,
			Gabriola,
			Georgia,
			HoloLens_MDL2_Assets,
			Impact,
			Ink_Free,
			Lucida_Console,
			Lucida_Sans_Unicode,
			Marlett,
			Microsoft_Sans_Serif,
			MingLiU_ExtB,
			Segoe_MDL2_Assets,
			Segoe_Print,
			Segoe_Script,
			Segoe_UI,
			Segoe_UI_Emoji,
			Segoe_UI_Historic,
			Segoe_UI_Symbol,
			Sitka,
			Sylfaen,
			Symbol,
			Tahoma,
			Times_New_Roman,
			Trebuchet_MS,
			Verdana,
			Webdings,
			Wingdings,
			
			_reserved_
		} 
		
		enum TotalFontIds = 128; 
		enum DefaultFontId = FontId.VGA_9x16; 
		
		enum FontSourceType: ubyte
		{
			//ProportionalFont: TTF fonts generated by DirectWrite
			directWrite, 
			
			//MonospaceFont: monospace fonts defined by 3D textures
			mono_1bit_file, mono_1bit_raw, monoTexture
		} 
		
		///Fontsource specifies data from which a font can be loaded/initialized.
		struct FontSource
		{
			FontSourceType type; 
			Texture monoTexture; //this pins the texture in GC
			string data; 
			ivec2 cellSize, gridSize; //for monoTexture
			
			string asName()
			{
				switch(type)
				{
					case mixin(舉!((FontSourceType),q{directWrite})): 	return data; 
					default: 	return ""; 
				}
			} 
			
			File asFile()
			{
				switch(type)
				{
					case mixin(舉!((FontSourceType),q{mono_1bit_file})): 	return File(data); 
					default: 	return File.init; 
				}
			} 
			
			ubyte[] asRaw()
			{
				/+Todo: Make all this crap work with immutable(ubyte)[]+/
				switch(type)
				{
					case mixin(舉!((FontSourceType),q{mono_1bit_raw})): 	return (cast(ubyte[])(data)); 
					default: 	return []; 
				}
			} 
			
			Texture asMonoTexture()
			{
				switch(type)
				{
					case mixin(舉!((FontSourceType),q{mono_1bit_file})): 	return mainVulkanWindow.new 
					BitmapArrayTexture(asFile, cellSize, gridSize); 
					case mixin(舉!((FontSourceType),q{mono_1bit_raw})): 	return mainVulkanWindow.new 
					BitmapArrayTexture(asRaw, cellSize, gridSize); 
					case mixin(舉!((FontSourceType),q{monoTexture})): 	return monoTexture; 
					default: 	return null; 
				}
			} 
		} 
		
		
		FontSource fontSource(string faceName)
		=> FontSource(mixin(舉!((FontSourceType),q{directWrite})), null, faceName); 
		
		FontSource fontSource(Texture texture)
		=> FontSource(mixin(舉!((FontSourceType),q{monoTexture})), texture); 
		
		FontSource fontSource_mono_1bit(T)(in T a, ivec2 cellSize = ivec2(0), ivec2 gridSize = ivec2(0))
		{
			static if(is(T : File))
			return FontSource(mixin(舉!((FontSourceType),q{mono_1bit_file})), null, a.fullName, cellSize: cellSize, gridSize: gridSize); 
			else static if(is(T : ubyte[])/+ || is(T : string)+/)
			return FontSource(mixin(舉!((FontSourceType),q{mono_1bit_raw})), null, (cast(string)(a)), cellSize: cellSize, gridSize: gridSize); 
			else static assert(false, "unhandled type: "~T.stringof); 
		} 
		
		class FontFace
		{
			const 
			{
				string name; 
				FontId id; 
				bool isMonospace; 
				ivec2 defaultSize; 
				float defaultAspect, defaultAspect_inv; 
			} 
			
			this(
				FontId id, string name, 
				bool isMonospace, ivec2 defaultSize
			)
			{
				this.id 	= id,
				this.name 	= name,
				this.isMonospace 	= isMonospace,
				this.defaultSize 	= defaultSize,
				this.defaultAspect 	= (float(defaultSize.x)) / defaultSize.y; 
				
				defaultAspect_inv = 1.0f/defaultAspect; 
				
				//LOG(i"FontFace created: $(id.to!int) $(id.text) $(name.quoted)".text); 
			} 
			
			abstract @property float charWidth(dchar ch); 
		} 
		
		class MonoFont : FontFace
		{
			Texture monoTexture; 
			
			override @property float charWidth(dchar ch) => defaultSize.x; 
			
			this(FontId id, string name, Texture monoTexture)
			{
				super(id, name, true, monoTexture.size); 
				this.monoTexture = monoTexture.enforce("monoTexture is null "~name.quoted); 
			} 
		} 
		
		class DirectWriteFont : FontFace
		{
			const string typeFaceName; 
			
			override @property float charWidth(dchar ch) => defaultSize.x; 
			
			this(FontId id, string name, string typeFaceName)
			{
				super(id, name, false, ivec2(48, 72)); 
				this.typeFaceName = typeFaceName; 
			} 
		} 
		
		version(/+$DIDE_REGION FontFace stuff+/all)
		{
			FontFace createFontFace(FontId id, string name, FontSource src)
			{
				with(src)
				switch(type) {
					case mixin(舉!((FontSourceType),q{monoTexture})), mixin(舉!((FontSourceType),q{mono_1bit_raw})), mixin(舉!((FontSourceType),q{mono_1bit_file})): 
						return new MonoFont(id, name, asMonoTexture); 
					case mixin(舉!((FontSourceType),q{directWrite})): 
						return new DirectWriteFont(id, name, src.asName); 
					default: 
						return null; 
				}
			} 
			
			void registerFontFace(string name, FontSource src)
			{ g_fontFaceManager.registerFontFace(name, src); } 
			
			FontFace fontFace(string name)
			=> g_fontFaceManager.accessFontFace(name); 
			FontFace fontFace(FontId id)
			=> g_fontFaceManager.accessFontFace(id); 
			FontFace fontFace(FontFace f)
			=> f; 
		}
		
		struct FontSpec(T)
		{
			T fontSpec; 
			FontFlags fontFlags; 
			
			//FontFlag options by name
			static foreach(name; GetBuilderMethodNames!FontFlags)
			mixin(iq{
				auto $(name)()
				{
					auto tmp = this; 
					tmp.fontFlags = tmp.fontFlags._builder_$(name)(); 
					return tmp; 
				} 
			}.text); 
			
			version(/+$DIDE_REGION Standard font access by name+/all)
			{
				static foreach(id; FontId.init.succ .. FontId._reserved_)
				{
					static if(is(T : string))
					{ mixin(iq{auto $(id)() { auto tmp = this; tmp.fontSpec = id.text; return tmp; } }.text); }
					static if(is(T : FontId))
					{ mixin(iq{auto $(id)() { auto tmp = this; tmp.fontSpec = id; return tmp; } }.text); }
					static if(is(T : FontFace))
					{ mixin(iq{auto $(id)() { auto tmp = this; tmp.fontSpec = fontFace(id); return tmp; } }.text); }
				}
			}
		} 
		
		auto Font() => FontSpec!FontId(FontId._default_); 
		auto Font(FontId id) => FontSpec!FontId(id); 
		auto Font(string name) => FontSpec!string(name); 
		auto Font(FontFace ff) => FontSpec!FontFace(ff); 
		auto Font(Texture t) => FontSpec!Texture(t); 
		
		static assert(__traits(compiles, { enum test2 = Font.Times_New_Roman.bold.italic.errorline.fastblink; })); 
		
		/+
			Assistant: /+H3: System Fonts:+/
			Monospace 1bit: /+Code: CGA_8x8+/, /+Code: VGA_9x16+/
			DirectWrite: 
			/+
				Para: /+Code: Arial+/
				/+Code: Bahnschrift+/
				/+Code: Calibri+/
				/+Code: Cambria+/
				/+Code: Cambria_Math+/
				/+Code: Candara+/
				/+Code: Cascadia_Code+/
				/+Code: Cascadia_Mono+/
				/+Code: Comic_Sans_MS+/
				/+Code: Consolas+/
				/+Code: Constantia+/
				/+Code: Corbel+/
				/+Code: Courier_New+/
				/+Code: Franklin_Gothic+/
				/+Code: Gabriola+/
				/+Code: Georgia+/
				/+Code: HoloLens_MDL2_Assets+/
				/+Code: Impact+/
				/+Code: Ink_Free+/
				/+Code: Lucida_Console+/
				/+Code: Lucida_Sans_Unicode+/
				/+Code: Marlett+/
				/+Code: Microsoft_Sans_Serif+/
				/+Code: MingLiU_ExtB+/
				/+Code: Segoe_MDL2_Assets+/
				/+Code: Segoe_Print+/
				/+Code: Segoe_Script+/
				/+Code: Segoe_UI+/
				/+Code: Segoe_UI_Emoji+/
				/+Code: Segoe_UI_Historic+/
				/+Code: Segoe_UI_Symbol+/
				/+Code: Sitka+/
				/+Code: Sylfaen+/
				/+Code: Symbol+/
				/+Code: Tahoma+/
				/+Code: Times_New_Roman+/
				/+Code: Trebuchet_MS+/
				/+Code: Verdana+/
				/+Code: Webdings+/
				/+Code: Wingdings+/
			+/
			/+
				Para: /+H3: FontLine+/:
				/+Code: underline+/
				/+Code: strikethrough+/
				/+Code: errorline+/
			+/   /+
				Para: /+H3: FontWidth+/:
				/+Code: thin+/ 	 66%
				/+Code: wide+/ 	150%
				/+Code: wider+/ 	200%
			+/   /+
				Para: /+H3: FontScript+/:
				/+Code: superscript+/
				/+Code: subscript+/
				/+Code: smallscript+/
			+/   /+
				Para: /+H3: FontBlink+/:
				/+Code: blink+/
				/+Code: slowblink+/
				/+Code: fastblink+/
			+/
		+/
		
		final class FontFaceManager
		{
			protected
			{
				FontSource[string] fontSourceByName; 
				
				FontFace[string] fontFaceByName; 
				FontId[string] fontIdByName; 
				FontFace[TotalFontIds] fontFaceById; 
			} 
			
			void registerFontFace(string name, FontSource src)
			{
				enforce(name.strip!="", "Invalid font name"); 
				synchronized(this)
				{
					if(name in fontSourceByName)
					WARN(i"FontSource $(name.quoted) already registered.".text); 
					else {
						fontSourceByName[name] = src; 
						//LOG("Registered fontFace: "~name.quoted ~ fontSourceByName.text); 
					}
				} 
			} 
			
			FontFace accessFontFace(T)(T a)
			{
				FontFace res; 
				synchronized(this)
				{
					bool getByName(string name)
					{
						if(auto f = name in fontFaceByName)
						{ res = *f; return true; }return false; 
					} 
					bool getById(FontId id)
					{
						if(id<TotalFontIds && fontFaceById[id])
						{ res = fontFaceById[id]; return true; }return false; 
					} 
					FontId getNewId()
					{
						foreach(i; FontId._reserved_+1 .. TotalFontIds)
						if(fontFaceById[i] is null) return (cast(FontId)(i)); 
						throw new Exception("Fatal error: Out of FontId's."); 
					} 
					
					void create(string name)
					{
						assert(name !in fontFaceByName); 
						assert(name !in fontIdByName); 
						
						const idOfName = name.replace(' ', '_').to!FontId.ifThrown(FontId.init); 
						FontFace fontFace; FontId fontId; 
						
						void doit(FontSource src)
						{ fontFace =.createFontFace(fontId, name, src); } 
						
						if(auto src = name in fontSourceByName /+font was registered by user+/)
						{
							fontId = getNewId; 
							doit(*src); 
						}
						else if(idOfName && idOfName<FontId._reserved_/+standard fonts+/)
						{
							fontId = idOfName; 
							switch(idOfName)
							{
								case FontId.CGA_8x8: 
								doit(
									fontSource_mono_1bit(
										`fontmap:\CGA_8x8`.File, 
										cellSize: ivec2(8, 8)
									)
								); 	break; 
								case FontId.VGA_9x16: 
								doit(
									fontSource_mono_1bit(
										`fontmap:\VGA_9x16`.File, 
										cellSize: ivec2(9, 16)
									)
								); 	break; 
								default: doit(fontSource(name)); 
							}
						}
						else enforce(false, iq{Font registration, unknown name: $(name.quoted)}.text); 
						enforce(
							fontFace && fontId, 
							i"Font registration error: $(name.quoted) $(idOfName) $(fontFace)".text
						); 
						
						fontFaceById	[fontId] 	= fontFace,
						fontFaceByName	[name] 	= fontFace,
						fontIdByName	[name] 	= fontId; 
						res = fontFace; 
					} 
					
					static if(is(T : string))
					{
						const name = a; 
						if(!getByName(name)) create(name); 
					}
					else static if(is(T : FontId))
					{
						const FontId id = ((a)?(a):(DefaultFontId)); 
						if(!getById(id))
						{
							if(id>FontId._default_ && id<FontId._reserved_)
							create(id.text); 
						}
					}
					else static assert(false, "Unhandled type: "~T.stringof); 
				} 
				return res; 
			} 
		} 
		
		
		
	}
	
	
	struct GfxContent
	{
		alias VertexData = VulkanWindow.VertexData; 
		VertexData[] vb; 
		ulong[] gb; 
		uint gbBits; 
		@property empty() const
		=> vb.empty; 
	}  interface IGfxContentDestination
	{ void appendGfxContent(in GfxContent content); } 
	
	class GfxAssembler /+Todo: this is basically an assembler, not a builder: It maintains a state and emits it on request.+/
	{
		IGfxContentDestination gfxContentDestination/+optional: the target handler of commitGfxContent()+/; 
		
		/+
			Opt: final functions everywhere if possible!!! Do timing tests!!!
			250919: No luck. Used `final:` in every classes, but same FPS. Should check in ASM.
		+/
		
		/+Opt: Pull all the state into a central, well packed struct! It will make state copy operations faster.  Currently the user and target states are interleaved.+/
		
		alias VertexData 	= VulkanWindow.VertexData,
		Texture 	= VulkanWindow.Texture; 
		
		version(/+$DIDE_REGION Bitstream+/all)
		{
			protected
			{
				Appender!(VertexData[]) vbAppender; 
				Appender!(ulong[]) gbAppender; 
				BitStreamAppender bitStreamAppender; 
				final void onBitStreamAppenderFull(ulong data)
				{ gbAppender ~= data; } 
			} 
			
			this(IGfxContentDestination gfxContentDestination = null)
			{
				this.gfxContentDestination = gfxContentDestination; 
				bitStreamAppender.onBuffer = &onBitStreamAppenderFull; 
			} 
			
			@property gbBitPos() 
			=> (cast(uint)(gbAppender.length))*64 + (cast(uint)(bitStreamAppender.tempBits)); 
			
			///The appenders are keeping their memory ready to use.
			void resetStream(bool doDealloc=false)
			{
				if(doDealloc)
				{
					vbAppender = appender!(VertexData[])(); 
					gbAppender = appender!(ulong[])(); 
				}
				else
				{
					vbAppender.clear; 
					gbAppender.clear; 
				}
				bitStreamAppender.reset; 
				resetBlockState; 
			} 
			
			///This resets and frees up the appenders memory
			void deallocStream()
			{ resetStream(doDealloc : true); } 
			
			@property empty()
			{
				return vbAppender.empty; 
				/+
					After the first begin(), there will be an index in VB.
					Emitting data into GB without calling begin() is treated as empty.
				+/
			} 
			
			GfxContent toGfxContent()
			{
				if(empty) return GfxContent.init; 
				end; 
				const actual_gbBitsPos = gbBitPos; 
				bitStreamAppender.flush; 
				return GfxContent(vbAppender[], gbAppender[], actual_gbBitsPos); 
			} 
			
			protected void appendToDestination(in GfxContent content)
			{
				enforce(gfxContentDestination, "Unablem to commit GfxContent."); 
				gfxContentDestination.appendGfxContent(content); 
			} 
			
			void commit()
			{
				const content = toGfxContent; 
				appendToDestination(content); 
				resetStream; 
			} 
			
			void commit(in GfxContent externalContent)
			{
				if(!externalContent.empty)
				{
					if(!this.empty) { commit; /+first it must commit the self+/}
					
					//Normally this is a costy synchronized operation:
					appendToDestination(externalContent); 
				}
			} 
			
			void consume(GfxBuilder externalBuilder)
			{
				if(externalBuilder && !externalBuilder.empty)
				{
					commit(externalBuilder.toGfxContent); 
					externalBuilder.resetStream; //important to reser AFTER the commit!
				}
			} 
			
			void emit(Args...)(in Args args)
			{
				static foreach(i, T; Args)
				{
					{
						alias a = args[i]; 
						static if(is(T : Bits!(B), B))
						bitStreamAppender.appendBits(a.data, a.bitCnt); 
						else static if(is(T : Bits!(B)[N], B, int N))
						{ static foreach(i; 0..N) emit(a[i]); }
						else static if(is(T : ubyte[]))
						emitBytes(a); 
						else
						with(bits(a)) bitStreamAppender.appendBits(data, bitCnt); 
					}
				}
			} 
			
			void emitBytes(in void[] data)
			{
				auto ba = (cast(ubyte[])(data)); 
				while(ba.length>=8) { emit(*(cast(ulong*)(ba.ptr))); ba = ba[8..$]; }
				if(ba.length>=4) { emit(*(cast(uint*)(ba.ptr))); ba = ba[4..$]; }
				if(ba.length>=2) { emit(*(cast(ushort*)(ba.ptr))); ba = ba[2..$]; }
				if(ba.length>=1) { emit(*(cast(ubyte*)(ba.ptr))); }
			} 
			
			void emitEvenBytes(void[] data)
			{
				auto ba = (cast(ubyte[])(data)); 
				while(ba.length>=16) { emit(ba.staticArray!16.packEvenBytes); ba = ba[16..$]; }
				if(ba.length>=8) { emit(ba.staticArray!8.packEvenBytes); ba = ba[8..$]; }
				if(ba.length>=4) { emit(ba.staticArray!4.packEvenBytes); ba = ba[4..$]; }
				if(ba.length>=2) { emit(ba[0]); }
			} 
			
		}
		
		
		version(/+$DIDE_REGION Block handling+/all)
		{
			protected int actVertexCount; 
			protected bool insideBlock; 
			
			protected void resetBlockState()
			{ insideBlock = false; actVertexCount = 0; } 
			
			///Closes the block with an 'end' opcode. Only if there is an actual block.
			void end()
			{
				if(insideBlock.chkClear)
				{ emit(mixin(舉!((Opcode),q{end}))); }
			} 
			
			///It always starts a new block.  Emits 'end' if needed.
			void begin()
			{
				if(insideBlock) end; 
				vbAppender ~= mixin(體!((VertexData),q{gbBitPos})); 
				resetState!(StateSide.target); 
				actVertexCount=0; 
				insideBlock = true; 
			} 
			
			version(/+$DIDE_REGION Messy ShaderMaxVertexCount logic+/all)
			{
				enum ShaderMaxVertexCount = 
				
				//127
				/+
					127:
					4 vec4 gl_Position
					4 smooth mediump vec4 fragColor
					4 smooth mediump vec4 fragBkColor
					2 smooth vec2 fragTexCoordXY
					1 flat uint fragTexHandleAndMode
					1 flat uint fragTexCoordZ
					4 flat vec4 fragFloats0
					4 flat vec4 fragFloats1
					-----
					24 total
				+/
				113
				/+
					113:
					24 total + gl_ClipDistance[4] = 28
				+/
				; 
				__gshared int desiredMaxVertexCount = ShaderMaxVertexCount; 
				
				static @property int maxVertexCount()
				{ return desiredMaxVertexCount; } 
			}
			
			@property remainingVertexCount() const
			=> ((insideBlock)?(maxVertexCount - actVertexCount):(0)); 
			
			void incVertexCount(int inrc)
			{ actVertexCount += inrc; } 
			
			///Tries to continue the current block with the required vertices.
			///If a new block started, it emits setup code.
			void begin(int requiredVertexCount, void delegate() onSetup)
			{
				if(insideBlock)
				{
					const newVertexCount = actVertexCount + requiredVertexCount; 
					if(newVertexCount <= maxVertexCount)
					{
						actVertexCount = newVertexCount; 
						/+Actual block is continued.+/
						//print("continuing block", gbBitPos, actVertexCount); 
					}
					else
					{ begin; onSetup(); }
				}
				else
				{ begin; onSetup(); }
				/+
					Todo: Handle the case when maxVertexCount > requiredVertexCount.
					Because that's an automatic fail, but must be handled on the 
					caller side, not here.
				+/
			} 
		}
		
		version(/+$DIDE_REGION Internal state+/all)
		{
			protected enum StateSide
			{ user, target, both } 
			
			version(none)
			{
				struct ExperimentalState
				{
					/+16+/TexHandle PALH, FMH, LFMH, LTH; 
					/+16+/float FH=GSP_DefaultFontHeight, LW=1, DL=1; Vector!(ushort, 2) fontSize; 
					/+16+/FormattedColor PC, SC; 	//can save 6
					/+16+/FontFace fontFace; float	OP=1;  ushort fontFlags, texFlags; 
					/+40+/TR a; 
				} 
				
				pragma(msg,i"$(ExperimentalState.sizeof)".text.注); 
				ExperimentalState experimentalUserState, experimentalTargetState; 
			}
			
			version(/+$DIDE_REGION Handles+/all)
			{
				struct TexHandleState(Opcode opcode)
				{
					private: 
					enum TexHandle initialState = TexHandle.init; 
					TexHandle 	userState 	= initialState, 
						targetState 	= initialState; 
					
					public: 
					@property TexHandle get()
					=> userState; 
					
					@property void set(TexHandle val)
					{
						if(userState.chkSet(val))
						{
							/+
								The user changed the internal state. Change detection, 
								and precompilation can go here.
							+/
						}
					} 
					
					@property void set(Texture tex)
					{ set(tex ? tex.handle : TexHandle.init); } 
					
					void resetState(StateSide side)()
					{
						if(side & StateSide.user) userState = initialState; 
						if(side & StateSide.target) targetState = initialState; 
					} 
					
					void synch(GfxAssembler builder)
					{
						if(targetState.chkSet(userState))
						{
							/+
								The internal state was different to the target GPU state.
								So it have to be emited.
							+/
							builder.emit(assemble(opcode, assembleHandle(targetState))); 
						}
					} 
				} 
				
				protected mixin template TexHandleTemplate(string name)
				{
					mixin(iq{
						TexHandleState!(Opcode.set$(name)) state_$(name); 
						void $(name)(T)(T arg) { state_$(name).set(arg); } 
						auto $(name)() => state_$(name).get; 
						void synch_$(name)() { state_$(name).synch(this); } 
					}.text); 
				} 
			}
			
			version(/+$DIDE_REGION Sizes+/all)
			{
				struct SizeState(Opcode opcode, float initialState)
				{
					private: 
					float 	userState 	= initialState, 
						targetState 	= initialState; 
					
					public: 
					ref access() => userState; 
					
					void resetState(StateSide side)()
					{
						if(side & StateSide.user) userState = initialState; 
						if(side & StateSide.target) targetState = initialState; 
					} 
					
					void synch(GfxAssembler builder)
					{
						if(targetState.chkSet(userState))
						{
							/+
								The internal state was different to the target GPU state.
								So it have to be emited.
							+/
							builder.emit(assemble(opcode, assembleSize(targetState))); 
						}
					} 
				} 
				
				protected mixin template SizeTemplate(string name, float initialValue)
				{
					mixin(iq{
						SizeState!(Opcode.set$(name), initialValue) state_$(name); 
						ref $(name)() => state_$(name).access; 
						void synch_$(name)() { state_$(name).synch(this); } 
					}.text); 
				} 
			}
			
			version(/+$DIDE_REGION Color+/all)
			{
				@property colorState() => tuple(((PALH).名!q{PALH}), ((PC).名!q{PC}), ((SC).名!q{SC}), ((OP).名!q{OP})); 
				
				struct ColorState
				{
					FormattedColor 	PC = FormattedColor(1, mixin(舉!((ColorFormat),q{u1}))), 
						SC = FormattedColor(0, mixin(舉!((ColorFormat),q{la_u8}))); 
					float OP = 1; 
				} 
				
				ColorState 	user_colorState, 
					target_colorState; 
				
				version(/+$DIDE_REGION+/all) {
					mixin TexHandleTemplate!"PALH"; 
					auto PC()
					=> user_colorState.PC; void PC(A...)(in A a)
					{ user_colorState.PC = FormattedColor(a); } 
					auto SC()
					=> user_colorState.SC; void SC(A...)(in A a)
					{ user_colorState.SC = FormattedColor(a); } 
					ref OP() => user_colorState.OP; 
				}
				
				void reset_colors(StateSide side)()
				{
					state_PALH.resetState!side; 
					if(side & StateSide.user) user_colorState = ColorState.init; 
					if(side & StateSide.target) target_colorState = ColorState.init; 
				} 
				
				void synch_colors(bool doPC=true, bool doSC=true)()
				{
					synch_PALH; 
					with(target_colorState)
					{
						const 	PC_changed = doPC && PC.chkSet(user_colorState.PC),
							SC_changed = doSC && SC.chkSet(user_colorState.SC); 
						
						if(PC_changed && SC_changed && PC.format==SC.format)
						{
							if(PC.value==SC.value)	{ emit(assemble(mixin(舉!((Opcode),q{setC})), assembleColor(PC))); }
							else {
								emit(
									assemble(mixin(舉!((Opcode),q{setPCSC})), assembleColor(PC)),
									           assembleColor_noFormat(SC)
								); 
							}
						}
						else
						{
							if(PC_changed) emit(assemble(mixin(舉!((Opcode),q{setPC})), assembleColor(PC))); 
							if(SC_changed) emit(assemble(mixin(舉!((Opcode),q{setSC})), assembleColor(SC))); 
						}
						
						if(OP.chkSet(user_colorState.OP)) emit(assemble(mixin(舉!((Opcode),q{setOP}))), OP.to_unorm); 
					}
				} 
				
				alias synch_PC = synch_colors!(true, false),
				synch_SC = synch_colors!(false, true); 
			}
			
			version(/+$DIDE_REGION Font+/all)
			{
				@property fontState() => tuple(((FMH).名!q{FMH}), ((LFMH).名!q{LFMH}), ((FH).名!q{FH}), ((fontSize).名!q{fontSize})); 
				
				mixin TexHandleTemplate!"FMH"; 	//Fontmap
				mixin TexHandleTemplate!"LFMH"; 	//Latin fontmap
				mixin SizeTemplate!("FH", GSP_DefaultFontHeight); 	//Font height
				
				FontSpec!FontFace fontSpec; 
				Vector!(ushort, 2) fontSize; /+cursor can use it to move around+/
				
				
				void reset_font(StateSide side)()
				{
					state_FMH	.resetState!(side),
					state_LFMH	.resetState!(side),
					state_FH	.resetState!(side); 
					if(side & StateSide.user) {
						fontSize = 0;  
						fontSpec = fontSpec.init; 
					}
				} void synch_font()
				{
					synch_FMH, 
					synch_LFMH, 
					synch_FH; 
				} 
				
				void setFont(FontFace font)
				{
					if(auto mf = (cast(MonoFont)(font)))
					{
						FMH = mf.monoTexture, 
						FH = font.defaultSize.y, 
						fontSize = Vector!(ushort, 2)(font.defaultSize); 
					}
					else raise("Unsupported FontFace type: "~font.text); 
				} 
				
				void setFont(FontId id)
				{ setFont(fontFace(id)); }  void setFont(string name)
				{ setFont(fontFace(name)); } 
				
				void setFont(T)(FontSpec!T a)
				{
					fontSpec.fontSpec = .fontFace(a.fontSpec); 
					fontSpec.fontFlags = a.fontFlags; 
					setFont(fontSpec.fontSpec); 
				} 
			}
			
			version(/+$DIDE_REGION Line+/all)
			{
				@property lineState() => tuple(((LTH).名!q{LTH}), ((LW).名!q{LW}), ((DL).名!q{DL})); 
				
				mixin TexHandleTemplate!"LTH"; 	//Line tex handle
				mixin SizeTemplate!("LW", 1); 	//Line width
				mixin SizeTemplate!("DL", 1); 	//Dot length
				void reset_line(StateSide side)()
				{
					state_LTH	.resetState!(side),
					state_LW	.resetState!(side),
					state_DL	.resetState!(side); 
				} void synch_line()
				{
					synch_LTH, 
					synch_LW, 
					synch_DL; 
				} 
			}
			
			version(/+$DIDE_REGION Point+/all)
			{
				@property pointState() => tuple(((PS).名!q{PS})); 
				
				mixin SizeTemplate!("PS", 1); //Point size
				void reset_point(StateSide side)()
				{ state_PS	.resetState!(side); } void synch_point()
				{ synch_PS; } 
			}
			
			version(/+$DIDE_REGION Transform+/all)
			{
				@property transformState() => tuple(((TR).名!q{TR})); 
				
				static struct TransformationState
				{
					enum initialClipBounds = bounds2(-1e30, -1e30, 1e30, 1e30); 
					vec2 scaleXY = vec2(1); 
					float skewX_deg = 0; 
					float rotZ_deg = 0; 
					vec2 transXY = vec2(0); //in world space
					bounds2 clipBounds = initialClipBounds; //in world space
					//applied in this order
					
					void clipBounds_reset() { clipBounds = initialClipBounds; } 
				} 
				
				TransformationState user_TR, target_TR; 
				alias TR = user_TR; 
				
				void reset_transform(StateSide side)()
				{
					if(side & StateSide.user) user_TR = TransformationState.init; 
					if(side & StateSide.target) target_TR = TransformationState.init; 
				} 
				
				void synch_transform()
				{
					with(target_TR)
					{
						if(scaleXY.chkSet(user_TR.scaleXY))
						{
							if(scaleXY.x!=scaleXY.y)
							{
								emit(
									assemble(mixin(舉!((Opcode),q{setTrans})), mixin(舉!((TransFormat),q{scaleXY}))), 	assembleSize(scaleXY.x), 
										assembleSize(scaleXY.y)
								); 
							}
							else
							{ emit(assemble(mixin(舉!((Opcode),q{setTrans})), mixin(舉!((TransFormat),q{scale}))), assembleSize(scaleXY.x)); }
						}
						
						if(skewX_deg.chkSet(user_TR.skewX_deg))
						{ emit(assemble(mixin(舉!((Opcode),q{setTrans})), mixin(舉!((TransFormat),q{skewX}))), assembleAngle_deg(skewX_deg)); }
						
						if(rotZ_deg.chkSet(user_TR.rotZ_deg))
						{ emit(assemble(mixin(舉!((Opcode),q{setTrans})), mixin(舉!((TransFormat),q{rotZ}))), assembleAngle_deg(rotZ_deg)); }
						
						if(transXY.chkSet(user_TR.transXY))
						{ emit(assemble(mixin(舉!((Opcode),q{setTrans})), mixin(舉!((TransFormat),q{transXY}))), assemblePoint(transXY)); }
						
						if(clipBounds.chkSet(user_TR.clipBounds))
						{
							emit(
								assemble(mixin(舉!((Opcode),q{setTrans})), mixin(舉!((TransFormat),q{clipBounds}))), 	assemblePoint(clipBounds.topLeft),
									assemblePoint(clipBounds.size)
							); 
						}
					}
				} 
			}
			
			
			@property allState()
			=> tuple(
				colorState.expand, fontState.expand, lineState.expand, 
				pointState.expand, transformState.expand
			); 
			
			protected void resetState(StateSide side)()
			{
				reset_colors!(side), reset_font!(side), reset_line!(side), 
				reset_point!(side), reset_transform!(side); 
			} 
			
			void resetStyle()
			{ resetState!(StateSide.user); } 
			
			void setState(Args...)(in Args args)
			{
				void processArg(T)(in T a)
				{
					static if(isTuple!T) { static foreach(i; 0..T.length) processArg(a[i]); }
					else static if(is(T : GenericArg!(name, C), string name, C))
					{
						alias mixedInArg = a; 
						mixin(name~"=mixedInArg;"); 
					}
				} 
				static foreach(a; args) processArg(a); 
			} 
		}
		
		
	} 
	
	class GfxBuilder : GfxAssembler
	{
		alias This = typeof(this); 
		
		
		enum isCallable(alias fun, T) = 
			__traits(
			compiles, {
				auto b = new This; 
				mixin(iq{b.$(__traits(identifier, fun))(T.init); }.text); 
			}
		); 
		
		void drawC64Sprite(V)(in V pos, in int idx)
		{
			if(idx.inRange(0, 255))
			{
				begin(4, {}); synch_transform, synch_PALH, synch_FMH, synch_FH, synch_colors; 
				emit(
					mixin(舉!((Opcode),q{drawMove})), assemblePoint(pos),
					assemble(mixin(舉!((Opcode),q{drawFontASCII})), bits(1-1, 6), (cast(ubyte)(idx)))
				); 
			}
		} 
		
		void drawC64Rect(B)(in B bnd, in TexHandle texHandle = TexHandle(0))
		{
			begin(4, {}); synch_transform, synch_PALH, synch_colors; 
			emit(
				mixin(舉!((Opcode),q{drawMove}))	, assemblePoint(bnd.topLeft    ),
				mixin(舉!((Opcode),q{drawTexRect}))	, assemblePoint(bnd.bottomRight),
				assembleHandle(texHandle)
			); 
		} 
		
		void drawC64Border(ivec2 pos)
		{
			void r(int x0, int y0, int x1, int y1)
			{
				auto p(int x, int y) => (ivec2(x, y)+pos)*8; 
				drawC64Rect(ibounds2(p(x0, y0), p(x1, y1))); 
			} 
			r(0, 0, 4+40+4, 4); r(0, 4+25, 4+40+4, 4+25+4); 
			r(0, 4, 4, 4+25); r(4+40, 4, 4+40+4, 4+25); 
		} 
		
		void drawC64Screen(ivec2 pos, Image2D!RG img, int[3] bkCols, int borderCol)
		{
			PC(borderCol, 4); drawC64Border(pos-4); 
			foreach(y; 0..img.height)
			{ drawC64ChrRow((pos+ivec2(0, y))*8, img.row(y), bkCols[0]); }
		} 
		
		void drawC64ChrRow(
			//Texture palette, Texture fontTex, /+Todo: put these into state+/
			ivec2 pos, RG[] data, int bk
		)
		{
			if(data.empty) return; 
			
			int index = 0; 
			
			static RG[] fetchSameColor(ref RG[] data)
			{
				if(data.empty) return []; 
				const fg = data.front.y; 
				auto n = data.countUntil!((a)=>(a.y!=fg)); if(n<0) n = data.length; 
				auto res = data[0..n]; data = data[n..$]; return res; 
			} 
			
			index = 0; 
			Style((((cast(EGAColor)(bk))).名!q{bk})); 
			while(data.length)
			{
				auto act = fetchSameColor(data/+, remainingChars+/); 
				const nextIndex = index + act.length.to!int; 
				Style((((cast(EGAColor)(act[0].y))).名!q{fg})); 
				cursorPos = vec2(pos/8+ivec2(index, 0)); 
				textBackend(act.map!((a)=>((cast(AnsiChar)(a.x))))); 
				index = nextIndex; 
			}
		} 
		
		void drawPath(Args...)(in Args args)
		{
			void setup() { synch_transform, synch_colors, synch_LW; } 
			
			/+
				Bug: The splitter is WRONG, for a temporal fix, it gets a full begin() at each path
				The problem could be at start/end of line segments. The tangents are bad there!
			+/
			static if(0)	begin(6/+to be safe+/, {}); 
			else	begin/+full begin. for a fix+/; 
			
			setup; 
			static immutable NOP = assemble(mixin(舉!((Opcode),q{drawPathM})), mixin(舉!((XYFormat),q{relX})), mixin(舉!((CoordFormat),q{i8})), byte(0)); 
			
			vec2 P_start, P_last, P_mirror; //internal state
			
			void emitPathCmd(A...)(in char cmd, in Opcode op, in A args)
			{
				//cmd is for estimationb only.  It should use the SvgPathCommand...
				
				//Todo: compress XYFormat -> assembleXY()
				
				const est = bezierTesselationSettings.estimateVertexCount(cmd); 
				if(est + 4/*to be sure*/ > remainingVertexCount)
				{
					emit(
						assemble(mixin(舉!((Opcode),q{drawPathTG})), mixin(舉!((XYFormat),q{absXY})), mixin(舉!((CoordFormat),q{f32}))), args[0], 
						NOP, NOP
					); 
					end; begin; setup;  //Todo: this is bad and bogus.
					emit(
						assemble(mixin(舉!((Opcode),q{drawPathTG})), mixin(舉!((XYFormat),q{absXY})), mixin(舉!((CoordFormat),q{f32}))), P_mirror,
						assemble(mixin(舉!((Opcode),q{drawPathTG})), mixin(舉!((XYFormat),q{absXY})), mixin(舉!((CoordFormat),q{f32}))), P_last
					); 
					incVertexCount(2); //add extra to be sure
				}
				
				emit(op); incVertexCount(est); 
				static foreach(a; args) { emit(assemble(mixin(舉!((XYFormat),q{absXY})), mixin(舉!((CoordFormat),q{f32}))), a); }
			} 
			
			void onItem(const ref SvgPathItem item)
			{
				const ref P0()
				=> item.data[0]; const ref P1()
				=> item.data[1]; const ref P2()
				=> item.data[2]; const Pm()
				=> P_last*2 - P_mirror; void step(vec2 M, vec2 L)
				{ P_mirror = M, P_last = L; } 
				final switch(item.cmd)
				{
						/+drawing+/	/+state update+/	
					case SvgPathCommand.M: 	emitPathCmd('M', mixin(舉!((Opcode),q{drawPathM})), P0); 	step(P_last, P0),
					P_start = P0; 	break; 
					case SvgPathCommand.L: 	emitPathCmd('L', mixin(舉!((Opcode),q{drawPathL})), P0); 	step(P_last, P0); 	break; 
					case SvgPathCommand.Q: 	emitPathCmd('Q', mixin(舉!((Opcode),q{drawPathQ})), P0, P1); 	step(P0, P1); 	break; 
					case SvgPathCommand.T: 	emitPathCmd('T', mixin(舉!((Opcode),q{drawPathT})), P0); 	step(Pm, P0); 	break; 
					case SvgPathCommand.C: 	emitPathCmd('C', mixin(舉!((Opcode),q{drawPathC})), P0, P1, P2); 	step(P1, P2); 	break; 
					case SvgPathCommand.S: 	emitPathCmd('S', mixin(舉!((Opcode),q{drawPathS})), P0, P1); 	step(P0, P1); 	break; 
					/+redirected commands:+/			
					case SvgPathCommand.A: 	approximateArcToCubicBeziers
						(P_last, item, &onItem)
					/+Todo: move it to GPU+/
					/+
						Opt: Should do with a simplified 
						version of cubic bezier!
						because <90deg and no S curve
					+/; 		break; 
					case SvgPathCommand.Z: 	if(P_last!=P_start)
					{
						emitPathCmd(
							'L', mixin(舉!((Opcode),q{drawPathL})), 
							P_start
						); 
						/+
							Todo: move it	to GPU
							...bad	idea because vertexLimit
						+/
						/+Todo: only works for line, not curves+/
					}	step(P_start, P_start); 	break; 
				}
			} 
			
			
			SvgPathParser parser = void; bool parserInitialized = false; 
			void parse(in string s)
			{
				if(parserInitialized.chkSet) parser = SvgPathParser(&onItem); 
				parser.parse(s); 
			} 
			
			static foreach(i, a; args)
			{
				{
					alias T = Unqual!(Args[i]); 
					static if(isSomeString!T) { parse(a); }
				}
			}
			
			emit(NOP, NOP, NOP); incVertexCount(2); /+to be sure+/
		} 
		
		version(/+$DIDE_REGION Style+/all)
		{
			protected void applyStyleArg(T)(T a)
			{
				static if(is(T : GenericArg!(name, C), string name, C))
				{
					static if(name == "opacity") { OP = a.value; }
					else static if(name == "fg")	{ PC = a.value; }
					else static if(name == "bk")	{ SC = a.value; }
					else static assert(false, "Unsupported Style() named argument: " ~ T.stringof); 
				}
				else static if(is(T : FontSpec!F, F))	{ setFont(a); }
				else static assert(false, "Unsupported Style() argument: " ~ T.stringof); 
			} 
			
			enum isStyleArg(T) = isCallable!(applyStyleArg, T); ; 
			
			template AffectedStyleRegsOfType(T)
			{
				static if(is(T : GenericArg!(name, C), string name, C))
				{
					static if(name == "opacity")	alias AffectedStyleRegsOfType = AliasSeq!(q{OP}); 
					else static if(name == "fg")	alias AffectedStyleRegsOfType = AliasSeq!(q{PC}); 
					else static if(name == "bk")	alias AffectedStyleRegsOfType = AliasSeq!(q{SC}); 
				}
			} 
			
			template AffectedStyleRegs(Args...)
			{
				template CollectTypes(alias Pred, Args...)
				{
					template ProcessArg(A)
					{
						static if(isTuple!A)	alias ProcessArg = Filter!(Pred, A.Types); 
						else static if(Pred!A)	alias ProcessArg = A; 
						else	alias ProcessArg = AliasSeq!(); 
					} 
					alias CollectTypes = NoDuplicates!(staticMap!(ProcessArg, Args)); 
				} 
				
				enum regs = staticMap!(AffectedStyleRegsOfType, CollectTypes!(isStyleArg, Args)); 
				static if(regs.length)	enum AffectedStyleRegs = [NoDuplicates!regs]; 
				else	enum AffectedStyleRegs = string[].init; 	
			} 
			
			
			void Style(Args...)(Args args)
			{
				void processArg(T)(T a)
				{
					static if(isTuple!T) { static foreach(i; 0..T.length) processArg(a[i]); }
					else applyStyleArg(a); 
				} 
				
				static foreach(i, a; args) { processArg/+!(Unqual!(Args[i]))+/(a); }
			} 
		}
		
		
		version(/+$DIDE_REGION Cursor+/all)
		{
			vec2 cursorPos; 
			
			alias cr = cursorPos; 
			
			struct M { vec2 value; this(A...)(in A a) { value = vec2(a); } } 
			struct m { vec2 value; this(A...)(in A a) { value = vec2(a); } } 
			
			struct Mx { float value=0; this(A)(in A a) { value = float(a); } } 
			struct mx { float value=0; this(A)(in A a) { value = float(a); } } 
			struct My { float value=0; this(A)(in A a) { value = float(a); } } 
			struct my { float value=0; this(A)(in A a) { value = float(a); } } 
			
			protected void applyCursorArg(T)(in T a)
			{
				static if(is(T : M))	cursorPos = a.value; 
				else static if(is(T : Mx))	cursorPos.x = a.value; 
				else static if(is(T : My))	cursorPos.y = a.value; 
				else static if(is(T : m))	cursorPos += a.value; 
				else static if(is(T : mx))	cursorPos.x += a.value; 
				else static if(is(T : my))	cursorPos.y += a.value; 
				else static if(
					is(T : GenericArg!(name, E), string name, E) 
					&& name.startsWith("cr")
				)
				{
					alias mixedInArg = a; 
					mixin(name~"=mixedInArg.value;"); 
				}
				else { static assert(false, "Unhandled Cursor() argument: "~T.stringof); }
			} 
			
			enum isCursorArg(T) = __traits(
				compiles, {
					auto b = new GfxBuilder; 
					with(b) b.applyCursorArg(T.init); 
				}
			) || (
				is(T : GenericArg!(name, E), string name, E) 
					&& name.startsWith("cr")
			); 
		}
		
		version(/+$DIDE_REGION+/all) {
			void Text(Args...)(Args args)
			{
				//this work on temporal graphics state
				/+Must not use const args!!!! because /+Code: chain(" ", str)+/ fails.+/
				
				mixin(scope_remember(AffectedStyleRegs!Args.join(','))); 
				
				void processArg(T)(T a)
				{
					static if(isTuple!T) { static foreach(i; 0..T.length) processArg(a[i]); }
					else static if(isStyleArg!T)	{ applyStyleArg(a); }
					else static if(isCursorArg!T)	applyCursorArg(a); 
					else static if(isSomeString!T)	textBackend(a); 
					else static if(isSomeChar!T)	textBackend(only(a)); 
					else static if(
						isInputRange!T &&
						(
							isSomeChar!(ElementType!T)
							||is(ElementType!T : AnsiChar)
						)
					)	{ textBackend(a); }
					else static if(isDelegate!T) a(); 
					else static if(isFunction!T) a(); 
					else
					{
						pragma(msg,i"$(T.stringof) $(isCallable!(applyStyleArg, T))".text.注); 
						static assert(false, "Unhandled Text() argument: "~T.stringof); 
					}
				} 
				
				static foreach(i, a; args) { processArg/+!(Unqual!(Args[i]))+/(a); }
			} 
			
			void textBackend(R)(R input)
			{
				if(input.empty) return; 
				
				alias _builder = this; 
				
				void setup()
				{
					with(_builder)
					{
						synch_transform, synch_PALH, synch_FMH, synch_FH, synch_colors; 
						emit(mixin(舉!((Opcode),q{drawMove})), assemblePoint(cursorPos*fontSize)); 
					}
				} 
				_builder.begin(0, {}); 
				setup; 
				
				version(/+$DIDE_REGION Convert various types to 8bit ASCII, reuse allocated temp memory.+/all)
				{
					static Appender!(ubyte[]) app; app.clear; 
					ubyte[] rawSrc; 
					alias E = ElementType!R; 
					static if(isDynamicArray!R && is(E : AnsiChar) /+fastest way+/)
					{ rawSrc = (cast(ubyte[])(input)); }
					else static if(isInputRange!R && is(E : AnsiChar) /+buffer the inputRange+/)
					{ app.put(input); rawSrc = (cast(ubyte[])(app[])); }
					else static if(isInputRange!R && isSomeChar!E /+convert fron normal string+/)
					{ app.put(input.map!toAnsiChar); rawSrc = (cast(ubyte[])(app[])); }
					else static assert(false, "unhandled element type: "~E.stringof); 
				}
				
				uint decideCharCount(int len)
				{
					enum maxChars = 1<<6/+bits, base1 (0 means 1, 63 means 64)+/; 
					const uint 	space 	= max(_builder.remainingVertexCount-2, 0)/2,
						n	= len.min(min(space, maxChars)); 
					if(n) _builder.incVertexCount(n*2+2); return n; 
				} 
				
				encodeRLE
				(
					rawSrc, 3,
					((ubyte[] part) {
						while(1)
						{
							if(const n = decideCharCount((cast(int)(part.length))))
							{
								_builder.emit(assemble(mixin(舉!((Opcode),q{drawFontASCII})), bits(n-1, 6)), part[0..n]); 
								cursorPos.x += n; part = part[n..$]; if(part.empty) break; 
							}
							/+start next geometry item+/_builder.begin; setup; 
						}
					}),
					((ubyte ch, uint len) {
						while(1)
						{
							if(const n = decideCharCount(len))
							{
								_builder.emit(assemble(mixin(舉!((Opcode),q{drawFontASCII_rep})), bits(n-1, 6)), ch); 
								cursorPos.x += n; len -= n; if(!len) break; 
							}
							/+start next geometry item+/_builder.begin; setup; 
						}
					})
				); 
				
				version(/+$DIDE_REGION Don't waste memory for exceptionally large texts+/all)
				{
					enum tooLargeBuf = 0x1000; 
					if(app.length>tooLargeBuf) { app.shrinkTo(tooLargeBuf); }
				}
			} 
		}
		
		
	} 
	
	class TurboVisionBuilder : GfxBuilder
	{
		mixin InjectEnumMembers!EGAColor; 
		
		enum clMenuBk 	= ((ltGray).名!q{bk}), 
		clMenuText 	= ((black).名!q{fg}), 
		clMenuKey	= ((red).名!q{fg}),
		clMenuItem 	= tuple(clMenuText, clMenuBk),
		clMenuSelected 	= tuple(clMenuText, ((green).名!q{bk})),
		clMenuDisabled 	= tuple(((dkGray).名!q{fg}), clMenuBk); 
		
		enum clWindowBk	= ((blue).名!q{bk}),
		clWindowText 	= ((white).名!q{fg}),
		clWindow 	= tuple(clWindowText, clWindowBk),
		clWindowClickable 	= tuple(((ltGreen).名!q{fg}), clWindowBk); 
		
		enum clScrollBar = tuple(((blue).名!q{fg}), ((cyan).名!q{bk})); 
		
		static struct MenuItem
		{
			string title, shortcut, hint; 
			bool selected, disabled, opened; 
			MenuItem[] subMenu; 
		} 
		
		void drawMenuTitle(Args...)(in MenuItem item, Args extra)
		{
			const clNormal = 	item.disabled 	? clMenuDisabled : 
				item.selected 	? clMenuSelected 
					: clMenuItem; 
			const s = item.title, aidx = s.byDchar.countUntil('&'); 
			if(aidx < 0) { Text(clNormal, chain(" ", s , " ")); }
			else {
				Text(
					clNormal, 	chain(" ", mixin(指(q{s},q{0..aidx}))), 
					clMenuKey, 	mixin(指(q{s},q{aidx+1})), 
					clNormal, 	chain(mixin(指(q{s},q{aidx+2..$})), " "),
					extra
				); 
			}
		} 
		
		void drawSubMenu(R)(R items)
			if(isForwardRange!(R, MenuItem))
		{
			sizediff_t measureItemWidth(in MenuItem item)
			=> item.title.filter!q{a!='&'}.walkLength + 2
			+ ((item.shortcut.empty)?(0):(item.shortcut.walkLength + 2)); 
			
			const maxWidth = items.save.map!measureItemWidth.maxElement; 
			vec2 pos = cursorPos; void NL() { pos += vec2(0, 1); Text(M(pos)); } 
			Style(clMenuItem); 
			
			void shadow(size_t n) { Text(((black).名!q{bk}), ((.6).名!q{opacity}), " ".replicate(n)); } 
			
			Text(chain(" ┌", "─".replicate(maxWidth), "┐ ")); NL; 
			foreach(item; items)
			{
				Text(" │"); 
				const space = maxWidth - measureItemWidth(item); 
				if(item.shortcut!="")
				{ drawMenuTitle(item, chain(' '.repeat.take(space+1), item.shortcut, " ")); }
				else
				{ drawMenuTitle(item, ' '.repeat.take(space)); }
				Text("│ "); shadow(2); NL; 
			}
			Text(chain(" └", '─'.repeat.take(maxWidth), "┘ ")); shadow(2); NL; 
			Text(mx(2)); shadow(maxWidth+4); 
		} 
		
		void drawMainMenu(R)(R items)
			if(isForwardRange!(R, MenuItem))
		{
			foreach(item; items)
			{
				const pos = cursorPos; 
				drawMenuTitle(item); 
				if(item.opened && !item.subMenu.empty)
				{
					mixin(scope_remember(q{cursorPos})); 
					Text(M(pos), my(1)); //move the cursor
					drawSubMenu(item.subMenu); 
				}
			}
		} 
		
		void drawTextWindow(R)(string title, ibounds2 bnd, R lines)
		{
			void Btn(string s)
			{ Text(clWindow, "[", clWindowClickable, s, clWindow, "]"); } 
			
			Style(clWindow); 
			Text(
				M(bnd.topLeft), (((互!((float/+w=3 min=-10 max=10+/),(0.000),(0x13A8782886ADB)))).名!q{cr.x+}), "╔═", { Btn("■"); }, 
				chain(" ", title, " ").text.center(bnd.width-12, '═'), "1═",
				{ Btn("↕"); }, "═╗"
			); 
			const w = bnd.width-2, h = bnd.height-2; 
			foreach(line; lines.padRight("", h).take(h))
			{
				Text(Mx(bnd.left), my(1), '║'); 
				string s = line.replace('\t', "    ").padRight(' ', w).takeExactly(w).text; 
				enum enableSyntaxHighlight = true/+note, it's extremely slow!+/; 
				static if(enableSyntaxHighlight)
				{
					foreach(word; s.splitWhen!((a,b)=>(a.isAlphaNum!=b.isAlphaNum)))
					{
						enum keywords = ["program", "var", "begin", "end", "integer"]; 
						const isKeyword = keywords.canFind(word.text.lc); 
						Text(((isKeyword)?(((white).名!q{fg})):(((yellow).名!q{fg}))) , word); 
					}
				}
				else
				{ Text(s); }
				Text(
					clScrollBar, predSwitch(
						cursorPos.y-bnd.top-1, 
						0, '▲', 1, '■', h-1, '▼', '▒'
					)
				); 
			}
			Text(
				M(bnd.bottomLeft), my(-1), "╚═",
				chain(" ", "1:1", " ").text.center(17, '═'),
				clScrollBar, chain("◄", "■", '▒'.repeat.take(bnd.width-24), "►"),
				clWindowClickable, "─┘"
			); 
		} 
		
		void fillSpace(int width=80) { while(cursorPos.x<width) Text(' '); } 
		
		
		/+
			/+
				Para: 	00	01	02	03	04	05	06	07	08	09	0A	0B	0C	0D	0E	0F
				00	�	☺	☻	♥	♦	♣	♠	•	◘	○	◙	♂	♀	♪	♫	☼
				10	►	◄	↕	‼	¶	§	▬	↨	↑	↓	→	←	∟	↔	▲	▼
				20	 	!	"	#	$	%	&	'	(	)	*	+	,	-	.	/
				30	0	1	2	3	4	5	6	7	8	9	:	;	<	=	>	?
				40	@	A	B	C	D	E	F	G	H	I	J	K	L	M	N	O
				50	P	Q	R	S	T	U	V	W	X	Y	Z	[	\	]	^	_
				60	`	a	b	c	d	e	f	g	h	i	j	k	l	m	n	o
				70	p	q	r	s	t	u	v	w	x	y	z	{	|	}	~	⌂
				80	Ç	ü	é	â	ä	à	å	ç	ê	ë	è	ï	î	ì	Ä	Å
				90	É	æ	Æ	ô	ö	ò	û	ù	ÿ	Ö	Ü	¢	£	¥	₧	ƒ
				A0	á	í	ó	ú	ñ	Ñ	ª	º	¿	⌐	¬	½	¼	¡	«	»
				B0	░	▒	▓	│	┤	╡	╢	╖	╕	╣	║	╗	╝	╜	╛	┐
				C0	└	┴	┬	├	─	┼	╞	╟	╚	╔	╩	╦	╠	═	╬	╧
				D0	╨	╤	╥	╙	╘	╒	╓	╫	╪	┘	┌	█	▄	▌	▐	▀
				E0	α	ß	Γ	π	Σ	σ	µ	τ	Φ	Θ	Ω	δ	∞	φ	ε	∩
				F0	≡	±	≥	≤	⌠	⌡	÷	≈	°	∙	·	√	ⁿ	²	■	 
			+/
		+/
	} 
	
	
}








class VulkanWindow: Window, IGfxContentDestination
{
	version(/+$DIDE_REGION+/all) {
		auto getGfxContentDestination() => (cast(IGfxContentDestination)(this)); 
		
		/+
			Todo: handle VK_ERROR_DEVICE_LOST.	It can be caused by an external bug 
			when the GPU freezes because of another app, and then restarts.
		+/
		
		static struct BufferSizeConfigs
		{ VulkanBufferSizeConfig VBConfig, GBConfig, IBConfig, TBConfig; } 
		
		BufferSizeConfigs bufferSizeConfigs =
		mixin(體!((BufferSizeConfigs),q{
			VBConfig : 	mixin(體!((VulkanBufferSizeConfig),q{
				minSizeBytes 	: ((  4)*(KiB)), 
				maxSizeBytes 	: ((256)*(MiB)),
				growRate : 2.0,
				shrinkWhen 	: 0.25, 
				shrinkRate 	: 0.5
			})),
			GBConfig : 	mixin(體!((VulkanBufferSizeConfig),q{
				minSizeBytes 	: ((  4)*(KiB)), 
				maxSizeBytes 	: ((256)*(MiB)),
				growRate : 2.0,
				shrinkWhen 	: 0.25, 
				shrinkRate 	: 0.5
			})),
			IBConfig : 	mixin(體!((VulkanBufferSizeConfig),q{
				minSizeBytes 	: ((  4)*(KiB)), 
				maxSizeBytes 	: (( 16)*(MiB)),
				growRate : 2.0,
				shrinkWhen 	: 0.25, 
				shrinkRate 	: 0.5
			})),
			TBConfig : 	mixin(體!((VulkanBufferSizeConfig),q{
				minSizeBytes 	: ((  1)*(MiB)), 
				maxSizeBytes 	: ((768)*(MiB)),
				growRate : 2.0,
				shrinkWhen 	: 0.25, 
				shrinkRate 	: 0.5
			}))
		})); 
		enum HeapGranularity 	= 16,
		DelayedTextureLoading 	= (常!(bool)(1)); 
		
		struct Stats
		{
			size_t V_cnt, V_size, G_size; 
			@property VG_size() => V_size + G_size; 
		} 
		Stats lastFrameStats; 
		
		VulkanInstance vk; 
		VulkanSurface surface; 
		VulkanPhysicalDevice physicalDevice; 
		VulkanQueueFamily queueFamily; 
		
		VulkanDevice device; 
		VulkanQueue queue; 
		
		VulkanSemaphore 	imageAvailableSemaphore,
			renderingFinishedSemaphore; 
		
		VulkanCommandPool commandPool; 
		
		VulkanSwapchain swapchain; 
		VulkanRenderPass renderPass; 
		
		VulkanDescriptorSetLayout descriptorSetLayout; 
		VulkanPipeline graphicsPipeline; 
		VulkanPipelineLayout pipelineLayout; 
		
		VulkanDescriptorPool descriptorPool; 
		VulkanDescriptorSet descriptorSet; 
		
		VulkanGraphicsShaderModules shaderModules; 
		
		Object[] buffers; 
		
		bool windowResized; 
		
		VkClearValue clearColor = { color: {float32: [ 0.1, 0.1, 0.1, 0 ]}, }; 
		
		
		/+
			/+
				Code: struct State
				{
					vec3 base; //def=0
					vec3 scale; //def=1
					vec3 last, act; //def=0
				} 
				
				struct CoordConfig
				{
					bool rel; 
					bool f32, u32, i32, u16, i16, u8, i8; 
				} 
				
				enum Inst
				{
					cfg, //rel, dt
					cfg_x, //rel, dt
					cfg_y, //rel, dt
					cfg_z, //rel, dt
					move_abs_u8_u8
				} 
				
				
				
				enum Primitive
				{
					triangles_2d_f32_constantColor
					triangles_2d_f32_flatColor
					triangles_2d_f32_smoothColor
					triangleStrip_2d_f32_constantColor
					triangleStrip_2d_f32_flatColor
					triangleStrip_2d_f32_smoothColor
				} 
				
				struct VertexInput
				{
					uint cmd; float x, y, z; 
					int tile_x, tile_y; RGBA col0, col1; 
					bounds2 clipBounds; 
				} 
			+/
		+/
		
		/+
			Note: Alignment rules:
			
			/+
				Bullet: /+Bold: minMemoryMapAlignment+/ (Fury=4096, RX580=64, RTX4080=64) s the minimum required alignment, in bytes, 
				of host visible memory allocations within the host address space. When mapping a memory 
				allocation with vkMapMemory, subtracting offset bytes from the returned pointer will always 
				produce an integer multiple of this limit.
				/+Nem erdekel, mert vele foglaltatom a cpu memoriat es az egesz buffert mappolom.+/
			+/
			
			/+
				Bullet: /+Bold: minUniformBufferOffsetAlignment+/ (Fury=4, RX580=64, RTX4080=64) is the minimum required alignment, in 
				bytes, for the offset member of the VkDescriptorBufferInfo structure for uniform buffers. When 
				a descriptor of type VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER or 
				VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC is updated, the offset must be an integer 
				multiple of this limit. Similarly, dynamic offsets for uniform buffers must be multiples of this limit.
				/+Nem erdekel, mert a teljes buffert bekuldom.+/
			+/
			
			/+
				Bullet: /+Bold: minStorageBufferOffsetAlignment+/ (Fury=4, RX580=4, RTX4080=16) is the minimum required alignment, in bytes, 
				for the offset member of the VkDescriptorBufferInfo structure for storage buffers. When a 
				descriptor of type VK_DESCRIPTOR_TYPE_STORAGE_BUFFER or 
				VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC is updated, the offset must be an integer 
				multiple of this limit. Similarly, dynamic offsets for storage buffers must be multiples of this limit.
				/+Nem erdekel, mert nalam is 4 a minimum align (4=GPU addressable unit).+/
			+/
			
			// Flush the memory range
			// If the memory type of stagingMemory includes VK_MEMORY_PROPERTY_HOST_COHERENT, skip this step
			
			// Align to the VkPhysicalDeviceProperties::nonCoherentAtomSize
			uint32_t alignedSize = (vertexDataSize-1) - ((vertexDataSize-1) % nonCoherentAtomSize) + nonCoherentAtomSize;
		+/
		
		
		
		
		version(/+$DIDE_REGION UB    +/all)
		{
			struct UniformData
			{
				mat4 transformationMatrix, inverseTransformationMatrix; 
				vec4 viewport; 
				float iTime=0; 
			} 
			
			UniformBufferManager UB; 
			
			class UniformBufferManager
			{
				protected UniformData* uniformDataPtr; 
				protected VulkanMemoryBuffer uniformMemoryBuffer; 
				
				ref access() => *uniformDataPtr; 
				
				void flush()
				{
					uniformMemoryBuffer.flush; //only is not coherent!
				} 
				
				
				this()
				{
					//uniformDataPtr = (cast(UniformData*)(virtualAlloc(UniformData.sizeof))); 
					uniformMemoryBuffer = device.createMemoryBuffer
						(
						UniformData.sizeof/+Bug: alignment!!!+/, 
						mixin(幟!((VK_MEMORY_PROPERTY_),q{HOST_VISIBLE_BIT | HOST_COHERENT_BIT})), mixin(舉!((VK_BUFFER_USAGE_),q{UNIFORM_BUFFER_BIT}))
					); 
					uniformDataPtr = (cast(UniformData*)(uniformMemoryBuffer.map)); 
				} 
				
				~this()
				{
					uniformMemoryBuffer.free; 
					virtualFree(uniformDataPtr); 
				} 
			} 
		}
		
		version(/+$DIDE_REGION VB    +/all)
		{
			struct VertexData
			{ uint geometryStreamBitOfs; } static assert(VertexData.sizeof == 4); 
			
			VertexBufferManager VB; 
			
			class VertexBufferManager
			{
				protected VulkanAppenderBuffer buffer; 
				protected uint _uploadedVertexCount; 
				@property uploadedVertexCount() const => _uploadedVertexCount; 
				
				this()
				{
					buffer = new VulkanAppenderBuffer
						(device, queue, commandPool, mixin(幟!((VK_BUFFER_USAGE_),q{VERTEX_BUFFER_BIT})), bufferSizeConfigs.VBConfig); 
					/+Todo: Do the whole drawing thing it in multiple parts when max was reached+/
				} 
				
				~this()
				{ buffer.free; } 
				
				void reset()
				{ buffer.reset; } 
				
				final void append(VertexData data)
				{ buffer.append(data); } final void opCall(T...)(in T args)
				{ append(args); } 
				
				final void append(uint[], uint shift=0)
				{} 
				
				void upload()
				{
					buffer.upload; 
					_uploadedVertexCount = (buffer.appendPos / VertexData.sizeof).to!uint; 
					with(lastFrameStats) {
						V_size 	= buffer.appendPos,
						V_cnt 	= _uploadedVertexCount; 
					}
				} 
				
				@property deviceMemoryBuffer() => buffer.deviceMemoryBuffer; 
			} 
		}
		
		version(/+$DIDE_REGION GB    +/all)
		{
			GeometryBufferManager GB; 
			
			class GeometryBufferManager
			{
				protected VulkanAppenderBuffer buffer; 
				
				this()
				{
					buffer = new VulkanAppenderBuffer
						(device, queue, commandPool, mixin(幟!((VK_BUFFER_USAGE_),q{STORAGE_BUFFER_BIT})), bufferSizeConfigs.GBConfig); 
				} 
				
				~this()
				{ buffer.free; } 
				
				void reset()
				{ buffer.reset; } 
				
				//returns byte idx
				
				@property uint bitPos() => buffer.bitPos.to!uint /+Opt: check the range ocassionally+/; 
				
				void append(Args...)(in Args args)
				{
					static foreach(i, T; Args)
					{
						{
							alias a = args[i]; 
							static if(is(T : Opcode))	with(opInfo[a]) buffer.appendBits(bits, bitCnt); 
							else static if(is(T : Bits!(B), B))	buffer.appendBits(a.data, a.bitCnt); 
							else static if(is(T==enum))	buffer.appendBits(a, EnumBits!T); 
							else static if(is(T : RGBA))	buffer.appendBits(a.raw, 32); 
							else static if(is(T : RGB))	buffer.appendBits(a.raw, 24); 
							else static if(is(T : vec2))	buffer.appendBits(a.bitCast!ulong); 
							else static if(is(T : ulong))	buffer.appendBits(a); 
							else static if(is(T : uint))	buffer.appendBits(a); 
							else static if(is(T : ushort))	buffer.appendBits(a); 
							else static if(is(T : ubyte))	buffer.appendBits(a); 
							else static assert(0, "Unhandled type "~T.stringof); 
						}
					}
				} 
				
				final void opCall(T...)(in T args)
				{ append(args); } 
				
				void upload()
				{
					buffer.upload; 
					with(lastFrameStats) { G_size 	= buffer.appendPos; }
					
					//if(inputs.Shift.down) (cast(ubyte*)(buffer.hostPtr))[0..buffer.appendPos].saveTo(`c:\dl\a.a`); 
				} 
				
				@property deviceMemoryBuffer() => buffer.deviceMemoryBuffer; 
				
				/+
					Todo: Smart Memoty Access a GB-re meg a VB-re, meg az IB-re!
					
					Egy fontos adalek ehhez a Smart Access Memory technikahoz:
					AMD modded driver segitsegevel a regebbi kartyakat fel lehet kesziteni arra, hogy ne csak 
					256MB SAM memoria legyen, hanem a teljes GPU memoria az legyen.
					Az en GPU-m is meg a benti is pont 1 verzioval regebbi (GCN3) de lehet, hogy tevedek 
					es azoknal is tamogatva van. Ha ezt ki tudnam hasznalni az azt jelentene, hogy a kamera 
					kepeket is meg az ui grafika adatait is 2x olyan gyorsan tudnam felkuldeni, mint a 
					hagyomanyos modszerrel, amit most hasznalok.
					
					Hogy Intellel, NVidiaval mukodik-e ez, azt nem tudom, ez egy opcionalis lehetoseg lesz es 
					ki akarom hasznalni.  A lenyege a dolognak, hogy kozvetlenul a PCIE buszra tortenik a kiiras. 
					A CPU hasznalat ugyanaz marad, de nem kell utana egy PCIE DMA transfert is inditani.
				+/
			} 
			
			void appendGfxContent(in GfxContent content)
			{
				if(content.empty) return; 
				
				void doit()
				{
					GB.buffer.alignTo(16); 
					const shift = GB.bitPos; 
					GB.buffer.append(content.gb); 
					static assert(VertexData.sizeof==uint.sizeof); 
					VB.buffer.appendUints((cast(uint[])(content.vb)), shift); 
				} 
				
				synchronized doit; 
			} 
			
			void consumeGfxContent(GfxBuilder builder)
			{
				if(builder && !builder.empty)
				{
					appendGfxContent(builder.toGfxContent); 
					builder.resetStream; 
				}
			} 
		}
		
		version(/+$DIDE_REGION IB     +/all)
		{
			static struct TexInfo
			{
				TexSizeFormat sizeFormat; 
				HeapChunkIdx heapChunkIdx; 
				uint extra; 
				
				string toString() const
				=> format!"TexInfo(%s, chunk:%d, extra:%d)"
				(sizeFormat, heapChunkIdx.to!uint, extra); 
				
				static assert(TexInfo.sizeof==16); 
			} 
			
			InfoBufferManager IB; 
			class InfoBufferManager
			{
				protected
				{
					VulkanArrayBuffer!TexInfo buffer; 
					TexHandle[] freeHandles; 
				} 
				
				
				this()
				{
					buffer = new VulkanArrayBuffer!TexInfo
						(
						device, queue, commandPool, mixin(幟!((VK_BUFFER_USAGE_),q{STORAGE_BUFFER_BIT})), 
						bufferSizeConfigs.IBConfig
					); 
					
					//create the very first handle
					const nullHandle = buffer.append(TexInfo.init); 
					enforce(!nullHandle && buffer.length==1); 
				} 
				
				~this()
				{ buffer.free; } 
				
				bool isValidHandle(in TexHandle handle) const
				=> handle.inRange(1, buffer.length); 
				
				TexHandle add(in TexInfo info)
				{
					TexHandle handle; 
					if(!freeHandles.empty)
					{ handle = freeHandles.fetchBack; }
					else
					{
						const h = buffer.append(info); 
						if(h && h<=uint.max /+overflow check+/)
						{ handle = (cast(TexHandle)((cast(uint)(h)))); }
					}
					
					if(handle)
					buffer[(cast(uint)(handle))] = info; 
					
					return handle; 
				} 
				
				void remove(in TexHandle handle)
				{
					if(!handle) return; 
					assert(isValidHandle(handle)); 
					buffer[(cast(uint)(handle))] = TexInfo.init; 
					freeHandles ~= handle; 
				} 
				
				TexInfo access(in TexHandle handle)
				{
					assert(isValidHandle(handle)); 
					return buffer[(cast(uint)(handle))]; 
				} 
				
				void set(in TexHandle handle, in TexInfo info)
				{
					assert(isValidHandle(handle)); 
					buffer[(cast(uint)(handle))] = info; 
				} 
			} 
			
		}
		
		version(/+$DIDE_REGION TB     +/all)
		{
			TextureBufferManager TB; 
			
			class TextureBufferManager
			{
				alias HeapBuffer = VulkanHeapBuffer!HeapGranularity; 
				static struct TexRec
				{
					TexHandle texHandle; 	//index into IB (InfoBuffer) enties
					uint lastAccessed; 	//last application.tick value of most recent access
					DateTime modified; 	//last bitmap.modified value for automatic reload
				} 
				static assert(TexRec.sizeof==16); 
				
				protected HeapBuffer buffer; 
				protected TexRec[File] texRecByFile; 
				const TexRec nullTexRec = TexRec.init; 
				
				this()
				{
					buffer = new HeapBuffer
						(device, queue, commandPool, mixin(幟!((VK_BUFFER_USAGE_),q{STORAGE_BUFFER_BIT})), mixin(舉!((bufferSizeConfigs),q{TBConfig}))); 	
					
					/+
						buffer.heapInit; 	((0x318E82886ADB).檢((update間(_間)))); 
						buffer.allocator.stats.print; 	((0x31DE82886ADB).檢((update間(_間)))); 
							
						uint[] sizes = mixin(求map(q{0<i<35000},q{},q{uint(i)})).array; 	((0x325882886ADB).檢((update間(_間)))); 
						import std.random; auto rnd = MinstdRand0(42); 	((0x32B982886ADB).檢((update間(_間)))); 
						
						if((常!(bool)(1))) { sizes.randomShuffle(rnd); }	((0x332282886ADB).檢((update間(_間)))); 
						sizes.take(20).print; 	((0x336A82886ADB).檢((update間(_間)))); 
						auto addrs = mixin(求map(q{i},q{sizes},q{
							() {
								auto a = buffer.heapAlloc(i); 
								if((常!(bool)(1))) IB.add(TexInfo(TexPtr(a.heapAddr))); 
								return a.heapAddr; 
							} ()
						})).array; 	((0x346F82886ADB).檢((update間(_間)))); 
						IB.buffer.upload; 	((0x34B382886ADB).檢((update間(_間)))); 
						addrs.take(20).print; 	((0x34FB82886ADB).檢((update間(_間)))); 
						if((常!(bool)(1))) { addrs.randomShuffle(rnd); }	((0x355E82886ADB).檢((update間(_間)))); 
						buffer.allocator.stats.print; 	((0x35AE82886ADB).檢((update間(_間)))); 
						mixin(求each(q{a},q{addrs},q{buffer.heapFree(buffer.calcHeapPtr(a))})); 	((0x362982886ADB).檢((update間(_間)))); 
						buffer.allocator.stats.print; 	((0x367982886ADB).檢((update間(_間)))); 
					+/
				} 
				
				~this()
				{ buffer.free; } 
				
				auto extractBitmapData(Bitmap bmp)
				{
					TexSizeFormat fmt; 
					const(void)[] data; 
					
					void doUnsupported()
					{
						fmt.size = ivec2(1); 
						fmt.format = TexFormat.rgba_u8; 
						data = [0xFFFF00FF]; 
					} 
					
					if(bmp && bmp.valid)
					{}
					else
					{
						//bmp is null
					}
					
					fmt.size = ivec2(bmp.size); 
					data = bmp.getRaw; 
					
					
					/+
						if(bmp.channels.inRange(1, 4))
						{
							switch(bmp.format)
							{
								case "ubyte": 	switch(bmp.channels)
								{
									case 1: 	fmt.format = TexFormat.u8; 	data = bmp.getRaw; 	break; 
									case 2: 	fmt.format = TexFormat.rg_u8; 	data = bmp.getRaw; 	break; 
									case 3: 	fmt.format = TexFormat.rgb_u8; 	data = bmp.getRaw; 	break; 
									case 4: 	fmt.format = TexFormat.rgba_u8; 	data = bmp.getRaw; 	break; 
									default: 	unsupported; 
								}	break; 
								case "float": 	switch(bmp.channels)
								{
									case 1: 	fmt.format = TexFormat.f32; 	data = bmp.getRaw; 	break; 
									case 2: 	fmt.format = TexFormat.rg_f32; 	data = bmp.getRaw; 	break; 
									case 3: 	fmt.format = TexFormat.rgb_f32; 	data = bmp.getRaw; 	break; 
									case 4: 	fmt.format = TexFormat.rgba_f32; 	data = bmp.getRaw; 	break; 
									default: 	unsupported; 
								}	break; 
								case "ushort": 	switch(bmp.channels)
								{
									case 1: 	fmt.format = TexFormat.u16; 	data = bmp.getRaw; 	break; 
									case 2: 	fmt.format = TexFormat.rg_u16; 	data = bmp.getRaw; 	break; 
									case 3: 	fmt.format = TexFormat.rgb_u16; 	data = bmp.getRaw; 	break; 
									case 4: 	fmt.format = TexFormat.rgba_u16; 	data = bmp.getRaw; 	break; 
									default: 	unsupported; 
								}	break; 
								default: 	unsupported; 
							}
						}
						
					+/
					return tuple(fmt, data); 
				} 
				
				protected TexHandle createHandleAndSetData(in TexSizeFormat fmt, in void[] data)
				{
					if(auto heapRef = buffer.heapAlloc(data.length))
					{
						const texInfo = mixin(體!((TexInfo),q{
							sizeFormat 	: fmt, 
							heapChunkIdx 	: heapRef.heapChunkIdx,
							extra 	: 0
						})); 
						if(const texHandle = IB.add(texInfo))
						{
							memcpy(heapRef.ptr, data.ptr, data.length); /+Note: ⚡ Memory transfer (process → host) +/
							buffer.markModified(heapRef.ptr, data.length); 
							return texHandle; /+Note: ✔ Success+/
						}
						else
						{ buffer.heapFree(heapRef); /+Note: 🚫 Failed to allocate handle+/}
					}
					else
					{/+Note: 🚫 Failed to allocate memory+/}
					return TexHandle.init; 
				} 
				
				protected bool updateExistingData(in TexHandle handle, in TexSizeFormat fmt, in void[] data)
				{
					auto info = IB.access(handle); 
					buffer.heapFree(info.heapChunkIdx); 
					info.heapChunkIdx = HeapChunkIdx(0); 
					if(auto heapRef = buffer.heapAlloc(data.length))
					{
						info.sizeFormat = fmt; 
						memcpy(heapRef.ptr, data.ptr, data.length); /+Note: ⚡ Memory transfer (process → host) +/
						buffer.markModified(heapRef.ptr, data.length); 
						info.heapChunkIdx = heapRef.heapChunkIdx; 
						IB.set(handle, info); 
						return true; /+Note: ✔ Success+/
					}
					else
					{
						IB.set(handle, info); //upload the info with null pointer.
						return false; /+Note: 🚫 Failed to allocate memory+/
					}
				} 
				
				void remove(in TexHandle texHandle)
				{
					if(texHandle)
					{
						if(const heapChunkIdx = IB.access(texHandle).heapChunkIdx)
						{ buffer.heapFree(heapChunkIdx); }
						IB.remove(texHandle); 
					}
				} 
				
				void remove(File file)
				{
					if(const texRec = file in texRecByFile)
					{
						remove(texRec.texHandle); 
						texRecByFile.remove(file); 
					}
				} 
				
				TexRec* access(File file, in Flag!"delayed" delayed_)
				{
					const delayed = delayed_ && DelayedTextureLoading; 
					auto bmp = bitmaps(file, delayed ? Yes.delayed : No.delayed, ErrorHandling.ignore); 
					//Opt: this synchronized call is slow. Should make a very fast cache storing images accessed in the current frame.
					
					if(auto texRec = file in texRecByFile)
					{
						if(texRec.modified==bmp.modified) return texRec; 
						
					}
					
					return null; 
					/+
						TexRec* res; 
						texRecByFileName.update
						(
							((){}),
							((ref texRec tr){
								res = &tr /+found existing+/; 
								if(tr.modified!=bmp.modified /+bmp's changed+/)
								{
									auto 	texHandle 	= tr.texHandle,
										texInfo 	= IB.access(texHandle); 
									buffer.heapFree(texInfo.heapChunkIdx); 
									auto bmp.serialize()
									auto heapRef = texInfo.heapAlloc(bmp); 
									texInfo.heapChunkIdx = heapRef.texChunkIdx; 
									if(heapRef.texInfo.heapChunkIdx)
									{}
									IB.modify(texHandle, texInfo); 
								}
							})
						); 
						
						if(auto texRec = file in byFileName)
						{
							if(bmp.modified == texRec.modified)
							{
								return texRec; //existing texture and matching modified datetime
							}
							
							const 	texHandle 	= texRec.texHandle,
								texInfo	= IB.access(texHandle); 
							buffer.heapFree(texInfo.heapChunkIdx); 
							IB.remove(texHandle); 
						}
						
						
						itt tartok; 
						
						auto idx = createSubTex(bmp); 
						byFileName[file] = idx; 
						bitmapModified[file] = modified; 
						return idx; 
					+/
				} 
				
			} 
		}
		
		version(/+$DIDE_REGION+/all) {
			class Texture
			{
				const TexHandle handle; 
				
				version(/+$DIDE_REGION Tracking released texHandles+/all)
				{
					protected __gshared MMQueue_nogc!TexHandle destroyedResidentTexHandles; 
					shared static this()
					{ destroyedResidentTexHandles = new typeof(destroyedResidentTexHandles); } 
				}
				
				this(S)(in TexInfoFlags flags, in TexFormat format, in S size, in void[] data=null)
				{
					TexSizeFormat fmt; 
					fmt.flags 	= flags,
					fmt.format 	= format,
					fmt.size 	= size; 
					fmt.resident = true; 
					handle = TB.createHandleAndSetData(fmt, data); 
				} 
				
				this(S)(in TexFormat format, in S size, in void[] data=null, in TexInfoFlags flags=TexInfoFlags.init)
				{ this(flags, format, size, data); } 
				
				~this()
				{
					if(handle)
					{ destroyedResidentTexHandles.put(handle); }
				} 
				
				@property TexInfo texInfo()
				=> ((handle)?(IB.access(handle)):(TexInfo.init));  @property texSizeFormat()
				=> texInfo.sizeFormat; 
				
				@property size()
				=> texSizeFormat.size.xy; 	@property size3D()
				=> texSizeFormat.size.xyz; 
				
				@property width()
				=> size.x; 	 @property height()
				=> size.y; 	 @property depth()
				=> size3D.z; 
			} 
			
			class BitmapArrayTexture : Texture
			{
				ubyte[] raw/+Todo: use the staging buffer!+/; 
				float aspect; 
				@property length() => depth; 
				
				int getPixel_1bit_unsafe(int idx, int x, int y)
				=> /+Opt: the size quiries are so slow, this must be moved outside+/
				raw[(idx*size.y+y)*(size.x/8)+(x/8)].getBit(x%8); 
				
				this(T)(T src, ivec2 cellSize = ivec2(0), ivec2 gridSize = ivec2(0))
				{
					static if(is(T : Image2D!ubyte)) auto img = src; 
					else static if(is(T : File)) auto img = bitmaps[src].accessOrGet!ubyte; 
					else static if(
						is(T : ubyte[])||
						is(T : string)
					) auto img = src.deserializeImage!ubyte; 
					else static assert(false, "unhandled type: "~T.stringof); 
					
					const origCellSize = cellSize, origGridSize = gridSize; 
					
					string makeErrorMsg(string s)
					=> i"$(s) (img:$(img.size), cell:$(origCellSize), grid:$(origGridSize)".text; 
					
					enforce(!img.empty, makeErrorMsg("empty image")); 
					
					static foreach(c; "xy")
					mixin(iq{
						if(cellSize.$(c)==0 && gridSize.$(c)>0)
						{ cellSize.$(c) = img.size.$(c)/gridSize.$(c); }
						if(cellSize.$(c)>0 && gridSize.$(c)==0)
						{ gridSize.$(c) = img.size.$(c)/cellSize.$(c); }
						
						enforce(
							cellSize.$(c).inRange(1, img.size.$(c)), 
								makeErrorMsg("cell size out of range")
						); 
						enforce(
							gridSize.$(c).inRange(1, img.size.$(c)), 
								makeErrorMsg("grid size out of range")
						); 
						enforce(
							cellSize.$(c)*gridSize.$(c)==img.size.$(c), 
								makeErrorMsg("image size mismatch")
						); 
					}.text); 
					
					enforce(gridSize.x==1, makeErrorMsg("only gridSize.x=1 supported")); 
					
					raw = img.asArray.pack8bitTo1bit; 
					super(TexFormat.wa_u1, ivec3(cellSize.xy, gridSize.y), raw); 
					aspect = (float(size.x))/size.y; 
					
					if(cellSize.y==0 && gridSize.y>0) { cellSize.y = img.size.y/gridSize.y; }
					
					enforce(size.x>0 && size.y>0); 
					aspect = (float(size.x))/size.y; 
				} 
			} 
		}
		
		Drawing dr; 
		
		class Drawing
		{
			/+
				enum WidthAlign { left, center, client, right } 
				enum Align {
					topLeft	, topCenter	, topRight	,
					centerLeft	, center	, centerRight	,
					bottomLeft	, bottomCenter	, bottomRight	
				} 
				enum SizeUnit
				{
					world, 	/+one unit in the world+/
					screen, 	/+one pixel at the screen (similar to fwidth())+/
					model 	/+Todo: one unit inside scaled model space+/
				} 
				enum SizeSpec
				{
					scaled, 	/+bitmaps's size is used and scaled by specified size+/
					exact	/+size is exactly specified+/
				} 
				enum Aspect {stretch, keep, crop} 
				
				struct VD_texturedRect
				{
					mixin((
						(表([
							[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
							[q{cmd},q{4},q{"cmd"},q{
								mixin(舉!((VertexCmd),q{texturedRect}))
								
							},q{/++/}],
							[q{Align},q{4},q{"align_"},q{},q{/++/}],
							[q{SizeUnit},q{2},q{"sizeUnit"},q{},q{/++/}],
							[q{SizeSpec},q{1},q{"sizeSpec"},q{},q{/++/}],
						]))
					).調!(GEN_bitfields)); 
				} 
			+/
			
			static foreach(field; ["PC", "SC"])
			mixin(iq{
				protected RGBA $(field)_; 
				@property
				{
					RGBA $(field)() const => $(field)_; 
					void $(field)(RGBA a) {$(field)_= a; } 
					
					void $(field)(vec4 a) {$(field)_= a.to_unorm; } 
					void $(field)(RGB a) {$(field)_.rgb = a; } 
					void $(field)(vec3 a) {$(field)_.rgb = a.to_unorm; } 
					void $(field)(float f) {$(field)_.rgb = f.to_unorm; } 
				} 
			}.text); 
			
			static foreach(field; ["PS", "LW"])
			mixin(iq{
				//Todo: these must be coded 12bit log2(x)*64 <-> exp2(x/64)
				protected float $(field)_; 
				@property
				{
					float $(field)() const => $(field)_; 
					void $(field)(float a) {$(field)_= a; } 
				} 
			}.text); 
			
			
			alias primaryColor 	= PC, 
			secondaryColor 	= SC,
			pointSize	= PS,
			lineWidth	= LW; 
			
			void reset()
			{
				PC = (RGB(0xFFFFFFFF)); 
				SC = (RGB(0xFF000000)); 
			} 
			
			void rect_old(bounds2 bounds, TexHandle texHandle, in RGBA color=(RGBA(0xFFFFFFFF)))
			{
				VB(mixin(體!((VertexData),q{GB.bitPos}))); 
				foreach(i; 0..4)
				GB(
					mixin(舉!((Opcode),q{setPC}))	, mixin(舉!((ColorFormat),q{rgba_u8})), color,
					mixin(舉!((Opcode),q{drawMove}))	, mixin(舉!((CoordFormat),q{f32})), bounds.low+vec2(i*4).rotate(i*.125f),
					mixin(舉!((Opcode),q{drawTexRect}))	, mixin(舉!((CoordFormat),q{f32})), bounds.high+vec2(i*4).rotate(i*.125f), mixin(舉!((HandleFormat),q{u32})), (cast(uint)(texHandle)),
				); 
				GB(mixin(舉!((Opcode),q{end}))); 
			} 
			
			void finalize()
			{
				static if(bugFix_LastTwoGeometryShaderStreamsMissing)
				{
					foreach(i; 0..3) { VB(mixin(體!((VertexData),q{GB.bitPos}))); }GB(0u/+many zeroes as end+/); 
					/+
						Bug: I don't know why these empty vertexes are needed. Minimum 2 of them.
						POINTS -> POINT_LIST is good
						POINTS -> TRIANGLE_STRIP, needs 2 extra points.
						I add 3 to make sure.
					+/
				}
			} 
			
			
		} 
		
		
		
		void createRenderPass(VulkanSwapchain swapchain)
		{
			renderPass = device.createRenderPass
				(
				[
					mixin(體!((VkAttachmentDescription),q{
						format 	: swapchain.format, 	samples 	: mixin(舉!((VK_SAMPLE_COUNT),q{_1_BIT})),
						loadOp 	: mixin(舉!((VK_ATTACHMENT_LOAD_OP_),q{CLEAR})), 	storeOp 	: mixin(舉!((VK_ATTACHMENT_STORE_OP_),q{STORE})),
						stencilLoadOp 	: mixin(舉!((VK_ATTACHMENT_LOAD_OP_),q{DONT_CARE})), 	stencilStoreOp 	: mixin(舉!((VK_ATTACHMENT_STORE_OP_),q{DONT_CARE})),
						initialLayout 	: mixin(舉!((VK_IMAGE_LAYOUT_),q{PRESENT_SRC_KHR})), 	finalLayout 	: mixin(舉!((VK_IMAGE_LAYOUT_),q{PRESENT_SRC_KHR})),
					}))
				], 
				[
					mixin(體!((VulkanSubpassDescription),q{
						pipelineBindPoint	: mixin(舉!((VK_PIPELINE_BIND_POINT_),q{GRAPHICS})), 
						colorAttachments	: [
							mixin(體!((VkAttachmentReference),q{
								attachment 	: 0, //attachment index
								layout	: mixin(舉!((VK_IMAGE_LAYOUT_),q{COLOR_ATTACHMENT_OPTIMAL})),
							}))
						]
					}))
				]
			); 
			renderPass.createFramebuffers(swapchain); 
		} 
		
		
		
		
		
		
		void createDescriptorPool()
		{
			/+
				This describes how many descriptor sets we'll 
				create from this pool for each type
			+/
			descriptorPool = device.createDescriptorPool
			(
				[
					mixin(體!((VkDescriptorPoolSize),q{
						type : mixin(舉!((VK_DESCRIPTOR_TYPE_),q{UNIFORM_BUFFER})), 
						descriptorCount : 1
					})), 
					mixin(體!((VkDescriptorPoolSize),q{
						type : mixin(舉!((VK_DESCRIPTOR_TYPE_),q{STORAGE_BUFFER})), 
						descriptorCount : 3
					}))
				]
				,1 /+maxSets+/
			); 
		} void createDescriptorSet()
		{
			/+
				There needs to be one descriptor set per 
				binding point in the shader
			+/
			descriptorSet = descriptorPool.allocate(descriptorSetLayout); 
			descriptorSet.write(
				0, UB.uniformMemoryBuffer, 
				mixin(舉!((VK_DESCRIPTOR_TYPE_),q{UNIFORM_BUFFER}))
			); 
			descriptorSet.write(
				1, IB.buffer.deviceMemoryBuffer, 
				mixin(舉!((VK_DESCRIPTOR_TYPE_),q{STORAGE_BUFFER}))
			); 
			descriptorSet.write(
				2, TB.buffer.deviceMemoryBuffer, 
				mixin(舉!((VK_DESCRIPTOR_TYPE_),q{STORAGE_BUFFER}))
			); 
			descriptorSet.write(
				3, GB.buffer.deviceMemoryBuffer, 
				mixin(舉!((VK_DESCRIPTOR_TYPE_),q{STORAGE_BUFFER}))
			); 
		} 
		
		void createDescriptorSetLayout()
		{
			const stages = mixin(幟!((VK_SHADER_STAGE_),q{GEOMETRY_BIT | FRAGMENT_BIT})); 
			descriptorSetLayout = device.createDescriptorSetLayout
			(
				mixin(體!((VkDescriptorSetLayoutBinding),q{
					binding	: 0, descriptorType 	: mixin(舉!((VK_DESCRIPTOR_TYPE_),q{UNIFORM_BUFFER})), 
					descriptorCount 	: 1, stageFlags 	: stages
				})), 
				mixin(體!((VkDescriptorSetLayoutBinding),q{
					binding	: 1, 	descriptorType 	: mixin(舉!((VK_DESCRIPTOR_TYPE_),q{STORAGE_BUFFER})), 
					descriptorCount 	: 1, 	stageFlags 	: stages
				})),
				mixin(體!((VkDescriptorSetLayoutBinding),q{
					binding	: 2, 	descriptorType 	: mixin(舉!((VK_DESCRIPTOR_TYPE_),q{STORAGE_BUFFER})),
					descriptorCount 	: 1, 	stageFlags 	: stages
				})),
				mixin(體!((VkDescriptorSetLayoutBinding),q{
					binding	: 3, 	descriptorType 	: mixin(舉!((VK_DESCRIPTOR_TYPE_),q{STORAGE_BUFFER})),
					descriptorCount 	: 1, 	stageFlags 	: stages
				})),
			); 
		} enum ShaderBufferDeclarations = 
		iq{
			//UB: Uniform buffer
			layout(binding = 0)
			uniform UB_T {
				mat4 mvp, inv_mvp; 
				vec4 viewport; 
				float iTime; 
			} UB; 
			
			//IB: Info buffer (texture directory)
			layout(binding = 1) buffer IB_T { uint IB[]; } ; 
			
			//TB: Texture buffer
			layout(binding = 2) buffer TB_T { uint TB[]; } ; 
			
			//GB: Geometry buffer (additional variable lengt vertex data)
			layout(binding = 3) buffer GB_T { uint GB[]; } ; 
		}.text; 
		
		void createGraphicsPipeline()
		{
			//Link: https://vulkan-tutorial.com/Drawing_a_triangle/Graphics_pipeline_basics/Shader_modules
			
			createDescriptorSetLayout; 
			
			// Describe pipeline layout
			// Note: this describes the mapping between memory and shader resources (descriptor sets)
			pipelineLayout = device.createPipelineLayout(descriptorSetLayout); 
			
			// Create the graphics pipeline
			graphicsPipeline = device.createGraphicsPipeline
				(
				shaderModules.pipelineShaderStageCreateInfos,
				device.vertexInputState
				(
					mixin(體!((VkVertexInputBindingDescription),q{
						binding	: 0, 
						stride	: VertexData.sizeof,
						inputRate 	: mixin(舉!((VK_VERTEX_INPUT_RATE_),q{VERTEX})),
					})), [
						mixin(體!((VkVertexInputAttributeDescription),q{
							binding	: 0, 
							location 	: 0,
							format	: mixin(舉!((VK_FORMAT_),q{R32_UINT})),
							offset	: 0
						}))
					]
				),
				
				mixin(體!((VkPipelineInputAssemblyStateCreateInfo),q{
					topology 	: mixin(舉!((VK_PRIMITIVE_TOPOLOGY_),q{TRIANGLE_STRIP})),
					primitiveRestartEnable 	: true,
				})), 
				
				device.viewportState(swapchain.extent),
				
				mixin(體!((VkPipelineRasterizationStateCreateInfo),q{
					depthClampEnable 	: false,
					rasterizerDiscardEnable 	: false/*This discards everything*/,
					polygonMode 	: mixin(舉!((VK_POLYGON_MODE_),q{FILL})),
					cullMode 	: mixin(舉!((VK_CULL_MODE_),q{BACK_BIT})),
					frontFace 	: mixin(舉!((VK_FRONT_FACE_),q{COUNTER_CLOCKWISE})),
					depthBiasEnable 	: false,
					depthBiasConstantFactor 	: 0.0f,
					depthBiasClamp 	: 0.0f,
					depthBiasSlopeFactor 	: 0.0f,
					lineWidth 	: 1.0f,
				})), mixin(體!((VkPipelineMultisampleStateCreateInfo),q{
					rasterizationSamples 	: mixin(舉!((VK_SAMPLE_COUNT),q{_1_BIT})),
					sampleShadingEnable 	: false,
					minSampleShading 	: 1.0f,
					alphaToCoverageEnable 	: false,
					alphaToOneEnable 	: false,
				})), mixin(體!((VkPipelineColorBlendStateCreateInfo),q{
					logicOpEnable 	: false,
					logicOp 	: mixin(舉!((VK_LOGIC_OP_),q{COPY})),
					blendConstants 	: [0, 0, 0, 0]
				})),
				
				mixin(體!((VkPipelineColorBlendAttachmentState),q{
					blendEnable 	: true,
					srcColorBlendFactor 	: mixin(舉!((VK_BLEND_FACTOR_),q{SRC_ALPHA})), 	dstColorBlendFactor 	: mixin(舉!((VK_BLEND_FACTOR_),q{ONE_MINUS_SRC_ALPHA})), 	colorBlendOp 	: mixin(舉!((VK_BLEND_OP_),q{ADD})),
					srcAlphaBlendFactor 	: mixin(舉!((VK_BLEND_FACTOR_),q{ONE})), 	dstAlphaBlendFactor 	: mixin(舉!((VK_BLEND_FACTOR_),q{ZERO})), 	alphaBlendOp 	: mixin(舉!((VK_BLEND_OP_),q{ADD})),
					colorWriteMask 	: mixin(幟!((VK_COLOR_COMPONENT_),q{R_BIT | G_BIT | B_BIT | A_BIT}))
				})),
				
				pipelineLayout, renderPass, 0, null, -1
			); 
		} 
		
		void recreateDescriptors()
		{ descriptorSet.free; descriptorPool.free; createDescriptorPool; createDescriptorSet; /+0.03 ms+/} 
		
		auto createCommandBuffer(
			size_t swapchainIndex, size_t vertexCount,
			VulkanMemoryBuffer vertexMemoryBuffer
		)
		{
			auto commandBuffer = commandPool.createBuffer; 
			with(commandBuffer)
			{
				record
				(
					mixin(舉!((VK_COMMAND_BUFFER_USAGE_),q{ONE_TIME_SUBMIT_BIT})),
					{
						cmdPipelineBarrier
							(
							mixin(舉!((VK_PIPELINE_STAGE_),q{COLOR_ATTACHMENT_OUTPUT_BIT})), 
							mixin(舉!((VK_PIPELINE_STAGE_),q{COLOR_ATTACHMENT_OUTPUT_BIT})),
							mixin(體!((VkImageMemoryBarrier),q{
								srcAccessMask 	: mixin(舉!((VK_ACCESS_),q{init})),
								dstAccessMask 	: mixin(舉!((VK_ACCESS_),q{COLOR_ATTACHMENT_WRITE_BIT})),
								oldLayout 	: mixin(舉!((VK_IMAGE_LAYOUT_),q{UNDEFINED})),
								newLayout 	: mixin(舉!((VK_IMAGE_LAYOUT_),q{PRESENT_SRC_KHR})),
								srcQueueFamilyIndex	: VK_QUEUE_FAMILY_IGNORED,
								dstQueueFamilyIndex	: VK_QUEUE_FAMILY_IGNORED,
								image	: swapchain.images[swapchainIndex],
								subresourceRange	: {
									aspectMask 	: mixin(舉!((VK_IMAGE_ASPECT_),q{COLOR_BIT})),
									baseMipLevel 	: 0, levelCount 	: 1,
									baseArrayLayer 	: 0, layerCount 	: 1,
								},
							}))
						); 
						recordRenderPass
							(
							mixin(體!((VkRenderPassBeginInfo),q{
								renderPass 	: this.renderPass,
								framebuffer 	: renderPass.framebuffers[swapchainIndex],
								renderArea 	: {
									offset 	: { x: 0, y: 0 }, 
									extent 	: swapchain.extent 
								},
								clearValueCount 	: 1,
								pClearValues 	: &clearColor //Note: AMD has FastClear if black or white
							})), 
							{
								cmdBindGraphicsDescriptorSets(pipelineLayout, 0, descriptorSet); 
								cmdBindGraphicsPipeline(graphicsPipeline); 
								cmdBindVertexBuffers(0, vertexMemoryBuffer); 
								cmdDraw(vertexCount.to!uint, 1, 0, 0); 
							}
						); 
					}
				); 
			}
			return commandBuffer; 
			/+
				Opt: Use primary AND secondary command buffers!	
				On triangle test goes from 1500 to 1300 FPS	with single use buffers.
			+/
		} 
		
		void selfTest()
		{
			TexSizeFormat.selfTest; 
			unittest_assembleSize; 
			unittest_assembleAngle; 
			unittest_assemblePoint; 
		} 
		
		
		override void onInitializeGLWindow()
		{
			version(/+$DIDE_REGION Make the VulkanWindow to be globally accessible+/all)
			{
				//It is needed for fonts.  And fonts needs a way to make textures.
				enforce(
					!mainVulkanWindow || mainVulkanWindow is this, 
						"Vulkan Multi-Window support not implemented yet."
				); 
				
				mainVulkanWindow = this; 
				if(!g_fontFaceManager)
				g_fontFaceManager = new FontFaceManager; 
			}
			
			disableInternalRedraw = true /+Do nothing on WM_PAINT+/; 
			targetUpdateRate = 100000 /+No limit on minimum update interval+/; 
			
			selfTest; 
			
			vk	= new VulkanInstance(["VK_KHR_surface", "VK_KHR_win32_surface"]),
			physicalDevice	= vk.physicalDevices.front,
			surface	= vk.surfaces(hwnd),
			queueFamily	= surface.requireGraphicsPresenterQueueFamily(physicalDevice),
			device	= createVulkanDevice("VK_KHR_swapchain", queueFamily, &queue),
			commandPool	= queue.createCommandPool,
			imageAvailableSemaphore	= new VulkanSemaphore(device),
			renderingFinishedSemaphore 	= new VulkanSemaphore(device); 
			swapchain = new VulkanSwapchain(device, surface, clientSize); 
			createRenderPass(swapchain); 
			
			buffers = 
			[
				UB 	= new UniformBufferManager,
				VB	= new VertexBufferManager,
				GB	= new GeometryBufferManager,
				IB	= new InfoBufferManager,
				TB	= new TextureBufferManager
			]; 
			dr = new Drawing; 
			
			createShaderModules; 
			createGraphicsPipeline; //also creates descriptorsetLayout and pipelineLayout
			
			createDescriptorPool; 
			createDescriptorSet; //needs: descriptorsetLayout, uniformBuffer
			
			if(0) VulkanInstance.dumpBasicStuff; 
		} 
		
		override void onFinalizeGLWindow()
		{
			device.waitIdle; 
			/+
				import core.memory : GC; GC.collect; 
				((0xAEFC82886ADB).檢(destroyedResidentTexHandles.fetchAll)); 
			+/
			buffers.each!free; buffers = []; 
			vk.free; 
		} 
		
		void onWindowSizeChanged() 
		{
			/+
				Only recreate objects that are affected 
					by framebuffer size changes
			+/
			device.waitIdle; 
			
			graphicsPipeline.free; 
			pipelineLayout.free; 
			descriptorSetLayout.free; 
			renderPass.free; 
			swapchain.recreate(clientSize); 
			createRenderPass(swapchain); 
			createGraphicsPipeline; 
		} 
		
		override void doUpdate()
		{
			static if((常!(bool)(1)))
			{
				with(lastFrameStats)
				{
					((0x1DBD782886ADB).檢(
						i"$(V_cnt)
$(V_size)
$(G_size)
$(V_size+G_size)".text
					)); 
				}
				if((互!((bool),(0),(0x1DC4982886ADB))))
				{
					const ma = GfxAssembler.ShaderMaxVertexCount; 
					GfxAssembler.desiredMaxVertexCount = 
					((0x1DCDD82886ADB).檢((互!((float/+w=12+/),(1.000),(0x1DCF482886ADB))).iremap(0, 1, 4, ma))); 
					static imVG = image2D(128, 128, ubyte(0)); 
					imVG.safeSet(
						GfxAssembler.desiredMaxVertexCount, 
						imVG.height-1 - lastFrameStats.VG_size.to!int/1024/8, 255
					); 
					
					static imFPS = image2D(128, 128, ubyte(0)); 
					imFPS.safeSet(
						GfxAssembler.desiredMaxVertexCount, 
						imFPS.height-1 - (second/deltaTime).get.iround, 255
					); 
					
					((0x1DEC982886ADB).檢 (imVG)),
					((0x1DEEF82886ADB).檢 (imFPS)); 
				}
			}
			
			
			VulkanCommandBuffer commandBuffer; 
			VulkanMemoryBuffer 	vertexMemoryBuffer,
				indexMemoryBuffer; 
			
			try
			{
				//Link: https://vulkan-tutorial.com/Drawing_a_triangle/Swap_chain_recreation#page_Fixing-a-deadlock
				/+
					Link: https://www.intel.com/content/www/us/en/developer/articles/
					training/api-without-secrets-introduction-to-vulkan-part-2.html
				+/
				swapchain.acquireAndPresent
					(
					queue, imageAvailableSemaphore, renderingFinishedSemaphore, 
					{
						try
						{
							VB.reset; GB.reset; dr.reset; 
							
							internalUpdate; //this will call onUpdate()
							
							dr.finalize/+It appends nops to the end.+/; 
							VB.upload; GB.upload; 
							
							{
								static float globalScale = 1; 
								globalScale.follow(inputs.Shift.down ? 34.0f : 1, calcAnimationT(deltaTime.value(second), 0.75f), 0.001f); 
								auto modelMatrix = mat4.identity; 
								const rotationAngle = 0 * QPS.value(10*second); 
								modelMatrix.translate(vec3(-160-32, -100-32, 0)*globalScale); 
								modelMatrix.rotate(vec3(0, 0, 1), rotationAngle); 
								
								// Set up view
								const side = vec2(1, 0).rotate(QPS.value(10*second).fract*π*2)*vec2(80, 40)*0.5f; 
								float zoomanim = (0.71f+0.7f*sin((float(QPS.value(19*second))).fract*π*2))*0+1; 
								zoomanim *=2; 
								auto viewMatrix = mat4.lookAt(vec3(side.xy, 500)/1.65f*globalScale*(zoomanim), vec3(0), vec3(0, 1, 0)); 
								
								// Set up projection
								auto projMatrix = mat4.perspective(swapchain.extent.width, swapchain.extent.height, 60, 0.1*globalScale, 1000*globalScale); 
								
								auto mvp = projMatrix * viewMatrix * modelMatrix; 
								with(UB.access)
								{
									transformationMatrix = mvp; 
									inverseTransformationMatrix = mvp.inverse; 
									viewport = vec4(0, 0, swapchain.extent.width, swapchain.extent.height); 
									iTime = QPS_local.value(second); 
									//Todo: The UB struct should be automatic in the shader code.
								}
							}
							
							/+
								TB.buffer.reset; 
								TB.buffer.append([(RGBA(255, 245, 70, 255)), (RGBA(0xFFFF00FF))]); 
							+/
							
							if(0)
							if(TB.buffer.growByRate(((KeyCombo("Shift").down)?(2):(((KeyCombo("Ctrl").down)?(.5):(1)))), true))
							{}
							
							
							if(KeyCombo("Up").down) {
								foreach(i; 0..6)
								{
									const N = 1<<20; 
									auto t = new Texture(TexFormat.rgb_u8, 3*N, [clAqua].replicate(N)); 
									/+print(t.handle); +/
								}
							}
							
							foreach(th; Texture.destroyedResidentTexHandles)
							{ TB.remove(th); /+LOG(th); +/}
							
							/+
								if(KeyCombo("Space").down)
								{ LOG(Texture.destroyedResidentTexHandles.stats); }
							+/
							
							
							IB.buffer.upload; 
							TB.buffer.upload; 
						}
						catch(Exception e) { ERR("Scene exception: ", e.simpleMsg); }
						//because buffers could grow, descriptors can change.
						recreateDescriptors; 
						
						device.waitIdle/+Wait for everything+/; /+Opt: STALL  only wait if something's changed+/
						commandBuffer = createCommandBuffer	(
							swapchain.imageIndex, 
							VB.uploadedVertexCount, VB.deviceMemoryBuffer
						); 
						queue.submit
							(
							imageAvailableSemaphore, mixin(舉!((VK_PIPELINE_STAGE_),q{TOP_OF_PIPE_BIT})),
							commandBuffer,
							renderingFinishedSemaphore
						); 
					},
					&onWindowSizeChanged
				); 
			}
			catch(Exception e)
			{ ERR(e.simpleMsg); }
			
			commandBuffer.free; 
			vertexMemoryBuffer.free; 
			//Opt: These reallocations in every frame are bad.
			
			//invalidate; no need.+/; 
		} 
	}
	version(/+$DIDE_REGION+/all) {
		/+
			Opt: Make a faster bitStream fetcher with a closing MSB 1 bit instead of `currentDwBits`./+
				Details: /+
					Hidden: /+
						AI: /+
							User: Yesterday we did this cool bitsream reader in GLSL:
							/+
								Code: struct BitStream
								{
									uint dwOfs; //the dword offset of the NEXT fetched dword.
									uint currentDw; //the current dword that is fetched
									int currentDwBits; /*
										how many of the lower bits are valid in the current dword, 
										if zero, the next dword must be fetched
									*/
								}; 
								
								uint fetchBits(inout BitStream bitStream, in uint numBits)
								{
									uint result = 0; 
									int bitsRemaining = int(numBits); 
									
									while(bitsRemaining > 0)
									{
										// If current dword is exhausted, fetch next one
										if(bitStream.currentDwBits == 0)
										{
											bitStream.currentDw = GB[bitStream.dwOfs]; 
											bitStream.dwOfs++; 
											bitStream.currentDwBits = 32; 
										}
										
										// Calculate how many bits we can take this iteration
										int bitsToTake = min(bitsRemaining, bitStream.currentDwBits); 
										
										// Extract the bits we need (using bitfieldExtract)
										uint extracted = bitfieldExtract(bitStream.currentDw, 0, bitsToTake); 
										
										// Insert them into the result (using bitfieldInsert)
										result = bitfieldInsert(result, extracted, int(numBits) - bitsRemaining, bitsToTake); 
										
										// Remove used bits from current dword (using bitfieldExtract for the remaining bits)
										bitStream.currentDw >>= bitsToTake; 
										bitStream.currentDwBits -= bitsToTake; 
										bitsRemaining -= bitsToTake; 
									}
									
									return result; 
								} 
								
								bool fetch_bool(inout BitStream bitStream)
								{
									if(bitStream.currentDwBits == 0)
									{
										bitStream.currentDw = GB[bitStream.dwOfs]; 
										bitStream.dwOfs++; 
										bitStream.currentDwBits = 32; 
									}
									
									bool bit = (bitStream.currentDw & 1u) != 0; 
									bitStream.currentDw >>= 1; 
									bitStream.currentDwBits--; 
									
									return bit; 
								} 
							+/
							
							I thought about making it faster and use less gpu regs by storing
							`currentDwBits` via an extra one bit on top of the last valid bit.
							So if I have 8x 0 bits of data, the contents of currentDwBits woud be 0x1FF.
							So reading 8 bits from it means (currentDwBits>>8)!=0 which means it is still valid (0..31 bits can be in it).
							Reading 8 bits from that would be (currentDwBits>>9)==0 that is an early signal that it has not enough bits.
							Reading less than 8 bits end up a nonzero value: the closing bits and optional other data.
							After the closing 1 bit there are always zeroes.
							
							New glsl instructions that support these:
								* bitCount: it tells if it's invalid (0), or valid(1 or higher)
								* findMSB: it finds the position of the closing 1 bit. -1 if none. It basically tells all info about the current 
											0..31 bit temporal storage (currentDwBits).
							
							Problem:
								* It is impossible to load 32 bits into currentDwBits, because you cant put the 33th closing 1 bit, 
											so the maximum allowed 32bit fetches must be done differently and also in an optimized way.
								* I feel like currentDw==0 and currentDw==1 are weirdly special cases, 1 means that we run temporarily ran out 
											of bits, 0 means that we are also at 32 a bit boundary. Please think this through.
							
							The goal is to solve the above problem with a simplified struct:
							/+
								Code: struct BitStream
								{
									uint dwOfs; //The dword offset of the NEXT fetched dword.
									
									uint currentDw; 
									/*
										The current dword that is fetched, and beyond the highest valid data bit there is a 1 bit for closing.
										1 means there is 0 data bits currently
										0 means there were not even a fetch into currentDw. This is the initial state.
										0x8000000 means 31 valid data bits that are all zeroes in this example.
										Note: The maximal 32bit reads must be handled specially, it can only hold 31 bits!!!
									*/
								}; 
							+/
						+/
						/+
							Assistant: /+
								Para: I understand you want to optimize the bitstream reader by encoding the bit count information
								directly in the /+Highlighted: currentDw+/ value using a terminating 1 bit. Let me analyze this and propose
								a solution:
							+/
							
							1. Key observations:
										/+Bullet: The terminating 1 bit marks the end of valid bits+/
										/+Bullet: /+Highlighted: currentDw == 0+/ means uninitialized state+/
										/+Bullet: /+Highlighted: currentDw == 1+/ means no valid bits (just the terminator)+/
										/+Bullet: For N valid bits, the pattern is: [N data bits][1][0...0]+/
							
							2. Special case handling:
										/+Bullet: 32-bit reads must be handled separately since we can't represent them+/
										/+Bullet: Need to detect when we're about to run out of bits+/
							
							Here's the optimized implementation:
							
							/+
								Structured: struct BitStream
								{
									uint dwOfs; // The dword offset of the NEXT fetched dword.
									uint currentDw; // [data bits][1][0...0] pattern
								}; 
								
								uint fetchBits(inout BitStream bitStream, in uint numBits)
								{
									// Special case: full 32-bit read
									if(numBits == 32)
									{
										// Must have empty current buffer to do this efficiently
										if(bitStream.currentDw == 0 || bitStream.currentDw == 1)
										{
											uint result = GB[bitStream.dwOfs]; 
											bitStream.dwOfs++; 
											return result; 
										}
										else
										{
											// Need to handle partial read then get remaining bits
											uint bitsAvailable = findMSB(bitStream.currentDw); 
											uint firstPart = bitfieldExtract(bitStream.currentDw, 0, bitsAvailable); 
											bitStream.currentDw = GB[bitStream.dwOfs]; 
											bitStream.dwOfs++; 
											uint remainingBits = numBits - bitsAvailable; 
											uint secondPart = bitfieldExtract(bitStream.currentDw, 0, remainingBits); 
											bitStream.currentDw >>= remainingBits; 
											bitStream.currentDw |= 1u << remainingBits; // Set new terminator
											return (secondPart << bitsAvailable) | firstPart; 
										}
									}
										
									uint result = 0; 
									uint bitsRemaining = numBits; 
										
									while(bitsRemaining > 0)
									{
										// Check if we need to refill
										if(bitStream.currentDw == 0 || bitStream.currentDw == 1)
										{
											bitStream.currentDw = GB[bitStream.dwOfs]; 
											bitStream.dwOfs++; 
											bitStream.currentDw |= 1u << 31; // Set terminator at bit 31 (31 data bits)
										}
											
										// Calculate available bits
										int msbPos = findMSB(bitStream.currentDw); 
										uint bitsAvailable = msbPos; 
										uint bitsToTake = min(bitsRemaining, bitsAvailable); 
											
										// Extract bits
										uint extracted = bitfieldExtract(bitStream.currentDw, 0, bitsToTake); 
										result = bitfieldInsert(result, extracted, numBits - bitsRemaining, bitsToTake); 
											
										// Update state
										bitStream.currentDw >>= bitsToTake; 
										bitsRemaining -= bitsToTake; 
											
										// If we consumed all bits, clear the terminator (will be 1 if empty)
										if(bitsToTake == bitsAvailable)
										bitStream.currentDw &= ~(1u << (msbPos - bitsToTake)); 
									}
										
									return result; 
								} 
								
								bool fetch_bool(inout BitStream bitStream)
								{
									// Check if we need to refill
									if(bitStream.currentDw == 0 || bitStream.currentDw == 1)
									{
										bitStream.currentDw = GB[bitStream.dwOfs]; 
										bitStream.dwOfs++; 
										bitStream.currentDw |= 1u << 31; // Set terminator at bit 31
									}
										
									// Extract bit
									bool bit = (bitStream.currentDw & 1u) != 0; 
									bitStream.currentDw >>= 1; 
										
									// If we just consumed the terminator, clear it
									if((bitStream.currentDw & 1u) == 0)
									bitStream.currentDw = 1; 
										
									return bit; 
								} 
							+/
							
							Key optimizations:
							1. Eliminated /+Highlighted: currentDwBits+/ by using the terminator bit pattern
							2. Special handling for 32-bit reads when possible
							3. Uses /+Highlighted: findMSB+/ to quickly determine available bits
							4. Maintains the invariant that after the last data bit there's exactly one terminator bit
							
							The special cases are handled as:
								/+Bullet: /+Highlighted: currentDw == 0+/: Initial/uninitialized state+/
								/+Bullet: /+Highlighted: currentDw == 1+/: Empty buffer (just terminator)+/
								/+Bullet: Otherwise: [data bits][1][0...0] pattern+/
							
							This should be more efficient as it:
								/+Bullet: Uses one less register (no separate bit count)+/
								/+Bullet: Has faster empty buffer checks (just compare to 0 or 1)+/
								/+Bullet: Uses hardware-accelerated /+Highlighted: findMSB+/ for bit counting+/
							
							/+Note: Usage(prompt_hit: 64, prompt_miss: 1357, completion: 1102, HUF: 0.60, price: 100%)+/
						+/
					+/
				+/
			+/
		+/
		void createShaderModules()
		{
			with(TexSizeFormat /+share bitSize/bitOffset constants for texturing+/)
			{
				enum shaderBinary = 
				(碼!((位!()),iq{glslc -O},iq{
					#version 430
					
					//Todo: check the warnings!
					
					//common stuff
					#define nan (uintBitsToFloat(0x7fc00000u))
					
					#define ErrorColor vec4(1, 0, 1, 1)
					#define LoadingColor vec4(1, 0, 1, 1)
					
					#define getBits(val, ofs, len) (bitfieldExtract(val, ofs, len))
					#define getBit(val, ofs) (bitfieldExtract(val, ofs, 1)!=0)
					#define setBits(val, ofs, len, data) (val = bitfieldInsert(val, data, ofs, len))
					
					#define inRange(value, mi, ma) (mi<=value && value<=ma)
					#define inRange_sorted(value, r1, r2) (inRange(value, min(r1, r2), max(r1, r2)))
					
					#define PI 3.14159265359
					
					vec2 rotate90(in vec2 v) { return vec2(-v.y, v.x); } 
					float crossZ(in vec2 a, vec2 b) { return a.x*b.y - b.x*a.y; } 
					
					struct seg2
					{ vec2[2] p; }; 
					
					vec2 lineSegmentNearestPoint2D(in vec2 p0, in vec2 p1, in vec2 point)
					{
						vec2 line_dir = p1 - p0; 
						vec2 to_point = point - p0; 
						float t = dot(to_point, line_dir) / dot(line_dir, line_dir); 
						t = clamp(t, 0.0, 1.0); 
						return p0 + t * line_dir; 
					} 
					
					// Helper function for line intersection
					vec2 lineIntersection(vec2 p1, vec2 p2, vec2 p3, vec2 p4)
					{
						float denom = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x); 
						if(abs(denom) < 1e-4)
						{
							return (p2+p3)/2; // Fallback to first point if lines are parallel
						}
						
						float t = ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / denom; 
						return p1 + t * (p2 - p1); 
					} 
					
					
					//fragment attributes
					
					#define FragMode_fullyFilled 0
					#define FragMode_cubicBezier 1
					#define FragMode_glyphStrip 2
					
					#define getFragMode getBits(fragTexHandleAndMode, 28, 4)
					#define setFragMode(a) setBits(fragTexHandleAndMode, 28, 4, a)
					
					#define getFragTexHandle getBits(fragTexHandleAndMode, 0, 28)
					#define setFragTexHandle(a) setBits(fragTexHandleAndMode, 0, 28, a)
					
					
					$(
						(表([
							[q{/+Note: Stage out+/},q{/+Note: Stage in+/},q{/+Note: Location 0+/},q{/+Note: Location 1+/},q{/+Note: Location 2+/},q{/+Note: Location 3+/},q{/+Note: Location 4+/},q{/+Note: Location 5+/},q{/+Note: Location 6+/}],
							[q{},q{vert},q{uint vertGSBitOfs}],
							[q{vert},q{geom},q{uint geomGSBitOfs}],
							[q{geom},q{frag},q{
								smooth mediump
								vec4 fragColor
							},q{
								smooth mediump
								vec4 fragBkColor
							},q{
								smooth
								vec2 fragTexCoordXY
							},q{
								flat
								uint fragTexHandleAndMode
							},q{
								flat
								uint fragTexCoordZ
							},q{
								flat
								vec4 fragFloats0
							},q{
								flat
								vec4 fragFloats1
							}],
							[q{frag},q{},q{vec4 outColor}],
						]))
						.GEN_ShaderLayoutDeclarations
					)
					
					/*
						Anomalies:
							* Lines:
								* fragTexCoordZ: is used for lineWidth/2
								* fragFloats0..1 contain 2D cubic bezier control points
					*/
					
					@vert: 
					
					void main()
					{
						geomGSBitOfs 	= vertGSBitOfs 
						/*geomVertexID	= gl_VertexIndex*/; 
					} 
					
					@geom: 
					$(ShaderBufferDeclarations)
					$(TexSizeFormat.GLSLCode)
					
					out gl_PerVertex 
					{
						vec4 gl_Position; 
						float gl_ClipDistance[4]; 
					}; 
					
					layout(points) in; 
					layout(triangle_strip, max_vertices = $(GfxAssembler.ShaderMaxVertexCount)) out; 
					/*
						255 is the max on R9 Fury X
						
						250802 must send 2 more vertices to the geometry shader streams, last 2 is ignored.
							(Windows default driver, )
						250804 170 is the max with 12 components. 170*12=2040  (171*12=2052)
							I have no clue where this 2048 limit comes from o.O
						250822 127 is the max when I add 2x vec4 (20 components)  127*16 = 2032
							highp vs medump doesn't change this 127 limit
						250908 D constant is used, 127 still works.  Have 24 components with gl_Position, 
							but still, the math fails... 16384/24 = 682.6
					*/
					
					/*
						Todo: There is no line_strip or line_strip_adjacency.  No overlapping vertex input is possible.
						
						So if I want to know the size of each stream, 
						I have to read it from a buffer, indexed by InputPrimitiveID
					*/
					
					//Todo: Geom Shader User Clip Distances could be useful for UI rect clipping !!!
					
					/*Link: https://docs.vulkan.org/spec/latest/chapters/geometry.html*/
					/*Link: https://www.khronos.org/opengl/wiki/Geometry_Shader*/
					/*
						Note: From: OpenGL Geometry Shader docs:
							Note: You must write to each output variable before every EmitVertex() call (for all 
							outputs for a stream for each EmitStreamVertex() call).
						
						I don't follow this rule and it works so far on Vulkan + R9 Fury X
					*/
					
					
					ivec3 getTexSize(in uint texIdx)
					{
						//This is all copied from the fragment shader.
						
						if(texIdx==0) return ivec3(0); 
						
						//fetch info dword 0
						const uint textDwIdx = texIdx * $(TexInfo.sizeof/4); 
						const uint info_0 = IB[textDwIdx+0]; 
						
						//handle 'error' and 'loading' flags
						if(getBits(info_0, $(TexInfoBitOfs), 2)!=0) { return ivec3(0); }
						
						//decode dimensions, size
						const uint dim = getBits(info_0, $(TexDimBitOfs), $(TexDimBits)); 
						const uint info_1 = IB[textDwIdx+1]; 
						const uint _rawSize0 = getBits(info_0, 16, 16); 
						const uint _rawSize12 = info_1; 
						return decodeDimSize(dim, _rawSize0, _rawSize12); 
					} 
					
					vec4 readPaletteSample(in uint texIdx, in float v, in bool prescaleX)
					{
						if(texIdx==0) return ErrorColor; 
						
						//fetch info dword 0
						const uint textDwIdx = texIdx * $(TexInfo.sizeof/4); 
						const uint info_0 = IB[textDwIdx+0]; 
						
						//handle 'error' and 'loading' flags
						if(getBits(info_0, $(TexInfoBitOfs), 2)!=0)
						{
							if(getBit(info_0, $(TexInfoBitOfs)))	return ErrorColor; 
							else	return LoadingColor; 
						}
						
						//decode dimensions, size
						const uint dim = getBits(info_0, $(TexDimBitOfs), $(TexDimBits)); 
						if(dim!=TexDim_1D) return ErrorColor; 
						const uint size = IB[textDwIdx+1]/*fast access 1D size*/; 
						if(size==0) return ErrorColor; 
						
						
						//Prescale tex coordinates by size
						float pv = v; if(prescaleX) pv *= float(size); 
						
						//Clamp tex coordinates. Assume non-empty image.
						const int iv = int(pv); 
						const int clamped = max(min(iv, int(size)-1), 0); 
						
						//Calculate flat index
						const uint i = clamped; 
						
						//Get chunkIdx from info rec
						const uint chunkIdx = IB[textDwIdx+2]; 
						const uint dwIdx = chunkIdx * $(HeapGranularity/4); 
						
						//decode format (chn, bpp, alt)
						const uint chn = getBits(info_0, $(TexFormatBitOfs), $(TexChnBits)); 
						const uint bpp = getBits(info_0, $(TexFormatBitOfs + TexChnBits), $(TexBppBits)); 
						const bool alt = getBit(info_0, $(TexFormatBitOfs + TexChnBits + TexBppBits)); 
						
						if(chn==TexChn_4 && bpp==TexBpp_32)
						{
							//Opt: Cache all this palette reading operation!
							vec4 res = unpackUnorm4x8(TB[dwIdx + i]); 
							if(alt) {/*swap red-blue*/res.rgba = res.bgra; }
							return res; 
						}
						
						return ErrorColor; 
					} 
					
					/*Vector graphics state registers*/
					uint TF = 0, FF = 0, VF = 0; 	//flags: texFlags, fontFlags, vecFlags
					
					
					vec4 PC = vec4(1); 	/* Primary color - default black */
					vec4 SC = vec4(0); 	/* Secondary color - default white */
					float OP = 1; 	/* opacity*/
					
					//Todo: compress PC and SC to RGBA32
					
					float PS = 1; 	/* Point size */
					float LW = 1; 	/* Line width */
					float DL = 1; 	/* Dot lenthg */
					float FH = $(GSP_DefaultFontHeight); /* Font height */
					
					uint FMH = 0; 	/* Font map handle */
					uint LFMH = 0; 	/* Latin font map handle */
					uint PALH = 0; 	/* Palette handle */
					uint LTH = 0; 	/* Line texture handle */
					
					//Model - World coordinate transformation
					const vec4 initialClipBounds = vec4(-1e30, -1e30, 1e30, 1e30); 
					
					vec2 TR_scaleXY = vec2(1); 
					float TR_skewX_rad = 0; 
					float TR_rotZ_rad = 0; 
					vec2 TR_transXY = vec2(0); 
					vec4 TR_clipBounds = initialClipBounds; 
					
					void TR_reset()
					{
						TR_scaleXY = vec2(1); 
						TR_skewX_rad = 0; 
						TR_rotZ_rad = 0; 
						TR_transXY = vec2(0); 
						TR_clipBounds = initialClipBounds; 
					} 
					
					mat2 rotation2D(float angle)
					{
						float s = sin(angle), c = cos(angle); 
						return mat2(c, -s, s, c); 
					} 
					
					vec2 outputTransformPoint2D(vec2 p)
					{
						p *= TR_scaleXY; 
						if(TR_skewX_rad!=0) {
							p.x -= p.y * tan(TR_skewX_rad); 
							//Opt: cache this constant
						}
						if(TR_rotZ_rad!=0) {
							p = rotation2D(-TR_rotZ_rad) * p; 
							//Opt: cache this matrix
						}
						p += TR_transXY; 
						
						return p; 
					} 
					
					void emitVertex2D(vec2 p)
					{
						fragColor 	= vec4(PC.rgb, PC.a*OP),
						fragBkColor 	= vec4(SC.rgb, SC.a*OP); 
						
						vec2 w = outputTransformPoint2D(p); //model to world transform
						
						gl_ClipDistance[0] = w.x-TR_clipBounds.x; 
						gl_ClipDistance[1] = w.y-TR_clipBounds.y; 
						gl_ClipDistance[2] = TR_clipBounds.z-w.x; 
						gl_ClipDistance[3] = TR_clipBounds.w-w.y; 
						
						gl_Position = UB.mvp * vec4(w, 0, 1); //world to screen transform
						
						EmitVertex(); 
					} 
					
					void emitTexturedPointPointRect2D(in vec2 p, in vec2 q)
					{
						fragTexCoordXY = vec2(0,0); emitVertex2D(p); 
						fragTexCoordXY = vec2(0,1); emitVertex2D(vec2(p.x, q.y)); 
						fragTexCoordXY = vec2(1,0); emitVertex2D(vec2(q.x, p.y)); 
						fragTexCoordXY = vec2(1,1); emitVertex2D(q); 
						EndPrimitive(); 
					} 
					
					// Split at t = 0.33333333
					void splitBezier_third(
						in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3, 
						out vec2 Q0, out vec2 Q1, out vec2 Q2, out vec2 Q3,
						out vec2 R0, out vec2 R1, out vec2 R2, out vec2 R3
					)
					{
						vec2 a = 0.66666667 * P0 + 0.33333333 * P1; 
						vec2 b = 0.44444444 * P0 + 0.44444444 * P1 + 0.11111111 * P2; 
						vec2 c = 0.29629630 * P0 + 0.44444444 * P1 + 0.22222222 * P2 + 0.03703704 * P3; 
						vec2 d = 0.44444444 * P1 + 0.44444444 * P2 + 0.11111111 * P3; 
						vec2 e = 0.66666667 * P2 + 0.33333333 * P3; 
						
						Q0 = P0; Q1 = a; Q2 = b; Q3 = c; 
						R0 = c; R1 = d; R2 = e; R3 = P3; 
					} 
					
					// Split at t = 0.50000000
					void splitBezier_half(
						in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3,
						out vec2 Q0, out vec2 Q1, out vec2 Q2, out vec2 Q3,
						out vec2 R0, out vec2 R1, out vec2 R2, out vec2 R3
					)
					{
						vec2 a = 0.50000000 * P0 + 0.50000000 * P1; 
						vec2 b = 0.25000000 * P0 + 0.50000000 * P1 + 0.25000000 * P2; 
						vec2 c = 0.12500000 * P0 + 0.37500000 * P1 + 0.37500000 * P2 + 0.12500000 * P3; 
						vec2 d = 0.25000000 * P1 + 0.50000000 * P2 + 0.25000000 * P3; 
						vec2 e = 0.50000000 * P2 + 0.50000000 * P3; 
						
						Q0 = P0; Q1 = a; Q2 = b; Q3 = c; 
						R0 = c; R1 = d; R2 = e; R3 = P3; 
					} 
					
					// Split at t = 0.25000000
					void splitBezier_quarter(
						in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3,
						out vec2 Q0, out vec2 Q1, out vec2 Q2, out vec2 Q3,
						out vec2 R0, out vec2 R1, out vec2 R2, out vec2 R3
					)
					{
						vec2 a = 0.75000000 * P0 + 0.25000000 * P1; 
						vec2 b = 0.56250000 * P0 + 0.37500000 * P1 + 0.06250000 * P2; 
						vec2 c = 0.42187500 * P0 + 0.42187500 * P1 + 0.14062500 * P2 + 0.01562500 * P3; 
						vec2 d = 0.18750000 * P1 + 0.37500000 * P2 + 0.43750000 * P3; 
						vec2 e = 0.25000000 * P2 + 0.75000000 * P3; 
						
						Q0 = P0; Q1 = a; Q2 = b; Q3 = c; 
						R0 = c; R1 = d; R2 = e; R3 = P3; 
					} 
					
					bool splitBezier_ration(
						in int i, in int N, 
						in vec2 Q0, in vec2 Q1, in vec2 Q2, in vec2 Q3,
						out vec2 R0, out vec2 R1, out vec2 R2, out vec2 R3
					)
					{
						bool valid = true; int requestHalfSplit=-1; 
						if(N==1)
						{ R0=Q0, R1=Q1, R2=Q2, R3=Q3; }
						else if(N==2 || N==4)
						{
							vec2 A0,A1,A2,A3, B0,B1,B2,B3; 
							splitBezier_half(Q0,Q1,Q2,Q3, A0,A1,A2,A3, B0,B1,B2,B3); 
							if((i&(N/2))==0)	R0=A0, R1=A1, R2=A2, R3=A3; 
							else	R0=B0, R1=B1, R2=B2, R3=B3; 
							if(N==4)
							{ requestHalfSplit = i&1; }
						}
						else if(N==3)
						{
							vec2 A0,A1,A2,A3, B0,B1,B2,B3; 
							splitBezier_third(Q0,Q1,Q2,Q3, A0,A1,A2,A3, B0,B1,B2,B3); 
							if(i==0) R0=A0, R1=A1, R2=A2, R3=A3; 
							else {
								R0=B0, R1=B1, R2=B2, R3=B3; 
								requestHalfSplit = i-1; 
							}
						}
						else { valid = false; }
						
						if(valid && requestHalfSplit>=0)
						{
							vec2 A0,A1,A2,A3, B0,B1,B2,B3; 
							splitBezier_half(R0,R1,R2,R3, A0,A1,A2,A3, B0,B1,B2,B3); 
							if(requestHalfSplit==0)	R0=A0, R1=A1, R2=A2, R3=A3; 
							else	R0=B0, R1=B1, R2=B2, R3=B3; 
						}
						
						if(!valid) R0=Q0, R1=Q1, R2=Q2, R3=Q3; 
						return valid; 
					} 
					
					
					float calcManhattanLength(in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3)
					{
						const vec2 v = abs(P3-P2) + abs(P2-P1) + abs(P1-P0); 
						return v.x + v.y; 
					} 
					
					vec2 evalCubicBezier2D(in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3, in vec4 w)
					{ return P0*w.x + P1*w.y + P2*w.z + P3*w.w; } 
					vec4 cubicBezierPointWeights(in float t)
					{ const float u = 1-t; return vec4(u*u*u, 3*t*u*u, 3*u*t*t, t*t*t); } 
					vec4 cubicBezierTangentWeights(in float t)
					{ const float u = 1-t; return vec4(-3*u*u, 3*u*u - 6*u*t, 6*u*t - 3*t*t, 3*t*t); } 
					vec2 cubicBezierPoint2D(in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3, in float t)
					{ return evalCubicBezier2D(P0, P1, P2, P3, cubicBezierPointWeights(t)); } 
					vec2 cubicBezierTangent2D(in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3, in float t)
					{ return evalCubicBezier2D(P0, P1, P2, P3, cubicBezierTangentWeights(t)); } 
					
					vec2 cubicBezierNormal2D(in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3, in float t)
					{ return rotate90(normalize(cubicBezierTangent2D(P0, P1, P2, P3, t))); } 
					
					void emitCubicBezierAt(
						in float t, in 
						vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3, 
						in float r0, in float r1
					)
					{
						const vec2 	p = cubicBezierPoint2D(P0, P1, P2, P3, t),
							n = cubicBezierNormal2D(P0, P1, P2, P3, t) * mix(r0, r1, t); 
						fragTexCoordXY = vec2(t, 0); emitVertex2D(p-n); 
						fragTexCoordXY = vec2(t, 1); emitVertex2D(p+n); 
					} 
					
					void emitBezierAtStart(vec2 P0, in vec2 P1, in float r)
					{
						const vec2 	p = P0,
							n = rotate90(normalize(P1-P0)) * r; 
						fragTexCoordXY = vec2(0, 0); emitVertex2D(p-n); 
						fragTexCoordXY = vec2(0, 1); emitVertex2D(p+n); 
					} 
					
					
					bool intersectSegs2D(in seg2 S0, in seg2 S1, out vec2 P)
					{
						vec2 	S	= S1.p[0] - S0.p[0],
							T	= S0.p[1] - S0.p[0],
							U 	= S1.p[0] - S1.p[1]; 
						float det = crossZ(T, U); 
						
						if(abs(det)<1e-30) return false;  //Todo: this is lame
						
						float detA = crossZ(S, U); 
						
						if(inRange_sorted(detA, 0, det))
						{
							//have one intersection
							float detB = crossZ(T, S); 
							if(inRange_sorted(detB, 0, det)) {
								float alpha = detA/det; 
								P = S0.p[0]+T*alpha; 
								return true; 
							}
						}
						return false; 
					} 
					
					const int tesselateCubicBezierTentacle_N = 7; 
					
					void tesselateCubicBezierTentacle_updateRay(inout seg2 ray, in int i, in vec2 p, in bool dir, in float rayLen)
					{
						if(i==0) ray.p[0] = p; 
						else if(i==1) ray.p[1] = p; 
						else {
							if((crossZ(ray.p[1]-ray.p[0], p-ray.p[0])>=0)==dir) ray.p[1] = p; 
							if(i==tesselateCubicBezierTentacle_N-3)
							ray.p[1] = ray.p[0] + normalize(ray.p[1]-ray.p[0])*rayLen; 
						}
					} 
					
					void calcCubicBezierMidPoints(
						in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3, in float r0, in float r1,
						out vec2 M0, out vec2 M1
					)
					{
						const int N = tesselateCubicBezierTentacle_N; 
						const float[N] t = {0, 0.01, 0.33333, 0.5, 0.66666, 0.99, 1}; 
						
						vec2[N] points, sides; 
						for(int i=0; i<N; i++)
						{
							points[i] = cubicBezierPoint2D(P0, P1, P2, P3, t[i]); 
							sides[i] = cubicBezierNormal2D(P0, P1, P2, P3, t[i]) * mix(r0, r1, t[i]); 
						}
						
						const float maxRayLen = calcManhattanLength(P0, P1, P2, P3)*4; 
						seg2 rayRightFwd, rayRightBack, rayLeftFwd, rayLeftBack; 
						for(int i=0; i<N-2; i++)
						{
							int k = N-1-i; 
							tesselateCubicBezierTentacle_updateRay(rayRightFwd, i, points[i] + sides[i], true, maxRayLen); 
							tesselateCubicBezierTentacle_updateRay(rayRightBack, i, points[k] + sides[k], false, maxRayLen); 
							tesselateCubicBezierTentacle_updateRay(rayLeftFwd  , i, points[i] - sides[i], false, maxRayLen); 
							tesselateCubicBezierTentacle_updateRay(rayLeftBack  , i, points[k] - sides[k], true, maxRayLen); 
						}
						
						if(!intersectSegs2D(rayLeftFwd , rayLeftBack , M0)) M0 = points[N/2] - sides[N/2]; 
						if(!intersectSegs2D(rayRightFwd, rayRightBack, M1)) M1 = points[N/2] + sides[N/2]; 
					} 
					
					void emitCubicBezierMidJoint(in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3, in float r0, in float r1)
					{
						vec2 M0, M1; 
						calcCubicBezierMidPoints(P0, P1, P2, P3, r0, r1, M0, M1); 
						fragTexCoordXY = vec2(.5, 0); emitVertex2D(M0); 
						fragTexCoordXY = vec2(.5, 1); emitVertex2D(M1); 
					} 
					
					
					void emitLineJoint(in vec2 P0, in vec2 P1, in vec2 P2, in float r0, in float r1, in float r2)
					{
						/*
							P0-P1 and P1-P2 defines 2 line segments.
							W0, W1, W2 defiles linewidth at P0, P1, P2.
							The x coordinate of points can be nan, that meant there is no point defined 
							and P1 is the start or the end of a line.
							If this is the cast an endcap must be generated, the depth of the cap is 
							W1/2 in length, so later a pixel shader can paint a nice roundcap there.
							If P1.x is null it means that there is nothing at this particular line joint.
							The primitive type is triangle strip, so ideally it should emit 2 vertices.
							The 2 vertex is the intersection points of the two side boundary lines at 
							segments P0-P1 and P1-P2. Be careful with the linewidts at the 3 points.
							Make the intersection calculation safe, they should fallback tho an existing 
							point at a valid linewidth distance.
						*/
						
						// Handle case where P1 is invalid (no joint to process)
						if(isnan(P1.x)) return; 
						
						bool hasPrev = !isnan(P0.x), hasNext = !isnan(P2.x); 
						if(!hasPrev && !hasNext) return; 
						
						// Calculate direction vectors
						vec2 dirPrev = hasPrev ? normalize(P1 - P0) : vec2(0); 
						vec2 dirNext = hasNext ? normalize(P2 - P1) : vec2(0); 
						
						// Calculate perpendicular vectors for offset directions
						vec2 perpPrev = hasPrev ? vec2(-dirPrev.y, dirPrev.x) : vec2(0); 
						vec2 perpNext = hasNext ? vec2(-dirNext.y, dirNext.x) : vec2(0); 
						
						if(!hasPrev)
						{
							// Start cap - emit perpendicular offset
							vec2 P = P1 - dirNext * (r1); vec2 capDir = perpNext * (r1); 
							fragTexCoordXY = vec2(0, 0); emitVertex2D(P - capDir ); 
							fragTexCoordXY = vec2(0, 1); emitVertex2D(P + capDir); 
							return; 
						}
						
						if(!hasNext)
						{
							// End cap - emit perpendicular offset
							vec2 P = P1 + dirPrev * (r1); vec2 capDir = perpPrev * (r1); 
							fragTexCoordXY = vec2(0, 0); emitVertex2D(P - capDir); 
							fragTexCoordXY = vec2(0, 1); emitVertex2D(P + capDir); 
							EndPrimitive(); 
							return; 
						}
						
						fragTexCoordXY = vec2(0, 0); emitVertex2D(
							lineIntersection(
								P0 - perpPrev*(r0), 
								P1 - perpPrev*(r1), 
								P1 - perpNext*(r1), 
								P2 - perpNext*(r2)
							)
						); 
						fragTexCoordXY = vec2(0, 1); emitVertex2D(
							lineIntersection(
								P0 + perpPrev*(r0), 
								P1 + perpPrev*(r1), 
								P1 + perpNext*(r1), 
								P2 + perpNext*(r2)
							)
						); 
					} 
					
					struct BitStream
					{
						uint dwOfs; //the dword offset of the NEXT fetched dword.
						uint currentDw; //the current dword that is fetched
						int currentDwBits; /*
							how many of the lower bits are valid in the current dword, 
							if zero, the next dword must be fetched
						*/
						/*uint totalBitsRemaining; *//*overflow checking*/
					}; 
					
					uint fetchBits(inout BitStream bitStream, in uint numBits)
					{
						/*
							//overflow checking
							if(numBits>bitStream.totalBitsRemaining) { bitStream.totalBitsRemaining = 0; return 0; }
							bitStream.totalBitsRemaining -= numBits; 
						*/
						
						uint result = 0; 
						int bitsRemaining = int(numBits); 
						while(bitsRemaining > 0)
						{
							// If current dword is exhausted, fetch next one
							if(bitStream.currentDwBits == 0)
							{
								bitStream.currentDw = GB[bitStream.dwOfs]; 
								bitStream.dwOfs++; 
								bitStream.currentDwBits = 32; 
							}
							
							// Calculate how many bits we can take this iteration
							int bitsToTake = min(bitsRemaining, bitStream.currentDwBits); 
							
							// Extract the bits we need (using bitfieldExtract)
							uint extracted = bitfieldExtract(bitStream.currentDw, 0, bitsToTake); 
							
							// Insert them into the result (using bitfieldInsert)
							result = bitfieldInsert(result, extracted, int(numBits) - bitsRemaining, bitsToTake); 
							
							// Remove used bits from current dword (using bitfieldExtract for the remaining bits)
							bitStream.currentDw >>= bitsToTake; 
							bitStream.currentDwBits -= bitsToTake; 
							bitsRemaining -= bitsToTake; 
						}
						
						return result; 
					} 
					
					bool fetch_bool(inout BitStream bitStream)
					{
						/*
							//overflow check
										if(bitStream.totalBitsRemaining==0) { return false; }
										bitStream.totalBitsRemaining--; 
						*/
						
						if(bitStream.currentDwBits == 0)
						{
							bitStream.currentDw = GB[bitStream.dwOfs]; 
							bitStream.dwOfs++; 
							bitStream.currentDwBits = 32; 
						}
						
						bool bit = (bitStream.currentDw & 1u) != 0; 
						bitStream.currentDw >>= 1; 
						bitStream.currentDwBits--; 
						
						return bit; 
					} 
					
					int fetch_int(inout BitStream bitStream, in int numBits)
					{ return bitfieldExtract(int(fetchBits(bitStream, numBits)), 0, numBits); } 
					
					uint fetch_uint(inout BitStream bitStream, in int numBits)
					{
						return fetchBits(bitStream, numBits); 
						/*Opt: this 32bit read should be optimized*/
					} 
					
					float fetch_float(inout BitStream bitStream)
					{ return uintBitsToFloat(fetch_uint(bitStream, 32)); } 
					
					vec2 fetch_vec2(inout BitStream bitStream)
					{ return vec2(fetch_float(bitStream), fetch_float(bitStream)); } 
					
					vec3 fetch_vec3(inout BitStream bitStream)
					{
						return vec3(
							fetch_float(bitStream), fetch_float(bitStream),
							fetch_float(bitStream)
						); 
					} 
					vec4 fetch_vec4(inout BitStream bitStream)
					{
						return vec4(
							fetch_float(bitStream), fetch_float(bitStream),
							fetch_float(bitStream), fetch_float(bitStream)
						); 
					} 
					
					
					BitStream initBitStream(uint bitOfs/*, uint nextBitOfs*/)
					{
						BitStream bitStream; 
						bitStream.dwOfs = bitOfs >> 5; 
						bitStream.currentDwBits = 0; 
						uint bitsToSkip = bitOfs & 0x1F; 
						if(bitsToSkip > 0)
						{ uint dummy = fetchBits(bitStream, bitsToSkip); }
						
						/*bitStream.totalBitsRemaining = nextBitOfs - bitOfs; //overflow check*/
						return bitStream; 
					} 
					
					$(TexFlags.GLSLCode)
					$(FontFlags.GLSLCode)
					$(VecFlags.GLSLCode)
					
					/* Helper functions for fetching different data formats */
					$(GEN_enumDefines!ColorFormat)
					uint fetchColorFormat(inout BitStream bitStream)
					{ return fetchBits(bitStream, $(EnumBits!ColorFormat)); } 
					
					
					int fetchColor(inout BitStream bitStream, uint format, inout vec4 color)
					{
						//return code: 1: color changed, 2: alpha changed, 3: both
						
						//optimization strategy: extra math, but less divergence
						if(format<=ColorFormat_a_u8 /*rgba_u8 .. a_u8*/)
						{
							const int bits = int((ColorFormat_a_u8 + 1 - format)*8); 
							const vec4 tmp = unpackUnorm4x8(fetchBits(bitStream, bits)); 
							switch(format)
							{
								case ColorFormat_rgba_u8: 	color = tmp; 	return 3; 
								case ColorFormat_rgb_u8: 	color.rgb = tmp.xyz; 	return 1; 
								case ColorFormat_la_u8: 	color.rgb = vec3(tmp.x), color.a = tmp.y; 	return 3; 
								case ColorFormat_a_u8: 	color.a = tmp.x; 	return 2; 
							}
						}
						else if(format<=ColorFormat_u8 /*u1, u2, u4, u8*/)
						{
							const int idx = int(format - ColorFormat_u1); //0..3
							const int bits = 1<<idx; //1, 2, 4, 8
							const float high = float((1<<bits) - 1); //1, 3, 15, 255
							const uint raw = fetchBits(bitStream, bits); 
							if(PALH!=0)	{ color = readPaletteSample(PALH, raw, false)/*palette lookup*/; return 3; }
							else	{ color.rgb = vec3(float(raw) / high)/*grayscale*/; return 1; }
						}
						return 0; 
					} 
					
					//setting RGB automatically sets alpha to 1
					int fetchColor2(inout BitStream bitStream, uint format, inout vec4 color)
					{
						int res = fetchColor(bitStream, format, color); 
						if(res == 1) { color.a = 1; res = 3; }
						return res; 
					} 
					
					$(GEN_enumDefines!SizeFormat)
					uint fetchSizeFormat(inout BitStream bitStream)
					{ return fetchBits(bitStream, $(EnumBits!SizeFormat)); } 
					
					float fetchSize(inout BitStream bitStream, uint format)
					{
						switch(format)
						{
							case SizeFormat_u4: 	return float(fetchBits(bitStream, 4)); 
							case SizeFormat_u8: 	return float(fetchBits(bitStream, 8)); 
							case SizeFormat_ulog12: 	return exp2(float(fetchBits(bitStream, 12)) / 128.0); 
							case SizeFormat_f32: 	return fetch_float(bitStream); 
							default: return 1.0; 
						}
					} 
					
					float fetchFormattedSize(inout BitStream bitStream)
					{ return fetchSize(bitStream, fetchSizeFormat(bitStream)); } 
					
					$(GEN_enumDefines!AngleFormat)
					uint fetchAngleFormat(inout BitStream bitStream)
					{ return fetchBits(bitStream, $(EnumBits!AngleFormat)); } 
					
					float fetchAngle_rad(inout BitStream bitStream, uint format)
					{
						switch(format)
						{
							//case AngleFormat_u2: 	return float(fetchBits(bitStream, 2))*(PI/2.0); 
							//case AngleFormat_u4: 	return float(fetchBits(bitStream, 4))*(PI/8.0); 
							case AngleFormat_i10: 	return radians(float(fetch_int(bitStream, 10))); 
							case AngleFormat_f32: 	return radians(fetch_float(bitStream)); 
						}
						return 0.0; 
					} 
					
					float fetchFormattedAngle_rad(inout BitStream bitStream)
					{ return fetchAngle_rad(bitStream, fetchAngleFormat(bitStream)); } 
					
					
					$(GEN_enumDefines!HandleFormat)
					uint fetchHandleFormat(inout BitStream bitStream)
					{ return fetchBits(bitStream, $(EnumBits!HandleFormat)); } 
					
					uint fetchHandle(inout BitStream bitStream, uint format)
					{
						switch(format) {
							case HandleFormat_u12: 	return fetchBits(bitStream, 12); 
							case HandleFormat_u16: 	return fetchBits(bitStream, 16); 
							case HandleFormat_u24: 	return fetchBits(bitStream, 24); 
							case HandleFormat_u32: 	return fetch_uint(bitStream, 32); 
							default: return 0; 
						}
					} 
					
					$(GEN_enumDefines!CoordFormat)
					uint fetchCoordFormat(inout BitStream bitStream)
					{ return fetchBits(bitStream, $(EnumBits!CoordFormat)); } 
					
					float fetchCoord(inout BitStream bitStream, uint format)
					{
						int bits=0; 
						switch(format)
						{
							case CoordFormat_f32: 	return fetch_float(bitStream); 
							case CoordFormat_i32: 	bits = 32; 	break; 
							case CoordFormat_i16: 	bits = 16; 	break; 
							case CoordFormat_i8: 	bits = 8; 	break; 
						}
						if(bits>0) return float(fetch_int(bitStream, bits)); 
						return 0; 
						/*Opt: Do it with single fetch*/
					} 
					
					vec2 fetchFormattedPoint2D(inout BitStream bitStream)
					{
						//fetches absolute 2D point
						const uint coordFmt = fetchCoordFormat(bitStream); 
						return vec2(
							fetchCoord(bitStream, coordFmt), 
							fetchCoord(bitStream, coordFmt)
						); 
					} 
					
					$(GEN_enumDefines!XYFormat)
					uint fetchXYFormat(inout BitStream bitStream)
					{ return fetchBits(bitStream, $(EnumBits!XYFormat)); } 
					
					vec2 fetchXY(inout BitStream bitStream, vec2 p/*prev point*/)
					{
						//fetches absolute or relative 2D point
						const uint xyFmt = fetchXYFormat(bitStream); 
						const uint coordFmt = fetchCoordFormat(bitStream); 
						const float f0 = ((xyFmt<=XYFormat_relY) ?(fetchCoord(bitStream, coordFmt)):(0)); 
						const float f1 = ((xyFmt<=XYFormat_relXY) ?(fetchCoord(bitStream, coordFmt)):(0)); 
						switch(xyFmt)
						{
							case XYFormat_absXY: 	return vec2(f0, f1); 
							case XYFormat_relXY: 	return p+vec2(f0, f1); 
							case XYFormat_absX: 	return vec2(f0, p.y); 
							case XYFormat_relX: 	return vec2(p.x+f0, p.y); 
							case XYFormat_absY: 	return vec2(p.x, f0); 
							case XYFormat_relY: 	return vec2(p.x, p.y+f0); 
							case XYFormat_absXrelY1: 	return vec2(f0, p.y+1); 
							case XYFormat_relX1absY: 	return vec2(p.x+1, f0); 
							default: 	return vec2(0)/*invalid*/; 
						}
					} 
					
					void setOpacity(inout BitStream bitStream)
					{ OP = float(fetch_uint(bitStream, 8))/255; } 
					
					$(GEN_enumDefines!FlagFormat)
					void setFlags(inout BitStream bitStream)
					{
						const uint fmt = fetchBits(bitStream, $(EnumBits!FlagFormat)); 
						
						if(fmt==FlagFormat_all || fmt==FlagFormat_tex) TF = fetchBits(bitStream, $(FlagBits!TexFlags)); 
						if(fmt==FlagFormat_all || fmt==FlagFormat_font) FF = fetchBits(bitStream, $(FlagBits!FontFlags)); 
						if(fmt==FlagFormat_all || fmt==FlagFormat_vec) VF = fetchBits(bitStream, $(FlagBits!VecFlags)); 
						/*Opt: Do it all with a single fetchBits call*/
					} 
					
					$(GEN_enumDefines!TransFormat)
					void setTrans(inout BitStream bitStream)
					{
						const uint fmt = fetchBits(bitStream, $(EnumBits!TransFormat)); 
						
						switch(fmt)
						{
							case TransFormat_unity: 
								{ TR_reset(); }
							break; 
							
							case TransFormat_transXY: 
								{
								//can use outputTransformPoint2D(fetchP) for relative transform
								TR_transXY = fetchFormattedPoint2D(bitStream); 
							}
							break; 
							
							case TransFormat_skewX: 
								{ TR_skewX_rad = fetchFormattedAngle_rad(bitStream); }
							break; 
							
							case TransFormat_rotZ: 
								{ TR_rotZ_rad = fetchFormattedAngle_rad(bitStream); }
							break; 
							
							case TransFormat_scale: case TransFormat_scaleXY: 
								{
								const float 	sx = fetchFormattedSize(bitStream),
									sy = ((fmt==TransFormat_scaleXY) ?(fetchFormattedSize(bitStream)):(sx)); 
								TR_scaleXY = vec2(sx, sy); 
							}
							break; 
							
							case TransFormat_clipBounds: 
								{
								//absolute coords: topLeft, widthHeight
								TR_clipBounds.xy = fetchFormattedPoint2D(bitStream); 
								TR_clipBounds.zw = 	TR_clipBounds.xy +
									fetchFormattedPoint2D(bitStream); 
							}
							break; 
						}
					} 
					
					
					/*Position queue*/
					
					vec2 	P0 	= vec2(0)
					,	P1 	= vec2(0)
					,	P2 	= vec2(0)
					,	P3	= vec2(0)
					,	P4 	= vec2(0); 
					#define PathCodeQueue_lastIdx 4
					
					uint PathCodeQueue = 0; 
					
					/*nop*/	#define PathCode_none 0
						
					/*move to*/	#define PathCode_M 1
					/*
						tangent 
						(for interrupted paths)
					*/	#define PathCode_TG 2
					/*line to*/	#define PathCode_L 3
						
					/*
						quadratic bezier smoot point
						(turns into Q1, no fetch)
					*/	#define PathCode_T1 4
					/*quadratic bezier control point*/	#define PathCode_Q1 5
					/*quadratic bezier endpoint*/	#define PathCode_Q2 6
						
					/*
						cubic bezier smoot point
						(turns into C1, no fetch)
					*/	#define PathCode_S1 7
					/*cubic bezier control point*/	#define PathCode_C1 8
					/*cubic bezier control point*/	#define PathCode_C2 9
					/*cubic bezier endpoint*/	#define PathCode_C3 10
					
					#define PathCode_bits 4
					
					uint PathCode(int idx)
					{ return getBits(PathCodeQueue, idx*PathCode_bits, PathCode_bits); } 
					
					/*S or T*/
					bool PathCode_isSmooth(uint c)
					{ return c==PathCode_T1 || c==PathCode_S1; } 
					
					/*internal bezier points and the last points of the curve*/
					bool PathCode_isBezier(uint c)
					{ return c>=PathCode_T1 && c<=PathCode_C3; } 
					
					/*only the internal bezier ponts*/
					bool PathCode_isControlPoint(uint c)
					{
						return c>=PathCode_T1 && c<=PathCode_Q1 ||
						c>=PathCode_S1 && c<=PathCode_C2; 
					} 
					
					uint PathCode_next(uint c)
					{
						if(PathCode_isSmooth(c)) c++; 
						if(PathCode_isControlPoint(c)) c++; 
						else c = PathCode_none; 
						return c; 
					} 
					
					vec4 PathCodeQueue_debugColor()
					{
						vec4 c = vec4(0, 1, 0, 1); //lines are green
						//detect 3 phase of Q
						if(PathCode(2)==PathCode_Q1) return vec4(1,0,0,1); 
						if(PathCode(2)==PathCode_Q2) return vec4(1,1,0,1); 
						if(PathCode(1)==PathCode_Q2) return vec4(1,1,.5,1); 
						
						//detect 4 phase of C
						if(PathCode(2)==PathCode_C1) return vec4(0,0,1,1); 
						if(PathCode(2)==PathCode_C2) return vec4(0,.5,1,1); 
						if(PathCode(2)==PathCode_C3) return vec4(0,1,1,1); 
						if(PathCode(1)==PathCode_C3) return vec4(.5,1,1,1); 
						
						return vec4(0, 1, 0, 1); //lines are green
					} 
					
					void emitPathCodeDebugPoint(uint code, float r)
					{
						setFragMode(FragMode_fullyFilled); PC = vec4(1,0,1,1); 
						switch(code)
						{
							case PathCode_M: 	PC = vec4(.5,.5,.5,1); 	break; 
							case PathCode_L: 	PC = vec4(0,1,0,1); 	break; 
							case PathCode_TG: 	PC = vec4(1,.5,1,1); 	break; 
							case PathCode_Q1: 	PC = vec4(1,0,0,1); 	break; 
							case PathCode_Q2: 	PC = vec4(1,1,0,1); 	break; 
							case PathCode_C1: 	PC = vec4(0,0,1,1); 	break; 
							case PathCode_C2: 	PC = vec4(0,.5,1,1); 	break; 
							case PathCode_C3: 	PC = vec4(0,1,1,1); 	break; 
						}
						emitTexturedPointPointRect2D(P4-r, P4+r); 
					} 
					
					void latchP(vec2 newP)
					{ P0=P1, P1=P2, P2=P3, P3=P4, P4=newP; } 
					
					vec2 smoothMirror()
					{
						/*mirrors P2 over P3, so it can be assigned to P4*/
						return P3*2 - P2; 
					} 
					
					
					void setFragModeAndFloats(in uint mode, in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3, bool trans)
					{
						setFragMode(mode); 
						if(trans) {
							fragFloats0.xy 	= outputTransformPoint2D(P0), 
							fragFloats0.zw 	= outputTransformPoint2D(P1), 
							fragFloats1.xy 	= outputTransformPoint2D(P2), 
							fragFloats1.zw 	= outputTransformPoint2D(P3); 
						}else {
							fragFloats0.xy 	= P0, 
							fragFloats0.zw 	= P1, 
							fragFloats1.xy 	= P2, 
							fragFloats1.zw 	= P3; 
						}
					} 
					
					void setFragMode_L(in uint mode, in vec2 P0, in vec2 P1)
					{ setFragModeAndFloats(mode, P0, mix(P0, P1, 1/3.0), mix(P0, P1, 2/3.0), P1, true); } 
					
					void setFragMode_Q(in uint mode, in vec2 P0, in vec2 P1, in vec2 P2)
					{ setFragModeAndFloats(mode, P0, mix(P0, P1, 2/3.0), mix(P1, P2, 1/3.0), P2, true); } 
					
					void setFragMode_C(in uint mode, in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3)
					{ setFragModeAndFloats(mode, P0, P1, P2, P3, true); } 
					
					void convertQuadtraticBezierControlPointsToCubic(
						in vec2 P0, in vec2 P1, in vec2 P2,
						out vec2 Q0, out vec2 Q1, out vec2 Q2, out vec2 Q3
					)
					{ Q0=P0, Q1=mix(P0, P1, 2/3.0), Q2=mix(P1, P2, 1/3.0), Q3=P2; } 
					
					void copyCubicBezierControlPoints(
						in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3,
						out vec2 Q0, out vec2 Q1, out vec2 Q2, out vec2 Q3
					)
					{ Q0=P0, Q1=P1, Q2=P2, Q3=P3; } 
					
					void acquireCubicBezierControlPoints(
						in bool isQuadratic,
						in vec2 P0, in vec2 P1, in vec2 P2, in vec2 P3,
						out vec2 Q0, out vec2 Q1, out vec2 Q2, out vec2 Q3
					)
					{
						if(isQuadratic)
						convertQuadtraticBezierControlPointsToCubic(
							P0,P1,P2, 
							Q0,Q1,Q2,Q3
						); 
						else
						copyCubicBezierControlPoints             (
							P0,P1,P2,P3, 
							Q0,Q1,Q2,Q3
						); 
						
					} 
					
					void shiftInPathCode(uint code)
					{
						PathCodeQueue >>= PathCode_bits; 
						setBits(PathCodeQueue, PathCodeQueue_lastIdx*PathCode_bits, PathCode_bits, code); 
						
						const bool 	Mode_Points 	= $(bezierTesselationSettings.mode == BTSM.points)
						,	Mode_PerPixel 	= $(bezierTesselationSettings.mode == BTSM.perPixel)
						,	EnableDebugColors 	= false /*debug only, ruins normal colors*/; 
						
						const float r = LW/2;  //Todo: properly delayed and linearly changing radius handling!!!
						if(Mode_Points)
						{ emitPathCodeDebugPoint(code, r); }
						else
						{
							const uint PC1 = PathCode(1), PC2 = PathCode(2); 
							
							if(EnableDebugColors) { PC = PathCodeQueue_debugColor(); }
							
							if(Mode_PerPixel)
							{
								switch(PC2)
								{
									case PathCode_L: 	setFragMode_L(FragMode_cubicBezier, P1, P2); 	break; 
									case PathCode_Q1: 	setFragMode_Q(FragMode_cubicBezier, P1, P2, P3); 	break; 
									case PathCode_C1: 	setFragMode_C(FragMode_cubicBezier, P1, P2, P3, P4); 	break; 
									/*Todo: _line mode for rounded lines*/
								}
							}
							else
							{ setFragModeAndFloats(FragMode_fullyFilled, vec2(0), vec2(0), vec2(0), vec2(0), false); }
							
							/*
								Todo: Remake this in a way that it emits evry primitive as fast as it can.
								It is maybe impossible because beziers must know their control points BEFORE the first verices.
							*/
							if(PC1>=PathCode_L || PC2>=PathCode_L /*any line or curve*/)
							{
								if(PC2==PathCode_Q2 || PC2==PathCode_C2 || PC2==PathCode_C3 /*any curve*/)
								{
									if(PC2!=PathCode_C3)
									{
										vec2 Q0,Q1,Q2,Q3; /*Q: cubic bezier params*/
										const bool isQuadratic = PC2==PathCode_Q2; 
										acquireCubicBezierControlPoints(isQuadratic, P0,P1,P2,P3, Q0,Q1,Q2,Q3); 
										const int N = ((isQuadratic)?($(bezierTesselationSettings.quadraticSegments)) :($(bezierTesselationSettings.cubicSegments))); 
										if(Mode_PerPixel)
										{
											for(int i=0; i<N; i++)
											{
												vec2 R0,R1,R2,R3; 
												if(splitBezier_ration(i, N, Q0,Q1,Q2,Q3, R0,R1,R2,R3))
												{
													/*
														//local bezier params. This are simpler than the whole curve
														setFragMode_C(FragMode_cubicBezier, R0, R1, R2, R3); 
													*/
													if(i>0) emitBezierAtStart(R0, R1, r); 
													emitCubicBezierMidJoint(R0, R1, R2, R3, r, r); 
												}
											}
										}
										else
										{
											const float invN = 1.0/N; 
											for(int i=1; i<N; i++)
											emitCubicBezierAt(i*invN, Q0, Q1, Q2, Q3, r, r); 
										}
									}
								}
								else
								{
									//Todo: this should be P2, P3, P4.  As fast as it can!
									emitLineJoint(
										PathCode(1)<=PathCode_M ? vec2(nan) : P0, 
										P1, 
										PathCode(2)<=PathCode_M ? vec2(nan) : P2, 
										r, r, r
									); 
								}
							}
						}
						
						//Todo: automatically close the final path via appending an empty PathCode_M
					} 
					
					
					//Internal state for batch operations
					uint pendingChars = 0; 
					bool repeated; 
					uint repeatedChar; 
					//Opt: put all this information into one uint!
					void drawMove(inout BitStream bitStream)
					{ P4 = fetchFormattedPoint2D(bitStream); } 
					
					void drawTexturedRect(inout BitStream bitStream)
					{
						P3 = P4; P4 = fetchFormattedPoint2D(bitStream); 
						
						const uint handleFmt = fetchHandleFormat(bitStream); ; 
						const uint texHandle = fetchHandle(bitStream, handleFmt); 
						
						setFragMode(FragMode_fullyFilled); 
						setFragTexHandle(texHandle); 
						fragTexCoordZ = 0; //Todo: should optionally come from the outside
						
						emitTexturedPointPointRect2D(P3.xy, P4.xy); 
					} 
					
					const bool EnbaleAsciiStrips = true; 
					
					void drawASCII_rect(uint ch)
					{
						vec2 size = vec2(getTexSize(FMH).xy); 
						size *= FH*(1.0/size.y); 
						fragTexCoordZ = ch; 
						emitTexturedPointPointRect2D(P4.xy, P4.xy+size); 
						
						P4.x += size.x; //advance cursor
					} 
					
					void drawASCII_strip(uint ch, bool isLast)
					{
						vec2 size = vec2(getTexSize(FMH).xy); //Opt: cache these size calculations
						size *= FH*(1.0/size.y); 
						
						fragTexCoordZ = ch; 
						
						fragTexCoordXY.y = 0; emitVertex2D(P4.xy); 
						fragTexCoordXY.y = 1; emitVertex2D(vec2(P4.x, P4.y + size.y)); 
						
						//advance
						P4.x += size.x; 
						fragTexCoordXY.x += 1; //only the .fract is used
						
						if(isLast)
						{
							fragTexCoordXY.y = 0; emitVertex2D(P4.xy); 
							fragTexCoordXY.y = 1; emitVertex2D(vec2(P4.x, P4.y + size.y)); 
							EndPrimitive(); 
						}
					} 
					
					void drawChars(inout BitStream bitStream, bool repeated_)
					{
						pendingChars = fetchBits(bitStream, 6)+1; 
						repeated = repeated_; 
						if(repeated) repeatedChar = fetchBits(bitStream, 8); 
						
						setFragTexHandle(FMH); 
						setFragMode(EnbaleAsciiStrips ? FragMode_glyphStrip : FragMode_fullyFilled); 
						fragTexCoordXY.x = 0; 
					} 
					
					float 	Ph 	= 0, 
						Ph_next 	= 0; 	/* Phase coordinate */
						
					int runningCntr = 256; 	/*
						Execution is enabled if it's greater than 0
						After every step it's decremented.
					*/
					
					uint pendingPathCode = 0; 
					
					void processInstruction(inout BitStream bitStream) 
					{
						const bool canFetchInstr = pendingChars==0 && pendingPathCode==0; 
						
						if(canFetchInstr)
						{
							const uint opcode = 
							fetchBits(bitStream, 5); const bool mainCat = 
							getBit(opcode, 0); const uint subCat = 
							getBits(opcode, 1, 2); const uint cmd = 
							getBits(opcode, 3, 2); 
							if(
								!mainCat //settings
							)
							{
								bool colorsChanged = false; 
								switch(subCat)
								{
									case 0: //system
										switch(cmd)
									{
										case 0: 	runningCntr = 0; 	/*end - 5 zeroes at end of VBO*/	break; 
										case 1: 	setOpacity(bitStream); 	/*opacity for both PS and SC*/	break; 
										case 2: 	setFlags(bitStream); 	/*set flags*/	break; 
										case 3: 	setTrans(bitStream); 	/*set output transformation*/	break; 
									}
									break; 
									case 1: //colors
										{
										const uint fmt = fetchColorFormat(bitStream); 
										int copyFlags = 0; /*bit0: RGB changed, bit1: Alpha changed*/
										if(cmd!=1) copyFlags = fetchColor2(bitStream, fmt, PC); 
										if(cmd==1 || cmd==2) fetchColor2(bitStream, fmt, SC); 
										else if(cmd==3) {
											if((copyFlags & 1)!=0) SC.rgb = PC.rgb; 
											if((copyFlags & 2)!=0) SC.a = PC.a; 
										}
										colorsChanged = true; 
									}
									break; 
									case 2: //sizes
										{
										const uint fmt = fetchSizeFormat(bitStream); 
										const float size = fetchSize(bitStream, fmt); 
										switch(cmd)
										{
											case 0: 	PS = size; 	/* set pixel size*/	break; 
											case 1: 	LW = size; 	/* set line width*/	break; 
											case 2: 	DL = size; 	/* set dot length*/	break; 
											case 3: 	FH = size; 	/* set font height*/	break; 
										}
									}
									break; 
									case 3: //handles
										{
										const uint handle = fetchHandle(bitStream, fetchHandleFormat(bitStream)); 
										switch(cmd)
										{
											case 0: 	FMH = handle; 	/* set FontMap handle*/	break; 
											case 1: 	LFMH = handle; 	/* set LatinFontMap handle*/	break; 
											case 2: 	PALH = handle; 	/* set Palette handle*/	break; 
											case 3: 	LTH = handle; 	/* set LineTexture handle*/	break; 
										}
									}
									break; 
								}
								
								if(colorsChanged)
								{
									fragColor 	= vec4(PC.rgb, PC.a*OP),
									fragBkColor 	= vec4(SC.rgb, SC.a*OP); 
								}
							}else {
								switch(subCat)
								{
									case 0: //SVG path 1
									/*Opt: build a state machine from SVG PatCode stuff, so the it will require less gpu code and hopefully be faster.*/
										switch(cmd)
									{
										case 0: 	/*Z: close path*/	/*Todo: close path*/break; 
										case 1: 	/*M: move*/	pendingPathCode = PathCode_M; 	break; 
										case 2: 	/*L: line*/	pendingPathCode = PathCode_L; 	break; 
										case 3: 	/*T: smooth quadratic*/	pendingPathCode = PathCode_T1; 	break; 
									}
									break; 
									case 1: //SVG path 2
										switch(cmd)
									{
										case 0: 	/*Q: quadratic*/	pendingPathCode = PathCode_Q1; 	break; 
										case 1: 	/*S: smooth cubic*/	pendingPathCode = PathCode_S1; 	break; 
										case 2: 	/*C: cubic*/	pendingPathCode = PathCode_C1; 	break; 
										case 3: 	/*TG: tangent move*/	pendingPathCode = PathCode_TG; 	break; 
										
										/*Todo: calculate arc on GPU: 1..4x simple cubic beziers*/
										/*Todo: cubic b-spline a letrehozva a harmadolos modszerrel szerkesztett control pointokkal. */
									}
									break; 
									case 2: 
										switch(cmd)
									{
										case 0: 	/**/	break; 
										case 1: 	/**/	break; 
										case 2: 	/**/	break; 
										case 3: 	/**/	break; 
									}
									break; 
									case 3: 
										switch(cmd)
									{
										case 0: 	drawMove(bitStream); 	break; 
										case 1: 	drawTexturedRect(bitStream); 	break; 
										case 2: 	drawChars(bitStream, false); 	break; 
										case 3: 	drawChars(bitStream, /*repeat*/true); 	break; 
									}
									break; 
								}
							}
						}
						
						if(pendingPathCode>0)
						{
							switch(pendingPathCode)
							{
								case PathCode_TG: 
								case PathCode_M: case PathCode_L: 
								case PathCode_Q1: case PathCode_Q2: 
								case PathCode_C1: case PathCode_C2: case PathCode_C3: 
									{
									//Todo: set these states it less frequently!!!
									fragColor = PC; fragBkColor = SC; setFragTexHandle(0); 
									fragTexCoordZ = floatBitsToUint(LW/2); 
									
									latchP(fetchXY(bitStream, P4)); 
									shiftInPathCode(pendingPathCode); 
									pendingPathCode = PathCode_next(pendingPathCode); 
								}	break; 
								
								default: pendingPathCode = 0; 
							}
						}
						
						if(pendingChars>0)
						{
							if(EnbaleAsciiStrips)
							{
								const bool isLast = pendingChars==1; 
								drawASCII_strip(repeated ? repeatedChar : fetchBits(bitStream, 8), isLast); 
							}
							else
							{ drawASCII_rect(repeated ? repeatedChar : fetchBits(bitStream, 8)); }
							
							pendingChars--; 
						}
					} 
					
					
					void main() /*geometry shader*/
					{
						fragTexHandleAndMode = 0; 
						fragTexCoordZ = 0; //This is normally 0. Fonts and lines can temporarily change it.
						fragFloats0 = vec4(1, 2, 3, 4); 
						fragFloats1 = vec4(5, 6, 7, 8); 
						
						if(true)
						{
							BitStream GS = initBitStream(geomGSBitOfs[0]/*, geomGSBitOfs[0]+10000*/); 
							while(runningCntr>0/* && GS.totalBitsRemaining>0*//*overflow check*/)
							{ processInstruction(GS); runningCntr--; }
						}
					} 
					
					@frag: 
					
					$(ShaderBufferDeclarations)
					$(TexSizeFormat.GLSLCode)
					
					uint fragMode, fragTexHandle; 
					vec2 texCoordXY; 
					
					void initFragmentParams()
					{
						fragMode = getFragMode; 
						fragTexHandle = getFragTexHandle; 
						texCoordXY = fragTexCoordXY; 
					} 
					/*
						--------------------------------------------------------------
							Cubic bezier approx distance 2 
						--------------------------------------------------------------
							Created by NinjaKoala in 2019-07-17
							https://www.shadertoy.com/view/3lsSzS
						--------------------------------------------------------------
						
						Copyright (c) <2024> <Felix Potthast>
						Permission is hereby granted, free of charge, to any person obtaining a 
						copy of this software and associated documentation files (the "Software"), 
						to deal in the Software without restriction, including without limitation 
						the rights to use, copy, modify, merge, publish, distribute, sublicense, 
						and/or sell copies of the Software, and to permit persons to whom the
						Software is furnished to do so, subject to the following conditions:
						
						The above copyright notice and this permission notice shall be included 
						in all copies or substantial portions of the Software.
						
						THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY 
						KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE 
						WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
						PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS 
						OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR 
						OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
						OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
						SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
					*/
					
					/*
						See also:
						
						Old distance approximation (which is inferior): https://www.shadertoy.com/view/lsByRG
						Exact distance computation: https://www.shadertoy.com/view/4sKyzW
						Maximum norm distance: https://www.shadertoy.com/view/4sKyRm
						This approach applied to more complex parametric curves: https://www.shadertoy.com/view/3tsXDB
					*/
					
					const int bezier_num_iterations=3; /*def:3*/
					const int bezier_num_start_params=3; /*def:3*/
					
					const int bezier_method=0; /*valid range: [0..3]*/
					
					//factor should be positive
					//it decreases the step size when lowered.
					//Lowering the factor and increasing iterations increases the area in which
					//the iteration converges, but this is quite costly
					const float bezier_factor=1; /*def:1*/
					
					float newton_iteration(vec3 coeffs, float x)
					{
						float a2=coeffs[2]+x; 
						float a1=coeffs[1]+x*a2; 
						float f=coeffs[0]+x*a1; 
						float f1=((x+a2)*x)+a1; 
						
						return x-f/f1; 
					} 
					
					float halley_iteration(vec3 coeffs, float x)
					{
						float a2=coeffs[2]+x; 
						float a1=coeffs[1]+x*a2; 
						float f=coeffs[0]+x*a1; 
						
						float b2=a2+x; 
						float f1=a1+x*b2; 
						float f2=2.*(b2+x); 
						return x-(2.*f*f1)/(2.*f1*f1-f*f2); 
					} 
					
					float cubic_bezier_normal_iteration(int method, float t, vec2 a0, vec2 a1, vec2 a2, vec2 a3)
					{
						if(method<=1)
						{
							//horner's method
							vec2 a_2=a2+t*a3; 
							vec2 a_1=a1+t*a_2; 
							vec2 b_2=a_2+t*a3; 
							
							vec2 uv_to_p=a0+t*a_1; 
							vec2 tang=a_1+t*b_2; 
							float l_tang=dot(tang,tang); 
							
							if(method==0/*normal iteration*/)
							{ return t-bezier_factor*dot(tang,uv_to_p)/l_tang; }
							else if(method==1/*normal iteration2*/)
							{
								vec2 snd_drv=2.*(b_2+t*a3); 
								
								float fac=dot(tang,snd_drv)/(2.*l_tang); 
								float d=-dot(tang,uv_to_p); 
								float t2=d/(l_tang+fac*d); 
								return t+bezier_factor*t2; 
							}
						}
						else
						{
							vec2 tang=(3.*a3*t+2.*a2)*t+a1; 
							vec3 poly=vec3(dot(a0,tang),dot(a1,tang),dot(a2,tang))/dot(a3,tang); 
							
							if(method==2)	{ return newton_iteration(poly,t); /*equivalent to normal_iteration*/}
							else if(method==3)	{ return halley_iteration(poly,t); /*equivalent to normal_iteration2*/}
						}
						return 0; 
					} 
					
					float cubic_bezier_dis_approx(vec2 uv, vec2 p0, vec2 p1, vec2 p2, vec2 p3)
					{
						vec2 a3 = (-p0 + 3. * p1 - 3. * p2 + p3); 
						vec2 a2 = (3. * p0 - 6. * p1 + 3. * p2); 
						vec2 a1 = (-3. * p0 + 3. * p1); 
						vec2 a0 = p0 - uv; 
						
						float d0 = 1e38, t0=0.; 
						for(int i=0;i<bezier_num_start_params;i++)
						{
							float t=t0; 
							for(int j=0;j<bezier_num_iterations;j++)
							{ t=cubic_bezier_normal_iteration(bezier_method, t,a0,a1,a2,a3); }
							t=clamp(t,0.,1.); 
							vec2 uv_to_p=((a3*t+a2)*t+a1)*t+a0; 
							d0=min(d0,dot(uv_to_p,uv_to_p)); 
							
							t0+=1./float(bezier_num_start_params-1); 
						}
						
						return sqrt(d0); 
					} 
					
					/*
						Exact distance to cubic bezier curve by computing roots of the derivative(s)
						to isolate roots of a fifth degree polynomial and Halley's Method to compute them.
						Inspired by https://www.shadertoy.com/view/4sXyDr and https://www.shadertoy.com/view/ldXXWH
						See also my approximate version:
						https://www.shadertoy.com/view/lsByRG
					*/
					const float bezier_eps = .000005; 
					const int halley_iterations = 8; 
					
					//lagrange positive real root upper bound
					//see for example: https://doi.org/10.1016/j.jsc.2014.09.038
					float upper_bound_lagrange5(float a0, float a1, float a2, float a3, float a4)
					{
						vec4 coeffs1 = vec4(a0,a1,a2,a3); 
						
						vec4 neg1 = max(-coeffs1,vec4(0)); 
						float neg2 = max(-a4,0.); 
						
						const vec4 indizes1 = vec4(0,1,2,3); 
						const float indizes2 = 4.; 
						
						vec4 bounds1 = pow(neg1,1./(5.-indizes1)); 
						float bounds2 = pow(neg2,1./(5.-indizes2)); 
						
						vec2 min1_2 = min(bounds1.xz,bounds1.yw); 
						vec2 max1_2 = max(bounds1.xz,bounds1.yw); 
						
						float maxmin = max(min1_2.x,min1_2.y); 
						float minmax = min(max1_2.x,max1_2.y); 
						
						float max3 = max(max1_2.x,max1_2.y); 
						
						float max_max = max(max3,bounds2); 
						float max_max2 = max(min(max3,bounds2),max(minmax,maxmin)); 
						
						return max_max + max_max2; 
					} 
					
					//lagrange upper bound applied to f(-x) to get lower bound
					float lower_bound_lagrange5(float a0, float a1, float a2, float a3, float a4)
					{
						vec4 coeffs1 = vec4(-a0,a1,-a2,a3); 
						
						vec4 neg1 = max(-coeffs1,vec4(0)); 
						float neg2 = max(-a4,0.); 
						
						const vec4 indizes1 = vec4(0,1,2,3); 
						const float indizes2 = 4.; 
						
						vec4 bounds1 = pow(neg1,1./(5.-indizes1)); 
						float bounds2 = pow(neg2,1./(5.-indizes2)); 
						
						vec2 min1_2 = min(bounds1.xz,bounds1.yw); 
						vec2 max1_2 = max(bounds1.xz,bounds1.yw); 
						
						float maxmin = max(min1_2.x,min1_2.y); 
						float minmax = min(max1_2.x,max1_2.y); 
						
						float max3 = max(max1_2.x,max1_2.y); 
						
						float max_max = max(max3,bounds2); 
						float max_max2 = max(min(max3,bounds2),max(minmax,maxmin)); 
						
						return -max_max - max_max2; 
					} 
					
					vec2 parametric_cub_bezier(float t, vec2 p0, vec2 p1, vec2 p2, vec2 p3)
					{
						vec2 a0 = (-p0 + 3. * p1 - 3. * p2 + p3); 
						vec2 a1 = (3. * p0  -6. * p1 + 3. * p2); 
						vec2 a2 = (-3. * p0 + 3. * p1); 
						vec2 a3 = p0; 
						
						return (((a0 * t) + a1) * t + a2) * t + a3; 
					} 
					
					void sort_roots3(inout vec3 roots)
					{
						vec3 tmp; 
						
						tmp[0] = min(roots[0],min(roots[1],roots[2])); 
						tmp[1] = max(roots[0],min(roots[1],roots[2])); 
						tmp[2] = max(roots[0],max(roots[1],roots[2])); 
						
						roots=tmp; 
					} 
					
					void sort_roots4(inout vec4 roots)
					{
						vec4 tmp; 
						
						vec2 min1_2 = min(roots.xz,roots.yw); 
						vec2 max1_2 = max(roots.xz,roots.yw); 
						
						float maxmin = max(min1_2.x,min1_2.y); 
						float minmax = min(max1_2.x,max1_2.y); 
						
						tmp[0] = min(min1_2.x,min1_2.y); 
						tmp[1] = min(maxmin,minmax); 
						tmp[2] = max(minmax,maxmin); 
						tmp[3] = max(max1_2.x,max1_2.y); 
						
						roots = tmp; 
					} 
					
					float eval_poly5(float a0, float a1, float a2, float a3, float a4, float x)
					{
						float f = ((((x + a4) * x + a3) * x + a2) * x + a1) * x + a0; 
						return f; 
					} 
					
					//halley's method
					//basically a variant of newton raphson which converges quicker and has bigger basins of convergence
					//see http://mathworld.wolfram.com/HalleysMethod.html
					//or https://en.wikipedia.org/wiki/Halley%27s_method
					float halley_iteration5(float a0, float a1, float a2, float a3, float a4, float x)
					{
						float f = ((((x + a4) * x + a3) * x + a2) * x + a1) * x + a0; 
						float f1 = (((5. * x + 4. * a4) * x + 3. * a3) * x + 2. * a2) * x + a1; 
						float f2 = ((20. * x + 12. * a4) * x + 6. * a3) * x + 2. * a2; 
						
						return x - (2. * f * f1) / (2. * f1 * f1 - f * f2); 
					} 
					
					float halley_iteration4(vec4 coeffs, float x)
					{
						float f = (((x + coeffs[3]) * x + coeffs[2]) * x + coeffs[1]) * x + coeffs[0]; 
						float f1 = ((4. * x + 3. * coeffs[3]) * x + 2. * coeffs[2]) * x + coeffs[1]; 
						float f2 = (12. * x + 6. * coeffs[3]) * x + 2. * coeffs[2]; 
						
						return x - (2. * f * f1) / (2. * f1 * f1 - f * f2); 
					} 
					
					// Modified from http://tog.acm.org/resources/GraphicsGems/gems/Roots3And4.c
					// Credits to Doublefresh for hinting there
					int solve_quadric(vec2 coeffs, inout vec2 roots)
					{
						// normal form: x^2 + px + q = 0
						float p = coeffs[1] / 2.; 
						float q = coeffs[0]; 
						
						float D = p * p - q; 
						
						if(D < 0.) { return 0; }
						else if(D > 0.) {
							roots[0] = -sqrt(D) - p; 
							roots[1] = sqrt(D) - p; 
							
							return 2; 
						}
					} 
					
					//From Trisomie21
					//But instead of his cancellation fix i'm using a newton iteration
					int solve_cubic(vec3 coeffs, inout vec3 r)
					{
						
						float a = coeffs[2]; 
						float b = coeffs[1]; 
						float c = coeffs[0]; 
						
						float p = b - a*a / 3.0; 
						float q = a * (2.0*a*a - 9.0*b) / 27.0 + c; 
						float p3 = p*p*p; 
						float d = q*q + 4.0*p3 / 27.0; 
						float offset = -a / 3.0; 
						if(d >= 0.0) {
							 // Single solution
							float z = sqrt(d); 
							float u = (-q + z) / 2.0; 
							float v = (-q - z) / 2.0; 
							u = sign(u)*pow(abs(u),1.0/3.0); 
							v = sign(v)*pow(abs(v),1.0/3.0); 
							r[0] = offset + u + v; 	
									
							//Single newton iteration to account for cancellation
							float f = ((r[0] + a) * r[0] + b) * r[0] + c; 
							float f1 = (3. * r[0] + 2. * a) * r[0] + b; 
									
							r[0] -= f / f1; 
									
							return 1; 
						}
						float u = sqrt(-p / 3.0); 
						float v = acos(-sqrt( -27.0 / p3) * q / 2.0) / 3.0; 
						float m = cos(v), n = sin(v)*1.732050808; 
						
						//Single newton iteration to account for cancellation
						//(once for every root)
						r[0]	= offset + u * (m + m); 
						r[1] = offset - u * (n + m); 
						r[2] = offset + u * (n - m); 
						
						vec3 f = ((r + a) * r + b) * r + c; 
						vec3 f1 = (3. * r + 2. * a) * r + b; 
						
						r -= f / f1; 
						
						return 3; 
					} 
					
					// Modified from http://tog.acm.org/resources/GraphicsGems/gems/Roots3And4.c
					// Credits to Doublefresh for hinting there
					int solve_quartic(vec4 coeffs, inout vec4 s)
					{
						float a = coeffs[3]; 
						float b = coeffs[2]; 
						float c = coeffs[1]; 
						float d = coeffs[0]; 
						
						/*
							  substitute x = y - A/4 to eliminate cubic term:
										x^4 + px^2 + qx + r = 0 
						*/
						
						float sq_a = a * a; 
						float p = - 3./8. * sq_a + b; 
						float q = 1./8. * sq_a * a - 1./2. * a * b + c; 
						float r = - 3./256.*sq_a*sq_a + 1./16.*sq_a*b - 1./4.*a*c + d; 
						
						int num; 
						
						/* doesn't seem to happen for me */
						//if(abs(r)<eps){
						//	/* no absolute term: y(y^3 + py + q) = 0 */
						
						//	vec3 cubic_coeffs;
						
						//	cubic_coeffs[0] = q;
						//	cubic_coeffs[1] = p;
						//	cubic_coeffs[2] = 0.;
						
						//	num = solve_cubic(cubic_coeffs, s.xyz);
						
						//	s[num] = 0.;
						//	num++;
						//}
						{
							/* solve the resolvent cubic ... */
							
							vec3 cubic_coeffs; 
							
							cubic_coeffs[0] = 1.0/2. * r * p - 1.0/8. * q * q; 
							cubic_coeffs[1] = - r; 
							cubic_coeffs[2] = - 1.0/2. * p; 
							
							solve_cubic(cubic_coeffs, s.xyz); 
							
							/* ... and take the one real solution ... */
							
							float z = s[0]; 
							
							/* ... to build two quadric equations */
							
							float u = z * z - r; 
							float v = 2. * z - p; 
							
							if(u > -bezier_eps) { u = sqrt(abs(u)); }
							else	{ return 0; }
							
							if(v > -bezier_eps) { v = sqrt(abs(v)); }
							else	{ return 0; }
							
							vec2 quad_coeffs; 
							
							quad_coeffs[0] = z - u; 
							quad_coeffs[1] = q < 0. ? -v : v; 
							
							num = solve_quadric(quad_coeffs, s.xy); 
							
							quad_coeffs[0]= z + u; 
							quad_coeffs[1] = q < 0. ? v : -v; 
							
							vec2 tmp=vec2(1e38); 
							int old_num=num; 
							
							num += solve_quadric(quad_coeffs, tmp); 
							if(old_num!=num) {
								if(old_num == 0) {
									 s[0] = tmp[0]; 
									 s[1] = tmp[1]; 
								}
								else {
									//old_num == 2
									s[2] = tmp[0]; 
									s[3] = tmp[1]; 
								}
							}
						}
						
						/* resubstitute */
						
						float sub = 1./4. * a; 
						
						/* single halley iteration to fix cancellation */
						for(int i=0;i<4;i+=2) {
							if(i < num) {
								s[i] -= sub; 
								s[i] = halley_iteration4(coeffs,s[i]); 
								
								s[i+1] -= sub; 
								s[i+1] = halley_iteration4(coeffs,s[i+1]); 
							}
						}
						
						return num; 
					} 
					float cubic_bezier_dis_exact(vec2 uv, vec2 p0, vec2 p1, vec2 p2, vec2 p3)
					{
						//switch points when near to end point to minimize numerical error
						//only needed when control point(s) very far away
						if(false)
						{
							vec2 mid_curve = parametric_cub_bezier(.5,p0,p1,p2,p3); 
							vec2 mid_points = (p0 + p3)/2.; 
							
							vec2 tang = mid_curve-mid_points; 
							vec2 nor = vec2(tang.y,-tang.x); 
							
							if(sign(dot(nor,uv-mid_curve)) != sign(dot(nor,p0-mid_curve)))
							{
								vec2 tmp = p0; 
								p0 = p3; 
								p3 = tmp; 
								
								tmp = p2; 
								p2 = p1; 
								p1 = tmp; 
							}
						}
						vec2 a3 = (-p0 + 3. * p1 - 3. * p2 + p3); 
						vec2 a2 = (3. * p0 - 6. * p1 + 3. * p2); 
						vec2 a1 = (-3. * p0 + 3. * p1); 
						vec2 a0 = p0 - uv; 
						
						//compute polynomial describing distance to current pixel dependent on a parameter t
						float bc6 = dot(a3,a3); 
						float bc5 = 2.*dot(a3,a2); 
						float bc4 = dot(a2,a2) + 2.*dot(a1,a3); 
						float bc3 = 2.*(dot(a1,a2) + dot(a0,a3)); 
						float bc2 = dot(a1,a1) + 2.*dot(a0,a2); 
						float bc1 = 2.*dot(a0,a1); 
						float bc0 = dot(a0,a0); 
						
						bc5 /= bc6; 
						bc4 /= bc6; 
						bc3 /= bc6; 
						bc2 /= bc6; 
						bc1 /= bc6; 
						bc0 /= bc6; 
						
						//compute derivatives of this polynomial
						
						float b0 = bc1 / 6.; 
						float b1 = 2. * bc2 / 6.; 
						float b2 = 3. * bc3 / 6.; 
						float b3 = 4. * bc4 / 6.; 
						float b4 = 5. * bc5 / 6.; 
						
						vec4 c1 = vec4(b1,2.*b2,3.*b3,4.*b4)/5.; 
						vec3 c2 = vec3(c1[1],2.*c1[2],3.*c1[3])/4.; 
						vec2 c3 = vec2(c2[1],2.*c2[2])/3.; 
						float c4 = c3[1]/2.; 
						
						vec4 roots_drv = vec4(1e38); 
						
						int num_roots_drv = solve_quartic(c1,roots_drv); 
						sort_roots4(roots_drv); 
						
						float ub = upper_bound_lagrange5(b0,b1,b2,b3,b4); 
						float lb = lower_bound_lagrange5(b0,b1,b2,b3,b4); 
						
						vec3 a = vec3(1e38); 
						vec3 b = vec3(1e38); 
						
						vec3 roots = vec3(1e38); 
						
						int num_roots = 0; 
						
						//compute root isolating intervals by roots of derivative and outer root bounds
						//only roots going form - to + considered, because only those result in a minimum
						if(num_roots_drv==4)
						{
							if(eval_poly5(b0,b1,b2,b3,b4,roots_drv[0]) > 0.)
							{
								a[0]=lb; 
								b[0]=roots_drv[0]; 
								num_roots=1; 
							}
							
							if(
								sign(eval_poly5(b0,b1,b2,b3,b4,roots_drv[1])) != 
								sign(eval_poly5(b0,b1,b2,b3,b4,roots_drv[2]))
							)
							{
								if(num_roots == 0)
								{
									a[0]=roots_drv[1]; 
									b[0]=roots_drv[2]; 
									num_roots=1; 
								}
								else
								{
									a[1]=roots_drv[1]; 
									b[1]=roots_drv[2]; 
									num_roots=2; 
								}
							}
							
							if(eval_poly5(b0,b1,b2,b3,b4,roots_drv[3]) < 0.)
							{
								if(num_roots == 0)
								{
									a[0]=roots_drv[3]; 
									b[0]=ub; 
									num_roots=1; 
								}
								else if(num_roots == 1)
								{
									a[1]=roots_drv[3]; 
									b[1]=ub; 
									num_roots=2; 
								}
								else
								{
									a[2]=roots_drv[3]; 
									b[2]=ub; 
									num_roots=3; 
								}
							}
						}else {
							if(num_roots_drv==2)
							{
								if(eval_poly5(b0,b1,b2,b3,b4,roots_drv[0]) < 0.)
								{
									num_roots=1; 
									a[0]=roots_drv[1]; 
									b[0]=ub; 
								}
								else if(eval_poly5(b0,b1,b2,b3,b4,roots_drv[1]) > 0.)
								{
									num_roots=1; 
									a[0]=lb; 
									b[0]=roots_drv[0]; 
								}
								else
								{
									num_roots=2; 
									
									a[0]=lb; 
									b[0]=roots_drv[0]; 
									
									a[1]=roots_drv[1]; 
									b[1]=ub; 
								}
							}
							else {
								//num_roots_drv==0
								vec3 roots_snd_drv=vec3(1e38); 
								int num_roots_snd_drv=solve_cubic(c2,roots_snd_drv); 
								
								vec2 roots_trd_drv=vec2(1e38); 
								int num_roots_trd_drv=solve_quadric(c3,roots_trd_drv); 
								num_roots=1; 
								
								a[0]=lb; 
								b[0]=ub; 
							}
							
							//further subdivide intervals to guarantee convergence of halley's method
							//by using roots of further derivatives
							vec3 roots_snd_drv=vec3(1e38); 
							int num_roots_snd_drv=solve_cubic(c2,roots_snd_drv); 
							sort_roots3(roots_snd_drv); 
							
							int num_roots_trd_drv=0; 
							vec2 roots_trd_drv=vec2(1e38); 
							
							if(num_roots_snd_drv!=3) { num_roots_trd_drv=solve_quadric(c3,roots_trd_drv); }
							
							for(int i=0;i<3;i++)
							{
								if(i < num_roots)
								{
									for(int j=0;j<3;j+=2)
									{
										if(j < num_roots_snd_drv)
										{
											if(a[i] < roots_snd_drv[j] && b[i] > roots_snd_drv[j])
											{
												if(eval_poly5(b0,b1,b2,b3,b4,roots_snd_drv[j]) > 0.)
												{ b[i]=roots_snd_drv[j]; }
												else { a[i]=roots_snd_drv[j]; }
											}
										}
									}
									for(int j=0;j<2;j++)
									{
										if(j < num_roots_trd_drv)
										{
											if(a[i] < roots_trd_drv[j] && b[i] > roots_trd_drv[j])
											{
												if(eval_poly5(b0,b1,b2,b3,b4,roots_trd_drv[j]) > 0.)
												{ b[i]=roots_trd_drv[j]; }
												else { a[i]=roots_trd_drv[j]; }
											}
										}
									}
								}
							}
						}
						
						float d0 = 1e38; 
						
						//compute roots with halley's method
						
						for(int i=0;i<3;i++)
						{
							if(i < num_roots)
							{
								roots[i] = .5 * (a[i] + b[i]); 
								
								for(int j=0;j<halley_iterations;j++) { roots[i] = halley_iteration5(b0,b1,b2,b3,b4,roots[i]); }
								
								//compute squared distance to nearest point on curve
								roots[i] =	clamp(roots[i],0.,1.); 
								vec2 to_curve = uv - parametric_cub_bezier(roots[i],p0,p1,p2,p3); 
								d0 = min(d0,dot(to_curve,to_curve)); 
							}
						}
						
						return sqrt(d0); 
					} 
					
					//Quadratic Bezier - distance 2D 
					
					// The MIT License
					// Copyright © 2018 Inigo Quilez
					/*
						 Permission is hereby granted, free of charge, to any person obtaining a copy of 
						this software and associated documentation files (the "Software"), to deal in the 
						Software without restriction, including without limitation the rights to use, copy, 
						modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, 
						and to permit persons to whom the Software is furnished to do so, subject to 
						the following conditions: The above copyright notice and this permission notice 
						shall be included in all copies or substantial portions of the Software. 
						THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
						EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
						MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
						IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY 
						CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
						TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
						SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
					*/
					
					
					// Distance to a quadratic bezier segment
					
					// SDF(x) = argmin{t} |x-b(t)|²  
					//           
					// where b(t) is the curve. So we have
					//
					// |x-b(t)|² = |x|² - 2x·b(t) + |b(t)|²
					//
					// ∂|x-b(t)|²/∂t = 2(b(t)-x)·b'(t) = 0
					//
					// (b(t)-x)·b'(t) = 0
					//
					// But b(t) is degree 2, so b'(t) is degree 1, so (b(t)-x)·b'(t)=0 is a cubic.
					// I solved the cubic using the trigonometric solution of the depressed as 
					// shown here: https://en.wikipedia.org/wiki/Cubic_equation
					
					
					// List of some other 2D distances: https://www.shadertoy.com/playlist/MXdSRf
					//
					// and iquilezles.org/articles/distfunctions2d
					
					
					
					float dot2( vec2 v ) { return dot(v,v); } 
					float cro( vec2 a, vec2 b ) { return a.x*b.y-a.y*b.x; } 
					float cos_acos_3( float x )
					{
						x=sqrt(0.5+0.5*x); 
						return x*(x*(x*(x*-0.008972+0.039071)-0.107074)+0.576975)+0.5; 
					} 
					// https://www.shadertoy.com/view/WltSD7
					
					
					// This method provides just an approximation, and is only usable in
					// the very close neighborhood of the curve. Taken and adapted from
					// http://research.microsoft.com/en-us/um/people/hoppe/ravg.pdf
					float quadratic_bezier_dis_approx(
						 vec2 p, vec2 v0, vec2 v1, vec2 v2
						/*out vec2 outQ */
					)
					{
						vec2 i = v0 - v2; 
						vec2 j = v2 - v1; 
						vec2 k = v1 - v0; 
						vec2 w = j-k; 
						
						v0-= p; v1-= p; v2-= p; 
						
						float x = cro(v0, v2); 
						float y = cro(v1, v0); 
						float z = cro(v2, v1); 
						
						vec2 s = 2.0*(y*j+z*k)-x*i; 
						
						float r =  (y*z-x*x*0.25)/dot2(s); 
						float t = clamp( (0.5*x+y+r*dot(s,w))/(x+y+z),0.0,1.0); 
						
						vec2 d = v0+t*(k+k+t*w); 
						//outQ = d + p; 
						return length(d); 
					} 
					
					// signed distance to a quadratic bezier
					float quadratic_bezier_dis_exact(
						 in vec2 pos, in vec2 A, in vec2 B, in vec2 C
						/*out vec2 outQ*/
					)
					{
						vec2 a = B - A; 
						vec2 b = A - 2.0*B + C; 
						vec2 c = a * 2.0; 
						vec2 d = A - pos; 
						
						// cubic to be solved (kx*=3 and ky*=3)
						float kk = 1.0/dot(b,b); 
						float kx = kk * dot(a,b); 
						float ky = kk * (2.0*dot(a,a)+dot(d,b))/3.0; 
						float kz = kk * dot(d,a); 
						
						float res = 0.0; 
						float sgn = 0.0; 
						
						float p = ky - kx*kx; 
						float q = kx*(2.0*kx*kx - 3.0*ky) + kz; 
						float p3 = p*p*p; 
						float q2 = q*q; 
						float h = q2 + 4.0*p3; 
						
						if(h>=0.0)
						{
							// 1 root
							h = sqrt(h); 
							
							h = (q<0.0) ? h : -h; // copysign()
							float x = (h-q)/2.0; 
							float v = sign(x)*pow(abs(x),1.0/3.0); 
							float t = v - p/v; 
							
							// from NinjaKoala - single newton iteration to account for cancellation
							t -= (t*(t*t+3.0*p)+q)/(3.0*t*t+3.0*p); 
							
							t = clamp( t-kx, 0.0, 1.0 ); 
							vec2  w = d+(c+b*t)*t; 
							//outQ = w + pos; 
							res = dot2(w); 
							sgn = cro(c+2.0*b*t,w); 
						}
						else
						{
							// 3 roots
							float z = sqrt(-p); 
							float m = cos_acos_3(q/(p*z*2.0)); 
							float n = sqrt(1.0-m*m); 
							n *= sqrt(3.0); 
							vec3	t = clamp( vec3(m+m,-n-m,n-m)*z-kx, 0.0, 1.0 ); 
							vec2	qx=d+(c+b*t.x)*t.x; float dx=dot2(qx), sx=cro(a+b*t.x,qx); 
							vec2	qy=d+(c+b*t.y)*t.y; float dy=dot2(qy), sy=cro(a+b*t.y,qy); 
							if(dx<dy)	{ res=dx; sgn=sx; /*outQ=qx+pos; */}
							else	{ res=dy; sgn=sy; /*outQ=qy+pos; */}
						}
						
						return sqrt( res )/*sign(sgn)*/; 
					} 
					
					
					vec4 readSample(in uint texIdx, in vec3 v, in bool prescaleXY, bool prescaleZ)
					{
						if(texIdx==0) return vec4(1,1,1,1)/*no texture means full white*/; 
						
						//fetch info dword 0
						const uint textDwIdx = texIdx * $(TexInfo.sizeof/4); 
						const uint info_0 = IB[textDwIdx+0]; 
						
						//handle 'error' and 'loading' flags
						if(getBits(info_0, $(TexInfoBitOfs), 2)!=0)
						{
							if(getBit(info_0, $(TexInfoBitOfs)))	return ErrorColor; 
							else	return LoadingColor; 
						}
						
						//decode dimensions, size
						const uint dim = getBits(info_0, $(TexDimBitOfs), $(TexDimBits)); 
						const uint info_1 = IB[textDwIdx+1]; 
						const uint _rawSize0 = getBits(info_0, 16, 16); 
						const uint _rawSize12 = info_1; 
						const ivec3 size = decodeDimSize(dim, _rawSize0, _rawSize12); 
						if(size.x==0 || size.y==0 || size.z==0) return ErrorColor; 
						
						
						//Prescale tex coordinates by size
						vec3 pv = v; 
						if(prescaleXY) pv.xy *= size.xy; 
						if(prescaleZ) pv.z *= size.z; 
						
						//Clamp tex coordinates. Assume non-empty image.
						const ivec3 iv = ivec3(pv); 
						const ivec3 clamped = max(min(iv, size-1), 0); 
						
						//if(iv!=clamped) return vec4(0,0,0,0)/*out of texture means transparent*/; 
						//transparent is not good! triangle edges can go out of texture bounds
						
						//Calculate flat index
						const uint i = calcFlatIndex(clamped, dim, size); 
						
						//Get chunkIdx from info rec
						const uint chunkIdx = IB[textDwIdx+2]; 
						const uint dwIdx = chunkIdx * $(HeapGranularity/4); 
						
						//decode format (chn, bpp, alt)
						const uint chn = getBits(info_0, $(TexFormatBitOfs), $(TexChnBits)); 
						const uint bpp = getBits(info_0, $(TexFormatBitOfs + TexChnBits), $(TexBppBits)); 
						const bool alt = getBit(info_0, $(TexFormatBitOfs + TexChnBits + TexBppBits)); 
						
						//Phase 1: Calculate minimal read range
						uint startIdx; 
						uint numDWords; 
						uint shift; // Only used for 24bpp case
						bool aligned; // Only used for 48bpp case
						
						switch(bpp)
						{
							case TexBpp_1: 	{ startIdx = dwIdx + i/32; numDWords = 1; }	break; 
							case TexBpp_2: 	{ startIdx = dwIdx + i/16; numDWords = 1; }	break; 
							case TexBpp_4: 	{ startIdx = dwIdx + i/8; numDWords = 1; }	break; 
							case TexBpp_8: 	{ startIdx = dwIdx + i/4; numDWords = 1; }	break; 
							case TexBpp_16: 	{ startIdx = dwIdx + i/2; numDWords = 1; }	break; 
							case TexBpp_24: 	{
								startIdx = dwIdx + (i*3)/4; 
								shift = (i*24)&31; /*AI mistake: int(i%4)*6*/
								numDWords = (shift <= 8) ? 1 : 2; 
							}	break; 
							case TexBpp_32: 	{ startIdx = dwIdx + i; numDWords = 1; }	break; 
							case TexBpp_48: 	{
								startIdx = dwIdx + i*3/2; 
								aligned = (i%2 == 0); numDWords = 2; 
							}	break; 
							case TexBpp_64: 	{ startIdx = dwIdx + i*2; numDWords = 2; }	break; 
							case TexBpp_96: 	{ startIdx = dwIdx + i*3; numDWords = 3; }	break; 
							case TexBpp_128: 	{ startIdx = dwIdx + i*4; numDWords = 4; }	break; 
							default: return ErrorColor; 
						}
						
						//Phase 2: Perform minimal TB[] reads
						uvec4 tmp; // Max 4 dwords needed for 128bpp case
						tmp.x = TB[startIdx + 0]; 
						if(numDWords>1) tmp.y = TB[startIdx + 1]; 
						if(numDWords>2) tmp.z = TB[startIdx + 2]; 
						if(numDWords>3) tmp.w = TB[startIdx + 3]; 
						
						vec4 res; 
						
						switch(chn)
						{
							case TexChn_1: 
							switch(bpp)
							{
								case TexBpp_1: 	{ res = vec4(vec3(getBits(tmp.x, int(i%32)* 1,  1)         ), 1); }	break; 
								case TexBpp_2: 	{ res = vec4(vec3(getBits(tmp.x, int(i%16)* 2,  2) /     3.0), 1); }	break; 
								case TexBpp_4: 	{ res = vec4(vec3(getBits(tmp.x, int(i% 8)* 4,  4) /    15.0), 1); }	break; 
								case TexBpp_8: 	{ res = vec4(vec3(getBits(tmp.x, int(i% 4)* 8,  8) /   255.0), 1); }	break; 
								case TexBpp_16: 	{ res = vec4(vec3(getBits(tmp.x, int(i% 2)*16, 16) / 65535.0), 1); }	break; 
								case TexBpp_32: 	{ res = vec4(vec3(uintBitsToFloat(tmp.x)      ), 1); }	break; 
								default: return ErrorColor; 
							}
							if(alt) {
								/*white alpha (used by monochrome fonts)*/
								res.a = res.r; res.rgb = vec3(1); 
							}break; 
							
							case TexChn_2: 
							switch(bpp)
							{
								case TexBpp_16: 	{ res = unpackUnorm4x8(tmp.x).xxxy; }	break; 
								case TexBpp_32: 	{ res = unpackUnorm2x16(tmp.x).xxxy; }	break; 
								case TexBpp_64: 	{
									res = vec4(
										vec3(uintBitsToFloat(tmp.x)),
										      uintBitsToFloat(tmp.y)
									); 
								}	break; 
								default: return ErrorColor; 
							}
							if(alt) {/*no alt mode defined for 2ch,*/}break; 
							case TexChn_3: 
							switch(bpp)
							{
								case TexBpp_16: 	{
									res = vec4(
										getBits(tmp.x,  0, 5) / 31.0,
										getBits(tmp.x,  5, 6) / 63.0,
										getBits(tmp.x, 11, 5) / 31.0, 1
									); 
								}	break; 
								case TexBpp_24: 	{
									if(shift <= 8)	{ res = vec4(unpackUnorm4x8(getBits(tmp.x, int(shift), 24)).xyz, 1); }
									else	{
										res = vec4(
											unpackUnorm4x8(
												(tmp.x >> shift) | 
												(tmp.y << (32-shift))
											).xyz, 1
										); 
									}
								}	break; 
								case TexBpp_48: 	{
									if(aligned)	{
										res = vec4(
											unpackUnorm2x16(tmp.x).xy, 
											unpackUnorm2x16(tmp.y).x, 1
										); 
									}
									else	{
										res = vec4(
											unpackUnorm2x16(tmp.x>>16).x, 
											unpackUnorm2x16(tmp.y).xy, 1
										); 
									}
								}	break; 
								case TexBpp_96: 	{ res = vec4(uintBitsToFloat(tmp.xyz), 1); }	break; 
								default: return ErrorColor; 
							}
							if(alt) {/*swap red-blue*/res.rgba = res.bgra; }break; 
							
							case TexChn_4: 
							switch(bpp)
							{
								case TexBpp_16: 	{
									res = vec4(
										getBits(tmp.x,  0, 5) / 31.0,
										getBits(tmp.x,  5, 5) / 31.0,
										getBits(tmp.x, 10, 5) / 31.0,
										getBits(tmp.x, 15, 1)
									); 
								}	break; 
								case TexBpp_32: 	{ res = unpackUnorm4x8(tmp.x); }	break; 
								case TexBpp_64: 	{
									res = vec4(
										unpackUnorm2x16(tmp.x),
										unpackUnorm2x16(tmp.y)
									); 
								}	break; 
								case TexBpp_128: 	{ res = uintBitsToFloat(tmp.xyzw); }	break; 
								default: return ErrorColor; 
							}
							if(alt) {/*swap red-blue*/res.rgba = res.bgra; }break; 
							
							default: return ErrorColor; 
						}
						return res; 
					} 
					
					vec4 readFilteredSample(bool enableMultisampling)
					{
						if(enableMultisampling)
						{
							const vec2[6] rooks6_offsets = 
								{
								vec2(-0.417, 0.250), vec2(-0.250, -0.417), vec2(-0.083, -0.083),
								vec2(0.083, 0.083), vec2(0.250, 0.417), vec2(0.417, -0.250)
							}; 
							
							vec4 sum = vec4(0); 
							const vec2 texCoordDx = dFdx(fragTexCoordXY); 
							const vec2 texCoordDy = dFdy(fragTexCoordXY); 
							for(int i=0; i<6; i++)
							{
								vec2 rooks = rooks6_offsets[i]; 
								vec2 tc = texCoordXY + 	rooks.x * texCoordDx + 
									rooks.y * texCoordDy; 
								vec4 smp = readSample(fragTexHandle, vec3(tc, fragTexCoordZ), true, false); 
								sum += smp; 
							}
							return sum/6; 
						}
						else
						{ return readSample(fragTexHandle, vec3(texCoordXY, fragTexCoordZ), true, false); }
					} 
					
					void main()
					{
						initFragmentParams(); 
						
						if(fragMode==FragMode_glyphStrip)
						{
							//textCoord.x is interpolated, so the integer part must be removed
							texCoordXY.x = fract(texCoordXY.x); 
						}
						
						const vec4 ndcPos = vec4(
							2*(gl_FragCoord.xy-UB.viewport.xy)/(UB.viewport.zw)-1,
							gl_FragCoord.z, 1
						); 
						const vec4 clipPos = UB.inv_mvp * ndcPos; 
						const vec3 objPos = clipPos.xyz / clipPos.w; 
						
						if((fragMode==FragMode_cubicBezier))
						{
							float dst = cubic_bezier_dis_approx(objPos.xy, fragFloats0.xy, fragFloats0.zw, fragFloats1.xy, fragFloats1.zw); 
							float t = fract(texCoordXY.x); 
							float r = uintBitsToFloat(fragTexCoordZ); 
							if(dst>r) discard; 
						}
						
						const vec4 filteredColor = readFilteredSample(true); 
						vec4 resultColor = mix(fragBkColor, vec4(filteredColor.rgb, 1)*fragColor, filteredColor.a); 
						
						outColor = resultColor; 
					} 
				})); 
				shaderModules = new VulkanGraphicsShaderModules(device, shaderBinary); 
			}
		} 
	}
	
} 