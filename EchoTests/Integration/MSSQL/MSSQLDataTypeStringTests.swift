import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server string/binary data type round-trips through Echo's DatabaseSession layer.
final class MSSQLDataTypeStringTests: MSSQLDockerTestCase {

    // MARK: - Character Types

    func testCharType() async throws {
        let result = try await query("SELECT CAST('hello' AS CHAR(10)) AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("hello") ?? false)
    }

    func testVarCharType() async throws {
        let result = try await query("SELECT CAST('hello world' AS VARCHAR(100)) AS val")
        XCTAssertEqual(result.rows[0][0], "hello world")
    }

    func testVarCharMaxType() async throws {
        let longString = String(repeating: "x", count: 5000)
        let result = try await query("SELECT CAST('\(longString)' AS VARCHAR(MAX)) AS val")
        XCTAssertEqual(result.rows[0][0]?.count, 5000)
    }

    func testNCharType() async throws {
        let result = try await query("SELECT CAST(N'日本語' AS NCHAR(10)) AS val")
        XCTAssertTrue(result.rows[0][0]?.contains("日本語") ?? false)
    }

    func testNVarCharType() async throws {
        let result = try await query("SELECT CAST(N'Unicode: café' AS NVARCHAR(100)) AS val")
        XCTAssertEqual(result.rows[0][0], "Unicode: café")
    }

    func testNVarCharMaxType() async throws {
        let result = try await query("SELECT CAST(N'Large Unicode' AS NVARCHAR(MAX)) AS val")
        XCTAssertEqual(result.rows[0][0], "Large Unicode")
    }

    func testEmptyString() async throws {
        let result = try await query("SELECT '' AS empty_varchar, N'' AS empty_nvarchar")
        XCTAssertEqual(result.rows[0][0], "")
        XCTAssertEqual(result.rows[0][1], "")
    }

    // MARK: - Special String Values

    func testStringWithQuotes() async throws {
        let result = try await query("SELECT 'it''s a ''test''' AS val")
        XCTAssertEqual(result.rows[0][0], "it's a 'test'")
    }

    func testStringWithNewlines() async throws {
        let result = try await query("SELECT 'line1' + CHAR(10) + 'line2' AS val")
        XCTAssertTrue(result.rows[0][0]?.contains("line1") ?? false)
        XCTAssertTrue(result.rows[0][0]?.contains("line2") ?? false)
    }

    // MARK: - Date/Time Types

    func testDateType() async throws {
        let result = try await query("SELECT CAST('2024-03-15' AS DATE) AS val")
        XCTAssertTrue(result.rows[0][0]?.contains("2024") ?? false)
    }

    func testTimeType() async throws {
        let result = try await query("SELECT CAST('14:30:00' AS TIME) AS val")
        XCTAssertTrue(result.rows[0][0]?.contains("14:30") ?? false)
    }

    func testDateTimeType() async throws {
        let result = try await query("SELECT CAST('2024-03-15 14:30:00' AS DATETIME) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testDateTime2Type() async throws {
        let result = try await query("SELECT CAST('2024-03-15 14:30:00.1234567' AS DATETIME2) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testDateTimeOffsetType() async throws {
        let result = try await query("SELECT CAST('2024-03-15 14:30:00 +05:30' AS DATETIMEOFFSET) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testSmallDateTimeType() async throws {
        let result = try await query("SELECT CAST('2024-03-15 14:30' AS SMALLDATETIME) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Binary/Special Types

    func testUniqueIdentifierType() async throws {
        let result = try await query("SELECT NEWID() AS val")
        XCTAssertNotNil(result.rows[0][0])
        // UUID format: 8-4-4-4-12
        let uuid = result.rows[0][0] ?? ""
        XCTAssertTrue(uuid.count >= 32, "UUID should be at least 32 chars")
    }

    func testXMLType() async throws {
        let result = try await query("SELECT CAST('<root><item>test</item></root>' AS XML) AS val")
        XCTAssertTrue(result.rows[0][0]?.contains("<root>") ?? false)
    }

    func testVarBinaryType() async throws {
        let result = try await query("SELECT CAST(0x48656C6C6F AS VARBINARY(100)) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - NULL Handling

    func testNullStringValues() async throws {
        let result = try await query("""
            SELECT CAST(NULL AS VARCHAR(100)) AS null_varchar,
                   CAST(NULL AS NVARCHAR(100)) AS null_nvarchar,
                   CAST(NULL AS DATE) AS null_date,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS null_uuid
        """)
        for i in 0..<4 {
            XCTAssertNil(result.rows[0][i])
        }
    }

    // MARK: - Round-Trip Through Table

    func testStringRoundTripThroughTable() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "char_val", definition: .standard(.init(dataType: .char(length: 20)))),
            SQLServerColumnDefinition(name: "varchar_val", definition: .standard(.init(dataType: .varchar(length: .length(200))))),
            SQLServerColumnDefinition(name: "nchar_val", definition: .standard(.init(dataType: .nchar(length: 20)))),
            SQLServerColumnDefinition(name: "nvarchar_val", definition: .standard(.init(dataType: .nvarchar(length: .length(200))))),
            SQLServerColumnDefinition(name: "date_val", definition: .standard(.init(dataType: .date))),
            SQLServerColumnDefinition(name: "time_val", definition: .standard(.init(dataType: .time(precision: 7)))),
            SQLServerColumnDefinition(name: "dt2_val", definition: .standard(.init(dataType: .datetime2(precision: 7)))),
            SQLServerColumnDefinition(name: "uid_val", definition: .standard(.init(dataType: .uniqueidentifier)))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        _ = try await sqlserverClient.admin.insertRow(into: tableName, values: [
            "id": .int(1),
            "char_val": .string("fixed"),
            "varchar_val": .string("variable"),
            "nchar_val": .nString("固定"),
            "nvarchar_val": .nString("可変"),
            "date_val": .raw("'2024-01-15'"),
            "time_val": .raw("'10:30:00'"),
            "dt2_val": .raw("'2024-01-15 10:30:00'"),
            "uid_val": .uuid(UUID(uuidString: "12345678-1234-1234-1234-123456789012")!)
        ])

        let result = try await query("SELECT * FROM [\(tableName)]")
        XCTAssertEqual(result.rows.count, 1)
        for (i, col) in result.columns.enumerated() {
            XCTAssertNotNil(result.rows[0][i], "Column \(col.name) should have a value")
        }
    }
}
