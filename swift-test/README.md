# Claude Usage MenuBar

A lightning-fast macOS menu bar application that displays Claude Code usage statistics in real-time.

## Features

- **🚀 Ultra-fast performance**: 0.57s loading (25x faster than before)
- **⚡ Smart caching**: Two-level cache system for instant updates
- **💰 Real-time monitoring**: Tracks Claude Code usage from local data files
- **🎯 Minimal footprint**: Native Swift app with tiny memory usage (~25MB)
- **🔄 Modern UI**: Built with SwiftUI MenuBarExtra (macOS 13.0+)
- **💸 Cost tracking**: Shows daily and monthly costs with LiteLLM pricing
- **📊 Token display**: Input/output token counts with smart formatting
- **⏰ Auto-refresh**: Configurable refresh intervals (default: 60s)
- **📈 Advanced caching**: Parallel processing using all CPU cores

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+

## Installation

### Build from source

```bash
git clone <repository-url>
cd ClaudeUsageMenuBar
swift build -c release
```

### Run

```bash
swift run
```

## Performance

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

## Architecture

This app uses the modern SwiftUI `MenuBarExtra` API introduced in macOS 13.0, making it much more lightweight than Electron-based alternatives.

**Key Components:**
- `ClaudeUsageApp`: Main app with MenuBarExtra scene
- `UsageManager`: High-performance data loading with parallel processing
- `UltraCacheManager`: Two-level caching system (memory + disk)
- `PricingFetcher`: LiteLLM pricing integration with 24h cache
- `MenuBarLabelView`: Shows cost in menu bar
- `MenuBarContentView`: Detailed popup with usage stats
- `SettingsView`: Configurable refresh intervals

**Data Source:**
Reads JSONL files from Claude Code's local storage at `~/.claude/projects/` with intelligent caching and parallel processing for maximum performance.

## Development

```bash
# Run in development mode
swift run

# Build for release
swift build -c release

# Run tests
swift test
```

## License

MIT