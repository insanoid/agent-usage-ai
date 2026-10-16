import AgentUsageCore
import AgentUsageUI
import SwiftUI

/// The window that drops down from the menu bar item.
struct UsagePanel: View {
    let store: UsageStore

    static let width: CGFloat = 360
    /// Countdowns move in minutes; redrawing more often only costs energy.
    private static let tick: TimeInterval = 30

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.tick)) { context in
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if let error = store.lastError {
                    ErrorBanner(message: error, hasStaleData: store.report != nil)
                }

                if let report = store.report {
                    UsageOverview(report: report, now: context.date)
                } else if store.lastError == nil {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xxl * 2)
                }

                PanelFooter(store: store, now: context.date)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.md)
            .frame(width: Self.width)
        }
        .onAppear {
            Task { await store.refreshIfStale() }
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    let hasStaleData: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(Typography.secondary)
                .foregroundStyle(.orange)
            if hasStaleData {
                Text("Showing the last numbers that loaded.")
                    .font(Typography.small)
                    .foregroundStyle(.secondary)
            }
        }
        .textSelection(.enabled)
    }
}
