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

fn addIncludePathsToTranslateC(translate_c: *std.Build.Step.TranslateC, lib: *std.Build.Step.Compile) void {
    for (lib.root_module.include_dirs.items) |*included| {
        switch (included.*) {
            .path => translate_c.addIncludePath(included.path),
            .config_header_step => translate_c.addConfigHeader(included.config_header_step),
            .path_system => translate_c.addSystemIncludePath(included.path_system),
            .other_step => addIncludePathsToTranslateC(translate_c, included.other_step),
            else => unreachable,
        }
    }
}

pub fn build(builder: *std.Build) !void {
    const target = builder.standardTargetOptions(.{});
    const optimize = .Debug;

    const pattern = builder.option([]const u8, "pattern", "Simple & stupid indexOf pattern matching to select examples") orelse "";

    var examples_dir = try builder.build_root.handle.openDir(builder.graph.io, ".", .{
        .iterate = true,
    });
    defer examples_dir.close(builder.graph.io);

    var translate_c: *std.Build.Step.TranslateC = undefined;
    var c_module: *std.Build.Module = undefined;
    var cimgui_dep: *std.Build.Dependency = undefined;
    var cimgui_artifact: *std.Build.Step.Compile = undefined;
    var exe: *std.Build.Step.Compile = undefined;
    var it = examples_dir.iterate();
    const docking = builder.option(bool, "docking", "use master or docking ocornut/imgui branch ?") orelse false;
    while (try it.next(builder.graph.io)) |*entry| {
        if (entry.kind == .directory and
            std.mem.startsWith(u8, entry.name, "example_") and
            std.mem.indexOf(u8, entry.name, pattern) != null)
        {
            // Skip Metal examples on non-macOS targets
            if (std.mem.indexOf(u8, entry.name, "_metal") != null) {
                if (target.result.os.tag != .macos and target.result.os.tag != .ios) {
                    std.log.info("Skipping {s} (Metal only available on macOS/iOS)", .{entry.name});
                    continue;
                }
            }

            translate_c = builder.addTranslateC(.{
                .root_source_file = builder.path(builder.pathJoin(&.{
                    entry.name, "c.h",
                })),
                .target = target,
                .optimize = optimize,
            });

            cimgui_dep = builder.dependency("cimgui_zig", .{
                .target = target,
                .optimize = optimize,
                .platforms = try platforms(entry.name),
                .renderers = try renderers(entry.name),
                .docking = docking,
            });

            cimgui_artifact = cimgui_dep.artifact("cimgui");

            addIncludePathsToTranslateC(translate_c, cimgui_artifact);

            c_module = translate_c.createModule();
            c_module.linkLibrary(cimgui_artifact);

            exe = builder.addExecutable(.{
                .name = entry.name,
                .root_module = std.Build.Module.create(builder, .{
                    .root_source_file = builder.path(builder.pathJoin(&.{
                        entry.name, "main.zig",
                    })),
                    .target = target,
                    .optimize = optimize,
                    .imports = &.{
                        .{
                            .name = "c",
                            .module = c_module,
                        },
                    },
                }),
            });

            if (std.mem.endsWith(u8, entry.name, "_opengl3") or std.mem.endsWith(u8, entry.name, "_vulkan+opengl3")) {
                exe.root_module.addImport("gl", cimgui_artifact.root_module.import_table.get("gl").?);
                _ = cimgui_artifact.root_module.import_table.swapRemove("gl");
            }

            builder.installArtifact(exe);
        }
    }
}
