const std = @import ("std");
const toolbox = @import ("toolbox");

const utils = @import ("utils.zig");
const Paths = utils.Paths;
const flags_size = utils.flags_size;

pub const Renderer = enum
{
  Vulkan,
};

pub fn rendererOption (builder: *std.Build, lib: *std.Build.Step.Compile,
  target: *const std.Build.ResolvedTarget,
  optimize: *const std.builtin.OptimizeMode, path: *const Paths,
  flags: *std.BoundedArray ([] const u8, flags_size)) !?Renderer
{
  _ = target.*;
  _ = optimize.*;

  if (builder.option (Renderer, "renderer",
    "Specify the renderer backend")) |backend|
  {
    switch (backend)
    {
      .Vulkan => {
        try flags.append ("-DIMGUI_IMPL_VULKAN_NO_PROTOTYPES");
        try toolbox.addSource (lib, path.getBackends (),
          "cimgui_impl_vulkan.cpp", flags.slice ());
      },
    }
    return backend;
  }
  std.log.warn ("Unspecified renderer backend", .{});
  return null;
}

pub const Platform = enum
{
  GLFW,
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
          "cimgui_impl_glfw.cpp", flags.slice ());

        if (renderer == .Vulkan)
        {
          lib.root_module.addCMacro ("GLFW_INCLUDE_NONE", "1");
          lib.root_module.addCMacro ("GLFW_INCLUDE_VULKAN", "1");
        }
      },
    }
  } else std.log.warn ("Unspecified platform backend", .{});
}
