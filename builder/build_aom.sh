#!/usr/bin/env bash
set -e

NDK="${ANDROID_NDK:-}"
API=21
AOM_SRC=$PROJECT_ROOT/libaom
AOM_BUILD=$PROJECT_ROOT/$BUILD_DIR_NMAE/aom_build_android_$TARGET_ARCH

if [ -f "$AOM_INSTALL/lib/libaom.a" ]; then
  echo "libaom.a exist. Pass"
  exit 0
fi

rm -rf "$AOM_BUILD" "$AOM_INSTALL"
mkdir -p "$AOM_BUILD" "$AOM_INSTALL"

cd "$AOM_BUILD"

# aom arguments
CMAKE_ARGS=(
  "$AOM_SRC"
  "-DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake"
  "-DANDROID_ABI=${ANDROID_ABI}"
  "-DANDROID_PLATFORM=android-${API}"
  "-DCONFIG_SVT_AV1=0"
  "-DCONFIG_AV1_DECODER=0"
  "-DCMAKE_BUILD_TYPE=Release"
  "-DBUILD_SHARED_LIBS=OFF"
  "-DCONFIG_DENOISE=0"
  "-DCONFIG_QUANT_MATRIX=0"
  "-DCONFIG_WEBM_IO=0"
  "-DCONFIG_LIBYUV=0"
  "-DCONFIG_INTERNAL_STATS=0"
  "-DENABLE_TESTS=OFF"
  "-DENABLE_DOCS=OFF"
  "-DENABLE_EXAMPLES=OFF"
  "-DCONFIG_AV1_HIGHBITDEPTH=0"
  "-DCONFIG_RUNTIME_CPU_DETECT=0"
  "-DCMAKE_C_FLAGS=-ffunction-sections -fdata-sections"
  "-DCONFIG_INSPECTION=0"
  "-DCMAKE_EXE_LINKER_FLAGS=-Wl,--gc-sections"
  "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--gc-sections"
  "-DCMAKE_C_FLAGS_RELEASE=-Os -DNDEBUG"
  "-DCMAKE_C_FLAGS_DEBUG=-Os -DNDEBUG"
  "-DCMAKE_INSTALL_PREFIX=$AOM_INSTALL"
)

if [[ $TARGET_CPU != "x86-64" ]]; then
  CMAKE_ARGS+=(
    "-DAOM_TARGET_CPU=$TARGET_CPU"
  )
fi


cmake "${CMAKE_ARGS[@]}"
cmake --build . --config Release --target install -- -j$(nproc)
$NDK_TOOLCHAIN/bin/llvm-strip --strip-unneeded "$AOM_INSTALL/lib/libaom.a"