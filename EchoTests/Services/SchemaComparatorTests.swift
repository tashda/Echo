import XCTest
@testable import Echo

final class SchemaComparatorTests: XCTestCase {

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

    private func makeDB(
        name: String = "testdb",
        schemas: [SchemaInfo] = []
    ) -> DatabaseInfo {
        DatabaseInfo(name: name, schemas: schemas)
    }

    // MARK: - Both nil

    func testBothNilReturnsZeros() {
        let result = SchemaComparator.diff(old: nil, new: nil)
        XCTAssertEqual(result.inserted, 0)
        XCTAssertEqual(result.removed, 0)
        XCTAssertEqual(result.changed, 0)
    }

    // MARK: - New is nil

    func testNewNilReturnsZeros() {
        let old = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [makeObject(name: "users")])
        ])
        let result = SchemaComparator.diff(old: old, new: nil)
        XCTAssertEqual(result.inserted, 0)
        XCTAssertEqual(result.removed, 0)
        XCTAssertEqual(result.changed, 0)
    }

    // MARK: - Old is nil (everything is new)

    func testOldNilCountsAllAsInserted() {
        let new = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users"),
                makeObject(name: "posts")
            ])
        ])
        let result = SchemaComparator.diff(old: nil, new: new)
        XCTAssertEqual(result.inserted, 2)
        XCTAssertEqual(result.removed, 0)
        XCTAssertEqual(result.changed, 0)
    }

    // MARK: - Identical schemas

    func testIdenticalSchemasReturnZeros() {
        let objects = [makeObject(name: "users"), makeObject(name: "posts")]
        let schema = SchemaInfo(name: "public", objects: objects)
        let old = makeDB(schemas: [schema])
        let new = makeDB(schemas: [schema])
        let result = SchemaComparator.diff(old: old, new: new)
        XCTAssertEqual(result.inserted, 0)
        XCTAssertEqual(result.removed, 0)
        XCTAssertEqual(result.changed, 0)
    }

    // MARK: - Inserted tables

    func testInsertedTablesDetected() {
        let old = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [makeObject(name: "users")])
        ])
        let new = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users"),
                makeObject(name: "posts"),
                makeObject(name: "comments")
            ])
        ])
        let result = SchemaComparator.diff(old: old, new: new)
        XCTAssertEqual(result.inserted, 2)
        XCTAssertEqual(result.removed, 0)
        XCTAssertEqual(result.changed, 0)
    }

    // MARK: - Removed tables

    func testRemovedTablesDetected() {
        let old = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users"),
                makeObject(name: "posts"),
                makeObject(name: "comments")
            ])
        ])
        let new = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [makeObject(name: "users")])
        ])
        let result = SchemaComparator.diff(old: old, new: new)
        XCTAssertEqual(result.inserted, 0)
        XCTAssertEqual(result.removed, 2)
        XCTAssertEqual(result.changed, 0)
    }

    // MARK: - Changed column count

    func testChangedColumnCountDetected() {
        let old = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users", columns: [makeColumn("id"), makeColumn("name")])
            ])
        ])
        let new = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users", columns: [makeColumn("id"), makeColumn("name"), makeColumn("email")])
            ])
        ])
        let result = SchemaComparator.diff(old: old, new: new)
        XCTAssertEqual(result.inserted, 0)
        XCTAssertEqual(result.removed, 0)
        XCTAssertEqual(result.changed, 1)
    }

    // MARK: - Changed comment

    func testChangedCommentDetected() {
        let old = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users", comment: "Old comment")
            ])
        ])
        let new = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users", comment: "New comment")
            ])
        ])
        let result = SchemaComparator.diff(old: old, new: new)
        XCTAssertEqual(result.changed, 1)
    }

    // MARK: - Comment nil vs empty treated as same

    func testNilCommentAndEmptyCommentAreSame() {
        let old = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users", comment: nil)
            ])
        ])
        let new = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users", comment: "")
            ])
        ])
        let result = SchemaComparator.diff(old: old, new: new)
        XCTAssertEqual(result.changed, 0)
    }

    // MARK: - Mixed insert, remove, change

    func testMixedInsertRemoveChange() {
        let old = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users", columns: [makeColumn("id")]),
                makeObject(name: "posts"),
                makeObject(name: "tags")
            ])
        ])
        let new = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users", columns: [makeColumn("id"), makeColumn("email")]),
                makeObject(name: "posts"),
                makeObject(name: "comments")
            ])
        ])
        let result = SchemaComparator.diff(old: old, new: new)
        XCTAssertEqual(result.inserted, 1, "comments is new")
        XCTAssertEqual(result.removed, 1, "tags was removed")
        XCTAssertEqual(result.changed, 1, "users column count changed")
    }

    // MARK: - Different object types with same name

    func testDifferentObjectTypesAreDistinct() {
        let old = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users", type: .table)
            ])
        ])
        let new = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [
                makeObject(name: "users", type: .table),
                makeObject(name: "users", type: .view)
            ])
        ])
        let result = SchemaComparator.diff(old: old, new: new)
        XCTAssertEqual(result.inserted, 1, "view 'users' is a new object")
        XCTAssertEqual(result.removed, 0)
    }

    // MARK: - Multiple schemas

    func testMultipleSchemasFlattened() {
        let old = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [makeObject(name: "a", schema: "public")]),
            SchemaInfo(name: "auth", objects: [makeObject(name: "b", schema: "auth")])
        ])
        let new = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [makeObject(name: "a", schema: "public")]),
            SchemaInfo(name: "auth", objects: [
                makeObject(name: "b", schema: "auth"),
                makeObject(name: "c", schema: "auth")
            ])
        ])
        let result = SchemaComparator.diff(old: old, new: new)
        XCTAssertEqual(result.inserted, 1)
        XCTAssertEqual(result.removed, 0)
        XCTAssertEqual(result.changed, 0)
    }

    // MARK: - Empty schemas

    func testEmptyOldAndNewWithObjects() {
        let old = makeDB(schemas: [])
        let new = makeDB(schemas: [
            SchemaInfo(name: "public", objects: [makeObject(name: "users")])
        ])
        let result = SchemaComparator.diff(old: old, new: new)
        XCTAssertEqual(result.inserted, 1)
        XCTAssertEqual(result.removed, 0)
    }
}
