# Claude Usage MenuBar

A lightweight macOS menu bar application that displays Claude Code usage statistics in real-time.

## Features

- **Real-time monitoring**: Tracks Claude Code usage from local data files
- **Minimal footprint**: Native Swift app with tiny memory usage
- **Modern UI**: Built with SwiftUI MenuBarExtra (macOS 13.0+)
- **Cost tracking**: Shows daily and monthly costs
- **Token display**: Input/output token counts with smart formatting
- **Auto-refresh**: Updates every 5 minutes automatically

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

## Architecture

This app uses the modern SwiftUI `MenuBarExtra` API introduced in macOS 13.0, making it much more lightweight than Electron-based alternatives.

**Key Components:**
- `ClaudeUsageApp`: Main app with MenuBarExtra scene
- `UsageManager`: Handles data loading from `~/.claude/projects/`
- `MenuBarLabelView`: Shows cost in menu bar
- `MenuBarContentView`: Detailed popup with usage stats

**Data Source:**
Reads JSONL files from Claude Code's local storage at `~/.claude/projects/` to calculate usage statistics.

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