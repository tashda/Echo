import Foundation
import os
import SQLServerNIO

private let structureLogger = os.Logger(subsystem: "dk.tippr.echo.database-structure", category: "Explorer")

struct DatabaseStructureFetcher {
    struct Credentials {
        let authentication: DatabaseAuthenticationConfiguration
    }

    struct Progress {
        let fraction: Double
        let databaseName: String
        let schemaName: String?
        let message: String?
    }

    let factory: DatabaseFactory
    let databaseType: DatabaseType

    private var supportedObjectTypes: Set<SchemaObjectInfo.ObjectType> {
        Set(SchemaObjectInfo.ObjectType.supported(for: databaseType))
    }

    func fetchStructure(
        for connection: SavedConnection,
        credentials: Credentials,
        selectedDatabase: String?,
        reuseSession: DatabaseSession? = nil,
        databaseFilter: [String]? = nil,
        progressHandler: (@Sendable (Progress) async -> Void)? = nil,
        databaseHandler: (@Sendable (DatabaseInfo, Int, Int) async -> Void)? = nil
    ) async throws -> DatabaseStructure {
        ConnectionDebug.log("Starting structure fetch for connection=\(connection.connectionName) type=\(connection.databaseType.displayName) selectedDatabase=\(selectedDatabase ?? "<nil>") filter=\(databaseFilter ?? [])")
        try Task.checkCancellation()

        let progressCallback = progressHandler

        func emitProgress(
            _ fraction: Double,
            databaseName: String,
            schemaName: String?,
            message: String?
        ) async {
            guard let progressCallback else { return }
            guard !Task.isCancelled else { return }
            let clamped = min(max(fraction, 0), 1)
            await progressCallback(Progress(fraction: clamped, databaseName: databaseName, schemaName: schemaName, message: message))
        }

        func message(for type: SchemaObjectInfo.ObjectType) -> String {
            switch type {
            case .table:
                return "Updating tables…"
            case .view:
                return "Updating views…"
            case .materializedView:
                return "Updating materialized views…"
            case .function:
                return "Updating functions…"
            case .trigger:
                return "Updating triggers…"
            case .procedure:
                return "Updating procedures…"
            }
        }

        let baseSession: DatabaseSession
        if let reuseSession {
            baseSession = reuseSession
        } else {
            try Task.checkCancellation()
            baseSession = try await factory.connect(
                host: connection.host,
                port: connection.port,
                database: connection.database.isEmpty ? nil : connection.database,
                tls: connection.useTLS,
                authentication: credentials.authentication
            )
            try Task.checkCancellation()
        }

        defer {
            if reuseSession == nil {
                Task { await baseSession.close() }
            }
        }

        var serverVersion = connection.serverVersion
        if serverVersion == nil {
            switch databaseType {
            case .postgresql:
                if let result = try? await baseSession.simpleQuery("SHOW server_version"),
                   let rawValue = result.rows.first?.first,
                   let version = rawValue,
                   !version.isEmpty {
                    serverVersion = version
                } else if let fallback = try? await baseSession.simpleQuery("SELECT version()"),
                          let rawValue = fallback.rows.first?.first,
                          let version = rawValue,
                          !version.isEmpty {
                    serverVersion = version
                }
            case .mysql:
                if let result = try? await baseSession.simpleQuery("SELECT VERSION()"),
                   let rawValue = result.rows.first?.first,
                   let version = rawValue,
                   !version.isEmpty {
                    serverVersion = version
                }
            case .sqlite:
                if let result = try? await baseSession.simpleQuery("SELECT sqlite_version()"),
                   let rawValue = result.rows.first?.first,
                   let version = rawValue,
                   !version.isEmpty {
                    serverVersion = version
                }
            case .microsoftSQL:
                if let result = try? await baseSession.simpleQuery("SELECT CONCAT(CONVERT(varchar(100), SERVERPROPERTY('ProductVersion')), ' ', CONVERT(varchar(100), SERVERPROPERTY('Edition')))") ,
                   let rawValue = result.rows.first?.first,
                   let version = rawValue,
                   !version.isEmpty {
                    serverVersion = version
                }
            }
        }

        var baseSessionDatabaseName: String?
        switch databaseType {
        case .postgresql:
            try Task.checkCancellation()
            if let currentDatabase = try? await baseSession.simpleQuery("SELECT current_database()"),
               let rawValue = currentDatabase.rows.first?.first,
               let databaseName = rawValue,
               !databaseName.isEmpty {
                baseSessionDatabaseName = databaseName
            }
        case .mysql:
            try Task.checkCancellation()
            if let currentDatabase = try? await baseSession.simpleQuery("SELECT DATABASE()"),
               let rawValue = currentDatabase.rows.first?.first,
               let databaseName = rawValue,
               !databaseName.isEmpty {
                baseSessionDatabaseName = databaseName
            }
        case .sqlite:
            baseSessionDatabaseName = "main"
        case .microsoftSQL:
            if !connection.database.isEmpty {
                baseSessionDatabaseName = connection.database
            }
        }

        var databaseNames: [String]
        if let databaseFilter, !databaseFilter.isEmpty {
            var unique: [String] = []
            for name in databaseFilter where !name.isEmpty {
                try Task.checkCancellation()
                if !unique.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                    unique.append(name)
                }
            }
            databaseNames = unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        } else {
            try Task.checkCancellation()
            var fetched = try await baseSession.listDatabases()
            let explicitDatabase = connection.database
            if !explicitDatabase.isEmpty && !fetched.contains(explicitDatabase) {
                fetched.append(explicitDatabase)
            }
            databaseNames = Array(Set(fetched)).sorted()
            if databaseNames.isEmpty && !explicitDatabase.isEmpty {
                databaseNames = [explicitDatabase]
            }
        }

        ConnectionDebug.log("Fetched database names for \(connection.connectionName): \(databaseNames)")
        let normalizedFilter = databaseFilter?
            .compactMap { $0.isEmpty ? nil : $0.lowercased() }
        let totalDatabases = max(databaseNames.count, 1)
        var databaseInfos: [DatabaseInfo] = []

        func shouldLoadMetadata(for databaseName: String) -> Bool {
            if let selectedDatabase,
               databaseName.caseInsensitiveCompare(selectedDatabase) == .orderedSame {
                return true
            }
            if let normalizedFilter,
               normalizedFilter.contains(databaseName.lowercased()) {
                return true
            }
            if !connection.database.isEmpty,
               databaseName.caseInsensitiveCompare(connection.database) == .orderedSame {
                return true
            }
            return false
        }

        func sanitizedSchemaInfo(_ schema: SchemaInfo) -> SchemaInfo {
            guard !supportedObjectTypes.isEmpty else { return schema }
            let filteredObjects = schema.objects.filter { supportedObjectTypes.contains($0.type) }
            guard filteredObjects.count != schema.objects.count else { return schema }
            let removedTypes = Set(schema.objects.map(\.type)).subtracting(supportedObjectTypes)
            if !removedTypes.isEmpty {
                let removedDescription = removedTypes.map(\.rawValue).joined(separator: ",")
                structureLogger.notice("Filtered unsupported schema objects (\(removedDescription, privacy: .public)) for \(databaseType.displayName, privacy: .public) schema \(schema.name, privacy: .public)")
            }
            return SchemaInfo(name: schema.name, objects: filteredObjects)
        }

        for (databaseIndex, databaseName) in databaseNames.enumerated() {
            try Task.checkCancellation()
            let loadMetadata = shouldLoadMetadata(for: databaseName)
            let databaseStartFraction = Double(databaseIndex) / Double(totalDatabases)
            let initialMessage = loadMetadata
                ? "Updating database \(databaseName)…"
                : "Metadata deferred until database selection"
            try Task.checkCancellation()
            await emitProgress(databaseStartFraction, databaseName: databaseName, schemaName: nil, message: initialMessage)

            var sessionForDatabase: DatabaseSession?
            var shouldCloseSession = false
            var connectionError: Error?

            if loadMetadata {
                try Task.checkCancellation()
                if let reuseSession,
                   let selectedDatabase,
                   databaseName.caseInsensitiveCompare(selectedDatabase) == .orderedSame {
                    sessionForDatabase = reuseSession
                } else if reuseSession == nil,
                          let baseDatabaseName = baseSessionDatabaseName,
                          databaseName.caseInsensitiveCompare(baseDatabaseName) == .orderedSame {
                    sessionForDatabase = baseSession
                } else {
                    do {
                        try Task.checkCancellation()
                        sessionForDatabase = try await factory.connect(
                            host: connection.host,
                            port: connection.port,
                            database: databaseName.isEmpty ? nil : databaseName,
                            tls: connection.useTLS,
                            authentication: credentials.authentication
                        )
                        try Task.checkCancellation()
                        shouldCloseSession = (sessionForDatabase != nil)
                    } catch {
                        connectionError = error
                    }
                }
            }

            ConnectionDebug.log("Preparing database=\(databaseName) (index=\(databaseIndex + 1)/\(totalDatabases)) loadMetadata=\(loadMetadata)")
            guard loadMetadata, let activeSession = sessionForDatabase else {
                if Task.isCancelled {
                    throw CancellationError()
                }
                if loadMetadata, let error = connectionError {
                    print("Failed to connect to database \(databaseName) for connection \(connection.connectionName): \(error.localizedDescription)")
                }

                let placeholder = DatabaseInfo(name: databaseName, schemas: [], schemaCount: 0)
                databaseInfos.append(placeholder)
                ConnectionDebug.log("Database=\(databaseName) skipped metadata. error=\(connectionError?.localizedDescription ?? "none")")
                if let databaseHandler {
                    if Task.isCancelled {
                        throw CancellationError()
                    }
                    await databaseHandler(placeholder, databaseIndex, totalDatabases)
                }

                let completionFraction = Double(databaseIndex + 1) / Double(totalDatabases)
                let completionMessage = loadMetadata && connectionError != nil
                    ? "Database \(databaseName) skipped due to connection error"
                    : "Select a database to load metadata"
                if Task.isCancelled {
                    throw CancellationError()
                }
                await emitProgress(completionFraction, databaseName: databaseName, schemaName: nil, message: completionMessage)
                continue
            }

            var sessionForAttempt = activeSession
            var closeSessionWhenDone = shouldCloseSession
            var attempt = 0
            let maxAttempts = 2
            var metadataLoaded = false
            var lastFailure: Error?
            var loadedSchemas: [SchemaInfo] = []

            while attempt < maxAttempts && !metadataLoaded {
                attempt += 1
                do {
                    try Task.checkCancellation()
                    let schemaNames = try await sessionForAttempt.listSchemas()
                    let totalSchemas = max(schemaNames.count, 1)
                    ConnectionDebug.log("Database=\(databaseName) schema count=\(schemaNames.count) attempt=\(attempt)")

                    if schemaNames.isEmpty {
                        let completionFraction = Double(databaseIndex + 1) / Double(totalDatabases)
                        if Task.isCancelled {
                            throw CancellationError()
                        }
                        await emitProgress(completionFraction, databaseName: databaseName, schemaName: nil, message: "No schemas found")
                    }

                    var schemas: [SchemaInfo] = []
                    for (schemaIndex, schemaName) in schemaNames.enumerated() {
                        try Task.checkCancellation()
                        let schemaBaseFraction = (
                            Double(databaseIndex)
                            + Double(schemaIndex) / Double(totalSchemas)
                        ) / Double(totalDatabases)
                        if Task.isCancelled {
                            throw CancellationError()
                        }
                        await emitProgress(schemaBaseFraction, databaseName: databaseName, schemaName: schemaName, message: "Updating schema \(schemaName)…")

                        let rawSchemaInfo: SchemaInfo
                        if let metadataSession = sessionForAttempt as? DatabaseMetadataSession {
                            try Task.checkCancellation()
                            rawSchemaInfo = try await metadataSession.loadSchemaInfo(schemaName) { objectType, currentIndex, total in
                                guard supportedObjectTypes.contains(objectType) else {
                                    structureLogger.warning("Received unsupported object type \(objectType.rawValue, privacy: .public) for \(databaseType.displayName, privacy: .public) (schema \(schemaName, privacy: .public))")
                                    return
                                }
                                guard !Task.isCancelled else { return }
                                let normalizedTotal = max(total, 1)
                                let objectFraction = Double(currentIndex) / Double(normalizedTotal)
                                let schemaFraction = (
                                    Double(schemaIndex) + objectFraction
                                ) / Double(totalSchemas)
                                let overallFraction = (
                                    Double(databaseIndex) + schemaFraction
                                ) / Double(totalDatabases)
                                await emitProgress(overallFraction, databaseName: databaseName, schemaName: schemaName, message: message(for: objectType))
                            }
                        } else {
                            try Task.checkCancellation()
                            let objects = try await sessionForAttempt.listTablesAndViews(schema: schemaName)
                            rawSchemaInfo = SchemaInfo(name: schemaName, objects: objects)
                        }

                        let schemaInfo = sanitizedSchemaInfo(rawSchemaInfo)
                        schemas.append(schemaInfo)

                        let schemaCompletionFraction = (
                            Double(databaseIndex)
                            + Double(schemaIndex + 1) / Double(totalSchemas)
                        ) / Double(totalDatabases)
                        if Task.isCancelled {
                            throw CancellationError()
                        }
                        await emitProgress(schemaCompletionFraction, databaseName: databaseName, schemaName: schemaName, message: "Schema \(schemaName) updated")
                    }

                    loadedSchemas = schemas
                    metadataLoaded = true

                    if closeSessionWhenDone {
                        await sessionForAttempt.close()
                    }
                } catch let sessionError as MSSQLSessionError {
                    lastFailure = sessionError
                    structureLogger.error("SQL Server closed the connection while loading metadata for \(databaseName, privacy: .public) (attempt \(attempt)/\(maxAttempts)): connection closed")
                    ConnectionDebug.log("Database=\(databaseName) metadata attempt=\(attempt) connectionClosed")

                    if closeSessionWhenDone {
                        await sessionForAttempt.close()
                    }

                    if attempt >= maxAttempts {
                        break
                    } else {
                        try Task.checkCancellation()
                        sessionForAttempt = try await factory.connect(
                            host: connection.host,
                            port: connection.port,
                            database: databaseName.isEmpty ? nil : databaseName,
                            tls: connection.useTLS,
                            authentication: credentials.authentication
                        )
                        closeSessionWhenDone = true
                        continue
                    }
                } catch let sqlError as SQLServerError {
                    if case .connectionClosed = sqlError {
                        lastFailure = MSSQLSessionError.connectionClosed
                        structureLogger.error("SQL Server closed the connection while loading metadata for \(databaseName, privacy: .public) (attempt \(attempt)/\(maxAttempts)): connection closed")
                        ConnectionDebug.log("Database=\(databaseName) metadata attempt=\(attempt) connectionClosed")

                        if closeSessionWhenDone {
                            await sessionForAttempt.close()
                        }

                        if attempt >= maxAttempts {
                            break
                        } else {
                            try Task.checkCancellation()
                            sessionForAttempt = try await factory.connect(
                                host: connection.host,
                                port: connection.port,
                                database: databaseName.isEmpty ? nil : databaseName,
                                tls: connection.useTLS,
                                authentication: credentials.authentication
                            )
                            closeSessionWhenDone = true
                            continue
                        }
                    } else {
                        lastFailure = sqlError
                        if closeSessionWhenDone {
                            await sessionForAttempt.close()
                        }
                        throw DatabaseError.queryError(sqlError.description)
                    }
                } catch {
                    lastFailure = error
                    if closeSessionWhenDone {
                        await sessionForAttempt.close()
                    }
                    throw error
                }
            }

            if metadataLoaded {
                let totalObjects = loadedSchemas.reduce(0) { $0 + $1.objects.count }
                ConnectionDebug.log("Database=\(databaseName) loaded schemas=\(loadedSchemas.count) totalObjects=\(totalObjects)")
                let info = DatabaseInfo(name: databaseName, schemas: loadedSchemas, schemaCount: loadedSchemas.count)
                databaseInfos.append(info)
                if let databaseHandler {
                    if Task.isCancelled {
                        throw CancellationError()
                    }
                    await databaseHandler(info, databaseIndex, totalDatabases)
                }
            } else {
                let failure = lastFailure ?? DatabaseError.queryError("Failed to load metadata for database \(databaseName)")
                structureLogger.error("Giving up on metadata for \(databaseName, privacy: .public) after \(attempt) attempt(s): \(failure.localizedDescription, privacy: .public)")
                ConnectionDebug.log("Database=\(databaseName) metadata final failure: \(failure.localizedDescription)")
                let placeholder = DatabaseInfo(name: databaseName, schemas: [], schemaCount: 0)
                databaseInfos.append(placeholder)
                if let databaseHandler {
                    if Task.isCancelled {
                        throw CancellationError()
                    }
                    await databaseHandler(placeholder, databaseIndex, totalDatabases)
                }
                let completionFraction = Double(databaseIndex + 1) / Double(totalDatabases)
                await emitProgress(completionFraction, databaseName: databaseName, schemaName: nil, message: failure.localizedDescription)
                continue
            }

            let databaseCompletionFraction = Double(databaseIndex + 1) / Double(totalDatabases)
            if Task.isCancelled {
                throw CancellationError()
            }
            await emitProgress(databaseCompletionFraction, databaseName: databaseName, schemaName: nil, message: "Database \(databaseName) updated")
        }

        let structure = DatabaseStructure(
            serverVersion: serverVersion,
            databases: databaseInfos.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        )

        if Task.isCancelled {
            throw CancellationError()
        }
        await emitProgress(1.0, databaseName: "", schemaName: nil, message: "Metadata cached")

        ConnectionDebug.log("Completed structure fetch for connection=\(connection.connectionName) databases=\(structure.databases.count) totalSchemas=\(structure.databases.reduce(0) { $0 + $1.schemas.count })")
        return structure
    }
}
