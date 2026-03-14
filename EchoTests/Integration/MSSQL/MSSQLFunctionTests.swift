import XCTest
@testable import Echo

/// Tests SQL Server user-defined function operations through Echo's DatabaseSession layer.
final class MSSQLFunctionTests: MSSQLDockerTestCase {

    // MARK: - Scalar Functions

    func testCreateScalarFunction() async throws {
        let funcName = uniqueTableName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION dbo.[\(funcName)](@x INT)
            RETURNS INT
            AS
            BEGIN
                RETURN @x * 3;
            END
        """)
        cleanupSQL("DROP FUNCTION dbo.[\(funcName)]")

        let result = try await query("SELECT dbo.[\(funcName)](14) AS tripled")
        XCTAssertEqual(result.rows[0][0], "42")
    }

    func testScalarFunctionWithStringInput() async throws {
        let funcName = uniqueTableName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION dbo.[\(funcName)](@first NVARCHAR(50), @last NVARCHAR(50))
            RETURNS NVARCHAR(101)
            AS
            BEGIN
                RETURN @first + ' ' + @last;
            END
        """)
        cleanupSQL("DROP FUNCTION dbo.[\(funcName)]")

        let result = try await query("SELECT dbo.[\(funcName)]('Jane', 'Doe') AS name")
        XCTAssertEqual(result.rows[0][0], "Jane Doe")
    }

    // MARK: - Inline Table-Valued Function

    func testInlineTableValuedFunction() async throws {
        let tableName = uniqueTableName()
        let funcName = uniqueTableName(prefix: "fn")
        try await execute("CREATE TABLE [\(tableName)] (id INT, dept NVARCHAR(50), name NVARCHAR(100))")
        try await execute("INSERT INTO [\(tableName)] VALUES (1, 'ENG', 'Alice'), (2, 'ENG', 'Bob'), (3, 'HR', 'Carol')")
        try await execute("""
            CREATE FUNCTION dbo.[\(funcName)](@dept NVARCHAR(50))
            RETURNS TABLE
            AS
            RETURN (SELECT id, name FROM [\(tableName)] WHERE dept = @dept)
        """)
        cleanupSQL(
            "DROP FUNCTION dbo.[\(funcName)]",
            "DROP TABLE [\(tableName)]"
        )

        let result = try await query("SELECT * FROM dbo.[\(funcName)]('ENG')")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }

    // MARK: - Alter and Drop

    func testAlterFunction() async throws {
        let funcName = uniqueTableName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION dbo.[\(funcName)](@x INT)
            RETURNS INT AS BEGIN RETURN @x; END
        """)
        cleanupSQL("DROP FUNCTION dbo.[\(funcName)]")

        try await execute("""
            ALTER FUNCTION dbo.[\(funcName)](@x INT)
            RETURNS INT AS BEGIN RETURN @x + 100; END
        """)

        let result = try await query("SELECT dbo.[\(funcName)](1) AS val")
        XCTAssertEqual(result.rows[0][0], "101")
    }

    func testDropFunction() async throws {
        let funcName = uniqueTableName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION dbo.[\(funcName)](@x INT)
            RETURNS INT AS BEGIN RETURN @x; END
        """)

        try await execute("DROP FUNCTION dbo.[\(funcName)]")

        do {
            _ = try await query("SELECT dbo.[\(funcName)](1)")
            XCTFail("Should fail after drop")
        } catch {
            // Expected
        }
    }

    // MARK: - Function Definition

    func testGetFunctionDefinition() async throws {
        let funcName = uniqueTableName(prefix: "fn")
        try await execute("""
            CREATE FUNCTION dbo.[\(funcName)](@input NVARCHAR(100))
            RETURNS NVARCHAR(100)
            AS
            BEGIN
                RETURN UPPER(@input);
            END
        """)
        cleanupSQL("DROP FUNCTION dbo.[\(funcName)]")

        let definition = try await session.getObjectDefinition(
            objectName: funcName, schemaName: "dbo", objectType: .function
        )
        XCTAssertFalse(definition.isEmpty)
    }
}
