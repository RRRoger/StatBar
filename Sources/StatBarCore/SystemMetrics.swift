import Darwin
import Foundation

public struct CPUMetrics: Equatable, Sendable {
    public var usage: Double

    public init(usage: Double) {
        self.usage = usage.clampedPercent
    }
}

public struct MemoryMetrics: Equatable, Sendable {
    public var usedBytes: UInt64
    public var totalBytes: UInt64

    public init(usedBytes: UInt64, totalBytes: UInt64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }

    public var usage: Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(usedBytes) / Double(totalBytes) * 100).clampedPercent
    }
}

public struct NetworkMetrics: Equatable, Sendable {
    public var downBytesPerSec: UInt64
    public var upBytesPerSec: UInt64

    public init(downBytesPerSec: UInt64, upBytesPerSec: UInt64) {
        self.downBytesPerSec = downBytesPerSec
        self.upBytesPerSec = upBytesPerSec
    }
}

public struct DiskMetrics: Equatable, Sendable {
    public var usedBytes: UInt64
    public var totalBytes: UInt64

    public init(usedBytes: UInt64, totalBytes: UInt64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
    }

    public var usage: Double {
        guard totalBytes > 0 else { return 0 }
        return (Double(usedBytes) / Double(totalBytes) * 100).clampedPercent
    }
}

public struct BatteryMetrics: Equatable, Sendable {
    public var level: Double
    public var cycleCount: Int
    public var health: String
    public var isPresent: Bool

    public init(level: Double, cycleCount: Int, health: String, isPresent: Bool) {
        self.level = level.clampedPercent
        self.cycleCount = cycleCount
        self.health = health
        self.isPresent = isPresent
    }
}

public struct TopProcessInfo: Equatable, Sendable {
    public var name: String
    public var cpuPercent: Double

    public init(name: String, cpuPercent: Double) {
        self.name = name
        self.cpuPercent = cpuPercent.clampedPercent
    }
}

public struct DeepSeekMetrics: Equatable, Sendable {
    public var totalBalance: Double
    public var currency: String
    public var isAvailable: Bool
    public var loadedAt: Date

    public init(totalBalance: Double = 0, currency: String = "CNY", isAvailable: Bool = false, loadedAt: Date = .distantPast) {
        self.totalBalance = totalBalance
        self.currency = currency
        self.isAvailable = isAvailable
        self.loadedAt = loadedAt
    }

    public var formattedBalance: String {
        String(format: "%.2f", totalBalance)
    }
}

public struct VideoPlaybackInfo: Equatable, Sendable {
    public var isPlaying: Bool
    public var appName: String
    public var windowTitle: String

    public init(isPlaying: Bool = false, appName: String = "", windowTitle: String = "") {
        self.isPlaying = isPlaying
        self.appName = appName
        self.windowTitle = windowTitle
    }
}

public struct SystemSnapshot: Equatable, Sendable {
    public var cpu: CPUMetrics
    public var memory: MemoryMetrics
    public var network: NetworkMetrics
    public var disk: DiskMetrics
    public var battery: BatteryMetrics
    public var topProcesses: [TopProcessInfo]
    public var uptime: TimeInterval
    public var deepseek: DeepSeekMetrics
    public var video: VideoPlaybackInfo
    public var capturedAt: Date

    public init(
        cpu: CPUMetrics,
        memory: MemoryMetrics,
        network: NetworkMetrics = NetworkMetrics(downBytesPerSec: 0, upBytesPerSec: 0),
        disk: DiskMetrics = DiskMetrics(usedBytes: 0, totalBytes: 0),
        battery: BatteryMetrics = BatteryMetrics(level: 0, cycleCount: 0, health: "", isPresent: false),
        topProcesses: [TopProcessInfo] = [],
        uptime: TimeInterval = 0,
        deepseek: DeepSeekMetrics = DeepSeekMetrics(),
        video: VideoPlaybackInfo = VideoPlaybackInfo(),
        capturedAt: Date = Date()
    ) {
        self.cpu = cpu
        self.memory = memory
        self.network = network
        self.disk = disk
        self.battery = battery
        self.topProcesses = topProcesses
        self.uptime = uptime
        self.deepseek = deepseek
        self.video = video
        self.capturedAt = capturedAt
    }
}

public protocol SystemMetricsProviding: Sendable {
    mutating func snapshot() -> SystemSnapshot
    mutating func refreshDeepSeek() -> DeepSeekMetrics
}

public struct StatBarFormatter: Sendable {
    public init() {}

    public func menuTitle(for snapshot: SystemSnapshot) -> String {
        menuTitle(for: snapshot, config: MenuBarConfig())
    }

    public func menuTitle(for snapshot: SystemSnapshot, config: MenuBarConfig) -> String {
        let parts: [String] = [
            itemText(icon: "🔥", label: "CPU", value: "\(wholePercent(snapshot.cpu.usage))%", config: config.cpu),
            itemText(icon: "💾", label: "MEM", value: "\(wholePercent(snapshot.memory.usage))%", config: config.memory),
            itemText(
                icon: "🌐", label: "NET",
                value: "↓\(compactRate(snapshot.network.downBytesPerSec))↑\(compactRate(snapshot.network.upBytesPerSec))",
                config: config.network
            ),
            itemText(icon: "💿", label: "DSK", value: "\(wholePercent(snapshot.disk.usage))%", config: config.disk),
        ].compactMap { $0.isEmpty ? nil : $0 }

        if parts.isEmpty { return "StatBar" }
        return parts.joined(separator: " ")
    }

    private func itemText(icon: String, label: String, value: String, config: MenuBarItemConfig) -> String {
        guard config.visible else { return "" }
        switch config.style {
        case .emoji: return "\(icon) \(value)"
        case .label: return "\(label) \(value)"
        case .number: return value
        }
    }

    public func percentText(_ value: Double) -> String {
        "\(wholePercent(value))%"
    }

    public func bytesText(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: Int64(bytes))
    }

    public func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }

    public func networkRateText(_ bytesPerSec: UInt64) -> String {
        if bytesPerSec >= 1_000_000 {
            String(format: "%.1f MB/s", Double(bytesPerSec) / 1_000_000)
        } else {
            String(format: "%.0f KB/s", Double(bytesPerSec) / 1_000)
        }
    }

    public func uptimeText(_ uptime: TimeInterval) -> String {
        let totalSeconds = Int(uptime)
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        if days > 0 {
            return "\(days)d \(hours):\(String(format: "%02d", minutes))"
        }
        return "\(hours):\(String(format: "%02d", minutes))"
    }

    private func wholePercent(_ value: Double) -> Int {
        Int(value.clampedPercent.rounded())
    }

    public func islandSummaryTitle(for snapshot: SystemSnapshot, config: MenuBarConfig) -> String {
        let parts: [String] = [
            itemText(icon: "🔥", label: "CPU", value: "\(wholePercent(snapshot.cpu.usage))%", config: config.cpu),
            itemText(icon: "💾", label: "MEM", value: "\(wholePercent(snapshot.memory.usage))%", config: config.memory),
            networkSummaryText(for: snapshot, config: config.network),
        ].compactMap { $0.isEmpty ? nil : $0 }

        if parts.isEmpty { return "StatBar" }
        return parts.joined(separator: " ")
    }

    private func networkSummaryText(for snapshot: SystemSnapshot, config: MenuBarItemConfig) -> String {
        guard config.visible else { return "" }
        let down = compactRate(snapshot.network.downBytesPerSec)
        let up = compactRate(snapshot.network.upBytesPerSec)
        switch config.style {
        case .emoji, .number:
            return "↓\(down) ↑\(up)"
        case .label:
            return "NET ↓\(down) ↑\(up)"
        }
    }

    private func compactRate(_ bytesPerSec: UInt64) -> String {
        if bytesPerSec >= 1_000_000 {
            String(format: "%.1fM", Double(bytesPerSec) / 1_000_000)
        } else if bytesPerSec >= 1_000 {
            String(format: "%.0fK", Double(bytesPerSec) / 1_000)
        } else {
            "0"
        }
    }
}

public struct CPUTickSample: Equatable, Sendable {
    public var user: UInt64
    public var system: UInt64
    public var idle: UInt64
    public var nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

public struct CPUUsageCalculator: Sendable {
    public init() {}

    public func usage(previous: CPUTickSample, current: CPUTickSample) -> Double {
        let user = current.user.saturatingDifference(from: previous.user)
        let system = current.system.saturatingDifference(from: previous.system)
        let idle = current.idle.saturatingDifference(from: previous.idle)
        let nice = current.nice.saturatingDifference(from: previous.nice)
        let total = user + system + idle + nice

        guard total > 0 else { return 0 }
        return (Double(total - idle) / Double(total) * 100).clampedPercent
    }
}

public struct MacSystemMetricsProvider: SystemMetricsProviding {
    private var previousCPU: CPUTickSample?
    private let calculator = CPUUsageCalculator()
    private var networkProvider = NetworkRateProvider()
    private let diskProvider = DiskInfoProvider()
    private let batteryProvider = BatteryInfoProvider()
    private let uptimeProvider = SystemUptimeProvider()
    private let topProcessesProvider = TopProcessesProvider()
    private var deepseekProvider = DeepSeekBalanceProvider()

    public init() {}

    public mutating func snapshot() -> SystemSnapshot {
        let currentCPU = readCPUSample()
        let cpuUsage: Double

        if let previousCPU, let currentCPU {
            cpuUsage = calculator.usage(previous: previousCPU, current: currentCPU)
        } else {
            cpuUsage = 0
        }

        if let currentCPU {
            previousCPU = currentCPU
        }

        return SystemSnapshot(
            cpu: CPUMetrics(usage: cpuUsage),
            memory: readMemory(),
            network: networkProvider.snapshot(),
            disk: diskProvider.snapshot(),
            battery: batteryProvider.snapshot(),
            topProcesses: topProcessesProvider.snapshot(),
            uptime: uptimeProvider.uptime(),
            deepseek: deepseekProvider.snapshot(),
            capturedAt: Date()
        )
    }

    public mutating func refreshDeepSeek() -> DeepSeekMetrics {
        deepseekProvider.forceRefresh()
    }

    private func readCPUSample() -> CPUTickSample? {
        var processorInfo: processor_info_array_t?
        var processorMsgCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorMsgCount
        )

        guard result == KERN_SUCCESS, let processorInfo else {
            return nil
        }

        defer {
            let byteCount = vm_size_t(Int(processorMsgCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: processorInfo), byteCount)
        }

        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        var nice: UInt64 = 0
        let stride = Int(CPU_STATE_MAX)

        for cpuIndex in 0..<Int(processorCount) {
            let offset = cpuIndex * stride
            user += UInt64(processorInfo[offset + Int(CPU_STATE_USER)])
            system += UInt64(processorInfo[offset + Int(CPU_STATE_SYSTEM)])
            idle += UInt64(processorInfo[offset + Int(CPU_STATE_IDLE)])
            nice += UInt64(processorInfo[offset + Int(CPU_STATE_NICE)])
        }

        return CPUTickSample(user: user, system: system, idle: idle, nice: nice)
    }

    private func readMemory() -> MemoryMetrics {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return MemoryMetrics(usedBytes: 0, totalBytes: ProcessInfo.processInfo.physicalMemory)
        }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { statsPointer in
            statsPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryMetrics(usedBytes: 0, totalBytes: ProcessInfo.processInfo.physicalMemory)
        }

        let total = ProcessInfo.processInfo.physicalMemory
        let freePages = UInt64(stats.free_count + stats.speculative_count)
        let freeBytes = freePages * UInt64(pageSize)
        let usedBytes = total > freeBytes ? total - freeBytes : 0

        return MemoryMetrics(usedBytes: usedBytes, totalBytes: total)
    }
}

extension Double {
    var clampedPercent: Double {
        min(100, max(0, self))
    }
}

private extension UInt64 {
    func saturatingDifference(from previous: UInt64) -> UInt64 {
        self >= previous ? self - previous : 0
    }
}
