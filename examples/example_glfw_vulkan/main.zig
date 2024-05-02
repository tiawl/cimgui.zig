const std = @import ("std");
const builtin = @import ("builtin");

pub const c = @cImport ({
  @cDefine ("GLFW_INCLUDE_VULKAN", "1");
  @cDefine ("GLFW_INCLUDE_NONE", "1");
  @cInclude ("GLFW/glfw3.h");
  @cInclude ("cimgui.h");
  @cInclude ("backends/cimgui_impl_glfw.h");
  @cInclude ("backends/cimgui_impl_vulkan.h");
});

var g_Allocator:        *c.VkAllocationCallbacks   = undefined;
var g_Instance:         c.VkInstance               = undefined;
var g_PhysicalDevice:   c.VkPhysicalDevice         = undefined;
var g_Device:           c.VkDevice                 = undefined;
var g_QueueFamily:      ?u32                       = null;
var g_Queue:            c.VkQueue                  = undefined;
var g_DebugReport:      c.VkDebugReportCallbackEXT = undefined;
var g_PipelineCache:    c.VkPipelineCache          = undefined;
var g_DescriptorPool:   c.VkDescriptorPool         = undefined;

var g_MainWindowData:   c.ImGui_ImplVulkanH_Window = undefined;
var g_MinImageCount:    u32 = 2;
var g_SwapChainRebuild: bool = false;

const required_layers = [_][*:0] const u8 { "VK_LAYER_KHRONOS_validation", };

fn get_vulkan_instance_func (comptime PFN: type, instance: c.VkInstance, name: [*c] const u8) PFN
{
  return @ptrCast (c.glfwGetInstanceProcAddress (instance, name));
}

fn get_vulkan_device_func (comptime PFN: type, device: c.VkDevice, name: [*c] const u8) PFN
{
  const vkGetDeviceProcAddr = get_vulkan_instance_func (c.PFN_vkGetDeviceProcAddr, g_Instance, "vkGetDeviceProcAddr").?;
  return @ptrCast (vkGetDeviceProcAddr (device, name));
}

fn vkEnumerateInstanceExtensionProperties (name: [*c] const u8, count: [*c] u32, properties: [*c] c.VkExtensionProperties) c.VkResult
{
  const func = get_vulkan_instance_func (c.PFN_vkEnumerateInstanceExtensionProperties, null, "vkEnumerateInstanceExtensionProperties").?;
  return func (name, count, properties);
}

fn vkEnumerateInstanceLayerProperties (count: [*c] u32, properties: [*c] c.VkLayerProperties) c.VkResult
{
  const func = get_vulkan_instance_func (c.PFN_vkEnumerateInstanceLayerProperties, null, "vkEnumerateInstanceLayerProperties").?;
  return func (count, properties);
}

fn vkCreateInstance (info: [*c] const c.VkInstanceCreateInfo, allocator: [*c] const c.VkAllocationCallbacks, instance: [*c] c.VkInstance) c.VkResult
{
  const func = get_vulkan_instance_func (c.PFN_vkCreateInstance, null, "vkCreateInstance").?;
  return func (info, allocator, instance);
}

fn vkEnumerateDeviceExtensionProperties (physical_device: c.VkPhysicalDevice, name: [*c] const u8, count: [*c] u32, properties: [*c] c.VkExtensionProperties) c.VkResult
{
  const func = get_vulkan_instance_func (c.PFN_vkEnumerateDeviceExtensionProperties, null, "vkEnumerateDeviceExtensionProperties").?;
  return func (physical_device, name, count, properties);
}

fn vkGetPhysicalDeviceSurfaceSupportKHR (physical_device: c.VkPhysicalDevice, index: u32, surface: c.VkSurfaceKHR, supported: [*c] c.VkBool32) c.VkResult
{
  const func = get_vulkan_instance_func (c.PFN_vkGetPhysicalDeviceSurfaceSupportKHR, g_Instance, "vkGetPhysicalDeviceSurfaceSupportKHR").?;
  return func (physical_device, index, surface, supported);
}

fn vkCreateDebugReportCallbackEXT (instance: c.VkInstance, debug_report_ci: [*c] const c.VkDebugReportCallbackCreateInfoEXT, allocator: [*c] const c.VkAllocationCallbacks, debug_report: [*c] c.VkDebugReportCallbackEXT) c.VkResult
{
  const func = get_vulkan_instance_func (c.PFN_vkCreateDebugReportCallbackEXT, instance, "vkCreateDebugReportCallbackEXT").?;
  return func (instance, debug_report_ci, allocator, debug_report);
}

fn vkGetPhysicalDeviceProperties (physical_device: c.VkPhysicalDevice, properties: [*c] c.VkPhysicalDeviceProperties) void
{
  const func = get_vulkan_instance_func (c.PFN_vkGetPhysicalDeviceProperties, g_Instance, "vkGetPhysicalDeviceProperties").?;
  func (physical_device, properties);
}

fn vkEnumeratePhysicalDevices (instance: c.VkInstance, count: [*c] u32, physical_devices: [*c] c.VkPhysicalDevice) c.VkResult
{
  const func = get_vulkan_instance_func (c.PFN_vkEnumeratePhysicalDevices, instance, "vkEnumeratePhysicalDevices").?;
  return func (instance, count, physical_devices);
}

fn vkGetPhysicalDeviceQueueFamilyProperties (physical_device: c.VkPhysicalDevice, count: [*c]u32, properties: [*c] c.VkQueueFamilyProperties) void
{
  const func = get_vulkan_instance_func (c.PFN_vkGetPhysicalDeviceQueueFamilyProperties, g_Instance, "vkGetPhysicalDeviceQueueFamilyProperties").?;
  func (physical_device, count, properties);
}

fn vkCreateDevice (physical_device: c.VkPhysicalDevice, info: [*c] const c.VkDeviceCreateInfo, allocator: [*c] const c.VkAllocationCallbacks, device: [*c] c.VkDevice) c.VkResult
{
  const func = get_vulkan_instance_func (c.PFN_vkCreateDevice, g_Instance, "vkCreateDevice").?;
  return func (physical_device, info, allocator, device);
}

fn vkDestroyInstance (instance: c.VkInstance, allocator: [*c] const c.VkAllocationCallbacks) void
{
  const func = get_vulkan_instance_func (c.PFN_vkDestroyInstance, instance, "vkDestroyInstance").?;
  func (instance, allocator);
}

fn vkAcquireNextImageKHR (device: c.VkDevice, swapchain: c.VkSwapchainKHR, timeout: u64, semaphore: c.VkSemaphore, fence: c.VkFence, index: [*c] u32) c.VkResult
{
  const func = get_vulkan_device_func (c.PFN_vkAcquireNextImageKHR, device, "vkAcquireNextImageKHR").?;
  return func (device, swapchain, timeout, semaphore, fence, index);
}

fn vkWaitForFences (device: c.VkDevice, count: u32, fences: [*c] const c.VkFence, wait: c.VkBool32, timeout: u64) c.VkResult
{
  const func = get_vulkan_device_func (c.PFN_vkWaitForFences, device, "vkWaitForFences").?;
  return func (device, count, fences, wait, timeout);
}

fn vkResetFences (device: c.VkDevice, count: u32, fences: [*c] const c.VkFence) c.VkResult
{
  const func = get_vulkan_device_func (c.PFN_vkResetFences, device, "vkResetFences").?;
  return func (device, count, fences);
}

fn vkGetDeviceQueue (device: c.VkDevice, family: u32, index: u32, queue: [*c] c.VkQueue) void
{
  const func = get_vulkan_device_func (c.PFN_vkGetDeviceQueue, device, "vkGetDeviceQueue").?;
  func (device, family, index, queue);
}

fn vkCreateDescriptorPool (device: c.VkDevice, info: [*c] const c.VkDescriptorPoolCreateInfo, allocator: [*c] const c.VkAllocationCallbacks, descriptor_pool: [*c] c.VkDescriptorPool) c.VkResult
{
  const func = get_vulkan_device_func (c.PFN_vkCreateDescriptorPool, device, "vkCreateDescriptorPool").?;
  return func (device, info, allocator, descriptor_pool);
}

fn vkCmdBeginRenderPass (command_buffer: c.VkCommandBuffer, info: [*c] const c.VkRenderPassBeginInfo, contents: c.VkSubpassContents) void
{
  const func = get_vulkan_device_func (c.PFN_vkCmdBeginRenderPass, g_Device, "vkCmdBeginRenderPass").?;
  func (command_buffer, info, contents);
}

fn vkCmdEndRenderPass (command_buffer: c.VkCommandBuffer) void
{
  const func = get_vulkan_device_func (c.PFN_vkCmdEndRenderPass, g_Device, "vkCmdEndRenderPass").?;
  func (command_buffer);
}

fn vkEndCommandBuffer (command_buffer: c.VkCommandBuffer) c.VkResult
{
  const func = get_vulkan_device_func (c.PFN_vkEndCommandBuffer, g_Device, "vkEndCommandBuffer").?;
  return func (command_buffer);
}

fn vkQueueSubmit (queue: c.VkQueue, count: u32, info: [*c] const c.VkSubmitInfo, fence: c.VkFence) c.VkResult
{
  const func = get_vulkan_device_func (c.PFN_vkQueueSubmit, g_Device, "vkQueueSubmit").?;
  return func (queue, count, info, fence);
}

fn vkResetCommandPool (device: c.VkDevice, command_pool: c.VkCommandPool, flags: c.VkCommandPoolResetFlags) c.VkResult
{
  const func = get_vulkan_device_func (c.PFN_vkResetCommandPool, device, "vkResetCommandPool").?;
  return func (device, command_pool, flags);
}

fn vkBeginCommandBuffer (command_buffer: c.VkCommandBuffer, info: [*c] const c.VkCommandBufferBeginInfo) c.VkResult
{
  const func = get_vulkan_device_func (c.PFN_vkBeginCommandBuffer, g_Device, "vkBeginCommandBuffer").?;
  return func (command_buffer, info);
}

fn vkQueuePresentKHR (queue: c.VkQueue, info: [*c] const c.VkPresentInfoKHR) c.VkResult
{
  const func = get_vulkan_device_func (c.PFN_vkQueuePresentKHR, g_Device, "vkQueuePresentKHR").?;
  return func (queue, info);
}

fn vkDeviceWaitIdle (device: c.VkDevice) c.VkResult
{
  const func = get_vulkan_device_func (c.PFN_vkDeviceWaitIdle, device, "vkDeviceWaitIdle").?;
  return func (device);
}

fn vkDestroyDescriptorPool (device: c.VkDevice, descriptor_pool: c.VkDescriptorPool, allocator: [*c] const c.VkAllocationCallbacks) void
{
  const func = get_vulkan_device_func (c.PFN_vkDestroyDescriptorPool, device, "vkDestroyDescriptorPool").?;
  func (device, descriptor_pool, allocator);
}

fn vkDestroyDebugReportCallbackEXT (instance: c.VkInstance, debug_report: c.VkDebugReportCallbackEXT, allocator: [*c] const c.VkAllocationCallbacks) void
{
  const func = get_vulkan_instance_func (c.PFN_vkDestroyDebugReportCallbackEXT, instance, "vkDestroyDebugReportCallbackEXT").?;
  func (instance, debug_report, allocator);
}

fn vkDestroyDevice (device: c.VkDevice, allocator: [*c] const c.VkAllocationCallbacks) void
{
  const func = get_vulkan_device_func (c.PFN_vkDestroyDevice, device, "vkDestroyDevice").?;
  func (device, allocator);
}

fn loader (name: [*c] const u8, instance: ?*anyopaque) callconv (.C) ?*const fn () callconv (.C) void
{
  return c.glfwGetInstanceProcAddress (@ptrCast (instance), name);
}

fn glfw_error_callback (err: c_int, description: [*c] const u8) callconv (.C) void
{
  std.debug.print ("GLFW Error {d}: {s}\n", .{ err, description });
}

fn check_vk_result (err: c.VkResult) callconv (.C) void
{
  if (err == 0) return;
  std.debug.print ("[vulkan] Error: VkResult = {d}\n", .{ err });
  if (err < 0) std.process.exit (1);
}

fn debugReport (_: c.VkDebugReportFlagsEXT, objectType: c.VkDebugReportObjectTypeEXT, _: u64, _: usize, _: i32, _: ?*const u8, pMessage: ?[*:0] const u8, _: ?*anyopaque) callconv (.C) c.VkBool32
{
  std.debug.print ("[vulkan] Debug report from ObjectType: {any}\nMessage: {s}\n\n", .{ objectType, pMessage orelse "No message available" });
  return c.VK_FALSE;
}

fn IsExtensionAvailable (properties: [] const c.VkExtensionProperties, extension: [] const u8) bool
{
  for (0 .. properties.len) |i|
  {
    if (std.mem.eql (u8, &properties [i].extensionName, extension)) return true;
  } else return false;
}

fn IsLayerAvailable (layers: [] const c.VkLayerProperties, layer: [*:0] const u8) bool
{
  const span = std.mem.span (layer);
  for (0 .. layers.len) |i|
  {
    if (std.mem.eql (u8, layers [i].layerName [0 .. span.len], span)) return true;
  } else return false;
}

fn SetupVulkan_SelectPhysicalDevice (allocator: std.mem.Allocator) !c.VkPhysicalDevice
{
  var gpu_count: u32 = undefined;
  var err = vkEnumeratePhysicalDevices (g_Instance, &gpu_count, null);
  check_vk_result (err);

  const gpus = try allocator.alloc (c.VkPhysicalDevice, gpu_count);
  err = vkEnumeratePhysicalDevices (g_Instance, &gpu_count, gpus.ptr);
  check_vk_result(err);

  for (gpus) |device|
  {
    var properties: c.VkPhysicalDeviceProperties = undefined;
    vkGetPhysicalDeviceProperties (device, &properties);
    if (properties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) return device;
  }

  // Use first GPU (Integrated) is a Discrete one is not available.
  if (gpu_count > 0) return gpus [0];
  return error.NoPhysicalDeviceAvailable;
}

fn SetupVulkan (allocator: std.mem.Allocator, instance_extensions: *std.ArrayList ([*:0] const u8)) !void
{
  var err: c.VkResult = undefined;

  var app_info = c.VkApplicationInfo {};
  app_info.pApplicationName = "example_glfw_vulkan";
  app_info.applicationVersion = c.VK_API_VERSION_1_2;
  app_info.pEngineName = "No Engine";
  app_info.engineVersion = c.VK_API_VERSION_1_2;
  app_info.apiVersion = c.VK_API_VERSION_1_2;

  // Setup the debug report callback
  var debug_report_ci = c.VkDebugReportCallbackCreateInfoEXT {};
  debug_report_ci.sType = c.VK_STRUCTURE_TYPE_DEBUG_REPORT_CALLBACK_CREATE_INFO_EXT;
  debug_report_ci.flags = c.VK_DEBUG_REPORT_ERROR_BIT_EXT | c.VK_DEBUG_REPORT_WARNING_BIT_EXT | c.VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT;
  debug_report_ci.pfnCallback = debugReport;
  debug_report_ci.pUserData = null;

  // Create Vulkan Instance
  var create_info = c.VkInstanceCreateInfo {};
  create_info.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
  create_info.pApplicationInfo = &app_info;
  create_info.pNext = &debug_report_ci;

  // Enumerate available extensions
  var properties_count: u32 = undefined;
  _ = vkEnumerateInstanceExtensionProperties (null, &properties_count, null);
  const properties = try allocator.alloc (c.VkExtensionProperties, properties_count);
  err = vkEnumerateInstanceExtensionProperties (null, &properties_count, properties.ptr);
  check_vk_result (err);

  // Enable required extensions
  if (IsExtensionAvailable (properties [0 .. properties_count], c.VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME))
    try instance_extensions.append (c.VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME);

  // Enumerate available layers
  var layers_count: u32 = undefined;
  _ = vkEnumerateInstanceLayerProperties (&layers_count, null);
  const layers = try allocator.alloc (c.VkLayerProperties, layers_count);
  err = vkEnumerateInstanceLayerProperties (&layers_count, layers.ptr);
  check_vk_result (err);

  // Enable required layers
  if (!IsLayerAvailable (layers [0 .. layers_count], required_layers [0]))
    return error.RequiredLayerNotAvailable;

  // Enabling validation layers
  create_info.enabledLayerCount = required_layers.len;
  create_info.ppEnabledLayerNames = required_layers [0 ..].ptr;
  try instance_extensions.append ("VK_EXT_debug_report");

  // Create Vulkan Instance
  create_info.enabledExtensionCount = @intCast (instance_extensions.items.len);
  create_info.ppEnabledExtensionNames = instance_extensions.items.ptr;
  err = vkCreateInstance (&create_info, g_Allocator, &g_Instance);
  check_vk_result (err);

  err = vkCreateDebugReportCallbackEXT (g_Instance, &debug_report_ci, g_Allocator, &g_DebugReport);
  check_vk_result (err);

  // Select Physical Device (GPU)
  g_PhysicalDevice = try SetupVulkan_SelectPhysicalDevice (allocator);

  // Select graphics queue family
  var count: u32 = undefined;
  vkGetPhysicalDeviceQueueFamilyProperties (g_PhysicalDevice, &count, null);
  const queues = try allocator.alloc (c.VkQueueFamilyProperties, count);
  defer allocator.free (queues);
  vkGetPhysicalDeviceQueueFamilyProperties (g_PhysicalDevice, &count, queues.ptr);
  var i: u32 = 0;
  while (i < count)
  {
    if (queues [i].queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0)
    {
      g_QueueFamily = i;
      break;
    }
    i += 1;
  }

  // Create Logical Device (with 1 queue)
  var device_extensions = std.ArrayList ([*:0] const u8).init (allocator);
  try device_extensions.append ("VK_KHR_swapchain");

  // Enumerate physical device extension
  _ = vkEnumerateDeviceExtensionProperties (g_PhysicalDevice, null, &properties_count, null);
  const properties2 = try allocator.alloc (c.VkExtensionProperties, properties_count);
  _ = vkEnumerateDeviceExtensionProperties (g_PhysicalDevice, null, &properties_count, properties2.ptr);

  const queue_priority = [_] f32 { 1.0 };
  var queue_info = [1] c.VkDeviceQueueCreateInfo { .{} };
  queue_info [0].sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
  queue_info [0].queueFamilyIndex = g_QueueFamily.?;
  queue_info [0].queueCount = 1;
  queue_info [0].pQueuePriorities = &queue_priority;
  var device_create_info = c.VkDeviceCreateInfo {};
  device_create_info.sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  device_create_info.queueCreateInfoCount = queue_info.len;
  device_create_info.pQueueCreateInfos = &queue_info;
  device_create_info.enabledLayerCount = required_layers.len;
  device_create_info.ppEnabledLayerNames = required_layers [0 ..].ptr;
  device_create_info.enabledExtensionCount = @intCast (device_extensions.items.len);
  device_create_info.ppEnabledExtensionNames = device_extensions.items.ptr;
  err = vkCreateDevice (g_PhysicalDevice, &device_create_info, g_Allocator, &g_Device);
  check_vk_result (err);
  vkGetDeviceQueue (g_Device, g_QueueFamily.?, 0, &g_Queue);

  // Create Descriptor Pool
  // The example only requires a single combined image sampler descriptor for the font image and only uses one descriptor set (for that)
  // If you wish to load e.g. additional textures you may need to alter pools sizes.
  const pool_sizes = [_] c.VkDescriptorPoolSize
  {
    .{
       .@"type" = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
       .descriptorCount = 1,
     },
  };
  var pool_info = c.VkDescriptorPoolCreateInfo {};
  pool_info.sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
  pool_info.flags = c.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
  pool_info.maxSets = 1;
  pool_info.poolSizeCount = pool_sizes.len;
  pool_info.pPoolSizes = &pool_sizes;
  err = vkCreateDescriptorPool (g_Device, &pool_info, g_Allocator, &g_DescriptorPool);
  check_vk_result (err);
}

// All the ImGui_ImplVulkanH_XXX structures/functions are optional helpers used by the demo.
// Your real engine/app may not use them.
fn SetupVulkanWindow (wd: *c.ImGui_ImplVulkanH_Window, surface: c.VkSurfaceKHR, width: i32, height: i32) !void
{
  wd.Surface = surface;

  // Check for WSI support
  var res: c.VkBool32 = undefined;
  _ = vkGetPhysicalDeviceSurfaceSupportKHR (g_PhysicalDevice, g_QueueFamily.?, wd.Surface, &res);
  if (res != c.VK_TRUE) return error.NoWSISupport;

  // Select Surface Format
  const requestSurfaceImageFormat = [_] c.VkFormat { c.VK_FORMAT_B8G8R8A8_UNORM, c.VK_FORMAT_R8G8B8A8_UNORM, c.VK_FORMAT_B8G8R8_UNORM, c.VK_FORMAT_R8G8B8_UNORM };
  const ptrRequestSurfaceImageFormat: [*] const c.VkFormat = &requestSurfaceImageFormat;
  const requestSurfaceColorSpace = c.VK_COLORSPACE_SRGB_NONLINEAR_KHR;
  wd.SurfaceFormat = c.cImGui_ImplVulkanH_SelectSurfaceFormat (g_PhysicalDevice, wd.Surface, ptrRequestSurfaceImageFormat, requestSurfaceImageFormat.len, requestSurfaceColorSpace);

  // Select Present Mode
  const present_modes = [_] c.VkPresentModeKHR { c.VK_PRESENT_MODE_FIFO_KHR };
  wd.PresentMode = c.cImGui_ImplVulkanH_SelectPresentMode (g_PhysicalDevice, wd.Surface, &present_modes [0], present_modes.len);

  // Create SwapChain, RenderPass, Framebuffer, etc.
  c.cImGui_ImplVulkanH_CreateOrResizeWindow (g_Instance, g_PhysicalDevice, g_Device, wd, g_QueueFamily.?, g_Allocator, width, height, g_MinImageCount);
}

fn CleanupVulkan () void
{
  vkDestroyDescriptorPool (g_Device, g_DescriptorPool, g_Allocator);

  // Remove the debug report callback
  vkDestroyDebugReportCallbackEXT (g_Instance, g_DebugReport, g_Allocator);

  vkDestroyDevice (g_Device, g_Allocator);
  vkDestroyInstance (g_Instance, g_Allocator);
}

fn CleanupVulkanWindow () void
{
  c.cImGui_ImplVulkanH_DestroyWindow (g_Instance, g_Device, &g_MainWindowData, g_Allocator);
}

fn FrameRender (wd: *c.ImGui_ImplVulkanH_Window, draw_data: *c.ImDrawData) void
{
  var err: c.VkResult = undefined;

  var image_acquired_semaphore  = wd.FrameSemaphores [wd.SemaphoreIndex].ImageAcquiredSemaphore;
  var render_complete_semaphore = wd.FrameSemaphores [wd.SemaphoreIndex].RenderCompleteSemaphore;
  err = vkAcquireNextImageKHR (g_Device, wd.Swapchain, std.math.maxInt (u64), image_acquired_semaphore, null, &wd.FrameIndex);
  if (err == c.VK_ERROR_OUT_OF_DATE_KHR or err == c.VK_SUBOPTIMAL_KHR)
  {
    g_SwapChainRebuild = true;
    return;
  }
  check_vk_result (err);

  var fd = &wd.Frames [wd.FrameIndex];
  err = vkWaitForFences (g_Device, 1, &fd.Fence, c.VK_TRUE, std.math.maxInt (u64));    // wait indefinitely instead of periodically checking
  check_vk_result (err);

  {
    err = vkResetFences (g_Device, 1, &fd.Fence);
    check_vk_result (err);
    err = vkResetCommandPool (g_Device, fd.CommandPool, 0);
    check_vk_result (err);
    var info = c.VkCommandBufferBeginInfo {};
    info.sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    info.flags |= c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    err = vkBeginCommandBuffer (fd.CommandBuffer, &info);
    check_vk_result (err);
  }{
    var info = c.VkRenderPassBeginInfo {};
    info.sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    info.renderPass = wd.RenderPass;
    info.framebuffer = fd.Framebuffer;
    info.renderArea.extent.width = @intCast (wd.Width);
    info.renderArea.extent.height = @intCast (wd.Height);
    info.clearValueCount = 1;
    info.pClearValues = &wd.ClearValue;
    vkCmdBeginRenderPass (fd.CommandBuffer, &info, c.VK_SUBPASS_CONTENTS_INLINE);
  }

  // Record dear imgui primitives into command buffer
  c.cImGui_ImplVulkan_RenderDrawData (draw_data, fd.CommandBuffer);

  // Submit command buffer
  vkCmdEndRenderPass (fd.CommandBuffer);
  {
    var wait_stage: c.VkPipelineStageFlags = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    var info = c.VkSubmitInfo {};
    info.sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO;
    info.waitSemaphoreCount = 1;
    info.pWaitSemaphores = &image_acquired_semaphore;
    info.pWaitDstStageMask = &wait_stage;
    info.commandBufferCount = 1;
    info.pCommandBuffers = &fd.CommandBuffer;
    info.signalSemaphoreCount = 1;
    info.pSignalSemaphores = &render_complete_semaphore;

    err = vkEndCommandBuffer (fd.CommandBuffer);
    check_vk_result (err);
    err = vkQueueSubmit (g_Queue, 1, &info, fd.Fence);
    check_vk_result (err);
  }
}

fn FramePresent (wd: *c.ImGui_ImplVulkanH_Window) void
{
  if (g_SwapChainRebuild) return;
  var render_complete_semaphore = wd.FrameSemaphores [wd.SemaphoreIndex].RenderCompleteSemaphore;
  var info = c.VkPresentInfoKHR {};
  info.sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
  info.waitSemaphoreCount = 1;
  info.pWaitSemaphores = &render_complete_semaphore;
  info.swapchainCount = 1;
  info.pSwapchains = &wd.Swapchain;
  info.pImageIndices = &wd.FrameIndex;
  const err = vkQueuePresentKHR (g_Queue, &info);
  if (err == c.VK_ERROR_OUT_OF_DATE_KHR or err == c.VK_SUBOPTIMAL_KHR)
  {
    g_SwapChainRebuild = true;
    return;
  }
  check_vk_result (err);
  wd.SemaphoreIndex = (wd.SemaphoreIndex + 1) % wd.SemaphoreCount; // Now we can use the next set of semaphores
}

pub fn main () !void
{
  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  const allocator = arena.allocator ();

  _ = c.glfwSetErrorCallback (glfw_error_callback);
  if (c.glfwInit () == 0) return error.glfwInitFailure;

  // Create window with Vulkan context
  c.glfwWindowHint (c.GLFW_CLIENT_API, c.GLFW_NO_API);
  const window = c.glfwCreateWindow (1280, 720, "Dear ImGui GLFW+Vulkan example", null, null);
  if (c.glfwVulkanSupported () == 0) return error.VulkanNotSupported;

  var extensions = std.ArrayList ([*:0] const u8).init (allocator);
  var extensions_count: u32 = 0;
  const glfw_extensions = c.glfwGetRequiredInstanceExtensions (&extensions_count);
  for (0 .. extensions_count) |i| try extensions.append (std.mem.span (glfw_extensions [i]));
  try SetupVulkan (allocator, &extensions);

  // Create Window Surface
  var surface: c.VkSurfaceKHR = undefined;
  var err = c.glfwCreateWindowSurface (g_Instance, window, g_Allocator, &surface);
  check_vk_result (err);

  if (!c.cImGui_ImplVulkan_LoadFunctions (loader)) return error.ImGuiVulkanLoadFailure;

  // Create Framebuffers
  var w: i32 = undefined;
  var h: i32 = undefined;
  c.glfwGetFramebufferSize (window, &w, &h);
  var wd = &g_MainWindowData;
  try SetupVulkanWindow (wd, surface, w, h);

  // Setup Dear ImGui context
  if (c.ImGui_CreateContext (null) == null) return error.ImGuiCreateContextFailure;
  const io = c.ImGui_GetIO ();// (void)io;
  io.*.ConfigFlags |= c.ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
  io.*.ConfigFlags |= c.ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

  // Setup Dear ImGui style
  c.ImGui_StyleColorsDark (null);

  // Setup Platform/Renderer backends
  if (!c.cImGui_ImplGlfw_InitForVulkan (window, true)) return error.ImGuiGlfwInitForVulkanFailure;
  var init_info = c.ImGui_ImplVulkan_InitInfo {};
  init_info.Instance = g_Instance;
  init_info.PhysicalDevice = g_PhysicalDevice;
  init_info.Device = g_Device;
  init_info.QueueFamily = g_QueueFamily.?;
  init_info.Queue = g_Queue;
  init_info.PipelineCache = g_PipelineCache;
  init_info.DescriptorPool = g_DescriptorPool;
  init_info.RenderPass = wd.RenderPass;
  init_info.Subpass = 0;
  init_info.MinImageCount = g_MinImageCount;
  init_info.ImageCount = wd.ImageCount;
  init_info.MSAASamples = c.VK_SAMPLE_COUNT_1_BIT;
  init_info.Allocator = g_Allocator;
  init_info.CheckVkResultFn = check_vk_result;
  if (!c.cImGui_ImplVulkan_Init (&init_info)) return error.ImGuiVulkanInitFailure;

  // Our state
  var show_demo_window = true;
  var show_another_window = false;
  const clear_color: c.ImVec4 = .{ .x = 0.45, .y = 0.55, .z = 0.6, .w = 1.0 };
  const clear_color_slice = try allocator.alloc (f32, 3);
  clear_color_slice [0] = clear_color.x;
  clear_color_slice [1] = clear_color.y;
  clear_color_slice [2] = clear_color.z;

  defer
  {
    // Cleanup
    err = vkDeviceWaitIdle (g_Device);
    check_vk_result (err);
    c.cImGui_ImplVulkan_Shutdown ();
    c.cImGui_ImplGlfw_Shutdown ();
    c.ImGui_DestroyContext (null);

    CleanupVulkanWindow ();
    CleanupVulkan ();

    c.glfwDestroyWindow (window);
    c.glfwTerminate ();
  }

  while (c.glfwWindowShouldClose (window) == 0)
  {
    c.glfwPollEvents ();

    // Resize swap chain?
    if (g_SwapChainRebuild)
    {
      var width: i32 = undefined;
      var height: i32 = undefined;
      c.glfwGetFramebufferSize (window, &width, &height);
      if (width > 0 and height > 0)
      {
        c.cImGui_ImplVulkan_SetMinImageCount (g_MinImageCount);
        c.cImGui_ImplVulkanH_CreateOrResizeWindow (g_Instance, g_PhysicalDevice, g_Device, &g_MainWindowData, g_QueueFamily.?, g_Allocator, width, height, g_MinImageCount);
        g_MainWindowData.FrameIndex = 0;
        g_SwapChainRebuild = false;
      }
    }

    // Start the Dear ImGui frame
    c.cImGui_ImplVulkan_NewFrame ();
    c.cImGui_ImplGlfw_NewFrame ();
    c.ImGui_NewFrame ();

    defer
    {
      // Rendering
      c.ImGui_Render ();
      const draw_data = c.ImGui_GetDrawData ();
      const is_minimized = (draw_data.*.DisplaySize.x <= 0.0 or draw_data.*.DisplaySize.y <= 0.0);
      if (!is_minimized)
      {
        wd.ClearValue.color.float32 [0] = clear_color.x * clear_color.w;
        wd.ClearValue.color.float32 [1] = clear_color.y * clear_color.w;
        wd.ClearValue.color.float32 [2] = clear_color.z * clear_color.w;
        wd.ClearValue.color.float32 [3] = clear_color.w;
        FrameRender (wd, draw_data);
        FramePresent (wd);
      }
    }

    // 1. Show the big demo window (Most of the sample code is in ImGui::ShowDemoWindow()! You can browse its code to learn more about Dear ImGui!).
    if (show_demo_window) c.ImGui_ShowDemoWindow (&show_demo_window);

    // 2. Show a simple window that we create ourselves. We use a Begin/End pair to create a named window.
    var f: f32 = 0.0;
    var counter: i32 = 0;

    {
      _ = c.ImGui_Begin ("Hello, world!", null, 0);
      defer c.ImGui_End ();

      c.ImGui_Text ("This is some useful text.");
      _ = c.ImGui_Checkbox ("Demo Window", &show_demo_window);
      _ = c.ImGui_Checkbox ("Another Window", &show_another_window);

      _ = c.ImGui_SliderFloat ("float", &f, 0.0, 1.0);
      _ = c.ImGui_ColorEdit3 ("clear color", clear_color_slice.ptr, 0);

      if (c.ImGui_Button ("Button")) counter += 1;
      c.ImGui_SameLine ();
      c.ImGui_Text ("counter = %d", counter);

      c.ImGui_Text ("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.*.Framerate, io.*.Framerate);
    }

    // 3. Show another simple window.
    if (show_another_window)
    {
      _ = c.ImGui_Begin ("Another Window", &show_another_window, 0);
      defer c.ImGui_End ();
      c.ImGui_Text ("Hello from another window!");
      if (c.ImGui_Button ("Close Me")) show_another_window = false;
    }
  }
}
