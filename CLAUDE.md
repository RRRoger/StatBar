# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

StatBar is a macOS menu bar system monitoring tool built with Swift/SwiftUI. It displays real-time system metrics (CPU, memory, etc.) in the menu bar, with a dropdown panel for detailed data.

## Environment

- macOS 15+, Xcode 16+
- Swift / SwiftUI, macOS native app (no Catalyst)

## Build & Run

```bash
# Build the project
xcodebuild -project StatBar.xcodeproj -scheme StatBar build

# Run tests
xcodebuild -project StatBar.xcodeproj -scheme StatBar test

# Run a single test
xcodebuild -project StatBar.xcodeproj -scheme StatBar -only-testing StatBarTests/TestClassName/testMethodName test
```

## Architecture

- macOs menu bar app (`.menuBarExtra` scene or `NSStatusItem` depending on deployment target)
- Menu bar text displays key metrics (e.g., CPU %), updated on a timer
- Dropdown content shows detailed breakdown (CPU, memory, network, disk) using SwiftUI views
- System metrics sourced via `host_statistics` / `Host` APIs and IOKit
- Settings/preferences managed via `@AppStorage` or a settings scene

## Key Patterns

- Prefer `@MainActor` for UI-bound observable objects
- Use `Timer.publish` or `Task.sleep` loops for periodic metric refreshes
- Keep metric collection separate from display views (dedicated service/manager types)
- Menu bar text is length-constrained; keep it scannable (e.g., "C 23% M 58%")
