# Settings Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS Settings window for StatBar with menu bar display, refresh, alert threshold, and profile settings.

**Architecture:** Add a top-level `StatBarSettings` model in `StatBarCore` and make the app bind one shared settings value through the menu bar scene and Settings scene. Keep data logic testable in core, and keep SwiftUI window code in `Sources/StatBar`.

**Tech Stack:** Swift 6, SwiftUI `Settings` scene, Swift Testing, UserDefaults persistence.

---

## File Structure

- `Sources/StatBarCore/MenuBarConfig.swift`: Owns codable configuration models, defaults, validation, UserDefaults persistence, and refresh mode duration mapping.
- `Sources/StatBarCore/MetricsStore.swift`: Allows refresh interval updates while the store is running.
- `Sources/StatBar/StatBarApp.swift`: Loads settings, opens the native Settings window, renders the settings UI, and applies profile/alert/menu bar settings.
- `Tests/StatBarCoreTests/StatBarCoreTests.swift`: Covers settings defaults, codable round trip, threshold clamping, profile fallback, and refresh mode mapping.

## Tasks

### Task 1: Core Settings Model

**Files:**
- Modify: `Sources/StatBarCore/MenuBarConfig.swift`
- Modify: `Tests/StatBarCoreTests/StatBarCoreTests.swift`

- [ ] Add tests for `StatBarSettings`, `RefreshMode`, `AlertSettings`, and `ProfileSettings`.
- [ ] Run `swift test` and verify the new tests fail because the types do not exist.
- [ ] Implement the models in `MenuBarConfig.swift`.
- [ ] Run `swift test` and verify the new tests pass.

### Task 2: Runtime Refresh Interval

**Files:**
- Modify: `Sources/StatBarCore/MetricsStore.swift`

- [ ] Change `refreshInterval` from `let` to mutable state.
- [ ] Add `updateRefreshInterval(_:)` that restarts the loop if the interval changed.
- [ ] Preserve existing `DispatchQueue.global` snapshot behavior.
- [ ] Run `swift test`.

### Task 3: Native Settings Window UI

**Files:**
- Modify: `Sources/StatBar/StatBarApp.swift`

- [ ] Replace `@State private var menuBarConfig` with `@State private var settings`.
- [ ] Add a SwiftUI `Settings` scene using `SettingsView(settings: $settings)`.
- [ ] Change the gear button to open the native Settings window.
- [ ] Remove the old popover settings UI from the dropdown.
- [ ] Add sections for Menu Bar, Refresh, Alerts, and Profile.
- [ ] Save settings on change and update `MetricsStore` refresh interval.

### Task 4: Apply Settings In App

**Files:**
- Modify: `Sources/StatBar/StatBarApp.swift`

- [ ] Use `settings.menuBar` for menu title formatting.
- [ ] Use alert thresholds for red menu bar coloring.
- [ ] Use profile display name and subtitle in the dropdown header.
- [ ] Ensure reset buttons write defaults and update the UI immediately.

### Task 5: Verification

**Files:**
- No code changes expected.

- [ ] Run `swift test`.
- [ ] Run `swift build`.
- [ ] Review `git diff --check`.
- [ ] Review changed files for accidental unrelated edits.

