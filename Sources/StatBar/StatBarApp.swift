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
        isIslandExpanded = false
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
                SystemMoodView(mood: snapshot.mood)
                    .allowsHitTesting(false)
                ThreeBodyView(size: 30)
                    .allowsHitTesting(false)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(width: IslandLayout.compactSize.width, height: IslandLayout.compactSize.height)
            .background(
                ZStack {
                    Color.black.opacity(0.92)
                    if isHot {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.red.opacity(0.15), .clear, .red.opacity(0.08)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .blur(radius: 8)
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isHot ? Color.red.opacity(0.2) : Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func networkPulse(rate: UInt64, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: rate > 0 ? 5 : 3, height: rate > 0 ? 5 : 3)
            .opacity(rate > 0 ? 0.9 : 0.3)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: rate > 0)
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

            AnimatedProgressBar(value: snapshot.cpu.usage / 100,
                                gradient: snapshot.cpu.usage > 90 ? Gradient(colors: [.red, .orange]) : Gradient(colors: [.green, .cyan]))
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

            AnimatedProgressBar(value: snapshot.memory.usage / 100,
                                gradient: snapshot.memory.usage > 90 ? Gradient(colors: [.red, .orange]) : Gradient(colors: [.purple, .pink]))

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

            HStack(spacing: 6) {
                NetworkActivityDot(rate: snapshot.network.downBytesPerSec, color: .cyan)
                Text("↓ \(formatter.networkRateText(snapshot.network.downBytesPerSec))")
                    .font(.caption)
                Spacer()
                Text("↑ \(formatter.networkRateText(snapshot.network.upBytesPerSec))")
                    .font(.caption)
                NetworkActivityDot(rate: snapshot.network.upBytesPerSec, color: .orange)
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

            AnimatedProgressBar(value: snapshot.disk.usage / 100,
                                gradient: snapshot.disk.usage > 90 ? Gradient(colors: [.red, .orange]) : Gradient(colors: [.blue, .cyan]))

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

            ForEach(Array(snapshot.topProcesses.enumerated()), id: \.offset) { _, process in
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
                thresholdField("CPU", value: $settings.alerts.cpuHighUsagePercent, suffix: "%")
                thresholdField("Memory", value: $settings.alerts.memoryHighUsagePercent, suffix: "%")
                thresholdField("Disk", value: $settings.alerts.diskHighUsagePercent, suffix: "%")
                thresholdField("DeepSeek", value: $settings.alerts.deepSeekLowBalance, suffix: "¥")
            }

            Section("Profile") {
                TextField("Display Name", text: $settings.profile.displayName)
                TextField("Subtitle", text: $settings.profile.subtitle)
                HStack {
                    Text("Avatar Path")
                    Spacer()
                    if settings.profile.avatarPath.isEmpty {
                        Text("e.g. ~/Pictures/avatar.jpeg")
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                    }
                    TextField("", text: $settings.profile.avatarPath)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 200)
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
                    if settings.profile.deepSeekApiKey.isEmpty {
                        Text("sk-...")
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                    }
                    SecureField("", text: $settings.profile.deepSeekApiKey)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 200)
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
            .frame(width: 120, alignment: .leading)

            Picker("", selection: config.style) {
                ForEach(MenuBarItemStyle.allCases, id: \.self) { style in
                    Text(styleName(style)).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(!config.visible.wrappedValue)
            .opacity(config.visible.wrappedValue ? 1.0 : 0.4)
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
                .layoutPriority(1)
            Spacer()
            TextField("", value: value, format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .fixedSize()
            Text(suffix)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }
}

// MARK: - Animated Progress Bar

private struct AnimatedProgressBar: View {
    let value: Double
    let gradient: Gradient
    @State private var shimmerPhase: CGFloat = 0

    private var clamped: CGFloat { CGFloat(min(1, max(0, value))) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(.white.opacity(0.08))

                // Fill with gradient + shimmer
                Capsule()
                    .fill(
                        LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * clamped)
                    .overlay(
                        GeometryReader { fillGeo in
                            if fillGeo.size.width > 0 {
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.3), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: fillGeo.size.width * 0.4)
                                .offset(x: shimmerPhase * fillGeo.size.width * 1.4 - fillGeo.size.width * 0.2)
                                .blendMode(.overlay)
                            }
                        }
                        .clipped()
                    )
                    .animation(.easeInOut(duration: 0.5), value: clamped)
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }
}

// MARK: - Three-Body Simulation

private struct ThreeBodyState: Equatable {
    struct Body: Equatable {
        var x: Double
        var y: Double
        var vx: Double
        var vy: Double
        let mass: Double
        let color: Color
    }
    var bodies: [Body]
}

private class ThreeBodySimulator: ObservableObject, @unchecked Sendable {
    @Published var state: ThreeBodyState
    private var timer: Timer?

    // Classic figure-eight initial conditions (scaled)
    private static let initialBodies: [ThreeBodyState.Body] = [
        ThreeBodyState.Body(x: -0.97, y: 0.2434, vx: 0.4662, vy: 0.4324, mass: 1.0, color: .cyan),
        ThreeBodyState.Body(x: 0.97, y: -0.2434, vx: 0.4662, vy: 0.4324, mass: 1.0, color: .orange),
        ThreeBodyState.Body(x: 0, y: 0, vx: -0.9324, vy: -0.8648, mass: 1.0, color: .pink),
    ]

    init() {
        self.state = ThreeBodyState(bodies: Self.initialBodies)
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.step()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func step() {
        let dt = 0.015
        let G = 1.0
        let dampening = 0.9999
        var b = state.bodies

        // Compute gravitational accelerations
        var ax = [Double](repeating: 0, count: 3)
        var ay = [Double](repeating: 0, count: 3)

        for i in 0..<3 {
            for j in 0..<3 where j != i {
                let dx = b[j].x - b[i].x
                let dy = b[j].y - b[i].y
                let distSq = dx * dx + dy * dy + 0.01 // softening
                let dist = sqrt(distSq)
                let force = G * b[j].mass / distSq
                ax[i] += force * dx / dist
                ay[i] += force * dy / dist
            }
        }

        // Velocity Verlet integration
        for i in 0..<3 {
            b[i].vx = (b[i].vx + ax[i] * dt) * dampening
            b[i].vy = (b[i].vy + ay[i] * dt) * dampening
            b[i].x += b[i].vx * dt
            b[i].y += b[i].vy * dt

            // Soft boundary - bounce back if too far
            let limit = 2.0
            if b[i].x > limit { b[i].x = limit; b[i].vx *= -0.5 }
            if b[i].x < -limit { b[i].x = -limit; b[i].vx *= -0.5 }
            if b[i].y > limit { b[i].y = limit; b[i].vy *= -0.5 }
            if b[i].y < -limit { b[i].y = -limit; b[i].vy *= -0.5 }
        }

        state = ThreeBodyState(bodies: b)
    }
}

private struct ThreeBodyView: View {
    @StateObject private var sim = ThreeBodySimulator()
    let size: CGFloat

    var body: some View {
        Canvas { ctx, canvasSize in
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2
            let scale = min(canvasSize.width, canvasSize.height) / 5.5

            // Draw faint trails (using previous positions is expensive, so draw orbital hint)
            for body in sim.state.bodies {
                let px = cx + CGFloat(body.x) * scale
                let py = cy - CGFloat(body.y) * scale
                let dotSize: CGFloat = size > 20 ? 5 : 4

                // Glow
                ctx.drawLayer { layerCtx in
                    layerCtx.addFilter(.blur(radius: 3))
                    layerCtx.draw(
                        layerCtx.resolveSymbol(id: 0)!,
                        at: CGPoint(x: px, y: py)
                    )
                }

                // Core dot
                let rect = CGRect(x: px - dotSize/2, y: py - dotSize/2, width: dotSize, height: dotSize)
                ctx.fill(Circle().path(in: rect), with: .color(body.color.opacity(0.9)))
            }
        } symbols: {
            // Glow symbols
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(sim.state.bodies[i].color.opacity(0.4))
                    .frame(width: size > 20 ? 10 : 8, height: size > 20 ? 10 : 8)
            }
        }
        .frame(width: size, height: size)
        .onAppear { sim.start() }
        .onDisappear { sim.stop() }
    }
}

// MARK: - Network Activity Dot

private struct NetworkActivityDot: View {
    let rate: UInt64
    let color: Color
    @State private var pulsing = false

    private var active: Bool { rate > 0 }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: active ? 6 : 4, height: active ? 6 : 4)
            .opacity(active ? (pulsing ? 1.0 : 0.5) : 0.2)
            .scaleEffect(active ? (pulsing ? 1.2 : 0.8) : 1.0)
            .animation(
                active
                    ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                    : .default,
                value: pulsing
            )
            .animation(.easeInOut(duration: 0.3), value: active)
            .onChange(of: active) { _, newValue in
                pulsing = newValue
            }
    }
}

// MARK: - System Mood Face

private struct SystemMoodView: View {
    let mood: SystemMood
    @State private var blinkPhase = false
    @State private var breathScale: CGFloat = 1.0

    var body: some View {
        Text(mood.emoji)
            .font(.system(size: 16))
            .scaleEffect(breathScale)
            .overlay(blinkOverlay)
            .onChange(of: mood) { _, _ in
                // Reset animation on mood change
            }
            .onAppear {
                startBreathing()
            }
    }

    @ViewBuilder
    private var blinkOverlay: some View {
        if mood == .idle || mood == .relaxed {
            // Subtle eye-close animation via opacity pulse
            Rectangle()
                .fill(.black.opacity(blinkPhase ? 0.15 : 0))
                .frame(width: 12, height: 4)
                .offset(y: -1)
                .blendMode(.destinationOut)
                .animation(
                    .easeInOut(duration: 0.15)
                    .repeatCount(2, autoreverses: true)
                    .delay(3.0),
                    value: blinkPhase
                )
        }
    }

    private func startBreathing() {
        withAnimation(
            .easeInOut(duration: mood == .onFire ? 0.4 : 1.8)
            .repeatForever(autoreverses: true)
        ) {
            breathScale = mood == .onFire ? 1.15 : 1.06
        }
        // Blink timer
        Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            DispatchQueue.main.async {
                blinkPhase.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    blinkPhase.toggle()
                }
            }
        }
    }
}
