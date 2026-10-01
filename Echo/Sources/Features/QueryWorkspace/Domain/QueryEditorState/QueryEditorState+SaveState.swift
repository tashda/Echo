import Foundation

extension QueryEditorState {
    /// Changed since the tab opened or was last saved, and not empty (owner, 2026-10-01): a
    /// script Echo generated asks only once you edit it.
    var hasUnsavedChanges: Bool {
        Self.hasUnsavedChanges(sql: sql, savedSQL: savedSQL)
    }

    nonisolated static func hasUnsavedChanges(sql: String, savedSQL: String) -> Bool {
        sql != savedSQL && !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func markSaved() {
        savedSQL = sql
    }
}
