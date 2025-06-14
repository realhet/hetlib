module vulkanwin; 

public import het.win, het.vulkan; 

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
	enum TB_heapGranularity = 16; 
	
	
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
		struct VertexData { vec3 pos; vec3 color; } 
		
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
			
			vec3 actColor; 
			
			void reset()
			{
				buffer.reset; 
				
				actColor = vec3(0); 
			} 
			
			void upload()
			{
				buffer.upload; 
				_uploadedVertexCount = (buffer.appendPos / VertexData.sizeof).to!uint; 
			} 
			
			auto deviceMemoryBuffer() => buffer.deviceMemoryBuffer; 
			
			
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
		} 
	}
	
	version(/+$DIDE_REGION IB     +/all)
	{
		
		version(/+$DIDE_REGION TexInfo declarations+/all)
		{
			alias TexHandle 	= Typedef!(uint, 0, "TexHandle"); 
			
			
			enum TexType
			{
				/+Note: bits↓+/  	/+Note: 1 ch+/	/+Note: 2 ch+/	/+Note: 3 ch+/	/+Note: 4 ch+/	
				/+Note:   1+/	u1,				
				/+Note:   2+/	u2,				
				/+Note:   4+/	u4,				
				/+Note:   8+/	u8,				
				/+Note:  16+/	u16,	rg_u8, 	rgb_u565,	rgba_u5551,	
				/+Note:  24+/			rgb_u8,		
				/+Note:  32+/	f32,			rgba_u8,	
				/+Note:  48+/			rgb_u16,		
				/+Note:  64+/		rg_f32,		rgba_u16,	
				/+Note:  96+/			rgb_f32,		
				/+Note: 128+/				rgba_f32	
			} 
			static assert(TexType.max < 1<<4); 
			
			enum TexEffect
			{
				none, 
				whiteAlpha, 
				redBlueSwap
			} 
			static assert(TexEffect.max < 1<<4); 
			
			enum TexDim
			{
				_1D, 
				_2D, 
				_3D,
			} 
			static assert(TexEffect.max < 1<<2); 
			
			struct TexSizeFormat
			{
				mixin((
					(表([
						[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
						[q{TexType},q{4},q{"type"},q{},q{/++/}],
						[q{TexEffect},q{4},q{"effect"},q{},q{/++/}],
						[q{TexDim},q{2},q{"dim"},q{},q{/++/}],
						[q{uint},q{6},q{"_unused"},q{},q{/++/}],
						[q{uint},q{16},q{"_rawSize0"},q{},q{/++/}],
						[q{uint},q{32},q{"_rawSize12"},q{},q{/++/}],
					]))
				).調!(GEN_bitfields)); 
				
				@property ivec3 size()
				=> dim.predSwitch(
					TexDim._1D, ivec3(_rawSize12, 1, 1),
					TexDim._2D, ivec3((_rawSize0 | ((_rawSize12 & 0xFF)<<16)), _rawSize12>>8, 1),
					TexDim._3D, ivec3(_rawSize0, _rawSize12 & 0xFFFF, _rawSize12>>16),
				); 
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
			} 
			static assert(TexSizeFormat.sizeof==8); 
			
			struct TexInfo
			{
				HeapChunkIdx heapChunkIdx; 
				uint extra; 
				TexSizeFormat SizeFormat; 
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
				enforce(!nullHandle); 
			} 
			
			~this()
			{ buffer.free; } 
			
			bool isValidHandle(in TexHandle handle) const
			=> handle.inRange(1, buffer.length); 
			
			TexHandle add(in TexInfo info) /+can throw+/
			{
				TexHandle handle; 
				if(!freeHandles.empty)	{
					handle = freeHandles.fetchBack; 
					buffer[(cast(uint)(handle))] = info; 
				}
				else	{ handle = buffer.append(info); }
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
			
			void modify(in TexHandle handle, in TexInfo info)
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
			alias HeapBuffer = VulkanHeapBuffer!TB_heapGranularity; 
			static struct TexRec
			{
				TexHandle texHandle; 	//index into IB (InfoBuffer) enties
				uint lastAccessed; 	//last application.tick value of most recent access
				DateTime modified; 	//last bitmap.modified value for automatic reload
			} 
			static assert(TexRec.sizeof==16); 
			
			protected HeapBuffer buffer; 
			protected TexRec[File] texRecByFileName; 
			
			this()
			{
					auto _間=init間; 
				buffer = new HeapBuffer
					(device, queue, commandPool, mixin(幟!((VK_BUFFER_USAGE_),q{STORAGE_BUFFER_BIT})), mixin(舉!((bufferSizeConfigs),q{TBConfig}))); 	((0x30E282886ADB).檢((update間(_間)))); 
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
			
			TexRec* access(File file, in Flag!"delayed" fDelayed)
			{
				const delayed = fDelayed && EnableMultiThreadedTextureLoading; 
				auto bmp = bitmaps(file, delayed ? Yes.delayed : No.delayed, ErrorHandling.ignore); 
				//Opt: this synchronized call is slow. Should make a very fast cache storing images accessed in the current frame.
				
				if(auto existing = file in byFileName)
				{
					if(bmp.modified == existing.modified)
					{
						return existing; //existing texture and matching modified datetime
					}
					
					const 	texHandle 	= existing.texHandle,
						texInfo	= IB.access(texHandle); 
					buffer.heapFree(texInfo.heapChunkIdx); 
					IB.remove(texHandle); 
				}
				
				
				itt tartok; 
				
				auto idx = createSubTex(bmp); 
				byFileName[file] = idx; 
				bitmapModified[file] = modified; 
				return idx; 
			} 
			
			void remove(File file)
			{
				if(auto texRec = file in byFileName)
				{
					remove(texRec.texHandle); 
					
				}
			} 
			
		} 
	}
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	void createShaderModules()
	{
		enum shaderBinary = 
		(碼!((位!()),iq{glslc -O},iq{
			#version 430
			
			$(GEN_enumDefines!TexType)
			
			@vert: 
			layout(location = 0)
			in vec3 vertPosition; 	layout(location = 1)
			in vec3 vertColor; 
				
			layout(location = 0)
			out vec3 geomPosition; 	layout(location = 1)
			out vec3 geomColor; 
			@geom: 	
			layout(location = 0)
			in vec3 geomPosition[]; 	layout(location = 1)
			in vec3 geomColor[]; 
			
			layout(location = 0)
			flat out vec4 fragColor; 
			@frag: 
			layout(location = 0)
			flat in vec4 fragColor; 
			
			layout(location = 0)
			out vec4 outColor; 
			
			@common: 
			
			@vert: 
			
			void main()
			{ geomPosition = vertPosition, geomColor = vertColor; } 
			
			@geom: 
			$(ShaderBufferDeclarations); 
			
			layout(points) in; 
			layout(points, max_vertices = 32) out; 
			
			
			void main()
			{
				gl_Position = UB.mvp * vec4(geomPosition[0], 1.0); 
				fragColor = vec4(geomColor[0], 1.0); 
				//fragColor = unpackUnorm4x8(TB[IB[0]]); 
				fragColor = vec4(1, 0, 1, 1); 
				EmitVertex(); 
			} 
			
			@frag: 
			$(ShaderBufferDeclarations); 
			
			void main() { outColor = fragColor; } 
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
		layout(binding = 1) buffer IB_T { uint IB[]; }; 
		
		//TB: Texture buffer
		layout(binding = 2) buffer TB_T { uint TB[]; }; 
		
		void _dummy_declaration()
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
						//vec3 position (.z is 0)
						binding	: 0, 
						location 	: 0,
						format	: mixin(舉!((VK_FORMAT_),q{R32G32B32_SFLOAT})),
						offset	: 0
					})), mixin(體!((VkVertexInputAttributeDescription),q{
						//vec3 color
						binding	: 0,
						location 	: 1,
						format	: mixin(舉!((VK_FORMAT_),q{R32G32B32_SFLOAT})), 
						offset	: float.sizeof * 3,
					})),
				]
			),
			
			mixin(體!((VkPipelineInputAssemblyStateCreateInfo),q{
				topology 	: mixin(舉!((VK_PRIMITIVE_TOPOLOGY_),q{POINT_LIST})),
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
							const rotationAngle = QPS.value(10*second); 
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