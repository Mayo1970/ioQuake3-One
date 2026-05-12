# ioquake3-One

A port of [ioQuake3](https://github.com/ioquake/ioq3) to the **Xbox One** via
UWP Dev Mode, using [ANGLE](https://chromium.googlesource.com/angle/angle)
(Direct3D 11) for rendering and [aerisarn's SDL-uwp-gl](https://github.com/aerisarn/SDL-uwp-gl)
for the WinRT platform layer.

## Status

- Boots, loads maps, enters gameplay with bots
- Networking works (LAN discovery, internet server browser, master server)
- Xbox controller with dual-stick analog input
- On-screen keyboard for in-game chat
- 60 fps at 1920x1080
- ANGLE GLSL ES 1.00 shader path (Xbox One GPU is vs_4_1 / ps_4_1)

## Upstream projects

| Component | Source | Used as |
|---|---|---|
| Engine | [ioquake/ioq3](https://github.com/ioquake/ioq3) | Cloned, patched via `patches/ioq3-uwp.patch` |
| WinRT SDL2 | [aerisarn/SDL-uwp-gl](https://github.com/aerisarn/SDL-uwp-gl) | Cloned, patched via `patches/sdl-uwp-gl.patch` (ES2/EGL config) |
| GLES → D3D11 | [ANGLE](https://chromium.googlesource.com/angle/angle) | Prebuilt x64 UWP binaries from [RetroArch](https://github.com/libretro/RetroArch) (`pkg/msvc-uwp/RetroArch-msvcUWP/ANGLE/x64/`) |
| Series S/X reference | [worleydl/ioq3-uwp](https://github.com/worleydl/ioq3-uwp) | Read-only — UWP shell shape, Package.appxmanifest layout |

## Prerequisites (Windows)

### 1. Visual Studio 2022

Install [Visual Studio 2022 Community](https://visualstudio.microsoft.com/vs/community/)
with these workloads:

- **Universal Windows Platform development**
- **Desktop development with C++** (for the MinGW headers SDL2 needs)
- **Windows 10 SDK 10.0.19041.0**

### 2. MSYS2 + MinGW-w64 + lld

Install [MSYS2](https://www.msys2.org/) and the toolchain packages:

```bash
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake \
          mingw-w64-x86_64-make mingw-w64-x86_64-lld
```

> **Note:** lld is required. MinGW's default GNU ld produces a corrupt PE
> export table on the libioquake3 DLL — every export RVA collapses to the
> same value, so calls from MSVC code dispatch to garbage memory.

### 3. Xbox One in Dev Mode

Activate Dev Mode on your Xbox One via the [Microsoft partner portal](https://partner.microsoft.com/en-us/dashboard/registration).
Note the IP address shown in the Dev Home app — you'll need it for Device
Portal access (`http://<xbox-ip>:11443`).

### 4. Self-signed package certificate

A `uwp_TemporaryKey.pfx` is included in `uwp/`. It self-signs the package
with `CN=q3a-uwp` (password: `q3adev`). Replace it with your own if you
prefer.

### 5. Upstream source trees

Clone the two third-party repos as siblings of this repo:

```
<parent>\
├── ioQ3-One\        ← this repo
├── ioq3\            ← git clone https://github.com/ioquake/ioq3
└── SDL-uwp-gl\      ← git clone https://github.com/aerisarn/SDL-uwp-gl
```

Then drop ANGLE's prebuilt x64 UWP binaries (`libEGL.dll`, `libGLESv2.dll`,
headers) somewhere reachable — the path RetroArch ships them at works:
`dev stuff\RetroArch\pkg\msvc-uwp\RetroArch-msvcUWP\ANGLE\x64\` and
`dev stuff\RetroArch\gfx\include\ANGLE\`. The `uwp.vcxproj` macros
`ANGLE_INC_DIR` and `ANGLE_BIN_DIR` point at those.

### 6. Retail Quake III Arena data

Supply your own from a legal install (Steam:
`steamapps/common/Quake 3 Arena/baseq3/`).

---

## Building

### Step 1 -- Patch ioQ3 + SDL-uwp-gl (run once)

```bash
cd ioQ3-One/patches
bash apply_patches.sh
```

This applies `ioq3-uwp.patch` to the ioq3 tree (CMake `BUILD_UWP_LIB` target,
ANGLE/EGL renderer paths, hardcoded LocalState home path, Xbox controller
binds, CD-key auto-skip, etc.) and `sdl-uwp-gl.patch` to the SDL-uwp-gl tree
(SDL_config_winrt.h flipped to ES2/EGL, WGL bits stubbed out). Idempotent —
safe to re-run.

### Step 2 -- Build libioquake3 + renderers (MSYS2)

```bash
/c/msys64/usr/bin/bash.exe -lc "cd /e/path/to/ioq3/build/release-mingw64-x86_64 && \
  cmake --build . --target libioquake3 renderer_opengl1 renderer_opengl2 -- -j4"
```

### Step 3 -- Regenerate the MSVC import lib (PowerShell)

```powershell
$lib    = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\lib.exe"
$outDir = "E:\path\to\ioq3\build\release-mingw64-x86_64\Release"
"LIBRARY libioquake3","EXPORTS","    SDL_main" | Out-File "$outDir\libioquake3.def" -Encoding ascii
& $lib /DEF:"$outDir\libioquake3.def" /OUT:"$outDir\libioquake3_msvc.lib" /MACHINE:X64
```

### Step 4 -- Build libuwp + the bundle (PowerShell)

```powershell
$msbuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
$alt = "E:\path\to\ioQ3-One\uwp\AppPackages2"

& $msbuild "E:\path\to\ioQ3-One\libuwp\libuwp.vcxproj" /t:Rebuild `
  /p:Configuration=Release /p:Platform=x64 `
  /p:WindowsTargetPlatformVersion=10.0.19041.0 /m /v:m

& $msbuild "E:\path\to\ioQ3-One\uwp\uwp.vcxproj" /t:Rebuild `
  /p:Configuration=Release /p:Platform=x64 `
  /p:WindowsTargetPlatformVersion=10.0.19041.0 /p:AppxBundle=Always `
  /p:AppxBundlePlatforms=x64 /p:PackageCertificatePassword=q3adev `
  /p:AppxPackageSigningEnabled=True /p:AppxPackageDir=$alt /m /v:m
```

**Output:** `uwp\AppPackages2\uwp_1.0.0.0_Test\uwp_1.0.0.0_x64.msixbundle`

> **Note:** The `AppPackages2` override is used because the default
> `AppPackages` directory often gets locked by Explorer/Device Portal.

### Optional -- Verbose diagnostics build

```bash
cmake -DIOQ3_UWP_DEBUG_LOGS=ON .   # boot breadcrumbs + qconsole.log + per-shader progress
cmake -DIOQ3_UWP_DEBUG_LOGS=OFF .  # release default (only ioq3_error.log on crash)
```

---

## Installing on Xbox One

1. Build the `.msixbundle` (Step 4 above).
2. Open Device Portal at `http://<xbox-ip>:11443` in a browser.
3. Install **VCLibs** once: `uwp\AppPackages2\uwp_1.0.0.0_Test\Dependencies\x64\Microsoft.VCLibs.x64.14.00.appx`
4. Install the bundle.
5. Launch ioQuake3-One once briefly (this creates `LocalState\baseq3\`).
6. Close it.
7. FTP the `pak0.pk3 .. pak8.pk3` files to:
   ```
   LocalAppData\ioq3-uwp_1.0.0.0_x64__t8sjjnx0kvmt8\LocalState\baseq3\
   ```
   via Device Portal → File Explorer → User Folders.
8. Launch the game.

**You need the original Quake III Arena data files** (`pak0.pk3` through
`pak8.pk3`). On Steam these are at
`steamapps/common/Quake 3 Arena/baseq3/`.

---

## Controls

Xbox controller, dual-stick FPS layout. Buttons are rebindable from the
in-game options menu.

#### In-game

| Input | Action |
|---|---|
| Left stick | Move (forward/back + strafe) |
| Right stick | Look (yaw + pitch) |
| **RT** | Fire |
| **LT** | Zoom |
| **A** | Jump |
| **B** | Crouch |
| **X** | Use |
| **Y** | Next weapon |
| **LB** | Previous weapon |
| **RB** | Next weapon |
| **LS click** | Walk / run toggle |
| **View** (Back) | Scoreboard (hold) |
| **Menu** (Start) | Toggle menu (Escape) |
| **D-pad down** | Open chat |

#### Menus

| Input | Action |
|---|---|
| Left stick | Move cursor |
| D-pad | Arrow keys |
| **A** | Confirm (Enter) |
| **B** | Back (Escape) |
| **Menu** | Toggle menu |

#### Chat

| Input | Action |
|---|---|
| **D-pad down** (in-game) | Open Xbox on-screen keyboard |
| Type + OSK Enter | Send as `say` chat |
| **B** | Cancel |

---

## Xbox LocalState directory

```
U:\Users\UserMgr0\AppData\Local\Packages\ioq3-uwp_t8sjjnx0kvmt8\LocalState\
├── baseq3\
│   ├── pak0.pk3 .. pak8.pk3        ← FTP your retail data here
│   └── q3config.cfg                ← user settings (auto-saved)
└── ioq3_error.log                  ← only on a fatal error
```

In a `IOQ3_UWP_DEBUG_LOGS=ON` build the directory also gets:
- `qconsole.log` — full engine log, flushed every line
- `boot_*.log` — per-stage init breadcrumbs

---

## Technical notes

- **Renderer:** renderergl2 only. ANGLE provides GLES 2.0/3.0 over Direct3D 11.
  The Xbox One GPU exposes vs_4_1 / ps_4_1 (D3D feature level 10.0).
- **Shaders:** ANGLE advertises GLSL ES 3.00 but its frontend stalls
  translating Q3's ES3 syntax. All shaders are forced through the
  `#version 100` / GLSL ES 1.00 path. ~81 shader variants compile in ~12s
  on first boot.
- **Bone animation:** disabled — ANGLE's vs_4_1 translator hangs on the
  largest bone permutations. Vanilla Q3 ships no `.iqm` content, so this
  is not user-visible.
- **Shadow maps:** the cascaded sun-shadow path is skipped; `shadowmask_fp`
  hardcodes `sampler2DShadow` which ANGLE rejects under GLSL ES 1.00.
- **Audio:** SDL/WASAPI playback. VoIP capture is disabled (would block
  on a microphone privacy prompt that never arrives).
- **Networking:** SDL_net via `ws2_32`. LAN, internet browser, and direct
  IP connect all work.
- **UWP shell timeout:** the runtime kills any app that doesn't pump the
  CoreWindow message queue for ~20s. We pump events between shader
  permutations to stay under the threshold.
- **Logs:** `ioq3_error.log` is always written on a `Com_Error`. All other
  diagnostic output is gated behind the `IOQ3_UWP_DEBUG_LOGS` CMake option.

---

## Memory budget

| Region | Size | Notes |
|---|---|---|
| Hunk (`com_hunkMegs`) | 256 MB | Maps, shaders, models |
| Zone (`com_zoneMegs`) | 24 MB | Dynamic allocs, zlib inflate |
| Sound (`com_soundMegs`) | 8 MB | Audio buffers |

Xbox One Dev Mode allocates ~1 GB to UWP apps, so headroom is generous.

---

## Credits

- [id Software](https://github.com/id-Software/Quake-III-Arena) — original Quake III Arena engine
- [ioquake3 team](https://ioquake3.org/) — modern engine upkeep
- [worleydl](https://github.com/worleydl/ioq3-uwp) — Xbox Series S/X UWP port that this work started from
- [aerisarn](https://github.com/aerisarn/SDL-uwp-gl) — SDL2 WinRT fork with EGL/ANGLE support
- [ANGLE](https://chromium.googlesource.com/angle/angle) — GLES → Direct3D 11 translator
- [RetroArch](https://github.com/libretro/RetroArch) — source of the prebuilt x64 UWP ANGLE binaries

## License

ioQuake3 is GPLv2. This Xbox One port layer is also GPLv2. See `LICENSE`.
Quake III Arena retail data is © id Software / ZeniMax and is **not**
included in this repository.
