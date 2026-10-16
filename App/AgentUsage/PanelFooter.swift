import AgentUsageCore
import AgentUsageUI
import ServiceManagement
import SwiftUI

struct PanelFooter: View {
    let store: UsageStore
    let now: Date

    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

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
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshing)
                .keyboardShortcut("r")
                .help("Refresh now")

                Spacer()

                Toggle("Open at login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .fixedSize()
                    .controlSize(.mini)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                Button {
                    openWindow(id: SettingsView.windowID)
                    // A menu bar app is never frontmost on its own.
                    NSApp.activate()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(",")
                .help("Subscriptions…")
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("q")
            }
            .font(Typography.small)
            .foregroundStyle(.secondary)

            if let loginError {
                Text(loginError)
                    .font(Typography.small)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
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

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        // Resetting the toggle after a failure fires onChange again; the
        // service already matches then, so there is nothing to do.
        guard enabled != (service.status == .enabled) else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            loginError = nil
        } catch {
            loginError = "Open at login: \(error.localizedDescription)"
            launchAtLogin = service.status == .enabled
        }
    }
}
