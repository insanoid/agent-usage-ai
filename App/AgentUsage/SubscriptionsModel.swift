import AgentUsageCore
import Foundation
import Observation
import os

/// The editable list of subscriptions, saved to the file the script reads.
@MainActor
@Observable
final class SubscriptionsModel {
    private(set) var subscriptions: [Subscription] = []
    /// Set when the file could not be read or written.
    private(set) var lastError: String?

    let file: SubscriptionsFile
    private let onChange: @MainActor () -> Void
    private static let logger = Logger(subsystem: "com.karthikeyaudupa.agent-usage", category: "subscriptions")

    /// Installs the bundled default configuration on first run, then loads.
    init(file: SubscriptionsFile = .standard(), onChange: @escaping @MainActor () -> Void = {}) {
        self.file = file
        self.onChange = onChange
        do {
            if let defaults = Bundle.main.url(forResource: "subscriptions", withExtension: "json") {
                try file.installIfMissing(from: defaults)
            }
            subscriptions = try file.load()
        } catch {
            report(error, doing: "load")
        }
    }

    func subscriptions(for provider: Agent) -> [Subscription] {
        subscriptions.filter { $0.provider == provider }
    }

    /// Why `candidate` cannot be added, or nil when it can.
    func problem(with candidate: Subscription) -> String? {
        if candidate.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Give it a name."
        }
        if candidate.dir.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Choose its folder."
        }
        let clash = subscriptions.contains { $0.provider == candidate.provider && $0.slot == candidate.slot }
        return clash ? "There is already a \(candidate.provider.title) subscription called \(candidate.name)." : nil
    }

    func add(_ subscription: Subscription) {
        var trimmed = subscription
        trimmed.name = subscription.name.trimmingCharacters(in: .whitespaces)
        trimmed.dir = subscription.dir.trimmingCharacters(in: .whitespaces)
        subscriptions.append(trimmed)
        save()
    }

    func remove(_ subscription: Subscription) {
        subscriptions.removeAll { $0.id == subscription.id }
        save()
    }

    private func save() {
        do {
            try file.save(subscriptions)
            lastError = nil
            onChange()
        } catch {
            report(error, doing: "save")
        }
    }

    private func report(_ error: Error, doing action: String) {
        let message = "Could not \(action) \(file.url.path): \(error.localizedDescription)"
        lastError = message
        Self.logger.error("\(message, privacy: .public)")
    }
}
