# Changelog

All notable changes to StatBar will be documented in this file.

## [1.2.0] — 2026-05-24

### Added
- Native macOS Settings window opened from the dropdown gear button
- Unified app settings for menu bar display, refresh mode, alert thresholds, and profile text
- Refresh modes: Low Power (5s), Standard (2s), and High Frequency (1s)
- Configurable CPU, memory, disk, and DeepSeek alert thresholds
- Configurable dropdown display name and subtitle

### Changed
- Moved menu bar display controls from a popover into the Settings window
- CPU and memory hot-state coloring now use configurable thresholds

### Fixed
- Preserve existing menu bar display preferences when migrating to unified settings
- Use the incremented build number in packaged app metadata

## [1.1.0] — 2026-05-16

### Added
- Customizable menu bar display: show/hide each metric independently
- Per-item display style: emoji, text label, or number only
- Preferences popover panel accessible via gear icon in dropdown
- Fallback to "StatBar" when all items hidden
- App icon from avatar (AppIcon.icns)

### Changed
- Menu bar format now uses space between emoji and value (e.g. `🔥 23%`)

## [1.0.0] — 2026-05-16

### Added
- Menu bar system monitoring with emoji icons: CPU, memory, network, disk
- Rich dropdown panel with detailed metrics and progress bars
- Battery status including cycle count and health
- Top 5 running processes by CPU usage
- DeepSeek API balance display with manual refresh button
- Personalized header with avatar and time-based greeting
- Auto-incrementing build version
- GitHub repository link in panel footer
- Python test script for DeepSeek API

### Fixed
- CPU usage stuck at 0% (provider write-back missing after mutation)
- Network rate stuck at 0% (same root cause)
- Dropdown panel opening lag (Thread.sleep blocked Swift concurrency pool; switched to GCD)

### Changed
- API keys read from environment variables, never hardcoded
