import XCTest
import SQLServerKit
@testable import Echo

/// Tests SQL Server user-defined function operations through Echo's DatabaseSession layer.
final class MSSQLFunctionTests: MSSQLLabTestCase {

    // MARK: - Scalar Functions

    func testCreateScalarFunction() async throws {
        let funcName = uniqueTableName(prefix: "fn")
        try await sqlserverClient.routines.createFunction(
            name: funcName,
            parameters: [
                FunctionParameter(name: "x", dataType: .int)
            ],
            returnType: .int,
            body: "BEGIN RETURN @x * 3; END"
        )

        let result = try await query("SELECT dbo.[\(funcName)](14) AS tripled")
        XCTAssertEqual(result.rows[0][0], "42")
    }

    func testScalarFunctionWithStringInput() async throws {
        let funcName = uniqueTableName(prefix: "fn")
        try await sqlserverClient.routines.createFunction(
            name: funcName,
            parameters: [
                FunctionParameter(name: "first", dataType: .nvarchar(length: .length(50))),
                FunctionParameter(name: "last", dataType: .nvarchar(length: .length(50))),
            ],
            returnType: .nvarchar(length: .length(101)),
            body: "BEGIN RETURN @first + ' ' + @last; END"
        )

        let result = try await query("SELECT dbo.[\(funcName)]('Jane', 'Doe') AS name")
        XCTAssertEqual(result.rows[0][0], "Jane Doe")
    }

    // MARK: - Inline Table-Valued Function

    func testInlineTableValuedFunction() async throws {
        let tableName = uniqueTableName()
        let funcName = uniqueTableName(prefix: "fn")
        try await sqlserverClient.admin.createTable(name: tableName, columns: [
            SQLServerColumnDefinition(name: "id", definition: .standard(.init(dataType: .int))),
            SQLServerColumnDefinition(name: "dept", definition: .standard(.init(dataType: .nvarchar(length: .length(50))))),
            SQLServerColumnDefinition(name: "name", definition: .standard(.init(dataType: .nvarchar(length: .length(100))))),
        ])
        try await sqlserverClient.admin.insertRows(
            into: tableName,
            columns: ["id", "dept", "name"],
            values: [
                [.int(1), .nString("ENG"), .nString("Alice")],
                [.int(2), .nString("ENG"), .nString("Bob")],
                [.int(3), .nString("HR"), .nString("Carol")],
            ]
        )
        try await sqlserverClient.routines.createInlineTableValuedFunction(
            name: funcName, parameters: [FunctionParameter(name: "dept", dataType: .nvarchar(length: .length(50)))],
            query: "SELECT id, name FROM [\(tableName)] WHERE dept = @dept")

        let result = try await query("SELECT * FROM dbo.[\(funcName)]('ENG')")
        IntegrationTestHelpers.assertRowCount(result, expected: 2)
    }

    // MARK: - Alter and Drop

    func testAlterFunction() async throws {
        let funcName = uniqueTableName(prefix: "fn")
        try await sqlserverClient.routines.createFunction(
            name: funcName,
            parameters: [
                FunctionParameter(name: "x", dataType: .int)
            ],
            returnType: .int,
            body: "BEGIN RETURN @x; END"
        )

        try await sqlserverClient.routines.alterScalarFunction(
            name: funcName, parameters: [FunctionParameter(name: "x", dataType: .int)], returnType: .int, body: "BEGIN RETURN @x + 100; END")

        let result = try await query("SELECT dbo.[\(funcName)](1) AS val")
        XCTAssertEqual(result.rows[0][0], "101")
    }

    func testDropFunction() async throws {
        let funcName = uniqueTableName(prefix: "fn")
        try await sqlserverClient.routines.createFunction(
            name: funcName,
            parameters: [
                FunctionParameter(name: "x", dataType: .int)
            ],
            returnType: .int,
            body: "BEGIN RETURN @x; END"
        )

        try await sqlserverClient.routines.dropFunction(name: funcName)

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
        try await sqlserverClient.routines.createFunction(
            name: funcName,
            parameters: [
                FunctionParameter(name: "input", dataType: .nvarchar(length: .length(100)))
            ],
            returnType: .nvarchar(length: .length(100)),
            body: "BEGIN RETURN UPPER(@input); END"
        )

        let definition = try await session.getObjectDefinition(
            objectName: funcName, schemaName: "dbo", objectType: .function
        )
        XCTAssertFalse(definition.isEmpty)
    }
}
