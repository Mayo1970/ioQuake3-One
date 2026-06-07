/*
    Various helpers for UWP apps, add a new function if you need to interop between a dll and UWP calls
*/
#include "pch.h"
#define LIBUWP_IMPL
#include "libuwp.h"
#include <wrl.h>

#include <winrt/Windows.ApplicationModel.Core.h>
#include <winrt/Windows.UI.Composition.h>
#include <winrt/Windows.Graphics.Display.Core.h>
#include <winrt/Windows.System.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <string>

static int width = 0;
static int height = 0;

using namespace winrt::Windows;
using namespace winrt::Windows::ApplicationModel::Core;
using namespace winrt::Windows::Graphics::Display::Core;

void uwp_GetBundlePath(char* buffer)
{
    sprintf_s(buffer, 1024, "%s", winrt::to_string(ApplicationModel::Package::Current().InstalledPath()).c_str());
}

void uwp_GetBundleFilePath(char* buffer, const char *filename)
{
    sprintf_s(buffer, 1024, "%s\\%s", winrt::to_string(ApplicationModel::Package::Current().InstalledPath()).c_str(), filename);
}

void uwp_GetScreenSize(int* x, int* y)
{
    if (width == 0) {
        try {
            HdmiDisplayInformation hdi = HdmiDisplayInformation::GetForCurrentView();
            if (hdi) {
                auto mode = hdi.GetCurrentDisplayMode();
                if (mode) {
                    width  = mode.ResolutionWidthInRawPixels();
                    height = mode.ResolutionHeightInRawPixels();
                }
            }
        } catch (...) { }
        if (width == 0) { width = 1920; height = 1080; }
    }
    *x = width;
    *y = height;
}

float uwp_GetRefreshRate()
{
    try {
        HdmiDisplayInformation hdi = HdmiDisplayInformation::GetForCurrentView();
        if (hdi) {
            auto mode = hdi.GetCurrentDisplayMode();
            if (mode) return (float)mode.RefreshRate();
        }
    } catch (...) { }
    return 60.0f;
}

void uwp_GetPlayerName(char* buffer, int bufLen)
{
    buffer[0] = '\0';
    try {
        auto users = winrt::Windows::System::User::FindAllAsync().get();
        if (users && users.Size() > 0) {
            auto user = users.GetAt(0);
            winrt::hstring keys[2] = {
                winrt::Windows::System::KnownUserProperties::AccountName(),
                winrt::Windows::System::KnownUserProperties::DisplayName(),
            };
            for (int k = 0; k < 2; k++) {
                auto prop = user.GetPropertyAsync(keys[k]).get();
                if (!prop) continue;
                IInspectable* raw = static_cast<IInspectable*>(winrt::get_abi(prop));
                HSTRING hs = reinterpret_cast<HSTRING>(raw);
                UINT32 len = 0;
                const wchar_t* wstr = WindowsGetStringRawBuffer(hs, &len);
                if (!wstr || len == 0) continue;
                std::string utf8 = winrt::to_string(wstr);
                if (utf8.empty()) continue;
                int copyLen = (int)utf8.size() < bufLen - 1 ? (int)utf8.size() : bufLen - 1;
                memcpy(buffer, utf8.c_str(), (size_t)copyLen);
                buffer[copyLen] = '\0';
                break;
            }
        }
    } catch (...) { }
}
