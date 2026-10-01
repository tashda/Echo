import Foundation

/// One finished run of a query tab, for the time pill's popover (round 41.5, PT0): when it started
/// and finished, how long it took and how it ended. The tab keeps its last few.
struct QueryRunRecord: Equatable, Identifiable {
    enum Outcome: Equatable {
        case succeeded
        case failed
        case cancelled
    }

    let startedAt: Date
    let finishedAt: Date
    let outcome: Outcome
    let id = UUID()

    var duration: TimeInterval { finishedAt.timeIntervalSince(startedAt) }

    /// How many runs a tab remembers.
    static let historyLimit = 5

    /// `history` with `record` added last, keeping the newest `historyLimit`.
    static func appending(_ record: QueryRunRecord, to history: [QueryRunRecord]) -> [QueryRunRecord] {
        Array((history + [record]).suffix(historyLimit))
    }
}
