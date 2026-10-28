#!/bin/bash
set -eu
cd "$(dirname "$0")"
./build-fsr4.sh
CLT=/Library/Developer/CommandLineTools
if [ -x "$CLT/usr/bin/clang" ]; then
    CC="$CLT/usr/bin/clang"; SDK="$CLT/SDKs/MacOSX.sdk"
else
    CC="$(xcrun -f clang)"; SDK="$(xcrun --show-sdk-path)"
fi
"$CC" -dynamiclib -O2 -Wall -Wextra -Werror -fobjc-arc -arch arm64 \
    -mmacosx-version-min=26.0 -isysroot "$SDK" -I vendor/fsr4-native-macos/src \
    src/native-fsr4-hook.m build/libbg3fsr4.dylib \
    -framework Foundation -framework Metal -framework MetalFX \
    -Wl,-rpath,@loader_path -install_name @rpath/libnativefsr4.dylib \
    -o build/libnativefsr4.dylib
codesign -f -s - build/libnativefsr4.dylib

"${CC%clang}clang++" -std=c++17 -O2 -Wall -Wextra -Werror -fobjc-arc -arch arm64 \
    -mmacosx-version-min=26.0 -isysroot "$SDK" tests/native-fsr4-smoke.mm \
    -framework Foundation -framework Metal -framework MetalFX -o build/native-fsr4-smoke
