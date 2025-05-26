#!/usr/bin/env bash
set -e

# CMake version check and setup script
# Ensure using CMake 3.x version, download CMake 3.30.8 if system CMake is not found or version is 4.x+

CMAKE_VERSION_REQUIRED="3.30.8"

# Detect system architecture
detect_arch() {
  local arch=$(uname -m)
  case $arch in
    x86_64)
      echo "x86_64"
      ;;
    aarch64|arm64)
      echo "aarch64"
      ;;
    *)
      echo "Unsupported architecture: $arch" >&2
      exit 1
      ;;
  esac
}

# Detect operating system
detect_os() {
  local os=$(uname -s)
  case $os in
    Linux)
      echo "linux"
      ;;
    Darwin)
      echo "macos"
      ;;
    *)
      echo "Unsupported OS: $os" >&2
      exit 1
      ;;
  esac
}

# Check CMake version
check_cmake_version() {
  if command -v cmake >/dev/null 2>&1; then
    local version=$(cmake --version | head -n1 | sed 's/cmake version //')
    local major_version=$(echo $version | cut -d. -f1)
    echo "Found CMake version: $version"
    
    if [ "$major_version" -ge 4 ]; then
      echo "CMake version $version is 4.x or higher, need to use CMake 3.x"
      return 1
    elif [ "$major_version" -eq 3 ]; then
      echo "CMake version $version is acceptable (3.x)"
      return 0
    else
      echo "CMake version $version is too old, need CMake 3.x"
      return 1
    fi
  else
    echo "CMake not found"
    return 1
  fi
}

# Download and install CMake
download_cmake() {
  local os=$(detect_os)
  local arch=$(detect_arch)
  
  # Build download URL
  local cmake_filename
  if [ "$os" = "linux" ]; then
    cmake_filename="cmake-${CMAKE_VERSION_REQUIRED}-linux-${arch}.tar.gz"
  elif [ "$os" = "macos" ]; then
    if [ "$arch" = "x86_64" ]; then
      cmake_filename="cmake-${CMAKE_VERSION_REQUIRED}-macos-universal.tar.gz"
    else
      cmake_filename="cmake-${CMAKE_VERSION_REQUIRED}-macos-universal.tar.gz"
    fi
  fi
  
  local download_url="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION_REQUIRED}/${cmake_filename}"
  local cmake_dir="${PROJECT_ROOT:-$(pwd)}/tools/cmake"
  local cmake_archive="${cmake_dir}/${cmake_filename}"
  
  echo "Downloading CMake ${CMAKE_VERSION_REQUIRED} for ${os}-${arch}..."
  echo "URL: $download_url"
  
  # Create directory
  mkdir -p "$cmake_dir"
  
  # Download CMake
  if command -v wget >/dev/null 2>&1; then
    wget -O "$cmake_archive" "$download_url"
  elif command -v curl >/dev/null 2>&1; then
    curl -L -o "$cmake_archive" "$download_url"
  else
    echo "Error: Neither wget nor curl found. Please install one of them." >&2
    exit 1
  fi
  
  # Extract
  echo "Extracting CMake..."
  cd "$cmake_dir"
  tar -xzf "$cmake_archive"
  
  # Find extracted directory
  local extracted_dir=$(find . -maxdepth 1 -type d -name "cmake-${CMAKE_VERSION_REQUIRED}*" | head -n1)
  if [ -z "$extracted_dir" ]; then
    echo "Error: Could not find extracted CMake directory" >&2
    exit 1
  fi
  
  # Create symlink or rename
  if [ -d "current" ]; then
    rm -rf current
  fi
  mv "$extracted_dir" current
  
  # Clean up downloaded archive
  rm -f "$cmake_archive"
  
  echo "CMake ${CMAKE_VERSION_REQUIRED} installed to: ${cmake_dir}/current"
}

# Set up CMake path
setup_cmake_path() {
  local cmake_dir="${PROJECT_ROOT:-$(pwd)}/tools/cmake/current"
  
  if [ -d "$cmake_dir" ]; then
    local os=$(detect_os)
    if [ "$os" = "macos" ]; then
      export CMAKE_BIN="$cmake_dir/CMake.app/Contents/bin/cmake"
    else
      export CMAKE_BIN="$cmake_dir/bin/cmake"
    fi
    
    if [ -f "$CMAKE_BIN" ]; then
      echo "Using CMake: $CMAKE_BIN"
      echo "CMake version: $($CMAKE_BIN --version | head -n1)"
      
      # Add CMake path to the front of PATH
      local cmake_bin_dir=$(dirname "$CMAKE_BIN")
      export PATH="$cmake_bin_dir:$PATH"
      
      # Set CMAKE environment variable for other scripts
      export CMAKE="$CMAKE_BIN"
      
      return 0
    else
      echo "Error: CMake binary not found at $CMAKE_BIN" >&2
      return 1
    fi
  else
    echo "Error: CMake directory not found at $cmake_dir" >&2
    return 1
  fi
}

# Main logic encapsulated in a function
cmake_main() {
  echo "=== CMake Version Check and Setup ==="

  # First check system CMake
  if check_cmake_version; then
    echo "System CMake is suitable, using system CMake"
    export CMAKE="cmake"
    return 0
  fi

  # Check if a suitable CMake is already downloaded
  cmake_dir="${PROJECT_ROOT:-$(pwd)}/tools/cmake/current"
  if [ -d "$cmake_dir" ]; then
    echo "Found downloaded CMake, checking version..."
    if setup_cmake_path; then
      # Verify downloaded CMake version
      downloaded_version=$($CMAKE --version | head -n1 | sed 's/cmake version //')
      downloaded_major=$(echo $downloaded_version | cut -d. -f1)
      if [ "$downloaded_major" -eq 3 ]; then
        echo "Downloaded CMake version $downloaded_version is suitable"
        return 0
      fi
    fi
  fi

  # Download and install CMake
  echo "Downloading CMake ${CMAKE_VERSION_REQUIRED}..."
  download_cmake

  # Set up CMake path
  setup_cmake_path

  echo "=== CMake Setup Complete ==="
  echo "CMake path: $CMAKE"
  echo "CMake version: $($CMAKE --version | head -n1)"
}

# Call main function
cmake_main