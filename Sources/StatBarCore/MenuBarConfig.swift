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
    private static let key = "menuBarConfig"

    public var cpu: MenuBarItemConfig = .init()
    public var memory: MenuBarItemConfig = .init()
    public var network: MenuBarItemConfig = .init()
    public var disk: MenuBarItemConfig = .init()

    public init() {}

    public static func load() -> MenuBarConfig {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(MenuBarConfig.self, from: data)
        else { return MenuBarConfig() }
        return config
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
