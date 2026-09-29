import Foundation

extension QueryEditorState {
    /// A results-only state holding extra result set `index` (1-based after the first), so it
    /// shows in the same grid as the first set (plan R6). Kept in memory: extra sets arrive
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
}
