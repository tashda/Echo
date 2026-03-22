import SwiftUI

extension TableStructureEditorView {

    // MARK: - Constraint Presentation Helpers

    internal func presentPrimaryKeyEditor(isNew: Bool) {
        if isNew {
            viewModel.primaryKey = TableStructureEditorViewModel.PrimaryKeyModel(
                original: nil,
                name: "pk_\(viewModel.tableName)",
                columns: [],
                isDeferrable: false,
                isInitiallyDeferred: false
            )
            viewModel.clearPrimaryKeyRemoval()
        }

        guard viewModel.primaryKey != nil else { return }
        activePrimaryKeyEditor = PrimaryKeyEditorPresentation(isNew: isNew)
    }

    internal func presentNewUniqueConstraint() {
        let model = viewModel.addUniqueConstraint()
        activeUniqueConstraintEditor = UniqueConstraintEditorPresentation(constraintID: model.id, isNew: true)
    }

    internal func presentUniqueConstraintEditor(for constraint: TableStructureEditorViewModel.UniqueConstraintModel) {
        activeUniqueConstraintEditor = UniqueConstraintEditorPresentation(constraintID: constraint.id, isNew: constraint.isNew)
    }

    internal func presentNewCheckConstraint() {
        let model = viewModel.addCheckConstraint()
        activeCheckConstraintEditor = CheckConstraintEditorPresentation(constraintID: model.id, isNew: true)
    }

    internal func presentCheckConstraintEditor(for constraint: TableStructureEditorViewModel.CheckConstraintModel) {
        activeCheckConstraintEditor = CheckConstraintEditorPresentation(constraintID: constraint.id, isNew: constraint.isNew)
    }
}
