# StatBar Settings Window - Design Spec

## Overview

StatBar currently has a small popover for menu bar display preferences. The next step is a dedicated macOS settings window opened from the dropdown panel gear button. The first version should establish a durable configuration foundation for Mac management features without adding notification delivery or new metric providers yet.

## Goals

- Open a standalone macOS Settings window from the existing gear button.
- Move menu bar display configuration out of the popover and into the settings window.
- Add configurable refresh frequency.
- Add persisted alert threshold settings for future status and notification work.
- Add simple personalization settings for the dropdown header.
- Keep pure configuration models testable in `StatBarCore`.

## Non-Goals

- No user notifications in this version.
- No temperature, fan, disk IO, or new system metric providers in this version.
- No avatar image picker in this version.
- No custom `NSWindow` lifecycle management unless SwiftUI `Settings` is insufficient.

## Architecture

Use SwiftUI's native `Settings` scene:

```swift
Settings {
    SettingsView(settings: $settings)
}
```

The existing gear button in the dropdown footer opens the system settings window using the standard macOS settings action. This keeps window behavior native and avoids manually managing a separate `NSWindow`.

Configuration is represented by a new `StatBarSettings` model in `StatBarCore`. It owns the existing `MenuBarConfig` plus new refresh, alert, and profile sections:

```swift
public struct StatBarSettings: Codable, Equatable, Sendable {
    public var menuBar: MenuBarConfig
    public var refresh: RefreshSettings
    public var alerts: AlertSettings
    public var profile: ProfileSettings
}
```

`StatBarSettings.load()` and `save()` persist the whole configuration in `UserDefaults`. Existing `MenuBarConfig` can remain codable and equatable, but the app should use `StatBarSettings` as the single top-level settings object.

## Settings Sections

### Menu Bar

Expose existing display controls for CPU, memory, network, and disk:

- Visible toggle
- Style segmented picker: emoji, label, number
- Reset menu bar display to defaults

The formatter keeps using `MenuBarConfig`, now accessed through `settings.menuBar`.

### Refresh

Expose a refresh mode picker:

- Low Power: 5 seconds
- Standard: 2 seconds
- High Frequency: 1 second

`MetricsStore` should accept updates to its refresh interval while running. Changing the setting should restart the refresh loop with the new interval.

### Alerts

Persist thresholds for future management features:

- CPU high usage threshold, default 90%
- Memory high usage threshold, default 90%
- Disk high usage threshold, default 90%
- DeepSeek low balance threshold, default 10 CNY

This version stores and edits these values only. It may use CPU and memory thresholds for menu bar red coloring because that behavior already exists, but it should not show system notifications yet.

### Profile

Expose simple text settings:

- Display name, default `陈鹏`
- Header subtitle, default `你的 Mac 此刻状态`

The dropdown header uses these settings immediately.

## Data Flow

1. `StatBarApp` loads `StatBarSettings` into `@State`.
2. Menu bar title reads `settings.menuBar`.
3. Dropdown header reads `settings.profile`.
4. Hot-state coloring reads `settings.alerts.cpuHighUsagePercent` and `settings.alerts.memoryHighUsagePercent`.
5. Settings window edits the same binding and saves on change.
6. Refresh mode changes update `MetricsStore` so the timer interval changes without restarting the app.

## Error Handling

- If stored settings cannot be decoded, fall back to defaults.
- Clamp percent thresholds to `0...100`.
- Clamp DeepSeek low-balance threshold to non-negative values.
- Empty display name falls back to the default name.
- Empty subtitle falls back to the default subtitle.

## Testing

Add Swift Testing coverage for pure configuration logic:

- `StatBarSettings` default values.
- `StatBarSettings` codable round trip.
- Refresh mode duration mapping.
- Threshold clamping.
- Profile fallback values.
- Existing menu title tests updated to use nested `settings.menuBar` where needed.

Manual verification:

- `swift test`
- `swift build`
- Open packaged app or debug app and confirm gear button opens the Settings window.
- Change menu bar visibility/style and confirm menu title updates.
- Change display name/subtitle and confirm dropdown header updates.
- Change refresh mode and confirm the app continues refreshing.

## Files Expected To Change

| File | Change |
| --- | --- |
| `Sources/StatBarCore/MenuBarConfig.swift` | Add top-level settings, refresh, alert, and profile models |
| `Sources/StatBarCore/MetricsStore.swift` | Support runtime refresh interval updates |
| `Sources/StatBar/StatBarApp.swift` | Add `Settings` scene, settings window view, gear action, and profile/alert binding |
| `Tests/StatBarCoreTests/StatBarCoreTests.swift` | Add settings model tests and adjust related formatter tests |

