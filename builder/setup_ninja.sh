#!/usr/bin/env bash
set -e

# =============================================================================
# Script: setup_ninja.sh
# Purpose: Make sure a *working* ninja binary is used.
#
# Some machines have wrapper scripts named `ninja` earlier on PATH (e.g.
# chromium depot_tools' ninja.py, which may try to bootstrap/download a real
# binary and can spin out of control on restricted networks). Meson runs
# `ninja --version` at setup time, so a broken wrapper stalls or poisons the
# whole build. Here we probe the candidates with a timeout and export NINJA
# (respected by meson) plus prepend a shim dir to PATH for direct invocations.
# =============================================================================

ninja_works() {
  # $1 = candidate command/path; must answer --version quickly.
  timeout 15 "$1" --version >/dev/null 2>&1
}

ninja_main() {
  echo "=== Ninja Check and Setup ==="

  if [[ -n "${NINJA:-}" ]] && ninja_works "$NINJA"; then
    echo "Using NINJA from environment: $NINJA ($("$NINJA" --version 2>/dev/null))"
    return 0
  fi

  local candidates=()
  local p
  # All `ninja` / `ninja-build` occurrences on PATH, then well-known locations.
  while IFS= read -r p; do candidates+=("$p"); done < <(which -a ninja ninja-build 2>/dev/null)
  candidates+=(
    /usr/bin/ninja
    /usr/local/bin/ninja
    "$HOME/.local/bin/ninja"
    /opt/homebrew/bin/ninja
  )

  local c
  for c in "${candidates[@]}"; do
    if ninja_works "$c"; then
      export NINJA="$c"
      break
    fi
    echo "Skipping non-working ninja candidate: $c"
  done

  if [[ -z "${NINJA:-}" ]]; then
    echo "Error: no working ninja binary found (looked at: ${candidates[*]})" >&2
    echo "Please install ninja (e.g. apt install ninja-build / brew install ninja)." >&2
    return 1
  fi

  # Put a shim first on PATH so plain `ninja` calls also hit the real binary.
  local shim_dir="${PROJECT_ROOT:-$(pwd)}/tools/bin"
  mkdir -p "$shim_dir"
  ln -sf "$NINJA" "$shim_dir/ninja"
  export PATH="$shim_dir:$PATH"

  echo "Using ninja: $NINJA ($("$NINJA" --version))"
}

ninja_main
