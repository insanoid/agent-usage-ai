import AgentUsageUI
import SwiftUI

/// Settings for tinting the menu bar icon while extra usage is in use.
struct ExtraUsageAlertRow: View {
    @AppStorage(AlertPreferences.enabledKey) private var enabled = true
    @AppStorage(AlertPreferences.colorKey) private var colorHex = AlertPreferences.defaultColorHex
    @AppStorage(AlertPreferences.previewKey) private var previewing = false

    private static let previewSize: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Extra usage alert")
                        .font(Typography.profile)
                    Text("Tint the menu bar icon while a Claude account is past a limit "
                        + "and its use is billed as extra usage.")
                        .font(Typography.small)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.md)
                Toggle("Extra usage alert", isOn: $enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            HStack(spacing: Spacing.md) {
                ColorPicker("Colour", selection: color, supportsOpacity: false)
                    .font(Typography.body)
                Button("Default") { colorHex = AlertPreferences.defaultColorHex }
                    .disabled(colorHex == AlertPreferences.defaultColorHex)
                Spacer(minLength: Spacing.md)
                robotPreview
                Button(previewing ? "Previewing…" : "Preview in menu bar", action: preview)
                    .disabled(previewing)
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }

    /// The icon as it will look, plain and tinted, side by side.
    private var robotPreview: some View {
        HStack(spacing: Spacing.sm) {
            if let plain = AppGlyph.menuBarRobot() {
                Image(nsImage: plain)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: Self.previewSize, height: Self.previewSize)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
            if let tinted = AppGlyph.menuBarRobot(tint: AlertPreferences.color(fromHex: colorHex)) {
                Image(nsImage: tinted)
                    .resizable()
                    .frame(width: Self.previewSize, height: Self.previewSize)
            }
        }
        .accessibilityLabel("Icon preview")
    }

    private var color: Binding<Color> {
        Binding(
            get: { Color(nsColor: AlertPreferences.color(fromHex: colorHex)) },
            set: { colorHex = AlertPreferences.hex(from: $0) }
        )
    }

    private func preview() {
        previewing = true
        Task {
            // Cancelled or not, the preview ends: never leave the icon tinted.
            defer { previewing = false }
            try await Task.sleep(for: AlertPreferences.previewDuration)
        }
    }
}
