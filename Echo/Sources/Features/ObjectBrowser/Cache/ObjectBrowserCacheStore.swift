import EchoLocalStorage
import Foundation
import OSLog

actor ObjectBrowserCacheStore {
    struct Configuration: Sendable { let rootDirectory: URL }
    private let configuration: Configuration
    private let storage: EncryptedRecordStore
    private var protectedConnections: Set<String> = []

    init(configuration: Configuration, storage: EncryptedRecordStore? = nil) {
        self.configuration = configuration
        self.storage = storage ?? (configuration.rootDirectory == Self.defaultRootDirectory()
            ? .shared : EncryptedRecordStore(configuration: .init(url: configuration.rootDirectory.appendingPathComponent("Cache.sqlite"))))
    }

    static func defaultRootDirectory() -> URL {
        EncryptedRecordStore.defaultURL.deletingLastPathComponent().appendingPathComponent("ObjectBrowserCache")
    }

    func setProtectedConnections(_ ids: Set<UUID>) { protectedConnections = Set(ids.map(\.uuidString)) }

    /// Read only the small catalog and the selected database. Other databases warm after presentation.
    func entry(for connection: SavedConnection, fingerprint: String? = nil,
               databaseName: String? = nil) async -> ObjectBrowserCacheEntry? {
        do {
            guard let data = try await storage.read(collection: "metadata-catalog", id: connection.id.uuidString) else { return nil }
            let catalog = try JSONDecoder().decode(ObjectBrowserCacheEntry.self, from: data)
            let fingerprint = fingerprint ?? connection.objectBrowserCacheFingerprint
            guard catalog.connectionFingerprint == fingerprint else { return nil }
            var databases = catalog.structure.databases
            if let name = databaseName, let cached = try await database(name, for: connection, fingerprint: fingerprint),
               let index = databases.firstIndex(where: { $0.name == name }) { databases[index] = cached }
            return ObjectBrowserCacheEntry(key: catalog.key, connectionFingerprint: fingerprint,
                updatedAt: catalog.updatedAt, structure: DatabaseStructure(serverVersion: catalog.structure.serverVersion, databases: databases))
        } catch {
            Logger(subsystem: "dev.echodb.echo", category: "local-storage").error("Metadata cache unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    func database(_ name: String, for connection: SavedConnection, fingerprint: String) async throws -> DatabaseInfo? {
        let id = try await storage.opaqueIdentifier("\(connection.id.uuidString):\(name)")
        guard let data = try await storage.read(collection: "metadata-database", id: id) else { return nil }
        let record = try JSONDecoder().decode(CachedDatabase.self, from: data)
        guard record.fingerprint == fingerprint else { return nil }
        return record.database
    }

    func migrateLegacyCacheIfNeeded(from connection: SavedConnection, limitBytes: Int,
                                    fingerprint: String? = nil) async {
        let url = configuration.rootDirectory.appendingPathComponent(connection.id.uuidString).appendingPathExtension("json")
        do {
            let marker = "metadata-\(connection.id.uuidString)"
            guard !(try await storage.hasMigration(marker)) else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                let old = try JSONDecoder().decode(ObjectBrowserCacheEntry.self, from: Data(contentsOf: url))
                if old.connectionFingerprint == connection.legacyObjectBrowserCacheFingerprint {
                    try await stashStructure(old.structure, for: connection, limitBytes: limitBytes,
                                             fingerprint: fingerprint, updatedAt: old.updatedAt)
                }
                try await storage.finishMigration(marker)
                try FileManager.default.removeItem(at: url)
            } else {
                try await storage.finishMigration(marker)
            }
            // Inline snapshots have no endpoint provenance; keep no stale fallback attached to the configuration.
            try await storage.remove(collection: "legacy-metadata", id: connection.id.uuidString)
        } catch {
            Logger(subsystem: "dev.echodb.echo", category: "local-storage").error("Metadata import paused: \(error.localizedDescription)")
        }
    }

    func stashStructure(_ structure: DatabaseStructure, for connection: SavedConnection,
                        limitBytes: Int, fingerprint: String? = nil, updatedAt: Date = Date(),
                        completedDatabases: Set<String> = []) async throws {
        let fingerprint = fingerprint ?? connection.objectBrowserCacheFingerprint
        var records: [LocalRecord] = []
        for (position, database) in structure.databases.enumerated() {
            // A list-only refresh must not erase a previously fetched database payload.
            guard !database.schemas.isEmpty || completedDatabases.contains(database.name) else { continue }
            let id = try await storage.opaqueIdentifier("\(connection.id.uuidString):\(database.name)")
            let payload = CachedDatabase(fingerprint: fingerprint, database: database)
            records.append(LocalRecord(collection: "metadata-database", id: id, group: connection.id.uuidString,
                payload: try JSONEncoder().encode(payload), position: position, isCache: true))
        }
        let catalog = ObjectBrowserCacheEntry(key: .init(connectionID: connection.id), connectionFingerprint: fingerprint,
            updatedAt: updatedAt, structure: DatabaseStructure(serverVersion: structure.serverVersion,
                databases: structure.databases.map { DatabaseInfo(name: $0.name, schemaCount: $0.schemaCount,
                    stateDescription: $0.stateDescription, hasAccess: $0.hasAccess) }))
        records.append(LocalRecord(collection: "metadata-catalog", id: connection.id.uuidString,
            group: connection.id.uuidString, payload: try JSONEncoder().encode(catalog), isCache: true))
        try await storage.writeBatch(records)
        await pruneToLimit(limitBytes)
    }

    func currentUsageBytes() async -> UInt64 {
        let catalog = (try? await storage.usage(collection: "metadata-catalog")) ?? 0
        let databases = (try? await storage.usage(collection: "metadata-database")) ?? 0
        return catalog + databases
    }

    func removeAll() async {
        do {
            try await storage.remove(collection: "metadata-catalog")
            try await storage.remove(collection: "metadata-database")
            try await storage.remove(collection: "legacy-metadata")
        } catch {
            Logger(subsystem: "dev.echodb.echo", category: "local-storage").error("Cache clearing failed: \(error.localizedDescription)")
        }
    }

    func pruneToLimit(_ limitBytes: Int) async {
        do {
            let catalogBytes = try await storage.usage(collection: "metadata-catalog")
            let limit = UInt64(max(0, limitBytes))
            try await storage.prune(collection: "metadata-database", limit: limit > catalogBytes ? limit - catalogBytes : 0,
                                    protecting: protectedConnections)
        } catch {
            Logger(subsystem: "dev.echodb.echo", category: "local-storage").error("Cache maintenance failed: \(error.localizedDescription)")
        }
    }

    private struct CachedDatabase: Codable { let fingerprint: String; let database: DatabaseInfo }
}
