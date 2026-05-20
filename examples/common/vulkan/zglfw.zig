const std = @import("std");
const c = @import("c");
pub const zglfw = @import("common/zglfw");
const glfw = @import("common/vulkan/glfw");

extern fn glfwGetInstanceProcAddress(instance: c.VkInstance, procname: [*:0]const u8) c.PFN_vkVoidFunction;
extern fn glfwCreateWindowSurface(instance: c.VkInstance, window: *zglfw.Window, allocation_callbacks: ?*const c.VkAllocationCallbacks, surface: *c.VkSurfaceKHR) c.VkResult;

pub const getInstanceProcAddress = glfwGetInstanceProcAddress;

pub fn loader(name: [*c]const u8, instance: ?*anyopaque) callconv(std.builtin.CallingConvention.c) ?*const fn () callconv(std.builtin.CallingConvention.c) void {
    return getInstanceProcAddress(@ptrCast(@alignCast(instance)), name);
}

pub const loadFunctions = glfw.loadFunctions;

pub fn getRequiredInstanceExtensions(count: *u32) [*][*:0]const u8 {
    return zglfw.getRequiredInstanceExtensions(count) orelse @panic("Failed to get GLFW extensions");
}

pub const getFramebufferSize = zglfw.getFramebufferSize;

pub fn createWindowSurface(instance: *c.VkInstance, surface: *c.VkSurfaceKHR) c.VkResult {
    return glfwCreateWindowSurface(instance.*, zglfw.window, null, surface);
}

pub const destroyWindowSurface = glfw.destroyWindowSurface;
pub const finalizeSetupWindow = glfw.finalizeSetupWindow;

pub fn initForVulkan() !void {
    if (!c.cImGui_ImplGlfw_InitForVulkan(@ptrCast(@alignCast(zglfw.window)), true)) return error.cImGui_ImplGlfw_InitForVulkan;
}

pub const shutdown = glfw.shutdown;

fn getInstanceFunc(comptime PFN: type, instance: c.VkInstance, name: [*c]const u8) PFN {
    return @ptrCast(getInstanceProcAddress(instance, name));
}

fn getDeviceFunc(comptime PFN: type, device: c.VkDevice, instance: c.VkInstance, name: [*c]const u8) PFN {
    const vkGetDeviceProcAddr = getInstanceFunc(c.PFN_vkGetDeviceProcAddr, instance, "vkGetDeviceProcAddr").?;
    return @ptrCast(vkGetDeviceProcAddr(device, name));
}

pub fn vkCreateInstance(info: [*c]const c.VkInstanceCreateInfo, allocator: [*c]const c.VkAllocationCallbacks, instance: [*c]c.VkInstance) c.VkResult {
    const func = getInstanceFunc(c.PFN_vkCreateInstance, null, "vkCreateInstance").?;
    return func(info, allocator, instance);
}

pub fn vkGetPhysicalDeviceSurfaceSupportKHR(instance: c.VkInstance, physical_device: c.VkPhysicalDevice, index: u32, surface: c.VkSurfaceKHR, supported: [*c]c.VkBool32) c.VkResult {
    const func = getInstanceFunc(c.PFN_vkGetPhysicalDeviceSurfaceSupportKHR, instance, "vkGetPhysicalDeviceSurfaceSupportKHR").?;
    return func(physical_device, index, surface, supported);
}

pub fn vkGetPhysicalDeviceProperties(instance: c.VkInstance, physical_device: c.VkPhysicalDevice, properties: [*c]c.VkPhysicalDeviceProperties) void {
    const func = getInstanceFunc(c.PFN_vkGetPhysicalDeviceProperties, instance, "vkGetPhysicalDeviceProperties").?;
    func(physical_device, properties);
}

pub fn vkEnumeratePhysicalDevices(instance: c.VkInstance, count: [*c]u32, physical_devices: [*c]c.VkPhysicalDevice) c.VkResult {
    const func = getInstanceFunc(c.PFN_vkEnumeratePhysicalDevices, instance, "vkEnumeratePhysicalDevices").?;
    return func(instance, count, physical_devices);
}

pub fn vkGetPhysicalDeviceQueueFamilyProperties(instance: c.VkInstance, physical_device: c.VkPhysicalDevice, count: [*c]u32, properties: [*c]c.VkQueueFamilyProperties) void {
    const func = getInstanceFunc(c.PFN_vkGetPhysicalDeviceQueueFamilyProperties, instance, "vkGetPhysicalDeviceQueueFamilyProperties").?;
    func(physical_device, count, properties);
}

pub fn vkCreateDevice(instance: c.VkInstance, physical_device: c.VkPhysicalDevice, info: [*c]const c.VkDeviceCreateInfo, allocator: [*c]const c.VkAllocationCallbacks, device: [*c]c.VkDevice) c.VkResult {
    const func = getInstanceFunc(c.PFN_vkCreateDevice, instance, "vkCreateDevice").?;
    return func(physical_device, info, allocator, device);
}

pub fn vkDestroyInstance(instance: c.VkInstance, allocator: [*c]const c.VkAllocationCallbacks) void {
    const func = getInstanceFunc(c.PFN_vkDestroyInstance, instance, "vkDestroyInstance").?;
    func(instance, allocator);
}

pub fn vkAcquireNextImageKHR(device: c.VkDevice, instance: c.VkInstance, swapchain: c.VkSwapchainKHR, timeout: u64, semaphore: c.VkSemaphore, fence: c.VkFence, index: [*c]u32) c.VkResult {
    const func = getDeviceFunc(c.PFN_vkAcquireNextImageKHR, device, instance, "vkAcquireNextImageKHR").?;
    return func(device, swapchain, timeout, semaphore, fence, index);
}

pub fn vkWaitForFences(device: c.VkDevice, instance: c.VkInstance, count: u32, fences: [*c]const c.VkFence, wait: c.VkBool32, timeout: u64) c.VkResult {
    const func = getDeviceFunc(c.PFN_vkWaitForFences, device, instance, "vkWaitForFences").?;
    return func(device, count, fences, wait, timeout);
}

pub fn vkResetFences(device: c.VkDevice, instance: c.VkInstance, count: u32, fences: [*c]const c.VkFence) c.VkResult {
    const func = getDeviceFunc(c.PFN_vkResetFences, device, instance, "vkResetFences").?;
    return func(device, count, fences);
}

pub fn vkGetDeviceQueue(device: c.VkDevice, instance: c.VkInstance, family: u32, index: u32, queue: [*c]c.VkQueue) void {
    const func = getDeviceFunc(c.PFN_vkGetDeviceQueue, device, instance, "vkGetDeviceQueue").?;
    func(device, family, index, queue);
}

pub fn vkCreateDescriptorPool(device: c.VkDevice, instance: c.VkInstance, info: [*c]const c.VkDescriptorPoolCreateInfo, allocator: [*c]const c.VkAllocationCallbacks, descriptor_pool: [*c]c.VkDescriptorPool) c.VkResult {
    const func = getDeviceFunc(c.PFN_vkCreateDescriptorPool, device, instance, "vkCreateDescriptorPool").?;
    return func(device, info, allocator, descriptor_pool);
}

pub fn vkCmdBeginRenderPass(device: c.VkDevice, instance: c.VkInstance, command_buffer: c.VkCommandBuffer, info: [*c]const c.VkRenderPassBeginInfo, contents: c.VkSubpassContents) void {
    const func = getDeviceFunc(c.PFN_vkCmdBeginRenderPass, device, instance, "vkCmdBeginRenderPass").?;
    func(command_buffer, info, contents);
}

pub fn vkCmdEndRenderPass(device: c.VkDevice, instance: c.VkInstance, command_buffer: c.VkCommandBuffer) void {
    const func = getDeviceFunc(c.PFN_vkCmdEndRenderPass, device, instance, "vkCmdEndRenderPass").?;
    func(command_buffer);
}

pub fn vkEndCommandBuffer(device: c.VkDevice, instance: c.VkInstance, command_buffer: c.VkCommandBuffer) c.VkResult {
    const func = getDeviceFunc(c.PFN_vkEndCommandBuffer, device, instance, "vkEndCommandBuffer").?;
    return func(command_buffer);
}

pub fn vkQueueSubmit(device: c.VkDevice, instance: c.VkInstance, queue: c.VkQueue, count: u32, info: [*c]const c.VkSubmitInfo, fence: c.VkFence) c.VkResult {
    const func = getDeviceFunc(c.PFN_vkQueueSubmit, device, instance, "vkQueueSubmit").?;
    return func(queue, count, info, fence);
}

pub fn vkResetCommandPool(device: c.VkDevice, instance: c.VkInstance, command_pool: c.VkCommandPool, flags: c.VkCommandPoolResetFlags) c.VkResult {
    const func = getDeviceFunc(c.PFN_vkResetCommandPool, device, instance, "vkResetCommandPool").?;
    return func(device, command_pool, flags);
}

pub fn vkBeginCommandBuffer(device: c.VkDevice, instance: c.VkInstance, command_buffer: c.VkCommandBuffer, info: [*c]const c.VkCommandBufferBeginInfo) c.VkResult {
    const func = getDeviceFunc(c.PFN_vkBeginCommandBuffer, device, instance, "vkBeginCommandBuffer").?;
    return func(command_buffer, info);
}

pub fn vkQueuePresentKHR(device: c.VkDevice, instance: c.VkInstance, queue: c.VkQueue, info: [*c]const c.VkPresentInfoKHR) c.VkResult {
    const func = getDeviceFunc(c.PFN_vkQueuePresentKHR, device, instance, "vkQueuePresentKHR").?;
    return func(queue, info);
}

pub fn vkDeviceWaitIdle(device: c.VkDevice, instance: c.VkInstance) c.VkResult {
    const func = getDeviceFunc(c.PFN_vkDeviceWaitIdle, device, instance, "vkDeviceWaitIdle").?;
    return func(device);
}

pub fn vkDestroyDescriptorPool(device: c.VkDevice, instance: c.VkInstance, descriptor_pool: c.VkDescriptorPool, allocator: [*c]const c.VkAllocationCallbacks) void {
    const func = getDeviceFunc(c.PFN_vkDestroyDescriptorPool, device, instance, "vkDestroyDescriptorPool").?;
    func(device, descriptor_pool, allocator);
}

pub fn vkDestroyDevice(device: c.VkDevice, instance: c.VkInstance, allocator: [*c]const c.VkAllocationCallbacks) void {
    const func = getDeviceFunc(c.PFN_vkDestroyDevice, device, instance, "vkDestroyDevice").?;
    func(device, allocator);
}
