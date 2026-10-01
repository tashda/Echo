import Foundation

/// When Run widens for the time (owner, after round 31): only once a query has run 3 s, so a quick
/// query turns ▶ into ■ and back without the capsule growing and shrinking. Changes round 20's G0.
nonisolated enum QueryRunTimeReveal {
    /// How long a query runs before the time shows.
    static let after: TimeInterval = 3

    /// How long to wait, from now, before showing the time for a query started at `start`; zero
    /// once it is due.
    static func wait(since start: Date?, now: Date = .now) -> TimeInterval {
        guard let start else { return after }
        return max(after - now.timeIntervalSince(start), 0)
    }
}
