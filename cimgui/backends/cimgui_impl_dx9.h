// THIS FILE HAS BEEN AUTO-GENERATED BY THE 'DEAR BINDINGS' GENERATOR.
// **DO NOT EDIT DIRECTLY**
// https://github.com/dearimgui/dear_bindings

// dear imgui: Renderer Backend for DirectX9
// This needs to be used along with a Platform Backend (e.g. Win32)

// Implemented features:
//  [X] Renderer: User texture binding. Use 'LPDIRECT3DTEXTURE9' as ImTextureID. Read the FAQ about ImTextureID!
//  [X] Renderer: Large meshes support (64k+ vertices) with 16-bit indices.

// You can use unmodified imgui_impl_* files in your project. See examples/ folder for examples of using this.
// Prefer including the entire imgui/ repository into your project (either as a copy or as a submodule), and only build the backends you need.
// Learn about Dear ImGui:
// - FAQ                  https://dearimgui.com/faq
// - Getting Started      https://dearimgui.com/getting-started
// - Documentation        https://dearimgui.com/docs (same as your local docs/ folder).
// - Introduction, links and more at the top of imgui.cpp

#pragma once

#ifdef __cplusplus
extern "C"
{
#endif
#include "cimgui.h"
#ifndef IMGUI_DISABLE
typedef struct IDirect3DDevice9 IDirect3DDevice9;
typedef struct ImDrawData_t ImDrawData;

CIMGUI_IMPL_API bool cImGui_ImplDX9_Init(IDirect3DDevice9* device);
CIMGUI_IMPL_API void cImGui_ImplDX9_Shutdown(void);
CIMGUI_IMPL_API void cImGui_ImplDX9_NewFrame(void);
CIMGUI_IMPL_API void cImGui_ImplDX9_RenderDrawData(ImDrawData* draw_data);

// Use if you want to reset your rendering device without losing Dear ImGui state.
CIMGUI_IMPL_API bool cImGui_ImplDX9_CreateDeviceObjects(void);
CIMGUI_IMPL_API void cImGui_ImplDX9_InvalidateDeviceObjects(void);
#endif// #ifndef IMGUI_DISABLE
#ifdef __cplusplus
} // End of extern "C" block
#endif
