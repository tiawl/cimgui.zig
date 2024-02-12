const std = @import ("std");

fn exec (builder: *std.Build, argv: [] const [] const u8) !void
{
  var stdout = std.ArrayList (u8).init (builder.allocator);
  var stderr = std.ArrayList (u8).init (builder.allocator);
  errdefer { stdout.deinit (); stderr.deinit (); }

  var child = std.ChildProcess.init (argv, builder.allocator);

  child.stdin_behavior = .Ignore;
  child.stdout_behavior = .Pipe;
  child.stderr_behavior = .Pipe;

  try child.spawn ();
  try child.collectOutput (&stdout, &stderr, 1000);

  const term = try child.wait ();

  std.debug.print ("\x1b[35m[{s}]\x1b[0m\n", .{ try std.mem.join (builder.allocator, " ", argv), });
  if (stdout.items.len > 0) std.debug.print ("{s}", .{ stdout.items });
  if (stderr.items.len > 0) std.debug.print ("\x1b[31m{s}\x1b[0m", .{ stderr.items });
  try std.testing.expectEqual (term, std.ChildProcess.Term { .Exited = 0 });
}

pub fn build (builder: *std.Build) !void
{
  try exec (builder, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--output", "cimgui", "./imgui/imgui.h" });
  try exec (builder, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--backend", "--imconfig-path", "./imgui/imconfig.h", "--output", "cimgui_impl_vulkan", "./imgui/backends/imgui_impl_vulkan.h" });
  try exec (builder, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--backend", "--imconfig-path", "./imgui/imconfig.h", "--output", "cimgui_impl_glfw", "./imgui/backends/imgui_impl_glfw.h" });
}
