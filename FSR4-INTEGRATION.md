# Native BG3 + FSR 4 integration

This branch connects BG3MetalFX's native macOS rendering hooks to the FSR 4.1.2
INT8 Lite Metal backend. It does not require the Windows game or CrossOver.
The backend is pinned as a Git submodule in `vendor/fsr4-native-macos`.

## Build and test

```sh
git submodule update --init --recursive
python3 tools/setup-fsr4-model.py
./build-fsr4.sh
./test-fsr4.sh
./test-fsr4.sh large
```

Requires Apple Silicon, macOS 26+, a suitable C++ SDK and the Metal toolchain.
The setup tool downloads a pinned, SHA256-verified upstream release and extracts
only its model assets. Model assets and compiled shaders remain ignored build
artifacts; they are not committed. Preserve upstream third-party/model licensing
and provenance if redistributing them.

The build produces `build/bg3metalfx.dylib` and `build/libbg3fsr4.dylib`. The FSR
backend is compiled as arm64 with ARC, separately from BG3MetalFX's MRC interposer.
It excludes the upstream CrossOver-specific MetalFX swizzle hook.

The smoke test submits three actual GPU frames with reversed depth, render-pixel
motion, jitter, constant exposure, temporal history and RG11B10 input/output.
The large case uses 2016x1260 -> 3024x1890. It checks command-buffer completion
and finite, nonzero output. These checks do not establish in-game visual accuracy
or performance. First use compiles model shaders and can take time.

## Run the development build

Quit BG3, then:

```sh
./launch-fsr4.sh
# Or pass another native Mac app bundle:
./launch-fsr4.sh "/path/to/Baldur's Gate 3.app"
```

The launcher reads the app's actual executable name, uses this checkout's dylibs,
and creates an independent config at `build/runtime/BG3MetalFX/config.toml` with
Quality upscaling, frame interpolation off, no frame cap and detailed logging.
It does not change the existing installed dylib or Desktop launcher. The upstream
render-scale option writes the game's FSR setting at startup and keeps a backup.
Keep TAA enabled and use a display-sized window. Do not enable frame interpolation
until the upscaler has been checked in game.

Logs:

- `build/fsr4-runtime.log`: FSR model, conversions, compilation and errors.
- `build/bg3-launch.log`: process stdout/stderr.
- `~/Library/Logs/BG3MetalFX.log`: existing mod diagnostics plus explicit
  `FSR4 BACKEND: ACTIVE` / `FSR4 BACKEND: FALLBACK to MetalFX` transitions.

The upstream `STATUS: MetalFX active` line still names the overall replacement
pipeline. It does **not** distinguish FSR from MetalFX; use the FSR4 BACKEND line.

## Implementation and limits

`src/fsr4_bridge.inc.mm` feeds the scaler's configured textures and per-frame
properties into the upstream live API. Motion vectors are render-resolution,
un-jittered, scaled with BG3MetalFX's existing signed pixel scales. Colour uses
linear HDR with the existing exposure hint. FSR uses the same command buffer and
output as MetalFX, so both existing encode paths retain their ordering. Backend
allocations are excluded from BG3's render-target probe.

Backend loading is opt-in through `BG3_FSR4_LIBRARY`; otherwise MetalFX behaves
as before. A backend rejection invalidates FSR history and encodes MetalFX instead.
Returning from FSR to MetalFX resets MetalFX history. Resize teardown releases FSR
owner state through the upstream lifetime API. The dylib stays loaded for in-flight
GPU work. Automatic backend selection uses SIMD on this M2 Max.

BG3MetalFX's original colour grading, bloom reconstruction, compositing and optional
frame-generation paths are retained. Replacing the upscaler cannot by itself fix
white flashes caused by those paths. The Lite build has been visually checked in one native GOG BG3 session on M2 Max
at Quality (2016x1260 -> 3024x1890). The full 4.1.1 exact-fast backend also ran,
but dropped that setup below 30 FPS. This is limited validation; other scenes,
game versions, stores and hardware still need testing.
