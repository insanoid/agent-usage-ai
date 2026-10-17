import AgentUsageUI
import AppKit
import SwiftUI

/// Light, dark, or whatever the system uses, for the panel and Settings.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let defaultsKey = "appearance"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// `nil` hands the choice back to the system.
    private var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// The stored choice, or `.system` when nothing valid is stored.
    static var stored: AppearancePreference {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(Self.init(rawValue:)) ?? .system
    }

    /// Sets the appearance for every window the app owns, the menu bar panel included.
    @MainActor
    func apply() {
        // `NSApp` is still nil while `App.init` runs; `shared` creates it.
        NSApplication.shared.appearance = appearance
    }
}

struct AppearanceRow: View {
    @AppStorage(AppearancePreference.defaultsKey) private var preference = AppearancePreference.system

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Appearance")
                    .font(Typography.profile)
                Text("For the panel and this window. The widget follows the system.")
                    .font(Typography.small)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Spacing.md)
            Picker("Appearance", selection: $preference) {
                ForEach(AppearancePreference.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .onChange(of: preference) { _, new in
                new.apply()
            }
        }
    }
}
