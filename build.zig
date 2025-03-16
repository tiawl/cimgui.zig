const std = @import("std");
const toolbox = @import("toolbox");

const utils = @import("build/utils.zig");
const Paths = utils.Paths;
const flags_size = utils.flags_size;

const backends = @import("build/backends.zig");
pub const Renderer = backends.Renderer;
pub const Platform = backends.Platform;
const backendOptions = backends.backendOptions;

fn update(builder: *std.Build, path: *const Paths, dependencies: *const toolbox.Dependencies) !void {
    for ([_][]const u8{
        path.getDcimgui(),
        path.getTmp(),
    }) |clone_path| {
        std.fs.deleteTreeAbsolute(clone_path) catch |err|
            {
            switch (err) {
                error.FileNotFound => {},
                else => return err,
            }
        };
    }

    try dependencies.clone(builder, "imgui", path.getDcimgui());

    var dcimgui_dir = try std.fs.openDirAbsolute(path.getDcimgui(), .{
        .iterate = true,
    });
    defer dcimgui_dir.close();

    var it = dcimgui_dir.iterate();
    while (try it.next()) |*entry| {
        if (!std.mem.eql(u8, entry.name, "backends") and
            !std.mem.startsWith(u8, entry.name, "im"))
            try std.fs.deleteTreeAbsolute(try std.fs.path.join(builder.allocator, &.{
                path.getDcimgui(),
                entry.name,
            }));
    }

    var backends_dir = try std.fs.openDirAbsolute(path.getBackends(), .{
        .iterate = true,
    });
    defer backends_dir.close();

    try dependencies.clone(builder, "dcimgui", path.getTmp());

    const binding_py = try std.fs.path.join(builder.allocator, &.{
        path.getTmp(),
        "dear_bindings.py",
    });
    const imconfig_h = try std.fs.path.join(builder.allocator, &.{
        path.getDcimgui(),
        "imconfig.h",
    });
    const imgui_h = try std.fs.path.join(builder.allocator, &.{
        path.getDcimgui(),
        "imgui.h",
    });
    const imgui_out = try std.fs.path.join(builder.allocator, &.{
        path.getDcimgui(),
        "dcimgui",
    });
    try toolbox.run(builder, .{
        .argv = &[_][]const u8{
            "python3",  binding_py,
            "--output", imgui_out,
            imgui_h,
        },
    });

    const templates = try std.fs.path.join(builder.allocator, &.{
        path.getTmp(),
        "src",
        "templates",
    });
    var templates_dir = try std.fs.openDirAbsolute(templates, .{
        .iterate = true,
    });
    defer templates_dir.close();

    var backend_h: []const u8 = undefined;
    var backend_cpp: []const u8 = undefined;
    var out: []const u8 = undefined;
    it = backends_dir.iterate();
    while (try it.next()) |*entry| {
        switch (entry.kind) {
            .file => {
                const stem = std.fs.path.stem(entry.name);
                const cpp_template = try std.fs.path.join(builder.allocator, &.{
                    templates,
                    builder.fmt("{s}-header-template.cpp", .{
                        stem,
                    }),
                });
                const h_template = try std.fs.path.join(builder.allocator, &.{
                    templates,
                    builder.fmt("{s}-header-template.h", .{
                        stem,
                    }),
                });
                backend_cpp = try std.fs.path.join(builder.allocator, &.{
                    path.getBackends(),
                    builder.fmt("{s}.cpp", .{
                        stem,
                    }),
                });
                if (toolbox.isCHeader(entry.name) and toolbox.exists(backend_cpp) and std.mem.startsWith(u8, entry.name, "imgui") and !std.meta.isError(std.fs.accessAbsolute(cpp_template, .{})) and !std.meta.isError(std.fs.accessAbsolute(h_template, .{}))) {
                    backend_h = try std.fs.path.join(builder.allocator, &.{
                        path.getBackends(),
                        entry.name,
                    });
                    out = try std.fs.path.join(builder.allocator, &.{
                        path.getBackends(),
                        builder.fmt("dc{s}", .{
                            stem,
                        }),
                    });
                    try toolbox.run(builder, .{
                        .argv = &[_][]const u8{
                            "python3",
                            binding_py,
                            "--backend",
                            "--include",
                            imgui_h,
                            "--imconfig-path",
                            imconfig_h,
                            "--output",
                            out,
                            backend_h,
                        },
                    });
                }
            },
            else => {},
        }
    }

    try std.fs.deleteTreeAbsolute(path.getTmp());
    try toolbox.clean(builder, &.{
        "dcimgui",
    }, &.{});
}

pub fn build(builder: *std.Build) !void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    const path = try Paths.init(builder);

    const dependencies = try toolbox.Dependencies.init(builder, "cimgui.zig", &.{
        "build",
        "dcimgui",
    }, .{
        .toolbox = .{
            .name = "tiawl/toolbox",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.commit,
        },
        .vulkan_zig = .{
            .name = "tiawl/vulkan.zig",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.commit,
        },
        .glfw_zig = .{
            .name = "tiawl/glfw.zig",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.commit,
        },
        .sdl = .{
            .name = "castholm/SDL",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.commit,
        },
        .zigglgen = .{
            .name = "castholm/zigglgen",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.commit,
        },
    }, .{
        .imgui = .{
            .name = "ocornut/imgui",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.tag,
        },
        .dcimgui = .{
            .name = "dearimgui/dear_bindings",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.commit,
        },
    });

    if (builder.option(bool, "update", "Update binding") orelse false)
        try update(builder, &path, &dependencies);

    const lib = builder.addStaticLibrary(.{
        .name = "cimgui",
        .root_source_file = builder.addWriteFiles().add("empty.c", ""),
        .target = target,
        .optimize = optimize,
    });

    var flags = try std.BoundedArray([]const u8, flags_size).init(0);

    var root_dir = try builder.build_root.handle.openDir(".", .{
        .iterate = true,
    });
    defer root_dir.close();

    var walk = try root_dir.walk(builder.allocator);

    while (try walk.next()) |*entry| {
        if (std.mem.startsWith(u8, entry.path, "dcimgui") and
            entry.kind == .directory) toolbox.addInclude(lib, entry.path);
    }

    var dcimgui_dir = try std.fs.openDirAbsolute(path.getDcimgui(), .{
        .iterate = true,
    });
    defer dcimgui_dir.close();

    toolbox.addHeader(lib, path.getDcimgui(), ".", &.{
        ".h",
    });

    lib.linkLibCpp();

    var it = dcimgui_dir.iterate();
    while (try it.next()) |*entry| {
        if ((std.mem.startsWith(u8, entry.name, "imgui") or
            std.mem.startsWith(u8, entry.name, "dcimgui")) and
            toolbox.isCppSource(entry.name) and entry.kind == .file)
            try toolbox.addSource(lib, path.getDcimgui(), entry.name, flags.slice());
    }

    try backendOptions(builder, lib, &target, &optimize, &path, &flags);

    builder.installArtifact(lib);
}
