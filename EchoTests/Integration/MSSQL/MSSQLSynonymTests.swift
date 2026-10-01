import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server synonym operations through Echo's DatabaseSession layer.
final class MSSQLSynonymTests: MSSQLLabTestCase {

    // MARK: - Synonym in Schema Info

    func testSynonymAppearsInSchemaInfo() async throws {
        let tableName = uniqueTableName(prefix: "syn_target")
        let synName = uniqueTableName(prefix: "syn_test")

        try await createTable(tableName, [.column("id", .int)])
        try await sqlserverClient.admin.createSynonym(name: synName, target: SQLServerObjectName(object: tableName))

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

        try await createTable(tableName, [.column("id", .int), .column("name", .nvarchar(length: .length(100)))])
        try await sqlserverClient.admin.createSynonym(name: synName, target: SQLServerObjectName(object: tableName))

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

        try await createTable(tableName, [.column("id", .int), .column("name", .nvarchar(length: .length(100)))])
        try await sqlserverClient.admin.insertRows(into: tableName, columns: ["id", "name"], values: [[.int(1), .nString("Alice")], [.int(2), .nString("Bob")]])
        try await sqlserverClient.admin.createSynonym(name: synName, target: SQLServerObjectName(object: tableName))

        let result = try await query("SELECT * FROM dbo.[\(synName)] ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
        XCTAssertEqual(result.rows[0][1], "Alice")
        XCTAssertEqual(result.rows[1][1], "Bob")
    }

    // MARK: - Insert Through Synonym

    func testInsertThroughSynonym() async throws {
        let tableName = uniqueTableName(prefix: "syn_target")
        let synName = uniqueTableName(prefix: "syn_insert")

        try await createTable(tableName, [.column("id", .int), .column("value", .nvarchar(length: .length(50)))])
        try await sqlserverClient.admin.createSynonym(name: synName, target: SQLServerObjectName(object: tableName))

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

        try await createTable(tableName, [.column("id", .int), .column("active", .bit)])
        try await sqlserverClient.admin.insertRows(into: tableName, columns: ["id", "active"], values: [[.int(1), .bool(true)], [.int(2), .bool(false)], [.int(3), .bool(true)]])
        try await sqlserverClient.views.createView(name: viewName, query: "SELECT id FROM dbo.[\(tableName)] WHERE active = 1")
        try await sqlserverClient.admin.createSynonym(name: synName, target: SQLServerObjectName(object: viewName))

        let result = try await query("SELECT * FROM dbo.[\(synName)] ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }

    // MARK: - Synonym to Procedure

    func testSynonymPointingToProcedure() async throws {
        let procName = uniqueTableName(prefix: "syn_proc")
        let synName = uniqueTableName(prefix: "syn_pref")

        try await sqlserverClient.routines.createStoredProcedure(
            name: procName, parameters: [ProcedureParameter(name: "x", dataType: .int)], body: "SELECT @x * 2 AS result;")
        try await sqlserverClient.admin.createSynonym(name: synName, target: SQLServerObjectName(object: procName))

        let result = try await query("EXEC dbo.[\(synName)] @x = 5")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "10")
    }

    // MARK: - Drop Synonym

    func testDropSynonymRemovesFromSchema() async throws {
        let tableName = uniqueTableName(prefix: "syn_target")
        let synName = uniqueTableName(prefix: "syn_drop")

        try await createTable(tableName, [.column("id", .int)])
        try await sqlserverClient.admin.createSynonym(name: synName, target: SQLServerObjectName(object: tableName))

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
        try await sqlserverClient.admin.dropSynonym(name: synName)

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

        try await sqlserverClient.security.createSchema(name: schemaName)
        try await createTable(tableName, schema: schemaName, [.column("id", .int)])
        try await sqlserverClient.admin.createSynonym(name: synName, schema: schemaName, target: SQLServerObjectName(schema: schemaName, object: tableName))

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
