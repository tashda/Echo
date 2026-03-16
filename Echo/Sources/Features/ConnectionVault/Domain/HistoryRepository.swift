import Foundation

struct RecentConnectionRecord: Codable, Identifiable, Equatable, Sendable {
    let id: UUID // This is the connection ID
    let connectionName: String
    let host: String
    let databaseName: String?
    let username: String?
    let databaseType: DatabaseType
    let colorHex: String?
    let lastUsedAt: Date
    var projectID: UUID?

    var identifier: String {
        let databaseComponent = databaseName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let userComponent = username?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return "\(id.uuidString)|\(databaseComponent)|\(userComponent)"
    }
}

protocol HistoryRepositoryProtocol: Sendable {
    func loadRecentConnections() -> [RecentConnectionRecord]
    func loadRecentConnections(forProjectID projectID: UUID) -> [RecentConnectionRecord]
    func saveRecentConnections(_ records: [RecentConnectionRecord])
}

final class HistoryRepository: HistoryRepositoryProtocol, @unchecked Sendable {
    private let userDefaults = UserDefaults.standard
    private let recentConnectionsKey = "recentConnections"
    private let maxRecords = 20
    
    func loadRecentConnections() -> [RecentConnectionRecord] {
        guard let data = userDefaults.data(forKey: recentConnectionsKey),
              let records = try? JSONDecoder().decode([RecentConnectionRecord].self, from: data) else {
            return []
        }
        return records
    }

    func loadRecentConnections(forProjectID projectID: UUID) -> [RecentConnectionRecord] {
        loadRecentConnections().filter { $0.projectID == projectID }
    }
    
    func saveRecentConnections(_ records: [RecentConnectionRecord]) {
        let sorted = records.sorted { $0.lastUsedAt > $1.lastUsedAt }
        let limited = Array(sorted.prefix(maxRecords))
        if let data = try? JSONEncoder().encode(limited) {
            userDefaults.set(data, forKey: recentConnectionsKey)
        }
    }
}
