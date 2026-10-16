@testable import AgentUsageCore
import Foundation
import Testing

struct ScriptUsageSourceTests {
    @Test func environmentPutsUserToolsFirst() {
        let env = ScriptUsageSource.environment(base: ["PATH": "/usr/bin:/bin", "HOME": "/h"], home: "/h")
        let path = env["PATH"]?.split(separator: ":").map(String.init) ?? []
        #expect(path.first == "/h/.local/bin")
        #expect(path.suffix(2) == ["/usr/bin", "/bin"])
        #expect(env["HOME"] == "/h")
    }

    @Test func missingScriptIsReported() async {
        let source = ScriptUsageSource(scriptURL: URL(fileURLWithPath: "/nonexistent/agent-usage"))
        await #expect(throws: UsageError.scriptMissing(path: "/nonexistent/agent-usage")) {
            try await source.fetch()
        }
    }

    @Test func scriptFailureCarriesStderr() async throws {
        let script = try temporaryScript("import sys; sys.stderr.write('no accounts configured\\n'); sys.exit(1)")
        await #expect(throws: UsageError.scriptFailed(status: 1, message: "no accounts configured")) {
            try await ScriptUsageSource(scriptURL: script).fetch()
        }
    }

    @Test func garbageOutputIsUnreadable() async throws {
        let script = try temporaryScript("print('not json')")
        await #expect {
            try await ScriptUsageSource(scriptURL: script).fetch()
        } throws: { error in
            if case .unreadableOutput = error as? UsageError {
                return true
            }
            return false
        }
    }

    private func temporaryScript(_ body: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "agent-usage-test-\(UUID().uuidString).py")
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

struct ProcessRunnerTests {
    @Test func collectsOutputAndStatus() async throws {
        let output = try await ProcessRunner.run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "echo out; echo err >&2; exit 3"],
            environment: [:],
            timeout: .seconds(5)
        )
        #expect(String(bytes: output.stdout, encoding: .utf8) == "out\n")
        #expect(String(bytes: output.stderr, encoding: .utf8) == "err\n")
        #expect(output.status == 3)
    }

    @Test func killsAProcessPastItsDeadline() async {
        await #expect(throws: UsageError.timedOut(seconds: 1)) {
            try await ProcessRunner.run(
                executable: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["30"],
                environment: [:],
                timeout: .seconds(1)
            )
        }
    }
}

/// Runs the repo's bin/agent-usage with the sample configuration, which reads
/// real credentials and calls the network. Opt in with `AGENT_USAGE_LIVE=1 swift test`.
struct LiveScriptTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["AGENT_USAGE_LIVE"] == "1"))
    func decodesRealOutput() async throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = try await ScriptUsageSource(
            scriptURL: root.appending(path: "bin/agent-usage"),
            configURL: root.appending(path: "config/subscriptions.json")
        ).fetch()
        #expect(!report.accounts.isEmpty)
    }
}
