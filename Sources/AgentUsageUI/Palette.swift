import AgentUsageCore
import SwiftUI

public extension Severity {
    /// Bar fill.
    var tint: Color {
        switch self {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        }
    }

    /// Value text: plain until a limit is high, so colour means "look here".
    var valueStyle: AnyShapeStyle {
        switch self {
        case .normal: AnyShapeStyle(.primary)
        case .warning: AnyShapeStyle(Color.orange)
        case .critical: AnyShapeStyle(Color.red)
        }
    }
}

public extension Limit {
    var percentText: String {
        "\(Int(percent.rounded()))%"
    }

    /// "5-hour", "Weekly", "Fable weekly" — the script names every window,
    /// so the CLI and the app always agree.
    var rowLabel: String {
        label
    }

    /// "5h", "7d", "Fable" — for the narrow small widget.
    var shortLabel: String {
        if let scope {
            return scope
        }
        switch label {
        case "5-hour": return "5h"
        case "Weekly": return "7d"
        default: return label
        }
    }
}

public extension Spend {
    /// "$426 / $600", whole units with the narrow symbol so it stays short.
    var displayText: String? {
        guard enabled, let used else { return nil }
        let usedText = Self.money(used, currency: currency)
        guard let limit else { return usedText }
        return "\(usedText) / \(Self.money(limit, currency: currency))"
    }

    private static func money(_ amount: Double, currency: String?) -> String {
        let rounded = amount.rounded()
        guard let currency else { return rounded.formatted(.number.precision(.fractionLength(0))) }
        return rounded.formatted(.currency(code: currency).presentation(.narrow).precision(.fractionLength(0)))
    }
}
