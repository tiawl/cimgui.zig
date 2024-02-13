const std = @import ("std");

pub fn build (builder: *std.Build) !void
{
  const target = builder.standardTargetOptions (.{});
  const optimize = builder.standardOptimizeOption (.{});

  const imgui = builder.dependency ("imgui", .{
    .target = target,
    .optimize = optimize,
  });

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
  var options = builder.addOptions ();
  options.addOption ([] const u8, "IMCONFIG_H_PATH", imgui.path ("imgui/imconfig.h").getPath (builder));
  options.addOption ([] const u8, "IMGUI_H_PATH", imgui.path ("imgui/imgui.h").getPath (builder));
  options.addOption ([] const u8, "IMGUI_IMPL_GLFW_H_PATH", imgui.path ("imgui/backends/imgui_impl_glfw.h").getPath (builder));
  options.addOption ([] const u8, "IMGUI_IMPL_VULKAN_H_PATH", imgui.path ("imgui/backends/imgui_impl_vulkan.h").getPath (builder));
  exe.root_module.addImport ("build_options", options.createModule ());

  const lib = builder.addStaticLibrary (.{
    .name = "cimgui",
    .target = target,
    .optimize = optimize,
  });

  lib.addIncludePath (imgui.path ("imgui"));
  lib.addIncludePath (imgui.path ("imgui/backends"));

  lib.addCSourceFiles (.{
    .files = &.{
      "cimgui.cpp",
      "cimgui_impl_glfw.cpp",
      "cimgui_impl_vulkan.cpp",
      imgui.path ("imgui/imgui.cpp").getPath (builder),
      imgui.path ("imgui/imgui_demo.cpp").getPath (builder),
      imgui.path ("imgui/imgui_draw.cpp").getPath (builder),
      imgui.path ("imgui/imgui_tables.cpp").getPath (builder),
      imgui.path ("imgui/imgui_widgets.cpp").getPath (builder),
      imgui.path ("imgui/backends/imgui_impl_glfw.cpp").getPath (builder),
      imgui.path ("imgui/backends/imgui_impl_vulkan.cpp").getPath (builder),
    },
  });
  lib.linkLibC ();
  lib.installHeadersDirectory (imgui.path ("imgui").getPath (builder), "imgui");
  lib.installHeader ("cimgui.h", "cimgui.h");
  lib.installHeader ("cimgui_impl_glfw.h", "cimgui_impl_glfw.h");
  lib.installHeader ("cimgui_impl_vulkan.h", "cimgui_impl_vulkan.h");
  builder.installArtifact (lib);
}
