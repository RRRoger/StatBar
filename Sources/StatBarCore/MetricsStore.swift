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

    public func refreshDeepSeek() {
        let providerCopy = provider
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var p = providerCopy
            let deepseek = p.refreshDeepSeek()
            DispatchQueue.main.async {
                var snap = self?.snapshot ?? SystemSnapshot(
                    cpu: CPUMetrics(usage: 0),
                    memory: MemoryMetrics(usedBytes: 0, totalBytes: 0)
                )
                snap.deepseek = deepseek
                self?.snapshot = snap
                self?.provider = p
            }
        }
    }

    public func refresh() {
        let providerCopy = provider
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var p = providerCopy
            let snap = p.snapshot()
            DispatchQueue.main.async {
                self?.snapshot = snap
                self?.provider = p
            }
        }
    }
}
