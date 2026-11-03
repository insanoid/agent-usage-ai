import SwiftUI
import WidgetKit

@MainActor @Observable
final class UsageModel {
    var cache: CachedUsage?
    var error: String?
    var refreshing = false
    var configured = false
    var endpoint = ServerEndpoint.defaultURL
    var fixtureState: String?

    init() {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-usage-fixture"), arguments.indices.contains(index + 1) {
                fixtureState = arguments[index + 1]
                cache = fixtureState == "loading" ? nil : SampleUsage.cache(state: fixtureState!)
                refreshing = fixtureState == "loading"
                configured = true
                return
            }
        #endif
        reload()
    }

    func reload() {
        do {
            let store = try SharedStore.live()
            let settings = try store.settings()
            configured = settings != nil
            endpoint = settings?.endpoint ?? ServerEndpoint.defaultURL
            cache = try store.cached()
        } catch { self.error = UsageRepository.message(for: error) }
    }

    func refresh() async {
        guard fixtureState == nil, configured, !refreshing else { return }
        refreshing = true
        error = nil
        defer { refreshing = false }
        do {
            _ = try await UsageRepository(store: SharedStore.live()).refresh()
            WidgetCenter.shared.reloadAllTimelines()
        } catch { self.error = UsageRepository.message(for: error) }
        reload()
    }

    func configure(url: String, token: String) throws {
        let endpoint = try ServerEndpoint(url).baseURL.absoluteString
        let tokenStore = TokenStore()
        let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            guard try tokenStore.read(endpoint: endpoint) != nil else { throw APIError.missingToken }
        } else {
            _ = try UsageClient().request(endpoint: ServerEndpoint(endpoint), token: cleaned)
            try tokenStore.save(cleaned, endpoint: endpoint)
        }
        try SharedStore.live().configure(ServerSettings(endpoint: endpoint))
        error = nil
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

@main struct AgentUsageMobileApp: App {
    @State private var model = UsageModel()
    var body: some Scene {
        WindowGroup {
            #if DEBUG
                let args = ProcessInfo.processInfo.arguments
                if let index = args.firstIndex(of: "-widget-preview"), args.indices.contains(index + 1) {
                    WidgetPreview(size: args[index + 1], state: model.fixtureState ?? "success")
                } else {
                    UsageHome(model: model)
                }
            #else
                UsageHome(model: model)
            #endif
        }
    }
}

struct UsageHome: View {
    @Bindable var model: UsageModel
    @State private var settingsPresented = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    statusSection
                    if let cache = model.cache {
                        ForEach(UsageProvider.allCases, id: \.self) { provider in
                            Section {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(cache.snapshot.profiles(for: provider)) { profile in
                                        ProfileView(profile: profile).id(profile.id)
                                    }
                                }
                                .listRowInsets(EdgeInsets(
                                    top: 0, leading: Spacing.xl, bottom: 0, trailing: Spacing.xl
                                ))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color(.secondarySystemGroupedBackground))
                            } header: {
                                ProviderSectionHeader(provider: provider)
                            }
                            .listSectionSeparator(.hidden)
                        }
                        if cache.snapshot.accounts.isEmpty {
                            ContentUnavailableView(
                                "No profiles",
                                systemImage: "person.crop.circle.badge.questionmark",
                                description: Text("No subscriptions are configured on the server.")
                            )
                        }
                        let timestamp = cache.snapshot.generatedAt.formatted(date: .abbreviated, time: .shortened)
                        Text("Collected at \(timestamp)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .contentMargins(.top, Spacing.xs, for: .scrollContent)
                .onOpenURL { url in
                    guard url.scheme == "agentusage", url.host == "profile",
                          let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                          .first(where: { $0.name == "id" })?.value else { return }
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { settingsPresented = true }
                }
            }
            .refreshable { await model.refresh() }
            .sheet(isPresented: $settingsPresented) { SettingsView(model: model) }
            .task { await model.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await model.refresh() }
                }
            }
        }
    }

    private var connectionError: String? {
        if let error = model.error ?? model.cache?.failure {
            return error
        }
        if model.cache?.snapshot.collection.status == "failed" {
            return "Collection failed. Showing previously collected usage."
        }
        return nil
    }

    @ViewBuilder private var statusSection: some View {
        if !model.configured || model.cache == nil || connectionError != nil {
            Section {
                if let error = connectionError {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                if !model.configured {
                    ContentUnavailableView {
                        Label("Connect your server", systemImage: "server.rack")
                    } description: {
                        Text("Connect to Tailscale, then add your server URL and API token.")
                    } actions: {
                        Button("Open Settings") { settingsPresented = true }.buttonStyle(.borderedProminent)
                    }
                } else if model.cache == nil {
                    if model.refreshing {
                        ProgressView("Loading usage…")
                    } else if connectionError == nil {
                        Text("Usage is not available yet.").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
