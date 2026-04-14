import SwiftUI
import Foundation

extension CheckConstraintEditorSheet {
    func applyDraftChanges() {
        let updatedConstraint = TableStructureEditorViewModel.CheckConstraintModel(
            original: constraint.original,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            expression: draft.expression.trimmingCharacters(in: .whitespacesAndNewlines)
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
