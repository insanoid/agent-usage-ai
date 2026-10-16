/// The coding agents a report covers, in panel order.
public enum Agent: String, CaseIterable, Sendable, Identifiable {
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
    /// Every account with a login for `agent`, in configuration order.
    func usages(for agent: Agent) -> [AccountUsage] {
        accounts.compactMap { account in
            account.usage(for: agent).map { AccountUsage(account: account, usage: $0) }
        }
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
