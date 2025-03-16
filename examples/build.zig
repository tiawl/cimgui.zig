const std = @import("std");

const cimgui = @import("cimgui_zig");
const Platform = cimgui.Platform;
const Renderer = cimgui.Renderer;

fn platform(dir_name: []const u8) !Platform {
    return if (std.mem.indexOf(u8, dir_name, "_glfw") != null) .GLFW else if (std.mem.indexOf(u8, dir_name, "_sdl3") != null) .SDL3 else error.UnknownPlatformBackend;
}

fn renderer(dir_name: []const u8) !Renderer {
    return if (std.mem.indexOf(u8, dir_name, "_vulkan") != null) .Vulkan else if (std.mem.indexOf(u8, dir_name, "_opengl3") != null) .OpenGL3 else error.UnknownRendererBackend;
}

fn linkLibAndImportModules(lib: *std.Build.Step.Compile, exe: *std.Build.Step.Compile, dir_name: []const u8) void {
    if (std.mem.indexOf(u8, dir_name, "_opengl3") != null) {
        exe.root_module.addImport("gl", lib.root_module.import_table.get("gl").?);
        _ = lib.root_module.import_table.swapRemove("gl");
    }
    exe.linkLibrary(lib);
}

pub fn build(builder: *std.Build) !void {
    const target = builder.standardTargetOptions(.{});
    const optimize = .Debug;

    const pattern = builder.option([]const u8, "pattern", "Simple & stupid indexOf pattern matching to select examples") orelse "";

    var examples_dir =
        try builder.build_root.handle.openDir(".", .{
        .iterate = true,
    });
    defer examples_dir.close();

    var exe: *std.Build.Step.Compile = undefined;
    var cimgui_dep: *std.Build.Dependency = undefined;
    var it = examples_dir.iterate();
    while (try it.next()) |*entry| {
        if (entry.kind == .directory and
            std.mem.startsWith(u8, entry.name, "example_") and
            std.mem.indexOf(u8, entry.name, pattern) != null)
        {
            exe = builder.addExecutable(.{
                .name = entry.name,
                .root_source_file = .{
                    .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                        entry.name,
                        "main.zig",
                    }),
                },
                .target = target,
                .optimize = optimize,
            });

            cimgui_dep = builder.dependency("cimgui_zig", .{
                .target = target,
                .optimize = optimize,
                .platform = try platform(entry.name),
                .renderer = try renderer(entry.name),
            });

            linkLibAndImportModules(cimgui_dep.artifact("cimgui"), exe, entry.name);

            builder.installArtifact(exe);
        }
    }
}
