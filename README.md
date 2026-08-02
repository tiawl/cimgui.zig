> [!WARNING]
> If you are using the `docking` branch it won't be updated anymore and there won't be more `*-docking` tags. Please use the `-Ddocking` option [instead](https://github.com/tiawl/cimgui.zig/tree/stable?tab=readme-ov-file#cimguizig-as-a-library).

# cimgui.zig

This is a fork of [ocornut/imgui][1] packaged for [Zig][2]

## Why this fork ?

The intention under this fork is to package [ocornut/imgui][1] for [Zig][2]. So:
* Unnecessary files have been deleted,
* The build system has been replaced with `build.zig`,
* [dearimgui/dear_bindings][3] generates the C binding,
* A cron runs every day to check [ocornut/imgui][2], [dearimgui/dear_bindings][3] and other dependencies. Then it updates this repository if a new release is available.

## How to use it

The goal of this repository is not to provide a [Zig][2] binding for [ocornut/imgui][1]. The point of this repository is to abstract the [ocornut/imgui][1] compilation process with [Zig][2] (which is not easy to maintain) to let you focus on your application. So you can use **cimgui.zig**:
- as raw (see the `examples` directory),
- as a daily updated interface for your [Zig][2] binding of [ocornut/imgui][1]

### `examples` directory

`examples/example_*` directories follow this naming convention: `example_<platforms>_<renderers>`

Each backend in `<platforms>` and `<renderers>` is split with a `+` character if more than one backend.

Backends prefixed with a `z` character stands for popular Zig Bindings. Currently:
* `zopengl3` refers to [castholm/zigglgen][8],
* `zglfw` refers to [IridescenceTech/zglfw][9],
* `zvulkan` refers to [Snektron/vulkan-zig][10]

The whole examples code is refactored in `examples/common` directory for easier maintainance and better test coverage.

### cimgui.zig as a library

If you want to add `cimgui.zig` as a library to your project, you can do the following:

Fetch this repository:
```sh
$ zig fetch --save git+https://github.com/tiawl/cimgui.zig
```

Add a `src/c.h` file with the headers you need:
```c
#define GLFW_INCLUDE_VULKAN 1
#define GLFW_INCLUDE_NONE 1
#include "GLFW/glfw3.h"
#include "dcimgui.h"
#include "backends/dcimgui_impl_glfw.h"
#include "backends/dcimgui_impl_vulkan.h"
```

Add it to your `build.zig` :
```diff
const std = @import("std");
+const cimgui = @import("cimgui_zig");
+const Renderer = cimgui.Renderer;
+const Platform = cimgui.Platform;

pub fn build(b: *std.Build) void {
    // -- snip --

+    const cimgui_dep = b.dependency("cimgui_zig", .{
+        .target = target,
+        .optimize = optimize,
+        .platforms = &[_]Platform{.GLFW},
+        .renderers = &[_]Renderer{.Vulkan},
+        // .docking = true, // Default value: false
+        // .no_renderer = true, // Default value: false. Comment `.renderers` field if you use this one
+        // .no_platform = true, // Default value: false. Comment `.platforms` field if you use this one
+    });
+    const cimgui_lib = cimgui_dep.artifact("cimgui");
+
+    const c_mod = cimgui.createModule(b, cimgui_dep, cimgui_lib, b.path("src/c.h"));

    // Where `exe` represents your executable/library to link to
+    exe.root_module.addImport("c", c_mod);

    // -- snip --
}
```

And that's it ! You're ready to go ! See the `examples` directory on how to move forward from there.

## Backends

The backends are separated in two categories: the platforms (handling windows, events, ...) and the renderers (draw to screen, ..).

### Platforms
  - [GLFW][4]
  - [SDL3][6]

### Renderers
  - [Vulkan][5]
  - [OpenGL3][7]
  - [SDLGPU3][6]
  - Metal

> As you can see, these backends do not support all of those supported by ImGUI. Adding a backend is a bit of work because of the needed *maintenance*. Please do not ask for backends to be added if you don't feel like adding them yourselves !

## Dependencies

The [Zig][2] part of this package requires the latest (0.16.0) or the master (0.17.0-dev) [Zig][2] release.

For other dependencies see [the build.zig.zon](https://github.com/tiawl/cimgui.zig/blob/stable/build.zig.zon)

## `zig build` options

These additional options have been implemented to cover main usecases:
```
  -Drenderers=[enum_list]      Specify the renderer backends
                                 Supported Values:
                                   Metal
                                   OpenGL3
                                   SDLGPU3
                                   Vulkan
  -Dplatforms=[enum_list]      Specify the platform backends
                                 Supported Values:
                                   GLFW
                                   SDL3
  -Ddocking=[bool]             master or docking ocornut/imgui branch ?
  -Dno_renderer=[bool]         Specify there no need for renderer backend. It returns an error if you use it with `renderers` option.
  -Dno_platform=[bool]         Specify there no need for platform backend. It returns an error if you use it with `platforms` option.
  -Dlibc=[bool]                link libC ?
```

These additional options have mainly been implemented for maintainability tasks but they maybe could be useful for edge usecases:
```
  -Dlist-renderers=[bool]      Print available renderer backends. This options prevail on list-platforms option
  -Dlist-platforms=[bool]      Print available platform backends
  -Dseparator=[string]         Used separator instead of default newline character
  -Dfetch=[bool]               Update build.zig.zon then stop execution
  -Dupdate=[bool]              Update binding
  -Dverbose=[bool]             Enabled toolbox debug logging
```

## License

This repository is not subject to a unique License:

The parts of this repository originated from this repository are dedicated to the public domain. See the LICENSE file for more details.

**For other parts, it is subject to the License restrictions their respective owners choosed. By design, the public domain code is incompatible with the License notion. In this case, the License prevails. So if you have any doubt about a file property, open an issue.**

[1]:https://github.com/ocornut/imgui
[2]:https://codeberg.org/ziglang/zig
[3]:https://github.com/dearimgui/dear_bindings
[4]:https://github.com/glfw/glfw
[5]:https://github.com/KhronosGroup/Vulkan-Headers
[6]:https://wiki.libsdl.org/SDL3/FrontPage
[7]:https://www.opengl.org/
[8]:https://github.com/castholm/zigglgen
[9]:https://github.com/IridescenceTech/zglfw
[10]:https://github.com/Snektron/vulkan-zig
