import XCTest
@testable import Echo

/// Tests SQL Server constraint operations through Echo's DatabaseSession layer.
final class MSSQLConstraintTests: MSSQLDockerTestCase {

    // MARK: - Primary Key

    func testCreateTableWithPrimaryKey() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, name NVARCHAR(100)") { tableName in
            let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
            XCTAssertNotNil(details.primaryKey)
            XCTAssertTrue(details.primaryKey?.columns.contains("id") ?? false)
        }
    }

    func testCompositePrimaryKey() async throws {
        try await withTempTable(
            columns: "a INT NOT NULL, b INT NOT NULL, name NVARCHAR(100), PRIMARY KEY (a, b)"
        ) { tableName in
            let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
            XCTAssertNotNil(details.primaryKey)
            XCTAssertEqual(details.primaryKey?.columns.count, 2)
        }
    }

    func testAddPrimaryKeyConstraint() async throws {
        let tableName = uniqueTableName()
        try await execute("CREATE TABLE [\(tableName)] (id INT NOT NULL, name NVARCHAR(100))")
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await execute("ALTER TABLE [\(tableName)] ADD CONSTRAINT PK_\(tableName) PRIMARY KEY (id)")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        XCTAssertNotNil(details.primaryKey)
    }

    // MARK: - Foreign Key

    func testForeignKeyConstraint() async throws {
        let parent = uniqueTableName(prefix: "fk_parent")
        let child = uniqueTableName(prefix: "fk_child")
        try await execute("CREATE TABLE [\(parent)] (id INT PRIMARY KEY)")
        try await execute("""
            CREATE TABLE [\(child)] (
                id INT PRIMARY KEY,
                parent_id INT,
                CONSTRAINT FK_\(child)_parent FOREIGN KEY (parent_id) REFERENCES [\(parent)](id)
            )
        """)
        cleanupSQL(
            "DROP TABLE [\(child)]",
            "DROP TABLE [\(parent)]"
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: child)
        XCTAssertFalse(details.foreignKeys.isEmpty, "Should detect FK constraint")

        let fk = details.foreignKeys.first
        XCTAssertTrue(fk?.columns.contains("parent_id") ?? false)
    }

    func testForeignKeyWithCascade() async throws {
        let parent = uniqueTableName(prefix: "cas_parent")
        let child = uniqueTableName(prefix: "cas_child")
        try await execute("CREATE TABLE [\(parent)] (id INT PRIMARY KEY)")
        try await execute("""
            CREATE TABLE [\(child)] (
                id INT PRIMARY KEY,
                parent_id INT,
                FOREIGN KEY (parent_id) REFERENCES [\(parent)](id) ON DELETE CASCADE ON UPDATE CASCADE
            )
        """)
        cleanupSQL(
            "DROP TABLE [\(child)]",
            "DROP TABLE [\(parent)]"
        )

        let details = try await session.getTableStructureDetails(schema: "dbo", table: child)
        XCTAssertFalse(details.foreignKeys.isEmpty)
    }

    // MARK: - Unique Constraint

    func testUniqueConstraint() async throws {
        try await withTempTable(
            columns: "id INT PRIMARY KEY, code NVARCHAR(10) UNIQUE, name NVARCHAR(100)"
        ) { tableName in
            let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
            let hasUnique = !details.uniqueConstraints.isEmpty ||
                details.indexes.contains(where: { $0.isUnique && $0.columns.contains(where: { $0.name.caseInsensitiveCompare("code") == .orderedSame }) })
            XCTAssertTrue(hasUnique, "Should detect unique constraint on 'code'")
        }
    }

    func testAddUniqueConstraint() async throws {
        let tableName = uniqueTableName()
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, email NVARCHAR(200))")
        cleanupSQL("DROP TABLE [\(tableName)]")

        try await execute("ALTER TABLE [\(tableName)] ADD CONSTRAINT UQ_\(tableName)_email UNIQUE (email)")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: tableName)
        let hasUnique = !details.uniqueConstraints.isEmpty ||
            details.indexes.contains(where: { $0.isUnique })
        XCTAssertTrue(hasUnique)
    }

    // MARK: - Check Constraint

    func testCheckConstraint() async throws {
        try await withTempTable(
            columns: "id INT PRIMARY KEY, age INT CHECK (age >= 0 AND age <= 150)"
        ) { tableName in
            // Insert valid data
            try await execute("INSERT INTO [\(tableName)] VALUES (1, 25)")
            let result = try await query("SELECT age FROM [\(tableName)]")
            XCTAssertEqual(result.rows[0][0], "25")

            // Insert invalid data should fail
            do {
                try await execute("INSERT INTO [\(tableName)] VALUES (2, -5)")
                XCTFail("Should reject negative age")
            } catch {
                // Expected
            }
        }
    }

    // MARK: - Default Constraint

    func testDefaultConstraint() async throws {
        try await withTempTable(
            columns: "id INT PRIMARY KEY, status NVARCHAR(20) DEFAULT 'active', created_at DATETIME2 DEFAULT GETDATE()"
        ) { tableName in
            try await execute("INSERT INTO [\(tableName)] (id) VALUES (1)")
            let result = try await query("SELECT status FROM [\(tableName)] WHERE id = 1")
            XCTAssertEqual(result.rows[0][0], "active")
        }
    }

    // MARK: - Drop Constraints

    func testDropForeignKey() async throws {
        let parent = uniqueTableName(prefix: "dp")
        let child = uniqueTableName(prefix: "dc")
        let fkName = "FK_\(child)_parent"
        try await execute("CREATE TABLE [\(parent)] (id INT PRIMARY KEY)")
        try await execute("""
            CREATE TABLE [\(child)] (
                id INT PRIMARY KEY,
                parent_id INT,
                CONSTRAINT \(fkName) FOREIGN KEY (parent_id) REFERENCES [\(parent)](id)
            )
        """)
        cleanupSQL(
            "DROP TABLE [\(child)]",
            "DROP TABLE [\(parent)]"
        )

        try await execute("ALTER TABLE [\(child)] DROP CONSTRAINT [\(fkName)]")

        let details = try await session.getTableStructureDetails(schema: "dbo", table: child)
        XCTAssertTrue(details.foreignKeys.isEmpty, "FK should be dropped")
    }
}
