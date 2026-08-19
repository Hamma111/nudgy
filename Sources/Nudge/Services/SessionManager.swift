import Foundation
import SwiftUI

/// Thread-safe session state manager.
actor SessionManager {
    private var sessions: [String: AgentSession] = [:]
    private let appState: AppState
    private var cleanupTask: Task<Void, Never>?
    private var colorIndex: Int = 0

    /// Maximum number of tracked sessions to prevent memory exhaustion.
    private static let maxSessions = 100

    private static let accentColors: [Color] = [
        .blue, .purple, .orange, .pink, .cyan, .mint, .indigo, .teal
    ]

    private static let staleThreshold: TimeInterval = 300 // 5 minutes

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Event Processing

    func handleEvent(_ event: HookEvent) async {
        let sessionId = event.sessionId ?? "unknown"

        var session = sessions[sessionId] ?? AgentSession(
            id: sessionId,
            state: .active,
            projectName: Self.projectName(from: event.cwd),
            workingDirectory: event.cwd,
            accentColor: nextAccentColor(),
            startedAt: Date(),
            lastEventAt: Date(),
            pendingPermissions: [],
            recentEvents: RingBuffer<HookEvent>(capacity: 50),
            stats: SessionStats()
        )

        switch event.hookEventName {
        case "SessionStart":
            session.state = .active

        case "Stop":
            session.state = .idle
            if let usage = TranscriptParser.parseUsage(sessionId: sessionId, cwd: event.cwd ?? session.workingDirectory) {
                session.tokenUsage = usage
            }

        case "Notification":
            // Claude Code sends `notification_type`; `matcher` is a settings-side
            // filter and never appears in the payload.
            switch event.notificationType {
            case "permission_prompt":
                session.state = .waitingPermission
                session.pendingPermissions.append(PermissionRequest(from: event))
                session.stats.permissionCount += 1
            case "idle_prompt", "agent_needs_input", "elicitation_dialog", "elicitation_url_dialog":
                session.state = .waitingInput
            case "agent_completed":
                session.state = .idle
            default:
                // auth_success, elicitation_complete, etc. — record only, keep state
                break
            }

        case "StopFailure":
            // The error type lives in `error`, not `matcher`.
            if event.error == "max_output_tokens" {
                session.state = .idle
            } else {
                session.state = .error
                session.stats.errorCount += 1
            }

        case "SessionEnd":
            session.state = .stopped

        case "PreToolUse":
            session.state = .active

        case "PermissionRequest":
            // Permission dialog is being shown to the user RIGHT NOW
            session.state = .waitingPermission
            session.pendingPermissions.append(PermissionRequest(from: event))
            session.stats.permissionCount += 1

        default:
            break
        }

        session.lastEventAt = Date()
        session.recentEvents.append(event)
        session.stats.eventCount += 1
        sessions[sessionId] = session

        // Evict oldest stopped sessions if we exceed the cap
        if sessions.count > Self.maxSessions {
            evictStaleSessions()
        }

        let updatedSession = session
        await MainActor.run {
            appState.updateFromSession(updatedSession)
        }
    }

    // MARK: - Session Queries

    func session(for id: String) -> AgentSession? {
        sessions[id]
    }

    func activeSessions() -> [AgentSession] {
        sessions.values.filter { $0.state != .stopped }
    }

    func allSessions() -> [AgentSession] {
        Array(sessions.values)
    }

    func removeSession(id: String) async {
        sessions.removeValue(forKey: id)
        await MainActor.run {
            appState.removeSession(id: id)
        }
    }

    // MARK: - Stale Session Cleanup

    func startCleanupTimer() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60s
                await self?.cleanupStaleSessions()
            }
        }
    }

    func stopCleanupTimer() {
        cleanupTask?.cancel()
        cleanupTask = nil
    }

    func cleanupStaleSessions() async {
        let now = Date()
        let staleIds = sessions.filter { _, session in
            session.state != .stopped &&
            now.timeIntervalSince(session.lastEventAt) > Self.staleThreshold
        }.map(\.key)

        for id in staleIds {
            sessions[id]?.state = .stopped
            if let session = sessions[id] {
                await MainActor.run {
                    appState.updateFromSession(session)
                }
            }
        }
    }

    /// Remove oldest stopped sessions to stay within the session cap.
    private func evictStaleSessions() {
        let stopped = sessions.filter { $0.value.state == .stopped }
            .sorted { $0.value.lastEventAt < $1.value.lastEventAt }
        for (id, _) in stopped.prefix(sessions.count - Self.maxSessions) {
            sessions.removeValue(forKey: id)
        }
    }

    // MARK: - Helpers

    private func nextAccentColor() -> Color {
        let color = Self.accentColors[colorIndex % Self.accentColors.count]
        colorIndex += 1
        return color
    }

    static func projectName(from cwd: String?) -> String {
        guard let cwd = cwd else { return "Unknown" }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }
}
