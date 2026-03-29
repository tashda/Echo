import SwiftUI

struct PostgresDatabaseSecurityView: View {
    @Bindable var viewModel: PostgresDatabaseSecurityViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState

    @Environment(\.openWindow) private var openWindow
    @State private var showNewSchemaSheet = false
    @State private var showNewPolicySheet = false
    @State private var showGrantWizard = false

    private var session: ConnectionSession? {
        environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)
    }

    var body: some View {
        MaintenanceTabFrame(
            panelState: panelState,
            connectionText: connectionText,
            isInitialized: viewModel.isInitialized,
            statusBubble: statusBubble
        ) {
            sectionPicker
        } content: {
            sectionContent
        }
        .task {
            await viewModel.initialize()
        }
        .onChange(of: viewModel.selectedSection) { _, _ in
            guard viewModel.isInitialized else { return }
            Task { await viewModel.loadCurrentSection() }
        }
        .sheet(isPresented: $showNewSchemaSheet) {
            PostgresNewSchemaSheet(viewModel: viewModel) {
                showNewSchemaSheet = false
                Task { await viewModel.loadCurrentSection() }
            }
        }
        .sheet(isPresented: $showNewPolicySheet) {
            PostgresNewPolicySheet(viewModel: viewModel) {
                showNewPolicySheet = false
                Task { await viewModel.loadCurrentSection() }
            }
        }
        .sheet(isPresented: $showGrantWizard) {
            PostgresGrantWizardSheet(
                viewModel: makeGrantWizardViewModel(),
                session: viewModel.session,
                onComplete: {
                    showGrantWizard = false
                    Task { await viewModel.loadCurrentSection() }
                }
            )
        }
    }

    private var connectionText: String {
        let connText = tabStore.activeTab?.connection.connectionName ?? "Server"
        let db = tabStore.activeTab?.activeDatabaseName
        return db.map { "\(connText) \u{2022} \($0)" } ?? connText
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isLoadingSchemas || viewModel.isLoadingRoles || viewModel.isLoadingPolicies {
            return .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
    }

    private var sectionPicker: some View {
        HStack(spacing: SpacingTokens.md) {
            Picker(selection: $viewModel.selectedSection) {
                ForEach(PostgresDatabaseSecurityViewModel.Section.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)

            Spacer()

            Button {
                showGrantWizard = true
            } label: {
                Label("Grant Wizard", systemImage: "key.badge.plus")
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        VStack(spacing: 0) {
            switch viewModel.selectedSection {
            case .schemas:
                PostgresSchemasSection(
                    viewModel: viewModel,
                    onNewSchema: { showNewSchemaSheet = true }
                )
            case .roles:
                PostgresRolesSection(viewModel: viewModel, onNewRole: openNewRoleEditor)
            case .policies:
                PostgresPoliciesSection(
                    viewModel: viewModel,
                    onNewPolicy: { showNewPolicySheet = true }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func makeGrantWizardViewModel() -> PostgresGrantWizardViewModel {
        let vm = PostgresGrantWizardViewModel(connectionSessionID: viewModel.connectionSessionID)
        vm.activityEngine = viewModel.activityEngine
        vm.setPanelState(panelState)
        return vm
    }

    private func openNewRoleEditor() {
        let value = environmentState.preparePgRoleEditorWindow(
            connectionSessionID: viewModel.connectionID,
            existingRole: nil
        )
        openWindow(id: PgRoleEditorWindow.sceneID, value: value)
    }
}
