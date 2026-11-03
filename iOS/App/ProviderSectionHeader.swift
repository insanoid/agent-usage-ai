import SwiftUI

struct ProviderSectionHeader: View {
    @ScaledMetric(relativeTo: .headline) private var logoSize = 22.0
    let provider: UsageProvider

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(provider == .claude ? "ClaudeLogo" : "CodexLogo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .accessibilityHidden(true)
            Text(provider.title)
                .font(.headline)
        }
        .foregroundStyle(.primary)
        .textCase(nil)
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
