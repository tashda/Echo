import Foundation
import EchoLocalStorage
import Testing
@testable import Echo

@Suite("Object Browser Cache Store")
struct ObjectBrowserCacheStoreTests {
    @Test func ignoresEntryWhenConnectionFingerprintChanges() async throws {
        let fixture = try LocalStorageFixture()
        defer { fixture.cleanup() }
        let store = ObjectBrowserCacheStore(configuration: .init(rootDirectory: fixture.directory), storage: fixture.storage)
        let structure = TestFixtures.databaseStructure(databaseCount: 1, schemasPerDatabase: 1, tablesPerSchema: 1)
        let original = SavedConnection(
            id: UUID(),
            connectionName: "Demo",
            host: "db.local",
            port: 5432,
            database: "analytics",
            username: "echo",
            databaseType: .postgresql
        )

        try await store.stashStructure(structure, for: original, limitBytes: 512 * 1_024 * 1_024)

        var changed = original
        changed.port = 5433

        let entry = await store.entry(for: changed)
        #expect(entry == nil)
    }

    /// Legacy inline caches carry no fingerprint, so they could belong to the server a saved
    /// connection pointed at before it was edited: they are never moved into the store.
    @Test func doesNotMigrateLegacyInlineCache() async throws {
        let fixture = try LocalStorageFixture()
        defer { fixture.cleanup() }
        let store = ObjectBrowserCacheStore(configuration: .init(rootDirectory: fixture.directory), storage: fixture.storage)
        let structure = TestFixtures.databaseStructure(databaseCount: 1, schemasPerDatabase: 1, tablesPerSchema: 2)
        let connection = SavedConnection(
            id: UUID(),
            connectionName: "Legacy",
            host: "legacy.local",
            port: 5432,
            database: "legacydb",
            username: "echo",
            databaseType: .postgresql,
            cachedStructure: structure,
            cachedStructureUpdatedAt: Date(timeIntervalSince1970: 1_000)
        )

        await store.migrateLegacyCacheIfNeeded(from: connection, limitBytes: 512 * 1_024 * 1_024)

        #expect(await store.entry(for: connection) == nil)
    }

    @Test func initialLoadHydratesOnlySelectedDatabaseAndPreservesActiveCache() async throws {
        let fixture = try LocalStorageFixture()
        defer { fixture.cleanup() }
        let store = ObjectBrowserCacheStore(configuration: .init(rootDirectory: fixture.directory), storage: fixture.storage)
        let structure = TestFixtures.databaseStructure(databaseCount: 3, schemasPerDatabase: 2, tablesPerSchema: 10)
        let connection = SavedConnection(id: UUID(), connectionName: "Cache", host: "cache.local", port: 5432,
            database: structure.databases[0].name, username: "echo")
        try await store.stashStructure(structure, for: connection, limitBytes: Int.max)
        let selected = await store.entry(for: connection, databaseName: structure.databases[0].name)
        #expect(selected?.structure.databases[0].schemas.count == 2)
        #expect(selected?.structure.databases[1].schemas.isEmpty == true)
        let later = try await store.database(structure.databases[1].name, for: connection, fingerprint: connection.objectBrowserCacheFingerprint)
        #expect(later?.schemas.count == 2)
        #expect(try await store.databases(for: connection, fingerprint: connection.objectBrowserCacheFingerprint).count == 3)
        await store.setProtectedConnections([connection.id])
        await store.pruneToLimit(0)
        #expect(try await store.database(structure.databases[0].name, for: connection, fingerprint: connection.objectBrowserCacheFingerprint) != nil)
        await store.setProtectedConnections([])
        await store.pruneToLimit(0)
        #expect(try await store.database(structure.databases[0].name, for: connection, fingerprint: connection.objectBrowserCacheFingerprint) == nil)
    }

    @Test func importsFingerprintMatchedLegacyCacheAndRetiresSource() async throws {
        let fixture = try LocalStorageFixture()
        defer { fixture.cleanup() }
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        let connection = SavedConnection(connectionName: "Legacy", host: "legacy.local", port: 5432, database: "db_0", username: "test")
        let structure = TestFixtures.databaseStructure(databaseCount: 1, schemasPerDatabase: 1, tablesPerSchema: 1)
        let entry = ObjectBrowserCacheEntry(key: .init(connectionID: connection.id),
            connectionFingerprint: connection.legacyObjectBrowserCacheFingerprint, updatedAt: Date(), structure: structure)
        let url = fixture.directory.appendingPathComponent(connection.id.uuidString + ".json")
        try JSONEncoder().encode(entry).write(to: url)
        let store = ObjectBrowserCacheStore(configuration: .init(rootDirectory: fixture.directory), storage: fixture.storage)
        await store.migrateLegacyCacheIfNeeded(from: connection, limitBytes: Int.max)
        let restored = try await store.database(structure.databases[0].name, for: connection, fingerprint: connection.objectBrowserCacheFingerprint)
        #expect(restored?.schemas.count == 1)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    private func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ObjectBrowserCacheStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
