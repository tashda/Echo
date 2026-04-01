import SwiftUI
import AppKit

// MARK: - NSMenu Builder (lazy — only runs on right-click)

@MainActor
func buildDatabaseNSMenu(
    database: DatabaseInfo,
    session: ConnectionSession,
    viewModel: ObjectBrowserSidebarViewModel,
    sheetState: SidebarSheetState,
    environmentState: EnvironmentState,
    projectStore: ProjectStore,
    openWindow: OpenWindowAction,
    runMSSQLTask: @escaping (ConnectionSession, String, String) -> Void
) -> NSMenu {
    let menu = NSMenu()
    let connID = session.connection.id
    let dbType = session.connection.databaseType

    // Group 1: Refresh
    menu.addActionItem("Refresh Schema", systemImage: "arrow.clockwise") {
        viewModel.ensureDatabaseExpanded(connectionID: connID, databaseName: database.name)
        viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
        Task {
            let handle = AppDirector.shared.activityEngine.begin("Refreshing schema for \(database.name)", connectionSessionID: session.id)
            await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
            handle.succeed()
            viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
        }
    }

    // Group 2: New Query
    menu.addActionItem("New Query", systemImage: "doc.text") {
        environmentState.openQueryTab(for: session, database: database.name)
    }

    menu.addDivider()

    // Group 3: Open / View
    if dbType == .postgresql {
        if projectStore.globalSettings.managedPostgresConsoleEnabled {
            menu.addActionItem("Postgres Console", systemImage: "terminal") {
                environmentState.openPSQLTab(for: session, database: database.name)
            }
        }
    }

    menu.addDivider()

    // Group 7: Maintenance
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
        menu.addActionItem("Detach Database...", systemImage: "externaldrive.badge.minus") {
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
                    runMSSQLTask(session, database.name, "shrink")
                }
                sub.addDivider()
                sub.addActionItem("Take Offline", systemImage: "bolt.slash") {
                    runMSSQLTask(session, database.name, "takeOffline")
                }
                sub.addDivider()
                sub.addActionItem("Detach Database...", systemImage: "externaldrive.badge.minus") {
                    sheetState.detachDatabaseName = database.name
                    sheetState.detachConnectionID = connID
                    sheetState.showDetachSheet = true
                }
                sub.addDivider()
                sub.addActionItem("Generate Scripts...", systemImage: "script.badge.plus") {
                    sheetState.generateScriptsDatabaseName = database.name
                    sheetState.generateScriptsConnectionID = connID
                    sheetState.showGenerateScriptsWizard = true
                }
                sub.addActionItem("Import Flat File...", systemImage: "square.and.arrow.down.on.square") {
                    sheetState.quickImportDatabaseName = database.name
                    sheetState.quickImportConnectionID = connID
                    sheetState.showQuickImportSheet = true
                }
                sub.addActionItem("Migrate Data...", systemImage: "arrow.right.arrow.left") {
                    sheetState.dataMigrationConnectionID = connID
                    sheetState.showDataMigrationWizard = true
                }
                sub.addActionItem("Visual Query Builder", systemImage: "hammer") {
                    environmentState.openQueryBuilderTab(connectionID: connID)
                }
                sub.addDivider()
                sub.addActionItem("Data-tier Application Tasks...", systemImage: "archivebox") {
                    sheetState.dacWizardDatabaseName = database.name
                    sheetState.dacWizardConnectionID = connID
                    sheetState.showDACWizard = true
                }
            } else {
                sub.addActionItem("Bring Online", systemImage: "bolt") {
                    runMSSQLTask(session, database.name, "bringOnline")
                }
                sub.addActionItem("Restore", systemImage: "arrow.up.doc") {
                    environmentState.openMaintenanceBackups(connectionID: connID, databaseName: database.name, action: .restore)
                }
            }
        }
    }

    menu.addDivider()

    // Group 9: Destructive
    if dbType == .postgresql {
        menu.addSubmenu("Drop Database", systemImage: "trash") { sub in
            sub.addActionItem("Drop") {
                sheetState.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .standard)
                sheetState.showDropDatabaseAlert = true
            }
            sub.addActionItem("Drop (Cascade)") {
                sheetState.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .cascade)
                sheetState.showDropDatabaseAlert = true
            }
            sub.addActionItem("Drop (Force)") {
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

    // Group 10: Properties
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


extension ObjectBrowserSidebarView {

    // MARK: - Database Context Menu (SwiftUI — kept for reference but no longer used on header rows)

    @ViewBuilder
    func databaseContextMenu(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id

        // Group 1: Refresh
        Button {
            viewModel.ensureDatabaseExpanded(connectionID: connID, databaseName: database.name)
            viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
            Task {
                let handle = AppDirector.shared.activityEngine.begin("Refreshing schema for \(database.name)", connectionSessionID: session.id)
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                handle.succeed()
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
            }
        } label: {
            Label("Refresh Schema", systemImage: "arrow.clockwise")
        }

        // Group 2: New
        Button {
            environmentState.openQueryTab(for: session, database: database.name)
        } label: {
            Label("New Query", systemImage: "doc.text")
        }

        Divider()

        // Group 3: Open / View
        if session.connection.databaseType == .postgresql {
            if projectStore.globalSettings.managedPostgresConsoleEnabled {
                Button {
                    environmentState.openPSQLTab(for: session, database: database.name)
                } label: {
                    Label("Postgres Console", systemImage: "terminal")
                }
            }
            if projectStore.globalSettings.nativePsqlEnabled {
                Button {} label: {
                    Label("Native psql (Coming Soon)", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .disabled(true)
            }
        }

        Divider()

        // Group 7: Maintenance
        Button {
            environmentState.openMaintenanceTab(connectionID: connID, databaseName: database.name)
        } label: {
            Label("Maintenance", systemImage: "wrench.and.screwdriver")
        }

        if session.connection.databaseType == .postgresql {
            Menu("Tasks", systemImage: "gearshape") {
                Button {
                    sheetState.pgBackupDatabaseName = database.name
                    sheetState.pgBackupConnectionID = connID
                    sheetState.showPgBackupSheet = true
                } label: {
                    Label("Back Up", systemImage: "arrow.down.doc")
                }
                Button {
                    sheetState.pgBackupDatabaseName = database.name
                    sheetState.pgBackupConnectionID = connID
                    sheetState.showPgRestoreSheet = true
                } label: {
                    Label("Restore", systemImage: "arrow.up.doc")
                }
            }
        }

        if session.connection.databaseType == .mysql {
            Menu("Tasks", systemImage: "gearshape") {
                Button {
                    sheetState.mysqlBackupDatabaseName = database.name
                    sheetState.mysqlBackupConnectionID = connID
                    sheetState.showMySQLBackupSheet = true
                } label: {
                    Label("Back Up", systemImage: "arrow.down.doc")
                }
                Button {
                    sheetState.mysqlBackupDatabaseName = database.name
                    sheetState.mysqlBackupConnectionID = connID
                    sheetState.showMySQLRestoreSheet = true
                } label: {
                    Label("Restore", systemImage: "arrow.up.doc")
                }
            }
        }

        if session.connection.databaseType == .sqlite
            && database.name.lowercased() != "main"
            && database.name.lowercased() != "temp" {
            Divider()
            Button {
                sheetState.detachDatabaseName = database.name
                sheetState.detachConnectionID = connID
                sheetState.showDetachSheet = true
            } label: {
                Label("Detach Database...", systemImage: "externaldrive.badge.minus")
            }
        }

        if session.connection.databaseType == .microsoftSQL {
            Menu("Advanced Objects", systemImage: "puzzlepiece.extension") {
                Button {
                    environmentState.openMSSQLAdvancedObjectsTab(connectionID: connID, databaseName: database.name, section: .changeTracking)
                } label: {
                    Label("Change Tracking", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }

                Button {
                    environmentState.openMSSQLAdvancedObjectsTab(connectionID: connID, databaseName: database.name, section: .cdc)
                } label: {
                    Label("Change Data Capture", systemImage: "arrow.triangle.branch")
                }

                Button {
                    environmentState.openMSSQLAdvancedObjectsTab(connectionID: connID, databaseName: database.name, section: .fullTextSearch)
                } label: {
                    Label("Full-Text Search", systemImage: "text.magnifyingglass")
                }

                Button {
                    environmentState.openMSSQLAdvancedObjectsTab(connectionID: connID, databaseName: database.name, section: .replication)
                } label: {
                    Label("Replication", systemImage: "arrow.triangle.swap")
                }
            }
            .disabled(!database.isOnline)

            Menu("Tasks", systemImage: "gearshape") {
                if database.isOnline {
                    Button {
                        environmentState.openMaintenanceBackups(connectionID: connID, databaseName: database.name, action: .backup)
                    } label: {
                        Label("Back Up", systemImage: "arrow.down.doc")
                    }

                    Button {
                        environmentState.openMaintenanceBackups(connectionID: connID, databaseName: database.name, action: .restore)
                    } label: {
                        Label("Restore", systemImage: "arrow.up.doc")
                    }

                    Divider()

                    Button {
                        Task { await runMSSQLTask(session: session, database: database.name, task: .shrink) }
                    } label: {
                        Label("Shrink Database", systemImage: "arrow.down.right.and.arrow.up.left")
                    }

                    Divider()

                    Button {
                        Task { await runMSSQLTask(session: session, database: database.name, task: .takeOffline) }
                    } label: {
                        Label("Take Offline", systemImage: "bolt.slash")
                    }

                    Divider()

                    Button {
                        sheetState.detachDatabaseName = database.name
                        sheetState.detachConnectionID = connID
                        sheetState.showDetachSheet = true
                    } label: {
                        Label("Detach Database...", systemImage: "externaldrive.badge.minus")
                    }

                    Divider()

                    Button {
                        sheetState.generateScriptsDatabaseName = database.name
                        sheetState.generateScriptsConnectionID = connID
                        sheetState.showGenerateScriptsWizard = true
                    } label: {
                        Label("Generate Scripts...", systemImage: "script.badge.plus")
                    }

                    Button {
                        sheetState.quickImportDatabaseName = database.name
                        sheetState.quickImportConnectionID = connID
                        sheetState.showQuickImportSheet = true
                    } label: {
                        Label("Import Flat File...", systemImage: "square.and.arrow.down.on.square")
                    }

                    Button {
                        sheetState.dataMigrationConnectionID = connID
                        sheetState.showDataMigrationWizard = true
                    } label: {
                        Label("Migrate Data...", systemImage: "arrow.right.arrow.left")
                    }

                    Button {
                        environmentState.openQueryBuilderTab(connectionID: connID)
                    } label: {
                        Label("Visual Query Builder", systemImage: "hammer")
                    }

                    Divider()

                    Button {
                        sheetState.dacWizardDatabaseName = database.name
                        sheetState.dacWizardConnectionID = connID
                        sheetState.showDACWizard = true
                    } label: {
                        Label("Data-tier Application Tasks...", systemImage: "archivebox")
                    }
                } else {
                    Button {
                        Task { await runMSSQLTask(session: session, database: database.name, task: .bringOnline) }
                    } label: {
                        Label("Bring Online", systemImage: "bolt")
                    }

                    Button {
                        environmentState.openMaintenanceBackups(connectionID: connID, databaseName: database.name, action: .restore)
                    } label: {
                        Label("Restore", systemImage: "arrow.up.doc")
                    }
                }
            }
        }

        Divider()

        // Group 9: Destructive
        if session.connection.databaseType == .postgresql {
            Menu("Drop Database", systemImage: "trash") {
                Button(role: .destructive) {
                    sheetState.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .standard)
                    sheetState.showDropDatabaseAlert = true
                } label: {
                    Label("Drop", systemImage: "trash")
                }
                Button(role: .destructive) {
                    sheetState.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .cascade)
                    sheetState.showDropDatabaseAlert = true
                } label: {
                    Label("Drop (Cascade)", systemImage: "trash")
                }
                Button(role: .destructive) {
                    sheetState.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .force)
                    sheetState.showDropDatabaseAlert = true
                } label: {
                    Label("Drop (Force)", systemImage: "trash")
                }
            }
        } else {
            Button(role: .destructive) {
                sheetState.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: session.connection.databaseType, variant: .standard)
                sheetState.showDropDatabaseAlert = true
            } label: {
                Label("Drop Database", systemImage: "trash")
            }
        }

        Divider()

        // Group 10: Properties — ALWAYS last
        Button {
            let value = environmentState.prepareDatabaseEditorWindow(
                connectionSessionID: session.connection.id,
                databaseName: database.name,
                databaseType: session.connection.databaseType
            )
            openWindow(id: DatabaseEditorWindow.sceneID, value: value)
        } label: {
            Label("Properties", systemImage: "info.circle")
        }
    }
}
