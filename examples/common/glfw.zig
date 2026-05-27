const std = @import("std");
const c = @import("c");

const build = struct {
    const Renderer = @TypeOf(@import("build").dummy_renderer);
};

const vk = struct {
    fn windowHints() !void {
        if (c.glfwVulkanSupported() == 0) return error.VulkanNotSupported;
        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
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

pub var window: *c.GLFWwindow = undefined;

pub fn errorCallback(err: c_int, description: [*c]const u8) callconv(std.builtin.CallingConvention.c) void {
    std.debug.print("GLFW Error {d}: {s}\n", .{ err, description });
}

pub fn createWindow(comptime r: build.Renderer, title: [*c]const u8, width: c_int, height: c_int) !void {
    _ = c.glfwSetErrorCallback(errorCallback);
    if (c.glfwInit() != c.GLFW_TRUE) return error.GlfwInit;
    errdefer c.glfwTerminate();

    try renderer(r).windowHints();
    if (c.glfwCreateWindow(width, height, title, null, null)) |*win| {
        window = win.*;
    } else return error.glfwCreateWindow;
}

pub fn destroyWindow() void {
    c.glfwDestroyWindow(window);
    c.glfwTerminate();
}

pub fn getFramebufferSize(width: *i32, height: *i32) !void {
    c.glfwGetFramebufferSize(window, width, height);
}

pub fn createContext() !void {
    c.glfwMakeContextCurrent(window);
    c.glfwSwapInterval(1);
}

pub fn destroyContext() void {}

pub fn shouldClose() bool {
    return c.glfwWindowShouldClose(window) == c.GLFW_TRUE;
}

pub const pollEvents = c.glfwPollEvents;
pub const newFrame = c.cImGui_ImplGlfw_NewFrame;

pub fn swapBuffers() void {
    c.glfwSwapBuffers(window);
}

pub const shutdown = c.cImGui_ImplGlfw_Shutdown;
