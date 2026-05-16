import Darwin
import Foundation

// MARK: - Uptime

public struct SystemUptimeProvider: Sendable {
    public init() {}

    public func uptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        guard sysctl(&mib, 2, &boottime, &size, nil, 0) == 0 else {
            return 0
        }

        let now = Date().timeIntervalSince1970
        let boot = TimeInterval(boottime.tv_sec) + TimeInterval(boottime.tv_usec) / 1_000_000
        return max(0, now - boot)
    }
}

// MARK: - Disk

public struct DiskInfoProvider: Sendable {
    public init() {}

    public func snapshot() -> DiskMetrics {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/") else {
            return DiskMetrics(usedBytes: 0, totalBytes: 0)
        }

        let total = attributes[.systemSize] as? UInt64 ?? 0
        let free = attributes[.systemFreeSize] as? UInt64 ?? 0
        let used = total > free ? total - free : 0

        return DiskMetrics(usedBytes: used, totalBytes: total)
    }
}

// MARK: - Network Rate

public struct NetworkRateProvider: Sendable {
    private var previous: NetworkSample?

    public init() {}

    public mutating func snapshot() -> NetworkMetrics {
        let now = Date()
        guard let current = readInterfaces() else {
            return NetworkMetrics(downBytesPerSec: 0, upBytesPerSec: 0)
        }

        defer { previous = (current, now) }

        guard let (prevBytes, prevTime) = previous else {
            return NetworkMetrics(downBytesPerSec: 0, upBytesPerSec: 0)
        }

        let elapsed = now.timeIntervalSince(prevTime)
        guard elapsed > 0 else {
            return NetworkMetrics(downBytesPerSec: 0, upBytesPerSec: 0)
        }

        let downDelta = current.down.saturatingSubtract(prevBytes.down)
        let upDelta = current.up.saturatingSubtract(prevBytes.up)

        return NetworkMetrics(
            downBytesPerSec: UInt64(Double(downDelta) / elapsed),
            upBytesPerSec: UInt64(Double(upDelta) / elapsed)
        )
    }

    private func readInterfaces() -> (down: UInt64, up: UInt64)? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(first) }

        var totalDown: UInt64 = 0
        var totalUp: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let addr = ptr?.pointee.ifa_addr,
                  addr.pointee.sa_family == AF_LINK,
                  let data = ptr?.pointee.ifa_data else { continue }

            let name = String(cString: ptr!.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("wl") else { continue }

            let networkData = data.assumingMemoryBound(to: if_data.self).pointee
            totalDown += UInt64(networkData.ifi_ibytes)
            totalUp += UInt64(networkData.ifi_obytes)
        }

        return (totalDown, totalUp)
    }

    private typealias NetworkSample = (bytes: (down: UInt64, up: UInt64), time: Date)
}

// MARK: - Battery

public struct BatteryInfoProvider: Sendable {
    private let cache = OSAtomic<BatteryCache>(default: BatteryCache())

    public init() {}

    public func snapshot() -> BatteryMetrics {
        let now = Date()
        let cached = cache.load()
        // Reuse cached cycle/health for 5 minutes, only refresh level each call
        let useCache = now.timeIntervalSince(cached.refreshedAt) < 300 && cached.isPresent

        let (level, isPresent) = readBatteryLevel()
        guard isPresent else {
            cache.store(BatteryCache(isPresent: false, refreshedAt: now, cycles: 0, health: ""))
            return BatteryMetrics(level: 0, cycleCount: 0, health: "", isPresent: false)
        }

        let cycles: Int
        let health: String

        if useCache {
            cycles = cached.cycles
            health = cached.health
        } else {
            (cycles, health) = readCycleAndHealth()
            cache.store(BatteryCache(isPresent: true, refreshedAt: now, cycles: cycles, health: health))
        }

        return BatteryMetrics(level: level, cycleCount: cycles, health: health, isPresent: true)
    }

    private func readBatteryLevel() -> (Double, Bool) {
        guard let output = Process.runWithTimeout(
            launchPath: "/usr/bin/pmset",
            arguments: ["-g", "batt"],
            timeout: 1.0
        ) else { return (0, false) }

        guard output.contains("InternalBattery") else { return (0, false) }

        if let range = output.range(of: #"\d+%"#, options: .regularExpression) {
            return (Double(output[range].replacingOccurrences(of: "%", with: "")) ?? 0, true)
        }
        return (0, false)
    }

    private func readCycleAndHealth() -> (Int, String) {
        guard let output = Process.runWithTimeout(
            launchPath: "/usr/sbin/ioreg",
            arguments: ["-r", "-c", "AppleSmartBattery"],
            timeout: 1.0
        ) else { return (0, "Good") }

        var cycles = 0
        var health = "Good"

        for line in output.components(separatedBy: "\n") {
            if line.contains("CycleCount") {
                let digits = line.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                cycles = Int(digits) ?? 0
            }
            if line.contains("PermanentFailureStatus") && line.contains("1") {
                health = "Service"
            }
        }

        return (cycles, health)
    }
}

private struct BatteryCache: Sendable {
    let isPresent: Bool
    let refreshedAt: Date
    let cycles: Int
    let health: String

    init(isPresent: Bool = false, refreshedAt: Date = .distantPast, cycles: Int = 0, health: String = "") {
        self.isPresent = isPresent
        self.refreshedAt = refreshedAt
        self.cycles = cycles
        self.health = health
    }
}

private final class OSAtomic<T: Sendable>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(default: T) { self.value = `default` }

    func load() -> T { lock.lock(); defer { lock.unlock() }; return value }
    func store(_ newValue: T) { lock.lock(); defer { lock.unlock() }; value = newValue }
}

// MARK: - Top Processes

public struct TopProcessesProvider: Sendable {
    public init() {}

    public func snapshot() -> [TopProcessInfo] {
        guard let output = Process.runWithTimeout(
            launchPath: "/bin/ps",
            arguments: ["-A", "-o", "pid,%cpu,comm", "-r"],
            timeout: 1.0
        ) else { return [] }

        var processes: [TopProcessInfo] = []

        for line in output.components(separatedBy: "\n").dropFirst() {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3 else { continue }
            guard let cpu = Double(parts[1]) else { continue }
            let name = String(parts.suffix(from: 2).joined(separator: " "))
            guard !name.hasPrefix("-") else { continue }
            processes.append(TopProcessInfo(name: name, cpuPercent: cpu))
            if processes.count >= 5 { break }
        }

        return processes
    }
}

extension Process {
    static func runWithTimeout(launchPath: String, arguments: [String], timeout: TimeInterval) -> String? {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while task.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if task.isRunning {
            task.terminate()
            return nil
        }

        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}

// MARK: - DeepSeek Balance

public struct DeepSeekBalanceProvider: Sendable {
    private let baseURL = "https://api.deepseek.com"
    private let cacheInterval: TimeInterval = 30
    private var cachedMetrics: DeepSeekMetrics?
    private var lastFetch: Date = .distantPast

    public init() {}

    public mutating func snapshot() -> DeepSeekMetrics {
        let now = Date()
        if let cached = cachedMetrics, now.timeIntervalSince(lastFetch) < cacheInterval {
            return cached
        }

        guard let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !apiKey.isEmpty else {
            let empty = DeepSeekMetrics(isAvailable: false)
            cachedMetrics = empty
            lastFetch = now
            return empty
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/user/balance")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let box = OSAtomic<DeepSeekMetrics>(default: DeepSeekMetrics(isAvailable: false))
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let isAvailable = json["is_available"] as? Bool,
                  let infos = json["balance_infos"] as? [[String: Any]] else { return }

            let target = infos.first(where: { $0["currency"] as? String == "CNY" }) ?? infos.first
            guard let totalStr = target?["total_balance"] as? String,
                  let total = Double(totalStr) else { return }

            box.store(DeepSeekMetrics(
                totalBalance: total,
                currency: (target?["currency"] as? String) ?? "CNY",
                isAvailable: isAvailable,
                loadedAt: Date()
            ))
        }
        task.resume()
        semaphore.wait()

        let metrics = box.load()
        cachedMetrics = metrics
        lastFetch = now
        return metrics
    }

    public mutating func forceRefresh() -> DeepSeekMetrics {
        lastFetch = .distantPast
        return snapshot()
    }
}

private extension UInt64 {
    func saturatingSubtract(_ other: UInt64) -> UInt64 {
        self >= other ? self - other : 0
    }
}
