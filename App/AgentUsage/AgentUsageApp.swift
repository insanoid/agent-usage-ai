import AgentUsageCore
import os
import SwiftUI
import WidgetKit

@main
struct AgentUsageApp: App {
    @State private var store = UsageStore(
        source: ScriptUsageSource(),
        cached: WidgetBridge.loadCached(),
        onReport: WidgetBridge.publish
    )

    var body: some Scene {
        MenuBarExtra {
            UsagePanel(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Hands each fresh report to the widget through the shared App Group cache.
enum WidgetBridge {
    private static let logger = Logger(subsystem: "com.karthikeyaudupa.agent-usage", category: "widget")

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
            logger.error("no App Group container for \(ReportCache.appGroup, privacy: .public); widget not updated")
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
