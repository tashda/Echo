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

    var body: some View {
        VStack(spacing: 0) {
            TabSectionToolbar {
                HStack(spacing: SpacingTokens.sm) {
                    Picker("Object Type", selection: $viewModel.selectedAdvancedObjectSection) {
                        ForEach(MySQLDatabaseSecurityViewModel.AdvancedObjectSection.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 170)

                    Picker("Database", selection: $viewModel.advancedObjectSchemaFilter) {
                        ForEach(viewModel.availableObjectSchemas, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)

                    if viewModel.isLoadingAdvancedObjects {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            } controls: {
                Button {
                    draftKind = draftKindForCurrentSection
                } label: {
                    Label(newButtonTitle, systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()

            MySQLAdvancedObjectsContent(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
