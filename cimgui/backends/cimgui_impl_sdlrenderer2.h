// THIS FILE HAS BEEN AUTO-GENERATED BY THE 'DEAR BINDINGS' GENERATOR.
// **DO NOT EDIT DIRECTLY**
// https://github.com/dearimgui/dear_bindings

// dear imgui: Renderer Backend for SDL_Renderer for SDL2
// (Requires: SDL 2.0.17+)

// Note how SDL_Renderer is an _optional_ component of SDL2.
// For a multi-platform app consider using e.g. SDL+DirectX on Windows and SDL+OpenGL on Linux/OSX.
// If your application will want to render any non trivial amount of graphics other than UI,
// please be aware that SDL_Renderer currently offers a limited graphic API to the end-user and
// it might be difficult to step out of those boundaries.

// Implemented features:
//  [X] Renderer: User texture binding. Use 'SDL_Texture*' as ImTextureID. Read the FAQ about ImTextureID!
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
#ifndef IMGUI_DISABLE
#include "cimgui.h"
typedef struct SDL_Renderer SDL_Renderer;

typedef struct ImDrawData_t ImDrawData;
// Follow "Getting Started" link and check examples/ folder to learn about using backends!
CIMGUI_IMPL_API bool cImGui_ImplSDLRenderer2_Init(SDL_Renderer* renderer);
CIMGUI_IMPL_API void cImGui_ImplSDLRenderer2_Shutdown(void);
CIMGUI_IMPL_API void cImGui_ImplSDLRenderer2_NewFrame(void);
CIMGUI_IMPL_API void cImGui_ImplSDLRenderer2_RenderDrawData(ImDrawData* draw_data, SDL_Renderer* renderer);

// Called by Init/NewFrame/Shutdown
CIMGUI_IMPL_API bool cImGui_ImplSDLRenderer2_CreateFontsTexture(void);
CIMGUI_IMPL_API void cImGui_ImplSDLRenderer2_DestroyFontsTexture(void);
CIMGUI_IMPL_API bool cImGui_ImplSDLRenderer2_CreateDeviceObjects(void);
CIMGUI_IMPL_API void cImGui_ImplSDLRenderer2_DestroyDeviceObjects(void);
#endif// #ifndef IMGUI_DISABLE
#ifdef __cplusplus
} // End of extern "C" block
#endif
