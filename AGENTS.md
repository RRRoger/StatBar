# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

StatBar is a macOS menu bar system monitoring tool built with Swift/SwiftUI. It displays real-time system metrics (CPU, memory, etc.) in the menu bar, with a dropdown panel for detailed data.

## Environment

- macOS 15+
- Swift 6 / SwiftUI, macOS native app (no Catalyst)
- Xcode 16+ is optional for opening `StatBar.xcodeproj`. The project can also be built with Swift Package Manager and Command Line Tools only.

## Build & Run

```bash
# Run core tests
swift test

# Build the SwiftPM executable
swift build

# Build a release .app without Xcode
./scripts/build-app.sh

# Open the packaged menu bar app
open .build/StatBar.app

# Build with Xcode when a full Xcode developer directory is active
xcodebuild -project StatBar.xcodeproj -scheme StatBar build

# Run Xcode tests when a full Xcode developer directory is active
xcodebuild -project StatBar.xcodeproj -scheme StatBar test

# Run a single Xcode test
xcodebuild -project StatBar.xcodeproj -scheme StatBar -only-testing StatBarTests/TestClassName/testMethodName test
```

## Architecture

- `Package.swift` is the primary build definition. Keep core logic testable through SwiftPM.
- `StatBar.xcodeproj` is provided for Xcode users and should reference the same source files.
- `Sources/StatBar/StatBarApp.swift` contains the SwiftUI menu bar app using `MenuBarExtra`.
- `Sources/StatBarCore/SystemMetrics.swift` contains metric models, formatting, CPU delta calculation, and macOS host API collection.
- `Sources/StatBarCore/MetricsStore.swift` contains the `@MainActor` observable refresh store.
- `Tests/StatBarCoreTests/` contains pure logic tests using Swift Testing.
- `scripts/build-app.sh` packages the SwiftPM release executable into `.build/StatBar.app` and ad-hoc signs it when `codesign` is available.

## Key Patterns

- Prefer `@MainActor` for UI-bound observable objects
- Use `Task.sleep` loops for periodic metric refreshes
- Keep metric collection separate from display views (dedicated service/manager types)
- Menu bar text is length-constrained; keep it scannable (e.g., "C 23% M 58%")
- Treat `C 23% M 58%` as CPU and memory percentages respectively.
- Add tests for pure logic before changing formatter, CPU calculation, memory calculation, or refresh behavior.
- Do not commit `.build/`, `.swiftpm/`, `.vscode/`, or Xcode user data.
