import AppKit
import SwiftUI
import SQLServerKit

/// Menus for the Databases section, databases, and the folders inside a database.
extension ObjectBrowserSidebarView {
    func databasesFolderMenu(for session: ConnectionSession) -> NSMenu {
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
        menu.addDivider()
        let connID = session.connection.id
        let hideItem = menu.addActionItem(hideOfflineDatabasesTitle(for: connID), systemImage: "eye.slash") {
            self.toggleHideOffline(for: connID)
        }
        hideItem.state = (viewModel.hideOfflineDatabasesBySession[connID] ?? false) ? .on : .off
        return menu
    }

    func databaseMenu(for database: DatabaseInfo, session: ConnectionSession) -> NSMenu {
        let menu = NSMenu()
        let connID = session.connection.id
        let dbType = session.connection.databaseType
        let isOnlineSQLServer = dbType == .microsoftSQL && database.isOnline

        menu.addActionItem("New Query", systemImage: "plus.rectangle") {
            environmentState.openQueryTab(for: session, database: database.name)
        }
        if dbType == .postgresql, projectStore.globalSettings.managedPostgresConsoleEnabled {
            menu.addActionItem("Postgres Console", systemImage: "terminal") {
                environmentState.openPSQLTab(for: session, database: database.name)
            }
        }
        if dbType == .microsoftSQL {
            menu.addActionItem("Query Builder", systemImage: "square.stack.3d.up") {
                environmentState.openQueryBuilderTab(connectionID: connID)
            }
        }

        menu.addDivider()
        addBackUpAndRestore(to: menu, database: database, session: session)
        menu.addCopyName(database.name)
        if isOnlineSQLServer {
            addMSSQLTasksSubmenu(to: menu, database: database, session: session)
        }
        if dbType == .sqlite && database.name.lowercased() != "main" && database.name.lowercased() != "temp" {
            menu.addActionItem("Detach Database", systemImage: "externaldrive.badge.minus") {
                sheetState.detachDatabaseName = database.name
                sheetState.detachConnectionID = connID
                sheetState.showDetachSheet = true
            }
        }
        addOpenTool(to: menu, database: database, session: session)

        menu.addDivider()
        menu.addActionItem("Refresh", systemImage: "arrow.clockwise") {
            viewModel.setExpanded(true, nodeID: ObjectBrowserSidebarViewModel.databaseNodeID(connectionID: connID, databaseName: database.name))
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing schema for \(database.name)", connectionSessionID: session.id)
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                handle.succeed()
            }
        }
        if dbType == .microsoftSQL, !database.isOnline {
            menu.addActionItem("Bring Online", systemImage: "bolt") {
                Task { await self.runMSSQLTask(session: session, database: database.name, task: .bringOnline) }
            }
        }

        menu.addDivider()
        addDropDatabase(to: menu, database: database, session: session)

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

    /// Back Up and Restore sit in the menu itself (round 42.3, BU1).
    private func addBackUpAndRestore(to menu: NSMenu, database: DatabaseInfo, session: ConnectionSession) {
        let connID = session.connection.id
        switch session.connection.databaseType {
        case .postgresql:
            menu.addActionItem("Back Up", systemImage: "arrow.down.doc") {
                sheetState.pgBackupDatabaseName = database.name
                sheetState.pgBackupConnectionID = connID
                sheetState.showPgBackupSheet = true
            }
            menu.addActionItem("Restore", systemImage: "arrow.up.doc") {
                sheetState.pgBackupDatabaseName = database.name
                sheetState.pgBackupConnectionID = connID
                sheetState.showPgRestoreSheet = true
            }
        case .mysql:
            menu.addActionItem("Back Up", systemImage: "arrow.down.doc") {
                sheetState.mysqlBackupDatabaseName = database.name
                sheetState.mysqlBackupConnectionID = connID
                sheetState.showMySQLBackupSheet = true
            }
            menu.addActionItem("Restore", systemImage: "arrow.up.doc") {
                sheetState.mysqlBackupDatabaseName = database.name
                sheetState.mysqlBackupConnectionID = connID
                sheetState.showMySQLRestoreSheet = true
            }
        case .microsoftSQL:
            if database.isOnline {
                menu.addActionItem("Back Up", systemImage: "arrow.down.doc") {
                    environmentState.openMaintenanceBackups(connectionID: connID, databaseName: database.name, action: .backup)
                }
            }
            menu.addActionItem("Restore", systemImage: "arrow.up.doc") {
                environmentState.openMaintenanceBackups(connectionID: connID, databaseName: database.name, action: .restore)
            }
        case .sqlite:
            break
        }
    }

    /// The tasks that are not Back Up or Restore, in one submenu (SQL Server).
    private func addMSSQLTasksSubmenu(to menu: NSMenu, database: DatabaseInfo, session: ConnectionSession) {
        let connID = session.connection.id
        menu.addSubmenu("Tasks", systemImage: "checklist") { sub in
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
            sub.addDivider()
            sub.addActionItem("Shrink Database", systemImage: "arrow.down.right.and.arrow.up.left") {
                Task { await self.runMSSQLTask(session: session, database: database.name, task: .shrink) }
            }
            sub.addActionItem("Take Offline", systemImage: "bolt.slash") {
                Task { await self.runMSSQLTask(session: session, database: database.name, task: .takeOffline) }
            }
            sub.addActionItem("Detach Database", systemImage: "externaldrive.badge.minus") {
                sheetState.detachDatabaseName = database.name
                sheetState.detachConnectionID = connID
                sheetState.showDetachSheet = true
            }
            sub.addDivider()
            sub.addActionItem("Data-tier Application", systemImage: "archivebox") {
                sheetState.dacWizardDatabaseName = database.name
                sheetState.dacWizardConnectionID = connID
                sheetState.showDACWizard = true
            }
        }
    }

    /// Maintenance, Security Overview and the advanced objects, in one Open Tool submenu (round 42.3, AO0).
    private func addOpenTool(to menu: NSMenu, database: DatabaseInfo, session: ConnectionSession) {
        let connID = session.connection.id
        let openMaintenance = {
            environmentState.openMaintenanceTab(connectionID: connID, databaseName: database.name)
        }
        guard session.connection.databaseType == .microsoftSQL else {
            menu.addActionItem("Maintenance", systemImage: "wrench.and.screwdriver", action: openMaintenance)
            return
        }
        menu.addSubmenu("Open Tool", systemImage: "wrench.and.screwdriver") { sub in
            sub.addActionItem("Maintenance", systemImage: "wrench.and.screwdriver", action: openMaintenance)
            sub.addActionItem("Security Overview", systemImage: "lock.shield") {
                environmentState.openDatabaseSecurityTab(connectionID: connID, databaseName: database.name)
            }
            sub.addDivider()
            let advanced: [(String, String, MSSQLAdvancedObjectsViewModel.Section)] = [
                ("Change Tracking", "clock.arrow.trianglehead.counterclockwise.rotate.90", .changeTracking),
                ("Change Data Capture", "arrow.triangle.branch", .cdc),
                ("Full-Text Search", "text.magnifyingglass", .fullTextSearch),
                ("Replication", "arrow.triangle.swap", .replication),
            ]
            for (title, symbol, section) in advanced {
                sub.addActionItem(title, systemImage: symbol) {
                    environmentState.openMSSQLAdvancedObjectsTab(connectionID: connID, databaseName: database.name, section: section)
                }
            }
        }
    }

    private func addDropDatabase(to menu: NSMenu, database: DatabaseInfo, session: ConnectionSession) {
        let connID = session.connection.id
        let dbType = session.connection.databaseType
        func target(_ variant: SidebarSheetState.DropVariant) -> () -> Void {
            {
                sheetState.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: dbType, variant: variant)
                sheetState.showDropDatabaseAlert = true
            }
        }
        if dbType == .postgresql {
            menu.addSubmenu("Drop Database", systemImage: "trash") { sub in
                sub.addActionItem("Drop", systemImage: "trash", action: target(.standard))
                sub.addActionItem("Drop (Cascade)", systemImage: "trash", action: target(.cascade))
                sub.addActionItem("Drop (Force)", systemImage: "trash", action: target(.force))
            }
        } else {
            menu.addActionItem("Drop Database", systemImage: "trash", action: target(.standard))
        }
    }

    func databaseFolderMenu(
        kind: ExplorerNodeKind,
        databaseName: String,
        session: ConnectionSession
    ) -> NSMenu {
        let menu = NSMenu()

        switch kind {
        case .databaseSecurity:
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
        default:
            break
        }

        return menu
    }

    func databaseSubfolderMenu(
        kind: ExplorerNodeKind,
        databaseName: String,
        session: ConnectionSession
    ) -> NSMenu? {
        let menu = NSMenu()
        switch kind {
        case .messageTypes:
            menu.addActionItem("New Message Type", systemImage: "plus") {
                sheetState.newMessageTypeConnectionID = session.connection.id
                sheetState.newMessageTypeDatabaseName = databaseName
                sheetState.showNewMessageTypeSheet = true
            }
        case .contracts:
            menu.addActionItem("New Contract", systemImage: "plus") {
                sheetState.newContractConnectionID = session.connection.id
                sheetState.newContractDatabaseName = databaseName
                sheetState.showNewContractSheet = true
            }
        case .queues:
            menu.addActionItem("New Queue", systemImage: "plus") {
                sheetState.newQueueConnectionID = session.connection.id
                sheetState.newQueueDatabaseName = databaseName
                sheetState.showNewQueueSheet = true
            }
        case .services:
            menu.addActionItem("New Service", systemImage: "plus") {
                sheetState.newServiceConnectionID = session.connection.id
                sheetState.newServiceDatabaseName = databaseName
                sheetState.showNewServiceSheet = true
            }
        case .routes:
            menu.addActionItem("New Route", systemImage: "plus") {
                sheetState.newRouteConnectionID = session.connection.id
                sheetState.newRouteDatabaseName = databaseName
                sheetState.showNewRouteSheet = true
            }
        case .externalDataSources:
            menu.addActionItem("New External Data Source", systemImage: "plus") {
                sheetState.newExternalDataSourceConnectionID = session.connection.id
                sheetState.newExternalDataSourceDatabaseName = databaseName
                sheetState.showNewExternalDataSourceSheet = true
            }
        case .externalTables:
            menu.addActionItem("New External Table", systemImage: "plus") {
                sheetState.newExternalTableConnectionID = session.connection.id
                sheetState.newExternalTableDatabaseName = databaseName
                sheetState.showNewExternalTableSheet = true
            }
        case .externalFileFormats:
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
}
