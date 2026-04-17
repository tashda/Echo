import Foundation

enum DatabaseMetadataFreshness: String, Codable, Sendable {
    case listOnly
    case cached
    case refreshing
    case live
    case failed
}

extension ConnectionSession {
    func isRefreshingMetadata(forDatabase databaseName: String) -> Bool {
        metadataFreshness(forDatabase: databaseName) == .refreshing
            || schemaLoadsInFlight.contains(schemaLoadKey(databaseName))
    }

    func metadataFreshness(forDatabase databaseName: String) -> DatabaseMetadataFreshness {
        metadataFreshnessByDatabase[schemaLoadKey(databaseName)] ?? .listOnly
    }

    func hydrateMetadataFreshnessFromCacheStructure() {
        guard let structure = databaseStructure else {
            metadataFreshnessByDatabase.removeAll()
            return
        }
        // Mark cached databases with schemas AND column data as .live so the first expand is instant.
        // Databases whose objects lack column data (e.g. saved when a server was unreachable or had
        // a schema-load failure) are treated as .listOnly so the background prefetch reloads them.
        metadataFreshnessByDatabase = Self.makeMetadataFreshnessMap(
            from: structure,
            loadedState: .live,
            preserveExisting: false,
            existing: [:],
            requireColumns: true
        )
    }

    func reconcileMetadataFreshnessFromLiveStructure(
        markingLive databasesLoadedLive: Set<String> = []
    ) {
        guard let structure = databaseStructure else {
            metadataFreshnessByDatabase.removeAll()
            return
        }
        let normalizedLive = Set(databasesLoadedLive.map(schemaLoadKey))
        metadataFreshnessByDatabase = Self.makeMetadataFreshnessMap(
            from: structure,
            loadedState: .cached,
            preserveExisting: true,
            existing: metadataFreshnessByDatabase,
            liveDatabases: normalizedLive
        )
    }

    func markMetadataRefreshStarted(forDatabase databaseName: String) {
        metadataFreshnessByDatabase[schemaLoadKey(databaseName)] = .refreshing
    }

    func markMetadataRefreshCompleted(forDatabase databaseName: String, hasSchemas: Bool) {
        metadataFreshnessByDatabase[schemaLoadKey(databaseName)] = hasSchemas ? .live : .listOnly
    }

    func markMetadataRefreshFailed(forDatabase databaseName: String) {
        metadataFreshnessByDatabase[schemaLoadKey(databaseName)] = .failed
    }

    func clearMetadataCacheState() {
        metadataFreshnessByDatabase.removeAll()
        databaseStructure = nil
        structureLoadingState = .idle
        structureLoadingMessage = nil
        schemaLoadsInFlight.removeAll()
    }

    private static func makeMetadataFreshnessMap(
        from structure: DatabaseStructure,
        loadedState: DatabaseMetadataFreshness,
        preserveExisting: Bool,
        existing: [String: DatabaseMetadataFreshness],
        liveDatabases: Set<String> = [],
        requireColumns: Bool = false
    ) -> [String: DatabaseMetadataFreshness] {
        var next: [String: DatabaseMetadataFreshness] = [:]
        for database in structure.databases {
            let key = database.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            let hasSchemas = database.schemas.contains(where: { !$0.objects.isEmpty })
            if !hasSchemas {
                // Preserve live/refreshing state even when the incoming structure has no schemas.
                // MSSQL (and MySQL) initial fetches return empty schemas intentionally — they do a
                // list-only load and rely on per-database lazy loads for schema detail.
                // Overriding a .live database with .listOnly forces an unnecessary re-fetch every
                // time the background structure refresh completes.
                if preserveExisting, let state = existing[key], state == .live || state == .refreshing {
                    next[key] = .live
                } else {
                    next[key] = .listOnly
                }
                continue
            }
            // When hydrating from cache (requireColumns = true), treat databases whose table/view
            // objects have no column data as .listOnly. This forces the background prefetch to
            // reload them, which happens when the server was previously unreachable (e.g. version
            // mismatch causing all schema loads to fail) or when columns were never persisted.
            if requireColumns {
                let hasColumns = database.schemas.contains(where: { schema in
                    schema.objects.contains(where: { obj in
                        (obj.type == .table || obj.type == .view) && !obj.columns.isEmpty
                    })
                })
                if !hasColumns {
                    next[key] = .listOnly
                    continue
                }
            }
            if liveDatabases.contains(key) {
                next[key] = .live
                continue
            }
            if preserveExisting, let state = existing[key], state == .live || state == .refreshing {
                next[key] = .live
                continue
            }
            next[key] = loadedState
        }
        return next
    }
}
