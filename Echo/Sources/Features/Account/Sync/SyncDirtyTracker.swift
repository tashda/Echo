import Foundation

/// Tracks which local documents have been modified since the last successful push.
///
/// When a user changes a connection, folder, identity, or project locally,
/// the tracker records its ID and collection. During the next push cycle,
/// the SyncEngine reads the dirty set, converts those documents to SyncDocuments,
/// pushes them, and clears the dirty flag on success.
actor SyncDirtyTracker {
    private let fileURL: URL
    private var dirtyItems: Set<DirtyItem> = []

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let echoDir = appSupport.appendingPathComponent("Echo", isDirectory: true)
        self.fileURL = echoDir.appendingPathComponent("sync_dirty.json")
    }

    func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        dirtyItems = try JSONDecoder().decode(Set<DirtyItem>.self, from: data)
    }

    /// Mark a document as needing to be pushed.
    func markDirty(id: UUID, collection: SyncCollection, projectID: UUID) throws {
        dirtyItems.insert(DirtyItem(id: id, collection: collection, projectID: projectID))
        try save()
    }

    /// Mark a document as deleted (needs tombstone push).
    func markDeleted(id: UUID, collection: SyncCollection, projectID: UUID) throws {
        dirtyItems.insert(DirtyItem(id: id, collection: collection, projectID: projectID, isDelete: true))
        try save()
    }

    /// Get all dirty items for a given project.
    func dirtyItems(for projectID: UUID) -> [DirtyItem] {
        dirtyItems.filter { $0.projectID == projectID }
    }

    /// Get all dirty items across all projects.
    var allDirtyItems: Set<DirtyItem> { dirtyItems }

    /// Clear dirty flags for successfully pushed items.
    func clearDirty(_ items: Set<DirtyItem>) throws {
        dirtyItems.subtract(items)
        try save()
    }

    /// Clear all dirty flags (e.g. after sign-out).
    func clearAll() throws {
        dirtyItems.removeAll()
        try save()
    }

    private func save() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(dirtyItems)
        try data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Dirty Item

struct DirtyItem: Codable, Hashable, Sendable {
    let id: UUID
    let collection: SyncCollection
    let projectID: UUID
    var isDelete: Bool = false
}
