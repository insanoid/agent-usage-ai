public extension AgentUsage {
    /// Running on extra usage: a limit is used up and extra usage is switched
    /// on, so further use is billed against the extra-usage credit. A model
    /// limit counts too — past Fable's weekly cap, Fable is billed as extra.
    var isOnExtraUsage: Bool {
        guard spend?.enabled == true else { return false }
        return limits.contains { $0.percent >= 100 }
    }
}

public extension UsageReport {
    /// The Claude profiles currently running on extra usage.
    var accountsOnExtraUsage: [Account] {
        accounts.filter { $0.claude?.isOnExtraUsage == true }
    }
}
