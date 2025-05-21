#!/usr/bin/env bash
EXTRA_BUILD_CFG=(
  --disable-avdevice
  --enable-protocol=file
  --enable-filter=aformat
  --enable-filter=scale
  --enable-libaom
  --enable-libmp3lame
  --enable-encoder=libaom_av1
  --enable-decoder=libaom_av1
  --enable-encoder=libmp3lame
)