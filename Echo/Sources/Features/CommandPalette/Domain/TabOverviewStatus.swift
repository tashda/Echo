import Foundation

/// What state a query tab is in, for the tab overview (round 35.1, OR1: see everything that's
/// open and what state it's in). Tool tabs have none.
nonisolated enum TabOverviewStatus: Equatable, Sendable {
    case notRun
    case running(elapsed: TimeInterval)
    case failed
    case cancelled
    case finished(rows: Int)

    init(isExecuting: Bool, elapsed: TimeInterval, hasError: Bool, wasCancelled: Bool, hasRun: Bool, rows: Int) {
        if isExecuting {
            self = .running(elapsed: elapsed)
        } else if hasError {
            self = .failed
        } else if wasCancelled {
            self = .cancelled
        } else if hasRun {
            self = .finished(rows: rows)
        } else {
            self = .notRun
        }
    }

    var text: String {
        switch self {
        case .notRun: "Not run"
        case .running(let elapsed): "Running \(Self.clock(elapsed))"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .finished(let rows): rows == 1 ? "1 row" : "\(rows.formatted()) rows"
        }
    }

    /// m:ss, as the run button's timer reads.
    static func clock(_ elapsed: TimeInterval) -> String {
        let seconds = max(Int(elapsed), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
