import AppKit
import StatBarCore
import SwiftUI

private func loadAvatar() -> NSImage? {
    guard let path = Bundle.main.path(forResource: "avatar", ofType: "jpeg") else { return nil }
    return NSImage(contentsOfFile: path)
}

@main
struct StatBarApp: App {
    @State private var store: MetricsStore
    @State private var deepseekRefreshing = false
    @State private var settings: StatBarSettings
    private let formatter = StatBarFormatter()

    init() {
        let loadedSettings = StatBarSettings.load()
        _settings = State(initialValue: loadedSettings)
        _store = State(initialValue: MetricsStore(refreshInterval: loadedSettings.refresh.interval))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                snapshot: store.snapshot,
                formatter: formatter,
                store: store,
                refreshing: $deepseekRefreshing,
                settings: $settings
            )
        } label: {
            let title = formatter.menuTitle(for: store.snapshot, config: settings.menuBar)
            let isHot = store.snapshot.cpu.usage > settings.alerts.cpuHighUsagePercent ||
                store.snapshot.memory.usage > settings.alerts.memoryHighUsagePercent
            Text(title)
                .foregroundStyle(isHot ? .red : .primary)
                .task {
                    store.start()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: $settings)
                .onChange(of: settings) {
                    settings.save()
                    store.updateRefreshInterval(settings.refresh.interval)
                }
        }
    }
}

private struct MenuBarContentView: View {
    let snapshot: SystemSnapshot
    let formatter: StatBarFormatter
    let store: MetricsStore
    @Binding var refreshing: Bool
    @Binding var settings: StatBarSettings
    @Environment(\.openSettings) private var openSettings

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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "早上好"
        case 12..<14: return "中午好"
        case 14..<18: return "下午好"
        case 18..<24: return "晚上好"
        default: return "夜深了"
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let avatar = loadAvatar() {
                Image(nsImage: avatar)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.secondary.opacity(0.2), lineWidth: 1))
            } else {
                Circle()
                    .fill(.secondary.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay(Text("陈").font(.title2).foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(greeting)，\(settings.profile.displayName)")
                    .font(.headline)
                Text(settings.profile.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
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

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "v\(short) (\(build))"
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                    Button("github.com/RRRoger/StatBar") {
                        if let url = URL(string: "https://github.com/RRRoger/StatBar") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 10))
                }
                Text("Updated \(formatter.timeText(snapshot.capturedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(versionString)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.callout)
            }
            .buttonStyle(.plain)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

// MARK: - Settings Window

private struct SettingsView: View {
    @Binding var settings: StatBarSettings

    var body: some View {
        Form {
            Section("Menu Bar") {
                menuBarRow(icon: "🔥", label: "CPU", config: $settings.menuBar.cpu)
                menuBarRow(icon: "💾", label: "Memory", config: $settings.menuBar.memory)
                menuBarRow(icon: "🌐", label: "Network", config: $settings.menuBar.network)
                menuBarRow(icon: "💿", label: "Disk", config: $settings.menuBar.disk)

                Button("Reset Menu Bar") {
                    settings.menuBar = MenuBarConfig()
                }
            }

            Section("Refresh") {
                Picker("Refresh Mode", selection: $settings.refresh.mode) {
                    Text("Low Power (5s)").tag(RefreshMode.lowPower)
                    Text("Standard (2s)").tag(RefreshMode.standard)
                    Text("High Frequency (1s)").tag(RefreshMode.highFrequency)
                }
                .pickerStyle(.segmented)
            }

            Section("Alerts") {
                thresholdField("CPU High Usage", value: $settings.alerts.cpuHighUsagePercent, suffix: "%")
                thresholdField("Memory High Usage", value: $settings.alerts.memoryHighUsagePercent, suffix: "%")
                thresholdField("Disk High Usage", value: $settings.alerts.diskHighUsagePercent, suffix: "%")
                thresholdField("DeepSeek Low Balance", value: $settings.alerts.deepSeekLowBalance, suffix: "CNY")
            }

            Section("Profile") {
                TextField("Display Name", text: $settings.profile.displayName)
                TextField("Subtitle", text: $settings.profile.subtitle)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }

    private func menuBarRow(icon: String, label: String, config: Binding<MenuBarItemConfig>) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: config.visible) {
                HStack(spacing: 4) {
                    Text(icon)
                    Text(label)
                }
            }
            .toggleStyle(.checkbox)
            .frame(width: 120, alignment: .leading)

            Picker("Style", selection: config.style) {
                ForEach(MenuBarItemStyle.allCases, id: \.self) { style in
                    Text(styleName(style)).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private func styleName(_ style: MenuBarItemStyle) -> String {
        switch style {
        case .emoji: return "🔥"
        case .label: return "CPU"
        case .number: return "23"
        }
    }

    private func thresholdField(_ title: String, value: Binding<Double>, suffix: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.trailing)
                .frame(width: 76)
            Text(suffix)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
    }
}
