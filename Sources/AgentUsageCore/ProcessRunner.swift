import Foundation

/// Runs a child process to completion, collecting its output, with a deadline.
public enum ProcessRunner {
    public struct Output: Sendable {
        public let status: Int32
        public let stdout: Data
        public let stderr: Data
    }

    public static func run(
        executable: URL,
        arguments: [String],
        environment: [String: String],
        timeout: Duration
    ) async throws -> Output {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw UsageError.launchFailed(error.localizedDescription)
        }

        let child = ChildProcess(process)
        let watchdog = Task {
            try await Task.sleep(for: timeout)
            child.terminateForTimeout()
        }
        defer { watchdog.cancel() }

        // Drain both pipes at once: a child blocked on a full stderr pipe
        // would never close stdout. Cancelling the caller kills the child,
        // which closes the pipes and ends the reads.
        let (outData, errData, status) = await withTaskCancellationHandler {
            async let out = readToEnd(stdout.fileHandleForReading)
            async let err = readToEnd(stderr.fileHandleForReading)
            let (outData, errData) = await (out, err)
            return await (outData, errData, child.waitForExit())
        } onCancel: {
            child.terminate()
        }

        if child.timedOut {
            throw UsageError.timedOut(seconds: Int(timeout.components.seconds))
        }
        return Output(status: status, stdout: outData, stderr: errData)
    }

    /// The blocking read runs on a GCD thread: parking it on Swift's
    /// cooperative pool would hold one of its few threads for the whole run.
    private static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }
}

/// `Process` is not `Sendable`; this wrapper is the only place that touches it
/// after launch, and guards its own mutable state with a lock.
private final class ChildProcess: @unchecked Sendable {
    private let process: Process
    private let lock = NSLock()
    private var didTimeOut = false

    init(_ process: Process) {
        self.process = process
    }

    var timedOut: Bool {
        lock.withLock { didTimeOut }
    }

    func terminateForTimeout() {
        lock.withLock { didTimeOut = true }
        terminate()
    }

    func terminate() {
        if process.isRunning {
            process.terminate()
        }
    }

    /// Waits on a GCD thread, for the same reason as `readToEnd`.
    func waitForExit() async -> Int32 {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [process] in
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus)
            }
        }
    }
}
