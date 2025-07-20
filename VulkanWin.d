module vulkanwin; 

public import het.win, het.bitmap, het.vulkan; 

import core.stdc.string : memset; 

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
	
	
	enum OpCat
	{
		system, color, size, handle,
		reserved4, reserved5, reserved6, reserved7,
	} 
	enum Opcode
	{
		//opcat: system
		end = 0, 
		
		//opcat: system
		setPC=0, setSC=1, setPCSC=2, setC=3/+broadcast single color+/,
		
		//opcat: size
		setPS=0, setLW=1, setDS=2, setFH=3,
		
		
	} 
	
	struct FontTexFlags
	{
		/+This is a combination of FontFlags and TexFlags+/
		
		mixin((
			(表([
				[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
				[q{TexXAlign},q{2},q{"texXAlign"},q{},q{/++/}],
				[q{TexSizeSpec},q{2},q{"texXSize"},q{},q{/++/}],
				[q{TexYAlign},q{2},q{"texYAlign"},q{},q{/++/}],
				[q{TexSizeSpec},q{2},q{"texYSize"},q{},q{/++/}],
				[q{TexAspect},q{2},q{"texAspect"},q{},q{/++/}],
				[q{TexOrientation},q{3},q{"texOrientation"},q{},q{/++/}],
				[],
				[q{FontType},q{2},q{"fontType"},q{},q{/++/}],
				[q{bool},q{1},q{"fontBold"},q{},q{/++/}],
				[q{bool},q{1},q{"fontItalic"},q{},q{/++/}],
				[q{bool},q{1},q{"fontMonospace"},q{},q{/++/}],
				[q{FontLine},q{2},q{"fontLine"},q{},q{/++/}],
				[q{FontWidth},q{2},q{"fontWidth"},q{},q{/++/}],
				[q{FontScript},q{2},q{"fontScript"},q{},q{/++/}],
				[q{FontBlink},q{2},q{"fontBlink"},q{},q{/++/}],
			]))
		).調!(GEN_bitfields)); 
		
		protected
		{
			enum GLSLCode = /+
				AI: /+
					Hidden: I need you to generate GLSL functions.  I have this global variable: `uint fontTexFlags;`
					
					I only need the getters, so no need the to use 'get' prefixes.
					You can use my macros to get the bits:
					/+
						Code: #define getBits(val, ofs, len) (bitfieldExtract(val, ofs, len))
						#define getBit(val, ofs) (bitfieldExtract(val, ofs, 1)!=0)
					+/
					
					For boolean results please use getBit macro.
					For other enumerated types, the return type will be uint because fontTextFlags is an uint.
					
					Here are all the fields:
				+/
			+/
			q{
				uint texXAlign() { return getBits(fontTexFlags, 0, 2); } 
				uint texXSize() { return getBits(fontTexFlags, 2, 2); } 
				uint texYAlign() { return getBits(fontTexFlags, 4, 2); } 
				uint texYSize() { return getBits(fontTexFlags, 6, 2); } 
				uint texAspect() { return getBits(fontTexFlags, 8, 2); } 
				uint texOrientation() { return getBits(fontTexFlags, 10, 3); } 
				uint fontType() { return getBits(fontTexFlags, 13, 2); } 
				bool fontBold() { return getBit(fontTexFlags, 15); } 
				bool fontItalic() { return getBit(fontTexFlags, 16); } 
				bool fontMonospace() { return getBit(fontTexFlags, 17); } 
				uint fontLine() { return getBits(fontTexFlags, 18, 2); } 
				uint fontWidth() { return getBits(fontTexFlags, 20, 2); } 
				uint fontScript() { return getBits(fontTexFlags, 22, 2); } 
				uint fontBlink() { return getBits(fontTexFlags, 24, 2); } 
			}; 
		} 
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
						dashSize 	= 1,
						fontHeight 	= 18
						
					},q{
						PS,
						LW,
						FH,
						DS
					},q{float},q{SizeFormat},q{
						setPS 	SizeFormat, val
						setLW 	SizeFormat, val
						setDS 	SizeFormat, val /+scaling factor for LineTex[Ph]+/
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
	
	VkClearValue clearColor = { color: {float32: [ 0, 0, 0, 0 ]}, }; 
	
	
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
		enum VertexCmd
		{texturedRect} 
		enum VertexCmdBits = 4; static assert(VertexCmd.max < 1<<VertexCmdBits); 
		
		union VertexData {
			struct 
			{ uvec4 VA0, VA1; } 
			struct 
			{
				uint cmd; 
				RGBA color; 
				uint dummy0, dummy1; 
				bounds2 bounds; 
			} 
		} 
		
		static assert(VertexData.sizeof == 32); 
		
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
			
			void upload()
			{
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
			uint append(T)(in T data)
			{
				const ofs = (cast(uint)(buffer.appendPos)); /+A maximum of 4GB geometry data is assumed+/
				buffer.append(data); return ofs; 
			} 
			
			void upload()
			{ buffer.upload; } 
			
			@property deviceMemoryBuffer() => buffer.deviceMemoryBuffer; 
		} 
	}
	
	version(/+$DIDE_REGION IB     +/all)
	{
		version(/+$DIDE_REGION TexInfo declarations+/all)
		{
			alias TexHandle = Typedef!(uint, 0, "TexHandle"); 
			
			enum TexFlag {
				error 	= 1,
				loading 	= 2,
				resident 	= 4
			}; alias TexFlags = VkBitFlags!TexFlag; 
			
			enum FlagBits	= 3,
			DimBits 	= 2, 
			ChnBits 	= 2, 
			BppBits 	= 4, 
			FlagBitOfs	= 0,
			DimBitOfs	= 6,
			FormatBitOfs 	= 8 /+inside info_dword[0]+/,
			FormatBits 	= ChnBits + BppBits + 1 /+alt+/; 
			
			enum TexDim {_1D, _2D, _3D} 	static assert(TexDim.max < 1<<DimBits); 
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
			static assert(TexChn.max < 1<<ChnBits); static assert(TexBpp.max < 1<<BppBits); 
			static assert(TexFormat.max < 1<<FormatBits); 
			
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
				
				@property format() const => (cast(TexFormat)((*(cast(ulong*)(&this))).getBits(FormatBitOfs, FormatBits))); 
				@property format(TexFormat t) { auto p = (cast(ulong*)(&this)); *p = (*p).setBits(FormatBitOfs, FormatBits, t); } 
				
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
				=> mixin(幟!((TexFlag),q{getBits(*(cast(ubyte*)(&this)), FlagBitOfs, FlagBits)})); 
				
				@property flags(in TexFlags a)
				{ auto b = (cast(ubyte*)(&this)); *b = setBits(*b, FlagBitOfs, FlagBits, (cast(ubyte)((cast(uint)(a))))); } 
				
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
		
		this(S)(in TexFlags flags, in TexFormat format, in S size, in void[] data=null)
		{
			TexSizeFormat fmt; 
			fmt.flags 	= flags,
			fmt.format 	= format,
			fmt.size 	= size; 
			fmt.resident = true; 
			handle = TB.createHandleAndSetData(fmt, data); 
		} 
		
		this(S)(in TexFormat format, in S size, in void[] data=null, in TexFlags flags=TexFlags.init)
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
		
		void rect(bounds2 bounds, TexHandle texHandle, RGBA color=(RGBA(0xFFFFFFFF)))
		{
			const addr = GB.append(bounds); 
			VB.buffer.append
			(
				mixin(體!((VertexData),q{
					cmd 	: VertexCmd.texturedRect | texHandle.to!uint<<VertexCmdBits,
					dummy0 	: addr,
					/+bounds 	: bounds,+/
					color 	: color
				}))
			); 
		} 
		
		void draw(A...)(A args)
		{
			TexHandle tex; 
			RGBA color = (RGBA(0xFFFFFFFF)); 
			
			void emitQuad_vec2(); 
			
			static foreach(i; 0..A.length)
			{
				{
					alias T = A[i], a = args[i]; 
					static if(is(T : TexHandle)) { tex = a; }
					else static if(is(T : RGB)) { color.rgb = a; }
					else static if(is(T : RGBA)) { color.rgba = a; }
					else static if(is(T : vec2)) { emitQuad_vec2(a); }
					else static assert(0, "unhandled type: "~T.stringof); 
				}
			}
		} 
		
		
		
		/+
			void tri(Args...)(in Args args)
			{
				void emit(in vec3 pos)
				{ buffer.append(VertexData(pos, actColor)); } 
				
				static foreach(i, A; Args)
				{
					static if(is(A==vec3)) emit(args[i]); 
					else static if(is(A==vec2)) emit(vec3(args[i], 0)); 
					else static if(is(A==RGB)) actColor = args[i].from_unorm; 
				}
			} 
		+/
	} 
	
	/+
		AI: /+
			User: I have some GLSL variables declared:
			/+
				Code: /+Vector graphics state registers+/
				vec4 PC = vec4(0, 0, 0, 1); 	/+ Primary color - default black +/
				vec4 SC = vec4(1, 1, 1, 1); 	/+ Secondary color - default white +/
					
				float PS = 1; 	/+ Point size +/
				float LW = 1; 	/+ Line width +/
				float DS = 1; 	/+ Dash size scaling factor +/
				float FH = 18; 	/+ Font height +/
					
				uint FMH = 0; 	/+ Font map handle +/
				uint LFMH = 0; 	/+ Latin font map handle +/
				uint PALH = 0; 	/+ Palette handle +/
				uint LTH = 0; 	/+ Line texture handle +/
					
				vec3 P = vec3(0); 	/+ Position +/
				float Ph = 0; 	/+ Phase coordinate +/
			+/
			
			I also have a bitStream that I can read from by using : 
			/+Code: uint fetchBits(GS, numBits/*you have to fill it!*/)+/
			/+Code: bool fetch_bool(GS)+/
			/+Code: uint fetch_uint(GS)+/
			/+Code: float fetch_float(GS)+/
			/+Code: vec2 fetch_vec2(GS)+/
			/+Code: vec3 fetch_vec3(GS)+/
			/+Code: vec4 fetch_vec4(GS)+/
			You can build more convinience functions if you want based on these.
			
			Here are the documentation of these variables, they are basically registers in a virtual processor:
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
						dashSize 	= 1,
						fontHeight 	= 18
						
					},q{
						PS,
						LW,
						FH,
						DS
					},q{float},q{SizeFormat},q{
						setPS 	SizeFormat, val
						setLW 	SizeFormat, val
						setDS 	SizeFormat, val /+scaling factor for LineTex[Ph]+/
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
			
			Here are some types you can use: In GLSL they are in the form: TexXAlign_left, etc...
			/+
				Code: enum TexXAlign {left, center, right} 
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
				enum SizeFormat {f32, log12, u8, u4} 
				enum ColorFormat {a_u8, la_u8, rgb_u8, rgba_u8, u1, u2, u4, u8} 
				enum HandleFormat {u12, u16, u24, u32} 
				
				struct FontTexFlags
				{
					/+This is a combination of FontFlags and TexFlags+/
					
					mixin((
						(表([
							[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
							[q{TexXAlign},q{2},q{"texXAlign"},q{},q{/++/}],
							[q{TexSizeSpec},q{2},q{"texXSize"},q{},q{/++/}],
							[q{TexYAlign},q{2},q{"texYAlign"},q{},q{/++/}],
							[q{TexSizeSpec},q{2},q{"texYSize"},q{},q{/++/}],
							[q{TexAspect},q{2},q{"texAspect"},q{},q{/++/}],
							[q{TexOrientation},q{3},q{"texOrientation"},q{},q{/++/}],
							[],
							[q{FontType},q{2},q{"fontType"},q{},q{/++/}],
							[q{bool},q{1},q{"fontBold"},q{},q{/++/}],
							[q{bool},q{1},q{"fontItalic"},q{},q{/++/}],
							[q{bool},q{1},q{"fontMonospace"},q{},q{/++/}],
							[q{FontLine},q{2},q{"fontLine"},q{},q{/++/}],
							[q{FontWidth},q{2},q{"fontWidth"},q{},q{/++/}],
							[q{FontScript},q{2},q{"fontScript"},q{},q{/++/}],
							[q{FontBlink},q{2},q{"fontBlink"},q{},q{/++/}],
						]))
					).調!(GEN_bitfields)); 
					
					protected
					{
						enum GLSLCode = /+
							AI: /+
								Hidden: I need you to generate GLSL functions.  I have this global variable: `uint fontTexFlags;`
								
								I only need the getters, so no need the to use 'get' prefixes.
								You can use my macros to get the bits:
								/+
									Code: #define getBits(val, ofs, len) (bitfieldExtract(val, ofs, len))
									#define getBit(val, ofs) (bitfieldExtract(val, ofs, 1)!=0)
								+/
								
								For boolean results please use getBit macro.
								For other enumerated types, the return type will be uint because fontTextFlags is an uint.
								
								Here are all the fields:
							+/
						+/
						q{
							uint texXAlign() { return getBits(fontTexFlags, 0, 2); } 
							uint texXSize() { return getBits(fontTexFlags, 2, 2); } 
							uint texYAlign() { return getBits(fontTexFlags, 4, 2); } 
							uint texYSize() { return getBits(fontTexFlags, 6, 2); } 
							uint texAspect() { return getBits(fontTexFlags, 8, 2); } 
							uint texOrientation() { return getBits(fontTexFlags, 10, 3); } 
							uint fontType() { return getBits(fontTexFlags, 13, 2); } 
							bool fontBold() { return getBit(fontTexFlags, 15); } 
							bool fontItalic() { return getBit(fontTexFlags, 16); } 
							bool fontMonospace() { return getBit(fontTexFlags, 17); } 
							uint fontLine() { return getBits(fontTexFlags, 18, 2); } 
							uint fontWidth() { return getBits(fontTexFlags, 20, 2); } 
							uint fontScript() { return getBits(fontTexFlags, 22, 2); } 
							uint fontBlink() { return getBits(fontTexFlags, 24, 2); } 
						}; 
					} 
				} 
			+/
			
			Your task is to generate code for the register setter functions in GLSL.
			It is a big case switch statement basically.
			You are free to assign opcodes to the instructions. Use 4 bits for it, I think it is enough.
			Good luck ;)
		+/
		/+
			Assistant: /+
				Para: I'll generate GLSL code for the register setter functions using a switch statement with 4-bit opcodes.
				Here's the implementation:
			+/
			
			/+
				Structured: /+
					Register setter functions 
					Uses 4-bit opcodes (0x0-0xF)
					Format: opcode (4 bits) | format (4 bits) | data...
				+/ 
				void processRegisterCommand(uint opcode)
				{
					uint format = fetchBits(4); 
					
					switch(opcode)
					{
						/+ Color registers +/
						case 0x0: // setPC
							PC = fetchColor(format); 
							break; 
							
						case 0x1: // setSC 
							SC = fetchColor(format); 
							break; 
							
						case 0x2: // setPCSC
							PC = fetchColor(format); 
							SC = fetchColor(format); 
							break; 
							
						case 0x3: // setC (broadcast to both)
							vec4 color = fetchColor(format); 
							PC = color; 
							SC = color; 
							break; 
							
						/+ Size registers +/
						case 0x4: // setPS
							PS = fetchSize(format); 
							break; 
							
						case 0x5: // setLW
							LW = fetchSize(format); 
							break; 
							
						case 0x6: // setDS
							DS = fetchSize(format); 
							break; 
							
						case 0x7: // setFH
							FH = fetchSize(format); 
							break; 
							
						/+ Handle registers +/
						case 0x8: // setFontMap
							{
							uint handle = fetchHandle(format); 
							uint fontType = fetchBits(2); 
							FMH = handle; 
							// Additional font type processing if needed
						}
							break; 
							
						case 0x9: // setLatinFontMap
							LFMH = fetchHandle(format); 
							break; 
							
						case 0xA: // setPalette
							PALH = fetchHandle(format); 
							break; 
							
						case 0xB: // setLineTex
							LTH = fetchHandle(format); 
							break; 
							
						/+ Vector state +/
						case 0xC: // setPosition
							P = fetchCoord(format); 
							break; 
							
						case 0xD: // setPhase
							Ph = fetchCoord(format).x; 
							break; 
							
						default: 
							/+ Unknown opcode - handle error +/
							break; 
					}
				} 
				
				/+ Helper functions for fetching different data formats +/
				vec4 fetchColor(uint format)
				{
					switch(format)
					{
						case 0: return vec4(fetch_float()); // a_u8 as float
						case 1: return vec4(fetch_vec2(), 0, 1); // la_u8
						case 2: return vec4(fetch_vec3(), 1); // rgb_u8
						case 3: return fetch_vec4(); // rgba_u8
						/+Bug: ezek 8 bitesek, nem floatosak!!!+/
						
						/+Bug: A formatokat NEV szerint kell csinalni, a szamokkal kovethetetlen!!!+/
						
						case 4: return vec4(fetch_bool() ? 1.0 : 0.0); // u1
						case 5: return vec4(float(fetchBits(2)) / 3.0); // u2
						case 6: return vec4(float(fetchBits(4)) / 15.0); // u4
						case 7: return vec4(float(fetchBits(8)) / 255.0); // u8
						default: return vec4(0); 
					}
				} 
				
				float fetchSize(uint format)
				{
					switch(format)
					{
						case 0: return fetch_float(); // f32
						case 1: return exp2(float(int(fetchBits(12)) - 2048) / 256.0); // log12
						case 2: return float(fetchBits(8) / 255.0); // u8
						case 3: return float(fetchBits(4) / 15.0); // u4
						default: return 1.0; 
					}
				} 
				
				uint fetchHandle(uint format)
				{
					switch(format)
					{
						case 0: return fetchBits(12); // u12
						case 1: return fetchBits(16); // u16
						case 2: return fetchBits(24); // u24
						case 3: return fetch_uint(); // u32
						default: return 0; 
					}
				} 
				
				vec3 fetchCoord(uint format)
				{
					switch(format)
					{
						case 0: return fetch_vec3(); // full precision
						case 1: return vec3(fetch_vec2(), 0); // 2D coords
						case 2: return vec3(float(fetchBits(16)) / 65535.0); // normalized u16
						case 3: return vec3(float(fetchBits(8)) / 255.0); // normalized u8
						default: return vec3(0); 
					}
				} 
			+/
			
			This implementation:
			
			1. Uses 4-bit opcodes (0x0-0xF) for the instructions
			2. Each instruction can have a 4-bit format specifier for data decoding
			3. Includes helper functions for fetching different data formats:
						/+Bullet: /+Highlighted: fetchColor()+/ for color formats+/
						/+Bullet: /+Highlighted: fetchSize()+/ for size values+/
						/+Bullet: /+Highlighted: fetchHandle()+/ for texture handles+/
						/+Bullet: /+Highlighted: fetchCoord()+/ for position/coordinate values+/
			4. Handles all the register types mentioned:
						/+Bullet: Color registers (PC, SC)+/
						/+Bullet: Size registers (PS, LW, DS, FH)+/
						/+Bullet: Handle registers (FMH, LFMH, PALH, LTH)+/
						/+Bullet: Vector state (P, Ph)+/
			
			/+
				Para: The format specifiers allow flexible data encoding while keeping the bitstream compact. The switch
				statement makes it easy to add new instructions by just adding new cases.
			+/
			
			/+Note: Usage(prompt_hit: 64, prompt_miss: 3264, completion: 1244, HUF: 0.85, price: 100%)+/
		+/
	+/
	
	/+
		AI: /+
			User: GLSL:
			/+
				Code: uint fetchHandle(uint format)
				{
					switch(format)
					{
						case 0: return fetchBits(12); // u12
						case 1: return fetchBits(16); // u16
						case 2: return fetchBits(24); // u24
						case 3: return fetch_uint(); // u32
						default: return 0; 
					}
				} 
			+/
			
			DLang:
			/+Code: enum HandleFormat {u12, u16, u24, u32} +/
			
			From glsl you can access enum ids like `HandleFormat_u12` constants.
			
			Please replace the integer caqse constants with them!
		+/
		/+
			Assistant: Here's the updated GLSL code using the DLang enum constants:
			
			/+
				Structured: /+
					Code: uint fetchHandle(uint format)
					{
						switch(format)
						{
							case HandleFormat_u12: return fetchBits(12); // u12
							case HandleFormat_u16: return fetchBits(16); // u16
							case HandleFormat_u24: return fetchBits(24); // u24
							case HandleFormat_u32: return fetch_uint(); // u32
							default: return 0; 
						}
					} 
				+/
			+/
			
			/+Note: Usage(prompt_hit: 64, prompt_miss: 314, completion: 122, HUF: 0.08, price: 100%)+/
		+/
	+/
	/+
		AI: /+
			User: /+
				Code: float fetchSize(inout BitStream bitStream, uint format)
				{
					switch(format)
					{
						case 0: return fetch_float(bitStream); // f32
						case 1: return exp2(float(int(fetchBits(bitStream, 12)) - 2048) / 256.0); // log12
						case 2: return float(fetchBits(bitStream, 8) / 255.0); // u8
						case 3: return float(fetchBits(bitStream, 4) / 15.0); // u4
						default: return 1.0; 
					}
				} 
			+/
			
			I have enum ID names here:
			/+Code: enum SizeFormat {f32, log12, u8, u4} +/
			
			Please replace the case constants to to be like `SizeFormat_f32`, not an integer literal!
		+/
		/+
			Assistant: Here's the updated code with enum names instead of integer literals:
			
			/+
				Structured: /+
					Code: float fetchSize(inout BitStream bitStream, uint format)
					{
						switch(format)
						{
							case SizeFormat.f32: return fetch_float(bitStream); // f32
							case SizeFormat.log12: return exp2(float(int(fetchBits(bitStream, 12)) - 2048) / 256.0); // log12
							case SizeFormat.u8: return float(fetchBits(bitStream, 8) / 255.0); // u8
							case SizeFormat.u4: return float(fetchBits(bitStream, 4) / 15.0); // u4
							default: return 1.0; 
						}
					} 
				+/
			+/
			
			/+Note: Usage(prompt_hit: 64, prompt_miss: 354, completion: 196, HUF: 0.11, price: 100%)+/
		+/
	+/
	/+
		AI: /+
			User: Please estimate high low ranges and gradient step percentage for:
			/+Code: exp2(float(fetchBits(bitStream, 12)) / 128.0)+/
		+/
		/+
			Assistant: Let me analyze the expression and estimate the ranges:
			
			1. /+Highlighted: fetchBits(bitStream, 12)+/ extracts 12 bits:
						/+Bullet: Minimum value: 0+/
						/+Bullet: Maximum value: 2^12 - 1 = 4095+/
			
			2. /+Highlighted: float(fetchBits(...))+/ converts to floating point:
						/+Bullet: Minimum: 0.0f+/
						/+Bullet: Maximum: 4095.0f+/
			
			3. Division by 128.0:
						/+Bullet: Minimum: 0.0f / 128.0 = 0.0f+/
						/+Bullet: Maximum: 4095.0f / 128.0 ≈ 31.9921875f+/
			
			4. /+Highlighted: exp2()+/ (2^x) operation:
						/+Bullet: Minimum: exp2(0.0f) = 1.0f+/
						/+Bullet: Maximum: exp2(31.9921875f) ≈ 4.295e9 (very large number)+/
			
			Gradient step percentage analysis:
				/+Bullet: The 12-bit input gives 4096 discrete steps+/
				/+Bullet: The output range spans many orders of magnitude (1.0 to ~4.3e9)+/
				/+Bullet: The gradient step percentage varies dramatically across the range:+/
					/+Bullet: At low values (input near 0): ~0.7% change per step+/
					/+Bullet: At mid-range (input ~2048): ~100% change per step+/
					/+Bullet: At high values (input near 4095): extremely large percentage changes+/
			
			This creates an exponential encoding that provides:
				/+Bullet: High precision at low values+/
				/+Bullet: Very coarse steps at high values+/
			
			Would you like me to suggest alternative encodings or normalization approaches?
			
			/+Note: Usage(prompt_hit: 128, prompt_miss: 155, completion: 342, HUF: 0.15, price: 100%)+/
		+/
	+/
	/+
		AI: /+
			User: Please estimate high low ranges and gradient step percentage for:
			/+Code: exp2(float(fetchBits(bitStream, 8)) * 15.0+/
		+/
		/+
			Assistant: To estimate the high/low ranges and gradient step percentage for the given expression:
			
			/+Structured: exp2(float(fetchBits(bitStream, 8)) * 15.0)+/
			
			/+H3: Analysis:+/
			1. /+Bold: Input Range+/:
						/+Bullet: /+Highlighted: fetchBits(bitStream, 8)+/ returns an 8-bit unsigned integer → range [0, 255]+/
						/+Bullet: /+Highlighted: float()+/ conversion → [0.0f, 255.0f]+/
			
			2. /+Bold: Scaled Range+/:
						/+Bullet: Multiplied by 15.0 → [0.0f, 3825.0f]+/
			
			3. /+Bold: Final Output Range+/:
						/+Bullet: /+Highlighted: exp2(x)+/ applied → [exp2(0.0f), exp2(3825.0f)] ≈ [1.0f, Infinity]+/
			
			/+H3: Practical Considerations:+/
				/+Bullet: For real-world use, you likely want to constrain this to finite values+/
				/+Bullet: Maximum finite float32 value is ~3.4e38 (exp2(128.0) gives 3.4e38)+/
			
			/+H3: Suggested Ranges:+/
			/+
				Structured: /+ Recommended safe ranges +/
				const float minValue = 1.0f; 		/+ exp2(0.0) +/
				const float maxValue = 3.4e38f; 	/+ exp2(128.0) +/
				
				/+ Gradient step percentage suggestion +/
				const float stepPercent = 0.1f; 	/+ 10% steps for smooth interpolation +/
			+/
			
			/+H3: Modified Version with Clamping:+/
			/+
				Structured: /+ Safe version with clamping +/
				exp2(clamp(float(fetchBits(bitStream, 8)) * (15.0 / 255.0 * 128.0), 0.0f, 128.0f))
			+/
			
			This would give you:
				/+Bullet: Input: [0,255] → Scaled to [0,128] → exp2 range [1.0, 3.4e38]+/
			
			/+Note: Usage(prompt_hit: 128, prompt_miss: 154, completion: 409, HUF: 0.18, price: 100%)+/
		+/
	+/
	
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
			
			#define ErrorColor vec4(1, 0, 1, 1)
			#define LoadingColor vec4(1, 0, 1, 1)
			
			
			
			$(
				(表([
					[q{/+Note: Stage out+/},q{/+Note: Stage in+/},q{/+Note: Location 0+/},q{/+Note: Location 1+/},q{/+Note: Location 2+/}],
					[q{},q{vert},q{uvec4 vertAttr0},q{uvec4 vertAttr1}],
					[q{vert},q{geom},q{uvec4 geomAttr0},q{uvec4 geomAttr1},q{int geomVertexID}],
					[q{geom},q{frag},q{
						smooth
						vec4 fragColor
					},q{
						smooth
						vec2 fragTexCoord
					},q{
						flat
						uint fragTexHandle
					}],
					[q{frag},q{},q{vec4 outColor}],
				]))
				.GEN_ShaderLayoutDeclarations
			)
			
			
			@vert: 
			
			void main()
			{
				geomAttr0 	= vertAttr0, 
				geomAttr1 	= vertAttr1,
				geomVertexID	= gl_VertexIndex; 
			} 
			
			@geom: 
			$(ShaderBufferDeclarations)
			
			layout(points) in; 
			layout(triangle_strip, max_vertices = 32) out; 
			
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
				fragTexCoord = vec2(0,0); emitVertex2D(p); 
				fragTexCoord = vec2(0,1); emitVertex2D(p+vec2(0, size.y)); 
				fragTexCoord = vec2(1,0); emitVertex2D(p+vec2(size.x, 0)); 
				fragTexCoord = vec2(1,1); emitVertex2D(p+size); 
				EndPrimitive(); 
			} 
			
			void emitTexturedPointPointRect2D(in vec2 p, in vec2 q)
			{
				fragTexCoord = vec2(0,0); emitVertex2D(p); 
				fragTexCoord = vec2(0,1); emitVertex2D(vec2(p.x, q.y)); 
				fragTexCoord = vec2(1,0); emitVertex2D(vec2(q.x, p.y)); 
				fragTexCoord = vec2(1,1); emitVertex2D(q); 
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
			
			
			BitStream initBitStream(uint byteOfs)
			{
				BitStream bitStream; 
				bitStream.dwOfs = byteOfs >> 2; 
				bitStream.currentDwBits = 0; 
				uint bitsToSkip = (byteOfs & 3) * 8; 
				if(bitsToSkip > 0)
				{ uint dummy = fetchBits(bitStream, bitsToSkip); }
				return bitStream; 
			} 
			
			$(GEN_enumDefines!VertexCmd)
			
			uint fontTexFlags = 0; 
			$(FontTexFlags.GLSLCode)
			
			/*Vector graphics state registers*/
			vec4 PC = vec4(0, 0, 0, 1); 	/* Primary color - default black */
			vec4 SC = vec4(1, 1, 1, 1); 	/* Secondary color - default white */
				
			float PS = 1; 	/* Point size */
			float LW = 1; 	/* Line width */
			float DS = 1; 	/* Dash size scaling factor */
			float FH = 18; 	/* Font height */
				
			uint FMH = 0; 	/* Font map handle */
			uint LFMH = 0; 	/* Latin font map handle */
			uint PALH = 0; 	/* Palette handle */
			uint LTH = 0; 	/* Line texture handle */
				
			vec3 P = vec3(0); 	/* Position */
			float Ph = 0; 	/* Phase coordinate */
			
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
					color.rgb = vec3(float(fetchBits(bitStream, bits)) / high); 
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
			
			vec3 fetchCoord(inout BitStream bitStream, uint format)
			{
				switch(format)
				{
					case 0: return fetch_vec3(bitStream); // full precision
					case 1: return vec3(fetch_vec2(bitStream), 0); // 2D coords
					case 2: return vec3(float(fetchBits(bitStream, 16)) / 65535.0); // normalized u16
					case 3: return vec3(float(fetchBits(bitStream, 8)) / 255.0); // normalized u8
					default: return vec3(0); 
				}
			} 
			
			$(GEN_enumDefines!OpCat)
			$(GEN_enumDefines!OpCode)
			
			void processRegisterCommand(inout BitStream bitStream, uint opcode)
			{
				/*
					Register setter opcodes 
					Uses 4-bit opcodes (0x0-0xF)
					Format: opcode (4 bits) | format (4 bits) | data...
				*/
				
				const uint opCat = fetchBits(bitStream, 3); 
				switch(opCat)
				{
					case OpCat_system: 	{}	break; 
					case OpCat_setColor: 	{}	break; 
					case OpCat_setSize: 	{}	break; 
					case OpCat_setHandle: 	{}	break; 
					case OpCat_reserved4: 	{}	break; 
					case OpCat_reserved5: 	{}	break; 
					case OpCat_reserved6: 	{}	break; 
					case OpCat_reserved7: 	{}	break; 
				}
				
				
				uint format = fetchBits(bitStream, 4); 
				switch(opcode)
				{
					/* Color registers */
					case Opcode_setPC: //set promary color
						fetchColor(bitStream, format, PC); 
						break; 
						
					case Opcode_setSC: //set secondary color
						fetchColor(bitStream, format, SC); 
						break; 
						
					case Opcode_setPCSC: //set both color regs
						fetchColor(bitStream, format, PC); 
						fetchColor(bitStream, format, SC); 
						break; 
						
					case Opcode_setC: //broadcast to both color regis
						{
						const int chg = fetchColor(bitStream, format, PC); 
						if((chg&1)!=0) SC.rgb = PC.rgb; 
						if((chg&2)!=0) SC.a = PC.a; 
					}
						break; 
					
					/* Size registers */
					case 0x4: // setPS
						PS = fetchSize(bitStream, format); 
						break; 
						
					case 0x5: // setLW
						LW = fetchSize(bitStream, format); 
						break; 
						
					case 0x6: // setDS
						DS = fetchSize(bitStream, format); 
						break; 
						
					case 0x7: // setFH
						FH = fetchSize(bitStream, format); 
						break; 
					
					/* Handle registers */
					case 0x8: // setFontMap
						{
						uint handle = fetchHandle(bitStream, format); 
						uint fontType = fetchBits(bitStream, 2); 
						FMH = handle; 
						// Additional font type processing if needed
					}
						break; 
						
					case 0x9: // setLatinFontMap
						LFMH = fetchHandle(bitStream, format); 
						break; 
						
					case 0xA: // setPalette
						PALH = fetchHandle(bitStream, format); 
						break; 
						
					case 0xB: // setLineTex
						LTH = fetchHandle(bitStream, format); 
						break; 
					
					/* Vector state */
					case 0xC: // setPosition
						P = fetchCoord(bitStream, format); 
						break; 
						
					case 0xD: // setPhase
						Ph = fetchCoord(bitStream, format).x; 
						break; 
						
					default: 
						/* Unknown opcode - handle error */
						break; 
				}
			} 
			
			void main() /*geometry shader*/
			{
				const uint vertexCmd = getBits(geomAttr0[0].x, 0, $(VertexCmdBits)); 
				
				switch(vertexCmd)
				{
					case VertexCmd_texturedRect: 
						{
						fragTexHandle = geomAttr0[0].x >> $(VertexCmdBits); 
						fragColor = unpackUnorm4x8(geomAttr0[0].y); 
						const uint gAddr = geomAttr0[0].z; 
						BitStream GS = initBitStream(gAddr); 
						emitTexturedPointPointRect2D(fetch_vec2(GS), fetch_vec2(GS)); 
					}
					break; 
				}
			} 
			
			@frag: 
			$(ShaderBufferDeclarations)
			
			$(TexSizeFormat.GLSLCode)
			
			vec4 readSample(in uint texIdx, in vec3 v, in bool preScale)
			{
				if(texIdx==0) return ErrorColor; 
				
				//fetch info dword 0
				const uint textDwIdx = texIdx * $(TexInfo.sizeof/4); 
				const uint info_0 = IB[textDwIdx+0]; 
				
				//handle 'error' and 'loading' flags
				if(getBits(info_0, $(FlagBitOfs), 2)!=0)
				{
					if(getBit(info_0, $(FlagBitOfs)))	return ErrorColor; 
					else	return LoadingColor; 
				}
				
				//decode dimensions, size
				const uint dim = getBits(info_0, $(DimBitOfs), $(DimBits)); 
				const uint info_1 = IB[textDwIdx+1]; 
				const uint _rawSize0 = getBits(info_0, 16, 16); 
				const uint _rawSize12 = info_1; 
				const ivec3 size = decodeDimSize(dim, _rawSize0, _rawSize12); 
				if(size.x==0 || size.y==0 || size.z==0) return ErrorColor; 
				
				//Clamp coordinates. Assume non-empty image.
				const ivec3 iv = ivec3 ((preScale)?(v * vec3(size)) :(v)); 
				const ivec3 clamped = max(min(iv, size-1), 0); 
				
				//Calculate flat index
				const uint i = calcFlatIndex(clamped, dim, size); 
				
				//Get chunkIdx from info rec
				const uint chunkIdx = IB[textDwIdx+2]; 
				const uint dwIdx = chunkIdx * $(HeapGranularity/4); 
				
				//decode format (chn, bpp, alt)
				const uint chn = getBits(info_0, $(FormatBitOfs), $(ChnBits)); 
				const uint bpp = getBits(info_0, $(FormatBitOfs + ChnBits), $(BppBits)); 
				const bool alt = getBit(info_0, $(FormatBitOfs+ChnBits+BppBits)); 
				
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
				const vec2 texCoordDx = dFdx(fragTexCoord); 
				const vec2 texCoordDy = dFdy(fragTexCoord); 
				for(int i=0; i<6; i++)
				{
					vec2 rooks = rooks6_offsets[i]; 
					vec2 tc = fragTexCoord + 	rooks.x * texCoordDx + 
						rooks.y * texCoordDy; 
					vec4 smp = readSample(fragTexHandle, vec3(tc, 0), true); 
					sum += smp; 
				}
				
				outColor = sum/6 * fragColor; 
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
						//uvec4 VertexData0
						binding	: 0, 
						location 	: 0,
						format	: mixin(舉!((VK_FORMAT_),q{R32G32B32A32_UINT})),
						offset	: 0
					})), mixin(體!((VkVertexInputAttributeDescription),q{
						//uvec4 VertexData1
						binding	: 0,
						location 	: 1,
						format	: mixin(舉!((VK_FORMAT_),q{R32G32B32A32_UINT})), 
						offset	: uvec4.sizeof,
					})),
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
						
						
						VB.upload; GB.upload; 
						
						{
							auto modelMatrix = mat4.identity; 
							const rotationAngle = 0 * QPS.value(10*second); 
							modelMatrix.translate(vec3(-274, -266, 0)); 
							modelMatrix.rotate(vec3(0, 0, 1), rotationAngle); 
							
							// Set up view
							auto viewMatrix = mat4.lookAt(vec3(0, 0, 500), vec3(0), vec3(0, 1, 0)); 
							
							// Set up projection
							auto projMatrix = mat4.perspective(swapchain.extent.width, swapchain.extent.height, 60, 0.1, 1000); 
							
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
						
						if(KeyCombo("Space").down)
						{ LOG(Texture.destroyedResidentTexHandles.stats); }
						
						
						IB.buffer.upload; 
						TB.buffer.upload; 
					}
					catch(Exception e) { ERR("Scene exception: ", e.simpleMsg); }
					//because buffers could grow, descriptors can change.
					recreateDescriptors; 
					
					device.waitIdle/+Wait for everything+/; /+Opt: STALL+/
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