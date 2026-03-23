import SwiftUI

struct MSSQLDatabaseSecurityView: View {
    @Bindable var viewModel: DatabaseSecurityViewModel
    @Bindable var panelState: BottomPanelState
    @Environment(TabStore.self) private var tabStore
    @Environment(EnvironmentState.self) private var environmentState

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
    }

    private var connectionText: String {
        let connText = tabStore.activeTab?.connection.connectionName ?? "Server"
        let db = viewModel.selectedDatabase
        return db.map { "\(connText) \u{2022} \($0)" } ?? connText
    }

    private var statusBubble: BottomPanelStatusBarConfiguration.StatusBubble? {
        if viewModel.isLoadingUsers || viewModel.isLoadingRoles ||
           viewModel.isLoadingAppRoles || viewModel.isLoadingSchemas {
            return .init(label: "Loading\u{2026}", tint: .blue, isPulsing: true)
        }
        return nil
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: SpacingTokens.sm) {
            Picker("Database", selection: $viewModel.selectedDatabase) {
                ForEach(viewModel.databaseList, id: \.self) { db in
                    Text(db).tag(Optional(db))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 180)

            Picker(selection: $viewModel.selectedSection) {
                ForEach(DatabaseSecurityViewModel.Section.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 340)
        }
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
                MSSQLSecurityRolesSection(viewModel: viewModel)
            case .appRoles:
                MSSQLSecurityAppRolesSection(viewModel: viewModel)
            case .schemas:
                MSSQLSecuritySchemasSection(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
