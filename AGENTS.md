# AGENTS.md

> **Note for humans:** this file is written primarily for AI coding agents
> (Claude Code, Copilot, Cursor, etc.) picking this project up cold. It exists
> so the work can be continued if the original author no longer can. The fixes
> here were expensive to find — re-breaking them is the most common failure
> mode, so read the **Hard rules / dead ends** section before changing code.

## Project overview

ioquake3 (Quake III Arena) ported to a retail **Xbox One in UWP Dev Mode**.
The Xbox One has no OpenGL, so the render path is:

```
Quake3 GL  →  SDL2 (WinRT fork)  →  EGL/GLES  →  ANGLE  →  Direct3D 11  →  Xbox One GPU
(renderergl2)  (aerisarn fork)      (libEGL)     (libGLESv2)  (d3d11)
```

Two facts explain ~90% of this project's surprises:
1. The engine is built with **MinGW/GCC (lld linker)** as a DLL, but the UWP
   shell hosting it is built with **MSVC**. Two C runtimes meet at a
   hand-written DLL boundary (see `libuwp`).
2. **ANGLE's shader translator on this GPU is incomplete** — it stalls/rejects
   real GLES3 syntax, so everything is forced down a GLES 1.00 path.

Every Xbox-specific change in the engine is fenced behind `#ifdef IOQ3_UWP`.
**To see the entire customization surface, run `grep -rln "IOQ3_UWP" code/`.**
The code is the source of truth; this file is the map and the "why".

## Project layout

This repo is `ioQ3-One\`. It expects sibling directories under a common parent
(`<parent>\` below):

```
<parent>\
├── ioQ3-One\          ← THIS REPO. Engine source + UWP shell + build output.
│   ├── code\          ← ioquake3 C source (edited in place, NO patch files)
│   ├── cmake\         ← build system (MinGW Makefiles generator)
│   ├── CMakeLists.txt
│   ├── libuwp\        ← MSVC C++/WinRT DLL: the MSVC↔MinGW bridge
│   ├── uwp\           ← MSVC UWP app shell (.vcxproj, manifest, entry point)
│   ├── build\         ← CMake build dir; output in build\Release\
│   └── data\          ← (NOT retail paks — those live on the Xbox)
├── SDL-uwp-gl\        ← aerisarn SDL2 WinRT fork. EDITED IN PLACE for ES2/EGL.
├── ioq3-uwp\          ← Xbox SERIES S/X port. READ-ONLY REFERENCE. Never edit.
├── dev stuff\RetroArch\ ← prebuilt x64 UWP ANGLE binaries + headers
└── Crash dumps\       ← Windows crash dumps pulled from the Xbox
```

- **Only edit** files under `ioQ3-One\` and (when SDL itself must change)
  `SDL-uwp-gl\`. `ioq3-uwp\` is reference only — read it, never modify it.
- Single git branch `main`; history is squashed to one commit, so it won't
  explain anything. The "why" lives in this file and in `#ifdef IOQ3_UWP`
  comments.

## Build commands

One `.msixbundle` is assembled from pieces built by two toolchains. **Rebuild
in this order** after an engine source change — each step consumes the previous:

| Order | Artifact | Toolchain | What it is |
|---|---|---|---|
| 1 | `libioquake3.dll` + `renderer_opengl{1,2}.dll` | MinGW/GCC + lld (CMake) | the engine |
| 2 | `libioquake3_msvc.lib` | MSVC `lib.exe` | import stub exporting only `SDL_main` |
| 3 | `libuwp.dll` | MSVC C++/WinRT (MSBuild) | WinRT→C bridge |
| 4 | `uwp.exe` + bundle | MSVC (MSBuild) | the UWP app shell |

The exact command lines live in **`README.md` → "Building"**. Skipping the
step-2 import-lib regen after touching exported symbols is the classic "it
linked but crashes on launch" trap.

Verbose diagnostics are off by default in Release. To enable boot breadcrumbs +
`qconsole.log` + per-shader progress:

```bash
cmake -DIOQ3_UWP_DEBUG_LOGS=ON .    # then rebuild
cmake -DIOQ3_UWP_DEBUG_LOGS=OFF .   # back to quiet release (flag is sticky)
```

After any link change, verify lld (not GNU ld) produced a sane export table:

```bash
objdump -p build/Release/libioquake3.dll | grep "Export RVA"
# RVA must be small (e.g. 0x000def19). A huge number = ld crept back = poison DLL.
```

## The MSVC↔MinGW bridge (`libuwp`)

`libuwp` is the **only** sanctioned channel between the MSVC shell and the
MinGW engine. It exposes a flat C ABI (`libuwp/libuwp.h`):

```c
LIBAPI void  uwp_GetScreenSize(int* x, int* y);
LIBAPI void  uwp_GetBundlePath(char* buffer);
LIBAPI void  uwp_GetBundleFilePath(char* buffer, const char* filename);
LIBAPI float uwp_GetRefreshRate();
LIBAPI void  uwp_GetPlayerName(char* buffer, int bufLen);  // dead — no engine caller (see player-name note)
```

> **Player name:** `uwp_GetPlayerName` still compiles but nothing calls it.
> The Xbox gamertag API needs the GDK (unavailable in Dev-Mode UWP); the
> account `DisplayName` returns the real name, not the gamertag. So instead
> `uwp/main.cpp` writes `set name "Q3Xbox"` to `LocalState\baseq3\uwp_defaults.cfg`
> on first boot, and `common.c` execs that cfg. Do **not** re-attempt gamertag
> lookup without GDK access.

The engine never sees a WinRT type; libuwp never sees a GCC type. To add new
WinRT data: add a `uwp_*` function here, rebuild libuwp (artifact 3), call it
from the engine behind `#ifdef IOQ3_UWP`. Contract: **caller allocates the
buffer, callee fills it. Plain C scalars/pointers only.**

## Where the IOQ3_UWP changes live

| File | What it changes |
|---|---|
| `code/sys/sys_win32.c` | `Sys_DefaultHomePath` → LocalState path; `Sys_ErrorDialog` → `ioq3_error.log` there |
| `code/sdl/sdl_glimp.c` | ES2 default (`r_preferOpenGLES=1`), explicit `SDL_GL_LoadLibrary("libEGL.dll")`, per-profile retry, `R_MODE_FALLBACK=-2` (native res) |
| `code/sdl/sdl_input.c` | Xbox controller scheme, OSK chat/console, no `SDL_StartTextInput` at boot |
| `code/renderergl2/tr_glsl.c` | Force GLSL ES 1.00 header, disable bone anim, skip shadowmask shader, pump SDL events between compiles |
| `code/renderergl2/tr_extensions.c`, `tr_init.c` | ANGLE clamps (`glslMaxAnimatedBones=0`, `shadowSamplers=qfalse`) |
| `code/qcommon/common.c` | CD-key auto-gen, `com_logfile` default `0`, skip `com_abnormalExit` safe-mode reset, exec `uwp_defaults.cfg` |
| `code/client/cl_main.c`, `snd_dma.c` | client/audio tweaks (VoIP off) |
| `code/client/snd_openal.c` | `ALDRIVER_DEFAULT="libopenal-1.dll"` (MSYS2 naming) so OpenAL+music actually loads |
| `code/client/cl_keys.c` | fire `K_JOY1+i` for pad buttons (so ui.qvm shows real names), B→Esc menu redirect after `CL_ParseBinding`, `Key_StringToKeynum` keyname-first scan |
| `code/client/cl_input.c` | `CL_JoystickMove` scales look axes by `cl_sensitivity/5` (in-game slider drives stick speed) |
| `code/q3_ui/ui_mfield.c` | text-field / OSK interaction |
| `code/server/sv_init.c` | server-side UWP guard |

`IOQ3_UWP` reaches the renderer DLLs via `cmake/renderer_common.cmake`. If a
renderer change isn't taking effect, confirm the define is reaching that target.
**Always wrap Xbox-specific changes in `#ifdef IOQ3_UWP`** so the source stays a
clean delta from upstream ioquake3.

## Rendering & shaders (ANGLE on the One)

The Xbox One GPU is D3D feature level ~10.0 (`vs_4_1` / `ps_4_1`). ANGLE
advertises GLSL ES 3.00 but stalls/rejects Q3's ES3 shaders, so:

- All shaders forced through `#version 100` (GLSL ES 1.00) in
  `tr_glsl.c::GLSL_GetShaderHeader`.
- Bone animation disabled (`glslMaxAnimatedBones=0`) — translator hangs on big
  permutations. Safe: vanilla Q3 ships no `.iqm` skeletal content.
- Shadowmask shader skipped — it hardcodes `sampler2DShadow` (`shadowSamplers=qfalse`).
- `#extension GL_OES_standard_derivatives : enable` emitted in SSAO/depthBlur.
- SDL events pumped between shader permutations (~81 compile in ~12s on first
  boot) to stay under the UWP watchdog (below).

Treat ANGLE-on-One as a **subset** of GLES2. "Compiles in desktop ANGLE" proves
nothing — test on hardware.

## The ~20s UWP watchdog

WinRT kills any app that doesn't pump its `CoreWindow` message queue for ~20s.
Any long synchronous main-thread step (shader compile, big map load, blocking
I/O) risks it.

- Pump SDL events inside any new long startup loop, or the OS kills you and it
  looks like a freeze (no `ioq3_error.log`), not a crash.
- Blocking dialogs are doubly dangerous — that's why VoIP is compiled out and
  `SDL_StartTextInput()` is not called at boot (mic prompt / OSK can block the
  queue).

## Input model

No mouse/keyboard — controller + WinRT on-screen keyboard (OSK/InputPane),
implemented in `sdl_input.c` under `IOQ3_UWP`:

- Stock SDL gamepad binds (RT=fire, A=jump, …); stick directions bound to
  `+forward` etc. so `KeyToAxisAndSign` reads them.
- **LB+RB** (edge-triggered) = toggle developer console anywhere, raises OSK.
- **L3+A** in gameplay = open chat (`messagemode` + `SDL_StartTextInput()`);
  WinRT InputPane is non-blocking.
- Menus: D-pad→arrows, A→Enter, B→Esc, left stick→mouse.
- `IN_Frame` auto-hides the OSK when no text-input catcher is active.
- **Button names in the Controls menu:** stock ui.qvm only scans keycodes
  0–255, so `K_PAD0_*` (≥264) show as "???". Fix in `cl_keys.c`: fire
  `K_JOY1+i` directly from the SDL GameController handler (K_JOY* sit in
  0–255), so rebinds display "A", "B", "LB", "D-pad Up", etc. D-pad arrow
  mirrors still fire alongside for menu nav.
- **B as back in menus:** stock ui.qvm doesn't treat K_JOY2 as back. After
  `CL_ParseBinding` (so B's gameplay bind still fires), `cl_keys.c` redirects
  K_JOY2 through the K_ESCAPE dispatch when not in active no-catcher gameplay.
  Don't fire K_ESCAPE from `sdl_input.c` — that runs before `CL_ParseBinding`
  and breaks rebinding.
- **Look sensitivity:** the in-game mouse-sensitivity slider scales stick look
  speed — `CL_JoystickMove` multiplies look axes by `cl_sensitivity/5`.

## Debugging on hardware

No attached debugger — diagnose via logs and crash dumps.

- `<parent>\Crash dumps\` — crash dumps pulled from the Xbox.
- Xbox writable LocalState (Device Portal → File Explorer → User Folders →
  LocalAppData → `ioq3-uwp_..._t8sjjnx0kvmt8` → LocalState):
  `...\Packages\ioq3-uwp_t8sjjnx0kvmt8\LocalState\`
  - `ioq3_error.log` — **always** written on a `Com_Error`. Read this first.
  - `baseq3\q3config.cfg` — user settings (see config-reset rule below).
  - Debug build only: `qconsole.log` (flushed) + `boot_*.log` breadcrumbs.
- A freeze with **no** `ioq3_error.log` usually means the watchdog killed you —
  different problem, different fix.

## Workflow for a change

1. Map the surface: `grep -rln "IOQ3_UWP" code/` + the table above.
2. Make the change behind `#ifdef IOQ3_UWP`, matching surrounding code.
3. Rebuild in order: engine → MSVC import lib → libuwp → bundle. Don't skip the
   import-lib regen if exported symbols changed.
4. If you changed a cvar **default**, delete `q3config.cfg` on the device or the
   stale value overrides your new default.
5. If you added a long startup step, pump SDL events.
6. Deploy via Device Portal (`http://<xbox-ip>:11443`), install VCLibs once, FTP
   retail paks if needed.
7. On failure, read logs first (`ioq3_error.log` → crash dumps → enable
   `IOQ3_UWP_DEBUG_LOGS`).
8. Document the change here (tables below) or in an `#ifdef IOQ3_UWP` comment.

## Hard rules / dead ends (do not re-attempt without solving the prerequisite)

| Attempt | Why it failed | Prerequisite to retry |
|---|---|---|
| GNU `ld` for the engine DLL | Corrupt PE export table | None — use lld, always |
| Env vars across MSVC↔MinGW | CRTs don't share env block | None — use the `libuwp` C ABI |
| `LoadPackagedLibrary(libuwp)` | Failed empirically | None — link via import lib |
| Mouse + keyboard input | `SDL_SetRelativeMouseMode` non-functional on WinRT | Make relative mouse work on WinRT first |
| Writing to `D:\DevelopmentFiles\` | Not writable from AppContainer (despite `broadFileSystemAccess`) | None — use LocalState |
| GLSL ES 3.00 shader path | ANGLE-on-One translator stalls/rejects | Fixed ANGLE build, or rewrite shaders for vs_4_1 |
| 640×480 fallback mode | Looked tiny/broken on TV | Already fixed (`R_MODE_FALLBACK=-2`) |
| Xbox gamertag for player name | Needs GDK (no Dev-Mode UWP); `DisplayName` gives real name, not gamertag | GDK access — else keep the `Q3Xbox` cfg default |
| Mirroring K_JOY2 → K_ESCAPE in `sdl_input.c` | Fires before `CL_ParseBinding`, breaks rebinding & loops rebind prompt | None — redirect lives in `cl_keys.c` after `CL_ParseBinding` |

## Current state

Shipping / functional: ANGLE/D3D11 rendering at 1080p60, audio via OpenAL
(`libopenal-1.dll`) with music streaming, networking (LAN + internet browser +
direct connect), Xbox controller with rumble, OSK chat (L3+A), menu navigation
with B-as-back, developer console (LB+RB), native-resolution display,
in-game sensitivity slider scaling stick look, Controls menu showing proper
Xbox button names, and a fixed `Q3Xbox` default player name.

If something regressed, suspect in order: (1) rebuild skipped the import-lib
step, (2) cvar default changed without deleting `q3config.cfg`, (3) GNU ld crept
back in, (4) the watchdog on a new startup path, (5) an ANGLE-incompatible
shader change.
