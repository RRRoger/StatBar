# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

StatBar is a macOS menu bar system monitoring tool built with Swift/SwiftUI. It displays real-time system metrics in the menu bar using emoji icons, with a rich dropdown panel for detailed data. Metrics: CPU, memory, network rate, disk usage, battery (health/cycles), top 5 processes by CPU, system uptime, and DeepSeek API balance.

## Environment

- macOS 15+
- Swift 6 / SwiftUI, macOS native app (no Catalyst)
- Xcode 16+ is optional. The project builds with Swift Package Manager and Command Line Tools only.
- Env var `DEEPSEEK_API_KEY` (set via `launchctl setenv`) for DeepSeek balance display.

## Build & Run

```bash
# Run all tests (24 tests, Swift Testing framework)
swift test

# Build debug
swift build

# Build release .app (auto-increments build version in version.txt)
./scripts/build-app.sh

# Open the packaged menu bar app
open .build/StatBar.app

# Xcode build/test (when full Xcode developer directory is active)
xcodebuild -project StatBar.xcodeproj -scheme StatBar build
xcodebuild -project StatBar.xcodeproj -scheme StatBar test
xcodebuild -project StatBar.xcodeproj -scheme StatBar -only-testing StatBarCoreTests/ClassName/methodName test
```

## Architecture

```
Sources/
  StatBar/StatBarApp.swift          — SwiftUI MenuBarExtra + dropdown panel
  StatBarCore/
    SystemMetrics.swift             — Metric models, SystemSnapshot, formatter, MacSystemMetricsProvider, protocol
    SystemInfoProviders.swift       — 5 system providers + DeepSeekBalanceProvider + Process.runWithTimeout
    MetricsStore.swift              — @MainActor @Observable refresh store
Tests/StatBarCoreTests/             — Pure logic tests (24 tests)
scripts/build-app.sh                — Packages .app, auto-increments version, copies avatar
Resources/avatar.jpeg               — User avatar, copied to .app/Contents/Resources/ by build script
```

**Source file responsibilities:**

- `SystemMetrics.swift` — All metric structs (CPU, Memory, Network, Disk, Battery, TopProcessInfo, DeepSeekMetrics), `SystemSnapshot`, `StatBarFormatter`, `CPUUsageCalculator`, `CPUTickSample`, `MacSystemMetricsProvider` (reads Mach APIs + delegates to providers), `SystemMetricsProviding` protocol.
- `SystemInfoProviders.swift` — `SystemUptimeProvider`, `DiskInfoProvider`, `NetworkRateProvider` (delta from getifaddrs), `BatteryInfoProvider` (pmset/ioreg, 5-min cache), `TopProcessesProvider` (ps top 5), `DeepSeekBalanceProvider` (HTTP to api.deepseek.com, 30s cache, env var for key), `OSAtomic` helper class, `Process.runWithTimeout` extension (synchronous Process with Thread.sleep polling).
- `MetricsStore.swift` — Owns a `SystemMetricsProviding` (value type), runs refresh on `DispatchQueue.global().async` (NOT Swift concurrency Task — because sub-providers use blocking Process/Thread.sleep). Writes back mutated provider to preserve CPU delta and network rate state. Separate `refreshDeepSeek()` for manual DeepSeek balance refresh.

## Key Patterns

- `@MainActor` for UI-bound observable objects (`MetricsStore` is `@Observable`).
- `DispatchQueue.global().async` for refresh work that includes blocking `Process.runWithTimeout` calls. Do NOT use `Task` — `Thread.sleep` blocks the cooperative thread pool.
- Provider structs are value types with `mutating func snapshot()`. Must write back the mutated copy after calling snapshot to preserve state (CPU previous tick, network previous sample).
- Menu bar format: `🔥{cpu}% 💾{mem}% 🌐↓{down}↑{up} 💿{disk}%`
- CPU usage > 90% or memory > 90% turns menu bar text red.
- Dropdown panel has sections: header (avatar + greeting), CPU, Memory, Network, Disk, Battery (conditional), Top Processes, DeepSeek (with manual refresh button), Uptime, Footer (update time + build version).
- `DeepSeekMetrics` has 30s cache in `DeepSeekBalanceProvider`. API key from `ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]` — never hardcode.
- `StatBarFormatter.menuTitle(for:)` must stay length-constrained for menu bar.
- Tests use Swift Testing (`@Test`, `#expect`). Add tests for pure logic (formatters, calculators, metrics models) before changing them.
- Do not commit `.build/`, `.swiftpm/`, `.vscode/`, Xcode user data, or files containing API keys.
