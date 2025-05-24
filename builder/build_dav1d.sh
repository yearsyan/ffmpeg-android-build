#!/usr/bin/env bash

DAV1D_BUILD=$PROJECT_ROOT/$BUILD_DIR_NMAE/dav1d_build_android_$TARGET_ARCH

if [ -f "$DAV1D_PREFIX/lib/libdav1d.a" ]; then
  echo "libdav1d.a already exists at $DAV1D_PREFIX/lib/libdav1d.a, skipping build..."
  exit 0
fi

generate_cross_file() {
  local arch="$1"
  local output_dir="$2"
  local ndk_toolchain="$NDK_TOOLCHAIN"
  local api_level=$ANDROID_API_LEVEL
  local triple=""
  local cpu_family=""
  local cpu=""
  case "$arch" in
    "aarch64")
      triple="aarch64-linux-android"
      cpu_family="aarch64"
      cpu="armv8-a"
      ;;
    "armv7a")
      triple="armv7a-linux-androideabi"
      cpu_family="arm"
      cpu="armv7-a"
      ;;
    "x86")
      triple="i686-linux-android"
      cpu_family="x86"
      cpu="i686"
      ;;
    "x86_64")
      triple="x86_64-linux-android"
      cpu_family="x86_64"
      cpu="x86_64"
      ;;
    *)
      echo "Unsupported arch: $arch"
      return 1
      ;;
  esac

  # Construct toolchain path
  local clang="${ndk_toolchain}/bin/${triple}${api_level}-clang"
  local clangpp="${clang}++"
  local ar="${ndk_toolchain}/bin/llvm-ar"
  local strip="${ndk_toolchain}/bin/llvm-strip"

  # Output cross-file path
  local cross_file="${output_dir}/android-${arch}.txt"
  mkdir -p "$output_dir"

  # Write cross-file content
  cat > "$cross_file" <<EOF
[binaries]
c = '${clang}'
cpp = '${clangpp}'
ar = '${ar}'
strip = '${strip}'

[host_machine]
system = 'android'
cpu_family = '${cpu_family}'
cpu = '${cpu}'
endian = 'little'
EOF

  echo "Generated cross file: $cross_file"
}

rm -rf $DAV1D_BUILD
mkdir -p $DAV1D_BUILD

cd $PROJECT_ROOT/dav1d
generate_cross_file "$ARCH" "$PROJECT_ROOT/$BUILD_DIR_NMAE"
meson setup "$DAV1D_BUILD" --buildtype release --cross-file "$PROJECT_ROOT/$BUILD_DIR_NMAE/android-$ARCH.txt"  --default-library=static -Denable_tools=false -Denable_tests=false -Dprefix="$DAV1D_PREFIX"
ninja -C $DAV1D_BUILD install
$NDK_TOOLCHAIN/bin/llvm-strip --strip-unneeded "$DAV1D_PREFIX/lib/libdav1d.a"