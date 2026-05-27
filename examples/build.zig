const std = @import("std");

const cimgui = @import("cimgui_zig");
const Platform = cimgui.Platform;
const Renderer = cimgui.Renderer;

const zigglgen = @import("zigglgen");

fn isPlatformUsed(dirname: []const u8, comptime platform: []const u8) bool {
    return (std.mem.startsWith(u8, dirname, "example_" ++ platform ++ "_") or
        std.mem.startsWith(u8, dirname, "example_" ++ platform ++ "+") or
        (std.mem.find(u8, dirname, "+" ++ platform ++ "_") != null) or
        (std.mem.find(u8, dirname, "+" ++ platform ++ "+") != null));
}

fn isRendererUsed(dirname: []const u8, comptime renderer: []const u8) bool {
    std.debug.assert(!std.mem.startsWith(u8, dirname, "example_" ++ renderer ++ "_"));
    std.debug.assert(!std.mem.startsWith(u8, dirname, "example_" ++ renderer ++ "+"));
    return (std.mem.endsWith(u8, dirname, "_" ++ renderer) or
        std.mem.endsWith(u8, dirname, "+" ++ renderer) or
        (std.mem.find(u8, dirname, "_" ++ renderer ++ "+") != null) or
        (std.mem.find(u8, dirname, "+" ++ renderer ++ "+") != null));
}

fn examplePlatforms(builder: *std.Build, dirname: []const u8) ![]const Platform {
    var platforms = std.array_list.Managed(Platform).init(builder.allocator);
    if (isPlatformUsed(dirname, "glfw")) try platforms.append(.GLFW);
    if (isPlatformUsed(dirname, "sdl3")) try platforms.append(.SDL3);
    if (isPlatformUsed(dirname, "zglfw")) try platforms.append(.GLFW);
    return platforms.toOwnedSlice();
}

fn exampleRenderers(builder: *std.Build, dirname: []const u8) ![]const Renderer {
    var renderers = std.array_list.Managed(Renderer).init(builder.allocator);
    if (isRendererUsed(dirname, "vulkan")) try renderers.append(.Vulkan);
    if (isRendererUsed(dirname, "zopengl3")) try renderers.append(.OpenGL3);
    if (isRendererUsed(dirname, "zvulkan")) try renderers.append(.Vulkan);
    if (isRendererUsed(dirname, "sdlgpu3")) try renderers.append(.SDLGPU3);
    if (isRendererUsed(dirname, "metal")) try renderers.append(.Metal);
    return renderers.toOwnedSlice();
}

fn commonModule(builder: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, build_types_module: *std.Build.Module, c_module: *std.Build.Module, zglfw_module: *std.Build.Module, zvulkan_module: *std.Build.Module, zopengl3_module: *std.Build.Module, dirname: []const u8) *std.Build.Module {
    const common_glfw_module = builder.createModule(.{
        .root_source_file = if (isPlatformUsed(dirname, "glfw") or isPlatformUsed(dirname, "zglfw")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "glfw.zig" }),
        } else builder.addWriteFiles().add("common_glfw.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "build",
                .module = build_types_module,
            },
        },
    });

    const common_zglfw_module = builder.createModule(.{
        .root_source_file = if (isPlatformUsed(dirname, "zglfw")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "zglfw.zig" }),
        } else builder.addWriteFiles().add("common_zglfw.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "build",
                .module = build_types_module,
            },
            .{
                .name = "common/glfw",
                .module = common_glfw_module,
            },
            .{
                .name = "zglfw",
                .module = zglfw_module,
            },
        },
    });

    const common_sdl3_module = builder.createModule(.{
        .root_source_file = if (isPlatformUsed(dirname, "sdl3")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "sdl3.zig" }),
        } else builder.addWriteFiles().add("common_sdl3.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "build",
                .module = build_types_module,
            },
        },
    });

    const common_sdlgpu3_module = builder.createModule(.{
        .root_source_file = if (isRendererUsed(dirname, "sdlgpu3")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "sdlgpu3.zig" }),
        } else builder.addWriteFiles().add("common_sdlgpu3.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "build",
                .module = build_types_module,
            },
            .{
                .name = "common/sdl3",
                .module = common_sdl3_module,
            },
        },
    });

    const common_opengl3_glfw_module = builder.createModule(.{
        .root_source_file = if ((isRendererUsed(dirname, "opengl3") or isRendererUsed(dirname, "zopengl3")) and (isPlatformUsed(dirname, "glfw") or isPlatformUsed(dirname, "zglfw"))) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "opengl3", "glfw.zig" }),
        } else builder.addWriteFiles().add("common_opengl3_glfw.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "common/glfw",
                .module = common_glfw_module,
            },
        },
    });

    const common_opengl3_sdl3_module = builder.createModule(.{
        .root_source_file = if ((isRendererUsed(dirname, "opengl3") or isRendererUsed(dirname, "zopengl3")) and isPlatformUsed(dirname, "sdl3")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "opengl3", "sdl3.zig" }),
        } else builder.addWriteFiles().add("common_opengl3_sdl3.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "common/sdl3",
                .module = common_sdl3_module,
            },
        },
    });

    const common_opengl3_zglfw_module = builder.createModule(.{
        .root_source_file = if ((isRendererUsed(dirname, "opengl3") or isRendererUsed(dirname, "zopengl3")) and isPlatformUsed(dirname, "zglfw")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "opengl3", "zglfw.zig" }),
        } else builder.addWriteFiles().add("common_opengl3_zglfw.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "common/zglfw",
                .module = common_zglfw_module,
            },
            .{
                .name = "common/opengl3/glfw",
                .module = common_opengl3_glfw_module,
            },
        },
    });

    const common_opengl3_module = builder.createModule(.{
        .root_source_file = if (isRendererUsed(dirname, "opengl3") or isRendererUsed(dirname, "zopengl3")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "opengl3.zig" }),
        } else builder.addWriteFiles().add("common_opengl3.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "build",
                .module = build_types_module,
            },
            .{
                .name = "common/opengl3/glfw",
                .module = common_opengl3_glfw_module,
            },
            .{
                .name = "common/opengl3/sdl3",
                .module = common_opengl3_sdl3_module,
            },
            .{
                .name = "common/opengl3/zglfw",
                .module = common_opengl3_zglfw_module,
            },
        },
    });

    const common_zopengl3_module = builder.createModule(.{
        .root_source_file = if (isRendererUsed(dirname, "zopengl3")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "zopengl3.zig" }),
        } else builder.addWriteFiles().add("common_zopengl3.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "build",
                .module = build_types_module,
            },
            .{
                .name = "common/opengl3/glfw",
                .module = common_opengl3_glfw_module,
            },
            .{
                .name = "common/opengl3/sdl3",
                .module = common_opengl3_sdl3_module,
            },
            .{
                .name = "common/opengl3/zglfw",
                .module = common_opengl3_zglfw_module,
            },
            .{
                .name = "common/opengl3",
                .module = common_opengl3_module,
            },
            .{
                .name = "zopengl3",
                .module = zopengl3_module,
            },
        },
    });

    const common_vulkan_glfw_module = builder.createModule(.{
        .root_source_file = if ((isRendererUsed(dirname, "vulkan") or isRendererUsed(dirname, "zvulkan")) and (isPlatformUsed(dirname, "glfw") or isPlatformUsed(dirname, "zglfw"))) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "vulkan", "glfw.zig" }),
        } else builder.addWriteFiles().add("common_vulkan_glfw.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "common/glfw",
                .module = common_glfw_module,
            },
        },
    });

    const common_vulkan_sdl3_module = builder.createModule(.{
        .root_source_file = if ((isRendererUsed(dirname, "vulkan") or isRendererUsed(dirname, "zvulkan")) and isPlatformUsed(dirname, "sdl3")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "vulkan", "sdl3.zig" }),
        } else builder.addWriteFiles().add("common_vulkan_sdl3.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "common/sdl3",
                .module = common_sdl3_module,
            },
        },
    });

    const common_vulkan_zglfw_module = builder.createModule(.{
        .root_source_file = if ((isRendererUsed(dirname, "vulkan") or isRendererUsed(dirname, "zvulkan")) and isPlatformUsed(dirname, "zglfw")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "vulkan", "zglfw.zig" }),
        } else builder.addWriteFiles().add("common_vulkan_zglfw.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "common/zglfw",
                .module = common_zglfw_module,
            },
            .{
                .name = "common/vulkan/glfw",
                .module = common_vulkan_glfw_module,
            },
        },
    });

    const common_vulkan_module = builder.createModule(.{
        .root_source_file = if (isRendererUsed(dirname, "vulkan") or isRendererUsed(dirname, "zvulkan")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "vulkan.zig" }),
        } else builder.addWriteFiles().add("common_vulkan.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "build",
                .module = build_types_module,
            },
            .{
                .name = "common/vulkan/glfw",
                .module = common_vulkan_glfw_module,
            },
            .{
                .name = "common/vulkan/sdl3",
                .module = common_vulkan_sdl3_module,
            },
            .{
                .name = "common/vulkan/zglfw",
                .module = common_vulkan_zglfw_module,
            },
        },
    });

    const common_zvulkan_glfw_module = builder.createModule(.{
        .root_source_file = if (isRendererUsed(dirname, "zvulkan") and (isPlatformUsed(dirname, "glfw") or isPlatformUsed(dirname, "zglfw"))) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "zvulkan", "glfw.zig" }),
        } else builder.addWriteFiles().add("common_zvulkan_glfw.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "common/vulkan/glfw",
                .module = common_vulkan_glfw_module,
            },
            .{
                .name = "zvulkan",
                .module = zvulkan_module,
            },
        },
    });

    const common_zvulkan_sdl3_module = builder.createModule(.{
        .root_source_file = if (isRendererUsed(dirname, "zvulkan") and isPlatformUsed(dirname, "sdl3")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "zvulkan", "sdl3.zig" }),
        } else builder.addWriteFiles().add("common_zvulkan_sdl3.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "common/vulkan/sdl3",
                .module = common_vulkan_sdl3_module,
            },
            .{
                .name = "zvulkan",
                .module = zvulkan_module,
            },
        },
    });

    const common_zvulkan_zglfw_module = builder.createModule(.{
        .root_source_file = if (isRendererUsed(dirname, "zvulkan") and isPlatformUsed(dirname, "zglfw")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "zvulkan", "zglfw.zig" }),
        } else builder.addWriteFiles().add("common_zvulkan_zglfw.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "common/vulkan/zglfw",
                .module = common_vulkan_zglfw_module,
            },
            .{
                .name = "zglfw",
                .module = zglfw_module,
            },
            .{
                .name = "zvulkan",
                .module = zvulkan_module,
            },
        },
    });

    const common_zvulkan_module = builder.createModule(.{
        .root_source_file = if (isRendererUsed(dirname, "zvulkan")) .{
            .cwd_relative = builder.pathJoin(&.{ "common", "zvulkan.zig" }),
        } else builder.addWriteFiles().add("common_zvulkan.zig", ""),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "build",
                .module = build_types_module,
            },
            .{
                .name = "common/vulkan",
                .module = common_vulkan_module,
            },
            .{
                .name = "common/zvulkan/glfw",
                .module = common_zvulkan_glfw_module,
            },
            .{
                .name = "common/zvulkan/sdl3",
                .module = common_zvulkan_sdl3_module,
            },
            .{
                .name = "common/zvulkan/zglfw",
                .module = common_zvulkan_zglfw_module,
            },
            .{
                .name = "zvulkan",
                .module = zvulkan_module,
            },
        },
    });

    return builder.createModule(.{
        .root_source_file = .{
            .cwd_relative = builder.pathJoin(&.{ "common", "index.zig" }),
        },
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "c",
                .module = c_module,
            },
            .{
                .name = "build",
                .module = build_types_module,
            },
            .{
                .name = "common/glfw",
                .module = common_glfw_module,
            },
            .{
                .name = "common/opengl3",
                .module = common_opengl3_module,
            },
            .{
                .name = "common/sdl3",
                .module = common_sdl3_module,
            },
            .{
                .name = "common/sdlgpu3",
                .module = common_sdlgpu3_module,
            },
            .{
                .name = "common/vulkan",
                .module = common_vulkan_module,
            },
            .{
                .name = "common/zglfw",
                .module = common_zglfw_module,
            },
            .{
                .name = "common/zopengl3",
                .module = common_zopengl3_module,
            },
            .{
                .name = "common/zvulkan",
                .module = common_zvulkan_module,
            },
        },
    });
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

    const verbose = builder.option(bool, "verbose", "Verbose mode") orelse true;
    const docking = builder.option(bool, "docking", "use master or docking ocornut/imgui branch ?") orelse false;

    var examples_dir = try builder.build_root.handle.openDir(builder.graph.io, ".", .{
        .iterate = true,
    });
    defer examples_dir.close(builder.graph.io);

    const zigglgen_module = zigglgen.generateBindingsModule(builder, .{
        .api = .gl,
        .version = .@"4.6",
        .profile = .core,
        .extensions = &.{},
    });

    const vulkan_headers_dep = builder.dependency("cimgui_zig", .{
        .target = target,
        .optimize = optimize,
        .platforms = &[_]Platform{},
        .renderers = &[_]Renderer{.Vulkan},
        .no_platform = true,
    }).builder.dependency("vulkan_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const vulkan_zig_dep = builder.dependency("vulkan", .{
        .registry = vulkan_headers_dep.path(builder.pathJoin(&.{ "vulkan", "registry", "vk.xml" })),
        .target = target,
        .optimize = optimize,
    });
    const vulkan_zig_module = vulkan_zig_dep.module("vulkan-zig");
    const zglfw_dep = builder.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    const zglfw_module = zglfw_dep.module("glfw");

    var build_types = builder.addOptions();
    build_types.addOption(extended_platforms: {
        const zig_platforms = &[_][]const u8{"zGLFW"};
        var values: [std.meta.fieldNames(cimgui.Platform).len + zig_platforms.len]u32 = undefined;
        for (0..values.len) |i| values[i] = i;
        break :extended_platforms @Enum(u32, .exhaustive, std.meta.fieldNames(cimgui.Platform) ++ zig_platforms, &values);
    }, "dummy_platform", .GLFW);
    build_types.addOption(extended_renderers: {
        const zig_renderers = &[_][]const u8{ "zVulkan", "zOpenGL3" };
        var values: [std.meta.fieldNames(cimgui.Renderer).len + zig_renderers.len]u32 = undefined;
        for (0..values.len) |i| values[i] = i;
        break :extended_renderers @Enum(u32, .exhaustive, std.meta.fieldNames(cimgui.Renderer) ++ zig_renderers, &values);
    }, "dummy_renderer", .Vulkan);
    const build_types_module = build_types.createModule();

    var platforms: []const Platform = undefined;
    var renderers: []const Renderer = undefined;
    var options: *std.Build.Step.Options = undefined;
    var translate_c: *std.Build.Step.TranslateC = undefined;
    var c_module: *std.Build.Module = undefined;
    var cimgui_dep: *std.Build.Dependency = undefined;
    var cimgui_artifact: *std.Build.Step.Compile = undefined;
    var exe: *std.Build.Step.Compile = undefined;
    var it = examples_dir.iterate();
    while (try it.next(builder.graph.io)) |*entry| {
        if (entry.kind == .directory and std.mem.startsWith(u8, entry.name, "example_")) {
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

            platforms = try examplePlatforms(builder, entry.name);
            renderers = try exampleRenderers(builder, entry.name);

            cimgui_dep = builder.dependency("cimgui_zig", .{
                .target = target,
                .optimize = optimize,
                .platforms = platforms,
                .renderers = renderers,
                .docking = docking,
            });

            cimgui_artifact = cimgui_dep.artifact("cimgui");

            addIncludePathsToTranslateC(translate_c, cimgui_artifact);

            c_module = translate_c.createModule();
            c_module.linkLibrary(cimgui_artifact);

            options = builder.addOptions();
            options.addOption([:0]const u8, "name", try builder.allocator.dupeSentinel(u8, entry.name, 0));

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
                        .{
                            .name = "build_options",
                            .module = options.createModule(),
                        },
                        .{
                            .name = "build_types",
                            .module = build_types_module,
                        },
                        .{
                            .name = "common",
                            .module = commonModule(builder, target, optimize, build_types_module, c_module, zglfw_module, vulkan_zig_module, zigglgen_module, entry.name),
                        },
                    },
                }),
            });

            if (verbose) std.log.debug("{s} built", .{entry.name});

            builder.installArtifact(exe);
        }
    }
}
