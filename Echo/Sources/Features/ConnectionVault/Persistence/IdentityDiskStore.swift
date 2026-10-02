import Foundation

actor IdentityDiskStore {
    func load() async throws -> [SavedIdentity] {
        try await LocalConfigurationArchive.load(SavedIdentity.self, collection: "identities", filename: "identities.json")
    }

    func save(_ identities: [SavedIdentity]) async throws {
        try await LocalConfigurationArchive.save(identities, collection: "identities")
    }
}
