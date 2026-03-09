import Foundation
@testable import Echo

final class MockHistoryRepository: HistoryRepositoryProtocol, @unchecked Sendable {
    // MARK: - In-Memory Storage

    var records: [RecentConnectionRecord] = []

    // MARK: - Call Tracking

    var loadCallCount = 0
    var saveCallCount = 0

    // MARK: - HistoryRepositoryProtocol

    func loadRecentConnections() -> [RecentConnectionRecord] {
        loadCallCount += 1
        return records.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    func saveRecentConnections(_ records: [RecentConnectionRecord]) {
        saveCallCount += 1
        let sorted = records.sorted { $0.lastUsedAt > $1.lastUsedAt }
        self.records = Array(sorted.prefix(20))
    }
}
