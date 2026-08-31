const std = @import("std");
const c = @import("c");
const vk = @import("zvulkan");
const sdl3 = @import("common/vulkan/sdl3");

extern fn SDL_Vulkan_CreateSurface(window: *c.SDL_Window, instance: vk.Instance, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) bool;
extern fn SDL_Vulkan_DestroySurface(instance: vk.Instance, surface: vk.SurfaceKHR, allocation_callbacks: ?*const vk.AllocationCallbacks) void;

pub var getInstanceProcAddress: vk.PfnGetInstanceProcAddr = undefined;

pub fn initInstanceProcAddress() void {
    getInstanceProcAddress = @ptrCast(sdl3.getVkGetInstanceProcAddress());
}

pub var loader: Loader = undefined;
pub const loadFn = Loader.load;

pub const getRequiredInstanceExtensions = sdl3.getRequiredInstanceExtensions;
pub const getFramebufferSize = sdl3.getFramebufferSize;

pub fn createWindowSurface(instance: *vk.Instance, surface: *vk.SurfaceKHR) vk.Result {
    if (SDL_Vulkan_CreateSurface(sdl3.sdl3.window, instance.*, null, surface)) return .success;
    unreachable;
}

pub fn destroyWindowSurface(instance: *vk.Instance, surface: *vk.SurfaceKHR) void {
    SDL_Vulkan_DestroySurface(instance.*, surface.*, null);
}

pub const finalizeSetupWindow = sdl3.finalizeSetupWindow;
pub const initForVulkan = sdl3.initForVulkan;
pub const shutdown = sdl3.shutdown;

const Loader = struct {
    instance: *vk.Instance,
    device: *vk.Device,

    fn loadGlobal(name: [*c]const u8) vk.PfnVoidFunction {
        return getInstanceProcAddress(null, name);
    }

    fn loadInstance(self: *const @This(), name: [*c]const u8) vk.PfnVoidFunction {
        return getInstanceProcAddress(self.instance.*, name);
    }

    fn loadDevice(self: *const @This(), name: [*c]const u8) vk.PfnVoidFunction {
        return @as(vk.PfnGetDeviceProcAddr, @ptrCast(self.loadInstance("vkGetDeviceProcAddr")))(self.device.*, name);
    }

    fn load(funcname: [*c]const u8, user_data: ?*anyopaque) callconv(std.builtin.CallingConvention.c) vk.PfnVoidFunction {
        var self: *@This() = @ptrCast(@alignCast(user_data));
        if (self.loadDevice(funcname)) |func| return func;
        if (self.loadInstance(funcname)) |func| return func;
        if (loadGlobal(funcname)) |func| return func;
        return null;
    }
};
