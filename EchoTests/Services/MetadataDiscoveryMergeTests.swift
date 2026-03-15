import XCTest
@testable import Echo

@MainActor
final class MetadataDiscoveryMergeTests: XCTestCase {

    // MARK: - Helpers

    private func makeObject(
        name: String,
        schema: String = "public",
        type: SchemaObjectInfo.ObjectType = .table,
        columns: [ColumnInfo] = [],
        comment: String? = nil
    ) -> SchemaObjectInfo {
        SchemaObjectInfo(name: name, schema: schema, type: type, columns: columns, comment: comment)
    }

    private func makeColumn(_ name: String) -> ColumnInfo {
        ColumnInfo(name: name, dataType: "text")
    }

    // MARK: - mergeDatabaseInfo

    func testMergeDatabaseInfoWithNilExistingReturnsPartialSorted() {
        let partial = DatabaseInfo(name: "mydb", schemas: [
            SchemaInfo(name: "zeta", objects: [makeObject(name: "t1", schema: "zeta")]),
            SchemaInfo(name: "alpha", objects: [makeObject(name: "t2", schema: "alpha")])
        ], schemaCount: 2)

        let result = MetadataDiscoveryEngine.mergeDatabaseInfo(partial: partial, existing: nil)

        XCTAssertEqual(result.name, "mydb")
        XCTAssertEqual(result.schemas.count, 2)
        XCTAssertEqual(result.schemas[0].name, "alpha", "Schemas should be sorted alphabetically")
        XCTAssertEqual(result.schemas[1].name, "zeta")
        XCTAssertEqual(result.schemaCount, 2)
    }

    func testMergeDatabaseInfoPreservesExistingName() {
        let partial = DatabaseInfo(name: "newname", schemas: [
            SchemaInfo(name: "public", objects: [makeObject(name: "new_table")])
        ], schemaCount: 1)
        let existing = DatabaseInfo(name: "original", schemas: [
            SchemaInfo(name: "public", objects: [makeObject(name: "old_table")])
        ], schemaCount: 1)

        let result = MetadataDiscoveryEngine.mergeDatabaseInfo(partial: partial, existing: existing)

        XCTAssertEqual(result.name, "original", "Should preserve existing database name")
    }

    func testMergeDatabaseInfoCombinesSchemasFromBoth() {
        let partial = DatabaseInfo(name: "db", schemas: [
            SchemaInfo(name: "new_schema", objects: [makeObject(name: "t1", schema: "new_schema")])
        ], schemaCount: 1)
        let existing = DatabaseInfo(name: "db", schemas: [
            SchemaInfo(name: "old_schema", objects: [makeObject(name: "t2", schema: "old_schema")])
        ], schemaCount: 1)

        let result = MetadataDiscoveryEngine.mergeDatabaseInfo(partial: partial, existing: existing)

        XCTAssertEqual(result.schemas.count, 2)
        let names = result.schemas.map(\.name)
        XCTAssertTrue(names.contains("new_schema"))
        XCTAssertTrue(names.contains("old_schema"))
    }

    func testMergeDatabaseInfoSchemaCountIsMax() {
        let partial = DatabaseInfo(name: "db", schemas: [], schemaCount: 5)
        let existing = DatabaseInfo(name: "db", schemas: [], schemaCount: 10)

        let result = MetadataDiscoveryEngine.mergeDatabaseInfo(partial: partial, existing: existing)

        XCTAssertEqual(result.schemaCount, 10, "Should use the max of existing and partial schema counts")
    }

    func testMergeDatabaseInfoSchemasSortedAlphabetically() {
        let partial = DatabaseInfo(name: "db", schemas: [
            SchemaInfo(name: "charlie", objects: []),
            SchemaInfo(name: "alpha", objects: [])
        ])
        let existing = DatabaseInfo(name: "db", schemas: [
            SchemaInfo(name: "bravo", objects: [])
        ])

        let result = MetadataDiscoveryEngine.mergeDatabaseInfo(partial: partial, existing: existing)

        XCTAssertEqual(result.schemas.map(\.name), ["alpha", "bravo", "charlie"])
    }

    // MARK: - mergeSchemas

    func testMergeSchemasAddsNewSchemas() {
        let partial = [
            SchemaInfo(name: "new_schema", objects: [makeObject(name: "t1", schema: "new_schema")])
        ]
        let existing = [
            SchemaInfo(name: "existing_schema", objects: [makeObject(name: "t2", schema: "existing_schema")])
        ]

        let result = MetadataDiscoveryEngine.mergeSchemas(partialSchemas: partial, existingSchemas: existing)

        XCTAssertEqual(result.count, 2)
        let names = Set(result.map(\.name))
        XCTAssertTrue(names.contains("new_schema"))
        XCTAssertTrue(names.contains("existing_schema"))
    }

    func testMergeSchemasUpdatesExistingSchema() {
        // Partial is authoritative: objects not in partial are considered dropped.
        let partial = [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "new_table"),
                makeObject(name: "updated_table", columns: [makeColumn("col1"), makeColumn("col2")])
            ])
        ]
        let existing = [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "old_table"),
                makeObject(name: "updated_table", columns: [makeColumn("col1")])
            ])
        ]

        let result = MetadataDiscoveryEngine.mergeSchemas(partialSchemas: partial, existingSchemas: existing)

        XCTAssertEqual(result.count, 1)
        let publicSchema = result.first { $0.name == "public" }!
        let objectNames = Set(publicSchema.objects.map(\.name))
        XCTAssertFalse(objectNames.contains("old_table"), "Objects not in partial are considered dropped")
        XCTAssertTrue(objectNames.contains("new_table"), "New objects should be added")
        XCTAssertTrue(objectNames.contains("updated_table"), "Updated objects should be present")
    }

    func testMergeSchemasEmptyPartialPreservesExisting() {
        let existing = [
            SchemaInfo(name: "public", objects: [makeObject(name: "users")])
        ]

        let result = MetadataDiscoveryEngine.mergeSchemas(partialSchemas: [], existingSchemas: existing)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].objects.count, 1)
    }

    func testMergeSchemasEmptyExistingReturnsPartial() {
        let partial = [
            SchemaInfo(name: "public", objects: [makeObject(name: "users")])
        ]

        let result = MetadataDiscoveryEngine.mergeSchemas(partialSchemas: partial, existingSchemas: [])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "public")
    }

    // MARK: - mergeSchemaInfo

    func testMergeSchemaInfoOverwritesExistingObjectsByID() {
        let partial = SchemaInfo(name: "public", objects: [
            makeObject(name: "users", columns: [makeColumn("id"), makeColumn("name"), makeColumn("email")])
        ])
        let existing = SchemaInfo(name: "public", objects: [
            makeObject(name: "users", columns: [makeColumn("id"), makeColumn("name")])
        ])

        let result = MetadataDiscoveryEngine.mergeSchemaInfo(partial: partial, existing: existing)

        XCTAssertEqual(result.name, "public")
        let users = result.objects.first { $0.name == "users" }!
        XCTAssertEqual(users.columns.count, 3, "Partial object should overwrite existing by ID")
    }

    func testMergeSchemaInfoDropsExistingObjectsNotInPartial() {
        // Partial is authoritative: objects not in partial are considered dropped from the server.
        let partial = SchemaInfo(name: "public", objects: [
            makeObject(name: "new_table")
        ])
        let existing = SchemaInfo(name: "public", objects: [
            makeObject(name: "old_table")
        ])

        let result = MetadataDiscoveryEngine.mergeSchemaInfo(partial: partial, existing: existing)

        let names = Set(result.objects.map(\.name))
        XCTAssertFalse(names.contains("old_table"), "Objects not in partial are dropped")
        XCTAssertTrue(names.contains("new_table"))
    }

    func testMergeSchemaInfoResultIsSortedAlphabetically() {
        // Partial is authoritative, so only partial objects survive (mango is dropped).
        let partial = SchemaInfo(name: "public", objects: [
            makeObject(name: "zebra"),
            makeObject(name: "apple")
        ])
        let existing = SchemaInfo(name: "public", objects: [
            makeObject(name: "mango")
        ])

        let result = MetadataDiscoveryEngine.mergeSchemaInfo(partial: partial, existing: existing)

        XCTAssertEqual(result.objects.map(\.name), ["apple", "zebra"])
    }

    func testMergeSchemaInfoPreservesExistingSchemaName() {
        let partial = SchemaInfo(name: "ignored", objects: [])
        let existing = SchemaInfo(name: "public", objects: [])

        let result = MetadataDiscoveryEngine.mergeSchemaInfo(partial: partial, existing: existing)

        XCTAssertEqual(result.name, "public")
    }

    func testMergeSchemaInfoEmptyPartialPreservesAll() {
        let existing = SchemaInfo(name: "public", objects: [
            makeObject(name: "users"),
            makeObject(name: "posts")
        ])

        let result = MetadataDiscoveryEngine.mergeSchemaInfo(
            partial: SchemaInfo(name: "public", objects: []),
            existing: existing
        )

        XCTAssertEqual(result.objects.count, 2)
    }

    func testMergeSchemaInfoDifferentObjectTypesShareID() {
        // SchemaObjectInfo.id is "\(schema).\(name)" (i.e. fullName), so a table and view
        // with the same schema+name have the same ID. The merge deduplicates by ID,
        // meaning the partial (view) overwrites the existing (table).
        let partial = SchemaInfo(name: "public", objects: [
            makeObject(name: "users", type: .view)
        ])
        let existing = SchemaInfo(name: "public", objects: [
            makeObject(name: "users", type: .table)
        ])

        let result = MetadataDiscoveryEngine.mergeSchemaInfo(partial: partial, existing: existing)

        XCTAssertEqual(result.objects.count, 1, "Table and view with same schema.name share the same ID, so partial overwrites existing")
        XCTAssertEqual(result.objects.first?.type, .view, "Partial object should overwrite existing")
    }
}
