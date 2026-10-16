import AgentUsageCore
import SwiftUI

/// "Work  [Team · Max 5×]  ⚠︎" — free resets sit with the limit rows below.
public struct ProfileHeader: View {
    private let name: String
    private let usage: AgentUsage

    public init(name: String, usage: AgentUsage) {
        self.name = name
        self.usage = usage
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
