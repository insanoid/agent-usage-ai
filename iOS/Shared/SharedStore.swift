import Darwin
import Foundation
import os

struct ServerSettings: Codable, Equatable, Sendable { let endpoint: String }
struct CachedUsage: Codable, Sendable {
    let endpoint: String
    let snapshot: UsageSnapshot
    let fetchedAt: Date
    let failure: String?
}

struct SharedStore: Sendable {
    let directory: URL
    private static let logger = Logger(subsystem: "AgentUsageMobile", category: "cache")

    static func live() throws -> Self {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "UsageAppGroup") as? String,
              let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { throw APIError.sharedStorage }
        return Self(directory: directory.appendingPathComponent("Usage", isDirectory: true))
    }

    func settings() throws -> ServerSettings? {
        try locked { try read("settings.json") }
    }

    func configure(_ settings: ServerSettings) throws {
        _ = try ServerEndpoint(settings.endpoint)
        try locked {
            let previous: ServerSettings? = try read("settings.json")
            if previous != settings {
                try remove("usage.json")
                try write(settings, to: "settings.json")
            }
        }
    }

    func cached() throws -> CachedUsage? {
        try locked {
            let settings: ServerSettings? = try read("settings.json")
            let cache: CachedUsage? = try read("usage.json")
            return cache?.endpoint == settings?.endpoint ? cache : nil
        }
    }

    func save(_ cache: CachedUsage) throws {
        try locked {
            let settings: ServerSettings? = try read("settings.json")
            guard settings?.endpoint == cache.endpoint else { return }
            try write(cache, to: "usage.json")
        }
    }

    func recordFailure(_ message: String, endpoint: String) throws {
        try locked {
            let settings: ServerSettings? = try read("settings.json")
            guard settings?.endpoint == endpoint,
                  let cache: CachedUsage = try read("usage.json"), cache.endpoint == endpoint else { return }
            try write(CachedUsage(
                endpoint: endpoint,
                snapshot: cache.snapshot,
                fetchedAt: cache.fetchedAt,
                failure: message
            ), to: "usage.json")
        }
    }

    private func read<T: Decodable>(_ name: String) throws -> T? {
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: directory.appendingPathComponent(name)))
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        } catch is DecodingError {
            Self.logger.error("Quarantining malformed shared data: \(name, privacy: .public)")
            try remove(name + ".corrupt")
            try FileManager.default.moveItem(
                at: directory.appendingPathComponent(name),
                to: directory.appendingPathComponent(name + ".corrupt")
            )
            return nil
        }
    }

    private func write(_ value: some Encodable, to name: String) throws {
        let url = directory.appendingPathComponent(name)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        #if os(iOS)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        #endif
    }

    private func remove(_ name: String) throws {
        do {
            try FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        } catch CocoaError.fileNoSuchFile {
            return
        }
    }

    /// The app and widget run in separate processes. Serialize configuration and cache writes.
    private func locked<T>(_ operation: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let descriptor = open(directory.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }
}
