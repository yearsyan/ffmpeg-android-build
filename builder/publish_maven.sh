#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Script: publish_maven.sh
# Purpose: Publish FFmpeg Android AAR packages to Maven Central
# Usage: ./publish_maven.sh [--config=CONFIG] [--version=VERSION]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")" && pwd)"
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-${0}}")/.." && pwd)

# Default values
BUILD_CONFIG_NAME="standard"
PUBLISH_VERSION="1.0.0"
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --config=*)
      BUILD_CONFIG_NAME="${arg#*=}"
      ;;
    --version=*)
      PUBLISH_VERSION="${arg#*=}"
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --help|-h)
      echo "Usage: $0 [--config=CONFIG] [--version=VERSION] [--dry-run]"
      echo "Options:"
      echo "  --config=CONFIG    Build configuration (standard, mini, gpl)"
      echo "  --version=VERSION  Version to publish (default: 1.0.0)"
      echo "  --dry-run         Only build AAR without publishing"
      exit 0
      ;;
  esac
done

BUILD_SUFFIX=""
if [[ "$BUILD_CONFIG_NAME" != "standard" ]]; then
  BUILD_SUFFIX="_$BUILD_CONFIG_NAME"
fi

BUILD_DIR="$PROJECT_ROOT/build"
PREFAB_WORK_DIR="$BUILD_DIR/prefab-work"
PUBLISH_DIR="$BUILD_DIR/maven-publish"

echo "=== Publishing FFmpeg Android to Maven Central ==="
echo "Configuration: $BUILD_CONFIG_NAME"
echo "Version: $PUBLISH_VERSION"
echo "Dry run: $DRY_RUN"

# Check if AAR exists
AAR_FILE="$BUILD_DIR/ffmpeg${BUILD_SUFFIX}.aar"
if [[ ! -f "$AAR_FILE" ]]; then
  echo "Error: AAR file not found: $AAR_FILE"
  echo "Please run build_all.sh first to generate the AAR packages."
  exit 1
fi

# Create publish directory
rm -rf "$PUBLISH_DIR"
mkdir -p "$PUBLISH_DIR"

# Extract AAR to get the Android project structure
cd "$PUBLISH_DIR"
unzip -q "$AAR_FILE" -d ffmpeg-android/

# Copy Gradle build files
cp "$PROJECT_ROOT/prefab/ffmpeg/build.gradle" ffmpeg-android/
cp "$PROJECT_ROOT/prefab/ffmpeg/gradle.properties" ffmpeg-android/

# Update version in build.gradle
sed -i "s/PUBLISH_VERSION = '1.0.0'/PUBLISH_VERSION = '$PUBLISH_VERSION'/g" ffmpeg-android/build.gradle

# Update artifact ID based on configuration
if [[ "$BUILD_CONFIG_NAME" != "standard" ]]; then
  sed -i "s/PUBLISH_ARTIFACT_ID = 'ffmpeg-android'/PUBLISH_ARTIFACT_ID = 'ffmpeg-android-$BUILD_CONFIG_NAME'/g" ffmpeg-android/build.gradle
fi

# Create settings.gradle
cat > ffmpeg-android/settings.gradle << EOF
rootProject.name = 'ffmpeg-android'
EOF

# Create wrapper gradle files
cat > ffmpeg-android/gradlew << 'EOF'
#!/usr/bin/env sh
exec gradle "$@"
EOF
chmod +x ffmpeg-android/gradlew

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run completed. Project prepared at: $PUBLISH_DIR/ffmpeg-android"
  echo "To publish manually, run:"
  echo "  cd $PUBLISH_DIR/ffmpeg-android"
  echo "  ./gradlew publishReleasePublicationToSonatypeRepository"
  exit 0
fi

# Check required environment variables
if [[ -z "${OSSRH_USERNAME:-}" || -z "${OSSRH_PASSWORD:-}" ]]; then
  echo "Error: OSSRH_USERNAME and OSSRH_PASSWORD environment variables must be set"
  echo "Please set them with your Sonatype OSSRH credentials"
  exit 1
fi

if [[ -z "${SIGNING_KEY_ID:-}" || -z "${SIGNING_PASSWORD:-}" || -z "${SIGNING_SECRET_KEY_RING_FILE:-}" ]]; then
  echo "Error: Signing configuration not found"
  echo "Please set SIGNING_KEY_ID, SIGNING_PASSWORD, and SIGNING_SECRET_KEY_RING_FILE environment variables"
  exit 1
fi

# Set Gradle properties for publishing
export ORG_GRADLE_PROJECT_ossrhUsername="$OSSRH_USERNAME"
export ORG_GRADLE_PROJECT_ossrhPassword="$OSSRH_PASSWORD"
export ORG_GRADLE_PROJECT_signing_keyId="$SIGNING_KEY_ID"
export ORG_GRADLE_PROJECT_signing_password="$SIGNING_PASSWORD"
export ORG_GRADLE_PROJECT_signing_secretKeyRingFile="$SIGNING_SECRET_KEY_RING_FILE"

# Publish to Maven Central
cd ffmpeg-android
echo "Publishing to Maven Central..."
./gradlew publishReleasePublicationToSonatypeRepository

echo "=== Publication completed ==="
echo "Please check Sonatype OSSRH staging repository to release the artifacts:"
echo "https://s01.oss.sonatype.org/" 