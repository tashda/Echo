import Foundation
import Testing
@testable import Echo

struct MetadataSearchEngineTests {

    // MARK: - Helpers

    private func makeSnapshot(
        name: String = "TestServer",
        databaseType: DatabaseType = .microsoftSQL,
        structure: DatabaseStructure? = nil
    ) -> MetadataSearchEngine.SessionSnapshot {
        MetadataSearchEngine.SessionSnapshot(
            sessionID: UUID(),
            serverName: name,
            databaseType: databaseType,
            structure: structure ?? DatabaseStructure(serverVersion: "", databases: [])
        )
    }

    private func sampleStructure() -> DatabaseStructure {
        DatabaseStructure(
            serverVersion: "16.0",
            databases: [
                DatabaseInfo(name: "sales", schemas: [
                    SchemaInfo(name: "dbo", objects: [
                        SchemaObjectInfo(name: "Customers", schema: "dbo", type: .table, columns: [
                            ColumnInfo(name: "CustomerID", dataType: "int"),
                            ColumnInfo(name: "Email", dataType: "nvarchar(255)")
                        ]),
                        SchemaObjectInfo(name: "Orders", schema: "dbo", type: .table),
                        SchemaObjectInfo(name: "GetCustomerOrders", schema: "dbo", type: .procedure),
                        SchemaObjectInfo(name: "ActiveCustomers", schema: "dbo", type: .view)
                    ])
                ]),
                DatabaseInfo(name: "analytics", schemas: [
                    SchemaInfo(name: "reporting", objects: [
                        SchemaObjectInfo(name: "DailyMetrics", schema: "reporting", type: .table),
                        SchemaObjectInfo(name: "CustomerReport", schema: "reporting", type: .view)
                    ])
                ])
            ]
        )
    }

    // MARK: - Basic Search

    @Test func searchReturnsEmptyForShortQuery() async {
        let snapshot = makeSnapshot(structure: sampleStructure())
        let results = await MetadataSearchEngine.search(
            query: "a",
            scope: .allServers,
            snapshots: [snapshot],
            categories: Set(SearchSidebarCategory.allCases)
        )
        #expect(results.isEmpty)
    }

    @Test func searchReturnsEmptyWithNoSessions() async {
        let results = await MetadataSearchEngine.search(
            query: "customers",
            scope: .allServers,
            snapshots: [],
            categories: Set(SearchSidebarCategory.allCases)
        )
        #expect(results.isEmpty)
    }

    @Test func searchFindsTableByName() async {
        let snapshot = makeSnapshot(structure: sampleStructure())
        let results = await MetadataSearchEngine.search(
            query: "customers",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.tables]
        )
        #expect(results.count == 1)
        #expect(results.first?.title == "dbo.Customers")
        #expect(results.first?.category == .tables)
    }

    @Test func searchFindsViewByName() async {
        let snapshot = makeSnapshot(structure: sampleStructure())
        let results = await MetadataSearchEngine.search(
            query: "active",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.views]
        )
        #expect(results.count == 1)
        #expect(results.first?.title == "dbo.ActiveCustomers")
    }

    @Test func searchFindsProcedureByName() async {
        let snapshot = makeSnapshot(structure: sampleStructure())
        let results = await MetadataSearchEngine.search(
            query: "GetCustomer",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.procedures]
        )
        #expect(results.count == 1)
        #expect(results.first?.title == "dbo.GetCustomerOrders")
    }

    @Test func searchFindsColumnByName() async {
        let snapshot = makeSnapshot(structure: sampleStructure())
        let results = await MetadataSearchEngine.search(
            query: "email",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.columns]
        )
        #expect(results.count == 1)
        #expect(results.first?.title == "Email")
        #expect(results.first?.subtitle == "dbo.Customers")
        #expect(results.first?.metadata == "nvarchar(255)")
    }

    @Test func searchIsCaseInsensitive() async {
        let snapshot = makeSnapshot(structure: sampleStructure())
        let results = await MetadataSearchEngine.search(
            query: "ORDERS",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.tables]
        )
        #expect(results.count == 1)
        #expect(results.first?.title == "dbo.Orders")
    }

    // MARK: - Category Filtering

    @Test func searchRespectsCategories() async {
        let snapshot = makeSnapshot(structure: sampleStructure())

        // "Customer" matches tables, views, and procedures
        let tablesOnly = await MetadataSearchEngine.search(
            query: "customer",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.tables]
        )
        let allCategories = await MetadataSearchEngine.search(
            query: "customer",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.tables, .views, .procedures, .columns]
        )

        #expect(tablesOnly.count < allCategories.count)
        #expect(tablesOnly.allSatisfy { $0.category == .tables })
    }

    // MARK: - Multi-Session Search

    @Test func searchAcrossMultipleSessions() async {
        let snapshot1 = makeSnapshot(name: "Server1", structure: sampleStructure())
        let snapshot2 = makeSnapshot(name: "Server2", structure: DatabaseStructure(
            serverVersion: "15.0",
            databases: [
                DatabaseInfo(name: "inventory", schemas: [
                    SchemaInfo(name: "dbo", objects: [
                        SchemaObjectInfo(name: "CustomerInventory", schema: "dbo", type: .table)
                    ])
                ])
            ]
        ))

        let results = await MetadataSearchEngine.search(
            query: "customer",
            scope: .allServers,
            snapshots: [snapshot1, snapshot2],
            categories: [.tables]
        )

        let serverNames = Set(results.map(\.serverName))
        #expect(serverNames.contains("Server1"))
        #expect(serverNames.contains("Server2"))
        #expect(results.count >= 2) // At least Customers from Server1 and CustomerInventory from Server2
    }

    // MARK: - Scope Filtering

    @Test func scopeFiltersByServer() async {
        let snapshot1 = makeSnapshot(name: "Server1", structure: sampleStructure())
        let snapshot2 = makeSnapshot(name: "Server2", structure: DatabaseStructure(
            serverVersion: "15.0",
            databases: [
                DatabaseInfo(name: "other", schemas: [
                    SchemaInfo(name: "dbo", objects: [
                        SchemaObjectInfo(name: "Orders", schema: "dbo", type: .table)
                    ])
                ])
            ]
        ))

        let results = await MetadataSearchEngine.search(
            query: "orders",
            scope: .server(connectionSessionID: snapshot1.sessionID),
            snapshots: [snapshot1, snapshot2],
            categories: [.tables]
        )

        #expect(results.allSatisfy { $0.connectionSessionID == snapshot1.sessionID })
        #expect(results.count == 1)
    }

    @Test func scopeFiltersByDatabase() async {
        let snapshot = makeSnapshot(structure: sampleStructure())

        let allResults = await MetadataSearchEngine.search(
            query: "report",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.tables, .views]
        )

        let scopedResults = await MetadataSearchEngine.search(
            query: "report",
            scope: .database(connectionSessionID: snapshot.sessionID, databaseName: "analytics"),
            snapshots: [snapshot],
            categories: [.tables, .views]
        )

        // "report" matches CustomerReport in analytics only
        #expect(scopedResults.count <= allResults.count)
        #expect(scopedResults.allSatisfy { $0.databaseName == "analytics" })
    }

    // MARK: - Provenance

    @Test func resultsHaveCorrectProvenance() async {
        let snapshot = makeSnapshot(name: "MyServer", structure: sampleStructure())
        let results = await MetadataSearchEngine.search(
            query: "daily",
            scope: .allServers,
            snapshots: [snapshot],
            categories: [.tables]
        )

        #expect(results.count == 1)
        let result = results[0]
        #expect(result.serverName == "MyServer")
        #expect(result.databaseName == "analytics")
        #expect(result.connectionSessionID == snapshot.sessionID)
        #expect(result.title == "reporting.DailyMetrics")
    }
}
