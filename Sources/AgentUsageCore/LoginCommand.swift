import Foundation

/// Signs a subscription in by running its CLI's browser login with the
/// subscription's folder, as the user would in Terminal.
public enum LoginCommand {
    /// Browser sign-in waits for the user; give them time to finish it.
    public static let timeout: Duration = .seconds(600)

    /// The command line, for showing or copying when the in-app login fails.
    public static func shellCommand(for subscription: Subscription) -> String {
        let folder = subscription.dir
        switch subscription.provider {
        case .claude: return "CLAUDE_CONFIG_DIR=\(folder) claude auth login"
        case .codex: return "CODEX_HOME=\(folder) codex login"
        }
    }

    public static func run(_ subscription: Subscription) async throws {
        let folder = subscription.expandedDir
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)

        var environment = ScriptUsageSource.environment()
        let arguments: [String]
        switch subscription.provider {
        case .claude:
            environment["CLAUDE_CONFIG_DIR"] = folder
            arguments = ["claude", "auth", "login"]
        case .codex:
            environment["CODEX_HOME"] = folder
            arguments = ["codex", "login"]
        }

        let output = try await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: arguments,
            environment: environment,
            timeout: timeout
        )
        guard output.status == 0 else {
            let detail = String(bytes: output.stderr, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw LoginError(
                cli: arguments[0],
                status: output.status,
                detail: detail,
                command: shellCommand(for: subscription)
            )
        }
    }
}

public struct LoginError: LocalizedError, Equatable {
    /// "claude" or "codex".
    public let cli: String
    public let status: Int32
    public let detail: String
    /// What to run in Terminal instead.
    public let command: String

    public init(cli: String, status: Int32, detail: String, command: String) {
        self.cli = cli
        self.status = status
        self.detail = detail
        self.command = command
    }

    public var errorDescription: String? {
        // `env` exits 127 when the CLI is not on PATH.
        if status == 127 {
            return "\(cli) is not installed or not on PATH"
        }
        return detail.isEmpty ? "Login exited with status \(status)" : detail
    }
}
