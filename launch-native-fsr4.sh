#!/bin/bash
# Native MetalFX temporal scaler replacement. BG3 uses its dedicated launcher.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
case "${1:-}" in
    cyberpunk) APP=/Applications/Cyberpunk2077.app; NAME=cyberpunk ;;
    crimson) APP=/Applications/CrimsonDesert.app; NAME=crimson ;;
    *) echo "Usage: $0 cyberpunk|crimson" >&2; exit 2 ;;
esac
EXE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")"
BIN="$APP/Contents/MacOS/$EXE"
if pgrep -f "^$BIN" >/dev/null; then echo "Quit $EXE first." >&2; exit 1; fi
[ -f "$HERE/build/libnativefsr4.dylib" ] || { echo 'Run ./build-native-fsr4.sh first.' >&2; exit 1; }
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
RUNTIME="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Application Support/NativeFSR4"
[ -f "$RUNTIME/prepared.txt" ] || {
    echo "Run python3 tools/prepare-native-fsr4.py $NAME first." >&2; exit 1;
}
LOGDIR="$RUNTIME/logs"
mkdir -p "$LOGDIR"
# Set only model/profile. Exposure, jitter, motion, content regions and depth
# conventions are captured from the game's own MetalFX scaler descriptor.
cd "$APP/Contents/MacOS"
exec arch -arm64 env \
    FSR4_ROOT="$RUNTIME" \
    FSR4_BUILD_DIR="$RUNTIME/build" \
    FSR4_SETTINGS=none FSR4_VERSION=4.1.2 FSR4_PROFILE=int8-lite \
    FSR4_MODEL=auto FSR4_RCAS=0 FSR4_COMPILE=0 FSR4_REPLACE=1 \
    FSR4_HOOK_LOG="$LOGDIR/fsr4.log" \
    DYLD_INSERT_LIBRARIES="$RUNTIME/libnativefsr4.dylib" \
    "$BIN" > "$LOGDIR/game.log" 2>&1
