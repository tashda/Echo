import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server synonym operations through Echo's DatabaseSession layer.
final class MSSQLSynonymTests: MSSQLDockerTestCase {

    // MARK: - Synonym in Schema Info

    func testSynonymAppearsInSchemaInfo() async throws {
        let tableName = uniqueTableName(prefix: "syn_target")
        let synName = uniqueTableName(prefix: "syn_test")

        try await execute("CREATE TABLE dbo.[\(tableName)] (id INT)")
        try await execute("CREATE SYNONYM dbo.[\(synName)] FOR dbo.[\(tableName)]")
        cleanupSQL(
            "DROP SYNONYM IF EXISTS dbo.[\(synName)]",
            "DROP TABLE IF EXISTS dbo.[\(tableName)]"
        )

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("dbo", progress: nil)
        let synonyms = schemaInfo.objects.filter { $0.type == .synonym }

        XCTAssertTrue(
            synonyms.contains { $0.name.caseInsensitiveCompare(synName) == .orderedSame },
            "Expected synonym '\(synName)' in schema objects, found synonyms: \(synonyms.map(\.name))"
        )
    }

    func testSynonymHasCorrectType() async throws {
        let tableName = uniqueTableName(prefix: "syn_target")
        let synName = uniqueTableName(prefix: "syn_type")

        try await execute("CREATE TABLE dbo.[\(tableName)] (id INT, name NVARCHAR(100))")
        try await execute("CREATE SYNONYM dbo.[\(synName)] FOR dbo.[\(tableName)]")
        cleanupSQL(
            "DROP SYNONYM IF EXISTS dbo.[\(synName)]",
            "DROP TABLE IF EXISTS dbo.[\(tableName)]"
        )

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("dbo", progress: nil)
        let match = schemaInfo.objects.first {
            $0.name.caseInsensitiveCompare(synName) == .orderedSame
        }

        XCTAssertNotNil(match, "Synonym '\(synName)' should exist in schema objects")
        XCTAssertEqual(match?.type, .synonym, "Object type should be .synonym")
    }

    // MARK: - Query Through Synonym

    func testQueryThroughSynonym() async throws {
        let tableName = uniqueTableName(prefix: "syn_target")
        let synName = uniqueTableName(prefix: "syn_query")

        try await execute("CREATE TABLE dbo.[\(tableName)] (id INT, name NVARCHAR(100))")
        try await execute("INSERT INTO dbo.[\(tableName)] VALUES (1, N'Alice'), (2, N'Bob')")
        try await execute("CREATE SYNONYM dbo.[\(synName)] FOR dbo.[\(tableName)]")
        cleanupSQL(
            "DROP SYNONYM IF EXISTS dbo.[\(synName)]",
            "DROP TABLE IF EXISTS dbo.[\(tableName)]"
        )

        let result = try await query("SELECT * FROM dbo.[\(synName)] ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
        XCTAssertEqual(result.rows[0][1], "Alice")
        XCTAssertEqual(result.rows[1][1], "Bob")
    }

    // MARK: - Insert Through Synonym

    func testInsertThroughSynonym() async throws {
        let tableName = uniqueTableName(prefix: "syn_target")
        let synName = uniqueTableName(prefix: "syn_insert")

        try await execute("CREATE TABLE dbo.[\(tableName)] (id INT, value NVARCHAR(50))")
        try await execute("CREATE SYNONYM dbo.[\(synName)] FOR dbo.[\(tableName)]")
        cleanupSQL(
            "DROP SYNONYM IF EXISTS dbo.[\(synName)]",
            "DROP TABLE IF EXISTS dbo.[\(tableName)]"
        )

        try await execute("INSERT INTO dbo.[\(synName)] VALUES (1, N'test_value')")

        let result = try await query("SELECT * FROM dbo.[\(tableName)]")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][1], "test_value")
    }

    // MARK: - Synonym to View

    func testSynonymPointingToView() async throws {
        let tableName = uniqueTableName(prefix: "syn_tbl")
        let viewName = uniqueTableName(prefix: "syn_view")
        let synName = uniqueTableName(prefix: "syn_vref")

        try await execute("CREATE TABLE dbo.[\(tableName)] (id INT, active BIT)")
        try await execute("INSERT INTO dbo.[\(tableName)] VALUES (1, 1), (2, 0), (3, 1)")
        try await execute("CREATE VIEW dbo.[\(viewName)] AS SELECT id FROM dbo.[\(tableName)] WHERE active = 1")
        try await execute("CREATE SYNONYM dbo.[\(synName)] FOR dbo.[\(viewName)]")
        cleanupSQL(
            "DROP SYNONYM IF EXISTS dbo.[\(synName)]",
            "DROP VIEW IF EXISTS dbo.[\(viewName)]",
            "DROP TABLE IF EXISTS dbo.[\(tableName)]"
        )

        let result = try await query("SELECT * FROM dbo.[\(synName)] ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }

    // MARK: - Synonym to Procedure

    func testSynonymPointingToProcedure() async throws {
        let procName = uniqueTableName(prefix: "syn_proc")
        let synName = uniqueTableName(prefix: "syn_pref")

        try await execute("""
            CREATE PROCEDURE dbo.[\(procName)]
                @x INT
            AS
            BEGIN
                SELECT @x * 2 AS result;
            END
        """)
        try await execute("CREATE SYNONYM dbo.[\(synName)] FOR dbo.[\(procName)]")
        cleanupSQL(
            "DROP SYNONYM IF EXISTS dbo.[\(synName)]",
            "DROP PROCEDURE IF EXISTS dbo.[\(procName)]"
        )

        let result = try await query("EXEC dbo.[\(synName)] @x = 5")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "10")
    }

    // MARK: - Drop Synonym

    func testDropSynonymRemovesFromSchema() async throws {
        let tableName = uniqueTableName(prefix: "syn_target")
        let synName = uniqueTableName(prefix: "syn_drop")

        try await execute("CREATE TABLE dbo.[\(tableName)] (id INT)")
        try await execute("CREATE SYNONYM dbo.[\(synName)] FOR dbo.[\(tableName)]")
        cleanupSQL("DROP TABLE IF EXISTS dbo.[\(tableName)]")

        // Verify synonym exists
        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaBefore = try await metaSession.loadSchemaInfo("dbo", progress: nil)
        let existsBefore = schemaBefore.objects.contains {
            $0.name.caseInsensitiveCompare(synName) == .orderedSame && $0.type == .synonym
        }
        XCTAssertTrue(existsBefore, "Synonym should exist before drop")

        // Drop and verify removal
        try await execute("DROP SYNONYM dbo.[\(synName)]")

        let schemaAfter = try await metaSession.loadSchemaInfo("dbo", progress: nil)
        let existsAfter = schemaAfter.objects.contains {
            $0.name.caseInsensitiveCompare(synName) == .orderedSame && $0.type == .synonym
        }
        XCTAssertFalse(existsAfter, "Synonym should not exist after drop")
    }

    // MARK: - Synonym in Custom Schema

    func testSynonymInCustomSchema() async throws {
        let schemaName = uniqueTableName(prefix: "s")
        let tableName = uniqueTableName(prefix: "syn_target")
        let synName = uniqueTableName(prefix: "syn_custom")

        try await execute("CREATE SCHEMA [\(schemaName)]")
        try await execute("CREATE TABLE [\(schemaName)].[\(tableName)] (id INT)")
        try await execute("CREATE SYNONYM [\(schemaName)].[\(synName)] FOR [\(schemaName)].[\(tableName)]")
        cleanupSQL(
            "DROP SYNONYM IF EXISTS [\(schemaName)].[\(synName)]",
            "DROP TABLE IF EXISTS [\(schemaName)].[\(tableName)]",
            "DROP SCHEMA [\(schemaName)]"
        )

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo(schemaName, progress: nil)
        let synonyms = schemaInfo.objects.filter { $0.type == .synonym }

        XCTAssertTrue(
            synonyms.contains { $0.name.caseInsensitiveCompare(synName) == .orderedSame },
            "Expected synonym '\(synName)' in custom schema '\(schemaName)', found: \(synonyms.map(\.name))"
        )
    }
}
