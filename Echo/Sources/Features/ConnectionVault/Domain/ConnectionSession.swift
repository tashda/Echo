import Foundation
import SwiftUI
import Combine

// MARK: - Connection Session Management

enum StructureLoadingState: Equatable {
    case idle
    case loading(progress: Double?)
    case ready
    case failed(message: String?)
}

/// Represents an active connection session to a database server
@MainActor
final class ConnectionSession: ObservableObject, Identifiable {
    let id: UUID
    let connection: SavedConnection
    let session: DatabaseSession
    private let spoolManager: ResultSpoolCoordinator

    @Published var selectedDatabaseName: String?
    @Published var databaseStructure: DatabaseStructure?
    @Published var connectionState: ConnectionState = .connected
    @Published var lastActivity: Date = Date()
    @Published var structureLoadingState: StructureLoadingState = .idle
    @Published var structureLoadingMessage: String?
    private var defaultInitialBatchSize: Int
    private var defaultBackgroundStreamingThreshold: Int
    private var defaultBackgroundFetchSize: Int

    // Query tabs specific to this connection
    @Published var queryTabs: [WorkspaceTab] = []
    @Published var activeQueryTabID: UUID?
    var structureLoadTask: Task<Void, Never>?

    init(
        id: UUID = UUID(),
        connection: SavedConnection,
        session: DatabaseSession,
        defaultInitialBatchSize: Int = 500,
        defaultBackgroundStreamingThreshold: Int = 512,
        defaultBackgroundFetchSize: Int = 4_096,
        spoolManager: ResultSpoolCoordinator
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
        let db = (selectedDatabaseName ?? connection.database).trimmingCharacters(in: .whitespacesAndNewlines)
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
    func addQueryTab(withQuery query: String = "", database: String? = nil) -> WorkspaceTab {
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
            session: session,
            connectionSessionID: id,
            title: "Query \(queryTabs.count + 1)",
            content: .query(queryState),
            activeDatabaseName: databaseName
        )
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        lastActivity = Date()
        return tab
    }

    @discardableResult
    func addJobQueueTab(selectJobID: String? = nil) -> WorkspaceTab {
        let viewModel = JobQueueViewModel(session: session, connection: connection, initialSelectedJobID: selectJobID)
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Jobs",
            content: .jobQueue(viewModel)
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
        if let focus {
            viewModel.focusSection(focus)
        }

        // For PostgreSQL, resolve a database-specific session if needed
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
        let viewModel = PostgresExtensionsManagerViewModel(
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
    func addActivityMonitorTab() throws -> WorkspaceTab {
        let monitor = try session.makeActivityMonitor()
        let viewModel = ActivityMonitorViewModel(monitor: monitor, connectionSessionID: self.id)
        
        let tab = WorkspaceTab(
            connection: connection,
            session: session,
            connectionSessionID: id,
            title: "Activity Monitor",
            content: .activityMonitor(viewModel)
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
}

// MARK: - Multi-Connection Manager

/// Manages multiple active database connections and provides server switching functionality
@MainActor
final class ActiveSessionCoordinator: ObservableObject {
    @Published var activeSessions: [ConnectionSession] = []
    @Published var activeSessionID: UUID?
    @Published var isServerSwitcherVisible = false

    // MARK: - Computed Properties

    var activeConnectionID: UUID? {
        activeSession?.connection.id
    }

    var activeDatabaseName: String? {
        activeSession?.selectedDatabaseName
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
