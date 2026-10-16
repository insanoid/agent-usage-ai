// Renders the README screenshots from the real views: the panel, Settings, and
// the small, medium and large widget, each in light and dark. Run through
// scripts/screenshots.sh, which links the app's view files next to this one.
//
// Usage: Screenshots <report.json | --sample> <subscriptions.json> <output-dir>
// --sample renders UsageReport.sample(): made-up numbers, safe to publish.
import AgentUsageCore
import AgentUsageUI
import AppKit
import SwiftUI
import WidgetKit

/// Mirrors the widget extension's entry, which this harness does not compile.
struct UsageEntry {
    let date: Date
    let report: UsageReport?
    let problem: String?
}

struct FixedSource: UsageSource {
    let report: UsageReport
    func fetch() async throws -> UsageReport {
        report
    }
}

/// A rounded card like the panel and widget on screen.
struct Card<Content: View>: View {
    let dark: Bool
    let radius: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(dark ? Color(red: 0.14, green: 0.14, blue: 0.16) : Color(red: 0.97, green: 0.97, blue: 0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .padding(24)
    }
}

/// Draws through AppKit (`cacheDisplay`), not ImageRenderer, so switches,
/// buttons and colour wells render as they do in the app.
@MainActor
func snapshot(_ view: some View, dark: Bool, to url: URL) throws {
    let host = NSHostingView(rootView: view)
    host.frame = NSRect(origin: .zero, size: host.fittingSize)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    host.display()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
        throw CocoaError(.fileWriteUnknown)
    }
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])?.write(to: url)
    print("wrote \(url.lastPathComponent)")
}

@MainActor
func run() async throws {
    let arguments = CommandLine.arguments
    guard arguments.count == 4 else {
        print("usage: Screenshots <report.json | --sample> <subscriptions.json> <output-dir>")
        exit(2)
    }
    NSApplication.shared.setActivationPolicy(.prohibited)
    let report = arguments[1] == "--sample"
        ? UsageReport.sample()
        : try UsageReport.decode(Data(contentsOf: URL(fileURLWithPath: arguments[1])))
    let subscriptions = SubscriptionsModel(file: SubscriptionsFile(url: URL(fileURLWithPath: arguments[2])))
    let out = URL(fileURLWithPath: arguments[3])
    let store = UsageStore(source: FixedSource(report: report))
    await store.refresh()

    let widgets: [(WidgetFamily, CGSize, String)] = [
        (.systemSmall, CGSize(width: 170, height: 170), "widget-small"),
        (.systemMedium, CGSize(width: 364, height: 170), "widget"),
        (.systemLarge, CGSize(width: 364, height: 382), "widget-large"),
    ]
    for dark in [true, false] {
        let mode = dark ? "dark" : "light"
        try snapshot(Card(dark: dark, radius: 14) { UsagePanel(store: store) },
                     dark: dark, to: out.appending(path: "panel-\(mode).png"))
        try snapshot(Card(dark: dark, radius: 12) { SettingsContent(model: subscriptions, store: store).frame(width: 540) },
                     dark: dark, to: out.appending(path: "settings-\(mode).png"))
        let entry = UsageEntry(date: Date(), report: report, problem: nil)
        for (family, size, name) in widgets {
            let widget = Card(dark: dark, radius: 22) {
                UsageWidgetContent(entry: entry, family: family)
                    .padding(16)
                    .frame(width: size.width, height: size.height)
            }
            try snapshot(widget, dark: dark, to: out.appending(path: "\(name)-\(mode).png"))
        }
    }
}

try await run()
