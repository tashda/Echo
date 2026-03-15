import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL constraint operations through Echo's DatabaseSession layer.
final class PGConstraintTests: PostgresDockerTestCase {

    // MARK: - Primary Key

    func testCreateTableWithPrimaryKey() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            PostgresColumnDefinition(name: "id", dataType: "INT", nullable: false, primaryKey: true),
            .text(name: "name")
        ])
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
        XCTAssertNotNil(details.primaryKey)
        XCTAssertTrue(details.primaryKey?.columns.contains("id") ?? false)
    }

    func testCompositePrimaryKey() async throws {
        // Composite primary keys require raw SQL — createTable doesn't support table-level constraints
        try await withTempTable(
            columns: "a INT NOT NULL, b INT NOT NULL, name TEXT, PRIMARY KEY (a, b)"
        ) { tableName in
            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            XCTAssertNotNil(details.primaryKey)
            XCTAssertEqual(details.primaryKey?.columns.count, 2)
        }
    }

    func testAddPrimaryKeyConstraint() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            PostgresColumnDefinition(name: "id", dataType: "INT", nullable: false),
            .text(name: "name")
        ])
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await postgresClient.admin.addPrimaryKey(table: tableName, column: "id", constraintName: "pk_\(tableName)")

        let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
        XCTAssertNotNil(details.primaryKey)
    }

    // MARK: - Foreign Key

    func testForeignKeyConstraint() async throws {
        let parent = uniqueName(prefix: "fk_parent")
        let child = uniqueName(prefix: "fk_child")
        try await postgresClient.admin.createTable(name: parent, columns: [
            .serial(name: "id", primaryKey: true)
        ])
        try await postgresClient.admin.createTable(name: child, columns: [
            .serial(name: "id", primaryKey: true),
            .integer(name: "parent_id")
        ])
        cleanupSQL(
            "DROP TABLE IF EXISTS public.\(child)",
            "DROP TABLE IF EXISTS public.\(parent)"
        )

        try await postgresClient.admin.addForeignKey(
            table: child,
            column: "parent_id",
            referencesTable: parent,
            referencesColumn: "id",
            constraintName: "fk_\(child)_parent"
        )

        let details = try await session.getTableStructureDetails(schema: "public", table: child)
        XCTAssertFalse(details.foreignKeys.isEmpty, "Should detect FK constraint")

        let fk = details.foreignKeys.first
        XCTAssertTrue(fk?.columns.contains("parent_id") ?? false)
    }

    func testForeignKeyWithCascade() async throws {
        let parent = uniqueName(prefix: "cas_parent")
        let child = uniqueName(prefix: "cas_child")
        try await postgresClient.admin.createTable(name: parent, columns: [
            .serial(name: "id", primaryKey: true)
        ])
        try await postgresClient.admin.createTable(name: child, columns: [
            .serial(name: "id", primaryKey: true),
            .integer(name: "parent_id")
        ])
        cleanupSQL(
            "DROP TABLE IF EXISTS public.\(child)",
            "DROP TABLE IF EXISTS public.\(parent)"
        )

        try await postgresClient.admin.addForeignKey(
            table: child,
            column: "parent_id",
            referencesTable: parent,
            referencesColumn: "id",
            onDelete: .cascade,
            onUpdate: .cascade
        )

        // Verify cascade works: insert parent and child, delete parent
        try await postgresClient.connection.insert(into: parent, columns: ["id"], values: [[1]])
        try await postgresClient.connection.insert(into: child, columns: ["parent_id"], values: [[1]])
        try await postgresClient.connection.delete(from: parent, whereClause: "id = 1")

        let result = try await query("SELECT COUNT(*) FROM public.\(child)")
        XCTAssertEqual(result.rows[0][0], "0", "Child row should be cascade-deleted")
    }

    func testDropForeignKey() async throws {
        let parent = uniqueName(prefix: "dp")
        let child = uniqueName(prefix: "dc")
        let fkName = "fk_\(child)_parent"
        try await postgresClient.admin.createTable(name: parent, columns: [
            .serial(name: "id", primaryKey: true)
        ])
        try await postgresClient.admin.createTable(name: child, columns: [
            .serial(name: "id", primaryKey: true),
            .integer(name: "parent_id")
        ])
        cleanupSQL(
            "DROP TABLE IF EXISTS public.\(child)",
            "DROP TABLE IF EXISTS public.\(parent)"
        )

        try await postgresClient.admin.addForeignKey(
            table: child,
            column: "parent_id",
            referencesTable: parent,
            referencesColumn: "id",
            constraintName: fkName
        )

        try await postgresClient.admin.dropConstraint(table: child, constraintName: fkName)

        let details = try await session.getTableStructureDetails(schema: "public", table: child)
        XCTAssertTrue(details.foreignKeys.isEmpty, "FK should be dropped")
    }

    // MARK: - Unique Constraint

    func testUniqueConstraintInline() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .varchar(name: "code", length: 10, unique: true),
            .text(name: "name")
        ])
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
        let hasUnique = !details.uniqueConstraints.isEmpty ||
            details.indexes.contains(where: { $0.isUnique && $0.columns.contains(where: { $0.name.caseInsensitiveCompare("code") == .orderedSame }) })
        XCTAssertTrue(hasUnique, "Should detect unique constraint on 'code'")
    }

    func testAddUniqueConstraint() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "email")
        ])
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await postgresClient.admin.addUniqueConstraint(
            table: tableName,
            columns: ["email"],
            constraintName: "uq_\(tableName)_email"
        )

        let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
        let hasUnique = !details.uniqueConstraints.isEmpty ||
            details.indexes.contains(where: { $0.isUnique })
        XCTAssertTrue(hasUnique)
    }

    // MARK: - Check Constraint

    func testCheckConstraintValidInsert() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .integer(name: "age")
        ])
        try await postgresClient.admin.addCheckConstraint(
            table: tableName,
            condition: "age >= 0 AND age <= 150",
            constraintName: "chk_\(tableName)_age"
        )
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await postgresClient.connection.insert(into: tableName, columns: ["age"], values: [[25]])
        let result = try await query("SELECT age FROM public.\(tableName)")
        XCTAssertEqual(result.rows[0][0], "25")
    }

    func testCheckConstraintInvalidInsert() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .integer(name: "age")
        ])
        try await postgresClient.admin.addCheckConstraint(
            table: tableName,
            condition: "age >= 0 AND age <= 150",
            constraintName: "chk_\(tableName)_age"
        )
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        do {
            try await postgresClient.connection.insert(into: tableName, columns: ["age"], values: [[-5]])
            XCTFail("Should reject negative age")
        } catch {
            // Expected: check constraint violation
        }
    }

    // MARK: - Exclusion Constraint

    func testExclusionConstraint() async throws {
        let tableName = uniqueName(prefix: "excl")
        // Exclusion constraints require btree_gist extension for integer comparisons
        try? await execute("CREATE EXTENSION IF NOT EXISTS btree_gist")
        // Exclusion constraints are not supported by the typed API — use raw SQL
        try await execute("""
            CREATE TABLE public.\(tableName) (
                id SERIAL PRIMARY KEY,
                room INT NOT NULL,
                during TSRANGE NOT NULL,
                EXCLUDE USING GIST (room WITH =, during WITH &&)
            )
        """)
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        // Insert a booking
        try await execute("""
            INSERT INTO public.\(tableName) (room, during)
            VALUES (101, '[2024-01-01 10:00, 2024-01-01 12:00)')
        """)

        // Overlapping booking should fail
        do {
            try await execute("""
                INSERT INTO public.\(tableName) (room, during)
                VALUES (101, '[2024-01-01 11:00, 2024-01-01 13:00)')
            """)
            XCTFail("Should reject overlapping booking")
        } catch {
            // Expected: exclusion constraint violation
        }
    }

    // MARK: - Default Constraint

    func testDefaultConstraint() async throws {
        let tableName = uniqueName()
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id", primaryKey: true),
            .text(name: "status", defaultValue: "'active'"),
            .timestampWithTimeZone(name: "created_at", defaultValue: "NOW()")
        ])
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await execute("INSERT INTO public.\(tableName) DEFAULT VALUES")
        let result = try await query("SELECT status FROM public.\(tableName) WHERE id = 1")
        XCTAssertEqual(result.rows[0][0], "active")
    }
}
