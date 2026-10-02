import EchoLocalStorage
import Foundation

actor LocalArchive {
    static let shared = LocalArchive()
    private let storage = EncryptedRecordStore.shared

    func load(collection: String, id: String = "archive", legacyURL: URL? = nil,
              legacyData: Data? = nil) async throws -> Data? {
        if let data = try await storage.read(collection: collection, id: id) {
            // A previous successful import may have stopped before source cleanup.
            if let legacyURL, FileManager.default.fileExists(atPath: legacyURL.path) {
                try FileManager.default.removeItem(at: legacyURL)
            }
            return data
        }
        let data: Data?
        if let legacyURL, FileManager.default.fileExists(atPath: legacyURL.path) {
            data = try Data(contentsOf: legacyURL)
        } else { data = legacyData }
        guard let data else { return nil }
        try await save(data, collection: collection, id: id)
        let authenticated = try await storage.read(collection: collection, id: id)
        guard authenticated == data else { throw LocalStorageError.invalidEnvelope }
        if let legacyURL, FileManager.default.fileExists(atPath: legacyURL.path) {
            try FileManager.default.removeItem(at: legacyURL)
        }
        return authenticated
    }

    func save(_ data: Data, collection: String, id: String = "archive") async throws {
        try await storage.write(LocalRecord(collection: collection, id: id, payload: data))
    }

    func remove(collection: String, id: String = "archive") async throws {
        try await storage.remove(collection: collection, id: id)
    }
}
