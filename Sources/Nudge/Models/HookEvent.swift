import Foundation

/// Represents an incoming event from an AI coding agent hook.
struct HookEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let hookEventName: String
    let sessionId: String?
    let cwd: String?
    let permissionMode: String?
    let timestamp: Date

    // Notification-specific
    let message: String?
    let title: String?
    /// `notification_type`, e.g. "permission_prompt", "idle_prompt", "agent_needs_input".
    let notificationType: String?

    // StopFailure-specific
    /// `error` — the error type, e.g. "rate_limit", "max_output_tokens".
    let error: String?
    let errorDetails: String?

    // Session lifecycle
    /// `source` on SessionStart: "startup", "resume", "clear", "compact", "fork".
    let source: String?
    /// `reason` on SessionEnd: "clear", "logout", "prompt_input_exit", "other".
    let reason: String?

    // Tool-use specific
    let toolName: String?
    let toolInput: [String: AnyCodable]?
    let toolUseId: String?

    // Additional fields
    let stopHookActive: Bool?
    let transcriptPath: String?
    let lastAssistantMessage: String?

    /// Claude Code does NOT send `matcher` in hook input — it is a settings-side
    /// filter only. Kept solely so older/third-party payloads still decode, and as
    /// a last-resort fallback in `discriminator`. Do not branch on this directly.
    let matcher: String?

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case sessionId = "session_id"
        case cwd
        case permissionMode = "permission_mode"
        case matcher
        case message
        case title
        case notificationType = "notification_type"
        case error
        case errorDetails = "error_details"
        case source
        case reason
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolUseId = "tool_use_id"
        case stopHookActive = "stop_hook_active"
        case transcriptPath = "transcript_path"
        case lastAssistantMessage = "last_assistant_message"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        hookEventName = try container.decode(String.self, forKey: .hookEventName)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
        permissionMode = try container.decodeIfPresent(String.self, forKey: .permissionMode)
        matcher = try container.decodeIfPresent(String.self, forKey: .matcher)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        notificationType = try container.decodeIfPresent(String.self, forKey: .notificationType)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        errorDetails = try container.decodeIfPresent(String.self, forKey: .errorDetails)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        toolInput = try container.decodeIfPresent([String: AnyCodable].self, forKey: .toolInput)
        toolUseId = try container.decodeIfPresent(String.self, forKey: .toolUseId)
        stopHookActive = try container.decodeIfPresent(Bool.self, forKey: .stopHookActive)
        transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
        lastAssistantMessage = try container.decodeIfPresent(String.self, forKey: .lastAssistantMessage)
        timestamp = Date()
    }

    /// Internal initializer for tests and programmatic creation.
    init(
        id: UUID = UUID(),
        hookEventName: String,
        sessionId: String? = nil,
        cwd: String? = nil,
        permissionMode: String? = nil,
        matcher: String? = nil,
        message: String? = nil,
        title: String? = nil,
        notificationType: String? = nil,
        error: String? = nil,
        errorDetails: String? = nil,
        source: String? = nil,
        reason: String? = nil,
        toolName: String? = nil,
        toolInput: [String: AnyCodable]? = nil,
        toolUseId: String? = nil,
        stopHookActive: Bool? = nil,
        transcriptPath: String? = nil,
        lastAssistantMessage: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.hookEventName = hookEventName
        self.sessionId = sessionId
        self.cwd = cwd
        self.permissionMode = permissionMode
        self.matcher = matcher
        self.message = message
        self.title = title
        self.notificationType = notificationType
        self.error = error
        self.errorDetails = errorDetails
        self.source = source
        self.reason = reason
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolUseId = toolUseId
        self.stopHookActive = stopHookActive
        self.transcriptPath = transcriptPath
        self.lastAssistantMessage = lastAssistantMessage
        self.timestamp = timestamp
    }

    /// The sub-type field that distinguishes variants of the same event, whichever
    /// one this event carries. Claude Code names it differently per event:
    /// `notification_type` (Notification), `error` (StopFailure), `source`
    /// (SessionStart), `reason` (SessionEnd). Used for logging and display.
    var discriminator: String? {
        notificationType ?? error ?? source ?? reason ?? matcher
    }
}
