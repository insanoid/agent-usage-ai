import Foundation

struct ServerEndpoint: Equatable, Sendable {
    static let defaultURL = "https://karthik-hetzner.tail9bd7eb.ts.net/agent-usage"
    let baseURL: URL
    var usageURL: URL {
        baseURL.appendingPathComponent("v1/usage")
    }

    init(_ value: String) throws {
        guard let parts = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme?.lowercased() == "https", let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              let url = parts.url else { throw APIError.invalidEndpoint }
        baseURL = url.hasDirectoryPath ? url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent) : url
    }
}

enum APIError: LocalizedError {
    case invalidEndpoint, missingToken, unauthorized, unavailable, invalidReport, http(Int), sharedStorage,
         keychain(OSStatus)
    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "Enter an HTTPS server URL without credentials, a query, or a fragment."
        case .missingToken: "Add the API token in Settings."
        case .unauthorized: "The API token was rejected. Update it in Settings."
        case .unavailable: "The server has no usage snapshot yet. Try again shortly."
        case .invalidReport: "The server returned an unsupported usage report."
        case let .http(status): "The server returned HTTP \(status)."
        case .sharedStorage: "Shared storage is unavailable. Check App Group signing."
        case let .keychain(status): "Keychain access failed (\(status)). Check signing and unlock the device."
        }
    }
}

struct UsageSnapshot: Codable, Sendable {
    static let staleInterval: TimeInterval = 600
    let version: Int
    let generatedAt: Date
    let accounts: [UsageAccount]
    let order: [String: [String]]?
    let collection: CollectionState

    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: value) {
                return date
            }
            formatter.formatOptions.insert(.withFractionalSeconds)
            guard let date = formatter.date(from: value) else { throw APIError.invalidReport }
            return date
        }
        let snapshot = try decoder.decode(Self.self, from: data)
        guard snapshot.version == 1 else { throw APIError.invalidReport }
        return snapshot
    }

    func isStale(at date: Date) -> Bool {
        collection.stale || collection.status == "failed" || collection.ageSeconds > Self.staleInterval
            || date.timeIntervalSince(generatedAt) > Self.staleInterval
    }

    func profiles(for provider: UsageProvider) -> [UsageProfile] {
        let slots = order?[provider.rawValue] ?? []
        return accounts.compactMap { account in
            account.usage(for: provider).map { UsageProfile(account: account, provider: provider, usage: $0) }
        }.sorted { left, right in
            (slots.firstIndex(of: left.account.slot) ?? Int.max) < (slots.firstIndex(of: right.account.slot) ?? Int.max)
        }
    }
}

enum UsageProvider: String, Codable, CaseIterable, Sendable {
    case claude, codex
    var title: String {
        self == .claude ? "Claude" : "Codex"
    }
}

struct UsageProfile: Identifiable, Sendable {
    let account: UsageAccount
    let provider: UsageProvider
    let usage: ProviderUsage
    var id: String {
        "\(provider.rawValue):\(account.slot)"
    }

    var title: String {
        "\(provider.title) · \(account.label)"
    }

    var link: URL {
        var components = URLComponents()
        components.scheme = "agentusage"
        components.host = "profile"
        components.queryItems = [URLQueryItem(name: "id", value: id)]
        return components.url!
    }
}

struct UsageAccount: Codable, Sendable {
    let slot: String
    let label: String
    let claude: ProviderUsage?
    let codex: ProviderUsage?
    func usage(for provider: UsageProvider) -> ProviderUsage? {
        provider == .claude ? claude : codex
    }
}

struct ProviderUsage: Codable, Sendable {
    let note: String?
    let limits: [UsageLimit]
    let plan: String?
    let planDetail: String?
    let spend: UsageSpend?
    let resetCredits: Int?
    let resetCreditsExpireAt: Date?

    init(
        note: String?, limits: [UsageLimit], plan: String?, planDetail: String?, spend: UsageSpend?,
        resetCredits: Int? = nil, resetCreditsExpireAt: Date? = nil
    ) {
        self.note = note
        self.limits = limits
        self.plan = plan
        self.planDetail = planDetail
        self.spend = spend
        self.resetCredits = resetCredits
        self.resetCreditsExpireAt = resetCreditsExpireAt
    }

    var summaryLimits: [UsageLimit] {
        limits.filter { $0.kind == "session" || $0.kind == "weekly_all" }
    }
}

struct UsageLimit: Codable, Identifiable, Sendable {
    let kind: String
    let label: String
    let scope: String?
    let percent: Double
    let resetsAt: Date?
    var id: String {
        "\(kind):\(label)"
    }
}

struct UsageSpend: Codable, Sendable {
    let used: Double?
    let limit: Double?
    let currency: String?
    let enabled: Bool
    let disabledReason: String?
}

struct CollectionState: Codable, Sendable {
    let ageSeconds: Double
    let stale: Bool
    let status: String
}

extension ProviderUsage {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        note = try values.decodeIfPresent(String.self, forKey: .note)
        limits = try values.decodeIfPresent([UsageLimit].self, forKey: .limits) ?? []
        plan = try values.decodeIfPresent(String.self, forKey: .plan)
        planDetail = try values.decodeIfPresent(String.self, forKey: .planDetail)
        spend = try values.decodeIfPresent(UsageSpend.self, forKey: .spend)
        resetCredits = try values.decodeIfPresent(Int.self, forKey: .resetCredits)
        resetCreditsExpireAt = try values.decodeIfPresent(Date.self, forKey: .resetCreditsExpireAt)
    }
}
