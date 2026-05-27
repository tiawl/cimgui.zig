const std = @import("std");
const build = struct {
    const Platform = @TypeOf(@import("build_types").dummy_platform);
    const Renderer = @TypeOf(@import("build_types").dummy_renderer);
    const options = @import("build_options");
};
const common = @import("common");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const platform: build.Platform = .GLFW;
    const renderer: build.Renderer = .zVulkan;
    try common.init(platform, renderer, allocator, build.options.name, common.window.width, common.window.height, build.options.name);
    defer common.deinit(platform, renderer, allocator);

    try common.loop(platform, renderer, allocator);
}
