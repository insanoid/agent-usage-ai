import AgentUsageCore
import AgentUsageUI
import AppKit
import SwiftUI

/// Adds a subscription, or edits one in place of its row.
struct SubscriptionForm: View {
    let model: SubscriptionsModel
    @State var draft: Subscription
    let isNew: Bool
    @Binding var isPresented: Bool

    private static let labelWidth: CGFloat = 64

    var body: some View {
        let problem = model.problem(with: draft)
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text(isNew ? "New subscription" : "Edit subscription")
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
                Text(problem ?? (isNew ? "Then press Log in on the new row to sign in." : ""))
                    .font(Typography.small)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    if isNew {
                        model.add(draft)
                    } else {
                        model.update(draft)
                    }
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
