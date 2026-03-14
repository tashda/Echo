import XCTest
@testable import Echo

/// Tests SQL Server stored procedure operations through Echo's DatabaseSession layer.
final class MSSQLProcedureTests: MSSQLDockerTestCase {

    // MARK: - Create and Execute

    func testCreateAndExecuteProcedure() async throws {
        let procName = uniqueTableName(prefix: "usp")
        try await execute("""
            CREATE PROCEDURE [\(procName)]
                @value INT
            AS
            BEGIN
                SELECT @value * 2 AS doubled;
            END
        """)
        cleanupSQL("DROP PROCEDURE [\(procName)]")

        let result = try await query("EXEC [\(procName)] @value = 21")
        XCTAssertEqual(result.rows[0][0], "42")
    }

    func testProcedureWithMultipleParameters() async throws {
        let procName = uniqueTableName(prefix: "usp")
        try await execute("""
            CREATE PROCEDURE [\(procName)]
                @first NVARCHAR(50),
                @last NVARCHAR(50)
            AS
            BEGIN
                SELECT @first + ' ' + @last AS full_name;
            END
        """)
        cleanupSQL("DROP PROCEDURE [\(procName)]")

        let result = try await query("EXEC [\(procName)] @first = 'John', @last = 'Doe'")
        XCTAssertEqual(result.rows[0][0], "John Doe")
    }

    func testProcedureWithTableOperations() async throws {
        let tableName = uniqueTableName()
        let procName = uniqueTableName(prefix: "usp")
        try await execute("CREATE TABLE [\(tableName)] (id INT PRIMARY KEY, name NVARCHAR(100))")
        try await execute("""
            CREATE PROCEDURE [\(procName)]
                @id INT, @name NVARCHAR(100)
            AS
            BEGIN
                INSERT INTO [\(tableName)] (id, name) VALUES (@id, @name);
                SELECT * FROM [\(tableName)] WHERE id = @id;
            END
        """)
        cleanupSQL(
            "DROP PROCEDURE [\(procName)]",
            "DROP TABLE [\(tableName)]"
        )

        let result = try await query("EXEC [\(procName)] @id = 1, @name = 'Alice'")
        XCTAssertEqual(result.rows[0][1], "Alice")
    }

    // MARK: - Alter Procedure

    func testAlterProcedure() async throws {
        let procName = uniqueTableName(prefix: "usp")
        try await execute("""
            CREATE PROCEDURE [\(procName)] AS SELECT 1 AS original;
        """)
        cleanupSQL("DROP PROCEDURE [\(procName)]")

        try await execute("""
            ALTER PROCEDURE [\(procName)] AS SELECT 2 AS modified;
        """)

        let result = try await query("EXEC [\(procName)]")
        XCTAssertEqual(result.rows[0][0], "2")
    }

    // MARK: - Drop Procedure

    func testDropProcedure() async throws {
        let procName = uniqueTableName(prefix: "usp")
        try await execute("CREATE PROCEDURE [\(procName)] AS SELECT 1;")

        try await execute("DROP PROCEDURE [\(procName)]")

        // Verify it's gone
        do {
            _ = try await query("EXEC [\(procName)]")
            XCTFail("Should fail after drop")
        } catch {
            // Expected
        }
    }

    // MARK: - Procedure Definition

    func testGetProcedureDefinition() async throws {
        let procName = uniqueTableName(prefix: "usp")
        try await execute("""
            CREATE PROCEDURE dbo.[\(procName)]
                @id INT
            AS
            BEGIN
                SELECT @id AS result_id;
            END
        """)
        cleanupSQL("DROP PROCEDURE dbo.[\(procName)]")

        let definition = try await session.getObjectDefinition(
            objectName: procName, schemaName: "dbo", objectType: .procedure
        )
        XCTAssertFalse(definition.isEmpty)
    }

    // MARK: - Procedure with Multiple Result Sets

    func testProcedureReturnsMultipleResultSets() async throws {
        let procName = uniqueTableName(prefix: "usp")
        try await execute("""
            CREATE PROCEDURE [\(procName)]
            AS
            BEGIN
                SELECT 1 AS first_set;
                SELECT 'a' AS col_a, 'b' AS col_b;
            END
        """)
        cleanupSQL("DROP PROCEDURE [\(procName)]")

        let result = try await query("EXEC [\(procName)]")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertFalse(result.additionalResults.isEmpty, "Should have multiple result sets")
    }
}
