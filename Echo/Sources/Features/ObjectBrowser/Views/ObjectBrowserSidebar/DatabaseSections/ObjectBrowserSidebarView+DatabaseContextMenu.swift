import SwiftUI

extension ObjectBrowserSidebarView {

    // MARK: - Database Context Menu

    @ViewBuilder
    func databaseContextMenu(database: DatabaseInfo, session: ConnectionSession) -> some View {
        let connID = session.connection.id

        Button {
            viewModel.ensureDatabaseExpanded(connectionID: connID, databaseName: database.name)
            viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: true)
            Task {
                await environmentState.loadSchemaForDatabase(database.name, connectionSession: session)
                viewModel.setDatabaseLoading(connectionID: connID, databaseName: database.name, loading: false)
            }
        } label: {
            Label("Refresh Schema", systemImage: "arrow.clockwise")
        }

        Divider()

        // New Query in this database
        Button {
            environmentState.openQueryTab(for: session, database: database.name)
        } label: {
            Label("New Query", systemImage: "doc.badge.plus")
        }

        if session.connection.databaseType == .postgresql {
            if projectStore.globalSettings.managedPostgresConsoleEnabled {
                Button {
                    environmentState.openPSQLTab(for: session, database: database.name)
                } label: {
                    Label("Postgres Console", systemImage: "terminal")
                }
            }
            if projectStore.globalSettings.nativePsqlEnabled {
                Button {
                } label: {
                    Label("Native psql (Coming Soon)", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .disabled(true)
            }
        }

        Divider()

        Button {
            environmentState.openMaintenanceTab(connectionID: connID, databaseName: database.name)
        } label: {
            Label("Maintenance", systemImage: "wrench.and.screwdriver")
        }

        // MSSQL-specific operations
        if session.connection.databaseType == .microsoftSQL {
            Button {
                environmentState.openQueryStoreTab(connectionID: connID, databaseName: database.name)
            } label: {
                Label("Query Store", systemImage: "chart.bar.xaxis")
            }
            .disabled(!database.isOnline)

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
                viewModel.maintenanceDatabaseName = database.name
                viewModel.maintenanceConnectionID = connID
                viewModel.showMaintenanceSheet = true
            } label: {
                Label("Maintenance Plan", systemImage: "wrench.and.screwdriver")
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

            Menu {
                if database.isOnline {
                    Button("Back Up") {
                        viewModel.backupDatabaseName = database.name
                        viewModel.backupConnectionID = connID
                        viewModel.showBackupSheet = true
                    }

                    Button("Restore") {
                        viewModel.restoreDatabaseName = database.name
                        viewModel.restoreConnectionID = connID
                        viewModel.showRestoreSheet = true
                    }

                    Divider()

                    Button("Shrink Database") {
                        Task { await runMSSQLTask(session: session, database: database.name, task: .shrink) }
                    }

                    Divider()

                    Button("Take Offline") {
                        Task { await runMSSQLTask(session: session, database: database.name, task: .takeOffline) }
                    }
                } else {
                    Button("Bring Online") {
                        Task { await runMSSQLTask(session: session, database: database.name, task: .bringOnline) }
                    }

                    Button("Restore") {
                        viewModel.restoreDatabaseName = database.name
                        viewModel.restoreConnectionID = connID
                        viewModel.showRestoreSheet = true
                    }
                }
            } label: {
                Label("Tasks", systemImage: "gearshape")
            }

            Divider()
        }

        // Drop / Delete
        if session.connection.databaseType == .postgresql {
            Menu {
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
            } label: {
                Label("Drop Database", systemImage: "trash")
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

        Button {
            viewModel.propertiesDatabaseName = database.name
            viewModel.propertiesConnectionID = connID
            viewModel.showDatabaseProperties = true
        } label: {
            Label("Properties", systemImage: "info.circle")
        }
    }
}
