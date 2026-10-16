import Foundation

/// The last good report, kept in the App Group container that the menu bar
/// app and its widget share. The widget is sandboxed and cannot run the
/// script, so this file is its only data source.
public struct ReportCache: Sendable {
    /// Info.plist key holding the App Group, set at build time from the
    /// signing team, so each builder's copy uses a group their team owns.
    public static let appGroupInfoKey = "AgentUsageAppGroup"

    /// Team-prefixed (`TEAMID.bundle-prefix.agent-usage`), which macOS accepts
    /// without a provisioning profile. Nil in a build without one.
    public static var appGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: appGroupInfoKey) as? String
    }

    private static let fileName = "report.json"

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The cache in the shared container, or nil when this build has no
    /// App Group (built without a signing team) or lacks the entitlement.
    public static func shared() -> ReportCache? {
        guard let appGroup, !appGroup.isEmpty else { return nil }
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            .map { ReportCache(fileURL: $0.appending(path: fileName)) }
    }

    public func save(_ report: UsageReport) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try report.encoded().write(to: fileURL, options: .atomic)
    }

    /// The cached report, or nil when nothing has been saved yet.
    public func load() throws -> UsageReport? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try UsageReport.decode(Data(contentsOf: fileURL))
    }
}
