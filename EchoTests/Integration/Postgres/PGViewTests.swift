import XCTest
@testable import Echo

/// Tests PostgreSQL view operations through Echo's DatabaseSession layer.
final class PGViewTests: PostgresDockerTestCase {

    // MARK: - Create View

    func testCreateView() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, name TEXT, active BOOLEAN DEFAULT TRUE)")
        try await execute("CREATE VIEW public.\(viewName) AS SELECT id, name FROM public.\(tableName) WHERE active = TRUE")
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        let objects = try await session.listTablesAndViews(schema: "public")
        IntegrationTestHelpers.assertContainsObject(objects, name: viewName, type: .view)
    }

    func testQueryThroughView() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, name TEXT, active BOOLEAN)")
        try await execute("INSERT INTO public.\(tableName) (name, active) VALUES ('Alice', TRUE), ('Bob', FALSE), ('Carol', TRUE)")
        try await execute("CREATE VIEW public.\(viewName) AS SELECT id, name FROM public.\(tableName) WHERE active = TRUE")
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        let result = try await query("SELECT * FROM public.\(viewName) ORDER BY id")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
        XCTAssertEqual(result.rows[0][1], "Alice")
        XCTAssertEqual(result.rows[1][1], "Carol")
    }

    // MARK: - Alter View

    func testAlterView() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, name TEXT, email TEXT)")
        try await execute("CREATE VIEW public.\(viewName) AS SELECT id, name FROM public.\(tableName)")
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        // PostgreSQL uses CREATE OR REPLACE VIEW to alter
        try await execute("CREATE OR REPLACE VIEW public.\(viewName) AS SELECT id, name, email FROM public.\(tableName)")

        let definition = try await session.getObjectDefinition(
            objectName: viewName, schemaName: "public", objectType: .view
        )
        XCTAssertTrue(definition.lowercased().contains("email"))
    }

    // MARK: - Drop View

    func testDropView() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY)")
        try await execute("CREATE VIEW public.\(viewName) AS SELECT id FROM public.\(tableName)")
        cleanupSQL("DROP TABLE IF EXISTS public.\(tableName)")

        try await execute("DROP VIEW public.\(viewName)")

        let objects = try await session.listTablesAndViews(schema: "public")
        let exists = objects.contains { $0.name.caseInsensitiveCompare(viewName) == .orderedSame }
        XCTAssertFalse(exists)
    }

    // MARK: - View Definition

    func testGetViewDefinition() async throws {
        let tableName = uniqueName()
        let viewName = uniqueName(prefix: "v")
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, name TEXT)")
        try await execute("CREATE VIEW public.\(viewName) AS SELECT id, name FROM public.\(tableName) WHERE id > 0")
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        let definition = try await session.getObjectDefinition(
            objectName: viewName, schemaName: "public", objectType: .view
        )
        XCTAssertFalse(definition.isEmpty)
        XCTAssertTrue(definition.lowercased().contains("select"))
    }

    // MARK: - View with Joins

    func testViewWithJoin() async throws {
        let t1 = uniqueName(prefix: "dept")
        let t2 = uniqueName(prefix: "emp")
        let viewName = uniqueName(prefix: "v")
        try await execute("CREATE TABLE public.\(t1) (id SERIAL PRIMARY KEY, name TEXT)")
        try await execute("CREATE TABLE public.\(t2) (id SERIAL PRIMARY KEY, dept_id INT, name TEXT)")
        try await execute("INSERT INTO public.\(t1) (id, name) VALUES (1, 'Engineering')")
        try await execute("INSERT INTO public.\(t2) (dept_id, name) VALUES (1, 'Alice'), (1, 'Bob')")
        try await execute("""
            CREATE VIEW public.\(viewName) AS
            SELECT e.name AS employee, d.name AS department
            FROM public.\(t2) e JOIN public.\(t1) d ON e.dept_id = d.id
        """)
        cleanupSQL(
            "DROP VIEW IF EXISTS public.\(viewName)",
            "DROP TABLE IF EXISTS public.\(t2)",
            "DROP TABLE IF EXISTS public.\(t1)"
        )

        let result = try await query("SELECT * FROM public.\(viewName)")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }

    // MARK: - Materialized View

    func testCreateMaterializedView() async throws {
        let tableName = uniqueName()
        let matViewName = uniqueName(prefix: "mv")
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, category TEXT, amount NUMERIC)")
        try await execute("INSERT INTO public.\(tableName) (category, amount) VALUES ('A', 100), ('A', 200), ('B', 50)")
        try await execute("""
            CREATE MATERIALIZED VIEW public.\(matViewName) AS
            SELECT category, SUM(amount) AS total FROM public.\(tableName) GROUP BY category
        """)
        cleanupSQL(
            "DROP MATERIALIZED VIEW IF EXISTS public.\(matViewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        let result = try await query("SELECT * FROM public.\(matViewName) ORDER BY category")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }

    func testRefreshMaterializedView() async throws {
        let tableName = uniqueName()
        let matViewName = uniqueName(prefix: "mv")
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL PRIMARY KEY, value INT)")
        try await execute("INSERT INTO public.\(tableName) (value) VALUES (1), (2)")
        try await execute("CREATE MATERIALIZED VIEW public.\(matViewName) AS SELECT COUNT(*) AS cnt FROM public.\(tableName)")
        cleanupSQL(
            "DROP MATERIALIZED VIEW IF EXISTS public.\(matViewName)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        // Verify initial count
        let before = try await query("SELECT cnt FROM public.\(matViewName)")
        XCTAssertEqual(before.rows[0][0], "2")

        // Insert more data and refresh
        try await execute("INSERT INTO public.\(tableName) (value) VALUES (3), (4), (5)")
        try await execute("REFRESH MATERIALIZED VIEW public.\(matViewName)")

        let after = try await query("SELECT cnt FROM public.\(matViewName)")
        XCTAssertEqual(after.rows[0][0], "5")
    }
}
