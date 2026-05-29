# Changelog

All notable changes to StatBar will be documented in this file.

## [2.0.0] — 2026-05-30

### Added
- Dynamic Island floating panel at top-center of screen (NSPanel)
- Compact island: avatar, CPU/MEM/NET summary, three-body gravitational orbit animation
- Expanded island: scrollable detail panel with all system metrics
- Three-body simulation with cyan/orange/pink bodies and glow effects
- Animated progress bars with gradient shimmer for CPU/Memory/Disk
- Network activity pulse indicators
- High-load breathing glow and red border on compact island
- Video playback detection (Safari, Chrome, IINA, VLC, Netflix, Bilibili, etc.)
- Settings window: menu bar config, refresh mode, alert thresholds, profile, DeepSeek API Key
- Avatar path configuration with file browser
- DeepSeek API Key test connection button
- Smart placeholder display (hidden when value exists)
- Auto-collapse island when opening settings
- Top processes show clean process names (not full paths)
- Network speed shows full units (KB/s, MB/s) in island

### Changed
- Expanded panel height reduced from 800px to 750px
- Alerts section uses shorter labels (CPU/Memory/Disk/DeepSeek)
- Style picker disabled when metric toggle is off
- Deploy command uses `rm -rf` before `cp -R` to ensure overwrite

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
