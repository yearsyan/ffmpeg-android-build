#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Script: build_all.sh
# Purpose: Build FFmpeg for all supported architectures
# =============================================================================

# Get the absolute path of the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check ANDROID_NDK environment variable
if [[ -z "${ANDROID_NDK:-}" ]]; then
  echo "Error: ANDROID_NDK is not set, please run export ANDROID_NDK=/path/to/android-ndk first" >&2
  exit 1
fi

# List of supported architectures
ARCHS=(
  "aarch64"
  "armv7a"
  "x86"
  "x86_64"
)

# Common build arguments
BUILD_ARGS=(
  "--enable-dynamic-program"
)

# Build for each architecture
for arch in "${ARCHS[@]}"; do
  echo "Building for architecture: ${arch}"
  "${SCRIPT_DIR}/build_ffmpeg.sh" "${BUILD_ARGS[@]}" --arch="${arch}"
  "${SCRIPT_DIR}/build_ffmpeg.sh" "${BUILD_ARGS[@]}" --arch="${arch}" --config="mini"
  "${SCRIPT_DIR}/build_ffmpeg.sh" "${BUILD_ARGS[@]}" --arch="${arch}" --config="gpl"
  "${SCRIPT_DIR}/build_ffmpeg.sh" "${BUILD_ARGS[@]}" --arch="${arch}" --config="tiny"
done

echo "=== All architectures built successfully ==="

# Create Prefab packages for each configuration
echo "=== Creating Prefab packages ==="
"${SCRIPT_DIR}/create_prefab.sh" --config="standard"
"${SCRIPT_DIR}/create_prefab.sh" --config="mini"
"${SCRIPT_DIR}/create_prefab.sh" --config="gpl"
"${SCRIPT_DIR}/create_prefab.sh" --config="tiny"
echo "=== Build and packaging completed ==="