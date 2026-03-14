import XCTest
@testable import Echo

/// Tests PostgreSQL function operations through Echo's DatabaseSession layer.
final class PGFunctionTests: PostgresDockerTestCase {

    // MARK: - PL/pgSQL Function

    func testCreatePlpgsqlFunction() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION public.\(funcName)(x INT)
            RETURNS INT
            LANGUAGE plpgsql
            AS $$
            BEGIN
                RETURN x * 3;
            END;
            $$
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)(INT)")

        let result = try await query("SELECT public.\(funcName)(14) AS tripled")
        XCTAssertEqual(result.rows[0][0], "42")
    }

    // MARK: - SQL Function

    func testCreateSQLFunction() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION public.\(funcName)(a INT, b INT)
            RETURNS INT
            LANGUAGE sql
            AS $$ SELECT a + b $$
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)(INT, INT)")

        let result = try await query("SELECT public.\(funcName)(17, 25) AS sum")
        XCTAssertEqual(result.rows[0][0], "42")
    }

    // MARK: - Function with Parameters

    func testFunctionWithStringParameters() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION public.\(funcName)(first_name TEXT, last_name TEXT)
            RETURNS TEXT
            LANGUAGE sql
            AS $$ SELECT first_name || ' ' || last_name $$
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)(TEXT, TEXT)")

        let result = try await query("SELECT public.\(funcName)('Jane', 'Doe') AS name")
        XCTAssertEqual(result.rows[0][0], "Jane Doe")
    }

    // MARK: - Function Returning Table

    func testFunctionReturningTable() async throws {
        let tableName = uniqueName()
        let funcName = uniqueName(prefix: "fn")
        try await execute("CREATE TABLE public.\(tableName) (id SERIAL, dept TEXT, name TEXT)")
        try await execute("INSERT INTO public.\(tableName) (dept, name) VALUES ('ENG', 'Alice'), ('ENG', 'Bob'), ('HR', 'Carol')")
        try await execute("""
            CREATE FUNCTION public.\(funcName)(target_dept TEXT)
            RETURNS TABLE(id INT, name TEXT)
            LANGUAGE sql
            AS $$ SELECT id, name FROM public.\(tableName) WHERE dept = target_dept $$
        """)
        cleanupSQL(
            "DROP FUNCTION IF EXISTS public.\(funcName)(TEXT)",
            "DROP TABLE IF EXISTS public.\(tableName)"
        )

        let result = try await query("SELECT * FROM public.\(funcName)('ENG')")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }

    // MARK: - Alter Function (CREATE OR REPLACE)

    func testAlterFunction() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION public.\(funcName)(x INT)
            RETURNS INT
            LANGUAGE sql
            AS $$ SELECT x $$
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)(INT)")

        // Replace with different logic
        try await execute("""
            CREATE OR REPLACE FUNCTION public.\(funcName)(x INT)
            RETURNS INT
            LANGUAGE sql
            AS $$ SELECT x + 100 $$
        """)

        let result = try await query("SELECT public.\(funcName)(1) AS val")
        XCTAssertEqual(result.rows[0][0], "101")
    }

    // MARK: - Drop Function

    func testDropFunction() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION public.\(funcName)(x INT)
            RETURNS INT
            LANGUAGE sql
            AS $$ SELECT x $$
        """)

        try await execute("DROP FUNCTION public.\(funcName)(INT)")

        do {
            _ = try await query("SELECT public.\(funcName)(1)")
            XCTFail("Should fail after drop")
        } catch {
            // Expected: function does not exist
        }
    }

    // MARK: - Function Definition

    func testGetFunctionDefinition() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION public.\(funcName)(input TEXT)
            RETURNS TEXT
            LANGUAGE sql
            AS $$ SELECT UPPER(input) $$
        """)
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)(TEXT)")

        let definition = try await session.getObjectDefinition(
            objectName: funcName, schemaName: "public", objectType: .function
        )
        XCTAssertFalse(definition.isEmpty)
    }
}
