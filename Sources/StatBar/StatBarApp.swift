import AppKit
import StatBarCore
import SwiftUI

@main
struct StatBarApp: App {
    @State private var store = MetricsStore()
    private let formatter = StatBarFormatter()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(snapshot: store.snapshot, formatter: formatter)
        } label: {
            Text(formatter.menuTitle(for: store.snapshot))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            MetricRow(
                title: "CPU",
                value: formatter.percentText(snapshot.cpu.usage),
                progress: snapshot.cpu.usage / 100
            )

            MetricRow(
                title: "Memory",
                value: formatter.percentText(snapshot.memory.usage),
                progress: snapshot.memory.usage / 100
            )

            HStack {
                Text("Used")
                Spacer()
                Text(formatter.bytesText(snapshot.memory.usedBytes))
                    .monospacedDigit()
            }
            .font(.callout)

            HStack {
                Text("Total")
                Spacer()
                Text(formatter.bytesText(snapshot.memory.totalBytes))
                    .monospacedDigit()
            }
            .font(.callout)

            Divider()

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
        .padding(16)
        .frame(width: 280)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("StatBar")
                .font(.headline)
            Text("System monitor")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MetricRow: View {
    let title: String
    let value: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .fontDesign(.monospaced)
                    .monospacedDigit()
            }

            ProgressView(value: min(1, max(0, progress)))
                .progressViewStyle(.linear)
        }
        .font(.callout)
    }
}
