// dear imgui: Renderer Backend for Metal - C bindings
// This is a C wrapper for imgui_impl_metal.h

#pragma once
#include "../dcimgui.h"

#ifndef IMGUI_DISABLE
#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle types for Metal objects (compatible with both ObjC and C++)
typedef void* ImGuiMTLDevice;
typedef void* ImGuiMTLCommandBuffer;
typedef void* ImGuiMTLRenderCommandEncoder;
typedef void* ImGuiMTLRenderPassDescriptor;

// Follow "Getting Started" link and check examples/ folder to learn about using backends!
CIMGUI_API bool cImGui_ImplMetal_Init(ImGuiMTLDevice device);
CIMGUI_API void cImGui_ImplMetal_Shutdown(void);
CIMGUI_API void cImGui_ImplMetal_NewFrame(ImGuiMTLRenderPassDescriptor renderPassDescriptor);
CIMGUI_API void cImGui_ImplMetal_RenderDrawData(ImDrawData* draw_data,
                                                 ImGuiMTLCommandBuffer commandBuffer,
                                                 ImGuiMTLRenderCommandEncoder commandEncoder);

// Called by Init/NewFrame/Shutdown
CIMGUI_API bool cImGui_ImplMetal_CreateDeviceObjects(ImGuiMTLDevice device);
CIMGUI_API void cImGui_ImplMetal_DestroyDeviceObjects(void);

#ifdef __cplusplus
}
#endif
#endif // #ifndef IMGUI_DISABLE
