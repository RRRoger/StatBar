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

public struct SystemSnapshot: Equatable, Sendable {
    public var cpu: CPUMetrics
    public var memory: MemoryMetrics
    public var capturedAt: Date

    public init(cpu: CPUMetrics, memory: MemoryMetrics, capturedAt: Date = Date()) {
        self.cpu = cpu
        self.memory = memory
        self.capturedAt = capturedAt
    }
}

public protocol SystemMetricsProviding: Sendable {
    mutating func snapshot() -> SystemSnapshot
}

public struct StatBarFormatter: Sendable {
    public init() {}

    public func menuTitle(for snapshot: SystemSnapshot) -> String {
        "C \(wholePercent(snapshot.cpu.usage))% M \(wholePercent(snapshot.memory.usage))%"
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

    private func wholePercent(_ value: Double) -> Int {
        Int(value.clampedPercent.rounded())
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
            capturedAt: Date()
        )
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
