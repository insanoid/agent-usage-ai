import AgentUsageCore
import AppKit
import os
import SwiftUI

/// The provider's mark: Claude for Claude Code, OpenAI for Codex.
public struct ProviderLogo: View {
    private let agent: Agent
    private let size: CGFloat

    public init(_ agent: Agent, size: CGFloat) {
        self.agent = agent
        self.size = size
    }

    public var body: some View {
        Group {
            if let image = LogoCache.image(named: agent.logoName, template: agent == .codex) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(agent.title.prefix(1))
                    .font(.system(size: size * 0.8, weight: .semibold))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(agent.title)
    }
}

/// The robot for the menu bar: a template image, so macOS tints it for light
/// and dark menu bars.
public enum AppGlyph {
    /// Menu bar icons are drawn at 16–18 pt; the robot's thin strokes read best at 16.
    private static let menuBarSize = NSSize(width: 16, height: 16)

    @MainActor
    public static func menuBarRobot() -> NSImage? {
        guard let image = LogoCache.image(named: "robot", template: true)?.copy() as? NSImage else { return nil }
        image.size = menuBarSize
        image.isTemplate = true
        return image
    }
}

/// Loads each SVG once. NSImage reads SVG natively, which works the same in
/// `swift build` and Xcode builds — an asset catalog only compiles in Xcode.
private enum LogoCache {
    private static let logger = Logger(subsystem: "com.karthikeyaudupa.agent-usage", category: "logo")

    @MainActor private static var images: [String: NSImage] = [:]

    /// `template` images draw in the surrounding text colour — right for
    /// monochrome marks (OpenAI, the robot), wrong for Claude's orange.
    @MainActor
    static func image(named name: String, template: Bool) -> NSImage? {
        if let cached = images[name] {
            return cached
        }
        guard let url = Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "Logos"),
              let image = NSImage(contentsOf: url)
        else {
            logger.error("logo \(name, privacy: .public).svg missing from the bundle")
            return nil
        }
        image.isTemplate = template
        images[name] = image
        return image
    }
}

extension Agent {
    var logoName: String {
        switch self {
        case .claude: "claude"
        case .codex: "openai"
        }
    }
}
