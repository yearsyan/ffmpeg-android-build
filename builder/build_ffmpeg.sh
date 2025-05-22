#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Script: build_ffmpeg.sh
# Purpose: Cross-compile Android FFmpeg on macOS (Intel/M1) or Linux
# Supported architectures: aarch64 (arm64-v8a), armv7a (armeabi-v7a), x86, x86_64
# Usage: ./build_ffmpeg.sh [options]
# Options:
#   --arch=ARCH          Target architecture (default: aarch64)
#   --enable-shared      Build shared libraries
#   --enable-merged-shared  Link all static libraries into a single shared library
#   --enable-dynamic-program  Build FFmpeg executable with dynamic linking
#   --show-error        Show detailed error output when build fails
#   --small-build       Build a minimal version with reduced features and smaller size
# =============================================================================

if [[ "$*" == *"--help"* || "$*" == *"-h"* ]]; then
  echo "Usage: $0 [--arch=ARCH] [--enable-shared] [--enable-merged-shared] [--enable-dynamic-program] [--show-error] [--small-build]"
  echo "Default architecture is aarch64 (arm64-v8a)."
  echo "Supported architectures: aarch64, armv7a, x86, x86_64."
  echo "Options:"
  echo "  --enable-shared: Build shared libraries. This corresponds to FFmpeg's '--enable-shared' option."
  echo "  --enable-merged-shared: Link all static libraries into a single shared library 'libffmpeg.so'."
  echo "                          This is distinct from '--enable-shared' as it produces one merged shared library."
  echo "  --enable-dynamic-program: Build the FFmpeg executable with dynamic linking."
  echo "                            Implies '--enable-merged-shared', and the resulting executable will depend on the merged shared library."
  echo "  --show-error: Show detailed error output when build fails. Without this option, only basic error messages are shown."
  echo "  --small-build: Build a minimal version with reduced features and smaller size. This option enables only essential"
  echo "                 codecs and features, resulting in a significantly smaller binary size."
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")" && pwd)"
export PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")/.." && pwd)
# Required: ANDROID_NDK environment variable must point to the NDK root directory
NDK_ROOT="${ANDROID_NDK:-}"
if [[ -z "$NDK_ROOT" ]]; then
  echo "Error: ANDROID_NDK is not set, please run export ANDROID_NDK=/path/to/android-ndk first" >&2
  exit 1
fi

# Adjustable parameters
API_LEVEL=21                      # Minimum supported API level ≥ 21
CPU_COUNT=$(sysctl -n hw.ncpu 2>/dev/null || nproc)

# Read architecture from the script's first argument, default is aarch64
ARCH="aarch64"
for arg in "$@"; do
  case $arg in
    --arch=*)
      ARCH="${arg#*=}"
      ;;
  esac
done

# Set FFmpeg configure's --arch, --cpu, and NDK triple according to ARCH
case "$ARCH" in
  aarch64)
    export TARGET_ARCH="aarch64"
    export TARGET_CPU="armv8-a"
    export TRIPLE="aarch64-linux-android"
    export ANDROID_ABI="arm64-v8a"
    ;;
  armv7a)
    export TARGET_ARCH="arm"
    export TARGET_CPU="armv7-a"
    export TRIPLE="armv7a-linux-androideabi"
    export ANDROID_ABI="armeabi-v7a"
    ;;
  x86)
    export TARGET_ARCH="x86"
    export TARGET_CPU="i686"
    export TRIPLE="i686-linux-android"
    export ANDROID_ABI="x86"
    ;;
  x86_64)
    export TARGET_ARCH="x86_64"
    export TARGET_CPU="x86-64"
    export TRIPLE="x86_64-linux-android"
    export ANDROID_ABI="x86_64"
    ;;
  *)
    echo "Error: Unsupported architecture '$ARCH' (only support aarch64, armv7a, x86, x86_64)" >&2
    exit 1
    ;;
esac

export BUILD_DIR_NMAE="build"
BUILD_DIST="$PROJECT_ROOT/$BUILD_DIR_NMAE"
PREFIX="$BUILD_DIST/ffmpeg_android_${TARGET_ARCH}"
if [[ "$*" == *"--small-build"*  ]]; then
  PREFIX="$BUILD_DIST/ffmpeg_android_${TARGET_ARCH}_mini"
fi

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

export NDK_TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/$PREBUILT"
TOOLCHAIN_BIN="$NDK_TOOLCHAIN/bin"
SYSROOT="$NDK_TOOLCHAIN/sysroot"

# Clean old output
rm -rf "$PREFIX"
mkdir -p "$PREFIX"

DEPS_INSTALL="$PROJECT_ROOT/$BUILD_DIR_NMAE/ffmpeg_android_dep_${TARGET_ARCH}"
#build aom
echo "Start build aom"
export AOM_INSTALL=$DEPS_INSTALL
bash "$SCRIPT_DIR/build_aom.sh"

echo "Start build lame"
export LAME_PREFIX=$DEPS_INSTALL
bash "$SCRIPT_DIR/build_lame.sh"

# Enter FFmpeg source directory
cd "$(dirname "$0")/../ffmpeg"

if [[ -f Makefile ]]; then
  echo "INFO: Detected Makefile, running make distclean..."
  make distclean 2>/dev/null || true
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
  --extra-cflags="-I$DEPS_INSTALL/include"
  --extra-ldflags="-L$DEPS_INSTALL/lib"
  --enable-cross-compile
  --enable-pic
  --enable-static
  --disable-doc
  --disable-debug
)

if [[ "$*" == *"--enable-shared"* ]]; then
  COMMON_CFG+=(--enable-shared)
else
  COMMON_CFG+=(--disable-shared)
fi

# By adjusting these options, you can streamline the compiled components, reducing the size of the final binary.
if [[ "$*" == *"--small-build"*  ]]; then
  source "$SCRIPT_DIR/small_config.sh"
else
  source "$SCRIPT_DIR/standard_config.sh"
fi

COMMON_CFG+=("${EXTRA_BUILD_CFG[@]}")

if [[ "$ARCH" == "x86_64" ]]; then
  # Check if nasm exists on the host
  if command -v nasm &> /dev/null; then
    echo "INFO: Detected NASM. FFmpeg will try to use it for x86 assembly optimization."
    # If configure reports "nasm is too old", user needs to manually update NASM on the host
  else
    echo "INFO: NASM not detected on the host."
    echo "INFO: Will disable x86 assembly optimization (--disable-x86asm). The compiled output may be slightly larger and performance may be slightly worse."
    COMMON_CFG+=(--disable-x86asm)
  fi
fi

if [[ "$ARCH" == "x86" ]]; then
  # Disable x86 assembly optimization for Android NDK
  # Reason: Clang in Android NDK does not support inline assembly with so many registers
  echo "INFO: Disabling x86 assembly optimization (--disable-asm) due to limited register support in Android NDK's Clang."
  COMMON_CFG+=(--disable-asm)
fi

echo "=== Start configuring FFmpeg [$ARCH] ==="
PKG_CONFIG_PATH="$DEPS_INSTALL/lib/pkgconfig" \
./configure "${COMMON_CFG[@]}"

echo "=== Start compiling (parallel $CPU_COUNT) ==="
if [[ "$*" == *"--show-error"* ]]; then
  make -j"$CPU_COUNT" || exit 1
else
  make -j"$CPU_COUNT" > /dev/null 2>&1 || {
    echo "Compilation failed. Use --show-error to see detailed output."
    exit 1
  }
fi

echo "=== Install to $PREFIX ==="
if [[ "$*" == *"--show-error"* ]]; then
  make install || exit 1
else
  make install > /dev/null 2>&1 || {
    echo "Installation failed. Use --show-error to see detailed output."
    exit 1
  }
fi

echo "Static libraries (*.a) and headers have been installed to: $PREFIX"

if [[ "$*" == *"--enable-merged-shared"* || "$*" == *"--enable-dynamic-program"* ]]; then
  echo "=== Linking static libraries into libffmpeg.so ==="
  LIBS_DIR="$PREFIX/lib"
  OUT_SO="$PREFIX/lib/libffmpeg.so"

  $CC \
    -shared \
    -o "$OUT_SO" \
    -Wl,--whole-archive \
      "$LIBS_DIR/libavcodec.a" \
      "$LIBS_DIR/libavfilter.a" \
      "$LIBS_DIR/libavformat.a" \
      "$LIBS_DIR/libswresample.a" \
      "$LIBS_DIR/libswscale.a" \
      "$LIBS_DIR/libavutil.a" \
    -Wl,--no-whole-archive \
      "$DEPS_INSTALL/lib/libaom.a" \
      "$DEPS_INSTALL/lib/libmp3lame.a" \
    -Wl,--gc-sections \
    -Wl,--allow-multiple-definition \
    -Wl,-Bsymbolic \
    -lm -lz -pthread

  [[ -f "$OUT_SO" ]] && echo "libffmpeg.so created at: $OUT_SO" || {
    echo "Failed to create libffmpeg.so" >&2
    exit 1
  }
  $STRIP --strip-unneeded $OUT_SO
fi

if [[ "$*" == *"--enable-dynamic-program"* ]]; then
  

  FFMPEG_OBJS=(
    "fftools/ffmpeg_dec.o"
    "fftools/ffmpeg_demux.o"
    "fftools/ffmpeg_enc.o"
    "fftools/ffmpeg_filter.o"
    "fftools/ffmpeg_hw.o"
    "fftools/ffmpeg_mux.o"
    "fftools/ffmpeg_mux_init.o"
    "fftools/ffmpeg_opt.o"
    "fftools/ffmpeg_sched.o"
    "fftools/objpool.o"
    "fftools/sync_queue.o"
    "fftools/thread_queue.o"
    "fftools/cmdutils.o"
    "fftools/opt_common.o"
    "fftools/ffmpeg.o"
  )

  echo "=== Create ffmpeg-dynamic  ==="
  # Create ffmpeg executable
  $CC \
    "${FFMPEG_OBJS[@]}" \
    -o "$PREFIX/bin/ffmpeg-dynamic" \
    -L"$LIBS_DIR" \
    -lm -lz -lffmpeg -pthread

  [[ -f "$PREFIX/bin/ffmpeg-dynamic" ]] && echo "ffmpeg executable created at: $PREFIX/bin/ffmpeg-dynamic" || {
    echo "Failed to create ffmpeg executable" >&2
    exit 1
  }
fi

# Calculate SHA512 hashes for all files
echo "=== Calculating SHA512 hashes ==="
cd "$PREFIX"
find . -type f -exec sha512sum {} \; | sed 's|^\([^ ]*\)  \./|\1 |' > hash.txt
echo "Hash file created at: $PREFIX/hash.txt"

# Create tgz archive
echo "=== Creating tgz archive ==="
ARCHIVE_NAME="ffmpeg_android_${TARGET_ARCH}.tar.gz"
if [[ "$*" == *"--small-build"*  ]]; then
  ARCHIVE_NAME="ffmpeg_android_${TARGET_ARCH}_mini.tar.gz"
fi
cd "$(dirname "$PREFIX")"
tar -czf "$PROJECT_ROOT/$ARCHIVE_NAME" "$(basename "$PREFIX")"
echo "Archive created: $ARCHIVE_NAME"
