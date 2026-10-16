import Foundation

/// One login to watch: a provider and the folder its profile lives in
/// (`CLAUDE_CONFIG_DIR` for Claude Code, `CODEX_HOME` for Codex). Holds no
/// credentials — those stay where each CLI keeps them.
public struct Subscription: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var provider: Agent
    /// May start with `~`; `expandedDir` resolves it.
    public var dir: String

    public init(id: UUID = UUID(), name: String, provider: Agent, dir: String) {
        self.id = id
        self.name = name
        self.provider = provider
        self.dir = dir
    }

    /// The account key the script derives from the name: "Work 2" → "work-2".
    /// Subscriptions with the same slot pair up as one account.
    public var slot: String {
        Self.slot(for: name)
    }

    public var expandedDir: String {
        (dir as NSString).expandingTildeInPath
    }

    /// Mirrors `account_slot` in bin/agent-usage; the two must agree.
    public static func slot(for name: String) -> String {
        var slot = ""
        var pendingDash = false
        for scalar in name.lowercased().unicodeScalars {
            if ("a" ... "z").contains(scalar) || ("0" ... "9").contains(scalar) {
                if pendingDash, !slot.isEmpty {
                    slot.append("-")
                }
                slot.unicodeScalars.append(scalar)
                pendingDash = false
            } else {
                pendingDash = true
            }
        }
        return slot.isEmpty ? "account" : slot
    }

    /// The folder each CLI uses when no variable points elsewhere.
    public static func defaultDir(for provider: Agent) -> String {
        switch provider {
        case .claude: "~/.claude"
        case .codex: "~/.codex"
        }
    }

    /// The sample file carries no ids; give each subscription one on load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        provider = try container.decode(Agent.self, forKey: .provider)
        dir = try container.decode(String.self, forKey: .dir)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, provider, dir
    }
}

/// The subscriptions file the app edits and passes to the script with `--config`.
public struct SubscriptionsFile: Sendable {
    public static let currentVersion = 1

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `~/Library/Application Support/AgentUsage/subscriptions.json`.
    public static func standard() -> SubscriptionsFile {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return SubscriptionsFile(url: support.appending(path: "AgentUsage/subscriptions.json"))
    }

    /// Copies `defaults` into place on first run, so the app starts with a
    /// working configuration. Does nothing once the file exists.
    public func installIfMissing(from defaults: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: defaults, to: url)
    }

    public func load() throws -> [Subscription] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode(Document.self, from: Data(contentsOf: url)).subscriptions
    }

    public func save(_ subscriptions: [Subscription]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let document = Document(version: Self.currentVersion, subscriptions: subscriptions)
        try encoder.encode(document).write(to: url, options: .atomic)
    }

    private struct Document: Codable {
        var version: Int?
        var subscriptions: [Subscription]
    }
}
