import Foundation

/// Round 20 (N1): a query that ran for 30 s or more and ends while Echo isn't in front gets a
/// macOS notification, because Run's ✓ is gone long before you look back.
nonisolated enum LongQueryNotice {
    static let threshold: TimeInterval = 30

    static func shouldNotify(duration: TimeInterval?, echoIsActive: Bool) -> Bool {
        guard let duration, !echoIsActive else { return false }
        return duration >= threshold
    }

    static func title(succeeded: Bool) -> String {
        succeeded ? "Query finished" : "Query failed"
    }

    static func body(tabTitle: String, succeeded: Bool, duration: TimeInterval) -> String {
        let elapsed = ElapsedTimeText.format(duration)
        return succeeded ? "\(tabTitle) finished in \(elapsed)" : "\(tabTitle) failed after \(elapsed)"
    }
}
