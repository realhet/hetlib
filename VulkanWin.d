module vulkanwin; 

public import het.win, het.bitmap, het.vulkan; 

import core.stdc.string : memset; 

enum bugFix_LastTwoGeometryShaderStreamsMissing = (常!(bool)(1))
/+
	Todo: It happens with the Windows default driver.
	Try this with new drivers! (official and radeon-ID)
+/; 

/+
	+This variant is sinchronizes put and fetch to itself 
	and put() can be called in a destructor.
+/
class SafeQueue_nogc(T)
{
	private
	{
		static struct Node 
		{ T data; uint next; } 
		
		Node* buffer; 
		uint bufferSize; 
		uint head, tail; 
		uint freeListHead = uint.max; // Using uint.max as null indicator
		
		import core.stdc.stdlib : malloc, free; 
	} 
	
	this()
	{
		synchronized(this) { asm { nop; } } 
		/+
			It is priming the synchronization object,
			so later put() can be called from a destructor
			without freezing.
		+/
		
		// Start with capacity for 16 nodes
		bufferSize = 16; 
		buffer = cast(Node*)malloc(Node.sizeof * bufferSize); 
		
		// Initialize all nodes as free
		for(uint i = 0; i < bufferSize; ++i)
		{ buffer[i].next = i + 1; }
		buffer[bufferSize-1].next = uint.max; 
		freeListHead = 0; 
		
		// Allocate first node for dummy head
		head = tail = allocNode(); 
		buffer[head].next = uint.max; 
	} 
	
	~this()
	{
		if(buffer)
		{ free(buffer); buffer = null; }
	} 
	
	private uint allocNode() @nogc
	{
		if(freeListHead == uint.max)
		{
			// Double the buffer size
			auto newSize = bufferSize * 2; 
			auto newBuffer = cast(Node*)malloc(Node.sizeof * newSize); 
			
			// Copy old data
			memcpy(newBuffer, buffer, Node.sizeof * bufferSize); 
			
			// Initialize new nodes
			for(uint i = bufferSize; i < newSize; ++i)
			{ newBuffer[i].next = i + 1; }
			newBuffer[newSize-1].next = uint.max; 
			freeListHead = bufferSize; 
			
			// Replace buffer
			free(buffer); 
			buffer = newBuffer; 
			bufferSize = newSize; 
		}
		
		uint nodeIdx = freeListHead; 
		freeListHead = buffer[nodeIdx].next; 
		return nodeIdx; 
	} 
	
	private void freeNode(uint idx)
	{
		buffer[idx].next = freeListHead; 
		freeListHead = idx; 
	} 
	
	void put(T data) @nogc
	{
		synchronized(this)
		{
			auto nodeIdx = allocNode(); 
			buffer[nodeIdx].data = data; 
			buffer[nodeIdx].next = uint.max; 
			
			buffer[tail].next = nodeIdx; 
			tail = nodeIdx; 
		} 
	} 
	
	int opApply(int delegate(T) fun)
	{
		synchronized(this)
		{
			while(1)
			{
				auto nextHead = buffer[head].next; 
				if(nextHead != uint.max)
				{
					T res = buffer[nextHead].data; 
					freeNode(head); // Free old dummy head
					head = nextHead; 
					
					if(fun(res)) return 1; 
				}
				else break; 
			}
		} 
		return 0; 
	} 
	
	
	string stats() const
	=> i"bufSize:$(bufferSize) head:$(head) tail:$(tail) freeHead:$(freeListHead)".text; 
} 

alias MMQueue_nogc(T) = SafeQueue_nogc!T; 
/+
	Code: (表([
		[q{/+Note: Limits/Cards+/},q{/+Note: MAX+/},q{/+Note: R9 Fury X+/},q{/+Note: R9 280+/},q{/+Note: GTX 1060+/},q{/+Note: RX 580+/},q{/+Note: RTX 5090+/},q{/+Note: RX 9070+/}],
		[q{maxPushConstantsSize},q{128},q{256},q{128},q{256},q{256},q{256},q{256}],
		[q{maxVertexInputAttributes},q{32},q{32},q{64},q{32},q{32},q{32},q{64}],
		[q{maxGeometryInputComponents},q{64},q{64},q{128},q{128},q{64},q{128},q{128}],
		[q{maxGeometryOutputComponents},q{128},q{128},q{128},q{128},q{128},q{128},q{128}],
		[q{maxGeometryOutputVertices},q{256},q{1024},q{1024},q{1024},q{256},q{1024},q{256}],
		[q{maxGeometryTotalOutputComponents},q{1024},q{16384},q{16384},q{1024},q{1024},q{1024},q{1024}],
		[q{maxGeometryShaderInvocations},q{32},q{127},q{127},q{32},q{32},q{32},q{32}],
		[q{maxFragmentInputComponents},q{128},q{128},q{128},q{128},q{128},q{128},q{128}],
	]))
+/

version(/+$DIDE_REGION Geometry Stream Processor+/all)
{
	struct Bits(T)
	{
		T data; 
		size_t bitCnt; 
		
		auto opBinary(string op : "~", B)(B other) const
		{
			static if(is(B==Bits!T2, T2))
			return Bits!T(data | (other.data<<bitCnt), bitCnt+other.bitCnt); 
			else
			return this ~ bits(other); 
		} 
	} 
	
	auto bits(T)(T data, size_t bitCnt)
	=> Bits!T(data, bitCnt); 
	
	auto bits(T)(T a)
	{
		static if(is(T==enum))
		{
			static if(is(T==Opcode))
			{ return bits(opInfo[a].bits, opInfo[a].bitCnt); }
			else
			{ return bits(a, EnumBits!T); }
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
		return res; 
	} 
	
	/+
		General rules of enums:
		 - enum item Order is important, GLSL sources rely on it.
		 - Defaults are always 0. The the first enum member is the default.
	+/
	
	enum TexXAlign {left, center, right} 
	enum TexYAlign {top, center, baseline, bottom} 
	enum TexSizeSpec {original, scaled, exact} 
	enum TexAspect {stretch, keep, crop} 
	
	enum TexOrientation
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
	
	enum FontType
	{
		textureHandles, 	//no fontMap, just individual texture handles.
		asciiCharmap16x16, 	//fontMap is a bitmap containing 16x16 monosized characters
		unicodeBlockMap128 	/+
			fontMap is a texture of 0x110000>>7 = 8704 uints.
			block = code>>7; blkTex = texture[fontMap[block]];
			charTex = blkTex[code & 0x7F];
			/+Opt: fast 0th block at the very start of the fontMap+/
		+/
	} 
	enum FontLine {none, underline, strikeout, errorline } 
	enum FontWidth {normal, thin/+.66+/, wide/+1.5+/, wider/+2+/ } 
	enum FontScript {none, superscript, subscript, small} 
	enum FontBlink {none, blink, soft, fast } 
	
	enum SizeUnit
	{
		world, 	/+one unit in the world+/
		screen, 	/+one pixel at the screen (similar to fwidth())+/
		model 	/+Todo: one unit inside scaled model space+/
	} 
	
	enum SizeFormat {u4, u8, ulog12/+4G range+/, f32} 
	enum ColorFormat {rgba_u8, rgb_u8, la_u8, a_u8, u1, u2, u4, u8} 
	enum HandleFormat {u12, u16, u24, u32} 
	enum CoordFormat {f32, i16, i12, i8} 
	enum FlagFormat {tex, font, vec, all} 
	
	
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
	
	
	version(/+$DIDE_REGION Opcode+/all)
	{
		mixin 入 !((
			(表([
				[q{/+Note: lvl0+/},q{/+Note: lvl1+/},q{/+Note: lvl2+/},q{/+Note: op+/},q{/+Note: comment+/}],
				[q{/+settings+/}],
				[q{/+	system+/}],
				[q{"0"},q{"00"},q{"00"},q{end},q{/+5 zeroed at end of VBO+/}],
				[q{},q{},q{"01"},q{setPh},q{/+phase (position along line)+/}],
				[q{},q{},q{"10"},q{setFlags},q{/+FlagFormat Flags+/}],
				[q{},q{},q{"11"},q{},q{/++/}],
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
				[q{/+	SVG linear+/}],
				[q{"1"},q{"00"},q{"00"},q{drawM},q{/+xy+/}],
				[q{},q{},q{"01"},q{drawL},q{/+xy+/}],
				[q{},q{},q{"10"},q{drawH},q{/+x+/}],
				[q{},q{},q{"11"},q{drawV},q{/+y+/}],
				[q{/+	SVG curves+/}],
				[q{},q{"01"},q{"00"},q{drawQ},q{/+xy xy+/}],
				[q{},q{},q{"01"},q{drawT},q{/+xy+/}],
				[q{},q{},q{"10"},q{drawC},q{/+xy xy xy+/}],
				[q{},q{},q{"11"},q{drawS},q{/+xy xy+/}],
				[q{/+	SVG arc, images, text+/}],
				[q{},q{"10"},q{"00"},q{drawA},q{/+rx ry rot, b, b, p+/}],
				[q{},q{},q{"01"},q{drawTEX},q{/+size, handle+/}],
				[q{},q{},q{"10"},q{drawTYPE},q{/+string+/}],
				[q{},q{},q{"11"},q{drawRECT},q{/++/}],
				[q{/+	future extensions+/}],
				[q{},q{"11"},q{"00"},q{drawMove},q{/+CoordFormat Coords+/}],
				[q{},q{},q{"01"},q{drawTexRect},q{/+CoordFormat Coords HandleFormat Handle+/}],
				[q{},q{},q{"10"},q{drawFontASCII},q{/+ubyte+/}],
				[q{},q{},q{"11"},q{drawFontASCII_2x},q{/+ubyte+/}],
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
	}
	
	static if((常!(bool)(0)))
	static foreach(op; EnumMembers!Opcode)
	pragma(msg, opInfo[op].bits.to!string(2).padLeft('0', opInfo[op].bitCnt).text, " : ", op.text); 
	
	
	
	
	version(none)
	enum test = mixin(體!((TexFlags),q{mixin(舉!((TexXAlign),q{center})), mixin(舉!((TexSizeSpec),q{original})), mixin(舉!((TexYAlign),q{center})), mixin(舉!((TexSizeSpec),q{original})), mixin(舉!((TexAspect),q{keep})), mixin(舉!((TexOrientation),q{normal}))})); 
	
	struct TexFlags
	{
		mixin((
			(表([
				[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
				[q{TexXAlign},q{2},q{"xAlign"},q{},q{/++/}],
				[q{TexSizeSpec},q{2},q{"xSize"},q{},q{/++/}],
				[q{TexYAlign},q{2},q{"yAlign"},q{},q{/++/}],
				[q{TexSizeSpec},q{2},q{"ySize"},q{},q{/++/}],
				[q{TexAspect},q{2},q{"aspect"},q{},q{/++/}],
				[q{TexOrientation},q{3},q{"orientation"},q{},q{/++/}],
			]))
		).調!(GEN_bitfields)); 
		enum bitCnt = 13; 
		protected
		{
			enum GLSLCode =
			iq{
				uint texXAlign() { return getBits(TF, 0, 2); } 
				uint texXSize() { return getBits(TF, 2, 2); } 
				uint texYAlign() { return getBits(TF, 4, 2); } 
				uint texYSize() { return getBits(TF, 6, 2); } 
				uint texAspect() { return getBits(TF, 8, 2); } 
				uint texOrientation() { return getBits(TF, 10, 3); } 
			}.text; 
		} 
	} 
	
	
	struct FontFlags
	{
		mixin((
			(表([
				[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
				[q{FontType},q{2},q{"type"},q{},q{/++/}],
				[q{bool},q{1},q{"bold"},q{},q{/++/}],
				[q{bool},q{1},q{"italic"},q{},q{/++/}],
				[q{bool},q{1},q{"monospace"},q{},q{/++/}],
				[q{FontLine},q{2},q{"line"},q{},q{/++/}],
				[q{FontWidth},q{2},q{"width"},q{},q{/++/}],
				[q{FontScript},q{2},q{"script"},q{},q{/++/}],
				[q{FontBlink},q{2},q{"blink"},q{},q{/++/}],
			]))
		).調!(GEN_bitfields)); 
		enum bitCnt = 13; 
		protected
		{
			enum GLSLCode =
			iq{
				uint fontType() { return getBits(FF, 0, 2); } 
				bool fontBold() { return getBit(FF, 2); } 
				bool fontItalic() { return getBit(FF, 3); } 
				bool fontMonospace() { return getBit(FF, 4); } 
				uint fontLine() { return getBits(FF, 5, 2); } 
				uint fontWidth() { return getBits(FF, 7, 2); } 
				uint fontScript() { return getBits(FF, 9, 2); } 
				uint fontBlink() { return getBits(FF, 11, 2); } 
			}.text; 
		} 
	} 
	
	struct VecFlags
	{
		mixin((
			(表([
				[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
				[q{CoordFormat},q{2},q{"format"},q{},q{/++/}],
				[q{bool},q{1},q{"relative"},q{},q{/++/}],
			]))
		).調!(GEN_bitfields)); 
		enum bitCnt = 3; 
		protected
		{
			enum GLSLCode = 
			iq{
				uint vecFormat() { return getBits(VF, 0, 2); } 
				bool vecRelative() { return getBit(VF, 2); } 
			}.text; 
		} 
	} 
	
	template FlagBits(T)
	{
		static foreach(A; AliasSeq!(TexFlags, FontFlags, VecFlags))
		static if(is(T : A)) enum FlagBits = A.bitCnt; 
	} 
	
	
	class GeometryStreamProcessor
	{
		/+
			Registers:
			/+
				Code: (表([
					[q{/+Note: name+/},q{/+Note: reg+/},q{/+Note: internal type+/},q{/+Note: stream formats+/},q{/+Note: instructions+/}],
					[q{
						primary color,
						secondary color
					},q{
						PC,
						SC
					},q{vec4},q{ColorFormat},q{
						setPC 	ColorFormat, col
						setSC 	ColorFormat, col
						setPCSC 	ColorFormat, col, col
						setC 	ColorFormat, col /+it broadcasts+/
					}],
					[q{
						pointSize 	= 1,
						lineWidth 	= 1,
						dotLength 	= 1,
						fontHeight 	= 18
						
					},q{
						PS,
						LW,
						FH,
						DS
					},q{float},q{SizeFormat},q{
						setPS 	SizeFormat, val
						setLW 	SizeFormat, val
						setDL 	SizeFormat, val /+scaling factor for LineTex[Ph]+/
						setFH 	SizeFormat, val
					}],
					[q{
						fontMapHandle,
						latinFontMapHandle,
						paletteHandle
						lineTexHandle
					},q{
						FMH
						LFMH
						PALH
						LTH
					},q{uint},q{HandleFormat},q{
						setFontMap 	HandleFormat, handle, FontType
						setLatinFontMap 	HandleFormat, handle
						setPalette 	HandleFormat, handle
						setLineTex 	HandleFormat, handle
					}],
					[],
					[q{//vector state:
					}],
					[q{position},q{P},q{vec3},q{CoordFormat},q{Various drawing and moving commands.}],
					[q{phase},q{Ph},q{float},q{CoordFormat},q{setPhase CoordFormat, coord /+used by -> lineTex[Ph]+/}],
					[],
					[q{/+Todo: Perpixel effects: arrows, markers, wavy line, multicolor dashed line+/}],
				]))
			+/
			
			Drawing commands:
			/+
				Code: (表([
					[q{/+Note: instr+/},q{/+Note: name+/}],
					[q{/+
						Line drawing commands based on SVG. 
						Every command has a lowercase relative variant tooL first bit is 1.
					+/}],
					[q{M p},q{move}],
					[q{L p},q{line}],
					[q{H signed_dist},q{horizontal line}],
					[q{V signed_dist},q{vertical line}],
					[q{Q p0, p1},q{quadratic bezier}],
					[q{T p},q{smooth quadratic bezier}],
					[q{C p0, p1, p2},q{cubic bezier}],
					[q{S p0, p1},q{smooth cubic bezier}],
					[q{A rx, ry, rot, lf, sf, p},q{elliptical arc}],
					[],
					[q{/+textured axis aligned rectangles+/}],
					[q{TEX [xSizeFmt, xSize], [ySizeFmt, ySize], hFmt, th},q{
						Draws a texture at the current position,
						aligned by xAlign, yAlign
						sized by xSizeSpec, ySizeSpec and aspect.
					}],
					[q{TEXM [xSizeFmt, xSize], [ySizeFmt, ySize], hFmt, th},q{Also moves the cursor to the right.}],
					[q{TYPE length, string},q{
						Uses fontMap, fontHeight, fontType 
						and fontFlags to draw a text.
					}],
				]))
			+/
			
		+/
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
	
	
}




class VulkanWindow: Window
{
	/+
		Todo: handle VK_ERROR_DEVICE_LOST.	It can be caused by an external bug 
		when the GPU freezes because of another app, and then restarts.
	+/
	
	struct BufferSizeConfigs
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
		{ mat4 transformationMatrix; } 
		
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
			
			void upload()
			{
				((0x635482886ADB).檢(buffer.appendPos)); 
				buffer.upload; 
				_uploadedVertexCount = (buffer.appendPos / VertexData.sizeof).to!uint; 
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
				((0x6A0782886ADB).檢(buffer.appendPos)); 
				buffer.upload; 
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
	}
	
	version(/+$DIDE_REGION IB     +/all)
	{
		version(/+$DIDE_REGION TexInfo declarations+/all)
		{
			alias TexHandle = Typedef!(uint, 0, "TexHandle"); 
			
			enum TexInfoFlag {
				error 	= 1,
				loading 	= 2,
				resident 	= 4
			}; alias TexInfoFlags = VkBitFlags!TexInfoFlag; 
			
			enum TexInfoBits	= 3,
			TexDimBits 	= 2, 
			TexChnBits 	= 2, 
			TexBppBits 	= 4, 
			TexInfoBitOfs	= 0,
			TexDimBitOfs	= 6,
			TexFormatBitOfs 	= 8 /+inside info_dword[0]+/,
			TexFormatBits 	= TexChnBits + TexBppBits + 1 /+alt+/; 
			
			enum TexDim {_1D, _2D, _3D} 	static assert(TexDim.max < 1<<TexDimBits); 
			enum _TexFormat_matrix = 
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
			])); 
			static if((常!(bool)(0))) { pragma(msg, GEN_TexFormat); }/+Todo: rename Type -> Format+/
			mixin(GEN_TexFormat); 
			static assert(TexChn.max < 1<<TexChnBits); static assert(TexBpp.max < 1<<TexBppBits); 
			static assert(TexFormat.max < 1<<TexFormatBits); 
			
			static string GEN_TexFormat()
			{
				version(/+$DIDE_REGION Process table cells, generate types+/all)
				{
					auto 	table = _TexFormat_matrix,
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
			
			struct TexSizeFormat
			{
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
					enum SharedCode = 
					q{
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
					},
					
					GLSLCode = 
					iq{
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
			} 
			static assert(TexSizeFormat.sizeof==8); 
			
			struct TexInfo
			{
				TexSizeFormat sizeFormat; 
				HeapChunkIdx heapChunkIdx; 
				uint extra; 
				
				string toString() const
				=> format!"TexInfo(%s, chunk:%d, extra:%d)"
				(sizeFormat, heapChunkIdx.to!uint, extra); 
			} 
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
		
		void rect(bounds2 bounds, TexHandle texHandle, in RGBA color=(RGBA(0xFFFFFFFF)))
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
	
	/+Opt: Make a faster bitStream fetcher with a closing MSB 1 bit instead of `currentDwBits`.+//+
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
	void createShaderModules()
	{
		enum shaderBinary = 
		(碼!((位!()),iq{glslc -O},iq{
			#version 430
			
			#define getBits(val, ofs, len) (bitfieldExtract(val, ofs, len))
			#define getBit(val, ofs) (bitfieldExtract(val, ofs, 1)!=0)
			#define setBits(val, ofs, len, data) (val = bitfieldInsert(val, data, ofs, len))
			
			#define ErrorColor vec4(1, 0, 1, 1)
			#define LoadingColor vec4(1, 0, 1, 1)
			
			
			
			$(
				(表([
					[q{/+Note: Stage out+/},q{/+Note: Stage in+/},q{/+Note: Location 0+/},q{/+Note: Location 1+/},q{/+Note: Location 2+/},q{/+Note: Location 3+/},q{/+Note: Location 4+/}],
					[q{},q{vert},q{uint vertGSBitOfs}],
					[q{vert},q{geom},q{uint geomGSBitOfs}],
					[q{geom},q{frag},q{
						smooth
						vec4 fragColor
					},q{
						smooth
						vec4 fragBkColor
					},q{
						smooth
						vec2 fragTexCoordXY
					},q{
						flat
						uint fragTexHandle
					},q{
						flat
						uint fragTexCoordZ
					}],
					[q{frag},q{},q{vec4 outColor}],
				]))
				.GEN_ShaderLayoutDeclarations
			)
			
			
			@vert: 
			
			void main()
			{
				geomGSBitOfs 	= vertGSBitOfs 
				/*geomVertexID	= gl_VertexIndex*/; 
			} 
			
			@geom: 
			$(ShaderBufferDeclarations)
			$(TexSizeFormat.GLSLCode)
			
			
			layout(points) in; 
			layout(triangle_strip, max_vertices = 170) out; 
			/*
				255 is the max on R9 Fury X
				
				250802 must send 2 more vertices to the geometry shader streams, last 2 is ignored.
					(Windows default driver, )
				250804 170 is the max with 12 components. 170*12=2040  (171*12=2052)
					I have no clue where this 2048 limit comes from o.O
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
			
			void emitVertex2D(vec2 p)
			{
				gl_Position = UB.mvp * vec4(p.xy, 0, 1); 
				EmitVertex(); 
			} 
			
			void emitPointSizeRect2D(in vec2 p, in vec2 size)
			{
				emitVertex2D(p); 
				emitVertex2D(p+vec2(0, size.y)); 
				emitVertex2D(p+vec2(size.x, 0)); 
				emitVertex2D(p+size); 
				EndPrimitive(); 
			} 
			
			void emitTexturedPointSizeRect2D(in vec2 p, in vec2 size)
			{
				fragTexCoordXY = vec2(0,0); emitVertex2D(p); 
				fragTexCoordXY = vec2(0,1); emitVertex2D(p+vec2(0, size.y)); 
				fragTexCoordXY = vec2(1,0); emitVertex2D(p+vec2(size.x, 0)); 
				fragTexCoordXY = vec2(1,1); emitVertex2D(p+size); 
				EndPrimitive(); 
			} 
			
			void emitTexturedPointPointRect2D(in vec2 p, in vec2 q)
			{
				fragTexCoordXY = vec2(0,0); emitVertex2D(p); 
				fragTexCoordXY = vec2(0,1); emitVertex2D(vec2(p.x, q.y)); 
				fragTexCoordXY = vec2(1,0); emitVertex2D(vec2(q.x, p.y)); 
				fragTexCoordXY = vec2(1,1); emitVertex2D(q); 
				EndPrimitive(); 
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
			
			int fetch_int(inout BitStream bitStream, int numBits)
			{ return bitfieldExtract(int(fetchBits(bitStream, numBits)), 0, numBits); } 
			
			uint fetch_uint(inout BitStream bitStream)
			{
				return fetchBits(bitStream, 32); 
				/*Opt: this 32bit read should be optimized*/
			} 
			
			float fetch_float(inout BitStream bitStream)
			{ return uintBitsToFloat(fetch_uint(bitStream)); } 
			
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
			
			/*Vector graphics state registers*/
			uint TF = 0, FF = 0, VF = 0; 	//flags: texFlags, fontFlags, vecFlags
			
			
			vec4 PC = vec4(1); 	/* Primary color - default black */
			vec4 SC = vec4(0); 	/* Secondary color - default white */
				
			float PS = 1; 	/* Point size */
			float LW = 1; 	/* Line width */
			float DL = 1; 	/* Dot lenthg */
			float FH = 18; 	/* Font height */
				
			uint FMH = 0; 	/* Font map handle */
			uint LFMH = 0; 	/* Latin font map handle */
			uint PALH = 0; 	/* Palette handle */
			uint LTH = 0; 	/* Line texture handle */
				
			vec3 	P	= vec3(0), 
				P_last 	= vec3(0),
				P_next 	= vec3(0); 	/* Position */
			float 	Ph 	= 0, 
				Ph_next 	= 0; 	/* Phase coordinate */
				
			int runningCntr = 256; 	/*
				Execution is enabled if it's greater than 0
				After every step it's decremented.
			*/
			
			$(TexFlags.GLSLCode)
			$(FontFlags.GLSLCode)
			$(VecFlags.GLSLCode)
			
			/* Helper functions for fetching different data formats */
			$(GEN_enumDefines!ColorFormat)
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
						case ColorFormat_la_u8: 	color.rgb = vec3(tmp.x); color.a = tmp.y; 	return 3; 
						case ColorFormat_a_u8: 	color.a = tmp.x; 	return 2; 
					}
				}
				else if(format<=ColorFormat_u8 /*u1 .. u8*/)
				{
					const int idx = int(format - ColorFormat_u1); //0..3
					const int bits = 1<<idx; //1, 2, 4, 8
					const float high = float((1<<bits) - 1); //1, 3, 15, 255
					const uint raw = fetchBits(bitStream, bits); 
					if(PALH!=0)	color = readPaletteSample(PALH, raw, false)/*palette lookup*/; 
					else	color.rgb = vec3(float(raw) / high)/*grayscale*/; 
					return 1; 
				}
				return 0; 
			} 
			
			$(GEN_enumDefines!SizeFormat)
			float fetchSize(inout BitStream bitStream, uint format)
			{
				switch(format)
				{
					case SizeFormat_u4: 	return float(fetchBits(bitStream, 4) / 15.0); 
					case SizeFormat_u8: 	return float(fetchBits(bitStream, 8) / 255.0); 
					case SizeFormat_ulog12: 	return exp2(float(fetchBits(bitStream, 12)) / 128.0); 
					case SizeFormat_f32: 	return fetch_float(bitStream); 
					default: return 1.0; 
				}
			} 
			
			
			$(GEN_enumDefines!HandleFormat)
			uint fetchHandle(inout BitStream bitStream, uint format)
			{
				switch(format) {
					case HandleFormat_u12: 	return fetchBits(bitStream, 12); 
					case HandleFormat_u16: 	return fetchBits(bitStream, 16); 
					case HandleFormat_u24: 	return fetchBits(bitStream, 24); 
					case HandleFormat_u32: 	return fetch_uint(bitStream); 
					default: return 0; 
				}
			} 
			
			$(GEN_enumDefines!CoordFormat)
			float fetchCoord(inout BitStream bitStream, uint format)
			{
				int bits=0; 
				switch(format)
				{
					case CoordFormat_f32: 	return fetch_float(bitStream); 
					case CoordFormat_i16: 	bits = 16; 	break; 
					case CoordFormat_i12: 	bits = 12; 	break; 
					case CoordFormat_i8: 	bits = 8; 	break; 
				}
				if(bits>0) return float(fetch_int(bitStream, bits)); 
				return 0; 
				/*Opt: Do it with single fetch*/
			} 
			$(GEN_enumDefines!FlagFormat)
			void setFlags(inout BitStream bitStream)
			{
				const uint fmt = fetchBits(bitStream, $(EnumBits!FlagFormat)); 
				
				if(fmt==FlagFormat_all || fmt==FlagFormat_tex) TF = fetchBits(bitStream, $(FlagBits!TexFlags)); 
				if(fmt==FlagFormat_all || fmt==FlagFormat_font) FF = fetchBits(bitStream, $(FlagBits!FontFlags)); 
				if(fmt==FlagFormat_all || fmt==FlagFormat_vec) VF = fetchBits(bitStream, $(FlagBits!VecFlags)); 
				/*Opt: Do it all with a single fetchBits call*/
			} 
			
			void fetchP(inout BitStream bitStream)
			{
				const uint coordFmt = fetchBits(bitStream, $(EnumBits!CoordFormat)); 
				P_next.xy = vec2(
					fetchCoord(bitStream, coordFmt), 
					fetchCoord(bitStream, coordFmt)
				); 
			} 
			
			void latchP()
			{ P_last = P; P = P_next; } 
			
			void drawMove(inout BitStream bitStream)
			{
				fetchP(bitStream); 
				
				latchP(); 
			} 
			
			void drawTexRect(inout BitStream bitStream)
			{
				fetchP(bitStream); 
				
				const uint handleFmt = fetchBits(bitStream, $(EnumBits!HandleFormat)); 
				const uint texHandle = fetchHandle(bitStream, handleFmt); 
				
				fragColor = PC; fragBkColor = SC; 
				fragTexHandle = texHandle; 
				emitTexturedPointPointRect2D(P.xy, P_next.xy); 
				
				latchP(); 
			} void drawASCII(inout BitStream bitStream, bool doubleSize)
			{
				vec2 size = vec2(getTexSize(FMH).xy); 
				
				if(doubleSize) size *= 2; 
				
				fragTexCoordZ = fetchBits(bitStream, 8); 
				fragColor = PC; fragBkColor = SC; 
				fragTexHandle = FMH; 
				emitTexturedPointPointRect2D(P.xy, P.xy+size); 
				
				fragTexCoordZ = 0; //restore it
				P_next.x += size.x; //advance cursor
				latchP(); 
			} 
			
			
			void processInstruction(inout BitStream bitStream) 
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
					switch(subCat)
					{
						case 0: //system
							switch(cmd)
						{
							case 0: 	runningCntr = 0; 	/*end - 5 zeroes at end of VBO*/	break; 
							case 1: 	/*setPh(); */	/*set phase (position along line)*/	break; 
							case 2: 	setFlags(bitStream); 	/*set flags*/	break; 
							case 3: 			break; 
						}
						break; 
						case 1: //colors
							{
							const uint fmt = fetchBits(bitStream, $(EnumBits!ColorFormat)); 
							int copyFlags = 0; /*bit0: RGB changed, bit1: Alpha changed*/
							if(cmd!=1) copyFlags = fetchColor(bitStream, fmt, PC); 
							if(cmd==1 || cmd==2) fetchColor(bitStream, fmt, SC); 
							else if(cmd==3) {
								if((copyFlags & 1)!=0) SC.rgb = PC.rgb; 
								if((copyFlags & 2)!=0) SC.a = PC.a; 
							}
						}
						break; 
						case 2: //sizes
							{
							const uint fmt = fetchBits(bitStream, $(EnumBits!SizeFormat)); 
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
							const uint fmt = fetchBits(bitStream, $(EnumBits!HandleFormat)); 
							const uint handle = fetchHandle(bitStream, fmt); 
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
				}else {
					switch(subCat)
					{
						case 0: //SVG linear
							switch(cmd)
						{
							/*
								x	update x coord
								y 	update y coord
								z 	update z coord
								xy	update x and y coords
								xyz	update x, y and z coords
								x1 	update x coord, move y by relative 1
								tf 	turn, then move forward
								tft 	half turn, move forward, another half turn
							*/
							
							case 0: 	/*drawM(); */	/*move (xy)*/	break; 
							case 1: 	/*drawL(); */	/*line (xy)*/	break; 
							case 2: 	/*drawH(); */	/*horizontal line (x)*/	break; 
							case 3: 	/*drawV(); */	/*vertical line (y)*/	break; 
						}
						break; 
						case 1: //SVG curves
							switch(cmd)
						{
							case 0: 	/*drawQ(); */	/*quadratic bezier (xy, xy)*/	break; 
							case 1: 	/*drawT(); */	/*smooth quadratic bezier (xy)*/	break; 
							case 2: 	/*drawC(); */	/*cubic bezier (xy, xy, xy)*/	break; 
							case 3: 	/*drawS(); */	/*smooth cubic bezier (xy, xy)*/	break; 
						}
						break; 
						case 2: //SVG arc, images, text
							switch(cmd)
						{
							case 0: 	/*drawA(); */	/*elliptical arc (rx, ry, rot, b, b, p)*/	break; 
							case 1: 	/*drawTEX(); */	/*draw texture (size, handle)*/	break; 
							case 2: 	/*drawTYPE(); */	/*draw text (string)*/	break; 
							case 3: 	/*drawRECT(); */	/*draw rectangle*/	break; 
						}
						break; 
						case 3: 
							switch(cmd)
						{
							case 0: 	drawMove(bitStream); 	break; 
							case 1: 	drawTexRect(bitStream); 	break; 
							case 2: 	drawASCII(bitStream, false); 	break; 
							case 3: 	drawASCII(bitStream, true); 	break; 
						}
						break; 
					}
				}
			} 
			
			
			void main() /*geometry shader*/
			{
				fragTexCoordZ = 0; //this is normally 0. Fonts can temporarily change it.
				
				BitStream GS = initBitStream(geomGSBitOfs[0]/*, geomGSBitOfs[0]+10000*/); 
				while(runningCntr>0/* && GS.totalBitsRemaining>0*//*overflow check*/)
				{ processInstruction(GS); runningCntr--; }
			} 
			
			@frag: 
			$(ShaderBufferDeclarations)
			$(TexSizeFormat.GLSLCode)
			
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
			
			void main() {
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
					vec2 tc = fragTexCoordXY + 	rooks.x * texCoordDx + 
						rooks.y * texCoordDy; 
					vec4 smp = readSample(fragTexHandle, vec3(tc, fragTexCoordZ), true, false); 
					sum += smp; 
				}
				sum /= 6; 
				
				outColor = mix(fragBkColor, vec4(sum.rgb, 1)*fragColor, sum.a); 
			} 
		})); 
		shaderModules = new VulkanGraphicsShaderModules(device, shaderBinary); 
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
		layout(binding = 0) uniform UB_T { mat4 mvp; } UB; 
		
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
				rasterizerDiscardEnable 	: false,
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
	{ TexSizeFormat.selfTest; } 
	
	
	override void onInitializeGLWindow()
	{
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
							enum globalScale=1; 
							auto modelMatrix = mat4.identity; 
							const rotationAngle = 0 * QPS.value(10*second); 
							modelMatrix.translate(vec3(-160-32, -100-32, 0)*globalScale); 
							modelMatrix.rotate(vec3(0, 0, 1), rotationAngle); 
							
							// Set up view
							const side = vec2(1, 0).rotate(QPS.value(10*second).fract*π*2)*vec2(80, 40)*1; 
							const zoomanim = (0.71f+0.7f*sin((float(QPS.value(19*second))).fract*π*2))*0+1; 
							auto viewMatrix = mat4.lookAt(vec3(side.xy, 500)/1.65f*globalScale*(zoomanim), vec3(0), vec3(0, 1, 0)); 
							
							// Set up projection
							auto projMatrix = mat4.perspective(swapchain.extent.width, swapchain.extent.height, 60, 0.1*globalScale, 1000*globalScale); 
							
							UB.access.transformationMatrix = projMatrix * viewMatrix * modelMatrix; 
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