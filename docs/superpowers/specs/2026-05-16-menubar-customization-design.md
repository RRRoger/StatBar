# Menu Bar Customization — Design Spec

## Overview

StatBar 菜单栏目前固定显示 `🔥23% 💾58% 🌐↓1.2M↑300K 💿42%`。用户希望：
- 可选择显示/隐藏某个指标
- 每项可独立切换风格：emoji / 文字标签 / 纯数字
- 通过偏好设置面板实时调整

## Data Model

New file: `Sources/StatBarCore/MenuBarConfig.swift`

```swift
enum MenuBarItemStyle: String, Codable, CaseIterable {
    case emoji   // "🔥 23%"
    case label   // "CPU 23%"
    case number  // "23%"
}

struct MenuBarItemConfig: Codable, Equatable {
    var visible: Bool = true
    var style: MenuBarItemStyle = .emoji
}

struct MenuBarConfig: Codable, Equatable {
    static let key = "menuBarConfig"
    var cpu: MenuBarItemConfig = .init()
    var memory: MenuBarItemConfig = .init()
    var network: MenuBarItemConfig = .init()
    var disk: MenuBarItemConfig = .init()

    static func load() -> MenuBarConfig { ... }
    func save() { ... }
}
```

- 存于 UserDefaults，key `menuBarConfig`
- 默认全部 emoji 风格、全部可见
- `CaseIterable` 用于 Picker 遍历
- 可独立单测

## Formatter Changes

`StatBarFormatter` 新增重载：

```swift
func menuTitle(for snapshot: SystemSnapshot, config: MenuBarConfig) -> String
```

拼接规则：
- `visible=false` → 跳过
- 每个 item 一个空格分隔
- 如果 menu bar 为空 → 返回 `"StatBar"`
- 原有 `menuTitle(for:)` 保留，内部调用新方法传 `MenuBarConfig()`

单个 item 按 style 产出：
| style | CPU example | Network example |
|-------|------------|----------------|
| emoji | `🔥 23%` | `🌐↓1.2M↑300K` |
| label | `CPU 23%` | `NET↓1.2M↑300K` |
| number | `23%` | `↓1.2M↑300K` |

## Preferences UI

- 在下拉面板 footer `HStack` 中，Quit 按钮左侧添加齿轮 `⚙` 按钮
- 点击齿轮弹出 Popover（不是独立窗口），指向按钮
- Popover 布局：标题 "Menu Bar Display"，4 行 Checkbox + Picker，底部 Reset 按钮

```
┌─────────────────────────────┐
│  ⚙ Menu Bar Display         │
│                             │
│  Show  Style                │
│  [✓]  CPU   [🔥 emoji  ▾]  │
│  [✓]  MEM   [💾 emoji  ▾]  │
│  [✓]  NET   [🌐 emoji  ▾]  │
│  [✓]  DSK   [💿 emoji  ▾]  │
│                             │
│  [Reset to default]        │
└─────────────────────────────┘
```

实现要点：
- `@State showPrefs` 控制 Popover
- 每行一个 Toggle + Picker，绑定 `@Bindable config`
- 配置变更实时写入 UserDefaults
- Reset：`MenuBarConfig()` → save() → menu bar 立即更新

## Live Refresh on Config Change

方案：`MetricsStore` 监听 `UserDefaults.didChangeNotification`，收到通知后触发 `objectWillChange.send()` 让 View 重建，菜单栏 label 自动重读 config。

不需要 Timer 也不需要轮询。

## Warm/Hot Color Logic

保持现有：CPU > 90% 或 memory > 90% 菜单栏变红，不受配置影响。

## Testing

- `MenuBarConfig` round-trip encode/decode
- `menuTitle(for:config:)` 各种组合：全隐藏、部分隐藏、风格切换、空配置兜底
- 按现有测试框架（Swift Testing）

## Files Changed

| File | Change |
|------|--------|
| `Sources/StatBarCore/MenuBarConfig.swift` | 新建 |
| `Sources/StatBarCore/SystemMetrics.swift` | `StatBarFormatter` 新增重载 |
| `Sources/StatBar/StatBarApp.swift` | 菜单栏 label 读 config；footer 加齿轮按钮 + Popover 偏好面板；空状态监听 |
| `Tests/StatBarCoreTests/StatBarCoreTests.swift` | 新增 config / formatter 测试 |
