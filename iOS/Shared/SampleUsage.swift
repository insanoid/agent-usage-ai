import Foundation

/// Fictional values for WidgetKit gallery previews and simulator inspection.
enum SampleUsage {
    static func cache(state: String = "success") -> CachedUsage {
        let now = Date()
        let collected = state == "stale" ? now.addingTimeInterval(-3600) : now.addingTimeInterval(-90)
        return CachedUsage(
            endpoint: ServerEndpoint.defaultURL,
            snapshot: UsageSnapshot(
                version: 1,
                generatedAt: collected,
                accounts: accounts(now: now, longLabels: state == "long-labels"),
                order: nil,
                collection: CollectionState(
                    ageSeconds: now.timeIntervalSince(collected),
                    stale: state == "stale",
                    status: "ok"
                )
            ),
            fetchedAt: now,
            failure: state == "offline" ?
                "Cannot reach the server. Check Tailscale and your connection." : nil
        )
    }

    private static func accounts(now: Date, longLabels: Bool) -> [UsageAccount] {
        let work = UsageAccount(
            slot: "work",
            label: longLabels ? "Prosperity engineering team" : "Work",
            claude: ProviderUsage(
                note: nil,
                limits: limits(34, 82, now: now),
                plan: "Team",
                planDetail: "Max 5×",
                spend: UsageSpend(
                    used: 128,
                    limit: 500,
                    currency: "USD",
                    enabled: true,
                    disabledReason: nil
                )
            ),
            codex: ProviderUsage(
                note: nil,
                limits: limits(16, 27, now: now),
                plan: "Business",
                planDetail: nil,
                spend: nil,
                resetCredits: 2,
                resetCreditsExpireAt: now.addingTimeInterval(7 * 24 * 60 * 60)
            )
        )
        let personal = UsageAccount(
            slot: "personal",
            label: "Personal",
            claude: ProviderUsage(
                note: "No access token. Sign in on the server.",
                limits: [],
                plan: nil,
                planDetail: nil,
                spend: nil
            ),
            codex: ProviderUsage(
                note: nil,
                limits: limits(12, 41, now: now),
                plan: "Pro",
                planDetail: nil,
                spend: UsageSpend(
                    used: nil, limit: nil, currency: "USD", enabled: false, disabledReason: "Out of credits"
                ),
                resetCredits: 2,
                resetCreditsExpireAt: now.addingTimeInterval(7 * 24 * 60 * 60)
            )
        )
        return [work, personal]
    }

    private static func limits(_ session: Double, _ weekly: Double, now: Date) -> [UsageLimit] {
        [
            UsageLimit(
                kind: "session",
                label: "5-hour",
                scope: nil,
                percent: session,
                resetsAt: now.addingTimeInterval(7200)
            ),
            UsageLimit(
                kind: "weekly_all",
                label: "Weekly",
                scope: nil,
                percent: weekly,
                resetsAt: now.addingTimeInterval(172_800)
            ),
        ]
    }
}
