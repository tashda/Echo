import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {

    func applySheets<V: View>(to content: V) -> some View {
        content
            .sheet(isPresented: $sheetState.showNewJobSheet) {
                if let connID = sheetState.newJobSessionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    NewAgentJobSheet(session: session, environmentState: environmentState) {
                        sheetState.showNewJobSheet = false
                        loadAgentJobs(session: session)
                    }
                }
            }
            .sheet(isPresented: $sheetState.showNewDatabaseSheet) {
                if let connID = sheetState.newDatabaseConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    NewDatabaseSheet(
                        session: session,
                        environmentState: environmentState,
                        onDismiss: { sheetState.showNewDatabaseSheet = false }
                    )
                }
            }
            .sheet(isPresented: $sheetState.showNewServerRoleSheet) {
                if let connID = sheetState.newSecuritySheetSessionID,
                   let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == connID }) {
                    NewServerRoleSheet(session: session) {
                        sheetState.showNewServerRoleSheet = false
                        loadServerSecurity(session: session)
                    }
                }
            }
            .sheet(isPresented: $sheetState.showNewCredentialSheet) {
                if let connID = sheetState.newSecuritySheetSessionID,
                   let session = environmentState.sessionGroup.activeSessions.first(where: { $0.id == connID }) {
                    NewCredentialSheet(session: session) {
                        sheetState.showNewCredentialSheet = false
                        loadServerSecurity(session: session)
                    }
                }
            }
            .sheet(isPresented: $sheetState.showSecurityPGRoleSheet) {
                if let connID = sheetState.securityPGRoleSheetSessionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    SecurityPGRoleSheet(
                        session: session,
                        environmentState: environmentState,
                        existingRoleName: sheetState.securityPGRoleSheetEditName
                    ) {
                        sheetState.showSecurityPGRoleSheet = false
                        loadServerSecurity(session: session)
                    }
                }
            }
            .sheet(isPresented: $sheetState.showPgBackupSheet) {
                if let dbName = sheetState.pgBackupDatabaseName,
                   let connID = sheetState.pgBackupConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    PgBackupSheetContainer(
                        connection: session.connection,
                        session: session.session,
                        databaseName: dbName,
                        isPresented: $sheetState.showPgBackupSheet
                    )
                }
            }
            .sheet(isPresented: $sheetState.showPgRestoreSheet) {
                if let dbName = sheetState.pgBackupDatabaseName,
                   let connID = sheetState.pgBackupConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    PgRestoreSheetContainer(
                        connection: session.connection,
                        session: session.session,
                        databaseName: dbName,
                        connectionSession: session,
                        isPresented: $sheetState.showPgRestoreSheet
                    )
                }
            }
            .sheet(isPresented: $sheetState.showMySQLBackupSheet) {
                if let dbName = sheetState.mysqlBackupDatabaseName,
                   let connID = sheetState.mysqlBackupConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    MySQLBackupSheetContainer(
                        connection: session.connection,
                        session: session.session,
                        databaseName: dbName,
                        isPresented: $sheetState.showMySQLBackupSheet
                    )
                }
            }
            .sheet(isPresented: $sheetState.showMySQLRestoreSheet) {
                if let dbName = sheetState.mysqlBackupDatabaseName,
                   let connID = sheetState.mysqlBackupConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    MySQLRestoreSheetContainer(
                        connection: session.connection,
                        session: session.session,
                        databaseName: dbName,
                        connectionSession: session,
                        isPresented: $sheetState.showMySQLRestoreSheet
                    )
                }
            }
            .sheet(isPresented: $sheetState.showNewLinkedServerSheet) {
                if let connID = sheetState.newLinkedServerSessionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    NewLinkedServerSheet(
                        session: session,
                        environmentState: environmentState
                    ) {
                        sheetState.showNewLinkedServerSheet = false
                        loadLinkedServers(session: session)
                    }
                }
            }
            .sheet(isPresented: $sheetState.showCMSSheet) {
                if let connID = sheetState.cmsConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    CMSSheet(
                        session: session,
                        onDismiss: { sheetState.showCMSSheet = false }
                    )
                }
            }
            .sheet(isPresented: $sheetState.showDetachSheet) {
                if let dbName = sheetState.detachDatabaseName,
                   let connID = sheetState.detachConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    if session.connection.databaseType == .sqlite {
                        SQLiteDetachDatabaseSheet(
                            databaseName: dbName,
                            session: session,
                            environmentState: environmentState,
                            onDismiss: { sheetState.showDetachSheet = false }
                        )
                    } else {
                        DetachDatabaseSheet(
                            databaseName: dbName,
                            session: session,
                            environmentState: environmentState,
                            onDismiss: { sheetState.showDetachSheet = false }
                        )
                    }
                }
            }
            .sheet(isPresented: $sheetState.showAttachSheet) {
                if let connID = sheetState.attachConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    if session.connection.databaseType == .sqlite {
                        SQLiteAttachDatabaseSheet(
                            session: session,
                            environmentState: environmentState,
                            onDismiss: { sheetState.showAttachSheet = false }
                        )
                    } else {
                        AttachDatabaseSheet(
                            session: session,
                            environmentState: environmentState,
                            onDismiss: { sheetState.showAttachSheet = false }
                        )
                    }
                }
            }
            .sheet(isPresented: $sheetState.showCreateSnapshotSheet) {
                if let connID = sheetState.createSnapshotConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    CreateSnapshotSheet(
                        session: session,
                        environmentState: environmentState,
                        onDismiss: {
                            sheetState.showCreateSnapshotSheet = false
                            loadDatabaseSnapshots(session: session)
                        }
                    )
                }
            }
            // Phase 3 — Server Trigger
            .sheet(isPresented: $sheetState.showNewServerTriggerSheet) {
                if let connID = sheetState.newServerTriggerConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    NewServerTriggerSheet(session: session, environmentState: environmentState) {
                        sheetState.showNewServerTriggerSheet = false
                        loadServerTriggers(session: session)
                    }
                }
            }
            // Phase 3 — Database DDL Trigger
            .sheet(isPresented: $sheetState.showNewDBDDLTriggerSheet) {
                if let connID = sheetState.newDBDDLTriggerConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = sheetState.newDBDDLTriggerDatabaseName {
                    NewDatabaseDDLTriggerSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        sheetState.showNewDBDDLTriggerSheet = false
                    }
                }
            }
            // Phase 3 — Service Broker
            .sheet(isPresented: $sheetState.showNewMessageTypeSheet) {
                if let connID = sheetState.newMessageTypeConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = sheetState.newMessageTypeDatabaseName {
                    NewMessageTypeSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        sheetState.showNewMessageTypeSheet = false
                    }
                }
            }
            .sheet(isPresented: $sheetState.showNewContractSheet) {
                if let connID = sheetState.newContractConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = sheetState.newContractDatabaseName {
                    NewContractSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        sheetState.showNewContractSheet = false
                    }
                }
            }
            .sheet(isPresented: $sheetState.showNewQueueSheet) {
                if let connID = sheetState.newQueueConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = sheetState.newQueueDatabaseName {
                    NewQueueSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        sheetState.showNewQueueSheet = false
                    }
                }
            }
            .sheet(isPresented: $sheetState.showNewServiceSheet) {
                if let connID = sheetState.newServiceConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = sheetState.newServiceDatabaseName {
                    NewServiceSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        sheetState.showNewServiceSheet = false
                    }
                }
            }
            .sheet(isPresented: $sheetState.showNewRouteSheet) {
                if let connID = sheetState.newRouteConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = sheetState.newRouteDatabaseName {
                    NewRouteSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        sheetState.showNewRouteSheet = false
                    }
                }
            }
            // Phase 3 — External Resources (PolyBase)
            .sheet(isPresented: $sheetState.showNewExternalDataSourceSheet) {
                if let connID = sheetState.newExternalDataSourceConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = sheetState.newExternalDataSourceDatabaseName {
                    NewExternalDataSourceSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        sheetState.showNewExternalDataSourceSheet = false
                    }
                }
            }
            .sheet(isPresented: $sheetState.showNewExternalFileFormatSheet) {
                if let connID = sheetState.newExternalFileFormatConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = sheetState.newExternalFileFormatDatabaseName {
                    NewExternalFileFormatSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        sheetState.showNewExternalFileFormatSheet = false
                    }
                }
            }
            .sheet(isPresented: $sheetState.showNewExternalTableSheet) {
                if let connID = sheetState.newExternalTableConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = sheetState.newExternalTableDatabaseName {
                    NewExternalTableSheet(databaseName: dbName, session: session, environmentState: environmentState) {
                        sheetState.showNewExternalTableSheet = false
                    }
                }
            }
            // Phase 3 — Temporal
            .sheet(isPresented: $sheetState.showEnableVersioningSheet) {
                if let connID = sheetState.enableVersioningConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let schema = sheetState.enableVersioningSchemaName,
                   let table = sheetState.enableVersioningTableName {
                    EnableSystemVersioningSheet(
                        tableName: table,
                        schemaName: schema,
                        session: session,
                        environmentState: environmentState
                    ) {
                        sheetState.showEnableVersioningSheet = false
                    }
                }
            }
            // Phase 6 — Generate Scripts
            .sheet(isPresented: $sheetState.showGenerateScriptsWizard) {
                if let connID = sheetState.generateScriptsConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID),
                   let dbName = sheetState.generateScriptsDatabaseName {
                    let vm = GenerateScriptsWizardViewModel(
                        session: session.session,
                        databaseName: dbName,
                        databaseType: session.connection.databaseType
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
            .sheet(isPresented: $sheetState.showQuickImportSheet) {
                if let connID = sheetState.quickImportConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    QuickImportSheet(
                        viewModel: QuickImportViewModel(session: session.session)
                    )
                }
            }
            // Phase 6 — DAC Wizard
            .sheet(isPresented: $sheetState.showDACWizard) {
                if let connID = sheetState.dacWizardConnectionID,
                   let session = environmentState.sessionGroup.sessionForConnection(connID) {
                    DACWizardView(
                        viewModel: DACWizardViewModel(
                            session: session.session,
                            databaseName: sheetState.dacWizardDatabaseName ?? ""
                        )
                    )
                }
            }
            // Data Migration Wizard
            .sheet(isPresented: $sheetState.showDataMigrationWizard) {
                let vm = DataMigrationWizardViewModel()
                let sessions = environmentState.sessionGroup.activeSessions
                DataMigrationWizardView(viewModel: vm)
                    .onAppear {
                        vm.availableSessions = sessions
                        if let connID = sheetState.dataMigrationConnectionID,
                           let session = sessions.first(where: { $0.connection.id == connID }) {
                            vm.sourceSessionID = session.id
                            vm.loadSourceDatabases()
                        }
                        vm.onOpenInQueryTab = { [weak environmentState] script in
                            let targetSession = sessions.first(where: { $0.id == vm.targetSessionID })
                            environmentState?.openQueryTab(
                                for: targetSession,
                                presetQuery: script,
                                database: vm.targetDatabaseName
                            )
                        }
                    }
            }
    }

    func applyAlerts<V: View>(to content: V) -> some View {
        content
            .alert(
                "Drop \"\(sheetState.dropDatabaseTarget?.databaseName ?? "")\"?",
                isPresented: $sheetState.showDropDatabaseAlert
            ) {
                Button("Cancel", role: .cancel) {
                    sheetState.dropDatabaseTarget = nil
                }
                Button("Drop", role: .destructive) {
                    guard let target = sheetState.dropDatabaseTarget else { return }
                    sheetState.dropDatabaseTarget = nil
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
                if let target = sheetState.dropDatabaseTarget {
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
                "Delete linked server \"\(sheetState.dropLinkedServerTarget?.serverName ?? "")\"?",
                isPresented: $sheetState.showDropLinkedServerAlert
            ) {
                Button("Cancel", role: .cancel) {
                    sheetState.dropLinkedServerTarget = nil
                }
                Button("Delete", role: .destructive) {
                    guard let target = sheetState.dropLinkedServerTarget else { return }
                    sheetState.dropLinkedServerTarget = nil
                    guard let session = environmentState.sessionGroup.sessionForConnection(target.connectionID) else { return }
                    Task {
                        await executeDropLinkedServer(target, session: session)
                    }
                }
            } message: {
                Text("This will permanently remove the linked server and all its login mappings. This action cannot be undone.")
            }
            .alert(
                "Drop \(sheetState.dropSecurityPrincipalTarget?.kind.rawValue ?? "") \"\(sheetState.dropSecurityPrincipalTarget?.name ?? "")\"?",
                isPresented: $sheetState.showDropSecurityPrincipalAlert
            ) {
                Button("Cancel", role: .cancel) {
                    sheetState.dropSecurityPrincipalTarget = nil
                }
                Button("Drop", role: .destructive) {
                    guard let target = sheetState.dropSecurityPrincipalTarget else { return }
                    sheetState.dropSecurityPrincipalTarget = nil
                    guard let session = environmentState.sessionGroup.sessionForConnection(target.connectionID) else { return }
                    Task {
                        await executeDropSecurityPrincipal(target, session: session)
                    }
                }
            } message: {
                if let target = sheetState.dropSecurityPrincipalTarget {
                    Text("This will permanently drop the \(target.kind.rawValue.lowercased()) \"\(target.name)\". This action cannot be undone.")
                }
            }
    }
}
