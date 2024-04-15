const std = @import ("std");
const toolbox = @import ("toolbox");
const pkg = .{ .name = "cimgui.zig", .version = "1.90.4", };

const Paths = struct
{
  imgui: [] const u8 = undefined,
  backends: [] const u8 = undefined,
};

fn update (builder: *std.Build, path: *const Paths) !void
{
  std.fs.deleteTreeAbsolute (path.imgui) catch |err|
  {
    switch (err)
    {
      error.FileNotFound => {},
      else => return err,
    }
  };

  try toolbox.run (builder, .{ .argv = &[_][] const u8 { "git", "clone",
    "--branch", "v" ++ pkg.version, "--depth", "1",
    "https://github.com/ocornut/imgui.git", path.imgui, }, });

  var imgui_dir = try std.fs.openDirAbsolute (path.imgui,
    .{ .iterate = true, });
  defer imgui_dir.close ();

  var it = imgui_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    if (!std.mem.eql (u8, entry.name, "backends") and
      !std.mem.startsWith (u8, entry.name, "im"))
        try std.fs.deleteTreeAbsolute (try std.fs.path.join (builder.allocator,
          &.{ path.imgui, entry.name, }));
  }

  var backends_dir = try std.fs.openDirAbsolute (path.backends,
    .{ .iterate = true, });
  defer backends_dir.close ();

  const binding_py = try builder.build_root.join (builder.allocator,
    &.{ "dear_bindings", "dear_bindings.py", });
  const imconfig_h = try std.fs.path.join (builder.allocator,
    &.{ path.imgui, "imconfig.h", });
  const imgui_h = try std.fs.path.join (builder.allocator,
    &.{ path.imgui, "imgui.h", });
  const glfw_backend_h = try std.fs.path.join (builder.allocator,
    &.{ path.backends, "imgui_impl_glfw.h", });
  const vulkan_backend_h = try std.fs.path.join (builder.allocator, &.{
    path.backends, "imgui_impl_vulkan.h", });
  const imgui_out = try std.fs.path.join (builder.allocator,
    &.{ path.imgui, "cimgui", });
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
              (!toolbox.is_cpp_source_file (entry.name) and
              !toolbox.is_c_header_file (entry.name)))
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
  path.imgui = try builder.build_root.join (builder.allocator,
    &.{ "imgui", });
  path.backends = try std.fs.path.join (builder.allocator,
    &.{ path.imgui, "backends", });

  if (builder.option (bool, "update", "Update binding") orelse false)
    try update (builder, &path);

  const lib = builder.addStaticLibrary (.{
    .name = "cimgui",
    .root_source_file = builder.addWriteFiles ().add ("empty.c", ""),
    .target = target,
    .optimize = optimize,
  });

  var includes = try std.BoundedArray (std.Build.LazyPath, 64).init (0);
  var sources = try std.BoundedArray ([] const u8, 64).init (0);
  var headers = try std.BoundedArray ([] const u8, 64).init (0);

  var root_dir = try builder.build_root.handle.openDir (".",
    .{ .iterate = true, });
  defer root_dir.close ();

  var walk = try root_dir.walk (builder.allocator);

  while (try walk.next ()) |*entry|
  {
    if (std.mem.startsWith (u8, entry.path, "imgui") and
      entry.kind == .directory)
        try includes.append (.{ .path = builder.dupe (entry.path), });
  }

  var it = root_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    if (std.mem.startsWith (u8, entry.name, "cimgui") and entry.kind == .file)
    {
      if (toolbox.is_c_header_file (entry.name))
        try headers.append (builder.dupe (entry.name));
    }
  }

  var imgui_dir = try std.fs.openDirAbsolute (path.imgui,
    .{ .iterate = true, });
  defer imgui_dir.close ();
  var backends_dir = try std.fs.openDirAbsolute (path.backends,
    .{ .iterate = true, });
  defer backends_dir.close ();

  for (includes.slice ()) |include|
  {
    std.debug.print ("[cimgui include] {s}\n", .{ include.getPath (builder), });
    lib.addIncludePath (include);
  }

  const glfw_dep = builder.dependency ("glfw", .{
    .target = target,
    .optimize = optimize,
  });

  lib.linkLibrary (glfw_dep.artifact ("glfw"));
  lib.installLibraryHeaders (glfw_dep.artifact ("glfw"));

  lib.installHeadersDirectory (.{ .path = path.imgui, }, "imgui",
    .{ .include_extensions = &.{ ".h", }, });
  std.debug.print ("[cimgui headers dir] {s}\n", .{ path.imgui, });
  for (headers.slice ()) |header|
  {
    const header_path = try builder.build_root.join (builder.allocator,
      &.{ header, });
    std.debug.print ("[cimgui header] {s}\n", .{ header_path, });
    lib.installHeader (.{ .path = header_path, }, header);
  }

  lib.linkLibCpp ();

  it = imgui_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    if ((std.mem.startsWith (u8, entry.name, "imgui") or
      std.mem.startsWith (u8, entry.name, "cimgui")) and
        toolbox.is_cpp_source_file (entry.name) and entry.kind == .file)
    {
      const source_path = try std.fs.path.join (builder.allocator,
        &.{ path.imgui, entry.name, });
      std.debug.print ("[cimgui source] {s}\n", .{ source_path, });
      try sources.append (try std.fs.path.relative (builder.allocator,
        builder.build_root.path.?, source_path));
    }
  }

  it = backends_dir.iterate ();
  while (try it.next ()) |*entry|
  {
    if (toolbox.is_cpp_source_file (entry.name))
    {
      const source_path = try std.fs.path.join (builder.allocator,
        &.{ path.backends, entry.name, });
      std.debug.print ("[cimgui source] {s}\n", .{ source_path, });
      try sources.append (try std.fs.path.relative (builder.allocator,
        builder.build_root.path.?, source_path));
    }
  }

  lib.addCSourceFiles (.{
    .files = sources.slice (),
    .flags = &.{ "-DIMGUI_IMPL_VULKAN_NO_PROTOTYPES", },
  });

  lib.root_module.addCMacro ("GLFW_INCLUDE_NONE", "1");
  lib.root_module.addCMacro ("GLFW_INCLUDE_VULKAN", "1");

  builder.installArtifact (lib);
}
