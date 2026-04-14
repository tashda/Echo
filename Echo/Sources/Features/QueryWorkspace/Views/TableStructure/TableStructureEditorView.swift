import SwiftUI

struct TableStructureEditorView: View {
    @Bindable var tab: WorkspaceTab
    @Bindable var viewModel: TableStructureEditorViewModel

    @Environment(ProjectStore.self) internal var projectStore
    @Environment(EnvironmentState.self) internal var environmentState

    @State internal var selectedSection: TableStructureSection
    @State internal var selectedColumnIDs: Set<TableStructureEditorViewModel.ColumnModel.ID> = []
    @State internal var selectedIndexIDs: Set<TableStructureEditorViewModel.IndexModel.ID> = []
    @State internal var selectedForeignKeyIDs: Set<TableStructureEditorViewModel.ForeignKeyModel.ID> = []
    @State internal var selectedConstraintIDs: Set<ConstraintRowModel.ID> = []

    internal var columnIndexLookup: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: viewModel.columns.enumerated().map { ($0.element.id, $0.offset) })
    }

    init(tab: WorkspaceTab, viewModel: TableStructureEditorViewModel) {
        self.tab = tab
        self.viewModel = viewModel
        _selectedSection = State(initialValue: viewModel.requestedSection ?? .columns)
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
            consumePendingAddActionIfNeeded()
            if viewModel.columns.isEmpty && !viewModel.isLoading {
                Task { await viewModel.reload() }
            }
        }
        .onChange(of: viewModel.requestedSection) { _, newSection in
            guard let newSection else { return }
            selectedSection = newSection
            viewModel.requestedSection = nil
        }
        .onChange(of: viewModel.pendingAddAction) { _, _ in
            consumePendingAddActionIfNeeded()
        }
        .onChange(of: selectedSection) {
            viewModel.lastError = nil
            viewModel.lastSuccessMessage = nil
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                NSCursor.arrow.set()
            case .ended:
                break
            }
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

    internal func checkConstraintBinding(for constraintID: UUID) -> Binding<TableStructureEditorViewModel.CheckConstraintModel>? {
        guard let index = viewModel.checkConstraints.firstIndex(where: { $0.id == constraintID }) else { return nil }
        return $viewModel.checkConstraints[index]
    }

    internal var primaryKeyBinding: Binding<TableStructureEditorViewModel.PrimaryKeyModel>? {
        guard let pk = viewModel.primaryKey else { return nil }
        return Binding(
            get: { self.viewModel.primaryKey ?? pk },
            set: { self.viewModel.primaryKey = $0 }
        )
    }

    internal func applyChanges() {
        Task {
            await viewModel.applyChanges()
            if let error = viewModel.lastError {
                environmentState.notificationEngine?.post(
                    category: .generalError,
                    message: error
                )
            } else if viewModel.lastSuccessMessage != nil {
                environmentState.notificationEngine?.post(
                    category: .generalSuccess,
                    icon: "checkmark.circle",
                    message: "Structure of \(viewModel.tableName) updated",
                    style: .success
                )
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

        viewModel.sheetCoordinator.activeSheet = nil
    }

    internal func consumePendingAddActionIfNeeded() {
        guard let action = viewModel.pendingAddAction else { return }
        viewModel.pendingAddAction = nil

        switch action {
        case .column:
            selectedSection = .columns
            presentNewColumn()
        case .index:
            selectedSection = .indexes
            presentNewIndex()
        case .foreignKey:
            selectedSection = .relations
            presentNewForeignKey()
        case .uniqueConstraint:
            selectedSection = .constraints
            presentNewUniqueConstraint()
        case .checkConstraint:
            selectedSection = .constraints
            presentNewCheckConstraint()
        }
    }
}
