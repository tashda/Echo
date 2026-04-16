import AppKit
import SwiftUI
import SQLServerKit

extension ObjectBrowserSidebarView {
    func contextMenu(for node: ObjectBrowserNode) -> NSMenu? {
        switch node.row {
        case .topSpacer:
            nil
        case .pendingConnection(let pending):
            pendingConnectionMenu(for: pending)
        case .server(let session):
            serverMenu(for: session)
        case .databasesFolder(let session, _):
            databasesFolderMenu(for: session)
        case .database(let session, let database, _):
            databaseMenu(for: database, session: session)
        case .objectGroup(let session, let databaseName, let type, _):
            objectGroupMenu(for: type, databaseName: databaseName, session: session)
        case .object(let session, let databaseName, let object):
            objectMenu(for: object, databaseName: databaseName, session: session)
        case .serverFolder(let session, let kind, _):
            serverFolderMenu(kind: kind, session: session)
        case .databaseFolder(let session, let databaseName, let kind, _, _):
            databaseFolderMenu(kind: kind, databaseName: databaseName, session: session)
        case .databaseSubfolder(let session, let databaseName, let title, _, _, _):
            databaseSubfolderMenu(title: title, databaseName: databaseName, session: session)
        case .databaseNamedItem:
            nil
        case .securitySection(let session, let kind, _, _):
            securitySectionMenu(kind: kind, session: session)
        case .securityLogin(let session, let login):
            securityLoginMenu(login: login, session: session)
        case .securityServerRole(let session, let role):
            securityServerRoleMenu(role: role, session: session)
        case .securityCredential(let session, let credential):
            securityCredentialMenu(credential: credential, session: session)
        case .databaseSnapshot(let session, let snapshot):
            snapshotMenu(snapshot: snapshot, session: session)
        case .linkedServer(let session, let server):
            linkedServerMenu(server: server, session: session)
        case .serverTrigger(let session, let trigger):
            serverTriggerMenu(trigger: trigger, session: session)
        case .agentJob(let session, _):
            agentJobMenu(for: session)
        case .ssisFolder, .action, .infoLeaf, .loading, .message, .column:
            nil
        }
    }

    private func pendingConnectionMenu(for pending: PendingConnection) -> NSMenu {
        let menu = NSMenu()

        switch pending.phase {
        case .connecting:
            menu.addActionItem("Cancel Connection", systemImage: "xmark.circle") {
                environmentState.cancelPendingConnection(for: pending.connection.id)
            }
            menu.addActionItem("Edit Connection", systemImage: "pencil") {
                ManageConnectionsWindowController.shared.present()
            }
        case .failed:
            menu.addActionItem("Retry", systemImage: "arrow.clockwise") {
                environmentState.retryPendingConnection(for: pending.connection.id)
            }
            menu.addActionItem("Edit Connection", systemImage: "pencil") {
                ManageConnectionsWindowController.shared.present()
            }
            menu.addDivider()
            menu.addActionItem("Remove", systemImage: "trash") {
                environmentState.removePendingConnection(for: pending.connection.id)
            }
        }

        return menu
    }

    private func serverFolderMenu(
        kind: ObjectBrowserServerFolderKind,
        session: ConnectionSession
    ) -> NSMenu? {
        let menu = NSMenu()

        switch kind {
        case .security:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                Task {
                    let handle = AppDirector.shared.activityEngine.begin("Refreshing security", connectionSessionID: session.id)
                    await loadServerSecurityAsync(session: session)
                    handle.succeed()
                }
            }
            switch session.connection.databaseType {
            case .microsoftSQL:
                menu.addActionItem("New Login", systemImage: "person.badge.plus") {
                    let value = environmentState.prepareLoginEditorWindow(
                        connectionSessionID: session.connection.id,
                        existingLogin: nil
                    )
                    openWindow(id: LoginEditorWindow.sceneID, value: value)
                }
                menu.addDivider()
                menu.addActionItem("Open Security Management", systemImage: "lock.shield") {
                    environmentState.openServerSecurityTab(connectionID: session.connection.id)
                }
            case .postgresql:
                menu.addActionItem("New Login Role", systemImage: "person.badge.plus") {
                    sheetState.securityPGRoleSheetSessionID = session.connection.id
                    sheetState.securityPGRoleSheetEditName = nil
                    sheetState.showSecurityPGRoleSheet = true
                }
                menu.addActionItem("New Group Role", systemImage: "person.2.badge.plus") {
                    sheetState.securityPGRoleSheetSessionID = session.connection.id
                    sheetState.securityPGRoleSheetEditName = nil
                    sheetState.showSecurityPGRoleSheet = true
                }
            case .mysql, .sqlite:
                break
            }
        case .agentJobs:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                loadAgentJobs(session: session)
            }
            menu.addDivider()
            menu.addActionItem("Open in Tab", systemImage: "list.bullet.rectangle") {
                environmentState.openJobQueueTab(for: session)
            }
            menu.addActionItem("Open in New Window", systemImage: "rectangle.portrait.and.arrow.right") {
                let sessionID = environmentState.prepareJobQueueWindow(for: session)
                openWindow(id: JobQueueWindow.sceneID, value: sessionID)
            }
        case .databaseSnapshots:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                loadDatabaseSnapshots(session: session)
            }
            menu.addDivider()
            menu.addActionItem("New Snapshot", systemImage: "camera.badge.ellipsis") {
                sheetState.createSnapshotConnectionID = session.connection.id
                sheetState.showCreateSnapshotSheet = true
            }
        case .ssis:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                Task { await loadSSISFoldersAsync(session: session) }
            }
        case .linkedServers:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                loadLinkedServers(session: session)
            }
            menu.addDivider()
            menu.addActionItem("New Linked Server", systemImage: "link.badge.plus") {
                sheetState.newLinkedServerSessionID = session.connection.id
                sheetState.showNewLinkedServerSheet = true
            }
        case .serverTriggers:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                loadServerTriggers(session: session)
            }
            menu.addActionItem("New Server Trigger", systemImage: "bolt") {
                sheetState.newServerTriggerConnectionID = session.connection.id
                sheetState.showNewServerTriggerSheet = true
            }
        case .management:
            return nil
        }

        return menu
    }

    private func securitySectionMenu(
        kind: ObjectBrowserSecuritySectionKind,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing \(kind.title.lowercased())", connectionSessionID: session.id)
                await loadServerSecurityAsync(session: session)
                handle.succeed()
            }
        }

        switch kind {
        case .logins:
            menu.addActionItem("New Login", systemImage: "person.badge.plus") {
                let value = environmentState.prepareLoginEditorWindow(
                    connectionSessionID: session.connection.id,
                    existingLogin: nil
                )
                openWindow(id: LoginEditorWindow.sceneID, value: value)
            }
        case .serverRoles:
            menu.addActionItem("New Server Role", systemImage: "person.2.badge.plus") {
                createMSSQLServerRole(session: session)
            }
        case .credentials:
            menu.addActionItem("New Credential", systemImage: "key.fill") {
                createMSSQLCredential(session: session)
            }
        case .pgLoginRoles:
            menu.addActionItem("New Login Role", systemImage: "person.badge.plus") {
                sheetState.securityPGRoleSheetSessionID = session.connection.id
                sheetState.securityPGRoleSheetEditName = nil
                sheetState.showSecurityPGRoleSheet = true
            }
        case .pgGroupRoles:
            menu.addActionItem("New Group Role", systemImage: "person.2.badge.plus") {
                sheetState.securityPGRoleSheetSessionID = session.connection.id
                sheetState.securityPGRoleSheetEditName = nil
                sheetState.showSecurityPGRoleSheet = true
            }
        case .certificateLogins:
            break
        }

        return menu
    }

    private func securityLoginMenu(
        login: ObjectBrowserSidebarViewModel.SecurityLoginItem,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()

        if session.connection.databaseType == .postgresql {
            menu.addActionItem("Reassign Owned Objects", systemImage: "arrow.triangle.swap") {
                Task { await reassignPGRole(name: login.name, session: session) }
            }
            menu.addDivider()
            menu.addSubmenu("Script as", systemImage: "scroll") { sub in
                let loginAttribute = login.loginType.contains("Login") || login.loginType.contains("Superuser") ? " LOGIN" : ""
                sub.addActionItem("CREATE", systemImage: "plus.rectangle.on.rectangle") {
                    openScriptTab(sql: "CREATE ROLE \"\(login.name)\"\(loginAttribute);", session: session)
                }
                sub.addDivider()
                sub.addActionItem("DROP", systemImage: "trash") {
                    openScriptTab(sql: "DROP ROLE \"\(login.name)\";", session: session)
                }
            }
            menu.addDivider()
            menu.addActionItem("Drop Role", systemImage: "trash") {
                sheetState.dropSecurityPrincipalTarget = .init(
                    sessionID: session.id,
                    connectionID: session.connection.id,
                    name: login.name,
                    kind: .pgRole,
                    databaseName: nil
                )
                sheetState.showDropSecurityPrincipalAlert = true
            }
            menu.addDivider()
            menu.addActionItem("Properties", systemImage: "info.circle") {
                sheetState.securityPGRoleSheetSessionID = session.connection.id
                sheetState.securityPGRoleSheetEditName = login.name
                sheetState.showSecurityPGRoleSheet = true
            }
            return menu
        }

        menu.addSubmenu("Script as", systemImage: "scroll") { sub in
            let createSQL = if login.loginType == "SQL" {
                "CREATE LOGIN [\(login.name)] WITH PASSWORD = N'<password>';"
            } else {
                "CREATE LOGIN [\(login.name)] FROM WINDOWS;"
            }
            sub.addActionItem("CREATE", systemImage: "plus.rectangle.on.rectangle") {
                openScriptTab(sql: createSQL, session: session)
            }
            sub.addDivider()
            sub.addActionItem("DROP", systemImage: "trash") {
                openScriptTab(sql: "DROP LOGIN [\(login.name)];", session: session)
            }
        }
        menu.addDivider()
        if login.isDisabled {
            menu.addActionItem("Enable Login", systemImage: "checkmark.circle") {
                Task { await enableMSSQLLogin(name: login.name, enabled: true, session: session) }
            }
        } else {
            menu.addActionItem("Disable Login", systemImage: "nosign") {
                Task { await enableMSSQLLogin(name: login.name, enabled: false, session: session) }
            }
        }
        menu.addDivider()
        menu.addActionItem("Drop Login", systemImage: "trash") {
            sheetState.dropSecurityPrincipalTarget = .init(
                sessionID: session.id,
                connectionID: session.connection.id,
                name: login.name,
                kind: .mssqlLogin,
                databaseName: nil
            )
            sheetState.showDropSecurityPrincipalAlert = true
        }
        menu.addDivider()
        menu.addActionItem("Properties", systemImage: "info.circle") {
            let value = environmentState.prepareLoginEditorWindow(
                connectionSessionID: session.connection.id,
                existingLogin: login.name
            )
            openWindow(id: LoginEditorWindow.sceneID, value: value)
        }
        return menu
    }

    private func securityServerRoleMenu(
        role: ObjectBrowserSidebarViewModel.SecurityServerRoleItem,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("List Members", systemImage: "person.2") {
            openScriptTab(
                sql: """
                SELECT m.name AS member_name, m.type_desc
                FROM sys.server_role_members rm
                JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
                JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
                WHERE r.name = N'\(role.name)';
                """,
                session: session
            )
        }

        if !role.isFixed {
            menu.addDivider()
            menu.addSubmenu("Script as", systemImage: "scroll") { sub in
                sub.addActionItem("CREATE", systemImage: "plus.rectangle.on.rectangle") {
                    openScriptTab(sql: "CREATE SERVER ROLE [\(role.name)];", session: session)
                }
                sub.addDivider()
                sub.addActionItem("DROP", systemImage: "trash") {
                    openScriptTab(sql: "DROP SERVER ROLE [\(role.name)];", session: session)
                }
            }
            menu.addDivider()
            menu.addActionItem("Drop Server Role", systemImage: "trash") {
                sheetState.dropSecurityPrincipalTarget = .init(
                    sessionID: session.id,
                    connectionID: session.connection.id,
                    name: role.name,
                    kind: .mssqlServerRole,
                    databaseName: nil
                )
                sheetState.showDropSecurityPrincipalAlert = true
            }
        }

        return menu
    }

    private func securityCredentialMenu(
        credential: ObjectBrowserSidebarViewModel.SecurityCredentialItem,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addSubmenu("Script as", systemImage: "scroll") { sub in
            sub.addActionItem("CREATE", systemImage: "plus.rectangle.on.rectangle") {
                openScriptTab(
                    sql: "CREATE CREDENTIAL [\(credential.name)] WITH IDENTITY = N'\(credential.identity)', SECRET = N'<secret>';",
                    session: session
                )
            }
            sub.addDivider()
            sub.addActionItem("DROP", systemImage: "trash") {
                openScriptTab(sql: "DROP CREDENTIAL [\(credential.name)];", session: session)
            }
        }
        return menu
    }

    private func serverMenu(for session: ConnectionSession) -> NSMenu {
        let menu = NSMenu()

        menu.addActionItem("Refresh All", systemImage: "arrow.clockwise") {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing all databases", connectionSessionID: session.id)
                await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
                handle.succeed()
            }
        }
        menu.addActionItem("New Query", systemImage: "doc.text") {
            environmentState.openQueryTab(for: session)
        }
        menu.addDivider()
        menu.addActionItem("Activity Monitor", systemImage: "gauge.with.dots.needle.33percent") {
            environmentState.openActivityMonitorTab(connectionID: session.connection.id)
        }
        menu.addDivider()
        menu.addActionItem("Maintenance", systemImage: "wrench.and.screwdriver") {
            environmentState.openMaintenanceTab(connectionID: session.connection.id)
        }

        if session.connection.databaseType == .microsoftSQL {
            menu.addActionItem("Database Mail", systemImage: "envelope") {
                let value = environmentState.prepareDatabaseMailEditorWindow(connectionSessionID: session.connection.id)
                openWindow(id: DatabaseMailEditorWindow.sceneID, value: value)
            }
            menu.addActionItem("Central Management Servers", systemImage: "server.rack") {
                sheetState.cmsConnectionID = session.connection.id
                sheetState.showCMSSheet = true
            }
            menu.addActionItem("Extended Events", systemImage: "waveform.path.ecg") {
                environmentState.openActivityMonitorTab(connectionID: session.connection.id, section: "XEvents")
            }
            menu.addActionItem("Availability Groups", systemImage: "server.rack") {
                environmentState.openAvailabilityGroupsTab(connectionID: session.connection.id)
            }
            menu.addDivider()

            let connID = session.connection.id
            let hideOffline = viewModel.hideOfflineDatabasesBySession[connID] ?? false
            let item = menu.addActionItem("Hide Offline Databases", systemImage: "eye.slash") {
                viewModel.hideOfflineDatabasesBySession[connID] = !(viewModel.hideOfflineDatabasesBySession[connID] ?? false)
            }
            item.state = hideOffline ? NSControl.StateValue.on : NSControl.StateValue.off
        }

        menu.addDivider()
        menu.addActionItem("Manage Connection", systemImage: "slider.horizontal.3") {
            ManageConnectionsWindowController.shared.present(
                initialSection: .connections,
                selectedConnectionID: session.connection.id
            )
        }
        menu.addActionItem("Disconnect", systemImage: "xmark.circle") {
            Task { await environmentState.disconnectSession(withID: session.id) }
        }

        menu.addDivider()
        if session.connection.databaseType == .microsoftSQL {
            menu.addActionItem("Properties", systemImage: "info.circle") {
                let value = environmentState.prepareServerEditorWindow(connectionSessionID: session.connection.id)
                openWindow(id: ServerEditorWindow.sceneID, value: value)
            }
        } else if session.connection.databaseType == .mysql {
            menu.addActionItem("Server Properties", systemImage: "info.circle") {
                environmentState.openServerPropertiesTab(connectionID: session.connection.id)
            }
        }

        return menu
    }

    private func databasesFolderMenu(for session: ConnectionSession) -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing databases", connectionSessionID: session.id)
                await environmentState.refreshDatabaseStructure(for: session.id, scope: .full)
                handle.succeed()
            }
        }
        let newDatabaseItem = menu.addActionItem("New Database", systemImage: "cylinder") {
            sheetState.newDatabaseConnectionID = session.connection.id
            sheetState.showNewDatabaseSheet = true
        }
        newDatabaseItem.isEnabled = session.permissions?.canCreateDatabases ?? true
        if session.connection.databaseType == .microsoftSQL || session.connection.databaseType == .sqlite {
            menu.addDivider()
            menu.addActionItem("Attach Database", systemImage: "externaldrive.badge.plus") {
                sheetState.attachConnectionID = session.connection.id
                sheetState.showAttachSheet = true
            }
        }
        return menu
    }

    private func databaseMenu(for database: DatabaseInfo, session: ConnectionSession) -> NSMenu {
        let menu = NSMenu()
        let connID = session.connection.id
        let dbType = session.connection.databaseType

        menu.addActionItem("Refresh Schema", systemImage: "arrow.clockwise") {
            viewModel.setExpanded(true, nodeID: ObjectBrowserSidebarViewModel.databaseNodeID(connectionID: connID, databaseName: database.name))
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing schema for \(database.name)", connectionSessionID: session.id)
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                handle.succeed()
            }
        }
        menu.addActionItem("New Query", systemImage: "doc.text") {
            environmentState.openQueryTab(for: session, database: database.name)
        }

        menu.addDivider()

        if dbType == .postgresql, projectStore.globalSettings.managedPostgresConsoleEnabled {
            menu.addActionItem("Postgres Console", systemImage: "terminal") {
                environmentState.openPSQLTab(for: session, database: database.name)
            }
            menu.addDivider()
        }

        menu.addActionItem("Maintenance", systemImage: "wrench.and.screwdriver") {
            environmentState.openMaintenanceTab(connectionID: connID, databaseName: database.name)
        }

        if dbType == .postgresql {
            menu.addSubmenu("Tasks", systemImage: "gearshape") { sub in
                sub.addActionItem("Back Up", systemImage: "arrow.down.doc") {
                    sheetState.pgBackupDatabaseName = database.name
                    sheetState.pgBackupConnectionID = connID
                    sheetState.showPgBackupSheet = true
                }
                sub.addActionItem("Restore", systemImage: "arrow.up.doc") {
                    sheetState.pgBackupDatabaseName = database.name
                    sheetState.pgBackupConnectionID = connID
                    sheetState.showPgRestoreSheet = true
                }
            }
        }

        if dbType == .mysql {
            menu.addSubmenu("Tasks", systemImage: "gearshape") { sub in
                sub.addActionItem("Back Up", systemImage: "arrow.down.doc") {
                    sheetState.mysqlBackupDatabaseName = database.name
                    sheetState.mysqlBackupConnectionID = connID
                    sheetState.showMySQLBackupSheet = true
                }
                sub.addActionItem("Restore", systemImage: "arrow.up.doc") {
                    sheetState.mysqlBackupDatabaseName = database.name
                    sheetState.mysqlBackupConnectionID = connID
                    sheetState.showMySQLRestoreSheet = true
                }
            }
        }

        if dbType == .sqlite && database.name.lowercased() != "main" && database.name.lowercased() != "temp" {
            menu.addDivider()
            menu.addActionItem("Detach Database", systemImage: "externaldrive.badge.minus") {
                sheetState.detachDatabaseName = database.name
                sheetState.detachConnectionID = connID
                sheetState.showDetachSheet = true
            }
        }

        if dbType == .microsoftSQL {
            menu.addSubmenu("Advanced Objects", systemImage: "puzzlepiece.extension") { sub in
                sub.addActionItem("Change Tracking", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                    environmentState.openMSSQLAdvancedObjectsTab(connectionID: connID, databaseName: database.name, section: .changeTracking)
                }
                sub.addActionItem("Change Data Capture", systemImage: "arrow.triangle.branch") {
                    environmentState.openMSSQLAdvancedObjectsTab(connectionID: connID, databaseName: database.name, section: .cdc)
                }
                sub.addActionItem("Full-Text Search", systemImage: "text.magnifyingglass") {
                    environmentState.openMSSQLAdvancedObjectsTab(connectionID: connID, databaseName: database.name, section: .fullTextSearch)
                }
                sub.addActionItem("Replication", systemImage: "arrow.triangle.swap") {
                    environmentState.openMSSQLAdvancedObjectsTab(connectionID: connID, databaseName: database.name, section: .replication)
                }
            }

            menu.addSubmenu("Tasks", systemImage: "gearshape") { sub in
                if database.isOnline {
                    sub.addActionItem("Back Up", systemImage: "arrow.down.doc") {
                        environmentState.openMaintenanceBackups(connectionID: connID, databaseName: database.name, action: .backup)
                    }
                    sub.addActionItem("Restore", systemImage: "arrow.up.doc") {
                        environmentState.openMaintenanceBackups(connectionID: connID, databaseName: database.name, action: .restore)
                    }
                    sub.addDivider()
                    sub.addActionItem("Shrink Database", systemImage: "arrow.down.right.and.arrow.up.left") {
                        Task { await self.runMSSQLTask(session: session, database: database.name, task: .shrink) }
                    }
                    sub.addDivider()
                    sub.addActionItem("Take Offline", systemImage: "bolt.slash") {
                        Task { await self.runMSSQLTask(session: session, database: database.name, task: .takeOffline) }
                    }
                    sub.addDivider()
                    sub.addActionItem("Detach Database", systemImage: "externaldrive.badge.minus") {
                        sheetState.detachDatabaseName = database.name
                        sheetState.detachConnectionID = connID
                        sheetState.showDetachSheet = true
                    }
                    sub.addDivider()
                    sub.addActionItem("Generate Scripts", systemImage: "scroll") {
                        sheetState.generateScriptsDatabaseName = database.name
                        sheetState.generateScriptsConnectionID = connID
                        sheetState.showGenerateScriptsWizard = true
                    }
                    sub.addActionItem("Import Flat File", systemImage: "square.and.arrow.down.on.square") {
                        sheetState.quickImportDatabaseName = database.name
                        sheetState.quickImportConnectionID = connID
                        sheetState.showQuickImportSheet = true
                    }
                    sub.addActionItem("Migrate Data", systemImage: "arrow.right.arrow.left") {
                        sheetState.dataMigrationConnectionID = connID
                        sheetState.showDataMigrationWizard = true
                    }
                    sub.addActionItem("Visual Query Builder", systemImage: "hammer") {
                        environmentState.openQueryBuilderTab(connectionID: connID)
                    }
                    sub.addDivider()
                    sub.addActionItem("Data-tier Application Tasks", systemImage: "archivebox") {
                        sheetState.dacWizardDatabaseName = database.name
                        sheetState.dacWizardConnectionID = connID
                        sheetState.showDACWizard = true
                    }
                } else {
                    sub.addActionItem("Bring Online", systemImage: "bolt") {
                        Task { await self.runMSSQLTask(session: session, database: database.name, task: .bringOnline) }
                    }
                    sub.addActionItem("Restore", systemImage: "arrow.up.doc") {
                        environmentState.openMaintenanceBackups(connectionID: connID, databaseName: database.name, action: .restore)
                    }
                }
            }
        }

        menu.addDivider()
        if dbType == .postgresql {
            menu.addSubmenu("Drop Database", systemImage: "trash") { sub in
                sub.addActionItem("Drop", systemImage: "trash") {
                    sheetState.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .standard)
                    sheetState.showDropDatabaseAlert = true
                }
                sub.addActionItem("Drop (Cascade)", systemImage: "trash") {
                    sheetState.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .cascade)
                    sheetState.showDropDatabaseAlert = true
                }
                sub.addActionItem("Drop (Force)", systemImage: "trash") {
                    sheetState.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .force)
                    sheetState.showDropDatabaseAlert = true
                }
            }
        } else {
            menu.addActionItem("Drop Database", systemImage: "trash") {
                sheetState.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: dbType, variant: .standard)
                sheetState.showDropDatabaseAlert = true
            }
        }

        menu.addDivider()
        menu.addActionItem("Properties", systemImage: "info.circle") {
            let value = environmentState.prepareDatabaseEditorWindow(
                connectionSessionID: session.connection.id,
                databaseName: database.name,
                databaseType: dbType
            )
            openWindow(id: DatabaseEditorWindow.sceneID, value: value)
        }

        return menu
    }

    private func databaseFolderMenu(
        kind: ObjectBrowserDatabaseFolderKind,
        databaseName: String,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()

        switch kind {
        case .security:
            menu.addActionItem("Open Security Management", systemImage: "lock.shield") {
                environmentState.openDatabaseSecurityTab(connectionID: session.connection.id, databaseName: databaseName)
            }
        case .databaseTriggers:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                if let database = session.databaseStructure?.databases.first(where: { $0.name == databaseName }) {
                    loadDatabaseDDLTriggers(database: database, session: session)
                }
            }
            menu.addActionItem("New Database Trigger", systemImage: "bolt") {
                sheetState.newDBDDLTriggerConnectionID = session.connection.id
                sheetState.newDBDDLTriggerDatabaseName = databaseName
                sheetState.showNewDBDDLTriggerSheet = true
            }
        case .serviceBroker:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                if let database = session.databaseStructure?.databases.first(where: { $0.name == databaseName }) {
                    loadServiceBrokerData(database: database, session: session)
                }
            }
        case .externalResources:
            menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
                if let database = session.databaseStructure?.databases.first(where: { $0.name == databaseName }) {
                    loadExternalResources(database: database, session: session)
                }
            }
        }

        return menu
    }

    private func databaseSubfolderMenu(
        title: String,
        databaseName: String,
        session: ConnectionSession
    ) -> NSMenu? {
        let menu = NSMenu()
        switch title {
        case "Message Types":
            menu.addActionItem("New Message Type", systemImage: "plus") {
                sheetState.newMessageTypeConnectionID = session.connection.id
                sheetState.newMessageTypeDatabaseName = databaseName
                sheetState.showNewMessageTypeSheet = true
            }
        case "Contracts":
            menu.addActionItem("New Contract", systemImage: "plus") {
                sheetState.newContractConnectionID = session.connection.id
                sheetState.newContractDatabaseName = databaseName
                sheetState.showNewContractSheet = true
            }
        case "Queues":
            menu.addActionItem("New Queue", systemImage: "plus") {
                sheetState.newQueueConnectionID = session.connection.id
                sheetState.newQueueDatabaseName = databaseName
                sheetState.showNewQueueSheet = true
            }
        case "Services":
            menu.addActionItem("New Service", systemImage: "plus") {
                sheetState.newServiceConnectionID = session.connection.id
                sheetState.newServiceDatabaseName = databaseName
                sheetState.showNewServiceSheet = true
            }
        case "Routes":
            menu.addActionItem("New Route", systemImage: "plus") {
                sheetState.newRouteConnectionID = session.connection.id
                sheetState.newRouteDatabaseName = databaseName
                sheetState.showNewRouteSheet = true
            }
        case "External Data Sources":
            menu.addActionItem("New External Data Source", systemImage: "plus") {
                sheetState.newExternalDataSourceConnectionID = session.connection.id
                sheetState.newExternalDataSourceDatabaseName = databaseName
                sheetState.showNewExternalDataSourceSheet = true
            }
        case "External Tables":
            menu.addActionItem("New External Table", systemImage: "plus") {
                sheetState.newExternalTableConnectionID = session.connection.id
                sheetState.newExternalTableDatabaseName = databaseName
                sheetState.showNewExternalTableSheet = true
            }
        case "External File Formats":
            menu.addActionItem("New External File Format", systemImage: "plus") {
                sheetState.newExternalFileFormatConnectionID = session.connection.id
                sheetState.newExternalFileFormatDatabaseName = databaseName
                sheetState.showNewExternalFileFormatSheet = true
            }
        default:
            return nil
        }
        return menu
    }

    private func objectGroupMenu(
        for type: SchemaObjectInfo.ObjectType,
        databaseName: String,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()

        menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing \(type.pluralDisplayName)", connectionSessionID: session.id)
                await environmentState.loadSchemaForDatabase(databaseName, connectionSession: session)
                handle.succeed()
            }
        }

        if let title = experimentalObjectGroupCreationTitle(for: type) {
            menu.addDivider()
            let hasDesigner = VisualEditorResolver.hasVisualEditor(for: type, databaseType: session.connection.databaseType)

            if hasDesigner {
                menu.addActionItem(title, systemImage: experimentalObjectGroupCreationIcon(for: type)) {
                    openNewObjectInDesigner(type: type, session: session)
                }
                menu.addActionItem(title + " (SQL)", systemImage: "scroll") {
                    let schemaName = session.connection.databaseType == .microsoftSQL ? "dbo" : "public"
                    let sql = experimentalObjectGroupCreationSQL(
                        for: title,
                        databaseType: session.connection.databaseType,
                        schemaName: schemaName
                    )
                    environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
                }
            } else if type == .extension {
                menu.addActionItem(title, systemImage: experimentalObjectGroupCreationIcon(for: type)) {
                    environmentState.openExtensionsManagerTab(connectionID: session.connection.id, databaseName: databaseName)
                }
            } else {
                menu.addActionItem(title, systemImage: experimentalObjectGroupCreationIcon(for: type)) {
                    let schemaName = session.connection.databaseType == .microsoftSQL ? "dbo" : "public"
                    let sql = experimentalObjectGroupCreationSQL(
                        for: title,
                        databaseType: session.connection.databaseType,
                        schemaName: schemaName
                    )
                    environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
                }
            }
        }

        return menu
    }

    private func objectMenu(
        for object: SchemaObjectInfo,
        databaseName: String,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        let databaseType = session.connection.databaseType

        menu.addActionItem("New Query", systemImage: "doc.text") {
            environmentState.openQueryTab(for: session, database: databaseName)
        }

        if object.type == .extension {
            menu.addActionItem("New Extension", systemImage: "puzzlepiece.extension") {
                environmentState.openExtensionsManagerTab(connectionID: session.connection.id, databaseName: databaseName)
            }
        }

        menu.addDivider()

        if object.type == .table || object.type == .view || object.type == .materializedView {
            menu.addActionItem("Data", systemImage: "tablecells") {
                let sql = previewQuery(for: object, databaseType: databaseType)
                environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
            }
        }

        if object.type == .table || object.type == .extension {
            menu.addActionItem("Structure", systemImage: object.type == .extension ? "puzzlepiece.fill" : "square.stack.3d.up") {
                environmentState.openStructureTab(for: session, object: object, databaseName: databaseName)
            }
        }

        if object.type == .table {
            menu.addActionItem("Diagram", systemImage: "rectangle.connected.to.line.below") {
                environmentState.openDiagramTab(for: session, object: object, activeDatabaseName: databaseName)
            }
        }

        if [.view, .materializedView, .function, .procedure, .trigger, .sequence, .type].contains(object.type) {
            menu.addActionItem("Definition", systemImage: "doc.text") {
                openDefinition(for: object, databaseName: databaseName, session: session)
            }
        }

        if object.type == .function || object.type == .procedure {
            menu.addActionItem("Execute", systemImage: "play.circle") {
                let sql = executeStatement(for: object, databaseType: databaseType)
                environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
            }
        }

        if VisualEditorResolver.hasVisualEditor(for: object.type, databaseType: databaseType) {
            menu.addActionItem("Edit in Designer", systemImage: "rectangle.and.pencil.and.ellipsis") {
                openObjectInDesigner(object, session: session)
            }
        }

        if object.type == .procedure || object.type == .function {
            menu.addActionItem("Modify", systemImage: "pencil.and.outline") {
                openAlterDefinition(for: object, databaseName: databaseName, session: session)
            }
        }

        let scriptActions = ScriptActionResolver.actions(for: object.type, databaseType: databaseType)
        if !scriptActions.isEmpty {
            menu.addDivider()
            menu.addSubmenu("Script as", systemImage: "scroll") { submenu in
                let readActions = scriptActions.filter(\.isReadGroup)
                let createActions = scriptActions.filter(\.isCreateModifyGroup)
                let writeActions = scriptActions.filter(\.isWriteGroup)
                let executeActions = scriptActions.filter(\.isExecuteGroup)
                let destroyActions = scriptActions.filter(\.isDestroyGroup)

                addScriptActions(readActions, to: submenu, object: object, databaseName: databaseName, session: session)
                if !readActions.isEmpty && !createActions.isEmpty { submenu.addDivider() }
                addScriptActions(createActions, to: submenu, object: object, databaseName: databaseName, session: session)
                if !createActions.isEmpty && !writeActions.isEmpty { submenu.addDivider() }
                addScriptActions(writeActions, to: submenu, object: object, databaseName: databaseName, session: session)
                if !writeActions.isEmpty && !executeActions.isEmpty { submenu.addDivider() }
                if writeActions.isEmpty && !createActions.isEmpty && !executeActions.isEmpty { submenu.addDivider() }
                addScriptActions(executeActions, to: submenu, object: object, databaseName: databaseName, session: session)
                let hasNonDestroy = !executeActions.isEmpty || !writeActions.isEmpty || !createActions.isEmpty || !readActions.isEmpty
                if hasNonDestroy && !destroyActions.isEmpty { submenu.addDivider() }
                addScriptActions(destroyActions, to: submenu, object: object, databaseName: databaseName, session: session)
            }
        }

        if databaseType == .microsoftSQL || object.type == .table || object.type == .view {
            menu.addDivider()
            menu.addSubmenu("Tasks", systemImage: "checklist") { submenu in
                if databaseType == .microsoftSQL {
                    submenu.addActionItem("Generate Scripts", systemImage: "applescript") {
                        sheetState.generateScriptsDatabaseName = databaseName
                        sheetState.generateScriptsConnectionID = session.connection.id
                        sheetState.showGenerateScriptsWizard = true
                    }
                }
                if object.type == .table {
                    submenu.addActionItem("Import Data", systemImage: "square.and.arrow.down") {
                        sheetState.quickImportDatabaseName = databaseName
                        sheetState.quickImportConnectionID = session.connection.id
                        sheetState.showQuickImportSheet = true
                    }
                }
                if object.type == .table && databaseType == .microsoftSQL && object.isSystemVersioned != true && object.isHistoryTable != true {
                    submenu.addActionItem("Enable System Versioning", systemImage: "clock.badge.checkmark") {
                        sheetState.enableVersioningConnectionID = session.connection.id
                        sheetState.enableVersioningDatabaseName = databaseName
                        sheetState.enableVersioningSchemaName = object.schema
                        sheetState.enableVersioningTableName = object.name
                        sheetState.showEnableVersioningSheet = true
                    }
                }
            }
        }

        menu.addDivider()
        menu.addActionItem("Drop \(object.type.displayName)", systemImage: "trash") {
            let sql = dropStatement(for: object, databaseType: databaseType, includeIfExists: false)
            environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
        }

        if object.type == .table {
            menu.addDivider()
            menu.addActionItem("Properties", systemImage: "info.circle") {
                let value = environmentState.prepareTablePropertiesWindow(
                    connectionSessionID: session.connection.id,
                    schemaName: object.schema,
                    tableName: object.name,
                    databaseType: databaseType
                )
                openWindow(id: TablePropertiesWindow.sceneID, value: value)
            }
        } else if VisualEditorResolver.hasVisualEditor(for: object.type, databaseType: databaseType) {
            menu.addDivider()
            menu.addActionItem("Properties", systemImage: "info.circle") {
                openObjectInDesigner(object, session: session)
            }
        }

        return menu
    }

    private func snapshotMenu(snapshot: SQLServerDatabaseSnapshot, session: ConnectionSession) -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("Revert to Snapshot", systemImage: "arrow.uturn.backward") {
            revertSnapshot(snapshot, session: session)
        }
        menu.addDivider()
        menu.addActionItem("Delete Snapshot", systemImage: "trash") {
            deleteSnapshot(snapshot, session: session)
        }
        return menu
    }

    private func linkedServerMenu(
        server: ObjectBrowserSidebarViewModel.LinkedServerItem,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("Test Connection", systemImage: "bolt.horizontal") {
            testLinkedServer(name: server.name, session: session)
        }
        menu.addDivider()
        let dropItem = menu.addActionItem("Drop", systemImage: "trash") {
            sheetState.dropLinkedServerTarget = .init(
                connectionID: session.connection.id,
                serverName: server.name
            )
            sheetState.showDropLinkedServerAlert = true
        }
        dropItem.isEnabled = session.permissions?.canManageLinkedServers ?? true
        return menu
    }

    private func serverTriggerMenu(
        trigger: ObjectBrowserSidebarViewModel.ServerTriggerItem,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()
        if trigger.isDisabled {
            menu.addActionItem("Enable", systemImage: "checkmark.circle") {
                setServerTrigger(trigger.name, enabled: true, session: session)
            }
        } else {
            menu.addActionItem("Disable", systemImage: "pause.circle") {
                setServerTrigger(trigger.name, enabled: false, session: session)
            }
        }
        menu.addDivider()
        menu.addActionItem("Script as CREATE", systemImage: "doc.text") {
            scriptServerTrigger(name: trigger.name, session: session)
        }
        menu.addDivider()
        menu.addActionItem("Drop", systemImage: "trash") {
            dropServerTrigger(name: trigger.name, session: session)
        }
        return menu
    }

    private func agentJobMenu(for session: ConnectionSession) -> NSMenu {
        let menu = NSMenu()
        menu.addActionItem("Open in Tab", systemImage: "list.bullet.rectangle") {
            environmentState.openJobQueueTab(for: session)
        }
        menu.addActionItem("Open in New Window", systemImage: "rectangle.portrait.and.arrow.right") {
            let sessionID = environmentState.prepareJobQueueWindow(for: session)
            openWindow(id: JobQueueWindow.sceneID, value: sessionID)
        }
        return menu
    }

    private func addScriptActions(
        _ actions: [ScriptAction],
        to menu: NSMenu,
        object: SchemaObjectInfo,
        databaseName: String,
        session: ConnectionSession
    ) {
        for action in actions {
            menu.addActionItem(action.title(for: session.connection.databaseType), systemImage: action.systemImage) {
                performScriptAction(action, object: object, databaseName: databaseName, session: session)
            }
        }
    }
}

private extension ObjectBrowserSidebarView {
    func openNewObjectInDesigner(type: SchemaObjectInfo.ObjectType, session: ConnectionSession) {
        let connID = session.connection.id
        let schema = session.connection.databaseType == .microsoftSQL ? "dbo" : "public"

        switch type {
        case .view:
            let value = environmentState.prepareViewEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                existingView: nil,
                isMaterialized: false
            )
            openWindow(id: ViewEditorWindow.sceneID, value: value)
        case .materializedView:
            let value = environmentState.prepareViewEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                existingView: nil,
                isMaterialized: true
            )
            openWindow(id: ViewEditorWindow.sceneID, value: value)
        case .function:
            let value = environmentState.prepareFunctionEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                existingFunction: nil
            )
            openWindow(id: FunctionEditorWindow.sceneID, value: value)
        case .trigger:
            let value = environmentState.prepareTriggerEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                tableName: "",
                existingTrigger: nil
            )
            openWindow(id: TriggerEditorWindow.sceneID, value: value)
        case .sequence:
            let value = environmentState.prepareSequenceEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                existingSequence: nil
            )
            openWindow(id: SequenceEditorWindow.sceneID, value: value)
        case .type:
            let value = environmentState.prepareTypeEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                existingType: nil,
                typeCategory: .composite
            )
            openWindow(id: TypeEditorWindow.sceneID, value: value)
        default:
            break
        }
    }

    func performScriptAction(
        _ action: ScriptAction,
        object: SchemaObjectInfo,
        databaseName: String,
        session: ConnectionSession
    ) {
        let databaseType = session.connection.databaseType
        let qualified = qualifiedName(for: object, databaseType: databaseType)
        let sql: String

        switch action {
        case .select:
            sql = makeSelectStatement(
                qualifiedName: qualified,
                columnLines: "*",
                databaseType: databaseType,
                limit: nil
            )
        case .selectLimited(let limit):
            sql = makeSelectStatement(
                qualifiedName: qualified,
                columnLines: "*",
                databaseType: databaseType,
                limit: limit
            )
        case .create:
            openDefinition(for: object, databaseName: databaseName, session: session, replaceCreateWith: nil)
            return
        case .createOrReplace:
            openDefinition(for: object, databaseName: databaseName, session: session, replaceCreateWith: "CREATE OR REPLACE")
            return
        case .alter:
            openAlterDefinition(for: object, databaseName: databaseName, session: session)
            return
        case .alterTable:
            sql = "ALTER TABLE \(qualified)\n    ADD new_column_name data_type;"
        case .insert:
            sql = "INSERT INTO \(qualified) (column1, column2)\nVALUES (value1, value2);"
        case .update:
            sql = "UPDATE \(qualified)\nSET column1 = value1\nWHERE condition;"
        case .delete:
            sql = "DELETE FROM \(qualified)\nWHERE condition;"
        case .execute:
            sql = executeStatement(for: object, databaseType: databaseType)
        case .drop:
            sql = dropStatement(for: object, databaseType: databaseType, includeIfExists: false)
        case .dropIfExists:
            sql = dropStatement(for: object, databaseType: databaseType, includeIfExists: true)
        }

        environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
    }

    func openDefinition(
        for object: SchemaObjectInfo,
        databaseName: String,
        session: ConnectionSession,
        replaceCreateWith replacement: String? = nil
    ) {
        Task {
            do {
                var definition = try await session.session.getObjectDefinition(
                    objectName: object.name,
                    schemaName: object.schema,
                    objectType: object.type,
                    database: databaseName
                )
                if let replacement,
                   let range = definition.range(of: "CREATE", options: .caseInsensitive) {
                    definition = definition.replacingCharacters(in: range, with: replacement)
                }
                environmentState.openQueryTab(for: session, presetQuery: definition, database: databaseName)
            } catch {
                environmentState.lastError = DatabaseError.from(error)
            }
        }
    }

    func openAlterDefinition(for object: SchemaObjectInfo, databaseName: String, session: ConnectionSession) {
        Task {
            do {
                var definition = try await session.session.getObjectDefinition(
                    objectName: object.name,
                    schemaName: object.schema,
                    objectType: object.type,
                    database: databaseName
                )
                if let range = definition.range(of: "CREATE", options: .caseInsensitive) {
                    definition = definition.replacingCharacters(in: range, with: "ALTER")
                }
                environmentState.openQueryTab(for: session, presetQuery: definition, database: databaseName)
            } catch {
                environmentState.lastError = DatabaseError.from(error)
            }
        }
    }

    func openObjectInDesigner(_ object: SchemaObjectInfo, session: ConnectionSession) {
        switch object.type {
        case .view:
            let value = environmentState.prepareViewEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                existingView: object.name,
                isMaterialized: false
            )
            openWindow(id: ViewEditorWindow.sceneID, value: value)
        case .materializedView:
            let value = environmentState.prepareViewEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                existingView: object.name,
                isMaterialized: true
            )
            openWindow(id: ViewEditorWindow.sceneID, value: value)
        case .trigger:
            let value = environmentState.prepareTriggerEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                tableName: object.triggerTable ?? "",
                existingTrigger: object.name
            )
            openWindow(id: TriggerEditorWindow.sceneID, value: value)
        case .function:
            let value = environmentState.prepareFunctionEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                existingFunction: object.name
            )
            openWindow(id: FunctionEditorWindow.sceneID, value: value)
        case .sequence:
            let value = environmentState.prepareSequenceEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                existingSequence: object.name
            )
            openWindow(id: SequenceEditorWindow.sceneID, value: value)
        case .type:
            let value = environmentState.prepareTypeEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                existingType: object.name,
                typeCategory: .composite
            )
            openWindow(id: TypeEditorWindow.sceneID, value: value)
        default:
            break
        }
    }

    func previewQuery(for object: SchemaObjectInfo, databaseType: DatabaseType) -> String {
        let qualified = qualifiedName(for: object, databaseType: databaseType)
        return switch databaseType {
        case .microsoftSQL:
            "SELECT TOP 1000 * FROM \(qualified);"
        default:
            "SELECT * FROM \(qualified) LIMIT 1000;"
        }
    }

    func executeStatement(for object: SchemaObjectInfo, databaseType: DatabaseType) -> String {
        let qualified = qualifiedName(for: object, databaseType: databaseType)
        return switch databaseType {
        case .microsoftSQL:
            "EXEC \(qualified);"
        case .postgresql:
            "SELECT * FROM \(qualified)();"
        case .mysql, .sqlite:
            "CALL \(qualified)();"
        }
    }

    func dropStatement(for object: SchemaObjectInfo, databaseType: DatabaseType, includeIfExists: Bool) -> String {
        let qualified = qualifiedName(for: object, databaseType: databaseType)
        let keyword: String = switch object.type {
        case .table: "TABLE"
        case .view: "VIEW"
        case .materializedView: "MATERIALIZED VIEW"
        case .function: "FUNCTION"
        case .procedure: "PROCEDURE"
        case .trigger: "TRIGGER"
        case .extension: "EXTENSION"
        case .sequence: "SEQUENCE"
        case .type: "TYPE"
        case .synonym: "SYNONYM"
        }
        let ifExists = includeIfExists ? " IF EXISTS" : ""
        return "DROP \(keyword)\(ifExists) \(qualified);"
    }

    func qualifiedName(for object: SchemaObjectInfo, databaseType: DatabaseType) -> String {
        switch databaseType {
        case .microsoftSQL:
            "[\(object.schema)].[\(object.name)]"
        case .postgresql:
            "\"\(object.schema.replacingOccurrences(of: "\"", with: "\"\""))\".\"\(object.name.replacingOccurrences(of: "\"", with: "\"\""))\""
        case .mysql:
            "`\(object.schema)`.`\(object.name)`"
        case .sqlite:
            "\"\(object.name.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
    }
}

private func experimentalObjectGroupCreationTitle(for type: SchemaObjectInfo.ObjectType) -> String? {
    switch type {
    case .table: "New Table"
    case .view: "New View"
    case .materializedView: "New Materialized View"
    case .function: "New Function"
    case .procedure: "New Procedure"
    case .trigger: "New Trigger"
    case .extension: "New Extension"
    case .sequence: "New Sequence"
    case .type: "New Type"
    case .synonym: "New Synonym"
    }
}

private func experimentalObjectGroupCreationIcon(for type: SchemaObjectInfo.ObjectType) -> String {
    switch type {
    case .table: "tablecells"
    case .view: "eye"
    case .materializedView: "eye"
    case .function: "function"
    case .procedure: "gearshape"
    case .trigger: "bolt"
    case .extension: "puzzlepiece.extension"
    case .sequence: "number"
    case .type: "t.square"
    case .synonym: "arrow.triangle.swap"
    }
}

private func experimentalObjectGroupCreationSQL(
    for title: String,
    databaseType: DatabaseType,
    schemaName: String
) -> String {
    switch (title, databaseType) {
    case ("New Table", .microsoftSQL):
        "CREATE TABLE [\(schemaName)].[NewTable] (\n    [Id] INT IDENTITY(1,1) PRIMARY KEY,\n    [Name] NVARCHAR(100) NOT NULL\n);\nGO"
    case ("New Table", .postgresql):
        "CREATE TABLE \(schemaName).new_table (\n    id SERIAL PRIMARY KEY,\n    name TEXT NOT NULL\n);"
    case ("New Table", .mysql):
        "CREATE TABLE new_table (\n    id INT AUTO_INCREMENT PRIMARY KEY,\n    name VARCHAR(100) NOT NULL\n);"
    case ("New Table", .sqlite):
        "CREATE TABLE new_table (\n    id INTEGER PRIMARY KEY AUTOINCREMENT,\n    name TEXT NOT NULL\n);"
    case ("New View", .microsoftSQL):
        "CREATE VIEW [\(schemaName)].[NewView]\nAS\n    SELECT * FROM [\(schemaName)].[TableName];\nGO"
    case ("New View", .postgresql):
        "CREATE VIEW \(schemaName).new_view AS\n    SELECT * FROM \(schemaName).table_name;"
    case ("New View", _):
        "CREATE VIEW new_view AS\n    SELECT * FROM table_name;"
    case ("New Materialized View", _):
        "CREATE MATERIALIZED VIEW \(schemaName).new_materialized_view AS\n    SELECT * FROM \(schemaName).table_name;"
    case ("New Function", .microsoftSQL):
        "CREATE FUNCTION [\(schemaName)].[NewFunction]\n(\n    @param1 INT\n)\nRETURNS INT\nAS\nBEGIN\n    RETURN @param1;\nEND;\nGO"
    case ("New Function", .postgresql):
        "CREATE FUNCTION \(schemaName).new_function(param1 INTEGER)\nRETURNS INTEGER\nLANGUAGE plpgsql\nAS $$\nBEGIN\n    RETURN param1;\nEND;\n$$;"
    case ("New Function", _):
        "CREATE FUNCTION new_function(param1 INT)\nRETURNS INT\nDETERMINISTIC\nBEGIN\n    RETURN param1;\nEND;"
    case ("New Procedure", .microsoftSQL):
        "CREATE PROCEDURE [\(schemaName)].[NewProcedure]\n    @param1 INT\nAS\nBEGIN\n    SET NOCOUNT ON;\n    SELECT @param1;\nEND;\nGO"
    case ("New Procedure", _):
        "CREATE PROCEDURE \(schemaName).new_procedure(param1 INTEGER)\nLANGUAGE plpgsql\nAS $$\nBEGIN\n    -- procedure body\nEND;\n$$;"
    case ("New Trigger", .microsoftSQL):
        "CREATE TRIGGER [\(schemaName)].[NewTrigger]\nON [\(schemaName)].[TableName]\nAFTER INSERT\nAS\nBEGIN\n    SET NOCOUNT ON;\n    -- trigger body\nEND;\nGO"
    case ("New Trigger", .postgresql):
        "CREATE TRIGGER new_trigger\n    AFTER INSERT ON \(schemaName).table_name\n    FOR EACH ROW\n    EXECUTE FUNCTION \(schemaName).trigger_function();"
    case ("New Trigger", _):
        "CREATE TRIGGER new_trigger\n    AFTER INSERT ON table_name\n    FOR EACH ROW\nBEGIN\n    -- trigger body\nEND;"
    case ("New Sequence", .microsoftSQL):
        "CREATE SEQUENCE [\(schemaName)].[NewSequence]\n    AS INT\n    START WITH 1\n    INCREMENT BY 1;\nGO"
    case ("New Sequence", _):
        "CREATE SEQUENCE \(schemaName).new_sequence\n    START WITH 1\n    INCREMENT BY 1;"
    case ("New Type", .microsoftSQL):
        "CREATE TYPE [\(schemaName)].[NewType] AS TABLE (\n    [Id] INT,\n    [Name] NVARCHAR(100)\n);\nGO"
    case ("New Type", _):
        "CREATE TYPE \(schemaName).new_type AS (\n    field1 TEXT,\n    field2 INTEGER\n);"
    case ("New Synonym", .microsoftSQL):
        "CREATE SYNONYM [\(schemaName)].[NewSynonym]\n    FOR [\(schemaName)].[TargetObject];\nGO"
    default:
        "-- \(title)"
    }
}
