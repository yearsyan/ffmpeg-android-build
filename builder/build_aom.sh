#!/usr/bin/env bash
set -e

NDK="${ANDROID_NDK:-}"
AOM_SRC=$PROJECT_ROOT/libaom
AOM_BUILD=$PROJECT_ROOT/$BUILD_DIR_NMAE/aom_build_android_$TARGET_ARCH


rm -rf "$AOM_BUILD"
mkdir -p "$AOM_BUILD"

cd "$AOM_BUILD"

# aom arguments
CMAKE_ARGS=(
  "$AOM_SRC"
  "-DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake"
  "-DANDROID_ABI=${ANDROID_ABI}"
  "-DANDROID_PLATFORM=android-${ANDROID_API_LEVEL}"
  "-DCONFIG_SVT_AV1=0"
  "-DCONFIG_AV1_DECODER=${ENABLE_AOM_DECODER:0}"
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
  # Prefer nasm (bootstrapped by setup_nasm.sh): the yasm bundled in the NDK
  # prebuilt dir is an x86_64-only binary and cannot run on Apple Silicon.
  "-DENABLE_NASM=ON"
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

# The NDK legacy toolchain file hardcodes CMAKE_ASM_NASM_COMPILER to the yasm
# bundled with the NDK for x86 ABIs. That yasm is an x86_64-only binary and
# fails on Apple Silicon hosts without Rosetta ("Bad CPU type in executable"),
# and aom's ENABLE_NASM cannot override it: find_program() skips the search
# when the variable is already set. When a host nasm was bootstrapped, force
# it after the toolchain runs via CMAKE_PROJECT_INCLUDE.
if [[ -x "$PROJECT_ROOT/tools/bin/nasm" ]]; then
  cat > "$AOM_BUILD/asm_nasm_override.cmake" <<EOF
set(CMAKE_ASM_NASM_COMPILER "$PROJECT_ROOT/tools/bin/nasm")
EOF
  CMAKE_ARGS+=("-DCMAKE_PROJECT_INCLUDE=$AOM_BUILD/asm_nasm_override.cmake")
fi


$CMAKE "${CMAKE_ARGS[@]}"
$CMAKE --build . --config Release --target install -- -j$(nproc)
$NDK_TOOLCHAIN/bin/llvm-strip --strip-unneeded "$AOM_INSTALL/lib/libaom.a"