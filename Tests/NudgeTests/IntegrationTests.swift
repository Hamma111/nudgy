import XCTest
@testable import Nudgy

/// Integration tests verifying cross-component interactions.
final class IntegrationTests: XCTestCase {

    private var appState: AppState!
    private var sessionManager: SessionManager!

    @MainActor
    override func setUp() {
        super.setUp()
        appState = AppState()
        sessionManager = SessionManager(appState: appState)
    }

    // MARK: - Session → AppState Integration

    func testStopEventUpdatesAppState() async throws {
        await sendEvent(name: "SessionStart", sessionId: "int-1", cwd: "/project")
        await sendEvent(name: "Stop", sessionId: "int-1")

        let session = await sessionManager.session(for: "int-1")
        XCTAssertEqual(session?.state, .idle)

        await MainActor.run {
            XCTAssertEqual(appState.sessions.count, 1)
            XCTAssertEqual(appState.sessions.first?.state, .idle)
        }
    }

    func testPermissionEventUpdatesAppState() async throws {
        await sendEvent(name: "SessionStart", sessionId: "int-2")
        await sendEvent(name: "Notification", sessionId: "int-2", detail: "permission_prompt")

        await MainActor.run {
            XCTAssertEqual(appState.highestPriorityState, .waitingPermission)
            XCTAssertEqual(appState.pendingPermissionCount, 1)
            XCTAssertEqual(appState.statusIcon, "exclamationmark.bubble.fill")
        }
    }

    func testMultipleSessionsDifferentStates() async throws {
        await sendEvent(name: "SessionStart", sessionId: "ms-A", cwd: "/project-a")
        await sendEvent(name: "SessionStart", sessionId: "ms-B", cwd: "/project-b")
        await sendEvent(name: "Stop", sessionId: "ms-A")
        await sendEvent(name: "Notification", sessionId: "ms-B", detail: "permission_prompt")

        await MainActor.run {
            XCTAssertEqual(appState.activeSessionCount, 2)
            XCTAssertEqual(appState.highestPriorityState, .waitingPermission)
        }

        let a = await sessionManager.session(for: "ms-A")
        let b = await sessionManager.session(for: "ms-B")
        XCTAssertEqual(a?.state, .idle)
        XCTAssertEqual(b?.state, .waitingPermission)
    }

    // MARK: - Full Session Lifecycle

    func testFullSessionLifecycle() async throws {
        // Start
        await sendEvent(name: "SessionStart", sessionId: "life-1", cwd: "/project")
        var session = await sessionManager.session(for: "life-1")
        XCTAssertEqual(session?.state, .active)
        XCTAssertEqual(session?.projectName, "project")

        // Permission request
        await sendEvent(name: "Notification", sessionId: "life-1", detail: "permission_prompt")
        session = await sessionManager.session(for: "life-1")
        XCTAssertEqual(session?.state, .waitingPermission)
        XCTAssertEqual(session?.pendingPermissions.count, 1)

        // Resume work
        await sendEvent(name: "Stop", sessionId: "life-1")
        session = await sessionManager.session(for: "life-1")
        XCTAssertEqual(session?.state, .idle)

        // End
        await sendEvent(name: "SessionEnd", sessionId: "life-1")
        session = await sessionManager.session(for: "life-1")
        XCTAssertEqual(session?.state, .stopped)

        await MainActor.run {
            XCTAssertEqual(appState.activeSessionCount, 0)
        }
    }

    // MARK: - Suppression Integration

    func testSuppressionIntegration() async throws {
        let focuser = WindowFocuser()
        let suppressor = SmartSuppressor(windowFocuser: focuser)

        await sendEvent(name: "SessionStart", sessionId: "sup-1")
        await sendEvent(name: "Notification", sessionId: "sup-1", detail: "permission_prompt")

        let session = await sessionManager.session(for: "sup-1")!
        let event = HookEvent(hookEventName: "Notification", sessionId: "sup-1", notificationType: "permission_prompt")

        // Permission is NEVER suppressed
        let decision = suppressor.evaluate(event: event, session: session)
        XCTAssertEqual(decision, .show)
    }

    func testNotificationCreation() async throws {
        await sendEvent(name: "SessionStart", sessionId: "notif-1", cwd: "/my-app")
        await sendEvent(name: "Stop", sessionId: "notif-1")

        let session = await sessionManager.session(for: "notif-1")!
        let event = HookEvent(hookEventName: "Stop", sessionId: "notif-1")

        // Build notification like AppDelegate does
        let item = NotificationItem(
            sessionId: session.id,
            projectName: session.projectName,
            title: "Task Complete",
            message: "Claude finished working on \(session.displayName)",
            style: .success
        )

        await MainActor.run {
            appState.addNotification(item)
            XCTAssertEqual(appState.notifications.count, 1)
            XCTAssertEqual(appState.notifications.first?.style, .success)
            XCTAssertEqual(appState.notifications.first?.projectName, "my-app")
        }
    }

    // MARK: - Concurrent Sessions

    func testConcurrentSessionProcessing() async throws {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    await self.sendEvent(name: "SessionStart", sessionId: "c-\(i)", cwd: "/p-\(i)")
                }
            }
        }

        let sessions = await sessionManager.allSessions()
        XCTAssertEqual(sessions.count, 20)

        await MainActor.run {
            XCTAssertEqual(appState.sessions.count, 20)
            XCTAssertEqual(appState.activeSessionCount, 20)
        }
    }

    // MARK: - Event Stats

    func testEventStatsAccumulate() async throws {
        await sendEvent(name: "SessionStart", sessionId: "stats-1")
        await sendEvent(name: "Stop", sessionId: "stats-1")
        await sendEvent(name: "Notification", sessionId: "stats-1", detail: "permission_prompt")
        await sendEvent(name: "StopFailure", sessionId: "stats-1", detail: "rate_limit")

        let session = await sessionManager.session(for: "stats-1")!
        XCTAssertEqual(session.stats.eventCount, 4)
        XCTAssertEqual(session.stats.permissionCount, 1)
        XCTAssertEqual(session.stats.errorCount, 1)
    }

    // MARK: - Hook Installer Integration

    func testHookInstallAndVerify() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nudgy-int-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let installer = HookInstaller(port: 9847, settingsDir: tempDir)
        try installer.install()
        XCTAssertTrue(installer.isInstalled())
        XCTAssertTrue(installer.verify())
    }

    func testHookInstallUninstallRoundTrip() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nudgy-int-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let settingsPath = tempDir.appendingPathComponent("settings.json")
        let existing = """
        {
            "hooks": {
                "PreToolUse": [
                    {"hooks": [{"type": "command", "command": "echo hi"}]}
                ]
            },
            "permissions": {"allow": ["Read"]}
        }
        """
        try existing.write(to: settingsPath, atomically: true, encoding: .utf8)

        let installer = HookInstaller(port: 9847, settingsDir: tempDir)

        try installer.install()
        var settings = try JSONSerialization.jsonObject(with: Data(contentsOf: settingsPath)) as! [String: Any]
        var hooks = settings["hooks"] as! [String: Any]
        XCTAssertNotNil(hooks["PreToolUse"], "User's own PreToolUse command hook should be preserved")
        XCTAssertNotNil(hooks["Stop"])
        XCTAssertNotNil(settings["permissions"])

        try installer.uninstall()
        settings = try JSONSerialization.jsonObject(with: Data(contentsOf: settingsPath)) as! [String: Any]
        hooks = settings["hooks"] as! [String: Any]
        XCTAssertNotNil(hooks["PreToolUse"], "User's own PreToolUse hook should survive uninstall")
        XCTAssertNil(hooks["Stop"])
    }

    // MARK: - Helpers

    /// Builds an event the way Claude Code actually sends it. The discriminator
    /// field is named differently per event type, and `matcher` is never present
    /// in hook input at all — it is a settings-side filter only.
    private func sendEvent(name: String, sessionId: String, cwd: String? = nil, detail: String? = nil) async {
        let event = HookEvent(
            hookEventName: name,
            sessionId: sessionId,
            cwd: cwd,
            notificationType: name == "Notification" ? detail : nil,
            error: name == "StopFailure" ? detail : nil,
            source: name == "SessionStart" ? detail : nil,
            reason: name == "SessionEnd" ? detail : nil
        )
        await sessionManager.handleEvent(event)
    }
}
