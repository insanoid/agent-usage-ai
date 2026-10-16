import Foundation

/// Somewhere a usage report comes from.
public protocol UsageSource: Sendable {
    func fetch() async throws -> UsageReport
}

/// Reads usage by running `agent-usage --json`, so the CLI and this app share
/// one implementation of the Keychain, HTTP and Codex calls. The app ships the
/// script in its bundle and runs it with the system Python that Xcode and the
/// Command Line Tools install.
public struct ScriptUsageSource: UsageSource {
    /// Codex's app-server call alone may take 25s per account.
    public static let timeout: Duration = .seconds(90)

    /// `defaults write <bundle id> scriptPath <path>` overrides the location.
    public static let scriptPathDefaultsKey = "scriptPath"

    public let scriptURL: URL
    /// The subscriptions file passed as `--config`; nil lets the script fall
    /// back to accounts.conf.
    public let configURL: URL?

    public init(scriptURL: URL = ScriptUsageSource.configuredScriptURL(), configURL: URL? = nil) {
        self.scriptURL = scriptURL
        self.configURL = configURL
    }

    /// The `scriptPath` override when set, else the copy in the app bundle.
    public static func configuredScriptURL(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) -> URL {
        if let path = defaults.string(forKey: scriptPathDefaultsKey), !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        return bundle.url(forResource: "agent-usage", withExtension: nil)
            ?? bundle.bundleURL.appending(path: "Contents/Resources/agent-usage")
    }

    public func fetch() async throws -> UsageReport {
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw UsageError.scriptMissing(path: scriptURL.path)
        }

        let output = try await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["python3", scriptURL.path, "--json"] + (configURL.map { ["--config", $0.path] } ?? []),
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
