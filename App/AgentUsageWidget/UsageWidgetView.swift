import AgentUsageCore
import AgentUsageUI
import SwiftUI
import WidgetKit

struct UsageWidgetView: View {
    let entry: UsageEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        UsageWidgetContent(entry: entry, family: family)
    }
}

/// The widget's layout with the family passed in, so it renders outside
/// WidgetKit too.
struct UsageWidgetContent: View {
    let entry: UsageEntry
    let family: WidgetFamily

    var body: some View {
        if let report = entry.report {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                switch family {
                case .systemSmall:
                    SmallProfile(report: report, now: entry.date)
                case .systemMedium:
                    // Captions go first, then the columns, as profiles are added.
                    ViewThatFits(in: .vertical) {
                        ProviderColumns(report: report, now: entry.date, showsCaptions: true)
                        ProviderColumns(report: report, now: entry.date, showsCaptions: false)
                        ProfileLines(report: report, now: entry.date)
                    }
                    // Centred: two profiles per provider leave spare height.
                    .frame(maxHeight: .infinity)
                default:
                    // More profiles than the large widget holds fall back to
                    // one line each rather than clipping.
                    ViewThatFits(in: .vertical) {
                        UsageOverview(report: report, now: entry.date, style: .dense)
                        ProfileLines(report: report, now: entry.date, maxLines: WidgetMetrics.largeLines)
                    }
                }
                Spacer(minLength: 0)
                StaleNote(generatedAt: report.generatedAt, now: entry.date)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            EmptyState(problem: entry.problem)
        }
    }
}

private enum WidgetMetrics {
    static let logo: CGFloat = 13
    static let nameWidth: CGFloat = 64
    static let tagWidth: CGFloat = 34
    static let percentWidth: CGFloat = 36
    static let timeWidth: CGFloat = 50
    static let mediumLines = 5
    static let largeLines = 12
    /// Older data than this is flagged; the app refreshes every five minutes.
    static let staleAfter: TimeInterval = 30 * 60
}

private struct WidgetProfile: Identifiable {
    let agent: Agent
    let entry: AccountUsage

    /// A slot such as "work" appears once per provider, so the id needs both.
    var id: String {
        "\(agent.rawValue)/\(entry.id)"
    }
}

/// Every profile across providers, the most-used first.
private func profilesByUsage(_ report: UsageReport) -> [WidgetProfile] {
    Agent.allCases
        .flatMap { agent in report.usages(for: agent).map { WidgetProfile(agent: agent, entry: $0) } }
        .sorted { ($0.entry.usage.peakLimit?.percent ?? 0) > ($1.entry.usage.peakLimit?.percent ?? 0) }
}

/// Small: the profile closest to a limit, with all its limits.
private struct SmallProfile: View {
    let report: UsageReport
    let now: Date

    var body: some View {
        if let top = profilesByUsage(report).first {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    ProviderLogo(top.agent, size: WidgetMetrics.logo)
                    Text(top.entry.account.displayName)
                        .font(Typography.profile)
                        .lineLimit(1)
                }
                if let plan = top.entry.usage.plan {
                    PlanPill(plan: plan, detail: top.entry.usage.planDetail)
                }
                LimitRows(usage: top.entry.usage, now: now, density: .compact)
                if let peak = top.entry.usage.peakLimit, let resetsAt = peak.resetsAt {
                    Text("\(peak.rowLabel) resets in \(ResetFormat.countdown(to: resetsAt, now: now))")
                        .font(Typography.small)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// Medium: a column per provider, its profiles stacked — the panel's
/// grouping at widget size.
private struct ProviderColumns: View {
    let report: UsageReport
    let now: Date
    let showsCaptions: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xxl) {
            ForEach(Agent.allCases) { agent in
                let entries = report.usages(for: agent)
                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: showsCaptions ? Spacing.md : Spacing.sm) {
                        ProviderHeader(agent: agent)
                        ForEach(entries) { entry in
                            ProfileMeter(
                                name: entry.account.displayName,
                                usage: entry.usage,
                                now: now,
                                showsCaption: showsCaptions
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// "Work            94%", a bar, then "Weekly · 3d 12h".
private struct ProfileMeter: View {
    let name: String
    let usage: AgentUsage
    let now: Date
    let showsCaption: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(name)
                    .font(Typography.body.weight(.semibold))
                    .lineLimit(1)
                if usage.note != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
                Spacer(minLength: Spacing.xs)
                if let limit = usage.peakLimit {
                    Text(limit.percentText)
                        .font(Typography.value)
                        .foregroundStyle(limit.level.valueStyle)
                }
            }
            if let limit = usage.peakLimit {
                UsageBar(fraction: limit.percent / 100, tint: limit.level.tint, height: 5)
                if showsCaption {
                    caption(for: limit)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(usage.note ?? "No limits reported")
                    .font(Typography.small)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
    }

    /// "Weekly · 3d 12h": the label in SF Pro, the time in SF Mono.
    private func caption(for limit: Limit) -> Text {
        let label = Text(limit.rowLabel).font(Typography.small)
        guard let resetsAt = limit.resetsAt else { return label }
        return label
            + Text(" · ").font(Typography.small)
            + Text(ResetFormat.countdown(to: resetsAt, now: now)).font(Typography.time)
    }
}

/// Medium fallback: one line per profile — its most-used limit and time left.
private struct ProfileLines: View {
    let report: UsageReport
    let now: Date
    var maxLines = WidgetMetrics.mediumLines

    var body: some View {
        let profiles = Agent.allCases.flatMap { agent in
            report.usages(for: agent).map { WidgetProfile(agent: agent, entry: $0) }
        }
        let shown = profiles.prefix(maxLines)
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(Array(shown)) { profile in
                ProfileLine(
                    agent: profile.agent,
                    name: profile.entry.account.displayName,
                    usage: profile.entry.usage,
                    now: now
                )
            }
            if profiles.count > shown.count {
                Text("+\(profiles.count - shown.count) more")
                    .font(Typography.small)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct ProfileLine: View {
    let agent: Agent
    let name: String
    let usage: AgentUsage
    let now: Date

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ProviderLogo(agent, size: WidgetMetrics.logo)
            Text(name)
                .font(Typography.body.weight(.medium))
                .lineLimit(1)
                .frame(width: WidgetMetrics.nameWidth, alignment: .leading)
            if let limit = usage.peakLimit {
                Text(limit.shortLabel)
                    .font(Typography.secondary)
                    .foregroundStyle(.tertiary)
                    .frame(width: WidgetMetrics.tagWidth, alignment: .leading)
                UsageBar(fraction: limit.percent / 100, tint: limit.level.tint, height: 5)
                Text(limit.percentText)
                    .font(Typography.value)
                    .foregroundStyle(limit.level.valueStyle)
                    .frame(width: WidgetMetrics.percentWidth, alignment: .trailing)
                Text(limit.resetsAt.map { ResetFormat.countdown(to: $0, now: now) } ?? "")
                    .font(Typography.time)
                    .foregroundStyle(.tertiary)
                    .frame(width: WidgetMetrics.timeWidth, alignment: .trailing)
            } else {
                Text(usage.note ?? "No limits reported")
                    .font(Typography.secondary)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
    }
}

private struct StaleNote: View {
    let generatedAt: Date
    let now: Date

    var body: some View {
        if now.timeIntervalSince(generatedAt) > WidgetMetrics.staleAfter {
            Text("Updated \(ResetFormat.countdown(to: now, now: generatedAt)) ago")
                .font(Typography.small)
                .foregroundStyle(.orange)
        }
    }
}

private struct EmptyState: View {
    let problem: String?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(problem ?? "Open Agent Usage to load your limits")
                .font(Typography.secondary)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
