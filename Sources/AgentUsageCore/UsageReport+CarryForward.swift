import Foundation

public extension UsageReport {
    /// This report, with the last good numbers kept for any agent that failed
    /// to read this time (rate limited, offline). The failure note stays, so
    /// the panel says the numbers are older rather than going blank. A window
    /// that has reset since is dropped: its old percentage no longer means anything.
    func carryingForward(from previous: UsageReport?, now: Date = Date()) -> UsageReport {
        guard let previous else { return self }
        let earlier = Dictionary(previous.accounts.map { ($0.slot, $0) }, uniquingKeysWith: { first, _ in first })
        let merged = accounts.map { account -> Account in
            guard let before = earlier[account.slot] else { return account }
            return Account(
                slot: account.slot,
                label: account.label,
                claude: account.claude.map { Self.keep($0, else: before.claude, now: now) },
                codex: account.codex.map { Self.keep($0, else: before.codex, now: now) }
            )
        }
        return UsageReport(version: version, generatedAt: generatedAt, accounts: merged)
    }

    private static func keep(_ fresh: AgentUsage, else old: AgentUsage?, now: Date) -> AgentUsage {
        guard let note = fresh.note, fresh.limits.isEmpty, let old else { return fresh }
        let current = old.limits.filter { limit in limit.resetsAt.map { $0 > now } ?? true }
        guard !current.isEmpty else { return fresh }
        return AgentUsage(
            note: "\(note) — showing earlier numbers",
            limits: current,
            plan: old.plan,
            planDetail: old.planDetail,
            spend: old.spend,
            resetCredits: old.resetCredits,
            resetCreditsExpireAt: old.resetCreditsExpireAt
        )
    }
}
