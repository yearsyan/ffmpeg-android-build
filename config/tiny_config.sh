#!/usr/bin/env bash

export ENABLE_DAV1D=0
export ENABLE_AOM_ENCODER=0
export ENABLE_AOM_DECODER=0
export ENABLE_MP3LAME=0
export ENABLE_MEDIACODEC=1

# Basic configuration
EXTRA_BUILD_CFG=(
  --disable-avdevice
  --disable-everything
  --disable-network
  --disable-filters
  --disable-encoders
  --disable-decoders
  --disable-hwaccels
  --disable-protocols
  --disable-bsfs
  --disable-doc
  --enable-small
  --enable-protocol=file
  --enable-encoder=aac
  --enable-encoder=ac3
  --enable-encoder=opus
  --enable-encoder=flac
  --enable-decoder=h264
  --enable-decoder=hevc
  --enable-decoder=vp8
  --enable-decoder=vp9
  --enable-decoder=av1
  --enable-decoder=aac
  --enable-decoder=ac3
  --enable-decoder=mp3
  --enable-decoder=opus
  --enable-decoder=flac
  --disable-muxers
  --disable-demuxers
  --enable-muxer=mp4
  --enable-muxer=matroska
  --enable-muxer=mov
  --enable-muxer=flv
  --enable-muxer=webm
  --enable-muxer=adts
  --enable-muxer=ogg
  --enable-muxer=mp3
  --enable-muxer=wav
  --enable-muxer=flac
  --enable-demuxer=matroska
  --enable-demuxer=mov
  --enable-demuxer=flv
  --enable-demuxer=aac
  --enable-demuxer=ogg
  --enable-demuxer=mp3
  --enable-demuxer=wav
  --enable-demuxer=flac
  --disable-parsers
  --enable-parser=aac
  --enable-parser=ac3
  --enable-parser=h264
  --enable-parser=hevc
  --enable-parser=vp8
  --enable-parser=vp9
  --enable-parser=av1
  --enable-parser=flac
  --enable-parser=opus
  --enable-parser=mpegaudio
  --enable-zlib
)