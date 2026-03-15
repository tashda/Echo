import XCTest
@testable import Echo

/// Tests PostgreSQL constraint operations through Echo's DatabaseSession layer.
final class PGConstraintTests: PostgresDockerTestCase {

    // MARK: - Primary Key

    func testCreateTableWithPrimaryKey() async throws {
        try await withTempTable(columns: "id INT PRIMARY KEY, name TEXT") { tableName in
            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            XCTAssertNotNil(details.primaryKey)
            XCTAssertTrue(details.primaryKey?.columns.contains("id") ?? false)
        }
    }

    func testCompositePrimaryKey() async throws {
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
        try await execute("CREATE TABLE public.\(tableName) (id INT NOT NULL, name TEXT)")
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await execute("ALTER TABLE public.\(tableName) ADD CONSTRAINT pk_\(tableName) PRIMARY KEY (id)")

        let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
        XCTAssertNotNil(details.primaryKey)
    }

    // MARK: - Foreign Key

    func testForeignKeyConstraint() async throws {
        let parent = uniqueName(prefix: "fk_parent")
        let child = uniqueName(prefix: "fk_child")
        try await execute("CREATE TABLE public.\(parent) (id SERIAL PRIMARY KEY)")
        try await execute("""
            CREATE TABLE public.\(child) (
                id SERIAL PRIMARY KEY,
                parent_id INT,
                CONSTRAINT fk_\(child)_parent FOREIGN KEY (parent_id) REFERENCES public.\(parent)(id)
            )
        """)
        cleanupSQL(
            "DROP TABLE IF EXISTS public.\(child)",
            "DROP TABLE IF EXISTS public.\(parent)"
        )

        let details = try await session.getTableStructureDetails(schema: "public", table: child)
        XCTAssertFalse(details.foreignKeys.isEmpty, "Should detect FK constraint")

        let fk = details.foreignKeys.first
        XCTAssertTrue(fk?.columns.contains("parent_id") ?? false)
    }

    func testForeignKeyWithCascade() async throws {
        let parent = uniqueName(prefix: "cas_parent")
        let child = uniqueName(prefix: "cas_child")
        try await execute("CREATE TABLE public.\(parent) (id SERIAL PRIMARY KEY)")
        try await execute("""
            CREATE TABLE public.\(child) (
                id SERIAL PRIMARY KEY,
                parent_id INT,
                FOREIGN KEY (parent_id) REFERENCES public.\(parent)(id) ON DELETE CASCADE ON UPDATE CASCADE
            )
        """)
        cleanupSQL(
            "DROP TABLE IF EXISTS public.\(child)",
            "DROP TABLE IF EXISTS public.\(parent)"
        )

        // Verify cascade works: insert parent and child, delete parent
        try await execute("INSERT INTO public.\(parent) (id) VALUES (1)")
        try await execute("INSERT INTO public.\(child) (parent_id) VALUES (1)")
        try await execute("DELETE FROM public.\(parent) WHERE id = 1")

        let result = try await query("SELECT COUNT(*) FROM public.\(child)")
        XCTAssertEqual(result.rows[0][0], "0", "Child row should be cascade-deleted")
    }

    func testDropForeignKey() async throws {
        let parent = uniqueName(prefix: "dp")
        let child = uniqueName(prefix: "dc")
        let fkName = "fk_\(child)_parent"
        try await execute("CREATE TABLE public.\(parent) (id SERIAL PRIMARY KEY)")
        try await execute("""
            CREATE TABLE public.\(child) (
                id SERIAL PRIMARY KEY,
                parent_id INT,
                CONSTRAINT \(fkName) FOREIGN KEY (parent_id) REFERENCES public.\(parent)(id)
            )
        """)
        cleanupSQL(
            "DROP TABLE IF EXISTS public.\(child)",
            "DROP TABLE IF EXISTS public.\(parent)"
        )

        try await execute("ALTER TABLE public.\(child) DROP CONSTRAINT \(fkName)")

        let details = try await session.getTableStructureDetails(schema: "public", table: child)
        XCTAssertTrue(details.foreignKeys.isEmpty, "FK should be dropped")
    }

    // MARK: - Unique Constraint

    func testUniqueConstraintInline() async throws {
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, code VARCHAR(10) UNIQUE, name TEXT"
        ) { tableName in
            let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
            let hasUnique = !details.uniqueConstraints.isEmpty ||
                details.indexes.contains(where: { $0.isUnique && $0.columns.contains(where: { $0.name.caseInsensitiveCompare("code") == .orderedSame }) })
            XCTAssertTrue(hasUnique, "Should detect unique constraint on 'code'")
        }
    }

    func testAddUniqueConstraint() async throws {
        let tableName = uniqueName()
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, email TEXT)")
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await execute("ALTER TABLE public.\(tableName) ADD CONSTRAINT uq_\(tableName)_email UNIQUE (email)")

        let details = try await session.getTableStructureDetails(schema: "public", table: tableName)
        let hasUnique = !details.uniqueConstraints.isEmpty ||
            details.indexes.contains(where: { $0.isUnique })
        XCTAssertTrue(hasUnique)
    }

    // MARK: - Check Constraint

    func testCheckConstraintValidInsert() async throws {
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, age INT CHECK (age >= 0 AND age <= 150)"
        ) { tableName in
            try await execute("INSERT INTO public.\(tableName) (age) VALUES (25)")
            let result = try await query("SELECT age FROM public.\(tableName)")
            XCTAssertEqual(result.rows[0][0], "25")
        }
    }

    func testCheckConstraintInvalidInsert() async throws {
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, age INT CHECK (age >= 0 AND age <= 150)"
        ) { tableName in
            do {
                try await execute("INSERT INTO public.\(tableName) (age) VALUES (-5)")
                XCTFail("Should reject negative age")
            } catch {
                // Expected: check constraint violation
            }
        }
    }

    // MARK: - Exclusion Constraint

    func testExclusionConstraint() async throws {
        let tableName = uniqueName(prefix: "excl")
        // Exclusion constraints require btree_gist extension for integer comparisons
        try? await execute("CREATE EXTENSION IF NOT EXISTS btree_gist")
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
        try await withTempTable(
            columns: "id SERIAL PRIMARY KEY, status TEXT DEFAULT 'active', created_at TIMESTAMPTZ DEFAULT NOW()"
        ) { tableName in
            try await execute("INSERT INTO public.\(tableName) DEFAULT VALUES")
            let result = try await query("SELECT status FROM public.\(tableName) WHERE id = 1")
            XCTAssertEqual(result.rows[0][0], "active")
        }
    }
}
