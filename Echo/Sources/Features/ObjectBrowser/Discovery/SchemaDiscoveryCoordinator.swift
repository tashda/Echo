import Foundation
import Observation

@Observable @MainActor
final class MetadataDiscoveryCoordinator: MetadataDiscoveryCoordinatorProtocol, @unchecked Sendable {
    private let identityRepository: IdentityRepository
    private let connectionStore: ConnectionStore
    
    var onPersistConnections: (@MainActor @Sendable () async -> Void)?
    var onEnqueuePrefetch: (@MainActor @Sendable (ConnectionSession) async -> Void)?

    init(identityRepository: IdentityRepository, connectionStore: ConnectionStore) {
        self.identityRepository = identityRepository
        self.connectionStore = connectionStore
    }

    // MARK: - Core Discovery

    func startStructureLoadTask(for session: ConnectionSession) {
        session.structureLoadTask?.cancel()
        session.structureLoadTask = Task { @MainActor [weak self, weak session] in
            guard let self, let session else { return }
            defer { session.structureLoadTask = nil }
            
            ConnectionDebug.log("[SchemaDiscovery] Starting structure load for \(session.connection.connectionName)")
            
            do {
                _ = try await self.loadDatabaseStructureForSession(session)
                session.structureLoadingState = .ready
                session.structureLoadingMessage = nil
                await self.onEnqueuePrefetch?(session)
            } catch is CancellationError {
                session.structureLoadingState = .idle
            } catch {
                session.structureLoadingMessage = error.localizedDescription
                session.structureLoadingState = .failed(message: error.localizedDescription)
                ConnectionDebug.log("[SchemaDiscovery] Load failed: \(error.localizedDescription)")
            }
        }
    }

    func loadDatabaseStructureForSession(_ connectionSession: ConnectionSession) async throws -> DatabaseStructure {
        connectionSession.structureLoadingState = .loading(progress: 0)
        connectionSession.structureLoadingMessage = "Preparing update…"

        if connectionSession.databaseStructure == nil {
            connectionSession.databaseStructure = DatabaseStructure(serverVersion: nil, databases: [])
        }

        guard let credentials = identityRepository.resolveAuthenticationConfiguration(for: connectionSession.connection, overridePassword: nil) else {
            connectionSession.structureLoadingState = .failed(message: "Missing credentials")
            throw DatabaseError.connectionFailed("Missing credentials")
        }

        let selectedDatabase: String?
        if let selected = connectionSession.selectedDatabaseName, !selected.isEmpty {
            selectedDatabase = selected
        } else {
            selectedDatabase = nil
        }

        var interimServerVersion = connectionSession.databaseStructure?.serverVersion
            ?? connectionSession.connection.cachedStructure?.serverVersion
            ?? connectionSession.connection.serverVersion

        guard let fetcher = makeStructureFetcher(for: connectionSession) else {
            connectionSession.structureLoadingState = .failed(message: "Unsupported database type")
            throw DatabaseError.connectionFailed("Unsupported database type")
        }

        try Task.checkCancellation()

        do {
            let structure = try await fetcher.fetchStructure(
                for: connectionSession.connection,
                credentials: ConnectionCredentials(authentication: credentials),
                selectedDatabase: selectedDatabase,
                reuseSession: connectionSession.session,
                databaseFilter: nil as String?,
                cachedStructure: connectionSession.connection.cachedStructure,
                progressHandler: { progress in
                    Task { @MainActor in
                        connectionSession.structureLoadingState = .loading(progress: progress.fraction)
                        if let message = progress.message {
                            connectionSession.structureLoadingMessage = message
                        }
                    }
                },
                databaseHandler: { database, _, _ in
                    Task { @MainActor in
                        var databases = connectionSession.databaseStructure?.databases
                            ?? connectionSession.connection.cachedStructure?.databases
                            ?? []
                        if let index = databases.firstIndex(where: { $0.name == database.name }) {
                            let previous = databases[index]
                            let merged = Self.mergeDatabaseInfo(partial: database, existing: previous)
                            if previous == merged {
                                self.ensureSelectedDatabaseIfNeeded(for: connectionSession, availableDatabases: databases)
                                return
                            }
                            databases[index] = merged
                        } else {
                            let fallbackExisting = connectionSession.databaseStructure?.databases.first(where: { $0.name == database.name })
                            let merged = Self.mergeDatabaseInfo(partial: database, existing: fallbackExisting)
                            databases.append(merged)
                            databases.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                        }

                        let resolvedServerVersion = interimServerVersion
                            ?? connectionSession.databaseStructure?.serverVersion
                            ?? connectionSession.connection.cachedStructure?.serverVersion

                        let updatedStructure = DatabaseStructure(serverVersion: resolvedServerVersion, databases: databases)
                        self.applyStructureUpdateIfNeeded(updatedStructure, to: connectionSession, cacheResult: true)
                        self.ensureSelectedDatabaseIfNeeded(for: connectionSession, availableDatabases: databases)
                    }
                }
            )

            if let serverVersion = structure.serverVersion {
                interimServerVersion = serverVersion
            }

            // Merge fetcher results into existing structure instead of replacing,
            // so previously loaded databases are preserved
            var mergedDatabases = connectionSession.databaseStructure?.databases ?? []
            for db in structure.databases {
                if let index = mergedDatabases.firstIndex(where: { $0.name == db.name }) {
                    mergedDatabases[index] = Self.mergeDatabaseInfo(partial: db, existing: mergedDatabases[index])
                } else {
                    mergedDatabases.append(db)
                }
            }

            // For non-MSSQL, list all databases and add empty entries for unlisted ones.
            // MSSQL already fetches the full database list with state in its fetcher.
            if !(connectionSession.session is SQLServerSessionAdapter) {
                do {
                    let allDatabaseNames = try await connectionSession.session.listDatabases()
                    let existingNames = Set(mergedDatabases.map(\.name))
                    for dbName in allDatabaseNames where !existingNames.contains(dbName) {
                        mergedDatabases.append(DatabaseInfo(name: dbName, schemas: [], schemaCount: 0))
                    }
                } catch {
                    ConnectionDebug.log("[SchemaDiscovery] listDatabases failed (non-fatal): \(error.localizedDescription)")
                }
            }

            mergedDatabases.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            let finalStructure = DatabaseStructure(serverVersion: interimServerVersion, databases: mergedDatabases)
            self.applyStructureUpdateIfNeeded(finalStructure, to: connectionSession, cacheResult: true)

            connectionSession.structureLoadingState = .ready
            connectionSession.structureLoadingMessage = nil

            ensureSelectedDatabaseIfNeeded(for: connectionSession, availableDatabases: finalStructure.databases)
            return connectionSession.databaseStructure ?? finalStructure
        } catch {
            if error is CancellationError {
                connectionSession.structureLoadingState = .idle
            } else {
                connectionSession.structureLoadingState = .failed(message: error.localizedDescription)
            }
            throw error
        }
    }

    func refreshStructure(for session: ConnectionSession, scope: EnvironmentState.StructureRefreshScope) async {
        startStructureLoadTask(for: session)
    }

    /// Loads schema for a single database without cancelling any existing structure load task.
    /// This allows multiple databases to load in parallel (critical for PostgreSQL where each
    /// database requires a separate connection).
    func loadDatabaseSchemaOnly(_ databaseName: String, for session: ConnectionSession) async {
        guard let credentials = identityRepository.resolveAuthenticationConfiguration(
            for: session.connection, overridePassword: nil
        ) else { return }

        guard let fetcher = makeStructureFetcher(for: session) else { return }

        // Ensure we have a base structure to merge into
        if session.databaseStructure == nil {
            session.databaseStructure = DatabaseStructure(serverVersion: nil, databases: [])
        }

        do {
            let structure = try await fetcher.fetchStructure(
                for: session.connection,
                credentials: ConnectionCredentials(authentication: credentials),
                selectedDatabase: databaseName,
                reuseSession: session.session,
                databaseFilter: nil,
                cachedStructure: session.databaseStructure,
                progressHandler: { _ in },
                databaseHandler: { [weak self, weak session] database, _, _ in
                    guard let self, let session else { return }
                    Task { @MainActor in
                        self.mergeSingleDatabase(database, into: session)
                    }
                }
            )

            // Final merge of fetcher results
            for db in structure.databases {
                mergeSingleDatabase(db, into: session)
            }
        } catch {
            ConnectionDebug.log("[SchemaDiscovery] loadDatabaseSchemaOnly failed for '\(databaseName)': \(error.localizedDescription)")
        }
    }

    private func mergeSingleDatabase(_ database: DatabaseInfo, into session: ConnectionSession) {
        var databases = session.databaseStructure?.databases ?? []
        if let index = databases.firstIndex(where: { $0.name == database.name }) {
            let merged = Self.mergeDatabaseInfo(partial: database, existing: databases[index])
            if databases[index] == merged { return }
            databases[index] = merged
        } else {
            databases.append(database)
            databases.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        let updated = DatabaseStructure(
            serverVersion: session.databaseStructure?.serverVersion,
            databases: databases
        )
        applyStructureUpdateIfNeeded(updated, to: session, cacheResult: true)
    }

    func preloadStructure(for connection: SavedConnection, overridePassword: String?) async {
        // Implementation for preloading if needed
    }

    // MARK: - Private Helpers

    private func makeStructureFetcher(for connectionSession: ConnectionSession) -> DatabaseStructureFetcher? {
        let session = connectionSession.session
        switch connectionSession.connection.databaseType {
        case .postgresql: return PostgresStructureFetcher(session: session)
        case .microsoftSQL: return MSSQLStructureFetcher(session: session)
        case .mysql, .sqlite: return nil
        }
    }

    private func ensureSelectedDatabaseIfNeeded(for session: ConnectionSession, availableDatabases: [DatabaseInfo]) {
        // Only fix invalid selections (database no longer exists); never auto-select when nil
        if let selected = session.selectedDatabaseName,
           !availableDatabases.contains(where: { $0.name == selected }) {
            session.selectedDatabaseName = nil
        }
    }

    @discardableResult
    private func applyStructureUpdateIfNeeded(_ structure: DatabaseStructure, to session: ConnectionSession, cacheResult: Bool) -> Bool {
        if session.databaseStructure != structure {
            session.databaseStructure = structure
            if cacheResult {
                var updated = session.connection
                updated.cachedStructure = structure
                updated.cachedStructureUpdatedAt = Date()
                if let version = structure.serverVersion { updated.serverVersion = version }
                Task { await updateConnectionInStore(updated) }
            }
            return true
        }
        return false
    }

    private func updateConnectionInStore(_ connection: SavedConnection) async {
        if let index = connectionStore.connections.firstIndex(where: { $0.id == connection.id }) {
            connectionStore.connections[index] = connection
            await onPersistConnections?()
        }
    }

    static func mergeDatabaseInfo(partial: DatabaseInfo, existing: DatabaseInfo?) -> DatabaseInfo {
        guard let existing else {
            let sortedSchemas = partial.schemas.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return DatabaseInfo(name: partial.name, schemas: sortedSchemas, schemaCount: max(partial.schemaCount, sortedSchemas.count), stateDescription: partial.stateDescription)
        }
        var mergedSchemas = mergeSchemas(partialSchemas: partial.schemas, existingSchemas: existing.schemas)
        mergedSchemas.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let state = partial.stateDescription ?? existing.stateDescription
        
        // Merge extensions
        var extensionMap = Dictionary(uniqueKeysWithValues: existing.extensions.map { ($0.id, $0) })
        for ext in partial.extensions {
            extensionMap[ext.id] = ext
        }
        let mergedExtensions = Array(extensionMap.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return DatabaseInfo(
            name: existing.name,
            schemas: mergedSchemas,
            extensions: mergedExtensions,
            schemaCount: max(existing.schemaCount, partial.schemaCount, mergedSchemas.count),
            stateDescription: state
        )
    }

    static func mergeSchemas(partialSchemas: [SchemaInfo], existingSchemas: [SchemaInfo]) -> [SchemaInfo] {
        var schemaMap = Dictionary(uniqueKeysWithValues: existingSchemas.map { ($0.name, $0) })
        for schema in partialSchemas {
            if let current = schemaMap[schema.name] {
                schemaMap[schema.name] = mergeSchemaInfo(partial: schema, existing: current)
            } else {
                schemaMap[schema.name] = schema
            }
        }
        return Array(schemaMap.values)
    }

    static func mergeSchemaInfo(partial: SchemaInfo, existing: SchemaInfo) -> SchemaInfo {
        // When partial has objects, treat it as authoritative for this schema.
        // Objects not present in the partial result have been renamed/dropped on the server.
        // Enrich partial objects with column details from existing when partial lacks them.
        guard !partial.objects.isEmpty else { return existing }
        let existingMap = Dictionary(existing.objects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let enriched = partial.objects.map { obj -> SchemaObjectInfo in
            if obj.columns.isEmpty, let prev = existingMap[obj.id], !prev.columns.isEmpty {
                return SchemaObjectInfo(
                    name: obj.name, schema: obj.schema, type: obj.type,
                    columns: prev.columns, parameters: obj.parameters,
                    triggerAction: obj.triggerAction, triggerTable: obj.triggerTable,
                    comment: obj.comment
                )
            }
            return obj
        }
        let sortedObjects = enriched.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return SchemaInfo(name: existing.name, objects: sortedObjects)
    }
}

enum SchemaComparator {
    static func diff(old: DatabaseInfo?, new: DatabaseInfo?) -> (inserted: Int, removed: Int, changed: Int) {
        guard let new else { return (0, 0, 0) }
        let oldObjects = old?.schemas.flatMap { $0.objects } ?? []
        let newObjects = new.schemas.flatMap { $0.objects }

        func key(_ o: SchemaObjectInfo) -> String { "\(o.type.rawValue)|\(o.id)" }
        let oldMap = Dictionary(oldObjects.map { (key($0), $0) }, uniquingKeysWith: { first, _ in first })
        let newMap = Dictionary(newObjects.map { (key($0), $0) }, uniquingKeysWith: { first, _ in first })

        let oldKeys = Set(oldMap.keys)
        let newKeys = Set(newMap.keys)
        let inserted = newKeys.subtracting(oldKeys).count
        let removed = oldKeys.subtracting(newKeys).count

        var changed = 0
        for commonKey in oldKeys.intersection(newKeys) {
            if let lhs = oldMap[commonKey], let rhs = newMap[commonKey] {
                let columnsChanged = lhs.columns.count != rhs.columns.count
                let commentChanged = (lhs.comment ?? "") != (rhs.comment ?? "")
                if columnsChanged || commentChanged { changed &+= 1 }
            }
        }
        return (inserted, removed, changed)
    }
}
