import SwiftUI

extension ObjectBrowserSidebarView {

    // MARK: - Database Context Menu

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

        if session.connection.databaseType == .microsoftSQL {
            Button {
                environmentState.openQueryStoreTab(connectionID: connID, databaseName: database.name)
            } label: {
                Label("Query Store", systemImage: "chart.bar.xaxis")
            }
            .disabled(!database.isOnline)
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
                    viewModel.pgBackupDatabaseName = database.name
                    viewModel.pgBackupConnectionID = connID
                    viewModel.showPgBackupSheet = true
                } label: {
                    Label("Back Up", systemImage: "arrow.down.doc")
                }
                Button {
                    viewModel.pgBackupDatabaseName = database.name
                    viewModel.pgBackupConnectionID = connID
                    viewModel.showPgRestoreSheet = true
                } label: {
                    Label("Restore", systemImage: "arrow.up.doc")
                }
            }
        }

        if session.connection.databaseType == .microsoftSQL {
            Button {
                viewModel.changeTrackingDatabaseName = database.name
                viewModel.changeTrackingConnectionID = connID
                viewModel.showChangeTrackingSheet = true
            } label: {
                Label("Change Tracking / CDC", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(!database.isOnline)

            Button {
                viewModel.fullTextDatabaseName = database.name
                viewModel.fullTextConnectionID = connID
                viewModel.showFullTextSheet = true
            } label: {
                Label("Full-Text Search", systemImage: "text.magnifyingglass")
            }
            .disabled(!database.isOnline)

            Button {
                viewModel.replicationDatabaseName = database.name
                viewModel.replicationConnectionID = connID
                viewModel.showReplicationSheet = true
            } label: {
                Label("Replication", systemImage: "arrow.triangle.swap")
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
                    viewModel.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .standard)
                    viewModel.showDropDatabaseAlert = true
                } label: {
                    Label("Drop", systemImage: "trash")
                }
                Button(role: .destructive) {
                    viewModel.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .cascade)
                    viewModel.showDropDatabaseAlert = true
                } label: {
                    Label("Drop (Cascade)", systemImage: "trash")
                }
                Button(role: .destructive) {
                    viewModel.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .force)
                    viewModel.showDropDatabaseAlert = true
                } label: {
                    Label("Drop (Force)", systemImage: "trash")
                }
            }
        } else {
            Button(role: .destructive) {
                viewModel.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: session.connection.databaseType, variant: .standard)
                viewModel.showDropDatabaseAlert = true
            } label: {
                Label("Drop Database", systemImage: "trash")
            }
        }

        Divider()

        // Group 10: Properties — ALWAYS last
        Button {
            viewModel.propertiesDatabaseName = database.name
            viewModel.propertiesConnectionID = connID
            viewModel.showDatabaseProperties = true
        } label: {
            Label("Properties", systemImage: "info.circle")
        }
    }
}
