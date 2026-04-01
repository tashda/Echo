import XCTest
import PostgresKit
@testable import Echo

/// Tests PostgreSQL function operations through Echo's DatabaseSession layer.
final class PGFunctionTests: PostgresDockerTestCase {

    // MARK: - PL/pgSQL Function

    func testCreatePlpgsqlFunction() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [PostgresFunctionParameter(name: "x", dataType: "INT")],
            returnType: "INT",
            body: """
                BEGIN
                    RETURN x * 3;
                END;
                """,
            language: .plpgsql
        )
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)(INT)")

        let result = try await query("SELECT public.\(funcName)(14) AS tripled")
        XCTAssertEqual(result.rows[0][0], "42")
    }

    // MARK: - SQL Function

    func testCreateSQLFunction() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [
                PostgresFunctionParameter(name: "a", dataType: "INT"),
                PostgresFunctionParameter(name: "b", dataType: "INT")
            ],
            returnType: "INT",
            body: "SELECT a + b",
            language: .sql
        )
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)(INT, INT)")

        let result = try await query("SELECT public.\(funcName)(17, 25) AS sum")
        XCTAssertEqual(result.rows[0][0], "42")
    }

    // MARK: - Function with Parameters

    func testFunctionWithStringParameters() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [
                PostgresFunctionParameter(name: "first_name", dataType: "TEXT"),
                PostgresFunctionParameter(name: "last_name", dataType: "TEXT")
            ],
            returnType: "TEXT",
            body: "SELECT first_name || ' ' || last_name",
            language: .sql
        )
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)(TEXT, TEXT)")

        let result = try await query("SELECT public.\(funcName)('Jane', 'Doe') AS name")
        XCTAssertEqual(result.rows[0][0], "Jane Doe")
    }

    // MARK: - Function Returning Table

    func testFunctionReturningTable() async throws {
        let tableName = uniqueName()
        let funcName = uniqueName(prefix: "fn")
        try await postgresClient.admin.createTable(name: tableName, columns: [
            .serial(name: "id"),
            .text(name: "dept"),
            .text(name: "name")
        ])
        try await postgresClient.connection.insert(
            into: tableName,
            columns: ["dept", "name"],
            values: [["ENG", "Alice"], ["ENG", "Bob"], ["HR", "Carol"]]
        )
        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [PostgresFunctionParameter(name: "target_dept", dataType: "TEXT")],
            returnType: "TABLE(id INT, name TEXT)",
            body: "SELECT id, name FROM \(tableName) WHERE dept = target_dept",
            language: .sql
        )
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
        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [PostgresFunctionParameter(name: "x", dataType: "INT")],
            returnType: "INT",
            body: "SELECT x",
            language: .sql
        )
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)(INT)")

        // Replace with different logic
        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [PostgresFunctionParameter(name: "x", dataType: "INT")],
            returnType: "INT",
            body: "SELECT x + 100",
            language: .sql,
            orReplace: true
        )

        let result = try await query("SELECT public.\(funcName)(1) AS val")
        XCTAssertEqual(result.rows[0][0], "101")
    }

    // MARK: - Drop Function

    func testDropFunction() async throws {
        let funcName = uniqueName(prefix: "fn")
        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [PostgresFunctionParameter(name: "x", dataType: "INT")],
            returnType: "INT",
            body: "SELECT x",
            language: .sql
        )

        try await postgresClient.admin.dropFunction(name: funcName, parameters: ["INT"])

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
        try await postgresClient.admin.createFunction(
            name: funcName,
            parameters: [PostgresFunctionParameter(name: "input", dataType: "TEXT")],
            returnType: "TEXT",
            body: "SELECT UPPER(input)",
            language: .sql
        )
        cleanupSQL("DROP FUNCTION IF EXISTS public.\(funcName)(TEXT)")

        let definition = try await session.getObjectDefinition(
            objectName: funcName, schemaName: "public", objectType: .function
        )
        XCTAssertFalse(definition.isEmpty)
    }
}
