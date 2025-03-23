const std = @import("std");
const toolbox = @import("toolbox");

const utils = @import("build/utils.zig");
const Paths = utils.Paths;
const flags_size = utils.flags_size;

const backends = @import("build/backends.zig");
pub const Renderer = backends.Renderer;
pub const Platform = backends.Platform;
const backendOptions = backends.backendOptions;

fn update(path: *const Paths) !void {
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

    try toolbox.instance().clone(.imgui, path.getDcimgui());

    var dcimgui_dir = try std.fs.openDirAbsolute(path.getDcimgui(), .{
        .iterate = true,
    });
    defer dcimgui_dir.close();

    var it = dcimgui_dir.iterate();
    while (try it.next()) |*entry| {
        if (!std.mem.eql(u8, entry.name, "backends") and !std.mem.startsWith(u8, entry.name, "im")) {
            try std.fs.deleteTreeAbsolute(toolbox.instance().pathJoin(&.{
                path.getDcimgui(), entry.name,
            }));
        }
    }

    var backends_dir = try std.fs.openDirAbsolute(path.getBackends(), .{
        .iterate = true,
    });
    defer backends_dir.close();

    try toolbox.instance().clone(.dcimgui, path.getTmp());

    const binding_py = toolbox.instance().pathJoin(&.{
        path.getTmp(), "dear_bindings.py",
    });
    const imconfig_h = toolbox.instance().pathJoin(&.{
        path.getDcimgui(), "imconfig.h",
    });
    const imgui_h = toolbox.instance().pathJoin(&.{
        path.getDcimgui(), "imgui.h",
    });
    const imgui_out = toolbox.instance().pathJoin(&.{
        path.getDcimgui(), "dcimgui",
    });
    try toolbox.instance().run(.{
        .argv = &[_][]const u8{
            "python3", binding_py, "--output", imgui_out, imgui_h,
        },
    });

    const templates = toolbox.instance().pathJoin(&.{
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
                const cpp_template = toolbox.instance().pathJoin(&.{
                    templates, toolbox.instance().fmt("{s}-header-template.cpp", .{
                        stem,
                    }),
                });
                const h_template = toolbox.instance().pathJoin(&.{
                    templates, toolbox.instance().fmt("{s}-header-template.h", .{
                        stem,
                    }),
                });
                backend_cpp = toolbox.instance().pathJoin(&.{
                    path.getBackends(), toolbox.instance().fmt("{s}.cpp", .{
                        stem,
                    }),
                });
                if (toolbox.isCHeader(entry.name) and toolbox.exists(backend_cpp) and std.mem.startsWith(u8, entry.name, "imgui") and !std.meta.isError(std.fs.accessAbsolute(cpp_template, .{})) and !std.meta.isError(std.fs.accessAbsolute(h_template, .{}))) {
                    backend_h = toolbox.instance().pathJoin(&.{
                        path.getBackends(), entry.name,
                    });
                    out = toolbox.instance().pathJoin(&.{
                        path.getBackends(), toolbox.instance().fmt("dc{s}", .{
                            stem,
                        }),
                    });
                    try toolbox.instance().run(.{
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
    try toolbox.instance().clean(&.{
        "dcimgui",
    }, &.{});
}

const FromZon = toolbox.Repositories(.{
    .toolbox, .vulkan_zig, .glfw_zig, .sdl, .zigglgen,
});

const DuringExec = toolbox.Repositories(.{
    .imgui, .dcimgui,
});

pub fn build(builder: *std.Build) !void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    try toolbox.init(FromZon, DuringExec, builder, optimize, .cimgui_zig, "0x4e4978d2929b7bd9", &.{
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

    const path = try Paths.init();

    if (toolbox.instance().getUpdate()) try update(&path);

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
        if (std.mem.startsWith(u8, entry.path, "dcimgui") and entry.kind == .directory) {
            toolbox.instance().addInclude(lib, entry.path);
        }
    }

    var dcimgui_dir = try std.fs.openDirAbsolute(path.getDcimgui(), .{
        .iterate = true,
    });
    defer dcimgui_dir.close();

    toolbox.instance().addHeader(lib, path.getDcimgui(), ".", &.{
        ".h",
    });

    lib.linkLibCpp();

    var it = dcimgui_dir.iterate();
    while (try it.next()) |*entry| {
        if ((std.mem.startsWith(u8, entry.name, "imgui") or std.mem.startsWith(u8, entry.name, "dcimgui")) and toolbox.isCppSource(entry.name) and entry.kind == .file) {
            try toolbox.instance().addSource(lib, path.getDcimgui(), entry.name, flags.slice());
        }
    }

    try backendOptions(lib, &target, &optimize, &path, &flags);

    builder.installArtifact(lib);
}
