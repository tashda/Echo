import Foundation

/// Where a run's time went, for the time pill's timeline (round 41.5, PT0): sending the query,
/// waiting for the first row, then reading the rows.
struct QueryRunTimeline: Equatable {
    /// From pressing Run to the query leaving Echo.
    let sending: TimeInterval
    /// From the query leaving Echo to the first rows (or the end, when nothing came back).
    let waiting: TimeInterval
    /// From the first rows to the end.
    let reading: TimeInterval

    var total: TimeInterval { sending + waiting + reading }

    /// Each phase's share of the run, for the bar; all zero when the run took no time.
    var shares: (sending: Double, waiting: Double, reading: Double) {
        guard total > 0 else { return (0, 0, 0) }
        return (sending / total, waiting / total, reading / total)
    }

    init(sending: TimeInterval, waiting: TimeInterval, reading: TimeInterval) {
        self.sending = max(sending, 0); self.waiting = max(waiting, 0); self.reading = max(reading, 0)
    }

    /// The phases from a run's timings; nil until the run has an end (or, while running, a first row).
    init?(timings: QueryPerformanceTracker.Report.Timings) {
        let sending = timings.startToDispatch ?? 0
        let firstRow = timings.startToFirstUpdate
        guard let end = timings.startToFinish ?? firstRow else { return nil }
        let waitingEnd = min(firstRow ?? end, end)
        self.init(sending: min(sending, waitingEnd), waiting: waitingEnd - sending, reading: end - waitingEnd)
    }
}
