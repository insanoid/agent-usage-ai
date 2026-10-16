import AgentUsageCore
import AgentUsageUI
import AppIntents
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
        AppIntentConfiguration(
            kind: "AgentUsage",
            intent: SelectProfilesIntent.self,
            provider: UsageProvider()
        ) { entry in
            UsageWidgetView(entry: entry)
                // Solid, not the translucent default: a see-through fill lets
                // the system rim show as a bright border on the desktop.
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Agent Usage")
        .description("Claude and Codex limits, and when they reset. Edit the widget to choose profiles.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// The widget's one setting: which profiles to show.
struct SelectProfilesIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose profiles"
    static let description = IntentDescription("Pick the profiles this widget shows. Leave it empty to show all.")

    @Parameter(title: "Profiles")
    var profiles: [ProfileEntity]?
}

/// A provider and account pair, such as Claude · Work.
struct ProfileEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Profile"
    static let defaultQuery = ProfileQuery()

    /// "claude/work", matching `UsageReport.filtered(to:)`.
    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

/// Offers the profiles in the app's last report.
struct ProfileQuery: EntityQuery {
    private static let logger = Logger(subsystem: "com.karthikeyaudupa.agent-usage", category: "widget")

    func entities(for identifiers: [ProfileEntity.ID]) async throws -> [ProfileEntity] {
        let wanted = Set(identifiers)
        return Self.all().filter { wanted.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ProfileEntity] {
        Self.all()
    }

    private static func all() -> [ProfileEntity] {
        let report: UsageReport?
        do {
            report = try ReportCache.shared()?.load()
        } catch {
            logger.error("profiles unavailable, cache unreadable: \(error.localizedDescription, privacy: .public)")
            return []
        }
        guard let report else { return [] }
        return Agent.allCases.flatMap { agent in
            report.usages(for: agent).map { entry in
                ProfileEntity(
                    id: UsageReport.profileID(agent: agent, slot: entry.account.slot),
                    title: "\(agent.title) · \(entry.account.displayName)"
                )
            }
        }
    }
}

struct UsageEntry: TimelineEntry {
    let date: Date
    let report: UsageReport?
    /// Set when the cache exists but could not be read.
    let problem: String?
}

/// Reads the report the menu bar app cached, narrowed to the chosen profiles.
/// The app reloads the timeline after each refresh; the entries in between
/// only move the countdowns.
struct UsageProvider: AppIntentTimelineProvider {
    private static let step: TimeInterval = 5 * 60
    private static let entryCount = 12
    private static let logger = Logger(subsystem: "com.karthikeyaudupa.agent-usage", category: "widget")

    func placeholder(in _: Context) -> UsageEntry {
        UsageEntry(date: Date(), report: .sample(), problem: nil)
    }

    func snapshot(for configuration: SelectProfilesIntent, in context: Context) async -> UsageEntry {
        let (report, problem) = Self.loadCached(for: configuration)
        return UsageEntry(date: Date(), report: report ?? (context.isPreview ? .sample() : nil), problem: problem)
    }

    func timeline(for configuration: SelectProfilesIntent, in _: Context) async -> Timeline<UsageEntry> {
        let now = Date()
        let (report, problem) = Self.loadCached(for: configuration)
        let entries = (0 ..< Self.entryCount).map { index in
            UsageEntry(date: now.addingTimeInterval(Double(index) * Self.step), report: report, problem: problem)
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(Double(Self.entryCount) * Self.step)))
    }

    private static func loadCached(for configuration: SelectProfilesIntent) -> (UsageReport?, String?) {
        guard let cache = ReportCache.shared() else {
            logger.error("no App Group container; widget has no data")
            return (nil, "Widget cannot reach the app's data")
        }
        do {
            let chosen = Set((configuration.profiles ?? []).map(\.id))
            return try (cache.load()?.filtered(to: chosen), nil)
        } catch {
            logger.error("cache read failed: \(error.localizedDescription, privacy: .public)")
            return (nil, "Could not read the last report")
        }
    }
}
