# StatBar MVP Design

## Goal

Build a first usable macOS menu bar system monitor. The app shows a short CPU and memory summary in the menu bar, opens a compact SwiftUI panel with current details, refreshes automatically, and includes a quit action.

## Scope

The MVP includes CPU utilization, memory utilization, used memory, total memory, refresh time, and a menu action to quit the app. Network, disk, preferences, custom ordering, launch-at-login, and historical charts are intentionally left for later versions.

## Architecture

The code is split into a testable core library and a small app shell.

- `StatBarCore` contains metric models, formatting, CPU delta calculation, macOS system metric collection, and a main-actor store that refreshes data on a timer.
- `StatBar` contains the SwiftUI `MenuBarExtra` app entry and menu panel views.
- `StatBarCoreTests` verifies the pure logic without depending on live system state.

## Data Flow

`StatBarApp` owns one `MetricsStore`. On launch, the store refreshes immediately and then refreshes every two seconds. The store asks `SystemMetricsProvider` for a `SystemSnapshot`, formats the title as `C 23% M 58%`, and publishes the snapshot to SwiftUI views.

CPU usage is calculated from two samples of host processor tick counters. The first sample returns 0 percent until there is a previous sample. Memory usage is calculated from `host_statistics64` and `host_page_size`.

## UI

The menu bar title is intentionally short and stable. The dropdown panel shows:

- CPU percentage with a progress bar.
- Memory percentage with a progress bar.
- Used and total memory in human-readable units.
- Last refresh timestamp.
- A Quit button.

## Error Handling

Metric collection returns a snapshot even when partial data is unavailable. CPU falls back to the last known or 0 percent on first sample. Memory falls back to 0 values if host statistics fail. The UI remains usable.

## Testing

Unit tests cover CPU delta math, menu title formatting, percent clamping, byte formatting, and snapshot display helpers. Live host API calls are not required for tests.
