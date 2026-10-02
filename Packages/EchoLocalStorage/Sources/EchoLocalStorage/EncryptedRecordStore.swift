import CryptoKit
import Foundation
import SQLite3

public actor EncryptedRecordStore {
    public struct Configuration: Sendable {
        public let url: URL
        public let encryption: LocalEncryption?

        public init(url: URL, encryption: LocalEncryption? = nil) {
            self.url = url
            self.encryption = encryption
        }
    }

    public static let shared = EncryptedRecordStore(configuration: .init(url: defaultURL))
    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Echo/LocalStorage.sqlite")
    }

    private let configuration: Configuration
    private var connection: SQLiteConnection?
    private var encryption: LocalEncryption?

    public init(configuration: Configuration) { self.configuration = configuration }

    private func database() throws -> SQLiteConnection {
        if let connection { return connection }
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: configuration.url.path)
        let crypto = try configuration.encryption ?? LocalEncryption.load(allowCreation: !exists)
        try fm.createDirectory(at: configuration.url.deletingLastPathComponent(),
                               withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: configuration.url.deletingLastPathComponent().path)
        let db = try SQLiteConnection(url: configuration.url)
        try db.execute("""
            CREATE TABLE IF NOT EXISTS records (
                collection TEXT NOT NULL, id TEXT NOT NULL, group_id TEXT,
                payload BLOB NOT NULL, digest BLOB NOT NULL, position INTEGER NOT NULL,
                revision INTEGER NOT NULL DEFAULT 1, is_cache INTEGER NOT NULL,
                accessed REAL NOT NULL, PRIMARY KEY(collection,id))
            """)
        try db.execute("CREATE INDEX IF NOT EXISTS record_groups ON records(collection,group_id,position)")
        try db.execute("CREATE INDEX IF NOT EXISTS cache_access ON records(is_cache,accessed)")
        self.encryption = crypto
        self.connection = db
        try secureFiles()
        return db
    }

    private func crypto() throws -> LocalEncryption {
        _ = try database()
        guard let encryption else { throw LocalStorageError.missingKey }
        return encryption
    }

    public func encryptionContext() throws -> LocalEncryption { try crypto() }
    public func opaqueIdentifier(_ value: String) throws -> String { try crypto().identifier(for: value) }

    public func read(collection: String, id: String) throws -> Data? {
        let db = try database()
        let crypto = try crypto()
        var payload: Data?
        try db.query("SELECT payload,revision FROM records WHERE collection=? AND id=?", [.text(collection), .text(id)]) { row in
            payload = try crypto.open(SQLiteConnection.data(row, 0), context: context(collection, id, sqlite3_column_int64(row, 1)))
        }
        if payload != nil {
            let now = Date().timeIntervalSince1970
            try db.execute("UPDATE records SET accessed=? WHERE collection=? AND id=? AND accessed<?",
                           [.real(now), .text(collection), .text(id), .real(now - 60)])
        }
        return payload
    }

    public func records(collection: String, group: String? = nil) throws -> [LocalRecord] {
        let db = try database()
        let crypto = try crypto()
        var result: [LocalRecord] = []
        let filter = group == nil ? "" : " AND group_id=?"
        var values: [SQLiteConnection.Value] = [.text(collection)]
        if let group { values.append(.text(group)) }
        try db.query("SELECT id,group_id,payload,position,is_cache,revision FROM records WHERE collection=?\(filter) ORDER BY position,id", values) { row in
            let id = SQLiteConnection.text(row, 0)
            let group = sqlite3_column_type(row, 1) == SQLITE_NULL ? nil : SQLiteConnection.text(row, 1)
            let data = try crypto.open(SQLiteConnection.data(row, 2), context: context(collection, id, sqlite3_column_int64(row, 5)))
            result.append(LocalRecord(collection: collection, id: id, group: group, payload: data,
                                      position: Int(sqlite3_column_int64(row, 3)), isCache: sqlite3_column_int(row, 4) != 0))
        }
        return result
    }

    public func write(_ record: LocalRecord) throws {
        let db = try database()
        try db.transaction { try put(record, database: db) }
        try secureFiles()
    }

    /// A collection snapshot updates only changed payloads; unrelated collections are untouched.
    public func replace(collection: String, with records: [LocalRecord]) throws {
        guard records.allSatisfy({ $0.collection == collection }), Set(records.map(\.id)).count == records.count else {
            throw LocalStorageError.invalidRecord
        }
        let db = try database()
        try db.transaction {
            var existing: [String] = []
            try db.query("SELECT id FROM records WHERE collection=?", [.text(collection)]) { existing.append(SQLiteConnection.text($0, 0)) }
            let ids = Set(records.map(\.id))
            for id in existing where !ids.contains(id) {
                try db.execute("DELETE FROM records WHERE collection=? AND id=?", [.text(collection), .text(id)])
            }
            for record in records { try put(record, database: db) }
        }
        try secureFiles()
    }

    public func remove(collection: String, id: String? = nil, group: String? = nil) throws {
        let db = try database()
        var sql = "DELETE FROM records WHERE collection=?"
        var values: [SQLiteConnection.Value] = [.text(collection)]
        if let id { sql += " AND id=?"; values.append(.text(id)) }
        if let group { sql += " AND group_id=?"; values.append(.text(group)) }
        try db.execute(sql, values)
    }

    public func usage(collection: String) throws -> UInt64 {
        var total: UInt64 = 0
        try database().query("SELECT COALESCE(SUM(length(payload)),0) FROM records WHERE collection=?", [.text(collection)]) {
            total = UInt64(max(0, sqlite3_column_int64($0, 0)))
        }
        return total
    }

    public func prune(collection: String, limit: UInt64, protecting groups: Set<String> = []) throws {
        let db = try database()
        var total = try usage(collection: collection)
        guard total > limit else { return }
        var candidates: [(String, String, UInt64)] = []
        try db.query("SELECT id,COALESCE(group_id,''),length(payload) FROM records WHERE collection=? AND is_cache=1 ORDER BY accessed", [.text(collection)]) {
            candidates.append((SQLiteConnection.text($0, 0), SQLiteConnection.text($0, 1), UInt64(sqlite3_column_int64($0, 2))))
        }
        try db.transaction {
            for (id, group, size) in candidates where total > limit && !groups.contains(group) {
                try db.execute("DELETE FROM records WHERE collection=? AND id=?", [.text(collection), .text(id)])
                total -= min(total, size)
            }
        }
    }

    public func hasMigration(_ name: String) throws -> Bool { try read(collection: "migration", id: name) != nil }
    public func finishMigration(_ name: String) throws {
        try write(LocalRecord(collection: "migration", id: name, payload: Data("complete".utf8)))
    }

    private func put(_ record: LocalRecord, database db: SQLiteConnection) throws {
        let crypto = try crypto()
        let digest = crypto.digest(record.payload)
        var revision: Int64 = 0
        var unchanged = false
        try db.query("SELECT revision,digest FROM records WHERE collection=? AND id=?", [.text(record.collection), .text(record.id)]) {
            revision = sqlite3_column_int64($0, 0)
            unchanged = SQLiteConnection.data($0, 1) == digest
        }
        if unchanged {
            try db.execute("UPDATE records SET position=?,group_id=? WHERE collection=? AND id=?",
                           [.integer(Int64(record.position)), record.group.map(SQLiteConnection.Value.text) ?? .null,
                            .text(record.collection), .text(record.id)])
            return
        }
        revision += 1
        let payload = try crypto.seal(record.payload, context: context(record.collection, record.id, revision))
        try db.execute("""
            INSERT INTO records(collection,id,group_id,payload,digest,position,revision,is_cache,accessed)
            VALUES(?,?,?,?,?,?,?,?,?) ON CONFLICT(collection,id) DO UPDATE SET
            group_id=excluded.group_id,payload=excluded.payload,digest=excluded.digest,position=excluded.position,
            revision=excluded.revision,is_cache=excluded.is_cache,accessed=excluded.accessed
            """, [.text(record.collection), .text(record.id), record.group.map(SQLiteConnection.Value.text) ?? .null,
                  .blob(payload), .blob(digest), .integer(Int64(record.position)), .integer(revision),
                  .integer(record.isCache ? 1 : 0), .real(Date().timeIntervalSince1970)])
    }

    private func context(_ collection: String, _ id: String, _ revision: Int64) -> String {
        "record:\(collection.utf8.count):\(collection):\(id.utf8.count):\(id):\(revision)"
    }

    private func secureFiles() throws {
        for suffix in ["", "-wal", "-shm"] {
            let path = configuration.url.path + suffix
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            }
        }
    }
}
