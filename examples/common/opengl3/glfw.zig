const c = @import("c");
const glfw = @import("common/glfw");

pub fn initForOpenGL() !void {
    _ = c.cImGui_ImplGlfw_InitForOpenGL(glfw.window, true);
}

pub const shutdown = glfw.shutdown;
pub const loader = c.glfwGetProcAddress;

pub const createContext = glfw.createContext;
pub const destroyContext = glfw.destroyContext;
pub const getFramebufferSize = glfw.getFramebufferSize;
pub const swapBuffers = glfw.swapBuffers;
