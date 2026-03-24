import Foundation
import Testing
@testable import Echo

@MainActor
struct MetadataSearchEngineTests {

    // MARK: - Helpers

    private func makeSpoolManager() -> ResultSpooler {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MetadataSearchTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let configuration = ResultSpoolConfiguration.defaultConfiguration(rootDirectory: tempRoot)
        return ResultSpooler(configuration: configuration)
    }

    private func makeSession(
        name: String = "TestServer",
        database: String = "testdb",
        databaseType: DatabaseType = .microsoftSQL,
        structure: DatabaseStructure? = nil
    ) -> ConnectionSession {
        let connection = TestFixtures.savedConnection(
            connectionName: name,
            database: database,
            databaseType: databaseType
        )
        let session = ConnectionSession(
            connection: connection,
            session: MockDatabaseSession(),
            spoolManager: makeSpoolManager()
        )
        session.databaseStructure = structure
        return session
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

    @Test func searchReturnsEmptyForShortQuery() {
        let session = makeSession(structure: sampleStructure())
        let results = MetadataSearchEngine.search(
            query: "a",
            scope: .allServers,
            sessions: [session],
            categories: Set(SearchSidebarCategory.allCases)
        )
        #expect(results.isEmpty)
    }

    @Test func searchReturnsEmptyWithNoSessions() {
        let results = MetadataSearchEngine.search(
            query: "customers",
            scope: .allServers,
            sessions: [],
            categories: Set(SearchSidebarCategory.allCases)
        )
        #expect(results.isEmpty)
    }

    @Test func searchFindsTableByName() {
        let session = makeSession(structure: sampleStructure())
        let results = MetadataSearchEngine.search(
            query: "customers",
            scope: .allServers,
            sessions: [session],
            categories: [.tables]
        )
        #expect(results.count == 1)
        #expect(results.first?.title == "dbo.Customers")
        #expect(results.first?.category == .tables)
    }

    @Test func searchFindsViewByName() {
        let session = makeSession(structure: sampleStructure())
        let results = MetadataSearchEngine.search(
            query: "active",
            scope: .allServers,
            sessions: [session],
            categories: [.views]
        )
        #expect(results.count == 1)
        #expect(results.first?.title == "dbo.ActiveCustomers")
    }

    @Test func searchFindsProcedureByName() {
        let session = makeSession(structure: sampleStructure())
        let results = MetadataSearchEngine.search(
            query: "GetCustomer",
            scope: .allServers,
            sessions: [session],
            categories: [.procedures]
        )
        #expect(results.count == 1)
        #expect(results.first?.title == "dbo.GetCustomerOrders")
    }

    @Test func searchFindsColumnByName() {
        let session = makeSession(structure: sampleStructure())
        let results = MetadataSearchEngine.search(
            query: "email",
            scope: .allServers,
            sessions: [session],
            categories: [.columns]
        )
        #expect(results.count == 1)
        #expect(results.first?.title == "Email")
        #expect(results.first?.subtitle == "dbo.Customers")
        #expect(results.first?.metadata == "nvarchar(255)")
    }

    @Test func searchIsCaseInsensitive() {
        let session = makeSession(structure: sampleStructure())
        let results = MetadataSearchEngine.search(
            query: "ORDERS",
            scope: .allServers,
            sessions: [session],
            categories: [.tables]
        )
        #expect(results.count == 1)
        #expect(results.first?.title == "dbo.Orders")
    }

    // MARK: - Category Filtering

    @Test func searchRespectsCategories() {
        let session = makeSession(structure: sampleStructure())

        // "Customer" matches tables, views, and procedures
        let tablesOnly = MetadataSearchEngine.search(
            query: "customer",
            scope: .allServers,
            sessions: [session],
            categories: [.tables]
        )
        let allCategories = MetadataSearchEngine.search(
            query: "customer",
            scope: .allServers,
            sessions: [session],
            categories: [.tables, .views, .procedures, .columns]
        )

        #expect(tablesOnly.count < allCategories.count)
        #expect(tablesOnly.allSatisfy { $0.category == .tables })
    }

    // MARK: - Multi-Session Search

    @Test func searchAcrossMultipleSessions() {
        let session1 = makeSession(name: "Server1", structure: sampleStructure())
        let session2 = makeSession(name: "Server2", structure: DatabaseStructure(
            serverVersion: "15.0",
            databases: [
                DatabaseInfo(name: "inventory", schemas: [
                    SchemaInfo(name: "dbo", objects: [
                        SchemaObjectInfo(name: "CustomerInventory", schema: "dbo", type: .table)
                    ])
                ])
            ]
        ))

        let results = MetadataSearchEngine.search(
            query: "customer",
            scope: .allServers,
            sessions: [session1, session2],
            categories: [.tables]
        )

        let serverNames = Set(results.map(\.serverName))
        #expect(serverNames.contains("Server1"))
        #expect(serverNames.contains("Server2"))
        #expect(results.count >= 2) // At least Customers from Server1 and CustomerInventory from Server2
    }

    // MARK: - Scope Filtering

    @Test func scopeFiltersByServer() {
        let session1 = makeSession(name: "Server1", structure: sampleStructure())
        let session2 = makeSession(name: "Server2", structure: DatabaseStructure(
            serverVersion: "15.0",
            databases: [
                DatabaseInfo(name: "other", schemas: [
                    SchemaInfo(name: "dbo", objects: [
                        SchemaObjectInfo(name: "Orders", schema: "dbo", type: .table)
                    ])
                ])
            ]
        ))

        let results = MetadataSearchEngine.search(
            query: "orders",
            scope: .server(connectionSessionID: session1.id),
            sessions: [session1, session2],
            categories: [.tables]
        )

        #expect(results.allSatisfy { $0.connectionSessionID == session1.id })
        #expect(results.count == 1)
    }

    @Test func scopeFiltersByDatabase() {
        let session = makeSession(structure: sampleStructure())

        let allResults = MetadataSearchEngine.search(
            query: "report",
            scope: .allServers,
            sessions: [session],
            categories: [.tables, .views]
        )

        let scopedResults = MetadataSearchEngine.search(
            query: "report",
            scope: .database(connectionSessionID: session.id, databaseName: "analytics"),
            sessions: [session],
            categories: [.tables, .views]
        )

        // "report" matches CustomerReport in analytics only
        #expect(scopedResults.count <= allResults.count)
        #expect(scopedResults.allSatisfy { $0.databaseName == "analytics" })
    }

    // MARK: - Provenance

    @Test func resultsHaveCorrectProvenance() {
        let session = makeSession(name: "MyServer", structure: sampleStructure())
        let results = MetadataSearchEngine.search(
            query: "daily",
            scope: .allServers,
            sessions: [session],
            categories: [.tables]
        )

        #expect(results.count == 1)
        let result = results[0]
        #expect(result.serverName == "MyServer")
        #expect(result.databaseName == "analytics")
        #expect(result.connectionSessionID == session.id)
        #expect(result.title == "reporting.DailyMetrics")
    }
}
