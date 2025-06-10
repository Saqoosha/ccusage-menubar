#!/bin/bash

# Claude Code Usage MenuBar - Complete Build and Notarization Script
# Builds, signs, notarizes, and packages the app for distribution

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
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Claude Code Usage"

echo -e "${BLUE}🚀 Claude Code Usage MenuBar - Complete Build & Notarization${NC}"
echo "=================================================================="

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Complete build and notarization workflow for Claude Code Usage MenuBar"
    echo ""
    echo "Options:"
    echo "  --clean        Clean build directory before building"
    echo "  --no-notarize  Build only, skip notarization"
    echo "  --dmg          Create distribution DMG (implies notarization)"
    echo "  --release      Build for release distribution (clean + notarize + dmg)"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                     # Basic build and notarization"
    echo "  $0 --clean             # Clean build and notarization"
    echo "  $0 --release           # Full release build with DMG"
    echo "  $0 --no-notarize       # Build only, no notarization"
    echo ""
    echo "Build stages:"
    echo "1. 🧹 Clean (optional)"
    echo "2. 🔨 Build release version"
    echo "3. ✍️  Code signing"
    echo "4. 🍎 Apple notarization"
    echo "5. 📎 Ticket stapling"
    echo "6. 💿 DMG creation (optional)"
    echo "7. ✅ Verification"
}

# Function to clean build directory
clean_build() {
    echo -e "${YELLOW}🧹 Cleaning build directory...${NC}"
    
    # Clean Swift build artifacts
    swift package clean
    
    # Remove build directory
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
        echo -e "${GREEN}✅ Build directory cleaned${NC}"
    else
        echo -e "${GREEN}✅ Build directory already clean${NC}"
    fi
    
    # Create fresh build directory
    mkdir -p "$BUILD_DIR"
}

# Function to build the app
build_app() {
    echo -e "${YELLOW}🔨 Building Claude Code Usage MenuBar...${NC}"
    
    # Run the existing build script
    "$SCRIPT_DIR/build.sh"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ App build completed successfully${NC}"
    else
        echo -e "${RED}❌ App build failed${NC}"
        exit 1
    fi
    
    # Verify app bundle exists
    local app_path="$BUILD_DIR/${APP_NAME}.app"
    if [[ ! -d "$app_path" ]]; then
        echo -e "${RED}❌ App bundle not found after build: $app_path${NC}"
        exit 1
    fi
    
    # Show build information
    echo ""
    echo "Build information:"
    echo "  App bundle: $app_path"
    local app_size=$(du -sh "$app_path" | cut -f1)
    echo "  Size: $app_size"
    
    # Check if main executable exists
    local executable="$app_path/Contents/MacOS/ClaudeUsageMenuBar"
    if [[ -f "$executable" ]]; then
        echo "  Executable: ✅ Found"
        
        # Show Swift version used
        local swift_version=$(swift --version | head -1)
        echo "  Built with: $swift_version"
    else
        echo "  Executable: ❌ Missing"
        exit 1
    fi
    echo ""
}

# Function to notarize the app
notarize_app() {
    echo -e "${YELLOW}🍎 Starting notarization process...${NC}"
    
    # Check if notarization is set up
    if [[ ! -f "$PROJECT_DIR/config/.notarization-config" ]]; then
        echo -e "${RED}❌ Notarization not configured${NC}"
        echo "Please run ./scripts/setup-notarization.sh first"
        exit 1
    fi
    
    # Run notarization script
    "$SCRIPT_DIR/notarize.sh" --skip-build
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Notarization completed successfully${NC}"
    else
        echo -e "${RED}❌ Notarization failed${NC}"
        exit 1
    fi
}

# Function to create distribution DMG
create_distribution_dmg() {
    echo -e "${YELLOW}💿 Creating distribution DMG...${NC}"
    
    local app_path="$BUILD_DIR/${APP_NAME}.app"
    local dmg_path="$BUILD_DIR/${APP_NAME}.dmg"
    local temp_dmg="$BUILD_DIR/temp.dmg"
    local mount_point="/tmp/${APP_NAME}_dmg"
    
    # Remove existing files
    rm -f "$dmg_path" "$temp_dmg"
    rm -rf "$mount_point"
    
    # Create temporary DMG
    echo "Creating temporary DMG..."
    hdiutil create -size 100m -volname "$APP_NAME" -fs HFS+ -format UDRW "$temp_dmg"
    
    # Mount the DMG
    echo "Mounting DMG..."
    hdiutil attach "$temp_dmg" -mountpoint "$mount_point"
    
    # Copy app to DMG
    echo "Copying app to DMG..."
    cp -R "$app_path" "$mount_point/"
    
    # Create Applications symlink for easy installation
    ln -s /Applications "$mount_point/Applications"
    
    # Set DMG background and layout (optional)
    # You can customize this section to add a background image and arrange icons
    
    # Unmount the DMG
    echo "Unmounting DMG..."
    hdiutil detach "$mount_point"
    
    # Convert to compressed, read-only DMG
    echo "Compressing DMG..."
    hdiutil convert "$temp_dmg" -format UDZO -o "$dmg_path"
    rm -f "$temp_dmg"
    
    if [[ -f "$dmg_path" ]]; then
        local dmg_size=$(du -h "$dmg_path" | cut -f1)
        echo -e "${GREEN}✅ Distribution DMG created: ${APP_NAME}.dmg (${dmg_size})${NC}"
        echo "  Path: $dmg_path"
        
        # Verify DMG
        echo "Verifying DMG..."
        hdiutil verify "$dmg_path"
        echo -e "${GREEN}✅ DMG verification passed${NC}"
    else
        echo -e "${RED}❌ Failed to create distribution DMG${NC}"
        exit 1
    fi
}

# Function to verify final distribution
verify_distribution() {
    echo -e "${YELLOW}🔍 Verifying distribution...${NC}"
    
    local app_path="$BUILD_DIR/${APP_NAME}.app"
    local dmg_path="$BUILD_DIR/${APP_NAME}.dmg"
    
    # Verify app signature
    echo "Checking app signature..."
    codesign --verify --deep --strict --verbose=1 "$app_path"
    
    # Verify notarization
    echo "Checking notarization..."
    xcrun stapler validate "$app_path"
    
    # Check Gatekeeper
    echo "Checking Gatekeeper assessment..."
    spctl -a -v "$app_path" || echo "  (This may fail in development environment)"
    
    # Show distribution files
    echo ""
    echo "Distribution files:"
    echo "  📱 App bundle: $app_path"
    if [[ -f "$dmg_path" ]]; then
        echo "  💿 DMG package: $dmg_path"
    fi
    if [[ -f "$BUILD_DIR/${APP_NAME}.zip" ]]; then
        echo "  📦 Zip archive: $BUILD_DIR/${APP_NAME}.zip"
    fi
    
    echo -e "${GREEN}✅ Distribution verification complete${NC}"
}

# Function to show final summary
show_final_summary() {
    echo ""
    echo -e "${GREEN}🎉 Build and Notarization Complete!${NC}"
    echo "============================================="
    echo ""
    
    local start_time="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo "⏱️  Total time: ${minutes}m ${seconds}s"
    echo ""
    
    # Show file sizes
    echo "📊 Distribution files:"
    local app_path="$BUILD_DIR/${APP_NAME}.app"
    if [[ -d "$app_path" ]]; then
        local app_size=$(du -sh "$app_path" | cut -f1)
        echo "  📱 App bundle: $app_size"
    fi
    
    local dmg_path="$BUILD_DIR/${APP_NAME}.dmg"
    if [[ -f "$dmg_path" ]]; then
        local dmg_size=$(du -sh "$dmg_path" | cut -f1)
        echo "  💿 DMG package: $dmg_size"
    fi
    
    local zip_path="$BUILD_DIR/${APP_NAME}.zip"
    if [[ -f "$zip_path" ]]; then
        local zip_size=$(du -sh "$zip_path" | cut -f1)
        echo "  📦 Zip archive: $zip_size"
    fi
    
    echo ""
    echo "🚀 Ready for distribution!"
    echo "The app is now signed, notarized, and ready for users."
    echo "No security warnings will be shown when users run the app."
    echo ""
    echo "Distribution options:"
    echo "• Upload DMG to GitHub Releases"
    echo "• Distribute via direct download"
    echo "• Share with beta testers"
    echo ""
    echo "For more information, see: docs/NOTARIZATION.md"
}

# Function to handle cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo -e "${RED}❌ Build process failed${NC}"
        echo "Check the output above for error details."
        echo ""
        echo "Common issues:"
        echo "• Missing Developer ID certificate"
        echo "• Notarization not configured (run ./scripts/setup-notarization.sh)"
        echo "• Network issues during notarization"
        echo "• Invalid app signature"
        echo ""
        echo "For troubleshooting, see: docs/NOTARIZATION.md"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Main execution function
main() {
    local clean_build=false
    local no_notarize=false
    local create_dmg=false
    local release_mode=false
    local start_time=$(date +%s)
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                clean_build=true
                shift
                ;;
            --no-notarize)
                no_notarize=true
                shift
                ;;
            --dmg)
                create_dmg=true
                shift
                ;;
            --release)
                release_mode=true
                clean_build=true
                create_dmg=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Show configuration
    echo "Build configuration:"
    echo "  Clean build: $([ "$clean_build" = true ] && echo "✅ Yes" || echo "❌ No")"
    echo "  Notarization: $([ "$no_notarize" = true ] && echo "❌ Disabled" || echo "✅ Enabled")"
    echo "  Create DMG: $([ "$create_dmg" = true ] && echo "✅ Yes" || echo "❌ No")"
    echo "  Release mode: $([ "$release_mode" = true ] && echo "✅ Yes" || echo "❌ No")"
    echo ""
    
    # Execute build stages
    if [[ "$clean_build" == true ]]; then
        clean_build
    fi
    
    build_app
    
    if [[ "$no_notarize" != true ]]; then
        notarize_app
    fi
    
    if [[ "$create_dmg" == true ]]; then
        create_distribution_dmg
    fi
    
    verify_distribution
    show_final_summary "$start_time"
}

# Run main function with all arguments
main "$@"