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
                ExtraUsageAlertRow()
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
                SectionHeader(title: "Subscriptions")
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
                AddSubscriptionForm(model: model, isPresented: $isAdding)
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
                    SubscriptionRow(subscription: subscription, model: model, store: store)
                }
            }
        }
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription
    let model: SubscriptionsModel
    let store: UsageStore

    @State private var isLoggingIn = false
    @State private var loginError: LoginError?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.md) {
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

private struct AddSubscriptionForm: View {
    let model: SubscriptionsModel
    @Binding var isPresented: Bool

    @State private var draft = Subscription(name: "", provider: .claude, dir: Subscription.defaultDir(for: .claude))

    private static let labelWidth: CGFloat = 64

    var body: some View {
        let problem = model.problem(with: draft)
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("New subscription")
                .font(Typography.profile)

            field("Provider") {
                Picker("Provider", selection: $draft.provider) {
                    ForEach(Agent.allCases) { agent in
                        Text(agent.title).tag(agent)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .onChange(of: draft.provider) { old, new in
                    // Follow the provider's default folder unless one was chosen.
                    if draft.dir == Subscription.defaultDir(for: old) {
                        draft.dir = Subscription.defaultDir(for: new)
                    }
                }
            }
            field("Name") {
                TextField("Work", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
            }
            field("Folder") {
                HStack(spacing: Spacing.sm) {
                    TextField(Subscription.defaultDir(for: draft.provider), text: $draft.dir)
                        .textFieldStyle(.roundedBorder)
                        .font(Typography.time)
                    Button("Choose…", action: chooseFolder)
                }
            }

            HStack {
                Text(problem ?? "Then press Log in on the new row to sign in.")
                    .font(Typography.small)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    model.add(draft)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(problem != nil)
            }
        }
        .padding(Spacing.xl)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: Spacing.md) {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .frame(width: Self.labelWidth, alignment: .leading)
            content()
        }
    }

    /// Profile folders are usually hidden (~/.claude-work), so show hidden files.
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.showsHiddenFiles = true
        panel.prompt = "Choose"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK, let url = panel.url {
            draft.dir = (url.path as NSString).abbreviatingWithTildeInPath
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
