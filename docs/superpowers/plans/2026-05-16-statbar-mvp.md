# StatBar MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working macOS menu bar app that displays live CPU and memory metrics.

**Architecture:** Use a Swift Package for testable core code and a SwiftUI executable target for the app. The Xcode project references the same source files for users who prefer opening the app in Xcode.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Darwin Mach host APIs, XCTest.

---

## File Structure

- `Package.swift`: SwiftPM package with `StatBarCore`, `StatBar`, and `StatBarCoreTests`.
- `Sources/StatBarCore/SystemMetrics.swift`: metric models, formatting, CPU delta calculation, provider protocol, and macOS provider.
- `Sources/StatBarCore/MetricsStore.swift`: main-actor observable refresh loop.
- `Sources/StatBar/StatBarApp.swift`: SwiftUI menu bar app and dropdown UI.
- `Tests/StatBarCoreTests/StatBarCoreTests.swift`: unit tests for pure logic.
- `StatBar.xcodeproj/project.pbxproj`: Xcode project for app and tests.
- `StatBar/Info.plist`: app bundle metadata.

## Tasks

- [x] Write failing unit tests for formatter and CPU delta logic.
- [x] Implement `StatBarCore` models, formatter, CPU calculator, and system provider.
- [x] Implement `MetricsStore` refresh behavior.
- [x] Implement SwiftUI `MenuBarExtra` app UI.
- [x] Add package and Xcode project metadata.
- [x] Run `swift test`.
- [x] Run `swift build`.
- [ ] Run `xcodebuild -project StatBar.xcodeproj -scheme StatBar test` when a full Xcode developer directory is active.
