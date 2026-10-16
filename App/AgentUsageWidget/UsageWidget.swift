import AgentUsageCore
import AgentUsageUI
import os
import SwiftUI
import WidgetKit

@main
struct AgentUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        UsageWidget()
    }
}

struct UsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AgentUsage", provider: UsageProvider()) { entry in
            UsageWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Agent Usage")
        .description("Claude and Codex limits for every account, and when they reset.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct UsageEntry: TimelineEntry {
    let date: Date
    let report: UsageReport?
    /// Set when the cache exists but could not be read.
    let problem: String?
}

/// Reads the report the menu bar app cached. The app reloads the timeline
/// after each refresh; the entries in between only move the countdowns.
struct UsageProvider: TimelineProvider {
    private static let step: TimeInterval = 5 * 60
    private static let entryCount = 12
    private static let logger = Logger(subsystem: "com.karthikeyaudupa.agent-usage", category: "widget")

    func placeholder(in _: Context) -> UsageEntry {
        UsageEntry(date: Date(), report: .sample(), problem: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let (report, problem) = Self.loadCached()
        completion(UsageEntry(date: Date(), report: report ?? (context.isPreview ? .sample() : nil), problem: problem))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let now = Date()
        let (report, problem) = Self.loadCached()
        let entries = (0 ..< Self.entryCount).map { index in
            UsageEntry(date: now.addingTimeInterval(Double(index) * Self.step), report: report, problem: problem)
        }
        let end = now.addingTimeInterval(Double(Self.entryCount) * Self.step)
        completion(Timeline(entries: entries, policy: .after(end)))
    }

    private static func loadCached() -> (UsageReport?, String?) {
        guard let cache = ReportCache.shared() else {
            logger.error("no App Group container for \(ReportCache.appGroup, privacy: .public)")
            return (nil, "Widget cannot reach the app's data")
        }
        do {
            return try (cache.load(), nil)
        } catch {
            logger.error("cache read failed: \(error.localizedDescription, privacy: .public)")
            return (nil, "Could not read the last report")
        }
    }
}
