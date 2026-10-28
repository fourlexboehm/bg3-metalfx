# Experimental native MetalFX -> FSR 4 hook

This branch extends the FSR backend with a general arm64 MetalFX temporal-scaler
hook. It is separate from the BG3-specific interposer. It targets games already
using Apple's ordinary MetalFX temporal upscaler. It does not replace spatial
upscaling, frame interpolation, or the combined denoising/upscaling API.

## Build

```sh
git submodule update --init --recursive
python3 tools/setup-fsr4-model.py
./build-native-fsr4.sh
```

This also builds a GPU test that creates a real Apple MetalFX temporal scaler,
then verifies FSR replacement, ordinary MetalFX fallback, and recovery through
that API. The model/backend code remains pinned in the submodule.

## Prepare and launch

The current launch profiles assume these app bundles:

```sh
python3 tools/prepare-native-fsr4.py cyberpunk
./launch-native-fsr4.sh cyberpunk

python3 tools/prepare-native-fsr4.py crimson
./launch-native-fsr4.sh crimson
```

The preparation step copies runtime resources into each game's sandbox container
under `Data/Library/Application Support/NativeFSR4`. Source/build tooling remains
shared in this checkout. A shared `~/.cache` directory does not grant a sandboxed
game access to it. No game executable, app entitlements, or original signature
is changed. Preparation uses fresh inodes when installing signed libraries.

The script warms the observed tier-2160 linear-HDR/reversed-depth/low-resolution
motion model and tests both compilation enabled and disabled. It currently covers
3024x1890 output. Other output tiers, exposure conventions or shader variants need
preparation before they can work with compilation disabled. Missing variants fall
back to MetalFX. Preparation should run only while the target game is closed.

Choose **ordinary MetalFX upscaling** in the game. The menu will retain that name.
The hook replaces its encoding with FSR 4.1.2 Lite using the game's input sizes,
exposure, depth/motion conventions, offsets, dynamic-resolution and jitter values.
The launcher does not change game settings or enable frame generation.

Launcher/process output is written to `~/Library/Logs/NativeFSR4/<game>/game.log`.
The backend writes `NativeFSR4/logs/fsr4.log` inside the game's container. The
launcher avoids writing into the protected container before executing the game. Look for `NATIVE FSR4: ACTIVE` and current `4.1.2 encoded` entries.
A loaded-hook message alone does not prove that replacement frames ran.

For example, Cyberpunk's runtime is:
`~/Library/Containers/com.cdprojektred.cyberpunk/Data/Library/Application Support/NativeFSR4`.
Crimson Desert uses `com.pearlabyss.CrimsonDesert`.

## Validation and limitations

- Native MetalFX API GPU tests run on M2 Max at 2016x1260 -> 3024x1890.
- Cyberpunk's hook loaded and intercepted its actual temporal scaler. Its first
  run fell back because the sandbox denied access to the checkout's shader files.
  The per-container installation resolved those filesystem restrictions. The next
  run confirmed over 2,100 actual FSR frames, including dynamic resolution at
  1512x945 -> 3024x1890. Visual quality and performance remain user assessments.
- Crimson Desert has a prepared runtime and passed the GPU API test; its actual
  in-game activation and visual correctness still need verification. The combined denoising mode is intentionally untouched.
- First-use compilation of Metal source through Apple's runtime compiler still
  occurs. External Python/model build subprocesses are disabled in the game.
- A failed replacement invalidates FSR history. The first MetalFX fallback after
  FSR frames resets MetalFX history. Scaler lifetime callbacks release FSR state.
- No performance or image-quality improvement over the games' own MetalFX is
  guaranteed. The full 4.1.1 model was too expensive for the tested BG3 setup;
  these launchers use Lite.
