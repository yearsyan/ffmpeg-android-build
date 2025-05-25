#!/usr/bin/env bash
set -e

X265_BUILD=$PROJECT_ROOT/$BUILD_DIR_NMAE/x265_build_android_$TARGET_ARCH
X265_INSTALL=$X265_PREFIX
NDK="${ANDROID_NDK:-}"

if [ -f "$X265_INSTALL/lib/libx265.a" ]; then
  echo "libx265.a already exists at $X265_INSTALL/lib/libx265.a, skipping build..."
  exit 0
fi

rm -rf "$X265_BUILD"
mkdir -p "$X265_BUILD"

cd "$X265_BUILD"

# x265 arguments
CMAKE_ARGS=(
  "$PROJECT_ROOT/x265/source"
  "-DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake"
  "-DANDROID_PLATFORM=android-${ANDROID_API_LEVEL}"
  "-DCMAKE_ANDROID_ARCH_ABI=${ANDROID_ABI}"
  "-DENABLE_SHARED=OFF"
  "-DENABLE_CLI=OFF"
  "-DENABLE_TESTS=OFF"
  "-DENABLE_PIC=ON"
  "-DCMAKE_BUILD_TYPE=Release"
  "-DCMAKE_C_FLAGS=-ffunction-sections -fdata-sections"
  "-DCMAKE_CXX_FLAGS=-ffunction-sections -fdata-sections"
  "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  "-DCMAKE_INSTALL_PREFIX=$X265_INSTALL"
  "-DENABLE_LIBNUMA=OFF"
  "-DENABLE_LIBUNWIND=OFF"
)

$CMAKE "${CMAKE_ARGS[@]}"
$CMAKE --build . --config Release --target install -- -j$(nproc)
$NDK_TOOLCHAIN/bin/llvm-strip --strip-unneeded "$X265_INSTALL/lib/libx265.a"

# Function to update x265.pc
update_pkgconfig() {
  local pc_file="$X265_INSTALL/lib/pkgconfig/x265.pc"
  if [ -f "$pc_file" ]; then
    # Remove -l-l:libunwind.a from Libs.private
    sed -i 's/-l-l:libunwind\.a//g' "$pc_file"
    
    if ! grep -q "Libs.private:.*-lpthread" "$pc_file"; then
      sed -i '/^Libs.private:/ s/$/ -lpthread/' "$pc_file"
      echo "Added -lpthread to Libs.private in $pc_file"
    else
      echo "-lpthread already present in Libs.private"
    fi
    
    # Clean up multiple spaces that might have been created
    sed -i 's/  */ /g' "$pc_file"
    echo "Removed -l-l:libunwind.a from $pc_file"
  else
    echo "pkg-config file $pc_file not found!"
  fi
}

# Call the function after build
update_pkgconfig