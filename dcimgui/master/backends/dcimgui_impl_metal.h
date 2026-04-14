// dear imgui: Renderer Backend for Metal - C bindings
// This is a C wrapper for imgui_impl_metal.h

#pragma once

#ifdef __cplusplus
extern "C" {
#endif
#ifndef IMGUI_DISABLE
#include "dcimgui.h"

// Opaque handle types for Metal objects (compatible with both ObjC and C++)
typedef void* ImGuiMTLDevice;
typedef void* ImGuiMTLCommandBuffer;
typedef void* ImGuiMTLRenderCommandEncoder;
typedef void* ImGuiMTLRenderPassDescriptor;

// Follow "Getting Started" link and check examples/ folder to learn about using backends!
CIMGUI_IMPL_API bool cImGui_ImplMetal_Init(ImGuiMTLDevice device);
CIMGUI_IMPL_API void cImGui_ImplMetal_Shutdown(void);
CIMGUI_IMPL_API void cImGui_ImplMetal_NewFrame(ImGuiMTLRenderPassDescriptor renderPassDescriptor);
CIMGUI_IMPL_API void cImGui_ImplMetal_RenderDrawData(ImDrawData* draw_data,
                                                 ImGuiMTLCommandBuffer commandBuffer,
                                                 ImGuiMTLRenderCommandEncoder commandEncoder);

// Called by Init/NewFrame/Shutdown
CIMGUI_IMPL_API bool cImGui_ImplMetal_CreateDeviceObjects(ImGuiMTLDevice device);
CIMGUI_IMPL_API void cImGui_ImplMetal_DestroyDeviceObjects(void);

#endif // #ifndef IMGUI_DISABLE
#ifdef __cplusplus
}
#endif
