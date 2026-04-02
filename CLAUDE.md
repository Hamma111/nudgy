# Nudgy

Native macOS menu bar app that notifies you when AI coding agents need attention. Currently supports Claude Code.

## Build & Run

```bash
make build          # release build
make debug          # debug build
make test           # run tests
make run            # debug build + launch
make package        # create .app bundle
make release        # full pipeline: test → sign → dmg
```

Requires: Swift 5.9+, macOS 14.0+ (Sonoma). Zero external dependencies — only Apple system frameworks.

## Architecture

```
Sources/Nudge/
├── App/        # NudgeApp.swift (@main), AppDelegate.swift (lifecycle + notification pipeline)
├── Models/     # AppState, AgentSession, HookEvent, NotificationItem, RingBuffer, AnyCodable
├── Server/     # HTTPServer (NWListener on 127.0.0.1:9847, token-authenticated)
├── Services/   # SessionManager, HookInstaller, SmartSuppressor, TranscriptParser,
│               # WindowFocuser, SoundManager, UsageQuotaManager, KeychainHelper, Logger
└── UI/         # MenuBarManager, MenuBarView, PopupWindowController, PopupContentView,
                # SettingsView, NudgyIcon
```

## Event Flow

```
Claude Code hook → HTTP POST /event?token=... → HTTPServer (responds 200 immediately)
  → AppDelegate.httpServer(_:didReceive:)
  → SessionManager.handleEvent() [actor-isolated, updates session state]
  → SmartSuppressor.evaluate() → show / suppress / escalate / batch
  → PopupWindowController.show(item) + SoundManager + MenuBarManager.updateIcon()
```

## Key Patterns

- **AppState** is `@Observable @MainActor` — the single source of truth for all UI
- **SessionManager** is a Swift `actor` — always `await` its methods
- **UserDefaults keys** use `nudgy.*` prefix (e.g. `nudgy.soundEnabled`, `nudgy.notify.success`)
- **HTTP responses** are sent immediately; event processing is async
- **Auth token** stored in Keychain, generated on first launch

## Session States

States in priority order (highest first):

| State | Priority | Style | Auto-dismiss |
|---|---|---|---|
| waitingPermission | 100 | warning (orange) | no |
| error | 90 | error (red) | 3s |
| waitingInput | 80 | question (yellow) | no |
| active | 50 | — | — |
| idle | 10 | success (teal) | 3s |
| stopped | 0 | — | — |

## Notification Styles

Five styles used throughout: `success`, `warning`, `question`, `error`, `info`. Each has color, gradient, icon, and a user toggle (`nudgy.notify.<style>`).

## Hook System

HookInstaller manages `~/.claude/settings.json`:
- Installs HTTP hooks for: Stop, Notification, StopFailure, SessionStart, PermissionRequest, SessionEnd
- Creates timestamped backups before modifying (keeps max 5)
- Idempotent — detects existing Nudgy hooks by URL pattern
- Cleans up on quit (unless user explicitly uninstalled)

## Tests

```bash
swift test
```

Tests in `Tests/NudgyTests/`: SessionManager, HTTPServer, HookInstaller, SmartSuppressor, RingBuffer, AppState, HookEvent, WindowFocuser, SoundManager, Integration.

## Style Notes

- SwiftUI for views, AppKit for window management (NSPanel, NSStatusItem)
- No external dependencies — Network.framework for HTTP, Keychain for secrets
- Popup presets: Minimal, Pill, Glass (default), Card, Banner
- Sound effects mapped per notification style, user-configurable
- Smart suppression avoids notification fatigue (3+ events in 10s = suppress idle completions)
- Logger writes to `~/Library/Logs/Nudgy/nudgy.log` (rotates at 5MB)
