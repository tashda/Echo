import SwiftUI

extension TableStructureEditorView {

    // MARK: - Constraint Presentation Helpers

    internal func presentPrimaryKeyEditor(isNew: Bool) {
        if isNew {
            viewModel.sheetCoordinator.pendingNewPrimaryKey = TableStructureEditorViewModel.PrimaryKeyModel(
                original: nil,
                name: "pk_\(viewModel.tableName)",
                columns: [],
                isDeferrable: false,
                isInitiallyDeferred: false
            )
            viewModel.sheetCoordinator.activeSheet = .newPrimaryKey
            return
        }

        guard viewModel.primaryKey != nil else { return }
        viewModel.sheetCoordinator.activeSheet = .primaryKey(PrimaryKeyEditorPresentation(isNew: isNew))
    }

    internal func presentNewUniqueConstraint() {
        viewModel.sheetCoordinator.pendingNewUniqueConstraint = TableStructureEditorViewModel.UniqueConstraintModel(
            original: nil,
            name: "uq_\(viewModel.tableName)_\(viewModel.uniqueConstraints.count + 1)",
            columns: [],
            isDeferrable: false,
            isInitiallyDeferred: false
        )
        viewModel.sheetCoordinator.activeSheet = .newUniqueConstraint
    }

    internal func presentUniqueConstraintEditor(for constraint: TableStructureEditorViewModel.UniqueConstraintModel) {
        viewModel.sheetCoordinator.activeSheet = .uniqueConstraint(UniqueConstraintEditorPresentation(constraintID: constraint.id, isNew: constraint.isNew))
    }

    internal func presentNewCheckConstraint() {
        viewModel.sheetCoordinator.pendingNewCheckConstraint = TableStructureEditorViewModel.CheckConstraintModel(
            original: nil,
            name: "ck_\(viewModel.tableName)_\(viewModel.checkConstraints.count + 1)",
            expression: ""
        )
        viewModel.sheetCoordinator.activeSheet = .newCheckConstraint
    }

    internal func presentCheckConstraintEditor(for constraint: TableStructureEditorViewModel.CheckConstraintModel) {
        viewModel.sheetCoordinator.activeSheet = .checkConstraint(CheckConstraintEditorPresentation(constraintID: constraint.id, isNew: constraint.isNew))
    }
}
