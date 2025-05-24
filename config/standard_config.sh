#!/usr/bin/env bash

export ENABLE_AOM_DECODER=1

# Basic configuration
EXTRA_BUILD_CFG=(
  --disable-avdevice
  --enable-protocol=file
  --enable-filter=aformat
  --enable-filter=scale
)