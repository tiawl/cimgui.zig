const std = @import ("std");

const build = @import ("build_options");
const IMCONFIG_H_PATH = build.IMCONFIG_H_PATH;
const IMGUI_H_PATH = build.IMGUI_H_PATH;
const IMGUI_IMPL_GLFW_H_PATH = build.IMGUI_IMPL_GLFW_H_PATH;
const IMGUI_IMPL_VULKAN_H_PATH = build.IMGUI_IMPL_VULKAN_H_PATH;

fn exec (allocator: std.mem.Allocator, argv: [] const [] const u8) !void
{
  var stdout = std.ArrayList (u8).init (allocator);
  var stderr = std.ArrayList (u8).init (allocator);
  errdefer { stdout.deinit (); stderr.deinit (); }

  std.debug.print ("\x1b[35m[{s}]\x1b[0m\n", .{ try std.mem.join (allocator, " ", argv), });

  var child = std.ChildProcess.init (argv, allocator);

  child.stdin_behavior = .Ignore;
  child.stdout_behavior = .Pipe;
  child.stderr_behavior = .Pipe;

  try child.spawn ();
  try child.collectOutput (&stdout, &stderr, 1000);

  const term = try child.wait ();

  if (stdout.items.len > 0) std.debug.print ("{s}", .{ stdout.items });
  if (stderr.items.len > 0 and !std.meta.eql (term, std.ChildProcess.Term { .Exited = 0 })) std.debug.print ("\x1b[31m{s}\x1b[0m", .{ stderr.items });
  try std.testing.expectEqual (term, std.ChildProcess.Term { .Exited = 0 });
}

pub fn main () !void
{
  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  const allocator = arena.allocator ();

  const cwd = std.fs.cwd ();

  if (cwd.access ("cimgui.cpp", .{}) == error.FileNotFound) try exec (allocator, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--output", "cimgui", IMGUI_H_PATH });
  if (cwd.access ("cimgui_impl_glfw.cpp", .{}) == error.FileNotFound) try exec (allocator, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--backend", "--imconfig-path", IMCONFIG_H_PATH, "--output", "cimgui_impl_glfw", IMGUI_IMPL_GLFW_H_PATH, });
  if (cwd.access ("cimgui_impl_vulkan.cpp", .{}) == error.FileNotFound) try exec (allocator, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--backend", "--imconfig-path", IMCONFIG_H_PATH, "--output", "cimgui_impl_vulkan", IMGUI_IMPL_VULKAN_H_PATH, });

}
