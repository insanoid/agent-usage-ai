import Foundation

public enum UsageError: LocalizedError, Equatable {
    case scriptMissing(path: String)
    case launchFailed(String)
    case scriptFailed(status: Int32, message: String)
    case timedOut(seconds: Int)
    case unreadableOutput(String)
    case unsupportedVersion(Int)

    public var errorDescription: String? {
        switch self {
        case let .scriptMissing(path):
            "agent-usage not found at \(path)"
        case let .launchFailed(reason):
            "Could not start agent-usage: \(reason)"
        case let .scriptFailed(status, message):
            message.isEmpty ? "agent-usage exited with status \(status)" : message
        case let .timedOut(seconds):
            "agent-usage did not finish within \(seconds)s"
        case let .unreadableOutput(reason):
            "agent-usage printed output this app cannot read: \(reason)"
        case let .unsupportedVersion(version):
            "agent-usage report version \(version) is newer than this app supports"
        }
    }
}
