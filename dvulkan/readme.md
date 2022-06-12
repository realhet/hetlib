D-Vulkan
========

Automatically-generated D bindings for Vulkan.

Usage with Function Pointers Struct
-----------------------------------

D-Vulkan, at its core, does not load functions into global variables, like similar bindings do.
Instead, functions are loaded into a `VulkanFunctions` structure. This is because Vulkan functions
are inherently tied to the instance, or device, that they were loaded from. For example, global
variables would make using the device-specific functions impossible to use with multiple devices.

To use the `VulkanFunctions` struct:

1. Import via `import dvulkan;`.
2. Get a pointer to the `vkGetInstanceProcAddr`, through platform-specific means (ex. loading the
   Vulkan shared library, using the Derelict loader, or `glfwGetInstanceProcAddress` if using GLFW).
3. Define a `VulkanFunctions` structure somewhere (ex. on the stack via `VulkanFunctions funcs;`)
3. Call `VulkanFunctions.loadInitializationFunctions(getProcAddr)`, where `getProcAddr` is the
   address of the loaded `vkGetInstanceProcAddr` function, to load the following functions:
	* `vkGetInstanceProcAddr` (sets the function from the passed value)
	* `vkCreateInstance`
	* `vkEnumerateInstanceExtensionProperties`
	* `vkEnumerateInstanceLayerProperties`
4. Create a `VkInstance` using the above functions.
5. Call `VulkanFunctions.loadInstanceFunctions(instance)` to load the rest of the functions.
6. (Optional) Call `VulkanFunctions.loadDeviceFunctions(device)` once you have a `VkDevice` to load
   specific functions for a device.

For your convenience, the `VulkanFunctions` structure includes the fields `instance` and `device`,
that are set whenever `loadInstanceFunctions` and `loadDeviceFunctions` are called, respectively.

Note that the `VulkanFunctions` struct is fairly large; be sure, if you are passing it around, to
pass by reference or pointer.

Usage with Global Functions
---------------------------

For convenience, when the `DVulkanGlobalFunctions` version is set (it is set in the default
configuration), D-Vulkan will generate global variables holding Vulkan functions.

To use the global functions, follow the steps for using the `VulkanFunctions` struct, but instead of
using the `VulkanFunctions.load*Functions` member functions, use the `dvulkan.global.load*Functions`
global functions instead.

Differences from C Vulkan
-------------------------

* `VK_NULL_HANDLE` **will not work.** The C Vulkan headers rely on the fact that 0 in C is implicitly
  convertible to the null pointer, but that is not the case in D. Instead, use the
  `VK_NULL_[NON_]DISPATCHABLE_HANDLE` constants (as approprate for the type) or `VkType.init`
  (where `Type` is the type to get a null handle for).
* All structures have their `sType` field set to the appropriate value upon initialization; explicit
  initialization is not needed.
* Without the `DVulkanGlobalEnums` version (on by default), Vulkan enums must be prefixed by their
  type, as they are defined as D enums (ex. `VkResult.VK_SUCCESS`).
* `VkPipelineShaderStageCreateInfo.module` has been renamed to
  `VkPipelineShaderStageCreateInfo._module`, since `module` is a D keyword.
* The `VK_KHR_*_surface` extensions are not yet implemented, as they require types from external
  libraries (X11, XCB, ...). They can be manually loaded with `vkGetInstanceProcAddr` if needed.

Configurations
--------------

D-Vulkan has two configurations, settable via the `subConfigurations` dub option

* __default__: The default. Sets the versions `DVulkanDerelict`, `DVulkanAllExtensions`,
  `DVulkanGlobalEnums`, and `DVulkanGlobalFunctions` (see below), and includes `derelict-util`.
* __bare__: No versions are set, you must specify what you want manually (usually at least
  `DVulkan_VK_VERSION_1_0`).

Versions
--------

D-Vulkan has several versions, settable via the `versions` dub option.

* `DVulkanGlobalEnums`: Defines global aliases for all enumerations.
* `DVulkanGlobalFunctions`: Generates global function pointers for Vulkan functions.
* `DVulkanDerelict`: Includes a small loader for the Vulkan shared library using `derelict-util`.
  When using this version with the `bare` config, you must add `derelict-util` to your dependencies.
* `DVulkan_(EXT)`: Where `(EXT)` is an Vulkan version or extension name (ex. `VK_VERSION_1_0` or
  `VK_KHR_swapchain`), generates bindings 

Examples
--------

Examples can be found in the `examples` directory, and ran with `dub run d-vulkan:examplename`.

Derelict Loader
---------------

D-Vulkan includes a small loader using `derelict-util` to load the Vulkan shared library when the
`DVulkanDerelict` version is defined.

To use it, call `DVulkanDerelict.load()`, then either `DVulkanDerelict.getInitializationFunctions()`,
which returns a `VulkanFunctions` struct containing the initialization functions loaded by
`VulkanFunctions.getInitializationFunctions`, or, if `DVulkanGlobalFunctions` is also specified,
`DVulkanDerelict.loadInitializationFunctions()` to load the same functions to the global variables.

Examples
--------

Two examples can be found in the `examples` directory, and can be ran with
`dub run d-vulkan:examplename`.

devices: Lists devices. Uses the derelict loader.

layers: Lists available layers. Uses the derelict loader, global enums, and whitelisted extension
loading.

Generating Bindings
-------------------

To generate bindings, download the [Vulkan-Docs](https://github.com/KhronosGroup/Vulkan-Docs) repo,
copy/move/symlink `vkdgen.py` into `src/spec/`, `cd` there, and execute it, passing in an output
folder to place the D files. Requires Python 3.
