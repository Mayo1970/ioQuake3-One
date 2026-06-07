#pragma once

#ifdef LIBUWP_IMPL
#  define LIBAPI extern "C" __declspec(dllexport)
#else
#  define LIBAPI extern "C" __declspec(dllimport)
#endif

LIBAPI void uwp_GetScreenSize(int* x, int* y);
LIBAPI void uwp_GetBundlePath(char* buffer);
LIBAPI void uwp_GetBundleFilePath(char* buffer, const char* filename);
LIBAPI float uwp_GetRefreshRate();
LIBAPI void uwp_GetPlayerName(char* buffer, int bufLen);
