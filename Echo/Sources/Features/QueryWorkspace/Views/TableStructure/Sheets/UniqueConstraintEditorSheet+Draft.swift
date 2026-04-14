import SwiftUI
import Foundation

extension UniqueConstraintEditorSheet {
    func applyDraftChanges() {
        constraint.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        constraint.columns = draft.columns.map { $0.name }
        constraint.isDeferrable = draft.isDeferrable
        constraint.isInitiallyDeferred = draft.isInitiallyDeferred
    }

    func cancelIfNew() {
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }
}
