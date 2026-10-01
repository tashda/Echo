import SwiftUI

struct MySQLAdvancedObjectsView: View {
    @Bindable var viewModel: MySQLDatabaseSecurityViewModel

    @State private var draftKind: DraftKind?

    enum DraftKind: String, Identifiable {
        case function
        case procedure
        case trigger
        case event

        var id: String { rawValue }
    }

    @ViewBuilder
    private var headerControls: some View {
        ToolTabPickerPill(title: "Object Type", systemImage: "square.stack.3d.up",
                          selection: $viewModel.selectedAdvancedObjectSection,
                          options: MySQLDatabaseSecurityViewModel.AdvancedObjectSection.allCases, label: \.rawValue)
        ToolTabPickerPill(title: "Database", systemImage: "cylinder", selection: $viewModel.advancedObjectSchemaFilter,
                          options: viewModel.availableObjectSchemas, label: { $0 })
    }

    var body: some View {
        // Its object type and database sit on the header line (37.2), New in the toolbar (37.5).
        VStack(spacing: SpacingTokens.none) {
            MySQLAdvancedObjectsContent(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolTabHeaderControls { headerControls }
        // Round 37.5: New Function, Procedure, Trigger or Event is the page's special button.
        .tabToolbar(
            special: TabToolbarItem(id: "newObject", title: newButtonTitle, symbol: "plus") { draftKind = draftKindForCurrentSection },
            groups: [[.refresh(isBusy: viewModel.isLoadingAdvancedObjects) { [viewModel] in Task { await viewModel.loadCurrentSection() } }]]
        )
        .task {
            guard !viewModel.isInitialized else { return }
            await viewModel.initialize()
        }
        .onChange(of: viewModel.selectedAdvancedObjectSection) { _, _ in
            guard viewModel.selectedSection == .advancedObjects else { return }
            Task {
                await viewModel.loadSelectedAdvancedObjectDefinition()
            }
        }
        .onChange(of: viewModel.advancedObjectSchemaFilter) { _, _ in
            guard viewModel.selectedSection == .advancedObjects else { return }
            Task {
                await viewModel.loadCurrentSection()
            }
        }
        .sheet(item: $draftKind) { kind in
            MySQLProgrammableObjectTemplateSheet(
                kind: kind,
                schema: viewModel.advancedObjectSchemaFilter,
                connectionID: viewModel.connectionID
            ) {
                draftKind = nil
                Task { await viewModel.loadCurrentSection() }
            }
        }
    }

    private var draftKindForCurrentSection: DraftKind {
        switch viewModel.selectedAdvancedObjectSection {
        case .functions: .function
        case .procedures: .procedure
        case .triggers: .trigger
        case .events: .event
        }
    }

    private var newButtonTitle: String {
        switch viewModel.selectedAdvancedObjectSection {
        case .functions: "New Function"
        case .procedures: "New Procedure"
        case .triggers: "New Trigger"
        case .events: "New Event"
        }
    }
}
