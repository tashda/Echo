import Foundation

/// Persists sync checkpoints per project to disk.
///
/// Each checkpoint records the last server HLC that was successfully pulled,
/// allowing subsequent pulls to fetch only new changes.
actor SyncCheckpointStore {
    private let fileURL: URL
    private var checkpoints: [UUID: SyncCheckpoint] = [:]

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let echoDir = appSupport.appendingPathComponent("Echo", isDirectory: true)
        self.fileURL = echoDir.appendingPathComponent("sync_checkpoints.json")
    }

    func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder().decode([SyncCheckpoint].self, from: data)
        checkpoints = Dictionary(uniqueKeysWithValues: decoded.map { ($0.projectID, $0) })
    }

    func checkpoint(for projectID: UUID) -> UInt64 {
        checkpoints[projectID]?.checkpoint ?? 0
    }

    func hasCheckpoint(for projectID: UUID) -> Bool {
        checkpoints[projectID] != nil
    }

    func update(projectID: UUID, checkpoint: UInt64) throws {
        checkpoints[projectID] = SyncCheckpoint(
            projectID: projectID,
            checkpoint: checkpoint,
            lastSyncedAt: Date()
        )
        try save()
    }

    func clearAll() throws {
        checkpoints.removeAll()
        try save()
    }

    private func save() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(Array(checkpoints.values))
        try data.write(to: fileURL, options: .atomic)
    }
}
