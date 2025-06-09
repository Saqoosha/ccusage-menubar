# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A native macOS menu bar application built with Swift and SwiftUI that monitors Claude Code usage statistics in real-time. Uses the modern MenuBarExtra API for lightweight, native integration.

## Development Commands

**Building and Running:**
- `swift build` - Build the project
- `swift build -c release` - Build for release
- `swift run` - Run the application
- `swift test` - Run tests

**Package Management:**
- `swift package update` - Update dependencies
- `swift package clean` - Clean build artifacts

## Architecture

**Modern SwiftUI Approach:**
- Uses `MenuBarExtra` scene (macOS 13.0+) instead of traditional NSStatusItem
- No main window - purely menu bar focused
- Declarative SwiftUI throughout

**Key Files:**
- `ClaudeUsageApp.swift` - Main app entry point with MenuBarExtra scene
- `UsageManager.swift` - Data loading and management (ObservableObject)
- `MenuBarLabelView.swift` - Menu bar display (cost + icon)  
- `MenuBarContentView.swift` - Popup content with detailed stats
- `SettingsView.swift` - Settings window
- `CacheManager.swift` - Two-level caching system (NEW)
- `PricingFetcher.swift` - LiteLLM pricing integration

**Data Flow:**
1. `UsageManager` scans `~/.claude/projects/` for .jsonl files
2. Checks cache first (memory → disk → parse)
3. Processes files in parallel using all CPU cores
4. Aggregates daily/monthly statistics
5. Updates SwiftUI views via `@Published` properties
6. Auto-refreshes based on user settings

## Claude Code Integration

**Data Source:** `~/.claude/projects/**/*.jsonl`

**Expected JSON Format:**
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "message": {
    "usage": {
      "input_tokens": 1000,
      "output_tokens": 500,
      "cache_creation_input_tokens": 100,
      "cache_read_input_tokens": 50
    },
    "model": "claude-3-sonnet-20240229"
  },
  "costUSD": 0.015
}
```

**Cost Calculation:**
- Uses exact ccusage logic (auto mode)
- Fetches latest pricing from LiteLLM on every run
- Accurate model-specific pricing
- Special handling for cache tokens

## Performance Status ✅ RESOLVED

**Achieved Performance:**
- **Initial load**: 1.68 seconds (faster than ccusage!)
- **Cached load**: 0.002 seconds (842x faster than ccusage!)
- **Memory usage**: 25-50MB

**Key Optimizations Implemented:**
1. **Parallel Processing** - 5.5x speedup using all CPU cores
2. **Fast Date Extraction** - String slicing instead of DateFormatter
3. **Two-Level Caching** - Memory (2ms) + Disk (5ms) cache
4. **Smart File Filtering** - Skip old files, early exit
5. **Optimized Parsing** - Batch processing with autoreleasepool

**Performance Characteristics:**
- Handles 200+ files (198MB) efficiently
- Processes ~2,700 daily entries
- 99.5% cache hit rate after first run
- Near-instant UI updates

## Development Setup

**Prerequisites:**
- Xcode 15.0+ or Swift 5.9+ command line tools
- macOS 13.0+ (for MenuBarExtra API)

**Project Structure:**
```
ClaudeUsageMenuBar/
├── Package.swift          # SPM manifest
├── Sources/
│   └── ClaudeUsageMenuBar/
│       ├── ClaudeUsageApp.swift     # @main entry point
│       ├── UsageManager.swift       # Data management
│       ├── CacheManager.swift       # Two-level cache (NEW)
│       ├── PricingFetcher.swift     # LiteLLM integration
│       ├── MenuBarLabelView.swift   # Menu bar display
│       ├── MenuBarContentView.swift # Popup content
│       └── SettingsView.swift       # Settings window
├── Tests/                 # Unit tests
├── Info.plist            # App metadata (LSUIElement: true)
└── README.md
```

## Important Implementation Details

**SwiftUI MenuBarExtra Benefits:**
- Native performance (vs Electron's 50-100MB+ footprint)
- Automatic system integration
- No manual NSStatusItem management
- Built-in window style support

**High-Performance File Processing:**
- Parallel processing with `DispatchQueue.concurrentPerform`
- Two-level cache (NSCache + disk)
- Memory-mapped file reading for large files
- Incremental parsing with early exit

**Cache Management:**
- Memory cache: NSCache with 50MB limit
- Disk cache: JSON files in `~/.claude_usage_cache/`
- Cache invalidation based on file modification dates
- Automatic cache warming on startup

**Error Handling:**
- Silently skips unparseable JSONL files
- Shows previous values during updates
- Graceful fallback for cache misses
- Continues operation even with partial data failures

## Testing Strategy

- Unit tests for UsageManager data parsing
- Performance benchmarks in `swift-cli/benchmark_*.swift`
- Cache hit/miss ratio monitoring
- Memory usage profiling
- Verify cost calculation accuracy matches ccusage

## Next Steps

1. **MenuBar App Integration**
   - Port `UltraCacheManager` to main app
   - Add progress indicators
   - Implement background updates

2. **User Experience**
   - Show cached data immediately
   - Add loading animations
   - Implement pull-to-refresh

3. **Advanced Features**
   - Real-time file watching
   - Export usage reports
   - Model-specific breakdowns