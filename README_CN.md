# FFmpeg Android 构建项目

[English Documentation](./README.md)

这是一个用于交叉编译Android版FFmpeg的项目。该项目提供了多种配置和架构的FFmpeg构建脚本。

## 特性

- 支持多种Android架构：
  - aarch64 (arm64-v8a)
  - armv7a (armeabi-v7a)
  - x86
  - x86_64
- 多种构建配置：
  - 标准构建：完整的FFmpeg功能，仅最小限制
    - 启用所有编解码器和格式
    - 额外编解码器支持：
      - dav1d：高性能AV1解码器
      - aom：AV1编码器/解码器
      - mp3lame：高质量MP3编码器
  - 精简构建：针对常见使用场景优化，包含必要的编解码器和格式：
    - 视频编解码器：H.264、HEVC、VP8、VP9、AV1（通过dav1d）
    - 音频编解码器：AAC、AC3、MP3（通过mp3lame）、Opus、FLAC
    - 容器格式：MP4、MKV、MOV、FLV、WebM、ADTS、OGG、WAV
    - 基础功能：文件协议、zlib支持
    - 额外编解码器支持：
      - dav1d：高性能AV1解码器
      - aom：仅AV1编码器
      - mp3lame：高质量MP3编码器
  - GPL构建：包含标准构建的所有功能，并额外支持：
    - x264：H.264编码器
    - x265：HEVC编码器
- 可选功能：
  - 动态程序支持
  - 共享库支持
  - 合并共享库支持

## 前置要求

- Android NDK（必须通过ANDROID_NDK环境变量设置）
- Bash shell
- 基本构建工具（make, tar等）
- x86_64构建：NASM（可选，用于汇编优化）

## 使用方法

### 基本构建

```bash
# 设置Android NDK路径
export ANDROID_NDK=/path/to/android-ndk

# 构建所有架构
./builder/build_all.sh

# 或构建特定架构
./builder/build_ffmpeg.sh --arch=aarch64
```

### 构建选项

- `--arch=ARCH`：目标架构（默认：aarch64）
  - 支持：aarch64, armv7a, x86, x86_64
- `--config=CONFIG`：构建配置（默认：standard）
  - 支持：standard, mini, gpl
- `--enable-shared`：构建共享库
- `--enable-merged-shared`：将所有静态库链接到单个共享库中
- `--enable-dynamic-program`：构建动态链接的FFmpeg可执行文件

### 输出

构建过程会生成：
- 静态库（*.a）
- 头文件
- 可选的共享库（libffmpeg.so）
- 可选的动态FFmpeg可执行文件
- SHA512哈希文件
- 压缩归档文件（.tar.gz）

所有架构和配置的构建产物都可以在 [Releases](https://github.com/yearsyan/ffmpeg-android-build/releases) 页面下载。每个发布版本都包含所有支持架构的标准版和精简版配置。 