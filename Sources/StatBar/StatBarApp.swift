import AppKit
import StatBarCore
import SwiftUI

@main
struct StatBarApp: App {
    @State private var store = MetricsStore()
    @State private var deepseekRefreshing = false
    private let formatter = StatBarFormatter()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(snapshot: store.snapshot, formatter: formatter, store: store, refreshing: $deepseekRefreshing)
        } label: {
            let title = formatter.menuTitle(for: store.snapshot)
            let isHot = store.snapshot.cpu.usage > 90 || store.snapshot.memory.usage > 90
            Text(title)
                .foregroundStyle(isHot ? .red : .primary)
                .task {
                    store.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarContentView: View {
    let snapshot: SystemSnapshot
    let formatter: StatBarFormatter
    let store: MetricsStore
    @Binding var refreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            cpuSection
            memorySection
            networkSection
            diskSection

            if snapshot.battery.isPresent {
                Divider()
                batterySection
            }

            Divider()

            topProcessesSection

            Divider()

            deepseekSection

            Divider()

            uptimeSection

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("StatBar")
                .font(.headline)
            Text("System monitor")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - CPU

    private var cpuSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("🔥 CPU")
                Spacer()
                Text(formatter.percentText(snapshot.cpu.usage))
                    .monospacedDigit()
            }
            .font(.callout)

            ProgressView(value: min(1, max(0, snapshot.cpu.usage / 100)))
                .progressViewStyle(.linear)
        }
    }

    // MARK: - Memory

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("💾 Memory")
                Spacer()
                Text(formatter.percentText(snapshot.memory.usage))
                    .monospacedDigit()
            }
            .font(.callout)

            ProgressView(value: min(1, max(0, snapshot.memory.usage / 100)))
                .progressViewStyle(.linear)

            HStack {
                Text("Used")
                    .font(.caption)
                Spacer()
                Text(formatter.bytesText(snapshot.memory.usedBytes))
                    .font(.caption)
                    .monospacedDigit()
            }

            HStack {
                Text("Total")
                    .font(.caption)
                Spacer()
                Text(formatter.bytesText(snapshot.memory.totalBytes))
                    .font(.caption)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Network

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("🌐 Network")
                .font(.callout)

            HStack {
                Text("↓ \(formatter.networkRateText(snapshot.network.downBytesPerSec))")
                    .font(.caption)
                Spacer()
                Text("↑ \(formatter.networkRateText(snapshot.network.upBytesPerSec))")
                    .font(.caption)
            }
            .monospacedDigit()
        }
    }

    // MARK: - Disk

    private var diskSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("💿 Disk")
                Spacer()
                Text(formatter.percentText(snapshot.disk.usage))
                    .monospacedDigit()
            }
            .font(.callout)

            ProgressView(value: min(1, max(0, snapshot.disk.usage / 100)))
                .progressViewStyle(.linear)

            HStack {
                Text("Used")
                    .font(.caption)
                Spacer()
                Text(formatter.bytesText(snapshot.disk.usedBytes))
                    .font(.caption)
                    .monospacedDigit()
            }

            HStack {
                Text("Total")
                    .font(.caption)
                Spacer()
                Text(formatter.bytesText(snapshot.disk.totalBytes))
                    .font(.caption)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Top Processes

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("📊 Top Processes")
                .font(.callout)

            ForEach(snapshot.topProcesses, id: \.name) { process in
                HStack {
                    Text(process.name)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(process.cpuPercent.rounded()))%")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Battery

    private var batterySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("⚡ Battery")
                Spacer()
                Text(formatter.percentText(snapshot.battery.level))
                    .monospacedDigit()
            }
            .font(.callout)

            ProgressView(value: min(1, max(0, snapshot.battery.level / 100)))
                .progressViewStyle(.linear)

            HStack {
                Text("Cycles: \(snapshot.battery.cycleCount)")
                    .font(.caption)
                Spacer()
                Text("Health: \(snapshot.battery.health)")
                    .font(.caption)
            }
        }
    }

    // MARK: - DeepSeek

    private var deepseekSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("🤖 DeepSeek")
                Spacer()
                if snapshot.deepseek.isAvailable && snapshot.deepseek.totalBalance > 0 {
                    Text("¥\(snapshot.deepseek.formattedBalance)")
                        .monospacedDigit()
                } else {
                    Text("N/A")
                        .font(.caption)
                }
                Button {
                    refreshing = true
                    store.refreshDeepSeek()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        refreshing = false
                    }
                } label: {
                    Image(systemName: refreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(refreshing)
                .scaleEffect(refreshing ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: refreshing)
            }
            .font(.callout)
        }
    }

    // MARK: - Uptime

    private var uptimeSection: some View {
        HStack {
            Text("⏱ Uptime")
                .font(.callout)
            Spacer()
            Text(formatter.uptimeText(snapshot.uptime))
                .font(.callout)
                .monospacedDigit()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Updated \(formatter.timeText(snapshot.capturedAt))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
