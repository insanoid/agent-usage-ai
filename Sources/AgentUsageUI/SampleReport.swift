import AgentUsageCore
import Foundation

public extension UsageReport {
    /// Made-up but realistic numbers: the widget placeholder, the gallery
    /// preview and the README screenshots. Never real account data.
    static func sample(now: Date = Date()) -> UsageReport {
        let hour: TimeInterval = 3600
        func limit(_ kind: String, _ label: String, _ percent: Double, hours: Double, scope: String? = nil) -> Limit {
            let resetsAt = now.addingTimeInterval(hours * hour)
            return Limit(kind: kind, label: label, scope: scope, percent: percent, resetsAt: resetsAt)
        }
        let resetsExpire = now.addingTimeInterval(6 * 24 * hour)
        return UsageReport(
            version: UsageReport.supportedVersion,
            generatedAt: now,
            accounts: [
                Account(
                    slot: "work",
                    label: "Work",
                    claude: AgentUsage(
                        limits: [
                            limit("session", "5-hour", 34, hours: 2.3),
                            limit("weekly_all", "Weekly", 82, hours: 76),
                            limit("weekly_scoped", "Fable weekly", 100, hours: 76, scope: "Fable"),
                        ],
                        plan: "Team",
                        planDetail: "Max 5×",
                        spend: Spend(used: 128, limit: 500, currency: "USD", percent: 26, enabled: true),
                        resetCredits: 1,
                        resetCreditsExpireAt: resetsExpire
                    ),
                    codex: AgentUsage(
                        limits: [limit("weekly_all", "Weekly", 27, hours: 130)],
                        plan: "Business",
                        planDetail: "Pro Lite"
                    )
                ),
                Account(
                    slot: "personal",
                    label: "Personal",
                    claude: AgentUsage(
                        limits: [
                            limit("session", "5-hour", 18, hours: 3.6),
                            limit("weekly_all", "Weekly", 41, hours: 29),
                        ],
                        plan: "Pro",
                        spend: Spend(used: 0, limit: 50, currency: "USD", percent: 0, enabled: false),
                        resetCredits: 1,
                        resetCreditsExpireAt: resetsExpire
                    ),
                    codex: AgentUsage(
                        limits: [limit("weekly_all", "Weekly", 12, hours: 130)],
                        plan: "Pro Lite"
                    )
                ),
            ]
        )
    }
}
