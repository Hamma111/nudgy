import Foundation

enum HookInstallerError: Error, LocalizedError {
    case settingsFileCorrupted(String)
    case backupFailed(Error)
    case writeFailed(Error)
    case validationFailed

    var errorDescription: String? {
        switch self {
        case .settingsFileCorrupted(let detail):
            return "Settings file corrupted: \(detail)"
        case .backupFailed(let error):
            return "Backup failed: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Write failed: \(error.localizedDescription)"
        case .validationFailed:
            return "Hook validation failed after write"
        }
    }
}

/// Installs and manages Nudgy hooks in ~/.claude/settings.json.
final class HookInstaller {
    static let hookedEvents = [
        "Stop",
        "Notification",
        "StopFailure",
        "PermissionRequest",
        "SessionEnd",
    ]

    /// Events that were hooked in previous versions but are no longer needed.
    /// These are cleaned up during install to avoid error spam when Nudgy isn't running.
    ///
    /// `SessionStart` only supports `command` and `mcp_tool` handlers — an `http`
    /// handler there is silently never invoked, so the entry was dead weight.
    /// Sessions are created lazily on their first real event instead.
    private static let legacyEvents = [
        "PreToolUse",
        "SessionStart",
    ]

    let port: UInt16
    let token: String?
    let claudeDir: URL
    let settingsPath: URL

    private static let maxBackups = 5

    init(port: UInt16 = 9847, token: String? = nil, settingsDir: URL? = nil) {
        self.port = port
        self.token = token
        let dir = settingsDir ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        self.claudeDir = dir
        self.settingsPath = dir.appendingPathComponent("settings.json")
    }

    /// Install hooks into settings.json.
    func install() throws {
        let fm = FileManager.default

        // Create .claude directory if needed
        if !fm.fileExists(atPath: claudeDir.path) {
            try fm.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        }

        // Create backup if file exists
        if fm.fileExists(atPath: settingsPath.path) {
            try createBackup()
        }

        var settings = try readSettings()
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        var hookURL = "http://127.0.0.1:\(port)/event"
        if let token = token, !token.isEmpty {
            hookURL += "?token=\(token)"
        }

        for eventType in Self.hookedEvents {
            var eventHooks = hooks[eventType] as? [[String: Any]] ?? []

            // Check if our hook already exists
            let existingIndex = eventHooks.firstIndex { group in
                guard let hooksList = group["hooks"] as? [[String: Any]] else { return false }
                return hooksList.contains { hook in
                    guard let url = hook["url"] as? String else { return false }
                    return url.contains("127.0.0.1") && url.contains("/event")
                }
            }

            let hookEntry = buildHookEntry(for: eventType, url: hookURL)

            if let index = existingIndex {
                // Update existing entry (port may have changed)
                eventHooks[index] = hookEntry
            } else {
                // Append new entry
                eventHooks.append(hookEntry)
            }

            hooks[eventType] = eventHooks
        }

        // Remove legacy hooks from previous Nudgy versions
        for legacyEvent in Self.legacyEvents {
            guard var eventHooks = hooks[legacyEvent] as? [[String: Any]] else { continue }
            eventHooks.removeAll { group in
                guard let hooksList = group["hooks"] as? [[String: Any]] else { return false }
                return hooksList.contains { hook in
                    guard let url = hook["url"] as? String else { return false }
                    return url.contains("127.0.0.1") && url.contains("/event")
                }
            }
            if eventHooks.isEmpty {
                hooks.removeValue(forKey: legacyEvent)
            } else {
                hooks[legacyEvent] = eventHooks
            }
        }

        settings["hooks"] = hooks
        try writeSettings(settings)
        try pruneBackups()
    }

    /// Remove only Nudgy hooks from settings.json.
    func uninstall() throws {
        guard FileManager.default.fileExists(atPath: settingsPath.path) else { return }

        try createBackup()

        var settings = try readSettings()
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for eventType in hooks.keys {
            guard var eventHooks = hooks[eventType] as? [[String: Any]] else { continue }

            eventHooks.removeAll { group in
                guard let hooksList = group["hooks"] as? [[String: Any]] else { return false }
                return hooksList.contains { hook in
                    guard let url = hook["url"] as? String else { return false }
                    return url.contains("127.0.0.1") && url.contains("/event")
                }
            }

            if eventHooks.isEmpty {
                hooks.removeValue(forKey: eventType)
            } else {
                hooks[eventType] = eventHooks
            }
        }

        if hooks.isEmpty {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }

        try writeSettings(settings)
    }

    /// Check if hooks are already installed.
    func isInstalled() -> Bool {
        guard let settings = try? readSettings(),
              let hooks = settings["hooks"] as? [String: Any] else {
            return false
        }

        return Self.hookedEvents.allSatisfy { eventType in
            guard let eventHooks = hooks[eventType] as? [[String: Any]] else { return false }
            return eventHooks.contains { group in
                guard let hooksList = group["hooks"] as? [[String: Any]] else { return false }
                return hooksList.contains { hook in
                    guard let url = hook["url"] as? String else { return false }
                    return url.contains("127.0.0.1") && url.contains("/event")
                }
            }
        }
    }

    /// Verify hooks are correctly configured.
    func verify() -> Bool {
        isInstalled()
    }

    // MARK: - Private

    func readSettings() throws -> [String: Any] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: settingsPath.path) else {
            return [:]
        }

        let data = try Data(contentsOf: settingsPath)
        guard !data.isEmpty else { return [:] }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw HookInstallerError.settingsFileCorrupted(error.localizedDescription)
        }

        guard let json = object as? [String: Any] else {
            throw HookInstallerError.settingsFileCorrupted("Not a JSON object")
        }
        return json
    }

    private func writeSettings(_ settings: [String: Any]) throws {
        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: settingsPath, options: .atomic)
    }

    @discardableResult
    func createBackup() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let timestamp = formatter.string(from: Date())
        let backupName = "settings.json.backup.\(timestamp)-\(UInt32.random(in: 0...9999))"
        let backupPath = claudeDir.appendingPathComponent(backupName)

        do {
            try FileManager.default.copyItem(at: settingsPath, to: backupPath)
            return backupPath
        } catch {
            throw HookInstallerError.backupFailed(error)
        }
    }

    private func pruneBackups() throws {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: claudeDir, includingPropertiesForKeys: [.creationDateKey])
        let backups = contents
            .filter { $0.lastPathComponent.hasPrefix("settings.json.backup.") }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return dateA > dateB
            }

        for backup in backups.dropFirst(Self.maxBackups) {
            try? fm.removeItem(at: backup)
        }
    }

    private func buildHookEntry(for eventType: String, url: String) -> [String: Any] {
        var hook: [String: Any] = ["type": "http", "url": url]

        // SessionEnd hooks share a 1.5s budget by default; a localhost round trip
        // fits easily, but be explicit so a slow start-up can't drop the event.
        if eventType == "SessionEnd" {
            hook["timeout"] = 5
        }

        return ["hooks": [hook]]
    }
}
