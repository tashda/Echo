import Foundation
import Observation

@Observable @MainActor
final class SchemaDiscoveryCoordinator: SchemaDiscoveryCoordinatorProtocol, @unchecked Sendable {
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
                let structure = try await self.loadDatabaseStructureForSession(session)
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

        if connectionSession.selectedDatabaseName == nil,
           !connectionSession.connection.database.isEmpty {
            connectionSession.selectedDatabaseName = connectionSession.connection.database
        }

        guard let credentials = identityRepository.resolveAuthenticationConfiguration(for: connectionSession.connection, overridePassword: nil) else {
            connectionSession.structureLoadingState = .failed(message: "Missing credentials")
            throw DatabaseError.connectionFailed("Missing credentials")
        }

        let selectedDatabase: String?
        if let selected = connectionSession.selectedDatabaseName, !selected.isEmpty {
            selectedDatabase = selected
        } else if !connectionSession.connection.database.isEmpty {
            selectedDatabase = connectionSession.connection.database
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

            let finalStructure = DatabaseStructure(serverVersion: interimServerVersion, databases: structure.databases)
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

    func refreshStructure(for session: ConnectionSession, scope: WorkspaceSessionStore.StructureRefreshScope) async {
        startStructureLoadTask(for: session)
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
        if session.selectedDatabaseName == nil || !availableDatabases.contains(where: { $0.name == session.selectedDatabaseName }) {
            if let first = availableDatabases.first?.name {
                session.selectedDatabaseName = first
            }
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

    private static func mergeDatabaseInfo(partial: DatabaseInfo, existing: DatabaseInfo?) -> DatabaseInfo {
        guard let existing else {
            let sortedSchemas = partial.schemas.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return DatabaseInfo(name: partial.name, schemas: sortedSchemas, schemaCount: max(partial.schemaCount, sortedSchemas.count))
        }
        var mergedSchemas = mergeSchemas(partialSchemas: partial.schemas, existingSchemas: existing.schemas)
        mergedSchemas.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return DatabaseInfo(name: existing.name, schemas: mergedSchemas, schemaCount: max(existing.schemaCount, partial.schemaCount, mergedSchemas.count))
    }

    private static func mergeSchemas(partialSchemas: [SchemaInfo], existingSchemas: [SchemaInfo]) -> [SchemaInfo] {
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

    private static func mergeSchemaInfo(partial: SchemaInfo, existing: SchemaInfo) -> SchemaInfo {
        var objectMap = Dictionary(uniqueKeysWithValues: existing.objects.map { ($0.id, $0) })
        for object in partial.objects {
            objectMap[object.id] = object
        }
        let sortedObjects = objectMap.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
