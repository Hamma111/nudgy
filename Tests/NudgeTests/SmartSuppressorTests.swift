import XCTest
import SwiftUI
@testable import Nudgy

final class SmartSuppressorTests: XCTestCase {

    private func makeSession(
        id: String = "s1",
        state: SessionState,
        startedAt: Date = Date().addingTimeInterval(-60),
        lastEventAt: Date = Date(),
        pendingPermissions: [PermissionRequest] = []
    ) -> AgentSession {
        AgentSession(
            id: id,
            state: state,
            projectName: "TestProject",
            accentColor: .blue,
            startedAt: startedAt,
            lastEventAt: lastEventAt,
            pendingPermissions: pendingPermissions,
            recentEvents: RingBuffer<HookEvent>(capacity: 50),
            stats: SessionStats()
        )
    }

    func testPermissionRequestIsNeverSuppressed() {
        let focuser = WindowFocuser()
        let suppressor = SmartSuppressor(windowFocuser: focuser)
        let event = HookEvent(hookEventName: "Notification", sessionId: "s1", notificationType: "permission_prompt")
        let session = makeSession(state: .waitingPermission)

        let decision = suppressor.evaluate(event: event, session: session)
        XCTAssertEqual(decision, .show)
    }

    func testErrorIsNeverSuppressed() {
        let focuser = WindowFocuser()
        let suppressor = SmartSuppressor(windowFocuser: focuser)
        let event = HookEvent(hookEventName: "StopFailure", sessionId: "s1", error: "rate_limit")
        let session = makeSession(state: .error)

        let decision = suppressor.evaluate(event: event, session: session)
        XCTAssertEqual(decision, .show)
    }

    func testWaitingInputIsNeverSuppressed() {
        let focuser = WindowFocuser()
        let suppressor = SmartSuppressor(windowFocuser: focuser)
        let event = HookEvent(hookEventName: "Notification", sessionId: "s1", notificationType: "idle_prompt")
        let session = makeSession(state: .waitingInput)

        let decision = suppressor.evaluate(event: event, session: session)
        XCTAssertEqual(decision, .show)
    }

    func testTerminalFocusedSuppressionDisabledByDefault() {
        let focuser = WindowFocuser()
        let suppressor = SmartSuppressor(windowFocuser: focuser)
        // suppressWhenTerminalFocused is false by default
        XCTAssertFalse(suppressor.suppressWhenTerminalFocused)

        let event = HookEvent(hookEventName: "Stop", sessionId: "s1")
        let session = makeSession(state: .idle)

        // Should show even if terminal is focused (since suppression is off)
        let decision = suppressor.evaluate(event: event, session: session)
        XCTAssertEqual(decision, .show)
    }

    func testBatchRapidFireEvents() {
        let focuser = WindowFocuser()
        let suppressor = SmartSuppressor(windowFocuser: focuser)
        suppressor.batchWindow = 10.0

        for _ in 0..<4 {
            suppressor.recordEvent(HookEvent(hookEventName: "Stop", sessionId: "s1"))
        }

        let event = HookEvent(hookEventName: "Stop", sessionId: "s1")
        let session = makeSession(state: .idle)

        let decision = suppressor.evaluate(event: event, session: session)
        XCTAssertEqual(decision, .batch(groupId: "s1"))
    }

    func testShowWhenEventsAreSpreadOut() {
        let focuser = WindowFocuser()
        let suppressor = SmartSuppressor(windowFocuser: focuser)
        suppressor.batchWindow = 10.0

        for _ in 0..<2 {
            suppressor.recordEvent(HookEvent(hookEventName: "Stop", sessionId: "s1"))
        }

        let event = HookEvent(hookEventName: "Stop", sessionId: "s1")
        let session = makeSession(state: .idle)

        let decision = suppressor.evaluate(event: event, session: session)
        XCTAssertEqual(decision, .show)
    }

    func testEscalateStalePermission() {
        let focuser = WindowFocuser()
        let suppressor = SmartSuppressor(windowFocuser: focuser)
        suppressor.escalationThreshold = 120.0

        let stalePermission = PermissionRequest(
            sessionId: "s1",
            toolName: "Bash",
            timestamp: Date().addingTimeInterval(-180)
        )
        let session = makeSession(
            state: .waitingPermission,
            pendingPermissions: [stalePermission]
        )
        let event = HookEvent(hookEventName: "Notification", sessionId: "s1", notificationType: "permission_prompt")

        let decision = suppressor.evaluate(event: event, session: session)
        XCTAssertEqual(decision, .escalate)
    }

    func testDisabledSuppressionAlwaysShows() {
        let focuser = WindowFocuser()
        let suppressor = SmartSuppressor(windowFocuser: focuser)
        suppressor.isEnabled = false

        let event = HookEvent(hookEventName: "Stop", sessionId: "s1")
        let session = makeSession(state: .idle)

        let decision = suppressor.evaluate(event: event, session: session)
        XCTAssertEqual(decision, .show)
    }

    func testDifferentSessionsTrackedSeparately() {
        let focuser = WindowFocuser()
        let suppressor = SmartSuppressor(windowFocuser: focuser)
        suppressor.batchWindow = 10.0

        for _ in 0..<4 {
            suppressor.recordEvent(HookEvent(hookEventName: "Stop", sessionId: "sA"))
        }

        let eventB = HookEvent(hookEventName: "Stop", sessionId: "sB")
        let sessionB = makeSession(id: "sB", state: .idle)

        let decision = suppressor.evaluate(event: eventB, session: sessionB)
        XCTAssertEqual(decision, .show)
    }

    func testNormalStopEventShows() {
        let focuser = WindowFocuser()
        let suppressor = SmartSuppressor(windowFocuser: focuser)

        let event = HookEvent(hookEventName: "Stop", sessionId: "s1")
        let session = makeSession(state: .idle)

        let decision = suppressor.evaluate(event: event, session: session)
        XCTAssertEqual(decision, .show)
    }
}
