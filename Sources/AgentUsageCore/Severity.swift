/// How close a limit is to blocking work.
public enum Severity: String, Sendable, Comparable {
    case normal
    case warning
    case critical

    /// Thresholds for limits the API sends without a severity (Codex).
    public static let warningPercent = 75.0
    public static let criticalPercent = 90.0

    public init(percent: Double) {
        switch percent {
        case Self.criticalPercent...: self = .critical
        case Self.warningPercent...: self = .warning
        default: self = .normal
        }
    }

    private var rank: Int {
        switch self {
        case .normal: 0
        case .warning: 1
        case .critical: 2
        }
    }

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rank < rhs.rank
    }
}
