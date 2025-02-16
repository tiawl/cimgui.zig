# cimgui.zig

This is a fork of [ocornut/imgui][1] packaged for [Zig][2]

## Why this fork ?

The intention under this fork is to package [ocornut/imgui][1] for [Zig][2]. So:
* Unnecessary files have been deleted,
* The build system has been replaced with `build.zig`,
* [dearimgui/dear_bindings][3] generates the C binding,
* A cron runs every day to check [ocornut/imgui][2] and [dearimgui/dear_bindings][3]. Then it updates this repository if a new release is available.

## How to use it

The goal of this repository is not to provide a [Zig][2] binding for [ocornut/imgui][1]. There are at least as many legit ways as possible to make a binding as there are active accounts on Github. So you are not going to find an answer for this question here. The point of this repository is to abstract the [ocornut/imgui][1] compilation process with [Zig][2] (which is not new comers friendly and not easy to maintain) to let you focus on your application. So you can use **cimgui.zig**:
- as raw (see the [examples directory](https://github.com/tiawl/cimgui.zig/blob/trunk/examples)),
- as a daily updated interface for your [Zig][2] binding of [ocornut/imgui][1] (see [here][13] for a private usage).

### cimgui.zig as a library
If you want to add `cimgui.zig` as a library to your project, you can do the following (do know that it requires a zig version `>0.13`) :

Fetch this repository :
```sh
$ zig fetch --save git+https://github.com/tiawl/cimgui.zig
```

Add it to your `build.zig` :
```diff
const std = @import("std");
+const cimgui = @import("cimgui.zig");

pub fn build(b: *std.Build) void {
    // -- snip --

+    const cimgui_dep = b.dependency("cimgui.zig", .{
+        .target = target,
+        .optimize = optimize,
+        .platform = cimgui.Platform.GLFW,
+        .renderer = cimgui.Renderer.Vulkan,
+    });

    // Where `exe` represents your executable/library to link to
+    exe.linkLibrary(cimgui_dep.artifact("cimgui"));

    // -- snip --
}
```

And that's it ! You're ready to go ! See the `examples` directory on how to move forward from there.

## Backends
The backends are separated in two categories : the platforms (handling windows, events, ...) and the renderers (draw to screen, ..).

### Platform
  - [GLFW][4]
  - [SDL3][14]

### Renderers
  - [Vulkan][5]
  - [OpenGL][15]


> As you can see, these backends do not support all of those supported by ImGUI. Adding a backend is a bit of work because of the needed *maintenance*. Please do not ask for backends to be added if you don't feel like adding them yourselves !

## Dependencies

The [Zig][2] part of this package is relying on the latest [Zig][2] release (0.13.0) and will only be updated for the next one (so for the 0.14.0).

Here the repositories' version used by this fork:
* [ocornut/imgui](https://github.com/tiawl/cimgui.zig/blob/trunk/.references/imgui)

Currently there are no tags/release for [dearimgui/dear_bindings][3] so **cimgui.zig** is relying on the last commit.

For backends see [the build.zig.zon](https://github.com/tiawl/cimgui.zig/blob/trunk/build.zig.zon)

## CICD reminder

These repositories are automatically updated when a new release is available:
* [tiawl/spaceporn][6]

This repository is automatically updated when a new release is available from these repositories:
* [ocornut/imgui][1]
* [dearimgui/dear_bindings][3]
* [tiawl/toolbox][7]
* [tiawl/glfw.zig][8]
* [tiawl/spaceporn-action-bot][9]
* [tiawl/spaceporn-action-ci][10]
* [tiawl/spaceporn-action-cd-ping][11]
* [tiawl/spaceporn-action-cd-pong][12]

## `zig build` options

These additional options have been implemented for maintainability tasks:
```
  -Dfetch=[bool]               Update .references folder and build.zig.zon then stop execution
  -Dupdate=[bool]              Update binding
  -Drenderer=[enum]            Specify the renderer backend
                                 Supported Values:
                                   Vulkan
                                   OpenGL3
  -Dplatform=[enum]            Specify the platform backend
                                 Supported Values:
                                   GLFW
                                   SDL3
```

## License

This repository is not subject to a unique License:

The parts of this repository originated from this repository are dedicated to the public domain. See the LICENSE file for more details.

**For other parts, it is subject to the License restrictions their respective owners choosed. By design, the public domain code is incompatible with the License notion. In this case, the License prevails. So if you have any doubt about a file property, open an issue.**

[1]:https://github.com/ocornut/imgui
[2]:https://github.com/ziglang/zig
[3]:https://github.com/dearimgui/dear_bindings
[4]:https://github.com/glfw/glfw
[5]:https://github.com/KhronosGroup/Vulkan-Headers
[6]:https://github.com/tiawl/spaceporn
[7]:https://github.com/tiawl/toolbox
[8]:https://github.com/tiawl/glfw.zig
[9]:https://github.com/tiawl/spaceporn-action-bot
[10]:https://github.com/tiawl/spaceporn-action-ci
[11]:https://github.com/tiawl/spaceporn-action-cd-ping
[12]:https://github.com/tiawl/spaceporn-action-cd-pong
[13]:https://github.com/tiawl/spaceporn/blob/trunk/src/spaceporn/bindings/imgui/imgui.zig
[14]:https://wiki.libsdl.org/SDL3/FrontPage
[15]:https://www.opengl.org/
