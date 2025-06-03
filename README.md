# FFmpeg Android Build

[中文文档](./README_CN.md)

A cross-compilation project for building FFmpeg for Android platforms. This project provides scripts to build FFmpeg with various configurations and architectures.

## Features

- Supports multiple Android architectures:
  - aarch64 (arm64-v8a)
  - armv7a (armeabi-v7a)
  - x86
  - x86_64
- Multiple build configurations:
  - Standard build: Full FFmpeg features with minimal restrictions
    - All codecs and formats enabled
    - Additional codec support:
      - dav1d: High-performance AV1 decoder
      - aom: AV1 encoder/decoder
      - mp3lame: High-quality MP3 encoder
  - Mini build: Optimized for common use cases with essential codecs and formats:
    - Video codecs: H.264, HEVC, VP8, VP9, AV1 (via dav1d)
    - Audio codecs: AAC, AC3, MP3 (via mp3lame), Opus, FLAC
    - Container formats: MP4, MKV, MOV, FLV, WebM, ADTS, OGG, WAV
    - Basic features: file protocol, zlib support
    - Additional codec support:
      - dav1d: High-performance AV1 decoder
      - aom: AV1 encoder only
      - mp3lame: High-quality MP3 encoder
  - GPL build: Includes all features from standard build plus:
    - x264: H.264 encoder
    - x265: HEVC encoder
- Optional features:
  - Dynamic program support
  - Shared library support
  - Merged shared library support

## Prerequisites

- Android NDK (must be set via ANDROID_NDK environment variable)
- Bash shell
- Basic build tools (make, tar, etc.)
- For x86_64 builds: NASM (optional, for assembly optimization)

## Usage

### Basic Build

```bash
# Set Android NDK path
export ANDROID_NDK=/path/to/android-ndk

# Build for all architectures
./builder/build_all.sh

# Or build for specific architecture
./builder/build_ffmpeg.sh --arch=aarch64
```

### Build Options

- `--arch=ARCH`: Target architecture (default: aarch64)
  - Supported: aarch64, armv7a, x86, x86_64
- `--config=CONFIG`: Build configuration (default: standard)
  - Supported: standard, mini, gpl
- `--enable-shared`: Build shared libraries
- `--enable-merged-shared`: Link all static libraries into a single shared library
- `--enable-dynamic-program`: Build FFmpeg executable with dynamic linking

### Output

The build process creates:
- Static libraries (*.a)
- Headers
- Optional shared library (libffmpeg.so)
- Optional dynamic FFmpeg executable
- SHA512 hash file
- Compressed archive (.tar.gz)

Build artifacts for all architectures and configurations are available in the [Releases](https://github.com/yearsyan/ffmpeg-android-build/releases) section. Each release includes both standard and mini configurations for all supported architectures. 

## Library Usage

### 1. Add dependency in build.gradle

The library is published on Maven Central and uses Prefab package format for native dependencies, which is supported by Android Gradle Plugin 4.0+.

```gradle
android {
    buildFeatures {
        prefab true
    }
}

dependencies {
    // For mini build
    implementation 'io.github.yearsyan:ffmpeg-mini:7.1-alpha.10'
    // Or for standard build
    implementation 'io.github.yearsyan:ffmpeg-standard:7.1-alpha.10'
}
```

Note: The library uses the prefab package schema v2, which is configured by default since Android Gradle Plugin 7.1.0. If you are using Android Gradle Plugin earlier than 7.1.0, please add the following configuration to gradle.properties:

```properties
android.prefabVersion=2.0.0
```

### 2. Add dependency in CMakeLists.txt or Android.mk

CMakeLists.txt:
```cmake
find_package(ffmpeg REQUIRED CONFIG)

add_library(mylib SHARED mylib.c)
target_link_libraries(mylib ffmpeg::ffmpeg)
```

Android.mk:
```makefile
include $(CLEAR_VARS)
LOCAL_MODULE           := mylib
LOCAL_SRC_FILES        := mylib.c
LOCAL_SHARED_LIBRARIES += ffmpeg
include $(BUILD_SHARED_LIBRARY)

$(call import-module,prefab/ffmpeg)
```

### Additional Notes

- GPL version is not available on Maven Central. You can download it directly from [GitHub Releases](https://github.com/yearsyan/ffmpeg-android-build/releases).
- If you need to customize build parameters, you can fork this repository and modify the build configuration according to your needs. 