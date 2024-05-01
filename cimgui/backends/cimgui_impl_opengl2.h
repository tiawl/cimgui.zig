// THIS FILE HAS BEEN AUTO-GENERATED BY THE 'DEAR BINDINGS' GENERATOR.
// **DO NOT EDIT DIRECTLY**
// https://github.com/dearimgui/dear_bindings

typedef struct ImDrawData_t ImDrawData;
// dear imgui: Renderer Backend for OpenGL2 (legacy OpenGL, fixed pipeline)
// This needs to be used along with a Platform Backend (e.g. GLFW, SDL, Win32, custom..)

// Implemented features:
//  [X] Renderer: User texture binding. Use 'GLuint' OpenGL texture identifier as void*/ImTextureID. Read the FAQ about ImTextureID!

// You can use unmodified imgui_impl_* files in your project. See examples/ folder for examples of using this.
// Prefer including the entire imgui/ repository into your project (either as a copy or as a submodule), and only build the backends you need.
// Learn about Dear ImGui:
// - FAQ                  https://dearimgui.com/faq
// - Getting Started      https://dearimgui.com/getting-started
// - Documentation        https://dearimgui.com/docs (same as your local docs/ folder).
// - Introduction, links and more at the top of imgui.cpp

// **DO NOT USE THIS CODE IF YOUR CODE/ENGINE IS USING MODERN OPENGL (SHADERS, VBO, VAO, etc.)**
// **Prefer using the code in imgui_impl_opengl3.cpp**
// This code is mostly provided as a reference to learn how ImGui integration works, because it is shorter to read.
// If your code is using GL3+ context or any semi modern OpenGL calls, using this is likely to make everything more
// complicated, will require your code to reset every single OpenGL attributes to their initial state, and might
// confuse your GPU driver.
// The GL2 code is unable to reset attributes or even call e.g. "glUseProgram(0)" because they don't exist in that API.

#pragma once

#ifdef __cplusplus
extern "C"
{
#endif
#include "cimgui.h"
#ifndef IMGUI_DISABLE
CIMGUI_IMPL_API bool cImGui_ImplOpenGL2_Init(void);
CIMGUI_IMPL_API void cImGui_ImplOpenGL2_Shutdown(void);
CIMGUI_IMPL_API void cImGui_ImplOpenGL2_NewFrame(void);
CIMGUI_IMPL_API void cImGui_ImplOpenGL2_RenderDrawData(ImDrawData* draw_data);

// Called by Init/NewFrame/Shutdown
CIMGUI_IMPL_API bool cImGui_ImplOpenGL2_CreateFontsTexture(void);
CIMGUI_IMPL_API void cImGui_ImplOpenGL2_DestroyFontsTexture(void);
CIMGUI_IMPL_API bool cImGui_ImplOpenGL2_CreateDeviceObjects(void);
CIMGUI_IMPL_API void cImGui_ImplOpenGL2_DestroyDeviceObjects(void);
#endif// #ifndef IMGUI_DISABLE
#ifdef __cplusplus
} // End of extern "C" block
#endif
