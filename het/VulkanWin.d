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
			
			
			this()
			{
				//uniformDataPtr = (cast(UniformData*)(virtualAlloc(UniformData.sizeof))); 
				uniformMemoryBuffer = device.createMemoryBuffer
					(
					UniformData.sizeof/+Bug: alignment!!!+/, 
					mixin(舉!((VK_MEMORY_PROPERTY_),q{HOST_VISIBLE_BIT})), mixin(舉!((VK_BUFFER_USAGE_),q{UNIFORM_BUFFER_BIT}))
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
			vec3 actColor; 
			VertexData[] vertices; 
			
			void reset()
			{
				actColor = vec3(0); 
				vertices.clear; 
			} 
			
			
			void tri(Args...)(in Args args)
			{
				void emit(in vec3 pos)
				{ vertices ~= VertexData(pos, actColor); } 
				
				static foreach(i, A; Args)
				{
					static if(is(A==vec3)) emit(args[i]); 
					else static if(is(A==vec2)) emit(vec3(args[i], 0)); 
					else static if(is(A==RGB)) actColor = args[i].from_unorm; 
				}
			} 
			
			
			auto createAndUploadBuffer(T)(in T[] buff, in VK_BUFFER_USAGE_ usage)
			{
				//host accessible buffer
				auto stagingBuffer = device.createMemoryBuffer
					(buff, mixin(舉!((VK_MEMORY_PROPERTY_),q{HOST_VISIBLE_BIT})), mixin(舉!((VK_BUFFER_USAGE_),q{TRANSFER_SRC_BIT}))); 
				
				//gpu only buffer
				auto deviceBuffer = device.createMemoryBuffer
					(buff.sizeBytes, mixin(舉!((VK_MEMORY_PROPERTY_),q{DEVICE_LOCAL_BIT})), mixin(幟!((VK_BUFFER_USAGE_),q{usage | TRANSFER_DST_BIT}))); 
				
				//Allocate command buffer for copy operation
				auto copyCommandBuffer = new VulkanCommandBuffer(commandPool); 
				
				// Now copy data from host visible buffer to gpu only buffer
				with(copyCommandBuffer)
				record(
					mixin(舉!((VK_COMMAND_BUFFER_USAGE_),q{ONE_TIME_SUBMIT_BIT})),
					{ cmdCopyBuffer(stagingBuffer, deviceBuffer); }
				); 
				
				// Submit to queue
				queue.submit(copyCommandBuffer); 
				queue.waitIdle; //Opt: STALL
				
				copyCommandBuffer.destroy; 
				stagingBuffer.destroy; 
				
				return deviceBuffer; 
			} 
		} 
	}
	
	class StagingStorageBuffer
	{
		VulkanMemoryBuffer hostMemoryBuffer, deviceMemoryBuffer; 
		size_t initialSizeBytes, maxSizeBytes, bufferSizeBytes; 
		void* hostPtr; 
		
		this(size_t initialSizeBytes, size_t maxSizeBytes)
		{
			this.initialSizeBytes = initialSizeBytes, this.maxSizeBytes = maxSizeBytes; 
			
			bufferSizeBytes = initialSizeBytes; 
			hostMemoryBuffer = device.createMemoryBuffer
				(bufferSizeBytes, mixin(舉!((VK_MEMORY_PROPERTY_),q{HOST_VISIBLE_BIT})), mixin(幟!((VK_BUFFER_USAGE_),q{TRANSFER_SRC_BIT}))); 
			deviceMemoryBuffer = device.createMemoryBuffer
				(
				bufferSizeBytes, mixin(舉!((VK_MEMORY_PROPERTY_),q{DEVICE_LOCAL_BIT})), mixin(幟!((VK_BUFFER_USAGE_),q{
					TRANSFER_SRC_BIT | TRANSFER_DST_BIT | 
					STORAGE_BUFFER_BIT
				}))
			); 
			hostPtr = hostMemoryBuffer.map; 
		} 
		
		~this()
		{
			hostMemoryBuffer.free; 
			deviceMemoryBuffer.free; 
		} 
		
		/+
			Measurements: 
				CPU memset: 10 GB/s
					{ import core.stdc.string; memset(hostStorageMemoryBuffer.map 0xAA, storageBufferSizeBytes); }
				CPU <-> GPU transfer: 5.8 GB/sec
		+/
		
		void upload(in void[] data)
		{
			if(data.empty) return; 
			
			hostMemoryBuffer.write(data/+Bug: alignment!!!+/); 
			/+Opt: Should write directly to memory buffer, not copy!+/
			
			auto cb = new VulkanCommandBuffer(commandPool); 
			with(cb)
			record(
				mixin(舉!((VK_COMMAND_BUFFER_USAGE_),q{ONE_TIME_SUBMIT_BIT})),
				{
					cmdCopyBuffer(
						hostMemoryBuffer, deviceMemoryBuffer,
						VkBufferCopy(0, 0, bufferSizeBytes/+data.sizeBytes+//+Bug: alignment!!!+/)
					); 
				}
			); 
			queue.submit(cb); 
			queue.waitIdle; //Opt: STALL
			cb.destroy; 
		} 
	} 
	
	version(/+$DIDE_REGION IB     +/all)
	{
		enum TexFormat
		{
			l8,
			la8,
			rgb8,
			rgba8,
			bgr8,
			bgra8,
		} 
		
		struct TexInfo
		{ uint addr, type, width, height; } 
		
		InfoBufferManager IB; 
		class InfoBufferManager : StagingStorageBuffer
		{
			this()
			{
				super(
					16 << 10, 
					16 << 20
				); 
				
				upload([TexInfo.init].replicate(bufferSizeBytes/TexInfo.sizeof)); 
			} 
			
			~this()
			{} 
		} 
	}
	
	version(/+$DIDE_REGION SB     +/all)
	{
		StorageBufferManager SB; 
		class StorageBufferManager : StagingStorageBuffer
		{
			this()
			{
				super(
					initialSizeBytes 	=  64 << 10,
					maxSizeBytes 	= 512 << 20
				); 
			} 
			
			~this()
			{} 
			
			/+
				Measurements: 
					CPU memset: 10 GB/s
						{ import core.stdc.string; memset(hostStorageMemoryBuffer.map 0xAA, storageBufferSizeBytes); }
					CPU <-> GPU transfer: 5.8 GB/sec
			+/
		} 
	}
	
	void createShaderModules()
	{
		enum shaderBinary = 
		(碼!((位!()),iq{glslc -O},iq{
			#version 430
			
			layout(binding = 0) uniform UBO { mat4 mvp; } ubo; 
			
			layout(binding = 1) buffer SBO { uint sbo[]; }; 
			
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
			layout(points) in; 
			layout(points, max_vertices = 32) out; 
			
			
			void main()
			{
				gl_Position = ubo.mvp * vec4(geomPosition[0], 1.0); 
				fragColor = vec4(geomColor[0], 1.0); 
				fragColor = unpackUnorm4x8(sbo[0]); 
				EmitVertex(); 
			} 
			
			@frag: 
			
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
					descriptorCount : 1
				}))
			],1 /+maxSets+/
		); 
	}  void createDescriptorSet()
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
			1, SB.deviceMemoryBuffer, 
				mixin(舉!((VK_DESCRIPTOR_TYPE_),q{STORAGE_BUFFER}))
		); 
	} 
	
	void createGraphicsPipeline()
	{
		//Link: https://vulkan-tutorial.com/Drawing_a_triangle/Graphics_pipeline_basics/Shader_modules
		
		// This is for uniform buffers and samplers
		descriptorSetLayout = device.createDescriptorSetLayout
			(
			mixin(體!((VkDescriptorSetLayoutBinding),q{
				binding	: 0, descriptorType 	: mixin(舉!((VK_DESCRIPTOR_TYPE_),q{UNIFORM_BUFFER})),
				descriptorCount 	: 1, stageFlags 	: shaderModules.shaderStageFlagBits
			})), 
			mixin(體!((VkDescriptorSetLayoutBinding),q{
				binding	: 1, 	descriptorType 	: mixin(舉!((VK_DESCRIPTOR_TYPE_),q{STORAGE_BUFFER})),
				descriptorCount 	: 1, 	stageFlags 	: shaderModules.shaderStageFlagBits
			}))
		); 
		
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
	
	
	override void onInitializeGLWindow()
	{
		disableInternalRedraw = true /+Do nothing on WM_PAINT+/; 
		targetUpdateRate = 100000 /+No limit on minimum update interval+/; 
		
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
		
		UB = new UniformBufferManager; 
		VB = new VertexBufferManager; 
		SB = new StorageBufferManager; 
		
		createShaderModules; 
		createGraphicsPipeline; //also creates descriptorsetLayout and pipelineLayout
		
		createDescriptorPool; 
		createDescriptorSet; //needs: descriptorsetLayout, uniformBuffer
		
		if(0) VulkanInstance.dumpBasicStuff; 
	} 
	
	override void onFinalizeGLWindow()
	{
		device.waitIdle; 
		SB.free; VB.free; UB.free; 
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
					VB.reset; 
					
					internalUpdate; //this will call onUpdate()
					
					
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
					
					UB.uniformMemoryBuffer.flush; 
					
					SB.upload([(RGBA(255, 245, 70, 255)), (RGBA(0xFFFF00FF))]); 
					vertexMemoryBuffer = VB.createAndUploadBuffer(VB.vertices, mixin(幟!((VK_BUFFER_USAGE_),q{VERTEX_BUFFER_BIT}))); 
					device.waitIdle; //Opt: STALL
					
					commandBuffer = createCommandBuffer
						(
						swapchain.imageIndex, VB.vertices.length,
						vertexMemoryBuffer
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