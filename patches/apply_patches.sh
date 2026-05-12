#!/usr/bin/env bash
# apply_patches.sh - Applies all ioQ3-One Xbox One Dev Mode patches to clean
# checkouts of ioq3 and SDL-uwp-gl. Run from anywhere (paths are absolute).
# Idempotent: re-running reports "ALREADY APPLIED" and is a no-op.
#
# Applies:
#   ioq3-uwp.patch     -> ioq3/    (cmake, renderer, sdl_input, sys, etc.)
#   sdl-uwp-gl.patch   -> SDL-uwp-gl/ (ES2/EGL config, IOQ3_SDLBC no-op,
#                                       D3D11 pixel format helper)
#   uwp-main.cpp       -> ioQ3-One/uwp/main.cpp (SDL WinRT shell + baseq3 pre-create)

set -e

UWP_DIR="/e/Users/Matteo/Desktop/quake3/ioQ3-One/ioQ3-One"
IOQ3_DIR="/e/Users/Matteo/Desktop/quake3/ioQ3-One/ioq3"
SDL_DIR="/e/Users/Matteo/Desktop/quake3/ioQ3-One/SDL-uwp-gl"
PATCH_DIR="$UWP_DIR/patches"

apply_patch() {
    local label="$1" target_dir="$2" patch_file="$3"
    cd "$target_dir"
    if git apply --check "$patch_file" 2>/dev/null; then
        git apply "$patch_file"
        echo "  $label: OK"
    else
        echo "  $label: ALREADY APPLIED or CONFLICT (skipped)"
    fi
}

echo "=== ioq3 ==="
apply_patch "ioq3-uwp.patch" "$IOQ3_DIR" "$PATCH_DIR/ioq3-uwp.patch"

echo ""
echo "=== SDL-uwp-gl ==="
apply_patch "sdl-uwp-gl.patch" "$SDL_DIR" "$PATCH_DIR/sdl-uwp-gl.patch"

echo ""
echo "=== uwp/main.cpp ==="
cp "$PATCH_DIR/uwp-main.cpp" "$UWP_DIR/uwp/main.cpp"
echo "  uwp/main.cpp: OK"

echo ""
echo "All patches applied."
echo "Next: build steps from CLAUDE.md (SDL2 -> libioquake3 -> import lib -> libuwp -> bundle)."
