import Foundation
import Testing
@testable import Echo

@Suite("Metadata cache failure preservation")
struct MetadataCacheFailureTests {
    @Test func mysqlSchemaFailureIsNotASuccessfulEmptyDatabase() async throws {
        let session = MockDatabaseSession()
        session.loadSchemaInfoHandler = { _, _ in throw DatabaseError.connectionFailed("offline") }
        let connection = SavedConnection(connectionName: "MySQL", host: "localhost", port: 3306, database: "shop", username: "test", databaseType: .mysql)
        do {
            _ = try await MySQLStructureFetcher(session: session).fetchStructure(for: connection,
                credentials: .init(authentication: DatabaseAuthenticationConfiguration(username: "test", password: "")), selectedDatabase: "shop",
                reuseSession: session, databaseFilter: nil, cachedStructure: nil,
                progressHandler: { _ in }, databaseHandler: { _, _, _ in })
            Issue.record("Failed metadata must throw so it cannot replace the cache with an empty database")
        } catch {}
    }

    @Test func databaseAndUsernameCaseScopeTheCache() {
        let connection = SavedConnection(connectionName: "Postgres", host: "db.local", port: 5432,
            database: "Sales", username: "CaseSensitiveUser", databaseType: .postgresql)
        var changed = connection
        changed.database = "sales"
        #expect(connection.objectBrowserCacheFingerprint != changed.objectBrowserCacheFingerprint)
        changed = connection
        changed.username = "casesensitiveuser"
        #expect(connection.objectBrowserCacheFingerprint != changed.objectBrowserCacheFingerprint)
    }
}
