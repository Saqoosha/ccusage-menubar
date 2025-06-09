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

**Data Flow:**
1. `UsageManager` scans `~/.claude/projects/` for .jsonl files
2. Parses Claude Code usage entries with token counts and costs
3. Aggregates daily/monthly statistics
4. Updates SwiftUI views via `@Published` properties
5. Auto-refreshes every 5 minutes

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
- Prefers `costUSD` when available
- Falls back to estimation: ~$3/1M input tokens, ~$15/1M output tokens
- Handles cache tokens separately

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

**File Processing:**
- Async/await for non-blocking file I/O
- Background queue for JSONL parsing
- Graceful error handling for corrupted files
- Recursive directory scanning

**Memory Management:**
- `@MainActor` for UI updates
- Proper Timer cleanup in deinit
- Efficient JSON parsing with Codable

**Error Handling:**
- Silently skips unparseable JSONL files
- Shows "--" when data unavailable
- Continues operation even with partial data failures

## Testing Strategy

- Unit tests for UsageManager data parsing
- Mock JSONL files for testing different scenarios
- Test cost calculation accuracy
- Verify date filtering for daily/monthly stats