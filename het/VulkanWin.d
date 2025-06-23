module vulkanwin; 

public import het.win, het.bitmap, het.vulkan; 

import core.stdc.string : memset; 

/+
	Code: (表([
		[q{/+Note: Limits/Cards+/},q{/+Note: MAX+/},q{/+Note: R9 Fury X+/},q{/+Note: R9 280+/},q{/+Note: GTX 1060+/},q{/+Note: RX 580+/},q{/+Note: RTX 5090+/},q{/+Note: RX 9070+/}],
		[q{maxPushConstantsSize},q{128},q{256},q{128},q{256},q{256},q{256},q{256}],
		[q{maxVertexInputAttributes},q{32},q{32},q{64},q{32},q{32},q{32},q{64}],
		[q{maxGeometryInputComponents},q{64},q{64},q{128},q{128},q{64},q{128},q{128}],
		[q{maxGeometryOutputComponents},q{128},q{128},q{128},q{128},q{128},q{128},q{128}],
		[q{maxGeometryOutputVertices},q{256},q{256},q{1024},q{1024},q{256},q{1024},q{256}],
		[q{maxGeometryTotalOutputComponents},q{1024},q{1024},q{16384},q{1024},q{1024},q{1024},q{1024}],
		[q{maxGeometryShaderInvocations},q{32},q{127},q{127},q{32},q{32},q{32},q{32}],
		[q{maxFragmentInputComponents},q{128},q{128},q{128},q{128},q{128},q{128},q{128}],
	]))
+/

class VulkanWindow: Window
{
	struct BufferSizeConfigs
	{ VulkanBufferSizeConfig VBConfig, IBConfig, TBConfig; } 
	
	BufferSizeConfigs bufferSizeConfigs =
	mixin(體!((BufferSizeConfigs),q{
		VBConfig : 	mixin(體!((VulkanBufferSizeConfig),q{
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
			struct 	 { uvec4 VA0, VA1; } 
			struct 	 {
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
			
			auto deviceMemoryBuffer() => buffer.deviceMemoryBuffer; 
			
			void rect(bounds2 bounds, TexHandle texHandle, RGBA color=(RGBA(0xFFFFFFFF)))
			{
				buffer.append
				(
					mixin(體!((VertexData),q{
						cmd 	: VertexCmd.texturedRect | texHandle.to!uint<<VertexCmdBits,
						bounds 	: bounds,
						color 	: color
					}))
				); 
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
	}
	
	version(/+$DIDE_REGION IB     +/all)
	{
		
		version(/+$DIDE_REGION TexInfo declarations+/all)
		{
			alias TexHandle = Typedef!(uint, 0, "TexHandle"); 
			
			enum DimBits 	= 2, 
			ChnBits 	= 2, 
			BppBits 	= 4, 
			DimBitOfs	= 6,
			TypeBitOfs 	= 8 /+inside info_dword[0]+/,
			TypeBits 	= ChnBits + BppBits + 1 /+alt+/; 
			
			enum TexDim {_1D, _2D, _3D} 	static assert(TexDim.max < 1<<DimBits); 
			enum _TexType_matrix = 
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
			static if((常!(bool)(0))) { pragma(msg, GEN_TexType); }
			mixin(GEN_TexType); 
			static assert(TexChn.max < 1<<ChnBits); static assert(TexBpp.max < 1<<BppBits); 
			static assert(TexType.max < 1<<TypeBits); 
			
			static string GEN_TexType()
			{
				version(/+$DIDE_REGION Process table cells, generate types+/all)
				{
					auto 	table = _TexType_matrix,
						bppCount = table.width-2,
						chnCount = table.rowCount; struct Type {
						string name; 
						int value, chn, bpp; 
					} Type[] types; 
					int chnVal(int chn) => table.headerColumnCell(chn+1).to!int; 
					int bppVal(int bpp) => table.headerCell(bpp+1).to!int; 
					void processCell(int bpp, int chn)
					{
						foreach(alt, n; table.cell(bpp+1, chn+1).split)
						types ~= Type(n, chn | (bpp<<2) | (!!alt<<6), chnVal(chn), bppVal(bpp)); 
					} 
					foreach(bpp; 0..bppCount) foreach(chn; 0..chnCount) processCell(bpp, chn); 
				}
				
				return iq{
					enum TexType {$(types.map!"a.name~`=`~a.value.text".join(','))} 
					enum TexChn {$(chnCount.iota.map!((i)=>('_'~chnVal(i).text)).join(','))} 
					enum TexBpp {$(bppCount.iota.map!((i)=>('_'~bppVal(i).text)).join(','))} 
					enum texTypeChnVals 	= [$(types.map!q{a.chn.text}.join(','))],
					texTypeBppVals 	= [$(types.map!q{a.bpp.text}.join(','))]; 
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
				
				@property type() const => (cast(TexType)((*(cast(ulong*)(&this))).getBits(TypeBitOfs, TypeBits))); 
				@property type(TexType t) { auto p = (cast(ulong*)(&this)); *p = (*p).setBits(TypeBitOfs, TypeBits, t); } 
				
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
					$(GEN_enumDefines!TexType)
					$(GEN_enumDefines!TexChn)
					$(GEN_enumDefines!TexBpp)
					$(SharedCode.replace("TexDim._", "TexDim_"))
				}.text; 
				static protected { mixin(SharedCode); } 
				
				@property ivec3 size() const
				=> decodeDimSize(dim, _rawSize0, _rawSize12); 
				@property size(int a)
				{ dim = TexDim._1D; _rawSize0 = 0; _rawSize12 = a; } 
				@property size(ivec2 a)
				{ dim = TexDim._2D; _rawSize0 = a.x & 0xFFFF; _rawSize12 = ((a.x>>16) & 0xFF) | (a.y << 8); } 
				@property size(ivec3 a)
				{ dim = TexDim._3D; _rawSize0 = a.x; _rawSize12 = (a.y & 0xFFFF) | (a.z << 16); } 
				
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
				=> i"TexSizeFormat($(type), $(size.x) x $(size.y) x $(size.z)$(error?", ERR":"")$(loading?", LD":"")$(resident?", RES":""))".text; 
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
					auto _間=init間; 
				buffer = new HeapBuffer
					(device, queue, commandPool, mixin(幟!((VK_BUFFER_USAGE_),q{STORAGE_BUFFER_BIT})), mixin(舉!((bufferSizeConfigs),q{TBConfig}))); 	((0x430582886ADB).檢((update間(_間)))); 
				
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
					fmt.type = TexType.rgba_u8; 
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
						switch(bmp.type)
						{
							case "ubyte": 	switch(bmp.channels)
							{
								case 1: 	fmt.type = TexType.u8; 	data = bmp.getRaw; 	break; 
								case 2: 	fmt.type = TexType.rg_u8; 	data = bmp.getRaw; 	break; 
								case 3: 	fmt.type = TexType.rgb_u8; 	data = bmp.getRaw; 	break; 
								case 4: 	fmt.type = TexType.rgba_u8; 	data = bmp.getRaw; 	break; 
								default: 	unsupported; 
							}	break; 
							case "float": 	switch(bmp.channels)
							{
								case 1: 	fmt.type = TexType.f32; 	data = bmp.getRaw; 	break; 
								case 2: 	fmt.type = TexType.rg_f32; 	data = bmp.getRaw; 	break; 
								case 3: 	fmt.type = TexType.rgb_f32; 	data = bmp.getRaw; 	break; 
								case 4: 	fmt.type = TexType.rgba_f32; 	data = bmp.getRaw; 	break; 
								default: 	unsupported; 
							}	break; 
							case "ushort": 	switch(bmp.channels)
							{
								case 1: 	fmt.type = TexType.u16; 	data = bmp.getRaw; 	break; 
								case 2: 	fmt.type = TexType.rg_u16; 	data = bmp.getRaw; 	break; 
								case 3: 	fmt.type = TexType.rgb_u16; 	data = bmp.getRaw; 	break; 
								case 4: 	fmt.type = TexType.rgba_u16; 	data = bmp.getRaw; 	break; 
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
			
			void remove(File file)
			{
				if(const texRec = file in texRecByFile)
				{
					if(const texHandle = texRec.texHandle)
					{
						if(const heapChunkIdx = IB.access(texHandle).heapChunkIdx)
						{ buffer.heapFree(heapChunkIdx); }
						IB.remove(texHandle); 
					}
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
			
			$(GEN_enumDefines!VertexCmd)
			
			void main()
			{
				const uint 	vertexCmd = getBits(geomAttr0[0].x, 0, $(VertexCmdBits)); 
				
				switch(vertexCmd)
				{
					case VertexCmd_texturedRect: 
						{
						fragTexHandle = geomAttr0[0].x >> $(VertexCmdBits); 
						fragColor = unpackUnorm4x8(geomAttr0[0].y); 
						emitTexturedPointPointRect2D(
							uintBitsToFloat (geomAttr1[0].xy),
							uintBitsToFloat (geomAttr1[0].zw)
						); 
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
				if(getBits(info_0, 0, 2)!=0)
				{
					if(getBit(info_0, 0))	return ErrorColor; 
					else	return LoadingColor; 
				}
				
				//decode dimensions, size
				const uint dim = getBits(info_0, $(DimBitOfs), $(DimBits)); 
				const uint info_1 = IB[textDwIdx+1]; 
				const uint _rawSize0 = getBits(info_0, 16, 16); 
				const uint _rawSize12 = info_1; 
				const ivec3 size = decodeDimSize(dim, _rawSize0, _rawSize12); 
				
				//Clamp coordinates. Assume non-empty image.
				const ivec3 iv = ivec3 ((preScale)?(v * vec3(size)) :(v)); 
				const ivec3 clamped = max(min(iv, size-1), 0); 
				
				//Calculate flat index
				const uint i = calcFlatIndex(clamped, dim, size); 
				
				//Get chunkIdx from info rec
				const uint chunkIdx = IB[textDwIdx+2]; 
				const uint dwIdx = chunkIdx * $(HeapGranularity/4); 
				
				//decode type (chn, bpp, alt)
				const uint chn = getBits(info_0, $(TypeBitOfs), $(ChnBits)); 
				const uint bpp = getBits(info_0, $(TypeBitOfs + ChnBits), $(BppBits)); 
				const bool alt = getBit(info_0, $(TypeBitOfs+ChnBits+BppBits)); 
				
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
						case TexBpp_32: 	{ res = vec4(vec3(uintBitsToFloat(tmp.x)                 ), 1); }	break; 
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
					descriptorCount : 2
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
		); 
	} enum ShaderBufferDeclarations = 
	iq{
		//UB: Uniform buffer
		layout(binding = 0) uniform UB_T { mat4 mvp; } UB; 
		
		//IB: Info buffer
		layout(binding = 1) buffer IB_T { uint IB[]; } ; 
		
		//TB: Texture buffer
		layout(binding = 2) buffer TB_T { uint TB[]; } ; 
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
			IB	= new InfoBufferManager,
			TB	= new TextureBufferManager
		]; 
		
		createShaderModules; 
		createGraphicsPipeline; //also creates descriptorsetLayout and pipelineLayout
		
		createDescriptorPool; 
		createDescriptorSet; //needs: descriptorsetLayout, uniformBuffer
		
		if(0) VulkanInstance.dumpBasicStuff; 
		
		if(1)
		{
			console.hide; 
			{
				TexSizeFormat fmt; 
				
				fmt.size = ivec2(24, 21); 
				fmt.type = TexType.wa_u1; 
				
				const ubyte[] data = 
				[
					0,127,0,
					1,255,192,
					3,255,224,
					3,231,224,
					7,217,240,
					7,223,240,
					7,217,240,
					3,231,224,
					3,255,224,
					3,255,224,
					2,255,160,
					1,127,64,
					1,62,64,
					0,156,128,
					0,156,128,
					0,73,0,
					0,73,0,
					0,62,0,
					0,62,0,
					0,62,0,
					0,28,0
				]; 
				
				const texHandle = TB.createHandleAndSetData(fmt, data.swapBits); 
				
				const texInfo = IB.buffer[texHandle.to!uint]; 
				((0xABAC82886ADB).檢(texInfo)); 
				auto ptr = (cast(ubyte*)(TB.buffer.hostPtr)) + texInfo.heapChunkIdx.to!uint * HeapGranularity; 
				((0xAC3882886ADB).檢 (ptr[0..3*21])); 
			}
			
			{
				TexSizeFormat fmt; 
				
				fmt.size = ivec2(24/2, 21); 
				fmt.type = TexType.wa_u2; 
				
				const ubyte[] data = 
				[
					0,170,0,
					2,170,128,
					10,170,160,
					10,170,160,
					42,170,168,
					43,170,232,
					47,235,250,
					175,235,250,
					173,235,122,
					173,235,122,
					171,170,234,
					170,170,170,
					170,170,170,
					170,170,170,
					170,170,170,
					170,170,170,
					170,170,170,
					162,138,138,
					162,138,138,
					128,130,2,
					128,130,2,
				]; 
				
				const texHandle = TB.createHandleAndSetData(fmt, data.swapBits); 
				
				const texInfo = IB.buffer[texHandle.to!uint]; 
				((0xAF0F82886ADB).檢(texInfo)); 
				auto ptr = (cast(ubyte*)(TB.buffer.hostPtr)) + texInfo.heapChunkIdx.to!uint * HeapGranularity; 
				((0xAF9B82886ADB).檢 (ptr[0..3*21])); 
			}
			
			{
				TexSizeFormat fmt; 
				
				fmt.size = ivec2(24/2, 21); 
				fmt.type = TexType.wa_u2; 
				
				const ubyte[] data = (cast(ubyte[])(
					x"91 3d c8 a5  65 91 3d 4c  26 09 a0 02  b1 3d c5 32
90 12 85 30  88 b1 3d 85  2f 88 b1 3d  a8 91 2f a9
ff c8 91 2f  a5 66 c5 32  90 19 a4 64  c8 b1 65 c9
ff f0 03 20  6b 1d a4 64  a5 3d 91 65"
				)).swapBits; 
				
				
				
				const texHandle = TB.createHandleAndSetData(fmt, data); 
				
				const texInfo = IB.buffer[texHandle.to!uint]; 
				((0xB1D282886ADB).檢(texInfo)); 
				auto ptr = (cast(ubyte*)(TB.buffer.hostPtr)) + texInfo.heapChunkIdx.to!uint * HeapGranularity; 
				((0xB25E82886ADB).檢 (ptr[0..3*21])); 
			}
			{
				TexSizeFormat fmt; 
				
				auto bmp = bitmaps[`c:\dl\zafira-is-a-hungarian-porn-actres-1.jpg`.File]; 
				auto img = bmp.access!RGB[876..$, 1123..$][0..38, 0..26]; 
				
				fmt.size = img.size; 
				fmt.type = TexType.rgb_u8; 
				
				const texHandle = TB.createHandleAndSetData(fmt, img.asArray); 
				
				const texInfo = IB.buffer[texHandle.to!uint]; 
				((0xB40D82886ADB).檢(texInfo)); 
				auto ptr = (cast(ubyte*)(TB.buffer.hostPtr)) + texInfo.heapChunkIdx.to!uint * HeapGranularity; 
				((0xB49982886ADB).檢 (ptr[0..img.asArray.length*3][0..50])); 
			}
			
		}
	} 
	
	override void onFinalizeGLWindow()
	{
		device.waitIdle; 
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
						VB.reset; 
						
						internalUpdate; //this will call onUpdate()
						
						VB.upload; 
						
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