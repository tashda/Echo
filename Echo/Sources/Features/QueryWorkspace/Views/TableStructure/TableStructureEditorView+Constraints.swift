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
        activeSheet = .primaryKey(PrimaryKeyEditorPresentation(isNew: isNew))
    }

    internal func presentNewUniqueConstraint() {
        let model = viewModel.addUniqueConstraint()
        activeSheet = .uniqueConstraint(UniqueConstraintEditorPresentation(constraintID: model.id, isNew: true))
    }

    internal func presentUniqueConstraintEditor(for constraint: TableStructureEditorViewModel.UniqueConstraintModel) {
        activeSheet = .uniqueConstraint(UniqueConstraintEditorPresentation(constraintID: constraint.id, isNew: constraint.isNew))
    }

    internal func presentNewCheckConstraint() {
        let model = viewModel.addCheckConstraint()
        activeSheet = .checkConstraint(CheckConstraintEditorPresentation(constraintID: model.id, isNew: true))
    }

    internal func presentCheckConstraintEditor(for constraint: TableStructureEditorViewModel.CheckConstraintModel) {
        activeSheet = .checkConstraint(CheckConstraintEditorPresentation(constraintID: constraint.id, isNew: constraint.isNew))
    }
}
