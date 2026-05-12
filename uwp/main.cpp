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
    return SDL_WinRTRunApp(SDL_main, NULL);
}
