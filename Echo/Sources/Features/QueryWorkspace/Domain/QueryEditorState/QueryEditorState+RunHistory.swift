import Foundation

extension QueryEditorState {
    /// Keeps the run that just ended for the time pill's popover (round 41.5, PT0).
    func recordRun(startedAt: Date?, finishedAt: Date, outcome: QueryRunRecord.Outcome) {
        guard let startedAt else { return }
        runHistory = QueryRunRecord.appending(QueryRunRecord(startedAt: startedAt, finishedAt: finishedAt, outcome: outcome), to: runHistory)
    }

    /// The run on screen: the last one recorded, unless a run is going.
    var lastRun: QueryRunRecord? { isExecuting ? nil : runHistory.last }
}
