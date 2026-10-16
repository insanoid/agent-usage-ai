import AgentUsageCore
import os
import SwiftUI
import WidgetKit

@main
struct AgentUsageApp: App {
    @State private var store: UsageStore
    @State private var subscriptions: SubscriptionsModel

    init() {
        LoginItem.refreshIfEnabled()
        let store = UsageStore(
            source: ScriptUsageSource(configURL: SubscriptionsFile.standard().url),
            cached: WidgetBridge.loadCached(),
            onReport: WidgetBridge.publish
        )
        _store = State(initialValue: store)
        // Installs the default configuration before the first refresh reads it.
        _subscriptions = State(initialValue: SubscriptionsModel {
            Task { await store.refresh() }
        })
    }

    var body: some Scene {
        MenuBarExtra {
            UsagePanel(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("Agent Usage", id: SettingsView.windowID) {
            SettingsView(model: subscriptions, store: store)
        }
        .windowResizability(.contentSize)
    }
}

/// Hands each fresh report to the widget through the shared App Group cache.
enum WidgetBridge {
    private static let logger = Logger(subsystem: Log.subsystem, category: "widget")

    /// The report saved by the last run, so a restart does not start blank.
    @MainActor
    static func loadCached() -> UsageReport? {
        guard let cache = ReportCache.shared() else { return nil }
        do {
            return try cache.load()
        } catch {
            logger.error("cached report unreadable, starting empty: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    @MainActor
    static func publish(_ report: UsageReport) {
        guard let cache = ReportCache.shared() else {
            logger.info("no App Group in this build; widget not updated")
            return
        }
        do {
            try cache.save(report)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            logger.error("widget cache write failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
