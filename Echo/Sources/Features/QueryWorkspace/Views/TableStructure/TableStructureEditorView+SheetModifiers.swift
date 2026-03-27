import SwiftUI

extension TableStructureEditorView {
    @ViewBuilder
    var sheetModifiers: some View {
        Color.clear
            .sheet(item: $activeSheet) { sheet in
                sheetContent(for: sheet)
            }
    }

    @ViewBuilder
    private func sheetContent(for sheet: TableStructureSheet) -> some View {
        switch sheet {
        case .index(let presentation):
            if let binding = indexBinding(for: presentation.indexID) {
                IndexEditorSheet(
                    index: binding,
                    availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                    databaseType: tab.connection.databaseType,
                    onDelete: {
                        viewModel.removeIndex(binding.wrappedValue)
                        activeSheet = nil
                    },
                    onCancelNew: {
                        if binding.wrappedValue.isNew {
                            viewModel.removeIndex(binding.wrappedValue)
                        }
                        activeSheet = nil
                    }
                )
            }

        case .column(let presentation):
            if let binding = columnBinding(for: presentation.columnID) {
                ColumnEditorSheet(
                    column: binding,
                    databaseType: tab.connection.databaseType,
                    onDelete: {
                        viewModel.removeColumn(binding.wrappedValue)
                        activeSheet = nil
                    },
                    onCancelNew: {
                        if binding.wrappedValue.isNew {
                            viewModel.removeColumn(binding.wrappedValue)
                        }
                        activeSheet = nil
                    }
                )
            }

        case .primaryKey(let presentation):
            if let binding = primaryKeyBinding {
                PrimaryKeyEditorSheet(
                    primaryKey: binding,
                    availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                    databaseType: tab.connection.databaseType,
                    onDelete: {
                        viewModel.removePrimaryKey()
                        activeSheet = nil
                    },
                    onCancelNew: {
                        if presentation.isNew {
                            viewModel.removePrimaryKey()
                        }
                        activeSheet = nil
                    }
                )
            }

        case .uniqueConstraint(let presentation):
            if let binding = uniqueConstraintBinding(for: presentation.constraintID) {
                UniqueConstraintEditorSheet(
                    constraint: binding,
                    availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                    databaseType: tab.connection.databaseType,
                    onDelete: {
                        viewModel.removeUniqueConstraint(binding.wrappedValue)
                        activeSheet = nil
                    },
                    onCancelNew: {
                        if binding.wrappedValue.isNew {
                            viewModel.removeUniqueConstraint(binding.wrappedValue)
                        }
                        activeSheet = nil
                    }
                )
            }

        case .foreignKey(let presentation):
            if let binding = foreignKeyBinding(for: presentation.foreignKeyID) {
                ForeignKeyEditorSheet(
                    foreignKey: binding,
                    availableColumns: viewModel.columns.filter { !$0.isDeleted }.map { $0.name },
                    databaseType: tab.connection.databaseType,
                    session: viewModel.session,
                    onDelete: {
                        viewModel.removeForeignKey(binding.wrappedValue)
                        activeSheet = nil
                    },
                    onCancelNew: {
                        if binding.wrappedValue.isNew {
                            viewModel.removeForeignKey(binding.wrappedValue)
                        }
                        activeSheet = nil
                    }
                )
            }

        case .checkConstraint(let presentation):
            if let binding = checkConstraintBinding(for: presentation.constraintID) {
                CheckConstraintEditorSheet(
                    constraint: binding,
                    onDelete: {
                        viewModel.removeCheckConstraint(binding.wrappedValue)
                        activeSheet = nil
                    },
                    onCancelNew: {
                        if binding.wrappedValue.isNew {
                            viewModel.removeCheckConstraint(binding.wrappedValue)
                        }
                        activeSheet = nil
                    }
                )
            }

        case .scriptPreview:
            ScriptPreviewSheet(statements: scriptPreviewStatements)

        case .bulkColumn(let presentation):
            BulkColumnEditorSheet(
                mode: presentation.mode,
                columnNames: presentation.columnIDs.compactMap { id in visibleColumns.first(where: { $0.id == id })?.name },
                databaseType: tab.connection.databaseType,
                onApply: { value in
                    let targets = presentation.columnIDs.compactMap { id in columnBinding(for: id) }
                    applyBulkEdit(mode: presentation.mode, value: value, bindings: targets)
                },
                onCancel: { activeSheet = nil }
            )
        }
    }
}
