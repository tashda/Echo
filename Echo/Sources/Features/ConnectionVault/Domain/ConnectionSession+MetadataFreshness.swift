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
        metadataFreshnessByDatabase = Self.makeMetadataFreshnessMap(
            from: structure,
            loadedState: .cached,
            preserveExisting: false,
            existing: [:]
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
        liveDatabases: Set<String> = []
    ) -> [String: DatabaseMetadataFreshness] {
        var next: [String: DatabaseMetadataFreshness] = [:]
        for database in structure.databases {
            let key = database.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            let hasSchemas = database.schemas.contains(where: { !$0.objects.isEmpty })
            if !hasSchemas {
                next[key] = .listOnly
                continue
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
