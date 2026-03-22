import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server Phase 3 table designer features through Echo's DatabaseSession layer.
/// Verifies that identity columns, collation, check constraints, INCLUDE columns,
/// table compression, and filegroup all round-trip correctly through
/// `getTableStructureDetails`.
final class MSSQLTableDesignerTests: MSSQLDockerTestCase {

    // MARK: - Identity Columns

    func testIdentityColumn() async throws {
        let tableName = uniqueTableName()
        try await execute("""
            CREATE TABLE dbo.[\(tableName)] (
                id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                name NVARCHAR(100)
            )
        """)
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let idColumn = try XCTUnwrap(details.columns.first(where: { $0.name == "id" }))
        XCTAssertTrue(idColumn.isIdentity, "id column should be an identity column")
        XCTAssertEqual(idColumn.identitySeed, 1, "Identity seed should be 1")
        XCTAssertEqual(idColumn.identityIncrement, 1, "Identity increment should be 1")
    }

    func testIdentityColumnCustomSeed() async throws {
        let tableName = uniqueTableName()
        try await execute("""
            CREATE TABLE dbo.[\(tableName)] (
                id INT IDENTITY(100,5) NOT NULL PRIMARY KEY,
                name NVARCHAR(100)
            )
        """)
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let idColumn = try XCTUnwrap(details.columns.first(where: { $0.name == "id" }))
        XCTAssertTrue(idColumn.isIdentity, "id column should be an identity column")
        XCTAssertEqual(idColumn.identitySeed, 100, "Identity seed should be 100")
        XCTAssertEqual(idColumn.identityIncrement, 5, "Identity increment should be 5")
    }

    // MARK: - Collation

    func testColumnCollation() async throws {
        let tableName = uniqueTableName()
        try await execute("""
            CREATE TABLE dbo.[\(tableName)] (
                id INT NOT NULL PRIMARY KEY,
                name NVARCHAR(100) COLLATE Latin1_General_CI_AS
            )
        """)
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let nameColumn = try XCTUnwrap(details.columns.first(where: { $0.name == "name" }))
        XCTAssertNotNil(nameColumn.collation, "Collation should not be nil for column with explicit COLLATE")
        XCTAssertEqual(nameColumn.collation, "Latin1_General_CI_AS", "Collation should be Latin1_General_CI_AS")
    }

    // MARK: - Check Constraints

    func testCheckConstraintIntrospection() async throws {
        let tableName = uniqueTableName()
        try await execute("""
            CREATE TABLE dbo.[\(tableName)] (
                id INT NOT NULL PRIMARY KEY,
                value INT NOT NULL,
                CONSTRAINT ck_\(tableName)_positive CHECK (value > 0)
            )
        """)
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertEqual(details.checkConstraints.count, 1, "Should have exactly one check constraint")
        let ck = details.checkConstraints[0]
        XCTAssertEqual(ck.name, "ck_\(tableName)_positive", "Check constraint name should match")
        XCTAssertTrue(ck.expression.contains("value"), "Expression should reference 'value', got: \(ck.expression)")
    }

    func testMultipleCheckConstraints() async throws {
        let tableName = uniqueTableName()
        let ckPositive = "ck_\(tableName)_positive"
        let ckStatus = "ck_\(tableName)_status"
        try await execute("""
            CREATE TABLE dbo.[\(tableName)] (
                id INT NOT NULL PRIMARY KEY,
                value INT NOT NULL,
                status NVARCHAR(20) NOT NULL,
                CONSTRAINT [\(ckPositive)] CHECK (value > 0),
                CONSTRAINT [\(ckStatus)] CHECK (status IN (N'active', N'inactive'))
            )
        """)
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertEqual(details.checkConstraints.count, 2, "Should have two check constraints")
        let names = Set(details.checkConstraints.map(\.name))
        XCTAssertTrue(names.contains(ckPositive), "Should contain \(ckPositive)")
        XCTAssertTrue(names.contains(ckStatus), "Should contain \(ckStatus)")
    }

    // MARK: - Index INCLUDE Columns

    func testIndexWithIncludeColumns() async throws {
        let tableName = uniqueTableName()
        let indexName = "ix_\(tableName)_key"
        try await execute("""
            CREATE TABLE dbo.[\(tableName)] (
                id INT NOT NULL PRIMARY KEY,
                key_col INT NOT NULL,
                included_col NVARCHAR(100)
            )
        """)
        try await execute("CREATE INDEX [\(indexName)] ON dbo.[\(tableName)] (key_col) INCLUDE (included_col)")
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let idx = try XCTUnwrap(details.indexes.first(where: { $0.name == indexName }), "Index should be present")
        XCTAssertGreaterThanOrEqual(idx.columns.count, 2, "Index should have at least 2 columns (key + include)")

        let keyCol = idx.columns.first(where: { $0.name == "key_col" })
        let inclCol = idx.columns.first(where: { $0.name == "included_col" })
        XCTAssertNotNil(keyCol, "Key column should be present")
        XCTAssertNotNil(inclCol, "Included column should be present")
        XCTAssertFalse(keyCol?.isIncluded ?? true, "Key column should not be marked as included")
        XCTAssertTrue(inclCol?.isIncluded ?? false, "Included column should be marked as included")
    }

    // MARK: - Table Properties

    func testTablePropertiesCompression() async throws {
        let tableName = uniqueTableName()
        try await execute("""
            CREATE TABLE dbo.[\(tableName)] (
                id INT NOT NULL PRIMARY KEY,
                name NVARCHAR(100)
            ) WITH (DATA_COMPRESSION = PAGE)
        """)
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let props = try XCTUnwrap(details.tableProperties, "Table properties should not be nil")
        XCTAssertEqual(props.dataCompression?.uppercased(), "PAGE", "Data compression should be PAGE, got: \(props.dataCompression ?? "nil")")
    }

    func testTablePropertiesFilegroup() async throws {
        let tableName = uniqueTableName()
        try await execute("""
            CREATE TABLE dbo.[\(tableName)] (
                id INT NOT NULL PRIMARY KEY,
                name NVARCHAR(100)
            )
        """)
        cleanupSQL("DROP TABLE dbo.[\(tableName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let props = try XCTUnwrap(details.tableProperties, "Table properties should not be nil")
        XCTAssertNotNil(props.filegroup, "Filegroup should be populated")
        XCTAssertEqual(props.filegroup, "PRIMARY", "Default filegroup should be PRIMARY")
    }
}
