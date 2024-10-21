// THIS FILE HAS BEEN AUTO-GENERATED BY THE 'DEAR BINDINGS' GENERATOR.
// **DO NOT EDIT DIRECTLY**
// https://github.com/dearimgui/dear_bindings

// dear imgui: Renderer for WebGPU
// This needs to be used along with a Platform Binding (e.g. GLFW)
// (Please note that WebGPU is currently experimental, will not run on non-beta browsers, and may break.)

// Important note to dawn and/or wgpu users: when targeting native platforms (i.e. NOT emscripten),
// one of IMGUI_IMPL_WEBGPU_BACKEND_DAWN or IMGUI_IMPL_WEBGPU_BACKEND_WGPU must be provided.
// Add #define to your imconfig.h file, or as a compilation flag in your build system.
// This requirement will be removed once WebGPU stabilizes and backends converge on a unified interface.
//#define IMGUI_IMPL_WEBGPU_BACKEND_DAWN
//#define IMGUI_IMPL_WEBGPU_BACKEND_WGPU

// Implemented features:
//  [X] Renderer: User texture binding. Use 'WGPUTextureView' as ImTextureID. Read the FAQ about ImTextureID!
//  [X] Renderer: Large meshes support (64k+ vertices) with 16-bit indices.
//  [X] Renderer: Expose selected render state for draw callbacks to use. Access in '(ImGui_ImplXXXX_RenderState*)GetPlatformIO().Renderer_RenderState'.

// You can use unmodified imgui_impl_* files in your project. See examples/ folder for examples of using this.
// Prefer including the entire imgui/ repository into your project (either as a copy or as a submodule), and only build the backends you need.
// Learn about Dear ImGui:
// - FAQ                  https://dearimgui.com/faq
// - Getting Started      https://dearimgui.com/getting-started
// - Documentation        https://dearimgui.com/docs (same as your local docs/ folder).
// - Introduction, links and more at the top of imgui.cpp

// Auto-generated forward declarations for C header
typedef struct ImGui_ImplWGPU_InitInfo_t ImGui_ImplWGPU_InitInfo;
typedef struct ImGui_ImplWGPU_RenderState_t ImGui_ImplWGPU_RenderState;
#pragma once

#ifdef __cplusplus
extern "C"
{
#endif
#include "cimgui.h"
#ifndef IMGUI_DISABLE
#include <webgpu/webgpu.h>                                                               // Initialization data, for ImGui_ImplWGPU_Init()
typedef struct ImGui_ImplWGPU_InitInfo_ImDrawData_t ImGui_ImplWGPU_InitInfo_ImDrawData;
typedef struct ImGui_ImplWGPU_InitInfo_t
{
    WGPUDevice           Device;
    int                  NumFramesInFlight /* = 3 */;
    WGPUTextureFormat    RenderTargetFormat /* = WGPUTextureFormat_Undefined */;
    WGPUTextureFormat    DepthStencilFormat /* = WGPUTextureFormat_Undefined */;
    WGPUMultisampleState PipelineMultisampleState /* = {} */;
} ImGui_ImplWGPU_InitInfo;

// Follow "Getting Started" link and check examples/ folder to learn about using backends!
CIMGUI_IMPL_API bool cImGui_ImplWGPU_Init(ImGui_ImplWGPU_InitInfo* init_info);
CIMGUI_IMPL_API void cImGui_ImplWGPU_Shutdown(void);
CIMGUI_IMPL_API void cImGui_ImplWGPU_NewFrame(void);
CIMGUI_IMPL_API void cImGui_ImplWGPU_RenderDrawData(ImDrawData* draw_data, WGPURenderPassEncoder pass_encoder);

// Use if you want to reset your rendering device without losing Dear ImGui state.
CIMGUI_IMPL_API void cImGui_ImplWGPU_InvalidateDeviceObjects(void);
CIMGUI_IMPL_API bool cImGui_ImplWGPU_CreateDeviceObjects(void);

// [BETA] Selected render state data shared with callbacks.
// This is temporarily stored in GetPlatformIO().Renderer_RenderState during the ImGui_ImplWGPU_RenderDrawData() call.
// (Please open an issue if you feel you need access to more data)
typedef struct ImGui_ImplWGPU_RenderState_t
{
    WGPUDevice            Device;
    WGPURenderPassEncoder RenderPassEncoder;
} ImGui_ImplWGPU_RenderState;
#endif// #ifndef IMGUI_DISABLE
#ifdef __cplusplus
} // End of extern "C" block
#endif
