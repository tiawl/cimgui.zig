const c = @import("c");
const sdl3 = @import("common/sdl3");

pub fn initForOpenGL() !void {
    _ = c.cImGui_ImplSDL3_InitForOpenGL(sdl3.window, sdl3.context);
}

pub const shutdown = sdl3.shutdown;
pub const loader = c.SDL_GL_GetProcAddress;

pub const createContext = sdl3.createContext;
pub const destroyContext = sdl3.destroyContext;
pub const getFramebufferSize = sdl3.getFramebufferSize;
pub const swapBuffers = sdl3.swapBuffers;
