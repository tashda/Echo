import Foundation
import SwiftUI
import Observation
import SQLServerKit

// MARK: - Connection Session Management

enum StructureLoadingState: Equatable {
    case idle
    case loading(progress: Double?)
    case ready
    case failed(message: String?)
}

/// Represents an active connection session to a database server
@Observable @MainActor
final class ConnectionSession: Identifiable {
    let id: UUID
    @ObservationIgnored let connection: SavedConnection
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored private let spoolManager: ResultSpooler

    var selectedDatabaseName: String?
    var databaseStructure: DatabaseStructure?
    var connectionState: ConnectionState = .connected
    var lastActivity: Date = Date()
    var structureLoadingState: StructureLoadingState = .idle
    var structureLoadingMessage: String?
    @ObservationIgnored private var defaultInitialBatchSize: Int
    @ObservationIgnored private var defaultBackgroundStreamingThreshold: Int
    @ObservationIgnored private var defaultBackgroundFetchSize: Int
    @ObservationIgnored private var schemaLoadsInFlight: Set<String> = []

    // Query tabs specific to this connection
    var queryTabs: [WorkspaceTab] = []
    var activeQueryTabID: UUID?
    @ObservationIgnored var structureLoadTask: Task<Void, Never>?

    init(
        id: UUID = UUID(),
        connection: SavedConnection,
        session: DatabaseSession,
        defaultInitialBatchSize: Int = 500,
        defaultBackgroundStreamingThreshold: Int = 512,
        defaultBackgroundFetchSize: Int = 4_096,
        spoolManager: ResultSpooler
    ) {
        self.id = id
        self.connection = connection
        self.session = session
        self.defaultInitialBatchSize = max(100, defaultInitialBatchSize)
        self.defaultBackgroundStreamingThreshold = max(100, defaultBackgroundStreamingThreshold)
        self.defaultBackgroundFetchSize = max(128, min(defaultBackgroundFetchSize, 16_384))
        self.spoolManager = spoolManager

        self.selectedDatabaseName = nil
    }

    var activeQueryTab: WorkspaceTab? {
        guard let activeID = activeQueryTabID else { return nil }
        return queryTabs.first { $0.id == activeID }
    }

    var displayName: String {
        let db = (activeDatabaseName ?? connection.database).trimmingCharacters(in: .whitespacesAndNewlines)
        if !db.isEmpty {
            return "\(connection.connectionName) • \(db)"
        } else {
            return connection.connectionName
        }
    }

    var shortDisplayName: String {
        return connection.connectionName
    }

    var isConnected: Bool {
        return connectionState.isConnected
    }

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
        } else if let selected = selectedDatabaseName, let normalizedSelected = normalized(selected) {
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
        let targetDatabase = database ?? selectedDatabaseName ?? connection.database
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
            title: "\(object.name) (Structure)",
            content: .structure(viewModel)
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
    func addMSSQLMaintenanceTab(databaseName: String? = nil) -> WorkspaceTab {
        let effectiveDatabase = databaseName ?? selectedDatabaseName ?? connection.database

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

        let dbName = databaseName ?? selectedDatabaseName

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
        let effectiveDatabase = databaseName ?? selectedDatabaseName ?? connection.database

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

        let dbName = databaseName ?? selectedDatabaseName

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

    @discardableResult
    func addActivityMonitorTab() throws -> WorkspaceTab {
        // Reuse existing activity monitor tab if present
        if let existing = queryTabs.first(where: { $0.activityMonitor != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let monitor = try session.makeActivityMonitor()
        let interval = AppDirector.shared.projectStore.globalSettings.activityMonitorRefreshInterval
        let viewModel = ActivityMonitorViewModel(
            monitor: monitor,
            connectionSessionID: self.id,
            connectionID: connection.id,
            databaseType: connection.databaseType,
            refreshInterval: interval
        )

        if let mssql = session as? MSSQLSession {
            viewModel.extendedEventsVM = ExtendedEventsViewModel(
                xeClient: mssql.extendedEvents,
                connectionSessionID: id
            )
        }

        let connName = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Activity Monitor",
            content: .activityMonitor(viewModel),
            activeDatabaseName: connName.isEmpty ? connection.host : connName
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addQueryStoreTab(databaseName: String) -> WorkspaceTab? {
        guard let mssql = session as? MSSQLSession else { return nil }

        // Reuse existing query store tab for THIS specific database if present
        if let existing = queryTabs.first(where: { tab in
            guard let vm = tab.queryStoreVM else { return false }
            return vm.databaseName == databaseName
        }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = QueryStoreViewModel(
            queryStoreClient: mssql.queryStore,
            databaseName: databaseName,
            connectionSessionID: id
        )
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Query Store (\(databaseName))",
            content: .queryStore(viewModel)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addExtendedEventsTab() -> WorkspaceTab? {
        guard let mssql = session as? MSSQLSession else { return nil }

        // Reuse existing extended events tab if present
        if let existing = queryTabs.first(where: { $0.extendedEventsVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = ExtendedEventsViewModel(
            xeClient: mssql.extendedEvents,
            connectionSessionID: id
        )
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Extended Events",
            content: .extendedEvents(viewModel)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addAvailabilityGroupsTab() -> WorkspaceTab? {
        guard let mssql = session as? MSSQLSession else { return nil }

        // Reuse existing availability groups tab if present
        if let existing = queryTabs.first(where: { $0.availabilityGroupsVM != nil }) {
            activeQueryTabID = existing.id
            return existing
        }

        let viewModel = AvailabilityGroupsViewModel(
            agClient: mssql.availabilityGroups,
            connectionSessionID: id
        )
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Availability Groups",
            content: .availabilityGroups(viewModel)
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    func closeQueryTab(withID tabID: UUID) {
        guard let index = queryTabs.firstIndex(where: { $0.id == tabID }) else { return }
        let tab = queryTabs[index]

        // Proactively cancel any executing query task for this tab before removal
        if let state = tab.query {
            state.cancelExecution()
        }

        // Stop activity monitor streaming if this is an activity monitor tab
        if let activityVM = tab.activityMonitor {
            activityVM.stopStreaming()
        }

        if tab.ownsSession {
            Task {
                await tab.session.close()
            }
        }

        queryTabs.remove(at: index)

        // Adjust active tab
        if activeQueryTabID == tabID {
            if !queryTabs.isEmpty {
                // Select the previous tab, or the first one if we removed the first
                let newIndex = max(0, index - 1)
                activeQueryTabID = queryTabs.indices.contains(newIndex) ? queryTabs[newIndex].id : queryTabs.first?.id
            } else {
                activeQueryTabID = nil
            }
        }
        lastActivity = Date()
    }

    func updateActivity() {
        lastActivity = Date()
    }

    func updateDefaultInitialBatchSize(_ batchSize: Int) {
        defaultInitialBatchSize = max(100, batchSize)
    }

    func updateDefaultBackgroundStreamingThreshold(_ threshold: Int) {
        defaultBackgroundStreamingThreshold = max(100, threshold)
    }

    func updateDefaultBackgroundFetchSize(_ fetchSize: Int) {
        defaultBackgroundFetchSize = max(128, min(fetchSize, 16_384))
    }

    func cancelStructureLoadTask() async {
        let task = structureLoadTask
        structureLoadTask = nil
        task?.cancel()
        if let task {
            await task.value
        }
    }

    func hasLoadedSchema(forDatabase databaseName: String) -> Bool {
        let normalizedName = normalizedDatabaseName(databaseName)
        guard !normalizedName.isEmpty else { return false }
        return databaseStructure?.databases
            .first(where: { normalizedDatabaseName($0.name).caseInsensitiveCompare(normalizedName) == .orderedSame })?
            .schemas.isEmpty == false
    }

    func beginSchemaLoad(forDatabase databaseName: String) -> Bool {
        let loadKey = schemaLoadKey(databaseName)
        guard !loadKey.isEmpty else { return false }
        if schemaLoadsInFlight.contains(loadKey) {
            return false
        }
        schemaLoadsInFlight.insert(loadKey)
        return true
    }

    func finishSchemaLoad(forDatabase databaseName: String) {
        let loadKey = schemaLoadKey(databaseName)
        guard !loadKey.isEmpty else { return }
        schemaLoadsInFlight.remove(loadKey)
    }

    var activeDatabaseName: String? {
        let tabDatabase = activeQueryTab?.activeDatabaseName.map(normalizedDatabaseName)
        if let tabDatabase, !tabDatabase.isEmpty {
            return tabDatabase
        }

        let selectedDatabase = selectedDatabaseName.map(normalizedDatabaseName)
        if let selectedDatabase, !selectedDatabase.isEmpty {
            return selectedDatabase
        }

        let connectionDatabase = normalizedDatabaseName(connection.database)
        return connectionDatabase.isEmpty ? nil : connectionDatabase
    }

    private func normalizedDatabaseName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func schemaLoadKey(_ value: String) -> String {
        normalizedDatabaseName(value).lowercased()
    }
}

// MARK: - Multi-Connection Manager

/// Manages multiple active database connections and provides server switching functionality
@Observable @MainActor
final class ActiveSessionGroup {
    var activeSessions: [ConnectionSession] = []
    var activeSessionID: UUID?
    var isServerSwitcherVisible = false

    // MARK: - Computed Properties

    var activeConnectionID: UUID? {
        activeSession?.connection.id
    }

    var activeDatabaseName: String? {
        activeSession?.activeDatabaseName
    }

    var activeSession: ConnectionSession? {
        guard let activeID = activeSessionID else { return nil }
        return activeSessions.first { $0.id == activeID }
    }

    var sessions: [ConnectionSession] {
        return activeSessions
    }

    var sortedSessions: [ConnectionSession] {
        return activeSessions.sorted { $0.lastActivity > $1.lastActivity }
    }

    // MARK: - Session Management

    func addSession(_ session: ConnectionSession) {
        // Remove any existing session for the same connection
        if let existing = activeSessions.first(where: { $0.connection.id == session.connection.id }) {
            let sessionID = existing.id
            Task {
                for tab in existing.queryTabs where tab.ownsSession {
                    await tab.session.close()
                }
                await existing.session.close()
            }
            activeSessions.removeAll { $0.id == sessionID }
        }

        // Add the new session
        activeSessions.append(session)
        activeSessionID = session.id
        session.updateActivity()
    }

    func removeSession(withID sessionID: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == sessionID }) else { return }

        // Cancel any in-flight queries belonging to this session before removing it
        let session = activeSessions[index]
        for tab in session.queryTabs {
            if let state = tab.query {
                state.cancelExecution()
            }
        }

        // Close the database session properly to avoid driver crashes on deinit
        Task {
            for tab in session.queryTabs where tab.ownsSession {
                await tab.session.close()
            }
            await session.session.close()
        }

        activeSessions.remove(at: index)

        // Adjust active session
        if activeSessionID == sessionID {
            activeSessionID = activeSessions.first?.id
        }
    }

    func setActiveSession(_ sessionID: UUID) {
        guard activeSessions.contains(where: { $0.id == sessionID }) else { return }
        activeSessionID = sessionID

        // Update activity for the newly active session
        if let session = activeSession {
            session.updateActivity()
        }
    }

    func sessionForConnection(_ connectionID: UUID) -> ConnectionSession? {
        return activeSessions.first { $0.connection.id == connectionID }
    }

    // MARK: - Server Switching (Cmd+Tab style)

    func showServerSwitcher() {
        guard activeSessions.count > 1 else { return }
        isServerSwitcherVisible = true
    }

    func hideServerSwitcher() {
        isServerSwitcherVisible = false
    }

    func switchToNextServer() {
        guard activeSessions.count > 1 else { return }

        let sorted = sortedSessions
        guard let currentIndex = sorted.firstIndex(where: { $0.id == activeSessionID }) else {
            activeSessionID = sorted.first?.id
            return
        }

        let nextIndex = (currentIndex + 1) % sorted.count
        activeSessionID = sorted[nextIndex].id
        sorted[nextIndex].updateActivity()
    }

    func switchToPreviousServer() {
        guard activeSessions.count > 1 else { return }

        let sorted = sortedSessions
        guard let currentIndex = sorted.firstIndex(where: { $0.id == activeSessionID }) else {
            activeSessionID = sorted.first?.id
            return
        }

        let previousIndex = currentIndex == 0 ? sorted.count - 1 : currentIndex - 1
        activeSessionID = sorted[previousIndex].id
        sorted[previousIndex].updateActivity()
    }

    // MARK: - Query Tab Management

    func addQueryTab(toSessionID sessionID: UUID, withQuery query: String = "", database: String? = nil) {
        guard let session = activeSessions.first(where: { $0.id == sessionID }) else { return }
        session.addQueryTab(withQuery: query, database: database)
    }

    func addQueryTabToActiveSession(withQuery query: String = "", database: String? = nil) {
        guard let session = activeSession else { return }
        session.addQueryTab(withQuery: query, database: database)
    }

    func closeQueryTab(withID tabID: UUID, fromSessionID sessionID: UUID) {
        guard let session = activeSessions.first(where: { $0.id == sessionID }) else { return }
        session.closeQueryTab(withID: tabID)
    }
}

// MARK: - Server Switcher Data

@MainActor
struct ServerSwitcherItem: Identifiable {
    let id: UUID
    let session: ConnectionSession
    let isActive: Bool

    var displayName: String { session.displayName }
    var shortName: String { session.shortDisplayName }
    var queryTabCount: Int { session.queryTabs.count }
    var connectionColor: Color { session.connection.color }
    var lastActivity: Date { session.lastActivity }
}

extension ConnectionSession: DiagramSchemaProvider {
    nonisolated var connectionID: UUID {
        connection.id
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        try await session.getTableStructureDetails(schema: schema, table: table)
    }
}
