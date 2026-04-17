import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server binary and special data type round-trips through Echo's DatabaseSession layer.
final class MSSQLDataTypeBinaryTests: MSSQLDockerTestCase {

    // MARK: - BINARY

    func testBinaryType() async throws {
        let result = try await query("SELECT CAST(0x48454C4C4F AS BINARY(5)) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testBinaryFixedLength() async throws {
        // BINARY(10) pads with zeros
        let result = try await query("SELECT CAST(0x4142 AS BINARY(10)) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - VARBINARY

    func testVarbinaryType() async throws {
        let result = try await query("SELECT CAST(0x48454C4C4F AS VARBINARY(100)) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testVarbinarySmall() async throws {
        let result = try await query("SELECT CAST(0xFF AS VARBINARY(1)) AS val")
        XCTAssertNotNil(result.rows[0][0])
    }

    func testVarbinaryMax() async throws {
        let result = try await query("""
            SELECT CAST(REPLICATE(CAST(0xABCD AS VARBINARY(MAX)), 100) AS VARBINARY(MAX)) AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
    }

    func testVarbinaryMaxLargePayload() async throws {
        // Generate a reasonably large binary value
        let result = try await query("""
            SELECT CAST(
                REPLICATE(CAST('ABCDEF0123456789' AS VARBINARY(MAX)), 500)
            AS VARBINARY(MAX)) AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
    }

    // MARK: - IMAGE (Legacy)

    func testImageType() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "img", definition: .standard(.init(dataType: .image)))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        _ = try await sqlserverClient.admin.insertRow(into: tableName, values: [
            "id": .int(1),
            "img": .raw("0x89504E470D0A1A0A")
        ])

        let result = try await query("SELECT * FROM [\(tableName)]")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertNotNil(result.rows[0][1], "Image column should have a value")
    }

    // MARK: - UNIQUEIDENTIFIER

    func testUniqueidentifierType() async throws {
        let result = try await query("SELECT NEWID() AS val")
        XCTAssertNotNil(result.rows[0][0])
        let guid = result.rows[0][0] ?? ""
        // GUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        XCTAssertEqual(guid.count, 36, "GUID should be 36 chars including hyphens")
        XCTAssertEqual(guid.filter({ $0 == "-" }).count, 4, "GUID should have 4 hyphens")
    }

    func testUniqueidentifierSpecificValue() async throws {
        let testGuid = "6F9619FF-8B86-D011-B42D-00C04FC964FF"
        let result = try await query(
            "SELECT CAST('\(testGuid)' AS UNIQUEIDENTIFIER) AS val"
        )
        XCTAssertNotNil(result.rows[0][0])
        // GUID comparison is case-insensitive
        XCTAssertEqual(
            result.rows[0][0]?.uppercased(),
            testGuid.uppercased()
        )
    }

    func testUniqueidentifierRoundTrip() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "guid", definition: .standard(.init(dataType: .uniqueidentifier)))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let uuids = [UUID(), UUID(), UUID()]
        _ = try await sqlserverClient.admin.insertRows(
            into: tableName,
            columns: ["id", "guid"],
            values: [
                [.int(1), .uuid(uuids[0])],
                [.int(2), .uuid(uuids[1])],
                [.int(3), .uuid(uuids[2])]
            ]
        )

        let result = try await query("SELECT * FROM [\(tableName)] ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 3)

        let guids = result.rows.compactMap { $0[1] }
        XCTAssertEqual(guids.count, 3, "All GUIDs should be non-null")
        XCTAssertEqual(Set(guids).count, 3, "All GUIDs should be unique")

        // Verify byte-order correctness: displayed GUID must match what was inserted.
        // SQL Server uses mixed-endian storage; incorrect byte swapping produces a
        // different string that SQL Server cannot find via WHERE pk = 'displayed-guid'.
        for (index, uuid) in uuids.enumerated() {
            let expected = uuid.uuidString.uppercased()
            let actual = guids[index].uppercased()
            XCTAssertEqual(actual, expected, "GUID at row \(index + 1) must round-trip correctly through SQL Server's mixed-endian encoding")
        }
    }

    func testUniqueidentifierWhereClause() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .uniqueidentifier, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "val", definition: .standard(.init(dataType: .nvarchar(length: .length(50)))))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let knownGuid = UUID()
        _ = try await sqlserverClient.admin.insertRow(
            into: tableName,
            values: ["id": .uuid(knownGuid), "val": .nString("hello")]
        )

        // Read the row back first to get what Echo displays.
        let allRows = try await query("SELECT * FROM [\(tableName)]")
        IntegrationTestHelpers.assertRowCount(allRows, expected: 1)
        let displayedGuid = allRows.rows[0][0] ?? ""
        XCTAssertFalse(displayedGuid.isEmpty, "Displayed GUID must not be empty")

        // The displayed GUID must equal the original UUID (case-insensitive).
        XCTAssertEqual(displayedGuid.uppercased(), knownGuid.uuidString.uppercased(),
            "Displayed GUID must match the inserted UUID; incorrect byte-swap causes WHERE clause lookups to fail")

        // Query by the displayed GUID — this must return exactly one row.
        let filtered = try await query("SELECT * FROM [\(tableName)] WHERE [id] = '\(displayedGuid)'")
        IntegrationTestHelpers.assertRowCount(filtered, expected: 1)
    }

    // MARK: - XML

    func testXmlType() async throws {
        let result = try await query("""
            SELECT CAST('<root><item id="1">Hello</item></root>' AS XML) AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
        let xml = result.rows[0][0] ?? ""
        XCTAssertTrue(xml.contains("<root>"), "XML should contain root element")
        XCTAssertTrue(xml.contains("Hello"), "XML should contain text content")
    }

    func testXmlWithNamespaces() async throws {
        let result = try await query("""
            SELECT CAST('<ns:root xmlns:ns="http://example.com"><ns:item>Test</ns:item></ns:root>' AS XML) AS val
        """)
        XCTAssertNotNil(result.rows[0][0])
        let xml = result.rows[0][0] ?? ""
        XCTAssertTrue(xml.contains("example.com"), "XML should preserve namespace")
    }

    func testXmlRoundTrip() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "data", definition: .standard(.init(dataType: .xml)))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        _ = try await sqlserverClient.admin.insertRows(
            into: tableName,
            columns: ["id", "data"],
            values: [
                [.int(1), .raw("'<doc><title>Test</title><body>Content</body></doc>'")],
                [.int(2), .raw("'<config><setting name=\"debug\" value=\"true\"/></config>'")]
            ]
        )

        let result = try await query("SELECT * FROM [\(tableName)] ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
        XCTAssertTrue(result.rows[0][1]?.contains("Test") ?? false)
        XCTAssertTrue(result.rows[1][1]?.contains("debug") ?? false)
    }

    // MARK: - SQL_VARIANT

    func testSqlVariantType() async throws {
        let result = try await query("""
            SELECT
                CAST(42 AS SQL_VARIANT) AS int_variant,
                CAST('hello' AS SQL_VARIANT) AS str_variant,
                CAST(3.14 AS SQL_VARIANT) AS float_variant
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
        XCTAssertNotNil(result.rows[0][2])
    }

    func testSqlVariantInTable() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "val", definition: .standard(.init(dataType: .sql_variant)))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        // sql_variant requires CAST expressions — insert one at a time to avoid type conflicts
        _ = try await execute("INSERT INTO [\(tableName)] (id, val) VALUES (1, CAST(100 AS INT))")
        _ = try await execute("INSERT INTO [\(tableName)] (id, val) VALUES (2, CAST('text value' AS NVARCHAR(50)))")
        _ = try await execute("INSERT INTO [\(tableName)] (id, val) VALUES (3, CAST(3.14159 AS FLOAT))")

        let result = try await query("SELECT * FROM [\(tableName)] ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 3)
        for i in 0..<3 {
            XCTAssertNotNil(result.rows[i][1], "Row \(i) variant should not be null")
        }
    }

    // MARK: - HIERARCHYID

    func testHierarchyIdType() async throws {
        do {
            let result = try await query("""
                SELECT
                    hierarchyid::GetRoot() AS root_node,
                    hierarchyid::Parse('/1/') AS child1,
                    hierarchyid::Parse('/1/2/') AS grandchild
            """)
            XCTAssertNotNil(result.rows[0][0])
            XCTAssertNotNil(result.rows[0][1])
            XCTAssertNotNil(result.rows[0][2])
        } catch {
            throw XCTSkip("HierarchyId not supported: \(error.localizedDescription)")
        }
    }

    func testHierarchyIdRoundTrip() async throws {
        do {
            // HIERARCHYID is not in the typed API, use raw SQL for table setup
            let tableName = uniqueTableName()
            try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, node HIERARCHYID)")
            cleanupSQL("DROP TABLE [\(tableName)]")

            try await execute("""
                INSERT INTO [\(tableName)] VALUES
                    (1, hierarchyid::GetRoot()),
                    (2, hierarchyid::Parse('/1/')),
                    (3, hierarchyid::Parse('/1/2/')),
                    (4, hierarchyid::Parse('/2/'))
            """)

            let result = try await query("""
                SELECT id, node.ToString() AS node_path
                FROM [\(tableName)]
                ORDER BY node
            """)
            IntegrationTestHelpers.assertRowCount(result, expected: 4)
            XCTAssertEqual(result.rows[0][1], "/")
        } catch {
            throw XCTSkip("HierarchyId not supported: \(error.localizedDescription)")
        }
    }

    // MARK: - GEOGRAPHY / GEOMETRY

    func testGeographyType() async throws {
        do {
            let result = try await query("""
                SELECT geography::Point(47.65100, -122.34900, 4326).ToString() AS seattle
            """)
            XCTAssertNotNil(result.rows[0][0])
            let value = result.rows[0][0] ?? ""
            XCTAssertTrue(value.contains("POINT"), "Geography should serialize as WKT POINT")
        } catch {
            throw XCTSkip("Geography type not supported: \(error.localizedDescription)")
        }
    }

    func testGeometryType() async throws {
        do {
            let result = try await query("""
                SELECT geometry::STGeomFromText('POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))', 0).ToString() AS polygon
            """)
            XCTAssertNotNil(result.rows[0][0])
            let value = result.rows[0][0] ?? ""
            XCTAssertTrue(value.contains("POLYGON"), "Geometry should serialize as WKT POLYGON")
        } catch {
            throw XCTSkip("Geometry type not supported: \(error.localizedDescription)")
        }
    }

    func testGeographyRoundTrip() async throws {
        do {
            // GEOGRAPHY is not in the typed API, use raw SQL for table setup
            let tableName = uniqueTableName()
            try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, location GEOGRAPHY)")
            cleanupSQL("DROP TABLE [\(tableName)]")

            try await execute("""
                INSERT INTO [\(tableName)] VALUES
                    (1, geography::Point(47.651, -122.349, 4326)),
                    (2, geography::Point(40.7128, -74.0060, 4326))
            """)

            let result = try await query("""
                SELECT id, location.ToString() AS wkt,
                       location.Lat AS latitude,
                       location.Long AS longitude
                FROM [\(tableName)]
                ORDER BY id
            """)
            IntegrationTestHelpers.assertRowCount(result, expected: 2)
            IntegrationTestHelpers.assertHasColumn(result, named: "latitude")
            IntegrationTestHelpers.assertHasColumn(result, named: "longitude")
        } catch {
            throw XCTSkip("Geography type not supported: \(error.localizedDescription)")
        }
    }

    // MARK: - NULL Handling

    func testNullBinaryValues() async throws {
        let result = try await query("""
            SELECT CAST(NULL AS BINARY(10)) AS null_binary,
                   CAST(NULL AS VARBINARY(100)) AS null_varbinary,
                   CAST(NULL AS VARBINARY(MAX)) AS null_varbmax,
                   CAST(NULL AS UNIQUEIDENTIFIER) AS null_guid,
                   CAST(NULL AS XML) AS null_xml
        """)
        for i in 0..<5 {
            XCTAssertNil(result.rows[0][i], "Column \(i) should be NULL")
        }
    }

    func testNullSpecialTypes() async throws {
        let result = try await query("""
            SELECT CAST(NULL AS SQL_VARIANT) AS null_variant
        """)
        XCTAssertNil(result.rows[0][0])
    }

    // MARK: - Table Round-Trip

    func testBinaryRoundTripThroughTable() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "bin_col", definition: .standard(.init(dataType: .binary(length: 8)))),
            SQLServerColumnDefinition(name: "varbin_col", definition: .standard(.init(dataType: .varbinary(length: .length(100))))),
            SQLServerColumnDefinition(name: "varbin_max_col", definition: .standard(.init(dataType: .varbinary(length: .max)))),
            SQLServerColumnDefinition(name: "guid_col", definition: .standard(.init(dataType: .uniqueidentifier))),
            SQLServerColumnDefinition(name: "xml_col", definition: .standard(.init(dataType: .xml)))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        _ = try await sqlserverClient.admin.insertRow(into: tableName, values: [
            "id": .int(1),
            "bin_col": .raw("0x0102030405060708"),
            "varbin_col": .raw("0xDEADBEEF"),
            "varbin_max_col": .raw("0xCAFEBABE00112233"),
            "guid_col": .uuid(UUID()),
            "xml_col": .raw("'<data><value>42</value></data>'")
        ])

        let result = try await query("SELECT * FROM [\(tableName)]")
        IntegrationTestHelpers.assertRowCount(result, expected: 1)
        XCTAssertEqual(result.columns.count, 6)

        for (i, col) in result.columns.enumerated() {
            XCTAssertNotNil(result.rows[0][i], "Column \(col.name) should have a value")
        }
    }

    // MARK: - Binary Comparison

    func testBinaryComparison() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "data", definition: .standard(.init(dataType: .varbinary(length: .length(100)))))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        _ = try await sqlserverClient.admin.insertRows(
            into: tableName,
            columns: ["id", "data"],
            values: [
                [.int(1), .raw("0x0001")],
                [.int(2), .raw("0x00FF")],
                [.int(3), .raw("0xFF00")],
                [.int(4), .raw("0xFFFF")]
            ]
        )

        let result = try await query("""
            SELECT id, data FROM [\(tableName)]
            WHERE data > 0x00FF
            ORDER BY data
        """)
        // 0xFF00 and 0xFFFF are > 0x00FF
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }

    // MARK: - HASHBYTES

    func testHashBytesFunction() async throws {
        let result = try await query("""
            SELECT
                HASHBYTES('SHA2_256', 'Hello World') AS sha256_hash,
                HASHBYTES('MD5', 'Hello World') AS md5_hash,
                DATALENGTH(HASHBYTES('SHA2_256', 'Hello World')) AS hash_len
        """)
        XCTAssertNotNil(result.rows[0][0])
        XCTAssertNotNil(result.rows[0][1])
        XCTAssertEqual(result.rows[0][2], "32", "SHA-256 hash should be 32 bytes")
    }
}
