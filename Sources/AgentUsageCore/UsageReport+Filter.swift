public extension UsageReport {
    /// Only the profiles in `ids` ("claude/work", "codex/personal"); every
    /// profile when `ids` is empty. Accounts left with nothing are dropped.
    func filtered(to ids: Set<String>) -> UsageReport {
        guard !ids.isEmpty else { return self }
        let kept = accounts.compactMap { account -> Account? in
            let claude = ids.contains(Self.profileID(agent: .claude, slot: account.slot)) ? account.claude : nil
            let codex = ids.contains(Self.profileID(agent: .codex, slot: account.slot)) ? account.codex : nil
            guard claude != nil || codex != nil else { return nil }
            return Account(slot: account.slot, label: account.label, claude: claude, codex: codex)
        }
        return UsageReport(version: version, generatedAt: generatedAt, accounts: kept, order: order)
    }

    static func profileID(agent: Agent, slot: String) -> String {
        "\(agent.rawValue)/\(slot)"
    }
}
