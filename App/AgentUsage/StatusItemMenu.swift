import AppKit
import os

/// The right-click menu on the menu bar icon. `MenuBarExtra` has no context
/// menu of its own, so right-clicks (and control-clicks) on the status item
/// are caught before they reach it and answered with this menu instead.
@MainActor
final class StatusItemMenu: NSObject {
    private let refresh: () -> Void
    private let openSettings: () -> Void
    private var monitor: Any?

    /// AppKit's private class for the window that hosts status items.
    private static let statusBarWindowClass = "NSStatusBarWindow"

    init(refresh: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.refresh = refresh
        self.openSettings = openSettings
        super.init()
    }

    func install() {
        guard monitor == nil else { return }
        // The monitor keeps this object alive for the app's lifetime, so the
        // menu cannot vanish if SwiftUI rebuilds the label that created it.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { event in
            guard Self.isContextClick(event), let view = event.window?.contentView else { return event }
            self.menu().popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.minY - 4), in: view)
            return nil // Swallowed: the panel stays closed.
        }
    }

    private static func isContextClick(_ event: NSEvent) -> Bool {
        guard event.window?.className == statusBarWindowClass else { return false }
        return event.type == .rightMouseDown || event.modifierFlags.contains(.control)
    }

    private func menu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("Refresh Now", key: "r", action: #selector(refreshNow)))
        menu.addItem(item("Settings…", key: ",", action: #selector(showSettings)))
        menu.addItem(.separator())
        menu.addItem(item("Quit Agent Usage…", key: "q", action: #selector(quit)))
        return menu
    }

    private func item(_ title: String, key: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func refreshNow() {
        refresh()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func quit() {
        AppActions.confirmQuit()
    }
}

enum AppActions {
    /// Asks before quitting: a menu bar app has no Dock icon to reopen it from.
    @MainActor
    static func confirmQuit() {
        let alert = NSAlert()
        alert.messageText = "Quit Agent Usage?"
        alert.informativeText = "The menu bar icon goes away and the widget stops updating "
            + "until you open the app again."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }
}
