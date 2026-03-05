import XCTest
@testable import Echo

final class DatabaseStructureTests: XCTestCase {

    // MARK: - Codable Round-Trip

    func testDatabaseStructureCodableRoundTrip() throws {
        let structure = TestFixtures.databaseStructure(
            serverVersion: "15.2",
            databaseCount: 2,
            schemasPerDatabase: 2,
            tablesPerSchema: 3
        )

        let data = try JSONEncoder().encode(structure)
        let decoded = try JSONDecoder().decode(DatabaseStructure.self, from: data)

        XCTAssertEqual(decoded.serverVersion, "15.2")
        XCTAssertEqual(decoded.databases.count, 2)
        XCTAssertEqual(decoded.databases[0].schemas.count, 2)
        XCTAssertEqual(decoded.databases[0].schemas[0].objects.count, 3)
    }

    func testDatabaseInfoCodableRoundTrip() throws {
        let info = DatabaseInfo(
            name: "production",
            schemas: [SchemaInfo(name: "public", objects: [])],
            schemaCount: 1
        )

        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(DatabaseInfo.self, from: data)

        XCTAssertEqual(decoded.name, "production")
        XCTAssertEqual(decoded.id, "production")
        XCTAssertEqual(decoded.schemas.count, 1)
    }

    // MARK: - SchemaInfo Computed Filters

    func testSchemaInfoTables() {
        let objects: [SchemaObjectInfo] = [
            TestFixtures.schemaObjectInfo(name: "users", type: .table),
            TestFixtures.schemaObjectInfo(name: "orders", type: .table),
            TestFixtures.schemaObjectInfo(name: "user_view", type: .view),
            TestFixtures.schemaObjectInfo(name: "audit_fn", type: .function),
        ]
        let schema = SchemaInfo(name: "public", objects: objects)

        XCTAssertEqual(schema.tables.count, 2)
        XCTAssertEqual(schema.views.count, 1)
        XCTAssertEqual(schema.functions.count, 1)
        XCTAssertEqual(schema.triggers.count, 0)
        XCTAssertEqual(schema.procedures.count, 0)
    }

    func testSchemaInfoAllObjectTypes() {
        let objects: [SchemaObjectInfo] = [
            TestFixtures.schemaObjectInfo(name: "t1", type: .table),
            TestFixtures.schemaObjectInfo(name: "v1", type: .view),
            TestFixtures.schemaObjectInfo(name: "mv1", type: .materializedView),
            TestFixtures.schemaObjectInfo(name: "f1", type: .function),
            TestFixtures.schemaObjectInfo(name: "tr1", type: .trigger),
            TestFixtures.schemaObjectInfo(name: "p1", type: .procedure),
        ]
        let schema = SchemaInfo(name: "public", objects: objects)

        XCTAssertEqual(schema.tables.count, 1)
        XCTAssertEqual(schema.views.count, 1)
        XCTAssertEqual(schema.materializedViews.count, 1)
        XCTAssertEqual(schema.functions.count, 1)
        XCTAssertEqual(schema.triggers.count, 1)
        XCTAssertEqual(schema.procedures.count, 1)
        XCTAssertEqual(schema.allObjects.count, 6)
    }

    // MARK: - SchemaObjectInfo

    func testSchemaObjectInfoFullName() {
        let obj = TestFixtures.schemaObjectInfo(name: "users", schema: "public")
        XCTAssertEqual(obj.fullName, "public.users")
    }

    func testSchemaObjectInfoIDUniquenessForTriggers() {
        let trigger1 = SchemaObjectInfo(
            name: "audit_trigger",
            schema: "public",
            type: .trigger,
            triggerAction: "INSERT",
            triggerTable: "users"
        )
        let trigger2 = SchemaObjectInfo(
            name: "audit_trigger",
            schema: "public",
            type: .trigger,
            triggerAction: "DELETE",
            triggerTable: "users"
        )

        // Triggers with same name but different actions should have different IDs
        XCTAssertNotEqual(trigger1.id, trigger2.id)
    }

    // MARK: - TableStructureDetails

    func testTableStructureDetailsCodableRoundTrip() throws {
        let details = TestFixtures.tableStructureDetails(columnCount: 5, primaryKeyName: "pk_users")

        let data = try JSONEncoder().encode(details)
        let decoded = try JSONDecoder().decode(TableStructureDetails.self, from: data)

        XCTAssertEqual(decoded.columns.count, 5)
        XCTAssertEqual(decoded.primaryKey?.name, "pk_users")
    }
}
