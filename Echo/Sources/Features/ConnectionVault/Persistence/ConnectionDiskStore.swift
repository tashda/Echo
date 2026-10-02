import EchoLocalStorage
import Foundation

actor ConnectionDiskStore {
    func load() async throws -> [SavedConnection] {
        try await LocalConfigurationArchive.load(SavedConnection.self, collection: "connections", filename: "connections.json")
    }

    func save(_ connections: [SavedConnection]) async throws {
        let records = try connections.enumerated().map { position, connection in
            var configuration = connection
            configuration.cachedStructure = nil
            configuration.cachedStructureUpdatedAt = nil
            return LocalRecord(collection: "connections", id: connection.id.uuidString,
                               group: connection.projectID?.uuidString,
                               payload: try LocalRecordEncoding.encode(configuration), position: position)
        }
        try await EncryptedRecordStore.shared.replace(collection: "connections", with: records)
    }
}
