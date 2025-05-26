# Publishing to Maven Central

This guide explains how to publish FFmpeg Android AAR packages to Maven Central Repository.

## Prerequisites

### 1. Sonatype OSSRH Account
- Create an account at [Sonatype OSSRH](https://issues.sonatype.org/)
- Create a JIRA ticket to request a new project namespace (e.g., `io.github.yearsyan`)
- Wait for approval (usually takes 1-2 business days)

### 2. GPG Key for Signing
Generate a GPG key pair for signing artifacts:

```bash
# Generate GPG key
gpg --gen-key

# List keys to get the key ID
gpg --list-secret-keys --keyid-format LONG

# Export public key to key servers
gpg --keyserver keyserver.ubuntu.com --send-keys YOUR_KEY_ID
gpg --keyserver keys.openpgp.org --send-keys YOUR_KEY_ID

# Export secret key ring (for older GPG versions)
gpg --export-secret-keys YOUR_KEY_ID > secring.gpg
```

### 3. Environment Variables
Set the following environment variables:

```bash
# Sonatype OSSRH credentials
export OSSRH_USERNAME="your_sonatype_username"
export OSSRH_PASSWORD="your_sonatype_password"

# GPG signing configuration
export SIGNING_KEY_ID="your_gpg_key_id"
export SIGNING_PASSWORD="your_gpg_key_password"
export SIGNING_SECRET_KEY_RING_FILE="/path/to/secring.gpg"
```

## Configuration

### 1. Update build.gradle
Edit `prefab/ffmpeg/build.gradle` and update the following:

```gradle
ext {
    PUBLISH_GROUP_ID = 'io.github.yearsyan'  // Your approved namespace
    PUBLISH_ARTIFACT_ID = 'ffmpeg-android'
    PUBLISH_VERSION = '1.0.0'
}
```

Update the POM information:
- `name`: Library name
- `description`: Library description
- `url`: GitHub repository URL
- `licenses`: License information
- `developers`: Your information
- `scm`: Source control information

### 2. Artifact IDs
The script will automatically generate different artifact IDs for different configurations:
- Standard: `ffmpeg-android`
- Mini: `ffmpeg-android-mini`
- GPL: `ffmpeg-android-gpl`

## Publishing Process

### 1. Build AAR Packages
First, build all architectures and create AAR packages:

```bash
./builder/build_all.sh
```

### 2. Publish to Maven Central

#### Dry Run (Recommended First)
Test the publishing setup without actually uploading:

```bash
./builder/publish_maven.sh --config=standard --version=1.0.0 --dry-run
```

#### Publish Standard Configuration
```bash
./builder/publish_maven.sh --config=standard --version=1.0.0
```

#### Publish All Configurations
```bash
./builder/publish_maven.sh --config=standard --version=1.0.0
./builder/publish_maven.sh --config=mini --version=1.0.0
./builder/publish_maven.sh --config=gpl --version=1.0.0
```

### 3. Release from Staging
1. Go to [Sonatype OSSRH Staging Repository](https://s01.oss.sonatype.org/)
2. Login with your credentials
3. Navigate to "Staging Repositories"
4. Find your uploaded artifacts
5. Select and "Close" the repository
6. After validation passes, "Release" the repository

## Using Published Artifacts

Once published, users can add the dependency to their Android projects:

### Standard Configuration
```gradle
dependencies {
    implementation 'io.github.yearsyan:ffmpeg-android:1.0.0'
}
```

### Mini Configuration
```gradle
dependencies {
    implementation 'io.github.yearsyan:ffmpeg-android-mini:1.0.0'
}
```

### GPL Configuration
```gradle
dependencies {
    implementation 'io.github.yearsyan:ffmpeg-android-gpl:1.0.0'
}
```

## Troubleshooting

### Common Issues

1. **GPG Signing Errors**
   - Ensure GPG key is properly configured
   - Check that the secret key ring file exists
   - Verify the key ID and password are correct

2. **Authentication Errors**
   - Verify OSSRH username and password
   - Check that your namespace is approved

3. **Validation Errors**
   - Ensure all required POM fields are filled
   - Check that sources and javadoc JARs are included
   - Verify GPG signatures are valid

### Logs and Debugging
- Check Gradle build logs for detailed error messages
- Use `--dry-run` flag to test configuration without publishing
- Verify staging repository status in Sonatype OSSRH web interface

## Automation with CI/CD

For automated publishing in CI/CD pipelines, store credentials as secrets:

### GitHub Actions Example
```yaml
- name: Publish to Maven Central
  env:
    OSSRH_USERNAME: ${{ secrets.OSSRH_USERNAME }}
    OSSRH_PASSWORD: ${{ secrets.OSSRH_PASSWORD }}
    SIGNING_KEY_ID: ${{ secrets.SIGNING_KEY_ID }}
    SIGNING_PASSWORD: ${{ secrets.SIGNING_PASSWORD }}
    SIGNING_SECRET_KEY_RING_FILE: ${{ secrets.SIGNING_SECRET_KEY_RING_FILE }}
  run: |
    ./builder/publish_maven.sh --config=standard --version=${{ github.ref_name }}
```

## Version Management

- Use semantic versioning (e.g., 1.0.0, 1.1.0, 2.0.0)
- Tag releases in Git to match published versions
- Consider using different version schemes for different configurations
- Update version in build.gradle before publishing 