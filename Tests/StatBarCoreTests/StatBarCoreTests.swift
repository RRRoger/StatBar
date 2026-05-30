import Foundation
import Testing
@testable import StatBarCore

@Test func menuTitleUsesRoundedWholePercentages() {
    let snapshot = SystemSnapshot(
        cpu: CPUMetrics(usage: 22.6),
        memory: MemoryMetrics(usedBytes: 65, totalBytes: 100)
    )

    #expect(StatBarFormatter().menuTitle(for: snapshot) == "🔥 23% 💾 65% 🌐 ↓0↑0 💿 0%")
}

@Test func percentValuesAreClamped() {
    #expect(CPUMetrics(usage: -4).usage == 0)
    #expect(CPUMetrics(usage: 104).usage == 100)
}

@Test func memoryUsageHandlesZeroTotal() {
    let memory = MemoryMetrics(usedBytes: 20, totalBytes: 0)

    #expect(memory.usage == 0)
}

@Test func memoryUsageComputesPercentOfTotal() {
    let memory = MemoryMetrics(usedBytes: 3, totalBytes: 4)

    #expect(memory.usage == 75)
}

@Test func cpuUsageCalculatorUsesDeltaExcludingIdleTicks() {
    let previous = CPUTickSample(user: 100, system: 50, idle: 850, nice: 0)
    let current = CPUTickSample(user: 150, system: 100, idle: 900, nice: 0)

    let usage = CPUUsageCalculator().usage(previous: previous, current: current)

    #expect(abs(usage - 66.666) < 0.01)
}

@Test func cpuUsageCalculatorHandlesUnchangedSamples() {
    let sample = CPUTickSample(user: 10, system: 20, idle: 30, nice: 40)

    #expect(CPUUsageCalculator().usage(previous: sample, current: sample) == 0)
}

@Test func byteFormatterUsesReadableUnits() {
    let text = StatBarFormatter().bytesText(1_073_741_824)

    #expect(text.contains("1"))
    #expect(text.localizedCaseInsensitiveContains("GB"))
}

// MARK: - Emoji menu title

@Test func menuTitleUsesEmojiFormat() {
    let snapshot = SystemSnapshot(
        cpu: CPUMetrics(usage: 23),
        memory: MemoryMetrics(usedBytes: 12_000_000_000, totalBytes: 24_000_000_000),
        network: NetworkMetrics(downBytesPerSec: 1_200_000, upBytesPerSec: 300_000),
        disk: DiskMetrics(usedBytes: 210_000_000_000, totalBytes: 500_000_000_000),
        capturedAt: Date()
    )

    let title = StatBarFormatter().menuTitle(for: snapshot)
    #expect(title.contains("🔥"))
    #expect(title.contains("23%"))
    #expect(title.contains("💾"))
    #expect(title.contains("50%"))
}

// MARK: - NetworkMetrics

@Test func networkMetricsStoresRates() {
    let net = NetworkMetrics(downBytesPerSec: 1_500_000, upBytesPerSec: 500_000)
    #expect(net.downBytesPerSec == 1_500_000)
    #expect(net.upBytesPerSec == 500_000)
}

@Test func networkRateFormatterShowsMBPerSec() {
    let text = StatBarFormatter().networkRateText(1_500_000)
    #expect(text.contains("1.5"))
    #expect(text.localizedCaseInsensitiveContains("MB"))
}

@Test func networkRateFormatterShowsKBPerSec() {
    let text = StatBarFormatter().networkRateText(500_000)
    #expect(text.localizedCaseInsensitiveContains("KB"))
}

// MARK: - DiskMetrics

@Test func diskMetricsUsagePercent() {
    let disk = DiskMetrics(usedBytes: 250_000_000_000, totalBytes: 500_000_000_000)
    #expect(disk.usage == 50)
}

@Test func diskMetricsHandlesZeroTotal() {
    let disk = DiskMetrics(usedBytes: 100, totalBytes: 0)
    #expect(disk.usage == 0)
}

// MARK: - BatteryMetrics

@Test func batteryMetricsReportsPresence() {
    let present = BatteryMetrics(level: 85, cycleCount: 100, health: "Good", isPresent: true)
    #expect(present.isPresent)
    let absent = BatteryMetrics(level: 0, cycleCount: 0, health: "", isPresent: false)
    #expect(!absent.isPresent)
}

@Test func batteryLevelClamped() {
    #expect(BatteryMetrics(level: -5, cycleCount: 0, health: "", isPresent: true).level == 0)
    #expect(BatteryMetrics(level: 110, cycleCount: 0, health: "", isPresent: true).level == 100)
}

// MARK: - Uptime formatting

@Test func uptimeFormatterShowsReadableDuration() {
    // 3 days + 12 hours + 34 minutes in seconds
    let uptime = TimeInterval(304_440)
    let text = StatBarFormatter().uptimeText(uptime)
    #expect(text.contains("3"))
    #expect(text.contains("d"))
}

// MARK: - UptimeProvider

@Test func uptimeProviderReturnsNonNegativeValue() {
    var provider = SystemUptimeProvider()
    let uptime = provider.uptime()
    #expect(uptime >= 0)
}

// MARK: - DiskInfoProvider

@Test func diskInfoProviderReturnsRootVolumeData() {
    var provider = DiskInfoProvider()
    let disk = provider.snapshot()
    #expect(disk.totalBytes > 0)
    #expect(disk.usage >= 0)
    #expect(disk.usage <= 100)
}

// MARK: - NetworkRateProvider

@Test func networkRateProviderReturnsNonNegativeRates() {
    var provider = NetworkRateProvider()
    let net = provider.snapshot()
    #expect(net.downBytesPerSec >= 0)
    #expect(net.upBytesPerSec >= 0)
}

// MARK: - TopProcessesProvider

@Test func topProcessesProviderReturnsAtMostFiveProcesses() {
    var provider = TopProcessesProvider()
    let processes = provider.snapshot()
    #expect(processes.count <= 5)
    for process in processes {
        #expect(!process.name.isEmpty)
        #expect(process.cpuPercent >= 0)
    }
}

// MARK: - BatteryInfoProvider

@Test func batteryInfoProviderReturnsPresenceFlag() {
    var provider = BatteryInfoProvider()
    let battery = provider.snapshot()
    // Either present with valid data, or absent
    if battery.isPresent {
        #expect(battery.level >= 0)
        #expect(battery.level <= 100)
    } else {
        #expect(battery.level == 0)
    }
}

// MARK: - DeepSeek Metrics

@Test func deepseekMetricsFormatsBalance() {
    let metrics = DeepSeekMetrics(totalBalance: 54.69, currency: "CNY", isAvailable: true)
    #expect(metrics.formattedBalance == "54.69")
}

@Test func deepseekMetricsDefaultIsUnavailable() {
    let metrics = DeepSeekMetrics()
    #expect(!metrics.isAvailable)
    #expect(metrics.totalBalance == 0)
    #expect(metrics.formattedBalance == "0.00")
}

@Test func deepseekMetricsEquatable() {
    let a = DeepSeekMetrics(totalBalance: 10.0, currency: "CNY", isAvailable: true)
    let b = DeepSeekMetrics(totalBalance: 10.0, currency: "CNY", isAvailable: true)
    let c = DeepSeekMetrics(totalBalance: 20.0, currency: "CNY", isAvailable: true)
    #expect(a == b)
    #expect(a != c)
}

// MARK: - MenuBarConfig

@Test func menuBarConfigDefaultAllVisible() {
    let config = MenuBarConfig()
    #expect(config.cpu.visible)
    #expect(config.memory.visible)
    #expect(config.network.visible)
    #expect(config.disk.visible)
}

@Test func menuBarConfigDefaultStyleIsEmoji() {
    let config = MenuBarConfig()
    #expect(config.cpu.style == .emoji)
    #expect(config.memory.style == .emoji)
    #expect(config.network.style == .emoji)
    #expect(config.disk.style == .emoji)
}

@Test func menuBarConfigRoundTripCodable() throws {
    var config = MenuBarConfig()
    config.cpu.visible = false
    config.memory.style = .label
    config.network.style = .number
    config.disk.visible = true

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let data = try encoder.encode(config)
    let decoded = try decoder.decode(MenuBarConfig.self, from: data)

    #expect(decoded == config)
    #expect(decoded.cpu.visible == false)
    #expect(decoded.memory.style == .label)
    #expect(decoded.network.style == .number)
    #expect(decoded.disk.visible == true)
}

// MARK: - StatBarSettings

@Test func statBarSettingsDefaultsMatchCurrentAppBehavior() {
    let settings = StatBarSettings()

    #expect(settings.menuBar == MenuBarConfig())
    #expect(settings.refresh.mode == .standard)
    #expect(settings.refresh.interval == .seconds(2))
    #expect(settings.alerts.cpuHighUsagePercent == 90)
    #expect(settings.alerts.memoryHighUsagePercent == 90)
    #expect(settings.alerts.diskHighUsagePercent == 90)
    #expect(settings.alerts.deepSeekLowBalance == 10)
    #expect(settings.profile.displayName == "陈鹏")
    #expect(settings.profile.subtitle == "你的 Mac 此刻状态")
}

@Test func statBarSettingsRoundTripCodable() throws {
    var settings = StatBarSettings()
    settings.menuBar.cpu.visible = false
    settings.refresh.mode = .highFrequency
    settings.alerts.cpuHighUsagePercent = 75
    settings.alerts.deepSeekLowBalance = 3.5
    settings.profile.displayName = "Roger"
    settings.profile.subtitle = "Mac dashboard"

    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(StatBarSettings.self, from: data)

    #expect(decoded == settings)
    #expect(decoded.refresh.interval == .seconds(1))
}

@Test func refreshModeMapsToIntervals() {
    #expect(RefreshMode.lowPower.interval == .seconds(5))
    #expect(RefreshMode.standard.interval == .seconds(2))
    #expect(RefreshMode.highFrequency.interval == .seconds(1))
}

@Test func alertSettingsClampValues() {
    var alerts = AlertSettings(
        cpuHighUsagePercent: -10,
        memoryHighUsagePercent: 150,
        diskHighUsagePercent: 101,
        deepSeekLowBalance: -2
    )

    #expect(alerts.cpuHighUsagePercent == 0)
    #expect(alerts.memoryHighUsagePercent == 100)
    #expect(alerts.diskHighUsagePercent == 100)
    #expect(alerts.deepSeekLowBalance == 0)

    alerts.cpuHighUsagePercent = 101
    alerts.memoryHighUsagePercent = -1
    alerts.diskHighUsagePercent = 42
    alerts.deepSeekLowBalance = -10

    #expect(alerts.cpuHighUsagePercent == 100)
    #expect(alerts.memoryHighUsagePercent == 0)
    #expect(alerts.diskHighUsagePercent == 42)
    #expect(alerts.deepSeekLowBalance == 0)
}

@Test func profileSettingsFallbackForEmptyText() {
    var profile = ProfileSettings(displayName: "   ", subtitle: "")

    #expect(profile.displayName == "陈鹏")
    #expect(profile.subtitle == "你的 Mac 此刻状态")

    profile.displayName = ""
    profile.subtitle = "   "

    #expect(profile.displayName == "陈鹏")
    #expect(profile.subtitle == "你的 Mac 此刻状态")
}

// MARK: - Config-aware menu title

@Test func menuTitleHidesItemsWhenNotVisible() {
    var config = MenuBarConfig()
    config.cpu.visible = false
    config.memory.visible = false
    config.network.visible = false

    let snapshot = SystemSnapshot(
        cpu: CPUMetrics(usage: 50),
        memory: MemoryMetrics(usedBytes: 1, totalBytes: 1),
        disk: DiskMetrics(usedBytes: 1, totalBytes: 2),
        capturedAt: Date()
    )
    let title = StatBarFormatter().menuTitle(for: snapshot, config: config)
    #expect(!title.contains("🔥"))
    #expect(!title.contains("💾"))
    #expect(!title.contains("🌐"))
    #expect(title.contains("💿"))
}

@Test func menuTitleUsesLabelStyle() {
    var config = MenuBarConfig()
    config.cpu.style = .label
    config.memory.visible = false
    config.network.visible = false
    config.disk.visible = false

    let snapshot = SystemSnapshot(
        cpu: CPUMetrics(usage: 80),
        memory: MemoryMetrics(usedBytes: 0, totalBytes: 1),
        capturedAt: Date()
    )
    let title = StatBarFormatter().menuTitle(for: snapshot, config: config)
    #expect(title.contains("CPU"))
    #expect(title.contains("80%"))
    #expect(!title.contains("🔥"))
    #expect(title == "CPU 80%")
}

@Test func menuTitleUsesNumberStyle() {
    var config = MenuBarConfig()
    config.cpu.style = .number
    config.memory.visible = false
    config.network.visible = false
    config.disk.visible = false

    let snapshot = SystemSnapshot(
        cpu: CPUMetrics(usage: 90),
        memory: MemoryMetrics(usedBytes: 0, totalBytes: 1),
        capturedAt: Date()
    )
    let title = StatBarFormatter().menuTitle(for: snapshot, config: config)
    #expect(title == "90%")
}

// MARK: - Dynamic Island formatter

@Test func islandSummaryTitleShowsCoreMetrics() {
    let snapshot = SystemSnapshot(
        cpu: CPUMetrics(usage: 22.6),
        memory: MemoryMetrics(usedBytes: 65, totalBytes: 100),
        network: NetworkMetrics(downBytesPerSec: 1_200_000, upBytesPerSec: 300_000),
        capturedAt: Date()
    )

    let title = StatBarFormatter().islandSummaryTitle(for: snapshot, config: MenuBarConfig())
    #expect(title == "🔥 23% 💾 65% ↓1.2MB/s ↑300KB/s")
}

@Test func islandSummaryTitleHidesInvisibleItems() {
    var config = MenuBarConfig()
    config.cpu.visible = false
    config.network.visible = false

    let snapshot = SystemSnapshot(
        cpu: CPUMetrics(usage: 50),
        memory: MemoryMetrics(usedBytes: 1, totalBytes: 2),
        network: NetworkMetrics(downBytesPerSec: 1_200_000, upBytesPerSec: 300_000),
        capturedAt: Date()
    )

    let title = StatBarFormatter().islandSummaryTitle(for: snapshot, config: config)
    #expect(!title.contains("🔥"))
    #expect(!title.contains("↓"))
    #expect(title.contains("💾"))
    #expect(title.contains("50%"))
}

@Test func islandSummaryTitleReturnsStatBarWhenAllSummaryItemsHidden() {
    var config = MenuBarConfig()
    config.cpu.visible = false
    config.memory.visible = false
    config.network.visible = false
    config.disk.visible = false

    let snapshot = SystemSnapshot(
        cpu: CPUMetrics(usage: 0),
        memory: MemoryMetrics(usedBytes: 0, totalBytes: 1),
        capturedAt: Date()
    )

    let title = StatBarFormatter().islandSummaryTitle(for: snapshot, config: config)
    #expect(title == "StatBar")
}

@Test func menuTitleReturnsStatBarWhenAllHidden() {
    var config = MenuBarConfig()
    config.cpu.visible = false
    config.memory.visible = false
    config.network.visible = false
    config.disk.visible = false

    let snapshot = SystemSnapshot(
        cpu: CPUMetrics(usage: 0),
        memory: MemoryMetrics(usedBytes: 0, totalBytes: 1),
        capturedAt: Date()
    )
    let title = StatBarFormatter().menuTitle(for: snapshot, config: config)
    #expect(title == "StatBar")
}

// MARK: - SystemMood

@Test func systemMoodIdleWhenLowMemory() {
    let mood = SystemMood(cpuUsage: 80, memoryUsage: 20)
    #expect(mood == .idle)
    #expect(mood.emoji == "😌")
}

@Test func systemMoodRelaxedWhenModerateMemory() {
    let mood = SystemMood(cpuUsage: 90, memoryUsage: 45)
    #expect(mood == .relaxed)
    #expect(mood.emoji == "🙂")
}

@Test func systemMoodBusyWhenHighMemory() {
    let mood = SystemMood(cpuUsage: 30, memoryUsage: 65)
    #expect(mood == .busy)
    #expect(mood.emoji == "😐")
}

@Test func systemMoodStressedWhenVeryHighMemory() {
    let mood = SystemMood(cpuUsage: 20, memoryUsage: 85)
    #expect(mood == .stressed)
    #expect(mood.emoji == "😤")
}

@Test func systemMoodOnFireWhenMemoryFull() {
    let mood = SystemMood(cpuUsage: 50, memoryUsage: 96)
    #expect(mood == .onFire)
    #expect(mood.emoji == "🔥")
}

@Test func systemMoodCpuBoostsOnlyAtExtreme() {
    // CPU 98%+ triggers boost even if memory is moderate
    let mood = SystemMood(cpuUsage: 98, memoryUsage: 40)
    #expect(mood == .onFire)
    // CPU 95% alone does NOT boost
    let mood2 = SystemMood(cpuUsage: 95, memoryUsage: 40)
    #expect(mood2 == .relaxed)
}

@Test func systemMoodLabelIsChinese() {
    #expect(SystemMood(cpuUsage: 5, memoryUsage: 10).label == "空闲")
    #expect(SystemMood(cpuUsage: 5, memoryUsage: 40).label == "轻松")
    #expect(SystemMood(cpuUsage: 5, memoryUsage: 65).label == "繁忙")
    #expect(SystemMood(cpuUsage: 5, memoryUsage: 85).label == "高压")
    #expect(SystemMood(cpuUsage: 5, memoryUsage: 97).label == "过载")
}

@Test func systemSnapshotMoodComputed() {
    let snapshot = SystemSnapshot(
        cpu: CPUMetrics(usage: 50),
        memory: MemoryMetrics(usedBytes: 97, totalBytes: 100)
    )
    #expect(snapshot.mood == .onFire)
}
