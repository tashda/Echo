import Foundation

extension QueryEditorState {
    /// A results-only state holding extra result set `index` (1-based after the first), so it
    /// shows in the same grid as the first set (plan R6). A set that streamed (SQL Server, round 22
    /// BG1) already has its state, spooled like the first set; other engines deliver extra sets
    /// complete, so the buffer is sized to hold every row and nothing spools.
    func additionalResultState(at index: Int) -> QueryEditorState? {
        guard index >= 0, index < additionalResults.count else { return nil }
        if let cached = additionalResultStates[index] { return cached }
        let set = additionalResults[index]
        let state = QueryEditorState(initialVisibleRowBatch: max(set.rows.count, 1), spoolManager: spoolManager)
        state.consumeFinalResult(QueryResultSet(
            columns: set.columns,
            rows: set.rows,
            totalRowCount: set.rows.count,
            commandTag: set.commandTag,
            dataClassification: set.dataClassification
        ))
        additionalResultStates[index] = state
        return state
    }

    /// Rows of extra result set `index` as they stream: the set gets its own state, which spools
    /// past the preview exactly like the first set.
    func applyAdditionalStreamUpdate(_ update: QueryStreamUpdate) {
        let index = update.resultSetIndex - 1
        let state: QueryEditorState
        if let existing = streamedAdditionalStates[index] {
            state = existing
        } else {
            state = QueryEditorState(initialVisibleRowBatch: initialVisibleRowBatch, previewRowLimit: previewRowLimit, spoolManager: spoolManager)
            state.startExecution()
            streamedAdditionalStates[index] = state
        }
        var routed = update
        routed.resultSetIndex = 0
        state.applyStreamUpdate(routed)
    }

    /// The run's final result: each streamed extra set gets its preview rows and real total, and
    /// becomes the state the grid shows for it.
    func finishStreamedAdditionalResults(_ sets: [QueryResultSet]) {
        for (index, state) in streamedAdditionalStates where sets.indices.contains(index) {
            state.consumeFinalResult(sets[index])
            state.finishExecution()
            additionalResultStates[index] = state
        }
        streamedAdditionalStates.removeAll()
    }
}
