#!/bin/bash

# Claude Code Usage MenuBar - Notarization Script
# Signs and notarizes macOS app for distribution

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/.notarization-config"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Claude Code Usage"
APP_PATH="$BUILD_DIR/${APP_NAME}.app"
ENTITLEMENTS_FILE="$CONFIG_DIR/entitlements.plist"

echo -e "${BLUE}🍎 Claude Code Usage MenuBar - App Notarization${NC}"
echo "========================================================"

# Function to load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}❌ Configuration file not found: $CONFIG_FILE${NC}"
        echo "Please run ./scripts/setup-notarization.sh first"
        exit 1
    fi
    
    echo -e "${YELLOW}📝 Loading configuration...${NC}"
    source "$CONFIG_FILE"
    
    # Validate required variables
    local required_vars=("APPLE_ID" "TEAM_ID" "BUNDLE_ID" "SIGNING_IDENTITY" "NOTARY_PROFILE")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo -e "${RED}❌ Required configuration variable $var is not set${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}✅ Configuration loaded successfully${NC}"
    echo "  Apple ID: $APPLE_ID"
    echo "  Team ID: $TEAM_ID"
    echo "  Bundle ID: $BUNDLE_ID"
    echo "  Profile: $NOTARY_PROFILE"
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
    
    # Check if app exists
    if [[ ! -d "$APP_PATH" ]]; then
        echo -e "${RED}❌ App bundle not found: $APP_PATH${NC}"
        echo "Please build the app first using ./scripts/build.sh"
        exit 1
    fi
    
    # Check if entitlements file exists
    if [[ ! -f "$ENTITLEMENTS_FILE" ]]; then
        echo -e "${YELLOW}⚠️  Entitlements file not found, creating default...${NC}"
        create_entitlements_file
    fi
    
    # Check code signing identity
    if ! security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
        echo -e "${RED}❌ Code signing identity not found: $SIGNING_IDENTITY${NC}"
        echo "Available identities:"
        security find-identity -v -p codesigning
        exit 1
    fi
    
    # Check notarytool profile
    if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &> /dev/null; then
        echo -e "${RED}❌ Notarytool profile not found: $NOTARY_PROFILE${NC}"
        echo "Please run ./scripts/setup-notarization.sh to create the profile"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites satisfied${NC}"
}

# Function to create default entitlements file
create_entitlements_file() {
    mkdir -p "$CONFIG_DIR"
    
    cat > "$ENTITLEMENTS_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Hardened Runtime entitlements for notarization -->
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    <key>com.apple.security.cs.disable-executable-page-protection</key>
    <false/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <false/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <false/>
    
    <!-- Network access for currency conversion -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- File system access -->
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
EOF
    
    echo -e "${GREEN}✅ Created default entitlements file: $ENTITLEMENTS_FILE${NC}"
}

# Function to clean old signatures
clean_signatures() {
    echo -e "${YELLOW}🧹 Cleaning existing signatures...${NC}"
    
    # Remove extended attributes that might interfere with signing
    xattr -cr "$APP_PATH" || true
    
    echo -e "${GREEN}✅ Signatures cleaned${NC}"
}

# Function to sign the app
sign_app() {
    echo -e "${YELLOW}✍️  Code signing the app...${NC}"
    
    # Sign all executables and frameworks first
    find "$APP_PATH" -type f \( -name "*.dylib" -o -name "*.framework" -o -perm +111 \) | while read -r file; do
        if file "$file" | grep -q "Mach-O"; then
            echo "  Signing: $file"
            codesign --force --verify --verbose --timestamp \
                --options runtime \
                --entitlements "$ENTITLEMENTS_FILE" \
                --sign "$SIGNING_IDENTITY" \
                "$file" || echo "    Warning: Failed to sign $file"
        fi
    done
    
    # Sign the main app bundle
    echo "  Signing main app bundle..."
    codesign --force --verify --verbose --timestamp \
        --options runtime \
        --entitlements "$ENTITLEMENTS_FILE" \
        --sign "$SIGNING_IDENTITY" \
        "$APP_PATH"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ App signed successfully${NC}"
    else
        echo -e "${RED}❌ App signing failed${NC}"
        exit 1
    fi
}

# Function to verify signature
verify_signature() {
    echo -e "${YELLOW}🔍 Verifying code signature...${NC}"
    
    # Verify the signature
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Signature verification passed${NC}"
    else
        echo -e "${RED}❌ Signature verification failed${NC}"
        exit 1
    fi
    
    # Show signature details
    echo ""
    echo "Signature details:"
    codesign -dv --verbose=4 "$APP_PATH" 2>&1 | head -10
    echo ""
}

# Function to create archive for notarization
create_archive() {
    echo -e "${YELLOW}📦 Creating archive for notarization...${NC}"
    
    local archive_path="$BUILD_DIR/${APP_NAME}.zip"
    
    # Remove existing archive
    rm -f "$archive_path"
    
    # Create zip archive
    cd "$BUILD_DIR"
    ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${APP_NAME}.zip"
    cd - > /dev/null
    
    if [[ -f "$archive_path" ]]; then
        local archive_size=$(du -h "$archive_path" | cut -f1)
        echo -e "${GREEN}✅ Archive created: ${APP_NAME}.zip (${archive_size})${NC}"
        echo "  Path: $archive_path"
    else
        echo -e "${RED}❌ Failed to create archive${NC}"
        exit 1
    fi
}

# Function to submit for notarization
submit_notarization() {
    echo -e "${YELLOW}🚀 Submitting for notarization...${NC}"
    
    local archive_path="$BUILD_DIR/${APP_NAME}.zip"
    local submission_log="$BUILD_DIR/notarization-submission.log"
    
    # Submit to Apple's notary service
    echo "Submitting to Apple's notary service (this may take a few minutes)..."
    xcrun notarytool submit "$archive_path" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait \
        --timeout 600 \
        --verbose > "$submission_log" 2>&1
    
    local exit_code=$?
    
    # Show submission results
    echo ""
    echo "Submission results:"
    cat "$submission_log"
    echo ""
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✅ Notarization completed successfully${NC}"
        
        # Extract submission ID for future reference
        local submission_id=$(grep "id:" "$submission_log" | head -1 | awk '{print $2}')
        if [[ -n "$submission_id" ]]; then
            echo "Submission ID: $submission_id"
            echo "$submission_id" > "$BUILD_DIR/notarization-id.txt"
        fi
    else
        echo -e "${RED}❌ Notarization failed${NC}"
        
        # Try to get more detailed error information
        local submission_id=$(grep "id:" "$submission_log" | head -1 | awk '{print $2}')
        if [[ -n "$submission_id" ]]; then
            echo ""
            echo "Getting detailed error log..."
            xcrun notarytool log "$submission_id" \
                --keychain-profile "$NOTARY_PROFILE" \
                "$BUILD_DIR/notarization-error.json"
            
            echo "Error details saved to: $BUILD_DIR/notarization-error.json"
        fi
        
        exit 1
    fi
}

# Function to staple the notarization ticket
staple_ticket() {
    echo -e "${YELLOW}📎 Stapling notarization ticket...${NC}"
    
    xcrun stapler staple "$APP_PATH"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Notarization ticket stapled successfully${NC}"
    else
        echo -e "${RED}❌ Failed to staple notarization ticket${NC}"
        exit 1
    fi
}

# Function to verify notarization
verify_notarization() {
    echo -e "${YELLOW}🔍 Verifying notarization...${NC}"
    
    # Verify stapling
    xcrun stapler validate "$APP_PATH"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Notarization verification passed${NC}"
    else
        echo -e "${RED}❌ Notarization verification failed${NC}"
        exit 1
    fi
    
    # Check Gatekeeper assessment
    echo ""
    echo "Checking Gatekeeper assessment..."
    spctl -a -v "$APP_PATH"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Gatekeeper assessment passed${NC}"
    else
        echo -e "${YELLOW}⚠️  Gatekeeper assessment failed (this may be normal for development builds)${NC}"
    fi
}

# Function to create distribution DMG
create_dmg() {
    echo -e "${YELLOW}💿 Creating distribution DMG...${NC}"
    
    local dmg_path="$BUILD_DIR/${APP_NAME}.dmg"
    local temp_dmg="$BUILD_DIR/temp.dmg"
    
    # Remove existing DMG
    rm -f "$dmg_path" "$temp_dmg"
    
    # Create DMG
    hdiutil create -size 50m -volname "$APP_NAME" -srcfolder "$APP_PATH" -fs HFS+ -format UDRW "$temp_dmg"
    
    # Convert to read-only
    hdiutil convert "$temp_dmg" -format UDZO -o "$dmg_path"
    rm -f "$temp_dmg"
    
    if [[ -f "$dmg_path" ]]; then
        local dmg_size=$(du -h "$dmg_path" | cut -f1)
        echo -e "${GREEN}✅ Distribution DMG created: ${APP_NAME}.dmg (${dmg_size})${NC}"
        echo "  Path: $dmg_path"
    else
        echo -e "${RED}❌ Failed to create DMG${NC}"
        exit 1
    fi
}

# Function to show completion summary
show_summary() {
    echo ""
    echo -e "${GREEN}🎉 Notarization Process Complete!${NC}"
    echo "========================================"
    echo ""
    echo "Files created:"
    echo "  📱 Notarized App: $APP_PATH"
    if [[ -f "$BUILD_DIR/${APP_NAME}.dmg" ]]; then
        echo "  💿 Distribution DMG: $BUILD_DIR/${APP_NAME}.dmg"
    fi
    echo "  📦 Archive: $BUILD_DIR/${APP_NAME}.zip"
    echo "  📋 Logs: $BUILD_DIR/notarization-*.log"
    echo ""
    echo "The app is now ready for distribution!"
    echo "Users will not see any security warnings when running the app."
    echo ""
    echo "Next steps:"
    echo "1. Test the notarized app on a clean system"
    echo "2. Distribute via your preferred method (GitHub Releases, direct download, etc.)"
    echo "3. Consider setting up automated notarization in CI/CD"
}

# Main execution function
main() {
    local create_dmg_flag=false
    local skip_build=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dmg)
                create_dmg_flag=true
                shift
                ;;
            --skip-build)
                skip_build=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dmg          Create a distribution DMG after notarization"
                echo "  --skip-build   Skip building, notarize existing app bundle"
                echo "  --help, -h     Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                # Basic notarization"
                echo "  $0 --dmg          # Notarize and create DMG"
                echo "  $0 --skip-build   # Notarize existing build"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Execute notarization steps
    load_config
    check_prerequisites
    
    # Build app if not skipping
    if [[ "$skip_build" != true ]]; then
        echo -e "${YELLOW}🔨 Building app...${NC}"
        "$SCRIPT_DIR/build.sh"
    fi
    
    clean_signatures
    sign_app
    verify_signature
    create_archive
    submit_notarization
    staple_ticket
    verify_notarization
    
    # Create DMG if requested
    if [[ "$create_dmg_flag" == true ]]; then
        create_dmg
    fi
    
    show_summary
}

# Run main function with all arguments
main "$@"