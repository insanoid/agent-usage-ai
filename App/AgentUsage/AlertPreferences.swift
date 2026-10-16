import AgentUsageUI
import AppKit
import SwiftUI

/// Settings for tinting the menu bar icon while a Claude account runs on
/// extra usage. Stored in UserDefaults, so every view sees changes at once.
enum AlertPreferences {
    static let enabledKey = "extraUsageAlertEnabled"
    static let colorKey = "extraUsageAlertColor"
    /// Set for a few seconds by Settings' preview button.
    static let previewKey = "extraUsageAlertPreviewing"

    /// The system orange, as sRGB hex.
    static let defaultColorHex = "#FF9500"
    static let previewDuration: Duration = .seconds(4)

    /// The stored colour, or the default when the stored value is not a colour.
    static func color(fromHex hex: String) -> NSColor {
        HexColor.color(hex) ?? HexColor.color(defaultColorHex) ?? .systemOrange
    }

    static func hex(from color: Color) -> String {
        HexColor.hex(NSColor(color)) ?? defaultColorHex
    }
}
