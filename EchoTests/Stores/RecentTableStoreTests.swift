import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Recent tables (QE6)")
struct RecentTableStoreTests {
    private let connection = UUID()
    private let otherConnection = UUID()

    private func makeDefaults() -> UserDefaults {
        let suite = "RecentTableStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func newestTableComesFirstAndReopeningMovesItUp() {
        let store = RecentTableStore(defaults: makeDefaults())
        store.record(connectionID: connection, databaseName: "shop", schema: "dbo", name: "Orders", at: Date(timeIntervalSince1970: 1))
        store.record(connectionID: connection, databaseName: "shop", schema: "dbo", name: "Customers", at: Date(timeIntervalSince1970: 2))
        store.record(connectionID: connection, databaseName: "Shop", schema: "DBO", name: "orders", at: Date(timeIntervalSince1970: 3))

        let names = store.recent(forConnection: connection, database: "shop", limit: 10).map(\.name)
        #expect(names == ["orders", "Customers"])
    }

    @Test func tablesStayWithTheirConnectionAndDatabase() {
        let store = RecentTableStore(defaults: makeDefaults())
        store.record(connectionID: connection, databaseName: "shop", schema: "dbo", name: "Orders")
        store.record(connectionID: connection, databaseName: "hr", schema: "dbo", name: "People")
        store.record(connectionID: otherConnection, databaseName: "shop", schema: "dbo", name: "Elsewhere")
        store.record(connectionID: connection, databaseName: nil, schema: "main", name: "Everywhere")

        #expect(store.recent(forConnection: connection, database: "shop", limit: 10).map(\.name) == ["Everywhere", "Orders"])
        #expect(store.recent(forConnection: connection, database: "hr", limit: 10).map(\.name) == ["Everywhere", "People"])
        #expect(store.recent(forConnection: connection, database: nil, limit: 10).count == 3)
        #expect(store.recent(forConnection: connection, database: "shop", limit: 1).map(\.name) == ["Everywhere"])
    }

    @Test func blankDatabaseIsStoredAsNone() {
        let store = RecentTableStore(defaults: makeDefaults())
        store.record(connectionID: connection, databaseName: "  ", schema: "public", name: "t")
        #expect(store.tables.first?.databaseName == nil)
    }

    @Test func tablesSurviveARelaunch() {
        let defaults = makeDefaults()
        RecentTableStore(defaults: defaults).record(connectionID: connection, databaseName: "shop", schema: "dbo", name: "Orders")
        let reloaded = RecentTableStore(defaults: defaults)
        #expect(reloaded.tables.map(\.name) == ["Orders"])
    }

    @Test func storeKeepsOnlyItsCapacity() {
        let store = RecentTableStore(defaults: makeDefaults())
        for index in 0..<(RecentTableStore.capacity + 5) {
            store.record(connectionID: connection, databaseName: "shop", schema: "dbo", name: "t\(index)")
        }
        #expect(store.tables.count == RecentTableStore.capacity)
        #expect(store.tables.first?.name == "t\(RecentTableStore.capacity + 4)")
    }

    @Test func forgettingAConnectionDropsOnlyItsTables() {
        let store = RecentTableStore(defaults: makeDefaults())
        store.record(connectionID: connection, databaseName: "shop", schema: "dbo", name: "Orders")
        store.record(connectionID: otherConnection, databaseName: "shop", schema: "dbo", name: "Kept")
        store.forget(connectionID: connection)
        #expect(store.tables.map(\.name) == ["Kept"])
    }
}
