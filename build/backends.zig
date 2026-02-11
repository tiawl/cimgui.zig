const std = @import("std");
const toolbox = @import("toolbox");
const VerboseBuilder = toolbox.VerboseBuilder;

const zigglgen = @import("zigglgen");

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

pub fn build(pkg_builder: *VerboseBuilder, lib: *std.Build.Step.Compile, docking: bool, flags: *std.ArrayListUnmanaged([]const u8)) !void {
    const renderers = pkg_builder.option([]const Renderer, &.{}, "renderers", "Specify the renderer backends");
    const platforms = pkg_builder.option([]const Platform, &.{}, "platforms", "Specify the platform backends");

    if (renderers.len == 0) {
        std.log.warn("Unspecified renderer backend", .{});
    }
    for (renderers) |renderer| {
        switch (renderer) {
            .Vulkan => {
                if (std.mem.indexOfScalar(Platform, platforms, .GLFW) == null) {
                    const vulkan_dep = pkg_builder.dependency("vulkan_zig");
                    const vulkan_artifact = pkg_builder.artifact(vulkan_dep, "vulkan");

                    pkg_builder.linkLibrary(lib, vulkan_artifact);
                    pkg_builder.installLibraryHeaders(lib, vulkan_artifact);
                }
                flags.appendAssumeCapacity("-DIMGUI_IMPL_VULKAN_NO_PROTOTYPES");
                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "imgui_impl_vulkan.cpp" }, flags.items);
                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "dcimgui_impl_vulkan.cpp" }, flags.items);
            },
            .OpenGL3 => {
                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "imgui_impl_opengl3.cpp" }, flags.items);
                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "dcimgui_impl_opengl3.cpp" }, flags.items);

                const gl_bindings = zigglgen.generateBindingsModule(pkg_builder.ptrBuilder(), .{
                    .api = .gl,
                    .version = pkg_builder.option(zigglgen.GeneratorOptions.Version, .@"4.6", "gl_version", "Specify the gl version"),
                    .profile = .core,
                    .extensions = pkg_builder.option([]const zigglgen.GeneratorOptions.Extension, &.{}, "gl_ext", "Specify the gl extensions"),
                });

                pkg_builder.addImport(lib, "gl", gl_bindings);
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
                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "imgui_impl_metal.mm" }, flags.items);
                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "dcimgui_impl_metal.mm" }, flags.items);
            },
        }
    }

    if (platforms.len == 0) {
        std.log.warn("Unspecified platform backend", .{});
    }
    for (platforms) |platform| {
        switch (platform) {
            .GLFW => {
                const glfw_dep = pkg_builder.dependency("glfw_zig");
                const glfw_artifact = pkg_builder.artifact(glfw_dep, "glfw");
                for (glfw_artifact.root_module.include_dirs.items) |*included| {
                    switch (included.*) {
                        .path => pkg_builder.addIncludePath(lib, included.path),
                        else => {},
                    }
                }

                pkg_builder.linkLibrary(lib, glfw_artifact);
                pkg_builder.installLibraryHeaders(lib, glfw_artifact);

                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "imgui_impl_glfw.cpp" }, flags.items);
                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "dcimgui_impl_glfw.cpp" }, flags.items);

                pkg_builder.addCMacro(lib, "GLFW_INCLUDE_NONE", "1");
                if (std.mem.indexOfScalar(Renderer, renderers, .Vulkan) != null) {
                    pkg_builder.addCMacro(lib, "GLFW_INCLUDE_VULKAN", "1");
                }
            },
            .SDL3 => {
                const sdl_dep = pkg_builder.dependency("sdl");
                const sdl_artifact = pkg_builder.artifact(sdl_dep, "SDL3");
                pkg_builder.linkLibrary(lib, sdl_artifact);
                pkg_builder.installLibraryHeaders(lib, sdl_artifact);

                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "imgui_impl_sdl3.cpp" }, flags.items);
                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "dcimgui_impl_sdl3.cpp" }, flags.items);
            },
            .SDLGPU3 => {
                const sdl_dep = pkg_builder.dependency("sdl");
                const sdl_artifact = pkg_builder.artifact(sdl_dep, "SDL3");
                pkg_builder.linkLibrary(lib, sdl_artifact);
                pkg_builder.installLibraryHeaders(lib, sdl_artifact);

                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "imgui_impl_sdl3.cpp" }, flags.items);
                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "dcimgui_impl_sdl3.cpp" }, flags.items);
                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "imgui_impl_sdlgpu3.cpp" }, flags.items);
                pkg_builder.addCSource(lib, &.{ "dcimgui", if (docking) "docking" else "master", "backends", "dcimgui_impl_sdlgpu3.cpp" }, flags.items);
            },
        }
    }
    pkg_builder.addCMacro(lib, "IMGUI_USE_LEGACY_CRC32_ADLER", "1");
}
