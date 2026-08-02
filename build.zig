const std = @import("std");
const build_zig_zon = @import("build.zig.zon");
const examples_build_zig_zon = @import("examples/build.zig.zon");
const toolbox = @import("toolbox");
const VerboseBuilder = toolbox.VerboseBuilder;
const TranslateC = @import("translate_c").Translator;

fn addIncludePathsToTranslateC(translate_c: *TranslateC, lib: *std.Build.Step.Compile) void {
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

var user_translate_c: TranslateC = undefined;

pub fn createModule(builder: *std.Build, dep: *std.Build.Dependency, lib: *std.Build.Step.Compile, c_path: std.Build.LazyPath) *std.Build.Module {
    const translate_c_dep = dep.builder.dependency("translate_c", .{});

    user_translate_c = .init(translate_c_dep, .{
        .c_source_file = c_path,
        .target = lib.root_module.resolved_target orelse builder.standardTargetOptions(.{}),
        .optimize = lib.root_module.optimize orelse builder.standardOptimizeOption(.{}),
    });

    addIncludePathsToTranslateC(&user_translate_c, lib);

    user_translate_c.mod.linkLibrary(lib);

    return user_translate_c.mod;
}

pub const Renderer = enum {
    Metal,
    OpenGL3,
    SDLGPU3,
    Vulkan,
};

pub const Platform = enum {
    GLFW,
    SDL3,
};

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
    var branch_dir: []const u8 = "master";

    try dcimgui_builder.make(&.{"backends"});

    for ([_]*std.Build.Dependency{ imgui_master_dep, imgui_docking_dep }) |imgui_dep| {
        imgui_builder = VerboseBuilder.initFromDependency(imgui_dep);

        while (try imgui_builder.iterate(&.{"."})) |*entry| {
            switch (entry.kind) {
                .file => if (std.mem.startsWith(u8, entry.name, "im")) {
                    try pkg_builder.copy(&.{ "dcimgui", branch_dir, entry.name }, &imgui_builder, &.{entry.name});
                },
                else => {},
            }
        }

        while (try imgui_builder.iterate(&.{"backends"})) |*entry| {
            switch (entry.kind) {
                .file => if (std.mem.startsWith(u8, entry.name, "im")) {
                    try pkg_builder.copy(&.{ "dcimgui", branch_dir, "backends", entry.name }, &imgui_builder, &.{ "backends", entry.name });
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
        try pkg_builder.copy(&.{ "dcimgui", branch_dir, "dcimgui.h" }, &dcimgui_builder, &.{"dcimgui.h"});
        try pkg_builder.copy(&.{ "dcimgui", branch_dir, "dcimgui.cpp" }, &dcimgui_builder, &.{"dcimgui.cpp"});

        _ = try dcimgui_builder.run(&.{ "python3", "dear_bindings.py", "-o", "dcimgui_internal", "--include", "imgui.h", "imgui_internal.h" }, dcimgui_builder.ptrCwd().*);
        try pkg_builder.copy(&.{ "dcimgui", branch_dir, "dcimgui_internal.h" }, &dcimgui_builder, &.{"dcimgui_internal.h"});
        try pkg_builder.copy(&.{ "dcimgui", branch_dir, "dcimgui_internal.cpp" }, &dcimgui_builder, &.{"dcimgui_internal.cpp"});

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
                        try pkg_builder.copy(&.{ "dcimgui", branch_dir, "backends", pkg_builder.fmt("dc{s}", .{entry.name}) }, &dcimgui_builder, &.{ "backends", pkg_builder.fmt("dc{s}", .{entry.name}) });
                        try pkg_builder.copy(&.{ "dcimgui", branch_dir, "backends", pkg_builder.fmt("dc{s}", .{source.?}) }, &dcimgui_builder, &.{ "backends", pkg_builder.fmt("dc{s}", .{source.?}) });
                    }
                },
                else => {},
            }
        }

        while (try pkg_builder.iterate(&.{"copyme"})) |*entry| {
            switch (entry.kind) {
                .file => try pkg_builder.copy(&.{ "dcimgui", branch_dir, "backends", entry.name }, pkg_builder, &.{ "copyme", entry.name }),
                else => {},
            }
        }

        branch_dir = "docking";
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
    var stdout_writer = std.Io.File.stdout().writer(pkg_builder.getIo(), &stdout_buffer);
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
        stdout.print("{s}\n", .{buf}) catch {};
        stdout.flush() catch {};
        return true;
    }
    return false;
}

pub fn buildBackends(pkg_builder: *VerboseBuilder, lib: *std.Build.Step.Compile, docking: bool, flags: *std.ArrayListUnmanaged([]const u8)) !void {
    const renderers = pkg_builder.option([]const Renderer, &.{}, "renderers", "Specify the renderer backends");
    const platforms = pkg_builder.option([]const Platform, &.{}, "platforms", "Specify the platform backends");
    const no_renderer = pkg_builder.option(bool, false, "no_renderer", "Specify there no need for renderer backend. It returns an error if you use it with `renderers` option.");
    const no_platform = pkg_builder.option(bool, false, "no_platform", "Specify there no need for platform backend. It returns an error if you use it with `platforms` option.");
    const branch_dir = if (docking) "docking" else "master";

    if (renderers.len == 0 and !no_renderer) {
        std.log.warn("Unspecified renderer backend", .{});
    } else if (renderers.len > 0 and no_renderer) {
        return error.ConflictingOptions;
    }

    var sdl_artifact: *std.Build.Step.Compile = undefined;
    var sdl_dep_fetched = false;

    for (renderers) |renderer| {
        switch (renderer) {
            .Vulkan => {
                if (pkg_builder.verboseDependencyLazy("vulkan_zig")) |vulkan_dep| {
                    const vulkan_artifact = pkg_builder.artifact(vulkan_dep, "vulkan");
                    if (std.mem.indexOfScalar(Platform, platforms, .GLFW) == null) {
                        pkg_builder.linkLibrary(lib, vulkan_artifact);
                        pkg_builder.installLibraryHeaders(lib, vulkan_artifact);
                    }
                    pkg_builder.addIncludePathsFromLib(@TypeOf(lib.*), lib, vulkan_artifact);
                    flags.appendAssumeCapacity("-DIMGUI_IMPL_VULKAN_NO_PROTOTYPES");
                    pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_vulkan.cpp" }, flags.items);
                    pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_vulkan.cpp" }, flags.items);
                    pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_vulkan.h" }, &.{ "backends", "imgui_impl_vulkan.h" });
                    pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_vulkan.h" }, &.{ "backends", "dcimgui_impl_vulkan.h" });
                }
            },
            .OpenGL3 => {
                pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_opengl3.cpp" }, flags.items);
                pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_opengl3.cpp" }, flags.items);
                pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_opengl3.h" }, &.{ "backends", "imgui_impl_opengl3.h" });
                pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_opengl3.h" }, &.{ "backends", "dcimgui_impl_opengl3.h" });
                pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_opengl3_loader.h" }, &.{ "backends", "imgui_impl_opengl3_loader.h" });
            },
            .SDLGPU3 => {
                if (pkg_builder.dependencyLazy("sdl")) |sdl_dep| {
                    sdl_artifact = pkg_builder.artifact(sdl_dep, "SDL3");
                    sdl_dep_fetched = true;

                    pkg_builder.linkLibrary(lib, sdl_artifact);
                    pkg_builder.installLibraryHeaders(lib, sdl_artifact);

                    pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_sdlgpu3.cpp" }, flags.items);
                    pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_sdlgpu3.cpp" }, flags.items);
                    pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_sdlgpu3.h" }, &.{ "backends", "imgui_impl_sdlgpu3.h" });
                    pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_sdlgpu3.h" }, &.{ "backends", "dcimgui_impl_sdlgpu3.h" });
                }
            },
            .Metal => {
                if (pkg_builder.getOs() != .macos and pkg_builder.getOs() != .ios) {
                    std.log.err("Metal renderer is only available on macOS/iOS", .{});
                    return error.UnsupportedTarget;
                }

                // Link Metal frameworks
                pkg_builder.linkFramework(lib, "Metal");
                pkg_builder.linkFramework(lib, "MetalKit");
                pkg_builder.linkFramework(lib, "Cocoa");
                pkg_builder.linkFramework(lib, "IOKit");
                pkg_builder.linkFramework(lib, "CoreVideo");
                pkg_builder.linkFramework(lib, "QuartzCore");

                // Add Metal backend sources (compile separately to avoid header conflicts)
                pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_metal.mm" }, flags.items);
                pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_metal.mm" }, flags.items);
                pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_metal.h" }, &.{ "backends", "imgui_impl_metal.h" });
                pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_metal.h" }, &.{ "backends", "dcimgui_impl_metal.h" });
            },
        }
    }

    if (platforms.len == 0 and !no_platform) {
        std.log.warn("Unspecified platform backend", .{});
    } else if (platforms.len > 0 and no_platform) {
        return error.ConflictingOptions;
    }
    for (platforms) |platform| {
        switch (platform) {
            .GLFW => {
                if (pkg_builder.verboseDependencyLazy("glfw_zig")) |glfw_dep| {
                    const glfw_artifact = pkg_builder.artifact(glfw_dep, "glfw");
                    pkg_builder.addIncludePathsFromLib(@TypeOf(lib.*), lib, glfw_artifact);
                    pkg_builder.linkLibrary(lib, glfw_artifact);
                    pkg_builder.installLibraryHeaders(lib, glfw_artifact);

                    pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_glfw.cpp" }, flags.items);
                    pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_glfw.cpp" }, flags.items);
                    pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_glfw.h" }, &.{ "backends", "imgui_impl_glfw.h" });
                    pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_glfw.h" }, &.{ "backends", "dcimgui_impl_glfw.h" });

                    pkg_builder.addCMacro(lib, "GLFW_INCLUDE_NONE", "1");
                    if (std.mem.indexOfScalar(Renderer, renderers, .Vulkan) != null) {
                        pkg_builder.addCMacro(lib, "GLFW_INCLUDE_VULKAN", "1");
                    }
                }
            },
            .SDL3 => {
                if (!sdl_dep_fetched) {
                    if (pkg_builder.dependencyLazy("sdl")) |sdl_dep| {
                        sdl_artifact = pkg_builder.artifact(sdl_dep, "SDL3");
                    } else continue;
                }

                pkg_builder.linkLibrary(lib, sdl_artifact);
                pkg_builder.installLibraryHeaders(lib, sdl_artifact);

                pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_sdl3.cpp" }, flags.items);
                pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_sdl3.cpp" }, flags.items);
                pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "imgui_impl_sdl3.h" }, &.{ "backends", "imgui_impl_sdl3.h" });
                pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, "backends", "dcimgui_impl_sdl3.h" }, &.{ "backends", "dcimgui_impl_sdl3.h" });
            },
        }
    }
    pkg_builder.addCMacro(lib, "IMGUI_USE_LEGACY_CRC32_ADLER", "1");
}

fn buildFn(pkg_builder: *VerboseBuilder) !void {
    const docking = pkg_builder.option(bool, false, "docking", "master or docking ocornut/imgui branch ?");
    const branch_dir = if (docking) "docking" else "master";
    const link_libc = pkg_builder.option(bool, true, "libc", "link libC ?");

    const lib = pkg_builder.addLibrary("cimgui");
    if (link_libc) pkg_builder.linkLibCpp(lib);

    pkg_builder.addInclude(lib, &.{ "dcimgui", branch_dir });

    while (try pkg_builder.iterate(&.{ "dcimgui", branch_dir })) |*entry| {
        if (toolbox.isCHeader(entry.name)) pkg_builder.installHeader(lib, &.{ "dcimgui", branch_dir, entry.name }, &.{entry.name});
    }

    var flags_buffer: [16][]const u8 = undefined;
    var flags = std.ArrayListUnmanaged([]const u8).initBuffer(&flags_buffer);

    while (try pkg_builder.iterate(&.{ "dcimgui", branch_dir })) |entry| {
        switch (entry.kind) {
            .file => {
                if ((std.mem.startsWith(u8, entry.name, "imgui") or
                    std.mem.startsWith(u8, entry.name, "dcimgui")) and
                    toolbox.isCppSource(entry.name))
                {
                    pkg_builder.addCSource(lib, &.{ "dcimgui", branch_dir, entry.name }, flags.items);
                }
            },
            else => {},
        }
    }

    try buildBackends(pkg_builder, lib, docking, &flags);

    pkg_builder.installArtifact(lib);
}

pub fn build(builder: *std.Build) !void {
    var pkg_builder = try VerboseBuilder.init(builder, @tagName(build_zig_zon.name), buildFn, updateFn);

    if (list(&pkg_builder)) return;
    try pkg_builder.fetch(@TypeOf(build_zig_zon.dependencies), build_zig_zon.dependencies, pkg_builder.ptrCwd());
    var examples_dir = try pkg_builder.openDir(&.{"examples"});
    defer pkg_builder.closeDir(examples_dir);
    try pkg_builder.fetch(@TypeOf(examples_build_zig_zon.dependencies), examples_build_zig_zon.dependencies, &examples_dir);
    try pkg_builder.update();
    try pkg_builder.build();
}
