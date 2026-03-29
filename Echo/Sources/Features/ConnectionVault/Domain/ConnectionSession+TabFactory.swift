import Foundation
import SwiftUI
import SQLServerKit

// MARK: - Tab Factory Methods

extension ConnectionSession {

    @discardableResult
    func addQueryTab(
        withQuery query: String = "",
        database: String? = nil,
        session querySession: DatabaseSession? = nil,
        ownsSession: Bool = false
    ) -> WorkspaceTab {
        let previewLimit = max(defaultBackgroundStreamingThreshold, defaultInitialBatchSize)
        let queryState = QueryEditorState(
            sql: query.isEmpty ? "SELECT current_timestamp;" : query,
            initialVisibleRowBatch: defaultInitialBatchSize,
            previewRowLimit: previewLimit,
            spoolManager: spoolManager,
            backgroundFetchSize: defaultBackgroundFetchSize
        )

        func normalized(_ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        let serverName = normalized(connection.connectionName) ?? normalized(connection.host)

        let databaseName: String?

        if let value = database, let normalizedValue = normalized(value) {
            databaseName = normalizedValue
        } else if let selected = sidebarFocusedDatabase, let normalizedSelected = normalized(selected) {
            databaseName = normalizedSelected
        } else {
            databaseName = normalized(connection.database)
        }

        queryState.updateClipboardContext(
            serverName: serverName,
            databaseName: databaseName,
            connectionColorHex: connection.metadataColorHex
        )

        let tab = WorkspaceTab(
            connection: connection,
            session: querySession ?? session,
            connectionSessionID: id,
            title: "Query \(queryTabs.count + 1)",
            content: .query(queryState),
            activeDatabaseName: databaseName,
            ownsSession: ownsSession
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addJobQueueTab(selectJobID: String? = nil, activityEngine: ActivityEngine? = nil) -> WorkspaceTab {
        let viewModel = JobQueueViewModel(session: session, connection: connection, initialSelectedJobID: selectJobID)
        viewModel.activityEngine = activityEngine
        viewModel.connectionSessionID = id
        let connName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Jobs",
            content: .jobQueue(viewModel),
            activeDatabaseName: connName.isEmpty ? connection.host : connName
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addPSQLTab(
        session dedicatedSession: DatabaseSession,
        database: String? = nil,
        sessionFactory: @escaping @Sendable (String) async throws -> DatabaseSession
    ) -> WorkspaceTab {
        let targetDatabase = database ?? sidebarFocusedDatabase ?? connection.database
        let viewModel = PSQLTabViewModel(
            connection: connection,
            session: dedicatedSession,
            database: targetDatabase,
            sessionFactory: sessionFactory
        )
        let tab = WorkspaceTab(
            connection: connection,
            session: dedicatedSession,
            connectionSessionID: id,
            title: "Postgres Console (\(targetDatabase))",
            content: .psql(viewModel)
        )
        viewModel.onActiveDatabaseChanged = { [weak tab] databaseName in
            tab?.title = "Postgres Console (\(databaseName))"
        }
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addStructureTab(for object: SchemaObjectInfo, focus: TableStructureSection? = nil, databaseName: String? = nil) -> WorkspaceTab {
        let viewModel = TableStructureEditorViewModel(
            schemaName: object.schema,
            tableName: object.name,
            details: TableStructureDetails(), // Placeholder, reload() will fetch real data
            session: session,
            databaseType: connection.databaseType
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine
        viewModel.connectionSessionID = id
        if let focus {
            viewModel.focusSection(focus)
        }

        // Resolve a database-specific session if a database name is provided
        if let databaseName {
            Task { @MainActor [weak viewModel, session = self.session] in
                guard let viewModel else { return }
                do {
                    let dbSession = try await session.sessionForDatabase(databaseName)
                    viewModel.updateSession(dbSession)
                } catch {
                    // Fall back to the primary session — better than showing nothing
                }
            }
        }

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: object.name,
            content: .structure(viewModel),
            activeDatabaseName: databaseName ?? (connection.database.isEmpty ? nil : connection.database)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addExtensionStructureTab(extensionName: String, databaseName: String) -> WorkspaceTab {
        let viewModel = PostgresExtensionStructureViewModel(
            extensionName: extensionName,
            databaseName: databaseName,
            session: self
        )

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "\(extensionName) (Extension)",
            content: .extensionStructure(viewModel)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addExtensionsManagerTab(databaseName: String) -> WorkspaceTab {
        let viewModel = PostgresExtensionsViewModel(
            databaseName: databaseName,
            session: self
        )

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Extensions (\(databaseName))",
            content: .extensionsManager(viewModel)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addTableDataTab(schema: String, table: String, databaseName: String? = nil) -> WorkspaceTab {
        let viewModel = TableDataViewModel(
            schemaName: schema,
            tableName: table,
            databaseType: connection.databaseType,
            session: session
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine
        viewModel.connectionSessionID = id

        // Resolve a database-specific session if a database name is provided
        if let databaseName {
            Task { @MainActor [weak viewModel, session = self.session] in
                guard let viewModel else { return }
                do {
                    let dbSession = try await session.sessionForDatabase(databaseName)
                    viewModel.updateSession(dbSession)
                } catch {
                    // Fall back to the primary session
                }
            }
        }

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "\(table) (Data)",
            content: .tableData(viewModel),
            activeDatabaseName: databaseName ?? sidebarFocusedDatabase
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addDiagramTab(
        for object: SchemaObjectInfo,
        viewModel: SchemaDiagramViewModel,
        databaseName: String? = nil
    ) -> WorkspaceTab {
        if let existing = queryTabs.first(where: { tab in
            guard let diagram = tab.diagram,
                  let context = diagram.context else {
                return false
            }
            return context.object == object
        }) {
            activeQueryTabID = existing.id
            return existing
        }

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: viewModel.title,
            content: .diagram(viewModel),
            activeDatabaseName: databaseName
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addMSSQLMaintenanceTab(databaseName: String? = nil) -> WorkspaceTab {
        let effectiveDatabase = databaseName ?? sidebarFocusedDatabase ?? connection.database

        // Only one MSSQL maintenance tab per connection — reuse if present, switch database
        if let existing = queryTabs.first(where: { $0.mssqlMaintenance != nil }) {
            activeQueryTabID = existing.id
            if let vm = existing.mssqlMaintenance, vm.selectedDatabase != effectiveDatabase {
                existing.activeDatabaseName = effectiveDatabase.isEmpty ? nil : effectiveDatabase
                Task { await vm.selectDatabase(effectiveDatabase) }
            }
            return existing
        }

        let viewModel = MSSQLMaintenanceViewModel(
            session: session,
            connectionID: connection.id,
            connectionSessionID: id,
            initialDatabase: effectiveDatabase.isEmpty ? nil : effectiveDatabase,
            notificationEngine: AppDirector.shared.notificationEngine
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine
        viewModel.backupsVM?.activityEngine = AppDirector.shared.activityEngine
        viewModel.backupsVM?.connectionSessionID = id
        viewModel.backupsVM?.notificationEngine = AppDirector.shared.notificationEngine

        let dbName = databaseName ?? sidebarFocusedDatabase

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Maintenance",
            content: .mssqlMaintenance(viewModel),
            activeDatabaseName: (dbName?.isEmpty == false) ? dbName : nil
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addMaintenanceTab(databaseName: String? = nil) -> WorkspaceTab {
        let effectiveDatabase = databaseName ?? sidebarFocusedDatabase ?? connection.database

        // Only one maintenance tab per connection — reuse if present, switch database
        if let existing = queryTabs.first(where: { $0.maintenance != nil }) {
            activeQueryTabID = existing.id
            if let vm = existing.maintenance, vm.selectedDatabase != effectiveDatabase {
                vm.selectedDatabase = effectiveDatabase
                vm.pgBackupsVM?.databaseName = effectiveDatabase
                vm.pgBackupsVM?.restoreDatabaseName = effectiveDatabase
                existing.activeDatabaseName = effectiveDatabase.isEmpty ? nil : effectiveDatabase
            }
            return existing
        }

        let viewModel = MaintenanceViewModel(
            session: session,
            connectionID: connection.id,
            connectionSessionID: id,
            databaseType: connection.databaseType,
            initialDatabase: effectiveDatabase.isEmpty ? nil : effectiveDatabase
        )
        viewModel.activityEngine = AppDirector.shared.activityEngine

        if connection.databaseType == .postgresql {
            let dbName = effectiveDatabase.isEmpty ? (connection.database) : effectiveDatabase
            let authConfig = AppDirector.shared.identityRepository.resolveAuthenticationConfiguration(for: connection, overridePassword: nil)
            let pgVM = PostgresBackupRestoreViewModel(
                connection: connection,
                session: session,
                databaseName: dbName,
                password: authConfig?.password,
                resolvedUsername: authConfig?.username
            )
            pgVM.activityEngine = AppDirector.shared.activityEngine
            pgVM.connectionSessionID = id
            pgVM.notificationEngine = AppDirector.shared.notificationEngine
            viewModel.pgBackupsVM = pgVM
        }

        let dbName = databaseName ?? sidebarFocusedDatabase

        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Maintenance",
            content: .maintenance(viewModel),
            activeDatabaseName: (dbName?.isEmpty == false) ? dbName : nil
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }
}
