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

**Release Process:**
- `./scripts/release.sh` - Create a patch release
- `./scripts/release.sh minor` - Create a minor release
- `./scripts/release.sh major` - Create a major release
- `./scripts/release.sh --yes` - Non-interactive mode

**Development Scripts:**
- `./scripts/dev.sh run` - Run in development mode
- `./scripts/build.sh` - Build release version
- `./scripts/install.sh` - Install to Applications folder

## Architecture

**Modern SwiftUI Approach:**
- Uses `MenuBarExtra` scene (macOS 13.0+) instead of traditional NSStatusItem
- No main window - purely menu bar focused
- Declarative SwiftUI throughout

**Key Files:**
- `Sources/ClaudeUsageMenuBar/ClaudeUsageApp.swift` - Main app entry point with MenuBarExtra scene
- `Sources/ClaudeUsageMenuBar/UsageManager.swift` - Data loading and management (ObservableObject)
- `Sources/ClaudeUsageMenuBar/MenuBarLabelView.swift` - Menu bar display (cost + icon)  
- `Sources/ClaudeUsageMenuBar/MenuBarContentView.swift` - Popup content with detailed stats
- `Sources/ClaudeUsageMenuBar/CurrencyManager.swift` - Currency conversion and formatting
- `Sources/ClaudeUsageMenuBar/UltraCacheManager.swift` - Two-level caching system
- `Sources/ClaudeUsageMenuBar/PricingFetcher.swift` - LiteLLM pricing integration
- `Sources/ClaudeUsageMenuBar/UltraFastManager.swift` - Memory-based ultra-fast caching

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
- **Currency Conversion**: Real-time conversion to 33+ currencies using free exchange API
- **Auto-Detection**: Uses OS locale to set default currency
- **Smart Formatting**: NumberFormatter with proper locale support (JPY: 1,234,567)

## Performance Status ✅ FULLY OPTIMIZED

**Achieved Performance:**
- **Initial load**: 0.57 seconds (25x faster than original 15s!)
- **Cached load**: 0.002 seconds (7,500x faster in CLI benchmarks!)
- **Memory usage**: 25-50MB optimized
- **Cache hit rate**: 99.5% after first run

**Key Optimizations Implemented:**
1. **Parallel Processing** - Uses all CPU cores with DispatchQueue.concurrentPerform
2. **Two-Level Caching** - UltraCacheManager (memory + disk) + UltraFastManager (memory-only)
3. **Fast Date Extraction** - String slicing instead of DateFormatter
4. **Smart File Filtering** - Skip old files, process newest first
5. **24h Pricing Cache** - Automatic LiteLLM pricing updates for long-running apps
6. **Optimized Parsing** - Batch processing with autoreleasepool

**Performance Characteristics:**
- Handles 200+ files (198MB) efficiently
- Processes ~2,700 daily entries at ~2,700 entries/second
- 99.5% cache hit rate after first run
- True instant UI updates with memory cache
- Perfect for long-running apps (pricing auto-updates every 24h)

## Development Setup

**Prerequisites:**
- Xcode 15.0+ or Swift 5.9+ command line tools
- macOS 13.0+ (for MenuBarExtra API)

**Project Structure:**
```
ccusage-menubar/
├── README.md                    # Project overview
├── CLAUDE.md                    # This file - Claude Code configuration
├── Package.swift                # Swift package manifest
├── Info.plist                   # macOS app bundle configuration (LSUIElement: true)
├── Sources/ClaudeUsageMenuBar/  # Main application source code
│   ├── ClaudeUsageApp.swift     # @main entry point with MenuBarExtra
│   ├── UsageManager.swift       # High-performance data management
│   ├── UltraCacheManager.swift  # Two-level caching system (memory + disk)
│   ├── UltraFastManager.swift   # Memory-based ultra-fast caching
│   ├── PricingFetcher.swift     # LiteLLM pricing integration with 24h cache
│   ├── CurrencyManager.swift    # Currency conversion and exchange rate management
│   ├── MenuBarLabelView.swift   # Menu bar display (cost + icon)
│   └── MenuBarContentView.swift # Popup content with detailed stats
├── Tests/                       # Test scripts and Swift unit tests
├── docs/                        # Documentation files
│   ├── BUILD.md                 # Build and installation guide
│   ├── OPTIMIZATION_RESULTS.md  # Performance achievements
│   └── ...                      # Other documentation
├── benchmarks/                  # Performance benchmarks and CLI tools
│   ├── benchmark*.swift         # Performance test suite
│   └── exact_ccusage.swift      # Reference implementation
├── tests/                       # Test scripts and validation tools
│   ├── compare_json.py          # Validation against ccusage CLI
│   └── ...                      # Various test utilities
└── artifacts/                   # Generated files and build outputs
```

## Important Notes for Development

**Testing Before Release:**
- Always test the built app before creating a release
- Use `xattr -cr "build/Claude Code Usage.app"` to bypass Gatekeeper for testing
- Verify all features work correctly with actual Claude Code data
- Check that the menu bar display updates properly

**Documentation Updates:**
- **IMPORTANT**: Always update both `README.md` and `README.ja.md` together
- Keep English and Japanese versions in sync
- When adding features, update both READMEs
- When changing installation steps, update both READMEs
- Commit both files together to maintain consistency

**Known Issues:**
- App requires Gatekeeper bypass on first launch (not code signed)
- Menu bar item may be hidden by menu bar management utilities
- Right-click "Open" method doesn't work for menu bar apps

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
- **UltraCacheManager**: Two-level caching (memory NSCache + disk JSON files)
- **UltraFastManager**: Memory-only ultra-fast caching for file lists and pricing
- Memory cache: NSCache with 50MB limit for instant access (2ms)
- Disk cache: JSON files in `~/.claude_ultra_cache/` for persistence (5ms)
- Cache invalidation based on file modification dates
- Automatic cache warming on startup
- 24h pricing cache with auto-refresh for long-running apps

**Error Handling:**
- Silently skips unparseable JSONL files
- Shows previous values during updates
- Graceful fallback for cache misses
- Continues operation even with partial data failures

## Testing Strategy

- Unit tests for UsageManager data parsing
- Performance benchmarks in `benchmarks/benchmark_*.swift`
- Cost calculation validation with `tests/compare_json.py`
- Cache hit/miss ratio monitoring
- Memory usage profiling
- Verify accuracy matches ccusage with various test scripts in `tests/`

## Release Status

- **Current Version**: v1.0.0 (Released)
- **Bundle ID**: `sh.saqoo.ccusage-menubar`
- **Code Signing**: Not yet implemented (users need to bypass Gatekeeper)
- **Distribution**: GitHub Releases with automated release process

## Completed Features ✅

1. **Performance Optimization**
   - UltraCacheManager fully integrated
   - Instant cached data display
   - Background updates via configurable intervals
   - 25x performance improvement achieved

2. **User Experience**
   - Clean, minimal menu bar interface
   - Multi-currency support with auto-detection
   - Real-time cost updates
   - Simplified UI (removed settings window for better UX)

3. **Development Infrastructure**
   - Automated release process (`scripts/release.sh`)
   - Comprehensive documentation
   - Performance benchmarking suite
   - Build and installation scripts

## Future Improvements

1. **Code Signing & Distribution**
   - Apple Developer account for code signing
   - Notarization for easier installation
   - Homebrew formula
   - Auto-update functionality

2. **Advanced Features**
   - Real-time file watching (FSEvents)
   - Usage history graphs
   - Export usage reports (CSV/JSON)
   - Model-specific cost breakdowns
   - Usage alerts/notifications

3. **UI Enhancements**
   - Dark/light mode icon variants
   - Customizable display format
   - Mini graphs in popup view