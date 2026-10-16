import AgentUsageCore
import AgentUsageUI
import SwiftUI

/// The menu bar item: a robot. The numbers live in the panel.
struct MenuBarLabel: View {
    let store: UsageStore

    var body: some View {
        icon
            // The label exists from launch, so polling starts here rather
            // than when the panel is first opened.
            .task { store.start() }
    }

    @ViewBuilder
    private var icon: some View {
        if store.report == nil, store.lastError != nil {
            Image(systemName: "exclamationmark.triangle")
        } else if let robot = AppGlyph.menuBarRobot() {
            Image(nsImage: robot)
        } else {
            // The robot SVG is missing from the bundle (logged); stay visible.
            Image(systemName: "cpu")
        }
    }
}
