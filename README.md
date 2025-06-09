# Claude Usage MenuBar - Swift Native

A lightweight native Swift macOS menubar application that displays Claude Code usage statistics in real-time.

## 🎯 Project Focus

**Swift Native MenuBar App** (`swift-test/`)
- Native SwiftUI implementation using MenuBarExtra
- Real-time Claude usage monitoring
- Accurate cost calculation based on ccusage CLI
- Fast startup and minimal resource usage

**Development Tools** (`swift-cli/`)
- `simple_output.swift` - Reference implementation (100% accurate)
- `compare_json.py` - Validation against ccusage CLI
- `exact_ccusage.swift` - ccusage reproduction for testing

## 🚀 Quick Start

### Run the MenuBar App
```bash
cd swift-test
swift run
```

### Test with CLI Tools
```bash
# Get current usage data
swift swift-cli/simple_output.swift

# Compare with ccusage (requires ccusage CLI)
python3 swift-cli/compare_json.py
```

## 📊 Accuracy

The Swift CLI tools achieve **100% accuracy** compared to ccusage:
- Perfect token count matching
- Correct cost calculation using discovered pricing rates
- Verified with JSON-based comparison tools

## 🔧 Development

**Requirements:**
- macOS 13.0+ (for MenuBarExtra)
- Swift 5.9+
- Xcode or Swift command line tools

**Architecture:**
- SwiftUI for native UI
- Async/await for data loading
- Timer-based auto-refresh
- Optimized JSONL parsing

## 📁 Project Structure

```
ccusage-menubar/
├── swift-test/           # Main native menubar app
│   ├── Sources/          # Swift source code
│   └── Package.swift     # SPM configuration
├── swift-cli/            # Development tools & testing
└── README.md             # This file
```

## 🎯 Goals

1. **Replace Electron with Native Swift** - Lightweight, fast, native experience
2. **Accurate Cost Calculation** - Match ccusage CLI exactly
3. **Real-time Updates** - Show current usage in menubar
4. **Performance** - Sub-3 second startup, minimal CPU usage