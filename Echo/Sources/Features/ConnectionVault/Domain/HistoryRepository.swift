import Synchronization
import EchoLocalStorage
import OSLog
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

final class HistoryRepository: HistoryRepositoryProtocol {
    private struct State { var records: [RecentConnectionRecord] = []; var revision: UInt64 = 0; var available = true }
    private let state = Mutex(State())

    func hydrate() async throws {
        do {
            let data = try await LocalArchive.shared.load(collection: "recent-connections",
                legacyData: EncryptedRecordStore.isTestHost ? nil : UserDefaults.standard.data(forKey: "recentConnections"))
            let stored = try data.map { try JSONDecoder().decode([RecentConnectionRecord].self, from: $0) } ?? []
            state.withLock { $0.records = stored }
            if !EncryptedRecordStore.isTestHost { UserDefaults.standard.removeObject(forKey: "recentConnections") }
        } catch { state.withLock { $0.available = false }; throw error }
    }

    func loadRecentConnections() -> [RecentConnectionRecord] { state.withLock { $0.records } }
    func loadRecentConnections(forProjectID projectID: UUID) -> [RecentConnectionRecord] {
        loadRecentConnections().filter { $0.projectID == projectID }
    }
    func saveRecentConnections(_ records: [RecentConnectionRecord]) {
        let (snapshot, revision, available) = state.withLock { state in
            state.records = Array(records.sorted { $0.lastUsedAt > $1.lastUsedAt }.prefix(20))
            state.revision += 1
            return (state.records, state.revision, state.available)
        }
        guard available else { return }
        Task(name: "Save encrypted recent connections") {
            do {
                try await LocalArchive.shared.saveVersioned(LocalRecordEncoding.encode(snapshot), collection: "recent-connections", revision: revision)
            } catch { Logger(subsystem: "dev.echodb.echo", category: "local-storage").error("Couldn't save recent connections: \(error.localizedDescription)") }
        }
    }
}
