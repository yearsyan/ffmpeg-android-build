#!/usr/bin/env bash
set -e

X264_BUILD=$PROJECT_ROOT/$BUILD_DIR_NMAE/x264_build_android_$TARGET_ARCH
X264_INSTALL=$X264_PREFIX

if [ -f "$X264_INSTALL/lib/libx264.a" ]; then
  echo "libx264.a already exists at $X264_INSTALL/lib/libx264.a, skipping build..."
  exit 0
fi

rm -rf "$X264_BUILD"
mkdir -p "$X264_BUILD"

cd "$PROJECT_ROOT/x264"

# Add architecture specific flags
ARCH_FLAGS=""
if [ "$TARGET_ARCH" = "arm" ]; then
    ARCH_FLAGS="-march=armv7-a"
fi

STRINGS="$NDK_TOOLCHAIN/bin/llvm-strings" ./configure \
  --prefix="$X264_INSTALL" \
  --enable-static \
  --enable-pic \
  --disable-shared \
  --disable-cli \
  --disable-opencl \
  --disable-asm \
  --disable-avs \
  --disable-lavf \
  --disable-ffms \
  --disable-gpac \
  --disable-lsmash \
  --host="$TRIPLE" \
  --cross-prefix="$NDK_TOOLCHAIN/bin/${TRIPLE}-" \
  --sysroot="$NDK_TOOLCHAIN/sysroot" \
  --extra-cflags="-fPIC -ffunction-sections -fdata-sections -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE $ARCH_FLAGS" \
  --extra-ldflags="-Wl,--gc-sections"

make -j$(nproc)
make install
$NDK_TOOLCHAIN/bin/llvm-strip --strip-unneeded "$X264_INSTALL/lib/libx264.a"