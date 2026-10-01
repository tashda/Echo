import Foundation

/// A test server from `.echo-automation/config.json`, the same file Echo's automation mode reads.
struct LabConnectionProfile: Codable, Identifiable, Hashable {
    var name: String
    var type: String
    var host: String
    var port: Int?
    var database: String?
    var username: String?
    var password: String?
    var useTLS: Bool?
    var trustServerCertificate: Bool?

    var id: String { name }
    var isSQLServer: Bool { type == "mssql" }
    var isPostgres: Bool { type == "postgresql" }

    private struct File: Codable { var connections: [LabConnectionProfile] }

    /// `<repo>/.echo-automation/config.json`, found from this file's place in the checkout.
    static var configURL: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url.appending(path: ".echo-automation/config.json")
    }

    static func load() -> [LabConnectionProfile] {
        guard let data = try? Data(contentsOf: configURL),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.connections.filter { $0.isSQLServer || $0.isPostgres }
    }
}
