import Foundation
import Observation
import os

/// Holds the latest report and keeps it fresh.
@MainActor
@Observable
public final class UsageStore {
    public static let pollInterval: Duration = .seconds(300)

    /// Opening the panel refreshes only data older than this, so opening it
    /// repeatedly does not start a process each time.
    public static let freshness: TimeInterval = 60

    public private(set) var report: UsageReport?
    /// Set when the last refresh failed. The previous report stays visible
    /// beside it, so a network blip does not blank the panel.
    public private(set) var lastError: String?
    public private(set) var isRefreshing = false
    public private(set) var lastSuccess: Date?

    private static let logger = Logger(subsystem: Log.subsystem, category: "refresh")

    private let source: UsageSource
    private let onReport: @MainActor (UsageReport) -> Void
    private var pollTask: Task<Void, Never>?

    /// `onReport` runs after each successful refresh — the app uses it to
    /// hand the report to its widget.
    /// `cached` is the last report saved by an earlier run: shown at once and
    /// kept underneath any profile whose first read fails.
    public init(
        source: UsageSource,
        cached: UsageReport? = nil,
        onReport: @escaping @MainActor (UsageReport) -> Void = { _ in }
    ) {
        self.source = source
        self.onReport = onReport
        report = cached
    }

    /// Starts polling. Calling it again has no effect.
    public func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                do {
                    try await Task.sleep(for: Self.pollInterval)
                } catch {
                    return // Cancelled: stop polling.
                }
            }
        }
    }

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let report = try await source.fetch().carryingForward(from: report)
            self.report = report
            lastSuccess = Date()
            lastError = nil
            Self.logger.info("refreshed \(report.accounts.count) accounts")
            onReport(report)
        } catch {
            lastError = error.localizedDescription
            Self.logger.error("refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func refreshIfStale(now: Date = Date()) async {
        if let lastSuccess, now.timeIntervalSince(lastSuccess) < Self.freshness {
            return
        }
        await refresh()
    }
}
