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
};

pub const Platform = enum {
    GLFW,
    SDL3,
    SDLGPU3,
};

pub fn backendOptions(toolbox: *Toolbox, builder: *std.Build, lib: *std.Build.Step.Compile, target: *const std.Build.ResolvedTarget, optimize: *const std.builtin.OptimizeMode, path: *const Paths, flags: *std.BoundedArray([]const u8, flags_size)) !void {
    const renderer_opt = builder.option(Renderer, "renderer", "Specify the renderer backend");
    const platform_opt = builder.option(Platform, "platform", "Specify the platform backend");

    if (renderer_opt) |renderer| {
        switch (renderer) {
            .Vulkan => {
                if (platform_opt) |platform| {
                    if (platform != .GLFW) {
                        const vulkan_dep = builder.dependency("vulkan_zig", .{
                            .target = target.*,
                            .optimize = optimize.*,
                        });

                        const vulkan_lib = vulkan_dep.artifact("vulkan");

                        lib.linkLibrary(vulkan_lib);
                        lib.installLibraryHeaders(vulkan_lib);
                    }
                }
                try flags.append("-DIMGUI_IMPL_VULKAN_NO_PROTOTYPES");
                try toolbox.addSource(lib, path.getBackends(), "imgui_impl_vulkan.cpp", flags.slice());
                try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_vulkan.cpp", flags.slice());
            },
            .OpenGL3 => {
                try toolbox.addSource(lib, path.getBackends(), "imgui_impl_opengl3.cpp", flags.slice());
                try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_opengl3.cpp", flags.slice());

                const gl_bindings = zigglgen.generateBindingsModule(builder, .{
                    .api = .gl,
                    .version = builder.option(zigglgen.GeneratorOptions.Version, "gl_version", "Specify the gl version") orelse .@"4.6",
                    .profile = .core,
                    .extensions = builder.option([]const zigglgen.GeneratorOptions.Extension, "gl_ext", "Specify the gl extensions") orelse &.{},
                });

                lib.root_module.addImport("gl", gl_bindings);
            },
        }
    } else std.log.warn("Unspecified renderer backend", .{});

    if (platform_opt) |platform| {
        switch (platform) {
            .GLFW => {
                const glfw_dep = builder.dependency("glfw_zig", .{
                    .target = target.*,
                    .optimize = optimize.*,
                });

                const glfw_lib = glfw_dep.artifact("glfw");

                lib.linkLibrary(glfw_lib);
                lib.installLibraryHeaders(glfw_lib);

                try toolbox.addSource(lib, path.getBackends(), "imgui_impl_glfw.cpp", flags.slice());
                try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_glfw.cpp", flags.slice());

                lib.root_module.addCMacro("GLFW_INCLUDE_NONE", "1");
                if (renderer_opt) |renderer| {
                    if (renderer == .Vulkan) {
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

                try toolbox.addSource(lib, path.getBackends(), "imgui_impl_sdl3.cpp", flags.slice());
                try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_sdl3.cpp", flags.slice());
            },
            .SDLGPU3 => {
                const sdl_dep = builder.dependency("sdl", .{
                    .target = target.*,
                    .optimize = optimize.*,
                });

                lib.linkLibrary(sdl_dep.artifact("SDL3"));
                lib.installLibraryHeaders(sdl_dep.artifact("SDL3"));
                try toolbox.addSource(lib, path.getBackends(), "imgui_impl_sdlgpu3.cpp", flags.slice());
                try toolbox.addSource(lib, path.getBackends(), "dcimgui_impl_sdlgpu3.cpp", flags.slice());
            },
        }
        lib.root_module.addCMacro("IMGUI_USE_LEGACY_CRC32_ADLER", "1");
    } else std.log.warn("Unspecified platform backend", .{});
}
