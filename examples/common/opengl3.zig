const c = @import("c");
const build = struct {
    const Platform = @TypeOf(@import("build").dummy_platform);
};

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

const glsl_version = "#version 130";

pub fn beforeNewFrame(comptime p: build.Platform) !void {
    _ = p;
}

pub fn newFrame() void {
    c.cImGui_ImplOpenGL3_NewFrame();
}

pub fn initImguiContext(comptime p: build.Platform) !void {
    try platform(p).initForOpenGL();
    _ = c.cImGui_ImplOpenGL3_InitEx(glsl_version);
}

pub fn deinitImguiContext(comptime p: build.Platform) void {
    platform(p).shutdown();
    c.cImGui_ImplOpenGL3_Shutdown();
}
