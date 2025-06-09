# Claude Usage MenuBar

A lightning-fast native Swift macOS menubar application that displays Claude Code usage statistics in real-time.

## ✨ Features

- **🚀 Ultra-fast performance**: 0.57s loading (25x faster than original)
- **⚡ Smart caching**: Two-level cache system for instant updates
- **💰 Real-time monitoring**: Tracks Claude Code usage from local data files
- **🎯 Minimal footprint**: Native Swift app with tiny memory usage (~25MB)
- **🔄 Modern UI**: Built with SwiftUI MenuBarExtra (macOS 13.0+)
- **💸 Accurate cost tracking**: Shows daily and monthly costs with LiteLLM pricing
- **📊 Token display**: Input/output token counts with smart formatting
- **⏰ Auto-refresh**: Configurable refresh intervals (default: 60s)
- **📈 Advanced caching**: Parallel processing using all CPU cores

## 🚀 Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd ccusage-menubar

# Run the menubar app
swift run

# Or build for release
swift build -c release
```

For detailed build instructions, see [docs/BUILD.md](docs/BUILD.md).

## 📊 Performance

**🚀 Ultra-Fast Loading:**
- Initial load: 0.57s (25x faster than original 15s)
- Cached loads: 0.002s (7,500x improvement!)
- Processes 200+ files (198MB) efficiently
- 99.5% cache hit rate after first run

**🎯 Key Optimizations:**
- **Parallel Processing**: Uses all CPU cores for file processing
- **Two-Level Caching**: Memory (NSCache) + Disk cache for instant access
- **Smart File Filtering**: Skips old files, processes only recent data
- **Optimized Parsing**: Batch processing with autoreleasepool
- **24h Pricing Cache**: Automatic LiteLLM pricing updates

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

## 🔧 Development

**Requirements:**
- macOS 13.0+ (for MenuBarExtra API)
- Swift 5.9+ or Xcode 15.0+
- Git (for cloning)

**Architecture:**
- Native SwiftUI with MenuBarExtra scene
- High-performance parallel data processing
- Two-level caching system (memory + disk)
- LiteLLM pricing integration with auto-refresh
- Async/await throughout for responsive UI

## 📖 Documentation

- [Build Guide](docs/BUILD.md) - Complete build and installation instructions
- [Performance Results](docs/OPTIMIZATION_RESULTS.md) - Detailed performance achievements
- [Future Improvements](docs/FUTURE_IMPROVEMENTS.md) - Planned enhancements
- [Claude Configuration](CLAUDE.md) - Claude Code integration details

## 🎯 Goals Achieved

1. ✅ **Ultra-fast Performance** - 25x speed improvement over original
2. ✅ **Native Swift Implementation** - Lightweight, responsive experience  
3. ✅ **Accurate Cost Calculation** - Matches ccusage CLI exactly
4. ✅ **Real-time Updates** - Shows current usage in menubar instantly
5. ✅ **Advanced Caching** - Smart two-level cache for maximum performance