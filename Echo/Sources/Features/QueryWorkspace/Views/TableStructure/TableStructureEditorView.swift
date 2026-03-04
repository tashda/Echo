import SwiftUI
import Combine

struct TableStructureEditorView: View {
    @ObservedObject var tab: WorkspaceTab
    @ObservedObject var viewModel: TableStructureEditorViewModel
    
    @Environment(ProjectStore.self) internal var projectStore
    @EnvironmentObject internal var environmentState: EnvironmentState
    
    @State internal var activeIndexEditor: IndexEditorPresentation?
    @State internal var activeColumnEditor: ColumnEditorPresentation?
    @State internal var activePrimaryKeyEditor: PrimaryKeyEditorPresentation?
    @State internal var activeUniqueConstraintEditor: UniqueConstraintEditorPresentation?
    @State internal var activeForeignKeyEditor: ForeignKeyEditorPresentation?
    @State internal var selectedSection: TableStructureSection
    @State internal var selectedColumnIDs: Set<TableStructureEditorViewModel.ColumnModel.ID> = []
    @State internal var columnIndexLookup: [UUID: Int] = [:]
    @State internal var selectionAnchor: TableStructureEditorViewModel.ColumnModel.ID?
    @FocusState internal var focusedCustomColumnID: TableStructureEditorViewModel.ColumnModel.ID?
    @State internal var bulkColumnEditor: BulkColumnEditorPresentation?
    @EnvironmentObject internal var themeManager: ThemeManager

    init(tab: WorkspaceTab, viewModel: TableStructureEditorViewModel) {
        _tab = ObservedObject(initialValue: tab)
        _viewModel = ObservedObject(initialValue: viewModel)
        _selectedSection = State(initialValue: viewModel.requestedSection ?? .columns)
        
        // Initialize column index lookup
        _columnIndexLookup = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: viewModel.columns.enumerated().map { pair in
                    let (index, column) = pair
                    return (column.id, index)
                }
            )
        )
    }

    // Direct access to visible columns - no caching
    internal var visibleColumns: [TableStructureEditorViewModel.ColumnModel] {
        viewModel.columns.filter { !$0.isDeleted }
    }
    
    internal var cachedVisibleColumns: [TableStructureEditorViewModel.ColumnModel] {
        viewModel.columns.filter { !$0.isDeleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(ColorTokens.Background.primary)
        .task {
            // Lightweight initialization
            if let requested = viewModel.requestedSection {
                selectedSection = requested
                viewModel.requestedSection = nil
            }
        }
        .onChange(of: viewModel.columns) { _, _ in
            // Rebuild lookup when columns change
            rebuildColumnIndexLookup()
            pruneSelectedColumns()
        }
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
                onApply: { value in
                    let targets = presentation.columnIDs.compactMap { id in columnBinding(for: id) }
                    applyBulkEdit(mode: presentation.mode, value: value, bindings: targets)
                },
                onCancel: { bulkColumnEditor = nil }
            )
        }
    }

    internal func columnBinding(for columnID: UUID) -> Binding<TableStructureEditorViewModel.ColumnModel>? {
        guard let index = columnIndexLookup[columnID], index < viewModel.columns.count else { return nil }
        return $viewModel.columns[index]
    }

    internal func indexBinding(for indexID: UUID) -> Binding<TableStructureEditorViewModel.IndexModel>? {
        guard let position = viewModel.indexes.firstIndex(where: { $0.id == indexID }) else { return nil }
        return $viewModel.indexes[position]
    }

    internal func uniqueConstraintBinding(for constraintID: UUID) -> Binding<TableStructureEditorViewModel.UniqueConstraintModel>? {
        guard let index = viewModel.uniqueConstraints.firstIndex(where: { $0.id == constraintID }) else { return nil }
        return $viewModel.uniqueConstraints[index]
    }

    internal func foreignKeyBinding(for foreignKeyID: UUID) -> Binding<TableStructureEditorViewModel.ForeignKeyModel>? {
        guard let index = viewModel.foreignKeys.firstIndex(where: { $0.id == foreignKeyID }) else { return nil }
        return $viewModel.foreignKeys[index]
    }

    internal var primaryKeyBinding: Binding<TableStructureEditorViewModel.PrimaryKeyModel>? {
        guard viewModel.primaryKey != nil else { return nil }
        return Binding(
            get: { viewModel.primaryKey! },
            set: { viewModel.primaryKey = $0 }
        )
    }

    internal func applyChanges() {
        Task {
            await viewModel.applyChanges()
            if viewModel.lastError == nil {
                await environmentState.refreshDatabaseStructure(
                    for: tab.connectionSessionID,
                    scope: .selectedDatabase,
                    databaseOverride: tab.connection.database.isEmpty ? nil : tab.connection.database
                )
            }
        }
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

        bulkColumnEditor = nil
    }
}
