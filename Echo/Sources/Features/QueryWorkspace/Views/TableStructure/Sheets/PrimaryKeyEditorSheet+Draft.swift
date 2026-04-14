import SwiftUI
import Foundation

extension PrimaryKeyEditorSheet {
    func applyDraftChanges() {
        let updatedPrimaryKey = TableStructureEditorViewModel.PrimaryKeyModel(
            original: primaryKey.original,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            columns: draft.columns.map { $0.name },
            isDeferrable: draft.isDeferrable,
            isInitiallyDeferred: draft.isInitiallyDeferred
        )

        if draft.isEditingExisting {
            primaryKey = updatedPrimaryKey
        } else {
            onSaveNew?(updatedPrimaryKey)
        }
    }

    func cancelIfNew() {
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }
}
