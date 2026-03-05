import XCTest
@testable import Echo

final class HistoryRepositoryTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "HistoryRepositoryTests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Using Mock Repository (In-Memory)

    func testSaveAndLoadRoundTrip() {
        let repo = MockHistoryRepository()
        let record = RecentConnectionRecord(
            id: UUID(),
            connectionName: "Prod",
            host: "db.example.com",
            databaseName: "production",
            databaseType: .postgresql,
            colorHex: "FF0000",
            lastUsedAt: Date()
        )

        repo.saveRecentConnections([record])
        let loaded = repo.loadRecentConnections()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].connectionName, "Prod")
    }

    func testSortsByLastUsedAtDescending() {
        let repo = MockHistoryRepository()
        let older = RecentConnectionRecord(
            id: UUID(), connectionName: "Old", host: "h", databaseName: nil,
            databaseType: .postgresql, colorHex: nil,
            lastUsedAt: Date().addingTimeInterval(-100)
        )
        let newer = RecentConnectionRecord(
            id: UUID(), connectionName: "New", host: "h", databaseName: nil,
            databaseType: .postgresql, colorHex: nil,
            lastUsedAt: Date()
        )

        repo.saveRecentConnections([older, newer])
        let loaded = repo.loadRecentConnections()

        XCTAssertEqual(loaded[0].connectionName, "New")
        XCTAssertEqual(loaded[1].connectionName, "Old")
    }

    func testTrimsTo20Entries() {
        let repo = MockHistoryRepository()
        var records: [RecentConnectionRecord] = []
        for i in 0..<25 {
            records.append(RecentConnectionRecord(
                id: UUID(), connectionName: "C\(i)", host: "h", databaseName: nil,
                databaseType: .postgresql, colorHex: nil,
                lastUsedAt: Date().addingTimeInterval(Double(i))
            ))
        }

        repo.saveRecentConnections(records)
        let loaded = repo.loadRecentConnections()

        XCTAssertEqual(loaded.count, 20)
    }

    func testRecordIdentifier() {
        let id = UUID()
        let record = RecentConnectionRecord(
            id: id, connectionName: "Test", host: "localhost",
            databaseName: "MyDB", databaseType: .postgresql,
            colorHex: nil, lastUsedAt: Date()
        )

        XCTAssertEqual(record.identifier, "\(id.uuidString)|mydb")
    }

    func testRecordIdentifierWithNilDatabase() {
        let id = UUID()
        let record = RecentConnectionRecord(
            id: id, connectionName: "Test", host: "localhost",
            databaseName: nil, databaseType: .postgresql,
            colorHex: nil, lastUsedAt: Date()
        )

        XCTAssertEqual(record.identifier, "\(id.uuidString)|")
    }
}
