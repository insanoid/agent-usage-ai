import AgentUsageCore
import AgentUsageUI
import AppKit
import SwiftUI

/// Subscriptions: which provider folders to watch, and signing each one in.
struct SettingsView: View {
    static let windowID = "settings"
    private static let width: CGFloat = 540

    let model: SubscriptionsModel
    let store: UsageStore

    var body: some View {
        ScrollView {
            SettingsContent(model: model, store: store)
        }
        .frame(width: Self.width)
        .frame(minHeight: 420)
        // Pick up edits made to the file outside the app.
        .onAppear { model.reload() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.reload()
        }
    }
}

/// The settings page itself, separate from its scroll view so it can also be
/// rendered on its own.
struct SettingsContent: View {
    let model: SubscriptionsModel
    let store: UsageStore

    @State private var isAdding = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxl) {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold))

            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(Typography.secondary)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title: "General")
                LaunchAtLoginRow()
                Hairline()
                AppearanceRow()
                Hairline()
                ExtraUsageAlertRow()
                Hairline()
                FreeResetsRow(store: store)
                Hairline()
                HStack(alignment: .center, spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Quit Agent Usage")
                            .font(Typography.profile)
                        Text("Also on the menu bar icon: right-click it.")
                            .font(Typography.small)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Spacing.md)
                    Button("Quit…") { AppActions.confirmQuit() }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    SectionHeader(title: "Subscriptions")
                    Spacer()
                    Button("Open file", action: openFile)
                        .buttonStyle(.borderless)
                        .font(Typography.small)
                        .help("Open \((model.file.url.path as NSString).abbreviatingWithTildeInPath) in your editor. "
                            + "Changes show here when you come back.")
                }
                Text("Each subscription is a provider and the folder its login lives in. "
                    + "Subscriptions with the same name show together in the panel.")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Agent.allCases) { agent in
                ProviderList(agent: agent, model: model, store: store)
            }

            if isAdding {
                SubscriptionForm(
                    model: model,
                    draft: Subscription(name: "", provider: .claude, dir: Subscription.defaultDir(for: .claude)),
                    isNew: true,
                    isPresented: $isAdding
                )
            } else {
                Button {
                    isAdding = true
                } label: {
                    Label("Add subscription", systemImage: "plus")
                }
                .controlSize(.large)
            }
        }
        .padding(Spacing.xxl + Spacing.xs)
    }

    /// Opens the file in the app registered for JSON, or shows it in Finder
    /// when there is none.
    private func openFile() {
        let url = model.file.url
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

private struct ProviderList: View {
    let agent: Agent
    let model: SubscriptionsModel
    let store: UsageStore

    var body: some View {
        let subscriptions = model.subscriptions(for: agent)
        VStack(alignment: .leading, spacing: Spacing.md) {
            ProviderHeader(agent: agent)
            if subscriptions.isEmpty {
                Text("No \(agent.title) subscriptions.")
                    .font(Typography.secondary)
                    .foregroundStyle(.tertiary)
            }
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(subscriptions) { subscription in
                    if subscription.id != subscriptions.first?.id {
                        Hairline()
                    }
                    SubscriptionRow(
                        subscription: subscription,
                        model: model,
                        store: store,
                        position: subscriptions.firstIndex(of: subscription) ?? 0,
                        count: subscriptions.count
                    )
                }
            }
        }
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription
    let model: SubscriptionsModel
    let store: UsageStore
    /// Where the row sits among its provider's, for the move buttons.
    let position: Int
    let count: Int

    @State private var isLoggingIn = false
    @State private var loginError: LoginError?
    @State private var isEditing = false

    var body: some View {
        if isEditing {
            SubscriptionForm(model: model, draft: subscription, isNew: false, isPresented: $isEditing)
        } else {
            details
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.md) {
                if count > 1 {
                    MoveButtons(
                        canMoveUp: position > 0,
                        canMoveDown: position < count - 1
                    ) { offset in
                        model.move(subscription, by: offset)
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.sm) {
                        Text(subscription.name)
                            .font(Typography.profile)
                        status
                    }
                    Text(subscription.dir)
                        .font(Typography.time)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer(minLength: Spacing.md)
                Button {
                    logIn()
                } label: {
                    if isLoggingIn {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Log in")
                    }
                }
                .disabled(isLoggingIn)
                .help("Runs \(LoginCommand.shellCommand(for: subscription)); your browser opens to sign in.")
                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit the name or folder.")
                Button(role: .destructive) {
                    model.remove(subscription)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove this subscription. The folder and its login are left untouched.")
            }

            if let loginError {
                LoginFailure(error: loginError)
            }
        }
    }

    /// The plan when the last read worked, otherwise why it did not.
    @ViewBuilder
    private var status: some View {
        let usage = store.report?.accounts
            .first { $0.slot == subscription.slot }?
            .usage(for: subscription.provider)
        if let note = usage?.note, usage?.limits.isEmpty ?? true {
            Text(note)
                .font(Typography.small)
                .foregroundStyle(.orange)
                .lineLimit(1)
        } else if let plan = usage?.plan {
            PlanPill(plan: plan, detail: usage?.planDetail)
        }
    }

    private func logIn() {
        isLoggingIn = true
        loginError = nil
        Task {
            defer { isLoggingIn = false }
            do {
                try await LoginCommand.run(subscription)
                await store.refresh()
            } catch let error as LoginError {
                loginError = error
            } catch {
                loginError = LoginError(
                    cli: subscription.provider.rawValue,
                    status: -1,
                    detail: error.localizedDescription,
                    command: LoginCommand.shellCommand(for: subscription)
                )
            }
        }
    }
}

/// A stacked up/down pair that reorders a subscription within its provider.
private struct MoveButtons: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let move: (Int) -> Void

    private static let disabledOpacity = 0.3

    var body: some View {
        VStack(spacing: 0) {
            button("chevron.up", offset: -1, enabled: canMoveUp, help: "Move up in the panel")
            button("chevron.down", offset: 1, enabled: canMoveDown, help: "Move down in the panel")
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.secondary)
    }

    private func button(_ symbol: String, offset: Int, enabled: Bool, help: String) -> some View {
        Button {
            move(offset)
        } label: {
            Image(systemName: symbol)
                .frame(width: 14, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        // The explicit secondary style hides the usual disabled dimming.
        .opacity(enabled ? 1 : Self.disabledOpacity)
        .help(help)
    }
}

/// What went wrong, and the command to run in Terminal instead.
private struct LoginFailure: View {
    let error: LoginError

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                .font(Typography.small)
                .foregroundStyle(.orange)
                .textSelection(.enabled)
            HStack(spacing: Spacing.sm) {
                Text(error.command)
                    .font(Typography.time)
                    .textSelection(.enabled)
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(error.command, forType: .string)
                }
                .buttonStyle(.borderless)
                .font(Typography.small)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

/// A small-caps label over a settings group, like the panel's provider headers.
private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(Typography.section)
            .tracking(Typography.sectionTracking)
            .foregroundStyle(.secondary)
    }
}
