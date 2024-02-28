const std = @import ("std");

const LinkStep = struct
{
  step: std.Build.Step,
  includes: std.BoundedArray ([] const u8, 64),
  sources: std.BoundedArray ([] const u8, 64),
  headers: std.BoundedArray ([] const u8, 64),

  fn init (builder: *std.Build) !*@This ()
  {
    const self = try builder.allocator.create (@This ());
    self.* = .{
      .step = std.Build.Step.init (.{
        .id = .custom,
        .name = "link",
        .owner = builder,
        .makeFn = make,
      }),
      .includes = try std.BoundedArray ([] const u8, 64).init (0),
      .sources = try std.BoundedArray ([] const u8, 64).init (0),
      .headers = try std.BoundedArray ([] const u8, 64).init (0),
    };
    return self;
  }

  fn make (step: *std.Build.Step, _: *std.Progress.Node) !void
  {
    const self = @fieldParentPtr (LinkStep, "step", step);
    const builder = step.owner;

    const imgui_path = try builder.build_root.join (builder.allocator, &.{ "imgui", });
    const backends_path = try std.fs.path.join (builder.allocator, &.{ imgui_path, "backends", });

    var root = try builder.build_root.handle.openDir (".", .{ .iterate = true });
    defer root.close ();

    var walk = try root.walk (builder.allocator);

    while (try walk.next ()) |*entry|
    {
      if (std.mem.startsWith (u8, entry.path, "imgui") and entry.kind == .directory)
        try self.headers.append (entry.path);
    }

    var it = root.iterate ();
    while (try it.next ()) |*entry|
    {
      if (std.mem.startsWith (u8, entry.name, "cimgui") and entry.kind == .file)
      {
        if (std.mem.endsWith (u8, entry.name, ".cpp"))
          try self.sources.append (try std.fs.path.join (builder.allocator, &.{ entry.name, }))
        else if (std.mem.endsWith (u8, entry.name, ".h"))
          try self.headers.append (entry.name);
      }
    }

    var imgui = try std.fs.openDirAbsolute (imgui_path, .{ .iterate = true });
    defer imgui.close ();

    it = imgui.iterate ();
    while (try it.next ()) |*entry|
    {
      if (std.mem.startsWith (u8, entry.name, "imgui") and
        std.mem.endsWith (u8, entry.name, ".cpp") and entry.kind == .file)
          try self.sources.append (try std.fs.path.join (builder.allocator, &.{ imgui_path , entry.name, }));
    }

    try self.sources.appendSlice (&.{
      try std.fs.path.join (builder.allocator, &.{ backends_path, "imgui_impl_glfw.cpp", }),
      try std.fs.path.join (builder.allocator, &.{ backends_path, "imgui_impl_vulkan.cpp", }),
    });
  }
};

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  const exe = builder.addExecutable (.{
    .name = "updater",
    .root_source_file = .{ .path = try builder.build_root.join (builder.allocator, &.{ "src", "main.zig", }), },
    .target = target,
    .optimize = optimize,
  });
  builder.installArtifact (exe);
  const run_cmd = builder.addRunArtifact (exe);
  const run_step = builder.step ("run", "Update the lib");
  run_step.dependOn (&run_cmd.step);

  const lib = builder.addStaticLibrary (.{
    .name = "cimgui",
    .root_source_file = builder.addWriteFiles ().add ("empty.c", ""),
    .target = target,
    .optimize = optimize,
  });
  var link = try LinkStep.init (builder);

  lib.linkLibCpp ();

  for (link.includes.slice ()) |include| lib.addIncludePath (.{ .path = include, });

  lib.addCSourceFiles (.{
    .files = link.sources.slice (),
  });

  lib.installHeadersDirectory ("imgui", "imgui");
  for (link.headers.slice ()) |header| lib.installHeader (header, header);

  builder.installArtifact (lib);
  lib.step.dependOn (&link.step);
}
