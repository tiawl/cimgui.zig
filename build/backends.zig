const std = @import ("std");
const toolbox = @import ("toolbox");

const utils = @import ("utils.zig");
const Paths = utils.Paths;
const flags_size = utils.flags_size;

pub const Renderer = enum
{
  Vulkan,
  OpenGL3,
};

pub fn rendererOption (builder: *std.Build, lib: *std.Build.Step.Compile,
  target: *const std.Build.ResolvedTarget,
  optimize: *const std.builtin.OptimizeMode, path: *const Paths,
  flags: *std.BoundedArray ([] const u8, flags_size)) !?Renderer
{
  _ = target.*;
  _ = optimize.*;

  try flags.append("-DIMGUI_USE_LEGACY_CRC32_ADLER");

  if (builder.option (Renderer, "renderer",
    "Specify the renderer backend")) |backend|
  {
    switch (backend)
    {
      .Vulkan => {
        try flags.append ("-DIMGUI_IMPL_VULKAN_NO_PROTOTYPES");
        try toolbox.addSource (lib, path.getBackends (),
          "imgui_impl_vulkan.cpp", flags.slice ());
        try toolbox.addSource (lib, path.getBackends (),
          "dcimgui_impl_vulkan.cpp", flags.slice ());
      },
      .OpenGL3 => {
          try toolbox.addSource(lib, path.getBackends(),
          "imgui_impl_opengl3.cpp", flags.slice());
          try toolbox.addSource(lib, path.getBackends(),
          "cimgui_impl_opengl3.cpp", flags.slice());

          if(target.result.os.tag == .windows)
          {
              lib.linkSystemLibrary("opengl32");
          }
          else
          {
              lib.linkSystemLibrary("opengl");
          }
        }
      }
    }
    return backend;
  }
  std.log.warn ("Unspecified renderer backend", .{});
  return null;
}

pub const Platform = enum
{
  GLFW,
  SDL3,
};

pub fn platformOption (builder: *std.Build, lib: *std.Build.Step.Compile,
  target: *const std.Build.ResolvedTarget,
  optimize: *const std.builtin.OptimizeMode, path: *const Paths,
  renderer: ?Renderer, flags: *std.BoundedArray ([] const u8, flags_size)) !void
{
  if (builder.option (Platform, "platform",
    "Specify the platform backend")) |backend|
  {
    switch (backend)
    {
      .GLFW => {
        const glfw_dep = builder.dependency ("glfw", .{
          .target = target.*,
          .optimize = optimize.*,
        });

        lib.linkLibrary (glfw_dep.artifact ("glfw"));
        lib.installLibraryHeaders (glfw_dep.artifact ("glfw"));

        try toolbox.addSource (lib, path.getBackends (),
          "imgui_impl_glfw.cpp", flags.slice ());
        try toolbox.addSource (lib, path.getBackends (),
          "dcimgui_impl_glfw.cpp", flags.slice ());

        if (renderer == .Vulkan)
        {
          lib.root_module.addCMacro ("GLFW_INCLUDE_NONE", "1");
          lib.root_module.addCMacro ("GLFW_INCLUDE_VULKAN", "1");
        }
        lib.root_module.addCMacro("IMGUI_USE_LEGACY_CRC32_ADLER", "1");
      },
      .SDL3 => {
        const sdl_dep = builder.dependency("sdl", .{
          .target = target.*,
          .optimize = optimize.*,
        });

        lib.linkLibrary(sdl_dep.artifact("SDL3"));
        lib.installLibraryHeaders(sdl_dep.artifact("SDL3"));

        try toolbox.addSource(lib, path.getBackends(),
          "imgui_impl_sdl3.cpp", flags.slice());
        try toolbox.addSource(lib, path.getBackends(),
          "cimgui_impl_sdl3.cpp", flags.slice());

        lib.root_module.addCMacro("IMGUI_USE_LEGACY_CRC32_ADLER", "1");
      }
    }
  } else std.log.warn ("Unspecified platform backend", .{});
}
