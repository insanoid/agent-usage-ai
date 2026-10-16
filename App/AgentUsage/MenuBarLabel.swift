import AgentUsageCore
import AgentUsageUI
import SwiftUI

/// The menu bar item: a robot. The numbers live in the panel.
struct MenuBarLabel: View {
    let store: UsageStore

    @Environment(\.openWindow) private var openWindow
    @State private var contextMenu: StatusItemMenu?
    @AppStorage(AlertPreferences.enabledKey) private var alertEnabled = true
    @AppStorage(AlertPreferences.colorKey) private var alertColorHex = AlertPreferences.defaultColorHex
    @AppStorage(AlertPreferences.previewKey) private var previewing = false

    var body: some View {
        icon
            // The label exists from launch, so polling and the right-click
            // menu start here rather than when the panel is first opened.
            .task {
                store.start()
                installContextMenu()
            }
    }

    private func installContextMenu() {
        guard contextMenu == nil else { return }
        let menu = StatusItemMenu(
            refresh: { Task { await store.refresh() } },
            openSettings: {
                openWindow(id: SettingsView.windowID)
                NSApp.activate()
            }
        )
        menu.install()
        contextMenu = menu
    }

    /// The alert colour while a Claude account runs on extra usage (or while
    /// Settings previews it); nil for the plain template icon.
    private var alertTint: NSColor? {
        let onExtraUsage = alertEnabled && !(store.report?.accountsOnExtraUsage.isEmpty ?? true)
        return previewing || onExtraUsage ? AlertPreferences.color(fromHex: alertColorHex) : nil
    }

    @ViewBuilder
    private var icon: some View {
        if store.report == nil, store.lastError != nil {
            Image(systemName: "exclamationmark.triangle")
        } else if let robot = AppGlyph.menuBarRobot(tint: alertTint) {
            Image(nsImage: robot)
                .renderingMode(alertTint == nil ? .template : .original)
        } else {
            // The robot SVG is missing from the bundle (logged); stay visible.
            Image(systemName: "cpu")
        }
    }
}
