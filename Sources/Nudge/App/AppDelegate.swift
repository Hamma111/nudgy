import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var httpServer: HTTPServer!
    private var sessionManager: SessionManager!
    private var appState: AppState!
    private var menuBarManager: MenuBarManager!
    private var popupController: PopupWindowController!
    private var soundManager: SoundManager!
    private var windowFocuser: WindowFocuser!
    private var smartSuppressor: SmartSuppressor!
    private var hookInstaller: HookInstaller!
    private var usageQuotaManager: UsageQuotaManager!
    private var settingsWindow: NSWindow?
    private var settingsObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppState()
        windowFocuser = WindowFocuser()
        soundManager = SoundManager.shared
        smartSuppressor = SmartSuppressor(windowFocuser: windowFocuser)
        // Disable terminal-focused suppression — users WANT notifs even when in terminal
        smartSuppressor.suppressWhenTerminalFocused = false

        sessionManager = SessionManager(appState: appState)
        Task { await sessionManager.startCleanupTimer() }

        popupController = PopupWindowController()
        popupController.onDismiss = { [weak self] id in
            Task { @MainActor in
                self?.appState.removeNotification(id: id)
                self?.smartSuppressor.recordInteraction()
            }
        }

        usageQuotaManager = UsageQuotaManager()
        if usageQuotaManager.isConfigured {
            usageQuotaManager.startAutoRefresh()
        }

        menuBarManager = MenuBarManager(appState: appState, quotaManager: usageQuotaManager)

        // Generate or load auth token for HTTP server authentication
        let authToken = Self.loadOrGenerateAuthToken()

        httpServer = HTTPServer(port: appState.port)
        httpServer.sharedSecret = authToken
        httpServer.delegate = self

        do {
            try httpServer.start()
            Task { @MainActor in
                appState.isServerRunning = true
                appState.port = httpServer.actualPort
            }
        } catch {
            NudgyLogger.shared.log("Failed to start HTTP server: \(error)")
        }

        // Install/update hooks unless user explicitly disabled them
        hookInstaller = HookInstaller(port: httpServer.actualPort, token: authToken)
        if !UserDefaults.standard.bool(forKey: "hooksDisabled") {
            do {
                try hookInstaller.install()
                NudgyLogger.shared.log("Hooks installed successfully")
            } catch {
                NudgyLogger.shared.log("Failed to install hooks: \(error)")
            }
        }

        // Listen for settings window requests
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .openSettings, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openSettings()
            }
        }
    }

    @MainActor
    private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(appState: appState) { [weak self] item in
            guard let self else { return }
            self.popupController.show(item)
            self.soundManager.playForStyle(item.style)
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Nudgy Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - Auth Token

    private static let authKeychainService = "com.nudgy.auth"
    private static let authKeychainAccount = "hookToken"

    /// Load the auth token from Keychain, or generate and store a new one.
    static func loadOrGenerateAuthToken() -> String {
        if let existing = KeychainHelper.load(service: authKeychainService, account: authKeychainAccount),
           !existing.isEmpty {
            return existing
        }
        let token = UUID().uuidString
        _ = KeychainHelper.save(service: authKeychainService, account: authKeychainAccount, value: token)
        return token
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuBarManager.openPopover()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        httpServer?.stop()
        if !UserDefaults.standard.bool(forKey: "hooksDisabled") {
            try? hookInstaller?.uninstall()
        }
        Task { await sessionManager.stopCleanupTimer() }
    }

    // MARK: - Notification Pipeline

    @MainActor
    private func processNotification(event: HookEvent, session: AgentSession) {
        let decision = smartSuppressor.evaluate(event: event, session: session)
        smartSuppressor.recordEvent(event)

        switch decision {
        case .show, .escalate:
            let item = createNotificationItem(event: event, session: session, escalated: decision == .escalate)
            guard item.style.isEnabled else {
                NudgyLogger.shared.log("Notification disabled for style: \(item.style.rawValue)")
                menuBarManager.updateIcon()
                return
            }
            appState.addNotification(item)
            popupController.show(item)
            soundManager.playForStyle(item.style)
            menuBarManager.updateIcon()

        case .suppress(let reason):
            NudgyLogger.shared.log("Suppressed: \(reason)")

        case .batch(let groupId):
            NudgyLogger.shared.log("Batched for session \(groupId)")
        }
    }

    private func createNotificationItem(event: HookEvent, session: AgentSession, escalated: Bool) -> NotificationItem {
        let style: NotificationStyle
        var title: String
        var message: String
        var autoDismiss: TimeInterval? = 5.0

        switch session.state {
        case .idle:
            style = .success
            title = "Done"
            message = session.displayName
        case .waitingPermission:
            style = .warning
            title = escalated ? "Still waiting" : "Permission"
            if let tool = event.toolName {
                let cmd = event.toolInput?["command"]?.value as? String
                message = cmd.map { "\(tool): \($0.prefix(50))" } ?? tool
            } else {
                message = "Needs your approval"
            }
            autoDismiss = nil
        case .waitingInput:
            style = .question
            title = "Question"
            message = "Waiting for your input"
            autoDismiss = nil
        case .error:
            style = .error
            title = "Error"
            message = event.matcher ?? "Something went wrong"
        case .active:
            style = .info
            title = "Working"
            message = session.displayName
        default:
            style = .info
            title = event.hookEventName
            message = ""
        }

        // Prefer Claude Code's own message/title if present
        if let eventTitle = event.title, !eventTitle.isEmpty {
            title = eventTitle
        }
        if let eventMessage = event.message, !eventMessage.isEmpty {
            message = eventMessage
        }

        return NotificationItem(
            sessionId: session.id,
            projectName: session.projectName,
            title: title,
            message: message,
            style: style,
            autoDismissAfter: autoDismiss
        )
    }
}

extension AppDelegate: HTTPServerDelegate {
    func httpServer(_ server: HTTPServer, didReceive event: HookEvent) {
        NudgyLogger.shared.event(
            event.hookEventName,
            sessionId: event.sessionId,
            matcher: event.matcher,
            tool: event.toolName,
            cwd: event.cwd
        )

        Task {
            // Capture the session state before processing the event
            let previousState = await sessionManager.session(for: event.sessionId ?? "unknown")?.state

            await sessionManager.handleEvent(event)

            if let session = await sessionManager.session(for: event.sessionId ?? "unknown") {
                // Dismiss stale notifications when session leaves a waiting state
                let wasWaiting = previousState == .waitingPermission || previousState == .waitingInput
                let isNoLongerWaiting = session.state != .waitingPermission && session.state != .waitingInput
                if wasWaiting && isNoLongerWaiting {
                    await MainActor.run {
                        popupController.dismissForSession(session.id)
                    }
                }

                let shouldNotify: Bool
                switch event.hookEventName {
                case "Stop", "StopFailure", "Notification", "PermissionRequest", "SessionStart":
                    shouldNotify = true
                default:
                    shouldNotify = false
                }

                if shouldNotify {
                    await MainActor.run {
                        processNotification(event: event, session: session)
                    }
                } else {
                    // Still update menubar icon for state changes
                    await MainActor.run {
                        menuBarManager.updateIcon()
                    }
                }
            }
        }
    }

    func httpServer(_ server: HTTPServer, didEncounterError error: Error) {
        NudgyLogger.shared.log("HTTP server error: \(error)")
    }
}
