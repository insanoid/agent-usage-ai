import AgentUsageCore
@testable import AgentUsageUI
import AppKit
import Foundation
import Testing

struct LimitLabelTests {
    @Test(arguments: [
        ("5-hour", nil as String?, "5h"),
        ("Weekly", nil, "7d"),
        ("2-day", nil, "2-day"),
        ("Fable weekly", "Fable", "Fable"),
    ])
    func shortLabel(label: String, scope: String?, expected: String) {
        #expect(Limit(kind: "k", label: label, scope: scope, percent: 1).shortLabel == expected)
    }

    @Test func rowLabelIsTheScriptsLabel() {
        let fable = Limit(kind: "weekly_scoped", label: "Fable weekly", scope: "Fable", percent: 1)
        #expect(fable.rowLabel == "Fable weekly")
    }

    @Test(arguments: [(0.0, "0%"), (41.6, "42%"), (100, "100%")])
    func percentText(percent: Double, expected: String) {
        #expect(Limit(kind: "k", label: "L", percent: percent).percentText == expected)
    }
}

struct SpendTextTests {
    private func spend(_ json: String) throws -> Spend {
        try JSONDecoder().decode(Spend.self, from: Data(json.utf8))
    }

    @Test func usedOfLimitInWholeUnits() throws {
        let usd = try spend(#"{"used": 455.6, "limit": 600, "currency": "USD", "enabled": true}"#)
        let text = try #require(usd.displayText)
        #expect(text.contains("456"))
        #expect(text.contains(" / "))
        #expect(text.contains("600"))
        #expect(!text.contains(".")) // no cents
    }

    @Test func nothingWhenExtraUsageIsOff() throws {
        #expect(try spend(#"{"used": 10, "limit": 600, "enabled": false}"#).displayText == nil)
    }

    @Test func usedAloneWithoutALimit() throws {
        #expect(try spend(#"{"used": 12, "enabled": true}"#).displayText == "12")
    }
}

struct LinkTests {
    @Test func usagePagesBelongToEachProvider() {
        #expect(Agent.claude.usageSettingsURL.host() == "claude.ai")
        #expect(Agent.codex.usageSettingsURL.host() == "chatgpt.com")
        #expect(Agent.allCases.allSatisfy { $0.usageSettingsURL.scheme == "https" })
    }
}

struct HexColorTests {
    @Test(arguments: ["#FF9500", "#000000", "#12AB9C", "FFFFFF"])
    func roundTrips(hex: String) throws {
        let color = try #require(HexColor.color(hex))
        let expected = hex.hasPrefix("#") ? hex : "#\(hex)"
        #expect(HexColor.hex(color) == expected)
    }

    @Test(arguments: ["", "#FFF", "#GGGGGG", "orange", "#FF95001"])
    func rejectsNonColours(hex: String) {
        #expect(HexColor.color(hex) == nil)
    }
}

@MainActor
struct GlyphTests {
    @Test func plainRobotIsAMenuBarTemplate() throws {
        let robot = try #require(AppGlyph.menuBarRobot())
        #expect(robot.isTemplate)
        #expect(robot.size == NSSize(width: 16, height: 16))
    }

    @Test func tintedRobotKeepsItsColour() throws {
        let robot = try #require(AppGlyph.menuBarRobot(tint: .systemOrange))
        #expect(!robot.isTemplate)
    }
}
