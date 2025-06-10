# Changelog

All notable changes to Claude Code Usage MenuBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- VERSION file for centralized version management
- Automated release script (scripts/release.sh)
- Release process documentation

### Changed
- Bundle ID changed to sh.saqoo.ccusage-menubar
- build.sh now reads version from VERSION file

## [1.0.0] - 2025-01-10

### Added
- Initial release of Claude Code Usage MenuBar
- Native macOS menu bar app built with Swift and SwiftUI
- Real-time Claude Code usage monitoring
- Multi-currency support with automatic conversion (33+ currencies)
- Ultra-fast performance with two-level caching system
- Exact ccusage pricing logic with LiteLLM integration
- Configurable refresh intervals
- Clean, minimalist UI focused on cost display
- Support for all Claude models
- Automatic locale-based currency detection

### Performance
- Initial load: 0.57 seconds (25x faster than original)
- Cached load: 0.002 seconds (7,500x faster)
- Memory usage: 25-50MB optimized
- Cache hit rate: 99.5% after first run

### Technical
- Built with modern SwiftUI and MenuBarExtra API
- Requires macOS 13.0+
- Lightweight native app (~600KB)
- No external dependencies
- Comprehensive build and installation scripts

[1.0.0]: https://github.com/saqoosha/ccusage-menubar/releases/tag/v1.0.0