import Foundation

/// The document `agent-usage --json` prints.
public struct UsageReport: Codable, Sendable, Equatable {
    /// The schema version this app understands. A report with a newer version
    /// is rejected rather than half-read.
    public static let supportedVersion = 1

    public let version: Int
    public let generatedAt: Date
    public let accounts: [Account]
    /// Each agent's account slots in the order to list them, keyed by
    /// `Agent.rawValue`. Nil, or an agent missing, keeps `accounts` order.
    public let order: [String: [String]]?

    public init(version: Int, generatedAt: Date, accounts: [Account], order: [String: [String]]? = nil) {
        self.version = version
        self.generatedAt = generatedAt
        self.accounts = accounts
        self.order = order
    }

    /// Reads the script's output, or a report this app cached with `encoded()`.
    public static func decode(_ data: Data) throws -> UsageReport {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(UsageReport.self, from: data)
        guard report.version <= supportedVersion else {
            throw UsageError.unsupportedVersion(report.version)
        }
        return report
    }

    /// The same JSON shape the script prints, so `decode` reads it back.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

/// One configured account, which may hold a Claude and a Codex login.
public struct Account: Codable, Sendable, Equatable, Identifiable {
    public let slot: String
    public let label: String
    /// Nil for an account with only a Codex subscription.
    public let claude: AgentUsage?
    public let codex: AgentUsage?

    public var id: String {
        slot
    }

    public init(slot: String, label: String, claude: AgentUsage?, codex: AgentUsage?) {
        self.slot = slot
        self.label = label
        self.claude = claude
        self.codex = codex
    }
}

/// One agent's usage on one account. `note` is set, and `limits` is empty,
/// when the numbers could not be read — a stale token, a network failure.
public struct AgentUsage: Codable, Sendable, Equatable {
    public let note: String?
    public let limits: [Limit]
    /// The subscription, e.g. "Team" or "Pro Lite".
    public let plan: String?
    /// A qualifier for `plan`, e.g. "Max 5×" on a Team seat.
    public let planDetail: String?
    public let spend: Spend?
    /// Free resets of a used-up window the account can redeem. Only Codex
    /// reports these; nil means the agent does not say.
    public let resetCredits: Int?
    /// When the soonest-expiring free reset lapses; nil when none expire.
    public let resetCreditsExpireAt: Date?

    public init(
        note: String? = nil,
        limits: [Limit] = [],
        plan: String? = nil,
        planDetail: String? = nil,
        spend: Spend? = nil,
        resetCredits: Int? = nil,
        resetCreditsExpireAt: Date? = nil
    ) {
        self.note = note
        self.limits = limits
        self.plan = plan
        self.planDetail = planDetail
        self.spend = spend
        self.resetCredits = resetCredits
        self.resetCreditsExpireAt = resetCreditsExpireAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        limits = try container.decodeIfPresent([Limit].self, forKey: .limits) ?? []
        plan = try container.decodeIfPresent(String.self, forKey: .plan)
        planDetail = try container.decodeIfPresent(String.self, forKey: .planDetail)
        spend = try container.decodeIfPresent(Spend.self, forKey: .spend)
        resetCredits = try container.decodeIfPresent(Int.self, forKey: .resetCredits)
        resetCreditsExpireAt = try container.decodeIfPresent(Date.self, forKey: .resetCreditsExpireAt)
    }

    private enum CodingKeys: String, CodingKey {
        case note, limits, plan, planDetail, spend, resetCredits, resetCreditsExpireAt
    }
}

/// A usage window: the 5-hour session, the weekly cap, or a weekly cap scoped
/// to one model such as Fable.
public struct Limit: Codable, Sendable, Equatable, Identifiable {
    public let kind: String
    public let label: String
    public let scope: String?
    public let percent: Double
    public let resetsAt: Date?
    private let severity: String?

    /// Kind and label together: two model-scoped limits share a kind.
    public var id: String {
        "\(kind)|\(label)"
    }

    /// The API's own severity when it sends one; otherwise derived from `percent`.
    public var level: Severity {
        severity.flatMap(Severity.init(rawValue:)) ?? Severity(percent: percent)
    }

    public init(
        kind: String,
        label: String,
        scope: String? = nil,
        percent: Double,
        severity: String? = nil,
        resetsAt: Date? = nil
    ) {
        self.kind = kind
        self.label = label
        self.scope = scope
        self.percent = percent
        self.severity = severity
        self.resetsAt = resetsAt
    }
}

/// Extra-usage credits spent against the monthly cap.
public struct Spend: Codable, Sendable, Equatable {
    public let used: Double?
    public let limit: Double?
    public let currency: String?
    public let percent: Double?
    public let enabled: Bool
    public let disabledReason: String?

    public init(
        used: Double?,
        limit: Double?,
        currency: String?,
        percent: Double?,
        enabled: Bool,
        disabledReason: String? = nil
    ) {
        self.used = used
        self.limit = limit
        self.currency = currency
        self.percent = percent
        self.enabled = enabled
        self.disabledReason = disabledReason
    }
}
