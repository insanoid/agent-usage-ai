import Foundation
@testable import UsageMobileCore
import XCTest

final class UsageCoreTests: XCTestCase {
    func testEndpointRequiresHTTPSAndRejectsEmbeddedCredentialsAndQueries() throws {
        for invalid in [
            "http://host/usage",
            "https://user:secret@host",
            "https://host?token=x",
            "https://host/#fragment",
        ] {
            XCTAssertThrowsError(try ServerEndpoint(invalid))
        }
        let endpoint = try ServerEndpoint("https://example.ts.net/agent-usage/")
        XCTAssertEqual(endpoint.usageURL.absoluteString, "https://example.ts.net/agent-usage/v1/usage")
    }

    func testDecodesProviderErrorsWithoutInventingZeroUsage() throws {
        let snapshot = try UsageSnapshot.decode(fixture)
        XCTAssertEqual(snapshot.accounts[0].claude?.note, "No access token")
        XCTAssertEqual(snapshot.accounts[0].claude?.limits.count, 0)
        XCTAssertEqual(snapshot.accounts[0].codex?.limits[0].percent, 42)
        XCTAssertNil(snapshot.accounts[0].codex?.resetCredits)
        XCTAssertNil(snapshot.accounts[0].codex?.resetCreditsExpireAt)
        XCTAssertFalse(snapshot.isStale(at: Date(timeIntervalSince1970: 1_793_664_100)))
        XCTAssertTrue(snapshot.isStale(at: Date(timeIntervalSince1970: 1_793_664_700)))
    }

    func testCodexResetCreditsSurviveAPIDecodingAndCacheRoundTrip() throws {
        for count in [0, 3] {
            let text = try XCTUnwrap(String(data: fixture, encoding: .utf8)).replacingOccurrences(
                of: "\"plan\": \"Pro\",",
                with: "\"plan\": \"Pro\", \"reset_credits\": \(count), "
                    + "\"reset_credits_expire_at\": \"2026-11-10T00:00:00Z\","
            )
            let snapshot = try UsageSnapshot.decode(Data(text.utf8))
            let cached = try JSONDecoder().decode(UsageSnapshot.self, from: JSONEncoder().encode(snapshot))
            let provider = try XCTUnwrap(cached.accounts[0].codex)
            let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(provider))
                as? [String: Any])
            XCTAssertEqual(encoded["resetCredits"] as? Int, count)
            let expiry = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-10T00:00:00Z"))
            XCTAssertEqual(encoded["resetCreditsExpireAt"] as? Double, expiry.timeIntervalSinceReferenceDate)
        }
    }

    func testRejectsUnknownReportVersion() throws {
        let unsupported = try XCTUnwrap(String(data: fixture, encoding: .utf8)).replacingOccurrences(
            of: "\"version\": 1",
            with: "\"version\": 2"
        )
        XCTAssertThrowsError(try UsageSnapshot.decode(Data(unsupported.utf8)))
    }
}

let fixture = Data("""
{
  "version": 1,
  "generated_at": "2026-11-03T00:00:00Z",
  "accounts": [
    {
      "slot": "personal",
      "label": "Personal",
      "claude": {
        "note": "No access token"
      },
      "codex": {
        "plan": "Pro",
        "limits": [
          {
            "kind": "session",
            "label": "5-hour",
            "percent": 42,
            "resets_at": "2026-11-03T04:00:00Z"
          }
        ]
      }
    }
  ],
  "order": {
    "claude": [
      "personal"
    ]
  },
  "collection": {
    "age_seconds": 30,
    "stale": false,
    "status": "ok"
  }
}
""".utf8)

final class CacheTests: XCTestCase {
    func testMalformedSettingsCanBeReplacedAndOldCacheIsDiscarded() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SharedStore(directory: directory)
        try store.configure(ServerSettings(endpoint: "https://one.example"))
        try Data("broken".utf8).write(to: directory.appendingPathComponent("settings.json"))
        try store.configure(ServerSettings(endpoint: "https://two.example"))
        XCTAssertEqual(try store.settings()?.endpoint, "https://two.example")
        XCTAssertNil(try store.cached())
    }

    func testMalformedCacheDoesNotBlockFreshData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SharedStore(directory: directory)
        try store.configure(ServerSettings(endpoint: "https://one.example"))
        try Data("broken".utf8).write(to: directory.appendingPathComponent("usage.json"))
        XCTAssertNil(try store.cached())
        try store.save(CachedUsage(
            endpoint: "https://one.example",
            snapshot: UsageSnapshot.decode(fixture),
            fetchedAt: .now,
            failure: nil
        ))
        XCTAssertEqual(try store.cached()?.snapshot.accounts[0].codex?.limits[0].percent, 42)
    }

    func testEndpointChangeClearsCacheAndRejectsOldRequestCompletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SharedStore(directory: directory)
        try store.configure(ServerSettings(endpoint: "https://one.example"))
        let cache = try CachedUsage(
            endpoint: "https://one.example",
            snapshot: UsageSnapshot.decode(fixture),
            fetchedAt: .now,
            failure: nil
        )
        try store.save(cache)
        XCTAssertNotNil(try store.cached())
        try store.configure(ServerSettings(endpoint: "https://two.example"))
        XCTAssertNil(try store.cached())
        try store.save(cache)
        XCTAssertNil(try store.cached())
    }

    func testFailedRefreshRetainsSnapshotAndPersistsErrorAcrossInstances() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SharedStore(directory: directory)
        try store.configure(ServerSettings(endpoint: "https://one.example"))
        try store.save(CachedUsage(
            endpoint: "https://one.example",
            snapshot: UsageSnapshot.decode(fixture),
            fetchedAt: .now,
            failure: nil
        ))
        try store.recordFailure("Offline", endpoint: "https://one.example")
        let restored = try SharedStore(directory: directory).cached()
        XCTAssertEqual(restored?.snapshot.accounts[0].codex?.limits[0].percent, 42)
        XCTAssertEqual(restored?.failure, "Offline")
    }
}
