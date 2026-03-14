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
    @State internal var selectedIndexIDs: Set<TableStructureEditorViewModel.IndexModel.ID> = []
    @State internal var selectedForeignKeyIDs: Set<TableStructureEditorViewModel.ForeignKeyModel.ID> = []
    @State internal var columnIndexLookup: [UUID: Int] = [:]
    @State internal var bulkColumnEditor: BulkColumnEditorPresentation?

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

    internal var visibleColumns: [TableStructureEditorViewModel.ColumnModel] {
        viewModel.columns.filter { !$0.isDeleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(ColorTokens.Background.primary)
        .onAppear {
            if let requested = viewModel.requestedSection {
                selectedSection = requested
                viewModel.requestedSection = nil
            }
            if viewModel.columns.isEmpty {
                Task { await viewModel.reload() }
            }
        }
        .onChange(of: viewModel.columns) { _, _ in
            rebuildColumnIndexLookup()
            pruneSelectedColumns()
        }
        .background { sheetModifiers }
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

    internal func applyBulkEdit(
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
