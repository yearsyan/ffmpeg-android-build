#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Script: build_ffmpeg.sh
# Purpose: Cross-compile Android static FFmpeg on macOS (Intel/M1) or Linux
# Supported architectures: aarch64 (arm64-v8a), armv7a (armeabi-v7a), x86, x86_64
# Usage: ./build_ffmpeg.sh [ARCH]  (default aarch64)
# =============================================================================

# Required: ANDROID_NDK environment variable must point to the NDK root directory
NDK_ROOT="${ANDROID_NDK:-}"
if [[ -z "$NDK_ROOT" ]]; then
  echo "Error: ANDROID_NDK is not set, please run export ANDROID_NDK=/path/to/android-ndk first" >&2
  exit 1
fi

# Adjustable parameters
API_LEVEL=21                      # Minimum supported API level ≥ 21
CPU_COUNT=$(sysctl -n hw.ncpu || nproc)

# Read architecture from the script's first argument, default is aarch64
ARCH="${1:-aarch64}"

# Set FFmpeg configure's --arch, --cpu, and NDK triple according to ARCH
case "$ARCH" in
  aarch64)
    TARGET_ARCH="aarch64"
    TARGET_CPU="armv8-a"
    TRIPLE="aarch64-linux-android"
    ;;
  armv7a)
    TARGET_ARCH="arm"
    TARGET_CPU="armv7-a"
    TRIPLE="armv7a-linux-androideabi"
    ;;
  x86)
    TARGET_ARCH="x86"
    TARGET_CPU="i686"
    TRIPLE="i686-linux-android"
    ;;
  x86_64)
    TARGET_ARCH="x86_64"
    TARGET_CPU="x86-64"
    TRIPLE="x86_64-linux-android"
    ;;
  *)
    echo "Error: Unsupported architecture '$ARCH' (only support aarch64, armv7a, x86, x86_64)" >&2
    exit 1
    ;;
esac

PREFIX="$(pwd)/ffmpeg_android_${TARGET_ARCH}_build"

# Automatically detect host prebuilt directory (macOS / Linux, Intel / Apple Silicon)
HOST_OS=$(uname | tr '[:upper:]' '[:lower:]')
HOST_ARCH=$(uname -m)
if [[ "$HOST_OS" == "darwin" ]]; then
  POSSIBLE=("darwin-$HOST_ARCH" "darwin-x86_64")
elif [[ "$HOST_OS" == "linux" ]]; then
  POSSIBLE=("linux-$HOST_ARCH" "linux-x86_64")
else
  echo "Error: Only support compilation on macOS or Linux" >&2
  exit 1
fi

PREBUILT=""
for p in "${POSSIBLE[@]}"; do
  if [[ -d "$NDK_ROOT/toolchains/llvm/prebuilt/$p" ]]; then
    PREBUILT="$p"
    break
  fi
done

if [[ -z "$PREBUILT" ]]; then
  echo "Error: No valid prebuilt toolchain directory found, please check: " \
       "$NDK_ROOT/toolchains/llvm/prebuilt/" "${POSSIBLE[*]}" >&2
  exit 1
fi

echo "Using host toolchain: $PREBUILT target architecture $ARCH"

TOOLCHAIN_BIN="$NDK_ROOT/toolchains/llvm/prebuilt/$PREBUILT/bin"
SYSROOT="$NDK_ROOT/toolchains/llvm/prebuilt/$PREBUILT/sysroot"

# Clean old output
rm -rf "$PREFIX"
mkdir -p "$PREFIX"

# Enter FFmpeg source directory
cd "$(dirname "$0")/../ffmpeg"

if [[ -f Makefile ]]; then
  echo "INFO: Detected Makefile, running make distclean..."
  make distclean
fi

# Export cross-compilation toolchain
export CC="$TOOLCHAIN_BIN/${TRIPLE}${API_LEVEL}-clang"
export CXX="$TOOLCHAIN_BIN/${TRIPLE}${API_LEVEL}-clang++"
export AR="$TOOLCHAIN_BIN/llvm-ar"
export AS="$TOOLCHAIN_BIN/llvm-as"
export NM="$TOOLCHAIN_BIN/llvm-nm"
export RANLIB="$TOOLCHAIN_BIN/llvm-ranlib"
export STRIP="$TOOLCHAIN_BIN/llvm-strip"
export LD="$CC"

# Configure configure parameters
COMMON_CFG=(
  --prefix="$PREFIX"
  --target-os=android
  --arch="$TARGET_ARCH"
  --cpu="$TARGET_CPU"
  --cross-prefix=""
  --sysroot="$SYSROOT"
  --cc="$CC"
  --cxx="$CXX"
  --ar="$AR"
  --ranlib="$RANLIB"
  --ld="$LD"
  --strip="$STRIP"
  --enable-cross-compile
  --enable-pic
  --disable-shared
  --enable-static
  --disable-doc
  --disable-debug
  --disable-avdevice
  --enable-protocol=file
  --enable-filter=aformat
  --enable-filter=scale
)

if [[ "$ARCH" == "x86" || "$ARCH" == "x86_64" ]]; then
  # Check if nasm exists on the host
  if command -v nasm &> /dev/null; then
    echo "INFO: Detected NASM. FFmpeg will try to use it for x86 assembly optimization."
    # If configure reports "nasm is too old", user needs to manually update NASM on the host
  else
    echo "INFO: NASM not detected on the host."
    echo "INFO: Will disable x86 assembly optimization (--disable-x86asm). The compiled output may be slightly larger and performance may be slightly worse."
    if [[ "$ARCH" == "x86" ]]; then
      # x86 needs to disable x86 assembly optimization
      COMMON_CFG+=(--disable-asm)
    else
      COMMON_CFG+=(--disable-x86asm)
    fi
  fi
fi

echo "=== Start configuring FFmpeg [$ARCH] ==="
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" \
./configure "${COMMON_CFG[@]}"

echo "=== Start compiling (parallel $CPU_COUNT) ==="
make -j"$CPU_COUNT"

echo "=== Install to $PREFIX ==="
make install

echo "=== Done ==="
echo "Static libraries (*.a) and headers have been installed to: $PREFIX"

# Create tgz archive
echo "=== Creating tgz archive ==="
ARCHIVE_NAME="ffmpeg_android_${TARGET_ARCH}_$(date +%Y%m%d).tgz"
cd "$(dirname "$PREFIX")"
tar -czf "$ARCHIVE_NAME" "$(basename "$PREFIX")"
echo "Archive created: $ARCHIVE_NAME"
