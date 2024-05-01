# cimgui.zig

This is a fork of [ocornut/imgui][1] packaged for [Zig][2]

## Why this fork ?

The intention under this fork is to package [ocornut/imgui][1] for [Zig][2]. So:
* Unnecessary files have been deleted,
* The build system has been replaced with `build.zig`,
* [dearimgui/dear_bindings][3] generates the C binding,
* A cron runs every day to check [ocornut/imgui][2] and [dearimgui/dear_bindings][3]. Then it updates this repository if a new release is available.

Here the repositories' version used by this fork:
* [ocornut/imgui](https://github.com/tiawl/cimgui.zig/blob/trunk/.versions/imgui)

## Backends

Currently only [GLFW][4] and [Vulkan][5] backends are supported. There will be no other backends **if you are not are ready to maintain backends you want to use**. The team is not interested to maintain backends nobody uses. If you want to see a new backend available on this repository and you are ready for this, open an issue, we will be happy to talk with you and how we could manage this together.

## How to use it

The maintainers will update this section later

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
  -Dfetch   Update .versions folder and build.zig.zon then stop execution
  -Dupdate  Update binding
```

## License

The unprotected parts of this repository are under MIT License. For everything else, see with their respective owners.

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
