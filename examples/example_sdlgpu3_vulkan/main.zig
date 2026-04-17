const std = @import("std");
const c = @import("c");

pub fn main() !void {
    errdefer |err| if (err == error.SdlError) std.log.err("SDL error: {s}", .{c.SDL_GetError()});

    c.SDL_SetMainReady();
    defer c.SDL_Quit();

    try errify(c.SDL_SetAppMetadata("Renderdog", "0.0.0", "renderdog"));
    try errify(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO | c.SDL_INIT_GAMEPAD));

    try errify(c.SDL_Vulkan_LoadLibrary(null));

    try errify(c.SDL_SetHint(c.SDL_HINT_RENDER_VSYNC, "0"));
    try errify(c.SDL_SetHint(c.SDL_HINT_GPU_DRIVER, "vulkan"));

    const w = 640;
    const h = 480;
    const windowName = "sdlgpu3_vulkan";

    const window: *c.SDL_Window = try errify(c.SDL_CreateWindow(windowName, w, h, c.SDL_WINDOW_VULKAN));
    defer c.SDL_DestroyWindow(window);

    const device: *c.SDL_GPUDevice = try errify(c.SDL_CreateGPUDevice(c.SDL_GPU_SHADERFORMAT_SPIRV, false, null));
    defer c.SDL_DestroyGPUDevice(device);

    try errify(c.SDL_ClaimWindowForGPUDevice(device, window));
    defer c.SDL_ReleaseWindowFromGPUDevice(device, window);

    try errify(c.SDL_SetGPUSwapchainParameters(device, window, c.SDL_GPU_SWAPCHAINCOMPOSITION_SDR, c.SDL_GPU_PRESENTMODE_VSYNC));

    // setup IMGUI
    // Setup Dear ImGui context
    if (c.ImGui_CreateContext(null) == null) return error.ImGuiCreateContextFailure;
    defer c.ImGui_DestroyContext(null);

    const io = c.ImGui_GetIO(); // (void)io;
    io.*.ConfigFlags |= c.ImGuiConfigFlags_NavEnableKeyboard; // Enable Keyboard Controls
    io.*.ConfigFlags |= c.ImGuiConfigFlags_NavEnableGamepad; // Enable Gamepad Controls

    // Setup Dear ImGui style
    c.ImGui_StyleColorsDark(c.ImGui_GetStyle());

    // Setup Platform/Renderer backends
    try errify(c.cImGui_ImplSDL3_InitForSDLGPU(window));
    defer c.cImGui_ImplSDL3_Shutdown();
    defer c.cImGui_ImplSDLGPU3_Shutdown();

    var info = c.ImGui_ImplSDLGPU3_InitInfo{
        .Device = device,
        .ColorTargetFormat = c.SDL_GetGPUSwapchainTextureFormat(device, window),
        .MSAASamples = c.SDL_GPU_SAMPLECOUNT_1,
    };

    if (!c.cImGui_ImplSDLGPU3_Init(&info)) {
        std.log.err("Unable to init sdlgpu3", .{});
        return error.ImplSDLGPU3_Init_Error;
    }

    var event: c.SDL_Event = undefined;
    main_loop: while (true) {
        while (c.SDL_PollEvent(&event)) {
            _ = c.cImGui_ImplSDL3_ProcessEvent(&event);
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    break :main_loop;
                },
                else => {},
            }
        }

        // get command buffer and prepare for render
        const cmdbuf = try errify(c.SDL_AcquireGPUCommandBuffer(device));

        var swapchainTexture: ?*c.SDL_GPUTexture = undefined;
        try errify(c.SDL_WaitAndAcquireGPUSwapchainTexture(cmdbuf, window, &swapchainTexture, null, null));

        if (swapchainTexture == null) {
            std.log.err("Unable to get swapchainTexture: {s}", .{c.SDL_GetError()});
            return error.SDLUnableToGetSwapchainTexture;
        }

        // Prepare for ImGui frame.
        // Start the Dear ImGui frame
        c.cImGui_ImplSDLGPU3_NewFrame();
        c.cImGui_ImplSDL3_NewFrame();
        c.ImGui_NewFrame();

        // imgui gui config
        var demowindow = true;
        c.ImGui_ShowDemoWindow(&demowindow);

        c.ImGui_Render();
        const drawData: *c.ImDrawData = c.ImGui_GetDrawData();

        c.cImGui_ImplSDLGPU3_PrepareDrawData(drawData, cmdbuf);

        const targetInfo = c.SDL_GPUColorTargetInfo{
            .texture = swapchainTexture,
            .clear_color = c.SDL_FColor{ .r = 1.0, .g = 0.2, .b = 0.3, .a = 1.0 },
            .load_op = c.SDL_GPU_LOADOP_CLEAR,
            .store_op = c.SDL_GPU_STOREOP_STORE,
            .mip_level = 0,
            .layer_or_depth_plane = 0,
            .cycle = false,
        };
        const renderPass = c.SDL_BeginGPURenderPass(cmdbuf, &targetInfo, 1, null);

        // Render ImGui
        c.cImGui_ImplSDLGPU3_RenderDrawData(drawData, cmdbuf, renderPass);
        c.SDL_EndGPURenderPass(renderPass);

        try errify(c.SDL_SubmitGPUCommandBuffer(cmdbuf));
    }

    _ = c.SDL_WaitForGPUIdle(device);
}

/// Converts the return value of an SDL function to an error union.
pub inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}
