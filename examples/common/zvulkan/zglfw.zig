const std = @import("std");
const vk = @import("zvulkan");
const zglfw = @import("common/vulkan/zglfw");

extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *zglfw.zglfw.Window, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;

pub const getInstanceProcAddress = glfwGetInstanceProcAddress;
pub fn initInstanceProcAddress() void {}

pub var loader: Loader = undefined;
pub const loadFn = Loader.load;

pub const getRequiredInstanceExtensions = zglfw.getRequiredInstanceExtensions;
pub const getFramebufferSize = zglfw.getFramebufferSize;

pub fn createWindowSurface(instance: *vk.Instance, surface: *vk.SurfaceKHR) vk.Result {
    return glfwCreateWindowSurface(instance.*, zglfw.zglfw.window, null, surface);
}

pub fn destroyWindowSurface(instance: *vk.Instance, surface: *vk.SurfaceKHR) void {
    _ = instance;
    _ = surface;
}

pub const initForVulkan = zglfw.initForVulkan;
pub const shutdown = zglfw.shutdown;

const Loader = struct {
    instance: *vk.Instance,
    device: *vk.Device,

    fn load(funcname: [*c]const u8, user_data: ?*anyopaque) callconv(std.builtin.CallingConvention.c) ?*const fn () callconv(std.builtin.CallingConvention.c) void {
        const self: *@This() = @ptrCast(@alignCast(user_data));
        return getInstanceProcAddress(self.instance.*, funcname);
    }
};
