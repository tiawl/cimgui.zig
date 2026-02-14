// dear imgui: Renderer Backend for Metal - C bindings implementation
// This is a C wrapper for imgui_impl_metal functions

#ifdef __OBJC__

// Only include imgui.h (NOT dcimgui.h) to avoid conflicts
#define CIMGUI_DEFINE_ENUMS_AND_STRUCTS
#import "imgui.h"
#import "imgui_impl_metal.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

extern "C" {

// C wrapper functions with proper linkage
bool cImGui_ImplMetal_Init(void* device) {
    return ImGui_ImplMetal_Init((__bridge id<MTLDevice>)device);
}

void cImGui_ImplMetal_Shutdown(void) {
    ImGui_ImplMetal_Shutdown();
}

void cImGui_ImplMetal_NewFrame(void* renderPassDescriptor) {
    ImGui_ImplMetal_NewFrame((__bridge MTLRenderPassDescriptor*)renderPassDescriptor);
}

void cImGui_ImplMetal_RenderDrawData(ImDrawData* draw_data,
                                     void* commandBuffer,
                                     void* commandEncoder) {
    ImGui_ImplMetal_RenderDrawData(draw_data,
                                  (__bridge id<MTLCommandBuffer>)commandBuffer,
                                  (__bridge id<MTLRenderCommandEncoder>)commandEncoder);
}

bool cImGui_ImplMetal_CreateDeviceObjects(void* device) {
    return ImGui_ImplMetal_CreateDeviceObjects((__bridge id<MTLDevice>)device);
}

void cImGui_ImplMetal_DestroyDeviceObjects(void) {
    ImGui_ImplMetal_DestroyDeviceObjects();
}

} // extern "C"

#endif // __OBJC__
