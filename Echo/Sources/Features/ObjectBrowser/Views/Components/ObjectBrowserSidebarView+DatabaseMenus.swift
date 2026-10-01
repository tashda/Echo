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
