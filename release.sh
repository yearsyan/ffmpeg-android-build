#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Script: release.sh
# Purpose: Package and publish FFmpeg Android AAR packages to Maven Central
# =============================================================================

# Get the absolute path of the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ -z "${GPG_PASSWORD:-}" || -z "${SONATYPE_AUTH_TOKEN:-}" ]]; then
  echo "Error: Signing configuration not found"
  echo "Please set GPG_PASSWORD, SONATYPE_AUTH_TOKEN environment variables"
  exit 1
fi

# Import GPG private key if GPG_PRIVATE_KEY is set
if [[ -n "${GPG_PRIVATE_KEY:-}" ]]; then
  echo "=== Importing GPG private key ==="
  echo "$GPG_PRIVATE_KEY" | gpg --batch --import
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to import GPG private key"
    exit 1
  fi
  echo "GPG private key imported successfully"
fi

# Get version from git tag
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
VERSION=${VERSION#v} # Remove 'v' prefix if present

echo "=== Starting release process for version: $VERSION ==="

# Create Prefab packages
echo "=== Creating Prefab packages ==="
"${SCRIPT_DIR}/builder/create_prefab.sh" --config="standard"
"${SCRIPT_DIR}/builder/create_prefab.sh" --config="mini"

# Publish to Maven Central
echo "=== Publishing to Maven Central ==="
"${SCRIPT_DIR}/publish.sh" --config="mini"
"${SCRIPT_DIR}/publish.sh" --config="standard"

echo "=== Release process completed ==="
