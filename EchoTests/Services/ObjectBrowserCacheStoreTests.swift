import Foundation
import Testing
@testable import Echo

@Suite("Object Browser Cache Store")
struct ObjectBrowserCacheStoreTests {
    @Test func ignoresEntryWhenConnectionFingerprintChanges() async throws {
        let store = ObjectBrowserCacheStore(configuration: .init(rootDirectory: try makeTempDirectory()))
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

    @Test func migratesLegacyInlineCacheWhenStoreEntryIsMissing() async throws {
        let store = ObjectBrowserCacheStore(configuration: .init(rootDirectory: try makeTempDirectory()))
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

        let entry = await store.entry(for: connection)
        #expect(entry?.structure == structure)
        #expect(entry?.updatedAt == connection.cachedStructureUpdatedAt)
    }

    @Test func prunesOldestEntriesFirstWhenOverLimit() async throws {
        let directory = try makeTempDirectory()
        let store = ObjectBrowserCacheStore(configuration: .init(rootDirectory: directory))
        let oldConnection = SavedConnection(
            id: UUID(),
            connectionName: "Old",
            host: "old.local",
            port: 5432,
            database: "old",
            username: "echo"
        )
        let newConnection = SavedConnection(
            id: UUID(),
            connectionName: "New",
            host: "new.local",
            port: 5432,
            database: "new",
            username: "echo"
        )

        let oldEntry = ObjectBrowserCacheEntry(
            key: ObjectBrowserCacheKey(connectionID: oldConnection.id),
            connectionFingerprint: oldConnection.objectBrowserCacheFingerprint,
            updatedAt: Date(timeIntervalSince1970: 1_000),
            structure: TestFixtures.databaseStructure(databaseCount: 3, schemasPerDatabase: 2, tablesPerSchema: 10)
        )
        let newEntry = ObjectBrowserCacheEntry(
            key: ObjectBrowserCacheKey(connectionID: newConnection.id),
            connectionFingerprint: newConnection.objectBrowserCacheFingerprint,
            updatedAt: Date(timeIntervalSince1970: 2_000),
            structure: TestFixtures.databaseStructure(databaseCount: 3, schemasPerDatabase: 2, tablesPerSchema: 10)
        )

        let encoder = JSONEncoder()
        let oldData = try encoder.encode(oldEntry)
        let newData = try encoder.encode(newEntry)
        try oldData.write(to: directory.appendingPathComponent("\(oldConnection.id.uuidString).json"))
        try newData.write(to: directory.appendingPathComponent("\(newConnection.id.uuidString).json"))

        await store.pruneToLimit(oldData.count + 1)

        #expect(await store.entry(for: oldConnection) == nil)
        #expect(await store.entry(for: newConnection) != nil)
    }

    private func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ObjectBrowserCacheStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
