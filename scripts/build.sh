#!/bin/bash

# Claude Usage MenuBar - Build Script
# Creates a ready-to-distribute .app bundle

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Claude Usage"
BUNDLE_ID="sh.saqoo.claude-usage-menubar"
VERSION="1.0.0"
EXECUTABLE_NAME="ClaudeUsageMenuBar"

echo -e "${BLUE}🚀 Building Claude Usage MenuBar${NC}"
echo "=================================================="

# Check if we're in the right directory
if [[ ! -f "Package.swift" ]]; then
    echo -e "${RED}❌ Error: Package.swift not found. Please run this script from the project root.${NC}"
    exit 1
fi

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf ".build"
rm -rf "${APP_NAME}.app"

# Build the project
echo -e "${YELLOW}🔨 Building release version...${NC}"
swift build -c release

# Check if build succeeded
if [[ ! -f ".build/release/${EXECUTABLE_NAME}" ]]; then
    echo -e "${RED}❌ Build failed: Executable not found${NC}"
    exit 1
fi

# Create app bundle structure
echo -e "${YELLOW}📦 Creating app bundle...${NC}"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"

# Copy executable
cp ".build/release/${EXECUTABLE_NAME}" "${APP_NAME}.app/Contents/MacOS/"

# Copy Info.plist
cp "Info.plist" "${APP_NAME}.app/Contents/"

# Set executable permissions
chmod +x "${APP_NAME}.app/Contents/MacOS/${EXECUTABLE_NAME}"

# Verify the app bundle
echo -e "${YELLOW}🔍 Verifying app bundle...${NC}"

# Check bundle structure
if [[ ! -f "${APP_NAME}.app/Contents/MacOS/${EXECUTABLE_NAME}" ]]; then
    echo -e "${RED}❌ Error: Executable missing from bundle${NC}"
    exit 1
fi

if [[ ! -f "${APP_NAME}.app/Contents/Info.plist" ]]; then
    echo -e "${RED}❌ Error: Info.plist missing from bundle${NC}"
    exit 1
fi

# Test launch (quick test)
echo -e "${YELLOW}🧪 Testing app launch...${NC}"
timeout 3s "${APP_NAME}.app/Contents/MacOS/${EXECUTABLE_NAME}" || true

# Calculate bundle size
BUNDLE_SIZE=$(du -sh "${APP_NAME}.app" | cut -f1)

echo ""
echo -e "${GREEN}✅ Build completed successfully!${NC}"
echo "=================================================="
echo -e "${GREEN}📱 App Bundle: ${APP_NAME}.app${NC}"
echo -e "${GREEN}📏 Size: ${BUNDLE_SIZE}${NC}"
echo -e "${GREEN}🆔 Bundle ID: ${BUNDLE_ID}${NC}"
echo -e "${GREEN}📦 Version: ${VERSION}${NC}"
echo ""
echo -e "${BLUE}🎯 Next Steps:${NC}"
echo "1. Test the app: open '${APP_NAME}.app'"
echo "2. Copy to Applications: cp -r '${APP_NAME}.app' /Applications/"
echo "3. Or distribute via GitHub Releases"
echo ""
echo -e "${YELLOW}💡 Tip: You can also run 'scripts/install.sh' to install directly${NC}"