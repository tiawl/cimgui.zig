const c = @import("c");
const zglfw = @import("common/zglfw");
const glfw = @import("common/opengl3/glfw");

pub fn initForOpenGL() !void {
    _ = c.cImGui_ImplGlfw_InitForOpenGL(@ptrCast(@alignCast(zglfw.window)), true);
}

pub const shutdown = glfw.shutdown;
pub const loader = zglfw.getProcAddress;

pub const createContext = zglfw.createContext;
pub const destroyContext = zglfw.destroyContext;
pub const getFramebufferSize = zglfw.getFramebufferSize;
pub const swapBuffers = zglfw.swapBuffers;
