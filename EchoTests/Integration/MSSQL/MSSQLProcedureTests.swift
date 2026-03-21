import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server stored procedure operations through Echo's DatabaseSession layer.
final class MSSQLProcedureTests: MSSQLDockerTestCase {

    // MARK: - Create and Execute

    func testCreateAndExecuteProcedure() async throws {
        let procName = uniqueTableName(prefix: "usp")
        try await sqlserverClient.routines.createStoredProcedure(
            name: procName,
            parameters: [
                ProcedureParameter(name: "value", dataType: .int)
            ],
            body: "BEGIN SELECT @value * 2 AS doubled; END"
        )
        cleanupSQL("DROP PROCEDURE [\(procName)]")

        let result = try await query("EXEC [\(procName)] @value = 21")
        XCTAssertEqual(result.rows[0][0], "42")
    }

    func testProcedureWithMultipleParameters() async throws {
        let procName = uniqueTableName(prefix: "usp")
        try await sqlserverClient.routines.createStoredProcedure(
            name: procName,
            parameters: [
                ProcedureParameter(name: "first", dataType: .nvarchar(length: .length(50))),
                ProcedureParameter(name: "last", dataType: .nvarchar(length: .length(50))),
            ],
            body: "BEGIN SELECT @first + ' ' + @last AS full_name; END"
        )
        cleanupSQL("DROP PROCEDURE [\(procName)]")

        let result = try await query("EXEC [\(procName)] @first = 'John', @last = 'Doe'")
        XCTAssertEqual(result.rows[0][0], "John Doe")
    }

    func testProcedureWithTableOperations() async throws {
        let tableName = uniqueTableName()
        let procName = uniqueTableName(prefix: "usp")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int, isPrimaryKey: true))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        try await sqlserverClient.routines.createStoredProcedure(
            name: procName,
            parameters: [
                ProcedureParameter(name: "id", dataType: .int),
                ProcedureParameter(name: "name", dataType: .nvarchar(length: .length(100))),
            ],
            body: """
                BEGIN
                    INSERT INTO [\(tableName)] (id, name) VALUES (@id, @name);
                    SELECT * FROM [\(tableName)] WHERE id = @id;
                END
            """
        )
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
        try await sqlserverClient.routines.createStoredProcedure(
            name: procName,
            body: "BEGIN SELECT 1 AS original; END"
        )
        cleanupSQL("DROP PROCEDURE [\(procName)]")

        // ALTER PROCEDURE — no typed API, use raw SQL
        try await execute("ALTER PROCEDURE [\(procName)] AS BEGIN SELECT 2 AS modified; END")

        let result = try await query("EXEC [\(procName)]")
        XCTAssertEqual(result.rows[0][0], "2")
    }

    // MARK: - Drop Procedure

    func testDropProcedure() async throws {
        let procName = uniqueTableName(prefix: "usp")
        try await sqlserverClient.routines.createStoredProcedure(
            name: procName,
            body: "BEGIN SELECT 1; END"
        )

        try await sqlserverClient.routines.dropStoredProcedure(name: procName)

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
        try await sqlserverClient.routines.createStoredProcedure(
            name: procName,
            parameters: [
                ProcedureParameter(name: "id", dataType: .int)
            ],
            body: "BEGIN SELECT @id AS result_id; END"
        )
        cleanupSQL("DROP PROCEDURE dbo.[\(procName)]")

        let definition = try await session.getObjectDefinition(
            objectName: procName, schemaName: "dbo", objectType: .procedure
        )
        XCTAssertFalse(definition.isEmpty)
    }

    // MARK: - Procedure with Multiple Result Sets

    func testProcedureReturnsMultipleResultSets() async throws {
        let procName = uniqueTableName(prefix: "usp")
        try await sqlserverClient.routines.createStoredProcedure(
            name: procName,
            body: """
                BEGIN
                    SELECT 1 AS first_set;
                    SELECT 'a' AS col_a, 'b' AS col_b;
                END
            """
        )
        cleanupSQL("DROP PROCEDURE [\(procName)]")

        let result = try await query("EXEC [\(procName)]")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertFalse(result.additionalResults.isEmpty, "Should have multiple result sets")
    }
}
