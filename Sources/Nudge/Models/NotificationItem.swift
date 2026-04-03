import Foundation
import SwiftUI

/// A notification to display in the UI.
struct NotificationItem: Identifiable, Sendable {
    let id: UUID
    let sessionId: String
    let projectName: String
    let title: String
    let message: String
    let style: NotificationStyle
    let timestamp: Date
    var autoDismissAfter: TimeInterval?
    var actions: [NotificationAction]

    init(
        id: UUID = UUID(),
        sessionId: String,
        projectName: String,
        title: String,
        message: String,
        style: NotificationStyle,
        timestamp: Date = Date(),
        autoDismissAfter: TimeInterval? = 3.0,
        actions: [NotificationAction] = []
    ) {
        self.id = id
        self.sessionId = sessionId
        self.projectName = projectName
        self.title = title
        self.message = message
        self.style = style
        self.timestamp = timestamp
        self.autoDismissAfter = autoDismissAfter
        self.actions = actions
    }
}

/// Visual style for a notification popup.
enum NotificationStyle: String, Sendable {
    case success
    case warning
    case question
    case error
    case info

    var color: Color {
        switch self {
        case .success:  return Color(red: 0.3, green: 0.8, blue: 0.65)
        case .warning:  return Color(red: 1.0, green: 0.6, blue: 0.15)
        case .question: return Color(red: 1.0, green: 0.78, blue: 0.3)
        case .error:    return Color(red: 1.0, green: 0.35, blue: 0.25)
        case .info:     return Color(red: 0.55, green: 0.52, blue: 0.5)
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .success:
            return LinearGradient(
                colors: [Color(red: 0.25, green: 0.75, blue: 0.6), Color(red: 0.35, green: 0.85, blue: 0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .warning:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.55, blue: 0.1), Color(red: 1.0, green: 0.65, blue: 0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .question:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.72, blue: 0.2), Color(red: 1.0, green: 0.84, blue: 0.4)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .error:
            return LinearGradient(
                colors: [Color(red: 0.95, green: 0.28, blue: 0.2), Color(red: 1.0, green: 0.42, blue: 0.3)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .info:
            return LinearGradient(
                colors: [Color(red: 0.5, green: 0.47, blue: 0.45), Color(red: 0.6, green: 0.57, blue: 0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var icon: String {
        switch self {
        case .success:  return "checkmark.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .question: return "questionmark.bubble.fill"
        case .error:    return "xmark.octagon.fill"
        case .info:     return "info.circle.fill"
        }
    }

    var glowColor: Color {
        color.opacity(0.35)
    }

    /// Whether this notification style is enabled by the user in Settings.
    var isEnabled: Bool {
        let key = "nudgy.notify.\(rawValue)"
        let defaultValue = self != .info
        return UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }
}

/// An action button in a notification.
struct NotificationAction: Identifiable, Sendable {
    let id: UUID
    let label: String
    let style: ActionStyle
    let handler: @Sendable () -> Void

    init(
        id: UUID = UUID(),
        label: String,
        style: ActionStyle = .secondary,
        handler: @escaping @Sendable () -> Void
    ) {
        self.id = id
        self.label = label
        self.style = style
        self.handler = handler
    }
}

enum ActionStyle: String, Sendable {
    case primary
    case secondary
    case destructive
}
