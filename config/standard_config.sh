#!/usr/bin/env bash

# Basic configuration
EXTRA_BUILD_CFG=(
  --disable-avdevice
  --enable-protocol=file
  --enable-filter=aformat
  --enable-filter=scale
)