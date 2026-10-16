import AgentUsageCore
import SwiftUI

/// Every provider and its profiles: the body of the panel and the large widget.
public struct UsageOverview: View {
    private let report: UsageReport
    private let now: Date
    private let style: OverviewStyle

    public init(report: UsageReport, now: Date, style: OverviewStyle = .panel) {
        self.report = report
        self.now = now
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: style.providerGap) {
            ForEach(Agent.allCases) { agent in
                let entries = report.usages(for: agent)
                if !entries.isEmpty {
                    ProviderSection(agent: agent, entries: entries, now: now, style: style)
                }
            }
        }
    }
}

public struct ProviderHeader: View {
    private let agent: Agent

    public init(agent: Agent) {
        self.agent = agent
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            ProviderLogo(agent, size: 14)
            Text(agent.title.uppercased())
                .font(Typography.section)
                .tracking(Typography.sectionTracking)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ProviderSection: View {
    let agent: Agent
    let entries: [AccountUsage]
    let now: Date
    let style: OverviewStyle

    var body: some View {
        VStack(alignment: .leading, spacing: style.headerGap) {
            ProviderHeader(agent: agent)
            VStack(alignment: .leading, spacing: style.profileGap) {
                ForEach(entries) { entry in
                    if entry.id != entries.first?.id {
                        Hairline()
                    }
                    ProfileView(
                        agent: agent,
                        name: entry.account.displayName,
                        usage: entry.usage,
                        now: now,
                        style: style
                    )
                }
            }
        }
    }
}

private struct ProfileView: View {
    let agent: Agent
    let name: String
    let usage: AgentUsage
    let now: Date
    let style: OverviewStyle

    var body: some View {
        VStack(alignment: .leading, spacing: style.headerGap) {
            ProfileHeader(name: name, usage: usage)
            // With no numbers to show, the note is the profile's only content;
            // otherwise the header carries it as an icon.
            if let note = usage.note, usage.limits.isEmpty {
                Label(note, systemImage: "exclamationmark.triangle.fill")
                    .font(Typography.secondary)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
            if !usage.limits.isEmpty {
                LimitRows(
                    usage: usage,
                    now: now,
                    rowGap: style.rowGap,
                    resetsURL: agent.usageSettingsURL,
                    showsExtras: style.showsExtras
                )
            }
        }
    }
}
