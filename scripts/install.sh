#!/bin/bash

# Claude Usage MenuBar - Install Script
# Builds and installs the app to Applications folder

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME="Claude Code Usage"

echo -e "${BLUE}🚀 Installing Claude Code Usage MenuBar${NC}"
echo "=================================================="

# Check if we're in the right directory
if [[ ! -f "Package.swift" ]]; then
    echo -e "${RED}❌ Error: Package.swift not found. Please run this script from the project root.${NC}"
    exit 1
fi

# Build the app first
echo -e "${YELLOW}🔨 Building app...${NC}"
./scripts/build.sh

# Check if app bundle exists
if [[ ! -d "${APP_NAME}.app" ]]; then
    echo -e "${RED}❌ Error: App bundle not found after build${NC}"
    exit 1
fi

# Check if Applications directory is writable
if [[ ! -w "/Applications" ]]; then
    echo -e "${YELLOW}🔐 Need administrator permissions to install to Applications folder${NC}"
    INSTALL_CMD="sudo cp -r"
else
    INSTALL_CMD="cp -r"
fi

# Remove existing installation if it exists
if [[ -d "/Applications/${APP_NAME}.app" ]]; then
    echo -e "${YELLOW}🗑️  Removing existing installation...${NC}"
    if [[ ! -w "/Applications" ]]; then
        sudo rm -rf "/Applications/${APP_NAME}.app"
    else
        rm -rf "/Applications/${APP_NAME}.app"
    fi
fi

# Install the app
echo -e "${YELLOW}📦 Installing to Applications folder...${NC}"
$INSTALL_CMD "${APP_NAME}.app" /Applications/

# Verify installation
if [[ -d "/Applications/${APP_NAME}.app" ]]; then
    echo ""
    echo -e "${GREEN}✅ Installation completed successfully!${NC}"
    echo "=================================================="
    echo -e "${GREEN}📱 App installed to: /Applications/${APP_NAME}.app${NC}"
    echo ""
    echo -e "${BLUE}🎯 Next Steps:${NC}"
    echo "1. Launch from Applications folder"
    echo "2. Or run: open '/Applications/${APP_NAME}.app'"
    echo "3. Look for the 💰 icon in your menu bar"
    echo ""
    echo -e "${YELLOW}💡 Tip: You can now launch it from Spotlight or Launchpad${NC}"
    
    # Ask if user wants to launch now
    echo ""
    read -p "🚀 Would you like to launch the app now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
echo -e "${YELLOW}🚀 Launching Claude Code Usage MenuBar...${NC}"
        open "/Applications/${APP_NAME}.app"
    fi
else
    echo -e "${RED}❌ Installation failed: App not found in Applications folder${NC}"
    exit 1
fi