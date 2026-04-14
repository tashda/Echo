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
    @ObservationIgnored let spoolManager: ResultSpooler

    /// The database currently focused in the Object Browser sidebar tree.
    /// This is NOT the active tab's database — tabs carry their own `activeDatabaseName`.
    /// Only set by sidebar interactions (expanding a database, explicit selection).
    var sidebarFocusedDatabase: String?
    var databaseStructure: DatabaseStructure?
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

    @ObservationIgnored var defaultInitialBatchSize: Int
    @ObservationIgnored var defaultBackgroundStreamingThreshold: Int
    @ObservationIgnored var defaultBackgroundFetchSize: Int
    @ObservationIgnored var schemaLoadsInFlight: Set<String> = []
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
