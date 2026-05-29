import Foundation
import Observation

@MainActor
@Observable
public final class MetricsStore {
    public private(set) var snapshot: SystemSnapshot

    private var provider: any SystemMetricsProviding
    private var refreshTask: Task<Void, Never>?
    private var audioTask: Task<Void, Never>?
    private var refreshInterval: Duration
    private var isRunning = false
    private let audioProvider = AudioMonitorProvider()
    private let videoProvider = VideoAppProvider()
    private var audioStarted = false

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
        isRunning = true
        refresh()
        startAudioCapture()
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: self?.refreshInterval ?? .seconds(2))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
        // Separate high-frequency audio refresh (~10fps)
        audioTask?.cancel()
        audioTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                self?.refreshAudioLevel()
            }
        }
    }

    public func stop() {
        isRunning = false
        refreshTask?.cancel()
        refreshTask = nil
        audioTask?.cancel()
        audioTask = nil
        audioProvider.stop()
    }

    public func updateRefreshInterval(_ interval: Duration) {
        guard refreshInterval != interval else { return }
        refreshInterval = interval
        if isRunning {
            start()
        }
    }

    private func startAudioCapture() {
        guard !audioStarted else { return }
        audioStarted = true
        Task {
            await audioProvider.start()
        }
    }

    private func refreshAudioLevel() {
        var snap = snapshot
        snap.audio = AudioLevelMetrics(
            currentLevel: audioProvider.currentLevel(),
            waveformData: audioProvider.waveform(),
            isActive: audioProvider.currentLevel() > 0.01
        )
        snapshot = snap
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
        let videoP = videoProvider
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var p = providerCopy
            var snap = p.snapshot()
            snap.video = videoP.snapshot()
            DispatchQueue.main.async {
                self?.snapshot = snap
                self?.provider = p
            }
        }
    }
}
