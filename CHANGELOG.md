# Changelog

All notable changes to StatBar will be documented in this file.

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
