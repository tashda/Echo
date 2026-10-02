import EchoLocalStorage
import Foundation

actor SyncCheckpointStore {
    private let storage: EncryptedRecordStore
    private var account = ""
    init(storage: EncryptedRecordStore = .shared) { self.storage = storage }
    func setAccount(_ account: String) { self.account = account }
    func load() async throws {
        _ = try await storage.encryptionContext()
        let url = LocalConfigurationArchive.legacyURL("sync_checkpoints.json")
        if FileManager.default.fileExists(atPath: url.path) {
            let checkpoints = try JSONDecoder().decode([SyncCheckpoint].self, from: Data(contentsOf: url))
            for checkpoint in checkpoints { try await update(projectID: checkpoint.projectID, checkpoint: checkpoint.checkpoint) }
            try FileManager.default.removeItem(at: url)
        }
    }

    func checkpoint(for projectID: UUID) async -> UInt64 {
        guard let record = try? await storage.read(collection: "sync-checkpoints", id: identifier(projectID)),
              let checkpoint = try? JSONDecoder().decode(SyncCheckpoint.self, from: record) else { return 0 }
        return checkpoint.checkpoint
    }
    func hasCheckpoint(for projectID: UUID) async -> Bool {
        (try? await storage.read(collection: "sync-checkpoints", id: identifier(projectID))) != nil
    }
    func record(projectID: UUID, checkpoint: UInt64) async throws -> LocalRecord {
        LocalRecord(collection: "sync-checkpoints", id: try await identifier(projectID),
            group: try await storage.opaqueIdentifier(account), payload: try LocalRecordEncoding.encode(
                SyncCheckpoint(projectID: projectID, checkpoint: checkpoint, lastSyncedAt: Date())))
    }
    func update(projectID: UUID, checkpoint: UInt64) async throws {
        try await storage.write(record(projectID: projectID, checkpoint: checkpoint))
    }
    func clearAll() async throws {
        try await storage.remove(collection: "sync-checkpoints", group: storage.opaqueIdentifier(account))
    }
    private func identifier(_ projectID: UUID) async throws -> String {
        try await storage.opaqueIdentifier("checkpoint:\(account):\(projectID)")
    }
}
