const std = @import("std");
const build_zig_zon = @import("build.zig.zon");
const toolbox = @import("toolbox");
const VerboseBuilder = toolbox.VerboseBuilder;

const backends = @import("build/backends.zig");
pub const Renderer = backends.Renderer;
pub const Platform = backends.Platform;
const buildBackends = backends.build;

fn updateFn(pkg_builder: *VerboseBuilder) !void {
    try pkg_builder.remove(&.{"dcimgui"});
    try pkg_builder.make(&.{"dcimgui"});
    try pkg_builder.make(&.{ "dcimgui", "docking" });
    try pkg_builder.make(&.{ "dcimgui", "docking", "backends" });
    try pkg_builder.make(&.{ "dcimgui", "master" });
    try pkg_builder.make(&.{ "dcimgui", "master", "backends" });

    const imgui_master_dep = pkg_builder.verboseDependency("imgui-master");
    const imgui_docking_dep = pkg_builder.verboseDependency("imgui-docking");
    var imgui_builder: VerboseBuilder = undefined;
    const dcimgui_dep = pkg_builder.verboseDependency("dcimgui");
    var dcimgui_builder = VerboseBuilder.initFromDependency(dcimgui_dep);
    var docking = false;

    try dcimgui_builder.make(&.{"backends"});

    for ([_]*std.Build.Dependency{ imgui_master_dep, imgui_docking_dep }) |imgui_dep| {
        imgui_builder = VerboseBuilder.initFromDependency(imgui_dep);

        while (try imgui_builder.iterate(&.{"."})) |*entry| {
            switch (entry.kind) {
                .file => if (std.mem.startsWith(u8, entry.name, "im")) {
                    try pkg_builder.copy(&.{ "dcimgui", if (docking) "docking" else "master", entry.name }, &imgui_builder, &.{entry.name});
                },
                else => {},
            }
        }

        while (try imgui_builder.iterate(&.{"backends"})) |*entry| {
            switch (entry.kind) {
                .file => if (std.mem.startsWith(u8, entry.name, "im")) {
                    try pkg_builder.copy(&.{ "dcimgui", if (docking) "docking" else "master", "backends", entry.name }, &imgui_builder, &.{ "backends", entry.name });
                    try dcimgui_builder.remove(&.{ "backends", entry.name });
                    try dcimgui_builder.copy(&.{ "backends", entry.name }, &imgui_builder, &.{ "backends", entry.name });
                },
                else => {},
            }
        }

        try dcimgui_builder.remove(&.{"imgui.h"});
        try dcimgui_builder.copy(&.{"imgui.h"}, &imgui_builder, &.{"imgui.h"});
        try dcimgui_builder.remove(&.{"imgui_internal.h"});
        try dcimgui_builder.copy(&.{"imgui_internal.h"}, &imgui_builder, &.{"imgui_internal.h"});
        try dcimgui_builder.remove(&.{"imconfig.h"});
        try dcimgui_builder.copy(&.{"imconfig.h"}, &imgui_builder, &.{"imconfig.h"});
        _ = try dcimgui_builder.run(&.{ "python3", "dear_bindings.py", "--output", "dcimgui", "imgui.h" }, dcimgui_builder.ptrCwd().*);
        try pkg_builder.copy(&.{ "dcimgui", if (docking) "docking" else "master", "dcimgui.h" }, &dcimgui_builder, &.{"dcimgui.h"});
        try pkg_builder.copy(&.{ "dcimgui", if (docking) "docking" else "master", "dcimgui.cpp" }, &dcimgui_builder, &.{"dcimgui.cpp"});

        _ = try dcimgui_builder.run(&.{ "python3", "dear_bindings.py", "-o", "dcimgui_internal", "--include", "imgui.h", "imgui_internal.h" }, dcimgui_builder.ptrCwd().*);
        try pkg_builder.copy(&.{ "dcimgui", if (docking) "docking" else "master", "dcimgui_internal.h" }, &dcimgui_builder, &.{"dcimgui_internal.h"});
        try pkg_builder.copy(&.{ "dcimgui", if (docking) "docking" else "master", "dcimgui_internal.cpp" }, &dcimgui_builder, &.{"dcimgui_internal.cpp"});

        while (try dcimgui_builder.iterate(&.{"backends"})) |*entry| {
            switch (entry.kind) {
                .file => {
                    const backend = std.fs.path.stem(entry.name);
                    const source_template = [_][]const u8{ "src", "templates", pkg_builder.fmt("{s}-header-template.cpp", .{backend}) };
                    const header_template = [_][]const u8{ "src", "templates", pkg_builder.fmt("{s}-header-template.h", .{backend}) };
                    const source = if (imgui_builder.access(&.{ "backends", imgui_builder.fmt("{s}.cpp", .{backend}) })) imgui_builder.fmt("{s}.cpp", .{backend}) else if (imgui_builder.access(&.{ "backends", imgui_builder.fmt("{s}.mm", .{backend}) })) imgui_builder.fmt("{s}.mm", .{backend}) else null;
                    if (toolbox.isCHeader(entry.name) and
                        std.mem.startsWith(u8, entry.name, "imgui") and
                        (source != null) and
                        dcimgui_builder.access(&source_template) and
                        dcimgui_builder.access(&header_template))
                    {
                        _ = try dcimgui_builder.run(&.{ "python3", "dear_bindings.py", "--backend", "--include", "imgui.h", "--imconfig-path", "imconfig.h", "--output", pkg_builder.resolve(&.{ "backends", pkg_builder.fmt("dc{s}", .{backend}) }), pkg_builder.resolve(&.{ "backends", entry.name }) }, dcimgui_builder.ptrCwd().*);
                        try pkg_builder.copy(&.{ "dcimgui", if (docking) "docking" else "master", "backends", pkg_builder.fmt("dc{s}", .{entry.name}) }, &dcimgui_builder, &.{ "backends", pkg_builder.fmt("dc{s}", .{entry.name}) });
                        try pkg_builder.copy(&.{ "dcimgui", if (docking) "docking" else "master", "backends", pkg_builder.fmt("dc{s}", .{source.?}) }, &dcimgui_builder, &.{ "backends", pkg_builder.fmt("dc{s}", .{source.?}) });
                    }
                },
                else => {},
            }
        }

        while (try pkg_builder.iterate(&.{ "build", "copyme" })) |*entry| {
            switch (entry.kind) {
                .file => try pkg_builder.copy(&.{ "dcimgui", if (docking) "docking" else "master", "backends", entry.name }, pkg_builder, &.{ "build", "copyme", entry.name }),
                else => {},
            }
        }

        docking = true;
    }
}

fn joinBackend(pkg_builder: *VerboseBuilder, buf: *[]const u8, tag: []const u8, separator: []const u8) void {
    if (buf.len > 0) {
        buf.* = pkg_builder.join(separator, &[_][]const u8{ buf.*, tag });
    } else buf.* = tag;
}

fn list(pkg_builder: *VerboseBuilder) bool {
    const list_renderers_opt = pkg_builder.option(bool, false, "list-renderers", "Print available renderer backends. This options prevail on list-platforms option");
    const list_platforms_opt = pkg_builder.option(bool, false, "list-platforms", "Print available platform backends");
    const separator_opt = pkg_builder.option([]const u8, "\n", "separator", "Used separator instead of default newline character");

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    if (list_renderers_opt or list_platforms_opt) {
        var buf: []const u8 = "";
        if (list_renderers_opt) {
            for (std.enums.values(Renderer)) |backend| {
                switch (pkg_builder.getOs()) {
                    .windows => if (backend == .Metal) continue,
                    .macos => {},
                    else => if (backend == .Metal) continue,
                }
                joinBackend(pkg_builder, &buf, @tagName(backend), separator_opt);
            }
        } else {
            for (std.enums.values(Platform)) |backend| joinBackend(pkg_builder, &buf, @tagName(backend), separator_opt);
        }
        stdout.print("{s}\n", .{buf}) catch @panic("OOM");
        stdout.flush() catch @panic("OOM");
        return true;
    }
    return false;
}

fn buildFn(pkg_builder: *VerboseBuilder) !void {
    const docking = pkg_builder.option(bool, false, "docking", "master or docking ocornut/imgui branch ?");

    const lib = pkg_builder.addLibrary("cimgui");
    pkg_builder.linkLibCpp(lib);

    pkg_builder.addInclude(lib, &.{"dcimgui", if (docking) "docking" else "master"});

    while (try pkg_builder.iterate(&.{ "dcimgui", if (docking) "docking" else "master" })) |*entry| {
        if (toolbox.isCHeader(entry.name)) pkg_builder.installHeader(lib, &.{ "dcimgui", if (docking) "docking" else "master", entry.name }, &.{entry.name});
    }

    var flags_buffer: [16][]const u8 = undefined;
    var flags = std.ArrayListUnmanaged([]const u8).initBuffer(&flags_buffer);

    while (try pkg_builder.iterate(&.{ "dcimgui", if (docking) "docking" else "master" })) |entry| {
        switch (entry.kind) {
            .file => {
                if ((std.mem.startsWith(u8, entry.name, "imgui") or
                    std.mem.startsWith(u8, entry.name, "dcimgui")) and
                    toolbox.isCppSource(entry.name))
                {
                    pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", entry.name }, flags.items);
                }
            },
            else => {},
        }
    }

    try buildBackends(pkg_builder, lib, docking, &flags);

    pkg_builder.installArtifact(lib);
}

pub fn build(builder: *std.Build) !void {
    var pkg_builder = try VerboseBuilder.init(builder, build_zig_zon, buildFn, updateFn);

    if (list(&pkg_builder)) return;
    try pkg_builder.fetch(build_zig_zon);
    try pkg_builder.update();
    try pkg_builder.build();
}
