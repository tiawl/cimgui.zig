const std = @import ("std");
const pkg = .{ .name = "cimgui.zig", .version = "1.90.4" };

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

  const cwd_path = try std.fs.cwd ().realpathAlloc (allocator, ".");
  const imgui_path = try std.fs.path.join (allocator, &.{ cwd_path, "imgui", });

  std.fs.deleteTreeAbsolute (imgui_path) catch |err|
  {
    switch (err)
    {
      error.FileNotFound => {},
      else => return err,
    }
  };

  try exec (allocator, &[_][] const u8 { "git", "clone", "https://github.com/ocornut/imgui.git", imgui_path });
  try exec (allocator, &[_][] const u8 { "git", "-C", imgui_path, "checkout", "v" ++ pkg.version });

  var imgui = try std.fs.openDirAbsolute (imgui_path, .{ .iterate = true });
  defer imgui.close ();

  var it = imgui.iterate ();
  while (try it.next ()) |*entry|
  {
    if (!std.mem.eql (u8, entry.name, "backends") and
        !std.mem.startsWith (u8, entry.name, "imgui") and
        !std.mem.startsWith (u8, entry.name, "imconfig"))
      try std.fs.deleteTreeAbsolute (try std.fs.path.join (allocator, &.{ imgui_path, entry.name, }));
  }

  try exec (allocator, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--output", "cimgui", "imgui/imgui.h" });
  try exec (allocator, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--backend", "--imconfig-path", "imgui/imconfig.h", "--output", "cimgui_impl_glfw", "imgui/backends/imgui_impl_glfw.h", });
  try exec (allocator, &[_][] const u8 { "python3", "./dear_bindings/dear_bindings.py", "--backend", "--imconfig-path", "imgui/imconfig.h", "--output", "cimgui_impl_vulkan", "imgui/backends/imgui_impl_vulkan.h", });
}
