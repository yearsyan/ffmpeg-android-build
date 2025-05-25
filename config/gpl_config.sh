#!/usr/bin/env bash

export ENABLE_AOM_DECODER=1
export ENABLE_AOM_ENCODER=1
export ENABLE_X264=1
export ENABLE_X265=0


# Basic configuration
EXTRA_BUILD_CFG=(
  --enable-gpl
  --disable-avdevice
  --enable-protocol=file
  --enable-filter=aformat
  --enable-filter=scale
)