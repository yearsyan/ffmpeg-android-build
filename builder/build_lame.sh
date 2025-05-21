#!/bin/bash
set -e

NDK="${ANDROID_NDK:-}"
API=21
PREFIX=$LAME_PREFIX

if [ -f "$LAME_PREFIX/lib/libmp3lame.a" ]; then
  echo "libmp3lame.a exist. Pass"
  exit 0
fi

export CC=$NDK_TOOLCHAIN/bin/${TRIPLE}${API}-clang

cd "$PROJECT_ROOT/libmp3lame"

if [ -f Makefile ]; then
  make clean
fi

./configure \
  --host=$TRIPLE \
  --disable-shared \
  --enable-static \
  --disable-frontend \
  --prefix=$PREFIX

make -j$(nproc)
make install
