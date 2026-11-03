import AppIntents
import SwiftUI
import WidgetKit

struct ProfileEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Usage profile"
    static let defaultQuery = ProfileQuery()
    let id: String
    let title: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct ProfileQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ProfileEntity] {
        let profiles = try await suggestedEntities()
        return identifiers.map { identifier in
            profiles.first(where: { $0.id == identifier }) ?? ProfileEntity(id: identifier, title: "Removed profile")
        }
    }

    func suggestedEntities() async throws -> [ProfileEntity] {
        guard let snapshot = try SharedStore.live().cached()?.snapshot else { return [] }
        return UsageProvider.allCases.flatMap { snapshot.profiles(for: $0) }
            .map { ProfileEntity(id: $0.id, title: $0.title) }
    }
}

struct ProfileConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Usage profiles"
    static let description =
        IntentDescription("Choose one profile for a small widget, or up to two for a medium widget.")
    @Parameter(title: "First profile") var first: ProfileEntity?
    @Parameter(title: "Second profile (medium)") var second: ProfileEntity?
}

struct UsageEntry: TimelineEntry {
    let date: Date
    let cache: CachedUsage?
    let selections: [WidgetSelection]
    let error: String?
    let configured: Bool
}

struct UsageTimeline: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> UsageEntry {
        sample()
    }

    func snapshot(for configuration: ProfileConfiguration, in context: Context) async -> UsageEntry {
        if context.isPreview {
            return sample()
        }
        return await entry(configuration: configuration, fetch: false)
    }

    func timeline(for configuration: ProfileConfiguration, in _: Context) async -> Timeline<UsageEntry> {
        let entry = await entry(configuration: configuration, fetch: true)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
    }

    private func entry(configuration: ProfileConfiguration, fetch: Bool) async -> UsageEntry {
        var cache: CachedUsage?
        var failure: String?
        var configured = false
        do {
            let store = try SharedStore.live()
            configured = try store.settings() != nil
            cache = try store.cached()
            if fetch, configured {
                do {
                    _ = try await UsageRepository(store: store).refresh()
                } catch {
                    failure = UsageRepository.message(for: error)
                }
                cache = try store.cached()
            }
        } catch { failure = UsageRepository.message(for: error) }
        let available = cache.map { value in UsageProvider.allCases.flatMap { value.snapshot.profiles(for: $0) } } ?? []
        var selected = [configuration.first, configuration.second].compactMap(\.self)
            .map { WidgetSelection(id: $0.id, title: $0.title) }
        if selected.isEmpty {
            selected = available.prefix(2).map { WidgetSelection(id: $0.id, title: $0.title) }
        }
        if selected.count == 2, selected[0].id == selected[1].id {
            selected.removeLast()
        }
        return UsageEntry(date: .now, cache: cache, selections: selected, error: failure, configured: configured)
    }

    private func sample() -> UsageEntry {
        UsageEntry(date: .now, cache: SampleUsage.cache(), selections: [
            WidgetSelection(id: "claude:work", title: "Claude · Work"),
            WidgetSelection(id: "codex:work", title: "Codex · Work"),
        ], error: nil, configured: true)
    }
}

struct UsageWidgetView: View {
    let entry: UsageEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        WidgetContent(
            cache: entry.cache,
            selections: entry.selections,
            isMedium: family == .systemMedium,
            error: entry.error,
            configured: entry.configured
        )
        .containerBackground(Color(.secondarySystemGroupedBackground), for: .widget)
    }
}

@main struct AgentUsageMobileWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "AgentUsageMobile",
            intent: ProfileConfiguration.self,
            provider: UsageTimeline()
        ) { entry in
            UsageWidgetView(entry: entry)
        }
        .configurationDisplayName("Agent Usage")
        .description("Claude and Codex usage from your private server.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
