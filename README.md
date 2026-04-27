<p align="center">
  <img src="assets/hero.svg" alt="Nudgy — Native macOS notification app for AI coding agents like Claude Code" width="720"/>
</p>

<p align="center">
  <a href="https://github.com/Hamma111/nudgy/actions/workflows/ci.yml"><img src="https://github.com/Hamma111/nudgy/actions/workflows/ci.yml/badge.svg" alt="CI Status"></a>
  <a href="https://github.com/Hamma111/nudgy/releases/latest"><img src="https://img.shields.io/github/v/release/Hamma111/nudgy?label=version" alt="Latest Release"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform: macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange" alt="Swift 5.9+">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Hamma111/nudgy" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/dependencies-0-brightgreen" alt="Zero Dependencies">
</p>

## What is Nudgy?

**Nudgy is a free, open-source macOS menu bar app that sends you native notifications when AI coding agents like [Claude Code](https://docs.anthropic.com/en/docs/claude-code) finish a task, need permissions, or ask a question.** It sits in your menu bar and watches your agent sessions so you can context-switch to other work without constantly checking your terminal.

Nudgy is **privacy-first and fully local** — your conversations and code never leave your machine. No telemetry, no analytics, no remote logging. The only network activity is receiving hook events from your own Claude Code process over `127.0.0.1`.

> Currently supports [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (CLI, VS Code, Desktop App), with architecture designed for additional AI coding agents (Aider, Codex CLI, Cursor, etc.) in the future.

---

## Key Features

- **Floating popup notifications** — 5 visual presets (Minimal, Pill, Glass, Card, Banner), configurable screen position
- **Menu bar session tracker** — live session indicators, attention alerts with "Go" button, per-session token usage
- **Multi-session support** — color-coded sessions with real-time state (working, done, waiting, error)
- **Smart notification suppression** — prevents notification fatigue during rapid-fire agent events
- **Configurable sound alerts** — different sounds mapped to different event types
- **Token usage tracking** — parses Claude Code transcripts to display tokens consumed per session
- **Zero external dependencies** — built entirely with native macOS frameworks (SwiftUI, AppKit, Network.framework)
- **Per-notification toggles** — enable or disable specific event types individually

### Menu Bar

Track all your active Claude Code sessions at a glance. Sessions needing attention float to the top with a "Go" button to jump straight to the right terminal window.

<p align="center">
  <img src="assets/menubar-dropdown.svg" alt="Nudgy menu bar dropdown showing active Claude Code sessions" width="300"/>
</p>

### Popup Presets

Pick the notification style that fits your workflow — from a tiny dark chip to a full macOS-style banner.

<p align="center">
  <img src="assets/popup-presets.svg" alt="Nudgy popup notification presets — Minimal, Pill, Glass, Card, Banner" width="680"/>
</p>

## Installation

### Download (Recommended)

1. Grab the latest `.dmg` from [GitHub Releases](https://github.com/Hamma111/nudgy/releases/latest)
2. Open it, and drag Nudgy to Applications.

Enjoy.


**Requirements:** macOS 14.0+ (Sonoma or later), Swift 5.9+

## How It Works

Nudgy runs a lightweight HTTP server on `127.0.0.1:9847` that listens for [Claude Code hook events](https://docs.anthropic.com/en/docs/claude-code). All requests are authenticated with a per-install token stored in macOS Keychain. When Claude Code fires a hook event, Nudgy receives the JSON payload and shows the appropriate notification.

```
Claude Code ──hook──> POST http://127.0.0.1:9847/event?token=... ──> Nudgy ──> Floating Popup
```

### Automatic Setup

Nudgy automatically installs the required hooks into your `~/.claude/settings.json` on first launch, including a unique auth token. Hooks are refreshed on every launch to keep the token current.

### Manual Setup

If you prefer to configure hooks yourself:

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

Nudgy hooks into these Claude Code events: `Stop`, `StopFailure`, `Notification`, `PermissionRequest`, `SessionStart`, `SessionEnd`.

### Supported Events

| Event | What Nudgy Does |
|---|---|
| **Stop** | Agent finished — success popup with token usage |
| **PermissionRequest** | Agent needs permission — warning popup with tool and command detail |
| **Notification** (idle/question) | Agent is asking a question — question popup |
| **StopFailure** | Error during generation — error popup |
| **SessionStart** | New session tracked — dot appears in menu bar |
| **SessionEnd** | Session cleaned up — dot removed |

## Architecture

Nudgy is built with SwiftUI + AppKit using zero external dependencies:

| Component | Technology |
|---|---|
| HTTP Server | `NWListener` (Network.framework) on localhost |
| Session Manager | Swift Actor for thread-safe state |
| Floating Popups | `NSPanel` pool (max 3, auto-dismiss, 5 presets) |
| Menu Bar | `NSStatusItem` with dynamic icon and session dots |
| Smart Suppression | Rules engine to prevent notification fatigue |
| Token Tracking | JSONL transcript parser for per-session usage |
| Window Focus | Detects active terminal/editor for "Go" button |

See the [architecture](architecture/) directory for detailed design docs.

## Building from Source

```bash
make build      # Release build
make debug      # Debug build
make test       # Run all tests
make clean      # Clean build artifacts
make package    # Create .app bundle
make dmg        # Create distributable DMG
```

## Privacy

Nudgy is **fully local**. Your conversations, code, and session data never leave your machine. There is no telemetry, no analytics, no crash reporting, and no remote logging. The only network activity is the localhost HTTP server (`127.0.0.1`) receiving hook events from your own Claude Code process. Nothing is sent to the internet.

The source code is open — you're welcome to [audit every line](https://github.com/Hamma111/nudgy).

## FAQ

### Does Nudgy read my code or conversations?

No. Nudgy only receives structured hook event payloads (event type, session ID, timestamps) from Claude Code. It does not read your source files, conversation history, or terminal output. The only content it parses is the Claude Code transcript file for token counts, and that data stays entirely on your machine.

### Does Nudgy work with AI coding agents other than Claude Code?

Currently Nudgy supports Claude Code (CLI, VS Code extension, and Desktop App). The architecture uses a generic HTTP hook protocol, so support for other agents like Aider, Codex CLI, and Cursor can be added in the future.

### Does Nudgy send any data to the internet?

No. Nudgy binds exclusively to `127.0.0.1` (localhost). It makes no outbound network requests. There is an optional Usage Quota feature that, if enabled by the user, fetches quota info from the Anthropic API — but this is off by default and requires explicit opt-in.

### Is Nudgy free?

Yes. Nudgy is free and open-source under the [MIT License](LICENSE).

### What macOS versions are supported?

macOS 14.0 (Sonoma) and later. Nudgy uses SwiftUI and modern Apple frameworks that require macOS 14+.

### How do I uninstall Nudgy?

Quit Nudgy from the menu bar, then delete `Nudgy.app` from your Applications folder. Nudgy will automatically clean up its hooks from `~/.claude/settings.json` when you quit.

## Contributing

Contributions are welcome! Please read the [Contributing Guide](CONTRIBUTING.md) before submitting a pull request.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
