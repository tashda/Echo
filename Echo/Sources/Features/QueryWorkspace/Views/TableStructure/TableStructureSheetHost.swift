import SwiftUI

struct TableStructureSheetHost: View {
    @Bindable var tab: WorkspaceTab
    @Bindable var viewModel: TableStructureEditorViewModel

    var body: some View {
        Color.clear
            .sheet(
                item: Binding(
                    get: { viewModel.sheetCoordinator.activeSheet },
                    set: { viewModel.sheetCoordinator.activeSheet = $0 }
                )
            ) { sheet in
                sheetContent(for: sheet)
            }
    }

    @ViewBuilder
    private func sheetContent(for sheet: TableStructureSheet) -> some View {
        switch sheet {
        case .newIndex:
            if let binding = pendingNewIndexBinding {
                IndexEditorSheet(
                    index: binding,
                    availableColumns: availableColumnNames,
                    databaseType: tab.connection.databaseType,
                    onDelete: { dismissNewIndex() },
                    onCancelNew: { dismissNewIndex() },
                    onSaveNew: { model in
                        viewModel.indexes.append(model)
                        dismissNewIndex()
                    }
                )
            }

        case .index(let presentation):
            if let binding = indexBinding(for: presentation.indexID) {
                IndexEditorSheet(
                    index: binding,
                    availableColumns: availableColumnNames,
                    databaseType: tab.connection.databaseType,
                    onDelete: {
                        viewModel.removeIndex(binding.wrappedValue)
                        dismiss()
                    },
                    onCancelNew: { dismiss() },
                    onSaveNew: nil
                )
            }

        case .newColumn:
            NewColumnSheetHost(databaseType: tab.connection.databaseType) { model in
                viewModel.columns.append(model)
                dismiss()
            } onCancel: {
                dismiss()
            }

        case .column(let presentation):
            if let binding = columnBinding(for: presentation.columnID) {
                ColumnEditorSheet(
                    column: binding,
                    databaseType: tab.connection.databaseType,
                    onDelete: {
                        viewModel.removeColumn(binding.wrappedValue)
                        dismiss()
                    },
                    onCancelNew: { dismiss() },
                    onSaveNew: nil
                )
            }

        case .newPrimaryKey:
            if let binding = pendingNewPrimaryKeyBinding {
                PrimaryKeyEditorSheet(
                    primaryKey: binding,
                    availableColumns: availableColumnNames,
                    databaseType: tab.connection.databaseType,
                    onDelete: { dismissNewPrimaryKey() },
                    onCancelNew: { dismissNewPrimaryKey() },
                    onSaveNew: { model in
                        viewModel.primaryKey = model
                        viewModel.clearPrimaryKeyRemoval()
                        dismissNewPrimaryKey()
                    }
                )
            }

        case .primaryKey(let presentation):
            if let binding = primaryKeyBinding {
                PrimaryKeyEditorSheet(
                    primaryKey: binding,
                    availableColumns: availableColumnNames,
                    databaseType: tab.connection.databaseType,
                    onDelete: {
                        viewModel.removePrimaryKey()
                        dismiss()
                    },
                    onCancelNew: {
                        if presentation.isNew {
                            viewModel.removePrimaryKey()
                        }
                        dismiss()
                    },
                    onSaveNew: nil
                )
            }

        case .newUniqueConstraint:
            if let binding = pendingNewUniqueConstraintBinding {
                UniqueConstraintEditorSheet(
                    constraint: binding,
                    availableColumns: availableColumnNames,
                    databaseType: tab.connection.databaseType,
                    onDelete: { dismissNewUniqueConstraint() },
                    onCancelNew: { dismissNewUniqueConstraint() },
                    onSaveNew: { model in
                        viewModel.uniqueConstraints.append(model)
                        dismissNewUniqueConstraint()
                    }
                )
            }

        case .uniqueConstraint(let presentation):
            if let binding = uniqueConstraintBinding(for: presentation.constraintID) {
                UniqueConstraintEditorSheet(
                    constraint: binding,
                    availableColumns: availableColumnNames,
                    databaseType: tab.connection.databaseType,
                    onDelete: {
                        viewModel.removeUniqueConstraint(binding.wrappedValue)
                        dismiss()
                    },
                    onCancelNew: {
                        if binding.wrappedValue.isNew {
                            viewModel.removeUniqueConstraint(binding.wrappedValue)
                        }
                        dismiss()
                    },
                    onSaveNew: nil
                )
            }

        case .newForeignKey:
            if let binding = pendingNewForeignKeyBinding {
                ForeignKeyEditorSheet(
                    foreignKey: binding,
                    availableColumns: availableColumnNames,
                    databaseType: tab.connection.databaseType,
                    session: viewModel.session,
                    onDelete: { dismissNewForeignKey() },
                    onCancelNew: { dismissNewForeignKey() },
                    onSaveNew: { model in
                        viewModel.foreignKeys.append(model)
                        dismissNewForeignKey()
                    }
                )
            }

        case .foreignKey(let presentation):
            if let binding = foreignKeyBinding(for: presentation.foreignKeyID) {
                ForeignKeyEditorSheet(
                    foreignKey: binding,
                    availableColumns: availableColumnNames,
                    databaseType: tab.connection.databaseType,
                    session: viewModel.session,
                    onDelete: {
                        viewModel.removeForeignKey(binding.wrappedValue)
                        dismiss()
                    },
                    onCancelNew: {
                        if binding.wrappedValue.isNew {
                            viewModel.removeForeignKey(binding.wrappedValue)
                        }
                        dismiss()
                    },
                    onSaveNew: nil
                )
            }

        case .newCheckConstraint:
            if let binding = pendingNewCheckConstraintBinding {
                CheckConstraintEditorSheet(
                    constraint: binding,
                    onDelete: { dismissNewCheckConstraint() },
                    onCancelNew: { dismissNewCheckConstraint() },
                    onSaveNew: { model in
                        viewModel.checkConstraints.append(model)
                        dismissNewCheckConstraint()
                    }
                )
            }

        case .checkConstraint(let presentation):
            if let binding = checkConstraintBinding(for: presentation.constraintID) {
                CheckConstraintEditorSheet(
                    constraint: binding,
                    onDelete: {
                        viewModel.removeCheckConstraint(binding.wrappedValue)
                        dismiss()
                    },
                    onCancelNew: {
                        if binding.wrappedValue.isNew {
                            viewModel.removeCheckConstraint(binding.wrappedValue)
                        }
                        dismiss()
                    },
                    onSaveNew: nil
                )
            }

        case .bulkColumn(let presentation):
            BulkColumnEditorSheet(
                mode: presentation.mode,
                columnNames: presentation.columnIDs.compactMap { id in
                    viewModel.columns.first(where: { $0.id == id && !$0.isDeleted })?.name
                },
                databaseType: tab.connection.databaseType,
                onApply: { value in
                    let targets = presentation.columnIDs.compactMap { id in columnBinding(for: id) }
                    applyBulkEdit(mode: presentation.mode, value: value, bindings: targets)
                },
                onCancel: { dismiss() }
            )
        }
    }

    private var availableColumnNames: [String] {
        viewModel.columns.filter { !$0.isDeleted }.map(\.name)
    }

    private func dismiss() {
        viewModel.sheetCoordinator.activeSheet = nil
    }

    private func columnBinding(for columnID: UUID) -> Binding<TableStructureEditorViewModel.ColumnModel>? {
        guard let index = viewModel.columns.firstIndex(where: { $0.id == columnID }) else { return nil }
        return $viewModel.columns[index]
    }

    private func indexBinding(for indexID: UUID) -> Binding<TableStructureEditorViewModel.IndexModel>? {
        guard let index = viewModel.indexes.firstIndex(where: { $0.id == indexID }) else { return nil }
        return $viewModel.indexes[index]
    }

    private func uniqueConstraintBinding(for constraintID: UUID) -> Binding<TableStructureEditorViewModel.UniqueConstraintModel>? {
        guard let index = viewModel.uniqueConstraints.firstIndex(where: { $0.id == constraintID }) else { return nil }
        return $viewModel.uniqueConstraints[index]
    }

    private func foreignKeyBinding(for foreignKeyID: UUID) -> Binding<TableStructureEditorViewModel.ForeignKeyModel>? {
        guard let index = viewModel.foreignKeys.firstIndex(where: { $0.id == foreignKeyID }) else { return nil }
        return $viewModel.foreignKeys[index]
    }

    private func checkConstraintBinding(for constraintID: UUID) -> Binding<TableStructureEditorViewModel.CheckConstraintModel>? {
        guard let index = viewModel.checkConstraints.firstIndex(where: { $0.id == constraintID }) else { return nil }
        return $viewModel.checkConstraints[index]
    }

    private var primaryKeyBinding: Binding<TableStructureEditorViewModel.PrimaryKeyModel>? {
        guard let primaryKey = viewModel.primaryKey else { return nil }
        return Binding(
            get: { viewModel.primaryKey ?? primaryKey },
            set: { viewModel.primaryKey = $0 }
        )
    }

    private var pendingNewIndexBinding: Binding<TableStructureEditorViewModel.IndexModel>? {
        guard let pendingNewIndex = viewModel.sheetCoordinator.pendingNewIndex else { return nil }
        return Binding(
            get: { viewModel.sheetCoordinator.pendingNewIndex ?? pendingNewIndex },
            set: { viewModel.sheetCoordinator.pendingNewIndex = $0 }
        )
    }

    private var pendingNewPrimaryKeyBinding: Binding<TableStructureEditorViewModel.PrimaryKeyModel>? {
        guard let pendingNewPrimaryKey = viewModel.sheetCoordinator.pendingNewPrimaryKey else { return nil }
        return Binding(
            get: { viewModel.sheetCoordinator.pendingNewPrimaryKey ?? pendingNewPrimaryKey },
            set: { viewModel.sheetCoordinator.pendingNewPrimaryKey = $0 }
        )
    }

    private var pendingNewUniqueConstraintBinding: Binding<TableStructureEditorViewModel.UniqueConstraintModel>? {
        guard let pendingNewUniqueConstraint = viewModel.sheetCoordinator.pendingNewUniqueConstraint else { return nil }
        return Binding(
            get: { viewModel.sheetCoordinator.pendingNewUniqueConstraint ?? pendingNewUniqueConstraint },
            set: { viewModel.sheetCoordinator.pendingNewUniqueConstraint = $0 }
        )
    }

    private var pendingNewForeignKeyBinding: Binding<TableStructureEditorViewModel.ForeignKeyModel>? {
        guard let pendingNewForeignKey = viewModel.sheetCoordinator.pendingNewForeignKey else { return nil }
        return Binding(
            get: { viewModel.sheetCoordinator.pendingNewForeignKey ?? pendingNewForeignKey },
            set: { viewModel.sheetCoordinator.pendingNewForeignKey = $0 }
        )
    }

    private var pendingNewCheckConstraintBinding: Binding<TableStructureEditorViewModel.CheckConstraintModel>? {
        guard let pendingNewCheckConstraint = viewModel.sheetCoordinator.pendingNewCheckConstraint else { return nil }
        return Binding(
            get: { viewModel.sheetCoordinator.pendingNewCheckConstraint ?? pendingNewCheckConstraint },
            set: { viewModel.sheetCoordinator.pendingNewCheckConstraint = $0 }
        )
    }

    private func dismissNewIndex() {
        viewModel.sheetCoordinator.pendingNewIndex = nil
        dismiss()
    }

    private func dismissNewPrimaryKey() {
        viewModel.sheetCoordinator.pendingNewPrimaryKey = nil
        dismiss()
    }

    private func dismissNewUniqueConstraint() {
        viewModel.sheetCoordinator.pendingNewUniqueConstraint = nil
        dismiss()
    }

    private func dismissNewForeignKey() {
        viewModel.sheetCoordinator.pendingNewForeignKey = nil
        dismiss()
    }

    private func dismissNewCheckConstraint() {
        viewModel.sheetCoordinator.pendingNewCheckConstraint = nil
        dismiss()
    }

    private func applyBulkEdit(
        mode: BulkColumnEditorPresentation.Mode,
        value: BulkColumnEditValue,
        bindings: [Binding<TableStructureEditorViewModel.ColumnModel>]
    ) {
        for binding in bindings {
            switch mode {
            case .dataType:
                if case let .dataType(newType) = value {
                    binding.wrappedValue.dataType = newType
                }
            case .defaultValue:
                if case let .defaultValue(newValue) = value {
                    binding.wrappedValue.defaultValue = newValue
                }
            case .generatedExpression:
                if case let .generatedExpression(newValue) = value {
                    binding.wrappedValue.generatedExpression = newValue
                }
            }
        }

        dismiss()
    }
}

private struct NewColumnSheetHost: View {
    @State private var column: TableStructureEditorViewModel.ColumnModel
    let databaseType: DatabaseType
    let onSave: (TableStructureEditorViewModel.ColumnModel) -> Void
    let onCancel: () -> Void

    init(
        databaseType: DatabaseType,
        onSave: @escaping (TableStructureEditorViewModel.ColumnModel) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.databaseType = databaseType
        self.onSave = onSave
        self.onCancel = onCancel

        let defaultType: String = switch databaseType {
        case .mysql: "varchar(255)"
        case .microsoftSQL: "nvarchar(255)"
        default: "text"
        }

        _column = State(
            initialValue: TableStructureEditorViewModel.ColumnModel(
                original: nil,
                name: "new_column",
                dataType: defaultType,
                isNullable: true,
                defaultValue: nil,
                generatedExpression: nil,
                isIdentity: false,
                identitySeed: nil,
                identityIncrement: nil,
                identityGeneration: nil,
                collation: nil,
                characterSet: nil,
                comment: nil,
                isUnsigned: false,
                isZerofill: false,
                ordinalPosition: nil
            )
        )
    }

    var body: some View {
        ColumnEditorSheet(
            column: $column,
            databaseType: databaseType,
            onDelete: onCancel,
            onCancelNew: onCancel,
            onSaveNew: onSave
        )
    }
}
