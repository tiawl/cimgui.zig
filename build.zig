const std = @import("std");

pub fn build (builder: *std.Build) void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  const exe = builder.addExecutable (.{
      .name = "test",
      .root_source_file = .{ .path = "src/main.zig" },
      .target = target,
      .optimize = optimize,
  });

  builder.installArtifact (exe);

  const run_cmd = builder.addRunArtifact (exe);
  run_cmd.step.dependOn (builder.getInstallStep ());

  const run_step = builder.step ("run", "Run the app");
  run_step.dependOn (&run_cmd.step);
}
