# Nudgy

A native macOS menu bar app that notifies you when your AI coding agent finishes work, needs permissions, or asks a question — without stealing focus from your terminal.

Currently supports [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI, VS Code, Desktop App), with architecture designed for additional agents (Aider, Codex CLI, Cursor, etc.) in the future.

## Why Nudgy?

When you're running an AI coding agent in the background, you don't want to keep checking if it's done. Nudgy watches your agent sessions and shows unobtrusive floating notifications so you can focus on other work.

- **Floating popups** — 5 visual presets (Minimal, Pill, Glass, Card, Banner), configurable position (any corner)
- **Menu bar dropdown** — live session dots, attention alerts with "Go" button, token usage & cost per session
- **Multi-session tracking** — color-coded sessions with state indicators (working, done, waiting, error)
- **Smart suppression** — avoids notification fatigue during rapid-fire events
- **Sound alerts** — mapped to event types, fully configurable per-type
- **Token usage tracking** — parses Claude Code transcripts to show tokens used & estimated cost
- **Claude quota monitoring** — optional integration to show remaining API usage (requires session key)
- **Zero external dependencies** — built entirely on macOS system frameworks

## Requirements

- macOS 14.0+ (Sonoma or later)
- Swift 5.9+

## Installation

### Download

Grab the latest signed & notarized DMG from [GitHub Releases](https://github.com/Hamma111/nudgy/releases/latest), open it, and drag Nudgy to Applications.

### From Source

```bash
git clone https://github.com/Hamma111/nudgy.git
cd nudge
make package
open .build/release/Nudgy.app
```

## How It Works

Nudgy runs a lightweight HTTP server on `127.0.0.1:9847` that listens for events from AI coding agent hooks. All requests are authenticated with a per-install token stored in macOS Keychain. When Claude Code fires a hook event (task complete, permission needed, error, etc.), Nudgy receives the JSON payload and shows an appropriate notification.

```
Claude Code ──hook──▶ POST http://127.0.0.1:9847/event?token=... ──▶ Nudgy ──▶ Floating Popup
```

### Setting Up Hooks

Nudgy automatically installs the required hooks into your `~/.claude/settings.json` on first launch, including a unique auth token for security. The hooks are updated on every launch to keep the token current.

If you prefer to configure them manually, the format is:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "http",
            "url": "http://127.0.0.1:9847/event?token=YOUR_TOKEN"
          }
        ]
      }
    ]
  }
}
```

Nudgy hooks into these events: `Stop`, `StopFailure`, `Notification`, `PermissionRequest`, `SessionStart`, `SessionEnd`.

See [IPC Protocol](architecture/IPC_PROTOCOL.md) for the full list of supported events and payloads.

### Supported Events

| Event | What Happens |
|-------|-------------|
| **Stop** | Agent finished responding — success popup with token usage |
| **PermissionRequest** | Agent needs permission — warning popup with tool & command detail |
| **Notification** (idle/question) | Agent is asking a question — question popup |
| **StopFailure** | Error during generation — error popup |
| **SessionStart** | New session started — tracked silently, dot appears |
| **SessionEnd** | Session ended — cleaned up silently |

## Building

```bash
make build      # Release build
make debug      # Debug build
make test       # Run all tests
make clean      # Clean build artifacts
make package    # Create .app bundle
make dmg        # Create distributable DMG
```

## Architecture

Nudgy is built with SwiftUI + AppKit hybrid using zero external dependencies:

- **HTTP Server** — `NWListener` (Network.framework) on localhost
- **Session Manager** — Swift Actor for thread-safe state management
- **Floating Popups** — `NSPanel` pool (max 3 visible, auto-dismiss, 5 style presets)
- **Menu Bar** — `NSStatusItem` with dynamic status icon, session dots, quota bar
- **Smart Suppression** — Rules engine to prevent notification fatigue
- **Token Tracking** — JSONL transcript parser for per-session token usage & cost
- **Quota Monitor** — Optional claude.ai API integration for remaining usage
- **Window Focus** — Detects active terminal/editor for session focus via "Go" button

See the [architecture](architecture/) directory for detailed design docs.

## Contributing

Contributions are welcome! Please read the [Contributing Guide](CONTRIBUTING.md) before submitting a pull request.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
