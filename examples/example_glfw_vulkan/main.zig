const std = @import ("std");
const builtin = @import ("builtin");

const build = @import ("build");
const glfw = @import ("glfw");
const vk = @import ("vulkan");
const imgui = @import ("imgui");

var g_Allocator:        *vk.VkAllocationCallbacks   = undefined;
var g_Instance:         vk.VkInstance               = undefined;
var g_PhysicalDevice:   vk.VkPhysicalDevice         = undefined;
var g_Device:           vk.VkDevice                 = undefined;
var g_QueueFamily:      ?u32                        = null;
var g_Queue:            vk.VkQueue                  = undefined;
var g_DebugReport:      vk.VkDebugReportCallbackEXT = undefined;
var g_PipelineCache:    vk.VkPipelineCache          = undefined;
var g_DescriptorPool:   vk.VkDescriptorPool         = undefined;

var g_MainWindowData:   imgui.ImGui_ImplVulkanH_Window = undefined;
var g_MinImageCount:    u32 = 2;
var g_SwapChainRebuild: bool = false;

fn glfw_error_callback (err: c_int, description: [*c] const u8) callconv (.C) void
{
  std.debug.print ("GLFW Error {d}: {s}\n", .{ err, description });
}

fn get_vulkan_instance_func (comptime PFN: type, instance: vk.VkInstance, name: [*c] const u8) PFN
{
  return @ptrCast (glfw.glfwGetInstanceProcAddress (instance, name));
}

fn loader (name: [*c] const u8, instance: ?*anyopaque) callconv (.C) ?*const fn () callconv (.C) void
{
  return glfw.glfwGetInstanceProcAddress (@ptrCast (instance), name);
}

fn check_vk_result (err: vk.VkResult) callconv (.C) void
{
  if (err == 0) return;
  std.debug.print ("[vulkan] Error: VkResult = {d}\n", .{ err });
  if (err < 0) std.os.exit (1);
}

pub const vulkan_call_conv: std.builtin.CallingConvention = if (builtin.os.tag == .windows and builtin.cpu.arch == .x86)
  .Stdcall
else if (builtin.abi == .android and (builtin.cpu.arch.isARM () or builtin.cpu.arch.isThumb ()) and std.Target.arm.featureSetHas (builtin.cpu.features, .has_v7) and builtin.cpu.arch.ptrBitWidth () == 32)
  // On Android 32-bit ARM targets, Vulkan functions use the "hardfloat"
  // calling convention, i.e. float parameters are passed in registers. This
  // is true even if the rest of the application passes floats on the stack,
  // as it does by default when compiling for the armeabi-v7a NDK ABI.
  .AAPCSVFP
else
  .C;

fn debug_report (_: vk.VkDebugReportFlagsEXT, objectType: vk.VkDebugReportObjectTypeEXT, _: u64, _: usize, _: i32, _: ?*const u8, pMessage: ?[*:0] const u8, _: ?*anyopaque) callconv (vulkan_call_conv) vk.VkBool32
{
  std.debug.print ("[vulkan] Debug report from ObjectType: {any}\nMessage: {s}\n\n", .{ objectType, pMessage orelse "No message available" });
  return vk.VK_FALSE;
}

fn IsExtensionAvailable (properties: [] const vk.VkExtensionProperties, extension: [] const u8) bool
{
  for (0 .. properties.len) |i|
  {
    if (std.mem.eql (u8, &properties [i].extensionName, extension)) return true;
  } else return false;
}

fn SetupVulkan_SelectPhysicalDevice (allocator: std.mem.Allocator) !vk.VkPhysicalDevice
{
  var gpu_count: u32 = undefined;
  var err = vk.vkEnumeratePhysicalDevices (g_Instance, &gpu_count, null);
  check_vk_result (err);

  const gpus = try allocator.alloc (vk.VkPhysicalDevice, gpu_count);
  err = vk.vkEnumeratePhysicalDevices (g_Instance, &gpu_count, gpus.ptr);
  check_vk_result(err);

  for (gpus) |device|
  {
    var properties: vk.VkPhysicalDeviceProperties = undefined;
    vk.vkGetPhysicalDeviceProperties (device, &properties);
    if (properties.deviceType == vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) return device;
  }

  // Use first GPU (Integrated) is a Discrete one is not available.
  if (gpu_count > 0) return gpus [0];
  return error.NoPhysicalDeviceAvailable;
}

fn SetupVulkan (allocator: std.mem.Allocator, instance_extensions: *std.ArrayList ([*:0] const u8)) !void
{
  var err: vk.VkResult = undefined;

  // Create Vulkan Instance
  var create_info = vk.VkInstanceCreateInfo {};
  create_info.sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;

  // Enumerate available extensions
  var properties_count: u32 = undefined;
  _ = vk.vkEnumerateInstanceExtensionProperties (null, &properties_count, null);
  const properties = try allocator.alloc (vk.VkExtensionProperties, properties_count);
  err = vk.vkEnumerateInstanceExtensionProperties (null, &properties_count, properties.ptr);
  check_vk_result (err);

  // Enable required extensions
  if (IsExtensionAvailable (properties [0 .. properties_count], vk.VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME))
    try instance_extensions.append (vk.VK_KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME);

  // Enabling validation layers
  create_info.enabledLayerCount = 1;
  const required_layers = [_][*:0] const u8 { "VK_LAYER_KHRONOS_validation" };
  create_info.ppEnabledLayerNames = required_layers [0 ..].ptr;
  try instance_extensions.append ("VK_EXT_debug_report");

  // Create Vulkan Instance
  create_info.enabledExtensionCount = @intCast (instance_extensions.items.len);
  create_info.ppEnabledExtensionNames = instance_extensions.items.ptr;
  err = vk.vkCreateInstance (&create_info, g_Allocator, &g_Instance);
  check_vk_result (err);

  // Setup the debug report callback
  const func = get_vulkan_instance_func (vk.PFN_vkCreateDebugReportCallbackEXT, g_Instance, "vkCreateDebugReportCallbackEXT");
  var debug_report_ci = vk.VkDebugReportCallbackCreateInfoEXT {};
  debug_report_ci.sType = vk.VK_STRUCTURE_TYPE_DEBUG_REPORT_CALLBACK_CREATE_INFO_EXT;
  debug_report_ci.flags = vk.VK_DEBUG_REPORT_ERROR_BIT_EXT | vk.VK_DEBUG_REPORT_WARNING_BIT_EXT | vk.VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT;
  debug_report_ci.pfnCallback = debug_report;
  debug_report_ci.pUserData = null;
  if (func) |vkCreateDebugReportCallbackEXT|
    err = vkCreateDebugReportCallbackEXT (g_Instance, &debug_report_ci, g_Allocator, &g_DebugReport);
  check_vk_result (err);

  // Select Physical Device (GPU)
  g_PhysicalDevice = try SetupVulkan_SelectPhysicalDevice (allocator);

  // Select graphics queue family
  var count: u32 = undefined;
  vk.vkGetPhysicalDeviceQueueFamilyProperties (g_PhysicalDevice, &count, null);
  const queues = try allocator.alloc (vk.VkQueueFamilyProperties, count);
  defer allocator.free (queues);
  vk.vkGetPhysicalDeviceQueueFamilyProperties (g_PhysicalDevice, &count, queues.ptr);
  var i: u32 = 0;
  while (i < count)
  {
    if (queues [i].queueFlags & vk.VK_QUEUE_GRAPHICS_BIT != 0)
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
  _ = vk.vkEnumerateDeviceExtensionProperties (g_PhysicalDevice, null, &properties_count, null);
  const properties2 = try allocator.alloc (vk.VkExtensionProperties, properties_count);
  _ = vk.vkEnumerateDeviceExtensionProperties (g_PhysicalDevice, null, &properties_count, properties2.ptr);

  const queue_priority = [_] f32 { 1.0 };
  var queue_info = [1] vk.VkDeviceQueueCreateInfo { .{} };
  queue_info [0].sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
  queue_info [0].queueFamilyIndex = g_QueueFamily.?;
  queue_info [0].queueCount = 1;
  queue_info [0].pQueuePriorities = &queue_priority;
  var device_create_info = vk.VkDeviceCreateInfo {};
  device_create_info.sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  device_create_info.queueCreateInfoCount = queue_info.len;
  device_create_info.pQueueCreateInfos = &queue_info;
  device_create_info.enabledExtensionCount = @intCast (device_extensions.items.len);
  device_create_info.ppEnabledExtensionNames = device_extensions.items.ptr;
  err = vk.vkCreateDevice (g_PhysicalDevice, &device_create_info, g_Allocator, &g_Device);
  check_vk_result (err);
  vk.vkGetDeviceQueue (g_Device, g_QueueFamily.?, 0, &g_Queue);

  // Create Descriptor Pool
  // The example only requires a single combined image sampler descriptor for the font image and only uses one descriptor set (for that)
  // If you wish to load e.g. additional textures you may need to alter pools sizes.
  const pool_sizes = [_] vk.VkDescriptorPoolSize
                     {
                       .{
                          .@"type" = vk.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                          .descriptorCount = 1,
                        },
                     };
  var pool_info = vk.VkDescriptorPoolCreateInfo {};
  pool_info.sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
  pool_info.flags = vk.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
  pool_info.maxSets = 1;
  pool_info.poolSizeCount = pool_sizes.len;
  pool_info.pPoolSizes = &pool_sizes;
  err = vk.vkCreateDescriptorPool (g_Device, &pool_info, g_Allocator, &g_DescriptorPool);
  check_vk_result (err);
}

// All the ImGui_ImplVulkanH_XXX structures/functions are optional helpers used by the demo.
// Your real engine/app may not use them.
fn SetupVulkanWindow (wd: *imgui.ImGui_ImplVulkanH_Window, surface: vk.VkSurfaceKHR, width: i32, height: i32) !void
{
  wd.Surface = surface;

  // Check for WSI support
  var res: vk.VkBool32 = undefined;
  _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR (g_PhysicalDevice, g_QueueFamily.?, wd.Surface, &res);
  if (res != vk.VK_TRUE) return error.NoWSISupport;

  // Select Surface Format
  const requestSurfaceImageFormat = [_] vk.VkFormat { vk.VK_FORMAT_B8G8R8A8_UNORM, vk.VK_FORMAT_R8G8B8A8_UNORM, vk.VK_FORMAT_B8G8R8_UNORM, vk.VK_FORMAT_R8G8B8_UNORM };
  const ptrRequestSurfaceImageFormat: [*] const vk.VkFormat = &requestSurfaceImageFormat;
  const requestSurfaceColorSpace = vk.VK_COLORSPACE_SRGB_NONLINEAR_KHR;
  wd.SurfaceFormat = imgui.cImGui_ImplVulkanH_SelectSurfaceFormat (g_PhysicalDevice, wd.Surface, ptrRequestSurfaceImageFormat, requestSurfaceImageFormat.len, requestSurfaceColorSpace);

  // Select Present Mode
  const present_modes = [_] vk.VkPresentModeKHR { vk.VK_PRESENT_MODE_FIFO_KHR };
  wd.PresentMode = imgui.cImGui_ImplVulkanH_SelectPresentMode (g_PhysicalDevice, wd.Surface, &present_modes [0], present_modes.len);

  // Create SwapChain, RenderPass, Framebuffer, etc.
  imgui.cImGui_ImplVulkanH_CreateOrResizeWindow (g_Instance, g_PhysicalDevice, g_Device, wd, g_QueueFamily.?, g_Allocator, width, height, g_MinImageCount);
}

fn CleanupVulkan () void
{
  vk.vkDestroyDescriptorPool (g_Device, g_DescriptorPool, g_Allocator);

  // Remove the debug report callback
  const func = get_vulkan_instance_func (vk.PFN_vkDestroyDebugReportCallbackEXT, g_Instance, "vkDestroyDebugReportCallbackEXT");
  if (func) |vkDestroyDebugReportCallbackEXT|
    vkDestroyDebugReportCallbackEXT (g_Instance, g_DebugReport, g_Allocator);

  vk.vkDestroyDevice (g_Device, g_Allocator);
  vk.vkDestroyInstance (g_Instance, g_Allocator);
}

fn CleanupVulkanWindow () void
{
  imgui.cImGui_ImplVulkanH_DestroyWindow (g_Instance, g_Device, &g_MainWindowData, g_Allocator);
}

fn FrameRender (wd: *imgui.ImGui_ImplVulkanH_Window, draw_data: *imgui.ImDrawData) void
{
  var err: vk.VkResult = undefined;

  var image_acquired_semaphore  = wd.FrameSemaphores [wd.SemaphoreIndex].ImageAcquiredSemaphore;
  var render_complete_semaphore = wd.FrameSemaphores [wd.SemaphoreIndex].RenderCompleteSemaphore;
  err = vk.vkAcquireNextImageKHR (g_Device, wd.Swapchain, std.math.maxInt (u64), image_acquired_semaphore, null, &wd.FrameIndex);
  if (err == vk.VK_ERROR_OUT_OF_DATE_KHR or err == vk.VK_SUBOPTIMAL_KHR)
  {
    g_SwapChainRebuild = true;
    return;
  }
  check_vk_result (err);

  var fd = &wd.Frames [wd.FrameIndex];
  err = vk.vkWaitForFences (g_Device, 1, &fd.Fence, vk.VK_TRUE, std.math.maxInt (u64));    // wait indefinitely instead of periodically checking
  check_vk_result (err);

  {
    err = vk.vkResetFences (g_Device, 1, &fd.Fence);
    check_vk_result (err);
    err = vk.vkResetCommandPool (g_Device, fd.CommandPool, 0);
    check_vk_result (err);
    var info = vk.VkCommandBufferBeginInfo {};
    info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    info.flags |= vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    err = vk.vkBeginCommandBuffer (fd.CommandBuffer, &info);
    check_vk_result (err);
  }{
    var info = vk.VkRenderPassBeginInfo {};
    info.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    info.renderPass = wd.RenderPass;
    info.framebuffer = fd.Framebuffer;
    info.renderArea.extent.width = @intCast (wd.Width);
    info.renderArea.extent.height = @intCast (wd.Height);
    info.clearValueCount = 1;
    info.pClearValues = &wd.ClearValue;
    vk.vkCmdBeginRenderPass (fd.CommandBuffer, &info, vk.VK_SUBPASS_CONTENTS_INLINE);
  }

  // Record dear imgui primitives into command buffer
  imgui.cImGui_ImplVulkan_RenderDrawData (draw_data, fd.CommandBuffer);

  // Submit command buffer
  vk.vkCmdEndRenderPass (fd.CommandBuffer);
  {
    var wait_stage: vk.VkPipelineStageFlags = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    var info = vk.VkSubmitInfo {};
    info.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;
    info.waitSemaphoreCount = 1;
    info.pWaitSemaphores = &image_acquired_semaphore;
    info.pWaitDstStageMask = &wait_stage;
    info.commandBufferCount = 1;
    info.pCommandBuffers = &fd.CommandBuffer;
    info.signalSemaphoreCount = 1;
    info.pSignalSemaphores = &render_complete_semaphore;

    err = vk.vkEndCommandBuffer (fd.CommandBuffer);
    check_vk_result (err);
    err = vk.vkQueueSubmit (g_Queue, 1, &info, fd.Fence);
    check_vk_result (err);
  }
}

fn FramePresent (wd: *imgui.ImGui_ImplVulkanH_Window) void
{
  if (g_SwapChainRebuild) return;
  var render_complete_semaphore = wd.FrameSemaphores [wd.SemaphoreIndex].RenderCompleteSemaphore;
  var info = vk.VkPresentInfoKHR {};
  info.sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
  info.waitSemaphoreCount = 1;
  info.pWaitSemaphores = &render_complete_semaphore;
  info.swapchainCount = 1;
  info.pSwapchains = &wd.Swapchain;
  info.pImageIndices = &wd.FrameIndex;
  const err = vk.vkQueuePresentKHR (g_Queue, &info);
  if (err == vk.VK_ERROR_OUT_OF_DATE_KHR or err == vk.VK_SUBOPTIMAL_KHR)
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

  std.debug.print ("{s} {s}\n", .{ build.name, build.version });

  _ = glfw.glfwSetErrorCallback (glfw_error_callback);
  if (glfw.glfwInit () == 0) return error.glfwInitFailure;

  // Create window with Vulkan context
  glfw.glfwWindowHint (glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
  const window = glfw.glfwCreateWindow (1280, 720, "Dear ImGui GLFW+Vulkan example", null, null);
  if (glfw.glfwVulkanSupported () == 0) return error.VulkanNotSupported;

  var extensions = std.ArrayList ([*:0] const u8).init (allocator);
  var extensions_count: u32 = 0;
  const glfw_extensions = glfw.glfwGetRequiredInstanceExtensions (&extensions_count);
  for (0 .. extensions_count) |i| try extensions.append (std.mem.span (glfw_extensions [i]));
  try SetupVulkan (allocator, &extensions);

  // Create Window Surface
  var surface: vk.VkSurfaceKHR = undefined;
  var err = glfw.glfwCreateWindowSurface (g_Instance, window, g_Allocator, &surface);
  check_vk_result (err);

  // Create Framebuffers
  var w: i32 = undefined;
  var h: i32 = undefined;
  glfw.glfwGetFramebufferSize (window, &w, &h);
  var wd = &g_MainWindowData;
  try SetupVulkanWindow (wd, surface, w, h);

  // Setup Dear ImGui context
  if (imgui.ImGui_CreateContext (null) == null) return error.ImGuiCreateContextFailure;
  const io = imgui.ImGui_GetIO ();// (void)io;
  io.*.ConfigFlags |= imgui.ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
  io.*.ConfigFlags |= imgui.ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

  // Setup Dear ImGui style
  imgui.ImGui_StyleColorsDark (null);

  // Setup Platform/Renderer backends
  if (!imgui.cImGui_ImplGlfw_InitForVulkan (window, true)) return error.ImGuiGlfwInitForVulkanFailure;
  var init_info = imgui.ImGui_ImplVulkan_InitInfo {};
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
  init_info.MSAASamples = vk.VK_SAMPLE_COUNT_1_BIT;
  init_info.Allocator = g_Allocator;
  init_info.CheckVkResultFn = check_vk_result;
  if (!imgui.cImGui_ImplVulkan_LoadFunctions (loader)) return error.ImGuiVulkanLoadFailure;
  if (!imgui.cImGui_ImplVulkan_Init (&init_info)) return error.ImGuiVulkanInitFailure;

  // Our state
  var show_demo_window = true;
  var show_another_window = false;
  const clear_color: imgui.ImVec4 = .{ .x = 0.45, .y = 0.55, .z = 0.6, .w = 1.0 };

  while (glfw.glfwWindowShouldClose (window) == 0)
  {
    glfw.glfwPollEvents ();

    // Resize swap chain?
    if (g_SwapChainRebuild)
    {
      var width: i32 = undefined;
      var height: i32 = undefined;
      glfw.glfwGetFramebufferSize (window, &width, &height);
      if (width > 0 and height > 0)
      {
        imgui.cImGui_ImplVulkan_SetMinImageCount (g_MinImageCount);
        imgui.cImGui_ImplVulkanH_CreateOrResizeWindow (g_Instance, g_PhysicalDevice, g_Device, &g_MainWindowData, g_QueueFamily.?, g_Allocator, width, height, g_MinImageCount);
        g_MainWindowData.FrameIndex = 0;
        g_SwapChainRebuild = false;
      }
    }

    // Start the Dear ImGui frame
    imgui.cImGui_ImplVulkan_NewFrame ();
    imgui.cImGui_ImplGlfw_NewFrame ();
    imgui.ImGui_NewFrame ();

    // 1. Show the big demo window (Most of the sample code is in ImGui::ShowDemoWindow()! You can browse its code to learn more about Dear ImGui!).
    if (show_demo_window) imgui.ImGui_ShowDemoWindow (&show_demo_window);

    // 2. Show a simple window that we create ourselves. We use a Begin/End pair to create a named window.
    var f: f32 = 0.0;
    var counter: i32 = 0;

    _ = imgui.ImGui_Begin ("Hello, world!", null, 0);

    imgui.ImGui_Text ("This is some useful text.");
    _ = imgui.ImGui_Checkbox ("Demo Window", &show_demo_window);
    _ = imgui.ImGui_Checkbox ("Another Window", &show_another_window);

    _ = imgui.ImGui_SliderFloat ("float", &f, 0.0, 1.0);

    if (imgui.ImGui_Button ("Button")) counter += 1;
    imgui.ImGui_SameLine ();
    imgui.ImGui_Text ("counter = %d", counter);

    imgui.ImGui_Text ("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.*.Framerate, io.*.Framerate);
    imgui.ImGui_End ();

    // 3. Show another simple window.
    if (show_another_window)
    {
      _ = imgui.ImGui_Begin ("Another Window", &show_another_window, 0);
      imgui.ImGui_Text ("Hello from another window!");
      if (imgui.ImGui_Button ("Close Me")) show_another_window = false;
      imgui.ImGui_End ();
    }

    // Rendering
    imgui.ImGui_Render ();
    const draw_data = imgui.ImGui_GetDrawData ();
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

  // Cleanup
  err = vk.vkDeviceWaitIdle (g_Device);
  check_vk_result (err);
  imgui.cImGui_ImplVulkan_Shutdown ();
  imgui.cImGui_ImplGlfw_Shutdown ();
  imgui.ImGui_DestroyContext (null);

  CleanupVulkanWindow ();
  CleanupVulkan ();

  glfw.glfwDestroyWindow (window);
  glfw.glfwTerminate ();
}
