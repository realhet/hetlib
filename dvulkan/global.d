/+
	+
		+ Contains global Vulkan function pointers, only if the DVulkanGlobalFunctions version is selected.
		+
		+ This file dynamically generates variables containing Vulkan function pointers using string mixins.
		+ Each function has their original name (ex. `dvulkan.global.vkGetInstanceProcAddr`).
		+
		+ If the `DVulkanGlobalFunctions` version is not specified, this module contains nothing.
	+
+/
module dvulkan.global;
version(DVulkanGlobalFunctions)
:

import std.algorithm;
import std.range;
import dvulkan.functions;
import dvulkan.types;

mixin(
	[VulkanFunctions.AllFuncs]
		.map!(name => "__gshared VulkanFunctions.PFN_"~name~" "~name~";\n")
		.join()
);

/// Loads instance initialization functions to the global variables.
/// See VulkanFunctions.loadInitializationFunctions.
void loadInitializationFunctions(VulkanFunctions.PFN_vkGetInstanceProcAddr getProcAddr)
{
	VulkanFunctions funcs;
	funcs.loadInitializationFunctions(getProcAddr);
	foreach(string name; VulkanFunctions.AllFuncs)
	{ mixin("if(funcs.NAME) NAME = funcs.NAME;".replace("NAME", name)); }
}

/// Loads all functions to the global variables.
/// See VulkanFunctions.loadInstanceFunctions.
void loadInstanceFunctions(VkInstance instance)
{
	VulkanFunctions funcs;
	funcs.vkGetInstanceProcAddr = vkGetInstanceProcAddr;
	funcs.loadInstanceFunctions(instance);
	foreach(string name; VulkanFunctions.AllFuncs)
	{ mixin("if(funcs.NAME) NAME = funcs.NAME;".replace("NAME", name)); }
}

/// Loads device-bound functions to the global variables.
/// See VulkanFunctions.loadDeviceFunctions.
void loadDeviceFunctions(VkDevice device)
{
	VulkanFunctions funcs;
	funcs.vkGetDeviceProcAddr = vkGetDeviceProcAddr;
	funcs.loadDeviceFunctions(device);
	foreach(string name; VulkanFunctions.AllFuncs)
	{ mixin("if(funcs.NAME) NAME = funcs.NAME;".replace("NAME", name)); }
}