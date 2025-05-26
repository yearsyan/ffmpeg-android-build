#!/usr/bin/env bash
set -e

X265_BUILD=$PROJECT_ROOT/$BUILD_DIR_NMAE/x265_build_android_$TARGET_ARCH
X265_INSTALL=$X265_PREFIX
NDK="${ANDROID_NDK:-}"

if [ -f "$X265_INSTALL/lib/libx265.a" ]; then
  echo "libx265.a already exists at $X265_INSTALL/lib/libx265.a, skipping build..."
  exit 0
fi

rm -rf "$X265_BUILD"
mkdir -p "$X265_BUILD"

cd "$X265_BUILD"

# Debug: Print environment
echo "=== Build Environment ==="
echo "TARGET_ARCH: $TARGET_ARCH"
echo "ANDROID_ABI: $ANDROID_ABI"
echo "ANDROID_API_LEVEL: $ANDROID_API_LEVEL"
echo "NDK: $NDK"

# Ensure we're building for the correct architecture
if [ "$TARGET_ARCH" = "aarch64" ]; then
    ANDROID_ABI="arm64-v8a"
    EXTRA_FLAGS="-DENABLE_ASSEMBLY=OFF"
    export CFLAGS="-march=armv8-a"
    export CXXFLAGS="-march=armv8-a"
    export LDFLAGS="-march=armv8-a -static-libstdc++"
elif [ "$TARGET_ARCH" = "armv7a" ]; then
    ANDROID_ABI="armeabi-v7a"
    EXTRA_FLAGS="-DCROSS_COMPILE_ARM=ON -DENABLE_ASSEMBLY=ON"
elif [ "$TARGET_ARCH" = "x86" ]; then
    ANDROID_ABI="x86"
    EXTRA_FLAGS="-DENABLE_ASSEMBLY=OFF"
elif [ "$TARGET_ARCH" = "x86_64" ]; then
    ANDROID_ABI="x86_64"
    EXTRA_FLAGS="-DENABLE_ASSEMBLY=OFF"
fi

# x265 arguments
CMAKE_ARGS=(
    "$PROJECT_ROOT/x265/source"
    "-DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake"
    "-DANDROID_ABI=$ANDROID_ABI"
    "-DANDROID_PLATFORM=android-$ANDROID_API_LEVEL"
    "-DANDROID_STL=c++_static"
    "-DANDROID_ARM_NEON=ON"
    "-DCMAKE_SYSTEM_NAME=Android"
    "-DCMAKE_SYSTEM_VERSION=$ANDROID_API_LEVEL"
    "-DCMAKE_ANDROID_ARCH_ABI=$ANDROID_ABI"
    "-DENABLE_SHARED=OFF"
    "-DENABLE_CLI=OFF"
    "-DENABLE_TESTS=OFF"
    "-DENABLE_PIC=ON"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_C_FLAGS=$CFLAGS"
    "-DCMAKE_CXX_FLAGS=$CXXFLAGS"
    "-DCMAKE_EXE_LINKER_FLAGS=$LDFLAGS"
    "-DCMAKE_SHARED_LINKER_FLAGS=$LDFLAGS"
    "-DCMAKE_MODULE_LINKER_FLAGS=$LDFLAGS"
    "-DCMAKE_INSTALL_PREFIX=$X265_INSTALL"
    "-DENABLE_LIBNUMA=OFF"
    "-DENABLE_LIBUNWIND=OFF"
    $EXTRA_FLAGS
)

echo "=== CMake Arguments ==="
printf '%s\n' "${CMAKE_ARGS[@]}"

# Clean any previous CMake cache
rm -rf CMakeCache.txt CMakeFiles/

$CMAKE "${CMAKE_ARGS[@]}"
$CMAKE --build . --config Release --target install -- -j$(nproc)
$NDK_TOOLCHAIN/bin/llvm-strip --strip-unneeded "$X265_INSTALL/lib/libx265.a"

# Verify the built library
echo "=== Verifying built library ==="
file "$X265_INSTALL/lib/libx265.a"
