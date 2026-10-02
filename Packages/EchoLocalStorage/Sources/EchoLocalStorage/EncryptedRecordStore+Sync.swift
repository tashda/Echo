import Foundation
import SQLite3

extension EncryptedRecordStore {
    static let syncedCollections: Set<String> = ["connections", "folders", "identities", "projects", "bookmarks", "settings", "project-settings"]

    public func syncContext() throws -> LocalSyncContext? {
        guard let data = try read(collection: "sync-context", id: "current") else { return nil }
        return try JSONDecoder().decode(LocalSyncContext.self, from: data)
    }

    public func configureSync(account: String, projects: Set<String>) throws {
        let context = LocalSyncContext(account: account, projects: projects)
        try write(LocalRecord(collection: "sync-context", id: "current", payload: LocalRecordEncoding.encode(context)))
    }

    public func generation() throws -> Int64 {
        var value: Int64 = 0
        try database().query("SELECT value FROM local_counters WHERE name='generation'") { value = sqlite3_column_int64($0, 0) }
        return value
    }

    func nextCounter(_ name: String, database db: SQLiteConnection) throws -> Int64 {
        try db.execute("INSERT INTO local_counters(name,value) VALUES(?,1) ON CONFLICT(name) DO UPDATE SET value=value+1", [.text(name)])
        var value: Int64 = 0
        try db.query("SELECT value FROM local_counters WHERE name=?", [.text(name)]) { value = sqlite3_column_int64($0, 0) }
        return value
    }

    func enqueue(collection: String, id: String, project: String?, isDelete: Bool, database db: SQLiteConnection) throws {
        guard Self.syncedCollections.contains(collection), let project, let context = try syncContext(),
              context.projects.contains(project) else { return }
        let account = try crypto().identifier(for: context.account)
        let cloudCollection = collection == "project-settings" ? "settings" : collection
        let revision = try nextCounter("outbox", database: db)
        try db.execute("""
            INSERT INTO pending_changes(account,collection,id,project_id,revision,is_delete) VALUES(?,?,?,?,?,?)
            ON CONFLICT(account,collection,id) DO UPDATE SET project_id=excluded.project_id,
            revision=excluded.revision,is_delete=excluded.is_delete
            """, [.text(account), .text(cloudCollection), .text(id), .text(project), .integer(revision), .integer(isDelete ? 1 : 0)])
    }

    public func markPending(collection: String, id: String, project: String, isDelete: Bool) throws {
        let db = try database()
        try db.transaction { try enqueue(collection: collection, id: id, project: project, isDelete: isDelete, database: db) }
        try secureFiles()
    }

    public func pendingChanges(account: String, project: String? = nil) throws -> [PendingLocalChange] {
        let accountID = try crypto().identifier(for: account)
        var values: [SQLiteConnection.Value] = [.text(accountID)]
        if let project { values.append(.text(project)) }
        let filter = project == nil ? "" : " AND project_id=?"
        var items: [PendingLocalChange] = []
        try database().query("SELECT collection,id,project_id,revision,is_delete FROM pending_changes WHERE account=?\(filter) ORDER BY revision", values) {
            items.append(PendingLocalChange(account: accountID, collection: SQLiteConnection.text($0, 0),
                id: SQLiteConnection.text($0, 1), projectID: SQLiteConnection.text($0, 2),
                revision: sqlite3_column_int64($0, 3), isDelete: sqlite3_column_int($0, 4) != 0))
        }
        return items
    }

    public func acknowledge(_ items: [PendingLocalChange]) throws {
        let db = try database()
        try db.transaction {
            for item in items {
                try db.execute("DELETE FROM pending_changes WHERE account=? AND collection=? AND id=? AND revision=?",
                    [.text(item.account), .text(item.collection), .text(item.id), .integer(item.revision)])
            }
        }
    }

    public func clearPending(account: String) throws {
        try database().execute("DELETE FROM pending_changes WHERE account=?", [.text(crypto().identifier(for: account))])
    }
}
