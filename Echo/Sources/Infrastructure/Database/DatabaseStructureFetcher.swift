import Foundation
import os
import SQLServerKit

// No need for extra imports since TDSTokens is now available through SQLServerKit

nonisolated private let structureLogger = os.Logger(subsystem: "dk.tippr.echo.database-structure", category: "Explorer")

/// Protocol for database structure fetching operations
protocol DatabaseStructureFetcher {
    func fetchStructure(
        for connection: SavedConnection,
        credentials: ConnectionCredentials,
        selectedDatabase: String?,
        reuseSession: DatabaseSession?,
        databaseFilter: String?,
        cachedStructure: DatabaseStructure?,
        progressHandler: @escaping (Progress) async -> Void,
        databaseHandler: @escaping (DatabaseInfo, String, String) async -> Void
    ) async throws -> DatabaseStructure
}

/// Progress tracking for structure fetching operations
public struct Progress {
    public let fraction: Double
    public let message: String?

    public init(fraction: Double, message: String? = nil) {
        self.fraction = fraction
        self.message = message
    }
}

/// Connection credentials for database authentication
public struct ConnectionCredentials {
    public let authentication: Any

    public init(authentication: Any) {
        self.authentication = authentication
    }
}

/// PostgreSQL implementation of DatabaseStructureFetcher
public struct PostgresStructureFetcher: DatabaseStructureFetcher {
    private let session: DatabaseSession

    init(session: DatabaseSession) {
        self.session = session
    }

    func fetchStructure(
        for connection: SavedConnection,
        credentials: ConnectionCredentials,
        selectedDatabase: String?,
        reuseSession: DatabaseSession?,
        databaseFilter: String?,
        cachedStructure: DatabaseStructure?,
        progressHandler: @escaping (Progress) async -> Void,
        databaseHandler: @escaping (DatabaseInfo, String, String) async -> Void
    ) async throws -> DatabaseStructure {

        await progressHandler(Progress(fraction: 0.0, message: "Starting PostgreSQL structure fetch"))

        let _ = selectedDatabase ?? connection.database ?? "postgres"

        await progressHandler(Progress(fraction: 0.1, message: "Listing databases"))
        let databases = try await session.listDatabases()

        await progressHandler(Progress(fraction: 0.2, message: "Loading schemas"))
        let schemas = try await session.listSchemas()

        var echoDatabases: [DatabaseInfo] = []

        for (index, dbName) in databases.enumerated() {
            // Apply database filter if provided
            if let filter = databaseFilter, !dbName.contains(filter) {
                continue
            }

            // Skip if we're only fetching a specific database
            if let selectedDb = selectedDatabase, dbName != selectedDb {
                continue
            }

            let progressFraction = 0.2 + (Double(index + 1) / Double(databases.count)) * 0.7
            await progressHandler(Progress(fraction: progressFraction, message: "Loading database: \(dbName)"))

            var schemaInfos: [SchemaInfo] = []

            // Load tables for each schema
            for schema in schemas {
                let objects = try await session.listTablesAndViews(schema: schema)

                let filteredObjects = objects.filter { obj in
                    // Skip system schemas if not requested
                    if schema.hasPrefix("pg_") || schema.hasPrefix("information_schema") {
                        return false
                    }
                    return obj.type == .table || obj.type == .view || obj.type == .materializedView ||
                           obj.type == .function || obj.type == .trigger || obj.type == .procedure
                }

                let schemaInfo = SchemaInfo(
                    name: schema,
                    objects: filteredObjects
                )
                schemaInfos.append(schemaInfo)
            }

            let databaseInfo = DatabaseInfo(
                name: dbName,
                schemas: schemaInfos,
                schemaCount: schemaInfos.count
            )

            echoDatabases.append(databaseInfo)

            // Call the database handler for incremental processing
            await databaseHandler(databaseInfo, dbName, "PostgreSQL")
        }

        await progressHandler(Progress(fraction: 1.0, message: "PostgreSQL structure fetch completed"))

        return DatabaseStructure(
            serverVersion: "PostgreSQL",
            databases: echoDatabases
        )
    }
}

/// Microsoft SQL Server implementation of DatabaseStructureFetcher
public struct MSSQLStructureFetcher: DatabaseStructureFetcher {
    private let session: DatabaseSession

    init(session: DatabaseSession) {
        self.session = session
    }

    func fetchStructure(
        for connection: SavedConnection,
        credentials: ConnectionCredentials,
        selectedDatabase: String?,
        reuseSession: DatabaseSession?,
        databaseFilter: String?,
        cachedStructure: DatabaseStructure?,
        progressHandler: @escaping (Progress) async -> Void,
        databaseHandler: @escaping (DatabaseInfo, String, String) async -> Void
    ) async throws -> DatabaseStructure {

        await progressHandler(Progress(fraction: 0.0, message: "Starting SQL Server structure fetch"))

        let _ = selectedDatabase ?? connection.database ?? "master"

        await progressHandler(Progress(fraction: 0.1, message: "Listing databases"))
        let databases = try await session.listDatabases()

        await progressHandler(Progress(fraction: 0.2, message: "Loading schemas"))
        let schemas = try await session.listSchemas()

        var echoDatabases: [DatabaseInfo] = []

        for (index, dbName) in databases.enumerated() {
            // Apply database filter if provided
            if let filter = databaseFilter, !dbName.contains(filter) {
                continue
            }

            // Skip if we're only fetching a specific database
            if let selectedDb = selectedDatabase, dbName != selectedDb {
                continue
            }

            let progressFraction = 0.2 + (Double(index + 1) / Double(databases.count)) * 0.7
            await progressHandler(Progress(fraction: progressFraction, message: "Loading database: \(dbName)"))

            var schemaInfos: [SchemaInfo] = []

            // Load tables for each schema
            for schema in schemas {
                let objects = try await session.listTablesAndViews(schema: schema)

                let filteredObjects = objects.filter { obj in
                    // Skip system schemas if not requested
                    if schema.hasPrefix("sys") || schema.hasPrefix("INFORMATION_SCHEMA") {
                        return false
                    }
                    return obj.type == .table || obj.type == .view || obj.type == .materializedView ||
                           obj.type == .function || obj.type == .trigger || obj.type == .procedure
                }

                let schemaInfo = SchemaInfo(
                    name: schema,
                    objects: filteredObjects
                )
                schemaInfos.append(schemaInfo)
            }

            let databaseInfo = DatabaseInfo(
                name: dbName,
                schemas: schemaInfos,
                schemaCount: schemaInfos.count
            )

            echoDatabases.append(databaseInfo)

            // Call the database handler for incremental processing
            await databaseHandler(databaseInfo, dbName, "Microsoft SQL Server")
        }

        await progressHandler(Progress(fraction: 1.0, message: "SQL Server structure fetch completed"))

        return DatabaseStructure(
            serverVersion: "Microsoft SQL Server",
            databases: echoDatabases
        )
    }
}
