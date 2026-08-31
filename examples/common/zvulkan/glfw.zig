const std = @import("std");
const c = @import("c");
const vk = @import("zvulkan");
const glfw = @import("common/vulkan/glfw");

extern fn glfwGetInstanceProcAddress(instance: ?vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *c.GLFWwindow, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;

pub const getInstanceProcAddress = glfwGetInstanceProcAddress;
pub fn initInstanceProcAddress() void {}

pub var loader: Loader = undefined;
pub const loadFn = Loader.load;

pub const getRequiredInstanceExtensions = glfw.getRequiredInstanceExtensions;
pub const getFramebufferSize = glfw.getFramebufferSize;

pub fn createWindowSurface(instance: *vk.Instance, surface: *vk.SurfaceKHR) vk.Result {
    return glfwCreateWindowSurface(instance.*, glfw.glfw.window, null, surface);
}

pub fn destroyWindowSurface(instance: *vk.Instance, surface: *vk.SurfaceKHR) void {
    _ = instance;
    _ = surface;
}

pub const initForVulkan = glfw.initForVulkan;
pub const shutdown = glfw.shutdown;

const Loader = struct {
    instance: *vk.Instance,
    device: *vk.Device,

    fn load(funcname: [*c]const u8, user_data: ?*anyopaque) callconv(std.builtin.CallingConvention.c) ?*const fn () callconv(std.builtin.CallingConvention.c) void {
        const self: *@This() = @ptrCast(@alignCast(user_data));
        return getInstanceProcAddress(self.instance.*, funcname);
    }
};
