import XCTest
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
        try await withTempTable(
            columns: "id INT PRIMARY KEY, img IMAGE"
        ) { tableName in
            try await execute("""
                INSERT INTO [\(tableName)] VALUES (1, 0x89504E470D0A1A0A)
            """)

            let result = try await query("SELECT * FROM [\(tableName)]")
            IntegrationTestHelpers.assertRowCount(result, expected: 1)
            XCTAssertNotNil(result.rows[0][1], "Image column should have a value")
        }
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
        try await withTempTable(
            columns: "id INT PRIMARY KEY, guid UNIQUEIDENTIFIER DEFAULT NEWID()"
        ) { tableName in
            try await execute("INSERT INTO [\(tableName)] (id) VALUES (1), (2), (3)")

            let result = try await query("SELECT * FROM [\(tableName)] ORDER BY id")
            IntegrationTestHelpers.assertRowCount(result, expected: 3)

            // All GUIDs should be unique
            let guids = result.rows.compactMap { $0[1] }
            XCTAssertEqual(guids.count, 3, "All GUIDs should be non-null")
            XCTAssertEqual(Set(guids).count, 3, "All GUIDs should be unique")
        }
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
        try await withTempTable(
            columns: "id INT PRIMARY KEY, data XML"
        ) { tableName in
            try await execute("""
                INSERT INTO [\(tableName)] VALUES
                    (1, '<doc><title>Test</title><body>Content</body></doc>'),
                    (2, '<config><setting name="debug" value="true"/></config>')
            """)

            let result = try await query("SELECT * FROM [\(tableName)] ORDER BY id")
            IntegrationTestHelpers.assertRowCount(result, expected: 2)
            XCTAssertTrue(result.rows[0][1]?.contains("Test") ?? false)
            XCTAssertTrue(result.rows[1][1]?.contains("debug") ?? false)
        }
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
        try await withTempTable(
            columns: "id INT PRIMARY KEY, val SQL_VARIANT"
        ) { tableName in
            try await execute("""
                INSERT INTO [\(tableName)] VALUES
                    (1, CAST(100 AS INT)),
                    (2, CAST('text value' AS NVARCHAR(50))),
                    (3, CAST(3.14159 AS FLOAT))
            """)

            let result = try await query("SELECT * FROM [\(tableName)] ORDER BY id")
            IntegrationTestHelpers.assertRowCount(result, expected: 3)
            for i in 0..<3 {
                XCTAssertNotNil(result.rows[i][1], "Row \(i) variant should not be null")
            }
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
            try await withTempTable(
                columns: "id INT PRIMARY KEY, node HIERARCHYID"
            ) { tableName in
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
            }
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
            try await withTempTable(
                columns: "id INT PRIMARY KEY, location GEOGRAPHY"
            ) { tableName in
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
            }
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
        try await withTempTable(
            columns: """
                id INT PRIMARY KEY,
                bin_col BINARY(8),
                varbin_col VARBINARY(100),
                varbin_max_col VARBINARY(MAX),
                guid_col UNIQUEIDENTIFIER,
                xml_col XML
            """
        ) { tableName in
            try await execute("""
                INSERT INTO [\(tableName)] VALUES (
                    1,
                    0x0102030405060708,
                    0xDEADBEEF,
                    0xCAFEBABE00112233,
                    NEWID(),
                    '<data><value>42</value></data>'
                )
            """)

            let result = try await query("SELECT * FROM [\(tableName)]")
            IntegrationTestHelpers.assertRowCount(result, expected: 1)
            XCTAssertEqual(result.columns.count, 6)

            for (i, col) in result.columns.enumerated() {
                XCTAssertNotNil(result.rows[0][i], "Column \(col.name) should have a value")
            }
        }
    }

    // MARK: - Binary Comparison

    func testBinaryComparison() async throws {
        try await withTempTable(
            columns: "id INT PRIMARY KEY, data VARBINARY(100)"
        ) { tableName in
            try await execute("""
                INSERT INTO [\(tableName)] VALUES
                    (1, 0x0001),
                    (2, 0x00FF),
                    (3, 0xFF00),
                    (4, 0xFFFF)
            """)

            let result = try await query("""
                SELECT id, data FROM [\(tableName)]
                WHERE data > 0x00FF
                ORDER BY data
            """)
            // 0xFF00 and 0xFFFF are > 0x00FF
            IntegrationTestHelpers.assertRowCount(result, expected: 2)
        }
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
