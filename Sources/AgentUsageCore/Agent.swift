/// The coding agents a report covers, in panel order.
public enum Agent: String, CaseIterable, Codable, Sendable, Identifiable {
    case claude
    case codex

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }
}

/// One account's usage of one agent.
public struct AccountUsage: Sendable, Equatable, Identifiable {
    public let account: Account
    public let usage: AgentUsage

    public var id: String {
        account.slot
    }
}

public extension Account {
    func usage(for agent: Agent) -> AgentUsage? {
        switch agent {
        case .claude: claude
        case .codex: codex
        }
    }
}

public extension UsageReport {
    /// Every account with a login for `agent`, in that agent's configured
    /// order. Accounts the order does not name follow, in report order.
    func usages(for agent: Agent) -> [AccountUsage] {
        let entries = accounts.compactMap { account in
            account.usage(for: agent).map { AccountUsage(account: account, usage: $0) }
        }
        guard let slots = order?[agent.rawValue] else { return entries }
        let rank = Dictionary(slots.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return entries.enumerated()
            .sorted { lhs, rhs in
                (rank[lhs.element.account.slot] ?? slots.count + lhs.offset)
                    < (rank[rhs.element.account.slot] ?? slots.count + rhs.offset)
            }
            .map(\.element)
    }

    /// The highest account-wide limit across every account and agent.
    var peakPercent: Double? {
        accounts
            .flatMap { account in Agent.allCases.compactMap(account.usage(for:)) }
            .compactMap(\.peakLimit?.percent)
            .max()
    }
}

public extension AgentUsage {
    /// The account-wide limit closest to blocking this agent. A model-scoped
    /// limit (Fable) blocks only that model, so it does not count.
    var peakLimit: Limit? {
        limits.filter { $0.scope == nil }.max { $0.percent < $1.percent }
    }
}
