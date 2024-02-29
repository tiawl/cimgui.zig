const std = @import ("std");
const pkg = .{ .name = "cimgui.zig", .version = "1.90.4", };

fn exec (builder: *std.Build, argv: [] const [] const u8) !void
{
  var stdout = std.ArrayList (u8).init (builder.allocator);
  var stderr = std.ArrayList (u8).init (builder.allocator);
  errdefer { stdout.deinit (); stderr.deinit (); }

  std.debug.print ("\x1b[35m[{s}]\x1b[0m\n", .{ try std.mem.join (builder.allocator, " ", argv), });

  var child = std.ChildProcess.init (argv, builder.allocator);

  child.stdin_behavior = .Ignore;
  child.stdout_behavior = .Pipe;
  child.stderr_behavior = .Pipe;

  try child.spawn ();
  try child.collectOutput (&stdout, &stderr, 1000);

  const term = try child.wait ();

  if (stdout.items.len > 0) std.debug.print ("{s}", .{ stdout.items, });
  if (stderr.items.len > 0 and !std.meta.eql (term, std.ChildProcess.Term { .Exited = 0, })) std.debug.print ("\x1b[31m{s}\x1b[0m", .{ stderr.items, });
  try std.testing.expectEqual (term, std.ChildProcess.Term { .Exited = 0, });
}

fn update (builder: *std.Build) !void
{
  const imgui_path = try builder.build_root.join (builder.allocator, &.{ "imgui", });
  const backends_path = try std.fs.path.join (builder.allocator, &.{ imgui_path, "backends", });

  std.fs.deleteTreeAbsolute (imgui_path) catch |err|
  {
    switch (err)
    {
      error.FileNotFound => {},
      else => return err,
    }
  };

  try exec (builder, &[_][] const u8 { "git", "clone", "https://github.com/ocornut/imgui.git", imgui_path, });
  try exec (builder, &[_][] const u8 { "git", "-C", imgui_path, "checkout", "v" ++ pkg.version, });

  var imgui = try std.fs.openDirAbsolute (imgui_path, .{ .iterate = true, });
  defer imgui.close ();

  var it = imgui.iterate ();
  while (try it.next ()) |*entry|
  {
    if (!std.mem.eql (u8, entry.name, "backends") and
      !std.mem.startsWith (u8, entry.name, "im"))
        try std.fs.deleteTreeAbsolute (try std.fs.path.join (builder.allocator, &.{ imgui_path, entry.name, }));
  }

  var backends = try std.fs.openDirAbsolute (backends_path, .{ .iterate = true, });
  defer backends.close ();

  it = backends.iterate ();
  while (try it.next ()) |*entry|
  {
    if (!std.mem.startsWith (u8, entry.name, "imgui"))
      try std.fs.deleteTreeAbsolute (try std.fs.path.join (builder.allocator, &.{ backends_path, entry.name, }));
  }

  try exec (builder, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--output", "cimgui", "imgui/imgui.h", });
  try exec (builder, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--backend", "--imconfig-path", "imgui/imconfig.h", "--output", "cimgui_impl_glfw", "imgui/backends/imgui_impl_glfw.h", });
  try exec (builder, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--backend", "--imconfig-path", "imgui/imconfig.h", "--output", "cimgui_impl_vulkan", "imgui/backends/imgui_impl_vulkan.h", });
}

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  if (builder.option (bool, "update", "Update binding") orelse false) try update (builder);

  const lib = builder.addStaticLibrary (.{
    .name = "cimgui",
    .root_source_file = builder.addWriteFiles ().add ("empty.c", ""),
    .target = target,
    .optimize = optimize,
  });

  const vulkan_dep = builder.dependency ("vulkan", .{
    .target = target,
    .optimize = optimize,
  });
  lib.installLibraryHeaders (vulkan_dep.artifact ("vulkan"));

  var includes = try std.BoundedArray ([] const u8, 64).init (0);
  var sources = try std.BoundedArray ([] const u8, 64).init (0);
  var headers = try std.BoundedArray ([] const u8, 64).init (0);

  lib.linkLibCpp ();

  const imgui_path = try builder.build_root.join (builder.allocator, &.{ "imgui", });
  const backends_path = try std.fs.path.join (builder.allocator, &.{ imgui_path, "backends", });

  var root = try builder.build_root.handle.openDir (".", .{ .iterate = true, });
  defer root.close ();

  var walk = try root.walk (builder.allocator);

  while (try walk.next ()) |*entry|
  {
    if (std.mem.startsWith (u8, entry.path, "imgui") and entry.kind == .directory)
      try includes.append (builder.dupe (entry.path));
  }

  var it = root.iterate ();
  while (try it.next ()) |*entry|
  {
    if (std.mem.startsWith (u8, entry.name, "cimgui") and entry.kind == .file)
    {
      if (std.mem.endsWith (u8, entry.name, ".cpp"))
        try sources.append (try builder.build_root.join (builder.allocator, &.{ entry.name, }))
      else if (std.mem.endsWith (u8, entry.name, ".h"))
        try headers.append (builder.dupe (entry.name));
    }
  }

  var imgui = try std.fs.openDirAbsolute (imgui_path, .{ .iterate = true, });
  defer imgui.close ();

  it = imgui.iterate ();
  while (try it.next ()) |*entry|
  {
    if (std.mem.startsWith (u8, entry.name, "imgui") and
      std.mem.endsWith (u8, entry.name, ".cpp") and entry.kind == .file)
        try sources.append (try std.fs.path.join (builder.allocator, &.{ imgui_path , entry.name, }));
  }

  try sources.appendSlice (&.{
    try std.fs.path.join (builder.allocator, &.{ backends_path, "imgui_impl_glfw.cpp", }),
    try std.fs.path.join (builder.allocator, &.{ backends_path, "imgui_impl_vulkan.cpp", }),
  });

  for (includes.slice ()) |include|
  {
    std.debug.print ("[cimgui include] {s}\n", .{ try builder.build_root.join (builder.allocator, &.{ include, }), });
    lib.addIncludePath (.{ .path = include, });
  }

  for (sources.slice ()) |source| std.debug.print ("[cimgui source] {s}\n", .{ source, });
  lib.addCSourceFiles (.{
    .files = sources.slice (),
  });

  lib.installHeadersDirectory ("imgui", "imgui");
  std.debug.print ("[cimgui headers dir] {s}\n", .{ imgui_path, });
  for (headers.slice ()) |header|
  {
    std.debug.print ("[cimgui header] {s}\n", .{ try builder.build_root.join (builder.allocator, &.{ header, }), });
    lib.installHeader (header, header);
  }

  builder.installArtifact (lib);
}
