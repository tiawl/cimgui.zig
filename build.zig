const std = @import ("std");

const LinkStep = struct
{
  step: std.Build.Step,
  static: *std.Build.Step.Compile,

  fn init (builder: *std.Build, static: *std.Build.Step.Compile) !*@This ()
  {
    const self = try builder.allocator.create (@This ());
    self.* = .{
      .step = std.Build.Step.init (.{
        .id = .custom,
        .name = "link",
        .owner = builder,
        .makeFn = make,
      }),
      .static = static,
    };
    return self;
  }

  fn make (step: *std.Build.Step, _: *std.Progress.Node) !void
  {
    const self = @fieldParentPtr (LinkStep, "step", step);
    const builder = step.owner;

    self.static.linkLibCpp ();

    self.static.addIncludePath (.{ .path = "imgui" });
    self.static.addIncludePath (.{ .path = "imgui/backends" });

    self.static.installHeadersDirectory ("imgui", "imgui");

    var sources = try std.BoundedArray ([] const u8, 64).init (0);

    const imgui_path = try builder.build_root.join (builder.allocator, &.{ "imgui", });

    var root = try builder.build_root.handle.openDir (".", .{ .iterate = true });
    defer root.close ();

    var it = root.iterate ();
    while (try it.next ()) |*entry|
    {
      if (std.mem.startsWith (u8, entry.name, "cimgui") and entry.kind == .file)
      {
        if (std.mem.endsWith (u8, entry.name, ".cpp"))
          try sources.append (try std.fs.path.join (builder.allocator, &.{ entry.name, }))
        else if (std.mem.endsWith (u8, entry.name, ".h"))
          self.static.installHeader (entry.name, entry.name);
      }
    }

    var imgui = try std.fs.openDirAbsolute (imgui_path, .{ .iterate = true });
    defer imgui.close ();

    it = imgui.iterate ();
    while (try it.next ()) |*entry|
    {
      if (std.mem.startsWith (u8, entry.name, "imgui") and
        std.mem.endsWith (u8, entry.name, ".cpp") and entry.kind == .file)
          try sources.append (try std.fs.path.join (builder.allocator, &.{ imgui_path , entry.name, }));
    }

    try sources.appendSlice (&.{
      "imgui/backends/imgui_impl_glfw.cpp",
      "imgui/backends/imgui_impl_vulkan.cpp",
    });

    self.static.addCSourceFiles (.{
      .files = sources.slice (),
    });
  }
};

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  const exe = builder.addExecutable (.{
    .name = "updater",
    .root_source_file = .{ .path = "src/main.zig" },
    .target = target,
    .optimize = optimize,
  });
  builder.installArtifact (exe);
  const run_cmd = builder.addRunArtifact (exe);
  const run_step = builder.step ("run", "Update the lib");
  run_step.dependOn (&run_cmd.step);

  const lib = try LinkStep.init (builder, builder.addStaticLibrary (.{
    .name = "cimgui",
    .root_source_file = builder.addWriteFiles ().add ("empty.c", ""),
    .target = target,
    .optimize = optimize,
  }));
  builder.installArtifact (lib.static);
}
