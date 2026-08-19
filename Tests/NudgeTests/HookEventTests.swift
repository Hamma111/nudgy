import XCTest
@testable import Nudgy

/// Decoding tests for `HookEvent`.
///
/// The JSON fixtures below are verbatim captures from Claude Code 2.1.235 taken by
/// pointing real hooks at a logging HTTP endpoint. Do not hand-write payloads here:
/// an earlier version of this file invented a `matcher` field that Claude Code never
/// sends, which kept the suite green while the app was broken in production.
final class HookEventTests: XCTestCase {

    func testDecodeStopEvent() throws {
        // Captured: Stop
        let json = """
        {
            "session_id": "b4a4d1a6-34b1-42a0-9817-d237b0b19ff1",
            "transcript_path": "/Users/dev/.claude/projects/-Users-dev-myproject/b4a4d1a6.jsonl",
            "cwd": "/Users/dev/myproject",
            "prompt_id": "95ee8829-b27b-4ce9-aeb6-79d894713816",
            "permission_mode": "default",
            "effort": { "level": "high" },
            "hook_event_name": "Stop",
            "stop_hook_active": false,
            "last_assistant_message": "Output: `hello`",
            "background_tasks": [],
            "session_crons": []
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "Stop")
        XCTAssertEqual(event.sessionId, "b4a4d1a6-34b1-42a0-9817-d237b0b19ff1")
        XCTAssertEqual(event.cwd, "/Users/dev/myproject")
        XCTAssertEqual(event.permissionMode, "default")
        XCTAssertEqual(event.stopHookActive, false)
        XCTAssertEqual(event.lastAssistantMessage, "Output: `hello`")
        XCTAssertNotNil(event.transcriptPath)
    }

    func testDecodeNotificationPermissionPrompt() throws {
        // Captured: Notification fired by an interactive permission dialog.
        let json = """
        {
            "session_id": "7da86ad3-49ea-4f16-a8e1-24aac955aca2",
            "transcript_path": "/Users/dev/.claude/projects/-Users-dev-myproject/7da86ad3.jsonl",
            "cwd": "/Users/dev/myproject",
            "prompt_id": "114ec577-a5a2-443d-a738-ac85a7e7459c",
            "hook_event_name": "Notification",
            "message": "Claude needs your permission",
            "notification_type": "permission_prompt"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "Notification")
        XCTAssertEqual(event.notificationType, "permission_prompt")
        XCTAssertEqual(event.message, "Claude needs your permission")
        // Regression guard: the payload carries no `matcher`.
        XCTAssertNil(event.matcher)
        XCTAssertEqual(event.discriminator, "permission_prompt")
    }

    func testDecodeNotificationIdlePrompt() throws {
        let json = """
        {
            "hook_event_name": "Notification",
            "session_id": "abc-123-def",
            "cwd": "/Users/dev/myproject",
            "message": "Claude is waiting for your input",
            "notification_type": "idle_prompt"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.notificationType, "idle_prompt")
        XCTAssertNil(event.matcher)
    }

    func testDecodeStopFailure() throws {
        // StopFailure carries the error type in `error`, not `matcher`.
        let json = """
        {
            "hook_event_name": "StopFailure",
            "session_id": "abc-123-def",
            "cwd": "/Users/dev/myproject",
            "error": "rate_limit",
            "error_details": "API Error: Rate limit reached",
            "last_assistant_message": "API Error: Rate limit reached"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "StopFailure")
        XCTAssertEqual(event.error, "rate_limit")
        XCTAssertEqual(event.errorDetails, "API Error: Rate limit reached")
        XCTAssertNil(event.matcher)
        XCTAssertEqual(event.discriminator, "rate_limit")
    }

    func testDecodeSessionStart() throws {
        // Captured: SessionStart (via a command hook — HTTP handlers are not
        // supported on this event, which is why Nudgy no longer registers one).
        let json = """
        {
            "session_id": "b4a4d1a6-34b1-42a0-9817-d237b0b19ff1",
            "transcript_path": "/Users/dev/.claude/projects/-Users-dev-myproject/b4a4d1a6.jsonl",
            "cwd": "/Users/dev/myproject",
            "hook_event_name": "SessionStart",
            "source": "startup"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "SessionStart")
        XCTAssertEqual(event.source, "startup")
        XCTAssertNil(event.matcher)
    }

    func testDecodeSessionEnd() throws {
        // Captured: SessionEnd
        let json = """
        {
            "session_id": "b4a4d1a6-34b1-42a0-9817-d237b0b19ff1",
            "transcript_path": "/Users/dev/.claude/projects/-Users-dev-myproject/b4a4d1a6.jsonl",
            "cwd": "/Users/dev/myproject",
            "prompt_id": "95ee8829-b27b-4ce9-aeb6-79d894713816",
            "hook_event_name": "SessionEnd",
            "reason": "other"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "SessionEnd")
        XCTAssertEqual(event.reason, "other")
        XCTAssertNil(event.matcher)
    }

    func testDecodePermissionRequest() throws {
        // Captured: PermissionRequest for a Write tool call.
        let json = """
        {
            "session_id": "7da86ad3-49ea-4f16-a8e1-24aac955aca2",
            "cwd": "/Users/dev/myproject",
            "permission_mode": "default",
            "hook_event_name": "PermissionRequest",
            "tool_name": "Write",
            "tool_input": {
                "file_path": "/Users/dev/myproject/probe.txt",
                "content": "banana\\n"
            },
            "permission_suggestions": [
                { "type": "setMode", "mode": "acceptEdits", "destination": "session" }
            ]
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "PermissionRequest")
        XCTAssertEqual(event.toolName, "Write")
        XCTAssertEqual(event.toolInput?["file_path"]?.value as? String,
                       "/Users/dev/myproject/probe.txt")
        // PermissionRequest does not carry a tool_use_id.
        XCTAssertNil(event.toolUseId)
    }

    func testDecodeWithMissingOptionalFields() throws {
        let json = """
        {
            "hook_event_name": "Stop"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "Stop")
        XCTAssertNil(event.sessionId)
        XCTAssertNil(event.cwd)
        XCTAssertNil(event.notificationType)
        XCTAssertNil(event.error)
        XCTAssertNil(event.toolName)
        XCTAssertNil(event.toolInput)
        XCTAssertNil(event.discriminator)
    }

    func testDecodeWithUnknownEventName() throws {
        let json = """
        {
            "hook_event_name": "FutureEvent",
            "session_id": "abc-123-def"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.hookEventName, "FutureEvent")
    }

    func testDecodeInvalidJSON() {
        let json = "not json at all".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(HookEvent.self, from: json))
    }

    func testDecodeWithToolInput() throws {
        let json = """
        {
            "hook_event_name": "PermissionRequest",
            "session_id": "abc-123",
            "tool_name": "Bash",
            "tool_input": {
                "command": "ls -la",
                "description": "List files"
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertEqual(event.toolName, "Bash")
        XCTAssertNotNil(event.toolInput)
        XCTAssertEqual(event.toolInput?["command"]?.value as? String, "ls -la")
    }

    func testEventHasUniqueId() throws {
        let json = """
        {"hook_event_name": "Stop"}
        """.data(using: .utf8)!

        let event1 = try JSONDecoder().decode(HookEvent.self, from: json)
        let event2 = try JSONDecoder().decode(HookEvent.self, from: json)
        XCTAssertNotEqual(event1.id, event2.id)
    }
}
