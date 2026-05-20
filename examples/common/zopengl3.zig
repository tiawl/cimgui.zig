const std = @import("std");
const c = @import("c");
const gl = @import("zopengl3");

const build = struct {
    const Platform = @TypeOf(@import("build").dummy_platform);
};

const opengl3 = @import("common/opengl3");
const glfw = @import("common/opengl3/glfw");
const sdl3 = @import("common/opengl3/sdl3");
const zglfw = @import("common/opengl3/zglfw");

fn platform(comptime backend: build.Platform) type {
    return switch (backend) {
        .GLFW => glfw,
        .SDL3 => sdl3,
        .zGLFW => zglfw,
    };
}

var procs: gl.ProcTable = undefined;

pub fn init(comptime p: build.Platform, allocator: std.mem.Allocator, app_name: [*c]const u8) !void {
    _ = allocator;
    _ = app_name;
    try platform(p).createContext();
    errdefer platform(p).destroyContext();
    try createContext(platform(p).loader);
    errdefer destroyContext();
}

pub fn deinit(comptime p: build.Platform, allocator: std.mem.Allocator) void {
    _ = allocator;
    destroyContext();
    platform(p).destroyContext();
}

fn createContext(loader: anytype) !void {
    if (!procs.init(loader)) return error.GLInit;
    gl.makeProcTableCurrent(&procs);
}

fn destroyContext() void {
    gl.makeProcTableCurrent(null);
}

pub const beforeNewFrame = opengl3.beforeNewFrame;
pub const newFrame = opengl3.newFrame;
pub const initImguiContext = opengl3.initImguiContext;
pub const deinitImguiContext = opengl3.deinitImguiContext;

pub fn render(comptime p: build.Platform, clear_color: *const c.ImVec4, draw_data: *c.ImDrawData, is_minimized: bool) !void {
    _ = is_minimized;
    var width: c_int = 0;
    var height: c_int = 0;
    try platform(p).getFramebufferSize(&width, &height);
    gl.Viewport(0, 0, width, height);
    gl.ClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
    gl.Clear(gl.COLOR_BUFFER_BIT);
    c.cImGui_ImplOpenGL3_RenderDrawData(draw_data);
    platform(p).swapBuffers();
}
