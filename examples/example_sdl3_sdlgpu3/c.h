#define SDL_DISABLE_OLD_NAMES
#include "SDL3/SDL.h"
#include "SDL3/SDL_revision.h"
// For programs that provide their own entry points instead of relying on SDL's main function
// macro magic, 'SDL_MAIN_HANDLED' should be defined before including 'SDL_main.h'.
#define SDL_MAIN_HANDLED
#include "SDL3/SDL_main.h"
#include "dcimgui.h"
#include "backends/dcimgui_impl_sdl3.h"
#include "backends/dcimgui_impl_sdlgpu3.h"
