# Apple Notarization Guide

## Overview

This guide covers the Apple notarization process for the Claude Code Usage MenuBar app. Notarization ensures that your app is free from malicious content and will run without security warnings on macOS 10.15 Catalina and later.

## Why Notarization?

Starting with macOS 10.15 Catalina, Apple requires all apps distributed outside the Mac App Store to be notarized. Without notarization, users will see security warnings that may prevent them from running your app.

### Benefits of Notarization
- ✅ **No Security Warnings**: Users can run your app without scary dialogs
- ✅ **Increased Trust**: Apple's seal of approval builds user confidence
- ✅ **Future-Proof**: Required for current and future macOS versions
- ✅ **Professional Distribution**: Essential for commercial apps

## Prerequisites

### 1. Apple Developer Account
- **Cost**: $99/year
- **Sign up**: https://developer.apple.com/programs/
- **Required for**: Code signing certificates and notarization service access

### 2. Developer ID Certificate
- **Type**: "Developer ID Application" certificate
- **Purpose**: Code signing for distribution outside Mac App Store
- **Location**: Apple Developer Portal → Certificates, Identifiers & Profiles

### 3. App-Specific Password
- **Purpose**: Secure authentication for notarization
- **Generate**: https://appleid.apple.com/account/manage
- **Section**: Sign-In and Security → App-Specific Passwords

## Quick Start

### 1. Initial Setup
```bash
# Run the setup script to configure notarization
./scripts/setup-notarization.sh
```

This script will:
- Check for required tools (Xcode, notarytool)
- Verify your Developer ID certificates
- Create configuration templates
- Set up notarytool keychain profile
- Validate your setup

### 2. Build and Notarize
```bash
# Complete build and notarization
./scripts/build-and-notarize.sh --release

# Or step by step:
./scripts/build.sh                    # Build the app
./scripts/notarize.sh --dmg           # Notarize and create DMG
```

### 3. Distribute
Your notarized app is now ready for distribution via:
- GitHub Releases
- Direct download
- Email distribution
- Third-party app stores

## Detailed Process

### Step 1: Configuration

#### Create Configuration File
```bash
# Copy template and edit with your details
cp config/.notarization-config.template config/.notarization-config
```

#### Required Configuration
```bash
# Your Apple Developer details
APPLE_ID="your-apple-id@example.com"
TEAM_ID="ABC123DEF4"  # 10-character team ID
SIGNING_IDENTITY="Developer ID Application: Your Name (ABC123DEF4)"
```

### Step 2: Code Signing

The app must be signed with:
- **Developer ID Application certificate**
- **Hardened Runtime enabled**
- **Proper entitlements**

Our scripts handle this automatically:
```bash
# Manual code signing (handled by scripts)
codesign --force --verify --verbose --timestamp \
    --options runtime \
    --entitlements config/entitlements.plist \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    "build/Claude Code Usage.app"
```

### Step 3: Notarization Submission

```bash
# Create archive for submission
ditto -c -k --sequesterRsrc --keepParent \
    "build/Claude Code Usage.app" \
    "build/Claude Code Usage.zip"

# Submit to Apple's notary service
xcrun notarytool submit "build/Claude Code Usage.zip" \
    --keychain-profile "claude-usage-notary" \
    --wait
```

### Step 4: Stapling

After successful notarization, "staple" the ticket to your app:
```bash
xcrun stapler staple "build/Claude Code Usage.app"
```

Stapling allows the app to be verified offline.

## Security Configuration

### Entitlements (config/entitlements.plist)

Our app uses minimal entitlements for security:

```xml
<!-- Required for currency conversion -->
<key>com.apple.security.network.client</key>
<true/>

<!-- Required for reading Claude Code logs -->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>

<!-- Hardened Runtime (required for notarization) -->
<key>com.apple.security.cs.allow-jit</key>
<false/>
```

### Hardened Runtime

Hardened Runtime is required for notarization and provides:
- Protection against code injection
- Stricter memory protections  
- Limited dynamic code generation
- Enhanced security boundaries

## Script Reference

### setup-notarization.sh
**Purpose**: Initial configuration and verification

**Usage**:
```bash
./scripts/setup-notarization.sh
```

**Features**:
- Interactive setup wizard
- Certificate verification
- Keychain profile creation
- Configuration validation

### notarize.sh
**Purpose**: Sign and notarize existing app bundle

**Usage**:
```bash
./scripts/notarize.sh [OPTIONS]

Options:
  --dmg          Create distribution DMG
  --skip-build   Notarize existing build
  --help         Show help
```

**Process**:
1. Load configuration
2. Verify prerequisites  
3. Clean signatures
4. Code sign with Hardened Runtime
5. Create archive
6. Submit for notarization
7. Staple ticket
8. Verify result

### build-and-notarize.sh
**Purpose**: Complete build and notarization workflow

**Usage**:
```bash
./scripts/build-and-notarize.sh [OPTIONS]

Options:
  --clean        Clean build first
  --no-notarize  Build only
  --dmg          Create DMG
  --release      Full release build
```

**Process**:
1. Clean build (optional)
2. Build release version
3. Code sign
4. Notarize
5. Create DMG (optional)
6. Verify distribution

## Troubleshooting

### Common Issues

#### 1. Certificate Not Found
```
❌ Code signing identity not found
```

**Solution**:
- Verify you have a "Developer ID Application" certificate
- Check it's installed in your keychain
- Ensure the certificate name matches your configuration

#### 2. Notarization Failed
```
❌ Notarization failed
```

**Solution**:
- Check the detailed error log in `build/notarization-error.json`
- Common causes:
  - Missing Hardened Runtime
  - Invalid entitlements
  - Unsigned nested frameworks
  - Network connectivity issues

#### 3. Team ID Not Found
```
❌ Required configuration variable TEAM_ID is not set
```

**Solution**:
- Find your Team ID at https://developer.apple.com/account/
- Update your configuration file
- Re-run setup script

#### 4. App-Specific Password Rejected
```
❌ HTTP status code: 401
```

**Solution**:
- Generate new app-specific password at https://appleid.apple.com/account/manage
- Ensure you're using app-specific password, not your Apple ID password
- Check for typos in Apple ID email address

### Debug Commands

#### Check Certificate
```bash
security find-identity -v -p codesigning
```

#### Verify Signature
```bash
codesign --verify --deep --strict --verbose=2 "build/Claude Code Usage.app"
```

#### Check Notarization Status
```bash
xcrun notarytool info SUBMISSION_ID --keychain-profile "claude-usage-notary"
```

#### Test Gatekeeper
```bash
spctl -a -v "build/Claude Code Usage.app"
```

## Automation

### CI/CD Integration

For automated builds in GitHub Actions or similar:

1. **Store Secrets**:
   - `APPLE_ID` - Your Apple ID
   - `TEAM_ID` - Your team ID  
   - `APP_PASSWORD` - App-specific password
   - `SIGNING_CERTIFICATE` - Base64-encoded .p12 certificate
   - `CERTIFICATE_PASSWORD` - Certificate password

2. **Use in Workflow**:
```yaml
- name: Notarize App
  env:
    APPLE_ID: ${{ secrets.APPLE_ID }}
    TEAM_ID: ${{ secrets.TEAM_ID }}
    APP_PASSWORD: ${{ secrets.APP_PASSWORD }}
  run: |
    ./scripts/build-and-notarize.sh --release
```

### Webhook Notifications

For large-scale automation, consider using Apple's webhook notifications:
```bash
xcrun notarytool submit app.zip \
    --keychain-profile "profile" \
    --webhook "https://your-server.com/notarization-webhook"
```

## Cost and Timing

### Apple Developer Program
- **Cost**: $99/year
- **Includes**: Code signing certificates, notarization service, developer resources

### Notarization Performance
- **Typical Time**: 2-5 minutes for small apps
- **Maximum Time**: 15 minutes (Apple's commitment)
- **Our App**: Usually completes in 1-3 minutes
- **Rate Limits**: No published limits for reasonable usage

### File Size Limits
- **Maximum**: 2GB per submission
- **Our App**: ~600KB (well within limits)
- **Recommendation**: Keep apps under 100MB for faster processing

## Best Practices

### Security
- ✅ Use minimal entitlements
- ✅ Enable Hardened Runtime
- ✅ Sign all nested frameworks
- ✅ Use app-specific passwords (not Apple ID password)
- ✅ Store credentials securely in CI/CD

### Performance
- ✅ Cache notarization setup in CI/CD
- ✅ Use webhook notifications for automation
- ✅ Minimize app bundle size
- ✅ Parallelize builds when possible

### Distribution
- ✅ Always staple notarization tickets
- ✅ Test on clean systems before release
- ✅ Provide clear download instructions
- ✅ Consider DMG distribution for easier installation

## Resources

### Apple Documentation
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)

### Tools
- **notarytool**: Modern notarization tool (Xcode 13+)
- **codesign**: Code signing utility
- **stapler**: Ticket stapling utility
- **spctl**: System Policy control (Gatekeeper testing)

### Community
- [Apple Developer Forums](https://developer.apple.com/forums/topics/code-signing-topic/)
- [Stack Overflow - macOS Notarization](https://stackoverflow.com/questions/tagged/notarize)

## Conclusion

Apple notarization ensures your Claude Code Usage MenuBar app can be safely distributed to users without security warnings. While the initial setup requires an Apple Developer Account and some configuration, our automated scripts make the ongoing process seamless.

The investment in notarization pays off through:
- Improved user experience (no scary warnings)
- Professional appearance and trust
- Compliance with Apple's requirements
- Future-proofing for macOS updates

For additional support or questions about the notarization process for this specific app, please refer to the project documentation or open an issue in the GitHub repository.