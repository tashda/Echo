import SwiftUI

extension TableStructureEditorView {
    @ViewBuilder
    var sheetModifiers: some View {
        Color.clear
            .sheet(item: $activeIndexEditor) { presentation in
                if let binding = indexBinding(for: presentation.indexID) {
                    IndexEditorSheet(
                        index: binding,
                        availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                        onDelete: {
                            viewModel.removeIndex(binding.wrappedValue)
                            activeIndexEditor = nil
                        },
                        onCancelNew: {
                            if binding.wrappedValue.isNew {
                                viewModel.removeIndex(binding.wrappedValue)
                            }
                            activeIndexEditor = nil
                        }
                    )
                }
            }
            .sheet(item: $activeColumnEditor) { presentation in
                if let binding = columnBinding(for: presentation.columnID) {
                    ColumnEditorSheet(
                        column: binding,
                        databaseType: tab.connection.databaseType,
                        onDelete: {
                            viewModel.removeColumn(binding.wrappedValue)
                            activeColumnEditor = nil
                        },
                        onCancelNew: {
                            if binding.wrappedValue.isNew {
                                viewModel.removeColumn(binding.wrappedValue)
                            }
                            activeColumnEditor = nil
                        }
                    )
                }
            }
            .sheet(item: $activePrimaryKeyEditor) { presentation in
                if let binding = primaryKeyBinding {
                    PrimaryKeyEditorSheet(
                        primaryKey: binding,
                        availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                        onDelete: {
                            viewModel.removePrimaryKey()
                            activePrimaryKeyEditor = nil
                        },
                        onCancelNew: {
                            if presentation.isNew {
                                viewModel.removePrimaryKey()
                            }
                            activePrimaryKeyEditor = nil
                        }
                    )
                }
            }
            .sheet(item: $activeUniqueConstraintEditor) { presentation in
                if let binding = uniqueConstraintBinding(for: presentation.constraintID) {
                    UniqueConstraintEditorSheet(
                        constraint: binding,
                        availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                        onDelete: {
                            viewModel.removeUniqueConstraint(binding.wrappedValue)
                            activeUniqueConstraintEditor = nil
                        },
                        onCancelNew: {
                            if binding.wrappedValue.isNew {
                                viewModel.removeUniqueConstraint(binding.wrappedValue)
                            }
                            activeUniqueConstraintEditor = nil
                        }
                    )
                }
            }
            .sheet(item: $activeForeignKeyEditor) { presentation in
                if let binding = foreignKeyBinding(for: presentation.foreignKeyID) {
                    ForeignKeyEditorSheet(
                        foreignKey: binding,
                        availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                        onDelete: {
                            viewModel.removeForeignKey(binding.wrappedValue)
                            activeForeignKeyEditor = nil
                        },
                        onCancelNew: {
                            if binding.wrappedValue.isNew {
                                viewModel.removeForeignKey(binding.wrappedValue)
                            }
                            activeForeignKeyEditor = nil
                        }
                    )
                }
            }
            .sheet(item: $bulkColumnEditor) { presentation in
                BulkColumnEditorSheet(
                    mode: presentation.mode,
                    columnNames: presentation.columnIDs.compactMap { id in visibleColumns.first(where: { $0.id == id })?.name },
                    databaseType: tab.connection.databaseType,
                    onApply: { value in
                        let targets = presentation.columnIDs.compactMap { id in columnBinding(for: id) }
                        applyBulkEdit(mode: presentation.mode, value: value, bindings: targets)
                    },
                    onCancel: { bulkColumnEditor = nil }
                )
            }
    }
}
