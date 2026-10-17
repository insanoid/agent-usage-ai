import AgentUsageCore
import AgentUsageUI
import SwiftUI

struct PanelFooter: View {
    let store: UsageStore
    let now: Date

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Hairline()
            HStack(spacing: Spacing.md) {
                Button {
                    Task { await store.refresh() }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if store.isRefreshing {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(updatedText)
                    }
                    .font(Typography.status)
                    .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshing)
                .keyboardShortcut("r")
                .help("Refresh now")

                Spacer()

                Button {
                    openWindow(id: SettingsView.windowID)
                    // A menu bar app is never frontmost on its own.
                    NSApp.activate()
                    // Close the panel on the next turn: dismissing tears this
                    // view down, and a window request still pending is dropped.
                    DispatchQueue.main.async { dismiss() }
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(",")
                .help("Settings… (right-click the menu bar icon to quit)")
            }
            .font(Typography.small)
            .foregroundStyle(.secondary)
        }
    }

    private var updatedText: String {
        guard let lastSuccess = store.lastSuccess else {
            return store.isRefreshing ? "Loading…" : "Not loaded yet"
        }
        if now.timeIntervalSince(lastSuccess) < 60 {
            return "Updated just now"
        }
        return "Updated \(ResetFormat.countdown(to: now, now: lastSuccess)) ago"
    }
}
