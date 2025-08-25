const std = @import("std");
const toolbox_pkg = @import("toolbox");
const Toolbox = toolbox_pkg.Toolbox;

const utils = @import("build/utils.zig");
const Paths = utils.Paths;
const flags_size = utils.flags_size;

const backends = @import("build/backends.zig");
pub const Renderer = backends.Renderer;
pub const Platform = backends.Platform;
const backendOptions = backends.backendOptions;

fn update(toolbox: *Toolbox, path: *const Paths) !void {
    for ([_][]const u8{
        path.getDcimgui(), path.getTmp(),
    }) |clone_path| {
        std.fs.deleteTreeAbsolute(clone_path) catch |err| {
            switch (err) {
                error.FileNotFound => {},
                else => return err,
            }
        };
    }

    try toolbox.clone(.imgui, path.getDcimgui());

    var dcimgui_dir = try std.fs.openDirAbsolute(path.getDcimgui(), .{
        .iterate = true,
    });
    defer dcimgui_dir.close();

    var it = dcimgui_dir.iterate();
    while (try it.next()) |*entry| {
        if (!std.mem.eql(u8, entry.name, "backends") and !std.mem.startsWith(u8, entry.name, "im")) {
            try std.fs.deleteTreeAbsolute(toolbox.pathJoin(&.{
                path.getDcimgui(), entry.name,
            }));
        }
    }

    var backends_dir = try std.fs.openDirAbsolute(path.getBackends(), .{
        .iterate = true,
    });
    defer backends_dir.close();

    try toolbox.clone(.dcimgui, path.getTmp());

    const binding_py = toolbox.pathJoin(&.{
        path.getTmp(), "dear_bindings.py",
    });
    const imconfig_h = toolbox.pathJoin(&.{
        path.getDcimgui(), "imconfig.h",
    });
    const imgui_h = toolbox.pathJoin(&.{
        path.getDcimgui(), "imgui.h",
    });
    const imgui_out = toolbox.pathJoin(&.{
        path.getDcimgui(), "dcimgui",
    });
    const imgui_internal_h = toolbox.pathJoin(&.{
        path.getDcimgui(), "imgui_internal.h",
    });
    const imgui_internal_out = toolbox.pathJoin(&.{
        path.getDcimgui(), "dcimgui_internal",
    });
    try toolbox.run(.{
        .argv = &[_][]const u8{
            "python3", binding_py, "--output", imgui_out, imgui_h,
        },
    });
    try toolbox.run(.{
        .argv = &[_][]const u8{
            "python3", binding_py, "-o", imgui_internal_out, "--include", imgui_h, imgui_internal_h,
        },
    });

    const templates = toolbox.pathJoin(&.{
        path.getTmp(), "src", "templates",
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
                const cpp_template = toolbox.pathJoin(&.{
                    templates, toolbox.fmt("{s}-header-template.cpp", .{
                        stem,
                    }),
                });
                const h_template = toolbox.pathJoin(&.{
                    templates, toolbox.fmt("{s}-header-template.h", .{
                        stem,
                    }),
                });
                backend_cpp = toolbox.pathJoin(&.{
                    path.getBackends(), toolbox.fmt("{s}.cpp", .{
                        stem,
                    }),
                });
                if (toolbox_pkg.isCHeader(entry.name) and toolbox_pkg.exists(backend_cpp) and std.mem.startsWith(u8, entry.name, "imgui") and !std.meta.isError(std.fs.accessAbsolute(cpp_template, .{})) and !std.meta.isError(std.fs.accessAbsolute(h_template, .{}))) {
                    backend_h = toolbox.pathJoin(&.{
                        path.getBackends(), entry.name,
                    });
                    out = toolbox.pathJoin(&.{
                        path.getBackends(), toolbox.fmt("dc{s}", .{
                            stem,
                        }),
                    });
                    try toolbox.run(.{
                        .argv = &[_][]const u8{
                            "python3", binding_py, "--backend", "--include", imgui_h, "--imconfig-path", imconfig_h, "--output", out, backend_h,
                        },
                    });
                }
            },
            else => {},
        }
    }

    try std.fs.deleteTreeAbsolute(path.getTmp());
    try toolbox.clean(&.{
        "dcimgui",
    }, &.{});
}

const FromZon = toolbox_pkg.Repositories(.{
    .toolbox, .vulkan_zig, .glfw_zig, .sdl, .zigglgen,
});

const DuringExec = toolbox_pkg.Repositories(.{
    .imgui, .dcimgui,
});

pub fn build(builder: *std.Build) !void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    var toolbox = try Toolbox.init(FromZon, DuringExec, builder, optimize, .cimgui_zig, "0x4e4978d2929b7bd9", &.{
        "build", "dcimgui",
    }, .{
        .toolbox = .{
            .name = "tiawl/toolbox",
            .host = .github,
            .ref = .tag,
        },
        .vulkan_zig = .{
            .name = "tiawl/vulkan.zig",
            .host = .github,
            .ref = .tag,
        },
        .glfw_zig = .{
            .name = "tiawl/glfw.zig",
            .host = .github,
            .ref = .tag,
        },
        .sdl = .{
            .name = "castholm/SDL",
            .host = .github,
            .ref = .commit,
        },
        .zigglgen = .{
            .name = "castholm/zigglgen",
            .host = .github,
            .ref = .commit,
        },
    }, .{
        .imgui = .{
            .name = "ocornut/imgui",
            .host = .github,
            .ref = .tag,
        },
        .dcimgui = .{
            .name = "dearimgui/dear_bindings",
            .host = .github,
            .ref = .commit,
        },
    });
    defer toolbox.deinit();

    const path = try Paths.init(&toolbox);

    if (toolbox.getUpdate()) try update(&toolbox, &path);

    const lib = builder.addLibrary(.{
        .name = "cimgui",
        .root_module = std.Build.Module.create(builder, .{
            .root_source_file = builder.addWriteFiles().add("empty.c", ""),
            .target = target,
            .optimize = optimize,
        }),
    });

    var flags = try std.BoundedArray([]const u8, flags_size).init(0);

    var root_dir = try builder.build_root.handle.openDir(".", .{
        .iterate = true,
    });
    defer root_dir.close();

    var walk = try root_dir.walk(builder.allocator);

    while (try walk.next()) |*entry| {
        if (std.mem.startsWith(u8, entry.path, "dcimgui") and entry.kind == .directory) {
            toolbox.addInclude(lib, entry.path);
        }
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
        if ((std.mem.startsWith(u8, entry.name, "imgui") or std.mem.startsWith(u8, entry.name, "dcimgui")) and toolbox_pkg.isCppSource(entry.name) and entry.kind == .file) {
            try toolbox.addSource(lib, path.getDcimgui(), entry.name, flags.slice());
        }
    }

    try backendOptions(&toolbox, builder, lib, &target, &optimize, &path, &flags);

    builder.installArtifact(lib);
}
