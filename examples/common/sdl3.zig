const std = @import("std");
const c = @import("c");
const build = struct {
    const Renderer = @TypeOf(@import("build").dummy_renderer);
};

const vk = struct {
    fn createWindow(title: [*c]const u8, width: c_int, height: c_int) ?*c.SDL_Window {
        return c.SDL_CreateWindow(title, width, height, c.SDL_WINDOW_VULKAN | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_HIGH_PIXEL_DENSITY);
    }
};

const sdlgpu3 = struct {
    fn createWindow(title: [*c]const u8, width: c_int, height: c_int) ?*c.SDL_Window {
        return c.SDL_CreateWindow(title, width, height, c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_HIDDEN | c.SDL_WINDOW_HIGH_PIXEL_DENSITY);
    }
};

const zopengl3 = struct {
    fn createWindow(title: [*c]const u8, width: c_int, height: c_int) ?*c.SDL_Window {
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_FLAGS, 0);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 0);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_STENCIL_SIZE, 8);

        return c.SDL_CreateWindow(title, width, height, c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE);
    }
};

fn renderer(comptime backend: build.Renderer) type {
    return switch (backend) {
        .Vulkan, .zVulkan => vk,
        .SDLGPU3 => sdlgpu3,
        .zOpenGL3 => zopengl3,
        else => unreachable,
    };
}

pub var window: *c.SDL_Window = undefined;
pub var context: c.SDL_GLContext = undefined;
var opened = true;

/// Converts the return value of an SDL function to an error union.
pub inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    } catch |err| switch (err) {
        error.SdlError => {
            std.log.err("SDL error: {s}", .{c.SDL_GetError()});
            return err;
        },
        else => unreachable,
    };
}

pub fn createWindow(comptime r: build.Renderer, title: [*c]const u8, width: c_int, height: c_int) !void {
    try errify(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_GAMEPAD));
    errdefer c.SDL_Quit();

    window = try errify(renderer(r).createWindow(title, width, height));
}

pub fn destroyWindow() void {
    c.SDL_DestroyWindow(window);
    c.SDL_Quit();
}

pub fn getFramebufferSize(width: *i32, height: *i32) !void {
    try errify(c.SDL_GetWindowSize(window, width, height));
}

pub fn createContext() !void {
    context = try errify(c.SDL_GL_CreateContext(window));
    errdefer destroyContext();
    _ = c.SDL_GL_MakeCurrent(window, context);
    _ = c.SDL_GL_SetSwapInterval(1);
}

pub fn destroyContext() void {
    _ = c.SDL_GL_DestroyContext(context);
}

pub fn shouldClose() bool {
    return !opened;
}

pub fn pollEvents() void {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event)) {
        _ = c.cImGui_ImplSDL3_ProcessEvent(&event);
        switch (event.type) {
            c.SDL_EVENT_QUIT => opened = false,
            c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => if (event.window.windowID == c.SDL_GetWindowID(window)) {
                opened = false;
            },
            else => {},
        }
    }
}

pub fn newFrame() void {
    c.cImGui_ImplSDL3_NewFrame();
}

pub fn swapBuffers() void {
    _ = c.SDL_GL_SwapWindow(window);
}

pub fn finalizeSetupWindow() !void {
    try errify(c.SDL_SetWindowPosition(window, c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED));
    try errify(c.SDL_ShowWindow(window));
}

pub const shutdown = c.cImGui_ImplSDL3_Shutdown;
