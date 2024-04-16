const std = @import ("std");
const toolbox = @import ("toolbox");
const pkg = .{ .name = "cimgui.zig", .version = "1.90.4", };

const Paths = struct
{
  cimgui: [] const u8 = undefined,
  backends: [] const u8 = undefined,
};

fn update (builder: *std.Build, path: *const Paths) !void
{
  std.fs.deleteTreeAbsolute (path.cimgui) catch |err|
  {
    switch (err)
    {
      error.FileNotFound => {},
      else => return err,
    }
  };

  try toolbox.clone (builder, "https://github.com/ocornut/imgui.git",
    "v" ++ pkg.version, path.cimgui);

  var cimgui_dir = try std.fs.openDirAbsolute (path.cimgui,
    .{ .iterate = true, });
  defer cimgui_dir.close ();

  var it = cimgui_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    if (!std.mem.eql (u8, entry.name, "backends") and
      !std.mem.startsWith (u8, entry.name, "im"))
        try std.fs.deleteTreeAbsolute (try std.fs.path.join (builder.allocator,
          &.{ path.cimgui, entry.name, }));
  }

  var backends_dir = try std.fs.openDirAbsolute (path.backends,
    .{ .iterate = true, });
  defer backends_dir.close ();

  const binding_py = try builder.build_root.join (builder.allocator,
    &.{ "dear_bindings", "dear_bindings.py", });
  const imconfig_h = try std.fs.path.join (builder.allocator,
    &.{ path.cimgui, "imconfig.h", });
  const imgui_h = try std.fs.path.join (builder.allocator,
    &.{ path.cimgui, "imgui.h", });
  const glfw_backend_h = try std.fs.path.join (builder.allocator,
    &.{ path.backends, "imgui_impl_glfw.h", });
  const vulkan_backend_h = try std.fs.path.join (builder.allocator, &.{
    path.backends, "imgui_impl_vulkan.h", });
  const imgui_out = try std.fs.path.join (builder.allocator,
    &.{ path.cimgui, "cimgui", });
  const glfw_out = try std.fs.path.join (builder.allocator,
    &.{ path.backends, "cimgui_impl_glfw", });
  const vulkan_out = try std.fs.path.join (builder.allocator,
    &.{ path.backends, "cimgui_impl_vulkan", });
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
                  builder.allocator, &.{ path.backends, entry.name, }));
      },
      .directory => try std.fs.deleteTreeAbsolute (try std.fs.path.join (
        builder.allocator, &.{ path.backends, entry.name, })),
      else => {},
    }
  }
}

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  var path: Paths = .{};
  path.cimgui = try builder.build_root.join (builder.allocator,
    &.{ "cimgui", });
  path.backends = try std.fs.path.join (builder.allocator,
    &.{ path.cimgui, "backends", });

  if (builder.option (bool, "update", "Update binding") orelse false)
    try update (builder, &path);

  const lib = builder.addStaticLibrary (.{
    .name = "cimgui",
    .root_source_file = builder.addWriteFiles ().add ("empty.c", ""),
    .target = target,
    .optimize = optimize,
  });

  const flags = [_][] const u8 { "-DIMGUI_IMPL_VULKAN_NO_PROTOTYPES", };

  var root_dir = try builder.build_root.handle.openDir (".",
    .{ .iterate = true, });
  defer root_dir.close ();

  var walk = try root_dir.walk (builder.allocator);

  while (try walk.next ()) |*entry|
  {
    if (std.mem.startsWith (u8, entry.path, "cimgui") and
      entry.kind == .directory) toolbox.addInclude (lib, entry.path);
  }

  var cimgui_dir = try std.fs.openDirAbsolute (path.cimgui,
    .{ .iterate = true, });
  defer cimgui_dir.close ();
  var backends_dir = try std.fs.openDirAbsolute (path.backends,
    .{ .iterate = true, });
  defer backends_dir.close ();

  const glfw_dep = builder.dependency ("glfw", .{
    .target = target,
    .optimize = optimize,
  });

  lib.linkLibrary (glfw_dep.artifact ("glfw"));
  lib.installLibraryHeaders (glfw_dep.artifact ("glfw"));

  toolbox.addHeader (lib, path.cimgui, "cimgui", &.{ ".h", });

  lib.linkLibCpp ();

  var it = cimgui_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    if ((std.mem.startsWith (u8, entry.name, "imgui") or
      std.mem.startsWith (u8, entry.name, "cimgui")) and
        toolbox.isCppSource (entry.name) and entry.kind == .file)
          try toolbox.addSource (lib, path.cimgui, entry.name, &flags);
  }

  it = backends_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    if (toolbox.isCppSource (entry.name))
      try toolbox.addSource (lib, path.backends, entry.name, &flags);
  }

  lib.root_module.addCMacro ("GLFW_INCLUDE_NONE", "1");
  lib.root_module.addCMacro ("GLFW_INCLUDE_VULKAN", "1");

  builder.installArtifact (lib);
}
