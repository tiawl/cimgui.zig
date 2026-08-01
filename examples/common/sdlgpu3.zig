const std = @import("std");
const c = @import("c");
const build = struct {
    const Platform = @TypeOf(@import("build").dummy_platform);
};

const sdl3 = @import("common/sdl3");

fn platform(comptime backend: build.Platform) type {
    return switch (backend) {
        .SDL3 => sdl3,
        else => unreachable,
    };
}

var gpu_device: *c.struct_SDL_GPUDevice = undefined;

pub fn init(comptime p: build.Platform, allocator: std.mem.Allocator, app_name: [*c]const u8) !void {
    _ = allocator;
    _ = app_name;
    try platform(p).finalizeSetupWindow();

    gpu_device = try platform(p).errify(c.SDL_CreateGPUDevice(c.SDL_GPU_SHADERFORMAT_SPIRV | c.SDL_GPU_SHADERFORMAT_DXIL | c.SDL_GPU_SHADERFORMAT_MSL | c.SDL_GPU_SHADERFORMAT_METALLIB, true, null));
    errdefer c.SDL_DestroyGPUDevice(gpu_device);

    try platform(p).errify(c.SDL_ClaimWindowForGPUDevice(gpu_device, platform(p).window));
    errdefer c.SDL_ReleaseWindowFromGPUDevice(gpu_device, platform(p).window);

    try platform(p).errify(c.SDL_SetGPUSwapchainParameters(gpu_device, platform(p).window, c.SDL_GPU_SWAPCHAINCOMPOSITION_SDR, c.SDL_GPU_PRESENTMODE_VSYNC));
}

pub fn deinit(comptime p: build.Platform, allocator: std.mem.Allocator) void {
    _ = allocator;
    deviceWaitIdle();
    c.SDL_ReleaseWindowFromGPUDevice(gpu_device, platform(p).window);
    c.SDL_DestroyGPUDevice(gpu_device);
}

pub fn initImguiContext(comptime p: build.Platform) !void {
    try platform(p).errify(c.cImGui_ImplSDL3_InitForSDLGPU(platform(p).window));
    errdefer c.cImGui_ImplSDL3_Shutdown();
    var init_info: c.ImGui_ImplSDLGPU3_InitInfo = undefined;
    init_info.Device = gpu_device;
    init_info.ColorTargetFormat = c.SDL_GetGPUSwapchainTextureFormat(gpu_device, platform(p).window);
    init_info.MSAASamples = c.SDL_GPU_SAMPLECOUNT_1;
    init_info.SwapchainComposition = c.SDL_GPU_SWAPCHAINCOMPOSITION_SDR;
    init_info.PresentMode = c.SDL_GPU_PRESENTMODE_VSYNC;
    try platform(p).errify(c.cImGui_ImplSDLGPU3_Init(&init_info));
    errdefer c.cImGui_ImplSDLGPU3_Shutdown();
}

pub fn deinitImguiContext(comptime p: build.Platform) void {
    c.cImGui_ImplSDLGPU3_Shutdown();
    platform(p).shutdown();
}

pub fn newFrame() void {
    c.cImGui_ImplSDLGPU3_NewFrame();
}

pub fn render(comptime p: build.Platform, clear_color: *const c.ImVec4, draw_data: *c.ImDrawData, is_minimized: bool) !void {
    const command_buffer = try platform(p).errify(c.SDL_AcquireGPUCommandBuffer(gpu_device));

    var swapchain_texture: ?*c.SDL_GPUTexture = undefined;
    try platform(p).errify(c.SDL_WaitAndAcquireGPUSwapchainTexture(command_buffer, platform(p).window, &swapchain_texture, null, null));

    if (swapchain_texture != null and !is_minimized) {
        c.cImGui_ImplSDLGPU3_PrepareDrawData(draw_data, command_buffer);

        var target_info: c.SDL_GPUColorTargetInfo = undefined;
        target_info.texture = swapchain_texture;
        target_info.clear_color = c.SDL_FColor{
            .r = clear_color.x * clear_color.w,
            .g = clear_color.y * clear_color.w,
            .b = clear_color.z * clear_color.w,
            .a = clear_color.w,
        };
        target_info.load_op = c.SDL_GPU_LOADOP_CLEAR;
        target_info.store_op = c.SDL_GPU_STOREOP_STORE;
        target_info.mip_level = 0;
        target_info.layer_or_depth_plane = 0;
        target_info.cycle = false;
        const render_pass = c.SDL_BeginGPURenderPass(command_buffer, &target_info, 1, null);

        c.cImGui_ImplSDLGPU3_RenderDrawData(draw_data, command_buffer, render_pass);

        c.SDL_EndGPURenderPass(render_pass);
    }

    try platform(p).errify(c.SDL_SubmitGPUCommandBuffer(command_buffer));
}

fn deviceWaitIdle() void {
    _ = c.SDL_WaitForGPUIdle(gpu_device);
}
