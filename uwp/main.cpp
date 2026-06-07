/*
    SDL_winrt_main_NonXAML.cpp, placed in the public domain by David Ludwig  3/13/14
*/

#include "SDL_main.h"
#include <wrl.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.h>

using namespace winrt;

#ifdef _MSC_VER
#pragma warning(disable : 4447)
#pragma comment(lib, "runtimeobject.lib")
#endif

// Pre-create LocalState\baseq3 so paks can be uploaded before first launch.
static void EnsureBaseq3Folder()
{
    try {
        auto local = winrt::Windows::Storage::ApplicationData::Current().LocalFolder();
        local.CreateFolderAsync(L"baseq3",
            winrt::Windows::Storage::CreationCollisionOption::OpenIfExists).get();
    } catch (...) {}
}

int CALLBACK WinMain(HINSTANCE, HINSTANCE, LPSTR, int)
{
    EnsureBaseq3Folder();

    // Write default player name on first boot (no q3config.cfg yet).
    try {
        auto local = winrt::Windows::Storage::ApplicationData::Current().LocalFolder();
        auto localStr = winrt::to_string(local.Path());
        FILE* q3cfg = nullptr; fopen_s(&q3cfg, (localStr + "\\baseq3\\q3config.cfg").c_str(), "r");
        if (!q3cfg) {
            FILE* f = nullptr; fopen_s(&f, (localStr + "\\baseq3\\uwp_defaults.cfg").c_str(), "w");
            if (f) { fprintf(f, "set name \"Q3Xbox\"\n"); fclose(f); }
        } else {
            fclose(q3cfg);
        }
    } catch (...) {}

    return SDL_WinRTRunApp(SDL_main, NULL);
}
