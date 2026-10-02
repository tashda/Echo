import EchoLocalStorage
import Foundation

/// A durable account-scoped outbox. Normal configuration writes enqueue in the same transaction.
actor SyncDirtyTracker {
    private let storage: EncryptedRecordStore
    private var account: String = ""
    init(storage: EncryptedRecordStore = .shared) { self.storage = storage }
    func setAccount(_ account: String) { self.account = account }
    func load() async throws {
        _ = try await storage.pendingChanges(account: account)
        if try await LocalSyncImport.originalAccount() == account,
           let data = try await LocalArchive.shared.load(collection: "legacy-sync-dirty") {
            struct LegacyItem: Codable { let id: UUID; let collection: SyncCollection; let projectID: UUID; let isDelete: Bool }
            let items = try JSONDecoder().decode([LegacyItem].self, from: data)
            for item in items {
                try await storage.markPending(collection: item.collection.rawValue, id: item.id.uuidString,
                    project: item.projectID.uuidString, isDelete: item.isDelete)
            }
            try await LocalArchive.shared.remove(collection: "legacy-sync-dirty")
        }
    }
    func markDirty(id: UUID, collection: SyncCollection, projectID: UUID) async throws {
        try await storage.markPending(collection: collection.rawValue, id: id.uuidString,
            project: projectID.uuidString, isDelete: false)
    }
    func markDeleted(id: UUID, collection: SyncCollection, projectID: UUID) async throws {
        try await storage.markPending(collection: collection.rawValue, id: id.uuidString,
            project: projectID.uuidString, isDelete: true)
    }
    func dirtyItems(for projectID: UUID) async throws -> [DirtyItem] {
        try await storage.pendingChanges(account: account, project: projectID.uuidString).compactMap(DirtyItem.init)
    }
    var allDirtyItems: Set<DirtyItem> {
        get async throws { Set(try await storage.pendingChanges(account: account).compactMap(DirtyItem.init)) }
    }
    func clearDirty(_ items: Set<DirtyItem>) async throws {
        try await storage.acknowledge(items.compactMap(\.pending))
    }
    func clearAll() async throws { try await storage.clearPending(account: account) }
}

struct DirtyItem: Hashable, Sendable {
    let id: UUID
    let collection: SyncCollection
    let projectID: UUID
    var isDelete: Bool = false
    var pending: PendingLocalChange?

    init(id: UUID, collection: SyncCollection, projectID: UUID, isDelete: Bool = false) {
        self.id = id; self.collection = collection; self.projectID = projectID; self.isDelete = isDelete
    }
    init?(_ item: PendingLocalChange) {
        guard let id = UUID(uuidString: item.id), let collection = SyncCollection(rawValue: item.collection),
              let project = UUID(uuidString: item.projectID) else { return nil }
        self.id = id; self.collection = collection; self.projectID = project
        self.isDelete = item.isDelete; self.pending = item
    }
}
