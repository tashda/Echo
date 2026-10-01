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
        ToolTabActionGroup {
            ToolTabRefreshButton(isRefreshing: viewModel.isLoadingAdvancedObjects) {
                Task { await viewModel.loadCurrentSection() }
            }
        }
        ToolTabPrimaryButton(title: newButtonTitle, systemImage: "plus") { draftKind = draftKindForCurrentSection }
    }

    var body: some View {
        // Its object type, database and New sit on the tool's header line (round 37.2, 37.3).
        VStack(spacing: SpacingTokens.none) {
            MySQLAdvancedObjectsContent(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolTabHeaderControls { headerControls }
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
