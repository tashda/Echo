import Foundation
import Observation

/// A table the user opened from Echo (its data, structure or diagram), remembered per
/// connection and database for the empty query tab's starting points (QE6).
nonisolated struct RecentTable: Codable, Hashable, Sendable, Identifiable {
    let connectionID: UUID
    let databaseName: String?
    let schema: String
    let name: String
    var openedAt: Date

    var id: String {
        [connectionID.uuidString, databaseName ?? "", schema, name].map { $0.lowercased() }.joined(separator: "|")
    }

    /// A table recorded without a database belongs to every database of its connection.
    func belongs(toConnection connectionID: UUID, database: String?) -> Bool {
        guard self.connectionID == connectionID else { return false }
        guard let database, let databaseName else { return true }
        return databaseName.caseInsensitiveCompare(database) == .orderedSame
    }
}

/// The tables opened most recently, newest first, kept across launches in user defaults.
@Observable @MainActor
final class RecentTableStore {
    static let defaultsKey = "echo.recentTables"
    /// How many tables are remembered across all connections.
    static let capacity = 60

    private(set) var tables: [RecentTable]
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode([RecentTable].self, from: data) {
            tables = stored
        } else {
            tables = []
        }
    }

    func record(connectionID: UUID, databaseName: String?, schema: String, name: String, at date: Date = Date()) {
        let database = databaseName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let table = RecentTable(
            connectionID: connectionID,
            databaseName: database?.isEmpty == false ? database : nil,
            schema: schema,
            name: name,
            openedAt: date
        )
        tables.removeAll { $0.id == table.id }
        tables.insert(table, at: 0)
        if tables.count > Self.capacity {
            tables.removeLast(tables.count - Self.capacity)
        }
        save()
    }

    func recent(forConnection connectionID: UUID, database: String?, limit: Int) -> [RecentTable] {
        Array(tables.lazy.filter { $0.belongs(toConnection: connectionID, database: database) }.prefix(limit))
    }

    func forget(connectionID: UUID) {
        tables.removeAll { $0.connectionID == connectionID }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tables) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
