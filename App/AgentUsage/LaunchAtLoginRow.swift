import AgentUsageUI
import ServiceManagement
import SwiftUI

/// The "Open at login" switch, backed by the system's login items.
struct LaunchAtLoginRow: View {
    @State private var isOn = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Open at login")
                        .font(Typography.profile)
                    Text("Start Agent Usage when you log in, so the menu bar and widget stay current.")
                        .font(Typography.small)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Spacing.md)
                Toggle("Open at login", isOn: $isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: isOn) { _, enabled in
                        apply(enabled)
                    }
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(Typography.small)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
        }
    }

    private func apply(_ enabled: Bool) {
        let service = SMAppService.mainApp
        // Resetting the switch after a failure fires onChange again; the
        // service already matches then, so there is nothing to do.
        guard enabled != (service.status == .enabled) else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            error = nil
        } catch {
            self.error = "Could not change login items: \(error.localizedDescription)"
            isOn = service.status == .enabled
        }
    }
}
