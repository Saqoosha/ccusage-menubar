#!/bin/bash

# Claude Code Usage MenuBar - Notarization Setup Script
# Configures Apple Developer credentials and certificates for notarization

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
TEMPLATE_FILE="$CONFIG_DIR/.notarization-config.template"

echo -e "${BLUE}🍎 Claude Code Usage MenuBar - Notarization Setup${NC}"
echo "========================================================="

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Function to check if Xcode is installed
check_xcode() {
    echo -e "${YELLOW}🔍 Checking Xcode installation...${NC}"
    
    if ! command -v xcrun &> /dev/null; then
        echo -e "${RED}❌ Error: Xcode command line tools not found${NC}"
        echo "Please install Xcode or Xcode command line tools:"
        echo "  xcode-select --install"
        exit 1
    fi
    
    # Check notarytool availability
    if ! xcrun notarytool --help &> /dev/null; then
        echo -e "${RED}❌ Error: notarytool not available${NC}"
        echo "Please update to Xcode 13 or later for notarytool support"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Xcode and notarytool are available${NC}"
}

# Function to check Developer ID certificates
check_certificates() {
    echo -e "${YELLOW}🔍 Checking Developer ID certificates...${NC}"
    
    # List available Developer ID Application certificates
    local certs=$(security find-identity -v -p codesigning | grep "Developer ID Application" || true)
    
    if [[ -z "$certs" ]]; then
        echo -e "${RED}❌ No Developer ID Application certificates found${NC}"
        echo ""
        echo "To get a Developer ID certificate:"
        echo "1. Join the Apple Developer Program ($99/year)"
        echo "2. Go to https://developer.apple.com/account/resources/certificates"
        echo "3. Create a 'Developer ID Application' certificate"
        echo "4. Download and install it in Keychain Access"
        echo ""
        echo "Available certificates:"
        security find-identity -v -p codesigning | head -10
        exit 1
    fi
    
    echo -e "${GREEN}✅ Found Developer ID Application certificates:${NC}"
    echo "$certs"
    echo ""
}

# Function to get Team ID from certificate
get_team_id() {
    local cert_name="$1"
    local team_id=$(echo "$cert_name" | grep -oE '\([A-Z0-9]{10}\)' | tr -d '()')
    echo "$team_id"
}

# Function to create configuration template
create_config_template() {
    echo -e "${YELLOW}📝 Creating configuration template...${NC}"
    
    cat > "$TEMPLATE_FILE" << 'EOF'
# Apple Notarization Configuration
# Copy this file to .notarization-config and fill in your details

# Apple Developer Account
APPLE_ID="your-apple-id@example.com"
TEAM_ID="YOUR_TEAM_ID"  # 10-character team ID from Developer Portal

# App Information
BUNDLE_ID="sh.saqoo.claude-usage-menubar"
APP_NAME="Claude Code Usage"

# Code Signing
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"

# Notarization Profile Name (will be created)
NOTARY_PROFILE="claude-usage-notary"

# Optional: App-specific password (recommended to use keychain profile instead)
# APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # Generate at appleid.apple.com
EOF
    
    echo -e "${GREEN}✅ Configuration template created at:${NC}"
    echo "   $TEMPLATE_FILE"
}

# Function to interactive configuration
interactive_setup() {
    echo -e "${YELLOW}🔧 Interactive Configuration Setup${NC}"
    echo ""
    
    # Check if config already exists
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}⚠️  Configuration file already exists:${NC}"
        echo "   $CONFIG_FILE"
        read -p "Do you want to overwrite it? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Keeping existing configuration."
            return 0
        fi
    fi
    
    echo "Let's set up your Apple Developer credentials:"
    echo ""
    
    # Get Apple ID
    read -p "Enter your Apple ID (email): " apple_id
    while [[ ! "$apple_id" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
        echo -e "${RED}Invalid email format${NC}"
        read -p "Enter your Apple ID (email): " apple_id
    done
    
    # Show available certificates and let user choose
    echo ""
    echo "Available Developer ID Application certificates:"
    security find-identity -v -p codesigning | grep "Developer ID Application" | nl -w2 -s". "
    echo ""
    
    read -p "Enter the number of the certificate to use: " cert_num
    local selected_cert=$(security find-identity -v -p codesigning | grep "Developer ID Application" | sed -n "${cert_num}p")
    
    if [[ -z "$selected_cert" ]]; then
        echo -e "${RED}❌ Invalid certificate selection${NC}"
        exit 1
    fi
    
    # Extract certificate details
    local signing_identity=$(echo "$selected_cert" | sed 's/^[[:space:]]*[0-9]*)[[:space:]]*//' | sed 's/"//g')
    local team_id=$(get_team_id "$selected_cert")
    
    if [[ -z "$team_id" ]]; then
        echo -e "${YELLOW}⚠️  Could not extract Team ID from certificate${NC}"
        read -p "Enter your Team ID manually (10 characters): " team_id
    fi
    
    echo ""
    echo -e "${GREEN}Selected certificate:${NC}"
    echo "  Signing Identity: $signing_identity"
    echo "  Team ID: $team_id"
    echo ""
    
    # Create the configuration file
    cat > "$CONFIG_FILE" << EOF
# Apple Notarization Configuration
# Generated by setup-notarization.sh

# Apple Developer Account
APPLE_ID="$apple_id"
TEAM_ID="$team_id"

# App Information
BUNDLE_ID="sh.saqoo.claude-usage-menubar"
APP_NAME="Claude Code Usage"

# Code Signing
SIGNING_IDENTITY="$signing_identity"

# Notarization Profile Name
NOTARY_PROFILE="claude-usage-notary"

# App-specific password (optional - use keychain profile instead)
# APP_PASSWORD=""  # Generate at appleid.apple.com
EOF
    
    echo -e "${GREEN}✅ Configuration saved to:${NC}"
    echo "   $CONFIG_FILE"
    echo ""
}

# Function to setup notarytool profile
setup_notary_profile() {
    echo -e "${YELLOW}🔑 Setting up notarytool keychain profile...${NC}"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}❌ Configuration file not found: $CONFIG_FILE${NC}"
        echo "Please run the interactive setup first."
        return 1
    fi
    
    # Source the configuration
    source "$CONFIG_FILE"
    
    # Check if profile already exists
    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &> /dev/null; then
        echo -e "${GREEN}✅ Notarytool profile '$NOTARY_PROFILE' already exists${NC}"
        return 0
    fi
    
    echo ""
    echo "To create a notarytool profile, you need an app-specific password."
    echo "Generate one at: https://appleid.apple.com/account/manage (Sign-In and Security section)"
    echo ""
    read -s -p "Enter your app-specific password: " app_password
    echo ""
    
    if [[ -z "$app_password" ]]; then
        echo -e "${RED}❌ App-specific password cannot be empty${NC}"
        return 1
    fi
    
    # Create the notarytool profile
    echo -e "${YELLOW}Creating notarytool profile...${NC}"
    xcrun notarytool store-credentials "$NOTARY_PROFILE" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$app_password"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Notarytool profile '$NOTARY_PROFILE' created successfully${NC}"
    else
        echo -e "${RED}❌ Failed to create notarytool profile${NC}"
        return 1
    fi
}

# Function to verify setup
verify_setup() {
    echo -e "${YELLOW}🔍 Verifying notarization setup...${NC}"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}❌ Configuration file not found${NC}"
        return 1
    fi
    
    source "$CONFIG_FILE"
    
    # Check notarytool profile
    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &> /dev/null; then
        echo -e "${GREEN}✅ Notarytool profile '$NOTARY_PROFILE' is working${NC}"
    else
        echo -e "${RED}❌ Notarytool profile '$NOTARY_PROFILE' is not working${NC}"
        return 1
    fi
    
    # Check code signing identity
    if security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
        echo -e "${GREEN}✅ Code signing identity is available${NC}"
    else
        echo -e "${RED}❌ Code signing identity not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Notarization setup is complete and verified${NC}"
}

# Main execution
main() {
    check_xcode
    check_certificates
    create_config_template
    
    echo ""
    echo "Setup options:"
    echo "1. Interactive setup (recommended for first time)"
    echo "2. Setup notarytool profile only"
    echo "3. Verify existing setup"
    echo "4. Exit"
    echo ""
    
    read -p "Choose an option (1-4): " choice
    
    case $choice in
        1)
            interactive_setup
            setup_notary_profile
            verify_setup
            ;;
        2)
            setup_notary_profile
            ;;
        3)
            verify_setup
            ;;
        4)
            echo "Exiting setup."
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}🎉 Notarization setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review your configuration: $CONFIG_FILE"
    echo "2. Use ./scripts/notarize.sh to notarize your app"
    echo "3. Use ./scripts/build-and-notarize.sh for complete build + notarization"
    echo ""
    echo "For more information, see: docs/NOTARIZATION.md"
}

# Run main function
main "$@"