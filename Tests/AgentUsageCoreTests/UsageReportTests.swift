@testable import AgentUsageCore
import Foundation
import Testing

struct UsageReportTests {
    private func fixture() throws -> UsageReport {
        let url = try #require(Bundle.module.url(forResource: "Fixtures/report", withExtension: "json"))
        return try UsageReport.decode(Data(contentsOf: url))
    }

    @Test func decodesEveryAccount() throws {
        let report = try fixture()
        #expect(report.accounts.map(\.slot) == ["work", "personal"])
    }

    @Test func decodesScopedLimitsAndDates() throws {
        let work = try fixture().accounts[0]
        let fable = try #require(work.claude.limits.first { $0.scope == "Fable" })
        #expect(fable.label == "Fable weekly")
        #expect(fable.percent == 100)
        #expect(fable.resetsAt == ISO8601DateFormatter().date(from: "2026-10-20T04:59:59Z"))
    }

    @Test func decodesSpendAndCodex() throws {
        let work = try fixture().accounts[0]
        #expect(work.claude.spend?.used == 405.06)
        #expect(work.claude.spend?.enabled == true)
        #expect(work.codex?.plan == "Business")
        #expect(work.codex?.planDetail == "Pro Lite")
        #expect(work.codex?.limits.first?.level == .normal)
        #expect(work.codex?.resetCredits == 0)
        #expect(work.claude.resetCredits == nil)
    }

    @Test func noteResultHasNoLimits() throws {
        let personal = try fixture().accounts[1]
        #expect(personal.claude.note == "token stale — run: cc personal")
        #expect(personal.claude.limits.isEmpty)
        #expect(personal.codex == nil)
    }

    @Test func rejectsNewerSchemaVersion() {
        let json = Data(#"{"version": 2, "generated_at": "2026-10-16T13:58:35Z", "accounts": []}"#.utf8)
        #expect(throws: UsageError.unsupportedVersion(2)) { try UsageReport.decode(json) }
    }
}

struct AgentGroupingTests {
    private func usage(_ percents: [Double], scope: String? = nil) -> AgentUsage {
        AgentUsage(limits: percents.enumerated().map { index, percent in
            Limit(kind: "k\(index)", label: "L", scope: scope, percent: percent)
        })
    }

    private func report(_ accounts: [Account]) -> UsageReport {
        UsageReport(version: 1, generatedAt: Date(), accounts: accounts)
    }

    @Test func groupsAccountsByAgentInConfigOrder() {
        let report = report([
            Account(slot: "work", label: "work", claude: usage([1]), codex: usage([2])),
            Account(slot: "work2", label: "work2", claude: usage([3]), codex: nil),
            Account(slot: "personal", label: "personal", claude: usage([4]), codex: usage([5])),
        ])
        #expect(report.usages(for: .claude).map(\.id) == ["work", "work2", "personal"])
        #expect(report.usages(for: .codex).map(\.id) == ["work", "personal"])
    }

    @Test func peakSpansAgentsAndIgnoresScopedLimits() {
        let fable = Limit(kind: "weekly_scoped", label: "Fable weekly", scope: "Fable", percent: 100)
        let claude = AgentUsage(limits: [Limit(kind: "weekly_all", label: "Weekly", percent: 60), fable])
        let report = report([
            Account(slot: "a", label: "a", claude: claude, codex: usage([85])),
            Account(slot: "b", label: "b", claude: usage([10]), codex: nil),
        ])
        #expect(report.peakPercent == 85)
        #expect(self.report([]).peakPercent == nil)
    }
}

struct DisplayNameTests {
    @Test(arguments: [
        ("🔵 work", "work", "Work"), ("work2", "work2", "Work2"), ("Personal", "p", "Personal"),
        ("🟢", "personal", "Personal"), ("", "work", "Work"),
    ])
    func stripsBadgeAndCapitalises(label: String, slot: String, expected: String) {
        let account = Account(slot: slot, label: label, claude: AgentUsage(), codex: nil)
        #expect(account.displayName == expected)
    }
}

struct SeverityTests {
    static let cases: [(Double, Severity)] = [
        (0, .normal), (74.9, .normal), (75, .warning), (89.9, .warning), (90, .critical), (100, .critical),
    ]

    @Test(arguments: cases)
    func derivedFromPercent(percent: Double, expected: Severity) {
        #expect(Severity(percent: percent) == expected)
    }

    @Test func apiSeverityWins() {
        #expect(Limit(kind: "k", label: "L", percent: 10, severity: "critical").level == .critical)
        #expect(Limit(kind: "k", label: "L", percent: 95, severity: "bogus").level == .critical)
    }
}

struct ResetFormatTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    static let countdowns: [(TimeInterval, String)] = [
        (30, "now"), (-100, "now"), (720, "12m"), (7500, "2h 05m"), (359_940, "4d 3h"),
    ]

    @Test(arguments: countdowns)
    func countdown(offset: TimeInterval, expected: String) {
        #expect(ResetFormat.countdown(to: now.addingTimeInterval(offset), now: now) == expected)
    }

    @Test func clockAddsWeekdayOnlyForOtherDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let locale = Locale(identifier: "en_GB")
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-16T09:00:00Z"))
        let today = now.addingTimeInterval(3 * 3600)
        let later = now.addingTimeInterval(4 * 86400)
        #expect(ResetFormat.clock(today, now: now, calendar: calendar, locale: locale) == "12:00")
        #expect(ResetFormat.clock(later, now: now, calendar: calendar, locale: locale) == "Tue 09:00")
    }
}

struct ReportCacheTests {
    @Test func roundTripsThroughTheCache() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "agent-usage-cache-\(UUID().uuidString)/report.json")
        let cache = ReportCache(fileURL: url)
        #expect(try cache.load() == nil)

        let fixture = try #require(Bundle.module.url(forResource: "Fixtures/report", withExtension: "json"))
        let report = try UsageReport.decode(Data(contentsOf: fixture))
        try cache.save(report)
        #expect(try cache.load() == report)
    }
}

struct CarryForwardTests {
    private func report(_ claude: AgentUsage) -> UsageReport {
        UsageReport(version: 1, generatedAt: Date(), accounts: [
            Account(slot: "work", label: "work", claude: claude, codex: nil),
        ])
    }

    @Test func keepsEarlierNumbersWhenAReadFails() throws {
        let good = AgentUsage(limits: [Limit(kind: "session", label: "5-hour", percent: 40)], plan: "Team")
        let merged = report(AgentUsage(note: "rate limited")).carryingForward(from: report(good))
        let claude = try #require(merged.accounts.first?.claude)
        #expect(claude.limits.first?.percent == 40)
        #expect(claude.plan == "Team")
        #expect(claude.note == "rate limited — showing earlier numbers")
    }

    @Test func dropsWindowsThatHaveResetSince() {
        let now = Date()
        let old = AgentUsage(limits: [
            Limit(kind: "session", label: "5-hour", percent: 95, resetsAt: now.addingTimeInterval(-60)),
        ])
        let merged = report(AgentUsage(note: "token stale")).carryingForward(from: report(old), now: now)
        #expect(merged.accounts.first?.claude.limits.isEmpty == true)
        #expect(merged.accounts.first?.claude.note == "token stale")
    }

    @Test func freshNumbersWin() {
        let old = AgentUsage(limits: [Limit(kind: "session", label: "5-hour", percent: 40)])
        let fresh = AgentUsage(limits: [Limit(kind: "session", label: "5-hour", percent: 55)])
        let merged = report(fresh).carryingForward(from: report(old))
        #expect(merged.accounts.first?.claude.limits.first?.percent == 55)
        #expect(merged.accounts.first?.claude.note == nil)
    }
}

@MainActor
struct UsageStoreSeedTests {
    private struct Failing: UsageSource {
        func fetch() async throws -> UsageReport {
            UsageReport(version: 1, generatedAt: Date(), accounts: [
                Account(slot: "work", label: "work", claude: AgentUsage(note: "rate limited"), codex: nil),
            ])
        }
    }

    @Test func aCachedReportSurvivesAFailedFirstRead() async throws {
        let cached = UsageReport(version: 1, generatedAt: Date(), accounts: [
            Account(
                slot: "work",
                label: "work",
                claude: AgentUsage(limits: [Limit(kind: "session", label: "5-hour", percent: 40)]),
                codex: nil
            ),
        ])
        let store = UsageStore(source: Failing(), cached: cached)
        await store.refresh()
        let claude = try #require(store.report?.accounts.first?.claude)
        #expect(claude.limits.first?.percent == 40)
        #expect(claude.note == "rate limited — showing earlier numbers")
    }
}
