const std = @import ("std");
const toolbox = @import ("toolbox");

const utils = @import ("build/utils.zig");
const Paths = utils.Paths;
const flags_size = utils.flags_size;

const backends = @import ("build/backends.zig");
pub const Renderer = backends.Renderer;
pub const Platform = backends.Platform;
const rendererOption = backends.rendererOption;
const platformOption = backends.platformOption;

fn update (builder: *std.Build, path: *const Paths,
  dependencies: *const toolbox.Dependencies) !void
{
  std.fs.deleteTreeAbsolute (path.getCimgui ()) catch |err|
  {
    switch (err)
    {
      error.FileNotFound => {},
      else => return err,
    }
  };

  try dependencies.clone (builder, "imgui", path.getCimgui ());

  var cimgui_dir = try std.fs.openDirAbsolute (path.getCimgui (),
    .{ .iterate = true, });
  defer cimgui_dir.close ();

  var it = cimgui_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    if (!std.mem.eql (u8, entry.name, "backends") and
      !std.mem.startsWith (u8, entry.name, "im"))
        try std.fs.deleteTreeAbsolute (try std.fs.path.join (builder.allocator,
          &.{ path.getCimgui (), entry.name, }));
  }

  var backends_dir = try std.fs.openDirAbsolute (path.getBackends (),
    .{ .iterate = true, });
  defer backends_dir.close ();

  const binding_py = try builder.build_root.join (builder.allocator,
    &.{ "dear_bindings", "dear_bindings.py", });
  const imconfig_h = try std.fs.path.join (builder.allocator,
    &.{ path.getCimgui (), "imconfig.h", });
  const imgui_h = try std.fs.path.join (builder.allocator,
    &.{ path.getCimgui (), "imgui.h", });
  const glfw_backend_h = try std.fs.path.join (builder.allocator,
    &.{ path.getBackends (), "imgui_impl_glfw.h", });
  const vulkan_backend_h = try std.fs.path.join (builder.allocator, &.{
    path.getBackends (), "imgui_impl_vulkan.h", });
  const imgui_out = try std.fs.path.join (builder.allocator,
    &.{ path.getCimgui (), "cimgui", });
  const glfw_out = try std.fs.path.join (builder.allocator,
    &.{ path.getBackends (), "cimgui_impl_glfw", });
  const vulkan_out = try std.fs.path.join (builder.allocator,
    &.{ path.getBackends (), "cimgui_impl_vulkan", });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "python3", binding_py,
    "--output", imgui_out, imgui_h, }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "python3", binding_py,
    "--backend", "--imconfig-path", imconfig_h,
    "--output", glfw_out, glfw_backend_h, }, });
  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "python3", binding_py,
    "--backend", "--imconfig-path", imconfig_h,
    "--output", vulkan_out, vulkan_backend_h, }, });

  it = backends_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    switch (entry.kind)
    {
      .file => {
        if ((!std.mem.startsWith (u8, entry.name, "imgui_impl_") and
          !std.mem.startsWith (u8, entry.name, "cimgui_impl_")) or
            (std.mem.indexOf (u8, entry.name, "vulkan") == null and
            std.mem.indexOf (u8, entry.name, "glfw") == null) or
              (!toolbox.isCppSource (entry.name) and
              !toolbox.isCHeader (entry.name)))
                try std.fs.deleteFileAbsolute (try std.fs.path.join (
                  builder.allocator, &.{ path.getBackends (), entry.name, }));
      },
      .directory => try std.fs.deleteTreeAbsolute (try std.fs.path.join (
        builder.allocator, &.{ path.getBackends (), entry.name, })),
      else => {},
    }
  }

  try toolbox.clean (builder, &.{ "cimgui", }, &.{});
}

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  const path = try Paths.init (builder);

  const dependencies = try toolbox.Dependencies.init (builder, "cimgui.zig",
  .{
     .toolbox = .{
       .name = "tiawl/toolbox",
       .host = toolbox.Repository.Host.github,
     },
     .glfw = .{
       .name = "tiawl/glfw.zig",
       .host = toolbox.Repository.Host.github,
     },
   }, .{
     .imgui = .{
       .name = "ocornut/imgui",
       .host = toolbox.Repository.Host.github,
     },
   });

  if (builder.option (bool, "update", "Update binding") orelse false)
    try update (builder, &path, &dependencies);

  const lib = builder.addStaticLibrary (.{
    .name = "cimgui",
    .root_source_file = builder.addWriteFiles ().add ("empty.c", ""),
    .target = target,
    .optimize = optimize,
  });

  var flags = try std.BoundedArray ([] const u8, flags_size).init (0);

  var root_dir = try builder.build_root.handle.openDir (".",
    .{ .iterate = true, });
  defer root_dir.close ();

  var walk = try root_dir.walk (builder.allocator);

  while (try walk.next ()) |*entry|
  {
    if (std.mem.startsWith (u8, entry.path, "cimgui") and
      entry.kind == .directory) toolbox.addInclude (lib, entry.path);
  }

  var cimgui_dir = try std.fs.openDirAbsolute (path.getCimgui (),
    .{ .iterate = true, });
  defer cimgui_dir.close ();

  toolbox.addHeader (lib, path.getCimgui (), ".", &.{ ".h", });

  lib.linkLibCpp ();

  var it = cimgui_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    if ((std.mem.startsWith (u8, entry.name, "imgui") or
      std.mem.startsWith (u8, entry.name, "cimgui")) and
      toolbox.isCppSource (entry.name) and entry.kind == .file)
        try toolbox.addSource (lib, path.getCimgui (), entry.name,
          flags.slice ());
  }

  const renderer =
    try rendererOption (builder, lib, &target, &optimize, &path, &flags);
  try platformOption (builder, lib, &target, &optimize, &path,
    renderer, &flags);

  builder.installArtifact (lib);
}
