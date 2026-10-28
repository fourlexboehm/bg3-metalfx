#!/bin/bash
set -eu
cd "$(dirname "$0")"
FSR=vendor/fsr4-native-macos
mkdir -p build/fsr4
CLT=/Library/Developer/CommandLineTools
if [ -x "$CLT/usr/bin/clang++" ]; then
    CXX="$CLT/usr/bin/clang++"
    SDK="$CLT/SDKs/MacOSX.sdk"
else
    CXX="$(xcrun -f clang++)"
    SDK="$(xcrun --show-sdk-path)"
fi
for unit in fsr4_live fsr411_live fsr412_live fsr4_panel; do
    "$CXX" -c -std=c++17 -O2 -Wall -fobjc-arc -arch arm64 -mmacosx-version-min=26.0 \
        -isysroot "$SDK" -I "$FSR/src" "$FSR/src/$unit.mm" -o "build/fsr4/$unit.o"
done
"$CXX" -dynamiclib -arch arm64 -mmacosx-version-min=26.0 -isysroot "$SDK" \
    build/fsr4/*.o -framework Foundation -framework Metal -framework MetalFX \
    -install_name @rpath/libbg3fsr4.dylib -o build/libbg3fsr4.dylib
codesign -f -s - build/libbg3fsr4.dylib
./pack.sh
