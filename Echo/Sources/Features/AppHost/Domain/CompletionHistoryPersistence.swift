import EchoSense
import Foundation

/// Completion ranking stays synchronous; its disk snapshots use Echo's encrypted local store.
actor CompletionHistoryPersistence: SQLHistoryPersistence {
    static let shared = CompletionHistoryPersistence()
    private var latestRevision: UInt64 = 0

    func save(_ data: Data, revision: UInt64) async throws {
        guard revision >= latestRevision else { return }
        latestRevision = revision
        try await LocalArchive.shared.save(data, collection: "completion-history")
    }

    func load() async throws {
        let history = SQLAutoCompletionHistoryStore.shared
        let url = LocalConfigurationArchive.legacyURL("AutocompleteHistory/history.json")
        if let data = try await LocalArchive.shared.load(collection: "completion-history", legacyURL: url) {
            history.importSnapshot(try JSONDecoder().decode(SQLAutoCompletionHistoryStore.Snapshot.self, from: data))
        }
        history.setPersistence(self)
    }
}
