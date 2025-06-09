# Build Guide

## Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ or Swift 5.9+ command line tools
- Git (for cloning the repository)

## Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd ccusage-menubar

# Build the application
swift build -c release

# Create the .app bundle
./scripts/create-app-bundle.sh

# Or run directly in development mode
swift run
```

## Development Build

```bash
# Build for development (with debug symbols)
swift build

# Run in development mode
swift run

# Run tests
swift test
```

## Release Build

```bash
# Build optimized release version
swift build -c release

# The executable will be located at:
# .build/release/ClaudeUsageMenuBar
```

## Creating App Bundle

To create a standard macOS app bundle:

```bash
# Create app bundle structure
mkdir -p "Claude Usage.app/Contents/MacOS"

# Copy executable
cp .build/release/ClaudeUsageMenuBar "Claude Usage.app/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "Claude Usage.app/Contents/"

# Set executable permissions
chmod +x "Claude Usage.app/Contents/MacOS/ClaudeUsageMenuBar"
```

## Distribution

1. **Development**: Use `swift run` for testing
2. **Local Installation**: Copy the .app bundle to Applications folder
3. **Release Distribution**: Upload .app bundle to GitHub Releases

## Project Structure

```
ccusage-menubar/
├── README.md                    # Project overview
├── CLAUDE.md                    # Claude Code configuration
├── Package.swift                # Swift package manifest
├── Info.plist                   # macOS app bundle configuration
├── Sources/ClaudeUsageMenuBar/  # Main application source code
├── Tests/                       # Test scripts and Swift unit tests
├── docs/                        # Documentation files
├── benchmarks/                  # Performance benchmarks and CLI tools
└── artifacts/                   # Generated files and build outputs
```

## Troubleshooting

### Build Issues

**Error: Missing dependencies**
```bash
swift package update
swift package clean
swift build
```

**Error: Permission denied**
```bash
chmod +x "Claude Usage.app/Contents/MacOS/ClaudeUsageMenuBar"
```

### Runtime Issues

**App doesn't appear in menu bar**
- Check System Settings → Control Center → Menu Bar items
- Ensure app has proper permissions
- Try quitting and restarting the app

**Performance issues**
- Clear cache: `rm -rf ~/.claude_ultra_cache/`
- Check available disk space
- Verify ~/.claude/projects/ directory exists

## Performance

- **First load**: ~0.57s (builds cache)
- **Subsequent loads**: ~0.1s (ultra-fast with cache)
- **Memory usage**: 25-50MB
- **Cache hit rate**: 99.5% after first run

## Build Configurations

### Debug Build
- Includes debug symbols
- Larger binary size
- Detailed error messages
- Slower execution

### Release Build  
- Optimized for performance
- Smaller binary size
- Minimal debug information
- Fastest execution (recommended for distribution)