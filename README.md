# Claude Code Usage MenuBar

A lightning-fast native Swift macOS menubar application that displays [Claude Code](https://claude.ai/code) usage statistics in real-time.

## 💡 What is this?

This app monitors your Claude Code usage by reading local data files and displaying:
- **Daily/Monthly costs** - How much you've spent on Claude Code
- **Token usage** - Input/output tokens with cache statistics  
- **Real-time updates** - Live monitoring in your macOS menu bar

Perfect for tracking your Claude Code usage and managing costs efficiently!

## ✨ Features

- **🚀 Ultra-fast performance**: 0.57s loading (was 15+ seconds before optimization)
- **⚡ Smart caching**: Two-level cache system for instant updates
- **💰 Real-time monitoring**: Tracks Claude Code usage from local data files
- **🎯 Minimal footprint**: Native Swift app with tiny memory usage (~25MB)
- **🔄 Modern UI**: Built with SwiftUI MenuBarExtra (macOS 13.0+)
- **💸 Accurate cost tracking**: Shows daily and monthly costs with LiteLLM pricing
- **🌍 Currency conversion**: Real-time conversion to 33+ currencies with OS auto-detection
- **📊 Token display**: Input/output token counts with smart formatting
- **⏰ Auto-refresh**: Configurable refresh intervals (default: 60s)
- **📈 Advanced caching**: Parallel processing using all CPU cores

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/Saqoosha/ccusage-menubar.git
cd ccusage-menubar

# Install to Applications folder
./scripts/install.sh

# Or just build the app
./scripts/build.sh

# Or run in development mode
./scripts/dev.sh run
```

For detailed build instructions, see [docs/BUILD.md](docs/BUILD.md).

## ⚡ Why So Fast?

- **Native Swift**: Built specifically for macOS, not a web app
- **Smart Caching**: Remembers previous data so it doesn't re-read everything
- **Parallel Processing**: Uses all your CPU cores simultaneously
- **Efficient File Reading**: Only processes new or changed files

Result: Loads in under 1 second, even with months of usage history!

## 📁 Project Structure

```
ccusage-menubar/
├── README.md                    # Project overview
├── CLAUDE.md                    # Claude Code configuration
├── Package.swift                # Swift package manifest
├── Info.plist                   # macOS app bundle configuration
├── Sources/ClaudeUsageMenuBar/  # Main application source code
├── Tests/                       # Test scripts and Swift unit tests
├── docs/                        # Documentation files
│   ├── BUILD.md                 # Build instructions
│   ├── OPTIMIZATION_RESULTS.md  # Performance achievements
│   ├── CURRENCY_CONVERSION.md   # Currency conversion feature details
│   └── ...                      # Other documentation
├── benchmarks/                  # Performance benchmarks and CLI tools
│   ├── benchmark*.swift         # Performance test suite
│   ├── exact_ccusage.swift      # Reference implementation
│   └── ...                      # Development tools
├── tests/                       # Test scripts and validation tools
│   ├── compare_json.py          # Validation against ccusage CLI
│   ├── test_*.py                # Various test scripts
│   └── ...                      # Test utilities
└── artifacts/                   # Generated files and build outputs
```

## 💻 Requirements

- macOS 13.0 (Ventura) or later
- Claude Code installed and used (creates local usage logs)

## 📖 Documentation

- [Build Guide](docs/BUILD.md) - How to build and install the app
- [Claude Configuration](CLAUDE.md) - Technical details for developers
- [Currency Conversion](docs/CURRENCY_CONVERSION.md) - Multi-currency support details

## 🎯 Why This App?

Claude Code doesn't provide a built-in usage monitor, making it hard to track costs and usage patterns. This app solves that by:

1. ✅ **Ultra-fast Performance** - Loads usage data in under 1 second
2. ✅ **Native Swift Implementation** - Lightweight, responsive macOS experience  
3. ✅ **Accurate Cost Calculation** - Uses real LiteLLM pricing data
4. ✅ **Real-time Updates** - Shows current usage in menubar instantly
5. ✅ **Advanced Caching** - Smart two-level cache for maximum performance

## 🔍 How it Works

The app reads Claude Code's local usage logs stored in `~/.claude/projects/` and processes them to show:
- Token counts (input/output/cache)
- Daily and monthly cost calculations
- Real-time currency conversion (33+ currencies supported)
- Usage patterns and trends

All processing happens locally - no data is sent anywhere except for fetching exchange rates!