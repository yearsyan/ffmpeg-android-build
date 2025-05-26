#!/bin/bash

# Exit on error
set -e

# Configuration
AUTH_TOKEN="${SONATYPE_AUTH_TOKEN}"
if [ -z "$AUTH_TOKEN" ]; then
    echo "Error: SONATYPE_AUTH_TOKEN environment variable is not set"
    exit 1
fi

# Check if gpg is available
if ! command -v gpg &> /dev/null; then
    echo "Error: gpg is not installed"
    exit 1
fi

# Check if GPG_PASSWORD is set
if [ -z "$GPG_PASSWORD" ]; then
    echo "Error: GPG_PASSWORD environment variable is not set"
    exit 1
fi

# Get version from git tag
VERSION=$(git describe --tags --abbrev=0 | sed 's/^v//')
# Store original version for file name
FILE_VERSION="$VERSION"

# Get build config
CONFIG_NAME="${CONFIG_NAME:-standard}"
if [ "$CONFIG_NAME" = "standard" ]; then
    AAR_FILE="build/ffmpeg-${FILE_VERSION}.aar"
else
    AAR_FILE="build/ffmpeg_${CONFIG_NAME}-${FILE_VERSION}.aar"
fi

if [ ! -f "$AAR_FILE" ]; then
    echo "Error: AAR file not found at $AAR_FILE"
    exit 1
fi

# Create bundle directory
BUNDLE_DIR="bundle_${CONFIG_NAME}"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Create Maven directory structure
GROUP_ID="io.github.yearsyan"
ARTIFACT_ID="ffmpeg-${CONFIG_NAME}"
MAVEN_PATH="${BUNDLE_DIR}/${GROUP_ID//.//}/${ARTIFACT_ID}/${VERSION}"
mkdir -p "$MAVEN_PATH"

# Function to generate signatures and checksums
generate_signatures_and_checksums() {
    local file="$1"
    # Generate GPG signature with password
    echo "$GPG_PASSWORD" | gpg --batch --yes --pinentry-mode loopback --passphrase-fd 0 --armor --detach-sign "$file"
    # Generate MD5 checksum
    md5sum "$file" | cut -d' ' -f1 > "${file}.md5"
    # Generate SHA1 checksum
    sha1sum "$file" | cut -d' ' -f1 > "${file}.sha1"
}

# Copy AAR file and generate signatures/checksums
cp "$AAR_FILE" "${MAVEN_PATH}/${ARTIFACT_ID}-${VERSION}.aar"
generate_signatures_and_checksums "${MAVEN_PATH}/${ARTIFACT_ID}-${VERSION}.aar"

# Create POM file
POM_FILE="${MAVEN_PATH}/${ARTIFACT_ID}-${VERSION}.pom"
cat > "$POM_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>${GROUP_ID}</groupId>
    <artifactId>${ARTIFACT_ID}</artifactId>
    <version>${VERSION}</version>
    <packaging>aar</packaging>
    <name>FFmpeg Android</name>
    <description>FFmpeg library for Android with Prefab support</description>
    <url>https://github.com/yearsyan/ffmpeg-android-build</url>
    <licenses>
        <license>
            <name>LGPL-2.1</name>
            <url>https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html</url>
        </license>
    </licenses>
    <developers>
        <developer>
            <id>${GITHUB_ACTOR:-yearsyan}</id>
            <name>${GITHUB_ACTOR:-yearsyan}</name>
            <email>${GIT_EMAIL:-yearsyan@hotmail.com}</email>
        </developer>
    </developers>
    <scm>
        <connection>scm:git:git://github.com/${GITHUB_REPOSITORY:-yearsyan/ffmpeg-android-build}.git</connection>
        <developerConnection>scm:git:ssh://github.com/${GITHUB_REPOSITORY:-yearsyan/ffmpeg-android-build}.git</developerConnection>
        <url>https://github.com/${GITHUB_REPOSITORY:-yearsyan/ffmpeg-android-build}</url>
    </scm>
</project>
EOF

# Generate signatures and checksums for POM
generate_signatures_and_checksums "$POM_FILE"

# Create bundle zip
cd "$BUNDLE_DIR"
zip -9 -r "../bundle.zip" .
echo "Bundle size: $(du -h ../bundle.zip | cut -f1)"
cd ..

# Upload bundle
echo "Uploading bundle..."
DEPLOYMENT_ID=$(curl -# --connect-timeout 60 --max-time 0 --retry 3 --retry-delay 5 --retry-max-time 0 -w "\nUpload speed: %{speed_upload} bytes/sec\n" -X POST \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    -F "bundle=@bundle.zip" \
    "https://central.sonatype.com/api/v1/publisher/upload?publishingType=AUTOMATIC&name=${VERSION}" | tr -d '"')

if [ -z "$DEPLOYMENT_ID" ]; then
    echo "Error: Failed to upload bundle"
    exit 1
fi

echo "Deployment ID: ${DEPLOYMENT_ID}"
# Cleanup
rm -rf "$BUNDLE_DIR" bundle.zip 