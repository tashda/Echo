import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server numeric data type round-trips through Echo's DatabaseSession layer.
final class MSSQLDataTypeNumericTests: MSSQLDockerTestCase {

    // MARK: - Integer Types

    func testBitType() async throws {
        let result = try await query("SELECT CAST(1 AS BIT) AS val_true, CAST(0 AS BIT) AS val_false")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
    }

    func testTinyIntType() async throws {
        let result = try await query("SELECT CAST(255 AS TINYINT) AS max_val, CAST(0 AS TINYINT) AS min_val")
        XCTAssertEqual(result.rows[0][0], "255")
        XCTAssertEqual(result.rows[0][1], "0")
    }

    func testSmallIntType() async throws {
        let result = try await query("SELECT CAST(32767 AS SMALLINT) AS max_val, CAST(-32768 AS SMALLINT) AS min_val")
        XCTAssertEqual(result.rows[0][0], "32767")
        XCTAssertEqual(result.rows[0][1], "-32768")
    }

    func testIntType() async throws {
        let result = try await query("SELECT CAST(2147483647 AS INT) AS max_val, CAST(-2147483648 AS INT) AS min_val")
        XCTAssertEqual(result.rows[0][0], "2147483647")
        XCTAssertEqual(result.rows[0][1], "-2147483648")
    }

    func testBigIntType() async throws {
        let result = try await query("SELECT CAST(9223372036854775807 AS BIGINT) AS max_val")
        XCTAssertEqual(result.rows[0][0], "9223372036854775807")
    }

    // MARK: - Decimal/Numeric Types

    func testDecimalType() async throws {
        let result = try await query("SELECT CAST(123456.789 AS DECIMAL(10,3)) AS val")
        XCTAssertTrue(result.rows[0][0]?.contains("123456.789") ?? false)
    }

    func testNumericType() async throws {
        let result = try await query("SELECT CAST(99999.99 AS NUMERIC(7,2)) AS val")
        XCTAssertTrue(result.rows[0][0]?.contains("99999.99") ?? false)
    }

    func testDecimalPrecision() async throws {
        let result = try await query("SELECT CAST(0.000001 AS DECIMAL(18,6)) AS small_val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Floating Point Types

    func testFloatType() async throws {
        let result = try await query("SELECT CAST(3.14159265358979 AS FLOAT) AS pi_val")
        XCTAssertNotNil(result.rows[0][0])
        // Float precision may vary
        let value = Double(result.rows[0][0] ?? "0") ?? 0
        XCTAssertEqual(value, 3.14159265358979, accuracy: 0.0001)
    }

    func testRealType() async throws {
        let result = try await query("SELECT CAST(2.5 AS REAL) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Money Types

    func testMoneyType() async throws {
        let result = try await query("SELECT CAST(922337203685477.5807 AS MONEY) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testSmallMoneyType() async throws {
        let result = try await query("SELECT CAST(214748.3647 AS SMALLMONEY) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Round-Trip Through Table

    func testNumericRoundTripThroughTable() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "tiny_val", definition: .standard(.init(dataType: .tinyint))),
            SQLServerColumnDefinition(name: "small_val", definition: .standard(.init(dataType: .smallint))),
            SQLServerColumnDefinition(name: "int_val", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "big_val", definition: .standard(.init(dataType: .bigint))),
            SQLServerColumnDefinition(name: "dec_val", definition: .standard(.init(dataType: .decimal(precision: 10, scale: 2)))),
            SQLServerColumnDefinition(name: "float_val", definition: .standard(.init(dataType: .float(mantissa: 53)))),
            SQLServerColumnDefinition(name: "money_val", definition: .standard(.init(dataType: .money))),
            SQLServerColumnDefinition(name: "bit_val", definition: .standard(.init(dataType: .bit)))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        _ = try await sqlserverClient.admin.insertRow(into: tableName, values: [
            "id": .int(1),
            "tiny_val": .int(42),
            "small_val": .int(1000),
            "int_val": .int(100000),
            "big_val": .int64(9876543210),
            "dec_val": .decimal("12345.67"),
            "float_val": .double(3.14),
            "money_val": .decimal("99.99"),
            "bit_val": .bool(true)
        ])

        let result = try await query("SELECT * FROM [\(tableName)]")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.columns.count, 9)

        // Verify each value can be read back
        for (i, col) in result.columns.enumerated() {
            XCTAssertNotNil(result.rows[0][i], "Column \(col.name) should have a value")
        }
    }

    // MARK: - NULL Handling

    func testNullNumericValues() async throws {
        let result = try await query("""
            SELECT CAST(NULL AS INT) AS null_int,
                   CAST(NULL AS DECIMAL(10,2)) AS null_dec,
                   CAST(NULL AS FLOAT) AS null_float,
                   CAST(NULL AS MONEY) AS null_money
        """)
        for i in 0..<4 {
            XCTAssertNil(result.rows[0][i], "Column \(i) should be NULL")
        }
    }
}
