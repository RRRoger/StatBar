# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

StatBar is a macOS menu bar system monitoring tool built with Swift/SwiftUI. It displays real-time system metrics in the menu bar using emoji icons, with a rich dropdown panel for detailed data. Metrics: CPU, memory, network rate, disk usage, battery (health/cycles), top 5 processes by CPU, system uptime, and DeepSeek API balance.

## Environment

- macOS 15+
- Swift 6 / SwiftUI, macOS native app (no Catalyst)
- Xcode 16+ is optional. The project builds with Swift Package Manager and Command Line Tools only.
- Env var `DEEPSEEK_API_KEY` (set via `launchctl setenv`) for DeepSeek balance display.

## Build & Run

```bash
# Run all tests (Swift Testing framework)
swift test

# Build debug
swift build

# Build release .app (auto-increments patch version: 0.0.1 → 0.0.2)
./scripts/build-app.sh

# Kill running instance, build, and launch
pkill -f StatBar 2>/dev/null; sleep 0.3; ./scripts/build-app.sh && open .build/StatBar.app

# Open the packaged menu bar app
open .build/StatBar.app

# Xcode build/test (when full Xcode developer directory is active)
xcodebuild -project StatBar.xcodeproj -scheme StatBar build
xcodebuild -project StatBar.xcodeproj -scheme StatBar test
xcodebuild -project StatBar.xcodeproj -scheme StatBar -only-testing StatBarCoreTests/ClassName/methodName test
```

**每次修改代码后，执行以下命令编译并启动：**

```bash
pkill -f StatBar 2>/dev/null; sleep 0.3; ./scripts/build-app.sh && open .build/StatBar.app
```

**部署到 Applications（需要屏幕录制权限时）：**

```bash
pkill -f StatBar 2>/dev/null; sleep 0.3; ./scripts/build-app.sh && cp -R .build/StatBar.app /Applications/StatBar.app && open /Applications/StatBar.app
```

脚本会自动递增 `version.txt` 中的 patch 版本号（如 `0.0.1` → `0.0.2`），同时更新 `CFBundleShortVersionString` 和 `CFBundleVersion`。

## Release Process

Every push to release must follow these steps:

```bash
# 1. Ensure all tests pass
swift test

# 2. Build release .app (auto-increments version.txt)
./scripts/build-app.sh

# 3. Zip the .app for distribution
cd .build && zip -r StatBar-v1.0.0.zip StatBar.app && cd ..

# 4. Commit and push changes
git add -A
git commit -m "<message>"
git push

# 5. Tag and create GitHub Release with zip asset
git tag -a v1.0.0 -m "v1.0.0: <summary>"
git push origin v1.0.0
gh release create v1.0.0 \
  --title "StatBar v1.0.0" \
  --notes "$(cat <<'EOF'
## What's New

- <feature bullets>
EOF
  )" \
  .build/StatBar-v1.0.0.zip
```

**Versioning:** semver (`CFBundleShortVersionString` in Info.plist). The build script auto-increments `CFBundleVersion`. Update `CHANGELOG.md` with the release entry before tagging.

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

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
