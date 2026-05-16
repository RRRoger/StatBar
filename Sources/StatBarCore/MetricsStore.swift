import Foundation
import Observation

@MainActor
@Observable
public final class MetricsStore {
    public private(set) var snapshot: SystemSnapshot

    private var provider: any SystemMetricsProviding
    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: Duration

    public init(
        provider: any SystemMetricsProviding = MacSystemMetricsProvider(),
        refreshInterval: Duration = .seconds(2)
    ) {
        self.provider = provider
        self.refreshInterval = refreshInterval
        self.snapshot = SystemSnapshot(
            cpu: CPUMetrics(usage: 0),
            memory: MemoryMetrics(usedBytes: 0, totalBytes: ProcessInfo.processInfo.physicalMemory)
        )
    }

    public func start() {
        refresh()
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: self?.refreshInterval ?? .seconds(2))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    public func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func refresh() {
        snapshot = provider.snapshot()
    }
}
