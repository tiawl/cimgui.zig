# cimgui.zig

This is a fork of [ocornut/imgui](https://github.com/ocornut/imgui) packaged for @ziglang

## Why this fork ?

The intention under this fork is to package [ocornut/imgui](https://github.com/ocornut/imgui) for @ziglang. So:
* Unnecessary files have been deleted,
* The build system has been replaced with `build.zig`,
* [dearimgui/dear_bindings](https://github.com/dearimgui/dear_bindings) generates the C binding,
* A cron runs every day to check [ocornut/imgui](https://github.com/ocornut/imgui) and [dearimgui/dear_bindings](https://github.com/dearimgui/dear_bindings). Then it updates this repository if a new release is available on one of them.

Here the repositories' version used by this fork:
* [ocornut/imgui](https://github.com/tiawl/cimgui.zig/blob/trunk/.versions/imgui)

## Backends

Currently only @glfw and Vulkan backends are supported. There will be no other backends **if you are not are ready to maintain backends you want to use**. The team is not interested to maintain backends nobody uses. If you want to see a new backend available on this repository and you are ready for this, open an issue, we will be happy to talk with you and how we could manage this together.

## How to use it

The maintainers will update this section later

## CICD reminder

These repositories are automatically updated when a new release is available:
* [tiawl/spaceporn](https://github.com/tiawl/spaceporn)

This repository is automatically updated when a new release is available from these repositories:
* [ocornut/imgui](https://github.com/ocornut/imgui)
* [dearimgui/dear_bindings](https://github.com/dearimgui/dear_bindings)
* [tiawl/toolbox](https://github.com/tiawl/toolbox)
* [tiawl/glfw.zig](https://github.com/tiawl/glfw.zig)
* [tiawl/spaceporn-dep-action-bot](https://github.com/tiawl/spaceporn-dep-action-bot)
* [tiawl/spaceporn-dep-action-ci](https://github.com/tiawl/spaceporn-dep-action-ci)
* [tiawl/spaceporn-dep-action-cd-ping](https://github.com/tiawl/spaceporn-dep-action-cd-ping)
* [tiawl/spaceporn-dep-action-cd-pong](https://github.com/tiawl/spaceporn-dep-action-cd-pong)

## `zig build` options

These additional options have been implemented for maintainability tasks:
```
  -Dfetch   Update .versions folder and build.zig.zon then stop execution
  -Dupdate  Update binding
```

## License

The unprotected parts of this repository are under MIT License. For everything else, see with their respective owners.
