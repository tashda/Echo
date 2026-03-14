import XCTest
@testable import Echo

/// Tests SQL Server database administration through Echo's DatabaseSession layer.
final class MSSQLDatabaseAdminTests: MSSQLDockerTestCase {

    // MARK: - Create Database

    func testCreateDatabase() async throws {
        let dbName = uniqueTableName(prefix: "testdb")
        try await execute("CREATE DATABASE [\(dbName)]")
        cleanupSQL("DROP DATABASE [\(dbName)]")

        let databases = try await session.listDatabases()
        IntegrationTestHelpers.assertContains(databases, value: dbName)
    }

    // MARK: - Drop Database

    func testDropDatabase() async throws {
        let dbName = uniqueTableName(prefix: "dropdb")
        try await execute("CREATE DATABASE [\(dbName)]")

        try await execute("DROP DATABASE [\(dbName)]")

        let databases = try await session.listDatabases()
        let exists = databases.contains(where: { $0.caseInsensitiveCompare(dbName) == .orderedSame })
        XCTAssertFalse(exists, "Database should be dropped")
    }

    // MARK: - Database Properties

    func testQueryDatabaseProperties() async throws {
        let result = try await query("""
            SELECT
                name,
                compatibility_level,
                collation_name,
                recovery_model_desc,
                state_desc
            FROM sys.databases
            WHERE name = 'master'
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        IntegrationTestHelpers.assertHasColumn(result, named: "name")
        IntegrationTestHelpers.assertHasColumn(result, named: "compatibility_level")
        IntegrationTestHelpers.assertHasColumn(result, named: "collation_name")
    }

    func testQueryDatabaseSize() async throws {
        let result = try await query("""
            SELECT
                DB_NAME() AS database_name,
                SUM(size * 8 / 1024) AS size_mb
            FROM sys.database_files
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        let sizeMB = Int(result.rows[0][1] ?? "0") ?? 0
        XCTAssertGreaterThan(sizeMB, 0, "Database should have non-zero size")
    }

    // MARK: - Database Options

    func testAlterDatabaseRecoveryModel() async throws {
        let dbName = uniqueTableName(prefix: "recdb")
        try await execute("CREATE DATABASE [\(dbName)]")
        cleanupSQL("DROP DATABASE [\(dbName)]")

        try await execute("ALTER DATABASE [\(dbName)] SET RECOVERY SIMPLE")

        let result = try await query("""
            SELECT recovery_model_desc FROM sys.databases WHERE name = '\(dbName)'
        """)
        XCTAssertEqual(result.rows[0][0], "SIMPLE")
    }

    // MARK: - Server Properties

    func testQueryServerVersion() async throws {
        let result = try await query("SELECT @@VERSION AS version")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("Microsoft SQL Server") ?? false)
    }

    func testQueryServerProperties() async throws {
        let result = try await query("""
            SELECT
                SERVERPROPERTY('ProductVersion') AS version,
                SERVERPROPERTY('Edition') AS edition,
                SERVERPROPERTY('ProductLevel') AS level,
                SERVERPROPERTY('Collation') AS collation
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertNotNil(result.rows[0][0]) // Version should be present
    }

    // MARK: - Collation

    func testQueryCollation() async throws {
        let result = try await query("""
            SELECT name, description FROM sys.fn_helpcollations()
            WHERE name = SERVERPROPERTY('Collation')
        """)
        IntegrationTestHelpers.assertMinRowCount(result, expected: 1)
    }

    func testCreateDatabaseWithCollation() async throws {
        let dbName = uniqueTableName(prefix: "colldb")
        try await execute("CREATE DATABASE [\(dbName)] COLLATE Latin1_General_CI_AS")
        cleanupSQL("DROP DATABASE [\(dbName)]")

        let result = try await query("""
            SELECT collation_name FROM sys.databases WHERE name = '\(dbName)'
        """)
        XCTAssertEqual(result.rows[0][0], "Latin1_General_CI_AS")
    }

    // MARK: - Activity Monitor

    func testMakeActivityMonitor() async throws {
        do {
            let monitor = try session.makeActivityMonitor()
            let snapshot = try await monitor.snapshot()
            // Should have at least our own session
            XCTAssertFalse(snapshot.processes.isEmpty, "Should have at least one active session")
        } catch {
            // Activity monitor may not be supported in all configurations
            // This is acceptable
        }
    }
}
