// THIS FILE HAS BEEN AUTO-GENERATED BY THE 'DEAR BINDINGS' GENERATOR.
// **DO NOT EDIT DIRECTLY**
// https://github.com/dearimgui/dear_bindings

#include "imgui.h"
#include "imgui_impl_sdl2.h"

#include <stdio.h>

// Wrap this in a namespace to keep it separate from the C++ API
namespace cimgui
{
#include "cimgui_impl_sdl2.h"
}

// By-value struct conversions

// Function stubs

#ifndef IMGUI_DISABLE

CIMGUI_IMPL_API bool cimgui::cImGui_ImplSDL2_InitForOpenGL(cimgui::SDL_Window* window, void* sdl_gl_context)
{
    return ::ImGui_ImplSDL2_InitForOpenGL(reinterpret_cast<::SDL_Window*>(window), sdl_gl_context);
}

CIMGUI_IMPL_API bool cimgui::cImGui_ImplSDL2_InitForVulkan(cimgui::SDL_Window* window)
{
    return ::ImGui_ImplSDL2_InitForVulkan(reinterpret_cast<::SDL_Window*>(window));
}

CIMGUI_IMPL_API bool cimgui::cImGui_ImplSDL2_InitForD3D(cimgui::SDL_Window* window)
{
    return ::ImGui_ImplSDL2_InitForD3D(reinterpret_cast<::SDL_Window*>(window));
}

CIMGUI_IMPL_API bool cimgui::cImGui_ImplSDL2_InitForMetal(cimgui::SDL_Window* window)
{
    return ::ImGui_ImplSDL2_InitForMetal(reinterpret_cast<::SDL_Window*>(window));
}

CIMGUI_IMPL_API bool cimgui::cImGui_ImplSDL2_InitForSDLRenderer(cimgui::SDL_Window* window, cimgui::SDL_Renderer* renderer)
{
    return ::ImGui_ImplSDL2_InitForSDLRenderer(reinterpret_cast<::SDL_Window*>(window), reinterpret_cast<::SDL_Renderer*>(renderer));
}

CIMGUI_IMPL_API bool cimgui::cImGui_ImplSDL2_InitForOther(cimgui::SDL_Window* window)
{
    return ::ImGui_ImplSDL2_InitForOther(reinterpret_cast<::SDL_Window*>(window));
}

CIMGUI_IMPL_API void cimgui::cImGui_ImplSDL2_Shutdown(void)
{
    ::ImGui_ImplSDL2_Shutdown();
}

CIMGUI_IMPL_API void cimgui::cImGui_ImplSDL2_NewFrame(void)
{
    ::ImGui_ImplSDL2_NewFrame();
}

CIMGUI_IMPL_API bool cimgui::cImGui_ImplSDL2_ProcessEvent(const SDL_Event* event)
{
    return ::ImGui_ImplSDL2_ProcessEvent(event);
}

CIMGUI_IMPL_API void cimgui::cImGui_ImplSDL2_SetGamepadMode(cimgui::ImGui_ImplSDL2_GamepadMode mode)
{
    ::ImGui_ImplSDL2_SetGamepadMode(static_cast<::ImGui_ImplSDL2_GamepadMode>(mode));
}

CIMGUI_IMPL_API void cimgui::cImGui_ImplSDL2_SetGamepadModeEx(cimgui::ImGui_ImplSDL2_GamepadMode mode, struct cimgui::_SDL_GameController** manual_gamepads_array, int manual_gamepads_count)
{
    ::ImGui_ImplSDL2_SetGamepadMode(static_cast<::ImGui_ImplSDL2_GamepadMode>(mode), reinterpret_cast<struct ::_SDL_GameController**>(manual_gamepads_array), manual_gamepads_count);
}

#endif // #ifndef IMGUI_DISABLE
