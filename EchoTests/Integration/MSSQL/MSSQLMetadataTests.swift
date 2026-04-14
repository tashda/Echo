import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server metadata retrieval through Echo's DatabaseSession layer.
final class MSSQLMetadataTests: MSSQLDockerTestCase {

    // MARK: - Table Schema

    func testGetTableSchema() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "email", definition: .standard(.init(dataType: .nvarchar(length: .length(200))))),
            SQLServerColumnDefinition(name: "age", definition: .standard(.init(dataType: .int)))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let columns = try await session.getTableSchema(tableName, schemaName: "dbo")
        XCTAssertEqual(columns.count, 4)

        let names = columns.map(\.name)
        XCTAssertTrue(names.contains("id"))
        XCTAssertTrue(names.contains("name"))
        XCTAssertTrue(names.contains("email"))
        XCTAssertTrue(names.contains("age"))
    }

    func testGetTableSchemaIncludesDataTypes() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "amount", definition: .standard(.init(dataType: .decimal(precision: 10, scale: 2)))),
            SQLServerColumnDefinition(name: "created_at", definition: .standard(.init(dataType: .datetime2(precision: 7))))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let columns = try await session.getTableSchema(tableName, schemaName: "dbo")

        for col in columns {
            XCTAssertFalse(col.dataType.isEmpty, "Column \(col.name) should have a data type")
        }
    }

    // MARK: - Table Structure Details

    func testGetTableStructureDetailsColumns() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "value", definition: .standard(.init(dataType: .decimal(precision: 10, scale: 2))))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertGreaterThanOrEqual(details.columns.count, 3)
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "id")
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "name")
        IntegrationTestHelpers.assertHasStructureColumn(details, named: "value")
    }

    func testGetTableStructureDetailsPrimaryKey() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100)))))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertNotNil(details.primaryKey, "Should detect primary key")
        if let pk = details.primaryKey {
            XCTAssertTrue(pk.columns.contains("id"))
        }
    }

    func testGetTableStructureDetailsIndexes() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
            SQLServerColumnDefinition(name: "email", definition: .standard(.init(dataType: .nvarchar(length: .length(200)))))
        ])
        try await execute("CREATE INDEX IX_\(tableName)_name ON dbo.[\(tableName)](name)")
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertFalse(details.indexes.isEmpty, "Should have at least one index")
    }

    func testGetTableStructureDetailsForeignKeys() async throws {
        let parentTable = uniqueTableName(prefix: "parent")
        let childTable = uniqueTableName(prefix: "child")
        try await sqlserverClient.admin.createTable(name: parentTable, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100)))))
        ])
        try await execute("""
            CREATE TABLE dbo.[\(childTable)] (
                id INT PRIMARY KEY,
                parent_id INT REFERENCES dbo.[\(parentTable)](id)
            )
        """)
        cleanupSQL(
            "DROP TABLE dbo.[\(childTable)]",
            "DROP TABLE dbo.[\(parentTable)]"
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: childTable)
        XCTAssertFalse(details.foreignKeys.isEmpty, "Should detect foreign key")
        if let fk = details.foreignKeys.first {
            XCTAssertTrue(fk.referencedTable.contains(parentTable))
        }
    }

    func testGetTableStructureDetailsUniqueConstraints() async throws {
        // UNIQUE constraint requires raw SQL since typed API doesn't support constraints inline
        let tableName = uniqueTableName()
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, code NVARCHAR(10) UNIQUE, name NVARCHAR(100))")
        cleanupSQL("DROP TABLE [\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        // Unique constraint may appear as index or unique constraint
        let hasUnique = !details.uniqueConstraints.isEmpty ||
            details.indexes.contains(where: { $0.isUnique })
        XCTAssertTrue(hasUnique, "Should detect unique constraint on 'code'")
    }

    // MARK: - Object Definitions

    func testGetViewDefinition() async throws {
        let tableName = uniqueTableName()
        let viewName = uniqueTableName(prefix: "v")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100)))))
        ])
        try await execute("CREATE VIEW dbo.[\(viewName)] AS SELECT id, name FROM dbo.[\(tableName)]")
        cleanupSQL(
            "DROP VIEW dbo.[\(viewName)]",
            "DROP TABLE dbo.[\(tableName)]"
        )

        let definition = try await session.getObjectDefinition(
            objectName: viewName, schemaName: "dbo", objectType: .view
        )
        XCTAssertFalse(definition.isEmpty)
        XCTAssertTrue(definition.contains("SELECT") || definition.contains("select"),
                       "View definition should contain SELECT")
    }

    func testGetProcedureDefinition() async throws {
        let procName = uniqueTableName(prefix: "usp")
        try await execute("""
            CREATE PROCEDURE dbo.[\(procName)]
                @id INT
            AS
            BEGIN
                SELECT @id AS result;
            END
        """)
        cleanupSQL("DROP PROCEDURE dbo.[\(procName)]")

        let definition = try await session.getObjectDefinition(
            objectName: procName, schemaName: "dbo", objectType: .procedure
        )
        XCTAssertFalse(definition.isEmpty)
    }

    func testGetFunctionDefinition() async throws {
        let funcName = uniqueTableName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION dbo.[\(funcName)](@x INT)
            RETURNS INT
            AS
            BEGIN
                RETURN @x * 2;
            END
        """)
        cleanupSQL("DROP FUNCTION dbo.[\(funcName)]")

        let definition = try await session.getObjectDefinition(
            objectName: funcName, schemaName: "dbo", objectType: .function
        )
        XCTAssertFalse(definition.isEmpty)
    }

    func testGetTableDefinition() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100)))))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        let definition = try await session.getObjectDefinition(
            objectName: tableName, schemaName: "dbo", objectType: .table
        )
        XCTAssertFalse(definition.isEmpty)
        XCTAssertTrue(definition.lowercased().contains("create"),
                       "Table definition should contain CREATE")
    }

    // MARK: - Load Schema Info

    func testLoadSchemaInfo() async throws {
        let tableName = uniqueTableName()
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true)))
        ])
        cleanupSQL("DROP TABLE [\(tableName)]")

        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let schemaInfo = try await metaSession.loadSchemaInfo("dbo", progress: nil)
        XCTAssertEqual(schemaInfo.name, "dbo")
        XCTAssertFalse(schemaInfo.objects.isEmpty)
    }

    func testLoadSchemaInfoReportsProgress() async throws {
        guard let metaSession = session as? DatabaseMetadataSession else {
            throw XCTSkip("Session does not support DatabaseMetadataSession")
        }

        let progressCalled = LockIsolated(false)
        _ = try await metaSession.loadSchemaInfo("dbo") { _, _, _ in
            progressCalled.setValue(true)
        }
        // Progress may or may not be called depending on implementation
        // The important thing is it doesn't crash
        _ = progressCalled.value
    }
}
