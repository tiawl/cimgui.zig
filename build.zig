const std = @import ("std");

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  const exe = builder.addExecutable (.{
    .name = "binding_generator",
    .root_source_file = .{ .path = "src/main.zig" },
    .target = target,
    .optimize = optimize,
  });
  builder.installArtifact (exe);
  const run_cmd = builder.addRunArtifact (exe);
  const run_step = builder.step ("run", "Run the app");
  run_step.dependOn (&run_cmd.step);

  const lib = builder.addStaticLibrary (.{
    .name = "cimgui",
    .target = target,
    .optimize = optimize,
  });

  lib.linkLibC ();
  lib.linkLibCpp ();

  lib.addIncludePath (.{ .path = "imgui" });
  lib.addIncludePath (.{ .path = "imgui/backends" });

  lib.addCSourceFiles (.{
    .files = &.{
      "cimgui.cpp",
      "cimgui_impl_glfw.cpp",
      "cimgui_impl_vulkan.cpp",
      "imgui/imgui.cpp",
      "imgui/imgui_demo.cpp",
      "imgui/imgui_draw.cpp",
      "imgui/imgui_tables.cpp",
      "imgui/imgui_widgets.cpp",
      "imgui/backends/imgui_impl_glfw.cpp",
      "imgui/backends/imgui_impl_vulkan.cpp",
    },
  });

  lib.installHeadersDirectory ("imgui", "imgui");
  lib.installHeader ("cimgui.h", "cimgui.h");
  lib.installHeader ("cimgui_impl_glfw.h", "cimgui_impl_glfw.h");
  lib.installHeader ("cimgui_impl_vulkan.h", "cimgui_impl_vulkan.h");

  builder.installArtifact (lib);
}
