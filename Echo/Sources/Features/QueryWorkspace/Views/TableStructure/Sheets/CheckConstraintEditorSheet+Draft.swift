import SwiftUI
import Foundation

extension CheckConstraintEditorSheet {
    func applyDraftChanges() {
        constraint.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        constraint.expression = draft.expression.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancelIfNew() {
        if !draft.isEditingExisting {
            onCancelNew()
        }
    }
}
