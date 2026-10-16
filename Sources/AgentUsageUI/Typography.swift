import SwiftUI

/// Type and spacing for every surface — panel and widgets — so they read as
/// one design. Words are SF Pro; numbers (percent, time, money) are SF Mono,
/// a size smaller, so they line up in columns and recede behind the labels.
public enum Typography {
    public static let profile = Font.system(size: 14, weight: .semibold)
    public static let body = Font.system(size: 13)
    public static let value = Font.system(size: 12, weight: .semibold, design: .monospaced)
    public static let money = Font.system(size: 11.5, weight: .medium, design: .monospaced)
    public static let time = Font.system(size: 11, design: .monospaced)
    public static let secondary = Font.system(size: 12)
    public static let small = Font.system(size: 11.5)
    public static let pill = Font.system(size: 11, weight: .medium)
    /// The plan badge: smaller than its neighbours, so it labels without competing.
    public static let badge = Font.system(size: 10, weight: .semibold)
    public static let section = Font.system(size: 11, weight: .semibold)
    /// Section labels are set in capitals with a little extra tracking.
    public static let sectionTracking: CGFloat = 0.7
}

/// Vertical rhythm of the provider/profile layout. The panel breathes; the
/// large widget has a fixed height, so it packs the same layout tighter.
public struct OverviewStyle: Sendable {
    public let providerGap: CGFloat
    public let profileGap: CGFloat
    public let headerGap: CGFloat
    public let rowGap: CGFloat

    public static let panel = OverviewStyle(providerGap: 20, profileGap: 12, headerGap: 10, rowGap: 7)
    public static let dense = OverviewStyle(providerGap: 12, profileGap: 8, headerGap: 6, rowGap: 4)
}

/// A 4-point spacing scale.
public enum Spacing {
    public static let hairline: CGFloat = 1
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 7
    public static let md: CGFloat = 10
    public static let lg: CGFloat = 12
    public static let xl: CGFloat = 16
    public static let xxl: CGFloat = 20
}
