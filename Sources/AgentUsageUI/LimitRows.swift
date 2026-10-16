import AgentUsageCore
import SwiftUI

/// One aligned row per limit — label, bar, percent, time left — plus extra
/// usage. Fixed column widths keep every profile's bars under each other.
public struct LimitRows: View {
    public enum Density: Sendable {
        /// Panel and large widget: full labels and a time-left column.
        case regular
        /// Small widget: short labels, no time column.
        case compact
    }

    private let usage: AgentUsage
    private let now: Date
    private let density: Density
    private let rowGap: CGFloat
    /// Where clicking the free-reset row goes: the provider's usage page.
    private let resetsURL: URL?
    private let showsExtras: Bool

    private static let barHeight: CGFloat = 5
    /// Fits "100%" in SF Mono semibold.
    private static let percentWidth: CGFloat = 40
    private static let timeWidth: CGFloat = 54

    public init(
        usage: AgentUsage,
        now: Date,
        density: Density = .regular,
        rowGap: CGFloat = Spacing.sm,
        resetsURL: URL? = nil,
        showsExtras: Bool = true
    ) {
        self.usage = usage
        self.now = now
        self.density = density
        self.rowGap = rowGap
        self.resetsURL = resetsURL
        self.showsExtras = showsExtras
    }

    public var body: some View {
        // Plain rows with fixed side columns, not a Grid: a Grid sizes its
        // columns per profile, so bars would not line up across profiles.
        VStack(alignment: .leading, spacing: rowGap) {
            ForEach(usage.limits) { limit in
                HStack(spacing: Spacing.md) {
                    Text(density == .regular ? limit.rowLabel : limit.shortLabel)
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: labelWidth, alignment: .leading)
                    UsageBar(fraction: limit.percent / 100, tint: limit.level.tint, height: Self.barHeight)
                    Text(limit.percentText)
                        .font(Typography.value)
                        .foregroundStyle(limit.level.valueStyle)
                        .lineLimit(1)
                        .frame(width: Self.percentWidth, alignment: .trailing)
                    if density == .regular {
                        Text(limit.resetsAt.map { ResetFormat.countdown(to: $0, now: now) } ?? "")
                            .font(Typography.time)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .frame(width: Self.timeWidth, alignment: .trailing)
                            .help(limit.resetsAt.map { "Resets \(ResetFormat.clock($0, now: now))" } ?? "")
                    }
                }
            }
            if density == .regular, showsExtras, let spend = usage.spend?.displayText {
                HStack(spacing: Spacing.md) {
                    Text("Extra usage")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: Spacing.md)
                    Text(spend)
                        .font(Typography.money)
                }
            }
            if density == .regular, showsExtras, let count = usage.resetCredits, count > 0 {
                FreeResetRow(
                    count: count,
                    expiresAt: usage.resetCreditsExpireAt,
                    isUseful: isCapped,
                    destination: resetsURL
                )
            }
        }
    }

    /// A used-up limit is the moment a free reset is worth spending.
    private var isCapped: Bool {
        usage.limits.contains { $0.percent >= 100 }
    }

    /// Wide enough for "Fable weekly" in the regular density.
    private var labelWidth: CGFloat {
        density == .regular ? 86 : 40
    }
}

/// "Free reset          1 · use by 22 Oct". Quiet by default; in the accent
/// colour only while a limit is used up and the reset would help.
private struct FreeResetRow: View {
    let count: Int
    let expiresAt: Date?
    let isUseful: Bool
    /// The provider's usage page; the row opens it when clicked.
    let destination: URL?

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let destination {
            Button { openURL(destination) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: Spacing.md) {
            Text(count == 1 ? "Free reset" : "Free resets")
                .font(Typography.body)
                .foregroundStyle(.secondary)
            Spacer(minLength: Spacing.md)
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 9, weight: .semibold))
                Text("\(count)")
                    .font(Typography.time)
                if let expiresAt {
                    // The date is detail: neutral grey, a step lighter than the count.
                    // An explicit colour, as `.tertiary` would derive from the blue.
                    Text("· use by \(expiresAt.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(Typography.time)
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                }
            }
            .foregroundStyle(isUseful ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
        }
        .help(helpText)
        .accessibilityElement(children: .combine)
    }

    private var helpText: String {
        let expiry = expiresAt.map { " Use by \($0.formatted(date: .complete, time: .shortened))." } ?? ""
        let when = isUseful ? "A limit is used up, so now is when a reset helps." : "Keep it for when a limit runs out."
        let open = destination == nil ? "" : " Click to open the usage page."
        return "Resets a used-up limit to zero. \(when)\(expiry)\(open)"
    }
}
