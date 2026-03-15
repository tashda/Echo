import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL special data type round-trips through Echo's DatabaseSession layer.
final class PGDataTypeSpecialTests: PostgresDockerTestCase {

    // MARK: - Boolean

    func testBooleanTrue() async throws {
        let result = try await query("SELECT TRUE::BOOLEAN AS val")
        XCTAssertNotNil(result.rows[0][0])
        let val = result.rows[0][0] ?? ""
        XCTAssertTrue(val == "t" || val == "true", "Expected true, got \(val)")
    }

    func testBooleanFalse() async throws {
        let result = try await query("SELECT FALSE::BOOLEAN AS val")
        XCTAssertNotNil(result.rows[0][0])
        let val = result.rows[0][0] ?? ""
        XCTAssertTrue(val == "f" || val == "false", "Expected false, got \(val)")
    }

    func testBooleanFromString() async throws {
        let result = try await query("SELECT 'yes'::BOOLEAN AS y, 'no'::BOOLEAN AS n")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
    }

    // MARK: - UUID

    func testUuidGenerated() async throws {
        let result = try await query("SELECT gen_random_uuid()::UUID AS val")
        XCTAssertNotNil(result.rows[0][0])
        let uuid = result.rows[0][0]!
        XCTAssertTrue(uuid.count >= 32, "UUID should be at least 32 chars: \(uuid)")
    }

    func testUuidRoundTrip() async throws {
        let knownUUID = "12345678-1234-1234-1234-123456789012"
        let result = try await query("SELECT '\(knownUUID)'::UUID AS val")
        XCTAssertEqual(result.rows[0][0], knownUUID)
    }

    func testUuidUniqueness() async throws {
        let result = try await query("""
            SELECT gen_random_uuid() AS u1, gen_random_uuid() AS u2
        """)
        XCTAssertNotEqual(result.rows[0][0], result.rows[0][1])
    }

    // MARK: - JSON

    func testJsonType() async throws {
        let result = try await query("""
            SELECT '{"key": "value", "num": 42}'::JSON AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("key") ?? false)
    }

    func testJsonArray() async throws {
        let result = try await query("SELECT '[1, 2, 3]'::JSON AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testJsonNested() async throws {
        let result = try await query("""
            SELECT '{"outer": {"inner": "value"}}'::JSON AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("inner") ?? false)
    }

    // MARK: - JSONB

    func testJsonbType() async throws {
        let result = try await query("""
            SELECT '{"key": "value", "num": 42}'::JSONB AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("key") ?? false)
    }

    func testJsonbOperator() async throws {
        let result = try await query("""
            SELECT '{"name": "test"}'::JSONB ->> 'name' AS val
        """)
        XCTAssertEqual(result.rows[0][0], "test")
    }

    func testJsonbContains() async throws {
        let result = try await query("""
            SELECT '{"a": 1, "b": 2}'::JSONB @> '{"a": 1}'::JSONB AS contains
        """)
        XCTAssertNotNil(result.rows[0][0])
        let val = result.rows[0][0] ?? ""
        XCTAssertTrue(val == "t" || val == "true")
    }

    // MARK: - Bytea

    func testByteaHex() async throws {
        let result = try await query("SELECT E'\\\\xDEADBEEF'::BYTEA AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testByteaEmpty() async throws {
        let result = try await query("SELECT E'\\\\x'::BYTEA AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testByteaFromString() async throws {
        let result = try await query("SELECT 'hello'::BYTEA AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - XML

    func testXmlType() async throws {
        let result = try await query("SELECT '<root><child>value</child></root>'::XML AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("<root>") ?? false)
    }

    func testXmlWithAttributes() async throws {
        let result = try await query("""
            SELECT '<item id="1" name="test"/>'::XML AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Arrays

    func testIntegerArray() async throws {
        let result = try await query("SELECT ARRAY[1, 2, 3, 4, 5]::INT[] AS val")
        XCTAssertNotNil(result.rows[0][0])
        let val = result.rows[0][0] ?? ""
        XCTAssertTrue(val.contains("1") && val.contains("5"), "Array should contain elements: \(val)")
    }

    func testTextArray() async throws {
        let result = try await query("SELECT ARRAY['hello', 'world', 'test']::TEXT[] AS val")
        XCTAssertNotNil(result.rows[0][0])
        let val = result.rows[0][0] ?? ""
        XCTAssertTrue(val.contains("hello") && val.contains("world"))
    }

    func testEmptyArray() async throws {
        let result = try await query("SELECT ARRAY[]::INT[] AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testNestedArray() async throws {
        let result = try await query("SELECT ARRAY[ARRAY[1,2], ARRAY[3,4]]::INT[][] AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testBooleanArray() async throws {
        let result = try await query("SELECT ARRAY[TRUE, FALSE, TRUE]::BOOLEAN[] AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testArrayWithNull() async throws {
        let result = try await query("SELECT ARRAY[1, NULL, 3]::INT[] AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Network Types

    func testInetIPv4() async throws {
        let result = try await query("SELECT '192.168.1.1'::INET AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("192.168.1.1") ?? false)
    }

    func testInetIPv6() async throws {
        let result = try await query("SELECT '::1'::INET AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testInetWithSubnet() async throws {
        let result = try await query("SELECT '192.168.1.0/24'::INET AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testCidrType() async throws {
        let result = try await query("SELECT '10.0.0.0/8'::CIDR AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testCidrIPv6() async throws {
        let result = try await query("SELECT 'fe80::/10'::CIDR AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testMacaddrType() async throws {
        let result = try await query("SELECT '08:00:2b:01:02:03'::MACADDR AS val")
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertTrue(result.rows[0][0]?.contains("08:00:2b:01:02:03") ?? false)
    }

    func testMacaddr8Type() async throws {
        let result = try await query("SELECT '08:00:2b:01:02:03:04:05'::MACADDR8 AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Geometric Types

    func testPointType() async throws {
        let result = try await query("SELECT '(1.5, 2.5)'::POINT AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testLineType() async throws {
        let result = try await query("SELECT '{1, 2, 3}'::LINE AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testLineSegmentType() async throws {
        let result = try await query("SELECT '[(0,0),(1,1)]'::LSEG AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testBoxType() async throws {
        let result = try await query("SELECT '((0,0),(1,1))'::BOX AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testCircleType() async throws {
        let result = try await query("SELECT '<(0,0),5>'::CIRCLE AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testPathType() async throws {
        let result = try await query("SELECT '[(0,0),(1,1),(2,0)]'::PATH AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testPolygonType() async throws {
        let result = try await query("SELECT '((0,0),(1,0),(1,1),(0,1))'::POLYGON AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - Range Types

    func testInt4Range() async throws {
        let result = try await query("SELECT '[1,10)'::INT4RANGE AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testInt8Range() async throws {
        let result = try await query("SELECT '[1,100)'::INT8RANGE AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testNumRange() async throws {
        let result = try await query("SELECT '[1.5,9.5]'::NUMRANGE AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testTsRange() async throws {
        let result = try await query("""
            SELECT '[2024-01-01, 2024-12-31)'::TSRANGE AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
    }

    func testTstzRange() async throws {
        let result = try await query("""
            SELECT '[2024-01-01 00:00:00+00, 2024-12-31 00:00:00+00)'::TSTZRANGE AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
    }

    func testDateRange() async throws {
        let result = try await query("SELECT '[2024-01-01, 2024-12-31)'::DATERANGE AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testEmptyRange() async throws {
        let result = try await query("SELECT 'empty'::INT4RANGE AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testRangeContains() async throws {
        let result = try await query("SELECT '[1,10)'::INT4RANGE @> 5 AS contains")
        XCTAssertNotNil(result.rows[0][0])
        let val = result.rows[0][0] ?? ""
        XCTAssertTrue(val == "t" || val == "true")
    }

    // MARK: - NULL Handling

    func testNullBoolean() async throws {
        let result = try await query("SELECT NULL::BOOLEAN AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullUuid() async throws {
        let result = try await query("SELECT NULL::UUID AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullJson() async throws {
        let result = try await query("SELECT NULL::JSON AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullJsonb() async throws {
        let result = try await query("SELECT NULL::JSONB AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullBytea() async throws {
        let result = try await query("SELECT NULL::BYTEA AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullXml() async throws {
        let result = try await query("SELECT NULL::XML AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullInet() async throws {
        let result = try await query("SELECT NULL::INET AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullIntArray() async throws {
        let result = try await query("SELECT NULL::INT[] AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullPoint() async throws {
        let result = try await query("SELECT NULL::POINT AS val")
        XCTAssertNil(result.rows[0][0])
    }

    func testNullRange() async throws {
        let result = try await query("SELECT NULL::INT4RANGE AS val")
        XCTAssertNil(result.rows[0][0])
    }

    // MARK: - Table Round-Trip

    func testSpecialTypesRoundTrip() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .boolean(name: "bool_val"),
            .uuid(name: "uuid_val"),
            .json(name: "json_val"),
            .jsonb(name: "jsonb_val"),
            .inet(name: "inet_val"),
            .macaddr(name: "macaddr_val"),
            PostgresColumnDefinition(name: "point_val", dataType: "POINT"),
            .array(name: "int_arr", elementType: "INT"),
            .array(name: "text_arr", elementType: "TEXT")
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName)")

        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["bool_val", "uuid_val", "json_val", "jsonb_val", "inet_val", "macaddr_val", "point_val", "int_arr", "text_arr"],
            values: [[
                PostgresInsertValue.sql("TRUE"),
                PostgresInsertValue.sql("'12345678-1234-1234-1234-123456789012'"),
                PostgresInsertValue.sql("'{\"test\": true}'"),
                PostgresInsertValue.sql("'{\"test\": true}'"),
                PostgresInsertValue.sql("'192.168.1.1'"),
                PostgresInsertValue.sql("'08:00:2b:01:02:03'"),
                PostgresInsertValue.sql("'(1.5, 2.5)'"),
                PostgresInsertValue.sql("ARRAY[1, 2, 3]"),
                PostgresInsertValue.sql("ARRAY['a', 'b', 'c']")
            ]]
        )

        let result = try await query("SELECT * FROM \(tableName)")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.columns.count, 10)

        // All non-id columns should be non-null
        for i in 1..<result.columns.count {
            XCTAssertNotNil(result.rows[0][i], "Column \(result.columns[i].name) should have a value")
        }
    }

    func testSpecialTypesRoundTripWithNulls() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .boolean(name: "bool_val"),
            .uuid(name: "uuid_val"),
            .jsonb(name: "jsonb_val"),
            .inet(name: "inet_val")
        ])
        cleanupSQL("DROP TABLE IF EXISTS \(tableName)")

        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["bool_val", "uuid_val", "jsonb_val", "inet_val"],
            values: [[
                PostgresInsertValue.null,
                PostgresInsertValue.null,
                PostgresInsertValue.null,
                PostgresInsertValue.null
            ]]
        )

        let result = try await query("""
            SELECT bool_val, uuid_val, jsonb_val, inet_val FROM \(tableName)
        """)
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        for i in 0..<4 {
            XCTAssertNil(result.rows[0][i], "Column \(i) should be NULL")
        }
    }

    // MARK: - Enum Type

    func testCustomEnumType() async throws {
        let typeName = uniqueName(prefix: "mood")
        try await execute("CREATE TYPE \(typeName) AS ENUM ('happy', 'sad', 'neutral')")
        cleanupSQL("DROP TYPE IF EXISTS \(typeName)")

        let result = try await query("SELECT 'happy'::\(typeName) AS val")
        XCTAssertEqual(result.rows[0][0], "happy")
    }

    // MARK: - Composite Type

    func testHstoreIfAvailable() async throws {
        do {
            try await execute("CREATE EXTENSION IF NOT EXISTS hstore")
        } catch {
            throw XCTSkip("hstore extension not available")
        }

        let result = try await query("SELECT 'key => value'::HSTORE AS val")
        XCTAssertNotNil(result.rows[0][0])
    }
}
