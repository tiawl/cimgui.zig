const std = @import("std");
const c = @import("c");
pub const sdl3 = @import("common/sdl3");

pub var getInstanceProcAddress: c.PFN_vkGetInstanceProcAddr = null;
pub const getVkGetInstanceProcAddress = c.SDL_Vulkan_GetVkGetInstanceProcAddr;

fn initInstanceProcAddress() void {
    if (getInstanceProcAddress == null) getInstanceProcAddress = @ptrCast(getVkGetInstanceProcAddress());
}

var loader: Loader = undefined;

pub fn loadFunctions(api_version: u32) !void {
    if (!c.cImGui_ImplVulkan_LoadFunctionsEx(api_version, Loader.load, &loader)) return error.ImGuiVulkanLoad;
}

pub const getRequiredInstanceExtensions = c.SDL_Vulkan_GetInstanceExtensions;
pub const getFramebufferSize = sdl3.getFramebufferSize;

pub fn createWindowSurface(instance: *c.VkInstance, surface: *c.VkSurfaceKHR) c.VkResult {
    if (c.SDL_Vulkan_CreateSurface(sdl3.window, instance.*, null, surface)) return c.VK_SUCCESS;
    unreachable;
}

pub fn destroyWindowSurface(instance: *c.VkInstance, surface: *c.VkSurfaceKHR) void {
    c.SDL_Vulkan_DestroySurface(instance.*, surface.*, null);
}

pub const finalizeSetupWindow = sdl3.finalizeSetupWindow;

pub fn initForVulkan() !void {
    if (!c.cImGui_ImplSDL3_InitForVulkan(sdl3.window)) return error.cImGui_ImplSDL3_InitForVulkan;
}

pub const shutdown = sdl3.shutdown;

const Loader = struct {
    instance: *c.VkInstance,
    device: *c.VkDevice,

    fn loadGlobal(name: [*c]const u8) c.PFN_vkVoidFunction {
        initInstanceProcAddress();
        return getInstanceProcAddress.?(null, name);
    }

    fn loadInstance(self: *const @This(), name: [*c]const u8) c.PFN_vkVoidFunction {
        initInstanceProcAddress();
        return getInstanceProcAddress.?(self.instance.*, name);
    }

    fn loadDevice(self: *const @This(), name: [*c]const u8) c.PFN_vkVoidFunction {
        return @as(c.PFN_vkGetDeviceProcAddr, @ptrCast(self.loadInstance("vkGetDeviceProcAddr"))).?(self.device.*, name);
    }

    fn load(funcname: [*c]const u8, user_data: ?*anyopaque) callconv(std.builtin.CallingConvention.c) c.PFN_vkVoidFunction {
        var self: *@This() = @ptrCast(@alignCast(user_data));
        if (self.loadDevice(funcname)) |func| return func;
        if (self.loadInstance(funcname)) |func| return func;
        if (loadGlobal(funcname)) |func| return func;
        return null;
    }
};

pub fn vkCreateInstance(info: [*c]const c.VkInstanceCreateInfo, allocator: [*c]const c.VkAllocationCallbacks, instance: [*c]c.VkInstance) c.VkResult {
    const func: c.PFN_vkCreateInstance = @ptrCast(Loader.loadGlobal("vkCreateInstance").?);
    loader.instance = instance;
    return func.?(info, allocator, instance);
}

pub fn vkGetPhysicalDeviceSurfaceSupportKHR(instance: c.VkInstance, physical_device: c.VkPhysicalDevice, index: u32, surface: c.VkSurfaceKHR, supported: [*c]c.VkBool32) c.VkResult {
    _ = instance;
    const func: c.PFN_vkGetPhysicalDeviceSurfaceSupportKHR = @ptrCast(loader.loadInstance("vkGetPhysicalDeviceSurfaceSupportKHR").?);
    return func.?(physical_device, index, surface, supported);
}

pub fn vkGetPhysicalDeviceProperties(instance: c.VkInstance, physical_device: c.VkPhysicalDevice, properties: [*c]c.VkPhysicalDeviceProperties) void {
    _ = instance;
    const func: c.PFN_vkGetPhysicalDeviceProperties = @ptrCast(loader.loadInstance("vkGetPhysicalDeviceProperties").?);
    func.?(physical_device, properties);
}

pub fn vkEnumeratePhysicalDevices(instance: c.VkInstance, count: [*c]u32, physical_devices: [*c]c.VkPhysicalDevice) c.VkResult {
    const func: c.PFN_vkEnumeratePhysicalDevices = @ptrCast(loader.loadInstance("vkEnumeratePhysicalDevices").?);
    return func.?(instance, count, physical_devices);
}

pub fn vkGetPhysicalDeviceQueueFamilyProperties(instance: c.VkInstance, physical_device: c.VkPhysicalDevice, count: [*c]u32, properties: [*c]c.VkQueueFamilyProperties) void {
    _ = instance;
    const func: c.PFN_vkGetPhysicalDeviceQueueFamilyProperties = @ptrCast(loader.loadInstance("vkGetPhysicalDeviceQueueFamilyProperties").?);
    func.?(physical_device, count, properties);
}

pub fn vkCreateDevice(instance: c.VkInstance, physical_device: c.VkPhysicalDevice, info: [*c]const c.VkDeviceCreateInfo, allocator: [*c]const c.VkAllocationCallbacks, device: [*c]c.VkDevice) c.VkResult {
    _ = instance;
    const func: c.PFN_vkCreateDevice = @ptrCast(loader.loadInstance("vkCreateDevice").?);
    loader.device = device;
    return func.?(physical_device, info, allocator, device);
}

pub fn vkDestroyInstance(instance: c.VkInstance, allocator: [*c]const c.VkAllocationCallbacks) void {
    const func: c.PFN_vkDestroyInstance = @ptrCast(loader.loadInstance("vkDestroyInstance").?);
    func.?(instance, allocator);
}

pub fn vkAcquireNextImageKHR(device: c.VkDevice, instance: c.VkInstance, swapchain: c.VkSwapchainKHR, timeout: u64, semaphore: c.VkSemaphore, fence: c.VkFence, index: [*c]u32) c.VkResult {
    _ = instance;
    const func: c.PFN_vkAcquireNextImageKHR = @ptrCast(loader.loadDevice("vkAcquireNextImageKHR").?);
    return func.?(device, swapchain, timeout, semaphore, fence, index);
}

pub fn vkWaitForFences(device: c.VkDevice, instance: c.VkInstance, count: u32, fences: [*c]const c.VkFence, wait: c.VkBool32, timeout: u64) c.VkResult {
    _ = instance;
    const func: c.PFN_vkWaitForFences = @ptrCast(loader.loadDevice("vkWaitForFences").?);
    return func.?(device, count, fences, wait, timeout);
}

pub fn vkResetFences(device: c.VkDevice, instance: c.VkInstance, count: u32, fences: [*c]const c.VkFence) c.VkResult {
    _ = instance;
    const func: c.PFN_vkResetFences = @ptrCast(loader.loadDevice("vkResetFences").?);
    return func.?(device, count, fences);
}

pub fn vkGetDeviceQueue(device: c.VkDevice, instance: c.VkInstance, family: u32, index: u32, queue: [*c]c.VkQueue) void {
    _ = instance;
    const func: c.PFN_vkGetDeviceQueue = @ptrCast(loader.loadDevice("vkGetDeviceQueue").?);
    func.?(device, family, index, queue);
}

pub fn vkCreateDescriptorPool(device: c.VkDevice, instance: c.VkInstance, info: [*c]const c.VkDescriptorPoolCreateInfo, allocator: [*c]const c.VkAllocationCallbacks, descriptor_pool: [*c]c.VkDescriptorPool) c.VkResult {
    _ = instance;
    const func: c.PFN_vkCreateDescriptorPool = @ptrCast(loader.loadDevice("vkCreateDescriptorPool").?);
    return func.?(device, info, allocator, descriptor_pool);
}

pub fn vkCmdBeginRenderPass(device: c.VkDevice, instance: c.VkInstance, command_buffer: c.VkCommandBuffer, info: [*c]const c.VkRenderPassBeginInfo, contents: c.VkSubpassContents) void {
    _ = device;
    _ = instance;
    const func: c.PFN_vkCmdBeginRenderPass = @ptrCast(loader.loadDevice("vkCmdBeginRenderPass").?);
    func.?(command_buffer, info, contents);
}

pub fn vkCmdEndRenderPass(device: c.VkDevice, instance: c.VkInstance, command_buffer: c.VkCommandBuffer) void {
    _ = device;
    _ = instance;
    const func: c.PFN_vkCmdEndRenderPass = @ptrCast(loader.loadDevice("vkCmdEndRenderPass").?);
    func.?(command_buffer);
}

pub fn vkEndCommandBuffer(device: c.VkDevice, instance: c.VkInstance, command_buffer: c.VkCommandBuffer) c.VkResult {
    _ = device;
    _ = instance;
    const func: c.PFN_vkEndCommandBuffer = @ptrCast(loader.loadDevice("vkEndCommandBuffer").?);
    return func.?(command_buffer);
}

pub fn vkQueueSubmit(device: c.VkDevice, instance: c.VkInstance, queue: c.VkQueue, count: u32, info: [*c]const c.VkSubmitInfo, fence: c.VkFence) c.VkResult {
    _ = device;
    _ = instance;
    const func: c.PFN_vkQueueSubmit = @ptrCast(loader.loadDevice("vkQueueSubmit").?);
    return func.?(queue, count, info, fence);
}

pub fn vkResetCommandPool(device: c.VkDevice, instance: c.VkInstance, command_pool: c.VkCommandPool, flags: c.VkCommandPoolResetFlags) c.VkResult {
    _ = instance;
    const func: c.PFN_vkResetCommandPool = @ptrCast(loader.loadDevice("vkResetCommandPool").?);
    return func.?(device, command_pool, flags);
}

pub fn vkBeginCommandBuffer(device: c.VkDevice, instance: c.VkInstance, command_buffer: c.VkCommandBuffer, info: [*c]const c.VkCommandBufferBeginInfo) c.VkResult {
    _ = device;
    _ = instance;
    const func: c.PFN_vkBeginCommandBuffer = @ptrCast(loader.loadDevice("vkBeginCommandBuffer").?);
    return func.?(command_buffer, info);
}

pub fn vkQueuePresentKHR(device: c.VkDevice, instance: c.VkInstance, queue: c.VkQueue, info: [*c]const c.VkPresentInfoKHR) c.VkResult {
    _ = device;
    _ = instance;
    const func: c.PFN_vkQueuePresentKHR = @ptrCast(loader.loadDevice("vkQueuePresentKHR").?);
    return func.?(queue, info);
}

pub fn vkDeviceWaitIdle(device: c.VkDevice, instance: c.VkInstance) c.VkResult {
    _ = instance;
    const func: c.PFN_vkDeviceWaitIdle = @ptrCast(loader.loadDevice("vkDeviceWaitIdle").?);
    return func.?(device);
}

pub fn vkDestroyDescriptorPool(device: c.VkDevice, instance: c.VkInstance, descriptor_pool: c.VkDescriptorPool, allocator: [*c]const c.VkAllocationCallbacks) void {
    _ = instance;
    const func: c.PFN_vkDestroyDescriptorPool = @ptrCast(loader.loadDevice("vkDestroyDescriptorPool").?);
    func.?(device, descriptor_pool, allocator);
}

pub fn vkDestroyDevice(device: c.VkDevice, instance: c.VkInstance, allocator: [*c]const c.VkAllocationCallbacks) void {
    _ = instance;
    const func: c.PFN_vkDestroyDevice = @ptrCast(loader.loadDevice("vkDestroyDevice").?);
    func.?(device, allocator);
}
