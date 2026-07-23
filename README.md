# GCWII-Recomp-Test

A static-recompilation pipeline for GameCube and Wii games, built on:

- [DolRecomp](https://github.com/ExpansionPak/DolRecomp) - static recompiler that turns a GameCube/Wii DOL into split C source.
- [ModernGekko](https://github.com/ExpansionPak/ModernGekko) - the runtime the recompiled C links against (built on a Dolphin-derived core for video/audio/HLE).

Both are pulled in as git submodules under `lib/`. Everything is driven through the top-level `Makefile`, based on [ModernGekko-Template](https://github.com/ExpansionPak/ModernGekko-Template).

## Dependencies

CMake, Ninja, and pkg-config, plus a C11/C++23 toolchain. DolRecomp and ModernGekko both build on macOS, Linux, and Windows; this repo's `Makefile` doesn't do anything platform-specific itself - it just drives the same CMake builds each submodule supports natively. `TOOLCHAIN` (see below) defaults to the native compiler for whichever of these you're on.

### Linux

Ubuntu/Debian, matching what `lib/ModernGekko/vendor/dolphin`'s own CI installs for its NoGUI build (`.github/workflows/build.yml`):

```
sudo apt-get install -y ninja-build build-essential pkg-config cmake \
  libevdev-dev libudev-dev libgtk-3-dev libsystemd-dev \
  libbluetooth-dev libasound2-dev libpulse-dev libgl1-mesa-dev \
  libxrandr-dev libxi-dev
```

### macOS

Via Homebrew:

```
brew install cmake ninja pkg-config
```

Xcode's command line tools are also required (AppleClang 14.0.3+; verified on AppleClang 17).

`build-essential` pulls in GCC, the default toolchain on Linux (see "Toolchain" below for why). Other distros need the equivalent `-dev`/`-devel` packages from their own package manager (evdev, udev, GTK3, systemd, BlueZ, ALSA, PulseAudio, GL, Xrandr, Xi).

### Windows

Install [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022) (or full Visual Studio 2022) with the "Desktop development with C++" workload for the MSVC toolchain, plus CMake and Ninja on `PATH` (each has a standalone Windows installer, or install via `winget`/`choco`). No external package manager is needed beyond that for the build itself - Dolphin's Windows dependency tree (FFmpeg, SDL, etc.) is vendored as prebuilt binaries/source under `lib/ModernGekko/vendor/dolphin/Externals/`, unlike Linux where system `-dev` packages are expected. `pkg-config` isn't available on Windows out of the box, though:

```
winget install --id bloodrock.pkg-config-lite --source winget -e
```

MSVC isn't on `PATH` in an ordinary shell - build from a shell launched inside an **"x64 Native Tools Command Prompt for VS 2022"**. If you're using Git Bash (recommended; the `Makefile` needs a POSIX-ish shell and GNU coreutils, both of which Git Bash already provides), open that Native Tools prompt first, then launch Git Bash from inside it so it inherits the MSVC environment:

```
"C:\Program Files\Git\bin\bash.exe" --login -i
```

Run `make check` from that shell to verify everything (`cmake`, `ninja`, `pkg-config`, git, and a C++ compiler) is actually on `PATH` and runnable before building - it's also a build prerequisite, so a missing dependency fails fast with this same message instead of deep inside a CMake/Ninja log.

## Getting the Source

```
git clone --recurse-submodules git@github.com:MrPoloGit/MeleeRecomp.git
cd MeleeRecomp
```

If you already cloned without `--recurse-submodules`, `make` will fetch them for you on first run. To do it manually instead:

```
git submodule update --init --recursive
```

> [!NOTE]
> `lib/ModernGekko` vendors a large chunk of Dolphin's dependency tree (SDL, fmt, imgui, Vulkan headers, etc.), so the first submodule sync takes a while and pulls a few hundred MB.

## Recompile and Run

Bring your own legally-owned ISOs - no game data is included in or downloaded by this repository. Works with any GameCube or Wii disc; there is no default game, so `ISO=` (or an already-extracted `GAME=`) is required. Point `ISO` at a dump and run:

```
make run ISO=/path/to/Super\ Smash\ Bros.\ Melee.iso
```

This builds DolRecomp and ModernGekko, extracts the ISO, recompiles `main.dol` to C, compiles the result into a native module, and launches the game in a window.

Each game gets its own directory under `extracted/<slug>/`, where `<slug>` is derived from the ISO's filename, so multiple games coexist without clobbering each other. `ISO` is only needed the first time per game - once extracted, run it again by slug instead:

```
make run ISO=iso/Mario\ Kart\ Wii\ ....iso  # first time for a new game
make run GAME=Mario-Kart-Wii-USA-En-Fr-Es   # afterwards, by slug
```

Drop ISOs under `iso/` at the repo root (gitignored) for a stable local path.

To just build the tools without touching a game, or to produce the compiled module without launching it:

```
make tools
make recompile ISO=/path/to/game.iso
```

`moderngekko-port` caches compiled modules by DOL hash and toolchain identity, so re-running `recompile`/`run` after the first build is cheap - it hits cache instead of recompiling.

> [!NOTE]
> Wii ISOs need [Wiimms ISO Tools](https://wit.wiimm.de/) (`wit`) for extraction - `make` downloads it automatically into `extern/wit` on first use. GameCube extraction is built into DolRecomp directly and doesn't need this.

## Makefile Targets

Run `make help` (or just `make`, the default target) for this list:

| Target       | Description                                                |
|--------------|--------------------------------------------------------------|
| `check`      | Verify CMake, Ninja, pkg-config, git, and a C++ compiler are on `PATH` and runnable |
| `tools`      | Build DolRecomp and ModernGekko (runs `check` first)         |
| `extract`    | Extract a GameCube/Wii ISO into `extracted/<slug>/`         |
| `recompile`  | Recompile + compile a runnable module                       |
| `run`        | Recompile (if needed) and launch the game                   |
| `clean`      | Remove all build output                                     |

## Variables

| Variable           | Default                                    | Description                                              |
|--------------------|---------------------------------------------|------------------------------------------------------------|
| `ISO`              | *(none)*                                    | Path to a game ISO. Required the first time per game - also determines that game's slug. |
| `GAME`             | *(none)*                                    | Select an already-extracted game by slug instead of `ISO=`. Required if `ISO` isn't given. |
| `JOBS`              | detected CPU count                          | Parallel build jobs passed to CMake/Ninja.                |
| `CMAKE_BUILD_TYPE`  | `Release`                                    | Passed to both submodule builds.                          |
| `RUN_ARGS`          | *(empty)*                                    | Extra flags forwarded to `moderngekko-run` via `make run`, e.g. `--headless`, `--graphics Vulkan`. |
| `TOOLCHAIN`         | `gcc` (Linux) / `clang` (macOS) / `msvc` (Windows) | Compiler for the per-game module: `auto`, `clang`, `gcc`, or `msvc`. See "Toolchain" below. |

For example, to force a debug build with extra runner flags:

```
CMAKE_BUILD_TYPE=Debug make run ISO=/path/to/game.iso RUN_ARGS="--headless"
```

## Toolchain

The `Makefile` defaults `TOOLCHAIN` per-platform: `gcc` on Linux, Apple Clang (`clang`) on macOS, `msvc` on Windows. That default exists specifically because of a Linux issue: clang's per-game module build links with `-fuse-ld=lld`, and if `ld.lld` isn't reliably resolvable on your system (PATH issues, partial LLVM install, etc.), the module build fails at the link step. GCC's build branch in `module-template/CMakeLists.txt` doesn't use `lld` at all, so it's the safer default there. macOS and Windows don't have that failure mode, so they default to their native compiler instead.

Override it either way with `TOOLCHAIN=`:

```
make run ISO=/path/to/game.iso TOOLCHAIN=clang   # try clang on Linux anyway
make run ISO=/path/to/game.iso TOOLCHAIN=auto    # let moderngekko-port pick
```

Module builds are cached by DOL hash *and* toolchain identity, so switching `TOOLCHAIN` between runs produces a separate cache entry rather than clobbering a previous build.

## How Assets Are Handled

DolRecomp only recompiles code (`main.dol`) - it never touches game assets. Extraction lays out the full disc filesystem under `extracted/<slug>/` (`sys/` for boot files, `files/` for every asset on the disc, in their original formats). At runtime, ModernGekko boots through Dolphin's real `BootParameters`/`DiscIO` path, which treats that `sys/`+`files/` directory as a virtual disc and serves every file read the (recompiled) game code makes exactly as if it were reading the original disc. No asset conversion or repacking happens anywhere in this pipeline.

Wii discs additionally carry multiple partitions (`UPDATE`, `CHANNEL`, `DATA`); `wit` extracts each into its own subfolder rather than flattening the game partition to the top level the way GameCube extraction does. The `Makefile` handles this automatically - after extraction, if `sys/main.dol` isn't at the top level but `DATA/sys/main.dol` is, it flattens `DATA/` up a level.

## Controller Input

ModernGekko has no in-app controller configuration UI (same as Dolphin's NoGUI frontend it's built on) - bindings come from `Config/GCPadNew.ini` / `Config/WiimoteNew.ini` in ModernGekko's user directory (`~/.local/share/moderngekko/Config/` by default), which nothing in this pipeline creates for you. Without one, controller input silently does nothing. You'll need to hand-author or copy in a working ini - Dolphin's ini format and key names are stable and documented by the project itself.

## macOS Support

DolRecomp already builds cleanly on macOS with no changes. ModernGekko needed four small fixes to build, open a window, and output audio there:

1. **`SDL_HIDAPI OFF` on `APPLE`** (`CMakeLists.txt`) - SDL3's vendored build embeds its own copy of the macOS `hidapi` backend, which collides (duplicate `_hid_darwin_*` symbols) with Dolphin's own vendored `hidapi` at static link time.
2. **`OBJCXX` language + `CommonFuncsObjC.mm`** (`CMakeLists.txt`) - `DriverDetails.cpp` calls `Common::GetMacOSVersion()`, implemented in an Objective-C++ file that wasn't included in the `moderngekko_dolphin_video` target's sources.
3. **Cocoa windowing backend** (`CMakeLists.txt`, `src/runtime/dolphin_runtime.cpp`) - upstream `Runtime::Create()` only ever selected Headless, Wayland, or X11, so any non-headless run failed with "the requested Dolphin host platform is unavailable." Dolphin's real Cocoa backend (`PlatformMacos.mm`) already existed in the vendored source; it just wasn't wired up. Without this fix the game builds and loads fine but never opens a window.
4. **`ENABLE_CUBEB ON` on `APPLE`** (`CMakeLists.txt`) - upstream forced Cubeb (Dolphin's only real audio backend on macOS; it wraps CoreAudio) off unconditionally, leaving only the silent `NullSoundStream` backend regardless of config.

Separately, this repo's own `Makefile` works around one macOS-specific tooling issue: the official prebuilt `wit` binary (used for Wii extraction) ships with a signature Gatekeeper rejects outright on current macOS (`invalid signature (code or signature have been modified)`, killed on launch). The `wit` target re-signs it locally (ad-hoc) after download, which resolves it.

## Windows Support

DolRecomp builds unmodified on Windows. ModernGekko needed a number of fixes, all in `lib/ModernGekko/CMakeLists.txt` unless noted, since its own targets (`moderngekko`, `moderngekko_legacy`, `moderngekko-launcher`) compile `vendor/dolphin` sources directly and sit outside that submodule's own CMake directory scope — so none of the flags/definitions it sets for itself reach them:

1. **`/Zc:preprocessor` on MSVC** — Dolphin's fmt-based logging macros (`Common/HookableEvent.h`, `Common/Logging/Log.h`) and Dear ImGui's `IM_ASSERT` use `__VA_OPT__`, which MSVC's classic (non-conforming) preprocessor mishandles (`C5109`/`C3878`/`C2146` and friends). Scoped to `moderngekko`, `moderngekko_legacy`, `moderngekko_dolphin_video`, and `moderngekko-launcher` specifically, not applied globally — see point 2.
2. **`NOMINMAX` / `WIN32_LEAN_AND_MEAN` / `UNICODE` / `_UNICODE` / CRT-warning suppressions** — `vendor/dolphin/Source/CMakeLists.txt` already sets these for targets built inside its own tree (`core`, `uicommon`, ...), but not for ModernGekko's own targets. Without `NOMINMAX`, `Common/BitField.h`'s `std::numeric_limits<T>::max()` collides with `windows.h`'s `max()` macro; without `WIN32_LEAN_AND_MEAN`, `windows.h` drags in the legacy `winsock.h` ahead of `winsock2.h`; without `_UNICODE`, `Common/StringUtil.h`'s `TStrToUTF8`/`UTF8ToTStr` fall into the wrong `#ifdef` branch and fail to compile. These are applied per-target (not globally) because `vendor/dolphin/Externals/hidapi`'s vendored `hidapi_cfgmgr32.h` breaks under `WIN32_LEAN_AND_MEAN` — its `PROPERTYKEY`/`DEFINE_PROPERTYKEY` declarations depend on the un-lean `<windows.h>` expansion.
3. **`PlatformWin32` windowing backend** (`CMakeLists.txt`, `src/runtime/dolphin_runtime.cpp`) — same shape of gap as the macOS Cocoa fix above: upstream `Runtime::Create()` only ever selected Headless, Wayland, or X11/macOS, so any non-headless run failed with "the requested Dolphin host platform is unavailable." Dolphin's real Win32 backend (`PlatformWin32.cpp`) already existed in the vendored source, just unused; it also needs `Dwmapi.lib` linked (`DwmSetWindowAttribute`).
4. **`UICommon::CreateDirectories()`** (`src/runtime/dolphin_runtime.cpp`) — real Dolphin frontends call this between `SetUserDirectory()` and `Init()` (see `DolphinQt/Main.cpp`) to eagerly create the user directory tree. Without it, a brand-new user directory is missing `Cache/`, and `ShaderCache`'s later lazy, single-level `File::CreateDir("Cache/Shaders/")` fails because its parent doesn't exist — breaking shader caching/compilation silently (black screen, no error) on a fresh install.
5. **`ENABLE_CUBEB ON` on `WIN32`, not just `APPLE`** — `AudioCommon::GetDefaultSoundBackend()` only ever tries Cubeb, then ALSA on Linux, before falling through to the silent `NullSoundStream`; it never considers WASAPI even though `WASAPIStream.cpp` is compiled in unconditionally for `WIN32`. Upstream Dolphin's own default is `ENABLE_CUBEB=ON` on every platform — this repo had narrowed it to `APPLE` only.

Two fixes live outside ModernGekko's `CMakeLists.txt`:

- **`moderngekko-port`'s `std::system()` calls mangle multi-argument commands on Windows** (`tools/moderngekko_port.cpp`) — `system()` runs commands via `cmd.exe /c <command>`, and `cmd`'s quote-stripping for `/C` only behaves predictably with exactly two quote characters on the line. Commands quoting multiple path arguments (the executable plus each path) hit `cmd`'s fallback heuristic instead, which mangles argument boundaries — surfacing as e.g. "The filename, directory name, or volume label syntax is incorrect" from the spawned tool. Fixed by wrapping the whole command in one more pair of quotes when it starts with one (`RunCommand()`), the documented workaround (see `cmd /?`).
- **Cache-key directory names could exceed `MAX_PATH`** (`tools/moderngekko_port.cpp`) — the per-build cache directory was named `<64-char dol_sha256>-<16-char toolchain hash>`; combined with a deeply-nested checkout path and further module-build subdirectories, generated object file paths could exceed Windows' legacy 260-character path limit (`cl : Command line error D8022 : cannot open '...rsp'`). The `dol_sha256` component is truncated to 16 characters in the cache-key directory name — cache correctness is unaffected since the full hash is still what's compared for cache-hit validity, via `manifest.txt`.

## Local Patches (`lib/ModernGekko`)

Not OS-specific - these are workarounds for the currently pinned `lib/ModernGekko` commit disagreeing with its own vendored/generated dependencies, uncovered while getting a full clean build running:

1. **`vendor/dolphin/GXRuntime/include/cpu/cpu.h` forwarding shim** (new file) - DolRecomp-generated code `#include`s `"cpu/cpu.h"` expecting DolRecomp's own vendored `CPUState` layout, but per-game modules must link against GXRuntime's canonical `CPUState`/ABI instead - the two currently disagree on layout (DolRecomp's still carries a stale `spr[1024]` field GXRuntime dropped) despite sharing the same include guard. This shim routes straight to `core/cpu.h` (the authoritative one) and adds stub `ppc_mfspr`/`ppc_mtspr` implementations for the named SPRs GXRuntime's `CPUState` actually has fields for (XER, LR, CTR, DSISR, DAR, SRR0/1, EAR, GQR0-7, HID2); everything else reads as 0 and discards writes. Real game code does touch some of the no-op'd SPRs (BAT setup at boot, in particular), so this gets things building and running, not a correctness-complete implementation.
2. **`tools/netplay_session_stub.cpp`** (new file) + **`CMakeLists.txt`** - `tools/netplay_session.cpp` and `tests/netplay_protocol_test.cpp` both call a `NetPlayClient`/`NetPlayServer` API (`SetReady`, `GetPlayersSnapshot`, `CanStart`, `SetAdaptiveBuffer`, `NetPlay::InputWaitTelemetry`, `NetPlay::SetCompatibilityFingerprint`, ...) that doesn't exist in the currently vendored Dolphin NetPlay code, so neither compiles against this tree. The stub keeps `moderngekko-run`'s single external entry point (`RunNetplayLobby`) linkable by reporting netplay as unavailable instead; the CMake test target is disabled (`if(FALSE AND MODERNGEKKO_ENABLE_DOLPHIN_RUNTIME)`) until the vendored API catches up.
3. **`src/runtime/dolphin_runtime.cpp`: `FormatWindowTitle` simplified** - for the same reason as #2, `NetPlay::NetPlayClient::GetInputWaitTelemetry()` doesn't exist in the vendored tree, so the net-wait-ms/buffer-size portion of the window title is removed; it now just reports `{title} | {fps} FPS`.

These are local, uncommitted working-tree changes in `lib/ModernGekko` (not pushed anywhere) - re-running `git -C lib/ModernGekko checkout .` or re-cloning would lose them. Candidates for upstreaming once GXRuntime's `CPUState` and the vendored Dolphin NetPlay code catch up to what these call sites expect.

## Cleaning Up

```
make clean            # everything below
make clean-extracted  # extracted disc + compiled modules only, keeps built tools
make clean-tools       # DolRecomp/ModernGekko build trees only
```

## License

DolRecomp and ModernGekko are each distributed under their own upstream licenses (see `lib/DolRecomp/LICENSE` and `lib/ModernGekko/LICENSE`, the latter GPL-3.0-or-later due to its Dolphin-derived runtime). No Nintendo disc image, extracted game data, keys, or copyrighted assets are part of this repository - bring your own legally-owned dump.

## Notes

A consolidated log of everything changed (code and configuration) to get a build actually launching, rendering, and running at a reasonable speed on Windows, beyond what's already itemized in "Windows Support" and "Local Patches" above.

### Correctness

- **External-interrupt delivery bug** (`lib/ModernGekko/vendor/dolphin/Source/Core/Core/PowerPC/StaticRecomp/StaticRecompCore_Run.cpp`) - the post-burst exception check was gated on `SYNC_EXCEPTION_MASK` (synchronous exceptions only), so `EXCEPTION_EXTERNAL_INT`/`DECREMENTER`/`PERFORMANCE_MONITOR` (e.g. VI's vblank interrupt) were scheduled by `CoreTiming` but never actually delivered anywhere in the static-recomp dispatch loop. Changed the check to `ppc.Exceptions != 0` unconditionally - `CheckExceptions()` already routes to `CheckExternalExceptions()` internally when no synchronous exception is pending, so this is correct for both cases. This was a black-screen/never-boots failure mode, not Windows-specific.

### Windows-specific code fixes

- **`cpu.c` MSVC export** (`lib/ModernGekko/vendor/dolphin/GXRuntime/src/core/cpu.c`) - `ppc_set_mem_write_journal` used `__attribute__((visibility("default")))` to stay visible for `GetProcAddress` lookup; MSVC has no such attribute. Added a `__declspec(dllexport)` branch under `#if defined(_MSC_VER)`.
- **`ARCHIVE_OUTPUT_NAME` for `moderngekko-launcher`** (`lib/ModernGekko/CMakeLists.txt`) - on Windows' case-insensitive filesystem, the launcher exe's auto-generated import lib (`ModernGekko.lib`) collided with the `moderngekko` static runtime lib (`moderngekko.lib`) it links against (`LNK1149`). Gave the import lib a distinct name (`ModernGekkoLauncher.lib`) without renaming the exe.
- **`moderngekko-port` Windows path/quoting fixes** (`lib/ModernGekko/tools/moderngekko_port.cpp`):
  - `Quote()` now uses `generic_string()` instead of `string()` so quoted paths always use `/`, never a `/`+`\` mix - which broke `cmd.exe`'s re-quoting when a path built by appending onto a literal like `build/modules` reached it.
  - `RunCommand()` wraps the whole command in an extra pair of quotes when it already starts with one - `cmd.exe /c`'s quote-stripping only behaves predictably for exactly two quote characters on the line; without this, commands quoting multiple path arguments mangled argument boundaries (surfacing as e.g. "The filename, directory name, or volume label syntax is incorrect").
  - Cache-key directory names truncate `dol_sha256` to 16 characters instead of the full 64 - combined with a deeply-nested checkout and module-build path, the full hash pushed generated object-file paths past Windows' 260-character `MAX_PATH` (`cl.exe` failing to open its `.rsp` file, `D8022`). The full hash is still what's compared for cache-hit validity via `manifest.txt`, so this doesn't affect cache correctness.
  - The tool's own final launch now goes through `RunCommand()` instead of a raw `std::system()` call, so it gets the same quoting fix as every other command it runs.

### Per-game module build performance

- **Optimization flags raised from `-O2`/`/O2` to `-O3`/whole-program**:
  - `lib/ModernGekko/vendor/dolphin/module-template/CMakeLists.txt` - Clang and GCC module builds now use `-O3` (was `-O2`); MSVC adds `/GL` (whole-program optimization) + `/LTCG` (link-time code generation), its closest equivalent to Clang's ThinLTO since MSVC has no `/O3`.
  - `lib/ModernGekko/tools/moderngekko_port.cpp`'s per-toolchain cache-key flag strings updated to match (`-O3` for Clang/GCC, `/O2 /fp:strict /GL` for MSVC), so the cache key actually changes when these flags do instead of silently reusing a stale cached module.
- **Measured on Windows**: an MSVC-only build measured ~13% speed / 8 FPS in one test; switching just the per-game module to Clang (`-O3 -flto=thin`, host stays MSVC) measured ~28% speed / 16 FPS - a confirmed ~2x improvement. The module/host ABI boundary is plain C (a `CPUState*` struct and a `GetProcAddress`-resolved `dispatch()` function, no C++ across it), so mixing host and module compilers is safe. Until MSVC's module codegen is tuned further, prefer `TOOLCHAIN=clang` on Windows explicitly - the Makefile's per-platform default is still `msvc` there.
- **Still open**: even at Clang `-O3`, Windows speed lags noticeably behind what the same generated code reportedly achieves on Linux/macOS. Leading hypothesis: the Windows x64 calling convention mandates 10 callee-saved XMM registers (`XMM6`-`XMM15`) across any function call, while System V (Linux/macOS) has zero - a real per-call tax on the ~10M/sec `dispatch()` calls into floating-point-heavy generated code, independent of compiler. Untested next steps: `__vectorcall` on the hot `dispatch()` call path (supported by both MSVC and Clang on Windows); reducing `EMIT_CHUNK_INSTRUCTIONS` (`lib/DolRecomp/src/backend/codegen.h`, currently `4096`) to produce smaller, more optimizer-tractable generated functions.

### Runtime configuration (not code - ModernGekko's user config, `~/.local/share/moderngekko/Config/` by default)

- `Logger.ini` - quieted from noisy defaults (`Verbosity = 3`, all `WriteTo*` off, only `BOOT`/`CORE`/`OSREPORT`/`OSREPORT_HLE`/`MASTER`/`COMMON` logs enabled). The default verbosity had enough overhead to look like a performance bug on its own before real profiling started.
- `GFX.ini` - added `ShowFPS = True`, `ShowVPS = True`, `ShowSpeed = True` for the on-screen perf overlay used throughout the performance investigation above.
- `Dolphin.ini` - `CPUCore = 6` selects the static-recomp core; `FastDiscSpeed = True`, `CPUThread = True`, `DSPThread = True`; `SIDevice0 = 12` (`SIDEVICE_WIIU_ADAPTER`) routes controller input through the dedicated GC Adapter driver path instead of the generic SDL-joystick binding system.
- **GameCube controller adapter** (Mayflash-style, `libusb`-based) - needs a WinUSB (or libusbK) driver bound to it via [Zadig](https://zadig.akeo.ie/) before `libusb_open()` can succeed; Windows' default HID driver otherwise claims the device first. `GCPadNew.ini`/`GCKeyNew.ini`/`WiimoteNew.ini` still need to be hand-authored or copied in regardless (see "Controller Input" above) - the adapter/Zadig step is specifically about physical controllers plugged into an adapter rather than the ini bindings themselves.
