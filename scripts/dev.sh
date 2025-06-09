#!/bin/bash

# Claude Usage MenuBar - Development Script
# Quick development and testing commands

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function show_help() {
    echo -e "${BLUE}Claude Usage MenuBar - Development Script${NC}"
    echo "=================================================="
    echo ""
    echo "Usage: ./scripts/dev.sh [command]"
    echo ""
    echo "Commands:"
    echo -e "  ${GREEN}run${NC}        - Run the app in development mode"
    echo -e "  ${GREEN}build${NC}      - Build debug version"
    echo -e "  ${GREEN}test${NC}       - Run tests"
    echo -e "  ${GREEN}clean${NC}      - Clean build artifacts"
    echo -e "  ${GREEN}format${NC}     - Format Swift code (if swift-format is available)"
    echo -e "  ${GREEN}deps${NC}       - Update dependencies"
    echo -e "  ${GREEN}check${NC}      - Run quick health checks"
    echo -e "  ${GREEN}logs${NC}       - Show app logs (Console.app)"
    echo ""
    echo "Examples:"
    echo "  ./scripts/dev.sh run      # Start development server"
    echo "  ./scripts/dev.sh clean    # Clean and rebuild"
}

function run_app() {
    echo -e "${YELLOW}🚀 Running in development mode...${NC}"
    echo -e "${BLUE}💡 Press Ctrl+C to stop${NC}"
    echo ""
    swift run
}

function build_debug() {
    echo -e "${YELLOW}🔨 Building debug version...${NC}"
    swift build
    echo -e "${GREEN}✅ Debug build completed${NC}"
}

function run_tests() {
    echo -e "${YELLOW}🧪 Running tests...${NC}"
    swift test
    echo -e "${GREEN}✅ Tests completed${NC}"
}

function clean_build() {
    echo -e "${YELLOW}🧹 Cleaning build artifacts...${NC}"
    swift package clean
    rm -rf .build
    rm -rf "Claude Usage.app"
    echo -e "${GREEN}✅ Clean completed${NC}"
}

function format_code() {
    if command -v swift-format &> /dev/null; then
        echo -e "${YELLOW}🎨 Formatting Swift code...${NC}"
        find Sources -name "*.swift" -exec swift-format -i {} \;
        echo -e "${GREEN}✅ Code formatted${NC}"
    else
        echo -e "${YELLOW}⚠️  swift-format not found. Install with: brew install swift-format${NC}"
    fi
}

function update_deps() {
    echo -e "${YELLOW}📦 Updating dependencies...${NC}"
    swift package update
    echo -e "${GREEN}✅ Dependencies updated${NC}"
}

function health_check() {
    echo -e "${YELLOW}🔍 Running health checks...${NC}"
    echo ""
    
    # Check Swift version
    echo -e "${BLUE}Swift Version:${NC}"
    swift --version
    echo ""
    
    # Check Package.swift
    if [[ -f "Package.swift" ]]; then
        echo -e "${GREEN}✅ Package.swift found${NC}"
    else
        echo -e "${RED}❌ Package.swift missing${NC}"
    fi
    
    # Check Info.plist
    if [[ -f "Info.plist" ]]; then
        echo -e "${GREEN}✅ Info.plist found${NC}"
    else
        echo -e "${RED}❌ Info.plist missing${NC}"
    fi
    
    # Check Sources directory
    if [[ -d "Sources/ClaudeUsageMenuBar" ]]; then
        SOURCE_COUNT=$(find Sources/ClaudeUsageMenuBar -name "*.swift" | wc -l)
        echo -e "${GREEN}✅ Sources found (${SOURCE_COUNT} Swift files)${NC}"
    else
        echo -e "${RED}❌ Sources directory missing${NC}"
    fi
    
    # Check macOS version
    echo ""
    echo -e "${BLUE}macOS Version:${NC}"
    sw_vers -productVersion
    
    # Check if we can build (compile check only)
    echo ""
    echo -e "${YELLOW}🔨 Testing build configuration...${NC}"
    if swift package dump-package &> /dev/null; then
        echo -e "${GREEN}✅ Package configuration valid${NC}"
    else
        echo -e "${RED}❌ Package configuration issues${NC}"
    fi
}

function show_logs() {
    echo -e "${YELLOW}📋 Opening Console.app for app logs...${NC}"
    echo -e "${BLUE}💡 Filter by 'ClaudeUsageMenuBar' or 'Claude Usage' to see app logs${NC}"
    open -a Console
}

# Check if we're in the right directory
if [[ ! -f "Package.swift" ]]; then
    echo -e "${RED}❌ Error: Package.swift not found. Please run this script from the project root.${NC}"
    exit 1
fi

# Parse command
case "${1:-help}" in
    "run")
        run_app
        ;;
    "build")
        build_debug
        ;;
    "test")
        run_tests
        ;;
    "clean")
        clean_build
        ;;
    "format")
        format_code
        ;;
    "deps")
        update_deps
        ;;
    "check")
        health_check
        ;;
    "logs")
        show_logs
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac