# StatBar

Mac 状态栏系统监控工具，极简 emoji 风格，点击展开详细面板。

## 功能

**菜单栏：** `🔥23% 💾58% 🌐↓1.2M↑300K 💿42%`（CPU、内存、网络速率、磁盘）

**下拉面板：**
- CPU 使用率、内存（已用/总量）
- 网络上下行速率、磁盘使用率
- 电池电量、循环次数、健康状态
- Top 5 进程（按 CPU 排序）
- 🤖 DeepSeek 账户余额（需配置 API Key）
- 系统运行时长、数据刷新时间

CPU 或内存超过 90% 时菜单栏文字变红。

## 技术栈

- Swift 6 / SwiftUI
- macOS 15+ 原生 App
- 无需 Xcode，Swift Package Manager + Command Line Tools 即可构建

## 本地运行

```bash
# 运行测试（24 个）
swift test

# 构建
swift build

# 打包 .app（自动递增构建版本号）
./scripts/build-app.sh
open .build/StatBar.app
```

## 配置 DeepSeek 余额显示

```bash
launchctl setenv DEEPSEEK_API_KEY "sk-你的key"
```

然后重新打开 StatBar，下拉面板中点击 DeepSeek 旁边的刷新按钮。

## 项目结构

```
Sources/StatBar/          # SwiftUI 菜单栏 App
Sources/StatBarCore/      # 核心数据模型、Formatter、系统指标采集
Tests/StatBarCoreTests/   # 单元测试
scripts/build-app.sh      # .app 打包脚本
Resources/                # 头像等资源文件
```
