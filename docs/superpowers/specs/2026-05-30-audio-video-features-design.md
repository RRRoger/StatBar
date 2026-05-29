# Audio Waveform + Video App Detection Design

Date: 2026-05-30

## Feature 1: Audio Waveform in Compact Island

### Approach
Use `ScreenCaptureKit` to capture system audio levels in real-time. Map RMS volume to 12 vertical bars displayed in the compact island state.

### Data Model
```swift
struct AudioLevelMetrics: Equatable, Sendable {
    var currentLevel: Float        // 0.0 ~ 1.0 RMS level
    var waveformData: [Float]      // Last 12 samples for visualization
    var isActive: Bool             // Audio is playing
}
```

### Provider
`AudioMonitorProvider` — uses `SCShareableContent` + `SCStreamConfiguration` with `.audio` capture type. Outputs RMS level at ~30fps. Stores rolling buffer of 12 samples.

### Display
In compact island: replace the status dot area with a 12-bar waveform visualization using SwiftUI `Canvas`. Bars are purple (#5e5ce6), height proportional to audio level. Silent bars stay at minimum height (2px).

### Permissions
Requires screen recording permission. On first launch, prompt via `CGRequestScreenCaptureAccess()`. If denied, show static bars.

## Feature 2: Video App Detection

### Approach
Use `CGWindowListCopyWindowInfo` to enumerate all on-screen windows. Match against known video app bundle IDs and check for video-related window characteristics.

### Known Video Apps
- Browsers: Safari, Chrome, Firefox, Edge (check for video in window title)
- Native: IINA, VLC, Infuse, QuickTime, TV.app, Netflix, YouTube, Bilibili
- Streaming: Disney+, HBO Max, Amazon Prime Video

### Data Model
```swift
struct VideoPlaybackInfo: Equatable, Sendable {
    var isPlaying: Bool
    var appName: String
    var appIcon: NSImage?
    var windowTitle: String?
}
```

### Provider
`VideoAppProvider` — polls `CGWindowListCopyWindowInfo` every 2 seconds. Filters for windows from known video bundle IDs. Returns the first match.

### Display
- Compact island: show ▶️ icon at the end of the summary text
- Expanded island: new "Now Playing" section with app icon + name + window title

## Files to Modify
- `SystemMetrics.swift` — add AudioLevelMetrics, VideoPlaybackInfo models
- `AudioMonitorProvider.swift` (new) — ScreenCaptureKit audio capture
- `VideoAppProvider.swift` (new) — CGWindowList video app detection
- `MetricsStore.swift` — add audio/video state, refresh logic
- `StatBarApp.swift` — waveform view in compact island, now playing in expanded
