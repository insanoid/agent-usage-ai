import AgentUsageCore
import os
import ServiceManagement

enum LoginItem {
    private static let logger = Logger(subsystem: Log.subsystem, category: "login-item")

    /// Re-registers the login item when it is on, so it follows the app after
    /// an install moves it (for example from ~/Applications to /Applications).
    static func refreshIfEnabled() {
        let service = SMAppService.mainApp
        guard service.status == .enabled else { return }
        do {
            try service.register()
        } catch {
            logger.error("login item refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
