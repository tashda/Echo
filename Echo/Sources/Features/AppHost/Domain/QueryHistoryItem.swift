import Foundation

nonisolated struct QueryHistoryItem: Codable, Identifiable, Sendable {
    let id: UUID
    let query: String
    let timestamp: Date
    let connectionID: UUID?
    let databaseName: String?
    let resultCount: Int?
    let duration: TimeInterval?
    var outcome: String?
    var connectionName: String?

    init(id: UUID = UUID(), query: String, timestamp: Date, connectionID: UUID? = nil, databaseName: String? = nil, resultCount: Int? = nil, duration: TimeInterval? = nil) {
        self.id = id
        self.query = query
        self.timestamp = timestamp
        self.connectionID = connectionID
        self.databaseName = databaseName
        self.resultCount = resultCount
        self.duration = duration
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var formattedDuration: String? {
        guard let duration = duration else {
            return nil
        }
        return String(format: "%.3fs", duration)
    }
}
