import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsTab(appState: appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceTab()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            AboutTab(appState: appState)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 440)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    let appState: AppState
    @AppStorage("nudgy.port") private var port: Int = 9847
    @AppStorage("nudgy.launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("nudgy.soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("nudgy.soundVolume") private var soundVolume: Double = 0.5
    @AppStorage("nudgy.autoDismissDelay") private var autoDismiss: Double = 3.0
    @AppStorage("nudgy.notify.success") private var notifySuccess: Bool = true
    @AppStorage("nudgy.notify.warning") private var notifyWarning: Bool = true
    @AppStorage("nudgy.notify.question") private var notifyQuestion: Bool = true
    @AppStorage("nudgy.notify.error") private var notifyError: Bool = true
    @AppStorage("nudgy.notify.info") private var notifyInfo: Bool = false

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }

            Section("Notifications") {
                NotificationRow(style: .success, effect: .success, label: "Success", soundEnabled: soundEnabled, isOn: $notifySuccess)
                NotificationRow(style: .warning, effect: .warning, label: "Warning", soundEnabled: soundEnabled, isOn: $notifyWarning)
                NotificationRow(style: .question, effect: .question, label: "Question", soundEnabled: soundEnabled, isOn: $notifyQuestion)
                NotificationRow(style: .error, effect: .error, label: "Error", soundEnabled: soundEnabled, isOn: $notifyError)
                NotificationRow(style: .info, effect: .info, label: "Working", soundEnabled: soundEnabled, isOn: $notifyInfo)
            }

            Section("Sound") {
                Toggle("Play sounds", isOn: $soundEnabled)
                if soundEnabled {
                    Slider(value: $soundVolume, in: 0...1) {
                        Text("Volume")
                    }
                }
            }

            Section("Behavior") {
                Slider(value: $autoDismiss, in: 2...30, step: 1) {
                    Text("Auto-dismiss: \(Int(autoDismiss))s")
                }
            }

            Section("Advanced") {
                HStack {
                    Text("Server Port")
                    Spacer()
                    TextField("", value: $port, format: .number)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                }
                Text("Restart required after changing port")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Accessibility")
                    Spacer()
                    if AXIsProcessTrusted() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Granted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Grant Access...") {
                            openAccessibilitySettings()
                        }
                    }
                }
                Text("Required to focus terminal windows via the Go button")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Nudgy: Launch at login error: \(error)")
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Appearance Tab

struct AppearanceTab: View {
    @AppStorage("nudgy.popupPreset") private var popupPreset: String = PopupPreset.glass.rawValue
    @AppStorage("nudgy.popupPosition") private var popupPosition: String = "topRight"

    private var sampleItem: NotificationItem {
        NotificationItem(
            sessionId: "preview",
            projectName: "my-app",
            title: "Done",
            message: "Finished working",
            style: .success,
            autoDismissAfter: nil
        )
    }

    var body: some View {
        Form {
            Section("Popup Style") {
                Picker("Style", selection: $popupPreset) {
                    ForEach(PopupPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                let activePreset = PopupPreset(rawValue: popupPreset) ?? .minimal
                Text(activePreset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    PopupContentView(
                        item: sampleItem,
                        onDismiss: {},
                        onAction: { _ in },
                        preset: activePreset
                    )
                    .scaleEffect(0.9)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section("Popup Position") {
                Picker("Position", selection: $popupPosition) {
                    Text("Top Right").tag("topRight")
                    Text("Top Left").tag("topLeft")
                    Text("Bottom Right").tag("bottomRight")
                    Text("Bottom Left").tag("bottomLeft")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About Tab

struct AboutTab: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // App identity
            VStack(spacing: 6) {
                Text("Nudgy")
                    .font(.system(size: 22, weight: .bold))
                Text("v\(Bundle.main.shortVersion)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Personal note
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    Text("Built by ")
                    Link("Hammad Ali", destination: URL(string: "https://github.com/Hamma111")!)
                }
                .font(.system(size: 15, weight: .medium))
                Text("Born from the frustration of missing Claude Code prompts while multitasking. Made with care for developers who run AI agents in the background and need a gentle nudge when it's their turn.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 400)
            }
            .padding(.top, 4)

            // Privacy
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Text("Your conversations and code never leave your machine. No telemetry, no analytics, no remote logging. Everything stays local. Code is open-source, feel free to scrutinize.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 400)
            .padding(.top, 2)

            Divider()
                .padding(.horizontal, 40)

            // Status
            VStack(spacing: 4) {
                HStack(spacing: 16) {
                    Label(
                        appState.isServerRunning ? "Port \(appState.port)" : "Server stopped",
                        systemImage: appState.isServerRunning ? "antenna.radiowaves.left.and.right" : "xmark.circle"
                    )
                    .font(.system(size: 10.5))
                    .foregroundStyle(appState.isServerRunning ? Color.secondary : Color.red)

                    Label(
                        "\(appState.activeSessionCount) session\(appState.activeSessionCount == 1 ? "" : "s")",
                        systemImage: "circle.grid.2x2"
                    )
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                }
            }

            // Hooks & Logs
            HStack(spacing: 12) {
                let installer = HookInstaller(port: appState.port)

                Button("Install Hooks") {
                    try? installer.install()
                    UserDefaults.standard.set(false, forKey: "hooksDisabled")
                }
                .controlSize(.small)

                Button("Uninstall Hooks") {
                    try? installer.uninstall()
                    UserDefaults.standard.set(true, forKey: "hooksDisabled")
                }
                .controlSize(.small)

                Button("Open Log") {
                    NSWorkspace.shared.selectFile(
                        NudgyLogger.shared.logFilePath,
                        inFileViewerRootedAtPath: ""
                    )
                }
                .controlSize(.small)
            }

            Spacer()

            Button("Quit Nudgy") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.red.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let style: NotificationStyle
    let effect: SoundEffect
    let label: String
    let soundEnabled: Bool
    @Binding var isOn: Bool
    @AppStorage private var chosenSound: String

    init(style: NotificationStyle, effect: SoundEffect, label: String, soundEnabled: Bool, isOn: Binding<Bool>) {
        self.style = style
        self.effect = effect
        self.label = label
        self.soundEnabled = soundEnabled
        self._isOn = isOn
        self._chosenSound = AppStorage(wrappedValue: effect.defaultSound.rawValue, effect.defaultsKey)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: style.icon)
                .foregroundStyle(isOn ? style.color : .secondary.opacity(0.4))
                .frame(width: 16)

            Toggle(label, isOn: $isOn)

            if isOn && soundEnabled {
                Picker("", selection: $chosenSound) {
                    ForEach(SoundChoice.allCases) { sound in
                        Text(sound.rawValue).tag(sound.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 90)

                Button {
                    if let choice = SoundChoice(rawValue: chosenSound) {
                        SoundManager.shared.playSound(choice)
                    }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}
