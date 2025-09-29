import Foundation

actor FolderStore {
    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let appSupport = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("fuzee", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        fileURL = dir.appendingPathComponent("folders.json")
    }

    func load() async throws -> [SavedFolder] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([SavedFolder].self, from: data)
    }

    func save(_ folders: [SavedFolder]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(folders)
        try data.write(to: fileURL, options: [.atomic])
    }
}
