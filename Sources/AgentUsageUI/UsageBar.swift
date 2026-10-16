import SwiftUI

/// A thin horizontal meter.
public struct UsageBar: View {
    private let fraction: Double
    private let tint: Color
    private let height: CGFloat

    public init(fraction: Double, tint: Color, height: CGFloat = 4) {
        self.fraction = min(max(fraction, 0), 1)
        self.tint = tint
        self.height = height
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, geometry.size.width * fraction))
                    .opacity(fraction > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}
