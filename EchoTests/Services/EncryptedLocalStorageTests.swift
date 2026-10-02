import CryptoKit
import EchoLocalStorage
import Foundation
import Testing
@testable import Echo

struct LocalStorageFixture {
    let directory: URL
    let storage: EncryptedRecordStore
    let encryption: LocalEncryption
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("EchoStorageTests-\(UUID())")
        encryption = LocalEncryption(key: SymmetricKey(size: .bits256))
        storage = EncryptedRecordStore(configuration: .init(url: directory.appendingPathComponent("Local.sqlite"), encryption: encryption))
    }
    func cleanup() { try? FileManager.default.removeItem(at: directory) }
}

@Suite("Encrypted local storage")
struct EncryptedLocalStorageTests {
    @Test func testHostStorageIsIsolatedFromTheInstallation() {
        #expect(EncryptedRecordStore.defaultURL.path.contains("EchoTestHost-"))
    }

    @Test func authenticatedEnvelopesRejectTamperingRelocationAndWrongKey() throws {
        let crypto = LocalEncryption(key: SymmetricKey(size: .bits256))
        let other = LocalEncryption(key: SymmetricKey(size: .bits256))
        let secret = Data("private SQL SELECT customer_email FROM customers".utf8)
        let encrypted = try crypto.seal(secret, context: "row:A")
        #expect(try crypto.open(encrypted, context: "row:A") == secret)
        #expect(encrypted.range(of: secret) == nil)
        #expect(throws: (any Error).self) { try crypto.open(encrypted, context: "row:B") }
        #expect(throws: (any Error).self) { try other.open(encrypted, context: "row:A") }
        var tampered = encrypted
        tampered[tampered.count - 1] ^= 1
        #expect(throws: (any Error).self) { try crypto.open(tampered, context: "row:A") }
        #expect(try crypto.open(crypto.seal(Data(), context: "empty"), context: "empty").isEmpty)
        #expect(throws: (any Error).self) { try LocalEncryption.load(service: "EchoMissingKeyTest-\(UUID())", allowCreation: false) }
    }

    @Test func cloudRoutingChangesDoNotChangeCredentialFieldIdentity() {
        let local = UUID()
        let server = UUID()
        let doc = SyncDocument(id: UUID(), collection: .connections, projectID: local,
            fields: ["encryptedPassword": SyncField(value: Data("ciphertext".utf8), hlc: 7, isEncrypted: true)])
        let transmitted = doc.scoped(to: server)
        #expect(transmitted.projectID == server)
        #expect(transmitted.id == doc.id)
        #expect(transmitted.fields == doc.fields)
        #expect(transmitted.scoped(to: local) == doc)
    }

    @Test func selectiveEncryptedReadsAndUnchangedWrite() async throws {
        let fixture = try LocalStorageFixture()
        defer { fixture.cleanup() }
        let project = UUID().uuidString
        try await fixture.storage.configureSync(account: "A", projects: [project])
        let record = LocalRecord(collection: "connections", id: "one", group: project, payload: Data("private.example.com".utf8))
        try await fixture.storage.replace(collection: "connections", with: [record])
        let pending = try await fixture.storage.pendingChanges(account: "A")
        try await fixture.storage.replace(collection: "connections", with: [record])
        #expect(try await fixture.storage.pendingChanges(account: "A") == pending)
        #expect(try await fixture.storage.records(collection: "connections", group: "other").isEmpty)
        #expect(try await fixture.storage.read(collection: "connections", id: "one") == record.payload)
        for suffix in ["", "-wal"] {
            let url = fixture.directory.appendingPathComponent("Local.sqlite" + suffix)
            if let bytes = try? Data(contentsOf: url) { #expect(bytes.range(of: record.payload) == nil) }
        }
    }

    @Test func acknowledgementCannotClearNewerEditAndQueuesAreAccountScoped() async throws {
        let fixture = try LocalStorageFixture()
        defer { fixture.cleanup() }
        let project = UUID().uuidString
        try await fixture.storage.configureSync(account: "A", projects: [project])
        try await fixture.storage.write(.init(collection: "connections", id: "one", group: project, payload: Data("first".utf8)))
        let sent = try await fixture.storage.pendingChanges(account: "A")
        try await fixture.storage.write(.init(collection: "connections", id: "one", group: project, payload: Data("second".utf8)))
        try await fixture.storage.acknowledge(sent)
        let pending = try await fixture.storage.pendingChanges(account: "A")
        #expect(pending.count == 1)
        #expect(pending.first!.revision > sent.first!.revision)
        try await fixture.storage.configureSync(account: "B", projects: [project])
        #expect(try await fixture.storage.pendingChanges(account: "B").isEmpty)
        #expect(try await fixture.storage.pendingChanges(account: "A") == pending)
        try await fixture.storage.replace(collection: "connections", with: [])
        #expect(try await fixture.storage.pendingChanges(account: "B").first?.isDelete == true)
    }

    @Test func failedSnapshotRollsBackRecordsOutboxAndCheckpoint() async throws {
        let fixture = try LocalStorageFixture()
        defer { fixture.cleanup() }
        let record = LocalRecord(collection: "connections", id: "one", payload: Data("original".utf8))
        try await fixture.storage.write(record)
        let generation = try await fixture.storage.generation()
        let changed = LocalRecord(collection: "connections", id: "one", payload: Data("changed".utf8))
        let checkpoint = LocalRecord(collection: "sync-checkpoints", id: "checkpoint", payload: Data("123".utf8))
        do {
            try await fixture.storage.replaceCollections([.init(collection: "connections", records: [changed]),
                .init(collection: "folders", records: [record])], checkpoint: checkpoint)
            Issue.record("Invalid batch must fail")
        } catch {}
        #expect(try await fixture.storage.read(collection: "connections", id: "one") == record.payload)
        #expect(try await fixture.storage.read(collection: "sync-checkpoints", id: "checkpoint") == nil)
        #expect(try await fixture.storage.generation() == generation)
    }

    @Test func remoteCommitRejectsConcurrentEditAndDoesNotEnqueueRemoteRecords() async throws {
        let fixture = try LocalStorageFixture()
        defer { fixture.cleanup() }
        let project = UUID().uuidString
        try await fixture.storage.configureSync(account: "A", projects: [project])
        let oldGeneration = try await fixture.storage.generation()
        let local = LocalRecord(collection: "connections", id: "one", group: project, payload: Data("local".utf8))
        try await fixture.storage.write(local)
        let remote = LocalRecord(collection: "connections", id: "one", group: project, payload: Data("remote".utf8))
        do {
            try await fixture.storage.replaceCollections([.init(collection: "connections", records: [remote])], remote: true, expectedGeneration: oldGeneration)
            Issue.record("A stale remote batch must fail")
        } catch {}
        #expect(try await fixture.storage.read(collection: "connections", id: "one") == local.payload)
        try await fixture.storage.acknowledge(fixture.storage.pendingChanges(account: "A"))
        try await fixture.storage.replaceCollections([.init(collection: "connections", records: [remote])], remote: true)
        #expect(try await fixture.storage.pendingChanges(account: "A").isEmpty)
    }

    @Test func cacheEvictionProtectsActiveGroupsAndSavedWork() async throws {
        let fixture = try LocalStorageFixture()
        defer { fixture.cleanup() }
        try await fixture.storage.writeBatch([
            .init(collection: "cache", id: "active", group: "open", payload: Data(repeating: 1, count: 100), isCache: true),
            .init(collection: "cache", id: "old", group: "closed", payload: Data(repeating: 2, count: 100), isCache: true),
            .init(collection: "saved", id: "work", payload: Data("keep me".utf8))])
        try await fixture.storage.prune(collection: "cache", limit: 0, protecting: ["open"])
        #expect(try await fixture.storage.read(collection: "cache", id: "active") != nil)
        #expect(try await fixture.storage.read(collection: "cache", id: "old") == nil)
        #expect(try await fixture.storage.read(collection: "saved", id: "work") != nil)
    }
    @Test func encryptedChunksRemainRandomlyReadableAndRejectTampering() async throws {
        let fixture = try LocalStorageFixture()
        defer { fixture.cleanup() }
        let tempRoot = fixture.directory.appendingPathComponent("Results")
        let config = ResultSpoolConfiguration(rootDirectory: tempRoot, maximumBytes: 1_024 * 1_024,
            retentionInterval: 3600, inMemoryRowLimit: 0)
        let spooler = ResultSpooler(configuration: config, storage: fixture.storage)
        let handle = try await spooler.makeSpoolHandle()
        let columns = [ColumnInfo(name: "secret_email", dataType: "text")]
        try await handle.append(columns: columns, rows: [["alice@example.com"], ["bob@example.com"]],
            encodedRows: [], rowRange: nil, metrics: nil)
        try await handle.append(columns: columns, rows: [["carol@example.com"]],
            encodedRows: [], rowRange: nil, metrics: nil)
        try await handle.markFinished(commandTag: "SELECT 3", metrics: nil)
        let rows = try await handle.loadRows(offset: 1, limit: 2)
        #expect(rows == [["bob@example.com"], ["carol@example.com"]])
        let url = await handle.directory.appendingPathComponent("rows.bin")
        var bytes = try Data(contentsOf: url)
        #expect(bytes.range(of: Data("secret_email".utf8)) == nil)
        #expect(bytes.range(of: Data("alice@example.com".utf8)) == nil)
        bytes[bytes.count - 1] ^= 1
        try bytes.write(to: url)
        do {
            _ = try await handle.loadRows(offset: 2, limit: 1)
            Issue.record("Tampered result must fail authentication")
        } catch {}
        await spooler.clearAll()
    }


}
