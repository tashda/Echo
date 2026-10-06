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

/// One database's info as its own object: a view reads it and is told when that database
/// changed, not for every other database's schemas (`ConnectionSession.databaseInfo(named:)`).
@Observable @MainActor
final class DatabaseSlot {
    var info: DatabaseInfo?

    init(info: DatabaseInfo?) {
        self.info = info
    }
}

/// Whether one database's schema is loading (`ConnectionSession.schemaLoadFlag(forDatabase:)`).
@Observable @MainActor
final class SchemaLoadFlag {
    var isLoading: Bool

    init(isLoading: Bool = false) {
        self.isLoading = isLoading
    }
}

/// Represents an active connection session to a database server
@Observable @MainActor
final class ConnectionSession: Identifiable {
    let id: UUID
    @ObservationIgnored var cacheFingerprint: String?
    @ObservationIgnored let connection: SavedConnection
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored let spoolManager: ResultSpooler

    /// The database currently focused in the Object Browser sidebar tree.
    /// This is NOT the active tab's database — tabs carry their own `activeDatabaseName`.
    /// Only set by sidebar interactions (expanding a database, explicit selection).
    var sidebarFocusedDatabase: String?
    var databaseStructure: DatabaseStructure? {
        didSet { refreshDatabaseSlices() }
    }
    /// The same structure, read without telling the view that reads it (`databaseInfo(named:)`).
    @ObservationIgnored private(set) var structureSnapshot: DatabaseStructure?
    @ObservationIgnored var databaseSlots: [String: DatabaseSlot] = [:]
    /// The server's databases without their schemas. Every schema that loads in the background
    /// replaces `databaseStructure`; readers that only list or pick databases read this, which
    /// changes only when the list, a state or an access flag does.
    private(set) var databaseSummaries: [DatabaseSummary] = []
    /// Whether any structure has arrived, for readers that do not need its contents.
    private(set) var hasDatabaseStructure = false
    /// The server version its structure reports (a structure update with the same version is no
    /// change to a reader of this).
    private(set) var reportedServerVersion: String?
    var connectionState: ConnectionState = .connected
    var lastActivity: Date = Date()
    var structureLoadingState: StructureLoadingState = .idle
    var structureLoadingMessage: String?

    /// Cached permissions for the current user. Fetched at connection time, refreshed on toolbar refresh.
    /// Views use fail-open: `permissions?.canDoX ?? true` — if nil, controls stay enabled.
    var permissions: (any DatabasePermissionProviding)?

    /// Pre-warmed dedicated session for the next MSSQL query tab.
    /// Created in the background after the initial connection so the first
    /// tab gets a ready connection instantly without waiting for TCP+TLS+login.
    @ObservationIgnored var preWarmedDedicatedSession: DatabaseSession?
    @ObservationIgnored var preWarmTask: Task<Void, Never>?
    @ObservationIgnored var healthCheckTask: Task<Void, Never>?
    /// Where a PostgreSQL connection with several servers moved after a failover (round 23, FS1).
    var serverMove: ConnectionServerMove?
    @ObservationIgnored var serverWatchTask: Task<Void, Never>?

    @ObservationIgnored var defaultInitialBatchSize: Int
    @ObservationIgnored var defaultBackgroundStreamingThreshold: Int
    @ObservationIgnored var defaultBackgroundFetchSize: Int
    @ObservationIgnored var schemaLoadsInFlight: Set<String> = []
    @ObservationIgnored var schemaLoadFlags: [String: SchemaLoadFlag] = [:]
    @ObservationIgnored var metadataFreshnessByDatabase: [String: DatabaseMetadataFreshness] = [:]

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

        self.sidebarFocusedDatabase = nil
    }

    /// Brings the slices up to date after `databaseStructure` changed; a slice that came out the same
    /// is not assigned, so its readers are not told.
    private func refreshDatabaseSlices() {
        let structure = databaseStructure
        structureSnapshot = structure
        // A database that has a reader is told only when its own info changed.
        if !databaseSlots.isEmpty {
            let current = Dictionary((structure?.databases ?? []).map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
            for (name, slot) in databaseSlots where slot.info != current[name] { slot.info = current[name] }
        }
        let summaries = structure?.databases.map(DatabaseSummary.init) ?? []
        if summaries != databaseSummaries { databaseSummaries = summaries }
        let has = structure != nil
        if has != hasDatabaseStructure { hasDatabaseStructure = has }
        let version = structure?.serverVersion
        if version != reportedServerVersion { reportedServerVersion = version }
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

    /// Fetches the current user's permissions from the server and caches them.
    /// Called at connection time and on toolbar refresh.
    func refreshPermissions() async {
        permissions = try? await session.fetchPermissions()
    }

    /// Starts a background task that periodically checks if the connection is alive.
    /// Runs every 5 minutes for idle connections. On failure, sets state to `.disconnected`.
    func startHealthCheck() {
        healthCheckTask?.cancel()
        healthCheckTask = Task(name: "health-check-\(connection.connectionName)") { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                guard self.connectionState.isConnected else { break }

                let alive = await self.session.connectionIsAlive()
                if !alive && self.connectionState.isConnected {
                    self.connectionState = .disconnected
                }
            }
        }
    }

    /// Stops the health check background task.
    func stopHealthCheck() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
        serverWatchTask?.cancel()
        serverWatchTask = nil
    }
}

// MARK: - DiagramSchemaProvider Conformance

extension ConnectionSession: DiagramSchemaProvider {
    nonisolated var connectionID: UUID {
        connection.id
    }

    func getTableStructureDetails(schema: String, table: String, database: String?) async throws -> TableStructureDetails {
        // For MSSQL, the adapter's `database` property may differ from the database
        // the user is currently browsing. Pass the explicit database name through
        // to the adapter so it queries the correct database.
        if let db = database {
            if let mssqlAdapter = session as? SQLServerSessionAdapter {
                return try await mssqlAdapter.getTableStructureDetails(schema: schema, table: table, database: db)
            }
            if let dedicated = session as? MSSQLDedicatedQuerySession {
                return try await dedicated.metadataSession.getTableStructureDetails(schema: schema, table: table, database: db)
            }
        }
        return try await session.getTableStructureDetails(schema: schema, table: table)
    }
}
