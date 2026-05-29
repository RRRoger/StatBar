import AppKit
import Foundation

public struct VideoAppProvider: Sendable {
    private static let knownVideoBundleIDs: Set<String> = [
        // Native players
        "com.colliderli.iina",
        "org.videolan.vlc",
        "com.firecore.infuse",
        "com.apple.QuickTimePlayerX",
        "com.apple.TV",
        // Browsers
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        // Streaming
        "com.netflix.Netflix",
        "com.disney.disneyplus",
        "com.amazon.aiv.AIVVideo",
        "com.hbo.hbonow",
        // Chinese
        "tv.danmaku.bilibili",
        "com.tencent.tenvideo",
        "com.youku.mac",
        "com.iqiyi.player",
    ]

    private static let videoKeywords = [
        "youtube", "netflix", "disney", "bilibili", "twitch",
        "video", "player", "movie", "media", "stream",
        "hulu", "peacock", "paramount",
    ]

    public init() {}

    public func snapshot() -> VideoPlaybackInfo {
        guard let info = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return VideoPlaybackInfo()
        }

        for window in info {
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }

            if let app = NSRunningApplication(processIdentifier: pid),
               Self.knownVideoBundleIDs.contains(app.bundleIdentifier ?? "") {
                let title = window[kCGWindowName as String] as? String ?? ""
                return VideoPlaybackInfo(isPlaying: true, appName: ownerName, windowTitle: title)
            }

            let lowerTitle = (window[kCGWindowName as String] as? String ?? "").lowercased()
            let lowerOwner = ownerName.lowercased()
            for keyword in Self.videoKeywords {
                if lowerTitle.contains(keyword) || lowerOwner.contains(keyword) {
                    return VideoPlaybackInfo(isPlaying: true, appName: ownerName, windowTitle: window[kCGWindowName as String] as? String ?? "")
                }
            }
        }

        return VideoPlaybackInfo()
    }
}
