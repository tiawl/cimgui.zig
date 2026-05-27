// The command line to run it with Vulkan backend:
// $ ./zig-out/bin/example_zglfw_vulkan+zopengl3
// The command line to run it with zOpenGL3 backend:
// $ env RENDERER=zOpenGL3 ./zig-out/bin/example_zglfw_vulkan+zopengl3

const std = @import("std");
const common = @import("common");
const build = struct {
    const Platform = @TypeOf(@import("build_types").dummy_platform);
    const Renderer = @TypeOf(@import("build_types").dummy_renderer);
    const options = @import("build_options");
};

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const platform: build.Platform = .zGLFW;
    const default_renderer: build.Renderer = .Vulkan;
    switch (std.meta.stringToEnum(build.Renderer, init.environ_map.get("RENDERER") orelse @tagName(default_renderer)) orelse return error.UnknownRendererBackend) {
        inline default_renderer, .zOpenGL3 => |renderer| {
            try common.init(platform, renderer, allocator, build.options.name ++ ": " ++ @tagName(renderer) ++ " backend used", common.window.width, common.window.height, build.options.name);
            defer common.deinit(platform, renderer, allocator);

            try common.loop(platform, renderer, allocator);
        },
        else => return error.Renderer,
    }
}
