import AgentUsageCore
import AgentUsageUI
import SwiftUI

/// Opt-in for Claude's free usage-limit resets, which Anthropic only reports
/// to Claude Code itself.
struct FreeResetsRow: View {
    let store: UsageStore

    @AppStorage(ScriptUsageSource.freeResetsDefaultsKey) private var enabled = false

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Claude free resets")
                    .font(Typography.profile)
                Text("Show free usage-limit resets. To read them, Agent Usage identifies itself "
                    + "to Anthropic as Claude Code, through an undocumented API that may change.")
                    .font(Typography.small)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.md)
            Toggle("Claude free resets", isOn: $enabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: enabled) {
                    Task { await store.refresh() }
                }
        }
    }
}
