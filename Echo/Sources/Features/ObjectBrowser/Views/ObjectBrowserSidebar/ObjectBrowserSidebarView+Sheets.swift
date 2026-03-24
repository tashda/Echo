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
            .sheet(isPresented: $viewModel.showNewDatabaseSheet) {
                if let connID = viewModel.newDatabaseConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    NewDatabaseSheet(
                        session: session,
                        environmentState: environmentState,
                        onDismiss: { viewModel.showNewDatabaseSheet = false }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showNewServerRoleSheet) {
                if let connID = viewModel.newSecuritySheetSessionID,
                   let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == connID }) {
                    NewServerRoleSheet(session: session) {
                        viewModel.showNewServerRoleSheet = false
                        loadServerSecurity(session: session)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showNewCredentialSheet) {
                if let connID = viewModel.newSecuritySheetSessionID,
                   let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == connID }) {
                    NewCredentialSheet(session: session) {
                        viewModel.showNewCredentialSheet = false
                        loadServerSecurity(session: session)
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
            .sheet(isPresented: $viewModel.showPgBackupSheet) {
                if let dbName = viewModel.pgBackupDatabaseName,
                   let connID = viewModel.pgBackupConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    PgBackupSheetContainer(
                        connection: session.connection,
                        session: session.session,
                        databaseName: dbName,
                        isPresented: $viewModel.showPgBackupSheet
                    )
                }
            }
            .sheet(isPresented: $viewModel.showPgRestoreSheet) {
                if let dbName = viewModel.pgBackupDatabaseName,
                   let connID = viewModel.pgBackupConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    PgRestoreSheetContainer(
                        connection: session.connection,
                        session: session.session,
                        databaseName: dbName,
                        connectionSession: session,
                        isPresented: $viewModel.showPgRestoreSheet
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
            .sheet(isPresented: $viewModel.showDatabaseMailSheet) {
                if let connID = viewModel.databaseMailConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    DatabaseMailSheet(
                        session: session,
                        onDismiss: { viewModel.showDatabaseMailSheet = false }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showChangeTrackingSheet) {
                if let dbName = viewModel.changeTrackingDatabaseName,
                   let connID = viewModel.changeTrackingConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    ChangeTrackingSheet(
                        databaseName: dbName,
                        session: session,
                        onDismiss: { viewModel.showChangeTrackingSheet = false }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showFullTextSheet) {
                if let dbName = viewModel.fullTextDatabaseName,
                   let connID = viewModel.fullTextConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    FullTextSearchSheet(
                        databaseName: dbName,
                        session: session,
                        onDismiss: { viewModel.showFullTextSheet = false }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showReplicationSheet) {
                if let dbName = viewModel.replicationDatabaseName,
                   let connID = viewModel.replicationConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    ReplicationSheet(
                        databaseName: dbName,
                        session: session,
                        onDismiss: { viewModel.showReplicationSheet = false }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showCMSSheet) {
                if let connID = viewModel.cmsConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    CMSSheet(
                        session: session,
                        onDismiss: { viewModel.showCMSSheet = false }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showDetachSheet) {
                if let dbName = viewModel.detachDatabaseName,
                   let connID = viewModel.detachConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    DetachDatabaseSheet(
                        databaseName: dbName,
                        session: session,
                        environmentState: environmentState,
                        onDismiss: { viewModel.showDetachSheet = false }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showAttachSheet) {
                if let connID = viewModel.attachConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    AttachDatabaseSheet(
                        session: session,
                        environmentState: environmentState,
                        onDismiss: { viewModel.showAttachSheet = false }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showCreateSnapshotSheet) {
                if let connID = viewModel.createSnapshotConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    CreateSnapshotSheet(
                        session: session,
                        environmentState: environmentState,
                        onDismiss: {
                            viewModel.showCreateSnapshotSheet = false
                            loadDatabaseSnapshots(session: session)
                        }
                    )
                }
            }
            // Phase 3 — Server Trigger
            .sheet(isPresented: $viewModel.showNewServerTriggerSheet) {
                if let connID = viewModel.newServerTriggerConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    NewServerTriggerSheet(session: session, environmentState: environmentState) {
                        viewModel.showNewServerTriggerSheet = false
                        loadServerTriggers(session: session)
                    }
                }
            }
            // Phase 3 — Database DDL Trigger
            .sheet(isPresented: $viewModel.showNewDBDDLTriggerSheet) {
                if let connID = viewModel.newDBDDLTriggerConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = viewModel.newDBDDLTriggerDatabaseName {
                    NewDatabaseDDLTriggerSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        viewModel.showNewDBDDLTriggerSheet = false
                    }
                }
            }
            // Phase 3 — Service Broker
            .sheet(isPresented: $viewModel.showNewMessageTypeSheet) {
                if let connID = viewModel.newMessageTypeConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = viewModel.newMessageTypeDatabaseName {
                    NewMessageTypeSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        viewModel.showNewMessageTypeSheet = false
                    }
                }
            }
            .sheet(isPresented: $viewModel.showNewContractSheet) {
                if let connID = viewModel.newContractConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = viewModel.newContractDatabaseName {
                    NewContractSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        viewModel.showNewContractSheet = false
                    }
                }
            }
            .sheet(isPresented: $viewModel.showNewQueueSheet) {
                if let connID = viewModel.newQueueConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = viewModel.newQueueDatabaseName {
                    NewQueueSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        viewModel.showNewQueueSheet = false
                    }
                }
            }
            .sheet(isPresented: $viewModel.showNewServiceSheet) {
                if let connID = viewModel.newServiceConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = viewModel.newServiceDatabaseName {
                    NewServiceSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        viewModel.showNewServiceSheet = false
                    }
                }
            }
            .sheet(isPresented: $viewModel.showNewRouteSheet) {
                if let connID = viewModel.newRouteConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = viewModel.newRouteDatabaseName {
                    NewRouteSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        viewModel.showNewRouteSheet = false
                    }
                }
            }
            // Phase 3 — External Resources (PolyBase)
            .sheet(isPresented: $viewModel.showNewExternalDataSourceSheet) {
                if let connID = viewModel.newExternalDataSourceConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = viewModel.newExternalDataSourceDatabaseName {
                    NewExternalDataSourceSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        viewModel.showNewExternalDataSourceSheet = false
                    }
                }
            }
            .sheet(isPresented: $viewModel.showNewExternalFileFormatSheet) {
                if let connID = viewModel.newExternalFileFormatConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = viewModel.newExternalFileFormatDatabaseName {
                    NewExternalFileFormatSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        viewModel.showNewExternalFileFormatSheet = false
                    }
                }
            }
            .sheet(isPresented: $viewModel.showNewExternalTableSheet) {
                if let connID = viewModel.newExternalTableConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = viewModel.newExternalTableDatabaseName {
                    NewExternalTableSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        viewModel.showNewExternalTableSheet = false
                    }
                }
            }
            // Phase 3 — Temporal
            .sheet(isPresented: $viewModel.showEnableVersioningSheet) {
                if let connID = viewModel.enableVersioningConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let schema = viewModel.enableVersioningSchemaName,
                   let table = viewModel.enableVersioningTableName {
                    EnableSystemVersioningSheet(
                        tableName: table,
                        schemaName: schema,
                        session: session,
                        environmentState: environmentState
                    ) {
                        viewModel.showEnableVersioningSheet = false
                    }
                }
            }
            // Phase 6 — Generate Scripts
            .sheet(isPresented: $viewModel.showGenerateScriptsWizard) {
                if let connID = viewModel.generateScriptsConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = viewModel.generateScriptsDatabaseName {
                    let vm = GenerateScriptsWizardViewModel(
                        session: session.session,
                        databaseName: dbName
                    )
                    GenerateScriptsWizardView(viewModel: vm)
                        .onAppear {
                            vm.onOpenInQueryTab = { script in
                                environmentState.openQueryTab(for: session, presetQuery: script, database: dbName)
                            }
                        }
                }
            }
            // Phase 6 — Import Flat File
            .sheet(isPresented: $viewModel.showQuickImportSheet) {
                if let connID = viewModel.quickImportConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    QuickImportSheet(
                        viewModel: QuickImportViewModel(session: session.session)
                    )
                }
            }
            // Phase 6 — DAC Wizard
            .sheet(isPresented: $viewModel.showDACWizard) {
                if let connID = viewModel.dacWizardConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    DACWizardView(
                        viewModel: DACWizardViewModel(
                            session: session.session,
                            databaseName: viewModel.dacWizardDatabaseName ?? ""
                        )
                    )
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
