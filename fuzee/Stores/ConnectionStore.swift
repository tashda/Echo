import Foundation

actor ConnectionStore {
    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let appSupport = try! fm.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil,
                                     create: true)
        let dir = appSupport.appendingPathComponent("fuzee", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.fileURL = dir.appendingPathComponent("connections.json")
    }

    func load() async throws -> [SavedConnection] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([SavedConnection].self, from: data)
    }

    func save(_ connections: [SavedConnection]) async throws {
        let data = try JSONEncoder().encode(connections)
        try data.write(to: fileURL, options: [.atomic])
    }
}

