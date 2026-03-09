import Foundation
import os
import PostgresKit
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

        let connectedDatabase = connection.database.isEmpty ? "postgres" : connection.database

        await progressHandler(Progress(fraction: 0.1, message: "Listing databases"))
        let databases: [String]
        if let selectedDb = selectedDatabase, !selectedDb.isEmpty {
            databases = [selectedDb]
        } else {
            do {
                databases = try await session.listDatabases()
            } catch {
                structureLogger.warning("PostgreSQL listDatabases failed; falling back to connected db: \(error)")
                databases = [connectedDatabase]
            }
        }

        var echoDatabases: [DatabaseInfo] = []

        for (index, dbName) in databases.enumerated() {
            if let filter = databaseFilter, !dbName.contains(filter) {
                continue
            }
            if let selectedDb = selectedDatabase, dbName != selectedDb {
                continue
            }

            let progressFraction = 0.1 + (Double(index + 1) / Double(databases.count)) * 0.8
            await progressHandler(Progress(fraction: progressFraction, message: "Loading database: \(dbName)"))

            // PostgreSQL requires a separate connection per database.
            // If the target database differs from the connected one, open a temporary connection.
            let needsTempConnection = dbName.caseInsensitiveCompare(connectedDatabase) != .orderedSame
            let targetSession: DatabaseSession
            var tempSession: DatabaseSession?

            if needsTempConnection {
                do {
                    guard let auth = credentials.authentication as? DatabaseAuthenticationConfiguration else {
                        structureLogger.warning("PostgreSQL: cannot create temp connection — missing auth config")
                        continue
                    }
                    let factory = PostgresNIOFactory()
                    let tmp = try await factory.connect(
                        host: connection.host,
                        port: connection.port,
                        database: dbName,
                        tls: connection.useTLS,
                        authentication: auth,
                        connectTimeoutSeconds: 10
                    )
                    tempSession = tmp
                    targetSession = tmp
                } catch {
                    structureLogger.warning("PostgreSQL: failed to connect to database '\(dbName)': \(error.localizedDescription)")
                    // Return an empty database entry so the user sees it in the sidebar
                    let emptyDb = DatabaseInfo(name: dbName, schemas: [], schemaCount: 0)
                    echoDatabases.append(emptyDb)
                    await databaseHandler(emptyDb, dbName, "PostgreSQL")
                    continue
                }
            } else {
                targetSession = session
            }

            defer {
                if let tmp = tempSession {
                    Task { await tmp.close() }
                }
            }

            // Fetch schemas and objects using the correct session
            let schemas: [String]
            do {
                schemas = try await targetSession.listSchemas()
            } catch {
                structureLogger.warning("PostgreSQL listSchemas failed for '\(dbName)': \(error)")
                schemas = ["public"]
            }

            var schemaInfos: [SchemaInfo] = []

            for schema in schemas {
                if schema.hasPrefix("pg_") || schema == "information_schema" {
                    continue
                }

                do {
                    let objects = try await targetSession.listTablesAndViews(schema: schema)
                    let filteredObjects = objects.filter { obj in
                        obj.type == .table || obj.type == .view || obj.type == .materializedView ||
                        obj.type == .function || obj.type == .trigger || obj.type == .procedure
                    }
                    if !filteredObjects.isEmpty {
                        schemaInfos.append(SchemaInfo(name: schema, objects: filteredObjects))
                    }
                } catch {
                    structureLogger.warning("PostgreSQL: failed to load schema '\(schema)' in '\(dbName)': \(error)")
                }
            }

            let databaseInfo = DatabaseInfo(
                name: dbName,
                schemas: schemaInfos,
                schemaCount: schemaInfos.count
            )

            echoDatabases.append(databaseInfo)
            await databaseHandler(databaseInfo, dbName, "PostgreSQL")
        }

        await progressHandler(Progress(fraction: 0.95, message: "Fetching server version"))

        var versionString = "PostgreSQL"
        if let pgSession = session as? PostgresSession {
            do {
                let admin = PostgresAdmin(client: pgSession.client, logger: pgSession.logger)
                if let rawVersion = try await admin.show("server_version") {
                    // Extract just the version number (e.g. "16.2" from "16.2 (Debian 16.2-1.pgdg120+2)")
                    let components = rawVersion.split(separator: " ", maxSplits: 1)
                    versionString = "PostgreSQL \(components.first ?? Substring(rawVersion))"
                }
            } catch {
                structureLogger.warning("PostgreSQL: failed to fetch server version: \(error)")
            }
        }

        await progressHandler(Progress(fraction: 1.0, message: "PostgreSQL structure fetch completed"))

        return DatabaseStructure(
            serverVersion: versionString,
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

        let resolvedDatabase = selectedDatabase ?? connection.database

        if let sqlSession = session as? SQLServerSessionAdapter {
            await progressHandler(Progress(fraction: 0.2, message: "Loading SQL Server metadata"))
            let databaseInfo = try await sqlSession.loadDatabaseInfo(databaseName: resolvedDatabase)
            await databaseHandler(databaseInfo, resolvedDatabase, "Microsoft SQL Server")

            // Fetch actual server version
            var versionString = "SQL Server"
            do {
                let version = try await sqlSession.serverVersion()
                versionString = "SQL Server \(version)"
            } catch {
                structureLogger.warning("SQL Server: failed to fetch server version: \(error)")
            }

            await progressHandler(Progress(fraction: 1.0, message: "SQL Server structure fetch completed"))
            return DatabaseStructure(
                serverVersion: versionString,
                databases: [databaseInfo]
            )
        }

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
                if let metadataSession = session as? DatabaseMetadataSession {
                    do {
                        let schemaInfo = try await metadataSession.loadSchemaInfo(schema, progress: nil)
                        schemaInfos.append(schemaInfo)
                    } catch {
                        structureLogger.warning("SQL Server schema load failed for \(schema): \(error)")
                    }
                    continue
                }

                let objects: [SchemaObjectInfo]
                do {
                    objects = try await session.listTablesAndViews(schema: schema)
                } catch {
                    structureLogger.warning("SQL Server listTablesAndViews failed for \(schema): \(error)")
                    continue
                }

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
