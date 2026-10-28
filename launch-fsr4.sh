#!/bin/bash
# Development launcher: uses only this checkout's build and config.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="/Applications/Baldur's Gate 3.app"
if [ "$#" -gt 0 ]; then APP="$1"; fi
EXE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")"
BIN="$APP/Contents/MacOS/$EXE"
if pgrep -f "^$BIN" >/dev/null; then
    echo "Quit BG3 before starting the FSR 4 test build." >&2
    exit 1
fi
[ -f "$HERE/build/libbg3fsr4.dylib" ] || { echo 'Run ./build-fsr4.sh first.' >&2; exit 1; }
[ -d "$HERE/vendor/fsr4-native-macos/build/fsr412_model" ] || {
    echo 'Run python3 tools/setup-fsr4-model.py first.' >&2; exit 1;
}
mkdir -p "$HERE/build/runtime/BG3MetalFX"
cp "$HERE/build/bg3metalfx.dylib" "$HERE/build/runtime/BG3MetalFX/.bg3metalfx.dylib.new"
mv -f "$HERE/build/runtime/BG3MetalFX/.bg3metalfx.dylib.new" "$HERE/build/runtime/BG3MetalFX/bg3metalfx.dylib"
if [ ! -f "$HERE/build/runtime/BG3MetalFX/config.toml" ]; then
    printf 'mode = "metalfx"\nrender_scale = "quality"\nframe_interp = false\nframe_cap = 0\nlogging = true\n' > "$HERE/build/runtime/BG3MetalFX/config.toml"
fi
# Model work uses Apple Metal directly. No CrossOver, Rosetta, or upstream swizzle hook.
exec arch -arm64 env \
    BG3MODS_HOME="$HERE/build/runtime" \
    BG3_FSR4_LIBRARY="$HERE/build/libbg3fsr4.dylib" \
    FSR4_ROOT="$HERE/vendor/fsr4-native-macos" \
    FSR4_BUILD_DIR="$HERE/vendor/fsr4-native-macos/build" \
    FSR4_SETTINGS=none FSR4_VERSION=4.1.2 FSR4_PROFILE=int8-lite FSR4_MODEL=auto \
    FSR4_COLORSPACE=linear FSR4_RCAS=0 FSR4_COMPILE=1 \
    FSR4_HOOK_LOG="$HERE/build/fsr4-runtime.log" \
    DYLD_INSERT_LIBRARIES="$HERE/build/runtime/BG3MetalFX/bg3metalfx.dylib" \
    "$BIN" > "$HERE/build/bg3-launch.log" 2>&1
