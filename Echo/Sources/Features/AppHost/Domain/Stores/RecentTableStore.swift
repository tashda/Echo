import Foundation
import EchoLocalStorage
import OSLog
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
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var revision: UInt64 = 0
    @ObservationIgnored private var forgottenConnections: Set<UUID> = []
    @ObservationIgnored private var available = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults !== UserDefaults.standard, let data = defaults.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode([RecentTable].self, from: data) {
            tables = stored
        } else {
            tables = []
        }
        if defaults === UserDefaults.standard {
            loadTask = Task(name: "Load encrypted recent tables") {
                do {
                    if let data = try await LocalArchive.shared.load(collection: "recent-tables", legacyData: EncryptedRecordStore.isTestHost ? nil : defaults.data(forKey: Self.defaultsKey)) {
                        let stored = try JSONDecoder().decode([RecentTable].self, from: data)
                        let ids = Set(tables.map(\.id))
                        tables += stored.filter { !ids.contains($0.id) && !forgottenConnections.contains($0.connectionID) }
                        tables = Array(tables.sorted { $0.openedAt > $1.openedAt }.prefix(Self.capacity))
                    }
                    if !EncryptedRecordStore.isTestHost { defaults.removeObject(forKey: Self.defaultsKey) }
                } catch {
                    available = false
                    Logger(subsystem: "dev.echodb.echo", category: "local-storage").error("Recent tables are unavailable: \(error.localizedDescription)")
                }
            }
        }
    }

    func finishLoading() async { await loadTask?.value }

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
        forgottenConnections.insert(connectionID)
        tables.removeAll { $0.connectionID == connectionID }
        save()
    }

    private func save() {
        guard defaults === UserDefaults.standard else {
            if let data = try? LocalRecordEncoding.encode(tables) { defaults.set(data, forKey: Self.defaultsKey) }
            return
        }
        revision += 1
        let generation = revision
        Task(name: "Save encrypted recent tables") {
            await loadTask?.value
            guard available else { return }
            do { try await LocalArchive.shared.saveVersioned(LocalRecordEncoding.encode(tables), collection: "recent-tables", revision: generation) }
            catch { Logger(subsystem: "dev.echodb.echo", category: "local-storage").error("Couldn't save recent tables: \(error.localizedDescription)") }
        }
    }
}
