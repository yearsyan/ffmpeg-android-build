#!/usr/bin/env bash

function ffmpeg_config_processor() {
  local -n build_config_arr=$1
  local base_config=()
  local env_configs=()
  
  # Adjust configuration based on environment variables
  if [[ "${ENABLE_DAV1D:-0}" == "1" ]]; then
    env_configs+=(
      --enable-libdav1d
      --enable-decoder=libdav1d
    )
  fi

  if [[ "${ENABLE_AOM_ENCODER:-0}" == "1" ]]; then
    env_configs+=(
      --enable-libaom
      --enable-encoder=libaom_av1
    )
  else
    env_configs+=(
      --disable-encoder=libaom_av1
    )
  fi

  if [[ "${ENABLE_AOM_DECODER:-0}" == "1" ]]; then
    env_configs+=(
      --enable-libaom
      --enable-decoder=libaom_av1
    )
  else
    env_configs+=(
      --disable-decoder=libaom_av1
    )
  fi

  if [[ "${ENABLE_MP3LAME:-0}" == "1" ]]; then
    env_configs+=(
      --enable-libmp3lame
      --enable-encoder=libmp3lame
    )
  fi

  # Add configurations from EXTRA_BUILD_CFG first
  base_config+=("${EXTRA_BUILD_CFG[@]}")

  # Add basic configuration
  base_config+=(
    --disable-avdevice
    --enable-protocol=file
    --enable-filter=aformat
    --enable-filter=scale
  )

  # Simply append env_configs to base_config
  # FFmpeg configure will handle any conflicts (later options override earlier ones)
  build_config_arr+=("${base_config[@]}")
  build_config_arr+=("${env_configs[@]}")
}