const std = @import("std");
const c = @import("c");
const zglfw = @import("zglfw");

pub const Window = zglfw.Window;
pub const getRequiredInstanceExtensions = zglfw.getRequiredInstanceExtensions;
pub const createWindowSurface = zglfw.createWindowSurface;
pub const getProcAddress = zglfw.getProcAddress;

const build = struct {
    const Renderer = @TypeOf(@import("build").dummy_renderer);
};

const glfw = @import("common/glfw");

const vk = struct {
    fn windowHints() !void {
        if (!zglfw.vulkanSupported()) return error.VulkanUnsupported;
        zglfw.windowHint(zglfw.ClientAPI, zglfw.NoAPI);
    }
};

const zopengl3 = struct {
    fn windowHints() !void {
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 0);
    }
};

fn renderer(comptime backend: build.Renderer) type {
    return switch (backend) {
        .Vulkan, .zVulkan => vk,
        .zOpenGL3 => zopengl3,
        else => unreachable,
    };
}

pub var window: *zglfw.Window = undefined;

pub const errorCallback = glfw.errorCallback;

pub fn createWindow(comptime r: build.Renderer, title: [*c]const u8, width: c_int, height: c_int) !void {
    _ = zglfw.setErrorCallback(glfw.errorCallback);
    try zglfw.init();
    errdefer zglfw.terminate();

    try renderer(r).windowHints();
    window = try zglfw.createWindow(width, height, title, null, null);
}

pub fn destroyWindow() void {
    zglfw.destroyWindow(window);
    zglfw.terminate();
}

pub fn getFramebufferSize(width: *i32, height: *i32) !void {
    zglfw.getFramebufferSize(window, width, height);
}

pub fn createContext() !void {
    zglfw.makeContextCurrent(window);
    zglfw.swapInterval(1);
}

pub fn destroyContext() void {}

pub fn shouldClose() bool {
    return zglfw.windowShouldClose(window);
}

pub const pollEvents = zglfw.pollEvents;
pub const newFrame = glfw.newFrame;

pub fn swapBuffers() void {
    zglfw.swapBuffers(window);
}
