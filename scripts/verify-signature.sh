#!/bin/bash

# Claude Code Usage MenuBar - Signature Verification Script
# Verifies code signatures and notarization status

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
APP_PATH="$BUILD_DIR/${APP_NAME}.app"

echo -e "${BLUE}🔍 Claude Code Usage MenuBar - Signature Verification${NC}"
echo "=========================================================="

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS] [APP_PATH]"
    echo ""
    echo "Verify code signature and notarization status of macOS app"
    echo ""
    echo "Arguments:"
    echo "  APP_PATH       Path to .app bundle (default: build/Claude Code Usage.app)"
    echo ""
    echo "Options:"
    echo "  --verbose, -v  Show detailed verification output"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Verify default app"
    echo "  $0 --verbose                         # Verbose verification"
    echo "  $0 /path/to/MyApp.app                # Verify specific app"
    echo "  $0 --verbose /Applications/MyApp.app # Verbose verify installed app"
}

# Function to check if app exists
check_app_exists() {
    local app_path="$1"
    
    if [[ ! -d "$app_path" ]]; then
        echo -e "${RED}❌ App bundle not found: $app_path${NC}"
        echo ""
        echo "Available apps in build directory:"
        ls -la "$BUILD_DIR"/*.app 2>/dev/null || echo "  No .app bundles found"
        exit 1
    fi
    
    echo -e "${GREEN}✅ App bundle found: $app_path${NC}"
    
    # Show basic info
    local app_size=$(du -sh "$app_path" | cut -f1)
    echo "  Size: $app_size"
    
    if [[ -f "$app_path/Contents/Info.plist" ]]; then
        local bundle_id=$(plutil -p "$app_path/Contents/Info.plist" | grep CFBundleIdentifier | cut -d'"' -f4)
        local version=$(plutil -p "$app_path/Contents/Info.plist" | grep CFBundleShortVersionString | cut -d'"' -f4)
        echo "  Bundle ID: $bundle_id"
        echo "  Version: $version"
    fi
    echo ""
}

# Function to verify code signature
verify_code_signature() {
    local app_path="$1"
    local verbose="$2"
    
    echo -e "${YELLOW}🔍 Verifying code signature...${NC}"
    
    # Basic verification
    if codesign --verify --deep --strict "$app_path" 2>/dev/null; then
        echo -e "${GREEN}✅ Code signature is valid${NC}"
    else
        echo -e "${RED}❌ Code signature verification failed${NC}"
        echo ""
        echo "Detailed error:"
        codesign --verify --deep --strict --verbose=2 "$app_path" || true
        return 1
    fi
    
    # Show signature details
    echo ""
    echo "Signature details:"
    if [[ "$verbose" == true ]]; then
        codesign -dv --verbose=4 "$app_path" 2>&1
    else
        codesign -dv "$app_path" 2>&1 | head -5
    fi
    echo ""
    
    # Check hardened runtime
    local hardened_runtime=$(codesign -dv "$app_path" 2>&1 | grep -o "runtime" || echo "")
    if [[ -n "$hardened_runtime" ]]; then
        echo -e "${GREEN}✅ Hardened Runtime is enabled${NC}"
    else
        echo -e "${YELLOW}⚠️  Hardened Runtime is not enabled${NC}"
        echo "  This may prevent notarization"
    fi
    
    # Check timestamp
    local timestamp=$(codesign -dv "$app_path" 2>&1 | grep "Timestamp" || echo "")
    if [[ -n "$timestamp" ]]; then
        echo -e "${GREEN}✅ Timestamp signature present${NC}"
        if [[ "$verbose" == true ]]; then
            echo "  $timestamp"
        fi
    else
        echo -e "${YELLOW}⚠️  No timestamp signature found${NC}"
    fi
    echo ""
}

# Function to check entitlements
check_entitlements() {
    local app_path="$1"
    local verbose="$2"
    
    echo -e "${YELLOW}🔍 Checking entitlements...${NC}"
    
    local entitlements=$(codesign -d --entitlements - "$app_path" 2>/dev/null || echo "")
    
    if [[ -n "$entitlements" ]]; then
        echo -e "${GREEN}✅ Entitlements found${NC}"
        
        if [[ "$verbose" == true ]]; then
            echo ""
            echo "Entitlements:"
            codesign -d --entitlements - "$app_path" 2>/dev/null | head -50
        else
            # Show key entitlements
            local network=$(echo "$entitlements" | grep "network.client" || echo "")
            local hardened=$(echo "$entitlements" | grep "cs.allow-jit" || echo "")
            
            if [[ -n "$network" ]]; then
                echo "  • Network client access: ✅ Enabled"
            fi
            if [[ -n "$hardened" ]]; then
                echo "  • JIT disabled (hardened): ✅ Good"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  No entitlements found${NC}"
        echo "  This may be normal for simple apps"
    fi
    echo ""
}

# Function to verify notarization
verify_notarization() {
    local app_path="$1"
    local verbose="$2"
    
    echo -e "${YELLOW}🔍 Checking notarization status...${NC}"
    
    # Check if stapler ticket exists
    if xcrun stapler validate "$app_path" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Notarization ticket is stapled${NC}"
        
        if [[ "$verbose" == true ]]; then
            echo ""
            echo "Stapler validation details:"
            xcrun stapler validate "$app_path"
        fi
    else
        echo -e "${YELLOW}⚠️  No notarization ticket found${NC}"
        echo "  App may not be notarized or ticket not stapled"
        
        # Try to get more info
        local validation_output=$(xcrun stapler validate "$app_path" 2>&1 || echo "")
        if [[ "$verbose" == true && -n "$validation_output" ]]; then
            echo ""
            echo "Validation output:"
            echo "$validation_output"
        fi
    fi
    echo ""
}

# Function to test Gatekeeper
test_gatekeeper() {
    local app_path="$1"
    local verbose="$2"
    
    echo -e "${YELLOW}🔍 Testing Gatekeeper assessment...${NC}"
    
    if spctl -a -v "$app_path" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Gatekeeper assessment passed${NC}"
        
        if [[ "$verbose" == true ]]; then
            echo ""
            echo "Gatekeeper details:"
            spctl -a -v "$app_path"
        fi
    else
        echo -e "${YELLOW}⚠️  Gatekeeper assessment failed${NC}"
        
        echo ""
        echo "Gatekeeper output:"
        spctl -a -v "$app_path" || true
        
        echo ""
        echo "This may be normal if:"
        echo "• App is not notarized"
        echo "• Running in development environment"
        echo "• App was built locally"
    fi
    echo ""
}

# Function to show comprehensive summary
show_summary() {
    local app_path="$1"
    local has_signature="$2"
    local has_notarization="$3"
    local gatekeeper_passed="$4"
    
    echo -e "${BLUE}📋 Verification Summary${NC}"
    echo "========================"
    echo ""
    echo "App: $(basename "$app_path")"
    echo "Path: $app_path"
    echo ""
    
    # Security status
    echo "Security Status:"
    if [[ "$has_signature" == true ]]; then
        echo "  🔐 Code Signature: ✅ Valid"
    else
        echo "  🔐 Code Signature: ❌ Invalid/Missing"
    fi
    
    if [[ "$has_notarization" == true ]]; then
        echo "  🍎 Apple Notarization: ✅ Verified"
    else
        echo "  🍎 Apple Notarization: ❌ Not Found"
    fi
    
    if [[ "$gatekeeper_passed" == true ]]; then
        echo "  🛡️  Gatekeeper: ✅ Approved"
    else
        echo "  🛡️  Gatekeeper: ❌ Blocked"
    fi
    
    echo ""
    
    # Distribution readiness
    if [[ "$has_signature" == true && "$has_notarization" == true ]]; then
        echo -e "${GREEN}🎉 Ready for Distribution!${NC}"
        echo "This app can be safely distributed to users."
        echo "No security warnings will be shown."
    elif [[ "$has_signature" == true ]]; then
        echo -e "${YELLOW}⚠️  Partially Ready${NC}"
        echo "App is signed but not notarized."
        echo "Users may see security warnings."
        echo ""
        echo "To complete preparation:"
        echo "  ./scripts/setup-notarization.sh   # Configure notarization"
        echo "  ./scripts/notarize.sh             # Notarize the app"
    else
        echo -e "${RED}❌ Not Ready for Distribution${NC}"
        echo "App needs code signing and notarization."
        echo ""
        echo "To prepare for distribution:"
        echo "  ./scripts/setup-notarization.sh   # Configure notarization"
        echo "  ./scripts/build-and-notarize.sh   # Build and notarize"
    fi
}

# Main execution function
main() {
    local app_path="$APP_PATH"
    local verbose=false
    local has_signature=false
    local has_notarization=false
    local gatekeeper_passed=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                verbose=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                app_path="$1"
                shift
                ;;
        esac
    done
    
    # Verify app exists
    check_app_exists "$app_path"
    
    # Perform verification steps
    if verify_code_signature "$app_path" "$verbose"; then
        has_signature=true
    fi
    
    check_entitlements "$app_path" "$verbose"
    
    if verify_notarization "$app_path" "$verbose"; then
        has_notarization=true
    fi
    
    if test_gatekeeper "$app_path" "$verbose"; then
        gatekeeper_passed=true
    fi
    
    # Show summary
    show_summary "$app_path" "$has_signature" "$has_notarization" "$gatekeeper_passed"
}

# Run main function with all arguments
main "$@"