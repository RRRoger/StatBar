import AppKit
import Observation
import QuartzCore
import StatBarCore
import SwiftUI

private func loadAvatar(customPath: String? = nil) -> NSImage? {
    if let customPath = customPath, !customPath.isEmpty,
       let image = NSImage(contentsOfFile: customPath) {
        return image
    }
    guard let path = Bundle.main.path(forResource: "avatar", ofType: "jpeg") else { return nil }
    return NSImage(contentsOfFile: path)
}

// MARK: - Dynamic Island Panel Helper

private enum IslandLayout {
    static let compactSize = NSSize(width: 320, height: 42)
    static let expandedSize = NSSize(width: 420, height: 750)
    static let topInset: CGFloat = 8
}

@MainActor
private func makeIslandPanel() -> NSPanel {
    let panel = NSPanel(
        contentRect: NSRect(origin: .zero, size: IslandLayout.compactSize),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .statusBar
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    panel.isMovableByWindowBackground = false
    return panel
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var settings: StatBarSettings
    let store: MetricsStore
    private let formatter = StatBarFormatter()
    private var islandPanel: NSPanel?
    private var islandController: NSHostingController<IslandRootView>?
    private var isIslandExpanded = false
    private var mouseMonitor: Any?
    private var settingsWindowController: NSWindowController?

    override init() {
        let s = StatBarSettings.load()
        settings = s
        store = MetricsStore(refreshInterval: s.refresh.interval)
        super.init()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupIslandPanel()
        observeStore()
        store.setDeepSeekApiKey(settings.profile.deepSeekApiKey)
        store.start()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        store.stop()
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
    }

    func onSettingsChanged() {
        settings.save()
        store.updateRefreshInterval(settings.refresh.interval)
        store.setDeepSeekApiKey(settings.profile.deepSeekApiKey)
        updateIslandPanel()
    }

    func showSettings() {
        if let wc = settingsWindowController, wc.window?.isVisible == true {
            wc.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let binding = Binding(
            get: { [weak self] in self?.settings ?? StatBarSettings() },
            set: { [weak self] in self?.settings = $0; self?.onSettingsChanged() }
        )
        let view = SettingsView(settings: binding, store: store)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "StatBar Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 560, height: 500))
        window.center()

        let wc = NSWindowController(window: window)
        wc.showWindow(nil)
        settingsWindowController = wc
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Dynamic Island

    private func setupIslandPanel() {
        let panel = makeIslandPanel()
        islandPanel = panel

        let controller = NSHostingController(rootView: makeIslandView())
        controller.view.appearance = NSAppearance(named: .darkAqua)
        islandController = controller
        panel.contentViewController = controller

        positionIslandPanel(animated: false)
        panel.orderFront(nil)

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.collapseIsland()
            }
        }
    }

    private func makeIslandView() -> IslandRootView {
        IslandRootView(
            snapshot: store.snapshot,
            store: store,
            formatter: formatter,
            settings: Binding(
                get: { [weak self] in self?.settings ?? StatBarSettings() },
                set: { [weak self] in
                    self?.settings = $0
                    self?.onSettingsChanged()
                }
            ),
            isExpanded: isIslandExpanded,
            toggleExpanded: { [weak self] in self?.toggleIsland() },
            collapse: { [weak self] in self?.collapseIsland() },
            showSettings: { [weak self] in self?.showSettings() }
        )
    }

    private func updateIslandPanel() {
        islandController?.rootView = makeIslandView()
    }

    private var targetIslandSize: NSSize {
        isIslandExpanded ? IslandLayout.expandedSize : IslandLayout.compactSize
    }

    private func toggleIsland() {
        isIslandExpanded.toggle()
        updateIslandPanel()
        positionIslandPanel(animated: true)
    }

    private func collapseIsland() {
        guard isIslandExpanded else { return }
        isIslandExpanded = false
        updateIslandPanel()
        positionIslandPanel(animated: true)
    }

    private func positionIslandPanel(animated: Bool) {
        guard let panel = islandPanel else { return }
        // Use the screen under the mouse cursor, fallback to main, then first
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
                ?? NSScreen.main
                ?? NSScreen.screens.first else { return }

        let size = targetIslandSize
        let sf = screen.frame
        let frame = NSRect(
            x: sf.origin.x + (sf.width - size.width) / 2,
            y: sf.maxY - size.height - IslandLayout.topInset,
            width: size.width,
            height: size.height
        )

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    // MARK: - Store Observation

    private func observeStore() {
        withObservationTracking {
            let _ = store.snapshot
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateIslandPanel()
                self?.observeStore()
            }
        }
    }
}

// MARK: - SwiftUI App

@main
struct StatBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - Island Root

private struct IslandRootView: View {
    let snapshot: SystemSnapshot
    let store: MetricsStore
    let formatter: StatBarFormatter
    @Binding var settings: StatBarSettings
    let isExpanded: Bool
    var toggleExpanded: () -> Void
    var collapse: () -> Void
    var showSettings: () -> Void
    @State private var deepseekRefreshing = false

    var body: some View {
        Group {
            if isExpanded {
                expandedIsland
            } else {
                compactIsland
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isExpanded)
    }

    private var compactIsland: some View {
        Button(action: toggleExpanded) {
            HStack(spacing: 10) {
                if let avatar = loadAvatar(customPath: settings.profile.avatarPath) {
                    Image(nsImage: avatar)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(isHot ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                }
                Text(formatter.islandSummaryTitle(for: snapshot, config: settings.menuBar))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                if snapshot.video.isPlaying {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(width: IslandLayout.compactSize.width, height: IslandLayout.compactSize.height)
            .background(.black.opacity(0.92))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var expandedIsland: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isHot ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                Text(formatter.islandSummaryTitle(for: snapshot, config: settings.menuBar))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Button(action: showSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                Button(action: collapse) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 2)

            ScrollView {
                MenuBarContentView(
                snapshot: snapshot,
                formatter: formatter,
                store: store,
                refreshing: $deepseekRefreshing,
                settings: $settings,
                showSettings: showSettings
            )
            .foregroundStyle(.white)
            }
        }
        .frame(width: IslandLayout.expandedSize.width, height: IslandLayout.expandedSize.height)
        .background(.black.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var isHot: Bool {
        snapshot.cpu.usage > settings.alerts.cpuHighUsagePercent ||
            snapshot.memory.usage > settings.alerts.memoryHighUsagePercent
    }
}

// MARK: - Menu Bar Content

private struct MenuBarContentView: View {
    let snapshot: SystemSnapshot
    let formatter: StatBarFormatter
    let store: MetricsStore
    @Binding var refreshing: Bool
    @Binding var settings: StatBarSettings
    var showSettings: () -> Void

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

            if snapshot.video.isPlaying {
                Divider()
                nowPlayingSection
            }

            Divider()

            deepseekSection

            Divider()

            uptimeSection

            Divider()

            footer
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
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
            if let avatar = loadAvatar(customPath: settings.profile.avatarPath) {
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

    // MARK: - Now Playing

    private var nowPlayingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.callout)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.video.appName)
                        .font(.callout)
                        .lineLimit(1)
                    if !snapshot.video.windowTitle.isEmpty {
                        Text(snapshot.video.windowTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
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
            Link("🔗 deepseek.com", destination: URL(string: "https://platform.deepseek.com")!)
                .font(.caption)
                .foregroundStyle(.blue)
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
    var store: MetricsStore

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
                HStack {
                    Text("Avatar Path")
                    Spacer()
                    TextField("e.g. ~/Pictures/avatar.jpeg", text: $settings.profile.avatarPath)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 260)
                    Button("Browse...") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.jpeg, .png]
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        if panel.runModal() == .OK, let url = panel.url {
                            settings.profile.avatarPath = url.path
                        }
                    }
                }
            }

            Section("DeepSeek") {
                HStack {
                    Text("API Key")
                    Spacer()
                    SecureField("sk-...", text: $settings.profile.deepSeekApiKey)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 260)
                }
                HStack {
                    Spacer()
                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                    }
                    Button("Test Connection") {
                        testDeepSeekConnection()
                    }
                    .disabled(settings.profile.deepSeekApiKey.isEmpty || testing)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 560)
    }

    @State private var testResult: String?
    @State private var testing = false

    private func testDeepSeekConnection() {
        testing = true
        testResult = nil
        let key = settings.profile.deepSeekApiKey
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/user/balance")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                testing = false
                if let error = error {
                    testResult = "❌ \(error.localizedDescription)"
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    testResult = "❌ No response"
                    return
                }
                if httpResponse.statusCode == 200 {
                    testResult = "✅ Connection successful"
                } else {
                    testResult = "❌ HTTP \(httpResponse.statusCode)"
                }
            }
        }.resume()
    }

    private func menuBarRow(icon: String, label: String, config: Binding<MenuBarItemConfig>) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: config.visible) {
                HStack(spacing: 4) {
                    Text(icon)
                    Text(label)
                }
            }
            .toggleStyle(.switch)
            .frame(width: 140, alignment: .leading)

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
