const std = @import("std");
const c = @import("c");
const build = struct {
    const Platform = @TypeOf(@import("build").dummy_platform);
};

const glfw = @import("common/vulkan/glfw");
const sdl3 = @import("common/vulkan/sdl3");
const zglfw = @import("common/vulkan/zglfw");

fn platform(comptime backend: build.Platform) type {
    return switch (backend) {
        .GLFW => glfw,
        .SDL3 => sdl3,
        .zGLFW => zglfw,
    };
}

var instance: c.VkInstance = undefined;
var physical_device: c.VkPhysicalDevice = undefined;
var device: c.VkDevice = undefined;
var queue_family: ?u32 = null;
var queue: c.VkQueue = undefined;
var descriptor_pool: c.VkDescriptorPool = undefined;
var window_data: c.ImGui_ImplVulkanH_Window = undefined;
var min_image_count: u32 = 2;
var swap_chain_rebuild: bool = false;
var swap_chain_image_usage: u32 = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

const api_version: u32 = c.VK_API_VERSION_1_2;

fn checkResult(result: c.VkResult) callconv(std.builtin.CallingConvention.c) void {
    if (result == c.VK_SUCCESS) return;
    std.debug.panic("[vulkan] Error: VkResult = {d}\n", .{result});
}

pub fn init(comptime p: build.Platform, allocator: std.mem.Allocator, app_name: [*c]const u8) !void {
    try setup(p, allocator, app_name);
    errdefer cleanup(p, allocator);

    try platform(p).loadFunctions(api_version);

    try setupWindow(p);
    errdefer cleanupWindow(p);
}

pub fn deinit(comptime p: build.Platform, allocator: std.mem.Allocator) void {
    deviceWaitIdle(p);
    cleanupWindow(p);
    cleanup(p, allocator);
}

fn setup(comptime p: build.Platform, allocator: std.mem.Allocator, app_name: [*c]const u8) !void {
    var instance_extensions: std.ArrayList([*:0]const u8) = .empty;
    var platform_extensions_count: u32 = 0;
    const platform_extensions = platform(p).getRequiredInstanceExtensions(&platform_extensions_count);
    for (0..platform_extensions_count) |i| try instance_extensions.append(allocator, std.mem.span(platform_extensions[i]));

    var app_info: c.VkApplicationInfo = undefined;
    app_info.pApplicationName = app_name;
    app_info.applicationVersion = c.VK_MAKE_API_VERSION(0, 0, 0, 0);
    app_info.pEngineName = "No Engine";
    app_info.engineVersion = c.VK_MAKE_API_VERSION(0, 0, 0, 0);
    app_info.apiVersion = api_version;

    var create_info: c.VkInstanceCreateInfo = undefined;
    create_info.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    create_info.pApplicationInfo = &app_info;
    create_info.enabledExtensionCount = @intCast(instance_extensions.items.len);
    create_info.ppEnabledExtensionNames = instance_extensions.items.ptr;
    checkResult(platform(p).vkCreateInstance(&create_info, null, &instance));

    var gpu_count: u32 = undefined;
    checkResult(platform(p).vkEnumeratePhysicalDevices(instance, &gpu_count, null));

    const gpus = try allocator.alloc(c.VkPhysicalDevice, gpu_count);
    checkResult(platform(p).vkEnumeratePhysicalDevices(instance, &gpu_count, gpus.ptr));
    var found = false;

    for (gpus) |gpu| {
        var properties: c.VkPhysicalDeviceProperties = undefined;
        platform(p).vkGetPhysicalDeviceProperties(instance, gpu, &properties);
        if (properties.deviceType == c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
            physical_device = gpu;
            found = true;
        }
    }

    if (!found) {
        if (gpu_count == 0) return error.NoPhysicalDeviceAvailable;
        physical_device = gpus[0];
    }

    var count: u32 = undefined;
    platform(p).vkGetPhysicalDeviceQueueFamilyProperties(instance, physical_device, &count, null);
    const queues = try allocator.alloc(c.VkQueueFamilyProperties, count);
    defer allocator.free(queues);
    platform(p).vkGetPhysicalDeviceQueueFamilyProperties(instance, physical_device, &count, queues.ptr);
    var i: u32 = 0;
    while (i < count) {
        if (queues[i].queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
            queue_family = i;
            break;
        }
        i += 1;
    }

    var device_extensions: std.ArrayList([*:0]const u8) = .empty;
    try device_extensions.append(allocator, "VK_KHR_swapchain");

    const queue_priority = [_]f32{1.0};
    var queue_create_info: [1]c.VkDeviceQueueCreateInfo = undefined;
    queue_create_info[0].sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queue_create_info[0].queueFamilyIndex = queue_family.?;
    queue_create_info[0].queueCount = 1;
    queue_create_info[0].pQueuePriorities = &queue_priority;
    var device_create_info: c.VkDeviceCreateInfo = undefined;
    device_create_info.sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    device_create_info.queueCreateInfoCount = queue_create_info.len;
    device_create_info.pQueueCreateInfos = &queue_create_info;
    device_create_info.enabledExtensionCount = @intCast(device_extensions.items.len);
    device_create_info.ppEnabledExtensionNames = device_extensions.items.ptr;
    checkResult(platform(p).vkCreateDevice(instance, physical_device, &device_create_info, null, &device));
    platform(p).vkGetDeviceQueue(device, instance, queue_family.?, 0, &queue);

    const pool_sizes = [_]c.VkDescriptorPoolSize{
        .{
            .type = c.VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,
            .descriptorCount = c.IMGUI_IMPL_VULKAN_MINIMUM_SAMPLED_IMAGE_POOL_SIZE,
        },
        .{
            .type = c.VK_DESCRIPTOR_TYPE_SAMPLER,
            .descriptorCount = c.IMGUI_IMPL_VULKAN_MINIMUM_SAMPLER_POOL_SIZE,
        },
    };
    var desc_pool_create_info: c.VkDescriptorPoolCreateInfo = undefined;
    desc_pool_create_info.sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
    desc_pool_create_info.flags = c.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
    desc_pool_create_info.maxSets = 0;
    for (pool_sizes) |pool_size| desc_pool_create_info.maxSets += pool_size.descriptorCount;
    desc_pool_create_info.poolSizeCount = pool_sizes.len;
    desc_pool_create_info.pPoolSizes = &pool_sizes;
    checkResult(platform(p).vkCreateDescriptorPool(device, instance, &desc_pool_create_info, null, &descriptor_pool));
}

fn setupWindow(comptime p: build.Platform) !void {
    checkResult(platform(p).createWindowSurface(&instance, &window_data.Surface));
    errdefer platform(p).destroyWindowSurface(&instance, &window_data.Surface);

    var width: i32 = undefined;
    var height: i32 = undefined;
    try platform(p).getFramebufferSize(&width, &height);

    var res: c.VkBool32 = undefined;
    _ = platform(p).vkGetPhysicalDeviceSurfaceSupportKHR(instance, physical_device, queue_family.?, window_data.Surface, &res);
    if (res != c.VK_TRUE) return error.NoWSISupport;

    const requestSurfaceImageFormat = [_]c.VkFormat{ c.VK_FORMAT_B8G8R8A8_UNORM, c.VK_FORMAT_R8G8B8A8_UNORM, c.VK_FORMAT_B8G8R8_UNORM, c.VK_FORMAT_R8G8B8_UNORM };
    const ptrRequestSurfaceImageFormat: [*]const c.VkFormat = &requestSurfaceImageFormat;
    const requestSurfaceColorSpace = c.VK_COLORSPACE_SRGB_NONLINEAR_KHR;
    window_data.SurfaceFormat = c.cImGui_ImplVulkanH_SelectSurfaceFormat(physical_device, window_data.Surface, ptrRequestSurfaceImageFormat, requestSurfaceImageFormat.len, requestSurfaceColorSpace);

    const present_modes = [_]c.VkPresentModeKHR{c.VK_PRESENT_MODE_FIFO_KHR};
    window_data.PresentMode = c.cImGui_ImplVulkanH_SelectPresentMode(physical_device, window_data.Surface, &present_modes[0], present_modes.len);

    c.cImGui_ImplVulkanH_CreateOrResizeWindow(instance, physical_device, device, &window_data, queue_family.?, null, width, height, min_image_count, swap_chain_image_usage);

    try platform(p).finalizeSetupWindow();
}

fn cleanup(comptime p: build.Platform, allocator: std.mem.Allocator) void {
    _ = allocator;
    platform(p).vkDestroyDescriptorPool(device, instance, descriptor_pool, null);

    platform(p).vkDestroyDevice(device, instance, null);
    platform(p).vkDestroyInstance(instance, null);
}

fn cleanupWindow(comptime p: build.Platform) void {
    platform(p).destroyWindowSurface(&instance, &window_data.Surface);
    c.cImGui_ImplVulkanH_DestroyWindow(instance, device, &window_data, null);
}

pub fn initImguiContext(comptime p: build.Platform) !void {
    try platform(p).initForVulkan();
    errdefer platform(p).shutdown();
    var init_info: c.ImGui_ImplVulkan_InitInfo = undefined;
    init_info.Instance = instance;
    init_info.PhysicalDevice = physical_device;
    init_info.Device = device;
    init_info.QueueFamily = queue_family.?;
    init_info.Queue = queue;
    init_info.DescriptorPool = descriptor_pool;
    init_info.MinImageCount = min_image_count;
    init_info.ImageCount = window_data.ImageCount;
    init_info.PipelineInfoMain.RenderPass = window_data.RenderPass;
    init_info.PipelineInfoMain.Subpass = 0;
    init_info.PipelineInfoMain.MSAASamples = c.VK_SAMPLE_COUNT_1_BIT;
    init_info.CheckVkResultFn = checkResult;
    if (!c.cImGui_ImplVulkan_Init(&init_info)) return error.ImGuiVulkanInit;
    errdefer c.cImGui_ImplVulkan_Shutdown();
}

pub fn deinitImguiContext(comptime p: build.Platform) void {
    c.cImGui_ImplVulkan_Shutdown();
    platform(p).shutdown();
}

pub fn beforeNewFrame(comptime p: build.Platform) !void {
    try resizeSwapChain(p);
}

fn resizeSwapChain(comptime p: build.Platform) !void {
    var width: i32 = undefined;
    var height: i32 = undefined;
    try platform(p).getFramebufferSize(&width, &height);
    if (width > 0 and height > 0 and (swap_chain_rebuild or window_data.Width != width or window_data.Height != height)) {
        c.cImGui_ImplVulkan_SetMinImageCount(min_image_count);
        c.cImGui_ImplVulkanH_CreateOrResizeWindow(instance, physical_device, device, &window_data, queue_family.?, null, width, height, min_image_count, swap_chain_image_usage);
        window_data.FrameIndex = 0;
        swap_chain_rebuild = false;
    }
}

pub fn newFrame() void {
    c.cImGui_ImplVulkan_NewFrame();
}

pub fn render(comptime p: build.Platform, clear_color: *const c.ImVec4, draw_data: *c.ImDrawData, is_minimized: bool) !void {
    if (!is_minimized) {
        window_data.ClearValue.color.float32[0] = clear_color.x * clear_color.w;
        window_data.ClearValue.color.float32[1] = clear_color.y * clear_color.w;
        window_data.ClearValue.color.float32[2] = clear_color.z * clear_color.w;
        window_data.ClearValue.color.float32[3] = clear_color.w;
        frameRender(p, draw_data);
        framePresent(p);
    }
}

fn frameRender(comptime p: build.Platform, draw_data: *c.ImDrawData) void {
    var image_acquired_semaphore = window_data.FrameSemaphores.Data[window_data.SemaphoreIndex].ImageAcquiredSemaphore;
    var render_complete_semaphore = window_data.FrameSemaphores.Data[window_data.SemaphoreIndex].RenderCompleteSemaphore;
    const err = platform(p).vkAcquireNextImageKHR(device, instance, window_data.Swapchain, std.math.maxInt(u64), image_acquired_semaphore, null, &window_data.FrameIndex);
    if (err == c.VK_ERROR_OUT_OF_DATE_KHR or err == c.VK_SUBOPTIMAL_KHR) {
        swap_chain_rebuild = true;
        return;
    }
    checkResult(err);

    var fd = &window_data.Frames.Data[window_data.FrameIndex];
    checkResult(platform(p).vkWaitForFences(device, instance, 1, &fd.Fence, c.VK_TRUE, std.math.maxInt(u64)));

    checkResult(platform(p).vkResetFences(device, instance, 1, &fd.Fence));
    checkResult(platform(p).vkResetCommandPool(device, instance, fd.CommandPool, 0));
    var command_buffer_begin_info: c.VkCommandBufferBeginInfo = undefined;
    command_buffer_begin_info.sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    command_buffer_begin_info.flags |= c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    checkResult(platform(p).vkBeginCommandBuffer(device, instance, fd.CommandBuffer, &command_buffer_begin_info));

    var render_pass_begin_info: c.VkRenderPassBeginInfo = undefined;
    render_pass_begin_info.sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    render_pass_begin_info.renderPass = window_data.RenderPass;
    render_pass_begin_info.framebuffer = fd.Framebuffer;
    render_pass_begin_info.renderArea.extent.width = @intCast(window_data.Width);
    render_pass_begin_info.renderArea.extent.height = @intCast(window_data.Height);
    render_pass_begin_info.clearValueCount = 1;
    render_pass_begin_info.pClearValues = &window_data.ClearValue;
    platform(p).vkCmdBeginRenderPass(device, instance, fd.CommandBuffer, &render_pass_begin_info, c.VK_SUBPASS_CONTENTS_INLINE);

    c.cImGui_ImplVulkan_RenderDrawData(draw_data, fd.CommandBuffer);

    platform(p).vkCmdEndRenderPass(device, instance, fd.CommandBuffer);

    var wait_stage: c.VkPipelineStageFlags = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    var submit_info: c.VkSubmitInfo = undefined;
    submit_info.sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submit_info.waitSemaphoreCount = 1;
    submit_info.pWaitSemaphores = &image_acquired_semaphore;
    submit_info.pWaitDstStageMask = &wait_stage;
    submit_info.commandBufferCount = 1;
    submit_info.pCommandBuffers = &fd.CommandBuffer;
    submit_info.signalSemaphoreCount = 1;
    submit_info.pSignalSemaphores = &render_complete_semaphore;

    checkResult(platform(p).vkEndCommandBuffer(device, instance, fd.CommandBuffer));
    checkResult(platform(p).vkQueueSubmit(device, instance, queue, 1, &submit_info, fd.Fence));
}

fn framePresent(comptime p: build.Platform) void {
    if (swap_chain_rebuild) return;
    var render_complete_semaphore = window_data.FrameSemaphores.Data[window_data.SemaphoreIndex].RenderCompleteSemaphore;
    var present_info: c.VkPresentInfoKHR = undefined;
    present_info.sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    present_info.waitSemaphoreCount = 1;
    present_info.pWaitSemaphores = &render_complete_semaphore;
    present_info.swapchainCount = 1;
    present_info.pSwapchains = &window_data.Swapchain;
    present_info.pImageIndices = &window_data.FrameIndex;
    const err = platform(p).vkQueuePresentKHR(device, instance, queue, &present_info);
    if (err == c.VK_ERROR_OUT_OF_DATE_KHR or err == c.VK_SUBOPTIMAL_KHR) {
        swap_chain_rebuild = true;
        return;
    }
    checkResult(err);
    window_data.SemaphoreIndex = (window_data.SemaphoreIndex + 1) % window_data.SemaphoreCount;
}

fn deviceWaitIdle(comptime p: build.Platform) void {
    checkResult(platform(p).vkDeviceWaitIdle(device, instance));
}
