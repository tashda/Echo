import Foundation
import os
import SQLServerKit

nonisolated private let structureLogger = os.Logger(subsystem: "dk.tippr.echo.database-structure", category: "Explorer")

nonisolated struct DatabaseStructureFetcher: Sendable {
    struct Credentials: Sendable {
        let authentication: DatabaseAuthenticationConfiguration
    }

    struct Progress: Sendable {
        let fraction: Double
        let databaseName: String
        let schemaName: String?
        let message: String?
    }

    let factory: DatabaseFactory
    let databaseType: DatabaseType

    // MARK: - Timeout helper (for resilience against indefinite driver/server stalls)
    private enum MetadataTimeoutError: LocalizedError {
        case timedOut(stage: String, database: String, schema: String?)
        var errorDescription: String? {
            switch self {
            case let .timedOut(stage, database, schema):
                if let schema { return "Metadata \(stage) timed out for \(database).\(schema)" }
                return "Metadata \(stage) timed out for \(database)"
            }
        }
    }

    private static func withTimeout<T: Sendable>(seconds: TimeInterval, stage: String, database: String, schema: String?, operation: @Sendable @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
                throw MetadataTimeoutError.timedOut(stage: stage, database: database, schema: schema)
            }
            defer { group.cancelAll() }
            let result = try await group.next()!
            return result
        }
    }

    @Sendable
    private static func message(for type: SchemaObjectInfo.ObjectType) -> String {
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

    func fetchStructure(
        for connection: SavedConnection,
        credentials: Credentials,
        selectedDatabase: String?,
        reuseSession: DatabaseSession? = nil,
        databaseFilter: [String]? = nil,
        cachedStructure: DatabaseStructure? = nil,
        progressHandler: (@Sendable (Progress) async -> Void)? = nil,
        databaseHandler: (@Sendable (DatabaseInfo, Int, Int) async -> Void)? = nil
    ) async throws -> DatabaseStructure {
        let runID = String(UUID().uuidString.prefix(8))
        ConnectionDebug.log("[Structure][\(runID)] start connection=\(connection.connectionName) type=\(connection.databaseType.displayName) selected=\(selectedDatabase ?? "<nil>") filter=\(databaseFilter ?? [])")
        try Task.checkCancellation()

        let progressCallback = progressHandler
        let supportedObjectTypes = Set(SchemaObjectInfo.ObjectType.supported(for: databaseType))

        @Sendable
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
                if let mssqlSession = baseSession as? MSSQLSession,
                   let version = try? await mssqlSession.serverVersion(),
                   !version.isEmpty {
                    serverVersion = version
                } else if let result = try? await baseSession.simpleQuery("SELECT CONCAT(CONVERT(varchar(100), SERVERPROPERTY('ProductVersion')), ' ', CONVERT(varchar(100), SERVERPROPERTY('Edition')))"),
                          let rawValue = result.rows.first?.first,
                          let version = rawValue,
                          !version.isEmpty {
                    serverVersion = version
                }
            }
        }

        // Identify current database if needed in future; currently unused
        switch databaseType {
        case .postgresql:
            _ = try? await baseSession.simpleQuery("SELECT current_database()")
        case .mysql:
            _ = try? await baseSession.simpleQuery("SELECT DATABASE()")
        case .sqlite:
            break
        case .microsoftSQL:
            break
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

        ConnectionDebug.log("[Structure][\(runID)] databases count=\(databaseNames.count) names=\(databaseNames)")
        let normalizedFilter = databaseFilter?
            .compactMap { $0.isEmpty ? nil : $0.lowercased() }
        let totalDatabases = max(databaseNames.count, 1)
        var databaseInfoMap: [String: DatabaseInfo] = [:]
        for name in databaseNames {
            databaseInfoMap[name] = DatabaseInfo(name: name, schemas: [], schemaCount: 0)
        }

        if let cachedStructure {
            let cachedDatabases = cachedStructure.databases.filter { info in
                if let filter = databaseFilter, !filter.isEmpty {
                    return filter.contains { $0.caseInsensitiveCompare(info.name) == .orderedSame }
                }
                return true
            }

            for cached in cachedDatabases {
                databaseInfoMap[cached.name] = cached
                if let databaseHandler,
                   let index = databaseNames.firstIndex(where: { $0.caseInsensitiveCompare(cached.name) == .orderedSame }) {
                    await databaseHandler(cached, index, totalDatabases)
                }
            }

            if serverVersion == nil {
                serverVersion = cachedStructure.serverVersion
            }
        }

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

        // Heartbeat logger: prints every 2s to show forward progress in Console (via actor for race‑free state)
        actor HeartbeatState {
            var stage: String = "init"
            var dbIndex: Int = 0
            var schema: String = ""
            var running: Bool = true
            func snapshot() -> (String, Int, String, Bool) { (stage, dbIndex, schema, running) }
            func update(stage: String? = nil, dbIndex: Int? = nil, schema: String? = nil) { if let stage { self.stage = stage }; if let dbIndex { self.dbIndex = dbIndex }; if let schema { self.schema = schema } }
            func stop() { running = false }
        }
        let hb = HeartbeatState()
        let hbTotal = databaseNames.count
        let heartbeat = Task.detached(priority: .utility) {
            while true {
                let snap = await hb.snapshot()
                if !snap.3 { break }
                let ts = String(format: "%.3f", CFAbsoluteTimeGetCurrent())
                ConnectionDebug.log("[Structure][\(runID)] hb t=\(ts) stage=\(snap.0) db=\(snap.1+1)/\(max(1, hbTotal)) schema=\(snap.2)")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        defer { Task { await hb.stop() }; heartbeat.cancel() }

        for (databaseIndex, databaseName) in databaseNames.enumerated() {
            try Task.checkCancellation()
            let loadMetadata = shouldLoadMetadata(for: databaseName)
            let databaseStartFraction = Double(databaseIndex) / Double(totalDatabases)
            let initialMessage = loadMetadata
                ? "Updating database \(databaseName)…"
                : "Metadata deferred until database selection"
            await hb.update(stage: "prepare-db", dbIndex: databaseIndex)
            structureLogger.info("[\(runID)] Starting metadata prep for database \(databaseName, privacy: .public) loadMetadata=\(loadMetadata, privacy: .public)")
            try Task.checkCancellation()
            await emitProgress(databaseStartFraction, databaseName: databaseName, schemaName: nil, message: initialMessage)

            var sessionForDatabase: DatabaseSession?
            var shouldCloseSession = false
            var connectionError: Error?

            if loadMetadata {
                // Use a dedicated session for per-database metadata to avoid contention
                // with the primary session (query editor or other consumers). This prevents
                // shared-connection stalls and ensures cancel reliably aborts in-flight work.
                try Task.checkCancellation()
                do {
                    await hb.update(stage: "connect-db")
                    sessionForDatabase = try await factory.connect(
                        host: connection.host,
                        port: connection.port,
                        database: databaseName.isEmpty ? nil : databaseName,
                        tls: connection.useTLS,
                        authentication: credentials.authentication
                    )
                    structureLogger.info("[\(runID)] Connected dedicated metadata session for database \(databaseName, privacy: .public)")
                    try Task.checkCancellation()
                    shouldCloseSession = (sessionForDatabase != nil)
                } catch {
                    structureLogger.error("[\(runID)] Connection attempt failed for database \(databaseName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    connectionError = error
                }
            }

            ConnectionDebug.log("[Structure][\(runID)] prepare db=\(databaseName) index=\(databaseIndex + 1)/\(totalDatabases) load=\(loadMetadata)")
            guard loadMetadata, let activeSession = sessionForDatabase else {
                if Task.isCancelled {
                    throw CancellationError()
                }
                if loadMetadata, let error = connectionError {
                    structureLogger.error("Skipping metadata for database \(databaseName, privacy: .public) due to connection error: \(error.localizedDescription, privacy: .public)")
                    print("Failed to connect to database \(databaseName) for connection \(connection.connectionName): \(error.localizedDescription)")
                }

                let placeholder = DatabaseInfo(name: databaseName, schemas: [], schemaCount: 0)
                databaseInfoMap[databaseName] = placeholder
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
                    await hb.update(stage: "list-schemas")
                    let schemaNames = try await sessionForAttempt.listSchemas()
                    structureLogger.info("[\(runID)] Database \(databaseName, privacy: .public) attempt \(attempt, privacy: .public) discovered \(schemaNames.count, privacy: .public) schemas")
                    let totalSchemas = max(schemaNames.count, 1)
                    ConnectionDebug.log("[Structure][\(runID)] schemas db=\(databaseName) count=\(schemaNames.count) attempt=\(attempt)")

                    if schemaNames.isEmpty {
                        let completionFraction = Double(databaseIndex + 1) / Double(totalDatabases)
                        if Task.isCancelled {
                            throw CancellationError()
                        }
                        await emitProgress(completionFraction, databaseName: databaseName, schemaName: nil, message: "No schemas found")
                    }

                    var schemas: [SchemaInfo] = []
                    for (schemaIndex, schemaName) in schemaNames.enumerated() {
                        await hb.update(stage: "schema-\(schemaIndex+1)/\(totalSchemas)", schema: schemaName)
                        try Task.checkCancellation()
                        let schemaBaseFraction = (
                            Double(databaseIndex)
                            + Double(schemaIndex) / Double(totalSchemas)
                        ) / Double(totalDatabases)
                        if Task.isCancelled {
                            throw CancellationError()
                        }
                        await emitProgress(schemaBaseFraction, databaseName: databaseName, schemaName: schemaName, message: "Updating schema \(schemaName)…")

                        var summaryIndex: Int?
                        var summaryResult: SchemaInfo?
                        if let summaryProvider = sessionForAttempt as? DatabaseSchemaSummaryProviding {
                            try Task.checkCancellation()
                            do {
                                await hb.update(stage: "summary")
                                // Avoid capturing non-Sendable provider inside a @Sendable closure
                                let summary = sanitizedSchemaInfo(try await summaryProvider.loadSchemaSummary(schemaName))
                                summaryResult = summary
                                if !summary.objects.isEmpty {
                                    schemas.append(summary)
                                    summaryIndex = schemas.count - 1
                                    if let databaseHandler {
                                        if Task.isCancelled {
                                            throw CancellationError()
                                        }
                                        let partial = DatabaseInfo(
                                            name: databaseName,
                                            schemas: schemas,
                                            schemaCount: schemas.count
                                        )
                                        await databaseHandler(partial, databaseIndex, totalDatabases)
                                    }
                                }
                            } catch {
                                structureLogger.warning("Failed to load summary for \(databaseName, privacy: .public).\(schemaName, privacy: .public): \(error.localizedDescription, privacy: .public)")
                            }
                        }

                        let rawSchemaInfo: SchemaInfo
                        if let metadataSession = sessionForAttempt as? DatabaseMetadataSession {
                            try Task.checkCancellation()
                            do {
                                await hb.update(stage: "details")
                                rawSchemaInfo = try await Self.withTimeout(
                                    seconds: 60,
                                    stage: "details",
                                    database: databaseName,
                                    schema: schemaName,
                                    operation: {
                                        try await metadataSession.loadSchemaInfo(schemaName) { objectType, currentIndex, total in
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
                                            await emitProgress(overallFraction, databaseName: databaseName, schemaName: schemaName, message: Self.message(for: objectType))
                                        }
                                    }
                                )
                            } catch {
                                let message = "Details failed for \(databaseName).\(schemaName): \(error.localizedDescription) — using summary if available"
                                structureLogger.error("\(message, privacy: .public)")
                                ConnectionDebug.log("[Structure][\(runID)] \(message)")
                                // Fall back to summary (or empty) so we keep making forward progress.
                                let summaryFromArray: SchemaInfo? = summaryIndex.flatMap { idx in
                                    schemas.indices.contains(idx) ? schemas[idx] : nil
                                }
                                rawSchemaInfo = summaryFromArray ?? summaryResult ?? SchemaInfo(name: schemaName, objects: [])
                            }
                        } else {
                            try Task.checkCancellation()
                            let objects = try await sessionForAttempt.listTablesAndViews(schema: schemaName)
                            rawSchemaInfo = SchemaInfo(name: schemaName, objects: objects)
                        }

                        let schemaInfo = sanitizedSchemaInfo(rawSchemaInfo)
                        if schemaInfo.objects.isEmpty {
                            structureLogger.info("Skipping schema \(schemaName, privacy: .public) for database \(databaseName, privacy: .public) because it contains no supported objects")
                            if let index = summaryIndex, schemas.indices.contains(index) {
                                schemas.remove(at: index)
                            }
                            continue
                        }

                        if let index = summaryIndex, schemas.indices.contains(index) {
                            schemas[index] = schemaInfo
                        } else {
                            schemas.append(schemaInfo)
                        }

                        if let databaseHandler {
                            if Task.isCancelled {
                                throw CancellationError()
                            }
                            let partial = DatabaseInfo(
                                name: databaseName,
                                schemas: schemas,
                                schemaCount: schemas.count
                            )
                            await databaseHandler(partial, databaseIndex, totalDatabases)
                        }

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
                    structureLogger.error("SQL Server session error while loading metadata for \(databaseName, privacy: .public) (attempt \(attempt)/\(maxAttempts)): \(sessionError, privacy: .public)")
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
                        structureLogger.error("SQL Server error while loading metadata for \(databaseName, privacy: .public) (attempt \(attempt)/\(maxAttempts)): \(sqlError.description, privacy: .public)")
                        if closeSessionWhenDone {
                            await sessionForAttempt.close()
                        }
                        throw DatabaseError.queryError(sqlError.description)
                    }
                } catch {
                    lastFailure = error
                    structureLogger.error("Unexpected error while loading metadata for \(databaseName, privacy: .public) (attempt \(attempt)/\(maxAttempts)): \(error.localizedDescription, privacy: .public)")
                    // Also log a reflection of the error to aid debugging of opaque errors
                    // like PostgresNIO.PostgresDecodingError which intentionally obscures details
                    // in localizedDescription.
                    let debugDescription = String(reflecting: error)
                    print("[DatabaseStructureFetcher] Debug error details (\(databaseName)) attempt=\(attempt): \(debugDescription)")
                    if closeSessionWhenDone {
                        await sessionForAttempt.close()
                    }
                    throw error
                }
            }

            if metadataLoaded {
                let totalObjects = loadedSchemas.reduce(0) { $0 + $1.objects.count }
                ConnectionDebug.log("Database=\(databaseName) loaded schemas=\(loadedSchemas.count) totalObjects=\(totalObjects)")
                    structureLogger.info("[\(runID)] Finished metadata load for database \(databaseName, privacy: .public) schemas=\(loadedSchemas.count, privacy: .public) objects=\(totalObjects, privacy: .public)")
                let info = DatabaseInfo(name: databaseName, schemas: loadedSchemas, schemaCount: loadedSchemas.count)
                databaseInfoMap[databaseName] = info
                if let databaseHandler {
                    if Task.isCancelled {
                        throw CancellationError()
                    }
                    await databaseHandler(info, databaseIndex, totalDatabases)
                }
            } else {
                let failure = lastFailure ?? DatabaseError.queryError("Failed to load metadata for database \(databaseName)")
                structureLogger.error("[\(runID)] Giving up on metadata for \(databaseName, privacy: .public) after \(attempt) attempt(s): \(failure.localizedDescription, privacy: .public)")
                ConnectionDebug.log("[Structure][\(runID)] failure db=\(databaseName) error=\(failure.localizedDescription)")
                let placeholder = DatabaseInfo(name: databaseName, schemas: [], schemaCount: 0)
                databaseInfoMap[databaseName] = placeholder
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

        let sortedDatabases = databaseNames.compactMap { databaseInfoMap[$0] }
        let structure = DatabaseStructure(
            serverVersion: serverVersion,
            databases: sortedDatabases
        )

        if Task.isCancelled {
            throw CancellationError()
        }
        await emitProgress(1.0, databaseName: "", schemaName: nil, message: "Metadata cached")

        ConnectionDebug.log("[Structure][\(runID)] done databases=\(structure.databases.count) totalSchemas=\(structure.databases.reduce(0) { $0 + $1.schemas.count })")
        return structure
    }
}
