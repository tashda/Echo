import EchoLocalStorage
import Foundation

/// A small one-time importer for this development installation. New installs use SQLite directly.
enum LocalConfigurationArchive {
    static let storage = EncryptedRecordStore.shared

    static func legacyURL(_ filename: String) -> URL {
        EncryptedRecordStore.defaultURL.deletingLastPathComponent().appendingPathComponent(filename)
    }

    static func load<Value: Codable & Sendable & Identifiable>(
        _ type: Value.Type, collection: String, filename: String
    ) async throws -> [Value] where Value.ID == UUID {
        if !(try await storage.hasMigration(collection)) {
            let url = legacyURL(filename)
            if FileManager.default.fileExists(atPath: url.path) {
                let values = try await decodeLegacy([Value].self, url: url)
                if let connections = values as? [SavedConnection] {
                    // Metadata is imported separately from fingerprinted ObjectBrowserCache files.
                    try await ConnectionDiskStore().save(connections)
                } else {
                    try await save(values, collection: collection)
                }
                _ = try await storage.records(collection: collection)
                try await storage.finishMigration(collection)
                try FileManager.default.removeItem(at: url)
            } else {
                try await storage.finishMigration(collection)
            }
        }
        return try await storage.records(collection: collection).map {
            try JSONDecoder().decode(Value.self, from: $0.payload)
        }
    }

    static func save<Value: Codable & Sendable & Identifiable>(
        _ values: [Value], collection: String
    ) async throws where Value.ID == UUID {
        let records = try values.enumerated().map { position, value in
            LocalRecord(collection: collection, id: value.id.uuidString,
                        group: (value as? SavedFolder)?.projectID?.uuidString ?? (value as? SavedIdentity)?.projectID?.uuidString ?? (value as? Project)?.id.uuidString,
                        payload: try LocalRecordEncoding.encode(value), position: position)
        }
        try await storage.replace(collection: collection, with: records)
    }

    @concurrent private static func decodeLegacy<Value: Decodable & Sendable>(
        _ type: Value.Type, url: URL
    ) async throws -> Value {
        try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
}
