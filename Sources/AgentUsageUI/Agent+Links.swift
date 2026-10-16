import AgentUsageCore
import Foundation

public extension Agent {
    /// The provider's own usage page, where limits and resets live.
    var usageSettingsURL: URL {
        switch self {
        case .claude: URL(string: "https://claude.ai/settings/usage")!
        case .codex: URL(string: "https://chatgpt.com/codex/settings/usage")!
        }
    }
}
