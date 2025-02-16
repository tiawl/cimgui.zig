const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_opengl.h");
    @cInclude("dcimgui.h");
    @cInclude("backends/dcimgui_impl_sdl3.h");
    @cInclude("backends/dcimgui_impl_opengl3.h");
});

pub fn main() !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_GAMEPAD)) {
        std.log.err("SDL Init failed : {s}", .{c.SDL_GetError()});
        return;
    }
    defer c.SDL_Quit();

    const GLSL_VERSION = "#version 130";
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_FLAGS, 0);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 0);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_STENCIL_SIZE, 8);

    const window = c.SDL_CreateWindow("example_sdl3_opengl3", 800, 600, c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE);
    if (window == null) {
        std.log.err("SDL create window failed : {s}", .{c.SDL_GetError()});
        return;
    }
    defer c.SDL_DestroyWindow(window);

    const context = c.SDL_GL_CreateContext(window);
    if (context == null) {
        std.log.err("SDL create context failed : {s}", .{c.SDL_GetError()});
        return;
    }
    defer _ = c.SDL_GL_DestroyContext(context);

    _ = c.SDL_GL_MakeCurrent(window, context);
    _ = c.SDL_GL_SetSwapInterval(1);

    _ = c.CIMGUI_CHECKVERSION();
    _ = c.ImGui_CreateContext(null);
    defer c.ImGui_DestroyContext(null);

    const imio = c.ImGui_GetIO();
    imio.*.ConfigFlags = c.ImGuiConfigFlags_NavEnableKeyboard;

    c.ImGui_StyleColorsDark(null);

    _ = c.cImGui_ImplSDL3_InitForOpenGL(window.?, context.?);
    defer c.cImGui_ImplSDL3_Shutdown();
    _ = c.cImGui_ImplOpenGL3_InitEx(GLSL_VERSION);
    defer c.cImGui_ImplOpenGL3_Shutdown();

    main_loop: while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            _ = c.cImGui_ImplSDL3_ProcessEvent(&event);
            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    break :main_loop;
                },
                else => {},
            }
        }

        c.cImGui_ImplOpenGL3_NewFrame();
        c.cImGui_ImplSDL3_NewFrame();
        c.ImGui_NewFrame();

        c.ImGui_ShowDemoWindow(null);

        c.ImGui_Render();

        c.glViewport(0, 0, @intFromFloat(imio.*.DisplaySize.x), @intFromFloat(imio.*.DisplaySize.y));
        c.glClearColor(0.0, 0.0, 0.0, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);
        c.cImGui_ImplOpenGL3_RenderDrawData(c.ImGui_GetDrawData());
        _ = c.SDL_GL_SwapWindow(window);
    }
}
