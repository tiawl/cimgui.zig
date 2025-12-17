const std = @import("std");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_metal.h");
    @cInclude("dcimgui.h");
    @cInclude("backends/dcimgui_impl_sdl3.h");
    @cInclude("backends/dcimgui_impl_metal.h");
});

// Objective-C runtime functions for calling Metal APIs from C
extern "C" fn objc_msgSend() void;
extern "C" fn sel_registerName(name: [*c]const u8) ?*anyopaque;
extern "C" fn objc_getClass(name: [*c]const u8) ?*anyopaque;

// Simple Objective-C message send helpers
fn msgSend0(obj: ?*anyopaque, sel_name: [*c]const u8) ?*anyopaque {
    const sel = sel_registerName(sel_name);
    const SendFn = *const fn (?*anyopaque, ?*anyopaque) callconv(std.builtin.CallingConvention.c) ?*anyopaque;
    const func: SendFn = @ptrCast(&objc_msgSend);
    return func(obj, sel);
}

fn msgSend1(obj: ?*anyopaque, sel_name: [*c]const u8, arg: anytype) ?*anyopaque {
    const sel = sel_registerName(sel_name);
    const SendFn = *const fn (?*anyopaque, ?*anyopaque, @TypeOf(arg)) callconv(std.builtin.CallingConvention.c) ?*anyopaque;
    const func: SendFn = @ptrCast(&objc_msgSend);
    return func(obj, sel, arg);
}

fn msgSendVoid1(obj: ?*anyopaque, sel_name: [*c]const u8, arg: anytype) void {
    const sel = sel_registerName(sel_name);
    const SendFn = *const fn (?*anyopaque, ?*anyopaque, @TypeOf(arg)) callconv(std.builtin.CallingConvention.c) void;
    const func: SendFn = @ptrCast(&objc_msgSend);
    func(obj, sel, arg);
}

fn msgSendVoid0(obj: ?*anyopaque, sel_name: [*c]const u8) void {
    const sel = sel_registerName(sel_name);
    const SendFn = *const fn (?*anyopaque, ?*anyopaque) callconv(std.builtin.CallingConvention.c) void;
    const func: SendFn = @ptrCast(&objc_msgSend);
    func(obj, sel);
}

pub fn main() !void {
    if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_GAMEPAD)) {
        std.log.err("SDL Init failed : {s}", .{c.SDL_GetError()});
        return;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("example_sdl3_metal", 800, 600, c.SDL_WINDOW_METAL | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_HIGH_PIXEL_DENSITY);
    if (window == null) {
        std.log.err("SDL create window failed : {s}", .{c.SDL_GetError()});
        return;
    }
    defer c.SDL_DestroyWindow(window);

    const metal_view = c.SDL_Metal_CreateView(window);
    if (metal_view == null) {
        std.log.err("SDL_Metal_CreateView failed : {s}", .{c.SDL_GetError()});
        return;
    }
    defer c.SDL_Metal_DestroyView(metal_view);

    const metal_layer = c.SDL_Metal_GetLayer(metal_view);
    if (metal_layer == null) {
        std.log.err("SDL_Metal_GetLayer failed", .{});
        return;
    }

    // Get Metal device from layer (CAMetalLayer.device property)
    const metal_device = msgSend0(metal_layer, "device");
    if (metal_device == null) {
        std.log.err("Failed to get Metal device from layer", .{});
        return;
    }

    // Create command queue
    const command_queue = msgSend0(metal_device, "newCommandQueue");
    if (command_queue == null) {
        std.log.err("Failed to create Metal command queue", .{});
        return;
    }

    _ = c.CIMGUI_CHECKVERSION();
    _ = c.ImGui_CreateContext(null);
    defer c.ImGui_DestroyContext(null);

    const imio = c.ImGui_GetIO();
    imio.*.ConfigFlags = c.ImGuiConfigFlags_NavEnableKeyboard;

    c.ImGui_StyleColorsDark(null);

    _ = c.cImGui_ImplSDL3_InitForMetal(window.?);
    defer c.cImGui_ImplSDL3_Shutdown();
    
    _ = c.cImGui_ImplMetal_Init(metal_device);
    defer c.cImGui_ImplMetal_Shutdown();

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

        // Get next drawable from layer
        const drawable = msgSend0(metal_layer, "nextDrawable");
        if (drawable == null) continue;

        // Get texture from drawable
        const texture = msgSend0(drawable, "texture");

        // Create render pass descriptor
        const MTLRenderPassDescriptor = objc_getClass("MTLRenderPassDescriptor");
        const render_pass_descriptor = msgSend0(MTLRenderPassDescriptor, "renderPassDescriptor");
        
        // Configure color attachment
        const colorAttachments = msgSend0(render_pass_descriptor, "colorAttachments");
        const colorAttachment = msgSend1(colorAttachments, "objectAtIndexedSubscript:", @as(c_ulong, 0));
        
        msgSendVoid1(colorAttachment, "setTexture:", texture);
        msgSendVoid1(colorAttachment, "setLoadAction:", @as(c_ulong, 2)); // MTLLoadActionClear = 2
        msgSendVoid1(colorAttachment, "setStoreAction:", @as(c_ulong, 1)); // MTLStoreActionStore = 1

        c.cImGui_ImplMetal_NewFrame(render_pass_descriptor);
        c.cImGui_ImplSDL3_NewFrame();
        c.ImGui_NewFrame();

        c.ImGui_ShowDemoWindow(null);

        c.ImGui_Render();

        // Create command buffer
        const command_buffer = msgSend0(command_queue, "commandBuffer");
        
        // Create render command encoder
        const command_encoder = msgSend1(command_buffer, "renderCommandEncoderWithDescriptor:", render_pass_descriptor);

        // Render ImGui
        c.cImGui_ImplMetal_RenderDrawData(c.ImGui_GetDrawData(), command_buffer, command_encoder);

        // End encoding
        msgSendVoid0(command_encoder, "endEncoding");

        // Present drawable
        msgSendVoid1(command_buffer, "presentDrawable:", drawable);

        // Commit command buffer
        msgSendVoid0(command_buffer, "commit");
    }
}
