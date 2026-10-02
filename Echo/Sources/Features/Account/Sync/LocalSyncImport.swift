import Foundation

/// Retires this Mac's old sync files even while signed out; imports only into their original account.
enum LocalSyncImport {
    static func preserveLegacyState() async throws {
        if let previous = UserDefaults.standard.string(forKey: "sync.lastUserID") {
            try await LocalArchive.shared.save(Data(previous.lowercased().utf8), collection: "legacy-sync-account")
            UserDefaults.standard.removeObject(forKey: "sync.lastUserID")
        }
        _ = try await LocalArchive.shared.load(collection: "legacy-sync-dirty", legacyURL: LocalConfigurationArchive.legacyURL("sync_dirty.json"))
        _ = try await LocalArchive.shared.load(collection: "legacy-sync-checkpoints", legacyURL: LocalConfigurationArchive.legacyURL("sync_checkpoints.json"))
    }

    static func originalAccount() async throws -> String? {
        guard let data = try await LocalArchive.shared.load(collection: "legacy-sync-account") else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
