# StatBar

Mac 状态栏系统监控工具，在菜单栏显示 CPU、内存等关键指标，点击可展开查看详细数据。

## 技术栈

- Swift / SwiftUI
- macOS 原生 App

## 功能规划

- 状态栏实时显示关键数字（如 CPU 占用百分比）
- 点击图标展开下拉菜单，查看 CPU、内存、网络等详细数据
- 支持自定义显示项

## 开发环境

- macOS 15+
- Xcode 16+

## 本地运行

```bash
# 运行核心测试
swift test

# SwiftPM 构建
swift build

# 无 Xcode 打包成 .app
./scripts/build-app.sh
open .build/StatBar.app

# 使用完整 Xcode 时构建/测试 App
xcodebuild -project StatBar.xcodeproj -scheme StatBar build
xcodebuild -project StatBar.xcodeproj -scheme StatBar test
```

也可以直接打开 `StatBar.xcodeproj`，选择 `StatBar` scheme 运行。运行后菜单栏会显示类似 `C 23% M 58%` 的实时摘要，点击后展开详情面板。
