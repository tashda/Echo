import SwiftUI

struct PostgresDatabaseSecurityView: View {
    @Bindable var viewModel: PostgresDatabaseSecurityViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(\.workspaceTab) private var hostTab
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
            serverName: connectionText,
            isInitialized: viewModel.isInitialized,
            statusBubble: statusBubble
        ) {
            // Its pages are in the tab (round 36.2); Grant Wizard on the header line (37.2).
            sectionContent
        }
        .toolTabHeaderControls {
            ToolTabPrimaryButton(title: "Grant Wizard", systemImage: "key.fill") { showGrantWizard = true }
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
        let connText = hostTab?.connection.connectionName ?? "Server"
        let db = hostTab?.activeDatabaseName
        return db.map { "\(connText) \u{2022} \($0)" } ?? connText
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isLoadingSchemas || viewModel.isLoadingRoles || viewModel.isLoadingPolicies {
            return .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
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
