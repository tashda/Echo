import SwiftUI
import Foundation

extension UniqueConstraintEditorSheet {
    func applyDraftChanges() {
        let updatedConstraint = TableStructureEditorViewModel.UniqueConstraintModel(
            original: constraint.original,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            columns: draft.columns.map { $0.name },
            isDeferrable: draft.isDeferrable,
            isInitiallyDeferred: draft.isInitiallyDeferred
        )

        if draft.isEditingExisting {
            constraint = updatedConstraint
        } else {
            onSaveNew?(updatedConstraint)
        }
    }

    func cancelIfNew() {
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }
}
