import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {

    func applySheets<V: View>(to content: V) -> some View {
        content
            .sheet(isPresented: $viewModel.showNewJobSheet) {
                if let connID = viewModel.newJobSessionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    NewAgentJobSheet(session: session, environmentState: environmentState) {
                        viewModel.showNewJobSheet = false
                        loadAgentJobs(session: session)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showDatabaseProperties) {
                if let dbName = viewModel.propertiesDatabaseName,
                   let connID = viewModel.propertiesConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    DatabasePropertiesSheet(
                        databaseName: dbName,
                        session: session,
                        environmentState: environmentState,
                        onDismiss: { viewModel.showDatabaseProperties = false }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showSecurityLoginSheet) {
                if let connID = viewModel.securityLoginSheetSessionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    SecurityLoginSheet(
                        session: session,
                        environmentState: environmentState,
                        existingLoginName: viewModel.securityLoginSheetEditName
                    ) {
                        viewModel.showSecurityLoginSheet = false
                        loadServerSecurity(session: session)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSecurityUserSheet) {
                if let connID = viewModel.securityUserSheetSessionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = viewModel.securityUserSheetDatabaseName {
                    SecurityUserSheet(
                        session: session,
                        environmentState: environmentState,
                        databaseName: dbName,
                        existingUserName: viewModel.securityUserSheetEditName
                    ) {
                        viewModel.showSecurityUserSheet = false
                        // Reload database-level security
                        if let structure = session.databaseStructure,
                           let db = structure.databases.first(where: { $0.name == dbName }) {
                            loadDatabaseSecurity(database: db, session: session)
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSecurityPGRoleSheet) {
                if let connID = viewModel.securityPGRoleSheetSessionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    SecurityPGRoleSheet(
                        session: session,
                        environmentState: environmentState,
                        existingRoleName: viewModel.securityPGRoleSheetEditName
                    ) {
                        viewModel.showSecurityPGRoleSheet = false
                        loadServerSecurity(session: session)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showBackupSheet) {
                if let dbName = viewModel.backupDatabaseName,
                   let connID = viewModel.backupConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let adapter = session.session as? SQLServerSessionAdapter {
                    BackupSheet(
                        viewModel: BackupViewModel(client: adapter.client, databaseName: dbName),
                        onDismiss: { viewModel.showBackupSheet = false }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showRestoreSheet) {
                if let dbName = viewModel.restoreDatabaseName,
                   let connID = viewModel.restoreConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let adapter = session.session as? SQLServerSessionAdapter {
                    RestoreSheet(
                        viewModel: RestoreViewModel(client: adapter.client, databaseName: dbName),
                        onDismiss: { viewModel.showRestoreSheet = false }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showNewLinkedServerSheet) {
                if let connID = viewModel.newLinkedServerSessionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    NewLinkedServerSheet(
                        session: session,
                        environmentState: environmentState
                    ) {
                        viewModel.showNewLinkedServerSheet = false
                        loadLinkedServers(session: session)
                    }
                }
            }
    }

    func applyAlerts<V: View>(to content: V) -> some View {
        content
            .alert(
                "Drop \"\(viewModel.dropDatabaseTarget?.databaseName ?? "")\"?",
                isPresented: $viewModel.showDropDatabaseAlert
            ) {
                Button("Cancel", role: .cancel) {
                    viewModel.dropDatabaseTarget = nil
                }
                Button("Drop", role: .destructive) {
                    guard let target = viewModel.dropDatabaseTarget else { return }
                    viewModel.dropDatabaseTarget = nil
                    guard let session = environmentState.sessionGroup.sessionForConnection(target.connectionID) else { return }
                    Task {
                        switch target.databaseType {
                        case .postgresql:
                            await dropPostgresDatabase(
                                session: session,
                                name: target.databaseName,
                                cascade: target.variant == .cascade,
                                force: target.variant == .force
                            )
                        default:
                            await runMSSQLTask(session: session, database: target.databaseName, task: .drop)
                        }
                    }
                }
            } message: {
                if let target = viewModel.dropDatabaseTarget {
                    switch target.variant {
                    case .cascade:
                        Text("This will drop the database and all dependent objects. This action cannot be undone.")
                    case .force:
                        Text("This will forcefully terminate all connections and drop the database. This action cannot be undone.")
                    case .standard:
                        Text("This will permanently delete the database \"\(target.databaseName)\". This action cannot be undone.")
                    }
                }
            }
            .alert(
                "Delete linked server \"\(viewModel.dropLinkedServerTarget?.serverName ?? "")\"?",
                isPresented: $viewModel.showDropLinkedServerAlert
            ) {
                Button("Cancel", role: .cancel) {
                    viewModel.dropLinkedServerTarget = nil
                }
                Button("Delete", role: .destructive) {
                    guard let target = viewModel.dropLinkedServerTarget else { return }
                    viewModel.dropLinkedServerTarget = nil
                    guard let session = environmentState.sessionGroup.sessionForConnection(target.connectionID) else { return }
                    Task {
                        await executeDropLinkedServer(target, session: session)
                    }
                }
            } message: {
                Text("This will permanently remove the linked server and all its login mappings. This action cannot be undone.")
            }
            .alert(
                "Drop \(viewModel.dropSecurityPrincipalTarget?.kind.rawValue ?? "") \"\(viewModel.dropSecurityPrincipalTarget?.name ?? "")\"?",
                isPresented: $viewModel.showDropSecurityPrincipalAlert
            ) {
                Button("Cancel", role: .cancel) {
                    viewModel.dropSecurityPrincipalTarget = nil
                }
                Button("Drop", role: .destructive) {
                    guard let target = viewModel.dropSecurityPrincipalTarget else { return }
                    viewModel.dropSecurityPrincipalTarget = nil
                    guard let session = environmentState.sessionGroup.sessionForConnection(target.connectionID) else { return }
                    Task {
                        await executeDropSecurityPrincipal(target, session: session)
                    }
                }
            } message: {
                if let target = viewModel.dropSecurityPrincipalTarget {
                    Text("This will permanently drop the \(target.kind.rawValue.lowercased()) \"\(target.name)\". This action cannot be undone.")
                }
            }
    }
}
