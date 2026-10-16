import AgentUsageCore
import Foundation

public extension UsageReport {
    /// Plausible numbers for widget placeholders and the gallery preview.
    static func sample(now: Date = Date()) -> UsageReport {
        let hour: TimeInterval = 3600
        func limit(_ kind: String, _ label: String, _ percent: Double, _ hours: Double) -> Limit {
            Limit(kind: kind, label: label, percent: percent, resetsAt: now.addingTimeInterval(hours * hour))
        }
        return UsageReport(
            version: UsageReport.supportedVersion,
            generatedAt: now,
            accounts: [
                Account(
                    slot: "work",
                    label: "work",
                    claude: AgentUsage(limits: [
                        limit("session", "5-hour", 42, 3), limit("weekly_all", "Weekly", 78, 80),
                    ]),
                    codex: AgentUsage(limits: [limit("weekly_all", "Weekly", 14, 130)])
                ),
                Account(
                    slot: "personal",
                    label: "personal",
                    claude: AgentUsage(limits: [
                        limit("session", "5-hour", 9, 4), limit("weekly_all", "Weekly", 12, 30),
                    ]),
                    codex: AgentUsage(limits: [limit("weekly_all", "Weekly", 11, 130)])
                ),
            ]
        )
    }
}
