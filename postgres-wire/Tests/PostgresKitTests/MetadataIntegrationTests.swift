@testable import PostgresKit
import XCTest
import Logging

final class MetadataIntegrationTests: XCTestCase {
    var client: PostgresDatabaseClient!

    override func setUp() async throws {
        TestEnv.loadDotEnv()
        // Only run when explicitly enabled to avoid hanging CI/dev if no DB is available
        if (ProcessInfo.processInfo.environment["POSTGRES_INTEGRATION"] ?? "") != "1" {
            throw XCTSkip("Integration tests disabled; set POSTGRES_INTEGRATION=1 in .env to enable")
        }
        let logger = Logger(label: "postgres-kit-tests")
        let config = PostgresConfiguration(
            host: TestEnv.host,
            port: TestEnv.port,
            database: TestEnv.database,
            username: TestEnv.username,
            password: TestEnv.password,
            useTLS: TestEnv.useTLS,
            applicationName: "postgres-wire-tests"
        )
        self.client = try await PostgresDatabaseClient.connect(configuration: config, logger: logger)
    }

    override func tearDown() async throws {
        client?.close()
    }

    func testColumnsByTable() async throws {
        let schema = "public" // use default schema for integration; table is temporary
        let table = "kit_meta_test_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6))"

        // Create simple table and a secondary table with FK
        try await client.withConnection { conn in
            _ = try await conn.simpleQuery("DROP TABLE IF EXISTS \(table)")
            _ = try await conn.simpleQuery("CREATE TABLE \(table) (id INT PRIMARY KEY, name TEXT, ref_id INT)")
            _ = try await conn.simpleQuery("CREATE TABLE \(table)_ref (id INT PRIMARY KEY)")
            _ = try await conn.simpleQuery("ALTER TABLE \(table) ADD CONSTRAINT \(table)_fk FOREIGN KEY (ref_id) REFERENCES \(table)_ref(id)")
        }

        defer {
            Task.detached { [client] in
                try? await client?.withConnection { conn in
                    _ = try? await conn.simpleQuery("DROP TABLE IF EXISTS \(table)")
                    _ = try? await conn.simpleQuery("DROP TABLE IF EXISTS \(table)_ref")
                }
            }
        }

        let meta = PostgresMetadata()
        let byTable = try await meta.columnsByTable(using: client, schema: schema)
        guard let details = byTable[table] else {
            return XCTFail("Expected details for table \(table)")
        }

        // Expect id, name, ref_id
        let names = Set(details.map { $0.name })
        XCTAssertTrue(names.contains("id"))
        XCTAssertTrue(names.contains("name"))
        XCTAssertTrue(names.contains("ref_id"))
        // Primary key on id
        XCTAssertTrue(details.first(where: { $0.name == "id" })?.isPrimaryKey == true)
        // Foreign key on ref_id
        XCTAssertNotNil(details.first(where: { $0.name == "ref_id" })?.foreignKey)
    }
}
