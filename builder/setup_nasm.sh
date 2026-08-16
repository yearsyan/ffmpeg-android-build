#!/usr/bin/env bash
set -e

# =============================================================================
# Script: setup_nasm.sh
# Purpose: Ensure a host `nasm` is available for x86/x86_64 builds.
#          dav1d's x86 assembly hard-requires nasm and FFmpeg's x86 asm
#          optimizations also use it. CI installs nasm via apt; for local
#          machines without sudo we fetch the Ubuntu package and extract it
#          (no root needed), falling back to a source build.
# =============================================================================

NASM_VERSION="2.16.03"

nasm_main() {
  # Only x86 targets use nasm.
  case "${TARGET_ARCH:-}" in
    x86|x86_64) ;;
    *) return 0 ;;
  esac

  if timeout 15 nasm -v >/dev/null 2>&1; then
    echo "Using system nasm: $(command -v nasm) ($(nasm -v))"
    return 0
  fi

  local bin_dir="${PROJECT_ROOT:-$(pwd)}/tools/bin"
  mkdir -p "$bin_dir"

  if [[ ! -x "$bin_dir/nasm" ]]; then
    echo "nasm not found, bootstrapping nasm $NASM_VERSION ..."
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    local ok=0
    if command -v apt >/dev/null 2>&1 && command -v dpkg-deb >/dev/null 2>&1; then
      # No root required: fetch the .deb and extract the binary.
      if (cd "$tmp_dir" && apt download nasm >/dev/null 2>&1); then
        local deb
        deb=$(ls "$tmp_dir"/nasm_*.deb 2>/dev/null | head -n1)
        if [[ -n "$deb" ]]; then
          dpkg-deb -x "$deb" "$tmp_dir/extract"
          cp "$tmp_dir/extract/usr/bin/nasm" "$bin_dir/nasm"
          chmod +x "$bin_dir/nasm"
          ok=1
        fi
      fi
    fi

    if [[ "$ok" == "0" ]]; then
      # Fallback: build from source (host tool, use the host compiler).
      local tarball="nasm-${NASM_VERSION}.tar.xz"
      curl -fL --retry 3 -o "$tmp_dir/$tarball" \
        "https://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/$tarball"
      tar xJf "$tmp_dir/$tarball" -C "$tmp_dir"
      (cd "$tmp_dir/nasm-${NASM_VERSION}" && ./configure --prefix="$tmp_dir/install" >/dev/null && make -j"$(nproc)" >/dev/null)
      cp "$tmp_dir/nasm-${NASM_VERSION}/nasm" "$bin_dir/nasm"
      chmod +x "$bin_dir/nasm"
    fi
    rm -rf "$tmp_dir"
  fi

  # setup_ninja.sh already prepends tools/bin to PATH; do it here as well in
  # case this script runs standalone.
  case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) export PATH="$bin_dir:$PATH" ;;
  esac

  echo "Using nasm: $(command -v nasm) ($(nasm -v))"
}

nasm_main
