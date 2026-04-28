import Cocoa
import SwiftUI

/// Manages floating toast-style notification panels.
@MainActor
final class PopupWindowController {
    private var activePanels: [(panel: NSPanel, item: NotificationItem, id: UUID)] = []
    private var dismissTimers: [UUID: Task<Void, Never>] = [:]
    private let maxVisible: Int = 3
    private let stackGap: CGFloat = 4
    private let edgePadding: CGFloat = 12
    private let panelMinHeight: CGFloat = 46

    var onDismiss: ((UUID) -> Void)?
    var onAction: ((NotificationAction) -> Void)?
    var preset: PopupPreset = {
        PopupPreset(rawValue: UserDefaults.standard.string(forKey: "nudgy.popupPreset") ?? "") ?? .glass
    }()

    private var slideOffsetX: CGFloat {
        popupPosition.contains("Left") ? -40 : 40
    }

    func show(_ item: NotificationItem) {
        // Deduplicate: if this session already has a non-auto-dismiss (waiting) popup, skip
        if item.autoDismissAfter == nil {
            let hasExistingWaiting = activePanels.contains {
                $0.item.sessionId == item.sessionId && $0.item.autoDismissAfter == nil
            }
            if hasExistingWaiting { return }
        }

        // Cap visible popups
        if activePanels.count >= maxVisible {
            if let oldest = activePanels.last {
                dismiss(id: oldest.id)
            }
        }

        let panel = createPanel(for: item)
        let panelSize = panel.frame.size
        activePanels.insert((panel: panel, item: item, id: item.id), at: 0)
        repositionPanels(animated: true)

        // Slide in from edge
        let target = calculatePosition(at: 0, panelSize: panelSize)
        panel.setFrameOrigin(NSPoint(x: target.x + slideOffsetX, y: target.y))
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduceMotion ? 0.08 : 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(target)
            panel.animator().alphaValue = 1.0
        }

        // Auto-dismiss
        if let delay = item.autoDismissAfter {
            dismissTimers[item.id] = Task {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                dismiss(id: item.id)
            }
        }
    }

    func dismiss(id: UUID) {
        dismissTimers[id]?.cancel()
        dismissTimers.removeValue(forKey: id)

        guard let index = activePanels.firstIndex(where: { $0.id == id }) else { return }
        let panel = activePanels[index].panel

        // Remove from activePanels immediately so deduplication checks don't find stale entries
        activePanels.remove(at: index)
        repositionPanels(animated: true)

        let origin = panel.frame.origin
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = reduceMotion ? 0.06 : 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(NSPoint(x: origin.x + slideOffsetX, y: origin.y))
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })

        onDismiss?(id)
    }

    func dismissAll() {
        for entry in activePanels {
            dismiss(id: entry.id)
        }
    }

    /// Dismiss all notifications belonging to a specific session.
    func dismissForSession(_ sessionId: String) {
        let matching = activePanels.filter { $0.item.sessionId == sessionId }
        for entry in matching {
            dismiss(id: entry.id)
        }
    }

    var visibleCount: Int { activePanels.count }

    // MARK: - Private

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var panelWidth: CGFloat {
        switch preset {
        case .banner: return 320
        case .glass:  return 280
        case .card:   return 220
        default:      return 260
        }
    }

    private func createPanel(for item: NotificationItem) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelMinHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // Shadow handled by SwiftUI
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]

        panel.animationBehavior = .none

        let view = PopupContentView(
            item: item,
            onDismiss: { [weak self] in self?.dismiss(id: item.id) },
            onAction: { [weak self] action in self?.onAction?(action) },
            preset: preset
        )
        let hostingView = NSHostingView(rootView: view)
        // Use a generous initial frame so SwiftUI can calculate its natural size
        hostingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: 200)
        let fittingSize = hostingView.fittingSize
        let finalSize = NSSize(
            width: max(panelWidth, fittingSize.width),
            height: max(panelMinHeight, fittingSize.height)
        )
        panel.setContentSize(finalSize)
        hostingView.frame = NSRect(origin: .zero, size: finalSize)
        panel.contentView = hostingView
        return panel
    }

    private var popupPosition: String {
        UserDefaults.standard.string(forKey: "nudgy.popupPosition") ?? "topRight"
    }

    private func calculatePosition(at index: Int, panelSize: NSSize? = nil) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let visible = screen.visibleFrame
        let w = panelSize?.width ?? panelWidth
        let h = panelSize?.height ?? panelMinHeight
        let offset = CGFloat(index) * (h + stackGap)

        let x: CGFloat
        let y: CGFloat

        switch popupPosition {
        case "topLeft":
            x = visible.minX + edgePadding
            y = visible.maxY - h - edgePadding - offset
        case "bottomRight":
            x = visible.maxX - w - edgePadding
            y = visible.minY + edgePadding + offset
        case "bottomLeft":
            x = visible.minX + edgePadding
            y = visible.minY + edgePadding + offset
        default: // topRight
            x = visible.maxX - w - edgePadding
            y = visible.maxY - h - edgePadding - offset
        }
        return NSPoint(x: x, y: y)
    }

    private func repositionPanels(animated: Bool) {
        for (i, entry) in activePanels.enumerated() {
            let pos = calculatePosition(at: i, panelSize: entry.panel.frame.size)
            if animated && !reduceMotion {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.22
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    entry.panel.animator().setFrameOrigin(pos)
                }
            } else {
                entry.panel.setFrameOrigin(pos)
            }
        }
    }
}
