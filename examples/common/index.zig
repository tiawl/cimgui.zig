const std = @import("std");
const c = @import("c");
const build = struct {
    const Platform = @TypeOf(@import("build").dummy_platform);
    const Renderer = @TypeOf(@import("build").dummy_renderer);
};

const glfw = @import("common/glfw");
const zglfw = @import("common/zglfw");
const sdl3 = @import("common/sdl3");
const sdlgpu3 = @import("common/sdlgpu3");
const vk = @import("common/vulkan");
const opengl3 = @import("common/opengl3");
const zopengl3 = @import("common/zopengl3");
const zvk = @import("common/zvulkan");

fn renderer(comptime backend: build.Renderer) type {
    return switch (backend) {
        .Vulkan => vk,
        .zVulkan => zvk,
        .SDLGPU3 => sdlgpu3,
        .OpenGL3 => opengl3,
        .zOpenGL3 => zopengl3,
        else => unreachable,
    };
}

fn platform(comptime backend: build.Platform) type {
    return switch (backend) {
        .GLFW => glfw,
        .SDL3 => sdl3,
        .zGLFW => zglfw,
    };
}

pub const window = struct {
    pub const width = 1280;
    pub const height = 720;
};

var io: *c.ImGuiIO = undefined;
const clear_color: c.ImVec4 = .{ .x = 0.45, .y = 0.55, .z = 0.6, .w = 1.0 };
var show_demo_window = true;
var show_another_window = false;

pub fn init(comptime p: build.Platform, comptime r: build.Renderer, allocator: std.mem.Allocator, title: [*c]const u8, width: c_int, height: c_int, app_name: [*c]const u8) !void {
    try createWindow(p, r, title, width, height);
    errdefer destroyWindow(p);

    try renderer(r).init(p, allocator, app_name);
    errdefer renderer(r).deinit(p, allocator);

    try createImguiContext();
    errdefer destroyImguiContext();

    try renderer(r).initImguiContext(p);
    errdefer renderer(r).deinitImguiContext(p);
}

pub fn deinit(comptime p: build.Platform, comptime r: build.Renderer, allocator: std.mem.Allocator) void {
    renderer(r).deinitImguiContext(p);
    destroyImguiContext();
    renderer(r).deinit(p, allocator);
    destroyWindow(p);
}

fn createWindow(comptime p: build.Platform, comptime r: build.Renderer, title: [*c]const u8, width: c_int, height: c_int) !void {
    try platform(p).createWindow(r, title, width, height);
}

fn destroyWindow(comptime p: build.Platform) void {
    platform(p).destroyWindow();
}

fn createImguiContext() !void {
    _ = c.CIMGUI_CHECKVERSION();
    if (c.ImGui_CreateContext(null) == null) return error.ImGuiCreateContext;
    errdefer c.ImGui_DestroyContext(null);
    io = c.ImGui_GetIO();
    io.ConfigFlags |= c.ImGuiConfigFlags_NavEnableKeyboard;
    io.ConfigFlags |= c.ImGuiConfigFlags_NavEnableGamepad;
    c.ImGui_StyleColorsDark(null);
}

fn destroyImguiContext() void {
    c.ImGui_DestroyContext(null);
}

pub fn loop(comptime p: build.Platform, comptime r: build.Renderer, allocator: std.mem.Allocator) !void {
    while (!platform(p).shouldClose()) {
        platform(p).pollEvents();

        try newFrame(p, r);

        showFirstDemoWindow();
        try showSecondDemoWindow(allocator);
        showThirdDemoWindow();

        try render(p, r);
    }
}

fn showFirstDemoWindow() void {
    if (show_demo_window) c.ImGui_ShowDemoWindow(&show_demo_window);
}

fn showSecondDemoWindow(allocator: std.mem.Allocator) !void {
    const clear_color_slice = try allocator.alloc(f32, 3);
    clear_color_slice[0] = clear_color.x;
    clear_color_slice[1] = clear_color.y;
    clear_color_slice[2] = clear_color.z;

    var f: f32 = 0.0;
    var counter: i32 = 0;

    _ = c.ImGui_Begin("Hello, world!", null, 0);
    defer c.ImGui_End();

    c.ImGui_Text("This is some useful text.");
    _ = c.ImGui_Checkbox("Demo Window", &show_demo_window);
    _ = c.ImGui_Checkbox("Another Window", &show_another_window);

    _ = c.ImGui_SliderFloat("float", &f, 0.0, 1.0);
    _ = c.ImGui_ColorEdit3("clear color", clear_color_slice.ptr, 0);

    if (c.ImGui_Button("Button")) counter += 1;
    c.ImGui_SameLine();
    c.ImGui_Text("counter = %d", counter);

    c.ImGui_Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.Framerate, io.Framerate);
}

fn showThirdDemoWindow() void {
    if (show_another_window) {
        _ = c.ImGui_Begin("Another Window", &show_another_window, 0);
        defer c.ImGui_End();
        c.ImGui_Text("Hello from another window!");
        if (c.ImGui_Button("Close Me")) show_another_window = false;
    }
}

fn newFrame(comptime p: build.Platform, comptime r: build.Renderer) !void {
    if (@hasDecl(renderer(r), "beforeNewFrame")) try renderer(r).beforeNewFrame(p);
    platform(p).newFrame();
    renderer(r).newFrame();
    c.ImGui_NewFrame();
}

fn render(comptime p: build.Platform, comptime r: build.Renderer) !void {
    c.ImGui_Render();
    const draw_data: *c.ImDrawData = c.ImGui_GetDrawData();
    const is_minimized = (draw_data.DisplaySize.x <= 0.0 or draw_data.DisplaySize.y <= 0.0);
    try renderer(r).render(p, &clear_color, draw_data, is_minimized);
}
