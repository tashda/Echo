import Foundation

/// How often a monitor asks its server. A monitor whose tab is kept mounted but not shown still collects (so its charts keep
/// a history), but a minute apart rather than at the chosen rate, unless Settings says to keep the chosen rate.
nonisolated enum ActivityMonitorPolling {
    /// The gap between snapshots while a monitor is not shown.
    static let hiddenInterval: TimeInterval = 60

    static func interval(selected: TimeInterval, isShown: Bool, slowsWhenHidden: Bool) -> TimeInterval {
        isShown || !slowsWhenHidden ? selected : max(selected, hiddenInterval)
    }
}
