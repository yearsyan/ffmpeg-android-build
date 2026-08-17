#!/usr/bin/env bash

# ssl configuration: everything from the standard build plus TLS support
# (https://, tls://, rtsps:// ...) via OpenSSL shared libraries.

export ENABLE_AOM_DECODER=1
export ENABLE_AOM_ENCODER=1
export ENABLE_OPENSSL=1

# Basic configuration (mirrors standard_config.sh)
EXTRA_BUILD_CFG=(
  --disable-avdevice
  --enable-protocol=file
  --enable-filter=aformat
  --enable-filter=scale
)
