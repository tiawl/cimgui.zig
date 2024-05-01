// THIS FILE HAS BEEN AUTO-GENERATED BY THE 'DEAR BINDINGS' GENERATOR.
// **DO NOT EDIT DIRECTLY**
// https://github.com/dearimgui/dear_bindings

#include "imgui.h"
#include "imgui_impl_sdlrenderer3.h"

#include <stdio.h>

// Wrap this in a namespace to keep it separate from the C++ API
namespace cimgui
{
#include "cimgui_impl_sdlrenderer3.h"
}

// By-value struct conversions

// Function stubs

#ifndef IMGUI_DISABLE

CIMGUI_IMPL_API bool cimgui::cImGui_ImplSDLRenderer3_Init(cimgui::SDL_Renderer* renderer)
{
    return ::ImGui_ImplSDLRenderer3_Init(reinterpret_cast<::SDL_Renderer*>(renderer));
}

CIMGUI_IMPL_API void cimgui::cImGui_ImplSDLRenderer3_Shutdown(void)
{
    ::ImGui_ImplSDLRenderer3_Shutdown();
}

CIMGUI_IMPL_API void cimgui::cImGui_ImplSDLRenderer3_NewFrame(void)
{
    ::ImGui_ImplSDLRenderer3_NewFrame();
}

CIMGUI_IMPL_API void cimgui::cImGui_ImplSDLRenderer3_RenderDrawData(cimgui::ImDrawData* draw_data)
{
    ::ImGui_ImplSDLRenderer3_RenderDrawData(reinterpret_cast<::ImDrawData*>(draw_data));
}

CIMGUI_IMPL_API bool cimgui::cImGui_ImplSDLRenderer3_CreateFontsTexture(void)
{
    return ::ImGui_ImplSDLRenderer3_CreateFontsTexture();
}

CIMGUI_IMPL_API void cimgui::cImGui_ImplSDLRenderer3_DestroyFontsTexture(void)
{
    ::ImGui_ImplSDLRenderer3_DestroyFontsTexture();
}

CIMGUI_IMPL_API bool cimgui::cImGui_ImplSDLRenderer3_CreateDeviceObjects(void)
{
    return ::ImGui_ImplSDLRenderer3_CreateDeviceObjects();
}

CIMGUI_IMPL_API void cimgui::cImGui_ImplSDLRenderer3_DestroyDeviceObjects(void)
{
    ::ImGui_ImplSDLRenderer3_DestroyDeviceObjects();
}

#endif // #ifndef IMGUI_DISABLE
