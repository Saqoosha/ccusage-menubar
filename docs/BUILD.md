# Build Guide

## Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ or Swift 5.9+ command line tools
- Git (for cloning the repository)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Saqoosha/ccusage-menubar.git
cd ccusage-menubar

# Option 1: Install directly to Applications folder
./scripts/install.sh

# Option 2: Just build the .app bundle
./scripts/build.sh

# Option 3: Run in development mode
./scripts/dev.sh run
```

## Build Scripts

We provide convenient build scripts for different use cases:

### 🚀 Production Build
```bash
./scripts/build.sh
```
Creates a `Claude Code Usage.app` bundle ready for distribution.

### 📱 Install to Applications
```bash
./scripts/install.sh
```
Builds and installs the app to your Applications folder.

### 🛠️ Development
```bash
# Run in development mode
./scripts/dev.sh run

# Build debug version
./scripts/dev.sh build

# Run tests
./scripts/dev.sh test

# Clean build artifacts
./scripts/dev.sh clean

# Show all available commands
./scripts/dev.sh help
```

## Manual Build (Advanced)

If you prefer to build manually:

```bash
# Build release version
swift build -c release

# Create app bundle manually
mkdir -p "Claude Code Usage.app/Contents/MacOS"
cp .build/release/ClaudeUsageMenuBar "Claude Code Usage.app/Contents/MacOS/"
cp Info.plist "Claude Code Usage.app/Contents/"
chmod +x "Claude Code Usage.app/Contents/MacOS/ClaudeUsageMenuBar"
```

## Distribution

1. **Development**: Use `swift run` for testing
2. **Local Installation**: Copy the .app bundle to Applications folder
3. **Release Distribution**: See [Release Process](RELEASE_PROCESS.md)

### First Launch (Unsigned App)

Since the app isn't code signed yet, macOS will block it on first launch. Users need to:

**Option 1 - Terminal (Recommended):**
```bash
xattr -cr /Applications/Claude\ Code\ Usage.app
```

**Option 2 - System Settings:**
- Double-click the app to trigger the security warning
- Go to System Settings > Privacy & Security
- Click "Open Anyway" next to the blocked app message

**Note**: The right-click "Open" method doesn't work for menu bar apps.

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
chmod +x "Claude Code Usage.app/Contents/MacOS/ClaudeUsageMenuBar"
```

### Runtime Issues

**App doesn't appear in menu bar**
- Look for the cost display (e.g., $0.00) in your menu bar
- If using a menu bar manager (Bartender, etc.), check there
- The app has no Dock icon (it's a menu bar only app)
- Try quitting via Activity Monitor and restarting

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