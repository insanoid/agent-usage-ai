import AgentUsageCore
import SwiftUI

/// "Work  [Team · Max 5×]          ↺ 1 free reset · use by 22 Oct"
public struct ProfileHeader: View {
    private let name: String
    private let usage: AgentUsage
    private let showsResetChip: Bool

    public init(name: String, usage: AgentUsage, showsResetChip: Bool = true) {
        self.name = name
        self.usage = usage
        self.showsResetChip = showsResetChip
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(name)
                .font(Typography.profile)
                .lineLimit(1)
            if let plan = usage.plan {
                PlanPill(plan: plan, detail: usage.planDetail)
            }
            // A failed read on top of earlier numbers: flag it, keep the rows.
            if let note = usage.note, !usage.limits.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .help(note)
                    .accessibilityLabel(note)
            }
            Spacer(minLength: Spacing.sm)
            if showsResetChip, let count = usage.resetCredits, count > 0 {
                ResetChip(count: count, expiresAt: usage.resetCreditsExpireAt)
            }
        }
    }
}

public struct PlanPill: View {
    private let plan: String
    private let detail: String?

    public init(plan: String, detail: String?) {
        self.plan = plan
        self.detail = detail
    }

    public var body: some View {
        HStack(spacing: 3) {
            Text(plan)
            if let detail {
                Text("· \(detail)")
                    .opacity(0.75)
            }
        }
        .font(Typography.badge)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.primary.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
        )
    }
}

/// Free usage-limit resets, with the date they must be used by.
public struct ResetChip: View {
    private let count: Int
    private let expiresAt: Date?

    public init(count: Int, expiresAt: Date?) {
        self.count = count
        self.expiresAt = expiresAt
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 9, weight: .bold))
            Text(text)
        }
        .font(Typography.pill)
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(Color.accentColor)
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.vertical, 2)
        .background(Color.accentColor.opacity(0.16), in: Capsule())
        .help(helpText)
    }

    private var text: String {
        let resets = count == 1 ? "1 free reset" : "\(count) free resets"
        guard let expiresAt else { return resets }
        return "\(resets) · use by \(expiresAt.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private var helpText: String {
        guard let expiresAt else { return "Free resets of a used-up limit" }
        return "Use by \(expiresAt.formatted(date: .complete, time: .shortened))"
    }
}
