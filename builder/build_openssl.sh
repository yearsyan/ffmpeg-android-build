#!/usr/bin/env bash
set -e

# =============================================================================
# Script: build_openssl.sh
# Purpose: Cross-compile OpenSSL (shared) for Android.
#          Expected to be invoked from build_ffmpeg.sh with the cross
#          environment already set up (PROJECT_ROOT, ARCH, TARGET_ARCH,
#          ANDROID_API_LEVEL, CPU_COUNT, NDK_TOOLCHAIN, BUILD_DIR_NMAE).
#
# The OpenSSL source tree is expected at $PROJECT_ROOT/openssl. If it is
# missing, the pinned release tarball is downloaded and verified.
# =============================================================================

OPENSSL_VERSION="3.5.5"
OPENSSL_SHA256="b28c91532a8b65a1f983b4c28b7488174e4a01008e29ce8e69bd789f28bc2a89"
OPENSSL_TARBALL="openssl-${OPENSSL_VERSION}.tar.gz"
OPENSSL_URL="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/${OPENSSL_TARBALL}"

OPENSSL_SRC="$PROJECT_ROOT/openssl"
OPENSSL_PREFIX="${OPENSSL_PREFIX:-$PROJECT_ROOT/$BUILD_DIR_NMAE/ffmpeg_android_dep_${TARGET_ARCH}}"

if [ -f "$OPENSSL_PREFIX/lib/libssl.so" ] && [ -f "$OPENSSL_PREFIX/lib/libcrypto.so" ]; then
  echo "libssl.so/libcrypto.so already exist at $OPENSSL_PREFIX/lib, skipping build..."
  exit 0
fi

# Fetch the source if it is not checked out (kept out of git on purpose,
# the pinned tarball is downloaded on demand, e.g. by CI).
if [ ! -f "$OPENSSL_SRC/Configure" ]; then
  echo "OpenSSL source not found, downloading $OPENSSL_URL ..."
  TMP_TARBALL="$(mktemp -d)/$OPENSSL_TARBALL"
  curl -fL --retry 3 -o "$TMP_TARBALL" "$OPENSSL_URL"
  echo "$OPENSSL_SHA256  $TMP_TARBALL" | sha256sum -c -
  rm -rf "$OPENSSL_SRC"
  mkdir -p "$OPENSSL_SRC"
  tar xzf "$TMP_TARBALL" -C "$OPENSSL_SRC" --strip-components=1
  rm -f "$TMP_TARBALL"
fi

case "$ARCH" in
  aarch64) OPENSSL_TARGET="android-arm64" ;;
  armv7a)  OPENSSL_TARGET="android-arm" ;;
  x86)     OPENSSL_TARGET="android-x86" ;;
  x86_64)  OPENSSL_TARGET="android-x86_64" ;;
  *)
    echo "Error: Unsupported architecture '$ARCH' for OpenSSL" >&2
    exit 1
    ;;
esac

# OpenSSL's android targets locate the NDK through $ANDROID_NDK_ROOT and
# expect the LLVM toolchain bin directory on PATH. Always pin ANDROID_NDK_ROOT
# to *this* NDK: CI images may pre-set ANDROID_NDK_ROOT to a different
# (image-default) NDK, and OpenSSL then fails with "no NDK ...-gcc on $PATH"
# because its clang sanity check matches against the wrong NDK path.
if [[ -z "${ANDROID_NDK:-}" ]]; then
  echo "Error: ANDROID_NDK is not set" >&2
  exit 1
fi
export ANDROID_NDK_ROOT="${ANDROID_NDK%/}"
export PATH="$NDK_TOOLCHAIN/bin:$PATH"

OPENSSL_BUILD="$PROJECT_ROOT/$BUILD_DIR_NMAE/openssl_build_android_$TARGET_ARCH"
rm -rf "$OPENSSL_BUILD"
mkdir -p "$OPENSSL_BUILD"

cd "$OPENSSL_BUILD"
"$OPENSSL_SRC/Configure" "$OPENSSL_TARGET" \
  -D__ANDROID_API__="$ANDROID_API_LEVEL" \
  shared \
  no-tests \
  --prefix="$OPENSSL_PREFIX"

make -j"$CPU_COUNT" build_libs
make install_sw

echo "OpenSSL installed to: $OPENSSL_PREFIX"
ls -la "$OPENSSL_PREFIX/lib/"libssl.so* "$OPENSSL_PREFIX/lib/"libcrypto.so*
