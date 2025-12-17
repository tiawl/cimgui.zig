const std = @import("std");

const cimgui = @import("cimgui_zig");
const Platform = cimgui.Platform;
const Renderer = cimgui.Renderer;

fn platforms(dir_name: []const u8) ![]const Platform {
    return if (std.mem.startsWith(u8, dir_name, "example_glfw_")) &.{
        .GLFW,
    } else if (std.mem.startsWith(u8, dir_name, "example_sdl3_")) &.{
        .SDL3,
    } else if (std.mem.startsWith(u8, dir_name, "example_sdlgpu3_")) &.{
        .SDLGPU3,
    } else error.UnknownPlatformBackend;
}

fn renderers(dir_name: []const u8) ![]const Renderer {
    return if (std.mem.endsWith(u8, dir_name, "_vulkan")) &.{
        .Vulkan,
    } else if (std.mem.endsWith(u8, dir_name, "_opengl3")) &.{
        .OpenGL3,
    } else if (std.mem.endsWith(u8, dir_name, "_vulkan+opengl3")) &.{
        .Vulkan, .OpenGL3,
    } else if (std.mem.indexOf(u8, dir_name, "_metal") != null) &.{
        .Metal,
    } else error.UnknownRendererBackend;
}

fn linkLibAndImportModules(lib: *std.Build.Step.Compile, exe: *std.Build.Step.Compile, dir_name: []const u8) void {
    if (std.mem.endsWith(u8, dir_name, "_opengl3") or std.mem.endsWith(u8, dir_name, "_vulkan+opengl3")) {
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
    const logging = builder.option(bool, "toolbox-logging", "toolbox logging") orelse false;
    while (try it.next()) |*entry| {
        if (entry.kind == .directory and
            std.mem.startsWith(u8, entry.name, "example_") and
            std.mem.indexOf(u8, entry.name, pattern) != null)
        {
            exe = builder.addExecutable(.{
                .name = entry.name,
                .root_module = std.Build.Module.create(builder, .{
                    .root_source_file = .{
                        .cwd_relative = try builder.build_root.join(builder.allocator, &.{
                            entry.name,
                            "main.zig",
                        }),
                    },
                    .target = target,
                    .optimize = optimize,
                }),
            });

            cimgui_dep = builder.dependency("cimgui_zig", .{
                .target = target,
                .optimize = optimize,
                .platforms = try platforms(entry.name),
                .renderers = try renderers(entry.name),
                .@"toolbox-logging" = logging,
            });

            linkLibAndImportModules(cimgui_dep.artifact("cimgui"), exe, entry.name);

            builder.installArtifact(exe);
        }
    }
}
