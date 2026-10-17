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
    private static let logger = Logger(subsystem: Log.subsystem, category: "subscriptions")

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
        // A subscription being edited may keep its own name.
        let clash = subscriptions.contains {
            $0.id != candidate.id && $0.provider == candidate.provider && $0.slot == candidate.slot
        }
        return clash ? "There is already a \(candidate.provider.title) subscription called \(candidate.name)." : nil
    }

    func add(_ subscription: Subscription) {
        subscriptions.append(Self.trimmed(subscription))
        save()
    }

    /// Replaces the subscription with the same id.
    func update(_ subscription: Subscription) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else {
            lastError = "Could not save \(subscription.name): it is no longer in \(file.url.path)."
            return
        }
        subscriptions[index] = Self.trimmed(subscription)
        save()
    }

    /// Moves a subscription one place up (`-1`) or down (`1`) among its
    /// provider's, which is the order the panel and widget list them in.
    func move(_ subscription: Subscription, by offset: Int) {
        let siblings = subscriptions.indices.filter { subscriptions[$0].provider == subscription.provider }
        guard let place = siblings.firstIndex(where: { subscriptions[$0].id == subscription.id }),
              siblings.indices.contains(place + offset)
        else { return }
        subscriptions.swapAt(siblings[place], siblings[place + offset])
        save()
    }

    /// Reads the file again, to pick up edits made outside the app. Refreshes
    /// usage only when the subscriptions changed.
    func reload() {
        do {
            let loaded = try file.load()
            lastError = nil
            // Ids are not compared: entries written by hand carry none, and
            // get a fresh one on every load.
            guard loaded.map(Self.content) != subscriptions.map(Self.content) else { return }
            subscriptions = loaded
            onChange()
        } catch {
            report(error, doing: "read")
        }
    }

    func remove(_ subscription: Subscription) {
        subscriptions.removeAll { $0.id == subscription.id }
        save()
    }

    private static func trimmed(_ subscription: Subscription) -> Subscription {
        var trimmed = subscription
        trimmed.name = subscription.name.trimmingCharacters(in: .whitespaces)
        trimmed.dir = subscription.dir.trimmingCharacters(in: .whitespaces)
        return trimmed
    }

    private static func content(_ subscription: Subscription) -> [String] {
        [subscription.name, subscription.provider.rawValue, subscription.dir]
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
