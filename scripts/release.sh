#!/bin/bash

# Claude Code Usage MenuBar - Release Script
# Automates the release process including version bumping, tagging, and GitHub release

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
APP_NAME="Claude Code Usage"
EXECUTABLE_NAME="ClaudeUsageMenuBar"

# Change to project directory
cd "$PROJECT_DIR"

echo -e "${BLUE}🚀 Claude Code Usage MenuBar - Release Tool${NC}"
echo "=================================================="

# Function to show help
show_help() {
    echo "Usage: $0 [VERSION_BUMP] [OPTIONS]"
    echo ""
    echo "VERSION_BUMP:"
    echo "  major     Bump major version (1.0.0 -> 2.0.0)"
    echo "  minor     Bump minor version (1.0.0 -> 1.1.0)"
    echo "  patch     Bump patch version (1.0.0 -> 1.0.1) [default]"
    echo "  x.y.z     Set specific version (e.g., 1.2.3)"
    echo ""
    echo "OPTIONS:"
    echo "  --no-build    Skip building the app"
    echo "  --no-github   Skip creating GitHub release"
    echo "  --draft       Create GitHub release as draft"
    echo "  --yes, -y     Non-interactive mode (auto-confirm all prompts)"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Bump patch version and release"
    echo "  $0 minor        # Bump minor version and release"
    echo "  $0 1.2.0        # Set version to 1.2.0 and release"
    echo "  $0 patch --draft # Create draft release"
    echo "  $0 1.0.0 --yes  # Non-interactive release"
}

# Function to bump version
bump_version() {
    local current_version=$1
    local bump_type=$2
    
    # Parse current version
    IFS='.' read -r major minor patch <<< "$current_version"
    
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            # Assume it's a specific version
            echo "$bump_type"
            return
            ;;
    esac
    
    echo "${major}.${minor}.${patch}"
}

# Function to update version files
update_version() {
    local new_version=$1
    
    echo -e "${YELLOW}📝 Updating version to ${new_version}...${NC}"
    
    # Update VERSION file
    echo "$new_version" > VERSION
    echo -e "${GREEN}✅ Updated VERSION file${NC}"
}

# Function to build the app
build_app() {
    echo -e "${YELLOW}🔨 Building release...${NC}"
    
    # Run build script
    if ./scripts/build.sh; then
        echo -e "${GREEN}✅ Build completed successfully${NC}"
        
        # Test the built app
        echo -e "${YELLOW}🧪 Testing built app...${NC}"
        local app_path="build/${APP_NAME}.app"
        
        # Remove quarantine attribute for testing
        xattr -cr "$app_path" 2>/dev/null || true
        
        # Try to launch the app briefly
        if timeout 3s "$app_path/Contents/MacOS/${EXECUTABLE_NAME}" 2>/dev/null; then
            echo -e "${GREEN}✅ App launches successfully${NC}"
        else
            # Check if it failed due to timeout (which is expected) or actual error
            if [[ $? -eq 124 ]]; then
                echo -e "${GREEN}✅ App launches successfully (timeout expected)${NC}"
            else
                echo -e "${RED}❌ App failed to launch - please test manually${NC}"
                echo "You may need to check code signing or other issues"
                return 1
            fi
        fi
        
        return 0
    else
        echo -e "${RED}❌ Build failed${NC}"
        return 1
    fi
}

# Function to create zip archive
create_archive() {
    local version=$1
    local app_path="build/${APP_NAME}.app"
    local zip_name="${APP_NAME// /-}-v${version}.zip"  # Replace spaces with hyphens
    
    echo -e "${YELLOW}📦 Creating zip archive...${NC}"
    
    # Create zip in build directory
    (cd build && zip -r "$zip_name" "${APP_NAME}.app" -x "*.DS_Store")
    
    if [[ -f "build/$zip_name" ]]; then
        local zip_size=$(du -h "build/$zip_name" | cut -f1)
        echo -e "${GREEN}✅ Created archive: $zip_name ($zip_size)${NC}"
        echo "build/$zip_name"
    else
        echo -e "${RED}❌ Failed to create archive${NC}"
        return 1
    fi
}

# Function to commit and tag
create_git_tag() {
    local version=$1
    local tag="v${version}"
    
    echo -e "${YELLOW}🏷️  Creating git tag ${tag}...${NC}"
    
    # Check for uncommitted changes
    if [[ -n $(git status -s) ]]; then
        echo -e "${YELLOW}📝 Committing version bump...${NC}"
        git add VERSION
        git commit -m "chore: bump version to ${version}"
    fi
    
    # Create tag
    git tag -a "$tag" -m "Release ${tag}"
    echo -e "${GREEN}✅ Created tag: ${tag}${NC}"
    
    # Push changes and tag
    echo -e "${YELLOW}📤 Pushing to remote...${NC}"
    git push origin main
    git push origin "$tag"
    echo -e "${GREEN}✅ Pushed changes and tag${NC}"
}

# Function to generate release notes
generate_release_notes() {
    local version=$1
    local previous_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    echo "## What's Changed"
    echo ""
    
    if [[ -n "$previous_tag" ]]; then
        # Get commit messages since last tag
        git log "${previous_tag}..HEAD" --pretty=format:"- %s" | grep -v "^- chore: bump version" || true
    else
        # First release - get all commits
        git log --pretty=format:"- %s" | head -20
    fi
    
    echo ""
    echo ""
    echo "## Installation"
    echo ""
    echo "1. Download \`${APP_NAME}-v${version}.zip\`"
    echo "2. Unzip the archive"
    echo "3. Move \`${APP_NAME}.app\` to your Applications folder"
    echo "4. Launch the app (you may need to right-click and select 'Open' the first time)"
    echo ""
    echo "## System Requirements"
    echo "- macOS 13.0 or later"
    echo "- Claude Code installed and configured"
}

# Function to create GitHub release
create_github_release() {
    local version=$1
    local tag="v${version}"
    local zip_path=$2
    local draft_flag=$3
    
    echo -e "${YELLOW}🚀 Creating GitHub release...${NC}"
    
    # Check if gh is installed
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI (gh) not found${NC}"
        echo "Install with: brew install gh"
        echo "Then authenticate with: gh auth login"
        return 1
    fi
    
    # Generate release notes
    local release_notes=$(generate_release_notes "$version")
    
    # Create release
    local gh_args=(
        "$tag"
        --title "Release ${tag}"
        --notes "$release_notes"
    )
    
    if [[ "$draft_flag" == "--draft" ]]; then
        gh_args+=(--draft)
    fi
    
    # Add the zip file
    gh_args+=("$zip_path")
    
    if gh release create "${gh_args[@]}"; then
        echo -e "${GREEN}✅ GitHub release created successfully${NC}"
        echo -e "${GREEN}🔗 View at: $(gh release view "$tag" --json url -q .url)${NC}"
    else
        echo -e "${RED}❌ Failed to create GitHub release${NC}"
        return 1
    fi
}

# Main execution
main() {
    local version_bump="patch"
    local skip_build=false
    local skip_github=false
    local draft_flag=""
    local non_interactive=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-build)
                skip_build=true
                shift
                ;;
            --no-github)
                skip_github=true
                shift
                ;;
            --draft)
                draft_flag="--draft"
                shift
                ;;
            --yes|-y)
                non_interactive=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            major|minor|patch)
                version_bump=$1
                shift
                ;;
            [0-9]*.[0-9]*.[0-9]*)
                version_bump=$1
                shift
                ;;
            *)
                echo -e "${RED}❌ Unknown argument: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check for clean working directory
    if [[ -n $(git status -s) ]]; then
        echo -e "${YELLOW}⚠️  Warning: You have uncommitted changes${NC}"
        echo "These will be included in the version bump commit."
        if [[ "$non_interactive" != true ]]; then
            read -p "Continue? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Aborted."
                exit 1
            fi
        else
            echo "Continuing in non-interactive mode..."
        fi
    fi
    
    # Get current version
    if [[ ! -f VERSION ]]; then
        echo -e "${RED}❌ VERSION file not found${NC}"
        exit 1
    fi
    
    current_version=$(cat VERSION)
    echo "Current version: ${current_version}"
    
    # Calculate new version
    new_version=$(bump_version "$current_version" "$version_bump")
    echo "New version: ${new_version}"
    echo ""
    
    # Confirm release
    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Update version to ${new_version}"
    if [[ "$skip_build" != true ]]; then
        echo "  2. Build the app"
    fi
    echo "  3. Create git tag v${new_version}"
    echo "  4. Push changes to GitHub"
    if [[ "$skip_github" != true ]]; then
        echo "  5. Create GitHub release${draft_flag:+ (draft)}"
    fi
    echo ""
    if [[ "$non_interactive" != true ]]; then
        read -p "Proceed with release? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    else
        echo "Proceeding in non-interactive mode..."
    fi
    
    echo ""
    
    # Execute release steps
    update_version "$new_version"
    
    if [[ "$skip_build" != true ]]; then
        if ! build_app; then
            echo -e "${RED}❌ Build failed, aborting release${NC}"
            git checkout VERSION
            exit 1
        fi
    fi
    
    # Create archive
    zip_path=$(create_archive "$new_version")
    if [[ -z "$zip_path" ]]; then
        echo -e "${RED}❌ Failed to create archive, aborting release${NC}"
        git checkout VERSION
        exit 1
    fi
    
    # Create git tag
    create_git_tag "$new_version"
    
    # Create GitHub release
    if [[ "$skip_github" != true ]]; then
        create_github_release "$new_version" "$zip_path" "$draft_flag"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Release ${new_version} completed successfully!${NC}"
    echo "=================================================="
    echo ""
    echo "Next steps:"
    if [[ "$draft_flag" == "--draft" ]]; then
        echo "• Review and publish the draft release on GitHub"
    fi
    echo "• Announce the release"
    echo "• Update documentation if needed"
}

# Run main function with all arguments
main "$@"