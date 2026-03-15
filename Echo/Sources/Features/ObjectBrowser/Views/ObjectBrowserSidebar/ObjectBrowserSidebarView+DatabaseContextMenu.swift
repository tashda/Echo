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
            environmentState.openQueryTab(for: session)
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

        // PostgreSQL-specific operations
        if session.connection.databaseType == .postgresql {
            Menu {
                Button("VACUUM") {
                    Task { await runPostgresMaintenance(session: session, database: database.name, operation: .vacuum) }
                }
                Button("VACUUM (Full)") {
                    Task { await runPostgresMaintenance(session: session, database: database.name, operation: .vacuumFull) }
                }
                Button("VACUUM (Analyze)") {
                    Task { await runPostgresMaintenance(session: session, database: database.name, operation: .vacuumAnalyze) }
                }
                Button("ANALYZE") {
                    Task { await runPostgresMaintenance(session: session, database: database.name, operation: .analyze) }
                }
                Button("REINDEX") {
                    Task { await runPostgresMaintenance(session: session, database: database.name, operation: .reindex) }
                }
            } label: {
                Label("Maintenance", systemImage: "wrench.and.screwdriver")
            }

            Divider()
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
                environmentState.openExtendedEventsTab(connectionID: connID)
            } label: {
                Label("Extended Events", systemImage: "waveform.path.ecg")
            }

            Menu {
                if database.isOnline {
                    Button("Back Up\u{2026}") {
                        viewModel.backupDatabaseName = database.name
                        viewModel.backupConnectionID = connID
                        viewModel.showBackupSheet = true
                    }

                    Button("Restore\u{2026}") {
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

                    Button("Restore\u{2026}") {
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
            Button(role: .destructive) {
                viewModel.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .standard)
                viewModel.showDropDatabaseAlert = true
            } label: {
                Label("Drop Database", systemImage: "trash")
            }
            Button(role: .destructive) {
                viewModel.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .cascade)
                viewModel.showDropDatabaseAlert = true
            } label: {
                Label("Drop Database (Cascade)", systemImage: "trash")
            }
            Button(role: .destructive) {
                viewModel.dropDatabaseTarget = .init(sessionID: session.id, connectionID: connID, databaseName: database.name, databaseType: .postgresql, variant: .force)
                viewModel.showDropDatabaseAlert = true
            } label: {
                Label("Drop Database (Force)", systemImage: "trash")
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
            Label("Properties\u{2026}", systemImage: "info.circle")
        }
    }
}
