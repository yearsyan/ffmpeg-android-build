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
  - Supported: standard, mini
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