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

        // Determine the actual connected database name by querying the server.
        // Falling back to the connection config or "postgres" only if the query fails.
        let connectedDatabase: String
        if !connection.database.isEmpty {
            connectedDatabase = connection.database
        } else {
            do {
                let result = try await session.simpleQuery("SELECT current_database()")
                if let row = result.rows.first, let value = row.first, let dbName = value, !dbName.isEmpty {
                    connectedDatabase = dbName
                } else {
                    connectedDatabase = "postgres"
                }
            } catch {
                structureLogger.warning("PostgreSQL: could not determine current database, assuming 'postgres': \(error)")
                connectedDatabase = "postgres"
            }
        }

        // Determine which single database to load structure for.
        // Only load the selected or connected database — remaining databases
        // are added as empty entries by the coordinator (matching MSSQL behavior).
        let targetDatabase = (selectedDatabase?.isEmpty == false ? selectedDatabase : nil) ?? connectedDatabase

        await progressHandler(Progress(fraction: 0.2, message: "Loading database: \(targetDatabase)"))

        var echoDatabases: [DatabaseInfo] = []

        // PostgreSQL requires a separate connection per database.
        // `sessionForDatabase` uses PostgresServerConnection to vend a cached client.
        let targetSession: DatabaseSession
        do {
            targetSession = try await session.sessionForDatabase(targetDatabase)
        } catch {
            structureLogger.warning("PostgreSQL: failed to connect to database '\(targetDatabase)': \(error.localizedDescription)")
            let emptyDb = DatabaseInfo(name: targetDatabase, schemas: [], schemaCount: 0)
            echoDatabases.append(emptyDb)
            await databaseHandler(emptyDb, targetDatabase, "PostgreSQL")
            return DatabaseStructure(serverVersion: "PostgreSQL", databases: echoDatabases)
        }

        // Fetch schemas and objects for the single target database
        let schemas: [String]
        do {
            schemas = try await targetSession.listSchemas()
        } catch {
            structureLogger.warning("PostgreSQL listSchemas failed for '\(targetDatabase)': \(error)")
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
                structureLogger.warning("PostgreSQL: failed to load schema '\(schema)' in '\(targetDatabase)': \(error)")
            }
        }

        // Fetch extensions
        var extensions: [SchemaObjectInfo] = []
        do {
            extensions = try await targetSession.listExtensions()
        } catch {
            structureLogger.warning("PostgreSQL: failed to load extensions in '\(targetDatabase)': \(error)")
        }

        let databaseInfo = DatabaseInfo(
            name: targetDatabase,
            schemas: schemaInfos,
            extensions: extensions,
            schemaCount: schemaInfos.count
        )

        echoDatabases.append(databaseInfo)
        await databaseHandler(databaseInfo, targetDatabase, "PostgreSQL")

        await progressHandler(Progress(fraction: 0.95, message: "Fetching server version"))

        var versionString = "PostgreSQL"
        if let pgSession = session as? PostgresSession {
            do {
                if let rawVersion = try await pgSession.client.admin.show("server_version") {
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

        if let sqlSession = session as? SQLServerSessionAdapter {
            // When a specific database is selected, load its full schema (lazy expand).
            // Otherwise, lightweight initial load: only database list + server version.
            if let selectedDatabase, !selectedDatabase.isEmpty {
                await progressHandler(Progress(fraction: 0.2, message: "Loading \(selectedDatabase)"))

                var databases: [DatabaseInfo] = []
                do {
                    let databaseInfo = try await sqlSession.loadDatabaseInfo(databaseName: selectedDatabase)
                    databases.append(databaseInfo)
                    await databaseHandler(databaseInfo, selectedDatabase, "Microsoft SQL Server")
                } catch {
                    structureLogger.warning("SQL Server: failed to load database '\(selectedDatabase)': \(error.localizedDescription)")
                    let fallback = DatabaseInfo(name: selectedDatabase, schemas: [], schemaCount: 0)
                    databases.append(fallback)
                    await databaseHandler(fallback, selectedDatabase, "Microsoft SQL Server")
                }

                await progressHandler(Progress(fraction: 1.0, message: "Done"))
                return DatabaseStructure(serverVersion: cachedStructure?.serverVersion, databases: databases)
            }

            await progressHandler(Progress(fraction: 0.2, message: "Loading SQL Server metadata"))

            var databases: [DatabaseInfo] = []
            do {
                let allDbs = try await sqlSession.listDatabasesWithState()
                databases = allDbs.map { DatabaseInfo(name: $0.name, schemas: [], schemaCount: 0, stateDescription: $0.stateDescription) }
                databases.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            } catch {
                structureLogger.warning("SQL Server: failed to list databases: \(error.localizedDescription)")
            }

            await progressHandler(Progress(fraction: 0.6, message: "Fetching server version"))

            var versionString = "SQL Server"
            do {
                let version = try await sqlSession.serverVersion()
                versionString = "SQL Server \(version)"
            } catch {
                structureLogger.warning("SQL Server: failed to fetch server version: \(error)")
            }

            for db in databases {
                await databaseHandler(db, db.name, versionString)
            }

            await progressHandler(Progress(fraction: 1.0, message: "SQL Server structure fetch completed"))
            return DatabaseStructure(
                serverVersion: versionString,
                databases: databases
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
