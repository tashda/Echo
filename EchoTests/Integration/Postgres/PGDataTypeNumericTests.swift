import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL numeric data type round-trips through Echo's DatabaseSession layer.
final class PGDataTypeNumericTests: PostgresDockerTestCase {

    // MARK: - Smallint

    func testSmallint() async throws {
        let result = try await query("SELECT 123::SMALLINT AS val")
        XCTAssertEqual(result.rows[0][0], "123")
    }

    func testSmallintBounds() async throws {
        let result = try await query("SELECT (-32768)::SMALLINT AS min_val, 32767::SMALLINT AS max_val")
        XCTAssertEqual(result.rows[0][0], "-32768")
        XCTAssertEqual(result.rows[0][1], "32767")
    }

    func testSmallintZero() async throws {
        let result = try await query("SELECT 0::SMALLINT AS val")
        XCTAssertEqual(result.rows[0][0], "0")
    }

    // MARK: - Integer

    func testInteger() async throws {
        let result = try await query("SELECT 2147483647::INTEGER AS val")
        XCTAssertEqual(result.rows[0][0], "2147483647")
    }

    func testIntegerNegative() async throws {
        let result = try await query("SELECT (-2147483648)::INTEGER AS val")
        XCTAssertEqual(result.rows[0][0], "-2147483648")
    }

    func testIntegerZero() async throws {
        let result = try await query("SELECT 0::INTEGER AS val")
        XCTAssertEqual(result.rows[0][0], "0")
    }

    // MARK: - Bigint

    func testBigint() async throws {
        let result = try await query("SELECT 9223372036854775807::BIGINT AS val")
        XCTAssertEqual(result.rows[0][0], "9223372036854775807")
    }

    func testBigintNegative() async throws {
        let result = try await query("SELECT (-9223372036854775808)::BIGINT AS val")
        XCTAssertEqual(result.rows[0][0], "-9223372036854775808")
    }

    // MARK: - Decimal / Numeric with Precision

    func testDecimalBasic() async throws {
        let result = try await query("SELECT 123456.789::DECIMAL(10,3) AS val")
        XCTAssertEqual(result.rows[0][0], "123456.789")
    }

    func testNumericWithPrecision() async throws {
        let result = try await query("SELECT 99999.99::NUMERIC(7,2) AS val")
        XCTAssertEqual(result.rows[0][0], "99999.99")
    }

    func testNumericHighPrecision() async throws {
        let result = try await query("SELECT 123456789.123456789::NUMERIC(20,9) AS val")
        XCTAssertEqual(result.rows[0][0], "123456789.123456789")
    }

    func testNumericZeroScale() async throws {
        let result = try await query("SELECT 12345::NUMERIC(10,0) AS val")
        XCTAssertEqual(result.rows[0][0], "12345")
    }

    func testNumericNegative() async throws {
        let result = try await query("SELECT (-123.456)::NUMERIC(10,3) AS val")
        XCTAssertEqual(result.rows[0][0], "-123.456")
    }

    func testNumericVerySmall() async throws {
        let result = try await query("SELECT 0.000001::NUMERIC(10,6) AS val")
        XCTAssertEqual(result.rows[0][0], "0.000001")
    }

    func testNumericZero() async throws {
        let result = try await query("SELECT 0::NUMERIC AS val")
        XCTAssertEqual(result.rows[0][0], "0")
    }

    func testNumericZeroWithScale() async throws {
        let result = try await query("SELECT 0.00::NUMERIC(5,2) AS val")
        let val = result.rows[0][0] ?? ""
        // Driver may return "0.00" or "0" depending on numeric formatting
        XCTAssertTrue(val == "0.00" || val == "0", "Expected 0.00 or 0, got \(val)")
    }

    // MARK: - Real (float4)

    func testReal() async throws {
        let result = try await query("SELECT 3.14::REAL AS val")
        XCTAssertNotNil(result.rows[0][0])
        let value = Float(result.rows[0][0]!)!
        XCTAssertEqual(value, 3.14, accuracy: 0.01)
    }

    func testRealInfinity() async throws {
        let result = try await query("SELECT 'Infinity'::REAL AS pos_inf, '-Infinity'::REAL AS neg_inf")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
        let posStr = result.rows[0][0]!.lowercased()
        let negStr = result.rows[0][1]!.lowercased()
        XCTAssertTrue(posStr.contains("inf"), "Expected Infinity, got \(posStr)")
        XCTAssertTrue(negStr.contains("inf"), "Expected -Infinity, got \(negStr)")
    }

    func testRealNaN() async throws {
        let result = try await query("SELECT 'NaN'::REAL AS nan_val")
        XCTAssertNotNil(result.rows[0][0])
        let strValue = result.rows[0][0]!.lowercased()
        XCTAssertTrue(strValue.contains("nan"), "Expected NaN, got \(strValue)")
    }

    // MARK: - Double Precision (float8)

    func testDoublePrecision() async throws {
        let result = try await query("SELECT 3.141592653589793::DOUBLE PRECISION AS val")
        XCTAssertNotNil(result.rows[0][0])
        let value = Double(result.rows[0][0]!)!
        XCTAssertEqual(value, 3.141592653589793, accuracy: 0.0000001)
    }

    func testDoublePrecisionInfinity() async throws {
        let result = try await query("SELECT 'Infinity'::DOUBLE PRECISION AS pos_inf")
        XCTAssertNotNil(result.rows[0][0])
        let strValue = result.rows[0][0]!.lowercased()
        XCTAssertTrue(strValue.contains("inf"), "Expected Infinity, got \(strValue)")
    }

    func testDoublePrecisionNegativeInfinity() async throws {
        let result = try await query("SELECT '-Infinity'::DOUBLE PRECISION AS neg_inf")
        XCTAssertNotNil(result.rows[0][0])
        let strValue = result.rows[0][0]!.lowercased()
        XCTAssertTrue(strValue.contains("inf"), "Expected -Infinity, got \(strValue)")
    }

    func testDoublePrecisionNaN() async throws {
        let result = try await query("SELECT 'NaN'::DOUBLE PRECISION AS nan_val")
        XCTAssertNotNil(result.rows[0][0])
        let strValue = result.rows[0][0]!.lowercased()
        XCTAssertTrue(strValue.contains("nan"), "Expected NaN, got \(strValue)")
    }

    // MARK: - Serial Types

    func testSerialColumn() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "name")
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName)")

        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["A"] as [Any]])
        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["B"] as [Any]])
        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["C"] as [Any]])

        let result = try await query("SELECT id FROM \(tableName) ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 3)
        XCTAssertEqual(result.rows[0][0], "1")
        XCTAssertEqual(result.rows[1][0], "2")
        XCTAssertEqual(result.rows[2][0], "3")
    }

    func testBigserialColumn() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .bigSerial(name: "id", primaryKey: true),
            .text(name: "name")
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName)")

        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["first"] as [Any]])
        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["second"] as [Any]])

        let result = try await query("SELECT id FROM \(tableName) ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
        XCTAssertEqual(result.rows[0][0], "1")
        XCTAssertEqual(result.rows[1][0], "2")
    }

    func testSmallserialColumn() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            PostgresColumnDefinition(name: "id", dataType: "SMALLSERIAL", nullable: false, primaryKey: true),
            .text(name: "name")
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName)")

        try await postgresClient.connection.insert(into: tableName, columns: ["name"], values: [["one"] as [Any]])

        let result = try await query("SELECT id FROM \(tableName)")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.rows[0][0], "1")
    }

    // MARK: - NULL Handling

    func testNullSmallint() async throws {
        let result = try await query("SELECT NULL::SMALLINT AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullInteger() async throws {
        let result = try await query("SELECT NULL::INTEGER AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullBigint() async throws {
        let result = try await query("SELECT NULL::BIGINT AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullNumeric() async throws {
        let result = try await query("SELECT NULL::NUMERIC AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullReal() async throws {
        let result = try await query("SELECT NULL::REAL AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullDoublePrecision() async throws {
        let result = try await query("SELECT NULL::DOUBLE PRECISION AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullAllNumericTypes() async throws {
        let result = try await query("""
            SELECT NULL::SMALLINT AS s, NULL::INTEGER AS i, NULL::BIGINT AS b,
                   NULL::NUMERIC(10,2) AS n, NULL::REAL AS r, NULL::DOUBLE PRECISION AS d
        """)
        for i in 0..<6 {
            XCTAssertNil(result.rows[0][i], "Column \(i) should be NULL")
        }
    }

    // MARK: - Table Round-Trip

    func testNumericRoundTripAllTypes() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            PostgresColumnDefinition(name: "small_val", dataType: "SMALLINT"),
            .integer(name: "int_val"),
            .bigInt(name: "big_val"),
            .decimal(name: "dec_val", precision: 10, scale: 2),
            PostgresColumnDefinition(name: "num_val", dataType: "NUMERIC(15,4)"),
            .real(name: "real_val"),
            .double(name: "double_val")
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName)")

        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["small_val", "int_val", "big_val", "dec_val", "num_val", "real_val", "double_val"],
            values: [[42, 100000, 9876543210, 12345.67, 98765.4321, 3.14, 2.71828] as [Any]]
        )

        let result = try await query("SELECT * FROM \(tableName)")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.columns.count, 8)

        XCTAssertEqual(result.rows[0][1], "42")
        XCTAssertEqual(result.rows[0][2], "100000")
        XCTAssertEqual(result.rows[0][3], "9876543210")
        XCTAssertEqual(result.rows[0][4], "12345.67")
        XCTAssertEqual(result.rows[0][5], "98765.4321")
        XCTAssertNotNil(result.rows[0][6]) // REAL precision varies
        XCTAssertNotNil(result.rows[0][7]) // DOUBLE precision varies
    }

    func testNullRoundTripThroughTable() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .integer(name: "val")
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName)")

        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["val"],
            values: [[PostgresInsertValue.null]]
        )

        let result = try await query("SELECT val FROM \(tableName)")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertNil(result.rows[0][0], "NULL value should round-trip as nil")
    }

    func testNumericRoundTripWithZeros() async throws {
        let result = try await query("""
            SELECT 0::SMALLINT AS s, 0::INTEGER AS i, 0::BIGINT AS b,
                   0.00::NUMERIC(5,2) AS n, 0.0::REAL AS r, 0.0::DOUBLE PRECISION AS d
        """)
        XCTAssertEqual(result.rows[0][0], "0")
        XCTAssertEqual(result.rows[0][1], "0")
        XCTAssertEqual(result.rows[0][2], "0")
        // Driver may return "0.00" or "0" for NUMERIC(5,2) zero
        let numVal = result.rows[0][3] ?? ""
        XCTAssertTrue(numVal == "0.00" || numVal == "0", "Expected 0.00 or 0, got \(numVal)")
    }

    // MARK: - Arithmetic Expressions

    func testIntegerArithmetic() async throws {
        let result = try await query("""
            SELECT 10 + 20 AS sum, 100 - 50 AS diff, 6 * 7 AS product, 100 / 3 AS quotient
        """)
        XCTAssertEqual(result.rows[0][0], "30")
        XCTAssertEqual(result.rows[0][1], "50")
        XCTAssertEqual(result.rows[0][2], "42")
        XCTAssertEqual(result.rows[0][3], "33")
    }

    func testNumericArithmetic() async throws {
        let result = try await query("SELECT (10.5 + 20.3)::NUMERIC(10,1) AS sum")
        XCTAssertEqual(result.rows[0][0], "30.8")
    }

    // MARK: - Money Type

    func testMoneyType() async throws {
        let result = try await query("SELECT 12.34::MONEY AS price")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testMoneyNegative() async throws {
        let result = try await query("SELECT (-99.99)::MONEY AS price")
        XCTAssertNotNil(result.rows[0][0])
    }
}
