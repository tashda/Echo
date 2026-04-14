import SwiftUI
import Foundation

extension PrimaryKeyEditorSheet {
    func applyDraftChanges() {
        primaryKey.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        primaryKey.columns = draft.columns.map { $0.name }
        primaryKey.isDeferrable = draft.isDeferrable
        primaryKey.isInitiallyDeferred = draft.isInitiallyDeferred
    }

    func cancelIfNew() {
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }
}
