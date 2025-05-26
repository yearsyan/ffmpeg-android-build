#!/usr/bin/env bash
set -e

# Meson version check and setup script
# Ensure using Meson 1.x version, download Meson 1.8.0 if system Meson is not found or version is too old

MESON_VERSION_REQUIRED="1.8.0"

# Check Meson version
check_meson_version() {
  if command -v meson >/dev/null 2>&1; then
    local version=$(meson --version)
    local major_version=$(echo $version | cut -d. -f1)
    echo "Found Meson version: $version"
    
    if [ "$major_version" -ge 1 ]; then
      echo "Meson version $version is acceptable (1.x or higher)"
      return 0
    else
      echo "Meson version $version is too old, need Meson 1.x"
      return 1
    fi
  else
    echo "Meson not found"
    return 1
  fi
}

# Download and install Meson
download_meson() {
  local meson_dir="${PROJECT_ROOT:-$(pwd)}/tools/meson"
  local meson_archive="${meson_dir}/meson-${MESON_VERSION_REQUIRED}.tar.gz"
  local download_url="https://github.com/mesonbuild/meson/releases/download/${MESON_VERSION_REQUIRED}/meson-${MESON_VERSION_REQUIRED}.tar.gz"
  
  echo "Downloading Meson ${MESON_VERSION_REQUIRED}..."
  echo "URL: $download_url"
  
  # Create directory
  mkdir -p "$meson_dir"
  
  # Download Meson
  if command -v wget >/dev/null 2>&1; then
    wget -O "$meson_archive" "$download_url"
  elif command -v curl >/dev/null 2>&1; then
    curl -L -o "$meson_archive" "$download_url"
  else
    echo "Error: Neither wget nor curl found. Please install one of them." >&2
    exit 1
  fi
  
  # Extract
  echo "Extracting Meson..."
  cd "$meson_dir"
  tar -xzf "$meson_archive"
  
  # Find extracted directory
  local extracted_dir=$(find . -maxdepth 1 -type d -name "meson-${MESON_VERSION_REQUIRED}" | head -n1)
  if [ -z "$extracted_dir" ]; then
    echo "Error: Could not find extracted Meson directory" >&2
    exit 1
  fi
  
  # Create symlink or rename
  if [ -d "current" ]; then
    rm -rf current
  fi
  mv "$extracted_dir" current
  
  # Clean up downloaded archive
  rm -f "$meson_archive"
  
  echo "Meson ${MESON_VERSION_REQUIRED} installed to: ${meson_dir}/current"
}

# Set up Meson path
setup_meson_path() {
  local meson_dir="${PROJECT_ROOT:-$(pwd)}/tools/meson/current"
  
  if [ -d "$meson_dir" ]; then
    export MESON_BIN="$meson_dir/meson.py"
    
    if [ -f "$MESON_BIN" ]; then
      echo "Using Meson: $MESON_BIN"
      # Ensure Python3 is available
      if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: Python3 is required for Meson but not found" >&2
        return 1
      fi
      
      # Set MESON environment variable for other scripts
      export MESON="python3 $MESON_BIN"
      echo "Meson version: $($MESON --version)"
      return 0
    else
      echo "Error: Meson script not found at $MESON_BIN" >&2
      return 1
    fi
  else
    echo "Error: Meson directory not found at $meson_dir" >&2
    return 1
  fi
}

# Main logic encapsulated in a function
meson_main() {
  echo "=== Meson Version Check and Setup ==="

  # First check system Meson
  if check_meson_version; then
    echo "System Meson is suitable, using system Meson"
    export MESON="meson"
    return 0
  fi

  # Check if a suitable Meson is already downloaded
  meson_dir="${PROJECT_ROOT:-$(pwd)}/tools/meson/current"
  if [ -d "$meson_dir" ]; then
    echo "Found downloaded Meson, checking version..."
    if setup_meson_path; then
      # Verify downloaded Meson version
      downloaded_version=$($MESON --version)
      downloaded_major=$(echo $downloaded_version | cut -d. -f1)
      if [ "$downloaded_major" -ge 1 ]; then
        echo "Downloaded Meson version $downloaded_version is suitable"
        return 0
      fi
    fi
  fi

  # Download and install Meson
  echo "Downloading Meson ${MESON_VERSION_REQUIRED}..."
  download_meson

  # Set up Meson path
  setup_meson_path

  echo "=== Meson Setup Complete ==="
  echo "Meson path: $MESON"
  echo "Meson version: $($MESON --version)"
}

# Call main function
meson_main 