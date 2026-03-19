import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server query execution through Echo's DatabaseSession layer.
final class MSSQLQueryTests: MSSQLDockerTestCase {

    // MARK: - Simple Queries

    func testSelectLiteral() async throws {
        let result = try await query("SELECT 42 AS number, 'hello' AS greeting")
        XCTAssertEqual(result.columns.count, 2)
        IntegrationTestHelpers.assertHasColumn(result, named: "number")
        IntegrationTestHelpers.assertHasColumn(result, named: "greeting")
        XCTAssertEqual(result.rows[0][0], "42")
        XCTAssertEqual(result.rows[0][1], "hello")
    }

    func testSelectMultipleRows() async throws {
        let result = try await query("""
            SELECT n FROM (VALUES (1),(2),(3),(4),(5)) AS t(n)
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 5)
    }

    func testSelectWithNulls() async throws {
        let result = try await query("SELECT NULL AS null_col, 1 AS not_null")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertNil(result.rows[0][0])
        XCTAssertEqual(result.rows[0][1], "1")
    }

    func testEmptyResultSet() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "value", definition: .standard(.init(dataType: .int))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let result = try await query("SELECT * FROM [\(tableName)]")
        XCTAssertEqual(result.rows.count, 0)
        XCTAssertFalse(result.columns.isEmpty)
    }

    // MARK: - Execute Update

    func testInsertReturnsAffectedCount() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "value", definition: .standard(.init(dataType: .int))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let count = try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1), "name": .nString("test"), "value": .int(42)]
        )
        XCTAssertEqual(count, 1)
    }

    func testMultipleInserts() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "value", definition: .standard(.init(dataType: .int))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let count = try await sqlserverClient.admin.insertRows(
            into: tableName,
            columns: ["id", "name", "value"],
            values: [
                [.int(1), .nString("a"), .int(1)],
                [.int(2), .nString("b"), .int(2)],
                [.int(3), .nString("c"), .int(3)],
            ]
        )
        XCTAssertEqual(count, 3)
    }

    func testUpdateReturnsAffectedCount() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "value", definition: .standard(.init(dataType: .int))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.insertRows(
            into: tableName,
            columns: ["id", "name", "value"],
            values: [
                [.int(1), .nString("a"), .int(1)],
                [.int(2), .nString("b"), .int(2)],
                [.int(3), .nString("c"), .int(3)],
            ]
        )
        let count = try await sqlserverClient.admin.updateRows(
            in: tableName,
            set: ["value": .int(99)],
            where: "[value] < 3"
        )
        XCTAssertEqual(count, 2)
    }

    func testDeleteReturnsAffectedCount() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "value", definition: .standard(.init(dataType: .int))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.insertRows(
            into: tableName,
            columns: ["id", "name", "value"],
            values: [
                [.int(1), .nString("a"), .int(1)],
                [.int(2), .nString("b"), .int(2)],
            ]
        )
        let count = try await sqlserverClient.admin.deleteRows(
            from: tableName,
            where: "[id] = 1"
        )
        XCTAssertEqual(count, 1)
    }

    // MARK: - Paged Queries

    func testQueryWithPaging() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "value", definition: .standard(.init(dataType: .int))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let rows: [[SQLServerLiteralValue]] = (1...20).map { i in
            [.int(i), .nString("row\(i)"), .int(i)]
        }
        try await sqlserverClient.admin.insertRows(
            into: tableName,
            columns: ["id", "name", "value"],
            values: rows
        )

        let page1 = try await session.queryWithPaging(
            "SELECT * FROM [\(tableName)] ORDER BY id",
            limit: 5, offset: 0
        )
        IntegrationTestHelpers.assertRowCount(page1, expected: 5)

        let page2 = try await session.queryWithPaging(
            "SELECT * FROM [\(tableName)] ORDER BY id",
            limit: 5, offset: 5
        )
        IntegrationTestHelpers.assertRowCount(page2, expected: 5)

        // Ensure different data
        XCTAssertNotEqual(page1.rows[0][0], page2.rows[0][0])
    }

    func testQueryWithPagingBeyondData() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "value", definition: .standard(.init(dataType: .int))),
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .int(1), "name": .nString("only"), "value": .int(1)]
        )
        let result = try await session.queryWithPaging(
            "SELECT * FROM [\(tableName)]",
            limit: 10, offset: 100
        )
        XCTAssertEqual(result.rows.count, 0)
    }

    // MARK: - Multi-Result Sets

    func testMultipleResultSets() async throws {
        let result = try await query("""
            SELECT 1 AS first_result;
            SELECT 'a' AS col_a, 'b' AS col_b;
        """)
        // First result set
        XCTAssertEqual(result.columns.count, 1)
        XCTAssertEqual(result.rows.count, 1)

        // Additional result sets
        XCTAssertFalse(result.additionalResults.isEmpty, "Should have additional result sets")
        let second = result.additionalResults[0]
        XCTAssertEqual(second.columns.count, 2)
    }

    func testMultipleResultSetsWithDifferentShapes() async throws {
        let result = try await query("""
            SELECT 1 AS a, 2 AS b, 3 AS c;
            SELECT 'x' AS single;
            SELECT 100 AS num, 'hello' AS str;
        """)
        XCTAssertEqual(result.columns.count, 3, "First result has 3 columns")
        XCTAssertGreaterThanOrEqual(result.additionalResults.count, 2, "Should have 2+ additional result sets")
    }

    // MARK: - Large Queries

    func testLargeResultSet() async throws {
        let result = try await query("""
            SELECT TOP 1000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_columns a CROSS JOIN sys.all_columns b
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1000)
    }

    // MARK: - SQL with Special Characters

    func testUnicodeInResults() async throws {
        let result = try await query("SELECT N'日本語テスト' AS unicode_text")
        XCTAssertEqual(result.rows[0][0], "日本語テスト")
    }

    func testSpecialCharactersInStrings() async throws {
        let result = try await query("SELECT 'it''s a test' AS escaped, CHAR(9) AS tab_char")
        XCTAssertEqual(result.rows[0][0], "it's a test")
    }
}
