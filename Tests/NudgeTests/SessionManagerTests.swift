import XCTest
@testable import Nudgy

final class SessionManagerTests: XCTestCase {
    private var appState: AppState!
    private var manager: SessionManager!

    @MainActor
    override func setUp() {
        super.setUp()
        appState = AppState()
        manager = SessionManager(appState: appState)
    }

    func testCreateSessionOnFirstEvent() async {
        let event = HookEvent(
            hookEventName: "SessionStart",
            sessionId: "session-1",
            cwd: "/Users/dev/myproject",
            source: "startup"
        )

        await manager.handleEvent(event)

        let session = await manager.session(for: "session-1")
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.state, .active)
        XCTAssertEqual(session?.projectName, "myproject")
    }

    func testUpdateSessionStateOnStop() async {
        await sendEvent(name: "SessionStart", sessionId: "s1")
        await sendEvent(name: "Stop", sessionId: "s1")

        let session = await manager.session(for: "s1")
        XCTAssertEqual(session?.state, .idle)
    }

    func testUpdateSessionStateOnPermission() async {
        await sendEvent(name: "SessionStart", sessionId: "s1")
        await sendEvent(name: "Notification", sessionId: "s1", detail: "permission_prompt")

        let session = await manager.session(for: "s1")
        XCTAssertEqual(session?.state, .waitingPermission)
        XCTAssertEqual(session?.pendingPermissions.count, 1)
    }

    func testUpdateSessionStateOnIdlePrompt() async {
        await sendEvent(name: "SessionStart", sessionId: "s1")
        await sendEvent(name: "Notification", sessionId: "s1", detail: "idle_prompt")

        let session = await manager.session(for: "s1")
        XCTAssertEqual(session?.state, .waitingInput)
    }

    func testUpdateSessionStateOnError() async {
        await sendEvent(name: "SessionStart", sessionId: "s1")
        await sendEvent(name: "StopFailure", sessionId: "s1", detail: "rate_limit")

        let session = await manager.session(for: "s1")
        XCTAssertEqual(session?.state, .error)
        XCTAssertEqual(session?.stats.errorCount, 1)
    }

    func testUpdateSessionStateOnSessionEnd() async {
        await sendEvent(name: "SessionStart", sessionId: "s1")
        await sendEvent(name: "SessionEnd", sessionId: "s1")

        let session = await manager.session(for: "s1")
        XCTAssertEqual(session?.state, .stopped)
    }

    func testMaxOutputTokensGoesToIdle() async {
        await sendEvent(name: "SessionStart", sessionId: "s1")
        await sendEvent(name: "StopFailure", sessionId: "s1", detail: "max_output_tokens")

        let session = await manager.session(for: "s1")
        XCTAssertEqual(session?.state, .idle)
    }

    func testMultipleSessionsTrackedIndependently() async {
        await sendEvent(name: "SessionStart", sessionId: "s1", cwd: "/project-a")
        await sendEvent(name: "SessionStart", sessionId: "s2", cwd: "/project-b")
        await sendEvent(name: "Stop", sessionId: "s1")

        let s1 = await manager.session(for: "s1")
        let s2 = await manager.session(for: "s2")
        XCTAssertEqual(s1?.state, .idle)
        XCTAssertEqual(s2?.state, .active)
        XCTAssertEqual(s1?.projectName, "project-a")
        XCTAssertEqual(s2?.projectName, "project-b")
    }

    func testProjectNameDerivedFromCwd() async {
        await sendEvent(name: "SessionStart", sessionId: "s1", cwd: "/Users/dev/my-cool-project")

        let session = await manager.session(for: "s1")
        XCTAssertEqual(session?.projectName, "my-cool-project")
    }

    func testProjectNameUnknownWhenNoCwd() async {
        await sendEvent(name: "SessionStart", sessionId: "s1")

        let session = await manager.session(for: "s1")
        XCTAssertEqual(session?.projectName, "Unknown")
    }

    func testEventHistoryRingBuffer() async {
        for i in 0..<60 {
            await sendEvent(name: "Stop", sessionId: "s1", cwd: "/project-\(i)")
        }

        let session = await manager.session(for: "s1")
        XCTAssertEqual(session?.recentEvents.count, 50) // Capacity limit
    }

    func testSessionStatsIncrement() async {
        await sendEvent(name: "SessionStart", sessionId: "s1")
        await sendEvent(name: "Stop", sessionId: "s1")
        await sendEvent(name: "Stop", sessionId: "s1")

        let session = await manager.session(for: "s1")
        XCTAssertEqual(session?.stats.eventCount, 3)
    }

    func testConcurrentEventProcessing() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await self.sendEvent(
                        name: "Stop",
                        sessionId: "session-\(i % 10)",
                        cwd: "/project"
                    )
                }
            }
        }

        let sessions = await manager.allSessions()
        XCTAssertEqual(sessions.count, 10)
    }

    func testRemoveSession() async {
        await sendEvent(name: "SessionStart", sessionId: "s1")
        await manager.removeSession(id: "s1")

        let session = await manager.session(for: "s1")
        XCTAssertNil(session)
    }

    func testActiveSessionsExcludesStopped() async {
        await sendEvent(name: "SessionStart", sessionId: "s1")
        await sendEvent(name: "SessionStart", sessionId: "s2")
        await sendEvent(name: "SessionEnd", sessionId: "s2")

        let active = await manager.activeSessions()
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.id, "s1")
    }

    // MARK: - Helpers

    /// Builds an event the way Claude Code actually sends it. The discriminator
    /// field is named differently per event type, and `matcher` is never present
    /// in hook input at all — it is a settings-side filter only.
    private func sendEvent(
        name: String,
        sessionId: String,
        cwd: String? = nil,
        detail: String? = nil
    ) async {
        let event = HookEvent(
            hookEventName: name,
            sessionId: sessionId,
            cwd: cwd,
            notificationType: name == "Notification" ? detail : nil,
            error: name == "StopFailure" ? detail : nil,
            source: name == "SessionStart" ? detail : nil,
            reason: name == "SessionEnd" ? detail : nil
        )
        await manager.handleEvent(event)
    }
}
