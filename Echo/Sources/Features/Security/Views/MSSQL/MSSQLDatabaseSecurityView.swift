import SwiftUI

struct MSSQLDatabaseSecurityView: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState

    @State private var showNewRoleSheet = false
    @State private var showNewSchemaSheet = false
    @State private var showNewAppRoleSheet = false
    @State private var showNewMaskSheet = false
    @State private var showNewAuditSpecSheet = false
    @State private var showNewCMKSheet = false
    @State private var showNewCEKSheet = false

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
            await viewModel.loadDatabases()
        }
        .onChange(of: viewModel.selectedSection) { _, _ in
            guard viewModel.isInitialized else { return }
            Task { await viewModel.loadCurrentSection() }
        }
        .onChange(of: viewModel.selectedDatabase) { _, newDB in
            guard let newDB else { return }
            if let tab = tabStore.activeTab, tab.databaseSecurity != nil {
                tab.title = "Database Security (\(newDB))"
                tab.activeDatabaseName = newDB
            }
        }
        .sheet(isPresented: $showNewRoleSheet) {
            NewDatabaseRoleSheet(viewModel: viewModel) {
                showNewRoleSheet = false
                Task { await viewModel.loadCurrentSection() }
            }
        }
        .sheet(isPresented: $showNewSchemaSheet) {
            NewSchemaSheet(viewModel: viewModel) {
                showNewSchemaSheet = false
                Task { await viewModel.loadCurrentSection() }
            }
        }
        .sheet(isPresented: $showNewAppRoleSheet) {
            NewAppRoleSheet(viewModel: viewModel) {
                showNewAppRoleSheet = false
                Task { await viewModel.loadCurrentSection() }
            }
        }
        .sheet(isPresented: $showNewMaskSheet) {
            if let session {
                NewMaskSheet(session: session, database: viewModel.selectedDatabase) {
                    showNewMaskSheet = false
                    Task { await viewModel.loadCurrentSection() }
                }
            }
        }
        .sheet(isPresented: $showNewAuditSpecSheet) {
            if let session {
                NewDBAuditSpecSheet(session: session, database: viewModel.selectedDatabase) {
                    showNewAuditSpecSheet = false
                    Task { await viewModel.loadCurrentSection() }
                }
            }
        }
        .sheet(isPresented: $showNewCMKSheet) {
            if let session {
                NewColumnMasterKeySheet(session: session, database: viewModel.selectedDatabase) {
                    showNewCMKSheet = false
                    Task { await viewModel.loadCurrentSection() }
                }
            }
        }
        .sheet(isPresented: $showNewCEKSheet) {
            if let session {
                NewColumnEncryptionKeySheet(session: session, database: viewModel.selectedDatabase) {
                    showNewCEKSheet = false
                    Task { await viewModel.loadCurrentSection() }
                }
            }
        }
    }

    private var connectionText: String {
        let connText = tabStore.activeTab?.connection.connectionName ?? "Server"
        let db = viewModel.selectedDatabase
        return db.map { "\(connText) \u{2022} \($0)" } ?? connText
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isLoadingUsers || viewModel.isLoadingRoles ||
           viewModel.isLoadingAppRoles || viewModel.isLoadingSchemas ||
           viewModel.isLoadingMaskedColumns || viewModel.isLoadingSecurityPolicies ||
           viewModel.isLoadingDBAuditSpecs || viewModel.isLoadingAlwaysEncrypted {
            return .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        Picker(selection: $viewModel.selectedSection) {
            ForEach(DatabaseSecurityViewModel.Section.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 580)
    }

    // MARK: - Section Content

    @ViewBuilder
    private var sectionContent: some View {
        VStack(spacing: 0) {
            if !(session?.permissions?.canManageRoles ?? true) {
                PermissionBanner(message: "Some operations require the securityadmin or sysadmin role.")
            }
            switch viewModel.selectedSection {
            case .users:
                MSSQLSecurityUsersSection(viewModel: viewModel)
            case .roles:
                MSSQLSecurityRolesSection(
                    viewModel: viewModel,
                    onNewRole: { showNewRoleSheet = true }
                )
            case .appRoles:
                MSSQLSecurityAppRolesSection(
                    viewModel: viewModel,
                    onNewAppRole: { showNewAppRoleSheet = true }
                )
            case .schemas:
                MSSQLSecuritySchemasSection(
                    viewModel: viewModel,
                    onNewSchema: { showNewSchemaSheet = true }
                )
            case .masking:
                MSSQLSecurityMaskingSection(
                    viewModel: viewModel,
                    onNewMask: { showNewMaskSheet = true }
                )
            case .securityPolicies:
                MSSQLSecurityPoliciesSection(viewModel: viewModel)
            case .auditSpecifications:
                MSSQLSecurityDBAuditSpecSection(
                    viewModel: viewModel,
                    onNewSpec: { showNewAuditSpecSheet = true }
                )
            case .alwaysEncrypted:
                MSSQLSecurityAlwaysEncryptedSection(
                    viewModel: viewModel,
                    onNewCMK: { showNewCMKSheet = true },
                    onNewCEK: { showNewCEKSheet = true }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
