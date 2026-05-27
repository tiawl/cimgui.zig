const std = @import("std");
const vk = @import("zvulkan");
const c = @import("c");
const build = struct {
    const Platform = @TypeOf(@import("build").dummy_platform);
};

const vulkan = @import("common/vulkan");
const glfw = @import("common/zvulkan/glfw");
const sdl3 = @import("common/zvulkan/sdl3");
const zglfw = @import("common/zvulkan/zglfw");

fn platform(comptime backend: build.Platform) type {
    return switch (backend) {
        .GLFW => glfw,
        .SDL3 => sdl3,
        .zGLFW => zglfw,
    };
}

extern fn cImGui_ImplVulkan_Init(info: [*c]ImGui_ImplVulkan_InitInfo) bool;
extern fn cImGui_ImplVulkan_LoadFunctionsEx(api_version: vk.Version, loader_func: ?*const fn (function_name: [*c]const u8, user_data: ?*anyopaque) callconv(.c) vk.PfnVoidFunction, user_data: ?*anyopaque) bool;
extern fn cImGui_ImplVulkanH_SelectSurfaceFormat(physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR, request_formats: [*c]const vk.Format, request_formats_count: c_int, request_color_space: vk.ColorSpaceKHR) vk.SurfaceFormatKHR;
extern fn cImGui_ImplVulkanH_SelectPresentMode(physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR, request_modes: [*c]const vk.PresentModeKHR, request_modes_count: c_int) vk.PresentModeKHR;
extern fn cImGui_ImplVulkanH_CreateOrResizeWindow(instance: vk.Instance, physical_device: vk.PhysicalDevice, device: vk.Device, window_data: [*c]ImGui_ImplVulkanH_Window, queue_family: u32, allocator: [*c]const vk.AllocationCallbacks, w: c_int, h: c_int, min_image_count: u32, image_usage: vk.ImageUsageFlags) void;
extern fn cImGui_ImplVulkan_RenderDrawData(draw_data: [*c]c.ImDrawData, command_buffer: vk.CommandBuffer) void;
extern fn cImGui_ImplVulkanH_DestroyWindow(instance: vk.Instance, device: vk.Device, window_data: [*c]ImGui_ImplVulkanH_Window, allocator: [*c]const vk.AllocationCallbacks) void;

const ImGui_ImplVulkanH_Frame = extern struct {
    CommandPool: vk.CommandPool = .null_handle,
    CommandBuffer: vk.CommandBuffer = .null_handle,
    Fence: vk.Fence = .null_handle,
    Backbuffer: vk.Image = .null_handle,
    BackbufferView: vk.ImageView = .null_handle,
    Framebuffer: vk.Framebuffer = .null_handle,
};

const ImVector_ImGui_ImplVulkanH_Frame = extern struct {
    Size: c_int = 0,
    Capacity: c_int = 0,
    Data: [*c]ImGui_ImplVulkanH_Frame = null,
};

const ImGui_ImplVulkanH_FrameSemaphores = extern struct {
    ImageAcquiredSemaphore: vk.Semaphore = .null_handle,
    RenderCompleteSemaphore: vk.Semaphore = .null_handle,
};

const ImVector_ImGui_ImplVulkanH_FrameSemaphores = extern struct {
    Size: c_int = 0,
    Capacity: c_int = 0,
    Data: [*c]ImGui_ImplVulkanH_FrameSemaphores = null,
};

const ImGui_ImplVulkanH_Window = extern struct {
    UseDynamicRendering: bool = false,
    Surface: vk.SurfaceKHR = .null_handle,
    SurfaceFormat: vk.SurfaceFormatKHR = std.mem.zeroes(vk.SurfaceFormatKHR),
    PresentMode: vk.PresentModeKHR = std.mem.zeroes(vk.PresentModeKHR),
    AttachmentDesc: vk.AttachmentDescription = std.mem.zeroes(vk.AttachmentDescription),
    ClearValue: vk.ClearValue = std.mem.zeroes(vk.ClearValue),
    Width: c_int = 0,
    Height: c_int = 0,
    Swapchain: vk.SwapchainKHR = .null_handle,
    RenderPass: vk.RenderPass = .null_handle,
    Pipeline: vk.Pipeline = .null_handle,
    FrameIndex: u32 = 0,
    ImageCount: u32 = 0,
    SemaphoreCount: u32 = 0,
    SemaphoreIndex: u32 = 0,
    Frames: ImVector_ImGui_ImplVulkanH_Frame = std.mem.zeroes(ImVector_ImGui_ImplVulkanH_Frame),
    FrameSemaphores: ImVector_ImGui_ImplVulkanH_FrameSemaphores = std.mem.zeroes(ImVector_ImGui_ImplVulkanH_FrameSemaphores),
};

const ImVector_VkDynamicState = extern struct {
    Size: c_int = 0,
    Capacity: c_int = 0,
    Data: [*c]vk.DynamicState = null,
};

const ImGui_ImplVulkan_PipelineInfo = extern struct {
    RenderPass: vk.RenderPass = .null_handle,
    Subpass: u32 = 0,
    MSAASamples: vk.SampleCountFlags = std.mem.zeroes(vk.SampleCountFlags),
    ExtraDynamicStates: ImVector_VkDynamicState = std.mem.zeroes(ImVector_VkDynamicState),
    PipelineRenderingCreateInfo: vk.PipelineRenderingCreateInfoKHR = std.mem.zeroes(vk.PipelineRenderingCreateInfoKHR),
};

const ImGui_ImplVulkan_InitInfo = extern struct {
    ApiVersion: u32 = 0,
    Instance: vk.Instance = .null_handle,
    PhysicalDevice: vk.PhysicalDevice = .null_handle,
    Device: vk.Device = .null_handle,
    QueueFamily: u32 = 0,
    Queue: vk.Queue = .null_handle,
    DescriptorPool: vk.DescriptorPool = .null_handle,
    DescriptorPoolSize: u32 = 0,
    MinImageCount: u32 = 0,
    ImageCount: u32 = 0,
    PipelineCache: vk.PipelineCache = .null_handle,
    PipelineInfoMain: ImGui_ImplVulkan_PipelineInfo = std.mem.zeroes(ImGui_ImplVulkan_PipelineInfo),
    UseDynamicRendering: bool = false,
    Allocator: [*c]const vk.AllocationCallbacks = null,
    CheckVkResultFn: ?*const fn (vk.Result) callconv(std.builtin.CallingConvention.c) void = null,
    MinAllocationSize: vk.DeviceSize = 0,
    CustomShaderVertCreateInfo: vk.ShaderModuleCreateInfo = std.mem.zeroes(vk.ShaderModuleCreateInfo),
    CustomShaderFragCreateInfo: vk.ShaderModuleCreateInfo = std.mem.zeroes(vk.ShaderModuleCreateInfo),
};

var instance: vk.Instance = .null_handle;
var instance_proxy: vk.InstanceProxy = undefined;
var physical_device: vk.PhysicalDevice = .null_handle;
var queue_family: ?u32 = null;
var device: vk.Device = .null_handle;
var device_proxy: vk.DeviceProxy = undefined;
var queue: vk.Queue = .null_handle;
var descriptor_pool: vk.DescriptorPool = .null_handle;
var pipeline_cache: vk.PipelineCache = .null_handle;
var window_data: ImGui_ImplVulkanH_Window = .{};
var min_image_count: u32 = 2;
var swap_chain_rebuild: bool = false;
var swap_chain_image_usage = vk.ImageUsageFlags{ .color_attachment_bit = true };

const api_version = vk.API_VERSION_1_2;

fn checkResult(result: vk.Result) callconv(std.builtin.CallingConvention.c) void {
    if (result == .success) return;
    std.debug.panic("[vulkan] Error: VkResult = {d}\n", .{@intFromEnum(result)});
}

pub fn init(comptime p: build.Platform, allocator: std.mem.Allocator, app_name: [*c]const u8) !void {
    try setup(p, allocator, app_name);
    errdefer cleanup(allocator);

    if (!cImGui_ImplVulkan_LoadFunctionsEx(api_version, platform(p).loadFn, &platform(p).loader)) return error.ImGuiVulkanLoad;

    try setupWindow(p);
    errdefer cleanupWindow(p);
}

pub fn deinit(comptime p: build.Platform, allocator: std.mem.Allocator) void {
    deviceWaitIdle();
    cleanupWindow(p);
    cleanup(allocator);
}

fn setup(comptime p: build.Platform, allocator: std.mem.Allocator, app_name: [*c]const u8) !void {
    var instance_extensions: std.ArrayList([*:0]const u8) = .empty;
    var platform_extensions_count: u32 = 0;
    const platform_extensions = platform(p).getRequiredInstanceExtensions(&platform_extensions_count);
    for (0..platform_extensions_count) |i| try instance_extensions.append(allocator, std.mem.span(platform_extensions[i]));

    platform(p).initInstanceProcAddress();
    var base_wrapper = vk.BaseWrapper.load(platform(p).getInstanceProcAddress);
    var app_info = vk.ApplicationInfo{
        .p_application_name = app_name,
        .application_version = @bitCast(vk.makeApiVersion(0, 0, 0, 0)),
        .p_engine_name = "No Engine",
        .engine_version = @bitCast(vk.makeApiVersion(0, 0, 0, 0)),
        .api_version = @bitCast(api_version),
    };

    var create_info = vk.InstanceCreateInfo{};
    create_info.p_application_info = &app_info;
    create_info.enabled_extension_count = @intCast(instance_extensions.items.len);
    create_info.pp_enabled_extension_names = instance_extensions.items.ptr;
    instance = try base_wrapper.createInstance(&create_info, null);
    platform(p).loader.instance = &instance;
    const instance_wrapper = try allocator.create(vk.InstanceWrapper);
    errdefer allocator.destroy(instance_proxy.wrapper);
    instance_wrapper.* = vk.InstanceWrapper.load(instance, base_wrapper.dispatch.vkGetInstanceProcAddr.?);
    instance_proxy = vk.InstanceProxy.init(instance, instance_wrapper);

    const gpus = try instance_proxy.enumeratePhysicalDevicesAlloc(allocator);
    defer allocator.free(gpus);

    var gpu_properties: vk.PhysicalDeviceProperties = undefined;
    var found = false;
    for (gpus) |gpu| {
        gpu_properties = instance_proxy.getPhysicalDeviceProperties(gpu);
        if (gpu_properties.device_type == .discrete_gpu) {
            physical_device = gpu;
            found = true;
        }
    }

    if (!found) {
        if (gpus.len == 0) return error.NoPhysicalDeviceAvailable;
        physical_device = gpus[0];
    }

    const families = try instance_proxy.getPhysicalDeviceQueueFamilyPropertiesAlloc(physical_device, allocator);
    defer allocator.free(families);
    var i: u32 = 0;
    for (families) |fproperties| {
        if (fproperties.queue_flags.graphics_bit) {
            queue_family = i;
            break;
        }
        i += 1;
    }

    var device_extensions: std.ArrayList([*:0]const u8) = .empty;
    try device_extensions.append(allocator, "VK_KHR_swapchain");

    const queue_priority = [_]f32{1.0};
    var queue_create_info = [_]vk.DeviceQueueCreateInfo{
        .{
            .queue_family_index = queue_family.?,
            .queue_count = 1,
            .p_queue_priorities = &queue_priority,
        },
    };
    var device_create_info = vk.DeviceCreateInfo{};
    device_create_info.queue_create_info_count = queue_create_info.len;
    device_create_info.p_queue_create_infos = &queue_create_info;
    device_create_info.enabled_extension_count = @intCast(device_extensions.items.len);
    device_create_info.pp_enabled_extension_names = device_extensions.items.ptr;
    device = try instance_proxy.createDevice(physical_device, &device_create_info, null);
    platform(p).loader.device = &device;
    const device_wrapper = try allocator.create(vk.DeviceWrapper);
    errdefer allocator.destroy(device_proxy.wrapper);
    device_wrapper.* = vk.DeviceWrapper.load(device, instance_proxy.wrapper.dispatch.vkGetDeviceProcAddr.?);
    device_proxy = vk.DeviceProxy.init(device, device_wrapper);
    queue = device_proxy.getDeviceQueue(queue_family.?, 0);

    const pool_sizes = [_]vk.DescriptorPoolSize{
        .{
            .type = .sampled_image,
            .descriptor_count = c.IMGUI_IMPL_VULKAN_MINIMUM_SAMPLED_IMAGE_POOL_SIZE,
        },
        .{
            .type = .sampler,
            .descriptor_count = c.IMGUI_IMPL_VULKAN_MINIMUM_SAMPLER_POOL_SIZE,
        },
    };
    var desc_pool_create_info = vk.DescriptorPoolCreateInfo{
        .flags = .{ .free_descriptor_set_bit = true },
        .max_sets = 0,
    };
    for (pool_sizes) |pool_size| desc_pool_create_info.max_sets += pool_size.descriptor_count;
    desc_pool_create_info.pool_size_count = pool_sizes.len;
    desc_pool_create_info.p_pool_sizes = &pool_sizes;
    descriptor_pool = try device_proxy.createDescriptorPool(&desc_pool_create_info, null);
}

fn setupWindow(comptime p: build.Platform) !void {
    checkResult(platform(p).createWindowSurface(&instance, &window_data.Surface));
    errdefer platform(p).destroyWindowSurface(&instance, &window_data.Surface);

    var width: i32 = undefined;
    var height: i32 = undefined;
    try platform(p).getFramebufferSize(&width, &height);

    if (try instance_proxy.getPhysicalDeviceSurfaceSupportKHR(physical_device, queue_family.?, window_data.Surface) != .true) return error.NoWSISupport;

    const requestSurfaceImageFormat = [_]vk.Format{ .b8g8r8a8_unorm, .r8g8b8a8_unorm, .b8g8r8_unorm, .r8g8b8_unorm };
    const ptrRequestSurfaceImageFormat: [*]const vk.Format = &requestSurfaceImageFormat;
    const requestSurfaceColorSpace = vk.ColorSpaceKHR.srgb_nonlinear_khr;
    window_data.SurfaceFormat = cImGui_ImplVulkanH_SelectSurfaceFormat(physical_device, window_data.Surface, ptrRequestSurfaceImageFormat, requestSurfaceImageFormat.len, requestSurfaceColorSpace);

    const present_modes = [_]vk.PresentModeKHR{.fifo_khr};
    window_data.PresentMode = cImGui_ImplVulkanH_SelectPresentMode(physical_device, window_data.Surface, &present_modes[0], present_modes.len);

    cImGui_ImplVulkanH_CreateOrResizeWindow(instance, physical_device, device, &window_data, queue_family.?, null, width, height, min_image_count, swap_chain_image_usage);
}

fn cleanup(allocator: std.mem.Allocator) void {
    device_proxy.destroyDescriptorPool(descriptor_pool, null);
    device_proxy.destroyDevice(null);
    instance_proxy.destroyInstance(null);
    allocator.destroy(device_proxy.wrapper);
    allocator.destroy(instance_proxy.wrapper);
}

fn cleanupWindow(comptime p: build.Platform) void {
    platform(p).destroyWindowSurface(&instance, &window_data.Surface);
    cImGui_ImplVulkanH_DestroyWindow(instance, device, &window_data, null);
}

pub fn initImguiContext(comptime p: build.Platform) !void {
    try platform(p).initForVulkan();
    errdefer platform(p).shutdown();
    var init_info = ImGui_ImplVulkan_InitInfo{
        .Instance = instance,
        .PhysicalDevice = physical_device,
        .Device = device,
        .QueueFamily = queue_family.?,
        .Queue = queue,
        .PipelineCache = pipeline_cache,
        .DescriptorPool = descriptor_pool,
        .DescriptorPoolSize = 0,
        .MinImageCount = min_image_count,
        .ImageCount = window_data.ImageCount,
        .PipelineInfoMain = .{
            .RenderPass = window_data.RenderPass,
            .Subpass = 0,
            .MSAASamples = vk.SampleCountFlags{ .@"1_bit" = true },
        },
        .CheckVkResultFn = checkResult,
    };
    if (!cImGui_ImplVulkan_Init(&init_info)) return error.ImGuiVulkanInit;
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
        cImGui_ImplVulkanH_CreateOrResizeWindow(instance, physical_device, device, &window_data, queue_family.?, null, width, height, min_image_count, swap_chain_image_usage);
        window_data.FrameIndex = 0;
        swap_chain_rebuild = false;
    }
}

pub const newFrame = vulkan.newFrame;

pub fn render(comptime p: build.Platform, clear_color: *const c.ImVec4, draw_data: *c.ImDrawData, is_minimized: bool) !void {
    _ = p;
    if (!is_minimized) {
        window_data.ClearValue.color.float_32[0] = clear_color.x * clear_color.w;
        window_data.ClearValue.color.float_32[1] = clear_color.y * clear_color.w;
        window_data.ClearValue.color.float_32[2] = clear_color.z * clear_color.w;
        window_data.ClearValue.color.float_32[3] = clear_color.w;
        try frameRender(draw_data);
        try framePresent();
    }
}

fn frameRender(draw_data: *c.ImDrawData) !void {
    const image_acquired_semaphore = window_data.FrameSemaphores.Data[window_data.SemaphoreIndex].ImageAcquiredSemaphore;
    const render_complete_semaphore = window_data.FrameSemaphores.Data[window_data.SemaphoreIndex].RenderCompleteSemaphore;
    const result = device_proxy.acquireNextImageKHR(window_data.Swapchain, std.math.maxInt(u64), image_acquired_semaphore, .null_handle) catch |err| switch (err) {
        error.OutOfDateKHR => {
            swap_chain_rebuild = true;
            return;
        },
        else => return err,
    };
    window_data.FrameIndex = result.image_index;
    if (result.result == .suboptimal_khr) {
        swap_chain_rebuild = true;
        return;
    }

    const fd = &window_data.Frames.Data[window_data.FrameIndex];
    _ = try device_proxy.waitForFences(&.{fd.Fence}, .true, std.math.maxInt(u64));

    try device_proxy.resetFences(&.{fd.Fence});
    try device_proxy.resetCommandPool(fd.CommandPool, .{});
    var command_buffer_begin_info = vk.CommandBufferBeginInfo{};
    command_buffer_begin_info.flags.one_time_submit_bit = true;
    try device_proxy.beginCommandBuffer(fd.CommandBuffer, &command_buffer_begin_info);

    var render_pass_begin_info = vk.RenderPassBeginInfo{
        .render_pass = window_data.RenderPass,
        .framebuffer = fd.Framebuffer,
        .render_area = .{
            .extent = .{
                .width = @intCast(window_data.Width),
                .height = @intCast(window_data.Height),
            },
            .offset = .{
                .x = 0,
                .y = 0,
            },
        },
        .clear_value_count = 1,
        .p_clear_values = &.{window_data.ClearValue},
    };
    device_proxy.cmdBeginRenderPass(fd.CommandBuffer, &render_pass_begin_info, .@"inline");

    cImGui_ImplVulkan_RenderDrawData(draw_data, fd.CommandBuffer);

    device_proxy.cmdEndRenderPass(fd.CommandBuffer);
    const wait_stage: vk.PipelineStageFlags = .{ .color_attachment_output_bit = true };
    var submit_info = vk.SubmitInfo{};
    submit_info.wait_semaphore_count = 1;
    submit_info.p_wait_semaphores = &.{image_acquired_semaphore};
    submit_info.p_wait_dst_stage_mask = &.{wait_stage};
    submit_info.command_buffer_count = 1;
    submit_info.p_command_buffers = &.{fd.CommandBuffer};
    submit_info.signal_semaphore_count = 1;
    submit_info.p_signal_semaphores = &.{render_complete_semaphore};

    try device_proxy.endCommandBuffer(fd.CommandBuffer);
    try device_proxy.queueSubmit(queue, &.{submit_info}, fd.Fence);
}

fn framePresent() !void {
    if (swap_chain_rebuild) return;
    const render_complete_semaphore = window_data.FrameSemaphores.Data[window_data.SemaphoreIndex].RenderCompleteSemaphore;
    var present_info = vk.PresentInfoKHR{
        .wait_semaphore_count = 1,
        .p_wait_semaphores = &.{render_complete_semaphore},
        .swapchain_count = 1,
        .p_swapchains = &.{window_data.Swapchain},
        .p_image_indices = &.{window_data.FrameIndex},
    };
    const result = device_proxy.queuePresentKHR(queue, &present_info) catch |err| switch (err) {
        error.OutOfDateKHR => {
            swap_chain_rebuild = true;
            return;
        },
        else => return err,
    };
    if (result == .suboptimal_khr) {
        swap_chain_rebuild = true;
        return;
    }
    window_data.SemaphoreIndex = (window_data.SemaphoreIndex + 1) % window_data.SemaphoreCount;
}

fn deviceWaitIdle() void {
    device_proxy.deviceWaitIdle() catch {};
}
