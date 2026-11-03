import SwiftUI

struct LimitView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .footnote) private var labelWidth = 86.0
    @ScaledMetric(relativeTo: .caption) private var valueWidth = 40.0
    @ScaledMetric(relativeTo: .caption2) private var timeWidth = 58.0
    let limit: UsageLimit

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        label
                        Spacer()
                        value
                    }
                    UsageMeter(percent: limit.percent, height: 5)
                    reset(at: context.date)
                }
            } else {
                HStack(spacing: Spacing.md) {
                    label.frame(width: labelWidth, alignment: .leading)
                    UsageMeter(percent: limit.percent, height: 5)
                    value.frame(width: valueWidth, alignment: .trailing)
                    reset(at: context.date).frame(width: timeWidth, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var label: some View {
        Text(limit.label).font(.footnote).foregroundStyle(.secondary)
    }

    private var value: some View {
        Text("\(limit.percent.formatted(.number.precision(.fractionLength(0))))%")
            .font(.system(.caption, design: .monospaced, weight: .semibold))
            .foregroundStyle(limit.percent >= 75 ? UsageStyle.tint(for: limit.percent) : .primary)
    }

    private func reset(at date: Date) -> some View {
        Text(limit.resetsAt.map { UsageStyle.resetText($0, at: date) } ?? "")
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
            .accessibilityLabel(limit.resetsAt.map { "Resets \($0.formatted())" } ?? "")
    }
}

struct ProfileView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let profile: UsageProfile

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let note = profile.usage.note {
                    Label(note, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.orange)
                }
                ForEach(profile.usage.limits) { LimitView(limit: $0) }
                if let spend = profile.usage.spend {
                    spendView(spend)
                }
                if let count = profile.usage.resetCredits, count > 0 {
                    resetCredits(count)
                }
                if profile.usage.limits.isEmpty, profile.usage.note == nil {
                    Text("No limits reported").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Spacing.md)
    }

    private var header: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.sm))
        return layout {
            Text(profile.account.label).font(.subheadline.weight(.semibold))
            if let plan = profile.usage.plan {
                Text([plan, profile.usage.planDetail].compactMap(\.self).joined(separator: " · "))
                    .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    @ViewBuilder private func spendView(_ spend: UsageSpend) -> some View {
        if spend.enabled, let used = spend.used {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
                : AnyLayout(HStackLayout(spacing: Spacing.md))
            layout {
                Text("Extra usage").font(.footnote).foregroundStyle(.secondary)
                if !typeSize.isAccessibilitySize {
                    Spacer(minLength: Spacing.md)
                }
                Text(spendText(used: used, spend: spend))
                    .font(.system(.caption, design: .monospaced, weight: .medium))
            }
        }
    }

    private func resetCredits(_ count: Int) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Spacing.md))
        return layout {
            Text(count == 1 ? "Free reset" : "Free resets").font(.footnote).foregroundStyle(.secondary)
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: Spacing.md)
            }
            HStack(spacing: Spacing.xs) {
                Text("\(count)")
                if let expiry = profile.usage.resetCreditsExpireAt {
                    Text("· use by \(expiry.formatted(.dateTime.day().month(.abbreviated)))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(.caption, design: .monospaced))
        }
        .accessibilityElement(children: .combine)
    }

    private func spendText(used: Double, spend: UsageSpend) -> String {
        func money(_ amount: Double) -> String {
            guard let currency = spend.currency else {
                return amount.rounded().formatted(.number.precision(.fractionLength(0)))
            }
            return amount.rounded().formatted(.currency(code: currency).presentation(.narrow)
                .precision(.fractionLength(0)))
        }
        guard let cap = spend.limit else { return money(used) }
        return "\(money(used)) / \(money(cap))"
    }
}
