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

    static func color(fromHex hex: String) -> NSColor {
        var value: UInt64 = 0
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, Scanner(string: digits).scanHexInt64(&value) else {
            return color(fromHex: defaultColorHex)
        }
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    static func hex(from color: Color) -> String {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return defaultColorHex }
        let channel = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(
            format: "#%02X%02X%02X",
            channel(srgb.redComponent),
            channel(srgb.greenComponent),
            channel(srgb.blueComponent)
        )
    }
}
