import Foundation

/// Somewhere a usage report comes from.
public protocol UsageSource: Sendable {
    func fetch() async throws -> UsageReport
}

/// Reads usage by running `agent-usage --json`, so the CLI and this app share
/// one implementation of the Keychain, HTTP and Codex calls.
public struct ScriptUsageSource: UsageSource {
    /// Codex's app-server call alone may take 25s per account.
    public static let timeout: Duration = .seconds(90)

    /// `defaults write <bundle id> scriptPath <path>` overrides the location.
    public static let scriptPathDefaultsKey = "scriptPath"

    public let scriptURL: URL

    public init(scriptURL: URL = ScriptUsageSource.configuredScriptURL()) {
        self.scriptURL = scriptURL
    }

    public static func configuredScriptURL(defaults: UserDefaults = .standard) -> URL {
        if let path = defaults.string(forKey: scriptPathDefaultsKey), !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".agents/bin/agent-usage")
    }

    public func fetch() async throws -> UsageReport {
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw UsageError.scriptMissing(path: scriptURL.path)
        }

        let output = try await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["python3", scriptURL.path, "--json"],
            environment: Self.environment(),
            timeout: Self.timeout
        )

        guard output.status == 0 else {
            let message = (String(bytes: output.stderr, encoding: .utf8) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw UsageError.scriptFailed(status: output.status, message: message)
        }

        do {
            return try UsageReport.decode(output.stdout)
        } catch let error as UsageError {
            throw error
        } catch {
            throw UsageError.unreadableOutput(String(describing: error))
        }
    }

    /// An app launched from Finder or at login gets launchd's minimal PATH,
    /// which holds neither `codex` nor the user's own Python. Put the usual
    /// user tool directories in front of whatever PATH there is.
    public static func environment(
        base: [String: String] = ProcessInfo.processInfo.environment,
        home: String = NSHomeDirectory()
    ) -> [String: String] {
        let userPaths = [
            "\(home)/.local/bin",
            "\(home)/.local/share/mise/shims",
            "/opt/homebrew/bin",
            "/usr/local/bin",
        ]
        var env = base
        env["PATH"] = (userPaths + [base["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"])
            .joined(separator: ":")
        return env
    }
}
