import SwiftUI

struct WidgetSelection: Sendable {
    let id: String
    let title: String
}

struct WidgetContent: View {
    let cache: CachedUsage?
    let selections: [WidgetSelection]
    let isMedium: Bool
    var error: String?
    var configured = true

    private let footerHeight: CGFloat = 12
    private let footerSpacing: CGFloat = 8
    private let columnSpacing: CGFloat = 24

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            GeometryReader { geometry in
                if let cache {
                    content(cache, date: context.date, size: geometry.size)
                } else {
                    emptyState
                }
            }
        }
        .widgetURL(selectedProfile?.link)
    }

    private var selectedProfile: UsageProfile? {
        guard let cache, let first = selections.first else { return nil }
        return profile(first, in: cache)
    }

    private func profile(_ selection: WidgetSelection, in cache: CachedUsage) -> UsageProfile? {
        UsageProvider.allCases.flatMap { cache.snapshot.profiles(for: $0) }
            .first { $0.id == selection.id }
    }

    private func content(_ cache: CachedUsage, date: Date, size: CGSize) -> some View {
        let visible = Array(selections.prefix(isMedium ? 2 : 1))
        let count = max(visible.count, 1)
        let separators = CGFloat(count - 1) * columnSpacing
        let width = max(0, (size.width - separators) / CGFloat(count))
        return VStack(alignment: .leading, spacing: footerSpacing) {
            HStack(alignment: .top, spacing: columnSpacing) {
                ForEach(visible, id: \.id) { selection in
                    profilePanel(selection, cache: cache, date: date)
                        .frame(width: width, alignment: .topLeading)
                }
                if visible.isEmpty {
                    Text("No profiles available").font(.system(size: 12))
                }
            }
            .frame(height: max(0, size.height - footerHeight - footerSpacing), alignment: .top)
            freshness(cache, date: date)
                .frame(height: footerHeight)
        }
    }

    @ViewBuilder private func profilePanel(_ selection: WidgetSelection, cache: CachedUsage, date: Date) -> some View {
        if let profile = profile(selection, in: cache) {
            Link(destination: profile.link) {
                VStack(alignment: .leading, spacing: 8) {
                    header(profile)
                    if let note = profile.usage.note {
                        unavailable(note)
                    } else if profile.usage.summaryLimits.isEmpty {
                        unavailable("No limits reported")
                    } else {
                        VStack(spacing: 6) {
                            ForEach(profile.usage.summaryLimits.prefix(2)) { limit in
                                WidgetLimitView(limit: limit, date: date)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(selection.title).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                Text("Profile removed. Edit this widget.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private func header(_ profile: UsageProfile) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(profile.provider.title)
                .font(Typography.profile)
            Text(profile.account.label)
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func unavailable(_ note: String) -> some View {
        let needsLogin = note.localizedCaseInsensitiveContains("token")
            || note.localizedCaseInsensitiveContains("sign in")
        return VStack(alignment: .leading, spacing: 5) {
            Image(systemName: needsLogin ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.circle")
                .font(.system(size: 18, weight: .regular)).foregroundStyle(.orange)
            Text(needsLogin ? "Sign-in needed" : "Unavailable")
                .font(.system(size: 11, weight: .semibold))
            Text("Open app for details")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .padding(.top, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(note)
        .accessibilityHint("Open the app for details")
    }

    private func freshness(_ cache: CachedUsage, date: Date) -> some View {
        let offline = cache.failure != nil
        let stale = cache.snapshot.isStale(at: date)
        return HStack(spacing: 4) {
            Image(systemName: offline ? "wifi.slash" : stale ? "clock.badge.exclamationmark" : "arrow.clockwise")
            Text(offline ? "Offline" : stale ? "Stale" : "Updated")
            Text(cache.snapshot.generatedAt, style: .time).monospacedDigit()
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(offline || stale ? .orange : .secondary)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: configured ? "wifi.slash" : "chart.bar.xaxis")
                .font(.system(size: 22)).foregroundStyle(.blue)
            Text("Agent Usage").font(.system(size: 14, weight: .semibold, design: .rounded))
            Text(error ?? (configured ? "Open the app to fetch usage." : "Open the app to connect your server."))
                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct WidgetLimitView: View {
    let limit: UsageLimit
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(limit.label).font(.system(size: 10, weight: .medium))
                    if let reset = limit.resetsAt {
                        Text("↻ \(UsageStyle.resetText(reset, at: date))")
                            .font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Text("\(limit.percent.formatted(.number.precision(.fractionLength(0))))%")
                    .font(Typography.value)
                    .monospacedDigit()
                    .foregroundStyle(limit.percent >= 75 ? UsageStyle.tint(for: limit.percent) : .primary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            UsageMeter(percent: limit.percent, height: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(limit.label), \(limit.percent.formatted()) percent used")
        .accessibilityValue(limit.resetsAt.map { "Resets: \($0.formatted())" } ?? "")
    }
}
