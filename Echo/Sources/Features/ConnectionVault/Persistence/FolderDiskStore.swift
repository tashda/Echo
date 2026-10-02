import Foundation

actor FolderDiskStore {
    func load() async throws -> [SavedFolder] {
        try await LocalConfigurationArchive.load(SavedFolder.self, collection: "folders", filename: "folders.json")
    }

    func save(_ folders: [SavedFolder]) async throws {
        try await LocalConfigurationArchive.save(folders, collection: "folders")
    }
}
