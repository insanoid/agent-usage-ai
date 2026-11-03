import SwiftUI

enum UsageStyle {
    static func tint(for percent: Double) -> Color {
        percent >= 90 ? .red : percent >= 75 ? .orange : .blue
    }

    static func resetText(_ reset: Date, at date: Date) -> String {
        guard reset > date else { return "Reset passed" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: max(60, reset.timeIntervalSince(date))) ?? "< 1m"
    }
}

struct UsageMeter: View {
    let percent: Double
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(.primary.opacity(0.08))
                .overlay(alignment: .leading) {
                    Capsule().fill(UsageStyle.tint(for: percent))
                        .frame(width: geometry.size.width * min(max(percent / 100, 0), 1))
                }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
