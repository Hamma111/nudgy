import Cocoa
import SwiftUI
import Combine

@MainActor
final class MenuBarManager {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?
    private let appState: AppState
    private let quotaManager: UsageQuotaManager?
    private var observation: Any?

    init(appState: AppState, quotaManager: UsageQuotaManager? = nil) {
        self.appState = appState
        self.quotaManager = quotaManager
        setupStatusItem()
        startObserving()
    }

    func updateIcon() {
        guard let button = statusItem.button else { return }

        let hasAttention = appState.pendingPermissionCount > 0
            || appState.highestPriorityState == .error
            || appState.highestPriorityState == .waitingInput

        let isActive = appState.highestPriorityState == .active
        let filled = isActive || hasAttention

        let icon = NudgyIcon.menuBarIcon(filled: filled, badge: hasAttention)

        if hasAttention {
            icon.isTemplate = false
            button.image = icon
            button.contentTintColor = NSColor(appState.iconColor)
        } else {
            icon.isTemplate = true
            button.image = icon
            button.contentTintColor = nil
        }

        let pending = appState.pendingPermissionCount
        button.title = pending > 0 ? " \(pending)" : ""
    }

    // MARK: - Private

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover)
        button.target = self

        let icon = NudgyIcon.menuBarIcon(filled: false)
        icon.isTemplate = true
        button.image = icon
    }

    private func startObserving() {
        observation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                withObservationTracking {
                    _ = self.appState.statusIcon
                    _ = self.appState.iconColor
                    _ = self.appState.pendingPermissionCount
                } onChange: {
                    Task { @MainActor [weak self] in
                        self?.updateIcon()
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    func openPopover() {
        if popover?.isShown != true {
            showPopover()
        }
    }

    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
            self.popover = nil
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 300)
        popover.behavior = .transient

        let hostingController = NSHostingController(
            rootView: MenuBarView(
                appState: appState,
                onFocusSession: { session in _ = WindowFocuser().focusSession(session) },
                quotaManager: quotaManager
            )
        )
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController

        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        self.popover = popover
    }
}
