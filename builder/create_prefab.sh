#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Script: create_prefab.sh
# Purpose: Create Android Prefab package from FFmpeg build output for all architectures
# Usage: ./create_prefab.sh [--config=CONFIG]
# Options:
#   --config=CONFIG      Build configuration (default: standard)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")" && pwd)"
export PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")/.." && pwd)

# Get version from git tag
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
VERSION=${VERSION#v} # Remove 'v' prefix if present

# Extract NDK version from ANDROID_NDK path
NDK_VERSION=$(echo $ANDROID_NDK | grep -o 'r[0-9]*' | sed 's/r//')
if [ -z "$NDK_VERSION" ]; then
  NDK_VERSION=28  # Default to 28 if not found
fi

# Read configuration from arguments
export BUILD_CONFIG_NAME="standard"
export BUILD_SUFFIX=""
for arg in "$@"; do
  case $arg in
    --config=*)
      BUILD_CONFIG_NAME="${arg#*=}"
      if [[ "$BUILD_CONFIG_NAME" != "standard" ]]; then
        BUILD_SUFFIX="_$BUILD_CONFIG_NAME"
      fi
      ;;
  esac
done

# Supported architectures
ARCHS=("aarch64" "armv7a" "x86" "x86_64")

# Architecture mapping
declare -A ARCH_MAP
ARCH_MAP["aarch64"]="arm64-v8a"
ARCH_MAP["armv7a"]="armeabi-v7a"
ARCH_MAP["x86"]="x86"
ARCH_MAP["x86_64"]="x86_64"

export BUILD_DIR_NAME="build"
BUILD_DIST="$PROJECT_ROOT/$BUILD_DIR_NAME"
PREFAB_WORK_DIR="$BUILD_DIST/prefab-work"
PREFAB_TEMPLATE_DIR="$PROJECT_ROOT/prefab-template"

echo "=== Creating Prefab package for config: $BUILD_CONFIG_NAME (version: $VERSION) ==="

# Clean and create working directory
rm -rf "$PREFAB_WORK_DIR"
mkdir -p "$PREFAB_WORK_DIR"

# Copy prefab template structure
cp -r "$PREFAB_TEMPLATE_DIR/"* "$PREFAB_WORK_DIR/"

# Create aar-metadata.properties file
mkdir -p "$PREFAB_WORK_DIR/META-INF/com/android/build/gradle"
cat > "$PREFAB_WORK_DIR/META-INF/com/android/build/gradle/aar-metadata.properties" << EOF
aarFormatVersion=1.0
aarMetadataVersion=1.0
minCompileSdk=1
minCompileSdkExtension=0
minAndroidGradlePluginVersion=1.0.0
coreLibraryDesugaringEnabled=false
EOF

# Update version in module.json
MODULE_JSON="$PREFAB_WORK_DIR/prefab/modules/ffmpeg/module.json"
if [[ -f "$MODULE_JSON" ]]; then
  sed -i "s/\"version\": \".*\"/\"version\": \"$VERSION\"/" "$MODULE_JSON"
fi

# Process each architecture
for arch in "${ARCHS[@]}"; do
  TARGET_ARCH="$arch"
  if [[ "$arch" == "armv7a" ]]; then
    TARGET_ARCH="arm"
  fi
  
  ANDROID_ABI="${ARCH_MAP[$arch]}"
  FFMPEG_BUILD_DIR="$BUILD_DIST/ffmpeg_android_${TARGET_ARCH}${BUILD_SUFFIX}"
  
  echo "Processing architecture: $arch ($ANDROID_ABI)"
  
  # Check if build exists
  if [[ ! -d "$FFMPEG_BUILD_DIR" ]]; then
    echo "Warning: Build directory not found for $arch: $FFMPEG_BUILD_DIR"
    continue
  fi
  
  # Create architecture-specific directories
  PREFAB_LIB_DIR="$PREFAB_WORK_DIR/prefab/modules/ffmpeg/libs/android.$ANDROID_ABI"
  JNI_LIB_DIR="$PREFAB_WORK_DIR/jni/$ANDROID_ABI"
  PREFAB_INCLUDE_DIR="$PREFAB_LIB_DIR/include"
  
  mkdir -p "$PREFAB_LIB_DIR"
  mkdir -p "$JNI_LIB_DIR"
  mkdir -p "$PREFAB_INCLUDE_DIR"
  
  # Generate abi.json for this architecture
  cat > "$PREFAB_LIB_DIR/abi.json" << EOF
{
  "abi": "$ANDROID_ABI",
  "api": 24,
  "ndk": $NDK_VERSION,
  "stl": "none",
  "static": false
}
EOF
  
  # Copy shared library if exists
  if [[ -f "$FFMPEG_BUILD_DIR/lib/libffmpeg.so" ]]; then
    # Copy to both prefab libs and jni directories
    cp "$FFMPEG_BUILD_DIR/lib/libffmpeg.so" "$PREFAB_LIB_DIR/"
    # cp "$FFMPEG_BUILD_DIR/lib/libffmpeg.so" "$JNI_LIB_DIR/"
    echo "  Copied libffmpeg.so for $ANDROID_ABI"
  else
    echo "  Warning: libffmpeg.so not found for $ANDROID_ABI"
  fi

  if [[ -f "$FFMPEG_BUILD_DIR/bin/ffmpeg-dynamic" ]]; then
    cp "$FFMPEG_BUILD_DIR/bin/ffmpeg-dynamic" "$JNI_LIB_DIR/libffmpegexe.so"
    echo "  Copied ffmpegexe for $ANDROID_ABI"
  fi
  
  # Copy headers to architecture-specific include directory
  if [[ -d "$FFMPEG_BUILD_DIR/include" ]]; then
    cp -r "$FFMPEG_BUILD_DIR/include/"* "$PREFAB_INCLUDE_DIR/"
    echo "  Copied headers for $ANDROID_ABI"
  else
    echo "  Warning: Headers not found for $ANDROID_ABI"
  fi
done

# Create AAR package
cd "$PREFAB_WORK_DIR"
AAR_NAME="ffmpeg${BUILD_SUFFIX}-${VERSION}.aar"
zip -9 -r "$BUILD_DIST/$AAR_NAME" .

echo "Prefab AAR package created at: $BUILD_DIST/$AAR_NAME"

# Create a summary
echo ""
echo "=== Prefab Package Summary ==="
echo "Configuration: $BUILD_CONFIG_NAME"
echo "Version: $VERSION"
echo "Package: $BUILD_DIST/$AAR_NAME"
echo "Included architectures:"
for arch in "${ARCHS[@]}"; do
  TARGET_ARCH="$arch"
  if [[ "$arch" == "armv7a" ]]; then
    TARGET_ARCH="arm"
  fi
  
  ANDROID_ABI="${ARCH_MAP[$arch]}"
  FFMPEG_BUILD_DIR="$BUILD_DIST/ffmpeg_android_${TARGET_ARCH}${BUILD_SUFFIX}"
  
  if [[ -d "$FFMPEG_BUILD_DIR" ]]; then
    echo "  ✓ $ANDROID_ABI"
  else
    echo "  ✗ $ANDROID_ABI (build not found)"
  fi
done 