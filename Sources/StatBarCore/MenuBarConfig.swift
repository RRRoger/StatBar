import Foundation

public enum MenuBarItemStyle: String, Codable, CaseIterable, Sendable {
    case emoji
    case label
    case number
}

public struct MenuBarItemConfig: Codable, Equatable, Sendable {
    public var visible: Bool = true
    public var style: MenuBarItemStyle = .emoji

    public init(visible: Bool = true, style: MenuBarItemStyle = .emoji) {
        self.visible = visible
        self.style = style
    }
}

public struct MenuBarConfig: Codable, Equatable, Sendable {
    public var cpu: MenuBarItemConfig = .init()
    public var memory: MenuBarItemConfig = .init()
    public var network: MenuBarItemConfig = .init()
    public var disk: MenuBarItemConfig = .init()

    public init() {}

    public static func load() -> MenuBarConfig {
        StatBarSettings.load().menuBar
    }

    public func save() {
        var settings = StatBarSettings.load()
        settings.menuBar = self
        settings.save()
    }
}

public enum RefreshMode: String, Codable, CaseIterable, Sendable {
    case lowPower
    case standard
    case highFrequency

    public var interval: Duration {
        switch self {
        case .lowPower: return .seconds(5)
        case .standard: return .seconds(2)
        case .highFrequency: return .seconds(1)
        }
    }
}

public struct RefreshSettings: Codable, Equatable, Sendable {
    public var mode: RefreshMode

    public init(mode: RefreshMode = .standard) {
        self.mode = mode
    }

    public var interval: Duration {
        mode.interval
    }
}

public struct AlertSettings: Codable, Equatable, Sendable {
    public var cpuHighUsagePercent: Double {
        didSet { cpuHighUsagePercent = cpuHighUsagePercent.clampedPercent }
    }
    public var memoryHighUsagePercent: Double {
        didSet { memoryHighUsagePercent = memoryHighUsagePercent.clampedPercent }
    }
    public var diskHighUsagePercent: Double {
        didSet { diskHighUsagePercent = diskHighUsagePercent.clampedPercent }
    }
    public var deepSeekLowBalance: Double {
        didSet { deepSeekLowBalance = max(0, deepSeekLowBalance) }
    }

    public init(
        cpuHighUsagePercent: Double = 90,
        memoryHighUsagePercent: Double = 90,
        diskHighUsagePercent: Double = 90,
        deepSeekLowBalance: Double = 10
    ) {
        self.cpuHighUsagePercent = cpuHighUsagePercent.clampedPercent
        self.memoryHighUsagePercent = memoryHighUsagePercent.clampedPercent
        self.diskHighUsagePercent = diskHighUsagePercent.clampedPercent
        self.deepSeekLowBalance = max(0, deepSeekLowBalance)
    }
}

public struct ProfileSettings: Codable, Equatable, Sendable {
    public static let defaultDisplayName = "陈鹏"
    public static let defaultSubtitle = "你的 Mac 此刻状态"

    public var displayName: String {
        didSet { displayName = Self.normalized(displayName, fallback: Self.defaultDisplayName) }
    }
    public var subtitle: String {
        didSet { subtitle = Self.normalized(subtitle, fallback: Self.defaultSubtitle) }
    }
    public var avatarPath: String
    public var deepSeekApiKey: String

    public init(
        displayName: String = Self.defaultDisplayName,
        subtitle: String = Self.defaultSubtitle,
        avatarPath: String = "",
        deepSeekApiKey: String = ""
    ) {
        self.displayName = Self.normalized(displayName, fallback: Self.defaultDisplayName)
        self.subtitle = Self.normalized(subtitle, fallback: Self.defaultSubtitle)
        self.avatarPath = avatarPath
        self.deepSeekApiKey = deepSeekApiKey
    }

    private static func normalized(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

public struct NotchLayoutConfig: Codable, Equatable, Sendable {
    public var enabled: Bool = true

    public init(enabled: Bool = true) {
        self.enabled = enabled
    }
}

public struct StatBarSettings: Codable, Equatable, Sendable {
    private static let key = "statBarSettings"
    private static let legacyMenuBarKey = "menuBarConfig"

    public var menuBar: MenuBarConfig
    public var refresh: RefreshSettings
    public var alerts: AlertSettings
    public var profile: ProfileSettings
    public var notchLayout: NotchLayoutConfig

    public init(
        menuBar: MenuBarConfig = MenuBarConfig(),
        refresh: RefreshSettings = RefreshSettings(),
        alerts: AlertSettings = AlertSettings(),
        profile: ProfileSettings = ProfileSettings(),
        notchLayout: NotchLayoutConfig = NotchLayoutConfig()
    ) {
        self.menuBar = menuBar
        self.refresh = refresh
        self.alerts = alerts
        self.profile = profile
        self.notchLayout = notchLayout
    }

    public static func load() -> StatBarSettings {
        if let data = UserDefaults.standard.data(forKey: key),
           let settings = try? JSONDecoder().decode(StatBarSettings.self, from: data) {
            return settings
        }

        if let data = UserDefaults.standard.data(forKey: legacyMenuBarKey),
           let menuBar = try? JSONDecoder().decode(MenuBarConfig.self, from: data) {
            return StatBarSettings(menuBar: menuBar)
        }

        return StatBarSettings()
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
