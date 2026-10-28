#!/bin/bash
set -eu
cd "$(dirname "$0")"
CLT=/Library/Developer/CommandLineTools
if [ -x "$CLT/usr/bin/clang++" ]; then
    CXX="$CLT/usr/bin/clang++"; SDK="$CLT/SDKs/MacOSX.sdk"
else
    CXX="$(xcrun -f clang++)"; SDK="$(xcrun --show-sdk-path)"
fi
mkdir -p build
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -fobjc-arc -arch arm64 \
    -mmacosx-version-min=26.0 -isysroot "$SDK" tests/fsr4-smoke.mm \
    -framework Foundation -framework Metal -o build/fsr4-smoke
exec env FSR4_ROOT="$PWD/vendor/fsr4-native-macos" \
    FSR4_BUILD_DIR="$PWD/vendor/fsr4-native-macos/build" FSR4_SETTINGS=none \
    FSR4_RCAS=0 FSR4_PROFILE=int8-lite FSR4_COLORSPACE=linear FSR4_MODEL=auto \
    ./build/fsr4-smoke "$PWD/build/libbg3fsr4.dylib" "$@"
