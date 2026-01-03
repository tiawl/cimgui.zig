const std = @import("std");

const toolbox_pkg = @import("toolbox");
const Toolbox = toolbox_pkg.Toolbox;
const zigglgen = @import("zigglgen");

const utils = @import("utils.zig");
const Paths = utils.Paths;
const flags_size = utils.flags_size;

pub const Renderer = enum {
    Vulkan,
    OpenGL3,
    Metal,
};

pub const Platform = enum {
    GLFW,
    SDL3,
    SDLGPU3,
};

pub fn backendOptions(toolbox: *Toolbox, builder: *std.Build, lib: *std.Build.Step.Compile, target: *const std.Build.ResolvedTarget, optimize: *const std.builtin.OptimizeMode, path: *const Paths, flags: *std.ArrayListUnmanaged([]const u8)) !void {
    const renderers_opt = builder.option([]const Renderer, "renderers", "Specify the renderer backends");
    const platforms_opt = builder.option([]const Platform, "platforms", "Specify the platform backends");

    if (renderers_opt) |renderers| {
        if (renderers.len == 0) {
            std.log.warn("Unspecified renderer backend", .{});
        }
        for (renderers) |renderer| {
            switch (renderer) {
                .Vulkan => {
                    if (platforms_opt) |platforms| {
                        if (std.mem.indexOf(Platform, platforms, &.{.GLFW}) == null) {
                            const vulkan_dep = builder.dependency("vulkan_zig", .{
                                .target = target.*,
                                .optimize = optimize.*,
                            });

                            const vulkan_lib = vulkan_dep.artifact("vulkan");

                            lib.linkLibrary(vulkan_lib);
                            lib.installLibraryHeaders(vulkan_lib);
                        }
                    }
                    flags.appendAssumeCapacity("-DIMGUI_IMPL_VULKAN_NO_PROTOTYPES");
                    try toolbox.addSource(lib, path.getBackends(), "imgui_impl_vulkan.cpp", flags.items);
                    try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_vulkan.cpp", flags.items);
                },
                .OpenGL3 => {
                    try toolbox.addSource(lib, path.getBackends(), "imgui_impl_opengl3.cpp", flags.items);
                    try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_opengl3.cpp", flags.items);

                    const gl_bindings = zigglgen.generateBindingsModule(builder, .{
                        .api = .gl,
                        .version = builder.option(zigglgen.GeneratorOptions.Version, "gl_version", "Specify the gl version") orelse .@"4.6",
                        .profile = .core,
                        .extensions = builder.option([]const zigglgen.GeneratorOptions.Extension, "gl_ext", "Specify the gl extensions") orelse &.{},
                    });

                    lib.root_module.addImport("gl", gl_bindings);
                },
                .Metal => {
                    if (target.result.os.tag != .macos and target.result.os.tag != .ios) {
                        std.log.err("Metal renderer is only available on macOS/iOS", .{});
                        return error.UnsupportedTarget;
                    }

                    // Link Metal frameworks
                    lib.linkFramework("Metal");
                    lib.linkFramework("MetalKit");
                    lib.linkFramework("Cocoa");
                    lib.linkFramework("IOKit");
                    lib.linkFramework("CoreVideo");
                    lib.linkFramework("QuartzCore");

                    // Add Metal backend sources (compile separately to avoid header conflicts)
                    try toolbox.addSource(lib, path.getBackends(), "imgui_impl_metal.mm", flags.items);
                    try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_metal.mm", flags.items);
                },
            }
        }
    } else std.log.warn("Unspecified renderer backend", .{});

    if (platforms_opt) |platforms| {
        if (platforms.len == 0) {
            std.log.warn("Unspecified platform backend", .{});
        }
        for (platforms) |platform| {
            switch (platform) {
                .GLFW => {
                    const glfw_dep = builder.dependency("glfw_zig", .{
                        .target = target.*,
                        .optimize = optimize.*,
                    });

                    const glfw_lib = glfw_dep.artifact("glfw");
                    for (glfw_lib.root_module.include_dirs.items) |*included| {
                        switch (included.*) {
                            .path => lib.addIncludePath(included.path),
                            else => {},
                        }
                    }

                    lib.linkLibrary(glfw_lib);
                    lib.installLibraryHeaders(glfw_lib);

                    try toolbox.addSource(lib, path.getBackends(), "imgui_impl_glfw.cpp", flags.items);
                    try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_glfw.cpp", flags.items);

                    lib.root_module.addCMacro("GLFW_INCLUDE_NONE", "1");
                    if (renderers_opt) |renderers| {
                        if (std.mem.indexOf(Renderer, renderers, &.{.Vulkan}) != null) {
                            lib.root_module.addCMacro("GLFW_INCLUDE_VULKAN", "1");
                        }
                    }
                },
                .SDL3 => {
                    const sdl_dep = builder.dependency("sdl", .{
                        .target = target.*,
                        .optimize = optimize.*,
                    });

                    lib.linkLibrary(sdl_dep.artifact("SDL3"));
                    lib.installLibraryHeaders(sdl_dep.artifact("SDL3"));

                    try toolbox.addSource(lib, path.getBackends(), "imgui_impl_sdl3.cpp", flags.items);
                    try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_sdl3.cpp", flags.items);
                },
                .SDLGPU3 => {
                    const sdl_dep = builder.dependency("sdl", .{
                        .target = target.*,
                        .optimize = optimize.*,
                    });

                    lib.linkLibrary(sdl_dep.artifact("SDL3"));
                    lib.installLibraryHeaders(sdl_dep.artifact("SDL3"));

                    try toolbox.addSource(lib, path.getBackends(), "imgui_impl_sdl3.cpp", flags.items);
                    try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_sdl3.cpp", flags.items);
                    try toolbox.addSource(lib, path.getBackends(), "imgui_impl_sdlgpu3.cpp", flags.items);
                    try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_sdlgpu3.cpp", flags.items);
                },
            }
        }
        lib.root_module.addCMacro("IMGUI_USE_LEGACY_CRC32_ADLER", "1");
    } else std.log.warn("Unspecified platform backend", .{});
}
